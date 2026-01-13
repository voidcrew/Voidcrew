/**
 * # Ship Upgrade Selector UI
 *
 * TGUI interface for unlocking and selecting ship themes and upgrades before spawning.
 *
 * Three-phase approach:
 * 1. THEME: Select ship theme (affects jobs, aesthetics, available modules)
 * 2. UNLOCK: Purchase upgrade modules permanently (one-time cost)
 * 3. SELECT: Choose from unlocked upgrades when spawning (free)
 *
 * Default themes and modules are always available (no unlock required).
 */

/**
 * Ship Upgrade Selector Datum
 *
 * Opens after player selects a ship from the catalog to allow
 * unlocking themes, selecting a theme, and customizing upgrade modules before spawning.
 */
/datum/ship_upgrade_selector
	/// The user viewing this UI
	var/mob/user
	/// The ship template being customized
	var/datum/map_template/shuttle/voidcrew/template
	/// Callback invoked when selection is confirmed (template, upgrade_selections, selected_theme)
	var/datum/callback/on_complete
	/// Currently selected upgrades per slot: slot_key -> /datum/ship_upgrade_module
	var/list/selected_upgrades = list()
	/// All available modules for this ship, cached
	var/list/available_modules = list()
	/// All available themes for this ship, cached
	var/list/available_themes = list()
	/// Currently selected theme
	var/datum/ship_theme/selected_theme
	/// Cached list of unlocked upgrade IDs for this ship
	var/list/unlocked_upgrade_ids = list()
	/// Cached list of unlocked theme IDs for this ship
	var/list/unlocked_theme_ids = list()

/datum/ship_upgrade_selector/New(mob/viewing_user, datum/map_template/shuttle/voidcrew/ship_template, datum/callback/completion_callback)
	. = ..()
	user = viewing_user
	template = ship_template
	on_complete = completion_callback

	// Initialize upgrade system and cache modules/themes
	ensure_ship_upgrades_initialized()
	available_modules = get_modules_for_ship(template.type)
	available_themes = get_themes_for_ship(template.type)

	// Get unlocked upgrades and themes for this ship
	refresh_unlocked_upgrades()
	refresh_unlocked_themes()

	// Select default theme
	selected_theme = get_default_theme_for_ship(template.type)

	// Pre-select default modules for each slot based on selected theme
	refresh_default_module_selections()

/datum/ship_upgrade_selector/Destroy()
	user = null
	template = null
	on_complete = null
	selected_upgrades = null
	available_modules = null
	available_themes = null
	selected_theme = null
	unlocked_upgrade_ids = null
	unlocked_theme_ids = null
	return ..()

/**
 * Refresh the cached list of unlocked upgrade IDs
 */
/datum/ship_upgrade_selector/proc/refresh_unlocked_upgrades()
	if(!user?.client)
		unlocked_upgrade_ids = list()
		return

	var/ckey = user.client.ckey
	unlocked_upgrade_ids = GLOB.ship_economy_db?.get_unlocked_upgrades_for_ship(ckey, "[template.type]") || list()

/**
 * Refresh the cached list of unlocked theme IDs
 */
/datum/ship_upgrade_selector/proc/refresh_unlocked_themes()
	if(!user?.client)
		unlocked_theme_ids = list()
		return

	var/ckey = user.client.ckey
	unlocked_theme_ids = GLOB.ship_economy_db?.get_unlocked_themes_for_ship(ckey, "[template.type]") || list()

/**
 * Refresh default module selections based on current theme
 */
/datum/ship_upgrade_selector/proc/refresh_default_module_selections()
	selected_upgrades = list()
	var/list/slot_ids = get_current_slot_ids()

	for(var/slot_key in slot_ids)
		var/datum/ship_upgrade_module/default_module = get_default_module_for_ship_slot(template.type, slot_key)
		if(default_module && is_module_available_for_theme(default_module, selected_theme?.id))
			selected_upgrades[slot_key] = default_module

/**
 * Get the upgrade slot IDs for the current theme (or template default)
 */
/datum/ship_upgrade_selector/proc/get_current_slot_ids()
	if(selected_theme?.upgrade_slot_ids && length(selected_theme.upgrade_slot_ids))
		return selected_theme.upgrade_slot_ids
	return template.upgrade_slot_ids

/**
 * Check if a module is unlocked (or is default/free)
 */
