// ===== COMMAND TRANSFER AND ELECTIONS =====
//
// Command of a ship can come from three places: the officer job, claiming a derelict,
// or acting command on a ship that never had a captain. None of them could ever be
// handed over, so a captain who wanted to step down, or a crew whose captain died,
// were stuck with the roster they woke up with.
//
// Two ways out, both landing in the same place - claimed_captain:
//
// * Transfer: the sitting captain offers command to a crewmember from Ship Management
//   and they accept.
// * Election: with no captain able to run the ship, any crewmember calls a vote from
//   the cryogenic oversight console and the crew decides.
//
// is_ship_captain() treats a set claimed_captain as exclusive, so after either of
// these exactly one person aboard holds command, even on a ship whose officer job is
// still sitting in somebody's ID. The console was chosen over an action button because
// it is already linked to the ship, already open to every crewmember, and mapped onto
// every playable hull - a button would have to be handed out on every join, invite and
// enlist path and taken back on every kick and cryo.

/mob
	/// world.time this mob last lost its client. Read by has_available_captain() to
	/// tell a captain who dropped a second ago from one who has been gone for minutes;
	/// only ever consulted while client is null, so a mob swap stamping it is harmless.
	var/last_logout_time = 0

/mob/Logout()
	last_logout_time = world.time
	return ..()

// ===== WHO HOLDS COMMAND =====

/**
 * The crewmember is_ship_captain() currently answers TRUE for, if any of them are
 * still embodied. Used to tell the outgoing captain that they have been relieved.
 */
/obj/structure/overmap/ship/proc/get_current_commander()
	for(var/datum/mind/member as anything in ship_team?.members)
		var/mob/living/body = member?.current
		if(QDELETED(body))
			continue
		if(is_ship_captain(body))
			return body
	return null

/**
 * Whether this ship still has a captain able to run it.
 *
 * Alive, on the roster, and either connected or only just disconnected: a captain who
 * dropped thirty seconds ago is reconnecting, not gone, and their crew should not be
 * able to vote the hull out from under them while they load. Dead, cryoed (cryo takes
 * the mind off the roster outright) and long-disconnected all read as absent, which is
 * exactly when an election opens.
 */
/obj/structure/overmap/ship/proc/has_available_captain()
	for(var/datum/mind/member as anything in ship_team?.members)
		var/mob/living/body = member?.current
		if(QDELETED(body) || !isliving(body))
			continue
		if(body.stat == DEAD)
			continue
		if(!is_ship_captain(body))
			continue
		if(body.client)
			return TRUE
		if(body.last_logout_time && (world.time - body.last_logout_time) < SHIP_CAPTAIN_ABSENCE_GRACE)
			return TRUE
	return FALSE

/**
 * Puts the Ship Management button in exactly the right hands: the one crewmember who
 * holds command gets it, everyone else on the roster loses whatever they were holding
 * for this ship. Idempotent, so it is safe to call after any command change.
 */
/obj/structure/overmap/ship/proc/refresh_command_buttons()
	for(var/datum/mind/member as anything in ship_team?.members)
		var/mob/living/body = member?.current
		if(QDELETED(body))
			continue
		if(is_ship_captain(body))
			grant_captain_management(body, src)
		else
			remove_captain_management(body, src)

/**
 * Hands command to a crewmember. Both the transfer and the election end here, so the
 * announcement, the logging and the button shuffle only exist in one place.
 *
 * Sets claimed_captain, which is exclusive: the officer job stops conferring command
 * on this hull from here on, and a revived former captain does not get it back unless
 * command is transferred to them again.
 */
