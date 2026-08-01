/**
 * Scarab-class Frigate
 *
 * * It's shaped like a Scarab, that's where the name comes from
 * * Designed for 5-8 players
 * * Fairly standard layout, nothing exceptional
 * * Has a cargo bay, med bay, and basic engineering
 * * Supports 3 themes: Hospital (default), Reinforced (chemistry), Security (patrol)
 */
/datum/map_template/shuttle/voidcrew/scarab
	name = "Scarab-class Frigate"
	short_name = "Scarab-class"
	suffix = "scarab_a" // Default suffix, overridden by selected theme
	catalog_desc = "A mid-size frigate shaped like its namesake, with a medbay, a cargo bay and \
		proper engineering under one roof. The fleet's all-rounder: comfortable for five to \
		eight crew, nothing exceptional in any one direction, and slots for medical, \
		engineering, commons and cargo to lean it whichever way you want."
	part_requirements = list(PART_CLASS_SCIENCE = 14, PART_CLASS_MISC = 10, PART_CLASS_TRADE = 8, PART_CLASS_COMBAT = 4)
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list(
		"scarab_med",
		"scarab_engineering",
		"scarab_common",
		"scarab_cargo",
	)
	available_themes = list("medical", "syndicate", "mining")
	// job_slots come from selected theme, not defined here

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/scarab
	area_type = /area/shuttle/voidcrew/scarab
	// The hull is 33x20 with its port mapped facing west, so the shuttle measures 33 fore
	// to aft against 20 abeam and the aspect-ratio guess in adjust_reserve_dock_to_shuttle
	// comes out EAST. This must match it or the ship spins 90 degrees on every dock.
	preferred_direction = 4

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
