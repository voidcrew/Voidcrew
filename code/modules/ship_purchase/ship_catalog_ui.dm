/**
 * Ship Catalog UI Backend
 *
 * TGUI interface for browsing and purchasing ship blueprints.
 * Displays all available ships with preview images, crew capacity,
 * unlock costs, and purchase functionality.
 *
 * Usage:
 *   var/datum/ship_catalog_ui/catalog = new(usr)
 *   catalog.ui_interact(usr)
 */

/// Global list of all ship templates for the catalog
GLOBAL_LIST_EMPTY(ship_catalog_templates)

/// Flag to track if catalog has been initialized
GLOBAL_VAR_INIT(ship_catalog_initialized, FALSE)

/// Proc to initialize ship catalog (called lazily on first access)
/proc/ensure_ship_catalog_initialized()
	if(GLOB.ship_catalog_initialized)
		return
	GLOB.ship_catalog_initialized = TRUE

	// Build ship catalog from all voidcrew shuttle templates
	for(var/shuttle_id in SSmapping.shuttle_templates)
		var/datum/map_template/shuttle/voidcrew/template = SSmapping.shuttle_templates[shuttle_id]

		// Only include voidcrew ships (player-selectable ships)
		if(!istype(template))
			continue

		// Skip abstract types
		if(template.abstract && template.type == template.abstract)
			continue

		GLOB.ship_catalog_templates += template

	log_game("SHIP_CATALOG: Initialized with [length(GLOB.ship_catalog_templates)] ships")

/// Find a ship template by its type path string
/proc/find_ship_template_by_type(type_path)
	ensure_ship_catalog_initialized()
	for(var/datum/map_template/shuttle/voidcrew/template as anything in GLOB.ship_catalog_templates)
		if("[template.type]" == type_path)
			return template
	return null

/**
 * Ship Catalog UI Datum
 *
 * Provides TGUI interface for ship browsing and purchasing.
 * Accessible from character creation or in-game admin panel.
 */
/datum/ship_catalog_ui
	/// Reference to the user viewing the catalog
	var/mob/user

	/// Selected ship filter (by faction)
	var/selected_faction = null

	/// Search query for filtering ships
	var/search_query = ""

	/// Optional callback when player selects a ship (for latejoin integration)
	var/datum/callback/on_ship_selected

	/// Flag to indicate if this is in latejoin mode vs browse mode
	var/latejoin_mode = FALSE

/datum/ship_catalog_ui/New(mob/viewing_user, latejoin = FALSE, datum/callback/selection_callback = null)
	. = ..()
	user = viewing_user
	latejoin_mode = latejoin
	on_ship_selected = selection_callback

/datum/ship_catalog_ui/Destroy()
	user = null
	return ..()

/**
 * Open the ship catalog UI for a user
 */
/datum/ship_catalog_ui/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipCatalog", "Ship Catalog")
		ui.open()

/**
 * UI state - accessible anytime (character creation, lobby, in-game)
 */
/datum/ship_catalog_ui/ui_state(mob/user)
	return GLOB.always_state

/**
 * Static data - ship catalog that doesn't change
 * Sent once when UI opens
 */
/datum/ship_catalog_ui/ui_static_data(mob/user)
	var/list/data = list()

	// Ensure catalog is initialized
	ensure_ship_catalog_initialized()
	// Also ensure ship upgrades/themes are initialized for themed ships
	ensure_ship_upgrades_initialized()

	// Build ship catalog
	var/list/ships = list()

	for(var/datum/map_template/shuttle/voidcrew/template as anything in GLOB.ship_catalog_templates)
		// Get job slots - either from template directly or from default theme
		var/list/job_slots_to_use = template.job_slots
		var/theme_count = 0

		// If ship has available_themes, get job slots from the default theme
		if(length(template.available_themes))
			theme_count = length(template.available_themes)
			var/datum/ship_theme/default_theme = get_default_theme_for_ship(template.type)
			if(default_theme?.job_slots)
				job_slots_to_use = default_theme.job_slots

		// Calculate crew capacity from job slots
		var/crew_capacity = 0
		for(var/list/job_definition in job_slots_to_use)
			crew_capacity += job_definition["slots"]

		// Build parts requirement list from template's class-based requirements
		var/list/parts_required = list()
		var/total_parts = 0
		for(var/part_class in GLOB.ship_part_classes)
			var/count = template.part_requirements[part_class] || 0
			if(count > 0)
				parts_required[part_class] = count
				total_parts += count

		// Determine primary class (the one with most requirements, for display/filtering)
		var/primary_class = "misc"
		var/max_count = 0
		for(var/part_class in template.part_requirements)
			var/count = template.part_requirements[part_class] || 0
			if(count > max_count)
				max_count = count
				primary_class = part_class

		// If no parts required, it's free
		if(total_parts == 0)
			primary_class = "free"

		// Faction (default to neutral - faction system not yet implemented on ships)
		var/faction = FACTION_NEUTRAL

		// Build job list for display
		var/list/jobs = list()
		for(var/list/job_definition in job_slots_to_use)
			jobs += list(list(
				"name" = job_definition["name"],
				"slots" = job_definition["slots"],
				"officer" = job_definition["officer"] ? TRUE : FALSE
			))

		ships += list(list(
			"id" = template.type,
			"name" = template.name,
			"short_name" = template.short_name || template.name,
			"suffix" = template.suffix,
			"description" = generate_ship_description(template),
			"crew_capacity" = crew_capacity,
			"total_parts" = total_parts,
			"primary_class" = primary_class,
			"parts_required" = parts_required,
			"faction" = faction,
			"preview_image" = get_ship_preview_path(template),
			"jobs" = jobs,
			"theme_count" = theme_count,
			"has_upgrades" = template.has_upgrade_slots
		))

	data["ships"] = ships

	// Available factions for filtering (these are defined in voidcrew but need fallbacks here)
	var/list/factions = list(
		"Neutral",
		"Syndicate",
		"Nanotrasen"
	)
	data["factions"] = factions

	return data

