
/datum/ship_theme/ship_nanopill_standard
	job_slots = list(list(name = "First Officer", officer = TRUE, outfit = /datum/outfit/job/workshop_ship_nanopill_job_1, category = "Command", slots = 1), list(name = "Heavy Infantry", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanopill_job_2, category = "Assistant", slots = 1), list(name = "Marine Medic", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanopill_job_3, category = "Medical", slots = 1), list(name = "Marine Engineer", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanopill_job_4, category = "Assistant", slots = 1))
	id = "standard"
	name = "Standard"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanopill
	template_suffix = "nanopill"
	is_default = TRUE
	upgrade_slot_ids = list("support_compliment")

/datum/ship_upgrade_module/ship_nanopill_support_compliment_basic
	id = "support_compliment_basic"
	name = "Support Compliment"
	slot = "support_compliment"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanopill
	for_theme = list("standard")
	map_file = "nanopill/support_compliment_basic.dmm"
	is_default = TRUE
