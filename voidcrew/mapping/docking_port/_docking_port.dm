/**
 * The main docking port that all voidcrew ships should be using.
 */
/obj/docking_port/mobile/voidcrew
	launch_status = UNLAUNCHED
	callTime = 0

	/// Makes sure we dont run linking logic more than once
	VAR_PRIVATE/cached_z_level
	var/z_levels_above = 0
	var/z_levels_below = 0

	///Cache of the old z level we're on, stored to remove after the shuttle moves.
	///We do this because on ship-spawning, the shuttle will move, init atoms, then call after move.
	///This means that things that require stuff like stationloving, will not function, as it'll load while there's no station z level to relocate to.
	VAR_PRIVATE/old_z_level

	///The linked overmap object, if there is one. This is set AFTER Initialize, so do not set machine inits to this.
	var/obj/structure/overmap/ship/current_ship

	///List of spawn points on the ship.
	var/list/obj/machinery/cryopod/spawn_points = list()

	///The cryo oversight console for this ship (for custom slot swaps)
	var/obj/machinery/computer/cryopod/cryo_console

/obj/docking_port/mobile/voidcrew/Initialize(mapload)
	. = ..()
	RegisterSignal(SSdcs, COMSIG_GLOB_Z_SHIP_PROBE, PROC_REF(respond_to_z_port_probe))

/obj/docking_port/mobile/voidcrew/Destroy(force)
	UnregisterSignal(SSdcs, COMSIG_GLOB_Z_SHIP_PROBE)
	// Debug: log when shuttle is destroyed to help track orphaning issues
	if(current_ship)
		// This should only happen through normal cleanup - log a stack trace to find unexpected deletions
		var/ship_name = current_ship.name
		var/ship_state = current_ship.state
		log_shuttle("Shuttle [name] destroyed while overmap ship [ship_name] still exists. Force=[force], state=[ship_state]")
		stack_trace("Shuttle [name] being destroyed while overmap ship [ship_name] exists - investigate if unexpected")
		current_ship.shuttle = null
	else
		log_shuttle("Shuttle [name] destroyed with no current_ship reference. Force=[force]")
	current_ship = null
	spawn_points.Cut()
	unlink_from_z_level()
	return ..()

/obj/docking_port/mobile/voidcrew/calculate_docking_port_information(datum/map_template/shuttle/loading_from)
	. = ..()
	// Re-populate shuttle_areas after dimensions are set (Initialize runs before dimensions are known)
	if(!length(shuttle_areas))
		var/list/all_turfs = return_ordered_turfs(x, y, z, dir)
		for(var/turf/curT as anything in all_turfs)
			var/area/cur_area = curT.loc
			if(istype(cur_area, area_type))
				shuttle_areas[cur_area] = TRUE
	link_to_z_level()

/**
 * Voidcrew ships are loaded straight onto their transit dock and begin the round
 * "flying" in deep space with no destination. action_load() leaves the port at
 * SHUTTLE_IDLE with timer = 0, which makes check_effects() treat us as "about to
 * arrive" on every SSshuttle fire and call parallax_slowdown(), permanently wiping
 * parallax_movedir on the ship's areas — so space looks frozen for the whole first
 * flight. Mirror enterTransit()'s destination-less state instead (SHUTTLE_CALL with
 * an infinite timer), which is exactly the state any ship is in after a normal
 * undock, and re-assert the scroll direction on our areas in case a mid-load
 * SSshuttle fire already wiped it.
 */
/obj/docking_port/mobile/voidcrew/postregister(replace = FALSE)
	. = ..()
	if(!istype(get_docked(), /obj/docking_port/stationary/transit) || mode != SHUTTLE_IDLE)
		return
	mode = SHUTTLE_CALL
	timer = INFINITY
	for(var/area/shuttle_area as anything in shuttle_areas)
		shuttle_area.parallax_movedir = preferred_direction
	if(assigned_transit?.assigned_area)
		assigned_transit.assigned_area.parallax_movedir = preferred_direction

