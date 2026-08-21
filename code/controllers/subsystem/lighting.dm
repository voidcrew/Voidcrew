SUBSYSTEM_DEF(lighting)
	name = "Lighting"
	dependencies = list(
		/datum/controller/subsystem/atoms,
		/datum/controller/subsystem/mapping,
	)
	wait = 2
	flags = SS_TICKER
	var/static/list/sources_queue = list() // List of lighting sources queued for update.
	var/static/list/corners_queue = list() // List of lighting corners queued for update.
	var/static/list/objects_queue = list() // List of lighting objects queued for update.
	var/static/list/current_sources = list()
#ifdef VISUALIZE_LIGHT_UPDATES
	var/allow_duped_values = FALSE
	var/allow_duped_corners = FALSE
#endif

/datum/controller/subsystem/lighting/stat_entry(msg)
	msg = "\n  Sources:[length(sources_queue)]|Corners:[length(corners_queue)]|Objects:[length(objects_queue)]"
	return ..()


/datum/controller/subsystem/lighting/Initialize()
	if(!initialized)
		create_all_lighting_objects()
		initialized = TRUE

	fire(FALSE, TRUE)

	return SS_INIT_SUCCESS


/datum/controller/subsystem/lighting/proc/create_all_lighting_objects()
	for(var/area/area as anything in GLOB.areas)
		// VOIDCREW EDIT: ambient-lit ground (a planet surface, static_lighting FALSE) carries
		// no lighting objects at all - that is where the memory saving comes from - EXCEPT
		// turfs that light themselves, like the fallout zone's hazard green. Those need an
		// object apiece or their own light has nothing to render on, and roundstart planets
		// never pass through ChangeTurf (their terrain is laid down before SSlighting comes
		// up), so this sweep is the only place they can get one.
		// See /turf/proc/skips_lighting_object() in voidcrew/edits/lighting.dm.
		var/ambient_lit_area = area.ambient_lighting
		if(!area.static_lighting && !ambient_lit_area)
			continue
		// END VOIDCREW EDIT (was: if(!area.static_lighting) continue)
		for (var/list/zlevel_turfs as anything in area.get_zlevel_turf_lists())
			for(var/turf/area_turf as anything in zlevel_turfs)
				if(area_turf.space_lit)
					continue
				// VOIDCREW EDIT: see above
				if(ambient_lit_area && area_turf.skips_lighting_object())
					continue
				// END VOIDCREW EDIT
				new /datum/lighting_object(area_turf)
			CHECK_TICK
		CHECK_TICK

/datum/controller/subsystem/lighting/fire(resumed, init_tick_checks)
	MC_SPLIT_TICK_INIT(3)
	if(!init_tick_checks)
		MC_SPLIT_TICK

	if(!resumed)
		// voidcrew edit: a non-resumed fire while current_sources still has entries means
		// the previous drain was interrupted (a runtime mid-batch, or an overlapping
		// fire(FALSE, TRUE) from Initialize racing the MC's ticks). Those sources sit
		// with needs_update set but in no queue, so EFFECT_UPDATE refuses to requeue
		// them and they stay dark forever. Salvage the remainder instead of leaking it.
		if(length(current_sources))
			sources_queue = current_sources + sources_queue
		current_sources = sources_queue
		sources_queue = list()

	// UPDATE SOURCE QUEUE
	var/i = 0
	var/list/queue = current_sources
	while(i < length(queue)) //we don't use for loop here because i cannot be changed during an iteration
		i += 1

		var/datum/light_source/L = queue[i]
		L.update_corners()
		if(!QDELETED(L))
			L.needs_update = LIGHTING_NO_UPDATE
		else
			i -= 1 // update_corners() has removed L from the list, move back so we don't overflow or skip the next element

		// We unroll TICK_CHECK here so we can clear out the queue to ensure any removals/additions when sleeping don't fuck us
		if(init_tick_checks)
			if(!TICK_CHECK)
				continue
			queue.Cut(1, i + 1)
			i = 0
			stoplag()
		else if(MC_TICK_CHECK)
			break
	if(i)
		queue.Cut(1, i + 1)
		i = 0

	if(!init_tick_checks)
		MC_SPLIT_TICK

	// UPDATE CORNERS QUEUE
	queue = corners_queue
	while(i < length(queue)) //we don't use for loop here because i cannot be changed during an iteration
		i += 1

		var/datum/lighting_corner/C = queue[i]
		C.needs_update = FALSE //update_objects() can call qdel if the corner is storing no data
		C.update_objects()

		// We unroll TICK_CHECK here so we can clear out the queue to ensure any removals/additions when sleeping don't fuck us
		if(init_tick_checks)
			if(!TICK_CHECK)
				continue
			queue.Cut(1, i + 1)
			i = 0
			stoplag()
		else if(MC_TICK_CHECK)
			break
	if(i)
		queue.Cut(1, i+1)
		i = 0

	if(!init_tick_checks)
		MC_SPLIT_TICK

	// UPDATE OBJECTS QUEUE
	queue = objects_queue
	while(i < length(queue)) //we don't use for loop here because i cannot be changed during an iteration
		i += 1

		var/datum/lighting_object/O = queue[i]
		if(QDELETED(O))
			continue
		O.update()
		O.needs_update = FALSE

		// We unroll TICK_CHECK here so we can clear out the queue to ensure any removals/additions when sleeping don't fuck us
		if(init_tick_checks)
			if(!TICK_CHECK)
				continue
			queue.Cut(1, i + 1)
			i = 0
			stoplag()
		else if(MC_TICK_CHECK)
			break
	if(i)
		queue.Cut(1, i + 1)


/datum/controller/subsystem/lighting/Recover()
	initialized = SSlighting.initialized
	..()
