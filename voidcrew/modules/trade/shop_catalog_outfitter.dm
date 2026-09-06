/**
 * # Quartermain Depot: the yellow-zone outfitter
 *
 * Mid-tier arms, armor and fieldcraft for the contested lanes. Mostly credits;
 * the good hardware wants a voucher on top. Also the galaxy's most reliable
 * source of loose firing pins.
 * Shop machinery lives in shop.dm; this file is pure catalog.
 *
 * Boards offer a cash route before a crew assembles and researches its own lab.
 * Cargo and fabrication provide cheaper bulk supply once their prerequisites exist.
 * Charts use the shared galaxy-wide pool in shop_catalog_charts.dm.
 */

/**
 * Sarge: a quartermaster first and a soldier second, in that order. The brown
 * QM shirt and the black gloves are the counter job; the militia beret and the
 * canvas field jacket over them are where the nickname came from. No sidearm.
 * She sells the guns, she doesn't wave them at customers.
 */
/datum/outfit/quartermain_sarge
	name = "Depot quartermaster"
	uniform = /obj/item/clothing/under/rank/cargo/qm
	suit = /obj/item/clothing/suit/jacket/miljacket
	head = /obj/item/clothing/head/beret/militia
	gloves = /obj/item/clothing/gloves/color/black
	shoes = /obj/item/clothing/shoes/jackboots

