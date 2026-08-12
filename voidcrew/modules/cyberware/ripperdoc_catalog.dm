/**
 * # The Chop Shop: Splice, ripperdoc
 *
 * The Undertow's chrome parlor: a vendor stall (own stock, own voice, own
 * ledger) fronted by Splice, who sits behind the counter in the neon annex off
 * the Dregs. He sells cyberware and nothing else, the whole roster, tiered up
 * the voucher ladder, with the flagships always on the shelf so the chase is
 * plannable. Ammunition for the arm weapons is parlor-only: the return-visit
 * hook.
 *
 * Balance shape mirrors Vex's counter: credits buy the street and pro-utility
 * ware, vouchers gate everything that changes how you fight. Splice's intake
 * ledger buys back ONLY the ladder-base rungs, the street chrome a customer
 * outgrows, at half list, credits only, so climbing a slot ladder feels like
 * climbing and never becomes an arbitrage loop (you can't refund vouchers, and
 * a removed piece resold at 50% is always a loss).
 *
 * Splice is not the only source any more. The roster also rides the zone loot
 * tables (modules/loot/themes/) at the tier that matches what he charges for
 * it, the same two-channel shape the gun blueprints already have, shop as
 * the certainty channel and caches as the gamble. What stays parlor-only:
 * Legend Chrome (the chase is meant to be plannable, so it is always on the
 * shelf and never in a crate) and both ammunition SKUs (the return-visit
 * hook, a looted Ronin or Bunker Buster comes with what's loaded in it and
 * nothing more). The one piece that is NOT sold here at all is the Skyhook
 * wrist winch: it drops from expedition caches only.
 *
 * Catalog only: the organs live in ware_*.dm, the cradle in chrome_cradle.dm,
 * the NPC subtype in trade/trader_npc.dm, the parlor room on the Undertow map.
 */
/**
 * Splice's look: surgical scrubs and cap in wine-dark and black instead of
 * sterile blue (he operates, just not on the books), street leather over the
 * top, black no-bloodstain coroner latex, a diagnostic HUD because he scans
 * chrome rather than flesh, and a toolbelt because installing ware is shop
 * work. Purely cosmetic, the NPC snapshot only copies appearance.
 */
/datum/outfit/ripperdoc_splice
	name = "Ripperdoc"
	uniform = /obj/item/clothing/under/syndicate/scrubs
	suit = /obj/item/clothing/suit/jacket/leather
	gloves = /obj/item/clothing/gloves/latex/coroner
	shoes = /obj/item/clothing/shoes/jackboots
	head = /obj/item/clothing/head/utility/surgerycap/black
	glasses = /obj/item/clothing/glasses/hud/diagnostic
	neck = /obj/item/clothing/neck/stethoscope
	belt = /obj/item/storage/belt/utility/full
	mask = /obj/item/cigarette

