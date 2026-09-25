///
/// Shuttle engine roster maintenance.
///
/// The periodic sanity pass over shuttle.engine_list (refresh_engines) plus the
/// helm's manual engine survey (engine_diagnostic_report): who is aboard, who is
/// gone, who is bolted to a tile the ship does not own, and why.

/**
  * Just double checks all the engines on the shuttle
  */
/obj/structure/overmap/ship/proc/refresh_engines()
	if(!shuttle)
		est_thrust = 0
		return
	// A hull mid-move is geometrically untestable: takeoff() relocates the port's tile
	// (x/y/z all updated) early in initiate_docking(), but setDir(new_dock.dir) is that
	// proc's LAST line, after cleanup_runway()'s per-turf CHECK_TICK yields - so on any
	// rotated move there are whole ticks where return_coords() projects the old heading
	// from the new position and the rect misses the hull entirely. Round 4 (2026-08-15
	// 04:39:22): a refresh landed in that window during an undock from the round's only
	// dir-rotated berth and unsynced all four of D 19's thrusters while they stood on
	// their own registered deck tiles - and the rebind sweep below could not save them,
	// because get_containing_shuttle() runs the same poisoned rect. Nothing about the
	// roster can be learned mid-move; keep the list and let the first post-move refresh
	// judge it against honest geometry.
	if(shuttle.move_in_flight())
		return
	var/calculated_thrust = 0
	// Cutting from engine_list mid-loop shifts the loop's internal index down and makes
	// it skip the next entry, so a live engine sitting behind a dropped one silently
	// stops counting toward thrust for that pass. Collect first, cut after.
	var/list/obj/machinery/power/shuttle_engine/ship/dropped = list()
	for(var/obj/machinery/power/shuttle_engine/ship/E in shuttle.engine_list)
		// Remove deleted engines
		if(QDELETED(E))
			dropped += E
			continue
		// Membership is judged purely geometrically (bounding box + z). Deliberately NOT
		// is_in_shuttle_bounds(): the mobile override layers a shuttle_areas instance
		// test on top, and turf-area bookkeeping can go wrong while the hull itself is
		// fine - another shuttle's footprint overlapping ours reassigns turfs into its
		// area until it leaves, and round 803 lost all four Delta thrusters to hull
		// tiles stranded in an orphaned same-type area instance. This proc runs every
		// helm UI tick, so an area test here turns any one bad frame into an engine
		// unbound for the rest of the round.
		if(!shuttle.is_in_shuttle_bounds_geometric(E))
			dropped += E
			continue
		var/area/engine_area = get_area(E)
		if(!(engine_area in shuttle.shuttle_areas))
			// Aboard geometrically, so keep it working - but this state is the trigger
			// behind every engine-disconnect report, so name the foreign area once per
			// episode rather than every UI tick.
			if(!E.logged_area_mismatch)
				E.logged_area_mismatch = TRUE
				log_shuttle("[name]: engine [E] at [AREACOORD(E)] is inside ship bounds but its area ([engine_area_name(E)]) is not one of the ship's areas - keeping it connected")
		else
			E.logged_area_mismatch = FALSE
		E.update_engine()
		if(E.enabled)
			calculated_thrust += E.engine_power
	for(var/obj/machinery/power/shuttle_engine/ship/E as anything in dropped)
		shuttle.engine_list -= E
		if(QDELETED(E))
			continue
		E.unsync_ship()
		// Off our hull for real. If it stands on some other ship's deck now (wrong-bind
		// while docked ship-to-ship, hull sections traded away), hand it over instead of
		// leaving it orphaned - the connect_loc relink unsync_ship() arms only fires on
		// admin/blueprint hull expansion, never in normal play.
		var/obj/docking_port/mobile/new_home = SSshuttle.get_containing_shuttle(E)
		if(new_home)
			E.connect_to_shuttle(port = new_home)
			log_shuttle("[name]: engine [E] at [AREACOORD(E)] left ship bounds - rebound to [new_home.name]")
		else
			log_shuttle("[name]: engine [E] at [AREACOORD(E)] left ship bounds - unsynced")
	est_thrust = calculated_thrust

/// Area name for the drop log above, kept separate so the log line stays readable.
/obj/structure/overmap/ship/proc/engine_area_name(obj/machinery/power/shuttle_engine/ship/E)
	var/area/engine_area = get_area(E)
	return engine_area ? "[engine_area.type]" : "nullspace"

/// How many diagnostic lines one engine refresh will read back before it stops.
#define ENGINE_DIAGNOSTIC_MAX_LINES 8

/**
 * Names every thruster on or beside the hull that the helm cannot use, and why.
 *
 * refresh_engines() silently prunes and silently ignores; a thruster bolted on a tile
 * the ship does not own simply never appears anywhere, and the round-6 crew burned
 * fifteen minutes theorising about cables and SMES units because nothing would say
 * "that tile is not your ship". This is the saying-it: run from the helm's manual
 * engine refresh (a button press, never the burn path - the sweep walks the whole
 * footprint plus a one-tile ring, which is exactly where nacelles get bolted on).
 *
 * Returns a list of player-facing strings; empty means nothing to complain about.
 */
/obj/structure/overmap/ship/proc/engine_diagnostic_report()
	var/list/lines = list()
	if(!shuttle)
		return lines
	// Same guard as refresh_engines(): mid-move the port's rect projects the old
	// heading from the new position and every geometric answer is wrong.
	if(shuttle.move_in_flight())
		lines += "Hull is mid-manoeuvre - engine survey unavailable until it settles."
		return lines
	var/turf/port_turf = get_turf(shuttle)
	if(!port_turf)
		return lines
	var/list/rect = shuttle.return_coords()
	var/min_x = max(1, min(rect[1], rect[3]) - 1)
	var/min_y = max(1, min(rect[2], rect[4]) - 1)
	var/max_x = min(world.maxx, max(rect[1], rect[3]) + 1)
	var/max_y = min(world.maxy, max(rect[2], rect[4]) + 1)

	// Everything registered, plus everything physically on or hugging the footprint -
	// the one-tile ring is where an unclaimed nacelle row sits.
	var/list/obj/machinery/power/shuttle_engine/ship/candidates = list()
	for(var/obj/machinery/power/shuttle_engine/ship/registered in shuttle.engine_list)
		candidates |= registered
	for(var/turf/tile as anything in block(locate(min_x, min_y, port_turf.z), locate(max_x, max_y, port_turf.z)))
		for(var/obj/machinery/power/shuttle_engine/ship/found in tile)
			candidates |= found

	for(var/obj/machinery/power/shuttle_engine/ship/engine as anything in candidates)
		if(QDELETED(engine))
			continue
		// A ship docked against us parks its own nacelles inside our ring - their
		// engines are their business, not a fault on our report.
		var/obj/docking_port/mobile/owner = engine.connected_ship_ref?.resolve()
		if(owner && owner != shuttle)
			continue
		var/reason = engine.link_refusal_reason(shuttle)
		if(!reason)
			continue
		lines += "[engine.name] at ([engine.x], [engine.y]): [reason]"
		if(length(lines) >= ENGINE_DIAGNOSTIC_MAX_LINES)
			break
	return lines

#undef ENGINE_DIAGNOSTIC_MAX_LINES
