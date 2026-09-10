
/datum/ship_theme/superpill_standard
	job_slots = list(list(name = "Head Assistant", officer = TRUE, outfit = /datum/outfit/job/assistant, category = "Assistant", slots = 1), list(name = "Assistant", officer = FALSE, outfit = /datum/outfit/job/assistant, category = "Assistant", slots = 2))
	id = "standard"
	name = "Rustbucket"
	for_ship = /datum/map_template/shuttle/voidcrew/superpill
	template_suffix = "superpill"
	is_default = TRUE
	upgrade_slot_ids = list("engine")
	desc = "Held together by duct tape, prayer, and whatever the last assistant found lying around."

/datum/ship_theme/superpill_climate_destroyer_supreme
	part_cost = list(PART_CLASS_COMBAT = 2, PART_CLASS_MISC = 2)
	job_slots = list(list(name = "Chief Engineer", officer = TRUE, outfit = /datum/outfit/job/workshop_superpill_job_3, category = "Engineering", slots = 1), list(name = "Engineer", officer = FALSE, outfit = /datum/outfit/job/workshop_superpill_job_4, category = "Engineering", slots = 2))
	id = "climate_destroyer_supreme"
	name = "Ironclad"
	for_ship = /datum/map_template/shuttle/voidcrew/superpill
	template_suffix = "superpill_climate_destroyer_supreme"
	is_default = FALSE
	upgrade_slot_ids = list("engine")
	desc = "Built and kept by engineers who treat \"good enough\" as a personal insult."

/datum/ship_upgrade_module/superpill_engine_basic
	id = "engine_basic"
	name = "Supermatter Crystal"
	slot = "engine"
	for_ship = /datum/map_template/shuttle/voidcrew/superpill
	for_theme = list("standard", "climate_destroyer_supreme")
	map_file = "superpill/supermatter_crystal.dmm"
	is_default = TRUE
	desc = "A compact supermatter crystal meant to give you infinite power and maybe even super powers."

/datum/ship_upgrade_module/superpill_teg_engine
	part_cost = list(PART_CLASS_MISC = 2)
	id = "teg_engine"
	name = "Thermo-Electric Generator"
	slot = "engine"
	for_ship = /datum/map_template/shuttle/voidcrew/superpill
	for_theme = list("standard", "climate_destroyer_supreme")
	map_file = "superpill/teg_engine.dmm"
	is_default = FALSE
	desc = "A much cleaner power generator for those environmentalists."
