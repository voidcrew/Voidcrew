// ========== SCARAB MODULES ==========
//
// All three hulls (scarab_a medical, scarab_b syndicate, scarab_c mining) are
// 33x20 and geometrically identical - same marker tiles, same footprints, same
// reserved tiles. Coords below are BYOND coords on the hull, origin bottom-left,
// and hold for all three themes.
//
//   scarab_med          x22-24 y5-8   3x4   marker (23,7)  connector local (2,3)
//     reserve (22,5), (22,8), (24,8) with /turf/template_noop - all three are
//     permanent hull wall. (24,8) is the bridge's wall, not medbay's.
//     This is the ONLY slot whose area already has an APC: the hull's medbay APC
//     sits at (21,8), just outside the west edge. Modules here must NOT place
//     one - the other three slots own their area's only APC and this one does not.
//
//   scarab_engineering  x9-16 y3-8   8x6   marker (11,6)  connector local (3,4)
//     reserve the whole south row (9,3)-(14,3) plus (16,3),(16,4) with
//     /turf/template_noop. (9,3),(13,3),(14,3) are wall; (10,3),(11,3),(12,3)
//     and (16,4) are the hull's reinforced-window + preopen-shutter band, and
//     (16,3) is already /turf/template_noop on the hull itself (exterior).
//     EVERY module here must ship the ship's ENTIRE power plant and air supply:
//     the bare hull has FOUR SMES in the engine bays but ZERO generators, and
//     the engineering area has no hull APC. A module that forgets any of
//     generator / SMES / APC / air tanks strands the whole ship.
//
//   scarab_common       x16-23 y10-15  8x6   marker (19,10)  connector local (4,1)
//     reserve twelve tiles - the two blocks this slot's box overhangs:
//       west  (16,14),(16,15),(17,14),(17,15),(18,14),(18,15) - the hull's
//             washroom (shower, curtain, sink, mirror) and its airlock.
//       east  (21,14),(21,15),(22,14),(22,15),(23,14),(23,15) - the dormitories
//             cryo alcove.
//     CRYO SAFETY INVARIANT: (22,15) is the ship's ONLY cryopod. No Scarab
//     module ships one, so this single hull tile is where every player spawns.
//     It is walled on three sides - (22,16) N, (22,14) S, (21,15) W - so its
//     ONLY exit is (23,15). Both the pod and its exit fall inside this slot's
//     footprint. Anything dense on (23,15) seals a spawning player in for good;
//     (23,14) is the airlock they leave through and (23,16) carries the cryo
//     console, so keep both clear as well. All six current common variants
//     template_noop this block correctly - keep it that way.
//     Module owns the commons APC at (22,10).
//
//   scarab_cargo        x8-14 y12-17  7x6   marker (11,13)  connector local (4,2)
//     reserve (8,16),(8,17),(14,17) with /turf/template_noop. (8,16) and (14,17)
//     are wall; (8,17) is the engine-room airlock + firedoor and is the cargo
//     bay's only route aft.
//     Module owns the cargo bay APC at (14,15).
//     OWNERSHIP RULE - the fabricator tile (14,16) belongs to the MODULE, not
//     the hull. All nine scarab_cargo variants ship the autolathe + bot decal
//     there, so no fitout can be left without one, and the hull therefore
//     places nothing on that tile (this is the same convention goon.dm records:
//     when every module in a slot carries an item, the hull drops its copy).
//     ship_scarab_a used to stamp a second autolathe, bot decal and
//     soft_cap_pop_art poster there and every assembled medical Scarab carried
//     two of each; that hull copy is gone. If you ever add a tenth cargo
//     variant it MUST bring its own autolathe.
//     The hull DOES own (8,12) - the voidcrew_cargo console - and it is the
//     only hull-dressed interior tile inside this footprint. Modules must leave
//     it clear of anything dense; the firecloset that used to sit on top of the
//     console now stands at (11,12), beside the EVA prep row.
//
// Permanent hull, never a module's job: the helm (28,11), the cryopod (22,15)
// and its console (23,16), all five hull APCs (7,6) (21,8) (26,6) (26,13)
// (28,15), the four engine-bay SMES (4,3) (4,4) (4,17) (4,18), and every
// pipe/cable trunk outside the four boxes above.
//
// Because three of the four slots own their area's only APC and scarab_engineering
// owns the only power plant, all four `is_default = TRUE` flags are load-bearing:
// with no player selection the loader falls back to the slot's default
// (modular_map_root_ship.dm), and that fallback is the only thing guaranteeing a
// powered, breathable ship. Never leave a slot without exactly one defaulted module.
//
// THEMES REACH EVERY ROOM. scarab_b (syndicate) originally left medbay/b,
// engineering/b and engines/b in scarab_a's medical palette - bright blue
// medbay tiles and a yellow engineering deck on an otherwise plastitanium
// hull - which also made scarab_med_chem_syndicate.dmm and
// scarab_med_surgery_syndicate.dmm content-identical to their medical
// counterparts. Those rooms now use the hull's own syndicate palette:
// medbay is /turf/open/floor/iron/dark under a tile/dark_blue contrasted ring
// (the grammar cmos_office/b already used), the engineering and engine decks
// are /turf/open/floor/mineral/plastitanium with their existing hazard
// stripes. When adding a theme, diff its hull against scarab_a room by room -
// any turf that comes back unchanged is a room the theme did not reach.

