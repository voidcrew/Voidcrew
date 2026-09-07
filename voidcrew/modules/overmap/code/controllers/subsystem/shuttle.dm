/// The ship currently being loaded, before its mobile port has current_ship assigned.
/datum/controller/subsystem/shuttle
	var/obj/structure/overmap/ship/loading_ship
	/// The only operation allowed to mutate the subsystem-wide template preview.
	var/datum/shuttle_template_load/active_template_load

/// Shared by nested operations belonging to one serialized template load.
/datum/shuttle_template_load
	var/obj/structure/overmap/ship/previous_loading_ship
	var/previous_air_can_fire

/// A timeout refuses the waiter without changing the active owner's state.
/datum/controller/subsystem/shuttle/proc/acquire_template_load(wait_timeout = null)
	var/deadline = isnum(wait_timeout) ? world.time + max(0, wait_timeout) : null
	while(shuttle_loading)
		if(isnum(deadline) && world.time >= deadline)
			return null
		stoplag(1)

	var/datum/shuttle_template_load/load_owner = new
	load_owner.previous_loading_ship = loading_ship
	load_owner.previous_air_can_fire = SSair.can_fire
	active_template_load = load_owner
	shuttle_loading = TRUE
	return load_owner

/datum/controller/subsystem/shuttle/proc/release_template_load(datum/shuttle_template_load/load_owner)
	if(!load_owner || active_template_load != load_owner)
		return FALSE
	loading_ship = load_owner.previous_loading_ship
	SSair.can_fire = load_owner.previous_air_can_fire
	active_template_load = null
	shuttle_loading = FALSE
	return TRUE

/// Own the preview across every yield, including nested ship/template operations.
/datum/controller/subsystem/shuttle/proc/run_template_load(datum/callback/operation, datum/shuttle_template_load/load_owner, wait_timeout = null)
	var/acquired_owner = !load_owner
	if(acquired_owner)
		load_owner = acquire_template_load(wait_timeout)
	if(!load_owner)
		return FALSE
	if(active_template_load != load_owner)
		CRASH("A shuttle template operation tried to use another load's ownership.")

	// Keep a normal proc boundary here. Catching across the map stack makes BYOND
	// unwind past the reader/atom subsystem's own cleanup after legacy map runtimes.
	// Invoke returns even when the operation aborts, so ownership still gets released.
	. = operation.Invoke(load_owner)
	if(acquired_owner)
		release_template_load(load_owner)

/// Mid-round ports only queue when they actually have a template to load.
/datum/controller/subsystem/shuttle/proc/setup_shuttle_late(obj/docking_port/stationary/port)
	if(QDELETED(port) || (!port.roundstart_template && !port.json_key && !port.shuttle_template_id))
		return
	// action_load() owns serialization. In particular, a transit port must never
	// wait two minutes then clear a different ship's active load as the old path did.
	port.load_roundstart()

/datum/controller/subsystem/shuttle/proc/create_ship(ship_template_to_spawn, list/upgrade_selections, datum/ship_theme/selected_theme)
	RETURN_TYPE(/obj/structure/overmap/ship)
	return run_template_load(CALLBACK(src, PROC_REF(create_ship_impl), ship_template_to_spawn, upgrade_selections, selected_theme))

