/**
 * Ship Purchase System - Transaction-Safe Helper Procedures
 *
 * NOTHING CALLS THESE YET. Every proc in this file has zero callers in the tree:
 * hulls are currently bought with parts through attempt_ship_unlock() in
 * ship_catalog_ui.dm, which spends parts and unlocks in two unguarded steps. This
 * file is the transaction-safe entry-point layer the purchase UI should adopt when
 * a credit-priced purchase flow is wired up - it is kept, and kept correct against
 * the live schema, for that adoption.
 *
 * Everything here runs on the real ship-economy schema in
 * `SQL/migrations/voidcrew_ship_parts.sql` and delegates to /datum/ship_economy_db
 * (GLOB.ship_economy_db) wherever that layer already owns an operation. What this
 * file adds on top of it:
 * - a race-safe conditional credit deduct (the live layer's add_credits() has no
 *   `WHERE credits >= :cost` clause, so a negative amount there can overdraw)
 * - retry x3 then compensating refund on failure
 * - a credit audit trail in `ship_credit_log`
 *   (`SQL/migrations/voidcrew_ship_credit_log.sql`)
 *
 * Credits are ACCOUNT-WIDE by schema design: keyed on ckey alone, no character slot.
 *
 * Pattern: optimistic concurrency control with compensating transactions.
 * Every path degrades gracefully with no database configured.
 */

// Maximum number of retry attempts for failed transactions
#define TRANSACTION_MAX_RETRIES 3

/**
 * Purchase a ship blueprint unlock with transaction safety.
 *
 * 1. Pre-flight balance check
 * 2. Deduct credits with a conditional WHERE clause (race-condition safe)
 * 3. Insert the unlock record into player_ship_unlocks
 * 4. Retry up to TRANSACTION_MAX_RETRIES times if the unlock fails
 * 5. Refund the credits if all retries fail, or if another process won the race
 *
 * Tables: player_ship_credits (raw), player_ship_unlocks (raw), ship_credit_log (audit).
 *
 * @param C The client purchasing the ship
 * @param ship_template The ship template path to unlock (e.g. "/datum/map_template/shuttle/voidcrew/delta")
 * @param cost The credit cost for this unlock
 * @return TRUE if the player ends up owning the ship, FALSE otherwise
 */
