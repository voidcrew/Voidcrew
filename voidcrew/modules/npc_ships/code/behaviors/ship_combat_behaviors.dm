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
		log_shuttle("NPC SCAN: No ship!")
		return AI_BEHAVIOR_DELAY

	log_shuttle("NPC SCAN: ship=[ship] territory_range=[ship.territory_range]")

	// Only attack in zones where weapons are allowed
	if(!SSovermap_zones.weapons_allowed_at(ship))
		log_shuttle("NPC SCAN: Weapons not allowed at our location")
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
		log_shuttle("NPC SCAN: Have target [current_target] at dist=[target_dist]")
		if(target_dist <= ship.territory_range)
			return AI_BEHAVIOR_DELAY
		log_shuttle("NPC SCAN: Target out of territory range!")
		// Target out of range - will be handled by disengage behavior

	// Scan for player ships in territory range
	var/turf/our_turf = get_turf(ship)
	if(!our_turf)
		return AI_BEHAVIOR_DELAY

	log_shuttle("NPC SCAN: Scanning range [ship.territory_range] from ([our_turf.x],[our_turf.y])")
	var/ships_found = 0

	for(var/obj/structure/overmap/ship/potential_target in range(ship.territory_range, our_turf))
		ships_found++
		// Skip ourselves
		if(potential_target == ship)
			log_shuttle("NPC SCAN: Skipping self")
			continue

		// Skip other NPC ships (for now - no faction wars)
		if(istype(potential_target, /obj/structure/overmap/ship/npc))
			log_shuttle("NPC SCAN: Skipping NPC ship [potential_target]")
			continue

		// Skip ships that aren't flying
		if(potential_target.state != OVERMAP_SHIP_FLYING)
			log_shuttle("NPC SCAN: Skipping [potential_target] - not flying (state=[potential_target.state])")
			continue

		// Found a valid target!
		log_shuttle("NPC SCAN: FOUND TARGET [potential_target]!")
		controller.set_target(potential_target)
		controller.set_combat_state(NPC_COMBAT_ENGAGING)

		// Notify the target that they're being targeted
		SEND_SIGNAL(potential_target, COMSIG_SHIP_BEING_TARGETED, ship)

		return AI_BEHAVIOR_DELAY

	log_shuttle("NPC SCAN: Checked [ships_found] ships, no valid targets found")
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

	log_shuttle("NPC LOCK: ship=[ship] target=[target]")

	if(!ship || !target || QDELETED(target))
		log_shuttle("NPC LOCK: No ship or target, clearing")
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check if already locked
	if(controller.blackboard[BB_NPC_TARGET_LOCKED])
		log_shuttle("NPC LOCK: Already locked!")
		return AI_BEHAVIOR_DELAY

	// Check if we've started the lock
	var/lock_start = controller.blackboard[BB_NPC_LOCK_START_TIME]
	if(!lock_start)
		log_shuttle("NPC LOCK: Starting lock on [target]")
		// Start the lock - alert the target ship (like combat console does)
		target.ship_announce(
			"Hostile ship acquiring weapons lock!",
			"WARNING",
			FALSE,
			sound('sound/effects/alert.ogg')
		)
		controller.set_blackboard_key(BB_NPC_LOCK_START_TIME, world.time)
		return AI_BEHAVIOR_DELAY

	// Check if lock is complete
	var/lock_time = world.time - lock_start
	log_shuttle("NPC LOCK: Lock progress [lock_time]/[NPC_SHIP_LOCK_TIME]")

	if(world.time >= lock_start + NPC_SHIP_LOCK_TIME)
		// Lock acquired!
		log_shuttle("NPC LOCK: LOCK ACQUIRED on [target]!")
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

	log_shuttle("NPC FIRE: ship=[ship] combat=[combat] target=[target]")

	if(!ship || !combat || !target || QDELETED(target))
		log_shuttle("NPC FIRE: Missing ship, combat interface, or target")
		return AI_BEHAVIOR_DELAY

	// Check if weapons are allowed in this zone
	if(!SSovermap_zones.weapons_allowed_at(ship))
		log_shuttle("NPC FIRE: Weapons not allowed at location")
		return AI_BEHAVIOR_DELAY

	// Determine weapon choice based on target shield status
	var/target_has_shields = target.shields_active && target.shield_health > 0
	log_shuttle("NPC FIRE: Target shields=[target_has_shields] (active=[target.shields_active] health=[target.shield_health])")

	if(target_has_shields)
		// Target has shields - use lasers (effective vs shields)
		log_shuttle("NPC FIRE: Using LASERS (target has shields)")
		try_fire_lasers(ship, combat, target)
	else
		// Target shields down - use missiles (effective vs hull)
		log_shuttle("NPC FIRE: Using MISSILES (shields down)")
		try_fire_missiles(ship, combat, target)

	return AI_BEHAVIOR_DELAY

