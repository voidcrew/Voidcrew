/datum/map_template/shuttle/voidcrew/pill_black
	name = "Pill-class-B(lack) Suicide Device"
	suffix = "pill_black"
	short_name = "Blackpill-class"
	catalog_desc = "A Pill with orange hardsuits and a self-destruct charge bolted to the \
		cabin floor. Three bunks, the same ore bags but improvised picks instead of drills, \
		the same complete lack of facilities. Free to take."
	force_purchasable = TRUE // 3 tiles and a bomb, no upgrade slots, free and on the shelf anyway

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
			slots = 2,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/pill_black
	name = "Pill-class-B(lack) Suicide Device"
	area_type = /area/shuttle/voidcrew/pill_black
	port_direction = 1
	preferred_direction = 1 // must match the aspect-ratio guess in adjust_reserve_dock_to_shuttle or the ship spins every dock


/// AREAS ///

/area/shuttle/voidcrew/pill_black
	name = "The Fringe"
	icon_state = "station"
