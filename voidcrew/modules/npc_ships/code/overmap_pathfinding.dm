/**
 * # Overmap Pathfinding
 *
 * A* pathfinding implementation for NPC ships on the overmap.
 * Also includes patrol circuit generation for territorial patrol behavior.
 */

// ========== A* PATHFINDING ==========

/**
 * A* pathfinding for the overmap.
 * Finds a path from start to goal, avoiding obstacles and respecting zone constraints.
 *
 * @param start Starting turf
 * @param goal Target turf
 * @param zone_constraint If set, path cannot leave this zone
 * @param max_iterations Safety limit to prevent infinite loops (default 1000)
 * @return List of turfs from start to goal (inclusive), or null if no path found
 */
/proc/overmap_astar(turf/start, turf/goal, datum/overmap_zone/zone_constraint = null, max_iterations = 1000)
	if(!start || !goal)
		return null
	if(start == goal)
		return list(start)

	// Check if goal is valid (O(1) assoc list lookup)
	if(zone_constraint && !zone_constraint.turfs[goal])
		return null
	if(overmap_turf_blocked(goal))
		return null

	// A* data structures
	var/list/open_set = list()      // Turfs to evaluate (keyed by turf ref for fast lookup)
	var/list/closed_set = list()    // Already evaluated turfs
	var/list/came_from = list()     // For path reconstruction
	var/list/g_score = list()       // Cost from start to node
	var/list/f_score = list()       // g_score + heuristic

	// Initialize
	open_set[start] = TRUE
	g_score[start] = 0
	f_score[start] = overmap_heuristic(start, goal)

	var/iterations = 0
	while(length(open_set) && iterations < max_iterations)
		iterations++

		// Yield to server every 50 iterations to prevent blocking
		if(iterations % 50 == 0)
			CHECK_TICK

		// Find node in open_set with lowest f_score
		var/turf/current = null
		var/lowest_f = INFINITY
		for(var/turf/T as anything in open_set)
			var/f = f_score[T]
			if(f < lowest_f)
				lowest_f = f
				current = T

		if(!current)
			break

		// Reached goal!
		if(current == goal)
			return overmap_reconstruct_path(came_from, current)

		// Move current from open to closed
		open_set -= current
		closed_set[current] = TRUE

		// Check all neighbors (8-directional)
		for(var/turf/neighbor as anything in overmap_get_neighbors(current))
			// Skip if already evaluated
			if(closed_set[neighbor])
				continue

			// Skip if blocked by obstacle
			if(overmap_turf_blocked(neighbor))
				continue

			// Skip if outside zone constraint (O(1) assoc list lookup)
			if(zone_constraint && !zone_constraint.turfs[neighbor])
				continue

			// Calculate tentative g_score
			var/move_cost = overmap_move_cost(current, neighbor)
			var/tentative_g = g_score[current] + move_cost

			// Check if this is a new node or a better path
			var/neighbor_g = g_score[neighbor]
			if(isnull(neighbor_g))
				neighbor_g = INFINITY

			if(tentative_g < neighbor_g)
				// This is a better path
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + overmap_heuristic(neighbor, goal)

				if(!open_set[neighbor])
					open_set[neighbor] = TRUE

	// No path found
	return null

/**
 * Heuristic function for A* (Euclidean distance)
 */
/proc/overmap_heuristic(turf/start_turf, turf/end_turf)
	var/dx = end_turf.x - start_turf.x
	var/dy = end_turf.y - start_turf.y
	return sqrt(dx * dx + dy * dy)

/**
 * Movement cost between adjacent tiles
 * Cardinal = 1, Diagonal = 1.4
 */
/proc/overmap_move_cost(turf/start_turf, turf/end_turf)
	var/dx = abs(end_turf.x - start_turf.x)
	var/dy = abs(end_turf.y - start_turf.y)
	if(dx && dy)
		return 1.4  // Diagonal
	return 1  // Cardinal

/**
 * Get all valid neighbor turfs (8-directional)
 */
/proc/overmap_get_neighbors(turf/center)
	var/list/neighbors = list()
	for(var/dir in GLOB.alldirs)
		var/turf/neighbor = get_step(center, dir)
		if(neighbor)
			neighbors += neighbor
	return neighbors

/**
 * Check if a turf is blocked by an obstacle.
 * Uses cached lookup for O(1) performance (cache built at round start).
 */
/proc/overmap_turf_blocked(turf/T)
	if(!T)
		return TRUE
	// O(1) cached lookup - cache is built at round start by SSovermap_zones
	return GLOB.overmap_blocked_turfs[T]

/**
 * Reconstruct the path from came_from map
 */
/proc/overmap_reconstruct_path(list/came_from, turf/current)
	var/list/path = list(current)
	while(came_from[current])
		current = came_from[current]
		path.Insert(1, current)  // Insert at beginning
	return path


// ========== PATROL CIRCUIT GENERATION ==========

/**
 * Generates a circular patrol circuit around the zone center.
 * Each ship gets a slightly different radius for variety.
 *
 * @param zone The zone to patrol
 * @param variance_percent How much to vary the radius (0.1 = 10%)
 * @param num_waypoints Number of waypoints in the circuit (default 12)
 * @return List of turfs forming the patrol circuit, or null if generation failed
 */
