/**
 * # Quartermain Depot: the Fitting Bay
 *
 * Wick's stall: the galaxy's only honest MODsuit counter. Chassis, cores,
 * frame parts, plating and the module catalogue, plus the environment
 * clothing a normal outfitter doesn't bother stocking. The modsuit bench
 * (/obj/machinery/modsuit_bench) sits in this stall. Wick sells the parts,
 * the bench fits them.
 *
 * Why this shelf exists: every MOD part in the game is a MECHFAB design, and
 * exactly one of the 49 ship maps carries an exosuit fabricator. For 48 crews
 * out of 49 there is no route to a powered suit at any price except this
 * counter. Nothing MOD-related drops in any zone loot table either, so the
 * shelf competes with nothing.
 *
 * Balance notes:
 * - No overlap with Sarge's counter (she keeps arms, armor and combat vests)
 *   or with Boffin's (he keeps the power-cell ladder and stock parts). Wick
 *   sells one basic cell so a bare core is usable; anything better is Boffin's.
 * - The illegal tier: syndicate/infiltrator/elite plating and antag modules.
 *   Is the Undertow's, not Wick's. Nothing here is contraband.
 * - The core shelf is the ladder spine; the rotating and rare pools carry the
 *   breadth, so a round shows a slice of ~200 modules rather than all of them.
 *   Plating rotates on purpose: which themes you can BUILD varies by round.
 * - Buybacks are credits-only and deliberately narrow. Modules, frame parts
 *   and plating are all mechfab-printable, so buying them back would be a
 *   money loop for any crew with a fabricator. Wick only buys things no lathe
 *   makes: dead cores and whole salvaged suits.
 */

// =========================================================================
// THE FITTING BAY: Wick, depot suit fitter
// =========================================================================

/**
 * Wick: a tailor from the collar up and an engineer from the eyes out. The
 * waistcoat and laceups are the fitting-room half of the job; the scanner
 * goggles are the half where he tells you your chassis is two sizes wrong.
 * The toolbelt is what he actually does the work with.
 */
/datum/outfit/fitting_bay_wick
	name = "Suit fitter"
	uniform = /obj/item/clothing/under/costume/buttondown/slacks
	accessory = /obj/item/clothing/accessory/waistcoat
	glasses = /obj/item/clothing/glasses/meson/engine
	gloves = /obj/item/clothing/gloves/color/black
	belt = /obj/item/storage/belt/utility/full
	shoes = /obj/item/clothing/shoes/laceup

