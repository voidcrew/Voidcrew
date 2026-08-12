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

	// Cache blocked turfs for O(1) pathfinding lookups
	cache_blocked_turfs()

	// Hook storm telegraphs so planet weather scales with zone danger (zone_weather.dm)
	setup_weather_scaling()

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
 * Resolves the zone type for any turf, including interiors of overmap objects.
 *
 * Overmap turfs resolve directly. Turfs inside a loaded space ruin, trader
 * outpost or planet resolve to the zone of that object's overmap tile.
 * Returns null when the location can't be tied to the overmap (e.g. ship
 * interiors, CentCom), callers pick their own default.
 */
/datum/controller/subsystem/overmap_zones/proc/get_zone_type_anywhere(turf/T)
	if(!T)
		return null
	if(istype(T, /turf/open/overmap))
		return resolve_zone_for_overmap_turf(T)
	var/obj/structure/overmap/holder = get_overmap_object_for_turf(T)
	if(!holder)
		return null
	var/turf/overmap_turf = get_turf(holder)
	if(!istype(overmap_turf, /turf/open/overmap))
		return null
	return resolve_zone_for_overmap_turf(overmap_turf)

/**
 * Zone type for an overmap turf, falling back to the static distance-from-sun
 * band formula when zone assignment hasn't run yet (zones never move, so the
 * formula always matches the eventual assignment).
 */
/datum/controller/subsystem/overmap_zones/proc/resolve_zone_for_overmap_turf(turf/T)
	var/zone_type = get_zone_type(T)
	if(!isnull(zone_type))
		return zone_type
	if(!SSovermap.overmap_centre)
		return null
	return SSovermap.get_zone_band_for_turf(T)

/**
 * Zone type for a z-level that belongs to a planet, or null for anything else.
 *
 * Narrower than get_zone_type_anywhere() on purpose: effects tuned for planet
 * surfaces (ore yields, fauna) must not leak onto the space ruins, asteroid
 * fields and trader outposts that also resolve to a zone. Falls back to the
 * band SSmapping dealt a pre-generated roundstart planet pair, which is the only
 * thing that answers before a dynamic planet has an overmap marker.
 */
/datum/controller/subsystem/overmap_zones/proc/planet_zone_type_for_z_level(z)
	if(!z)
		return null
	// Planets own whole z-levels, so any turf on one identifies it.
	var/turf/probe = locate(1, 1, z)
	var/obj/structure/overmap/holder = probe ? get_overmap_object_for_turf(probe) : null
	if(istype(holder, /obj/structure/overmap/planet))
		var/turf/overmap_turf = get_turf(holder)
		if(istype(overmap_turf, /turf/open/overmap))
			return resolve_zone_for_overmap_turf(overmap_turf)
	return SSmapping.get_planet_zone_band_for_z(z)

/**
 * Finds the overmap object whose loaded interior contains the given turf.
 */
/datum/controller/subsystem/overmap_zones/proc/get_overmap_object_for_turf(turf/T)
	// Space ruins: turf reservations on shared z-levels, bounds check
	for(var/obj/structure/overmap/space_ruin/ruin as anything in GLOB.space_ruin_signals)
		if(reservation_contains_turf(ruin.reservation, T))
			return ruin
	// Meteor storm fields: lazily-loaded reservations, same bounds check
	for(var/obj/structure/overmap/event/meteor/field as anything in GLOB.meteor_fields)
		if(reservation_contains_turf(field.reservation, T))
			return field
	// Trader outposts: same reservation pattern
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		if(reservation_contains_turf(outpost.reservation, T))
			return outpost
	// Planets: own whole z-levels via their mapzone
	for(var/obj/structure/overmap/planet/planet as anything in GLOB.overmap_planets)
		if(!planet.mapzone)
			continue
		for(var/datum/space_level/level as anything in planet.mapzone.z_levels)
			if(level.z_value == T.z)
				return planet
	// Player outposts: same whole-z-level pattern as planets
	for(var/obj/structure/overmap/dynamic/player_outpost/player_outpost as anything in GLOB.player_outposts)
		if(!player_outpost.mapzone)
			continue
		for(var/datum/space_level/level as anything in player_outpost.mapzone.z_levels)
			if(level.z_value == T.z)
				return player_outpost
	return null

/**
 * Whether a turf reservation's bounds contain the given turf.
 */
/datum/controller/subsystem/overmap_zones/proc/reservation_contains_turf(datum/turf_reservation/reservation, turf/T)
	if(!reservation || !length(reservation.bottom_left_turfs))
		return FALSE
	var/turf/bottom_left = reservation.bottom_left_turfs[1]
	if(!bottom_left || bottom_left.z != T.z)
		return FALSE
	return T.x >= bottom_left.x && T.x < bottom_left.x + reservation.width \
		&& T.y >= bottom_left.y && T.y < bottom_left.y + reservation.height

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

/**
 * Caches all blocked overmap turfs for O(1) pathfinding lookups.
 * Called once at initialization since the overmap is static.
 */
/datum/controller/subsystem/overmap_zones/proc/cache_blocked_turfs()
	var/blocked_count = 0
	var/list/all_turfs = get_area_turfs(/area/overmap, target_z = OVERMAP_Z_LEVEL)

	for(var/turf/T as anything in all_turfs)
		if(!T)
			continue
		// Check for blocking events (same logic as overmap_turf_blocked)
		for(var/obj/structure/overmap/event/E in T)
			// Nebulas are safe - skip them
			if(istype(E, /obj/structure/overmap/event/nebula))
				continue
			// Found a blocking event
			GLOB.overmap_blocked_turfs[T] = TRUE
			blocked_count++
			break

	log_world("SSovermap_zones: Cached [blocked_count] blocked turfs for pathfinding")
