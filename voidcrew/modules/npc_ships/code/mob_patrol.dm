/**
 * Mob Patrol System - Door-to-door navigation for boarding parties
 *
 * Instead of covering every turf, mobs navigate from door to door,
 * exploring rooms systematically. This prevents random structure destruction
 * and creates purposeful room-by-room searching.
 */

// Debug logging toggle - set to TRUE to enable patrol debug messages
#define PATROL_DEBUG TRUE

#if PATROL_DEBUG
#define PATROL_LOG(msg) log_shuttle("PATROL: [msg]")
#else
#define PATROL_LOG(msg)
#endif

/**
 * Generate a door-to-door patrol path for a ship.
 * Returns a list of doors to visit in order, creating a route through all accessible rooms.
 *
 * @param ship The overmap ship to generate a path for
 * @return List of door objects in visit order, or null if generation fails
 */
/proc/generate_ship_patrol_path(obj/structure/overmap/ship/target_ship)
	PATROL_LOG("generate_ship_patrol_path called for [target_ship]")

	if(!target_ship?.shuttle?.shuttle_areas?.len)
		PATROL_LOG("FAILED: No shuttle or shuttle_areas on target ship")
		return null

	// Collect all interior doors on the ship (exclude external airlocks, blast doors, etc.)
	var/list/obj/machinery/door/all_doors = list()
	for(var/area/ship_area as anything in target_ship.shuttle.shuttle_areas)
		for(var/obj/machinery/door/D in ship_area)
			// Skip firedoors
			if(istype(D, /obj/machinery/door/firedoor))
				continue
			// Skip blast doors / poddoors - these are critical ship infrastructure
			if(istype(D, /obj/machinery/door/poddoor))
				continue
			// Skip external airlocks by type
			if(istype(D, /obj/machinery/door/airlock/external))
				continue
			// Skip doors with "external" in the name
			if(findtext(D.name, "external"))
				continue
			// Check if door leads to space or non-ship area
			var/leads_to_space = FALSE
			var/turf/door_turf = get_turf(D)
			if(door_turf)
				for(var/dir in GLOB.cardinals)
					var/turf/adj = get_step(door_turf, dir)
					if(!adj)
						continue
					// Skip if leads to space
					if(isspaceturf(adj))
						leads_to_space = TRUE
						break
					// Skip if leads outside ship areas
					var/area/adj_area = get_area(adj)
					if(adj_area && !(adj_area in target_ship.shuttle.shuttle_areas))
						leads_to_space = TRUE
						break
			if(leads_to_space)
				continue
			all_doors += D

	PATROL_LOG("Found [length(all_doors)] interior doors on ship")

	if(!length(all_doors))
		PATROL_LOG("FAILED: No doors found on ship")
		return null

	// Build door adjacency - which doors can reach which other doors
	// Two doors are adjacent if you can walk between them without going through another door
	var/list/door_neighbors = list() // door ref -> list of neighboring door refs

	for(var/obj/machinery/door/door in all_doors)
		door_neighbors[REF(door)] = list()

	// For each door, flood fill to find reachable doors (without crossing other doors)
	for(var/obj/machinery/door/start_door in all_doors)
		var/turf/start_turf = get_turf(start_door)
		if(!start_turf)
			continue

		var/list/visited = list()
		var/list/queue = list()
		visited[start_turf] = TRUE

		// Start from both sides of the door
		for(var/dir in GLOB.cardinals)
			var/turf/adj = get_step(start_turf, dir)
			if(adj && !adj.density)
				queue += adj
				visited[adj] = TRUE

		// BFS to find reachable doors
		while(length(queue))
			var/turf/current = queue[1]
			queue.Cut(1, 2)

			// Check if this turf has a door (that isn't our start door)
			for(var/obj/machinery/door/found_door in current)
				if(found_door != start_door && (found_door in all_doors))
					// Found a neighboring door
					door_neighbors[REF(start_door)] |= REF(found_door)
					continue // Don't flood past this door

			// Check if current turf IS a door turf (block further expansion)
			var/has_other_door = FALSE
			for(var/obj/machinery/door/D in current)
				if(D != start_door && (D in all_doors))
					has_other_door = TRUE
					break
			if(has_other_door)
				continue

			// Expand to neighbors
			for(var/dir in GLOB.cardinals)
				var/turf/neighbor = get_step(current, dir)
				if(!neighbor || visited[neighbor])
					continue
				if(neighbor.density)
					continue
				// Check for walls/solid objects (but allow doors)
				var/blocked = FALSE
				for(var/obj/O in neighbor)
					if(O.density && !istype(O, /obj/machinery/door))
						blocked = TRUE
						break
				if(blocked)
					continue
				visited[neighbor] = TRUE
				queue += neighbor

	// Generate patrol path using BFS traversal through connected doors
	// This ensures every step in the path is through a valid door connection (no walls)
	var/list/path = list()
	var/list/unvisited = all_doors.Copy()

	// Start from a random door
	var/obj/machinery/door/current_door = pick(unvisited)
	path += current_door
	unvisited -= current_door

	// BFS through the door graph - only follow valid connections
	while(length(unvisited))
		var/list/neighbors = door_neighbors[REF(current_door)]
		var/obj/machinery/door/next_door = null
		var/best_dist = INFINITY

		// Find the closest unvisited neighbor (directly connected door)
		for(var/neighbor_ref in neighbors)
			var/obj/machinery/door/neighbor = locate(neighbor_ref)
			if(neighbor && (neighbor in unvisited))
				var/dist = get_dist(current_door, neighbor)
				if(dist < best_dist)
					best_dist = dist
					next_door = neighbor

		// If no unvisited neighbors, BFS through door graph to find nearest unvisited
		if(!next_door)
			var/list/bfs_queue = list(REF(current_door))
			var/list/bfs_visited = list(REF(current_door) = TRUE)
			var/list/bfs_parent = list() // To reconstruct path

			while(length(bfs_queue) && !next_door)
				var/check_ref = bfs_queue[1]
				bfs_queue.Cut(1, 2)

				var/list/check_neighbors = door_neighbors[check_ref]
				for(var/n_ref in check_neighbors)
					if(bfs_visited[n_ref])
						continue
					bfs_visited[n_ref] = TRUE
					bfs_parent[n_ref] = check_ref

					var/obj/machinery/door/n_door = locate(n_ref)
					if(n_door && (n_door in unvisited))
						// Found an unvisited door - trace back to find first step
						var/trace_ref = n_ref
						while(bfs_parent[trace_ref] && bfs_parent[trace_ref] != REF(current_door))
							trace_ref = bfs_parent[trace_ref]
						next_door = locate(trace_ref)
						break
					bfs_queue += n_ref

		if(!next_door)
			break // No more reachable doors through valid connections

		path += next_door
		unvisited -= next_door
		current_door = next_door

	PATROL_LOG("Generated door patrol path with [length(path)] doors (valid connections only)")

	if(length(path) < 2)
		PATROL_LOG("FAILED: Path too short ([length(path)] doors)")
		return null

	// Also build a list of doors that require access (pirates have none, so these need attacking)
	var/list/locked_doors = list()
	for(var/obj/machinery/door/D in path)
		if(door_requires_access(D))
			locked_doors[REF(D)] = TRUE

	// Cache the locked doors list
	var/ship_ref = REF(target_ship)
	GLOB.boarding_locked_doors[ship_ref] = locked_doors
	PATROL_LOG("Identified [length(locked_doors)] doors requiring access (will attack directly)")

	return path

