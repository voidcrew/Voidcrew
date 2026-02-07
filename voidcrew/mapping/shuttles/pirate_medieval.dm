/**
 * TG Pirate Ship (Medieval) - Siege-class
 * Medieval warmongers from OUTER SPACE! Heavy threat.
 */
/datum/map_template/shuttle/voidcrew/pirate_medieval
	name = "Siege-class Warship"
	suffix = "pirate_medieval"
	short_name = "Siege-class"
	part_requirements = list(PART_CLASS_COMBAT = 2)

	job_slots = list(
		list(
			name = "Warlord",
			officer = TRUE,
			outfit = /datum/outfit/job/captain/medieval,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Knight",
			outfit = /datum/outfit/job/security/medieval,
			category = JOB_CAT_SECURITY,
			slots = 2,
		),
		list(
			name = "Warmonger",
			outfit = /datum/outfit/job/assistant/medieval,
			category = JOB_CAT_ASSISTANT,
			slots = 4,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/pirate_medieval
	name = "Siege-class Warship"
	area_type = /area/shuttle/voidcrew/pirate_medieval
	port_direction = 2
	preferred_direction = 4

/// AREAS ///

/area/shuttle/voidcrew/pirate_medieval
	name = "Siege-class Warship"

/area/shuttle/voidcrew/pirate_medieval/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/pirate_medieval/armory
	name = "Armory"
	icon_state = "armory"

/area/shuttle/voidcrew/pirate_medieval/great_hall
	name = "Great Hall"
	icon_state = "station"

/area/shuttle/voidcrew/pirate_medieval/engineering
	name = "Engineering"
	icon_state = "engine"
