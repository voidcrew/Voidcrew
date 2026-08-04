/**
 * # Undertow Exchange — the red-zone black market
 *
 * Syndicate hardware, sealed mystery cargo and things with the serial numbers
 * filed off. The top shelf only moves for vouchers — the currency you can't
 * farm in safety.
 * Shop machinery lives in shop.dm; this file is pure catalog.
 *
 * Two shelves are the reason this shop exists:
 *
 * - MODsuits. The suit stall at Quartermain sells civilian through advanced.
 *   Vex sells the tier it won't touch: syndicate, infiltrator and Interdyne
 *   control units, plus the antag modules. Bare chassis are the mid rungs —
 *   cheaper, but the buyer has to kit them out at a bench themselves.
 * - Ship systems. Every combat board is a protolathe-only research design and
 *   only 9 of 48 ships can research anything, so most crews have no route to a
 *   shield generator at all. This is that route. Quartermain covers engines and
 *   the laser turret; the defensive and dirty boards are Vex's.
 */
/datum/outpost_shop/black_market
	outpost_name = "\improper Undertow Exchange"
	outpost_desc = "A heavily armored den of fences and quartermasters who don't ask questions. Somehow, nobody has ever managed to rob it."
	trader_name = "Vex"
	trader_outfit = /datum/outfit/job/detective
	trader_voice_pack = "goon.speak_2"
	trader_voice_pitch = 0.92
	// Vex's board also runs the drug-run contract: the only place in the
	// galaxy that posts it, and the only counter that takes the product
	extra_offer_mix = list(
		/datum/mission/drug_run = 20,
	)
	categories = list(
		"Weapons",
		"Explosives",
		"MODsuits",
		"Ship Systems",
		"Infiltration",
		"Combat Medical",
		"Intel & Charts",
		"Blueprints",
		"Mystery Cargo",
		"Sundries",
	)
	sku_types = list(
		// Weapons
		/datum/shop_sku/black_market/pistol,
		/datum/shop_sku/black_market/pistol_mag,
		/datum/shop_sku/black_market/revolver,
		/datum/shop_sku/black_market/speedloader,
		/datum/shop_sku/black_market/suppressor,
		/datum/shop_sku/black_market/combat_knife,
		/datum/shop_sku/black_market/switchblade,
		// Explosives
		/datum/shop_sku/black_market/c4,
		/datum/shop_sku/black_market/emp_grenade,
		/datum/shop_sku/black_market/frag_grenade,
		/datum/shop_sku/black_market/smoke_bomb,
		// MODsuits
		/datum/shop_sku/black_market/mod_chassis_syndicate,
		/datum/shop_sku/black_market/mod_chassis_elite,
		/datum/shop_sku/black_market/mod_interdyne,
		/datum/shop_sku/black_market/mod_infiltrator,
		/datum/shop_sku/black_market/mod_traitor,
		/datum/shop_sku/black_market/mod_storage,
		/datum/shop_sku/black_market/mod_plate_compression,
		/datum/shop_sku/black_market/mod_energy_shield,
		/datum/shop_sku/black_market/mod_wraith_cloak,
		// Ship Systems
		/datum/shop_sku/black_market/shield_generator_board,
		/datum/shop_sku/black_market/interdictor_board,
		/datum/shop_sku/black_market/data_siphon_board,
		// Infiltration
		/datum/shop_sku/black_market/emag,
		/datum/shop_sku/black_market/thermals,
		/datum/shop_sku/black_market/noslips,
		/datum/shop_sku/black_market/sleepy_pen,
		/datum/shop_sku/black_market/chameleon_mask,
		// Combat Medical
		/datum/shop_sku/black_market/tactical_medkit,
		/datum/shop_sku/black_market/stimulants,
		// Intel & Charts — named ruin tips are dealt onto the rotating shelf
		// from chart_pool below; the generic tip is the cheap standing rung.
		/datum/shop_sku/rumor,
		// Blueprints
		/datum/shop_sku/black_market/saw_blueprint,
		/datum/shop_sku/black_market/sniper_blueprint,
		/datum/shop_sku/black_market/bulldog_blueprint,
		// Mystery Cargo
		/datum/shop_sku/black_market/mystery_cache,
		/datum/shop_sku/black_market/mystery_cache_rare,
		// Sundries
		/datum/shop_sku/black_market/soap,
		/datum/shop_sku/black_market/donk_pockets,
		/datum/shop_sku/black_market/syndie_cigarettes,
	)
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
		/datum/shop_sku/black_market/rotating/mateba,
		/datum/shop_sku/black_market/rotating/ebow,
		/datum/shop_sku/black_market/rotating/minibomb,
		/datum/shop_sku/black_market/rotating/dart_pistol,
		/datum/shop_sku/black_market/rotating/mod_flamethrower,
		/datum/shop_sku/black_market/rotating/mod_chameleon,
		/datum/shop_sku/black_market/rotating/mod_active_sonar,
	)
	rare_pool = list(
		/datum/shop_sku/black_market/rare/energy_sword,
		/datum/shop_sku/black_market/rare/energy_shield,
		/datum/shop_sku/black_market/rare/mod_adrenaline,
	)
	// The consignment window: Vex fences planet exotics and ruin loot at the
	// best rates in the system. Voucher payouts are strictly planet/danger-gated.
	buyback_types = list(
		/datum/shop_buyback/black_market/telecrystal,
		/datum/shop_buyback/black_market/legion_core,
		/datum/shop_buyback/black_market/bluespace_crystals,
		/datum/shop_buyback/black_market/syndicate_documents,
		/datum/shop_buyback/exotic_gas/hypernoblium,
		/datum/shop_buyback/exotic_gas/pluoxium,
		/datum/shop_buyback/exotic_gas/nitrium,
	)
	// Vex's supply requests want the rare stuff — the free item makes it worth it
	mission_requests = list(
		list("type" = /obj/item/stack/ore/uranium, "name" = "uranium ore", "amount" = 8, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = /obj/item/stack/ore/diamond, "name" = "diamonds", "amount" = 4, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = /obj/item/stack/ore/bluespace_crystal, "name" = "bluespace crystals", "amount" = 2, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = /obj/item/stack/sheet/mineral/plasma, "name" = "plasma sheets", "amount" = 20, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/stack/telecrystal_raw, "name" = "raw telecrystal", "amount" = 10, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = /obj/item/organ/monster_core/regenerative_core/legion, "name" = "legion core", "amount" = 1, "difficulty" = MISSION_DIFFICULTY_HARD),
	)
	// The back shelf: hard contracts only, never sold. Each of these is the top
	// of a ladder Vex otherwise stops short of — the elite suit above the
	// syndicate one, the Spider Clan chassis above that, and the one combat
	// board that is on no shelf anywhere.
	exclusive_rewards = list(
		/obj/item/mod/control/pre_equipped/traitor_elite,
		/obj/item/mod/control/pre_equipped/empty/ninja,
		/obj/item/circuitboard/machine/ship_combat/cloak_device,
	)
	trader_lines = list(
		TRADER_LINE_GREETING = list(
			"Welcome to the Undertow. Touch nothing you can't pay for.",
			"Fresh faces. Vouchers up front, questions never.",
			"You found us. That's the hard part done. Now spend.",
			"Come in, come in. Leave the airlock drama outside — that's a dock problem.",
			"Ah, customers. Or corpses with good timing. Either way, welcome.",
		),
		TRADER_LINE_SALE = list(
			"Pleasure doing business. Forget you saw me.",
			"Sold. It was never here, and neither were you.",
			"A fine choice. No refunds, no receipts, no memories.",
			"Wrap it yourself. Discretion is complimentary.",
			"That one's got a history. I'd stop asking about it right around now.",
		),
		TRADER_LINE_REFUSAL = list(
			"Your money's no good here. Literally — check your embargo notice.",
			"We don't serve your kind. 'Your kind' meaning people who shoot at my stock.",
			"Come back when your ship's ledger is clean.",
			"The Undertow forgives everything except property damage. Wait it out.",
		),
		TRADER_LINE_WARNING = list(
			"Easy, killer. The turrets have a temper and a long memory.",
			"That's one. Keep swinging and you'll meet the expensive part of this station.",
			"Read the plaque. Violence is bad for business — mostly yours.",
		),
		TRADER_LINE_AGGRESSION = list(
			"Bad call. The turrets were the cheap part of this station.",
			"Violence! In MY shop! Embargo their ship and paint them, girls.",
			"You just made the blacklist. It's laminated.",
		),
		TRADER_LINE_IDLE = list(
			"I once sold a fleet admiral his own stolen flagship. Twice.",
			"Everything's legal in the red zone. That's the whole pitch.",
			"Stock's limited. The galaxy is not a reliable supplier.",
			"Raw telecrystal. The burning worlds are full of it, and the fools who mine it. Bring me both. Just kidding. Just the crystal.",
			"The mystery caches? Sealed when they got here. I make a point of not knowing.",
			"Somebody asked what the imprinter does with the schematics. Confetti. Expensive confetti.",
			"Legion cores keep better than legionnaires. Cooler's under the counter.",
			"Quartermain will sell you a mining suit. I sell the ones with the Cybersun stamp still on the plating.",
			"The bare chassis are cheaper for a reason. You're buying a frame and a cell, not a loadout.",
			"Nobody else in the galaxy will sell you a shield generator. Think about what that's worth before you haggle.",
		),
		TRADER_LINE_RESTOCK = list(
			"Convoy's in. Don't ask which flag it flew — new stock on the shelves.",
			"Fresh inventory, straight off a manifest that never existed.",
			"The warehouse door opens once a cycle. It just did. Shop.",
		),
	)