/// Wick, who will not sell you a suit until he has measured you for it
/datum/outpost_shop/vendor/suit_fitter
	outpost_name = "\improper The Fitting Bay"
	outpost_desc = "The depot's modsuit shop, and the only bench in the lanes that'll fit one properly."
	trader_name = "Wick"
	trader_outfit = /datum/outfit/fitting_bay_wick
	trader_gender = MALE
	trader_voice_pack = "goon.speak_4"
	trader_voice_pitch = 1.05
	rotating_picks = 8
	rare_picks_max = 3
	categories = list(
		"MOD Chassis",
		"Cores & Power",
		"Mobility",
		"Utility Modules",
		"Industrial Modules",
		"Medical Modules",
		"Visors & Sensors",
		"Environment Gear",
	)
	sku_types = list(
		// MOD Chassis: two finished suits plus the whole build route
		/datum/shop_sku/fitter/suit_civilian,
		/datum/shop_sku/fitter/suit_engineering,
		/datum/shop_sku/fitter/shell,
		/datum/shop_sku/fitter/frame_helmet,
		/datum/shop_sku/fitter/frame_chestplate,
		/datum/shop_sku/fitter/frame_gauntlets,
		/datum/shop_sku/fitter/frame_boots,
		/datum/shop_sku/fitter/plating_civilian,
		// Cores & Power
		/datum/shop_sku/fitter/core_standard,
		/datum/shop_sku/fitter/core_plasma,
		/datum/shop_sku/fitter/cell,
		// Mobility
		/datum/shop_sku/fitter/mod_tether,
		/datum/shop_sku/fitter/mod_magboot,
		/datum/shop_sku/fitter/mod_jetpack,
		/datum/shop_sku/fitter/mod_longfall,
		// Utility Modules
		/datum/shop_sku/fitter/mod_storage,
		/datum/shop_sku/fitter/mod_flashlight,
		/datum/shop_sku/fitter/mod_mouthhole,
		/datum/shop_sku/fitter/mod_thermal_regulator,
		/datum/shop_sku/fitter/mod_status_readout,
		// Industrial Modules
		/datum/shop_sku/fitter/mod_welding,
		/datum/shop_sku/fitter/mod_gps,
		/datum/shop_sku/fitter/mod_rad_protection,
		/datum/shop_sku/fitter/mod_headprotector,
		/datum/shop_sku/fitter/mod_drill,
		/datum/shop_sku/fitter/mod_orebag,
		// Medical Modules
		/datum/shop_sku/fitter/mod_health_analyzer,
		/datum/shop_sku/fitter/mod_injector,
		/datum/shop_sku/fitter/mod_quick_carry,
		// Visors & Sensors
		/datum/shop_sku/fitter/mod_visor_meson,
		/datum/shop_sku/fitter/mod_visor_medhud,
		/datum/shop_sku/fitter/mod_visor_diaghud,
		// Environment Gear
		/datum/shop_sku/fitter/nasa_suit,
		/datum/shop_sku/fitter/nasa_helmet,
		/datum/shop_sku/fitter/plasmaman_suit,
		/datum/shop_sku/fitter/plasmaman_helmet,
		/datum/shop_sku/fitter/insuls,
		/datum/shop_sku/fitter/wintercoat,
	)
	// A big pool on purpose: eight picks out of fifty means the rack looks
	// different every round and no crew ever sees the whole catalogue
	rotating_pool = list(
		// Chassis of the week
		/datum/shop_sku/fitter/rotating/suit_atmospheric,
		/datum/shop_sku/fitter/rotating/suit_mining,
		/datum/shop_sku/fitter/rotating/suit_medical,
		/datum/shop_sku/fitter/rotating/suit_rescue,
		/datum/shop_sku/fitter/rotating/suit_research,
		/datum/shop_sku/fitter/rotating/suit_security,
		/datum/shop_sku/fitter/rotating/suit_loader,
		// Plating of the week: decides what themes you can build this round
		/datum/shop_sku/fitter/rotating/plating_engineering,
		/datum/shop_sku/fitter/rotating/plating_atmospheric,
		/datum/shop_sku/fitter/rotating/plating_medical,
		/datum/shop_sku/fitter/rotating/plating_security,
		// Mobility
		/datum/shop_sku/fitter/rotating/mod_joint_torsion,
		/datum/shop_sku/fitter/rotating/mod_shock_absorber,
		/datum/shop_sku/fitter/rotating/mod_emp_shield,
		// Utility
		/datum/shop_sku/fitter/rotating/mod_storage_large,
		/datum/shop_sku/fitter/rotating/mod_dna_lock,
		/datum/shop_sku/fitter/rotating/mod_signlang_radio,
		/datum/shop_sku/fitter/rotating/mod_plasma_stabilizer,
		/datum/shop_sku/fitter/rotating/mod_recycler,
		/datum/shop_sku/fitter/rotating/mod_hat_stabilizer,
		/datum/shop_sku/fitter/rotating/mod_fishing_glove,
		/datum/shop_sku/fitter/rotating/mod_dispenser,
		/datum/shop_sku/fitter/rotating/mod_microwave_beam,
		// Industrial
		/datum/shop_sku/fitter/rotating/mod_t_ray,
		/datum/shop_sku/fitter/rotating/mod_constructor,
		/datum/shop_sku/fitter/rotating/mod_mister_atmos,
		/datum/shop_sku/fitter/rotating/mod_mister_cleaner,
		/datum/shop_sku/fitter/rotating/mod_clamp,
		/datum/shop_sku/fitter/rotating/mod_hydraulic,
		/datum/shop_sku/fitter/rotating/mod_magnet,
		/datum/shop_sku/fitter/rotating/mod_disposal_connector,
		/datum/shop_sku/fitter/rotating/mod_paper_dispenser,
		// Medical
		/datum/shop_sku/fitter/rotating/mod_defibrillator,
		/datum/shop_sku/fitter/rotating/mod_organizer,
		/datum/shop_sku/fitter/rotating/mod_thread_ripper,
		/datum/shop_sku/fitter/rotating/mod_patient_transport,
		// Visors & sensors
		/datum/shop_sku/fitter/rotating/mod_visor_night,
		/datum/shop_sku/fitter/rotating/mod_reagent_scanner,
		/datum/shop_sku/fitter/rotating/mod_active_sonar,
		/datum/shop_sku/fitter/rotating/mod_magnetic_harness,
		/datum/shop_sku/fitter/rotating/mod_holster,
		/datum/shop_sku/fitter/rotating/mod_megaphone,
		// Environment gear
		/datum/shop_sku/fitter/rotating/firesuit,
		/datum/shop_sku/fitter/rotating/fire_helmet,
		/datum/shop_sku/fitter/rotating/rad_suit,
		/datum/shop_sku/fitter/rotating/rad_hood,
		/datum/shop_sku/fitter/rotating/explorer_suit,
		/datum/shop_sku/fitter/rotating/explorer_mask,
		/datum/shop_sku/fitter/rotating/engine_goggles,
		/datum/shop_sku/fitter/rotating/hazard_vest,
	)
	rare_pool = list(
		/datum/shop_sku/fitter/rare/suit_advanced,
		/datum/shop_sku/fitter/rare/mod_jetpack_advanced,
		/datum/shop_sku/fitter/rare/mod_jump_jet,
		/datum/shop_sku/fitter/rare/mod_storage_bluespace,
		/datum/shop_sku/fitter/rare/mod_antigrav,
		/datum/shop_sku/fitter/rare/mod_visor_thermal,
		/datum/shop_sku/fitter/rare/mod_surgical_processor,
		/datum/shop_sku/fitter/rare/mod_emp_shield_advanced,
		/datum/shop_sku/fitter/rare/mod_projectile_dampener,
		/datum/shop_sku/fitter/rare/bomb_suit,
	)
	// Credits only, and only things no fabricator makes: dead cores and whole
	// suits off whoever stopped needing them
	buyback_types = list(
		/datum/shop_buyback/fitter/broken_core,
		/datum/shop_buyback/fitter/scrap_control,
		/datum/shop_buyback/fitter/salvage_spacesuit,
		/datum/shop_buyback/fitter/salvage_space_helmet,
	)
	// A suit shop eats refined metal and very little else
	mission_requests = list(
		list("type" = /obj/item/stack/sheet/mineral/titanium, "name" = "titanium sheets", "amount" = 10, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/stack/sheet/mineral/plasma, "name" = "plasma sheets", "amount" = 15, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/stack/sheet/mineral/silver, "name" = "silver sheets", "amount" = 8, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/stack/sheet/mineral/gold, "name" = "gold sheets", "amount" = 6, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/stack/sheet/mineral/uranium, "name" = "uranium sheets", "amount" = 6, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/stack/sheet/plasteel, "name" = "plasteel sheets", "amount" = 14, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = /obj/item/stack/ore/bluespace_crystal, "name" = "bluespace crystals", "amount" = 4, "difficulty" = MISSION_DIFFICULTY_HARD),
	)
	// Never on a shelf: two chassis Nakamura doesn't retail, and the two
	// anomaly modules that come with their core already seated
	exclusive_rewards = list(
		/obj/item/mod/control/pre_equipped/magnate,
		/obj/item/mod/control/pre_equipped/safeguard,
		/obj/item/mod/module/anomaly_locked/kinesis/prebuilt,
		/obj/item/mod/module/anomaly_locked/teleporter/prebuilt,
	)
	trader_lines = list(
		TRADER_LINE_SALE = list(
			"Sold. Seal it and watch the readout before you trust it to vacuum.",
			"Good fit. Bring it back when the cell's flat, not after.",
			"Signed for. Bench is right there if you want the modules seated properly.",
			"Yours. Service it every few runs and it'll outlast the ship.",
		),
		TRADER_LINE_REFUSAL = list(
			"You're flagged. The depot won't clear the sale and I don't argue with the depot.",
			"Sarge has your ship on her list. That's the whole conversation.",
			"Come back when the embargo lifts. The suits aren't going anywhere.",
		),
		TRADER_LINE_IDLE = list(
			"Everyone wants the advanced chassis. Almost nobody's been measured for one.",
			"Standard cores ship empty. Boffin's got the good cells two doors down.",
			"Bench install is free. Doing it yourself in a corridor is how people lose fingers.",
			"Plasma core runs on plasma sheets. If your engines burn it, you're already carrying the fuel.",
			"The civilian chassis is not spaceworthy. It says so on the plate. People still ask.",
			"Bring me a wrecked control unit and I'll take it, modules and all.",
			"Core, then helmet, chest, gauntlets, boots, then plating. In that order, or you start again.",
		),
		TRADER_LINE_RESTOCK = list(
			"Convoy's in. New chassis on the rack and the plating rotation changed.",
			"Resupply landed. Cores came through intact this time, which isn't guaranteed.",
			"Fresh stock. Look now, before the mining crews strip the rack.",
		),
	)

