/**
 * # Overmap Zone Datum
 *
 * Represents a zone on the overmap with specific PvP rules and properties.
 * Zones are defined by their type (GREEN/YELLOW/RED) and track which turfs belong to them.
 */
/datum/overmap_zone
	/// The zone type (ZONE_GREEN, ZONE_YELLOW, ZONE_RED)
	var/zone_type = ZONE_GREEN
	/// Associative list of overmap turfs in this zone (turf -> TRUE for O(1) lookup)
	var/list/turfs = list()
	/// Display name for this zone
	var/name = "Unknown Zone"

/datum/overmap_zone/New(zone_type_to_set)
	. = ..()
	if(zone_type_to_set)
		zone_type = zone_type_to_set
	update_name()

/datum/overmap_zone/Destroy()
	// Clear turf references
	for(var/turf/open/overmap/T as anything in turfs)
		T.current_zone = null
	turfs.Cut()
	return ..()

/**
 * Updates the zone's display name based on its type
 */
/datum/overmap_zone/proc/update_name()
	switch(zone_type)
		if(ZONE_GREEN)
			name = ZONE_NAME_GREEN
		if(ZONE_YELLOW)
			name = ZONE_NAME_YELLOW
		if(ZONE_RED)
			name = ZONE_NAME_RED

/**
 * Returns whether ship weapons (missiles, lasers) are allowed in this zone
 */
/datum/overmap_zone/proc/weapons_allowed()
	return ZONE_WEAPONS_ALLOWED(zone_type)

/**
 * Returns whether interdiction is allowed in this zone
 */
/datum/overmap_zone/proc/interdiction_allowed()
	return ZONE_INTERDICTION_ALLOWED(zone_type)

/**
 * Returns whether forced docking is allowed in this zone
 */
/datum/overmap_zone/proc/forced_docking_allowed()
	return ZONE_FORCED_DOCKING_ALLOWED(zone_type)

/**
 * Returns the display color for this zone type
 */
/datum/overmap_zone/proc/get_color()
	switch(zone_type)
		if(ZONE_GREEN)
			return ZONE_COLOR_GREEN
		if(ZONE_YELLOW)
			return ZONE_COLOR_YELLOW
		if(ZONE_RED)
			return ZONE_COLOR_RED
	return "#ffffff"

/**
 * Returns the description for this zone type
 */
/datum/overmap_zone/proc/get_description()
	switch(zone_type)
		if(ZONE_GREEN)
			return ZONE_DESC_GREEN
		if(ZONE_YELLOW)
			return ZONE_DESC_YELLOW
		if(ZONE_RED)
			return ZONE_DESC_RED
	return "Unknown zone type."

/**
 * Adds a turf to this zone
 */
/datum/overmap_zone/proc/add_turf(turf/open/overmap/T)
	if(!istype(T))
		return FALSE
	if(turfs[T])  // O(1) lookup
		return FALSE

	var/old_zone_type = null
	if(T.current_zone)
		old_zone_type = T.current_zone.zone_type
		T.current_zone.remove_turf(T)

	turfs[T] = TRUE  // Associative list entry
	T.current_zone = src

	// Send signal that turf's zone changed
	if(old_zone_type != zone_type)
		SEND_SIGNAL(T, COMSIG_TURF_ZONE_CHANGED, old_zone_type, zone_type)

	return TRUE

/**
 * Removes a turf from this zone
 */
/datum/overmap_zone/proc/remove_turf(turf/open/overmap/T)
	if(!istype(T))
		return FALSE
	if(!turfs[T])  // O(1) lookup
		return FALSE

	turfs -= T
	if(T.current_zone == src)
		T.current_zone = null

	return TRUE

/**
 * Gets all ships currently in this zone
 */
/datum/overmap_zone/proc/get_ships()
	var/list/ships = list()
	for(var/turf/open/overmap/T as anything in turfs)
		for(var/obj/structure/overmap/ship/S in T)
			ships += S
	return ships
