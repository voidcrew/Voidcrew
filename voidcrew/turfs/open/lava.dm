/turf/open/lava/nosmooth
	name = "lava"
	icon = 'icons/turf/floors/lava.dmi'
	baseturfs = /turf/open/lava
	icon_state = "lava-255"

/turf/open/lava/smooth/lava_land_surface/lit
	light_color = LIGHT_COLOR_LAVA
	light_range = 2
	light_power = 2

/turf/open/lava/plasma/planetary
	// Frozen planets use FROZEN_ATMOS everywhere else. Leaving this on the plasma
	// parent's BURNING_COLD mix makes every river edge active forever.
	initial_gas_mix = FROZEN_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/lava/plasma/planetary
	light_color = "#952CF4"
	light_range = 1.4
	light_power = 0.75

// The anomaly-research space ruin uses the same dim river appearance, but its
// contained plasma pools are deliberately finite BURNING_COLD hazards.
/turf/open/lava/plasma/anomaly_research
	light_color = "#952CF4"
	light_range = 1.4
	light_power = 0.75

/turf/open/lava/smooth/lava_land_surface/planetary
	light_color = "#F98511"
	light_range = 2
	light_power = 2
