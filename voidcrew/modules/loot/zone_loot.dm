/**
 * # Zone-Aware Loot Cache
 *
 * One generic container that rolls its contents from a per-zone loot table
 * when it spawns: the same cache type gives mild pickings in the safe outer
 * ring and the good stuff deep in the red. Loot tiers by where it *drops*
 * (source danger), so the zone is locked in at spawn — hauling an unopened
 * cache somewhere else doesn't change what's inside.
 *
 * Caches are placed by MAPPING ruin templates by hand (no automatic
 * spawning), and their value is pinned to where the mapper put them: the
 * spawn turf is captured at init and zone resolution only ever runs against
 * it, so hauling an unopened cache somewhere richer can't retier it.
 *
 * The zone is resolved through SSovermap_zones.get_zone_type_anywhere(),
 * which traces interior turfs (ruin reservations, outpost reservations,
 * planet z-levels) back to their overmap tile. Planet interiors register
 * their mapzone only after the template finishes loading, so resolution
 * retries on a timer; the closet's lazy PopulateContents() (first open or
 * break) is the last chance, after which an unresolved cache counts as
 * green — the weakest table.
 *
 * Subtypes are configs: each defines its three zone tables, plus optional
 * rare tables used by /rare variants ("the top of the zone's table").
 * First config: the syndicate cache.
 */

/// How many times a cache re-attempts zone resolution after spawning
#define ZONE_LOOT_RESOLVE_ATTEMPTS 6
/// Delay between resolution attempts
#define ZONE_LOOT_RESOLVE_RETRY_DELAY (10 SECONDS)

/obj/structure/closet/crate/zone_loot
	name = "abandoned cache"
	desc = "A scuffed cargo cache, sealed since whoever owned it stopped coming back."
	/// The ZONE_* type this cache spawned in (null until resolved)
	var/loot_zone
	/// The turf the cache spawned on — zone resolution is pinned to this, never the current position
	var/turf/spawn_turf
	/// Resolution retries left (covers levels that finish registering after the cache inits)
	var/resolve_attempts_left = ZONE_LOOT_RESOLVE_ATTEMPTS
	/// How many loot rolls the cache gets
	var/loot_rolls_min = 2
	var/loot_rolls_max = 3
	/// Rare variants roll from the rare tables instead (falling back to the normal table)
	var/rare = FALSE
	/// Weighted loot tables (typepath -> weight) keyed by spawn zone
	var/list/loot_green
	var/list/loot_yellow
	var/list/loot_red
	/// Optional rare tables for /rare variants
	var/list/rare_loot_green
	var/list/rare_loot_yellow
	var/list/rare_loot_red

/obj/structure/closet/crate/zone_loot/Destroy()
	spawn_turf = null
	return ..()

/obj/structure/closet/crate/zone_loot/LateInitialize()
	. = ..()
	spawn_turf = get_turf(src)
	try_resolve_zone()

/**
 * Attempts to pin down the spawn zone from the recorded spawn turf.
 * Reschedules itself while the containing level may still be registering
 * (planet mapzones attach only after their template load returns).
 */
/obj/structure/closet/crate/zone_loot/proc/try_resolve_zone()
	if(!isnull(loot_zone) || !spawn_turf)
		return
	loot_zone = SSovermap_zones.get_zone_type_anywhere(spawn_turf)
	if(!isnull(loot_zone))
		spawn_turf = null
		return
	if(resolve_attempts_left-- > 0)
		addtimer(CALLBACK(src, PROC_REF(try_resolve_zone)), ZONE_LOOT_RESOLVE_RETRY_DELAY)

/obj/structure/closet/crate/zone_loot/PopulateContents()
	. = ..()
	// Last chance: resolve against the spawn point (NOT the current
	// position — moving the cache must never change its value), else it
	// counts as the safe ring's weakest table
	if(isnull(loot_zone))
		loot_zone = SSovermap_zones.get_zone_type_anywhere(spawn_turf)
	if(isnull(loot_zone))
		loot_zone = ZONE_GREEN
	spawn_turf = null
	var/list/table = get_loot_table(loot_zone)
	if(!length(table))
		return
	for(var/_ in 1 to rand(loot_rolls_min, loot_rolls_max))
		var/loot_path = pick_weight(table)
		if(loot_path)
			new loot_path(src)

/**
 * The weighted table for a zone, honoring the rare flag.
 */