/datum/controller/subsystem/shuttle/proc/create_ship_impl(ship_template_to_spawn, list/upgrade_selections, datum/ship_theme/selected_theme, datum/shuttle_template_load/load_owner)

	// Handle both type paths and already-instantiated templates
	var/datum/map_template/shuttle/voidcrew/template_instance
	if(istype(ship_template_to_spawn, /datum/map_template/shuttle/voidcrew))
		// Already an instantiated template object
		template_instance = ship_template_to_spawn
	else if(ispath(ship_template_to_spawn, /datum/map_template/shuttle/voidcrew))
		// It's a type path, instantiate it
		template_instance = new ship_template_to_spawn()
	else
		stack_trace("create_ship called with invalid argument: [ship_template_to_spawn]")
		return FALSE

	if(!template_instance)
		stack_trace("Failed to instantiate ship template [ship_template_to_spawn].")
		return FALSE

	// No theme picked but the ship is themed (roundstart list, admin spawn): use the
	// default theme so the ship gets its job slots and the right base dmm
	if(!selected_theme && length(template_instance.available_themes))
		selected_theme = get_default_theme_for_ship(template_instance.type)

	// If a theme is selected, update the template's suffix, mappath, and theme ID for map loading
	if(selected_theme)
		template_instance.suffix = selected_theme.template_suffix
		template_instance.theme = selected_theme.id
		// Recalculate mappath since suffix changed (mappath is set in New() before we can change suffix)
		template_instance.mappath = "[template_instance.prefix][template_instance.port_id]_[template_instance.suffix].dmm"
		// New() measured the DEFAULT suffix's dmm. load_template() sizes the transit
		// reservation from width/height, and calculate_docking_port_information() takes the
		// port bounds from width/height/port_x_offset/port_y_offset, so a theme whose map is
		// a different size - or has its docking port somewhere else - has to re-measure here.
		if(fexists(template_instance.mappath))
			template_instance.preload_size(template_instance.mappath)
		else
			stack_trace("Ship theme [selected_theme.id] points at a missing map: [template_instance.mappath]")

	var/datum/worldgen_probe/probe = worldgen_begin("ship", "[template_instance.name] theme=[selected_theme?.id || "default"]")

	// Create ship and set template directly as a workaround for Initialize arg passing
	// Ships spawn in the green zone (outer ring) for safety
	var/turf/spawn_loc = SSovermap.get_unused_overmap_square_in_green_zone(tries = INFINITY)
	var/obj/structure/overmap/ship/ship_to_spawn = new(spawn_loc)

	if(!ship_to_spawn || QDELETED(ship_to_spawn))
		stack_trace("Unable to properly load ship [ship_template_to_spawn].")
		worldgen_end(probe, "spawn-failed")
		return FALSE

	// Store upgrade selections and theme BEFORE setup_from_template (module job_slots_add
	// reads them) and BEFORE the map loads (modular_map_root reads them)
	if(length(upgrade_selections))
		ship_to_spawn.upgrade_selections = upgrade_selections.Copy()
	ship_to_spawn.theme = selected_theme?.id || template_instance.theme

	// Manually initialize the ship with the template since arg passing through Initialize chain is broken
	// Pass the selected theme so job_slots can be set from theme
	if(!ship_to_spawn.setup_from_template(template_instance, selected_theme))
		stack_trace("Ship failed to setup from template [ship_template_to_spawn].")
		qdel(ship_to_spawn)
		worldgen_end(probe, "setup-failed")
		return FALSE

	// Set loading_ship so modular_map_root/ship_upgrade can find the ship during map loading
	loading_ship = ship_to_spawn

	SSair.can_fire = FALSE
	var/obj/docking_port/mobile/voidcrew/loaded = action_load(ship_to_spawn.source_template, load_owner = load_owner)
	SSair.can_fire = load_owner.previous_air_can_fire

	// Clear loading_ship now that map is loaded
	loading_ship = null

	if(!loaded)
		// A refusal for want of transit map volume (world.maxz at its ceiling with the
		// reserved levels momentarily full) is a capacity condition that clears in
		// seconds, not a code fault - log it as such and spare the stack trace for
		// loads that fail with room available.
		var/at_capacity = SSmapping.at_z_level_ceiling()
		if(at_capacity)
			log_mapping("SSshuttle: create_ship refused for '[ship_to_spawn.source_template]' - no transit map volume free (world.maxz at its ceiling)")
		else
			stack_trace("Unable to properly load ship template [ship_to_spawn.source_template].")
		loading_ship = null
		qdel(ship_to_spawn)
		worldgen_end(probe, at_capacity ? "load-refused-capacity" : "load-failed")
		return FALSE

	loaded.current_ship = ship_to_spawn
	ship_to_spawn.name = loaded.name
	ship_to_spawn.shuttle = loaded

	// Fresh ships spawn parked in deep space with zero speed - still the starfield
	// the template load asserted on our areas
	ship_to_spawn.update_flight_parallax()

	// Mass must exist before the signal: SHIP_LOADED handlers (shield generators among
	// them) read ship.mass for power pricing, and at this point it is still null
	ship_to_spawn.calculate_mass()

	SEND_SIGNAL(loaded, COMSIG_VOIDCREW_SHIP_LOADED)

	// assign landmarks as needed - use shuttle areas or fallback to shuttle location
	var/turf/safe_turf
	if(length(loaded.shuttle_areas))
		safe_turf = get_safe_random_station_turf(loaded.shuttle_areas)
	if(!safe_turf)
		// Fallback: find any turf inside the shuttle
		for(var/area/shuttle_area as anything in loaded.shuttle_areas)
			var/turf/area_turf = locate() in shuttle_area
			if(area_turf)
				safe_turf = area_turf
				break
	if(!safe_turf)
		// Last resort: use the docking port location
		safe_turf = get_turf(loaded)
	if(safe_turf)
		new /obj/effect/landmark/blobstart(safe_turf) // Stationloving component
		new /obj/effect/landmark/observer_start(safe_turf) // Observer and Unit tests

	// No hull configuration may launch without breathing gear, or without a
	// surgical kit if it has somewhere to operate (BAL-6) - see
	// voidcrew/modules/shuttle/ship_parts/starter_supplies.dm
	loaded.ensure_starter_supplies()

	worldgen_end(probe)
	return ship_to_spawn

