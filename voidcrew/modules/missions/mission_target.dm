/**
 * # Mission Targets
 *
 * Where a mission points: a live space ruin, a planet, bare overmap
 * coordinates, or another trader outpost. The target datum owns picking the
 * spot, caching its relative coordinates and zone, telling the mission when
 * the site's interior becomes available (for spawning field objectives), and
 * telling the mission when the target is lost so the shell's retarget/fail
 * policy can run.
 *
 * Everything here used to live inside /datum/mission/recovery; hoisting it
 * lets any mission type aim at any kind of target.
 */
/datum/mission_target
	/// The mission this target belongs to
	var/datum/mission/mission
	/// Cached relative overmap coordinates of the target
	var/target_x = 0
	var/target_y = 0

/datum/mission_target/New(datum/mission/mission)
	..()
	src.mission = mission

/datum/mission_target/Destroy()
	unhook()
	mission = null
	return ..()

/**
 * Picks (or re-picks) an actual target. Returns TRUE on success; FALSE means
 * no valid target exists right now (generation fails or retarget fails).
 */
/datum/mission_target/proc/resolve()
	return FALSE

/// Whether the picked target still exists
/datum/mission_target/proc/is_valid()
	return TRUE

/// Drops signal hooks on the underlying target object (idempotent)
/datum/mission_target/proc/unhook()
	return

/// Zone type (ZONE_*) of the target's overmap tile, or null
/datum/mission_target/proc/get_zone_type()
	return null

/// Whether the target's interior is loaded and can take objective spawns now
/datum/mission_target/proc/is_interior_loaded()
	return TRUE

/**
 * Asks to be told when the interior loads: calls mission.on_target_interior_loaded()
 * once. No-op if the interior concept doesn't apply.
 */
/datum/mission_target/proc/notify_when_loaded()
	return

/// A random open turf inside the loaded interior for objective spawns
/datum/mission_target/proc/get_spawn_turf()
	return null

/// Whether the given turf lies inside the target's interior footprint
/datum/mission_target/proc/contains_turf(turf/T)
	return FALSE

/**
 * Interior footprint as list(min_x, min_y, max_x, max_y, z), or null.
 * Cached by the mission when a quest atom registers, so stranding checks
 * still work while the target object is mid-deletion.
 */
/datum/mission_target/proc/get_interior_bounds()
	return null

/// Recaches target_x/target_y from the live object
/datum/mission_target/proc/refresh_coords()
	return

/// Helper: relative overmap coords of an overmap object
/datum/mission_target/proc/cache_coords_from(atom/movable/object)
	if(!object)
		return
	target_x = object.x
	target_y = object.y - OVERMAP_SOUTH_SIDE_COORD + 1

// =========================================================================
// SPACE RUIN — the classic recovery-family target
// =========================================================================

/datum/mission_target/space_ruin
	/// The ruin signal this mission targets
	var/obj/structure/overmap/space_ruin/ruin

/datum/mission_target/space_ruin/resolve()
	var/obj/structure/overmap/space_ruin/previous = ruin
	unhook()
	var/list/candidates = list()
	var/list/unclaimed = list()
	for(var/obj/structure/overmap/space_ruin/candidate as anything in GLOB.space_ruin_signals)
		if(QDELETED(candidate))
			continue
		if(candidate == previous)
			continue
		// A mission owns this ruin's whole lifecycle (the drug run's hidden
		// lab): never point another contract's objectives into it
		if(candidate.mission_locked)
			continue
		if(!istype(get_turf(candidate), /turf/open/overmap))
			continue
		candidates += candidate
		if(candidate.mission_claims <= 0)
			unclaimed += candidate
	if(!length(candidates))
		return FALSE
	// Prefer ruins no other mission is already pointed at; double-book only when
	// every candidate is taken
	ruin = pick(length(unclaimed) ? unclaimed : candidates)
	ruin.mission_claims++
	cache_coords_from(ruin)
	RegisterSignal(ruin, COMSIG_QDELETING, PROC_REF(on_ruin_deleted))
	return TRUE

/datum/mission_target/space_ruin/is_valid()
	return !QDELETED(ruin)

/datum/mission_target/space_ruin/unhook()
	if(ruin)
		ruin.mission_claims = max(ruin.mission_claims - 1, 0)
		UnregisterSignal(ruin, list(COMSIG_QDELETING, COMSIG_VOIDCREW_PLANET_LOADED))
		ruin = null

/datum/mission_target/space_ruin/get_zone_type()
	if(!ruin)
		return null
	return SSovermap_zones?.get_zone_type(get_turf(ruin))

/datum/mission_target/space_ruin/is_interior_loaded()
	return ruin?.loaded

