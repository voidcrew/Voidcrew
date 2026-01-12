/// MODULES ///


/datum/ship_upgrade_module/dwayne
	for_ship = /datum/map_template/shuttle/voidcrew/dwayne

// oof ouch ow my toe
/datum/ship_upgrade_module/dwayne/med_basic
	id = "med_basic"
	name = "Standard Infirmary"
	desc = "The stock infirmary of the Dwayne-class."
	slot = "medbay"
	map_file = "dwayne/med_basic.dmm"
	is_default = TRUE

/// Expanded medbay - better-equipped for revival
/datum/ship_upgrade_module/dwayne/cargo_expanded
	id = "med_advanced"
	name = "Advanced Infirmary"
	desc = "A retrofitted medical bay fitted with additional equipment."
	slot = "medbay"
	map_file = "dwayne/med_advanced.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 1)

// hangar upgrades

/// Empty hangar
/datum/ship_upgrade_module/dwayne/hangar_empty
	id = "hangar_empty"
	name = "Empty Hangar"
	desc = "An empty hangar. Ripe for modification."
	slot = "hangar"
	map_file = "dwayne/hangar_empty.dmm"
	is_default = TRUE

/// nerd room. you get a starter set of scientific supplies and a little free research, alongside some preset rooms
/datum/ship_upgrade_module/dwayne/hangar_fieldlab
	id = "hangar_science"
	name = "Field Lab Retrofit"
	desc = "A basic science lab, with room for additional machines, contraptions, gizmos, gadgets, war crimes, you name it."
	slot = "hangar"
	map_file = "dwayne/hangar_science.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 1)

/// boykisser but with like. a pirate hat. and "you like killing, don't you?"
/datum/ship_upgrade_module/dwayne/hangar_combat
	id = "hangar_armoury"
	name = "Combat Hangar Retrofit"
	desc = "Want to engage in piracy, clean out ruins, or just have the peace of mind granted by giving your crew advanced military hardware? You'll like this. If you can afford it, at least."
	slot = "hangar"
	map_file = "dwayne/hangar_armoury.dmm"
	part_cost = list(PART_CLASS_COMBAT = 2)