/proc/generate_patrol_circuit(datum/overmap_zone/zone, variance_percent = 0.15, num_waypoints = 12)
	if(!zone || !length(zone.turfs))
		return null

	// Get zone boundaries based on zone type
	var/inner_radius
	var/outer_radius
	var/max_radius = SSovermap_zones.max_radius

	switch(zone.zone_type)
		if(ZONE_RED)
			// Inner ring: 0 to 0.33 of max_radius
			inner_radius = 2  // Don't go too close to center (sun)
			outer_radius = max_radius * 0.33
		if(ZONE_YELLOW)
			// Middle ring: 0.33 to 0.66 of max_radius
			inner_radius = max_radius * 0.33
			outer_radius = max_radius * 0.66
		if(ZONE_GREEN)
			// Outer ring: 0.66 to 1.0 of max_radius
			inner_radius = max_radius * 0.66
			outer_radius = max_radius * 0.95  // Don't go to very edge

	// Calculate base patrol radius (middle of zone)
	var/base_radius = (inner_radius + outer_radius) / 2

	// Apply random variance
	var/variance = base_radius * variance_percent
	var/patrol_radius = base_radius + rand(-variance, variance)

	// Clamp to zone boundaries
	patrol_radius = clamp(patrol_radius, inner_radius + 1, outer_radius - 1)

	// Get center point
	var/center_x = SSovermap_zones.center_x
	var/center_y = SSovermap_zones.center_y

	// Generate waypoints around the circle
	var/list/waypoints = list()
	var/angle_step = 360 / num_waypoints

	for(var/i in 0 to (num_waypoints - 1))
		var/angle = i * angle_step  // Already in degrees

		// Calculate waypoint position (BYOND trig functions use degrees, not radians!)
		var/wx = center_x + cos(angle) * patrol_radius
		var/wy = center_y + sin(angle) * patrol_radius

		// Round to nearest tile
		wx = round(wx)
		wy = round(wy)

		// Get the turf at this position
		var/turf/waypoint = locate(wx, wy, OVERMAP_Z_LEVEL)

		// Validate waypoint is in zone and not blocked (O(1) lookup)
		if(waypoint && zone.turfs[waypoint])
			if(!overmap_turf_blocked(waypoint))
				waypoints += waypoint
			else
				// Try to find nearby unblocked turf
				var/turf/alt = find_nearby_unblocked_turf(waypoint, zone)
				if(alt)
					waypoints += alt

	// Need at least 3 waypoints for a valid circuit
	if(length(waypoints) < 3)
		return null

	return waypoints

/**
 * Finds a nearby unblocked turf within the zone.
 * Used when a circuit waypoint lands on an obstacle.
 */
/proc/find_nearby_unblocked_turf(turf/blocked, datum/overmap_zone/zone, search_range = 3)
	if(!blocked || !zone)
		return null

	for(var/dist in 1 to search_range)
		for(var/dir in GLOB.alldirs)
			var/turf/check = get_step(blocked, dir)
			for(var/step in 1 to dist)
				if(!check)
					break
				if(zone.turfs[check] && !overmap_turf_blocked(check))  // O(1) lookup
					return check
				check = get_step(check, dir)

	return null

/**
 * Finds the nearest waypoint in a circuit to the given position.
 * Used for rejoining patrol after combat.
 *
 * @param position Current position (turf)
 * @param circuit List of circuit waypoints
 * @return Index of nearest waypoint (1-based), or 0 if circuit is empty
 */
/proc/find_nearest_circuit_waypoint(turf/position, list/circuit)
	if(!position || !length(circuit))
		return 0

	var/nearest_index = 1
	var/nearest_dist = INFINITY

	for(var/i in 1 to length(circuit))
		var/turf/waypoint = circuit[i]
		if(!waypoint)
			continue
		var/dist = get_dist(position, waypoint)
		if(dist < nearest_dist)
			nearest_dist = dist
			nearest_index = i

	return nearest_index


// ========== PATH FOLLOWING HELPERS ==========

/**
 * Gets the next turf to move to from a path.
 * Returns null if path is empty or current position not on path.
 *
 * @param path The path list
 * @param current_pos Current position
 * @return Next turf to move to, or null
 */
/proc/get_next_path_turf(list/path, turf/current_pos)
	if(!length(path) || !current_pos)
		return null

	// Find current position in path
	var/current_index = path.Find(current_pos)
	if(!current_index)
		// Not on path - return first turf
		return path[1]

	// Return next turf if available
	if(current_index < length(path))
		return path[current_index + 1]

	// At end of path
	return null

/**
 * Checks if a path is still valid (no new obstacles blocking it).
 *
 * @param path The path to check
 * @param start_index Check from this index onwards (1-based)
 * @return TRUE if path is clear, FALSE if blocked
 */
/proc/path_still_valid(list/path, start_index = 1)
	if(!length(path))
		return FALSE

	for(var/i in start_index to length(path))
		var/turf/T = path[i]
		if(overmap_turf_blocked(T))
			return FALSE

	return TRUE
