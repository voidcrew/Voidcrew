/**
 * NPC Ship Combat Subtree
 *
 * VOIDCREW: fork-specific combat AI for NPC ships flying the overmap.
 *
 * This is a state machine, not a priority cascade. The ship's combat state lives on the
 * controller (get_combat_state()) and exactly one branch of the tree matches it at a time:
 * - IDLE: Just scan for threats
 * - SCANNING: Scanning target for wealth (yellow zone pirates)
 * - HAILING: Hailing target, waiting for them to answer (20 sec grace period)
 * - ENGAGING: Acquiring weapon lock on target
 * - COMBAT: Actively firing weapons and using interdictor
 * - SIPHONING: Yellow zone - interdict + siphon only (no weapons/boarding).
 *              Reached only after a hail the crew ignored, refused or stalled out.
 * - RETREATING: All weapons destroyed, trying to escape
 * - NEGOTIATING: In active negotiation with target, combat paused
 *
 * Phased Boarding Combat States:
 * - BOARDING: Active wave of boarders on target ship
 * - BOARDING_COOLDOWN: 60-second break between waves
 * - BOSS_PHASE: Boss has been spawned, awaiting outcome
 * - DISABLED: Ship disabled after boss killed, player can board
 * - DISENGAGING: Pirates won (all player crew dead), leaving area
 *
 * Each state's branch is a parallel of the behaviors that state used to queue. Every
 * npc_ship behavior returns a bare AI_BEHAVIOR_DELAY, so it reports BT_RUNNING forever and
 * re-fires on its own time_between_perform - the parallel reproduces the old queued set.
 */
/datum/bt_node/subtree/npc_ship_combat
	behavior_tree_json = "voidcrew/modules/npc_ships/code/subtrees/npc_ship_combat.bt.json"

// ========== STATE GATES ==========

/**
 * VOIDCREW: gates the whole combat tree on the ship actually being in flight.
 * Docked/crashed ships run no combat AI at all.
 */
/datum/bt_node/decorator/npc_ship_flying
	observer_abort = BT_ABORT_SELF

/datum/bt_node/decorator/npc_ship_flying/check_condition(datum/ai_controller/npc_ship/controller)
	if(!istype(controller))
		return FALSE
	var/obj/structure/overmap/ship/npc/ship = controller.get_ship()
	if(!ship)
		return FALSE
	// VOIDCREW: standing down is not the same as going silent. Note the park (one log
	// line, idempotent) so the parked branch of the movement tree can undock us again -
	// without it, one player force-dock killed an NPC hull's AI permanently, because
	// nothing else in the game ever returns an NPC hull to FLYING. DOCKING/UNDOCKING/
	// ACTING are transitional and reconciled by check_manoeuvre_stalled() on SSovermap's
	// poll, so they are simply waited out.
	if(ship.state != OVERMAP_SHIP_FLYING)
		controller.note_ai_parked()
		return FALSE
	controller.note_ai_recovered()
	return TRUE

/**
 * VOIDCREW: the mirror of the gate above - true only for a hull sitting berthed, which is
 * the one non-flying state something can be done about. See
 * /datum/bt_node/ai_behavior/npc_ship/undock_recovery.
 */
/datum/bt_node/decorator/npc_ship_parked
	observer_abort = BT_ABORT_SELF

/datum/bt_node/decorator/npc_ship_parked/check_condition(datum/ai_controller/npc_ship/controller)
	if(!istype(controller))
		return FALSE
	var/obj/structure/overmap/ship/npc/ship = controller.get_ship()
	return ship && ship.state == OVERMAP_SHIP_IDLE

/**
 * VOIDCREW: matches one NPC combat state. Subtypes below pin the state they answer for.
 *
 * These have no observer signals on purpose - set_combat_state() writes the blackboard key
 * directly, so no COMSIG_AI_BLACKBOARD_KEY_SET fires. Falling back to the controller's
 * polling loop re-evaluates every SelectBehaviors tick, which is exactly what the old
 * SelectBehaviors() switch did.
 */
/datum/bt_node/decorator/npc_combat_state
	observer_abort = BT_ABORT_SELF
	/// The NPC_COMBAT_* constant this branch answers for.
	var/state

/datum/bt_node/decorator/npc_combat_state/check_condition(datum/ai_controller/npc_ship/controller)
	if(!istype(controller))
		return FALSE
	return controller.get_combat_state() == state

/datum/bt_node/decorator/npc_combat_state/idle
	state = NPC_COMBAT_IDLE

/datum/bt_node/decorator/npc_combat_state/scanning
	state = NPC_COMBAT_SCANNING

/datum/bt_node/decorator/npc_combat_state/hailing
	state = NPC_COMBAT_HAILING

/datum/bt_node/decorator/npc_combat_state/engaging
	state = NPC_COMBAT_ENGAGING

/datum/bt_node/decorator/npc_combat_state/combat
	state = NPC_COMBAT_COMBAT

/datum/bt_node/decorator/npc_combat_state/siphoning
	state = NPC_COMBAT_SIPHONING

/datum/bt_node/decorator/npc_combat_state/retreating
	state = NPC_COMBAT_RETREATING

/datum/bt_node/decorator/npc_combat_state/negotiating
	state = NPC_COMBAT_NEGOTIATING

/datum/bt_node/decorator/npc_combat_state/boarding
	state = NPC_COMBAT_BOARDING

/datum/bt_node/decorator/npc_combat_state/boarding_cooldown
	state = NPC_COMBAT_BOARDING_COOLDOWN

/datum/bt_node/decorator/npc_combat_state/boss_phase
	state = NPC_COMBAT_BOSS_PHASE

/datum/bt_node/decorator/npc_combat_state/disabled
	state = NPC_COMBAT_DISABLED

/datum/bt_node/decorator/npc_combat_state/disengaging
	state = NPC_COMBAT_DISENGAGING

// ========== ACTION PRIORITY COMPOSITE ==========

/**
 * VOIDCREW: picks ONE offensive action per tick instead of running all of them.
 *
 * This prevents pirates from overwhelming players with simultaneous attacks. It is a
 * composite rather than a selector because the choice is a weighted roll with commitment
 * delays, not a priority order - the roll happens once per tick and only the winning child
 * is ticked. Children identify themselves by their combat_action var, so JSON ordering
 * does not matter.
 */
/datum/bt_node/composite/npc_combat_action
	label = "NPC COMBAT ACTION"

/datum/bt_node/composite/npc_combat_action/tick(datum/ai_controller/controller, seconds_per_tick)
	if(!istype(controller, /datum/ai_controller/npc_ship))
		return BT_FAILURE

	var/chosen_action = choose_combat_action(controller)
	for(var/datum/bt_node/ai_behavior/npc_ship/action_node as anything in children)
		if(action_node.combat_action != chosen_action)
			continue
		return action_node.tick(controller, seconds_per_tick)

	return BT_FAILURE

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
/datum/bt_node/composite/npc_combat_action/proc/choose_combat_action(datum/ai_controller/npc_ship/controller)
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

	// Siphon is available if ship has siphon goals (weight: 15) - but never in the red
	// band. The siphon is the yellow-band mugging tool; red settles it with guns and
	// boarders (acquire_lock and hail_escalates_to_siphon gate on the same check).
	// Without this, a red-zone pirate that rolled the siphon skimmed its goal and then
	// ended the whole fight via on_goal_reached()'s retreat - and retreating ships
	// ignore further player aggression entirely.
	if(ship?.siphon_goal_percent > 0 && !controller.is_red_zone_raid())
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
