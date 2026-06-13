/**
 * # Ship Waypoints
 *
 * Charted points of interest shown on the helm's waypoint readout.
 * Pure QoL bookkeeping: no detection, no map pings — just a name and
 * overmap coordinates the helm renders with live distance/bearing.
 *
 * Sources push waypoints keyed by a source_key (mission REF, outpost REF)
 * so re-pushing updates in place and a dead source can clean up after itself.
 */
/datum/ship_waypoint
	/// Display name shown on the helm readout
	var/name = "waypoint"
	/// Target X in relative overmap coordinates (1 to OVERMAP_SIZE)
	var/target_x = 0
	/// Target Y in relative overmap coordinates (1 to OVERMAP_SIZE)
	var/target_y = 0
	/// Dedup/cleanup key identifying who pushed this waypoint
	var/source_key
	/// Optional moving target (weakref to an overmap object, e.g. a bounty's
	/// pirate ship). Resolved at read time; target_x/y become the last known
	/// position if the target stops resolving.
	var/datum/weakref/tracked_target

/**
 * Returns list(x, y) in relative overmap coordinates. For tracked waypoints
 * this is the target's live position (cached into target_x/y as last-known).
 */
/datum/ship_waypoint/proc/get_coords()
	var/obj/structure/overmap/target = tracked_target?.resolve()
	if(target)
		var/list/live = target.get_relative_overmap_coords()
		if(live)
			target_x = live[1]
			target_y = live[2]
	return list(target_x, target_y)

/obj/structure/overmap/ship
	/// Waypoints charted on this ship's helm readout
	var/list/datum/ship_waypoint/waypoints = list()

/**
 * Adds a waypoint to the helm readout, or updates the existing one with the
 * same source_key (so retargeting missions move their marker instead of
 * stacking new ones). Pass track_target to make the waypoint follow a moving
 * overmap object.
 */
/obj/structure/overmap/ship/proc/add_waypoint(source_key, name, target_x, target_y, obj/structure/overmap/track_target)
	var/datum/ship_waypoint/waypoint = get_waypoint(source_key)
	if(!waypoint)
		waypoint = new
		waypoint.source_key = source_key
		waypoints += waypoint
	waypoint.name = name
	waypoint.target_x = target_x
	waypoint.target_y = target_y
	waypoint.tracked_target = track_target ? WEAKREF(track_target) : null
	return waypoint

/**
 * Finds the waypoint pushed under a given source_key, if any.
 */
/obj/structure/overmap/ship/proc/get_waypoint(source_key)
	for(var/datum/ship_waypoint/waypoint as anything in waypoints)
		if(waypoint.source_key == source_key)
			return waypoint
	return null

/**
 * Removes the waypoint pushed under a given source_key (no-op if absent).
 */
/obj/structure/overmap/ship/proc/remove_waypoint(source_key)
	var/datum/ship_waypoint/waypoint = get_waypoint(source_key)
	if(waypoint)
		delete_waypoint(waypoint)

/**
 * Removes a specific waypoint datum (used by the helm's clear button).
 */
/obj/structure/overmap/ship/proc/delete_waypoint(datum/ship_waypoint/waypoint)
	waypoints -= waypoint
	qdel(waypoint)

/**
 * Returns this overmap object's position as list(x, y) in relative overmap
 * coordinates (1 to OVERMAP_SIZE), or null if it isn't anywhere.
 * Works while docked too: get_turf resolves through the holder object.
 */
/obj/structure/overmap/proc/get_relative_overmap_coords()
	var/turf/our_turf = get_turf(src)
	if(!our_turf)
		return null
	return list(our_turf.x - OVERMAP_LEFT_SIDE_COORD + 1, our_turf.y - OVERMAP_SOUTH_SIDE_COORD + 1)

/**
 * Returns an 8-point compass bearing ("N", "NE", ...) for an overmap delta,
 * or null for a zero delta. Sectors are the standard 45-degree octants
 * (0.4142 = tan(22.5 degrees)).
 */
/proc/overmap_delta_to_compass(dx, dy)
	if(!dx && !dy)
		return null
	. = ""
	if(abs(dy) > abs(dx) * 0.4142)
		. += dy > 0 ? "N" : "S"
	if(abs(dx) > abs(dy) * 0.4142)
		. += dx > 0 ? "E" : "W"
