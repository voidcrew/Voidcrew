/**
 * # Ship Waypoints
 *
 * Charted points of interest shown on the helm's waypoint readout.
 * Pure QoL bookkeeping: no detection, no map pings, just a name and
 * overmap coordinates the helm renders with live distance/bearing.
 *
 * Sources push waypoints keyed by a source_key (mission REF, outpost REF)
 * so re-pushing updates in place and a dead source can clean up after itself.
 */
/datum/ship_waypoint
	/// Display name shown on the helm readout
	var/name = "waypoint"
	/// Category the helm groups/filters this entry under (e.g. "Missions", "Planets")
	var/category = "Waypoints"
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
 * stacking new ones). Pass category to group/filter the entry on the helm, and
 * track_target to make the waypoint follow a moving overmap object.
 */
/obj/structure/overmap/ship/proc/add_waypoint(source_key, name, target_x, target_y, category = "Waypoints", obj/structure/overmap/track_target)
	var/datum/ship_waypoint/waypoint = get_waypoint(source_key)
	if(!waypoint)
		waypoint = new
		waypoint.source_key = source_key
		waypoints += waypoint
	waypoint.name = name
	waypoint.target_x = target_x
	waypoint.target_y = target_y
	waypoint.category = category
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
 * # Fleet beacons
 *
 * A few sites announce themselves to the whole galaxy the moment they surface,
 * the Verdigris, the Grand Colosseum, a contested cache, and chart themselves
 * onto every helm so nobody has to go hunting for a thing that just shouted its
 * own coordinates. That push was a one-shot walk of SSovermap.simulated_ships at
 * surface time, which silently excluded every ship built AFTER it: a mid-round
 * hull requisition, a commissioned hull, a respawn into a fresh vessel. Those
 * crews came up with an empty Events list for a site the rest of the fleet had
 * been looking at for twenty minutes.
 *
 * So a broadcasting site registers here rather than firing once and forgetting.
 * The push becomes repeatable in both directions: a new ship asks the register
 * for a copy of everything currently broadcasting (receive_fleet_waypoints,
 * called from setup_from_template), and a site that is defeated or retires
 * deregisters so latecomers stop being told about it.
 */
GLOBAL_LIST_EMPTY(overmap_fleet_beacons)

/obj/structure/overmap
	/// Label this site's fleet-wide waypoint carries on the helm. Set on the
	/// handful of sites that broadcast themselves; null everywhere else, which is
	/// what broadcast_fleet_waypoint() refuses on.
	var/fleet_waypoint_name
	/// Helm category the fleet waypoint is grouped under.
	var/fleet_waypoint_category = "Events"

/// Dedup key for this site's fleet waypoint. Per-instance, so two caches in one
/// round chart separately.
/obj/structure/overmap/proc/fleet_waypoint_key()
	return "beacon_[REF(src)]"

/**
 * Starts broadcasting: charts this site on every helm in the fleet right now,
 * and registers so ships created later get it too. Idempotent, re-calling
 * refreshes the existing waypoints in place rather than stacking new ones.
 */
/obj/structure/overmap/proc/broadcast_fleet_waypoint()
	if(!fleet_waypoint_name)
		CRASH("broadcast_fleet_waypoint() on [type], which sets no fleet_waypoint_name")
	GLOB.overmap_fleet_beacons |= src
	if(!SSovermap)
		return
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(QDELETED(ship))
			continue
		push_fleet_waypoint(ship)

/// Charts this site onto one ship's helm. The single-ship half of the broadcast,
/// so the register can replay it for a ship that did not exist at surface time.
/obj/structure/overmap/proc/push_fleet_waypoint(obj/structure/overmap/ship/ship)
	var/list/coords = get_relative_overmap_coords()
	ship.add_waypoint(
		fleet_waypoint_key(),
		fleet_waypoint_name,
		coords ? coords[1] : 0,
		coords ? coords[2] : 0,
		fleet_waypoint_category,
		track_target = src,
	)

/**
 * Stops broadcasting: deregisters and clears the waypoint off every helm that
 * has it. Safe to call twice, and safe to call on a site that never broadcast.
 */
/obj/structure/overmap/proc/clear_fleet_waypoint()
	GLOB.overmap_fleet_beacons -= src
	if(!SSovermap)
		return
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(QDELETED(ship))
			continue
		ship.remove_waypoint(fleet_waypoint_key())

/**
 * Charts every site currently broadcasting onto this ship. Called once as the
 * ship registers into SSovermap.simulated_ships, which is what makes a hull
 * built mid-round see the same galaxy the rest of the fleet does.
 */
/obj/structure/overmap/ship/proc/receive_fleet_waypoints()
	for(var/obj/structure/overmap/beacon as anything in GLOB.overmap_fleet_beacons)
		if(QDELETED(beacon))
			GLOB.overmap_fleet_beacons -= beacon
			continue
		beacon.push_fleet_waypoint(src)

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
