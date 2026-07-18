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
// loot-economy item 6: weapon blueprints seeded below (c20r in yellow; l6_saw +
// sniper in red and rare-red). Craft them from the recipe anywhere, once you
// have the part and a firing pin (modules/weapons_bench/blueprint.dm).
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
		/obj/item/blueprint/gun/c20r = 4,
		/obj/item/blueprint/gun/wt550 = 3,
		/obj/item/blueprint/gun/laser_carbine = 3,
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
		/obj/item/blueprint/gun/l6_saw = 3,
		/obj/item/blueprint/gun/sniper_rifle = 3,
		/obj/item/blueprint/gun/bulldog = 3,
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
		/obj/item/blueprint/gun/l6_saw = 5,
		/obj/item/blueprint/gun/sniper_rifle = 5,
		/obj/item/blueprint/gun/bulldog = 5,
	)

/obj/structure/closet/crate/zone_loot/syndicate/rare
	name = "reinforced syndicate cache"
	desc = "A matte-black drop crate in an extra layer of plating. Whatever's inside, somebody thought it was worth the postage."
	rare = TRUE

// =========================================================================
// THEMED RAID CACHES — one config per rumor-chart raid ruin (see
// voidcrew/datums/ruins/rare_space.dm). Shells for now: full loot tables
// are authored alongside each ruin's map and merged in here.
// =========================================================================

// RESEARCH CACHE — the Eventide Exotics Annex config (rare_biolab ruin).
// Xenoscience: green = lab consumables / minor science gear, yellow = solid
// research and engineering prizes, red = bluespace and exotic tech.
// TODO: review/balance-pass all six tables — first-draft weights and
// contents, never playtested.
/obj/structure/closet/crate/zone_loot/research
	name = "specimen transfer cache"
	desc = "A sealed specimen-transfer cache stamped with a containment-tier barcode. The manifest slot is empty."
	icon_state = "scicrate"
	base_icon_state = "scicrate"
	loot_green = list(
		/obj/item/storage/box/beakers = 10,
		/obj/item/storage/box/monkeycubes = 10,
		/obj/item/stack/sheet/mineral/plasma/five = 8,
		/obj/item/clothing/glasses/science = 8,
		/obj/item/slime_extract/grey = 6,
		/obj/item/petri_dish = 6,
		/obj/item/experi_scanner = 5,
		/obj/item/stack/ore/bluespace_crystal/artificial = 4,
	)
	loot_yellow = list(
		/obj/item/stack/sheet/mineral/plasma/thirty = 10,
		/obj/item/stock_parts/capacitor/adv = 8,
		/obj/item/stock_parts/micro_laser/high = 8,
		/obj/item/stock_parts/matter_bin/adv = 7,
		/obj/item/slime_extract/metal = 6,
		/obj/item/slime_extract/gold = 5,
		/obj/item/clothing/glasses/night = 5,
		/obj/item/reagent_containers/cup/beaker/noreact = 4,
		/obj/item/raw_anomaly_core/random = 4,
		/obj/item/blueprint/gun/laser_carbine = 3,
	)
	loot_red = list(
		/obj/item/stack/ore/bluespace_crystal/refined = 10,
		/obj/item/stock_parts/capacitor/super = 8,
		/obj/item/stock_parts/micro_laser/ultra = 8,
		/obj/item/stock_parts/matter_bin/super = 7,
		/obj/item/slime_extract/bluespace = 6,
		/obj/item/slime_extract/adamantine = 5,
		/obj/item/clothing/shoes/bhop = 4,
		/obj/item/gun/energy/temperature = 4,
		/obj/item/reagent_containers/cup/beaker/bluespace = 3,
		/obj/item/assembly/signaler/anomaly/grav = 3,
		/obj/item/storage/backpack/holding = 2,
	)
	rare_loot_green = list(
		/obj/item/stack/sheet/mineral/plasma/thirty = 8,
		/obj/item/stock_parts/capacitor/adv = 6,
		/obj/item/slime_extract/metal = 4,
		/obj/item/clothing/glasses/night = 4,
	)
	rare_loot_yellow = list(
		/obj/item/stock_parts/capacitor/super = 8,
		/obj/item/slime_extract/bluespace = 6,
		/obj/item/clothing/shoes/bhop = 6,
		/obj/item/gun/energy/temperature = 4,
		/obj/item/reagent_containers/cup/beaker/bluespace = 4,
	)
	rare_loot_red = list(
		/obj/item/stack/ore/bluespace_crystal/refined = 8,
		/obj/item/stock_parts/matter_bin/bluespace = 8,
		/obj/item/stock_parts/capacitor/quadratic = 6,
		/obj/item/slime_extract/rainbow = 6,
		/obj/item/storage/backpack/holding = 5,
		/obj/item/assembly/signaler/anomaly/bluespace = 4,
		/obj/item/gun/energy/temperature/freeze = 3,
	)

