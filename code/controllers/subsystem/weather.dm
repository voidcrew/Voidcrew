/// Used for all kinds of weather, ex. lavaland ash storms.
SUBSYSTEM_DEF(weather)
	name = "Weather"
	ss_flags = SS_BACKGROUND
	dependencies = list(
		/datum/controller/subsystem/mapping,
	)
	wait = 10
	runlevels = RUNLEVEL_GAME
	var/list/processing = list()
	// VOIDCREW EDIT ADDITION BEGIN
	/// Snapshot of active weather being processed in the current fire. The event at
	/// the end remains there until all of its tasks finish, including across resumes.
	var/list/currentrun = list()
	// VOIDCREW EDIT ADDITION END
	/// Z levels on which weather can occur -> weather that can occur -> probability of said weather occuring
	var/list/eligible_zlevels = list()
	/// VOIDCREW EDIT ADDITION - canonical random-weather weights for each registered z-level
	var/list/weather_types_by_zlevel = list()
	/// Used by barometers to know when the next storm is coming
	var/list/next_hit_by_zlevel = list()
	// VOIDCREW EDIT ADDITION BEGIN
	/// Randomly scheduled weather currently occupying each z-level, including its cooldown.
	var/list/random_weather_by_zlevel = list()
	/// z ("[z]") -> list of living mobs, rebuilt at most once per fire cycle so several
	/// concurrent storms share one scan of the global mob list instead of one scan each
	var/list/mobs_by_z_cache
	/// The times_fired value mobs_by_z_cache was built on
	var/mobs_by_z_cache_fire = -1
	// VOIDCREW EDIT ADDITION END
	/// Alist of all particle holders per Z-stack offset for particle weather, each particle holder associated with z-levels it should be displayed on, to be shown to clients
	var/alist/particle_holders = alist()
	/// List of all RENDER_PLANE_PARTICLE_WEATHER and RENDER_PLANE_EMISSIVE_PARTICLE_WEATHER planes
	var/list/particle_planemasters = list()