/obj/structure/closet/crate/zone_loot/proc/get_loot_table(zone_type)
	switch(zone_type)
		if(ZONE_RED)
			return (rare && length(rare_loot_red)) ? rare_loot_red : loot_red
		if(ZONE_YELLOW)
			return (rare && length(rare_loot_yellow)) ? rare_loot_yellow : loot_yellow
	return (rare && length(rare_loot_green)) ? rare_loot_green : loot_green

// =========================================================================
// SYNDICATE CACHE — the first config. Contraband tiered by spawn zone;
// tables follow the black-market shop's price ladder (modules/trade/shop.dm)
// so the gamble channel and the certainty channel stay on one curve.
// TODO: review/balance-pass all six tables below — first-draft weights and
// contents, never playtested. Tune weights against the black-market voucher
// prices in shop.dm.
// TODO(loot-economy item 6): add weapon blueprints once the pipeline lands.
// =========================================================================

/obj/structure/closet/crate/zone_loot/syndicate
	name = "syndicate cache"
	desc = "A matte-black drop crate with the serial numbers burned off. Someone meant to come back for it."
	icon_state = "syndicrate"
	base_icon_state = "syndicrate"
	loot_green = list(
		/obj/item/soap/syndie = 10,
		/obj/item/storage/fancy/cigarettes/cigpack_syndicate = 10,
		/obj/item/knife/combat = 8,
		/obj/item/ammo_box/magazine/m9mm = 8,
		/obj/item/suppressor = 6,
		/obj/item/encryptionkey/syndicate = 6,
		/obj/item/grenade/empgrenade = 5,
		/obj/item/storage/medkit/tactical = 4,
	)
	loot_yellow = list(
		/obj/item/ammo_box/magazine/m9mm = 10,
		/obj/item/gun/ballistic/automatic/pistol = 8,
		/obj/item/storage/medkit/tactical = 7,
		/obj/item/knife/combat = 6,
		/obj/item/grenade/c4 = 6,
		/obj/item/grenade/empgrenade = 6,
		/obj/item/ammo_box/a357 = 5,
		/obj/item/gun/ballistic/revolver = 4,
		/obj/item/card/id/advanced/chameleon = 4,
		/obj/item/clothing/shoes/chameleon/noslip = 4,
		/obj/item/clothing/glasses/thermal/syndi = 3,
	)
	loot_red = list(
		/obj/item/ammo_box/a357 = 9,
		/obj/item/gun/ballistic/revolver = 8,
		/obj/item/storage/medkit/tactical = 8,
		/obj/item/grenade/c4 = 8,
		/obj/item/clothing/glasses/thermal/syndi = 6,
		/obj/item/clothing/shoes/chameleon/noslip = 6,
		/obj/item/card/id/advanced/chameleon = 6,
		/obj/item/melee/energy/sword/saber = 4,
		/obj/item/pen/sleepy = 4,
		/obj/item/grenade/syndieminibomb = 3,
		/obj/item/card/emag = 2,
	)
	rare_loot_green = list(
		/obj/item/storage/medkit/tactical = 8,
		/obj/item/suppressor = 6,
		/obj/item/card/id/advanced/chameleon = 4,
		/obj/item/clothing/glasses/thermal/syndi = 4,
	)
	rare_loot_yellow = list(
		/obj/item/gun/ballistic/revolver = 8,
		/obj/item/clothing/glasses/thermal/syndi = 6,
		/obj/item/clothing/shoes/chameleon/noslip = 6,
		/obj/item/melee/energy/sword/saber = 4,
		/obj/item/pen/sleepy = 4,
	)
	rare_loot_red = list(
		/obj/item/ammo_box/magazine/smgm45 = 8,
		/obj/item/melee/energy/sword/saber = 8,
		/obj/item/pen/sleepy = 6,
		/obj/item/grenade/syndieminibomb = 6,
		/obj/item/gun/ballistic/automatic/c20r = 5,
		/obj/item/card/emag = 4,
	)

/obj/structure/closet/crate/zone_loot/syndicate/rare
	name = "reinforced syndicate cache"
	desc = "A matte-black drop crate in an extra layer of plating. Whatever's inside, somebody thought it was worth the postage."
	rare = TRUE

#undef ZONE_LOOT_RESOLVE_ATTEMPTS
#undef ZONE_LOOT_RESOLVE_RETRY_DELAY
