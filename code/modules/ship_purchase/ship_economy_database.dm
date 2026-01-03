/**
 * Ship Economy Database Access Layer
 *
 * This datum provides database access for the ship purchase system.
 * Based on user decisions:
 * - Account-wide credits (ckey only, no character_slot)
 * - Part classes: combat, science, trade, misc
 * - Parts must be extracted via bluespace jump or round end
 * - Pending extractions queue for failed extraction retry
 * - Account-wide ship unlocks
 *
 * Database Tables:
 * - player_ship_credits: Account-wide credits
 * - player_ship_parts: Account-wide parts inventory (by class)
 * - player_ship_unlocks: Permanent ship blueprint unlocks
 * - pending_ship_extractions: Queue for failed part extractions
 * - ship_extraction_log: Audit trail for part extractions
 */

// Part class defines
#define PART_CLASS_COMBAT "combat"
#define PART_CLASS_SCIENCE "science"
#define PART_CLASS_TRADE "trade"
#define PART_CLASS_MISC "misc"

// List of all valid part classes
GLOBAL_LIST_INIT(ship_part_classes, list(
	PART_CLASS_COMBAT,
	PART_CLASS_SCIENCE,
	PART_CLASS_TRADE,
	PART_CLASS_MISC
))

// Singleton database access layer - initialized automatically on first access
GLOBAL_DATUM_INIT(ship_economy_db, /datum/ship_economy_db, new)

/**
 * Singleton database access layer for ship economy
 * Access via GLOB.ship_economy_db
 */
/datum/ship_economy_db
	/// Cache for credits by ckey
	var/list/credits_cache = list()
	/// Cache for parts by ckey
	var/list/parts_cache = list()
	/// Cache for unlocks by ckey
	var/list/unlocks_cache = list()
	/// Last cache update time by ckey
	var/list/cache_times = list()
	/// Cache validity duration in deciseconds (5 minutes)
	var/cache_duration = 3000

/**
 * Initialize the singleton instance
 */
/datum/ship_economy_db/New()
	. = ..()

/**
 * Get account-wide credits for a ckey
 *
 * @param ckey - The player's ckey
 * @return Integer credits amount, 0 if none
 */
/datum/ship_economy_db/proc/get_credits(ckey)
	if(!ckey)
		return 0

	ckey = ckey(ckey) // Normalize ckey

	// Check cache
	if(is_cache_valid(ckey, "credits"))
		return credits_cache[ckey] || 0

	if(!SSdbcore.IsConnected())
		return 0

	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT credits FROM [format_table_name("player_ship_credits")] WHERE ckey = :ckey",
		list("ckey" = ckey)
	)

	if(!query.Execute())
		qdel(query)
		return 0

	var/credits = 0
	if(query.NextRow())
		credits = text2num(query.item[1]) || 0

	qdel(query)

	// Update cache
	credits_cache[ckey] = credits
	update_cache_time(ckey, "credits")

	return credits

/**
 * Add or deduct credits from account (account-wide)
 *
 * @param ckey - The player's ckey
 * @param amount - Amount to add (positive) or deduct (negative)
 * @param reason - Reason for logging
 * @return TRUE if successful, FALSE otherwise
 */
/datum/ship_economy_db/proc/add_credits(ckey, amount, reason = "unspecified")
	if(!ckey)
		return FALSE

	ckey = ckey(ckey) // Normalize ckey

	if(!SSdbcore.IsConnected())
		return FALSE

	// Use INSERT ... ON DUPLICATE KEY UPDATE for MySQL/MariaDB
	var/datum/db_query/query = SSdbcore.NewQuery(
		"INSERT INTO [format_table_name("player_ship_credits")] (ckey, credits) \
		VALUES (:ckey, :amount) \
		ON DUPLICATE KEY UPDATE credits = credits + :amount",
		list("ckey" = ckey, "amount" = amount)
	)

	var/success = query.Execute()
	qdel(query)

	if(success)
		// Invalidate cache
		invalidate_cache(ckey, "credits")

		// Log the transaction
		log_game("SHIP_ECONOMY: [ckey] [amount > 0 ? "+" : ""][amount] credits - [reason]")

	return success

/**
 * Get parts inventory for a ckey
 * Returns associative list of class -> quantity
 *
 * @param ckey - The player's ckey
 * @return list("combat"=X, "science"=Y, "trade"=Z, "misc"=A)
 */
