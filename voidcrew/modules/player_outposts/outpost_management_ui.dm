/**
 * A claim-bound management panel accessed through a console or installed Registry uplink.
 */

/datum/player_outpost_management_ui
	var/obj/structure/overmap/dynamic/player_outpost/outpost
	var/mob/manager
	var/datum/weakref/console_ref
	var/datum/weakref/uplink_ref
	var/turf/console_turf
	/// Why the last research invitation was refused, or null. The user is told in chat.
	var/research_error
	/// Why the last ship bay action was refused, or null. The user is told in chat.
	var/ship_bay_error

/datum/player_outpost_management_ui/New(obj/structure/overmap/dynamic/player_outpost/target, mob/user, obj/machinery/computer/player_outpost_management/console, obj/item/organ/cyberimp/cyberware/registry_uplink/uplink)
	outpost = target
	manager = user
	if(console)
		console_ref = WEAKREF(console)
		console_turf = get_turf(console)
	else if(uplink)
		uplink_ref = WEAKREF(uplink)
		uplink.management_panels += src

/datum/player_outpost_management_ui/Destroy()
	SStgui.close_uis(src)
	var/obj/machinery/computer/player_outpost_management/console = console_ref?.resolve()
	if(console)
		console.panels -= src
	var/obj/item/organ/cyberimp/cyberware/registry_uplink/uplink = uplink_ref?.resolve()
	if(uplink)
		uplink.management_panels -= src
	uplink_ref = null
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
	return console_ref ? console_ref.resolve() : uplink_ref?.resolve()

/datum/player_outpost_management_ui/ui_status(mob/user, datum/ui_state/state)
	if(QDELETED(outpost) || QDELETED(user) || user != manager)
		return UI_CLOSE
	if(uplink_ref)
		var/obj/item/organ/cyberimp/cyberware/registry_uplink/uplink = uplink_ref.resolve()
		if(!uplink?.can_manage_outpost(user, outpost))
			return UI_CLOSE
		return user.shared_ui_interaction(user)
	var/obj/machinery/computer/player_outpost_management/console = console_ref?.resolve()
	if(QDELETED(console) || get_turf(console) != console_turf || get_outpost_from_atom(console) != outpost)
		return UI_CLOSE
	var/physical_status = console.ui_status(user, console.ui_state(user))
	return min(physical_status, isliving(user) && (outpost.is_current_management_user(user) || outpost.is_current_treasury_user(user) || outpost.is_current_pricing_user(user) || outpost.can_claim(user) || (outpost.ship_bay_installed && user.ckey)) ? UI_INTERACTIVE : UI_UPDATE)

/datum/player_outpost_management_ui/ui_close(mob/user)
	if(!QDELETED(src))
		qdel(src)

/datum/player_outpost_management_ui/ui_assets(mob/user)
	return list(get_asset_datum(/datum/asset/simple/outpost_upgrade_previews))

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
	data["can_claim"] = !!console_ref && outpost.can_claim(user)
	var/can_manage = outpost.is_current_management_user(user)
	var/treasury_user = outpost.is_current_treasury_user(user)
	data["can_manage"] = can_manage
	data["can_spend"] = outpost.can_spend(user)
	data["can_set_prices"] = outpost.is_current_pricing_user(user)
	data["can_select_silo"] = treasury_user
	// Only the people who run the outpost see its money, roster and research (market_ui_data() trims the rest)
	data["treasury_balance"] = (can_manage || treasury_user) ? (outpost.treasury?.account_balance || 0) : 0
	var/obj/machinery/ore_silo/selected_silo = outpost.ship_bay_silo()
	data["service_silo"] = selected_silo ? REF(selected_silo) : null
	var/list/silos = list()
	for(var/obj/machinery/ore_silo/silo as anything in outpost.service_silos())
		var/area/silo_area = get_area(silo)
		silos += list(list("ref" = REF(silo), "name" = "[silo.name] ([silo_area.name])"))
	data["service_silos"] = silos
	data["dock_mode"] = outpost.dock_mode
	data["rename_cooldown"] = COOLDOWN_TIMELEFT(outpost, rename_cooldown) / 10
	data["advert_cost"] = OUTPOST_ADVERT_COST
	data["advert_cooldown"] = COOLDOWN_TIMELEFT(outpost, advert_cooldown) / 10
	data["advert_remaining"] = outpost.current_advert ? outpost.current_advert.get_remaining_seconds() : 0
	data["advert_denial"] = advert_denial(user)

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
	outpost.ensure_home_services()
	if(can_manage)
		manager_ui_data(user, data)
	else
		data["builders"] = list()
		data["candidates"] = list()
		data["resident_mode"] = null
		data["arrival_available"] = FALSE
		data["resident_invites"] = list()
		data["resident_blocked"] = list()
		data["residents"] = list()
		data["research_servers"] = list()
	data["ship_bay_installed"] = outpost.ship_bay_installed
	data["ship_bay_cost"] = OUTPOST_SHIP_BAY_COST
	data["ship_bay_denial"] = outpost.ship_bay_install_denial(user)
	ships_ui_data(user, data, can_manage)
	data["upgrades"] = upgrade_ui_data(user)
	data["upgrade_surveying"] = outpost.upgrade_surveying
	market_ui_data(user, data, can_manage)
	return data

