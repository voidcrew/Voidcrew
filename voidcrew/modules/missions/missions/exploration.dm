/**
 * # Exploration Mission
 *
 * A mission that requires the ship to fly to specific overmap coordinates.
 * Completes when the ship reaches the target location.
 * Difficulty is determined by the target zone (Neutral=Easy, Contested=Medium, Lawless=Hard).
 */
/datum/mission/exploration
	name = "Exploration Contract"
	desc = "Survey the sector at coordinates (%TARGET_X%, %TARGET_Y%) in the %ZONE_NAME%. Fly to this location to complete the contract."
	weight = 10
	duration = DEFAULT_MISSION_DURATION

	/// Target X coordinate on the overmap
	var/target_x = 0
	/// Target Y coordinate on the overmap
	var/target_y = 0
	/// Target zone type (ZONE_GREEN, ZONE_YELLOW, ZONE_RED)
	var/target_zone = ZONE_GREEN
	/// Target zone display name
	var/target_zone_name = "Neutral Zone"
	/// Whether the target has been visited
	var/visited = FALSE
	/// Range within which the mission counts as complete (tiles from target)
	var/completion_range = 1

/datum/mission/exploration/generate_mission_details()
	var/center = round(OVERMAP_SIZE / 2)
	var/max_radius = (OVERMAP_SIZE - 1) / 2
	var/sun_radius = 3

	// Weighted zone selection (more easy missions, fewer hard)
	var/list/zone_weights = list()
	zone_weights["[ZONE_GREEN]"] = 50   // Easy - most common
	zone_weights["[ZONE_YELLOW]"] = 35  // Medium
	zone_weights["[ZONE_RED]"] = 15     // Hard - rarest
	target_zone = text2num(pick_weight(zone_weights))

	// Set difficulty and rewards based on zone
	switch(target_zone)
		if(ZONE_GREEN)
			target_zone_name = ZONE_NAME_GREEN
			difficulty = MISSION_DIFFICULTY_EASY
			value_min = 400
			value_max = 700
		if(ZONE_YELLOW)
			target_zone_name = ZONE_NAME_YELLOW
			difficulty = MISSION_DIFFICULTY_MEDIUM
			value_min = 800
			value_max = 1300
		if(ZONE_RED)
			target_zone_name = ZONE_NAME_RED
			difficulty = MISSION_DIFFICULTY_HARD
			value_min = 1400
			value_max = 2200

	// Calculate distance range for target zone
	// ZONE_RED: < 0.33 of max_radius (inner ring)
	// ZONE_YELLOW: 0.33 - 0.66 of max_radius (middle ring)
	// ZONE_GREEN: > 0.66 of max_radius (outer ring)
	var/min_dist
	var/max_dist
	switch(target_zone)
		if(ZONE_RED)
			min_dist = sun_radius + 1  // Avoid sun
			max_dist = max_radius * 0.33
		if(ZONE_YELLOW)
			min_dist = max_radius * 0.33
			max_dist = max_radius * 0.66
		if(ZONE_GREEN)
			min_dist = max_radius * 0.66
			max_dist = max_radius - 2  // Avoid edge

	// Generate random coordinates within the zone's distance range
	var/attempts = 30
	while(attempts > 0)
		// Pick random angle and distance within zone range
		var/angle = rand(0, 359) * (3.14159 / 180)  // Convert to radians
		var/dist = rand(round(min_dist), round(max_dist))

		target_x = round(center + cos(angle) * dist)
		target_y = round(center + sin(angle) * dist)

		// Clamp to valid bounds
		target_x = clamp(target_x, MISSION_OVERMAP_MIN_COORD, MISSION_OVERMAP_MAX_COORD)
		target_y = clamp(target_y, MISSION_OVERMAP_MIN_COORD, MISSION_OVERMAP_MAX_COORD)

		// Verify we're in the correct zone
		var/actual_dist = sqrt((target_x - center) ** 2 + (target_y - center) ** 2)
		var/normalized = actual_dist / max_radius
		var/actual_zone
		if(normalized < 0.33)
			actual_zone = ZONE_RED
		else if(normalized < 0.66)
			actual_zone = ZONE_YELLOW
		else
			actual_zone = ZONE_GREEN

		if(actual_zone == target_zone && actual_dist > sun_radius)
			break
		attempts--

	. = ..()

/datum/mission/exploration/apply_text_substitutions()
	. = ..()
	name = replacetext(name, "%TARGET_X%", "[target_x]")
	name = replacetext(name, "%TARGET_Y%", "[target_y]")
	name = replacetext(name, "%ZONE_NAME%", target_zone_name)
	desc = replacetext(desc, "%TARGET_X%", "[target_x]")
	desc = replacetext(desc, "%TARGET_Y%", "[target_y]")
	desc = replacetext(desc, "%ZONE_NAME%", target_zone_name)

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
		servant.ship_notify("Survey coordinates reached! Return to the mission board to collect your reward.", "MISSION UPDATE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

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
	data["target_zone"] = target_zone
	data["target_zone_name"] = target_zone_name
	data["visited"] = visited
	return data
