/**
 * # Map regions
 *
 * "Which piece of ground does this turf belong to", independent of which allocator handed
 * it out. Two registers deal ground in this codebase and neither knows about the other:
 *
 *  * /datum/turf_reservation - transit, bitrunning, cargo, space ruins, asteroid fields.
 *    Registered turf-by-turf in SSmapping.used_turfs.
 *  * /datum/map_footprint - the map-zone slot lattice: planets, flat encounters, player
 *    outposts. Registered as a rectangle on /datum/space_level.footprints.
 *
 * Everything that used to be safe because "one encounter owns one z-level" needs this
 * instead the moment sites share a level. A z comparison answers "same level", which on a
 * packed level is four unrelated crews; a region comparison answers "same place".
 *
 * Deliberately returns the register's own datum rather than a rectangle: identity is what
 * callers actually want (a stable key, an equality test), and a rectangle would alias
 * across recycled ground. Use map_region_rect() when the corners are genuinely needed.
 */
/proc/map_region_for_turf(turf/tile)
	if(isnull(tile))
		return null
	var/datum/turf_reservation/reservation = SSmapping.used_turfs[tile]
	if(reservation)
		return reservation
	var/z_value = tile.z
	if(z_value < 1 || z_value > length(SSmapping.z_list))
		return null
	var/datum/space_level/level = SSmapping.z_list[z_value]
	var/list/footprints = level?.footprints
	if(!length(footprints))
		return null
	for(var/datum/map_footprint/footprint as anything in footprints)
		if(footprint?.contains_turf(tile))
			return footprint
	return null

/// Whether `tile` lies inside `region`, whichever kind of region it is. FALSE for a null
/// region, so callers can pass an unresolved region straight in.
/proc/map_region_contains(datum/region, turf/tile)
	if(isnull(region) || isnull(tile))
		return FALSE
	if(istype(region, /datum/map_footprint))
		var/datum/map_footprint/footprint = region
		return footprint.contains_turf(tile)
	if(istype(region, /datum/turf_reservation))
		var/datum/turf_reservation/reservation = region
		return reservation.contains_turf(tile)
	return FALSE

/**
 * `region`'s inclusive rectangle as list(low_x, low_y, high_x, high_y), or null.
 *
 * `z_value` of 0 means "whichever z the region reports"; pass a real z to demand the
 * region's rectangle ON that level (a multi-z reservation has one per level).
 */
/proc/map_region_rect(datum/region, z_value = 0)
	if(isnull(region))
		return null
	if(istype(region, /datum/map_footprint))
		var/datum/map_footprint/footprint = region
		if(isnull(footprint.low_x) || !footprint.z_value)
			return null
		if(z_value && footprint.z_value != z_value)
			return null
		return list(footprint.low_x, footprint.low_y, footprint.high_x, footprint.high_y)
	if(istype(region, /datum/turf_reservation))
		var/datum/turf_reservation/reservation = region
		for(var/z_index in 1 to length(reservation.bottom_left_turfs))
			var/turf/bottom_left = reservation.bottom_left_turfs[z_index]
			var/turf/top_right = reservation.top_right_turfs[z_index]
			if(isnull(bottom_left) || isnull(top_right))
				continue
			if(z_value && bottom_left.z != z_value)
				continue
			return list(bottom_left.x, bottom_left.y, top_right.x, top_right.y)
	return null

/// TRUE when both turfs belong to the same map region - including "neither belongs to one",
/// which is the roundstart-space-level case and has to keep behaving as it always did.
/proc/map_regions_match(turf/first, turf/second)
	if(isnull(first) || isnull(second))
		return FALSE
	return map_region_for_turf(first) == map_region_for_turf(second)

/**
 * TRUE when `tile` positively belongs to a DIFFERENT map region than `region`.
 *
 * The workhorse form of the containment rule: "never somebody else's", not "only mine".
 * A null region (we do not know where WE are) and a tile that resolves to no region at all
 * (the cordon gutter, a roundstart level, deep space, ground a crew built a hull out onto)
 * both answer FALSE, so a guard written on this proc can never produce a false negative -
 * it refuses only ground another tenant demonstrably owns.
 *
 * Callers that already hold their own region should resolve it ONCE and call this per
 * candidate, rather than calling map_regions_match() per pair.
 */
/proc/map_region_excludes_turf(datum/region, turf/tile)
	if(isnull(region) || isnull(tile))
		return FALSE
	var/datum/tile_region = map_region_for_turf(tile)
	return tile_region && tile_region != region