/**
 * Check if a door requires access to open.
 * Pirates have no access, so any door with req_access or req_one_access will need to be attacked.
 */
/proc/door_requires_access(obj/machinery/door/D)
	if(!D)
		return FALSE

	// Check for airlock-specific access requirements
	if(istype(D, /obj/machinery/door/airlock))
		var/obj/machinery/door/airlock/A = D
		if(LAZYLEN(A.req_access) || LAZYLEN(A.req_one_access))
			return TRUE

	// Check for windoor access requirements
	if(istype(D, /obj/machinery/door/window))
		var/obj/machinery/door/window/W = D
		if(LAZYLEN(W.req_access) || LAZYLEN(W.req_one_access))
			return TRUE

	return FALSE

/**
 * Check if we can reach a door from the current position without passing through any closed doors.
 * Used to skip patrol doors that are already accessible (in the same "room").
 *
 * @param start_turf The turf to start from (usually mob's position)
 * @param target_door The door we want to reach
 * @param max_dist Maximum distance to flood fill (optimization)
 * @return TRUE if we can reach the door without passing through closed doors
 */
/proc/can_reach_door_directly(turf/start_turf, obj/machinery/door/target_door, max_dist = 20)
	if(!start_turf || !target_door)
		return FALSE

	var/turf/target_turf = get_turf(target_door)
	if(!target_turf)
		return FALSE

	// Quick distance check - if too far, don't bother
	if(get_dist(start_turf, target_turf) > max_dist)
		return FALSE

	// BFS flood fill from start, stopping at closed doors
	var/list/visited = list()
	var/list/queue = list(start_turf)
	visited[start_turf] = TRUE

	while(length(queue))
		var/turf/current = queue[1]
		queue.Cut(1, 2)

		// Check if we reached the target door's turf
		if(current == target_turf)
			return TRUE

		// Check if we're adjacent to the target door
		if(get_dist(current, target_turf) <= 1)
			return TRUE

		// Expand to cardinal neighbors
		for(var/dir in GLOB.cardinals)
			var/turf/neighbor = get_step(current, dir)
			if(!neighbor || visited[neighbor])
				continue

			// Skip dense turfs (walls)
			if(neighbor.density)
				continue

			// Check for closed doors - they block the path
			var/blocked_by_door = FALSE
			for(var/obj/machinery/door/door in neighbor)
				if(door == target_door)
					continue  // Target door doesn't block us
				if(door.density)
					blocked_by_door = TRUE
					break

			if(blocked_by_door)
				continue

			// Check for other dense objects (but not doors)
			var/blocked = FALSE
			for(var/obj/O in neighbor)
				if(O.density && !istype(O, /obj/machinery/door))
					blocked = TRUE
					break
			if(blocked)
				continue

			// Distance limit for optimization
			if(get_dist(start_turf, neighbor) > max_dist)
				continue

			visited[neighbor] = TRUE
			queue += neighbor

	return FALSE

/**
 * Get or generate the cached patrol path for a ship.
 * Paths are cached in GLOB.boarding_patrol_paths keyed by ship ref.
 */
/proc/get_ship_patrol_path(obj/structure/overmap/ship/target_ship)
	PATROL_LOG("get_ship_patrol_path called for [target_ship]")

	if(!target_ship)
		PATROL_LOG("FAILED: target_ship is null")
		return null

	var/ship_ref = REF(target_ship)

	// Return cached path if it exists
	if(GLOB.boarding_patrol_paths[ship_ref])
		PATROL_LOG("Returning cached path with [length(GLOB.boarding_patrol_paths[ship_ref])] doors")
		return GLOB.boarding_patrol_paths[ship_ref]

	// Generate and cache new path
	PATROL_LOG("No cached path, generating new one...")
	var/list/path = generate_ship_patrol_path(target_ship)
	if(path)
		GLOB.boarding_patrol_paths[ship_ref] = path
		PATROL_LOG("Cached new path with [length(path)] doors")
	else
		PATROL_LOG("Path generation returned null")

	return path

/**
 * Clear the cached patrol path for a ship (call when ship is destroyed or structure changes significantly)
 */
/proc/clear_ship_patrol_path(obj/structure/overmap/ship/target_ship)
	if(!target_ship)
		return
	var/ship_ref = REF(target_ship)
	GLOB.boarding_patrol_paths -= ship_ref
	GLOB.boarding_locked_doors -= ship_ref
	// Also reset the stagger counter for this ship
	GLOB.patrol_stagger_counter -= ship_ref

/**
 * Find a closed door between the mob and target that might be blocking the path.
 * Searches in the direction of the target, checking for doors within range.
 *
 * @param mob_source The mob trying to move
 * @param target The target we're trying to reach
 * @return The nearest blocking door, or null if none found
 */
/proc/find_blocking_door_toward_target(mob/living/mob_source, atom/target)
	if(!mob_source || !target)
		return null

	var/turf/start_turf = get_turf(mob_source)
	var/turf/target_turf = get_turf(target)
	if(!start_turf || !target_turf)
		return null

	// Get direction toward target
	var/dir_to_target = get_dir(start_turf, target_turf)
	if(!dir_to_target)
		return null

	// Search in that direction for closed doors (up to 5 tiles)
	var/obj/machinery/door/nearest_door = null
	var/nearest_dist = INFINITY

	// Check turfs in a cone toward the target
	for(var/check_dist in 1 to 5)
		// Check primary direction and adjacent directions
		var/list/dirs_to_check = list(dir_to_target)
		// Add diagonal/adjacent checks for better coverage
		if(dir_to_target & NORTH)
			dirs_to_check |= NORTH
		if(dir_to_target & SOUTH)
			dirs_to_check |= SOUTH
		if(dir_to_target & EAST)
			dirs_to_check |= EAST
		if(dir_to_target & WEST)
			dirs_to_check |= WEST

		for(var/check_dir in dirs_to_check)
			var/turf/check_turf = get_step(start_turf, check_dir)
			for(var/i in 1 to check_dist - 1)
				if(!check_turf)
					break
				check_turf = get_step(check_turf, check_dir)

			if(!check_turf)
				continue

			// Look for closed doors on this turf
			for(var/obj/machinery/door/door in check_turf)
				if(!door.density)
					continue  // Door is open
				if(istype(door, /obj/machinery/door/poddoor))
					continue  // Skip blast doors
				if(istype(door, /obj/machinery/door/airlock/external))
					continue  // Skip external airlocks
				if(findtext(door.name, "external"))
					continue  // Skip doors with "external" in name

				var/dist = get_dist(mob_source, door)
				if(dist < nearest_dist)
					nearest_dist = dist
					nearest_door = door

	return nearest_door

