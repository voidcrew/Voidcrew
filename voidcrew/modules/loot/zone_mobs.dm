/**
 * # Zone-Scaled Mob Spawner
 *
 * The danger-side twin of the zone loot cache (zone_loot.dm): a mapper-placed
 * marker that decides AT LOAD TIME how many enemies guard a spot and how
 * nasty they are, based on the overmap zone the ruin spawned in. The same
 * ruin template plays soft in the green ring and bares its teeth in the red.
 *
 * Mappers place themed markers (pirate/syndicate/cult/undead/bug/wildlife/
 * robot, subtypes live beside their loot theme in themes/<theme>.dm),
 * typically guarding the ruin's loot cache and its chokepoints. Every ruin
 * that carries a cache must carry at least one marker, and every ruin with a
 * /rare cache must carry a /boss marker, the loot audit unit test enforces
 * both.
 *
 * Each marker resolves its zone through the shared /datum/zone_resolver
 * (zone_resolution.dm), pinned to the spawn turf, retrying while the level
 * finishes registering, then rolls a mob count for that zone, scatters the
 * spawns over nearby open turfs, and deletes itself. Unresolvable zones fall
 * back to green (the weakest table), so a broken resolution can never flood
 * a ruin.
 *
 * The /boss variants are single-slot setpiece markers: green gets the
 * theme's lieutenant, red gets the real monster. "Real monster" tops out at
 * elite-tier ("harder versions of normal mobs"). Megafauna are BANNED from
 * the zone system, and from ruin maps outside the purpose-built boss-arena
 * whitelist in the unit test; the test enforces both.
 */

// NOT under /obj/effect/spawner: that base blocks atomlike setup and
// insta-qdels on Initialize, and this marker needs to live through the
// zone-resolution retry window.
/obj/effect/zone_mobs
	name = "zone mob spawner"
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "x2"
	color = COLOR_RED
	anchored = TRUE
	layer = OBJ_LAYER
	invisibility = INVISIBILITY_ABSTRACT
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// Weighted mob tables (typepath -> weight) keyed by spawn zone
	var/list/mobs_green
	var/list/mobs_yellow
	var/list/mobs_red
	/// Spawn count ranges per zone: list(min, max)
	var/list/count_green = list(0, 1)
	var/list/count_yellow = list(1, 2)
	var/list/count_red = list(2, 3)
	/// How far spawns scatter from the marker
	var/scatter_radius = 2

/**
 * Runtime spawns (mission waves) can pass a count override:
 * new /obj/effect/zone_mobs/pirate(T, list(1, 2)) guarantees 1-2 spawns in
 * green/yellow and one extra in red, regardless of the theme's defaults.
 */
/obj/effect/zone_mobs/Initialize(mapload, list/count_override)
	if(islist(count_override) && length(count_override) >= 2)
		count_green = count_override
		count_yellow = count_override
		count_red = list(count_override[1] + 1, count_override[2] + 1)
	. = ..()
	return INITIALIZE_HINT_LATELOAD

// no ..(): the /atom base LateInitialize is a stack_trace stub
/obj/effect/zone_mobs/LateInitialize()
	new /datum/zone_resolver(get_turf(src), CALLBACK(src, PROC_REF(on_zone_resolved)))

/**
 * Resolver result: spawn the pack and retire the marker. A null zone means
 * every retry failed, fall back to green, the weakest table.
 */
/obj/effect/zone_mobs/proc/on_zone_resolved(zone_type)
	if(QDELETED(src))
		return
	do_spawn(isnull(zone_type) ? ZONE_GREEN : zone_type)
	qdel(src)

/**
 * Rolls the count and table for the zone and spawns the pack over nearby
 * open turfs.
 */
/obj/effect/zone_mobs/proc/do_spawn(zone_type)
	var/list/table = mobs_green
	var/list/count_range = count_green
	switch(zone_type)
		if(ZONE_YELLOW)
			table = mobs_yellow || table
			count_range = count_yellow
		if(ZONE_RED)
			table = mobs_red || mobs_yellow || table
			count_range = count_red
	if(!length(table))
		return
	var/amount = rand(count_range[1], count_range[2])
	if(amount < 1)
		return
	var/list/open_turfs = get_scatter_turfs()
	for(var/_ in 1 to amount)
		var/mob_path = pick_weight(table)
		if(!mob_path)
			continue
		var/turf/spot = length(open_turfs) ? pick_n_take(open_turfs) : get_turf(src)
		new mob_path(spot)

/**
 * Open, unblocked turfs around the marker the pack can scatter onto.
 */
/obj/effect/zone_mobs/proc/get_scatter_turfs()
	var/list/result = list()
	for(var/turf/open/tile in RANGE_TURFS(scatter_radius, src))
		if(tile.is_blocked_turf(exclude_mobs = TRUE))
			continue
		result += tile
	return result