/obj/docking_port/mobile/voidcrew/initiate_docking(obj/docking_port/stationary/new_dock, movement_direction, force = FALSE)
	reconcile_hull_before_move()
	return ..()

/**
 * Pre-move audit of every turf inside our own footprint, run before initiate_docking()'s
 * preflight so repairs land before any per-turf move decisions are made. Two corruption
 * classes get repaired and logged, both of which otherwise leave hull tiles - and the
 * engines standing on them - behind at the old location when the ship moves (round 803,
 * 2026-08-01: all four Delta thrusters stranded on an unloading ruin z this way):
 *
 * 1. Area split: a tile sitting in a /area/shuttle/voidcrew instance whose TYPE we own
 *    but which is not the instance registered in shuttle_areas. area/beforeShuttleMove()
 *    grants MOVE_AREA purely by instance membership, so a split tile fails every
 *    membership test while stringifying identically in logs ("Engineering"). Reassign it
 *    to our instance. Tiles owned by a LIVE other ship (their area's shuttle_port
 *    resolves to a different port) are left alone - ship-to-ship docking legitimately
 *    nests one hull inside another's footprint.
 *
 * 2. Missing shuttle skipover: fromShuttleMove() refuses to move any turf without
 *    /turf/baseturf_skipover/shuttle in its baseturfs. Restore the marker the same way
 *    /datum/map_template/shuttle/load() stamps it at ship load.
 */
/obj/docking_port/mobile/voidcrew/proc/reconcile_hull_before_move()
	if(!length(shuttle_areas)) // initial load placement, nothing registered to reconcile against
		return
	var/list/own_area_by_type
	for(var/turf/hull_turf as anything in return_ordered_turfs(x, y, z, dir))
		if(!hull_turf)
			continue
		if(isspaceturf(hull_turf))
			restore_collapsed_mount(hull_turf)
			continue
		var/area/turf_area = hull_turf.loc
		if(!shuttle_areas[turf_area])
			if(!istype(turf_area, /area/shuttle/voidcrew))
				// A non-ship shuttle area (transit, another port's area) holding a real
				// floor inside our footprint = a previously stranded tile we re-landed
				// on. Not repairable from here, and it will not travel - log it.
				if(istype(turf_area, /area/shuttle))
					log_shuttle("[name]: hull-rect turf [hull_turf] ([hull_turf.type]) at [AREACOORD(hull_turf)] sits in unregistered [turf_area.type] [REF(turf_area)] - it will not move with the ship")
				continue
			var/area/shuttle/voidcrew/foreign = turf_area
			if(foreign.shuttle_port && foreign.shuttle_port != src)
				log_shuttle("[name]: hull-rect turf [hull_turf] at [AREACOORD(hull_turf)] belongs to live foreign ship area [foreign.type] [REF(foreign)] ([foreign.shuttle_port.name]) - leaving it alone")
				continue
			if(isnull(own_area_by_type))
				own_area_by_type = list()
				for(var/area/own_area as anything in shuttle_areas)
					// Ship-to-ship docking absorbs the guest's areas into the host's
					// shuttle_areas; with two same-class hulls docked, the guest's
					// instance must never win this map and steal reunified tiles.
					if(istype(own_area, /area/shuttle/voidcrew))
						var/area/shuttle/voidcrew/own_voidcrew_area = own_area
						if(own_voidcrew_area.shuttle_port && own_voidcrew_area.shuttle_port != src)
							continue
					own_area_by_type[own_area.type] = own_area
			var/area/replacement = own_area_by_type[foreign.type]
			if(!replacement)
				continue
			log_shuttle("[name]: hull turf [hull_turf] at [AREACOORD(hull_turf)] was in orphaned area instance [REF(foreign)] of [foreign.type] - reunified into [REF(replacement)] before move")
			hull_turf.change_area(foreign, replacement)
			turf_area = replacement
		if(!shuttle_areas[turf_area])
			continue
		if(!isnull(hull_turf.depth_to_find_baseturf(/turf/baseturf_skipover/shuttle)))
			continue
		if(!islist(hull_turf.baseturfs))
			hull_turf.assemble_baseturfs()
		hull_turf.insert_baseturf(min(3, hull_turf.count_baseturfs() + 1), /turf/baseturf_skipover/shuttle)
		log_shuttle("[name]: hull turf [hull_turf] ([hull_turf.type]) at [AREACOORD(hull_turf)] had no shuttle skipover baseturf - restored before move")
	// One line per move so a mangled rectangle (transposed dims, drifted offsets) is
	// visible next to whatever strands: compare stranded coords against this rect.
	var/list/rect = return_coords()
	log_shuttle("[name]: pre-move footprint pos=([x],[y],[z]) dir=[dir] w=[width] h=[height] dw=[dwidth] dh=[dheight] rect=([rect[1]],[rect[2]])-([rect[3]],[rect[4]])")

