
/datum/ship_theme/patrol_bee_standard
	job_slots = list(list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/workshop_patrol_bee_job_1, category = "Command", slots = 1), list(name = "Ship Engineer", officer = FALSE, outfit = /datum/outfit/job/engineer/gloved, category = "Engineering", slots = 1), list(name = "Atmospheric Technician", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_27, category = "Engineering", slots = 1), list(name = "Cargo Technician", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_28, category = "Cargo", slots = 1), list(name = "Patrolling Officer", officer = TRUE, outfit = /datum/outfit/job/workshop_patrol_bee_job_2, category = "Security", slots = 2), list(name = "Quartermaster", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_30, category = "Cargo", slots = 1))
	id = "standard"
	name = "NanoTrasen"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	template_suffix = "patrol_bee_nanotrasen"
	is_default = TRUE
	upgrade_slot_ids = list("Upper_Cargo", "closet", "cleanroom", "service", "security_bay")

/datum/ship_theme/patrol_bee_syndicate_black
	part_cost = list()
	job_slots = list(list(name = "Captain", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_14, category = "Command", slots = 1), list(name = "Ship Engineer", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_12, category = "Engineering", slots = 1), list(name = "Atmospheric Technician", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_13, category = "Engineering", slots = 1), list(name = "Cargo Technician", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_24, category = "Cargo", slots = 1), list(name = "Patrolling Officer", officer = TRUE, outfit = /datum/outfit/job/workshop_patrol_bee_job_25, category = "Security", slots = 2), list(name = "Quartermaster", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_17, category = "Cargo", slots = 1))
	id = "syndicate_black"
	name = "Syndicate Black"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	template_suffix = "patrol_bee_syndicate_black"
	is_default = FALSE
	upgrade_slot_ids = list("Upper_Cargo", "closet", "cleanroom", "service", "security_bay")

/datum/ship_upgrade_module/patrol_bee_mining_bay_basic
	job_slots_add_by_theme = list("standard" = list(list(name = "Miner", officer = FALSE, outfit = /datum/outfit/job/miner, category = "Cargo", slots = 1)), "syndicate_black" = list(list(name = "Miner", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_15, category = "Cargo", slots = 1)))
	id = "mining_bay_basic"
	name = "Mining Bay"
	slot = "Upper_Cargo"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard", "syndicate_black")
	map_file = "patrol_bee/mining_bay_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/patrol_bee_bitrunning_den
	part_cost = list()
	job_slots_add_by_theme = list("standard" = list(list(name = "Bitrunner", officer = FALSE, outfit = /datum/outfit/job/bitrunner, category = "Cargo", slots = 1)), "syndicate_black" = list(list(name = "Bitrunner", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_16, category = "Cargo", slots = 1)))
	id = "bitrunning_den"
	name = "Bitrunning Den"
	slot = "Upper_Cargo"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard", "syndicate_black")
	map_file = "patrol_bee/bitrunning_den.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/patrol_bee_cargo_mech_bay
	part_cost = list()
	job_slots_add_by_theme = list("standard" = list(list(name = "Cargo Mechanic", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_5, category = "Cargo", slots = 1)), "syndicate_black" = list(list(name = "Cargo Mechanic", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_29, category = "Cargo", slots = 1)))
	id = "cargo_mech_bay"
	name = "Cargo Mech Bay"
	slot = "Upper_Cargo"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard", "syndicate_black")
	map_file = "patrol_bee/cargo_mech_bay.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/patrol_bee_closet_basic
	id = "closet_basic"
	name = "Toilet"
	slot = "closet"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard", "syndicate_black")
	map_file = "patrol_bee/toilet.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/patrol_bee_custodial_closet
	part_cost = list()
	id = "custodial_closet"
	name = "Custodial Closet"
	slot = "closet"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard", "syndicate_black")
	map_file = "patrol_bee/custodial_closet.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/patrol_bee_cleanroom_basic
	job_slots_add_by_theme = list("standard" = list(list(name = "Surgeon", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_6, category = "Medical", slots = 1)), "syndicate_black" = list(list(name = "Surgeon", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_18, category = "Medical", slots = 1)))
	id = "cleanroom_basic"
	name = "Surgery Theater"
	slot = "cleanroom"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard", "syndicate_black")
	map_file = "patrol_bee/surgery_theater.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/patrol_bee_pharmacy_lab
	part_cost = list()
	job_slots_add_by_theme = list("standard" = list(list(name = "Chemist", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_7, category = "Medical", slots = 1)), "syndicate_black" = list(list(name = "Chemist", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_19, category = "Medical", slots = 1)))
	id = "pharmacy_lab"
	name = "Pharmacy Lab"
	slot = "cleanroom"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard", "syndicate_black")
	map_file = "patrol_bee/pharmacy_lab.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/patrol_bee_research_lab
	part_cost = list()
	job_slots_add_by_theme = list("standard" = list(list(name = "Scientist", officer = FALSE, outfit = /datum/outfit/job/scientist/consistent, category = "Science", slots = 1)), "syndicate_black" = list(list(name = "Scientist", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_20, category = "Science", slots = 1)))
	id = "research_lab"
	name = "Research Lab"
	slot = "cleanroom"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard", "syndicate_black")
	map_file = "patrol_bee/research_lab.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/patrol_bee_service_basic
	job_slots_add_by_theme = list("standard" = list(list(name = "Chef", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_9, category = "Service", slots = 1)), "syndicate_black" = list(list(name = "Chef", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_21, category = "Service", slots = 1)))
	id = "service_basic"
	name = "Full Kitchen"
	slot = "service"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard", "syndicate_black")
	map_file = "patrol_bee/full_kitchen.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/patrol_bee_hydroponics
	part_cost = list()
	job_slots_add_by_theme = list("standard" = list(list(name = "Botanist", officer = FALSE, outfit = /datum/outfit/job/botanist, category = "Service", slots = 1)), "syndicate_black" = list(list(name = "New job", officer = FALSE, outfit = /datum/outfit/job/botanist/syndicate, category = "Assistant", slots = 1)))
	id = "hydroponics"
	name = "Hydroponics"
	slot = "service"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard", "syndicate_black")
	map_file = "patrol_bee/hydroponics.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/patrol_bee_kitchen_and_hydroponics
	part_cost = list()
	job_slots_add_by_theme = list("standard" = list(list(name = "Head of Personnel", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_11, category = "Service", slots = 1)), "syndicate_black" = list(list(name = "Head of Personnel", officer = FALSE, outfit = /datum/outfit/job/workshop_patrol_bee_job_23, category = "Service", slots = 1)))
	id = "kitchen_and_hydroponics"
	name = "Kitchen and Hydroponics"
	slot = "service"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard", "syndicate_black")
	map_file = "patrol_bee/kitchen_and_hydroponics.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/patrol_bee_security_bay_basic
	job_slots_add_by_theme = list("standard" = list(), "syndicate_black" = list())
	id = "security_bay_basic"
	name = "Patrol Office"
	slot = "security_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard", "syndicate_black")
	map_file = "patrol_bee/patrol_office.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/patrol_bee_riot_gera_bay
	part_cost = list()
	job_slots_add_by_theme = list("standard" = list(), "syndicate_black" = list())
	id = "riot_gera_bay"
	name = "Riot Gear Bay"
	slot = "security_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/patrol_bee
	for_theme = list("standard", "syndicate_black")
	map_file = "patrol_bee/riot_gear_bay.dmm"
	is_default = FALSE
