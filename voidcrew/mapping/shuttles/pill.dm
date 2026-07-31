/datum/map_template/shuttle/voidcrew/pill
	name = "Pill-class Torture Device"
	suffix = "pill"
	short_name = "Pill-class"
	catalog_desc = "Three tiles, one engine, and a mining kit for each of the four bunks, \
		plus a single bay amidships you can fit out. No airlock and no medbay - you suit \
		up in the cabin, drill rocks and carry them back in an ore bag. Free to take, and \
		the smallest thing on the shelf that still flies."
	force_purchasable = TRUE // free and on the shelf despite being four tiles of misery
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("pill_extra")

	job_slots = list(
		list(
			name = "Head Prisoner",
			officer = TRUE,
			outfit = /datum/outfit/job/prisoner,
			category = JOB_CAT_ASSISTANT,
			slots = 1,
		),
		list(
			name = "Prisoner",
			outfit = /datum/outfit/job/prisoner,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/pill
	name = "Pill-class Torture Device"
	area_type = /area/shuttle/voidcrew/pill
	port_direction = 1
	preferred_direction = 1 // must match the aspect-ratio guess in adjust_reserve_dock_to_shuttle or the ship spins every dock


/// AREAS ///

/area/shuttle/voidcrew/pill
	name = "The Pill"
	icon_state = "station"
