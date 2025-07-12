/turf/open/misc/asteroid/snow/breathable
	planetary_atmos = TRUE
	slowdown = 0


/turf/open/misc/asteroid/snow/under
	icon_state = "snow_dug"
	planetary_atmos = TRUE



/turf/open/misc/asteroid/basalt/purple
	icon = 'voidcrew/icons/turf/lavaland_purple.dmi'
	baseturfs = /turf/open/misc/asteroid/basalt/purple
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	planetary_atmos = TRUE


/turf/open/misc/asteroid/purple
	name = "ashen sand"
	desc = "Sand, tinted by the chemicals in the atmosphere to an uncanny shade of purple."
	icon = 'voidcrew/icons/turf/lavaland_purple.dmi'
	baseturfs = /turf/open/misc/asteroid/purple
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	planetary_atmos = TRUE


/turf/open/misc/asteroid/sand
	name = "sand"
	icon = 'voidcrew/icons/turf/wasteland.dmi'
	icon_state = "desert"
	base_icon_state = "desert"
	baseturfs = /turf/open/misc/asteroid/sand
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	planetary_atmos = TRUE

/turf/open/misc/asteroid/sand/Initialize(mapload, inherited_virtual_z)
	. = ..()
	icon_state = "[base_icon_state][rand(0,5)]"


/turf/open/misc/asteroid/sand/dark
	icon_state = "desert6"

/turf/open/misc/asteroid/sand/dark/Initialize(mapload, inherited_virtual_z)
	. = ..()
	icon_state = "[base_icon_state][rand(6,8)]"


/turf/open/misc/asteroid/sand/beach
	planetary_atmos = TRUE
	icon = 'voidcrew/icons/misc/beach.dmi'
	icon_state = "sand"
	base_icon_state = "sand"

/turf/open/misc/asteroid/sand/beach/Initialize(mapload, inherited_virtual_z)
	. = ..()
	icon_state = "[base_icon_state]"


/turf/open/misc/asteroid/sand/beach/dense
	icon_state = "light_sand"
	planetary_atmos = TRUE
	base_icon_state = "light_sand"

