/**
 * # Zone-Aware Loot Cache
 *
 * One generic container that rolls its contents on first opening or break. Every cache
 * of a theme draws from the SAME four-tier pool no matter where it sits; the
 * overmap zone decides only how many draws it gets and how the odds lean
 * across those tiers. A green cache can pay the top of its theme, it just
 * rarely does; a red cache pays more items and reaches the top constantly.
 *
 * This is the same contract zones already have with planet ore, fauna and
 * weather (voidcrew/_DEFINES/overmap_zones.dm): deeper bands scale AMOUNTS
 * and ODDS, never the kinds on offer. There is no band-locked content and no
 * separate "rare" cache variant. A crew in safe space is on the same table
 * as everyone else, playing it at longer odds.
 *
 * Caches are placed by MAPPING ruin templates by hand (no automatic
 * spawning), and their value is pinned to where the mapper put them: the
 * spawn turf is captured at init and zone resolution only ever runs against
 * it, so hauling an unopened cache somewhere richer can't retier it.
 *
 * The zone is resolved through the shared /datum/zone_resolver
 * (zone_resolution.dm), which traces interior turfs (ruin reservations,
 * outpost reservations, planet z-levels) back to their overmap tile and
 * retries while the level finishes registering. The closet's lazy
 * PopulateContents() (first open or break) is the last chance, after which
 * an unresolved cache counts as green, the shortest, longest-odds profile.
 *
 * Subtypes are one-liner configs: each points at a /datum/loot_theme
 * (themes/<theme>.dm) that owns the four tier tables, the guard-marker
 * pairing and the shop-SKU cross-references.
 *
 * One draw pays a weapon; remaining nonweapon draws roll WITHOUT
 * replacement within one cache. Uniqueness is per-cache only, there is
 * deliberately no global already-dropped registry, so a long round can hand
 * two crews the same one-of-a-kind item.
 *
 * Ballistic guns ship with a spare reload beside them (see
 * GLOB.loot_gun_spare_ammo below), so a gun roll is never a dead roll.
 */

// Tier keys, per-band draw counts and tier odds all live in
// voidcrew/_DEFINES/loot.dm. The balance surface is one screen there, and it
// has to be defined before the admin preview verb that reads it back.

/**
 * Ballistic loot guns -> one spare reload that spawns beside them.
 *
 * tg ballistics already spawn with a full magazine, so this is the SECOND
 * one: without it a cache could pay a revolver whose six rounds are the
 * whole prize, and the crew has no route to more .357 short of the outpost.
 * Energy guns are deliberately absent. They recharge, so they need nothing.
 *
 * Internal-magazine guns (revolvers, bolt-actions, break-actions) can't take
 * a spare magazine, so they get the matching loose ammo box or shell box
 * instead. The bonus is spawned on top of the roll, not drawn from the
 * table, so it never displaces a prize.
 */
