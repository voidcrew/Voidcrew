/**
 * Deca-code freight keeps its lock and 5-7 draws. One draw is a weapon from
 * its spawn-zone profile; the others retain the nonweapon freight tables.
 * Freight never pays advanced guns, cyberware or authored unique weapons.
 */

/// Nonweapon commercial cargo, drawn without replacement within each tier.
GLOBAL_LIST_INIT(abandoned_crate_common, list(
	/obj/item/storage/medkit/regular = 8,
	/obj/item/stack/sheet/iron/fifty = 8,
	/obj/item/stack/sheet/glass/fifty = 7,
	/obj/item/tank/internals/oxygen = 7,
	/obj/item/reagent_containers/hypospray/medipen = 6,
	/obj/item/storage/box/donkpockets = 6,
	/obj/item/food/rationpack = 5,
	/obj/item/clothing/glasses/meson = 5,
	/obj/item/gps = 5,
	/obj/item/stack/spacecash/c100 = 5,
	/obj/item/clothing/gloves/color/yellow = 5,
	/obj/item/storage/box/lethalshot = 5,
	/obj/item/reagent_containers/cup/glass/bottle/whiskey = 5,
	/obj/item/clothing/suit/hooded/wintercoat = 4,
	/obj/item/stack/medical/gauze/twelve = 4,
	/obj/item/grenade/smokebomb = 4,
))

/// Worth the code-cracking on its own: the shipment had something on it.
GLOBAL_LIST_INIT(abandoned_crate_uncommon, list(
	// any class, not just misc: the manifest doesn't know what it's carrying
	/obj/effect/spawner/random/ship_parts = 8,
	/obj/item/stack/sheet/plasteel/twenty = 8,
	/obj/item/tank/jetpack/oxygen = 7,
	/obj/item/storage/medkit/advanced = 7,
	/obj/item/clothing/suit/armor/vest = 6,
	/obj/item/stack/spacecash/c500 = 6,
	/obj/item/stack/sheet/mineral/plasma/thirty = 6,
	/obj/item/stock_parts/power_store/cell/super = 5,
	/obj/item/stack/sheet/mineral/titanium/fifty = 5,
	/obj/item/reagent_containers/hypospray/medipen/survival = 5,
	/obj/item/storage/backpack/duffelbag/med = 4,
	/obj/item/survivalcapsule = 4,
	/obj/item/wormhole_jaunter = 4,
	/obj/item/grenade/flashbang = 4,
	/obj/item/tank/internals/plasma/full = 3,
))

/// The top of freight, and deliberately the top of nothing else. Gear a crew
/// reorganizes an afternoon around, never gear it reorganizes the round
/// around: no uniques, no chrome, no five-figure cash.
GLOBAL_LIST_INIT(abandoned_crate_prime, list(
	/obj/item/stack/sheet/plasteel/fifty = 7,
	/obj/item/ship_parts/combat = 7,
	/obj/item/construction/rcd/loaded = 6,
	/obj/item/stock_parts/power_store/cell/hyper = 5,
	/obj/item/defibrillator/compact = 5,
	/obj/item/stack/spacecash/c1000 = 5,
	/obj/item/stack/sheet/mineral/uranium/fifty = 5,
	/obj/item/stack/sheet/mineral/gold/fifty = 5,
	/obj/item/storage/medkit/surgery = 4,
	/obj/item/stack/sheet/mineral/diamond/five = 4,
	/obj/item/clothing/glasses/night = 4,
	// a loaded bluespace RPED: ten each of tier-3 parts, enough to re-fit
	// every machine on a hull in one pass. Tier 4 exists a line above this one
	// in part_replacer.dm if this plays too weak
	/obj/item/storage/part_replacer/bluespace/tier3 = 3,
))

GLOBAL_LIST_INIT(abandoned_crate_guns_green, list(
	/obj/item/gun/ballistic/rifle/boltaction/surplus,
	/obj/item/gun/ballistic/automatic/pistol,
	/obj/item/gun/ballistic/revolver/c38/detective,
	/obj/item/gun/ballistic/shotgun/doublebarrel,
))

GLOBAL_LIST_INIT(abandoned_crate_guns_yellow, list(
	/obj/item/gun/ballistic/shotgun/riot,
	/obj/item/gun/ballistic/automatic/tommygun,
	/obj/item/gun/ballistic/automatic/mini_uzi,
))

GLOBAL_LIST_INIT(abandoned_crate_melee_green, list(
	/obj/item/knife/combat/survival,
	/obj/item/spear,
	/obj/item/hatchet,
	/obj/item/melee/baseball_bat,
))

