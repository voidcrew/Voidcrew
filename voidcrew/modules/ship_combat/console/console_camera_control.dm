// ========== CAMERA EYE CONTROL & ATTACK MODE ==========

/obj/machinery/computer/camera_advanced/ship_combat/CreateEye()
	eyeobj = new /mob/eye/camera/remote/ship_combat(get_turf(src), src)
	return TRUE

/obj/machinery/computer/camera_advanced/ship_combat/give_eye_control(mob/user)
	. = ..()
	// Register click handler
	RegisterSignal(user, COMSIG_MOB_CLICKON, PROC_REF(on_user_click))
	// Show reticle
	if(user.client)
		user.client.screen += reticle
	// Update reticle position
	update_reticle()
	// Show turfs and objects but hide mobs
	user.set_sight(SEE_TURFS | SEE_OBJS | BLIND)

/// Override to allow removing eye control from non-living mobs (admin ghosts)
/obj/machinery/computer/camera_advanced/ship_combat/remove_eye_control(mob/user)
	UnregisterSignal(user, COMSIG_MOB_CLICKON)
	if(user?.client)
		user.client.screen -= reticle
		user.client.view_size.unsupress()

	for(var/datum/action/actions_removed as anything in actions)
		actions_removed.Remove(user)

	// Clear static overlay and unregister hull hit signal before removing control
	var/mob/eye/camera/remote/ship_combat/combat_eye = eyeobj
	if(combat_eye)
		combat_eye.clear_interior_static()
		if(combat_eye.target_ship)
			combat_eye.UnregisterSignal(combat_eye.target_ship, COMSIG_SHIP_HULL_HIT)

	if(eyeobj)
		eyeobj.assign_user(null)
	current_user = null
	attack_mode = FALSE  // Ensure attack mode is reset when eye control is removed

	// Restore interdiction overlay if the player had one
	var/atom/movable/screen/fullscreen/interdiction/interdict_screen = user?.screens["interdiction"]
	if(interdict_screen)
		interdict_screen.start_strobe()

	playsound(src, 'sound/machines/terminal/terminal_off.ogg', 25, FALSE)

/// Enters attack mode - takes over user's view to target ship
/obj/machinery/computer/camera_advanced/ship_combat/proc/enter_attack_mode(mob/user)
	if(!target_ship)
		to_chat(user, span_warning("No target selected!"))
		return FALSE

	// Check range for missile lock
	if(current_ship)
		var/turf/our_turf = get_turf(current_ship)
		var/turf/target_turf = get_turf(target_ship)
		if(our_turf && target_turf)
			var/distance = get_dist(our_turf, target_turf)
			if(distance > COMBAT_MISSILE_LOCK_RANGE)
				to_chat(user, span_warning("Target is too far for missile lock! Move within [COMBAT_MISSILE_LOCK_RANGE] tiles."))
				return FALSE

	if(!can_use(user))
		return FALSE
	if(isnull(user.client))
		return FALSE
	if(!QDELETED(current_user))
		to_chat(user, span_warning("The targeting system is already in use!"))
		return FALSE

	// Create eye if needed
	if(!eyeobj)
		if(!CreateEye())
			to_chat(user, span_warning("Targeting system malfunction!"))
			return FALSE
		SEND_SIGNAL(src, COMSIG_ADVANCED_CAMERA_EYE_CREATED, eyeobj)

	// Set the eye's target ship
	var/mob/eye/camera/remote/ship_combat/combat_eye = eyeobj
	if(combat_eye)
		combat_eye.target_ship = target_ship
		// Generate static overlay for interior turfs - only ship outline will be visible
		combat_eye.generate_interior_static()
		// Register for hull damage to update static when breaches occur
		combat_eye.RegisterSignal(target_ship, COMSIG_SHIP_HULL_HIT, TYPE_PROC_REF(/mob/eye/camera/remote/ship_combat, on_target_hull_hit))

	// Get the mobile docking port turf for the TARGET ship
	var/turf/target_turf = get_target_ship_port_turf()
	if(!target_turf)
		// Fall back to any turf on the ship
		target_turf = get_target_ship_turf()
	if(!target_turf)
		to_chat(user, span_warning("Cannot locate target ship interior!"))
		return FALSE

	// Register for ship movement to detect when ships move out of range
	// Use COMSIG_MOVABLE_MOVED to catch both engine burns AND momentum-based movement
	// Registered only after every failure check above, so a failed activation can't
	// leave signals behind (which would runtime as duplicates on the next attempt)
	// Note: Zone change signals are already registered in complete_targeting() and attempt_ship_connection()
	RegisterSignal(target_ship, COMSIG_MOVABLE_MOVED, PROC_REF(on_target_ship_moved_attack), override = TRUE)
	if(current_ship)
		RegisterSignal(current_ship, COMSIG_MOVABLE_MOVED, PROC_REF(on_our_ship_moved_attack), override = TRUE)

	attack_mode = TRUE

	// Hide interdiction overlay while in camera view
	var/atom/movable/screen/fullscreen/interdiction/interdict_screen = user.screens["interdiction"]
	if(interdict_screen)
		animate(interdict_screen)  // Stop any running animations
		interdict_screen.alpha = 0

	// Give control and move to target
	give_eye_control(user)
	eyeobj.setLoc(target_turf, TRUE)

	// Apply static overlay to the user's client
	if(combat_eye)
		combat_eye.apply_interior_static()

	to_chat(user, span_notice("Targeting system active. Move to aim, use action buttons to fire."))
	return TRUE

/// Exits attack mode - returns user to normal view
/obj/machinery/computer/camera_advanced/ship_combat/proc/exit_attack_mode(mob/user)
	attack_mode = FALSE

	// Unregister ship movement signals (zone change signals stay registered via complete_targeting)
	if(target_ship)
		UnregisterSignal(target_ship, COMSIG_MOVABLE_MOVED)
	if(current_ship)
		UnregisterSignal(current_ship, COMSIG_MOVABLE_MOVED)

	if(current_user == user)
		remove_eye_control(user)  // This also restores interdiction overlay
		// Don't call unset_machine() - it would double-call remove_eye_control
		// and end_processing, which can cause UI issues
		end_processing()
	to_chat(user, span_notice("Exiting attack mode."))

// ========== CLICK HANDLING ==========

/obj/machinery/computer/camera_advanced/ship_combat/proc/on_user_click(mob/source, atom/target, turf/location, control, params, mouseparams)
	SIGNAL_HANDLER

	// Only handle clicks in the game window, not UI
	if(!location)
		return NONE

	// Check if this turf is on the target
	if(!target_ship || !target_ship.combat_camera_can_view(location))
		return NONE

	// Move the eye to the clicked location
	if(eyeobj)
		eyeobj.setLoc(location, TRUE)
		update_reticle()

	return NONE // Don't block the click

/obj/machinery/computer/camera_advanced/ship_combat/proc/update_reticle()
	if(!reticle || !eyeobj)
		return
	// Reticle follows the eye
	reticle.screen_loc = "CENTER"
