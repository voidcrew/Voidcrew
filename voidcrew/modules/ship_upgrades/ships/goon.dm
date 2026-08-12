// ========== GOON MODULES ==========
//
// Slot geometry (BYOND coords on the 19x11 hull, origin bottom-left):
//
//   goon_port         x2-7  y7-9   18 tiles   marker (2,7)
//     reserve (7,7) with /turf/template_noop - hull APC + light live there.
//     PALETTE SEAM: because (7,7) is noop, its FLOOR is the hull's, and each
//     hull floors it in that theme's palette (a/b titanium/blue, c
//     plastitanium/red, d iron/dollhouse) to match the hull's other port-pod
//     tiles (3,10),(4,10),(8,8). A module whose room palette differs will show
//     that one tile in the hull's colour, in the corner where the APC is. The
//     three current modules already disagree with each other - infirmary and
//     chemlab floor titanium/blue, brig floors plain titanium - so no single
//     hull turf can match them all. Match titanium/blue if you want the seam
//     to vanish on the two NT themes; on c/d it cannot vanish without a
//     goon_port_<theme>.dmm variant.
//     Hull (6,7) borders the engine-room porthole at (6,6): a HARD-dense machine
//     there leaves that window tile with no approach and the linter flags it. A
//     closet or bare floor is fine. Keep hull (3,10) reachable too - the volume
//     pump and SMES terminal there are only approachable through (3,9).
//     Hull owns the y8 service spine (4,8)-(7,8): cable, pipes, and the pod's
//     vent + scrubber at (7,8). Row y10 is permanent hull (engine heater,
//     SMES terminal, the medkit hatch at (4,10)) - keep (4,9) walkable so the
//     hatch can be reached.
//
//   goon_engineering  x4-7  y3-5   12 tiles   marker (4,3)
//     reserve (7,3) with /turf/template_noop - hull APC + tool crate.
//     PALETTE SEAM: as with (7,7), the hull owns this tile's floor and each
//     hull matches its own engine-room tiles (3,2)-(3,5),(4,2),(8,4) - a
//     titanium/yellow, b titanium/blue, c plastitanium, d iron/dollhouse. All
//     three current modules floor titanium/yellow, so the seam is invisible on
//     a and visible on b/c/d. Do not "fix" it by repainting the hull tile: it
//     would then be the only engine-room floor tile in that hull not matching
//     the rest. The fix is a themed module variant.
//     Hull owns the APC cable run (4,3)-(6,3) and the ship's distro main on
//     y4 (4,4)-(7,4), including the scrubber at (6,4).
//     EVERY module here must ship a complete power plant - this slot is the
//     ship's only power source, so a module that forgets one strands the hull.
//
//   goon_mining       x11-14 y7-9  12 tiles   marker (11,7)
//     Hull owns the waste riser up column 12 (12,7)-(12,9) feeding the
//     exterior injector at (12,11), and the commons vent at (10,8) beside it.
//     Don't wall column 12.
//
//   goon_lounge       x11-13 y3-5   9 tiles   marker (11,3)
//     Hull owns the atmos spur at (11,4),(12,4). Keep an opening on the west
//     edge at (11,4) so the pocket connects to the corridor.
//     Column 13 is the cryopods' fire escape: NOTHING DENSE on (13,4) or
//     (13,5). Both pods are walled in on three sides by permanent hull - the
//     pod at (14,4) by the bridge window, the wall at (14,3) and the pod above
//     it; the pod at (14,5) by the bridge wall, the pod below it, and its own
//     north-facing survival-pod window - so column 13 is the ONLY way out of
//     either. A dense object there seals a spawning player in for good, and
//     the pod at (14,5) is the one people actually land in. This is not
//     hypothetical: goon_lounge_mess shipped a griddle on (13,5) and did
//     exactly that.
//
//   goon_cockpit      x17-18 y5-7   6 tiles   marker (17,5)
//     EVERY module here must ship a helm console. Column 16 (APC, vent,
//     scrubber, air alarm, supply trunk) and the docking port at (19,6) are
//     permanent hull.
//     The hull keeps MOVABLES on three of these six tiles and the module
//     stacks on top of them rather than replacing them: mission_pad (17,5),
//     computer/mission_board (18,5), and - on goon_a only - the captain's
//     beeplushie at (17,6), which is the standard theme's documented signature
//     and so must not live in a shared module. Don't put a dense object on
//     (17,5) or (18,5), and expect (17,6) to already hold an item.
//     The hull also owns the glazing: (19,5)-(19,7) east, (18,4) south and
//     (18,8) north are all fulltile shuttle windows. The modules additionally
//     place directional window spawners facing each of those five, which is
//     inherited verbatim from the pre-modular ship_goon.dmm and matches the
//     hull's own idiom at (16,4)/(16,8) - it is deliberate double glazing, not
//     a duplicate. Leave it.
//
// No slot has its own area - each rides the APC of the hull area it was carved
// from, so no module may place an APC.
//
// SAFETY INVARIANT: unlike kilo, goon's bare hull does NOT fly on its own. The
// helm lives in goon_cockpit and the generators live in goon_engineering, so the
// `is_default = TRUE` flags on goon_cockpit_standard and goon_engineering_pacman
// are load-bearing: the loader falls back to the slot's default whenever a player
// has selected nothing (modular_map_root_ship.dm), and that fallback is the only
// thing guaranteeing a helm and a power plant. Never leave either of those two
// slots without exactly one defaulted module, and never ship a module for them
// that lacks a helm / a complete power plant.
// What IS permanent on the bare hull: both cryopods (14,4),(14,5) - so spawn
// points never depend on a module loading - all four APCs, all four thrusters,
// both engine heaters, two of the three SMES, and every pipe/cable trunk.

