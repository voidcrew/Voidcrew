
/datum/ship_theme/soviet_spacecraft_standard
	job_slots = list(list(name = "Commander", officer = FALSE, outfit = /datum/outfit/job/workshop_soviet_spacecraft_job_1, category = "Command", slots = 1), list(name = "Flight Engineer", officer = FALSE, outfit = /datum/outfit/job/workshop_soviet_spacecraft_job_2, category = "Engineering", slots = 2), list(name = "Spaceflight Participant", officer = FALSE, outfit = /datum/outfit/job/workshop_soviet_spacecraft_job_3, category = "Assistant", slots = 3))
	id = "standard"
	name = "Soyuz"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	template_suffix = "soviet_spacecraft_soyuz"
	is_default = TRUE
	upgrade_slot_ids = list("solars", "docking_module", "living_module", "engineering_module")

/datum/ship_theme/soviet_spacecraft_proton
	part_cost = list()
	job_slots = list(list(name = "Commander", officer = FALSE, outfit = /datum/outfit/job/workshop_soviet_spacecraft_job_4, category = "Command", slots = 1), list(name = "Flight Engineer", officer = FALSE, outfit = /datum/outfit/job/workshop_soviet_spacecraft_job_5, category = "Engineering", slots = 2), list(name = "Spaceflight Participant", officer = FALSE, outfit = /datum/outfit/job/workshop_soviet_spacecraft_job_6, category = "Assistant", slots = 3))
	id = "proton"
	name = "Progress"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	template_suffix = "soviet_spacecraft_progress"
	is_default = FALSE
	upgrade_slot_ids = list("solars", "docking_module", "living_module", "engineering_module")

/datum/ship_upgrade_module/soviet_spacecraft_solars_basic
	id = "solars_basic"
	name = "No Solars"
	slot = "solars"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard", "proton")
	map_file = "soviet_spacecraft/no_solars.dmm"
	is_default = FALSE
	desc = "The panels have been replaced by battery arrays with an emergency power source. Standard Progress spacecraft configuration."

/datum/ship_upgrade_module/soviet_spacecraft_solars_broken
	part_cost = list()
	id = "solars_broken"
	name = "Solars Broken"
	slot = "solars"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard", "proton")
	map_file = "soviet_spacecraft/solars_broken.dmm"
	is_default = FALSE
	desc = "Solar panel modules damaged by space debris and small asteroids."

/datum/ship_upgrade_module/soviet_spacecraft_solars_working
	part_cost = list()
	id = "solars_working"
	name = "Solars Working"
	slot = "solars"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard", "proton")
	map_file = "soviet_spacecraft/solars_working.dmm"
	is_default = TRUE
	desc = "Standard solar panels for the Soyuz spacecraft series"

/datum/ship_upgrade_module/soviet_spacecraft_docking_module_basic
	id = "docking_module_basic"
	name = "Mining module"
	slot = "docking_module"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard", "proton")
	map_file = "soviet_spacecraft/mining_module.dmm"
	is_default = TRUE
	desc = "Module for the crew to conduct geological research on a planetoid"

/datum/ship_upgrade_module/soviet_spacecraft_living_module_basic
	id = "living_module_basic"
	name = "Dvushka"
	slot = "living_module"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard", "proton")
	map_file = "soviet_spacecraft/dvushka.dmm"
	is_default = TRUE
	desc = "A two-room module for two, or at a stretch, three people."

/datum/ship_upgrade_module/soviet_spacecraft_engineering_module_basic
	id = "engineering_module_basic"
	name = "Liquid-propellant type"
	slot = "engineering_module"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard", "proton")
	map_file = "soviet_spacecraft/liquid_propellant_type.dmm"
	is_default = TRUE
	desc = "Basic engines used on Soyuz rockets"

/datum/ship_upgrade_module/soviet_spacecraft_another
	part_cost = list()
	id = "another"
	name = "Nachalnik office"
	slot = "living_module"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard", "proton")
	map_file = "soviet_spacecraft/nachalnik_office.dmm"
	is_default = FALSE
	desc = "A module for one big, fat ass"

/datum/ship_upgrade_module/soviet_spacecraft_anotheer
	part_cost = list()
	id = "anotheer"
	name = "Priroda module"
	slot = "docking_module"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard", "proton")
	map_file = "soviet_spacecraft/priroda_module.dmm"
	is_default = FALSE
	desc = "A module containing living organisms for conducting zero-gravity experiments"

/datum/ship_upgrade_module/soviet_spacecraft_what_the_matter
	part_cost = list()
	id = "what_the_matter"
	name = "Electric propulsion type"
	slot = "engineering_module"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard", "proton")
	map_file = "soviet_spacecraft/electric_propulsion_type.dmm"
	is_default = FALSE
	desc = "They gonna blow it again..."

/datum/ship_upgrade_module/soviet_spacecraft_spektr_module
	part_cost = list()
	id = "spektr_module"
	name = "Spektr module"
	slot = "docking_module"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard", "proton")
	map_file = "soviet_spacecraft/spektr_module.dmm"
	is_default = FALSE
	desc = "Laboratory equipment module"
