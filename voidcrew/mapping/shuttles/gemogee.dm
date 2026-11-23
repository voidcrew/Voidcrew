/datum/map_template/shuttle/voidcrew/gemogee
	name = "Gemogee"
	catalog_desc = ""
	suffix = "gemogee_bounty_hunter_black"
	short_name = "Gemogee"
	part_requirements = list(PART_CLASS_MISC = 0)
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("cargo_load")
	player_hidden = FALSE
	job_slots = list(
		list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/captain, category = JOB_CAT_COMMAND, slots = 1),
		list(name = "Crew", outfit = /datum/outfit/job/assistant, category = JOB_CAT_ASSISTANT, slots = 3),
	)
	available_themes = list("standard", "medical_runner", "industrial_cracker")

/obj/docking_port/mobile/voidcrew/gemogee
	name = "Gemogee"
	area_type = /area/shuttle/voidcrew/gemogee
	port_direction = 2
	preferred_direction = NORTH

/area/shuttle/voidcrew/gemogee
	name = "Gemogee"
	icon_state = "station"
