/**
 * NPC Ships Spawner Subsystem
 *
 * Manages deterministic spawning of NPC pirate ships.
 * Spawns 3 pirates at round start: 2 light-threat (yellow zone) + 1 heavy-threat (red zone).
 * When a pirate is "resolved" (killed, claimed, abandoned), spawns a replacement from same tier.
 */
SUBSYSTEM_DEF(npc_ships)
	name = "NPC Ships"
	init_order = INIT_ORDER_OVERMAP + 2 // After SSovermap and SSovermap_zones
	flags = SS_NO_FIRE  // No periodic firing - we spawn on events
	runlevels = RUNLEVEL_GAME
	dependencies = list(
		/datum/controller/subsystem/shuttle,  // Need SSshuttle to load ship templates
		/datum/controller/subsystem/overmap_zones,  // Need zones for spawn locations
	)

	/// List of currently active NPC ships
	var/list/obj/structure/overmap/ship/npc/active_ships = list()

	/// Light-threat faction types (spawn in yellow zones)
	var/list/light_factions = list(
		/obj/structure/overmap/ship/npc/pirate/skeleton,   // Dutchman
		/obj/structure/overmap/ship/npc/pirate/grey,
		/obj/structure/overmap/ship/npc/pirate/medieval,
		/obj/structure/overmap/ship/npc/pirate/lustrous,   // Geode
	)

	/// Heavy-threat faction types (spawn in red zones)
	var/list/heavy_factions = list(
		/obj/structure/overmap/ship/npc/pirate/silverscale,
		/obj/structure/overmap/ship/npc/pirate,           // Rogues
		/obj/structure/overmap/ship/npc/pirate/irs,
		/obj/structure/overmap/ship/npc/pirate/interdyne,
	)

	/// Currently active light-threat faction types
	var/list/active_light_types = list()

	/// Currently active heavy-threat faction types
	var/list/active_heavy_types = list()

	/// Target counts for each tier
	var/light_count_target = 2
	var/heavy_count_target = 1

	/// Whether initial spawning is complete
	var/initialized_pirates = FALSE

/datum/controller/subsystem/npc_ships/Initialize()
	log_world("SSnpc_ships: Initializing with [length(light_factions)] light factions, [length(heavy_factions)] heavy factions")
	// SSshuttle is listed as a dependency, so it's guaranteed to be ready
	initialize_pirates()
	return SS_INIT_SUCCESS

/**
 * Spawns the initial set of pirates at round start.
 * 2 light-threat + 1 heavy-threat, no duplicate factions.
 */
/datum/controller/subsystem/npc_ships/proc/initialize_pirates()
	if(initialized_pirates)
		return

	log_world("SSnpc_ships: Spawning initial pirates...")

	// Spawn 2 light-threat pirates (pick 2 random factions)
	var/list/available_light = light_factions.Copy()
	for(var/i in 1 to light_count_target)
		if(!length(available_light))
			break
		var/faction_type = pick_n_take(available_light)
		spawn_pirate(faction_type)

	// Spawn 1 heavy-threat pirate
	var/list/available_heavy = heavy_factions.Copy()
	for(var/i in 1 to heavy_count_target)
		if(!length(available_heavy))
			break
		var/faction_type = pick_n_take(available_heavy)
		spawn_pirate(faction_type)

	initialized_pirates = TRUE
	log_world("SSnpc_ships: Initial spawn complete. [length(active_ships)] pirates active.")

/**
 * Called when a pirate is "resolved" (killed, claimed, abandoned, etc.)
 * Spawns a replacement from the same tier.
 * @param resolved_type The type path of the resolved pirate ship
 */
/datum/controller/subsystem/npc_ships/proc/on_pirate_resolved(resolved_type)
	if(!initialized_pirates)
		return  // Don't replace during initialization

	// Remove from active tracking
	active_light_types -= resolved_type
	active_heavy_types -= resolved_type

	// Determine which tier and spawn replacement
	var/is_heavy = (resolved_type in heavy_factions)

	if(is_heavy)
		spawn_replacement_heavy()
	else
		spawn_replacement_light()

/**
 * Spawns a replacement light-threat pirate.
 * Prefers factions not currently active.
 */
/datum/controller/subsystem/npc_ships/proc/spawn_replacement_light()
	// Check if we're at capacity
	if(length(active_light_types) >= light_count_target)
		return

	// Get factions not currently active
	var/list/available = light_factions - active_light_types

	// If all factions are active, pick any light faction
	if(!length(available))
		available = light_factions.Copy()

	var/faction_type = pick(available)
	spawn_pirate(faction_type)
	log_world("SSnpc_ships: Spawned replacement light pirate: [faction_type]")

