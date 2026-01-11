/**
 * # Ship Upgrade Selector UI
 *
 * TGUI interface for selecting ship upgrades before spawning.
 * Shows available upgrade modules for each slot and calculates costs.
 */

/**
 * Ship Upgrade Selector Datum
 *
 * Opens after player selects a ship from the catalog to allow
 * customization of upgrade slots before spawning.
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

/datum/ship_upgrade_selector/New(mob/viewing_user, datum/map_template/shuttle/voidcrew/ship_template, datum/callback/completion_callback)
	. = ..()
	user = viewing_user
	template = ship_template
	on_complete = completion_callback

	// Initialize upgrade system and cache modules
	ensure_ship_upgrades_initialized()
	available_modules = get_modules_for_ship(template.type)

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
	return ..()

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
					part_cost[part_class] = module.part_cost[part_class]

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
 * Dynamic data - player's parts and current selections
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

	// Current selections
	var/list/selections = list()
	for(var/slot_key in selected_upgrades)
		var/datum/ship_upgrade_module/module = selected_upgrades[slot_key]
		if(module)
			selections[slot_key] = module.id
	data["selected_upgrades"] = selections

	// Calculate total cost of non-default selections
	var/list/total_cost = list()
	for(var/part_class in GLOB.ship_part_classes)
		total_cost[part_class] = 0

	for(var/slot_key in selected_upgrades)
		var/datum/ship_upgrade_module/module = selected_upgrades[slot_key]
		if(module?.part_cost && !module.is_default)
			for(var/part_class in module.part_cost)
				total_cost[part_class] += module.part_cost[part_class]

	data["total_cost"] = total_cost

	// Check if player can afford
	var/can_afford = TRUE
	for(var/part_class in total_cost)
		if(total_cost[part_class] > (parts[part_class] || 0))
			can_afford = FALSE
			break
	data["can_afford"] = can_afford

	return data

/datum/ship_upgrade_selector/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return TRUE

	. = TRUE

	switch(action)
		if("select_upgrade")
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
				// Select specific module
				var/datum/ship_upgrade_module/module = available_modules[module_id]
				if(module && module.slot == slot_key)
					selected_upgrades[slot_key] = module

		if("confirm")
			// Validate player can afford
			if(!can_afford_upgrades(user))
				to_chat(user, span_warning("You cannot afford these upgrades!"))
				return FALSE

			// Deduct parts for non-default upgrades
			if(!spend_upgrade_parts(user))
				to_chat(user, span_warning("Failed to deduct upgrade costs. Please try again."))
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
 * Check if the user can afford all selected non-default upgrades
 */
/datum/ship_upgrade_selector/proc/can_afford_upgrades(mob/check_user)
	if(!check_user?.client)
		return FALSE

	var/ckey = check_user.client.ckey
	var/list/parts = GLOB.ship_economy_db?.get_parts(ckey)
	if(!parts)
		return FALSE

	// Calculate total cost - only non-zero costs
	var/list/total_cost = list()

	for(var/slot_key in selected_upgrades)
		var/datum/ship_upgrade_module/module = selected_upgrades[slot_key]
		if(module?.part_cost && !module.is_default)
			for(var/part_class in module.part_cost)
				var/cost = module.part_cost[part_class]
				if(cost > 0)
					total_cost[part_class] = (total_cost[part_class] || 0) + cost

	// If no cost, always affordable
	if(!length(total_cost))
		return TRUE

	// Check affordability
	for(var/part_class in total_cost)
		if(total_cost[part_class] > (parts[part_class] || 0))
			return FALSE

	return TRUE

/**
 * Spend parts for all selected non-default upgrades
 */
/datum/ship_upgrade_selector/proc/spend_upgrade_parts(mob/spending_user)
	if(!spending_user?.client)
		return FALSE

	var/ckey = spending_user.client.ckey

	// Calculate total cost - only include non-zero costs
	var/list/total_cost = list()

	for(var/slot_key in selected_upgrades)
		var/datum/ship_upgrade_module/module = selected_upgrades[slot_key]
		if(module?.part_cost && !module.is_default)
			for(var/part_class in module.part_cost)
				var/cost = module.part_cost[part_class]
				if(cost > 0)
					total_cost[part_class] = (total_cost[part_class] || 0) + cost

	// If no cost, nothing to spend
	if(!length(total_cost))
		return TRUE

	// Spend parts
	if(!GLOB.ship_economy_db?.spend_parts(ckey, total_cost))
		return FALSE

	log_game("SHIP_UPGRADE: [ckey] spent parts for ship upgrades on [template.type]")
	return TRUE
