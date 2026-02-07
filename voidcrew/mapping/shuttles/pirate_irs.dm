/**
 * TG Pirate Ship (Space IRS) - Auditor-class
 * Space IRS agents collecting unpaid taxes. Heavy threat.
 */
/datum/map_template/shuttle/voidcrew/pirate_irs
	name = "Auditor-class Enforcement Vessel"
	suffix = "pirate_irs"
	short_name = "Auditor-class"
	part_requirements = list(PART_CLASS_COMBAT = 2)

	job_slots = list(
		list(
			name = "Head Auditor",
			officer = TRUE,
			outfit = /datum/outfit/job/captain/irs,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Senior Agent",
			outfit = /datum/outfit/job/hop/irs,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Field Agent",
			outfit = /datum/outfit/job/security/irs,
			category = JOB_CAT_SECURITY,
			slots = 3,
		),
		list(
			name = "Junior Agent",
			outfit = /datum/outfit/job/assistant/irs,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/pirate_irs
	name = "Auditor-class Enforcement Vessel"
	area_type = /area/shuttle/voidcrew/pirate_irs
	port_direction = 2
	preferred_direction = 4

/// AREAS ///

/area/shuttle/voidcrew/pirate_irs
	name = "Auditor-class Enforcement Vessel"

/area/shuttle/voidcrew/pirate_irs/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/pirate_irs/armory
	name = "Armory"
	icon_state = "armory"

/area/shuttle/voidcrew/pirate_irs/office
	name = "Office"
	icon_state = "heads_quarters"

/area/shuttle/voidcrew/pirate_irs/commons
	name = "Commons"
	icon_state = "station"

/area/shuttle/voidcrew/pirate_irs/engineering
	name = "Engineering"
	icon_state = "engine"
