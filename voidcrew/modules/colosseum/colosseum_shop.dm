/**
 * # The Lanista's Rack: the Grand Colosseum's gear stall
 *
 * A trader-outpost-style vendor stall on the venue concourse, selling the
 * bespoke arena gear from colosseum_gear.dm. Reuses the whole outpost shop
 * stack (voidcrew/modules/trade/): /datum/outpost_shop for stock and
 * shelves, the outpost_trader mob + TraderShop tgui for the storefront,
 * but stands alone, with no trader outpost behind it (shop machinery in
 * trader_npc.dm is null-outpost tolerant for exactly this).
 *
 * Stock loop: the core shelf is always up; rotating picks and the rare
 * showcase reroll through convoy_restock(), which the match controller
 * fires after every settled match (colosseum_controller.dm resolve()).
 * The games end, the convoy lands, the rack refills.
 */

// =========================================================================
// THE SHOP
// =========================================================================

/datum/outpost_shop/vendor/colosseum_armory
	outpost_name = "\improper The Lanista's Rack"
	outpost_desc = "The Grand Colosseum's own gear stall."
	trader_name = "Lanista Verra"
	trader_outfit = /datum/outfit/colosseum_lanista
	trader_gender = FEMALE
	trader_voice_pack = "goon.speak_4"
	trader_voice_pitch = 0.9
	categories = list(
		"Panoply",
		"Armaments",
		"Pit Kit",
	)
	sku_types = list(
		/datum/shop_sku/colosseum/grindstone,
		/datum/shop_sku/colosseum/pit_satchel,
		/datum/shop_sku/colosseum/retiarius_net,
	)
	rotating_pool = list(
		/datum/shop_sku/colosseum/rotating/sandstriders,
		/datum/shop_sku/colosseum/rotating/parmula,
		/datum/shop_sku/colosseum/rotating/bestiarius_pike,
	)
	rotating_picks = 2
	rare_pool = list(
		/datum/shop_sku/colosseum/rare/galea,
		/datum/shop_sku/colosseum/rare/spaulder,
		/datum/shop_sku/colosseum/rare/laurel,
	)
	rare_picks_max = 2
	trader_lines = list(
		TRADER_LINE_GREETING = list(
			"Fresh off the sand or fresh off the boat, coin spends the same.",
			"Look with your eyes, pay with your chip, bleed on your own time.",
			"Welcome to the Rack. Everything here has survived the arena. Twice.",
		),
		TRADER_LINE_SALE = list(
			"Sold. Die in it and I'll buy it back at half.",
			"Good eye. That piece has outlived three owners.",
			"A pleasure. The infirmary is east, when the time comes.",
			"Wear it in good health. Statistically unlikely, but wear it anyway.",
			"That one's been waiting for the right pair of hands. Or any pair, really.",
		),
		TRADER_LINE_REFUSAL = list(
			"Not to you, not today.",
			"The Rack picks its customers. It didn't pick you.",
		),
		TRADER_LINE_IDLE = list(
			"Every piece on this rack came off a champion. Most of them came off the sand feet first.",
			"I outfitted six of the names in the Hall out there. The statues never mention the fitting fees.",
			"The grindstones sell to cooks, mostly. The cooks worry me more than the fighters.",
			"No, the trident is not for sale. The trident was never for sale. Stop asking about the trident.",
			"Buy the net. Everyone laughs at the net until they've been IN the net.",
			"House rule: no refunds once there's blood in the tread. That's most of my no-refunds, honestly.",
			"The laurel? Purely decorative. So are the statues upstairs, and people still fight for those.",
		),
		TRADER_LINE_RESTOCK = list(
			"Match settled, convoy's in. The rack is full again, for now.",
			"New stock off the supply lighter. Some of it is even unbloodied.",
			"The games provide. Fresh shelves, same prices.",
		),
	)

/// What the Lanista stands behind the counter wearing
/datum/outfit/colosseum_lanista
	name = "Colosseum lanista"
	uniform = /obj/item/clothing/under/costume/gladiator
	suit = /obj/item/clothing/suit/apron
	shoes = /obj/item/clothing/shoes/sandal

// =========================================================================
// SKUS
// =========================================================================

/datum/shop_sku/colosseum
	stock_min = 1
	stock_max = 2

// ===== CORE: PIT KIT + THE NET =====

/datum/shop_sku/colosseum/grindstone
	category = "Pit Kit"
	item_path = /obj/item/sharpener/grindstone
	price_credits = 1050
	stock_min = 2
	stock_max = 3

/datum/shop_sku/colosseum/pit_satchel
	category = "Pit Kit"
	item_path = /obj/item/storage/medkit/pit_doctor
	price_credits = 1500
	stock_min = 2
	stock_max = 3

/datum/shop_sku/colosseum/retiarius_net
	category = "Armaments"
	item_path = /obj/item/restraints/legcuffs/bola/retiarius
	price_credits = 1800

// ===== ROTATING: THE FIGHTING KIT =====

/datum/shop_sku/colosseum/rotating/sandstriders
	category = "Panoply"
	item_path = /obj/item/clothing/shoes/sandal/sandstrider
	price_credits = 2400

/datum/shop_sku/colosseum/rotating/parmula
	category = "Armaments"
	item_path = /obj/item/shield/buckler/parmula
	price_credits = 2700

/datum/shop_sku/colosseum/rotating/bestiarius_pike
	category = "Armaments"
	item_path = /obj/item/spear/bestiarius
	price_credits = 3300

// ===== RARE: THE SHOWCASE =====

/datum/shop_sku/colosseum/rare/galea
	category = "Panoply"
	item_path = /obj/item/clothing/head/helmet/gladiator/galea
	price_vouchers = 1
	price_credits = 2400

/datum/shop_sku/colosseum/rare/spaulder
	category = "Panoply"
	item_path = /obj/item/clothing/suit/armor/spaulder
	price_vouchers = 1
	price_credits = 3000

/datum/shop_sku/colosseum/rare/laurel
	category = "Panoply"
	item_path = /obj/item/clothing/head/costume/crown/laurel
	price_vouchers = 2
	price_credits = 4500

// =========================================================================
// THE LANISTA
// =========================================================================

/**
 * The stall's shopkeeper. Unlike the outpost stall vendors this mob has no
 * outpost to link it: it builds and owns its shop datum outright in
 * Initialize, so a mapped-in (or fallback-spawned) lanista is self-serving
 * the moment it loads. The colosseum site indexes it at link_interior for
 * the post-match restock hook.
 */
/mob/living/basic/outpost_trader/colosseum
	name = "lanista"
	desc = "The Grand Colosseum's gear merchant. Everything on the rack survived the arena, and it's priced like it."
	shop_type = /datum/outpost_shop/vendor/colosseum_armory

/mob/living/basic/outpost_trader/colosseum/Initialize(mapload)
	shop = new shop_type(null)
	shop.trader_npc = src
	return ..()

/mob/living/basic/outpost_trader/colosseum/Destroy()
	// This trader owns its shop (no outpost holds it)
	QDEL_NULL(shop)
	if(GLOB.colosseum_site?.armory_trader == src)
		GLOB.colosseum_site.armory_trader = null
	return ..()

/mob/living/basic/outpost_trader/colosseum/examine(mob/user)
	. = ..()
	. += span_notice("Winnings from the vault spend just fine here.")
