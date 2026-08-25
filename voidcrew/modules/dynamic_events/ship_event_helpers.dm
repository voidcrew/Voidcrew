/**
 * Ship-scoped helpers for dynamic events: the replacements for TG's station
 * helpers (get_random_station_turf, GLOB.station_turfs, priority_announce, ...).
 *
 * Everything here resolves through shuttle.shuttle_areas, never through z-levels:
 * a flying ship shares its transit z with other ships, and a docked ship shares
 * z with whatever it docked at. Area membership is the only correct ownership test.
 */
/obj/structure/overmap/ship
	/// world.time when a dynamic event last targeted this ship (see DYNAMIC_EVENT_SHIP_COOLDOWN).
	var/last_dynamic_event = 0

/// Living, client-connected players physically aboard. This is the population that
/// matters for event eligibility, ship_team membership means nothing if everyone
/// is off exploring a ruin.
/obj/structure/overmap/ship/proc/get_event_crew()
	var/list/aboard = list()
	if(!shuttle?.shuttle_areas)
		return aboard
	for(var/mob/player as anything in GLOB.player_list)
		if(!isliving(player))
			continue
		var/mob/living/living_player = player
		if(living_player.stat == DEAD)
			continue
		var/area/mob_area = get_area(living_player)
		if(mob_area && (mob_area in shuttle.shuttle_areas))
			aboard += living_player
	return aboard

/// Every living mob physically aboard, player or not, for effects that hit everyone.
/obj/structure/overmap/ship/proc/get_all_mobs_aboard(include_dead = FALSE)
	var/list/aboard = list()
	if(!shuttle?.shuttle_areas)
		return aboard
	for(var/area/ship_area as anything in shuttle.shuttle_areas)
		for(var/mob/living/aboard_mob in ship_area)
			if(!include_dead && aboard_mob.stat == DEAD)
				continue
			aboard += aboard_mob
	return aboard

/// TRUE if the atom is currently inside this ship's shuttle areas.
/obj/structure/overmap/ship/proc/is_aboard(atom/thing)
	if(!thing || !shuttle?.shuttle_areas)
		return FALSE
	var/area/thing_area = get_area(thing)
	return thing_area && (thing_area in shuttle.shuttle_areas)

/// Random area of this ship: the replacement for random_station_area().
/obj/structure/overmap/ship/proc/get_random_ship_area()
	if(!shuttle?.shuttle_areas?.len)
		return null
	return pick(shuttle.shuttle_areas)

/// Random unblocked open floor turf aboard, for spawning objects/mobs. Null if none found.
/obj/structure/overmap/ship/proc/get_random_open_ship_turf(max_tries = 20)
	for(var/i in 1 to max_tries)
		var/turf/open/floor/candidate = get_random_ship_turf()
		if(istype(candidate) && !candidate.is_blocked_turf())
			return candidate
	return null

/**
 * Mapper-placed /obj/effect/landmark/event_spawn markers aboard this ship, the
 * ship-scoped replacement for GLOB.generic_event_spawns.
 *
 * The global list spans every loaded z: ruins, outposts and other crews' hulls are all
 * in it, so an event that picks from it directly is not ship-scoped no matter what it
 * does afterwards. Filtering by area membership is the only correct read.
 *
 * Markers are optional. Events that use this must fall back to a random turf aboard
 * when a hull has none, or they would only ever fire on the maps that got marked up.
 */
/obj/structure/overmap/ship/proc/get_ship_event_spawns()
	var/list/aboard = list()
	if(!shuttle?.shuttle_areas)
		return aboard
	for(var/obj/effect/landmark/event_spawn/marker as anything in GLOB.generic_event_spawns)
		if(is_aboard(marker))
			aboard += marker
	return aboard

/// All machines of the given type (and subtypes) aboard this ship.
/obj/structure/overmap/ship/proc/get_ship_machines(machine_type)
	var/list/machines = list()
	if(!shuttle?.shuttle_areas)
		return machines
	for(var/area/ship_area as anything in shuttle.shuttle_areas)
		for(var/obj/machinery/machine in ship_area)
			if(istype(machine, machine_type))
				machines += machine
	return machines

/// Priority announcement heard only aboard this ship, the replacement for
/// priority_announce() in ported events. Sender defaults to the ship's own name,
/// framed as the ship computer talking to its crew.
/obj/structure/overmap/ship/proc/ship_event_announce(text, title = "", sound, sender_override)
	if(!shuttle?.shuttle_areas)
		return
	var/list/receivers = list()
	for(var/mob/player as anything in GLOB.player_list)
		var/area/mob_area = get_area(player)
		if(mob_area && (mob_area in shuttle.shuttle_areas))
			receivers += player
	if(!length(receivers))
		return
	priority_announce(text, title, sound, sender_override = sender_override || display_name || name, players = receivers)
