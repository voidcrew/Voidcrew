/**
 * NPC Ships Spawner Subsystem
 *
 * Manages dynamic spawning of NPC pirate ships in RED zones.
 * Ships are spawned periodically throughout the round based on player count.
 */
SUBSYSTEM_DEF(npc_ships)
	name = "NPC Ships"
	wait = NPC_SHIP_SPAWN_INTERVAL
	init_order = INIT_ORDER_OVERMAP + 2 // After SSovermap and SSovermap_zones
	flags = SS_BACKGROUND
	runlevels = RUNLEVEL_GAME

	/// List of currently active NPC ships
	var/list/obj/structure/overmap/ship/npc/active_ships = list()

	/// Maximum number of NPC ships that can exist at once
	var/max_ships = NPC_SHIP_MAX_SHIPS

	/// Weighted list of NPC ship types to spawn
	/// Format: list(ship_type_path = weight, ...)
	var/list/ship_types = list()

	/// Whether spawning is enabled
	var/spawning_enabled = TRUE

/datum/controller/subsystem/npc_ships/Initialize()
	// Build the ship type list with all available pirate factions
	build_ship_type_list()

	log_world("SSnpc_ships: Initialized with [length(ship_types)] ship types, max [max_ships] ships")
	return SS_INIT_SUCCESS

/datum/controller/subsystem/npc_ships/fire(resumed)
	if(!spawning_enabled)
		return

	// Clean up destroyed ships
	cleanup_destroyed_ships()

	// Check if we can spawn more
	if(length(active_ships) >= max_ships)
		return

	// Spawn chance scales with player count
	// Base 15% + 3% per player
	var/spawn_chance = 15 + (length(GLOB.clients) * 3)
	if(!prob(spawn_chance))
		return

	// Pick a random ship type and spawn it
	if(!length(ship_types))
		return
	var/ship_type = pick_weight(ship_types)
	spawn_npc_ship(ship_type)

/**
 * Builds the weighted list of NPC ship types to spawn.
 * Each faction has a weight determining spawn frequency.
 * Light-threat factions are more common, heavy-threat are rarer.
 */
/datum/controller/subsystem/npc_ships/proc/build_ship_type_list()
	ship_types = list()

	// Light-threat factions (more common)
	ship_types[/obj/structure/overmap/ship/npc/pirate] = 20              // Rogues (default)
	ship_types[/obj/structure/overmap/ship/npc/pirate/silverscale] = 15  // Silverscale nobles
	ship_types[/obj/structure/overmap/ship/npc/pirate/grey] = 15         // Grey Tide
	ship_types[/obj/structure/overmap/ship/npc/pirate/lustrous] = 10     // Lustrous ethereals

	// Heavy-threat factions (rarer but more dangerous)
	ship_types[/obj/structure/overmap/ship/npc/pirate/skeleton] = 10     // Flying Dutchman
	ship_types[/obj/structure/overmap/ship/npc/pirate/interdyne] = 10    // Interdyne biocraft
	ship_types[/obj/structure/overmap/ship/npc/pirate/irs] = 10          // Space IRS
	ship_types[/obj/structure/overmap/ship/npc/pirate/medieval] = 10     // Medieval warmongers

	// If no ship types found, log a warning
	if(!length(ship_types))
		log_world("SSnpc_ships: WARNING - No ship types found for NPC spawning!")

/**
 * Removes destroyed ships from the active list.
 */
/datum/controller/subsystem/npc_ships/proc/cleanup_destroyed_ships()
	for(var/obj/structure/overmap/ship/npc/ship as anything in active_ships)
		if(QDELETED(ship))
			active_ships -= ship

