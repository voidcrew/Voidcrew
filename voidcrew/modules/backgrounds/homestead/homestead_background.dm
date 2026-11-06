/**
 * # Homesteader
 *
 * Up to BACKGROUND_MAX_HOMESTEADERS players live on the Frontier homestead: one Rancher and three
 * Hands, waking in its beds. The goal is to stay. It fails only when a homesteader leaves the
 * Frontier of their own accord: checked on a timer from where they are, never from undock
 * events, so being carried, cuffed, dragged or knocked out and taken away leaves it open, with a
 * nudge to get home. Teleports off the Frontier do not take them. At round end a standing
 * goal is settled by how many of the family are alive.
 */
/datum/background/homesteader
	key = BACKGROUND_HOMESTEADER
	name = "Homesteader"
	site = TRUE
	/// The Rancher and the Hands (/datum/job -> slots), made on first use
	var/list/jobs

/// The homestead's jobs: one Rancher, three Hands
/datum/background/homesteader/proc/get_jobs()
	if(!jobs)
		jobs = assemble_job_slots_from_list(list(
			list(name = "Rancher", officer = TRUE, outfit = /datum/outfit/job/botanist/homesteader, category = JOB_CAT_SERVICE, slots = 1),
			list(name = "Hand", outfit = /datum/outfit/job/botanist/homestead_hand, category = JOB_CAT_SERVICE, slots = 3),
		))
	return jobs

/**
 * The job the next homesteader takes, or null when the homestead is full: the Rancher while nobody
 * living holds it, then a Hand while a Hand's place is free, never more than
 * BACKGROUND_MAX_HOMESTEADERS alive.
 */
/datum/background/homesteader/proc/pick_job()
	var/datum/job/rancher
	var/datum/job/hand
	var/list/all_jobs = get_jobs()
	for(var/datum/job/job as anything in all_jobs)
		if(job.title == "Rancher")
			rancher = job
		else
			hand = job
	var/ranchers = 0
	var/hands = 0
	for(var/datum/mind/mind as anything in background_active_minds(key))
		if(QDELETED(mind.current) || mind.current.stat == DEAD)
			continue
		if(mind.assigned_role?.title == "Rancher")
			ranchers++
		else
			hands++
	if(ranchers + hands >= BACKGROUND_MAX_HOMESTEADERS)
		return null
	if(!ranchers && rancher)
		return rancher
	if(hand && hands < all_jobs[hand])
		return hand
	return null

/// Where a homesteader with `job` wakes: the Rancher's bed, or a free settler bed
/datum/background/homesteader/proc/pick_destination(datum/job/job)
	var/datum/homestead/homestead = GLOB.homestead
	if(!homestead)
		return null
	var/obj/effect/landmark/homestead/settler/rancher/rancher_mark
	var/list/obj/effect/landmark/homestead/settler/marks = list()
	for(var/obj/effect/landmark/homestead/settler/mark in GLOB.landmarks_list)
		if(!homestead.contains(mark))
			continue
		if(istype(mark, /obj/effect/landmark/homestead/settler/rancher))
			rancher_mark = mark
		else
			marks += mark
	if(job?.title == "Rancher" && rancher_mark)
		return get_turf(rancher_mark)
	for(var/obj/effect/landmark/homestead/settler/mark as anything in shuffle(marks))
		if(!(locate(/mob/living/carbon/human) in get_turf(mark)))
			return get_turf(mark)
	if(length(marks))
		var/obj/effect/landmark/homestead/settler/mark = pick(marks)
		return get_turf(mark)
	return rancher_mark ? get_turf(rancher_mark) : null

/// Puts one lobby player on the homestead. TRUE on success. May sleep.
/datum/background/homesteader/proc/start_settler(mob/dead/new_player/player)
	var/datum/job/job = pick_job()
	var/turf/destination = job ? pick_destination(job) : null
	if(!destination)
		return FALSE
	var/mob/living/character = player.background_site_arrival(job, destination)
	if(QDELETED(character) || !character.mind)
		return FALSE
	background_begin(character.mind, key)
	return TRUE

