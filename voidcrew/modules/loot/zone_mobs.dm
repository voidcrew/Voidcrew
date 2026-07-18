/**
 * # Zone-Scaled Mob Spawner
 *
 * The danger-side twin of the zone loot cache (zone_loot.dm): a mapper-placed
 * marker that decides AT LOAD TIME how many enemies guard a spot and how
 * nasty they are, based on the overmap zone the ruin spawned in. The same
 * ruin template plays soft in the green ring and bares its teeth in the red.
 *
 * Mappers place themed markers (pirate/syndicate/cult/undead/bug/wildlife/
 * robot), typically guarding the ruin's loot cache and its chokepoints.
 * Each marker resolves its zone exactly like the loot cache does — pinned to
 * the spawn turf, retrying while the level finishes registering — then rolls
 * a mob count for that zone, scatters the spawns over nearby open turfs, and
 * deletes itself. Unresolvable zones fall back to green (the weakest table),
 * so a broken resolution can never flood a ruin.
 *
 * The /boss variants are single-slot setpiece markers: green gets the
 * theme's lieutenant, red gets the real monster.
 */

/// How many times a spawner re-attempts zone resolution
#define ZONE_MOBS_RESOLVE_ATTEMPTS 6
/// Delay between resolution attempts
#define ZONE_MOBS_RESOLVE_RETRY_DELAY (10 SECONDS)

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
	/// Resolution retries left
	var/resolve_attempts_left = ZONE_MOBS_RESOLVE_ATTEMPTS

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
	try_spawn()

/**
 * Resolves the zone and does the spawn. Reschedules itself while the
 * containing level may still be registering (planet mapzones attach only
 * after their template load returns).
 */
/obj/effect/zone_mobs/proc/try_spawn()
	if(QDELETED(src))
		return
	var/zone_type = SSovermap_zones.get_zone_type_anywhere(get_turf(src))
	if(isnull(zone_type))
		if(resolve_attempts_left-- > 0)
			addtimer(CALLBACK(src, PROC_REF(try_spawn)), ZONE_MOBS_RESOLVE_RETRY_DELAY)
			return
		zone_type = ZONE_GREEN // never resolved: weakest table
	do_spawn(zone_type)
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

// =========================================================================
// THEMES — grunt-pack markers. Place 2-4 per ruin: at the entrance approach,
// covering chokepoints, and around the loot cache.
// =========================================================================

/// Pirate crews: scattered faction pirates. Fits crash sites, coves, freeports.
/obj/effect/zone_mobs/pirate
	name = "zone mob spawner (pirate)"
	mobs_green = list(
		/mob/living/basic/trooper/pirate/faction/grey/melee = 10,
		/mob/living/basic/trooper/pirate/faction/skeleton/melee = 8,
		/mob/living/basic/trooper/pirate/faction/silverscale/melee = 6,
	)
	mobs_yellow = list(
		/mob/living/basic/trooper/pirate/faction/grey/ranged = 8,
		/mob/living/basic/trooper/pirate/faction/skeleton/ranged = 8,
		/mob/living/basic/trooper/pirate/faction/silverscale/melee = 6,
		/mob/living/basic/trooper/pirate/faction/lustrous/ranged = 5,
	)
	mobs_red = list(
		/mob/living/basic/trooper/pirate/faction/silverscale/ranged = 8,
		/mob/living/basic/trooper/pirate/faction/lustrous/ranged = 8,
		/mob/living/basic/trooper/pirate/faction/interdyne/ranged = 6,
		/mob/living/basic/trooper/pirate/faction/skeleton/captain = 4,
		/mob/living/basic/trooper/pirate/faction/grey/captain = 4,
	)

/// The pirate setpiece: a captain holding the vault, a proper boss in the red.
/obj/effect/zone_mobs/pirate/boss
	name = "zone mob spawner (pirate boss)"
	count_green = list(1, 1)
	count_yellow = list(1, 1)
	count_red = list(1, 1)
	mobs_green = list(
		/mob/living/basic/trooper/pirate/faction/grey/captain = 1,
		/mob/living/basic/trooper/pirate/faction/skeleton/captain = 1,
	)
	mobs_yellow = list(
		/mob/living/basic/trooper/pirate/faction/silverscale/captain = 1,
		/mob/living/basic/trooper/pirate/faction/lustrous/captain = 1,
		/mob/living/basic/trooper/pirate/faction/interdyne/captain = 1,
	)
	mobs_red = list(
		/mob/living/basic/trooper/pirate/faction/boss/silverscale = 1,
		/mob/living/basic/trooper/pirate/faction/boss/skeleton = 1,
		/mob/living/basic/trooper/pirate/faction/boss/grey = 1,
		/mob/living/basic/trooper/pirate/faction/boss/lustrous = 1,
		/mob/living/basic/trooper/pirate/faction/boss/interdyne = 1,
	)