/datum/controller/subsystem/weather/fire(resumed = FALSE)
	// process active weather
	// VOIDCREW EDIT BEGIN - a saved currentrun, so an event that runs out of tick budget resumes
	// where it left off instead of being re-processed from the top of the processing list
	if(!resumed)
		currentrun = processing.Copy()
	var/list/currentrun_cache = currentrun
	while(currentrun_cache.len)
		var/datum/weather/weather_event = currentrun_cache[currentrun_cache.len]
		if(QDELETED(weather_event) || !(weather_event in processing) || !length(weather_event.subsystem_tasks))
			currentrun_cache.len--
			resumed = FALSE
			continue

		if(istype(weather_event, /datum/weather/particle))
			var/datum/weather/particle/particle_event = weather_event
			particle_event.process_particles()

		if(weather_event.stage != MAIN_STAGE)
			currentrun_cache.len--
			resumed = FALSE
			continue
		// VOIDCREW EDIT END

		if(weather_event.subsystem_tasks[weather_event.task_index] == SSWEATHER_MOBS)
			if(!resumed)
				// VOIDCREW EDIT BEGIN - only collect mobs on the impacted z-levels, the whole world's
				// mob list gets very large with populated planets. The z index is built once per fire
				// cycle and shared by every storm processing this fire.
				if(mobs_by_z_cache_fire != times_fired)
					mobs_by_z_cache = list()
					mobs_by_z_cache_fire = times_fired
					for(var/mob/living/candidate as anything in GLOB.mob_living_list)
						// Weather is player-facing; ordinary planetary fauna should never enter its work list.
						if(!candidate.mind && !candidate.ever_had_mind)
							continue
						var/candidate_z = candidate.z
						if(!candidate_z) // contained mobs report z = 0
							var/turf/candidate_turf = get_turf(candidate)
							if(candidate_turf)
								candidate_z = candidate_turf.z
						if(!candidate_z)
							continue
						var/z_key = "[candidate_z]"
						var/list/z_mobs = mobs_by_z_cache[z_key]
						if(!z_mobs)
							z_mobs = list()
							mobs_by_z_cache[z_key] = z_mobs
						z_mobs += candidate
				var/list/eligible_mobs = list()
				for(var/storm_z in weather_event.impacted_z_levels)
					var/list/z_mobs = mobs_by_z_cache["[storm_z]"]
					if(z_mobs)
						eligible_mobs += z_mobs
				weather_event.current_mobs = eligible_mobs
				// VOIDCREW EDIT END
			var/list/current_mobs_cache = weather_event.current_mobs // cache for performance
			while(current_mobs_cache.len)
				var/mob/living/target = current_mobs_cache[current_mobs_cache.len]
				current_mobs_cache.len--
				if(QDELETED(target))
					continue
				if(weather_event.can_weather_act_mob(target))
					weather_event.weather_act_mob(target)
				if(MC_TICK_CHECK)
					return
			resumed = FALSE
			weather_event.task_index = WRAP_UP(weather_event.task_index, weather_event.subsystem_tasks.len)

		if(weather_event.subsystem_tasks[weather_event.task_index] == SSWEATHER_TURFS)
			if(!resumed)
				weather_event.turf_iteration = ROUND_PROB(weather_event.weather_turfs_per_tick)
			while(weather_event.turf_iteration)
				weather_event.turf_iteration--
				var/turf/selected_turf = weather_event.pick_turf()
				if(selected_turf && weather_event.can_weather_act_turf(selected_turf))
					weather_event.weather_act_turf(selected_turf)
				if(MC_TICK_CHECK)
					return
			resumed = FALSE
			weather_event.task_index = WRAP_UP(weather_event.task_index, weather_event.subsystem_tasks.len)

		if(weather_event.subsystem_tasks[weather_event.task_index] == SSWEATHER_THUNDER)
			if(!resumed)
				weather_event.thunder_iteration = ROUND_PROB(weather_event.thunder_turfs_per_tick)
			while(weather_event.thunder_iteration)
				weather_event.thunder_iteration--
				var/turf/selected_turf = weather_event.pick_turf()
				if(selected_turf && weather_event.can_weather_act_turf(selected_turf))
					weather_event.thunder_act_turf(selected_turf)
				if(MC_TICK_CHECK)
					return
			resumed = FALSE
			weather_event.task_index = WRAP_UP(weather_event.task_index, weather_event.subsystem_tasks.len)

		// VOIDCREW EDIT ADDITION BEGIN - do not remove an event before all of its tasks complete.
		// If MC_TICK_CHECK returned above, this remains the last entry and the next fire resumes it.
		currentrun_cache.len--
		resumed = FALSE
		// VOIDCREW EDIT ADDITION END

	// start random weather on relevant levels
	// VOIDCREW EDIT BEGIN - one scheduled storm per z-level at a time, with the downtime keyed off
	// the storm's real length and scaled by the overmap danger zone the z-level sits in
	var/list/eligible_zlevels_cache = eligible_zlevels.Copy()
	eligible_zlevels.Cut()
	for(var/z in eligible_zlevels_cache)
		var/list/possible_weather = eligible_zlevels_cache[z]
		if(!length(possible_weather))
			continue
		var/z_key = "[z]"
		if(random_weather_by_zlevel[z_key])
			continue
		var/numeric_z = text2num(z)
		if(is_weather_active_on_z(numeric_z))
			eligible_zlevels[z] = possible_weather
			continue
		var/datum/weather/weather_event_type = pick_weight(possible_weather)
		var/datum/weather/weather_event = run_weather(weather_event_type, list(numeric_z))
		random_weather_by_zlevel[z_key] = weather_event
		if(weather_event.weather_flags & WEATHER_ENDLESS)
			continue
		var/randTime = rand(5 MINUTES, 10 MINUTES)
		randTime *= SSovermap_zones.weather_downtime_multiplier_for_z(numeric_z) // storms come more often on planets in dangerous overmap zones
		var/time_until_next_storm = weather_event.telegraph_duration + weather_event.weather_duration + weather_event.end_duration + randTime
		var/old_timer = next_hit_by_zlevel[z_key]
		if(old_timer)
			deltimer(old_timer)
		next_hit_by_zlevel[z_key] = addtimer(CALLBACK(src, PROC_REF(make_eligible), z), time_until_next_storm, TIMER_STOPPABLE)
	// VOIDCREW EDIT END

