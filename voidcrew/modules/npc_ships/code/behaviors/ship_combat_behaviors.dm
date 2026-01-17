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

/**
 * Check if another pirate is already hailing or negotiating with the target.
 * Only one pirate can hail/negotiate with a ship at a time.
 */
/datum/ai_behavior/npc_ship/proc/is_target_being_hailed(obj/structure/overmap/ship/target, obj/structure/overmap/ship/npc/self)
	for(var/obj/structure/overmap/ship/npc/pirate/other_pirate as anything in SSnpc_ships.active_ships)
		if(other_pirate == self)
			continue
		if(!istype(other_pirate))
			continue
		var/datum/ai_controller/npc_ship/other_controller = other_pirate.ai_controller
		if(!other_controller)
			continue
		// Check if this other pirate is hailing or negotiating with our target
		var/other_state = other_controller.get_combat_state()
		if(other_state == NPC_COMBAT_HAILING || other_state == NPC_COMBAT_NEGOTIATING)
			if(other_controller.get_target() == target)
				return TRUE
	return FALSE

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

	// Only attack in zones where combat is allowed (weapons OR interdiction)
	var/turf/ship_loc = get_turf(ship)
	var/datum/overmap_zone/zone = SSovermap_zones.get_zone(ship_loc)
	var/can_fight = zone ? (zone.weapons_allowed() || zone.interdiction_allowed()) : TRUE
	if(!can_fight)
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

		// Skip cloaked ships - can't detect them
		if(potential_target.invisibility > INVISIBILITY_NONE)
			continue

		// Skip targets already engaged by another pirate (only one pirate can engage at a time)
		var/obj/structure/overmap/ship/npc/engaging_pirate = potential_target.engaging_pirate_ref?.resolve()
		if(engaging_pirate && engaging_pirate != ship && !QDELETED(engaging_pirate))
			continue

		// Skip targets that have recently paid tribute (immunity)
		if(controller.has_tribute_immunity(potential_target))
			continue

		// Check distance (O(1) instead of range()'s O(tiles))
		if(get_dist(ship, potential_target) > ship.territory_range)
			continue

		// Skip targets we can't see (blocked by nebula)
		if(!ship.has_los_to(potential_target))
			continue

		// Skip targets in zones where combat isn't allowed (green space protection)
		var/turf/target_loc = get_turf(potential_target)
		var/datum/overmap_zone/target_zone = SSovermap_zones.get_zone(target_loc)
		var/target_can_be_attacked = target_zone ? (target_zone.weapons_allowed() || target_zone.interdiction_allowed()) : TRUE
		if(!target_can_be_attacked)
			continue

		// If this ship scans before engaging, check if we recently scanned this target
		if(ship.scan_before_engage)
			var/list/scanned_ships = controller.blackboard[BB_NPC_SCANNED_SHIPS]
			if(scanned_ships)
				var/scanned_time = scanned_ships[REF(potential_target)]
				if(scanned_time && (world.time - scanned_time) < NPC_SCAN_MEMORY_TIME)
					continue  // Skip - we scanned this ship recently

		// Found a valid target!
		log_shuttle("NPC_SHIP: [ship.name] targeting [potential_target.name] - dist=[get_dist(ship, potential_target)], territory=[ship.territory_range]")
		controller.set_target(potential_target)

		// If this ship scans before engaging, go to SCANNING first
		if(ship.scan_before_engage)
			controller.set_combat_state(NPC_COMBAT_SCANNING)
			controller.blackboard[BB_NPC_SCAN_START_TIME] = world.time
			controller.blackboard[BB_NPC_SCAN_COMPLETE] = FALSE
			controller.blackboard[BB_NPC_SCAN_ANNOUNCED] = FALSE
		// If this pirate accepts negotiation, go to HAILING first (give player chance to respond)
		else if(istype(ship, /obj/structure/overmap/ship/npc/pirate))
			var/obj/structure/overmap/ship/npc/pirate/pirate_ship = ship
			// Only hail if no other pirate is already hailing/negotiating with this target
			if(pirate_ship.accepts_negotiation && !is_target_being_hailed(potential_target, ship))
				controller.set_combat_state(NPC_COMBAT_HAILING)
				controller.clear_blackboard_key(BB_NPC_HAILING_START)
				controller.clear_blackboard_key(BB_NPC_HAILING_ANNOUNCED)
			else
				controller.set_combat_state(NPC_COMBAT_ENGAGING)
		else
			controller.set_combat_state(NPC_COMBAT_ENGAGING)

		// Notify the target that they're being targeted
		SEND_SIGNAL(potential_target, COMSIG_SHIP_BEING_TARGETED, ship)

		return AI_BEHAVIOR_DELAY

	return AI_BEHAVIOR_DELAY

