/// Voidcrew weather subsystem overrides:
/// - Use carbon_list instead of mob_living_list for mob processing (performance)
/// - Skip weather processing on planets with no players present
/// - Cap concurrent planet weather events to prevent tick overruns

/datum/controller/subsystem/weather
	/// Maps surface z-level (as string) to cave z-level (as number) for roundstart planets.
	/// Used to check player presence on both surface and cave z-levels.
	var/list/planet_cave_z_lookup = list()
	/// Maximum number of planet weather events allowed in MAIN_STAGE simultaneously.
	var/max_concurrent_planet_weather = 3

/datum/controller/subsystem/weather/Initialize()
	. = ..()
	// Build surface_z -> cave_z lookup from roundstart planet data.
	// SSmapping.loadWorld() populates this before SSweather.Initialize() runs.
	for(var/planet_name in SSmapping.planets)
		var/list/planet_data = SSmapping.planets[planet_name]
		var/surface_z = planet_data["z"]
		var/cave_z = planet_data["cave_z"]
		if(surface_z && cave_z)
			planet_cave_z_lookup["[surface_z]"] = cave_z

/// Returns TRUE if any player client is on the given z-level or its associated cave z-level.
/datum/controller/subsystem/weather/proc/planet_has_players(z_value)
	if(length(SSmobs.clients_by_zlevel[z_value]))
		return TRUE
	var/cave_z = planet_cave_z_lookup["[z_value]"]
	if(cave_z && length(SSmobs.clients_by_zlevel[cave_z]))
		return TRUE
	return FALSE

/// Counts planet weather events currently in MAIN_STAGE.
/datum/controller/subsystem/weather/proc/count_active_planet_weather()
	var/count = 0
	for(var/datum/weather/weather as anything in processing)
		if(weather.stage == MAIN_STAGE && ispath(weather.area_type, /area/overmap_encounter/planetoid))
			count++
	return count

/datum/controller/subsystem/weather/fire(resumed = FALSE)
	// process active weather
	for(var/datum/weather/weather_event as anything in processing)
		if(!length(weather_event.subsystem_tasks) || weather_event.stage != MAIN_STAGE)
			continue

		// Skip processing for planet weather on empty planets
		if(ispath(weather_event.area_type, /area/overmap_encounter/planetoid))
			var/has_players = FALSE
			for(var/z_level in weather_event.impacted_z_levels)
				if(planet_has_players(z_level))
					has_players = TRUE
					break
			if(!has_players)
				continue

		if(weather_event.subsystem_tasks[weather_event.task_index] == SSWEATHER_MOBS)
			if(!resumed)
				weather_event.current_mobs = GLOB.carbon_list.Copy() // voidcrew edit: carbon_list instead of mob_living_list
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

	// start random weather on relevant levels
	var/active_planet_weather_count = count_active_planet_weather()
	for(var/z in eligible_zlevels)
		// Don't spawn weather on planets with no players
		if(!planet_has_players(text2num(z)))
			continue // stays eligible, rechecked next fire()
		// Don't exceed concurrent planet weather cap
		if(active_planet_weather_count >= max_concurrent_planet_weather)
			break
		var/possible_weather = eligible_zlevels[z]
		var/datum/weather/weather_event = pick_weight(possible_weather)
		run_weather(weather_event, list(text2num(z)))
		eligible_zlevels -= z
		active_planet_weather_count++
		var/randTime = rand(5 MINUTES, 10 MINUTES)
		next_hit_by_zlevel["[z]"] = addtimer(CALLBACK(src, PROC_REF(make_eligible), z, possible_weather), randTime + initial(weather_event.weather_duration_upper), TIMER_UNIQUE|TIMER_STOPPABLE)
