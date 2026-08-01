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
 * The zone is resolved through the shared /datum/zone_resolver
 * (zone_resolution.dm), which traces interior turfs (ruin reservations,
 * outpost reservations, planet z-levels) back to their overmap tile and
 * retries while the level finishes registering. The closet's lazy
 * PopulateContents() (first open or break) is the last chance, after which
 * an unresolved cache counts as green — the weakest table.
 *
 * Subtypes are one-liner configs: each points at a /datum/loot_theme
 * (themes/<theme>.dm) that owns the six tables, the guard-marker pairing
 * and the shop-SKU cross-references. /rare variants read the theme's rare
 * tables ("the top of the zone's table").
 *
 * Contents roll WITHOUT replacement within one cache: a single cache can
 * never pay the same prize twice, which is what keeps the rare tables'
 * one-of-a-kind items unique per cache (see the uniques file headers).
 *
 * Ballistic guns ship with a spare reload beside them (see
 * GLOB.loot_gun_spare_ammo below), so a gun roll is never a dead roll.
 */

/**
 * Ballistic loot guns -> one spare reload that spawns beside them.
 *
 * tg ballistics already spawn with a full magazine, so this is the SECOND
 * one: without it a cache could pay a revolver whose six rounds are the
 * whole prize, and the crew has no route to more .357 short of the outpost.
 * Energy guns are deliberately absent — they recharge, so they need nothing.
 *
 * Internal-magazine guns (revolvers, bolt-actions, break-actions) can't take
 * a spare magazine, so they get the matching loose ammo box or shell box
 * instead. The bonus is spawned on top of the roll, not drawn from the
 * table, so it never displaces a prize.
 */
GLOBAL_LIST_INIT(loot_gun_spare_ammo, list(
	// detachable magazines
	/obj/item/gun/ballistic/automatic/ar = /obj/item/ammo_box/magazine/m223,
	/obj/item/gun/ballistic/automatic/c20r = /obj/item/ammo_box/magazine/smgm45,
	/obj/item/gun/ballistic/automatic/gyropistol = /obj/item/ammo_box/magazine/m75,
	/obj/item/gun/ballistic/automatic/l6_saw = /obj/item/ammo_box/magazine/m7mm,
	/obj/item/gun/ballistic/automatic/m90 = /obj/item/ammo_box/magazine/m223,
	/obj/item/gun/ballistic/automatic/mini_uzi = /obj/item/ammo_box/magazine/uzim9mm,
	/obj/item/gun/ballistic/automatic/pistol = /obj/item/ammo_box/magazine/m9mm,
	/obj/item/gun/ballistic/automatic/pistol/deagle = /obj/item/ammo_box/magazine/m50,
	/obj/item/gun/ballistic/automatic/pistol/m1911 = /obj/item/ammo_box/magazine/m45,
	/obj/item/gun/ballistic/automatic/proto = /obj/item/ammo_box/magazine/smgm9mm,
	/obj/item/gun/ballistic/automatic/tommygun = /obj/item/ammo_box/magazine/tommygunm45,
	/obj/item/gun/ballistic/automatic/wt550 = /obj/item/ammo_box/magazine/wt550m9,
	/obj/item/gun/ballistic/rifle/sniper_rifle = /obj/item/ammo_box/magazine/sniper_rounds,
	/obj/item/gun/ballistic/shotgun/bulldog = /obj/item/ammo_box/magazine/m12g,
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
	/// The turf the cache spawned on — zone resolution is pinned to this, never the current position
	var/turf/spawn_turf
	/// How many loot rolls the cache gets
	var/loot_rolls_min = 2
	var/loot_rolls_max = 3
	/// Rare variants roll from the theme's rare tables instead (falling back to the normal table)
	var/rare = FALSE

/obj/structure/closet/crate/zone_loot/Destroy()
	spawn_turf = null
	return ..()

/obj/structure/closet/crate/zone_loot/LateInitialize()
	. = ..()
	spawn_turf = get_turf(src)
	new /datum/zone_resolver(spawn_turf, CALLBACK(src, PROC_REF(on_zone_resolved)))

/**
 * Resolver result. A null zone means every retry failed — keep the pinned
 * spawn turf so the lazy PopulateContents() gets one last synchronous try.
 */
/obj/structure/closet/crate/zone_loot/proc/on_zone_resolved(zone_type)
	if(QDELETED(src) || !isnull(loot_zone) || isnull(zone_type))
		return
	loot_zone = zone_type
	spawn_turf = null

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
	// draw without replacement: one cache never rolls the same entry twice
	table = table.Copy()
	for(var/_ in 1 to rand(loot_rolls_min, loot_rolls_max))
		if(!length(table))
			break
		var/loot_path = pick_weight(table)
		if(!loot_path)
			break
		table -= loot_path
		new loot_path(src)
		// a looted ballistic brings one spare reload with it; energy guns
		// aren't in the map and need nothing
		var/spare_ammo = GLOB.loot_gun_spare_ammo[loot_path]
		if(spare_ammo)
			new spare_ammo(src)

/**
 * The weighted table for a zone, honoring the rare flag, read from the
 * cache's loot theme.
 */
/obj/structure/closet/crate/zone_loot/proc/get_loot_table(zone_type)
	var/datum/loot_theme/loot_theme = GLOB.loot_themes[theme]
	if(!loot_theme)
		return null
	switch(zone_type)
		if(ZONE_RED)
			return (rare && length(loot_theme.rare_loot_red)) ? loot_theme.rare_loot_red : loot_theme.loot_red
		if(ZONE_YELLOW)
			return (rare && length(loot_theme.rare_loot_yellow)) ? loot_theme.rare_loot_yellow : loot_theme.loot_yellow
	return (rare && length(loot_theme.rare_loot_green)) ? loot_theme.rare_loot_green : loot_theme.loot_green
