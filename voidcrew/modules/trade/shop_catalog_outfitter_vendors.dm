/**
 * # Quartermain Depot: vendor stalls
 *
 * The depot's side business: Boffin's Skunkworks, the R&D annex where the
 * "legal-ish" tech gets bench-tested and the neural imprinter hums in the
 * corner. Full /datum/outpost_shop fronted by its own trader NPC, same
 * wiring as the Undertow's stalls (see outpost.dm get_shop(), trader_npc.dm).
 *
 * Balance notes:
 * - No overlap with Sarge's counter: she owns arms, armor, hull stock and the
 *   ship-systems boards; Boffin owns gadgets, machine retrofit parts and power
 *   cells. MOD suits and modules belong to the suit fitter's stall.
 * - Boffin's tier-2 parts and cells offer immediate upgrades while a crew is
 *   still assembling or researching its fabrication equipment. Cargo remains
 *   cheaper in bulk, and a working laboratory rewards making parts aboard ship.
 * - The buyback ledger only wants what a ship can't print: anomaly cores,
 *   slime extracts, and raw exotics out of the ground. No circuit boards.
 *   Anything a lathe spits out is a money loop waiting to happen.
 */

// =========================================================================
// THE SKUNKWORKS: Boffin, depot researcher
// =========================================================================

/**
 * Boffin: a research coat that has clearly been in a fire, over the black
 * jumpsuit of somebody who works with their hands. Green rather than the
 * standard-issue white, the annex buys its own supplies and nobody here has
 * ever filed for a replacement. Goggles on, multitool out, permanently.
 */
/datum/outfit/skunkworks_boffin
	name = "Depot researcher"
	uniform = /obj/item/clothing/under/rank/rnd/roboticist
	suit = /obj/item/clothing/suit/toggle/labcoat/mad
	glasses = /obj/item/clothing/glasses/science
	gloves = /obj/item/clothing/gloves/color/black
	shoes = /obj/item/clothing/shoes/workboots
	r_hand = /obj/item/multitool

/// Boffin, who has a workshop, a budget, and a very loose definition of "field testing"
/datum/outpost_shop/vendor/skunkworks
	outpost_name = "\improper The Skunkworks"
	outpost_desc = "The depot's R&D annex."
	trader_name = "Boffin"
	trader_outfit = /datum/outfit/skunkworks_boffin
	trader_gender = MALE
	trader_voice_pack = "goon.speak_2"
	trader_voice_pitch = 0.9
	categories = list(
		"Gadgetry",
		"Ship Retrofit",
		"Power & Optics",
		"Job Packs",
	)
	sku_types = list(
		// Gadgetry
		/datum/shop_sku/skunk/signaler,
		/datum/shop_sku/skunk/adv_analyzer,
		/datum/shop_sku/skunk/science_gps,
		/datum/shop_sku/skunk/alien_sample,
		// Ship Retrofit: tier-2 parts to tune up a ship's machines
		/datum/shop_sku/skunk/capacitor,
		/datum/shop_sku/skunk/servo,
		/datum/shop_sku/skunk/micro_laser,
		/datum/shop_sku/skunk/scanning_module,
		/datum/shop_sku/skunk/matter_bin,
		/datum/shop_sku/skunk/rped,
		// Power & Optics
		/datum/shop_sku/skunk/high_cell,
		/datum/shop_sku/skunk/science_glasses,
		/datum/shop_sku/skunk/diagnostic_hud,
		/datum/shop_sku/skunk/night_vision,
		// Job Packs: the crates live in shop_catalog_job_packs.dm
		/datum/shop_sku/skunk/job_pack_robotics,
		/datum/shop_sku/skunk/job_pack_xenobiology,
	)
	rotating_pool = list(
		/datum/shop_sku/skunk/rotating/experimental_welder,
		/datum/shop_sku/skunk/rotating/super_cell,
		/datum/shop_sku/skunk/rotating/foam_grenade,
		/datum/shop_sku/skunk/rotating/thermal_glasses,
	)
	rare_pool = list(
		/datum/shop_sku/skunk/rare/deluxe_parts,
		/datum/shop_sku/skunk/rare/hyper_cell,
	)
	buyback_types = list(
		/datum/shop_buyback/skunk/anomaly_core,
		/datum/shop_buyback/skunk/slime_extract,
		/datum/shop_buyback/skunk/bluespace_crystal,
		/datum/shop_buyback/skunk/uranium,
	)
	trader_lines = list(
		TRADER_LINE_SALE = list(
			"Bench-tested. The bench survived, which is the standard I work to.",
			"Sold. Calibration's on you. Blame's also on you, per the receipt.",
			"Good instincts. That one only caught fire in simulation.",
			"Payment logged. If it hums at a frequency you can taste, power it down.",
		),
		TRADER_LINE_REFUSAL = list(
			"You're flagged in the system. I'd let it slide. The system won't.",
			"No sales under embargo. Sarge's rule. Sarge has all the rules and the armory.",
			"Science is neutral. My till, regrettably, is not.",
		),
		TRADER_LINE_IDLE = list(
			"Sarge sells the guns. I sell everything that makes a gun jealous.",
			"Bring me anomaly cores. Intact, please. INTACT. We've had incidents.",
			"The imprinter is perfectly safe. The screaming is a licensing formality.",
			"Slime extracts, glands, crystals: if a planet made it and it shouldn't exist, I'm buying.",
			"A better servo saves material and print time. Check which part your machine actually needs.",
			"The convoy escort calls this annex 'the spooky room'. The convoy escort is correct.",
		),
		TRADER_LINE_RESTOCK = list(
			"Convoy's in. New components, and the crate only ticked a LITTLE.",
			"Fresh stock on the bench. The experimental shelf rotated. Go see what survived QA.",
			"Resupply's landed. QA passed everything. QA is me. QA was in a good mood.",
		),
	)

