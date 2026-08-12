// ========== KILO MODULES ==========

/datum/ship_upgrade_module/kilo
	for_ship = /datum/map_template/shuttle/voidcrew/kilo
	// All kilo modules are shared across all four themes; themed reskins are
	// per-dmm (the loader falls back from <base>_<theme>.dmm to map_file)
	for_theme = list("tramp", "saloon", "pink", "clean")

// -- kilo_service: the cafe box (4x4, enclosed room). Modules for this slot
// MUST ship their own APC, air alarm, vent and scrubber - the hull provides none.
//
// DOOR APPROACHES - do not put a dense structure on these. Each is the ONLY
// tile on its side of a door; blocking one strands whatever is behind it:
//   (12,4) cafe side of the dorms airlock (13,4)  - dorms holds all 3 cryopods
//   (11,5) cafe side of the "Ship Services" airlock (11,6) -> cargo
// The pocket must also stay internally connected: row y4 is the room's only
// cross-corridor, so a structure on (10,4) cuts the west column off from the
// east one even though the flood fill still shows the ship as whole.

/datum/ship_upgrade_module/kilo/service_galley
	id = "kilo_service_galley"
	name = "Galley"
	desc = "The classic NTMS crew cafeteria: kitchen line, lounge corner, \
		and a boozeomat that has seen things."
	slot = "kilo_service"
	map_file = "kilo/kilo_service_galley.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/kilo/service_hydroponics
	id = "kilo_service_hydroponics"
	name = "Hydroponics Bay"
	desc = "Three hydroponics trays, a seed vendor and a biogenerator on a \
		genuine grass lawn. Adds a Botanist to the crew."
	slot = "kilo_service"
	map_file = "kilo/kilo_service_hydroponics.dmm"
	part_cost = list(PART_CLASS_TRADE = 5)
	job_slots_add = list(
		list(
			name = "Botanist",
			outfit = /datum/outfit/job/botanist,
			category = JOB_CAT_SERVICE,
			slots = 1,
		),
	)

