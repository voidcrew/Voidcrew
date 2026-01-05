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
	blackboard[BB_NPC_ORBIT_DISTANCE] = NPC_SHIP_ORBIT_DISTANCE
	blackboard[BB_NPC_CHASE_BOUNDARY] = NPC_SHIP_CHASE_RANGE
	blackboard[BB_NPC_PATROL_INDEX] = 1

	// Store home turf for chase behavior
	if(new_pawn)
		blackboard[BB_NPC_HOME_TURF] = get_turf(new_pawn)

	. = ..()

/datum/ai_controller/npc_ship/TryPossessPawn(atom/new_pawn)
	// Verify the pawn is an NPC ship
	if(!istype(new_pawn, /obj/structure/overmap/ship/npc))
		return AI_CONTROLLER_INCOMPATIBLE

	// Register for ship-specific signals
	RegisterSignal(new_pawn, COMSIG_SHIP_SHIELD_HIT, PROC_REF(on_shield_hit))
	RegisterSignal(new_pawn, COMSIG_SHIP_HULL_HIT, PROC_REF(on_hull_hit))
	RegisterSignal(new_pawn, COMSIG_QDELETING, PROC_REF(on_ship_destroyed))

	return ..()

/datum/ai_controller/npc_ship/UnpossessPawn(destroy)
	if(pawn)
		UnregisterSignal(pawn, list(
			COMSIG_SHIP_SHIELD_HIT,
			COMSIG_SHIP_HULL_HIT,
			COMSIG_QDELETING,
		))
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
	set_ai_status(AI_STATUS_OFF)

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
	set_blackboard_key(BB_NPC_COMBAT_STATE, new_state)

/**
 * Gets the current combat state.
 */
/datum/ai_controller/npc_ship/proc/get_combat_state()
	return blackboard[BB_NPC_COMBAT_STATE]

/**
 * Sets the current target ship.
 */
/datum/ai_controller/npc_ship/proc/set_target(obj/structure/overmap/ship/target)
	if(target)
		set_blackboard_key(BB_NPC_TARGET, target)
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
 */
/datum/ai_controller/npc_ship/proc/clear_target()
	set_target(null)
	set_combat_state(NPC_COMBAT_IDLE)