/datum/outpost_shop/vendor/ripperdoc
	outpost_name = "\improper The Chop Shop"
	outpost_desc = "The Undertow's ripperdoc parlor. Chrome in, credits out, no paperwork."
	trader_name = "Splice"
	trader_outfit = /datum/outfit/ripperdoc_splice
	trader_gender = NEUTER
	trader_voice_pack = "goon.speak_2"
	trader_voice_pitch = 1.04
	categories = list(
		"Street Chrome",
		"Pro Chrome",
		"Military Chrome",
		"Legend Chrome",
		"Ammunition",
	)
	sku_types = list(
		// ---- Street Chrome (credits) ----
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
		// ---- Pro Chrome (mixed) ----
		/datum/shop_sku/ripperdoc/angler,
		/datum/shop_sku/ripperdoc/hemoglass,
		/datum/shop_sku/ripperdoc/hopper,
		/datum/shop_sku/ripperdoc/coolant,
		/datum/shop_sku/ripperdoc/icepick,
		/datum/shop_sku/ripperdoc/doppler,
		/datum/shop_sku/ripperdoc/graverobber,
		/datum/shop_sku/ripperdoc/deadeye,
		/datum/shop_sku/ripperdoc/slipwire,
		/datum/shop_sku/ripperdoc/dead_channel,
		/datum/shop_sku/ripperdoc/prospector,
		// ---- Military Chrome (vouchers) ----
		/datum/shop_sku/ripperdoc/atlas,
		/datum/shop_sku/ripperdoc/gorilla,
		/datum/shop_sku/ripperdoc/monowire,
		/datum/shop_sku/ripperdoc/ronin,
		/datum/shop_sku/ripperdoc/rigger,
		/datum/shop_sku/ripperdoc/slabskin,
		/datum/shop_sku/ripperdoc/mantis,
		/datum/shop_sku/ripperdoc/bunker_buster,
		/datum/shop_sku/ripperdoc/ghostskin,
		/datum/shop_sku/ripperdoc/lazarus,
		// ---- Legend Chrome (the chase, always listed) ----
		/datum/shop_sku/ripperdoc/governor_delete,
		/datum/shop_sku/ripperdoc/redline,
		/datum/shop_sku/ripperdoc/cascade,
		// ---- Ammunition (parlor-only reloads) ----
		/datum/shop_sku/ripperdoc/ronin_mag,
		/datum/shop_sku/ripperdoc/buster_rockets,
	)
	buyback_types = list(
		// The trade-in ladder: only the street rungs a customer outgrows.
		/datum/shop_buyback/ripperdoc/nightshade,
		/datum/shop_buyback/ripperdoc/shock_coils,
		/datum/shop_buyback/ripperdoc/second_wind,
		/datum/shop_buyback/ripperdoc/dermal_mesh,
		/datum/shop_buyback/ripperdoc/scrapper,
	)
	trader_lines = list(
		TRADER_LINE_GREETING = list(
			"Take a seat or take a look. The display cases are the menu.",
			"Fresh meat. I can fix that.",
			"You walked in on your own legs. We can do better.",
			"The chair's clean. The prices aren't.",
			"Welcome to the Chop Shop. Everything in here is legal somewhere.",
		),
		TRADER_LINE_SALE = list(
			"Sold. The chair's right there when you're ready.",
			"Good choice. It'll fit. I've done this before.",
			"Paid in full. If it sparks in the first hour, come back.",
			"That one's my own work. Treat it better than you treat your lungs.",
			"Done. No warranty card. I'm the warranty.",
		),
		TRADER_LINE_REFUSAL = list(
			"Your ledger's flagged. Chrome doesn't move to embargoed ships.",
			"Not today. Come back when your account stops embarrassing you.",
			"The invoice comes first. Always has.",
			"No credit. Not for you, not for anybody.",
		),
		TRADER_LINE_WARNING = list(
			"Careful. The turrets outside cost more than your arms are worth.",
			"Swing again and Vex bills your whole crew. I've watched it happen.",
			"This is the one room in the red zone with clean floors. Keep it that way.",
		),
		TRADER_LINE_AGGRESSION = list(
			"Wrong room to try that in.",
			"I fix bodies. The turrets outside keep me busy.",
			"Vex! One for the blacklist.",
		),
		TRADER_LINE_IDLE = list(
			"The Cascade Lattice in the case? Not a replica. Stop asking.",
			"Chrome doesn't get tired and it doesn't forget. That's the whole pitch.",
			"Sawbones does organs. I do upgrades. We don't compete. We share a supplier.",
			"The mirror's there for after. Everyone looks. Take your time.",
			"The bar watches installs through that window. Dram charges them for the seat.",
			"EMP will drop your chrome for a few seconds. It comes back. You might not. Plan around it.",
			"Capacity's not a suggestion. Your spine carries twenty points of load. After that, things brown out.",
			"Trade-ins get you half list on the street grades. Military chrome I don't buy back. Nobody sells it anyway.",
			"A courier once asked me to hide two kilos in his chest. The cavity's one slot. Read the tag.",
			"Borging shreds every implant in the body. Cloning leaves them on the corpse. Bring the corpse.",
			"I don't do discounts. I do work that doesn't need discounts.",
		),
		TRADER_LINE_RESTOCK = list(
			"Shipment's in. Fresh chrome on the shelves. Some of it's even unused.",
			"Restock. The crates don't say where from. That's the supplier's whole brand.",
			"Fresh stock. Come see what the lanes coughed up.",
		),
	)

/datum/shop_sku/ripperdoc
	stock_min = 1
	stock_max = 2

// =========================================================================
// STREET CHROME: credits
// =========================================================================

/datum/shop_sku/ripperdoc/chromatic_dermis
	category = "Street Chrome"
	desc = "Programmable circuit-tattoos under the skin. They flare when you take a hit, strobe when your chrome fires, and go dim when you're starving. Pure show, and worth every credit."
	item_path = /obj/item/organ/cyberimp/cyberware/chromatic_dermis
	price_credits = 400
	stock_min = 2
	stock_max = 4

/datum/shop_sku/ripperdoc/gastro
	category = "Street Chrome"
	desc = "A furnace where your stomach was. Eats anything that qualifies as food, and it's generous about qualifying. Immune to whatever the Dregs calls a special."
	item_path = /obj/item/organ/cyberimp/cyberware/gastro
	price_credits = 400
	stock_min = 2
	stock_max = 3

/datum/shop_sku/ripperdoc/shock_coils
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/shock_coils
	price_credits = 500
	stock_min = 2
	stock_max = 3

