// Voidcrew extensions to code/datums/mapgen/CaveGenerator.dm.

/**
 * VOIDCREW EDIT: reports how long a generation pass took.
 *
 * Upstream only ever runs these generators at mapload, so shouting the timings at
 * `world` reached nobody but the lobby. Here they also run MID-ROUND (asteroid
 * fields, planet builds, mapgen-bearing encounters), so every player on every ship
 * got a bold "Asteroid Field Generator terrain generation finished in 4.2s!" each
 * time somebody, anybody, docked a rock field. Keep the lobby behaviour as-is;
 * once the round is running it is admin-only. The log line is unconditional.
 */
/datum/map_generator/cave_generator/proc/announce_generation_time(message)
	if(SSticker?.HasRoundStarted())
		to_chat(GLOB.admins, span_boldannounce("[message]"), MESSAGE_TYPE_DEBUG)
	else
		to_chat(world, span_boldannounce("[message]"), MESSAGE_TYPE_DEBUG)
	log_world(message)
