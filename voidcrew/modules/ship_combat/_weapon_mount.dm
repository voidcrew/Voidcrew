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
	/// Whether this mount can be bolted into a hull wall by dragging it onto one.
	var/wall_mountable = FALSE
	/// How long bolting into a wall takes.
	var/wall_mount_time = 5 SECONDS

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

// ========== WALL MOUNTING ==========
// Weapon mounts have to sit on the exterior, which on most hulls means giving up a
// floor tile in a corridor that already has none to spare. Sinking one into the hull
// plating instead is the same trade the hull defense turrets make, so it is mounted
// the same way: wrench it loose, drag it onto the wall.
//
// Dragging rather than pushing is not a style choice. A mount is dense, so it can be
// pulled out of a closed turf but never walked back into one - Move() rejects the
// destination. Without the drag there is no way back in.

/**
 * Drag an unbolted mount onto an adjacent wall to bolt it into the hull.
 *
 * The mount ends up facing the way you shoved it, i.e. out through the far side of
 * the wall, which is the outboard side whenever you are standing inside your own ship.
 */
/obj/machinery/ship_combat/mouse_drop_dragged(atom/over, mob/user, src_location, over_location, params)
	if(!wall_mountable)
		return ..()

	var/turf/wall = over
	if(!isclosedturf(wall))
		return ..()

	if(anchored)
		balloon_alert(user, "unbolt it first")
		return

	var/mount_dir = get_dir(src, wall)
	if(!(mount_dir in GLOB.cardinals))
		balloon_alert(user, "move it beside the wall")
		return

	if(wall_mount_blocker(wall))
		balloon_alert(user, "no room in that wall")
		return

	balloon_alert(user, "mounting...")
	if(!do_after(user, wall_mount_time, target = src))
		return
	// Re-check: it is a long enough job that someone could have moved or bolted it.
	if(anchored || QDELETED(wall) || wall_mount_blocker(wall) || get_dir(src, wall) != mount_dir)
		return

	forceMove(wall)
	setDir(mount_dir)
	set_anchored(TRUE)
	invalidate_exterior_cache()
	update_appearance()
	playsound(src, 'sound/items/deconstruct.ogg', 50, TRUE)
	user.visible_message(
		span_notice("[user] bolts [src] into [wall]."),
		span_notice("You bolt [src] into [wall]."),
	)
	// The mount only became exterior-facing just now, and the launcher's auto-link
	// refuses to link anything that is not, so give it another go from its new home.
	after_wall_mount(user)

/// Anything already occupying a wall that would stop another mount going in there.
/obj/machinery/ship_combat/proc/wall_mount_blocker(turf/wall)
	return (locate(/obj/machinery/ship_combat) in wall) || (locate(/obj/machinery/porta_turret) in wall)

/// Hook for subtypes that need to react to being bolted into a wall.
/obj/machinery/ship_combat/proc/after_wall_mount(mob/user)
	return

/**
 * The tile something leaving this mount should be set down on.
 *
 * A mount bolted to the deck hands things to its own tile, like any other machine.
 * One sunk into hull plating cannot: its tile IS the wall, so a pod - or a rider
 * climbing out of one - would be forceMoved into solid plating. Step out from the
 * inboard side and take the first tile that is actually standable.
 *
 * Returns null when the mount is walled in on every side, so callers can refuse the
 * move rather than bury whatever was leaving. Never returns nullspace: a crewed
 * object with no turf is what put boarding parties in the CentCom error room.
 *
 * Arguments:
 * * leaving - the atom being set down, so its own density doesn't block its exit.
 */
/obj/machinery/ship_combat/proc/get_disembark_turf(atom/movable/leaving)
	var/turf/our_turf = get_turf(src)
	if(!our_turf)
		return null
	if(!isclosedturf(our_turf))
		return our_turf

	// Behind us first - that is the inboard side, the one the crew is standing on -
	// then any open side, so nothing stays wedged in solid rock.
	for(var/exit_dir in (list(REVERSE_DIR(dir)) + GLOB.cardinals))
		var/turf/exit = get_step(our_turf, exit_dir)
		if(!exit || exit.is_blocked_turf(exclude_mobs = TRUE, source_atom = leaving || src))
			continue
		return exit
	return null

/**
 * Shove a freshly unbolted mount out of the wall it was sitting in.
 *
 * A loose mount inside a wall cannot be wrenched down again - default_unfasten_wrench
 * refuses to anchor anything on a blocked turf - so leaving it there is a dead end that
 * looks like a bug. Popping it out onto the deck puts it back in a state the player has
 * seen before.
 */
/obj/machinery/ship_combat/proc/eject_from_wall(mob/user)
	if(anchored || !wall_mountable)
		return FALSE
	var/turf/our_turf = get_turf(src)
	if(!isclosedturf(our_turf))
		return FALSE

	var/turf/exit = get_disembark_turf()
	if(!exit || exit == our_turf)
		return FALSE
	forceMove(exit)
	invalidate_exterior_cache()
	if(user)
		balloon_alert(user, "pried out of the wall")
	return TRUE

/obj/machinery/ship_combat/examine(mob/user)
	. = ..()
	if(!wall_mountable)
		return
	if(!anchored)
		. += span_notice("It is loose. Drag it onto a hull wall to bolt it into the plating, or wrench it down where it stands.")
	else if(isclosedturf(get_turf(src)))
		. += span_notice("It is sunk into the hull plating. A wrench frees it.")
	else
		. += span_notice("It is bolted to the deck. Unwrench it and drag it onto a hull wall to sink it into the plating instead.")

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
