// ========== DELTA MODULES ==========
//
// Slot geometry (BYOND coords on the 28x17 hull, origin bottom-left):
//
//   delta_cargo   x20-26 y2-6   35 tiles  marker (20,2)   OPEN
//     The starboard hold interior. Hull keeps the x19 service column (EVA
//     airlock, APC, air alarm, fire alarm) and the in-pocket vent (22,4) /
//     scrubber (23,4) — modules leave those two tiles walkable and place NO
//     infrastructure of their own. Keep (20,4) open (west entry lane) and
//     the whole x26 face at y3-5 open and unwalled (blast-hatch approach;
//     the x27 hatch, fans and buttons are hull). (21,1)/(25,1) south and
//     (21,7)/(25,7) north are shuttered windows — no wallmounts facing them.
//
//   delta_cafe    x20-26 y12-16  35 tiles  marker (20,12)  OPEN
//     The port wing interior. Mirror of the hold: hull keeps the x19 service
//     column and the in-pocket vent (22,14) / scrubber (23,14). Keep (20,14)
//     open (west entry lane). The wing tip at x25-26 y13-16 is the hull's
//     ruin scar — the default diner preserves it. Shuttered windows at
//     (21,11)/(25,11) south and (21,17)/(25,17) north.
//
//   delta_med     x9-14 y2-4    18 tiles  marker (9,2)    OPEN
//     The medbay interior. Hull keeps the x8 strip (medvendor, APC, air
//     alarm, fire alarm) and the in-pocket vent (12,3) / scrubber (13,3).
//     Keep (12,4)/(13,4) open (hallway doors) and (14,4) open (east EVA).
//     The hull's defibrillator did not survive the carve, so EVERY med
//     module ships one /obj/machinery/defibrillator_mount/loaded.
//
//   delta_dorms   x9-14 y14-16  18 tiles  marker (9,14)   RESERVE (14,16)
//     The crew deck interior. (14,16) is /turf/template_noop in every
//     module: the hull keeps a cryopod + cryopod console + the dorms APC
//     there, so the bare hull is always joinable. Hull vent/scrubber sit
//     just outside the pocket at (9,13). Every dorms module ships at least
//     2 more cryopods and 2 beds. The whole y14 row is a real corridor
//     ((7,14) west door -> south doors -> (15,14) east EVA): modules keep
//     it entirely furniture-free, leaving 11 usable content tiles.
//
// The hull owns ALL slot infrastructure (power, atmos, alarms). Modules
// ship zero pipe/cable/APC/alarm content; the only sanctioned exception is
// a fully self-contained closed loop (the Cryo Ward's cryotube + freezer).

/datum/ship_upgrade_module/delta
	for_ship = /datum/map_template/shuttle/voidcrew/delta
	// Modules are shared across all four themes; themed reskins are per-dmm
	// (the loader falls back from <base>_<theme>.dmm to map_file)
	for_theme = list("salvage", "market", "archive", "lightship")

// -- delta_cargo: the starboard hold.

/datum/ship_upgrade_module/delta/cargo_salvage
	id = "delta_cargo_salvage"
	name = "Salvage Hold"
	desc = "A working salvager's hold: crate stack, cutting and fulton gear \
		on the rack, a charger bench, and the manifest desk where the \
		quartermaster keeps score."
	slot = "delta_cargo"
	map_file = "delta/delta_cargo_salvage.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/delta/cargo_mining
	id = "delta_cargo_mining"
	name = "Mining Bay"
	desc = "Ore redemption machine, mining lockers and an ore box - the \
		fittings this hull's miner berths never had. Adds two Shaft Miners \
		to the crew."
	slot = "delta_cargo"
	map_file = "delta/delta_cargo_mining.dmm"
	part_cost = list(PART_CLASS_TRADE = 6)
	job_slots_add = list(
		list(
			name = "Shaft Miner",
			outfit = /datum/outfit/job/miner,
			category = JOB_CAT_CARGO,
			slots = 2,
		),
	)

