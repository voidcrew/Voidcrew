// =========================================================================
// RESEARCH THEME: the Eventide Exotics Annex config (rare_biolab ruin) and
// every lab/anomaly ruin. Xenoscience: common = lab consumables / minor
// science gear, uncommon = solid research and engineering prizes, prime =
// bluespace and exotic tech. Guarded by loose specimens (the bug markers).
// Cyberware: the two pieces that read as instrumentation rather than
// augmentation, a bone-conducted sonar transceiver, and the skull jack that
// patches a helm console straight into a head.
// TODO: review/balance-pass all four tiers: first-draft weights and
// contents, never playtested.
// =========================================================================

/datum/loot_theme/research
	name = "research"
	guard_themes = list(/obj/effect/zone_mobs/bug, /obj/effect/zone_mobs/bug/boss)
	theme_skus = list(
		/datum/shop_sku/outfitter/carbine_blueprint,
		/datum/shop_sku/ripperdoc/doppler,
		/datum/shop_sku/ripperdoc/rigger,
	)
	loot_common = list(
		/obj/item/storage/box/beakers = 10,
		/obj/item/storage/box/monkeycubes = 10,
		/obj/item/stack/sheet/mineral/plasma/five = 8,
		/obj/item/clothing/glasses/science = 8,
		/obj/item/slime_extract/grey = 6,
		/obj/item/petri_dish = 6,
		/obj/item/experi_scanner = 5,
		/obj/item/research_notes/loot/tiny = 5,
		// containment sidearm: every lab that kept specimens kept one
		/obj/item/gun/energy/e_gun/mini = 5,
		/obj/item/stack/ore/bluespace_crystal/artificial = 4,
	)
	loot_uncommon = list(
		/obj/item/stack/sheet/mineral/plasma/thirty = 10,
		/obj/item/stock_parts/capacitor/adv = 8,
		/obj/item/stock_parts/micro_laser/high = 8,
		/obj/item/stock_parts/matter_bin/adv = 7,
		/obj/item/slime_extract/metal = 6,
		/obj/item/slime_extract/gold = 5,
		/obj/item/clothing/glasses/night = 5,
		/obj/item/research_notes/loot/small = 5,
		/obj/item/gun/energy/laser/retro = 6,
		/obj/item/gun/energy/recharge/ebow = 4,
		/obj/item/reagent_containers/cup/beaker/noreact = 4,
		/obj/item/raw_anomaly_core/random = 4,
		/obj/item/blueprint/gun/laser_carbine = 3,
		/obj/item/ship_parts/science = 7,
		// lab hardware worn instead of carried: a sonar transceiver socketed
		// into the bone behind the ear, reading movement through walls
		/obj/item/organ/cyberimp/cyberware/doppler = 3,
	)
	loot_prime = list(
		/obj/item/stack/ore/bluespace_crystal/refined = 10,
		/obj/item/stock_parts/capacitor/super = 8,
		/obj/item/stock_parts/micro_laser/ultra = 8,
		/obj/item/stock_parts/matter_bin/super = 7,
		/obj/item/slime_extract/bluespace = 6,
		/obj/item/slime_extract/adamantine = 5,
		/obj/item/research_notes/loot/medium = 5,
		/obj/item/clothing/shoes/bhop = 4,
		/obj/item/gun/energy/xray = 4,
		// finished blueprint gun, prime only: the annex built its own
		/obj/item/gun/energy/laser/carbine = 4,
		/obj/item/gun/energy/temperature = 4,
		/obj/item/reagent_containers/cup/beaker/bluespace = 3,
		/obj/item/assembly/signaler/anomaly/grav = 3,
		/obj/item/storage/backpack/holding = 2,
		// the deepest slice of the theme, previously reachable only through
		// a sealed cache: now the long tail of prime, open to any band
		/obj/item/stock_parts/matter_bin/bluespace = 6,
		/obj/item/research_notes/loot/big = 4,
		/obj/item/gun/energy/lasercannon = 3,
		/obj/item/book/granter/action/spell/charge = 2,
		/obj/item/gun/magic/wand/polymorph = 2,
		/obj/item/research_notes/loot/genius = 2,
		/obj/item/singularityhammer = 2,
		// the annex's own interface work: a skull jack that flies a ship from
		// anywhere aboard it, as long as the hull still has a helm console
		/obj/item/organ/cyberimp/cyberware/rigger = 2,
	)
	// One-of-a-kind authored prizes, drawn as the fourth tier from any
	// band (weight = how shallow the item used to sit: 3 was reachable
	// early, 1 was the bottom of the deepest cache).
	loot_uniques = list(
		/obj/item/book/annex_notebook = 3,
		/obj/item/clothing/glasses/science/calibration_prism = 3,
		/obj/item/displacer_fork = 2,
		/obj/item/reagent_containers/cup/beaker/entangled = 2,
		/obj/item/clothing/gloves/fingerless/chronal_splint = 1,
		/obj/item/clothing/suit/toggle/labcoat/eventide_courier = 1,
	)

/obj/structure/closet/crate/zone_loot/research
	name = "specimen transfer cache"
	desc = "A sealed specimen-transfer cache stamped with a containment-tier barcode. The manifest slot is empty."
	icon_state = "scicrate"
	base_icon_state = "scicrate"
	theme = /datum/loot_theme/research

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
