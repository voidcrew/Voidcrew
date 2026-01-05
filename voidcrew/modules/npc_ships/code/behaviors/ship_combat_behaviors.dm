/**
 * Base NPC Ship Behavior
 *
 * Parent class for all NPC ship combat behaviors.
 * These behaviors don't require movement (ships use overmap velocity).
 */
/datum/ai_behavior/npc_ship
	/// Ships don't need movement but need to allow planning during execution
	/// so SelectBehaviors can queue additional behaviors while we're running
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION
	/// Fast tick rate for responsive combat
	action_cooldown = 0.5 SECONDS

/**
 * Helper to get the ship from the controller.
 */
/datum/ai_behavior/npc_ship/proc/get_ship(datum/ai_controller/npc_ship/controller)
	return controller?.get_ship()

/**
 * Helper to get combat interface.
 */
/datum/ai_behavior/npc_ship/proc/get_combat_interface(datum/ai_controller/npc_ship/controller)
	return controller?.get_combat_interface()

// ========== SCAN THREATS ==========

/**
 * Scans for nearby player ships within territory range.
 * If a target is found in IDLE state, transitions to ENGAGING.
 * Only engages in zones where weapons are allowed.
 */
/datum/ai_behavior/npc_ship/scan_threats
	action_cooldown = 1 SECONDS

/datum/ai_behavior/npc_ship/scan_threats/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	if(!ship)
		log_shuttle("NPC SHIP AI: scan_threats - no ship found!")
		return AI_BEHAVIOR_DELAY

	// Only attack in zones where weapons are allowed
	if(!SSovermap_zones.weapons_allowed_at(ship))
		// If we had a target, clear it since we can't fight here
		if(controller.get_target())
			controller.clear_target()
		log_shuttle("NPC SHIP AI: [ship.name] - weapons not allowed in current zone")
		return AI_BEHAVIOR_DELAY

	// Get our current target (if any)
	var/obj/structure/overmap/ship/current_target = controller.get_target()

	// If we already have a valid target, don't scan for new ones
	if(current_target && !QDELETED(current_target))
		// Verify target is still in range
		var/target_dist = get_dist(ship, current_target)
		if(target_dist <= ship.territory_range)
			log_shuttle("NPC SHIP AI: [ship.name] - already tracking [current_target.name] (dist=[target_dist], state=[controller.get_combat_state()])")
			return AI_BEHAVIOR_DELAY
		// Target out of range - will be handled by disengage behavior
		log_shuttle("NPC SHIP AI: [ship.name] - target [current_target.name] drifted out of range (dist=[target_dist])")

	// Scan for player ships in territory range
	var/turf/our_turf = get_turf(ship)
	if(!our_turf)
		log_shuttle("NPC SHIP AI: [ship.name] - no turf found!")
		return AI_BEHAVIOR_DELAY

	var/ships_checked = 0
	for(var/obj/structure/overmap/ship/potential_target in range(ship.territory_range, our_turf))
		ships_checked++
		// Skip ourselves
		if(potential_target == ship)
			continue

		// Skip other NPC ships (for now - no faction wars)
		if(istype(potential_target, /obj/structure/overmap/ship/npc))
			continue

		// Skip ships that aren't flying
		if(potential_target.state != OVERMAP_SHIP_FLYING)
			log_shuttle("NPC SHIP AI: [ship.name] - skipping [potential_target.name], state=[potential_target.state] not FLYING")
			continue

		// Found a valid target!
		log_shuttle("NPC SHIP AI: [ship.name] - TARGETING [potential_target.name]!")
		controller.set_target(potential_target)
		controller.set_combat_state(NPC_COMBAT_ENGAGING)

		// Notify the target that they're being targeted
		SEND_SIGNAL(potential_target, COMSIG_SHIP_BEING_TARGETED, ship)

		return AI_BEHAVIOR_DELAY

	if(ships_checked == 0)
		log_shuttle("NPC SHIP AI: [ship.name] - no ships in range [ship.territory_range] at ([our_turf.x],[our_turf.y])")

	return AI_BEHAVIOR_DELAY

