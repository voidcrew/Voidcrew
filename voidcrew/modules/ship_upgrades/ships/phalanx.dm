// ========== PHALANX MODULES ==========
//
// Slot geometry (BYOND coords on the 56x30 hull, origin bottom-left):
//
//   phalanx_bay_north  x18-28 y27-29  33 tiles  marker (18,27)  OPEN
//     Open pocket in the North Hangar. The y26 service row south of it is
//     permanent hull: inner-blast buttons (19,26)/(27,26), air alarm (20,26),
//     APC (26,26), fire alarm (28,26), plus the hull vent (22,26) and scrubber
//     (24,26) that ventilate the bay. Modules must NOT place an APC or air
//     alarm. Keep (18,27) walkable - it is the lane from the (18,25) firedoor -
//     and leave the x21-25 face at y27 unwalled (inner blast door approach).
//     The y29 row backs the outer poddoor line; treat it as wall-backed.
//
//   phalanx_bay_south  x18-28 y2-4   33 tiles  marker (18,2)   OPEN
//     Mirror pocket in the South Hangar. Permanent y5 service row: buttons
//     (19,5)/(27,5), air alarm (20,5), APC (26,5), fire alarm (28,5), hull vent
//     (22,5) and scrubber (24,5). No module APC/air alarm. The inner poddoors
//     at x21-25 y6 are the bay's ONLY interior access - leave the x21-25 face
//     at y4 unwalled. The y2 row backs the outer poddoor line.
//
//   phalanx_lab       x21-30 y18-20  30 tiles  marker (21,18)  ENCLOSED
//     The old nanite lab interior; own area (/nanites/<letter>). The hull
//     provides NOTHING inside: every module must ship an APC, air alarm, fire
//     alarm, vent, scrubber and its own pipe/cable net reaching the door
//     stubs. Doors at (25,17)/(26,17) south and (25,21)/(26,21) north - keep
//     both x25-26 lanes open through the room. Shell windows on y17/y21 at
//     x21-22 and x28-29 are hull; build against them freely.
//
//   phalanx_medical   x21-30 y11-13  30 tiles  marker (21,11)  ENCLOSED
//     The old surgery block interior; own area (/medbay/<letter>). Same
//     enclosed-module kit rules as phalanx_lab. Doors at (25,10)/(26,10)
//     south and (25,14)/(26,14) north - keep both x25-26 lanes open.
//
//   phalanx_armory    x46-51 y7-10   24 tiles  marker (46,7)   ENCLOSED
//     The old armory box; own area (/security/armory/<letter>). Enclosed-module
//     kit required. Doors at (48,11)/(49,11) north (highsec) - keep x48-49 at
//     y10 open.

/datum/ship_upgrade_module/phalanx
	for_ship = /datum/map_template/shuttle/voidcrew/phalanx
	// Modules are shared across all four themes; themed reskins are per-dmm
	// (the loader falls back from <base>_<theme>.dmm to map_file)
	for_theme = list("surplus", "hearth", "verdant", "springs")

// -- phalanx_bay_north: the north hangar deck.

/datum/ship_upgrade_module/phalanx/bay_north_muster
	id = "phalanx_bay_north_muster"
	name = "Muster Deck"
	desc = "The hangar as the navy left it: ore redemption machine, autolathe, \
		pick rack and suit chargers, with the deck kept clear to stage an away \
		team."
	slot = "phalanx_bay_north"
	map_file = "phalanx/phalanx_bay_north_muster.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/phalanx/bay_north_mech
	id = "phalanx_bay_north_mech"
	name = "Mech Garage"
	desc = "Two mech charging bays, an exosuit fabricator and a wall of spare \
		parts. Bring your own mech, or build one."
	slot = "phalanx_bay_north"
	map_file = "phalanx/phalanx_bay_north_mech.dmm"
	part_cost = list(PART_CLASS_COMBAT = 14)

/datum/ship_upgrade_module/phalanx/bay_north_garden
	id = "phalanx_bay_north_garden"
	name = "Greenhouse Deck"
	desc = "Six hydroponics trays on real turf under grow lights, with a seed \
		vendor and a biogenerator. Adds a Botanist to the crew."
	slot = "phalanx_bay_north"
	map_file = "phalanx/phalanx_bay_north_garden.dmm"
	part_cost = list(PART_CLASS_TRADE = 8)
	job_slots_add = list(
		list(
			name = "Botanist",
			outfit = /datum/outfit/job/botanist,
			category = JOB_CAT_SERVICE,
			slots = 1,
		),
	)

