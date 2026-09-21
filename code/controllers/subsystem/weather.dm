/// Used for all kinds of weather, ex. lavaland ash storms.
SUBSYSTEM_DEF(weather)
	name = "Weather"
	flags = SS_BACKGROUND
	dependencies = list(
		/datum/controller/subsystem/mapping,
	)
	wait = 10
	runlevels = RUNLEVEL_GAME
	var/list/processing = list()
	// VOIDCREW EDIT REMOVAL START - the four "[z]"-keyed scheduler maps (eligible_zlevels,
	// weather_types_by_zlevel, next_hit_by_zlevel, random_weather_by_zlevel) are replaced by
	// the /datum/weather_site registry below, so several places can share a z-level and each
	// keep its own climate, storm and cooldown. See voidcrew/datums/weather_site.dm.
	// VOIDCREW EDIT REMOVAL END

/datum/controller/subsystem/weather/fire(resumed = FALSE)
	// process active weather
	if(!resumed)
		currentrun = processing.Copy()
	var/list/currentrun_cache = currentrun
	while(currentrun_cache.len)
		var/datum/weather/weather_event = currentrun_cache[currentrun_cache.len]
		if(QDELETED(weather_event) || !(weather_event in processing) || !length(weather_event.subsystem_tasks) || weather_event.stage != MAIN_STAGE)
			currentrun_cache.len--
			resumed = FALSE
			continue

		if(weather_event.subsystem_tasks[weather_event.task_index] == SSWEATHER_MOBS)
			if(!resumed)
				// Only collect mobs on the impacted z-levels, the whole world's mob list gets very large with populated planets.
				// The z index is built once per fire cycle and shared by every storm processing this fire.
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

		// Do not remove an event before all of its tasks complete. If MC_TICK_CHECK
		// returns above, this remains the last entry and the next fire resumes it.
		currentrun_cache.len--
		resumed = FALSE

	// VOIDCREW EDIT REPLACEMENT START - random weather is scheduled per site, not per z-level.
	// One storm per SITE replaces the old one-storm-per-z rule, so two sites sharing a
	// z-level can storm at the same time and hold independent cooldowns.
	var/list/datum/weather_site/eligible_sites_cache = eligible_sites.Copy()
	eligible_sites.Cut()
	for(var/datum/weather_site/site as anything in eligible_sites_cache)
		if(QDELETED(site) || !length(site.weather_types))
			continue
		if(site.awaiting_owned_areas())
			// Registered, but the areas it owns do not exist yet - a planet's site outlives
			// apply_planet_level_traits() by the whole of fill_in(), which is minutes. Rolling now
			// would hand the storm the z-wide get_areas(area_type) sweep in setup_weather_areas()
			// and paint every co-tenant packed onto the level. Stay eligible so the site storms as
			// soon as its ground exists, rather than burning this roll and a cooldown
			// on a storm that can only land in the wrong place.
			eligible_sites |= site
			continue
		if(site.has_active_weather())
			// This site's own storm is still winding down. Nothing else on the level blocks it.
			eligible_sites |= site
			continue
		var/datum/weather/weather_event_type = pick_weight(site.weather_types)
		var/datum/weather/weather_event = run_weather(weather_event_type, list(site.z_value), null, site)
		site.active_weather = weather_event
		if(weather_event.weather_flags & WEATHER_ENDLESS)
			continue
		var/downtime = site.roll_downtime()
		var/time_until_next_storm = weather_event.telegraph_duration + weather_event.weather_duration + weather_event.end_duration + downtime
		site.clear_next_hit()
		site.next_hit_time = world.time + time_until_next_storm
		site.next_hit_timer = addtimer(CALLBACK(src, PROC_REF(make_site_eligible), site), time_until_next_storm, TIMER_STOPPABLE)
	// VOIDCREW EDIT REPLACEMENT END

/datum/controller/subsystem/weather/Initialize()
	// VOIDCREW EDIT REPLACEMENT START - roundstart levels register one whole-level
	// /datum/weather_site each instead of an entry in a "[z]"-keyed weight map.
	var/list/weights_by_z = list()
	for(var/V in subtypesof(/datum/weather))
		var/datum/weather/W = V
		var/probability = initial(W.probability)
		var/target_trait = initial(W.target_trait)

		// any weather with a probability set may occur at random
		if (probability)
			for(var/z in SSmapping.levels_by_trait(target_trait))
				LAZYINITLIST(weights_by_z["[z]"])
				weights_by_z["[z]"][W] = probability
	for(var/z_key in weights_by_z)
		register_level_weather_site(text2num(z_key), weights_by_z[z_key])
	// VOIDCREW EDIT REPLACEMENT END
	return SS_INIT_SUCCESS

// VOIDCREW EDIT ADDITION START - weather site registry.
/datum/controller/subsystem/weather/proc/update_z_level(datum/space_level/level)
	// VOIDCREW EDIT REPLACEMENT START - drives the level-wide site instead of the "[z]" maps.
	var/z = level.z_value
	var/list/possible_weather = weather_weights_for_traits(level.traits)

	if(!length(possible_weather))
		// Only the level's own site goes; anything footprinted on this level is somebody
		// else's and keeps its climate.
		unregister_weather_site(get_level_weather_site(z))
		return

	register_level_weather_site(z, possible_weather)
	// VOIDCREW EDIT REPLACEMENT END

/datum/controller/subsystem/weather/proc/run_weather(datum/weather/weather_datum_type, z_levels, list/weather_data, datum/weather_site/site) // VOIDCREW EDIT - trailing `site` arg lets a site hand its own area instances to the storm
	if (istext(weather_datum_type))
		for (var/V in subtypesof(/datum/weather))
			var/datum/weather/W = V
			if (initial(W.name) == weather_datum_type)
				weather_datum_type = V
				break
	if (!ispath(weather_datum_type, /datum/weather))
		CRASH("run_weather called with invalid weather_datum_type: [weather_datum_type || "null"]")

	if (isnull(z_levels))
		z_levels = SSmapping.levels_by_trait(initial(weather_datum_type.target_trait))
	else if (isnum(z_levels))
		z_levels = list(z_levels)
	else if (!islist(z_levels))
		CRASH("run_weather called with invalid z_levels: [z_levels || "null"]")


	var/datum/weather/W = new weather_datum_type(z_levels, weather_data, site) // VOIDCREW EDIT - pass the scheduling site through
	W.telegraph()
	return W

// VOIDCREW EDIT ADDITION START - the cooldown callback is per site now.
/// VOIDCREW EDIT: kept for z-level-minded callers; addresses the level's own site.
/datum/controller/subsystem/weather/proc/make_eligible(z)
	make_site_eligible(get_level_weather_site(z))

///Returns an active storm by its type
/datum/controller/subsystem/weather/proc/get_weather_by_type(type)
	return locate(type) in processing
