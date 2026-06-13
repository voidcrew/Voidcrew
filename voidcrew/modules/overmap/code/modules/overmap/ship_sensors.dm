/**
 * # Ship Sensors & Discovery
 *
 * Active, on-demand detection: the crew triggers a scan for a specific kind of
 * object from the helm, and every matching STATIC object inside sensor range is
 * added to the helm's waypoint list (charting nothing automatically, saving
 * nothing the crew didn't ask for). Star charts (`star_chart.dm`) do the same in
 * bulk for a whole zone band — the certainty channel for discovery.
 *
 * The radar capability ladder is a dedicated R&D tree (see `radar_array*` nodes
 * in [[modules/research]]), read off the ship's techweb:
 * - higher tiers widen the scan radius (get_sensor_range),
 * - the mid tier identifies space ruins (true name instead of "unknown signal"),
 * - the top tier adds live player-ship tracking (helm, range-limited, ephemeral).
 *
 * Static scans never pick up ships or hazards. Ship tracking is its own live
 * readout gated behind the top radar tier; hazards stay undetectable entirely.
 */

/// Base scan radius, in overmap tiles, with no radar research.
#define SENSOR_RANGE_BASE 4
/// Scan radius granted by the tier-1 radar array node.
#define SENSOR_RANGE_ADVANCED 6
/// Scan radius granted by the tier-2 radar array node.
#define SENSOR_RANGE_SUPERIOR 8
/// Scan radius granted by the tier-3 radar array node.
#define SENSOR_RANGE_ELITE 10

/// Recharge between active scans.
#define SENSOR_SCAN_COOLDOWN (1 MINUTES)

/obj/structure/overmap
	/// Whether an active scan can detect this object. Scannable statics only —
	/// set TRUE on planets and ruins. Trader outposts are always listed by the
	/// helm directly, ships are tracked live by the top radar tier, and hazards
	/// stay undetectable — none of those carry this flag.
	var/sensor_detectable = FALSE
	/// Display category this object is grouped under on the helm readout, and
	/// the key an active scan matches against (e.g. "Planets", "Ruins").
	var/sensor_category = "Contacts"

/obj/structure/overmap/ship
	/// Scan radius before R&D upgrades. See get_sensor_range().
	var/base_sensor_range = SENSOR_RANGE_BASE
	COOLDOWN_DECLARE(sensor_scan_cooldown)
	/// Cached techweb resolved from the onboard R&D server (see get_research_web).
	var/datum/weakref/research_web_ref
	COOLDOWN_DECLARE(research_web_search_cooldown)

/**
 * Returns the ship's research techweb — the one hosted on its onboard R&D
 * server's disk, which is where radar nodes actually get researched. Cached by
 * weakref; the (potentially expensive) server search is throttled so a ship
 * with no R&D server doesn't rescan its whole hull every tick.
 */
/obj/structure/overmap/ship/proc/get_research_web()
	var/datum/techweb/web = research_web_ref?.resolve()
	if(web)
		return web
	if(!COOLDOWN_FINISHED(src, research_web_search_cooldown))
		return null
	COOLDOWN_START(src, research_web_search_cooldown, 10 SECONDS)
	web = find_research_web()
	if(web)
		research_web_ref = WEAKREF(web)
	return web

/**
 * Locates the techweb hosted by an R&D server somewhere on the ship's hull.
 */
/obj/structure/overmap/ship/proc/find_research_web()
	if(!shuttle)
		return null
	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
		for(var/turf/tile in shuttle_area)
			for(var/obj/machinery/rnd/server/ship/server in tile)
				if(server.stored_research)
					return server.stored_research
	return null

/**
 * Returns the scan radius in tiles, scaling with the ship's radar research tier.
 * Falls back to the base range with no radar nodes researched.
 */
/obj/structure/overmap/ship/proc/get_sensor_range()
	var/datum/techweb/web = get_research_web()
	if(web)
		if(TECHWEB_NODE_RADAR_ARRAY_ELITE in web.researched_nodes)
			return SENSOR_RANGE_ELITE
		if(TECHWEB_NODE_RADAR_ARRAY_ADV in web.researched_nodes)
			return SENSOR_RANGE_SUPERIOR
		if(TECHWEB_NODE_RADAR_ARRAY in web.researched_nodes)
			return SENSOR_RANGE_ADVANCED
	return base_sensor_range

