/**
 * NPC Ships Spawner Subsystem
 *
 * Manages deterministic spawning of NPC pirate ships.
 * Spawns 3 pirates at round start from a unified faction pool.
 * Any faction can spawn in any zone - the zone determines behavior:
 * - Yellow zone: scan -> lock -> interdict + siphon (economic threat)
 * - Red zone: hail -> negotiate -> boarding waves -> boss (lethal threat)
 * When a pirate is "resolved" (killed, claimed, abandoned), spawns a replacement.
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

	/// All available pirate faction types (any can spawn in any zone)
	var/list/all_factions = list(
		/obj/structure/overmap/ship/npc/pirate/skeleton,     // Dutchman
		/obj/structure/overmap/ship/npc/pirate/grey,         // Grey Tide
		/obj/structure/overmap/ship/npc/pirate/medieval,     // Medieval
		/obj/structure/overmap/ship/npc/pirate/lustrous,     // Geode
		/obj/structure/overmap/ship/npc/pirate/silverscale,  // Silverscale
		/obj/structure/overmap/ship/npc/pirate/irs,          // IRS
		/obj/structure/overmap/ship/npc/pirate/interdyne,    // Interdyne
	)

	/// Currently active faction types
	var/list/active_faction_types = list()

	/// Target number of active pirates
	var/pirate_count_target = 4

	/// Whether initial spawning is complete
	var/initialized_pirates = FALSE

/datum/controller/subsystem/npc_ships/Initialize()
	log_world("SSnpc_ships: Initializing with [length(all_factions)] factions, target [pirate_count_target] pirates")
	// SSshuttle is listed as a dependency, so it's guaranteed to be ready
	initialize_pirates()
	return SS_INIT_SUCCESS

/**
 * Spawns the initial set of pirates at round start.
 * Picks random unique factions, distributed evenly across zones.
 * Ensures each zone gets at least one pirate before any zone gets a second.
 */
/datum/controller/subsystem/npc_ships/proc/initialize_pirates()
	if(initialized_pirates)
		return

	log_world("SSnpc_ships: Spawning initial pirates...")

	// Pick random unique factions
	var/list/available = all_factions.Copy()

	// Build zone assignments: distribute evenly across RED and YELLOW
	var/list/spawn_zones = list(ZONE_RED, ZONE_YELLOW)
	var/list/zone_assignments = list()
	for(var/i in 1 to pirate_count_target)
		// Cycle through zones: 1->RED, 2->YELLOW, 3->RED, 4->YELLOW, etc.
		var/zone_index = ((i - 1) % length(spawn_zones)) + 1
		zone_assignments += spawn_zones[zone_index]

	// Shuffle zone assignments so it's not always RED first
	for(var/i in length(zone_assignments) to 2 step -1)
		var/j = rand(1, i)
		var/temp = zone_assignments[i]
		zone_assignments[i] = zone_assignments[j]
		zone_assignments[j] = temp

	for(var/i in 1 to pirate_count_target)
		if(!length(available))
			break
		var/faction_type = pick_n_take(available)
		spawn_pirate(faction_type, zone_assignments[i])

	initialized_pirates = TRUE
	log_world("SSnpc_ships: Initial spawn complete. [length(active_ships)] pirates active.")

/**
 * Called when a pirate is "resolved" (killed, claimed, abandoned, etc.)
 * Spawns a replacement from an unused faction in the same zone.
 * @param resolved_type The type path of the resolved pirate ship
 * @param resolved_zone_type The zone type the resolved ship was in (ZONE_YELLOW, ZONE_RED, or null)
 */
/datum/controller/subsystem/npc_ships/proc/on_pirate_resolved(resolved_type, resolved_zone_type)
	if(!initialized_pirates)
		return  // Don't replace during initialization

	// Remove from active tracking
	active_faction_types -= resolved_type

	// Spawn replacement in same zone
	spawn_replacement(resolved_zone_type)

/**
 * Spawns a replacement pirate.
 * Prefers factions not currently active. Spawns in specified zone.
 * @param target_zone_type The zone type to spawn in (null = any zone)
 */
/datum/controller/subsystem/npc_ships/proc/spawn_replacement(target_zone_type)
	// Check if we're at capacity
	if(length(active_faction_types) >= pirate_count_target)
		return

	// Get factions not currently active
	var/list/available = all_factions - active_faction_types

	// If all factions are active, pick any faction
	if(!length(available))
		available = all_factions.Copy()

	var/faction_type = pick(available)
	spawn_pirate(faction_type, target_zone_type)
	log_world("SSnpc_ships: Spawned replacement pirate: [faction_type] in zone [target_zone_type]")

/**
 * Spawns a pirate of the specified type.
 * @param ship_type_path The ship type to spawn
 * @param target_zone_type The zone type to spawn in (null = any zone)
 * @return The spawned ship or null on failure
 */
/datum/controller/subsystem/npc_ships/proc/spawn_pirate(ship_type_path, target_zone_type)
	var/obj/structure/overmap/ship/npc/ship = spawn_npc_ship(ship_type_path, target_zone_type)
	if(!ship)
		log_world("SSnpc_ships: Failed to spawn pirate of type [ship_type_path]")
		return null

	// Track in active faction list
	active_faction_types += ship_type_path

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
 * Any faction can spawn in any zone - zone determines behavior.
 */
/datum/controller/subsystem/npc_ships/proc/get_spawn_zones_for_type(ship_type_path)
	return list(ZONE_YELLOW, ZONE_RED)

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
 * @param target_zone_type Specific zone type to spawn in (null = use get_spawn_zones_for_type)
 * @return The spawned ship or null on failure
 */
/datum/controller/subsystem/npc_ships/proc/spawn_npc_ship(ship_type_path, target_zone_type)
	var/template_path = initial(ship_type_path:shuttle_template)
	if(!template_path)
		log_world("SSnpc_ships: No shuttle_template defined for [ship_type_path]")
		return null

	var/list/spawn_zones
	if(target_zone_type)
		spawn_zones = list(target_zone_type)
	else
		spawn_zones = get_spawn_zones_for_type(ship_type_path)
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
	lines += "Active ships: [length(SSnpc_ships.active_ships)]/[SSnpc_ships.pirate_count_target]"
	lines += ""
	lines += "Active Factions:"
	for(var/faction in SSnpc_ships.active_faction_types)
		lines += "  - [faction]"
	lines += ""
	lines += "All Active Ships:"
	for(var/obj/structure/overmap/ship/npc/ship in SSnpc_ships.active_ships)
		var/datum/ai_controller/npc_ship/controller = ship.ai_controller
		var/obj/structure/overmap/ship/target = controller?.get_target()
		var/combat_state = controller?.blackboard[BB_NPC_COMBAT_STATE] || "none"
		var/turf/ship_turf = get_turf(ship)
		var/datum/overmap_zone/ship_zone = SSovermap_zones.get_zone(ship_turf)
		var/zone_name = ship_zone?.zone_type || "unknown"
		lines += "  - [ship.name] at ([ship.x], [ship.y], z=[ship.z]) [zone_name] zone"
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
