/**
 * NPC Ship Movement Behaviors
 *
 * These behaviors control how NPC ships move around the overmap:
 * - Patrol: Travel between waypoints in the zone (avoids obstacles)
 * - Chase: Pursue a target ship (IGNORES obstacles - players can bait NPCs into hazards!)
 * - Return home: Go back to spawn point
 * - Return to zone: Emergency return when outside spawn zone
 */

/**
 * Helper proc to check if a turf has an obstacle.
 * Uses locate() for O(1) lookup instead of iterating.
 */
/datum/ai_behavior/npc_ship/proc/turf_has_obstacle(turf/T)
	return locate(/obj/structure/overmap/event) in T

/**
 * Checks if there's an obstacle in a given direction within scan range.
 */
/datum/ai_behavior/npc_ship/proc/direction_has_obstacle(turf/start, direction)
	var/turf/check_turf = start
	for(var/i in 1 to NPC_SHIP_OBSTACLE_SCAN_RANGE)
		check_turf = get_step(check_turf, direction)
		if(!check_turf)
			return FALSE
		if(turf_has_obstacle(check_turf))
			return TRUE
	return FALSE

/**
 * Checks if moving in a direction would take the ship out of its spawn zone.
 * Returns TRUE if the direction is safe (stays in zone), FALSE if it would leave.
 */
/datum/ai_behavior/npc_ship/proc/direction_stays_in_zone(turf/start, direction, spawn_zone)
	if(!spawn_zone)
		return TRUE  // No zone restriction
	var/turf/next_turf = get_step(start, direction)
	if(!next_turf)
		return FALSE
	var/next_zone = SSovermap_zones.get_zone(next_turf)
	return next_zone == spawn_zone

/**
 * Gets a safe direction that avoids obstacles AND stays in spawn zone.
 * Used by patrol, orbit, and return_home behaviors.
 * If completely stuck, will prioritize obstacle avoidance over zone (return_to_zone will fix it).
 */
/datum/ai_behavior/npc_ship/proc/get_zone_safe_direction(obj/structure/overmap/ship/ship, direction, spawn_zone)
	var/turf/start_loc = get_turf(ship)
	if(!start_loc)
		return direction

	var/static/list/alt_priority = list(NORTH, EAST, SOUTH, WEST, NORTHEAST, SOUTHEAST, NORTHWEST, SOUTHWEST)

	// Check if primary direction is safe (no obstacles AND stays in zone)
	if(!direction_has_obstacle(start_loc, direction) && direction_stays_in_zone(start_loc, direction, spawn_zone))
		return direction

	// Path blocked or would leave zone - find alternative that satisfies BOTH
	for(var/alt_dir in alt_priority)
		if(alt_dir == direction)
			continue
		if(!direction_has_obstacle(start_loc, alt_dir) && direction_stays_in_zone(start_loc, alt_dir, spawn_zone))
			return alt_dir

	// No direction satisfies both - try to find one that at least avoids obstacles
	for(var/alt_dir in alt_priority)
		if(!direction_has_obstacle(start_loc, alt_dir))
			return alt_dir

	// Truly surrounded by obstacles - no safe direction
	return 0

// ========== PATROL BEHAVIOR ==========

/**
 * Patrols in a circular circuit around the zone.
 * Uses A* pathfinding to navigate between circuit waypoints.
 * Moves tile-by-tile: thrust -> coast -> arrive -> brake -> repeat
 * Falls back to roaming if circuit generation fails.
 */
