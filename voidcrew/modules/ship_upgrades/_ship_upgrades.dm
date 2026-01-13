/**
 * # Ship Upgrade System
 *
 * This system allows ships to have modular upgrade slots that can be customized
 * at spawn time. Base ship templates have upgrade slot markers, and players can
 * select which modules load into those slots.
 *
 * Three-tier system:
 * 1. Base templates - Default ship layout with upgrade slot markers
 * 2. Themes - Alternative aesthetics/layouts (replaces base sections)
 * 3. Upgrades - Optional modules overlaid on base OR themed ships
 */

/// Global list of all registered ship upgrade modules (id -> /datum/ship_upgrade_module)
GLOBAL_LIST_EMPTY(ship_upgrade_modules)

/// Global list of all registered ship themes (id -> /datum/ship_theme)
GLOBAL_LIST_EMPTY(ship_themes)

/**
 * Ship Upgrade Module
 *
 * Represents a single upgrade option for a specific slot on a ship.
 * Each slot can have multiple modules to choose from.
 *
 * Modules are organized by ship template - each ship class has its own set of modules.
 * This allows multiple ships to have modules with the same display name (e.g., "Basic Cargo Bay")
 * without conflicting.
 */
/datum/ship_upgrade_module
	/// Unique identifier for this module within its ship class (e.g., "cargo_expanded")
	var/id
	/// Display name shown in UI
	var/name = "Unnamed Module"
	/// Description shown in UI
	var/desc = "A ship module."
	/// Which slot this module fits into (e.g., "cargobay", "medbay", "engineroom")
	var/slot
	/// DMM filename for this module (loaded from the TOML directory)
	var/map_file
	/// Cost in parts to select this module: list(PART_CLASS_TRADE = 1, PART_CLASS_COMBAT = 2)
	var/list/part_cost
	/// Optional icon state for preview in UI
	var/preview_icon
	/// If TRUE, this module loads when no upgrade is selected for this slot
	var/is_default = FALSE
	/// The BASE ship template type this module is for (e.g., /datum/map_template/shuttle/voidcrew/test_modular)
	/// Themed variants inherit from base, so only specify the base type.
	var/for_ship

/datum/ship_upgrade_module/New()
	. = ..()
	if(id && for_ship)
		// Register under ship type, then by id
		if(!GLOB.ship_upgrade_modules[for_ship])
			GLOB.ship_upgrade_modules[for_ship] = list()
		GLOB.ship_upgrade_modules[for_ship][id] = src

/**
 * Ship Theme
 *
 * Represents a complete aesthetic/layout alternative for a ship class.
 * Themes replace the base template with a themed variant that has the
 * same upgrade slots.
 */
/datum/ship_theme
	/// Unique identifier for this theme (e.g., "pirate", "science")
	var/id
	/// Display name shown in UI
	var/name = "Unnamed Theme"
	/// Description shown in UI
	var/desc = "A ship theme."
	/// Suffix appended to base template name to get themed template (e.g., "_pirate")
	var/template_suffix
	/// Cost in parts to select this theme
	var/list/part_cost

/datum/ship_theme/New()
	. = ..()
	if(id)
		GLOB.ship_themes[id] = src

/// Flag to track if ship upgrades have been initialized
GLOBAL_VAR_INIT(ship_upgrades_initialized, FALSE)

/**
 * Ensure ship upgrade system is initialized (lazy init pattern)
 *
 * Called before accessing ship upgrades to ensure all modules and themes are registered.
 */
/proc/ensure_ship_upgrades_initialized()
	if(GLOB.ship_upgrades_initialized)
		return
	GLOB.ship_upgrades_initialized = TRUE

	// Create instances of all ship_upgrade_module subtypes
	for(var/module_type in subtypesof(/datum/ship_upgrade_module))
		var/datum/ship_upgrade_module/module = module_type
		// Skip abstract types (no id or for_ship defined)
		if(!initial(module.id) || !initial(module.for_ship))
			continue
		new module_type()

	// Create instances of all ship_theme subtypes
	for(var/theme_type in subtypesof(/datum/ship_theme))
		var/datum/ship_theme/theme = theme_type
		// Skip abstract types (no id defined)
		if(!initial(theme.id))
			continue
		new theme_type()

/**
 * Get all modules registered for a specific ship template type
 * Handles inheritance - if template is a subtype (themed variant), checks parent types too
 *
 * Returns: assoc list of module_id -> /datum/ship_upgrade_module
 */
/proc/get_modules_for_ship(ship_template_type)
	ensure_ship_upgrades_initialized()

	// Check the exact type first
	if(GLOB.ship_upgrade_modules[ship_template_type])
		return GLOB.ship_upgrade_modules[ship_template_type]

	// For themed variants, walk up the parent chain to find the base ship's modules
	var/check_type = ship_template_type
	while(check_type && check_type != /datum/map_template/shuttle/voidcrew)
		if(GLOB.ship_upgrade_modules[check_type])
			return GLOB.ship_upgrade_modules[check_type]
		check_type = type2parent(check_type)

	return list()

/**
 * Get the default module for a slot on a specific ship
 */
/proc/get_default_module_for_ship_slot(ship_template_type, slot_key)
	var/list/modules = get_modules_for_ship(ship_template_type)
	for(var/module_id in modules)
		var/datum/ship_upgrade_module/module = modules[module_id]
		if(module.slot == slot_key && module.is_default)
			return module
	return null
