/datum/map_template/shuttle/voidcrew/starfury
	name = "Starfury"
	catalog_desc = ""
	suffix = "starfury"
	short_name = "Starfury"
	part_requirements = list(PART_CLASS_MISC = 0)
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list()
	player_hidden = FALSE
	job_slots = list(
		list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/captain, category = JOB_CAT_COMMAND, slots = 1),
		list(name = "Crew", outfit = /datum/outfit/job/assistant, category = JOB_CAT_ASSISTANT, slots = 3),
	)
	available_themes = list("standard")

/obj/docking_port/mobile/voidcrew/starfury
	name = "Starfury"
	area_type = /area/shuttle/voidcrew/starfury
	port_direction = 2
	preferred_direction = NORTH

/area/shuttle/voidcrew/starfury
	name = "Starfury"
	icon_state = "station"