/datum/ship_upgrade_selector/proc/is_module_unlocked(datum/ship_upgrade_module/module)
	if(!module)
		return FALSE
	// Default modules are always unlocked
	if(module.is_default)
		return TRUE
	// Check if purchased
	return (module.id in unlocked_upgrade_ids)

/**
 * Check if a theme is unlocked (or is default/free)
 */
/datum/ship_upgrade_selector/proc/is_theme_unlocked(datum/ship_theme/theme)
	if(!theme)
		return FALSE
	// Default themes are always unlocked
	if(theme.is_default)
		return TRUE
	// Check if purchased
	return (theme.id in unlocked_theme_ids)

/datum/ship_upgrade_selector/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipUpgradeSelector", "Customize Ship")
		ui.open()

/datum/ship_upgrade_selector/ui_state(mob/user)
	return GLOB.always_state

/datum/ship_upgrade_selector/ui_close(mob/user)
	. = ..()
	// Don't invoke callback on close - they may reopen catalog

/**
 * Static data - ship info and available themes (doesn't change)
 */
/datum/ship_upgrade_selector/ui_static_data(mob/user)
	var/list/data = list()

	// Ship info
	data["ship_name"] = template.name
	data["ship_short_name"] = template.short_name || template.name
	data["ship_template"] = "[template.type]"

	// Build themes list
	var/list/themes_data = list()
	for(var/theme_id in available_themes)
		var/datum/ship_theme/theme = available_themes[theme_id]

		// Build part cost list
		var/list/part_cost = list()
		if(length(theme.part_cost))
			for(var/part_class in theme.part_cost)
				var/cost = theme.part_cost[part_class]
				if(cost > 0)
					part_cost[part_class] = cost

		// Build job preview
		var/list/jobs = list()
		if(length(theme.job_slots))
			for(var/list/job_definition in theme.job_slots)
				jobs += list(list(
					"name" = job_definition["name"],
					"slots" = job_definition["slots"],
					"officer" = job_definition["officer"] ? TRUE : FALSE
				))

		themes_data += list(list(
			"id" = theme.id,
			"name" = theme.name,
			"desc" = theme.desc,
			"part_cost" = part_cost,
			"is_default" = theme.is_default,
			"jobs" = jobs
		))

	data["themes"] = themes_data
	data["has_themes"] = length(themes_data) > 0

	return data

/**
 * Dynamic data - player's parts, unlocks, current selections, and slots
 * Slots are dynamic because they change based on selected theme
 */
/datum/ship_upgrade_selector/ui_data(mob/user)
	var/list/data = list()

	if(!user?.client)
		return data

	var/ckey = user.client.ckey

	// Get player's parts inventory
	var/list/parts = GLOB.ship_economy_db?.get_parts(ckey)
	if(!parts)
		parts = list()
		for(var/part_class in GLOB.ship_part_classes)
			parts[part_class] = 0
	data["parts"] = parts

	// Refresh and send unlocked upgrades and themes
	refresh_unlocked_upgrades()
	refresh_unlocked_themes()
	data["unlocked_upgrades"] = unlocked_upgrade_ids
	data["unlocked_themes"] = unlocked_theme_ids

	// Selected theme
	data["selected_theme"] = selected_theme?.id

	// Build slots with available modules (filtered by selected theme)
	var/list/slots = list()
	var/list/slot_ids = get_current_slot_ids()
	var/current_theme_id = selected_theme?.id

	for(var/slot_key in slot_ids)
		var/list/slot_modules = list()

		for(var/module_id in available_modules)
			var/datum/ship_upgrade_module/module = available_modules[module_id]
			if(module.slot != slot_key)
				continue

			// Filter by theme if applicable
			if(!is_module_available_for_theme(module, current_theme_id))
				continue

			// Build part cost list
			var/list/part_cost = list()
			if(length(module.part_cost))
				for(var/part_class in module.part_cost)
					var/cost = module.part_cost[part_class]
					if(cost > 0)
						part_cost[part_class] = cost

			slot_modules += list(list(
				"id" = module.id,
				"name" = module.name,
				"desc" = module.desc,
				"part_cost" = part_cost,
				"is_default" = module.is_default
			))

		slots += list(list(
			"key" = slot_key,
			"display_name" = capitalize(replacetext(slot_key, "_", " ")),
			"modules" = slot_modules
		))

	data["slots"] = slots

	// Current selections (only unlocked modules can be selected)
	var/list/selections = list()
	for(var/slot_key in selected_upgrades)
		var/datum/ship_upgrade_module/module = selected_upgrades[slot_key]
		if(module && is_module_unlocked(module))
			selections[slot_key] = module.id
	data["selected_upgrades"] = selections

	return data

