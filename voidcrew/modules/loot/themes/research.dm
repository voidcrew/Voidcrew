// =========================================================================
// RESEARCH THEME — the Eventide Exotics Annex config (rare_biolab ruin) and
// every lab/anomaly ruin. Xenoscience: green = lab consumables / minor
// science gear, yellow = solid research and engineering prizes, red =
// bluespace and exotic tech. Guarded by loose specimens (the bug markers).
// TODO: review/balance-pass all six tables — first-draft weights and
// contents, never playtested.
// =========================================================================

/datum/loot_theme/research
	name = "research"
	guard_themes = list(/obj/effect/zone_mobs/bug, /obj/effect/zone_mobs/bug/boss)
	theme_skus = list(
		/datum/shop_sku/outfitter/carbine_blueprint,
	)
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
		/obj/item/ship_parts/science = 7,
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
		/obj/item/ship_parts/science = 10,
	)
	// Rare tables: surviving stock entries + this theme's uniques at ~4
	// (see voidcrew/modules/loot/uniques/research.dm and the design doc)
	rare_loot_green = list(
		/obj/item/stack/sheet/mineral/plasma/thirty = 8,
		/obj/item/stock_parts/capacitor/adv = 6,
		/obj/item/clothing/glasses/science/calibration_prism = 4,
		/obj/item/book/annex_notebook = 4,
	)
	// The weight-2 arcana below are the retired icemoon-portal wizard shelf's
	// tech-flavored half, rehomed here by owner request: unstable
	// transmutation (polymorph), recharging magic (charge), and a contained
	// singularity on a stick.
	rare_loot_yellow = list(
		/obj/item/stock_parts/capacitor/super = 8,
		/obj/item/slime_extract/bluespace = 6,
		/obj/item/reagent_containers/cup/beaker/entangled = 4,
		/obj/item/displacer_fork = 4,
		/obj/item/gun/magic/wand/polymorph = 2,
		/obj/item/book/granter/action/spell/charge = 2,
	)
	rare_loot_red = list(
		/obj/item/stack/ore/bluespace_crystal/refined = 8,
		/obj/item/stock_parts/matter_bin/bluespace = 6,
		/obj/item/storage/backpack/holding = 5,
		/obj/item/clothing/gloves/fingerless/chronal_splint = 4,
		/obj/item/clothing/suit/toggle/labcoat/eventide_courier = 4,
		/obj/item/singularityhammer = 2,
	)

/obj/structure/closet/crate/zone_loot/research
	name = "specimen transfer cache"
	desc = "A sealed specimen-transfer cache stamped with a containment-tier barcode. The manifest slot is empty."
	icon_state = "scicrate"
	base_icon_state = "scicrate"
	theme = /datum/loot_theme/research

/obj/structure/closet/crate/zone_loot/research/rare
	name = "priority specimen cache"
	desc = "A specimen-transfer cache flagged for priority extraction. Whatever's inside outranked the staff."
	rare = TRUE

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
