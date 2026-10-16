// =========================================================================
// SYNDICATE THEME: contraband tiered by what it's worth. Tables follow the
// black-market shop's price ladder (modules/trade/shop.dm and the SKUs in
// theme_skus below) so the gamble channel and the certainty channel stay on
// one curve.
// TODO: review/balance-pass all four tiers: first-draft weights and
// contents, never playtested. Tune weights against the black-market voucher
// prices in shop_catalog_black_market.dm.
// Cyberware rides the same two channels: the parlor's smuggling cavity and
// door spike sit at uncommon, and the three voucher-only pieces an operative
// would carry (cloak weave, wire, reflex shunt) sit at the bottom of prime.
// =========================================================================

/datum/loot_theme/syndicate
	name = "syndicate"
	gun_chance = LOOT_GUN_CHANCE_SYNDICATE
	gun_pool = LOOT_GUN_POOL_SYNDICATE
	gun_extras = list(
		LOOT_WEAPON_YELLOW = list(
			/obj/item/gun/ballistic/automatic/pistol/deagle = 1,
			/obj/item/gun/ballistic/revolver = 1,
			/obj/item/gun/ballistic/revolver/c38/housecall = 1,
		),
		LOOT_WEAPON_RED = list(
			/obj/item/gun/ballistic/rifle/sniper_rifle = 1,
			/obj/item/gun/ballistic/shotgun/automatic/combat = 1,
		),
	)
	melee_extras = list(
		LOOT_WEAPON_RED = list(
			/obj/item/knife/understudy = 1,
			/obj/item/organ/cyberimp/arm/toolkit/cyberware/monowire = 1,
		),
	)
	guard_themes = list(/obj/effect/zone_mobs/syndicate, /obj/effect/zone_mobs/syndicate/boss)
	theme_skus = list(
		/datum/shop_sku/black_market/emag,
		/datum/shop_sku/black_market/tactical_medkit,
		/datum/shop_sku/black_market/mystery_cache,
		/datum/shop_sku/black_market/mystery_cache_rare,
		/datum/shop_sku/black_market/rare/energy_sword,
		/datum/shop_sku/general/rotating/freight_crate,
		/datum/shop_sku/ripperdoc/cargo_cavity,
		/datum/shop_sku/ripperdoc/icepick,
		/datum/shop_sku/ripperdoc/slipwire,
		/datum/shop_sku/ripperdoc/monowire,
		/datum/shop_sku/ripperdoc/ghostskin,
	)
	loot_common = list(
		/obj/item/soap/syndie = 10,
		/obj/item/storage/fancy/cigarettes/cigpack_syndicate = 10,
		/obj/item/ammo_box/magazine/m9mm = 8,
		/obj/item/suppressor = 6,
		/obj/item/encryptionkey/syndicate = 6,
		/obj/item/grenade/empgrenade = 5,
		/obj/item/storage/medkit/tactical = 4,
	)
	loot_uncommon = list(
		/obj/item/grenade/c4 = 6,
		/obj/item/ammo_box/a357 = 5,
		/obj/item/card/id/advanced/chameleon = 4,
		/obj/item/clothing/shoes/chameleon/noslip = 4,
		/obj/item/clothing/glasses/thermal/syndi = 3,
		/obj/item/ship_parts/combat = 8,
		// courier chrome: a shielded rib compartment scanners read past, and
		// a wrist spike for door motors and turret IFF
		/obj/item/organ/cyberimp/cyberware/cargo_cavity = 4,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/icepick = 3,
	)
	loot_prime = list(
		/obj/item/pen/sleepy = 4,
		/obj/item/grenade/syndieminibomb = 3,
		/obj/item/card/emag = 2,
		// Operative chrome: the reflex shunt and refraction weave.
		/obj/item/organ/cyberimp/cyberware/slipwire = 3,
		/obj/item/organ/cyberimp/cyberware/ghostskin = 2,
	)
	// One-of-a-kind authored prizes, drawn as the fourth tier from any
	// band (weight = how shallow the item used to sit: 3 was reachable
	// early, 1 was the bottom of the deepest cache).
	loot_uniques = list(
		/obj/item/clothing/gloves/courier = 3,
		/obj/item/radio/listening_coin = 3,
		/obj/item/static_cuff = 2,
		/obj/item/clothing/suit/hooded/cloak/second_shadow = 1,
	)

/obj/structure/closet/crate/zone_loot/syndicate
	name = "syndicate cache"
	desc = "A matte-black drop crate with the serial numbers burned off. Someone meant to come back for it."
	icon_state = "syndicrate"
	base_icon_state = "syndicrate"
	theme = /datum/loot_theme/syndicate

/// The black market's premium cache SKU (shop_catalog_black_market.dm). Same
/// tables as any other syndicate cache. It is simply packed fuller, which is
/// what the extra vouchers buy.
/obj/structure/closet/crate/zone_loot/syndicate/reinforced
	name = "reinforced syndicate cache"
	desc = "A matte-black drop crate in an extra layer of plating. Whatever's inside, somebody thought it was worth the postage."
	bonus_draws = 2

/// Syndicate holdouts: operatives left guarding whatever the base was for.
/obj/effect/zone_mobs/syndicate
	name = "zone mob spawner (syndicate)"
	mobs_green = list(
		/mob/living/basic/trooper/syndicate/melee = 14,
	)
	mobs_yellow = list(
		/mob/living/basic/trooper/syndicate/melee/sword = 8,
		/mob/living/basic/trooper/syndicate/ranged = 12,
	)
	mobs_red = list(
		/mob/living/basic/trooper/syndicate/ranged/smg = 8,
		/mob/living/basic/trooper/syndicate/ranged/shotgun = 6,
		/mob/living/basic/trooper/syndicate/melee/sword = 5,
		/mob/living/basic/trooper/syndicate/ranged/smg/space/stormtrooper = 2,
	)

/obj/effect/zone_mobs/syndicate/boss
	name = "zone mob spawner (syndicate boss)"
	mobs_green = list(
		/mob/living/basic/trooper/syndicate/melee = 1,
	)
	mobs_yellow = list(
		/mob/living/basic/trooper/syndicate/ranged = 2,
	)
	mobs_red = list(
		/mob/living/basic/trooper/syndicate/ranged/smg/space/stormtrooper = 1,
		/mob/living/basic/trooper/syndicate/ranged/shotgun/space/stormtrooper = 1,
	)