// ========== ACQUIRE LOCK ==========

/**
 * Works on acquiring a weapon lock on the target.
 * After NPC_SHIP_LOCK_TIME seconds, transitions to COMBAT state.
 */
/datum/ai_behavior/npc_ship/acquire_lock
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/npc_ship/acquire_lock/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()
	log_shuttle("NPC SHIP AI: acquire_lock::perform called")

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/obj/structure/overmap/ship/target = controller.get_target()

	if(!ship || !target || QDELETED(target))
		log_shuttle("NPC SHIP AI: [ship] acquire_lock - no valid target (ship=[ship], target=[target])")
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check if already locked
	if(controller.blackboard[BB_NPC_TARGET_LOCKED])
		return AI_BEHAVIOR_DELAY

	// Check if we've started the lock
	var/lock_start = controller.blackboard[BB_NPC_LOCK_START_TIME]
	if(!lock_start)
		// Start the lock
		log_shuttle("NPC SHIP AI: [ship.name] - Starting weapon lock on [target.name]")
		controller.set_blackboard_key(BB_NPC_LOCK_START_TIME, world.time)
		return AI_BEHAVIOR_DELAY

	// Check if lock is complete
	if(world.time >= lock_start + NPC_SHIP_LOCK_TIME)
		// Lock acquired!
		log_shuttle("NPC SHIP AI: [ship.name] - WEAPONS LOCKED on [target.name]!")
		controller.set_blackboard_key(BB_NPC_TARGET_LOCKED, TRUE)
		controller.set_combat_state(NPC_COMBAT_COMBAT)

		// Notify the target
		SEND_SIGNAL(target, COMSIG_SHIP_WEAPONS_LOCKED, ship)

		// Announce to target ship
		target.ship_announce(
			"WARNING: Hostile weapons lock detected from [ship.name]!",
			"THREAT ALERT",
			sound('sound/effects/alert.ogg')
		)

	return AI_BEHAVIOR_DELAY

// ========== FIRE WEAPONS ==========

/**
 * Handles weapon firing logic.
 * - If target has shields: use lasers (effective vs shields)
 * - If target shields are down: use missiles (effective vs hull)
 */
/datum/ai_behavior/npc_ship/fire_weapons
	action_cooldown = 1 SECONDS

/datum/ai_behavior/npc_ship/fire_weapons/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/datum/npc_combat_interface/combat = get_combat_interface(controller)
	var/obj/structure/overmap/ship/target = controller.get_target()

	if(!ship || !combat || !target || QDELETED(target))
		log_shuttle("NPC SHIP AI: fire_weapons - missing ship/combat/target")
		return AI_BEHAVIOR_DELAY

	// Check if weapons are allowed in this zone
	if(!SSovermap_zones.weapons_allowed_at(ship))
		log_shuttle("NPC SHIP AI: [ship.name] - weapons not allowed, can't fire")
		return AI_BEHAVIOR_DELAY

	// Determine weapon choice based on target shield status
	var/target_has_shields = target.shields_active && target.shield_health > 0

	log_shuttle("NPC SHIP AI: [ship.name] - attempting to fire at [target.name] (shields: [target_has_shields])")

	if(target_has_shields)
		// Target has shields - use lasers (effective vs shields)
		try_fire_lasers(ship, combat, target)
	else
		// Target shields down - use missiles (effective vs hull)
		try_fire_missiles(ship, combat, target)

	return AI_BEHAVIOR_DELAY

/**
 * Attempts to fire lasers at the target.
 */
