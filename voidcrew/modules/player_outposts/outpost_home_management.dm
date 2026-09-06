/obj/machinery/computer/player_outpost_management/proc/home_service_data(mob/living/user)
	outpost.ensure_home_services()
	var/list/data = list(
		"can_manage" = outpost.can_manage(user),
		"can_spend" = outpost.can_spend(user),
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
	return data

/obj/machinery/computer/player_outpost_management/proc/home_service_action(action, list/params, mob/living/user)
	if(!(action in list("resident_mode", "resident_password", "resident_limit", "invite_resident", "block_resident", "unblock_resident", "reset_resident_access", "add_resident", "remove_resident", "delegate")))
		return FALSE
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
				if(member.current)
					remove_player_outpost_management(member.current, outpost)
			else if(outpost.is_owner(user))
				var/list/permissions = params["role"] == "steward" ? outpost.stewards : outpost.treasurers
				if(member in permissions)
					permissions -= member
				else
					permissions |= member
			if(action == "delegate" && params["role"] == "steward" && member.current)
				if(member in outpost.stewards)
					grant_player_outpost_management(member.current, outpost)
				else
					remove_player_outpost_management(member.current, outpost)
	return TRUE

/// Numbered choices keep identical disk/ship names selectable, even at the same location.
/obj/structure/overmap/dynamic/player_outpost/proc/research_pair_server_options(remote = FALSE)
	var/list/options = list()
	for(var/obj/machinery/rnd/server/ship/server as anything in GLOB.ship_research_servers)
		if(!server.source_code_hdd || server.source_code_hdd.loc != server)
			continue
		var/obj/structure/overmap/ship/ship = astype(get_service_site(server))
		if(remote ? (!ship || ship.docked != src) : get_outpost_from_atom(server) != src)
			continue
		var/turf/location = get_turf(server)
		var/disk_label = "[server.source_code_hdd.name] at [get_area(server)] ([location.x], [location.y], [location.z])"
		options["[length(options) + 1]. [remote ? "[ship.name]: " : ""][disk_label]"] = server
	return options
