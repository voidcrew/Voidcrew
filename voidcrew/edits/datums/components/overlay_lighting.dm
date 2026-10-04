// Voidcrew extensions to code/datums/components/overlay_lighting.dm.

/**
 * Re-runs the holder check from outside the component.
 *
 * We only re-check the holder when our own parent moves, so a light sitting in someone's
 * pocket keeps whatever holder it resolved to when it was last moved. If that mob then
 * leaves a container the light was never told about it, and stays dark. Anything that
 * dumps a mob out of itself should poke this - see [/atom/movable/proc/recheck_contained_lights].
 */
/datum/component/overlay_lighting/proc/recheck_holder()
	check_holder()