// ========== SCAN WEALTH ==========

/**
 * Scans the target ship for wealth before engaging.
 * Used by yellow zone pirates to check if target is worth robbing.
 * After scan completes, either engages (has money) or ignores (broke).
 */
/datum/ai_behavior/npc_ship/scan_wealth
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/npc_ship/scan_wealth/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/obj/structure/overmap/ship/target = controller.get_target()

	if(!ship || !target || QDELETED(target))
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check if scan is complete
	var/scan_start = controller.blackboard[BB_NPC_SCAN_START_TIME]
	if(!scan_start)
		// Shouldn't happen, but reset
		controller.blackboard[BB_NPC_SCAN_START_TIME] = world.time
		return AI_BEHAVIOR_DELAY

	// Announce scan start (only once)
	if(!controller.blackboard[BB_NPC_SCAN_ANNOUNCED])
		controller.blackboard[BB_NPC_SCAN_ANNOUNCED] = TRUE
		ship.ship_notify("Initiating financial scan of [target.name]...", "SCANNER", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg')
		target.ship_notify("[ship.name] is scanning our financial systems!", "SECURITY", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn4.ogg')
		// Start looping scan sound on target ship
		start_scan_sound(target)

	var/elapsed = world.time - scan_start
	if(elapsed < ship.scan_time)
		// Still scanning - just wait
		return AI_BEHAVIOR_DELAY

	// Scan complete! Stop the scan sound
	stop_scan_sound(target)

	// Record this ship as scanned
	controller.blackboard[BB_NPC_SCAN_COMPLETE] = TRUE
	var/list/scanned_ships = controller.blackboard[BB_NPC_SCANNED_SHIPS]
	if(!scanned_ships)
		scanned_ships = list()
		controller.blackboard[BB_NPC_SCANNED_SHIPS] = scanned_ships
	scanned_ships[REF(target)] = world.time

	// Check target's wealth
	var/target_wealth = target.ship_account?.account_balance || 0

	if(target_wealth >= ship.min_target_wealth)
		// Target has money - proceed to hailing or engaging
		ship.ship_notify("Scan complete. Target has [target_wealth] credits.", "SCANNER", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg')

		// If this pirate accepts negotiation, go to HAILING first (give player chance to respond)
		// But only if no other pirate is already hailing/negotiating with this target
		if(istype(ship, /obj/structure/overmap/ship/npc/pirate))
			var/obj/structure/overmap/ship/npc/pirate/pirate_ship = ship
			if(pirate_ship.accepts_negotiation && !is_target_being_hailed(target, ship))
				target.ship_notify("[ship.name] is hailing your vessel!", "SECURITY", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn2.ogg')
				controller.set_combat_state(NPC_COMBAT_HAILING)
				controller.clear_blackboard_key(BB_NPC_HAILING_START)
				controller.clear_blackboard_key(BB_NPC_HAILING_ANNOUNCED)
				return AI_BEHAVIOR_DELAY

		// Otherwise engage directly (or another pirate is already hailing)
		target.ship_notify("Hostile vessel has completed scan and is engaging!", "SECURITY", SHIP_NOTIFY_DANGER)
		controller.set_combat_state(NPC_COMBAT_ENGAGING)
	else
		// Target is broke - not worth it
		ship.ship_notify("Scan complete. Target has insufficient funds ([target_wealth] credits). Disengaging.", "SCANNER", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg')
		target.ship_notify("Hostile scan complete. They found nothing of value and are disengaging.", "BROKEY ALERT", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg')
		controller.clear_target()

	return AI_BEHAVIOR_DELAY

/// Starts looping scan sound on the target ship
/datum/ai_behavior/npc_ship/scan_wealth/proc/start_scan_sound(obj/structure/overmap/ship/target)
	if(!target?.shuttle?.shuttle_areas)
		return
	var/sound/scan_sound = sound('voidcrew/sound/econ_scan.ogg', repeat = TRUE, channel = CHANNEL_ECON_SCAN)
	for(var/area/shuttle_area as anything in target.shuttle.shuttle_areas)
		for(var/mob/M in shuttle_area)
			if(M.client)
				SEND_SOUND(M, scan_sound)

/// Stops the looping scan sound on the target ship
/datum/ai_behavior/npc_ship/scan_wealth/proc/stop_scan_sound(obj/structure/overmap/ship/target)
	if(!target?.shuttle?.shuttle_areas)
		return
	var/sound/stop_sound = sound(null, channel = CHANNEL_ECON_SCAN)
	for(var/area/shuttle_area as anything in target.shuttle.shuttle_areas)
		for(var/mob/M in shuttle_area)
			if(M.client)
				SEND_SOUND(M, stop_sound)

// ========== HAILING ==========

/**
 * Hailing behavior - pirate is demanding tribute, waiting for player response.
 * During this phase:
 * - Pirate follows target but doesn't attack
 * - Player can answer via holopad → NEGOTIATING
 * - Player can escape (moving is OK during hailing)
 * - Player locks weapons → immediate COMBAT
 * - Player fires on pirate → immediate COMBAT
 * - 20 seconds pass without answer → COMBAT
 */
/datum/ai_behavior/npc_ship/hailing
	action_cooldown = 1 SECONDS

/datum/ai_behavior/npc_ship/hailing/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/pirate/ship = get_ship(controller)
	var/obj/structure/overmap/ship/target = controller.get_target()

	if(!ship || !target || QDELETED(target))
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check if we've been attacked (player aggression)
	// This is handled by signal, but double-check here
	if(controller.blackboard[BB_NPC_TARGET_LOCKED])
		// We somehow got a lock during hailing - shouldn't happen, but handle it
		escalate_to_combat(controller, ship, target, "aggression")
		return AI_BEHAVIOR_DELAY

	// Send initial hail announcement (only once)
	if(!controller.blackboard[BB_NPC_HAILING_ANNOUNCED])
		controller.set_blackboard_key(BB_NPC_HAILING_ANNOUNCED, TRUE)
		controller.set_blackboard_key(BB_NPC_HAILING_START, world.time)

		// Announce to pirate ship
		ship.ship_notify("Hailing [target.name]. Awaiting response.", "COMMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg')

		// Announce to player ship - this is the key notification!
		target.ship_notify("INCOMING HAIL from [ship.name]! Report to comms array to respond. 20 seconds before they open fire!", "PRIORITY", SHIP_NOTIFY_DANGER, 'voidcrew/sound/warn3.ogg')

		// Make the ship comms holopad ring
		start_target_holopad_ringing(target)

	// Check timeout
	var/hail_start = controller.blackboard[BB_NPC_HAILING_START]
	if(!hail_start)
		controller.set_blackboard_key(BB_NPC_HAILING_START, world.time)
		return AI_BEHAVIOR_DELAY

	var/elapsed = world.time - hail_start

	// Send reminder at halfway point
	if(elapsed >= (NPC_HAILING_GRACE_PERIOD / 2) && elapsed < (NPC_HAILING_GRACE_PERIOD / 2) + 2 SECONDS)
		// Only send once (check if we're in the 2-second window after halfway)
		if(!controller.blackboard["hailing_reminder_sent"])
			controller.set_blackboard_key("hailing_reminder_sent", TRUE)
			target.ship_notify("[ship.name] is losing patience! 10 seconds until they open fire!", "URGENT", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn4.ogg')

	// Check if grace period expired
	if(elapsed >= NPC_HAILING_GRACE_PERIOD)
		escalate_to_combat(controller, ship, target, "ignored")
		return AI_BEHAVIOR_DELAY

	return AI_BEHAVIOR_DELAY

/**
 * Escalate from HAILING to COMBAT - player ignored or aggressed.
 */
/datum/ai_behavior/npc_ship/hailing/proc/escalate_to_combat(datum/ai_controller/npc_ship/controller, obj/structure/overmap/ship/npc/ship, obj/structure/overmap/ship/target, reason)
	// Clear hailing state
	controller.clear_blackboard_key(BB_NPC_HAILING_START)
	controller.clear_blackboard_key(BB_NPC_HAILING_ANNOUNCED)
	controller.clear_blackboard_key("hailing_reminder_sent")

	// Stop the holopad ringing
	stop_target_holopad_ringing(target)

	// Announce escalation
	if(reason == "ignored")
		ship.ship_notify("No response from target. Engaging.", "COMMS", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg')
		target.ship_notify("[ship.name] has received no response and is engaging!", "COMBAT", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert3.ogg')
	else if(reason == "aggression")
		ship.ship_notify("Hostile action detected! Engaging!", "COMBAT", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg')
		target.ship_notify("[ship.name] is retaliating to hostile action!", "COMBAT", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert3.ogg')
	else if(reason == "negotiation_failed")
		ship.ship_notify("Negotiations failed. Engaging target.", "COMMS", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg')
		target.ship_notify("Negotiations with [ship.name] have failed! Brace for combat!", "COMBAT", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert3.ogg')

	// Transition to ENGAGING (will acquire lock then fight)
	controller.set_combat_state(NPC_COMBAT_ENGAGING)

/**
 * Find and start ringing the ship comms holopad on the target ship.
 */
/datum/ai_behavior/npc_ship/hailing/proc/start_target_holopad_ringing(obj/structure/overmap/ship/target)
	var/obj/machinery/holopad/ship_comms/holopad = find_ship_comms_holopad(target)
	holopad?.start_ringing()

/**
 * Find and stop ringing the ship comms holopad on the target ship.
 */
/datum/ai_behavior/npc_ship/hailing/proc/stop_target_holopad_ringing(obj/structure/overmap/ship/target)
	var/obj/machinery/holopad/ship_comms/holopad = find_ship_comms_holopad(target)
	holopad?.stop_ringing()

/**
 * Find the ship comms holopad on a ship.
 */
/datum/ai_behavior/npc_ship/hailing/proc/find_ship_comms_holopad(obj/structure/overmap/ship/target)
	if(!target?.shuttle?.shuttle_areas)
		return null

	for(var/area/shuttle_area as anything in target.shuttle.shuttle_areas)
		var/obj/machinery/holopad/ship_comms/found = locate() in shuttle_area
		if(found)
			return found

	return null

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

	// Check if target escaped to green space - abort lock
	var/turf/target_loc = get_turf(target)
	var/datum/overmap_zone/target_zone = SSovermap_zones.get_zone(target_loc)
	var/target_can_be_attacked = target_zone ? (target_zone.weapons_allowed() || target_zone.interdiction_allowed()) : TRUE
	if(!target_can_be_attacked)
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check if already locked
	if(controller.blackboard[BB_NPC_TARGET_LOCKED])
		return AI_BEHAVIOR_DELAY

	// Check if we've started the lock
	var/lock_start = controller.blackboard[BB_NPC_LOCK_START_TIME]
	if(!lock_start)
		// Start the lock - alert the target ship (like combat console does)
		target.ship_notify("Hostile ship acquiring weapons lock!", "WARNING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/alert2.ogg')
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
		target.ship_notify("Hostile weapons lock completed!", "THREAT", SHIP_NOTIFY_DANGER)

	return AI_BEHAVIOR_DELAY

// ========== FIRE WEAPONS ==========

/**
 * Handles weapon firing logic.
 * - If target has shields: use lasers (effective vs shields)
 * - If target shields are down: use missiles (effective vs hull)
 */
/datum/ai_behavior/npc_ship/fire_weapons
	action_cooldown = 2 SECONDS  // Increased from 1s for balance

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
		// Fall back to missiles if we have no working lasers
		if(!try_fire_lasers(ship, combat, target))
			try_fire_missiles(ship, combat, target, skip_laser_fallback = TRUE)
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
		// 20% chance to fire all, 80% chance to fire single (reduced for balance)
		fire_all = prob(20)

	// Fire! (uses per-ship laser cooldown)
	if(combat.fire_lasers(target, fire_all))
		COOLDOWN_START(ship, laser_cooldown, ship.laser_cooldown_time)
		return TRUE

	return FALSE

/**
 * Attempts to fire missiles at the target.
 */
/datum/ai_behavior/npc_ship/fire_weapons/proc/try_fire_missiles(obj/structure/overmap/ship/npc/ship, datum/npc_combat_interface/combat, obj/structure/overmap/ship/target, skip_laser_fallback = FALSE)
	// Check cooldown
	if(!COOLDOWN_FINISHED(ship, missile_cooldown))
		// Fallback to lasers if available
		if(!skip_laser_fallback)
			try_fire_lasers(ship, combat, target)
		return FALSE

	var/launcher_count = combat.get_working_launcher_count()
	if(launcher_count < 1)
		// No launchers, try lasers instead
		if(!skip_laser_fallback)
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
	action_cooldown = 3 SECONDS  // Increased from 2s for balance

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
		// Clear commitment since interdiction is complete
		controller.clear_blackboard_key(BB_NPC_INTERDICTOR_START_TIME)
		return AI_BEHAVIOR_DELAY

	// Try to interdict! (aggressively - don't wait for target to start moving)
	if(combat.start_interdiction(target))
		// Record commitment start time - other actions delayed while committed
		controller.set_blackboard_key(BB_NPC_INTERDICTOR_START_TIME, world.time)

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

	// Check if target cloaked - lose tracking
	if(target.invisibility > INVISIBILITY_NONE)
		SEND_SIGNAL(target, COMSIG_SHIP_TARGETING_STOPPED, ship)
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check if line of sight is blocked (e.g., by a nebula) - lose tracking
	if(!ship.has_los_to(target))
		SEND_SIGNAL(target, COMSIG_SHIP_TARGETING_STOPPED, ship)
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check if target has crashed (no longer flying) - don't attack crashed ships
	if(target.state != OVERMAP_SHIP_FLYING)
		SEND_SIGNAL(target, COMSIG_SHIP_TARGETING_STOPPED, ship)
		controller.clear_target()
		return AI_BEHAVIOR_DELAY

	// Check if target escaped to a protected zone (where combat isn't allowed)
	var/turf/target_turf = get_turf(target)
	if(target_turf)
		var/datum/overmap_zone/target_zone = SSovermap_zones.get_zone(target_turf)
		var/target_can_be_attacked = target_zone ? (target_zone.weapons_allowed() || target_zone.interdiction_allowed()) : TRUE
		if(!target_can_be_attacked)
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

// ========== RETREAT ESCAPE ==========

/**
 * Escape behavior for retreating ships.
 * If interdicted: tries to shield burst to break free.
 * If not interdicted (or just broke free): tries to cloak.
 */
/datum/ai_behavior/npc_ship/retreat_escape
	action_cooldown = 1 SECONDS

/datum/ai_behavior/npc_ship/retreat_escape/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/datum/npc_combat_interface/combat = get_combat_interface(controller)

	if(!ship || !combat)
		return AI_BEHAVIOR_DELAY

	// If interdicted, try to break free with shield burst
	if(ship.is_interdicted)
		if(ship.can_burst_shields())
			ship.burst_shields_break_interdiction()
			// After bursting, immediately try to cloak
			if(combat.has_working_cloak())
				combat.activate_cloak()
		return AI_BEHAVIOR_DELAY

	// Not interdicted - try to cloak if we haven't already
	if(ship.invisibility <= INVISIBILITY_NONE && combat.has_working_cloak())
		combat.activate_cloak()

	// Check if we've escaped far enough from the last target to return to patrol
	var/datum/weakref/last_target_ref = controller.blackboard[BB_NPC_LAST_TARGET]
	var/obj/structure/overmap/ship/last_target = last_target_ref?.resolve()

	if(last_target && !QDELETED(last_target))
		var/turf/our_loc = get_turf(ship)
		var/turf/target_loc = get_turf(last_target)
		if(our_loc && target_loc)
			var/distance = get_dist(our_loc, target_loc)
			// If we're far enough away (15+ tiles), return to patrol
			if(distance >= 15)
				return_to_patrol(controller)
	else
		// No last target to escape from - just return to patrol
		return_to_patrol(controller)

	return AI_BEHAVIOR_DELAY

/// Helper proc to transition retreating ship back to patrol
/datum/ai_behavior/npc_ship/retreat_escape/proc/return_to_patrol(datum/ai_controller/npc_ship/controller)
	// Clear retreat state
	controller.blackboard[BB_NPC_RETREAT_REASON] = null
	controller.blackboard[BB_NPC_LAST_TARGET] = null
	// Return to idle/patrol
	controller.clear_target()
	controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_PATROL)

// ========== ACTIVATE SIPHON ==========

/**
 * Activates the ship's data siphon when weapons lock is achieved.
 * Pirates use this to steal credits from locked targets.
 */
/datum/ai_behavior/npc_ship/activate_siphon
	action_cooldown = 3 SECONDS  // Increased from 2s for balance

/datum/ai_behavior/npc_ship/activate_siphon/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/obj/structure/overmap/ship/target = controller.get_target()

	if(!ship || !target || QDELETED(target))
		return AI_BEHAVIOR_DELAY

	// Only siphon if we have lock
	if(!controller.blackboard[BB_NPC_TARGET_LOCKED])
		return AI_BEHAVIOR_DELAY

	// Find our data siphon and activate it
	var/obj/machinery/shuttle_scrambler/ship_siphon/siphon
	for(var/area/shuttle_area as anything in ship.shuttle?.shuttle_areas)
		siphon = locate(/obj/machinery/shuttle_scrambler/ship_siphon) in shuttle_area
		if(siphon)
			break

	if(siphon && !siphon.active && !siphon.warming_up)
		// Copy the ship's siphon goal percentage to the siphon
		siphon.siphon_goal_percent = ship.siphon_goal_percent
		if(siphon.activate_siphon(target))
			// Record commitment start time - other actions delayed while committed
			controller.set_blackboard_key(BB_NPC_SIPHON_START_TIME, world.time)

	return AI_BEHAVIOR_DELAY

// ========== CHECK WEAPONS ==========

/**
 * Checks if the ship still has functional weapons.
 * If all weapons are destroyed, transitions to RETREATING state.
 */
/datum/ai_behavior/npc_ship/check_weapons
	action_cooldown = 2 SECONDS

/datum/ai_behavior/npc_ship/check_weapons/perform(seconds_per_tick, datum/ai_controller/npc_ship/controller)
	. = ..()

	var/obj/structure/overmap/ship/npc/ship = get_ship(controller)
	var/datum/npc_combat_interface/combat = get_combat_interface(controller)

	if(!ship || !combat)
		return AI_BEHAVIOR_DELAY

	// If we have no weapons and ship type retreats without weapons, enter retreat mode
	if(!combat.has_any_weapons() && ship.retreat_without_weapons)
		controller.set_combat_state(NPC_COMBAT_RETREATING)
		controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, NPC_MOVEMENT_RETREAT)
		ship.ship_notify("All weapons systems offline! Initiating emergency retreat!", "CRITICAL", SHIP_NOTIFY_DANGER, 'voidcrew/sound/warn3.ogg')

	return AI_BEHAVIOR_DELAY