/datum/ship_economy_db/proc/get_parts(ckey)
	if(!ckey)
		return null

	ckey = ckey(ckey) // Normalize ckey

	// Check cache
	if(is_cache_valid(ckey, "parts"))
		return parts_cache[ckey]?.Copy() // Return copy to prevent external modification

	if(!SSdbcore.IsConnected())
		return null

	var/list/parts = list()
	// Initialize all classes to 0
	for(var/part_class in GLOB.ship_part_classes)
		parts[part_class] = 0

	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT part_class, quantity FROM [format_table_name("player_ship_parts")] WHERE ckey = :ckey",
		list("ckey" = ckey)
	)

	if(!query.Execute())
		qdel(query)
		return parts

	while(query.NextRow())
		var/part_class = query.item[1]
		var/quantity = text2num(query.item[2]) || 0

		if(part_class in GLOB.ship_part_classes)
			parts[part_class] = quantity

	qdel(query)

	// Update cache
	parts_cache[ckey] = parts.Copy()
	update_cache_time(ckey, "parts")

	return parts

/**
 * Add parts to account inventory
 *
 * @param ckey - The player's ckey
 * @param part_class - Part class (combat/science/trade/misc)
 * @param quantity - Number of parts to add (default 1)
 * @param method - Method of acquisition for logging
 * @return TRUE if successful, FALSE otherwise
 */
/datum/ship_economy_db/proc/add_part(ckey, part_class, quantity = 1, method = "unspecified")
	if(!ckey || !part_class)
		return FALSE

	ckey = ckey(ckey) // Normalize ckey

	// Validate class
	if(!(part_class in GLOB.ship_part_classes))
		stack_trace("Invalid part class '[part_class]' passed to add_part()")
		return FALSE

	if(!SSdbcore.IsConnected())
		return FALSE

	var/datum/db_query/query = SSdbcore.NewQuery(
		"INSERT INTO [format_table_name("player_ship_parts")] (ckey, part_class, quantity) \
		VALUES (:ckey, :part_class, :quantity) \
		ON DUPLICATE KEY UPDATE quantity = quantity + :quantity",
		list("ckey" = ckey, "part_class" = part_class, "quantity" = quantity)
	)

	var/success = query.Execute()
	qdel(query)

	if(success)
		// Invalidate cache
		invalidate_cache(ckey, "parts")

		// Log the addition
		log_game("SHIP_ECONOMY: [ckey] +[quantity] [part_class] part(s) - [method]")

	return success

/**
 * Spend parts from account for blueprint unlock
 * Deducts parts and checks if sufficient quantity exists
 *
 * @param ckey - The player's ckey
 * @param requirements - Associative list of class -> quantity needed
 * @return TRUE if successful, FALSE if insufficient parts or error
 */
/datum/ship_economy_db/proc/spend_parts(ckey, list/requirements)
	if(!ckey || !requirements || !islist(requirements))
		return FALSE

	ckey = ckey(ckey) // Normalize ckey

	if(!SSdbcore.IsConnected())
		return FALSE

	// First, check if player has sufficient parts
	var/list/current_parts = get_parts(ckey)
	if(!current_parts)
		return FALSE

	for(var/part_class in requirements)
		var/needed = requirements[part_class]
		var/have = current_parts[part_class] || 0

		if(have < needed)
			log_game("SHIP_ECONOMY: [ckey] insufficient [part_class] parts (have: [have], need: [needed])")
			return FALSE

	// Deduct each class
	for(var/part_class in requirements)
		var/amount = requirements[part_class]

		var/datum/db_query/query = SSdbcore.NewQuery(
			"UPDATE [format_table_name("player_ship_parts")] \
			SET quantity = quantity - :amount \
			WHERE ckey = :ckey AND part_class = :part_class AND quantity >= :amount",
			list("ckey" = ckey, "part_class" = part_class, "amount" = amount)
		)

		if(!query.Execute() || query.affected < 1)
			qdel(query)
			log_game("SHIP_ECONOMY: [ckey] failed to deduct [amount] [part_class] parts (transaction failed)")
			return FALSE

		qdel(query)

	// Invalidate cache
	invalidate_cache(ckey, "parts")

	// Log successful spending
	var/list/req_text = list()
	for(var/part_class in requirements)
		req_text += "[requirements[part_class]] [part_class]"
	log_game("SHIP_ECONOMY: [ckey] spent parts: [req_text.Join(", ")]")

	return TRUE

/**
 * Check if a ship template is unlocked for a player
 *
 * @param ckey - The player's ckey
 * @param ship_template - Ship template path or identifier
 * @return TRUE if unlocked, FALSE otherwise
 */
