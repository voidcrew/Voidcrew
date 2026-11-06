/// Backgrounds: owned by P2.

/**
 * # Convict
 *
 * An escaped prisoner of the Meridian Penitentiary. One scenario is rolled for each group that
 * starts together (all of roundstart, or one latejoiner):
 * - Cell: a bolted escape cell in Cell Block D, a guard's dropped tools under the bunk;
 * - Massacre: the pod bay's processing room, its officers dead around them (dressed once a round);
 * - Adrift: already out in a launched pod, two to a pod.
 * Each falls back to the next when it runs out of room: Massacre once dressed and Adrift out of
 * pods fall to Cell, Cell overflows onto the massacre spots, then the start fails [SPA-1, ECO-5].
 *
 * The goal comes from the crime (convict_crimes.dm); the warrant, the haul, the stash and the
 * witness are made when the background starts.
 */

/datum/background/convict
	key = BACKGROUND_CONVICT
	name = "Convict"
	site = TRUE
	/// The one Convict job every convict starts in
	var/datum/job/convict_job
	/// The 30-second goal check
	var/tick_timer

/// `ckey`'s ledger entry this round ("paid", "pods", "haul", "stash" ...), made if missing
/proc/convict_ledger(ckey)
	if(!ckey)
		return list()
	var/list/entry = GLOB.background_ledger[ckey]
	if(!islist(entry))
		entry = list()
		GLOB.background_ledger[ckey] = entry
	return entry

/datum/background/convict/proc/get_convict_job()
	if(!convict_job)
		var/list/slots = assemble_job_slots_from_list(list(list(name = "Convict", outfit = /datum/outfit/job/prisoner, category = JOB_CAT_ASSISTANT, slots = 99)))
		if(length(slots))
			convict_job = slots[1]
	return convict_job

/// One scenario for a group, by BACKGROUND_CONVICT_WEIGHT_*
/datum/background/convict/proc/roll_scenario()
	var/roll = rand(1, BACKGROUND_CONVICT_WEIGHT_CELL + BACKGROUND_CONVICT_WEIGHT_MASSACRE + BACKGROUND_CONVICT_WEIGHT_ADRIFT)
	if(roll <= BACKGROUND_CONVICT_WEIGHT_CELL)
		return BACKGROUND_CONVICT_SCENARIO_CELL
	if(roll <= BACKGROUND_CONVICT_WEIGHT_CELL + BACKGROUND_CONVICT_WEIGHT_MASSACRE)
		return BACKGROUND_CONVICT_SCENARIO_MASSACRE
	return BACKGROUND_CONVICT_SCENARIO_ADRIFT

/// The scenario an admin forced for this lobby player, if any, cleared as it is read
/datum/background/convict/proc/take_forced_scenario(mob/dead/new_player/player)
	if(QDELETED(player))
		return null
	. = player.background_forced_scenario
	player.background_forced_scenario = null

// ===== STARTS =====

/datum/background/convict/roundstart(list/mob/dead/new_player/players)
	return start_group(players, roll_scenario())

/datum/background/convict/latejoin_options(mob/dead/new_player/player)
	return list(list(
		"id" = BACKGROUND_CONVICT,
		"kind" = BACKGROUND_CONVICT,
		"name" = "Meridian Penitentiary",
		"detail" = null,
		"crew" = null,
		"refusal" = latejoin_refusal(player),
	))

/// "Full" when the Meridian has no escape cell, no massacre spot and no pod left for this player
/datum/background/convict/proc/latejoin_refusal(mob/dead/new_player/player)
	var/obj/structure/overmap/penitentiary/site = GLOB.penitentiary
	if(!site?.loaded)
		return "Full"
	if(site.free_escape_cell() || site.massacre_spots_left())
		return null
	if(!penitentiary_pod_refusal(player?.ckey))
		return null
	return "Full"

/datum/background/convict/latejoin(mob/dead/new_player/player, option_id)
	var/scenario = take_forced_scenario(player) || roll_scenario()
	var/list/started = list()
	start_group(list(player), scenario, started)
	return length(started) > 0

/**
 * Starts `players` in `scenario`, falling back as the header says. May sleep. Returns the players
 * who could not start; `started` (if given) gets the characters that did.
 */