/datum/background/homesteader/roundstart(list/mob/dead/new_player/players)
	. = list()
	for(var/mob/dead/new_player/player as anything in players)
		if(QDELETED(player))
			continue
		if(!player.client || !start_settler(player))
			. += player

/datum/background/homesteader/latejoin_options(mob/dead/new_player/player)
	var/refusal
	if(!GLOB.homestead || !frontier_surface_z())
		refusal = "Closed"
	else if(!pick_job())
		refusal = "Full"
	return list(list(
		"id" = "homesteader",
		"kind" = key,
		"name" = "Frontier homestead",
		"detail" = null,
		"crew" = null,
		"refusal" = refusal,
	))

/datum/background/homesteader/latejoin(mob/dead/new_player/player, option_id)
	if(option_id != "homesteader" || QDELETED(player))
		return FALSE
	if(!GLOB.homestead || !frontier_surface_z())
		return FALSE
	return start_settler(player)

/datum/background/homesteader/on_started(datum/mind/mind, datum/background_state/state)
	var/mob/living/body = mind?.current
	state.extra["homestead_fed"] = 0
	state.extra["homestead_watched"] = 0
	state.extra["homestead_free"] = FALSE
	state.extra["homestead_role"] = mind?.assigned_role?.title
	if(!isliving(body))
		return
	RegisterSignal(body, COMSIG_MOVABLE_TELEPORTING, PROC_REF(refuse_teleport), override = TRUE)
	if(state.extra["homestead_role"] == "Rancher")
		homestead_link_farm_stands(body)
	GLOB.homestead?.welcome(body)

/datum/background/homesteader/on_ended(datum/mind/mind, datum/background_state/state)
	if(mind?.current)
		UnregisterSignal(mind.current, COMSIG_MOVABLE_TELEPORTING)

/**
 * A teleport that would take a homesteader off the Frontier does not: beam-ups, a hostile
 * hand teleporter, a bluespace shove. Moves that keep them on the Frontier go ahead. Forced ones too:
 * the signal is sent for them.
 */
/datum/background/homesteader/proc/refuse_teleport(mob/living/source, atom/destination, channel)
	SIGNAL_HANDLER
	var/datum/background_state/state = source.mind?.background_state
	if(!state || state.ended || state.key != key)
		UnregisterSignal(source, COMSIG_MOVABLE_TELEPORTING)
		return NONE
	if(is_frontier_turf(destination))
		return NONE
	return TRUE

/datum/background/homesteader/goal_line(datum/background_state/state)
	return "We stay on Frontier. The family stays fed and safe."

/datum/background/homesteader/judge(datum/background_state/state)
	if(state.outcome != BACKGROUND_OUTCOME_ONGOING)
		return
	var/datum/homestead/homestead = GLOB.homestead
	var/total = homestead ? length(homestead.members) : 0
	var/alive = length(homestead_family())
	if(alive >= total)
		state.complete("Stayed on Frontier. The family made it.")
	else if(alive)
		state.complete("Stayed on Frontier. [alive] of the family made it.")
	else
		state.complete("Stayed on Frontier. None of the family made it.")

/// Points every farm stand's till at `rancher`'s account
/proc/homestead_link_farm_stands(mob/living/rancher)
	var/obj/item/card/id/card = rancher?.get_idcard(FALSE)
	var/datum/bank_account/account = card?.registered_account
	if(!account)
		return FALSE
	for(var/obj/machinery/vending/custom/unbreakable/homestead/stand as anything in GLOB.homestead_farm_stands)
		stand.linked_account = account
	return TRUE

/**
 * Whether `settler` could be leaving of their own accord right now: awake and able, not cuffed,
 * not pulled, not carried and not strapped to a stretcher, not shut inside something.
 */
