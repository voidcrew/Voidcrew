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
	// VOIDCREW EDIT REMOVAL START - the four "[z]"-keyed scheduler maps (eligible_zlevels,
	// weather_types_by_zlevel, next_hit_by_zlevel, random_weather_by_zlevel) are replaced by
	// the /datum/weather_site registry below, so several places can share a z-level and each
	// keep its own climate, storm and cooldown. See voidcrew/datums/weather_site.dm.
	/// Every registered weather site, in registration order.
	var/list/datum/weather_site/weather_sites = list()
	/// "[z]" -> list of /datum/weather_site on that level, for turf and level lookups.
	var/list/weather_sites_by_zlevel = list()
	/// Sites allowed to roll a new random storm on the next fire.
	var/list/datum/weather_site/eligible_sites = list()
	// VOIDCREW EDIT REMOVAL END
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
			// soon as its ground exists, rather than burning this roll and a 5-10 minute cooldown
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
		var/randTime = rand(5 MINUTES, 10 MINUTES)
		randTime *= site.get_downtime_multiplier() // Storms come more often on planets in dangerous overmap zones
		var/time_until_next_storm = weather_event.telegraph_duration + weather_event.weather_duration + weather_event.end_duration + randTime
		site.clear_next_hit()
		site.next_hit_time = world.time + time_until_next_storm
		site.next_hit_timer = addtimer(CALLBACK(src, PROC_REF(make_site_eligible), site), time_until_next_storm, TIMER_STOPPABLE)
	// VOIDCREW EDIT REPLACEMENT END

/datum/controller/subsystem/weather/Initialize()
	// VOIDCREW EDIT REPLACEMENT START - roundstart levels register one whole-level
	// /datum/weather_site each instead of an entry in a "[z]"-keyed weight map.
	var/list/weights_by_z = list()
	for(var/V in valid_subtypesof(/datum/weather))
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

// VOIDCREW EDIT ADDITION START - weather site registry.
/**
 * Builds the random-weather weight table (weather typepath -> probability) implied by a set
 * of z-level traits.
 *
 * This is the calculation Initialize() and update_z_level() used to each write out inline.
 * Registration paths that do not want to route a climate through the level's trait dict at
 * all (planets, which need to describe their own weather without fighting a co-tenant over
 * the level) call this with a trait list they assembled themselves.
 *
 * `level_traits` is an assoc list, trait -> value, i.e. the same shape as /datum/space_level.traits.
 */
/datum/controller/subsystem/weather/proc/weather_weights_for_traits(list/level_traits)
	var/list/possible_weather = list()
	if(!length(level_traits))
		return possible_weather
	for(var/datum/weather/weather as anything in valid_subtypesof(/datum/weather))
		var/probability = initial(weather.probability)
		if(!probability)
			continue
		var/target_trait = initial(weather.target_trait)
		if(target_trait && level_traits[target_trait])
			possible_weather[weather] = probability
	return possible_weather

/// Every z-level trait that some weather type can be rolled from.
/datum/controller/subsystem/weather/proc/random_weather_traits()
	var/list/traits = list()
	for(var/datum/weather/weather as anything in valid_subtypesof(/datum/weather))
		if(!initial(weather.probability))
			continue
		var/target_trait = initial(weather.target_trait)
		if(target_trait)
			traits |= list(target_trait)
	return traits

/// Adds a site to the scheduler. A site with weather in its table is eligible immediately.
/datum/controller/subsystem/weather/proc/register_weather_site(datum/weather_site/site)
	if(!istype(site) || (site in weather_sites))
		return site
	weather_sites += site
	var/z_key = "[site.z_value]"
	var/list/z_sites = weather_sites_by_zlevel[z_key]
	if(!z_sites)
		z_sites = list()
		weather_sites_by_zlevel[z_key] = z_sites
	z_sites |= site
	if(length(site.weather_types))
		eligible_sites |= site
	return site

/**
 * Removes one site from the scheduler, ending its storm and cancelling its cooldown.
 *
 * This is the per-site form of the old unregister_z_level(); nothing else on the site's
 * z-level is disturbed.
 */
