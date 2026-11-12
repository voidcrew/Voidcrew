/**
 * # Outpost floors: the host
 *
 * Owner: P1. The host type, its `floor` var and its two frozen overrides (is_turf_buildable(), contains_service_turf())
 * are in _floor_types.dm. Everything else a player outpost does that assumes a level of its own is overridden here:
 * found(), load_level(), adopt_built_turfs(), upgrade_level_z(), announcement_listeners(), ship_act(),
 * ensure_home_services() and Destroy() (build plan P1).
 *
 * P0 proved the host safe in nullspace (unit test voidcrew_outpost_floors_seam_host_off_overmap): Initialize(),
 * the lookups that walk GLOB.player_outposts and GLOB.overmap_objects, and Destroy() run with no runtime. The base
 * Destroy() only frees a mapzone when there is one, and a floor never has one.
 */

/obj/structure/overmap/dynamic/player_outpost/floor
	name = "outpost floor"
	desc = "A leased floor of a trader outpost."
	// Never a contact: it is not on the overmap, and nothing may chart it if an admin ever puts it there.
	sensor_detectable = FALSE
	sensor_visible = FALSE

/// P0 wrote the two-way unlink; P1 adds the rest (occupants to the lobby, the reservation, A10).
/obj/structure/overmap/dynamic/player_outpost/floor/Destroy()
	if(floor?.host == src)
		floor.host = null
	floor = null
	return ..()
