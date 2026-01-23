/**
 * Mob Patrol System - JPS-based navigation for boarding parties
 *
 * Mobs navigate from door to door using proper JPS pathfinding.
 * This is much simpler and more reliable than the old door-hopping system.
 */

// Debug logging toggle - set to TRUE to enable patrol debug messages
#define PATROL_DEBUG TRUE

#if PATROL_DEBUG
#define PATROL_LOG(msg) log_shuttle("PATROL: [msg]")
#else
#define PATROL_LOG(msg)
#endif

// How long to wait before considering a path failed (JPS should repath automatically, but this is a fallback)
#define PATROL_JPS_TIMEOUT (8 SECONDS)
// How long to wait at a door before giving up and moving to next
#define PATROL_DOOR_TIMEOUT (20 SECONDS)

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

	// Cache GLOB.cardinals locally for performance (avoid repeated GLOB lookups)
	var/list/cardinal_dirs = GLOB.cardinals

	// For each door, flood fill to find reachable doors (without crossing other doors)
	for(var/obj/machinery/door/start_door in all_doors)
		var/turf/start_turf = get_turf(start_door)
		if(!start_turf)
			continue

		var/list/visited = list()
		var/list/queue = list()
		visited[start_turf] = TRUE

		// Start from both sides of the door
		for(var/dir in cardinal_dirs)
			var/turf/adj = get_step(start_turf, dir)
			if(adj && !adj.density)
				queue += adj
				visited[adj] = TRUE

		// BFS to find reachable doors - use index-based traversal (O(1) vs O(n) for Cut)
		var/queue_idx = 1
		while(queue_idx <= length(queue))
			var/turf/current = queue[queue_idx]
			queue_idx++

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
			for(var/dir in cardinal_dirs)
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
			if(!neighbor)
				continue // Door was deleted
			if(neighbor in unvisited)
				var/dist = get_dist(current_door, neighbor)
				if(dist < best_dist)
					best_dist = dist
					next_door = neighbor

		// If no unvisited neighbors, BFS through door graph to find nearest unvisited
		if(!next_door)
			var/list/bfs_queue = list(REF(current_door))
			var/list/bfs_visited = list(REF(current_door) = TRUE)
			var/list/bfs_parent = list() // To reconstruct path

			// Use index-based traversal (O(1) vs O(n) for Cut)
			var/bfs_idx = 1
			while(bfs_idx <= length(bfs_queue) && !next_door)
				var/check_ref = bfs_queue[bfs_idx]
				bfs_idx++

				var/list/check_neighbors = door_neighbors[check_ref]
				for(var/n_ref in check_neighbors)
					if(bfs_visited[n_ref])
						continue
					bfs_visited[n_ref] = TRUE
					bfs_parent[n_ref] = check_ref

					var/obj/machinery/door/n_door = locate(n_ref)
					if(!n_door)
						continue // Door was deleted
					if(n_door in unvisited)
						// Found an unvisited door - trace back to find first step
						var/trace_ref = n_ref
						while(bfs_parent[trace_ref] != REF(current_door))
							if(!bfs_parent[trace_ref])
								break // Can't trace further
							trace_ref = bfs_parent[trace_ref]
						next_door = locate(trace_ref)
						if(!next_door)
							continue // Traced door was deleted
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
 * Clear patrol tracking keys from a controller's blackboard.
 * Called when advancing to a new door target.
 */
/proc/clear_patrol_tracking_keys(datum/ai_controller/controller)
	controller.clear_blackboard_key("_patrol_door_start_time")
	controller.clear_blackboard_key("_patrol_last_dist")

/**
 * Clear ALL patrol-related state from a controller's blackboard.
 * Call this when reassigning a mob to a new patrol to ensure a clean slate.
 */
