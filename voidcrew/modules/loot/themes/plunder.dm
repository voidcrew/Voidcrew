// =========================================================================
// PLUNDER THEME — The Scuppers Freeport config (rare_pirate_cove ruin) and
// every crash site, cove and freeport. Pirate plunder: green =
// trinkets/booze/small cash, yellow = valuables and serviceable weapons,
// red = treasure (big cash, precious mats, prize gear). Guarded by pirate
// crews.
// TODO: review/balance-pass all six tables — first-draft weights and
// contents, never playtested.
// =========================================================================

/datum/loot_theme/plunder
	name = "plunder"
	guard_themes = list(/obj/effect/zone_mobs/pirate, /obj/effect/zone_mobs/pirate/boss)
	theme_skus = list(
		/datum/shop_sku/black_market/rotating/mateba,
		/datum/shop_sku/black_market/bulldog_blueprint,
		/datum/shop_sku/outfitter/carbine_blueprint,
	)
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
	// Rare tables: surviving stock entries + this theme's uniques at ~4
	// (see voidcrew/modules/loot/uniques/plunder.dm and the design doc)
	rare_loot_green = list(
		/obj/item/coin/gold/doubloon = 8,
		/obj/item/stack/spacecash/c500 = 6,
		/obj/item/toy/cards/deck/cheats = 4,
		/obj/item/reagent_containers/cup/glass/bottle/bottomless_ration = 4,
	)
	rare_loot_yellow = list(
		/obj/item/gun/ballistic/shotgun/doublebarrel = 8,
		/obj/item/stack/spacecash/c1000 = 6,
		/obj/item/gun/magic/hook/marlinspike = 4,
		/obj/item/clothing/glasses/eyepatch/fences_eye = 4,
	)
	rare_loot_red = list(
		/obj/item/gun/ballistic/revolver/mateba = 6,
		/obj/item/stack/sheet/mineral/diamond = 5,
		/obj/item/claymore/cutlass/parley = 4,
		/obj/item/gps/deadmans_compass = 4,
		/obj/item/gun/ballistic/shotgun/musket/no_quarter = 3,
	)

/obj/structure/closet/crate/zone_loot/plunder
	name = "plunder cache"
	desc = "A dented cargo cache re-stenciled over three different shipping lines' logos. Finders keepers, apparently."
	icon_state = "wooden"
	base_icon_state = "wooden"
	theme = /datum/loot_theme/plunder

/obj/structure/closet/crate/zone_loot/plunder/rare
	name = "quartermaster's strongbox"
	desc = "A strongbox that never made it onto any quartermaster's books. Nobody splits shares on cargo nobody declared."
	rare = TRUE

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
