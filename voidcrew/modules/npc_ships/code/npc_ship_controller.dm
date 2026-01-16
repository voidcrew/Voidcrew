/**
 * NPC Ship AI Controller
 *
 * This AI controller is designed for NPC ships (objects, not mobs).
 * It manages combat behaviors like scanning for threats, acquiring locks,
 * firing weapons, and using the interdictor.
 *
 * Unlike mob AI controllers, this doesn't need movement handling
 * (ships use overmap movement) or stat/login checks.
 */
/datum/ai_controller/npc_ship
	/// Ships don't use normal movement, they use overmap velocity
	ai_movement = null

	/// Combat and movement subtrees
	planning_subtrees = list(
		/datum/ai_planning_subtree/npc_ship_combat,
		/datum/ai_planning_subtree/npc_ship_movement,
	)

	/// Ships should always be active while in simulation
	can_idle = FALSE

	/// Ships always process (no player interaction needed)
	continue_processing_when_client = TRUE

/datum/ai_controller/npc_ship/New(atom/new_pawn)
	// Initialize combat blackboard
	blackboard[BB_NPC_COMBAT_STATE] = NPC_COMBAT_IDLE
	blackboard[BB_NPC_TARGET_LOCKED] = FALSE

	// Initialize movement blackboard
	blackboard[BB_NPC_MOVEMENT_MODE] = NPC_MOVEMENT_PATROL
	blackboard[BB_NPC_CIRCUIT_INDEX] = 1

	// Store spawn zone - ship cannot leave this zone
	if(new_pawn)
		var/turf/spawn_turf = get_turf(new_pawn)
		if(spawn_turf)
			blackboard[BB_NPC_SPAWN_ZONE] = SSovermap_zones.get_zone(spawn_turf)

	. = ..()

/datum/ai_controller/npc_ship/TryPossessPawn(atom/new_pawn)
	// Verify the pawn is an NPC ship
	if(!istype(new_pawn, /obj/structure/overmap/ship/npc))
		return AI_CONTROLLER_INCOMPATIBLE

	// Register for ship-specific signals
	RegisterSignal(new_pawn, COMSIG_SHIP_SHIELD_HIT, PROC_REF(on_shield_hit))
	RegisterSignal(new_pawn, COMSIG_SHIP_HULL_HIT, PROC_REF(on_hull_hit))
	RegisterSignal(new_pawn, COMSIG_QDELETING, PROC_REF(on_ship_destroyed))

	// Register for player aggression signals (being targeted = player starting lock)
	RegisterSignal(new_pawn, COMSIG_SHIP_BEING_TARGETED, PROC_REF(on_being_targeted_by_player))
	RegisterSignal(new_pawn, COMSIG_SHIP_WEAPONS_LOCKED, PROC_REF(on_weapons_locked_by_player))

	return ..()

/// Override to avoid ai_movement access (we set ai_movement = null for ships)
/// Replicates parent logic without the ai_movement.moving_controllers check
/datum/ai_controller/npc_ship/UnpossessPawn(destroy)
	if(isnull(pawn))
		return

	// Unregister ship-specific signals
	UnregisterSignal(pawn, list(
		COMSIG_SHIP_SHIELD_HIT,
		COMSIG_SHIP_HULL_HIT,
		COMSIG_QDELETING,
		COMSIG_SHIP_BEING_TARGETED,
		COMSIG_SHIP_WEAPONS_LOCKED,
	))

	// Replicate parent cleanup (without ai_movement check which would crash)
	SEND_SIGNAL(src, COMSIG_AI_CONTROLLER_UNPOSSESSED_PAWN)
	set_ai_status(AI_STATUS_OFF)
	UnregisterSignal(pawn, list(COMSIG_MOVABLE_Z_CHANGED, COMSIG_QDELETING))
	clear_able_to_run()
	// SKIP: ai_movement.moving_controllers check - we don't use ai_movement
	var/turf/pawn_turf = get_turf(pawn)
	if(pawn_turf)
		GLOB.ai_controllers_by_zlevel[pawn_turf.z] -= src
	remove_from_unplanned_controllers()
	pawn.ai_controller = null
	pawn = null
	if(destroy)
		qdel(src)

/// Override to avoid ai_movement access in parent Destroy
/datum/ai_controller/npc_ship/Destroy(force)
	UnpossessPawn(FALSE)
	if(ai_status)
		GLOB.ai_controllers_by_status[ai_status] -= src
	our_cells = null
	set_movement_target(type, null)
	// SKIP: ai_movement.moving_controllers check - we don't use ai_movement
	return ..()

