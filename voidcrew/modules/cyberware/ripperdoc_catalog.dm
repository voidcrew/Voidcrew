/**
 * # The Chop Shop: Splice, ripperdoc
 *
 * The Undertow's chrome parlor: a vendor stall (own stock, own voice, own
 * ledger) fronted by Splice, who sits behind the counter in the neon annex off
 * the Dregs. He sells utility chrome, limited melee implants and ammunition
 * for salvaged gun arms.
 *
 * Balance shape mirrors Vex's counter: credits buy the street and pro-utility
 * ware, vouchers gate everything that changes how you fight. Splice's intake
 * ledger buys back every piece he sells for credits (owner D7), at half list,
 * credits only, so climbing a slot ladder feels like climbing and never becomes
 * an arbitrage loop (voucher chrome bought at a counter is never bought back,
 * and a removed piece resold at 50% is always a loss). Found chrome with no
 * trade-in row (voucher-shelf pieces and loot-only ones) sells on four price
 * bands instead, which refuse anything bought at a counter.
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
		/datum/shop_sku/ripperdoc/ghostskin_street,
		/datum/shop_sku/ripperdoc/mantis_street,
		/datum/shop_sku/ripperdoc/governor_street,
		/datum/shop_sku/ripperdoc/redline_street,
		/datum/shop_sku/ripperdoc/cascade_street,
		// The phase 2 street models, street passives and optics.
		/datum/shop_sku/ripperdoc/spyglass,
		/datum/shop_sku/ripperdoc/cuffer_wrists,
		/datum/shop_sku/ripperdoc/medic_palms,
		/datum/shop_sku/ripperdoc/subvocal_mic,
		/datum/shop_sku/ripperdoc/fixers_street,
		/datum/shop_sku/ripperdoc/muffler_ear,
		/datum/shop_sku/ripperdoc/clotter_node,
		/datum/shop_sku/ripperdoc/assay_optics,
		/datum/shop_sku/ripperdoc/coolant_street,
		/datum/shop_sku/ripperdoc/frostline,
		/datum/shop_sku/ripperdoc/atlas_street,
		/datum/shop_sku/ripperdoc/doppler_street,
		/datum/shop_sku/ripperdoc/second_wind_deep,
		/datum/shop_sku/ripperdoc/slipwire_street,
		/datum/shop_sku/ripperdoc/hopper_street,
		/datum/shop_sku/ripperdoc/adrenal_pump,
		/datum/shop_sku/ripperdoc/gorilla_street,
		/datum/shop_sku/ripperdoc/rockjaw_deepcore,
		/datum/shop_sku/ripperdoc/ronin_holdout,
		/datum/shop_sku/ripperdoc/longsight,
		/datum/shop_sku/ripperdoc/hardweave,
		// ---- Pro Chrome (mixed) ----
		/datum/shop_sku/ripperdoc/angler,
		/datum/shop_sku/ripperdoc/hemoglass,
		/datum/shop_sku/ripperdoc/registry_uplink,
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
		/datum/shop_sku/ripperdoc/monowire_live,
		/datum/shop_sku/ripperdoc/rigger,
		/datum/shop_sku/ripperdoc/slabskin,
		/datum/shop_sku/ripperdoc/mantis,
		/datum/shop_sku/ripperdoc/mantis_scorch,
		/datum/shop_sku/ripperdoc/ghostskin,
		/datum/shop_sku/ripperdoc/lazarus,
		/datum/shop_sku/ripperdoc/governor_milspec,
		/datum/shop_sku/ripperdoc/redline_milspec,
		/datum/shop_sku/ripperdoc/cascade_milspec,
		/datum/shop_sku/ripperdoc/hopper_milspec,
		/datum/shop_sku/ripperdoc/slipwire_milspec,
		/datum/shop_sku/ripperdoc/deadeye_milspec,
		/datum/shop_sku/ripperdoc/lookout,
		// ---- Legend Chrome (the chase, always listed) ----
		/datum/shop_sku/ripperdoc/governor_delete,
		/datum/shop_sku/ripperdoc/redline,
		/datum/shop_sku/ripperdoc/cascade,
		// ---- Ammunition (parlor-only reloads) ----
		/datum/shop_sku/ripperdoc/ronin_mag,
		/datum/shop_sku/ripperdoc/buster_rockets,
	)
	buyback_types = list(
		// The trade-in ladder: every piece on the shelf priced in credits.
		/datum/shop_buyback/ripperdoc/nightshade,
		/datum/shop_buyback/ripperdoc/shock_coils,
		/datum/shop_buyback/ripperdoc/second_wind,
		/datum/shop_buyback/ripperdoc/dermal_mesh,
		/datum/shop_buyback/ripperdoc/scrapper,
		// The cyberware lines' street models (ware_line_*.dm).
		/datum/shop_buyback/ripperdoc/ghostskin_street,
		/datum/shop_buyback/ripperdoc/mantis_street,
		/datum/shop_buyback/ripperdoc/governor_street,
		/datum/shop_buyback/ripperdoc/redline_street,
		/datum/shop_buyback/ripperdoc/cascade_street,
		// The phase 2 street models, street passives and optics.
		/datum/shop_buyback/ripperdoc/spyglass,
		/datum/shop_buyback/ripperdoc/cuffer_wrists,
		/datum/shop_buyback/ripperdoc/medic_palms,
		/datum/shop_buyback/ripperdoc/subvocal_mic,
		/datum/shop_buyback/ripperdoc/fixers_street,
		/datum/shop_buyback/ripperdoc/muffler_ear,
		/datum/shop_buyback/ripperdoc/clotter_node,
		/datum/shop_buyback/ripperdoc/assay_optics,
		/datum/shop_buyback/ripperdoc/coolant_street,
		/datum/shop_buyback/ripperdoc/frostline,
		/datum/shop_buyback/ripperdoc/atlas_street,
		/datum/shop_buyback/ripperdoc/doppler_street,
		/datum/shop_buyback/ripperdoc/second_wind_deep,
		/datum/shop_buyback/ripperdoc/slipwire_street,
		/datum/shop_buyback/ripperdoc/hopper_street,
		/datum/shop_buyback/ripperdoc/adrenal_pump,
		/datum/shop_buyback/ripperdoc/gorilla_street,
		/datum/shop_buyback/ripperdoc/rockjaw_deepcore,
		/datum/shop_buyback/ripperdoc/ronin_holdout,
		/datum/shop_buyback/ripperdoc/longsight,
		/datum/shop_buyback/ripperdoc/hardweave,
		// The rest of the credit shelf (owner D7).
		/datum/shop_buyback/ripperdoc/hopper,
		/datum/shop_buyback/ripperdoc/coolant,
		/datum/shop_buyback/ripperdoc/fixers,
		/datum/shop_buyback/ripperdoc/rockjaw,
		/datum/shop_buyback/ripperdoc/gecko,
		/datum/shop_buyback/ripperdoc/hemoglass,
		/datum/shop_buyback/ripperdoc/angler,
		/datum/shop_buyback/ripperdoc/registry_uplink,
		/datum/shop_buyback/ripperdoc/cargo_cavity,
		/datum/shop_buyback/ripperdoc/gastro,
		/datum/shop_buyback/ripperdoc/chromatic_dermis,
		/datum/shop_buyback/burnt_chrome,
		// Found chrome that has no trade-in row, by price band.
		/datum/shop_buyback/found_chrome/fitted,
		/datum/shop_buyback/found_chrome/pro,
		/datum/shop_buyback/found_chrome/military,
		/datum/shop_buyback/found_chrome/legend,
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
			"Careful. The wardens outside cost more than your arms are worth.",
			"Swing again and Vex bills your whole crew. I've watched it happen.",
			"This is the one room in the red zone with clean floors. Keep it that way.",
		),
		TRADER_LINE_AGGRESSION = list(
			"Wrong room to try that in.",
			"I fix bodies. The wardens outside keep me busy.",
			"Vex! One for the blacklist.",
		),
		TRADER_LINE_IDLE = list(
			"The Cascade Lattice in the case? Not a replica. Stop asking.",
			"Chrome doesn't get tired and it doesn't forget. That's the whole pitch.",
			"Sawbones does organs. I do upgrades. We don't compete. We share a supplier.",
			"The mirror's there for after. Everyone looks. Take your time.",
			"The bar watches installs through that window. Dram charges them for the seat.",
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
	desc = "Programmable circuit tattoos beneath the skin."
	item_path = /obj/item/organ/cyberimp/cyberware/chromatic_dermis
	price_credits = 400
	stock_min = 2
	stock_max = 4

/datum/shop_sku/ripperdoc/gastro
	category = "Street Chrome"
	desc = "A reinforced synthetic stomach with an industrial lining."
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
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Street Chrome"
	desc = "A pair of chrome low-light optics."
	item_path = /obj/item/organ/eyes/robotic/cyberware/nightshade
	price_credits = 600
	stock_min = 1
	stock_max = 3

/datum/shop_sku/ripperdoc/scrapper
	category = "Street Chrome"
	name = "Scrapper's Knuckles (pair)"
	desc = "A cased pair of reinforced knuckle plates."
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
	desc = "A concealed storage cavity behind the sternum."
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
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/fixers
	price_credits = 1800
	stock_min = 1
	stock_max = 2

/datum/shop_sku/ripperdoc/dermal_mesh
	zone_permission = ZONE_PERMISSION_YELLOW
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
	price_credits = 1200

/datum/shop_sku/ripperdoc/hemoglass
	category = "Pro Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/hemoglass
	price_credits = 1200

/datum/shop_sku/ripperdoc/registry_uplink
	category = "Pro Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/registry_uplink
	price_credits = 1200

/datum/shop_sku/ripperdoc/hopper
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Pro Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/hopper
	price_credits = 3600

/datum/shop_sku/ripperdoc/coolant
	zone_permission = ZONE_PERMISSION_ADVANCED
	category = "Pro Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/coolant
	price_credits = 3600

/datum/shop_sku/ripperdoc/icepick
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Pro Chrome"
	desc = "A chrome forearm with a retractable data spike."
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/icepick
	price_vouchers = 1

/datum/shop_sku/ripperdoc/doppler
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Pro Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/doppler
	price_vouchers = 1

/datum/shop_sku/ripperdoc/graverobber
	category = "Pro Chrome"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/graverobber
	price_vouchers = 1

/datum/shop_sku/ripperdoc/deadeye
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Pro Chrome"
	item_path = /obj/item/organ/eyes/robotic/cyberware/deadeye
	price_vouchers = 2

/datum/shop_sku/ripperdoc/slipwire
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Pro Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/slipwire
	price_vouchers = 2

/datum/shop_sku/ripperdoc/dead_channel
	zone_permission = ZONE_PERMISSION_ADVANCED
	category = "Pro Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/dead_channel
	price_vouchers = 2

/datum/shop_sku/ripperdoc/prospector
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Pro Chrome"
	item_path = /obj/item/organ/eyes/robotic/cyberware/prospector
	price_vouchers = 1

// =========================================================================
// MILITARY CHROME: vouchers
// =========================================================================

/datum/shop_sku/ripperdoc/atlas
	zone_permission = ZONE_PERMISSION_ADVANCED
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/atlas
	price_vouchers = 2

/datum/shop_sku/ripperdoc/gorilla
	zone_permission = ZONE_PERMISSION_ADVANCED
	category = "Military Chrome"
	name = "Gorilla Arms (pair)"
	desc = "A cased pair of heavy chrome forearms."
	item_path = /obj/item/cyberware_pair_case/gorilla_arms
	price_vouchers = 3
	stock_min = 1
	stock_max = 1
	convoys_per_unit = 3
	fixed_price = TRUE
	contract_reward = FALSE

/datum/shop_sku/ripperdoc/monowire
	zone_permission = ZONE_PERMISSION_ELITE
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/monowire
	price_vouchers = 3
	stock_min = 1
	stock_max = 1
	convoys_per_unit = 3
	fixed_price = TRUE
	contract_reward = FALSE

/datum/shop_sku/ripperdoc/ronin
	zone_permission = ZONE_PERMISSION_ELITE
	category = "Military Chrome"
	desc = "A submachine gun folded into a chrome forearm."
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin
	price_vouchers = 3
	stock_min = 0
	stock_max = 0
	restock_interval = INFINITY
	fixed_price = TRUE
	contract_reward = FALSE

/datum/shop_sku/ripperdoc/rigger
	zone_permission = ZONE_PERMISSION_ADVANCED
	category = "Military Chrome"
	desc = "A skull jack with a ship's control interface."
	item_path = /obj/item/organ/cyberimp/cyberware/rigger
	price_vouchers = 3

/datum/shop_sku/ripperdoc/slabskin
	zone_permission = ZONE_PERMISSION_ELITE
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/slabskin
	price_vouchers = 3

/datum/shop_sku/ripperdoc/mantis
	zone_permission = ZONE_PERMISSION_ELITE
	category = "Military Chrome"
	name = "Mantis Blades (pair)"
	desc = "A cased pair of folding forearm blades."
	item_path = /obj/item/cyberware_pair_case/mantis_blades
	price_vouchers = 4
	stock_min = 1
	stock_max = 1
	convoys_per_unit = 3
	fixed_price = TRUE
	contract_reward = FALSE

/datum/shop_sku/ripperdoc/bunker_buster
	zone_permission = ZONE_PERMISSION_ELITE
	category = "Military Chrome"
	desc = "A rocket pod built into a chrome forearm."
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/bunker_buster
	price_vouchers = 4
	stock_min = 0
	stock_max = 0
	restock_interval = INFINITY
	fixed_price = TRUE
	contract_reward = FALSE

/datum/shop_sku/ripperdoc/ghostskin
	zone_permission = ZONE_PERMISSION_ELITE
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/ghostskin
	price_vouchers = 4

/datum/shop_sku/ripperdoc/lazarus
	zone_permission = ZONE_PERMISSION_ELITE
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/lazarus
	price_vouchers = 4

// =========================================================================
// LEGEND CHROME: the chase, always on the shelf
// =========================================================================

/datum/shop_sku/ripperdoc/governor_delete
	zone_permission = ZONE_PERMISSION_ELITE
	category = "Legend Chrome"
	desc = "A factory neural governor with its limiter firmware stripped out."
	item_path = /obj/item/organ/cyberimp/cyberware/governor_delete
	price_vouchers = 5
	stock_min = 1
	stock_max = 1

/datum/shop_sku/ripperdoc/redline
	zone_permission = ZONE_PERMISSION_ELITE
	category = "Legend Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/redline
	price_vouchers = 6
	stock_min = 1
	stock_max = 1

/datum/shop_sku/ripperdoc/cascade
	zone_permission = ZONE_PERMISSION_ELITE
	category = "Legend Chrome"
	desc = "A full-spine reflex lattice in a sealed surgical case."
	item_path = /obj/item/organ/cyberimp/cyberware/cascade
	price_vouchers = 8
	stock_min = 1
	stock_max = 1

// =========================================================================
// AMMUNITION: proprietary reloads (late research also offers fabrication)
// =========================================================================

/datum/shop_sku/ripperdoc/ronin_mag
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Ammunition"
	name = "Ronin magazine"
	desc = "Proprietary caliber for the Popup Ronin. Nowhere else stocks it, which is the point."
	item_path = /obj/item/ammo_box/magazine/cyberware_ronin
	price_credits = 250
	stock_min = 3
	stock_max = 6

/datum/shop_sku/ripperdoc/buster_rockets
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Ammunition"
	name = "Bunker Buster rockets"
	desc = "A matched pair of shaped micro-rockets for the Bunker Buster pod. Handle them carefully. They're meant to go off at the far end."
	item_path = /obj/item/ammo_box/cyberware_buster_rockets
	price_credits = 300
	stock_min = 2
	stock_max = 4

// =========================================================================
// SPLICE'S INTAKE LEDGER: the trade-in ladder
// Half list, credits only, credit-priced chrome only. Removed chrome resold here is
// always a loss (you can't refund vouchers, and 50% never beats buying up the
// ladder), so this reads as "trade up" and never as an arbitrage loop.
//
// The ripperdoc trade-in is the one ledger that takes chrome bought over a
// counter (owner decision, 2026-11-07): every other buyer and every export
// refuses anything carrying the trader-goods mark (trade/resale.dm). It holds
// because each entry pays half the lowest list price of the piece and a special
// takes at most 30% off, so a bought piece always sells back at a loss. The
// voidcrew_ripperdoc_resale unit test pins both halves of that.
// =========================================================================

/datum/shop_buyback/ripperdoc
	buys_shop_stock = TRUE

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
	desc = "Reflex legs, lightly used."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/shock_coils
	pay_credits = 250
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/ripperdoc/second_wind
	name = "Second Wind Bladder (pulled)"
	desc = "A used air reserve."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/second_wind
	// The Deep-lung is a subtype with its own, higher entry (ware_models_b.dm).
	match_subtypes = FALSE
	pay_credits = 450
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/ripperdoc/dermal_mesh
	name = "Dermal Mesh (pulled)"
	desc = "Light plating you've outgrown. Splice recycles the weave toward the heavy slab."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/dermal_mesh
	// The Hardweave is a subtype with its own, higher entry (ware_models_b.dm).
	match_subtypes = FALSE
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

// =========================================================================
// THE REST OF THE CREDIT SHELF (owner D7): every piece he sells for credits
// comes back at half list, credits only. Exact types, so a ladder rung above
// or below (Spring calves, Vaulter, Tinker's, Deepcore, Heat-sink) keeps its
// own entry or none. Ratchet's subtypes carry his wording.
// =========================================================================

/datum/shop_buyback/ripperdoc/hopper
	name = "Hopper piston calves (pulled)"
	desc = "Piston calves, still sprung."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/hopper
	match_subtypes = FALSE
	pay_credits = 1800
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/coolant
	name = "Coolant Loop lattice (pulled)"
	desc = "A drained coolant lattice."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/coolant
	match_subtypes = FALSE
	pay_credits = 1800
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/fixers
	name = "Fixer's Fingers (pulled)"
	desc = "A fingertip tool suite, pulled."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/fixers
	match_subtypes = FALSE
	pay_credits = 900
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/rockjaw
	name = "Rockjaw drill fist (pulled)"
	desc = "A drill fist with plenty of bit left."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw
	match_subtypes = FALSE
	pay_credits = 600
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/gecko
	name = "Gecko Grip palm pads (pulled)"
	desc = "Palm pads, a bit worn."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/gecko
	match_subtypes = FALSE
	pay_credits = 450
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/hemoglass
	name = "Hemoglass filter (pulled)"
	desc = "A blood filter, flushed."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/hemoglass
	match_subtypes = FALSE
	pay_credits = 600
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/angler
	name = "Harpoon Spool (pulled)"
	desc = "A wrist spool and its line."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/angler
	match_subtypes = FALSE
	pay_credits = 600
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/registry_uplink
	name = "Registry uplink (pulled)"
	desc = "A registry uplink, pulled."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/registry_uplink
	match_subtypes = FALSE
	pay_credits = 600
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/cargo_cavity
	name = "Cargo Cavity (pulled)"
	desc = "An empty rib compartment."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/cargo_cavity
	match_subtypes = FALSE
	pay_credits = 500
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/gastro
	name = "Gastro Reactor (pulled)"
	desc = "A used stomach liner."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/gastro
	match_subtypes = FALSE
	pay_credits = 200
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/ripperdoc/chromatic_dermis
	name = "Chromatic Dermis ink suite (pulled)"
	desc = "A sheet of circuit ink, peeled."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/chromatic_dermis
	match_subtypes = FALSE
	pay_credits = 200
	demand_min = 2
	demand_max = 3

/**
 * Dead chrome off a dead (or opened-up) human NPC (/obj/item/burnt_chrome, human_npc.dm). Scrap money only:
 * 50 cr is a fifth of the cheapest piece Splice sells for credits, so burning out bought chrome in a captive
 * to sell the husk is always a loss, and the round's demand caps it. Not a ripperdoc trade-in row: those
 * buy back shelf stock, and no shelf sells burnt chrome.
 */
