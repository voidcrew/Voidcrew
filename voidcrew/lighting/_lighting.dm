// /create_all_lighting_objects()
// 	for(var/area/area as anything in GLOB.areas)
// 		if(istype(area, /area/overmap_encounter/planetoid/debug))
// 			continue
// 		if(!area.static_lighting)
// 			continue
// 		for (var/list/zlevel_turfs as anything in area.get_zlevel_turf_lists())
// 			for(var/turf/area_turf as anything in zlevel_turfs)
// 				if(area_turf.space_lit)
// 					continue
// 				new /datum/lighting_object(area_turf)
// 			CHECK_TICK
// 		CHECK_TICK

// /datum/controller/subsystem/lighting/proc/create_most_lighting_objects()
// 	for(var/area/area as anything in GLOB.areas)
// 		if(area.type == /area/overmap_encounter/planetoid/debug)
// 			log_admin("yuh")
// 			continue
// 		if(!area.static_lighting)
// 			continue
// 		for (var/list/zlevel_turfs as anything in area.get_zlevel_turf_lists())
// 			for(var/turf/area_turf as anything in zlevel_turfs)
// 				if(area_turf.space_lit)
// 					continue
// 				new /datum/lighting_object(area_turf)
// 			CHECK_TICK
// 		CHECK_TICK


// /datum/controller/subsystem/lighting/Initialize()
// 	if(!initialized)
// 		create_most_lighting_objects()
// 		initialized = TRUE

// 	fire(FALSE, TRUE)

// 	return SS_INIT_SUCCESS
