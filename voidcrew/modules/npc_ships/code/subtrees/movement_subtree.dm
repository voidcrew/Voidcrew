/**
 * NPC Ship Movement Subtree
 *
 * This planning subtree handles movement decisions for NPC ships.
 *
 * IMPORTANT: If there's an active combat target, we ALWAYS chase it
 * regardless of the movement mode. Movement mode only affects what
 * happens when there's no target.
 *
 * Movement modes (when no target):
 * - IDLE: No active movement, sit still
 * - ORBIT: Circle around a celestial object
 * - PATROL: Travel between waypoints in red zone
 * - CHASE: Return to home position and wait
 */
/datum/ai_planning_subtree/npc_ship_movement

/datum/ai_planning_subtree/npc_ship_movement/SelectBehaviors(datum/ai_controller/npc_ship/controller, seconds_per_tick)
	if(!istype(controller))
		log_shuttle("NPC MOVE SUBTREE: Invalid controller type")
		return

	var/movement_mode = controller.blackboard[BB_NPC_MOVEMENT_MODE] || NPC_MOVEMENT_PATROL
	var/obj/structure/overmap/ship/target = controller.get_target()
	var/obj/structure/overmap/ship/npc/ship = controller.pawn

	log_shuttle("NPC MOVE SUBTREE: ship=[ship] mode=[movement_mode] target=[target] state=[ship?.state]")

	// If we have a combat target, ALWAYS chase it regardless of movement mode
	if(target && !QDELETED(target))
		log_shuttle("NPC MOVE: Queueing CHASE - have target [target]")
		controller.queue_behavior(/datum/ai_behavior/npc_ship/chase)
		return

	// No target - use movement mode to decide what to do
	switch(movement_mode)
		if(NPC_MOVEMENT_IDLE)
			log_shuttle("NPC MOVE: IDLE mode - no behavior")
			return

		if(NPC_MOVEMENT_ORBIT)
			log_shuttle("NPC MOVE: Queueing ORBIT")
			controller.queue_behavior(/datum/ai_behavior/npc_ship/orbit)

		if(NPC_MOVEMENT_PATROL)
			log_shuttle("NPC MOVE: Queueing PATROL")
			controller.queue_behavior(/datum/ai_behavior/npc_ship/patrol)

		if(NPC_MOVEMENT_CHASE)
			log_shuttle("NPC MOVE: Queueing RETURN_HOME (chase mode, no target)")
			controller.queue_behavior(/datum/ai_behavior/npc_ship/return_home)