/datum/shop_buyback/burnt_chrome
	name = "Burnt-out chrome"
	desc = "Dead implants. Splice strips them for the parts that didn't melt."
	category = "Scrap"
	item_path = /obj/item/burnt_chrome
	pay_credits = 50
	demand_min = 4
	demand_max = 8

/datum/shop_buyback/burnt_chrome/street_doc
	desc = "Dead implants. Ratchet melts them down for the metal."

// =========================================================================
// FOUND CHROME: the pieces no trade-in row takes
// Voucher-shelf chrome and loot-only chrome, out of caches or off the dead.
// Priced by band against the shelf: 1-voucher pieces pay 400 cr, 2-voucher
// pieces 900 cr (a paired arm counts as half its pair), 3-voucher and dearer
// pieces 1 voucher, the loot-only Piledriver 2. Each band names exact types,
// none of which any trade-in row matches, so no piece fits two rows.
//
// Not a /datum/shop_buyback/ripperdoc subtype on purpose: those take shop
// stock and pay credits only (voidcrew_ripperdoc_resale pins that). These
// refuse anything bought at a counter, so a voucher payout here only ever
// buys chrome nobody paid a shop for.
// =========================================================================

/datum/shop_buyback/found_chrome
	category = "Found Chrome"
	item_path = /obj/item/organ
	icon_override = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	/// Exact chrome types this band pays for
	var/list/wanted_chrome

