/**
 * Exterior debris for ship-scoped dynamic events, meteors, space dust, immovable
 * rods: everything TG throws *across* a station z-level rather than spawning inside it.
 *
 * These are the events the dynamic-event port deferred, because they are the only
 * ones that live outside the hull and therefore can't be scoped by area membership
 * like every other port is. A flying ship is parked at a transit docking port inside
 * its own /datum/turf_reservation, and that reservation shares a z-level with every
 * other flying ship in the sector; a docked ship shares its reservation with whatever
 * it landed at, and ruins hand out two berths. So "spawn at the map edge and fly at
 * the station", TG's whole model, lands rocks on somebody else's bridge.
 *
 * The fix is a per-launch corridor: a rectangle covering only the target ship's own
 * footprint plus a margin, clamped inside its reservation. Debris spawns on the edge
 * of that rectangle, crosses the hull, and is culled the instant it leaves, so a rock
 * that misses is gone rather than continuing for its full three-minute lifetime into a
 * neighbour. Nothing here reads a z-level trait or a station global; the corridor is
 * derived from the shuttle's own projected bounds.
 */

/// How far outside the hull debris spawns, and how far past it debris may travel
/// before it is culled. Transit reservations pad a shuttle by SHUTTLE_TRANSIT_BORDER
/// (16) on every side, so this leaves a comfortable buffer at both ends.
#define SHIP_DEBRIS_MARGIN 8

/// Keep the corridor this far inside the reservation edge. A transit reservation rings
/// itself with a soft cordon that space-dumps whatever crosses it (pre_cordon_distance
/// puts that ring 6 turfs in, see /datum/turf_reservation/transit), and the hard
/// /turf/cordon sits one turf further out again. Staying inside both means launched
/// debris never trips either handler while it is doing its job.
#define SHIP_DEBRIS_RESERVATION_INSET 9

/**
 * Rectangle that exterior debris launched at this ship is allowed to exist in:
 * the shuttle's own projected footprint grown by `margin`, then clamped so it can
 * never reach a neighbouring reservation.
 *
 * Returns an assoc list of "min_x", "min_y", "max_x", "max_y", "z", or null if the
 * ship has no locatable interior (destroyed, mid-dock, not loaded).
 */
/obj/structure/overmap/ship/proc/get_debris_bounds(margin = SHIP_DEBRIS_MARGIN)
	if(!shuttle)
		return null
	var/turf/anchor = get_turf(shuttle)
	if(!anchor)
		return null
	var/list/coords = shuttle.return_coords()
	if(length(coords) < 4)
		return null

	var/min_x = min(coords[1], coords[3]) - margin
	var/max_x = max(coords[1], coords[3]) + margin
	var/min_y = min(coords[2], coords[4]) - margin
	var/max_y = max(coords[2], coords[4]) + margin

	var/floor_x = 1
	var/floor_y = 1
	var/ceil_x = world.maxx
	var/ceil_y = world.maxy

	// Clamp to the reservation the ship is sitting in. Multi-z reservations lay their
	// levels out as separate blocks on one z-level, so ask the reservation which block
	// this ship is actually in rather than assuming index 1.
	var/datum/turf_reservation/reservation = SSmapping.get_reservation_from_turf(anchor)
	if(reservation)
		var/list/bounds_info = reservation.calculate_turf_bounds_information(anchor)
		var/z_index = bounds_info?["z_idx"]
		if(z_index)
			var/turf/bottom_left = reservation.bottom_left_turfs[z_index]
			var/turf/top_right = reservation.top_right_turfs[z_index]
			floor_x = bottom_left.x + SHIP_DEBRIS_RESERVATION_INSET
			floor_y = bottom_left.y + SHIP_DEBRIS_RESERVATION_INSET
			ceil_x = top_right.x - SHIP_DEBRIS_RESERVATION_INSET
			ceil_y = top_right.y - SHIP_DEBRIS_RESERVATION_INSET

	min_x = max(min_x, floor_x)
	min_y = max(min_y, floor_y)
	max_x = min(max_x, ceil_x)
	max_y = min(max_y, ceil_y)

	// A hull wider than the space it is parked in leaves nothing to fly through.
	if(min_x >= max_x || min_y >= max_y)
		return null

	return list("min_x" = min_x, "min_y" = min_y, "max_x" = max_x, "max_y" = max_y, "z" = anchor.z)

