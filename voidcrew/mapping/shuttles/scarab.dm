/**
 * Scarab-class Frigate
 *
 * * It's shaped like a Scarab, that's where the name comes from
 * * Designed for 5-8 players
 * * Fairly standard layout, nothing exceptional
 * * Has a cargo bay, med bay, and basic engineering
 */
/datum/map_template/shuttle/voidcrew/scarab
	abstract = /datum/map_template/shuttle/voidcrew/scarab
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list(
		"scarab_med",
		"scarab_engineering",
		"scarab_common",
		"scarab_cargo",
	)

/datum/map_template/shuttle/voidcrew/scarab/a
	// Variant A is themed around medical and being a mobile hospital
	name = "Scarab-class Frigate A: Hospital Variant"
	suffix = "scarab_a"
	short_name = "Scarab-class A"
	theme = "medical"

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

/datum/map_template/shuttle/voidcrew/scarab/b
	// Variant B is heavily reinforced so it's themed around chemists (whom are prone to blowing themselves up), being a mobile chem dealer
	name = "Scarab-class Frigate B: Reinforced Variant"
	suffix = "scarab_b"
	short_name = "Scarab-class B"
	theme = "syndicate"
	part_requirements = list(PART_CLASS_SCIENCE = 1)

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

/datum/map_template/shuttle/voidcrew/scarab/c
	// Variant C is more standard / combat focused and is themed around security roles, being a patrol frigate
	// (The logic being it multiple upgrades for better medical, which you'd want if you're sending your team into dangerous situations)
	name = "Scarab-class Frigate C: Security Variant"
	suffix = "scarab_c"
	short_name = "Scarab-class C"
	theme = "mining"
	part_requirements = list(PART_CLASS_COMBAT = 1)

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

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/scarab
	area_type = /area/shuttle/voidcrew/scarab

/obj/docking_port/mobile/voidcrew/scarab/a
	name = "Scarab-class Frigate A"

/obj/docking_port/mobile/voidcrew/scarab/b
	name = "Scarab-class Frigate B"

/obj/docking_port/mobile/voidcrew/scarab/c
	name = "Scarab-class Frigate C"

/// AREAS ///

/// Command ///

/area/shuttle/voidcrew/scarab/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/scarab/bridge/a

/area/shuttle/voidcrew/scarab/bridge/b

/area/shuttle/voidcrew/scarab/bridge/c

/area/shuttle/voidcrew/scarab/captains_office
	name = "Captain's Quarters"
	icon_state = "captain"

/area/shuttle/voidcrew/scarab/captains_office/a

/area/shuttle/voidcrew/scarab/captains_office/b

/area/shuttle/voidcrew/scarab/captains_office/c

/area/shuttle/voidcrew/scarab/cmos_office
	name = "Chief Medical Officer's Quarters"
	icon_state = "cmo_office"

/area/shuttle/voidcrew/scarab/cmos_office/a

/area/shuttle/voidcrew/scarab/cmos_office/b

/area/shuttle/voidcrew/scarab/cmos_office/c

/// Engineering ///

/area/shuttle/voidcrew/scarab/engineering
	name = "Engineering Bay"
	icon_state = "engine"

/area/shuttle/voidcrew/scarab/engineering/a

/area/shuttle/voidcrew/scarab/engineering/b

/area/shuttle/voidcrew/scarab/engineering/c

/area/shuttle/voidcrew/scarab/engines
	name = "Engine Room"
	icon_state = "atmos_engine"

/area/shuttle/voidcrew/scarab/engines/a

/area/shuttle/voidcrew/scarab/engines/b

/area/shuttle/voidcrew/scarab/engines/c

/// Medbay ///

/area/shuttle/voidcrew/scarab/medbay
	name = "Medical Bay"
	icon_state = "medbay"

/area/shuttle/voidcrew/scarab/medbay/a

/area/shuttle/voidcrew/scarab/medbay/b

/area/shuttle/voidcrew/scarab/medbay/c

/// Misc ///

/area/shuttle/voidcrew/scarab/cargo_bay
	name = "Cargo Bay"
	icon_state = "cargo_bay"

/area/shuttle/voidcrew/scarab/cargo_bay/a

/area/shuttle/voidcrew/scarab/cargo_bay/b

/area/shuttle/voidcrew/scarab/cargo_bay/c

/area/shuttle/voidcrew/scarab/commons
	name = "Common Room"
	icon_state = "station"

/area/shuttle/voidcrew/scarab/commons/a

/area/shuttle/voidcrew/scarab/commons/b

/area/shuttle/voidcrew/scarab/commons/c

/area/shuttle/voidcrew/scarab/dormitories
	name = "Dormitories"
	icon_state = "dorms"

/area/shuttle/voidcrew/scarab/dormitories/a

/area/shuttle/voidcrew/scarab/dormitories/b

/area/shuttle/voidcrew/scarab/dormitories/c

/// OUTFITS

/datum/outfit/job/assistant/resident
	name = "Assistant - Resident"

/datum/outfit/job/assistant/resident/give_jumpsuit(mob/living/carbon/human/target)
	return

/datum/outfit/job/assistant/resident/a
	name = "Assistant - Resident A"
	uniform = /obj/item/clothing/under/rank/medical/scrubs/blue
	shoes = /obj/item/clothing/shoes/sneakers/blue

/datum/outfit/job/assistant/resident/b
	name = "Assistant - Resident B"
	uniform = /obj/item/clothing/under/rank/medical/scrubs/green
	shoes = /obj/item/clothing/shoes/sneakers/green

/datum/outfit/job/assistant/resident/c
	name = "Assistant - Resident C"
	uniform = /obj/item/clothing/under/rank/security/officer
	shoes = /obj/item/clothing/shoes/sneakers/red

// For the TEG, the default amount of plasma is too high and will clog it

/obj/machinery/atmospherics/components/tank/plasma/less
	name = "pressure tank (Plasma)"
	gas_type = null
	flags_1 = parent_type::flags_1 | NO_NEW_GAGS_PREVIEW_1

/obj/machinery/atmospherics/components/tank/plasma/less/Initialize(mapload)
	. = ..()
	fill_to_pressure(/datum/gas/plasma, 0.1)
