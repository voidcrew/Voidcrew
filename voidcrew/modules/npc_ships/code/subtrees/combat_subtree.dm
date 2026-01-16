/**
 * NPC Ship Combat Subtree
 *
 * This planning subtree handles all combat decision-making for NPC ships.
 * It queues behaviors based on the current combat state:
 * - IDLE: Just scan for threats
 * - SCANNING: Scanning target for wealth (yellow zone pirates)
 * - ENGAGING: Acquiring weapon lock on target
 * - COMBAT: Actively firing weapons and using interdictor
 * - RETREATING: All weapons destroyed, trying to escape
 * - NEGOTIATING: In active negotiation with target, combat paused
 */
/datum/ai_planning_subtree/npc_ship_combat

/datum/ai_planning_subtree/npc_ship_combat/SelectBehaviors(datum/ai_controller/npc_ship/controller, seconds_per_tick)
	if(!istype(controller))
		return

	var/combat_state = controller.get_combat_state()

	// Negotiating ships don't do any combat - they just wait for negotiation outcome
	if(combat_state == NPC_COMBAT_NEGOTIATING)
		// No combat behaviors - negotiation datum handles timeout and resolution
		return

	// Retreating ships don't scan for threats or fight - they just try to escape
	if(combat_state == NPC_COMBAT_RETREATING)
		controller.queue_behavior(/datum/ai_behavior/npc_ship/retreat_escape)
		return

	// Always scan for threats first (unless retreating or scanning)
	if(combat_state != NPC_COMBAT_SCANNING)
		controller.queue_behavior(/datum/ai_behavior/npc_ship/scan_threats)

	switch(combat_state)
		if(NPC_COMBAT_IDLE)
			return

		if(NPC_COMBAT_SCANNING)
			// Scanning target for wealth before engaging
			controller.queue_behavior(/datum/ai_behavior/npc_ship/scan_wealth)
			// Still check disengage in case target escapes during scan
			controller.queue_behavior(/datum/ai_behavior/npc_ship/check_disengage)
			return

		if(NPC_COMBAT_ENGAGING)
			controller.queue_behavior(/datum/ai_behavior/npc_ship/acquire_lock)
			controller.queue_behavior(/datum/ai_behavior/npc_ship/check_weapons)

		if(NPC_COMBAT_COMBAT)
			controller.queue_behavior(/datum/ai_behavior/npc_ship/fire_weapons)
			controller.queue_behavior(/datum/ai_behavior/npc_ship/use_interdictor)
			controller.queue_behavior(/datum/ai_behavior/npc_ship/activate_siphon)
			controller.queue_behavior(/datum/ai_behavior/npc_ship/check_weapons)

	// Always check if we should disengage (target out of range)
	controller.queue_behavior(/datum/ai_behavior/npc_ship/check_disengage)
