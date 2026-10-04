
/datum/ship_theme/starfury_standard
	id = "standard"
	name = "Standard"
	for_ship = /datum/map_template/shuttle/voidcrew/starfury
	template_suffix = "starfury"
	is_default = TRUE
	upgrade_slot_ids = list("engine_configuration")

/datum/ship_upgrade_module/starfury_engine_configuration_basic
	id = "engine_configuration_basic"
	name = "Supermatter Core"
	slot = "engine_configuration"
	for_ship = /datum/map_template/shuttle/voidcrew/starfury
	for_theme = list("standard")
	map_file = "starfury/supermatter_core.dmm"
	is_default = TRUE
	desc = "Looted from a plundered NT Station, this full sized shard is bound to blow up eventually."
