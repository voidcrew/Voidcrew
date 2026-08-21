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
	// Backstop sweep only - /datum/mission/Destroy() takes itself out of this list now, so
	// reaching here means something was deleted without running Destroy at all. Walked
	// backwards because removing from a list mid-iteration shifts every later element down
	// one and the forward form silently skipped the entry after each removal.
	for(var/i in length(all_active_missions) to 1 step -1)
		if(QDELETED(all_active_missions[i]))
			all_active_missions.Cut(i, i + 1)

	// Refresh available missions for all ships. CHECK_TICK between hulls: this is a
	// SS_BACKGROUND subsystem on a 30 s period with a dozen-plus hulls to visit, and
	// nothing in here is resumable, so without a yield point one fire runs the whole
	// fleet inside a single tick and overruns its allocation on every fire.
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(QDELETED(ship))
			continue
		refresh_ship_missions(ship)
		CHECK_TICK

/**
 * Fills a ship's available missions list up to the default count.
 * * ship - The ship to refresh missions for
 */
/datum/controller/subsystem/missions/proc/refresh_ship_missions(obj/structure/overmap/ship/ship)
	if(!ship)
		return
	// NPC ships never read their board; don't generate (and churn ruin refs) for them
	if(istype(ship, /obj/structure/overmap/ship/npc))
		return

	// Remove deleted missions and rotate out offers that sat unaccepted too long
	for(var/datum/mission/mission as anything in ship.available_missions)
		if(QDELETED(mission))
			ship.available_missions -= mission
			continue
		if(world.time - mission.posted_at > MISSION_BOARD_EXPIRY)
			ship.available_missions -= mission
			qdel(mission)

	// Fill up to default count
	var/missions_needed = DEFAULT_AVAILABLE_MISSIONS - length(ship.available_missions)
	// Asked once and reused: the lookup walks the hull for an R&D server the
	// first time it misses, and five offers is five walks.
	var/unarmed = !ship.has_ship_combat_research()
	for(var/i in 1 to missions_needed)
		var/datum/mission/new_mission = generate_random_mission(roll_offer_zone_preference(unarmed))
		if(new_mission)
			ship.available_missions += new_mission

/**
 * The zone band the next offer should prefer, rolled per offer.
 *
 * A ship with no Shuttle Warfare Systems research has nothing to fight or tank
 * with, so most of its board points at Neutral space. Rolled per offer rather
 * than per board so the five slots come out mixed - see
 * MISSION_UNARMED_GREEN_BIAS_PROB for why it isn't all five.
 */
/datum/controller/subsystem/missions/proc/roll_offer_zone_preference(unarmed)
	if(!unarmed)
		return null
	return prob(MISSION_UNARMED_GREEN_BIAS_PROB) ? ZONE_GREEN : null

/**
 * Generates a random mission based on weighted selection.
 * Returns a new mission datum, or null if none available.
 * * preferred_zone - ZONE_* band the offer should aim at where it can, or null
 */
/datum/controller/subsystem/missions/proc/generate_random_mission(preferred_zone)
	var/mission_type = get_weighted_mission_type()
	if(!mission_type)
		return null
	return create_mission(mission_type, preferred_zone)

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
/datum/controller/subsystem/missions/proc/create_mission(mission_type, preferred_zone)
	if(!mission_type)
		return null
	var/datum/mission/mission = new mission_type(null, preferred_zone)
	// Some mission types (e.g. recovery) can fail generation if no valid target exists
	if(mission.generation_failed)
		qdel(mission)
		return null
	return mission

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
	var/unarmed = !ship.has_ship_combat_research()
	for(var/i in 1 to DEFAULT_AVAILABLE_MISSIONS)
		var/datum/mission/new_mission = generate_random_mission(roll_offer_zone_preference(unarmed))
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