/datum/background/convict/proc/start_group(list/mob/dead/new_player/players, scenario, list/started = list())
	var/list/failed = list()
	var/obj/structure/overmap/penitentiary/site = GLOB.penitentiary
	if(!site?.loaded || !get_convict_job())
		return players.Copy()
	var/list/cell_group = list()
	switch(scenario)
		if(BACKGROUND_CONVICT_SCENARIO_ADRIFT)
			var/list/riders = list()
			for(var/mob/dead/new_player/player in players)
				if(penitentiary_pod_refusal(player.ckey))
					cell_group += player
				else
					riders += player
			var/pods = 0
			while(length(riders))
				if(pods >= BACKGROUND_ADRIFT_MAX_PODS)
					cell_group += riders
					break
				var/list/seat_group = riders.Copy(1, min(length(riders), BACKGROUND_POD_SEATS) + 1)
				riders.Cut(1, length(seat_group) + 1)
				pods++
				cell_group += start_adrift(seat_group, started)
		if(BACKGROUND_CONVICT_SCENARIO_MASSACRE)
			for(var/mob/dead/new_player/player in players)
				var/turf/spot = site.massacre_dressed ? null : site.take_massacre_spot()
				if(!spot)
					cell_group += player
					continue
				if(!start_at(player, spot, BACKGROUND_CONVICT_SCENARIO_MASSACRE, started))
					failed += player
		else
			cell_group += players
	for(var/mob/dead/new_player/player in cell_group)
		if(QDELETED(player))
			continue
		if(!start_in_cell(player, started))
			failed += player
	return failed

/// A free escape cell for `player`, else a massacre spot. TRUE if they started.
/datum/background/convict/proc/start_in_cell(mob/dead/new_player/player, list/started)
	var/obj/structure/overmap/penitentiary/site = GLOB.penitentiary
	var/datum/penitentiary_cell/cell = site.free_escape_cell()
	if(!cell)
		var/turf/spot = site.take_massacre_spot()
		return spot ? start_at(player, spot, BACKGROUND_CONVICT_SCENARIO_MASSACRE, started) : FALSE
	cell.reserved_until = world.time + 30 SECONDS
	cell.owner_ref = null
	cell.reset_door()
	var/turf/bed = length(cell.bed_turfs) ? cell.bed_turfs[1] : cell.mark_turf
	var/mob/living/carbon/human/character = arrive(player, bed)
	cell.reserved_until = 0
	if(!character)
		return FALSE
	cell.owner_ref = WEAKREF(character.mind)
	// A guard's tool roll, dropped under the bunk
	for(var/tool_type in list(/obj/item/screwdriver, /obj/item/multitool, /obj/item/wirecutters))
		var/obj/item/tool = new tool_type(bed)
		tool.pixel_x = rand(-8, 8)
		tool.pixel_y = rand(-10, -4)
	begin(character, BACKGROUND_CONVICT_SCENARIO_CELL, started)
	return TRUE

/// Starts `player` on `spot` (a massacre spot): the processing room is dressed first, once a round
/datum/background/convict/proc/start_at(mob/dead/new_player/player, turf/spot, scenario, list/started)
	if(scenario == BACKGROUND_CONVICT_SCENARIO_MASSACRE)
		GLOB.penitentiary?.dress_massacre()
	var/mob/living/carbon/human/character = arrive(player, spot)
	if(!character)
		return FALSE
	begin(character, scenario, started)
	return TRUE

/// One pod for up to BACKGROUND_POD_SEATS players: the first in its cryopod, the second in a seat. Returns those who did not start.
/datum/background/convict/proc/start_adrift(list/mob/dead/new_player/group, list/started)
	var/mob/dead/new_player/first = group[1]
	var/obj/structure/overmap/ship/pod = penitentiary_spawn_pod(first?.ckey)
	if(!pod)
		return group.Copy()
	var/list/turf/seats = penitentiary_pod_seats(pod)
	var/list/not_started = list()
	for(var/i in 1 to length(group))
		var/mob/dead/new_player/player = group[i]
		if(QDELETED(player))
			continue
		var/atom/destination
		if(i == 1 && length(pod.shuttle?.spawn_points))
			destination = pod.shuttle.spawn_points[1]
		else if(length(seats))
			destination = seats[min(i, length(seats))]
		if(!destination)
			not_started += player
			continue
		var/mob/living/carbon/human/character = arrive(player, destination)
		if(!character)
			not_started += player
			continue
		pod.enlist_crewmember(character)
		begin(character, BACKGROUND_CONVICT_SCENARIO_ADRIFT, started)
	return not_started

/// Puts the player into the world at `destination` through the shared site arrival. Returns the human, or null.
/datum/background/convict/proc/arrive(mob/dead/new_player/player, atom/destination)
	if(QDELETED(player) || !player.client || !destination)
		return null
	var/mob/living/carbon/human/character = player.background_site_arrival(get_convict_job(), destination)
	return ishuman(character) ? character : null

/datum/background/convict/proc/begin(mob/living/carbon/human/character, scenario, list/started)
	background_begin(character.mind, BACKGROUND_CONVICT, scenario)
	started += character

// ===== THE BACKGROUND'S LIFE =====

