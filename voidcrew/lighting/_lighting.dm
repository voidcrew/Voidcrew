// /datum/controller/subsystem/lighting/Initialize()
// 	for(var/area/overmap_encounter/planetoid/area in GLOB.areas)
// 		for(var/turf/turf in area.contents)
// 			if(turf.light_range > 0 && isnull(turf.overlay_light))
// 				turf.overlay_light = new /obj/effect/dummy/lighting_obj(turf, turf.light_range, turf.light_power, turf.light_color)

// 		CHECK_TICK
// 	CHECK_TICK
// 	. = ..()