/proc/clear_all_patrol_state(datum/ai_controller/controller)
	clear_patrol_tracking_keys(controller)
	controller.clear_blackboard_key(BB_MOB_PATROL_PATH)
	controller.clear_blackboard_key(BB_MOB_PATROL_INDEX)
	controller.clear_blackboard_key(BB_MOB_PATROL_TARGET)
	controller.clear_blackboard_key(BB_MOB_PATROL_SHIP_REF)
	controller.clear_blackboard_key("_failed_blocking_doors")
	controller.clear_blackboard_key("_patrol_started_logged")

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
	GLOB.patrol_stagger_counter -= ship_ref

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

	// Clear all existing patrol state
	clear_all_patrol_state(controller)

	// Assign patrol path reference
	controller.blackboard[BB_MOB_PATROL_PATH] = path
	controller.blackboard[BB_MOB_PATROL_SHIP_REF] = REF(target_ship)

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
	var/ship_ref = REF(target_ship)
	if(!GLOB.patrol_stagger_counter[ship_ref])
		GLOB.patrol_stagger_counter[ship_ref] = 0
	var/current_counter = GLOB.patrol_stagger_counter[ship_ref]++
	var/stagger_offset = current_counter * 3

	start_index = ((start_index - 1 + stagger_offset) % length(path)) + 1
	controller.blackboard[BB_MOB_PATROL_INDEX] = start_index

	// Pre-populate the failed doors list with doors that require access
	var/list/locked_doors = GLOB.boarding_locked_doors[ship_ref]
	if(length(locked_doors))
		controller.blackboard["_failed_blocking_doors"] = locked_doors.Copy()
		PATROL_LOG("Pre-marked [length(locked_doors)] doors as needing attack (no access)")

	PATROL_LOG("SUCCESS: Assigned [mob_to_assign] to patrol, start_index=[start_index], path_length=[length(path)]")

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
 * Planning subtree for door-to-door patrol behavior using JPS pathfinding.
 * Much simpler than the old door-hopping system - just set the movement target
 * and let the JPS movement system handle pathfinding.
 */
/datum/ai_planning_subtree/patrol_path

