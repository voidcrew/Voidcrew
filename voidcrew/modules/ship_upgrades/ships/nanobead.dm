
/datum/ship_theme/ship_nanobead_standard
	job_slots = list(list(name = "Commander", officer = TRUE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_4, category = "Command", slots = 1), list(name = "Assistant to the Regional Commander", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_5, category = "Assistant", slots = 1), list(name = "Engineer", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_11, category = "Engineering", slots = 1))
	id = "standard"
	name = "Light"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	template_suffix = "nanobead"
	is_default = TRUE
	upgrade_slot_ids = list("Biomedical_North", "Services_North", "Biomedical_South", "Services_South")

/datum/ship_theme/ship_nanobead_dark
	part_cost = list()
	job_slots = list(list(name = "Commander", officer = TRUE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_6, category = "Command", slots = 1), list(name = "Assistant to the Regional Commander", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_7, category = "Assistant", slots = 1), list(name = "Engineer", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_70, category = "Engineering", slots = 1))
	id = "dark"
	name = "Dark"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	template_suffix = "nanobead_dark"
	is_default = FALSE
	upgrade_slot_ids = list("Biomedical_North", "Services_North", "Biomedical_South", "Services_South")

/datum/ship_upgrade_module/ship_nanobead_med_sci_north_basic
	job_slots_add_by_theme = list("dark" = list(list(name = "Crew", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_39, category = "Assistant", slots = 1)), "standard" = list(list(name = "Crew", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_1, category = "Assistant", slots = 1)))
	job_slots_add = list()
	id = "med_sci_north_basic"
	name = "Empty Biomedical North"
	slot = "Biomedical_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/empty_biomedical_north.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/ship_nanobead_xenobio
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Xenobiologist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_38, category = "Science", slots = 1)), "standard" = list(list(name = "Xenobiologist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_2, category = "Science", slots = 1)))
	job_slots_add = list()
	id = "xenobio"
	name = "Xenobio North"
	slot = "Biomedical_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/xenobio_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_nanites
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Nanotechnologist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_40, category = "Science", slots = 1)), "standard" = list(list(name = "Nanotechnologist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_3, category = "Science", slots = 1)))
	job_slots_add = list()
	id = "nanites"
	name = "Nanites North"
	slot = "Biomedical_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/nanites_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_robotics
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Roboticist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_41, category = "Science", slots = 1)), "standard" = list(list(name = "Roboticist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_8, category = "Science", slots = 1)))
	id = "robotics"
	name = "Robotics North"
	slot = "Biomedical_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/robotics_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_chemistry
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Chemist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_42, category = "Medical", slots = 1)), "standard" = list(list(name = "Chemist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_9, category = "Medical", slots = 1)))
	id = "chemistry"
	name = "Chemistry North"
	slot = "Biomedical_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/chemistry_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_cryo
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Cryogenicist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_43, category = "Medical", slots = 1)), "standard" = list(list(name = "Cryogenicist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_10, category = "Medical", slots = 1)))
	id = "cryo"
	name = "Cryo Cells North"
	slot = "Biomedical_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/cryo_cells_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_sleeper_bay
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Physician", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_44, category = "Medical", slots = 1)), "standard" = list(list(name = "Physician", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_12, category = "Medical", slots = 1)))
	id = "sleeper_bay"
	name = "Sleeper Bay North"
	slot = "Biomedical_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/sleeper_bay_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_surgery
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Surgeon", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_45, category = "Medical", slots = 1)), "standard" = list(list(name = "Surgeon", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_13, category = "Medical", slots = 1)))
	id = "surgery"
	name = "Surgery North"
	slot = "Biomedical_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/surgery_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_services_north_basic
	job_slots_add_by_theme = list("dark" = list(list(name = "Crew", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_46, category = "Assistant", slots = 1)), "standard" = list(list(name = "Crew", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_14, category = "Assistant", slots = 1)))
	id = "services_north_basic"
	name = "Empty Services North"
	slot = "Services_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/empty_services_north.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/ship_nanobead_bitrunning
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Bitrunner", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_47, category = "Cargo", slots = 1)), "standard" = list(list(name = "Bitrunner", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_15, category = "Cargo", slots = 1)))
	id = "bitrunning"
	name = "Bitrunning North"
	slot = "Services_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/bitrunning_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_dining
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Chef", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_48, category = "Service", slots = 1)), "standard" = list(list(name = "Chef", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_16, category = "Service", slots = 1)))
	id = "dining"
	name = "Dining North"
	slot = "Services_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/dining_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_botany
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Botanist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_49, category = "Service", slots = 1)), "standard" = list(list(name = "Botanist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_17, category = "Service", slots = 1)))
	id = "botany"
	name = "Botany North"
	slot = "Services_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/botany_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_mining
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Metallurgist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_50, category = "Cargo", slots = 1)), "standard" = list(list(name = "Metallurgist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_18, category = "Cargo", slots = 1)))
	id = "mining"
	name = "Mining North"
	slot = "Services_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/mining_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_cargo
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Forklift Operator", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_51, category = "Cargo", slots = 1)), "standard" = list(list(name = "Forklift Operator", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_19, category = "Cargo", slots = 1)))
	id = "cargo"
	name = "Cargo North"
	slot = "Services_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/cargo_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_security
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Security Guard", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_52, category = "Security", slots = 1)), "standard" = list(list(name = "Security Guard", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_20, category = "Security", slots = 1)))
	id = "security"
	name = "Security North"
	slot = "Services_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/security_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_eva
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Crew", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_54, category = "Assistant", slots = 1)), "standard" = list(list(name = "Crew", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_21, category = "Assistant", slots = 1)))
	id = "eva"
	name = "Eva North"
	slot = "Services_North"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/eva_north.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_biomedical_south_basic
	job_slots_add_by_theme = list("dark" = list(list(name = "Crew", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_53, category = "Assistant", slots = 1)), "standard" = list(list(name = "Crew", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_22, category = "Assistant", slots = 1)))
	id = "biomedical_south_basic"
	name = "Empty Biomedical South"
	slot = "Biomedical_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/empty_biomedical_south.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/ship_nanobead_xenobio_south
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Xenobiologist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_55, category = "Science", slots = 1)), "standard" = list(list(name = "Xenobiologist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_23, category = "Science", slots = 1)))
	id = "xenobio_south"
	name = "Xenobio South"
	slot = "Biomedical_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/xenobio_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_nanites_south
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Nanotechnologist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_56, category = "Science", slots = 1)), "standard" = list(list(name = "Nanotechnologist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_24, category = "Science", slots = 1)))
	id = "nanites_south"
	name = "Nanites South"
	slot = "Biomedical_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/nanites_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_robotics_south
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Roboticist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_57, category = "Science", slots = 1)), "standard" = list(list(name = "Roboticist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_25, category = "Science", slots = 1)))
	id = "robotics_south"
	name = "Robotics South"
	slot = "Biomedical_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/robotics_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_chemistry_south
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Chemist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_58, category = "Medical", slots = 1)), "standard" = list(list(name = "Chemist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_26, category = "Medical", slots = 1)))
	id = "chemistry_south"
	name = "Chemistry South"
	slot = "Biomedical_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/chemistry_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_cryo_cells_south
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Cryogenicist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_59, category = "Medical", slots = 1)), "standard" = list(list(name = "Cryogenicist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_27, category = "Medical", slots = 1)))
	id = "cryo_cells_south"
	name = "Cryo Cells South"
	slot = "Biomedical_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/cryo_cells_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_sleeper_bay_south
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Physician", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_60, category = "Medical", slots = 1)), "standard" = list(list(name = "Physician", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_28, category = "Medical", slots = 1)))
	id = "sleeper_bay_south"
	name = "Sleeper Bay South"
	slot = "Biomedical_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/sleeper_bay_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_surgery_south
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Surgeon", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_61, category = "Medical", slots = 1)), "standard" = list(list(name = "Surgeon", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_29, category = "Medical", slots = 1)))
	id = "surgery_south"
	name = "Surgery South"
	slot = "Biomedical_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/surgery_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_services_south_basic
	job_slots_add_by_theme = list("dark" = list(list(name = "Crew", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_62, category = "Assistant", slots = 1)), "standard" = list(list(name = "Crew", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_30, category = "Assistant", slots = 1)))
	id = "services_south_basic"
	name = "Empty Services South"
	slot = "Services_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/empty_services_south.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/ship_nanobead_bitrunning_south
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Bitrunner", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_63, category = "Cargo", slots = 1)), "standard" = list(list(name = "Bitrunner", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_31, category = "Cargo", slots = 1)))
	id = "bitrunning_south"
	name = "Bitrunning South"
	slot = "Services_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/bitrunning_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_dining_south
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Chef", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_64, category = "Service", slots = 1)), "standard" = list(list(name = "Chef", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_32, category = "Service", slots = 1)))
	id = "dining_south"
	name = "Dining South"
	slot = "Services_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/dining_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_botany_south
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Botanist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_65, category = "Service", slots = 1)), "standard" = list(list(name = "Botanist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_33, category = "Service", slots = 1)))
	id = "botany_south"
	name = "Botany South"
	slot = "Services_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/botany_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_mining_south
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Metallurgist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_66, category = "Cargo", slots = 1)), "standard" = list(list(name = "Metallurgist", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_34, category = "Cargo", slots = 1)))
	id = "mining_south"
	name = "Mining South"
	slot = "Services_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/mining_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_cargo_south
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Forklift Operator", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_67, category = "Cargo", slots = 1)), "standard" = list(list(name = "Forklift Operator", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_35, category = "Cargo", slots = 1)))
	id = "cargo_south"
	name = "Cargo South"
	slot = "Services_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/cargo_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_security_south
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Security Guard", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_68, category = "Security", slots = 1)), "standard" = list(list(name = "Security Guard", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_36, category = "Security", slots = 1)))
	id = "security_south"
	name = "Security South"
	slot = "Services_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/security_south.dmm"
	is_default = FALSE

/datum/ship_upgrade_module/ship_nanobead_eva_south
	part_cost = list()
	job_slots_add_by_theme = list("dark" = list(list(name = "Crew", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_69, category = "Assistant", slots = 1)), "standard" = list(list(name = "Crew", officer = FALSE, outfit = /datum/outfit/job/workshop_ship_nanobead_job_37, category = "Assistant", slots = 1)))
	id = "eva_south"
	name = "Eva South"
	slot = "Services_South"
	for_ship = /datum/map_template/shuttle/voidcrew/ship_nanobead
	for_theme = list("standard", "dark")
	map_file = "nanobead/eva_south.dmm"
	is_default = FALSE
