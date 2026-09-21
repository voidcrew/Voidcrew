// Voidcrew extensions to code/game/movable_luminosity.dm.

/**
 * Makes every overlay light we're carrying work out where it is again.
 *
 * Overlay lights only re-resolve their holder when they personally move, so gear that
 * was in someone's hands or pockets while they sat inside a machine never learns that
 * they climbed out of it, and stays dark until it is dropped and picked back up.
 * Call this after moving a mob out of something it was inside of.
 */
/atom/movable/proc/recheck_contained_lights()
	for(var/atom/movable/carried as anything in get_all_contents())
		var/datum/component/overlay_lighting/light = carried.GetComponent(/datum/component/overlay_lighting)
		light?.recheck_holder()
