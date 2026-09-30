
/datum/ship_theme/hiryu_class_carrier_standard
	job_slots = list(list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/captain, category = "Command", slots = 1), list(name = "Ship Engineer", officer = FALSE, outfit = /datum/outfit/job/engineer, category = "Engineering", slots = 1), list(name = "Deckhand", officer = FALSE, outfit = /datum/outfit/job/assistant, category = "Assistant", slots = 3))
	id = "standard"
	name = "Titanium Hull"
	for_ship = /datum/map_template/shuttle/voidcrew/hiryu_class_carrier
	template_suffix = "hiryu_class_carrier_titanium_hull"
	is_default = TRUE
	upgrade_slot_ids = list("engineering", "medbay", "Exosuit_hangar", "Cryogenics", "helm")
	desc = "The ship as it was originally produced."

/datum/ship_theme/hiryu_class_carrier_syndicate
	part_cost = list()
	job_slots = list(list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_25, category = "Command", slots = 1), list(name = "Ship Engineer", officer = FALSE, outfit = /datum/outfit/job/engineer/syndicate, category = "Engineering", slots = 1), list(name = "Deckhand", officer = FALSE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_27, category = "Assistant", slots = 3))
	id = "syndicate"
	name = "Plastitanium Hull"
	for_ship = /datum/map_template/shuttle/voidcrew/hiryu_class_carrier
	template_suffix = "hiryu_class_carrier_plastitanium_hull"
	is_default = FALSE
	upgrade_slot_ids = list("engineering", "medbay", "Exosuit_hangar", "Cryogenics", "helm")
	desc = "Titanium swapped out for Plastitanium for an edgier look."

/datum/ship_theme/hiryu_class_carrier_pink
	part_cost = list()
	job_slots = list(list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_28, category = "Command", slots = 1), list(name = "Ship Engineer", officer = FALSE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_29, category = "Engineering", slots = 1), list(name = "Deckhand", officer = FALSE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_30, category = "Assistant", slots = 3))
	id = "pink"
	name = "Dollhouse Hull"
	for_ship = /datum/map_template/shuttle/voidcrew/hiryu_class_carrier
	template_suffix = "hiryu_class_carrier_dollhouse_hull"
	is_default = FALSE
	upgrade_slot_ids = list("engineering", "medbay", "Exosuit_hangar", "Cryogenics", "helm")
	desc = "Somebody spilled a can of pink paint everywhere."

/datum/ship_upgrade_module/hiryu_class_carrier_engineering_basic
	id = "engineering_basic"
	name = "PACMAN bay"
	slot = "engineering"
	for_ship = /datum/map_template/shuttle/voidcrew/hiryu_class_carrier
	for_theme = list("standard", "syndicate", "pink")
	map_file = "hiryu_class_carrier/pacman_bay.dmm"
	is_default = TRUE
	desc = "A set of pre-loaded PACMAN generators to power the ship."

/datum/ship_upgrade_module/hiryu_class_carrier_medbay_basic
	job_slots_add_by_theme = list("pink" = list(list(name = "Medical Doctor", officer = FALSE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_16, category = "Medical", slots = 1)), "standard" = list(list(name = "Medical Doctor", officer = FALSE, outfit = /datum/outfit/job/doctor, category = "Medical", slots = 1)), "syndicate" = list(list(name = "Medical Doctor", officer = FALSE, outfit = /datum/outfit/job/doctor/syndicate, category = "Medical", slots = 1)))
	id = "medbay_basic"
	name = "Medbay"
	slot = "medbay"
	for_ship = /datum/map_template/shuttle/voidcrew/hiryu_class_carrier
	for_theme = list("standard", "syndicate", "pink")
	map_file = "hiryu_class_carrier/medbay_basic.dmm"
	is_default = TRUE
	desc = "A compact but fully capable medbay, complete with medkits, an operating table and a stasis bed. Adds a Medical Doctor to the crew."

/datum/ship_upgrade_module/hiryu_class_carrier_port_hall_basic
	job_slots_add_by_theme = list("pink" = list(list(name = "Mining Exosuit Pilot", officer = FALSE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_17, category = "Cargo", slots = 1)), "standard" = list(list(name = "Mining Exosuit Pilot", officer = FALSE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_7, category = "Cargo", slots = 1)), "syndicate" = list(list(name = "Mining Exosuit Pilot", officer = FALSE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_3, category = "Cargo", slots = 1)))
	id = "port_hall_basic"
	name = "Mining hangar"
	slot = "Exosuit_hangar"
	for_ship = /datum/map_template/shuttle/voidcrew/hiryu_class_carrier
	for_theme = list("standard", "syndicate", "pink")
	map_file = "hiryu_class_carrier/mining_hangar.dmm"
	is_default = TRUE
	desc = "A well maintained Ripley MK1 exosuit fitted with mining gear for your mech pilot. Adds a Mining Exosuit Pilot to the crew."

/datum/ship_upgrade_module/hiryu_class_carrier_starboard_hall_basic
	id = "starboard_hall_basic"
	name = "Traditional fitting"
	slot = "Cryogenics"
	for_ship = /datum/map_template/shuttle/voidcrew/hiryu_class_carrier
	for_theme = list("standard", "syndicate", "pink")
	map_file = "hiryu_class_carrier/traditional_fitting.dmm"
	is_default = TRUE
	desc = "The look the ship is named for."

/datum/ship_upgrade_module/hiryu_class_carrier_helm_basic
	id = "helm_basic"
	name = "Captain's quarters"
	slot = "helm"
	for_ship = /datum/map_template/shuttle/voidcrew/hiryu_class_carrier
	for_theme = list("standard", "syndicate", "pink")
	map_file = "hiryu_class_carrier/captain_s_quarters.dmm"
	is_default = TRUE
	desc = "Oh captain, my captain!"