/datum/ai_behavior/npc_ship/patrol
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/npc_ship/patrol/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	if(!ship)
		log_shuttle("NPC PATROL: No ship!")
		return AI_BEHAVIOR_DELAY
	if(ship.state != OVERMAP_SHIP_FLYING)
		log_shuttle("NPC PATROL: Ship not flying, state=[ship.state]")
		return AI_BEHAVIOR_DELAY

	var/turf/our_loc = get_turf(ship)
	if(!our_loc)
		log_shuttle("NPC PATROL: No location!")
		return AI_BEHAVIOR_DELAY

	var/datum/overmap_zone/spawn_zone = controller.blackboard[BB_NPC_SPAWN_ZONE]

	// === TILE-BY-TILE MOVEMENT ===
	var/turf/target_tile = controller.blackboard[BB_NPC_TARGET_TILE]
	log_shuttle("NPC PATROL: ship=[ship] loc=([our_loc.x],[our_loc.y]) target_tile=[target_tile ? "([target_tile.x],[target_tile.y])" : "null"] speed=([ship.speed[1]],[ship.speed[2]]) still=[ship.is_still()]")
	if(target_tile)
		// Check if we've arrived (exact match OR within 1 tile for diagonal movement)
		var/arrived = (our_loc == target_tile) || (get_dist(ship, target_tile) <= 1)
		if(arrived)
			// Arrived! Brake and clear target
			log_shuttle("NPC PATROL: ARRIVED at target tile!")
			if(!ship.is_still())
				ship.burn_engines(null, 100)
				return AI_BEHAVIOR_DELAY
			// Fully stopped - clear target and continue
			controller.set_blackboard_key(BB_NPC_TARGET_TILE, null)
			log_shuttle("NPC PATROL: Cleared target_tile, ready for next")
		else
			// Still en route - but check if we're actually moving
			if(ship.is_still())
				// We're stopped but haven't arrived - need to re-thrust!
				log_shuttle("NPC PATROL: STUCK! Stopped but not at target. Re-thrusting...")
				var/direction = get_dir(ship, target_tile)
				if(direction)
					ship.burn_engines(direction, 100)
					log_shuttle("NPC PATROL: Re-thrust [dir2text(direction)]!")
			else
				log_shuttle("NPC PATROL: En route to target, coasting...")
			return AI_BEHAVIOR_DELAY

	// === CIRCUIT MANAGEMENT ===
	var/list/circuit = controller.blackboard[BB_NPC_PATROL_CIRCUIT]
	log_shuttle("NPC PATROL: circuit=[length(circuit)] waypoints")
	if(!length(circuit))
		log_shuttle("NPC PATROL: Generating new circuit...")
		circuit = generate_patrol_circuit(spawn_zone, NPC_SHIP_ORBIT_VARIANCE, NPC_SHIP_CIRCUIT_WAYPOINTS)
		log_shuttle("NPC PATROL: Generated circuit with [length(circuit)] waypoints")
		if(!length(circuit))
			log_shuttle("NPC PATROL: Circuit generation FAILED, switching to roaming")
			controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_ROAMING)
			return AI_BEHAVIOR_DELAY
		controller.blackboard[BB_NPC_PATROL_CIRCUIT] = circuit
		controller.set_blackboard_key(BB_NPC_CIRCUIT_INDEX, 1)

	var/circuit_index = controller.blackboard[BB_NPC_CIRCUIT_INDEX] || 1
	if(circuit_index > length(circuit))
		circuit_index = 1
		controller.set_blackboard_key(BB_NPC_CIRCUIT_INDEX, circuit_index)

	var/turf/target_waypoint = circuit[circuit_index]
	if(!target_waypoint)
		controller.set_blackboard_key(BB_NPC_CIRCUIT_INDEX, circuit_index + 1)
		return AI_BEHAVIOR_DELAY

	// Check if we've reached the circuit waypoint (exact position - we're doing tile-by-tile movement)
	if(our_loc == target_waypoint)
		log_shuttle("NPC PATROL: Reached waypoint [circuit_index], advancing to next")
		circuit_index++
		if(circuit_index > length(circuit))
			circuit_index = 1
		controller.set_blackboard_key(BB_NPC_CIRCUIT_INDEX, circuit_index)
		controller.blackboard[BB_NPC_CURRENT_PATH] = null
		controller.set_blackboard_key(BB_NPC_PATH_INDEX, 1)
		return AI_BEHAVIOR_DELAY

	// === PATH MANAGEMENT ===
	var/list/path = controller.blackboard[BB_NPC_CURRENT_PATH]
	var/path_index = controller.blackboard[BB_NPC_PATH_INDEX] || 1
	var/path_time = controller.blackboard[BB_NPC_PATH_TIMESTAMP] || 0

	log_shuttle("NPC PATROL: path=[length(path)] steps, path_index=[path_index], target_waypoint=([target_waypoint?.x],[target_waypoint?.y])")

	var/needs_repath = !length(path)
	if(!needs_repath && path_index > length(path))
		needs_repath = TRUE
	if(!needs_repath && (world.time - path_time) > NPC_SHIP_REPATH_INTERVAL)
		needs_repath = TRUE

	if(needs_repath)
		log_shuttle("NPC PATROL: Calculating A* path from ([our_loc.x],[our_loc.y]) to ([target_waypoint.x],[target_waypoint.y])")
		var/list/new_path = overmap_astar(our_loc, target_waypoint, spawn_zone)
		log_shuttle("NPC PATROL: A* returned [length(new_path)] steps")
		if(length(new_path))
			// Use direct blackboard assignment and update local vars to continue immediately
			controller.blackboard[BB_NPC_CURRENT_PATH] = new_path
			controller.blackboard[BB_NPC_PATH_INDEX] = 1
			controller.blackboard[BB_NPC_PATH_TIMESTAMP] = world.time
			path = new_path
			path_index = 1
			log_shuttle("NPC PATROL: Path updated! First tile: ([new_path[1]:x],[new_path[1]:y])")
			// Continue with new path (don't return)
		else
			// No path found - skip this waypoint
			log_shuttle("NPC PATROL: No path found, skipping waypoint")
			controller.set_blackboard_key(BB_NPC_CIRCUIT_INDEX, circuit_index + 1)
			return AI_BEHAVIOR_DELAY

	// === MOVE TO NEXT TILE ===
	if(length(path) && path_index <= length(path))
		var/turf/next_tile = path[path_index]
		log_shuttle("NPC PATROL: Moving to next_tile=([next_tile?.x],[next_tile?.y])")

		// Skip if already on this tile
		if(our_loc == next_tile)
			path_index++
			controller.set_blackboard_key(BB_NPC_PATH_INDEX, path_index)
			if(path_index > length(path))
				controller.blackboard[BB_NPC_CURRENT_PATH] = null
				return AI_BEHAVIOR_DELAY
			next_tile = path[path_index]

		// Set target and thrust
		var/direction = get_dir(ship, next_tile)
		log_shuttle("NPC PATROL: Direction=[dir2text(direction)] to tile ([next_tile?.x],[next_tile?.y])")
		if(direction)
			controller.set_blackboard_key(BB_NPC_TARGET_TILE, next_tile)
			controller.set_blackboard_key(BB_NPC_PATH_INDEX, path_index + 1)
			var/old_speed_x = ship.speed[1]
			var/old_speed_y = ship.speed[2]
			ship.burn_engines(direction, 100)
			log_shuttle("NPC PATROL: THRUSTING [dir2text(direction)]! Speed changed: ([old_speed_x],[old_speed_y]) -> ([ship.speed[1]],[ship.speed[2]]) est_thrust=[ship.est_thrust]")

	return AI_BEHAVIOR_DELAY


