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
 */
/datum/ship_upgrade_module
	/// Unique identifier for this module (e.g., "cargo_expanded")
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

/datum/ship_upgrade_module/New()
	. = ..()
	if(id)
		GLOB.ship_upgrade_modules[id] = src

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
		// Skip abstract types (no id defined)
		if(!initial(module.id))
			continue
		new module_type()

	// Create instances of all ship_theme subtypes
	for(var/theme_type in subtypesof(/datum/ship_theme))
		var/datum/ship_theme/theme = theme_type
		// Skip abstract types (no id defined)
		if(!initial(theme.id))
			continue
		new theme_type()

	log_game("SHIP_UPGRADES: Initialized with [length(GLOB.ship_upgrade_modules)] modules and [length(GLOB.ship_themes)] themes")