// -- phalanx_bay_south: the south hangar deck.

/datum/ship_upgrade_module/phalanx/bay_south_freight
	id = "phalanx_bay_south_freight"
	name = "Freight Hold"
	desc = "Crate racks, tank staging and pallet markings - a working freight \
		deck for a ship that hauls its pay home."
	slot = "phalanx_bay_south"
	map_file = "phalanx/phalanx_bay_south_freight.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/phalanx/bay_south_workshop
	id = "phalanx_bay_south_workshop"
	name = "Salvage Workshop"
	desc = "A recycler with a conveyor feed, a salvage rack - plasma cutter, \
		fulton rig, GPS - and a workbench for breaking wrecks into sheets."
	slot = "phalanx_bay_south"
	map_file = "phalanx/phalanx_bay_south_workshop.dmm"
	part_cost = list(PART_CLASS_TRADE = 8)

// The hull has no engineering slot: its power plant (seven SMES, five PACMANs
// and the atmospherics room) is permanent hull, and carving a slot out of that
// would have put the ship's air supply behind a purchase. The south hangar is
// the only pocket left that a plumbed hot-and-cold loop fits in, so the TEG
// lives here and the price of it is the freight deck.
//
// Unlike the Goon's rig this one ships plumbed. The generator faces NORTH, so
// find_circulators() takes the WEST circulator (cold, facing EAST) and the EAST
// one (hot, facing WEST); circulator/set_init_directions() then puts their pipe
// ports NORTH/SOUTH, which is exactly what a three-row pocket can serve. Each
// loop is circulator -> pipenet -> volume pump -> pipenet -> circulator, with the
// thermomachine on the circulator's INPUT net and a pressure tank on its OUTPUT
// net - the same topology as scarab_engineering_teg. The crew still has to start
// the pumps and the thermomachines; that is operating a TEG, not building one.
/datum/ship_upgrade_module/phalanx/bay_south_teg
	id = "phalanx_bay_south_teg"
	name = "Powerplant Deck"
	desc = "The freight racks come out and a thermoelectric plant goes in: \
		generator, hot and cold circulators, both loops plumbed and charged, a \
		heater and a freezer at either end, and a monitoring console. The output \
		is cabled into the bay's power run. Someone still has to start it."
	slot = "phalanx_bay_south"
	map_file = "phalanx/phalanx_bay_south_teg.dmm"
	part_cost = list(PART_CLASS_TRADE = 14)

/datum/ship_upgrade_module/phalanx/bay_south_gym
	id = "phalanx_bay_south_gym"
	name = "Deck Gym"
	desc = "Weight machines, punching bags and a sparring mat. The marines are \
		gone; the fitness culture stayed."
	slot = "phalanx_bay_south"
	map_file = "phalanx/phalanx_bay_south_gym.dmm"
	part_cost = list(PART_CLASS_MISC = 4)

// -- phalanx_lab: the laboratory box behind the glass on the central hall.

