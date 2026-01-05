/**
 * NPC Ship Movement Behaviors
 *
 * These behaviors control how NPC ships move around the overmap:
 * - Orbit: Circle around a celestial object (avoids obstacles)
 * - Patrol: Travel between waypoints in the red zone (avoids obstacles)
 * - Chase: Pursue a target ship (IGNORES obstacles - players can bait NPCs into hazards!)
 */

/**
 * Helper proc to check if a direction has obstacles (overmap events).
 * Returns a safer direction to move, or 0 if the original direction is safe.
 */
/datum/ai_behavior/npc_ship/proc/get_safe_direction(obj/structure/overmap/ship/ship, direction)
	var/turf/our_loc = get_turf(ship)
	if(!our_loc)
		return direction

	// Check tiles in the movement direction for obstacles
	var/list/dirs_to_check = list()

	// Primary direction and diagonals
	if(direction & NORTH)
		dirs_to_check += NORTH
	if(direction & SOUTH)
		dirs_to_check += SOUTH
	if(direction & EAST)
		dirs_to_check += EAST
	if(direction & WEST)
		dirs_to_check += WEST

	var/obstacle_found = FALSE
	for(var/check_dir in dirs_to_check)
		for(var/i in 1 to NPC_SHIP_OBSTACLE_SCAN_RANGE)
			var/turf/check_turf = get_step(our_loc, check_dir)
			if(!check_turf)
				continue
			our_loc = check_turf  // Move forward for next iteration

			// Check for overmap events (meteors, ion storms, etc.)
			for(var/obj/structure/overmap/event/E in check_turf)
				log_shuttle("NPC OBSTACLE: Found [E.type] at ([check_turf.x],[check_turf.y]) in direction [dir2text(check_dir)]")
				obstacle_found = TRUE
				break
			if(obstacle_found)
				break
		if(obstacle_found)
			break
		our_loc = get_turf(ship)  // Reset for next direction check

	if(!obstacle_found)
		return direction  // Original direction is safe

	// Try to find a safe alternative direction
	var/list/alternative_dirs = list(NORTH, SOUTH, EAST, WEST, NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST)
	alternative_dirs -= direction  // Don't try the blocked direction

	for(var/alt_dir in alternative_dirs)
		var/alt_safe = TRUE
		var/turf/check_loc = get_turf(ship)
		for(var/i in 1 to NPC_SHIP_OBSTACLE_SCAN_RANGE)
			var/turf/check_turf = get_step(check_loc, alt_dir)
			if(!check_turf)
				break
			check_loc = check_turf
			for(var/obj/structure/overmap/event/E in check_turf)
				alt_safe = FALSE
				break
			if(!alt_safe)
				break
		if(alt_safe)
			log_shuttle("NPC OBSTACLE: Redirecting from [dir2text(direction)] to [dir2text(alt_dir)]")
			return alt_dir

	// No safe direction found, stop moving
	log_shuttle("NPC OBSTACLE: No safe direction found, stopping")
	return 0

// ========== ORBIT BEHAVIOR ==========

/**
 * Orbits around a celestial object (star, planet, etc.).
 * The ship will try to maintain a specific distance while circling.
 */
/datum/ai_behavior/npc_ship/orbit
	action_cooldown = 1 SECONDS