/**
 * Override to handle ships (objects) instead of mobs.
 * Ships are always "on" as long as they exist and are in the overmap.
 */
/datum/ai_controller/npc_ship/get_expected_ai_status()
	if(isnull(pawn))
		return AI_STATUS_OFF

	var/turf/pawn_turf = get_turf(pawn)
	if(isnull(pawn_turf))
		return AI_STATUS_OFF

	// NPC ships should always be active when the game is running
	// Unlike mobs, we don't check for nearby players since ships operate
	// on the overmap z-level which has no clients (players are inside ships)
	if(on_failed_planning_timeout || !able_to_run)
		return AI_STATUS_OFF

	return AI_STATUS_ON

/**
 * Override to avoid mob-specific signal registrations.
 */
/datum/ai_controller/npc_ship/PossessPawn(atom/new_pawn)
	if(pawn)
		UnpossessPawn(FALSE)

	if(istype(new_pawn.ai_controller))
		QDEL_NULL(new_pawn.ai_controller)

	if(TryPossessPawn(new_pawn) & AI_CONTROLLER_INCOMPATIBLE)
		qdel(src)
		CRASH("[src] attached to [new_pawn] but these are not compatible!")

	pawn = new_pawn
	pawn.ai_controller = src

	var/turf/pawn_turf = get_turf(pawn)
	if(pawn_turf)
		GLOB.ai_controllers_by_zlevel[pawn_turf.z] += src

	SEND_SIGNAL(src, COMSIG_AI_CONTROLLER_POSSESSED_PAWN)

	reset_ai_status()
	RegisterSignal(pawn, COMSIG_MOVABLE_Z_CHANGED, PROC_REF(on_changed_z_level))
	update_able_to_run()
	setup_able_to_run()

	// Ships don't need the spatial grid cell tracking for player detection
	// They're always active on the overmap

/**
 * Override to avoid mob-specific signal unregistrations.
 */
/datum/ai_controller/npc_ship/setup_able_to_run()
	RegisterSignals(pawn, list(SIGNAL_ADDTRAIT(TRAIT_AI_PAUSED), SIGNAL_REMOVETRAIT(TRAIT_AI_PAUSED)), PROC_REF(update_able_to_run))

/datum/ai_controller/npc_ship/clear_able_to_run()
	UnregisterSignal(pawn, list(SIGNAL_ADDTRAIT(TRAIT_AI_PAUSED), SIGNAL_REMOVETRAIT(TRAIT_AI_PAUSED)))

// ========== SIGNAL HANDLERS ==========

/**
 * Called when the ship's shields take a hit.
 * This could trigger more aggressive behavior.
 */
/datum/ai_controller/npc_ship/proc/on_shield_hit(datum/source, damage_absorbed, turf/impact_location)
	SIGNAL_HANDLER
	// Could use this to track that we're under attack
	// For now, combat state is managed by the scan_threats behavior

/**
 * Called when the ship's hull takes damage.
 * This means shields are down or something bypassed them.
 */
/datum/ai_controller/npc_ship/proc/on_hull_hit(datum/source, turf/impact_location)
	SIGNAL_HANDLER
	// Could trigger flee behavior in the future
	// For now, just tracks that we're taking real damage

/**
 * Called when the ship is destroyed.
 */
/datum/ai_controller/npc_ship/proc/on_ship_destroyed(datum/source)
	SIGNAL_HANDLER
	// Clear engaging_pirate_ref on our target if we had one
	var/obj/structure/overmap/ship/target = get_target()
	var/obj/structure/overmap/ship/npc/our_ship = get_ship()
	if(target && !QDELETED(target) && our_ship)
		if(target.engaging_pirate_ref?.resolve() == our_ship)
			target.engaging_pirate_ref = null
	set_ai_status(AI_STATUS_OFF)

/**
 * Called when a player ship STARTS targeting us (beginning lock acquisition).
 * If we're in HAILING or NEGOTIATING with this player, treat as aggression.
 */
