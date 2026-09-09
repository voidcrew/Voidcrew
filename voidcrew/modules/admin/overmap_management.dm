ADMIN_VERB(overmap_management, R_ADMIN, "Overmap Management", "Manage overmap contacts, interiors and docking ports.", ADMIN_CATEGORY_SHUTTLE)
	var/datum/overmap_management/panel = new(user.mob)
	panel.ui_interact(user.mob)
	BLACKBOX_LOG_ADMIN_VERB("Overmap Management")

/// Each window owns only weak references; inspecting a contact must not hold up its deletion.
/datum/overmap_management
	var/datum/weakref/admin_ref
	var/datum/weakref/selected_ref
	var/datum/weakref/return_ref
	var/error
	var/notice
	var/spawning = FALSE
	var/spawn_serial = 0
	var/list/spawn_catalog

/datum/overmap_management/New(mob/user)
	admin_ref = WEAKREF(user)

/datum/overmap_management/Destroy()
	SStgui.close_uis(src)
	admin_ref = null
	selected_ref = null
	return_ref = null
	spawn_catalog = null
	return ..()

/datum/overmap_management/proc/select_contact(obj/structure/overmap/contact, obj/structure/overmap/return_to)
	var/obj/structure/overmap/previous = selected_ref?.resolve()
	if(previous)
		UnregisterSignal(previous, COMSIG_QDELETING)
	selected_ref = QDELETED(contact) ? null : WEAKREF(contact)
	return_ref = QDELETED(return_to) ? null : WEAKREF(return_to)
	if(!QDELETED(contact))
		RegisterSignal(contact, COMSIG_QDELETING, PROC_REF(selected_deleted))

/datum/overmap_management/proc/selected_deleted(obj/structure/overmap/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_QDELETING)
	notice = "[source.admin_name()] was deleted."
	select_contact(return_ref?.resolve())
	SStgui.update_uis(src)

/datum/overmap_management/proc/operation_finished(message, succeeded)
	if(QDELETED(src))
		return
	if(succeeded)
		notice = message
		error = null
	else
		error = message
		notice = null
	SStgui.update_uis(src)

/datum/overmap_management/proc/watch_load(obj/structure/overmap/contact)
	RegisterSignal(contact, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, PROC_REF(site_load_finished))

/datum/overmap_management/proc/site_load_finished(obj/structure/overmap/source, succeeded)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_VOIDCREW_SITE_LOAD_FINISHED)
	operation_finished(succeeded ? "Loaded the interior of [source.admin_name()]." : "Could not load [source.admin_name()]. Check available map space and mapping logs.", succeeded)

/datum/overmap_management/ui_state(mob/user)
	return ADMIN_STATE(R_ADMIN)

/datum/overmap_management/proc/authorized(mob/user)
	return !QDELETED(src) && user && admin_ref?.resolve() == user && check_rights_for(user.client, R_ADMIN)

/datum/overmap_management/ui_interact(mob/user, datum/tgui/ui)
	if(!authorized(user))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OvermapManagement")
		ui.open()

/datum/overmap_management/ui_close(mob/user)
	if(!QDELETED(src))
		qdel(src)

/datum/overmap_management/ui_data(mob/user)
	if(!authorized(user))
		return list()
	var/list/data = list(
		"objects" = list(),
		"selected" = null,
		"error" = error,
		"notice" = notice,
		"return_name" = return_ref?.resolve()?.admin_name(),
		"spawning" = spawning,
		"spawn_serial" = spawn_serial,
		"worldgen" = SSovermap.worldgen_label,
		"worldgen_seconds" = SSovermap.worldgen_owner ? round((world.time - SSovermap.worldgen_claimed_at) / 10) : 0,
		"queued_jobs" = SSovermap.worldgen_queue_length(),
	)
	for(var/obj/structure/overmap/contact as anything in GLOB.overmap_objects)
		if(QDELETED(contact))
			continue
		data["objects"] += list(list(
			"ref" = REF(contact),
			"name" = contact.admin_name(),
			"kind" = contact.admin_kind(),
			"coords" = contact.get_relative_overmap_coords(),
			"status" = contact.admin_status(),
		))
	var/obj/structure/overmap/selected = selected_ref?.resolve()
	if(selected)
		data["selected"] = contact_details(selected)
	return data