/datum/ai_behavior/npc_ship/orbit/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	log_shuttle("NPC ORBIT: ship=[ship] state=[ship?.state]")
	if(!ship || ship.state != OVERMAP_SHIP_FLYING)
		log_shuttle("NPC ORBIT: Aborting - not flying")
		return AI_BEHAVIOR_DELAY

	// Get orbit target (celestial object)
	var/atom/orbit_target = controller.blackboard[BB_NPC_ORBIT_TARGET]
	if(!orbit_target || QDELETED(orbit_target))
		log_shuttle("NPC ORBIT: No orbit target set!")
		return AI_BEHAVIOR_DELAY

	var/orbit_distance = controller.blackboard[BB_NPC_ORBIT_DISTANCE] || NPC_SHIP_ORBIT_DISTANCE
	var/current_angle = controller.blackboard[BB_NPC_ORBIT_ANGLE] || 0

	var/turf/target_loc = get_turf(orbit_target)
	var/turf/our_loc = get_turf(ship)
	if(!target_loc || !our_loc)
		return AI_BEHAVIOR_DELAY

	// Calculate current distance and angle to target
	var/dx = our_loc.x - target_loc.x
	var/dy = our_loc.y - target_loc.y
	var/current_dist = sqrt(dx*dx + dy*dy)

	// Calculate where we should be (advance angle for orbit)
	current_angle += 15 // Degrees per tick
	if(current_angle >= 360)
		current_angle -= 360
	controller.set_blackboard_key(BB_NPC_ORBIT_ANGLE, current_angle)

	// Calculate target position on orbit circle
	var/target_x = target_loc.x + cos(current_angle) * orbit_distance
	var/target_y = target_loc.y + sin(current_angle) * orbit_distance

	// Calculate direction to target orbit position
	var/move_dx = target_x - our_loc.x
	var/move_dy = target_y - our_loc.y

	// Determine acceleration direction
	var/direction = 0
	if(abs(move_dx) > 0.5)
		direction |= (move_dx > 0) ? EAST : WEST
	if(abs(move_dy) > 0.5)
		direction |= (move_dy > 0) ? NORTH : SOUTH

	if(direction)
		// Check for obstacles and get safe direction
		var/safe_dir = get_safe_direction(ship, direction)
		if(safe_dir)
			log_shuttle("NPC ORBIT: Accelerating [dir2text(safe_dir)] (wanted [dir2text(direction)])")
			ship.accelerate(safe_dir, NPC_SHIP_ACCELERATION)
		else
			log_shuttle("NPC ORBIT: Blocked by obstacles, decelerating")
			if(!ship.is_still())
				ship.decelerate(NPC_SHIP_ACCELERATION)
	else if(current_dist > orbit_distance + 1)
		// Too far, move toward target - with obstacle avoidance
		var/toward_dir = get_dir(ship, orbit_target)
		var/safe_toward = get_safe_direction(ship, toward_dir)
		if(safe_toward)
			ship.accelerate(safe_toward, NPC_SHIP_ACCELERATION)
	else if(current_dist < orbit_distance - 1)
		// Too close, move away - with obstacle avoidance
		var/away_dir = get_dir(orbit_target, ship)
		var/safe_away = get_safe_direction(ship, away_dir)
		if(safe_away)
			ship.accelerate(safe_away, NPC_SHIP_ACCELERATION)

	return AI_BEHAVIOR_DELAY

// ========== PATROL BEHAVIOR ==========

/**
 * Patrols between waypoints in the red zone.
 * Generates waypoints along the edges of the red zone.
 */
/datum/ai_behavior/npc_ship/patrol
	action_cooldown = 1 SECONDS

