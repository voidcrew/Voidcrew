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
		return AI_BEHAVIOR_DELAY

	// Non-hostile ships don't actively scan for targets
	if(!ship.hostile)
		return AI_BEHAVIOR_DELAY

	// Only attack in zones where weapons are allowed
	if(!SSovermap_zones.weapons_allowed_at(ship))
		// If we had a target, clear it since we can't fight here
		if(controller.get_target())
			controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Get our current target (if any)
	var/obj/structure/overmap/ship/current_target = controller.get_target()

	// If we already have a valid target, don't scan for new ones
	if(current_target && !QDELETED(current_target))
		// Verify target is still in range
		var/target_dist = get_dist(ship, current_target)
		if(target_dist <= ship.territory_range)
			return AI_BEHAVIOR_DELAY
		// Target out of range - will be handled by disengage behavior

	// Scan for player ships in territory range
	// Use SSovermap.simulated_ships + get_dist() instead of range() for better performance
	for(var/obj/structure/overmap/ship/potential_target as anything in SSovermap.simulated_ships)
		// Skip ourselves
		if(potential_target == ship)
			continue

		// Skip other NPC ships (for now - no faction wars)
		if(istype(potential_target, /obj/structure/overmap/ship/npc))
			continue

		// Skip ships that aren't flying
		if(potential_target.state != OVERMAP_SHIP_FLYING)
			continue

		// Check distance (O(1) instead of range()'s O(tiles))
		if(get_dist(ship, potential_target) > ship.territory_range)
			continue

		// Found a valid target!
		controller.set_target(potential_target)
		controller.set_combat_state(NPC_COMBAT_ENGAGING)

		// Notify the target that they're being targeted
		SEND_SIGNAL(potential_target, COMSIG_SHIP_BEING_TARGETED, ship)

		return AI_BEHAVIOR_DELAY

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

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/obj/structure/overmap/ship/target = controller.get_target()

	if(!ship || !target || QDELETED(target))
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check if already locked
	if(controller.blackboard[BB_NPC_TARGET_LOCKED])
		return AI_BEHAVIOR_DELAY

	// Check if we've started the lock
	var/lock_start = controller.blackboard[BB_NPC_LOCK_START_TIME]
	if(!lock_start)
		// Start the lock - alert the target ship (like combat console does)
		target.ship_announce(
			"Hostile ship acquiring weapons lock!",
			"WARNING",
			FALSE,
			sound('sound/effects/alert.ogg')
		)
		controller.set_blackboard_key(BB_NPC_LOCK_START_TIME, world.time)
		return AI_BEHAVIOR_DELAY

	// Check if lock is complete (uses per-ship lock time)
	if(world.time >= lock_start + ship.lock_time)
		// Lock acquired!
		controller.set_blackboard_key(BB_NPC_TARGET_LOCKED, TRUE)
		controller.set_combat_state(NPC_COMBAT_COMBAT)

		// Notify the target via signal (for cloak device etc)
		SEND_SIGNAL(target, COMSIG_SHIP_WEAPONS_LOCKED, ship)

		// Announce lock complete to target ship
		target.ship_announce(
			"WARNING: Hostile weapons lock detected from [ship.name]!",
			"THREAT ALERT",
			FALSE,
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
		return AI_BEHAVIOR_DELAY

	// Check if weapons are allowed in this zone
	if(!SSovermap_zones.weapons_allowed_at(ship))
		return AI_BEHAVIOR_DELAY

	// Determine weapon choice based on target shield status
	var/target_has_shields = target.shields_active && target.shield_health > 0

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

	// Fire! (uses per-ship laser cooldown)
	if(combat.fire_lasers(target, fire_all))
		COOLDOWN_START(ship, laser_cooldown, ship.laser_cooldown_time)
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

	var/launcher_count = combat.get_working_launcher_count()
	if(launcher_count < 1)
		// No launchers, try lasers instead
		try_fire_lasers(ship, combat, target)
		return FALSE

	// Fire missile (uses per-ship missile cooldown)
	if(combat.fire_missile(target))
		COOLDOWN_START(ship, missile_cooldown, ship.missile_cooldown_time)
		return TRUE

	return FALSE

// ========== USE INTERDICTOR ==========

/**
 * Attempts to use the interdictor on the target.
 * NPCs will aggressively interdict to prevent escape.
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

	// Try to interdict! (aggressively - don't wait for target to start moving)
	combat.start_interdiction(target)

	return AI_BEHAVIOR_DELAY

// ========== CHECK DISENGAGE ==========

/**
 * Checks if the target has moved out of territory range, left our zone, or crashed.
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
			controller.clear_target()
		return AI_BEHAVIOR_DELAY

	if(!ship)
		return AI_BEHAVIOR_DELAY

	// Check if target has crashed (no longer flying) - don't attack crashed ships
	if(target.state != OVERMAP_SHIP_FLYING)
		SEND_SIGNAL(target, COMSIG_SHIP_TARGETING_STOPPED, ship)
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check if target escaped to a different zone
	var/spawn_zone = controller.blackboard[BB_NPC_SPAWN_ZONE]
	if(spawn_zone)
		var/turf/target_turf = get_turf(target)
		if(target_turf)
			var/target_zone = SSovermap_zones.get_zone(target_turf)
			if(target_zone != spawn_zone)
				SEND_SIGNAL(target, COMSIG_SHIP_TARGETING_STOPPED, ship)
				controller.clear_target()
				return AI_BEHAVIOR_DELAY

	// Check distance to target
	var/target_dist = get_dist(ship, target)

	// If target is out of range, disengage
	if(target_dist > ship.territory_range)
		// Notify target that we stopped targeting them
		SEND_SIGNAL(target, COMSIG_SHIP_TARGETING_STOPPED, ship)
		controller.clear_target()

	return AI_BEHAVIOR_DELAY
