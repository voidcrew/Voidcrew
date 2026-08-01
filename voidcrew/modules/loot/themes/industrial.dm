// =========================================================================
// INDUSTRIAL THEME — the Helios-Betna Forgeworks config (rare_foundry ruin)
// and every dead factory and freight depot. Foundry output: green = common
// material stacks and tier-2 parts, yellow = good alloys and tier-3 parts,
// red = premium materials and tier-4 parts, with the RPED/loader-suit prize
// gear living in the rare tables. Guarded by malfunctioning automation.
//  - flamethrower/full came over from the retired icemoon-portal jackpot
//    (see cave_entrance.dm): industrial plant equipment, yellow-tier.
// TODO: review/balance-pass all six tables — first-draft weights and
// contents, never playtested. Tune against outpost shop material prices and
// the Boffin stall parts SKUs in theme_skus.
// =========================================================================

/datum/loot_theme/industrial
	name = "industrial"
	guard_themes = list(/obj/effect/zone_mobs/robot, /obj/effect/zone_mobs/robot/boss)
	theme_skus = list(
		/datum/shop_sku/skunk/capacitor,
		/datum/shop_sku/skunk/micro_laser,
		/datum/shop_sku/skunk/scanning_module,
		/datum/shop_sku/skunk/matter_bin,
		/datum/shop_sku/skunk/high_cell,
		/datum/shop_sku/skunk/rped,
	)
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
		// the line's own prototype SMG, never finished, still fires
		/obj/item/gun/ballistic/automatic/proto = 5,
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
		// asset-denial kit, and the answer to this theme's own hivebot
		// guards: ion weapons wreck automation
		/obj/item/gun/energy/ionrifle/carbine = 6,
		/obj/item/gun/ballistic/automatic/proto = 5,
		/obj/item/circuitboard/machine/autolathe = 4,
		/obj/item/flamethrower/full = 3,
		/obj/item/stack/sheet/mineral/gold/fifty = 3,
		/obj/item/weldingtool/experimental = 3,
		/obj/item/ship_parts/trade = 8,
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
		/obj/item/gun/energy/ionrifle = 6,
		/obj/item/stack/sheet/bluespace_crystal = 4,
		/obj/item/construction/rcd = 3,
		/obj/item/stack/sheet/mineral/diamond/fifty = 2,
		/obj/item/ship_parts/trade = 11,
	)
	// Rare tables: surviving stock entries + this theme's uniques at ~4
	// (see voidcrew/modules/loot/uniques/industrial.dm and the design doc)
	rare_loot_green = list(
		/obj/item/stack/sheet/plasteel/twenty = 8,
		/obj/item/stock_parts/power_store/cell/high = 6,
		/obj/item/gun/ballistic/automatic/proto = 5,
		/obj/item/storage/toolbox/helios_lunch_pail = 4,
		/obj/item/analyzer/honest_gauge = 4,
	)
	rare_loot_yellow = list(
		/obj/item/stack/sheet/mineral/gold/fifty = 8,
		/obj/item/stock_parts/power_store/cell/super = 6,
		/obj/item/gun/energy/ionrifle/carbine = 5,
		/obj/item/weldingtool/slagmaw = 4,
		/obj/item/clothing/gloves/cargo_gauntlet/line_gauntlet = 4,
	)
	rare_loot_red = list(
		/obj/item/stack/sheet/mineral/diamond/fifty = 8,
		/obj/item/construction/rcd = 6,
		/obj/item/gun/energy/ionrifle = 5,
		/obj/item/stock_parts/power_store/cell/forge_heart = 4,
		/obj/item/stamp/helios_pattern = 4,
	)

/obj/structure/closet/crate/zone_loot/industrial
	name = "foundry freight cache"
	desc = "A freight cache with a routing label for a company that no longer exists. Still awaiting pickup."
	icon_state = "engi_crate"
	base_icon_state = "engi_crate"
	theme = /datum/loot_theme/industrial

/obj/structure/closet/crate/zone_loot/industrial/rare
	name = "certified goods cache"
	desc = "A freight cache stamped CERTIFIED — FINAL INSPECTION PASSED. The line never shipped a finer batch."
	rare = TRUE

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