/datum/mission_target/space_ruin/notify_when_loaded()
	if(!ruin)
		return
	RegisterSignal(ruin, COMSIG_VOIDCREW_PLANET_LOADED, PROC_REF(on_ruin_loaded))

/datum/mission_target/space_ruin/proc/on_ruin_loaded(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(ruin, COMSIG_VOIDCREW_PLANET_LOADED)
	mission?.on_target_interior_loaded()

/datum/mission_target/space_ruin/get_spawn_turf()
	return ruin?.get_random_interior_turf() || ruin?.ruin_bottom_left

/datum/mission_target/space_ruin/contains_turf(turf/T)
	if(!ruin || !T)
		return FALSE
	var/datum/turf_reservation/reservation = ruin.reservation
	if(!reservation || !length(reservation.bottom_left_turfs))
		return FALSE
	var/turf/bottom_left = reservation.bottom_left_turfs[1]
	if(!bottom_left || bottom_left.z != T.z)
		return FALSE
	return T.x >= bottom_left.x && T.x < bottom_left.x + reservation.width \
		&& T.y >= bottom_left.y && T.y < bottom_left.y + reservation.height

/datum/mission_target/space_ruin/get_interior_bounds()
	var/datum/turf_reservation/reservation = ruin?.reservation
	if(!reservation || !length(reservation.bottom_left_turfs))
		return null
	var/turf/bottom_left = reservation.bottom_left_turfs[1]
	if(!bottom_left)
		return null
	return list(
		bottom_left.x,
		bottom_left.y,
		bottom_left.x + reservation.width - 1,
		bottom_left.y + reservation.height - 1,
		bottom_left.z,
	)

/// The ruin was abandoned and is respawning elsewhere
/datum/mission_target/space_ruin/proc/on_ruin_deleted(datum/source)
	SIGNAL_HANDLER
	unhook()
	mission?.on_target_lost()

// =========================================================================
// PLANET — the same interface pointed at a planet surface
// =========================================================================

/datum/mission_target/planet
	/// The planet this mission targets
	var/obj/structure/overmap/planet/planet
	/// Optional /datum/overmap/planet typepath filter: when set, resolve() only
	/// accepts planets of exactly that type ("the lava planet"). Null = any
	/// planet, the original behavior. NOTE: with one planet of each type per
	/// round, a filtered RE-resolve (retarget) finds nothing — the previous
	/// planet is excluded — so filtered missions should use the FAIL loss policy.
	var/wanted_planet

/datum/mission_target/planet/resolve()
	var/obj/structure/overmap/planet/previous = planet
	unhook()
	var/list/candidates = list()
	for(var/obj/structure/overmap/planet/candidate as anything in GLOB.overmap_planets)
		if(QDELETED(candidate))
			continue
		if(candidate == previous)
			continue
		if(wanted_planet && candidate.planet != wanted_planet)
			continue
		if(!istype(get_turf(candidate), /turf/open/overmap))
			continue
		candidates += candidate
	if(!length(candidates))
		return FALSE
	planet = pick(candidates)
	cache_coords_from(planet)
	RegisterSignal(planet, COMSIG_QDELETING, PROC_REF(on_planet_deleted))
	// Planets never delete on unload - they relocate. Track the move so the
	// waypoint and mission text follow the new position.
	RegisterSignal(planet, COMSIG_MOVABLE_MOVED, PROC_REF(on_planet_moved))
	return TRUE

/datum/mission_target/planet/is_valid()
	return !QDELETED(planet)

/datum/mission_target/planet/unhook()
	if(planet)
		UnregisterSignal(planet, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED, COMSIG_VOIDCREW_PLANET_LOADED))
		planet = null

/datum/mission_target/planet/get_zone_type()
	if(!planet)
		return null
	return SSovermap_zones?.get_zone_type(get_turf(planet))

/datum/mission_target/planet/is_interior_loaded()
	return planet?.loaded && planet.mapzone

/datum/mission_target/planet/notify_when_loaded()
	if(!planet)
		return
	RegisterSignal(planet, COMSIG_VOIDCREW_PLANET_LOADED, PROC_REF(on_planet_loaded))