/proc/homestead_free_to_leave(mob/living/settler)
	if(QDELETED(settler) || settler.stat != CONSCIOUS || HAS_TRAIT(settler, TRAIT_INCAPACITATED))
		return FALSE
	if(HAS_TRAIT(settler, TRAIT_RESTRAINED) || settler.pulledby)
		return FALSE
	if(ismob(settler.buckled) || istype(settler.buckled, /obj/structure/bed))
		return FALSE
	if(!isturf(settler.loc) && !istype(settler.loc, /obj/vehicle))
		return FALSE
	return TRUE

/// The key the homestead remembers a homesteader by
/proc/homestead_settler_key(datum/mind/mind)
	if(!mind)
		return null
	return mind.key ? ckey(mind.key) : REF(mind)

// =========================================================================
// ON THE HOMESTEAD'S TICK
// =========================================================================

/**
 * Where each homesteader is. On the Frontier: whether they could leave of their own accord,
 * and their time watched and fed. Off it, every BACKGROUND_HOMESTEAD_LEAVE_CHECK: if they were free
 * when last seen on the Frontier and are free now, they left; otherwise they were taken, and are
 * told once to get home.
 */
/datum/homestead/proc/tend_homesteaders()
	var/check_departures = world.time >= next_departure_check
	if(check_departures)
		next_departure_check = world.time + BACKGROUND_HOMESTEAD_LEAVE_CHECK
	var/seconds = BACKGROUND_HOMESTEAD_NEEDS_INTERVAL / (1 SECONDS)
	for(var/datum/mind/mind as anything in background_active_minds(BACKGROUND_HOMESTEADER))
		var/datum/background_state/state = mind.background_state
		var/mob/living/settler = mind.current
		if(!state || QDELETED(settler))
			continue
		if(on_frontier(settler))
			state.extra["homestead_free"] = homestead_free_to_leave(settler)
			state.extra["homestead_told_home"] = FALSE
			if(settler.stat != DEAD)
				state.extra["homestead_watched"] = (state.extra["homestead_watched"] || 0) + seconds
				if(fed)
					state.extra["homestead_fed"] = (state.extra["homestead_fed"] || 0) + seconds
			continue
		if(check_departures)
			check_departure(state, settler)

/// One homesteader off the Frontier: left, or taken
/datum/homestead/proc/check_departure(datum/background_state/state, mob/living/settler)
	if(state.outcome != BACKGROUND_OUTCOME_ONGOING)
		return
	if(state.extra["homestead_free"] && homestead_free_to_leave(settler))
		state.fail("Left Frontier.")
		return
	if(!state.extra["homestead_told_home"] && settler.stat == CONSCIOUS)
		state.extra["homestead_told_home"] = TRUE
		to_chat(settler, span_warning("Get home."))

/// A homesteader starting their life here: one of the family says hello, and the coming-home greeting waits
/datum/homestead/proc/welcome(mob/living/settler)
	var/key = homestead_settler_key(settler?.mind)
	if(!key)
		return
	greeted[key] = world.time
	near_family[key] = TRUE
	var/mob/living/basic/ambient_npc/homestead/greeter = family_speaker(/mob/living/basic/ambient_npc/homestead/spouse)
	if(greeter)
		addtimer(CALLBACK(greeter, TYPE_PROC_REF(/mob/living/basic/ambient_npc/homestead, greet), settler, "welcome"), 3 SECONDS, TIMER_DELETE_ME)

// =========================================================================
// OUTFITS
// =========================================================================

/datum/outfit/job/botanist/homesteader
	name = "Homesteader (Rancher)"
	head = /obj/item/clothing/head/cowboy/black
	shoes = /obj/item/clothing/shoes/cowboy
	uniform = /obj/item/clothing/under/misc/overalls

/datum/outfit/job/botanist/homestead_hand
	name = "Homesteader (Hand)"
	head = /obj/item/clothing/head/cowboy/brown
	shoes = /obj/item/clothing/shoes/cowboy
	uniform = /obj/item/clothing/under/misc/overalls