/**
 * Up to `count` distinct random turfs aboard, sampled in one pass over the ship's areas.
 *
 * get_random_ship_turf() rebuilds the ship's entire turf list on every call, which is
 * fine once but wasteful when a meteor wave wants several aim points at a time, and
 * this way a wave can't throw two rocks at the same tile.
 */
/obj/structure/overmap/ship/proc/get_random_ship_turfs(count = 1)
	var/list/picked = list()
	if(count < 1 || !shuttle?.shuttle_areas?.len)
		return picked

	var/list/all_turfs = list()
	for(var/area/ship_area as anything in shuttle.shuttle_areas)
		for(var/turf/ship_turf in ship_area)
			all_turfs += ship_turf

	for(var/i in 1 to min(count, length(all_turfs)))
		picked += pick_n_take(all_turfs)
	return picked

/// Random point on the edge of a debris corridor, for debris to enter from.
/obj/structure/overmap/ship/proc/get_debris_entry_turf(list/bounds)
	var/min_x = bounds["min_x"]
	var/min_y = bounds["min_y"]
	var/max_x = bounds["max_x"]
	var/max_y = bounds["max_y"]
	var/corridor_z = bounds["z"]
	switch(pick(GLOB.cardinals))
		if(NORTH)
			return locate(rand(min_x, max_x), max_y, corridor_z)
		if(SOUTH)
			return locate(rand(min_x, max_x), min_y, corridor_z)
		if(EAST)
			return locate(max_x, rand(min_y, max_y), corridor_z)
		else
			return locate(min_x, rand(min_y, max_y), corridor_z)

/**
 * Furthest turf still inside `bounds` along the ray from `entry` through `aim`.
 *
 * Debris that culls itself on arrival (the immovable rod deletes itself the moment it
 * reaches its destination turf) needs an end point on the far wall of the corridor
 * rather than a point inside the hull, or it stops halfway through the ship.
 */
/obj/structure/overmap/ship/proc/get_debris_exit_turf(list/bounds, turf/entry, turf/aim)
	if(!entry || !aim)
		return null
	var/delta_x = aim.x - entry.x
	var/delta_y = aim.y - entry.y
	if(!delta_x && !delta_y)
		return aim

	// Largest multiple of the entry->aim vector that still lands inside the rectangle.
	var/steps = INFINITY
	if(delta_x > 0)
		steps = min(steps, (bounds["max_x"] - entry.x) / delta_x)
	else if(delta_x < 0)
		steps = min(steps, (bounds["min_x"] - entry.x) / delta_x)
	if(delta_y > 0)
		steps = min(steps, (bounds["max_y"] - entry.y) / delta_y)
	else if(delta_y < 0)
		steps = min(steps, (bounds["min_y"] - entry.y) / delta_y)
	if(steps == INFINITY)
		return aim

	var/exit_x = clamp(round(entry.x + (delta_x * steps)), bounds["min_x"], bounds["max_x"])
	var/exit_y = clamp(round(entry.y + (delta_y * steps)), bounds["min_y"], bounds["max_y"])
	return locate(exit_x, exit_y, entry.z)

/**
 * Throws one piece of exterior debris across this ship.
 *
 * The debris type is constructed as `new type(entry_turf, destination_turf)`, which is
 * the signature both /obj/effect/meteor and /obj/effect/immovablerod already use.
 *
 * Arguments:
 * * debris_type - typepath to launch.
 * * aim_turf - what to aim at. Defaults to a random turf aboard.
 * * margin - how far outside the hull to launch from.
 * * aim_past_hull - aim at the far wall of the corridor instead of at `aim_turf`, for
 *   debris that stops when it arrives.
 *
 * Returns the launched debris, or null if the ship has no usable corridor right now.
 */
