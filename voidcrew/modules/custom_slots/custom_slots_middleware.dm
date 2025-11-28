/**
 * Custom Slots Middleware
 *
 * Preference middleware for custom spawn slot configuration in the lobby.
 * Connects TGUI to GLOB.custom_slot_manager to allow players to:
 * - Purchase additional custom slots (slot 2, slot 3)
 * - Configure slot names
 * - Set active slot (loads loadout into preferences)
 * - View their current slots and credit balance
 */

/datum/preference_middleware/custom_slots
	action_delegations = list(
		"purchase_slot" = PROC_REF(action_purchase_slot),
		"configure_slot" = PROC_REF(action_configure_slot),
		"save_loadout" = PROC_REF(action_save_loadout),
		"set_active_slot" = PROC_REF(action_set_active_slot),
	)

	/// Rate limit tracking - last action time per ckey
	var/static/list/last_action_time = list()
	/// Minimum time between actions in deciseconds (1 second)
	var/static/action_cooldown = 10

/**
 * Check rate limit for a user
 * Returns TRUE if action is allowed, FALSE if rate limited
 */
/datum/preference_middleware/custom_slots/proc/check_rate_limit(ckey)
	if(!ckey)
		return FALSE
	var/last_time = last_action_time[ckey]
	if(last_time && (world.time - last_time) < action_cooldown)
		return FALSE
	last_action_time[ckey] = world.time
	return TRUE

/**
 * Return dynamic UI data (updated on each UI refresh)
 * Includes: player's slots, current credits, owned slots
 */
/datum/preference_middleware/custom_slots/get_ui_data(mob/user)
	var/list/data = list()

	// Always provide slots list (even if empty) so TGUI doesn't break
	var/list/slots = list()

	if(!user?.client?.ckey)
		data["slots"] = slots
		data["playerCredits"] = 0
		return data

	var/ckey = user.client.ckey

	// Get player's current credit balance
	if(GLOB.ship_economy_db)
		data["playerCredits"] = GLOB.ship_economy_db.get_credits(ckey)
	else
		data["playerCredits"] = 0

	// Get player's slots from custom slot manager
	if(GLOB.custom_slot_manager)
		var/list/raw_slots = GLOB.custom_slot_manager.get_player_slots(ckey)

		// Determine which slot is active (has is_default set)
		var/active_index = 0
		for(var/list/slot_data in raw_slots)
			if(slot_data["is_default"])
				active_index = slot_data["slot_index"]
				break

		// Transform data for UI
		for(var/list/slot_data in raw_slots)
			var/slot_index = slot_data["slot_index"]
			slots += list(list(
				"index" = slot_index,
				"name" = slot_data["slot_name"] || "Custom Slot [slot_index]",
				"unlocked" = !!slot_data["purchased"],
				"cost" = GLOB.custom_slot_manager.get_slot_cost(slot_index),
				"isActive" = (slot_index == active_index)
			))

		// Add unpurchased slots (slots 2 and 3 if not owned)
		var/list/owned_indices = list()
		for(var/list/slot in slots)
			owned_indices += slot["index"]

		// Always show slot 1 even if database didn't return it
		if(!(1 in owned_indices))
			slots = list(list(
				"index" = 1,
				"name" = "Custom Slot 1",
				"unlocked" = TRUE,
				"cost" = 0,
				"isActive" = (1 == active_index)
			)) + slots

		// Check for slot 2
		if(!(2 in owned_indices))
			slots += list(list(
				"index" = 2,
				"name" = "Custom Slot 2",
				"unlocked" = FALSE,
				"cost" = GLOB.custom_slot_manager.get_slot_cost(2),
				"isActive" = FALSE
			))

		// Check for slot 3
		if(!(3 in owned_indices))
			slots += list(list(
				"index" = 3,
				"name" = "Custom Slot 3",
				"unlocked" = FALSE,
				"cost" = GLOB.custom_slot_manager.get_slot_cost(3),
				"isActive" = FALSE
			))
	else
		// Fallback: show default slots if manager isn't available
		slots = list(
			list("index" = 1, "name" = "Custom Slot 1", "unlocked" = TRUE, "cost" = 0, "isActive" = FALSE),
			list("index" = 2, "name" = "Custom Slot 2", "unlocked" = FALSE, "cost" = 10000, "isActive" = FALSE),
			list("index" = 3, "name" = "Custom Slot 3", "unlocked" = FALSE, "cost" = 25000, "isActive" = FALSE)
		)

	data["slots"] = slots
	return data

/**
 * Handle slot purchase action from UI
 * Expected params: slotIndex (number)
 */
/datum/preference_middleware/custom_slots/proc/action_purchase_slot(list/params, mob/user)
	PRIVATE_PROC(TRUE)

	if(!user.client?.ckey)
		to_chat(user, span_warning("Failed to purchase slot: no client!"))
		return TRUE

	// Rate limit check
	if(!check_rate_limit(user.client.ckey))
		return TRUE

	if(!GLOB.custom_slot_manager)
		to_chat(user, span_warning("Custom slot system not available!"))
		return TRUE

	var/slot_index = text2num(params["slotIndex"])
	if(!slot_index || slot_index < 2 || slot_index > 3)
		to_chat(user, span_warning("Invalid slot index!"))
		return TRUE

	// Check if already owned
	if(GLOB.custom_slot_manager.is_slot_owned(user.client.ckey, slot_index))
		to_chat(user, span_warning("You already own slot [slot_index]!"))
		return TRUE

	// Get cost
	var/cost = GLOB.custom_slot_manager.get_slot_cost(slot_index)
	var/current_credits = GLOB.ship_economy_db.get_credits(user.client.ckey)

	// Check affordability
	if(current_credits < cost)
		to_chat(user, span_warning("You need [cost] credits to purchase slot [slot_index], but you only have [current_credits]!"))
		return TRUE

	// Attempt purchase
	if(GLOB.custom_slot_manager.purchase_slot(user.client.ckey, slot_index))
		to_chat(user, span_notice("Successfully purchased custom slot [slot_index] for [cost] credits!"))
		return TRUE
	else
		to_chat(user, span_warning("Failed to purchase slot [slot_index]. Please try again."))
		return TRUE