/datum/shop_sku/skunk
	stock_min = 2
	stock_max = 4

// ===== GADGETRY =====

/datum/shop_sku/skunk/signaler
	category = "Gadgetry"
	item_path = /obj/item/assembly/signaler
	price_credits = 150
	stock_min = 3
	stock_max = 6

/datum/shop_sku/skunk/adv_analyzer
	category = "Gadgetry"
	item_path = /obj/item/healthanalyzer/advanced
	price_credits = 900
	stock_min = 1
	stock_max = 2

/datum/shop_sku/skunk/science_gps
	category = "Gadgetry"
	item_path = /obj/item/gps/science
	price_credits = 400
	stock_min = 1
	stock_max = 3

/datum/shop_sku/skunk/alien_sample
	category = "Gadgetry"
	name = "alien crowbar sample"
	desc = "An alien tool for destructive research. Each sample is consumed to reveal one alien research field. Bring three to investigate all three fields."
	item_path = /obj/item/crowbar/abductor
	price_credits = 1500
	stock_min = 3
	stock_max = 3

// ===== SHIP RETROFIT =====

/datum/shop_sku/skunk/capacitor
	category = "Ship Retrofit"
	item_path = /obj/item/stock_parts/capacitor/adv
	price_credits = 150

/datum/shop_sku/skunk/servo
	category = "Ship Retrofit"
	item_path = /obj/item/stock_parts/servo/nano
	price_credits = 150

/datum/shop_sku/skunk/micro_laser
	category = "Ship Retrofit"
	item_path = /obj/item/stock_parts/micro_laser/high
	price_credits = 150

/datum/shop_sku/skunk/scanning_module
	category = "Ship Retrofit"
	item_path = /obj/item/stock_parts/scanning_module/adv
	price_credits = 150

/datum/shop_sku/skunk/matter_bin
	category = "Ship Retrofit"
	item_path = /obj/item/stock_parts/matter_bin/adv
	price_credits = 150

/datum/shop_sku/skunk/rped
	category = "Ship Retrofit"
	name = "rapid part exchange device"
	desc = "Point at machine, click, parts swap themselves. Sold empty; the parts are the shelf above."
	item_path = /obj/item/storage/part_replacer
	price_credits = 300
	stock_min = 1
	stock_max = 2