/**
 * An engine of ours standing on bare space inside our own footprint is a collapsed
 * hull mount: a previous move carried the area and the engine (the engine's
 * beforeShuttleMove() grants MOVE_CONTENTS whenever MOVE_AREA is set) while the tile
 * itself failed isshuttleturf() and stayed behind, so the engine arrived standing on
 * the destination's raw space. It flies fine in that state - round 804 found Kilo,
 * Goon and CCU engines living in /area/space/nearstation and /area/shuttle/transit -
 * but the first time the area bookkeeping hiccups too, the engine strands for good.
 * Rebuild the mount: adopt a neighbouring registered area, then lay plating -
 * /area/shuttle/place_on_top_react() stamps the shuttle skipover during the
 * place_on_top(), which is exactly the state a mapped mount loads with.
 */
/obj/docking_port/mobile/voidcrew/proc/restore_collapsed_mount(turf/space_turf)
	var/obj/machinery/power/shuttle_engine/mounted
	for(var/obj/machinery/power/shuttle_engine/engine in space_turf)
		if(engine.connected_ship_ref?.resolve() == src)
			mounted = engine
			break
	if(!mounted)
		return
	var/area/new_home
	for(var/check_dir in GLOB.cardinals)
		var/turf/neighbour = get_step(space_turf, check_dir)
		var/area/neighbour_area = neighbour?.loc
		if(neighbour_area && shuttle_areas[neighbour_area])
			new_home = neighbour_area
			break
	if(!new_home)
		return
	log_shuttle("[name]: engine [mounted] at [AREACOORD(space_turf)] was standing on bare space inside the footprint - rebuilding its mount into [new_home.type]")
	space_turf.change_area(space_turf.loc, new_home)
	space_turf.place_on_top(/turf/open/floor/plating/airless)

/obj/docking_port/mobile/voidcrew/beforeShuttleMove(turf/newT, rotation, move_mode, obj/docking_port/mobile/moving_dock)
	old_z_level = z
	return ..()

/obj/docking_port/mobile/voidcrew/afterShuttleMove(turf/oldT, list/movement_force, shuttle_dir, shuttle_preferred_direction, move_dir, rotation)
	unlink_from_z_level()
	link_to_z_level()
	recalculate_shuttle_areas() // this also readds VALID_TERRITORY
	// Stranded-tile census: any registered area still holding turfs on a z we just
	// left is the seed of the next thruster loss - name the seed move while the
	// trail is warm (rounds 803/804: engines died with the site the tiles stayed on).
	for(var/area/shuttle_area as anything in shuttle_areas)
		for(var/census_z in 1 to length(shuttle_area.turfs_by_zlevel))
			if(census_z == z)
				continue
			var/stranded_count = length(shuttle_area.get_turfs_by_zlevel(census_z))
			if(stranded_count)
				log_shuttle("[name]: [stranded_count] turf(s) of [shuttle_area.type] left stranded on z=[census_z] after moving to z=[z]")
	// Moving into transit asserts a preferred_direction scroll on our areas
	// (shuttle_move.dm); reconcile it with the ship's real speed - a ship with no
	// thrust should show a still starfield, not a drifting one
	if(current_ship && istype(get_docked(), /obj/docking_port/stationary/transit))
		current_ship.update_flight_parallax()
	// Initialize space turfs if we're docking to empty space
	if(current_ship && istype(current_ship.docked, /obj/structure/overmap/planet/empty))
		current_ship.initialize_nearby_space_turfs()
	return ..()

