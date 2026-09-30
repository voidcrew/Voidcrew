/datum/map_template/shuttle/voidcrew/hiryu_class_carrier
	name = "Hiryu-class Carrier"
	catalog_desc = "A medium-sized vessel capable of a range of applications from the get go thanks to it's modularity."
	suffix = "hiryu_class_carrier_titanium_hull"
	short_name = "Hiryu-class Carrier"
	part_requirements = list()
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("engineering", "medbay", "Exosuit_hangar", "Cryogenics", "helm")
	player_hidden = FALSE
	job_slots = list(list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/captain, category = "Command", slots = 1), list(name = "Ship Engineer", officer = FALSE, outfit = /datum/outfit/job/engineer, category = "Engineering", slots = 1), list(name = "Deckhand", officer = FALSE, outfit = /datum/outfit/job/assistant, category = "Assistant", slots = 3))
	available_themes = list("standard", "syndicate", "pink")

/obj/docking_port/mobile/voidcrew/hiryu_class_carrier
	name = "Hiryu-class Carrier"
	area_type = /area/shuttle/voidcrew/hiryu_class_carrier
	port_direction = 2
	preferred_direction = NORTH

/area/shuttle/voidcrew/hiryu_class_carrier
	name = "Hiryu-class Carrier"
	icon_state = "station"
