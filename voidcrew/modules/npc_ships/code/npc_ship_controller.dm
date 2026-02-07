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

	// If we're hailing, negotiating, or siphoning, this is aggression
	if(combat_state == NPC_COMBAT_HAILING || combat_state == NPC_COMBAT_NEGOTIATING || combat_state == NPC_COMBAT_SIPHONING)
		INVOKE_ASYNC(src, PROC_REF(handle_player_aggression), aggressor, "targeting")

/**
 * Called when a player ship completes a weapons lock on us.
 * If we're in HAILING, NEGOTIATING, or SIPHONING with this player, treat as aggression.
 */
/datum/ai_controller/npc_ship/proc/on_weapons_locked_by_player(datum/source, obj/structure/overmap/ship/aggressor)
	SIGNAL_HANDLER
	// Only react if the aggressor is our current target (the ship we're negotiating with)
	var/obj/structure/overmap/ship/our_target = get_target()
	if(!our_target || aggressor != our_target)
		return

	var/combat_state = get_combat_state()

	// If we're hailing, negotiating, or siphoning, this is aggression - immediate combat
	if(combat_state == NPC_COMBAT_HAILING || combat_state == NPC_COMBAT_NEGOTIATING || combat_state == NPC_COMBAT_SIPHONING)
		INVOKE_ASYNC(src, PROC_REF(handle_player_aggression), aggressor, "weapons_lock")

/**
 * Called when our target starts a zone transition.
 * If we're in HAILING state, cancel the hail - they're escaping.
 */
/datum/ai_controller/npc_ship/proc/on_target_zone_transition(datum/source, datum/overmap_zone/target_zone)
	SIGNAL_HANDLER

	var/combat_state = get_combat_state()

	// If we're hailing, cancel the hail - they're getting away
	if(combat_state == NPC_COMBAT_HAILING)
		INVOKE_ASYNC(src, PROC_REF(handle_target_escaping_via_zone))

/**
 * Handle target escaping via zone transition during HAILING phase.
 * Cancels the hail and clears the target.
 */
