/**
 * Custom Slot Manager
 *
 * Manages custom spawn slots for players.
 * - 3 slots per account (slot 1 free, slot 2 costs 10000, slot 3 costs 25000)
 * - Each slot has: name, loadout, and active status
 * - Access is determined by the job the player spawns as (not overridden)
 *
 * Database Tables:
 * - player_custom_slots: Stores slot ownership and configuration
 */

// Slot costs
#define SLOT_1_COST 0      // Free
#define SLOT_2_COST 10000
#define SLOT_3_COST 25000

// Singleton custom slot manager - initialized automatically on first access
GLOBAL_DATUM_INIT(custom_slot_manager, /datum/custom_slot_manager, new)

/**
 * Singleton manager for custom spawn slots
 * Access via GLOB.custom_slot_manager
 */
/datum/custom_slot_manager
	/// Cache for slots by ckey
	var/list/slot_cache = list()
	/// Cache for equipment by ckey
	var/list/equipment_cache = list()
	/// Last cache update time by ckey
	var/list/cache_times = list()
	/// Cache validity duration in deciseconds (5 minutes)
	var/cache_duration = 3000
	/// Current round ID cache
	var/cached_round_id = null
	/// Round ID cache time
	var/round_id_cache_time = 0

/**
 * Initialize the singleton instance
 */
/datum/custom_slot_manager/New()
	. = ..()

/**
 * Get all slots for a player (creates slot 1 if doesn't exist)
 *
 * @param ckey - The player's ckey
 * @return List of slot data, each containing: slot_index, slot_name, access_preset, purchased
 */
/datum/custom_slot_manager/proc/get_player_slots(ckey)
	if(!ckey)
		return list()

	ckey = ckey(ckey) // Normalize ckey

	// Check cache
	if(is_cache_valid(ckey, "slots"))
		return slot_cache[ckey]?.Copy()

	// If database isn't connected, return a synthetic slot 1 so UI still works
	if(!SSdbcore.IsConnected())
		return list(list(
			"slot_index" = 1,
			"slot_name" = "Custom Slot 1",
			"access_preset" = "",
			"purchased" = TRUE,
			"is_default" = FALSE,
			"overwrite_spawn" = FALSE
		))

	var/list/slots = list()

	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT slot_index, slot_name, access_preset, unlocked, is_default, overwrite_spawn FROM [format_table_name("player_custom_slots")] \
		WHERE ckey = :ckey ORDER BY slot_index ASC",
		list("ckey" = ckey)
	)

	if(!query.Execute())
		qdel(query)
		return slots

	while(query.NextRow())
		slots += list(list(
			"slot_index" = text2num(query.item[1]),
			"slot_name" = query.item[2],
			"access_preset" = query.item[3],
			"purchased" = text2num(query.item[4]),  // DB column is 'unlocked', we map to 'purchased' internally
			"is_default" = text2num(query.item[5]),
			"overwrite_spawn" = text2num(query.item[6])
		))

	qdel(query)

	// Ensure slot 1 always exists (it's free)
	var/has_slot_1 = FALSE
	for(var/list/slot in slots)
		if(slot["slot_index"] == 1)
			has_slot_1 = TRUE
			break

	if(!has_slot_1)
		// Try to create slot 1 in database
		if(create_default_slot(ckey))
			// Fetch again after creating slot 1
			return get_player_slots(ckey)
		else
			// Database creation failed, add a synthetic slot 1 so UI still works
			slots = list(list(
				"slot_index" = 1,
				"slot_name" = "Custom Slot 1",
				"access_preset" = "",
				"purchased" = TRUE,
				"is_default" = FALSE,
				"overwrite_spawn" = FALSE
			)) + slots

	// Update cache
	slot_cache[ckey] = slots.Copy()
	update_cache_time(ckey, "slots")

	return slots

/**
 * Create the default free slot (slot 1) for a new player
 *
 * @param ckey - The player's ckey
 * @return TRUE if successful, FALSE otherwise
 */
