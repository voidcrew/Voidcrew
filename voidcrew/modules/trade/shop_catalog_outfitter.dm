/**
 * # Quartermain Depot — the yellow-zone outfitter
 *
 * Mid-tier arms, armor and fieldcraft for the contested lanes. Mostly credits;
 * the good hardware wants a voucher on top. Also the galaxy's most reliable
 * source of loose firing pins.
 * Shop machinery lives in shop.dm; this file is pure catalog.
 */
/datum/outpost_shop/outfitter
	outpost_name = "\improper Quartermain Depot"
	outpost_desc = "A fortified outfitter's depot serving the contested lanes. Armored like it expects its customers to be the problem."
	trader_name = "Sarge"
	trader_outfit = /datum/outfit/job/hos
	trader_gender = FEMALE
	trader_voice_pack = "goon.speak_1"
	trader_voice_pitch = 0.85
	categories = list(
		"Armor",
		"Firearms & Ammo",
		"Ship Ordnance",
		"Security Gear",
		"Combat Medical",
		"Utility",
		"Colonial Registry",
		"Charts & Special Orders",
		"Barter Deals",
	)
	sku_types = list(
		// Armor
		/datum/shop_sku/outfitter/armor_vest,
		/datum/shop_sku/outfitter/helmet,
		/datum/shop_sku/outfitter/riot_helmet,
		/datum/shop_sku/outfitter/bulletproof_vest,
		// Firearms & Ammo
		/datum/shop_sku/outfitter/disabler,
		/datum/shop_sku/outfitter/energy_gun,
		/datum/shop_sku/outfitter/laser_gun,
		/datum/shop_sku/outfitter/double_barrel,
		/datum/shop_sku/outfitter/rubbershot,
		/datum/shop_sku/outfitter/lethalshot,
		/datum/shop_sku/outfitter/boltaction,
		/datum/shop_sku/outfitter/rifle_clip,
		/datum/shop_sku/outfitter/firing_pin,
		// Ship Ordnance
		/datum/shop_sku/outfitter/missile_tracking,
		/datum/shop_sku/outfitter/warhead_standard,
		/datum/shop_sku/outfitter/missile_light,
		// Security Gear
		/datum/shop_sku/outfitter/handcuffs,
		/datum/shop_sku/outfitter/zipties,
		/datum/shop_sku/outfitter/seclite,
		/datum/shop_sku/outfitter/flash,
		/datum/shop_sku/outfitter/bola,
		/datum/shop_sku/outfitter/sechud,
		/datum/shop_sku/outfitter/security_belt,
		/datum/shop_sku/outfitter/pepper_spray,
		/datum/shop_sku/outfitter/riot_shield,
		/datum/shop_sku/outfitter/barrier_grenade,
		// Combat Medical
		/datum/shop_sku/outfitter/brute_kit,
		/datum/shop_sku/outfitter/advanced_medkit,
		/datum/shop_sku/outfitter/stimpack,
		/datum/shop_sku/outfitter/suture,
		// Utility
		/datum/shop_sku/outfitter/gas_mask,
		/datum/shop_sku/outfitter/jaws,
		/datum/shop_sku/outfitter/magboots,
		/datum/shop_sku/outfitter/binoculars,
		/datum/shop_sku/outfitter/mod_flashlight,
		/datum/shop_sku/outfitter/mod_tether,
		// Colonial Registry
		/datum/shop_sku/outpost_deed,
		// Charts & Special Orders
		/datum/shop_sku/outfitter/star_chart,
		/datum/shop_sku/rumor/outfitter,
		/datum/shop_sku/ruin_chart/biolab,
		/datum/shop_sku/ruin_chart/foundry,
		/datum/shop_sku/outfitter/smg_blueprint,
		/datum/shop_sku/outfitter/wt550_blueprint,
		/datum/shop_sku/outfitter/carbine_blueprint,
		// Barter
		/datum/shop_sku/barter/plasteel_for_shield,
	)
	rotating_pool = list(
		/datum/shop_sku/outfitter/rotating/riot_suit,
		/datum/shop_sku/outfitter/rotating/telescopic_baton,
		/datum/shop_sku/outfitter/rotating/tackler_gloves,
		/datum/shop_sku/outfitter/rotating/flashbang,
		/datum/shop_sku/outfitter/rotating/frag_grenade,
		/datum/shop_sku/outfitter/rotating/missile_standard,
		/datum/shop_sku/outfitter/rotating/warhead_heavy,
	)
	rare_pool = list(
		/datum/shop_sku/outfitter/rare/ablative_vest,
		/datum/shop_sku/outfitter/rare/compact_defib,
		/datum/shop_sku/outfitter/rare/ion_rifle,
		/datum/shop_sku/outfitter/rare/missile_heavy,
	)
	// Sarge buys serviceable salvage — arms and armor off whoever stopped
	// needing them — plus field materials off planet megafauna
	buyback_types = list(
		/datum/shop_buyback/outfitter/salvage_ballistics,
		/datum/shop_buyback/outfitter/salvage_energy,
		/datum/shop_buyback/outfitter/salvage_armor,
		/datum/shop_buyback/outfitter/goliath_plates,
		/datum/shop_buyback/outfitter/sinew,
	)
	// Depot resupply runs: industrial quantities, decent free kit
	mission_requests = list(
		list("type" = /obj/item/stack/sheet/plasteel, "name" = "plasteel sheets", "amount" = 10, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/stack/ore/titanium, "name" = "titanium ore", "amount" = 12, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/stack/ore/silver, "name" = "silver ore", "amount" = 10, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/stack/cable_coil, "name" = "cable coil", "amount" = 60, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("type" = /obj/item/stack/sheet/animalhide/goliath_hide, "name" = "goliath hide plates", "amount" = 4, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = /obj/item/stack/sheet/sinew, "name" = "beast sinew", "amount" = 4, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
	)
	// The armory back room: hard contracts only, never sold
	exclusive_rewards = list(
		/obj/item/storage/belt/military/assault,
		/obj/item/shield/riot/tele,
		/obj/item/clothing/gloves/tackler/combat,
		/obj/item/circuitboard/machine/ship_combat/missile_launcher,
	)
	trader_lines = list(
		TRADER_LINE_GREETING = list(
			"Quartermain Depot. State your needs, keep your sidearm holstered.",
			"Welcome in. Everything's rated for the yellow lanes and worse.",
			"Depot's open. Ammunition's to the left, regrets are on you.",
			"You look under-armored. Good news: fixable. Bad news: not free.",
		),
		TRADER_LINE_SALE = list(
			"Good kit. Try to bring it back in one piece. Or don't, repeat business is fine too.",
			"Sold. Inspect it before you need it, not after.",
			"Money's cleared. Zero your sights before you trust them.",
			"That'll hold. Longer than the last owner did, anyway.",
		),
		TRADER_LINE_REFUSAL = list(
			"You're flagged. No sales until your embargo clears.",
			"Depot policy: no service to hostiles. Take it up with your captain.",
			"I've got a list of ships I don't serve. Congratulations on making it.",
		),
		TRADER_LINE_WARNING = list(
			"Hands off the merchandise, hostile. Next one arms the grid.",
			"That's a warning shot's worth of patience. I have exactly one to spare.",
			"Test the armor on your own time. Not on my fixtures.",
		),
		TRADER_LINE_AGGRESSION = list(
			"Weapons free. You were warned by the sign. There are several signs.",
			"That armor you're wearing? I sell the thing that beats it. To my turrets.",
			"Grid's hot. For what it's worth, the paperwork on you was already done.",
		),
		TRADER_LINE_IDLE = list(
			"Inventory rotates when the convoys make it through. When.",
			"The yellow lanes eat the unprepared. Be a customer, not a statistic.",
			"Goliath plate lines the good vests. Bring me plates, walk out richer.",
			"Firing pins. Everyone forgets the firing pins. Don't be everyone.",
			"The schematics I stock are legal. The fun ones are two zones that way.",
		),
		TRADER_LINE_RESTOCK = list(
			"Convoy made it through. Shelves are full — for now.",
			"Resupply's in. Escort took casualties, so mind the prices and say thanks.",
			"Fresh crates on the floor. New rotation's up on the board.",
		),
	)

/datum/shop_sku/outfitter
	stock_min = 2
	stock_max = 4

// ===== ARMOR =====

/datum/shop_sku/outfitter/armor_vest
	category = "Armor"
	item_path = /obj/item/clothing/suit/armor/vest
	price_credits = 600

/datum/shop_sku/outfitter/helmet
	category = "Armor"
	item_path = /obj/item/clothing/head/helmet
	price_credits = 400

/datum/shop_sku/outfitter/riot_helmet
	category = "Armor"
	item_path = /obj/item/clothing/head/helmet/toggleable/riot
	price_credits = 600
	stock_min = 1
	stock_max = 3

/datum/shop_sku/outfitter/bulletproof_vest
	category = "Armor"
	item_path = /obj/item/clothing/suit/armor/bulletproof
	price_credits = 900
	stock_min = 1
	stock_max = 2

// ===== FIREARMS & AMMO =====

/datum/shop_sku/outfitter/disabler
	category = "Firearms & Ammo"
	item_path = /obj/item/gun/energy/disabler
	price_credits = 800
	stock_min = 1
	stock_max = 3

/datum/shop_sku/outfitter/energy_gun
	category = "Firearms & Ammo"
	item_path = /obj/item/gun/energy/e_gun
	price_vouchers = 1
	price_credits = 800
	stock_min = 1
	stock_max = 2

/datum/shop_sku/outfitter/laser_gun
	category = "Firearms & Ammo"
	item_path = /obj/item/gun/energy/laser
	price_credits = 1000
	stock_min = 1
	stock_max = 2

/datum/shop_sku/outfitter/double_barrel
	category = "Firearms & Ammo"
	item_path = /obj/item/gun/ballistic/shotgun/doublebarrel
	price_credits = 700
	stock_min = 1
	stock_max = 2

/datum/shop_sku/outfitter/rubbershot
	category = "Firearms & Ammo"
	item_path = /obj/item/storage/box/rubbershot
	price_credits = 200
	stock_min = 3
	stock_max = 6

/datum/shop_sku/outfitter/lethalshot
	category = "Firearms & Ammo"
	item_path = /obj/item/storage/box/lethalshot
	price_credits = 400
	stock_min = 2
	stock_max = 4

/datum/shop_sku/outfitter/boltaction
	category = "Firearms & Ammo"
	item_path = /obj/item/gun/ballistic/rifle/boltaction
	price_credits = 900
	stock_min = 1
	stock_max = 2

/datum/shop_sku/outfitter/rifle_clip
	category = "Firearms & Ammo"
	item_path = /obj/item/ammo_box/strilka310
	price_credits = 150
	stock_min = 3
	stock_max = 6

// The quiet backbone of the blueprint economy: no pin, no gun
/datum/shop_sku/outfitter/firing_pin
	category = "Firearms & Ammo"
	item_path = /obj/item/firing_pin
	price_credits = 300
	stock_min = 3
	stock_max = 5

// ===== SHIP ORDNANCE =====
// Ship-to-ship missiles and the parts to feed a launcher. The armed missiles
// dispense ready to drag onto a launcher; the components restock a workshop.

/datum/shop_sku/outfitter/missile_tracking
	category = "Ship Ordnance"
	item_path = /obj/item/electronics/ship_missile_tracking
	price_credits = 250
	stock_min = 2
	stock_max = 4

/datum/shop_sku/outfitter/warhead_standard
	category = "Ship Ordnance"
	item_path = /obj/item/bombcore/missile
	price_credits = 500
	stock_min = 1
	stock_max = 3

/datum/shop_sku/outfitter/missile_light
	category = "Ship Ordnance"
	name = "light missile (armed)"
	desc = "A ready-to-fire light missile. Drag it straight onto a ship launcher — no assembly, no fuss."
	item_path = /obj/structure/ship_missile/armed/light
	price_vouchers = 1
	price_credits = 400
	stock_min = 1
	stock_max = 2

// ===== SECURITY GEAR =====

/datum/shop_sku/outfitter/handcuffs
	category = "Security Gear"
	item_path = /obj/item/restraints/handcuffs
	price_credits = 200

/datum/shop_sku/outfitter/zipties
	category = "Security Gear"
	item_path = /obj/item/restraints/handcuffs/cable/zipties
	price_credits = 100
	stock_min = 4
	stock_max = 8

/datum/shop_sku/outfitter/seclite
	category = "Security Gear"
	item_path = /obj/item/flashlight/seclite
	price_credits = 150

/datum/shop_sku/outfitter/flash
	category = "Security Gear"
	item_path = /obj/item/assembly/flash/handheld
	price_credits = 250

/datum/shop_sku/outfitter/bola
	category = "Security Gear"
	item_path = /obj/item/restraints/legcuffs/bola
	price_credits = 200

/datum/shop_sku/outfitter/sechud
	category = "Security Gear"
	item_path = /obj/item/clothing/glasses/hud/security/sunglasses
	price_credits = 500
	stock_min = 1
	stock_max = 3

/datum/shop_sku/outfitter/security_belt
	category = "Security Gear"
	item_path = /obj/item/storage/belt/security/full
	price_credits = 900
	stock_min = 1
	stock_max = 1

/datum/shop_sku/outfitter/pepper_spray
	category = "Security Gear"
	item_path = /obj/item/reagent_containers/spray/pepper
	price_credits = 150

/datum/shop_sku/outfitter/riot_shield
	category = "Security Gear"
	item_path = /obj/item/shield/riot
	price_credits = 800
	stock_min = 1
	stock_max = 2

/datum/shop_sku/outfitter/barrier_grenade
	category = "Security Gear"
	item_path = /obj/item/grenade/barrier
	price_credits = 350
	stock_min = 2
	stock_max = 4

// ===== COMBAT MEDICAL =====

/datum/shop_sku/outfitter/brute_kit
	category = "Combat Medical"
	item_path = /obj/item/storage/medkit/brute
	price_credits = 400

/datum/shop_sku/outfitter/advanced_medkit
	category = "Combat Medical"
	item_path = /obj/item/storage/medkit/advanced
	price_credits = 800
	stock_min = 1
	stock_max = 2

/datum/shop_sku/outfitter/stimpack
	category = "Combat Medical"
	item_path = /obj/item/reagent_containers/hypospray/medipen/stimpack
	price_credits = 400
	stock_min = 2
	stock_max = 4

/datum/shop_sku/outfitter/suture
	category = "Combat Medical"
	item_path = /obj/item/stack/medical/suture
	price_credits = 120
	stock_min = 3
	stock_max = 6

// ===== UTILITY =====

/datum/shop_sku/outfitter/gas_mask
	category = "Utility"
	item_path = /obj/item/clothing/mask/gas
	price_credits = 150

/datum/shop_sku/outfitter/jaws
	category = "Utility"
	name = "jaws of life"
	item_path = /obj/item/crowbar/power
	price_vouchers = 1
	price_credits = 500
	stock_min = 1
	stock_max = 2

/datum/shop_sku/outfitter/magboots
	category = "Utility"
	item_path = /obj/item/clothing/shoes/magboots
	price_credits = 800
	stock_min = 1
	stock_max = 2

/datum/shop_sku/outfitter/binoculars
	category = "Utility"
	item_path = /obj/item/binoculars
	price_credits = 200

/datum/shop_sku/outfitter/mod_flashlight
	category = "Utility"
	item_path = /obj/item/mod/module/flashlight
	price_credits = 300

/datum/shop_sku/outfitter/mod_tether
	category = "Utility"
	item_path = /obj/item/mod/module/tether
	price_credits = 500
	stock_min = 1
	stock_max = 2

// ===== CHARTS & SPECIAL ORDERS =====

// Charts the contested lanes — discovery certainty for the middle ring
/datum/shop_sku/outfitter/star_chart
	category = "Charts & Special Orders"
	item_path = /obj/item/disk/star_chart/yellow
	price_credits = 400
	stock_min = 1
	stock_max = 2

// Sarge's tips are convoy scuttlebutt — yellow-band signals
/datum/shop_sku/rumor/outfitter
	name = "convoy scuttlebutt"
	desc = "The convoy crews see everything on the contested lanes and shut up about none of it. One uncharted yellow-band signal, marked on your helm."
	category = "Charts & Special Orders"
	price_credits = 300

// Sarge's special orders name a specific prize: each chart is one rare ruin
// that exists nowhere until somebody buys the tip and reveals it from their
// helm. One buyer per rumor, ever — once sold, the trail is cold at every
// outpost.
/datum/shop_sku/ruin_chart/biolab
	name = "special order: 'Eventide'"
	desc = "Sarge slides over a requisition form for coordinates. An off-ledger NT xenobiology annex that stopped filing reports mid-shift — specimens loose, extract vault never emptied. Uploaded sealed to your helm; reveal it when your crew is kitted for what's inside."
	category = "Charts & Special Orders"
	price_vouchers = 2
	price_credits = 500
	spawn_zone = ZONE_YELLOW
	ruin_template_path = /datum/map_template/ruin/space/rare/biolab
	rumor_name = "Sarge's special order: Eventide"
	rumor_desc = "A xenobiology annex drifting dark on the contested lanes. Containment failed from the inside. The extract vault is still sealed, and still full."

/datum/shop_sku/ruin_chart/foundry
	name = "special order: 'Helios-Betna'"
	desc = "Sarge slides over a requisition form for coordinates. An automated foundry that never heard its owners defaulted — the line still runs, the custodians still patrol, and the finished-goods vault has never shipped a crate. Uploaded sealed to your helm; reveal it when your crew is ready to fight machines for their paychecks."
	category = "Charts & Special Orders"
	price_vouchers = 3
	ruin_template_path = /datum/map_template/ruin/space/rare/foundry
	rumor_name = "Sarge's special order: Helios-Betna"
	rumor_desc = "A dead company's foundry running blind in the red band. The custodians hold the line, and the vault holds decades of certified alloy nobody ever came to collect."

// Weapon schematics -- yellow-tier guns, carried or imprinted, crafted beside a bench.
/datum/shop_sku/outfitter/smg_blueprint
	category = "Charts & Special Orders"
	item_path = /obj/item/blueprint/gun/c20r
	price_vouchers = 3
	stock_min = 1
	stock_max = 1

/datum/shop_sku/outfitter/wt550_blueprint
	category = "Charts & Special Orders"
	item_path = /obj/item/blueprint/gun/wt550
	price_vouchers = 3
	stock_min = 1
	stock_max = 1

/datum/shop_sku/outfitter/carbine_blueprint
	category = "Charts & Special Orders"
	item_path = /obj/item/blueprint/gun/laser_carbine
	price_vouchers = 2
	price_credits = 500
	stock_min = 1
	stock_max = 1

// ===== ROTATING SHELF =====

/datum/shop_sku/outfitter/rotating/riot_suit
	category = "Armor"
	item_path = /obj/item/clothing/suit/armor/riot
	price_credits = 1500

/datum/shop_sku/outfitter/rotating/telescopic_baton
	category = "Security Gear"
	item_path = /obj/item/melee/baton/telescopic
	price_credits = 800

/datum/shop_sku/outfitter/rotating/tackler_gloves
	category = "Security Gear"
	item_path = /obj/item/clothing/gloves/tackler
	price_credits = 400

/datum/shop_sku/outfitter/rotating/flashbang
	category = "Security Gear"
	item_path = /obj/item/grenade/flashbang
	price_credits = 300

/datum/shop_sku/outfitter/rotating/frag_grenade
	category = "Security Gear"
	item_path = /obj/item/grenade/frag
	price_vouchers = 1
	price_credits = 400

/datum/shop_sku/outfitter/rotating/missile_standard
	category = "Ship Ordnance"
	name = "standard missile (armed)"
	desc = "A ready-to-fire standard missile. Solid ship-to-ship punch, straight onto the launcher."
	item_path = /obj/structure/ship_missile/armed/standard
	price_vouchers = 1
	price_credits = 800

/datum/shop_sku/outfitter/rotating/warhead_heavy
	category = "Ship Ordnance"
	item_path = /obj/item/bombcore/missile/heavy
	price_vouchers = 1
	price_credits = 700

// ===== RARE SHOWCASE =====

/datum/shop_sku/outfitter/rare/ablative_vest
	category = "Armor"
	item_path = /obj/item/clothing/suit/armor/laserproof
	price_vouchers = 1
	price_credits = 1200

/datum/shop_sku/outfitter/rare/compact_defib
	category = "Combat Medical"
	item_path = /obj/item/defibrillator/compact
	price_credits = 2000

/datum/shop_sku/outfitter/rare/ion_rifle
	category = "Firearms & Ammo"
	item_path = /obj/item/gun/energy/ionrifle
	price_vouchers = 2
	price_credits = 1000

/datum/shop_sku/outfitter/rare/missile_heavy
	category = "Ship Ordnance"
	name = "heavy missile (armed)"
	desc = "A ready-to-fire heavy missile — devastating, and priced like it. Drag it onto a launcher and pity whatever's downrange."
	item_path = /obj/structure/ship_missile/armed/heavy
	price_vouchers = 2
	price_credits = 800

// ===== SARGE'S SALVAGE COUNTER (buybacks) =====
// Credits only; guns and armor can come off a lathe, so they never pay vouchers.

/datum/shop_buyback/outfitter/salvage_ballistics
	name = "ballistic firearm (salvage)"
	desc = "Working ballistics, any pattern. Sarge strips them for parts or resells to the next crew through."
	category = "Salvage"
	item_path = /obj/item/gun/ballistic
	pay_credits = 200
	demand_min = 3
	demand_max = 6

/datum/shop_buyback/outfitter/salvage_energy
	name = "energy weapon (salvage)"
	desc = "Cell-fed weaponry in working order. Dead cells accepted grudgingly."
	category = "Salvage"
	item_path = /obj/item/gun/energy
	pay_credits = 350
	demand_min = 2
	demand_max = 4

/datum/shop_buyback/outfitter/salvage_armor
	name = "armored suit (salvage)"
	desc = "Body armor with mileage on it. Holes are a pricing conversation, not a dealbreaker."
	category = "Salvage"
	item_path = /obj/item/clothing/suit/armor
	pay_credits = 150
	demand_min = 3
	demand_max = 6

// Planet megafauna materials — armor-grade feedstock the depot can't lathe
/datum/shop_buyback/outfitter/goliath_plates
	name = "goliath hide plates"
	desc = "Tentacle-scarred plate off a live goliath. Sarge lines the good vests with it and asks no questions about the tentacle marks on YOU."
	category = "Field Materials"
	item_path = /obj/item/stack/sheet/animalhide/goliath_hide
	amount = 2
	pay_credits = 250
	demand_min = 4
	demand_max = 6

/datum/shop_buyback/outfitter/sinew
	name = "beast sinew"
	desc = "Watcher or wolf sinew, cured for suit stitching. The depot's repair benches run through spools of it."
	category = "Field Materials"
	item_path = /obj/item/stack/sheet/sinew
	amount = 2
	pay_credits = 200
	demand_min = 4
	demand_max = 6

// Barter: the depot always needs hull stock
/datum/shop_sku/barter/plasteel_for_shield
	name = "riot shield (plasteel trade)"
	item_path = /obj/item/shield/riot
	barter_path = /obj/item/stack/sheet/plasteel
	barter_amount = 10
	stock_min = 1
	stock_max = 2