/**
 * # Ship presence bookkeeping
 *
 * ZTRAIT_STATION is a property of a WHOLE z-level, and link_to_z_level() below flips it on
 * as soon as a hull parks anywhere on that level - which is how stationloving, teleport
 * targeting and a dozen upstream "are we on the station" checks keep working aboard a ship
 * in this fork (is_station_level() here means "any ship's level", see
 * every-ship-z-is-a-station-level). There is no finer granularity available in the trait
 * itself, so the trait keeps z granularity and gains two things it did not have:
 *
 *  1. a REFERENCE COUNT, so the flag is added by the first hull to arrive and removed by
 *     the last one to leave - including the one that leaves by being deleted, which the
 *     old old_z_level-gated unlink silently skipped (a hull destroyed while docked left
 *     its encounter's whole z flagged forever, and packed sites hand that ground on), and
 *  2. a record of WHICH levels the flag was put on by a ship, so a roundstart station or
 *     mapped station level is never stripped by a ship undocking from it.
 *
 * and a per-SITE occupancy count sits beside it for the consumers that need the precise
 * answer on a packed level - see turf_has_ship_presence().
 */
/// "[z_level]" -> how many voidcrew hulls currently occupy that level.
GLOBAL_LIST_EMPTY(ship_z_level_links)
/// "[z_level]" -> TRUE for levels whose ZTRAIT_STATION flag was added by a hull linking.
/// Only these may ever be un-flagged; anything else got the trait from the map config.
GLOBAL_LIST_EMPTY(ship_added_station_levels)
/// "[REF(region)]" -> how many voidcrew hulls are standing inside that map region.
/// Keyed by REF rather than by the datum so a region is never kept alive by this list.
GLOBAL_LIST_EMPTY(ship_site_occupancy)

/// How many hulls are standing inside `region` (a /datum/map_footprint or a
/// /datum/turf_reservation) right now.
/proc/site_ship_occupancy(datum/region)
	if(isnull(region))
		return 0
	return GLOB.ship_site_occupancy[REF(region)] || 0

/**
 * The site-scoped answer to is_station_level(): is there a SHIP on this particular piece of
 * ground, rather than merely somewhere on this z-level?
 *
 * Four encounters share a z-level. One hull docked at any of them flags all four, so every
 * `is_station_level(turf.z)` reads TRUE on three sites that have never seen a ship. Callers
 * that are really asking about the ground under a turf - lockdown/undock refusals, assault
 * pod targeting, stationloving relocation, weather - want this instead. A turf that belongs
 * to no region at all (a roundstart level, the station itself) falls through to the trait,
 * so nothing off the lattice changes behaviour.
 */
/proc/turf_has_ship_presence(turf/tile)
	if(isnull(tile))
		return FALSE
	var/datum/region = map_region_for_turf(tile)
	if(isnull(region))
		return is_station_level(tile.z)
	return site_ship_occupancy(region) > 0

/**
 * Rebuilds the ship -> station-level registers from the live port roster.
 *
 * The refcount's failure mode is a link that never gets its matching unlink: the count
 * wedges above zero and the level stays flagged for the rest of the round. Rather than
 * trusting that every path is paired, the release side calls this the moment it finds its
 * own claim already missing, and it is safe to call at any time - it is a full recount, not
 * a patch. Ports are counted from `linked_z_levels`, which is what they actually hold.
 */
/proc/reconcile_ship_station_levels()
	var/list/counts = list()
	for(var/obj/docking_port/mobile/voidcrew/port as anything in SSshuttle.mobile_docking_ports)
		if(!istype(port) || QDELETED(port))
			continue
		for(var/z_level in port.linked_z_levels)
			counts["[z_level]"] += 1
	GLOB.ship_z_level_links = counts
	for(var/key in GLOB.ship_added_station_levels.Copy())
		if(counts[key])
			continue
		GLOB.ship_added_station_levels -= key
		var/z_level = text2num(key)
		if(isnull(z_level))
			continue
		SSmapping.z_trait_levels[ZTRAIT_STATION] -= list(z_level)
		LISTASSERTLEN(GLOB.station_levels_cache, z_level, FALSE)
		GLOB.station_levels_cache[z_level] = FALSE
	log_shuttle("reconcile_ship_station_levels(): rebuilt ship z-links from [length(SSshuttle.mobile_docking_ports)] port(s), [length(counts)] level(s) occupied")

