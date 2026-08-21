/**
 * # Outpost Management Console
 *
 * The owner's control panel, spawned by every shell template and linked at
 * load (see player_outpost.dm link_interior_machinery). Owner actions are
 * ckey-gated so ownership survives death and respawn; everyone else gets a
 * read-only status view.
 *
 * The circuit board exists so a raided or deconstructed console can be
 * rebuilt, a fresh console relinks to the outpost whose z-level it's on.
 */

/obj/item/circuitboard/computer/player_outpost_management
	name = "Outpost Management (Computer Board)"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/computer/player_outpost_management

/obj/machinery/computer/player_outpost_management
	name = "outpost management console"
	desc = "Colonial registry terminal for the outpost's owner: naming, docking control, broadcasts and builder authorization."
	icon_screen = "id"
	icon_keyboard = "id_key"
	circuit = /obj/item/circuitboard/computer/player_outpost_management
	light_color = LIGHT_COLOR_ORANGE
	/// The outpost this console manages (set by link_interior_machinery, or found on Initialize for rebuilt consoles)
	var/obj/structure/overmap/dynamic/player_outpost/outpost

// Machinery always late-initializes; consoles the shell spawned get linked by
// link_interior_machinery, hand-rebuilt ones relink to their z-level's outpost here
/obj/machinery/computer/player_outpost_management/LateInitialize()
	. = ..()
	if(outpost)
		return
	for(var/obj/structure/overmap/dynamic/player_outpost/candidate as anything in GLOB.player_outposts)
		if(!candidate.mapzone)
			continue
		for(var/datum/space_level/level as anything in candidate.mapzone.z_levels)
			if(level.z_value == z)
				outpost = candidate
				if(!candidate.management_console)
					candidate.management_console = src
				return

/obj/machinery/computer/player_outpost_management/Destroy()
	if(outpost?.management_console == src)
		outpost.management_console = null
	outpost = null
	return ..()

/// Docking requests changed server-side; refresh any open UIs
/obj/machinery/computer/player_outpost_management/proc/on_dock_requests_changed()
	SStgui.update_uis(src)

/obj/machinery/computer/player_outpost_management/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OutpostManagement", name)
		ui.open()

/obj/machinery/computer/player_outpost_management/ui_data(mob/user)
	var/list/data = list()
	data["linked"] = !!outpost
	if(!outpost)
		return data

	outpost.prune_dock_requests()

	data["outpost_name"] = outpost.name
	data["founder_name"] = outpost.founder_name
	data["memo"] = outpost.memo
	data["is_owner"] = outpost.is_owner(user)
	data["has_owner"] = !!outpost.founder_ckey
	data["raidable"] = outpost.raidable
	data["dock_mode"] = outpost.dock_mode
	data["rename_cooldown"] = COOLDOWN_TIMELEFT(outpost, rename_cooldown) / 10
	data["advert_cost"] = OUTPOST_ADVERT_COST
	data["advert_cooldown"] = COOLDOWN_TIMELEFT(outpost, advert_cooldown) / 10
	data["advert_remaining"] = outpost.current_advert ? outpost.current_advert.get_remaining_seconds() : 0

	var/list/requests = list()
	for(var/obj/structure/overmap/ship/requester in outpost.pending_dock_requests)
		requests += list(list(
			"name" = requester.name,
			"ref" = REF(requester),
		))
	data["dock_requests"] = requests

	var/list/approved = list()
	for(var/obj/structure/overmap/ship/ship in outpost.approved_ships)
		if(QDELETED(ship))
			continue
		approved += list(list(
			"name" = ship.name,
			"ref" = REF(ship),
		))
	data["approved_ships"] = approved

	var/list/banned = list()
	for(var/obj/structure/overmap/ship/ship in outpost.banned_ships)
		if(QDELETED(ship))
			continue
		banned += list(list(
			"name" = ship.name,
			"ref" = REF(ship),
		))
	data["banned_ships"] = banned

	data["builders"] = outpost.authorized_builder_ckeys.Copy()

	// Living, connected players on the outpost z-level: candidates for
	// builder authorization and ownership transfer
	var/list/candidates = list()
	if(outpost.mapzone)
		for(var/mob/living/candidate as anything in outpost.mapzone.get_mind_mobs_in(outpost.footprint))
			if(!candidate.ckey || candidate.ckey == outpost.founder_ckey)
				continue
			candidates += list(list(
				"name" = candidate.real_name,
				"ckey" = candidate.ckey,
				"ref" = REF(candidate),
				"can_receive_outpost" = !(candidate.ckey in GLOB.player_outpost_founder_ckeys),
			))
	data["candidates"] = candidates

	return data

