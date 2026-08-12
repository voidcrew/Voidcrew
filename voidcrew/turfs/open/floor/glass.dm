/**
 * Indestructible reinforced glass floor. Unlike /turf/open/floor/glass this
 * has no pryable floor_tile and shrugs off damage like the rest of
 * /turf/open/indestructible, for venues whose structure must be untouchable
 * (the Grand Colosseum observation deck) while still showing the level below.
 */
/turf/open/indestructible/glass
	name = "reinforced glass floor"
	desc = "A transparent deck panel rated for crowds. It looks near-impervious to damage."
	icon = 'icons/turf/floors/reinf_glass.dmi'
	icon_state = "reinf_glass-0"
	base_icon_state = "reinf_glass"
	layer = GLASS_FLOOR_LAYER
	underfloor_accessibility = UNDERFLOOR_VISIBLE
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_TURF_OPEN + SMOOTH_GROUP_FLOOR_TRANSPARENT_GLASS
	canSmoothWith = SMOOTH_GROUP_FLOOR_TRANSPARENT_GLASS
	footstep = FOOTSTEP_PLATING
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	tiled_dirt = FALSE

/turf/open/indestructible/glass/Initialize(mapload)
	icon_state = "" // the smooth overlays carry the look, same as /turf/open/floor/glass
	. = ..()
	return INITIALIZE_HINT_LATELOAD

/turf/open/indestructible/glass/LateInitialize()
	ADD_TURF_TRANSPARENCY(src, INNATE_TRAIT)