/datum/ship_upgrade_selector/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return TRUE

	. = TRUE

	switch(action)
		if("select_theme")
			// Select a theme (must be unlocked)
			var/theme_id = params["theme_id"]
			if(!theme_id)
				return FALSE

			var/datum/ship_theme/theme = available_themes[theme_id]
			if(!theme)
				to_chat(user, span_warning("Invalid theme."))
				return FALSE

			if(!is_theme_unlocked(theme))
				to_chat(user, span_warning("You must unlock this theme before selecting it."))
				return FALSE

			selected_theme = theme
			// Reset module selections to defaults for new theme
			refresh_default_module_selections()

		if("unlock_theme")
			// Purchase/unlock a theme permanently
			var/theme_id = params["theme_id"]
			if(!theme_id)
				return FALSE

			var/datum/ship_theme/theme = available_themes[theme_id]
			if(!theme)
				to_chat(user, span_warning("Invalid theme."))
				return FALSE

			// Can't unlock defaults (they're already free)
			if(theme.is_default)
				to_chat(user, span_notice("Default themes don't need to be unlocked."))
				return FALSE

			// Already unlocked?
			if(is_theme_unlocked(theme))
				to_chat(user, span_notice("You already own this theme."))
				return FALSE

			// Check cost
			if(!can_afford_theme(user, theme))
				to_chat(user, span_warning("You cannot afford this theme!"))
				return FALSE

			// Spend parts and unlock
			if(!purchase_theme(user, theme))
				to_chat(user, span_warning("Failed to purchase theme. Please try again."))
				return FALSE

			to_chat(user, span_notice("Successfully unlocked [theme.name]!"))
			refresh_unlocked_themes()

		if("unlock_upgrade")
			// Purchase/unlock an upgrade module permanently
			var/module_id = params["module_id"]
			if(!module_id)
				return FALSE

			var/datum/ship_upgrade_module/module = available_modules[module_id]
			if(!module)
				to_chat(user, span_warning("Invalid upgrade module."))
				return FALSE

			// Can't unlock defaults (they're already free)
			if(module.is_default)
				to_chat(user, span_notice("Default modules don't need to be unlocked."))
				return FALSE

			// Already unlocked?
			if(is_module_unlocked(module))
				to_chat(user, span_notice("You already own this upgrade."))
				return FALSE

			// Check cost
			if(!can_afford_module(user, module))
				to_chat(user, span_warning("You cannot afford this upgrade!"))
				return FALSE

			// Spend parts and unlock
			if(!purchase_module(user, module))
				to_chat(user, span_warning("Failed to purchase upgrade. Please try again."))
				return FALSE

			to_chat(user, span_notice("Successfully unlocked [module.name]!"))
			refresh_unlocked_upgrades()

		if("select_upgrade")
			// Select an upgrade for a slot (must be unlocked)
			var/slot_key = params["slot"]
			var/module_id = params["module_id"]

			if(!slot_key)
				return FALSE

			if(!module_id)
				// Deselect - use default
				var/datum/ship_upgrade_module/default_module = get_default_module_for_ship_slot(template.type, slot_key)
				if(default_module && is_module_available_for_theme(default_module, selected_theme?.id))
					selected_upgrades[slot_key] = default_module
				else
					selected_upgrades -= slot_key
			else
				// Select specific module (must be unlocked)
				var/datum/ship_upgrade_module/module = available_modules[module_id]
				if(!module || module.slot != slot_key)
					return FALSE

				if(!is_module_available_for_theme(module, selected_theme?.id))
					to_chat(user, span_warning("This module is not available for the selected theme."))
					return FALSE

				if(!is_module_unlocked(module))
					to_chat(user, span_warning("You must unlock this upgrade before selecting it."))
					return FALSE

				selected_upgrades[slot_key] = module

		if("confirm")
			// Validate theme is unlocked
			if(selected_theme && !is_theme_unlocked(selected_theme))
				to_chat(user, span_warning("You have selected a theme you don't own!"))
				return FALSE

			// Validate all selections are unlocked
			for(var/slot_key in selected_upgrades)
				var/datum/ship_upgrade_module/module = selected_upgrades[slot_key]
				if(module && !is_module_unlocked(module))
					to_chat(user, span_warning("You have selected upgrades you don't own!"))
					return FALSE

			// Close UI and invoke callback with theme
			ui.close()
			if(on_complete)
				on_complete.Invoke(template, selected_upgrades.Copy(), selected_theme)

		if("cancel")
			ui.close()
			if(on_complete)
				on_complete.Invoke(null, null, null)