/**
 * Frees a shuttle's transit reservation and clears its assignment.
 *
 * Every docking port answers a non-forced qdel() with QDEL_HINT_LETMELIVE
 * (/obj/docking_port/Destroy), and /obj/docking_port/stationary/transit does ALL of
 * its cleanup - unregistering from SSshuttle.transit_docking_ports, dropping `owner`,
 * qdel'ing the turf reservation - inside `if(force)`. So the QDEL_NULL() that
 * expand_shuttle()/remove_shuttle_turfs() used to call here deleted nothing: it nulled
 * the shuttle's reference and left a live, still-owned transit port sitting on its
 * reservation. `transit_utilized` is only decremented by the reservation's own
 * COMSIG_QDELETING handler, so every hull expansion past the bounding box burned
 * 3-6k turfs of the 22.5k global transit budget permanently, and SSshuttle's orphan
 * sweep never collected the port because `owner` was still set.
 *
 * That budget is what gates check_transit_zone(). Exhaust it and a ship can never
 * enter transit again - which on the overmap reads as an undock that leaves the hull
 * parked at the dock it just "left" (see complete_dock() in ship.dm).
 */
/proc/release_assigned_transit(obj/docking_port/mobile/shuttle)
	if(!shuttle)
		return
	if(!QDELETED(shuttle.assigned_transit))
		qdel(shuttle.assigned_transit, force = TRUE) // transit/Destroy() nulls our ref for us
	shuttle.assigned_transit = null

/**
 * Where an autogenerated reserve berth was originally built.
 *
 * Set by mark_reserve_home() at creation and read by reset_reserve_dock_to_home(), both in
 * voidcrew/_HELPERS/docking.dm, which is also where the reasoning lives. Zero on any dock that
 * is not an autogenerated reserve berth - mapped ports never move, so they need no home.
 */
/obj/docking_port/stationary
	var/reserve_home_x = 0
	var/reserve_home_y = 0
	var/reserve_home_z = 0

/**
 * Nothing upstream nulls the back-references a mobile port keeps to the berth it last
 * left (`previous`, set in enterTransit) or is flying toward (`destination`, set in
 * request and only cleared on arrival). Upstream never deletes stationary ports out
 * from under a live shuttle, but encounter berths here are force-qdel'd on every
 * planet/ruin/event teardown - so each undock left the departed berth pinned by the
 * ship's `previous` until the garbage collector hard-deleted it (round 4: 92 of them,
 * 22 s of world freeze).
 */
/obj/docking_port/stationary/Destroy(force)
	if(force)
		for(var/obj/docking_port/mobile/port as anything in SSshuttle.mobile_docking_ports)
			if(port.previous == src)
				port.previous = null
			if(port.destination == src)
				port.destination = null
	return ..()

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

	///The z-levels this hull currently holds a ZTRAIT_STATION claim on, as numbers.
	///This is the authority for unlinking, replacing the old `old_z_level` snapshot taken in
	///beforeShuttleMove(): that was null on every path that was not a move, so a hull deleted
	///while docked never released its levels and left the encounter's ground flagged for the
	///rest of the round. Read by reconcile_ship_station_levels().
	var/list/linked_z_levels = list()

	///REF() of the map region (footprint or turf reservation) this hull is counted against in
	///GLOB.ship_site_occupancy, or null when it is not standing in one.
	VAR_PRIVATE/occupied_site_key

	///The linked overmap object, if there is one. This is set AFTER Initialize, so do not set machine inits to this.
	var/obj/structure/overmap/ship/current_ship

	///List of spawn points on the ship.
	var/list/obj/machinery/cryopod/spawn_points = list()

	///The cryo oversight console for this ship (for custom slot swaps)
	var/obj/machinery/computer/cryopod/cryo_console

	///Reentrancy latch for initiate_docking(): world.time until which a second move is
	///refused. Two drivers reach for the same hull (SSshuttle's check() and the overmap
	///dock/undock timers), and initiate_docking() yields on CHECK_TICK - an overlap
	///interleaves two half-done turf transplants and strands whatever the loser touched.
	VAR_PRIVATE/move_lock_until = 0

	///turf -> turf type census of the tiles this hull actually carried to where it now
	///sits, rebuilt by takeoff() on every move. reconcile_hull_before_move() reads it to
	///tell a deck tile of ours that lost its skipover from ground we are merely parked on.
	VAR_PRIVATE/list/carried_hull_types

/obj/docking_port/mobile/voidcrew/Initialize(mapload)
	. = ..()
	RegisterSignal(SSdcs, COMSIG_GLOB_Z_SHIP_PROBE, PROC_REF(respond_to_z_port_probe))

