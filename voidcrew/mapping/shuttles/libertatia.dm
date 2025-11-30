/datum/map_template/shuttle/voidcrew/libertatia
	name = "Libertatia-class Hauler"
	suffix = "libertatia"
	short_name = "Libertatia-Class"
	part_cost = 2

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
			name = "Buccanner",
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
			name = "Ship's Doctor",
			outfit = /datum/outfit/job/doctor/pirate,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Deckhand",
			outfit = /datum/outfit/job/assistant/pirate,
			category = JOB_CAT_ASSISTANT,
			slots = 4,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/libertatia
	name = "Libertatia-class Hauler"
	area_type = /area/shuttle/voidcrew/libertatia
	port_direction = 2
	preferred_direction = 4


/// AREAS ///

/// Command ///

/area/shuttle/voidcrew/libertatia/bridge
	name = "Bridge"
	icon_state = "bridge"

/// Security ///

/area/shuttle/voidcrew/libertatia/armory
	name = "Armory"
	icon_state = "armory"

/// Cargo ///

/area/shuttle/voidcrew/libertatia/cargo_bay
	name = "Cargo Bay"
	icon_state = "cargo_warehouse"

/// Service ///

/area/shuttle/voidcrew/libertatia/crew_lounge
	name = "Crew Lounge"
	icon_state = "station"

/// Maintenance ///

/area/shuttle/voidcrew/libertatia/maintenance/port
	name = "Port Maintenance"
	icon_state = "portmaint"

/area/shuttle/voidcrew/libertatia/maintenance/starboard
	name = "Starboard Maintenance"
	icon_state = "starboardmaint"