/datum/ship_upgrade_module/scarab
	for_ship = /datum/map_template/shuttle/voidcrew/scarab
	// Scarab is the ONE family with no shared base maps: every module exists only
	// as <module>_medical.dmm / _mining.dmm / _syndicate.dmm. The loader's
	// <base>_<theme>.dmm -> <base>.dmm fallback therefore has nothing to fall back
	// TO - a missing themed file makes load_module() hit `if(!fexists(mapfile))`
	// and silently qdel the marker, loading nothing into the slot. Adding a theme
	// to this list means adding all ten .dmm files for it.
	for_theme = list("medical", "syndicate", "mining")

/datum/ship_upgrade_module/scarab/med_basic
	id = "scarab_med_basic"
	name = "Medical Storage"
	desc = "A small storage area for medical supplies. \
		Comes pre-stocked with medkits and basic equipment."
	slot = "scarab_med"
	map_file = "scarab/scarab_med_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/scarab/med_surgery
	id = "scarab_med_surgery"
	name = "Surgical Suite"
	desc = "A fully equipped surgical suite for advanced medical procedures. \
		Comes with extra prosthetic limbs."
	slot = "scarab_med"
	map_file = "scarab/scarab_med_surgery.dmm"
	part_cost = list(PART_CLASS_MISC = 8)

/datum/ship_upgrade_module/scarab/med_chem
	id = "scarab_med_chem"
	name = "Medical Chemistry Lab"
	desc = "A dedicated chemistry lab. \
		Comes with a syringe gun."
	slot = "scarab_med"
	map_file = "scarab/scarab_med_chem.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 8)

/datum/ship_upgrade_module/scarab/engineering_basic
	id = "scarab_engineering_basic"
	name = "Engineering Bay"
	desc = "A basic engineering, supplying the ship with breathable air and power. \
		Also includes an additional external airlock for EVA operations."
	slot = "scarab_engineering"
	map_file = "scarab/scarab_engineering_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/scarab/engineering_teg
	id = "scarab_engineering_teg"
	name = "Thermal-Electric Generator"
	desc = "An engineering bay containing an air supply and a fully functional Thermal-Electric Generator (TEG), \
		providing an immense amount of sustainable power to the ship."
	slot = "scarab_engineering"
	map_file = "scarab/scarab_engineering_teg.dmm"
	part_cost = list(PART_CLASS_TRADE = 14) // TEG is pretty OP

/datum/ship_upgrade_module/scarab/common_quarters
	id = "scarab_common_basic"
	name = "Common Quarters"
	desc = "A simple common area with a microwave and a few chairs, \
		allowing the crew to relax and eat."
	slot = "scarab_common"
	map_file = "scarab/scarab_common_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/scarab/common_cryo
	id = "scarab_common_cryo"
	name = "Cryogenics Bay"
	desc = "A fully functional cryogentics bay with two cryo tubes that can heal most injuries over time."
	slot = "scarab_common"
	map_file = "scarab/scarab_common_cryo.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 8)

/datum/ship_upgrade_module/scarab/cargo_basic
	id = "scarab_cargo_basic"
	name = "Cargo Bay"
	desc = "A moderately sized cargo bay that can hold upwards of a dozen crates."
	slot = "scarab_cargo"
	map_file = "scarab/scarab_cargo_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/scarab/cargo_engi
	id = "scarab_cargo_engi"
	name = "EVA Bay"
	desc = "A moderately sized cargo bay that can hold upwards of a half dozen crates. \
		Comes with recharging stations intended for quicker EVA operations."
	slot = "scarab_cargo"
	map_file = "scarab/scarab_cargo_engi.dmm"
	part_cost = list(PART_CLASS_COMBAT = 8) // Basically just a cargo bay but with stuff that makes space combat easier