/**
 * Debug visualization - draws the door patrol path on the ship with colored markers.
 * Green at start, transitions to red at end. Numbers show visit order.
 * Markers persist until manually cleared with clear_patrol_visualization().
 *
 * @param target_ship The ship to visualize patrol path for
 */
/proc/visualize_patrol_path(obj/structure/overmap/ship/target_ship)
	var/list/path = get_ship_patrol_path(target_ship)
	if(!path || !length(path))
		to_chat(world, span_warning("No patrol path for [target_ship]"))
		return

	// Clear any existing markers for this ship first
	var/ship_ref = REF(target_ship)
	clear_patrol_visualization(ship_ref)

	var/path_length = length(path)
	var/list/markers = list()

	for(var/i in 1 to path_length)
		var/obj/machinery/door/D = path[i]
		if(QDELETED(D))
			continue

		var/turf/T = get_turf(D)
		if(!T)
			continue

		// Create a visual marker at the door
		var/obj/effect/patrol_marker/marker = new(T)
		markers += marker

		// Color gradient: green (start) -> yellow (middle) -> red (end)
		var/progress = (i - 1) / max(path_length - 1, 1)
		var/r = min(255, round(510 * progress))
		var/g = min(255, round(510 * (1 - progress)))
		marker.color = rgb(r, g, 0)

		// Show door name and index
		marker.maptext = MAPTEXT("[i]")
		marker.name = "patrol door #[i]: [D.name]"

	// Store markers for later cleanup
	if(!GLOB.patrol_path_markers)
		GLOB.patrol_path_markers = list()
	GLOB.patrol_path_markers[ship_ref] = markers

	to_chat(world, span_notice("Visualizing door patrol path for [target_ship]: [path_length] doors (green=start, red=end). Use clear_patrol_visualization() to remove."))

/**
 * Clear patrol visualization markers for a specific ship or all ships.
 * @param ship_ref Optional - REF() of a specific ship. If null, clears all markers.
 */
/proc/clear_patrol_visualization(ship_ref)
	if(!GLOB.patrol_path_markers)
		return

	if(ship_ref)
		// Clear markers for specific ship
		var/list/markers = GLOB.patrol_path_markers[ship_ref]
		if(markers)
			for(var/obj/effect/patrol_marker/marker in markers)
				qdel(marker)
			GLOB.patrol_path_markers -= ship_ref
	else
		// Clear all markers
		for(var/ref in GLOB.patrol_path_markers)
			var/list/markers = GLOB.patrol_path_markers[ref]
			for(var/obj/effect/patrol_marker/marker in markers)
				qdel(marker)
		GLOB.patrol_path_markers.Cut()

/**
 * Visual marker for patrol path debugging
 */
/obj/effect/patrol_marker
	name = "patrol waypoint"
	icon = 'icons/effects/effects.dmi'
	icon_state = "yourturftarget"  // Green target reticle
	layer = ABOVE_MOB_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	alpha = 180

/// Admin verb to visualize patrol path for the ship you're standing on
/client/proc/visualize_ship_patrol()
	set name = "Visualize Patrol Path"
	set category = "Debug"

	if(!check_rights(R_DEBUG))
		return

	var/mob/M = mob
	var/turf/T = get_turf(M)
	if(!T)
		to_chat(M, span_warning("You're not on a turf!"))
		return

	// Find what ship we're on by checking the area
	var/area/A = get_area(T)
	if(!A)
		to_chat(M, span_warning("No area found!"))
		return

	// Look for a ship that has this area in its shuttle_areas
	for(var/obj/structure/overmap/ship/S in SSovermap.simulated_ships)
		if(!S.shuttle?.shuttle_areas)
			continue
		if(A in S.shuttle.shuttle_areas)
			visualize_patrol_path(S)
			return

	to_chat(M, span_warning("Couldn't find a ship for this location. Try standing on a ship."))

/// Admin verb to clear patrol path visualization for the ship you're standing on, or all ships
/client/proc/clear_ship_patrol_visualization()
	set name = "Clear Patrol Visualization"
	set category = "Debug"

	if(!check_rights(R_DEBUG))
		return

	var/mob/M = mob
	var/choice = tgui_alert(M, "Clear patrol visualization for which ships?", "Clear Patrol Viz", list("This Ship", "All Ships", "Cancel"))

	if(choice == "Cancel" || !choice)
		return

	if(choice == "All Ships")
		clear_patrol_visualization()
		to_chat(M, span_notice("Cleared all patrol visualizations."))
		return

	// Find what ship we're on
	var/turf/T = get_turf(M)
	if(!T)
		to_chat(M, span_warning("You're not on a turf!"))
		return

	var/area/A = get_area(T)
	if(!A)
		to_chat(M, span_warning("No area found!"))
		return

	for(var/obj/structure/overmap/ship/S in SSovermap.simulated_ships)
		if(!S.shuttle?.shuttle_areas)
			continue
		if(A in S.shuttle.shuttle_areas)
			clear_patrol_visualization(REF(S))
			to_chat(M, span_notice("Cleared patrol visualization for [S]."))
			return

	to_chat(M, span_warning("Couldn't find a ship for this location."))

/**
 * Assign a mob to patrol a ship's cached path.
 * Starts the mob at the nearest door to their current position.
 *
 * @param mob_to_assign The mob to assign patrol behavior to
 * @param target_ship The ship to patrol
 * @param spawn_index Unused (kept for compatibility)
 * @param total_spawns Unused (kept for compatibility)
 */