/datum/ai_behavior/npc_ship/fire_weapons/proc/try_fire_lasers(obj/structure/overmap/ship/npc/ship, datum/npc_combat_interface/combat, obj/structure/overmap/ship/target)
	// Check cooldown
	if(!COOLDOWN_FINISHED(ship, laser_cooldown))
		return FALSE

	var/working_lasers = combat.get_working_laser_count()
	if(working_lasers < 1)
		return FALSE

	// Decide whether to fire all or single
	var/fire_all = FALSE
	if(working_lasers >= 2)
		// 60% chance to fire all, 40% chance to fire single
		fire_all = prob(60)

	// Fire!
	if(combat.fire_lasers(target, fire_all))
		COOLDOWN_START(ship, laser_cooldown, NPC_LASER_COOLDOWN)
		return TRUE

	return FALSE

/**
 * Attempts to fire missiles at the target.
 */
/datum/ai_behavior/npc_ship/fire_weapons/proc/try_fire_missiles(obj/structure/overmap/ship/npc/ship, datum/npc_combat_interface/combat, obj/structure/overmap/ship/target)
	// Check cooldown
	if(!COOLDOWN_FINISHED(ship, missile_cooldown))
		// Fallback to lasers if available
		try_fire_lasers(ship, combat, target)
		return FALSE

	if(combat.get_working_launcher_count() < 1)
		// No launchers, try lasers instead
		try_fire_lasers(ship, combat, target)
		return FALSE

	// Fire missile (random type)
	if(combat.fire_missile(target))
		COOLDOWN_START(ship, missile_cooldown, NPC_MISSILE_COOLDOWN)
		return TRUE

	return FALSE

// ========== USE INTERDICTOR ==========

/**
 * Attempts to use the interdictor on a fleeing target.
 * Only activates if the target has velocity (trying to escape).
 */
/datum/ai_behavior/npc_ship/use_interdictor
	action_cooldown = 2 SECONDS

/datum/ai_behavior/npc_ship/use_interdictor/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/datum/npc_combat_interface/combat = get_combat_interface(controller)
	var/obj/structure/overmap/ship/target = controller.get_target()

	if(!ship || !combat || !target || QDELETED(target))
		return AI_BEHAVIOR_DELAY

	// Check if we have a working interdictor
	if(!combat.has_working_interdictor())
		return AI_BEHAVIOR_DELAY

	// Check if target is already interdicted
	if(target.is_interdicted)
		return AI_BEHAVIOR_DELAY

	// Check if target is moving (trying to escape)
	if(target.speed[1] == 0 && target.speed[2] == 0)
		return AI_BEHAVIOR_DELAY

	// Try to interdict!
	combat.start_interdiction(target)

	return AI_BEHAVIOR_DELAY

// ========== CHECK DISENGAGE ==========

/**
 * Checks if the target has moved out of territory range.
 * If so, clears the target and returns to IDLE state.
 */
/datum/ai_behavior/npc_ship/check_disengage
	action_cooldown = 1 SECONDS

/datum/ai_behavior/npc_ship/check_disengage/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/obj/structure/overmap/ship/target = controller.get_target()

	// No target means nothing to disengage from
	if(!target || QDELETED(target))
		if(controller.get_combat_state() != NPC_COMBAT_IDLE)
			log_shuttle("NPC SHIP AI: [ship] check_disengage - target gone, clearing")
			controller.clear_target()
		return AI_BEHAVIOR_DELAY

	if(!ship)
		return AI_BEHAVIOR_DELAY

	// Check distance to target
	var/target_dist = get_dist(ship, target)

	// If target is out of range, disengage
	if(target_dist > ship.territory_range)
		log_shuttle("NPC SHIP AI: [ship.name] - target [target.name] out of range (dist=[target_dist], range=[ship.territory_range]), disengaging")
		// Notify target that we stopped targeting them
		SEND_SIGNAL(target, COMSIG_SHIP_TARGETING_STOPPED, ship)

		controller.clear_target()

	return AI_BEHAVIOR_DELAY
