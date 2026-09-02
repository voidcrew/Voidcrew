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
 * Discrete movement: moves one tile per tick (no momentum/physics).
 * Falls back to roaming if circuit generation fails.
 */
/datum/ai_behavior/npc_ship/patrol
	action_cooldown = 8 SECONDS  // 1/4 speed when out of combat

/datum/ai_behavior/npc_ship/patrol/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	if(!ship)
		return AI_BEHAVIOR_DELAY
	if(ship.state != OVERMAP_SHIP_FLYING)
		return AI_BEHAVIOR_DELAY
	// Must have working engines with fuel
	if(!ship.can_thrust())
		return AI_BEHAVIOR_DELAY

	var/turf/our_loc = get_turf(ship)
	if(!our_loc)
		return AI_BEHAVIOR_DELAY

	var/datum/overmap_zone/spawn_zone = controller.blackboard[BB_NPC_SPAWN_ZONE]

	// === CIRCUIT MANAGEMENT ===
	var/list/circuit = controller.blackboard[BB_NPC_PATROL_CIRCUIT]
	if(!length(circuit))
		circuit = generate_patrol_circuit(spawn_zone, NPC_SHIP_ORBIT_VARIANCE, NPC_SHIP_CIRCUIT_WAYPOINTS)
		if(!length(circuit))
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

	// Check if we've reached the circuit waypoint
	if(our_loc == target_waypoint)
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

	var/needs_repath = !length(path) || path_index > length(path)

	if(needs_repath)
		var/list/new_path = overmap_astar(our_loc, target_waypoint, spawn_zone)
		if(length(new_path))
			controller.blackboard[BB_NPC_CURRENT_PATH] = new_path
			controller.blackboard[BB_NPC_PATH_INDEX] = 1
			path = new_path
			path_index = 1
		else
			// No path found - skip this waypoint
			controller.set_blackboard_key(BB_NPC_CIRCUIT_INDEX, circuit_index + 1)
			return AI_BEHAVIOR_DELAY

	// === DISCRETE MOVEMENT ===
	if(length(path) && path_index <= length(path))
		var/turf/next_tile = path[path_index]

		// Skip if already on this tile
		if(our_loc == next_tile)
			path_index++
			controller.set_blackboard_key(BB_NPC_PATH_INDEX, path_index)
			if(path_index > length(path))
				controller.blackboard[BB_NPC_CURRENT_PATH] = null
				return AI_BEHAVIOR_DELAY
			next_tile = path[path_index]

		// A half-wrecked thruster bank buys fewer tiles (see consume_thrust_step)
		if(!ship.consume_thrust_step())
			return AI_BEHAVIOR_DELAY

		// Move directly to next tile (no momentum)
		var/move_dir = get_dir(ship, next_tile)
		if(move_dir)
			ship.dir = move_dir
		ship.forceMove(next_tile)
		controller.set_blackboard_key(BB_NPC_PATH_INDEX, path_index + 1)

	return AI_BEHAVIOR_DELAY


// ========== ROAMING BEHAVIOR ==========

/**
 * Fallback behavior when circuit patrol is impossible.
 * Picks random directions and wanders the zone.
 * Discrete movement: moves one tile per tick (no momentum/physics).
 */
/datum/ai_behavior/npc_ship/roaming
	action_cooldown = 8 SECONDS  // 1/4 speed when out of combat

/datum/ai_behavior/npc_ship/roaming/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	if(!ship || ship.state != OVERMAP_SHIP_FLYING)
		return AI_BEHAVIOR_DELAY
	if(!ship.can_thrust())
		return AI_BEHAVIOR_DELAY

	var/turf/our_loc = get_turf(ship)
	if(!our_loc)
		return AI_BEHAVIOR_DELAY

	var/datum/overmap_zone/spawn_zone = controller.blackboard[BB_NPC_SPAWN_ZONE]

	// Pick a random safe direction and move one tile
	var/roaming_dir = pick_random_safe_direction(our_loc, spawn_zone)
	if(roaming_dir)
		var/turf/next_tile = get_step(our_loc, roaming_dir)
		if(next_tile && ship.consume_thrust_step())
			ship.dir = roaming_dir
			ship.forceMove(next_tile)

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
 * Discrete movement: moves one tile per tick (no momentum/physics).
 */
/datum/ai_behavior/npc_ship/return_to_route
	action_cooldown = 8 SECONDS  // 1/4 speed when out of combat

