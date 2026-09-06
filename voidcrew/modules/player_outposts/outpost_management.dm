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
	/// Reused claim-bound UI; the console is only a compatible physical launcher.
	var/datum/player_outpost_management_ui/panel

// Machinery always late-initializes; consoles the shell spawned get linked by
// link_interior_machinery, hand-rebuilt ones relink to their z-level's outpost here
/obj/machinery/computer/player_outpost_management/LateInitialize()
	. = ..()
	outpost = get_outpost_from_atom(src)
	if(outpost && !outpost.management_console)
		outpost.management_console = src

/obj/machinery/computer/player_outpost_management/Destroy()
	QDEL_NULL(panel)
	if(outpost?.management_console == src)
		outpost.management_console = null
	outpost = null
	return ..()

/// Docking requests changed server-side; refresh any open UIs
/obj/machinery/computer/player_outpost_management/proc/on_dock_requests_changed()
	SStgui.update_uis(src)
	if(panel)
		SStgui.update_uis(panel)

/obj/machinery/computer/player_outpost_management/ui_interact(mob/user, datum/tgui/ui)
	outpost = get_outpost_from_atom(src)
	if(!panel || panel.outpost != outpost)
		QDEL_NULL(panel)
		panel = new(outpost, user)
	panel.manager = user
	panel.ui_interact(user, ui)

/obj/machinery/computer/player_outpost_management/ui_data(mob/user)
	outpost = get_outpost_from_atom(src)
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

	// Claim-owned facilities count too; visiting ships remain separate sites.
	var/list/candidates = list()
	for(var/mob/living/candidate as anything in GLOB.mob_living_list)
		if(!outpost.is_management_candidate(candidate) || candidate.ckey == outpost.founder_ckey)
			continue
		candidates += list(list(
			"name" = candidate.real_name,
			"ckey" = candidate.ckey,
			"ref" = REF(candidate),
			"can_receive_outpost" = !(candidate.ckey in GLOB.player_outpost_founder_ckeys),
			"is_resident" = candidate.mind in outpost.residents,
		))
	data["candidates"] = candidates

	data += home_service_data(user)
	return data

/obj/machinery/computer/player_outpost_management/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!outpost)
		return

	if(get_outpost_from_atom(src) != outpost)
		return
	if(home_service_action(action, params, usr))
		return TRUE
	if(action in list("transfer", "abandon", "add_builder", "remove_builder"))
		if(!outpost.is_owner(usr))
			return
	else if(!outpost.can_manage(usr))
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
			if(new_mode == OUTPOST_DOCK_MODE_LOCKDOWN)
				outpost.approved_ships.Cut()
				for(var/obj/structure/overmap/ship/requester in outpost.pending_dock_requests.Copy())
					outpost.deny_dock_request(requester)

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
			if(!outpost.is_management_candidate(candidate))
				return
			outpost.authorized_builder_ckeys |= candidate.ckey
			to_chat(candidate, span_notice("You are now authorized to use [outpost.name]'s construction console."))

		if("remove_builder")
			outpost.authorized_builder_ckeys -= params["ckey"]

		if("transfer")
			var/mob/living/candidate = locate(params["ref"])
			var/obj/structure/overmap/dynamic/player_outpost/original_outpost = outpost
			if(!original_outpost.is_management_candidate(candidate))
				return
			var/mob/acting_user = usr
			var/turf/original_console_turf = get_turf(src)
			var/datum/mind/original_candidate_mind = candidate.mind
			var/original_candidate_ckey = candidate.ckey
			var/datum/ui_state/prompt_state = ui.state
			if(!confirm_ownership_action(acting_user, "Transfer ownership of [original_outpost.name] to [candidate.real_name]? This cannot be undone.", "Transfer Ownership", "Transfer"))
				return
			if(!ownership_prompt_valid(original_outpost, acting_user, original_console_turf, prompt_state) \
				|| !original_outpost.is_management_candidate(candidate) \
				|| candidate.mind != original_candidate_mind || candidate.ckey != original_candidate_ckey)
				return
			if(!original_outpost.transfer_ownership(candidate, acting_user))
				say("Transfer refused: the recipient already holds a claim this shift.")

		if("abandon")
			var/obj/structure/overmap/dynamic/player_outpost/original_outpost = outpost
			var/mob/acting_user = usr
			var/turf/original_console_turf = get_turf(src)
			var/datum/ui_state/prompt_state = ui.state
			if(!confirm_ownership_action(acting_user, "Abandon [original_outpost.name]? You will lose ownership for the rest of the shift and cannot found another outpost.", "Abandon Outpost", "Abandon"))
				return
			if(!ownership_prompt_valid(original_outpost, acting_user, original_console_turf, prompt_state))
				return
			original_outpost.abandon(acting_user)

/// Preserve the existing minded, non-dead player eligibility on every claim-owned site.
/obj/structure/overmap/dynamic/player_outpost/proc/is_management_candidate(mob/living/candidate)
	return istype(candidate) && !QDELETED(candidate) && !QDELETED(candidate.mind) && candidate.ckey \
		&& candidate.stat != DEAD && get_outpost_from_atom(candidate) == src

/obj/machinery/computer/player_outpost_management/proc/confirm_ownership_action(mob/user, prompt_text, title, confirm_label)
	return tgui_alert(user, prompt_text, title, list(confirm_label, "Cancel")) == confirm_label

/// A yielding confirmation must still refer to its original console, claim and owner.
/obj/machinery/computer/player_outpost_management/proc/ownership_prompt_valid(obj/structure/overmap/dynamic/player_outpost/original_outpost, mob/user, turf/original_console_turf, datum/ui_state/prompt_state)
	if(QDELETED(src) || QDELETED(original_outpost) || QDELETED(user) || outpost != original_outpost)
		return FALSE
	if(get_turf(src) != original_console_turf || get_outpost_from_atom(src) != original_outpost || !original_outpost.is_owner(user))
		return FALSE
	return ui_status(user, prompt_state) == UI_INTERACTIVE

/**
 * Charges the claim treasury and puts out a galaxy-wide broadcast.
 */
/obj/machinery/computer/player_outpost_management/proc/buy_advert(mob/living/user)
	if(outpost.current_advert)
		say("A broadcast is already live.")
		return
	if(!COOLDOWN_FINISHED(outpost, advert_cooldown))
		say("Broadcast array recharging: [COOLDOWN_TIMELEFT(outpost, advert_cooldown) / 10] seconds.")
		return
	if(!outpost.can_spend(user))
		say("Treasury spending permission required.")
		return
	var/datum/bank_account/account = outpost.treasury
	if(!account)
		say("No treasury connected. Reconnect the outpost services.")
		return
	if(!account.has_money(OUTPOST_ADVERT_COST))
		say("Insufficient credits: broadcast costs [OUTPOST_ADVERT_COST] cr.")
		return
	if(!account.adjust_money(-OUTPOST_ADVERT_COST, "Paid to Colonial Registry by [user.ckey] for broadcast: [outpost.name]"))
		say("Transaction failed.")
		return
	COOLDOWN_START(outpost, advert_cooldown, OUTPOST_ADVERT_COOLDOWN)
	outpost.current_advert = new /datum/outpost_advert(outpost)
	say("Broadcast live galaxy-wide for [OUTPOST_ADVERT_DURATION / 600] minutes.")
	log_game("PLAYER OUTPOST: [key_name(user)] bought an advertisement for '[outpost.name]'")
