
/datum/ship_theme/soviet_spacecraft_standard
	job_slots = list(list(name = "Commander", officer = FALSE, outfit = /datum/outfit/job/workshop_soviet_spacecraft_job_1, category = "Command", slots = 1), list(name = "Flight Engineer", officer = FALSE, outfit = /datum/outfit/job/workshop_soviet_spacecraft_job_2, category = "Engineering", slots = 2), list(name = "Spaceflight Participant", officer = FALSE, outfit = /datum/outfit/job/workshop_soviet_spacecraft_job_3, category = "Assistant", slots = 3))
	id = "standard"
	name = "Soyuz"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	template_suffix = "soviet_spacecraft_soyuz"
	is_default = TRUE
	upgrade_slot_ids = list("solars", "docking_module", "living_module", "engineering_module")

/datum/ship_upgrade_module/soviet_spacecraft_solars_basic
	id = "solars_basic"
	name = "No Solars"
	slot = "solars"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard")
	map_file = "soviet_spacecraft/no_solars.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/soviet_spacecraft_solars_broken
	part_cost = list()
	id = "solars_broken"
	name = "Solars Broken"
	slot = "solars"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard")
	map_file = "soviet_spacecraft/solars_broken.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/soviet_spacecraft_solars_working
	part_cost = list()
	id = "solars_working"
	name = "Solars Working"
	slot = "solars"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard")
	map_file = "soviet_spacecraft/solars_working.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/soviet_spacecraft_docking_module_basic
	id = "docking_module_basic"
	name = "Docking module"
	slot = "docking_module"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard")
	map_file = "soviet_spacecraft/docking_module_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/soviet_spacecraft_living_module_basic
	id = "living_module_basic"
	name = "Living module"
	slot = "living_module"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard")
	map_file = "soviet_spacecraft/living_module_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/soviet_spacecraft_engineering_module_basic
	id = "engineering_module_basic"
	name = "Liquid-propellant type"
	slot = "engineering_module"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard")
	map_file = "soviet_spacecraft/liquid_propellant_type.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/soviet_spacecraft_another
	part_cost = list()
	id = "another"
	name = "another"
	slot = "living_module"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard")
	map_file = "soviet_spacecraft/another.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/soviet_spacecraft_anotheer
	part_cost = list()
	id = "anotheer"
	name = "anotheer"
	slot = "docking_module"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard")
	map_file = "soviet_spacecraft/anotheer.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/soviet_spacecraft_what_the_matter
	part_cost = list()
	id = "what_the_matter"
	name = "Electric propulsion type"
	slot = "engineering_module"
	for_ship = /datum/map_template/shuttle/voidcrew/soviet_spacecraft
	for_theme = list("standard")
	map_file = "soviet_spacecraft/electric_propulsion_type.dmm"
	is_default = FALSE
