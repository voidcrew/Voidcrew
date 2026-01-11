/**
 * TG Pirate Ship (Default) - Rogue-class
 * Converted from the default TG pirate ship for use as a Voidcrew shuttle.
 */
/datum/map_template/shuttle/voidcrew/pirate_default
	name = "Rogue-class Pirate Vessel"
	suffix = "pirate_default"
	short_name = "Rogue-class"
	part_requirements = list(PART_CLASS_COMBAT = 1)

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
			name = "Deckhand",
			outfit = /datum/outfit/job/assistant/pirate,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/pirate_default
	name = "Rogue-class Pirate Vessel"
	area_type = /area/shuttle/voidcrew/pirate_default
	port_direction = 2
	preferred_direction = 4

/// AREAS ///

/// Command ///

/area/shuttle/voidcrew/pirate_default
	name = "Rogue-class Pirate Vessel"

/area/shuttle/voidcrew/pirate_default/bridge
	name = "Bridge"
	icon_state = "bridge"

/// Cargo ///

/area/shuttle/voidcrew/pirate_default/cargo
	name = "Cargo Hold"
	icon_state = "cargo_warehouse"

/// Commons ///

/area/shuttle/voidcrew/pirate_default/commons
	name = "Commons"
	icon_state = "station"

/// Engineering ///

/area/shuttle/voidcrew/pirate_default/engineering
	name = "Engineering"
	icon_state = "engine"
