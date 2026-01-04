/**
 * # Exploration Mission
 *
 * A mission that requires the ship to fly to specific overmap coordinates.
 * Completes when the ship reaches the target location.
 */
/datum/mission/exploration
	name = "Exploration Contract"
	desc = "Survey the sector at coordinates (%TARGET_X%, %TARGET_Y%). Fly to this location to complete the contract."
	value = 1500
	weight = 10
	duration = DEFAULT_MISSION_DURATION

	/// Target X coordinate on the overmap
	var/target_x = 0
	/// Target Y coordinate on the overmap
	var/target_y = 0
	/// Whether the target has been visited
	var/visited = FALSE
	/// Range within which the mission counts as complete (tiles from target)
	var/completion_range = 1

/datum/mission/exploration/generate_mission_details()
	// Pick random coordinates on the overmap (relative coords 1 to OVERMAP_SIZE)
	// Avoid the edges and center (sun area)
	var/min_coord = MISSION_OVERMAP_MIN_COORD
	var/max_coord = MISSION_OVERMAP_MAX_COORD
	var/center = round(OVERMAP_SIZE / 2)
	var/sun_radius = 3

	// Try to find coordinates not in the sun
	var/attempts = 20
	while(attempts > 0)
		target_x = rand(min_coord, max_coord)
		target_y = rand(min_coord, max_coord)

		// Check if we're not in the sun area
		var/dist_from_center = sqrt((target_x - center) ** 2 + (target_y - center) ** 2)
		if(dist_from_center > sun_radius)
			break
		attempts--

	// Adjust value based on distance from center (further = more valuable)
	var/center_dist = sqrt((target_x - center) ** 2 + (target_y - center) ** 2)
	var/max_dist = sqrt(2 * (center - min_coord) ** 2)
	var/distance_bonus = (center_dist / max_dist) * 500 // Up to 500 extra credits
	value += round(distance_bonus)

	. = ..()

/datum/mission/exploration/apply_text_substitutions()
	. = ..()
	name = replacetext(name, "%TARGET_X%", "[target_x]")
	name = replacetext(name, "%TARGET_Y%", "[target_y]")
	desc = replacetext(desc, "%TARGET_X%", "[target_x]")
	desc = replacetext(desc, "%TARGET_Y%", "[target_y]")

/datum/mission/exploration/start_mission(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return

	// Register for ship movement signal
	RegisterSignal(servant, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(on_ship_moved))

	// Check if already at destination
	check_position()

/datum/mission/exploration/Destroy()
	if(servant)
		UnregisterSignal(servant, COMSIG_VOIDCREW_SHIP_MOVED)
	return ..()

/**
 * Called when the ship moves on the overmap.
 */
/datum/mission/exploration/proc/on_ship_moved(datum/source)
	SIGNAL_HANDLER
	check_position()

/**
 * Gets the ship's position in relative overmap coordinates (1 to OVERMAP_SIZE).
 * Returns list(x, y) or null if no servant.
 */
/datum/mission/exploration/proc/get_ship_overmap_coords()
	if(!servant)
		return null
	// X is already relative since OVERMAP_LEFT_SIDE_COORD = 1
	var/rel_x = servant.x
	// Y needs conversion from world coords to relative overmap coords
	var/rel_y = servant.y - OVERMAP_SOUTH_SIDE_COORD + 1
	return list(rel_x, rel_y)

/**
 * Checks if the ship is at or near the target coordinates.
 */
/datum/mission/exploration/proc/check_position()
	if(!servant || visited)
		return

	var/list/ship_coords = get_ship_overmap_coords()
	if(!ship_coords)
		return

	var/ship_x = ship_coords[1]
	var/ship_y = ship_coords[2]

	// Check if within range of target
	var/dist = sqrt((ship_x - target_x) ** 2 + (ship_y - target_y) ** 2)
	if(dist <= completion_range)
		visited = TRUE
		servant.ship_announce("Survey coordinates reached! Return to the mission board to collect your reward.", "Mission Update")

/datum/mission/exploration/can_complete()
	if(!..())
		return FALSE
	return visited

/datum/mission/exploration/get_progress_string()
	if(visited)
		return "Complete"
	if(!servant)
		return "0/1"

	var/list/ship_coords = get_ship_overmap_coords()
	if(!ship_coords)
		return "Unknown"

	var/ship_x = ship_coords[1]
	var/ship_y = ship_coords[2]
	var/dist = round(sqrt((ship_x - target_x) ** 2 + (ship_y - target_y) ** 2))
	return "[dist] tiles away"

/datum/mission/exploration/get_ui_data()
	var/list/data = ..()
	data["target_x"] = target_x
	data["target_y"] = target_y
	data["visited"] = visited
	return data