/obj/docking_port/mobile/voidcrew/Destroy(force)
	UnregisterSignal(SSdcs, COMSIG_GLOB_Z_SHIP_PROBE)
	// Keyed by mobile port and never pruned on success - a ship that ever failed a
	// transit request would otherwise be pinned by this list and hard-delete
	SSshuttle.transit_request_failures -= src
	// A port dying while it still claims a live overmap ship is an ANOMALY, and this is the
	// alarm for it. Every teardown the fork drives itself breaks the link first, in
	// /obj/structure/overmap/ship/release_hull(), which is the single funnel for all three:
	// ship/Destroy() (so every qdel of an overmap ship, NPC hull kills included),
	// destroy_ship(force = TRUE) (the bluespace jump) and despawn_derelict() (the sweeper).
	// What is left to catch here is a port deleted out from under a ship that still expects
	// it: the admin shuttle-manipulator verbs (adminshuttle.dm), and a hull deconstructed to
	// its last turf (clear_empty_shuttle_turfs() in code/__HELPERS/shuttle.dm), which strands
	// an overmap ship with no hull and genuinely wants investigating.
	//
	// stack_trace() is CRASH() with the proc kept alive, so it increments GLOB.total_runtimes
	// and world.dm's clean_run.lk is refused for the run. That is exactly what we want from an
	// alarm and exactly why the legitimate paths must never reach it - one despawned ship used
	// to fail the whole unit-test suite from here.
	//
	// The nulling below stays regardless: it is the safety net for the paths above, without
	// which the stranded ship keeps a dangling `shuttle` and its Destroy() calls
	// intoTheSunset() on a deleted port.
	if(current_ship)
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

/**
 * Sweeps the landmarks off this hull before the ground goes back to space.
 *
 * /turf/proc/empty() (change_turf.dm) typecaches /obj/effect/landmark into `ignored_atoms`
 * right beside /obj/docking_port and /mob/dead, so the per-turf empty() pass below in the
 * parent proc deletes everything on a hull turf EXCEPT its landmarks - and jumpToNullSpace()
 * is the only thing that ever touches these turfs. Every hull carries several: create_ship()
 * spawns a blobstart and an observer_start aboard, and each hull .dmm maps its own job spawn
 * points. Nothing else removes them, so before this fix every create/destroy cycle grew
 * GLOB.landmarks_list (and GLOB.start_landmarks_list, and GLOB.jobspawn_overrides) forever,
 * with the abandoned markers left standing on ground that is handed to the next tenant.
 *
 * Fixed here rather than in empty(): upstream spares landmarks on purpose (a station turf
 * emptied by a bomb keeps its spawn points) and every other caller depends on that.
 *
 * Scoped exactly like the parent's own turf loop - our rect AND one of our areas - so a
 * planet's or ruin's own landmarks under a docked hull's rectangle are never touched. Only
 * turfs the parent is about to change_area() and ScrapeAway() are swept.
 */
/obj/docking_port/mobile/voidcrew/jumpToNullSpace()
	for(var/turf/hull_turf as anything in return_ordered_turfs(x, y, z, dir))
		if(!hull_turf || !istype(hull_turf.loc, area_type))
			continue
		for(var/obj/effect/landmark/marker in hull_turf.get_all_contents())
			if(QDELETED(marker))
				continue
			qdel(marker)
	return ..()

/obj/docking_port/mobile/voidcrew/calculate_docking_port_information(datum/map_template/shuttle/loading_from)
	. = ..()
	// Only Destroy() ever nulls shuttle_areas, so a null here means a stale caller
	// (an undock-time reseat, a load helper) reached a port that is already dying.
	// Rebuilding onto it assigns into the nulled list ("bad index" - the suite's
	// floating runtime), and the link_to_z_level() below would re-take the z claim
	// that Destroy()'s unlink just released, leaking ZTRAIT_STATION for the round.
	if(QDELETED(src) || isnull(shuttle_areas))
		return
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
 * parallax_movedir on the ship's areas, so space looks frozen for the whole first
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

/**
 * A voidcrew ship in open flight is SHUTTLE_CALL with destination = null - there is
 * nothing to ever arrive at. Base check() doesn't know that state: once the undock
 * timer expires it calls initiate_docking(null) every fire (which runtimed on
 * `new_dock.get_docked()` and killed the whole SSshuttle fire mid-loop - round 811),
 * and its arrival tail would park us at SHUTTLE_IDLE, the state postregister()
 * documents as wiping flight parallax. Settle the timer to the perpetual-flight value
 * before the base proc's arrival machinery can run.
 */
/obj/docking_port/mobile/voidcrew/check()
	if(mode == SHUTTLE_CALL && isnull(destination) && timeLeft(1) <= 0)
		timer = INFINITY
	return ..()

