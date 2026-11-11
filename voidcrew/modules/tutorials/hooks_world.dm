// Tutorial checklist hooks. Part C: closet, loot panel and ruin area hooks.
// Overrides chain with any others of the same proc; each returns the parent's value unchanged.

/// Opening an abandoned cache off-ship. Purchased caches are delivered aboard, so they don't count.
/obj/structure/closet/crate/zone_loot/open(mob/living/user, force = FALSE, special_effects = TRUE)
	. = ..()
	if(.)
		tutorial_credit_ruin_cache(src, user)

/obj/structure/closet/crate/secure/loot/open(mob/living/user, force = FALSE, special_effects = TRUE)
	. = ..()
	if(.)
		tutorial_credit_ruin_cache(src, user)

/proc/tutorial_credit_ruin_cache(obj/structure/closet/cache, mob/living/user)
	if(!ismob(user) || !user.ckey)
		return
	if(SSvc_tutorials.progress[user.ckey]?[TUTORIAL_STEP_RUIN_CACHE])
		return
	if(!tutorial_countable_cache(cache))
		return
	// A cache that counts sits in a ruin, open-air ones included (they have no /area/ruin).
	tutorial_credit(user, TUTORIAL_STEP_RUIN_FIND)
	tutorial_credit(user, TUTORIAL_STEP_RUIN_CACHE)

/// TRUE for a cache found in the world: not a bought black-market one, and not aboard a ship.
/proc/tutorial_countable_cache(obj/structure/closet/cache)
	if(QDELETED(cache) || istype(cache, /obj/structure/closet/crate/zone_loot/syndicate/trader))
		return FALSE
	return !get_ship_from_atom(cache)

// ---------------------------------------------------------------------------
// Ruin pointers for the Planet ruin item (ruin-vestige). Read only from the step
// procs in tutorial_catalog.dm, which run on a highlight rebuild or the panel's
// 5 s refresh, never per tick.
// ---------------------------------------------------------------------------

/// Furthest ruin the Find a ruin pointers will name. A planet is 128 tiles across.
#define TUTORIAL_RUIN_RANGE 100
/// How far from the viewer a cache is still pointed at.
#define TUTORIAL_CACHE_RANGE 40

/// Every abandoned cache in the world, so the pointers never scan turfs.
GLOBAL_LIST_EMPTY(tutorial_ruin_caches)

/obj/structure/closet/crate/zone_loot/Initialize(mapload)
	. = ..()
	GLOB.tutorial_ruin_caches += src

/obj/structure/closet/crate/zone_loot/Destroy()
	GLOB.tutorial_ruin_caches -= src
	return ..()

/obj/structure/closet/crate/secure/loot/Initialize(mapload)
	. = ..()
	GLOB.tutorial_ruin_caches += src

/obj/structure/closet/crate/secure/loot/Destroy()
	GLOB.tutorial_ruin_caches -= src
	return ..()

/// The planet the viewer stands on or is berthed at, or null.
/proc/tutorial_planet_under(mob/user)
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(user)
	if(ship)
		var/obj/structure/overmap/berth = ship.docked
		if(istype(berth, /obj/structure/overmap/planet) && !istype(berth, /obj/structure/overmap/planet/empty))
			return berth
		return null
	var/turf/here = get_turf(user)
	if(!here)
		return null
	var/obj/structure/overmap/planet/planet = SSovermap_zones.get_overmap_object_for_turf(here)
	if(istype(planet) && !istype(planet, /obj/structure/overmap/planet/empty))
		return planet
	return null

/// TRUE if a landmark and a turf share a map tenant (a planet on a shared level).
/proc/tutorial_same_tenant(turf/here, turf/there)
	if(!here || !there || here.z != there.z)
		return FALSE
	var/datum/map_footprint/tenant = map_footprint_containing_turf(here)
	return !tenant || tenant.contains_turf(there)

/// The ruin landmark nearest the viewer on their planet, or null.
/proc/tutorial_nearest_ruin_landmark(mob/user)
	var/turf/here = get_turf(user)
	if(!here)
		return null
	var/datum/map_footprint/tenant = map_footprint_containing_turf(here)
	var/obj/effect/landmark/ruin/nearest
	var/nearest_dist
	for(var/obj/effect/landmark/ruin/mark as anything in GLOB.ruin_landmarks)
		if(QDELETED(mark) || mark.z != here.z || !mark.ruin_template)
			continue
		var/turf/spot = get_turf(mark)
		if(!spot || (tenant && !tenant.contains_turf(spot)))
			continue
		var/dist = get_dist(here, spot)
		if(dist > TUTORIAL_RUIN_RANGE)
			continue
		if(!nearest || dist < nearest_dist)
			nearest = mark
			nearest_dist = dist
	return nearest

/// TRUE if a turf lies inside the area a ruin template was loaded over (centred on its landmark).
/proc/tutorial_in_ruin_footprint(turf/spot, obj/effect/landmark/ruin/mark)
	var/datum/map_template/ruin/template = mark?.ruin_template
	var/turf/center = get_turf(mark)
	if(!spot || !template || !center || spot.z != center.z)
		return FALSE
	return abs(spot.x - center.x) <= CEILING(template.width / 2, 1) && abs(spot.y - center.y) <= CEILING(template.height / 2, 1)

/**
 * TRUE if the viewer stands inside a ruin's footprint on their planet. With credit, also
 * credits Find a ruin (on the next tick: this runs inside a highlight rebuild, and a
 * credit starts another one).
 */
/proc/tutorial_ruin_footprint_check(mob/user, credit = FALSE)
	var/turf/here = get_turf(user)
	if(!here || get_ship_from_atom(user))
		return FALSE
	var/inside = FALSE
	for(var/obj/effect/landmark/ruin/mark as anything in GLOB.ruin_landmarks)
		if(QDELETED(mark) || mark.z != here.z)
			continue
		if(tutorial_in_ruin_footprint(here, mark))
			inside = TRUE
			break
	if(inside && credit && user.ckey)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(tutorial_credit_ruin_footprint), WEAKREF(user)), 0)
	return inside

/proc/tutorial_credit_ruin_footprint(datum/weakref/user_ref)
	var/mob/user = user_ref?.resolve()
	if(user && tutorial_ruin_footprint_check(user))
		tutorial_credit(user, TUTORIAL_STEP_RUIN_FIND)

/// Closed, countable caches near the viewer on their planet.
/proc/tutorial_nearby_ruin_caches(mob/user)
	. = list()
	var/turf/here = get_turf(user)
	if(!here)
		return
	for(var/obj/structure/closet/cache as anything in GLOB.tutorial_ruin_caches)
		if(cache.opened || cache.z != here.z || get_dist(here, cache) > TUTORIAL_CACHE_RANGE)
			continue
		if(!tutorial_same_tenant(here, get_turf(cache)) || !tutorial_countable_cache(cache))
			continue
		. += cache

#undef TUTORIAL_RUIN_RANGE
#undef TUTORIAL_CACHE_RANGE

/// Walking into a ruin. No ship maps /area/ruin.
/area/ruin/Entered(atom/movable/arrived, area/old_area)
	. = ..()
	if(!ismob(arrived))
		return
	var/mob/visitor = arrived
	if(!visitor.ckey || SSvc_tutorials.progress[visitor.ckey]?[TUTORIAL_STEP_RUIN_FIND])
		return
	tutorial_credit(visitor, TUTORIAL_STEP_RUIN_FIND)
