/datum/map_template/shuttle/voidcrew/ship_courage
	name = "SYN-C Courage"
	catalog_desc = ""
	suffix = "ship_courage_courage_class"
	short_name = "SYN-C Courage"
	part_requirements = list(PART_CLASS_MISC = 0)
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("aft_compartment")
	player_hidden = FALSE
	job_slots = list(
		list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/captain, category = JOB_CAT_COMMAND, slots = 1),
		list(name = "Crew", outfit = /datum/outfit/job/assistant, category = JOB_CAT_ASSISTANT, slots = 3),
	)
	available_themes = list("standard")

/obj/docking_port/mobile/voidcrew/ship_courage
	name = "SYN-C Courage"
	area_type = /area/shuttle/voidcrew/ship_courage
	port_direction = 2
	preferred_direction = NORTH

/area/shuttle/voidcrew/ship_courage
	name = "SYN-C Courage"
	icon_state = "station"