/datum/ai_controller/npc_ship/proc/handle_target_escaping_via_zone()
	var/obj/structure/overmap/ship/npc/our_ship = get_ship()
	var/obj/structure/overmap/ship/target = get_target()

	// Clear hailing state
	clear_blackboard_key(BB_NPC_HAILING_START)
	clear_blackboard_key(BB_NPC_HAILING_ANNOUNCED)
	clear_blackboard_key("hailing_reminder_sent")

	// Stop the holopad ringing on target ship
	if(target && !QDELETED(target))
		var/obj/machinery/holopad/ship_comms/holopad = find_ship_comms_holopad(target)
		holopad?.stop_ringing()

	// Announce to pirate ship
	our_ship?.ship_notify("Target is crossing zones. Hail cancelled.", "COMMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	// Clear target and return to idle
	clear_target()

/**
 * Find the ship comms holopad on a ship.
 */
/datum/ai_controller/npc_ship/proc/find_ship_comms_holopad(obj/structure/overmap/ship/target)
	if(!target?.shuttle?.shuttle_areas)
		return null

	for(var/area/shuttle_area as anything in target.shuttle.shuttle_areas)
		var/obj/machinery/holopad/ship_comms/found = locate() in shuttle_area
		if(found)
			return found

	return null

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
	our_ship?.ship_notify("Hostile action detected! Engaging!", "COMBAT", SHIP_NOTIFY_WARNING, 'voidcrew/sound/alert2.ogg', 25)
	aggressor?.ship_notify("[our_ship?.name || "Hostile vessel"] is retaliating to your aggressive actions!", "COMBAT", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert2.ogg', 25)

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
		var/obj/structure/overmap/ship/target = get_target()
		var/obj/structure/overmap/ship/npc/ship = get_ship()

		// Store last target for retreat direction (retreat_escape uses this for distance check)
		if(target && !QDELETED(target))
			blackboard[BB_NPC_LAST_TARGET] = WEAKREF(target)

		// Notify target that weapon lock is lost before clearing it
		if(blackboard[BB_NPC_TARGET_LOCKED] && target && ship && !QDELETED(target))
			SEND_SIGNAL(target, COMSIG_SHIP_WEAPONS_LOCK_LOST, ship)

		// Clear weapon lock
		clear_blackboard_key(BB_NPC_TARGET_LOCKED)
		clear_blackboard_key(BB_NPC_LOCK_START_TIME)

		// Cancel interdiction
		var/datum/npc_combat_interface/combat = get_combat_interface()
		combat?.cancel_interdiction()

		// Notify target that we stopped targeting them and clear engagement
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
		// Unregister zone transition signal from old target
		UnregisterSignal(old_target, COMSIG_VOIDCREW_SHIP_ZONE_TRANSITION_START)

	if(target)
		set_blackboard_key(BB_NPC_TARGET, target)
		// Mark this target as engaged by us (only one pirate can engage at a time)
		// Don't overwrite if another active pirate already has this target claimed
		if(our_ship)
			var/obj/structure/overmap/ship/npc/existing_pirate = target.engaging_pirate_ref?.resolve()
			if(!existing_pirate || QDELETED(existing_pirate) || existing_pirate.is_disabled || existing_pirate == our_ship)
				target.engaging_pirate_ref = WEAKREF(our_ship)
		// Register for zone transition signal to cancel hails if target escapes
		RegisterSignal(target, COMSIG_VOIDCREW_SHIP_ZONE_TRANSITION_START, PROC_REF(on_target_zone_transition))
	else
		// Unregister zone transition signal if clearing target
		if(old_target && !QDELETED(old_target))
			UnregisterSignal(old_target, COMSIG_VOIDCREW_SHIP_ZONE_TRANSITION_START)
		// If we had a weapon lock on the old target, notify them we lost it
		if(blackboard[BB_NPC_TARGET_LOCKED] && old_target && !QDELETED(old_target))
			SEND_SIGNAL(old_target, COMSIG_SHIP_WEAPONS_LOCK_LOST, our_ship)
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

	// Notify target that weapon lock is lost before clearing it
	var/obj/structure/overmap/ship/target = get_target()
	var/obj/structure/overmap/ship/npc/ship = get_ship()
	if(blackboard[BB_NPC_TARGET_LOCKED] && target && ship && !QDELETED(target))
		SEND_SIGNAL(target, COMSIG_SHIP_WEAPONS_LOCK_LOST, ship)

	// Clear weapon lock if we were acquiring one
	clear_blackboard_key(BB_NPC_TARGET_LOCKED)
	clear_blackboard_key(BB_NPC_LOCK_START_TIME)

	// Cancel any active interdiction
	var/datum/npc_combat_interface/combat = get_combat_interface()
	combat?.cancel_interdiction()

	return TRUE

/**
 * Exit negotiation state - either disengage (success) or resume combat (failure).
 * reason: Why negotiation ended - "player_moved" triggers immediate ship combat
 */
/datum/ai_controller/npc_ship/proc/exit_negotiation(success = FALSE, reason = "unknown")
	// Clear negotiation reference
	clear_blackboard_key(BB_NPC_NEGOTIATION)
	clear_blackboard_key(BB_NPC_NEGOTIATION_START)

	if(success)
		// Payment received - disengage completely
		clear_target()
		// Target is now on our "paid" list (handled by negotiation datum)
	else
		// Double flee attempt = straight to ship combat (player was already warned)
		if(reason == "player_moved")
			set_combat_state(NPC_COMBAT_COMBAT)
			return

		// Negotiation failed - check if we should use phased boarding
		var/obj/structure/overmap/ship/npc/pirate/ship = get_ship()
		if(istype(ship) && ship.uses_boarding_phases)
			// Start the phased boarding system
			if(start_boarding_phase())
				return  // Successfully started boarding phase
		// Fallback: resume standard ship combat
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

// ========== PHASED BOARDING COMBAT SYSTEM ==========

/**
 * Start the boarding phase after negotiation fails.
 * This initiates the wave-based combat system instead of immediate ship combat.
 */
/datum/ai_controller/npc_ship/proc/start_boarding_phase()
	var/obj/structure/overmap/ship/npc/pirate/ship = get_ship()
	var/obj/structure/overmap/ship/target = get_target()

	if(!ship || !target || QDELETED(target))
		return FALSE

	// Only pirate ships with boarding phases enabled can use this
	if(!istype(ship) || !ship.uses_boarding_phases)
		return FALSE

	// Count and store player crew count for wave scaling
	var/crew_count = count_player_crew(target)
	set_blackboard_key(BB_NPC_BOARDING_INITIAL_CREW_COUNT, crew_count)

	// Start tracking player crew deaths
	start_tracking_player_crew(target)

	// Register for player aggression during boarding (escalates to full combat)
	RegisterSignal(target, COMSIG_SHIP_WEAPONS_LOCKED, PROC_REF(on_player_weapons_lock_during_boarding))

	// Ensure engaging_pirate_ref is set (defensive - should already be set, but just in case)
	// This prevents other pirates from targeting this ship while we're boarding
	target.engaging_pirate_ref = WEAKREF(ship)

	// Initialize wave tracking
	set_blackboard_key(BB_NPC_BOARDING_WAVE, 1)
	blackboard[BB_NPC_BOARDING_WAVE_BOARDERS] = list()

	// Enter boarding state
	set_combat_state(NPC_COMBAT_BOARDING)

	// Stagger the boarding phase events for dramatic effect:
	// T+0: Rejection line already played (from end_negotiation)
	// T+5s: Interdiction locks in
	// T+8s: Boarding announcement
	// T+38s: First wave launches (30s after announcement)

	addtimer(CALLBACK(src, PROC_REF(boarding_phase_interdiction)), 5 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(boarding_phase_announcement)), 8 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(launch_boarding_wave), 1), 38 SECONDS)

	return TRUE

