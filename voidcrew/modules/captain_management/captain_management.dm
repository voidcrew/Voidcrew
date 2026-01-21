// ===== CAPTAIN SHIP MANAGEMENT SYSTEM =====
// Provides captains with an action button to manage their ship's crew,
// rename the ship, and set a memo for joining players.

// ===== ACTION BUTTON =====

/datum/action/innate/captain_management
	name = "Ship Management"
	desc = "Open the captain's ship management panel to manage crew, invites, and ship settings."
	button_icon = 'icons/hud/actions.dmi'
	button_icon_state = "round_end"
	check_flags = AB_CHECK_CONSCIOUS

	/// Reference to the ship this action controls
	var/obj/structure/overmap/ship/managed_ship

/datum/action/innate/captain_management/New(Target, obj/structure/overmap/ship/ship)
	. = ..()
	managed_ship = ship

/datum/action/innate/captain_management/Activate()
	if(!managed_ship || QDELETED(managed_ship))
		to_chat(owner, span_warning("Your ship no longer exists!"))
		Remove(owner)
		return

	// Open TGUI via the UI datum
	var/datum/captain_management_ui/ui_datum = new(managed_ship, owner)
	ui_datum.ui_interact(owner)

/datum/action/innate/captain_management/Remove(mob/remove_from)
	managed_ship = null
	return ..()

// ===== UI DATUM =====

/datum/captain_management_ui
	/// The ship being managed
	var/obj/structure/overmap/ship/ship
	/// The captain using this UI
	var/mob/living/captain

/datum/captain_management_ui/New(obj/structure/overmap/ship/target_ship, mob/living/user)
	ship = target_ship
	captain = user

/datum/captain_management_ui/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "CaptainManagement")
		ui.open()

/datum/captain_management_ui/ui_state(mob/user)
	return GLOB.always_state

/datum/captain_management_ui/ui_data(mob/user)
	var/list/data = list()

	if(!ship || QDELETED(ship))
		data["ship_destroyed"] = TRUE
		return data

	data["ship_destroyed"] = FALSE

	// Ship info
	data["ship_name"] = ship.name
	data["memo"] = ship.memo || ""
	data["joining_allowed"] = ship.joining_allowed

	// Check if user is still captain
	data["is_captain"] = ship.is_ship_captain(captain)

	// Crew list
	data["crew"] = list()
	if(ship.ship_team)
		for(var/datum/mind/member in ship.ship_team.members)
			if(!member.current)
				continue
			var/is_captain = ship.is_ship_captain(member.current)
			data["crew"] += list(list(
				"name" = member.current.real_name,
				"job" = member.assigned_role?.title || "Unknown",
				"ref" = REF(member),
				"is_captain" = is_captain,
				"is_online" = !!member.current.client
			))

	// Available players to invite (living players in captain's view, not on this ship)
	data["available_players"] = list()
	for(var/mob/living/carbon/human/player in view(captain))
		if(player == captain)
			continue
		if(!player.client)
			continue
		if(!player.mind)
			continue
		// Skip players already on this ship
		if(player.mind in ship.ship_team?.members)
			continue
		// Skip players with pending invites
		if(player.ckey in ship.pending_invites)
			continue
		data["available_players"] += list(list(
			"name" = player.real_name,
			"ckey" = player.ckey,
			"job" = player.mind.assigned_role?.title || "Unknown"
		))

	// Pending invites
	data["pending_invites"] = list()
	for(var/ckey in ship.pending_invites)
		data["pending_invites"] += list(list(
			"ckey" = ckey,
			"time" = ship.pending_invites[ckey]
		))

	data["can_invite"] = COOLDOWN_FINISHED(ship, invite_cooldown)
	data["can_rename"] = COOLDOWN_FINISHED(ship, rename_cooldown)

	return data