/datum/background/convict/on_started(datum/mind/mind, datum/background_state/state)
	var/mob/living/body = mind.current
	if(body)
		ADD_TRAIT(body, TRAIT_BACKGROUND_CONVICT, BACKGROUND_TRAIT)
	var/datum/prisoner_crime/crime = convict_resolve_crime(mind)
	state.crime = crime?.name
	state.crime_tier = crime?.background_tier || 1
	state.goal = crime?.background_goal || CONVICT_GOAL_CLEAN_SLATE
	state.goal_target = 1
	background_mint_warrant(mind, BACKGROUND_CONVICT)
	switch(state.goal)
		if(CONVICT_GOAL_HAUL)
			convict_place_haul(mind)
		if(CONVICT_GOAL_STASH, CONVICT_GOAL_WITNESS)
			var/datum/convict_lead/lead = convict_lead_for(state.ckey, state.goal)
			if(lead?.host_name)
				state.extra["p2_lead"] = "[state.ckey]:[state.goal]"
			else
				// Nowhere in the sector to hide one: Vex's counter will do
				state.goal = CONVICT_GOAL_CLEAN_SLATE
	if(!tick_timer)
		tick_timer = addtimer(CALLBACK(src, PROC_REF(convict_tick)), 30 SECONDS, TIMER_LOOP | TIMER_STOPPABLE)

/datum/background/convict/on_ended(datum/mind/mind, datum/background_state/state)
	if(mind.current)
		REMOVE_TRAIT(mind.current, TRAIT_BACKGROUND_CONVICT, BACKGROUND_TRAIT)
	background_close_warrant(mind, "ended")
	var/obj/structure/overmap/penitentiary/site = GLOB.penitentiary
	if(!site)
		return
	var/obj/structure/closet/secure_closet/penitentiary_evidence/locker = site.evidence_locker_for(mind)
	if(locker)
		// The haul outlives the life: a later one of this player's lives may still come for it
		for(var/obj/item/convict_haul/haul in locker)
			haul.moveToNullspace()
		locker.release()
	for(var/number in site.escape_cells)
		var/datum/penitentiary_cell/cell = site.escape_cells[number]
		if(cell.owner() == mind)
			cell.owner_ref = null

/// The 30-second check: a Mutiny convict who captains any ship but a pod has done it [BUG-1]
/datum/background/convict/proc/convict_tick()
	for(var/datum/mind/mind as anything in background_active_minds(BACKGROUND_CONVICT))
		var/datum/background_state/state = mind?.background_state
		if(!state || state.goal != CONVICT_GOAL_CAPTAIN || state.outcome != BACKGROUND_OUTCOME_ONGOING)
			continue
		if(convict_captains_a_ship(mind))
			state.complete("Took a ship of their own.")

/// Whether `mind` is captain or acting captain of a ship they crew that is not an escape pod
/proc/convict_captains_a_ship(datum/mind/mind)
	for(var/datum/team/voidcrew/team in mind?.ship_teams)
		var/obj/structure/overmap/ship/ship = team.ship
		if(QDELETED(ship) || istype(ship.source_template, /datum/map_template/shuttle/voidcrew/escape_pod))
			continue
		if(ship.is_ship_captain_mind(mind))
			return TRUE
	return FALSE

/datum/background/convict/goal_line(datum/background_state/state)
	switch(state?.goal)
		if(CONVICT_GOAL_HAUL)
			return "My haul is in a locker in the Meridian evidence vault. I want it back."
		if(CONVICT_GOAL_CAPTAIN)
			return "Next ship I set foot on, I'm the one giving orders."
		if(CONVICT_GOAL_CLEAN_SLATE)
			return "Vex at the Undertow can make my file disappear. For a price."
		if(CONVICT_GOAL_STASH)
			var/datum/convict_lead/lead = GLOB.convict_leads[state.extra["p2_lead"]]
			return "My stash is hidden at [lead?.host_name || "a wreck out past the Meridian"]. Vex at the Undertow is waiting for it."
		if(CONVICT_GOAL_WITNESS)
			var/datum/convict_lead/lead = GLOB.convict_leads[state.extra["p2_lead"]]
			return "[lead?.witness_name || "Somebody"] put me in here. Last I heard, they were at [lead?.host_name || "a wreck out past the Meridian"]."
	return null

/datum/background/convict/outcome_line(datum/background_state/state)
	if(state.outcome_line)
		return state.outcome_line
	if(state.outcome == BACKGROUND_OUTCOME_DONE)
		return "Got what they came for."
	return convict_status_line(state)

/// Where a convict ended up: back in a capture cell, dead, or still out there
/datum/background/convict/proc/convict_status_line(datum/background_state/state)
	var/datum/mind/mind = state.mind_ref?.resolve()
	var/mob/living/body = mind?.current
	if(body && GLOB.penitentiary?.capture_cell_holding(body))
		return "Back in a cell."
	if(!body || body.stat == DEAD)
		return "Died on the run."
	return "Still running."

/datum/background/convict/judge(datum/background_state/state)
	if(!state || state.outcome != BACKGROUND_OUTCOME_ONGOING)
		return
	var/line = convict_status_line(state)
	if(line != "Still running.")
		state.fail(line)