// ========== ROAMING BEHAVIOR ==========

/**
 * Fallback behavior when circuit patrol is impossible.
 * Picks random directions and wanders the zone.
 * Moves tile-by-tile: thrust -> coast -> arrive -> brake -> repeat
 */
/datum/ai_behavior/npc_ship/roaming
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/npc_ship/roaming/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	if(!ship || ship.state != OVERMAP_SHIP_FLYING)
		return AI_BEHAVIOR_DELAY

	var/turf/our_loc = get_turf(ship)
	if(!our_loc)
		return AI_BEHAVIOR_DELAY

	var/datum/overmap_zone/spawn_zone = controller.blackboard[BB_NPC_SPAWN_ZONE]

	// === TILE-BY-TILE MOVEMENT ===
	var/turf/target_tile = controller.blackboard[BB_NPC_TARGET_TILE]
	if(target_tile)
		var/arrived = (our_loc == target_tile) || (get_dist(ship, target_tile) <= 1)
		if(arrived)
			// Arrived - brake and clear
			if(!ship.is_still())
				ship.burn_engines(null, 100)
				return AI_BEHAVIOR_DELAY
			controller.set_blackboard_key(BB_NPC_TARGET_TILE, null)
		else
			// Still en route - coast
			return AI_BEHAVIOR_DELAY

	// Pick a random safe direction and move one tile
	var/roaming_dir = pick_random_safe_direction(our_loc, spawn_zone)
	if(roaming_dir)
		var/turf/next_tile = get_step(our_loc, roaming_dir)
		if(next_tile)
			controller.set_blackboard_key(BB_NPC_TARGET_TILE, next_tile)
			ship.burn_engines(roaming_dir, 100)

	return AI_BEHAVIOR_DELAY

/**
 * Picks a random direction that avoids obstacles and stays in zone.
 */
