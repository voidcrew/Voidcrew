GLOBAL_DATUM_INIT(ship_saves, /datum/ship_saves, new)

/**
 * Each player's saved ships. Only small metadata is cached here: the map itself is never kept in
 * the game, because every player's saves together would count against the 4 GB limit.
 */
/datum/ship_saves
	/// ckey -> list of metadata rows. A player is absent until a load has succeeded.
	var/list/cache = list()
	/// ckey -> number of the newest load, so a slow read can't undo a save made after it started.
	var/list/load_tickets = list()
	/// slot_key() -> TRUE for each slot being retrieved, deleted or written, from the lobby or any console.
	var/list/retrievals = list()
	/// slot_key() -> TRUE for each used save whose row hasn't been deleted yet. Reads leave these out,
	/// so a slow or failed delete can't let one save be used twice.
	var/list/spent_rows = list()
	/// slot_key() -> weakref to the ship a save made this round came from. In memory only, so a save from
	/// an earlier round has none. It can't be loaded while that ship is still in service.
	var/list/live_sources = list()
	/// slot_key() -> weakref to the crew record of the ship a save made this round came from, so loading it restores that crew.
	var/list/live_crews = list()

/// The player's cached rows, or null if they aren't loaded. This is the only read ui_data may use.
/datum/ship_saves/proc/saves_for(ckey)
	SHOULD_NOT_SLEEP(TRUE)
	return ckey ? cache[ckey(ckey)] : null

/// Loads a player's saves and parts total in the background, then updates their open windows.
/datum/ship_saves/proc/refresh(ckey)
	set waitfor = FALSE
	ckey = ckey(ckey)
	if(!ckey)
		return
	var/ticket = new_load_ticket(ckey)
	var/list/rows = GLOB.ship_save_store.read_meta(ckey)
	// A failed read leaves what we had, and never reads as "no saves".
	if(rows && load_tickets[ckey] == ticket)
		for(var/list/row as anything in rows.Copy())
			if(spent_rows[slot_key(ckey, row["slot"])])
				rows -= list(row)
		cache[ckey] = rows
	GLOB.ship_economy_db.get_parts(ckey)
	var/client/player = GLOB.directory[ckey]
	if(player?.mob)
		SStgui.update_user_uis(player.mob)

/datum/ship_saves/proc/new_load_ticket(ckey)
	load_tickets[ckey] = (load_tickets[ckey] || 0) + 1
	return load_tickets[ckey]

/// Why a ship can't be written to this slot now, or null.
/datum/ship_saves/proc/slot_denial(ckey, slot)
	SHOULD_NOT_SLEEP(TRUE)
	if(!isnum(slot) || slot < 1 || slot > SHIP_SAVE_SLOTS || slot != round(slot))
		return "No such slot."
	if(retrievals[slot_key(ckey, slot)])
		return "Already under way."
	return null

/**
 * Takes payment and writes a captured ship to the player's chosen slot, replacing whatever is there. Sleeps.
 * With no payment (see ship_save_payment()) the whole price is paid in parts. Credits and carried funds
 * come out of account, and the funds go into the save.
 * The payment goes back if the write fails, and the old row stays. Returns an error for the player, or null
 * on success. The slot stays locked throughout, so nothing can use or delete the old save under it.
 */
/datum/ship_saves/proc/commit_save(ckey, datum/ship_checkpoint/snapshot, mob/user, slot, list/survey, list/payment, datum/bank_account/account)
	ckey = ckey(ckey)
	if(!begin_retrieval(ckey, slot))
		return "Already under way."
	. = write_claimed_save(ckey, snapshot, user, slot, survey, payment, account)
	cancel_retrieval(ckey, slot)

