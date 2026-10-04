/**
 * Checkpoint testing tools for the Outpost Manipulator. Saves and rebuilds are free and skip
 * the captain rules; the rebuild itself is the normal staged reconstruction.
 */
/datum/outpost_manipulator/proc/checkpoint_admin_data(obj/structure/overmap/dynamic/player_outpost/home)
	var/list/saved = list()
	var/bay_free = !!home.available_ship_bay()
	for(var/datum/ship_checkpoint/snapshot as anything in home.checkpoints)
		saved += list(list(
			"ref" = REF(snapshot),
			"name" = snapshot.ship_name,
			"owner" = snapshot.captain_ckey,
			"size" = "[snapshot.width] x [snapshot.height]",
			"original" = checkpoint_original_text(snapshot),
			"rebuild_denial" = snapshot.busy ? "Already being rebuilt." : (bay_free ? null : "The ship bay is occupied or reserved."),
		))
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
		"checkpoints" = saved,
		"rebuilds" = jobs,
	)

/datum/outpost_manipulator/proc/checkpoint_original_text(datum/ship_checkpoint/snapshot)
	var/obj/structure/overmap/ship/original = snapshot.source_ship?.resolve()
	if(!original || QDELETED(original.shuttle))
		return "Lost"
	if(original.abandoned)
		return "Abandoned"
	if(original.docked == snapshot.outpost)
		return "Docked here"
	return "In service"

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
		if("checkpoint_save")
			prompt_free_checkpoint(home, user)
			return
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
		if("checkpoint_rebuild", "checkpoint_delete")
			var/datum/ship_checkpoint/snapshot = locate(params["ref"]) in home.checkpoints
			if(!snapshot)
				error = "That checkpoint is no longer available."
				return
			if(action == "checkpoint_rebuild")
				admin_rebuild(home, user, snapshot)
				return
			if(snapshot.busy)
				error = "Stop its reconstruction first."
				return
			if(!confirm(home, user, "Delete [snapshot.captain_ckey]'s checkpoint of [snapshot.ship_name]?") || QDELETED(snapshot) || snapshot.busy)
				return
			record(user, home, "delete [snapshot.captain_ckey]'s checkpoint of [snapshot.ship_name]")
			qdel(snapshot)
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
					if(!confirm(home, user, "Stop building [job.ship_name]? Placed pieces are removed. A checkpoint or payment already used by this build is not returned.") || QDELETED(job))
						return
					record(user, home, "stop the construction of [job.ship_name]")
					job.abort("Stopped by an administrator.")

/datum/outpost_manipulator/proc/prompt_free_checkpoint(obj/structure/overmap/dynamic/player_outpost/home, mob/user)
	if(!home.ship_bay_installed)
		error = "Install the ship bay first."
		return
	var/list/ships = list()
	var/obj/structure/overmap/ship/docked = docked_bay_ship(home)
	if(docked)
		ships["[docked.name] (in the ship bay)"] = docked
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(ship == docked || QDELETED(ship) || QDELETED(ship.shuttle) || !istype(ship.shuttle, /obj/docking_port/mobile/voidcrew))
			continue
		var/label = "[ship.name] ([ship.docked ? "at [ship.docked.name]" : "in flight"])"
		var/suffix = 1
		while(ships[label])
			label = "[ship.name] ([ship.docked ? "at [ship.docked.name]" : "in flight"]) #[++suffix]"
		ships[label] = ship
	if(!length(ships))
		error = "No ship has a hull to save."
		return
	var/ship_choice = tgui_input_list(user, "Ship to save", "Free Checkpoint", ships)
	if(!valid_selection(home, user) || !ship_choice)
		return
	var/obj/structure/overmap/ship/ship = ships[ship_choice]
	var/list/owners = list("You ([user.ckey])" = user.ckey)
	var/captain_ckey = ship_captain_ckey(ship)
	if(captain_ckey && captain_ckey != user.ckey)
		owners["Its captain ([captain_ckey])"] = captain_ckey
	owners["Another player..."] = "pick"
	var/owner_choice = tgui_input_list(user, "Owner. Only the owner can rebuild it at the console, and they receive the rebuilt ship.", "Free Checkpoint", owners)
	if(!valid_selection(home, user) || !owner_choice)
		return
	var/owner_ckey = owners[owner_choice]
	if(owner_ckey == "pick")
		var/mob/living/picked = voidcrew_admin_pick_player(user.client, "Checkpoint Owner")
		if(!valid_selection(home, user) || !picked?.ckey)
			return
		owner_ckey = picked.ckey
	save_free_checkpoint(home, user, ship, owner_ckey)

