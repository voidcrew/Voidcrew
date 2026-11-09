/**
 * # Stealth perception
 *
 * Sight for guards that opted into stealth (stealth_ai.dm). It is AI math only: no fov_view on the body
 * (a player who later takes it over must not inherit it), and the cone and darkness are never added to
 * can_attack(), so an alert guard keeps tg's all-round check and an attack from behind still lands on a
 * guard that can turn round (abuse review P1, P2).
 *
 * A scan, once a second while the AI is awake: the nearest few living mobs on the HEARING grid (every mob
 * is hearing-sensitive, so SSD bodies and other NPCs count), each passed through the guard's own
 * can_attack() first (faction, stat, line of sight, invisibility, the packed-level cordon, Ghostskin
 * camo), then the cone, light and movement rules below raise or decay its "notice".
 */

#ifdef UNIT_TESTS
/// Turfs the unit tests treat as dark, since the test level is fully lit
GLOBAL_LIST_EMPTY(stealth_test_dark_turfs)
#endif

/// Whether `target` is within `half_angle` degrees of `viewer`'s facing. Integer math, no trig per call.
/// The same tile is in the cone; a target exactly side-on is not, even at 90 degrees.
/proc/stealth_in_cone(atom/viewer, atom/target, half_angle)
	var/turf/from = get_turf(viewer)
	var/turf/target_turf = get_turf(target)
	if(isnull(from) || isnull(target_turf))
		return FALSE
	var/dx = target_turf.x - from.x
	var/dy = target_turf.y - from.y
	if(!dx && !dy)
		return TRUE
	var/facing = viewer.dir
	var/sx = (facing & EAST) ? 1 : ((facing & WEST) ? -1 : 0)
	var/sy = (facing & NORTH) ? 1 : ((facing & SOUTH) ? -1 : 0)
	var/facing_len2 = sx * sx + sy * sy
	if(!facing_len2)
		return FALSE
	var/forward = dx * sx + dy * sy
	if(forward <= 0)
		return FALSE
	return forward * forward >= (dx * dx + dy * dy) * facing_len2 * stealth_cos2(half_angle)

/// cos^2 of `angle` degrees, from a table for the angles the stealth layer uses.
/proc/stealth_cos2(angle)
	switch(angle)
		if(60)
			return 0.25
		if(75)
			return 0.0669873
		if(90)
			return 0
	var/c = cos(angle)
	return c * c

/**
 * Whether `tile` is dark enough to hide in. A turf with no lighting object (planet ground lit only by its
 * area's ambient light) reads its area's base light, which get_lumcount() skips (it returns 1 there).
 * Same rule as the bounty AI's ai_tile_is_dark() (bounty_ai_meek.dm), which is a type proc.
 */
/proc/stealth_tile_is_dark(turf/tile)
	if(!isturf(tile))
		return FALSE
#ifdef UNIT_TESTS
	if(tile in GLOB.stealth_test_dark_turfs)
		return TRUE
#endif
	if(!tile.lighting_object)
		var/area/tile_area = tile.loc
		return (tile_area.base_lighting_alpha / 255) + tile.dynamic_lumcount < STEALTH_DARK_LUMCOUNT
	return tile.get_lumcount() < STEALTH_DARK_LUMCOUNT

/// The vehicle `who` sits in (a mech or another vehicle), or null.
/proc/stealth_vehicle_of(mob/living/who)
	var/atom/holder = who.loc
	if(ismecha(holder) || isvehicle(holder))
		return holder
	return null

/**
 * Whether a cloak hides `who` from a guard's sight beyond the close radius (owner decision 20: cyberware
 * cloaks and boon abilities). Ghostskin camo is already refused by can_attack() past its spot range
 * (cyberware_stealth.dm); this adds the heretic shadow cloak a Vestige boon grants.
 */
/proc/stealth_is_cloaked(mob/living/who)
	if(HAS_TRAIT(who, TRAIT_CYBER_CAMO))
		return TRUE
	return !!who.has_status_effect(/datum/status_effect/shadow_cloak)

/**
 * The living mobs a guard might see, nearest first, at most STEALTH_MAX_CANDIDATES. Uses the spatial
 * grid, never view() or hearers().
 */
/proc/stealth_candidates(mob/living/guard, range)
	var/turf/center = get_turf(guard)
	if(isnull(center))
		return list()
	var/list/buckets = new /list(range + 1)
	for(var/mob/living/found in SSspatial_grid.orthogonal_range_search(center, SPATIAL_GRID_CONTENTS_TYPE_HEARING, range))
		if(found == guard)
			continue
		var/turf/found_turf = get_turf(found)
		if(isnull(found_turf) || found_turf.z != center.z)
			continue
		var/dist = get_dist(center, found_turf)
		if(dist > range)
			continue
		var/list/bucket = buckets[dist + 1]
		if(isnull(bucket))
			buckets[dist + 1] = bucket = list()
		bucket += found
	. = list()
	for(var/list/bucket in buckets)
		for(var/mob/living/found as anything in bucket)
			. += found
			if(length(.) >= STEALTH_MAX_CANDIDATES)
				return .