/datum/shop_sku/black_market
	stock_min = 1
	stock_max = 3

// ===== WEAPONS =====

/datum/shop_sku/black_market/pistol
	category = "Weapons"
	item_path = /obj/item/gun/ballistic/automatic/pistol
	price_vouchers = 2
	price_credits = 1500
	stock_min = 2
	stock_max = 4

/datum/shop_sku/black_market/pistol_mag
	category = "Weapons"
	item_path = /obj/item/ammo_box/magazine/m9mm
	price_credits = 900
	stock_min = 4
	stock_max = 8

/datum/shop_sku/black_market/revolver
	category = "Weapons"
	item_path = /obj/item/gun/ballistic/revolver
	price_vouchers = 3
	stock_min = 1
	stock_max = 2

/datum/shop_sku/black_market/speedloader
	category = "Weapons"
	item_path = /obj/item/ammo_box/a357
	price_credits = 1800
	stock_min = 2
	stock_max = 5

/datum/shop_sku/black_market/suppressor
	category = "Weapons"
	item_path = /obj/item/suppressor
	price_credits = 1200
	stock_min = 2
	stock_max = 4

/datum/shop_sku/black_market/combat_knife
	category = "Weapons"
	item_path = /obj/item/knife/combat
	price_credits = 1050
	stock_min = 2
	stock_max = 4

