/**
 * NPC Ship Combat Subtree
 *
 * This planning subtree handles all combat decision-making for NPC ships.
 * It queues behaviors based on the current combat state:
 * - IDLE: Just scan for threats
 * - SCANNING: Scanning target for wealth (yellow zone pirates)
 * - HAILING: Hailing target, waiting for them to answer (20 sec grace period)
 * - ENGAGING: Acquiring weapon lock on target
 * - COMBAT: Actively firing weapons and using interdictor
 * - SIPHONING: Yellow zone - interdict + siphon only (no weapons/boarding)
 * - RETREATING: All weapons destroyed, trying to escape
 * - NEGOTIATING: In active negotiation with target, combat paused
 *
 * Phased Boarding Combat States:
 * - BOARDING: Active wave of boarders on target ship
 * - BOARDING_COOLDOWN: 60-second break between waves
 * - BOSS_PHASE: Boss has been spawned, awaiting outcome
 * - DISABLED: Ship disabled after boss killed, player can board
 * - DISENGAGING: Pirates won (all player crew dead), leaving area
 */
/datum/ai_planning_subtree/npc_ship_combat

/datum/ai_planning_subtree/npc_ship_combat/SelectBehaviors(datum/ai_controller/npc_ship/controller, seconds_per_tick)
	if(!istype(controller))
		return

	// Don't run combat AI when the ship isn't flying (docked, crashed, etc.)
	var/obj/structure/overmap/ship/npc/ship = controller.get_ship()
	if(!ship || ship.state != OVERMAP_SHIP_FLYING)
		return

	var/combat_state = controller.get_combat_state()

	// Negotiating ships don't do any combat - they just wait for negotiation outcome
	if(combat_state == NPC_COMBAT_NEGOTIATING)
		// No combat behaviors - negotiation datum handles timeout and resolution
		return

	// Hailing ships wait for player to answer - don't scan for other threats
	if(combat_state == NPC_COMBAT_HAILING)
		controller.queue_behavior(/datum/ai_behavior/npc_ship/hailing)
		// Still check disengage in case target escapes
		controller.queue_behavior(/datum/ai_behavior/npc_ship/check_disengage)
		return

	// Siphoning ships interdict + siphon only (yellow zone economic threat, no weapons/boarding)
	if(combat_state == NPC_COMBAT_SIPHONING)
		controller.queue_behavior(/datum/ai_behavior/npc_ship/use_interdictor)
		controller.queue_behavior(/datum/ai_behavior/npc_ship/activate_siphon)
		controller.queue_behavior(/datum/ai_behavior/npc_ship/check_disengage)
		return

	// Retreating ships don't scan for threats or fight - they just try to escape
	if(combat_state == NPC_COMBAT_RETREATING)
		controller.queue_behavior(/datum/ai_behavior/npc_ship/retreat_escape)
		return

	// ========== BOARDING PHASE STATES ==========

	// Active boarding wave - monitor the wave
	if(combat_state == NPC_COMBAT_BOARDING)
		controller.queue_behavior(/datum/ai_behavior/npc_ship/use_interdictor)
		controller.queue_behavior(/datum/ai_behavior/npc_ship/boarding_wave_monitor)
		return

	// Cooldown between waves - wait for timer
	if(combat_state == NPC_COMBAT_BOARDING_COOLDOWN)
		controller.queue_behavior(/datum/ai_behavior/npc_ship/use_interdictor)
		controller.queue_behavior(/datum/ai_behavior/npc_ship/boarding_cooldown_monitor)
		return

	// Boss phase - wait for boss to be killed
	if(combat_state == NPC_COMBAT_BOSS_PHASE)
		controller.queue_behavior(/datum/ai_behavior/npc_ship/use_interdictor)
		controller.queue_behavior(/datum/ai_behavior/npc_ship/boss_phase_monitor)
		return

	// Ship disabled - do nothing, wait for players to board
	if(combat_state == NPC_COMBAT_DISABLED)
		controller.queue_behavior(/datum/ai_behavior/npc_ship/disabled)
		return

	// Disengaging after pirate victory - leaving the area
	if(combat_state == NPC_COMBAT_DISENGAGING)
		controller.queue_behavior(/datum/ai_behavior/npc_ship/disengage)
		return

	// Always scan for threats first (unless in special states)
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
			// ACTION PRIORITY SYSTEM: Pick ONE offensive action per tick instead of all three
			// This prevents pirates from overwhelming players with simultaneous attacks
			var/chosen_action = choose_combat_action(controller)
			switch(chosen_action)
				if(NPC_ACTION_FIRE_WEAPONS)
					controller.queue_behavior(/datum/ai_behavior/npc_ship/fire_weapons)
				if(NPC_ACTION_FIRE_BOARDING_PODS)
					controller.queue_behavior(/datum/ai_behavior/npc_ship/fire_boarding_pods)
				if(NPC_ACTION_USE_INTERDICTOR)
					controller.queue_behavior(/datum/ai_behavior/npc_ship/use_interdictor)
				if(NPC_ACTION_ACTIVATE_SIPHON)
					controller.queue_behavior(/datum/ai_behavior/npc_ship/activate_siphon)
			// Always check weapons status
			controller.queue_behavior(/datum/ai_behavior/npc_ship/check_weapons)

	// Always check if we should disengage (target out of range)
	controller.queue_behavior(/datum/ai_behavior/npc_ship/check_disengage)

