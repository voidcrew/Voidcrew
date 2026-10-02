
/datum/ship_theme/ship_courage_standard
	job_slots = list(list(name = "Syndicate Officer", officer = TRUE, outfit = /datum/outfit/job/workshop_ship_courage_job_1, category = "Command", slots = 1), list(name = "Syndicate Operative", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_courage_job_2, category = "Security", slots = 1), list(name = "Syndicate Combat Medic", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_courage_job_3, category = "Medical", slots = 1), list(name = "Syndicate Engineer", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_courage_job_4, category = "Engineering", slots = 1), list(name = "Syndicate Prospector", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_courage_job_5, category = "Cargo", slots = 1))
	id = "standard"
	name = "Courage Class"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_courage
	template_suffix = "ship_courage_courage_class"
	is_default = TRUE
	upgrade_slot_ids = list("aft_compartment")
	desc = "The courage is made to establish a force in required locations rapidly. Featuring a small crew compliment and the essentials to achieve a foothold in the sector."

/datum/ship_upgrade_module/ship_courage_aft_compartment_basic
	id = "aft_compartment_basic"
	name = "Aft Compartment"
	slot = "aft_compartment"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_courage
	for_theme = list("standard")
	map_file = "ship_courage/aft_compartment_basic.dmm"
	is_default = TRUE
	desc = "Standard Compliment."
