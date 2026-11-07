/datum/map_template/shuttle/voidcrew/patrol_bee
	name = "Patrol Bee"
	catalog_desc = "The NT Patrol Bee is a once-proud Nanotrasen patrol cruiser, forgotten and left to drift in favour of the more mobile Delta-class models. Consists of every module you'd need ranging from cargo ending with service."
	suffix = "patrol_bee_nanotrasen"
	short_name = "Patrol Bee"
	part_requirements = list()
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("Upper_Cargo", "closet", "cleanroom", "service", "security_bay")
	player_hidden = FALSE
	job_slots = list()
	available_themes = list("standard", "syndicate_black")

/obj/docking_port/mobile/voidcrew/patrol_bee
	name = "Patrol Bee"
	area_type = /area/shuttle/voidcrew/patrol_bee
	port_direction = 2
	preferred_direction = NORTH

/area/shuttle/voidcrew/patrol_bee
	name = "Patrol Bee"
	icon_state = "station"