/datum/ship_upgrade_module/delta/cargo_gundeck
	id = "delta_cargo_gundeck"
	name = "Gun Deck"
	desc = "Security lockers, an energy gun rack with a recharger, and a \
		desk for whoever minds the old hull turrets. Adds a Security \
		Officer to the crew."
	slot = "delta_cargo"
	map_file = "delta/delta_cargo_gundeck.dmm"
	part_cost = list(PART_CLASS_COMBAT = 10)
	job_slots_add = list(
		list(
			name = "Security Officer",
			outfit = /datum/outfit/job/security,
			category = JOB_CAT_SECURITY,
			slots = 1,
		),
	)

// -- delta_cafe: the port wing.

/datum/ship_upgrade_module/delta/cafe_diner
	id = "delta_cafe_diner"
	name = "Galley Diner"
	desc = "The rust-red checkered diner: kitchen and bar at one end, and \
		the wing's unrepaired wreckage at the other. Adds a Cook to the \
		crew."
	slot = "delta_cafe"
	map_file = "delta/delta_cafe_diner.dmm"
	is_default = TRUE
	job_slots_add = list(
		list(
			name = "Cook",
			outfit = /datum/outfit/job/cook,
			category = JOB_CAT_SERVICE,
			slots = 1,
		),
	)

/datum/ship_upgrade_module/delta/cafe_greenhouse
	id = "delta_cafe_greenhouse"
	name = "Greenhouse Cafe"
	desc = "Hydroponics trays on real soil under grow lights, a seed vendor \
		and a biogenerator. Adds a Botanist to the crew."
	slot = "delta_cafe"
	map_file = "delta/delta_cafe_greenhouse.dmm"
	part_cost = list(PART_CLASS_TRADE = 6)
	job_slots_add = list(
		list(
			name = "Botanist",
			outfit = /datum/outfit/job/botanist,
			category = JOB_CAT_SERVICE,
			slots = 1,
		),
	)

/datum/ship_upgrade_module/delta/cafe_shop
	id = "delta_cafe_shop"
	name = "Machine Shop"
	desc = "A workbench row with a techfab, a circuit imprinter and parts \
		racks. Adds a Scientist to the crew."
	slot = "delta_cafe"
	map_file = "delta/delta_cafe_shop.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 6)
	job_slots_add = list(
		list(
			name = "Scientist",
			outfit = /datum/outfit/job/scientist,
			category = JOB_CAT_SCIENCE,
			slots = 1,
		),
	)

// -- delta_med: the medbay.