/datum/custom_slot_manager/proc/create_default_slot(ckey)
	if(!ckey)
		return FALSE

	ckey = ckey(ckey)

	if(!SSdbcore.IsConnected())
		return FALSE

	// Use INSERT...ON DUPLICATE KEY UPDATE to handle race conditions and re-runs
	var/datum/db_query/query = SSdbcore.NewQuery(
		"INSERT INTO [format_table_name("player_custom_slots")] \
		(ckey, slot_index, slot_name, unlocked, unlock_date) \
		VALUES (:ckey, 1, 'Custom Slot 1', TRUE, NOW()) \
		ON DUPLICATE KEY UPDATE unlocked = TRUE",
		list("ckey" = ckey)
	)

	var/success = query.Execute()
	qdel(query)

	if(success)
		invalidate_cache(ckey, "slots")

	return success

/**
 * Purchase a slot (slot 2 or 3)
 *
 * @param ckey - The player's ckey
 * @param slot_index - Slot number (2 or 3)
 * @return TRUE if purchase successful, FALSE otherwise
 */
/datum/custom_slot_manager/proc/purchase_slot(ckey, slot_index)
	if(!ckey || slot_index < 2 || slot_index > 3)
		return FALSE

	ckey = ckey(ckey)

	if(!SSdbcore.IsConnected())
		return FALSE

	// Determine cost
	var/cost = 0
	switch(slot_index)
		if(2)
			cost = SLOT_2_COST
		if(3)
			cost = SLOT_3_COST
		else
			return FALSE

	// Check if slot already purchased
	var/list/slots = get_player_slots(ckey)
	for(var/list/slot in slots)
		if(slot["slot_index"] == slot_index)
			return FALSE

	// Check if player can afford it
	var/current_credits = GLOB.ship_economy_db.get_credits(ckey)
	if(current_credits < cost)
		return FALSE

	// Create the slot
	var/datum/db_query/query = SSdbcore.NewQuery(
		"INSERT INTO [format_table_name("player_custom_slots")] \
		(ckey, slot_index, slot_name, unlocked, unlock_date) \
		VALUES (:ckey, :index, :name, TRUE, NOW())",
		list(
			"ckey" = ckey,
			"index" = slot_index,
			"name" = "Custom Slot [slot_index]"
		)
	)

	if(!query.Execute())
		qdel(query)
		return FALSE

	qdel(query)

	// Deduct credits
	var/datum/db_query/credit_query = SSdbcore.NewQuery(
		"UPDATE [format_table_name("player_ship_credits")] SET credits = credits - :cost WHERE ckey = :ckey",
		list("ckey" = ckey, "cost" = cost)
	)
	credit_query.Execute()
	qdel(credit_query)

	// Invalidate caches
	GLOB.ship_economy_db.invalidate_cache(ckey, "credits")
	invalidate_cache(ckey, "slots")

	return TRUE

/**
 * Configure a slot (name only - access comes from the job)
 *
 * @param ckey - The player's ckey
 * @param slot_index - Slot number (1-3)
 * @param slot_name - New name for the slot
 * @return TRUE if successful, FALSE otherwise
 */
/datum/custom_slot_manager/proc/configure_slot(ckey, slot_index, slot_name)
	if(!ckey || slot_index < 1 || slot_index > 3)
		return FALSE

	ckey = ckey(ckey)

	// Sanitize slot name (limit length)
	slot_name = copytext(slot_name, 1, 51) // Max 50 characters

	if(!SSdbcore.IsConnected())
		return FALSE

	// Check if slot exists and is purchased - this will auto-create slot 1 if needed
	var/list/slots = get_player_slots(ckey)
	var/slot_exists = FALSE
	for(var/list/slot in slots)
		if(slot["slot_index"] == slot_index)
			slot_exists = TRUE
			break

	if(!slot_exists)
		return FALSE

	// Update slot configuration (name only)
	var/datum/db_query/query = SSdbcore.NewQuery(
		"UPDATE [format_table_name("player_custom_slots")] \
		SET slot_name = :name \
		WHERE ckey = :ckey AND slot_index = :index",
		list(
			"ckey" = ckey,
			"index" = slot_index,
			"name" = slot_name
		)
	)

	var/success = query.Execute()
	qdel(query)

	if(success)
		invalidate_cache(ckey, "slots")

	return success

