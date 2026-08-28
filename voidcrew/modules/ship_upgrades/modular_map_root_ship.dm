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
	config_file = "voidcrew/modules/ship_upgrades/ship_upgrades.toml"
	/// Cached reference to the ship - captured in Initialize before async load_map runs
	/// This is necessary because SSshuttle.loading_ship gets cleared before INVOKE_ASYNC fires
	var/obj/structure/overmap/ship/cached_ship

/**
 * Override Initialize to capture the ship reference BEFORE the async load_map call
 * The parent class uses INVOKE_ASYNC which means load_map() runs after loading_ship is cleared
 */
/obj/modular_map_root/ship_upgrade/Initialize(mapload)
	// Capture the ship reference NOW, before parent's INVOKE_ASYNC schedules load_map
	cached_ship = SSshuttle.loading_ship

	// Silence icon smoothing for the whole assembly. A hull carries up to five of these markers;
	// they are INITIALIZE_IMMEDIATE, so all five holds are taken while the HULL is still being
	// parsed, and the last one is not released until the last module has finished loading.
	//
	// Without that, the five module maps race each other through SSicon_smooth. Each module's
	// InitializeAtoms() ends in free_deferred(), which tips that module's turfs into
	// smooth_queue; the next module then starts parsing into the tiles right next door, and
	// SSicon_smooth gets a slot to run in because the map reader pops its SSatoms source before
	// every stoplag() (MAPLOADING_CHECK_TICK) - so initializing_something() reads zero depth
	// mid-parse. The freed turfs then smooth against the incoming module's brand new turfs and
	// tables, whose smoothing_groups have not been through SETUP_SMOOTHING() yet and are still
	// the raw comma-string. Indexing that string with a parsed bucket key is the "bad index"
	// runtime at code/__HELPERS/icon_smoothing.dm's cardinal scans, and because smooth_icon()
	// clears SMOOTH_QUEUED before it calls bitmask_smooth(), the aborted tile is never requeued
	// and keeps its unsmoothed "-0" state for the rest of the round.
	//
	// Tradeoff: this is a fork-side guard for an upstream race (the per-source deferral in
	// SSicon_smooth assumes one map load per tile block, which is not true here) rather than a
	// fix in the smoothing code itself. Guarding inside SMOOTH_AGAINST would mean a bitflag test
	// per neighbour in one of the hottest macros in the game, and would only downgrade the
	// runtime to a silently wrong junction, since nothing requeues the tile when its neighbour
	// finally initializes. Held here, the smoothing simply happens once the hull is whole.
	SSicon_smooth.hold_smoothing(src)

	return ..()

/obj/modular_map_root/ship_upgrade/Destroy(force)
	// Every exit from load_map() ends in qdel(src), so this is the one release point that covers
	// all of them - including the early bail-outs for a missing config, key, or module map.
	SSicon_smooth.release_smoothing(src)
	return ..()

/**
 * Override load_map to use ship's upgrade_selections instead of random TOML pick
 */
/obj/modular_map_root/ship_upgrade/load_map()
	var/turf/spawn_area = get_turf(src)

	if(!config_file || !key)
		qdel(src, force = TRUE)
		return

	// Ensure upgrade modules are registered
	ensure_ship_upgrades_initialized()

	// Use the cached ship reference (captured in Initialize before async delay)
	// Fall back to get_ship_from_atom for runtime spawning
	var/obj/structure/overmap/ship/ship = cached_ship
	if(!ship)
		ship = get_ship_from_atom(src)

	// Determine which module to load
	var/datum/ship_upgrade_module/module_to_load
	var/ship_template_type = ship?.source_template?.type

	if(ship?.upgrade_selections?[key])
		// Player selected an upgrade for this slot
		module_to_load = ship.upgrade_selections[key]
	else if(ship_template_type)
		// No selection - find and load the default module for this slot and ship
		module_to_load = get_default_module_for_ship_slot(ship_template_type, key)

	if(!module_to_load)
		// No module to load - just clean up
		qdel(src, force = TRUE)
		return

	// Load the module (pass ship theme for themed file lookup)
	load_module(spawn_area, module_to_load.map_file, ship?.theme)

/**
 * Load a module DMM at the spawn area
 * Automatically checks for themed variants based on ship's theme
 */
/obj/modular_map_root/ship_upgrade/proc/load_module(turf/spawn_area, map_file, ship_theme)
	var/config = rustg_read_toml_file(config_file)
	if(!config)
		stack_trace("Failed to read ship upgrades TOML config: [config_file]")
		qdel(src, force = TRUE)
		return

	var/directory = config["directory"]
	if(!directory)
		stack_trace("Ship upgrades TOML missing 'directory' key")
		qdel(src, force = TRUE)
		return

	// Check for themed variant if ship has a theme
	var/mapfile = directory + map_file
	if(ship_theme)
		var/themed_map_file = get_themed_filename(map_file, ship_theme)
		var/themed_mapfile = directory + themed_map_file
		if(fexists(themed_mapfile))
			mapfile = themed_mapfile

	if(!fexists(mapfile))
		qdel(src, force = TRUE)
		return

	var/datum/map_template/map_module/map = new()
	map.load(spawn_area, FALSE, mapfile)

	qdel(src, force = TRUE)

/**
 * Convert a base filename to a themed filename
 * e.g., "scarab/scarab_med_basic.dmm" + "medical" -> "scarab/scarab_med_basic_medical.dmm"
 */
/obj/modular_map_root/ship_upgrade/proc/get_themed_filename(base_file, theme)
	var/extension_pos = findtextEx(base_file, ".dmm")
	if(!extension_pos)
		return "[base_file]_[theme].dmm"
	var/base_name = copytext(base_file, 1, extension_pos)
	return "[base_name]_[theme].dmm"

/**
 * A deliberately single-faced (EAST-only) hidden layer-2 scrubber stub for module maps.
 *
 * Smart pipes node on ALL_CARDINALS at runtime, so a module-side waste stub laid one tile
 * south of a hull scrubber spine fuses with the spine when the module late-loads, forcing a
 * spine-wide pipenet rebuild that log_mapping reports as "added to a pipenet while still
 * having one" on every spine manifold (ten per Delta cryo module load). This stub only ever
 * connects east - toward the module's own layer_manifold bridge - so the module's filter
 * drain terminates in a sealed holding volume inside the module, matching the "cryotube on
 * its own sealed loop" design, and the hull spine (which carries its own nets) is never
 * touched. Classic binary pipes no longer exist upstream, hence the subtype.
 */
/obj/machinery/atmospherics/pipe/smart/simple/scrubbers/hidden/layer2/module_stub_east
	dir = EAST

/obj/machinery/atmospherics/pipe/smart/simple/scrubbers/hidden/layer2/module_stub_east/set_init_directions(init_dir)
	return ..(EAST)
