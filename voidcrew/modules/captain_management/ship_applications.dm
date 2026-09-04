// ===== SHIP CREW APPLICATIONS =====
//
// A password-locked ship is a closed door to anyone who does not already know the
// crew. Applications are the knocker: from the lobby join menu a player can send the
// ship's captain a one-line pitch, and the captain approves or denies it from Ship
// Management (or straight from the chat link). An approval clears the applicant's
// ckey past the password, which is the same clearance an invite grants - it is not a
// job assignment, so the applicant still picks their role in the join menu.
//
// Deliberately not a second invite system: the captain's Invites tab reaches players
// who are already alive and standing in front of them, and cannot see the lobby at
// all. This is the other direction.

/datum/ship_application
	/// The ship being applied to. Cleared in Destroy so a dead application never
	/// dereferences a hull that has been deleted out from under it.
	var/obj/structure/overmap/ship/ship
	/// Applicant's ckey. Shown to the reviewer on purpose: crews recruit people they
	/// know by ckey, which is the whole reason the feature was asked for.
	var/ckey
	/// The character name the applicant is currently set to spawn under.
	var/applicant_name
	/// The applicant's message. Stored raw (the input is taken unencoded so the TGUI
	/// panel shows it as typed); every path that puts it in chat html_encode()s it.
	var/message
	/// world.time the application was filed, for the "waiting" readout.
	var/created_at = 0

/datum/ship_application/New(obj/structure/overmap/ship/target_ship, applicant_ckey, name_used, applicant_message)
	. = ..()
	ship = target_ship
	ckey = applicant_ckey
	applicant_name = name_used
	message = applicant_message
	created_at = world.time
	// TIMER_DELETE_ME: approving or denying qdels the application, and the pending
	// expiry has to die with it instead of firing on a freed datum.
	addtimer(CALLBACK(src, PROC_REF(expire)), SHIP_APPLICATION_EXPIRY, TIMER_DELETE_ME)

/datum/ship_application/Destroy(force = FALSE)
	ship?.crew_applications -= src
	ship = null
	return ..()

/// How long this application has been waiting.
/datum/ship_application/proc/waiting_time()
	return world.time - created_at

/**
 * Ten minutes with no answer and the application lapses. Told to the applicant so they
 * stop staring at a ship that is never going to let them in.
 */
/datum/ship_application/proc/expire()
	if(QDELETED(src))
		return
	var/mob/applicant = get_mob_by_ckey(ckey)
	if(applicant && ship)
		to_chat(applicant, span_warning("Your application to join [ship.name] expired without an answer. You can apply again."))
	qdel(src)

/**
 * Approve and Deny links in the captain's chat notification.
 *
 * A ref can be reused after the datum it named is freed, so nothing here trusts the
 * link: the application has to still be on its ship's open list, and whoever clicked
 * has to still be that ship's captain.
 */
/datum/ship_application/Topic(href, href_list[])
	..()
	var/mob/user = usr
	if(!user)
		return
	if(QDELETED(src) || QDELETED(ship) || !(src in ship.crew_applications))
		to_chat(user, span_warning("That application is no longer open."))
		return
	if(!ship.is_ship_captain(user))
		to_chat(user, span_warning("You do not hold command of [ship.name]."))
		return

	if(href_list["approve"])
		ship.resolve_crew_application(src, TRUE, user)
		return
	if(href_list["deny"])
		// The reason prompt sleeps, and Topic() is not a good place to sit and wait.
		INVOKE_ASYNC(ship, TYPE_PROC_REF(/obj/structure/overmap/ship, prompt_deny_crew_application), src, user)
		return

// ===== SHIP SIDE =====

/**
 * Drops every open application older than the expiry. The expiry timer normally does
 * this on its own; this is the belt-and-braces sweep the readers run so a lapsed
 * application can never be listed or approved even if its timer was lost.
 */
/obj/structure/overmap/ship/proc/prune_crew_applications()
	// Copied: qdel() takes the application off crew_applications from inside its own
	// Destroy(), and mutating the list being walked skips entries.
	for(var/datum/ship_application/application as anything in crew_applications.Copy())
		if(QDELETED(application) || application.waiting_time() >= SHIP_APPLICATION_EXPIRY)
			qdel(application)
	// A hard-deleted datum is nulled in place in the list rather than removed from it
	crew_applications -= null

/// The open application from this ckey, if there is one.
/obj/structure/overmap/ship/proc/find_crew_application(applicant_ckey)
	if(!applicant_ckey)
		return null
	prune_crew_applications()
	for(var/datum/ship_application/application as anything in crew_applications)
		if(application.ckey == applicant_ckey)
			return application
	return null

/**
 * Files an application to join this ship. Returns TRUE if one was filed.
 *
 * One open application per ckey per ship - re-applying while one is pending does
 * nothing, so a player cannot spam a captain's chat by mashing the button.
 */
