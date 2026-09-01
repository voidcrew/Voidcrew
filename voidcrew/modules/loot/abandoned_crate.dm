/**
 * # Abandoned crate loot
 *
 * Replaces tg's `spawn_loot()` (code/modules/mining/abandoned_crates.dm),
 * which was a 1-100 switch that paid a plushie, a balloon, kitty ears or a
 * banhammer-and-bwoink-mines gag roughly seven times in ten. That table is
 * written for a station round where the crate is a bit of maintenance
 * furniture. Out here a crate is a two-jump trip and a bomb you have to
 * out-think, so it pays like one.
 *
 * WHAT THIS IS NOT: a zone cache. The nine themed caches
 * (voidcrew/modules/loot/themes/) are the other channel and they stay the
 * better one, because they are guarded, band-scaled and hold the authored
 * uniques. This crate is the flat one: a shipping container nobody came back
 * for, identical odds in green space and in red. The lock is what it charges
 * instead of a zone (see the header block on the constants in
 * voidcrew/_DEFINES/loot.dm for why that trade is the whole design).
 *
 * The content split follows from that. A themed cache is a PURPOSEFUL
 * stockpile: an armory holds an armory's guns, a lab holds a lab's science, a
 * pirate hoard holds treasure. Freight is COMMERCIAL CARGO, which is to say
 * anything a hauler moves: a pallet of plasteel, a case of medkits, a crate of
 * surplus rifles, a bale of winter coats. Breadth is the identity, not a
 * subject.
 *
 * That extends to the guns, and it is the main thing keeping this table off
 * the armory theme's toes. The armory pays the SEC-ISSUE ladder (vest and
 * helmet, disabler, seclite, baton, riot line). Freight pays what turns up in
 * a container: surplus bolt-actions, hunting doubles, a riot pump, a Makarov,
 * a detective's .38, an uzi, a tommygun. Civilian, surplus and criminal
 * hardware rather than anybody's service weapon, and every ballistic brings a
 * spare reload via GLOB.loot_gun_spare_ammo so a gun roll is never dead.
 *
 * Still excluded, all four the other channel's job: cyberware, authored
 * uniques, themed weapon SETS, and five-figure cash.
 *
 * Tuned against the outpost shelves, which are the certainty channel to this
 * crate's gamble (plasteel x20 = 900cr, jetpack = 2100cr, RCD = 2400cr, the
 * dearest general SKU = 3600cr). A cracked crate averages a couple of hundred
 * credits of loose cash, about one gun, and 5-7 items a crew would otherwise
 * have flown to a trader for. It is a good crate. It is not a round-winning
 * one.
 */

/// Freight bulk: consumables, kit and the surplus long gun off the bottom of
/// the manifest. A crate that paid nothing but these would still be worth
/// cracking, which is the bar this tier has to clear.
GLOBAL_LIST_INIT(abandoned_crate_common, list(
	/obj/item/storage/medkit/regular = 8,
	/obj/item/stack/sheet/iron/fifty = 8,
	// the container gun: war-surplus, one shot at a time, and it arrives with
	// a box of 310 to feed it
	/obj/item/gun/ballistic/rifle/boltaction/surplus = 7,
	/obj/item/stack/sheet/glass/fifty = 7,
	/obj/item/tank/internals/oxygen = 7,
	/obj/item/knife/combat = 6,
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
	/obj/item/gun/ballistic/shotgun/riot = 6,
	/obj/item/clothing/suit/armor/vest = 6,
	/obj/item/stack/spacecash/c500 = 6,
	/obj/item/stack/sheet/mineral/plasma/thirty = 6,
	/obj/item/gun/ballistic/automatic/pistol = 5,
	/obj/item/gun/ballistic/revolver/c38/detective = 5,
	/obj/item/gun/ballistic/shotgun/doublebarrel = 5,
	/obj/item/stock_parts/power_store/cell/super = 5,
	/obj/item/stack/sheet/mineral/titanium/fifty = 5,
	/obj/item/reagent_containers/hypospray/medipen/survival = 5,
	// somebody was moving these in a crate marked FARM EQUIPMENT
	/obj/item/gun/ballistic/automatic/mini_uzi = 4,
	/obj/item/gun/ballistic/automatic/tommygun = 4,
	/obj/item/storage/backpack/duffelbag/med = 4,
	/obj/item/survivalcapsule = 4,
	/obj/item/wormhole_jaunter = 4,
	/obj/item/grenade/flashbang = 4,
	/obj/item/tank/internals/plasma/full = 3,
))

/// The top of freight, and deliberately the top of nothing else. Gear a crew
/// reorganizes an afternoon around, never gear it reorganizes the round
/// around: no uniques, no chrome, no five-figure cash. The blueprint is the
/// one long-odds reach into the weapons-bench pipeline, at the tier the themed
/// caches already put a mid blueprint on.
GLOBAL_LIST_INIT(abandoned_crate_prime, list(
	/obj/item/stack/sheet/plasteel/fifty = 7,
	/obj/item/ship_parts/combat = 7,
	/obj/item/construction/rcd/loaded = 6,
	/obj/item/gun/ballistic/shotgun/automatic/combat = 6,
	/obj/item/gun/energy/e_gun = 5,
	/obj/item/gun/ballistic/automatic/pistol/deagle = 5,
	/obj/item/stock_parts/power_store/cell/hyper = 5,
	/obj/item/defibrillator/compact = 5,
	/obj/item/stack/spacecash/c1000 = 5,
	/obj/item/stack/sheet/mineral/uranium/fifty = 5,
	/obj/item/stack/sheet/mineral/gold/fifty = 5,
	/obj/item/gun/energy/laser = 4,
	/obj/item/gun/ballistic/rifle/boltaction = 4,
	/obj/item/storage/medkit/surgery = 4,
	/obj/item/stack/sheet/mineral/diamond/five = 4,
	/obj/item/clothing/glasses/night = 4,
	/obj/item/blueprint/gun/wt550 = 3,
	// a loaded bluespace RPED: ten each of tier-3 parts, enough to re-fit
	// every machine on a hull in one pass. Tier 4 exists a line above this one
	// in part_replacer.dm if this plays too weak
	/obj/item/storage/part_replacer/bluespace/tier3 = 3,
))

/**
 * Fires once, and only from the correct-code branch of attack_hand(). A crate
 * that gets blown, cut or emagged never reaches here, which is why the table
 * can afford to be this good.
 *
 * Draws WITHOUT replacement, so one crate never pays the same line twice, and
 * an exhausted tier walks down rather than wasting the draw (see
 * draw_loot_from_tier in zone_loot.dm). There is no UNIQUE tier here; the
 * odds never select one, and the walk-down handles the missing shelf anyway.
 */
/obj/structure/closet/crate/secure/loot/spawn_loot()
	var/list/pools = list(
		"[LOOT_TIER_COMMON]" = GLOB.abandoned_crate_common.Copy(),
		"[LOOT_TIER_UNCOMMON]" = GLOB.abandoned_crate_uncommon.Copy(),
		"[LOOT_TIER_PRIME]" = GLOB.abandoned_crate_prime.Copy(),
	)
	roll_loot_draws(src, pools, rand(ABANDONED_CRATE_DRAWS_MIN, ABANDONED_CRATE_DRAWS_MAX), ABANDONED_CRATE_ODDS)
	spawned_loot = TRUE