/obj/structure/closet/crate/zone_loot/research/rare
	name = "priority specimen cache"
	desc = "A specimen-transfer cache flagged for priority extraction. Whatever's inside outranked the staff."
	rare = TRUE

// PLUNDER CACHE — The Scuppers Freeport config (rare_pirate_cove ruin).
// Pirate plunder: green = trinkets/booze/small cash, yellow = valuables and
// serviceable weapons, red = treasure (big cash, precious mats, prize gear).
// TODO: review/balance-pass all six tables — first-draft weights and
// contents, never playtested.
/obj/structure/closet/crate/zone_loot/plunder
	name = "plunder cache"
	desc = "A dented cargo cache re-stenciled over three different shipping lines' logos. Finders keepers, apparently."
	icon_state = "wooden"
	base_icon_state = "wooden"
	loot_green = list(
		/obj/item/stack/spacecash/c100 = 10,
		/obj/item/reagent_containers/cup/glass/bottle/rum = 10,
		/obj/item/coin/silver/doubloon = 8,
		/obj/item/reagent_containers/cup/glass/bottle/whiskey = 8,
		/obj/item/clothing/glasses/eyepatch = 6,
		/obj/item/clothing/head/costume/pirate/bandana = 6,
		/obj/item/coin/gold/doubloon = 5,
		/obj/item/knife/combat = 4,
		/obj/item/toy/cards/deck = 4,
	)
	loot_yellow = list(
		/obj/item/stack/spacecash/c500 = 10,
		/obj/item/coin/gold/doubloon = 8,
		/obj/item/gun/ballistic/shotgun/doublebarrel = 7,
		/obj/item/storage/box/lethalshot = 7,
		/obj/item/gun/ballistic/revolver = 6,
		/obj/item/ammo_box/a357 = 6,
		/obj/item/stack/sheet/mineral/gold = 5,
		/obj/item/clothing/head/costume/pirate/armored = 4,
		/obj/item/clothing/suit/costume/pirate/armored = 4,
		/obj/item/reagent_containers/cup/glass/bottle/rum/aged = 4,
		/obj/item/blueprint/gun/laser_carbine = 3,
	)
	loot_red = list(
		/obj/item/stack/spacecash/c1000 = 9,
		/obj/item/coin/gold/doubloon = 8,
		/obj/item/gun/ballistic/shotgun/doublebarrel = 6,
		/obj/item/gun/ballistic/revolver/mateba = 5,
		/obj/item/melee/energy/sword/pirate = 4,
		/obj/item/stack/sheet/mineral/diamond = 4,
		/obj/item/reagent_containers/cup/glass/bottle/absinthe/premium = 4,
		/obj/item/clothing/suit/costume/pirate/captain/armored = 3,
		/obj/item/clothing/head/costume/pirate/captain = 3,
		/obj/item/blueprint/gun/bulldog = 3,
		/obj/item/stack/spacecash/c10000 = 2,
	)
	rare_loot_green = list(
		/obj/item/coin/gold/doubloon = 8,
		/obj/item/stack/spacecash/c500 = 6,
		/obj/item/gun/ballistic/revolver = 6,
		/obj/item/clothing/suit/costume/pirate/armored = 4,
	)
	rare_loot_yellow = list(
		/obj/item/gun/ballistic/shotgun/doublebarrel = 8,
		/obj/item/stack/spacecash/c1000 = 6,
		/obj/item/stack/sheet/mineral/gold = 6,
		/obj/item/melee/energy/sword/pirate = 4,
		/obj/item/clothing/head/costume/pirate/captain = 4,
	)
	rare_loot_red = list(
		/obj/item/stack/spacecash/c1000 = 8,
		/obj/item/gun/ballistic/revolver/mateba = 6,
		/obj/item/melee/energy/sword/pirate = 6,
		/obj/item/stack/sheet/mineral/diamond = 5,
		/obj/item/clothing/suit/costume/pirate/captain/armored = 4,
		/obj/item/blueprint/gun/bulldog = 4,
		/obj/item/stack/spacecash/c10000 = 3,
	)

