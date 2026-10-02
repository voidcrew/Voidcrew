/datum/map_template/shuttle/voidcrew/ship_nanopill
	name = "NT-C Nanopill"
	catalog_desc = ""
	suffix = "nanopill"
	short_name = "NT-C Nanopill"
	part_requirements = list()
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("support_compliment")
	player_hidden = FALSE
	job_slots = list(
		list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/captain, category = JOB_CAT_COMMAND, slots = 1),
		list(name = "Crew", outfit = /datum/outfit/job/assistant, category = JOB_CAT_ASSISTANT, slots = 3),
	)
	available_themes = list("standard")

/obj/docking_port/mobile/voidcrew/ship_nanopill
	name = "NT-C Nanopill"
	area_type = /area/shuttle/voidcrew/ship_nanopill
	port_direction = 2
	preferred_direction = NORTH

/area/shuttle/voidcrew/ship_nanopill
	name = "NT-C Nanopill"
	icon_state = "station"