/**
 * Handle slot configuration action from UI
 * Expected params: slotIndex (number), name (string)
 */
/datum/preference_middleware/custom_slots/proc/action_configure_slot(list/params, mob/user)
	PRIVATE_PROC(TRUE)

	if(!user.client?.ckey)
		to_chat(user, span_warning("Failed to configure slot: no client!"))
		return TRUE

	// Rate limit check
	if(!check_rate_limit(user.client.ckey))
		return TRUE

	if(!GLOB.custom_slot_manager)
		to_chat(user, span_warning("Custom slot system not available!"))
		return TRUE

	var/slot_index = text2num(params["slotIndex"])

	if(!slot_index || slot_index < 1 || slot_index > 3)
		to_chat(user, span_warning("Invalid slot index!"))
		return TRUE

	// Check ownership - this will auto-create slot 1 if needed
	if(!GLOB.custom_slot_manager.is_slot_owned(user.client.ckey, slot_index))
		to_chat(user, span_warning("You don't own slot [slot_index]!"))
		return TRUE

	var/slot_name = params["name"]

	// Validate slot name
	if(!slot_name || length(slot_name) == 0)
		to_chat(user, span_warning("Slot name cannot be empty!"))
		return TRUE

	// Sanitize slot name (trim whitespace)
	slot_name = trim(slot_name)

	// Attempt configuration
	if(GLOB.custom_slot_manager.configure_slot(user.client.ckey, slot_index, slot_name))
		to_chat(user, span_notice("Successfully configured slot [slot_index]: '[slot_name]'."))
		return TRUE
	else
		to_chat(user, span_warning("Failed to configure slot [slot_index]. Please try again."))
		return TRUE

/**
 * Handle saving current loadout to a custom slot
 * Expected params: slotIndex (number)
 */
/datum/preference_middleware/custom_slots/proc/action_save_loadout(list/params, mob/user)
	PRIVATE_PROC(TRUE)

	if(!user.client?.ckey)
		to_chat(user, span_warning("Failed to save loadout: no client!"))
		return TRUE

	// Rate limit check
	if(!check_rate_limit(user.client.ckey))
		return TRUE

	if(!GLOB.custom_slot_manager)
		to_chat(user, span_warning("Custom slot system not available!"))
		return TRUE

	var/slot_index = text2num(params["slotIndex"])
	if(!slot_index || slot_index < 1 || slot_index > 3)
		to_chat(user, span_warning("Invalid slot index!"))
		return TRUE

	// Check ownership
	if(!GLOB.custom_slot_manager.is_slot_owned(user.client.ckey, slot_index))
		to_chat(user, span_warning("You don't own slot [slot_index]!"))
		return TRUE

	// Get current loadout from preferences
	var/list/current_loadout = preferences.read_preference(/datum/preference/loadout)
	if(!current_loadout)
		current_loadout = list()

	// Save loadout to custom slot
	if(GLOB.custom_slot_manager.save_slot_loadout(user.client.ckey, slot_index, current_loadout))
		to_chat(user, span_notice("Successfully saved current loadout to slot [slot_index]!"))
		return TRUE
	else
		to_chat(user, span_warning("Failed to save loadout to slot [slot_index]. Please try again."))
		return TRUE

/**
 * Handle setting a slot as active and loading its loadout
 * Expected params: slotIndex (number)
 */
/datum/preference_middleware/custom_slots/proc/action_set_active_slot(list/params, mob/user)
	PRIVATE_PROC(TRUE)

	if(!user.client?.ckey)
		to_chat(user, span_warning("Failed to set active slot: no client!"))
		return TRUE

	// Rate limit check
	if(!check_rate_limit(user.client.ckey))
		return TRUE

	if(!GLOB.custom_slot_manager)
		to_chat(user, span_warning("Custom slot system not available!"))
		return TRUE

	var/slot_index = text2num(params["slotIndex"])
	if(!slot_index || slot_index < 1 || slot_index > 3)
		to_chat(user, span_warning("Invalid slot index!"))
		return TRUE

	// Check ownership
	if(!GLOB.custom_slot_manager.is_slot_owned(user.client.ckey, slot_index))
		to_chat(user, span_warning("You don't own slot [slot_index]!"))
		return TRUE

	// Set as default slot (clears other defaults)
	if(!GLOB.custom_slot_manager.set_default_slot(user.client.ckey, slot_index))
		to_chat(user, span_warning("Failed to set active slot. Please try again."))
		return TRUE

	// Explicitly clear cache to ensure fresh data for UI
	GLOB.custom_slot_manager.invalidate_cache(user.client.ckey, "slots")

	// Load the slot's loadout into preferences
	var/list/slot_loadout = GLOB.custom_slot_manager.get_slot_loadout(user.client.ckey, slot_index)
	if(slot_loadout && length(slot_loadout))
		// Apply loadout to preferences using update_preference (triggers character preview refresh)
		preferences.update_preference(GLOB.preference_entries[/datum/preference/loadout], slot_loadout)

	// Refresh character preview
	preferences.character_preview_view?.update_body()

	to_chat(user, span_notice("Slot [slot_index] is now active."))
	return TRUE