/datum/ship_economy_db/proc/is_ship_unlocked(ckey, ship_template)
	if(!ckey || !ship_template)
		return FALSE

	ckey = ckey(ckey) // Normalize ckey

	// Check cache
	if(is_cache_valid(ckey, "unlocks"))
		var/list/unlocks = unlocks_cache[ckey]
		return (ship_template in unlocks)

	if(!SSdbcore.IsConnected())
		return FALSE

	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT 1 FROM [format_table_name("player_ship_unlocks")] \
		WHERE ckey = :ckey AND ship_template_path = :template",
		list("ckey" = ckey, "template" = ship_template)
	)

	var/unlocked = FALSE
	if(query.Execute() && query.NextRow())
		unlocked = TRUE

	qdel(query)

	return unlocked

/**
 * Unlock a ship template for a player (permanent)
 *
 * @param ckey - The player's ckey
 * @param ship_template - Ship template path or identifier
 * @return TRUE if successful, FALSE otherwise
 */
/datum/ship_economy_db/proc/unlock_ship(ckey, ship_template)
	if(!ckey || !ship_template)
		return FALSE

	ckey = ckey(ckey) // Normalize ckey

	if(!SSdbcore.IsConnected())
		return FALSE

	// Check if already unlocked to avoid duplicate insert
	if(is_ship_unlocked(ckey, ship_template))
		return TRUE

	var/datum/db_query/query = SSdbcore.NewQuery(
		"INSERT INTO [format_table_name("player_ship_unlocks")] (ckey, ship_template_path) \
		VALUES (:ckey, :template) \
		ON DUPLICATE KEY UPDATE ship_template_path = ship_template_path",
		list("ckey" = ckey, "template" = ship_template)
	)

	var/success = query.Execute()
	qdel(query)

	if(success)
		// Invalidate cache
		invalidate_cache(ckey, "unlocks")

		// Log unlock
		log_game("SHIP_ECONOMY: [ckey] unlocked ship template: [ship_template]")

	return success

/**
 * Get list of all unlocked ships for a player
 *
 * @param ckey - The player's ckey
 * @return List of ship template paths
 */
/datum/ship_economy_db/proc/get_unlocked_ships(ckey)
	if(!ckey)
		return list()

	ckey = ckey(ckey) // Normalize ckey

	// Check cache
	if(is_cache_valid(ckey, "unlocks"))
		return unlocks_cache[ckey]?.Copy()

	if(!SSdbcore.IsConnected())
		return list()

	var/list/unlocks = list()

	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT ship_template_path FROM [format_table_name("player_ship_unlocks")] WHERE ckey = :ckey",
		list("ckey" = ckey)
	)

	if(!query.Execute())
		qdel(query)
		return unlocks

	while(query.NextRow())
		unlocks += query.item[1]

	qdel(query)

	// Update cache
	unlocks_cache[ckey] = unlocks.Copy()
	update_cache_time(ckey, "unlocks")

	return unlocks

/**
 * Queue a pending extraction for retry
 * Used when extraction fails due to database issues
 *
 * @param ckey - The player's ckey
 * @param part_class - Class of the part
 * @param part_uid - Unique identifier of the physical part (for tracking)
 * @return TRUE if queued successfully
 */
/datum/ship_economy_db/proc/queue_pending_extraction(ckey, part_class, part_uid)
	if(!ckey || !part_class)
		return FALSE

	ckey = ckey(ckey) // Normalize ckey

	if(!(part_class in GLOB.ship_part_classes))
		stack_trace("Invalid part class '[part_class]' in queue_pending_extraction()")
		return FALSE

	if(!SSdbcore.IsConnected())
		return FALSE

	var/datum/db_query/query = SSdbcore.NewQuery(
		"INSERT INTO [format_table_name("pending_ship_extractions")] \
		(ckey, part_class, part_uid, queued_at, retry_count) \
		VALUES (:ckey, :part_class, :uid, NOW(), 0)",
		list("ckey" = ckey, "part_class" = part_class, "uid" = part_uid)
	)

	var/success = query.Execute()
	qdel(query)

	if(success)
		log_game("SHIP_ECONOMY: Queued pending extraction for [ckey] - [part_class] part (UID: [part_uid])")

	return success

/**
 * Process all pending extractions
 * Attempts to retry failed extractions
 * Should be called periodically (e.g., on server init, or timer)
 *
 * @param max_retries - Maximum retry attempts before giving up (default 5)
 * @return Number of successfully processed extractions
 */