/obj/structure/closet/crate/zone_loot/plunder/rare
	name = "quartermaster's strongbox"
	desc = "A strongbox off some quartermaster's books. Nobody splits shares on what nobody declared."
	rare = TRUE

// OCCULT CACHE — the Pilgrim's Vow Reliquary config (rare_reliquary ruin).
// Grave-goods and occult curiosities: mechanically useful, none of it
// cult-antag power. Green is candlelight and pocket votives, yellow is solid
// valuables and curios, red is genuine prizes.
//  - soulstone/anybody/purified is the chaplain-issue stone: anyone can use
//    it, it can't be corrupted, and without shells it only carries a willing
//    shade — a companion gimmick, not an army.
//  - coin/eldritch is a cursed curio (diamond+plasma mats, bites non-heretics
//    for 5 on a flip). Flavor tax included.
// TODO: review/balance-pass all six tables — first-draft weights and
// contents, never playtested.
/obj/structure/closet/crate/zone_loot/occult
	name = "votive chest"
	desc = "A chest of offerings, wax-sealed and inscribed with a prayer nobody says anymore."
	icon_state = "wooden"
	base_icon_state = "wooden"
	loot_green = list(
		/obj/item/storage/fancy/candle_box = 10,
		/obj/item/flashlight/flare/candle/infinite = 8,
		/obj/item/coin/silver = 8,
		/obj/item/reagent_containers/cup/glass/bottle/holywater = 6,
		/obj/item/book/bible = 6,
		/obj/item/coin/gold = 5,
		/obj/item/toy/cards/deck/tarot = 5,
		/obj/item/reagent_containers/cup/glass/bottle/wine = 4,
	)
	loot_yellow = list(
		/obj/item/coin/gold = 10,
		/obj/item/statuebust = 8,
		/obj/item/flashlight/lantern = 7,
		/obj/item/ectoplasm = 6,
		/obj/item/clothing/suit/chaplainsuit/bishoprobe = 5,
		/obj/item/clothing/head/chaplain/bishopmitre = 5,
		/obj/item/toy/cards/deck/tarot/haunted = 4,
		/obj/item/coin/eldritch = 3,
	)
	loot_red = list(
		/obj/item/statuebust = 9,
		/obj/item/stack/sheet/mineral/diamond/five = 8,
		/obj/item/stack/sheet/mineral/gold/fifty = 6,
		/obj/item/stack/sheet/mineral/silver/fifty = 6,
		/obj/item/toy/cards/deck/tarot/haunted = 5,
		/obj/item/clothing/suit/armor/riot/knight = 5,
		/obj/item/coin/eldritch = 4,
		/obj/item/soulstone/anybody/purified = 3,
	)
	rare_loot_green = list(
		/obj/item/statuebust = 8,
		/obj/item/coin/gold = 6,
		/obj/item/flashlight/lantern = 5,
		/obj/item/toy/cards/deck/tarot/haunted = 4,
	)
	rare_loot_yellow = list(
		/obj/item/stack/sheet/mineral/diamond/five = 8,
		/obj/item/statuebust = 6,
		/obj/item/clothing/suit/armor/riot/knight = 5,
		/obj/item/coin/eldritch = 5,
		/obj/item/soulstone/anybody/purified = 3,
	)
	rare_loot_red = list(
		/obj/item/stack/sheet/mineral/gold/fifty = 8,
		/obj/item/stack/sheet/mineral/diamond/five = 8,
		/obj/item/soulstone/anybody/purified = 6,
		/obj/item/clothing/suit/armor/riot/knight = 5,
		/obj/item/coin/eldritch = 5,
	)

