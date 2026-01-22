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

	// Collect all interior doors on the ship (exclude external airlocks)
	var/list/obj/machinery/door/all_doors = list()
	for(var/area/ship_area as anything in target_ship.shuttle.shuttle_areas)
		for(var/obj/machinery/door/D in ship_area)
			// Skip firedoors
			if(istype(D, /obj/machinery/door/firedoor))
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

	return path

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
	GLOB.boarding_patrol_paths -= REF(target_ship)

/**
 * Debug visualization - draws the door patrol path on the ship with colored markers.
 * Green at start, transitions to red at end. Numbers show visit order.
 *
 * @param target_ship The ship to visualize patrol path for
 * @param duration How long to show the visualization (default 30 seconds)
 */
/proc/visualize_patrol_path(obj/structure/overmap/ship/target_ship, duration = 30 SECONDS)
	var/list/path = get_ship_patrol_path(target_ship)
	if(!path || !length(path))
		to_chat(world, span_warning("No patrol path for [target_ship]"))
		return

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

	to_chat(world, span_notice("Visualizing door patrol path for [target_ship]: [path_length] doors (green=start, red=end)"))

	// Clean up after duration
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(clear_patrol_visualization), markers), duration)

/proc/clear_patrol_visualization(list/markers)
	for(var/obj/effect/patrol_marker/marker in markers)
		qdel(marker)

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
			visualize_patrol_path(S, 60 SECONDS)
			return

	to_chat(M, span_warning("Couldn't find a ship for this location. Try standing on a ship."))

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

	controller.blackboard[BB_MOB_PATROL_INDEX] = start_index

	PATROL_LOG("SUCCESS: Assigned [mob_to_assign] to patrol, start_index=[start_index] (nearest door), path_length=[length(path)]")

	// Auto-visualize path in debug mode (only once per ship)
	#if PATROL_DEBUG
	var/ship_ref = REF(target_ship)
	if(!GLOB.patrol_paths_visualized)
		GLOB.patrol_paths_visualized = list()
	if(!GLOB.patrol_paths_visualized[ship_ref])
		GLOB.patrol_paths_visualized[ship_ref] = TRUE
		visualize_patrol_path(target_ship, 60 SECONDS)
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
		PATROL_LOG("[pawn] door [old_index] destroyed, advancing to [patrol_index]")
		return // Let next planning cycle handle the new target

	// If door is open (not blocking), we've "passed" it - advance to next
	if(!target_door.density)
		// Only advance if we're actually near/past the door
		if(get_dist(pawn, target_door) <= 2)
			var/old_index = patrol_index
			patrol_index = (patrol_index % length(patrol_path)) + 1
			controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index
			target_door = patrol_path[patrol_index]
			PATROL_LOG("[pawn] passed door [old_index] (now open), advancing to [patrol_index]")

			// Check if new target is also destroyed/open
			if(QDELETED(target_door) || !target_door.density)
				return // Let next planning cycle handle

	// Log first patrol start
	if(!controller.blackboard["_patrol_started_logged"])
		controller.blackboard["_patrol_started_logged"] = TRUE
		PATROL_LOG("[pawn] STARTING DOOR PATROL - first target: [target_door.name] at ([target_door.x],[target_door.y]), dist=[get_dist(pawn, target_door)]")

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

	// Check if we already tried and failed to open this door recently
	var/last_failed_door = controller.blackboard["_last_failed_door"]
	var/last_failed_time = controller.blackboard["_last_failed_door_time"]
	if(last_failed_door == REF(target_door) && world.time < last_failed_time + 3 SECONDS)
		return  // Let attack subtree handle it

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
		// Door opened or gone - clear any failed door tracking
		controller.clear_blackboard_key("_last_failed_door")
		controller.clear_blackboard_key("_last_failed_door_time")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Try to open the door via bumpopen (handles access checks, power, etc.)
	door.bumpopen(pawn)

	// Check if it opened
	if(!door.density)
		PATROL_LOG("[pawn] successfully opened door [door]")
		controller.clear_blackboard_key("_last_failed_door")
		controller.clear_blackboard_key("_last_failed_door_time")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Door didn't open - it's probably locked or we don't have access
	// Record this so the subtree lets attack_obstacle_in_path handle it next tick
	controller.set_blackboard_key("_last_failed_door", REF(door))
	controller.set_blackboard_key("_last_failed_door_time", world.time)
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

	// Only attack if we recently failed to open it
	var/last_failed_door = controller.blackboard["_last_failed_door"]
	if(last_failed_door != REF(target_door))
		return  // Haven't tried to open it yet

	// Attack the door
	PATROL_LOG("[pawn] ATTACKING locked door [target_door.name]")
	controller.set_blackboard_key(BB_DOOR_TO_OPEN, target_door)
	controller.queue_behavior(/datum/ai_behavior/attack_door, BB_DOOR_TO_OPEN)
	return SUBTREE_RETURN_FINISH_PLANNING

/**
 * Behavior that attacks a door with melee
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
		// Door opened/destroyed
		controller.clear_blackboard_key("_last_failed_door")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Attack the door
	pawn.melee_attack(door)
	PATROL_LOG("[pawn] attacked door [door.name]")
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
		/datum/ai_planning_subtree/patrol_path,                      // Navigate to next door
		/datum/ai_planning_subtree/try_open_door_in_path,           // Try to open doors first
		/datum/ai_planning_subtree/attack_patrol_door,              // Attack locked doors
	)

/datum/ai_controller/basic_controller/trooper/ranged/patrolling
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_ranged_attack_subtree/trooper,  // Fight enemies when found
		/datum/ai_planning_subtree/patrol_path,                          // Navigate to next door
		/datum/ai_planning_subtree/try_open_door_in_path,               // Try to open doors first
		/datum/ai_planning_subtree/attack_patrol_door,                  // Attack locked doors
	)
