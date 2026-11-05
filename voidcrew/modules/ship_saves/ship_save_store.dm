GLOBAL_DATUM_INIT(ship_save_store, /datum/ship_save_store, new)

/**
 * The player_ship_saves table, and nothing else touches it. Every query is async and can sleep.
 * The map is compressed by the database, so that work stays off the game thread.
 */
/datum/ship_save_store

/// Whether the table can be reached. Does not sleep.
/datum/ship_save_store/proc/online()
	return SSdbcore.IsConnected()

/// The player's saves without their maps. An empty list means none; null means the query failed.
/datum/ship_save_store/proc/read_meta(ckey)
	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT slot, ship_name, ship_class, tile_count, format_version, saved_round, saved_at, raw_bytes \
		FROM [format_table_name("player_ship_saves")] WHERE ckey = :ckey ORDER BY slot",
		list("ckey" = ckey)
	)
	if(!query.Execute())
		qdel(query)
		return null
	var/list/rows = list()
	while(query.NextRow())
		rows += list(list(
			"slot" = text2num(query.item[1]),
			"ship_name" = query.item[2],
			"ship_class" = query.item[3],
			"tile_count" = text2num(query.item[4]),
			"format_version" = text2num(query.item[5]),
			"saved_round" = text2num(query.item[6]),
			"saved_at" = query.item[7],
			"raw_bytes" = text2num(query.item[8]),
		))
	qdel(query)
	return rows

/// One save's map text. Null if the query failed or the row is gone.
/datum/ship_save_store/proc/read_payload(ckey, slot)
	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT CONVERT(UNCOMPRESS(payload) USING utf8mb4) FROM [format_table_name("player_ship_saves")] \
		WHERE ckey = :ckey AND slot = :slot",
		list("ckey" = ckey, "slot" = slot)
	)
	if(!query.Execute())
		qdel(query)
		return null
	var/payload
	if(query.NextRow())
		payload = query.item[1]
	qdel(query)
	return payload

/// A plain INSERT: a duplicate key fails rather than overwriting a save someone paid for.
/datum/ship_save_store/proc/write(ckey, slot, list/meta, payload)
	var/datum/db_query/query = SSdbcore.NewQuery(
		"INSERT INTO [format_table_name("player_ship_saves")] \
		(ckey, slot, ship_name, ship_class, tile_count, format_version, saved_round, saved_at, raw_bytes, payload) \
		VALUES (:ckey, :slot, :ship_name, :ship_class, :tile_count, :format_version, :saved_round, NOW(), :raw_bytes, COMPRESS(:payload))",
		list(
			"ckey" = ckey,
			"slot" = slot,
			"ship_name" = meta["ship_name"],
			"ship_class" = meta["ship_class"],
			"tile_count" = meta["tile_count"],
			"format_version" = meta["format_version"],
			"saved_round" = meta["saved_round"],
			"raw_bytes" = meta["raw_bytes"],
			"payload" = payload,
		)
	)
	// A failed insert would log all its arguments, and one of them is the whole map.
	var/success = query.Execute(log_error = FALSE)
	if(!success)
		log_game("Ship save [ckey] slot [slot] could not be written: [copytext(query.ErrorMsg(), 1, 300)]")
	qdel(query)
	return success

/// TRUE only if a row really was removed, so two callers can't both use one save.
/datum/ship_save_store/proc/remove(ckey, slot)
	var/datum/db_query/query = SSdbcore.NewQuery(
		"DELETE FROM [format_table_name("player_ship_saves")] WHERE ckey = :ckey AND slot = :slot",
		list("ckey" = ckey, "slot" = slot)
	)
	var/success = query.Execute() && query.affected > 0
	qdel(query)
	return success