/datum/controller/subsystem/weather/Initialize()
	for(var/datum/weather/weather as anything in valid_subtypesof(/datum/weather))
		var/probability = initial(weather.probability)
		var/target_trait = initial(weather.target_trait)

		// any weather with a probability set may occur at random
		if (probability)
			for(var/z in SSmapping.levels_by_trait(target_trait))
				// VOIDCREW EDIT - weather_types_by_zlevel is the canonical table, eligible_zlevels is the live queue
				LAZYINITLIST(weather_types_by_zlevel["[z]"])
				weather_types_by_zlevel["[z]"][weather] = probability
	// VOIDCREW EDIT ADDITION BEGIN
	for(var/z in weather_types_by_zlevel)
		eligible_zlevels[z] = weather_types_by_zlevel[z]
	// VOIDCREW EDIT ADDITION END
	return SS_INIT_SUCCESS

/datum/controller/subsystem/weather/proc/add_weather_objects(list/new_holders, z_level)
	for (var/offset in 1 to length(new_holders))
		var/list/holder_list = new_holders[offset]
		if (isnull(particle_holders[offset]))
			particle_holders[offset] = list()
		particle_holders[offset] += holder_list

		// We add it to vis_contents of planemasters rather than client screen as planemasters already
		// manage their own visibility based on owner's z level
		for (var/atom/movable/screen/plane_master/plane_master as anything in particle_planemasters)
			var/mob/owner = plane_master.home.our_hud?.mymob
			if (!owner) // Vibecheck
				continue
			// Could be caching these per-mob but its basically just a list lookup wrapper
			var/list/stack_levels = SSmapping.get_connected_levels(get_turf(owner.client?.eye || owner))
			for (var/obj/effect/abstract/weather_holder/holder as anything in holder_list)
				if (holder.plane != plane_master.plane)
					continue

				if (!length(holder_list[holder] & stack_levels))
					continue

				plane_master.vis_contents |= holder

/datum/controller/subsystem/weather/proc/remove_weather_objects(list/old_holders)
	for (var/offset in 1 to length(old_holders))
		var/list/holder_list = old_holders[offset]
		particle_holders[offset] -= holder_list

		for (var/atom/movable/screen/plane_master/plane_master as anything in particle_planemasters)
			plane_master.vis_contents -= holder_list

/datum/controller/subsystem/weather/proc/update_z_level(datum/space_level/level)
	var/z = level.z_value
	// VOIDCREW EDIT BEGIN - dynamic planet z-levels are recycled, so a level's weather table has to
	// be replaced wholesale rather than accumulated, and a level with no weather has to be dropped
	var/z_key = "[z]"
	var/list/possible_weather = list()
	for(var/datum/weather/weather as anything in valid_subtypesof(/datum/weather))
		var/probability = initial(weather.probability)
		var/target_trait = initial(weather.target_trait)
		if(probability && level.traits[target_trait])
			possible_weather[weather] = probability

	if(!length(possible_weather))
		unregister_z_level(z)
		return

	weather_types_by_zlevel[z_key] = possible_weather
	if(z_key in eligible_zlevels)
		eligible_zlevels[z_key] = possible_weather
	else if(!next_hit_by_zlevel[z_key] && !random_weather_by_zlevel[z_key])
		eligible_zlevels[z_key] = possible_weather

