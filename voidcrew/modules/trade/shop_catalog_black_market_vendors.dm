/**
 * # Undertow Exchange: vendor stalls
 *
 * The Undertow's side businesses: Dram behind the bar at the Dregs, and
 * Sawbones running the Patch-Up Clinic. Each is a full /datum/outpost_shop
 * (own stock, own buyback ledger, own voice) fronted by its own trader NPC.
 * The mobs carry a shop_type and the outpost links them to their vendor shop
 * on interior load (see outpost.dm get_shop(), trader_npc.dm for the mobs).
 *
 * Balance notes:
 * - Both stalls are credit-first; the few voucher SKUs sit on the rotating/
 *   rare shelves, same tier logic as Vex's counter.
 * - The Dregs only BUYS bottle types the cantina's own Booze-O-Mat never
 *   dispenses (moonshine, hooch, ...), so there's no vend-and-resell loop.
 * - Sawbones only buys what a ship can't lathe-print: organs, monster glands,
 *   and (like Vex's gun fencing) any defibrillator with a past.
 */

// =========================================================================
// THE DREGS: Dram, barkeep
// =========================================================================

/// Abstract grouping parent for the Undertow's side businesses
/datum/outpost_shop/vendor

/**
 * Dram: shirt, slacks, work apron, and a glass he is always in the middle of
 * drying. Deliberately the plainest fit on the station. The Undertow is full
 * of people signalling what they are, and the barkeep signals nothing at all.
 */
/datum/outfit/dregs_dram
	name = "Dregs barkeep"
	uniform = /obj/item/clothing/under/costume/buttondown/slacks/service
	suit = /obj/item/clothing/suit/apron
	head = /obj/item/clothing/head/soft/black
	shoes = /obj/item/clothing/shoes/laceup
	r_hand = /obj/item/reagent_containers/cup/glass/drinkingglass

/// Dram, the Dregs' barkeep: an apron, a rag, and no follow-up questions
/datum/outpost_shop/vendor/dregs_bar
	outpost_name = "\improper The Dregs"
	outpost_desc = "The Undertow's cantina."
	trader_name = "Dram"
	trader_outfit = /datum/outfit/dregs_dram
	trader_gender = MALE
	trader_voice_pack = "goon.speak_3"
	trader_voice_pitch = 0.82
	categories = list(
		"Top Shelf",
		"House Cellar",
		"Greasy Spoon",
		"Oddities",
	)
	sku_types = list(
		// Top Shelf: the bottles the Booze-O-Mat is too proud (or too legal) to stock
		/datum/shop_sku/dregs/champagne,
		/datum/shop_sku/dregs/absinthe_premium,
		/datum/shop_sku/dregs/patron,
		/datum/shop_sku/dregs/goldschlager,
		/datum/shop_sku/dregs/trappist,
		// House Cellar
		/datum/shop_sku/dregs/bitters,
		/datum/shop_sku/dregs/fernet,
		/datum/shop_sku/dregs/party_keg,
		// Greasy Spoon: whatever's under the heat lamp
		/datum/shop_sku/dregs/fry_basket,
		/datum/shop_sku/dregs/pizza_slice,
		/datum/shop_sku/dregs/monkey_kebab,
		/datum/shop_sku/dregs/meat_pie,
		/datum/shop_sku/dregs/donk_box,
	)
	rotating_pool = list(
		/datum/shop_sku/dregs/rotating/kong,
		/datum/shop_sku/dregs/rotating/candycorn_liquor,
		/datum/shop_sku/dregs/rotating/blazaam,
		/datum/shop_sku/dregs/rotating/mushi_kombucha,
		/datum/shop_sku/dregs/rotating/sake,
	)
	rare_pool = list(
		/datum/shop_sku/dregs/rare/lizardwine,
		/datum/shop_sku/dregs/rare/bottle_of_nothing,
	)
	buyback_types = list(
		/datum/shop_buyback/dregs/moonshine,
		/datum/shop_buyback/dregs/hooch,
		/datum/shop_buyback/dregs/kong,
		/datum/shop_buyback/dregs/ritual_wine,
	)
	trader_lines = list(
		TRADER_LINE_SALE = list(
			"On your tab. The tab is due immediately. That was the tab.",
			"Good pour. Don't drink it near the turrets, they get jealous.",
			"Enjoy. If it comes back up, that's between you and the deck plating.",
			"House rule: you break the bottle, you already bought the bottle.",
			"Cheers. To repeat business and functioning livers.",
		),
		TRADER_LINE_REFUSAL = list(
			"You're cut off. Not by me, by the station. Impressive, really.",
			"Embargoed crews drink at the OTHER bar. There is no other bar.",
			"Tab's frozen until your ship's ledger thaws. House rules.",
		),
		TRADER_LINE_IDLE = list(
			"We have beer, and we have questions I won't ask.",
			"Kitchen's whatever's under the heat lamp. The heat lamp is load-bearing.",
			"The regulars are pirates, the pirates are regular. It evens out.",
			"Vex doesn't drink. Says it's bad for the margins. Tragic, really.",
			"Someone paid their tab in raw telecrystal once. Kept the lights on for a month.",
			"You want intel, buy a rumor off Vex. You want the TRUTH? Beer first.",
			"Bring me real moonshine and I'll pay real credits. The synthetic stuff insults us both.",
			"Best drink this side of the sun is two zones that way. Don't go. Not worth it.",
		),
		TRADER_LINE_RESTOCK = list(
			"Cellar's restocked. Ask me where it came from and it's double.",
			"Convoy dropped a crate marked 'machine parts'. It sloshed. Top shelf's full.",
			"Fresh bottles in. Some of the labels are even accurate.",
		),
	)