/**
 * Save a loadout configuration to a custom slot
 *
 * @param ckey - The player's ckey
 * @param slot_index - Slot number (1-3)
 * @param loadout_list - List of loadout items to save
 * @return TRUE if successful, FALSE otherwise
 */
/datum/custom_slot_manager/proc/save_slot_loadout(ckey, slot_index, list/loadout_list)
	if(!ckey || slot_index < 1 || slot_index > 3)
		return FALSE

	ckey = ckey(ckey)

	if(!SSdbcore.IsConnected())
		return FALSE

	// Check if slot exists and is owned
	if(!is_slot_owned(ckey, slot_index))
		return FALSE

	// Convert loadout list to JSON
	var/loadout_json = json_encode(loadout_list)

	// Update slot with loadout
	var/datum/db_query/query = SSdbcore.NewQuery(
		"UPDATE [format_table_name("player_custom_slots")] \
		SET loadout_json = :loadout \
		WHERE ckey = :ckey AND slot_index = :index",
		list(
			"ckey" = ckey,
			"index" = slot_index,
			"loadout" = loadout_json
		)
	)

	var/success = query.Execute()
	qdel(query)

	if(success)
		invalidate_cache(ckey, "slots")

	return success

/**
 * Get the saved loadout for a custom slot
 *
 * @param ckey - The player's ckey
 * @param slot_index - Slot number (1-3)
 * @return List of loadout items or empty list
 */
/datum/custom_slot_manager/proc/get_slot_loadout(ckey, slot_index)
	if(!ckey || slot_index < 1 || slot_index > 3)
		return list()

	ckey = ckey(ckey)

	if(!SSdbcore.IsConnected())
		return list()

	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT loadout_json FROM [format_table_name("player_custom_slots")] \
		WHERE ckey = :ckey AND slot_index = :index",
		list("ckey" = ckey, "index" = slot_index)
	)

	if(!query.Execute())
		qdel(query)
		return list()

	var/list/loadout = list()
	if(query.NextRow())
		var/json_data = query.item[1]
		if(json_data)
			try
				loadout = json_decode(json_data)
			catch
				// Invalid JSON, return empty list

	qdel(query)
	return loadout

/**
 * Get equipment for a slot this round
 *
 * @param ckey - The player's ckey
 * @param slot_index - Slot number (1-3)
 * @return List of equipment item paths
 */
/datum/custom_slot_manager/proc/get_slot_equipment(ckey, slot_index)
	if(!ckey || slot_index < 1 || slot_index > 3)
		return list()

	ckey = ckey(ckey)

	var/round_id = get_round_id()
	if(!round_id)
		return list()

	// Check cache
	var/cache_key = "[ckey]_[slot_index]_[round_id]"
	if(is_cache_valid(cache_key, "equipment"))
		return equipment_cache[cache_key]?.Copy()

	if(!SSdbcore.IsConnected())
		return list()

	var/list/equipment = list()

	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT item_path FROM [format_table_name("player_custom_slot_equipment")] \
		WHERE ckey = :ckey AND slot_index = :index AND round_id = :round",
		list("ckey" = ckey, "index" = slot_index, "round" = round_id)
	)

	if(!query.Execute())
		qdel(query)
		return equipment

	while(query.NextRow())
		equipment += query.item[1]

	qdel(query)

	// Update cache
	equipment_cache[cache_key] = equipment.Copy()
	update_cache_time(cache_key, "equipment")

	return equipment

