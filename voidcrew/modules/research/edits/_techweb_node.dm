/datum/techweb_node
	// list(
	// 	nebulas = 0,
	// 	asteroids = 0,
	// 	electric_storms = 0,
	// 	emp_storms = 0,
	// 	planets = 0,
	// 	stars = 0,
	// )
	var/list/required_surveyed_objects

/datum/techweb_node/riot_supression/New()
	. = ..()
	design_ids = design_ids.Copy()
	design_ids -= "pin_testing"
