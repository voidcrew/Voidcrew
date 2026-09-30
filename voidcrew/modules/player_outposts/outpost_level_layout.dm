/**
 * # One level per outpost
 *
 * A player outpost owns exactly one z-level and never asks the reservation allocator for
 * ground elsewhere. Everything it needs besides the habitat is a fixed zone on that level,
 * carved at founding:
 *
 *   y 253 +--------+---------------------------------------------+
 *         | berth4 |                                             |
 *         +--------+                                             |
 *         | berth3 |             build region (habitat)          |
 *         +--------+                                             |
 *         | berth2 |                                             |
 *         +--------+------+--------+----+--------------------------+
 *         | berth1 | bay  |  yard  |pen |                          |
 *   y 3   +--------+------+--------+----+--------------------------+
 *         x 3                                                  x 253
 *
 * Zones are separated from each other and from the build region by OUTPOST_LEVEL_GUTTER tiles
 * of /turf/cordon, and the level has an OUTPOST_LEVEL_EDGE-tile cordon rim. Everything outside
 * the build region sits in /area/voidcrew/outpost_vacant, which is NOTELEPORT: an empty zone
 * cannot be teleported into, so nobody is standing there when a berth loads over it.
 *
 * Sizes are defines in voidcrew/_DEFINES/player_outposts.dm; the coordinates come from
 * outpost_level_layout() so they can be retuned in one place.
 */

/// The ground round and between an outpost's zones: cordon gutters and empty zones.
/area/voidcrew/outpost_vacant
	name = "\improper Restricted Space"
	icon_state = "space"
	requires_power = TRUE
	always_unpowered = TRUE
	static_lighting = FALSE
	base_lighting_alpha = 255
	base_lighting_color = COLOR_STARLIGHT
	power_light = FALSE
	power_equip = FALSE
	power_environ = FALSE
	area_flags = UNIQUE_AREA | NO_GRAVITY | NOTELEPORT | HIDDEN_AREA
	outdoors = TRUE
	ambience_index = AMBIENCE_SPACE
	sound_environment = SOUND_AREA_SPACE
	ambient_buzz = null

/// The one shared instance of the vacant area
/proc/outpost_vacant_area()
	return GLOB.areas_by_type[/area/voidcrew/outpost_vacant] || new /area/voidcrew/outpost_vacant

/**
 * Where everything goes on an outpost's level, as key -> list(low_x, low_y, high_x, high_y).
 * Keys: "berth1".."berthN", OUTPOST_ZONE_BAY, OUTPOST_ZONE_YARD, OUTPOST_ZONE_PEN and
 * OUTPOST_LEVEL_BUILD_REGION. The berths stack up the west edge; the bay, the shipyard and the
 * ferry pen sit in a row along the south edge; the build region is the rest.
 */
/proc/outpost_level_layout()
	var/static/list/layout
	if(layout)
		return layout
	layout = list()
	var/low = OUTPOST_LEVEL_EDGE + 1
	var/high_x = world.maxx - OUTPOST_LEVEL_EDGE
	var/high_y = world.maxy - OUTPOST_LEVEL_EDGE

	var/berth_high_x = low + OUTPOST_BERTH_ZONE_WIDTH - 1
	for(var/number in 1 to OUTPOST_LEVEL_BERTHS)
		var/berth_low_y = low + (number - 1) * (OUTPOST_BERTH_ZONE_HEIGHT + OUTPOST_LEVEL_GUTTER)
		layout["[OUTPOST_ZONE_BERTH][number]"] = list(low, berth_low_y, berth_high_x, berth_low_y + OUTPOST_BERTH_ZONE_HEIGHT - 1)

	var/row_x = berth_high_x + OUTPOST_LEVEL_GUTTER + 1
	var/build_low_x = row_x
	layout[OUTPOST_ZONE_BAY] = list(row_x, low, row_x + OUTPOST_BAY_ZONE_WIDTH - 1, low + OUTPOST_BAY_ZONE_HEIGHT - 1)
	row_x += OUTPOST_BAY_ZONE_WIDTH + OUTPOST_LEVEL_GUTTER
	layout[OUTPOST_ZONE_YARD] = list(row_x, low, row_x + OUTPOST_YARD_ZONE_SIZE - 1, low + OUTPOST_YARD_ZONE_SIZE - 1)
	row_x += OUTPOST_YARD_ZONE_SIZE + OUTPOST_LEVEL_GUTTER
	layout[OUTPOST_ZONE_PEN] = list(row_x, low, row_x + OUTPOST_PEN_ZONE_WIDTH - 1, low + OUTPOST_PEN_ZONE_HEIGHT - 1)

	var/row_top = low + max(OUTPOST_BAY_ZONE_HEIGHT, OUTPOST_YARD_ZONE_SIZE, OUTPOST_PEN_ZONE_HEIGHT) - 1
	layout[OUTPOST_LEVEL_BUILD_REGION] = list(build_low_x, row_top + OUTPOST_LEVEL_GUTTER + 1, high_x, high_y)
	return layout

/**
 * One fixed rectangle of an outpost's level, reserved for a berth, the ship bay, the hidden
 * shipyard or the ferry pen. Vacant zones are empty space in the vacant area.
 */
