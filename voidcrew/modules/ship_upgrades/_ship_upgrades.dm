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

/// Global list of all registered ship upgrade modules: ship_type -> (module_id -> /datum/ship_upgrade_module)
GLOBAL_LIST_EMPTY(ship_upgrade_modules)

/// Global list of all registered ship themes: ship_type -> (theme_id -> /datum/ship_theme)
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
	/// Which theme(s) this module is available for. REQUIRED for themed ships.
	/// Can be a single string (e.g., "medical") or a list (e.g., list("medical", "syndicate"))
	/// Modules without for_theme won't appear in the upgrade selector for themed ships.
	var/for_theme

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
 * Represents a complete configuration variant for a ship class.
 * Themes define job slots, upgrade slots, and which DMM to load.
 * Players can unlock and select themes when spawning a ship.
 */
/datum/ship_theme
	/// Unique identifier for this theme (e.g., "medical", "syndicate")
	var/id
	/// Display name shown in UI
	var/name = "Unnamed Theme"
	/// Description shown in UI
	var/desc = "A ship theme."
	/// The ship template type this theme is for
	var/for_ship
	/// Suffix for the DMM file (e.g., "scarab_a" loads ship_scarab_a.dmm)
	var/template_suffix
	/// Cost in parts to unlock this theme: list(PART_CLASS_SCIENCE = 1)
	/// If null or empty, theme is free (but may still need ship unlock first)
	var/list/part_cost
	/// If TRUE, this theme is free and pre-selected for new ship owners
	var/is_default = FALSE
	/// Theme-specific upgrade slot IDs. If null, uses ship's default upgrade_slot_ids.
	var/list/upgrade_slot_ids
	/// Theme-specific job slots. Required for themes with unique crews.
	var/list/job_slots

/datum/ship_theme/New()
	. = ..()
	if(id && for_ship)
		// Register under ship type, then by id
		if(!GLOB.ship_themes[for_ship])
			GLOB.ship_themes[for_ship] = list()
		GLOB.ship_themes[for_ship][id] = src

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
		// Skip abstract types (no id or for_ship defined)
		if(!initial(theme.id) || !initial(theme.for_ship))
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

/**
 * Get all themes registered for a specific ship template type
 *
 * Returns: assoc list of theme_id -> /datum/ship_theme
 */
/proc/get_themes_for_ship(ship_template_type)
	ensure_ship_upgrades_initialized()

	// Check the exact type first
	if(GLOB.ship_themes[ship_template_type])
		return GLOB.ship_themes[ship_template_type]

	// For subtypes, walk up the parent chain to find themes
	var/check_type = ship_template_type
	while(check_type && check_type != /datum/map_template/shuttle/voidcrew)
		if(GLOB.ship_themes[check_type])
			return GLOB.ship_themes[check_type]
		check_type = type2parent(check_type)

	return list()

/**
 * Get the default theme for a ship template type
 *
 * Returns: /datum/ship_theme or null
 */
/proc/get_default_theme_for_ship(ship_template_type)
	var/list/themes = get_themes_for_ship(ship_template_type)
	for(var/theme_id in themes)
		var/datum/ship_theme/theme = themes[theme_id]
		if(theme.is_default)
			return theme
	// If no default marked, return first theme
	// (In DM, themes[1] gets the first key, themes[key] gets the value)
	if(length(themes))
		var/first_theme_id = themes[1]
		return themes[first_theme_id]
	return null

/**
 * Get modules for a ship filtered by theme
 *
 * For themed ships (theme_id provided): Returns only modules with matching for_theme
 * For non-themed ships (theme_id null): Returns modules WITHOUT for_theme set
 *
 * Returns: assoc list of module_id -> /datum/ship_upgrade_module
 */
/proc/get_modules_for_ship_theme(ship_template_type, theme_id)
	var/list/all_modules = get_modules_for_ship(ship_template_type)

	var/list/filtered = list()
	for(var/module_id in all_modules)
		var/datum/ship_upgrade_module/module = all_modules[module_id]
		if(theme_id)
			// Themed ship: only modules that match this theme
			if(is_module_available_for_theme(module, theme_id))
				filtered[module_id] = module
		else
			// Non-themed ship: only modules without for_theme
			if(!module.for_theme)
				filtered[module_id] = module

	return filtered

/**
 * Check if a module is available for a specific theme
 *
 * Modules MUST have for_theme set to appear for themed ships.
 * for_theme can be a single string or a list of theme IDs.
 */
/proc/is_module_available_for_theme(datum/ship_upgrade_module/module, theme_id)
	if(!module)
		return FALSE
	// No theme specified = module doesn't appear for themed ships
	if(!module.for_theme)
		return FALSE
	// Check if for_theme is a list
	if(islist(module.for_theme))
		return (theme_id in module.for_theme)
	// Single theme string
	return (module.for_theme == theme_id)