/datum/ai_behavior/npc_ship/return_to_route/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	if(!ship || ship.state != OVERMAP_SHIP_FLYING)
		return AI_BEHAVIOR_DELAY
	if(!ship.can_thrust())
		return AI_BEHAVIOR_DELAY

	var/turf/our_loc = get_turf(ship)
	if(!our_loc)
		return AI_BEHAVIOR_DELAY

	var/datum/overmap_zone/spawn_zone = controller.blackboard[BB_NPC_SPAWN_ZONE]

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

	// Check if we've reached the waypoint
	if(our_loc == target_waypoint)
		controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_PATROL)
		controller.blackboard[BB_NPC_CURRENT_PATH] = null
		controller.set_blackboard_key(BB_NPC_PATH_INDEX, 1)
		controller.set_blackboard_key(BB_NPC_HAD_TARGET, FALSE)
		return AI_BEHAVIOR_DELAY

	// === PATH MANAGEMENT ===
	var/list/path = controller.blackboard[BB_NPC_CURRENT_PATH]
	var/path_index = controller.blackboard[BB_NPC_PATH_INDEX] || 1

	var/needs_repath = !length(path) || path_index > length(path)

	if(needs_repath)
		var/list/new_path = overmap_astar(our_loc, target_waypoint, spawn_zone)
		if(length(new_path))
			controller.blackboard[BB_NPC_CURRENT_PATH] = new_path
			controller.blackboard[BB_NPC_PATH_INDEX] = 1
			path = new_path
			path_index = 1
		else
			controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_ROAMING)
			return AI_BEHAVIOR_DELAY

	// === DISCRETE MOVEMENT ===
	if(length(path) && path_index <= length(path))
		var/turf/next_tile = path[path_index]

		if(our_loc == next_tile)
			path_index++
			controller.set_blackboard_key(BB_NPC_PATH_INDEX, path_index)
			if(path_index > length(path))
				controller.blackboard[BB_NPC_CURRENT_PATH] = null
				return AI_BEHAVIOR_DELAY
			next_tile = path[path_index]

		if(!ship.consume_thrust_step())
			return AI_BEHAVIOR_DELAY

		var/move_dir = get_dir(ship, next_tile)
		if(move_dir)
			ship.dir = move_dir
		ship.forceMove(next_tile)
		controller.set_blackboard_key(BB_NPC_PATH_INDEX, path_index + 1)

	return AI_BEHAVIOR_DELAY

// ========== CHASE BEHAVIOR ==========

/**
 * Chases a target ship when it enters range.
 * Discrete movement: moves one tile per tick toward target.
 * Stops chasing at zone boundaries or when target escapes.
 *
 * IMPORTANT: This behavior INTENTIONALLY IGNORES obstacles!
 * Players can bait NPC ships into meteor storms, ion storms, etc.
 * This is a core gameplay mechanic - don't add obstacle avoidance here!
 */
/datum/ai_behavior/npc_ship/chase
	action_cooldown = 2 SECONDS  // 1/2 speed when in combat

/datum/ai_behavior/npc_ship/chase/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	if(!ship || ship.state != OVERMAP_SHIP_FLYING)
		return AI_BEHAVIOR_DELAY
	if(!ship.can_thrust())
		return AI_BEHAVIOR_DELAY

	var/obj/structure/overmap/ship/target = controller.get_target()

	// No target - wait for subtree to switch to return_to_route
	if(!target || QDELETED(target))
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
		return AI_BEHAVIOR_DELAY

	// Check if we're already adjacent to target (within combat range)
	if(get_dist(ship, target) <= 1)
		return AI_BEHAVIOR_DELAY

	// Move toward target (ignoring obstacles - players can bait us into hazards)
	var/direction = get_dir(ship, target)
	if(direction)
		// Check if moving this direction would leave spawn zone
		if(spawn_zone && !direction_stays_in_zone(our_loc, direction, spawn_zone))
			return AI_BEHAVIOR_DELAY

		var/turf/next_tile = get_step(our_loc, direction)
		if(next_tile && ship.consume_thrust_step())
			ship.dir = direction
			ship.forceMove(next_tile)

	return AI_BEHAVIOR_DELAY

// ========== RETURN TO ZONE BEHAVIOR ==========

/**
 * Emergency behavior when ship is outside its spawn zone.
 * With discrete movement this should rarely trigger, but kept as fallback.
 * Moves directly toward zone middle.
 */
/datum/ai_behavior/npc_ship/return_to_zone
	action_cooldown = 8 SECONDS  // 1/4 speed when out of combat