/datum/ship_economy_db/proc/process_pending_extractions(max_retries = 5)
	if(!SSdbcore.IsConnected())
		return 0

	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT id, ckey, part_class, part_uid, retry_count FROM [format_table_name("pending_ship_extractions")] \
		WHERE retry_count < :max_retries \
		ORDER BY queued_at ASC \
		LIMIT 100",
		list("max_retries" = max_retries)
	)

	if(!query.Execute())
		qdel(query)
		return 0

	var/processed = 0
	var/list/pending_entries = list()

	// Collect all pending entries
	while(query.NextRow())
		pending_entries += list(list(
			"id" = text2num(query.item[1]),
			"ckey" = query.item[2],
			"part_class" = query.item[3],
			"part_uid" = query.item[4],
			"retry_count" = text2num(query.item[5])
		))

	qdel(query)

	// Process each pending extraction
	for(var/list/entry in pending_entries)
		var/id = entry["id"]
		var/entry_ckey = entry["ckey"]
		var/part_class = entry["part_class"]
		var/uid = entry["part_uid"]
		var/retries = entry["retry_count"]

		// Attempt to add the part
		if(add_part(entry_ckey, part_class, 1, "pending_extraction_retry"))
			// Success - remove from pending queue
			var/datum/db_query/delete_query = SSdbcore.NewQuery(
				"DELETE FROM [format_table_name("pending_ship_extractions")] WHERE id = :id",
				list("id" = id)
			)
			delete_query.Execute()
			qdel(delete_query)

			// Log to extraction log
			log_extraction(entry_ckey, part_class, "pending_retry_success", uid)

			processed++
			log_game("SHIP_ECONOMY: Successfully processed pending extraction [id] for [entry_ckey] ([part_class])")
		else
			// Failed - increment retry count
			var/datum/db_query/update_query = SSdbcore.NewQuery(
				"UPDATE [format_table_name("pending_ship_extractions")] \
				SET retry_count = retry_count + 1, last_retry_at = NOW() \
				WHERE id = :id",
				list("id" = id)
			)
			update_query.Execute()
			qdel(update_query)

			if(retries + 1 >= max_retries)
				log_game("SHIP_ECONOMY: Pending extraction [id] for [entry_ckey] exceeded max retries ([max_retries])")

	return processed

/**
 * Log a part extraction to audit trail
 *
 * @param ckey - Player's ckey
 * @param part_class - Class of extracted part
 * @param extraction_location - Location description for analytics
 * @param part_uid - Unique identifier of the part (optional)
 */
/datum/ship_economy_db/proc/log_extraction(ckey, part_class, extraction_location = "unknown", part_uid = null)
	if(!ckey || !part_class)
		return

	ckey = ckey(ckey)

	if(!SSdbcore.IsConnected())
		return

	var/datum/db_query/query = SSdbcore.NewQuery(
		"INSERT INTO [format_table_name("ship_extraction_log")] \
		(ckey, part_class, extraction_location, part_uid, extraction_timestamp) \
		VALUES (:ckey, :part_class, :location, :uid, NOW())",
		list(
			"ckey" = ckey,
			"part_class" = part_class,
			"location" = extraction_location,
			"uid" = part_uid
		)
	)

	query.Execute()
	qdel(query)

//
// Cache management helpers
//

/**
 * Check if cache is valid for a given ckey and type
 */
/datum/ship_economy_db/proc/is_cache_valid(ckey, cache_type)
	if(!cache_times[ckey])
		return FALSE

	var/list/times = cache_times[ckey]
	if(!times[cache_type])
		return FALSE

	return (world.time - times[cache_type]) < cache_duration

/**
 * Update cache timestamp
 */
/datum/ship_economy_db/proc/update_cache_time(ckey, cache_type)
	if(!cache_times[ckey])
		cache_times[ckey] = list()

	cache_times[ckey][cache_type] = world.time

/**
 * Invalidate cache for a ckey
 */
/datum/ship_economy_db/proc/invalidate_cache(ckey, cache_type = null)
	if(!cache_type)
		// Invalidate all caches for this ckey
		credits_cache -= ckey
		parts_cache -= ckey
		unlocks_cache -= ckey
		cache_times -= ckey
	else
		// Invalidate specific cache type
		switch(cache_type)
			if("credits")
				credits_cache -= ckey
			if("parts")
				parts_cache -= ckey
			if("unlocks")
				unlocks_cache -= ckey

		if(cache_times[ckey])
			cache_times[ckey] -= cache_type

/**
 * Clear all caches (useful for debugging or admin commands)
 */
/datum/ship_economy_db/proc/clear_all_caches()
	credits_cache.Cut()
	parts_cache.Cut()
	unlocks_cache.Cut()
	cache_times.Cut()
	log_admin("SHIP_ECONOMY: All caches cleared")