/**
 * TRUE while initiate_docking() is anywhere between its first line and its return -
 * which includes the window cleanup_runway() yields through AFTER takeoff() has already
 * relocated the port's tile. In that window the port's x/y/z are the destination berth
 * but `dir` is still the old dock's, because setDir(new_dock.dir) is the base proc's
 * LAST statement - so on any rotated move return_coords() projects the old heading from
 * the new position and describes a rectangle that exists nowhere. Round 4 (2026-08-15
 * 04:39:22, Delta D 19): a refresh_engines() landed in exactly that window during an
 * undock from the round's only dir-rotated berth (site dir=1, transit berth dir=2) and
 * every engine on the hull failed is_in_shuttle_bounds_geometric() while standing on its
 * own registered deck tiles. Callers that act PERMANENTLY on bounds membership must
 * treat the geometry as unknowable while this is TRUE.
 */
/obj/docking_port/mobile/voidcrew/proc/move_in_flight()
	return world.time < move_lock_until

/obj/docking_port/mobile/voidcrew/initiate_docking(obj/docking_port/stationary/new_dock, movement_direction, force = FALSE)
	if(isnull(new_dock)) // base proc error-returns; no reconcile pass for a non-move
		return ..()
	if(world.time < move_lock_until)
		log_shuttle("[name]: OVERLAPPING initiate_docking refused - move to [new_dock] arrived while another move is still in flight")
		return DOCKING_BLOCKED
	move_lock_until = world.time + 30 SECONDS
	reconcile_hull_before_move()
	. = ..()
	move_lock_until = 0

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
 *    /datum/map_template/shuttle/load() stamps it at ship load - but only on a tile
 *    carried_hull_types vouches for as ours, never on ground we are parked on. See
 *    takeoff() for why the turf's own state cannot tell those two apart.
 */
/obj/docking_port/mobile/voidcrew/proc/reconcile_hull_before_move()
	if(!length(shuttle_areas)) // initial load placement, nothing registered to reconcile against
		return
	// Engine-first audit. The per-turf sweep below has silent lanes - round 811's Pill
	// lost its thruster off a SPACE turf with an INTACT skipover sitting in an ORPHANED
	// same-name area instance, a state that passes every check in that sweep without a
	// single log line. An engine's mount is audited directly and repaired
	// unconditionally: registered area, real deck, skipover, or it gets rebuilt.
	for(var/obj/machinery/power/shuttle_engine/engine as anything in engine_list)
		var/turf/mount = get_turf(engine)
		if(!mount || mount.z != z || !is_in_shuttle_bounds_geometric(engine))
			continue
		repair_engine_mount(engine, mount)
	var/list/own_area_by_type
	for(var/turf/hull_turf as anything in return_ordered_turfs(x, y, z, dir))
		if(!hull_turf)
			continue
		// Collapsed mount: one of our own engines standing on a tile a move cannot
		// carry - bare space, or foreign ground adopted at a dock (wasteland dirt,
		// ruin space). Rebuild it into real hull before the move wedges them apart.
		if(!isshuttleturf(hull_turf) && restore_collapsed_mount(hull_turf))
			continue
		if(isspaceturf(hull_turf))
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
		// Unmarked ground inside one of our areas is the landing site's, not a deck tile
		// with a bookkeeping fault, unless we can show we carried this exact turf here.
		// Stamping the site's floor is how a breached hull sails off a planet with a
		// square of that planet's dirt riding in the hole.
		if(carried_hull_types?[hull_turf] != hull_turf.type)
			log_shuttle("[name]: footprint turf [hull_turf] ([hull_turf.type]) at [AREACOORD(hull_turf)] has no shuttle skipover and is not hull we carried here ([carried_hull_types?[hull_turf] || "never carried"]) - leaving it to the site")
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
 * Post-move census of what this hull actually set down, keyed turf -> turf type.
 *
 * reconcile_hull_before_move()'s skipover repair has to separate two states that are
 * indistinguishable by the time it looks at them:
 *
 *   - a deck tile of ours that lost its /turf/baseturf_skipover/shuttle to a bookkeeping
 *     fault, which has to get the marker back or the tile - and whatever is standing on
 *     it - is left behind on the next move, and
 *   - the landing site's own ground sitting in one of our areas. A breached tile travels
 *     as MOVE_AREA without MOVE_TURF, so /area/onShuttleMove() hands our area the
 *     planet's dirt at that coordinate while the dirt stays the planet's turf. A tile
 *     breached while already parked lands in the same state from the other direction:
 *     CopyOnTop() only carries the layers above the marker, so a landed deck tile has
 *     the site's ground directly under its skipover and ScrapeAway() takes both, leaving
 *     bare planet floor.
 *
 * Both end as unmarked ground in a registered ship area, and stamping either one makes
 * the hull carry a square of the planet away inside the breach - which is not even hull
 * as far as integrity is concerned, since get_turf_mass_weight_instance() refuses to
 * count a turf isshuttleturf() rejects.
 *
 * The turf's state cannot tell them apart; its history can. A tile we carried to this
 * coordinate that is still the type we set down is ours. Anything else belongs to the
 * site, including the ground a breach scraped down to - a break changes the type, which
 * is exactly the signal a marker lost to bookkeeping does not produce.
 */
