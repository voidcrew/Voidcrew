// =========================================================================
// ARMORY THEME — military/security hardware for ruins with a garrison story
// (weapons labs, chokepoints, fortresses, crashed patrol ships, the
// Bastion-6 rare ruin). Green is mall-cop kit, yellow is line infantry, red
// is the riot line's back room. Guarded by whatever outlived the garrison:
// asset-denial automation (robot markers) or the holdouts themselves
// (syndicate markers).
// TODO: review/balance-pass all six tables — first-draft weights and
// contents, never playtested. Tune against the outfitter armor/gun prices
// in theme_skus.
// =========================================================================

/datum/loot_theme/armory
	name = "armory"
	guard_themes = list(
		/obj/effect/zone_mobs/robot,
		/obj/effect/zone_mobs/robot/boss,
		/obj/effect/zone_mobs/syndicate,
		/obj/effect/zone_mobs/syndicate/boss,
	)
	theme_skus = list(
		/datum/shop_sku/outfitter/riot_helmet,
		/datum/shop_sku/outfitter/riot_shield,
		/datum/shop_sku/outfitter/rotating/riot_suit,
	)
	loot_green = list(
		/obj/item/clothing/suit/armor/vest = 10,
		/obj/item/clothing/head/helmet/sec = 10,
		/obj/item/gun/energy/disabler = 7,
		/obj/item/gun/ballistic/rifle/boltaction/surplus = 7,
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
		/obj/item/gun/ballistic/automatic/ar = 6,
		/obj/item/gun/ballistic/automatic/pistol/deagle = 5,
		/obj/item/shield/riot = 6,
		/obj/item/clothing/suit/armor/vest/marine = 5,
		/obj/item/clothing/gloves/combat = 5,
		/obj/item/clothing/shoes/combat = 5,
		/obj/item/gun/ballistic/rifle/boltaction = 4,
		/obj/item/clothing/under/syndicate/tacticool = 3,
		/obj/item/ship_parts/combat = 7,
	)
	loot_red = list(
		/obj/item/clothing/suit/armor/riot = 9,
		/obj/item/clothing/head/helmet/toggleable/riot = 8,
		/obj/item/gun/energy/laser = 8,
		/obj/item/gun/ballistic/shotgun/automatic/combat = 6,
		/obj/item/gun/energy/laser/scatter = 6,
		// finished blueprint guns, red only: the garrison's own issued
		// hardware, not the schematics the shops sell
		/obj/item/gun/ballistic/automatic/wt550 = 4,
		/obj/item/gun/energy/laser/carbine = 4,
		/obj/item/clothing/suit/armor/laserproof = 6,
		/obj/item/clothing/head/helmet/marine = 6,
		/obj/item/storage/belt/military/assault = 5,
		/obj/item/gun/energy/e_gun = 4,
		/obj/item/gun/ballistic/rifle/boltaction/prime = 3,
		/obj/item/shield/riot/tele = 3,
		/obj/item/clothing/suit/armor/heavy = 2,
		/obj/item/ship_parts/combat = 9,
	)
	// Rare tables: surviving stock entries + this theme's uniques at ~4
	// (see voidcrew/modules/loot/uniques/armory.dm and the design doc)
	rare_loot_green = list(
		/obj/item/clothing/suit/armor/bulletproof = 8,
		/obj/item/gun/ballistic/automatic/pistol/m1911 = 6,
		/obj/item/gun/ballistic/rifle/boltaction/surplus = 6,
		/obj/item/handloaders_vise = 4,
		/obj/item/clothing/mask/whistle/sergeants = 4,
	)
	rare_loot_yellow = list(
		/obj/item/clothing/suit/armor/riot = 8,
		/obj/item/gun/energy/laser = 6,
		/obj/item/gun/ballistic/automatic/ar = 6,
		/obj/item/shield/riot/phalanx_buckler = 4,
		/obj/item/clothing/glasses/sunglasses/marksmans_cant = 4,
	)
	rare_loot_red = list(
		/obj/item/gun/energy/e_gun = 8,
		/obj/item/clothing/suit/armor/heavy = 6,
		// the deepest, boss-guarded slice of the theme: the anti-materiel
		// rifle and the heavy laser, both otherwise long research projects
		/obj/item/gun/ballistic/rifle/sniper_rifle = 3,
		/obj/item/gun/energy/lasercannon = 3,
		/obj/item/garrison_standard = 4,
		/obj/item/clothing/gloves/knock_knock = 4,
	)

/obj/structure/closet/crate/zone_loot/armory
	name = "armory resupply cache"
	desc = "A stenciled munitions cache, requisition slip long gone. The lock was cut by someone in a hurry."
	icon_state = "weaponcrate"
	base_icon_state = "weaponcrate"
	theme = /datum/loot_theme/armory

/obj/structure/closet/crate/zone_loot/armory/rare
	name = "sealed ordnance cache"
	desc = "A munitions cache still under factory seal. Someone paid extra for what's in here."
	rare = TRUE