/datum/shop_buyback/found_chrome/buyback_wanted_kind(obj/item/offered)
	return (offered.type in wanted_chrome) && !shop_buyback_inside_body(offered)

/datum/shop_buyback/found_chrome/matches(obj/item/offered)
	if(!..() || !(offered.type in wanted_chrome))
		return FALSE
	var/obj/item/organ/ware = offered
	return !(ware.organ_flags & ORGAN_FAILING)

/// The stock refusal keys off item_path, which here is every organ (buyback_listed.dm).
/datum/shop_buyback/found_chrome/get_denial_reason(mob/living/user)
	return buyback_listed_denial(src, user)

/datum/shop_buyback/found_chrome/fitted
	name = "fitted chrome"
	desc = "Icepicks, sonar, field optics, grave hooks. Clean them up and they sell again."
	icon_state_override = "icepick"
	wanted_chrome = list(
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/icepick,
		/obj/item/organ/cyberimp/cyberware/doppler,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/graverobber,
		/obj/item/organ/eyes/robotic/cyberware/prospector,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/skyhook,
	)
	pay_credits = 400
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/found_chrome/pro
	name = "pro chrome"
	desc = "Combat optics, reflex wiring, one arm of a matched pair. Splice knows who's shopping."
	icon_state_override = "mantis"
	wanted_chrome = list(
		/obj/item/organ/eyes/robotic/cyberware/deadeye,
		/obj/item/organ/cyberimp/cyberware/slipwire,
		/obj/item/organ/cyberimp/cyberware/dead_channel,
		/obj/item/organ/cyberimp/cyberware/atlas,
		/obj/item/organ/cyberimp/cyberware/gorilla_arms,
		/obj/item/organ/cyberimp/cyberware/gorilla_arms/left,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/scorch,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/scorch/left,
	)
	pay_credits = 900
	demand_min = 1
	demand_max = 3