/datum/ai_behavior/npc_ship/return_to_zone/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	if(!ship || ship.state != OVERMAP_SHIP_FLYING)
		return AI_BEHAVIOR_DELAY
	if(!ship.can_thrust())
		return AI_BEHAVIOR_DELAY

	var/turf/our_loc = get_turf(ship)
	var/datum/overmap_zone/spawn_zone = controller.blackboard[BB_NPC_SPAWN_ZONE]

	if(!our_loc || !spawn_zone)
		return AI_BEHAVIOR_DELAY

	// Check if we're back in our zone
	var/current_zone = SSovermap_zones.get_zone(our_loc)
	if(current_zone == spawn_zone)
		return AI_BEHAVIOR_DELAY

	// Calculate target point in the MIDDLE of our spawn zone
	var/center_x = SSovermap_zones.center_x
	var/center_y = SSovermap_zones.center_y
	var/max_radius = SSovermap_zones.max_radius

	// Get target radius based on zone type
	var/target_radius
	switch(spawn_zone.zone_type)
		if(ZONE_RED)
			target_radius = max_radius * 0.17
		if(ZONE_YELLOW)
			target_radius = max_radius * 0.5
		if(ZONE_GREEN)
			target_radius = max_radius * 0.8
		else
			target_radius = 0

	// Calculate direction from center to ship, then find point at target_radius
	var/dx = our_loc.x - center_x
	var/dy = our_loc.y - center_y
	var/dist = sqrt(dx * dx + dy * dy)

	var/target_x = center_x
	var/target_y = center_y
	if(dist > 0 && target_radius > 0)
		target_x = center_x + (dx / dist) * target_radius
		target_y = center_y + (dy / dist) * target_radius

	var/turf/target = locate(round(target_x), round(target_y), OVERMAP_Z_LEVEL)
	if(target)
		var/direction = get_dir(ship, target)
		if(direction)
			var/turf/next_tile = get_step(our_loc, direction)
			if(next_tile && ship.consume_thrust_step())
				ship.dir = direction
				ship.forceMove(next_tile)

	return AI_BEHAVIOR_DELAY

// ========== RETREAT BEHAVIOR ==========

/**
 * Retreat behavior when weapons are destroyed or siphon goal reached.
 * Moves away from the last known threat, staying within spawn zone.
 * Uses fast movement (same as chase) since the ship is urgently fleeing.
 */
/datum/ai_behavior/npc_ship/retreat
	action_cooldown = 2 SECONDS  // Same speed as chase - urgently fleeing

/datum/ai_behavior/npc_ship/retreat/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	if(!ship || ship.state != OVERMAP_SHIP_FLYING)
		return AI_BEHAVIOR_DELAY
	if(!ship.can_thrust())
		return AI_BEHAVIOR_DELAY

	var/turf/our_loc = get_turf(ship)
	if(!our_loc)
		return AI_BEHAVIOR_DELAY

	var/datum/overmap_zone/spawn_zone = controller.blackboard[BB_NPC_SPAWN_ZONE]

	// Get the last target we were fighting (to flee from their direction)
	var/obj/structure/overmap/ship/threat = controller.get_target()
	// Fallback to BB_NPC_LAST_TARGET if current target was cleared
	if(!threat || QDELETED(threat))
		var/datum/weakref/last_target_ref = controller.blackboard[BB_NPC_LAST_TARGET]
		threat = last_target_ref?.resolve()
	var/flee_dir

	if(threat && !QDELETED(threat))
		// Flee in opposite direction from threat
		var/threat_dir = get_dir(ship, threat)
		flee_dir = REVERSE_DIR(threat_dir)
	else
		// No known threat - pick a random safe direction
		flee_dir = pick(GLOB.cardinals)

	// Get a safe direction that avoids obstacles and stays in zone
	var/safe_dir = get_zone_safe_direction(ship, flee_dir, spawn_zone)

	// get_zone_safe_direction's fallback list is static and knows nothing about the
	// threat, so when the direct escape vector is unusable - which is constant for a
	// ship pressed against its band boundary - it can hand back a step TOWARD the
	// chaser. Round 4's wedged pirates spent hours shuffling along the yellow boundary
	// beside their target this way. Re-rank: of the legal candidates, step wherever
	// opens the most distance from the threat.
	if(safe_dir && safe_dir != flee_dir && threat && !QDELETED(threat))
		var/turf/threat_loc = get_turf(threat)
		if(threat_loc)
			var/best_dist = -1
			for(var/candidate_dir in GLOB.alldirs)
				if(direction_has_obstacle(our_loc, candidate_dir))
					continue
				if(!direction_stays_in_zone(our_loc, candidate_dir, spawn_zone))
					continue
				var/turf/candidate_turf = get_step(our_loc, candidate_dir)
				if(!candidate_turf)
					continue
				var/candidate_dist = get_dist(candidate_turf, threat_loc)
				if(candidate_dist > best_dist)
					best_dist = candidate_dist
					safe_dir = candidate_dir

	if(!safe_dir)
		return AI_BEHAVIOR_DELAY

	var/turf/next_tile = get_step(our_loc, safe_dir)
	if(next_tile && ship.consume_thrust_step())
		ship.dir = safe_dir
		ship.forceMove(next_tile)

	return AI_BEHAVIOR_DELAY