/// Lookup table for ship type spawn zones
/// Light-threat factions spawn in yellow zones, heavy-threat in red zones
/datum/controller/subsystem/npc_ships/proc/get_spawn_zones_for_type(ship_type_path)
	switch(ship_type_path)
		// Light-threat factions - spawn in yellow (and red)
		if(/obj/structure/overmap/ship/npc/pirate)           // Rogues
			return list(ZONE_YELLOW)
		if(/obj/structure/overmap/ship/npc/pirate/silverscale)
			return list(ZONE_YELLOW)
		if(/obj/structure/overmap/ship/npc/pirate/grey)
			return list(ZONE_YELLOW)
		if(/obj/structure/overmap/ship/npc/pirate/lustrous)
			return list(ZONE_YELLOW)

		// Heavy-threat factions - spawn only in red
		if(/obj/structure/overmap/ship/npc/pirate/skeleton)
			return list(ZONE_RED)
		if(/obj/structure/overmap/ship/npc/pirate/interdyne)
			return list(ZONE_RED)
		if(/obj/structure/overmap/ship/npc/pirate/irs)
			return list(ZONE_RED)
		if(/obj/structure/overmap/ship/npc/pirate/medieval)
			return list(ZONE_RED)

	// Default fallback - red zone only
	return list(ZONE_RED)

/**
 * Spawns a new NPC ship in a valid zone.
 * @param ship_type_path The ship type to spawn (e.g., /obj/structure/overmap/ship/npc/pirate)
 * @return The spawned ship or null on failure.
 */
/datum/controller/subsystem/npc_ships/proc/spawn_npc_ship(ship_type_path = /obj/structure/overmap/ship/npc/pirate)
	// Get the shuttle template from the ship type
	var/template_path = initial(ship_type_path:shuttle_template)
	if(!template_path)
		log_world("SSnpc_ships: No shuttle_template defined for [ship_type_path]")
		return null

	// Get spawn zones for this ship type
	var/list/spawn_zones = get_spawn_zones_for_type(ship_type_path)
	if(!length(spawn_zones))
		return null

	// Find a spawn location in valid zones, away from player ships
	var/turf/spawn_turf = get_spawn_turf(spawn_zones)
	if(!spawn_turf)
		return null

	// Create the NPC ship
	var/obj/structure/overmap/ship/npc/ship = create_npc_ship(template_path, spawn_turf, ship_type_path)
	if(!ship)
		return null

	active_ships += ship
	log_world("SSnpc_ships: Spawned [ship.name] at ([spawn_turf.x], [spawn_turf.y])")

	return ship

/**
 * Finds a valid spawn turf for an NPC ship.
 * @param spawn_zones List of zone types to spawn in (ZONE_RED, ZONE_YELLOW, ZONE_GREEN)
 */
/datum/controller/subsystem/npc_ships/proc/get_spawn_turf(list/spawn_zones)
	// Build list of valid turfs from specified zones
	var/list/valid_turfs = list()

	for(var/zone_type in spawn_zones)
		var/datum/overmap_zone/zone = SSovermap_zones.get_zone_datum(zone_type)
		if(zone?.turfs)
			valid_turfs += zone.turfs

	if(!length(valid_turfs))
		return null

	// Filter out turfs near player ships (5 tile buffer)
	var/list/safe_turfs = list()
	for(var/turf/T as anything in valid_turfs)
		// Check for nearby ships
		var/too_close = FALSE
		for(var/obj/structure/overmap/ship/ship in range(5, T))
			// Skip NPC ships
			if(istype(ship, /obj/structure/overmap/ship/npc))
				continue
			too_close = TRUE
			break

		// Also check for overmap objects on this exact turf
		if(locate(/obj/structure/overmap) in T)
			continue

		if(!too_close)
			safe_turfs += T

	if(!length(safe_turfs))
		return null

	return pick(safe_turfs)

/**
 * Creates an NPC ship from a template at the specified location.
 * This is similar to SSshuttle.create_ship() but for NPC ships.
 * @param template_path The shuttle template to use
 * @param spawn_turf Where to spawn the ship
 * @param ship_type_path The ship type path (e.g., /obj/structure/overmap/ship/npc/pirate)
 */