/client/add_admin_verbs()
	. = ..()
	add_verb(src, list(
		/client/proc/respawn_ship,
		/client/proc/spawn_specific_ship,
		/client/proc/initiate_jump,
		/client/proc/cancel_jump,
		/client/proc/team_panel,
		/client/proc/spawn_npc_ship,
		/client/proc/npc_ship_status,
	))

/client/remove_admin_verbs()
	. = ..()
	remove_verb(src, list(
		/client/proc/respawn_ship,
		/client/proc/spawn_specific_ship,
		/client/proc/initiate_jump,
		/client/proc/cancel_jump,
		/client/proc/team_panel,
		/client/proc/spawn_npc_ship,
		/client/proc/npc_ship_status,
	))

#define RESPAWN_FORCE "Force Respawn"
/client/proc/respawn_ship()
	set name = "Respawn Initial Ships"
	set category = "Overmap.Spawn"
	if(length(SSovermap.initial_ships))
		var/resp = tgui_alert(usr, "Roundstart ships already exist ([length(SSovermap.initial_ships)] ships). This can delete players and their progress.", "Warning", list(RESPAWN_FORCE, "Cancel"))
		if(resp != RESPAWN_FORCE)
			return
		for(var/obj/structure/overmap/ship/ship as anything in SSovermap.initial_ships.Copy())
			qdel(ship)
		SSovermap.initial_ships.Cut()
		SSovermap.initial_ship = null
	// Fresh fleet, fresh draw - otherwise the reroll avoids every class it just deleted
	SSovermap.spent_roundstart_hulls.Cut()
	SSovermap.spawn_initial_ship()
#undef RESPAWN_FORCE

/client/proc/spawn_specific_ship()
	set name = "Spawn Specific Ship"
	set category = "Overmap.Spawn"
	var/static/list/choices
	if(!choices)
		choices = list()
		for(var/ship in subtypesof(/datum/map_template/shuttle/voidcrew))
			var/datum/map_template/shuttle/voidcrew/V = ship
			choices[initial(V.name)] = V
	var/ship_to_spawn = tgui_input_list(usr, "Which ship do you want to spawn?", "Spawn Specific Ship", choices)
	if(!ship_to_spawn)
		return

	var/obj/structure/overmap/ship/spawned = SSshuttle.create_ship(choices[ship_to_spawn])
	mob.client?.admin_follow(spawned.shuttle)

/client/proc/initiate_jump()
	set name = "Initiate Jump"
	set category = "Overmap.Jump"
	if(!check_rights(R_ADMIN))
		return

	var/confirm = tgui_alert(src, "Are you sure you want to initiate a bluespace jump?", "Bluespace Jump", list("Yes", "No"))
	if(confirm != "Yes")
		return

	if(SSovermap.jump_mode > BS_JUMP_IDLE)
		return

	SSovermap.request_jump()
	SSblackbox.record_feedback("tally", "admin_verb", 1, "Call Shuttle") //If you are copy-pasting this, ensure the 2nd parameter is unique to the new proc!
	log_admin("[key_name(usr)] admin-initiated a bluespace jump.")
	message_admins("<span class='adminnotice'>[key_name_admin(usr)] admin-initiated a bluespace jump.</span>")

/client/proc/cancel_jump()
	set name = "Cancel Jump"
	set category = "Overmap.Jump"
	if(!check_rights(0))
		return

	var/confirm = tgui_alert(src, "Are you sure you want to cancel the bluespace jump?", "Bluespace Jump", list("Yes", "No"))
	if(confirm != "Yes")
		return

	if(SSovermap.jump_mode != BS_JUMP_CALLED)
		return

	SSovermap.cancel_jump()
	SSblackbox.record_feedback("tally", "admin_verb", 1, "Cancel Shuttle") //If you are copy-pasting this, ensure the 2nd parameter is unique to the new proc!
	log_admin("[key_name(usr)] admin-cancelled a bluespace jump.")
	message_admins("<span class='adminnotice'>[key_name_admin(usr)] admin-cancelled a bluespace jump.</span>")

/client/proc/team_panel()
	set name = "Team Panel"
	set category = "Overmap.Team"
	if(!check_rights(R_ADMIN))
		return
	src.holder.check_teams()


