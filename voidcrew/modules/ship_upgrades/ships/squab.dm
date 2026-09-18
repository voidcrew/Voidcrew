
/datum/ship_upgrade_module/squab
	for_ship = /datum/map_template/shuttle/voidcrew/squab
	for_theme = list("nanotrasen_frigate", "cheap_frigate", "the_patrolboat")

/datum/ship_theme/squab
	for_ship = /datum/map_template/shuttle/voidcrew/squab

/datum/ship_theme/squab/nanotrasen_frigate
	job_slots = list(list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/workshop_squab_job_7, category = "Command", slots = 1), list(name = "Deckhand", officer = FALSE, outfit = /datum/outfit/job/assistant, category = "Assistant", slots = 1), list(name = "Security Detail", officer = FALSE, outfit = /datum/outfit/job/workshop_squab_job_9, category = "Security", slots = 1), list(name = "Repair Technician", officer = FALSE, outfit = /datum/outfit/job/workshop_squab_job_10, category = "Engineering", slots = 1))
	id = "nanotrasen_frigate"
	name = "Nanotrasen Frigate"
	for_ship = /datum/map_template/shuttle/voidcrew/squab
	template_suffix = "squab_a"
	is_default = TRUE
	upgrade_slot_ids = list("squab_lab", "squab_mech_bay", "lab_storage", "director_s_quarters", "squab_gear_room")
	desc = "A dusty, but still relatively fresh hull garbed in Nanotrasen titanium is the basic configuration used by the multipurpose frigate."

/datum/ship_theme/squab/cheap_frigate
	part_cost = list(PART_CLASS_MISC = 3)
	job_slots = list(list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/workshop_squab_job_13, category = "Command", slots = 1), list(name = "Deckhand", officer = FALSE, outfit = /datum/outfit/job/assistant, category = "Assistant", slots = 1), list(name = "Security Detail", officer = FALSE, outfit = /datum/outfit/job/workshop_squab_job_15, category = "Security", slots = 1), list(name = "Repair Technician", officer = FALSE, outfit = /datum/outfit/job/workshop_squab_job_16, category = "Engineering", slots = 1))
	id = "cheap_frigate"
	name = "Cheap Frigate"
	for_ship = /datum/map_template/shuttle/voidcrew/squab
	template_suffix = "squab_b"
	is_default = FALSE
	upgrade_slot_ids = list("squab_lab", "squab_mech_bay", "lab_storage", "director_s_quarters", "squab_gear_room")
	desc = "An old, incredibly cheap hull created due to massive cost-cutting by Nanotrasen. Something about it makes it feel soulful."

/datum/ship_theme/squab/the_patrolboat
	part_cost = list(PART_CLASS_COMBAT = 9)
	job_slots = list(list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/workshop_squab_job_17, category = "Command", slots = 1), list(name = "Deckhand", officer = FALSE, outfit = /datum/outfit/job/assistant, category = "Assistant", slots = 1), list(name = "Security Detail", officer = FALSE, outfit = /datum/outfit/job/workshop_squab_job_19, category = "Security", slots = 1), list(name = "Repair Technician", officer = FALSE, outfit = /datum/outfit/job/workshop_squab_job_20, category = "Engineering", slots = 1))
	id = "the_patrolboat"
	name = "The Patrolboat"
	for_ship = /datum/map_template/shuttle/voidcrew/squab
	template_suffix = "squab_c"
	is_default = FALSE
	upgrade_slot_ids = list("squab_lab", "squab_mech_bay", "lab_storage", "director_s_quarters", "squab_gear_room")
	desc = "An extensively modified Squab frigate refit to house a security patrol team used in regions of space where Nanotrasen does not bother spending money on dedicated combat ships."

/datum/ship_upgrade_module/squab/robotics_lab
	job_slots_add = list(list(name = "Scientist", officer = FALSE, outfit = /datum/outfit/job/scientist, category = "Science", slots = 2))
	id = "squab_lab_basic"
	name = "Robotics Lab"
	slot = "squab_lab"
	for_ship = /datum/map_template/shuttle/voidcrew/squab
	map_file = "squab/robotics_lab.dmm"
	is_default = TRUE
	desc = "Squab's classic Lab designed for field research and robotics: Two fabricators and a basic lathe setup to keep you going."

/datum/ship_upgrade_module/squab/medical_lab
	part_cost = list(PART_CLASS_SCIENCE = 2, PART_CLASS_TRADE = 1, PART_CLASS_MISC = 3)
	job_slots_add = list(list(name = "Medical Researcher", officer = FALSE, outfit = /datum/outfit/job/chemist, category = "Medical", slots = 2))
	id = "medical_lab"
	name = "Medical Lab"
	slot = "squab_lab"
	for_ship = /datum/map_template/shuttle/voidcrew/squab
	map_file = "squab/medical_lab.dmm"
	is_default = FALSE
	desc = "A chemistry lab with some spare medical supplies designed for pharmaceutical research."

/datum/ship_upgrade_module/squab/nanite_lab
	part_cost = list(PART_CLASS_SCIENCE = 3, PART_CLASS_TRADE = 2, PART_CLASS_MISC = 2)
	job_slots_add = list(list(name = "Nanite Researcher", officer = FALSE, outfit = /datum/outfit/job/scientist, category = "Science", slots = 2))
	id = "nanite_lab"
	name = "Nanite Lab"
	slot = "squab_lab"
	for_ship = /datum/map_template/shuttle/voidcrew/squab
	map_file = "squab/nanite_lab.dmm"
	is_default = FALSE
	desc = "A nanite research compartment for quick access to nanite technology and research."

