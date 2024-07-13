// /datum/controller/subsystem/lighting/Initialize()
// 	if(!initialized)
// 		edit_voidcrew_lighting()
// 		create_all_lighting_objects()
// 		initialized = TRUE

// 	fire(FALSE, TRUE)

// 	return SS_INIT_SUCCESS

// /datum/controller/subsystem/lighting/proc/edit_voidcrew_lighting()
// 	for(var/area/area as anything in GLOB.areas)
// 		if(area.type != /area/overmap_encounter/planetoid/cave)
// 			continue
// 		for (var/list/zlevel_turfs as anything in area.get_zlevel_turf_lists())
// 			for(var/turf/area_turf as anything in zlevel_turfs)
// 				var/list/area/adjacent_areas = get_adjacent_open_areas(area_turf)
// 				if(!adjacent_areas)
// 					continue
// 				var/bl_found = FALSE
// 				for(var/area/a in adjacent_areas)
// 					if(a.area_has_base_lighting)
// 						bl_found = TRUE
// 						break
// 				if(bl_found)
// 					area_turf.set_light(2, 2, l_on = TRUE)
// 			CHECK_TICK
// 		CHECK_TICK
