/**
 * Creates people's characters for ROUNDSTART ONLY
 * Assigns jobs based on ship category preferences, then spawns them on the roundstart ship.
 * Latejoining is handled differently via the ship selection menu.
 *
 * Job assignment priority:
 * 1. Ensure the ship gets a captain: contested by Command category preference (high > medium > low),
 *    ties broken randomly. If nobody wants Command, a random ready player is drafted.
 * 2. Try to match each remaining player to a job in a category they set to JP_HIGH
 * 3. Try to match player to a job in a category they set to JP_MEDIUM
 * 4. Try to match player to a job in a category they set to JP_LOW
 * 5. Fall back to random available job on the ship
 * 6. If every slot on the ship is taken, open an extra slot on the ship's assistant-equivalent
 *    job so nobody readies up and then gets dropped.
 */
/datum/controller/subsystem/ticker/create_characters()
	var/obj/structure/overmap/ship/roundstart_ship = SSovermap.initial_ship
	if(!roundstart_ship)
		CRASH("There's no roundstart ship for jobs to spawn on!")

	// Build list of ready players
	var/list/mob/dead/new_player/ready_players = list()
	for(var/mob/dead/new_player/player as anything in GLOB.new_player_list)
		if(player.ready == PLAYER_READY_TO_PLAY && player.mind)
			ready_players += player

	if(!length(ready_players))
		return

	// Shuffle to randomize who gets priority for contested positions
	shuffle_inplace(ready_players)

	// Assign jobs by priority level
	var/list/unassigned_players = ready_players.Copy()

	// Guarantee a captain before general assignment so the ship never launches leaderless
	var/mob/dead/new_player/chosen_captain = assign_roundstart_captain(unassigned_players, roundstart_ship)
	if(chosen_captain)
		unassigned_players -= chosen_captain

	// Priority levels in order
	var/list/priority_levels = list(JP_HIGH, JP_MEDIUM, JP_LOW)

	for(var/priority in priority_levels)
		// Iterate a snapshot: removing the current entry from the list being iterated skips the next player
		for(var/mob/dead/new_player/player as anything in unassigned_players.Copy())
			if(QDELETED(player) || !player.client)
				unassigned_players -= player
				continue
			var/datum/job/matched_job = find_job_by_category_preference(player, roundstart_ship, priority)
			if(matched_job)
				if(assign_player_to_ship_job(player, matched_job, roundstart_ship))
					unassigned_players -= player
			CHECK_TICK

	// Fallback: Assign random jobs to remaining players
	for(var/mob/dead/new_player/player as anything in unassigned_players.Copy())
		if(QDELETED(player) || !player.client)
			unassigned_players -= player
			continue
		if(try_assign_any_job(player, roundstart_ship))
			unassigned_players -= player
		CHECK_TICK

	// Last resort: every slot is taken - open extra slots on the ship's most junior job
	// so ready players are never dropped from the round entirely.
	for(var/mob/dead/new_player/player as anything in unassigned_players.Copy())
		if(QDELETED(player) || !player.client)
			unassigned_players -= player
			continue
		var/datum/job/overflow_job = get_overflow_job(roundstart_ship)
		if(!overflow_job)
			to_chat(player, span_warning("All positions on the roundstart ship are filled. You can join via the latejoin menu once the round starts."))
			continue
		// AttemptSpawnOnShip consumes a slot, so open one up first; take it back if spawning fails
		roundstart_ship.job_slots[overflow_job]++
		if(assign_player_to_ship_job(player, overflow_job, roundstart_ship))
			unassigned_players -= player
		else
			roundstart_ship.job_slots[overflow_job]--
			to_chat(player, span_warning("All positions on the roundstart ship are filled. You can join via the latejoin menu once the round starts."))
		CHECK_TICK

/**
 * Guarantees the roundstart ship spawns with a captain (its officer job).
 *
 * Selection order: players who set the Command category to JP_HIGH, then JP_MEDIUM, then JP_LOW,
 * then (if nobody wants Command) anyone. The candidate list is pre-shuffled, so ties within a
 * preference level are broken by fair random pick. Ineligible players (job bans etc.) are skipped.
 *
 * Returns the player who was spawned as captain, or null if there is no open officer job
 * or no eligible candidate.
 */
