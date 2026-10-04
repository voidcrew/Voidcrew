
/datum/ship_theme/faction_blackbeard_standard
	job_slots = list(list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/captain, category = "Command", slots = 1), list(name = "Crew", officer = FALSE, outfit = /datum/outfit/job/assistant, category = "Assistant", slots = 3))
	id = "standard"
	name = "Standard"
	for_ship = /datum/map_template/shuttle/voidcrew/faction_blackbeard
	template_suffix = "faction_blackbeard"
	is_default = TRUE
	upgrade_slot_ids = list("medical_bay")

/datum/ship_upgrade_module/faction_blackbeard_medical_bay_basic
	id = "medical_bay_basic"
	name = "Medical Bay"
	slot = "medical_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/faction_blackbeard
	for_theme = list("standard")
	map_file = "faction_blackbeard/medical_bay_basic.dmm"
	is_default = TRUE
