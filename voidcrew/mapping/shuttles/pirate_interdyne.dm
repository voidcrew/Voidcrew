/**
 * TG Pirate Ship (Ex-Interdyne) - Interdyne-class
 * Former Interdyne Pharmaceutics employees turned pirates. Heavy threat.
 */
/datum/map_template/shuttle/voidcrew/pirate_interdyne
	name = "Interdyne-class Biocraft"
	suffix = "pirate_interdyne"
	short_name = "Interdyne-class"
	part_requirements = list(PART_CLASS_COMBAT = 1, PART_CLASS_SCIENCE = 1)

	job_slots = list(
		list(
			name = "Senior Resident",
			officer = TRUE,
			outfit = /datum/outfit/job/captain/interdyne,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Pharmacist",
			outfit = /datum/outfit/job/doctor/interdyne,
			category = JOB_CAT_MEDICAL,
			slots = 2,
		),
		list(
			name = "Enforcer",
			outfit = /datum/outfit/job/security/interdyne,
			category = JOB_CAT_SECURITY,
			slots = 2,
		),
		list(
			name = "Lab Assistant",
			outfit = /datum/outfit/job/assistant/interdyne,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/pirate_interdyne
	name = "Interdyne-class Biocraft"
	area_type = /area/shuttle/voidcrew/pirate_interdyne
	port_direction = 2
	preferred_direction = 4

/// AREAS ///

/area/shuttle/voidcrew/pirate_interdyne
	name = "Interdyne-class Biocraft"

/area/shuttle/voidcrew/pirate_interdyne/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/pirate_interdyne/medbay
	name = "Medical Bay"
	icon_state = "medbay"

/area/shuttle/voidcrew/pirate_interdyne/laboratory
	name = "Laboratory"
	icon_state = "toxlab"

/area/shuttle/voidcrew/pirate_interdyne/commons
	name = "Commons"
	icon_state = "station"

/area/shuttle/voidcrew/pirate_interdyne/engineering
	name = "Engineering"
	icon_state = "engine"
