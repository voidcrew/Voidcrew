/datum/map_template/shuttle/voidcrew/superpill
	name = "Power-class Climate Destroyer"
	catalog_desc = "A ship for purely power generation and lack of safety regulations."
	suffix = "superpill"
	short_name = "Power-class Climate Destroyer"
	part_requirements = list()
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("engine")
	player_hidden = FALSE
	job_slots = list()
	available_themes = list("standard", "climate_destroyer_supreme")

/obj/docking_port/mobile/voidcrew/superpill
	name = "Power-class Climate Destroyer"
	area_type = /area/shuttle/voidcrew/superpill
	port_direction = 2
	preferred_direction = NORTH

/area/shuttle/voidcrew/superpill
	name = "Power-class Climate Destroyer"
	icon_state = "station"