/// Stops random weather scheduling for a z-level and ends its currently scheduled storm.
/datum/controller/subsystem/weather/proc/unregister_z_level(z)
	var/z_key = "[z]"
	eligible_zlevels -= z_key
	weather_types_by_zlevel -= z_key

	var/timer_id = next_hit_by_zlevel[z_key]
	if(timer_id)
		deltimer(timer_id)
	next_hit_by_zlevel -= z_key

	var/datum/weather/weather_event = random_weather_by_zlevel[z_key]
	random_weather_by_zlevel -= z_key
	if(weather_event && !QDELETED(weather_event) && weather_event.stage != END_STAGE)
		weather_event.end()

/// Replaces the random-weather trait on a recycled dynamic z-level.
/datum/controller/subsystem/weather/proc/set_z_level_weather_trait(datum/space_level/level, new_weather_trait)
	var/z = level.z_value
	unregister_z_level(z)

	var/list/random_weather_traits = list()
	for(var/datum/weather/weather as anything in valid_subtypesof(/datum/weather))
		if(!initial(weather.probability))
			continue
		var/target_trait = initial(weather.target_trait)
		if(target_trait)
			random_weather_traits |= list(target_trait)

	for(var/weather_trait in random_weather_traits)
		level.traits -= weather_trait
		var/list/trait_levels = SSmapping.z_trait_levels[weather_trait]
		if(trait_levels)
			trait_levels -= z

	if(!new_weather_trait)
		return

	level.traits[new_weather_trait] = TRUE
	var/list/new_trait_levels = SSmapping.z_trait_levels[new_weather_trait]
	if(!new_trait_levels)
		new_trait_levels = list()
		SSmapping.z_trait_levels[new_weather_trait] = new_trait_levels
	new_trait_levels |= list(z)
	update_z_level(level)
	// VOIDCREW EDIT END

/datum/controller/subsystem/weather/proc/run_weather(datum/weather/weather_datum_type, z_levels, list/weather_data)
	if (istext(weather_datum_type))
		for (var/datum/weather/weather as anything in valid_subtypesof(/datum/weather))
			if (initial(weather.name) == weather_datum_type)
				weather_datum_type = weather
				break
	if (!ispath(weather_datum_type, /datum/weather))
		CRASH("run_weather called with invalid weather_datum_type: [weather_datum_type || "null"]")

	if (isnull(z_levels))
		z_levels = SSmapping.levels_by_trait(initial(weather_datum_type.target_trait))
	else if (isnum(z_levels))
		z_levels = list(z_levels)
	else if (!islist(z_levels))
		CRASH("run_weather called with invalid z_levels: [z_levels || "null"]")

	var/datum/weather/weather = new weather_datum_type(z_levels, weather_data)
	weather.telegraph(weather_data)
	return weather

// VOIDCREW EDIT BEGIN - the scheduler owns the weather table, so make_eligible only needs the z
/datum/controller/subsystem/weather/proc/make_eligible(z)
	var/z_key = "[z]"
	next_hit_by_zlevel -= z_key
	random_weather_by_zlevel -= z_key
	var/list/possible_weather = weather_types_by_zlevel[z_key]
	if(length(possible_weather))
		eligible_zlevels[z_key] = possible_weather

/// Returns TRUE while any weather stage still occupies a z-level.
/datum/controller/subsystem/weather/proc/is_weather_active_on_z(z)
	for(var/datum/weather/weather_event as anything in processing)
		if(weather_event.stage != END_STAGE && islist(weather_event.impacted_z_levels) && (z in weather_event.impacted_z_levels))
			return TRUE
	return FALSE
// VOIDCREW EDIT END

/datum/controller/subsystem/weather/proc/get_weather(z, area/active_area)
	var/datum/weather/A
	for(var/V in processing)
		var/datum/weather/W = V
		if((z in W.impacted_z_levels) && W.area_type == active_area.type)
			A = W
			break
	return A

///Returns an active storm by its type
/datum/controller/subsystem/weather/proc/get_weather_by_type(type)
	return locate(type) in processing
