/// Per-window admin controls; no player management permissions are granted to the viewer.
ADMIN_VERB(outpost_manipulator, R_ADMIN, "Outpost Manipulator", "Create and manage player outposts.", ADMIN_CATEGORY_SHUTTLE)
	var/datum/outpost_manipulator/panel = new(user.mob)
	panel.ui_interact(user.mob)

/datum/outpost_manipulator
	var/mob/admin
	var/obj/structure/overmap/dynamic/player_outpost/selected
	var/busy = FALSE
	var/error

/datum/outpost_manipulator/New(mob/user)
	admin = user

/datum/outpost_manipulator/Destroy()
	SStgui.close_uis(src)
	admin = null
	selected = null
	return ..()

/datum/outpost_manipulator/ui_close(mob/user)
	if(!QDELETED(src))
		qdel(src)

/datum/outpost_manipulator/ui_state(mob/user)
	return ADMIN_STATE(R_ADMIN)

/datum/outpost_manipulator/ui_host(mob/user)
	return admin

/datum/outpost_manipulator/ui_status(mob/user, datum/ui_state/state)
	return authorized(user) ? ..() : UI_CLOSE

/datum/outpost_manipulator/proc/authorized(mob/user)
	return !QDELETED(src) && user == admin && check_rights_for(user?.client, R_ADMIN)

/datum/outpost_manipulator/ui_interact(mob/user, datum/tgui/ui)
	if(!authorized(user))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OutpostManipulator")
		ui.open()

/datum/outpost_manipulator/ui_data(mob/user)
	var/list/data = list("busy" = busy, "error" = error, "outposts" = list(), "selected" = null)
	if(!authorized(user))
		return data
	var/list/outposts = data["outposts"]
	for(var/obj/structure/overmap/dynamic/player_outpost/home as anything in GLOB.player_outposts)
		if(QDELETED(home))
			continue
		var/list/coords = home.get_relative_overmap_coords()
		outposts += list(list("ref" = REF(home), "name" = home.name, "owner" = home.founder_ckey || "Unowned", "coords" = "[coords[1]], [coords[2]]", "loaded" = home.loaded))
	if(QDELETED(selected) || !(selected in GLOB.player_outposts))
		selected = null
		return data
	var/list/coords = selected.get_relative_overmap_coords()
	var/freight_state = "Away"
	switch(selected.freight?.state)
		if(CARGO_SHUTTLE_ARRIVING)
			freight_state = "Arriving"
		if(CARGO_SHUTTLE_DOCKED)
			freight_state = "Docked"
		if(CARGO_SHUTTLE_DEPARTING)
			freight_state = "Departing"
	var/list/people = list()
	for(var/datum/mind/member as anything in selected.residents)
		if(!QDELETED(member))
			people += list(list("ref" = REF(member), "name" = member.name, "is_self" = (member == user.mind), "steward" = (member in selected.stewards), "treasurer" = (member in selected.treasurers)))
	data["selected"] = list(
		"ref" = REF(selected), "name" = selected.name, "owner" = selected.founder_ckey || "Unowned",
		"coords" = "[coords[1]], [coords[2]]", "shell" = selected.shell_template?.name || "Unloaded",
		"balance" = selected.treasury?.account_balance || 0, "dock_mode" = selected.dock_mode,
		"resident_mode" = selected.resident_mode,
		"resident_active" = selected.active_resident_count(), "residents" = people,
		"freight_state" = freight_state,
		"freight_error" = selected.freight?.last_error, "research_connection" = selected.active_research_link?.status_text() || "Disconnected",
	)
	return data

/datum/outpost_manipulator/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || busy || !authorized(usr) || ui?.user != usr || ui.src_object != src)
		return
	error = null
	if(action == "select")
		selected = locate(params["ref"]) in GLOB.player_outposts
		return TRUE
	busy = TRUE
	if(action == "create")
		create_outpost(usr)
	else if(valid_selection(selected, usr))
		manage_outpost(selected, usr, action, params)
	if(!QDELETED(src))
		busy = FALSE
	return TRUE

/// Also called after every modal prompt, before using its result.
/datum/outpost_manipulator/proc/valid_selection(obj/structure/overmap/dynamic/player_outpost/home, mob/user)
	return authorized(user) && !QDELETED(home) && home == selected && (home in GLOB.player_outposts) && !home.loading

/datum/outpost_manipulator/proc/record(mob/user, obj/structure/overmap/dynamic/player_outpost/home, operation)
	log_admin("[key_name(user)] used Outpost Manipulator to [operation] on '[home.name]' ([REF(home)]).")
	message_admins("[key_name_admin(user)] used Outpost Manipulator to [operation] on '[home.name]'.")

/datum/outpost_manipulator/proc/confirm(obj/structure/overmap/dynamic/player_outpost/home, mob/user, prompt)
	return tgui_alert(user, prompt, home.name, list("Confirm", "Cancel")) == "Confirm" && valid_selection(home, user)

