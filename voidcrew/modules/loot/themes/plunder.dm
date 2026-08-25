// =========================================================================
// PLUNDER THEME: The Scuppers Freeport config (rare_pirate_cove ruin) and
// every crash site, cove and freeport. Pirate plunder: common =
// trinkets/booze/small cash, uncommon = valuables and serviceable weapons,
// prime = treasure (big cash, precious mats, prize gear). Guarded by pirate
// crews.
// Cyberware: boarding chrome, and it reads as taken off somebody rather than
// bought, grip pads at uncommon, and in the treasure the blade pair, the
// folding machine-pistol and the rocket pod.
// TODO: review/balance-pass all four tiers: first-draft weights and
// contents, never playtested.
// =========================================================================

/datum/loot_theme/plunder
	name = "plunder"
	guard_themes = list(/obj/effect/zone_mobs/pirate, /obj/effect/zone_mobs/pirate/boss)
	theme_skus = list(
		/datum/shop_sku/black_market/rotating/mateba,
		/datum/shop_sku/black_market/bulldog_blueprint,
		/datum/shop_sku/outfitter/carbine_blueprint,
		/datum/shop_sku/ripperdoc/gecko,
		/datum/shop_sku/ripperdoc/mantis,
		/datum/shop_sku/ripperdoc/ronin,
		/datum/shop_sku/ripperdoc/bunker_buster,
	)
	loot_common = list(
		/obj/item/stack/spacecash/c100 = 10,
		/obj/item/reagent_containers/cup/glass/bottle/rum = 10,
		/obj/item/coin/silver/doubloon = 8,
		/obj/item/reagent_containers/cup/glass/bottle/whiskey = 8,
		/obj/item/clothing/glasses/eyepatch = 6,
		/obj/item/clothing/head/costume/pirate/bandana = 6,
		/obj/item/coin/gold/doubloon = 5,
		/obj/item/gun/ballistic/revolver/c38/detective = 5,
		/obj/item/knife/combat = 4,
		/obj/item/toy/cards/deck = 4,
	)
	loot_uncommon = list(
		/obj/item/stack/spacecash/c500 = 10,
		/obj/item/gun/ballistic/shotgun/doublebarrel = 7,
		/obj/item/storage/box/lethalshot = 7,
		/obj/item/gun/ballistic/revolver = 6,
		/obj/item/gun/ballistic/automatic/tommygun = 6,
		/obj/item/gun/ballistic/automatic/mini_uzi = 5,
		/obj/item/ammo_box/speedloader/c357 = 6,
		/obj/item/stack/sheet/mineral/gold = 5,
		/obj/item/clothing/head/costume/pirate/armored = 4,
		/obj/item/clothing/suit/costume/pirate/armored = 4,
		/obj/item/reagent_containers/cup/glass/bottle/rum/aged = 4,
		/obj/item/blueprint/gun/laser_carbine = 3,
		/obj/item/ship_parts/combat = 7,
		// boarder's palms: your hands clamp shut on your gun when you go
		// down, and tables stop being furniture
		/obj/item/organ/cyberimp/cyberware/gecko = 4,
	)
	loot_prime = list(
		/obj/item/stack/spacecash/c1000 = 9,
		/obj/item/gun/ballistic/revolver/mateba = 5,
		/obj/item/gun/ballistic/shotgun/automatic/combat = 5,
		/obj/item/gun/ballistic/automatic/pistol/deagle = 5,
		// finished blueprint gun, prime only: boarding hardware nobody
		// filed a schematic for
		/obj/item/gun/ballistic/shotgun/bulldog/unrestricted = 4,
		/obj/item/melee/energy/sword/pirate = 4,
		/obj/item/stack/sheet/mineral/diamond = 4,
		/obj/item/reagent_containers/cup/glass/bottle/absinthe/premium = 4,
		/obj/item/clothing/suit/costume/pirate/captain/armored = 3,
		/obj/item/clothing/head/costume/pirate/captain = 3,
		/obj/item/blueprint/gun/bulldog = 3,
		/obj/item/stack/spacecash/c10000 = 2,
		// the captain's cut, all of it voucher-grade chrome: the cased blade
		// pair, the arm gun nobody can disarm you of, and the rocket pod.
		// Both weapon pieces are parlor-fed. The crate pays what's loaded in
		// them and no more, so reloads still mean a trip to Splice
		/obj/item/cyberware_pair_case/mantis_blades = 3,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin = 3,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/bunker_buster = 2,
	)
	// One-of-a-kind authored prizes, drawn as the fourth tier from any
	// band (weight = how shallow the item used to sit: 3 was reachable
	// early, 1 was the bottom of the deepest cache).
	loot_uniques = list(
		/obj/item/reagent_containers/cup/glass/bottle/bottomless_ration = 3,
		/obj/item/toy/cards/deck/cheats = 3,
		/obj/item/clothing/glasses/eyepatch/fences_eye = 2,
		/obj/item/gun/magic/hook/marlinspike = 2,
		/obj/item/claymore/cutlass/parley = 1,
		/obj/item/gun/ballistic/shotgun/musket/no_quarter = 1,
		/obj/item/heave_ho = 1,
	)

/obj/structure/closet/crate/zone_loot/plunder
	name = "plunder cache"
	desc = "A dented cargo cache re-stenciled over three different shipping lines' logos. Finders keepers, apparently."
	icon_state = "wooden"
	base_icon_state = "wooden"
	theme = /datum/loot_theme/plunder

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