/datum/shop_sku/dregs
	stock_min = 1
	stock_max = 3

// ===== TOP SHELF =====

/datum/shop_sku/dregs/champagne
	category = "Top Shelf"
	item_path = /obj/item/reagent_containers/cup/glass/bottle/champagne
	price_credits = 500
	stock_min = 1
	stock_max = 2

/datum/shop_sku/dregs/absinthe_premium
	category = "Top Shelf"
	item_path = /obj/item/reagent_containers/cup/glass/bottle/absinthe/premium
	price_credits = 400
	stock_min = 1
	stock_max = 2

/datum/shop_sku/dregs/patron
	category = "Top Shelf"
	item_path = /obj/item/reagent_containers/cup/glass/bottle/patron
	price_credits = 350
	stock_min = 1
	stock_max = 2

/datum/shop_sku/dregs/goldschlager
	category = "Top Shelf"
	item_path = /obj/item/reagent_containers/cup/glass/bottle/goldschlager
	price_credits = 350
	stock_min = 1
	stock_max = 2

/datum/shop_sku/dregs/trappist
	category = "Top Shelf"
	item_path = /obj/item/reagent_containers/cup/glass/bottle/trappist
	price_credits = 250
	stock_min = 1
	stock_max = 3

// ===== HOUSE CELLAR =====

/datum/shop_sku/dregs/bitters
	category = "House Cellar"
	item_path = /obj/item/reagent_containers/cup/glass/bottle/bitters
	price_credits = 200
	stock_min = 2
	stock_max = 3

/datum/shop_sku/dregs/fernet
	category = "House Cellar"
	item_path = /obj/item/reagent_containers/cup/glass/bottle/fernet
	price_credits = 200
	stock_min = 1
	stock_max = 3

/datum/shop_sku/dregs/party_keg
	category = "House Cellar"
	name = "party keg"
	desc = "A full keg of the house beer, sold by the barrel. Dram does not do deposits, returns, or condolences."
	item_path = /obj/structure/reagent_dispensers/keg/beer
	price_credits = 400
	stock_min = 1
	stock_max = 2

// ===== GREASY SPOON =====
// Bar food. It exists so nobody has to drink on an empty stomach, and it is
// exactly as good as it needs to be for that job and no better.

/datum/shop_sku/dregs/fry_basket
	category = "Greasy Spoon"
	name = "basket of fries"
	desc = "Fried in oil that remembers better days. Still hot, which around here counts as a guarantee."
	item_path = /obj/item/food/fries
	price_credits = 50
	stock_min = 3
	stock_max = 6

/datum/shop_sku/dregs/pizza_slice
	category = "Greasy Spoon"
	name = "reheated pizza slice"
	desc = "A slice off a pie whose origin Dram describes as 'a pizza'. Reheated at least once, possibly per customer."
	item_path = /obj/item/food/pizzaslice/meat
	price_credits = 60
	stock_min = 3
	stock_max = 6

/datum/shop_sku/dregs/monkey_kebab
	category = "Greasy Spoon"
	name = "mystery meat kebab"
	desc = "The mystery is monkey. Everyone knows the mystery is monkey. Asking just makes the queue slower."
	item_path = /obj/item/food/kebab/monkey
	price_credits = 80
	stock_min = 2
	stock_max = 4

