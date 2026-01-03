/datum/map_template/shuttle/voidcrew/goon
	name = "Goon-class Repurposed Emergency Shuttle"
	suffix = "goon"
	short_name = "Goon-class"
	part_requirements = list()

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

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/goon // Brewing up something awful here
	name = "Goon-class Repurposed Emergency Shuttle"
	area_type = /area/shuttle/voidcrew/goon


/// AREAS ///

/// Command ///

/area/shuttle/voidcrew/goon/bridge
	name = "Bridge"
	icon_state = "bridge"

/// Engineering ///

/area/shuttle/voidcrew/goon/engineering
	name = "Engineering"
	icon_state = "engine"

/// Medbay ///

/area/shuttle/voidcrew/goon/medbay
	name = "Medbay"
	icon_state = "medbay"

/// Misc ///

/area/shuttle/voidcrew/goon/commons
	name = "Commons"
	icon_state = "station"
