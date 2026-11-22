// ===== BLUESPACE JUMP VOTE =====
//
// A bluespace jump takes the ship and everyone aboard out of the round, so one person
// should not be able to make that call for the whole crew. Only the captain can order
// it from the helm, and the order goes to a crew vote first. It carries only with a
// majority of the whole crew that is online and alive, the captain counted as a yes:
// a crewmember who doesn't answer counts against, so nobody leaves while half the crew
// is away from the keyboard. A captain alone aboard carries it unopposed.
//
// Runs on the same pattern as the command election in command_transfer.dm.

/// How long each crewmember has to answer.
#define JUMP_VOTE_TIME (45 SECONDS)
/// How long a captain waits between votes, so the crew is not asked over and over.
#define JUMP_VOTE_COOLDOWN (2 MINUTES)

/obj/structure/overmap/ship
	/// TRUE while the crew is voting on a bluespace jump.
	var/jump_vote_in_progress = FALSE
	COOLDOWN_DECLARE(jump_vote_cooldown)

/**
 * The captain orders a bluespace jump from `helm`. Puts it to the crew; the helm only
 * starts calibrating if the vote carries.
 */
/obj/structure/overmap/ship/proc/call_jump_vote(mob/living/captain, obj/machinery/computer/helm/helm)
	if(!is_ship_captain(captain))
		to_chat(captain, span_warning("Only the captain can order a bluespace jump."))
		return FALSE
	if(jump_vote_in_progress)
		to_chat(captain, span_warning("The crew is already voting on a jump."))
		return FALSE
	if(!COOLDOWN_FINISHED(src, jump_vote_cooldown))
		to_chat(captain, span_warning("The crew just voted on a jump. Try again in [DisplayTimeText(COOLDOWN_TIMELEFT(src, jump_vote_cooldown))]."))
		return FALSE
	jump_vote_in_progress = TRUE
	ship_notify("Captain [captain.real_name] has ordered a bluespace jump. The crew will be asked to vote.", "BLUESPACE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 50)
	log_game("[key_name(captain)] called a bluespace jump vote aboard ship [name]")
	INVOKE_ASYNC(src, PROC_REF(run_jump_vote), captain, helm)
	return TRUE

/// Prompts one voter and files their answer. Async so the whole crew votes at once.
/obj/structure/overmap/ship/proc/collect_jump_vote(mob/living/voter, captain_name, list/ballot)
	var/response = tgui_alert(voter,
		"Captain [captain_name] has ordered a bluespace jump. [name] and everyone aboard will leave the sector for good. Do you agree?",
		"Bluespace Jump",
		list("Agree", "Refuse"),
		timeout = JUMP_VOTE_TIME
	)
	if(response == "Agree")
		ballot["yes"]++
	else if(response == "Refuse")
		ballot["no"]++

/// Runs the vote and settles it. Async because it waits out the voting window.
/obj/structure/overmap/ship/proc/run_jump_vote(mob/living/captain, obj/machinery/computer/helm/helm)
	var/list/voters = list()
	for(var/datum/mind/member as anything in ship_team?.members)
		var/mob/living/body = member?.current
		if(QDELETED(body) || body == captain)
			continue
		if(!body.client || body.stat == DEAD)
			continue
		voters += body

	var/list/ballot = list("yes" = 0, "no" = 0)
	var/captain_name = captain.real_name
	for(var/mob/living/voter as anything in voters)
		INVOKE_ASYNC(src, PROC_REF(collect_jump_vote), voter, captain_name, ballot)

	// Wait the window out, but stop early once everyone has answered. The extra second
	// is for the last prompt's own timeout to land before the count is read.
	var/deadline = world.time + JUMP_VOTE_TIME + (1 SECONDS)
	while(world.time < deadline && (ballot["yes"] + ballot["no"]) < length(voters))
		stoplag(1 SECONDS)
		if(QDELETED(src))
			return

	jump_vote_in_progress = FALSE
	COOLDOWN_START(src, jump_vote_cooldown, JUMP_VOTE_COOLDOWN)
	// The captain is an automatic yes. Everyone eligible counts toward the total,
	// answered or not, so silence is a no.
	var/yes_votes = ballot["yes"] + 1
	var/no_votes = length(voters) + 1 - yes_votes
	var/carried = yes_votes * 2 > length(voters) + 1

	if(!carried)
		ship_notify("The crew refused the jump: [yes_votes] for, [no_votes] against.", "BLUESPACE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 30)
		log_game("Bluespace jump vote aboard ship [name] failed ([yes_votes] for, [no_votes] against)")
		return

	// Forty-five seconds is plenty of time for the captain to die or lose command, or
	// for the helm to be wrecked. The jump needs all of them still in place.
	if(QDELETED(captain) || captain.stat == DEAD || !is_ship_captain(captain))
		ship_notify("The jump order lapsed - the captain who gave it no longer holds command.", "BLUESPACE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 30)
		return
	if(QDELETED(helm) || helm.current_ship != src)
		ship_notify("The jump order lapsed - the helm that took it is gone.", "BLUESPACE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 30)
		return

	if(length(voters))
		ship_notify("The crew agreed to jump: [yes_votes] for, [no_votes] against.", "BLUESPACE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 30)
	log_game("Bluespace jump vote aboard ship [name] carried ([yes_votes] for, [no_votes] against)")
	helm.calibrate_jump(user = captain)

#undef JUMP_VOTE_TIME
#undef JUMP_VOTE_COOLDOWN
