
/datum/ship_theme/gemogee_standard
	id = "standard"
	name = "Bounty Hunter Black"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	template_suffix = "gemogee_bounty_hunter_black"
	is_default = TRUE
	upgrade_slot_ids = list()
	desc = "The standard variation of the ship. \nYou often see this in the hands of \nwell off pirates and bounty hunters"

/datum/ship_theme/gemogee_medical_runner
	part_cost = list()
	id = "medical_runner"
	name = "Medical Runner"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	template_suffix = "gemogee_medical_runner"
	is_default = FALSE
	upgrade_slot_ids = list()
	desc = "A variation of the original Gemogee, created to save lives, instead of destroying them. Though yet, it feels eerily the same..."

/datum/ship_theme/gemogee_industrial_cracker
	part_cost = list()
	id = "industrial_cracker"
	name = "Industrial Cracker"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	template_suffix = "gemogee_industrial_cracker"
	is_default = FALSE
	upgrade_slot_ids = list("cargo_load")
	desc = "A converted Gemogee, designed to assist in salvaging, mining and industrial work. Also a great disguise for bounty hunters!"

/datum/ship_upgrade_module/gemogee_cargo_load_basic
	id = "cargo_load_basic"
	name = "cargo load"
	slot = "cargo_load"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	for_theme = list("industrial_cracker")
	map_file = "gemogee/cargo_load_basic.dmm"
	is_default = TRUE
