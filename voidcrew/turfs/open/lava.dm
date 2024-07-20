/turf/open/lava/nosmooth
	name = "lava"
	icon = 'icons/turf/floors/lava.dmi'
	baseturfs = /turf/open/lava
	icon_state = "lava-255"

/turf/open/lava/smooth/lava_land_surface/lit
	light_color = LIGHT_COLOR_LAVA
	light_range = 2
	light_power = 2

/obj/effect/dummy/lighting_obj/lava_light/plasma
	light_color = "#CD4C9F"

/obj/effect/dummy/lighting_obj/lava_light
	light_range = 2
	light_power = 0.75
	light_color = "#F98511"

/turf/open/lava/smooth/lava_land_surface/planetary

/turf/open/lava/smooth/lava_land_surface/planetary/refresh_light()
	var/border_turf = FALSE
	var/list/turfs_to_check = RANGE_TURFS(1, src)
	if(GET_LOWEST_STACK_OFFSET(z))
		var/turf/above = GET_TURF_ABOVE(src)
		if(above)
			turfs_to_check += RANGE_TURFS(1, above)
		var/turf/below = GET_TURF_BELOW(src)
		if(below)
			turfs_to_check += RANGE_TURFS(1, below)

	for(var/turf/around as anything in turfs_to_check)
		if(islava(around))
			continue
		border_turf = TRUE

	if(!border_turf)
		return
	overlay_light = new /obj/effect/dummy/lighting_obj/lava_light(src)