/datum/ship_saves/proc/write_claimed_save(ckey, datum/ship_checkpoint/snapshot, mob/user, slot, list/survey, list/payment, datum/bank_account/account)
	PRIVATE_PROC(TRUE)
	// A runtime below ends this proc with this answer, not with a null that reads as success.
	. = "Shipyard records are offline."
	var/key = slot_key(ckey, slot)
	var/list/old_row = saved_row(ckey, slot)
	var/old_name = old_row?["ship_name"]
	// A failed delete leaves a row the cache doesn't show, and would otherwise block the slot for good.
	var/overwrite = !!old_row || !!spent_rows[key]
	var/tiles = snapshot.owned_tile_count()
	var/name = snapshot.ship_name
	var/class = snapshot.class_name
	var/datum/weakref/source = snapshot.source_ship
	var/datum/weakref/crew_ref = snapshot.crew_record_ref
	var/obj/structure/overmap/ship/ship = source?.resolve()
	var/funds_due = payment?["funds"] || 0
	snapshot.carried_funds = funds_due
	var/payload = encode(snapshot)
	var/list/cost = survey["cost"]
	var/list/parts_due = payment ? payment["parts"] : cost
	var/credits_due = (payment?["credits"] || 0) + funds_due
	GLOB.ship_economy_db.invalidate_cache(ckey, "parts")
	if(length(parts_due) && !GLOB.ship_economy_db.spend_parts(ckey, parts_due))
		return "You need [ship_save_cost_text(parts_due)]."
	// Last, because the parts sleep: the balance can't change between checking it and taking it.
	if(credits_due && (QDELETED(account) || !account.adjust_money(-credits_due, "Shipyard: saved [name]")))
		GLOB.ship_economy_db.refund_parts(ckey, parts_due)
		return "You need [ship_save_credits_text(credits_due)]."
	var/raw_bytes = length(payload)
	var/list/summary = ship_save_add_survey(list(), survey)
	var/list/row = list(
		"ship_name" = name,
		"ship_class" = class,
		"tile_count" = tiles,
		"format_version" = SHIP_SAVE_FORMAT,
		"saved_round" = text2num(GLOB.round_id),
		"raw_bytes" = raw_bytes,
		"summary" = json_encode(summary),
	)
	if(!GLOB.ship_save_store.write(ckey, slot, row, payload, overwrite))
		GLOB.ship_economy_db.refund_parts(ckey, parts_due)
		if(credits_due)
			if(QDELETED(account))
				log_game("[ckey] lost [credits_due] credits on a failed ship save: the ship's account is gone.")
			else
				account.adjust_money(credits_due, "Shipyard: refund")
		return
	row -= "summary"
	row["survey"] = summary
	row["slot"] = slot
	// The write worked, so nothing older is left in this slot.
	spent_rows -= key
	if(source)
		live_sources[key] = source
	else
		live_sources -= key
	if(crew_ref)
		live_crews[key] = crew_ref
	else
		live_crews -= key
	new_load_ticket(ckey)
	var/list/rows = cache[ckey] || list()
	// Looked up again: a refresh may have replaced the rows during the write.
	var/list/replaced = saved_row(ckey, slot)
	if(replaced)
		rows -= list(replaced)
	rows += list(row)
	cache[ckey] = rows
	log_game("[key_name(user)] saved [name] to ship save slot [slot] for [payment ? ship_save_payment_text(payment) : ship_save_cost_text(cost)][funds_due ? ", holding [funds_due] cr" : ""], [raw_bytes] bytes[old_name ? ", replacing [old_name]" : ""].")
	record_metric(METRIC_SHIP, "ship_saved", ckey = ckey, ship = ship, zone = ship_metric_zone(ship), subject = class, quantity = survey["total"], details = list("tiles" = tiles, "raw_bytes" = raw_bytes, "cost" = cost, "credits" = credits_due - funds_due, "funds" = funds_due, "overwrote" = old_name))
	refresh(ckey)
	return null

/datum/ship_saves/proc/slot_key(ckey, slot)
	return "[ckey(ckey)]:[slot]"

/// One cached row, or null.
/datum/ship_saves/proc/saved_row(ckey, slot)
	SHOULD_NOT_SLEEP(TRUE)
	for(var/list/row as anything in saves_for(ckey))
		if(row["slot"] == slot)
			return row
	return null

