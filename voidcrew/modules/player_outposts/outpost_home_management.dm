/obj/machinery/computer/player_outpost_management/proc/home_service_data(mob/living/user)
	outpost.ensure_home_services()
	var/list/data = list(
		"can_manage" = outpost.can_manage(user),
		"can_spend" = outpost.can_spend(user),
		"balance" = outpost.treasury.account_balance,
		"treasury_name" = outpost.treasury.account_holder,
		"personal_account" = user.get_idcard(TRUE)?.registered_account?.account_holder,
		"ledger" = outpost.treasury.transaction_history,
		"cargo_state" = outpost.freight.state,
		"cargo_status" = outpost.freight.availability_error() || outpost.freight.last_error || "Freight receiver ready; deliveries arrive by elevator",
		"cargo_history" = outpost.freight.transaction_history,
		"cargo_orders" = length(outpost.cargo_cart),
		"resident_mode" = outpost.resident_mode,
		"resident_limit" = outpost.resident_limit,
		"resident_active" = outpost.active_resident_count(),
		"arrival_available" = !!outpost.available_resident_pod(),
		"resident_invites" = outpost.invited_residents.Copy(),
		"resident_blocked" = outpost.blocked_residents.Copy(),
	)
	var/list/people = list()
	for(var/datum/mind/member as anything in outpost.residents)
		people += list(list("ref" = REF(member), "name" = member.name, "active" = !!member.current?.client && member.current.stat != DEAD, "steward" = (member in outpost.stewards), "treasurer" = (member in outpost.treasurers)))
	data["residents"] = people
	var/list/pairs = list()
	for(var/datum/outpost_research_pair/pair as anything in outpost.research_pairs)
		pairs += list(list("ref" = REF(pair), "name" = pair.label, "status" = pair.unavailable_reason() || pair.status, "last_success" = pair.last_success))
	data["research_pairs"] = pairs
	return data

/obj/machinery/computer/player_outpost_management/proc/home_service_action(action, list/params, mob/living/user)
	if(!(action in list("deposit", "withdraw", "open_cargo", "resident_mode", "resident_password", "resident_limit", "invite_resident", "block_resident", "unblock_resident", "reset_resident_access", "add_resident", "remove_resident", "delegate", "pair_research", "revoke_pair")))
		return FALSE
	if(action == "deposit" || action == "withdraw")
		var/amount = isnum(params["amount"]) ? params["amount"] : text2num(params["amount"])
		var/success = action == "deposit" ? outpost.deposit_from(user, amount) : outpost.withdraw_to(user, amount)
		if(!success)
			say("Transfer refused: check authority, ID account, whole credit amount and available funds.")
		return TRUE
	if(action == "open_cargo")
		for(var/obj/machinery/computer/voidcrew_cargo/console as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/computer/voidcrew_cargo))
			if(get_outpost_from_atom(console) != outpost)
				continue
			to_chat(user, span_notice("Use [console] at [get_area(console)]. Deliveries arrive at Freight Receiving by elevator."))
			return TRUE
		say("No cargo console. Build one in the habitat to order supplies.")
		return TRUE
	if(!outpost.can_manage(user))
		say("Outpost management permission required.")
		return TRUE
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
			if(istype(candidate) && candidate.mind && candidate.ckey && get_outpost_from_atom(candidate) == outpost)
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
			else if(outpost.is_owner(user))
				var/list/permissions = params["role"] == "steward" ? outpost.stewards : outpost.treasurers
				if(member in permissions)
					permissions -= member
				else
					permissions |= member
		if("pair_research")
			INVOKE_ASYNC(src, PROC_REF(prompt_research_pair), user)
		if("revoke_pair")
			var/datum/outpost_research_pair/pair = locate(params["ref"]) in outpost.research_pairs
			if(pair)
				outpost.research_pairs -= pair
				qdel(pair)
	return TRUE

/obj/machinery/computer/player_outpost_management/proc/prompt_research_pair(mob/living/user)
	var/list/local_servers = list()
	var/list/remote_servers = list()
	for(var/obj/machinery/rnd/server/ship/server as anything in GLOB.ship_research_servers)
		if(!server.source_code_hdd)
			continue
		if(get_outpost_from_atom(server) == outpost)
			local_servers[server.source_code_hdd.name] = server
		var/obj/structure/overmap/ship/ship = astype(get_service_site(server))
		if(ship?.docked == outpost)
			remote_servers["[ship.name]: [server.source_code_hdd.name]"] = server
	if(!length(local_servers) || !length(remote_servers))
		say("Pairing requires a local server with a disk and a ship docked with its own server and disk.")
		return
	var/obj/machinery/rnd/server/ship/local_server = local_servers[tgui_input_list(user, "Select the outpost's physical server disk.", "Research Pairing", local_servers)]
	var/obj/machinery/rnd/server/ship/remote_server = remote_servers[tgui_input_list(user, "Select the docked ship's physical server disk. Its captain must approve at that server.", "Research Pairing", remote_servers)]
	if(QDELETED(src) || !user.Adjacent(src) || get_outpost_from_atom(src) != outpost || QDELETED(local_server) || QDELETED(remote_server))
		return
	if(!outpost.propose_research_pair(user, local_server, remote_server))
		say("Pairing refused: recheck authority, docking, disks and existing pairings.")