/proc/assign_mob_to_patrol(mob/living/mob_to_assign, obj/structure/overmap/ship/target_ship, spawn_index = 0, total_spawns = 1)
	PATROL_LOG("assign_mob_to_patrol called: mob=[mob_to_assign], ship=[target_ship]")

	if(!mob_to_assign || !target_ship)
		PATROL_LOG("FAILED: mob_to_assign=[mob_to_assign], target_ship=[target_ship]")
		return FALSE

	var/list/path = get_ship_patrol_path(target_ship)
	if(!path || !length(path))
		PATROL_LOG("FAILED: No path returned from get_ship_patrol_path")
		return FALSE

	var/datum/ai_controller/controller = mob_to_assign.ai_controller
	if(!controller)
		PATROL_LOG("FAILED: Mob has no ai_controller")
		return FALSE

	PATROL_LOG("Mob AI controller type: [controller.type]")

	// Assign patrol path reference (direct assignment for lists)
	controller.blackboard[BB_MOB_PATROL_PATH] = path

	// Find the nearest door to the mob's current position
	var/start_index = 1
	var/best_dist = INFINITY
	var/turf/mob_turf = get_turf(mob_to_assign)
	if(mob_turf)
		for(var/i in 1 to length(path))
			var/obj/machinery/door/D = path[i]
			if(QDELETED(D))
				continue
			var/dist = get_dist(mob_turf, D)
			if(dist < best_dist)
				best_dist = dist
				start_index = i

	// Stagger start indices to prevent mobs from blocking each other
	// Each mob gets an offset of 2-3 doors so they spread out across the path
	var/ship_ref = REF(target_ship)
	if(!GLOB.patrol_stagger_counter[ship_ref])
		GLOB.patrol_stagger_counter[ship_ref] = 0
	var/stagger_offset = GLOB.patrol_stagger_counter[ship_ref] * 3  // Offset by 3 doors per mob
	GLOB.patrol_stagger_counter[ship_ref]++

	// Apply stagger (wrap around path length)
	start_index = ((start_index - 1 + stagger_offset) % length(path)) + 1

	controller.blackboard[BB_MOB_PATROL_INDEX] = start_index

	// Pre-populate the failed doors list with doors that require access
	// Pirates have no access, so these doors will never bumpopen - skip straight to attacking
	var/list/locked_doors = GLOB.boarding_locked_doors[ship_ref]
	if(length(locked_doors))
		controller.blackboard["_failed_blocking_doors"] = locked_doors.Copy()
		PATROL_LOG("Pre-marked [length(locked_doors)] doors as needing attack (no access)")

	PATROL_LOG("SUCCESS: Assigned [mob_to_assign] to patrol, start_index=[start_index] (staggered), path_length=[length(path)]")

	// Auto-visualize path in debug mode (only once per ship)
	#if PATROL_DEBUG
	if(!GLOB.patrol_paths_visualized)
		GLOB.patrol_paths_visualized = list()
	if(!GLOB.patrol_paths_visualized[ship_ref])
		GLOB.patrol_paths_visualized[ship_ref] = TRUE
		visualize_patrol_path(target_ship)
	#endif

	return TRUE

/**
 * Planning subtree for door-to-door patrol behavior.
 * Navigates from door to door, opening/attacking them as needed.
 */
/datum/ai_planning_subtree/patrol_path