/datum/shop_sku/fitter
	stock_min = 2
	stock_max = 4

// ===== MOD CHASSIS =====
// Finished suits arrive with a core, a cell and their theme's module loadout.
// The shell-and-parts route below is the cheaper, slower way to the same thing.

/datum/shop_sku/fitter/suit_civilian
	category = "MOD Chassis"
	name = "civilian MODsuit"
	desc = "A light powered suit fitted with storage, a welder and a light. It is not spaceworthy. The civilian frame trades the seal for speed and takes fewer modules than the industrial ones."
	item_path = /obj/item/mod/control/pre_equipped/civilian
	icon_state_override = "civilian-control"
	price_credits = 2400
	stock_min = 1
	stock_max = 2

/datum/shop_sku/fitter/suit_engineering
	category = "MOD Chassis"
	name = "engineering MODsuit"
	desc = "The standard industrial suit: sealed, insulated against high voltage, and fitted with magboots, a tether, a welder and radiation shielding out of the crate."
	item_path = /obj/item/mod/control/pre_equipped/engineering
	icon_state_override = "engineering-control"
	price_credits = 3000
	stock_min = 1
	stock_max = 2

// Build-vs-buy parity. A suit assembled from parts costs exactly what Wick
// charges for the same suit finished, so neither route is punished:
//
//   shell 1600 + helmet 750 + chestplate 900 + gauntlets 650 + boots 600
//   + standard core 700 + cell 200                              = 5400
//   + plating                            civilian  1800 -> 7200 = suit_civilian
//                                     engineering  1800 -> 7200 = suit_engineering
//                                         medical  1800 -> 7200 = suit_medical
//                                        security  1800 -> 7200 = suit_security
//                                    atmospheric   3000 -> 8400 = suit_atmospheric
//
// The theme premium lives entirely in the plating, which is why the platings
// carry the same voucher price as their finished suit. If a suit's price moves,
// move its plating by the same amount or the parity breaks.
/datum/shop_sku/fitter/shell
	category = "MOD Chassis"
	desc = "The empty frame a suit gets built inside. Core first, then helmet, chestplate, gauntlets, boots, then plating, with a screwdriver and a wrench along the way."
	item_path = /obj/item/mod/construction/shell
	price_credits = 400
	stock_min = 1
	stock_max = 3

