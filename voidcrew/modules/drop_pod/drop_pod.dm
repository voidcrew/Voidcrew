/obj/structure/closet/supplypod/drop_pod
	stay_after_drop = TRUE
	specialised = TRUE
	resistance_flags = LAVA_PROOF | FIRE_PROOF | ACID_PROOF | UNACIDABLE
	style = STYLE_CULT
	var/obj/docking_port/mobile/voidcrew/ship_port

/obj/structure/closet/supplypod/drop_pod/Initialize(mapload, customStyle)
	. = ..()
	ship_port = SSshuttle.get_containing_shuttle(src)

/obj/structure/closet/supplypod/drop_pod/proc/choose_drop_location()
	if(!ship_port)
		return
	var/current_overmap_objects = ship_port.current_ship.close_overmap_objects

	var/obj/structure/overmap/planet/current_planet

	for(var/object in current_overmap_objects)
		if(object.type in typesof(/obj/structure/overmap/planet))
			current_planet = object
	if(!current_planet || !current_planet.map_zone || !(length(current_planet.map_zone.z_levels)))
		return
	var/planet_z_level = current_planet.map_zone.z_levels[1] // the first z level
	var/list/area/planet_areas = list()
	for (var/area/area in SSmapping.areas_in_z(planet_z_level))
		if (!(area.type in typesof(/area/ruin)))
			planet_areas += area