/datum/shop_sku/black_market/switchblade
	category = "Weapons"
	item_path = /obj/item/switchblade
	price_credits = 900
	stock_min = 2
	stock_max = 4

// ===== EXPLOSIVES =====

/datum/shop_sku/black_market/c4
	category = "Explosives"
	item_path = /obj/item/grenade/c4
	price_vouchers = 1
	price_credits = 750
	stock_min = 2
	stock_max = 4

/datum/shop_sku/black_market/emp_grenade
	category = "Explosives"
	item_path = /obj/item/grenade/empgrenade
	price_vouchers = 1
	stock_min = 2
	stock_max = 4

/datum/shop_sku/black_market/frag_grenade
	category = "Explosives"
	item_path = /obj/item/grenade/frag
	price_vouchers = 2
	stock_min = 1
	stock_max = 2

/datum/shop_sku/black_market/smoke_bomb
	category = "Explosives"
	item_path = /obj/item/grenade/smokebomb
	price_credits = 900
	stock_min = 2
	stock_max = 4

// ===== MODSUITS =====
// The illegal half of the suit market. Quartermain's fitter stocks civilian
// through advanced; everything here is a control unit or module that shop will
// not carry, and all of it is voucher-gated.
//
// Two rules shape the ladder:
// - Nothing with a req_access list. /pre_equipped/elite and /nuclear spawn
//   locked to ACCESS_SYNDICATE (mod_control.dm:99), so a buyer could not seal
//   the suit they just paid five vouchers for. /empty/* and the traitor,
//   infiltrator and interdyne units carry no access list and are safe to sell.
// - The bare /empty chassis are the mid rungs on purpose: a working core and
//   cell and no modules at all, so the cheap route into a syndicate suit is the
//   one that still owes a bench a full loadout.

