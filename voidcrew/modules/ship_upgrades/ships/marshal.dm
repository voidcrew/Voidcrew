/// Backgrounds: owned by M2. See data/backgrounds/spec.md.

// ========== MARSHAL MODULES ==========

/datum/ship_upgrade_module/marshal
	for_ship = /datum/map_template/shuttle/voidcrew/marshal
	// Both modules are shared across both themes. The base map is the Lawman dressing; the
	// Bondsman loads its <base>_bondsman.dmm reskin (tube light, steel furniture).
	for_theme = list("lawman", "bondsman")

// -- marshal_bay: the Ready Room (4x4, enclosed room, hull x9-12 y2-5). Modules for this slot
// MUST ship their own APC, air alarm, vent and scrubber - the hull provides none, and flies
// with the slot empty.
//
// Hull marker /obj/modular_map_root/ship_upgrade{key = "marshal_bay"} at (9,2), the room's SW
// tile. Every module's /obj/modular_map_connector sits on module (1,1), so module (x,y) lands
// on hull (8+x, 1+y).
//
// The hull drops a stub through the Ready Room door (11,6) onto (11,5) = module (3,4): cable,
// supply pipe (layer 4) and scrubber pipe (layer 2). Modules connect to it like this:
//   APC          module (1,2), west wall; cable (1,2) -> (1,3) -> (1,4) -> (2,4) meets the stub
//   vent         module (2,4), layer 4, dir EAST onto the stub
//   scrubber     module (4,4), layer 2, dir WEST onto the stub
//   air alarm    module (4,4), east wall
// DOOR APPROACH - module (3,4) / hull (11,5) is the only tile inside the Ready Room door. Put
// nothing on it: no structure, pipe, cable or machine (the hull's stub is already there).

/datum/ship_upgrade_module/marshal/bay_armory
	id = "marshal_bay_armory"
	name = "Armory"
	desc = "A weapon recharger, two security lockers and a rack."
	slot = "marshal_bay"
	map_file = "marshal/marshal_bay_armory.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/marshal/bay_tracking
	id = "marshal_bay_tracking"
	name = "Tracking Room"
	desc = "A crew monitor, a prisoner management console and a desk."
	slot = "marshal_bay"
	map_file = "marshal/marshal_bay_tracking.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 3)

// ========== MARSHAL THEMES ==========

/datum/ship_theme/marshal
	for_ship = /datum/map_template/shuttle/voidcrew/marshal

/datum/ship_theme/marshal/lawman
	id = "lawman"
	name = "Lawman"
	desc = "Wood floors, warm bulbs and curtained bunks."
	is_default = TRUE
	template_suffix = "marshal_a"
	job_slots = list(
		list(
			name = "Marshal",
			officer = TRUE,
			outfit = /datum/outfit/job/captain/bounty_hunter,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Deputy",
			outfit = /datum/outfit/job/security/bounty_hunter,
			category = JOB_CAT_SECURITY,
			slots = 3,
		),
		list(
			name = "Mechanic",
			outfit = /datum/outfit/job/engineer/bounty_hunter,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Tracker",
			outfit = /datum/outfit/job/assistant/bounty_hunter,
			category = JOB_CAT_ASSISTANT,
			slots = 1,
		),
	)

/datum/ship_theme/marshal/bondsman
	id = "bondsman"
	name = "Bondsman"
	desc = "Titanium decks, white tubes and a red-trimmed holding block."
	part_cost = list(PART_CLASS_COMBAT = 4)
	template_suffix = "marshal_b"
	job_slots = list(
		list(
			name = "Marshal",
			officer = TRUE,
			outfit = /datum/outfit/job/captain/bounty_hunter,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Deputy",
			outfit = /datum/outfit/job/security/bounty_hunter,
			category = JOB_CAT_SECURITY,
			slots = 3,
		),
		list(
			name = "Mechanic",
			outfit = /datum/outfit/job/engineer/bounty_hunter,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Tracker",
			outfit = /datum/outfit/job/assistant/bounty_hunter,
			category = JOB_CAT_ASSISTANT,
			slots = 1,
		),
	)