/datum/ai_planning_subtree/patrol_path/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/pawn = controller.pawn
	if(!pawn)
		return

	// Don't patrol if we have a combat target
	if(controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return

	// Get patrol data
	var/list/patrol_path = controller.blackboard[BB_MOB_PATROL_PATH]
	if(!length(patrol_path))
		return

	var/patrol_index = controller.blackboard[BB_MOB_PATROL_INDEX] || 1

	// Clamp index to valid range
	if(patrol_index < 1 || patrol_index > length(patrol_path))
		patrol_index = 1
		controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index

	// Get current target door
	var/obj/machinery/door/target_door = patrol_path[patrol_index]

	// If door is destroyed, advance to next
	if(QDELETED(target_door))
		patrol_index = (patrol_index % length(patrol_path)) + 1
		controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index
		clear_patrol_tracking_keys(controller)
		PATROL_LOG("[pawn] door destroyed, advancing to [patrol_index]")
		return

	var/current_dist = get_dist(pawn, target_door)

	// Log first patrol start
	if(!controller.blackboard["_patrol_started_logged"])
		controller.blackboard["_patrol_started_logged"] = TRUE
		PATROL_LOG("[pawn] STARTING PATROL - target: [target_door.name], dist=[current_dist]")

	// If door is open and we're near it, advance to next
	if(!target_door.density && current_dist <= 2)
		var/old_index = patrol_index
		patrol_index = (patrol_index % length(patrol_path)) + 1
		controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index
		clear_patrol_tracking_keys(controller)
		PATROL_LOG("[pawn] passed open door [old_index], advancing to [patrol_index]")
		return

	// Simple timeout-based stuck detection
	// If we've been trying to reach this door for too long, skip it
	var/door_start_time = controller.blackboard["_patrol_door_start_time"]
	if(!door_start_time)
		controller.blackboard["_patrol_door_start_time"] = world.time
		controller.blackboard["_patrol_last_dist"] = current_dist
	else
		var/last_dist = controller.blackboard["_patrol_last_dist"]

		// If we're making progress, reset the timer
		if(current_dist < last_dist)
			controller.blackboard["_patrol_door_start_time"] = world.time
			controller.blackboard["_patrol_last_dist"] = current_dist
		// If we've been stuck for too long, skip to next door
		else if(world.time > door_start_time + PATROL_DOOR_TIMEOUT && current_dist > 2)
			var/old_index = patrol_index
			patrol_index = (patrol_index % length(patrol_path)) + 1
			controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index
			clear_patrol_tracking_keys(controller)
			PATROL_LOG("[pawn] TIMEOUT reaching door [old_index] (dist=[current_dist]), advancing to [patrol_index]")
			return

	// Set the door as our patrol target
	controller.blackboard[BB_MOB_PATROL_TARGET] = target_door

	// If adjacent to door, let door interaction subtrees handle it
	if(current_dist <= 1)
		return

	// Queue travel behavior - this triggers the JPS movement system
	// Only queue if we're not already moving to this target
	var/turf/target_turf = get_turf(target_door)
	if(target_turf && controller.current_movement_target != target_turf)
		controller.queue_behavior(/datum/ai_behavior/patrol_travel, BB_MOB_PATROL_TARGET)
		PATROL_LOG("[pawn] queued travel to [target_door.name] (dist=[current_dist])")

/**
 * Travel behavior for patrol movement.
 * Uses AI_BEHAVIOR_REQUIRE_MOVEMENT to trigger the JPS pathfinding system.
 */
/datum/ai_behavior/patrol_travel
	required_distance = 1  // Stop when adjacent to door
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/patrol_travel/setup(datum/ai_controller/controller, target_key)
	var/obj/machinery/door/target = controller.blackboard[target_key]
	if(QDELETED(target))
		return FALSE
	var/turf/target_turf = get_turf(target)
	if(!target_turf)
		return FALSE
	controller.set_movement_target(type, target_turf)
	return TRUE

/datum/ai_behavior/patrol_travel/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/obj/machinery/door/target = controller.blackboard[target_key]
	// Succeed if door opened/destroyed or we're adjacent
	if(QDELETED(target) || !target.density || get_dist(controller.pawn, target) <= 1)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY

/datum/ai_behavior/patrol_travel/finish_action(datum/ai_controller/controller, succeeded, target_key)
	. = ..()

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

	// Don't handle patrol doors if we have a combat target - attack_obstacle_in_path handles combat obstacles
	if(controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
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
				else if(world.time > attack_start + PATROL_DOOR_ATTACK_TIMEOUT)
					// We've been attacking this door for too long - give up
					if(!skipped_doors)
						skipped_doors = list()
						controller.blackboard["_skipped_blocking_doors"] = skipped_doors
					skipped_doors[door_ref] = TRUE
					PATROL_LOG("[pawn] giving up on blocking door [blocking_door.name] after [PATROL_DOOR_ATTACK_TIMEOUT / 10] seconds of attacking")
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
	var/assembly_dist = get_dist(pawn, assembly)
	if(assembly_dist > 1)
		PATROL_LOG("[pawn] not adjacent to assembly [assembly.name] (dist=[assembly_dist]), cannot attack")
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
	var/door_dist = get_dist(pawn, door)
	if(door_dist > 1)
		PATROL_LOG("[pawn] not adjacent to blocking door [door.name] (dist=[door_dist]), cannot attack")
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
	// Don't do patrol door stuff if we have a combat target
	if(controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return

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
	// Don't do patrol door stuff if we have a combat target
	if(controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return

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
	var/door_dist = get_dist(pawn, door)
	if(door_dist > 1)
		PATROL_LOG("[pawn] not adjacent to door [door.name] (dist=[door_dist]), cannot attack")
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
 * Aggressive target finding subtree that uses range() instead of hearers().
 * This bypasses TG's broken proximity field system.
 */
/datum/ai_planning_subtree/aggressive_find_target
	/// Range to scan for targets
	var/scan_range = 9

/datum/ai_planning_subtree/aggressive_find_target/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	// Already have a valid target? Skip scanning
	var/atom/current_target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!QDELETED(current_target))
		return

	var/mob/living/pawn = controller.pawn
	if(!pawn || !isturf(pawn.loc))
		return

	var/datum/targeting_strategy/targeting_strategy = GET_TARGETING_STRATEGY(controller.blackboard[BB_TARGETING_STRATEGY])
	if(!targeting_strategy)
		PATROL_LOG("[pawn] aggressive_find_target: No targeting strategy!")
		return

	// Use range() instead of hearers() - more reliable on shuttles
	var/list/potential_targets = list()
	var/list/rejected_targets = list()
	for(var/mob/living/potential_target in range(scan_range, pawn))
		if(potential_target == pawn)
			continue
		if(targeting_strategy.can_attack(pawn, potential_target))
			potential_targets += potential_target
		else
			rejected_targets += "[potential_target] ([potential_target.type])"

	// Debug: log what we found
	if(length(rejected_targets))
		PATROL_LOG("[pawn] aggressive_find_target: Rejected [length(rejected_targets)] targets: [rejected_targets.Join(", ")]")

	if(!length(potential_targets))
		return

	// Pick closest target
	var/mob/living/best_target
	var/best_dist = INFINITY
	for(var/mob/living/target as anything in potential_targets)
		var/dist = get_dist(pawn, target)
		if(dist < best_dist)
			best_dist = dist
			best_target = target

	if(best_target)
		controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, best_target)
		PATROL_LOG("[pawn] aggressive_find_target: Found target [best_target] at dist=[best_dist]")

/**
 * Override of attack_obstacle_in_path that includes mobs in blocking checks.
 * Base TG uses exclude_mobs = TRUE which prevents attacking mobs blocking the path during chase.
 */
/datum/ai_planning_subtree/attack_obstacle_in_path/trooper/include_mobs
	attack_behaviour = /datum/ai_behavior/attack_obstructions/trooper/include_mobs

/datum/ai_planning_subtree/attack_obstacle_in_path/trooper/include_mobs/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/atom/target = controller.blackboard[target_key]
	if(QDELETED(target))
		return

	var/turf/next_step = get_step_towards(controller.pawn, target)
	// Use exclude_mobs = FALSE to detect mobs blocking the path
	if (!next_step.is_blocked_turf(exclude_mobs = FALSE, source_atom = controller.pawn))
		return

	controller.queue_behavior(attack_behaviour, target_key)
	// Don't cancel future planning, maybe we can move now

/datum/ai_behavior/attack_obstructions/trooper/include_mobs
	action_cooldown = 1.2 SECONDS

/datum/ai_behavior/attack_obstructions/trooper/include_mobs/attack_in_direction(datum/ai_controller/controller, mob/living/basic/basic_mob, direction)
	var/turf/next_step = get_step(basic_mob, direction)
	// Use exclude_mobs = FALSE to detect mobs blocking the path
	if (!next_step.is_blocked_turf(exclude_mobs = FALSE, source_atom = controller.pawn))
		return FALSE

	// First check for mobs blocking the path and attack them
	for (var/mob/living/blocking_mob in next_step)
		if (blocking_mob == basic_mob)
			continue
		// Attack the blocking mob
		basic_mob.melee_attack(blocking_mob)
		return TRUE

	// Then check for objects (original behavior)
	for (var/obj/object as anything in next_step.contents)
		if (!can_smash_object(basic_mob, object))
			continue
		basic_mob.melee_attack(object)
		return TRUE

	if (can_attack_turfs)
		basic_mob.melee_attack(next_step)
		return TRUE
	return FALSE

/**
 * Trooper AI controller variant that patrols door-to-door when not in combat.
 * Uses JPS pathfinding for reliable navigation through ship interiors.
 */
/datum/ai_controller/basic_controller/trooper/patrolling
	ai_movement = /datum/ai_movement/jps  // JPS pathfinding instead of basic_avoidance
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/aggressive_find_target,
		/datum/ai_planning_subtree/attack_obstacle_in_path/trooper/include_mobs,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
		/datum/ai_planning_subtree/handle_blocking_door,
		/datum/ai_planning_subtree/patrol_path,
		/datum/ai_planning_subtree/try_open_door_in_path,
		/datum/ai_planning_subtree/attack_patrol_door,
	)

/datum/ai_controller/basic_controller/trooper/ranged/patrolling
	ai_movement = /datum/ai_movement/jps
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/aggressive_find_target,
		/datum/ai_planning_subtree/attack_obstacle_in_path/trooper/include_mobs,
		/datum/ai_planning_subtree/basic_ranged_attack_subtree/trooper,
		/datum/ai_planning_subtree/handle_blocking_door,
		/datum/ai_planning_subtree/patrol_path,
		/datum/ai_planning_subtree/try_open_door_in_path,
		/datum/ai_planning_subtree/attack_patrol_door,
	)

/// Patrolling version for melee boss mobs
/datum/ai_controller/basic_controller/trooper/patrolling/boss
	ai_movement = /datum/ai_movement/jps
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/aggressive_find_target,
		/datum/ai_planning_subtree/attack_obstacle_in_path/trooper/include_mobs,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
		/datum/ai_planning_subtree/handle_blocking_door,
		/datum/ai_planning_subtree/patrol_path,
		/datum/ai_planning_subtree/try_open_door_in_path,
		/datum/ai_planning_subtree/attack_patrol_door,
	)

/// Patrolling version for ranged boss mobs
/datum/ai_controller/basic_controller/trooper/ranged/patrolling/boss
	ai_movement = /datum/ai_movement/jps
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/aggressive_find_target,
		/datum/ai_planning_subtree/attack_obstacle_in_path/trooper/include_mobs,
		/datum/ai_planning_subtree/basic_ranged_attack_subtree/trooper,
		/datum/ai_planning_subtree/handle_blocking_door,
		/datum/ai_planning_subtree/patrol_path,
		/datum/ai_planning_subtree/try_open_door_in_path,
		/datum/ai_planning_subtree/attack_patrol_door,
	)
