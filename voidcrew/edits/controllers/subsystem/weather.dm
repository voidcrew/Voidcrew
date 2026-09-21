// Voidcrew extensions to code/controllers/subsystem/weather.dm.

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
	for(var/datum/weather/weather as anything in subtypesof(/datum/weather))
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
	for(var/datum/weather/weather as anything in subtypesof(/datum/weather))
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
/datum/controller/subsystem/weather/proc/register_level_weather_site(z, list/possible_weather, zone_band, site_id)
	var/datum/weather_site/site = get_level_weather_site(z)
	if(site)
		site.set_weather_types(possible_weather)
		// Only an explicit value overwrites; a bare refresh must not throw away the zone band
		// the site was registered with.
		if(!isnull(zone_band))
			site.zone_band = zone_band
		if(!(site in eligible_sites) && !site.next_hit_timer && !site.has_active_weather() && length(possible_weather))
			eligible_sites |= site
		return site
	site = new /datum/weather_site(site_id || "level-[z]", z, possible_weather, zone_band)
	return register_weather_site(site)

/**
 * Registers a whole-level site whose climate comes from an explicit trait set rather than
 * from the level's trait dict.
 *
 * Planets use this: their weather has to be describable without the level's trait dict
 * being the single source of truth, since a level may eventually hold more than one of them.
 */
/datum/controller/subsystem/weather/proc/register_weather_site_for_level(datum/space_level/level, list/weather_traits, zone_band, site_id)
	if(isnull(level))
		return null
	var/list/possible_weather = weather_weights_for_traits(weather_traits)
	if(!length(possible_weather))
		return null
	return register_level_weather_site(level.z_value, possible_weather, zone_band, site_id)
// VOIDCREW EDIT ADDITION END

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

/// Returns TRUE while any weather stage still occupies a z-level.
/// VOIDCREW EDIT: no longer gates random scheduling - fire() asks the site whether ITS storm
/// is still running, so two sites on one level can storm at once. Kept for outside callers.
/datum/controller/subsystem/weather/proc/is_weather_active_on_z(z)
	for(var/datum/weather/weather_event as anything in processing)
		if(weather_event.stage != END_STAGE && islist(weather_event.impacted_z_levels) && (z in weather_event.impacted_z_levels))
			return TRUE
	return FALSE

// VOIDCREW EDIT REMOVAL: get_weather(z, active_area) deleted. It matched a storm by
// z-level plus area TYPE, which on a packed level answers with a co-tenant's storm - every
// voidcrew planet storm shares area_type = /area/overmap_encounter/planetoid. It had zero
// callers in the tree, so it was a trap rather than a bug. Anything that needs this should
// resolve the site's own /datum/weather_site and read active_weather off it.

/datum/controller/subsystem/weather
	/// Snapshot of active weather being processed in the current fire. The event at
	/// the end remains there until all of its tasks finish, including across resumes.
	var/list/currentrun = list()
	/// Every registered weather site, in registration order.
	var/list/datum/weather_site/weather_sites = list()
	/// "[z]" -> list of /datum/weather_site on that level, for turf and level lookups.
	var/list/weather_sites_by_zlevel = list()
	/// Sites allowed to roll a new random storm on the next fire.
	var/list/datum/weather_site/eligible_sites = list()
	/// z ("[z]") -> list of living mobs, rebuilt at most once per fire cycle so several
	/// concurrent storms share one scan of the global mob list instead of one scan each
	var/list/mobs_by_z_cache
	/// The times_fired value mobs_by_z_cache was built on
	var/mobs_by_z_cache_fire = -1
