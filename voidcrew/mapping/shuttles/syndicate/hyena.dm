/datum/map_template/shuttle/voidcrew/hyena
	name = "Hyena-class Wrecking Tug"
	suffix = "syndicate_hyena"
	short_name = "Hyena-Class"
	part_requirements = list(PART_CLASS_TRADE = 2)

	job_slots = list(
		list(
			name = "Captain",
			officer = TRUE,
			outfit = /datum/outfit/job/captain/syndicate,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Foreman",
			outfit = /datum/outfit/job/ce/syndicate,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Mechanic",
			outfit = /datum/outfit/job/engineer/syndicate,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Atmospheric Mechanic",
			outfit = /datum/outfit/job/atmos/syndicate,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Wrecker",
			outfit = /datum/outfit/job/miner/syndicate,
			category = JOB_CAT_CARGO,
			slots = 2,
		),
		list(
			name = "Junior Agent",
			outfit = /datum/outfit/job/assistant/syndicate,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/hyena
	name = "Hyena-class Wrecking Tug"
	area_type = /area/shuttle/voidcrew/hyena
	port_direction = 8
	preferred_direction = 4


/// AREAS ///

/// Command ///

/area/shuttle/voidcrew/hyena/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/hyena/bridge/foreman
	name = "Foreman's Office"
	icon_state = "ce_office"

/// Security ///

/area/shuttle/voidcrew/hyena/armory
	name = "Armory"
	icon_state = "armory"

/// Cargo ///

/area/shuttle/voidcrew/hyena/cargo_bay
	name = "Cargo Bay"
	icon_state = "cargo_bay"

/// Service ///

/area/shuttle/voidcrew/hyena/equipment
	name = "Equipment Room"
	icon_state = "station"

/area/shuttle/voidcrew/hyena/dorms
	name = "Dormitories"
	icon_state = "dorms"

/area/shuttle/voidcrew/hyena/dorms/commons
	name = "Commons"
	icon_state = "commons"

/// Hallways ///

/area/shuttle/voidcrew/hyena/hallway
	name = "Port Hallway"
	icon_state = "hall"

/// Maintenance ///

/area/shuttle/voidcrew/hyena/maintenance/port
	name = "Port Maintenance"
	icon_state = "portmaint"

/area/shuttle/voidcrew/hyena/maintenance/starboard
	name = "Starboard Maintenance"
	icon_state = "starboardmaint"

/area/shuttle/voidcrew/hyena/maintenance/fore
	name = "Fore Maintenance"
	icon_state = "foremaint"