/obj/docking_port/mobile/voidcrew/takeoff(list/old_turfs, list/new_turfs, list/moved_atoms, rotation, movement_direction, old_dock, area/fallback_area)
	. = ..()
	carried_hull_types = list()
	for(var/i in 1 to length(old_turfs))
		if(!(old_turfs[old_turfs[i]] & MOVE_TURF))
			continue
		var/turf/landed = new_turfs[i]
		if(!landed)
			continue
		carried_hull_types[landed] = landed.type

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
/obj/docking_port/mobile/voidcrew/proc/restore_collapsed_mount(turf/mount_turf)
	var/obj/machinery/power/shuttle_engine/mounted
	for(var/obj/machinery/power/shuttle_engine/engine in mount_turf)
		if(engine.connected_ship == src)
			mounted = engine
			break
	if(!mounted)
		return FALSE
	var/area/home = mount_turf.loc
	if(!shuttle_areas[home])
		home = null
		for(var/check_dir in GLOB.cardinals)
			var/turf/neighbour = get_step(mount_turf, check_dir)
			var/area/neighbour_area = neighbour?.loc
			if(neighbour_area && shuttle_areas[neighbour_area])
				home = neighbour_area
				break
		if(!home)
			return FALSE
		mount_turf.change_area(mount_turf.loc, home)
	if(isfloorturf(mount_turf))
		// A real deck tile that merely lost its skipover marker - keep it, restamp.
		if(!islist(mount_turf.baseturfs))
			mount_turf.assemble_baseturfs()
		mount_turf.insert_baseturf(min(3, mount_turf.count_baseturfs() + 1), /turf/baseturf_skipover/shuttle)
		log_shuttle("[name]: engine [mounted] at [AREACOORD(mount_turf)] stood on [mount_turf.type] with no skipover - restamped its mount")
	else
		// Bare space or adopted foreign ground - rebuild the mount plating;
		// /area/shuttle/place_on_top_react() stamps the skipover for us.
		log_shuttle("[name]: engine [mounted] at [AREACOORD(mount_turf)] stood on [mount_turf.type] - rebuilding its mount into [home.type]")
		mount_turf.place_on_top(/turf/open/floor/plating/airless)
	return TRUE

/**
 * Makes one engine's mount tile fully move-legal before a move: registered area
 * instance, real deck turf, shuttle skipover. Unlike restore_collapsed_mount() this
 * runs for EVERY connected engine regardless of what the tile currently is, because
 * the degenerate states don't announce themselves - destroyed plating keeps both its
 * baseturfs (so isshuttleturf() still passes on the space turf left behind) and its
 * area, and an orphaned same-name area instance stringifies identically to the
 * registered one.
 */
