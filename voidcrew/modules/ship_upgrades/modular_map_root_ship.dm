/**
 * # Ship Upgrade Modular Map Root
 *
 * A custom modular_map_root that reads upgrade selections from the ship datum
 * instead of randomly picking from the TOML config.
 *
 * When placed on a ship template DMM, this marker will:
 * 1. Find the ship being loaded via SSshuttle.loading_ship
 * 2. Check if the player selected an upgrade for this slot (key)
 * 3. Load the selected upgrade module, OR load the default module for this slot
 */

/obj/modular_map_root/ship_upgrade
	name = "ship upgrade slot"
	config_file = "strings/modular_maps/ship_upgrades.toml"

/**
 * Override load_map to use ship's upgrade_selections instead of random TOML pick
 */
/obj/modular_map_root/ship_upgrade/load_map()
	var/turf/spawn_area = get_turf(src)

	log_game("SHIP_UPGRADE: load_map() called for key '[key]' at [spawn_area]")

	if(!config_file || !key)
		log_game("SHIP_UPGRADE: ERROR - missing config_file or key")
		qdel(src, force = TRUE)
		return

	// Ensure upgrade modules are registered
	ensure_ship_upgrades_initialized()
	log_game("SHIP_UPGRADE: Initialized. [length(GLOB.ship_upgrade_modules)] modules registered")

	// Find the ship - during map loading, use SSshuttle.loading_ship
	// After loading, fall back to get_ship_from_atom
	var/obj/structure/overmap/ship/ship = SSshuttle.loading_ship
	log_game("SHIP_UPGRADE: SSshuttle.loading_ship = [ship || "null"]")
	if(!ship)
		ship = get_ship_from_atom(src)
		log_game("SHIP_UPGRADE: get_ship_from_atom fallback = [ship || "null"]")

	// Determine which module to load
	var/datum/ship_upgrade_module/module_to_load

	if(ship?.upgrade_selections?[key])
		// Player selected an upgrade for this slot
		module_to_load = ship.upgrade_selections[key]
		log_game("SHIP_UPGRADE: Found selection for '[key]': [module_to_load?.id || "null"]")
	else
		// No selection - find and load the default module for this slot
		log_game("SHIP_UPGRADE: No selection for '[key]', looking for default. Ship selections: [ship?.upgrade_selections ? json_encode(ship.upgrade_selections) : "null"]")
		module_to_load = get_default_module_for_slot(key)
		log_game("SHIP_UPGRADE: Default module for '[key]': [module_to_load?.id || "null"]")

	if(!module_to_load)
		// No module to load - just clean up
		log_game("SHIP_UPGRADE: ERROR - no module found for key '[key]'")
		qdel(src, force = TRUE)
		return

	// Load the module
	log_game("SHIP_UPGRADE: Loading module '[module_to_load.id]' with map_file '[module_to_load.map_file]'")
	load_module(spawn_area, module_to_load.map_file)

/**
 * Find the default module for a given slot
 */
/obj/modular_map_root/ship_upgrade/proc/get_default_module_for_slot(slot_key)
	for(var/id in GLOB.ship_upgrade_modules)
		var/datum/ship_upgrade_module/module = GLOB.ship_upgrade_modules[id]
		if(module.slot == slot_key && module.is_default)
			return module
	return null

/**
 * Load a module DMM at the spawn area
 */
/obj/modular_map_root/ship_upgrade/proc/load_module(turf/spawn_area, map_file)
	log_game("SHIP_UPGRADE: load_module() - Reading TOML from '[config_file]'")

	var/config = rustg_read_toml_file(config_file)
	if(!config)
		log_game("SHIP_UPGRADE: ERROR - Failed to read TOML config")
		stack_trace("Failed to read ship upgrades TOML config: [config_file]")
		qdel(src, force = TRUE)
		return

	var/directory = config["directory"]
	if(!directory)
		log_game("SHIP_UPGRADE: ERROR - TOML missing 'directory' key. Config: [json_encode(config)]")
		stack_trace("Ship upgrades TOML missing 'directory' key")
		qdel(src, force = TRUE)
		return

	var/mapfile = directory + map_file
	log_game("SHIP_UPGRADE: Full map path: '[mapfile]'")

	if(!fexists(mapfile))
		log_game("SHIP_UPGRADE: ERROR - Map file does not exist: '[mapfile]'")
		qdel(src, force = TRUE)
		return

	var/datum/map_template/map_module/map = new()
	log_game("SHIP_UPGRADE: Calling map.load() at [spawn_area]")
	var/result = map.load(spawn_area, FALSE, mapfile)
	log_game("SHIP_UPGRADE: map.load() returned: [result]")

	qdel(src, force = TRUE)