/// The roster, construction grants and research servers: management only
/datum/player_outpost_management_ui/proc/manager_ui_data(mob/user, list/data)
	data["builders"] = outpost.authorized_builder_ckeys.Copy()
	var/list/candidates = list()
	for(var/mob/living/candidate as anything in GLOB.mob_living_list)
		if(!outpost.is_management_candidate(candidate) || candidate.ckey == outpost.founder_ckey)
			continue
		candidates += list(list("name" = candidate.real_name, "ckey" = candidate.ckey, "ref" = REF(candidate), "is_resident" = (candidate.mind in outpost.residents)))
	data["candidates"] = candidates

	data["resident_mode"] = outpost.resident_mode
	data["arrival_available"] = !!outpost.available_resident_pod()
	data["resident_invites"] = outpost.invited_residents.Copy()
	data["resident_blocked"] = outpost.blocked_residents.Copy()
	var/list/people = list()
	for(var/datum/mind/member as anything in outpost.residents)
		people += list(list("ref" = REF(member), "name" = member.name, "is_self" = (member == user.mind), "active" = !!member.current?.client && member.current.stat != DEAD, "steward" = (member in outpost.stewards), "treasurer" = (member in outpost.treasurers), "pricer" = (member in outpost.pricers)))
	data["residents"] = people
	var/list/servers = list()
	var/list/server_options = outpost.research_server_options()
	for(var/label in server_options)
		var/obj/machinery/rnd/server/ship/server = server_options[label]
		servers += list(list("ref" = REF(server), "name" = "[server.name] - [server.source_code_hdd.name]"))
	data["research_servers"] = servers

/**
 * The Ships tab. `ships_here`: one row per ship settled at this outpost (ship bay, hangar berth or
 * pad), with its research link for managers and, in the ship bay, its materials and eviction.
 * `research_away`: for managers, every research link no row shows. A link outlives the visit
 * (outpost_relay.dm), so a ship that left stays connected until someone disconnects it here.
 */
/datum/player_outpost_management_ui/proc/ships_ui_data(mob/user, list/data, can_manage)
	for(var/datum/outpost_berth/ship_bay/bay as anything in outpost.bay_berths)
		bay?.reconcile_silo()
	// Ship -> the link its row offers, a connected link before a pending one. The rest go in research_away.
	var/list/ship_links = list()
	var/list/away = list()
	if(can_manage)
		for(var/datum/outpost_research_link/link as anything in outpost.research_links.Copy())
			link.reconcile()
			if(QDELETED(link))
				continue
			var/obj/structure/overmap/ship/linked_ship = link.ship_ref.resolve()
			var/datum/outpost_research_link/shown = ship_links[linked_ship]
			if(shown && (shown.ship_approved || !link.ship_approved))
				away += link
				continue
			if(shown)
				away += shown
			ship_links[linked_ship] = link
	var/list/rows = list()
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(QDELETED(ship) || ship.docked != outpost || ship.state != OVERMAP_SHIP_IDLE)
			continue
		var/datum/outpost_research_link/link = ship_links[ship]
		ship_links -= ship
		var/list/row = list(
			"ref" = REF(ship),
			"name" = ship.name,
			"berth" = ship_berth_label(ship),
			"crew" = length(ship.ship_team?.members),
			"research" = research_link_state(link),
			"research_ref" = link ? REF(link) : null,
		)
		// Materials and eviction exist only for the ship bay
		var/datum/outpost_berth/ship_bay/bay = outpost.ship_bay_of(ship)
		if(bay)
			row["bay_ref"] = REF(bay)
			row["materials"] = bay.approved_silo ? "allowed" : (bay.silo_requested_at ? "requested" : "none")
			bay_eviction_ui_data(bay, user, row)
		rows += list(row)
	data["ships_here"] = rows
	for(var/linked_ship in ship_links)
		away += ship_links[linked_ship]
	var/list/away_rows = list()
	for(var/datum/outpost_research_link/link as anything in away)
		var/obj/structure/overmap/ship/linked_ship = link.ship_ref.resolve()
		away_rows += list(list("ref" = REF(link), "ship" = linked_ship?.name, "research" = research_link_state(link)))
	data["research_away"] = away_rows