/obj/structure/closet/crate/zone_loot/occult/rare
	name = "reliquary casket"
	desc = "A casket meant to hold something holy. The seal has been kissed smooth."
	icon_state = "coffin"
	base_icon_state = "coffin"
	rare = TRUE

// INDUSTRIAL CACHE — the Helios-Betna Forgeworks config (rare_foundry ruin).
// Foundry output: green = common material stacks and tier-2 parts, yellow =
// good alloys and tier-3 parts, red = premium materials and tier-4 parts,
// with the RPED/loader-suit prize gear living in the rare tables.
// TODO: review/balance-pass all six tables — first-draft weights and
// contents, never playtested. Tune against outpost shop material prices.
/obj/structure/closet/crate/zone_loot/industrial
	name = "foundry freight cache"
	desc = "A freight cache with a routing label for a company that no longer exists. Still awaiting pickup."
	icon_state = "engi_crate"
	base_icon_state = "engi_crate"
	loot_green = list(
		/obj/item/stack/sheet/iron/fifty = 10,
		/obj/item/stack/sheet/glass/fifty = 10,
		/obj/item/stack/rods/fifty = 8,
		/obj/item/stack/cable_coil = 8,
		/obj/item/stock_parts/capacitor/adv = 6,
		/obj/item/stock_parts/scanning_module/adv = 6,
		/obj/item/stock_parts/micro_laser/high = 6,
		/obj/item/stock_parts/matter_bin/adv = 6,
		/obj/item/storage/toolbox/mechanical = 5,
		/obj/item/weldingtool/largetank = 5,
		/obj/item/stock_parts/power_store/cell/high = 4,
		/obj/item/stack/sheet/plasteel/twenty = 4,
	)
	loot_yellow = list(
		/obj/item/stack/sheet/plasteel/twenty = 10,
		/obj/item/stack/sheet/mineral/titanium/fifty = 8,
		/obj/item/stack/sheet/mineral/plasma/thirty = 7,
		/obj/item/stack/sheet/mineral/silver/fifty = 6,
		/obj/item/stock_parts/capacitor/super = 6,
		/obj/item/stock_parts/scanning_module/phasic = 6,
		/obj/item/stock_parts/micro_laser/ultra = 6,
		/obj/item/stock_parts/matter_bin/super = 6,
		/obj/item/stock_parts/power_store/cell/super = 5,
		/obj/item/storage/part_replacer = 4,
		/obj/item/circuitboard/machine/autolathe = 4,
		/obj/item/stack/sheet/mineral/gold/fifty = 3,
		/obj/item/weldingtool/experimental = 3,
	)
	loot_red = list(
		/obj/item/stack/sheet/plasteel/fifty = 9,
		/obj/item/stack/sheet/mineral/gold/fifty = 8,
		/obj/item/stack/sheet/mineral/uranium/fifty = 7,
		/obj/item/stock_parts/capacitor/quadratic = 6,
		/obj/item/stock_parts/scanning_module/triphasic = 6,
		/obj/item/stock_parts/micro_laser/quadultra = 6,
		/obj/item/stock_parts/matter_bin/bluespace = 6,
		/obj/item/stack/sheet/mineral/diamond/five = 6,
		/obj/item/stock_parts/power_store/cell/hyper = 5,
		/obj/item/stack/sheet/bluespace_crystal = 4,
		/obj/item/construction/rcd = 3,
		/obj/item/stack/sheet/mineral/diamond/fifty = 2,
	)
	rare_loot_green = list(
		/obj/item/stack/sheet/plasteel/twenty = 8,
		/obj/item/stock_parts/power_store/cell/high = 6,
		/obj/item/stack/sheet/mineral/titanium/fifty = 4,
		/obj/item/storage/part_replacer = 4,
	)
	rare_loot_yellow = list(
		/obj/item/stack/sheet/mineral/gold/fifty = 8,
		/obj/item/stock_parts/power_store/cell/super = 6,
		/obj/item/weldingtool/experimental = 4,
		/obj/item/stock_parts/capacitor/quadratic = 4,
		/obj/item/stock_parts/micro_laser/quadultra = 4,
	)
	rare_loot_red = list(
		/obj/item/stack/sheet/mineral/diamond/fifty = 8,
		/obj/item/stack/sheet/mineral/uranium/fifty = 6,
		/obj/item/stock_parts/power_store/cell/bluespace = 6,
		/obj/item/construction/rcd = 6,
		/obj/item/storage/part_replacer/bluespace = 5,
		/obj/item/mod/control/pre_equipped/loader = 4,
	)