/**
 * Spawns a replacement heavy-threat pirate.
 * Prefers factions not currently active.
 */
/datum/controller/subsystem/npc_ships/proc/spawn_replacement_heavy()
	// Check if we're at capacity
	if(length(active_heavy_types) >= heavy_count_target)
		return

	// Get factions not currently active
	var/list/available = heavy_factions - active_heavy_types

	// If all factions are active, pick any heavy faction
	if(!length(available))
		available = heavy_factions.Copy()

	var/faction_type = pick(available)
	spawn_pirate(faction_type)
	log_world("SSnpc_ships: Spawned replacement heavy pirate: [faction_type]")

/**
 * Spawns a pirate of the specified type.
 * @param ship_type_path The ship type to spawn
 * @return The spawned ship or null on failure
 */
/datum/controller/subsystem/npc_ships/proc/spawn_pirate(ship_type_path)
	var/obj/structure/overmap/ship/npc/ship = spawn_npc_ship(ship_type_path)
	if(!ship)
		log_world("SSnpc_ships: Failed to spawn pirate of type [ship_type_path]")
		return null

	// Track in appropriate tier list
	if(ship_type_path in heavy_factions)
		active_heavy_types += ship_type_path
	else
		active_light_types += ship_type_path

	// Notify bounty subsystem to create a bounty for this pirate
	SSbounty?.on_pirate_spawned(ship)

	return ship

/**
 * Removes a ship from tracking (called when ship is deleted).
 */
/datum/controller/subsystem/npc_ships/proc/untrack_ship(obj/structure/overmap/ship/npc/ship)
	active_ships -= ship

/**
 * Gets all active ships of a specific faction type.
 * @param faction_type The faction type path to filter by
 * @return List of matching ships
 */
/datum/controller/subsystem/npc_ships/proc/get_ships_by_faction(faction_type)
	var/list/result = list()
	for(var/obj/structure/overmap/ship/npc/ship in active_ships)
		if(istype(ship, faction_type))
			result += ship
	return result

/**
 * Gets the spawn zones for a ship type.
 * Light-threat = yellow zones, Heavy-threat = red zones.
 */
/datum/controller/subsystem/npc_ships/proc/get_spawn_zones_for_type(ship_type_path)
	if(ship_type_path in heavy_factions)
		return list(ZONE_RED)
	return list(ZONE_YELLOW)

/**
 * Finds a valid spawn turf for an NPC ship.
 * @param spawn_zones List of zone types to spawn in
 */
/datum/controller/subsystem/npc_ships/proc/get_spawn_turf(list/spawn_zones)
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
		var/too_close = FALSE
		for(var/obj/structure/overmap/ship/ship in range(5, T))
			if(istype(ship, /obj/structure/overmap/ship/npc))
				continue
			too_close = TRUE
			break

		if(locate(/obj/structure/overmap) in T)
			continue

		if(!too_close)
			safe_turfs += T

	if(!length(safe_turfs))
		return null

	return pick(safe_turfs)

/**
 * Spawns a new NPC ship in a valid zone.
 * @param ship_type_path The ship type to spawn
 * @return The spawned ship or null on failure
 */
/datum/controller/subsystem/npc_ships/proc/spawn_npc_ship(ship_type_path)
	var/template_path = initial(ship_type_path:shuttle_template)
	if(!template_path)
		log_world("SSnpc_ships: No shuttle_template defined for [ship_type_path]")
		return null

	var/list/spawn_zones = get_spawn_zones_for_type(ship_type_path)
	if(!length(spawn_zones))
		return null

	var/turf/spawn_turf = get_spawn_turf(spawn_zones)
	if(!spawn_turf)
		log_world("SSnpc_ships: No valid spawn turf found for [ship_type_path]")
		return null

	var/obj/structure/overmap/ship/npc/ship = create_npc_ship(template_path, spawn_turf, ship_type_path)
	if(!ship)
		return null

	active_ships += ship
	log_world("SSnpc_ships: Spawned [ship.name] at ([spawn_turf.x], [spawn_turf.y])")

	return ship

/**
 * Creates an NPC ship from a template at the specified location.
 * @param template_path The shuttle template to use
 * @param spawn_turf Where to spawn the ship
 * @param ship_type_path The ship type path
 */