/datum/ai_behavior/npc_ship/patrol/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	log_shuttle("NPC PATROL: ship=[ship] state=[ship?.state]")
	if(!ship || ship.state != OVERMAP_SHIP_FLYING)
		log_shuttle("NPC PATROL: Aborting - not flying (state=[ship?.state])")
		return AI_BEHAVIOR_DELAY

	// Get or generate patrol waypoints
	var/list/waypoints = controller.blackboard[BB_NPC_PATROL_WAYPOINTS]
	if(!length(waypoints))
		log_shuttle("NPC PATROL: No waypoints, generating...")
		waypoints = generate_patrol_waypoints(ship)
		if(!length(waypoints))
			log_shuttle("NPC PATROL: Failed to generate waypoints! SSovermap_zones.zone_red=[SSovermap_zones?.zone_red] turfs=[SSovermap_zones?.zone_red?.turfs?.len]")
			return AI_BEHAVIOR_DELAY
		log_shuttle("NPC PATROL: Generated [length(waypoints)] waypoints")
		controller.set_blackboard_key(BB_NPC_PATROL_WAYPOINTS, waypoints)
		controller.set_blackboard_key(BB_NPC_PATROL_INDEX, 1)

	var/waypoint_index = controller.blackboard[BB_NPC_PATROL_INDEX] || 1
	if(waypoint_index > length(waypoints))
		waypoint_index = 1
		controller.set_blackboard_key(BB_NPC_PATROL_INDEX, waypoint_index)

	var/turf/waypoint = waypoints[waypoint_index]
	if(!waypoint)
		log_shuttle("NPC PATROL: Waypoint [waypoint_index] is null!")
		return AI_BEHAVIOR_DELAY

	var/turf/our_loc = get_turf(ship)
	if(!our_loc)
		return AI_BEHAVIOR_DELAY

	// Check if we've reached the waypoint
	var/dist = get_dist(ship, waypoint)
	log_shuttle("NPC PATROL: Waypoint [waypoint_index]/[length(waypoints)] at ([waypoint.x],[waypoint.y]), dist=[dist]")

	if(dist <= NPC_SHIP_PATROL_THRESHOLD)
		// Move to next waypoint
		waypoint_index++
		if(waypoint_index > length(waypoints))
			waypoint_index = 1
		log_shuttle("NPC PATROL: Reached waypoint, moving to [waypoint_index]")
		controller.set_blackboard_key(BB_NPC_PATROL_INDEX, waypoint_index)
		return AI_BEHAVIOR_DELAY

	// Move toward waypoint - with obstacle avoidance
	var/direction = get_dir(ship, waypoint)
	if(direction)
		// Check for obstacles and get safe direction
		var/safe_dir = get_safe_direction(ship, direction)
		if(safe_dir)
			log_shuttle("NPC PATROL: Accelerating [dir2text(safe_dir)] toward waypoint (wanted [dir2text(direction)])")
			ship.accelerate(safe_dir, NPC_SHIP_ACCELERATION)
		else
			log_shuttle("NPC PATROL: Blocked by obstacles, decelerating")
			if(!ship.is_still())
				ship.decelerate(NPC_SHIP_ACCELERATION)

	return AI_BEHAVIOR_DELAY

/**
 * Generates patrol waypoints in the red zone.
 */
/datum/ai_behavior/npc_ship/patrol/proc/generate_patrol_waypoints(obj/structure/overmap/ship/ship)
	var/list/waypoints = list()

	// Get the red zone
	var/datum/overmap_zone/red_zone = SSovermap_zones.zone_red
	if(!red_zone || !length(red_zone.turfs))
		log_shuttle("NPC PATROL WAYPOINTS: No red zone or no turfs!")
		return waypoints

	// Pick 4-8 random turfs from the red zone as waypoints
	var/num_waypoints = rand(4, 8)
	var/list/available_turfs = red_zone.turfs.Copy()

	for(var/i in 1 to min(num_waypoints, length(available_turfs)))
		var/turf/waypoint = pick_n_take(available_turfs)
		if(waypoint)
			waypoints += waypoint

	log_shuttle("NPC PATROL WAYPOINTS: Generated [length(waypoints)] from [length(red_zone.turfs)] red zone turfs")
	return waypoints

// ========== CHASE BEHAVIOR ==========

