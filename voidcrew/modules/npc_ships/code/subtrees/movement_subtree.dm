/**
 * NPC Ship Movement Subtree
 *
 * VOIDCREW: fork-specific overmap movement for NPC ships.
 * Uses discrete movement (forceMove) - no momentum/physics, and no ai_movement datum.
 *
 * Movement modes:
 * - IDLE: No active movement, sit still
 * - PATROL: Follow circular circuit around zone (uses A* pathfinding)
 * - CHASE: Pursue target (used internally when target exists)
 * - RETURN_TO_ROUTE: Path back to patrol circuit after combat
 * - ROAMING: Fallback when circuit generation fails
 * - RETREAT: Fleeing after all weapons destroyed
 *
 * The tree is a priority cascade (retreat > out-of-zone > chase > mode dispatch). The
 * old SelectBehaviors() interleaved side effects with those checks, so each side effect
 * now lives in its own leaf placed exactly where the old code ran it, and the branches
 * are parallels (not sequences) so those leaves re-fire every tick like they used to.
 */

/// VOIDCREW: the movement mode the mode-dispatch selector should act on THIS tick.
/// Deliberately separate from BB_NPC_MOVEMENT_MODE: the old subtree captured the mode into
/// a local before the "lost our target" block could overwrite it, so losing a target left
/// one tick still dispatching on the pre-overwrite mode. resolve_lost_target publishes the
/// captured value here so that quirk survives the port intact.
#define BB_NPC_DISPATCH_MODE "npc_dispatch_mode"

/datum/bt_node/subtree/npc_ship_movement
	behavior_tree_json = "voidcrew/modules/npc_ships/code/subtrees/npc_ship_movement.bt.json"

// ========== PRIORITY GATES ==========

/**
 * VOIDCREW: retreat mode overrides everything - keep fleeing.
 */
/datum/bt_node/decorator/npc_movement_retreating
	observer_abort = BT_ABORT_SELF

/datum/bt_node/decorator/npc_movement_retreating/check_condition(datum/ai_controller/npc_ship/controller)
	if(!istype(controller))
		return FALSE
	var/movement_mode = controller.blackboard[BB_NPC_MOVEMENT_MODE] || NPC_MOVEMENT_PATROL
	return movement_mode == NPC_MOVEMENT_RETREAT

/**
 * VOIDCREW: we drifted out of our spawn zone and have to get back.
 * Unconfined hunters have no spawn zone, so this never fires for them.
 */
/datum/bt_node/decorator/npc_outside_spawn_zone
	observer_abort = BT_ABORT_SELF

/datum/bt_node/decorator/npc_outside_spawn_zone/check_condition(datum/ai_controller/npc_ship/controller)
	if(!istype(controller))
		return FALSE
	var/datum/overmap_zone/spawn_zone = controller.blackboard[BB_NPC_SPAWN_ZONE]
	if(!spawn_zone)
		return FALSE
	var/obj/structure/overmap/ship/npc/ship = controller.pawn
	if(!ship)
		return FALSE
	var/turf/our_turf = get_turf(ship)
	if(!our_turf)
		return FALSE
	return SSovermap_zones.get_zone(our_turf) != spawn_zone

/**
 * VOIDCREW: if we have a combat target, ALWAYS chase it.
 */
/datum/bt_node/decorator/npc_has_combat_target
	observer_abort = BT_ABORT_SELF

/datum/bt_node/decorator/npc_has_combat_target/check_condition(datum/ai_controller/npc_ship/controller)
	if(!istype(controller))
		return FALSE
	var/obj/structure/overmap/ship/target = controller.get_target()
	return target && !QDELETED(target)

/**
 * VOIDCREW: matches one movement mode for the dispatch selector. Reads the captured
 * dispatch mode, not BB_NPC_MOVEMENT_MODE - see BB_NPC_DISPATCH_MODE above.
 */
/datum/bt_node/decorator/npc_movement_mode
	observer_abort = BT_ABORT_SELF
	/// The NPC_MOVEMENT_* constant this branch answers for.
	var/mode

/datum/bt_node/decorator/npc_movement_mode/check_condition(datum/ai_controller/npc_ship/controller)
	if(!istype(controller))
		return FALSE
	return controller.blackboard[BB_NPC_DISPATCH_MODE] == mode

