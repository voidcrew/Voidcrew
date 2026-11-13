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
 * - Boffin is the only store that sells raw anomaly cores (cargo no longer
 *   carries them) and anomaly charts. Both sit on small weighted rotations of
 *   two slots, one unit each. A sold slot turns over to a different type at
 *   the next convoy. Both take the normal specials. The
 *   core buybacks sit far below any core's price, and a core refined from a
 *   bought raw core keeps the shop's stamp (buyback_listed.dm), so it can't
 *   be sold back at all.
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
		"Anomalies",
		"Job Packs",
	)
	sku_types = list(
		// Gadgetry
		/datum/shop_sku/skunk/signaler,
		/datum/shop_sku/skunk/adv_analyzer,
		/datum/shop_sku/skunk/science_gps,
		/datum/shop_sku/skunk/alien_sample,
		/datum/shop_sku/skunk/strongarm,
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
	rotations = list(
		/datum/shop_rotation/skunk_cores,
		/datum/shop_rotation/skunk_anomaly_charts,
	)
	buyback_types = list(
		/datum/shop_buyback/skunk/anomaly_core,
		/datum/shop_buyback/skunk/anomaly_core/uncommon,
		/datum/shop_buyback/skunk/anomaly_core/rare,
		/datum/shop_buyback/skunk/anomaly_core/raw,
		/datum/shop_buyback/skunk/anomaly_core/raw/uncommon,
		/datum/shop_buyback/skunk/anomaly_core/raw/rare,
		/datum/shop_buyback/skunk/slime_extract,
		/datum/shop_buyback/skunk/slime_extract/common,
		/datum/shop_buyback/skunk/slime_extract/rare,
		/datum/shop_buyback/skunk/slime_extract/exotic,
		/datum/shop_buyback/skunk/slime_extract/rainbow,
		/datum/shop_buyback/skunk/crossbred,
		/datum/shop_buyback/skunk/crossbred/rare,
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
	price_credits = 80
	stock_min = 3
	stock_max = 6

/datum/shop_sku/skunk/adv_analyzer
	category = "Gadgetry"
	item_path = /obj/item/healthanalyzer/advanced
	price_credits = 400
	stock_min = 1
	stock_max = 2

/datum/shop_sku/skunk/science_gps
	category = "Gadgetry"
	item_path = /obj/item/gps/science
	price_credits = 50
	stock_min = 1
	stock_max = 3

/datum/shop_sku/skunk/alien_sample
	category = "Gadgetry"
	name = "alien crowbar sample"
	desc = "An alien crowbar with an unfamiliar metal finish."
	item_path = /obj/item/crowbar/abductor
	price_credits = 900
	stock_min = 3
	stock_max = 3

/datum/shop_sku/skunk/strongarm
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Gadgetry"
	name = "Strong-Arm implants (pair)"
	desc = "A matched pair of arm muscle implants, one per arm."
	item_path = /obj/item/organ/cyberimp/arm/strongarm
	price_credits = 1200
	stock_min = 1
	stock_max = 2
	contract_reward = FALSE

/// One sale, both implants.
/datum/shop_sku/skunk/strongarm/dispense(mob/living/user, mob/living/carbon/human/npc/ambient_npc/outpost/trader/vendor)
	. = ..()
	..()

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
	desc = "An empty rapid part exchange device."
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
	price_credits = 200

/datum/shop_sku/skunk/diagnostic_hud
	category = "Power & Optics"
	item_path = /obj/item/clothing/glasses/hud/diagnostic
	price_credits = 400
	stock_min = 1
	stock_max = 3

/datum/shop_sku/skunk/night_vision
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Power & Optics"
	item_path = /obj/item/clothing/glasses/night
	price_credits = 2100
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
	desc = "A canister of expanding hull-patch foam."
	item_path = /obj/item/grenade/chem_grenade/smart_metal_foam
	price_credits = 150

/datum/shop_sku/skunk/rotating/thermal_glasses
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Power & Optics"
	item_path = /obj/item/clothing/glasses/thermal
	price_vouchers = 2
	price_credits = 2100

// ===== RARE SHOWCASE =====

/datum/shop_sku/skunk/rare/deluxe_parts
	category = "Ship Retrofit"
	name = "deluxe stock part crate"
	desc = "A boxed set of top-shelf components, straight off a convoy that Boffin refuses to name."
	item_path = /obj/item/storage/box/stockparts/deluxe
	price_credits = 1500

/datum/shop_sku/skunk/rare/hyper_cell
	category = "Power & Optics"
	item_path = /obj/item/stock_parts/power_store/cell/hyper
	price_credits = 1200

// ===== ANOMALIES =====
// Raw cores still need the refinery and a bomb. Rarer types turn up less often
// and cost more. The charts for the same types live in anomaly_charts.dm.

/datum/shop_rotation/skunk_cores
	slots = 2
	pool = list(
		/datum/shop_sku/skunk/anomaly_core/flux = 6,
		/datum/shop_sku/skunk/anomaly_core/grav = 6,
		/datum/shop_sku/skunk/anomaly_core/hallucination = 6,
		/datum/shop_sku/skunk/anomaly_core/pyro = 6,
		/datum/shop_sku/skunk/anomaly_core/bioscrambler = 3,
		/datum/shop_sku/skunk/anomaly_core/ectoplasm = 3,
		/datum/shop_sku/skunk/anomaly_core/dimensional = 3,
		/datum/shop_sku/skunk/anomaly_core/bluespace = 1,
		/datum/shop_sku/skunk/anomaly_core/vortex = 1,
	)

/datum/shop_rotation/skunk_anomaly_charts
	slots = 4
	pool = list(
		/datum/shop_sku/anomaly_chart/flux = 6,
		/datum/shop_sku/anomaly_chart/grav = 6,
		/datum/shop_sku/anomaly_chart/hallucination = 6,
		/datum/shop_sku/anomaly_chart/pyro = 6,
		/datum/shop_sku/anomaly_chart/bioscrambler = 3,
		/datum/shop_sku/anomaly_chart/ectoplasm = 3,
		/datum/shop_sku/anomaly_chart/dimensional = 3,
		/datum/shop_sku/anomaly_chart/bluespace = 1,
		/datum/shop_sku/anomaly_chart/vortex = 1,
	)

/// Raw cores: normal specials apply; contracts never pay them out
/datum/shop_sku/skunk/anomaly_core
	category = "Anomalies"
	stock_min = 1
	stock_max = 1
	contract_reward = FALSE

/datum/shop_sku/skunk/anomaly_core/flux
	item_path = /obj/item/raw_anomaly_core/flux
	price_credits = 8000

/datum/shop_sku/skunk/anomaly_core/grav
	item_path = /obj/item/raw_anomaly_core/grav
	price_credits = 8000

/datum/shop_sku/skunk/anomaly_core/hallucination
	item_path = /obj/item/raw_anomaly_core/hallucination
	price_credits = 8000

/datum/shop_sku/skunk/anomaly_core/pyro
	item_path = /obj/item/raw_anomaly_core/pyro
	price_credits = 8000

/datum/shop_sku/skunk/anomaly_core/bioscrambler
	item_path = /obj/item/raw_anomaly_core/bioscrambler
	price_credits = 10000

/datum/shop_sku/skunk/anomaly_core/ectoplasm
	item_path = /obj/item/raw_anomaly_core/ectoplasm
	price_credits = 10000

/datum/shop_sku/skunk/anomaly_core/dimensional
	item_path = /obj/item/raw_anomaly_core/dimensional
	price_credits = 10000

/datum/shop_sku/skunk/anomaly_core/bluespace
	item_path = /obj/item/raw_anomaly_core/bluespace
	price_credits = 12000

/datum/shop_sku/skunk/anomaly_core/vortex
	item_path = /obj/item/raw_anomaly_core/vortex
	price_credits = 12000

// ===== BOFFIN'S SPECIMEN LEDGER (buybacks) =====
// Nothing a lathe can print. Planet exotics and things that glow wrong.

// Anomaly cores, priced the way his own shelf weights them: flux, grav,
// hallucination and pyro turn up most; bioscrambler, ectoplasm and dimensional
// less; bluespace and vortex rarely. "Raw" is /obj/item/raw_anomaly_core, the
// sealed core that still needs the refinery's implosion; a refined core
// (/obj/item/assembly/signaler/anomaly) is what drops when a crew neutralizes a
// live anomaly. Raw cores on his shelf cost 8,000-12,000 cr, and the refinery
// carries the shop's stamp onto the refined core, so neither can be sold back.

/datum/shop_buyback/skunk/anomaly_core
	name = "anomaly core"
	desc = "An intact core out of a collapsed anomaly. Boffin pays well and asks that you not shake the container. He asks this several times."
	category = "Anomalies"
	item_path = /obj/item/assembly/signaler/anomaly
	pay_credits = 800
	demand_min = 2
	demand_max = 4
	/// Exact core types this row takes
	var/list/core_types = list(
		/obj/item/assembly/signaler/anomaly/flux,
		/obj/item/assembly/signaler/anomaly/grav,
		/obj/item/assembly/signaler/anomaly/hallucination,
		/obj/item/assembly/signaler/anomaly/pyro,
	)
	var/list/core_cache
	/// Core whose sprite the ledger shows
	var/obj/item/display_path = /obj/item/assembly/signaler/anomaly/flux

/datum/shop_buyback/skunk/anomaly_core/New()
	..()
	core_cache = buyback_exact_cache(core_types)
	buyback_use_display_icon(src, display_path)

/datum/shop_buyback/skunk/anomaly_core/buyback_wanted_kind(obj/item/offered)
	return core_cache?[offered.type]

/datum/shop_buyback/skunk/anomaly_core/matches(obj/item/offered)
	if(!..())
		return FALSE
	// Loose only: a core seated in a MOD module or a device stays where it is
	return buyback_wanted_kind(offered) && buyback_goods_loose(offered)

/datum/shop_buyback/skunk/anomaly_core/get_denial_reason(mob/living/user)
	return buyback_listed_denial(src, user)

/datum/shop_buyback/skunk/anomaly_core/uncommon
	name = "uncommon anomaly core"
	desc = "Bioscrambler, ectoplasmic or dimensional. Boffin has a shelf for each and they are all nearly empty."
	pay_credits = 1500
	demand_min = 2
	demand_max = 3
	core_types = list(
		/obj/item/assembly/signaler/anomaly/bioscrambler,
		/obj/item/assembly/signaler/anomaly/ectoplasm,
		/obj/item/assembly/signaler/anomaly/dimensional,
	)
	display_path = /obj/item/assembly/signaler/anomaly/dimensional

/datum/shop_buyback/skunk/anomaly_core/rare
	name = "bluespace or vortex core"
	desc = "The two he has never managed to buy twice. He'll pay in vouchers, which he hates parting with."
	pay_credits = 0
	pay_vouchers = 2
	demand_min = 1
	demand_max = 2
	core_types = list(
		/obj/item/assembly/signaler/anomaly/bluespace,
		/obj/item/assembly/signaler/anomaly/vortex,
	)
	display_path = /obj/item/assembly/signaler/anomaly/vortex

/datum/shop_buyback/skunk/anomaly_core/raw
	name = "raw anomaly core"
	desc = "A sealed core nobody has run through a refinery yet. Boffin has a refinery. He also has a long list of complaints about it."
	category = "Anomalies"
	item_path = /obj/item/raw_anomaly_core
	pay_credits = 400
	demand_min = 1
	demand_max = 2
	core_types = list(
		/obj/item/raw_anomaly_core/flux,
		/obj/item/raw_anomaly_core/grav,
		/obj/item/raw_anomaly_core/hallucination,
		/obj/item/raw_anomaly_core/pyro,
	)
	display_path = /obj/item/raw_anomaly_core/flux

/datum/shop_buyback/skunk/anomaly_core/raw/uncommon
	name = "uncommon raw core"
	desc = "Unrefined bioscrambler, ectoplasmic or dimensional cores."
	pay_credits = 700
	core_types = list(
		/obj/item/raw_anomaly_core/bioscrambler,
		/obj/item/raw_anomaly_core/ectoplasm,
		/obj/item/raw_anomaly_core/dimensional,
	)
	display_path = /obj/item/raw_anomaly_core/dimensional

/datum/shop_buyback/skunk/anomaly_core/raw/rare
	name = "raw bluespace or vortex core"
	desc = "Unrefined, and still the best thing anyone has brought him all week."
	pay_credits = 1200
	core_types = list(
		/obj/item/raw_anomaly_core/bluespace,
		/obj/item/raw_anomaly_core/vortex,
	)
	display_path = /obj/item/raw_anomaly_core/vortex

// Slime extracts by colour, following the mutation ladder from grey to
// rainbow. Only whole, unspent extracts: a cored-out one is jelly. Ship labs
// make these, so only rainbow and the rarer crossbreeds pay vouchers, on
// small demand that every crew shares.

/datum/shop_buyback/skunk/slime_extract
	name = "grey slime extract"
	desc = "Every lab's first extract. Boffin keeps a jar of them for when he runs out of the interesting ones."
	category = "Slime Extracts"
	item_path = /obj/item/slime_extract
	pay_credits = 50
	demand_min = 4
	demand_max = 8
	/// Exact extract types this row takes
	var/list/extract_types = list(/obj/item/slime_extract/grey)
	var/list/extract_cache
	/// Extract whose sprite the ledger shows
	var/obj/item/display_path = /obj/item/slime_extract/grey

/datum/shop_buyback/skunk/slime_extract/New()
	..()
	extract_cache = buyback_exact_cache(extract_types)
	buyback_use_display_icon(src, display_path)

/datum/shop_buyback/skunk/slime_extract/buyback_wanted_kind(obj/item/offered)
	return extract_cache?[offered.type]

/datum/shop_buyback/skunk/slime_extract/matches(obj/item/offered)
	if(!..())
		return FALSE
	if(!buyback_wanted_kind(offered) || !buyback_goods_loose(offered))
		return FALSE
	var/obj/item/slime_extract/extract = offered
	// Spent cores are jelly, and a recurring crossbreed's core belongs to it
	return extract.extract_uses > 0 && !extract.recurring

/datum/shop_buyback/skunk/slime_extract/get_denial_reason(mob/living/user)
	return buyback_listed_denial(src, user)

/datum/shop_buyback/skunk/slime_extract/common
	name = "common slime extract"
	desc = "Orange, purple, blue, metal, yellow, dark purple, dark blue or silver."
	pay_credits = 150
	demand_min = 3
	demand_max = 6
	extract_types = list(
		/obj/item/slime_extract/orange,
		/obj/item/slime_extract/purple,
		/obj/item/slime_extract/blue,
		/obj/item/slime_extract/metal,
		/obj/item/slime_extract/yellow,
		/obj/item/slime_extract/darkpurple,
		/obj/item/slime_extract/darkblue,
		/obj/item/slime_extract/silver,
	)
	display_path = /obj/item/slime_extract/orange

/datum/shop_buyback/skunk/slime_extract/rare
	name = "rare slime extract"
	desc = "Bluespace, sepia, cerulean or pyrite. The ones that start doing strange things to the room."
	pay_credits = 300
	demand_min = 3
	demand_max = 5
	extract_types = list(
		/obj/item/slime_extract/bluespace,
		/obj/item/slime_extract/sepia,
		/obj/item/slime_extract/cerulean,
		/obj/item/slime_extract/pyrite,
	)
	display_path = /obj/item/slime_extract/bluespace

/datum/shop_buyback/skunk/slime_extract/exotic
	name = "exotic slime extract"
	desc = "Red, green, pink, gold, oil, black, light pink or adamantine. Boffin has a waiting list for most of them."
	pay_credits = 550
	demand_min = 2
	demand_max = 4
	extract_types = list(
		/obj/item/slime_extract/red,
		/obj/item/slime_extract/green,
		/obj/item/slime_extract/pink,
		/obj/item/slime_extract/gold,
		/obj/item/slime_extract/oil,
		/obj/item/slime_extract/black,
		/obj/item/slime_extract/lightpink,
		/obj/item/slime_extract/adamantine,
	)
	display_path = /obj/item/slime_extract/adamantine

/datum/shop_buyback/skunk/slime_extract/rainbow
	name = "rainbow slime extract"
	desc = "The end of the ladder. Boffin has seen two in his life and wants a third."
	pay_credits = 0
	pay_vouchers = 1
	demand_min = 1
	demand_max = 2
	extract_types = list(/obj/item/slime_extract/rainbow)
	display_path = /obj/item/slime_extract/rainbow

/// Crossbreeds, priced by the colour of the slime that made them. Self-sustaining
/// ones split on the spot and are never offered whole, so they're left out.
/datum/shop_buyback/skunk/crossbred
	name = "crossbred extract"
	desc = "Any crossbreed off a common slime. Ten extracts went into each, which is the part Boffin respects."
	category = "Slime Extracts"
	item_path = /obj/item/slimecross
	pay_credits = 450
	demand_min = 2
	demand_max = 3
	/// Slime colours (SLIME_TYPE_*) this row takes
	var/list/colours = list(
		SLIME_TYPE_GREY,
		SLIME_TYPE_ORANGE,
		SLIME_TYPE_PURPLE,
		SLIME_TYPE_BLUE,
		SLIME_TYPE_METAL,
		SLIME_TYPE_YELLOW,
		SLIME_TYPE_DARK_PURPLE,
		SLIME_TYPE_DARK_BLUE,
		SLIME_TYPE_SILVER,
	)
	/// Crossbreed whose sprite the ledger shows
	var/obj/item/display_path = /obj/item/slimecross/stabilized/grey

/datum/shop_buyback/skunk/crossbred/New()
	..()
	buyback_use_display_icon(src, display_path)

/datum/shop_buyback/skunk/crossbred/buyback_wanted_kind(obj/item/offered)
	if(!istype(offered, /obj/item/slimecross) || istype(offered, /obj/item/slimecross/selfsustaining))
		return FALSE
	var/obj/item/slimecross/cross = offered
	return cross.colour in colours

/datum/shop_buyback/skunk/crossbred/matches(obj/item/offered)
	if(!..())
		return FALSE
	return buyback_wanted_kind(offered) && buyback_goods_loose(offered)

/datum/shop_buyback/skunk/crossbred/get_denial_reason(mob/living/user)
	return buyback_listed_denial(src, user)

/datum/shop_buyback/skunk/crossbred/rare
	name = "rare crossbred extract"
	desc = "A crossbreed off a rare slime, up to rainbow. Stabilized ones especially; he wears three."
	pay_credits = 0
	pay_vouchers = 1
	demand_min = 1
	demand_max = 3
	colours = list(
		SLIME_TYPE_BLUESPACE,
		SLIME_TYPE_SEPIA,
		SLIME_TYPE_CERULEAN,
		SLIME_TYPE_PYRITE,
		SLIME_TYPE_RED,
		SLIME_TYPE_GREEN,
		SLIME_TYPE_PINK,
		SLIME_TYPE_GOLD,
		SLIME_TYPE_OIL,
		SLIME_TYPE_BLACK,
		SLIME_TYPE_LIGHT_PINK,
		SLIME_TYPE_ADAMANTINE,
		SLIME_TYPE_RAINBOW,
	)
	display_path = /obj/item/slimecross/stabilized/rainbow

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