/datum/shop_sku/ripperdoc/nightshade
	category = "Street Chrome"
	desc = "Sees in the dark, and doesn't blind you when someone pops a flash. The printed thermals can't say that. Diagnostic bus is stock, so you'll read how much chrome the other guy is carrying, but never what."
	item_path = /obj/item/organ/eyes/robotic/cyberware/nightshade
	price_credits = 600
	stock_min = 1
	stock_max = 3

/datum/shop_sku/ripperdoc/scrapper
	category = "Street Chrome"
	name = "Scrapper's Knuckles (pair)"
	desc = "Reinforced knuckle plating for both hands. Hits people harder, hits machines and doors a lot harder. Sold as a set; install one side at a time."
	item_path = /obj/item/storage/case/cyberware/scrapper
	price_credits = 800
	stock_min = 1
	stock_max = 2

/datum/shop_sku/ripperdoc/gecko
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/gecko
	price_credits = 900
	stock_min = 1
	stock_max = 2

/datum/shop_sku/ripperdoc/second_wind
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/second_wind
	price_credits = 900
	stock_min = 1
	stock_max = 3

/datum/shop_sku/ripperdoc/cargo_cavity
	category = "Street Chrome"
	desc = "One sealed slot behind the sternum. Scanners skip it and pat-downs miss it. I don't ask what goes in."
	item_path = /obj/item/organ/cyberimp/cyberware/cargo_cavity
	price_credits = 1000
	stock_min = 1
	stock_max = 2

/datum/shop_sku/ripperdoc/rockjaw
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw
	price_credits = 1200
	stock_min = 1
	stock_max = 2

/datum/shop_sku/ripperdoc/fixers
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/fixers
	price_credits = 1800
	stock_min = 1
	stock_max = 2

/datum/shop_sku/ripperdoc/dermal_mesh
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/dermal_mesh
	price_credits = 2000
	stock_min = 1
	stock_max = 2

// =========================================================================
// PRO CHROME: mixed currency
// =========================================================================

/datum/shop_sku/ripperdoc/angler
	category = "Pro Chrome"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/angler
	price_credits = 2800

/datum/shop_sku/ripperdoc/hemoglass
	category = "Pro Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/hemoglass
	price_credits = 2800

/datum/shop_sku/ripperdoc/hopper
	category = "Pro Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/hopper
	price_credits = 3600

/datum/shop_sku/ripperdoc/coolant
	category = "Pro Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/coolant
	price_credits = 3600

/datum/shop_sku/ripperdoc/icepick
	category = "Pro Chrome"
	desc = "A data spike for the doors and turrets that won't open or stand down when asked. Outpost defenses ignore it, before you get ideas."
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/icepick
	price_vouchers = 1

/datum/shop_sku/ripperdoc/doppler
	category = "Pro Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/doppler
	price_vouchers = 1

/datum/shop_sku/ripperdoc/graverobber
	category = "Pro Chrome"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/graverobber
	price_vouchers = 1

/datum/shop_sku/ripperdoc/deadeye
	category = "Pro Chrome"
	item_path = /obj/item/organ/eyes/robotic/cyberware/deadeye
	price_vouchers = 2

/datum/shop_sku/ripperdoc/slipwire
	category = "Pro Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/slipwire
	price_vouchers = 2

/datum/shop_sku/ripperdoc/dead_channel
	category = "Pro Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/dead_channel
	price_vouchers = 2

/datum/shop_sku/ripperdoc/prospector
	category = "Pro Chrome"
	item_path = /obj/item/organ/eyes/robotic/cyberware/prospector
	price_vouchers = 2

// =========================================================================
// MILITARY CHROME: vouchers
// =========================================================================

/datum/shop_sku/ripperdoc/atlas
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/atlas
	price_vouchers = 2

/datum/shop_sku/ripperdoc/gorilla
	category = "Military Chrome"
	name = "Gorilla Arms (pair)"
	desc = "A pair of chrome forearms that punch through people, doors, and rock in that order. Sold cased; install one side at a time."
	item_path = /obj/item/cyberware_pair_case/gorilla_arms
	price_vouchers = 3

/datum/shop_sku/ripperdoc/monowire
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/monowire
	price_vouchers = 3

/datum/shop_sku/ripperdoc/ronin
	category = "Military Chrome"
	desc = "A submachine gun that folds into your forearm. Feeds a proprietary caliber only I sell. See the Ammunition shelf. Nobody is disarming you of it."
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin
	price_vouchers = 3

