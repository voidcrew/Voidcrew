// =========================================================================
// ARMORY THEME: military/security hardware for ruins with a garrison story
// (weapons labs, chokepoints, fortresses, crashed patrol ships, the
// Bastion-6 chart ruin). Common is mall-cop kit, uncommon is line infantry,
// prime is the riot line's back room. Guarded by whatever outlived the garrison:
// asset-denial automation (robot markers) or the holdouts themselves
// (syndicate markers).
// Cyberware: chrome a garrison would have issued rather than bought, light
// weave and knuckle plate on the line, and in the back room the ceramic
// plating, the targeting optics and the frame that stops a limb coming off.
// TODO: review/balance-pass all four tiers: first-draft weights and
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
		/datum/shop_sku/ripperdoc/dermal_mesh,
		/datum/shop_sku/ripperdoc/scrapper,
		/datum/shop_sku/ripperdoc/slabskin,
		/datum/shop_sku/ripperdoc/deadeye,
		/datum/shop_sku/ripperdoc/atlas,
	)
	loot_common = list(
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
	loot_uncommon = list(
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
		// issue chrome: subdermal impact weave, and the knuckle set cased as
		// a matched pair (both halves, one per arm)
		/obj/item/organ/cyberimp/cyberware/dermal_mesh = 4,
		/obj/item/storage/case/cyberware/scrapper = 3,
	)
	loot_prime = list(
		/obj/item/clothing/suit/armor/riot = 9,
		/obj/item/clothing/head/helmet/toggleable/riot = 8,
		/obj/item/gun/energy/laser = 8,
		/obj/item/gun/ballistic/shotgun/automatic/combat = 6,
		/obj/item/gun/energy/laser/scatter = 6,
		// finished blueprint guns, prime only: the garrison's own issued
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
		// the deepest slice of the theme, previously reachable only through
		// a sealed cache: now the long tail of prime, open to any band
		/obj/item/gun/ballistic/rifle/sniper_rifle = 3,
		/obj/item/gun/energy/lasercannon = 3,
		// the back room's chrome, all voucher-grade at the parlor: ceramic
		// plate, the targeting link, and the truss that keeps limbs attached
		/obj/item/organ/cyberimp/cyberware/slabskin = 3,
		/obj/item/organ/eyes/robotic/cyberware/deadeye = 3,
		/obj/item/organ/cyberimp/cyberware/atlas = 2,
	)
	// One-of-a-kind authored prizes, drawn as the fourth tier from any
	// band (weight = how shallow the item used to sit: 3 was reachable
	// early, 1 was the bottom of the deepest cache).
	loot_uniques = list(
		/obj/item/clothing/mask/whistle/sergeants = 3,
		/obj/item/handloaders_vise = 3,
		/obj/item/clothing/glasses/sunglasses/marksmans_cant = 2,
		/obj/item/shield/riot/phalanx_buckler = 2,
		/obj/item/clothing/gloves/knock_knock = 1,
		/obj/item/garrison_standard = 1,
	)

/obj/structure/closet/crate/zone_loot/armory
	name = "armory resupply cache"
	desc = "A stenciled munitions cache, requisition slip long gone. The lock was cut by someone in a hurry."
	icon_state = "weaponcrate"
	base_icon_state = "weaponcrate"
	theme = /datum/loot_theme/armory