/obj/structure/closet/crate/zone_loot/industrial/rare
	name = "certified goods cache"
	desc = "A freight cache stamped CERTIFIED — FINAL INSPECTION PASSED. The line never shipped a finer batch."
	rare = TRUE

// MEDICAL CACHE — the CSV Meridian config (rare_hospice ruin). Field
// medicine tiered up to the miracle shelf: green is the aid-station shelf
// (basic kits and consumables), yellow is the working pharmacy (advanced
// kits, solid chems, entry cybernetics), red is the cold-chain stock nobody
// lived to sign out (top kits, rare chems, tier-2 organs).
// TODO: review/balance-pass all six tables — first-draft weights and
// contents, never playtested. Tune against the outpost shop med prices.
/obj/structure/closet/crate/zone_loot/medical
	name = "quarantine supply cache"
	desc = "A medical supply cache in biohazard livery. The requisition seal was never broken."
	icon_state = "medicalcrate"
	base_icon_state = "medicalcrate"
	loot_green = list(
		/obj/item/storage/medkit/regular = 10,
		/obj/item/stack/medical/gauze = 10,
		/obj/item/storage/medkit/brute = 8,
		/obj/item/storage/medkit/fire = 8,
		/obj/item/storage/medkit/o2 = 8,
		/obj/item/storage/medkit/toxin = 6,
		/obj/item/stack/medical/suture = 6,
		/obj/item/stack/medical/mesh = 6,
		/obj/item/reagent_containers/hypospray/medipen = 5,
		/obj/item/storage/pill_bottle/multiver = 5,
		/obj/item/healthanalyzer = 4,
		/obj/item/reagent_containers/cup/bottle/salglu_solution = 4,
	)
	loot_yellow = list(
		/obj/item/storage/medkit/advanced = 10,
		/obj/item/storage/medkit/surgery = 8,
		/obj/item/stack/medical/suture/medicated = 7,
		/obj/item/stack/medical/mesh/advanced = 7,
		/obj/item/storage/box/medipens = 6,
		/obj/item/reagent_containers/hypospray/medipen/ekit = 6,
		/obj/item/reagent_containers/hypospray/medipen/salacid = 5,
		/obj/item/reagent_containers/hypospray/medipen/oxandrolone = 5,
		/obj/item/reagent_containers/cup/bottle/atropine = 5,
		/obj/item/storage/pill_bottle/penacid = 5,
		/obj/item/defibrillator = 4,
		/obj/item/healthanalyzer/advanced = 4,
		/obj/item/storage/medkit/tactical_lite = 4,
		/obj/item/organ/eyes/robotic/basic = 3,
		/obj/item/organ/liver/cybernetic = 3,
		/obj/item/organ/lungs/cybernetic = 3,
	)
	loot_red = list(
		/obj/item/storage/medkit/advanced = 9,
		/obj/item/storage/medkit/tactical_lite = 8,
		/obj/item/reagent_containers/hypospray/medipen/atropine = 7,
		/obj/item/reagent_containers/hypospray/medipen/penthrite = 6,
		/obj/item/defibrillator/compact = 6,
		/obj/item/storage/medkit/tactical = 5,
		/obj/item/reagent_containers/hypospray/medipen/survival = 5,
		/obj/item/organ/heart/cybernetic = 4,
		/obj/item/organ/eyes/robotic/shield = 4,
		/obj/item/autosurgeon/medical_hud = 4,
		/obj/item/organ/liver/cybernetic/tier2 = 3,
		/obj/item/organ/lungs/cybernetic/tier2 = 3,
		/obj/item/reagent_containers/hypospray/medipen/survival/luxury = 2,
	)
	rare_loot_green = list(
		/obj/item/storage/medkit/advanced = 8,
		/obj/item/storage/medkit/surgery = 6,
		/obj/item/storage/box/medipens = 5,
		/obj/item/defibrillator = 4,
	)
	rare_loot_yellow = list(
		/obj/item/storage/medkit/tactical_lite = 8,
		/obj/item/defibrillator/compact = 6,
		/obj/item/reagent_containers/hypospray/medipen/atropine = 6,
		/obj/item/organ/heart/cybernetic = 4,
		/obj/item/organ/eyes/robotic/shield = 4,
		/obj/item/autosurgeon/medical_hud = 4,
	)
	rare_loot_red = list(
		/obj/item/storage/medkit/tactical = 8,
		/obj/item/reagent_containers/hypospray/medipen/survival/luxury = 6,
		/obj/item/reagent_containers/hypospray/medipen/penthrite = 6,
		/obj/item/organ/heart/cybernetic/tier2 = 5,
		/obj/item/organ/liver/cybernetic/tier2 = 5,
		/obj/item/organ/lungs/cybernetic/tier2 = 5,
		/obj/item/organ/stomach/cybernetic/tier2 = 4,
		/obj/item/reagent_containers/hypospray/medipen/stimulants = 4,
		/obj/item/storage/medkit/tactical/premium = 2,
	)