/proc/purchase_ship_unlock(client/C, ship_template, cost)
	if(!C || !ship_template || cost <= 0)
		return FALSE

	if(!SSdbcore.IsConnected())
		to_chat(C, span_warning("Database connection unavailable. Please try again later."))
		return FALSE

	var/player_ckey = ckey(C.ckey)

	// Step 1: Pre-flight balance check
	var/current_balance = GLOB.ship_economy_db?.get_credits(player_ckey) || 0
	if(current_balance < cost)
		to_chat(C, span_warning("Insufficient credits. You have [current_balance] credits but need [cost]."))
		return FALSE

	// Step 2: Check if already unlocked (prevent duplicate purchases)
	if(GLOB.ship_economy_db?.is_ship_unlocked(player_ckey, ship_template))
		to_chat(C, span_warning("You already own this ship!"))
		return FALSE

	var/retry_count = 0
	var/success = FALSE
	var/credits_deducted = FALSE
	var/duplicate_unlock = FALSE

	while(retry_count <= TRANSACTION_MAX_RETRIES && !success)
		if(retry_count > 0)
			sleep(1) // Brief delay between retries to avoid hammering the DB

		// Step 3: Deduct credits with a WHERE clause (race-condition safe).
		// This is deliberately raw rather than ship_economy_db.add_credits(-cost):
		// that proc has no balance guard and would happily push a player negative.
		if(!credits_deducted)
			var/datum/db_query/deduct_query = SSdbcore.NewQuery(
				"UPDATE [format_table_name("player_ship_credits")] \
				SET credits = credits - :cost \
				WHERE ckey = :ckey AND credits >= :cost",
				list(
					"cost" = cost,
					"ckey" = player_ckey
				)
			)

			if(!deduct_query.Execute(async = FALSE))
				var/deduct_error = deduct_query.ErrorMsg()
				qdel(deduct_query)
				to_chat(C, span_warning("Transaction failed: [deduct_error]"))
				return FALSE

			// Zero affected rows means the balance changed since the pre-flight check
			if(deduct_query.affected == 0)
				qdel(deduct_query)
				to_chat(C, span_warning("Insufficient credits. Your balance may have changed."))
				return FALSE

			qdel(deduct_query)
			credits_deducted = TRUE

			// Raw credit write - the live layer's cached balance is now stale
			GLOB.ship_economy_db?.invalidate_cache(player_ckey, "credits")

			log_credit_transaction(player_ckey, -cost, "purchase_ship:[ship_template]", current_balance - cost)

		// Step 4: Insert the unlock record.
		// A plain INSERT rather than ship_economy_db.unlock_ship(), because a
		// duplicate-key collision here is the race we need to detect and refund.
		var/datum/db_query/unlock_query = SSdbcore.NewQuery(
			"INSERT INTO [format_table_name("player_ship_unlocks")] \
			(ckey, ship_template_path, unlock_date) \
			VALUES (:ckey, :template, NOW())",
			list(
				"ckey" = player_ckey,
				"template" = ship_template
			)
		)

		if(unlock_query.Execute(async = FALSE))
			qdel(unlock_query)
			success = TRUE
			GLOB.ship_economy_db?.invalidate_cache(player_ckey, "unlocks")
			log_game("SHIP_ECONOMY: [player_ckey] purchased ship template [ship_template] for [cost] credits")
			to_chat(C, span_notice("Ship purchased successfully! You now own [ship_template]."))
		else
			var/error_msg = unlock_query.ErrorMsg()
			qdel(unlock_query)

			// Duplicate key: another process unlocked this hull for the player mid-flight.
			// They own it either way, so stop retrying and give the credits back below.
			if(findtext(error_msg, "UNIQUE") || findtext(error_msg, "duplicate"))
				success = TRUE
				duplicate_unlock = TRUE
				GLOB.ship_economy_db?.invalidate_cache(player_ckey, "unlocks")
			else
				retry_count++
				if(retry_count <= TRANSACTION_MAX_RETRIES)
					to_chat(C, span_warning("Transaction retry [retry_count]/[TRANSACTION_MAX_RETRIES]..."))

	// Step 5: Compensating transaction - refund if the unlock never landed, or if it
	// landed via someone else's insert and the player shouldn't pay for it twice.
	if(credits_deducted && (!success || duplicate_unlock))
		refund_credits(player_ckey, cost, "refund_ship_purchase[duplicate_unlock ? "_duplicate" : "_failed"]:[ship_template]", current_balance)

		if(duplicate_unlock)
			to_chat(C, span_notice("Ship was already unlocked. Credits refunded."))
			return TRUE

		to_chat(C, span_warning("Purchase failed after [TRANSACTION_MAX_RETRIES] retries. Credits refunded."))
		return FALSE

	return success

/**
 * Extract a physical ship part into the player's account.
 *
 * 1. Add the part through ship_economy_db.add_part()
 * 2. If that fails, queue it in pending_ship_extractions for retry
 * 3. Write the audit row to ship_extraction_log
 *
 * The physical item is destroyed once the part is either credited or queued - a
 * queue row is a promise the part is owed, so keeping the item as well would let
 * the player redeem it twice. It is only kept when even queuing failed.
 *
 * The pending queue has no quantity column: one row is exactly one part.
 *
 * Tables: player_ship_parts, pending_ship_extractions, ship_extraction_log
 * (all via /datum/ship_economy_db).
 *
 * @param C The client extracting the part
 * @param part The physical ship part item to extract
 * @return TRUE if extraction succeeded or was queued, FALSE on critical failure
 */