/datum/outpost_zone
	/// Layout key: "berth1", "bay", "yard" or "pen"
	var/key
	/// OUTPOST_ZONE_BERTH, _BAY, _YARD or _PEN
	var/kind
	/// The berth number for a berth zone, else 1
	var/number = 1
	var/low_x
	var/low_y
	var/high_x
	var/high_y
	var/z_value
	/// OUTPOST_ZONE_VACANT, _BUILDING, _IN_USE or _WIPING
	var/state = OUTPOST_ZONE_VACANT
	/// Whatever holds the zone while it is not vacant: a berth, the ship bay, a hull copy, the ferry
	var/datum/weakref/holder
	/// Set while the outpost is deleted: its level teardown wipes everything, so holders let go
	/// without wiping their own zone
	var/retired = FALSE

/datum/outpost_zone/New(key, kind, number, list/rect, z_value)
	src.key = key
	src.kind = kind
	src.number = number
	low_x = rect[1]
	low_y = rect[2]
	high_x = rect[3]
	high_y = rect[4]
	src.z_value = z_value

/datum/outpost_zone/Destroy()
	holder = null
	return ..()

/datum/outpost_zone/proc/get_bottom_left()
	return locate(low_x, low_y, z_value)

/datum/outpost_zone/proc/get_top_right()
	return locate(high_x, high_y, z_value)

/datum/outpost_zone/proc/get_width()
	return high_x - low_x + 1

/datum/outpost_zone/proc/get_height()
	return high_y - low_y + 1

/datum/outpost_zone/proc/contains_turf(turf/location)
	if(!location || location.z != z_value)
		return FALSE
	return location.x >= low_x && location.x <= high_x && location.y >= low_y && location.y <= high_y

/datum/outpost_zone/proc/get_block()
	return block(low_x, low_y, z_value, high_x, high_y, z_value)

/datum/outpost_zone/proc/is_vacant()
	return state == OUTPOST_ZONE_VACANT

/// Takes a vacant zone for `new_holder` before anything is loaded into it. FALSE if it is taken.
/datum/outpost_zone/proc/claim(datum/new_holder)
	if(state != OUTPOST_ZONE_VACANT)
		return FALSE
	state = OUTPOST_ZONE_BUILDING
	holder = WEAKREF(new_holder)
	return TRUE

/// The holder finished loading into the zone.
/datum/outpost_zone/proc/occupy()
	if(state == OUTPOST_ZONE_BUILDING)
		state = OUTPOST_ZONE_IN_USE

/// Whether `thing` holds this zone. Still true while `thing` is being deleted.
/datum/outpost_zone/proc/is_held_by(datum/thing)
	return IS_WEAKREF_OF(thing, holder)

/**
 * Gives the zone back: everything on it is wiped (wipe()) and it is vacant again. The wipe
 * runs asynchronously, since holders let go from Destroy() and signal handlers. Calling it
 * again while it wipes, or on a vacant zone, does nothing.
 */
/datum/outpost_zone/proc/release()
	if(state == OUTPOST_ZONE_VACANT || state == OUTPOST_ZONE_WIPING)
		return
	holder = null
	// A deleted outpost's level teardown wipes the whole level; nothing to do here.
	if(retired || QDELETED(src))
		state = OUTPOST_ZONE_VACANT
		return
	state = OUTPOST_ZONE_WIPING
	INVOKE_ASYNC(src, PROC_REF(wipe))

/// A holder deleted while its map was still loading leaves the zone to its loader. This covers
/// a load that never returns: long after, a zone still building for nobody is given back.
/datum/outpost_zone/proc/release_stalled_build()
	if(state == OUTPOST_ZONE_BUILDING && !holder?.resolve())
		log_mapping("OUTPOST ZONE: [key] at z[z_value] was still building for a deleted holder, wiping it.")
		release()

/**
 * Deletes everything on the zone but observers (landmarks included), turns every tile back
 * into space in the vacant area and marks the zone vacant. The same sweep a map-zone slot
 * teardown runs (/datum/space_level/proc/wipe_turfs()).
 */
/datum/outpost_zone/proc/wipe()
	// The sweep below cannot delete docking ports (non-forced qdel is refused), and a stranded
	// one would be adopted by the next ferry or hull loaded here. A visiting hull's is never touched.
	var/list/obj/docking_port/ports = SSshuttle.mobile_docking_ports + SSshuttle.stationary_docking_ports
	for(var/obj/docking_port/port as anything in ports)
		if(QDELETED(port) || port.z != z_value || !contains_turf(get_turf(port)) || is_encounter_visiting_hull(port))
			continue
		qdel(port, force = TRUE)
	var/datum/space_level/level = z_value && z_value <= length(SSmapping.z_list) ? SSmapping.z_list[z_value] : null
	if(level)
		var/list/turf/ground = get_block()
		level.wipe_turfs(ground, ground, outpost_vacant_area(), list(low_x, low_y, high_x, high_y), throttled = FALSE)
	if(QDELETED(src))
		return
	state = OUTPOST_ZONE_VACANT

