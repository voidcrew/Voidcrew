
/datum/ship_upgrade_module/workshop_bogatyr_eva_bay_basic
	job_slots_add_by_theme = list("freshen_up" = list(list(name = "Guy Given a Pickaxe", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_23, category = "Cargo", slots = 3)), "nightclub" = list(list(name = "Guy Given a Pickaxe", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_24, category = "Cargo", slots = 3)), "trashed" = list(list(name = "Guy Given a Pickaxe", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_22, category = "Cargo", slots = 3)))
	job_slots_add = list(list(name = "Guy Given a Pickaxe", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_5, category = "Assistant", slots = 3))
	id = "eva_bay_basic"
	name = "EVA Bay"
	slot = "eva_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/bogatyr
	for_theme = list("trashed", "freshen_up", "nightclub")
	map_file = "bogatyr/workshop/eva_bay_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/workshop_bogatyr_laboratory_basic
	job_slots_add_by_theme = list("freshen_up" = list(list(name = "Lab Specialist", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_25, category = "Science", slots = 1)), "nightclub" = list(list(name = "Lab Specialist", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_26, category = "Science", slots = 1)), "trashed" = list(list(name = "Lab Specialist", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_6, category = "Science", slots = 1)))
	job_slots_add = list(list(name = "Lab Specialist", officer = FALSE, outfit = /datum/outfit/job/scientist, category = "Science", slots = 1))
	id = "laboratory_basic"
	name = "Laboratory"
	slot = "laboratory"
	for_ship = /datum/map_template/shuttle/voidcrew/bogatyr
	for_theme = list("trashed", "freshen_up", "nightclub")
	map_file = "bogatyr/workshop/laboratory_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/workshop_bogatyr_medical_bay_basic
	job_slots_add_by_theme = list("freshen_up" = list(list(name = "Street Doctor", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_27, category = "Medical", slots = 1)), "nightclub" = list(list(name = "Street Doctor", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_28, category = "Medical", slots = 1)), "trashed" = list(list(name = "Street Doctor", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_9, category = "Medical", slots = 1)))
	desc = "A standard medical bay with a basic chemistry setup. Two beds, surgical gear, and some medkits."
	job_slots_add = list(list(name = "New job", officer = FALSE, outfit = /datum/outfit/job/doctor, category = "Medical", slots = 1))
	id = "medical_bay_basic"
	name = "Medical Bay"
	slot = "medical_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/bogatyr
	for_theme = list("trashed", "freshen_up", "nightclub")
	map_file = "bogatyr/workshop/medical_bay_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/workshop_bogatyr_engineering_basic
	job_slots_add_by_theme = list("freshen_up" = list(list(name = "Engineer", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_11, category = "Engineering", slots = 1), list(name = "Enforcer", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_12, category = "Security", slots = 1)), "nightclub" = list(list(name = "Lights and Sounds Guy", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_13, category = "Engineering", slots = 1), list(name = "The Bouncer", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_14, category = "Security", slots = 1)), "trashed" = list(list(name = "Engineer", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_1, category = "Engineering", slots = 1), list(name = "Enforcer", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_3, category = "Security", slots = 1)))
	desc = "\"Engineering\"... Pathetic. Comes with a single PACMAN generator, and a dated but stocked armory."
	job_slots_add = list(list(name = "Engines Guy", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_8, category = "Engineering", slots = 1))
	id = "engineering_basic"
	name = "Engineering And Classic Armory"
	slot = "engineering"
	for_ship = /datum/map_template/shuttle/voidcrew/bogatyr
	for_theme = list("trashed", "freshen_up", "nightclub")
	map_file = "bogatyr/workshop/engineering_and_classic_armory.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/workshop_bogatyr_microbiological_lab
	job_slots_add_by_theme = list("freshen_up" = list(list(name = "Plauge Master", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_18, category = "Medical", slots = 1)), "nightclub" = list(list(name = "Plauge Master", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_19, category = "Medical", slots = 1)), "trashed" = list(list(name = "Plauge Master", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_16, category = "Medical", slots = 1)))
	job_slots_add = list(list(name = "Plauge Master", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_2, category = "Medical", slots = 1))
	part_cost = list(PART_CLASS_SCIENCE = 3, PART_CLASS_MISC = 1)
	id = "microbiological_lab"
	name = "Microbiological Lab"
	slot = "medical_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/bogatyr
	for_theme = list("trashed", "freshen_up", "nightclub")
	map_file = "bogatyr/workshop/microbiological_lab.dmm"
	is_default = FALSE
	desc = "Treat your crews ailments with this claustrophobic \"research\" lab. Chem-Master not included."