/obj/machinery/computer/player_outpost_management/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!outpost)
		return

	// Everything below is owner-only
	if(!outpost.is_owner(usr))
		to_chat(usr, span_warning("The console rejects you. You aren't the registered owner."))
		return

	. = TRUE

	switch(action)
		if("rename")
			var/new_name = trim(params["name"])
			if(!length(new_name) || new_name == outpost.name)
				return
			if(!reject_bad_text(new_name, MAX_CHARTER_LEN))
				say("Registry rejected that designation.")
				return
			if(!outpost.set_outpost_name(new_name, usr))
				say("Registry cooldown: [COOLDOWN_TIMELEFT(outpost, rename_cooldown) / 10] seconds before the outpost can be renamed.")

		if("set_memo")
			var/new_memo = copytext(sanitize(params["memo"]), 1, PLAYER_OUTPOST_MEMO_MAX_LEN)
			outpost.set_memo(trim(new_memo))

		if("buy_advert")
			buy_advert(usr)

		if("set_dock_mode")
			var/new_mode = params["mode"]
			if(!(new_mode in list(OUTPOST_DOCK_MODE_OPEN, OUTPOST_DOCK_MODE_REQUEST, OUTPOST_DOCK_MODE_LOCKDOWN)))
				return
			outpost.dock_mode = new_mode

		if("approve_request")
			var/obj/structure/overmap/ship/requester = locate(params["ref"]) in outpost.pending_dock_requests
			if(requester)
				outpost.approve_dock_request(requester)

		if("deny_request")
			var/obj/structure/overmap/ship/requester = locate(params["ref"]) in outpost.pending_dock_requests
			if(requester)
				outpost.deny_dock_request(requester)

		if("ban_ship")
			var/obj/structure/overmap/ship/target = locate(params["ref"]) in SSovermap.simulated_ships
			if(!target)
				return
			outpost.banned_ships[target] = TRUE
			outpost.approved_ships -= target
			if(target in outpost.pending_dock_requests)
				outpost.deny_dock_request(target)

		if("unban_ship")
			var/obj/structure/overmap/ship/target = locate(params["ref"]) in outpost.banned_ships
			if(target)
				outpost.banned_ships -= target

		if("revoke_approval")
			var/obj/structure/overmap/ship/target = locate(params["ref"]) in outpost.approved_ships
			if(target)
				outpost.approved_ships -= target

		if("add_builder")
			var/mob/living/candidate = locate(params["ref"])
			if(!istype(candidate) || !candidate.ckey)
				return
			if(!outpost.mapzone || !(candidate in outpost.mapzone.get_mind_mobs_in(outpost.footprint)))
				return
			outpost.authorized_builder_ckeys |= candidate.ckey
			to_chat(candidate, span_notice("You are now authorized to use [outpost.name]'s construction console."))

		if("remove_builder")
			outpost.authorized_builder_ckeys -= params["ckey"]

		if("transfer")
			var/mob/living/candidate = locate(params["ref"])
			if(!istype(candidate) || !candidate.ckey)
				return
			if(!outpost.mapzone || !(candidate in outpost.mapzone.get_mind_mobs_in(outpost.footprint)))
				return
			if(tgui_alert(usr, "Transfer ownership of [outpost.name] to [candidate.real_name]? This cannot be undone.", "Transfer Ownership", list("Transfer", "Cancel")) != "Transfer")
				return
			if(!outpost.transfer_ownership(candidate, usr))
				say("Transfer refused: the recipient already holds a claim this shift.")

		if("abandon")
			if(tgui_alert(usr, "Abandon [outpost.name]? You will lose ownership for the rest of the shift and cannot found another outpost.", "Abandon Outpost", list("Abandon", "Cancel")) != "Abandon")
				return
			outpost.abandon(usr)

/**
 * Charges the buyer's ID account and puts out a galaxy-wide broadcast.
 */
/obj/machinery/computer/player_outpost_management/proc/buy_advert(mob/living/user)
	if(outpost.current_advert)
		say("A broadcast is already live.")
		return
	if(!COOLDOWN_FINISHED(outpost, advert_cooldown))
		say("Broadcast array recharging: [COOLDOWN_TIMELEFT(outpost, advert_cooldown) / 10] seconds.")
		return
	var/obj/item/card/id/id_card = user.get_idcard(TRUE)
	var/datum/bank_account/account = id_card?.registered_account
	if(!account)
		say("No bank account on your ID.")
		return
	if(!account.has_money(OUTPOST_ADVERT_COST))
		say("Insufficient credits: broadcast costs [OUTPOST_ADVERT_COST] cr.")
		return
	if(!account.adjust_money(-OUTPOST_ADVERT_COST, "Outpost Broadcast: [outpost.name]"))
		say("Transaction failed.")
		return
	COOLDOWN_START(outpost, advert_cooldown, OUTPOST_ADVERT_COOLDOWN)
	outpost.current_advert = new /datum/outpost_advert(outpost)
	say("Broadcast live galaxy-wide for [OUTPOST_ADVERT_DURATION / 600] minutes.")
	log_game("PLAYER OUTPOST: [key_name(user)] bought an advertisement for '[outpost.name]'")