/datum/shop_sku/dregs/meat_pie
	category = "Greasy Spoon"
	desc = "House meat pie. The meat is a category, not an animal."
	item_path = /obj/item/food/pie/meatpie
	price_credits = 120
	stock_min = 1
	stock_max = 3

/datum/shop_sku/dregs/donk_box
	category = "Greasy Spoon"
	name = "box of donk-pockets"
	desc = "Six factory donk-pockets, the official cuisine of people being shot at. Microwave not included."
	item_path = /obj/item/storage/box/donkpockets
	price_credits = 220
	stock_min = 1
	stock_max = 3

// ===== ODDITIES (rotating shelf) =====

/datum/shop_sku/dregs/rotating/kong
	category = "Oddities"
	item_path = /obj/item/reagent_containers/cup/glass/bottle/kong
	price_credits = 200

/datum/shop_sku/dregs/rotating/candycorn_liquor
	category = "Oddities"
	item_path = /obj/item/reagent_containers/cup/glass/bottle/candycornliquor
	price_credits = 200

/datum/shop_sku/dregs/rotating/blazaam
	category = "Oddities"
	item_path = /obj/item/reagent_containers/cup/glass/bottle/blazaam
	price_credits = 350

/datum/shop_sku/dregs/rotating/mushi_kombucha
	category = "Oddities"
	item_path = /obj/item/reagent_containers/cup/glass/bottle/mushi_kombucha
	price_credits = 100

/datum/shop_sku/dregs/rotating/sake
	category = "Oddities"
	item_path = /obj/item/reagent_containers/cup/glass/bottle/sake
	price_credits = 150

// ===== RARE SHOWCASE =====

/datum/shop_sku/dregs/rare/lizardwine
	category = "Top Shelf"
	item_path = /obj/item/reagent_containers/cup/glass/bottle/lizardwine
	price_credits = 750

/datum/shop_sku/dregs/rare/bottle_of_nothing
	category = "Oddities"
	desc = "An empty bottle with a proud label. Dram insists it's the rarest thing in the house and refuses to elaborate."
	item_path = /obj/item/reagent_containers/cup/glass/bottle/bottleofnothing
	price_credits = 500

// ===== DRAM'S CELLAR LEDGER (buybacks) =====
// Credits only, and strictly bottle types the cantina's own Booze-O-Mat never
// dispenses, no buying back the house stock.

/datum/shop_buyback/dregs/moonshine
	name = "genuine moonshine"
	desc = "The real article, still-made. Dram's regulars can tell the difference, and they will say so loudly."
	category = "The Cellar"
	item_path = /obj/item/reagent_containers/cup/glass/bottle/moonshine
	pay_credits = 150
	demand_min = 2
	demand_max = 4

/datum/shop_buyback/dregs/hooch
	name = "hooch"
	desc = "Maintenance vintage. Dram waters it down and sells it back to the same people who brewed it."
	category = "The Cellar"
	item_path = /obj/item/reagent_containers/cup/glass/bottle/hooch
	pay_credits = 60
	demand_min = 3
	demand_max = 6

/datum/shop_buyback/dregs/kong
	name = "bottle of Kong"
	desc = "They stopped making it. Somebody keeps finding it. Dram keeps buying it."
	category = "The Cellar"
	item_path = /obj/item/reagent_containers/cup/glass/bottle/kong
	pay_credits = 100
	demand_min = 1
	demand_max = 3

/datum/shop_buyback/dregs/ritual_wine
	name = "ritual wine"
	desc = "Dram won't say who drinks it, only that they tip in advance and arrive by airlock."
	category = "The Cellar"
	item_path = /obj/item/reagent_containers/cup/glass/bottle/ritual_wine
	pay_credits = 300
	demand_min = 1
	demand_max = 2

// =========================================================================
// PATCH-UP CLINIC: Sawbones, practitioner (license pending since forever)
// =========================================================================

/**
 * Sawbones: dressed like a surgeon by someone working from a description. The
 * scrubs and nitrile gloves are real practice; the head mirror is forty years
 * obsolete and worn because patients expect a doctor to have one. No coat, no
 * credentials, and the analyzer never leaves their hand.
 *
 * Kept visually clear of Splice two doors down (voidcrew/modules/cyberware),
 * different scrubs, different gloves, no leather, no cigarette.
 */
