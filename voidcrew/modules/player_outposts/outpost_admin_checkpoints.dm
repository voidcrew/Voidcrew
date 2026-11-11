/**
 * Ship construction testing tools for the Outpost Manipulator. Everything is free and skips the
 * captain rules; the builds themselves are the normal staged construction.
 */
/datum/outpost_manipulator/proc/checkpoint_admin_data(obj/structure/overmap/dynamic/player_outpost/home)
	var/list/jobs = list()
	for(var/datum/checkpoint_construction/job as anything in home.checkpoint_jobs)
		var/list/entry = job.rebuild_ui_data()
		entry["owner"] = job.captain_ckey
		entry["can_rush"] = !job.manual && (job.state == CHECKPOINT_BUILD_MARKING || (job.state == CHECKPOINT_BUILD_BUILDING && !job.rushed))
		jobs += list(entry)
	var/obj/structure/overmap/ship/docked = docked_bay_ship(home)
	return list(
		"enabled" = home.ship_bay_installed,
		"docked" = docked?.name,
		"rebuilds" = jobs,
	)

/datum/outpost_manipulator/proc/docked_bay_ship(obj/structure/overmap/dynamic/player_outpost/home)
	var/datum/outpost_berth/ship_bay/bay = LAZYACCESS(home.bay_berths, 1)
	return bay?.is_ship_present() ? bay.ship : null

/// The ship's captain by command, even while they are offline.
/datum/outpost_manipulator/proc/ship_captain_ckey(obj/structure/overmap/ship/ship)
	for(var/datum/mind/member as anything in ship?.ship_team?.members)
		var/member_ckey = ckey(member?.key)
		if(member_ckey && ship.is_ship_captain_mind(member))
			return member_ckey
	return null

/datum/outpost_manipulator/proc/manage_checkpoints(obj/structure/overmap/dynamic/player_outpost/home, mob/user, action, list/params)
	if(!valid_selection(home, user))
		return
	error = null
	switch(action)
		if("checkpoint_rebuild_docked")
			rebuild_docked_ship(home, user)
			return
		if("checkpoint_order_free")
			admin_free_order(home, user)
			return
		if("bay_remove_ship")
			var/datum/outpost_berth/ship_bay/bay = locate(params["ref"]) in home.bay_berths
			if(!bay?.is_ship_present())
				error = "No ship is docked in that bay."
				return
			var/obj/structure/overmap/ship/ship = bay.ship
			if(!confirm(home, user, "Delete [ship.name] and everything aboard? Living people aboard are moved to the bay elevator first."))
				return
			remove_docked_ship(home, user, bay, ship)
			return
		if("rebuild_rush", "rebuild_stop")
			var/datum/checkpoint_construction/job = locate(params["ref"]) in home.checkpoint_jobs
			if(!job)
				error = "That build is no longer running."
				return
			switch(action)
				if("rebuild_rush")
					if(job.rush())
						record(user, home, "rush the reconstruction of [job.ship_name]")
				if("rebuild_stop")
					if(!confirm(home, user, "Stop building [job.ship_name]? Placed pieces are removed. A saved ship or payment already used by this build is not returned.") || QDELETED(job))
						return
					record(user, home, "stop the construction of [job.ship_name]")
					job.abort("Stopped by an administrator.")

/// Deletes the hull docked in a bay the way the Shuttle Manipulator does. People aboard are
/// moved to the bay elevator first, and the pad gets its own hangar room back.
/datum/outpost_manipulator/proc/remove_docked_ship(obj/structure/overmap/dynamic/player_outpost/home, mob/user, datum/outpost_berth/ship_bay/bay, obj/structure/overmap/ship/expected)
	if(QDELETED(bay) || bay.outpost != home || !bay.is_ship_present() || bay.ship != expected)
		error = "The docked ship changed. Try again."
		return FALSE
	if(!length(bay.alcove_turfs))
		error = "The bay has no elevator alcove to move people to."
		return FALSE
	var/obj/structure/overmap/ship/ship = bay.ship
	var/obj/docking_port/mobile/voidcrew/port = ship.shuttle
	for(var/mob/living/person as anything in GLOB.mob_living_list)
		if(person.mind && ship.is_aboard(person))
			person.forceMove(pick(bay.alcove_turfs))
	var/list/underlying = port.underlying_areas_by_turf.Copy()
	var/ship_name = ship.name
	if(!port.admin_delete_shuttle())
		error = "The hull could not be deleted."
		return FALSE
	// Deletion gives the pad a new room of the dock's area type; put the bay's own back.
	var/list/area/replacements = list()
	for(var/turf/tile as anything in underlying)
		var/area/bay_room = underlying[tile]
		var/area/current = tile.loc
		if(QDELETED(bay_room) || current == bay_room)
			continue
		replacements |= current
		tile.change_area(current, bay_room)
	for(var/area/replacement as anything in replacements)
		if(!replacement.has_contained_turfs())
			qdel(replacement)
	// Some fittings drop parts as they are deleted: every duct leaves a stack of duct. The crew
	// were moved off first, so anything loose on the pad now is debris from the deletion.
	for(var/turf/tile as anything in underlying)
		for(var/obj/item/debris in tile)
			qdel(debris)
	bay.refresh_hangar_air()
	record(user, home, "delete [ship_name] from Ship Bay [bay.bay_number]")
	return TRUE