/datum/shop_sku/black_market/mod_chassis_syndicate
	category = "MODsuits"
	name = "syndicate MOD chassis"
	desc = "A blood-red MODsuit frame with a super cell in the core and no modules whatsoever. Cheaper than a kitted suit because you're buying the armor and nothing else."
	item_path = /obj/item/mod/control/pre_equipped/empty/syndicate
	price_vouchers = 2
	price_credits = 3600
	stock_min = 1
	stock_max = 2

/datum/shop_sku/black_market/mod_chassis_elite
	category = "MODsuits"
	name = "elite MOD chassis"
	desc = "The heavier plating the Syndicate issues to people it expects to get shot at, sold bare. Same deal as the red one: frame, core, cell, no modules."
	item_path = /obj/item/mod/control/pre_equipped/empty/elite
	price_vouchers = 3
	price_credits = 5400
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/mod_interdyne
	category = "MODsuits"
	name = "Interdyne MODsuit"
	desc = "A field surgery suit: combat defibrillator, health analyzer, injector and a loaded surgical processor. Sawbones next door thinks it's the best thing Vex sells."
	item_path = /obj/item/mod/control/pre_equipped/interdyne
	price_vouchers = 4
	price_credits = 3000
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/mod_infiltrator
	category = "MODsuits"
	name = "infiltrator MODsuit"
	desc = "Silent footsteps, no name on examine, and it doesn't register as contraband. Comes with the stealth core programs already welded in."
	item_path = /obj/item/mod/control/pre_equipped/infiltrator
	price_vouchers = 4
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/mod_traitor
	category = "MODsuits"
	name = "syndicate MODsuit (equipped)"
	desc = "The full loadout: syndicate storage, EMP shielding, shock absorbers, magnetic harness, jetpack and a DNA lock. An expedition's worth of vouchers, and it shows."
	item_path = /obj/item/mod/control/pre_equipped/traitor
	price_vouchers = 5
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/mod_storage
	category = "MODsuits"
	desc = "Cybersun compression storage. Twenty-one items in a back panel, and it fits things a normal storage module won't."
	item_path = /obj/item/mod/module/storage/syndicate
	price_vouchers = 1
	stock_min = 1
	stock_max = 3

/datum/shop_sku/black_market/mod_plate_compression
	category = "MODsuits"
	desc = "Squeezes a stowed suit down to normal size so it fits in a bag. Nothing else fits in the suit afterwards."
	item_path = /obj/item/mod/module/plate_compression
	price_vouchers = 1
	price_credits = 1800
	stock_min = 1
	stock_max = 2

/datum/shop_sku/black_market/mod_energy_shield
	category = "MODsuits"
	desc = "A back-mounted deflector that eats one incoming attack and then needs ten seconds to come back. The best defensive module money can buy here."
	item_path = /obj/item/mod/module/energy_shield
	price_vouchers = 3
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/mod_wraith_cloak
	category = "MODsuits"
	desc = "Bends light around the suit until you're nearly invisible. Taking a hit or throwing a punch drops it, and it drinks power."
	item_path = /obj/item/mod/module/stealth/wraith
	price_vouchers = 3
	stock_min = 1
	stock_max = 1