/datum/outfit/clinic_sawbones
	name = "Clinic practitioner"
	uniform = /obj/item/clothing/under/rank/medical/scrubs/green
	gloves = /obj/item/clothing/gloves/latex/nitrile
	head = /obj/item/clothing/head/utility/head_mirror
	shoes = /obj/item/clothing/shoes/workboots
	r_hand = /obj/item/healthanalyzer

/// Sawbones, the Patch-Up Clinic's resident professional. Of medicine, probably.
/datum/outpost_shop/vendor/patchup_clinic
	outpost_name = "\improper Patch-Up Clinic"
	outpost_desc = "The Undertow's medbay."
	trader_name = "Sawbones"
	trader_outfit = /datum/outfit/clinic_sawbones
	trader_voice_pack = "goon.speak_4"
	trader_voice_pitch = 1.12
	categories = list(
		"Field Medicine",
		"Pharmacy",
		"Back Room",
		"Spare Parts",
		"Job Packs",
	)
	sku_types = list(
		// Field Medicine
		/datum/shop_sku/clinic/advanced_medkit,
		/datum/shop_sku/clinic/surgery_kit,
		/datum/shop_sku/clinic/o2_medkit,
		/datum/shop_sku/clinic/toxin_medkit,
		/datum/shop_sku/clinic/blood_pack,
		// Pharmacy
		/datum/shop_sku/clinic/mutadone_bottle,
		/datum/shop_sku/clinic/mannitol_bottle,
		/datum/shop_sku/clinic/penacid_bottle,
		/datum/shop_sku/clinic/psicodine_bottle,
		/datum/shop_sku/clinic/morphine_bottle,
		// Back Room
		/datum/shop_sku/clinic/happy_pills,
		/datum/shop_sku/clinic/lsd_pills,
		/datum/shop_sku/clinic/zoom_pills,
		/datum/shop_sku/clinic/aranesp_pills,
		/datum/shop_sku/clinic/mystery_pills,
		/datum/shop_sku/clinic/morphine_pen,
		// Spare Parts
		/datum/shop_sku/clinic/heart,
		/datum/shop_sku/clinic/liver,
		/datum/shop_sku/clinic/lungs,
		/datum/shop_sku/clinic/autosurgeon,
		// Job Packs: the crate lives in shop_catalog_job_packs.dm
		/datum/shop_sku/clinic/job_pack_genetics,
	)
	rotating_pool = list(
		/datum/shop_sku/clinic/rotating/tactical_lite_medkit,
		/datum/shop_sku/clinic/rotating/atropine_pen,
		/datum/shop_sku/clinic/rotating/penthrite_pen,
		/datum/shop_sku/clinic/rotating/survival_pen,
		/datum/shop_sku/clinic/rotating/prescription_stimulants,
		/datum/shop_sku/clinic/rotating/meth_pen,
	)
	rare_pool = list(
		/datum/shop_sku/clinic/rare/syndie_surgery_kit,
		/datum/shop_sku/clinic/rare/compact_defib,
	)
	buyback_types = list(
		/datum/shop_buyback/clinic/heart,
		/datum/shop_buyback/clinic/liver,
		/datum/shop_buyback/clinic/lungs,
		/datum/shop_buyback/clinic/monster_gland,
		/datum/shop_buyback/clinic/used_defib,
	)
	trader_lines = list(
		TRADER_LINE_SALE = list(
			"Sold. Shake it before use. Or don't, dealer's choice.",
			"Excellent choice. Side effects are listed somewhere. Probably.",
			"That'll fix you right up, or at least differently.",
			"Payment received. The warranty died on the table, sorry.",
			"A discerning customer. Most people just scream and point.",
		),
		TRADER_LINE_REFUSAL = list(
			"Your chart says 'embargoed'. Medically speaking, that's terminal.",
			"No credit, no cure. Come back when your ship behaves.",
			"I took an oath. It was mostly about getting paid first.",
		),
		TRADER_LINE_IDLE = list(
			"Walk-ins welcome. Crawl-ins pay the same rates.",
			"The organs are fresh. Freshness is a spectrum.",
			"I don't ask where the hearts come from, and they extend me the same courtesy.",
			"The cryo tube works. Everything in this clinic works. On most species.",
			"Vex handles the bullets going out. I handle the ones coming back.",
			"Bring me monster glands. The things I can do with a rush gland are barely legal. Here. Barely legal HERE.",
			"Lost a limb? The freezer has spares. Sizes vary. Sides vary too.",
		),
		TRADER_LINE_RESTOCK = list(
			"Supply run's in. The pills are back in the CORRECT unmarked bottles.",
			"Fresh stock. The convoy medic and I have an understanding.",
			"Restocked. Ask me about the organ special. Don't ask about the donor.",
		),
	)