/// Links to the Z level to ensure that if there are more than one ships on a z level when one leaves it doesnt clear the z trait
/obj/docking_port/mobile/voidcrew/proc/link_to_z_level()
	GLOB.the_station_areas |= shuttle_areas

	var/bottom_z = z - z_levels_below
	var/top_z = z + z_levels_above
	for(var/z_level in bottom_z to top_z)
		if(is_station_level(z_level))
			continue
		SSmapping.z_trait_levels[ZTRAIT_STATION] += list(z_level)
		GLOB.station_levels_cache[z_level] = TRUE

/**
 * Unlinks the docking port from the old z level, stored as a var.
 * If we don't have one, we will early return, as you haven't moved from anything.
 * We will also send a signal to check for other ships on the z-level, to avoid turning
 * levels that have another ship on it, into a non-station level, breaking things like stationloving for them.
 */
/obj/docking_port/mobile/voidcrew/proc/unlink_from_z_level()
	if(!old_z_level)
		return

	GLOB.the_station_areas -= shuttle_areas
	for(var/area/area as anything in shuttle_areas)
		area.area_flags &= ~VALID_TERRITORY // don't want anyone dropped in mid shuttle move

	var/bottom_z = old_z_level - z_levels_below
	var/top_z = old_z_level + z_levels_above
	old_z_level = null

	for(var/z_level in bottom_z to top_z)
		var/active_ships = SEND_GLOBAL_SIGNAL(COMSIG_GLOB_Z_SHIP_PROBE, src, z_level)
		if(active_ships)
			continue
		SSmapping.z_trait_levels[ZTRAIT_STATION] -= list(z_level)
		GLOB.station_levels_cache[z_level] = FALSE

/**
 * ##respond_to_z_port_probe
 *
 * Sent by another docking port
 * This is our response, to prevent a level being removed from the list of station areas, if we're still here.
 * Args:
 * source - The docking port that's leaving
 * z_level - the z level that source is leaving from.
 */
/obj/docking_port/mobile/voidcrew/proc/respond_to_z_port_probe(atom/source, obj/docking_port/mobile/voidcrew/leaving, z_level)
	SIGNAL_HANDLER
	if(src == leaving)
		return FALSE
	return !!(z_level == z)

/**
 * ##get_all_humans
 *
 * Returns a list of all the living humans on the ship, as long as they have a mind and a client.
 */
/obj/docking_port/mobile/voidcrew/proc/get_all_humans()
	var/list/humans_to_add = list()
	var/list/all_turfs = return_ordered_turfs(x, y, z, dir)
	for(var/turf/turf as anything in all_turfs)
		var/mob/living/carbon/human/human_to_add = locate() in turf.contents
		if(isnull(human_to_add))
			continue
		if(human_to_add.stat == DEAD)
			continue
		if(!human_to_add.client || !human_to_add.mind)
			continue
		humans_to_add.Add(human_to_add)
	return humans_to_add

/obj/docking_port/mobile/voidcrew/proc/recalculate_shuttle_areas()
	for(var/area/area as anything in shuttle_areas)
		area.area_flags |= VALID_TERRITORY
	// TODO - UPSTREAM - RECALCULATE BOUNDS
