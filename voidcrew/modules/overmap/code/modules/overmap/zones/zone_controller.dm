/**
 * # Overmap Zones Subsystem
 *
 * Manages overmap zones, their rotation, and provides lookup functions.
 * Zones rotate in a clock-like pattern, with danger radiating from the center (sun).
 */
SUBSYSTEM_DEF(overmap_zones)
	name = "Overmap Zones"
	wait = 1 SECONDS
	init_order = INIT_ORDER_OVERMAP + 1 // Initialize after SSovermap (higher = later)
	flags = SS_BACKGROUND
	runlevels = RUNLEVEL_SETUP | RUNLEVEL_GAME
	dependencies = list(
		/datum/controller/subsystem/overmap,
	)

	/// The three zone datums (one for each type)
	var/datum/overmap_zone/zone_green
	var/datum/overmap_zone/zone_yellow
	var/datum/overmap_zone/zone_red

	/// Current rotation angle in degrees (0-360), determines zone positions
	var/rotation_angle = 0

	/// Timer ID for the next zone rotation
	var/rotation_timer_id

	/// Timer ID for warning announcements
	var/warning_timer_id

	/// Whether the zone system is active
	var/zones_active = FALSE

	/// Time of last rotation (for tracking)
	var/last_rotation_time = 0

	/// Cached center coordinates
	var/center_x = 0
	var/center_y = 0

	/// Cached max radius
	var/max_radius = 0

/datum/controller/subsystem/overmap_zones/Initialize()
	// Create the three zone datums
	zone_green = new /datum/overmap_zone(ZONE_GREEN)
	zone_yellow = new /datum/overmap_zone(ZONE_YELLOW)
	zone_red = new /datum/overmap_zone(ZONE_RED)

	// Wait for SSovermap to set up the map
	if(!SSovermap.overmap_centre)
		log_world("SSovermap_zones: ERROR - SSovermap.overmap_centre is null!")
		return SS_INIT_FAILURE

	// Cache center and radius
	center_x = SSovermap.overmap_centre.x
	center_y = SSovermap.overmap_centre.y
	max_radius = (OVERMAP_SIZE - 1) / 2

	log_world("SSovermap_zones: Initializing with center ([center_x], [center_y]), max_radius [max_radius]")

	// Randomize initial rotation
	rotation_angle = rand(0, 359)

	// Assign initial zones to all overmap turfs
	assign_zones()

	log_world("SSovermap_zones: Assigned zones - Green: [length(zone_green.turfs)], Yellow: [length(zone_yellow.turfs)], Red: [length(zone_red.turfs)]")

	// Update all turf colors (in case signals didn't fire during init)
	update_all_turf_colors()

	// Start the rotation timer
	start_rotation_timer()

	zones_active = TRUE
	last_rotation_time = world.time

	log_world("SSovermap_zones: Initialization complete!")
	return SS_INIT_SUCCESS

/datum/controller/subsystem/overmap_zones/Destroy()
	QDEL_NULL(zone_green)
	QDEL_NULL(zone_yellow)
	QDEL_NULL(zone_red)

	if(rotation_timer_id)
		deltimer(rotation_timer_id)
	if(warning_timer_id)
		deltimer(warning_timer_id)

	return ..()

/datum/controller/subsystem/overmap_zones/fire(resumed)
	// The subsystem doesn't need to fire regularly
	// Zone rotations are handled by timers
	return

/**
 * Assigns all overmap turfs to their appropriate zones based on current rotation
 */
/datum/controller/subsystem/overmap_zones/proc/assign_zones()
	var/list/turfs_to_process = get_area_turfs(/area/overmap, target_z = OVERMAP_Z_LEVEL)

	for(var/turf/open/overmap/T as anything in turfs_to_process)
		if(!istype(T))
			continue
		var/zone_type = calculate_zone_for_turf(T)
		var/datum/overmap_zone/target_zone = get_zone_datum(zone_type)
		if(target_zone)
			target_zone.add_turf(T)

/**
 * Calculates which zone type a turf should belong to based on position and rotation
 *
 * The zone system works like pie slices:
 * - 3 equal 120-degree wedges radiating from center
 * - Each wedge is a different zone type
 * - Wedges rotate together when rotation_angle changes
 * - Center near sun is always red (dangerous)
 */