/datum/outpost_manipulator/proc/create_outpost(mob/user)
	var/list/templates = list("Compact Habitat" = /datum/map_template/player_outpost/small, "Waystation Frame" = /datum/map_template/player_outpost/medium)
	var/template_choice = tgui_input_list(user, "Habitat", "Create Outpost", templates)
	if(!authorized(user) || !template_choice)
		return
	var/outpost_name = tgui_input_text(user, "Name", "Create Outpost", "Independent Outpost", max_length = MAX_CHARTER_LEN)
	if(!authorized(user) || !outpost_name)
		return
	outpost_name = trim(outpost_name)
	if(!reject_bad_text(outpost_name, MAX_CHARTER_LEN))
		error = "Invalid outpost name."
		return
	var/list/locations = list("Random free sector" = "random")
	var/turf/current = get_turf(get_ship_from_atom(user) || get_outpost_from_atom(user) || user)
	if(istype(current, /turf/open/overmap))
		locations["Current sector"] = current
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(!QDELETED(ship) && istype(get_turf(ship), /turf/open/overmap))
			locations["[ship.name] ([REF(ship)])"] = get_turf(ship)
	var/location_choice = tgui_input_list(user, "Sector", "Create Outpost", locations)
	if(!authorized(user) || !location_choice)
		return
	var/list/owners = list("Unowned" = null)
	for(var/mob/living/candidate in GLOB.player_list)
		if(candidate.ckey && candidate.mind)
			owners["[candidate.real_name] ([candidate.ckey])"] = candidate
	var/owner_choice = tgui_input_list(user, "Owner", "Create Outpost", owners)
	if(!authorized(user) || !owner_choice)
		return
	var/turf/destination = locations[location_choice] == "random" ? SSovermap.get_unused_overmap_square() : locations[location_choice]
	var/mob/living/new_owner = owners[owner_choice]
	var/datum/mind/owner_mind = new_owner?.mind
	var/owner_key = new_owner?.ckey
	var/obj/structure/overmap/ship/founding_ship = get_crew_ship(new_owner)
	var/list/datum/mind/founding_crew = founding_ship?.ship_team?.members.Copy()
	var/obj/structure/overmap/dynamic/player_outpost/home = create_home(user, destination, templates[template_choice], outpost_name)
	if(!home)
		return
	// Map loading can yield while a selected player leaves or changes characters.
	if(!QDELETED(new_owner) && new_owner.ckey == owner_key && new_owner.mind == owner_mind && check_rights_for(user?.client, R_ADMIN))
		if(home.transfer_ownership(new_owner, user, admin_override = TRUE))
			home.register_founding_crew(founding_crew)
	if(!QDELETED(src))
		selected = home

/// Uses the same physical shell, finite bundle and freight receiver loader as a deed.
/datum/outpost_manipulator/proc/create_home(mob/user, turf/destination, shell_type, outpost_name)
	if(!authorized(user))
		return null
	if(!(shell_type in list(/datum/map_template/player_outpost/small, /datum/map_template/player_outpost/medium)) || !length(outpost_name) || !reject_bad_text(outpost_name, MAX_CHARTER_LEN))
		error = "Invalid habitat or name."
		return null
	if(!istype(destination, /turf/open/overmap) || SSovermap.jump_mode != BS_JUMP_IDLE)
		error = "No available overmap sector, or exodus is in progress."
		return null
	for(var/obj/structure/overmap/other in destination)
		if(!istype(other, /obj/structure/overmap/ship))
			error = "That sector is occupied by [other.name]."
			return null
	// Creating the object reserves the sector before the loader yields.
	var/obj/structure/overmap/dynamic/player_outpost/home = new(destination)
	home.name = outpost_name
	home.display_name = outpost_name
	home.shell_template = new shell_type
	home.founded_zone = SSovermap.get_zone_band_for_turf(destination)
	home.raidable = home.founded_zone != ZONE_GREEN
	home.resident_mode = "closed"
	if(!home.load_level())
		qdel(home)
		if(!QDELETED(src))
			error = "Habitat loading failed; no claim was created."
		return null
	home.sync_close_overmap_objects()
	record(user, home, "create [home.shell_template.name]")
	return home