// ===== SHIP SYSTEMS =====
// All six ship-combat boards are protolathe research designs and only nine of
// forty-eight ships can research anything, so most crews have no way to build
// one. Quartermain covers engines and the laser turret. These three are the
// defensive and dirty half, and the cloak board is a contract reward only.

/datum/shop_sku/black_market/shield_generator_board
	category = "Ship Systems"
	name = "shield generator board"
	desc = "The machine board for a ship shield generator. If your ship didn't spawn with one, this is the only place in the galaxy that will sell you the part."
	item_path = /obj/item/circuitboard/machine/ship_combat/shield_generator
	price_vouchers = 4
	price_credits = 6000
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/interdictor_board
	category = "Ship Systems"
	name = "interdiction system board"
	desc = "Board for an interdictor. Holds a ship in place so it can't jump away from the fight it started."
	item_path = /obj/item/circuitboard/machine/ship_combat/interdictor
	price_vouchers = 3
	price_credits = 4800
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/data_siphon_board
	category = "Ship Systems"
	name = "data siphon board"
	desc = "Pirate hardware that pulls credits off another ship's account while you hold a lock on it. Vex sells it without comment."
	item_path = /obj/item/circuitboard/machine/ship_combat/data_siphon
	price_vouchers = 3
	price_credits = 3600
	stock_min = 1
	stock_max = 1

// ===== INFILTRATION =====
// What's left of the old shelf. Every door on every player ship and every
// outpost has req_access stripped, so nothing here is priced as an access tool
// — these are boarding tools and they're priced like boarding tools.

/datum/shop_sku/black_market/emag
	category = "Infiltration"
	name = "cryptographic sequencer"
	desc = "Opens outpost rental lockers, the cargo console's restricted list, and some colosseum machinery. That's the whole list, hence the price."
	item_path = /obj/item/card/emag
	price_vouchers = 2
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/thermals
	category = "Infiltration"
	item_path = /obj/item/clothing/glasses/thermal/syndi
	price_vouchers = 3
	stock_min = 1
	stock_max = 2

/datum/shop_sku/black_market/noslips
	category = "Infiltration"
	item_path = /obj/item/clothing/shoes/chameleon/noslip
	price_vouchers = 2
	price_credits = 1200
	stock_min = 1
	stock_max = 2

/datum/shop_sku/black_market/sleepy_pen
	category = "Infiltration"
	item_path = /obj/item/pen/sleepy
	price_vouchers = 1
	price_credits = 1200
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/chameleon_mask
	category = "Infiltration"
	name = "chameleon mask"
	desc = "A shape-shifting mask with a built-in voice modulator. Be anyone, sound like them too."
	item_path = /obj/item/clothing/mask/chameleon
	price_vouchers = 1
	price_credits = 1500
	stock_min = 1
	stock_max = 2

// ===== COMBAT MEDICAL =====

/datum/shop_sku/black_market/tactical_medkit
	category = "Combat Medical"
	item_path = /obj/item/storage/medkit/tactical
	price_vouchers = 1
	price_credits = 1500
	stock_min = 1
	stock_max = 3

/datum/shop_sku/black_market/stimulants
	category = "Combat Medical"
	item_path = /obj/item/reagent_containers/hypospray/medipen/stimulants
	price_vouchers = 2
	stock_min = 1
	stock_max = 2

// ===== INTEL & CHARTS =====
// Every chart SKU now lives in shop_catalog_charts.dm and reaches this shelf
// through chart_pool above. The generic rumor rides the core shelf.

// ===== BLUEPRINTS =====
// The only trader route to these guns; build them via their schematics.
// Reusable, so priced at the top of the ladder.