/datum/controller/subsystem/overmap_zones/proc/calculate_zone_for_turf(turf/T)
	if(!T)
		return ZONE_GREEN

	// Calculate distance from center (normalized 0-1)
	var/dx = T.x - center_x
	var/dy = T.y - center_y
	var/distance = sqrt(dx * dx + dy * dy)
	var/normalized_distance = distance / max_radius

	// If very close to center (sun), always red (dangerous)
	if(normalized_distance < 0.15)
		return ZONE_RED

	// Calculate angle from center (0-360 degrees)
	// arctan returns degrees in BYOND
	var/angle = arctan(dx, dy) // Note: using (dx, dy) for proper compass orientation
	if(angle < 0)
		angle += 360

	// Apply rotation offset
	var/rotated_angle = (angle + rotation_angle) % 360

	// Determine zone based on 120-degree pie slices
	// Segment 0 (0-120°): Green
	// Segment 1 (120-240°): Yellow
	// Segment 2 (240-360°): Red
	var/segment = floor(rotated_angle / 120)

	switch(segment)
		if(0)
			return ZONE_GREEN
		if(1)
			return ZONE_YELLOW
		if(2)
			return ZONE_RED

	return ZONE_GREEN

/**
 * Returns the zone datum for a given zone type
 */
/datum/controller/subsystem/overmap_zones/proc/get_zone_datum(zone_type)
	switch(zone_type)
		if(ZONE_GREEN)
			return zone_green
		if(ZONE_YELLOW)
			return zone_yellow
		if(ZONE_RED)
			return zone_red
	return null

/**
 * Gets the zone for a specific turf (fast lookup)
 */
/datum/controller/subsystem/overmap_zones/proc/get_zone(turf/T)
	if(!istype(T, /turf/open/overmap))
		return null
	var/turf/open/overmap/OT = T
	return OT.current_zone

/**
 * Gets the zone type for a specific turf
 */
/datum/controller/subsystem/overmap_zones/proc/get_zone_type(turf/T)
	var/datum/overmap_zone/zone = get_zone(T)
	if(zone)
		return zone.zone_type
	return null

/**
 * Gets the zone for an atom (looks up turf)
 */
/datum/controller/subsystem/overmap_zones/proc/get_zone_for_atom(atom/A)
	return get_zone(get_turf(A))

/**
 * Checks if weapons are allowed at a location
 * For atoms inside ships, checks the ship's overmap position
 */
/datum/controller/subsystem/overmap_zones/proc/weapons_allowed_at(atom/A)
	// First try to find the ship this atom belongs to
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(A)
	if(ship)
		// Check the ship's position on the overmap
		var/datum/overmap_zone/zone = get_zone(get_turf(ship))
		if(!zone)
			return TRUE // Default to allowed if no zone
		return zone.weapons_allowed()

	// Fallback: check the atom's direct location (for things on the overmap itself)
	var/datum/overmap_zone/zone = get_zone_for_atom(A)
	if(!zone)
		return TRUE // Default to allowed if no zone
	return zone.weapons_allowed()

/**
 * Checks if interdiction is allowed at a location
 * For atoms inside ships, checks the ship's overmap position
 */
/datum/controller/subsystem/overmap_zones/proc/interdiction_allowed_at(atom/A)
	// First try to find the ship this atom belongs to
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(A)
	if(ship)
		// Check the ship's position on the overmap
		var/datum/overmap_zone/zone = get_zone(get_turf(ship))
		if(!zone)
			return TRUE // Default to allowed if no zone
		return zone.interdiction_allowed()

	// Fallback: check the atom's direct location (for things on the overmap itself)
	var/datum/overmap_zone/zone = get_zone_for_atom(A)
	if(!zone)
		return TRUE
	return zone.interdiction_allowed()

/**
 * Starts the rotation timer
 */
/datum/controller/subsystem/overmap_zones/proc/start_rotation_timer()
	if(rotation_timer_id)
		deltimer(rotation_timer_id)

	rotation_timer_id = addtimer(CALLBACK(src, PROC_REF(perform_rotation)), ZONE_ROTATION_INTERVAL, TIMER_STOPPABLE)

	// Set up warning timer
	if(warning_timer_id)
		deltimer(warning_timer_id)

	var/warning_delay = ZONE_ROTATION_INTERVAL - ZONE_SHIFT_WARNING_TIME
	if(warning_delay > 0)
		warning_timer_id = addtimer(CALLBACK(src, PROC_REF(announce_warning), ZONE_SHIFT_WARNING_TIME / 10), warning_delay, TIMER_STOPPABLE)

/**
 * Announces a zone shift warning
 */