/datum/ai_behavior/npc_ship/roaming/proc/pick_random_safe_direction(turf/from, datum/overmap_zone/zone)
	var/list/valid_dirs = list()
	for(var/dir in GLOB.alldirs)
		if(!direction_has_obstacle(from, dir) && direction_stays_in_zone(from, dir, zone))
			valid_dirs += dir
	if(length(valid_dirs))
		return pick(valid_dirs)
	return 0


// ========== RETURN TO ROUTE BEHAVIOR ==========

/**
 * Returns to patrol circuit after combat ends.
 * Uses A* to path back to the nearest circuit waypoint.
 * Moves tile-by-tile: thrust -> coast -> arrive -> brake -> repeat
 */
/datum/ai_behavior/npc_ship/return_to_route
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/npc_ship/return_to_route/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	if(!ship || ship.state != OVERMAP_SHIP_FLYING)
		return AI_BEHAVIOR_DELAY

	var/turf/our_loc = get_turf(ship)
	if(!our_loc)
		return AI_BEHAVIOR_DELAY

	var/datum/overmap_zone/spawn_zone = controller.blackboard[BB_NPC_SPAWN_ZONE]

	// === TILE-BY-TILE MOVEMENT ===
	var/turf/target_tile = controller.blackboard[BB_NPC_TARGET_TILE]
	if(target_tile)
		var/arrived = (our_loc == target_tile) || (get_dist(ship, target_tile) <= 1)
		if(arrived)
			// Arrived - brake and clear
			if(!ship.is_still())
				ship.burn_engines(null, 100)
				return AI_BEHAVIOR_DELAY
			controller.set_blackboard_key(BB_NPC_TARGET_TILE, null)
		else
			// Still en route - coast
			return AI_BEHAVIOR_DELAY

	// === CIRCUIT CHECK ===
	var/list/circuit = controller.blackboard[BB_NPC_PATROL_CIRCUIT]
	if(!length(circuit))
		controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_ROAMING)
		return AI_BEHAVIOR_DELAY

	// Find nearest circuit waypoint if needed
	var/circuit_index = controller.blackboard[BB_NPC_CIRCUIT_INDEX]
	if(!circuit_index)
		circuit_index = find_nearest_circuit_waypoint(our_loc, circuit)
		controller.set_blackboard_key(BB_NPC_CIRCUIT_INDEX, circuit_index)
		controller.blackboard[BB_NPC_CURRENT_PATH] = null
		controller.set_blackboard_key(BB_NPC_PATH_INDEX, 1)

	var/turf/target_waypoint = circuit[circuit_index]
	if(!target_waypoint)
		controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_ROAMING)
		return AI_BEHAVIOR_DELAY

	// Check if we've reached the waypoint (exact position)
	if(our_loc == target_waypoint)
		controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_PATROL)
		controller.blackboard[BB_NPC_CURRENT_PATH] = null
		controller.set_blackboard_key(BB_NPC_PATH_INDEX, 1)
		controller.set_blackboard_key(BB_NPC_HAD_TARGET, FALSE)
		return AI_BEHAVIOR_DELAY

	// === PATH MANAGEMENT ===
	var/list/path = controller.blackboard[BB_NPC_CURRENT_PATH]
	var/path_index = controller.blackboard[BB_NPC_PATH_INDEX] || 1
	var/path_time = controller.blackboard[BB_NPC_PATH_TIMESTAMP] || 0

	var/needs_repath = !length(path)
	if(!needs_repath && path_index > length(path))
		needs_repath = TRUE
	if(!needs_repath && (world.time - path_time) > NPC_SHIP_REPATH_INTERVAL)
		needs_repath = TRUE

	if(needs_repath)
		var/list/new_path = overmap_astar(our_loc, target_waypoint, spawn_zone)
		if(length(new_path))
			// Use direct blackboard assignment and update local vars to continue immediately
			controller.blackboard[BB_NPC_CURRENT_PATH] = new_path
			controller.blackboard[BB_NPC_PATH_INDEX] = 1
			controller.blackboard[BB_NPC_PATH_TIMESTAMP] = world.time
			path = new_path
			path_index = 1
			// Continue with new path (don't return)
		else
			controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_ROAMING)
			return AI_BEHAVIOR_DELAY

	// === MOVE TO NEXT TILE ===
	if(length(path) && path_index <= length(path))
		var/turf/next_tile = path[path_index]

		if(our_loc == next_tile)
			path_index++
			controller.set_blackboard_key(BB_NPC_PATH_INDEX, path_index)
			if(path_index > length(path))
				controller.blackboard[BB_NPC_CURRENT_PATH] = null
				return AI_BEHAVIOR_DELAY
			next_tile = path[path_index]

		var/direction = get_dir(ship, next_tile)
		if(direction)
			controller.set_blackboard_key(BB_NPC_TARGET_TILE, next_tile)
			controller.set_blackboard_key(BB_NPC_PATH_INDEX, path_index + 1)
			ship.burn_engines(direction, 100)

	return AI_BEHAVIOR_DELAY

