/obj/effect/dummy/lighting_obj/basalt_light
	light_range = 2
	light_power = 0.75
	light_color = "#F98511"

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
	set_basalt_light(src)

/turf/open/misc/asteroid/planetary_basalt/lava //lava underneath
	baseturfs = /turf/open/lava/smooth

/turf/open/misc/asteroid/planetary_basalt/airless
	initial_gas_mix = AIRLESS_ATMOS
	worm_chance = 0

/turf/open/misc/asteroid/planetary_basalt/Initialize(mapload)
	. = ..()
	set_basalt_light(src)

/turf/open/misc/asteroid/planetary_basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/lava/smooth/lava_land_surface/planetary

/turf/open/misc/asteroid/planetary_basalt/proc/set_basalt_light()
	var/area/turf_area = get_area(src)
	if(turf_area.base_lighting_alpha != null || turf_area.base_lighting_alpha > 0)
		return

	// var/basalt_light_range = 1.4
	// var/basalt_light_power = 0
	var/light_size = 0
	var/light_alpha = 255
	switch(icon_state)
		if("basalt1", "basalt2", "basalt3")
			// basalt_light_power = 1
			light_size = 1.4
			light_alpha = 130
		if("basalt5", "basalt9")
			// basalt_light_power = 0.5
			light_size = 1.2
			light_alpha = 170
		else
			// basalt_light_range = 0
			light_size = 0

	// if(basalt_light_range > 0)
	if(light_size > 0)
		// var/obj/effect/dummy/lighting_obj/basalt_light/o_light = new(src)
		// o_light.light_range = basalt_light_range
		// o_light.light_power = basalt_light_power
		// overlay_light = o_light

		var/image/visible_mask = image('icons/effects/light_overlays/light_32.dmi', icon_state = "light")
		SET_PLANE_EXPLICIT(visible_mask, O_LIGHTING_VISUAL_PLANE, src)
		visible_mask.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
		visible_mask.alpha = light_alpha
		visible_mask.color = "#F98511"

		var/matrix/transform = new
		transform.Scale(light_size)
		// transform.Translate(-10.4)
		visible_mask.transform = transform

		src.overlays += visible_mask
