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

/obj/docking_port/mobile/voidcrew/beforeShuttleMove(turf/newT, rotation, move_mode, obj/docking_port/mobile/moving_dock)
	old_z_level = z
	return ..()

/obj/docking_port/mobile/voidcrew/afterShuttleMove(turf/oldT, list/movement_force, shuttle_dir, shuttle_preferred_direction, move_dir, rotation)
	unlink_from_z_level()
	link_to_z_level()
	recalculate_shuttle_areas() // this also readds VALID_TERRITORY
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
