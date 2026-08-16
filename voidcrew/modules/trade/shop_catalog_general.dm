/**
 * # Waystation Halcyon: the green-zone general store
 *
 * Sundries, survival kit and honest prices for the safe outer ring. Credits
 * only; the most dangerous thing on the shelf is the chili in the rations.
 * Shop machinery lives in shop.dm; this file is pure catalog.
 */

/**
 * Barnaby: thirty years on the same side of the same counter. Everything reads
 * soft and worn rather than professional. The sweater jacket and flat cap are
 * a shopkeeper's clothes, not a uniform, the reading glasses say he still does
 * the ledger by hand, and the mug is the bad coffee the shop is famous for.
 */
/datum/outfit/halcyon_barnaby
	name = "Halcyon shopkeep"
	uniform = /obj/item/clothing/under/suit/tan
	suit = /obj/item/clothing/suit/toggle/jacket/sweater
	head = /obj/item/clothing/head/flatcap
	glasses = /obj/item/clothing/glasses/regular
	shoes = /obj/item/clothing/shoes/laceup
	r_hand = /obj/item/reagent_containers/cup/glass/coffee

/datum/outpost_shop/general
	outpost_name = "\improper Waystation Halcyon"
	outpost_desc = "A sleepy general store and rest stop on the safe outer ring. The coffee is bad and the prices are honest."
	trader_name = "Barnaby"
	trader_outfit = /datum/outfit/halcyon_barnaby
	trader_gender = MALE
	trader_voice_pack = "goon.speak_1"
	trader_voice_pitch = 1.18
	categories = list(
		"Survival & EVA",
		"Tools & Repair",
		"Medical",
		"Prospecting",
		"Fuel & Gas",
		"Galley & Comforts",
		"Ship Sundries",
		"Colonial Registry",
		"Intel & Charts",
		"Barter Deals",
		"Back Room",
	)
	sku_types = list(
		// Survival & EVA
		/datum/shop_sku/general/oxygen_tank,
		/datum/shop_sku/general/emergency_oxygen,
		/datum/shop_sku/general/breath_mask,
		/datum/shop_sku/general/eva_suit,
		/datum/shop_sku/general/eva_helmet,
		/datum/shop_sku/general/gps,
		/datum/shop_sku/general/flare,
		/datum/shop_sku/general/glowstick,
		/datum/shop_sku/general/survival_medipen,
		/datum/shop_sku/general/oxygen_canister,
		/datum/shop_sku/general/jetpack,
		// Tools & Repair
		/datum/shop_sku/general/toolbelt,
		/datum/shop_sku/general/big_welder,
		/datum/shop_sku/general/welding_fuel,
		/datum/shop_sku/general/light_replacer,
		/datum/shop_sku/general/holofan,
		/datum/shop_sku/general/rcd,
		// Medical
		/datum/shop_sku/general/medkit,
		/datum/shop_sku/general/burn_kit,
		/datum/shop_sku/general/o2_kit,
		/datum/shop_sku/general/health_analyzer,
		/datum/shop_sku/general/epipen,
		/datum/shop_sku/general/gauze,
		/datum/shop_sku/general/suture,
		/datum/shop_sku/general/regen_mesh,
		// Prospecting
		/datum/shop_sku/general/pickaxe,
		/datum/shop_sku/general/mesons,
		/datum/shop_sku/general/ore_bag,
		/datum/shop_sku/general/mining_scanner,
		/datum/shop_sku/general/adv_mining_scanner,
		/datum/shop_sku/general/diamond_pick,
		// Fuel & Gas
		/datum/shop_sku/general/plasma_canister,
		/datum/shop_sku/general/plasma_sheets,
		/datum/shop_sku/general/plasma_ore,
		/datum/shop_sku/general/scoop_board,
		/datum/shop_sku/general/portable_generator,
		// Galley & Comforts
		/datum/shop_sku/general/rations,
		/datum/shop_sku/general/beans,
		/datum/shop_sku/general/chocolate,
		/datum/shop_sku/general/cigarettes,
		/datum/shop_sku/general/lighter,
		/datum/shop_sku/general/cards,
		/datum/shop_sku/general/plushie,
		// Ship Sundries
		/datum/shop_sku/general/floor_tiles,
		/datum/shop_sku/general/iron_sheets,
		/datum/shop_sku/general/glass_sheets,
		/datum/shop_sku/general/plasteel,
		/datum/shop_sku/general/soap,
		/datum/shop_sku/general/autolathe_board,
		/datum/shop_sku/general/supply_console_board,
		// Colonial Registry
		/datum/shop_sku/outpost_deed,
		// Intel & Charts: the cheap always-available rung; the dealt chart
		// shelf below stocks the star charts and the named ruin coordinates
		/datum/shop_sku/rumor,
		// Barter
		/datum/shop_sku/barter/plasma_for_medkit,
	)
	rotating_pool = list(
		/datum/shop_sku/general/rotating/freight_crate,
		/datum/shop_sku/general/rotating/metalfoam,
		/datum/shop_sku/general/rotating/bikehorn,
		/datum/shop_sku/general/rotating/welding_goggles,
		/datum/shop_sku/general/rotating/guitar,
	)
	rare_pool = list(
		/datum/shop_sku/general/rare/bluespace_bodybag,
		/datum/shop_sku/general/rare/drill,
	)
	// The back room: Trusted-standing uniques, per-crew supply (trader_favor.dm)
	favor_sku_types = list(
		/datum/shop_sku/favor/pike_ledger,
		/datum/shop_sku/favor/field_contract_pad,
		/datum/shop_sku/favor/freight_beacon,
	)
	// Charts are a mix. Any outpost can end up holding the coordinates for
	// anywhere. Named ruins are dealt without repeats across all three shops.
	chart_pool = list(
		/datum/shop_sku/chart/green,
		/datum/shop_sku/chart/yellow,
		/datum/shop_sku/chart/red,
		/datum/shop_sku/ruin_chart/armory,
		/datum/shop_sku/ruin_chart/biolab,
		/datum/shop_sku/ruin_chart/pirate_cove,
		/datum/shop_sku/ruin_chart/reliquary,
		/datum/shop_sku/ruin_chart/foundry,
		/datum/shop_sku/ruin_chart/hospice,
		/datum/shop_sku/ruin_chart/liner,
		/datum/shop_sku/ruin_chart/survey,
		/datum/shop_sku/ruin_chart/blacksite,
		/datum/shop_sku/ruin_chart/bitrunner_den,
	)
	chart_picks = 3
	// Barnaby buys honest prospecting hauls at honest prices, plus whatever
	// the trappers, anglers and foragers drag in off the green worlds
	buyback_types = list(
		/datum/shop_buyback/general/gold_ore,
		/datum/shop_buyback/general/diamonds,
		/datum/shop_buyback/general/fresh_catch,
		/datum/shop_buyback/general/bear_pelt,
		/datum/shop_buyback/general/spice_pods,
		/datum/shop_buyback/general/pearl_clam,
	)
	// Waystation restocking: gentle asks for the outer ring
	// Pike's stall makes this the outpost that posts angling requests, and
	// Roux's diner the one that posts kitchen orders
	extra_offer_mix = list(
		/datum/mission/outpost_supply/angler = 15,
		/datum/mission/outpost_supply/cook = 15,
	)
	mission_requests = list(
		list("type" = /obj/item/stack/ore/iron, "name" = "iron ore", "amount" = 15, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("type" = /obj/item/stack/sheet/glass, "name" = "glass sheets", "amount" = 10, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("type" = /obj/item/stack/ore/plasma, "name" = "plasma ore", "amount" = 8, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/fish, "name" = "fresh planet-caught fish", "amount" = 1, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("type" = /obj/item/stack/sheet/animalhide/bear, "name" = "bear hide", "amount" = 1, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/stack/spice_pods, "name" = "wild spice pods", "amount" = 6, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
	)
	// Under the counter: hard contracts only, never sold
	exclusive_rewards = list(
		/obj/item/storage/bag/ore/holding,
		/obj/item/fishing_rod/telescopic/master,
		/obj/item/pickaxe/drill/jackhammer,
	)
	trader_lines = list(
		TRADER_LINE_GREETING = list(
			"Welcome to Halcyon! Mind the gift shop on your way out. We are the gift shop.",
			"Come in, come in. Safest shop this side of the sun.",
			"Hello hello! Kettle's just boiled, shelves are just stocked.",
			"New faces! Or old faces, I never remember. Welcome either way.",
		),
		TRADER_LINE_SALE = list(
			"There you are. Safe travels out there!",
			"Lovely. Do come again. We're literally always here.",
			"Wonderful choice. I'd have picked the same, and I picked all of it.",
			"All wrapped up. Wave at the mechanic on your way out, she likes that.",
		),
		TRADER_LINE_REFUSAL = list(
			"Oh dear. Your ship's on the naughty list, I'm afraid.",
			"No no, I can't sell to you lot. Head office was very clear.",
			"I do forgive you, personally. The till doesn't. Come back later.",
		),
		TRADER_LINE_WARNING = list(
			"Oh, please don't do that, dear. The turrets get ever so cross.",
			"Now now, that's quite enough. One more and I simply can't help you.",
		),
		TRADER_LINE_AGGRESSION = list(
			"In the GREEN zone?! Have you no shame? Turrets, please.",
			"Goodness! Right. Embargo. And I'm telling everyone.",
		),
		TRADER_LINE_IDLE = list(
			"They say the deep-ring traders sell terrible things. We sell sensible boots.",
			"Forty years on this rock and the sun hasn't moved once. Reliable, that.",
			"The anglers bring me the strangest fish. I pay for all of them. The chowder pot forgives.",
			"Roux runs the diner counter now. I buy the fish, she does the forgiving. Try the special.",
			"Bear hide wears like iron and sleeps like a cloud. The bears disagree, of course.",
			"The pod foragers come back smelling like a spice rack and looking like they lost a fight. I pay them anyway.",
			"Pearl clams! Don't shake them, dear. I candle them cold in the back and never crack a single one.",
			"Take a rumor with you, dear. The lanes talk to me and I do love to pass it on.",
			"We had a jackhammer in the back once. Contract work only, mind. Ask at the board.",
		),
		TRADER_LINE_RESTOCK = list(
			"The supply run's in! Fresh everything, and the biscuit tin's full again.",
			"Restock day! I do love restock day. New oddments on the shelf, go look.",
			"That's the convoy come and gone. Shelves are full and nobody was shot. A good day.",
		),
	)

/datum/shop_sku/general
	stock_min = 3
	stock_max = 6

// ===== SURVIVAL & EVA =====

/datum/shop_sku/general/oxygen_tank
	category = "Survival & EVA"
	item_path = /obj/item/tank/internals/oxygen
	price_credits = 150

/datum/shop_sku/general/emergency_oxygen
	category = "Survival & EVA"
	item_path = /obj/item/tank/internals/emergency_oxygen/engi
	price_credits = 80
	stock_min = 4
	stock_max = 8

/datum/shop_sku/general/breath_mask
	category = "Survival & EVA"
	item_path = /obj/item/clothing/mask/breath
	price_credits = 80

/datum/shop_sku/general/eva_suit
	category = "Survival & EVA"
	item_path = /obj/item/clothing/suit/space/eva
	price_credits = 600
	stock_min = 2
	stock_max = 3

/datum/shop_sku/general/eva_helmet
	category = "Survival & EVA"
	item_path = /obj/item/clothing/head/helmet/space/eva
	price_credits = 450
	stock_min = 2
	stock_max = 3

/datum/shop_sku/general/gps
	category = "Survival & EVA"
	item_path = /obj/item/gps
	price_credits = 200

/datum/shop_sku/general/flare
	category = "Survival & EVA"
	item_path = /obj/item/flashlight/flare
	price_credits = 40
	stock_min = 6
	stock_max = 10

/datum/shop_sku/general/glowstick
	category = "Survival & EVA"
	item_path = /obj/item/flashlight/glowstick
	price_credits = 30
	stock_min = 6
	stock_max = 10

/datum/shop_sku/general/survival_medipen
	category = "Survival & EVA"
	item_path = /obj/item/reagent_containers/hypospray/medipen/survival
	price_credits = 450
	stock_min = 2
	stock_max = 4

/datum/shop_sku/general/oxygen_canister
	name = "oxygen canister (full)"
	desc = "A full canister of breathable oxygen. Wheel it into a compartment that lost its air, crack the valve, and give it a minute. The waystation moves a lot of these."
	category = "Survival & EVA"
	item_path = /obj/machinery/portable_atmospherics/canister/oxygen
	price_credits = 1200
	stock_min = 1
	stock_max = 3

/datum/shop_sku/general/jetpack
	name = "jetpack (oxygen)"
	desc = "A compressed oxygen tank rigged for propulsion. It will breathe you or fly you, but not both for very long. Standard kit for anyone patching a hull from the outside."
	category = "Survival & EVA"
	item_path = /obj/item/tank/jetpack/oxygen
	price_credits = 2100
	stock_min = 1
	stock_max = 2

// ===== TOOLS & REPAIR =====

/datum/shop_sku/general/toolbelt
	category = "Tools & Repair"
	item_path = /obj/item/storage/belt/utility/atmostech
	price_credits = 500

// The large-tank welder only prints on a hacked lathe, so this is the cheap
// rung on a shelf that otherwise starts at 250 cr.
/datum/shop_sku/general/big_welder
	category = "Tools & Repair"
	item_path = /obj/item/weldingtool/largetank
	price_credits = 300

/datum/shop_sku/general/welding_fuel
	name = "welding fuel tank"
	desc = "A thousand units of industrial welding fuel in a tank you can drag aboard. Enough to keep a repair crew going for a long shift. Don't weld it."
	category = "Tools & Repair"
	item_path = /obj/structure/reagent_dispensers/fueltank
	price_credits = 400
	stock_min = 2
	stock_max = 4

/datum/shop_sku/general/light_replacer
	category = "Tools & Repair"
	item_path = /obj/item/lightreplacer
	price_credits = 400
	stock_min = 1
	stock_max = 3

/datum/shop_sku/general/holofan
	category = "Tools & Repair"
	name = "holofan projector"
	item_path = /obj/item/holosign_creator/atmos
	price_credits = 600
	stock_min = 1
	stock_max = 2

// The expensive rung on the repair shelf, and the reason ships limp back here
// instead of to a depot: a breach closes in seconds instead of a welding shift.
/datum/shop_sku/general/rcd
	name = "rapid construction device"
	desc = "Lays and removes walls, floors and airlocks out of stored matter. The fast way to shut a breach while the compartment is still venting. Feed it iron, glass, or compressed matter cartridges."
	category = "Tools & Repair"
	item_path = /obj/item/construction/rcd
	price_credits = 2400
	stock_min = 1
	stock_max = 2

// ===== MEDICAL =====

/datum/shop_sku/general/medkit
	category = "Medical"
	item_path = /obj/item/storage/medkit/regular
	price_credits = 300

/datum/shop_sku/general/burn_kit
	category = "Medical"
	item_path = /obj/item/storage/medkit/fire
	price_credits = 400

/datum/shop_sku/general/o2_kit
	category = "Medical"
	item_path = /obj/item/storage/medkit/o2
	price_credits = 400

/datum/shop_sku/general/health_analyzer
	category = "Medical"
	item_path = /obj/item/healthanalyzer
	price_credits = 200

/datum/shop_sku/general/epipen
	category = "Medical"
	item_path = /obj/item/reagent_containers/hypospray/medipen
	price_credits = 150
	stock_min = 4
	stock_max = 8

/datum/shop_sku/general/gauze
	category = "Medical"
	item_path = /obj/item/stack/medical/gauze
	price_credits = 120
	stock_min = 4
	stock_max = 8

/datum/shop_sku/general/suture
	name = "sutures (pack of 10)"
	desc = "Sterile sutures for cuts and heavy bleeding. Ten to a pack, and a pack does not go far on a bad day."
	category = "Medical"
	item_path = /obj/item/stack/medical/suture
	dispense_amount = 10
	price_credits = 180
	stock_min = 4
	stock_max = 8

/datum/shop_sku/general/regen_mesh
	name = "regenerative mesh (pack of 15)"
	desc = "Bacteriostatic mesh for dressing burns. Fifteen pieces, sealed."
	category = "Medical"
	item_path = /obj/item/stack/medical/mesh
	dispense_amount = 15
	price_credits = 180
	stock_min = 4
	stock_max = 8

// ===== PROSPECTING =====

/datum/shop_sku/general/pickaxe
	category = "Prospecting"
	item_path = /obj/item/pickaxe
	price_credits = 200

/datum/shop_sku/general/mesons
	category = "Prospecting"
	item_path = /obj/item/clothing/glasses/meson
	price_credits = 400

/datum/shop_sku/general/ore_bag
	category = "Prospecting"
	item_path = /obj/item/storage/bag/ore
	price_credits = 200

/datum/shop_sku/general/mining_scanner
	category = "Prospecting"
	item_path = /obj/item/t_scanner/adv_mining_scanner/lesser
	price_credits = 450

/datum/shop_sku/general/adv_mining_scanner
	desc = "The full-range model of the scanner on the shelf beside it: seven tiles of rock instead of four, and it re-sweeps half again as fast. Worth it on a planet where the good seams sit deep."
	category = "Prospecting"
	item_path = /obj/item/t_scanner/adv_mining_scanner
	price_credits = 1500
	stock_min = 1
	stock_max = 3

/datum/shop_sku/general/diamond_pick
	category = "Prospecting"
	item_path = /obj/item/pickaxe/diamond
	price_credits = 1200
	stock_min = 1
	stock_max = 2

// ===== GALLEY & COMFORTS =====

/datum/shop_sku/general/rations
	category = "Galley & Comforts"
	item_path = /obj/item/food/rationpack
	price_credits = 40
	stock_min = 6
	stock_max = 12

/datum/shop_sku/general/beans
	category = "Galley & Comforts"
	item_path = /obj/item/food/canned/beans
	price_credits = 30
	stock_min = 4
	stock_max = 8

/datum/shop_sku/general/chocolate
	category = "Galley & Comforts"
	item_path = /obj/item/food/chocolatebar
	price_credits = 50

/datum/shop_sku/general/cigarettes
	category = "Galley & Comforts"
	item_path = /obj/item/storage/fancy/cigarettes
	price_credits = 60

/datum/shop_sku/general/lighter
	category = "Galley & Comforts"
	item_path = /obj/item/lighter
	price_credits = 40

/datum/shop_sku/general/cards
	category = "Galley & Comforts"
	item_path = /obj/item/toy/cards/deck
	price_credits = 80

/datum/shop_sku/general/plushie
	category = "Galley & Comforts"
	item_path = /obj/item/toy/plush/lizard_plushie
	price_credits = 120

// ===== SHIP SUNDRIES =====

/datum/shop_sku/general/floor_tiles
	category = "Ship Sundries"
	item_path = /obj/item/stack/tile/iron/base
	dispense_amount = 20
	price_credits = 120
	stock_min = 3
	stock_max = 6

// Hull stock. Ships take damage and not every crew can mine, Barnaby is the
// boring, reliable place to buy the material back.
/datum/shop_sku/general/iron_sheets
	name = "iron sheets (30)"
	desc = "Thirty sheets of iron off the waystation's own stock. Barnaby sells it by the bundle because nobody ever wants just one."
	category = "Ship Sundries"
	item_path = /obj/item/stack/sheet/iron
	dispense_amount = 30
	price_credits = 200
	stock_min = 3
	stock_max = 6

/datum/shop_sku/general/glass_sheets
	name = "glass sheets (30)"
	desc = "Thirty sheets of glass, packed in straw. Barnaby will remind you that he does not do refunds on glass."
	category = "Ship Sundries"
	item_path = /obj/item/stack/sheet/glass
	dispense_amount = 30
	price_credits = 200
	stock_min = 3
	stock_max = 6

/datum/shop_sku/general/plasteel
	name = "plasteel sheets (20)"
	desc = "Twenty sheets of plasteel for serious hull work. It needs a smelter to make and most ships don't carry one, so this is the honest way to get it."
	category = "Ship Sundries"
	item_path = /obj/item/stack/sheet/plasteel
	dispense_amount = 20
	price_credits = 900
	stock_min = 1
	stock_max = 3

// The fuel dock: plasma at a comfortable waystation markup. The deeper depots
// pump it cheaper, the commute is the discount.
/datum/shop_sku/general/plasma_canister
	name = "plasma canister (full)"
	desc = "A full canister of thruster-grade plasma. It costs more here than at the deep depots. You're paying for the haul out to the safe ring."
	category = "Fuel & Gas"
	item_path = /obj/machinery/portable_atmospherics/canister/plasma
	price_credits = 1800
	stock_min = 2
	stock_max = 3

// Generator fuel. The sheets are the lifeline for any hull with no ore redemption
// machine aboard, without them a ship that burns its plasma has no way back.
// The ore is the cheaper option per sheet, but only if you can actually smelt it.
/datum/shop_sku/general/plasma_sheets
	name = "solid plasma (20)"
	desc = "Twenty sheets of solid plasma, the grade portable generators burn. Buy these if your ship has no way to smelt its own ore."
	category = "Fuel & Gas"
	item_path = /obj/item/stack/sheet/mineral/plasma
	dispense_amount = 20
	price_credits = 500
	stock_min = 2
	stock_max = 4

/datum/shop_sku/general/plasma_ore
	name = "plasma ore (15)"
	desc = "Fifteen chunks of raw plasma ore, cheaper by weight than the refined sheets. You need an ore redemption machine to get anything out of it. A welder will not do the job."
	category = "Fuel & Gas"
	item_path = /obj/item/stack/ore/plasma
	dispense_amount = 15
	price_credits = 220
	stock_min = 2
	stock_max = 4

/datum/shop_sku/general/scoop_board
	name = "nebula ram scoop board"
	desc = "The circuit board for a nebula ram scoop. Park inside a nebula and drink your fuel straight out of the cloud. Barnaby keeps them behind the counter with the good stock."
	category = "Fuel & Gas"
	item_path = /obj/item/circuitboard/machine/shuttle/scoop
	price_credits = 600
	stock_min = 1
	stock_max = 2

// Pairs with the solid plasma two shelves over: the ship that can't fix its
// engine can at least keep the lights and the air handlers running.
/datum/shop_sku/general/portable_generator
	name = "portable plasma generator"
	desc = "A P.A.C.M.A.N. generator that burns solid plasma for power. Bolt it down, wire it to the grid, and it will hold up the essentials while the engine is out. It eats the plasma sheets Barnaby stocks two shelves over."
	category = "Fuel & Gas"
	item_path = /obj/machinery/power/port_gen/pacman
	price_credits = 1800
	stock_min = 1
	stock_max = 2

/datum/shop_sku/general/soap
	category = "Ship Sundries"
	item_path = /obj/item/soap
	price_credits = 60

// Bootstrap insurance. An autolathe board only prints at a circuit imprinter,
// and the imprinter kit only prints at an autolathe - a crew that loses its
// lathe is locked out of the whole fabrication chain with no way back. Barnaby
// stocking the board is the way back. (Round 15: a crew traded away an
// autosurgeon because there was no other way to get one.)
/datum/shop_sku/general/autolathe_board
	name = "autolathe board"
	desc = "The circuit board for an autolathe. If yours is gone, this is the only way to start fabricating again, so Barnaby keeps a couple in the back."
	category = "Ship Sundries"
	item_path = /obj/item/circuitboard/machine/autolathe
	price_credits = 500 // invented, unplaytested
	stock_min = 1
	stock_max = 2

// Same story for the supply console: the board design exists on the techweb
// (Civilian Consoles, imprinter-printed), but a crew without an imprinter has
// no path to one. Sold here so a broken or missing console isn't permanent.
/datum/shop_sku/general/supply_console_board
	name = "supply console board"
	desc = "The circuit board for a ship supply console, the one that calls the cargo shuttle. Barnaby finds it very funny to sell you the thing you buy things with."
	category = "Ship Sundries"
	item_path = /obj/item/circuitboard/computer/voidcrew_cargo
	price_credits = 500 // invented, unplaytested
	stock_min = 1
	stock_max = 2

// Chart and rumor SKUs live in shop_catalog_charts.dm, Barnaby draws his
// through chart_pool above rather than defining his own.

// ===== ROTATING SHELF =====

/datum/shop_sku/general/rotating
	category = "Galley & Comforts"

/datum/shop_sku/general/rotating/freight_crate
	category = "Ship Sundries"
	name = "unclaimed freight"
	desc = "A sealed crate somebody never came back for. Barnaby hasn't looked inside, and he'd rather you opened it somewhere else."
	item_path = /obj/structure/closet/crate/zone_loot/syndicate
	price_credits = 750

/datum/shop_sku/general/rotating/metalfoam
	category = "Ship Sundries"
	name = "metal foam grenades (box of 7)"
	desc = "Seven foam grenades for sealing a hull breach in a hurry. The foam is weak and ugly and it will hold long enough to get the plating on."
	item_path = /obj/item/storage/box/metalfoam
	price_credits = 500

/datum/shop_sku/general/rotating/bikehorn
	item_path = /obj/item/bikehorn
	price_credits = 80

/datum/shop_sku/general/rotating/welding_goggles
	category = "Tools & Repair"
	item_path = /obj/item/clothing/glasses/welding
	price_credits = 180

/datum/shop_sku/general/rotating/guitar
	item_path = /obj/item/instrument/guitar
	price_credits = 400

// ===== RARE SHOWCASE =====

/datum/shop_sku/general/rare/bluespace_bodybag
	category = "Ship Sundries"
	item_path = /obj/item/bodybag/bluespace
	price_credits = 3000

/datum/shop_sku/general/rare/drill
	category = "Prospecting"
	item_path = /obj/item/pickaxe/drill
	price_credits = 1800

// ===== BARNABY'S PROSPECTOR COUNTER (buybacks) =====

/datum/shop_buyback/general/gold_ore
	name = "gold ore"
	desc = "Raw gold, straight from the rock. Barnaby weighs it twice and rounds in your favor."
	category = "Prospecting"
	item_path = /obj/item/stack/ore/gold
	amount = 5
	pay_credits = 300
	demand_min = 4
	demand_max = 8

/datum/shop_buyback/general/diamonds
	name = "diamonds"
	desc = "Uncut diamonds. He keeps them in a biscuit tin behind the counter."
	category = "Prospecting"
	item_path = /obj/item/stack/ore/diamond
	amount = 2
	pay_credits = 500
	demand_min = 2
	demand_max = 4

// Planet-side game: reasons to take the fishing rod and the rifle dirtside
/datum/shop_buyback/general/fresh_catch
	name = "fresh catch (any fish)"
	desc = "Anything with fins, planet-caught. Freshness negotiable; the chowder pot forgives."
	category = "Trapper & Angler"
	item_path = /obj/item/fish
	pay_credits = 150
	demand_min = 5
	demand_max = 8

/datum/shop_buyback/general/bear_pelt
	name = "bear hide"
	desc = "Cave bear hide off the green worlds. Barnaby says it's for the guest bunks. There are no guest bunks."
	category = "Trapper & Angler"
	item_path = /obj/item/stack/sheet/animalhide/bear
	pay_credits = 250
	demand_min = 2
	demand_max = 4

// The jungle planets' good: pod clusters foraged off the surface biomes.
// Wild stock only: the vine can't be grown aboard, so there's nothing to farm.
/datum/shop_buyback/general/spice_pods
	name = "wild spice pods"
	desc = "Pods snipped off jungle-world strangler vines, picked wild. Barnaby buys every cluster that comes through the door. Apparently they do wonders for a stew."
	category = "Forage"
	item_path = /obj/item/stack/spice_pods
	amount = 3
	pay_credits = 250
	demand_min = 3
	demand_max = 5

// The beach planets' good: a rare live catch off the shore-water fishing table.
// Bought sealed: Barnaby does the candling, and the pearl never leaves the back room.
/datum/shop_buyback/general/pearl_clam
	name = "pearl clam (unopened)"
	desc = "A live lagoon clam off the beach worlds, shell shut tight. Barnaby candles them behind the counter and pays for the glow. Cracked or shucked ones are worth exactly nothing."
	category = "Trapper & Angler"
	item_path = /obj/item/pearl_clam
	pay_credits = 350
	demand_min = 2
	demand_max = 4

// Barter demo SKU: Barnaby pays in kit for raw plasma
/datum/shop_sku/barter/plasma_for_medkit
	name = "first-aid kit (plasma trade)"
	item_path = /obj/item/storage/medkit/regular
	barter_path = /obj/item/stack/sheet/mineral/plasma
	barter_amount = 10
	stock_min = 2
	stock_max = 4

// ===== BACK ROOM =====
// Barnaby's favor uniques: Trusted standing only, up to FAVOR_UNIQUE_CREW_LIMIT
// per crew per round. Priced above the rare shelf on purpose, standing opens
// the door, it doesn't pay the bill. All prices PROVISIONAL BALANCE.

/datum/shop_sku/favor/pike_ledger
	item_path = /obj/item/pike_ledger
	price_credits = 3200
	price_vouchers = 2

/datum/shop_sku/favor/field_contract_pad
	item_path = /obj/item/field_contract_pad
	price_credits = 3600
	price_vouchers = 2

/datum/shop_sku/favor/freight_beacon
	item_path = /obj/item/freight_beacon
	price_credits = 2400
	price_vouchers = 1