/obj/structure/overmap/ship/proc/launch_ship_debris(debris_type, turf/aim_turf, margin = SHIP_DEBRIS_MARGIN, aim_past_hull = FALSE)
	if(!ispath(debris_type, /atom/movable))
		return null
	var/list/bounds = get_debris_bounds(margin)
	if(!bounds)
		return null

	if(!aim_turf)
		aim_turf = get_random_ship_turf()
	// A turf on another z is a ship caught mid-dock; there is nothing to aim at yet.
	if(!aim_turf || aim_turf.z != bounds["z"])
		return null

	var/turf/entry_turf = get_debris_entry_turf(bounds)
	if(!entry_turf)
		return null
	var/turf/destination = aim_past_hull ? get_debris_exit_turf(bounds, entry_turf, aim_turf) : aim_turf
	if(!destination)
		return null

	var/atom/movable/debris = new debris_type(entry_turf, destination)
	if(QDELETED(debris))
		return null
	confine_ship_debris(debris, bounds)
	return debris

/**
 * Makes a piece of debris survive transit space long enough to reach the ship, and
 * deletes it the moment it leaves its corridor.
 *
 * The three exemption traits are what let it exist in reserved space at all: without
 * them the transit reservation's soft cordon dumps it, hyperspace drift shoves it, and
 * the shuttle-cling component grabs it. TRAIT_DEL_ON_SPACE_DUMP is the counterweight,
 * if debris somehow does reach the reservation's hard cordon, it dies there instead of
 * being teleported onto a live z-level by dump_in_space().
 */
/proc/confine_ship_debris(atom/movable/debris, list/bounds)
	if(QDELETED(debris) || !islist(bounds))
		return
	ADD_TRAIT(debris, TRAIT_FREE_HYPERSPACE_MOVEMENT, INNATE_TRAIT)
	ADD_TRAIT(debris, TRAIT_FREE_HYPERSPACE_SOFTCORDON_MOVEMENT, INNATE_TRAIT)
	ADD_TRAIT(debris, TRAIT_HYPERSPACED, INNATE_TRAIT)
	ADD_TRAIT(debris, TRAIT_DEL_ON_SPACE_DUMP, INNATE_TRAIT)

	// A "heavy" meteor shakes the camera of every player sharing its z-level on death.
	// On a transit z that is every other crew in the sector feeling a rock they can't
	// see hit a ship they aren't on, so confined rocks give that up, the launching
	// event rumbles its own ship instead (see /datum/round_event/voidcrew/meteor_strike).
	var/obj/effect/meteor/rock = debris
	if(istype(rock))
		rock.heavy = FALSE

	debris.AddComponent(/datum/component/ship_debris_confinement, bounds)

/**
 * Culls its parent the moment it leaves the corridor it was launched into.
 *
 * TG debris has no concept of arriving: a meteor's move loop keeps flying on its
 * original slope for its full lifetime whether or not it hit anything, and a rod only
 * stops if it happens to land exactly on its destination turf. On a station z-level
 * that is harmless because the map edge is the end of the world. Here it isn't.
 */
/datum/component/ship_debris_confinement
	/// Corridor edges, inclusive.
	var/min_x = 0
	var/min_y = 0
	var/max_x = 0
	var/max_y = 0
	/// The z-level the corridor lives on. Anything that changes z has left.
	var/corridor_z = 0

/datum/component/ship_debris_confinement/Initialize(list/bounds)
	if(!ismovable(parent) || !islist(bounds))
		return COMPONENT_INCOMPATIBLE
	min_x = bounds["min_x"]
	min_y = bounds["min_y"]
	max_x = bounds["max_x"]
	max_y = bounds["max_y"]
	corridor_z = bounds["z"]

/datum/component/ship_debris_confinement/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_parent_moved))

/datum/component/ship_debris_confinement/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_MOVABLE_MOVED)

/// TRUE if the given turf is inside this corridor.
/datum/component/ship_debris_confinement/proc/contains(turf/location)
	if(!location || location.z != corridor_z)
		return FALSE
	return location.x >= min_x && location.x <= max_x && location.y >= min_y && location.y <= max_y

/datum/component/ship_debris_confinement/proc/on_parent_moved(atom/movable/source)
	SIGNAL_HANDLER
	if(contains(get_turf(source)))
		return
	qdel(source)

#undef SHIP_DEBRIS_MARGIN
#undef SHIP_DEBRIS_RESERVATION_INSET