/datum/bt_node/decorator/npc_movement_mode/idle
	mode = NPC_MOVEMENT_IDLE

/datum/bt_node/decorator/npc_movement_mode/patrol
	mode = NPC_MOVEMENT_PATROL

/datum/bt_node/decorator/npc_movement_mode/return_to_route
	mode = NPC_MOVEMENT_RETURN_TO_ROUTE

/datum/bt_node/decorator/npc_movement_mode/roaming
	mode = NPC_MOVEMENT_ROAMING

/datum/bt_node/decorator/npc_movement_mode/chase
	mode = NPC_MOVEMENT_CHASE

// ========== BOOKKEEPING LEAVES ==========

/**
 * VOIDCREW: side effects the old subtree ran inline before queueing return_to_zone.
 * We can't fight outside our zone, so drop any target we picked up out here.
 */
/datum/bt_node/ai_behavior/npc_ship/leave_zone_cleanup

/datum/bt_node/ai_behavior/npc_ship/leave_zone_cleanup/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	if(controller.get_target())
		controller.clear_target()
	controller.blackboard[BB_NPC_HAD_TARGET] = FALSE
	return AI_BEHAVIOR_SUCCEEDED

/**
 * VOIDCREW: mark that we're in combat so we know to return to route afterwards.
 */
/datum/bt_node/ai_behavior/npc_ship/mark_had_target

/datum/bt_node/ai_behavior/npc_ship/mark_had_target/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	controller.set_blackboard_key(BB_NPC_HAD_TARGET, TRUE)
	return AI_BEHAVIOR_SUCCEEDED

/**
 * VOIDCREW: publishes the dispatch mode for this tick, then handles "we just lost our
 * target" - switch to RETURN_TO_ROUTE and aim at the nearest circuit waypoint.
 *
 * Order matters: the mode is captured BEFORE the had_target block overwrites
 * BB_NPC_MOVEMENT_MODE, which is what the old subtree's local variable did.
 */
/datum/bt_node/ai_behavior/npc_ship/resolve_lost_target

/datum/bt_node/ai_behavior/npc_ship/resolve_lost_target/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	var/movement_mode = controller.blackboard[BB_NPC_MOVEMENT_MODE] || NPC_MOVEMENT_PATROL
	controller.set_blackboard_key(BB_NPC_DISPATCH_MODE, movement_mode)

	var/had_target = controller.blackboard[BB_NPC_HAD_TARGET]
	if(!had_target)
		return AI_BEHAVIOR_SUCCEEDED

	controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_RETURN_TO_ROUTE)
	controller.set_blackboard_key(BB_NPC_HAD_TARGET, FALSE)
	// Clear movement state so return_to_route starts fresh
	controller.blackboard[BB_NPC_CURRENT_PATH] = null
	// Find nearest waypoint on circuit
	var/list/circuit = controller.blackboard[BB_NPC_PATROL_CIRCUIT]
	if(length(circuit))
		var/obj/structure/overmap/ship/npc/ship = controller.pawn
		var/turf/our_loc = get_turf(ship)
		var/nearest = find_nearest_circuit_waypoint(our_loc, circuit)
		controller.set_blackboard_key(BB_NPC_CIRCUIT_INDEX, nearest)

	return AI_BEHAVIOR_SUCCEEDED

/**
 * VOIDCREW: CHASE mode with no target left - fall back to patrol.
 */
/datum/bt_node/ai_behavior/npc_ship/chase_mode_reset

/datum/bt_node/ai_behavior/npc_ship/chase_mode_reset/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_PATROL)
	return AI_BEHAVIOR_SUCCEEDED

/**
 * VOIDCREW: IDLE movement mode - hold the tick without moving.
 * The old subtree returned here with nothing queued; a branch that FAILED instead would
 * let the selector fall through to the next mode, which never used to happen.
 */
/datum/bt_node/ai_behavior/npc_ship/movement_hold
	time_between_perform = 1 SECONDS

/datum/bt_node/ai_behavior/npc_ship/movement_hold/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	return AI_BEHAVIOR_DELAY
