// ===== ADMIN SHIP CREW MANAGEMENT PANEL =====
// Admin counterpart to the captain's Ship Management panel: instead of one ship
// gated on captaincy, this lists every simulated ship and lets an admin promote,
// demote, kick, and force-add crew on any of them.

ADMIN_VERB(manage_ship_crews, R_ADMIN, "Manage Ship Crews", "View and manage every ship's crew roster.", ADMIN_CATEGORY_GAME)
	var/datum/admin_crew_panel/panel = new
	panel.ui_interact(user.mob)
	BLACKBOX_LOG_ADMIN_VERB("Manage Ship Crews")

/datum/admin_crew_panel
	/// The ship whose roster is currently shown
	var/obj/structure/overmap/ship/selected_ship

/datum/admin_crew_panel/ui_state(mob/user)
	return ADMIN_STATE(R_ADMIN)

/datum/admin_crew_panel/ui_close(mob/user)
	qdel(src)

/datum/admin_crew_panel/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AdminCrewManagement")
		ui.open()

/datum/admin_crew_panel/ui_data(mob/user)
	var/list/data = list()

	data["ships"] = list()
	for(var/obj/structure/overmap/ship/ship in SSovermap.simulated_ships)
		if(QDELETED(ship))
			continue
		data["ships"] += list(list(
			"name" = ship.display_name || ship.name,
			"ref" = REF(ship),
			"crew_count" = length(ship.ship_team?.members),
		))

	if(QDELETED(selected_ship))
		selected_ship = null

	data["selected_ref"] = selected_ship ? REF(selected_ship) : null
	data["ship_name"] = null
	data["memo"] = null
	data["joining_allowed"] = FALSE
	data["crew"] = list()
	data["addable_players"] = list()

	if(!selected_ship)
		return data

	data["ship_name"] = selected_ship.display_name || selected_ship.name
	data["memo"] = selected_ship.memo || ""
	data["joining_allowed"] = selected_ship.joining_allowed

	for(var/datum/mind/member in selected_ship.ship_team?.members)
		data["crew"] += list(list(
			"name" = member.current?.real_name || member.name || "Unknown",
			"job" = member.assigned_role?.title || "Unknown",
			"ref" = REF(member),
			"is_captain" = selected_ship.is_ship_captain_mind(member),
			"is_online" = !!member.current?.client,
		))

	for(var/mob/living/carbon/human/player in GLOB.player_list)
		if(!player.client || !player.mind)
			continue
		if(player.mind in selected_ship.ship_team?.members)
			continue
		data["addable_players"] += list(list(
			"name" = player.real_name,
			"ckey" = player.ckey,
			"ref" = REF(player.mind),
		))

	return data

/datum/admin_crew_panel/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!check_rights(R_ADMIN))
		return

	switch(action)
		if("select_ship")
			var/obj/structure/overmap/ship/ship = locate(params["ref"]) in SSovermap.simulated_ships
			selected_ship = QDELETED(ship) ? null : ship
			return TRUE

		if("promote")
			var/datum/mind/target = locate(params["ref"]) in selected_ship?.ship_team?.members
			if(target)
				promote_to_captain(target, ui.user)
			return TRUE

		if("demote")
			var/datum/mind/target = locate(params["ref"]) in selected_ship?.ship_team?.members
			if(target)
				demote_from_captain(target, selected_ship, ui.user)
			return TRUE

		if("kick")
			var/datum/mind/target = locate(params["ref"]) in selected_ship?.ship_team?.members
			if(target)
				kick_crew_member(target, ui.user)
			return TRUE

		if("add_crew")
			var/datum/mind/target = locate(params["ref"])
			if(target?.current)
				add_crew_member(target, ui.user)
			return TRUE

// ===== ROSTER OPERATIONS =====

