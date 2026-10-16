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
 * Replaces a ship's fixed offer set only when its scheduled refresh is due.
 * * ship - The ship to refresh missions for
 */
/datum/controller/subsystem/missions/proc/refresh_ship_missions(obj/structure/overmap/ship/ship)
	if(!ship)
		return
	// NPC ships never read their board; don't generate (and churn ruin refs) for them
	if(istype(ship, /obj/structure/overmap/ship/npc))
		return

	// Deletion leaves a vacancy, not a retained reference or an early replacement.
	for(var/index in length(ship.available_missions) to 1 step -1)
		if(QDELETED(ship.available_missions[index]))
			ship.available_missions.Cut(index, index + 1)
	if(world.time < ship.next_mission_refresh)
		return FALSE
	// Claim the schedule before generation, so console rebuilds and vacant slots cannot reroll it.
	ship.next_mission_refresh = world.time + MISSION_REFRESH_COOLDOWN
	ship.last_mission_refresh = world.time
	for(var/datum/mission/mission as anything in ship.available_missions)
		if(!QDELETED(mission))
			tally_mission_offer(mission, ship, "mission_offer_expired") // round metrics, voidcrew/modules/metrics/mission_metrics.dm
			qdel(mission)
	ship.available_missions = list()

	// Reserve one of the existing slots before rolling the rest of the board.
	ensure_safe_exploration_offer(ship)
	var/reserved_vacancies = reserve_useful_family_offers(ship)
	var/list/eligible_zones = eligible_work_bands(ship)
	// Asked once and reused: the lookup walks the hull for an R&D server the
	// first time it misses, and five offers is five walks.
	var/unarmed = !ship.has_ship_combat_research()
	var/posting_zone = SSovermap_zones?.get_zone_type(get_turf(ship))
	// Resolve failed rolls inside this scheduled batch; never retry vacancies afterward.
	var/attempts_left = DEFAULT_AVAILABLE_MISSIONS * 10
	while(length(ship.available_missions) + reserved_vacancies < DEFAULT_AVAILABLE_MISSIONS && attempts_left-- > 0)
		var/datum/mission/new_mission = generate_random_mission(roll_offer_zone_preference(unarmed), posting_zone, eligible_zones)
		if(new_mission)
			ship.available_missions += new_mission
			tally_mission_offer(new_mission, ship, "mission_offered") // round metrics, voidcrew/modules/metrics/mission_metrics.dm
	return TRUE

/datum/controller/subsystem/missions/proc/eligible_work_bands(obj/structure/overmap/ship/ship)
	var/list/bands = list(ZONE_GREEN)
	var/datum/voidcrew_crew_record/record = ship.get_crew_record()
	for(var/band in list(ZONE_YELLOW, ZONE_RED))
		if(record?.can_work_in_zone(band))
			bands += band
	return bands

/// Earliest unmet cumulative band; elite crews no longer need reserved work.
/datum/controller/subsystem/missions/proc/next_work_band(datum/voidcrew_crew_record/record)
	switch(record?.get_zone_permission())
		if(ZONE_PERMISSION_YELLOW)
			return ZONE_YELLOW
		if(ZONE_PERMISSION_ADVANCED)
			return ZONE_RED
		if(ZONE_PERMISSION_ELITE)
			return null
	return ZONE_GREEN

/// Returns reserved vacancies, which ordinary rolls must not silently replace.
/datum/controller/subsystem/missions/proc/reserve_useful_family_offers(obj/structure/overmap/ship/ship)
	var/datum/voidcrew_crew_record/record = ship.get_crew_record()
	var/band = next_work_band(record)
	if(isnull(band))
		return 0
	var/list/families = list()
	var/list/contributions = record?.zone_families["[band]"]
	var/cap = band == ZONE_GREEN ? ZONE_REPUTATION_GREEN_FAMILY_CAP : ZONE_REPUTATION_DANGER_FAMILY_CAP
	for(var/mission_type in mission_types)
		var/family = zone_reputation_family(mission_type)
		if(!family || (contributions && contributions[family] >= cap))
			continue
		LAZYINITLIST(families[family])
		families[family] += mission_type
	var/vacancies = 0
	var/reserved_slots = min(3, length(families))
	for(var/slot in 1 to reserved_slots)
		var/family = pick(families)
		var/list/types = families[family]
		families -= family
		var/datum/mission/offer
		var/attempts = 8
		while(!offer && attempts-- > 0)
			var/mission_type = pick(types)
			if(!mission_type_within_limit(mission_type))
				types -= mission_type
				if(!length(types))
					break
				continue
			offer = create_mission(mission_type, band, null, list(band), TRUE)
		if(!offer)
			vacancies++
			log_mapping("SSmissions: ship [REF(ship)] reserved [family] in band [band] has no eligible offer after bounded retries")
			continue
		ship.available_missions += offer
		tally_mission_offer(offer, ship, "mission_offered")
	return vacancies

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
/datum/controller/subsystem/missions/proc/generate_random_mission(preferred_zone, posting_zone, list/eligible_zones)
	var/mission_type = get_weighted_mission_type()
	if(!mission_type)
		return null
	return create_mission(mission_type, preferred_zone, posting_zone, eligible_zones)

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
		if(!mission_type_within_limit(mission_type))
			continue

		weighted_types[mission_type] = type_weight

	if(!length(weighted_types))
		return null

	return pick_weight(weighted_types)

/**
 * Creates a new mission of the specified type.
 * * mission_type - The type path of the mission to create
 */
/datum/controller/subsystem/missions/proc/create_mission(mission_type, preferred_zone, posting_zone, list/eligible_zones, create_field_contact = FALSE)
	if(!mission_type)
		return null
	var/datum/mission/mission = new mission_type(null, preferred_zone, posting_zone, eligible_zones, create_field_contact)
	// Some mission types (e.g. recovery) can fail generation if no valid target exists
	if(mission.generation_failed)
		qdel(mission)
		return null
	return mission

/**
 * Requests a scheduled refresh for a specific ship; never bypasses its timer.
 * * ship - The ship to regenerate missions for
 */
/datum/controller/subsystem/missions/proc/force_refresh_ship_missions(obj/structure/overmap/ship/ship)
	if(!ship || istype(ship, /obj/structure/overmap/ship/npc))
		return

	return refresh_ship_missions(ship)

/// Retain or reserve one valid green travel job; never exceed the board's five slots.
/datum/controller/subsystem/missions/proc/ensure_safe_exploration_offer(obj/structure/overmap/ship/ship)
	for(var/datum/mission/exploration/offer in ship.available_missions)
		if(!QDELETED(offer) && !offer.generation_failed && !offer.active && offer.target?.is_valid() && offer.target.get_zone_type() == ZONE_GREEN)
			return TRUE
	if(!mission_type_within_limit(/datum/mission/exploration))
		return FALSE
	var/datum/mission/exploration/safe_offer = create_mission(/datum/mission/exploration, ZONE_GREEN)
	if(!safe_offer)
		return FALSE // No valid green coordinates: retain the existing board.
	if(!safe_offer.target?.is_valid() || safe_offer.target.get_zone_type() != ZONE_GREEN)
		qdel(safe_offer)
		return FALSE
	if(length(ship.available_missions) >= DEFAULT_AVAILABLE_MISSIONS)
		var/datum/mission/replaced = ship.available_missions[length(ship.available_missions)]
		ship.available_missions -= replaced
		qdel(replaced)
	ship.available_missions += safe_offer
	tally_mission_offer(safe_offer, ship, "mission_offered") // round metrics, voidcrew/modules/metrics/mission_metrics.dm
	return TRUE

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