/**
 * Check if player can afford to unlock a theme
 */
/datum/ship_upgrade_selector/proc/can_afford_theme(mob/check_user, datum/ship_theme/theme)
	if(!check_user?.client || !theme)
		return FALSE

	// Default themes are free
	if(theme.is_default)
		return TRUE

	// No cost defined = free
	if(!length(theme.part_cost))
		return TRUE

	var/ckey = check_user.client.ckey
	var/list/parts = GLOB.ship_economy_db?.get_parts(ckey)
	if(!parts)
		return FALSE

	for(var/part_class in theme.part_cost)
		var/cost = theme.part_cost[part_class]
		if(cost > 0 && (parts[part_class] || 0) < cost)
			return FALSE

	return TRUE

/**
 * Purchase/unlock a theme permanently
 */
/datum/ship_upgrade_selector/proc/purchase_theme(mob/purchasing_user, datum/ship_theme/theme)
	if(!purchasing_user?.client || !theme)
		return FALSE

	var/ckey = purchasing_user.client.ckey

	// Build cost list (only non-zero costs)
	var/list/cost = list()
	if(length(theme.part_cost))
		for(var/part_class in theme.part_cost)
			var/amount = theme.part_cost[part_class]
			if(amount > 0)
				cost[part_class] = amount

	// Spend parts if there's a cost
	if(length(cost))
		if(!GLOB.ship_economy_db?.spend_parts(ckey, cost))
			return FALSE

	// Unlock the theme
	if(!GLOB.ship_economy_db?.unlock_theme(ckey, "[template.type]", theme.id))
		// Parts were spent but unlock failed - log error
		log_game("SHIP_UPGRADE ERROR: Parts spent but theme unlock failed for [ckey] - theme [theme.id] on [template.type]")
		return FALSE

	log_game("SHIP_UPGRADE: [ckey] purchased theme '[theme.id]' for [template.type]")
	return TRUE

/**
 * Check if player can afford to unlock a module
 */
/datum/ship_upgrade_selector/proc/can_afford_module(mob/check_user, datum/ship_upgrade_module/module)
	if(!check_user?.client || !module)
		return FALSE

	// Default modules are free
	if(module.is_default)
		return TRUE

	// No cost defined = free
	if(!length(module.part_cost))
		return TRUE

	var/ckey = check_user.client.ckey
	var/list/parts = GLOB.ship_economy_db?.get_parts(ckey)
	if(!parts)
		return FALSE

	for(var/part_class in module.part_cost)
		var/cost = module.part_cost[part_class]
		if(cost > 0 && (parts[part_class] || 0) < cost)
			return FALSE

	return TRUE

/**
 * Purchase/unlock a module permanently
 */
/datum/ship_upgrade_selector/proc/purchase_module(mob/purchasing_user, datum/ship_upgrade_module/module)
	if(!purchasing_user?.client || !module)
		return FALSE

	var/ckey = purchasing_user.client.ckey

	// Build cost list (only non-zero costs)
	var/list/cost = list()
	if(length(module.part_cost))
		for(var/part_class in module.part_cost)
			var/amount = module.part_cost[part_class]
			if(amount > 0)
				cost[part_class] = amount

	// Spend parts if there's a cost
	if(length(cost))
		if(!GLOB.ship_economy_db?.spend_parts(ckey, cost))
			return FALSE

	// Unlock the upgrade
	if(!GLOB.ship_economy_db?.unlock_upgrade(ckey, "[template.type]", module.id))
		// Parts were spent but unlock failed - log error
		log_game("SHIP_UPGRADE ERROR: Parts spent but unlock failed for [ckey] - upgrade [module.id] on [template.type]")
		return FALSE

	log_game("SHIP_UPGRADE: [ckey] purchased upgrade '[module.id]' for [template.type]")
	return TRUE
