/**
 * ##Crew applications
 *
 * The second door into a password-locked hull. A player in the lobby who does not have
 * the password can ask for a seat instead: they attach a short note, the ship's command
 * gets told, and the captain approves or refuses by ckey and character name.
 *
 * The password itself is unchanged - this only decides who gets added to
 * password_cleared_ckeys, the same list an invite writes to. Approval is therefore
 * permanent for that ckey on that hull, exactly like being invited or having served
 * aboard: a captain who says yes has vouched for the player, and making them re-apply
 * after a disconnect or a death would just be the lock again with extra steps.
 *
 * Every failure mode ends with the applicant being told something. An application that
 * nobody answers expires and says so; a hull that dies underneath one cancels it; a
 * captain who unlocks the ship dissolves the queue. The one thing that must never happen
 * is a player sitting in the lobby watching a "pending" label that will never resolve.
 */

/// Crew applications this hull is holding, pending first-come order. Resolved records stay
/// in here until their re-apply cooldown lapses, which is what enforces the cooldown and
/// what lets the join menu show the applicant why they were turned down.
/obj/structure/overmap/ship/var/list/join_applications

// ===== APPLICATION RECORD =====

/datum/ship_join_application
	/// The hull being applied to. Cleared in Destroy; the record dies with the ship.
	var/obj/structure/overmap/ship/ship
	/// Applicant's ckey. The whole point of the feature - a captain holding a seat for a
	/// specific person needs to see who is actually knocking, not just a character name.
	var/ckey
	/// The character name the applicant is currently set up as
	var/applicant_name
	/// Optional note from the applicant
	var/message
	/// One of the SHIP_APPLICATION_* states
	var/status = SHIP_APPLICATION_PENDING
	/// Why the captain said no, if they gave a reason
	var/deny_reason
	/// world.time the application was filed
	var/created_at = 0
	/// world.time this resolved record stops blocking a re-application. Meaningless while pending.
	var/cooldown_until = 0
	/// Stoppable timer that expires the application if command never answers
	var/timer_id

/datum/ship_join_application/New(obj/structure/overmap/ship/target, applicant_ckey, name, note)
	. = ..()
	ship = target
	ckey = applicant_ckey
	applicant_name = name
	message = note
	created_at = world.time
	LAZYADD(ship.join_applications, src)
	// A hull can die with applications outstanding - it is a warship parked in a fight.
	// Without this the record outlives the ship it points at and hard-deletes it.
	RegisterSignal(ship, COMSIG_QDELETING, PROC_REF(on_ship_deleted))
	timer_id = addtimer(CALLBACK(src, PROC_REF(expire)), SHIP_JOIN_APPLICATION_TIMEOUT, TIMER_STOPPABLE)

/datum/ship_join_application/Destroy(force)
	if(timer_id)
		deltimer(timer_id)
		timer_id = null
	if(ship)
		UnregisterSignal(ship, COMSIG_QDELETING)
		LAZYREMOVE(ship.join_applications, src)
		ship = null
	return ..()

/// The mob the applicant is currently riding, if they are still connected. Usually their
/// lobby mob, but they may have wandered off and joined something else in the meantime.
/datum/ship_join_application/proc/get_applicant_mob()
	var/client/applicant_client = GLOB.directory[ckey]
	return applicant_client?.mob

/// Chat to the applicant, wherever they are. Silently does nothing if they left.
/datum/ship_join_application/proc/tell_applicant(text)
	var/mob/applicant = get_applicant_mob()
	if(!applicant)
		return
	to_chat(applicant, text)


/**
 * Command said yes. Writes the clearance and retires the record - an approved applicant
 * has no cooldown, because there is nothing left for them to re-apply for.
 */