/**
 * Delayed interdiction during boarding phase setup.
 */
/datum/ai_controller/npc_ship/proc/boarding_phase_interdiction()
	var/obj/structure/overmap/ship/target = get_target()
	if(!target || QDELETED(target))
		return

	// Start interdiction to prevent FTL escape
	var/datum/npc_combat_interface/combat = get_combat_interface()
	if(combat)
		combat.start_interdiction(target)

/**
 * Delayed boarding announcement during boarding phase setup.
 */
/datum/ai_controller/npc_ship/proc/boarding_phase_announcement()
	var/obj/structure/overmap/ship/npc/pirate/ship = get_ship()
	var/obj/structure/overmap/ship/target = get_target()

	if(!ship || !target || QDELETED(target))
		return

	// Check we're still in boarding state (didn't escalate to combat)
	if(get_combat_state() != NPC_COMBAT_BOARDING)
		return

	// Announce boarding phase start
	ship.ship_notify("Boarding operation initiated. Wave 1 deploying.", "COMBAT", SHIP_NOTIFY_WARNING, 'voidcrew/sound/alert2.ogg', 25)
	target.ship_notify("[ship.name] is deploying boarding parties! Prepare to repel boarders!", "COMBAT", SHIP_NOTIFY_DANGER)
	target.ship_notify("First wave incoming in 30 seconds!", "COMBAT", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 50)

/**
 * Count living humanoid crew on the target ship.
 * Used for wave scaling.
 */
/datum/ai_controller/npc_ship/proc/count_player_crew(obj/structure/overmap/ship/target)
	if(!target?.shuttle?.shuttle_areas)
		return 0

	var/count = 0
	for(var/area/shuttle_area as anything in target.shuttle.shuttle_areas)
		for(var/mob/living/carbon/human/H in shuttle_area)
			if(H.stat != DEAD)
				count++
	return count

/**
 * Launch a boarding wave of the specified number.
 * Wave size scales with initial player crew count.
 */
/datum/ai_controller/npc_ship/proc/launch_boarding_wave(wave_number)
	var/obj/structure/overmap/ship/npc/pirate/ship = get_ship()
	var/obj/structure/overmap/ship/target = get_target()

	if(!ship || !target || QDELETED(target))
		return FALSE

	// Get wave size range from ship config
	var/list/wave_sizes = ship.boarding_wave_sizes
	if(!wave_sizes || wave_number > length(wave_sizes))
		return FALSE

	var/list/wave_range = wave_sizes[wave_number]
	var/base_min = wave_range[1]
	var/base_max = wave_range[2]

	// Scale wave size based on initial crew count
	var/initial_crew = blackboard[BB_NPC_BOARDING_INITIAL_CREW_COUNT] || 1
	var/scale_factor = get_crew_scale_factor(initial_crew)

	var/scaled_min = round(base_min * scale_factor)
	var/scaled_max = round(base_max * scale_factor)

	// Ensure at least 1 boarder
	scaled_min = max(1, scaled_min)
	scaled_max = max(scaled_min, scaled_max)

	var/boarder_count = rand(scaled_min, scaled_max)

	// Get mob types to spawn (use boarding pod types or crew types)
	var/list/mob_types = ship.boarding_pod_mob_types
	if(!length(mob_types))
		mob_types = ship.crew_types

	if(!length(mob_types))
		return FALSE

	// Find valid spawn locations on target ship
	var/list/valid_turfs = get_target_spawn_turfs(target)
	if(!length(valid_turfs))
		return FALSE

	// Set up global spawn tracking for patrol distribution
	GLOB.boarding_spawn_index = 0
	GLOB.boarding_spawn_total = boarder_count

	// Spawn the boarders via drop pods
	var/list/wave_boarders = list()
	for(var/i in 1 to boarder_count)
		if(!length(valid_turfs))
			break
		var/turf/spawn_loc = pick(valid_turfs)
		var/mob_type = pick(mob_types)

		// Create boarding pod with the mob inside - returns the boarder for tracking
		var/mob/living/boarder = create_boarding_pod(spawn_loc, target, ship, mob_type)

		if(boarder)
			// Track this boarder and register death signal
			wave_boarders += boarder
			RegisterSignal(boarder, COMSIG_LIVING_DEATH, PROC_REF(on_boarder_death))

	// Note: Patrol setup is handled by the boarding pod's open_pod() proc
	log_shuttle("PATROL: Wave [wave_number] launched [length(wave_boarders)] boarders via drop pods")

	// Store the wave boarders for tracking
	blackboard[BB_NPC_BOARDING_WAVE_BOARDERS] = wave_boarders

	// Track wave start time and target position (for time limit and movement detection)
	set_blackboard_key(BB_NPC_BOARDING_WAVE_START_TIME, world.time)
	blackboard[BB_NPC_BOARDING_TARGET_POS] = list(target.x, target.y)

	// Notify target ship
	target.ship_notify("Wave [wave_number]: [length(wave_boarders)] hostiles have boarded!", "SECURITY", SHIP_NOTIFY_DANGER, 'voidcrew/sound/warn3.ogg', 25)

	return TRUE