/datum/ai_planning_subtree/patrol_path/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/pawn = controller.pawn
	if(!pawn)
		return

	// Get patrol data from blackboard - path is a list of doors
	var/list/patrol_path = controller.blackboard[BB_MOB_PATROL_PATH]
	if(!length(patrol_path))
		if(!controller.blackboard["_patrol_no_path_logged"])
			controller.blackboard["_patrol_no_path_logged"] = TRUE
			PATROL_LOG("[pawn] has no patrol path in blackboard - subtree will not run")
		return

	var/patrol_index = controller.blackboard[BB_MOB_PATROL_INDEX] || 1

	// Clamp index to valid range
	if(patrol_index < 1 || patrol_index > length(patrol_path))
		patrol_index = 1
		controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index

	// Get current target door
	var/obj/machinery/door/target_door = patrol_path[patrol_index]

	// If door is destroyed or doesn't exist, advance to next
	if(QDELETED(target_door))
		var/old_index = patrol_index
		patrol_index = (patrol_index % length(patrol_path)) + 1
		controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index
		controller.clear_blackboard_key("_patrol_door_start_time")
		controller.clear_blackboard_key("_patrol_last_position")
		controller.clear_blackboard_key("_patrol_last_position_time")
		controller.clear_blackboard_key("_patrol_best_dist")
		controller.clear_blackboard_key("_patrol_best_dist_time")
		controller.clear_blackboard_key("_blocking_door_attack_times")
		controller.clear_blackboard_key("_skipped_blocking_doors")
		PATROL_LOG("[pawn] door [old_index] destroyed, advancing to [patrol_index]")
		return // Let next planning cycle handle the new target

	// If door is open (not blocking), we've "passed" it - advance to next
	if(!target_door.density)
		// Only advance if we're actually near/past the door
		if(get_dist(pawn, target_door) <= 2)
			var/old_index = patrol_index
			patrol_index = (patrol_index % length(patrol_path)) + 1
			controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index
			controller.clear_blackboard_key("_patrol_door_start_time")
			controller.clear_blackboard_key("_patrol_last_position")
			controller.clear_blackboard_key("_patrol_last_position_time")
			controller.clear_blackboard_key("_patrol_best_dist")
			controller.clear_blackboard_key("_patrol_best_dist_time")
			controller.clear_blackboard_key("_blocking_door_attack_times")
			controller.clear_blackboard_key("_skipped_blocking_doors")
			target_door = patrol_path[patrol_index]
			PATROL_LOG("[pawn] passed door [old_index] (now open), advancing to [patrol_index]")

			// Skip doors we can already reach directly (same room optimization)
			// Keep advancing while the next door is directly reachable
			var/turf/advance_pawn_turf = get_turf(pawn)
			var/skipped_count = 0
			while(!QDELETED(target_door) && skipped_count < length(patrol_path))
				// If door is closed and we can't reach it directly, stop here - this is our target
				if(target_door.density && !can_reach_door_directly(advance_pawn_turf, target_door))
					break
				// If door is open or directly reachable, skip to next
				var/skip_reason = ""
				if(!target_door.density)
					skip_reason = "open"
				else if(can_reach_door_directly(advance_pawn_turf, target_door))
					skip_reason = "directly reachable"
				else
					break  // Can't skip this one

				var/skipped_index = patrol_index
				patrol_index = (patrol_index % length(patrol_path)) + 1
				controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index
				target_door = patrol_path[patrol_index]
				skipped_count++
				PATROL_LOG("[pawn] skipping door [skipped_index] ([skip_reason]), advancing to [patrol_index]")

			// Check if new target is also destroyed
			if(QDELETED(target_door))
				return // Let next planning cycle handle

	// Stuck detection - multiple conditions
	var/door_start_time = controller.blackboard["_patrol_door_start_time"]
	var/last_pos = controller.blackboard["_patrol_last_position"]
	var/last_pos_time = controller.blackboard["_patrol_last_position_time"]
	var/best_dist_to_target = controller.blackboard["_patrol_best_dist"]
	var/best_dist_time = controller.blackboard["_patrol_best_dist_time"]
	var/turf/pawn_turf = get_turf(pawn)
	var/current_dist = get_dist(pawn, target_door)

	if(!door_start_time)
		controller.blackboard["_patrol_door_start_time"] = world.time
		controller.blackboard["_patrol_last_position"] = pawn_turf
		controller.blackboard["_patrol_last_position_time"] = world.time
		controller.blackboard["_patrol_best_dist"] = current_dist
		controller.blackboard["_patrol_best_dist_time"] = world.time
	else
		// Track best distance to target (for progress detection)
		if(isnull(best_dist_to_target) || current_dist < best_dist_to_target)
			controller.blackboard["_patrol_best_dist"] = current_dist
			controller.blackboard["_patrol_best_dist_time"] = world.time
		else if(best_dist_time && world.time > best_dist_time + 8 SECONDS)
			// No progress toward target in 8 seconds - we're stuck
			// First, look for any closed doors nearby that might be blocking our path
			var/obj/machinery/door/blocking_door = find_blocking_door_toward_target(pawn, target_door)
			if(blocking_door)
				// Found a door blocking our path - make it our temporary patrol target
				// The normal patrol_to_door behavior will walk us to it, then handle_blocking_door
				// will open/attack it once we're adjacent
				controller.clear_blackboard_key("_patrol_best_dist")
				controller.clear_blackboard_key("_patrol_best_dist_time")
				controller.blackboard[BB_MOB_PATROL_TARGET] = blocking_door
				controller.queue_behavior(/datum/ai_behavior/patrol_to_door, BB_MOB_PATROL_TARGET)
				PATROL_LOG("[pawn] STUCK - found blocking door [blocking_door.name] toward target, moving to it")
				return SUBTREE_RETURN_FINISH_PLANNING

			// No blocking door found - skip to next patrol target
			var/old_index = patrol_index
			patrol_index = (patrol_index % length(patrol_path)) + 1
			controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index
			controller.clear_blackboard_key("_patrol_door_start_time")
			controller.clear_blackboard_key("_patrol_last_position")
			controller.clear_blackboard_key("_patrol_last_position_time")
			controller.clear_blackboard_key("_patrol_best_dist")
			controller.clear_blackboard_key("_patrol_best_dist_time")
			controller.clear_blackboard_key("_last_failed_door")
			controller.clear_blackboard_key("_blocking_door_attack_times")
			controller.clear_blackboard_key("_skipped_blocking_doors")
			PATROL_LOG("[pawn] STUCK - no progress toward target for 8s (dist=[current_dist], best=[best_dist_to_target]), skipping door [old_index] to [patrol_index]")
			return // Let next planning cycle handle the new target

		// Check if we've moved since last check
		if(pawn_turf != last_pos)
			// We moved - update position tracking
			controller.blackboard["_patrol_last_position"] = pawn_turf
			controller.blackboard["_patrol_last_position_time"] = world.time
		else if(last_pos_time && world.time > last_pos_time + 10 SECONDS)
			// Haven't moved in 10 seconds - we're stuck
			var/old_index = patrol_index
			patrol_index = (patrol_index % length(patrol_path)) + 1
			controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index
			controller.clear_blackboard_key("_patrol_door_start_time")
			controller.clear_blackboard_key("_patrol_last_position")
			controller.clear_blackboard_key("_patrol_last_position_time")
			controller.clear_blackboard_key("_patrol_best_dist")
			controller.clear_blackboard_key("_patrol_best_dist_time")
			controller.clear_blackboard_key("_last_failed_door")
			controller.clear_blackboard_key("_blocking_door_attack_times")
			controller.clear_blackboard_key("_skipped_blocking_doors")
			PATROL_LOG("[pawn] STUCK - no movement for 10s at ([pawn_turf.x],[pawn_turf.y]), skipping door [old_index] to [patrol_index]")
			return // Let next planning cycle handle the new target

		// Distance-based stuck detection - if far from door for 15 seconds
		if(world.time > door_start_time + 15 SECONDS)
			if(current_dist > 2)  // Still not close enough to interact
				var/old_index = patrol_index
				patrol_index = (patrol_index % length(patrol_path)) + 1
				controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index
				controller.clear_blackboard_key("_patrol_door_start_time")
				controller.clear_blackboard_key("_patrol_last_position")
				controller.clear_blackboard_key("_patrol_last_position_time")
				controller.clear_blackboard_key("_patrol_best_dist")
				controller.clear_blackboard_key("_patrol_best_dist_time")
				controller.clear_blackboard_key("_last_failed_door")
				controller.clear_blackboard_key("_blocking_door_attack_times")
				controller.clear_blackboard_key("_skipped_blocking_doors")
				PATROL_LOG("[pawn] STUCK trying to reach door [old_index] ([target_door.name]) for 15s (dist=[current_dist]), skipping to [patrol_index]")
				return // Let next planning cycle handle the new target

	// Log first patrol start
	if(!controller.blackboard["_patrol_started_logged"])
		controller.blackboard["_patrol_started_logged"] = TRUE
		PATROL_LOG("[pawn] STARTING DOOR PATROL - first target: [target_door.name] at ([target_door.x],[target_door.y]), dist=[get_dist(pawn, target_door)]")

	// Before setting the target, check if we can already reach this door directly
	// This handles the case where we spawn in a room with multiple doors - skip to one we can't already reach
	// pawn_turf is already defined above in stuck detection
	var/start_skipped_count = 0
	while(!QDELETED(target_door) && start_skipped_count < length(patrol_path))
		// If door is closed and we can't reach it directly, this is a good target
		if(target_door.density && !can_reach_door_directly(pawn_turf, target_door))
			break
		// Door is open or directly reachable - skip it
		var/start_skip_reason = ""
		if(!target_door.density)
			start_skip_reason = "open"
		else if(can_reach_door_directly(pawn_turf, target_door))
			start_skip_reason = "already reachable"
		else
			break

		var/start_skipped_index = patrol_index
		patrol_index = (patrol_index % length(patrol_path)) + 1
		controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index
		target_door = patrol_path[patrol_index]
		start_skipped_count++
		PATROL_LOG("[pawn] skipping door [start_skipped_index] ([start_skip_reason]) at start, advancing to [patrol_index]")

	if(QDELETED(target_door))
		return  // Let next planning cycle handle

	// Set the door as our patrol target (behaviors will target the door's turf for movement)
	controller.blackboard[BB_MOB_PATROL_TARGET] = target_door
	controller.queue_behavior(/datum/ai_behavior/patrol_to_door, BB_MOB_PATROL_TARGET)

