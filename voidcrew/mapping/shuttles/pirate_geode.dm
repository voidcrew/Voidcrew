/**
 * TG Pirate Ship (Lustrous Geode) - Geode-class
 * Mutated Ethereals who have adopted bluespace technology in strange ways.
 */
/datum/map_template/shuttle/voidcrew/pirate_geode
	name = "Geode-class Crystal Vessel"
	suffix = "pirate_geode"
	short_name = "Geode-class"
	part_requirements = list(PART_CLASS_SCIENCE = 1)

	job_slots = list(
		list(
			name = "Radiant",
			officer = TRUE,
			outfit = /datum/outfit/job/captain/lustrous,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Scintillant",
			outfit = /datum/outfit/job/assistant/lustrous,
			category = JOB_CAT_ASSISTANT,
			slots = 4,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/pirate_geode
	name = "Geode-class Crystal Vessel"
	area_type = /area/shuttle/voidcrew/pirate_geode
	port_direction = 2
	preferred_direction = 4

/// AREAS ///

/area/shuttle/voidcrew/pirate_geode
	name = "Geode-class Crystal Vessel"

/area/shuttle/voidcrew/pirate_geode/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/pirate_geode/crystal_chamber
	name = "Crystal Chamber"
	icon_state = "toxlab"

/area/shuttle/voidcrew/pirate_geode/commons
	name = "Commons"
	icon_state = "station"

/area/shuttle/voidcrew/pirate_geode/engineering
	name = "Engineering"
	icon_state = "engine"