/datum/ship_upgrade_module/squab/mecha_ripley
	id = "squab_mech_bay_basic"
	name = "Mecha Ripley"
	slot = "squab_mech_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/squab
	map_file = "squab/mecha_ripley.dmm"
	is_default = TRUE
	desc = "Squab's basic mecha setup: A mining ripley with some spare repair tools, a recharging station and a crate full of mining equipment."

/datum/ship_upgrade_module/squab/mecha_paddy
	part_cost = list(PART_CLASS_COMBAT = 2, PART_CLASS_MISC = 1)
	id = "mecha_paddy"
	name = "Mecha Paddy"
	slot = "squab_mech_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/squab
	map_file = "squab/mecha_paddy.dmm"
	is_default = FALSE
	desc = "A security upgrade for your vessel: A high-speed, low-drag Paddy mecha to keep your assistants in check."

/datum/ship_upgrade_module/squab/extra_gear_bay
	part_cost = list(PART_CLASS_TRADE = 1, PART_CLASS_MISC = 1)
	id = "extra_gear_bay"
	name = "Extra gear bay"
	slot = "squab_mech_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/squab
	map_file = "squab/extra_gear_bay.dmm"
	is_default = FALSE
	desc = "A small section of the cargobay that includes some extra mining gear for your adventures."

/datum/ship_upgrade_module/squab/ai_core
	id = "lab_storage_basic"
	name = "AI core"
	slot = "lab_storage"
	for_ship = /datum/map_template/shuttle/voidcrew/squab
	map_file = "squab/ai_core.dmm"
	is_default = TRUE
	desc = "Squab's default AI core setup designed for the robotics lab."

/datum/ship_upgrade_module/squab/plumbing_storage
	part_cost = list(PART_CLASS_SCIENCE = 1, PART_CLASS_MISC = 1)
	id = "plumbing_storage"
	name = "Plumbing storage"
	slot = "lab_storage"
	for_ship = /datum/map_template/shuttle/voidcrew/squab
	map_file = "squab/plumbing_storage.dmm"
	is_default = FALSE
	desc = "A basic storage compartment for medical plumbing gear."

/datum/ship_upgrade_module/squab/science_director
	job_slots_add = list(list(name = "Science Director", officer = TRUE, outfit = /datum/outfit/job/rd, category = "Command", slots = 1))
	id = "director_s_quarters_basic"
	name = "Science Director"
	slot = "director_s_quarters"
	for_ship = /datum/map_template/shuttle/voidcrew/squab
	map_file = "squab/science_director.dmm"
	is_default = TRUE
	desc = "A bedroom for the science director with a research modsuit and a filled locker. An experimental prototype resides on the table."

/datum/ship_upgrade_module/squab/medical_director
	part_cost = list(PART_CLASS_SCIENCE = 1, PART_CLASS_MISC = 2)
	job_slots_add = list(list(name = "Medical Director", officer = TRUE, outfit = /datum/outfit/job/workshop_squab_job_5, category = "Command", slots = 1))
	id = "medical_director"
	name = "Medical Director"
	slot = "director_s_quarters"
	for_ship = /datum/map_template/shuttle/voidcrew/squab
	map_file = "squab/medical_director.dmm"
	is_default = FALSE
	desc = "Medical Director's quarters containing a modsuit, a compact defibrillator and a filled locker for medical research."

/datum/ship_upgrade_module/squab/security_director
	part_cost = list(PART_CLASS_COMBAT = 2, PART_CLASS_TRADE = 1)
	job_slots_add = list(list(name = "Security Director", officer = TRUE, outfit = /datum/outfit/job/hos, category = "Command", slots = 1))
	id = "security_director"
	name = "Security Director"
	slot = "director_s_quarters"
	for_ship = /datum/map_template/shuttle/voidcrew/squab
	map_file = "squab/security_director.dmm"
	is_default = FALSE
	desc = "Sleeping quarters for the security director with all his gear intact. A displaycase proudly showcases a multiphase energy gun."

/datum/ship_upgrade_module/squab/miner_gear_room
	job_slots_add = list(list(name = "Shaft Miner", officer = FALSE, outfit = /datum/outfit/job/miner, category = "Cargo", slots = 2))
	id = "squab_gear_room_basic"
	name = "Mining gear"
	slot = "squab_gear_room"
	for_ship = /datum/map_template/shuttle/voidcrew/squab
	map_file = "squab/mining_gear.dmm"
	is_default = TRUE
	desc = "Two suit storage units filled with modsuits and two clothing lockers used for mining."

/datum/ship_upgrade_module/squab/security_gear_room
	part_cost = list(PART_CLASS_COMBAT = 1, PART_CLASS_MISC = 1)
	job_slots_add = list(list(name = "Security Officer", officer = FALSE, outfit = /datum/outfit/job/security, category = "Security", slots = 2))
	id = "security_gear_room"
	name = "Security gear room"
	slot = "squab_gear_room"
	for_ship = /datum/map_template/shuttle/voidcrew/squab
	map_file = "squab/security_gear_room.dmm"
	is_default = FALSE
	desc = "Extra security modsuits and security clothing used for enforcment."
