
/datum/ship_theme/gemogee_standard
	id = "standard"
	name = "Bounty Hunter Black"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	template_suffix = "gemogee_bounty_hunter_black"
	is_default = TRUE
	upgrade_slot_ids = list("ship_bay", "south_bay", "wing_modules")
	desc = "The standard variation of the ship. \nYou often see this in the hands of \nwell off pirates and bounty hunters"

/datum/ship_theme/gemogee_medical_runner
	part_cost = list(PART_CLASS_COMBAT = 100)
	id = "medical_runner"
	name = "Medical Runner"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	template_suffix = "gemogee_medical_runner"
	is_default = FALSE
	upgrade_slot_ids = list()
	desc = "A variation of the original Gemogee, created to save lives, instead of destroying them. Though yet, it feels eerily the same..."

/datum/ship_theme/gemogee_industrial_cracker
	part_cost = list(PART_CLASS_COMBAT = 100)
	id = "industrial_cracker"
	name = "Industrial Cracker"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	template_suffix = "gemogee_industrial_cracker"
	is_default = FALSE
	upgrade_slot_ids = list()
	desc = "A converted Gemogee, designed to assist in salvaging, mining and industrial work. Also a great disguise for bounty hunters!"

/datum/ship_upgrade_module/gemogee_ship_bay_basic
	id = "ship_bay_basic"
	name = "Ship Bay"
	slot = "ship_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	for_theme = list("standard")
	map_file = "gemogee/ship_bay_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/gemogee_hunter_bay
	part_cost = list()
	id = "hunter_bay"
	name = "Hunter Bay"
	slot = "ship_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	for_theme = list("standard")
	map_file = "gemogee/hunter_bay.dmm"
	is_default = FALSE
	desc = "Used by most bounty runners worth their salt. Comes with everything you need to catch those criminals."

/datum/ship_upgrade_module/gemogee_medical_bay
	part_cost = list()
	id = "medical_bay"
	name = "Medical Bay"
	slot = "ship_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	for_theme = list("standard")
	map_file = "gemogee/medical_bay.dmm"
	is_default = FALSE
	desc = "A standard bay for all your medical needs. Run in there and save those lives!"

/datum/ship_upgrade_module/gemogee_salvager_bay
	part_cost = list()
	id = "salvager_bay"
	name = "Salvager Bay"
	slot = "ship_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	for_theme = list("standard")
	map_file = "gemogee/salvager_bay.dmm"
	is_default = FALSE
	desc = "For your asteroid cracking and spelunking needs. Tools to deconstruct any rock or ship"

/datum/ship_upgrade_module/gemogee_science_bay
	part_cost = list()
	id = "science_bay"
	name = "Science Bay"
	slot = "ship_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	for_theme = list("standard")
	map_file = "gemogee/science_bay.dmm"
	is_default = FALSE
	desc = "Ever wanted to do science on the run? felt the need to conduct your experiments out of anyones sight? Try out our new top of the line science runner!"

/datum/ship_upgrade_module/gemogee_south_bay_basic
	id = "south_bay_basic"
	name = "South Bay"
	slot = "south_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	for_theme = list("standard")
	map_file = "gemogee/south_bay_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/gemogee_surgical_suite
	part_cost = list()
	id = "surgical_suite"
	name = "Surgical Suite"
	slot = "south_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	for_theme = list("standard")
	map_file = "gemogee/surgical_suite.dmm"
	is_default = FALSE
	desc = "a surgical suite, containing everything you need to perhaps re-attatch limbs"

/datum/ship_upgrade_module/gemogee_mech_suite
	part_cost = list()
	id = "mech_suite"
	name = "Mech Suite"
	slot = "south_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	for_theme = list("standard")
	map_file = "gemogee/mech_suite.dmm"
	is_default = FALSE
	desc = "A miniature Mech bay, loaded with your very own Paddy! This can be useful for anyone from the bounty hunter, salvager or paramedic"

/datum/ship_upgrade_module/gemogee_chemical_suite
	part_cost = list()
	id = "chemical_suite"
	name = "Chemical Suite"
	slot = "south_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	for_theme = list("standard")
	map_file = "gemogee/chemical_suite.dmm"
	is_default = FALSE
	desc = "Feel like making some \"medicine\"? or mabye you actually do. I wont judge either way."

/datum/ship_upgrade_module/gemogee_xenobiological_suite
	part_cost = list()
	id = "xenobiological_suite"
	name = "Xenobiological Suite"
	slot = "south_bay"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	for_theme = list("standard")
	map_file = "gemogee/xenobiological_suite.dmm"
	is_default = FALSE
	desc = "For the ones who loved to play with slime - a chance to do it all over again!"

/datum/ship_upgrade_module/gemogee_wing_modules_basic
	id = "wing_modules_basic"
	name = "Wing Modules"
	slot = "wing_modules"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	for_theme = list("standard")
	map_file = "gemogee/wing_modules_basic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/gemogee_cargo_wings
	part_cost = list()
	id = "cargo_wings"
	name = "Cargo Wings"
	slot = "wing_modules"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	for_theme = list("standard")
	map_file = "gemogee/cargo_wings.dmm"
	is_default = FALSE
	desc = "Ever wished to be a space trucker? Now's your chance!\n"

/datum/ship_upgrade_module/gemogee_leisure_wings
	part_cost = list()
	id = "leisure_wings"
	name = "Leisure Wings"
	slot = "wing_modules"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	for_theme = list("standard")
	map_file = "gemogee/leisure_wings.dmm"
	is_default = FALSE
	desc = "Tired of monotonous work? Mabye you just want to lay down for a bit, eat some food, read a book... Well we've got you covered with our brand new relux(TM) wing modules!"

/datum/ship_upgrade_module/gemogee_science_wings
	part_cost = list()
	id = "science_wings"
	name = "Science Wings"
	slot = "wing_modules"
	for_ship = /datum/map_template/shuttle/voidcrew/gemogee
	for_theme = list("standard")
	map_file = "gemogee/science_wings.dmm"
	is_default = FALSE
	desc = "Need to keep your research moving for legal purpouses? We've got you covered!"