/datum/shop_sku/fitter/frame_helmet
	category = "MOD Chassis"
	item_path = /obj/item/mod/construction/helmet
	price_credits = 100

/datum/shop_sku/fitter/frame_chestplate
	category = "MOD Chassis"
	item_path = /obj/item/mod/construction/chestplate
	price_credits = 100

/datum/shop_sku/fitter/frame_gauntlets
	category = "MOD Chassis"
	item_path = /obj/item/mod/construction/gauntlets
	price_credits = 100

/datum/shop_sku/fitter/frame_boots
	category = "MOD Chassis"
	item_path = /obj/item/mod/construction/boots
	price_credits = 100

/datum/shop_sku/fitter/plating_civilian
	category = "MOD Chassis"
	name = "MOD civilian plating"
	desc = "The last piece of a build. Finishes a shell into a civilian suit: light, quick, and no protection from vacuum."
	item_path = /obj/item/mod/construction/plating/civilian
	icon_state_override = "civilian-plating"
	price_credits = 400
	stock_min = 1
	stock_max = 3

// ===== CORES & POWER =====
// Boffin owns the cell ladder. Wick stocks exactly one basic cell so a bare
// core is usable the moment you buy it, and points at the Skunkworks for more.

/datum/shop_sku/fitter/core_standard
	category = "Cores & Power"
	name = "MOD standard core"
	desc = "The baseline power core. It ships empty, so drop a cell in it or the suit won't run. Boffin stocks the higher grades."
	item_path = /obj/item/mod/core/standard
	price_credits = 300
	stock_min = 2
	stock_max = 3

/datum/shop_sku/fitter/core_plasma
	category = "Cores & Power"
	name = "MOD plasma core"
	desc = "Refuels on plasma ore and plasma sheets instead of a charger. If your ship burns plasma you're already carrying the fuel."
	item_path = /obj/item/mod/core/plasma
	price_vouchers = 1
	price_credits = 750
	stock_min = 1
	stock_max = 2

/datum/shop_sku/fitter/cell
	category = "Cores & Power"
	desc = "A basic cell to seat in a standard core. Fine for a shift; the Skunkworks sells the ones that last."
	item_path = /obj/item/stock_parts/power_store/cell
	price_credits = 100
	stock_min = 3
	stock_max = 6

// ===== MOBILITY =====

/datum/shop_sku/fitter/mod_tether
	category = "Mobility"
	item_path = /obj/item/mod/module/tether
	price_credits = 300
	stock_min = 1
	stock_max = 3

/datum/shop_sku/fitter/mod_magboot
	category = "Mobility"
	item_path = /obj/item/mod/module/magboot
	price_credits = 450
	stock_min = 1
	stock_max = 3

/datum/shop_sku/fitter/mod_jetpack
	category = "Mobility"
	item_path = /obj/item/mod/module/jetpack
	price_credits = 750
	stock_min = 1
	stock_max = 2

/datum/shop_sku/fitter/mod_longfall
	category = "Mobility"
	item_path = /obj/item/mod/module/longfall
	price_credits = 1050

// ===== UTILITY MODULES =====

/datum/shop_sku/fitter/mod_storage
	category = "Utility Modules"
	item_path = /obj/item/mod/module/storage
	price_credits = 200

/datum/shop_sku/fitter/mod_flashlight
	category = "Utility Modules"
	item_path = /obj/item/mod/module/flashlight
	price_credits = 100

/datum/shop_sku/fitter/mod_mouthhole
	category = "Utility Modules"
	item_path = /obj/item/mod/module/mouthhole
	price_credits = 600

/datum/shop_sku/fitter/mod_thermal_regulator
	category = "Utility Modules"
	item_path = /obj/item/mod/module/thermal_regulator
	price_credits = 1200

/datum/shop_sku/fitter/mod_status_readout
	category = "Utility Modules"
	item_path = /obj/item/mod/module/status_readout
	price_credits = 900

// ===== INDUSTRIAL MODULES =====

/datum/shop_sku/fitter/mod_welding
	category = "Industrial Modules"
	item_path = /obj/item/mod/module/welding
	price_credits = 150

/datum/shop_sku/fitter/mod_gps
	category = "Industrial Modules"
	item_path = /obj/item/mod/module/gps
	price_credits = 750

/datum/shop_sku/fitter/mod_rad_protection
	category = "Industrial Modules"
	item_path = /obj/item/mod/module/rad_protection
	price_credits = 1350

/datum/shop_sku/fitter/mod_headprotector
	category = "Industrial Modules"
	item_path = /obj/item/mod/module/headprotector
	price_credits = 750