/// "connected", "pending" or "none" for a ships_here or research_away row
/datum/player_outpost_management_ui/proc/research_link_state(datum/outpost_research_link/link)
	if(!link)
		return "none"
	return link.ship_approved ? "connected" : "pending"

/// The short berth label of a ships_here row
/datum/player_outpost_management_ui/proc/ship_berth_label(obj/structure/overmap/ship/ship)
	var/datum/outpost_berth/ship_bay/bay = outpost.ship_bay_of(ship)
	if(bay)
		return "Bay [bay.bay_number]"
	for(var/datum/outpost_berth/berth as anything in outpost.berths)
		if(berth?.ship == ship)
			return "Berth [berth.berth_number]"
	if(ship.dock_index)
		return "Pad [ship.dock_index]"
	return "Docked"

/datum/player_outpost_management_ui/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/living/user = usr
	if(QDELETED(outpost) || !istype(user) || QDELETED(user) || ui.user != user || ui.src_object != src || ui_status(user, state) != UI_INTERACTIVE)
		return
	if(action == "claim")
		if(console_ref && outpost.can_claim(user))
			outpost.transfer_ownership(user, user)
		return TRUE
	if(action == "select_service_silo")
		var/obj/machinery/ore_silo/silo = locate(params["ref"]) in outpost.service_silos()
		outpost.select_service_silo(user, silo)
		return TRUE
	// Pricing, room settings and bay eviction actions check their own permissions
	if(market_action(action, params, user))
		return TRUE
	if(!outpost.is_current_management_user(user))
		return
	if((action in list("transfer", "abandon", "add_builder", "remove_builder")) && !outpost.is_owner(user))
		return
	if(action in list("resident_mode", "resident_password", "invite_resident", "block_resident", "unblock_resident", "reset_resident_access", "add_resident", "remove_resident", "delegate"))
		return service_action(action, params, user)
	if(action in list("buy_upgrade", "cancel_upgrade", "open_upgrade_map", "refresh_upgrade_map", "close_upgrade_map", "place_upgrade"))
		return upgrade_action(action, params, user)
	. = TRUE
	switch(action)
		if("install_ship_bay")
			ship_bay_error = outpost.install_ship_bay(user)
			if(ship_bay_error)
				to_chat(user, span_warning(ship_bay_error))
		if("approve_bay_silo", "revoke_bay_silo")
			if(!outpost.can_spend(user))
				return
			var/datum/outpost_berth/ship_bay/bay = locate(params["ref"]) in outpost.bay_berths
			if(!bay)
				return
			if(action == "approve_bay_silo")
				ship_bay_error = bay.approve_silo(user) ? null : "Material request is no longer available."
				if(ship_bay_error)
					to_chat(user, span_warning(ship_bay_error))
			else
				bay.revoke_silo()
		if("invite_research")
			research_error = null
			var/obj/structure/overmap/ship/ship = locate(params["ship"]) in SSovermap.simulated_ships
			var/obj/machinery/rnd/server/ship/server = locate(params["server"]) in GLOB.ship_research_servers
			if(!ship || ship.docked != outpost || ship.state != OVERMAP_SHIP_IDLE)
				research_error = "Ship is no longer docked"
			else if(!server?.source_code_hdd || get_research_service_site(server) != outpost)
				research_error = "Research server unavailable"
			else if(!outpost.propose_research_link(user, server, ship, server.source_code_hdd))
				research_error = "Invitation refused"
			if(research_error)
				to_chat(user, span_warning("[research_error]."))
		if("revoke_research")
			research_error = null
			var/datum/outpost_research_link/link = locate(params["ref"]) in outpost.research_links
			if(link)
				qdel(link)
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
			if(!confirm_ownership_action(user, "Transfer [outpost.name] to [recipient.real_name]?", "Transfer Ownership", "Transfer"))
				return
			if(!ownership_prompt_valid(original_outpost, user, ui) || !original_outpost.is_management_candidate(recipient) || recipient.mind != original_recipient_mind || recipient.ckey != original_recipient_ckey)
				return
			if(!original_outpost.transfer_ownership(recipient, user))
				to_chat(user, span_warning("Ownership transfer failed."))
		if("abandon")
			var/obj/structure/overmap/dynamic/player_outpost/original_outpost = outpost
			if(!confirm_ownership_action(user, "Abandon [outpost.name]?", "Abandon Outpost", "Abandon"))
				return
			if(ownership_prompt_valid(original_outpost, user, ui))
				original_outpost.abandon(user)