/// Removes captaincy from a team mind without touching their membership. Returns TRUE if they were captain.
/datum/admin_crew_panel/proc/demote_from_captain(datum/mind/member, obj/structure/overmap/ship/ship, mob/user)
	var/is_claimed = ship.claimed_captain == member
	var/is_acting = ship.acting_captain == member
	var/datum/job/captain_job = ship.get_captain_job()
	var/is_job_captain = captain_job && member.assigned_role == captain_job
	if(!is_claimed && !is_acting && !is_job_captain)
		return FALSE

	if(is_claimed)
		ship.claimed_captain = null
	if(is_acting)
		ship.acting_captain = null
	if(is_job_captain)
		// Hand them the hull's first non-officer job; single-job hulls have none, so
		// the demoted captain ends up roleless (admin-only edge case, worth logging).
		var/datum/job/replacement
		for(var/datum/job/job in ship.job_slots)
			if(!job.officer && job != captain_job)
				replacement = job
				break
		member.assigned_role = replacement

	ship.refresh_command_buttons()
	if(member.current && user)
		to_chat(member.current, span_warning("An admin has relieved you of command of [ship.name]."))

	if(user)
		log_admin("[key_name(user)] demoted [key_name(member.current || member)] from captain of [ship.name].")
	return TRUE

/// Transfers captaincy of the selected ship to the given team mind.
/datum/admin_crew_panel/proc/promote_to_captain(datum/mind/target, mob/user)
	var/obj/structure/overmap/ship/ship = selected_ship
	if(QDELETED(ship) || !ship.ship_team)
		return

	// Demote everyone currently holding command (usually one, but claimed + job
	// captain can coexist and both would otherwise keep their authority).
	for(var/datum/mind/member in ship.ship_team.members)
		if(member == target)
			continue
		demote_from_captain(member, ship, user)

	var/datum/job/captain_job = ship.get_captain_job()
	if(captain_job)
		target.assigned_role = captain_job
	// An admin appointment is exclusive, just like a command transfer or election.
	ship.claimed_captain = target
	ship.acting_captain = null
	ship.refresh_command_buttons()

	if(target.current)
		to_chat(target.current, span_notice("An admin has made you captain of [ship.name]."))

	ship.ship_notify("[target.current?.real_name || target.name] now holds command of the ship.", "CREW UPDATE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	message_admins("[key_name_admin(user)] made [key_name_admin(target.current || target)] captain of [ship.name].")
	log_admin("[key_name(user)] made [key_name(target.current || target)] captain of [ship.name].")

/// Removes a crew member from the selected ship's roster entirely.
/datum/admin_crew_panel/proc/kick_crew_member(datum/mind/target, mob/user)
	var/obj/structure/overmap/ship/ship = selected_ship
	if(QDELETED(ship))
		return

	var/kicked_name = target.current?.real_name || target.name

	// team.remove_member() already retires their Ship Management button for this hull
	if(ship.claimed_captain == target)
		ship.claimed_captain = null
	ship.ship_team?.remove_member(target)
	ship.manifest -= kicked_name

	if(target.current)
		to_chat(target.current, span_userdanger("You have been removed from [ship.name]'s crew by an admin!"))
	ship.ship_notify("[kicked_name] has been removed from the crew roster.", "CREW UPDATE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 25)
	message_admins("[key_name_admin(user)] kicked [key_name_admin(target.current || target)] from ship [ship.name].")
	log_admin("[key_name(user)] kicked [key_name(target.current || target)] from ship [ship.name].")

/// Force-adds an already-spawned player to the selected ship's roster.
/datum/admin_crew_panel/proc/add_crew_member(datum/mind/target, mob/user)
	var/obj/structure/overmap/ship/ship = selected_ship
	if(QDELETED(ship) || !target.current)
		return

	if(!ship.enlist_crewmember(target.current))
		to_chat(user, span_warning("Failed to add [target.name] to [ship.name]."))
		return

	var/added_name = target.current.real_name
	to_chat(target.current, span_notice("An admin has added you to the crew of [ship.name]."))
	ship.ship_notify("[added_name] has joined the crew.", "CREW UPDATE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	message_admins("[key_name_admin(user)] added [key_name_admin(target.current)] to ship [ship.name].")
	log_admin("[key_name(user)] added [key_name(target.current)] to ship [ship.name].")