/datum/shop_sku/fitter/mod_drill
	category = "Industrial Modules"
	item_path = /obj/item/mod/module/drill
	price_vouchers = 1
	price_credits = 1200
	stock_min = 1
	stock_max = 3

/datum/shop_sku/fitter/mod_orebag
	category = "Industrial Modules"
	item_path = /obj/item/mod/module/orebag
	price_credits = 1200
	stock_min = 1
	stock_max = 3

// ===== MEDICAL MODULES =====

/datum/shop_sku/fitter/mod_health_analyzer
	category = "Medical Modules"
	item_path = /obj/item/mod/module/health_analyzer
	price_credits = 1050

/datum/shop_sku/fitter/mod_injector
	category = "Medical Modules"
	item_path = /obj/item/mod/module/injector
	price_vouchers = 1
	price_credits = 1200
	stock_min = 1
	stock_max = 2

/datum/shop_sku/fitter/mod_quick_carry
	category = "Medical Modules"
	item_path = /obj/item/mod/module/quick_carry
	price_credits = 1200

// ===== VISORS & SENSORS =====

/datum/shop_sku/fitter/mod_visor_meson
	category = "Visors & Sensors"
	item_path = /obj/item/mod/module/visor/meson
	price_credits = 1200

/datum/shop_sku/fitter/mod_visor_medhud
	category = "Visors & Sensors"
	item_path = /obj/item/mod/module/visor/medhud
	price_credits = 1050

/datum/shop_sku/fitter/mod_visor_diaghud
	category = "Visors & Sensors"
	item_path = /obj/item/mod/module/visor/diaghud
	price_credits = 1050

// ===== ENVIRONMENT GEAR =====
// The non-MOD half of the stall. Barnaby has the EVA suit and the breath
// masks; Wick has everything you wear when the hazard isn't just vacuum.

/datum/shop_sku/fitter/nasa_suit
	category = "Environment Gear"
	desc = "A heavy old voidsuit. Slower than an EVA rig and far harder to tear, which is the trade the salvage crews keep making."
	item_path = /obj/item/clothing/suit/space/nasavoid
	price_credits = 750
	stock_min = 1
	stock_max = 3

/datum/shop_sku/fitter/nasa_helmet
	category = "Environment Gear"
	item_path = /obj/item/clothing/head/helmet/space/nasavoid
	price_credits = 500
	stock_min = 1
	stock_max = 3

/datum/shop_sku/fitter/plasmaman_suit
	category = "Environment Gear"
	desc = "Sealed envirosuit sized for a plasmaman, rated for vacuum. Wick keeps a rack of them because nobody else out here does."
	item_path = /obj/item/clothing/suit/space/eva/plasmaman
	price_credits = 400

/datum/shop_sku/fitter/plasmaman_helmet
	category = "Environment Gear"
	item_path = /obj/item/clothing/head/helmet/space/plasmaman
	price_credits = 300

/datum/shop_sku/fitter/insuls
	category = "Environment Gear"
	desc = "Insulated gloves. The suit's own insulation stops at the wrist on most frames, so these still matter."
	item_path = /obj/item/clothing/gloves/color/yellow
	price_credits = 450
	stock_min = 1
	stock_max = 3

/datum/shop_sku/fitter/wintercoat
	category = "Environment Gear"
	desc = "A hooded coat that holds body heat on the ice worlds. Cheap, and it fits over a jumpsuit instead of replacing it."
	item_path = /obj/item/clothing/suit/hooded/wintercoat
	price_credits = 200
	stock_min = 3
	stock_max = 5

// =========================================================================
// ROTATING RACK
// Eight picks a round out of fifty lines. The plating entries decide which
// suit themes a crew can actually build this shift.
// =========================================================================

/datum/shop_sku/fitter/rotating
	stock_min = 1
	stock_max = 2

// ----- chassis of the week -----

/datum/shop_sku/fitter/rotating/suit_atmospheric
	category = "MOD Chassis"
	name = "atmospheric MODsuit"
	desc = "Sealed against heat and bad air, with an extinguisher mister, a t-ray scanner and magboots fitted. What atmospherics wears into a burning compartment."
	item_path = /obj/item/mod/control/pre_equipped/atmospheric
	icon_state_override = "atmospheric-control"
	price_credits = 3600

/datum/shop_sku/fitter/rotating/suit_mining
	category = "MOD Chassis"
	name = "mining MODsuit"
	desc = "Runs on a plasma core, so it refuels off plasma sheets instead of a charger. Ships with a drill, an ore bag, a cargo clamp and a GPS."
	item_path = /obj/item/mod/control/pre_equipped/mining
	icon_state_override = "mining-control"
	price_credits = 3600

/datum/shop_sku/fitter/rotating/suit_medical
	category = "MOD Chassis"
	name = "medical MODsuit"
	desc = "A sealed medical suit with a health analyzer and a quick-carry rig fitted. Light plate, good sensors."
	item_path = /obj/item/mod/control/pre_equipped/medical
	icon_state_override = "medical-control"
	price_credits = 3000