GLOBAL_LIST_INIT(loot_gun_spare_ammo, list(
	// detachable magazines
	/obj/item/gun/ballistic/automatic/ar = /obj/item/ammo_box/magazine/m223,
	/obj/item/gun/ballistic/automatic/c20r/unrestricted = /obj/item/ammo_box/magazine/smgm45,
	/obj/item/gun/ballistic/automatic/gyropistol = /obj/item/ammo_box/magazine/m75,
	/obj/item/gun/ballistic/automatic/l6_saw/unrestricted = /obj/item/ammo_box/magazine/m7mm,
	/obj/item/gun/ballistic/automatic/m90 = /obj/item/ammo_box/magazine/m223,
	/obj/item/gun/ballistic/automatic/mini_uzi = /obj/item/ammo_box/magazine/uzim9mm,
	/obj/item/gun/ballistic/automatic/pistol = /obj/item/ammo_box/magazine/m9mm,
	/obj/item/gun/ballistic/automatic/pistol/deagle = /obj/item/ammo_box/magazine/m50,
	/obj/item/gun/ballistic/automatic/pistol/m1911 = /obj/item/ammo_box/magazine/m45,
	/obj/item/gun/ballistic/automatic/proto/unrestricted = /obj/item/ammo_box/magazine/smgm9mm,
	/obj/item/gun/ballistic/automatic/tommygun = /obj/item/ammo_box/magazine/tommygunm45,
	/obj/item/gun/ballistic/automatic/wt550 = /obj/item/ammo_box/magazine/wt550m9,
	/obj/item/gun/ballistic/rifle/sniper_rifle = /obj/item/ammo_box/magazine/sniper_rounds,
	/obj/item/gun/ballistic/shotgun/bulldog/unrestricted = /obj/item/ammo_box/magazine/m12g,
	// internal magazines: loose rounds instead
	/obj/item/gun/ballistic/revolver = /obj/item/ammo_box/a357,
	/obj/item/gun/ballistic/revolver/c38/detective = /obj/item/ammo_box/c38,
	/obj/item/gun/ballistic/revolver/mateba = /obj/item/ammo_box/a357,
	/obj/item/gun/ballistic/rifle/boltaction = /obj/item/ammo_box/strilka310,
	/obj/item/gun/ballistic/rifle/boltaction/prime = /obj/item/ammo_box/strilka310,
	/obj/item/gun/ballistic/rifle/boltaction/surplus = /obj/item/ammo_box/strilka310,
	// break/pump actions: a box of shells
	/obj/item/gun/ballistic/shotgun/automatic/combat = /obj/item/storage/box/lethalshot,
	/obj/item/gun/ballistic/shotgun/doublebarrel = /obj/item/storage/box/lethalshot,
	/obj/item/gun/ballistic/shotgun/riot = /obj/item/storage/box/lethalshot,
))
/obj/structure/closet/crate/zone_loot
	name = "abandoned cache"
	desc = "A scuffed cargo cache, sealed since whoever owned it stopped coming back."
	/// The /datum/loot_theme typepath this cache reads its tables from
	var/theme
	/// The ZONE_* type this cache spawned in (null until resolved)
	var/loot_zone
	/// The turf the cache spawned on. Zone resolution is pinned to this, never the current position
	var/turf/spawn_turf
	/// Extra draws on top of the band's roll, for caches that are a deliberate
	/// prize rather than scenery (a bought premium cache, a jackpot drop).
	/// Scales AMOUNT only, a bonus cache reaches no content a plain one can't.
	var/bonus_draws = 0
	/// Purchased caches keep themed supplies but use the freight weapon profile.
	var/freight_weapons = FALSE
	/// Claim before spawning anything, including on direct population calls.
	var/loot_consumed = FALSE

/obj/structure/closet/crate/zone_loot/Initialize(mapload)
	spawn_turf = get_turf(src)
	return ..()

/obj/structure/closet/crate/zone_loot/Destroy()
	spawn_turf = null
	return ..()

/obj/structure/closet/crate/zone_loot/LateInitialize()
	. = ..()
	if(loot_consumed)
		return
	new /datum/zone_resolver(spawn_turf, CALLBACK(src, PROC_REF(on_zone_resolved)))

/**
 * Resolver result. A null zone means every retry failed, keep the pinned
 * spawn turf so the lazy PopulateContents() gets one last synchronous try.
 */
/obj/structure/closet/crate/zone_loot/proc/on_zone_resolved(zone_type)
	if(QDELETED(src) || !isnull(loot_zone) || isnull(zone_type))
		return
	loot_zone = zone_type
	spawn_turf = null

