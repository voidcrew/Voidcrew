/// Backgrounds: owned by M3. See data/backgrounds/spec.md.

// Placeholder hull: everything but the slots, themes and modules, which arrive with the real map.
/datum/map_template/shuttle/voidcrew/escape_pod
	name = "Penitentiary Escape Pod"
	short_name = "Pod"
	suffix = "escape_pod"
	catalog_desc = "A two-seat escape pod off a prison station."
	part_requirements = list()
	background_start = BACKGROUND_CONVICT

	job_slots = list(
		list(
			name = "Escapee",
			outfit = /datum/outfit/job/prisoner,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/escape_pod
	name = "Penitentiary Escape Pod"
	area_type = /area/shuttle/voidcrew/escape_pod
	port_direction = 2
	preferred_direction = 1 // must match the aspect-ratio guess in adjust_reserve_dock_to_shuttle or the ship spins every dock

/// AREAS ///

/area/shuttle/voidcrew/escape_pod
	name = "Penitentiary Escape Pod"
	icon_state = "station"