/datum/outpost_manipulator/proc/manage_outpost(obj/structure/overmap/dynamic/player_outpost/home, mob/user, action, list/params)
	if(!valid_selection(home, user))
		return
	switch(action)
		if("jump", "jump_overmap")
			var/turf/destination = action == "jump" ? home.arrival_turf : get_turf(home)
			if(destination)
				user.forceMove(destination)
			else
				error = "No arrival point is available."
			return
		if("vv")
			user.client.debug_variables(home)
			return
		if("rename")
			var/new_name = tgui_input_text(user, "Name", home.name, home.name, max_length = MAX_CHARTER_LEN)
			if(!valid_selection(home, user) || !new_name || !reject_bad_text(trim(new_name), MAX_CHARTER_LEN))
				return
			COOLDOWN_RESET(home, rename_cooldown)
			home.set_outpost_name(trim(new_name), user)
			home.sync_management_lifecycle()
		if("owner")
			var/mob/living/recipient = voidcrew_admin_pick_player(user.client, "Assign Outpost Owner")
			if(!valid_selection(home, user) || !recipient?.ckey || !recipient.mind)
				return
			if(!home.transfer_ownership(recipient, user, admin_override = TRUE))
				error = "Ownership assignment failed."
				return
		if("abandon")
			if(!confirm(home, user, "Clear ownership and delegated permissions for [home.name]?"))
				return
			home.abandon(user, admin_override = TRUE)
		if("balance")
			var/amount = tgui_input_number(user, "Credit adjustment (negative to remove)", home.name, 0, max_value = 10000000, min_value = -10000000)
			if(!valid_selection(home, user) || isnull(amount) || !amount || amount != round(amount))
				return
			home.ensure_home_services()
			if(!home.treasury.adjust_money(amount, "Admin adjustment by [user.ckey]"))
				error = "The treasury cannot cover that deduction."
				return
			record(user, home, "adjust treasury by [amount] cr")
			return
		if("dock_mode")
			if(!(params["mode"] in list(OUTPOST_DOCK_MODE_OPEN, OUTPOST_DOCK_MODE_REQUEST, OUTPOST_DOCK_MODE_LOCKDOWN)))
				return
			home.dock_mode = params["mode"]
			if(home.dock_mode == OUTPOST_DOCK_MODE_LOCKDOWN)
				home.approved_ships.Cut()
				for(var/obj/structure/overmap/ship/requester in home.pending_dock_requests.Copy())
					home.deny_dock_request(requester)
		if("resident_mode")
			if(!(params["mode"] in list("open", "password", "approved", "closed")))
				return
			home.resident_mode = params["mode"]
		if("resident_password")
			var/password = tgui_input_text(user, "Resident password", home.name, max_length = 64)
			if(!valid_selection(home, user) || isnull(password))
				return
			home.resident_password = trim(password)
			home.resident_access_revision++
			home.resident_clearance.Cut()
		if("add_resident")
			var/mob/living/resident = voidcrew_admin_pick_player(user.client, "Add Outpost Resident")
			if(!valid_selection(home, user) || !resident?.ckey || !resident.mind)
				return
			home.residents |= resident.mind
			home.invited_residents[resident.ckey] = TRUE
			home.blocked_residents -= resident.ckey
		if("remove_resident", "delegate")
			var/datum/mind/resident = locate(params["ref"]) in home.residents
			if(!resident)
				return
			if(action == "remove_resident")
				if(resident == user.mind)
					return
				home.residents -= resident
				home.stewards -= resident
				home.treasurers -= resident
			else
				if(!(params["role"] in list("steward", "treasurer")))
					return
				var/list/roles = params["role"] == "steward" ? home.stewards : home.treasurers
				if(resident in roles)
					roles -= resident
				else
					roles |= resident
			home.sync_management_lifecycle()
		if("reset_resident_access")
			if(!confirm(home, user, "Clear remembered return access and invitations?"))
				return
			home.resident_access_revision++
			home.resident_clearance.Cut()
			home.invited_residents.Cut()
		if("relink")
			home.ensure_home_services()
			for(var/obj/machinery/machine as anything in SSmachines.get_all_machines())
				if(get_outpost_from_atom(machine) != home)
					continue
				if(istype(machine, /obj/machinery/computer/bank_machine))
					var/obj/machinery/computer/bank_machine/bank = machine
					bank.resolve_outpost_bank()
				else if(istype(machine, /obj/machinery/computer/voidcrew_cargo))
					var/obj/machinery/computer/voidcrew_cargo/cargo = machine
					cargo.cargo_account()
				else if(istype(machine, /obj/machinery/cryopod))
					var/obj/machinery/cryopod/pod = machine
					pod.relink_to_ship()
			home.sync_management_lifecycle()
		if("revoke_research")
			if(!confirm(home, user, "Disconnect research relays? The outpost keeps its research."))
				return
			home.revoke_research_links()
		if("delete")
			if(!confirm(home, user, "Permanently delete this outpost and its contents?"))
				return
			error = deletion_denial(home)
			if(error)
				return
			record(user, home, "delete the outpost")
			qdel(home)
			selected = null
			return
		else
			return
	record(user, home, "[action][params["mode"] ? " ([params["mode"]])" : ""]")

/// Never tear a loaded ship, occupied habitat or unfinished map load out from under it.
/datum/outpost_manipulator/proc/deletion_denial(obj/structure/overmap/dynamic/player_outpost/home)
	if(home.loading || home.freight?.load_pending || home.freight?.busy || length(home.arrival_reservations))
		return "An arrival or map load is in progress."
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		// docked is assigned before warmup starts, so this includes approaches.
		if(ship.docked == home)
			return "Undock visiting ships and cancel their approaches first."
	for(var/mob/living/occupant as anything in GLOB.mob_living_list)
		if(get_outpost_from_atom(occupant) == home)
			return "Move living occupants out of the outpost first."
	return null