/**
 * Behavior that moves toward a target door.
 * When adjacent, the try_open_door subtree will handle opening/attacking.
 */
/datum/ai_behavior/patrol_to_door
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/patrol_to_door/setup(datum/ai_controller/controller, target_key)
	var/obj/machinery/door/target_door = controller.blackboard[target_key]
	if(QDELETED(target_door))
		PATROL_LOG("[controller.pawn] patrol_to_door setup FAILED - door deleted")
		return FALSE

	// Move to the door's turf
	var/turf/door_turf = get_turf(target_door)
	if(!door_turf)
		return FALSE

	controller.set_movement_target(type, door_turf)
	PATROL_LOG("[controller.pawn] patrol_to_door setup OK - moving to [target_door.name] at ([door_turf.x],[door_turf.y])")
	return ..()

/datum/ai_behavior/patrol_to_door/finish_action(datum/ai_controller/controller, succeeded, target_key)
	. = ..()
	controller.clear_blackboard_key(target_key)

	// Re-queue if cancelled but patrol still valid
	var/mob/living/pawn = controller.pawn
	if(!succeeded && !QDELETED(pawn) && length(controller.blackboard[BB_MOB_PATROL_PATH]))
		var/list/patrol_path = controller.blackboard[BB_MOB_PATROL_PATH]
		var/patrol_index = controller.blackboard[BB_MOB_PATROL_INDEX] || 1
		if(patrol_index >= 1 && patrol_index <= length(patrol_path))
			var/obj/machinery/door/next_door = patrol_path[patrol_index]
			if(!QDELETED(next_door))
				controller.blackboard[BB_MOB_PATROL_TARGET] = next_door
				controller.queue_behavior(/datum/ai_behavior/patrol_to_door, BB_MOB_PATROL_TARGET)

/datum/ai_behavior/patrol_to_door/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/obj/machinery/door/target_door = controller.blackboard[target_key]

	// If door opened while we were moving, succeed immediately
	if(QDELETED(target_door) || !target_door.density)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/**
 * Subtree that handles ANY blocking door in our path - not just the patrol target.
 * This ensures mobs don't get stuck behind intermediate doors (like windoors)
 * that aren't their current patrol target.
 */
/datum/ai_planning_subtree/handle_blocking_door

/datum/ai_planning_subtree/handle_blocking_door/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/pawn = controller.pawn
	if(!pawn)
		return

	// Check all adjacent turfs for closed doors blocking our movement
	var/turf/pawn_turf = get_turf(pawn)
	if(!pawn_turf)
		return

	// Get our current patrol target from the path list (not from BB_MOB_PATROL_TARGET which may be cleared)
	// This prevents us from treating our target door as a "blocking" door
	var/obj/machinery/door/patrol_target = null
	var/list/patrol_path = controller.blackboard[BB_MOB_PATROL_PATH]
	var/patrol_index = controller.blackboard[BB_MOB_PATROL_INDEX] || 1
	if(length(patrol_path) && patrol_index >= 1 && patrol_index <= length(patrol_path))
		patrol_target = patrol_path[patrol_index]

	for(var/dir in GLOB.cardinals)
		var/turf/adj = get_step(pawn_turf, dir)
		if(!adj)
			continue

		// Check for any closed door on this adjacent turf
		for(var/obj/machinery/door/blocking_door in adj)
			// Skip if this IS our patrol target (normal handling will deal with it)
			if(blocking_door == patrol_target)
				continue

			// Skip open doors
			if(!blocking_door.density)
				continue

			// Skip blast doors / poddoors - critical ship infrastructure
			if(istype(blocking_door, /obj/machinery/door/poddoor))
				continue

			// Skip external airlocks - don't want mobs going into space
			if(istype(blocking_door, /obj/machinery/door/airlock/external))
				continue
			if(findtext(blocking_door.name, "external"))
				continue

			// Found a blocking door that isn't our target - handle it
			var/door_ref = REF(blocking_door)

			// Check if we've given up on this door (attacked for too long)
			var/list/skipped_doors = controller.blackboard["_skipped_blocking_doors"]
			if(skipped_doors && skipped_doors[door_ref])
				continue  // Skip this door, we gave up on it

			PATROL_LOG("[pawn] found blocking door [blocking_door.name] at ([adj.x],[adj.y]) - not our target, handling it")

			// Check if we already tried and failed to open this door (persistent tracking)
			var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
			if(!failed_doors)
				failed_doors = list()
				controller.blackboard["_failed_blocking_doors"] = failed_doors

			if(failed_doors[door_ref])
				// Check if we've been attacking this door for too long (30 seconds)
				var/list/attack_times = controller.blackboard["_blocking_door_attack_times"]
				if(!attack_times)
					attack_times = list()
					controller.blackboard["_blocking_door_attack_times"] = attack_times

				var/attack_start = attack_times[door_ref]
				if(!attack_start)
					attack_times[door_ref] = world.time
				else if(world.time > attack_start + 30 SECONDS)
					// We've been attacking this door for 30+ seconds - give up
					if(!skipped_doors)
						skipped_doors = list()
						controller.blackboard["_skipped_blocking_doors"] = skipped_doors
					skipped_doors[door_ref] = TRUE
					PATROL_LOG("[pawn] giving up on blocking door [blocking_door.name] after 30s of attacking")
					continue  // Check for other blocking doors

				// Already failed to open this door before - attack it directly
				controller.set_blackboard_key("_blocking_door_to_attack", blocking_door)
				controller.queue_behavior(/datum/ai_behavior/attack_blocking_door, "_blocking_door_to_attack")
				return SUBTREE_RETURN_FINISH_PLANNING

			// Try to open it first
			controller.set_blackboard_key("_blocking_door_to_open", blocking_door)
			controller.queue_behavior(/datum/ai_behavior/try_open_blocking_door, "_blocking_door_to_open")
			return SUBTREE_RETURN_FINISH_PLANNING

	// Also check for door assemblies (left behind when doors are destroyed)
	for(var/dir in GLOB.cardinals)
		var/turf/adj = get_step(pawn_turf, dir)
		if(!adj)
			continue

		for(var/obj/structure/door_assembly/assembly in adj)
			if(!assembly.density)
				continue  // Not blocking

			PATROL_LOG("[pawn] found blocking door assembly [assembly.name] at ([adj.x],[adj.y]) - attacking it")
			controller.set_blackboard_key("_blocking_assembly_to_attack", assembly)
			controller.queue_behavior(/datum/ai_behavior/attack_blocking_assembly, "_blocking_assembly_to_attack")
			return SUBTREE_RETURN_FINISH_PLANNING

/**
 * Behavior that attacks a blocking door assembly (left behind when doors are destroyed)
 */