/datum/controller/subsystem/weather/proc/unregister_weather_site(datum/weather_site/site)
	if(!istype(site))
		return
	weather_sites -= site
	eligible_sites -= site
	var/z_key = "[site.z_value]"
	var/list/z_sites = weather_sites_by_zlevel[z_key]
	if(z_sites)
		z_sites -= site
		if(!length(z_sites))
			weather_sites_by_zlevel -= z_key
	site.clear_next_hit()
	site.end_active_weather()

/// The site covering a whole z-level, i.e. the one the z-keyed entry points address. Null if none.
/datum/controller/subsystem/weather/proc/get_level_weather_site(z)
	for(var/datum/weather_site/site as anything in weather_sites_by_zlevel["[z]"])
		if(!site.has_footprint())
			return site
	return null

/// Every site registered on a z-level, footprinted or not.
/datum/controller/subsystem/weather/proc/get_weather_sites_on_z(z)
	return weather_sites_by_zlevel["[z]"] || list()

/**
 * The site that owns a set of coordinates.
 *
 * A footprinted site wins over the level-wide one, so a packed planet's own climate beats
 * whatever covers the rest of the level.
 */
/datum/controller/subsystem/weather/proc/get_weather_site_for_coords(x, y, z)
	var/list/z_sites = weather_sites_by_zlevel["[z]"]
	if(!length(z_sites))
		return null
	var/datum/weather_site/level_fallback
	for(var/datum/weather_site/site as anything in z_sites)
		if(!site.has_footprint())
			if(isnull(level_fallback))
				level_fallback = site
			continue
		if(site.contains_coords(x, y, z))
			return site
	return level_fallback

/// The site that owns a turf, or null.
/datum/controller/subsystem/weather/proc/get_weather_site_for_turf(turf/checked)
	if(isnull(checked))
		return null
	return get_weather_site_for_coords(checked.x, checked.y, checked.z)

/// Time until the next scheduled storm where this turf is standing, or null if nothing is armed.
/datum/controller/subsystem/weather/proc/next_hit_timeleft_for_turf(turf/checked)
	var/datum/weather_site/site = get_weather_site_for_turf(checked)
	if(!site?.next_hit_timer)
		return null
	return timeleft(site.next_hit_timer)

/// Time until the soonest scheduled storm anywhere on a z-level, or null if nothing is armed.
/datum/controller/subsystem/weather/proc/next_hit_timeleft_for_z(z)
	var/shortest = null
	for(var/datum/weather_site/site as anything in weather_sites_by_zlevel["[z]"])
		if(!site.next_hit_timer)
			continue
		var/remaining = timeleft(site.next_hit_timer)
		if(isnull(remaining))
			continue
		if(isnull(shortest) || remaining < shortest)
			shortest = remaining
	return shortest

/**
 * Registers (or refreshes) the site covering a whole z-level.
 *
 * Refreshing keeps a running storm and its cooldown intact and only swaps the weight
 * table, which is what update_z_level() has always done.
 */
/datum/controller/subsystem/weather/proc/register_level_weather_site(z, list/possible_weather, downtime_multiplier, site_id)
	var/datum/weather_site/site = get_level_weather_site(z)
	if(site)
		site.set_weather_types(possible_weather)
		// Only an explicit value overwrites; a bare refresh must not throw away a multiplier
		// the site was registered with.
		if(!isnull(downtime_multiplier))
			site.downtime_multiplier = downtime_multiplier
		if(!(site in eligible_sites) && !site.next_hit_timer && !site.has_active_weather() && length(possible_weather))
			eligible_sites |= site
		return site
	site = new /datum/weather_site(site_id || "level-[z]", z, possible_weather, downtime_multiplier)
	return register_weather_site(site)

/**
 * Registers a whole-level site whose climate comes from an explicit trait set rather than
 * from the level's trait dict.
 *
 * Planets use this: their weather has to be describable without the level's trait dict
 * being the single source of truth, since a level may eventually hold more than one of them.
 */
/datum/controller/subsystem/weather/proc/register_weather_site_for_level(datum/space_level/level, list/weather_traits, downtime_multiplier, site_id)
	if(isnull(level))
		return null
	var/list/possible_weather = weather_weights_for_traits(weather_traits)
	if(!length(possible_weather))
		return null
	return register_level_weather_site(level.z_value, possible_weather, downtime_multiplier, site_id)
