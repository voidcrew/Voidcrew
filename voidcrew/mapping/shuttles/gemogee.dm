/datum/map_template/shuttle/voidcrew/gemogee
	name = "Gemogee-Class Runner"
	catalog_desc = "A smaller ship, design for speed and modularity. You often find it in the hands of aspiring salvager, medic, pirate and bounty hunter crews. "
	suffix = "gemogee_bounty_hunter_black"
	short_name = "Gemogee-Class Runner"
	part_requirements = list()
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("ship_bay", "south_bay", "wing_modules")
	player_hidden = FALSE
	job_slots = list(list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/workshop_gemogee_job_1, category = "Command", slots = 1), list(name = "Crew", officer = FALSE, outfit = /datum/outfit/job/workshop_gemogee_job_2, category = "Assistant", slots = 2), list(name = "Paramedic", officer = FALSE, outfit = /datum/outfit/job/workshop_gemogee_job_3, category = "Medical", slots = 1), list(name = "Technician", officer = FALSE, outfit = /datum/outfit/job/workshop_gemogee_job_4, category = "Engineering", slots = 1))
	available_themes = list("standard", "medical_runner", "industrial_cracker")

/obj/docking_port/mobile/voidcrew/gemogee
	name = "Gemogee-Class Runner"
	area_type = /area/shuttle/voidcrew/gemogee
	port_direction = 2
	preferred_direction = NORTH

/area/shuttle/voidcrew/gemogee
	name = "Gemogee-Class Runner"
	icon_state = "station"