/// The player save rules that still matter without fees or a captain.
/datum/outpost_manipulator/proc/free_checkpoint_denial(obj/structure/overmap/dynamic/player_outpost/home, obj/structure/overmap/ship/ship, owner_ckey)
	if(!home.ship_bay_installed)
		return "Install the ship bay first."
	if(QDELETED(ship) || QDELETED(ship.shuttle))
		return "That ship no longer has a hull."
	if(ship.retired_by_checkpoint)
		return "That hull was already replaced by a rebuild."
	if(ship.checkpoint_rebuilding)
		return "That ship's checkpoint is being rebuilt."
	var/datum/ship_checkpoint/previous = home.checkpoint_for_ckey(owner_ckey)
	if(previous?.busy)
		return "[owner_ckey]'s checkpoint here is being rebuilt."
	var/datum/ship_checkpoint/linked = ship.checkpoint_ref?.resolve()
	if(linked && linked != previous)
		return "That ship already has a checkpoint owned by [linked.captain_ckey]. Delete it first."
	if(!previous && length(home.checkpoints) >= OUTPOST_MAX_CHECKPOINTS)
		return "This outpost's checkpoint storage is full."
	return null

/// Saves ship as owner_ckey's checkpoint here, replacing their previous one. No fee.
/datum/outpost_manipulator/proc/save_free_checkpoint(obj/structure/overmap/dynamic/player_outpost/home, mob/user, obj/structure/overmap/ship/ship, owner_ckey)
	error = free_checkpoint_denial(home, ship, owner_ckey)
	if(error)
		return null
	var/datum/ship_checkpoint/snapshot = new
	var/denial = snapshot.capture_hull(ship, owner_ckey)
	// Reading the hull yields; check everything again before replacing anything.
	if(!denial && !valid_selection(home, user))
		denial = "The outpost changed while the hull was being read."
	denial ||= free_checkpoint_denial(home, ship, owner_ckey)
	if(denial)
		qdel(snapshot)
		if(!QDELETED(src))
			error = denial
		return null
	var/datum/ship_checkpoint/previous = home.checkpoint_for_ckey(owner_ckey)
	if(previous)
		qdel(previous)
	snapshot.outpost = home
	home.checkpoints += snapshot
	ship.checkpoint_ref = WEAKREF(snapshot)
	record(user, home, "save a free checkpoint of [ship.name] for [owner_ckey]")
	return snapshot

/**
 * Starts the staged reconstruction without the captain rule. A lost or abandoned original is
 * retired as usual; one still in service is left alone and the new hull is an extra copy.
 */
/datum/outpost_manipulator/proc/admin_rebuild(obj/structure/overmap/dynamic/player_outpost/home, mob/user, datum/ship_checkpoint/snapshot)
	if(QDELETED(snapshot) || snapshot.outpost != home || !(snapshot in home.checkpoints))
		error = "That checkpoint is no longer available."
		return FALSE
	if(snapshot.busy)
		error = "That checkpoint is already being rebuilt."
		return FALSE
	if(!home.available_ship_bay())
		error = "The ship bay is occupied or reserved."
		return FALSE
	var/obj/structure/overmap/ship/original = snapshot.source_ship?.resolve()
	if(original?.retired_by_checkpoint)
		error = "That checkpoint's hull was already replaced."
		return FALSE
	var/in_service = original && !QDELETED(original.shuttle) && !original.abandoned
	var/ship_name = snapshot.ship_name
	var/owner_ckey = snapshot.captain_ckey
	var/datum/checkpoint_construction/job = new(null, snapshot, user, FALSE, in_service)
	if(!job.bay)
		error = job.error || "The ship bay is occupied or reserved."
		qdel(job)
		return FALSE
	if(!job.prepare())
		if(!QDELETED(src))
			error = job.error || "The rebuild could not start. The checkpoint is still available."
		return FALSE
	record(user, home, "start a free rebuild of [ship_name] for [owner_ckey][in_service ? " as a copy; the original stays in service" : ""]")
	return TRUE

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

/// One click: save the docked ship for its captain (or you), delete it, and rebuild it.
/datum/outpost_manipulator/proc/rebuild_docked_ship(obj/structure/overmap/dynamic/player_outpost/home, mob/user)
	var/datum/outpost_berth/ship_bay/bay = LAZYACCESS(home.bay_berths, 1)
	if(!bay?.is_ship_present())
		error = "No ship is docked in the ship bay."
		return FALSE
	var/obj/structure/overmap/ship/ship = bay.ship
	var/owner_ckey = ship_captain_ckey(ship) || user.ckey
	if(!confirm(home, user, "Save [ship.name] as a free checkpoint for [owner_ckey], delete the docked hull (living people aboard move to the bay elevator), then rebuild it with the drones?"))
		return FALSE
	if(bay.ship != ship || !bay.is_ship_present())
		error = "The docked ship changed. Try again."
		return FALSE
	var/datum/ship_checkpoint/snapshot = save_free_checkpoint(home, user, ship, owner_ckey)
	if(!snapshot || !remove_docked_ship(home, user, bay, ship))
		return FALSE
	return admin_rebuild(home, user, snapshot)

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