/datum/shop_sku/fitter/rotating/suit_rescue
	category = "MOD Chassis"
	name = "rescue MODsuit"
	desc = "Runs on a super cell and comes with an analyzer, a chemical injector and expanded storage. Built for pulling people out of wrecks."
	item_path = /obj/item/mod/control/pre_equipped/rescue
	icon_state_override = "rescue-control"
	price_credits = 4200

/datum/shop_sku/fitter/rotating/suit_research
	category = "MOD Chassis"
	name = "research MODsuit"
	desc = "Sealed lab suit on a super cell, with a circuit manipulator, a t-ray scanner and a welder fitted."
	item_path = /obj/item/mod/control/pre_equipped/research
	icon_state_override = "research-control"
	price_credits = 3600

/datum/shop_sku/fitter/rotating/suit_security
	category = "MOD Chassis"
	name = "security MODsuit"
	desc = "Sealed and properly armored, with a jetpack, a weapon harness and pepper shoulders fitted. Wick sells it to anyone; the depot's only rule is that you pay."
	item_path = /obj/item/mod/control/pre_equipped/security
	icon_state_override = "security-control"
	price_vouchers = 1
	price_credits = 3600

/datum/shop_sku/fitter/rotating/suit_loader
	category = "MOD Chassis"
	name = "loader MODsuit"
	desc = "A cargo frame with a hydraulic clamp and an ore magnet built into the chassis. Slow, strong, and it never gets tired."
	item_path = /obj/item/mod/control/pre_equipped/loader
	icon_state_override = "loader-control"
	price_credits = 3000

// ----- plating of the week -----

/datum/shop_sku/fitter/rotating/plating_engineering
	category = "MOD Chassis"
	name = "MOD engineering plating"
	desc = "Finishes a shell into an engineering suit: sealed, heat-resistant, and insulated against high voltage."
	item_path = /obj/item/mod/construction/plating/engineering
	icon_state_override = "engineering-plating"
	price_credits = 600

/datum/shop_sku/fitter/rotating/plating_atmospheric
	category = "MOD Chassis"
	name = "MOD atmospheric plating"
	desc = "Finishes a shell into an atmospheric suit, rated for fire and unbreathable air."
	item_path = /obj/item/mod/construction/plating/atmospheric
	icon_state_override = "atmospheric-plating"
	price_credits = 1200

/datum/shop_sku/fitter/rotating/plating_medical
	category = "MOD Chassis"
	name = "MOD medical plating"
	desc = "Finishes a shell into a medical suit. Light, sealed, and it doesn't slow you down over a patient."
	item_path = /obj/item/mod/construction/plating/medical
	icon_state_override = "medical-plating"
	price_credits = 600

/datum/shop_sku/fitter/rotating/plating_security
	category = "MOD Chassis"
	name = "MOD security plating"
	desc = "Finishes a shell into a security suit. This is the armored plate, and it costs like it."
	item_path = /obj/item/mod/construction/plating/security
	icon_state_override = "security-plating"
	price_vouchers = 1
	price_credits = 600

// ----- rotating modules -----

/datum/shop_sku/fitter/rotating/mod_joint_torsion
	category = "Mobility"
	item_path = /obj/item/mod/module/joint_torsion
	price_credits = 1200

/datum/shop_sku/fitter/rotating/mod_shock_absorber
	category = "Mobility"
	item_path = /obj/item/mod/module/shock_absorber
	price_credits = 1350

/datum/shop_sku/fitter/rotating/mod_emp_shield
	category = "Mobility"
	item_path = /obj/item/mod/module/emp_shield
	price_credits = 1500

/datum/shop_sku/fitter/rotating/mod_storage_large
	category = "Utility Modules"
	item_path = /obj/item/mod/module/storage/large_capacity
	price_credits = 1650

/datum/shop_sku/fitter/rotating/mod_dna_lock
	category = "Utility Modules"
	item_path = /obj/item/mod/module/dna_lock
	price_credits = 1350

/datum/shop_sku/fitter/rotating/mod_signlang_radio
	category = "Utility Modules"
	item_path = /obj/item/mod/module/signlang_radio
	price_credits = 750

/datum/shop_sku/fitter/rotating/mod_plasma_stabilizer
	category = "Utility Modules"
	item_path = /obj/item/mod/module/plasma_stabilizer
	price_credits = 900

/datum/shop_sku/fitter/rotating/mod_recycler
	category = "Utility Modules"
	item_path = /obj/item/mod/module/recycler
	price_credits = 1500

/datum/shop_sku/fitter/rotating/mod_hat_stabilizer
	category = "Utility Modules"
	item_path = /obj/item/mod/module/hat_stabilizer
	price_credits = 600

/datum/shop_sku/fitter/rotating/mod_fishing_glove
	category = "Utility Modules"
	item_path = /obj/item/mod/module/fishing_glove
	price_credits = 1050

/datum/shop_sku/fitter/rotating/mod_dispenser
	category = "Utility Modules"
	item_path = /obj/item/mod/module/dispenser
	price_credits = 1200

/datum/shop_sku/fitter/rotating/mod_microwave_beam
	category = "Utility Modules"
	item_path = /obj/item/mod/module/microwave_beam
	price_credits = 1050