/datum/ship_upgrade_module/workshop_bogatyr_pre_configured
	job_slots_add_by_theme = list("freshen_up" = list(list(name = "Professional Researcher", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_31, category = "Science", slots = 1)), "nightclub" = list(list(name = "Professional Researcher", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_32, category = "Science", slots = 1)), "trashed" = list(list(name = "Professional Researcher", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_7, category = "Science", slots = 1)))
	job_slots_add = list(list(name = "Scientist", officer = FALSE, outfit = /datum/outfit/job/scientist, category = "Science", slots = 1))
	part_cost = list(PART_CLASS_SCIENCE = 2, PART_CLASS_TRADE = 1)
	id = "pre_configured"
	name = "Pre-Configured"
	slot = "laboratory"
	for_ship = /datum/map_template/shuttle/voidcrew/bogatyr
	for_theme = list("trashed", "freshen_up", "nightclub")
	map_file = "bogatyr/workshop/pre_configured.dmm"
	is_default = FALSE
	desc = "Are you lazy? Well worry no more with this Pre-Configured lab!"


/datum/ship_upgrade_module/workshop_bogatyr_mining_bay
	job_slots_add_by_theme = list("freshen_up" = list(list(name = "Radioactive Liquidator", officer = FALSE, outfit = /datum/outfit/job/miner/equipped, category = "Cargo", slots = 2)), "nightclub" = list(list(name = "Specialized Drug Smuggler", officer = FALSE, outfit = /datum/outfit/job/miner/equipped, category = "Cargo", slots = 2)), "trashed" = list(list(name = "Radioactive Liquidator", officer = FALSE, outfit = /datum/outfit/job/miner/equipped, category = "Cargo", slots = 2)))
	job_slots_add = list(list(name = "Specialized Miner", officer = FALSE, outfit = /datum/outfit/job/miner/equipped, category = "Cargo", slots = 2))
	part_cost = list(PART_CLASS_COMBAT = 1, PART_CLASS_TRADE = 1, PART_CLASS_MISC = 1)
	id = "mining_bay"
	name = "Mining Bay"
	slot = "eva_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/bogatyr
	for_theme = list("trashed", "freshen_up", "nightclub")
	map_file = "bogatyr/workshop/mining_bay.dmm"
	is_default = FALSE
	desc = "Comes equipped with 2 Miner MOD's, a EVA suit, and some extra mining equipment."

/datum/ship_theme/bogatyr/trashed
	job_slots = list(list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/captain, category = "Command", slots = 1), list(name = "Pomoshchnik", officer = FALSE, outfit = /datum/outfit/job/assistant, category = "Assistant", slots = 4))
	part_cost = list()
	id = "trashed"
	name = "Trashed"
	for_ship = /datum/map_template/shuttle/voidcrew/bogatyr
	template_suffix = "bogatyr"
	is_default = TRUE
	desc = "Exactly what this is, trashed."
	upgrade_slot_ids = list("eva_bay", "laboratory", "medical_bay", "engineering")

/datum/ship_theme/bogatyr/freshen_up
	job_slots = list(list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/captain, category = "Command", slots = 1), list(name = "Pomoshchnik", officer = FALSE, outfit = /datum/outfit/job/assistant, category = "Assistant", slots = 4))
	part_cost = list(PART_CLASS_MISC = 3)
	id = "freshen_up"
	name = "Freshen Up"
	for_ship = /datum/map_template/shuttle/voidcrew/bogatyr
	template_suffix = "bogatyr_freshen_up"
	is_default = FALSE
	desc = "Whoever the previous crew was, they clearly had some sense of decency. The ship comes squeaky clean with extra janitorial supplies."
	upgrade_slot_ids = list("eva_bay", "laboratory", "medical_bay", "engineering")