/obj/structure/closet/crate/zone_loot/medical/rare
	name = "cold-chain pharmacy cache"
	desc = "A refrigerated pharmacy cache, still humming. The good stock was locked away from the wards."
	icon_state = "freezer"
	base_icon_state = "freezer"
	rare = TRUE

// ARMORY CACHE — military/security hardware for ruins with a garrison story
// (weapons labs, chokepoints, fortresses, crashed patrol ships). Green is
// mall-cop kit, yellow is line infantry, red is the riot line's back room.
// TODO: review/balance-pass all six tables — first-draft weights and
// contents, never playtested.
/obj/structure/closet/crate/zone_loot/armory
	name = "armory resupply cache"
	desc = "A stenciled munitions cache, requisition slip long gone. The lock was cut by someone in a hurry."
	icon_state = "weaponcrate"
	base_icon_state = "weaponcrate"
	loot_green = list(
		/obj/item/clothing/suit/armor/vest = 10,
		/obj/item/clothing/head/helmet/sec = 10,
		/obj/item/gun/energy/disabler = 7,
		/obj/item/flashlight/seclite = 7,
		/obj/item/grenade/flashbang = 6,
		/obj/item/clothing/glasses/hud/security/sunglasses = 5,
		/obj/item/melee/baton/security/loaded = 4,
		/obj/item/clothing/mask/balaclava = 4,
	)
	loot_yellow = list(
		/obj/item/clothing/suit/armor/bulletproof = 10,
		/obj/item/gun/ballistic/automatic/pistol/m1911 = 8,
		/obj/item/ammo_box/magazine/m45 = 8,
		/obj/item/gun/ballistic/shotgun/riot = 6,
		/obj/item/shield/riot = 6,
		/obj/item/clothing/suit/armor/vest/marine = 5,
		/obj/item/clothing/gloves/combat = 5,
		/obj/item/clothing/shoes/combat = 5,
		/obj/item/gun/ballistic/rifle/boltaction = 4,
		/obj/item/clothing/under/syndicate/tacticool = 3,
	)
	loot_red = list(
		/obj/item/clothing/suit/armor/riot = 9,
		/obj/item/clothing/head/helmet/toggleable/riot = 8,
		/obj/item/gun/energy/laser = 8,
		/obj/item/clothing/suit/armor/laserproof = 6,
		/obj/item/clothing/head/helmet/marine = 6,
		/obj/item/storage/belt/military/assault = 5,
		/obj/item/gun/energy/e_gun = 4,
		/obj/item/gun/ballistic/rifle/boltaction/prime = 3,
		/obj/item/shield/riot/tele = 3,
		/obj/item/clothing/suit/armor/heavy = 2,
	)
	rare_loot_green = list(
		/obj/item/clothing/suit/armor/bulletproof = 8,
		/obj/item/gun/ballistic/automatic/pistol/m1911 = 6,
		/obj/item/shield/riot = 5,
		/obj/item/clothing/suit/armor/vest/marine = 4,
	)
	rare_loot_yellow = list(
		/obj/item/clothing/suit/armor/riot = 8,
		/obj/item/gun/energy/laser = 6,
		/obj/item/clothing/head/helmet/toggleable/riot = 6,
		/obj/item/storage/belt/military/assault = 4,
	)
	rare_loot_red = list(
		/obj/item/gun/energy/e_gun = 8,
		/obj/item/clothing/suit/armor/heavy = 6,
		/obj/item/shield/riot/tele = 6,
		/obj/item/gun/ballistic/rifle/boltaction/prime = 5,
		/obj/item/clothing/suit/armor/laserproof = 5,
	)

