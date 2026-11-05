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
	/// slot_key() -> TRUE for each save being retrieved, from the lobby or any console.
	var/list/retrievals = list()
	/// slot_key() -> TRUE for each used save whose row hasn't been deleted yet. Reads leave these out,
	/// so a slow or failed delete can't let one save be used twice.
	var/list/spent_rows = list()

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

/// The lowest empty slot number. Null if they are all taken or the player isn't loaded.
/datum/ship_saves/proc/free_slot(ckey)
	var/list/rows = saves_for(ckey)
	if(!rows)
		return null
	var/list/taken = list()
	for(var/list/row as anything in rows)
		taken += row["slot"]
	for(var/slot in 1 to SHIP_SAVE_SLOTS)
		if(!(slot in taken))
			return slot
	return null

/// What a save costs in ship parts: the hull price curve, scaled so the biggest hull costs the most.
/datum/ship_saves/proc/price_for(tiles)
	return clamp(floor(6 * ((tiles / 200) ** 1.6) / 4), SHIP_SAVE_PRICE_MIN, SHIP_SAVE_PRICE_MAX)

/**
 * Takes payment and writes a captured ship to the player's lowest free slot. Sleeps.
 * The payment goes back if the write fails. Returns an error for the player, or null on success.
 */
/datum/ship_saves/proc/commit_save(ckey, datum/ship_checkpoint/snapshot, mob/user)
	ckey = ckey(ckey)
	var/slot = free_slot(ckey)
	if(!slot)
		return "All three slots are full."
	var/tiles = snapshot.owned_tile_count()
	var/price = price_for(tiles)
	var/name = snapshot.ship_name
	var/class = snapshot.class_name
	var/obj/structure/overmap/ship/ship = snapshot.source_ship?.resolve()
	var/payload = encode(snapshot)
	var/list/plan = GLOB.ship_economy_db.spend_any_parts(ckey, price)
	if(!plan)
		return "You need [price] ship parts."
	var/raw_bytes = length(payload)
	var/list/row = list(
		"ship_name" = name,
		"ship_class" = class,
		"tile_count" = tiles,
		"format_version" = SHIP_SAVE_FORMAT,
		"saved_round" = text2num(GLOB.round_id),
		"raw_bytes" = raw_bytes,
	)
	if(!GLOB.ship_save_store.write(ckey, slot, row, payload))
		GLOB.ship_economy_db.refund_parts(ckey, plan)
		return "Shipyard records are offline."
	row["slot"] = slot
	// The insert worked, so nothing older is left in this slot.
	spent_rows -= slot_key(ckey, slot)
	new_load_ticket(ckey)
	var/list/rows = cache[ckey] || list()
	rows += list(row)
	cache[ckey] = rows
	log_game("[key_name(user)] saved [name] to ship save slot [slot] for [price] ship parts, [raw_bytes] bytes.")
	record_metric(METRIC_SHIP, "ship_saved", ckey = ckey, ship = ship, zone = ship_metric_zone(ship), subject = class, quantity = price, details = list("tiles" = tiles, "raw_bytes" = raw_bytes))
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
	if(row["saved_round"] == text2num(GLOB.round_id))
		return "Ready next round."
	if(!allow_busy && retrievals[slot_key(ckey, slot)])
		return "Already under way."
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
	return snapshot

/// The save has been used. It leaves the cache now and the table in the background, because a console
/// build calls this mid-placement and must not sleep.
/datum/ship_saves/proc/spend(ckey, slot)
	SHOULD_NOT_SLEEP(TRUE)
	ckey = ckey(ckey)
	var/key = slot_key(ckey, slot)
	retrievals -= key
	spent_rows[key] = TRUE
	new_load_ticket(ckey)
	var/list/row = saved_row(ckey, slot)
	if(row)
		var/list/rows = cache[ckey]
		rows -= list(row)
	record_metric(METRIC_SHIP, "ship_retrieved", ckey = ckey, subject = row?["ship_class"], quantity = row?["tile_count"])
	INVOKE_ASYNC(src, PROC_REF(delete_spent), ckey, slot)

/datum/ship_saves/proc/delete_spent(ckey, slot)
	if(GLOB.ship_save_store.remove(ckey, slot))
		spent_rows -= slot_key(ckey, slot)
	else
		// It stays out of reads this round. Next round it would be back, so an admin should delete the row.
		log_game("Used ship save [ckey] slot [slot] could not be deleted from the table.")
		message_admins("Used ship save [ckey] slot [slot] could not be deleted from the table.")
	refresh(ckey)