/proc/extract_part_to_account(client/C, obj/item/ship_parts/part)
	if(!C || !part)
		return FALSE

	if(!SSdbcore.IsConnected())
		to_chat(C, span_warning("Database connection unavailable. Cannot extract parts."))
		return FALSE

	var/player_ckey = ckey(C.ckey)
	var/part_class = part.part_class || PART_CLASS_MISC
	// Ship parts carry no persistent id of their own; the ref is what the live
	// extraction path in voidcrew/modules/shuttle/ship_parts/extraction.dm records.
	var/part_uid = "\ref[part]"

	// Step 1: Credit the part to the account
	if(GLOB.ship_economy_db?.add_part(player_ckey, part_class, 1, "device"))
		GLOB.ship_economy_db.log_extraction(player_ckey, part_class, "device", part_uid)
		to_chat(C, span_notice("Extracted 1x [part_class] ship part to your account!"))
		qdel(part)
		return TRUE

	// Step 2: Failure - queue it for the retry processor
	to_chat(C, span_warning("Extraction failed. Adding to pending queue..."))

	if(GLOB.ship_economy_db?.queue_pending_extraction(player_ckey, part_class, part_uid))
		GLOB.ship_economy_db.log_extraction(player_ckey, part_class, "pending_queue", part_uid)
		to_chat(C, span_notice("Extraction queued for retry. Your part will be credited shortly."))
		qdel(part)
		return TRUE

	to_chat(C, span_danger("Critical error: Could not queue extraction. Keep this item and contact an admin!"))
	return FALSE

/**
 * Buy ship parts with credits, with retry and refund logic.
 *
 * 1. Pre-flight balance check
 * 2. Deduct credits with a conditional WHERE clause (race-condition safe)
 * 3. Add the parts through ship_economy_db.add_part()
 * 4. Retry up to TRANSACTION_MAX_RETRIES times
 * 5. Refund the credits if all retries fail
 *
 * Tables: player_ship_credits (raw), player_ship_parts (via ship_economy_db),
 * ship_credit_log (audit). Nothing is written to ship_extraction_log - buying parts
 * is not an extraction, and that table has no quantity column to record a bulk buy in.
 *
 * @param C The client buying parts
 * @param part_class The part class (combat/science/trade/misc)
 * @param quantity Number of parts to buy
 * @param cost Total credit cost
 * @return TRUE if the purchase succeeded, FALSE otherwise
 */
/proc/buy_parts_with_credits(client/C, part_class, quantity, cost)
	if(!C || quantity <= 0 || cost <= 0)
		return FALSE

	if(!(part_class in GLOB.ship_part_classes))
		to_chat(C, span_warning("Invalid part class."))
		return FALSE

	if(!SSdbcore.IsConnected())
		to_chat(C, span_warning("Database connection unavailable. Please try again later."))
		return FALSE

	var/player_ckey = ckey(C.ckey)

	// Step 1: Pre-flight balance check
	var/current_balance = GLOB.ship_economy_db?.get_credits(player_ckey) || 0
	if(current_balance < cost)
		to_chat(C, span_warning("Insufficient credits. You have [current_balance] credits but need [cost]."))
		return FALSE

	var/retry_count = 0
	var/success = FALSE
	var/credits_deducted = FALSE

	while(retry_count <= TRANSACTION_MAX_RETRIES && !success)
		if(retry_count > 0)
			sleep(1) // Brief delay between retries

		// Step 2: Deduct credits with a WHERE clause (race-condition safe)
		if(!credits_deducted)
			var/datum/db_query/deduct_query = SSdbcore.NewQuery(
				"UPDATE [format_table_name("player_ship_credits")] \
				SET credits = credits - :cost \
				WHERE ckey = :ckey AND credits >= :cost",
				list(
					"cost" = cost,
					"ckey" = player_ckey
				)
			)

			if(!deduct_query.Execute(async = FALSE))
				var/deduct_error = deduct_query.ErrorMsg()
				qdel(deduct_query)
				to_chat(C, span_warning("Transaction failed: [deduct_error]"))
				return FALSE

			if(deduct_query.affected == 0)
				qdel(deduct_query)
				to_chat(C, span_warning("Insufficient credits. Your balance may have changed."))
				return FALSE

			qdel(deduct_query)
			credits_deducted = TRUE

			// Raw credit write - the live layer's cached balance is now stale
			GLOB.ship_economy_db?.invalidate_cache(player_ckey, "credits")

			log_credit_transaction(player_ckey, -cost, "buy_parts:[part_class]x[quantity]", current_balance - cost)

		// Step 3: Add the parts (add_part handles its own cache invalidation and log_game)
		if(GLOB.ship_economy_db?.add_part(player_ckey, part_class, quantity, "purchase_with_credits"))
			success = TRUE
			to_chat(C, span_notice("Purchased [quantity]x [part_class] ship part(s)!"))
		else
			retry_count++
			if(retry_count <= TRANSACTION_MAX_RETRIES)
				to_chat(C, span_warning("Transaction retry [retry_count]/[TRANSACTION_MAX_RETRIES]..."))

	// Step 4: Compensating transaction - refund if all retries failed
	if(!success && credits_deducted)
		refund_credits(player_ckey, cost, "refund_part_purchase_failed:[part_class]x[quantity]", current_balance)
		to_chat(C, span_warning("Purchase failed after [TRANSACTION_MAX_RETRIES] retries. Credits refunded."))
		return FALSE

	return success