/datum/controller/subsystem/npc_ships/proc/create_npc_ship(template_path, turf/spawn_turf, ship_type_path)
	UNTIL(!SSshuttle.shuttle_loading)
	SSshuttle.shuttle_loading = TRUE

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

	var/obj/structure/overmap/ship/npc/ship = new ship_type_path(spawn_turf)

	if(!ship || QDELETED(ship))
		SSshuttle.shuttle_loading = FALSE
		return null

	if(!ship.setup_from_template(template_instance))
		stack_trace("NPC ship failed to setup from template [template_path]")
		qdel(ship)
		SSshuttle.shuttle_loading = FALSE
		return null

	SSair.can_fire = FALSE
	var/obj/docking_port/mobile/voidcrew/loaded = SSshuttle.action_load(ship.source_template)
	SSair.can_fire = TRUE
	SSshuttle.shuttle_loading = FALSE

	if(!loaded)
		stack_trace("Failed to load shuttle for NPC ship [template_path]")
		qdel(ship)
		return null

	loaded.current_ship = ship
	ship.shuttle = loaded

	SEND_SIGNAL(loaded, COMSIG_VOIDCREW_SHIP_LOADED)

	ship.calculate_mass()
	ship.initialize_ai()

	return ship

// ========== ADMIN VERBS ==========

/**
 * Admin verb to force spawn an NPC pirate ship.
 */
/client/proc/spawn_npc_ship()
	set name = "Spawn NPC Ship"
	set category = "Overmap.NPC"

	if(!check_rights(R_ADMIN))
		return

	var/list/faction_options = list(
		"Rogues (Default)" = /obj/structure/overmap/ship/npc/pirate,
		"Silverscale (Lizards)" = /obj/structure/overmap/ship/npc/pirate/silverscale,
		"Grey Tide (Assistants)" = /obj/structure/overmap/ship/npc/pirate/grey,
		"Lustrous (Ethereals)" = /obj/structure/overmap/ship/npc/pirate/lustrous,
		"Skeleton (Dutchman)" = /obj/structure/overmap/ship/npc/pirate/skeleton,
		"Interdyne (Pharma)" = /obj/structure/overmap/ship/npc/pirate/interdyne,
		"IRS (Tax Collectors)" = /obj/structure/overmap/ship/npc/pirate/irs,
		"Medieval (Knights)" = /obj/structure/overmap/ship/npc/pirate/medieval,
	)

	var/choice = tgui_input_list(usr, "Select pirate faction to spawn:", "Spawn NPC Ship", faction_options)
	if(!choice)
		return

	var/ship_type = faction_options[choice]
	var/obj/structure/overmap/ship/npc/ship = SSnpc_ships.spawn_pirate(ship_type)
	if(ship)
		to_chat(usr, span_notice("Spawned NPC ship: [ship.name]"))
		mob.client?.admin_follow(ship.shuttle)
	else
		to_chat(usr, span_warning("Failed to spawn NPC ship. Check spawn zone availability."))

/**
 * Admin verb to view NPC ship status.
 */
/client/proc/npc_ship_status()
	set name = "NPC Ship Status"
	set category = "Overmap.NPC"

	if(!check_rights(R_ADMIN))
		return

	var/list/lines = list()
	lines += "=== NPC Ship Status ==="
	lines += "Active ships: [length(SSnpc_ships.active_ships)]"
	lines += "Light types active: [length(SSnpc_ships.active_light_types)]/[SSnpc_ships.light_count_target]"
	lines += "Heavy types active: [length(SSnpc_ships.active_heavy_types)]/[SSnpc_ships.heavy_count_target]"
	lines += ""
	lines += "Active Light Factions:"
	for(var/faction in SSnpc_ships.active_light_types)
		lines += "  - [faction]"
	lines += ""
	lines += "Active Heavy Factions:"
	for(var/faction in SSnpc_ships.active_heavy_types)
		lines += "  - [faction]"
	lines += ""
	lines += "All Active Ships:"
	for(var/obj/structure/overmap/ship/npc/ship in SSnpc_ships.active_ships)
		var/datum/ai_controller/npc_ship/controller = ship.ai_controller
		var/obj/structure/overmap/ship/target = controller?.get_target()
		var/combat_state = controller?.blackboard[BB_NPC_COMBAT_STATE] || "none"
		lines += "  - [ship.name] at ([ship.x], [ship.y], z=[ship.z])"
		lines += "      State: [combat_state], Target: [target?.name || "none"]"
		lines += "      Territory: [ship.territory_range] tiles"

	// Also show player ships for distance comparison
	lines += ""
	lines += "Player Ships:"
	for(var/obj/structure/overmap/ship/player_ship in SSovermap.simulated_ships)
		if(istype(player_ship, /obj/structure/overmap/ship/npc))
			continue
		lines += "  - [player_ship.name] at ([player_ship.x], [player_ship.y], z=[player_ship.z])"
		// Show distance to each pirate
		for(var/obj/structure/overmap/ship/npc/pirate in SSnpc_ships.active_ships)
			var/dist = get_dist(pirate, player_ship)
			lines += "      -> [pirate.name]: [dist] tiles away"

	to_chat(usr, lines.Join("\n"))
