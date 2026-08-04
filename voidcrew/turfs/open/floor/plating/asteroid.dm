/turf/open/misc/asteroid/snow/breathable
	initial_gas_mix = FROZEN_ATMOS
	planetary_atmos = TRUE
	slowdown = 0

/turf/open/misc/asteroid/snow/breathable/lit
	light_range = 2
	light_power = 1

/turf/open/misc/dirt/snow
	name = "snowy dirt"
	initial_gas_mix = FROZEN_ATMOS
	planetary_atmos = TRUE

/turf/open/misc/dirt/snow/lit
	light_range = 2
	light_power = 1

/turf/open/misc/asteroid/snow/icemoon/breathable
	initial_gas_mix = FROZEN_ATMOS
	planetary_atmos = TRUE
	// Parent's baseturf is /turf/open/openspace/icemoon (planetary ICEMOON mix): every crater,
	// scrape or dig would spawn a chasm turf whose atmos fights the FROZEN planet forever
	baseturfs = /turf/open/misc/asteroid/snow/icemoon/breathable

// Surface ruin exteriors: matches the mapgen-lit snow (/turf/open/misc/asteroid/snow/breathable/lit)
// so ruin ground isn't a dark patch on an otherwise bright planet.
/turf/open/misc/asteroid/snow/icemoon/breathable/lit
	light_range = 2
	light_power = 1

/turf/open/misc/ice/icemoon/breathable
	initial_gas_mix = FROZEN_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/ice/icemoon/breathable

/turf/open/misc/asteroid/snow/under
	icon_state = "snow_dug"
	planetary_atmos = TRUE

/turf/open/misc/asteroid/snow/under/lit
	light_range = 2
	light_power = 1

/turf/open/misc/asteroid/basalt/lava_land_surface/lit
	light_power = 0.55
	light_range = 2

/turf/open/misc/asteroid/basalt/purple
	icon = 'voidcrew/icons/turf/lavaland_purple.dmi'
	baseturfs = /turf/open/misc/asteroid/basalt/purple
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	planetary_atmos = TRUE

/turf/open/misc/asteroid/basalt/purple/lit
	light_power = 1
	light_range = 2

/turf/open/misc/asteroid/purple
	name = "ashen sand"
	desc = "Sand, tinted by the chemicals in the atmosphere to an uncanny shade of purple."
	icon = 'voidcrew/icons/turf/lavaland_purple.dmi'
	baseturfs = /turf/open/misc/asteroid/purple
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	planetary_atmos = TRUE

/turf/open/misc/asteroid/purple/lit
	light_power = 1
	light_range = 2

/turf/open/misc/asteroid/sand
	name = "sand"
	icon = 'voidcrew/icons/turf/wasteland.dmi'
	damaged_dmi = 'voidcrew/icons/turf/wasteland.dmi'
	icon_state = "desert"
	base_icon_state = "desert"
	baseturfs = /turf/open/misc/asteroid/sand
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	planetary_atmos = TRUE

/turf/open/misc/asteroid/sand/Initialize(mapload, inherited_virtual_z)
	. = ..()
	icon_state = "[base_icon_state][rand(0,5)]"

/turf/open/misc/asteroid/sand/lit
	light_range = 2
	light_power = 1

/**
 * Fallout ground. Mechanically identical to lit sand - the hazard is the emitters
 * standing on it, not the turf - but it lights itself nuclear green instead of
 * neutral. Planet surfaces are lit almost entirely by their own ground, so the
 * colour break against the surrounding wasteland is what marks a contaminated
 * zone as dangerous from off-screen, before anything has been irradiated.
 * Used by /datum/biome/nuclear.
 */
/turf/open/misc/asteroid/sand/lit/nuclear
	name = "contaminated sand"
	desc = "Sand baked into brittle grey glass. Loose grit glows faintly green where it has been disturbed."
	light_color = LIGHT_COLOR_NUCLEAR

/turf/open/misc/asteroid/sand/dark
	icon_state = "desert6"

/turf/open/misc/asteroid/sand/dark/Initialize(mapload, inherited_virtual_z)
	. = ..()
	icon_state = "[base_icon_state][rand(6,8)]"

/turf/open/misc/asteroid/sand/dark/lit
	light_range = 2
	light_power = 1

/// Darker patches of the same fallout ground - see /turf/open/misc/asteroid/sand/lit/nuclear.
/turf/open/misc/asteroid/sand/dark/lit/nuclear
	name = "contaminated sand"
	desc = "Sand baked into brittle grey glass. Loose grit glows faintly green where it has been disturbed."
	light_color = LIGHT_COLOR_NUCLEAR

/turf/open/misc/asteroid/sand/beach
	planetary_atmos = TRUE
	icon = 'voidcrew/icons/misc/beach.dmi'
	damaged_dmi = 'voidcrew/icons/misc/beach.dmi'
	icon_state = "sand"
	base_icon_state = "sand"

/turf/open/misc/asteroid/sand/beach/Initialize(mapload, inherited_virtual_z)
	. = ..()
	icon_state = "[base_icon_state]"

/turf/open/misc/asteroid/sand/beach/lit
	light_range = 2
	light_power = 0.80
	light_color = LIGHT_COLOR_TUNGSTEN

/turf/open/misc/asteroid/sand/beach/dense
	icon_state = "light_sand"
	planetary_atmos = TRUE
	base_icon_state = "light_sand"

/turf/open/misc/asteroid/sand/beach/dense/lit
	light_range = 2
	light_power = 0.80
	light_color = LIGHT_COLOR_TUNGSTEN