// ===== POWER & OPTICS =====

/datum/shop_sku/skunk/high_cell
	category = "Power & Optics"
	item_path = /obj/item/stock_parts/power_store/cell/high
	price_credits = 300

/datum/shop_sku/skunk/science_glasses
	category = "Power & Optics"
	item_path = /obj/item/clothing/glasses/science
	price_credits = 900

/datum/shop_sku/skunk/diagnostic_hud
	category = "Power & Optics"
	item_path = /obj/item/clothing/glasses/hud/diagnostic
	price_credits = 1800
	stock_min = 1
	stock_max = 3

/datum/shop_sku/skunk/night_vision
	category = "Power & Optics"
	item_path = /obj/item/clothing/glasses/night
	price_credits = 5400
	stock_min = 1
	stock_max = 2

// ===== ROTATING BENCH =====

/datum/shop_sku/skunk/rotating
	stock_min = 1
	stock_max = 2

/datum/shop_sku/skunk/rotating/experimental_welder
	category = "Gadgetry"
	item_path = /obj/item/weldingtool/experimental
	price_credits = 750

/datum/shop_sku/skunk/rotating/super_cell
	category = "Power & Optics"
	item_path = /obj/item/stock_parts/power_store/cell/super
	price_credits = 600

/datum/shop_sku/skunk/rotating/foam_grenade
	category = "Gadgetry"
	name = "smart metal foam grenade"
	desc = "A hull-patch grenade. Set it off near a breach and the foam finds the hole on its own."
	item_path = /obj/item/grenade/chem_grenade/smart_metal_foam
	price_credits = 500

/datum/shop_sku/skunk/rotating/thermal_glasses
	category = "Power & Optics"
	item_path = /obj/item/clothing/glasses/thermal
	price_vouchers = 2
	price_credits = 4800

// ===== RARE SHOWCASE =====

/datum/shop_sku/skunk/rare/deluxe_parts
	category = "Ship Retrofit"
	name = "deluxe stock part crate"
	desc = "A boxed set of top-shelf components, straight off a convoy that Boffin refuses to name."
	item_path = /obj/item/storage/box/stockparts/deluxe
	price_vouchers = 1
	price_credits = 3000

/datum/shop_sku/skunk/rare/hyper_cell
	category = "Power & Optics"
	item_path = /obj/item/stock_parts/power_store/cell/hyper
	price_credits = 1200

// ===== BOFFIN'S SPECIMEN LEDGER (buybacks) =====
// Nothing a lathe can print. Planet exotics and things that glow wrong.

/datum/shop_buyback/skunk/anomaly_core
	name = "anomaly core (any)"
	desc = "An intact core out of a collapsed anomaly. Boffin pays full rate and asks that you not shake the container. He asks this several times."
	category = "Specimens"
	item_path = /obj/item/assembly/signaler/anomaly
	pay_credits = 400
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/skunk/slime_extract
	name = "slime extract (any)"
	desc = "Cores cut out of slimes. Every color does something different, and Boffin intends to try all of them."
	category = "Specimens"
	item_path = /obj/item/slime_extract
	pay_credits = 200
	demand_min = 3
	demand_max = 5

/datum/shop_buyback/skunk/bluespace_crystal
	name = "bluespace crystals"
	desc = "Raw bluespace out of the rock. Handled with tongs, purchased with enthusiasm."
	category = "Raw Exotics"
	item_path = /obj/item/stack/ore/bluespace_crystal
	amount = 2
	pay_credits = 250
	demand_min = 3
	demand_max = 5

/datum/shop_buyback/skunk/uranium
	name = "uranium ore"
	desc = "Reactor stock. The depot's cells don't charge themselves, whatever the brochure says."
	category = "Raw Exotics"
	item_path = /obj/item/stack/ore/uranium
	amount = 5
	pay_credits = 300
	demand_min = 2
	demand_max = 4