/**
 * Dynamic data - player's credits, parts, and unlocked ships
 * Updates on every UI refresh
 */
/datum/ship_catalog_ui/ui_data(mob/user)
	var/list/data = list()

	if(!user || !user.client)
		return data

	var/ckey = user.client.ckey

	// Get player's current credits (account-wide)
	data["credits"] = GLOB.ship_economy_db?.get_credits(ckey) || 0

	// Get player's parts inventory (account-wide) - now class-based
	var/list/parts = GLOB.ship_economy_db?.get_parts(ckey)
	if(!parts)
		parts = list()
		for(var/part_class in GLOB.ship_part_classes)
			parts[part_class] = 0
	data["parts"] = parts

	// Get list of unlocked ships
	var/list/unlocked_ships = GLOB.ship_economy_db?.get_unlocked_ships(ckey) || list()
	data["unlocked_ships"] = unlocked_ships

	// Current filters
	data["selected_faction"] = selected_faction
	data["search_query"] = search_query

	// Latejoin mode flag
	data["latejoin_mode"] = latejoin_mode

	return data

/**
 * Handle UI actions (unlock ship, filter, search)
 */
/datum/ship_catalog_ui/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return TRUE

	. = TRUE

	switch(action)
		if("unlock_ship")
			var/ship_id = params["ship_id"]
			if(!ship_id)
				return FALSE

			// Find the ship template by type path
			var/datum/map_template/shuttle/voidcrew/template = find_ship_template_by_type(ship_id)
			if(!template)
				to_chat(user, span_warning("Invalid ship template."))
				return FALSE

			// Attempt to unlock
			if(attempt_ship_unlock(user, template))
				to_chat(user, span_notice("Successfully unlocked [template.name]!"))
				// Update UI data
				SStgui.update_uis(src)
			else
				// Error messages handled in attempt_ship_unlock
				return FALSE

		if("set_faction_filter")
			selected_faction = params["faction"]
			if(selected_faction == "all")
				selected_faction = null

		if("set_search")
			search_query = params["query"] || ""

		if("clear_filters")
			selected_faction = null
			search_query = ""

		if("spawn_ship")
			// Admin-only action to immediately spawn a ship
			if(!check_rights(R_ADMIN))
				return FALSE

			var/ship_id = params["ship_id"]
			if(!ship_id)
				return FALSE

			var/datum/map_template/shuttle/voidcrew/template = find_ship_template_by_type(ship_id)
			if(!template)
				return FALSE

			// TODO: Implement ship spawning logic when ready
			to_chat(user, span_notice("Ship spawning not yet implemented. Coming soon!"))

		if("select_for_latejoin")
			var/ship_id = params["ship_id"]
			if(!ship_id)
				return FALSE

			// Find the ship template by type path
			var/datum/map_template/shuttle/voidcrew/template = find_ship_template_by_type(ship_id)
			if(!template)
				to_chat(user, span_warning("Invalid ship template."))
				return FALSE

			var/ckey = user.client?.ckey
			if(!ckey)
				return FALSE

			// Check if ship is unlocked
			if(!GLOB.ship_economy_db.is_ship_unlocked(ckey, "[template.type]"))
				// Try to unlock it
				if(!attempt_ship_unlock(user, template))
					// Error messages handled in attempt_ship_unlock
					return FALSE
				to_chat(user, span_notice("Successfully unlocked [template.name]!"))

			// Close the UI immediately before spawning
			ui.close()

			// Ship is unlocked (either was already, or just unlocked)
			// Invoke callback with the template
			if(on_ship_selected)
				on_ship_selected.Invoke(template)

/**
 * Attempt to unlock a ship by spending parts
 *
 * @param user The user attempting the unlock
 * @param template The ship template to unlock
 * @return TRUE if successful, FALSE otherwise
 */