/obj/docking_port/mobile/voidcrew/proc/repair_engine_mount(obj/machinery/power/shuttle_engine/engine, turf/mount)
	var/area/mount_area = mount.loc
	if(!shuttle_areas[mount_area])
		// Prefer our own registered instance of the same area type (the orphan-split
		// case), then any registered cardinal neighbour (adopted foreign ground).
		var/area/replacement
		for(var/area/own_area as anything in shuttle_areas)
			if(own_area.type != mount_area.type)
				continue
			if(istype(own_area, /area/shuttle/voidcrew))
				var/area/shuttle/voidcrew/own_voidcrew_area = own_area
				if(own_voidcrew_area.shuttle_port && own_voidcrew_area.shuttle_port != src)
					continue // absorbed guest area from a ship-to-ship dock, not ours
			replacement = own_area
			break
		if(!replacement)
			for(var/check_dir in GLOB.cardinals)
				var/turf/neighbour = get_step(mount, check_dir)
				var/area/neighbour_area = neighbour?.loc
				if(neighbour_area && shuttle_areas[neighbour_area])
					replacement = neighbour_area
					break
		if(!replacement)
			log_shuttle("[name]: engine [engine] at [AREACOORD(mount)] sits in unregistered [mount_area.type] [REF(mount_area)] with no registered area adjacent - NOT repairable, it will strand")
			return FALSE
		log_shuttle("[name]: engine [engine] at [AREACOORD(mount)] sat in unregistered [mount_area.type] [REF(mount_area)] - mount reassigned to [replacement.type] [REF(replacement)] before move")
		mount.change_area(mount_area, replacement)
	if(isspaceturf(mount))
		// Even with a skipover in its baseturfs this is a collapsed mount - the engine
		// is standing on nothing. place_on_top_react() stamps a fresh skipover.
		log_shuttle("[name]: engine [engine] at [AREACOORD(mount)] stood on [mount.type] (baseturfs=[islist(mount.baseturfs) ? jointext(mount.baseturfs, " > ") : "[mount.baseturfs]"]) - rebuilding its mount plating")
		mount.place_on_top(/turf/open/floor/plating/airless)
	else if(!isshuttleturf(mount))
		if(!islist(mount.baseturfs))
			mount.assemble_baseturfs()
		mount.insert_baseturf(min(3, mount.count_baseturfs() + 1), /turf/baseturf_skipover/shuttle)
		log_shuttle("[name]: engine [engine] at [AREACOORD(mount)] stood on [mount.type] with no skipover - restamped its mount")
	return TRUE

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
	// Engine census: the turf census above is blind to a tile that stranded in an
	// ORPHANED area instance (round 811's Pill) - the engine roster isn't.
	for(var/obj/machinery/power/shuttle_engine/engine as anything in engine_list)
		var/turf/engine_turf = get_turf(engine)
		if(!engine_turf)
			continue
		if(engine_turf.z >= z - z_levels_below && engine_turf.z <= z + z_levels_above)
			continue
		var/area/engine_area = engine_turf.loc
		log_shuttle("[name]: engine [engine] left behind at [AREACOORD(engine_turf)] on [engine_turf.type] in [engine_area.type] [REF(engine_area)] after moving to z=[z]")
	// Moving into transit asserts a preferred_direction scroll on our areas
	// (shuttle_move.dm); reconcile it with the ship's real speed - a ship with no
	// thrust should show a still starfield, not a drifting one
	if(current_ship && istype(get_docked(), /obj/docking_port/stationary/transit))
		current_ship.update_flight_parallax()
	// Initialize space turfs if we're docking to empty space
	if(current_ship && istype(current_ship.docked, /obj/structure/overmap/planet/empty))
		current_ship.initialize_nearby_space_turfs()
	return ..()

/**
 * Claims this hull's z-levels (and its site) so ZTRAIT_STATION reflects who is actually here.
 *
 * Idempotent, and it has to be: calculate_docking_port_information() calls this on every hull
 * expansion and every port reseat, not only on arrival, so a claim that counted each call
 * would never drain back to zero. Only levels we are not already holding are claimed, and any
 * level we hold but no longer stand on is released.
 */
/obj/docking_port/mobile/voidcrew/proc/link_to_z_level()
	GLOB.the_station_areas |= shuttle_areas

	var/list/wanted = list()
	for(var/z_level in (z - z_levels_below) to (z + z_levels_above))
		if(z_level < 1 || z_level > world.maxz)
			continue
		wanted += z_level

	// Swapped in before the diff runs, not after: a reconcile triggered from inside either
	// loop counts hulls off this var, and it has to already say what we hold.
	var/list/previous = linked_z_levels
	linked_z_levels = wanted
	for(var/z_level in previous)
		if(z_level in wanted)
			continue
		release_station_level_link(z_level)
	for(var/z_level in wanted)
		if(z_level in previous)
			continue
		claim_station_level_link(z_level)
	set_site_occupancy(map_region_for_turf(get_turf(src)))

/**
 * Releases every z-level and site claim this hull holds.
 *
 * No longer gated on a beforeShuttleMove() snapshot. That gate meant the only path that ever
 * released anything was a MOVE: a hull destroyed or despawned while docked ran this, found no
 * snapshot and returned, so its encounter's z stayed ZTRAIT_STATION forever - and on a packed
 * level that ground is dealt to three unrelated neighbours and then to the next tenant.
 * Clearing our own claims BEFORE releasing them keeps reconcile_ship_station_levels() honest
 * if it has to run from inside the release.
 */