/datum/controller/subsystem/ticker/proc/assign_roundstart_captain(list/candidate_players, obj/structure/overmap/ship/ship)
	// Find the ship's officer (captain) job with an open slot
	var/datum/job/captain_job
	for(var/datum/job/job as anything in ship.job_slots)
		if(job.officer && ship.job_slots[job] > 0)
			captain_job = job
			break
	if(!captain_job)
		return null

	// Bucket candidates by their Command category preference level
	var/list/high_candidates = list()
	var/list/medium_candidates = list()
	var/list/low_candidates = list()
	var/list/drafted_candidates = list()
	for(var/mob/dead/new_player/player as anything in candidate_players)
		if(QDELETED(player) || !player.client)
			continue
		var/list/category_prefs = player.client.prefs?.ship_category_preferences
		var/command_pref = length(category_prefs) ? category_prefs[JOB_CAT_COMMAND] : null
		switch(command_pref)
			if(JP_HIGH)
				high_candidates += player
			if(JP_MEDIUM)
				medium_candidates += player
			if(JP_LOW)
				low_candidates += player
			else
				drafted_candidates += player

	for(var/list/bucket in list(high_candidates, medium_candidates, low_candidates, drafted_candidates))
		var/was_drafted = (bucket == drafted_candidates)
		for(var/mob/dead/new_player/player as anything in bucket)
			// Pre-check eligibility so we quietly move on to the next candidate instead of
			// popping error dialogs from a failed assignment
			if(SSjob.check_job_eligibility(player, captain_job, "RoundstartCaptain") != JOB_AVAILABLE)
				continue
			// check_job_eligibility can sleep on the ban DB - revalidate the player
			if(QDELETED(player) || !player.client)
				continue
			// The new_player mob is deleted once the character spawns - grab the mind now
			var/datum/mind/captain_mind = player.mind
			if(!assign_player_to_ship_job(player, captain_job, ship))
				continue
			if(was_drafted)
				to_chat(captain_mind?.current, span_boldnotice("Nobody readied up with Command preferences, so you have been drafted as the ship's [captain_job.title]."))
			log_game("Roundstart captain: [captain_mind?.key] assigned as [captain_job.title] of [ship.name][was_drafted ? " (drafted - no Command preferences among ready players)" : ""].")
			return player
	return null

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
 * Tries to assign the player to any job on the ship with open slots, in random order.
 * Trying every job (rather than a single random pick) means a player who is ineligible
 * for one job (e.g. job banned) still ends up with another one.
 * Returns TRUE if the player was assigned and spawned, FALSE otherwise.
 */
/datum/controller/subsystem/ticker/proc/try_assign_any_job(mob/dead/new_player/player, obj/structure/overmap/ship/ship)
	var/list/jobs_with_slots = list()
	for(var/datum/job/job as anything in ship.job_slots)
		if(ship.job_slots[job] > 0)
			jobs_with_slots += job

	shuffle_inplace(jobs_with_slots)
	for(var/datum/job/job as anything in jobs_with_slots)
		if(assign_player_to_ship_job(player, job, ship))
			return TRUE
	return FALSE

/**
 * Picks the job that overflow players are stuffed into when every slot on the ship is taken.
 * Prefers an assistant-category job, then the most junior (last listed) non-officer job.
 * Never returns the officer job - a ship should not end up with two captains.
 */
/datum/controller/subsystem/ticker/proc/get_overflow_job(obj/structure/overmap/ship/ship)
	var/datum/job/junior_job
	for(var/datum/job/job as anything in ship.job_slots)
		if(job.officer)
			continue
		if(job.job_category == JOB_CAT_ASSISTANT)
			return job
		junior_job = job
	return junior_job

/**
 * Assigns a player to a ship job and spawns them
 * Returns TRUE on success, FALSE on failure
 */
/datum/controller/subsystem/ticker/proc/assign_player_to_ship_job(mob/dead/new_player/player, datum/job/job, obj/structure/overmap/ship/ship)
	if(!player || !job || !ship)
		return FALSE

	// AttemptSpawnOnShip handles role assignment, slot decrementing, spawning,
	// and adding the player to GLOB.joined_player_list
	return player.AttemptSpawnOnShip(job, ship)
