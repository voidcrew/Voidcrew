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
	if(!istype(controller))
		log_shuttle("NPC COMBAT SUBTREE: Invalid controller type")
		return

	var/obj/structure/overmap/ship/npc/ship = controller.pawn
	var/combat_state = controller.get_combat_state()
	var/obj/structure/overmap/ship/target = controller.get_target()

	log_shuttle("NPC COMBAT SUBTREE: ship=[ship] state=[combat_state] target=[target]")

	// Always scan for threats first
	controller.queue_behavior(/datum/ai_behavior/npc_ship/scan_threats)

	switch(combat_state)
		if(NPC_COMBAT_IDLE)
			log_shuttle("NPC COMBAT: IDLE - just scanning")
			return

		if(NPC_COMBAT_ENGAGING)
			log_shuttle("NPC COMBAT: ENGAGING - queueing acquire_lock")
			controller.queue_behavior(/datum/ai_behavior/npc_ship/acquire_lock)

		if(NPC_COMBAT_COMBAT)
			log_shuttle("NPC COMBAT: COMBAT - queueing fire_weapons and use_interdictor")
			controller.queue_behavior(/datum/ai_behavior/npc_ship/fire_weapons)
			controller.queue_behavior(/datum/ai_behavior/npc_ship/use_interdictor)

	// Always check if we should disengage (target out of range)
	controller.queue_behavior(/datum/ai_behavior/npc_ship/check_disengage)