/datum/ship_upgrade_module/kilo/service_surgery
	id = "kilo_service_surgery"
	name = "Surgical Suite"
	desc = "Operating table, stasis bed, sleeper and morgue - everything the \
		frontier's finest needs. Adds a Ship's Doctor to the crew."
	slot = "kilo_service"
	map_file = "kilo/kilo_service_surgery.dmm"
	part_cost = list(PART_CLASS_MISC = 5)
	job_slots_add = list(
		list(
			name = "Ship's Doctor",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
	)

/datum/ship_upgrade_module/kilo/service_saloon_bar
	id = "kilo_service_saloon_bar"
	name = "Saloon Bar"
	desc = "A proper frontier watering hole: jukebox, card table, keg \
		and a fully stocked bar."
	slot = "kilo_service"
	map_file = "kilo/kilo_service_saloon_bar.dmm"
	part_cost = list(PART_CLASS_TRADE = 3)

// -- kilo_dock: the mining prep strip (3x2, open pocket in the Mining Dock).
// The hull owns the room's APC and air alarm, and keeps it air-covered with no
// module loaded (vent + scrubber at (4,10)). Dock modules must NOT place an APC
// or an area; they add a scrubber at (5,10) and a vent at (6,10) over the strip
// itself, and connect those plus their cable south to the y9 trunk row.

/datum/ship_upgrade_module/kilo/dock_prep
	id = "kilo_dock_prep"
	name = "Mining Prep"
	desc = "Autolathe and a fully stocked materials bench - the standard \
		asteroid-mining fabrication kit."
	slot = "kilo_dock"
	map_file = "kilo/kilo_dock_prep.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/kilo/dock_refinery
	id = "kilo_dock_refinery"
	name = "Ore Refinery"
	desc = "An ore redemption machine installed right beside the standard \
		autolathe - smelt your haul and print your parts without hauling \
		either home."
	slot = "kilo_dock"
	map_file = "kilo/kilo_dock_refinery.dmm"
	part_cost = list(PART_CLASS_TRADE = 9)

// -- kilo_hold: the cargo east pocket (3x3 minus two wall tiles, open pocket).
// Hull APC/air alarm cover it. Two lanes must stay walkable:
//   (13,9)/(14,9) - the cargo->engineering corridor. Measured: these two are
//                   the load-bearing tiles; blocking either strands ~20 tiles.
//                   (13,8) is a dead-end alcove off the lane and IS free to use.
//   (12,8)        - links the "Ship Services" door corridor (11,6)-(11,8) into
//                   the cargo bay. With (11,5) also blocked the corridor seals.
// Current modules occupy (12,7), (12,9) and (14,8), which clears both lanes.

/datum/ship_upgrade_module/kilo/hold_freight
	id = "kilo_hold_freight"
	name = "Freight Stowage"
	desc = "Crates, the mining kit and the emergency internals stash."
	slot = "kilo_hold"
	map_file = "kilo/kilo_hold_freight.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/kilo/hold_eva
	id = "kilo_hold_eva"
	name = "Salvage Bay"
	desc = "An extra EVA suit, a recharging bench and a salvage rack: plasma \
		cutter, fulton extraction rig and mining GPS."
	slot = "kilo_hold"
	map_file = "kilo/kilo_hold_eva.dmm"
	part_cost = list(PART_CLASS_COMBAT = 5)

/datum/ship_upgrade_module/kilo/hold_vault
	id = "kilo_hold_vault"
	name = "Secure Stowage"
	desc = "A personal locker, a secure crate and a floor safe for cargo you \
		would rather keep."
	slot = "kilo_hold"
	map_file = "kilo/kilo_hold_vault.dmm"
	part_cost = list(PART_CLASS_MISC = 3)

// ========== KILO THEMES ==========

/datum/ship_theme/kilo
	for_ship = /datum/map_template/shuttle/voidcrew/kilo

/datum/ship_theme/kilo/tramp
	id = "tramp"
	name = "Dust Hauler"
	desc = "The NTMS-037 as she flies: safety-yellow mining dock, duty-blue \
		bridge, and twenty years of grime nobody is paid enough to scrub."
	is_default = TRUE
	template_suffix = "kilo_a"
	upgrade_slot_ids = list(
		"kilo_service",
		"kilo_dock",
		"kilo_hold",
	)
	job_slots = list(
		list(
			name = "Captain",
			officer = TRUE,
			outfit = /datum/outfit/job/captain/western,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Foreman",
			outfit = /datum/outfit/job/quartermaster/western,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Ship's Engineer",
			outfit = /datum/outfit/job/engineer/western,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Asteroid Miner",
			outfit = /datum/outfit/job/miner/western,
			category = JOB_CAT_CARGO,
			slots = 2,
		),
		list(
			name = "Deckhand",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

// The saloon hull parks a beerkeg on (10,9), which is the cargo bay's half of
// the fore/aft route - so on THIS hull the "Ship Services" corridor
// (11,5)-(11,6)-(11,7)-(11,8)-(12,8) is the only other way aft. Keep that
// corridor clear or the ship splits in two. The keg has nowhere better to go:
// the only tiles that stay safe under every fitout are the piano stool (10,7),
// which would make the piano unreachable, and (11,12), the docking airlock's
// vestibule.
/datum/ship_theme/kilo/saloon
	id = "saloon"
	name = "Saloon"
	desc = "A full timber refit, bow to stern: wooden walls and swinging doors \
		throughout, a piano hall in the cargo bay, and a card game running in \
		the galley. Only the engine block is still iron. Comes with a Barkeep \
		on the manifest."
	part_cost = list(PART_CLASS_TRADE = 8)
	template_suffix = "kilo_b"
	upgrade_slot_ids = list(
		"kilo_service",
		"kilo_dock",
		"kilo_hold",
	)
	job_slots = list(
		list(
			name = "Captain",
			officer = TRUE,
			outfit = /datum/outfit/job/captain/western,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Barkeep",
			outfit = /datum/outfit/job/bartender,
			category = JOB_CAT_SERVICE,
			slots = 1,
		),
		list(
			name = "Foreman",
			outfit = /datum/outfit/job/quartermaster/western,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Ship's Engineer",
			outfit = /datum/outfit/job/engineer/western,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Asteroid Miner",
			outfit = /datum/outfit/job/miner/western,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Deckhand",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

// WALLS ARE INTENTIONALLY STOCK ON THIS THEME - do not "fix" this.
// Audits keep flagging that clean repaints 0 of the hull's 76 wall turfs while
// saloon and pink each repaint 70. That is deliberate and matches the desc:
// clean promises "white composite decking" - decking is the FLOOR, and the text
// never mentions bulkheads. Compare pink ("Pastel bulkheads") and saloon
// ("wooden walls and swinging doors throughout"), which do promise walls and do
// repaint them. Pink pays for that with a bespoke recoloured wall .dmi plus a
// matching falsewall subtype; there is no stock white/clean titanium wall, so
// giving clean painted bulkheads would mean authoring new wall art for a
// promise the theme never makes. Clean's identity is delivered by the decking
// (72 white floor tiles, two-tone since 2026-08) and by zero grime.
/datum/ship_theme/kilo/clean
	id = "clean"
	name = "Factory Fresh"
	desc = "Straight out of the Nanotrasen refit yard: white composite decking, \
		working consoles, a corporate art programme and not one speck of dust. \
		The warranty seal is still on the airlock."
	part_cost = list(PART_CLASS_TRADE = 8)
	template_suffix = "kilo_d"
	upgrade_slot_ids = list(
		"kilo_service",
		"kilo_dock",
		"kilo_hold",
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
			name = "Site Overseer",
			outfit = /datum/outfit/job/quartermaster,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Systems Engineer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Extraction Specialist",
			outfit = /datum/outfit/job/miner,
			category = JOB_CAT_CARGO,
			slots = 2,
		),
		list(
			name = "Junior Associate",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

/datum/ship_theme/kilo/pink
	id = "pink"
	name = "Dollhouse"
	desc = "Pastel bulkheads, a checkerboard tea room, a plushie on every \
		shelf and a Princess Suite that smells like strawberries. The void \
		has never been this cute."
	part_cost = list(PART_CLASS_MISC = 8)
	template_suffix = "kilo_c"
	upgrade_slot_ids = list(
		"kilo_service",
		"kilo_dock",
		"kilo_hold",
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
			name = "Big Sis",
			outfit = /datum/outfit/job/quartermaster,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Glitter Engineer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Gem Hunter",
			outfit = /datum/outfit/job/miner,
			category = JOB_CAT_CARGO,
			slots = 2,
		),
		list(
			name = "Bestie",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)
