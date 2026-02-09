/**
 * NPC Ship Movement Subtree
 *
 * This planning subtree handles movement decisions for NPC ships.
 * Uses discrete movement (forceMove) - no momentum/physics.
 *
 * Movement modes:
 * - IDLE: No active movement, sit still
 * - PATROL: Follow circular circuit around zone (uses A* pathfinding)
 * - CHASE: Pursue target (used internally when target exists)
 * - RETURN_TO_ROUTE: Path back to patrol circuit after combat
 * - ROAMING: Fallback when circuit generation fails
 * - RETREAT: Fleeing after all weapons destroyed
 */
/datum/ai_planning_subtree/npc_ship_movement

/datum/ai_planning_subtree/npc_ship_movement/SelectBehaviors(datum/ai_controller/npc_ship/controller, seconds_per_tick)
	if(!istype(controller))
		return

	var/obj/structure/overmap/ship/npc/ship = controller.pawn

	// Don't run movement AI when the ship isn't flying (docked, crashed, etc.)
	if(!ship || ship.state != OVERMAP_SHIP_FLYING)
		return

	var/movement_mode = controller.blackboard[BB_NPC_MOVEMENT_MODE] || NPC_MOVEMENT_PATROL
	var/obj/structure/overmap/ship/target = controller.get_target()

	var/spawn_zone = controller.blackboard[BB_NPC_SPAWN_ZONE]

	// PRIORITY CHECK: Retreat mode overrides everything - keep fleeing
	if(movement_mode == NPC_MOVEMENT_RETREAT)
		controller.queue_behavior(/datum/ai_behavior/npc_ship/retreat)
		return

	// PRIORITY CHECK: If we're outside our spawn zone, we need to get back
	if(spawn_zone && ship)
		var/turf/our_turf = get_turf(ship)
		if(our_turf)
			var/current_zone = SSovermap_zones.get_zone(our_turf)
			if(current_zone != spawn_zone)
				// Clear any target - we can't fight outside our zone
				if(target)
					controller.clear_target()
				controller.blackboard[BB_NPC_HAD_TARGET] = FALSE
				controller.queue_behavior(/datum/ai_behavior/npc_ship/return_to_zone)
				return

	// If we have a combat target, ALWAYS chase it
	if(target && !QDELETED(target))
		// Mark that we're in combat so we know to return to route after
		controller.set_blackboard_key(BB_NPC_HAD_TARGET, TRUE)
		controller.queue_behavior(/datum/ai_behavior/npc_ship/chase)
		return

	// No target - check if we just lost one (need to return to route)
	var/had_target = controller.blackboard[BB_NPC_HAD_TARGET]
	if(had_target)
		controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_RETURN_TO_ROUTE)
		controller.set_blackboard_key(BB_NPC_HAD_TARGET, FALSE)
		// Clear movement state so return_to_route starts fresh
		controller.blackboard[BB_NPC_CURRENT_PATH] = null
		// Find nearest waypoint on circuit
		var/list/circuit = controller.blackboard[BB_NPC_PATROL_CIRCUIT]
		if(length(circuit))
			var/turf/our_loc = get_turf(ship)
			var/nearest = find_nearest_circuit_waypoint(our_loc, circuit)
			controller.set_blackboard_key(BB_NPC_CIRCUIT_INDEX, nearest)

	// Use movement mode to decide behavior
	switch(movement_mode)
		if(NPC_MOVEMENT_IDLE)
			return

		if(NPC_MOVEMENT_PATROL)
			controller.queue_behavior(/datum/ai_behavior/npc_ship/patrol)

		if(NPC_MOVEMENT_RETURN_TO_ROUTE)
			controller.queue_behavior(/datum/ai_behavior/npc_ship/return_to_route)

		if(NPC_MOVEMENT_ROAMING)
			controller.queue_behavior(/datum/ai_behavior/npc_ship/roaming)

		if(NPC_MOVEMENT_CHASE)
			// No target but in chase mode - switch to patrol
			controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_PATROL)
			controller.queue_behavior(/datum/ai_behavior/npc_ship/patrol)
