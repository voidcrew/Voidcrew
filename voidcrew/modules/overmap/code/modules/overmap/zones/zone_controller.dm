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

	/// Whether the zone system is active
	var/zones_active = FALSE

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

	// Assign zones to all overmap turfs based on distance from center
	assign_zones()

	log_world("SSovermap_zones: Assigned zones - Green: [length(zone_green.turfs)], Yellow: [length(zone_yellow.turfs)], Red: [length(zone_red.turfs)]")

	// Update all turf colors
	update_all_turf_colors()

	zones_active = TRUE

	log_world("SSovermap_zones: Initialization complete!")
	return SS_INIT_SUCCESS

/datum/controller/subsystem/overmap_zones/Destroy()
	QDEL_NULL(zone_green)
	QDEL_NULL(zone_yellow)
	QDEL_NULL(zone_red)
	return ..()

/datum/controller/subsystem/overmap_zones/fire(resumed)
	// The subsystem doesn't need to fire - zones are static based on distance from center
	return

/**
 * Assigns all overmap turfs to their appropriate zones based on distance from center
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
 * Calculates which zone type a turf should belong to based on distance from center
 *
 * The zone system uses concentric rings radiating from the sun:
 * - Inner ring = Red (dangerous, near sun)
 * - Middle ring = Yellow (caution)
 * - Outer ring = Green (safe, edge of map)
 */
/datum/controller/subsystem/overmap_zones/proc/calculate_zone_for_turf(turf/T)
	if(!T)
		return ZONE_GREEN

	// Calculate offset from center (sun)
	var/dx = T.x - center_x
	var/dy = T.y - center_y

	// Distance-based concentric rings (roughly equal thirds)
	var/distance = sqrt(dx * dx + dy * dy)
	var/normalized = distance / max_radius

	// Inner ring (Red) - dangerous, close to sun
	if(normalized < 0.33)
		return ZONE_RED

	// Middle ring (Yellow) - caution zone
	if(normalized < 0.66)
		return ZONE_YELLOW

	// Outer ring (Green) - safe, edge of map
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
 * Updates the color of all overmap turfs based on their zone
 */
/datum/controller/subsystem/overmap_zones/proc/update_all_turf_colors()
	for(var/turf/open/overmap/T as anything in zone_green.turfs)
		T.update_zone_color()
	for(var/turf/open/overmap/T as anything in zone_yellow.turfs)
		T.update_zone_color()
	for(var/turf/open/overmap/T as anything in zone_red.turfs)
		T.update_zone_color()