/datum/player_outpost_management_ui/proc/confirm_ownership_action(mob/user, prompt_text, title, confirm_label)
	return tgui_alert(user, prompt_text, title, list(confirm_label, "Cancel")) == confirm_label

/datum/player_outpost_management_ui/proc/ownership_prompt_valid(obj/structure/overmap/dynamic/player_outpost/original_outpost, mob/user, datum/tgui/ui)
	return !QDELETED(src) && !QDELETED(original_outpost) && !QDELETED(user) && outpost == original_outpost \
		&& original_outpost.is_owner(user) && ui?.user == user && ui.src_object == src && ui_status(user, ui.state) == UI_INTERACTIVE

/datum/player_outpost_management_ui/proc/advert_denial(mob/living/user)
	if(outpost.current_advert)
		return "Broadcast already live"
	if(!outpost.can_spend(user))
		return "Not authorized"
	if(!COOLDOWN_FINISHED(outpost, advert_cooldown))
		return "Transmitter cooling down"
	if(!outpost.treasury)
		return "No bank link"
	if(!outpost.treasury.has_money(OUTPOST_ADVERT_COST))
		return "Insufficient outpost funds"
	return null

/datum/player_outpost_management_ui/proc/buy_advert(mob/living/user)
	var/denial = advert_denial(user)
	if(denial)
		to_chat(user, span_warning("Broadcast rejected: [denial]."))
		return FALSE
	var/datum/bank_account/account = outpost.treasury
	if(!account.adjust_money(-OUTPOST_ADVERT_COST, "Paid to Colonial Registry by [user.ckey] for broadcast: [outpost.name]"))
		to_chat(user, span_warning("Broadcast rejected: Payment declined."))
		return FALSE
	COOLDOWN_START(outpost, advert_cooldown, OUTPOST_ADVERT_COOLDOWN)
	outpost.current_advert = new /datum/outpost_advert(outpost)
	log_game("PLAYER OUTPOST: [key_name(user)] bought an advertisement for '[outpost.name]'")
	metric_outpost_advert(outpost, user, OUTPOST_ADVERT_COST)
	to_chat(user, span_notice("Broadcast live: [outpost.name]."))
	return TRUE

/datum/player_outpost_management_ui/proc/service_action(action, list/params, mob/living/user)
	switch(action)
		if("resident_mode")
			if(params["mode"] in list("open", "password", "approved", "closed"))
				outpost.resident_mode = params["mode"]
		if("resident_password")
			outpost.resident_password = copytext(trim(params["password"]), 1, 65)
			outpost.resident_access_revision++
			outpost.resident_clearance.Cut()
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
				// A blocked player's current character stops being a member at once
				outpost.strip_resident_by_ckey(player_key)
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
				if(member == user.mind)
					return TRUE
				outpost.residents -= member
				outpost.stewards -= member
				outpost.treasurers -= member
				outpost.pricers -= member
			else if(outpost.is_owner(user) && (params["role"] in list("steward", "treasurer", "pricer")))
				var/list/permissions = outpost.delegated_role_list(params["role"])
				if(member in permissions)
					permissions -= member
				else
					permissions |= member
	return TRUE