/obj/structure/closet/crate/zone_loot/armory/rare
	name = "sealed ordnance cache"
	desc = "A munitions cache still under factory seal. Someone paid extra for what's in here."
	rare = TRUE

// EXPEDITION CACHE — prospector and frontier kit (mining camps, crash
// sites, survey posts). Green keeps you alive, yellow makes you faster,
// red makes the planet regret you landed.
// TODO: review/balance-pass all six tables — first-draft weights and
// contents, never playtested.
/obj/structure/closet/crate/zone_loot/expedition
	name = "expedition supply cache"
	desc = "A trail-battered supply cache plastered in claim stickers. The last crew never came back for it."
	icon_state = "mining"
	base_icon_state = "mining"
	loot_green = list(
		/obj/item/clothing/suit/hooded/explorer = 10,
		/obj/item/knife/combat/survival = 9,
		/obj/item/gps/mining = 8,
		/obj/item/flashlight/flare = 8,
		/obj/item/stack/marker_beacon/thirty = 6,
		/obj/item/mining_scanner = 6,
		/obj/item/climbing_hook = 5,
		/obj/item/reagent_containers/hypospray/medipen/survival = 4,
		/obj/item/pickaxe = 4,
	)
	loot_yellow = list(
		/obj/item/gun/energy/recharge/kinetic_accelerator = 10,
		/obj/item/storage/belt/mining/alt = 8,
		/obj/item/pickaxe/diamond = 7,
		/obj/item/t_scanner/adv_mining_scanner/lesser = 6,
		/obj/item/wormhole_jaunter = 6,
		/obj/item/survivalcapsule = 5,
		/obj/item/clothing/suit/hooded/cloak/goliath = 4,
		/obj/item/gun/energy/plasmacutter = 4,
	)
	loot_red = list(
		/obj/item/borg/upgrade/modkit/range = 9,
		/obj/item/clothing/shoes/bhop = 7,
		/obj/item/resonator = 7,
		/obj/item/gun/energy/plasmacutter/adv = 6,
		/obj/item/kinetic_crusher = 5,
		/obj/item/clothing/glasses/heat = 4,
		/obj/item/clothing/suit/hooded/cloak/drake = 2,
	)
	rare_loot_green = list(
		/obj/item/gun/energy/recharge/kinetic_accelerator = 8,
		/obj/item/storage/belt/mining/alt = 6,
		/obj/item/wormhole_jaunter = 5,
		/obj/item/pickaxe/diamond = 4,
	)
	rare_loot_yellow = list(
		/obj/item/borg/upgrade/modkit/range = 8,
		/obj/item/resonator = 6,
		/obj/item/gun/energy/plasmacutter/adv = 5,
		/obj/item/clothing/shoes/bhop = 5,
	)
	rare_loot_red = list(
		/obj/item/kinetic_crusher = 8,
		/obj/item/clothing/suit/hooded/cloak/drake = 5,
		/obj/item/clothing/glasses/heat = 5,
		/obj/item/borg/upgrade/modkit/range = 5,
	)

