/datum/map_template/shuttle/voidcrew/faction_hyena
	name = "SYN-C Hyena-class  Wrecking Tug"
	catalog_desc = ""
	suffix = "faction_hyena"
	short_name = "SYN-C Hyena-class  Wrecking Tug"
	part_requirements = list(PART_CLASS_MISC = 0)
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("common_area")
	player_hidden = FALSE
	job_slots = list(
		list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/captain, category = JOB_CAT_COMMAND, slots = 1),
		list(name = "Crew", outfit = /datum/outfit/job/assistant, category = JOB_CAT_ASSISTANT, slots = 3),
	)
	available_themes = list("standard")

/obj/docking_port/mobile/voidcrew/faction_hyena
	name = "SYN-C Hyena-class  Wrecking Tug"
	area_type = /area/shuttle/voidcrew/faction_hyena
	port_direction = 2
	preferred_direction = NORTH

/area/shuttle/voidcrew/faction_hyena
	name = "SYN-C Hyena-class  Wrecking Tug"
	icon_state = "station"