/obj/structure/closet/crate/zone_loot/PopulateContents()
	if(loot_consumed)
		return
	loot_consumed = TRUE
	. = ..()
	// Last chance: resolve against the spawn point (NOT the current
	// position, moving the cache must never change its value), else it
	// falls back to green: the fewest draws at the longest odds
	if(isnull(loot_zone))
		loot_zone = SSovermap_zones.get_zone_type_anywhere(spawn_turf)
	if(isnull(loot_zone))
		loot_zone = ZONE_GREEN
	spawn_turf = null

	var/datum/loot_theme/loot_theme = GLOB.loot_themes[theme]
	if(!loot_theme)
		return

	// Draw without replacement, per tier: one cache never pays the same entry
	// twice. Each tier keeps its own working copy so exhausting the uniques
	// shelf can't eat into the tier below it.
	var/list/pools = list(
		"[LOOT_TIER_COMMON]" = loot_theme.loot_common?.Copy(),
		"[LOOT_TIER_UNCOMMON]" = loot_theme.loot_uncommon?.Copy(),
		"[LOOT_TIER_PRIME]" = loot_theme.loot_prime?.Copy(),
		"[LOOT_TIER_UNIQUE]" = loot_theme.loot_uniques?.Copy(),
	)

	var/draws_min = ZONE_LOOT_DRAWS_MIN_GREEN
	var/draws_max = ZONE_LOOT_DRAWS_MAX_GREEN
	var/list/tier_odds = ZONE_LOOT_ODDS_GREEN
	switch(loot_zone)
		if(ZONE_RED)
			draws_min = ZONE_LOOT_DRAWS_MIN_RED
			draws_max = ZONE_LOOT_DRAWS_MAX_RED
			tier_odds = ZONE_LOOT_ODDS_RED
		if(ZONE_YELLOW)
			draws_min = ZONE_LOOT_DRAWS_MIN_YELLOW
			draws_max = ZONE_LOOT_DRAWS_MAX_YELLOW
			tier_odds = ZONE_LOOT_ODDS_YELLOW

	roll_cache_weapon(src, loot_zone, loot_theme, freight_weapons)
	roll_loot_draws(src, pools, rand(draws_min, draws_max) - 1 + bonus_draws, tier_odds)

/**
 * Rolls `draws` prizes out of `pools` and spawns them inside `destination`.
 *
 * Shared by the zone caches above and by the abandoned crate
 * (voidcrew/modules/loot/abandoned_crate.dm), which rolls the same way off a
 * flat profile instead of a band's. `pools` is a WORKING COPY keyed by tier
 * ("1".."4"); this proc consumes it, so callers Copy() their tables in.
 *
 * Stops early once every tier is empty: a table shorter than the draw count
 * pays what it has rather than looping for nothing.
 */
/proc/roll_loot_draws(atom/destination, list/pools, draws, list/tier_odds)
	for(var/_ in 1 to draws)
		var/loot_path = draw_loot_from_tier(pools, pick_weight(tier_odds))
		if(!loot_path)
			return
		spawn_loot_prize(destination, loot_path)

/// Shared by themed caches and freight. The caller replaces one existing draw.
/proc/roll_cache_weapon(atom/destination, zone, datum/loot_theme/theme, freight = FALSE)
	var/loot_path = select_cache_weapon(zone, theme, freight)
	spawn_loot_prize(destination, loot_path)
	return loot_path

/// The two independent rolls are exposed so tests can enumerate every outcome.
/proc/select_cache_weapon(zone, datum/loot_theme/theme, freight = FALSE, gun_roll = rand(1, 100), class_roll = rand(1, 1000))
	var/gun = gun_roll <= get_cache_gun_chance(zone, theme, freight)
	var/weapon_class = get_cache_weapon_class(zone, gun, class_roll)
	var/list/pool = theme ? theme.get_weapon_pool(gun, weapon_class, freight) : get_cache_weapon_pool(gun, weapon_class, LOOT_GUN_POOL_FREIGHT)
	return pick_weight(pool)

/proc/get_cache_gun_chance(zone, datum/loot_theme/theme, freight = FALSE)
	if(zone != ZONE_YELLOW && zone != ZONE_RED)
		zone = ZONE_GREEN
	var/list/chances = freight || !theme ? LOOT_GUN_CHANCE_FREIGHT : theme.gun_chance
	return chances[zone]

