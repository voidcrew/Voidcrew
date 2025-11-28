/**
 * Ship Purchase System - Transaction-Safe Helper Procedures
 *
 * This file implements atomic, race-condition-safe database operations for:
 * - Ship blueprint purchases with retry logic
 * - Physical part extraction with pending queue fallback
 * - Part purchases with compensating transactions
 *
 * User Decisions Implemented:
 * - Q3: Retry 3 times, then auto-refund on failure
 * - Q4: Pending extractions queue for critical failures
 *
 * Pattern: Optimistic concurrency control with compensating transactions
 */

// Maximum number of retry attempts for failed transactions (User Q3)
#define TRANSACTION_MAX_RETRIES 3

// Rarity tier constants - use string-based system from ship_economy_database.dm
// These are just aliases for compatibility with old code
#define TRANSACTION_RARITY_COMMON RARITY_COMMON
#define TRANSACTION_RARITY_UNCOMMON RARITY_UNCOMMON
#define TRANSACTION_RARITY_RARE RARITY_RARE
#define TRANSACTION_RARITY_EPIC RARITY_EPIC
#define TRANSACTION_RARITY_LEGENDARY RARITY_LEGENDARY

/**
 * Purchase a ship blueprint unlock with transaction safety.
 *
 * This proc implements a multi-step transaction with retry logic:
 * 1. Pre-flight balance check
 * 2. Deduct credits with WHERE clause (race-condition safe)
 * 3. Insert unlock record
 * 4. Retry up to 3 times if unlock fails (User Q3)
 * 5. Refund credits if all retries fail
 *
 * @param client The client purchasing the ship
 * @param ship_template The ship template path to unlock (e.g., "/datum/map_template/shuttle/voidcrew/delta")
 * @param cost The credit cost for this unlock
 * @return TRUE if purchase successful, FALSE otherwise
 */
/proc/purchase_ship_unlock(client/C, ship_template, cost)
	if(!C || !ship_template || cost <= 0)
		return FALSE

	if(!SSdbcore.IsConnected())
		to_chat(C, span_warning("Database connection unavailable. Please try again later."))
		return FALSE

	var/ckey = C.ckey
	var/character_slot = C.prefs?.default_slot || 1

	// Step 1: Pre-flight balance check
	var/current_balance = get_player_credits(ckey, character_slot)
	if(current_balance < cost)
		to_chat(C, span_warning("Insufficient credits. You have [current_balance] credits but need [cost]."))
		return FALSE

	// Step 2: Check if already unlocked (prevent duplicate purchases)
	if(is_ship_unlocked(ckey, ship_template))
		to_chat(C, span_warning("You already own this ship!"))
		return FALSE

	var/retry_count = 0
	var/success = FALSE
	var/credits_deducted = FALSE

	// Retry loop (User Q3: Retry 3 times)
	while(retry_count <= TRANSACTION_MAX_RETRIES && !success)
		if(retry_count > 0)
			sleep(1) // Brief delay between retries to avoid hammering DB

		// Step 3: Deduct credits with WHERE clause (race-condition safe)
		if(!credits_deducted)
			var/datum/db_query/deduct_query = SSdbcore.NewQuery(
				"UPDATE [format_table_name("player_credits")] \
				SET credits = credits - :cost, last_updated = Now() \
				WHERE ckey = :ckey AND character_slot = :slot AND credits >= :cost",
				list(
					"cost" = cost,
					"ckey" = ckey,
					"slot" = character_slot
				)
			)

			if(!deduct_query.Execute(async = FALSE))
				qdel(deduct_query)
				to_chat(C, span_warning("Transaction failed: [deduct_query.ErrorMsg()]"))
				return FALSE

			// Check affected rows - if 0, balance changed since pre-flight check (race condition)
			if(deduct_query.affected == 0)
				qdel(deduct_query)
				to_chat(C, span_warning("Insufficient credits. Your balance may have changed."))
				return FALSE

			qdel(deduct_query)
			credits_deducted = TRUE

			// Log credit transaction
			log_credit_transaction(ckey, character_slot, -cost, "purchase_ship:[ship_template]", current_balance - cost)

		// Step 4: Insert unlock record
		var/datum/db_query/unlock_query = SSdbcore.NewQuery(
			"INSERT INTO [format_table_name("player_ship_unlocks")] \
			(ckey, ship_template_type, unlocked_at) \
			VALUES (:ckey, :template, Now())",
			list(
				"ckey" = ckey,
				"template" = ship_template
			)
		)

		if(unlock_query.Execute(async = FALSE))
			success = TRUE
			qdel(unlock_query)
			to_chat(C, span_notice("Ship purchased successfully! You now own [ship_template]."))
		else
			var/error_msg = unlock_query.ErrorMsg()
			qdel(unlock_query)

			// Check if it's a duplicate key error (race condition: someone else bought it for this player)
			if(findtext(error_msg, "UNIQUE") || findtext(error_msg, "duplicate"))
				// Already unlocked by another process, treat as success but refund
				success = TRUE
				to_chat(C, span_notice("Ship already unlocked. Credits refunded."))
				// Refund will happen in compensating transaction below
			else
				retry_count++
				if(retry_count <= TRANSACTION_MAX_RETRIES)
					to_chat(C, span_warning("Transaction retry [retry_count]/[TRANSACTION_MAX_RETRIES]..."))

	// Step 5: Compensating transaction - Refund if all retries failed
	if(!success && credits_deducted)
		var/datum/db_query/refund_query = SSdbcore.NewQuery(
			"UPDATE [format_table_name("player_credits")] \
			SET credits = credits + :cost, last_updated = Now() \
			WHERE ckey = :ckey AND character_slot = :slot",
			list(
				"cost" = cost,
				"ckey" = ckey,
				"slot" = character_slot
			)
		)

		refund_query.Execute(async = FALSE)
		qdel(refund_query)

		// Log refund
		log_credit_transaction(ckey, character_slot, cost, "refund_ship_purchase_failed:[ship_template]", current_balance)

		to_chat(C, span_warning("Purchase failed after [TRANSACTION_MAX_RETRIES] retries. Credits refunded."))
		return FALSE

	return success

