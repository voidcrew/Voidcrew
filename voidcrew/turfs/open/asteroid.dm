/obj/effect/dummy/lighting_obj/basalt_light
	light_range = 2
	light_power = 0.75
	light_color = "#F98511"

/turf/open/misc/asteroid/basalt/lava_land_surface/planetary/proc/set_basalt_light()
	var/basalt_light_range = 2
	switch(icon_state)
		if("basalt1", "basalt2", "basalt3")
			// set_light(2, 0.6, LIGHT_COLOR_LAVA) //more light
			basalt_light_range = 2
		if("basalt5", "basalt9")
			// set_light(1.4, 0.6, LIGHT_COLOR_LAVA) //barely anything!
			basalt_light_range = 1.4

	var/obj/effect/dummy/lighting_obj/basalt_light/o_light = new(src)
	o_light.light_range = basalt_light_range
	overlay_light = o_light
