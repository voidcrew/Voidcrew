/**
 * A claim-bound management action. The physical console remains a launcher for
 * rebuild compatibility, while the action is the owner's normal entry point.
 */

/datum/asset/simple/outpost_management_plate
	assets = list(
		"outpost_management_plate.png" = 'voidcrew/modules/cyberware/icons/chrome_cradle_plate.png',
	)

/datum/action/innate/player_outpost_management
	name = "Outpost Management"
	desc = "Open the registered outpost management panel."
	button_icon = 'icons/hud/actions.dmi'
	button_icon_state = "round_end"
	check_flags = AB_CHECK_CONSCIOUS
	var/obj/structure/overmap/dynamic/player_outpost/managed_outpost
	var/datum/player_outpost_management_ui/panel

/datum/action/innate/player_outpost_management/New(mob/living/target, obj/structure/overmap/dynamic/player_outpost/outpost)
	. = ..(target?.mind)
	managed_outpost = outpost

/datum/action/innate/player_outpost_management/Destroy()
	managed_outpost = null
	QDEL_NULL(panel)
	return ..()

/datum/action/innate/player_outpost_management/update_button_name(atom/movable/screen/movable/action_button/button, force = FALSE)
	name = QDELETED(managed_outpost) ? initial(name) : "Outpost Management ([managed_outpost.name])"
	return ..()

/datum/action/innate/player_outpost_management/Activate()
	if(QDELETED(managed_outpost) || !managed_outpost.can_manage(owner))
		to_chat(owner, span_warning("You no longer hold management authorization for this outpost."))
		qdel(src)
		return
	if(!panel)
		panel = new(managed_outpost, owner)
	panel.manager = owner
	panel.ui_interact(owner)

/proc/grant_player_outpost_management(mob/living/user, obj/structure/overmap/dynamic/player_outpost/outpost)
	if(!user || QDELETED(outpost) || !outpost.can_manage(user))
		return null
	for(var/datum/action/innate/player_outpost_management/existing in user.actions)
		if(existing.managed_outpost == outpost)
			existing.build_all_button_icons(UPDATE_BUTTON_NAME)
			return existing
	var/datum/action/innate/player_outpost_management/granted = new(user, outpost)
	granted.Grant(user)
	return granted

/proc/remove_player_outpost_management(mob/living/user, obj/structure/overmap/dynamic/player_outpost/outpost)
	if(!user || !outpost)
		return
	var/list/retiring = list()
	for(var/datum/action/innate/player_outpost_management/existing in user.actions)
		if(existing.managed_outpost == outpost)
			retiring += existing
	for(var/datum/action/innate/player_outpost_management/doomed as anything in retiring)
		qdel(doomed)

/proc/refresh_player_outpost_management(obj/structure/overmap/dynamic/player_outpost/outpost)
	if(QDELETED(outpost))
		return
	for(var/mob/living/user as anything in GLOB.mob_living_list)
		if(outpost.can_manage(user))
			grant_player_outpost_management(user, outpost)
		else
			remove_player_outpost_management(user, outpost)

/datum/player_outpost_management_ui
	var/obj/structure/overmap/dynamic/player_outpost/outpost
	var/mob/manager
	var/datum/weakref/console_ref
	var/turf/console_turf

/datum/player_outpost_management_ui/New(obj/structure/overmap/dynamic/player_outpost/target, mob/user, obj/machinery/computer/player_outpost_management/console)
	outpost = target
	manager = user
	if(console)
		console_ref = WEAKREF(console)
		console_turf = get_turf(console)

/datum/player_outpost_management_ui/Destroy()
	SStgui.close_uis(src)
	var/obj/machinery/computer/player_outpost_management/console = console_ref?.resolve()
	if(console)
		console.panels -= src
	console_ref = null
	console_turf = null
	outpost = null
	manager = null
	return ..()

/datum/player_outpost_management_ui/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OutpostManagement", outpost?.name || "Outpost Management")
		ui.open()

/datum/player_outpost_management_ui/ui_state(mob/user)
	return GLOB.always_state