/datum/shop_sku/black_market/saw_blueprint
	category = "Blueprints"
	item_path = /obj/item/blueprint/gun/l6_saw
	price_vouchers = 5
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/sniper_blueprint
	category = "Blueprints"
	item_path = /obj/item/blueprint/gun/sniper_rifle
	price_vouchers = 5
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/bulldog_blueprint
	category = "Blueprints"
	item_path = /obj/item/blueprint/gun/bulldog
	price_vouchers = 5
	stock_min = 1
	stock_max = 1

// ===== MYSTERY CARGO =====
// The gamble channel, sold over the counter: sealed caches rolling the zone
// loot tables. The crate pins its band to the spawn turf — bought at the
// Undertow, it rolls on lawless odds. The reinforced one is not a different
// table, just a fuller crate; nothing here is unobtainable from a cache
// found in the field.

/datum/shop_sku/black_market/mystery_cache
	category = "Mystery Cargo"
	name = "sealed cache"
	desc = "A locked syndicate supply cache, contents sight-unseen. Vex guarantees it's worth something. Vex guarantees nothing else."
	item_path = /obj/structure/closet/crate/zone_loot/syndicate
	price_vouchers = 2
	stock_min = 2
	stock_max = 3

/datum/shop_sku/black_market/mystery_cache_rare
	category = "Mystery Cargo"
	name = "reinforced cache"
	desc = "The good crate. The one from the back room. Even Vex looks curious when one moves."
	item_path = /obj/structure/closet/crate/zone_loot/syndicate/reinforced
	price_vouchers = 4
	stock_min = 1
	stock_max = 1

// ===== SUNDRIES =====

// The mandatory joke item; also the cheap "see how the shop works" SKU
/datum/shop_sku/black_market/soap
	category = "Sundries"
	item_path = /obj/item/soap/syndie
	price_credits = 150
	stock_min = 3
	stock_max = 6

/datum/shop_sku/black_market/donk_pockets
	category = "Sundries"
	item_path = /obj/item/storage/box/donkpockets
	price_credits = 200
	stock_min = 2
	stock_max = 4

/datum/shop_sku/black_market/syndie_cigarettes
	category = "Sundries"
	item_path = /obj/item/storage/fancy/cigarettes/cigpack_syndicate
	price_credits = 150
	stock_min = 2
	stock_max = 4

// ===== ROTATING SHELF =====

/datum/shop_sku/black_market/rotating/mateba
	category = "Weapons"
	item_path = /obj/item/gun/ballistic/revolver/mateba
	price_vouchers = 4

/datum/shop_sku/black_market/rotating/ebow
	category = "Weapons"
	name = "miniature energy crossbow"
	item_path = /obj/item/gun/energy/recharge/ebow
	price_vouchers = 6

/datum/shop_sku/black_market/rotating/minibomb
	category = "Explosives"
	item_path = /obj/item/grenade/syndieminibomb
	price_vouchers = 3

/datum/shop_sku/black_market/rotating/dart_pistol
	category = "Weapons"
	item_path = /obj/item/gun/syringe/syndicate
	price_vouchers = 2

/datum/shop_sku/black_market/rotating/mod_flamethrower
	category = "MODsuits"
	desc = "A suit-mounted flamethrower. Three seconds between bursts and it costs a lot of charge, so pick your moment."
	item_path = /obj/item/mod/module/flamethrower
	price_vouchers = 3

/datum/shop_sku/black_market/rotating/mod_chameleon
	category = "MODsuits"
	desc = "Disguises the whole stowed suit as some other object. Useful for walking a MODsuit past people who would object to a MODsuit."
	item_path = /obj/item/mod/module/chameleon
	price_vouchers = 2

/datum/shop_sku/black_market/rotating/mod_active_sonar
	category = "MODsuits"
	desc = "Pings for living things around you and puts them on your HUD. Everyone in earshot hears the ping too."
	item_path = /obj/item/mod/module/active_sonar
	price_vouchers = 2

// ===== RARE SHOWCASE =====

/datum/shop_sku/black_market/rare/energy_sword
	category = "Weapons"
	item_path = /obj/item/melee/energy/sword/saber
	price_vouchers = 4