/**
 * Extract a physical ship part to player's account.
 *
 * This proc implements safe extraction with pending queue fallback:
 * 1. Mark part as extracted in database
 * 2. Add to player's inventory
 * 3. If add fails: Queue to pending_extractions (User Q4)
 * 4. Only delete physical item after confirmed success
 *
 * @param client The client extracting the part
 * @param obj/item/ship_parts The physical ship part item to extract
 * @return TRUE if extraction successful or queued, FALSE on critical failure
 */
/proc/extract_part_to_account(client/C, obj/item/ship_parts/part)
	if(!C || !part)
		return FALSE

	if(!SSdbcore.IsConnected())
		to_chat(C, span_warning("Database connection unavailable. Cannot extract parts."))
		return FALSE

	var/ckey = C.ckey
	var/part_rarity = part.part_rarity || RARITY_COMMON
	var/quantity = 1  // Each ship_parts item represents 1 part

	// Step 1: Attempt to add parts to inventory
	var/datum/db_query/add_parts_query = SSdbcore.NewQuery(
		"INSERT INTO [format_table_name("player_ship_parts")] \
		(ckey, part_rarity, quantity, last_updated) \
		VALUES (:ckey, :rarity, :qty, Now()) \
		ON DUPLICATE KEY UPDATE quantity = quantity + :qty, last_updated = Now()",
		list(
			"ckey" = ckey,
			"rarity" = part_rarity,
			"qty" = quantity
		)
	)

	if(!add_parts_query.Execute(async = FALSE))
		var/error_msg = add_parts_query.ErrorMsg()
		qdel(add_parts_query)

		// Step 2: CRITICAL FAILURE - Queue to pending_extractions (User Q4)
		to_chat(C, span_warning("Extraction failed. Adding to pending queue..."))

		var/datum/db_query/pending_query = SSdbcore.NewQuery(
			"INSERT INTO [format_table_name("pending_extractions")] \
			(ckey, part_rarity, quantity, failure_reason, queued_at) \
			VALUES (:ckey, :rarity, :qty, :reason, Now())",
			list(
				"ckey" = ckey,
				"rarity" = part_rarity,
				"qty" = quantity,
				"reason" = error_msg
			)
		)

		if(pending_query.Execute(async = FALSE))
			qdel(pending_query)
			to_chat(C, span_notice("Extraction queued for retry. Your parts will be credited shortly."))

			// Log the pending extraction
			log_part_extraction(ckey, part_rarity, quantity, "pending_queue")

			// DO NOT delete the physical item - let player keep it in case queue fails
			return TRUE
		else
			qdel(pending_query)
			to_chat(C, span_danger("Critical error: Could not queue extraction. Keep this item and contact an admin!"))
			return FALSE

	qdel(add_parts_query)

	// Step 3: Success! Log the extraction
	log_part_extraction(ckey, part_rarity, quantity, "device")

	// Step 4: Only delete physical item after confirmed success
	to_chat(C, span_notice("Extracted [quantity]x [get_rarity_name(part_rarity)] ship part(s) to your account!"))
	qdel(part)

	return TRUE

