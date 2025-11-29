/**
 * Voidcrew Player Shop System - Preferences Integration
 *
 * Handles loading/saving player shop inventory and spawning roundstart items.
 * Integrates with the player_shop_purchases database table.
 *
 * Key functionality:
 * - Loads purchased items from database into preferences.inventory
 * - Spawns permanent (non-one-time) items at roundstart
 * - Hooks into existing preference and character spawning systems
 *
 * Note: The inventory var is defined in voidcrew/modules/store/preferences.dm
 */

/**
 * Load player's shop inventory from database
 * Called when preferences are loaded to populate the inventory list
 *
 * @param ckey - The player's ckey to load inventory for
 */
/datum/preferences/proc/load_shop_inventory(ckey)
	// Clear any existing inventory first (prevents stale data from persisting in memory)
	inventory.Cut()

	if(!ckey || !SSdbcore.IsConnected())
		return

	// Query the player_shop_purchases table for this player's purchases
	var/datum/db_query/query_inventory = SSdbcore.NewQuery(
		"SELECT item_id FROM [format_table_name("player_shop_purchases")] WHERE ckey = :ckey",
		list("ckey" = ckey)
	)

	if(!query_inventory.Execute())
		qdel(query_inventory)
		return

	// Populate inventory list with item paths
	while(query_inventory.NextRow())
		var/item_path_text = query_inventory.item[1]
		var/item_path = text2path(item_path_text)
		if(item_path)
			inventory += item_path
		else
			stack_trace("load_shop_inventory(): Invalid item path in database for [ckey]: [item_path_text]")

	qdel(query_inventory)

/**
 * Save player's shop inventory to database
 * Currently handled by store_item.dm's finalize_purchase() - this is a stub for future use
 *
 * @param ckey - The player's ckey to save inventory for
 */
/datum/preferences/proc/save_shop_inventory(ckey)
	// Currently unused - purchases are saved immediately when made via store_item/proc/finalize_purchase()
	// This stub exists for potential future batch saving or migration needs
	return

/**
 * Spawn purchased items for the player at roundstart
 * Spawns both permanent items and one-time items
 * One-time items are removed from DB after spawning
 *
 * @param player - The mob to spawn items for
 */
/datum/preferences/proc/spawn_shop_items(mob/living/player)
	if(!player || !player.client)
		return

	if(!length(inventory))
		return // No items to spawn

	var/list/items_spawned = list()
	var/list/items_failed = list()
	var/list/one_time_items_to_remove = list()

	for(var/item_path in inventory)
		// Look up the store_item datum for this path
		var/datum/store_item/store_datum = GLOB.all_store_items[item_path]

		if(!store_datum)
			// Item path is in inventory but not in store items list
			// This could happen if an item was removed from the store
			stack_trace("spawn_shop_items(): Item path [item_path] in [player.client.ckey]'s inventory but not found in GLOB.all_store_items")
			continue

		// Try to spawn the item
		var/obj/item/spawned_item = new item_path(player.loc)

		if(!spawned_item)
			items_failed += store_datum.name
			continue

		// Track one-time items for removal after spawning
		if(store_datum.one_time_buy)
			one_time_items_to_remove += item_path

		// Try to equip the item to the player
		// First try to put it in their backpack, then hands, then just drop it
		var/equipped = FALSE

		// Try backpack first (for humans)
		if(ishuman(player))
			var/mob/living/carbon/human/human_player = player
			if(human_player.back && istype(human_player.back, /obj/item/storage))
				var/obj/item/storage/backpack = human_player.back
				if(backpack.atom_storage?.attempt_insert(spawned_item, player, override = TRUE))
					equipped = TRUE

		// Try hands if backpack failed
		if(!equipped)
			if(player.put_in_hands(spawned_item))
				equipped = TRUE

		// If both failed, item will remain at player's location
		if(equipped)
			items_spawned += store_datum.name
		else
			items_spawned += "[store_datum.name] (at feet)"

	// Remove one-time items from inventory and database
	if(length(one_time_items_to_remove))
		remove_one_time_items(player.client.ckey, one_time_items_to_remove)

	// Notify player of spawned items
	if(length(items_spawned))
		to_chat(player, span_notice("Your purchased shop items have been spawned: [english_list(items_spawned)]"))

	if(length(items_failed))
		to_chat(player, span_warning("Failed to spawn some shop items: [english_list(items_failed)]"))

/**
 * Remove one-time items from inventory and database after they've been spawned
 *
 * @param ckey - The player's ckey
 * @param items_to_remove - List of item paths to remove
 */
/datum/preferences/proc/remove_one_time_items(ckey, list/items_to_remove)
	if(!length(items_to_remove) || !SSdbcore.IsConnected())
		return

	for(var/item_path in items_to_remove)
		// Remove from local inventory
		inventory -= item_path

		// Remove from database
		var/datum/db_query/query_remove = SSdbcore.NewQuery(
			"DELETE FROM [format_table_name("player_shop_purchases")] WHERE ckey = :ckey AND item_id = :item_id",
			list("ckey" = ckey, "item_id" = "[item_path]")
		)
		query_remove.Execute()
		qdel(query_remove)

// Hook into preferences loading to load shop inventory
/datum/preferences/load_preferences()
	. = ..()
	if(. && parent) // Only load if preferences loaded successfully and we have a parent client
		load_shop_inventory(parent.ckey)

// Hook into roundstart character spawning to spawn shop items after equipment
/datum/job/after_roundstart_spawn(mob/living/spawning, client/player_client)
	. = ..()
	// Spawn shop items after job equipment is complete
	if(player_client?.prefs && ishuman(spawning))
		player_client.prefs.spawn_shop_items(spawning)

// Hook into latejoin character spawning to spawn shop items after equipment
/datum/job/after_latejoin_spawn(mob/living/spawning)
	. = ..()
	// Spawn shop items after job equipment is complete
	if(spawning.client?.prefs && ishuman(spawning))
		spawning.client.prefs.spawn_shop_items(spawning)
