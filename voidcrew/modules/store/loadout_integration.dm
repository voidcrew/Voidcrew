/**
 * Voidcrew Store - Loadout Integration
 *
 * Extends the loadout system to support purchasable items.
 * Items with requires_purchase = TRUE must be bought with ship credits
 * before they can be selected in the loadout menu.
 */

/// Add purchase-related vars to loadout items
/datum/loadout_item
	/// If TRUE, this item must be purchased before it can be used
	var/requires_purchase = FALSE
	/// Cost in ship credits (only relevant if requires_purchase = TRUE)
	var/purchase_cost = 0

/**
 * Check if a player owns this loadout item
 * Returns TRUE if item doesn't require purchase OR if player has purchased it
 */
/datum/loadout_item/proc/is_owned_by(client/player)
	if(!requires_purchase)
		return TRUE

	if(!player?.ckey)
		return FALSE

	// Check database for ownership
	if(!SSdbcore.IsConnected())
		return FALSE

	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT 1 FROM [format_table_name("player_loadout_purchases")] WHERE ckey = :ckey AND item_path = :item_path",
		list("ckey" = player.ckey, "item_path" = "[item_path]")
	)

	var/owned = FALSE
	if(query.Execute() && query.NextRow())
		owned = TRUE

	qdel(query)
	return owned

/**
 * Attempt to purchase this loadout item for a player
 * Returns TRUE if purchase successful, FALSE otherwise
 */
/datum/loadout_item/proc/attempt_purchase(client/buyer)
	if(!requires_purchase)
		to_chat(buyer, span_warning("[name] doesn't require purchase!"))
		return FALSE

	if(!buyer?.ckey)
		return FALSE

	// Check if already owned
	if(is_owned_by(buyer))
		to_chat(buyer, span_warning("You already own [name]!"))
		return FALSE

	// Check credits
	var/current_credits = GLOB.ship_economy_db.get_credits(buyer.ckey)
	if(current_credits < purchase_cost)
		to_chat(buyer, span_warning("You need [purchase_cost] credits to buy [name], but you only have [current_credits]!"))
		return FALSE

	if(!SSdbcore.IsConnected())
		to_chat(buyer, span_warning("Database not connected. Purchase failed."))
		return FALSE

	// Insert purchase record
	var/datum/db_query/query = SSdbcore.NewQuery(
		"INSERT INTO [format_table_name("player_loadout_purchases")] (ckey, item_path) VALUES (:ckey, :item_path)",
		list("ckey" = buyer.ckey, "item_path" = "[item_path]")
	)

	if(!query.Execute())
		to_chat(buyer, span_warning("Failed to record purchase. You have not been charged."))
		qdel(query)
		return FALSE

	qdel(query)

	// Deduct credits
	var/datum/db_query/credit_query = SSdbcore.NewQuery(
		"UPDATE [format_table_name("player_ship_credits")] SET credits = credits - :cost WHERE ckey = :ckey",
		list("ckey" = buyer.ckey, "cost" = purchase_cost)
	)
	credit_query.Execute()
	qdel(credit_query)

	// Invalidate credit cache
	GLOB.ship_economy_db.invalidate_cache(buyer.ckey, "credits")

	to_chat(buyer, span_notice("Successfully purchased [name] for [purchase_cost] credits! You can now select it in your loadout."))
	log_game("VOIDCREW_STORE: [buyer.ckey] purchased loadout item [name] ([item_path]) for [purchase_cost] credits")

	return TRUE

/**
 * Override to_ui_data to include purchase info
 */
/datum/loadout_item/to_ui_data()
	var/list/data = ..()

	// Add purchase-related data
	data["requires_purchase"] = requires_purchase
	data["purchase_cost"] = purchase_cost

	return data

/**
 * Override get_item_information to show price for purchasable items
 */
/datum/loadout_item/get_item_information()
	var/list/info = ..()

	if(requires_purchase && purchase_cost > 0)
		info[FA_ICON_COINS] = "[purchase_cost] credits"

	return info

/**
 * Get list of all purchasable loadout items the player owns
 * Returns a list of item paths
 */
/proc/get_owned_loadout_items(ckey)
	var/list/owned = list()

	if(!ckey || !SSdbcore.IsConnected())
		return owned

	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT item_path FROM [format_table_name("player_loadout_purchases")] WHERE ckey = :ckey",
		list("ckey" = ckey)
	)

	if(!query.Execute())
		qdel(query)
		return owned

	while(query.NextRow())
		owned += query.item[1]

	qdel(query)
	return owned

/**
 * Extend the loadout middleware to handle purchases and ownership
 */
/datum/preference_middleware/loadout
	/// Cached list of owned item paths for the current user
	var/list/cached_owned_items

/datum/preference_middleware/loadout/New(datum/preferences/preferences)
	. = ..()
	// Add purchase action to the action delegations
	action_delegations["purchase_loadout_item"] = PROC_REF(action_purchase_item)

/datum/preference_middleware/loadout/get_ui_data(mob/user)
	var/list/data = ..()

	// Add player's current credits
	if(user.client?.ckey)
		data["ship_credits"] = GLOB.ship_economy_db.get_credits(user.client.ckey)

		// Get owned purchasable items for this player
		if(isnull(cached_owned_items))
			cached_owned_items = get_owned_loadout_items(user.client.ckey)
		data["owned_loadout_items"] = cached_owned_items
	else
		data["ship_credits"] = 0
		data["owned_loadout_items"] = list()

	return data

/**
 * Handle purchase action from UI
 */
/datum/preference_middleware/loadout/proc/action_purchase_item(list/params, mob/user)
	PRIVATE_PROC(TRUE)

	var/path_to_use = text2path(params["path"])
	var/datum/loadout_item/target_item = GLOB.all_loadout_datums[path_to_use]

	if(!istype(target_item))
		to_chat(user, span_warning("Invalid item!"))
		return TRUE

	if(!target_item.requires_purchase)
		to_chat(user, span_warning("This item doesn't require purchase!"))
		return TRUE

	if(target_item.attempt_purchase(user.client))
		// Invalidate ownership cache so UI updates
		cached_owned_items = null
		return TRUE

	return TRUE

/**
 * Override select_item to check ownership for purchasable items
 */
/datum/preference_middleware/loadout/action_select_item(list/params, mob/user)
	var/path_to_use = text2path(params["path"])
	var/datum/loadout_item/interacted_item = GLOB.all_loadout_datums[path_to_use]

	if(!istype(interacted_item))
		stack_trace("Failed to locate desired loadout item (path: [params["path"]]) in the global list of loadout datums!")
		return TRUE

	// Check ownership for purchasable items (only when selecting, not deselecting)
	if(!params["deselect"] && interacted_item.requires_purchase)
		if(!interacted_item.is_owned_by(user.client))
			to_chat(user, span_warning("You must purchase [interacted_item.name] before you can use it! ([interacted_item.purchase_cost] credits)"))
			return TRUE

	if(params["deselect"])
		deselect_item(interacted_item)
	else
		select_item(interacted_item)
	return TRUE