/datum/ship_upgrade_module/hiryu_class_carrier_rtg_bay
	part_cost = list()
	id = "rtg_bay"
	name = "RTG bay"
	slot = "engineering"
	for_ship = /datum/map_template/shuttle/voidcrew/hiryu_class_carrier
	for_theme = list("standard", "syndicate", "pink")
	map_file = "hiryu_class_carrier/rtg_bay.dmm"
	is_default = FALSE
	desc = "A set of RTGs to power the ship."

/datum/ship_upgrade_module/hiryu_class_carrier_security_hangar
	part_cost = list()
	job_slots_add_by_theme = list("pink" = list(list(name = "Combat Exosuit Pilot", officer = TRUE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_18, category = "Security", slots = 1)), "standard" = list(list(name = "Combat Exosuit Pilot", officer = TRUE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_8, category = "Security", slots = 1)), "syndicate" = list(list(name = "Combat Exosuit Pilot", officer = TRUE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_5, category = "Security", slots = 1)))
	id = "security_hangar"
	name = "Security hangar"
	slot = "Exosuit_hangar"
	for_ship = /datum/map_template/shuttle/voidcrew/hiryu_class_carrier
	for_theme = list("standard", "syndicate", "pink")
	map_file = "hiryu_class_carrier/security_hangar.dmm"
	is_default = FALSE
	desc = "A well maintained Paddy exosuit with additional equipment for your mech pilot. Adds a Combat Exosuit Pilot to the crew."

/datum/ship_upgrade_module/hiryu_class_carrier_robotics_lab
	part_cost = list()
	job_slots_add_by_theme = list("pink" = list(list(name = "Roboticist", officer = FALSE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_19, category = "Science", slots = 1)), "standard" = list(list(name = "Roboticist", officer = FALSE, outfit = /datum/outfit/job/roboticist, category = "Science", slots = 1)), "syndicate" = list(list(name = "Roboticist", officer = FALSE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_13, category = "Science", slots = 1)))
	id = "robotics_lab"
	name = "Robotics lab"
	slot = "medbay"
	for_ship = /datum/map_template/shuttle/voidcrew/hiryu_class_carrier
	for_theme = list("standard", "syndicate", "pink")
	map_file = "hiryu_class_carrier/robotics_lab.dmm"
	is_default = FALSE
	desc = "A partically constructed lab, with a surgical setup and man machine interfaces. Adds a Roboticist to the crew."

/datum/ship_upgrade_module/hiryu_class_carrier_gaming_room
	part_cost = list()
	job_slots_add_by_theme = list("pink" = list(list(name = "Barmaid", officer = FALSE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_20, category = "Service", slots = 1)), "standard" = list(list(name = "Bartender", officer = FALSE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_12, category = "Service", slots = 1)), "syndicate" = list(list(name = "Bartender", officer = FALSE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_14, category = "Service", slots = 1)))
	id = "gaming_room"
	name = "Bar"
	slot = "Cryogenics"
	for_ship = /datum/map_template/shuttle/voidcrew/hiryu_class_carrier
	for_theme = list("standard", "syndicate", "pink")
	map_file = "hiryu_class_carrier/bar.dmm"
	is_default = FALSE
	desc = "Booze and gambling to keep the crew entertained. Adds a Bartender to the crew."

/datum/ship_upgrade_module/hiryu_class_carrier_grill
	part_cost = list()
	job_slots_add_by_theme = list("pink" = list(list(name = "Maid", officer = FALSE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_21, category = "Service", slots = 1)), "standard" = list(list(name = "Cook", officer = FALSE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_9, category = "Service", slots = 1)), "syndicate" = list(list(name = "Cook", officer = FALSE, outfit = /datum/outfit/job/workshop_hiryu_class_carrier_job_15, category = "Service", slots = 1)))
	id = "grill"
	name = "Grill"
	slot = "Exosuit_hangar"
	for_ship = /datum/map_template/shuttle/voidcrew/hiryu_class_carrier
	for_theme = list("standard", "syndicate", "pink")
	map_file = "hiryu_class_carrier/grill.dmm"
	is_default = FALSE
	desc = "Exosuits? Who cares about exosuits. I just wanna grill for god's sake. Adds a Cook to the crew."

/datum/ship_upgrade_module/hiryu_class_carrier_cargo_bay
	part_cost = list()
	id = "cargo_bay"
	name = "Cargo bay"
	slot = "Cryogenics"
	for_ship = /datum/map_template/shuttle/voidcrew/hiryu_class_carrier
	for_theme = list("standard", "syndicate", "pink")
	map_file = "hiryu_class_carrier/cargo_bay.dmm"
	is_default = FALSE
	desc = "Some space for long term storage and a basic cryo room and dorm."

/datum/ship_upgrade_module/hiryu_class_carrier_bridge
	part_cost = list()
	id = "bridge"
	name = "Bridge"
	slot = "helm"
	for_ship = /datum/map_template/shuttle/voidcrew/hiryu_class_carrier
	for_theme = list("standard", "syndicate", "pink")
	map_file = "hiryu_class_carrier/bridge.dmm"
	is_default = FALSE
	desc = "A simple helm featuring multiple extra consoles and emergency supplies."

/datum/ship_upgrade_module/hiryu_class_carrier_xenobiology_pens
	part_cost = list()
	id = "xenobiology_pens"
	name = "Xenobiology pens"
	slot = "Cryogenics"
	for_ship = /datum/map_template/shuttle/voidcrew/hiryu_class_carrier
	for_theme = list("standard", "syndicate", "pink")
	map_file = "hiryu_class_carrier/xenobiology_pens.dmm"
	is_default = FALSE
	desc = "A xenobiology lab for your ship."