/datum/ai_controller/npc_ship/proc/on_being_targeted_by_player(datum/source, obj/structure/overmap/ship/aggressor)
	SIGNAL_HANDLER
	// Only react if the aggressor is our current target (the ship we're negotiating with)
	var/obj/structure/overmap/ship/our_target = get_target()
	if(!our_target || aggressor != our_target)
		return

	var/combat_state = get_combat_state()

	// If we're hailing or negotiating, this is aggression
	if(combat_state == NPC_COMBAT_HAILING || combat_state == NPC_COMBAT_NEGOTIATING)
		INVOKE_ASYNC(src, PROC_REF(handle_player_aggression), aggressor, "targeting")

/**
 * Called when a player ship completes a weapons lock on us.
 * If we're in HAILING or NEGOTIATING with this player, treat as aggression.
 */
/datum/ai_controller/npc_ship/proc/on_weapons_locked_by_player(datum/source, obj/structure/overmap/ship/aggressor)
	SIGNAL_HANDLER
	// Only react if the aggressor is our current target (the ship we're negotiating with)
	var/obj/structure/overmap/ship/our_target = get_target()
	if(!our_target || aggressor != our_target)
		return

	var/combat_state = get_combat_state()

	// If we're hailing or negotiating, this is aggression - immediate combat
	if(combat_state == NPC_COMBAT_HAILING || combat_state == NPC_COMBAT_NEGOTIATING)
		INVOKE_ASYNC(src, PROC_REF(handle_player_aggression), aggressor, "weapons_lock")

/**
 * Handle player aggression during HAILING or NEGOTIATING phase.
 * Escalates to immediate combat.
 */
/datum/ai_controller/npc_ship/proc/handle_player_aggression(obj/structure/overmap/ship/aggressor, reason)
	var/obj/structure/overmap/ship/npc/our_ship = get_ship()
	var/combat_state = get_combat_state()

	// If negotiating, end the negotiation first
	if(combat_state == NPC_COMBAT_NEGOTIATING)
		var/datum/pirate_negotiation/negotiation = blackboard[BB_NPC_NEGOTIATION]
		if(negotiation)
			negotiation.end_negotiation(success = FALSE, reason = "player_aggression")

	// Clear hailing state if we were hailing
	if(combat_state == NPC_COMBAT_HAILING)
		clear_blackboard_key(BB_NPC_HAILING_START)
		clear_blackboard_key(BB_NPC_HAILING_ANNOUNCED)
		clear_blackboard_key("hailing_reminder_sent")

	// Announce to both ships
	our_ship?.ship_announce("Hostile action detected! Engaging!", "COMBAT")
	aggressor?.ship_announce(
		"[our_ship?.name || "Hostile vessel"] is retaliating to your aggressive actions!",
		"COMBAT ALERT",
		FALSE,
		sound('sound/effects/alert.ogg')
	)

	// Go straight to ENGAGING (will acquire lock then fight)
	set_combat_state(NPC_COMBAT_ENGAGING)

// ========== HELPER PROCS ==========

/**
 * Gets our NPC ship pawn.
 */
/datum/ai_controller/npc_ship/proc/get_ship()
	return pawn

/**
 * Gets the combat interface for our ship.
 */
/datum/ai_controller/npc_ship/proc/get_combat_interface()
	var/obj/structure/overmap/ship/npc/ship = pawn
	return ship?.combat_interface

/**
 * Transitions to a new combat state.
 */
/datum/ai_controller/npc_ship/proc/set_combat_state(new_state)
	var/old_state = blackboard[BB_NPC_COMBAT_STATE]
	set_blackboard_key(BB_NPC_COMBAT_STATE, new_state)

	// When entering retreat mode, lose weapon lock and cancel interdiction
	if(new_state == NPC_COMBAT_RETREATING && old_state != NPC_COMBAT_RETREATING)
		// Clear weapon lock
		clear_blackboard_key(BB_NPC_TARGET_LOCKED)
		clear_blackboard_key(BB_NPC_LOCK_START_TIME)

		// Cancel interdiction
		var/datum/npc_combat_interface/combat = get_combat_interface()
		combat?.cancel_interdiction()

		// Notify target that we stopped targeting them and clear engagement
		var/obj/structure/overmap/ship/target = get_target()
		var/obj/structure/overmap/ship/npc/ship = get_ship()
		if(target && ship)
			SEND_SIGNAL(target, COMSIG_SHIP_TARGETING_STOPPED, ship)
			// Clear engagement so another pirate can engage this target
			if(target.engaging_pirate_ref?.resolve() == ship)
				target.engaging_pirate_ref = null

/**
 * Gets the current combat state.
 */