// ========== UNDOCK RECOVERY ==========

/**
 * Takes a parked NPC ship back to open flight.
 *
 * Both AI subtrees stand down whenever the ship isn't OVERMAP_SHIP_FLYING, and nothing
 * else in the game ever undocks an NPC hull - so before this behavior existed, one
 * player force-dock (or a crash-land) was a permanent kill switch for that ship's AI:
 * the hull sat berthed with live crew for the rest of the round. The movement subtree
 * queues this whenever the ship is sitting in OVERMAP_SHIP_IDLE.
 *
 * Holds before leaving:
 * - the park must be at least NPC_PARKED_RECOVERY_DELAY old, so the pirate doesn't
 *   launch straight back out into the face of whoever force-docked it (undock()'s own
 *   force-dock/interdiction lockouts still apply on top of this);
 * - no living player aboard our own hull - they are mid-raid, and undocking under
 *   them would kidnap the boarding party;
 * - no player ship docked onto us or berthed at the same site - the encounter is
 *   still in progress, leave the hull where they pinned it.
 *
 * Never recovers a crashed, abandoned, claimed or crew-dead hull. Those are wrecks
 * and prizes for the players, not pilots.
 */
/datum/ai_behavior/npc_ship/undock_recovery
	action_cooldown = 15 SECONDS

/datum/ai_behavior/npc_ship/undock_recovery/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	if(!ship)
		return AI_BEHAVIOR_DELAY

	// Only recover a ship that is actually sitting berthed. Flying again means we're
	// done; DOCKING/UNDOCKING/ACTING are transitional and covered elsewhere.
	if(ship.state != OVERMAP_SHIP_IDLE)
		return AI_BEHAVIOR_DELAY

	// Wrecks and prizes stay where they are
	if(ship.player_controlled || ship.abandoned || ship.has_crash_landed)
		return AI_BEHAVIOR_DELAY

	// A hull with no living crew aboard is a derelict-in-waiting (the abandonment
	// timer owns it now), not something that should fly itself away from the players
	// who earned it
	if(ship.count_live_crew_aboard() < 1)
		return AI_BEHAVIOR_DELAY

	// Wait out the parked delay before even thinking about leaving
	var/parked_since = controller.blackboard[BB_NPC_PARKED_SINCE]
	if(!parked_since || world.time - parked_since < NPC_PARKED_RECOVERY_DELAY)
		return AI_BEHAVIOR_DELAY

	// Hold while any living player is aboard our hull - undocking now would carry
	// their boarding party off with us
	if(controller.count_living_crew(ship) > 0)
		return AI_BEHAVIOR_DELAY

	// Hold while a player ship is docked onto us or shares our berth site - the
	// encounter that parked us is still going on
	for(var/obj/structure/overmap/ship/other as anything in SSovermap.simulated_ships)
		if(other == ship || QDELETED(other))
			continue
		if(istype(other, /obj/structure/overmap/ship/npc))
			var/obj/structure/overmap/ship/npc/other_npc = other
			if(!other_npc.player_controlled)
				continue
		if(other.docked == ship || (ship.docked && other.docked == ship.docked))
			return AI_BEHAVIOR_DELAY

	// Clear to leave. undock() runs its own cooldown/lockout checks and returns a
	// refusal string while any still apply - in that case just retry next tick,
	// quietly. It also self-heals drifted bookkeeping (IDLE while standing on a
	// turf) via check_loc(), which is a recovery in itself.
	var/berth = ship.docked ? "[ship.docked]" : "unknown berth"
	var/refusal = ship.undock()
	if(isnull(refusal))
		log_shuttle("NPC_SHIP: [ship.name] AI undocking from [berth] to resume patrol ([round((world.time - parked_since) / (1 MINUTES), 0.1)] minutes parked)")

	return AI_BEHAVIOR_DELAY
