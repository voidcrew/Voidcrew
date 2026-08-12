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
	/// Zone band (ZONE_*) this target prefers to sit in, copied off the mission.
	/// Null = no preference, which is what every target that isn't generated for
	/// a specific ship's board gets.
	var/preferred_zone

/datum/mission_target/New(datum/mission/mission)
	..()
	src.mission = mission
	preferred_zone = mission?.preferred_zone

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

/**
 * Narrows a resolved candidate list down to the objects sitting in
 * preferred_zone, if a preference was asked for and anything matches.
 *
 * This is a preference and never a filter that can fail: with no preference set,
 * no live zone controller, or nothing in the wanted band, the full list comes
 * back untouched. A board offer would rather point somewhere dangerous than not
 * exist, and the shallow-band bias is there to shape what a new crew usually
 * sees, not to guarantee it.
 */
/datum/mission_target/proc/filter_by_preferred_zone(list/candidates)
	if(isnull(preferred_zone) || !length(candidates) || !SSovermap_zones?.zones_active)
		return candidates
	var/list/matching = list()
	for(var/atom/movable/candidate as anything in candidates)
		if(SSovermap_zones.get_zone_type(get_turf(candidate)) == preferred_zone)
			matching += candidate
	return length(matching) ? matching : candidates

/// Helper: relative overmap coords of an overmap object
/datum/mission_target/proc/cache_coords_from(atom/movable/object)
	if(!object)
		return
	target_x = object.x
	target_y = object.y - OVERMAP_SOUTH_SIDE_COORD + 1

// =========================================================================
// SPACE RUIN: the classic recovery-family target
// =========================================================================

/datum/mission_target/space_ruin
	/// The ruin signal this mission targets
	var/obj/structure/overmap/space_ruin/ruin

/datum/mission_target/space_ruin/resolve()
	var/obj/structure/overmap/space_ruin/previous = ruin
	unhook()
	// Three tiers, worst case last. The two preferences are NOT equally weighted,
	// which an earlier version of this got wrong by folding them into one set:
	// double-booking a ruin is cosmetic, but pointing a contract at a site that
	// is currently occupied is self-destructing, and the boards hold enough
	// offers to keep most of the sector claimed at any moment - so a combined
	// set empties out constantly and drops straight through to "anything".
	var/list/candidates = list() // legal at all
	var/list/cold = list() // ...and nobody is standing in it
	var/list/cold_unclaimed = list() // ...and no other contract wants it
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
		// A ruin is only ever loaded because somebody is there or has just left.
		// Picking one spawns the objective into the deck the accepting crew is
		// already standing on, and then their undock runs the recycle that tears
		// that site down behind them - the job is to fly nowhere, and leaving
		// voids it.
		if(candidate.loaded)
			continue
		cold += candidate
		if(candidate.mission_claims <= 0)
			cold_unclaimed += candidate
	if(!length(candidates))
		return FALSE
	var/list/pool = candidates
	if(length(cold_unclaimed))
		pool = cold_unclaimed
	else if(length(cold))
		pool = cold
	// Applied last, to the pool the occupancy tiers already settled on: a cold
	// unclaimed ruin in the wrong band still beats a hot one in the right band.
	pool = filter_by_preferred_zone(pool)
	ruin = pick(pool)
	ruin.mission_claims++
	cache_coords_from(ruin)
	RegisterSignal(ruin, COMSIG_QDELETING, PROC_REF(on_ruin_deleted))
	RegisterSignal(ruin, COMSIG_VOIDCREW_RUIN_UNLOADING, PROC_REF(on_ruin_unloading))
	return TRUE

/datum/mission_target/space_ruin/is_valid()
	return !QDELETED(ruin)

/datum/mission_target/space_ruin/unhook()
	if(ruin)
		ruin.mission_claims = max(ruin.mission_claims - 1, 0)
		UnregisterSignal(ruin, list(COMSIG_QDELETING, COMSIG_VOIDCREW_PLANET_LOADED, COMSIG_VOIDCREW_RUIN_UNLOADING))
		ruin = null

/datum/mission_target/space_ruin/get_zone_type()
	if(!ruin)
		return null
	return SSovermap_zones?.get_zone_type(get_turf(ruin))

/datum/mission_target/space_ruin/is_interior_loaded()
	return ruin?.loaded

/// override: see the planet target's copy - a re-arming field objective can hook
/// this a second time
/datum/mission_target/space_ruin/notify_when_loaded()
	if(!ruin)
		return
	RegisterSignal(ruin, COMSIG_VOIDCREW_PLANET_LOADED, PROC_REF(on_ruin_loaded), override = TRUE)

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

/**
 * The ruin emptied out and gave its interior back, but the signal is still on
 * the chart at the same coordinates. Distinct from on_ruin_deleted(): the
 * target is intact, so the mission rewinds instead of re-rolling.
 */