/// Syndicate holdouts: operatives left guarding whatever the base was for.
/obj/effect/zone_mobs/syndicate
	name = "zone mob spawner (syndicate)"
	mobs_green = list(
		/mob/living/basic/trooper/syndicate/melee = 10,
		/mob/living/basic/trooper/syndicate/melee/sword = 4,
	)
	mobs_yellow = list(
		/mob/living/basic/trooper/syndicate/melee/sword = 8,
		/mob/living/basic/trooper/syndicate/ranged = 8,
		/mob/living/basic/trooper/syndicate/ranged/smg = 4,
	)
	mobs_red = list(
		/mob/living/basic/trooper/syndicate/ranged/smg = 8,
		/mob/living/basic/trooper/syndicate/ranged/shotgun = 6,
		/mob/living/basic/trooper/syndicate/melee/sword = 5,
		/mob/living/basic/trooper/syndicate/ranged/smg/space/stormtrooper = 2,
	)

/obj/effect/zone_mobs/syndicate/boss
	name = "zone mob spawner (syndicate boss)"
	count_green = list(1, 1)
	count_yellow = list(1, 1)
	count_red = list(1, 1)
	mobs_green = list(
		/mob/living/basic/trooper/syndicate/melee/sword = 1,
	)
	mobs_yellow = list(
		/mob/living/basic/trooper/syndicate/ranged/shotgun = 1,
		/mob/living/basic/trooper/syndicate/ranged/smg = 1,
	)
	mobs_red = list(
		/mob/living/basic/trooper/syndicate/ranged/smg/space/stormtrooper = 1,
		/mob/living/basic/trooper/syndicate/ranged/shotgun/space/stormtrooper = 1,
	)

/// Cult remnants: constructs still bound to a dead master's wards.
/obj/effect/zone_mobs/cult
	name = "zone mob spawner (cult)"
	mobs_green = list(
		/mob/living/basic/construct/proteon/hostile = 10,
	)
	mobs_yellow = list(
		/mob/living/basic/construct/proteon/hostile = 8,
		/mob/living/basic/construct/artificer/hostile = 5,
	)
	mobs_red = list(
		/mob/living/basic/construct/artificer/hostile = 6,
		/mob/living/basic/construct/wraith/hostile = 5,
		/mob/living/basic/construct/juggernaut/hostile = 4,
	)

/obj/effect/zone_mobs/cult/boss
	name = "zone mob spawner (cult boss)"
	count_green = list(1, 1)
	count_yellow = list(1, 1)
	count_red = list(1, 1)
	mobs_green = list(
		/mob/living/basic/construct/artificer/hostile = 1,
	)
	mobs_yellow = list(
		/mob/living/basic/construct/wraith/hostile = 1,
	)
	mobs_red = list(
		/mob/living/basic/construct/juggernaut/hostile = 1,
	)

/// The restless dead: graves, derelicts, plague sites.
/obj/effect/zone_mobs/undead
	name = "zone mob spawner (undead)"
	mobs_green = list(
		/mob/living/basic/skeleton = 10,
		/mob/living/basic/zombie = 6,
	)
	mobs_yellow = list(
		/mob/living/basic/skeleton/settler = 8,
		/mob/living/basic/zombie = 8,
		/mob/living/basic/skeleton/templar = 4,
	)
	mobs_red = list(
		/mob/living/basic/skeleton/templar = 8,
		/mob/living/basic/skeleton/plasmaminer = 6,
		/mob/living/basic/skeleton/plasmaminer/jackhammer = 4,
	)

/obj/effect/zone_mobs/undead/boss
	name = "zone mob spawner (undead boss)"
	count_green = list(1, 1)
	count_yellow = list(1, 1)
	count_red = list(1, 1)
	mobs_green = list(
		/mob/living/basic/skeleton/templar = 1,
	)
	mobs_yellow = list(
		/mob/living/basic/skeleton/plasmaminer = 1,
	)
	mobs_red = list(
		/mob/living/basic/skeleton/plasmaminer/jackhammer = 1,
	)