/datum/ship_upgrade_module/delta/med_clinic
	id = "delta_med_clinic"
	name = "Field Clinic"
	desc = "Stasis bed, operating table, defibrillator and an IV drip - a \
		clinic sized for a small crew's bad days."
	slot = "delta_med"
	map_file = "delta/delta_med_clinic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/delta/med_chem
	id = "delta_med_chem"
	name = "Chemistry Annex"
	desc = "Chem dispenser, ChemMaster and heater behind a counter, with a \
		smartfridge for the output. Adds a Chemist to the crew."
	slot = "delta_med"
	map_file = "delta/delta_med_chem.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 6)
	job_slots_add = list(
		list(
			name = "Chemist",
			outfit = /datum/outfit/job/chemist,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
	)

/datum/ship_upgrade_module/delta/med_cryo
	id = "delta_med_cryo"
	name = "Cryo Ward"
	desc = "A cryotube on its own sealed loop, a recovery bed and a sleeper. \
		Adds a Paramedic to the crew."
	slot = "delta_med"
	map_file = "delta/delta_med_cryo.dmm"
	part_cost = list(PART_CLASS_MISC = 6)
	job_slots_add = list(
		list(
			name = "Paramedic",
			outfit = /datum/outfit/job/paramedic,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
	)

// -- delta_dorms: the crew deck.

/datum/ship_upgrade_module/delta/dorms_cabins
	id = "delta_dorms_cabins"
	name = "Crew Cabins"
	desc = "Two snug cabins, lockers, a small washroom and two cryopods."
	slot = "delta_dorms"
	map_file = "delta/delta_dorms_cabins.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/delta/dorms_bunkhouse
	id = "delta_dorms_bunkhouse"
	name = "Bunkhouse"
	desc = "Bunk rows, a locker wall and three cryopods - room for more \
		hands. Adds two Assistants to the crew."
	slot = "delta_dorms"
	map_file = "delta/delta_dorms_bunkhouse.dmm"
	part_cost = list(PART_CLASS_MISC = 6)
	job_slots_add = list(
		list(
			name = "Assistant",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

/datum/ship_upgrade_module/delta/dorms_den
	id = "delta_dorms_den"
	name = "The Den"
	desc = "The crew's living room: a proper couch, a game table, a jukebox \
		and a shelf of someone's things, with a sleeping nook at the back."
	slot = "delta_dorms"
	map_file = "delta/delta_dorms_den.dmm"
	part_cost = list(PART_CLASS_MISC = 3)

// ========== DELTA THEMES ==========

/datum/ship_theme/delta
	for_ship = /datum/map_template/shuttle/voidcrew/delta

/datum/ship_theme/delta/salvage
	id = "salvage"
	name = "Salvage Claim"
	desc = "The frigate as the salvage crew that claimed her keeps her: \
		re-lit, patched where it matters, and dusty where it doesn't. Nobody \
		has scrubbed the old crew's story off the deck, and nobody is in a \
		hurry to."
	is_default = TRUE
	template_suffix = "delta_a"
	upgrade_slot_ids = list(
		"delta_cargo",
		"delta_cafe",
		"delta_med",
		"delta_dorms",
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
			name = "Quartermaster",
			outfit = /datum/outfit/job/quartermaster,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Medical Doctor",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Station Engineer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Assistant",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)

/datum/ship_theme/delta/market
	id = "market"
	name = "The Night Market"
	desc = "A hawker family bought the wreck at auction, strung her bow to \
		stern with lanterns, and reopened the mess deck as a night market. \
		Regulars dock for noodles and stay for the gossip; the kitchen has \
		not fully closed in six years."
	part_cost = list(PART_CLASS_TRADE = 9)
	template_suffix = "delta_b"
	upgrade_slot_ids = list(
		"delta_cargo",
		"delta_cafe",
		"delta_med",
		"delta_dorms",
	)
	job_slots = list(
		list(
			name = "Market Boss",
			officer = TRUE,
			outfit = /datum/outfit/job/captain,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Purser",
			outfit = /datum/outfit/job/quartermaster,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Street Doctor",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Fixer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Hawker",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)

/datum/ship_theme/delta/archive
	id = "archive"
	name = "The Stacks"
	desc = "A travelling archive crewed by people who catalogue what the \
		void leaves behind. Shelves line the corridors, the reading lamps \
		stay lit through the night watch, and the ship's own salvage report \
		hangs framed by the bridge door."
	part_cost = list(PART_CLASS_SCIENCE = 9)
	template_suffix = "delta_c"
	upgrade_slot_ids = list(
		"delta_cargo",
		"delta_cafe",
		"delta_med",
		"delta_dorms",
	)
	job_slots = list(
		list(
			name = "Head Archivist",
			officer = TRUE,
			outfit = /datum/outfit/job/captain,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Registrar",
			outfit = /datum/outfit/job/quartermaster,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Ship's Physician",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Stacks Engineer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Page",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)

/datum/ship_theme/delta/lightship
	id = "lightship"
	name = "The Lightship"
	desc = "A volunteer rescue crew stripped the dust out, repainted the \
		hull markings, and lit every deck for the first time in years. She \
		answers maydays now. The kettle in the mess is always warm, and the \
		bell by the airlock rings every time a rescue comes home."
	part_cost = list(PART_CLASS_MISC = 9)
	template_suffix = "delta_d"
	upgrade_slot_ids = list(
		"delta_cargo",
		"delta_cafe",
		"delta_med",
		"delta_dorms",
	)
	job_slots = list(
		list(
			name = "Stationmaster",
			officer = TRUE,
			outfit = /datum/outfit/job/captain,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Storekeeper",
			outfit = /datum/outfit/job/quartermaster,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Lifeboat Medic",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Keeper",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Volunteer",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)