/datum/player_outpost_management_ui/ui_host(mob/user)
	return console_ref ? console_ref.resolve() : manager

/datum/player_outpost_management_ui/ui_status(mob/user, datum/ui_state/state)
	if(QDELETED(outpost) || QDELETED(user) || user != manager)
		return UI_CLOSE
	if(console_ref)
		var/obj/machinery/computer/player_outpost_management/console = console_ref.resolve()
		if(!console || get_turf(console) != console_turf || get_outpost_from_atom(console) != outpost)
			return UI_CLOSE
		var/physical_status = console.ui_status(user, console.ui_state(user))
		return min(physical_status, isliving(user) && outpost.can_manage(user) ? UI_INTERACTIVE : UI_UPDATE)
	if(!isliving(user) || !outpost.can_manage(user))
		return UI_CLOSE
	return user.shared_ui_interaction(user)

/datum/player_outpost_management_ui/ui_close(mob/user)
	if(console_ref && !QDELETED(src))
		qdel(src)

/datum/player_outpost_management_ui/ui_assets(mob/user)
	return list(get_asset_datum(/datum/asset/simple/outpost_management_plate))

/datum/player_outpost_management_ui/ui_data(mob/user)
	var/list/data = list("linked" = !!outpost)
	if(QDELETED(outpost))
		return data
	outpost.prune_dock_requests()
	data["outpost_name"] = outpost.name
	data["founder_name"] = outpost.founder_name
	data["memo"] = outpost.memo
	data["is_owner"] = outpost.is_owner(user)
	data["has_owner"] = !!outpost.founder_ckey
	data["can_manage"] = outpost.can_manage(user)
	data["can_spend"] = outpost.can_spend(user)
	data["raidable"] = outpost.raidable
	data["dock_mode"] = outpost.dock_mode
	data["rename_cooldown"] = COOLDOWN_TIMELEFT(outpost, rename_cooldown) / 10
	data["advert_cost"] = OUTPOST_ADVERT_COST
	data["advert_cooldown"] = COOLDOWN_TIMELEFT(outpost, advert_cooldown) / 10
	data["advert_remaining"] = outpost.current_advert ? outpost.current_advert.get_remaining_seconds() : 0

	var/list/requests = list()
	for(var/obj/structure/overmap/ship/requester in outpost.pending_dock_requests)
		requests += list(list("name" = requester.name, "ref" = REF(requester)))
	data["dock_requests"] = requests
	var/list/approved = list()
	for(var/obj/structure/overmap/ship/ship in outpost.approved_ships)
		if(!QDELETED(ship))
			approved += list(list("name" = ship.name, "ref" = REF(ship)))
	data["approved_ships"] = approved
	var/list/banned = list()
	for(var/obj/structure/overmap/ship/banned_ship in outpost.banned_ships)
		if(!QDELETED(banned_ship))
			banned += list(list("name" = banned_ship.name, "ref" = REF(banned_ship)))
	data["banned_ships"] = banned
	data["builders"] = outpost.authorized_builder_ckeys.Copy()
	var/list/candidates = list()
	for(var/mob/living/candidate as anything in GLOB.mob_living_list)
		if(!outpost.is_management_candidate(candidate) || candidate.ckey == outpost.founder_ckey)
			continue
		candidates += list(list("name" = candidate.real_name, "ckey" = candidate.ckey, "ref" = REF(candidate), "can_receive_outpost" = !(candidate.ckey in GLOB.player_outpost_founder_ckeys), "is_resident" = candidate.mind in outpost.residents))
	data["candidates"] = candidates

	outpost.ensure_home_services()
	data["resident_mode"] = outpost.resident_mode
	data["resident_limit"] = outpost.resident_limit
	data["resident_active"] = outpost.active_resident_count()
	data["arrival_available"] = !!outpost.available_resident_pod()
	data["resident_invites"] = outpost.invited_residents.Copy()
	data["resident_blocked"] = outpost.blocked_residents.Copy()
	var/list/people = list()
	for(var/datum/mind/member as anything in outpost.residents)
		people += list(list("ref" = REF(member), "name" = member.name, "active" = !!member.current?.client && member.current.stat != DEAD, "steward" = (member in outpost.stewards), "treasurer" = (member in outpost.treasurers)))
	data["residents"] = people
	return data

