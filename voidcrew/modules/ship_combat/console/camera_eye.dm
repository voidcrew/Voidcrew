// ========== CAMERA EYE ==========

/mob/eye/camera/remote/ship_combat
	name = "tactical targeting system"
	visible_to_user = TRUE
	use_visibility = FALSE // Don't check camera network - we view ships directly
	sight = SEE_TURFS | SEE_OBJS // See turfs and objects, not mobs
	/// Reference to our console
	var/obj/machinery/computer/camera_advanced/ship_combat/console
	/// The target (ship or raidable outpost) we're allowed to view
	var/obj/structure/overmap/target_ship
	/// Static images applied to interior turfs (non-edge turfs)
	var/list/image/interior_static_images

/mob/eye/camera/remote/ship_combat/Initialize(mapload, obj/machinery/computer/camera_advanced/ship_combat/origin)
	. = ..()
	console = origin

/// Override Destroy to handle non-living mobs (admin ghosts)
/mob/eye/camera/remote/ship_combat/Destroy()
	var/mob/user = user_ref?.resolve()
	if(console && user)
		console.remove_eye_control(user)
	assign_user(null)
	clear_interior_static()
	if(target_ship)
		UnregisterSignal(target_ship, COMSIG_SHIP_HULL_HIT)
	console = null
	target_ship = null
	return ..()

/// Generates static overlay images for all interior turfs (turfs not adjacent to space)
/// Only the target's exterior outline (turfs touching space) will be visible
/mob/eye/camera/remote/ship_combat/proc/generate_interior_static()
	clear_interior_static()
	var/list/turf/camera_turfs = target_ship?.get_combat_camera_turfs()
	if(!length(camera_turfs))
		return

	interior_static_images = list()

	// Get the z-level for plane offset calculation
	var/turf/first_turf = camera_turfs[1]
	var/z_level = first_turf.z
	if(!z_level)
		return

	// Create the base static image to clone from
	var/image/base_static = new('icons/effects/cameravis.dmi')
	SET_PLANE_W_SCALAR(base_static, CAMERA_STATIC_PLANE, GET_Z_PLANE_OFFSET(z_level))
	base_static.appearance_flags = RESET_TRANSFORM | RESET_ALPHA | RESET_COLOR | KEEP_APART
	base_static.override = TRUE

	// Iterate through all turfs in the target
	for(var/turf/target_turf as anything in camera_turfs)
		CHECK_TICK
		// Check if this turf is on the exterior (adjacent to space)
		if(is_exterior_turf(target_turf))
			continue // Skip exterior turfs - they should be visible

		// This is an interior turf - add static
		var/image/static_image = new /image(base_static)
		static_image.loc = target_turf
		interior_static_images += static_image

/// Checks if a turf is visible (within COMBAT_CAMERA_VISIBILITY_RANGE tiles of space)
/// When range is 0, only turfs directly adjacent to space are visible
/// When range is 1+, turfs within that many tiles of space are also visible
/mob/eye/camera/remote/ship_combat/proc/is_exterior_turf(turf/T)
	return is_near_space(T, COMBAT_CAMERA_VISIBILITY_RANGE)

/// Checks if a turf is within 'range' tiles of any space turf
/mob/eye/camera/remote/ship_combat/proc/is_near_space(turf/T, range = 0)
	// Check all turfs within range for space
	for(var/turf/check_turf in RANGE_TURFS(range, T))
		if(isspaceturf(check_turf))
			return TRUE
	return FALSE

/// Clears all interior static images
/mob/eye/camera/remote/ship_combat/proc/clear_interior_static()
	var/client/client = GetViewerClient()
	if(client && interior_static_images)
		client.images -= interior_static_images
	interior_static_images = null

/// Applies the interior static images to the current viewer
/mob/eye/camera/remote/ship_combat/proc/apply_interior_static()
	var/client/client = GetViewerClient()
	if(client && interior_static_images)
		client.images += interior_static_images

/// Refreshes static overlay - called when hull damage reveals new areas
/mob/eye/camera/remote/ship_combat/proc/refresh_interior_static()
	var/client/client = GetViewerClient()
	if(!client)
		return
	// Remove old static, regenerate, and reapply
	if(interior_static_images)
		client.images -= interior_static_images
	generate_interior_static()
	if(interior_static_images)
		client.images += interior_static_images

/// Signal handler for when the target ship's hull is hit
/mob/eye/camera/remote/ship_combat/proc/on_target_hull_hit(datum/source, turf/impact_loc)
	SIGNAL_HANDLER
	// Refresh static after a short delay to allow turf destruction to complete
	addtimer(CALLBACK(src, PROC_REF(refresh_interior_static)), 0.5 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE)

/// Override to allow assigning non-living mobs (admin ghosts)
/mob/eye/camera/remote/ship_combat/assign_user(mob/new_user)
	var/mob/old_user = user_ref?.resolve()
	SEND_SIGNAL(src, COMSIG_REMOTE_CAMERA_ASSIGN_USER, new_user, old_user)
	if(old_user)
		// Reset perspective BEFORE clearing remote_control
		// This prevents TGUI from closing when it checks ui_state
		old_user.reset_perspective(null)
		old_user.remote_control = null
		name = initial(src.name)

		var/client/old_user_client = GetViewerClient()
		if(user_image && old_user_client)
			old_user_client.images -= user_image
		clear_camera_chunks()

	user_ref = WEAKREF(new_user)

	if(new_user)
		new_user.remote_control = src
		new_user.reset_perspective(src)
		name = "Camera Eye ([new_user.name])"

		var/client/new_user_client = GetViewerClient()
		if(user_image && new_user_client)
			new_user_client.images += user_image
		if(use_visibility)
			update_visibility()

/// Override to show turfs and objects but not mobs
/mob/eye/camera/remote/ship_combat/update_remote_sight(mob/user)
	user.set_sight(SEE_TURFS | SEE_OBJS | BLIND)
	return TRUE

/mob/eye/camera/remote/ship_combat/setLoc(turf/destination, force_update = FALSE)
	if(!destination)
		return ..()

	// If no target set yet, allow any movement (for initial placement)
	if(!target_ship)
		return ..()

	// Only allow movement within the target's viewable footprint
	if(target_ship.combat_camera_can_view(destination))
		return ..()

	// Block movement outside the target
	return FALSE

/mob/eye/camera/remote/ship_combat/can_z_move(direction, turf/start, turf/destination, z_move_flags = NONE, mob/living/rider)
	return FALSE // No z-movement for ship targeting