/datum/mission_target/planet/proc/on_planet_loaded(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(planet, COMSIG_VOIDCREW_PLANET_LOADED)
	mission?.on_target_interior_loaded()

/**
 * A random clear surface turf, sampled from the planet's z-level with a
 * margin so objectives never land in the map border or the dock aprons.
 */
/datum/mission_target/planet/get_spawn_turf()
	if(!planet?.mapzone || !length(planet.mapzone.z_levels))
		return null
	var/datum/space_level/level = planet.mapzone.z_levels[1]
	if(!level)
		return null
	var/margin = 12
	for(var/_ in 1 to 40)
		var/turf/candidate = locate(
			rand(level.low_x + margin, level.high_x - margin),
			rand(level.low_y + margin, level.high_y - margin),
			level.z_value,
		)
		if(!candidate || !isopenturf(candidate) || isspaceturf(candidate))
			continue
		if(candidate.is_blocked_turf(exclude_mobs = TRUE))
			continue
		return candidate
	return null

/datum/mission_target/planet/contains_turf(turf/T)
	if(!planet?.mapzone || !T)
		return FALSE
	for(var/datum/space_level/level as anything in planet.mapzone.z_levels)
		if(level.z_value == T.z)
			return TRUE
	return FALSE

/datum/mission_target/planet/get_interior_bounds()
	if(!planet?.mapzone || !length(planet.mapzone.z_levels))
		return null
	var/datum/space_level/level = planet.mapzone.z_levels[1]
	if(!level)
		return null
	return list(level.low_x, level.low_y, level.high_x, level.high_y, level.z_value)

/datum/mission_target/planet/refresh_coords()
	if(planet)
		cache_coords_from(planet)

/datum/mission_target/planet/proc/on_planet_deleted(datum/source)
	SIGNAL_HANDLER
	unhook()
	mission?.on_target_lost()

/// The planet relocated after unloading: same target, new coordinates
/datum/mission_target/planet/proc/on_planet_moved(datum/source)
	SIGNAL_HANDLER
	if(!istype(get_turf(planet), /turf/open/overmap))
		return
	cache_coords_from(planet)
	mission?.on_target_moved()

// =========================================================================
// COORDINATES — bare overmap coordinates in a chosen zone band
// =========================================================================

/**
 * Picks a random overmap tile from a zone band, using the zone controller's
 * own turf sets rather than reimplementing the ring geometry (the old
 * exploration mission carried a private copy of the band math).
 */
/datum/mission_target/coords
	/// Weighted zone selection table the resolve rolls: "[ZONE_*]" -> weight
	var/list/zone_weights = list()
	/// The zone type that was picked
	var/zone_type = ZONE_GREEN

/datum/mission_target/coords/resolve()
	if(!SSovermap_zones)
		return FALSE
	zone_type = text2num(pick_weight(zone_weights)) || ZONE_GREEN
	var/datum/overmap_zone/zone = SSovermap_zones.get_zone_datum(zone_type)
	if(!zone || !length(zone.turfs))
		return FALSE
	for(var/_ in 1 to 30)
		var/turf/candidate = pick(zone.turfs)
		var/rel_x = candidate.x
		var/rel_y = candidate.y - OVERMAP_SOUTH_SIDE_COORD + 1
		if(rel_x < MISSION_OVERMAP_MIN_COORD || rel_x > MISSION_OVERMAP_MAX_COORD)
			continue
		if(rel_y < MISSION_OVERMAP_MIN_COORD || rel_y > MISSION_OVERMAP_MAX_COORD)
			continue
		if(GLOB.overmap_blocked_turfs[candidate])
			continue
		target_x = rel_x
		target_y = rel_y
		return TRUE
	return FALSE

/datum/mission_target/coords/get_zone_type()
	return zone_type

// =========================================================================
// TRADER OUTPOST — courier destinations
// =========================================================================

/datum/mission_target/outpost
	/// The destination outpost
	var/obj/structure/overmap/trader_outpost/outpost
	/// Outpost to exclude from the pick (the posting shop's own)
	var/obj/structure/overmap/trader_outpost/exclude

/datum/mission_target/outpost/resolve()
	unhook()
	var/list/candidates = list()
	for(var/obj/structure/overmap/trader_outpost/candidate as anything in GLOB.trader_outposts)
		if(QDELETED(candidate) || candidate == exclude)
			continue
		candidates += candidate
	outpost = null
	if(!length(candidates))
		return FALSE
	outpost = pick(candidates)
	cache_coords_from(outpost)
	RegisterSignal(outpost, COMSIG_QDELETING, PROC_REF(on_outpost_deleted))
	return TRUE

/datum/mission_target/outpost/is_valid()
	return !QDELETED(outpost)

/datum/mission_target/outpost/unhook()
	if(outpost)
		UnregisterSignal(outpost, COMSIG_QDELETING)
		outpost = null

/datum/mission_target/outpost/get_zone_type()
	if(!outpost)
		return null
	return SSovermap_zones?.get_zone_type(get_turf(outpost))

/datum/mission_target/outpost/proc/on_outpost_deleted(datum/source)
	SIGNAL_HANDLER
	unhook()
	mission?.on_target_lost()