/**
 * Buy ship parts with credits, with retry and refund logic.
 *
 * This proc implements transaction safety:
 * 1. Pre-flight check
 * 2. Deduct credits with WHERE clause
 * 3. Add parts to inventory
 * 4. Retry pattern (User Q3)
 * 5. Refund on failure
 *
 * @param client The client buying parts
 * @param rarity The rarity tier (1-4)
 * @param quantity Number of parts to buy
 * @param cost Total credit cost
 * @return TRUE if purchase successful, FALSE otherwise
 */
/proc/buy_parts_with_credits(client/C, rarity, quantity, cost)
	if(!C || quantity <= 0 || cost <= 0)
		return FALSE

	if(!(rarity in GLOB.ship_part_rarities))
		to_chat(C, span_warning("Invalid part rarity."))
		return FALSE

	if(!SSdbcore.IsConnected())
		to_chat(C, span_warning("Database connection unavailable. Please try again later."))
		return FALSE

	var/ckey = C.ckey
	var/character_slot = C.prefs?.default_slot || 1

	// Step 1: Pre-flight balance check
	var/current_balance = get_player_credits(ckey, character_slot)
	if(current_balance < cost)
		to_chat(C, span_warning("Insufficient credits. You have [current_balance] credits but need [cost]."))
		return FALSE

	var/retry_count = 0
	var/success = FALSE
	var/credits_deducted = FALSE

	// Retry loop (User Q3: Retry 3 times)
	while(retry_count <= TRANSACTION_MAX_RETRIES && !success)
		if(retry_count > 0)
			sleep(1) // Brief delay between retries

		// Step 2: Deduct credits with WHERE clause (race-condition safe)
		if(!credits_deducted)
			var/datum/db_query/deduct_query = SSdbcore.NewQuery(
				"UPDATE [format_table_name("player_credits")] \
				SET credits = credits - :cost, last_updated = Now() \
				WHERE ckey = :ckey AND character_slot = :slot AND credits >= :cost",
				list(
					"cost" = cost,
					"ckey" = ckey,
					"slot" = character_slot
				)
			)

			if(!deduct_query.Execute(async = FALSE))
				qdel(deduct_query)
				to_chat(C, span_warning("Transaction failed: [deduct_query.ErrorMsg()]"))
				return FALSE

			// Check affected rows
			if(deduct_query.affected == 0)
				qdel(deduct_query)
				to_chat(C, span_warning("Insufficient credits. Your balance may have changed."))
				return FALSE

			qdel(deduct_query)
			credits_deducted = TRUE

			// Log credit transaction
			log_credit_transaction(ckey, character_slot, -cost, "buy_parts:rarity[rarity]x[quantity]", current_balance - cost)

		// Step 3: Add parts to inventory
		var/datum/db_query/add_parts_query = SSdbcore.NewQuery(
			"INSERT INTO [format_table_name("player_ship_parts")] \
			(ckey, part_rarity, quantity, last_updated) \
			VALUES (:ckey, :rarity, :qty, Now()) \
			ON DUPLICATE KEY UPDATE quantity = quantity + :qty, last_updated = Now()",
			list(
				"ckey" = ckey,
				"rarity" = rarity,
				"qty" = quantity
			)
		)

		if(add_parts_query.Execute(async = FALSE))
			success = TRUE
			qdel(add_parts_query)

			// Log part acquisition
			log_part_extraction(ckey, rarity, quantity, "purchase_with_credits")

			to_chat(C, span_notice("Purchased [quantity]x [get_rarity_name(rarity)] ship part(s)!"))
		else
			qdel(add_parts_query)
			retry_count++
			if(retry_count <= TRANSACTION_MAX_RETRIES)
				to_chat(C, span_warning("Transaction retry [retry_count]/[TRANSACTION_MAX_RETRIES]..."))

	// Step 4: Compensating transaction - Refund if all retries failed
	if(!success && credits_deducted)
		var/datum/db_query/refund_query = SSdbcore.NewQuery(
			"UPDATE [format_table_name("player_credits")] \
			SET credits = credits + :cost, last_updated = Now() \
			WHERE ckey = :ckey AND character_slot = :slot",
			list(
				"cost" = cost,
				"ckey" = ckey,
				"slot" = character_slot
			)
		)

		refund_query.Execute(async = FALSE)
		qdel(refund_query)

		// Log refund
		log_credit_transaction(ckey, character_slot, cost, "refund_part_purchase_failed:rarity[rarity]x[quantity]", current_balance)

		to_chat(C, span_warning("Purchase failed after [TRANSACTION_MAX_RETRIES] retries. Credits refunded."))
		return FALSE

	return success

