/turf/open/floor/plating/grass/lit
	light_range = 2
	light_power = 0.80
	baseturfs = /turf/open/misc/beach/sand
	planetary_atmos = TRUE

/turf/open/misc/grass/lit
	light_range = 2
	light_power = 0.80
	baseturfs = /turf/open/misc/beach/sand
	planetary_atmos = TRUE

/**
 * Unlit twin of /turf/open/misc/grass/lit, for beach planet mapgen.
 * Daylight on a generated planet surface is one area-wide ambient light
 * (see /area/overmap_encounter/planetoid/beach) rather than a light source on
 * every single tile, but the beach baseturf and the planetary atmos still have
 * to live on the turf - plain /turf/open/misc/grass carries neither, and a
 * non-planetary surface never purges an atmos disturbance
 * (see /turf/open/misc/dirt/dry).
 * /lit is kept for the ruin .dmms that place it directly.
 */
/turf/open/misc/grass/planet
	baseturfs = /turf/open/misc/beach/sand
	planetary_atmos = TRUE

/turf/open/misc/ice/lit
	light_range = 2
	light_power = 1
	light_color = LIGHT_COLOR_LIGHT_CYAN
	planetary_atmos = TRUE

/turf/open/misc/moss
	name = "overgrown moss"
	desc = "Overgrown moss, sprawling all over the rock below."
	baseturfs = /turf/open/misc/moss
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	planetary_atmos = TRUE
	icon_state = "moss"
	icon = 'voidcrew/icons/turf/lava_moss.dmi'
	base_icon_state = "moss"
	bullet_bounce_sound = null
	footstep = FOOTSTEP_GRASS
	barefootstep = FOOTSTEP_GRASS
	clawfootstep = FOOTSTEP_GRASS
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	// layer = HIGH_TURF_LAYER
	gender = PLURAL