/datum/shop_buyback/found_chrome/military
	name = "military chrome"
	desc = "Monowire, gun arms, slab plating, milspec builds. The big names too, if they still work."
	icon_state_override = "ronin"
	wanted_chrome = list(
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/monowire,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/monowire/live,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/bunker_buster,
		/obj/item/organ/cyberimp/cyberware/rigger,
		/obj/item/organ/cyberimp/cyberware/slabskin,
		/obj/item/organ/cyberimp/cyberware/ghostskin,
		/obj/item/organ/cyberimp/cyberware/lazarus,
		/obj/item/organ/eyes/robotic/cyberware/lookout,
		/obj/item/organ/eyes/robotic/cyberware/deadeye/milspec,
		/obj/item/organ/cyberimp/cyberware/slipwire/milspec,
		/obj/item/organ/cyberimp/cyberware/hopper/milspec,
		/obj/item/organ/cyberimp/cyberware/governor_delete/milspec,
		/obj/item/organ/cyberimp/cyberware/redline/milspec,
		/obj/item/organ/cyberimp/cyberware/cascade/milspec,
		/obj/item/organ/cyberimp/cyberware/governor_delete,
		/obj/item/organ/cyberimp/cyberware/redline,
		/obj/item/organ/cyberimp/cyberware/cascade,
	)
	pay_vouchers = 1
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/found_chrome/legend
	name = "Piledriver"
	desc = "Splice has never had one on the bench. He'd like to."
	icon_state_override = "piledriver"
	wanted_chrome = list(/obj/item/organ/cyberimp/cyberware/piledriver)
	pay_vouchers = 2
	demand_min = 1
	demand_max = 1