/obj/structure/overmap/dynamic/player_outpost
	/// The fixed zones on the outpost's level, layout key -> /datum/outpost_zone
	var/list/datum/outpost_zone/level_zones = list()

/// The zone stored under a layout key ("berth2", OUTPOST_ZONE_BAY, ...), or null
/obj/structure/overmap/dynamic/player_outpost/proc/level_zone(key)
	return level_zones[key]

/// The zone a berth number loads into, or null
/obj/structure/overmap/dynamic/player_outpost/proc/berth_zone(number)
	return level_zones["[OUTPOST_ZONE_BERTH][number]"]

// Hangar berths load into the berth zones instead of turf reservations (outpost_hangar.dm).
/obj/structure/overmap/dynamic/player_outpost/berths_on_level()
	return TRUE

/obj/structure/overmap/dynamic/player_outpost/berth_capacity()
	return OUTPOST_LEVEL_BERTHS

/obj/structure/overmap/dynamic/player_outpost/berth_zone_for(berth_number)
	return berth_zone(berth_number)

/// The zone containing `location`, or null (the build region and the gutters are no zone)
/obj/structure/overmap/dynamic/player_outpost/proc/zone_at(turf/location)
	for(var/key in level_zones)
		var/datum/outpost_zone/zone = level_zones[key]
		if(zone.contains_turf(location))
			return zone
	return null

/// The habitat: the build region, where the outpost's own announcements are heard.
/obj/structure/overmap/dynamic/player_outpost/proc/is_habitat_turf(turf/location)
	return is_turf_buildable(location)

/**
 * Carves the outpost's level at founding: the build region, the zones in the vacant area and
 * cordon everywhere else. Sets build_bounds. The level is fresh space when this runs.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/carve_level(datum/space_level/zlevel)
	var/z = zlevel.z_value
	var/list/layout = outpost_level_layout()
	var/list/build = layout[OUTPOST_LEVEL_BUILD_REGION]
	build_bounds = build.Copy()

	level_zones = list()
	for(var/key in layout)
		if(key == OUTPOST_LEVEL_BUILD_REGION)
			continue
		var/kind = key
		var/number = 1
		if(findtext(key, OUTPOST_ZONE_BERTH) == 1)
			kind = OUTPOST_ZONE_BERTH
			number = text2num(copytext(key, length(OUTPOST_ZONE_BERTH) + 1))
		level_zones[key] = new /datum/outpost_zone(key, kind, number, layout[key], z)

	var/area/vacant = outpost_vacant_area()
	for(var/turf/tile as anything in block(1, 1, z, world.maxx, world.maxy, z))
		if(tile.x >= build[1] && tile.x <= build[3] && tile.y >= build[2] && tile.y <= build[4])
			continue
		var/area/old_area = tile.loc
		if(old_area != vacant)
			tile.change_area(old_area, vacant)
		if(!zone_at(tile))
			zlevel.place_cordon_turf(tile)
		CHECK_TICK

	// The cordon went down as raw turf swaps, which recalculate nobody's atmos adjacency; the
	// cordon tiles hugging live ground strip themselves out of their neighbours' lists (see
	// place_cordon()).
	var/list/live_rects = list(build)
	for(var/key in level_zones)
		var/datum/outpost_zone/zone = level_zones[key]
		live_rects += list(list(zone.low_x, zone.low_y, zone.high_x, zone.high_y))
	for(var/list/rect as anything in live_rects)
		for(var/turf/edge_turf as anything in map_boundary_ring(rect[1], rect[2], rect[3], rect[4], z))
			if(istype(edge_turf, /turf/cordon))
				edge_turf.air_update_turf(TRUE, TRUE)
		CHECK_TICK

/// The player outpost whose level is `z`, or null
/proc/player_outpost_on_level(z)
	if(!z)
		return null
	for(var/obj/structure/overmap/dynamic/player_outpost/home as anything in GLOB.player_outposts)
		var/datum/space_level/level = LAZYACCESS(home.mapzone?.z_levels, 1)
		if(level?.z_value == z)
			return home
	return null

/**
 * Whether a teleport onto `destination` crosses between the zones of a player outpost's level and
 * the rest of it (check_teleport_valid()). The zones share the habitat's level but are only
 * reached by the hangar lift: a crystal at the habitat's edge must not drop anyone into a ship in
 * a berth, or out of one past the outpost's docking rules.
 *
 * Only same-level moves are judged, so a pad aboard a ship in a berth still takes its crew home
 * from elsewhere. An imprecise teleport is also held to the zone it was aimed at (`wanted`).
 */
/proc/outpost_zone_teleport_refused(turf/origin, turf/destination, turf/wanted)
	if(!destination)
		return FALSE
	var/obj/structure/overmap/dynamic/player_outpost/home = player_outpost_on_level(destination.z)
	if(!home)
		return FALSE
	var/datum/outpost_zone/landing = home.zone_at(destination)
	if(wanted?.z == destination.z && home.zone_at(wanted) != landing)
		return TRUE
	if(origin?.z == destination.z && home.zone_at(origin) != landing)
		return TRUE
	return FALSE