/// What a screen shows of one saved ship, given why it can't be retrieved from there. Only reads caches.
/datum/ship_saves/proc/saved_ship_entry(ckey, list/row, denial)
	SHOULD_NOT_SLEEP(TRUE)
	var/slot = row["slot"]
	return ship_save_add_survey(list(
		"slot" = slot,
		"name" = row["ship_name"],
		"class" = row["ship_class"],
		"denial" = denial,
		"locked" = retrievals[slot_key(ckey, slot)] ? 1 : 0,
	), row["survey"])

/**
 * Why a save can't be retrieved now, or null. Only reads caches, so ui_data can use it.
 * allow_busy: the caller holds this save's lock and is checking again after a wait.
 */
/datum/ship_saves/proc/retrieve_denial(ckey, slot, allow_busy = FALSE)
	SHOULD_NOT_SLEEP(TRUE)
	if(!GLOB.ship_save_store.online())
		return "Shipyard records are offline."
	var/list/row = saved_row(ckey, slot)
	if(!row)
		return "No such record."
	if(row["format_version"] != SHIP_SAVE_FORMAT)
		return "This record can't be read."
	var/key = slot_key(ckey, slot)
	if(!allow_busy && retrievals[key])
		return "Already under way."
	var/datum/weakref/source = live_sources[key]
	var/obj/structure/overmap/ship/original = source?.resolve()
	if(original)
		if(original.retired_by_checkpoint)
			return "The original hull has already been replaced."
		if(!allow_busy && original.checkpoint_rebuilding)
			return "Already under way."
		if(!QDELETED(original.shuttle) && !original.abandoned)
			return "The original hull is still in service."
	return null

/// Claims a save for one retrieval, across the lobby and every console. FALSE if it is already claimed.
/datum/ship_saves/proc/begin_retrieval(ckey, slot)
	var/key = slot_key(ckey, slot)
	if(retrievals[key])
		return FALSE
	retrievals[key] = TRUE
	return TRUE

/// The retrieval stopped before the save was used. It stays where it is.
/datum/ship_saves/proc/cancel_retrieval(ckey, slot)
	retrievals -= slot_key(ckey, slot)

/**
 * Reads a save out of the table. Sleeps. Returns a snapshot, which the caller owns and must delete,
 * or an error for the player. Nothing is spent either way.
 */
/datum/ship_saves/proc/read_save(ckey, slot)
	ckey = ckey(ckey)
	var/payload = GLOB.ship_save_store.read_payload(ckey, slot)
	if(!payload)
		return "Shipyard records are offline."
	var/datum/ship_checkpoint/snapshot = decode(payload)
	if(!snapshot)
		return "This record can't be read."
	snapshot.captain_ckey = ckey
	snapshot.source_ship = live_sources[slot_key(ckey, slot)]
	snapshot.crew_record_ref = live_crews[slot_key(ckey, slot)]
	return snapshot

/// The save has been used. It leaves the cache now and the table in the background, because a console
/// build calls this mid-placement and must not sleep. The slot stays locked until the delete is done,
/// so a new save to it can't be overtaken by the delete of the old one.
/datum/ship_saves/proc/spend(ckey, slot)
	SHOULD_NOT_SLEEP(TRUE)
	ckey = ckey(ckey)
	var/key = slot_key(ckey, slot)
	retrievals[key] = TRUE
	spent_rows[key] = TRUE
	live_sources -= key
	live_crews -= key
	new_load_ticket(ckey)
	var/list/row = saved_row(ckey, slot)
	if(row)
		var/list/rows = cache[ckey]
		rows -= list(row)
	record_metric(METRIC_SHIP, "ship_retrieved", ckey = ckey, subject = row?["ship_class"], quantity = row?["tile_count"])
	INVOKE_ASYNC(src, PROC_REF(delete_spent), ckey, slot)

/datum/ship_saves/proc/delete_spent(ckey, slot)
	var/key = slot_key(ckey, slot)
	if(GLOB.ship_save_store.remove(ckey, slot))
		spent_rows -= key
	else
		// It stays out of reads this round. Next round it would be back, so an admin should delete the row.
		log_game("Used ship save [ckey] slot [slot] could not be deleted from the table.")
		message_admins("Used ship save [ckey] slot [slot] could not be deleted from the table.")
	retrievals -= key
	refresh(ckey)