/datum/ship_upgrade_module/scarab/cargo_med
	id = "scarab_cargo_med"
	name = "Extra Medical Bay"
	desc = "A fully equipped medical bay with two stasis beds and a variety of medical supplies. \
		Intended to supplement the main medical area of the ship."
	slot = "scarab_cargo"
	map_file = "scarab/scarab_cargo_med.dmm"
	part_cost = list(PART_CLASS_MISC = 8)

// ========== SCARAB THEMES ==========

/datum/ship_theme/scarab
	for_ship = /datum/map_template/shuttle/voidcrew/scarab

/datum/ship_theme/scarab/medical
	id = "medical"
	name = "Hospital Variant"
	desc = "Medical-focused configuration with a Chief Medical Officer and dedicated doctors. \
		Designed for emergency response and patient care."
	is_default = TRUE
	template_suffix = "scarab_a"
	upgrade_slot_ids = list(
		"scarab_med",
		"scarab_engineering",
		"scarab_common",
		"scarab_cargo",
	)
	job_slots = list(
		list(
			name = "Chief Medical Officer",
			officer = TRUE,
			outfit = /datum/outfit/job/cmo,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Medical Doctor",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 4,
		),
		list(
			name = "Ship Engineer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 3,
		),
		list(
			name = "Atmospheric Technician",
			outfit = /datum/outfit/job/atmos,
			category = JOB_CAT_ENGINEERING,
			slots = 2,
		),
		list(
			name = "Resource Acquisition Specialist",
			outfit = /datum/outfit/job/miner,
			category = JOB_CAT_CARGO,
			slots = 4,
		),
		list(
			name = "Resident",
			outfit = /datum/outfit/job/assistant/resident/a,
			category = JOB_CAT_ASSISTANT,
			slots = 5,
		),
	)

/datum/ship_theme/scarab/syndicate
	id = "syndicate"
	name = "Reinforced Variant"
	desc = "Chemistry-focused variant with reinforced hull. \
		Designed for pharmaceutical operations and hazardous material handling."
	part_cost = list(PART_CLASS_SCIENCE = 12)
	template_suffix = "scarab_b"
	upgrade_slot_ids = list(
		"scarab_med",
		"scarab_engineering",
		"scarab_common",
		"scarab_cargo",
	)
	job_slots = list(
		list(
			name = "Chief Pharmacist Officer",
			officer = TRUE,
			outfit = /datum/outfit/job/cmo,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Pharmacist",
			outfit = /datum/outfit/job/chemist,
			category = JOB_CAT_MEDICAL,
			slots = 2,
		),
		list(
			name = "Medical Doctor",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 4,
		),
		list(
			name = "Ship Engineer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 3,
		),
		list(
			name = "Atmospheric Technician",
			outfit = /datum/outfit/job/atmos,
			category = JOB_CAT_ENGINEERING,
			slots = 2,
		),
		list(
			name = "Resource Acquisition Specialist",
			outfit = /datum/outfit/job/miner,
			category = JOB_CAT_CARGO,
			slots = 4,
		),
		list(
			name = "Resident",
			outfit = /datum/outfit/job/assistant/resident/b,
			category = JOB_CAT_ASSISTANT,
			slots = 5,
		),
	)

/datum/ship_theme/scarab/mining
	id = "mining"
	name = "Security Variant"
	desc = "Patrol-focused variant with security crew. \
		Designed for sector patrol and law enforcement operations."
	part_cost = list(PART_CLASS_COMBAT = 12)
	template_suffix = "scarab_c"
	upgrade_slot_ids = list(
		"scarab_med",
		"scarab_engineering",
		"scarab_common",
		"scarab_cargo",
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
			name = "Medical Officer",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 4,
		),
		list(
			name = "Engineering Officer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 3,
		),
		list(
			name = "Resource Acquisition Specialist",
			outfit = /datum/outfit/job/miner,
			category = JOB_CAT_CARGO,
			slots = 4,
		),
		list(
			name = "Security Officer",
			outfit = /datum/outfit/job/security,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
		list(
			name = "Assistant",
			outfit = /datum/outfit/job/assistant/resident/c,
			category = JOB_CAT_ASSISTANT,
			slots = 5,
		),
	)