/datum/overmap_management/proc/contact_details(obj/structure/overmap/contact)
	var/datum/map_footprint/footprint = contact.get_interior_footprint()
	var/datum/map_zone/zone = contact.admin_mapzone()
	var/is_ship = istype(contact, /obj/structure/overmap/ship)
	var/has_interior = !!(zone || contact.is_loaded())
	if(is_ship)
		var/obj/structure/overmap/ship/ship = contact
		has_interior = !QDELETED(ship.shuttle)
	var/list/details = list(
		"ref" = REF(contact),
		"name" = contact.admin_name(),
		"type" = "[contact.type]",
		"kind" = contact.admin_kind(),
		"status" = contact.admin_status(),
		"coords" = contact.get_relative_overmap_coords(),
		"interior" = contact.is_loading() ? "Loading" : (has_interior ? "Loaded" : "Not loaded"),
		"footprint" = footprint?.describe(),
		"is_ship" = is_ship,
		"has_interior" = has_interior,
		"supports_interior" = istype(contact, /obj/structure/overmap/planet) || istype(contact, /obj/structure/overmap/space_ruin) || istype(contact, /obj/structure/overmap/event/meteor),
		"load_blocker" = contact.admin_load_blocker(),
		"unload_blocker" = contact.admin_unload_blocker(),
		"delete_blocker" = contact.admin_delete_blocker(),
		"busy" = !!contact.admin_operation || contact.is_loading() || contact.concerned || SSovermap.worldgen_owner == contact || !!SSovermap.worldgen_waiting_for(contact),
		"can_jump" = !!contact.admin_interior_turf(),
		"ports" = list(),
		"ships" = list(),
		"cleanup" = contact.admin_cleanup_details(),
		"unload_effect" = contact.admin_unload_effect(),
	)
	var/list/ports = contact.admin_ports()
	for(var/label in ports)
		var/obj/docking_port/port = ports[label]
		if(QDELETED(port))
			continue
		var/obj/docking_port/occupant = port.get_docked()
		var/port_status = "Available"
		if(occupant)
			port_status = "Occupied: [occupant.name]"
		else if(label == "Landing pad 1" || label == "Landing pad 2")
			var/obj/structure/overmap/dynamic/site = contact // Shared berth fields on site types.
			if(label == "Landing pad 1" ? site.first_dock_taken : site.second_dock_taken)
				port_status = "Reserved for a ship"
		if(istype(port, /obj/docking_port/mobile))
			port_status = occupant ? "Docked at [occupant.name]" : "In flight"
		details["ports"] += list(list(
			"ref" = REF(port), "label" = label, "name" = port.name,
			"id" = port.shuttle_id, "coords" = list(port.x, port.y, port.z),
			"direction" = dir2text(port.dir), "width" = port.width, "height" = port.height,
			"status" = port_status,
		))
	for(var/obj/structure/overmap/ship/ship as anything in contact.get_docking_ships())
		details["ships"] += list(list("ref" = REF(ship), "name" = ship.admin_name(), "status" = ship.presence_at(contact)))
	return details