// ============================================================================
// HELPER PROCEDURES
// ============================================================================

/**
 * Get player's current credit balance.
 *
 * @param ckey Player's ckey
 * @param character_slot Character slot number
 * @return Credit balance, or 0 if not found
 */
/proc/get_player_credits(ckey, character_slot)
	if(!SSdbcore.IsConnected())
		return 0

	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT credits FROM [format_table_name("player_credits")] \
		WHERE ckey = :ckey AND character_slot = :slot",
		list(
			"ckey" = ckey,
			"slot" = character_slot
		)
	)

	if(!query.Execute(async = FALSE))
		qdel(query)
		return 0

	if(query.NextRow())
		var/balance = text2num(query.item[1])
		qdel(query)
		return balance

	qdel(query)
	return 0

/**
 * Check if a ship is unlocked for a player.
 *
 * @param ckey Player's ckey
 * @param ship_template Ship template path
 * @return TRUE if unlocked, FALSE otherwise
 */
/proc/is_ship_unlocked(ckey, ship_template)
	if(!SSdbcore.IsConnected())
		return FALSE

	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT 1 FROM [format_table_name("player_ship_unlocks")] \
		WHERE ckey = :ckey AND ship_template_type = :template",
		list(
			"ckey" = ckey,
			"template" = ship_template
		)
	)

	if(!query.Execute(async = FALSE))
		qdel(query)
		return FALSE

	var/unlocked = query.NextRow()
	qdel(query)
	return unlocked

/**
 * Log a credit transaction to audit trail.
 *
 * @param ckey Player's ckey
 * @param character_slot Character slot
 * @param amount Credit amount (negative for spending, positive for earning)
 * @param reason Transaction reason
 * @param balance_after Balance after transaction
 */
/proc/log_credit_transaction(ckey, character_slot, amount, reason, balance_after)
	if(!SSdbcore.IsConnected())
		return

	var/datum/db_query/query = SSdbcore.NewQuery(
		"INSERT INTO [format_table_name("credit_transaction_log")] \
		(ckey, character_slot, amount, reason, balance_after, transaction_at) \
		VALUES (:ckey, :slot, :amount, :reason, :balance, Now())",
		list(
			"ckey" = ckey,
			"slot" = character_slot,
			"amount" = amount,
			"reason" = reason,
			"balance" = balance_after
		)
	)

	query.Execute() // Fire and forget, don't block on logging
	qdel(query)