/datum/ai_behavior/attack_blocking_assembly
	action_cooldown = 1.2 SECONDS
	behavior_flags = NONE

/datum/ai_behavior/attack_blocking_assembly/setup(datum/ai_controller/controller, assembly_key)
	var/obj/structure/door_assembly/assembly = controller.blackboard[assembly_key]
	if(QDELETED(assembly) || !assembly.density)
		return FALSE
	return TRUE

/datum/ai_behavior/attack_blocking_assembly/perform(seconds_per_tick, datum/ai_controller/controller, assembly_key)
	var/obj/structure/door_assembly/assembly = controller.blackboard[assembly_key]
	var/mob/living/basic/pawn = controller.pawn

	if(QDELETED(assembly) || !assembly.density)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Must be adjacent to attack
	if(get_dist(pawn, assembly) > 1)
		PATROL_LOG("[pawn] not adjacent to assembly [assembly.name] (dist=[get_dist(pawn, assembly)]), cannot attack")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	pawn.melee_attack(assembly)
	PATROL_LOG("[pawn] smashing door assembly [assembly.name]")
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/attack_blocking_assembly/finish_action(datum/ai_controller/controller, succeeded, assembly_key)
	. = ..()
	controller.clear_blackboard_key(assembly_key)

/**
 * Behavior that attempts to open a blocking door (not our patrol target)
 */
/datum/ai_behavior/try_open_blocking_door
	action_cooldown = 1 SECONDS
	behavior_flags = NONE

/datum/ai_behavior/try_open_blocking_door/setup(datum/ai_controller/controller, door_key)
	var/obj/machinery/door/door = controller.blackboard[door_key]
	if(QDELETED(door) || !door.density)
		return FALSE
	return TRUE

/datum/ai_behavior/try_open_blocking_door/perform(seconds_per_tick, datum/ai_controller/controller, door_key)
	var/obj/machinery/door/door = controller.blackboard[door_key]
	var/mob/living/pawn = controller.pawn

	if(QDELETED(door) || !door.density)
		// Door opened or destroyed - remove from failed list if present
		var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
		if(failed_doors)
			failed_doors -= REF(door)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Try to open via bumpopen
	door.bumpopen(pawn)

	if(!door.density)
		// Door opened - remove from failed list so we try bumpopen again if it closes
		var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
		if(failed_doors)
			failed_doors -= REF(door)
		// Also clear attack timeout tracking for this door
		var/list/attack_times = controller.blackboard["_blocking_door_attack_times"]
		if(attack_times)
			attack_times -= REF(door)
		var/list/skipped_doors = controller.blackboard["_skipped_blocking_doors"]
		if(skipped_doors)
			skipped_doors -= REF(door)
		PATROL_LOG("[pawn] successfully opened blocking door [door.name]")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Failed to open - add to failed list so we always attack it from now on
	var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
	if(!failed_doors)
		failed_doors = list()
		controller.blackboard["_failed_blocking_doors"] = failed_doors
	failed_doors[REF(door)] = TRUE
	PATROL_LOG("[pawn] failed to open blocking door [door.name] - will attack")
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/try_open_blocking_door/finish_action(datum/ai_controller/controller, succeeded, door_key)
	. = ..()
	controller.clear_blackboard_key(door_key)

/**
 * Behavior that attacks a blocking door (not our patrol target)
 */
/datum/ai_behavior/attack_blocking_door
	action_cooldown = 1.2 SECONDS
	behavior_flags = NONE

/datum/ai_behavior/attack_blocking_door/setup(datum/ai_controller/controller, door_key)
	var/obj/machinery/door/door = controller.blackboard[door_key]
	if(QDELETED(door) || !door.density)
		return FALSE
	return TRUE

/datum/ai_behavior/attack_blocking_door/perform(seconds_per_tick, datum/ai_controller/controller, door_key)
	var/obj/machinery/door/door = controller.blackboard[door_key]
	var/mob/living/basic/pawn = controller.pawn

	if(QDELETED(door) || !door.density)
		// Door opened or destroyed - remove from all tracking lists
		var/door_ref = REF(door)
		var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
		if(failed_doors)
			failed_doors -= door_ref
		var/list/attack_times = controller.blackboard["_blocking_door_attack_times"]
		if(attack_times)
			attack_times -= door_ref
		var/list/skipped_doors = controller.blackboard["_skipped_blocking_doors"]
		if(skipped_doors)
			skipped_doors -= door_ref
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Must be adjacent to attack - if not, fail so we can move closer
	if(get_dist(pawn, door) > 1)
		PATROL_LOG("[pawn] not adjacent to blocking door [door.name] (dist=[get_dist(pawn, door)]), cannot attack")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	// Always use melee attack for door breaking (like blobbernauts/standard troopers)
	// This is more reliable than ranged attacks and saves ammo for combat
	pawn.melee_attack(door)
	PATROL_LOG("[pawn] smashing blocking door [door.name]")
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/attack_blocking_door/finish_action(datum/ai_controller/controller, succeeded, door_key)
	. = ..()
	controller.clear_blackboard_key(door_key)

/**
 * Door-opening subtree for patrol behavior.
 * When adjacent to target door, tries to open it before attacking.
 */
/datum/ai_planning_subtree/try_open_door_in_path
	var/target_key = BB_MOB_PATROL_TARGET

/datum/ai_planning_subtree/try_open_door_in_path/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/obj/machinery/door/target_door = controller.blackboard[target_key]
	if(QDELETED(target_door))
		return

	// Only try to open if door is closed
	if(!target_door.density)
		return

	var/mob/living/pawn = controller.pawn

	// Only interact when adjacent to the door
	if(get_dist(pawn, target_door) > 1)
		return

	// Check if we already tried and failed to open this door (persistent tracking)
	var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
	if(failed_doors && failed_doors[REF(target_door)])
		return  // Let attack subtree handle it - we already know this door won't open

	// Try to open the door
	controller.set_blackboard_key(BB_DOOR_TO_OPEN, target_door)
	controller.queue_behavior(/datum/ai_behavior/try_open_door, BB_DOOR_TO_OPEN)
	return SUBTREE_RETURN_FINISH_PLANNING

/**
 * Behavior that attempts to open a door by bumping it.
 * If the door doesn't open (locked, no access, etc.), it stays closed
 * and attack_obstacle_in_path will handle breaking it down.
 */
/datum/ai_behavior/try_open_door
	action_cooldown = 1 SECONDS
	behavior_flags = NONE  // No movement required, we're adjacent

/datum/ai_behavior/try_open_door/setup(datum/ai_controller/controller, door_key)
	var/obj/machinery/door/door = controller.blackboard[door_key]
	if(QDELETED(door) || !door.density)
		return FALSE  // Door gone or already open
	return TRUE