/datum/ship_upgrade_module/goon
	for_ship = /datum/map_template/shuttle/voidcrew/goon
	// Modules are shared across all four themes; themed reskins are per-dmm
	// (the loader falls back from <base>_<theme>.dmm to map_file)
	for_theme = list("standard", "void", "syndicate", "slumber")

// -- goon_port: the port pod, the ship's one big enclosed room.

/datum/ship_upgrade_module/goon/port_infirmary
	id = "goon_port_infirmary"
	name = "Infirmary"
	desc = "Operating table, stasis bed and a stocked medicine cabinet. The \
		shuttle's original sickbay, near enough."
	slot = "goon_port"
	map_file = "goon/goon_port_infirmary.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/goon/port_brig
	id = "goon_port_brig"
	name = "Brig Block"
	desc = "Two holding cells, an evidence locker and a security records \
		console. Adds a Master-at-Arms to the crew."
	slot = "goon_port"
	map_file = "goon/goon_port_brig.dmm"
	part_cost = list(PART_CLASS_COMBAT = 4)
	job_slots_add = list(
		list(
			name = "Master-at-Arms",
			outfit = /datum/outfit/job/security,
			category = JOB_CAT_SECURITY,
			slots = 1,
		),
	)

/datum/ship_upgrade_module/goon/port_chemlab
	id = "goon_port_chemlab"
	name = "Chem Lab"
	desc = "Chem dispenser, ChemMaster and a pill press behind a proper \
		counter. Adds a Chemist to the crew."
	slot = "goon_port"
	map_file = "goon/goon_port_chemlab.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 4)
	job_slots_add = list(
		list(
			name = "Chemist",
			outfit = /datum/outfit/job/chemist,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
	)

// -- goon_engineering: the ship's only power source. Every module needs a
// generator, a SMES and something to fuel it.

/datum/ship_upgrade_module/goon/engineering_pacman
	id = "goon_engineering_pacman"
	name = "PACMAN Bay"
	desc = "Two portable plasma generators feeding a SMES, with a plasma \
		stack and a tool closet. Loud, simple, and it always starts."
	slot = "goon_engineering"
	map_file = "goon/goon_engineering_pacman.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/goon/engineering_rtg
	id = "goon_engineering_rtg"
	name = "RTG Bank"
	desc = "Radioisotope generators and a bigger SMES. Less output than the \
		PACMANs, but it never needs fuel and it never stops."
	slot = "goon_engineering"
	map_file = "goon/goon_engineering_rtg.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 4)

// Ships the TEG and its circulators UNPLUMBED, and that is deliberate rather
// than an oversight: find_circulators() only accepts circulators east/west of a
// north-facing generator, and set_init_directions() then forces their pipe
// ports north/south. North of the top row is hull wall and porthole; south is
// the distro main, where modules may not lay pipe. No hot and cold loop fits in
// a 4x3 pocket. A crew can run the loops in-round - players aren't bound by the
// module contract - so this is priced and described as the project it is, not
// as a working plant. The PACMAN carries the ship until someone finishes it.
/datum/ship_upgrade_module/goon/engineering_teg
	id = "goon_engineering_teg"
	name = "Thermoelectric Rig"
	desc = "A thermoelectric generator and its circulators, delivered \
		unplumbed - running the hot and cold loops is the crew's job. A PACMAN \
		and a plasma crate keep the lights on until someone finishes it."
	slot = "goon_engineering"
	map_file = "goon/goon_engineering_teg.dmm"
	part_cost = list(PART_CLASS_TRADE = 4)

// -- goon_mining: the white utility bay under the poddoor cargo dock.
// The autolathe is ship infrastructure, not mining kit: EVERY module for this
// slot ships one, so swapping fitouts never leaves the hull without a
// fabricator. The ore redemption machine is mining-specific and belongs to
// Prospector Bay alone - dropping it is the real cost of the other two.

/datum/ship_upgrade_module/goon/mining_prospector
	id = "goon_mining_prospector"
	name = "Prospector Bay"
	desc = "Ore redemption machine, autolathe, ore box and a bench of picks \
		and scanners."
	slot = "goon_mining"
	map_file = "goon/goon_mining_prospector.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/goon/mining_salvage
	id = "goon_mining_salvage"
	name = "Salvage Bay"
	desc = "A second EVA suit, a recharging bench and a rack of salvage gear: \
		plasma cutter, fulton rig and a mining GPS. Keeps the autolathe, drops \
		the ore redemption machine."
	slot = "goon_mining"
	map_file = "goon/goon_mining_salvage.dmm"
	part_cost = list(PART_CLASS_COMBAT = 4)

/datum/ship_upgrade_module/goon/mining_freight
	id = "goon_mining_freight"
	name = "Freight Dock"
	desc = "Crate racks and a conveyor running to the poddoor bay, for crews \
		who haul more than they dig. Keeps the autolathe, drops the ore \
		redemption machine."
	slot = "goon_mining"
	map_file = "goon/goon_mining_freight.dmm"
	part_cost = list(PART_CLASS_TRADE = 2)

// -- goon_lounge: the purple corner beside the cryopods.

/datum/ship_upgrade_module/goon/lounge_bunks
	id = "goon_lounge_bunks"
	name = "Capsule Bunks"
	desc = "Three survival-pod sleeping capsules and a microwave counter. \
		Cramped, but everyone gets a door."
	slot = "goon_lounge"
	map_file = "goon/goon_lounge_bunks.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/goon/lounge_mess
	id = "goon_lounge_mess"
	name = "Mess Hall"
	desc = "A real galley: griddle, fridge, booth seating and a coffee pot. \
		Trades the bunks for somewhere to sit down and eat."
	slot = "goon_lounge"
	map_file = "goon/goon_lounge_mess.dmm"
	part_cost = list(PART_CLASS_TRADE = 2)

// -- goon_cockpit: the chair arc in front of the helm.

/datum/ship_upgrade_module/goon/cockpit_standard
	id = "goon_cockpit_standard"
	name = "Standard Cockpit"
	desc = "The helm, three comfy chairs and a pair of console tables. The \
		bridge as the shuttle left the yard."
	slot = "goon_cockpit"
	map_file = "goon/goon_cockpit_standard.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/goon/cockpit_command
	id = "goon_cockpit_command"
	name = "Command Suite"
	desc = "Helm plus a communications console and a ship-wide camera monitor, \
		with the seating cut down to two."
	slot = "goon_cockpit"
	map_file = "goon/goon_cockpit_command.dmm"
	part_cost = list(PART_CLASS_MISC = 2)

// ========== GOON THEMES ==========

/datum/ship_theme/goon
	for_ship = /datum/map_template/shuttle/voidcrew/goon

/datum/ship_theme/goon/standard
	id = "standard"
	name = "NT Standard"
	desc = "The shuttle as Nanotrasen built it: four colour-coded pods off a \
		grey corridor, a captain's plushie on the bridge, and a decal budget \
		of exactly two."
	is_default = TRUE
	template_suffix = "goon_a"
	upgrade_slot_ids = list(
		"goon_port",
		"goon_engineering",
		"goon_mining",
		"goon_lounge",
		"goon_cockpit",
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
			name = "Shaft Miner",
			outfit = /datum/outfit/job/miner,
			category = JOB_CAT_CARGO,
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
			name = "Assistant",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)

/datum/ship_theme/goon/void
	id = "void"
	name = "Void Runner"
	desc = "A long-haul refit in deep blue and violet: indigo decking, repainted \
		bulkheads and cold blue lamps all the way from the bridge to the engine \
		room. Built for crews who go a long way out and stay there."
	part_cost = list(PART_CLASS_TRADE = 6)
	template_suffix = "goon_b"
	upgrade_slot_ids = list(
		"goon_port",
		"goon_engineering",
		"goon_mining",
		"goon_lounge",
		"goon_cockpit",
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
			name = "Navigator",
			outfit = /datum/outfit/job/bridge_assistant,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Reactor Engineer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Prospector",
			outfit = /datum/outfit/job/miner,
			category = JOB_CAT_CARGO,
			slots = 2,
		),
		list(
			name = "Ship's Medic",
			outfit = /datum/outfit/job/paramedic,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Crewman",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

/datum/ship_theme/goon/syndicate
	id = "syndicate"
	name = "Syndicate Cutter"
	desc = "Someone repainted the pods matte black, swapped the titanium for \
		plastitanium and bolted a weapons locker where the shower used to be. \
		The Nanotrasen signage is still under the paint if you look."
	part_cost = list(PART_CLASS_COMBAT = 6)
	template_suffix = "goon_c"
	upgrade_slot_ids = list(
		"goon_port",
		"goon_engineering",
		"goon_mining",
		"goon_lounge",
		"goon_cockpit",
	)
	job_slots = list(
		list(
			name = "Team Leader",
			officer = TRUE,
			outfit = /datum/outfit/job/captain/syndicate_cutter,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Combat Engineer",
			outfit = /datum/outfit/job/engineer/syndicate_cutter,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Field Medic",
			outfit = /datum/outfit/job/doctor/syndicate_cutter,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Salvage Operative",
			outfit = /datum/outfit/job/miner/syndicate_cutter,
			category = JOB_CAT_CARGO,
			slots = 2,
		),
		list(
			name = "Operative",
			outfit = /datum/outfit/job/assistant/syndicate_cutter,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)

/datum/ship_theme/goon/slumber
	id = "slumber"
	name = "Slumber Party"
	desc = "Pink and cream throughout, with fairy lights strung along the \
		corridor and the capsule bunks buried in blankets. There is a nail \
		polish rack bolted to the bridge console."
	part_cost = list(PART_CLASS_MISC = 6)
	template_suffix = "goon_d"
	upgrade_slot_ids = list(
		"goon_port",
		"goon_engineering",
		"goon_mining",
		"goon_lounge",
		"goon_cockpit",
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
			name = "Slumber Host",
			outfit = /datum/outfit/job/quartermaster,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Ship's Engineer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Rockhound",
			outfit = /datum/outfit/job/miner,
			category = JOB_CAT_CARGO,
			slots = 2,
		),
		list(
			name = "Ship's Nurse",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Guest",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)
