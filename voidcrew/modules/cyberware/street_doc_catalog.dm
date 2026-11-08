/**
 * # The Back Bay: Ratchet, street ripperdoc
 *
 * Quartermain's chrome counter: a vendor stall in a storage bay off the depot's
 * upper landing, with its own Chrome Cradle. Ratchet is a loader mechanic who
 * started putting chrome in people, and the shelf shows it: street chrome only,
 * nothing that needs a voucher.
 *
 * He lists the SAME /datum/shop_sku/ripperdoc types Splice does, not copies.
 * Each shop builds its own SKU instances, so his stock is his own, but the
 * price of a piece can never drift between the two counters. That matters
 * because the cradle quotes one price per organ type
 * (build_cyberware_price_index() in cradle_ui.dm), and because
 * voidcrew_zone_shops/catalog pins the reputation gate of every SKU type that
 * exists, so a parallel set of street-doc SKU types would need its own
 * entries there for no gain.
 *
 * His intake ledger takes the same street rungs as Splice's at the same pay
 * (subtypes of Splice's buybacks, with his own wording). Like every ledger it
 * refuses trader goods (is_trader_good()), so it only ever buys chrome that
 * was looted, never chrome bought at a counter and pulled again.
 *
 * Catalog and NPC only: the organs live in ware_*.dm, the cradle in
 * chrome_cradle.dm, the room on the Quartermain map
 * (trader_outpost_outfitter.dmm). The NPC is a subtype of Splice's so the
 * cradle's install patter (play_ripperdoc_bark()) comes out of his mouth.
 */

/**
 * Ratchet's look: a black robotics jumpsuit under a leather wader bib, the
 * kind you hose down. Insulated gloves because half the job is wiring, welding
 * goggles pushed up because the other half is welding, a hand-rolled cigarette,
 * and a hand drill he uses on loaders and patients alike. Kept clear of Splice
 * (no scrubs, no leather jacket) and of Sawbones (no head mirror).
 * Purely cosmetic, the NPC snapshot only copies appearance.
 */
/datum/outfit/street_doc_ratchet
	name = "Street ripperdoc"
	uniform = /obj/item/clothing/under/rank/rnd/roboticist
	suit = /obj/item/clothing/suit/apron/waders
	gloves = /obj/item/clothing/gloves/color/yellow
	shoes = /obj/item/clothing/shoes/workboots
	glasses = /obj/item/clothing/glasses/welding/up
	mask = /obj/item/cigarette/rollie
	r_hand = /obj/item/screwdriver/power

/datum/outpost_shop/vendor/street_doc
	outpost_name = "\improper The Back Bay"
	outpost_desc = "The depot's ripperdoc, in a storage bay he rents by the week."
	trader_name = "Ratchet"
	trader_outfit = /datum/outfit/street_doc_ratchet
	trader_gender = MALE
	trader_voice_pack = "goon.speak_3"
	trader_voice_pitch = 0.88
	// A SKU whose category is missing here never renders on the storefront
	// (voidcrew_shop_catalog checks it). Add the line models' category if it
	// is not "Street Chrome".
	categories = list(
		"Street Chrome",
	)
	sku_types = list(
		// ---- Street Chrome (credits), Splice's own SKU types ----
		/datum/shop_sku/ripperdoc/chromatic_dermis,
		/datum/shop_sku/ripperdoc/gastro,
		/datum/shop_sku/ripperdoc/shock_coils,
		/datum/shop_sku/ripperdoc/nightshade,
		/datum/shop_sku/ripperdoc/scrapper,
		/datum/shop_sku/ripperdoc/gecko,
		/datum/shop_sku/ripperdoc/second_wind,
		/datum/shop_sku/ripperdoc/cargo_cavity,
		/datum/shop_sku/ripperdoc/rockjaw,
		/datum/shop_sku/ripperdoc/fixers,
		/datum/shop_sku/ripperdoc/dermal_mesh,
		// ---- Street models from the cyberware lines (credit-priced T2) ----
		// CYBERWARE LINES: T2 SKUS START
		// CYBERWARE LINES: T2 SKUS END
	)
	buyback_types = list(
		/datum/shop_buyback/ripperdoc/nightshade/street_doc,
		/datum/shop_buyback/ripperdoc/shock_coils/street_doc,
		/datum/shop_buyback/ripperdoc/second_wind/street_doc,
		/datum/shop_buyback/ripperdoc/dermal_mesh/street_doc,
		/datum/shop_buyback/ripperdoc/scrapper/street_doc,
		// CYBERWARE LINES: T2 BUYBACKS START
		// CYBERWARE LINES: T2 BUYBACKS END
	)
	trader_lines = list(
		TRADER_LINE_GREETING = list(
			"Shut the door, you're letting the good air out.",
			"Chair's free. The chrome isn't.",
			"Don't mind the bucket.",
			"You want it fancy, the Undertow's that way. You want it today, sit down.",
		),
		TRADER_LINE_SALE = list(
			"Done. Lie down whenever you're ready.",
			"Good pick. I've put in a hundred of those. Most of them still work.",
			"Wipe the slab before you lie on it.",
			"Pleasure doing business.",
			"There you go. Don't tell Sarge what you paid.",
		),
		TRADER_LINE_REFUSAL = list(
			"Your ship's on the list. Can't help you.",
			"Not today. Sarge would have my bay.",
			"No. Go square it with the depot first.",
		),
		TRADER_LINE_WARNING = list(
			"Easy. The turrets in here don't miss.",
			"Do that again and the whole depot stops serving you.",
			"I patch people up. I'd rather not start with you.",
		),
		TRADER_LINE_AGGRESSION = list(
			"Out of my bay!",
			"Sarge! Got one for you!",
			"Wrong guy to swing at.",
		),
		TRADER_LINE_IDLE = list(
			"That cradle came off a wreck. Don't ask whose.",
			"Splice has the nicer chair. I've got the shorter flight.",
			"I used to fix loaders. An arm's just a small loader.",
			"The drain in the floor? Don't worry about the drain.",
			"Most of my customers come back. Some of them on purpose.",
			"The dockhands keep asking for discounts. I keep saying no.",
		),
		TRADER_LINE_RESTOCK = list(
			"Convoy's in. New chrome, some of it barely used.",
			"Fresh crate. Still smells like the last owner.",
			"Restocked. Get in before the dockhands do.",
		),
	)

// =========================================================================
// RATCHET'S INTAKE LEDGER
// Splice's ledger entries with Ratchet's wording. Same goods, same pay.
// =========================================================================

/datum/shop_buyback/ripperdoc/nightshade/street_doc
	desc = "Used low-light eyes."

/datum/shop_buyback/ripperdoc/shock_coils/street_doc
	desc = "Used calf pistons."

/datum/shop_buyback/ripperdoc/second_wind/street_doc
	desc = "A used air bladder."

/datum/shop_buyback/ripperdoc/dermal_mesh/street_doc
	desc = "Used subdermal plating."

/datum/shop_buyback/ripperdoc/scrapper/street_doc
	desc = "One used knuckle plate, either hand."

// =========================================================================
// THE NPC
// =========================================================================

/// Ratchet behind his counter. A ripperdoc subtype, so the cradle in his bay
/// talks through him during installs.
/mob/living/basic/outpost_trader/ripperdoc/street_doc
	shop_type = /datum/outpost_shop/vendor/street_doc