/obj/structure/overmap/ship/proc/take_command(mob/living/new_captain, reason)
	if(!new_captain?.mind || !(new_captain.mind in ship_team?.members))
		return FALSE
	var/mob/living/former = get_current_commander()
	if(former == new_captain)
		return FALSE

	claimed_captain = new_captain.mind
	acting_captain = null
	refresh_command_buttons()

	if(former)
		to_chat(former, span_boldwarning("You no longer hold command of [name]."))
	to_chat(new_captain, span_boldnotice("You hold command of [name]. Ship Management is in your action buttons."))
	ship_notify("Command of [name] has passed to [new_captain.real_name].", "SHIP SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	log_game("[key_name(new_captain)] took command of ship [name] ([reason]); relieved [former ? key_name(former) : "nobody"]")
	return TRUE

// ===== TRANSFER =====

/**
 * Offers command to a crewmember. They get half a minute to answer; nothing changes
 * until they accept.
 *
 * One offer at a time per ship, so a captain cannot paper the crew with prompts.
 */
/obj/structure/overmap/ship/proc/offer_command(mob/living/candidate, mob/living/offering)
	if(!is_ship_captain(offering))
		to_chat(offering, span_warning("You do not hold command of [name]."))
		return FALSE
	if(command_offer_pending)
		to_chat(offering, span_warning("You already have a command transfer waiting on an answer."))
		return FALSE
	if(QDELETED(candidate) || !candidate.mind || !(candidate.mind in ship_team?.members))
		to_chat(offering, span_warning("They are not on your crew."))
		return FALSE
	if(candidate == offering)
		to_chat(offering, span_warning("You already hold command."))
		return FALSE
	if(!candidate.client || candidate.stat == DEAD)
		to_chat(offering, span_warning("[candidate.real_name] is in no state to take command."))
		return FALSE

	command_offer_pending = TRUE
	to_chat(offering, span_notice("Offered command of [name] to [candidate.real_name]. Waiting on their answer."))
	INVOKE_ASYNC(src, PROC_REF(run_command_offer), candidate, offering)
	return TRUE

/// The half-minute prompt. Async because it sleeps.
/obj/structure/overmap/ship/proc/run_command_offer(mob/living/candidate, mob/living/offering)
	var/response = tgui_alert(candidate,
		"[offering.real_name] is handing you command of [name]. Accepting makes you the ship's captain; they stop being it.",
		"Command Transfer",
		list("Accept", "Decline"),
		timeout = SHIP_COMMAND_OFFER_TIME
	)
	command_offer_pending = FALSE

	if(QDELETED(src))
		return
	if(response != "Accept")
		if(offering?.client)
			to_chat(offering, span_warning("[QDELETED(candidate) ? "They" : candidate.real_name] did not take command of [name]."))
		return
	// Everything is re-checked: half a minute is plenty of time for the captain to die,
	// the candidate to leave, or somebody else to win an election.
	if(!is_ship_captain(offering))
		to_chat(candidate, span_warning("[QDELETED(offering) ? "The previous captain" : offering.real_name] no longer holds command of [name]."))
		return
	if(QDELETED(candidate) || !candidate.mind || !(candidate.mind in ship_team?.members) || candidate.stat == DEAD)
		if(offering?.client)
			to_chat(offering, span_warning("The transfer failed - [QDELETED(candidate) ? "they are" : "[candidate.real_name] is"] no longer aboard."))
		return
	take_command(candidate, "command transferred by [key_name(offering)]")

// ===== ELECTION =====

/**
 * Whether `user` may call an election right now. Says why not when asked to, because
 * every refusal here is something the player can act on.
 */
/obj/structure/overmap/ship/proc/can_call_election(mob/living/user, feedback = FALSE)
	if(!user?.mind || !(user.mind in ship_team?.members))
		if(feedback)
			to_chat(user, span_warning("You are not on [name]'s crew."))
		return FALSE
	if(user.stat != CONSCIOUS)
		if(feedback)
			to_chat(user, span_warning("You are in no state to stand for command."))
		return FALSE
	if(election_in_progress)
		if(feedback)
			to_chat(user, span_warning("An election is already running."))
		return FALSE
	if(!COOLDOWN_FINISHED(src, election_cooldown))
		if(feedback)
			to_chat(user, span_warning("The last election failed too recently. Try again in [DisplayTimeText(COOLDOWN_TIMELEFT(src, election_cooldown))]."))
		return FALSE
	if(has_available_captain())
		if(feedback)
			to_chat(user, span_warning("[name] still has a captain. Elections are for when there is nobody left to run the ship."))
		return FALSE
	return TRUE

/**
 * Calls an election, nominating the caller. Every other crewmember who is online and
 * alive gets 45 seconds to vote; a simple majority of the people who answer carries it.
 * The only crewmember aboard carries it unopposed - there is nobody left to object.
 */
/obj/structure/overmap/ship/proc/call_election(mob/living/nominee)
	if(!can_call_election(nominee, TRUE))
		return FALSE
	election_in_progress = TRUE
	ship_notify("[nominee.real_name] has called an election for command of [name] - no captain is able to run the ship. The crew will be asked to vote.", "SHIP SYSTEMS", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 50)
	log_game("[key_name(nominee)] called a command election aboard ship [name]")
	INVOKE_ASYNC(src, PROC_REF(run_election), nominee)
	return TRUE

/// Prompts one voter and files their answer. Async so the whole crew votes at once.
/obj/structure/overmap/ship/proc/collect_election_vote(mob/living/voter, nominee_name, list/ballot)
	var/response = tgui_alert(voter,
		"[nominee_name] is standing for command of [name]. The ship has no captain able to run it. Do you back them?",
		"Command Election",
		list("Yes", "No"),
		timeout = SHIP_ELECTION_VOTE_TIME
	)
	if(isnull(ballot))
		return
	if(response == "Yes")
		ballot["yes"]++
	else if(response == "No")
		ballot["no"]++

/// Runs the vote and settles it. Async because it waits out the voting window.
/obj/structure/overmap/ship/proc/run_election(mob/living/nominee)
	var/list/voters = list()
	for(var/datum/mind/member as anything in ship_team?.members)
		var/mob/living/body = member?.current
		if(QDELETED(body) || body == nominee)
			continue
		if(!body.client || body.stat == DEAD)
			continue
		voters += body

	var/list/ballot = list("yes" = 0, "no" = 0)
	var/nominee_name = nominee.real_name
	for(var/mob/living/voter as anything in voters)
		INVOKE_ASYNC(src, PROC_REF(collect_election_vote), voter, nominee_name, ballot)

	// Wait the window out, but stop early once everyone has answered. The extra second
	// is for the last prompt's own timeout to land before the count is read.
	var/deadline = world.time + SHIP_ELECTION_VOTE_TIME + (1 SECONDS)
	while(world.time < deadline && (ballot["yes"] + ballot["no"]) < length(voters))
		stoplag(1 SECONDS)
		if(QDELETED(src))
			return

	election_in_progress = FALSE
	var/yes_votes = ballot["yes"]
	var/no_votes = ballot["no"]

	if(QDELETED(nominee) || !nominee.mind || !(nominee.mind in ship_team?.members) || nominee.stat == DEAD)
		ship_notify("The election lapsed - the candidate is no longer able to take command.", "SHIP SYSTEMS", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 30)
		COOLDOWN_START(src, election_cooldown, SHIP_ELECTION_FAILURE_COOLDOWN)
		return
	// Somebody's captain reconnected, or won a transfer, while the vote was running
	if(has_available_captain())
		ship_notify("The election is void - [name] has a captain again.", "SHIP SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 30)
		COOLDOWN_START(src, election_cooldown, SHIP_ELECTION_FAILURE_COOLDOWN)
		return

	if(!length(voters) || yes_votes > no_votes)
		if(length(voters))
			ship_notify("The election carried: [yes_votes] for, [no_votes] against.", "SHIP SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 30)
		take_command(nominee, "elected by the crew ([yes_votes] for, [no_votes] against)")
		return

	ship_notify("The election failed: [yes_votes] for, [no_votes] against. Another can be called in [DisplayTimeText(SHIP_ELECTION_FAILURE_COOLDOWN)].", "SHIP SYSTEMS", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 30)
	to_chat(nominee, span_warning("The crew did not back you."))
	log_game("[key_name(nominee)]'s command election aboard ship [name] failed ([yes_votes] for, [no_votes] against)")
	COOLDOWN_START(src, election_cooldown, SHIP_ELECTION_FAILURE_COOLDOWN)