/datum/ship_upgrade_module/phalanx/lab_nanite
	id = "phalanx_lab_nanite"
	name = "Nanite Lab"
	desc = "The suite the class is named for: nanite chamber and control, cloud \
		controller, program hub and programmer, purple deck and all."
	slot = "phalanx_lab"
	map_file = "phalanx/phalanx_lab_nanite.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/phalanx/lab_chem
	id = "phalanx_lab_chem"
	name = "Chemistry Lab"
	desc = "Chem dispenser, ChemMaster and heater behind a proper counter, with \
		a smartfridge for the output. Adds a Chemist to the crew."
	slot = "phalanx_lab"
	map_file = "phalanx/phalanx_lab_chem.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 8)
	job_slots_add = list(
		list(
			name = "Chemist",
			outfit = /datum/outfit/job/chemist,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
	)

/datum/ship_upgrade_module/phalanx/lab_xenobio
	id = "phalanx_lab_xenobio"
	name = "Xenobiology Pen"
	desc = "Two windowed slime pens with a grey slime in each, and the \
		processing gear to keep them fed and profitable. Adds a Xenobiologist \
		to the crew."
	slot = "phalanx_lab"
	map_file = "phalanx/phalanx_lab_xenobio.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 14)
	job_slots_add = list(
		list(
			name = "Xenobiologist",
			outfit = /datum/outfit/job/scientist,
			category = JOB_CAT_SCIENCE,
			slots = 1,
		),
	)

// -- phalanx_medical: the twin-theatre block on the central hall.

/datum/ship_upgrade_module/phalanx/medical_theatre
	id = "phalanx_medical_theatre"
	name = "Twin Theatres"
	desc = "Two glass-fronted operating cells with stasis beds between them - \
		the cleanest view on the ship, if you are not the patient."
	slot = "phalanx_medical"
	map_file = "phalanx/phalanx_medical_theatre.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/phalanx/medical_ward
	id = "phalanx_medical_ward"
	name = "Recovery Ward"
	desc = "Cryotubes, recovery beds and a sleeper for patching a boarding \
		party back together. Adds a Triage Nurse to the crew."
	slot = "phalanx_medical"
	map_file = "phalanx/phalanx_medical_ward.dmm"
	part_cost = list(PART_CLASS_MISC = 8)
	job_slots_add = list(
		list(
			name = "Triage Nurse",
			outfit = /datum/outfit/job/paramedic,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
	)

// -- phalanx_armory: the highsec box off the security room.

/datum/ship_upgrade_module/phalanx/armory_post
	id = "phalanx_armory_post"
	name = "Watch Post"
	desc = "A duty desk, a rack of disablers and riot shields, and an evidence \
		locker. Enough to keep order; not enough to start a war."
	slot = "phalanx_armory"
	map_file = "phalanx/phalanx_armory_post.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/phalanx/armory_full
	id = "phalanx_armory_full"
	name = "Ship Armory"
	desc = "Energy and riot closets, an EOD locker and a marine vendor - a \
		working slice of the arsenal this hull used to carry."
	slot = "phalanx_armory"
	map_file = "phalanx/phalanx_armory_full.dmm"
	part_cost = list(PART_CLASS_COMBAT = 14)

/datum/ship_upgrade_module/phalanx/armory_brig
	id = "phalanx_armory_brig"
	name = "Brig Wing"
	desc = "Two holding cells with brig timers, a processing desk and evidence \
		storage. Adds a Warden to the crew."
	slot = "phalanx_armory"
	map_file = "phalanx/phalanx_armory_brig.dmm"
	part_cost = list(PART_CLASS_COMBAT = 8)
	job_slots_add = list(
		list(
			name = "Warden",
			outfit = /datum/outfit/job/warden,
			category = JOB_CAT_SECURITY,
			slots = 1,
		),
	)

// ========== PHALANX THEMES ==========

/datum/ship_theme/phalanx
	for_ship = /datum/map_template/shuttle/voidcrew/phalanx

/datum/ship_theme/phalanx/surplus
	id = "surplus"
	name = "Fleet Surplus"
	desc = "The battlecruiser as the decommissioning yard sold her: navy grey, \
		a blue parade runner down the aft hall, and a crew of veterans who \
		signed on the day she was struck from the register. The marine gear is \
		gone; the discipline is not."
	is_default = TRUE
	template_suffix = "nano_phalanx_a"
	upgrade_slot_ids = list(
		"phalanx_bay_north",
		"phalanx_bay_south",
		"phalanx_lab",
		"phalanx_medical",
		"phalanx_armory",
	)
	job_slots = list(
		list(
			name = "Captain",
			officer = TRUE,
			outfit = /datum/outfit/job/captain,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Chaplain",
			outfit = /datum/outfit/job/chaplain,
			category = JOB_CAT_SERVICE,
			slots = 1,
		),
		list(
			name = "Station Engineer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Atmospheric Technician",
			outfit = /datum/outfit/job/atmos,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Medical Doctor",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Cook",
			outfit = /datum/outfit/job/cook,
			category = JOB_CAT_SERVICE,
			slots = 1,
		),
		list(
			name = "Security Officer",
			outfit = /datum/outfit/job/security,
			category = JOB_CAT_SECURITY,
			slots = 3,
		),
		list(
			name = "Assistant",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

/datum/ship_theme/phalanx/hearth
	id = "hearth"
	name = "Hearthship"
	desc = "Three generations of one spacer family bought a warship at auction \
		and made it the house: timber decks, quilted bunks, a kitchen that \
		never quite goes cold and height marks pencilled on the dormitory \
		doorframe. The blast doors still work. So does the dinner bell."
	part_cost = list(PART_CLASS_TRADE = 12)
	template_suffix = "nano_phalanx_b"
	upgrade_slot_ids = list(
		"phalanx_bay_north",
		"phalanx_bay_south",
		"phalanx_lab",
		"phalanx_medical",
		"phalanx_armory",
	)
	job_slots = list(
		list(
			name = "Family Head",
			officer = TRUE,
			outfit = /datum/outfit/job/captain,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Hearthkeeper",
			outfit = /datum/outfit/job/chaplain,
			category = JOB_CAT_SERVICE,
			slots = 1,
		),
		list(
			name = "Ship's Fixer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Boilerhand",
			outfit = /datum/outfit/job/atmos,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "House Medic",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Family Cook",
			outfit = /datum/outfit/job/cook,
			category = JOB_CAT_SERVICE,
			slots = 2,
		),
		list(
			name = "Door Warden",
			outfit = /datum/outfit/job/security,
			category = JOB_CAT_SECURITY,
			slots = 2,
		),
		list(
			name = "Cousin",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)

/datum/ship_theme/phalanx/verdant
	id = "verdant"
	name = "Verdant"
	desc = "A terraforming detachment retired without giving the ship back, \
		and planted her instead: turf down the central hall, planters in every \
		corner, and a chapel that has quietly become a grove. The guns are \
		long gone. The gardens are armed to the teeth."
	part_cost = list(PART_CLASS_SCIENCE = 12)
	template_suffix = "nano_phalanx_c"
	upgrade_slot_ids = list(
		"phalanx_bay_north",
		"phalanx_bay_south",
		"phalanx_lab",
		"phalanx_medical",
		"phalanx_armory",
	)
	job_slots = list(
		list(
			name = "Caretaker",
			officer = TRUE,
			outfit = /datum/outfit/job/captain,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Arborist",
			outfit = /datum/outfit/job/botanist,
			category = JOB_CAT_SERVICE,
			slots = 2,
		),
		list(
			name = "Groundskeeper",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Climate Technician",
			outfit = /datum/outfit/job/atmos,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Herbalist",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Cook",
			outfit = /datum/outfit/job/cook,
			category = JOB_CAT_SERVICE,
			slots = 1,
		),
		list(
			name = "Ranger",
			outfit = /datum/outfit/job/security,
			category = JOB_CAT_SECURITY,
			slots = 2,
		),
		list(
			name = "Fieldhand",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

/datum/ship_theme/phalanx/springs
	id = "springs"
	name = "The Springs"
	desc = "A retired atmospheric technician re-plumbed the gun decks into a \
		travelling bathhouse: hot pools where the mess used to be, lanterns in \
		the halls, towels by the airlock, and the only working showers in the \
		fleet. The plasma heaters keep the water at a perfect 41 degrees."
	part_cost = list(PART_CLASS_MISC = 12)
	template_suffix = "nano_phalanx_d"
	upgrade_slot_ids = list(
		"phalanx_bay_north",
		"phalanx_bay_south",
		"phalanx_lab",
		"phalanx_medical",
		"phalanx_armory",
	)
	job_slots = list(
		list(
			name = "Proprietor",
			officer = TRUE,
			outfit = /datum/outfit/job/captain,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Shrinekeeper",
			outfit = /datum/outfit/job/chaplain,
			category = JOB_CAT_SERVICE,
			slots = 1,
		),
		list(
			name = "Boilermaster",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Steamfitter",
			outfit = /datum/outfit/job/atmos,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "House Physician",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Tea Master",
			outfit = /datum/outfit/job/cook,
			category = JOB_CAT_SERVICE,
			slots = 1,
		),
		list(
			name = "Doorman",
			outfit = /datum/outfit/job/security,
			category = JOB_CAT_SECURITY,
			slots = 2,
		),
		list(
			name = "Guest",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)