/datum/controller/subsystem/npc_ships/proc/create_npc_ship(template_path, turf/spawn_turf, ship_type_path = /obj/structure/overmap/ship/npc/pirate)
	UNTIL(!SSshuttle.shuttle_loading)
	SSshuttle.shuttle_loading = TRUE

	// Instantiate template
	var/datum/map_template/shuttle/voidcrew/template_instance
	if(istype(template_path, /datum/map_template/shuttle/voidcrew))
		template_instance = template_path
	else if(ispath(template_path, /datum/map_template/shuttle/voidcrew))
		template_instance = new template_path()
	else
		stack_trace("create_npc_ship called with invalid template: [template_path]")
		SSshuttle.shuttle_loading = FALSE
		return null

	if(!template_instance)
		SSshuttle.shuttle_loading = FALSE
		return null

	// Create NPC ship of specified type at spawn location
	var/obj/structure/overmap/ship/npc/ship = new ship_type_path(spawn_turf)

	if(!ship || QDELETED(ship))
		SSshuttle.shuttle_loading = FALSE
		return null

	// Setup from template
	if(!ship.setup_from_template(template_instance))
		stack_trace("NPC ship failed to setup from template [template_path]")
		qdel(ship)
		SSshuttle.shuttle_loading = FALSE
		return null

	// Load the shuttle
	SSair.can_fire = FALSE
	var/obj/docking_port/mobile/voidcrew/loaded = SSshuttle.action_load(ship.source_template)
	SSair.can_fire = TRUE
	SSshuttle.shuttle_loading = FALSE

	if(!loaded)
		stack_trace("Failed to load shuttle for NPC ship [template_path]")
		qdel(ship)
		return null

	// Link ship to shuttle
	loaded.current_ship = ship
	ship.shuttle = loaded
	// Ship name comes from the subtype (e.g., "pirate vessel", "merchant vessel")

	SEND_SIGNAL(loaded, COMSIG_VOIDCREW_SHIP_LOADED)

	ship.calculate_mass()

	// Initialize the AI (this also spawns crew)
	ship.initialize_ai()

	return ship

/**
 * Admin verb to force spawn an NPC pirate ship.
 */
/client/proc/spawn_npc_ship()
	set name = "Spawn NPC Ship"
	set category = "Overmap.NPC"

	if(!check_rights(R_ADMIN))
		return

	// Let admin pick which faction to spawn
	var/list/faction_options = list(
		"Rogues (Default)" = /obj/structure/overmap/ship/npc/pirate,
		"Silverscale (Lizards)" = /obj/structure/overmap/ship/npc/pirate/silverscale,
		"Grey Tide (Assistants)" = /obj/structure/overmap/ship/npc/pirate/grey,
		"Lustrous (Ethereals)" = /obj/structure/overmap/ship/npc/pirate/lustrous,
		"Skeleton (Dutchman)" = /obj/structure/overmap/ship/npc/pirate/skeleton,
		"Interdyne (Pharma)" = /obj/structure/overmap/ship/npc/pirate/interdyne,
		"IRS (Tax Collectors)" = /obj/structure/overmap/ship/npc/pirate/irs,
		"Medieval (Knights)" = /obj/structure/overmap/ship/npc/pirate/medieval,
		"Random" = null,
	)

	var/choice = tgui_input_list(usr, "Select pirate faction to spawn:", "Spawn NPC Ship", faction_options)
	if(!choice)
		return

	var/ship_type = faction_options[choice]
	if(!ship_type)
		// Random - pick from weighted list
		ship_type = pick_weight(SSnpc_ships.ship_types)

	var/obj/structure/overmap/ship/npc/ship = SSnpc_ships.spawn_npc_ship(ship_type)
	if(ship)
		to_chat(usr, span_notice("Spawned NPC ship: [ship.name]"))
		mob.client?.admin_follow(ship.shuttle)
	else
		to_chat(usr, span_warning("Failed to spawn NPC ship. Check spawn zone availability."))

/**
 * Admin verb to toggle NPC ship spawning.
 */
/client/proc/toggle_npc_spawning()
	set name = "Toggle NPC Spawning"
	set category = "Overmap.NPC"

	if(!check_rights(R_ADMIN))
		return

	SSnpc_ships.spawning_enabled = !SSnpc_ships.spawning_enabled
	to_chat(usr, span_notice("NPC ship spawning is now [SSnpc_ships.spawning_enabled ? "ENABLED" : "DISABLED"]."))
	message_admins("[key_name_admin(usr)] [SSnpc_ships.spawning_enabled ? "enabled" : "disabled"] NPC ship spawning.")