/// Infested nests: giant spiders. Webs sold separately.
/obj/effect/zone_mobs/bug
	name = "zone mob spawner (bug)"
	mobs_green = list(
		/mob/living/basic/spider/giant/nurse = 8,
		/mob/living/basic/spider/giant = 6,
	)
	mobs_yellow = list(
		/mob/living/basic/spider/giant/hunter = 8,
		/mob/living/basic/spider/giant/nurse = 6,
	)
	mobs_red = list(
		/mob/living/basic/spider/giant/hunter = 8,
		/mob/living/basic/spider/giant/tarantula = 4,
	)

/obj/effect/zone_mobs/bug/boss
	name = "zone mob spawner (bug boss)"
	count_green = list(1, 1)
	count_yellow = list(1, 1)
	count_red = list(1, 1)
	mobs_green = list(
		/mob/living/basic/spider/giant/hunter = 1,
	)
	mobs_yellow = list(
		/mob/living/basic/spider/giant/tarantula = 1,
	)
	mobs_red = list(
		/mob/living/basic/spider/giant/midwife = 1,
	)

/// Planet fauna: territorial wildlife around and inside surface ruins.
/obj/effect/zone_mobs/wildlife
	name = "zone mob spawner (wildlife)"
	mobs_green = list(
		/mob/living/basic/mining/bileworm = 8,
		/mob/living/basic/mining/lobstrosity = 6,
		/mob/living/basic/mining/goldgrub = 3,
	)
	mobs_yellow = list(
		/mob/living/basic/mining/goliath = 8,
		/mob/living/basic/mining/watcher = 6,
		/mob/living/basic/mining/brimdemon = 5,
	)
	mobs_red = list(
		/mob/living/basic/mining/goliath = 8,
		/mob/living/basic/mining/watcher = 6,
		/mob/living/basic/mining/legion = 5,
		/mob/living/basic/mining/goliath/ancient = 3,
	)

/obj/effect/zone_mobs/wildlife/boss
	name = "zone mob spawner (wildlife boss)"
	count_green = list(1, 1)
	count_yellow = list(1, 1)
	count_red = list(1, 1)
	mobs_green = list(
		/mob/living/basic/mining/goliath = 1,
	)
	mobs_yellow = list(
		/mob/living/basic/mining/goliath/ancient = 1,
	)
	mobs_red = list(
		/mob/living/simple_animal/hostile/megafauna/dragon/lesser = 1,
	)

/// Airless rock fauna: mining wildlife that shrugs off vacuum. Used by the
/// landable meteor storm fields (overmap/events.dm) and fits any airless
/// asteroid ruin — everything in these tables survives space.
/obj/effect/zone_mobs/asteroid
	name = "zone mob spawner (asteroid)"
	mobs_green = list(
		/mob/living/basic/mining/goldgrub = 8,
		/mob/living/basic/mining/hivelord = 6,
	)
	mobs_yellow = list(
		/mob/living/basic/mining/basilisk = 8,
		/mob/living/basic/mining/hivelord = 6,
		/mob/living/basic/mining/goliath = 4,
	)
	mobs_red = list(
		/mob/living/basic/mining/basilisk = 8,
		/mob/living/basic/mining/goliath/ancient = 6,
		/mob/living/basic/mining/legion = 4,
	)

/// Malfunctioning automation: hivebots and shredders in dead facilities.
/obj/effect/zone_mobs/robot
	name = "zone mob spawner (robot)"
	mobs_green = list(
		/mob/living/basic/hivebot = 10,
		/mob/living/basic/viscerator = 5,
	)
	mobs_yellow = list(
		/mob/living/basic/hivebot/range = 8,
		/mob/living/basic/hivebot = 6,
		/mob/living/basic/viscerator = 5,
	)
	mobs_red = list(
		/mob/living/basic/hivebot/rapid = 8,
		/mob/living/basic/hivebot/strong = 6,
		/mob/living/basic/hivebot/mechanic = 4,
	)

/obj/effect/zone_mobs/robot/boss
	name = "zone mob spawner (robot boss)"
	count_green = list(1, 1)
	count_yellow = list(1, 1)
	count_red = list(1, 2)
	mobs_green = list(
		/mob/living/basic/hivebot/strong = 1,
	)
	mobs_yellow = list(
		/mob/living/basic/hivebot/strong = 1,
	)
	mobs_red = list(
		/mob/living/basic/hivebot/strong = 2,
		/mob/living/basic/hivebot/mechanic = 1,
	)

#undef ZONE_MOBS_RESOLVE_ATTEMPTS
#undef ZONE_MOBS_RESOLVE_RETRY_DELAY
