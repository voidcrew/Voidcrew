/datum/map_template/shuttle/voidcrew/ship_nanobead
	name = "NanoBead-Class Corvette"
	catalog_desc = "A compact ship including 2 biomedical rooms and 2 service rooms along a central hallway, capped by command and engine maintenance on either side."
	suffix = "nanobead"
	short_name = "NanoBead"
	part_requirements = list()
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("Biomedical_North", "Services_North", "Biomedical_South", "Services_South")
	player_hidden = FALSE
	job_slots = list()
	available_themes = list("standard", "dark")

/obj/docking_port/mobile/voidcrew/ship_nanobead
	name = "NanoBead"
	area_type = /area/shuttle/voidcrew/ship_nanobead
	port_direction = 2
	preferred_direction = NORTH

/area/shuttle/voidcrew/ship_nanobead
	name = "NanoBead"
	icon_state = "station"