/**
 * Get crew scaling factor based on player crew count.
 * Returns multiplier for wave sizes.
 */
/datum/ai_controller/npc_ship/proc/get_crew_scale_factor(crew_count)
	switch(crew_count)
		if(0 to 2)
			return 0.75  // Solo/duo - smaller waves
		if(3 to 4)
			return 1.0   // Standard crew - normal waves
		if(5 to 6)
			return 1.25  // Larger crew - bigger waves
		else
			return 1.5   // Full crew - maximum waves

/**
 * Find valid turfs on the target ship for spawning boarders.
 */
/datum/ai_controller/npc_ship/proc/get_target_spawn_turfs(obj/structure/overmap/ship/target)
	var/list/valid_turfs = list()

	if(!target?.shuttle?.shuttle_areas)
		return valid_turfs

	for(var/area/shuttle_area as anything in target.shuttle.shuttle_areas)
		for(var/turf/T in shuttle_area)
			if(isspaceturf(T))
				continue
			if(T.density)
				continue
			if(!isfloorturf(T))
				continue
			var/blocked = FALSE
			for(var/obj/O in T)
				if(O.density)
					blocked = TRUE
					break
			if(blocked)
				continue
			valid_turfs += T

	return valid_turfs

/**
 * Signal handler for when a boarder dies.
 * Tracks deaths and checks if wave is complete.
 */
/datum/ai_controller/npc_ship/proc/on_boarder_death(mob/living/victim, gibbed)
	SIGNAL_HANDLER
	UnregisterSignal(victim, COMSIG_LIVING_DEATH)

	var/list/wave_boarders = blackboard[BB_NPC_BOARDING_WAVE_BOARDERS]
	if(wave_boarders)
		wave_boarders -= victim

	// Check if all boarders are dead
	INVOKE_ASYNC(src, PROC_REF(check_wave_complete))

/**
 * Check if the current wave is complete (all boarders dead).
 */
/datum/ai_controller/npc_ship/proc/check_wave_complete()
	// Guard against multiple calls - only process if we're in BOARDING state
	var/combat_state = get_combat_state()
	if(combat_state != NPC_COMBAT_BOARDING && combat_state != NPC_COMBAT_BOSS_PHASE)
		return

	var/list/wave_boarders = blackboard[BB_NPC_BOARDING_WAVE_BOARDERS]

	// Count living boarders
	var/living_count = 0
	for(var/mob/living/boarder as anything in wave_boarders)
		if(!QDELETED(boarder) && boarder.stat != DEAD)
			living_count++

	if(living_count > 0)
		return  // Wave still active

	// Wave complete! Clear the list to prevent duplicate processing
	clear_blackboard_key(BB_NPC_BOARDING_WAVE_BOARDERS)

	var/current_wave = blackboard[BB_NPC_BOARDING_WAVE] || 1
	SEND_SIGNAL(src, COMSIG_BOARDING_WAVE_COMPLETE, current_wave)

	// Check if this was the final wave
	if(current_wave >= NPC_BOARDING_WAVE_COUNT)
		// All waves defeated - start boss cooldown
		start_boss_cooldown()
	else
		// Start cooldown before next wave
		start_wave_cooldown(current_wave)

/**
 * Start the cooldown period between waves.
 * During cooldown, pirates taunt the players.
 */