/obj/structure/overmap/ship/proc/file_crew_application(mob/applicant, applicant_message)
	if(!applicant?.ckey)
		return FALSE
	if(!join_password)
		to_chat(applicant, span_warning("[name] is not locked - you can simply join it."))
		return FALSE
	if(is_password_cleared(applicant.ckey))
		to_chat(applicant, span_notice("You are already cleared to join [name]."))
		return FALSE
	if(find_crew_application(applicant.ckey))
		to_chat(applicant, span_warning("You already have an application waiting on [name]."))
		return FALSE

	applicant_message = trim("[applicant_message || ""]", SHIP_APPLICATION_MESSAGE_MAX_LEN + 1)
	if(!length(applicant_message))
		to_chat(applicant, span_warning("An application needs a message."))
		return FALSE

	var/name_used = applicant.client?.prefs?.read_preference(/datum/preference/name/real_name) || applicant.real_name || applicant.ckey
	var/datum/ship_application/application = new(src, applicant.ckey, name_used, applicant_message)
	crew_applications += application

	log_game("[key_name(applicant)] applied to join ship [name]")

	if(notify_captains_of_application(application))
		to_chat(applicant, span_notice("Application sent to [name]. Its captain has been told; you will hear back here."))
	else
		to_chat(applicant, span_notice("Application filed with [name]. Nobody aboard can review applications right now, but it will be waiting for them for the next [DisplayTimeText(SHIP_APPLICATION_EXPIRY)]."))
	return TRUE

/**
 * Chat-pings every captain of this ship who is online. Returns TRUE if anyone was
 * reachable, which is what tells the applicant whether to expect a quick answer.
 */
/obj/structure/overmap/ship/proc/notify_captains_of_application(datum/ship_application/application)
	var/reached_anyone = FALSE
	for(var/datum/mind/member as anything in ship_team?.members)
		var/mob/living/body = member?.current
		if(QDELETED(body) || !body.client)
			continue
		if(!is_ship_captain(body))
			continue
		reached_anyone = TRUE
		to_chat(body, boxed_message(span_boldnotice("CREW APPLICATION - [name]") + "\n" + \
			span_notice("[application.applicant_name] (ckey: [application.ckey]) is asking to join.") + "\n" + \
			span_notice("\"[html_encode(application.message)]\"") + "\n" + \
			"<a href='byond://?src=[REF(application)];approve=1'>APPROVE</a> | <a href='byond://?src=[REF(application)];deny=1'>DENY</a>"))
		SEND_SOUND(body, sound('voidcrew/sound/notify.ogg', volume = 25))
	return reached_anyone

/**
 * Approve or deny an application.
 *
 * Approval only clears the applicant's ckey past the join password. It does not seat
 * them, pick their job or put them on the roster - they still go through the join menu
 * like anyone else, which is what keeps the job slot accounting in one place.
 */
/obj/structure/overmap/ship/proc/resolve_crew_application(datum/ship_application/application, approved, mob/reviewer, deny_reason)
	if(QDELETED(application) || !(application in crew_applications))
		if(reviewer)
			to_chat(reviewer, span_warning("That application is no longer open."))
		return FALSE

	var/applicant_ckey = application.ckey
	var/applicant_name = application.applicant_name
	var/mob/applicant = get_mob_by_ckey(applicant_ckey)

	if(approved)
		password_cleared_ckeys[applicant_ckey] = TRUE
		if(applicant)
			to_chat(applicant, span_boldnotice("Your application to join [name] was approved. You can join it from the lobby without the password."))
			SEND_SOUND(applicant, sound('voidcrew/sound/notify.ogg', volume = 25))
		if(reviewer)
			to_chat(reviewer, span_notice("Approved [applicant_name] ([applicant_ckey])."))
		ship_notify("[applicant_name] has been cleared to join the crew.", "CREW UPDATE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 25)
		log_game("[key_name(reviewer)] approved [applicant_ckey]'s application to join ship [name]")
	else
		deny_reason = trim("[deny_reason || ""]", SHIP_APPLICATION_MESSAGE_MAX_LEN + 1)
		if(applicant)
			to_chat(applicant, span_warning("Your application to join [name] was denied.[length(deny_reason) ? " Reason: [html_encode(deny_reason)]" : ""]"))
		if(reviewer)
			to_chat(reviewer, span_notice("Denied [applicant_name] ([applicant_ckey])."))
		log_game("[key_name(reviewer)] denied [applicant_ckey]'s application to join ship [name][length(deny_reason) ? ": [deny_reason]" : ""]")

	qdel(application)
	return TRUE

/// Asks the reviewer for an optional reason, then denies. Split out because the prompt sleeps.
/obj/structure/overmap/ship/proc/prompt_deny_crew_application(datum/ship_application/application, mob/reviewer)
	if(QDELETED(application) || QDELETED(src))
		return
	// encode = FALSE for the same reason the join password takes raw input: the reason
	// is shown in a TGUI panel that escapes for itself, and html_encode()d at the one
	// place it reaches chat. Double-encoding here would print entities at the applicant.
	var/reason = tgui_input_text(reviewer, "Optional reason to send back with the denial.", "Deny [application.applicant_name]", max_length = SHIP_APPLICATION_MESSAGE_MAX_LEN, encode = FALSE, timeout = 60 SECONDS)
	if(QDELETED(application) || QDELETED(src))
		return
	if(!is_ship_captain(reviewer))
		to_chat(reviewer, span_warning("You do not hold command of [name]."))
		return
	resolve_crew_application(application, FALSE, reviewer, reason)

/**
 * Drops this ckey's open applications from every ship in the fleet.
 *
 * Called when someone joins a crew: whatever they were waiting on, they have a berth
 * now, and leaving the application open would have a captain approving a player who
 * is already somebody else's problem.
 */
/proc/clear_crew_applications_for_ckey(applicant_ckey)
	if(!applicant_ckey)
		return
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		var/datum/ship_application/application = ship.find_crew_application(applicant_ckey)
		if(application)
			qdel(application)