/datum/overmap_management/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !authorized(ui.user))
		return
	error = null
	notice = null
	if(action == "dismiss")
		return TRUE
	if(action == "back")
		select_contact(return_ref?.resolve())
		return TRUE
	if(action == "spawn")
		if(!spawning)
			INVOKE_ASYNC(src, PROC_REF(spawn_contact), ui.user, params["id"], params["location"], params["ref"])
		return TRUE
	if(action == "outposts")
		var/datum/outpost_manipulator/panel = new(ui.user)
		panel.ui_interact(ui.user)
		return TRUE
	if(action == "select")
		var/obj/structure/overmap/contact = locate(params["ref"]) in GLOB.overmap_objects
		select_contact(contact)
		return TRUE
	var/obj/structure/overmap/contact = selected_ref?.resolve()
	// Bind every action to the displayed selection, including across confirmation dialogs.
	if(!contact || REF(contact) != params["ref"])
		error = "That contact is no longer selected or has been deleted."
		return TRUE
	switch(action)
		if("inspect_ship")
			var/obj/structure/overmap/ship/ship = locate(params["ship_ref"]) in contact.get_docking_ships()
			if(!QDELETED(ship))
				select_contact(ship, contact)
		if("variables")
			ui.user.client.debug_variables(contact)
		if("jump", "overmap")
			var/turf/destination = action == "jump" ? contact.admin_interior_turf() : get_turf(contact)
			if(destination)
				ui.user.abstract_move(destination)
				log_admin("[key_name(ui.user)] jumped to [contact.admin_name()] ([action]) at [AREACOORD(destination)].")
		if("port_jump", "port_variables")
			var/obj/docking_port/port = locate(params["port_ref"])
			var/list/ports = contact.admin_ports()
			var/found = FALSE
			for(var/label in ports)
				if(ports[label] == port && !QDELETED(port))
					found = TRUE
					break
			if(!found)
				error = "This docking port is no longer assigned to the contact."
				return TRUE
			if(action == "port_jump")
				if(!contact.admin_operation && !contact.is_loading() && !contact.concerned && get_turf(port))
					ui.user.abstract_move(get_turf(port))
					log_admin("[key_name(ui.user)] jumped to [contact.admin_name()] port [port.name] at [AREACOORD(port)].")
			else
				ui.user.client.debug_variables(port)
		if("load", "unload", "delete")
			if(contact.admin_operation)
				error = "An admin operation is already running."
				return TRUE
			var/blocker = action == "load" ? contact.admin_load_blocker() : (action == "unload" ? contact.admin_unload_blocker() : contact.admin_delete_blocker())
			if(blocker)
				error = blocker
				return TRUE
			if(action != "load")
				var/prompt = action == "delete" ? "Permanently delete [contact.admin_name()] and everything in its interior?" : "Unload [contact.admin_name()]? Everything in its interior will be removed. [contact.admin_unload_effect()]"
				if(tgui_alert(ui.user, prompt, "Overmap Management", list("Confirm", "Cancel")) != "Confirm")
					return TRUE
			if(!authorized(ui.user) || QDELETED(contact) || selected_ref?.resolve() != contact || contact.admin_operation)
				return TRUE
			blocker = action == "load" ? contact.admin_load_blocker() : (action == "unload" ? contact.admin_unload_blocker() : contact.admin_delete_blocker())
			if(blocker)
				error = blocker
				return TRUE
			contact.admin_operation = action
			if(action == "load")
				watch_load(contact)
			INVOKE_ASYNC(contact, TYPE_PROC_REF(/obj/structure/overmap, admin_run_operation), action, ui.user, WEAKREF(src))
	return TRUE

