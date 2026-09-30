/**
 * Queues one metrics row. Cheap: builds a list and appends it, with no database work, so it is
 * safe to call anywhere. Use named arguments and pass only what you know.
 *
 * * category - a METRIC_* define
 * * event - snake_case event name, listed in the header of the file that records it
 * * ckey - the player the row is about (buyer, seller, victim, researcher)
 * * other_ckey - a second player involved (killer, seller's customer, target)
 * * ship - the player ship the row is about; filled from `actor` when left out
 * * zone - "green", "yellow" or "red"; filled from `location` (or `actor`) when left out
 * * subject - what the row is about: an item or mob typepath, SKU name, mission type, node id
 * * credits - signed change to a ship account; income positive, spending negative
 * * vouchers - signed trade vouchers gained or spent
 * * points - research points, or another count that isn't credits
 * * quantity - how many of the subject
 * * details - small assoc list of anything else, stored as JSON
 * * actor - a mob; fills ckey, ship and location when those are left out
 * * location - an atom whose position decides the zone
 */
/proc/record_metric(category, event, ckey, other_ckey, obj/structure/overmap/ship/ship, zone, subject, credits = 0, vouchers = 0, points = 0, quantity = 0, list/details, atom/actor, atom/location)
	if(!SSmetrics.accepting)
		return
	if(actor)
		if(!ckey)
			ckey = metric_ckey(actor)
		if(!ship && ismob(actor))
			ship = metric_crew_ship(actor)
		if(!location)
			location = actor
	if(isnull(zone) && location)
		zone = metric_zone(location)
	SSmetrics.queue_row(SSmetrics.build_row(category, event, ckey, other_ckey, ship, zone, subject, credits, vouchers, points, quantity, details))

/**
 * Adds to a running total instead of writing a row per call. Use it for events that happen many
 * times a minute, like hits. Calls with the same category, event, players, ship, zone and subject
 * share one row per minute; `quantity`, `points` and `credits` are summed. Pass the zone
 * yourself if you can: looking it up on every call costs more than the tally.
 */
/proc/tally_metric(category, event, ckey, other_ckey, obj/structure/overmap/ship/ship, zone, subject, quantity = 1, points = 0, credits = 0)
	if(!SSmetrics.accepting)
		return
	SSmetrics.add_tally(category, event, ckey, other_ckey, ship, zone, subject, quantity, points, credits)

/// Seconds since the round started, or 0 before it starts.
/proc/metric_round_seconds()
	if(!SSticker.round_start_time)
		return 0
	return max(0, round((world.time - SSticker.round_start_time) / 10))

/// A ship's metrics id, handed out on first use. It never changes for the rest of the ship's life,
/// including before its shuttle is attached and after it is detached.
/obj/structure/overmap/ship/var/metric_id

GLOBAL_VAR_INIT(metric_ship_count, 0)

/// A ship's id for the round. Stays the same through renames and shuttle changes.
/proc/metric_ship_id(obj/structure/overmap/ship/ship)
	if(!ship.metric_id)
		ship.metric_id = "ship_[++GLOB.metric_ship_count]"
	return ship.metric_id

/// The ckey of a mob, or of the player whose mind it holds while they are ghosted.
/proc/metric_ckey(atom/thing)
	if(!ismob(thing))
		return null
	var/mob/player = thing
	if(player.ckey)
		return player.ckey
	if(player.mind?.key)
		return ckey(player.mind.key)
	return null

/// The ship a mob crews. Falls back to the ship they are standing on.
/proc/metric_crew_ship(mob/player)
	for(var/datum/team/voidcrew/team as anything in player.mind?.ship_teams)
		if(team.ship)
			return team.ship
	return get_ship_from_atom(player)

/// "green", "yellow" or "red" for where an atom is, counting a ship's interior as the ship's tile.
/// Null when the place isn't tied to the overmap.
/proc/metric_zone(atom/thing)
	var/turf/location = get_turf(thing)
	if(!location)
		return null
	var/zone_type
	var/obj/structure/overmap/ship/ship = zone_log_ship_for_atom(location)
	if(ship)
		zone_type = SSovermap_zones.get_zone_type_anywhere(get_turf(ship))
	else
		zone_type = SSovermap_zones.get_zone_type_anywhere(location)
	return metric_zone_name(zone_type)

/// Converts a ZONE_* define to the name stored in the table.
/proc/metric_zone_name(zone_type)
	switch(zone_type)
		if(ZONE_GREEN)
			return "green"
		if(ZONE_YELLOW)
			return "yellow"
		if(ZONE_RED)
			return "red"
	return null

/// Round metrics on or off. On by default; they also need the database and the round_metric table.
/datum/config_entry/flag/round_metrics
	default = TRUE
