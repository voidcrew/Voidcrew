/**
 * Creates people's characters for ROUNDSTART ONLY
 * Assigns jobs based on ship category preferences, then spawns them on the roundstart ship.
 * Latejoining is handled differently via the ship selection menu.
 *
 * Job assignment priority:
 * 1. Try to match player to a job in a category they set to JP_HIGH
 * 2. Try to match player to a job in a category they set to JP_MEDIUM
 * 3. Try to match player to a job in a category they set to JP_LOW
 * 4. Fall back to random available job on the ship
 */
/datum/controller/subsystem/ticker/create_characters()
	var/obj/structure/overmap/ship/roundstart_ship = SSovermap.simulated_ships[1]
	if(!roundstart_ship)
		CRASH("There's no roundstart ship for jobs to spawn on!")

	// Build list of ready players
	var/list/mob/dead/new_player/ready_players = list()
	for(var/mob/dead/new_player/player as anything in GLOB.new_player_list)
		if(player.ready == PLAYER_READY_TO_PLAY && player.mind)
			ready_players += player

	// Shuffle to randomize who gets priority for contested positions
	shuffle_inplace(ready_players)

	// Assign jobs by priority level
	var/list/unassigned_players = ready_players.Copy()

	// Priority levels in order
	var/list/priority_levels = list(JP_HIGH, JP_MEDIUM, JP_LOW)

	for(var/priority in priority_levels)
		for(var/mob/dead/new_player/player as anything in unassigned_players)
			var/datum/job/matched_job = find_job_by_category_preference(player, roundstart_ship, priority)
			if(matched_job)
				if(assign_player_to_ship_job(player, matched_job, roundstart_ship))
					unassigned_players -= player
			CHECK_TICK

	// Fallback: Assign random jobs to remaining players
	for(var/mob/dead/new_player/player as anything in unassigned_players)
		var/datum/job/random_job = get_random_available_job(roundstart_ship)
		if(random_job)
			assign_player_to_ship_job(player, random_job, roundstart_ship)
		else
			// No jobs left - player will have to latejoin
			to_chat(player, span_warning("All positions on the roundstart ship are filled. You can join via the latejoin menu once the round starts."))
		CHECK_TICK

/**
 * Finds a job matching a player's category preference at the given priority level
 * Returns the job datum if found, null otherwise
 */
/datum/controller/subsystem/ticker/proc/find_job_by_category_preference(mob/dead/new_player/player, obj/structure/overmap/ship/ship, priority_level)
	if(!player.client?.prefs)
		return null

	var/list/category_prefs = player.client.prefs.ship_category_preferences
	if(!length(category_prefs))
		return null

	// Build list of categories at this priority level
	var/list/matching_categories = list()
	for(var/category in category_prefs)
		if(category_prefs[category] == priority_level)
			matching_categories += category

	if(!length(matching_categories))
		return null

	// Find available jobs in matching categories
	var/list/possible_jobs = list()
	for(var/datum/job/job as anything in ship.job_slots)
		if(ship.job_slots[job] <= 0)
			continue
		if(job.job_category in matching_categories)
			possible_jobs += job

	if(!length(possible_jobs))
		return null

	// Return a random job from possible matches
	return pick(possible_jobs)

/**
 * Gets a random available job from the ship
 */
/datum/controller/subsystem/ticker/proc/get_random_available_job(obj/structure/overmap/ship/ship)
	var/list/jobs_with_slots = list()
	for(var/datum/job/job as anything in ship.job_slots)
		if(ship.job_slots[job] > 0)
			jobs_with_slots += job

	if(!length(jobs_with_slots))
		return null

	return pick(jobs_with_slots)

/**
 * Assigns a player to a ship job and spawns them
 * Returns TRUE on success, FALSE on failure
 */
/datum/controller/subsystem/ticker/proc/assign_player_to_ship_job(mob/dead/new_player/player, datum/job/job, obj/structure/overmap/ship/ship)
	if(!player || !job || !ship)
		return FALSE

	// Add to joined player list
	GLOB.joined_player_list += player.ckey

	// Use the existing AttemptSpawnOnShip which handles role assignment, slot decrementing, and spawning
	return player.AttemptSpawnOnShip(job, ship)