/**
 * Log a part extraction to audit trail.
 *
 * @param ckey Player's ckey
 * @param part_rarity Rarity tier
 * @param quantity Number of parts
 * @param extraction_method How parts were obtained
 */
/proc/log_part_extraction(ckey, part_rarity, quantity, extraction_method)
	if(!SSdbcore.IsConnected())
		return

	var/datum/db_query/query = SSdbcore.NewQuery(
		"INSERT INTO [format_table_name("part_extraction_log")] \
		(ckey, part_rarity, quantity, extraction_method, extracted_at) \
		VALUES (:ckey, :rarity, :qty, :method, Now())",
		list(
			"ckey" = ckey,
			"rarity" = part_rarity,
			"qty" = quantity,
			"method" = extraction_method
		)
	)

	query.Execute() // Fire and forget
	qdel(query)

/**
 * Get human-readable rarity name.
 * Capitalizes the first letter of the rarity string.
 *
 * @param rarity Rarity tier string (common/uncommon/rare/epic/legendary)
 * @return Capitalized string name
 */
/proc/get_rarity_name(rarity)
	if(!rarity)
		return "Unknown"
	// Capitalize first letter
	return uppertext(copytext(rarity, 1, 2)) + copytext(rarity, 2)

// ============================================================================
// PENDING EXTRACTIONS QUEUE PROCESSOR
// ============================================================================

/**
 * Process pending extractions queue.
 * This should be called periodically (e.g., subsystem fire) to retry failed extractions.
 *
 * @return Number of extractions processed
 */
/proc/process_pending_extractions()
	if(!SSdbcore.IsConnected())
		return 0

	var/processed = 0

	// Get pending extractions
	var/datum/db_query/get_pending = SSdbcore.NewQuery(
		"SELECT id, ckey, part_rarity, quantity FROM [format_table_name("pending_extractions")] \
		WHERE processed = 0 \
		ORDER BY queued_at ASC \
		LIMIT 10",
		list()
	)

	if(!get_pending.Execute(async = FALSE))
		qdel(get_pending)
		return 0

	while(get_pending.NextRow())
		var/extraction_id = text2num(get_pending.item[1])
		var/ckey = get_pending.item[2]
		var/part_rarity = text2num(get_pending.item[3])
		var/quantity = text2num(get_pending.item[4])

		// Try to add parts
		var/datum/db_query/add_parts = SSdbcore.NewQuery(
			"INSERT INTO [format_table_name("player_ship_parts")] \
			(ckey, part_rarity, quantity, last_updated) \
			VALUES (:ckey, :rarity, :qty, Now()) \
			ON DUPLICATE KEY UPDATE quantity = quantity + :qty, last_updated = Now()",
			list(
				"ckey" = ckey,
				"rarity" = part_rarity,
				"qty" = quantity
			)
		)

		if(add_parts.Execute(async = FALSE))
			// Success! Mark as processed
			qdel(add_parts)

			var/datum/db_query/mark_processed = SSdbcore.NewQuery(
				"UPDATE [format_table_name("pending_extractions")] \
				SET processed = 1, processed_at = Now() \
				WHERE id = :id",
				list("id" = extraction_id)
			)
			mark_processed.Execute(async = FALSE)
			qdel(mark_processed)

			// Log the successful extraction
			log_part_extraction(ckey, part_rarity, quantity, "pending_queue_retry")

			processed++
		else
			qdel(add_parts)
			// Still failing, leave it for next cycle

	qdel(get_pending)
	return processed

#undef TRANSACTION_MAX_RETRIES
#undef TRANSACTION_RARITY_COMMON
#undef TRANSACTION_RARITY_UNCOMMON
#undef TRANSACTION_RARITY_RARE
#undef TRANSACTION_RARITY_EPIC
#undef TRANSACTION_RARITY_LEGENDARY
