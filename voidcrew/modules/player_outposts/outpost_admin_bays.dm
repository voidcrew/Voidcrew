/// Administrative bay operations keep the normal bay zone and permission cleanup.
/datum/outpost_manipulator/proc/ship_bay_data(obj/structure/overmap/dynamic/player_outpost/home)
	var/list/slots = list()
	for(var/number in 1 to length(home.bay_berths))
		var/datum/outpost_berth/ship_bay/bay = home.bay_berths[number]
		if(!bay)
			slots += list(list("number" = number, "ref" = null, "status" = "Available"))
			continue
		bay.reconcile_silo()
		var/status = bay.status_text()
		var/obj/machinery/ore_silo/silo = bay.console?.get_linked_silo()
		slots += list(list(
			"number" = number, "ref" = REF(bay), "ship" = bay.ship?.name,
			"status" = status, "can_jump" = !!length(bay.alcove_turfs),
			"silo" = silo && bay.console.can_link_silo(silo) ? silo.name : null,
			"requested" = !!bay.silo_requested_at, "approved" = !!bay.approved_silo,
			"owner_crew" = home.is_owner_crew_ship(bay.ship),
			"grant_denial" = bay_material_denial(home, bay),
			"can_remove_ship" = bay.is_ship_present(),
		))
	var/list/silos = list()
	for(var/obj/machinery/ore_silo/silo as anything in home.service_silos())
		var/area/location = get_area(silo)
		silos += list(list("ref" = REF(silo), "name" = "[silo.name] ([location.name], [silo.x], [silo.y])"))
	var/obj/machinery/ore_silo/selected_silo = home.ship_bay_silo()
	return list(
		"installed" = home.ship_bay_installed, "capacity" = OUTPOST_SHIP_BAY_SLOTS,
		"install_denial" = home.ship_bay_setup_denial(), "remove_denial" = bay_removal_denial(home),
		"slots" = slots, "silos" = silos, "silo" = selected_silo ? REF(selected_silo) : null,
		"saved_checkpoints" = length(home.checkpoints),
	)

/datum/outpost_manipulator/proc/bay_material_denial(obj/structure/overmap/dynamic/player_outpost/home, datum/outpost_berth/ship_bay/bay)
	if(!bay.is_ship_present() || QDELETED(bay.console))
		return "An operational bay and a fully docked ship are required."
	if(!home.founder_ckey)
		return "Assign an outpost owner before granting materials."
	if(home.is_owner_crew_ship(bay.ship))
		return "The owner's crew already has automatic access."
	if(!home.ship_bay_silo())
		return "Select an outpost silo first."
	return null

/// Never disable recovery or pull the bay out from under an active visit.
/datum/outpost_manipulator/proc/bay_removal_denial(obj/structure/overmap/dynamic/player_outpost/home)
	if(!home.ship_bay_installed)
		return "The ship bay is not installed."
	if(length(home.checkpoints))
		return "Saved checkpoints still depend on this bay."
	for(var/datum/outpost_berth/ship_bay/bay as anything in home.bay_berths)
		if(bay && !bay.is_available())
			return "Undock the ship and finish any checkpoint rebuild first."
	for(var/obj/structure/overmap/ship/ship as anything in home.pending_dock_variants)
		if(home.pending_dock_variants[ship] == OUTPOST_DOCK_VARIANT_BAY)
			return "Resolve pending ship-bay docking requests first."
	return null

/datum/outpost_manipulator/proc/manage_ship_bays(obj/structure/overmap/dynamic/player_outpost/home, mob/user, action, list/params)
	if(!valid_selection(home, user))
		return
	error = null
	switch(action)
		if("install_bays")
			error = home.enable_ship_bays()
			if(!error)
				record(user, home, "install one permanent ship bay without payment")
			return
		if("remove_bays")
			error = bay_removal_denial(home)
			if(error || !confirm(home, user, "Remove the ship-bay upgrade? No credits or materials will be refunded."))
				return
			if(!valid_selection(home, user))
				return
			error = bay_removal_denial(home)
			if(error)
				return
			home.ship_bay_installed = FALSE
			for(var/datum/outpost_berth/ship_bay/removing as anything in home.bay_berths.Copy())
				if(removing)
					qdel(removing)
			home.bay_berths.Cut()
			home.refresh_elevator_uis()
			record(user, home, "remove the empty ship-bay upgrade without refund")
			return
		if("bay_select_silo")
			var/obj/machinery/ore_silo/silo = locate(params["ref"]) in home.service_silos()
			if(!home.link_service_silo(silo))
				error = "That silo no longer belongs to this outpost."
				return
			record(user, home, "select service silo [silo] ([REF(silo)])")
			return
	var/datum/outpost_berth/ship_bay/bay = locate(params["ref"]) in home.bay_berths
	if(QDELETED(bay) || bay.outpost != home)
		error = "That bay visit is no longer available."
		return
	switch(action)
		if("bay_jump")
			if(length(bay.alcove_turfs))
				user.forceMove(bay.alcove_turfs[1])
			else
				error = "The bay is still being prepared."
		if("bay_vv")
			user.client.debug_variables(bay)
		if("bay_grant_materials")
			error = bay_material_denial(home, bay)
			if(error)
				return
			if(!bay.grant_silo(user))
				error = "The material link could not be established."
				return
			record(user, home, "grant outpost materials to Ship Bay [bay.bay_number] ([bay.ship.name])")
		if("bay_revoke_materials")
			bay.revoke_silo()
			record(user, home, "revoke outpost materials from Ship Bay [bay.bay_number]")