/// Normalize every class distribution to 1000 integer outcomes.
/proc/get_cache_weapon_class(zone, gun, roll = rand(1, 1000))
	var/list/odds
	switch(zone)
		if(ZONE_YELLOW)
			odds = gun ? LOOT_GUN_CLASSES_YELLOW : LOOT_MELEE_CLASSES_YELLOW
		if(ZONE_RED)
			odds = gun ? LOOT_GUN_CLASSES_RED : LOOT_MELEE_CLASSES_RED
		else
			odds = gun ? LOOT_GUN_CLASSES_GREEN : LOOT_MELEE_CLASSES_GREEN
	var/cumulative = 0
	for(var/weapon_class in odds)
		cumulative += odds[weapon_class]
		if(roll <= cumulative)
			return weapon_class

/proc/get_cache_weapon_pool(gun, weapon_class, family, list/extras)
	if(gun && family == LOOT_GUN_POOL_FREIGHT && weapon_class == LOOT_WEAPON_RED)
		weapon_class = LOOT_WEAPON_YELLOW
	var/list/main_pools = gun ? GLOB.loot_gun_pools[family] : GLOB.loot_melee_pools
	var/list/pool = main_pools[weapon_class]
	pool = pool.Copy()
	var/list/extra_pool = extras?[weapon_class]
	for(var/entry in extra_pool)
		// A main entry always keeps its weight, even if an extra repeats it.
		if(!(entry in pool))
			pool[entry] = extra_pool[entry]
	return pool

/// One prize plus one matching ballistic reload; reloads never consume a draw.
/proc/spawn_loot_prize(atom/destination, loot_path)
	if(!loot_path)
		return
	var/atom/movable/prize = new loot_path(destination)
	. = prize
	var/spare_ammo = GLOB.loot_gun_spare_ammo[loot_path]
	if(spare_ammo)
		new spare_ammo(destination)
		return
	if(!istype(prize, /obj/item/gun/ballistic))
		return
	var/obj/item/gun/ballistic/gun = prize
	// These authored kits already create their own matching reloads.
	if(istype(gun, /obj/item/gun/ballistic/revolver/c38/housecall) || istype(gun, /obj/item/gun/ballistic/shotgun/musket/no_quarter))
		return
	if(!gun.internal_magazine)
		var/magazine_path = gun.accepted_magazine_type
		new magazine_path(destination)
		return
	// Retained specialist weapons may have no boxed ammunition. Give one
	// cylinder/tube of their actual rounds, rather than an incompatible box.
	var/round_path = gun.magazine.ammo_type
	for(var/round in 1 to gun.magazine.max_ammo)
		new round_path(destination)

// Stamp purchased caches before they can be opened, even when dispensed aboard a ship.
/datum/shop_sku/general/rotating/freight_crate/dispense(mob/living/user, mob/living/basic/outpost_trader/vendor)
	. = ..()
	var/obj/structure/closet/crate/zone_loot/cache = .
	cache.freight_weapons = TRUE

/datum/shop_sku/black_market/mystery_cache/dispense(mob/living/user, mob/living/basic/outpost_trader/vendor)
	. = ..()
	var/obj/structure/closet/crate/zone_loot/cache = .
	cache.freight_weapons = TRUE

/datum/shop_sku/black_market/mystery_cache_rare/dispense(mob/living/user, mob/living/basic/outpost_trader/vendor)
	. = ..()
	var/obj/structure/closet/crate/zone_loot/cache = .
	cache.freight_weapons = TRUE

/**
 * Pulls one entry out of `pools` at the requested tier, removing it so the
 * cache can't roll it again.
 *
 * A tier that has been drawn dry (or that a theme never authored, including
 * the whole UNIQUE shelf the abandoned crate deliberately has none of) walks
 * DOWN to the next tier rather than wasting the draw. A cache always pays what
 * it promised, and the failure direction is toward the commoner item, never a
 * free upgrade. Returns null only when every tier is empty.
 */
/proc/draw_loot_from_tier(list/pools, tier)
	if(isnull(tier))
		tier = LOOT_TIER_COMMON
	for(var/attempt in text2num(tier) to 1 step -1)
		var/list/pool = pools["[attempt]"]
		if(!length(pool))
			continue
		var/loot_path = pick_weight(pool)
		if(!loot_path)
			continue
		pool -= loot_path
		return loot_path
	return null