/**
 * Purchase per-round equipment for a slot
 *
 * @param ckey - The player's ckey
 * @param slot_index - Slot number (1-3)
 * @param item_path - Item typepath to purchase
 * @param cost - Cost in credits
 * @return TRUE if purchase successful, FALSE otherwise
 */
/datum/custom_slot_manager/proc/purchase_equipment(ckey, slot_index, item_path, cost)
	if(!ckey || slot_index < 1 || slot_index > 3 || !item_path)
		return FALSE

	ckey = ckey(ckey)

	var/round_id = get_round_id()
	if(!round_id)
		return FALSE

	if(!SSdbcore.IsConnected())
		return FALSE

	// Verify slot ownership
	var/list/slots = get_player_slots(ckey)
	var/slot_exists = FALSE
	for(var/list/slot in slots)
		if(slot["slot_index"] == slot_index)
			slot_exists = TRUE
			break

	if(!slot_exists)
		return FALSE

	// Check if player can afford it
	var/current_credits = GLOB.ship_economy_db.get_credits(ckey)
	if(current_credits < cost)
		return FALSE

	// Check if already purchased this item for this slot this round
	var/list/current_equipment = get_slot_equipment(ckey, slot_index)
	if(item_path in current_equipment)
		return FALSE

	// Insert equipment record
	var/datum/db_query/query = SSdbcore.NewQuery(
		"INSERT INTO [format_table_name("player_custom_slot_equipment")] \
		(ckey, slot_index, round_id, item_path) \
		VALUES (:ckey, :index, :round, :item)",
		list(
			"ckey" = ckey,
			"index" = slot_index,
			"round" = round_id,
			"item" = item_path
		)
	)

	if(!query.Execute())
		qdel(query)
		return FALSE

	qdel(query)

	// Deduct credits
	var/datum/db_query/credit_query = SSdbcore.NewQuery(
		"UPDATE [format_table_name("player_ship_credits")] SET credits = credits - :cost WHERE ckey = :ckey",
		list("ckey" = ckey, "cost" = cost)
	)
	credit_query.Execute()
	qdel(credit_query)

	// Invalidate caches
	GLOB.ship_economy_db.invalidate_cache(ckey, "credits")
	var/cache_key = "[ckey]_[slot_index]_[round_id]"
	invalidate_cache(cache_key, "equipment")

	return TRUE

/**
 * Get current round ID
 * Uses cached value to avoid excessive database queries
 *
 * @return Round ID or null if unavailable
 */
/datum/custom_slot_manager/proc/get_round_id()
	// Check if cached round ID is still valid (cache for 1 minute)
	if(cached_round_id && (world.time - round_id_cache_time) < 600)
		return cached_round_id

	if(!SSdbcore.IsConnected())
		return null

	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT MAX(id) FROM [format_table_name("round")]"
	)

	if(!query.Execute())
		qdel(query)
		return null

	var/round_id = null
	if(query.NextRow())
		round_id = text2num(query.item[1])

	qdel(query)

	// Update cache
	if(round_id)
		cached_round_id = round_id
		round_id_cache_time = world.time

	return round_id

/**
 * Get the cost for purchasing a specific slot
 *
 * @param slot_index - Slot number (1-3)
 * @return Cost in credits
 */
/datum/custom_slot_manager/proc/get_slot_cost(slot_index)
	switch(slot_index)
		if(1)
			return SLOT_1_COST
		if(2)
			return SLOT_2_COST
		if(3)
			return SLOT_3_COST
		else
			return 0

/**
 * Check if a slot is owned by a player
 *
 * @param ckey - The player's ckey
 * @param slot_index - Slot number (1-3)
 * @return TRUE if owned, FALSE otherwise
 */
/datum/custom_slot_manager/proc/is_slot_owned(ckey, slot_index)
	if(!ckey || slot_index < 1 || slot_index > 3)
		return FALSE

	var/list/slots = get_player_slots(ckey)
	for(var/list/slot in slots)
		if(slot["slot_index"] == slot_index)
			return TRUE

	return FALSE