// ============================================================================
// HELPER PROCEDURES
// ============================================================================

/**
 * Give credits back after a failed or duplicated purchase.
 *
 * Refunds go through ship_economy_db.add_credits() - a plain addition needs no
 * balance guard, and that proc already invalidates the credits cache and writes
 * the log_game line. This wrapper just adds the audit row.
 *
 * @param player_ckey Player's ckey (already normalized)
 * @param amount Positive amount to return
 * @param reason Transaction reason for the audit trail
 * @param balance_after Expected balance once the refund lands
 */
/proc/refund_credits(player_ckey, amount, reason, balance_after)
	if(!GLOB.ship_economy_db?.add_credits(player_ckey, amount, reason))
		// Nothing else can be done from here: the deduct is committed and the refund
		// is not. Shout about it so an admin can settle it by hand.
		log_game("SHIP_ECONOMY ERROR: refund of [amount] credits to [player_ckey] FAILED - [reason]")
		message_admins("SHIP_ECONOMY ERROR: failed to refund [amount] credits to [player_ckey] ([reason]). Manual correction needed.")
		return FALSE

	log_credit_transaction(player_ckey, amount, reason, balance_after)
	return TRUE

/**
 * Log a credit transaction to the audit trail (`ship_credit_log`).
 *
 * Fire-and-forget: the query is not waited on, and a missing database is not an error.
 * See SQL/migrations/voidcrew_ship_credit_log.sql.
 *
 * @param player_ckey Player's ckey (already normalized)
 * @param amount Credit delta (negative for spending, positive for earning)
 * @param reason Transaction reason
 * @param balance_after Balance after the transaction
 */
/proc/log_credit_transaction(player_ckey, amount, reason, balance_after)
	if(!player_ckey)
		return

	log_game("SHIP_ECONOMY: [player_ckey] [amount > 0 ? "+" : ""][amount] credits - [reason] (balance: [balance_after])")

	if(!SSdbcore.IsConnected())
		return

	var/datum/db_query/query = SSdbcore.NewQuery(
		"INSERT INTO [format_table_name("ship_credit_log")] \
		(ckey, amount, reason, balance_after, created_at) \
		VALUES (:ckey, :amount, :reason, :balance, NOW())",
		list(
			"ckey" = player_ckey,
			"amount" = amount,
			"reason" = reason,
			"balance" = balance_after
		)
	)

	query.Execute() // Fire and forget, don't block on logging
	qdel(query)

// The pending extraction queue is owned by /datum/ship_economy_db/proc/process_pending_extractions()
// in ship_economy_database.dm - a second processor over the same rows would double-credit parts.

#undef TRANSACTION_MAX_RETRIES