/obj/docking_port/mobile/voidcrew/proc/unlink_from_z_level()
	set_site_occupancy(null)
	if(!length(linked_z_levels))
		return

	GLOB.the_station_areas -= shuttle_areas
	for(var/area/area as anything in shuttle_areas)
		// A null left by a hard-deleted area would runtime here and abort the release
		// below, leaving this hull's z-level claim - and its ZTRAIT_STATION flag - held
		// for the rest of the round. That is the exact leak this proc exists to close.
		if(!istype(area))
			continue
		area.area_flags &= ~VALID_TERRITORY // don't want anyone dropped in mid shuttle move

	var/list/releasing = linked_z_levels
	linked_z_levels = list()
	for(var/z_level in releasing)
		release_station_level_link(z_level)

/// Adds one hull to `z_level`'s occupancy, flagging it ZTRAIT_STATION if we are the first.
/// A level that is already a station level for any other reason is left alone and never
/// recorded as ours, so a mapped station level can never be un-flagged by a ship leaving it.
/obj/docking_port/mobile/voidcrew/proc/claim_station_level_link(z_level)
	var/key = "[z_level]"
	var/count = GLOB.ship_z_level_links[key]
	GLOB.ship_z_level_links[key] = count + 1
	if(count)
		return
	if(is_station_level(z_level))
		return
	SSmapping.z_trait_levels[ZTRAIT_STATION] += list(z_level)
	LISTASSERTLEN(GLOB.station_levels_cache, z_level, FALSE)
	GLOB.station_levels_cache[z_level] = TRUE
	GLOB.ship_added_station_levels[key] = TRUE

/// Drops one hull from `z_level`'s occupancy, un-flagging the level when the last one leaves.
/obj/docking_port/mobile/voidcrew/proc/release_station_level_link(z_level)
	var/key = "[z_level]"
	var/count = GLOB.ship_z_level_links[key]
	if(count > 1)
		GLOB.ship_z_level_links[key] = count - 1
		return
	if(!count)
		// Our claim is not in the register at all. Somebody released it for us, or a link was
		// never recorded - either way the counts are no longer describable from here, so do a
		// full recount rather than guessing at the trait.
		log_shuttle("[name]: station-level claim for z=[z_level] was already gone when unlinking - reconciling")
		reconcile_ship_station_levels()
		return
	GLOB.ship_z_level_links -= key
	if(!GLOB.ship_added_station_levels[key])
		return // the trait came from the map config, not from a hull
	// Second opinion before the flag comes off. A missed claim anywhere would otherwise strip
	// stationloving out from under a ship that is still parked on this level.
	if(SEND_GLOBAL_SIGNAL(COMSIG_GLOB_Z_SHIP_PROBE, src, z_level))
		reconcile_ship_station_levels()
		return
	GLOB.ship_added_station_levels -= key
	SSmapping.z_trait_levels[ZTRAIT_STATION] -= list(z_level)
	LISTASSERTLEN(GLOB.station_levels_cache, z_level, FALSE)
	GLOB.station_levels_cache[z_level] = FALSE

/// Moves this hull's entry in the per-site occupancy register to `new_region` (or off it).
/obj/docking_port/mobile/voidcrew/proc/set_site_occupancy(datum/new_region)
	var/new_key = isnull(new_region) ? null : REF(new_region)
	if(occupied_site_key == new_key)
		return
	if(occupied_site_key)
		var/count = GLOB.ship_site_occupancy[occupied_site_key]
		if(count > 1)
			GLOB.ship_site_occupancy[occupied_site_key] = count - 1
		else
			GLOB.ship_site_occupancy -= occupied_site_key
	occupied_site_key = new_key
	if(!new_key)
		return
	GLOB.ship_site_occupancy[new_key] += 1

/**
 * ##respond_to_z_port_probe
 *
 * Sent by another docking port that is releasing its claim on a z-level, as a cross-check
 * against the reference count in GLOB.ship_z_level_links. This is our response, to prevent a
 * level being removed from the list of station areas if we are still here.
 *
 * Tests the hull's whole linked range rather than bare z equality: a multi-z hull holds every
 * level it spans, and answering only for its own centre would let one of them be un-flagged.
 * Args:
 * source - The docking port that's leaving
 * z_level - the z level that source is leaving from.
 */
/obj/docking_port/mobile/voidcrew/proc/respond_to_z_port_probe(atom/source, obj/docking_port/mobile/voidcrew/leaving, z_level)
	SIGNAL_HANDLER
	if(src == leaving || QDELETED(src))
		return FALSE
	return !!(z_level >= (z - z_levels_below) && z_level <= (z + z_levels_above))

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