/datum/shop_sku/clinic
	stock_min = 1
	stock_max = 3

// ===== FIELD MEDICINE =====

/datum/shop_sku/clinic/advanced_medkit
	category = "Field Medicine"
	item_path = /obj/item/storage/medkit/advanced
	price_credits = 900
	stock_min = 1
	stock_max = 2

/datum/shop_sku/clinic/surgery_kit
	category = "Field Medicine"
	item_path = /obj/item/storage/medkit/surgery
	price_credits = 750
	stock_min = 1
	stock_max = 2

/datum/shop_sku/clinic/o2_medkit
	category = "Field Medicine"
	item_path = /obj/item/storage/medkit/o2
	price_credits = 300
	stock_min = 2
	stock_max = 3

/datum/shop_sku/clinic/toxin_medkit
	category = "Field Medicine"
	item_path = /obj/item/storage/medkit/toxin
	price_credits = 300
	stock_min = 2
	stock_max = 3

/datum/shop_sku/clinic/blood_pack
	category = "Field Medicine"
	name = "O- blood pack"
	desc = "Universal donor blood. Sawbones swears it's O negative and mostly blood."
	item_path = /obj/item/reagent_containers/blood/o_minus
	price_credits = 300
	stock_min = 2
	stock_max = 4

// ===== PHARMACY =====

/datum/shop_sku/clinic/mutadone_bottle
	category = "Pharmacy"
	item_path = /obj/item/storage/pill_bottle/mutadone
	price_credits = 400
	stock_min = 1
	stock_max = 2

/datum/shop_sku/clinic/mannitol_bottle
	category = "Pharmacy"
	item_path = /obj/item/storage/pill_bottle/mannitol
	price_credits = 200
	stock_min = 1
	stock_max = 3

/datum/shop_sku/clinic/penacid_bottle
	category = "Pharmacy"
	item_path = /obj/item/storage/pill_bottle/penacid
	price_credits = 300
	stock_min = 1
	stock_max = 3

/datum/shop_sku/clinic/psicodine_bottle
	category = "Pharmacy"
	item_path = /obj/item/storage/pill_bottle/psicodine
	price_credits = 200
	stock_min = 1
	stock_max = 2

/datum/shop_sku/clinic/morphine_bottle
	category = "Pharmacy"
	name = "morphine bottle"
	desc = "For pain management. Whose pain is your business."
	item_path = /obj/item/reagent_containers/cup/bottle/morphine
	price_credits = 450
	stock_min = 1
	stock_max = 2

// ===== BACK ROOM =====
// The shelf that isn't on the sign. Recreational, "recreational", and worse.

/datum/shop_sku/clinic/happy_pills
	category = "Back Room"
	item_path = /obj/item/storage/pill_bottle/happy
	price_credits = 400
	stock_min = 1
	stock_max = 1

/datum/shop_sku/clinic/lsd_pills
	category = "Back Room"
	item_path = /obj/item/storage/pill_bottle/lsd
	price_credits = 250
	stock_min = 1
	stock_max = 2

/datum/shop_sku/clinic/zoom_pills
	category = "Back Room"
	item_path = /obj/item/storage/pill_bottle/zoom
	price_credits = 300
	stock_min = 1
	stock_max = 1

/datum/shop_sku/clinic/aranesp_pills
	category = "Back Room"
	item_path = /obj/item/storage/pill_bottle/aranesp
	price_credits = 300
	stock_min = 1
	stock_max = 1

/datum/shop_sku/clinic/mystery_pills
	category = "Back Room"
	name = "mystery pills"
	desc = "A bottle of assorted maintenance-grade pharmaceuticals. Sawbones calls it a sampler. There is no label."
	item_path = /obj/item/storage/pill_bottle/maintenance_pill
	price_credits = 75
	stock_min = 2
	stock_max = 4

/datum/shop_sku/clinic/morphine_pen
	category = "Back Room"
	item_path = /obj/item/reagent_containers/hypospray/medipen/morphine
	price_credits = 200
	stock_min = 1
	stock_max = 3

// ===== SPARE PARTS =====

/datum/shop_sku/clinic/heart
	category = "Spare Parts"
	name = "pre-owned heart"
	desc = "One careful owner. Sawbones guarantees it was beating recently."
	item_path = /obj/item/organ/heart
	price_credits = 450
	stock_min = 1
	stock_max = 2