/datum/ai_controller/npc_ship/proc/start_wave_cooldown(completed_wave)
	var/obj/structure/overmap/ship/npc/pirate/ship = get_ship()
	var/obj/structure/overmap/ship/target = get_target()

	if(!ship || !target)
		return

	// Enter cooldown state
	set_combat_state(NPC_COMBAT_BOARDING_COOLDOWN)

	// Set cooldown end time
	var/cooldown_end = world.time + NPC_BOARDING_WAVE_COOLDOWN
	set_blackboard_key(BB_NPC_BOARDING_COOLDOWN_END, cooldown_end)

	// Play a taunt
	if(ship.wave_taunts && completed_wave <= length(ship.wave_taunts))
		var/list/taunts = ship.wave_taunts[completed_wave]
		if(length(taunts))
			var/taunt = pick(taunts)
			ship.ship_notify("[taunt]", "COMMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
			target.ship_notify("[ship.name]: \"[taunt]\"", "COMMS", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 50)

	// Notify about cooldown
	var/next_wave = completed_wave + 1
	target.ship_notify("Wave [completed_wave] repelled! Next wave in 30 seconds...", "COMBAT", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	// Schedule next wave
	addtimer(CALLBACK(src, PROC_REF(end_wave_cooldown), next_wave), NPC_BOARDING_WAVE_COOLDOWN)

/**
 * End the cooldown and launch the next wave.
 */
/datum/ai_controller/npc_ship/proc/end_wave_cooldown(next_wave)
	// Make sure we're still in cooldown state (could have escalated to combat)
	if(get_combat_state() != NPC_COMBAT_BOARDING_COOLDOWN)
		return

	var/obj/structure/overmap/ship/target = get_target()
	if(!target || QDELETED(target))
		return

	// Update wave number
	set_blackboard_key(BB_NPC_BOARDING_WAVE, next_wave)

	// Return to active boarding state
	set_combat_state(NPC_COMBAT_BOARDING)

	// Launch the wave
	launch_boarding_wave(next_wave)

/**
 * Start the cooldown before boss spawns.
 * Plays the boss taunt and announces boss arrival in 30 seconds.
 */
/datum/ai_controller/npc_ship/proc/start_boss_cooldown()
	var/obj/structure/overmap/ship/npc/pirate/ship = get_ship()
	var/obj/structure/overmap/ship/target = get_target()

	if(!ship || !target)
		return

	// Enter cooldown state (reuse boarding cooldown state)
	set_combat_state(NPC_COMBAT_BOARDING_COOLDOWN)

	// Set cooldown end time
	var/cooldown_end = world.time + NPC_BOARDING_WAVE_COOLDOWN
	set_blackboard_key(BB_NPC_BOARDING_COOLDOWN_END, cooldown_end)

	// Play boss spawn taunt
	if(ship.wave_taunts && length(ship.wave_taunts) >= 3)
		var/list/boss_taunts = ship.wave_taunts[3]
		if(length(boss_taunts))
			var/taunt = pick(boss_taunts)
			ship.ship_notify("[taunt]", "COMMS", SHIP_NOTIFY_WARNING, 'voidcrew/sound/alert2.ogg', 25)
			target.ship_notify("[ship.name]: \"[taunt]\"", "COMMS", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert3.ogg', 25)

	// Announce boss incoming
	target.ship_notify("All waves repelled! Enemy commander boarding in 30 seconds...", "COMBAT", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 50)

	// Schedule boss spawn
	addtimer(CALLBACK(src, PROC_REF(spawn_boarding_boss)), NPC_BOARDING_WAVE_COOLDOWN)

/**
 * Spawn the faction boss after all waves are defeated.
 */
/datum/ai_controller/npc_ship/proc/spawn_boarding_boss()
	// Guard against duplicate boss spawns
	if(blackboard[BB_NPC_BOARDING_BOSS])
		return

	var/obj/structure/overmap/ship/npc/pirate/ship = get_ship()
	var/obj/structure/overmap/ship/target = get_target()

	if(!ship || !target || QDELETED(target))
		return

	// Enter boss phase
	set_combat_state(NPC_COMBAT_BOSS_PHASE)

	// Find spawn location
	var/list/valid_turfs = get_target_spawn_turfs(target)
	if(!length(valid_turfs))
		return

	var/turf/spawn_loc = pick(valid_turfs)

	// Spawn the boss via heavy drop pod
	var/boss_type = ship.boss_type
	if(!boss_type)
		return

	// Create boss boarding pod - returns the boss for tracking
	// Pod handles parent_ship, AI controller swap, and patrol assignment
	var/mob/living/basic/trooper/pirate/faction/boss/boss = create_boss_boarding_pod(spawn_loc, target, ship, boss_type)
	if(boss)
		set_blackboard_key(BB_NPC_BOARDING_BOSS, boss)
		RegisterSignal(boss, COMSIG_LIVING_DEATH, PROC_REF(on_boss_death))

	// Announce boss arrival
	target.ship_notify("WARNING: Enemy Commander incoming via drop pod!", "SECURITY", SHIP_NOTIFY_DANGER, 'voidcrew/sound/warn3.ogg', 25)

/**
 * Signal handler for when the boss is killed.
 * This disables the pirate ship and allows players to board it.
 */
/datum/ai_controller/npc_ship/proc/on_boss_death(mob/living/victim, gibbed)
	SIGNAL_HANDLER
	UnregisterSignal(victim, COMSIG_LIVING_DEATH)

	INVOKE_ASYNC(src, PROC_REF(handle_boss_killed))

/**
 * Handle the boss being killed - disable the pirate ship.
 */
/datum/ai_controller/npc_ship/proc/handle_boss_killed()
	// Guard against duplicate processing
	if(get_combat_state() == NPC_COMBAT_DISABLED)
		return

	var/obj/structure/overmap/ship/npc/pirate/ship = get_ship()
	var/obj/structure/overmap/ship/target = get_target()

	SEND_SIGNAL(src, COMSIG_BOARDING_BOSS_KILLED)

	// Clean up boarding signals
	cleanup_boarding_signals()

	// Release the player - cancel weapons lock and interdiction
	if(target && ship && !QDELETED(target))
		// Notify target that weapons lock is released
		if(blackboard[BB_NPC_TARGET_LOCKED])
			SEND_SIGNAL(target, COMSIG_SHIP_WEAPONS_LOCK_LOST, ship)
		// Clear engagement tracking so other pirates can engage
		if(target.engaging_pirate_ref?.resolve() == ship)
			target.engaging_pirate_ref = null

	// Clear weapons lock
	clear_blackboard_key(BB_NPC_TARGET_LOCKED)
	clear_blackboard_key(BB_NPC_LOCK_START_TIME)

	// Cancel interdiction
	var/datum/npc_combat_interface/combat = get_combat_interface()
	combat?.cancel_interdiction()

	// Disable the pirate ship (this sends the notification to the player)
	ship?.set_disabled_state()

// ========== PLAYER CREW TRACKING ==========

/**
 * Start tracking player crew for the "pirates win" condition.
 * If all tracked crew die, pirates disengage victoriously.
 */
/datum/ai_controller/npc_ship/proc/start_tracking_player_crew(obj/structure/overmap/ship/target)
	if(!target?.shuttle?.shuttle_areas)
		return

	var/list/tracked_crew = list()

	for(var/area/shuttle_area as anything in target.shuttle.shuttle_areas)
		for(var/mob/living/carbon/human/H in shuttle_area)
			if(H.stat != DEAD && H.client)  // Only track player-controlled crew
				tracked_crew += H
				RegisterSignal(H, COMSIG_LIVING_DEATH, PROC_REF(on_player_crew_death))

	set_blackboard_key(BB_NPC_BOARDING_PLAYER_CREW, tracked_crew)

/**
 * Signal handler for when a tracked player crew member dies.
 */
/datum/ai_controller/npc_ship/proc/on_player_crew_death(mob/living/victim, gibbed)
	SIGNAL_HANDLER
	UnregisterSignal(victim, COMSIG_LIVING_DEATH)

	var/list/tracked_crew = blackboard[BB_NPC_BOARDING_PLAYER_CREW]
	if(tracked_crew)
		tracked_crew -= victim

	INVOKE_ASYNC(src, PROC_REF(check_player_crew_status))

/**
 * Check if all player crew are dead - pirates win!
 */
/datum/ai_controller/npc_ship/proc/check_player_crew_status()
	var/list/tracked_crew = blackboard[BB_NPC_BOARDING_PLAYER_CREW]
	if(!tracked_crew)
		return

	// Count living, connected players
	var/living_players = 0
	for(var/mob/living/carbon/human/H as anything in tracked_crew)
		if(!QDELETED(H) && H.stat != DEAD && H.client)
			living_players++

	if(living_players > 0)
		return

	// All players dead - pirates win!
	pirates_win()

/**
 * Pirates have won - all player crew eliminated.
 * Pirates disengage and leave.
 */
/datum/ai_controller/npc_ship/proc/pirates_win()
	var/obj/structure/overmap/ship/npc/pirate/ship = get_ship()
	var/obj/structure/overmap/ship/target = get_target()

	// Clean up
	cleanup_boarding_signals()

	// Announce victory
	ship?.ship_notify("All hostiles eliminated. Disengaging.", "COMBAT", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	target?.ship_notify("[ship?.name || "Hostile vessel"] has eliminated all crew and is disengaging.", "DEFEAT", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn3.ogg', 25)

	// Enter disengage state
	set_combat_state(NPC_COMBAT_DISENGAGING)

	// Schedule full disengage
	addtimer(CALLBACK(src, PROC_REF(complete_disengage)), NPC_BOARDING_DISENGAGE_DELAY)

/**
 * Complete the disengage - clear target and return to patrol.
 */
/datum/ai_controller/npc_ship/proc/complete_disengage()
	clear_target()
	set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_PATROL)

// ========== ESCALATION HANDLING ==========

/**
 * Signal handler for player locking weapons during boarding phase.
 * This escalates to full ship combat.
 */
/datum/ai_controller/npc_ship/proc/on_player_weapons_lock_during_boarding(datum/source, obj/structure/overmap/ship/aggressor)
	SIGNAL_HANDLER

	// Only escalate if we're in a boarding state
	var/combat_state = get_combat_state()
	if(combat_state != NPC_COMBAT_BOARDING && combat_state != NPC_COMBAT_BOARDING_COOLDOWN && combat_state != NPC_COMBAT_BOSS_PHASE)
		return

	INVOKE_ASYNC(src, PROC_REF(escalate_to_full_combat), aggressor)

/**
 * Escalate from boarding phase to full ship combat.
 * This happens when the player locks weapons on the pirate ship.
 */
/datum/ai_controller/npc_ship/proc/escalate_to_full_combat(obj/structure/overmap/ship/aggressor)
	var/obj/structure/overmap/ship/npc/pirate/ship = get_ship()
	var/obj/structure/overmap/ship/target = get_target()

	SEND_SIGNAL(src, COMSIG_BOARDING_ESCALATED)

	// Clean up boarding state
	cleanup_boarding_signals()

	// Clear any remaining boarders (they're now on their own)
	var/list/wave_boarders = blackboard[BB_NPC_BOARDING_WAVE_BOARDERS]
	if(wave_boarders)
		for(var/mob/living/boarder as anything in wave_boarders)
			UnregisterSignal(boarder, COMSIG_LIVING_DEATH)
	clear_blackboard_key(BB_NPC_BOARDING_WAVE_BOARDERS)

	// Clear boss tracking
	var/mob/living/boss = blackboard[BB_NPC_BOARDING_BOSS]
	if(boss && !QDELETED(boss))
		UnregisterSignal(boss, COMSIG_LIVING_DEATH)
	clear_blackboard_key(BB_NPC_BOARDING_BOSS)

	// Announce escalation
	ship?.ship_notify("Hostile action detected! Switching to weapons combat!", "COMBAT", SHIP_NOTIFY_WARNING, 'voidcrew/sound/alert2.ogg', 25)
	target?.ship_notify("[ship?.name || "Hostile vessel"] is responding to your aggression with ship weapons!", "COMBAT", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert3.ogg', 25)

	// Transition to standard combat
	set_combat_state(NPC_COMBAT_ENGAGING)

/**
 * Clean up all boarding-related signals and state.
 */
/datum/ai_controller/npc_ship/proc/cleanup_boarding_signals()
	var/obj/structure/overmap/ship/target = get_target()

	// Unregister from player weapons lock
	if(target && !QDELETED(target))
		UnregisterSignal(target, COMSIG_SHIP_WEAPONS_LOCKED)

	// Unregister from player crew deaths
	var/list/tracked_crew = blackboard[BB_NPC_BOARDING_PLAYER_CREW]
	if(tracked_crew)
		for(var/mob/living/crew as anything in tracked_crew)
			if(!QDELETED(crew))
				UnregisterSignal(crew, COMSIG_LIVING_DEATH)

	// Clear boarding blackboard keys
	clear_blackboard_key(BB_NPC_BOARDING_WAVE)
	clear_blackboard_key(BB_NPC_BOARDING_WAVE_BOARDERS)
	clear_blackboard_key(BB_NPC_BOARDING_COOLDOWN_END)
	clear_blackboard_key(BB_NPC_BOARDING_BOSS)
	clear_blackboard_key(BB_NPC_BOARDING_PLAYER_CREW)
	clear_blackboard_key(BB_NPC_BOARDING_INITIAL_CREW_COUNT)
	clear_blackboard_key(BB_NPC_BOARDING_WAVE_START_TIME)
	clear_blackboard_key(BB_NPC_BOARDING_TARGET_POS)

/**
 * Abort boarding operation entirely - target escaped to a different zone.
 * Cleans up all boarding state and returns to IDLE without a target.
 */
/datum/ai_controller/npc_ship/proc/abort_boarding()
	// Clean up boarding state
	cleanup_boarding_signals()

	// Clear any remaining boarders (unregister death signals)
	var/list/wave_boarders = blackboard[BB_NPC_BOARDING_WAVE_BOARDERS]
	if(wave_boarders)
		for(var/mob/living/boarder as anything in wave_boarders)
			if(!QDELETED(boarder))
				UnregisterSignal(boarder, COMSIG_LIVING_DEATH)
	clear_blackboard_key(BB_NPC_BOARDING_WAVE_BOARDERS)

	// Clear boss tracking
	var/mob/living/boss = blackboard[BB_NPC_BOARDING_BOSS]
	if(boss && !QDELETED(boss))
		UnregisterSignal(boss, COMSIG_LIVING_DEATH)
	clear_blackboard_key(BB_NPC_BOARDING_BOSS)

	// Fully disengage - clear target and return to idle
	clear_target()

/**
 * Escalate from boarding phase to ship combat due to player behavior.
 * Called when time limit exceeded, player moves, or player locks weapons.
 * The caller is responsible for sending appropriate messages before calling this.
 */
/datum/ai_controller/npc_ship/proc/escalate_boarding_to_combat(reason)
	SEND_SIGNAL(src, COMSIG_BOARDING_ESCALATED, reason)

	// Clean up boarding state
	cleanup_boarding_signals()

	// Clear any remaining boarders (they're now on their own)
	var/list/wave_boarders = blackboard[BB_NPC_BOARDING_WAVE_BOARDERS]
	if(wave_boarders)
		for(var/mob/living/boarder as anything in wave_boarders)
			if(!QDELETED(boarder))
				UnregisterSignal(boarder, COMSIG_LIVING_DEATH)
	clear_blackboard_key(BB_NPC_BOARDING_WAVE_BOARDERS)

	// Clear boss tracking
	var/mob/living/boss = blackboard[BB_NPC_BOARDING_BOSS]
	if(boss && !QDELETED(boss))
		UnregisterSignal(boss, COMSIG_LIVING_DEATH)
	clear_blackboard_key(BB_NPC_BOARDING_BOSS)

	// Transition to standard combat (will acquire lock then fight)
	set_combat_state(NPC_COMBAT_ENGAGING)

/**
 * Handle wave timeout - advance to next wave instead of escalating to combat.
 * Only escalate to ship combat if ALL waves time out (none defeated).
 */
/datum/ai_controller/npc_ship/proc/handle_wave_timeout()
	var/obj/structure/overmap/ship/npc/pirate/ship = get_ship()
	var/obj/structure/overmap/ship/target = get_target()
	var/current_wave = blackboard[BB_NPC_BOARDING_WAVE] || 1

	if(!ship || !target)
		return

	// Clean up current wave boarders
	var/list/wave_boarders = blackboard[BB_NPC_BOARDING_WAVE_BOARDERS]
	if(wave_boarders)
		for(var/mob/living/boarder as anything in wave_boarders)
			if(!QDELETED(boarder))
				UnregisterSignal(boarder, COMSIG_LIVING_DEATH)
	clear_blackboard_key(BB_NPC_BOARDING_WAVE_BOARDERS)

	// Check if this was the final wave
	if(current_wave >= NPC_BOARDING_WAVE_COUNT)
		// All waves timed out - escalate to boss phase
		ship.ship_notify("Time's up! Sending in the heavy hitter!", "COMBAT", SHIP_NOTIFY_WARNING, 'voidcrew/sound/alert2.ogg', 25)
		target.ship_notify("[ship.name]: \"You've stalled long enough. Meet our enforcer.\"", "COMMS", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert3.ogg', 25)
		start_boss_cooldown()
		return

	// Advance to next wave
	var/next_wave = current_wave + 1
	ship.ship_notify("Wave [current_wave] timed out. Sending wave [next_wave]!", "COMBAT", SHIP_NOTIFY_WARNING)
	target.ship_notify("[ship.name]: \"Your stalling won't save you. More incoming!\"", "COMMS", SHIP_NOTIFY_WARNING)

	// Start cooldown for next wave
	set_combat_state(NPC_COMBAT_BOARDING_COOLDOWN)
	var/cooldown_end = world.time + NPC_BOARDING_WAVE_COOLDOWN
	set_blackboard_key(BB_NPC_BOARDING_COOLDOWN_END, cooldown_end)
	set_blackboard_key(BB_NPC_BOARDING_WAVE_START_TIME, null)

	// Schedule next wave
	addtimer(CALLBACK(src, PROC_REF(end_wave_cooldown), next_wave), NPC_BOARDING_WAVE_COOLDOWN)

/**
 * Check if any boarders have fallen into space and clean them up.
 * This prevents boarders from being "stuck" floating in space after being spaced.
 */
/datum/ai_controller/npc_ship/proc/check_boarders_in_space()
	var/list/wave_boarders = blackboard[BB_NPC_BOARDING_WAVE_BOARDERS]
	if(!wave_boarders || !length(wave_boarders))
		return

	var/list/spaced_boarders = list()
	for(var/mob/living/boarder as anything in wave_boarders)
		if(QDELETED(boarder))
			continue
		var/turf/boarder_turf = get_turf(boarder)
		if(!boarder_turf)
			continue
		// Check if boarder is in space (not on a ship)
		if(isspaceturf(boarder_turf) || istype(get_area(boarder_turf), /area/space))
			spaced_boarders += boarder

	// Kill spaced boarders (they suffocate in space anyway)
	for(var/mob/living/spaced as anything in spaced_boarders)
		if(!QDELETED(spaced) && spaced.stat != DEAD)
			spaced.death()
			wave_boarders -= spaced
			UnregisterSignal(spaced, COMSIG_LIVING_DEATH)
