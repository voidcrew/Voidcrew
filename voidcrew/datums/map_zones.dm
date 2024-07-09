/datum/map_zone
	var/name = "Map Zone"
	var/id
	/// Is the mapzone currently used by a overmap encounter?
	var/taken = FALSE
	/// List of all z levels this map zone contains
	var/list/z_levels = list()

/datum/map_zone/New(passed_name)
	if(!isnull(passed_name))
		name = passed_name
	SSovermap.map_zones += src
	id = SSovermap.map_zones.len
	. = ..()

/datum/map_zone/Destroy()
	SSovermap.map_zones -= src
	return ..()

/// Clears all of what's inside the z levels managed by the mapzone.
/datum/map_zone/proc/clear_reservation()
	for(var/datum/space_level/zlevel as anything in z_levels)
		zlevel.clear_reservation()

/datum/map_zone/proc/add_space_level(datum/space_level/level)
	z_levels += level

/datum/map_zone/proc/get_mind_mobs()
	. = list()
	for(var/datum/space_level/zlevel as anything in z_levels)
		. += zlevel.get_mind_mobs()

/datum/space_level/proc/get_mind_mobs()
	. = list()
	for(var/mob/living/living_mob as anything in GLOB.mob_living_list)
		if(!living_mob.mind || living_mob.stat == DEAD)
			continue
		if(living_mob.z == z_value)
			. += living_mob

/datum/space_level/proc/get_block()
	return block(locate(1,1,z_value), locate(world.maxx,world.maxy,z_value))

/datum/space_level/proc/clear_reservation()
	var/area/space_area = GLOB.areas_by_type[world.area]

	var/list/turf/block_turfs = get_block()

	for(var/turf/turf as anything in block_turfs)
		// don't waste time trying to qdelete the lighting object
		for(var/datum/thing in (turf.contents - turf.lighting_object))
			qdel(thing)
			// DO NOT CHECK_TICK HERE. IT CAN CAUSE ITEMS TO GET LEFT BEHIND
			// THIS IS REALLY IMPORTANT FOR CONSISTENCY. SORRY ABOUT THE LAG SPIKE

	for(var/turf/turf as anything in block_turfs)
		// Reset turf
		turf.empty(RESERVED_TURF_TYPE, RESERVED_TURF_TYPE, null, CHANGETURF_IGNORE_AIR|CHANGETURF_DEFER_CHANGE)
		// Reset area
		var/area/old_area = get_area(turf)
		turf.change_area(old_area, space_area)
		CHECK_TICK

	for(var/turf/turf as anything in block_turfs)
		turf.AfterChange(CHANGETURF_IGNORE_AIR)
		CHECK_TICK

/datum/space_level/proc/fill_in(turf/turf_type, area/area_override)
	var/area/area_to_use = null
	if(area_override)
		if(ispath(area_override))
			area_to_use = new area_override
		else
			area_to_use = area_override

	if(area_to_use)
		for(var/turf/iterated_turf as anything in get_block())
			var/area/old_area = get_area(iterated_turf)
			iterated_turf.change_area(old_area, area_to_use)
			CHECK_TICK
			if(QDELETED(src))
				return
		area_to_use.reg_in_areas_in_z()

	if(turf_type)
		for(var/turf/iterated_turf as anything in get_block())
			iterated_turf.ChangeTurf(turf_type, turf_type)
			CHECK_TICK
			if(QDELETED(src))
				return