/**
 * Chases a target ship when it enters range.
 * Stops chasing at zone boundaries or when target escapes range.
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
	log_shuttle("NPC CHASE: ship=[ship] state=[ship?.state]")
	if(!ship || ship.state != OVERMAP_SHIP_FLYING)
		log_shuttle("NPC CHASE: Aborting - not flying")
		return AI_BEHAVIOR_DELAY

	var/obj/structure/overmap/ship/target = controller.get_target()

	// No target - sit idle and wait
	if(!target || QDELETED(target))
		log_shuttle("NPC CHASE: No target, decelerating")
		// Decelerate if we were moving
		if(!ship.is_still())
			ship.decelerate(NPC_SHIP_ACCELERATION)
		return AI_BEHAVIOR_DELAY

	var/turf/our_loc = get_turf(ship)
	var/turf/target_loc = get_turf(target)
	var/turf/home_turf = controller.blackboard[BB_NPC_HOME_TURF]

	if(!our_loc || !target_loc)
		return AI_BEHAVIOR_DELAY

	// Check zone boundary - stop chasing if we'd leave RED zone
	var/target_zone = SSovermap_zones.get_zone(target_loc)
	log_shuttle("NPC CHASE: Target [target] at zone [target_zone] (need ZONE_RED)")
	if(target_zone != ZONE_RED)
		log_shuttle("NPC CHASE: Target escaped to safe zone, stopping")
		ship.decelerate(NPC_SHIP_ACCELERATION * 2)
		return AI_BEHAVIOR_DELAY

	// Check chase boundary (max distance from home)
	if(home_turf)
		var/chase_range = controller.blackboard[BB_NPC_CHASE_BOUNDARY] || NPC_SHIP_CHASE_RANGE
		var/dist_from_home = get_dist(ship, home_turf)
		log_shuttle("NPC CHASE: Dist from home=[dist_from_home] max=[chase_range]")
		if(dist_from_home >= chase_range)
			log_shuttle("NPC CHASE: At chase boundary, stopping")
			ship.decelerate(NPC_SHIP_ACCELERATION)
			return AI_BEHAVIOR_DELAY

	// Chase the target
	var/direction = get_dir(ship, target)
	if(direction)
		log_shuttle("NPC CHASE: Chasing [target], accelerating [dir2text(direction)]")
		ship.accelerate(direction, NPC_SHIP_ACCELERATION)

	return AI_BEHAVIOR_DELAY

// ========== RETURN HOME BEHAVIOR ==========

/**
 * Returns to home position when target is lost or escaped.
 * Used after chase behavior disengages.
 */
/datum/ai_behavior/npc_ship/return_home
	action_cooldown = 1 SECONDS

/datum/ai_behavior/npc_ship/return_home/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	log_shuttle("NPC RETURN_HOME: ship=[ship] state=[ship?.state]")
	if(!ship || ship.state != OVERMAP_SHIP_FLYING)
		log_shuttle("NPC RETURN_HOME: Aborting - not flying")
		return AI_BEHAVIOR_DELAY

	var/turf/home_turf = controller.blackboard[BB_NPC_HOME_TURF]
	if(!home_turf)
		log_shuttle("NPC RETURN_HOME: No home turf set!")
		return AI_BEHAVIOR_DELAY

	var/turf/our_loc = get_turf(ship)
	if(!our_loc)
		return AI_BEHAVIOR_DELAY

	var/dist = get_dist(ship, home_turf)
	log_shuttle("NPC RETURN_HOME: Dist to home=[dist]")

	// Close enough to home - stop
	if(dist <= 2)
		log_shuttle("NPC RETURN_HOME: At home, stopping")
		if(!ship.is_still())
			ship.decelerate(NPC_SHIP_ACCELERATION * 2)
		return AI_BEHAVIOR_DELAY

	// Move toward home - with obstacle avoidance
	var/direction = get_dir(ship, home_turf)
	if(direction)
		var/safe_dir = get_safe_direction(ship, direction)
		if(safe_dir)
			log_shuttle("NPC RETURN_HOME: Moving home, accelerating [dir2text(safe_dir)] (wanted [dir2text(direction)])")
			ship.accelerate(safe_dir, NPC_SHIP_ACCELERATION)
		else
			log_shuttle("NPC RETURN_HOME: Blocked by obstacles, waiting")
			if(!ship.is_still())
				ship.decelerate(NPC_SHIP_ACCELERATION)

	return AI_BEHAVIOR_DELAY