/datum/player_outpost_management_ui/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/living/user = usr
	if(QDELETED(outpost) || !istype(user) || QDELETED(user) || ui.user != user || ui.src_object != src || ui_status(user, state) != UI_INTERACTIVE || !outpost.can_manage(user))
		return
	if(action in list("transfer", "abandon", "add_builder", "remove_builder") && !outpost.is_owner(user))
		return
	if(action in list("resident_mode", "resident_password", "resident_limit", "invite_resident", "block_resident", "unblock_resident", "reset_resident_access", "add_resident", "remove_resident", "delegate"))
		return service_action(action, params, user)
	. = TRUE
	switch(action)
		if("rename")
			var/new_name = trim(params["name"])
			if(length(new_name) && new_name != outpost.name && reject_bad_text(new_name, MAX_CHARTER_LEN))
				outpost.set_outpost_name(new_name, user)
		if("set_memo")
			outpost.set_memo(trim(copytext(sanitize(params["memo"]), 1, PLAYER_OUTPOST_MEMO_MAX_LEN)))
		if("buy_advert")
			buy_advert(user)
		if("set_dock_mode")
			var/new_mode = params["mode"]
			if(new_mode in list(OUTPOST_DOCK_MODE_OPEN, OUTPOST_DOCK_MODE_REQUEST, OUTPOST_DOCK_MODE_LOCKDOWN))
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
			var/obj/structure/overmap/ship/denied = locate(params["ref"]) in outpost.pending_dock_requests
			if(denied)
				outpost.deny_dock_request(denied)
		if("ban_ship")
			var/obj/structure/overmap/ship/target = locate(params["ref"]) in SSovermap.simulated_ships
			if(target)
				outpost.banned_ships[target] = TRUE
				outpost.approved_ships -= target
				if(target in outpost.pending_dock_requests)
					outpost.deny_dock_request(target)
		if("unban_ship")
			var/obj/structure/overmap/ship/unbanned = locate(params["ref"]) in outpost.banned_ships
			if(unbanned)
				outpost.banned_ships -= unbanned
		if("revoke_approval")
			var/obj/structure/overmap/ship/revoked = locate(params["ref"]) in outpost.approved_ships
			if(revoked)
				outpost.approved_ships -= revoked
		if("add_builder")
			var/mob/living/candidate = locate(params["ref"])
			if(outpost.is_management_candidate(candidate))
				outpost.authorized_builder_ckeys |= candidate.ckey
		if("remove_builder")
			outpost.authorized_builder_ckeys -= params["ckey"]
		if("transfer")
			var/obj/structure/overmap/dynamic/player_outpost/original_outpost = outpost
			var/mob/living/recipient = locate(params["ref"])
			if(!outpost.is_management_candidate(recipient))
				return
			var/datum/mind/original_recipient_mind = recipient.mind
			var/original_recipient_ckey = recipient.ckey
			if(!confirm_ownership_action(user, "Transfer ownership of [outpost.name] to [recipient.real_name]? This cannot be undone.", "Transfer Ownership", "Transfer"))
				return
			if(!ownership_prompt_valid(original_outpost, user, ui) || !original_outpost.is_management_candidate(recipient) || recipient.mind != original_recipient_mind || recipient.ckey != original_recipient_ckey)
				return
			if(!original_outpost.transfer_ownership(recipient, user))
				to_chat(user, span_warning("Transfer refused: the recipient already holds a claim this shift."))
		if("abandon")
			var/obj/structure/overmap/dynamic/player_outpost/original_outpost = outpost
			if(!confirm_ownership_action(user, "Abandon [outpost.name]? You will lose ownership for the rest of the shift and cannot found another outpost.", "Abandon Outpost", "Abandon"))
				return
			if(ownership_prompt_valid(original_outpost, user, ui))
				original_outpost.abandon(user)

/datum/player_outpost_management_ui/proc/confirm_ownership_action(mob/user, prompt_text, title, confirm_label)
	return tgui_alert(user, prompt_text, title, list(confirm_label, "Cancel")) == confirm_label

