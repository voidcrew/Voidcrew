/**
 * # Ship Upgrade Selector UI
 *
 * TGUI interface for unlocking and selecting ship upgrades before spawning.
 *
 * Two-phase approach:
 * 1. UNLOCK: Purchase upgrade modules permanently (one-time cost)
 * 2. SELECT: Choose from unlocked upgrades when spawning (free)
 *
 * Default modules are always available (no unlock required).
 */

/**
 * Ship Upgrade Selector Datum
 *
 * Opens after player selects a ship from the catalog to allow
 * unlocking and selecting upgrade modules before spawning.
 */
/datum/ship_upgrade_selector
	/// The user viewing this UI
	var/mob/user
	/// The ship template being customized
	var/datum/map_template/shuttle/voidcrew/template
	/// Callback invoked when selection is confirmed (template, upgrade_selections)
	var/datum/callback/on_complete
	/// Currently selected upgrades per slot: slot_key -> /datum/ship_upgrade_module
	var/list/selected_upgrades = list()
	/// All available modules for this ship, cached
	var/list/available_modules = list()
	/// Cached list of unlocked upgrade IDs for this ship
	var/list/unlocked_upgrade_ids = list()

/datum/ship_upgrade_selector/New(mob/viewing_user, datum/map_template/shuttle/voidcrew/ship_template, datum/callback/completion_callback)
	. = ..()
	user = viewing_user
	template = ship_template
	on_complete = completion_callback

	// Initialize upgrade system and cache modules
	ensure_ship_upgrades_initialized()
	available_modules = get_modules_for_ship(template.type)

	// Get unlocked upgrades for this ship
	refresh_unlocked_upgrades()

	// Pre-select default modules for each slot
	for(var/slot_key in template.upgrade_slot_ids)
		var/datum/ship_upgrade_module/default_module = get_default_module_for_ship_slot(template.type, slot_key)
		if(default_module)
			selected_upgrades[slot_key] = default_module

/datum/ship_upgrade_selector/Destroy()
	user = null
	template = null
	on_complete = null
	selected_upgrades = null
	available_modules = null
	unlocked_upgrade_ids = null
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
 * Static data - ship info and available upgrades (doesn't change)
 */
/datum/ship_upgrade_selector/ui_static_data(mob/user)
	var/list/data = list()

	// Ship info
	data["ship_name"] = template.name
	data["ship_short_name"] = template.short_name || template.name
	data["ship_template"] = "[template.type]"

	// Build slots with available modules
	var/list/slots = list()
	for(var/slot_key in template.upgrade_slot_ids)
		var/list/slot_modules = list()

		for(var/module_id in available_modules)
			var/datum/ship_upgrade_module/module = available_modules[module_id]
			if(module.slot != slot_key)
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
	return data

/**
 * Dynamic data - player's parts, unlocks, and current selections
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

	// Refresh and send unlocked upgrades
	refresh_unlocked_upgrades()
	data["unlocked_upgrades"] = unlocked_upgrade_ids

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
				if(default_module)
					selected_upgrades[slot_key] = default_module
				else
					selected_upgrades -= slot_key
			else
				// Select specific module (must be unlocked)
				var/datum/ship_upgrade_module/module = available_modules[module_id]
				if(!module || module.slot != slot_key)
					return FALSE

				if(!is_module_unlocked(module))
					to_chat(user, span_warning("You must unlock this upgrade before selecting it."))
					return FALSE

				selected_upgrades[slot_key] = module

		if("confirm")
			// Validate all selections are unlocked
			for(var/slot_key in selected_upgrades)
				var/datum/ship_upgrade_module/module = selected_upgrades[slot_key]
				if(module && !is_module_unlocked(module))
					to_chat(user, span_warning("You have selected upgrades you don't own!"))
					return FALSE

			// Close UI and invoke callback
			ui.close()
			if(on_complete)
				on_complete.Invoke(template, selected_upgrades.Copy())

		if("cancel")
			ui.close()
			if(on_complete)
				on_complete.Invoke(null, null)

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