/**
 * Set a slot as the default/active slot (unsets any other default)
 *
 * @param ckey - The player's ckey
 * @param slot_index - Slot number (1-3) to set as default, or 0 to clear default
 * @return TRUE if successful, FALSE otherwise
 */
/datum/custom_slot_manager/proc/set_default_slot(ckey, slot_index)
	if(!ckey)
		return FALSE

	ckey = ckey(ckey)

	if(!SSdbcore.IsConnected())
		return FALSE

	// First, unset all defaults AND overwrite_spawn flags for this player
	// (overwrite_spawn is legacy from old two-button system, now unified into is_default)
	var/datum/db_query/clear_query = SSdbcore.NewQuery(
		"UPDATE [format_table_name("player_custom_slots")] SET is_default = FALSE, overwrite_spawn = FALSE WHERE ckey = :ckey",
		list("ckey" = ckey)
	)
	clear_query.Execute()
	qdel(clear_query)

	// If slot_index is 0 or invalid, we just cleared all defaults
	if(slot_index < 1 || slot_index > 3)
		invalidate_cache(ckey, "slots")
		return TRUE

	// Check ownership
	if(!is_slot_owned(ckey, slot_index))
		return FALSE

	// Set the new default
	var/datum/db_query/set_query = SSdbcore.NewQuery(
		"UPDATE [format_table_name("player_custom_slots")] SET is_default = TRUE WHERE ckey = :ckey AND slot_index = :index",
		list("ckey" = ckey, "index" = slot_index)
	)
	var/success = set_query.Execute()
	qdel(set_query)

	if(success)
		invalidate_cache(ckey, "slots")

	return success

/**
 * Get the player's active (default) slot
 * Returns the slot that should be used for spawning
 *
 * @param ckey - The player's ckey
 * @return List with slot data if found, null otherwise
 */
/datum/custom_slot_manager/proc/get_active_slot(ckey)
	if(!ckey)
		return null

	var/list/slots = get_player_slots(ckey)
	if(!slots || !slots.len)
		return null

	// Return the slot marked as default (active)
	for(var/list/slot in slots)
		if(slot["is_default"])
			return slot

	return null

//
// Cache management helpers
//

/**
 * Check if cache is valid for a given key and type
 */
/datum/custom_slot_manager/proc/is_cache_valid(cache_key, cache_type)
	if(!cache_times[cache_key])
		return FALSE

	var/list/times = cache_times[cache_key]
	if(!times[cache_type])
		return FALSE

	return (world.time - times[cache_type]) < cache_duration

/**
 * Update cache timestamp
 */
/datum/custom_slot_manager/proc/update_cache_time(cache_key, cache_type)
	if(!cache_times[cache_key])
		cache_times[cache_key] = list()

	cache_times[cache_key][cache_type] = world.time

/**
 * Invalidate cache for a key
 */
/datum/custom_slot_manager/proc/invalidate_cache(cache_key, cache_type = null)
	if(!cache_type)
		// Invalidate all caches for this key
		slot_cache -= cache_key
		equipment_cache -= cache_key
		cache_times -= cache_key
	else
		// Invalidate specific cache type
		switch(cache_type)
			if("slots")
				slot_cache -= cache_key
			if("equipment")
				equipment_cache -= cache_key

		if(cache_times[cache_key])
			cache_times[cache_key] -= cache_type

/**
 * Clear all caches (useful for debugging or admin commands)
 */
/datum/custom_slot_manager/proc/clear_all_caches()
	slot_cache.Cut()
	equipment_cache.Cut()
	cache_times.Cut()
	cached_round_id = null
	round_id_cache_time = 0

// Undefine local defines
#undef SLOT_1_COST
#undef SLOT_2_COST
#undef SLOT_3_COST