/datum/shop_sku/ripperdoc/rigger
	category = "Military Chrome"
	desc = "Skull jack. Opens your ship's helm wherever you're standing on it: engineering, a corridor, medbay with your hands full. It borrows a real console, so a hull with no helm left gives you nothing, and you're walking, not running, the whole time you're flying."
	item_path = /obj/item/organ/cyberimp/cyberware/rigger
	price_vouchers = 3

/datum/shop_sku/ripperdoc/slabskin
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/slabskin
	price_vouchers = 3

/datum/shop_sku/ripperdoc/mantis
	category = "Military Chrome"
	name = "Mantis Blades (pair)"
	desc = "A pair of folded blades where your forearms were. The lunge is the selling point; the reaction you get is free. Sold cased, install one side at a time."
	item_path = /obj/item/cyberware_pair_case/mantis_blades
	price_vouchers = 4

/datum/shop_sku/ripperdoc/bunker_buster
	category = "Military Chrome"
	desc = "A two-shot rocket pod built into the forearm. Reloads are parlor-only. See the Ammunition shelf. Shaped charge, so it won't open your hull. Or theirs. Just whoever's standing in it."
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/bunker_buster
	price_vouchers = 4

/datum/shop_sku/ripperdoc/ghostskin
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/ghostskin
	price_vouchers = 4

/datum/shop_sku/ripperdoc/lazarus
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/lazarus
	price_vouchers = 4

// =========================================================================
// LEGEND CHROME: the chase, always on the shelf
// =========================================================================

/datum/shop_sku/ripperdoc/governor_delete
	category = "Legend Chrome"
	desc = "Firmware surgery. Your capacity governor goes back in believing your spine can carry six more points of load, and it holds. Everything else on this shelf needs it."
	item_path = /obj/item/organ/cyberimp/cyberware/governor_delete
	price_vouchers = 5
	stock_min = 1
	stock_max = 1

/datum/shop_sku/ripperdoc/redline
	category = "Legend Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/redline
	price_vouchers = 6
	stock_min = 1
	stock_max = 1

/datum/shop_sku/ripperdoc/cascade
	category = "Legend Chrome"
	desc = "Sandevistan-class reflex lattice. Eight seconds where everyone else may as well be furniture, then a crash that puts you on the floor. The most expensive thing I've ever bolted into a spine."
	item_path = /obj/item/organ/cyberimp/cyberware/cascade
	price_vouchers = 8
	stock_min = 1
	stock_max = 1

// =========================================================================
// AMMUNITION: parlor-only reloads (the return-visit hook)
// =========================================================================

/datum/shop_sku/ripperdoc/ronin_mag
	category = "Ammunition"
	name = "Ronin magazine"
	desc = "Proprietary caliber for the Popup Ronin. Nowhere else stocks it, which is the point."
	item_path = /obj/item/ammo_box/magazine/cyberware_ronin
	price_credits = 250
	stock_min = 3
	stock_max = 6

/datum/shop_sku/ripperdoc/buster_rockets
	category = "Ammunition"
	name = "Bunker Buster rockets"
	desc = "A matched pair of shaped micro-rockets for the Bunker Buster pod. Handle them carefully. They're meant to go off at the far end."
	item_path = /obj/item/ammo_box/cyberware_buster_rockets
	price_credits = 600
	stock_min = 2
	stock_max = 4

// =========================================================================
// SPLICE'S INTAKE LEDGER: the trade-in ladder
// Half list, credits only, street rungs only. Removed chrome resold here is
// always a loss (you can't refund vouchers, and 50% never beats buying up the
// ladder), so this reads as "trade up" and never as an arbitrage loop.
// =========================================================================

/datum/shop_buyback/ripperdoc/nightshade
	name = "Nightshade Optics (pulled)"
	desc = "Old low-light eyes. Splice takes them off your hands when you move up to a targeting rig."
	category = "Trade-In"
	item_path = /obj/item/organ/eyes/robotic/cyberware/nightshade
	pay_credits = 300
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/ripperdoc/shock_coils
	name = "Shock Coils (pulled)"
	desc = "Reflex legs, lightly used. Trade-in credit toward the jump pistons."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/shock_coils
	pay_credits = 250
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/ripperdoc/second_wind
	name = "Second Wind Bladder (pulled)"
	desc = "A used air reserve. Worth half toward something with a longer bladder."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/second_wind
	pay_credits = 450
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/ripperdoc/dermal_mesh
	name = "Dermal Mesh (pulled)"
	desc = "Light plating you've outgrown. Splice recycles the weave toward the heavy slab."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/dermal_mesh
	pay_credits = 1000
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/scrapper
	name = "Scrapper's Knuckles (pulled)"
	desc = "One knuckle plate, pulled. He'll take either side toward the gorilla frames."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/scrapper
	match_subtypes = TRUE
	pay_credits = 200
	demand_min = 2
	demand_max = 4