/datum/ai_controller/npc_ship/proc/get_combat_state()
	return blackboard[BB_NPC_COMBAT_STATE]

/**
 * Sets the current target ship.
 * Also marks the target as engaged by this pirate (prevents other pirates from engaging same target).
 */
/datum/ai_controller/npc_ship/proc/set_target(obj/structure/overmap/ship/target)
	var/obj/structure/overmap/ship/npc/our_ship = get_ship()

	// Clear engaging_pirate on old target if we had one
	var/obj/structure/overmap/ship/old_target = blackboard[BB_NPC_TARGET]
	if(old_target && !QDELETED(old_target) && old_target != target)
		if(old_target.engaging_pirate_ref?.resolve() == our_ship)
			old_target.engaging_pirate_ref = null

	if(target)
		set_blackboard_key(BB_NPC_TARGET, target)
		// Mark this target as engaged by us (only one pirate can engage at a time)
		if(our_ship)
			target.engaging_pirate_ref = WEAKREF(our_ship)
	else
		clear_blackboard_key(BB_NPC_TARGET)
		clear_blackboard_key(BB_NPC_TARGET_LOCKED)
		clear_blackboard_key(BB_NPC_LOCK_START_TIME)

/**
 * Gets the current target ship.
 */
/datum/ai_controller/npc_ship/proc/get_target()
	return blackboard[BB_NPC_TARGET]

/**
 * Clears the current target and resets to idle.
 * Also cancels any active interdiction and clears engagement tracking.
 */
/datum/ai_controller/npc_ship/proc/clear_target()
	// Cancel any active interdiction when losing target
	var/datum/npc_combat_interface/combat = get_combat_interface()
	combat?.cancel_interdiction()

	// Clear engaging_pirate_ref on current target before clearing
	var/obj/structure/overmap/ship/target = get_target()
	var/obj/structure/overmap/ship/npc/our_ship = get_ship()
	if(target && !QDELETED(target) && our_ship)
		// Only clear if we're the one engaging (could have been taken over by another pirate in edge cases)
		if(target.engaging_pirate_ref?.resolve() == our_ship)
			target.engaging_pirate_ref = null

	set_target(null)
	set_combat_state(NPC_COMBAT_IDLE)

// ========== NEGOTIATION HANDLING ==========

/**
 * Enter negotiation state - pauses combat while keeping target.
 * Called when a player hails the pirate to negotiate tribute.
 */
/datum/ai_controller/npc_ship/proc/enter_negotiation(datum/pirate_negotiation/negotiation)
	if(!negotiation)
		return FALSE

	// Store negotiation reference
	set_blackboard_key(BB_NPC_NEGOTIATION, negotiation)
	set_blackboard_key(BB_NPC_NEGOTIATION_START, world.time)

	// Transition to negotiating state (pauses combat behaviors)
	set_combat_state(NPC_COMBAT_NEGOTIATING)

	// Clear weapon lock if we were acquiring one
	clear_blackboard_key(BB_NPC_TARGET_LOCKED)
	clear_blackboard_key(BB_NPC_LOCK_START_TIME)

	// Cancel any active interdiction
	var/datum/npc_combat_interface/combat = get_combat_interface()
	combat?.cancel_interdiction()

	return TRUE

/**
 * Exit negotiation state - either disengage (success) or resume combat (failure).
 */
/datum/ai_controller/npc_ship/proc/exit_negotiation(success = FALSE)
	// Clear negotiation reference
	clear_blackboard_key(BB_NPC_NEGOTIATION)
	clear_blackboard_key(BB_NPC_NEGOTIATION_START)

	if(success)
		// Payment received - disengage completely
		clear_target()
		// Target is now on our "paid" list (handled by negotiation datum)
	else
		// Negotiation failed - resume combat
		set_combat_state(NPC_COMBAT_ENGAGING)

/**
 * Check if a target ship has recently paid tribute (immunity check).
 * Returns TRUE if the ship is immune from attack.
 */
/datum/ai_controller/npc_ship/proc/has_tribute_immunity(obj/structure/overmap/ship/target)
	var/list/paid_ships = blackboard[BB_NPC_PAID_TRIBUTE_SHIPS]
	if(!paid_ships)
		return FALSE

	var/immunity_expires = paid_ships[REF(target)]
	if(!immunity_expires)
		return FALSE

	// Check if immunity has expired
	if(world.time > immunity_expires)
		paid_ships -= REF(target)
		return FALSE

	return TRUE
