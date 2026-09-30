// VOIDCREW EDIT ADDITION START: /turf/open/misc/grass registers itself above but is a
// /turf/open/misc, so /turf/open/floor/Destroy()'s removal never applied to it and the
// registration was one-way even on a clean ChangeTurf.
/turf/open/misc/grass/Destroy()
	if(length(GLOB.station_turfs) && !map_region_for_turf(src))
		GLOB.station_turfs -= src
	return ..()
// VOIDCREW EDIT END