GLOBAL_LIST_INIT(abandoned_crate_melee_yellow, list(
	/obj/item/knife/combat,
	/obj/item/claymore/shortsword,
	/obj/item/melee/baseball_bat/ablative,
	/obj/item/fireaxe,
	/obj/item/melee/cleric_mace,
	/obj/item/melee/sabre,
))

GLOBAL_LIST_INIT(abandoned_crate_melee_red, list(
	/obj/item/claymore,
	/obj/item/claymore/cutlass,
	/obj/item/katana,
	/obj/item/mjollnir,
	/obj/item/melee/energy/sword/saber,
	/obj/item/melee/energy/sword/pirate,
))

/**
 * One Bernoulli gun roll, then a class roll in thousandths. Freight folds
 * the gun ladder's red class into yellow (940/60, 450/550, 150/850).
 * Melee retains all three classes: 900/99/1, 350/640/10, 100/450/450.
 * Explicit rolls let tests enumerate the exact distribution without sampling.
 */
/proc/freight_weapon_pool(zone_type, gun_roll = rand(1, 100), class_roll = rand(1, 1000))
	var/gun_chance = 8
	var/gun_green = 940
	var/melee_green = 900
	var/melee_through_yellow = 999
	switch(zone_type)
		if(ZONE_YELLOW)
			gun_chance = 19
			gun_green = 450
			melee_green = 350
			melee_through_yellow = 990
		if(ZONE_RED)
			gun_chance = 33
			gun_green = 150
			melee_green = 100
			melee_through_yellow = 550
	if(gun_roll <= gun_chance)
		return class_roll <= gun_green ? GLOB.abandoned_crate_guns_green : GLOB.abandoned_crate_guns_yellow
	if(class_roll <= melee_green)
		return GLOB.abandoned_crate_melee_green
	if(class_roll <= melee_through_yellow)
		return GLOB.abandoned_crate_melee_yellow
	return GLOB.abandoned_crate_melee_red

/obj/structure/closet/crate/secure/loot
	/// Resolved once at the origin; moving the crate cannot improve it.
	var/loot_zone
	var/turf/spawn_turf

/obj/structure/closet/crate/secure/loot/Initialize(mapload)
	spawn_turf = spawned_loot ? null : get_turf(src)
	return ..()

/obj/structure/closet/crate/secure/loot/LateInitialize()
	. = ..()
	if(!spawned_loot)
		new /datum/zone_resolver(spawn_turf, CALLBACK(src, PROC_REF(on_freight_zone_resolved)))

/obj/structure/closet/crate/secure/loot/proc/on_freight_zone_resolved(zone_type)
	if(QDELETED(src) || spawned_loot || !isnull(loot_zone) || isnull(zone_type))
		return
	loot_zone = zone_type
	spawn_turf = null

/// The same latch covers correct-code payout, forced opening and rebuilds.
/obj/structure/closet/crate/secure/loot/proc/consume_freight_loot()
	spawned_loot = TRUE
	spawn_turf = null

/obj/structure/closet/crate/secure/loot/dump_contents()
	// All opening, break, cut and anti-tamper explosion paths dump contents.
	// Only the correct-code branch calls spawn_loot() before reaching this.
	consume_freight_loot()
	return ..()

/obj/structure/closet/crate/secure/loot/emag_act(mob/user, obj/item/card/emag/emag_card)
	consume_freight_loot()
	return ..()

/obj/structure/closet/crate/secure/loot/Destroy()
	consume_freight_loot()
	return ..()

/// Replaces upstream's gag table; only a correct code requests this payout.
/obj/structure/closet/crate/secure/loot/spawn_loot()
	if(QDELETED(src) || spawned_loot)
		return
	// Claim before any item constructor can yield or re-enter this proc.
	spawned_loot = TRUE
	if(isnull(loot_zone))
		loot_zone = SSovermap_zones.get_zone_type_anywhere(spawn_turf)
	if(isnull(loot_zone))
		loot_zone = ZONE_GREEN
	consume_freight_loot()
	var/weapon_path = pick(freight_weapon_pool(loot_zone))
	new weapon_path(src)
	var/spare_ammo = GLOB.loot_gun_spare_ammo[weapon_path]
	if(spare_ammo)
		new spare_ammo(src)
	var/list/pools = list(
		"[LOOT_TIER_COMMON]" = GLOB.abandoned_crate_common.Copy(),
		"[LOOT_TIER_UNCOMMON]" = GLOB.abandoned_crate_uncommon.Copy(),
		"[LOOT_TIER_PRIME]" = GLOB.abandoned_crate_prime.Copy(),
	)
	roll_loot_draws(src, pools, rand(ABANDONED_CRATE_DRAWS_MIN, ABANDONED_CRATE_DRAWS_MAX) - 1, ABANDONED_CRATE_ODDS)
