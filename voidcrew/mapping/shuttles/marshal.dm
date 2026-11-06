/// Backgrounds: owned by M2. See data/backgrounds/spec.md.

// Placeholder hull: everything but the slots, themes and modules, which arrive with the real map.
/datum/map_template/shuttle/voidcrew/marshal
	name = "Marshal-class Prisoner Transport"
	short_name = "Marshal-class"
	suffix = "marshal_a"
	catalog_desc = "A licensed bounty hunter's cutter: a two-cell brig, a warrant console and room for six."
	part_requirements = list()
	background_start = BACKGROUND_BOUNTY_HUNTER

	job_slots = list(
		list(
			name = "Marshal",
			officer = TRUE,
			outfit = /datum/outfit/job/captain/bounty_hunter,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Deputy",
			outfit = /datum/outfit/job/security/bounty_hunter,
			category = JOB_CAT_SECURITY,
			slots = 3,
		),
		list(
			name = "Mechanic",
			outfit = /datum/outfit/job/engineer/bounty_hunter,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Tracker",
			outfit = /datum/outfit/job/assistant/bounty_hunter,
			category = JOB_CAT_ASSISTANT,
			slots = 1,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/marshal
	name = "Marshal-class Prisoner Transport"
	area_type = /area/shuttle/voidcrew/marshal
	port_direction = 1
	preferred_direction = 1 // must match the aspect-ratio guess in adjust_reserve_dock_to_shuttle or the ship spins every dock

/obj/docking_port/mobile/voidcrew/marshal/a
	name = "Marshal-class Prisoner Transport A"

/obj/docking_port/mobile/voidcrew/marshal/b
	name = "Marshal-class Prisoner Transport B"

/// AREAS ///

/area/shuttle/voidcrew/marshal
	name = "Marshal-class Prisoner Transport"
	icon_state = "station"

/area/shuttle/voidcrew/marshal/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/marshal/bridge/a

/area/shuttle/voidcrew/marshal/bridge/b

/area/shuttle/voidcrew/marshal/brig
	name = "Brig"
	icon_state = "brig"

/area/shuttle/voidcrew/marshal/brig/a

/area/shuttle/voidcrew/marshal/brig/b

/area/shuttle/voidcrew/marshal/crew
	name = "Crew Quarters"
	icon_state = "dorms"

/area/shuttle/voidcrew/marshal/crew/a

/area/shuttle/voidcrew/marshal/crew/b

/area/shuttle/voidcrew/marshal/engineering
	name = "Engineering"
	icon_state = "engine"

/area/shuttle/voidcrew/marshal/engineering/a

/area/shuttle/voidcrew/marshal/engineering/b

/area/shuttle/voidcrew/marshal/bay
	name = "Bay"
	icon_state = "cargo_bay"

/area/shuttle/voidcrew/marshal/bay/a

/area/shuttle/voidcrew/marshal/bay/b

/area/shuttle/voidcrew/marshal/hallway
	name = "Hallway"
	icon_state = "hallC"

/area/shuttle/voidcrew/marshal/hallway/a

/area/shuttle/voidcrew/marshal/hallway/b
