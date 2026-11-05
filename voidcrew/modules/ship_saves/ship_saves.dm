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
	new_load_ticket(ckey)
	var/list/rows = cache[ckey] || list()
	rows += list(row)
	cache[ckey] = rows
	log_game("[key_name(user)] saved [name] to ship save slot [slot] for [price] ship parts, [raw_bytes] bytes.")
	record_metric(METRIC_SHIP, "ship_saved", ckey = ckey, ship = ship, zone = ship_metric_zone(ship), subject = class, quantity = price, details = list("tiles" = tiles, "raw_bytes" = raw_bytes))
	refresh(ckey)
	return null
