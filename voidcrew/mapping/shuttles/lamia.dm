/datum/map_template/shuttle/voidcrew/lamia
	name = "Lamia-class Magery Ship"
	suffix = "lamia"
	short_name = "Lamia-Class"
	part_requirements = list(PART_CLASS_SCIENCE = 3, PART_CLASS_MISC = 1)

	job_slots = list(
		list(
			name = "Alchemist",
			officer = TRUE,
			outfit = /datum/outfit/job/bartender,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Gastronomer",
			outfit = /datum/outfit/job/cook,
			category = JOB_CAT_SERVICE,
			slots = 1,
		),
		list(
			name = "Lorekeeper",
			outfit = /datum/outfit/job/curator,
			category = JOB_CAT_SERVICE,
			slots = 1,
		),
		list(
			name = "Geomancer",
			outfit = /datum/outfit/job/miner,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Allomancer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Scholar",
			outfit = /datum/outfit/job/scientist,
			category = JOB_CAT_SCIENCE,
			slots = 1,
		),
		list(
			name = "Apprentice",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/lamia
	name = "Lamia-class Magery Ship"
	area_type = /area/shuttle/voidcrew/lamia
	port_direction = 8
	preferred_direction = 4


/// AREAS ///

/// Command ///

/area/shuttle/voidcrew/lamia/bridge
	name = "Cockpit Of Infernal Thrust +3"
	icon_state = "bridge"

/// Engineering ///

/area/shuttle/voidcrew/lamia/engines
	name = "Thruster Bay of Paralysis -1"
	icon_state = "engine"

/// Cargo ///

/area/shuttle/voidcrew/lamia/cargo
	name = "Warehouse of Storage"
	icon_state = "cargo_warehouse"

/area/shuttle/voidcrew/lamia/cargo/mining_dock
	name = "Mining Dock of Fireballs +2"
	icon_state = "mining"

/// Service ///

/area/shuttle/voidcrew/lamia/bar
	name = "Tavern Of Yalp Elor's Wrath +5"
	icon_state = "bar"

/area/shuttle/voidcrew/lamia/game_room
	name = "Game Room Of Tableflipping +10"
	icon_state = "station"

/area/shuttle/voidcrew/lamia/kitchen
	name = "Gastronomical Labrotory Of Foul Odor -1"
	icon_state = "kitchen"

/area/shuttle/voidcrew/lamia/archive
	name = "Archive Of Limitless Knowledge"
	icon_state = "library"

/area/shuttle/voidcrew/lamia/dorm
	name = "Dormitories Of Blinding Light +1"
	icon_state = "dorms"

/area/shuttle/voidcrew/lamia/restroom
	name = "Restroom Of Hoptoad +20"
	icon_state = "restrooms"

/// Science ///

/area/shuttle/voidcrew/lamia/study
	name = "Study Of Limited Knowledge"
	icon_state = "science"

/// Hallway ///

/area/shuttle/voidcrew/lamia/hallway/fore
	name = "Fore Hall Of Deafening"
	icon_state = "forehall"

/area/shuttle/voidcrew/lamia/hallway/aft
	name = "Aft Hall Of Architecture"
	icon_state = "afthall"
