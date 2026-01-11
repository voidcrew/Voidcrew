/**
 * # Test Modular Ship
 *
 * A simple test ship template that demonstrates the modular upgrade system.
 * This ship has two upgrade slots: cargobay and engineroom.
 */

/datum/map_template/shuttle/voidcrew/test_modular
	name = "Test Modular Ship"
	suffix = "test_modular"
	short_name = "Test-class"
	part_requirements = list()  // Free ship for testing

	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("cargobay", "engineroom")

	job_slots = list(
		list(
			name = "Test Captain",
			officer = TRUE,
			outfit = /datum/outfit/job/captain,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Test Crew",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/test_modular
	name = "Test Modular Ship"
	area_type = /area/shuttle/voidcrew/test_modular
	port_direction = SOUTH
	preferred_direction = NORTH

/// AREAS ///

/area/shuttle/voidcrew/test_modular
	name = "Test Modular Ship"
	icon_state = "station"

// ========== THEMED VARIANT EXAMPLE ==========

/**
 * Pirate-themed variant of the Test Modular Ship
 *
 * This demonstrates how to create a themed ship variant.
 * The module loader will automatically look for themed module files:
 * - "cargo_basic.dmm" becomes "cargo_basic_pirate.dmm" (if it exists)
 * - Falls back to base file if themed variant doesn't exist
 */
/datum/map_template/shuttle/voidcrew/test_modular/pirate
	name = "Test Modular Ship (Pirate)"
	suffix = "test_modular_pirate"  // Points to ship_test_modular_pirate.dmm
	short_name = "Test-class (Pirate)"
	theme = "pirate"  // This triggers themed module lookup

/// DOCKING PORT - inherits from base, just override name ///
/obj/docking_port/mobile/voidcrew/test_modular/pirate
	name = "Test Modular Ship (Pirate)"

/// AREAS - Can use same area or create themed one ///
/area/shuttle/voidcrew/test_modular/pirate
	name = "Pirate Test Ship"