/**
 * One click: capture the docked ship for its captain (or you), delete it, and rebuild it straight
 * from the capture. The job owns the capture, so a build that fails after the delete loses the ship.
 */
/datum/outpost_manipulator/proc/rebuild_docked_ship(obj/structure/overmap/dynamic/player_outpost/home, mob/user)
	var/datum/outpost_berth/ship_bay/bay = LAZYACCESS(home.bay_berths, 1)
	if(!bay?.is_ship_present())
		error = "No ship is docked in the ship bay."
		return FALSE
	var/obj/structure/overmap/ship/ship = bay.ship
	var/owner_ckey = ship_captain_ckey(ship) || user.ckey
	if(!confirm(home, user, "Capture [ship.name] for [owner_ckey], delete the docked hull (living people aboard move to the bay elevator), then rebuild it with the drones? It comes back at default tier."))
		return FALSE
	if(bay.ship != ship || !bay.is_ship_present())
		error = "The docked ship changed. Try again."
		return FALSE
	if(ship.retired_by_checkpoint || ship.checkpoint_rebuilding)
		error = "That hull is being replaced already."
		return FALSE
	var/datum/ship_checkpoint/snapshot = new
	var/denial = snapshot.capture_hull(ship, owner_ckey)
	// Reading the hull yields; check everything again before deleting anything.
	if(!denial && (!valid_selection(home, user) || bay.ship != ship || !bay.is_ship_present()))
		denial = "The docked ship changed while the hull was being read."
	if(denial)
		qdel(snapshot)
		if(!QDELETED(src))
			error = denial
		return FALSE
	snapshot.outpost = home
	var/ship_name = snapshot.ship_name
	if(!remove_docked_ship(home, user, bay, ship))
		qdel(snapshot)
		return FALSE
	var/datum/checkpoint_construction/job = new(null, snapshot, user)
	if(!job.bay)
		error = job.error || "The ship bay is occupied or reserved."
		qdel(job)
		return FALSE
	if(!job.prepare())
		if(!QDELETED(src))
			error = job.error || "The rebuild could not start."
		return FALSE
	record(user, home, "start a free rebuild of [ship_name] for [owner_ckey]")
	return TRUE

/**
 * Starts a free shipyard order: pick a hull, and optionally its theme and modules, or take the
 * defaults. The admin is the buyer and receives the ship. The build is the normal staged one.
 */
/datum/outpost_manipulator/proc/admin_free_order(obj/structure/overmap/dynamic/player_outpost/home, mob/user)
	if(!home.ship_bay_installed)
		error = "Install the ship bay first."
		return FALSE
	if(!home.available_ship_bay())
		error = "The ship bay is occupied or reserved."
		return FALSE
	var/list/hulls = list()
	for(var/datum/map_template/shuttle/voidcrew/hull as anything in get_ship_order_hulls())
		hulls[hull.name] = hull
	var/hull_choice = tgui_input_list(user, "Hull", "Build Ship (Free)", hulls)
	if(!valid_selection(home, user) || !hull_choice)
		return FALSE
	var/datum/ship_order/order = new(hulls[hull_choice])
	var/list/themes = get_themes_for_ship(order.hull_type)
	if(length(themes) > 1)
		var/list/theme_names = list()
		for(var/theme_id in themes)
			var/datum/ship_theme/theme = themes[theme_id]
			theme_names["[theme.name][theme.is_default ? " (default)" : ""]"] = theme
		var/theme_choice = tgui_input_list(user, "Theme", "Build Ship (Free)", theme_names)
		if(!valid_selection(home, user) || !theme_choice)
			qdel(order)
			return FALSE
		order.set_theme(theme_names[theme_choice])
	var/list/slots = order.slot_ids()
	if(length(slots) && tgui_alert(user, "Modules", "Build Ship (Free)", list("Defaults", "Choose")) == "Choose")
		for(var/slot_key in slots)
			var/list/options = list()
			for(var/datum/ship_upgrade_module/module as anything in get_modules_for_ship_slot(order.hull_type, order.theme?.id, slot_key))
				options["[module.name][module.is_default ? " (default)" : ""]"] = module
			if(!length(options))
				continue
			var/module_choice = tgui_input_list(user, "Module for [slot_key]", "Build Ship (Free)", options)
			if(!valid_selection(home, user))
				qdel(order)
				return FALSE
			if(module_choice)
				order.upgrade_selections[slot_key] = options[module_choice]
	error = order.denial()
	if(error)
		qdel(order)
		return FALSE
	var/hull_name = order.hull.name
	var/theme_name = order.theme?.name
	var/datum/checkpoint_construction/order/job = new(null, home, order, user, null, null, FALSE, TRUE)
	if(!job.bay)
		error = "The ship bay is occupied or reserved."
		qdel(job)
		return FALSE
	if(!job.prepare())
		if(!QDELETED(src))
			error = job.error || "The build could not start."
		return FALSE
	record(user, home, "start a free build of a [hull_name][theme_name ? " ([theme_name])" : ""]")
	return TRUE