/datum/ship_join_application/proc/approve(mob/living/approver)
	if(status != SHIP_APPLICATION_PENDING || QDELETED(ship))
		return FALSE
	ship.password_cleared_ckeys[ckey] = TRUE
	tell_applicant(boxed_message(span_boldnotice("[approver?.real_name || "The captain"] approved your application to [ship.name]. Pick it from the join menu - you will not be asked for the password.")))
	ship.ship_notify("[applicant_name] ([ckey]) was cleared to board by [approver?.real_name || "command"].", "CREW APPLICATION", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	log_game("[key_name(approver)] approved [ckey]'s crew application to ship [ship.name]")
	qdel(src)
	return TRUE

/**
 * Command said no. The record is kept, both to hold the re-apply cooldown and so the
 * applicant can read the reason off the join menu instead of having to catch it in chat.
 */
/datum/ship_join_application/proc/deny(mob/living/denier, reason)
	if(status != SHIP_APPLICATION_PENDING || QDELETED(ship))
		return FALSE
	reason = trim("[reason || ""]", SHIP_JOIN_APPLICATION_MSG_MAX_LEN + 1)
	status = SHIP_APPLICATION_DENIED
	deny_reason = length(reason) ? reason : null
	cooldown_until = world.time + SHIP_JOIN_APPLICATION_DENY_COOLDOWN
	if(timer_id)
		deltimer(timer_id)
		timer_id = null
	// html_encode at the point of use, not on the way in: this is free text a player typed and
	// chat is raw HTML, while the review panel is TGUI and escapes it on its own. Encoding it
	// into storage would show captains their own &amp;s.
	tell_applicant(boxed_message(span_boldwarning("Your application to [ship.name] was declined[deny_reason ? ": [html_encode(deny_reason)]" : "."]")))
	log_game("[key_name(denier)] denied [ckey]'s crew application to ship [ship.name][deny_reason ? " ([deny_reason])" : ""]")
	return TRUE

/// Nobody with command authority answered in time.
/datum/ship_join_application/proc/expire()
	timer_id = null
	if(status != SHIP_APPLICATION_PENDING)
		return
	status = SHIP_APPLICATION_EXPIRED
	cooldown_until = world.time + SHIP_JOIN_APPLICATION_COOLDOWN
	tell_applicant(span_warning("Nobody aboard [ship?.name || "that ship"] answered your application. Try another crew, or ask again in a few minutes."))

/// The applicant gave up on waiting.
/datum/ship_join_application/proc/withdraw()
	if(status != SHIP_APPLICATION_PENDING)
		return FALSE
	status = SHIP_APPLICATION_WITHDRAWN
	cooldown_until = world.time + SHIP_JOIN_APPLICATION_COOLDOWN
	if(timer_id)
		deltimer(timer_id)
		timer_id = null
	tell_applicant(span_notice("You withdrew your application to [ship?.name || "that ship"]."))
	return TRUE

/**
 * The question stopped making sense - the lock came off, or the hull did. Tells the
 * applicant why and drops the record outright, cooldown and all: none of these are the
 * applicant's fault and none of them should stop them applying somewhere else.
 */
/datum/ship_join_application/proc/cancel(text)
	if(status == SHIP_APPLICATION_PENDING && text)
		tell_applicant(span_notice(text))
	qdel(src)

/datum/ship_join_application/proc/on_ship_deleted(datum/source)
	SIGNAL_HANDLER
	if(status == SHIP_APPLICATION_PENDING)
		tell_applicant(span_warning("Your application to [ship?.name || "a ship"] was dropped - the ship no longer exists."))
	UnregisterSignal(source, COMSIG_QDELETING)
	// Drop the back-reference here rather than leaving it to Destroy(), which would try to
	// unregister a second time from a datum that is already mid-qdel.
	if(ship)
		LAZYREMOVE(ship.join_applications, src)
		ship = null
	qdel(src)

// ===== SHIP-SIDE API =====

/// This hull's application record for a ckey, pending or resolved, or null.
/obj/structure/overmap/ship/proc/get_join_application(applicant_ckey)
	if(!applicant_ckey)
		return null
	for(var/datum/ship_join_application/application as anything in join_applications)
		if(application.ckey == applicant_ckey)
			return application
	return null

/// How many applications are still waiting on an answer.
/obj/structure/overmap/ship/proc/count_pending_applications()
	. = 0
	for(var/datum/ship_join_application/application as anything in join_applications)
		if(application.status == SHIP_APPLICATION_PENDING)
			.++

/**
 * Housekeeping, called from both UIs that read the list rather than from a subsystem -
 * nothing here needs to happen on a timer, it only needs to be true by the time somebody
 * looks. Drops resolved records whose cooldown has lapsed, and dissolves the queue if the
 * hull is no longer locked, since an application to an open ship is just a delay.
 */
/obj/structure/overmap/ship/proc/prune_join_applications()
	if(!LAZYLEN(join_applications))
		return
	for(var/datum/ship_join_application/application as anything in join_applications.Copy())
		if(application.status == SHIP_APPLICATION_PENDING)
			if(!join_password)
				application.cancel("[name] is no longer locked - you can join it straight from the menu.")
			continue
		if(application.cooldown_until <= world.time)
			qdel(application)

/**
 * Crew who can actually answer an application right now: on the roster, holding command,
 * awake and connected. Deliberately the same authority test the Ship Management panel
 * uses, so the set of people who get told is exactly the set who can do anything about it.
 */
/obj/structure/overmap/ship/proc/get_application_reviewers()
	. = list()
	for(var/datum/mind/member as anything in ship_team?.members)
		var/mob/living/body = member.current
		if(!body?.client || body.stat != CONSCIOUS)
			continue
		if(!is_ship_captain(body))
			continue
		. += body

/**
 * Files an application from a lobby player. Returns TRUE if it went on the board.
 *
 * Every refusal explains itself in chat: this is reached from a button in the join menu,
 * and a button that silently does nothing is worse than the password was.
 */
/obj/structure/overmap/ship/proc/submit_join_application(mob/dead/new_player/applicant, note)
	if(!applicant?.ckey)
		return FALSE
	prune_join_applications()

	if(!join_password)
		to_chat(applicant, span_warning("[name] is not locked - you can join it directly."))
		return FALSE
	if(is_password_cleared(applicant.ckey))
		to_chat(applicant, span_notice("You are already cleared to board [name]."))
		return FALSE
	if(!joining_allowed || !ship_has_open_slots(src))
		to_chat(applicant, span_warning("[name] is not taking new crew right now."))
		return FALSE

	var/datum/ship_join_application/existing = get_join_application(applicant.ckey)
	if(existing)
		if(existing.status == SHIP_APPLICATION_PENDING)
			to_chat(applicant, span_warning("You already have an application waiting with [name]."))
			return FALSE
		to_chat(applicant, span_warning("[name] will not take another application from you for [DisplayTimeText(existing.cooldown_until - world.time)]."))
		return FALSE

	if(count_pending_applications() >= SHIP_JOIN_APPLICATION_MAX_PENDING)
		to_chat(applicant, span_warning("[name] already has as many applications as it can read. Try again shortly."))
		return FALSE

	note = trim("[note || ""]", SHIP_JOIN_APPLICATION_MSG_MAX_LEN + 1)
	var/character_name = applicant.client?.prefs?.read_preference(/datum/preference/name/real_name) || applicant.ckey
	var/datum/ship_join_application/application = new(src, applicant.ckey, character_name, length(note) ? note : null)

	var/list/reviewers = get_application_reviewers()
	// The note goes out to the whole crew's chat, which is raw HTML - see the note in deny().
	ship_notify("[character_name] ([application.ckey]) is asking to join the crew[application.message ? ": \"[html_encode(application.message)]\"" : "."]", "CREW APPLICATION", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 60)
	for(var/mob/living/reviewer as anything in reviewers)
		to_chat(reviewer, span_boldnotice("Approve or decline it from Ship Management → Applications."))

	if(length(reviewers))
		to_chat(applicant, span_notice("Application sent to [name]. Command has been notified; it lapses in [DisplayTimeText(SHIP_JOIN_APPLICATION_TIMEOUT)] if nobody answers."))
	else
		// Told up front rather than after five minutes of silence, so they can go and pick
		// another ship now instead of finding out later that nobody was ever going to read it.
		to_chat(applicant, span_warning("Application sent to [name], but nobody aboard currently holds command to answer it. It lapses in [DisplayTimeText(SHIP_JOIN_APPLICATION_TIMEOUT)]."))

	log_game("[key_name(applicant)] applied to join ship [name][application.message ? " (\"[application.message]\")" : ""]")
	return TRUE
