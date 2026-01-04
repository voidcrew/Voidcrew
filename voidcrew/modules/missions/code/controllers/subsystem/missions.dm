/**
 * # Missions Subsystem
 *
 * Manages mission generation, tracking, and timeout handling.
 * Generates available missions for ships periodically.
 */
SUBSYSTEM_DEF(missions)
	name = "Missions"
	wait = 30 SECONDS
	flags = SS_BACKGROUND

	/// List of all currently active missions across all ships
	var/list/datum/mission/all_active_missions = list()

	/// List of mission types that can be randomly generated
	var/list/mission_types = list()

/datum/controller/subsystem/missions/Initialize()

	// Build list of mission types from subtypes
	for(var/mission_type in subtypesof(/datum/mission))
		var/datum/mission/M = mission_type
		if(initial(M.weight) > 0)
			mission_types += mission_type

	return SS_INIT_SUCCESS

/datum/controller/subsystem/missions/fire(resumed)
	// Check for mission timeouts (handled by individual mission timers, but we can do cleanup here)
	for(var/datum/mission/mission as anything in all_active_missions)
		if(QDELETED(mission))
			all_active_missions -= mission
			continue

	// Refresh available missions for all ships
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(QDELETED(ship))
			continue
		refresh_ship_missions(ship)

/**
 * Fills a ship's available missions list up to the default count.
 * * ship - The ship to refresh missions for
 */
/datum/controller/subsystem/missions/proc/refresh_ship_missions(obj/structure/overmap/ship/ship)
	if(!ship)
		return

	// Remove any null/deleted missions from available list
	for(var/datum/mission/mission as anything in ship.available_missions)
		if(QDELETED(mission))
			ship.available_missions -= mission

	// Fill up to default count
	var/missions_needed = DEFAULT_AVAILABLE_MISSIONS - length(ship.available_missions)
	for(var/i in 1 to missions_needed)
		var/datum/mission/new_mission = generate_random_mission()
		if(new_mission)
			ship.available_missions += new_mission

/**
 * Generates a random mission based on weighted selection.
 * Returns a new mission datum, or null if none available.
 */
/datum/controller/subsystem/missions/proc/generate_random_mission()
	var/mission_type = get_weighted_mission_type()
	if(!mission_type)
		return null
	return create_mission(mission_type)

/**
 * Selects a random mission type based on weight.
 * Respects mission_limit for types that have caps.
 */
/datum/controller/subsystem/missions/proc/get_weighted_mission_type()
	if(!length(mission_types))
		return null

	var/list/weighted_types = list()
	for(var/mission_type in mission_types)
		var/datum/mission/M = mission_type
		var/type_weight = initial(M.weight)
		var/type_limit = initial(M.mission_limit)

		// Check mission limit
		if(type_limit > 0)
			var/active_count = 0
			for(var/datum/mission/active in all_active_missions)
				if(active.type == mission_type)
					active_count++
			if(active_count >= type_limit)
				continue

		weighted_types[mission_type] = type_weight

	if(!length(weighted_types))
		return null

	return pick_weight(weighted_types)

/**
 * Creates a new mission of the specified type.
 * * mission_type - The type path of the mission to create
 */
/datum/controller/subsystem/missions/proc/create_mission(mission_type)
	if(!mission_type)
		return null
	return new mission_type()

/**
 * Force-generates new available missions for a specific ship.
 * Clears existing available missions and generates fresh ones.
 * * ship - The ship to regenerate missions for
 */
/datum/controller/subsystem/missions/proc/force_refresh_ship_missions(obj/structure/overmap/ship/ship)
	if(!ship)
		return

	// Delete existing available missions
	for(var/datum/mission/mission as anything in ship.available_missions)
		if(!QDELETED(mission))
			qdel(mission)
	ship.available_missions = list()

	// Generate new missions
	for(var/i in 1 to DEFAULT_AVAILABLE_MISSIONS)
		var/datum/mission/new_mission = generate_random_mission()
		if(new_mission)
			ship.available_missions += new_mission

/**
 * Gets the count of active missions of a specific type.
 * * mission_type - The type path to count
 */
/datum/controller/subsystem/missions/proc/get_active_count_of_type(mission_type)
	var/count = 0
	for(var/datum/mission/mission as anything in all_active_missions)
		if(!QDELETED(mission) && mission.type == mission_type)
			count++
	return count