/datum/ai_behavior/try_open_door/perform(seconds_per_tick, datum/ai_controller/controller, door_key)
	var/obj/machinery/door/door = controller.blackboard[door_key]
	var/mob/living/pawn = controller.pawn

	if(QDELETED(door) || !door.density)
		// Door opened or destroyed - remove from failed list if present
		var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
		if(failed_doors)
			failed_doors -= REF(door)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Try to open the door via bumpopen (handles access checks, power, etc.)
	door.bumpopen(pawn)

	// Check if it opened
	if(!door.density)
		// Door opened - remove from failed list so we try bumpopen again if it closes
		var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
		if(failed_doors)
			failed_doors -= REF(door)
		// Also clear attack timeout tracking for this door
		var/list/attack_times = controller.blackboard["_blocking_door_attack_times"]
		if(attack_times)
			attack_times -= REF(door)
		var/list/skipped_doors = controller.blackboard["_skipped_blocking_doors"]
		if(skipped_doors)
			skipped_doors -= REF(door)
		PATROL_LOG("[pawn] successfully opened door [door]")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Door didn't open - it's probably locked or we don't have access
	// Add to failed list so we always attack it from now on
	var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
	if(!failed_doors)
		failed_doors = list()
		controller.blackboard["_failed_blocking_doors"] = failed_doors
	failed_doors[REF(door)] = TRUE
	PATROL_LOG("[pawn] failed to open door [door] - will attack it")
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/try_open_door/finish_action(datum/ai_controller/controller, succeeded, door_key)
	. = ..()
	controller.clear_blackboard_key(door_key)

/**
 * Attack door subtree for patrol behavior.
 * When adjacent to a locked door (that failed to open), attack it.
 */
/datum/ai_planning_subtree/attack_patrol_door
	var/target_key = BB_MOB_PATROL_TARGET

/datum/ai_planning_subtree/attack_patrol_door/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/obj/machinery/door/target_door = controller.blackboard[target_key]
	if(QDELETED(target_door))
		return

	// Only attack if door is closed (locked)
	if(!target_door.density)
		return

	var/mob/living/pawn = controller.pawn

	// Only attack when adjacent
	if(get_dist(pawn, target_door) > 1)
		return

	// Only attack if we know this door won't open (from failed list)
	var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
	if(!failed_doors || !failed_doors[REF(target_door)])
		return  // Haven't tried to open it yet

	// Attack the door
	PATROL_LOG("[pawn] ATTACKING locked door [target_door.name]")
	controller.set_blackboard_key(BB_DOOR_TO_OPEN, target_door)
	controller.queue_behavior(/datum/ai_behavior/attack_door, BB_DOOR_TO_OPEN)
	return SUBTREE_RETURN_FINISH_PLANNING

/**
 * Behavior that attacks a door - uses ranged attack if available, otherwise melee
 */
/datum/ai_behavior/attack_door
	action_cooldown = 1.2 SECONDS
	behavior_flags = NONE

/datum/ai_behavior/attack_door/setup(datum/ai_controller/controller, door_key)
	var/obj/machinery/door/door = controller.blackboard[door_key]
	if(QDELETED(door) || !door.density)
		return FALSE
	return TRUE

/datum/ai_behavior/attack_door/perform(seconds_per_tick, datum/ai_controller/controller, door_key)
	var/obj/machinery/door/door = controller.blackboard[door_key]
	var/mob/living/basic/pawn = controller.pawn

	if(QDELETED(door) || !door.density)
		// Door opened/destroyed - remove from all tracking lists
		var/door_ref = REF(door)
		var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
		if(failed_doors)
			failed_doors -= door_ref
		var/list/attack_times = controller.blackboard["_blocking_door_attack_times"]
		if(attack_times)
			attack_times -= door_ref
		var/list/skipped_doors = controller.blackboard["_skipped_blocking_doors"]
		if(skipped_doors)
			skipped_doors -= door_ref
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Must be adjacent to attack - if not, fail so we can move closer
	if(get_dist(pawn, door) > 1)
		PATROL_LOG("[pawn] not adjacent to door [door.name] (dist=[get_dist(pawn, door)]), cannot attack")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	// Always use melee attack for door breaking (like blobbernauts/standard troopers)
	// This is more reliable than ranged attacks and saves ammo for combat
	pawn.melee_attack(door)
	PATROL_LOG("[pawn] smashing door [door.name]")
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/attack_door/finish_action(datum/ai_controller/controller, succeeded, door_key)
	. = ..()
	controller.clear_blackboard_key(door_key)

/**
 * Trooper AI controller variant that patrols door-to-door when not in combat.
 * Used for boarding parties that search ships systematically via doors.
 */
/datum/ai_controller/basic_controller/trooper/patrolling
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,      // Fight enemies when found
		/datum/ai_planning_subtree/handle_blocking_door,             // Handle any door blocking our path (not just target)
		/datum/ai_planning_subtree/patrol_path,                      // Navigate to next door
		/datum/ai_planning_subtree/try_open_door_in_path,           // Try to open target door first
		/datum/ai_planning_subtree/attack_patrol_door,              // Attack locked target doors
	)

/datum/ai_controller/basic_controller/trooper/ranged/patrolling
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_ranged_attack_subtree/trooper,  // Fight enemies when found
		/datum/ai_planning_subtree/handle_blocking_door,                 // Handle any door blocking our path (not just target)
		/datum/ai_planning_subtree/patrol_path,                          // Navigate to next door
		/datum/ai_planning_subtree/try_open_door_in_path,               // Try to open target door first
		/datum/ai_planning_subtree/attack_patrol_door,                  // Attack locked target doors
	)

/// Patrolling version for melee boss mobs
/datum/ai_controller/basic_controller/trooper/patrolling/boss
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,      // Fight enemies when found
		/datum/ai_planning_subtree/handle_blocking_door,             // Handle any door blocking our path (not just target)
		/datum/ai_planning_subtree/patrol_path,                      // Navigate to next door
		/datum/ai_planning_subtree/try_open_door_in_path,           // Try to open target door first
		/datum/ai_planning_subtree/attack_patrol_door,              // Attack locked target doors
	)

/// Patrolling version for ranged boss mobs
/datum/ai_controller/basic_controller/trooper/ranged/patrolling/boss
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_ranged_attack_subtree/trooper,  // Fight enemies when found
		/datum/ai_planning_subtree/handle_blocking_door,                 // Handle any door blocking our path (not just target)
		/datum/ai_planning_subtree/patrol_path,                          // Navigate to next door
		/datum/ai_planning_subtree/try_open_door_in_path,               // Try to open target door first
		/datum/ai_planning_subtree/attack_patrol_door,                  // Attack locked target doors
	)
