/**
 * Voidcrew Player Shop System - Base Store Item Datum
 *
 * Ported from Monkestation's store system, adapted for Voidcrew's ship credit economy.
 * Uses GLOB.ship_economy_db for all credit operations instead of metacoins.
 *
 * Key differences from Monkestation:
 * - Uses ship credits (GLOB.ship_economy_db) instead of metacoins
 * - Integrates with player_shop_purchases database table
 * - Categories adapted for Voidcrew's item types
 */

// Global lists for each category
GLOBAL_LIST_EMPTY(store_clothing_head)
GLOBAL_LIST_EMPTY(store_clothing_suit)
GLOBAL_LIST_EMPTY(store_clothing_uniform)
GLOBAL_LIST_EMPTY(store_equipment)
GLOBAL_LIST_EMPTY(all_store_items)

/**
 * Base store item datum
 * Represents a purchasable item in the Voidcrew player shop
 */
/datum/store_item
	/// The displayed name of this item in the shop
	var/name
	/// The category of the item (used for organizing in tabs)
	var/category
	/// The path of the actual item to spawn/grant
	var/atom/item_path
	/// The cost of the item in ship credits
	var/item_cost = 1000
	/// Hidden from general store listing
	var/hidden = FALSE
	/// Is this a one-time purchase for roundstart? FALSE = permanent unlock, TRUE = consumable/one-time spawn
	var/one_time_buy = FALSE
	/// The description shown in the store UI
	var/store_desc = ""

/**
 * Attempt to purchase this item
 * Validates player has sufficient credits and doesn't already own permanent items
 *
 * @param buyer - The client attempting to purchase
 * @return TRUE if purchase successful, FALSE otherwise
 */
/datum/store_item/proc/attempt_purchase(client/buyer)
	if(!buyer)
		return FALSE

	var/datum/preferences/buyers_preferences = buyer.prefs
	if(!buyers_preferences)
		return FALSE

	// For permanent items, check if already owned
	if(!one_time_buy)
		if(item_path in buyers_preferences.inventory)
			to_chat(buyer, span_warning("You already own the [name]!"))
			return FALSE

	// Check if player has enough ship credits
	var/current_credits = GLOB.ship_economy_db.get_credits(buyer.ckey)
	if(current_credits < item_cost)
		to_chat(buyer, span_warning("You don't have enough ship credits to buy the [name]. You need [item_cost] credits but only have [current_credits]."))
		return FALSE

	// Both permanent and one-time items are saved to DB
	// One-time items are removed from DB after spawning at roundstart
	if(finalize_purchase(buyer))
		// Deduct credits directly via SQL
		var/datum/db_query/credit_query = SSdbcore.NewQuery(
			"UPDATE [format_table_name("player_ship_credits")] SET credits = credits - :cost WHERE ckey = :ckey",
			list("ckey" = buyer.ckey, "cost" = item_cost)
		)
		var/credit_success = credit_query.Execute()
		qdel(credit_query)

		if(credit_success)
			// Invalidate the cache so get_credits returns fresh data
			GLOB.ship_economy_db.invalidate_cache(buyer.ckey, "credits")
			log_game("VOIDCREW_STORE: [buyer.ckey] spent [item_cost] credits on [name]")

		to_chat(buyer, span_notice("Successfully purchased [name] for [item_cost] ship credits! It will be available when you spawn."))
		return TRUE
	else
		return FALSE

/**
 * Finalize a permanent item purchase
 * Adds item to player's inventory and records in database
 *
 * @param buyer - The client purchasing the item
 * @return TRUE if successful, FALSE if database operation failed
 */
/datum/store_item/proc/finalize_purchase(client/buyer)
	SHOULD_CALL_PARENT(TRUE)

	var/fail_message = span_warning("Failed to add purchase to database. You have not been charged.")

	if(!SSdbcore.IsConnected())
		to_chat(buyer, span_warning("DEBUG: SSdbcore not connected"))
		to_chat(buyer, fail_message)
		return FALSE

	if(!buyer?.prefs)
		to_chat(buyer, span_warning("DEBUG: buyer.prefs is null"))
		to_chat(buyer, fail_message)
		return FALSE

	// Add to inventory
	buyer.prefs.inventory += item_path

	// Insert into database using INSERT ... ON DUPLICATE KEY UPDATE (like ship_economy_db)
	var/table_name = format_table_name("player_shop_purchases")
	to_chat(buyer, span_notice("DEBUG: Inserting into table [table_name] - ckey=[buyer.ckey], item_id=[item_path]"))

	var/datum/db_query/query_add_gear_purchase = SSdbcore.NewQuery(
		"INSERT INTO [table_name] (`ckey`, `item_id`, `amount`) \
		VALUES (:ckey, :item_id, :amount) \
		ON DUPLICATE KEY UPDATE amount = amount + :amount",
		list("ckey" = buyer.ckey, "item_id" = "[item_path]", "amount" = 1)
	)

	if(!query_add_gear_purchase.Execute())
		to_chat(buyer, span_warning("DEBUG: Query.Execute() returned FALSE"))
		to_chat(buyer, fail_message)
		qdel(query_add_gear_purchase)
		buyer.prefs.inventory -= item_path // Rollback inventory change
		return FALSE

	to_chat(buyer, span_notice("DEBUG: Query.Execute() returned TRUE"))
	qdel(query_add_gear_purchase)

	// Save preferences to persist inventory changes
	buyer.prefs.save_character()

	return TRUE

/**
 * Generate a list of singleton store_item datums from all subtypes of [type_to_generate]
 * Populates the appropriate global list with instantiated datums
 *
 * @param type_to_generate - The base type to generate items from
 * @return List of generated singleton datums
 */
/proc/generate_store_items(type_to_generate)
	RETURN_TYPE(/list)

	. = list()
	if(!ispath(type_to_generate))
		CRASH("generate_store_items(): called with an invalid or null path as an argument!")

	for(var/datum/store_item/found_type as anything in subtypesof(type_to_generate))
		/// Any item without a name is "abstract" and should be skipped
		if(isnull(initial(found_type.name)))
			continue

		if(!ispath(initial(found_type.item_path)))
			stack_trace("generate_store_items(): Attempted to instantiate a store item ([initial(found_type.name)]) with an invalid or null typepath! (got path: [initial(found_type.item_path)])")
			continue

		var/datum/store_item/spawned_type = new found_type()
		GLOB.all_store_items[spawned_type.item_path] = spawned_type
		. |= spawned_type