// VOIDCREW EDIT ADDITION END

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

/// Stops random weather scheduling for a z-level and ends every storm scheduled on it.
/datum/controller/subsystem/weather/proc/unregister_z_level(z)
	// VOIDCREW EDIT REPLACEMENT START - the level is being torn down or recycled, so every
	// site on it goes, not just the level-wide one. Copy(): unregister mutates the index list.
	var/list/z_sites = weather_sites_by_zlevel["[z]"]
	if(!length(z_sites))
		return
	for(var/datum/weather_site/site as anything in z_sites.Copy())
		unregister_weather_site(site)
	// VOIDCREW EDIT REPLACEMENT END

/**
 * Replaces the random-weather trait on a recycled dynamic z-level.
 *
 * VOIDCREW EDIT: kept as a thin wrapper over the site registry for callers that still think
 * in "one climate per level" terms (map zone teardown, flat overmap encounters, mapping
 * helpers). Anything that wants more than one climate on a level registers sites directly.
 */
/datum/controller/subsystem/weather/proc/set_z_level_weather_trait(datum/space_level/level, new_weather_trait)
	var/z = level.z_value
	unregister_z_level(z)

	for(var/weather_trait in random_weather_traits())
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

/datum/controller/subsystem/weather/proc/run_weather(datum/weather/weather_datum_type, z_levels, list/weather_data, datum/weather_site/site) // VOIDCREW EDIT - trailing `site` arg lets a site hand its own area instances to the storm
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

	var/datum/weather/weather = new weather_datum_type(z_levels, weather_data, site) // VOIDCREW EDIT - pass the scheduling site through
	weather.telegraph(weather_data)
	return weather

// VOIDCREW EDIT ADDITION START - the cooldown callback is per site now.
/// Cooldown expiry: the site may roll another storm on the next fire.
/datum/controller/subsystem/weather/proc/make_site_eligible(datum/weather_site/site)
	if(QDELETED(site) || !(site in weather_sites))
		return
	site.next_hit_timer = null
	site.next_hit_time = 0
	// Only let go of a storm that has actually finished. Blanking this while the storm was
	// still running orphaned it - it kept processing and kept holding every area instance in
	// its impacted_areas with nothing left pointing at it - and let the site roll a second,
	// concurrent storm on top of it. A storm that ends normally clears this itself in end(),
	// so by the time the cooldown lands it is usually already null; fire() re-queues a site
	// whose storm is still winding down rather than starting another.
	if(!site.has_active_weather())
		if(site.active_weather?.weather_site == site)
			site.active_weather.weather_site = null
		site.active_weather = null
	if(length(site.weather_types))
		eligible_sites |= site
// VOIDCREW EDIT ADDITION END

/// VOIDCREW EDIT: kept for z-level-minded callers; addresses the level's own site.
/datum/controller/subsystem/weather/proc/make_eligible(z)
	make_site_eligible(get_level_weather_site(z))

/// Returns TRUE while any weather stage still occupies a z-level.
/// VOIDCREW EDIT: no longer gates random scheduling - fire() asks the site whether ITS storm
/// is still running, so two sites on one level can storm at once. Kept for outside callers.
/datum/controller/subsystem/weather/proc/is_weather_active_on_z(z)
	for(var/datum/weather/weather_event as anything in processing)
		if(weather_event.stage != END_STAGE && islist(weather_event.impacted_z_levels) && (z in weather_event.impacted_z_levels))
			return TRUE
	return FALSE
// VOIDCREW EDIT END

// VOIDCREW EDIT REMOVAL: get_weather(z, active_area) deleted. It matched a storm by
// z-level plus area TYPE, which on a packed level answers with a co-tenant's storm - every
// voidcrew planet storm shares area_type = /area/overmap_encounter/planetoid. It had zero
// callers in the tree, so it was a trap rather than a bug. Anything that needs this should
// resolve the site's own /datum/weather_site and read active_weather off it.

///Returns an active storm by its type
/datum/controller/subsystem/weather/proc/get_weather_by_type(type)
	return locate(type) in processing
