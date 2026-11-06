/// Backgrounds: owned by M3.

// ========== CORSAIR MODULES ==========

/datum/ship_upgrade_module/corsair
	for_ship = /datum/map_template/shuttle/voidcrew/corsair
	// Both themes share one geometry; the loader falls back from <base>_<theme>.dmm to map_file
	for_theme = list("rogue", "privateer")

// -- corsair_hold: the hold (5x4 enclosed room, hull x7..11 y10..13).
// Marker /obj/modular_map_root/ship_upgrade{key = "corsair_hold"} on hull (7,10), the room's
// SW corner; the module's /obj/modular_map_connector sits on its own (1,1).
// Module tile (mx,my) lands on hull (mx + 6, my + 9).
//
// The hull gives this room nothing but floor, walls and two bulbs: (7,13) on the west
// wall and (11,10) on the east wall (module (1,4) and (5,1)). Every module MUST ship its
// own APC, air alarm, vent and scrubber, and use /area/template_noop throughout.
//
// WALL MOUNTS - the south wall (y9) carries the keel's sign, bulb and APC on
// its far side, so mount nothing on module row 1 facing south. The west (x6), north (y14)
// and east (x12) walls are free apart from the two hull bulbs above.
//
// The only door is the hull's "Hold" hatch at (9,9), just below module (3,1). That door
// tile carries the boundary stub: cable + supply (layer 4) + scrubbers (layer 2). Land
// the module's cable and pipes on module (3,1); a vent and scrubber there facing south
// (dir 2) connect with no pipe of their own.
//
// DOOR APPROACH - module (3,1), hull (9,10), is the only tile inside the hold door.
// Never put anything dense on it.

/datum/ship_upgrade_module/corsair/hold_smuggler
	id = "corsair_hold_smuggler"
	name = "Smuggler's Hold"
	desc = "Racks, crates and room for more."
	slot = "corsair_hold"
	map_file = "corsair/corsair_hold_smuggler.dmm"
	is_default = TRUE

// The lockup partitions a 2x2 cell (module x4..5, y3..4) behind the brig door at module
// (4,2). Its vent and scrubber are piped under the partition wall at (5,2). The privateer
// reskin only swaps the partition walls to rust.
/datum/ship_upgrade_module/corsair/hold_lockup
	id = "corsair_hold_lockup"
	name = "Lockup"
	desc = "One cell behind a brig door."
	slot = "corsair_hold"
	map_file = "corsair/corsair_hold_lockup.dmm"
	part_cost = list(PART_CLASS_COMBAT = 3)

// ========== CORSAIR THEMES ==========

/datum/ship_theme/corsair
	for_ship = /datum/map_template/shuttle/voidcrew/corsair
	job_slots = list(
		list(
			name = "Captain",
			officer = TRUE,
			outfit = /datum/outfit/job/captain/pirate,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "First Mate",
			outfit = /datum/outfit/job/hop/pirate,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Buccaneer",
			outfit = /datum/outfit/job/security/pirate,
			category = JOB_CAT_SECURITY,
			slots = 2,
		),
		list(
			name = "Motorman",
			outfit = /datum/outfit/job/engineer/pirate,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Sawbones",
			outfit = /datum/outfit/job/doctor/pirate,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Deckhand",
			outfit = /datum/outfit/job/assistant/pirate,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

/datum/ship_theme/corsair/rogue
	id = "rogue"
	name = "Rogue"
	desc = "Black plate, small bulbs and a crew that keeps the guns clean."
	is_default = TRUE
	template_suffix = "corsair_a"

/datum/ship_theme/corsair/privateer
	id = "privateer"
	name = "Privateer"
	desc = "Rust, bare plating and whatever light still works."
	part_cost = list(PART_CLASS_COMBAT = 4)
	template_suffix = "corsair_b"
