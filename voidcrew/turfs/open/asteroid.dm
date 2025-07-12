
/turf/open/misc/asteroid/planetary_basalt
	name = "volcanic floor"
	baseturfs = /turf/open/misc/asteroid/basalt
	icon = 'icons/turf/floors.dmi'
	icon_state = "basalt"
	base_icon_state = "basalt"
	floor_variance = 15
	dig_result = /obj/item/stack/ore/glass/basalt

/turf/open/misc/asteroid/planetary_basalt/getDug()
	GLOB.dug_up_basalt |= src
	return ..()

/turf/open/misc/asteroid/planetary_basalt/Destroy()
	GLOB.dug_up_basalt -= src
	return ..()

/turf/open/misc/asteroid/planetary_basalt/refill_dug()
	. = ..()
	GLOB.dug_up_basalt -= src

/turf/open/misc/asteroid/planetary_basalt/lava //lava underneath
	baseturfs = /turf/open/lava/smooth

/turf/open/misc/asteroid/planetary_basalt/airless
	initial_gas_mix = AIRLESS_ATMOS
	worm_chance = 0

/turf/open/misc/asteroid/planetary_basalt/Initialize(mapload)
	. = ..()

/turf/open/misc/asteroid/planetary_basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/lava/smooth/lava_land_surface

