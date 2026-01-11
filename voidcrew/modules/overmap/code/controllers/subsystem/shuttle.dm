/// The ship currently being loaded via create_ship(). Used by modular_map_root/ship_upgrade
/// to find the ship during map loading (before current_ship is set on the docking port).
/datum/controller/subsystem/shuttle
	var/obj/structure/overmap/ship/loading_ship

/datum/controller/subsystem/shuttle/proc/create_ship(ship_template_to_spawn, list/upgrade_selections)
	RETURN_TYPE(/obj/structure/overmap/ship)

	UNTIL(!shuttle_loading)
	shuttle_loading = TRUE

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
		shuttle_loading = FALSE
		return FALSE

	if(!template_instance)
		stack_trace("Failed to instantiate ship template [ship_template_to_spawn].")
		shuttle_loading = FALSE
		return FALSE

	// Create ship and set template directly as a workaround for Initialize arg passing
	// Ships spawn in the green zone (outer ring) for safety
	var/turf/spawn_loc = SSovermap.get_unused_overmap_square_in_green_zone(tries = INFINITY)
	var/obj/structure/overmap/ship/ship_to_spawn = new(spawn_loc)

	if(!ship_to_spawn || QDELETED(ship_to_spawn))
		stack_trace("Unable to properly load ship [ship_template_to_spawn].")
		shuttle_loading = FALSE
		return FALSE

	// Manually initialize the ship with the template since arg passing through Initialize chain is broken
	if(!ship_to_spawn.setup_from_template(template_instance))
		stack_trace("Ship failed to setup from template [ship_template_to_spawn].")
		qdel(ship_to_spawn)
		shuttle_loading = FALSE
		return FALSE

	// Store upgrade selections and theme on ship BEFORE map loads (so modular_map_root can read them)
	if(length(upgrade_selections))
		ship_to_spawn.upgrade_selections = upgrade_selections.Copy()
	ship_to_spawn.theme = template_instance.theme

	// Set loading_ship so modular_map_root/ship_upgrade can find the ship during map loading
	loading_ship = ship_to_spawn

	SSair.can_fire = FALSE
	var/obj/docking_port/mobile/voidcrew/loaded = action_load(ship_to_spawn.source_template)
	SSair.can_fire = TRUE

	// Clear loading_ship now that map is loaded
	loading_ship = null
	shuttle_loading = FALSE

	if(!loaded)
		stack_trace("Unable to properly load ship template [ship_to_spawn.source_template].")
		loading_ship = null
		qdel(ship_to_spawn)
		return FALSE

	loaded.current_ship = ship_to_spawn
	ship_to_spawn.name = loaded.name
	ship_to_spawn.shuttle = loaded

	SEND_SIGNAL(loaded, COMSIG_VOIDCREW_SHIP_LOADED)

	ship_to_spawn.calculate_mass()

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

	return ship_to_spawn

/client/add_admin_verbs()
	. = ..()
	add_verb(src, list(
		/client/proc/respawn_ship,
		/client/proc/spawn_specific_ship,
		/client/proc/spawn_modular_ship,
		/client/proc/initiate_jump,
		/client/proc/cancel_jump,
		/client/proc/team_panel,
	))

/client/remove_admin_verbs()
	. = ..()
	remove_verb(src, list(
		/client/proc/respawn_ship,
		/client/proc/spawn_specific_ship,
		/client/proc/spawn_modular_ship,
		/client/proc/initiate_jump,
		/client/proc/cancel_jump,
		/client/proc/team_panel,
	))

#define RESPAWN_FORCE "Force Respawn"
/client/proc/respawn_ship()
	set name = "Respawn Initial Ship"
	set category = "Overmap.Spawn"
	if(SSovermap.initial_ship)
		var/resp = tgui_alert(usr, "Initial ship already exists. This can delete players and their progress", "Shits Fucked", list(RESPAWN_FORCE, "Cancel"))
		if(resp != RESPAWN_FORCE)
			return
		qdel(SSovermap.initial_ship)
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

/client/proc/spawn_modular_ship()
	set name = "Spawn Modular Ship (With Upgrades)"
	set category = "Overmap.Spawn"

	// Initialize upgrade system
	ensure_ship_upgrades_initialized()

	// Build list of ships that support upgrades
	var/list/modular_ships = list()
	for(var/ship_type in subtypesof(/datum/map_template/shuttle/voidcrew))
		var/datum/map_template/shuttle/voidcrew/template = ship_type
		if(initial(template.abstract) == ship_type)
			continue
		if(initial(template.has_upgrade_slots))
			modular_ships[initial(template.name)] = ship_type

	if(!length(modular_ships))
		to_chat(usr, span_warning("No ships with upgrade slots found!"))
		return

	// Select ship
	var/ship_choice = tgui_input_list(usr, "Select a modular ship to spawn:", "Spawn Modular Ship", modular_ships)
	if(!ship_choice)
		return

	var/ship_type = modular_ships[ship_choice]
	var/datum/map_template/shuttle/voidcrew/template = new ship_type()

	// Get modules registered for this ship
	var/list/ship_modules = get_modules_for_ship(ship_type)
	if(!length(ship_modules))
		to_chat(usr, span_warning("No upgrade modules registered for [template.name]!"))
		// Still allow spawning with no upgrades

	// Build upgrade selections for each slot
	var/list/upgrade_selections = list()

	for(var/slot_key in template.upgrade_slot_ids)
		// Find all modules for this slot
		var/list/slot_options = list()
		slot_options["None (empty)"] = null

		for(var/module_id in ship_modules)
			var/datum/ship_upgrade_module/module = ship_modules[module_id]
			if(module.slot != slot_key)
				continue

			var/option_name = module.name
			if(module.is_default)
				option_name += " (default)"
			if(length(module.part_cost))
				var/list/costs = list()
				for(var/part_class in module.part_cost)
					costs += "[module.part_cost[part_class]] [part_class]"
				option_name += " [jointext(costs, ", ")]"

			slot_options[option_name] = module

		// Ask user to pick
		var/choice = tgui_input_list(usr, "Select upgrade for '[slot_key]':", "Upgrade: [slot_key]", slot_options)
		if(choice && slot_options[choice])
			upgrade_selections[slot_key] = slot_options[choice]

	// Show summary
	to_chat(usr, span_notice("Spawning [template.name] with [length(upgrade_selections)] upgrade(s) selected..."))

	// Spawn
	var/obj/structure/overmap/ship/spawned = SSshuttle.create_ship(template, upgrade_selections)
	if(spawned)
		mob.client?.admin_follow(spawned.shuttle)
		to_chat(usr, span_notice("[template.name] spawned successfully!"))
	else
		to_chat(usr, span_warning("Failed to spawn [template.name]!"))

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


