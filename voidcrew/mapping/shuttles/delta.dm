/datum/map_template/shuttle/voidcrew/delta
	name = "Delta-class Frigate"
	suffix = "delta"
	short_name = "Delta-class"
	part_cost = 3

	job_slots = list(
		list(
			name = "Captain",
			officer = TRUE,
			outfit = /datum/outfit/job/captain,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Quartermaster",
			outfit = /datum/outfit/job/quartermaster,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Medical Doctor",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Station Engineer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Shaft Miner",
			outfit = /datum/outfit/job/miner,
			category = JOB_CAT_CARGO,
			slots = 2,
		),
		list(
			name = "Assistant",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/delta
	name = "Delta-class Frigate"
	area_type = /area/shuttle/voidcrew/delta
	port_direction = 8
	preferred_direction = 4

/// AREAS ///

/// Command ///

/area/shuttle/voidcrew/delta/bridge
	name = "Bridge"
	icon_state = "bridge"

/// Engineering ///
/area/shuttle/voidcrew/delta/engineering
	name = "Engineering"
	icon_state = "engine"

/// Medbay ///

/area/shuttle/voidcrew/delta/medbay
	name = "Medbay"
	icon_state = "medbay"

/// Cargo ///

/area/shuttle/voidcrew/delta/cargo
	name = "Cargo Bay"
	icon_state = "cargo_bay"

/// Service ///

/area/shuttle/voidcrew/delta/dorms
	name = "Dormitories"
	icon_state = "dorms"

/area/shuttle/voidcrew/delta/cafe
	name = "Cafeteria"
	icon_state = "cafeteria"

/// Hallways ///

/area/shuttle/voidcrew/delta/hallway/central
	name = "Central Primary Hallway"
	icon_state = "centralhall"

/area/shuttle/voidcrew/delta/airlock/port
	name = "Port Airlock"
	icon_state = "porthall"

/area/shuttle/voidcrew/delta/airlock/starboard
	name = "Starboard Airlock"
	icon_state = "starboardmaint"
