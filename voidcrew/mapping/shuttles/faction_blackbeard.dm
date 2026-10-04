/datum/map_template/shuttle/voidcrew/faction_blackbeard
	name = "SYN-C Blackbeard-class Heavy Boarder"
	catalog_desc = ""
	suffix = "faction_blackbeard"
	short_name = "SYN-C Blackbeard-class Heavy Boarder"
	part_requirements = list(PART_CLASS_COMBAT = 15, PART_CLASS_SCIENCE = 3, PART_CLASS_TRADE = 5, PART_CLASS_MISC = 5)
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("medical_bay")
	player_hidden = FALSE
	job_slots = list(
		list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/captain, category = JOB_CAT_COMMAND, slots = 1),
		list(name = "Crew", outfit = /datum/outfit/job/assistant, category = JOB_CAT_ASSISTANT, slots = 3),
	)
	available_themes = list("standard")

/obj/docking_port/mobile/voidcrew/faction_blackbeard
	name = "SYN-C Blackbeard-class Heavy Boarder"
	area_type = /area/shuttle/voidcrew/faction_blackbeard
	port_direction = 2
	preferred_direction = NORTH

/area/shuttle/voidcrew/faction_blackbeard
	name = "SYN-C Blackbeard-class Heavy Boarder"
	icon_state = "station"