/obj/structure/closet/crate/zone_loot/expedition/rare
	name = "prospector's claim chest"
	desc = "A claim chest with the assay office's wax still on it. Whoever staked this claim struck something."
	rare = TRUE

// WARDROBE CACHE — identity loot: clothes and character pieces so crews
// stop looking like quintuplets. Green is thrift-store, yellow is somebody's
// good coat, red is armored fashion you'll be recognized by.
// TODO: review/balance-pass all six tables — first-draft weights and
// contents, never playtested.
/obj/structure/closet/crate/zone_loot/wardrobe
	name = "lost luggage cache"
	desc = "A dented luggage container from a liner that stopped existing. The name tags have all faded."
	icon_state = "cargo"
	base_icon_state = "cargo"
	loot_green = list(
		/obj/item/clothing/suit/jacket/leather = 10,
		/obj/item/clothing/suit/jacket/bomber = 8,
		/obj/item/clothing/head/beret = 8,
		/obj/item/clothing/under/pants/jeans = 7,
		/obj/item/clothing/suit/costume/poncho = 7,
		/obj/item/clothing/head/cowboy/brown = 6,
		/obj/item/clothing/mask/bandana/skull = 6,
		/obj/item/clothing/head/costume/ushanka = 5,
		/obj/item/clothing/suit/hooded/wintercoat = 5,
		/obj/item/clothing/suit/costume/hawaiian = 4,
		/obj/item/clothing/neck/scarf/red = 4,
	)
	loot_yellow = list(
		/obj/item/clothing/suit/jacket/leather/biker = 10,
		/obj/item/clothing/suit/armor/vest/leather = 8,
		/obj/item/clothing/head/cowboy/black = 7,
		/obj/item/clothing/head/hats/warden/police = 6,
		/obj/item/clothing/under/costume/soviet = 6,
		/obj/item/clothing/suit/costume/judgerobe = 5,
		/obj/item/clothing/gloves/tackler/combat = 5,
		/obj/item/clothing/under/rank/prisoner = 4,
		/obj/item/clothing/mask/gas/sechailer/swat = 4,
	)
	loot_red = list(
		/obj/item/clothing/head/cowboy/bounty = 9,
		/obj/item/clothing/suit/armor/vest/warden/alt = 8,
		/obj/item/clothing/head/helmet/knight = 7,
		/obj/item/clothing/head/cowboy/black/syndicate = 6,
		/obj/item/clothing/suit/hooded/berserker = 4,
		/obj/item/clothing/head/hooded/berserker = 4,
	)
	rare_loot_green = list(
		/obj/item/clothing/suit/jacket/leather/biker = 8,
		/obj/item/clothing/head/cowboy/black = 6,
		/obj/item/clothing/suit/armor/vest/leather = 5,
	)
	rare_loot_yellow = list(
		/obj/item/clothing/head/cowboy/bounty = 8,
		/obj/item/clothing/suit/armor/vest/warden/alt = 6,
		/obj/item/clothing/head/helmet/knight = 5,
	)
	rare_loot_red = list(
		/obj/item/clothing/head/cowboy/bounty = 8,
		/obj/item/clothing/suit/hooded/berserker = 6,
		/obj/item/clothing/head/hooded/berserker = 6,
		/obj/item/clothing/head/cowboy/black/syndicate = 5,
	)

/obj/structure/closet/crate/zone_loot/wardrobe/rare
	name = "couturier's trunk"
	desc = "A tailor's traveling trunk, latches polished by use. Dressing well is the best revenge."
	rare = TRUE

#undef ZONE_LOOT_RESOLVE_ATTEMPTS
#undef ZONE_LOOT_RESOLVE_RETRY_DELAY
