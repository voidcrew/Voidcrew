/**
 * Ship Join Menu UI
 *
 * TGUI interface for selecting a ship to join or purchasing a new one.
 * Provides clear separation between starting your own ship and joining existing crews.
 */
/datum/ship_join_menu
	/// The player using this menu
	var/mob/dead/new_player/user

/**
 * Every ship the join menu is willing to show a player: it exists, it has somewhere to
 * put them, it is accepting crew, and it is not an NPC hull nobody has claimed yet.
 *
 * Shared by the menu's ship list and the requisition gate so the two can never disagree
 * about what counts as an available ship. Ships with no free positions are still in
 * here - they're listed with the Join button disabled.
 */
/proc/get_joinable_ships()
	var/list/obj/structure/overmap/ship/joinable = list()
	for(var/obj/structure/overmap/ship/candidate as anything in SSovermap.simulated_ships)
		if(isnull(candidate.shuttle))
			continue
		if(length(candidate.shuttle.spawn_points) <= 0 || !candidate.joining_allowed)
			continue
		var/obj/structure/overmap/ship/npc/npc_ship = candidate
		if(istype(npc_ship) && !npc_ship.player_controlled)
			continue
		joinable += candidate
	return joinable

/// Whether a ship has any job with a position still open on it.
/proc/ship_has_open_slots(obj/structure/overmap/ship/ship)
	for(var/datum/job/job as anything in ship.job_slots)
		if(ship.job_slots[job] > 0)
			return TRUE
	return FALSE

/**
 * Whether a free hull can be requisitioned right now, for this player.
 *
 * Requisition is the fleet's floor, not a way around it. It opens only when there is
 * nowhere left in the fleet to sit - every ship full, or every ship destroyed. While
 * any hull still has an open position the player joins that instead, which is what
 * keeps a wiped crew regrouping onto one replacement rather than scattering onto a
 * hull each, and keeps parts worth saving: they buy you the hull you want on demand,
 * not access to a hull at all.
 *
 * Per-player because of join passwords: a locked hull is not a seat for someone who
 * can't get through its door, and without this a fleet of nothing but locked ships
 * would leave a newcomer unable to join anything OR requisition.
 */
/proc/can_requisition_hull(mob/user)
	for(var/obj/structure/overmap/ship/ship as anything in get_joinable_ships())
		if(!ship_has_open_slots(ship))
			continue
		if(!ship.is_password_cleared(user?.ckey))
			continue
		return FALSE
	return TRUE

/datum/ship_join_menu/New(mob/dead/new_player/player)
	. = ..()
	user = player

/datum/ship_join_menu/Destroy()
	user = null
	return ..()

/datum/ship_join_menu/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipJoinMenu")
		ui.open()

/datum/ship_join_menu/ui_state(mob/user)
	return GLOB.always_state

/datum/ship_join_menu/ui_static_data(mob/user)
	var/list/data = list()
	// Grey the button out client-side rather than handing out a button that
	// only ever errors - same rule the lobby wiki button follows.
	data["wiki_url"] = CONFIG_GET(string/wikiurl)
	return data

/datum/ship_join_menu/ui_data(mob/user)
	var/list/data = list()

	// Player name for welcome message
	var/used_name = user.client?.prefs?.read_preference(/datum/preference/name/real_name) || "Spacer"
	data["player_name"] = used_name

	// Build list of active ships
	var/list/ships = list()
	for(var/obj/structure/overmap/ship/active_ship as anything in get_joinable_ships())
		var/crew_count = length(active_ship.manifest)
		var/class_name = active_ship.source_template?.short_name || "Unknown Class"

		// Build job list with available slots
		var/list/jobs = list()
		for(var/datum/job/job as anything in active_ship.job_slots)
			var/slots = active_ship.job_slots[job]
			if(slots > 0)
				jobs += list(list(
					"name" = job.title,
					"slots" = slots
				))

		// Crew applications: the alternative to knowing the password. Pruned here rather
		// than on a timer - the menu is the only place the state is ever read from.
		active_ship.prune_join_applications()
		var/cleared = active_ship.is_password_cleared(user.ckey)
		var/datum/ship_join_application/application = active_ship.get_join_application(user.ckey)
		var/application_status
		var/application_note
		if(application)
			application_status = application.status
			switch(application.status)
				if(SHIP_APPLICATION_PENDING)
					application_note = "Waiting on the captain - lapses in [DisplayTimeText(max(0, (application.created_at + SHIP_JOIN_APPLICATION_TIMEOUT) - world.time))]."
				if(SHIP_APPLICATION_DENIED)
					application_note = application.deny_reason ? "Declined: [application.deny_reason]" : "Declined, no reason given."
				if(SHIP_APPLICATION_EXPIRED)
					application_note = "Nobody answered in time."
				if(SHIP_APPLICATION_WITHDRAWN)
					application_note = "You withdrew this application."

		ships += list(list(
			"ref" = REF(active_ship),
			"name" = active_ship.name,
			"class_name" = class_name,
			"crew_count" = crew_count,
			"jobs" = jobs,
			"memo" = active_ship.memo,
			"locked" = !!active_ship.join_password,
			"password_cleared" = cleared,
			"application_status" = application_status,
			"application_note" = application_note,
			// Only offer the button where it can actually do something: a locked hull the
			// player has no clearance for, with a seat still on it and nothing already filed.
			"can_apply" = (!!active_ship.join_password && !cleared && ship_has_open_slots(active_ship) && isnull(application))
		))

	data["ships"] = ships
	data["can_requisition"] = can_requisition_hull(user)
	return data

