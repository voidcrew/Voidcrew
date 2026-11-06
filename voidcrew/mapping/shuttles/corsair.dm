/// Backgrounds: owned by M3. See data/backgrounds/spec.md.

// Placeholder hull: everything but the slots, themes and modules, which arrive with the real map.
/datum/map_template/shuttle/voidcrew/corsair
	name = "Corsair-class Raider"
	short_name = "Corsair-class"
	suffix = "corsair_a"
	catalog_desc = "A fast raider with teeth: lasers, a missile tube, an interdictor and a siphon rig."
	part_requirements = list()
	background_start = BACKGROUND_PIRATE

	job_slots = list(
		list(
			name = "Captain",
			officer = TRUE,
			outfit = /datum/outfit/job/captain/pirate,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "First Mate",
			outfit = /datum/outfit/job/hop/pirate,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Buccaneer",
			outfit = /datum/outfit/job/security/pirate,
			category = JOB_CAT_SECURITY,
			slots = 2,
		),
		list(
			name = "Motorman",
			outfit = /datum/outfit/job/engineer/pirate,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Sawbones",
			outfit = /datum/outfit/job/doctor/pirate,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Deckhand",
			outfit = /datum/outfit/job/assistant/pirate,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/corsair
	name = "Corsair-class Raider"
	area_type = /area/shuttle/voidcrew/corsair
	port_direction = 8
	preferred_direction = 4 // must match the aspect-ratio guess in adjust_reserve_dock_to_shuttle or the ship spins every dock

/obj/docking_port/mobile/voidcrew/corsair/a
	name = "Corsair-class Raider A"

/obj/docking_port/mobile/voidcrew/corsair/b
	name = "Corsair-class Raider B"

/// AREAS ///

/area/shuttle/voidcrew/corsair
	name = "Corsair-class Raider"
	icon_state = "station"

/area/shuttle/voidcrew/corsair/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/corsair/bridge/a

/area/shuttle/voidcrew/corsair/bridge/b

/area/shuttle/voidcrew/corsair/gunnery
	name = "Gunnery"
	icon_state = "bridge"

/area/shuttle/voidcrew/corsair/gunnery/a

/area/shuttle/voidcrew/corsair/gunnery/b

/area/shuttle/voidcrew/corsair/crew
	name = "Crew Quarters"
	icon_state = "dorms"

/area/shuttle/voidcrew/corsair/crew/a

/area/shuttle/voidcrew/corsair/crew/b

/area/shuttle/voidcrew/corsair/engineering
	name = "Engineering"
	icon_state = "engine"

/area/shuttle/voidcrew/corsair/engineering/a

/area/shuttle/voidcrew/corsair/engineering/b

/area/shuttle/voidcrew/corsair/hold
	name = "Hold"
	icon_state = "cargo_bay"

/area/shuttle/voidcrew/corsair/hold/a

/area/shuttle/voidcrew/corsair/hold/b

/area/shuttle/voidcrew/corsair/hallway
	name = "Hallway"
	icon_state = "hallC"

/area/shuttle/voidcrew/corsair/hallway/a

/area/shuttle/voidcrew/corsair/hallway/b
