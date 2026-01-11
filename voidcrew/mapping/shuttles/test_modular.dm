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
