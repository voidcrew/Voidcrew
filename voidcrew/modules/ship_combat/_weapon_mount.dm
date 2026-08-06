// Shared behaviour for ship combat weapon mounts.
//
// Missile launchers, laser turrets and assault pod tubes all fire outward, so
// they all have to sit against the outside of the ship, and anything they fire
// enters the target's reservation from one of its four sides. Both rules used to
// be copy-pasted per machine.

/obj/machinery/ship_combat
	/// Cached exterior check result (mounts don't move while anchored)
	var/cached_exterior_check
	/// Whether the exterior cache is valid
	var/exterior_cache_valid = FALSE

/// Checks if this weapon is on the exterior of the ship (adjacent to non-shuttle-area tile)
/// Weapons must be on the exterior to fire - they need line of sight to space/outside
/// Result is cached while anchored since mounts don't move
/obj/machinery/ship_combat/proc/is_on_exterior()
	// Return cached result if valid (only valid while anchored)
	if(exterior_cache_valid && anchored)
		return cached_exterior_check

	var/turf/our_turf = get_turf(src)
	if(!our_turf)
		return FALSE

	// Get the shuttle areas for our ship
	var/area/our_area = get_area(src)
	var/list/shuttle_areas
	for(var/obj/structure/overmap/ship/S in SSovermap.simulated_ships)
		if(!S.shuttle)
			continue
		if(our_area in S.shuttle.shuttle_areas)
			shuttle_areas = S.shuttle.shuttle_areas
			break

	// Check all adjacent tiles (including diagonals)
	var/result = FALSE
	for(var/turf/T in range(1, our_turf))
		if(T == our_turf)
			continue
		var/area/tile_area = get_area(T)
		// If adjacent tile is not in shuttle areas, we're on exterior
		if(!tile_area || !(tile_area in shuttle_areas))
			result = TRUE
			break

	// Cache the result
	cached_exterior_check = result
	exterior_cache_valid = TRUE

	return result

/// Invalidates the exterior check cache (call when the mount is moved/anchored)
/obj/machinery/ship_combat/proc/invalidate_exterior_cache()
	exterior_cache_valid = FALSE

// ========== APPROACH GEOMETRY ==========
// Where a shot fired from this mount enters the target's reservation, and from
// which side. Missiles and assault pods both fly in from outside the hull.

/// Calculates where an incoming projectile should spawn - outside the target, in
/// the transit space around it.
/// approach_dir: If provided, the shot comes from this direction. Otherwise auto-calculated to find a clear path.
/obj/machinery/ship_combat/proc/get_missile_spawn_turf(turf/target, obj/structure/overmap/tgt_ship, approach_dir = null)
	if(!target)
		return null

	// Get target footprint bounds (ships: shuttle rect; outposts: build region)
	var/min_x = target.x
	var/max_x = target.x
	var/min_y = target.y
	var/max_y = target.y

	var/list/bounds = tgt_ship?.get_combat_bounds()
	if(bounds && bounds.len >= 4)
		min_x = bounds[1]
		min_y = bounds[2]
		max_x = bounds[3]
		max_y = bounds[4]

	// How far outside the ship to spawn (between ship edge and black wall)
	var/spawn_dist = 10

	var/spawn_x = target.x
	var/spawn_y = target.y

	// Calculate direction if not provided - find a clear path through hull breaches
	var/dir = approach_dir
	if(!dir)
		dir = find_clear_approach_direction(target, min_x, max_x, min_y, max_y, spawn_dist)

	// Spawn missiles from the selected direction
	switch(dir)
		if(NORTH)
			// Missiles come FROM the north, spawn above the ship
			spawn_y = max_y + spawn_dist
			spawn_x = target.x
		if(SOUTH)
			// Missiles come FROM the south, spawn below the ship
			spawn_y = min_y - spawn_dist
			spawn_x = target.x
		if(EAST)
			// Missiles come FROM the east, spawn to the right of the ship
			spawn_x = max_x + spawn_dist
			spawn_y = target.y
		if(WEST)
			// Missiles come FROM the west, spawn to the left of the ship
			spawn_x = min_x - spawn_dist
			spawn_y = target.y

	return locate(spawn_x, spawn_y, target.z)

/// Finds the best approach direction for a missile to reach a target
/// Prioritizes clear paths (through hull breaches), then picks the shortest among them
/// If no clear paths exist, falls back to the shortest path overall
/// Returns a direction constant (NORTH, SOUTH, EAST, WEST)
/obj/machinery/ship_combat/proc/find_clear_approach_direction(turf/target, min_x, max_x, min_y, max_y, spawn_dist)
	var/list/clear_directions = list()
	var/list/direction_distances = list()

	// Calculate path distance and clearance for each direction
	for(var/check_dir in list(NORTH, SOUTH, EAST, WEST))
		var/spawn_x = target.x
		var/spawn_y = target.y
		var/distance

		switch(check_dir)
			if(NORTH)
				spawn_y = max_y + spawn_dist
				distance = spawn_y - target.y
			if(SOUTH)
				spawn_y = min_y - spawn_dist
				distance = target.y - spawn_y
			if(EAST)
				spawn_x = max_x + spawn_dist
				distance = spawn_x - target.x
			if(WEST)
				spawn_x = min_x - spawn_dist
				distance = target.x - spawn_x

		var/turf/spawn_turf = locate(spawn_x, spawn_y, target.z)
		if(!spawn_turf)
			continue

		direction_distances["[check_dir]"] = distance

		// Check if path from spawn to target is clear (no dense walls blocking)
		if(check_path_clear(spawn_turf, target))
			clear_directions += check_dir

	// If we found clear paths, return the shortest one
	if(length(clear_directions))
		var/best_dir
		var/best_distance = INFINITY
		for(var/dir in clear_directions)
			var/dist = direction_distances["[dir]"]
			if(dist < best_distance)
				best_distance = dist
				best_dir = dir
		return best_dir

	// No clear paths - return the shortest direction overall (will hit walls)
	var/best_dir
	var/best_distance = INFINITY
	for(var/dir_key in direction_distances)
		var/dist = direction_distances[dir_key]
		if(dist < best_distance)
			best_distance = dist
			best_dir = text2num(dir_key)
	return best_dir

/// Checks if there's a clear line-of-sight path between two turfs
/// Returns TRUE if the path is clear (no dense walls), FALSE otherwise
/obj/machinery/ship_combat/proc/check_path_clear(turf/start, turf/end)
	if(!start || !end)
		return FALSE

	// Get all turfs in the line from start to end
	var/list/path_turfs = get_line(start, end)

	for(var/turf/T in path_turfs)
		// Skip the start and end turfs
		if(T == start || T == end)
			continue

		// Check if this turf itself is dense (like a wall turf)
		if(T.density)
			return FALSE

		// Check for dense objects on this turf (walls, airlocks, etc)
		for(var/obj/O in T)
			// Skip objects that missiles can pass through
			if(!O.density)
				continue
			// Windows and grilles can be broken through - consider them passable
			if(istype(O, /obj/structure/window) || istype(O, /obj/structure/grille))
				continue
			// Dense object blocks the path
			return FALSE

	return TRUE
