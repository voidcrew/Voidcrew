
/datum/ship_theme/faction_hyena_standard
	id = "standard"
	name = "Standard"
	for_ship = /datum/map_template/shuttle/voidcrew/faction_hyena
	template_suffix = "faction_hyena"
	is_default = TRUE
	upgrade_slot_ids = list("common_area")

/datum/ship_upgrade_module/faction_hyena_common_area_basic
	id = "common_area_basic"
	name = "Common Area"
	slot = "common_area"
	for_ship = /datum/map_template/shuttle/voidcrew/faction_hyena
	for_theme = list("standard")
	map_file = "faction_hyena/common_area_basic.dmm"
	is_default = TRUE