// ========== CHASE BEHAVIOR ==========

/**
 * Chases a target ship when it enters range.
 * Stops chasing at zone boundaries or when target escapes.
 *
 * IMPORTANT: This behavior INTENTIONALLY IGNORES obstacles!
 * Players can bait NPC ships into meteor storms, ion storms, etc.
 * This is a core gameplay mechanic - don't add obstacle avoidance here!
 */
/datum/ai_behavior/npc_ship/chase
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/npc_ship/chase/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	if(!ship || ship.state != OVERMAP_SHIP_FLYING)
		return AI_BEHAVIOR_DELAY

	var/obj/structure/overmap/ship/target = controller.get_target()

	// No target - decelerate and wait for subtree to switch to return_to_route
	if(!target || QDELETED(target))
		if(!ship.is_still())
			ship.burn_engines(null, 100)
		return AI_BEHAVIOR_DELAY

	var/turf/our_loc = get_turf(ship)
	var/turf/target_loc = get_turf(target)

	if(!our_loc || !target_loc)
		return AI_BEHAVIOR_DELAY

	// Get spawn zone - ship cannot leave this zone
	var/datum/overmap_zone/spawn_zone = controller.blackboard[BB_NPC_SPAWN_ZONE]

	// Check if target escaped to a different zone
	var/target_zone = SSovermap_zones.get_zone(target_loc)
	if(spawn_zone && target_zone != spawn_zone)
		ship.burn_engines(null, 200)
		return AI_BEHAVIOR_DELAY

	// Chase the target - but check if next tile would leave our zone
	var/direction = get_dir(ship, target)
	if(direction)
		// Check if moving this direction would leave spawn zone
		if(spawn_zone && !direction_stays_in_zone(our_loc, direction, spawn_zone))
			ship.burn_engines(null, 200)
			return AI_BEHAVIOR_DELAY

		// Chase! (intentionally ignoring obstacles - players can bait us into hazards)
		ship.burn_engines(direction, 100)

	return AI_BEHAVIOR_DELAY

// ========== RETURN TO ZONE BEHAVIOR ==========

/**
 * Emergency behavior when ship has drifted outside its spawn zone.
 * Aggressively decelerates and moves back toward zone center.
 * Ignores obstacles - getting back to zone is priority.
 */
/datum/ai_behavior/npc_ship/return_to_zone
	action_cooldown = 0.25 SECONDS  // Fast tick for responsive correction

/datum/ai_behavior/npc_ship/return_to_zone/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	if(!ship || ship.state != OVERMAP_SHIP_FLYING)
		return AI_BEHAVIOR_DELAY

	var/turf/our_loc = get_turf(ship)
	var/datum/overmap_zone/spawn_zone = controller.blackboard[BB_NPC_SPAWN_ZONE]

	if(!our_loc || !spawn_zone)
		return AI_BEHAVIOR_DELAY

	// Check if we're back in our zone
	var/current_zone = SSovermap_zones.get_zone(our_loc)
	if(current_zone == spawn_zone)
		// We're back - stop and let normal behaviors take over
		if(!ship.is_still())
			ship.burn_engines(null, 300)
		return AI_BEHAVIOR_DELAY

	// Still outside zone - aggressive return toward zone center

	// First, hard brake to stop drifting further
	if(!ship.is_still())
		ship.burn_engines(null, 200)

	// Accelerate toward zone center (ignore obstacles - we MUST get back)
	var/turf/center = locate(SSovermap_zones.center_x, SSovermap_zones.center_y, OVERMAP_Z_LEVEL)
	if(center)
		var/direction = get_dir(ship, center)
		if(direction)
			ship.burn_engines(direction, 100)

	return AI_BEHAVIOR_DELAY