/datum/controller/subsystem/overmap_zones/proc/announce_warning(seconds_remaining)
	var/minutes = round(seconds_remaining / 60)
	var/message
	if(minutes >= 1)
		message = "Zone shift in [minutes] minute\s. Prepare for zone boundary changes."
	else
		message = "Zone shift in [seconds_remaining] seconds. Zone boundaries are about to change!"

	priority_announce(message, "Overmap Zone Control")
	SEND_SIGNAL(src, COMSIG_GLOB_ZONE_SHIFT_WARNING, seconds_remaining)

	// Schedule final warning if this wasn't it
	if(seconds_remaining > (ZONE_SHIFT_FINAL_WARNING_TIME / 10))
		var/final_warning_delay = (seconds_remaining * 10) - ZONE_SHIFT_FINAL_WARNING_TIME
		if(final_warning_delay > 0)
			addtimer(CALLBACK(src, PROC_REF(announce_warning), ZONE_SHIFT_FINAL_WARNING_TIME / 10), final_warning_delay)

/**
 * Performs a zone rotation
 * Rotates zones by 120 degrees (one segment)
 */
/datum/controller/subsystem/overmap_zones/proc/perform_rotation()
	// Rotate by 120 degrees (one third of the circle)
	rotation_angle = (rotation_angle + 120) % 360

	// Track ships and their old zones for signals
	var/list/ship_old_zones = list()
	for(var/obj/structure/overmap/ship/S as anything in SSovermap.simulated_ships)
		var/turf/T = get_turf(S)
		if(T)
			var/datum/overmap_zone/old_zone = get_zone(T)
			if(old_zone)
				ship_old_zones[S] = old_zone.zone_type

	// Clear existing zone assignments
	zone_green.turfs.Cut()
	zone_yellow.turfs.Cut()
	zone_red.turfs.Cut()

	// Reassign all turfs
	var/list/affected_turfs = list()
	var/list/turfs_to_process = get_area_turfs(/area/overmap, target_z = OVERMAP_Z_LEVEL)

	for(var/turf/open/overmap/T as anything in turfs_to_process)
		if(!istype(T))
			continue

		var/old_zone_type = T.current_zone?.zone_type
		T.current_zone = null

		var/new_zone_type = calculate_zone_for_turf(T)
		var/datum/overmap_zone/target_zone = get_zone_datum(new_zone_type)
		if(target_zone)
			target_zone.add_turf(T)

		if(old_zone_type != new_zone_type)
			affected_turfs += T

	// Send ship zone change signals
	for(var/obj/structure/overmap/ship/S as anything in ship_old_zones)
		var/turf/T = get_turf(S)
		if(!T)
			continue
		var/datum/overmap_zone/new_zone = get_zone(T)
		var/old_zone_type = ship_old_zones[S]
		var/new_zone_type = new_zone?.zone_type
		if(old_zone_type != new_zone_type)
			SEND_SIGNAL(S, COMSIG_SHIP_ZONE_CHANGED, old_zone_type, new_zone_type)

	// Global signals
	SEND_SIGNAL(src, COMSIG_GLOB_ZONE_SHIFT, affected_turfs)
	SEND_SIGNAL(src, COMSIG_GLOB_ZONE_ROTATION_COMPLETE)

	// Update turf colors
	update_all_turf_colors()

	// Announce the shift
	priority_announce("Zone boundaries have shifted. Check your navigation systems for updated zone information.", "Overmap Zone Control")

	last_rotation_time = world.time

	// Start timer for next rotation
	start_rotation_timer()

/**
 * Gets time remaining until next zone rotation (in seconds)
 */
/datum/controller/subsystem/overmap_zones/proc/get_time_until_rotation()
	if(!last_rotation_time)
		return 0
	var/elapsed = world.time - last_rotation_time
	var/remaining = ZONE_ROTATION_INTERVAL - elapsed
	return max(0, remaining / 10) // Convert to seconds

/**
 * Admin proc: Force a zone rotation
 */
/datum/controller/subsystem/overmap_zones/proc/force_rotation()
	perform_rotation()

/**
 * Admin proc: Set rotation angle directly
 */
/datum/controller/subsystem/overmap_zones/proc/set_rotation(new_angle)
	rotation_angle = new_angle % 360
	// Re-assign zones without triggering full rotation
	zone_green.turfs.Cut()
	zone_yellow.turfs.Cut()
	zone_red.turfs.Cut()
	assign_zones()
	update_all_turf_colors()

/**
 * Updates the color of all overmap turfs based on their zone
 */
/datum/controller/subsystem/overmap_zones/proc/update_all_turf_colors()
	for(var/turf/open/overmap/T as anything in zone_green.turfs)
		T.update_zone_color()
	for(var/turf/open/overmap/T as anything in zone_yellow.turfs)
		T.update_zone_color()
	for(var/turf/open/overmap/T as anything in zone_red.turfs)
		T.update_zone_color()