/datum/ship_join_menu/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return TRUE

	. = TRUE

	switch(action)
		if("open_wiki")
			var/wiki_url = CONFIG_GET(string/wikiurl)
			if(!wiki_url)
				return FALSE
			// Hands the link to the player's own browser; TGUI itself has no way
			// out to an external site.
			DIRECT_OUTPUT(user, link(wiki_url))

		if("purchase_ship")
			// Close this menu and open the ship shop - hull, theme and modules all
			// live in the one UI that shows you what you're buying
			ui.close()
			var/datum/callback/cb = CALLBACK(user, TYPE_PROC_REF(/mob/dead/new_player, on_upgrades_confirmed))
			var/datum/ship_upgrade_selector/selector = new(user, null, cb)
			selector.ui_interact(user)

		if("requisition_hull")
			// Re-checked in requisition_free_hull() too - the UI is never the authority
			// on this, and the fleet can fill up while the menu sits open
			if(!can_requisition_hull(user))
				to_chat(user, span_warning("There are still open positions in the fleet. Join one of those instead."))
				return FALSE
			ui.close()
			user.requisition_free_hull()

		if("apply_to_ship")
			var/obj/structure/overmap/ship/ship = locate(params["ship_ref"])
			if(!istype(ship))
				to_chat(user, span_warning("That ship is no longer available."))
				return FALSE
			// Prompting inside ui_act would hold the act loop open while the player types.
			// The menu deliberately stays up behind the prompt: applying is not leaving the
			// lobby, and they should be able to keep browsing while they wait for an answer.
			INVOKE_ASYNC(src, PROC_REF(prompt_ship_application), ship)

		if("withdraw_application")
			var/obj/structure/overmap/ship/ship = locate(params["ship_ref"])
			if(!istype(ship))
				return FALSE
			var/datum/ship_join_application/application = ship.get_join_application(user.ckey)
			if(!application || !application.withdraw())
				return FALSE

		if("select_ship")
			var/ship_ref = params["ship_ref"]
			if(!ship_ref)
				return FALSE

			var/obj/structure/overmap/ship/ship = locate(ship_ref)
			if(!istype(ship))
				to_chat(user, span_warning("That ship is no longer available."))
				return FALSE

			// Verify ship is still accepting crew
			if(!ship.joining_allowed)
				to_chat(user, span_warning("That ship is not accepting new crew members."))
				return FALSE
			// Block unclaimed NPC ships
			var/obj/structure/overmap/ship/npc/npc_ship = ship
			if(istype(npc_ship) && !npc_ship.player_controlled)
				to_chat(user, span_warning("That ship is not accepting new crew members."))
				return FALSE

			if(length(ship.shuttle?.spawn_points) <= 0)
				to_chat(user, span_warning("That ship has no spawn points available."))
				return FALSE

			// Close menu and proceed to job selection
			ui.close()
			user.select_job_on_ship(ship)

/**
 * Asks the applicant for a note and files the application. The note is optional - an empty
 * one is a perfectly good "can I come aboard", and forcing a sales pitch out of someone who
 * only wants a seat is how you end up back at everyone locking their ships.
 *
 * submit_join_application() re-checks everything: this sleeps, and a captain can unlock the
 * hull, fill the last seat or blow up while the box is open.
 */
/datum/ship_join_menu/proc/prompt_ship_application(obj/structure/overmap/ship/ship)
	// encode = FALSE to match how the note is read back out into TGUI text fields, the same
	// reason the password prompt does it.
	var/note = tgui_input_text(
		user,
		"Ask [ship.name]'s captain for a seat. Add a note if you want - your ckey and character name are shown to them either way. Leave it blank to just knock.",
		"[ship.name] - Crew Application",
		max_length = SHIP_JOIN_APPLICATION_MSG_MAX_LEN,
		encode = FALSE,
		timeout = 2 MINUTES,
	)
	if(isnull(note) || QDELETED(ship) || QDELETED(user))
		return
	ship.submit_join_application(user, note)
