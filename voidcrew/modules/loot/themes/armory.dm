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
	gun_chance = LOOT_GUN_CHANCE_ARMORY
	gun_pool = LOOT_GUN_POOL_ARMORY
	gun_extras = list(
		LOOT_WEAPON_GREEN = list(
			/obj/item/gun/ballistic/automatic/pistol/m1911 = 1,
			/obj/item/gun/ballistic/automatic/pistol/m1911/no_mag = 1,
			/obj/item/gun/ballistic/automatic/pistol/no_mag = 1,
			/obj/item/gun/ballistic/automatic/pistol/toy = 1,
			/obj/item/gun/ballistic/automatic/toy = 1,
			/obj/item/gun/ballistic/bow = 1,
			/obj/item/gun/ballistic/revolver/c38 = 1,
			/obj/item/gun/ballistic/revolver/nagant = 1,
			/obj/item/gun/ballistic/revolver/russian = 1,
			/obj/item/gun/ballistic/revolver/russian/soul = 1,
			/obj/item/gun/ballistic/rifle/boltaction/pipegun = 1,
			/obj/item/gun/ballistic/rifle/boltaction/pipegun/pistol = 1,
			/obj/item/gun/ballistic/shotgun/doublebarrel/breacherslug = 1,
			/obj/item/gun/ballistic/shotgun/doublebarrel/slugs = 1,
			/obj/item/gun/ballistic/shotgun/musket = 1,
			/obj/item/gun/ballistic/shotgun/toy = 1,
			/obj/item/gun/ballistic/shotgun/toy/crossbow = 1,
		),
		LOOT_WEAPON_YELLOW = list(
			/obj/item/gun/ballistic/automatic/ar = 1,
			/obj/item/gun/ballistic/automatic/pistol/aps = 1,
			/obj/item/gun/ballistic/automatic/pistol/deagle = 1,
			/obj/item/gun/ballistic/automatic/pistol/deagle/camo = 1,
			/obj/item/gun/ballistic/automatic/pistol/deagle/gold = 1,
			/obj/item/gun/ballistic/automatic/smartgun = 1,
			/obj/item/gun/ballistic/revolver/golden = 1,
			/obj/item/gun/ballistic/rifle/boltaction = 1,
			/obj/item/gun/ballistic/rifle/boltaction/donkrifle = 1,
			/obj/item/gun/ballistic/rifle/boltaction/pipegun/prime = 1,
			/obj/item/gun/ballistic/rifle/boltaction/prime = 1,
			/obj/item/gun/ballistic/rifle/rebarxbow/forced = 1,
			/obj/item/gun/ballistic/shotgun = 1,
			/obj/item/gun/ballistic/shotgun/lethal = 1,
			/obj/item/gun/ballistic/shotgun/riot = 1,
			/obj/item/gun/energy/e_gun/dragnet = 1,
			/obj/item/gun/energy/e_gun/old = 1,
			/obj/item/gun/energy/laser/luxurypaywall = 1,
			/obj/item/gun/energy/laser/retro/old = 1,
			/obj/item/gun/syringe/rapidsyringe = 1,
			/obj/item/gun/syringe/syndicate = 1,
		),
		LOOT_WEAPON_RED = list(
			/obj/item/gun/ballistic/automatic/m90/unrestricted = 1,
			/obj/item/gun/energy/e_gun/hos = 1,
			/obj/item/gun/energy/e_gun/nuclear = 1,
			/obj/item/gun/energy/laser/carbine/cybersun/unrestricted = 1,
		),
	)
	melee_extras = list(
		LOOT_WEAPON_GREEN = list(
			/obj/item/bambostaff = 1,
			/obj/item/knife/combat/bone = 1,
			/obj/item/knife/envy = 1,
			/obj/item/lead_pipe = 1,
			/obj/item/spear/bamboospear = 1,
			/obj/item/spear/bonespear = 1,
			/obj/item/spear/military = 1,
			/obj/item/storage/case/cyberware/scrapper = 1,
			/obj/item/tailclub = 1,
		),
		LOOT_WEAPON_YELLOW = list(
			/obj/item/chainsaw = 1,
			/obj/item/claymore/cutlass/old = 1,
			/obj/item/claymore/weak = 1,
			/obj/item/crowbar/large/twenty_force = 1,
			/obj/item/fireaxe/boardingaxe = 1,
			/obj/item/fireaxe/boneaxe = 1,
			/obj/item/melee/parsnip_sabre = 1,
			/obj/item/nullrod/claymore = 1,
			/obj/item/nullrod/claymore/chainsaw_sword = 1,
			/obj/item/nullrod/claymore/darkblade = 1,
			/obj/item/nullrod/claymore/glowing = 1,
			/obj/item/nullrod/claymore/katana = 1,
			/obj/item/nullrod/claymore/multiverse = 1,
			/obj/item/nullrod/claymore/saber = 1,
			/obj/item/nullrod/claymore/saber/pirate = 1,
			/obj/item/nullrod/claymore/saber/red = 1,
			/obj/item/nullrod/hypertool = 1,
			/obj/item/nullrod/vibro = 1,
			/obj/item/nullrod/vibro/spellblade = 1,
			/obj/item/nullrod/vibro/talking = 1,
			/obj/item/pen/edagger = 1,
			/obj/item/shield/buckler = 1,
			/obj/item/shield/buckler/parmula = 1,
			/obj/item/shield/kite = 1,
			/obj/item/shield/riot = 1,
			/obj/item/shield/riot/phalanx_buckler = 1,
			/obj/item/shield/riot/tele = 1,
			/obj/item/shield/roman = 1,
			/obj/item/shovel/serrated = 1,
			/obj/item/spear/grey_tide = 1,
			/obj/item/switchblade = 1,
		),
		LOOT_WEAPON_RED = list(
			/obj/item/clothing/gloves/knock_knock = 1,
			/obj/item/cursed_katana = 1,
			/obj/item/energy_katana = 1,
			/obj/item/house_edge = 1,
			/obj/item/melee/energy/sword/saber/blue = 1,
			/obj/item/melee/energy/sword/saber/purple = 1,
			/obj/item/melee/energy/sword/saber/red = 1,
			/obj/item/melee/greykingsword = 1,
			/obj/item/shield/energy = 1,
			/obj/item/storage/toolbox/mechanical/old/clean = 1,
			/obj/item/veilrender = 1,
			/obj/item/veilrender/vealrender = 1,
		),
	)
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
		/obj/item/flashlight/seclite = 7,
		/obj/item/grenade/flashbang = 6,
		/obj/item/clothing/glasses/hud/security/sunglasses = 5,
		/obj/item/melee/baton/security/loaded = 4,
		/obj/item/clothing/mask/balaclava = 4,
	)
	loot_uncommon = list(
		/obj/item/clothing/suit/armor/bulletproof = 10,
		/obj/item/ammo_box/magazine/m45 = 8,
		/obj/item/clothing/suit/armor/vest/marine = 5,
		/obj/item/clothing/gloves/combat = 5,
		/obj/item/clothing/shoes/combat = 5,
		/obj/item/clothing/under/syndicate/tacticool = 3,
		/obj/item/ship_parts/combat = 7,
		// Issue chrome: subdermal impact weave.
		/obj/item/organ/cyberimp/cyberware/dermal_mesh = 4,
	)
	loot_prime = list(
		/obj/item/clothing/suit/armor/riot = 9,
		/obj/item/clothing/head/helmet/toggleable/riot = 8,
		/obj/item/clothing/suit/armor/laserproof = 6,
		/obj/item/clothing/head/helmet/marine = 6,
		/obj/item/storage/belt/military/assault = 5,
		/obj/item/clothing/suit/armor/heavy = 2,
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
		/obj/item/garrison_standard = 1,
	)

/obj/structure/closet/crate/zone_loot/armory
	name = "armory resupply cache"
	desc = "A stenciled munitions cache, requisition slip long gone. The lock was cut by someone in a hurry."
	icon_state = "weaponcrate"
	base_icon_state = "weaponcrate"
	theme = /datum/loot_theme/armory

