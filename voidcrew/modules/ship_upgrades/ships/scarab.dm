/datum/ship_upgrade_module/scarab
	for_ship = /datum/map_template/shuttle/voidcrew/scarab
	// All Scarab modules are shared across all three themes
	for_theme = list("medical", "syndicate", "mining")

/datum/ship_upgrade_module/scarab/med_basic
	id = "scarab_med_basic"
	name = "Medical Storage"
	desc = "A small storage area for medical supplies. \
		Comes pre-stocked with medkits and basic equipment."
	slot = "scarab_med"
	map_file = "scarab/scarab_med_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/scarab/med_surgery
	id = "scarab_med_surgery"
	name = "Surgical Suite"
	desc = "A fully equipped surgical suite for advanced medical procedures. \
		Comes with extra prosthetic limbs."
	slot = "scarab_med"
	map_file = "scarab/scarab_med_surgery.dmm"
	part_cost = list(PART_CLASS_MISC = 1)

/datum/ship_upgrade_module/scarab/med_chem
	id = "scarab_med_chem"
	name = "Medical Chemistry Lab"
	desc = "A dedicated chemistry lab. \
		Comes with a syringe gun."
	slot = "scarab_med"
	map_file = "scarab/scarab_med_chem.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 1)

/datum/ship_upgrade_module/scarab/engineering_basic
	id = "scarab_engineering_basic"
	name = "Engineering Bay"
	desc = "A basic engineering, supplying the ship with breathable air and power. \
		Also includes an additional external airlock for EVA operations."
	slot = "scarab_engineering"
	map_file = "scarab/scarab_engineering_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/scarab/engineering_teg
	id = "scarab_engineering_teg"
	name = "Thermal-Electric Generator"
	desc = "An engineering bay containing an air supply and a fully functional Thermal-Electric Generator (TEG), \
		providing an immense amount of sustainable power to the ship."
	slot = "scarab_engineering"
	map_file = "scarab/scarab_engineering_teg.dmm"
	part_cost = list(PART_CLASS_TRADE = 2) // TEG is pretty OP

/datum/ship_upgrade_module/scarab/common_quarters
	id = "scarab_common_basic"
	name = "Common Quarters"
	desc = "A simple common area with a microwave and a few chairs, \
		allowing the crew to relax and eat."
	slot = "scarab_common"
	map_file = "scarab/scarab_common_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/scarab/common_cryo
	id = "scarab_common_cryo"
	name = "Cryogenics Bay"
	desc = "A fully functional cryogentics bay with two cryo tubes that can heal most injuries over time."
	slot = "scarab_common"
	map_file = "scarab/scarab_common_cryo.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 1)

/datum/ship_upgrade_module/scarab/cargo_basic
	id = "scarab_cargo_basic"
	name = "Cargo Bay"
	desc = "A moderately sized cargo bay that can hold upwards of a dozen crates."
	slot = "scarab_cargo"
	map_file = "scarab/scarab_cargo_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/scarab/cargo_engi
	id = "scarab_cargo_engi"
	name = "EVA Bay"
	desc = "A moderately sized cargo bay that can hold upwards of a half dozen crates. \
		Comes with recharging stations intended for quicker EVA operations."
	slot = "scarab_cargo"
	map_file = "scarab/scarab_cargo_engi.dmm"
	part_cost = list(PART_CLASS_COMBAT = 1) // Basically just a cargo bay but with stuff that makes space combat easier

/datum/ship_upgrade_module/scarab/cargo_med
	id = "scarab_cargo_med"
	name = "Extra Medical Bay"
	desc = "A fully equipped medical bay with two stasis beds and a variety of medical supplies. \
		Intended to supplement the main medical area of the ship."
	slot = "scarab_cargo"
	map_file = "scarab/scarab_cargo_med.dmm"
	part_cost = list(PART_CLASS_MISC = 1)

// ========== SCARAB THEMES ==========

/datum/ship_theme/scarab
	for_ship = /datum/map_template/shuttle/voidcrew/scarab

/datum/ship_theme/scarab/medical
	id = "medical"
	name = "Hospital Variant"
	desc = "Medical-focused configuration with a Chief Medical Officer and dedicated doctors. \
		Designed for emergency response and patient care."
	is_default = TRUE
	template_suffix = "scarab_a"
	upgrade_slot_ids = list(
		"scarab_med",
		"scarab_engineering",
		"scarab_common",
		"scarab_cargo",
	)
	job_slots = list(
		list(
			name = "Chief Medical Officer",
			officer = TRUE,
			outfit = /datum/outfit/job/cmo,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Medical Doctor",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 2,
		),
		list(
			name = "Ship Engineer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Atmospheric Technician",
			outfit = /datum/outfit/job/atmos,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Resource Acquisition Specialist",
			outfit = /datum/outfit/job/miner,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Resident",
			outfit = /datum/outfit/job/assistant/resident/a,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

/datum/ship_theme/scarab/syndicate
	id = "syndicate"
	name = "Reinforced Variant"
	desc = "Chemistry-focused variant with reinforced hull. \
		Designed for pharmaceutical operations and hazardous material handling."
	part_cost = list(PART_CLASS_SCIENCE = 1)
	template_suffix = "scarab_b"
	upgrade_slot_ids = list(
		"scarab_med",
		"scarab_engineering",
		"scarab_common",
		"scarab_cargo",
	)
	job_slots = list(
		list(
			name = "Chief Pharmacist Officer",
			officer = TRUE,
			outfit = /datum/outfit/job/cmo,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Pharmacist",
			outfit = /datum/outfit/job/chemist,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Medical Doctor",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Ship Engineer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Atmospheric Technician",
			outfit = /datum/outfit/job/atmos,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Resource Acquisition Specialist",
			outfit = /datum/outfit/job/miner,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Resident",
			outfit = /datum/outfit/job/assistant/resident/b,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

/datum/ship_theme/scarab/mining
	id = "mining"
	name = "Security Variant"
	desc = "Patrol-focused variant with security crew. \
		Designed for sector patrol and law enforcement operations."
	part_cost = list(PART_CLASS_COMBAT = 1)
	template_suffix = "scarab_c"
	upgrade_slot_ids = list(
		"scarab_med",
		"scarab_engineering",
		"scarab_common",
		"scarab_cargo",
	)
	job_slots = list(
		list(
			name = "Captain",
			officer = TRUE,
			outfit = /datum/outfit/job/captain,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Medical Officer",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Engineering Officer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Resource Acquisition Specialist",
			outfit = /datum/outfit/job/miner,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Security Officer",
			outfit = /datum/outfit/job/security,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
		list(
			name = "Assistant",
			outfit = /datum/outfit/job/assistant/resident/c,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)
