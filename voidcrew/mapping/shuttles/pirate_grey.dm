/**
 * TG Pirate Ship (Grey Tide) - Toolbox-class
 * Former Nanotrasen assistants seeking revenge. The Grey Tide rises.
 */
/datum/map_template/shuttle/voidcrew/pirate_grey
	name = "Toolbox-class Salvage Vessel"
	suffix = "pirate_grey"
	short_name = "Toolbox-class"
	part_requirements = list(PART_CLASS_MISC = 1)

	job_slots = list(
		list(
			name = "Tide Leader",
			officer = TRUE,
			outfit = /datum/outfit/job/captain/greytide,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Tider",
			outfit = /datum/outfit/job/assistant/greytide,
			category = JOB_CAT_ASSISTANT,
			slots = 5,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/pirate_grey
	name = "Toolbox-class Salvage Vessel"
	area_type = /area/shuttle/voidcrew/pirate_grey
	port_direction = 8
	preferred_direction = 4

/// AREAS ///

/area/shuttle/voidcrew/pirate_grey
	name = "Toolbox-class Salvage Vessel"

/area/shuttle/voidcrew/pirate_grey/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/pirate_grey/cargo
	name = "Cargo Hold"
	icon_state = "cargo_warehouse"

/area/shuttle/voidcrew/pirate_grey/commons
	name = "Commons"
	icon_state = "station"

/area/shuttle/voidcrew/pirate_grey/engineering
	name = "Engineering"
	icon_state = "engine"
