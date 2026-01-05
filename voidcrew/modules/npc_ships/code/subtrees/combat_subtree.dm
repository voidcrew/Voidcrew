/**
 * NPC Ship Combat Subtree
 *
 * This planning subtree handles all combat decision-making for NPC ships.
 * It queues behaviors based on the current combat state:
 * - IDLE: Just scan for threats
 * - ENGAGING: Acquiring weapon lock on target
 * - COMBAT: Actively firing weapons and using interdictor
 */
/datum/ai_planning_subtree/npc_ship_combat

/datum/ai_planning_subtree/npc_ship_combat/SelectBehaviors(datum/ai_controller/npc_ship/controller, seconds_per_tick)
	// Safety check
	if(!istype(controller))
		log_shuttle("NPC SHIP AI: SelectBehaviors - invalid controller type!")
		return

	// Debug: log that we're running (throttled)
	var/static/next_log_time = 0
	if(world.time >= next_log_time)
		log_shuttle("NPC SHIP AI: SelectBehaviors running for [controller.pawn], state=[controller.get_combat_state()]")
		next_log_time = world.time + 10 SECONDS // Log every 10 seconds max

	// Always scan for threats first
	controller.queue_behavior(/datum/ai_behavior/npc_ship/scan_threats)

	// Get current combat state
	var/combat_state = controller.get_combat_state()
	log_shuttle("NPC SHIP AI: SelectBehaviors switch check - state='[combat_state]', IDLE='[NPC_COMBAT_IDLE]', ENGAGING='[NPC_COMBAT_ENGAGING]'")

	switch(combat_state)
		if(NPC_COMBAT_IDLE)
			// Just scanning, nothing else to do
			log_shuttle("NPC SHIP AI: State is IDLE, returning")
			return

		if(NPC_COMBAT_ENGAGING)
			// Working on acquiring weapon lock
			log_shuttle("NPC SHIP AI: Queueing acquire_lock for [controller.pawn]")
			controller.queue_behavior(/datum/ai_behavior/npc_ship/acquire_lock)

		if(NPC_COMBAT_COMBAT)
			// In active combat - fire weapons and use interdictor
			log_shuttle("NPC SHIP AI: Queueing fire_weapons for [controller.pawn]")
			controller.queue_behavior(/datum/ai_behavior/npc_ship/fire_weapons)
			controller.queue_behavior(/datum/ai_behavior/npc_ship/use_interdictor)

	// Always check if we should disengage (target out of range)
	controller.queue_behavior(/datum/ai_behavior/npc_ship/check_disengage)
