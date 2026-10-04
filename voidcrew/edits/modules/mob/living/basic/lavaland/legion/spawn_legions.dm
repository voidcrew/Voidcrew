// Voidcrew extensions to code/modules/mob/living/basic/lavaland/legion/spawn_legions.dm.

/**
 * Walks the line from the owner to `destination` and returns the last turf the skull can
 * actually reach, or null if it cannot leave the owner's tile at all.
 *
 * Targeting is done with can_see(), which passes through anything non-opaque. A window is
 * transparent and solid at the same time, so without this the launcher happily deposits
 * brood on the other side of a hull - the "skulls spawned inside my ship" case. Dense mobs
 * are not obstacles; a thrown skull goes over them.
 */
/datum/action/cooldown/mob_cooldown/skull_launcher/proc/clamp_to_reachable_turf(turf/destination)
	var/turf/origin = get_turf(owner)
	if (isnull(destination) || destination == origin)
		return destination

	var/turf/furthest = null
	// get_line()'s first entry is the origin itself, which is not a candidate landing spot.
	var/list/path = get_line(origin, destination)
	for (var/i in 2 to length(path))
		var/turf/step = path[i]
		if (step.is_blocked_turf(exclude_mobs = TRUE, source_atom = owner))
			break
		furthest = step

	return furthest