/datum/shop_sku/fitter/rotating/mod_t_ray
	category = "Industrial Modules"
	item_path = /obj/item/mod/module/t_ray
	price_credits = 900

/datum/shop_sku/fitter/rotating/mod_constructor
	category = "Industrial Modules"
	item_path = /obj/item/mod/module/constructor
	price_vouchers = 1
	price_credits = 1800

/datum/shop_sku/fitter/rotating/mod_mister_atmos
	category = "Industrial Modules"
	item_path = /obj/item/mod/module/mister/atmos
	price_credits = 1200

/datum/shop_sku/fitter/rotating/mod_mister_cleaner
	category = "Industrial Modules"
	item_path = /obj/item/mod/module/mister/cleaner
	price_credits = 900

/datum/shop_sku/fitter/rotating/mod_clamp
	category = "Industrial Modules"
	item_path = /obj/item/mod/module/clamp
	price_credits = 1200

/datum/shop_sku/fitter/rotating/mod_hydraulic
	category = "Industrial Modules"
	item_path = /obj/item/mod/module/hydraulic
	price_credits = 1500

/datum/shop_sku/fitter/rotating/mod_magnet
	category = "Industrial Modules"
	item_path = /obj/item/mod/module/magnet
	price_vouchers = 1
	price_credits = 1500

/datum/shop_sku/fitter/rotating/mod_disposal_connector
	category = "Industrial Modules"
	item_path = /obj/item/mod/module/disposal_connector
	price_credits = 1050

/datum/shop_sku/fitter/rotating/mod_paper_dispenser
	category = "Industrial Modules"
	item_path = /obj/item/mod/module/paper_dispenser
	price_credits = 600

/datum/shop_sku/fitter/rotating/mod_defibrillator
	category = "Medical Modules"
	item_path = /obj/item/mod/module/defibrillator
	price_vouchers = 1
	price_credits = 2100

/datum/shop_sku/fitter/rotating/mod_organizer
	category = "Medical Modules"
	item_path = /obj/item/mod/module/organizer
	price_credits = 1500

/datum/shop_sku/fitter/rotating/mod_thread_ripper
	category = "Medical Modules"
	item_path = /obj/item/mod/module/thread_ripper
	price_credits = 1350

/datum/shop_sku/fitter/rotating/mod_patient_transport
	category = "Medical Modules"
	item_path = /obj/item/mod/module/criminalcapture/patienttransport
	price_credits = 1500

/datum/shop_sku/fitter/rotating/mod_visor_night
	category = "Visors & Sensors"
	item_path = /obj/item/mod/module/visor/night
	price_credits = 2100

/datum/shop_sku/fitter/rotating/mod_reagent_scanner
	category = "Visors & Sensors"
	item_path = /obj/item/mod/module/reagent_scanner
	price_credits = 1200

/datum/shop_sku/fitter/rotating/mod_active_sonar
	category = "Visors & Sensors"
	item_path = /obj/item/mod/module/active_sonar
	price_vouchers = 1
	price_credits = 1500

/datum/shop_sku/fitter/rotating/mod_magnetic_harness
	category = "Visors & Sensors"
	item_path = /obj/item/mod/module/magnetic_harness
	price_credits = 1200

/datum/shop_sku/fitter/rotating/mod_holster
	category = "Visors & Sensors"
	item_path = /obj/item/mod/module/holster
	price_credits = 1350

/datum/shop_sku/fitter/rotating/mod_megaphone
	category = "Visors & Sensors"
	item_path = /obj/item/mod/module/megaphone
	price_credits = 750

// ----- rotating environment gear -----

/datum/shop_sku/fitter/rotating/firesuit
	category = "Environment Gear"
	item_path = /obj/item/clothing/suit/utility/fire
	price_credits = 500

/datum/shop_sku/fitter/rotating/fire_helmet
	category = "Environment Gear"
	item_path = /obj/item/clothing/head/utility/hardhat/red
	price_credits = 300

/datum/shop_sku/fitter/rotating/rad_suit
	category = "Environment Gear"
	item_path = /obj/item/clothing/suit/utility/radiation
	price_credits = 600

/datum/shop_sku/fitter/rotating/rad_hood
	category = "Environment Gear"
	item_path = /obj/item/clothing/head/utility/radiation
	price_credits = 400

/datum/shop_sku/fitter/rotating/explorer_suit
	category = "Environment Gear"
	desc = "An armored hooded suit cut for hot, hostile ground. Popular with anyone who works a lava world on foot."
	item_path = /obj/item/clothing/suit/hooded/explorer
	price_credits = 900

/datum/shop_sku/fitter/rotating/explorer_mask
	category = "Environment Gear"
	item_path = /obj/item/clothing/mask/gas/explorer
	price_credits = 400

/datum/shop_sku/fitter/rotating/engine_goggles
	category = "Environment Gear"
	desc = "Meson and t-ray scanning in one pair of goggles. Worth carrying even once you have the visor module, since goggles work without a suit."
	item_path = /obj/item/clothing/glasses/meson/engine
	price_credits = 750