/datum/shop_sku/black_market/rare/energy_shield
	category = "Weapons"
	item_path = /obj/item/shield/energy
	price_vouchers = 3

/datum/shop_sku/black_market/rare/mod_adrenaline
	category = "MODsuits"
	desc = "Spider Clan chemistry in a suit module. Clears stamina damage and every immobilizing effect, then needs 20u of radium before it will do it again. Can't be uninstalled once fitted."
	item_path = /obj/item/mod/module/adrenaline_boost
	price_vouchers = 3

// ===== VEX'S CONSIGNMENT WINDOW (buybacks) =====
// Voucher payouts here must stay un-farmable: natural crystals only (the
// artificial subtype is lathe-printable), original syndicate docs only
// (photocopies are a different subtype and worthless).

// The flagship planetary good: raw telecrystal only comes out of hostile
// planet crust, so paying vouchers for it can't be farmed in safety.
/datum/shop_buyback/black_market/telecrystal
	name = "raw telecrystal"
	desc = "Vex doesn't say what the Undertow does with unrefined telecrystal, and you shouldn't ask. Veins hide in the rock of the burning and blasted worlds."
	category = "Planetary Exotics"
	item_path = /obj/item/stack/telecrystal_raw
	amount = 5
	pay_vouchers = 1
	demand_min = 4
	demand_max = 6

/datum/shop_buyback/black_market/legion_core
	name = "legion core"
	desc = "A still-warm regenerative core cut out of a legion. Vex keeps a cooler under the counter and a buyer list that's none of your business."
	category = "Planetary Exotics"
	item_path = /obj/item/organ/monster_core/regenerative_core/legion
	pay_vouchers = 1
	demand_min = 2
	demand_max = 4

/datum/shop_buyback/black_market/bluespace_crystals
	name = "natural bluespace crystals"
	desc = "Unrefined crystal straight out of dangerous rock. Vex can tell the lab-grown ones apart by smell, apparently."
	category = "Planetary Exotics"
	item_path = /obj/item/stack/ore/bluespace_crystal
	match_subtypes = FALSE
	amount = 3
	pay_vouchers = 1
	demand_min = 3
	demand_max = 5

/datum/shop_buyback/black_market/syndicate_documents
	name = "syndicate documents"
	desc = "Original classified paperwork. Photocopies are an insult and priced accordingly (zero)."
	category = "Intel"
	item_path = /obj/item/documents/syndicate
	pay_vouchers = 2
	demand_min = 1
	demand_max = 2

// No gun-fencing window. It was a flat-rate buyback typed at the top of the gun
// tree, which meant cargo's 400 cr crate of toy shotguns fenced for thousands,
// and nobody with a real gun was ever going to sell it for less than the
// outfitter charges. Sell salvaged arms to Sarge, who at least pretends to
// inspect them.

// The gas window: tanks of red-band nebula exotics, scooped where the lanes
// are worst. Sold with the tank — Vex doesn't do decanting. Pays cash, never
// vouchers: pluoxium and nitrium both come out of an ordinary atmospherics
// setup, and a voucher you can synthesise aboard ship stops being the currency
// that has to be earned in dangerous places.
/datum/shop_buyback/exotic_gas/hypernoblium
	name = "hypernoblium"
	desc = "A tank of the rarest gas on the cloud charts. Vex's buyer pays in advance and collects in an unmarked hauler."
	gas_type = /datum/gas/hypernoblium
	pay_credits = 1200
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/exotic_gas/pluoxium
	name = "pluoxium"
	desc = "Dense breathing gas. A tank of it goes a lot further than a tank of oxygen. Deep-lane nebulas are the only place it pools for free."
	gas_type = /datum/gas/pluoxium
	pay_credits = 300
	demand_min = 3
	demand_max = 5

/datum/shop_buyback/exotic_gas/nitrium
	name = "nitrium"
	desc = "Combat stim chemistry starts with this. Vex has never met the customers and intends to keep it that way."
	gas_type = /datum/gas/nitrium
	pay_credits = 300
	demand_min = 3
	demand_max = 5