/**
 * Whether the radar can identify space ruins (tier-2 radar node), revealing the
 * ruin's true name on the readout instead of the generic "unknown signal".
 */
/obj/structure/overmap/ship/proc/can_identify_ruins()
	var/datum/techweb/web = get_research_web()
	if(!web)
		return FALSE
	return (TECHWEB_NODE_RADAR_ARRAY_ADV in web.researched_nodes) || (TECHWEB_NODE_RADAR_ARRAY_ELITE in web.researched_nodes)

/**
 * Whether the radar can track live player-ship contacts (tier-3 radar node).
 */
/obj/structure/overmap/ship/proc/can_scan_ships()
	var/datum/techweb/web = get_research_web()
	if(!web)
		return FALSE
	return TECHWEB_NODE_RADAR_ARRAY_ELITE in web.researched_nodes

/**
 * Active scan: sweeps for static objects in the given category within sensor
 * range and adds each as a waypoint. Returns the count of newly-added contacts
 * (already-charted ones are refreshed in place, not recounted), or -1 if the
 * sensors are still recharging from a previous scan.
 */
/obj/structure/overmap/ship/proc/active_scan(category)
	if(state != OVERMAP_SHIP_FLYING)
		return 0
	if(!COOLDOWN_FINISHED(src, sensor_scan_cooldown))
		return -1
	var/turf/center = get_turf(src)
	if(!center)
		return 0
	var/found = 0
	for(var/obj/structure/overmap/candidate in range(get_sensor_range(), center))
		if(candidate == src || !candidate.sensor_detectable)
			continue
		if(category && candidate.sensor_category != category)
			continue
		if(chart_as_waypoint(candidate))
			found++
	// Only spend the cooldown on a productive scan — an empty sweep can retry.
	if(found > 0)
		COOLDOWN_START(src, sensor_scan_cooldown, SENSOR_SCAN_COOLDOWN)
	return found

/**
 * Adds a static object to the waypoint list, keyed by its ref so a re-scan
 * updates in place instead of stacking. Ruins resolve to their true name when
 * the radar can identify them. Returns TRUE only if the waypoint is new.
 */
/obj/structure/overmap/ship/proc/chart_as_waypoint(obj/structure/overmap/object)
	var/key = REF(object)
	var/was_charted = !isnull(get_waypoint(key))
	var/list/coords = object.get_relative_overmap_coords()
	if(!coords)
		return FALSE
	add_waypoint(key, get_contact_name(object), coords[1], coords[2], object.sensor_category)
	return !was_charted

/**
 * The label a charted contact shows. Identifies ruins by their true name when
 * radar identification is researched; otherwise uses the object's own name.
 */
/obj/structure/overmap/ship/proc/get_contact_name(obj/structure/overmap/object)
	if(istype(object, /obj/structure/overmap/space_ruin) && can_identify_ruins())
		var/obj/structure/overmap/space_ruin/ruin = object
		if(ruin.true_name)
			return ruin.true_name
	return object.name

/**
 * Charts every static object whose overmap tile is in the given zone band,
 * adding each as a waypoint. Used by star charts. Returns the count of newly
 * added contacts.
 */
/obj/structure/overmap/ship/proc/chart_zone(zone_type)
	if(!SSovermap_zones?.initialized)
		return 0
	var/found = 0
	var/turf/low_corner = locate(OVERMAP_LEFT_SIDE_COORD, OVERMAP_SOUTH_SIDE_COORD, OVERMAP_Z_LEVEL)
	var/turf/high_corner = locate(OVERMAP_RIGHT_SIDE_COORD, OVERMAP_NORTH_SIDE_COORD, OVERMAP_Z_LEVEL)
	if(!low_corner || !high_corner)
		return 0
	for(var/turf/tile as anything in block(low_corner, high_corner))
		for(var/obj/structure/overmap/candidate in tile)
			if(!candidate.sensor_detectable)
				continue
			var/datum/overmap_zone/zone = SSovermap_zones.get_zone(tile)
			if(!zone || zone.zone_type != zone_type)
				continue
			if(chart_as_waypoint(candidate))
				found++
	return found

#undef SENSOR_RANGE_BASE
#undef SENSOR_RANGE_ADVANCED
#undef SENSOR_RANGE_SUPERIOR
#undef SENSOR_RANGE_ELITE
#undef SENSOR_SCAN_COOLDOWN