/datum/shop_sku/fitter/rotating/hazard_vest
	category = "Environment Gear"
	item_path = /obj/item/clothing/suit/hazardvest
	price_credits = 200

// =========================================================================
// RARE RACK
// Three showcase units a round, one of each. Vouchers on everything.
// =========================================================================

/datum/shop_sku/fitter/rare/suit_advanced
	category = "MOD Chassis"
	name = "advanced MODsuit"
	desc = "Nakamura's flagship: fireproof, acid-resistant, insulated to zero, with advanced magboots built into the chassis. Ships with a jetpack, a tether and expanded storage."
	item_path = /obj/item/mod/control/pre_equipped/advanced
	icon_state_override = "advanced-control"
	price_vouchers = 2
	price_credits = 6000

/datum/shop_sku/fitter/rare/mod_jetpack_advanced
	category = "Mobility"
	item_path = /obj/item/mod/module/jetpack/advanced
	price_vouchers = 2
	price_credits = 2700

/datum/shop_sku/fitter/rare/mod_jump_jet
	category = "Mobility"
	item_path = /obj/item/mod/module/jump_jet
	price_vouchers = 2
	price_credits = 3000

/datum/shop_sku/fitter/rare/mod_storage_bluespace
	category = "Utility Modules"
	item_path = /obj/item/mod/module/storage/bluespace
	price_vouchers = 2
	price_credits = 3000

/datum/shop_sku/fitter/rare/mod_antigrav
	category = "Mobility"
	name = "MOD anti-gravity module (cored)"
	desc = "An anti-gravity module with a gravitational anomaly core already seated, so it works the moment it's installed. Wick does not say where the core came from."
	item_path = /obj/item/mod/module/anomaly_locked/antigrav/prebuilt
	price_vouchers = 2
	price_credits = 2400

/datum/shop_sku/fitter/rare/mod_visor_thermal
	category = "Visors & Sensors"
	item_path = /obj/item/mod/module/visor/thermal
	price_vouchers = 2
	price_credits = 2100

/datum/shop_sku/fitter/rare/mod_surgical_processor
	category = "Medical Modules"
	name = "MOD surgical processor (loaded)"
	desc = "A wrist-mounted surgical suite with the common operation programs already loaded."
	item_path = /obj/item/mod/module/surgical_processor/preloaded
	price_vouchers = 2
	price_credits = 2100

/datum/shop_sku/fitter/rare/mod_emp_shield_advanced
	category = "Utility Modules"
	item_path = /obj/item/mod/module/emp_shield/advanced
	price_vouchers = 1
	price_credits = 2400

/datum/shop_sku/fitter/rare/mod_projectile_dampener
	category = "Mobility"
	item_path = /obj/item/mod/module/projectile_dampener
	price_vouchers = 2
	price_credits = 2700

/datum/shop_sku/fitter/rare/bomb_suit
	category = "Environment Gear"
	desc = "Full blast plate for handling live ordnance. Heavy enough that you won't run anywhere in it, which is the point."
	item_path = /obj/item/clothing/suit/utility/bomb_suit
	price_vouchers = 1
	price_credits = 1200

// =========================================================================
// WICK'S SALVAGE BENCH (buybacks)
// Credits only, and nothing a fabricator prints. Modules, frame parts and
// plating are all MECHFAB designs. Buying those back would be a money loop
// for any crew with an exosuit fabricator, so Wick doesn't take them.
// =========================================================================

/datum/shop_buyback/fitter/broken_core
	name = "broken MOD core"
	desc = "A dead suit core. Wick can rebuild one on the bench, which is more than the crew who dropped it managed."
	category = "Suit Salvage"
	item_path = /obj/item/mod/construction/broken_core
	pay_credits = 250
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/fitter/scrap_control
	name = "MOD control unit (any)"
	desc = "A whole suit, working or not, modules included. Wick strips it to the frame and asks nothing about the previous owner."
	category = "Suit Salvage"
	item_path = /obj/item/mod/control
	pay_credits = 500
	demand_min = 2
	demand_max = 3

/**
 * A deployed suit is still inside the wearer's contents, so the stock
 * inventory sweep would happily sell the suit off the seller's own back.
 * Wick only takes one that's off a body.
 */
/datum/shop_buyback/fitter/scrap_control/matches(obj/item/offered)
	if(!..())
		return FALSE
	var/obj/item/mod/control/suit = offered
	return isnull(suit.wearer)

/datum/shop_buyback/fitter/salvage_spacesuit
	name = "space suit (salvage)"
	desc = "Any sealed suit with wear on it. Wick repatches the seals himself and sells them on to crews who can't afford a powered rig."
	category = "Suit Salvage"
	item_path = /obj/item/clothing/suit/space
	pay_credits = 30
	demand_min = 3
	demand_max = 5

/datum/shop_buyback/fitter/salvage_space_helmet
	name = "space helmet (salvage)"
	desc = "Helmets to match. Wick re-seals the visors and sells them on to crews who lost one out an airlock."
	category = "Suit Salvage"
	item_path = /obj/item/clothing/head/helmet/space
	pay_credits = 20
	demand_min = 3
	demand_max = 5
