// =========================================================================
// SYNDICATE THEME — contraband tiered by spawn zone. Tables follow the
// black-market shop's price ladder (modules/trade/shop.dm and the SKUs in
// theme_skus below) so the gamble channel and the certainty channel stay on
// one curve.
// TODO: review/balance-pass all six tables — first-draft weights and
// contents, never playtested. Tune weights against the black-market voucher
// prices in shop_catalog_black_market.dm.
// Weapon blueprints are seeded across both channels: the outfitter sells the
// c20r/wt550/carbine schematics (yellow-tier), the black market sells the
// l6_saw/sniper/bulldog three (red-tier) — the same blueprints ride these
// cache tables at matching tiers. Craft them from the recipe anywhere, once
// you have the part and a firing pin (modules/weapons_bench/blueprint.dm).
// =========================================================================

/datum/loot_theme/syndicate
	name = "syndicate"
	guard_themes = list(/obj/effect/zone_mobs/syndicate, /obj/effect/zone_mobs/syndicate/boss)
	theme_skus = list(
		/datum/shop_sku/black_market/emag,
		/datum/shop_sku/black_market/tactical_medkit,
		/datum/shop_sku/black_market/saw_blueprint,
		/datum/shop_sku/black_market/sniper_blueprint,
		/datum/shop_sku/black_market/bulldog_blueprint,
		/datum/shop_sku/black_market/mystery_cache,
		/datum/shop_sku/black_market/mystery_cache_rare,
		/datum/shop_sku/black_market/rare/energy_sword,
		/datum/shop_sku/general/rotating/freight_crate,
		/datum/shop_sku/outfitter/smg_blueprint,
		/datum/shop_sku/outfitter/wt550_blueprint,
		/datum/shop_sku/outfitter/carbine_blueprint,
	)
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
		/obj/item/ship_parts/combat = 8,
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
		/obj/item/ship_parts/combat = 12,
	)
	// Rare tables: 2-3 surviving stock entries + this theme's uniques at ~4
	// (see voidcrew/modules/loot/uniques/syndicate.dm and the design doc)
	rare_loot_green = list(
		/obj/item/storage/medkit/tactical = 8,
		/obj/item/suppressor = 6,
		/obj/item/radio/listening_coin = 4,
		/obj/item/clothing/gloves/courier = 4,
	)
	rare_loot_yellow = list(
		/obj/item/gun/ballistic/revolver = 8,
		/obj/item/clothing/glasses/thermal/syndi = 6,
		/obj/item/static_cuff = 4,
		/obj/item/gun/ballistic/revolver/c38/housecall = 4,
	)
	rare_loot_red = list(
		/obj/item/melee/energy/sword/saber = 8,
		/obj/item/blueprint/gun/l6_saw = 5,
		/obj/item/blueprint/gun/sniper_rifle = 5,
		/obj/item/blueprint/gun/bulldog = 5,
		/obj/item/clothing/suit/hooded/cloak/second_shadow = 4,
		/obj/item/knife/understudy = 4,
	)

/obj/structure/closet/crate/zone_loot/syndicate
	name = "syndicate cache"
	desc = "A matte-black drop crate with the serial numbers burned off. Someone meant to come back for it."
	icon_state = "syndicrate"
	base_icon_state = "syndicrate"
	theme = /datum/loot_theme/syndicate

/obj/structure/closet/crate/zone_loot/syndicate/rare
	name = "reinforced syndicate cache"
	desc = "A matte-black drop crate in an extra layer of plating. Whatever's inside, somebody thought it was worth the postage."
	rare = TRUE

/// Syndicate holdouts: operatives left guarding whatever the base was for.
/obj/effect/zone_mobs/syndicate
	name = "zone mob spawner (syndicate)"
	mobs_green = list(
		/mob/living/basic/trooper/syndicate/melee = 10,
		/mob/living/basic/trooper/syndicate/melee/sword = 4,
	)
	mobs_yellow = list(
		/mob/living/basic/trooper/syndicate/melee/sword = 8,
		/mob/living/basic/trooper/syndicate/ranged = 8,
		/mob/living/basic/trooper/syndicate/ranged/smg = 4,
	)
	mobs_red = list(
		/mob/living/basic/trooper/syndicate/ranged/smg = 8,
		/mob/living/basic/trooper/syndicate/ranged/shotgun = 6,
		/mob/living/basic/trooper/syndicate/melee/sword = 5,
		/mob/living/basic/trooper/syndicate/ranged/smg/space/stormtrooper = 2,
	)

/obj/effect/zone_mobs/syndicate/boss
	name = "zone mob spawner (syndicate boss)"
	count_green = list(1, 1)
	count_yellow = list(1, 1)
	count_red = list(1, 1)
	mobs_green = list(
		/mob/living/basic/trooper/syndicate/melee/sword = 1,
	)
	mobs_yellow = list(
		/mob/living/basic/trooper/syndicate/ranged/shotgun = 1,
		/mob/living/basic/trooper/syndicate/ranged/smg = 1,
	)
	mobs_red = list(
		/mob/living/basic/trooper/syndicate/ranged/smg/space/stormtrooper = 1,
		/mob/living/basic/trooper/syndicate/ranged/shotgun/space/stormtrooper = 1,
	)
