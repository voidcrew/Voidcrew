/**
 * # Exploration Mission
 *
 * Fly the ship to marked coordinates, then come home for the pay. The
 * coordinates come from the zone controller's own turf sets (no private ring
 * math), and pay scales through the shared zone table.
 */
/datum/mission/exploration
	name = "Exploration Contract"
	weight = 10
	// Green-band pay; apply_zone_scaling() raises it for deeper zones
	value_min = 400
	value_max = 700

/datum/mission/exploration/setup_target()
	var/datum/mission_target/coords/coords = new(src)
	// Weighted zone selection (more easy missions, fewer hard)
	coords.zone_weights = list(
		"[ZONE_GREEN]" = 50,
		"[ZONE_YELLOW]" = 35,
		"[ZONE_RED]" = 15,
	)
	if(!coords.resolve())
		qdel(coords)
		return FALSE
	target = coords
	return TRUE

/datum/mission/exploration/build_objectives()
	add_objective(new /datum/mission_objective/goto_coords)

/datum/mission/exploration/update_text()
	name = "Exploration Contract: ([target.target_x], [target.target_y])"
	desc = "Chart the sector at coordinates ([target.target_x], [target.target_y]) in the [target_zone_name]. Fly to this location, then return to the mission board to collect the fee."

/datum/mission/exploration/waypoint_label()
	return "Survey site"

/datum/mission/exploration/get_ui_data()
	var/list/data = ..()
	data["target_x"] = target.target_x
	data["target_y"] = target.target_y
	return data