/datum/player_outpost_management_ui/proc/ownership_prompt_valid(obj/structure/overmap/dynamic/player_outpost/original_outpost, mob/user, datum/tgui/ui)
	return !QDELETED(src) && !QDELETED(original_outpost) && !QDELETED(user) && outpost == original_outpost \
		&& original_outpost.is_owner(user) && ui?.user == user && ui.src_object == src && ui_status(user, ui.state) == UI_INTERACTIVE

/datum/player_outpost_management_ui/proc/buy_advert(mob/living/user)
	if(outpost.current_advert || !COOLDOWN_FINISHED(outpost, advert_cooldown) || !outpost.can_spend(user))
		return
	var/datum/bank_account/account = outpost.treasury
	if(!account || !account.has_money(OUTPOST_ADVERT_COST) || !account.adjust_money(-OUTPOST_ADVERT_COST, "Paid to Colonial Registry by [user.ckey] for broadcast: [outpost.name]"))
		return
	COOLDOWN_START(outpost, advert_cooldown, OUTPOST_ADVERT_COOLDOWN)
	outpost.current_advert = new /datum/outpost_advert(outpost)
	log_game("PLAYER OUTPOST: [key_name(user)] bought an advertisement for '[outpost.name]'")

/datum/player_outpost_management_ui/proc/service_action(action, list/params, mob/living/user)
	switch(action)
		if("resident_mode")
			if(params["mode"] in list("open", "password", "approved", "closed"))
				outpost.resident_mode = params["mode"]
		if("resident_password")
			outpost.resident_password = copytext(trim(params["password"]), 1, 65)
			outpost.resident_access_revision++
			outpost.resident_clearance.Cut()
		if("resident_limit")
			var/amount = text2num(params["amount"])
			if(valid_cargo_order_quantity(amount, 12))
				outpost.resident_limit = amount
		if("reset_resident_access")
			outpost.resident_access_revision++
			outpost.resident_clearance.Cut()
			outpost.invited_residents.Cut()
		if("invite_resident", "block_resident", "unblock_resident")
			var/player_key = ckey(params["ckey"])
			if(!length(player_key) || player_key == outpost.founder_ckey)
				return TRUE
			if(action == "invite_resident")
				outpost.blocked_residents -= player_key
				outpost.invited_residents[player_key] = TRUE
			else if(action == "block_resident")
				outpost.blocked_residents |= player_key
				outpost.invited_residents -= player_key
				outpost.resident_clearance -= player_key
			else
				outpost.blocked_residents -= player_key
		if("add_resident")
			var/mob/living/candidate = locate(params["ref"])
			if(outpost.is_management_candidate(candidate))
				outpost.residents |= candidate.mind
				outpost.invited_residents[candidate.ckey] = TRUE
				outpost.blocked_residents -= candidate.ckey
		if("remove_resident", "delegate")
			var/datum/mind/member = locate(params["ref"]) in outpost.residents
			if(!member)
				return TRUE
			if(action == "remove_resident")
				outpost.residents -= member
				outpost.stewards -= member
				outpost.treasurers -= member
				outpost.sync_management_lifecycle()
			else if(outpost.is_owner(user) && params["role"] in list("steward", "treasurer"))
				var/list/permissions = params["role"] == "steward" ? outpost.stewards : outpost.treasurers
				if(member in permissions)
					permissions -= member
				else
					permissions |= member
				outpost.sync_management_lifecycle()
	return TRUE

/// A new character can still own a round-long claim after their old mind is gone.
/mob/living/Login()
	. = ..()
	if(. && client)
		sync_player_outpost_management()

/mob/living/proc/sync_player_outpost_management()
	for(var/obj/structure/overmap/dynamic/player_outpost/home as anything in GLOB.player_outposts)
		if(home.is_owner(src) && mind)
			home.founder_mind = WEAKREF(mind)
			home.sync_management_lifecycle()
		else if(home.can_manage(src))
			grant_player_outpost_management(src, home)
		else
			remove_player_outpost_management(src, home)
