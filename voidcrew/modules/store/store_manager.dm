/**
 * Voidcrew Player Shop System - Store Manager Backend
 *
 * Ported from Monkestation's store system, adapted for Voidcrew's ship credit economy.
 * This is the TGUI backend datum that handles the store UI.
 *
 * Key differences from Monkestation:
 * - Uses ship credits (GLOB.ship_economy_db) instead of metacoins
 * - Lobby-only store (accessible before round starts)
 * - Simplified categories: Head, Suit, Uniform, Equipment
 * - No character preview/dummy sprite system
 */

// Client tracking for open store UI
/client
	/// A ref to store_manager datum
	var/datum/store_manager/open_store_ui = null

/**
 * Datum holder for the store manager UI
 * Handles purchasing items via ship credits and manages the TGUI interface
 */
/datum/store_manager
	/// The client of the person using the UI
	var/client/owner

/**
 * Initialize the store manager for a specific client
 *
 * @param user - Client or mob to extract client from
 */
/datum/store_manager/New(user)
	owner = CLIENT_FROM_VAR(user)
	if(!owner)
		stack_trace("store_manager created with invalid user (no client)")
		qdel(src)
		return
	owner.open_store_ui = src

/**
 * Cleanup on destroy
 */
/datum/store_manager/Destroy(force)
	if(owner)
		owner.open_store_ui = null
	owner = null
	return ..()

/**
 * Handle UI close - clean up the datum
 */
/datum/store_manager/ui_close(mob/user)
	owner?.prefs?.save_character()
	owner?.open_store_ui = null
	qdel(src)

/**
 * UI state - always accessible (lobby state)
 */
/datum/store_manager/ui_state(mob/user)
	return GLOB.always_state

/**
 * Open the TGUI window
 */
/datum/store_manager/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "VoidcrewStore")
		ui.open()

/**
 * Handle UI actions from the frontend
 *
 * @param action - The action being performed
 * @param params - Parameters for the action
 */
/datum/store_manager/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/datum/store_item/interacted_item
	if(params["path"])
		interacted_item = GLOB.all_store_items[text2path(params["path"])]
		if(!interacted_item)
			stack_trace("Failed to locate desired store item (path: [params["path"]]) in the global list of store items!")
			return

	switch(action)
		// Close the UI
		if("close_ui")
			SStgui.close_uis(src)
			return TRUE

		// Purchase an item
		if("select_item")
			if(!interacted_item)
				return FALSE
			select_item(interacted_item)
			return TRUE

	return FALSE

/**
 * Attempt to purchase the selected item
 *
 * @param selected_item - The store item datum to purchase
 */
/datum/store_manager/proc/select_item(datum/store_item/selected_item)
	if(!selected_item || !owner)
		return

	// For permanent items, check if already owned
	if(!selected_item.one_time_buy)
		if(selected_item.item_path in owner.prefs.inventory)
			to_chat(owner, span_warning("You already own the [selected_item.name]!"))
			return

	// Attempt the purchase
	if(selected_item.attempt_purchase(owner))
		// Purchase successful - UI will auto-update via ui_data
		return

/**
 * Return dynamic data for the UI
 * This is called frequently to update the UI with current state
 */
/datum/store_manager/ui_data(mob/user)
	var/list/data = list()

	if(!owner?.prefs)
		data["owned_items"] = list()
		data["total_coins"] = 0
		return data

	// List of item paths the player owns (convert to strings for TGUI comparison)
	var/list/owned_strings = list()
	for(var/path in owner.prefs.inventory)
		owned_strings += "[path]"
	data["owned_items"] = owned_strings

	// Player's current ship credit balance
	data["total_coins"] = GLOB.ship_economy_db?.get_credits(owner.ckey) || 0

	return data

/**
 * Return static data for the UI
 * This is called once when UI opens and contains the store catalog
 */
/datum/store_manager/ui_static_data()
	var/list/data = list()

	// Build the loadout tabs with store items
	// [name] is the tab name
	// [title] is the display title for the tab
	// [contents] is the list of items in that category
	var/list/loadout_tabs = list()

	loadout_tabs += list(list(
		"name" = "Head",
		"title" = "Head Slot Items",
		"contents" = list_to_data(GLOB.store_clothing_head)
	))

	loadout_tabs += list(list(
		"name" = "Suit",
		"title" = "Suit Slot Items",
		"contents" = list_to_data(GLOB.store_clothing_suit)
	))

	loadout_tabs += list(list(
		"name" = "Uniform",
		"title" = "Uniform Slot Items",
		"contents" = list_to_data(GLOB.store_clothing_uniform)
	))

	loadout_tabs += list(list(
		"name" = "Equipment",
		"title" = "One-Time Items",
		"contents" = list_to_data(GLOB.store_equipment)
	))

	data["loadout_tabs"] = loadout_tabs

	return data

/**
 * Convert a list of store item datums into TGUI-friendly format
 *
 * @param list_of_datums - List of /datum/store_item to format
 * @return Formatted list for TGUI consumption
 */
/datum/store_manager/proc/list_to_data(list/list_of_datums)
	if(!LAZYLEN(list_of_datums))
		return list()

	var/list/formatted_list = list()

	for(var/datum/store_item/item as anything in list_of_datums)
		// Skip hidden items
		if(item.hidden)
			continue

		var/obj/item/item_type = item.item_path

		var/list/formatted_item = list(
			"name" = item.name,
			"path" = "[item.item_path]", // Convert to string for TGUI
			"cost" = item.item_cost,
			"desc" = item.store_desc || item_type::desc || "No description available.",
		)

		// Try to get icon information
		// Use icon_preview if available, otherwise use the item's default icon
		if(item_type::icon && item_type::icon_state)
			formatted_item["icon"] = item_type::icon
			formatted_item["icon_state"] = item_type::icon_state
		else
			// Fallback - no icon
			formatted_item["icon"] = null
			formatted_item["icon_state"] = null

		formatted_list += list(formatted_item)

	return formatted_list

/**
 * Client proc to open the Voidcrew store
 * Called from lobby button - lobby only access
 */
/client/proc/open_voidcrew_store()
	// Check if player is in lobby
	if(!isnewplayer(mob))
		to_chat(src, span_warning("The store is only accessible from the lobby!"))
		return

	// Check if store is already open
	if(open_store_ui)
		to_chat(src, span_warning("You already have the store open!"))
		return

	// Check if player has preferences loaded
	if(!prefs)
		to_chat(src, span_warning("Unable to open store - preferences not loaded!"))
		return

	// Create and open the store manager
	var/datum/store_manager/manager = new(src)
	manager.ui_interact(mob)
