/**
 * TG Pirate Ship (Flying Dutchman) - Dutchman-class
 * Undead skeleton crew seeking booty. Heavy threat.
 */
/datum/map_template/shuttle/voidcrew/pirate_dutchman
	name = "Dutchman-class Ghostship"
	suffix = "pirate_dutchman"
	short_name = "Dutchman-class"
	part_requirements = list(PART_CLASS_COMBAT = 2)

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
			slots = 3,
		),
		list(
			name = "Deckhand",
			outfit = /datum/outfit/job/assistant/pirate,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/pirate_dutchman
	name = "Dutchman-class Ghostship"
	area_type = /area/shuttle/voidcrew/pirate_dutchman
	port_direction = 4
	preferred_direction = 8

/// AREAS ///

/area/shuttle/voidcrew/pirate_dutchman
	name = "Dutchman-class Ghostship"

/area/shuttle/voidcrew/pirate_dutchman/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/pirate_dutchman/cargo
	name = "Cargo Hold"
	icon_state = "cargo_warehouse"

/area/shuttle/voidcrew/pirate_dutchman/commons
	name = "Commons"
	icon_state = "station"

/area/shuttle/voidcrew/pirate_dutchman/engineering
	name = "Engineering"
	icon_state = "engine"
