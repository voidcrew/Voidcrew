/**
 * TG Pirate Ship (Silver Scales) - Silverscale-class
 * Aristocratic lizard pirates seeking tribute from plebeians.
 */
/datum/map_template/shuttle/voidcrew/pirate_silverscale
	name = "Silverscale-class Noble Vessel"
	suffix = "pirate_silverscale"
	short_name = "Silverscale-class"
	part_requirements = list(PART_CLASS_COMBAT = 1, PART_CLASS_TRADE = 1)

	job_slots = list(
		list(
			name = "Captain",
			officer = TRUE,
			outfit = /datum/outfit/job/captain/silverscale,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "First Mate",
			outfit = /datum/outfit/job/hop/silverscale,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Hunter",
			outfit = /datum/outfit/job/security/silverscale,
			category = JOB_CAT_SECURITY,
			slots = 2,
		),
		list(
			name = "Servant",
			outfit = /datum/outfit/job/assistant/silverscale,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/pirate_silverscale
	name = "Silverscale-class Noble Vessel"
	area_type = /area/shuttle/voidcrew/pirate_silverscale
	port_direction = 8
	preferred_direction = 4

/// AREAS ///

/area/shuttle/voidcrew/pirate_silverscale
	name = "Silverscale-class Noble Vessel"

/area/shuttle/voidcrew/pirate_silverscale/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/pirate_silverscale/trophy_room
	name = "Trophy Room"
	icon_state = "cargo_warehouse"

/area/shuttle/voidcrew/pirate_silverscale/commons
	name = "Commons"
	icon_state = "station"

/area/shuttle/voidcrew/pirate_silverscale/engineering
	name = "Engineering"
	icon_state = "engine"