/datum/ship_upgrade_module/workshop_bogatyr_surgical_suite
	job_slots_add_by_theme = list("freshen_up" = list(list(name = "Surgical Officer", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_20, category = "Medical", slots = 1)), "nightclub" = list(list(name = "O.D Watch", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_21, category = "Medical", slots = 1)), "trashed" = list(list(name = "Surgical Officer", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_17, category = "Medical", slots = 1)))
	part_cost = list(PART_CLASS_SCIENCE = 2)
	job_slots_add = list(list(name = "Real Doctor", officer = FALSE, outfit = /datum/outfit/job/doctor, category = "Medical", slots = 1))
	id = "surgical_suite"
	name = "Surgical Suite"
	slot = "medical_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/bogatyr
	for_theme = list("trashed", "freshen_up", "nightclub")
	map_file = "bogatyr/workshop/surgical_suite.dmm"
	is_default = FALSE
	desc = "Comes with all the equipment needed to revive your dead corpse. Includes a doctor!"

/datum/ship_theme/bogatyr/nightclub
	job_slots = list(list(name = "The DJ", officer = TRUE, outfit = /datum/outfit/job/workshop_bogatyr_job_10, category = "Command", slots = 1), list(name = "Clubber", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_15, category = "Assistant", slots = 20))
	part_cost = list(PART_CLASS_TRADE = 2, PART_CLASS_MISC = 3)
	id = "nightclub"
	name = "Nightclub"
	for_ship = /datum/map_template/shuttle/voidcrew/bogatyr
	template_suffix = "bogatyr_nightclub"
	is_default = FALSE
	desc = "Haters don't like me, 'cause I'm the spotlight, sorry for party rocking!"
	upgrade_slot_ids = list("eva_bay", "laboratory", "medical_bay", "engineering")



/datum/ship_upgrade_module/workshop_bogatyr_enhanced_engineering_module
	part_cost = list(PART_CLASS_TRADE = 2, PART_CLASS_MISC = 2)
	job_slots_add_by_theme = list("freshen_up" = list(list(name = "Engineer", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_37, category = "Engineering", slots = 2)), "nightclub" = list(list(name = "Engineer", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_36, category = "Engineering", slots = 2)), "trashed" = list(list(name = "Engineer", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_35, category = "Engineering", slots = 2)))
	job_slots_add = list(list(name = "Engineer", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_33, category = "Engineering", slots = 1), list(name = "Enforcer", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_34, category = "Security", slots = 1))
	id = "enhanced_engineering_module"
	name = "Enhanced Engineering Module"
	slot = "engineering"
	for_ship = /datum/map_template/shuttle/voidcrew/bogatyr
	for_theme = list("trashed", "freshen_up", "nightclub")
	map_file = "bogatyr/workshop/enhanced_engineering_module.dmm"
	is_default = FALSE
	desc = "Ditch the guns, who needs those when you can turtle."

/datum/ship_upgrade_module/workshop_bogatyr_enhanced_armory
	part_cost = list(PART_CLASS_COMBAT = 2, PART_CLASS_MISC = 2)
	job_slots_add = list(list(name = "Engineer", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_4, category = "Engineering", slots = 1), list(name = "Enforcer", officer = FALSE, outfit = /datum/outfit/job/workshop_bogatyr_job_29, category = "Security", slots = 1))
	id = "enhanced_armory"
	name = "Enhanced Armory"
	slot = "engineering"
	for_ship = /datum/map_template/shuttle/voidcrew/bogatyr
	for_theme = list("trashed", "freshen_up", "nightclub")
	map_file = "bogatyr/workshop/enhanced_armory.dmm"
	is_default = FALSE
	desc = "Tools? Materials? Who needs that when you have a 25% larger armory with 25% more armory things."