/**
 * Attempts to fire lasers at the target.
 */
/datum/ai_behavior/npc_ship/fire_weapons/proc/try_fire_lasers(obj/structure/overmap/ship/npc/ship, datum/npc_combat_interface/combat, obj/structure/overmap/ship/target)
	// Check cooldown
	if(!COOLDOWN_FINISHED(ship, laser_cooldown))
		log_shuttle("NPC FIRE LASER: On cooldown")
		return FALSE

	var/working_lasers = combat.get_working_laser_count()
	log_shuttle("NPC FIRE LASER: Working lasers=[working_lasers]")
	if(working_lasers < 1)
		log_shuttle("NPC FIRE LASER: No working lasers!")
		return FALSE

	// Decide whether to fire all or single
	var/fire_all = FALSE
	if(working_lasers >= 2)
		// 60% chance to fire all, 40% chance to fire single
		fire_all = prob(60)

	// Fire!
	log_shuttle("NPC FIRE LASER: Firing [fire_all ? "ALL" : "SINGLE"] at [target]")
	if(combat.fire_lasers(target, fire_all))
		log_shuttle("NPC FIRE LASER: SUCCESS!")
		COOLDOWN_START(ship, laser_cooldown, NPC_LASER_COOLDOWN)
		return TRUE

	log_shuttle("NPC FIRE LASER: FAILED!")
	return FALSE

/**
 * Attempts to fire missiles at the target.
 */
/datum/ai_behavior/npc_ship/fire_weapons/proc/try_fire_missiles(obj/structure/overmap/ship/npc/ship, datum/npc_combat_interface/combat, obj/structure/overmap/ship/target)
	// Check cooldown
	if(!COOLDOWN_FINISHED(ship, missile_cooldown))
		log_shuttle("NPC FIRE MISSILE: On cooldown, trying lasers instead")
		// Fallback to lasers if available
		try_fire_lasers(ship, combat, target)
		return FALSE

	var/launcher_count = combat.get_working_launcher_count()
	log_shuttle("NPC FIRE MISSILE: Working launchers=[launcher_count]")
	if(launcher_count < 1)
		log_shuttle("NPC FIRE MISSILE: No working launchers, trying lasers")
		// No launchers, try lasers instead
		try_fire_lasers(ship, combat, target)
		return FALSE

	// Fire missile (random type)
	log_shuttle("NPC FIRE MISSILE: Firing at [target]")
	if(combat.fire_missile(target))
		log_shuttle("NPC FIRE MISSILE: SUCCESS!")
		COOLDOWN_START(ship, missile_cooldown, NPC_MISSILE_COOLDOWN)
		return TRUE

	log_shuttle("NPC FIRE MISSILE: FAILED!")
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
	log_shuttle("NPC INTERDICT: Attempting to interdict [target]")
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
			log_shuttle("NPC DISENGAGE: No target, clearing combat state")
			controller.clear_target()
		return AI_BEHAVIOR_DELAY

	if(!ship)
		return AI_BEHAVIOR_DELAY

	// Check distance to target
	var/target_dist = get_dist(ship, target)

	// If target is out of range, disengage
	if(target_dist > ship.territory_range)
		log_shuttle("NPC DISENGAGE: Target [target] out of range (dist=[target_dist] max=[ship.territory_range])")
		// Notify target that we stopped targeting them
		SEND_SIGNAL(target, COMSIG_SHIP_TARGETING_STOPPED, ship)
		controller.clear_target()

	return AI_BEHAVIOR_DELAY