/datum/captain_management_ui/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	if(!ship || QDELETED(ship))
		to_chat(captain, span_warning("Your ship no longer exists!"))
		return TRUE

	// Verify captain status for all actions except viewing
	if(!ship.is_ship_captain(captain))
		to_chat(captain, span_warning("You are no longer the captain!"))
		return TRUE

	switch(action)
		if("kick_crew")
			var/datum/mind/target = locate(params["ref"])
			if(!target || !(target in ship.ship_team?.members))
				to_chat(captain, span_warning("Crew member not found."))
				return TRUE
			if(ship.is_ship_captain(target.current))
				to_chat(captain, span_warning("You cannot kick yourself!"))
				return TRUE
			kick_crew_member(target)
			return TRUE

		if("invite_player")
			var/ckey = params["ckey"]
			if(!ckey)
				return TRUE
			send_ship_invite(ckey)
			return TRUE

		if("cancel_invite")
			var/ckey = params["ckey"]
			if(ckey in ship.pending_invites)
				ship.pending_invites -= ckey
				to_chat(captain, span_notice("Cancelled invite to [ckey]."))
			return TRUE

		if("rename_ship")
			var/new_name = params["name"]
			if(!new_name)
				return TRUE
			new_name = trim(new_name)
			if(length(new_name) < 2 || length(new_name) > 42)
				to_chat(captain, span_warning("Ship name must be 2-42 characters."))
				return TRUE
			if(!COOLDOWN_FINISHED(ship, rename_cooldown))
				to_chat(captain, span_warning("Ship rename is on cooldown."))
				return TRUE

			var/old_name = ship.name
			ship.name = new_name
			if(ship.ship_team)
				ship.ship_team.name = new_name
			COOLDOWN_START(ship, rename_cooldown, 5 MINUTES)
			ship.ship_notify("This vessel has been renamed from [old_name] to [new_name].", "SHIP SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
			log_game("[key_name(captain)] renamed ship from [old_name] to [new_name]")
			return TRUE

		if("set_memo")
			var/new_memo = params["memo"]
			if(length(new_memo) > 500)
				new_memo = copytext(new_memo, 1, 501)
			ship.memo = new_memo
			to_chat(captain, span_notice("Ship memo updated."))
			return TRUE

		if("toggle_joining")
			ship.joining_allowed = !ship.joining_allowed
			to_chat(captain, span_notice("Cryopod joining is now [ship.joining_allowed ? "enabled" : "disabled"]."))
			return TRUE

// ===== INVITE SYSTEM =====

/// Send an invite to a living player
/datum/captain_management_ui/proc/send_ship_invite(ckey)
	if(!COOLDOWN_FINISHED(ship, invite_cooldown))
		to_chat(captain, span_warning("Please wait before sending another invite."))
		return FALSE

	var/mob/living/carbon/human/target_player
	for(var/mob/living/carbon/human/player in GLOB.player_list)
		if(player.ckey == ckey && player.client)
			target_player = player
			break

	if(!target_player)
		to_chat(captain, span_warning("Player not found or no longer available."))
		return FALSE

	ship.pending_invites[ckey] = world.time
	COOLDOWN_START(ship, invite_cooldown, 5 SECONDS)

	to_chat(captain, span_notice("Sent ship invite to [target_player.real_name]."))

	// Send invite popup to the player asynchronously
	INVOKE_ASYNC(src, PROC_REF(process_invite_response), target_player, ckey)
	return TRUE

/datum/captain_management_ui/proc/process_invite_response(mob/living/carbon/human/player, ckey)
	var/memo_text = ship.memo ? "\n\nShip Memo: [ship.memo]" : ""
	var/response = tgui_alert(player,
		"Captain [captain.real_name] has invited you to join the crew of [ship.name].[memo_text]",
		"Ship Invitation",
		list("Accept", "Decline"),
		timeout = 60 SECONDS
	)

	// Clean up invite regardless of response
	ship.pending_invites -= ckey

	if(response != "Accept")
		if(captain?.client)
			to_chat(captain, span_notice("[player.real_name] declined your invitation."))
		return

	if(!player?.client || !player.mind)
		return // Player left or is no longer valid

	if(!ship || QDELETED(ship))
		to_chat(player, span_warning("The ship no longer exists!"))
		return

	// Check if player is already on a ship team - remove them first
	for(var/datum/team/voidcrew/old_team in player.mind.ship_teams)
		if(old_team != ship.ship_team)
			old_team.remove_member(player.mind)

	// Add player to ship team
	if(ship.ship_team)
		ship.ship_team.add_member(player.mind)
		ship.manifest += player.real_name

	to_chat(player, span_notice("You have joined the crew of [ship.name]!"))
	ship.ship_notify("[player.real_name] has joined the crew.", "CREW UPDATE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	log_game("[key_name(captain)] invited [key_name(player)] to ship [ship.name]")

// ===== CREW MANAGEMENT =====

/// Kick a crew member from the ship
/datum/captain_management_ui/proc/kick_crew_member(datum/mind/target)
	if(!target?.current)
		return

	var/mob/living/kicked_mob = target.current
	var/kicked_name = kicked_mob.real_name

	// Remove from ship team
	if(ship.ship_team)
		ship.ship_team.remove_member(target)

	// Remove from manifest
	ship.manifest -= kicked_name

	to_chat(kicked_mob, span_userdanger("You have been removed from [ship.name]'s crew by the captain!"))
	ship.ship_notify("[kicked_name] has been removed from the crew roster.", "CREW UPDATE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 25)
	log_game("[key_name(captain)] kicked [key_name(kicked_mob)] from ship [ship.name]")

// ===== MEMO DISPLAY HELPER =====

/// Shows the ship memo to a player after they spawn
/proc/show_ship_memo_to_player(mob/living/player, obj/structure/overmap/ship/ship)
	if(!player?.client || QDELETED(ship))
		return
	if(!ship.memo || ship.memo == "")
		return

	to_chat(player, boxed_message(span_notice("<b>Ship Memo from [ship.name]:</b>\n[ship.memo]")))
