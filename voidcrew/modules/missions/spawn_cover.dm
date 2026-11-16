/**
 * # Mission Spawn Cover
 *
 * Field objectives are placed on whatever turf the site sampler rolls, and the
 * site can already be loaded with a crew standing in it: accept a contract while
 * landed and the survivor, the bounty, the anomaly or the crash site would wink
 * into existence in front of them. The pickers here sample the same candidates,
 * skip any turf a living player could see right now, and when nowhere is hidden
 * fall back to the candidate farthest from everyone watching.
 *
 * "Could see" is the watcher's screen rectangle (their own view size, so a scope
 * or zoom counts), widened by a few tiles so whatever scatters around the anchor
 * (guards, dressing, the rest of a pylon set) doesn't land on the edge of the
 * screen, then a straight line of sight that walls and other opaque turfs block.
 * Darkness is ignored: a dark tile in view still counts as seen.
 */

/// Tiles past the edge of a watcher's screen still treated as in view
#define MISSION_SPAWN_COVER_MARGIN 3
/// Random samples a hidden pick takes from a candidate list before falling back
#define MISSION_SPAWN_COVER_TRIES 40

/**
 * Everyone who could be looking at one z-level, taken once per pick so each
 * candidate check is a few subtractions and, only for turfs on somebody's screen,
 * one line-of-sight walk.
 */
/datum/spawn_cover
	/// One entry per watcher: list(eye turf, half view width, half view height), margin included
	var/list/watchers = list()
	/// The seen candidate farthest from its nearest watcher, for when nothing is hidden
	var/turf/fallback
	/// Chebyshev distance from the fallback to its nearest watcher
	var/fallback_distance = -1

/datum/spawn_cover/New(z)
	. = ..()
	if(!z)
		return
	for(var/mob/living/player as anything in GLOB.alive_player_list)
		var/client/viewer = player.client
		if(!viewer)
			continue
		// The client's eye, not the body: an AI looks through its camera eye
		var/turf/eye_turf = get_turf(viewer.eye || player)
		if(!eye_turf || eye_turf.z != z)
			continue
		var/list/view_size = getviewsize(viewer.view)
		add_watcher(eye_turf, CEILING((view_size[1] - 1) / 2, 1), CEILING((view_size[2] - 1) / 2, 1))

/// Registers one pair of eyes. Half sizes are the screen's, before the margin.
/datum/spawn_cover/proc/add_watcher(turf/eye_turf, half_width, half_height)
	watchers += list(list(eye_turf, half_width + MISSION_SPAWN_COVER_MARGIN, half_height + MISSION_SPAWN_COVER_MARGIN))

/datum/spawn_cover/proc/has_watchers()
	return length(watchers) > 0

/**
 * TRUE when no watcher could see the candidate. A seen candidate is remembered
 * as the fallback if it sits farther from its nearest watcher than the last one.
 */
/datum/spawn_cover/proc/is_hidden(turf/candidate)
	if(!length(watchers))
		return TRUE
	var/nearest = INFINITY
	var/seen = FALSE
	for(var/list/watcher as anything in watchers)
		var/turf/eye_turf = watcher[1]
		var/dx = abs(candidate.x - eye_turf.x)
		var/dy = abs(candidate.y - eye_turf.y)
		nearest = min(nearest, max(dx, dy))
		if(seen || dx > watcher[2] || dy > watcher[3])
			continue
		if(inLineOfSight(eye_turf.x, eye_turf.y, candidate.x, candidate.y, candidate.z))
			seen = TRUE
	if(!seen)
		return TRUE
	if(nearest > fallback_distance)
		fallback = candidate
		fallback_distance = nearest
	return FALSE

/**
 * A random turf from candidates that nobody can see, or the sampled candidate
 * farthest from any watcher. Candidates must already be valid spawn turfs on one
 * z-level; this only decides between them. With nobody on the level it is a
 * plain pick().
 */
/proc/pick_unwatched_turf(list/candidates, tries = MISSION_SPAWN_COVER_TRIES)
	if(!length(candidates))
		return null
	var/turf/first = candidates[1]
	var/datum/spawn_cover/cover = new(first.z)
	if(!cover.has_watchers())
		return pick(candidates)
	for(var/_ in 1 to tries)
		var/turf/candidate = pick(candidates)
		if(cover.is_hidden(candidate))
			return candidate
	return cover.fallback

#undef MISSION_SPAWN_COVER_MARGIN
#undef MISSION_SPAWN_COVER_TRIES