/datum/mission_target/space_ruin/proc/on_ruin_unloading(datum/source)
	SIGNAL_HANDLER
	mission?.on_target_interior_unloaded()

/// The ruin was abandoned and is respawning elsewhere
/datum/mission_target/space_ruin/proc/on_ruin_deleted(datum/source)
	SIGNAL_HANDLER
	unhook()
	mission?.on_target_lost()

// =========================================================================
// PLANET: the same interface pointed at a planet surface
// =========================================================================

/datum/mission_target/planet
	/// The planet this mission targets
	var/obj/structure/overmap/planet/planet
	/// Optional /datum/overmap/planet typepath filter: when set, resolve() only
	/// accepts planets of exactly that type ("the lava planet"). Null = any
	/// planet, the original behavior. NOTE: a filtered RE-resolve (retarget)
	/// excludes the previous planet, so it only finds anything while the round
	/// runs more than one planet of that type (SSovermap.dynamic_planets_per_type).
	/// Filtered missions should still use the FAIL loss policy.
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
	planet = pick(filter_by_preferred_zone(candidates))
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

/// override: a field objective that couldn't place its spawn re-hooks this, and
/// the hook may or may not still be live from the first arm()
/datum/mission_target/planet/notify_when_loaded()
	if(!planet)
		return
	RegisterSignal(planet, COMSIG_VOIDCREW_PLANET_LOADED, PROC_REF(on_planet_loaded), override = TRUE)

/datum/mission_target/planet/proc/on_planet_loaded(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(planet, COMSIG_VOIDCREW_PLANET_LOADED)
	mission?.on_target_interior_loaded()

/**
 * A random clear surface turf, sampled from the planet's z-level with a
 * margin so objectives never land in the map border or the dock aprons.
 *
 * The southern floor is the important one. Both reserve docks sit along the
 * bottom of the footprint, and a shuttle landing GIBS every living thing
 * standing on the turfs it lands on (/turf/proc/toShuttleMove) and deletes
 * anything anchored. Field objectives spawn BEFORE the crew touches down,
 * either at approach on an already-loaded planet, or from the interior-loaded
 * signal that load_level() fires before the dock move, so a specimen placed
 * in that strip is destroyed by the very ship that came to collect it. Ruins
 * are already kept out of it (reserve_dock_strip() -> NO_RUINS); objective
 * spawns need the same clearance.
 *
 * Shuttle areas are rejected for the mirror-image reason. A landed ship copies
 * its turfs over the surface, and those tiles are open, undense and perfectly
 * samplable, so with somebody else already parked on the planet the specimen
 * can materialise inside their hull, and their takeoff carries it off the world
 * (/mob/onShuttleMove). Nothing dies and nothing fails: the beacon simply stops
 * being on the crew's z-level, and the surface has nothing on it. SSplanet_mobs
 * skips these turfs for its own spawns already.
 */
/datum/mission_target/planet/get_spawn_turf()
	if(!planet?.mapzone || !length(planet.mapzone.z_levels))
		return null
	var/datum/space_level/level = planet.mapzone.z_levels[1]
	if(!level)
		return null
	var/margin = 12
	var/min_x = level.low_x + margin
	var/max_x = level.high_x - margin
	var/min_y = level.low_y + margin
	var/max_y = level.high_y - margin
	// Clear the berths, but never at the cost of leaving nothing to sample
	var/above_docks = planet.get_dock_strip_top_y(level) + 1
	if(above_docks < max_y)
		min_y = max(min_y, above_docks)
	if(min_x > max_x || min_y > max_y)
		return null
	for(var/_ in 1 to 40)
		var/turf/candidate = locate(rand(min_x, max_x), rand(min_y, max_y), level.z_value)
		if(!candidate || !isopenturf(candidate) || isspaceturf(candidate))
			continue
		if(istype(get_area(candidate), /area/shuttle))
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
// COORDINATES: bare overmap coordinates in a chosen zone band
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
	zone_type = pick_zone_band()
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

/**
 * The band this contract points at. A coordinate target has no object to filter,
 * so the preference is applied to the roll instead: take the preferred band
 * outright when the type's own table lists it, otherwise roll the table as
 * normal. Types that deliberately never offer a band (a deep-space survey with
 * no Neutral entry) keep that shape - the preference can only pick from what the
 * type already advertises.
 */
/datum/mission_target/coords/proc/pick_zone_band()
	if(!isnull(preferred_zone) && zone_weights["[preferred_zone]"] > 0)
		return preferred_zone
	return text2num(pick_weight(zone_weights)) || ZONE_GREEN

/datum/mission_target/coords/get_zone_type()
	return zone_type

// =========================================================================
// TRADER OUTPOST: courier destinations
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
	outpost = pick(filter_by_preferred_zone(candidates))
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
