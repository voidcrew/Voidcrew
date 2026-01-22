// ========== TARGET SELECTION & ZONE CHECKS ==========

/// Called when our ship's zone changes (due to zone rotation) - check if we need to break locks
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_our_ship_zone_changed(datum/source, old_zone_type, new_zone_type)
	SIGNAL_HANDLER
	// Check if we're in attack mode or targeting - need to verify target is still in same zone
	if(attack_mode || is_targeting)
		INVOKE_ASYNC(src, PROC_REF(check_zone_after_rotation))

/// Called when our target ship's zone changes (due to zone rotation)
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_target_ship_zone_changed(datum/source, old_zone_type, new_zone_type)
	SIGNAL_HANDLER
	if(attack_mode || is_targeting)
		INVOKE_ASYNC(src, PROC_REF(check_zone_after_rotation))

/// Checks if ships are still in the same zone after a zone rotation
/obj/machinery/computer/camera_advanced/ship_combat/proc/check_zone_after_rotation()
	if(!current_ship)
		return

	// Get our current zone
	var/turf/our_turf = get_turf(current_ship)
	var/datum/overmap_zone/our_zone = SSovermap_zones?.get_zone(our_turf)
	if(!our_zone)
		return

	// Check targeting in progress - break if either ship now in Neutral zone
	if(is_targeting && targeting_ship)
		var/turf/target_turf = get_turf(targeting_ship)
		var/datum/overmap_zone/target_zone = SSovermap_zones?.get_zone(target_turf)
		if(our_zone?.zone_type == ZONE_GREEN)
			cancel_targeting()
			if(current_user)
				to_chat(current_user, span_warning("Target lock lost - zone shift placed you in [our_zone.name]!"))
			current_ship.ship_notify("Target lock failed - entered safe zone.", "TARGETING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
			return
		if(target_zone?.zone_type == ZONE_GREEN)
			var/target_name = targeting_ship.display_name
			cancel_targeting()
			if(current_user)
				to_chat(current_user, span_warning("Target lock lost - zone shift placed [target_name] in [target_zone.name]!"))
			current_ship.ship_notify("Target lock failed - target entered safe zone.", "TARGETING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
			return

	// Check active attack mode or existing target lock - break if either ship now in Neutral zone
	if(target_ship)
		var/turf/target_turf = get_turf(target_ship)
		var/datum/overmap_zone/target_zone = SSovermap_zones?.get_zone(target_turf)
		if(our_zone?.zone_type == ZONE_GREEN)
			if(current_user)
				to_chat(current_user, span_warning("Target lock lost - zone shift placed you in [our_zone.name]!"))
			if(attack_mode)
				exit_attack_mode(current_user)
			clear_target()
			current_ship.ship_notify("Weapons lock lost - entered safe zone.", "TARGETING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
			return
		if(target_zone?.zone_type == ZONE_GREEN)
			var/target_name = target_ship.display_name
			if(current_user)
				to_chat(current_user, span_warning("Target lock lost - zone shift placed [target_name] in [target_zone.name]!"))
			if(attack_mode)
				exit_attack_mode(current_user)
			clear_target()
			current_ship.ship_notify("Weapons lock lost - target entered safe zone.", "TARGETING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

/// Starts the targeting process for a new ship (takes time and warns the target)
/obj/machinery/computer/camera_advanced/ship_combat/proc/start_targeting(obj/structure/overmap/ship/new_target, mob/user)
	if(new_target == current_ship)
		if(user)
			to_chat(user, span_warning("Cannot target your own ship!"))
		return FALSE

	// Can't acquire locks while docked
	if(current_ship?.docked)
		if(user)
			to_chat(user, span_warning("Cannot acquire target lock while docked!"))
		return FALSE

	// Can't acquire locks while hidden in nebula (combat systems offline)
	if(current_ship?.hidden_in_nebula)
		if(user)
			to_chat(user, span_warning("Cannot acquire target lock - combat systems offline while in nebula concealment!"))
		return FALSE

	// Can't target if either ship is in Neutral zone (safe space)
	if(SSovermap_zones?.initialized && current_ship)
		var/datum/overmap_zone/our_zone = SSovermap_zones.get_zone(get_turf(current_ship))
		var/datum/overmap_zone/target_zone = SSovermap_zones.get_zone(get_turf(new_target))
		if(our_zone?.zone_type == ZONE_GREEN)
			if(user)
				to_chat(user, span_warning("Cannot acquire target lock in [our_zone.name]!"))
			return FALSE
		if(target_zone?.zone_type == ZONE_GREEN)
			if(user)
				to_chat(user, span_warning("Cannot target ships in [target_zone.name]!"))
			return FALSE

	// Can't target if line of sight is blocked (e.g., by a nebula)
	if(current_ship && !current_ship.has_los_to(new_target))
		if(user)
			to_chat(user, span_warning("Cannot acquire target lock - line of sight blocked!"))
		return FALSE

	// Cancel any existing targeting
	cancel_targeting()

	// If we already have this ship locked, no need to re-target
	if(target_ship == new_target)
		if(user)
			to_chat(user, span_notice("Already have target lock on [new_target.display_name]."))
		return FALSE

	// Start the targeting process
	targeting_ship = new_target
	is_targeting = TRUE
	targeting_start_time = world.time

	// Play targeting lock sound
	playsound(src, 'voidcrew/sound/machines/interdictor/startup2.ogg', 30, FALSE)
	playsound(src, 'voidcrew/sound/machines/interdictor/terminal.ogg', 30, FALSE)

	// Register for target deletion, movement, and zone changes during targeting
	RegisterSignal(targeting_ship, COMSIG_QDELETING, PROC_REF(on_targeting_ship_deleted))
	RegisterSignal(targeting_ship, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(on_targeting_ship_moved))
	RegisterSignal(targeting_ship, COMSIG_SHIP_ZONE_CHANGED, PROC_REF(on_target_ship_zone_changed))
	if(current_ship)
		RegisterSignal(current_ship, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(on_our_ship_moved_targeting))

	// Warn the target ship
	SEND_SIGNAL(targeting_ship, COMSIG_SHIP_BEING_TARGETED, current_ship)
	targeting_ship.ship_notify("Hostile ship acquiring weapons lock!", "WARNING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/combatalarm.ogg', 25)

	// Notify our crew
	if(user)
		to_chat(user, span_notice("Acquiring target lock on [targeting_ship.display_name]... ([COMBAT_TARGETING_TIME / 10] seconds)"))

	// Start the targeting timer
	targeting_timer_id = addtimer(CALLBACK(src, PROC_REF(complete_targeting), user), COMBAT_TARGETING_TIME, TIMER_STOPPABLE)

	return TRUE

/// Called when targeting timer completes - finalizes the target lock
/obj/machinery/computer/camera_advanced/ship_combat/proc/complete_targeting(mob/user)
	if(!is_targeting || !targeting_ship)
		return FALSE

	var/obj/structure/overmap/ship/locked_target = targeting_ship

	// Clean up targeting state
	UnregisterSignal(targeting_ship, list(COMSIG_QDELETING, COMSIG_VOIDCREW_SHIP_MOVED, COMSIG_SHIP_ZONE_CHANGED))
	if(current_ship)
		UnregisterSignal(current_ship, COMSIG_VOIDCREW_SHIP_MOVED)
	is_targeting = FALSE
	targeting_ship = null
	targeting_timer_id = null
	targeting_start_time = null

	// Clear any previous target
	clear_target()

	// Set the new target
	target_ship = locked_target
	RegisterSignal(target_ship, COMSIG_QDELETING, PROC_REF(on_target_deleted))
	RegisterSignal(target_ship, COMSIG_SHIP_ZONE_CHANGED, PROC_REF(on_target_ship_zone_changed))
	RegisterSignal(target_ship, COMSIG_SHIP_GOING_DARK, PROC_REF(on_target_going_dark))

	// Set the eye's allowed ship if it exists
	var/mob/eye/camera/remote/ship_combat/combat_eye = eyeobj
	if(combat_eye)
		combat_eye.target_ship = target_ship

	// Notify the target ship that lock is complete (this breaks their cloak)
	SEND_SIGNAL(target_ship, COMSIG_SHIP_TARGETING_STOPPED, current_ship)
	SEND_SIGNAL(target_ship, COMSIG_SHIP_WEAPONS_LOCKED, current_ship)

	// Notify our crew
	if(user)
		to_chat(user, span_danger("Target lock acquired on [target_ship.display_name]!"))
	current_ship?.ship_notify("Target lock acquired: [target_ship.display_name]", "TARGETING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	return TRUE\

/// Cancels an in-progress targeting attempt
/obj/machinery/computer/camera_advanced/ship_combat/proc/cancel_targeting()
	if(!is_targeting)
		return

	// Stop the timer
	if(targeting_timer_id)
		deltimer(targeting_timer_id)
		targeting_timer_id = null

	// Unregister movement signal from our ship
	if(current_ship)
		UnregisterSignal(current_ship, COMSIG_VOIDCREW_SHIP_MOVED)

	// Notify the target they're no longer being targeted
	if(targeting_ship)
		SEND_SIGNAL(targeting_ship, COMSIG_SHIP_TARGETING_STOPPED, current_ship)
		targeting_ship.ship_notify("Hostile targeting signal lost.", "THREAT", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		UnregisterSignal(targeting_ship, list(COMSIG_QDELETING, COMSIG_VOIDCREW_SHIP_MOVED, COMSIG_SHIP_ZONE_CHANGED))

	is_targeting = FALSE
	targeting_ship = null
	targeting_start_time = null

/// Called when the target ship moves during targeting - check range
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_targeting_ship_moved(datum/source)
	SIGNAL_HANDLER
	check_targeting_range()

/// Called when our ship moves during targeting - check range
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_our_ship_moved_targeting(datum/source)
	SIGNAL_HANDLER
	check_targeting_range()

/// Checks if targeting should be cancelled due to range or zone
/obj/machinery/computer/camera_advanced/ship_combat/proc/check_targeting_range()
	if(!is_targeting || !targeting_ship || !current_ship)
		return

	var/turf/our_turf = get_turf(current_ship)
	var/turf/target_turf = get_turf(targeting_ship)
	if(!our_turf || !target_turf)
		return

	// Check if either ship entered Neutral zone (safe space)
	if(SSovermap_zones?.initialized)
		var/datum/overmap_zone/our_zone = SSovermap_zones.get_zone(our_turf)
		var/datum/overmap_zone/target_zone = SSovermap_zones.get_zone(target_turf)
		if(our_zone?.zone_type == ZONE_GREEN)
			cancel_targeting()
			if(current_user)
				to_chat(current_user, span_warning("Target lock lost - entered [our_zone.name]!"))
			current_ship?.ship_notify("Target lock failed - entered safe zone.", "TARGETING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
			return
		if(target_zone?.zone_type == ZONE_GREEN)
			var/target_name = targeting_ship.display_name
			cancel_targeting()
			if(current_user)
				to_chat(current_user, span_warning("Target lock lost - [target_name] entered [target_zone.name]!"))
			current_ship?.ship_notify("Target lock failed - target entered safe zone.", "TARGETING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
			return

	// Check if line of sight is blocked (e.g., by a nebula)
	if(!current_ship.has_los_to(targeting_ship))
		var/target_name = targeting_ship.display_name
		cancel_targeting()
		if(current_user)
			to_chat(current_user, span_warning("Target lock lost - [target_name] obscured by interference!"))
		current_ship?.ship_notify("Target lock failed - line of sight blocked.", "TARGETING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return

	var/distance = get_dist(our_turf, target_turf)
	if(distance > COMBAT_TARGETING_RANGE)
		var/target_name = targeting_ship.display_name
		cancel_targeting()
		if(current_user)
			to_chat(current_user, span_warning("Target lock lost - [target_name] moved out of sensor range!"))
		current_ship?.ship_notify("Target lock failed - target escaped sensor range.", "TARGETING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

/// Called when the target ship moves during attack mode - check range
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_target_ship_moved_attack(datum/source)
	SIGNAL_HANDLER
	check_attack_range()

/// Called when our ship moves during attack mode - check range
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_our_ship_moved_attack(datum/source)
	SIGNAL_HANDLER
	check_attack_range()

/// Checks if attack mode should end due to ships moving out of range or zone
/obj/machinery/computer/camera_advanced/ship_combat/proc/check_attack_range()
	if(!attack_mode || !target_ship || !current_ship)
		return

	var/turf/our_turf = get_turf(current_ship)
	var/turf/target_turf = get_turf(target_ship)
	if(!our_turf || !target_turf)
		return

	// Check if either ship entered Neutral zone (safe space)
	if(SSovermap_zones?.initialized)
		var/datum/overmap_zone/our_zone = SSovermap_zones.get_zone(our_turf)
		var/datum/overmap_zone/target_zone = SSovermap_zones.get_zone(target_turf)
		if(our_zone?.zone_type == ZONE_GREEN)
			if(current_user)
				to_chat(current_user, span_warning("Weapons lock lost - entered [our_zone.name]!"))
				INVOKE_ASYNC(src, PROC_REF(exit_attack_mode), current_user)
			current_ship?.ship_notify("Weapons lock lost - entered safe zone.", "TARGETING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
			return
		if(target_zone?.zone_type == ZONE_GREEN)
			var/target_name = target_ship.display_name
			if(current_user)
				to_chat(current_user, span_warning("Weapons lock lost - [target_name] entered [target_zone.name]!"))
				INVOKE_ASYNC(src, PROC_REF(exit_attack_mode), current_user)
			current_ship?.ship_notify("Weapons lock lost - target entered safe zone.", "TARGETING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
			return

	var/distance = get_dist(our_turf, target_turf)
	if(distance > COMBAT_MISSILE_LOCK_RANGE)
		var/target_name = target_ship.display_name
		if(current_user)
			to_chat(current_user, span_warning("Target lock lost - [target_name] moved out of weapons range!"))
			INVOKE_ASYNC(src, PROC_REF(exit_attack_mode), current_user)
		current_ship?.ship_notify("Weapons lock lost - target escaped range.", "TARGETING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

/// Called when the ship we're targeting is deleted mid-lock
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_targeting_ship_deleted(datum/source)
	SIGNAL_HANDLER
	cancel_targeting()
	if(current_user)
		to_chat(current_user, span_danger("Target lost!"))

/// Sets a new target ship (legacy - now just calls start_targeting)
/obj/machinery/computer/camera_advanced/ship_combat/proc/set_target_ship(obj/structure/overmap/ship/new_target, mob/user)
	return start_targeting(new_target, user)

/// Gets a turf at the target ship's mobile docking port
/obj/machinery/computer/camera_advanced/ship_combat/proc/get_target_ship_port_turf()
	if(!target_ship?.shuttle)
		return null
	return get_turf(target_ship.shuttle)

/// Gets any valid turf on the target ship (fallback)
/obj/machinery/computer/camera_advanced/ship_combat/proc/get_target_ship_turf()
	if(!target_ship?.shuttle?.shuttle_areas)
		return null

	for(var/area/A in target_ship.shuttle.shuttle_areas)
		for(var/turf/T in A)
			if(!isclosedturf(T))
				return T
	return null

/// Clears the current target
/obj/machinery/computer/camera_advanced/ship_combat/proc/clear_target()
	if(target_ship)
		// Notify the target they are no longer locked
		SEND_SIGNAL(target_ship, COMSIG_SHIP_WEAPONS_LOCK_LOST, current_ship)
		UnregisterSignal(target_ship, list(COMSIG_QDELETING, COMSIG_SHIP_ZONE_CHANGED, COMSIG_SHIP_GOING_DARK))
	target_ship = null

	var/mob/eye/camera/remote/ship_combat/combat_eye = eyeobj
	if(combat_eye)
		combat_eye.target_ship = null

/obj/machinery/computer/camera_advanced/ship_combat/proc/on_target_deleted(datum/source)
	SIGNAL_HANDLER
	clear_target()
	if(current_user)
		to_chat(current_user, span_danger("Target destroyed!"))

/// Called when the target ship hides in a nebula
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_target_going_dark(datum/source)
	SIGNAL_HANDLER
	var/target_name = target_ship?.display_name || "Target"
	if(attack_mode)
		INVOKE_ASYNC(src, PROC_REF(exit_attack_mode), current_user)
	clear_target()
	if(current_user)
		to_chat(current_user, span_warning("[target_name] has disappeared from sensors!"))
	current_ship?.ship_notify("Target lost - ship went dark.", "TARGETING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