/datum/outpost_shop/outfitter
	outpost_name = "\improper Quartermain Depot"
	outpost_desc = "A fortified outfitter's depot serving the contested lanes. Armored like it expects its customers to be the problem."
	trader_name = "Sarge"
	trader_outfit = /datum/outfit/quartermain_sarge
	trader_gender = FEMALE
	trader_voice_pack = "goon.speak_1"
	trader_voice_pitch = 0.85
	categories = list(
		"Armor",
		"Firearms & Ammo",
		"Ship Systems",
		"Ship Ordnance",
		"Security Gear",
		"Combat Medical",
		"Mess Tin",
		"Utility",
		"Hull Stock",
		"Fuel & Gas",
		"Colonial Registry",
		"Intel & Charts",
		"Blueprints",
		"Barter Deals",
		"Back Room",
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
		/datum/shop_sku/outfitter/smg_mag,
		/datum/shop_sku/outfitter/wt550_mag,
		/datum/shop_sku/outfitter/firing_pin,
		// Ship Systems
		/datum/shop_sku/outfitter/engine_plasma,
		/datum/shop_sku/outfitter/engine_expulsion,
		/datum/shop_sku/outfitter/engine_ion,
		/datum/shop_sku/outfitter/engine_oil,
		/datum/shop_sku/outfitter/engine_heater,
		/datum/shop_sku/outfitter/laser_turret_board,
		// Ship Ordnance
		/datum/shop_sku/outfitter/missile_tracking,
		/datum/shop_sku/outfitter/warhead_standard,
		/datum/shop_sku/outfitter/missile_light,
		// Security Gear
		/datum/shop_sku/outfitter/seclite,
		/datum/shop_sku/outfitter/flash,
		/datum/shop_sku/outfitter/bola,
		/datum/shop_sku/outfitter/security_belt,
		/datum/shop_sku/outfitter/pepper_spray,
		/datum/shop_sku/outfitter/riot_shield,
		/datum/shop_sku/outfitter/barrier_grenade,
		// Combat Medical
		/datum/shop_sku/outfitter/brute_kit,
		/datum/shop_sku/outfitter/advanced_medkit,
		/datum/shop_sku/outfitter/stimpack,
		/datum/shop_sku/outfitter/suture,
		/datum/shop_sku/outfitter/health_hud,
		// Mess Tin
		/datum/shop_sku/outfitter/rations,
		/datum/shop_sku/outfitter/energy_bar,
		/datum/shop_sku/outfitter/canned_peaches,
		/datum/shop_sku/outfitter/hot_sauce,
		// Utility
		/datum/shop_sku/outfitter/gas_mask,
		/datum/shop_sku/outfitter/jaws,
		/datum/shop_sku/outfitter/magboots,
		// Hull Stock
		/datum/shop_sku/outfitter/plasteel_stock,
		/datum/shop_sku/outfitter/iron_stock,
		/datum/shop_sku/outfitter/glass_stock,
		// Fuel & Gas
		/datum/shop_sku/outfitter/plasma_canister,
		/datum/shop_sku/outfitter/welding_fuel,
		/datum/shop_sku/outfitter/oxygen_tank,
		// Colonial Registry
		/datum/shop_sku/outpost_deed,
		// Intel & Charts: the dealt chart shelf adds to this from chart_pool
		/datum/shop_sku/rumor,
		// Blueprints
		/datum/shop_sku/outfitter/smg_blueprint,
		/datum/shop_sku/outfitter/wt550_blueprint,
		/datum/shop_sku/outfitter/carbine_blueprint,
		// Barter
		/datum/shop_sku/barter/plasteel_for_shield,
	)
	// Charts are a mix now. Any station can stock any zone's chart. The shelf
	// is dealt from this pool each round; ruin charts never repeat galaxy-wide.
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
	// The back room: Trusted-standing uniques, per-crew supply (trader_favor.dm)
	favor_sku_types = list(
		/datum/shop_sku/favor/skunkworks_cell,
		/datum/shop_sku/favor/fitter_gauntlets,
		/datum/shop_sku/favor/maneuvering_harness,
	)
	// Sarge buys serviceable salvage, arms and armor off whoever stopped
	// needing them, plus field materials off planet megafauna and crust
	buyback_types = list(
		/datum/shop_buyback/outfitter/salvage_armor,
		/datum/shop_buyback/outfitter/goliath_plates,
		/datum/shop_buyback/outfitter/sinew,
		/datum/shop_buyback/outfitter/glacial_core,
	)
	// Depot resupply runs: industrial quantities, decent free kit
	mission_requests = list(
		list("type" = /obj/item/stack/sheet/plasteel, "name" = "plasteel sheets", "amount" = 10, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/stack/ore/titanium, "name" = "titanium ore", "amount" = 12, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/stack/ore/silver, "name" = "silver ore", "amount" = 10, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		// Stack asks are settled from ONE stack, so never ask above max_amount -
		// cable coil caps at MAXCOIL (30) and a bigger ask can never be paid
		list("type" = /obj/item/stack/cable_coil, "name" = "cable coil", "amount" = 30, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("type" = /obj/item/stack/sheet/animalhide/goliath_hide, "name" = "goliath hide plates", "amount" = 4, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = /obj/item/stack/sheet/sinew, "name" = "beast sinew", "amount" = 4, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/stack/glacial_core, "name" = "glacial cores", "amount" = 5, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
	)
	// The armory back room: hard contracts only, never sold. Everything here has
	// to be unobtainable elsewhere, so no item that drops in a zone loot theme
	// and nothing that appears on the Ship Systems shelf.
	exclusive_rewards = list(
		/obj/item/circuitboard/machine/ship_combat/missile_launcher,
		/obj/item/circuitboard/machine/engine/void,
		/obj/item/gun/energy/laser/captain,
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
			"That's one warning. I only ever give the one.",
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
			"Glacial cores off the ice worlds. Coolant loops love them, scanners can't find them, wolves guard them. Good hunting.",
			"Firing pins. Everyone forgets the firing pins. Don't be everyone.",
			"Thruster boards are on the back wall. If your ship's limping, that's the fix, and it beats buying a new ship.",
			"Most crews can't build a turret. Most crews also can't afford mine. Work on the second problem.",
			"The schematics I stock are legal. The fun ones are two zones that way.",
		),
		TRADER_LINE_RESTOCK = list(
			"Convoy made it through. Shelves are full, for now.",
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
	price_credits = 450

/datum/shop_sku/outfitter/helmet
	category = "Armor"
	item_path = /obj/item/clothing/head/helmet
	price_credits = 300

/datum/shop_sku/outfitter/riot_helmet
	category = "Armor"
	item_path = /obj/item/clothing/head/helmet/toggleable/riot
	price_credits = 450
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
	price_credits = 400
	stock_min = 1
	stock_max = 3

/datum/shop_sku/outfitter/energy_gun
	category = "Firearms & Ammo"
	item_path = /obj/item/gun/energy/e_gun
	price_vouchers = 0
	price_credits = 1500
	stock_min = 1
	stock_max = 2

/datum/shop_sku/outfitter/laser_gun
	category = "Firearms & Ammo"
	item_path = /obj/item/gun/energy/laser
	price_credits = 600
	stock_min = 1
	stock_max = 2

/datum/shop_sku/outfitter/double_barrel
	category = "Firearms & Ammo"
	item_path = /obj/item/gun/ballistic/shotgun/doublebarrel
	price_credits = 900
	stock_min = 1
	stock_max = 2

/datum/shop_sku/outfitter/rubbershot
	category = "Firearms & Ammo"
	item_path = /obj/item/storage/box/rubbershot
	price_credits = 140
	stock_min = 10
	stock_max = 20

/datum/shop_sku/outfitter/lethalshot
	category = "Firearms & Ammo"
	item_path = /obj/item/storage/box/lethalshot
	price_credits = 280
	stock_min = 10
	stock_max = 20

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
	stock_min = 10
	stock_max = 20

// Magazines for the two ballistics whose blueprints are on the shelf below.
// Print the gun once, buy the ammo forever.
/datum/shop_sku/outfitter/smg_mag
	category = "Firearms & Ammo"
	name = "c-20r magazine"
	desc = "A loaded .45 magazine for a C-20r. Sarge stocks these because the schematic's on her own shelf."
	item_path = /obj/item/ammo_box/magazine/smgm45
	price_credits = 250
	stock_min = 10
	stock_max = 20

/datum/shop_sku/outfitter/wt550_mag
	category = "Firearms & Ammo"
	name = "wt-550 magazine"
	desc = "A loaded 4.6x30mm magazine for a WT-550. Armor-piercing, and priced accordingly."
	item_path = /obj/item/ammo_box/magazine/wt550m9
	price_credits = 300
	stock_min = 10
	stock_max = 20

// The quiet backbone of the blueprint economy: no pin, no gun
/datum/shop_sku/outfitter/firing_pin
	category = "Firearms & Ammo"
	item_path = /obj/item/firing_pin
	price_credits = 250
	stock_min = 3
	stock_max = 5

// ===== SHIP SYSTEMS =====
// Machine boards for the ship itself. Only 9 of 48 ships can research these,
// so for everyone else this shelf is the whole route. Note these are the
// /machine/engine/ boards from voidcrew/modules/shuttle/boards.dm, the same
// ones the protolathe designs build, so the shop stands in for a research bay.

/datum/shop_sku/outfitter/engine_plasma
	category = "Ship Systems"
	name = "plasma thruster board"
	desc = "Board for a plasma thruster, the standard workhorse drive. It draws fuel from a heater mounted right behind it, so you need one of those in the line too."
	item_path = /obj/item/circuitboard/machine/engine/plasma
	price_credits = 1800
	stock_min = 1
	stock_max = 3

/datum/shop_sku/outfitter/engine_expulsion
	category = "Ship Systems"
	name = "expulsion thruster board"
	desc = "Board for an expulsion thruster. It burns whatever gas is in the heater and wastes most of it, which is the point when plasma is scarce."
	item_path = /obj/item/circuitboard/machine/engine/expulsion
	price_credits = 1200
	stock_min = 1
	stock_max = 3

/datum/shop_sku/outfitter/engine_ion
	category = "Ship Systems"
	name = "ion thruster board"
	desc = "Board for an ion thruster. No fuel line and no heater, just a heavy draw on the powernet, at about 40% of a plasma thruster's push."
	item_path = /obj/item/circuitboard/machine/engine/electric
	price_credits = 2400
	stock_min = 1
	stock_max = 2

/datum/shop_sku/outfitter/engine_oil
	category = "Ship Systems"
	name = "oil thruster board"
	desc = "Board for an oil thruster, which burns liquid fuel instead of gas. Buying one here skips the shuttle research your lathe would need to print it."
	item_path = /obj/item/circuitboard/machine/engine/oil
	price_credits = 1800
	stock_min = 1
	stock_max = 2

/datum/shop_sku/outfitter/engine_heater
	category = "Ship Systems"
	name = "engine heater board"
	desc = "Board for a fueled engine heater. Plasma and expulsion thrusters latch onto one to draw fuel and won't fire without it."
	item_path = /obj/item/circuitboard/machine/shuttle/heater
	price_credits = 900
	stock_min = 2
	stock_max = 4

/datum/shop_sku/outfitter/laser_turret_board
	category = "Ship Systems"
	name = "laser turret board"
	desc = "Board for a hull-mounted laser turret. It takes a standard power cell you can swap out for a bigger one, and Sarge will not discuss where the crate came from."
	item_path = /obj/item/circuitboard/machine/ship_combat/laser_turret
	price_vouchers = 0
	price_credits = 2000
	stock_min = 1
	stock_max = 2

// ===== SHIP ORDNANCE =====
// Ship-to-ship missiles and the parts to feed a launcher. The armed missiles
// dispense ready to drag onto a launcher; the components restock a workshop.

/datum/shop_sku/outfitter/missile_tracking
	category = "Ship Ordnance"
	item_path = /obj/item/electronics/ship_missile_tracking
	price_credits = 150
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
	desc = "A ready-to-fire light missile. Drag it straight onto a ship launcher, no assembly, no fuss."
	item_path = /obj/structure/ship_missile/armed/light
	price_vouchers = 0
	price_credits = 800
	stock_min = 1
	stock_max = 2

// ===== SECURITY GEAR =====

/datum/shop_sku/outfitter/seclite
	category = "Security Gear"
	item_path = /obj/item/flashlight/seclite
	price_credits = 450

/datum/shop_sku/outfitter/flash
	category = "Security Gear"
	item_path = /obj/item/assembly/flash/handheld
	price_credits = 750

/datum/shop_sku/outfitter/bola
	category = "Security Gear"
	item_path = /obj/item/restraints/legcuffs/bola
	price_credits = 600

/datum/shop_sku/outfitter/security_belt
	category = "Security Gear"
	item_path = /obj/item/storage/belt/security/full
	price_credits = 2700
	stock_min = 1
	stock_max = 1

/datum/shop_sku/outfitter/pepper_spray
	category = "Security Gear"
	item_path = /obj/item/reagent_containers/spray/pepper
	price_credits = 450

/datum/shop_sku/outfitter/riot_shield
	category = "Security Gear"
	item_path = /obj/item/shield/riot
	price_credits = 2400
	stock_min = 1
	stock_max = 2

/datum/shop_sku/outfitter/barrier_grenade
	category = "Security Gear"
	item_path = /obj/item/grenade/barrier
	price_credits = 1050
	stock_min = 2
	stock_max = 4

// ===== COMBAT MEDICAL =====

/datum/shop_sku/outfitter/brute_kit
	stock_max = 20
	stock_min = 10
	category = "Combat Medical"
	item_path = /obj/item/storage/medkit/brute
	price_credits = 300

/datum/shop_sku/outfitter/advanced_medkit
	category = "Combat Medical"
	item_path = /obj/item/storage/medkit/advanced
	price_credits = 600
	stock_min = 10
	stock_max = 20

/datum/shop_sku/outfitter/stimpack
	category = "Combat Medical"
	item_path = /obj/item/reagent_containers/hypospray/medipen/stimpack
	price_credits = 1200
	stock_min = 2
	stock_max = 4

/datum/shop_sku/outfitter/suture
	dispense_amount = 10
	category = "Combat Medical"
	item_path = /obj/item/stack/medical/suture
	price_credits = 180
	stock_min = 10
	stock_max = 20

// Triage glasses. Reads live health off everyone in view, which is worth more
// in a boarding action than knowing who a station flagged as wanted.
/datum/shop_sku/outfitter/health_hud
	category = "Combat Medical"
	name = "medical HUD sunglasses"
	desc = "Tinted health-scanner glasses. Everyone in view gets a status icon, so you can tell who's down from who's dead without walking over."
	item_path = /obj/item/clothing/glasses/hud/health/sunglasses
	price_credits = 1500
	stock_min = 1
	stock_max = 3

// ===== MESS TIN =====
// Field chow. Nothing here is cooking. It's calories that survive a webbing
// pouch, a decompression and the customer. Every outpost feeds its lane;
// the contested lanes eat out of tins.

/datum/shop_sku/outfitter/rations
	category = "Mess Tin"
	name = "field ration pack"
	desc = "A sealed ration pack off the depot's own pallet. The main varies. The crackers do not."
	item_path = /obj/item/food/rationpack
	price_credits = 45
	stock_min = 6
	stock_max = 12

/datum/shop_sku/outfitter/energy_bar
	category = "Mess Tin"
	item_path = /obj/item/food/energybar
	price_credits = 30
	stock_min = 6
	stock_max = 10

/datum/shop_sku/outfitter/canned_peaches
	category = "Mess Tin"
	desc = "Peaches in syrup, the contested lanes' most fought-over dessert. Sarge limits them to keep the peace."
	item_path = /obj/item/food/canned/peaches
	price_credits = 50
	stock_min = 3
	stock_max = 6

/datum/shop_sku/outfitter/hot_sauce
	category = "Mess Tin"
	name = "bottle of hot sauce"
	desc = "Morale in a bottle. Makes a ration pack taste like a ration pack with hot sauce on it, which is measurably better."
	item_path = /obj/item/reagent_containers/condiment/hotsauce
	price_credits = 40
	stock_min = 3
	stock_max = 6

// ===== UTILITY =====

/datum/shop_sku/outfitter/gas_mask
	category = "Utility"
	item_path = /obj/item/clothing/mask/gas
	price_credits = 200

/datum/shop_sku/outfitter/jaws
	category = "Utility"
	name = "jaws of life"
	item_path = /obj/item/crowbar/power
	price_vouchers = 1
	price_credits = 750
	stock_min = 1
	stock_max = 2

/datum/shop_sku/outfitter/magboots
	category = "Utility"
	item_path = /obj/item/clothing/shoes/magboots
	price_credits = 1200
	stock_min = 1
	stock_max = 2

// ===== HULL STOCK =====
// Bulk repair material for crews who can't mine or can't wait. Sold by the
// stack, priced above what an ore redemption run costs you in time.

/datum/shop_sku/outfitter/plasteel_stock
	category = "Hull Stock"
	name = "plasteel (10 sheets)"
	desc = "Ten sheets of plasteel off the depot's own pallet. Reinforced walls, blast doors, and every airlock you'll rebuild this round."
	item_path = /obj/item/stack/sheet/plasteel
	dispense_amount = 10
	price_credits = 450
	stock_min = 2
	stock_max = 4

/datum/shop_sku/outfitter/iron_stock
	category = "Hull Stock"
	name = "iron (30 sheets)"
	desc = "Thirty sheets of iron. Not glamorous, but a hull breach doesn't care."
	item_path = /obj/item/stack/sheet/iron
	dispense_amount = 30
	price_credits = 220
	stock_min = 3
	stock_max = 6

/datum/shop_sku/outfitter/glass_stock
	category = "Hull Stock"
	name = "glass (30 sheets)"
	desc = "Thirty sheets of glass. Windows, and everything else that wants a sheet of glass in it."
	item_path = /obj/item/stack/sheet/glass
	dispense_amount = 30
	price_credits = 220
	stock_min = 3
	stock_max = 6

// ===== FUEL & GAS =====

// The contested-lane fuel dock: closer to the supply, cheaper than Halcyon's
// comfort markup, if you can make the drive
/datum/shop_sku/outfitter/plasma_canister
	name = "plasma canister (full)"
	desc = "A full canister of thruster-grade plasma at depot rates. Sarge doesn't do markup; she does volume."
	category = "Fuel & Gas"
	item_path = /obj/machinery/portable_atmospherics/canister/plasma
	price_credits = 1100
	stock_min = 3
	stock_max = 5

/datum/shop_sku/outfitter/welding_fuel
	name = "welding fuel tank"
	desc = "A full tank of welding fuel on a wheeled frame. Drag it aboard and stop rationing your repairs."
	category = "Fuel & Gas"
	item_path = /obj/structure/reagent_dispensers/fueltank
	price_credits = 400
	stock_min = 2
	stock_max = 4

/datum/shop_sku/outfitter/oxygen_tank
	name = "oxygen tank (full)"
	desc = "A filled oxygen tank at depot rates. Halcyon charges more for the same air and a nicer waiting room."
	category = "Fuel & Gas"
	item_path = /obj/item/tank/internals/oxygen
	price_credits = 120
	stock_min = 10
	stock_max = 20

// ===== BLUEPRINTS =====
// Yellow-tier guns, carried or imprinted, crafted anywhere. The charts and
// rumor tips that used to share this shelf now come off chart_pool.

/datum/shop_sku/outfitter/smg_blueprint
	category = "Blueprints"
	item_path = /obj/item/blueprint/gun/c20r
	price_vouchers = 3
	stock_min = 1
	stock_max = 1

/datum/shop_sku/outfitter/wt550_blueprint
	category = "Blueprints"
	item_path = /obj/item/blueprint/gun/wt550
	price_vouchers = 3
	stock_min = 1
	stock_max = 1

/datum/shop_sku/outfitter/carbine_blueprint
	category = "Blueprints"
	item_path = /obj/item/blueprint/gun/laser_carbine
	price_vouchers = 2
	price_credits = 3000
	stock_min = 1
	stock_max = 1

// ===== ROTATING SHELF =====

/datum/shop_sku/outfitter/rotating/riot_suit
	category = "Armor"
	item_path = /obj/item/clothing/suit/armor/riot
	price_credits = 4500

/datum/shop_sku/outfitter/rotating/telescopic_baton
	category = "Security Gear"
	item_path = /obj/item/melee/baton/telescopic
	price_credits = 2400

/datum/shop_sku/outfitter/rotating/tackler_gloves
	category = "Security Gear"
	item_path = /obj/item/clothing/gloves/tackler
	price_credits = 1200

/datum/shop_sku/outfitter/rotating/flashbang
	category = "Security Gear"
	item_path = /obj/item/grenade/flashbang
	price_credits = 900

/datum/shop_sku/outfitter/rotating/frag_grenade
	category = "Security Gear"
	item_path = /obj/item/grenade/frag
	price_vouchers = 1
	price_credits = 1200

/datum/shop_sku/outfitter/rotating/missile_standard
	category = "Ship Ordnance"
	name = "standard missile (armed)"
	desc = "A ready-to-fire standard missile. Solid ship-to-ship punch, straight onto the launcher."
	item_path = /obj/structure/ship_missile/armed/standard
	price_vouchers = 0
	price_credits = 1100

/datum/shop_sku/outfitter/rotating/warhead_heavy
	category = "Ship Ordnance"
	item_path = /obj/item/bombcore/missile/heavy
	price_vouchers = 0
	price_credits = 1400

// ===== RARE SHOWCASE =====

/datum/shop_sku/outfitter/rare/ablative_vest
	category = "Armor"
	item_path = /obj/item/clothing/suit/armor/laserproof
	price_vouchers = 1
	price_credits = 3600

/datum/shop_sku/outfitter/rare/compact_defib
	category = "Combat Medical"
	item_path = /obj/item/defibrillator/compact
	price_credits = 2400

/datum/shop_sku/outfitter/rare/ion_rifle
	category = "Firearms & Ammo"
	item_path = /obj/item/gun/energy/ionrifle
	price_vouchers = 2
	price_credits = 3000

/datum/shop_sku/outfitter/rare/missile_heavy
	category = "Ship Ordnance"
	name = "heavy missile (armed)"
	desc = "A ready-to-fire heavy missile: devastating, and priced like it. Drag it onto a launcher and pity whatever's downrange."
	item_path = /obj/structure/ship_missile/armed/heavy
	price_vouchers = 0
	price_credits = 2000

// ===== SARGE'S SALVAGE COUNTER (buybacks) =====
// Credits only; guns and armor can come off a lathe, so they never pay vouchers.
//
// No gun line here either. Any buyback typed at /obj/item/gun or
// /obj/item/gun/energy pays out on cargo's toy crates, 400 cr buys eight foam
// shotguns or six laser-tag rifles, and none of them can be told apart from the
// real thing at the counter. Armor's bid includes room for discounted cargo and
// the crate/manifest return; security packs cannot receive ordinary coupons.

/datum/shop_buyback/outfitter/salvage_armor
	name = "armored suit (salvage)"
	desc = "Body armor with mileage on it. Holes are a pricing conversation, not a dealbreaker."
	category = "Salvage"
	item_path = /obj/item/clothing/suit/armor
	pay_credits = 130
	demand_min = 3
	demand_max = 6

// Planet megafauna materials: armor-grade feedstock the depot can't lathe
/datum/shop_buyback/outfitter/goliath_plates
	name = "goliath hide plates"
	desc = "Hide plate cut off a live goliath. Sarge lines the good vests with it, and asks no questions about the tentacle marks on YOU."
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

// The ice planets' good: permafrost crystal out of unscannable veins in the
// snow rock (see planetary_goods.dm). Credits only, telecrystal keeps the
// voucher spigot.
/datum/shop_buyback/outfitter/glacial_core
	name = "glacial cores"
	desc = "Permafrost crystal cut whole out of the frozen worlds. The depot packs them around coolant loops and the cold lockers; they hold a chill for years and never sweat."
	category = "Field Materials"
	item_path = /obj/item/stack/glacial_core
	amount = 3
	pay_credits = 400
	demand_min = 3
	demand_max = 5

// Barter: the depot always needs hull stock
/datum/shop_sku/barter/plasteel_for_shield
	name = "riot shield (plasteel trade)"
	item_path = /obj/item/shield/riot
	barter_path = /obj/item/stack/sheet/plasteel
	barter_amount = 10
	stock_min = 1
	stock_max = 2

// ===== BACK ROOM =====
// Sarge's favor uniques: Trusted standing only, up to FAVOR_UNIQUE_CREW_LIMIT
// per crew per round. Priced above the rare shelf on purpose, standing opens
// the door, it doesn't pay the bill. All prices PROVISIONAL BALANCE.

/datum/shop_sku/favor/skunkworks_cell
	item_path = /obj/item/stock_parts/power_store/cell/skunkworks
	price_credits = 4200
	price_vouchers = 2

/datum/shop_sku/favor/fitter_gauntlets
	item_path = /obj/item/clothing/gloves/tinkerer/fitter
	price_credits = 3600
	price_vouchers = 2

/datum/shop_sku/favor/maneuvering_harness
	item_path = /obj/item/tank/jetpack/oxygen/harness/prototype
	price_credits = 3800
	price_vouchers = 2