/// Build from registered definitions, never from sensor disguises or a second planet list.
/datum/overmap_management/proc/build_spawn_catalog()
	spawn_catalog = list()
	for(var/obj/structure/overmap/planet/path as anything in subtypesof(/obj/structure/overmap/planet))
		var/datum/overmap/planet/definition = initial(path.planet)
		if(definition)
			add_spawn_option(initial(definition.name), initial(definition.surface_area) ? "Planets" : "Encounters", path, initial(definition.desc))
	for(var/id in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/template = SSmapping.space_ruins_templates[id]
		if(istype(template, /datum/map_template/ruin/space/lich_lair) || istype(template, /datum/map_template/ruin/space/contested_cache))
			continue // These event sites have dedicated admin spawn verbs.
		add_spawn_option(template.name, "Space ruins", template)
	for(var/obj/structure/overmap/event/path as anything in subtypesof(/obj/structure/overmap/event))
		add_spawn_option(initial(path.name), "Hazards", path, initial(path.desc))
	for(var/datum/map_template/shuttle/voidcrew/path as anything in subtypesof(/datum/map_template/shuttle/voidcrew))
		if(initial(path.suffix))
			add_spawn_option(initial(path.name), "Player ships", path)
	for(var/obj/structure/overmap/ship/npc/pirate/path as anything in subtypesof(/obj/structure/overmap/ship/npc/pirate))
		var/datum/map_template/shuttle/voidcrew/template = initial(path.shuttle_template)
		if(template && initial(template.suffix))
			add_spawn_option(initial(template.name), "NPC ships", path)

/datum/overmap_management/proc/add_spawn_option(name, category, path, description)
	var/id = "[length(spawn_catalog) + 1]"
	spawn_catalog[id] = list("id" = id, "name" = capitalize(name), "category" = category, "path" = path, "description" = description)

/datum/overmap_management/ui_static_data(mob/user)
	if(!authorized(user))
		return list()
	build_spawn_catalog()
	var/list/options = list()
	for(var/id in spawn_catalog)
		var/list/option = spawn_catalog[id].Copy()
		option -= "path"
		options += list(option)
	return list("spawn_options" = options)

/datum/overmap_management/proc/spawn_contact(mob/user, id, location, target_ref)
	if(!authorized(user) || spawning)
		return
	var/list/option = spawn_catalog?[id]
	if(!option || !(location in list("random", "selected")))
		error = "Choose a template and a spawn location."
		return
	var/obj/structure/overmap/selected = selected_ref?.resolve()
	if(location == "selected" && (!selected || REF(selected) != target_ref))
		error = "The selected location changed. Choose a location again."
		return
	var/turf/spawn_turf = location == "selected" ? get_turf(selected) : SSovermap.get_unused_overmap_square()
	if(!spawn_turf || spawn_turf.z != SSovermap.overmap_centre?.z)
		error = "No valid overmap sector is available."
		return
	spawning = TRUE
	var/category = option["category"]
	var/choice = option["name"]
	var/obj/structure/overmap/spawned
	var/path = option["path"]
	log_admin("[key_name(user)] requested overmap spawn: [choice] at [AREACOORD(spawn_turf)].")
	try
		switch(category)
			if("Player ships")
				spawned = SSshuttle.create_ship(path)
			if("NPC ships")
				spawned = SSnpc_ships.spawn_pirate(path)
			if("Space ruins")
				var/datum/map_template/ruin/space/template = path
				var/ruin_path = /obj/structure/overmap/space_ruin
				if(istype(template, /datum/map_template/ruin/space/vestige))
					ruin_path = /obj/structure/overmap/space_ruin/vestige
				spawned = new ruin_path(spawn_turf, template)
				if(!QDELETED(spawned) && istype(template, /datum/map_template/ruin/space/vestige))
					SSovermap.spawned_vestige_templates |= template
			else
				spawned = new path(spawn_turf)
		if(!QDELETED(spawned))
			spawned.forceMove(spawn_turf)
			spawned.sync_close_overmap_objects()
			if(!QDELETED(src))
				select_contact(spawned)
				spawn_serial++
				notice = "Spawned [spawned.admin_name()]."
			message_admins("[key_name_admin(user)] spawned [spawned.admin_name()] via Overmap Management. [ADMIN_VV(spawned)]")
		else
			operation_finished("Could not spawn [choice]. Check available map space and mapping logs.", FALSE)
	catch(var/exception/exception)
		stack_trace("Overmap admin spawn failed: [exception]")
		operation_finished("Spawning [choice] stopped because of a runtime error. See runtime logs for details.", FALSE)
	if(!QDELETED(src))
		spawning = FALSE
		SStgui.update_uis(src)

/obj/structure/overmap
	/// Shared by all admin windows; prevents duplicate asynchronous operations.
	var/admin_operation

/obj/structure/overmap/proc/admin_name()
	return display_name || name

/obj/structure/overmap/ship/admin_name()
	return name

/obj/structure/overmap/space_ruin/admin_name()
	return true_name || ruin_template?.name || ..()

/obj/structure/overmap/proc/admin_kind()
	if(istype(src, /obj/structure/overmap/ship/npc))
		return "NPC ships"
	if(istype(src, /obj/structure/overmap/ship))
		return "Ships"
	if(istype(src, /obj/structure/overmap/planet/empty))
		return "Encounters"
	if(istype(src, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/planet = src
		return planet.is_terrain_planet() ? "Planets" : "Encounters"
	if(istype(src, /obj/structure/overmap/space_ruin))
		return "Ruins"
	if(istype(src, /obj/structure/overmap/event/meteor))
		return "Asteroid fields"
	if(istype(src, /obj/structure/overmap/event))
		return "Hazards"
	if(istype(src, /obj/structure/overmap/dynamic/player_outpost) || istype(src, /obj/structure/overmap/trader_outpost))
		return "Outposts"
	return "Other"

/obj/structure/overmap/proc/admin_mapzone()
	return null

/obj/structure/overmap/planet/admin_mapzone()
	return mapzone

/obj/structure/overmap/space_ruin/admin_mapzone()
	return mapzone

/obj/structure/overmap/event/meteor/admin_mapzone()
	return mapzone

/obj/structure/overmap/dynamic/admin_mapzone()
	return mapzone

/// Labels retain the distinction between the mobile, transit and assigned stationary ports.
/obj/structure/overmap/proc/admin_ports()
	var/list/ports = list()
	for(var/datum/outpost_berth/berth as anything in berths)
		if(!QDELETED(berth) && berth.dock)
			ports["Hangar [berth.berth_number][berth.ship ? " - [berth.ship.name]" : ""]"] = berth.dock
	return ports

/obj/structure/overmap/planet/admin_ports()
	. = ..()
	if(reserve_dock)
		.["Landing pad 1"] = reserve_dock
	if(reserve_dock_secondary)
		.["Landing pad 2"] = reserve_dock_secondary

/obj/structure/overmap/space_ruin/admin_ports()
	. = ..()
	if(reserve_dock)
		.["Landing pad 1"] = reserve_dock
	if(reserve_dock_secondary)
		.["Landing pad 2"] = reserve_dock_secondary

/obj/structure/overmap/event/meteor/admin_ports()
	. = ..()
	if(reserve_dock)
		.["Landing pad 1"] = reserve_dock
	if(reserve_dock_secondary)
		.["Landing pad 2"] = reserve_dock_secondary

/obj/structure/overmap/dynamic/admin_ports()
	. = ..()
	if(reserve_dock)
		.["Landing pad 1"] = reserve_dock
	if(reserve_dock_secondary)
		.["Landing pad 2"] = reserve_dock_secondary

/obj/structure/overmap/dynamic/player_outpost/admin_ports()
	. = ..()
	if(freight_berth?.dock)
		.["Freight berth"] = freight_berth.dock

/obj/structure/overmap/ship/admin_ports()
	. = ..()
	if(shuttle)
		.["Mobile port"] = shuttle
		if(shuttle.get_docked())
			.["Current berth"] = shuttle.get_docked()
		if(shuttle.assigned_transit)
			.["Assigned transit"] = shuttle.assigned_transit

/obj/structure/overmap/proc/admin_interior_turf()
	if(is_loading() || admin_operation || concerned)
		return null
	if(template_bottom_left && (admin_mapzone() || is_loaded()))
		return template_bottom_left
	var/list/ports = admin_ports()
	for(var/label in ports)
		var/obj/docking_port/port = ports[label]
		if(!QDELETED(port) && get_turf(port))
			return get_turf(port)
	var/datum/map_footprint/footprint = get_interior_footprint()
	if(footprint)
		return locate(footprint.low_x, footprint.low_y, footprint.z_value)
	return null

/obj/structure/overmap/proc/admin_status()
	if(admin_operation)
		return "[capitalize(admin_operation)] requested"
	if(SSovermap.worldgen_owner == src)
		return is_loading() ? "Generating" : "Unloading"
	if(SSovermap.worldgen_waiting_for(src))
		return "Queued"
	if(is_loading())
		return "Loading"
	if(concerned)
		return "Busy"
	if(admin_mapzone())
		var/list/cleanup = admin_cleanup_details()
		return cleanup["title"]
	if(admin_mapzone() || is_loaded())
		return "Loaded"
	return admin_load_blocker() ? "Active" : "Unloaded"

/obj/structure/overmap/ship/admin_status()
	if(admin_operation)
		return ..()
	if(abandoned)
		return "Derelict"
	if(state == OVERMAP_SHIP_DOCKING)
		return "Docking"
	if(state == OVERMAP_SHIP_UNDOCKING)
		return "Undocking"
	return docked ? "Docked" : capitalize(state)

/obj/structure/overmap/trader_outpost/admin_status()
	return loading ? "Loading" : (loaded ? "Permanent interior" : "Unloaded")

/// Read the timers actually owned by the contact, rather than inferring that a retry exists.
/obj/structure/overmap/proc/admin_cleanup_timers()
	var/static/list/cleanup_procs = list(
		TYPE_PROC_REF(/obj/structure/overmap/planet, check_start_despawn) = "Next check",
		TYPE_PROC_REF(/obj/structure/overmap/planet, attempt_despawn) = "Unload interior",
		TYPE_PROC_REF(/obj/structure/overmap/planet/empty, try_unload_level) = "Next deletion attempt",
		TYPE_PROC_REF(/obj/structure/overmap/space_ruin, check_and_respawn) = "Next cleanup attempt",
		TYPE_PROC_REF(/obj/structure/overmap/event/meteor, unload_level) = "Next unload attempt",
	)
	var/list/timers = list()
	for(var/datum/timedevent/timer as anything in _active_timers)
		if(timer.spent || !timer.callBack)
			continue
		var/label = cleanup_procs[timer.callBack.delegate]
		if(label)
			timers += list(list("label" = label, "seconds" = max(0, round((timer.timeToRun - world.time) / 10))))
	return timers

/obj/structure/overmap/proc/admin_unload_effect()
	if(istype(src, /obj/structure/overmap/planet/empty))
		return "This temporary location will also be deleted."
	if(istype(src, /obj/structure/overmap/planet))
		return "The planet stays on the overmap and moves to another sector."
	if(istype(src, /obj/structure/overmap/space_ruin))
		return "The ruin moves to another sector and can be loaded again."
	return "The location stays on the overmap and can be loaded again."

/obj/structure/overmap/proc/admin_cleanup_details()
	var/list/details = list("title" = "Not scheduled", "reason" = null, "timer_label" = null, "seconds" = null)
	if(admin_operation || is_loading() || concerned || SSovermap.worldgen_owner == src)
		details["title"] = admin_operation == "delete" ? "Deleting" : (is_loading() || admin_operation == "load" ? "Loading" : "Unloading")
		details["reason"] = "Wait for this operation to finish."
		return details
	var/list/queued = SSovermap.worldgen_waiting_for(src)
	if(queued)
		details["title"] = "Queued"
		details["reason"] = "Waiting for another interior to finish. Position [queued["position"]] in the queue."
		return details
	if(istype(src, /obj/structure/overmap/trader_outpost) || istype(src, /obj/structure/overmap/dynamic/player_outpost))
		details["title"] = "Permanent location"
		details["reason"] = "Automatic cleanup is disabled for outposts."
		return details
	if(istype(src, /obj/structure/overmap/ship))
		var/obj/structure/overmap/ship/ship = src
		details["title"] = ship.abandoned ? "Derelict" : "In service"
		if(ship.docked)
			details["reason"] = "[ship.presence_at(ship.docked)] at [ship.docked.admin_name()]."
		if(ship.has_active_crew())
			details["reason"] = "Active crew are keeping this ship in service."
		else if(ship.abandoned_at)
			details["timer_label"] = "Eligible for automatic deletion in"
			details["seconds"] = max(0, round((ship.abandoned_at + SHIP_DERELICT_DESPAWN_TIME - world.time) / 10))
		else if(ship.crewless_since)
			var/obj/structure/overmap/ship/npc/npc = astype(ship)
			if(npc && !npc.player_controlled && !isnull(npc.disarmed_despawn_at))
				details["title"] = "Retired NPC ship"
				details["timer_label"] = "Eligible for automatic deletion in"
				details["seconds"] = max(0, round((npc.disarmed_despawn_at - world.time) / 10))
			else if(!npc || npc.player_controlled || npc.integrity_state == SHIP_INTEGRITY_DISABLED)
				details["title"] = "No active crew"
				details["timer_label"] = "Eligible for abandonment in"
				details["seconds"] = max(0, round((ship.crewless_since + SHIP_CREWLESS_ABANDON_TIME - world.time) / 10))
		return details
	var/list/timers = admin_cleanup_timers()
	if(!admin_mapzone())
		details["reason"] = "No loaded interior to clean up."
		return details
	var/blocker = admin_unload_blocker()
	details["title"] = blocker ? "Cleanup blocked" : "Loaded"
	details["reason"] = blocker || admin_unload_effect()
	if(istype(src, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/planet = src
		if(planet.preserve_level)
			details["title"] = "Kept loaded"
			return details
	if(length(timers))
		var/list/timer = timers[1]
		details["timer_label"] = timer["label"]
		details["seconds"] = timer["seconds"]
		if(!blocker)
			details["title"] = timer["label"] == "Unload interior" ? "Unload scheduled" : "Awaiting cleanup check"
		else if(timer["label"] == "Unload interior")
			details["timer_label"] = "Will check again in"
	return details

/obj/structure/overmap/proc/admin_load_blocker()
	if(is_loading() || concerned || SSovermap.worldgen_owner == src || SSovermap.worldgen_waiting_for(src))
		return "Another operation is in progress. Wait for it to finish."
	if(admin_mapzone() || is_loaded())
		return "The interior is already loaded."
	if(istype(src, /obj/structure/overmap/planet) || istype(src, /obj/structure/overmap/space_ruin) || istype(src, /obj/structure/overmap/event/meteor))
		return null
	return "This contact has no separately loadable interior."

/obj/structure/overmap/proc/admin_unload_blocker()
	if(is_loading() || concerned || SSovermap.worldgen_owner == src || SSovermap.worldgen_waiting_for(src))
		return "Another operation is in progress. Wait for it to finish."
	if(istype(src, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/planet = src
		if(planet.unloading)
			return "Interior teardown is in progress."
		if(planet.preserve_level)
			return "This interior is set to stay loaded."
		return planet.get_interior_release_blocker()
	if(istype(src, /obj/structure/overmap/space_ruin))
		var/obj/structure/overmap/space_ruin/ruin = src
		if(istype(ruin, /obj/structure/overmap/space_ruin/lich_lair))
			return "The lich lair preserves its raid state for the round."
		if(ruin.mission_locked)
			return "An active mission owns this site's lifecycle."
		return ruin.get_interior_release_blocker()
	if(istype(src, /obj/structure/overmap/event/meteor))
		var/obj/structure/overmap/event/meteor/field = src
		return field.get_interior_release_blocker()
	if(istype(src, /obj/structure/overmap/ship))
		return "Ships are removed with Delete; they have no unloaded state."
	return "This contact has no unloadable interior."

/obj/structure/overmap/proc/admin_delete_blocker()
	if(is_loading() || concerned || SSovermap.worldgen_owner == src || SSovermap.worldgen_waiting_for(src))
		return "Another operation is in progress. Wait for it to finish."
	var/docking_blocker = get_docking_blocker()
	if(docking_blocker)
		return docking_blocker
	if(istype(src, /obj/structure/overmap/ship))
		var/obj/structure/overmap/ship/ship = src
		if(ship.state == OVERMAP_SHIP_DOCKING || ship.state == OVERMAP_SHIP_UNDOCKING || ship.shuttle?.move_in_flight())
			return "A docking maneuver is in progress."
		if(ship.has_active_crew())
			return "This ship has active crew. Move the crew off the ship before deleting it."
		for(var/mob/player as anything in GLOB.player_list)
			if(isliving(player) && ship.is_aboard(player))
				return "[player.name] is still aboard."
		return null
	if(istype(src, /obj/structure/overmap/space_ruin))
		var/obj/structure/overmap/space_ruin/ruin = src
		if(ruin.mission_locked || ruin.mission_claims)
			return "Active missions still reference this ruin."
	if(admin_mapzone())
		return admin_unload_blocker()
	if(istype(src, /obj/structure/overmap/planet) || istype(src, /obj/structure/overmap/space_ruin) || istype(src, /obj/structure/overmap/event))
		return null
	if(istype(src, /obj/structure/overmap/dynamic/player_outpost))
		return "Use Manage outposts to remove a player outpost."
	return "This is a permanent location; deletion is unavailable."

/// Runs on the contact, so closing the panel cannot interrupt a map teardown.
/obj/structure/overmap/proc/admin_run_operation(action, mob/user, datum/weakref/panel_ref)
	if(!check_rights_for(user?.client, R_ADMIN))
		admin_operation = null
		return
	var/contact_name = admin_name()
	log_admin("[key_name(user)] requested overmap [action] for [contact_name] ([type]).")
	message_admins("[key_name_admin(user)] requested [action] for [contact_name] via Overmap Management.")
	var/succeeded = FALSE
	var/failure
	try
		if(action == "load")
			start_level_load(user)
			// The normal loader owns its loading flag and completion signal from here.
			succeeded = is_loading() || is_loaded()
		else if(istype(src, /obj/structure/overmap/ship))
			var/obj/structure/overmap/ship/ship = src
			if(action == "delete")
				succeeded = ship.despawn_derelict()
		else
			if(admin_mapzone() || istype(src, /obj/structure/overmap/planet/empty))
				if(istype(src, /obj/structure/overmap/planet))
					var/obj/structure/overmap/planet/planet = src
					planet.cancel_despawn_timer()
					planet.unload_level()
					if(!QDELETED(planet) && planet.mapzone)
						planet.check_start_despawn()
				else if(istype(src, /obj/structure/overmap/space_ruin))
					var/obj/structure/overmap/space_ruin/ruin = src
					ruin.unload_level()
				else if(istype(src, /obj/structure/overmap/event/meteor))
					var/obj/structure/overmap/event/meteor/field = src
					field.unload_level()
			succeeded = QDELETED(src) || !admin_mapzone()
			if(action == "delete" && succeeded && !QDELETED(src))
				// A queued teardown may have yielded; honor new claims or approaches.
				var/blocker = admin_delete_blocker()
				if(blocker)
					succeeded = FALSE
					failure = blocker
				else
					qdel(src)
	catch(var/exception/exception)
		succeeded = FALSE
		failure = "A runtime error interrupted the operation. See runtime logs for details."
		stack_trace("Overmap admin [action] failed for [contact_name]: [exception]")
	if(!QDELETED(src))
		admin_operation = null
		if(!succeeded && !failure)
			failure = action == "load" ? admin_load_blocker() : (action == "delete" ? admin_delete_blocker() : admin_unload_blocker())
	var/result
	if(succeeded)
		result = action == "load" ? (is_loaded() ? "Loaded the interior of [contact_name]." : "Loading started for [contact_name].") : (QDELETED(src) ? "Deleted [contact_name]." : "Unloaded the interior of [contact_name].")
	else
		result = "Could not [action] [contact_name]. [failure || "No interior space was released. Retry after other map operations finish; if it persists, check mapping logs."]"
	log_admin("Overmap [action] for [contact_name]: [result]")
	to_chat(user, succeeded ? span_notice(result) : span_warning(result))
	var/datum/overmap_management/panel = panel_ref?.resolve()
	if(action == "load" && !is_loading())
		panel?.UnregisterSignal(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED)
	panel?.operation_finished(result, succeeded)