/datum/ship_catalog_ui/proc/attempt_ship_unlock(mob/user, datum/map_template/shuttle/voidcrew/template)
	if(!user || !user.client || !template)
		return FALSE

	var/ckey = user.client.ckey

	// Check if ship is already unlocked
	if(GLOB.ship_economy_db.is_ship_unlocked(ckey, "[template.type]"))
		to_chat(user, span_warning("You have already unlocked this ship!"))
		return FALSE

	// Build requirements from template's class-based part_requirements
	var/list/requirements = list()
	var/has_requirements = FALSE
	for(var/part_class in template.part_requirements)
		var/count = template.part_requirements[part_class] || 0
		if(count > 0)
			requirements[part_class] = count
			has_requirements = TRUE

	// If no requirements, ship is free - just unlock it
	if(!has_requirements)
		if(!GLOB.ship_economy_db.unlock_ship(ckey, "[template.type]"))
			to_chat(user, span_warning("Failed to unlock ship. Please try again."))
			return FALSE
		log_game("SHIP_CATALOG: [ckey] unlocked free ship [template.type] ([template.name])")
		return TRUE

	// Check if player has sufficient parts
	var/list/current_parts = GLOB.ship_economy_db.get_parts(ckey)
	if(!current_parts)
		to_chat(user, span_warning("Unable to retrieve your parts inventory."))
		return FALSE

	for(var/part_class in requirements)
		var/needed = requirements[part_class]
		var/have = current_parts[part_class] || 0

		if(have < needed)
			to_chat(user, span_warning("Insufficient [part_class] parts! You need [needed] but only have [have]."))
			return FALSE

	// Attempt to spend parts
	if(!GLOB.ship_economy_db.spend_parts(ckey, requirements))
		to_chat(user, span_warning("Failed to deduct parts. Transaction failed."))
		return FALSE

	// Unlock the ship
	if(!GLOB.ship_economy_db.unlock_ship(ckey, "[template.type]"))
		// Parts were deducted but unlock failed - this is bad!
		// In production, this should trigger a compensating transaction or alert
		log_game("SHIP_CATALOG ERROR: Parts deducted but unlock failed for [ckey] - ship [template.type]")
		to_chat(user, span_userdanger("Unlock failed! Please contact an administrator - parts were deducted but unlock did not complete."))
		return FALSE

	// Success!
	log_game("SHIP_CATALOG: [ckey] unlocked ship [template.type] ([template.name])")
	return TRUE

/**
 * Generate a description for a ship based on its properties
 */
/datum/ship_catalog_ui/proc/generate_ship_description(datum/map_template/shuttle/voidcrew/template)
	// Get job slots - either from template directly or from default theme
	var/list/job_slots_to_use = template.job_slots

	// If ship has available_themes, get job slots from the default theme
	if(length(template.available_themes))
		var/datum/ship_theme/default_theme = get_default_theme_for_ship(template.type)
		if(default_theme?.job_slots)
			job_slots_to_use = default_theme.job_slots

	var/crew_count = 0
	for(var/list/job_definition in job_slots_to_use)
		crew_count += job_definition["slots"]

	var/ship_class = template.short_name || template.name

	// Build role summary
	var/list/roles = list()
	for(var/list/job_definition in job_slots_to_use)
		if(job_definition["slots"] > 0)
			roles += "[job_definition["slots"]]x [job_definition["name"]]"

	var/role_summary = length(roles) ? roles.Join(", ") : "varies by theme"

	// Add theme info if applicable
	var/theme_info = ""
	if(length(template.available_themes))
		theme_info = " [length(template.available_themes)] theme variants available."

	return "[ship_class] with capacity for [crew_count] crew members. Crew roles: [role_summary].[theme_info]"

/**
 * Get ship preview image path
 * For now returns a placeholder - will be implemented later
 */
/datum/ship_catalog_ui/proc/get_ship_preview_path(datum/map_template/shuttle/voidcrew/template)
	// TODO: Implement ship preview image system
	// For now, return a generic placeholder
	return "ship_preview_neutral.png"

/**
 * Admin verb to open ship catalog
 */
/datum/admins/proc/open_ship_catalog()
	if(!check_rights(R_ADMIN))
		return

	var/datum/ship_catalog_ui/catalog = new(usr)
	catalog.ui_interact(usr)

/**
 * Client proc to open ship catalog (for character creation)
 */
/client/proc/open_ship_catalog()
	var/datum/ship_catalog_ui/catalog = new(mob)
	catalog.ui_interact(mob)

/**
 * Player verb to browse the ship catalog
 */
/client/verb/view_ship_catalog()
	set name = "View Ship Catalog"
	set category = "OOC"
	set desc = "Browse available ships and see what you've unlocked."

	open_ship_catalog()

// Faction constants (if not already defined elsewhere)
#ifndef FACTION_NEUTRAL
#define FACTION_NEUTRAL "Neutral"
#endif

#ifndef FACTION_NT
#define FACTION_NT "Nanotrasen"
#endif

#ifndef SYNDICATE_SHIP
#define SYNDICATE_SHIP "Syndicate"
#endif

#ifndef NEUTRAL_SHIP
#define NEUTRAL_SHIP "Independent"
#endif