/**
 * Chooses which combat action to take this tick.
 * Implements action priority with commitment delays to prevent overwhelming players.
 *
 * Priority logic:
 * 1. If we just started interdiction/siphon, we're "committed" and must wait before other actions
 * 2. Otherwise, use weighted random selection favoring weapons fire
 * 3. Boarding pods are heavily favored when target shields are down (reduces missile reliance)
 *
 * Returns: NPC_ACTION_FIRE_WEAPONS, NPC_ACTION_FIRE_BOARDING_PODS, NPC_ACTION_USE_INTERDICTOR, or NPC_ACTION_ACTIVATE_SIPHON
 */
/datum/ai_planning_subtree/npc_ship_combat/proc/choose_combat_action(datum/ai_controller/npc_ship/controller)
	var/obj/structure/overmap/ship/npc/pirate/ship = controller.get_ship()
	var/obj/structure/overmap/ship/target = controller.get_target()

	// Check commitment delays - if we recently started interdiction or siphon, we can't do other actions
	var/interdictor_start = controller.blackboard[BB_NPC_INTERDICTOR_START_TIME]
	var/siphon_start = controller.blackboard[BB_NPC_SIPHON_START_TIME]

	var/interdictor_committed = interdictor_start && (world.time - interdictor_start) < NPC_INTERDICTOR_COMMITMENT_DELAY
	var/siphon_committed = siphon_start && (world.time - siphon_start) < NPC_SIPHON_COMMITMENT_DELAY

	// If committed to interdiction, can only continue interdiction (or nothing if target already interdicted)
	if(interdictor_committed)
		return NPC_ACTION_USE_INTERDICTOR

	// If committed to siphon, can only continue siphon
	if(siphon_committed)
		return NPC_ACTION_ACTIVATE_SIPHON

	// Build list of available actions with weights
	var/list/action_weights = list()

	// Check if target shields are down (critical for boarding pod decision)
	var/target_shields_down = !target?.shields_active || target.shield_health <= 0

	// Check if boarding pods are available (ship has them enabled, cooldown ready)
	var/boarding_pods_available = FALSE
	if(istype(ship) && ship.boarding_pods_enabled && target_shields_down)
		if(COOLDOWN_FINISHED(ship, boarding_pod_cooldown))
			boarding_pods_available = TRUE

	// If boarding pods are available (shields down, off cooldown), heavily favor them
	// This reduces reliance on missiles and adds lethality via boarders
	if(boarding_pods_available)
		// Boarding pods get high weight when shields are down (weight: 50)
		action_weights[NPC_ACTION_FIRE_BOARDING_PODS] = 50
		// Reduce weapons weight when pods available (weight: 30 instead of 60)
		action_weights[NPC_ACTION_FIRE_WEAPONS] = 30
	else
		// Weapons fire is always available (weight: 60)
		action_weights[NPC_ACTION_FIRE_WEAPONS] = 60

	// Interdictor is available if target isn't already interdicted (weight: 25)
	if(target && !target.is_interdicted)
		action_weights[NPC_ACTION_USE_INTERDICTOR] = 25

	// Siphon is available if ship has siphon goals (weight: 15)
	if(ship?.siphon_goal_percent > 0)
		action_weights[NPC_ACTION_ACTIVATE_SIPHON] = 15

	// If only weapons available, just return that
	if(length(action_weights) == 1)
		for(var/action in action_weights)
			return action

	// Weighted random selection
	var/total_weight = 0
	for(var/action in action_weights)
		total_weight += action_weights[action]

	var/roll = rand(1, total_weight)
	var/cumulative = 0
	for(var/action in action_weights)
		cumulative += action_weights[action]
		if(roll <= cumulative)
			return action

	// Fallback to weapons
	return NPC_ACTION_FIRE_WEAPONS