/datum/shop_sku/clinic/liver
	category = "Spare Parts"
	name = "lightly used liver"
	desc = "Some cosmetic wear, consistent with the previous owner drinking at the Dregs."
	item_path = /obj/item/organ/liver
	price_credits = 400
	stock_min = 1
	stock_max = 2

/datum/shop_sku/clinic/lungs
	category = "Spare Parts"
	name = "reconditioned lungs"
	desc = "Aired out and everything. Non-smoker, allegedly."
	item_path = /obj/item/organ/lungs
	price_credits = 400
	stock_min = 1
	stock_max = 2

/datum/shop_sku/clinic/autosurgeon
	category = "Spare Parts"
	name = "autosurgeon"
	desc = "Load an organ, press it against your chest, look away. Surgery for people who don't have a surgeon."
	item_path = /obj/item/autosurgeon
	price_credits = 600
	stock_min = 1
	stock_max = 2

// ===== ROTATING SHELF =====

/datum/shop_sku/clinic/rotating/tactical_lite_medkit
	category = "Field Medicine"
	item_path = /obj/item/storage/medkit/tactical_lite
	price_vouchers = 1

/datum/shop_sku/clinic/rotating/atropine_pen
	category = "Pharmacy"
	item_path = /obj/item/reagent_containers/hypospray/medipen/atropine
	price_credits = 450

/datum/shop_sku/clinic/rotating/penthrite_pen
	category = "Pharmacy"
	item_path = /obj/item/reagent_containers/hypospray/medipen/penthrite
	price_credits = 500

/datum/shop_sku/clinic/rotating/survival_pen
	category = "Field Medicine"
	item_path = /obj/item/reagent_containers/hypospray/medipen/survival
	price_credits = 400

/datum/shop_sku/clinic/rotating/prescription_stimulants
	category = "Back Room"
	item_path = /obj/item/storage/pill_bottle/prescription_stimulant
	price_credits = 400

/datum/shop_sku/clinic/rotating/meth_pen
	category = "Back Room"
	name = "unlabeled medipen"
	desc = "Sawbones describes the contents as 'motivation'. The chemical analysis describes them as methamphetamine."
	item_path = /obj/item/reagent_containers/hypospray/medipen/methamphetamine
	price_vouchers = 1

// ===== RARE SHOWCASE =====

/datum/shop_sku/clinic/rare/syndie_surgery_kit
	category = "Field Medicine"
	item_path = /obj/item/storage/medkit/surgery_syndie
	price_vouchers = 2

/datum/shop_sku/clinic/rare/compact_defib
	category = "Field Medicine"
	item_path = /obj/item/defibrillator/compact
	price_vouchers = 2

// ===== SAWBONES' INTAKE LEDGER (buybacks) =====
// Credits only, and nothing a ship lathe can print: organs, monster glands,
// and pre-owned defibs (the medical equivalent of Vex's gun fencing).

/datum/shop_buyback/clinic/heart
	name = "donor heart"
	desc = "Provenance optional. Pulse optional. Sawbones has a cooler and a client list."
	category = "Organ Intake"
	item_path = /obj/item/organ/heart
	pay_credits = 150
	demand_min = 2
	demand_max = 4

/datum/shop_buyback/clinic/liver
	name = "donor liver"
	desc = "The red-zone liver market is a growth industry. Ask Dram why."
	category = "Organ Intake"
	item_path = /obj/item/organ/liver
	pay_credits = 100
	demand_min = 2
	demand_max = 4

/datum/shop_buyback/clinic/lungs
	name = "donor lungs"
	desc = "Matched pairs preferred. Singles negotiable."
	category = "Organ Intake"
	item_path = /obj/item/organ/lungs
	pay_credits = 100
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/clinic/monster_gland
	name = "monster gland (any)"
	desc = "Rush glands, brimdust sacs, regenerative cores: if it came out of something that tried to eat you, Sawbones wants it on ice."
	category = "Organ Intake"
	item_path = /obj/item/organ/monster_core
	pay_credits = 250
	demand_min = 3
	demand_max = 5

/datum/shop_buyback/clinic/used_defib
	name = "defibrillator (pre-owned)"
	desc = "Sawbones buys defibs with a history. Scorch marks are fine. Scorch marks are expected."
	category = "Equipment Intake"
	item_path = /obj/item/defibrillator
	pay_credits = 250
	demand_min = 2
	demand_max = 4
