/obj/structure/closet/supplypod/drop_pod
	stay_after_drop = TRUE
	specialised = TRUE
	resistance_flags = LAVA_PROOF | FIRE_PROOF | ACID_PROOF | UNACIDABLE
	style = STYLE_CULT
	var/obj/docking_port/mobile/voidcrew/ship_port
	var/used = FALSE

/obj/structure/closet/supplypod/drop_pod/Initialize(mapload, customStyle)
	. = ..()
	ship_port = SSshuttle.get_containing_shuttle(src)

/obj/structure/closet/supplypod/drop_pod/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(used)
		return
	choose_drop_location(user)

/obj/structure/closet/supplypod/drop_pod/proc/choose_drop_location(mob/living/user)
	if(!ship_port)
		return
	var/list/current_overmap_objects = ship_port.current_ship.close_overmap_objects

	var/obj/structure/overmap/planet/current_planet

	for(var/obj/structure/overmap/object in current_overmap_objects)
		if(object.type in typesof(/obj/structure/overmap/planet))
			current_planet = object
	if(!current_planet || !current_planet.mapzone || !(length(current_planet.mapzone.z_levels)))
		return
	var/planet_z_level = current_planet.mapzone.z_levels[1].z_value // the first z level
	if(!planet_z_level)
		return

	var/list/area/planet_areas = list()
	for (var/area/area in SSmapping.areas_in_z["[planet_z_level]"])
		if (!(area.type in typesof(/area/ruin)))
			planet_areas += area
	for (var/i in 1 to 5)
		var/list/turf_list = get_area_turfs(pick(planet_areas))
		var/turf/target
		while (turf_list.len && !target)
			var/I = rand(1, turf_list.len)
			var/turf/checked_turf = turf_list[I]
			if(!checked_turf.density && !isgroundlessturf(checked_turf))
				var/clear = TRUE
				for(var/obj/checked_object in checked_turf)
					if(checked_object.density)
						clear = FALSE
						break
				if(clear)
					target = checked_turf
			if (!target)
				turf_list.Cut(I, I + 1)
		if (target)
			user.forceMove(src)
			new /obj/effect/pod_landingzone(target, src)
			used = TRUE
			return
