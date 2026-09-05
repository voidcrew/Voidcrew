/**
 * # Weather site
 *
 * One independently-scheduled patch of weather: its own climate (weight table), its own
 * storm, its own cooldown.
 *
 * Upstream SSweather keys everything by z-level - one climate, one storm and one cooldown
 * per z. That is fine while a z-level holds exactly one place, and wrong the moment two
 * planets share a level: the second planet's registration tears down the first one's
 * climate and any storm running on it, and a single weight table means ash storms roll
 * onto the ice planet.
 *
 * The storm datum itself was never really z-scoped - `impacted_areas` is a list of area
 * *instances*, the per-mob hot path is `impacted_areas_lookup[mob_turf.loc]`, turf picks
 * weight by area instance, and overlays are painted on area instances. Since voidcrew
 * planet areas are per-planet instances (`/area/overmap_encounter` drops UNIQUE_AREA), an
 * area-scoped storm on a shared z already only touches its own planet. All the z-coupling
 * lived in the scheduler, and this datum is what replaces it.
 *
 * A site covers either a whole z-level (`low_x` and friends null, which is every site
 * today) or a rectangle on one. `add_footprint_rect()` is the attachment point for the
 * planet-packing work: hand it the bounds of a packed planet's footprint and the site
 * stops being the level's site and starts being that planet's.
 *
 * `owned_areas` is the authoritative list when set - a site-launched storm is handed those
 * area instances directly and skips `get_areas(area_type)` entirely. Left null, the storm
 * falls back to the z-wide sweep, which is exactly today's behaviour.
 */
/datum/weather_site
	/// Identifier for this site, for logging and for finding it again. Not enforced unique.
	var/id
	/// The z-level this site sits on. A site never spans levels.
	var/z_value = 0
	/// Footprint bounds within the level. All four null means "the whole z-level".
	var/low_x
	var/low_y
	var/high_x
	var/high_y
	/**
	 * The area INSTANCES this site owns, handed to every storm it launches.
	 *
	 * Null (the default) means the site has no area scoping of its own and its storms fall
	 * back to the z-wide `get_areas(area_type)` walk in setup_weather_areas().
	 */
	var/list/owned_areas
	/**
	 * TRUE when this site's storms MUST stay inside `owned_areas`, i.e. the z-wide fallback
	 * in setup_weather_areas() is not allowed to answer for it.
	 *
	 * A tenant's site exists before its areas do. A planet registers its site in
	 * apply_planet_level_traits(), and the surface area it owns is not created until
	 * fill_in() returns - a tick-yielding walk of ~15k turfs, minutes later. SSweather fires
	 * every second and a site is eligible the moment it is registered, so a storm rolled
	 * inside that window found `owned_areas` empty, fell back to
	 * get_areas(/area/overmap_encounter/planetoid) and painted - and burned - every OTHER
	 * planet packed onto the level. That is how a lava co-tenant's ash storm landed on a
	 * jungle planet, with no telegraph, because can_get_alert() filters on the site rect and
	 * can_weather_act_mob() does not.
	 *
	 * Sites that legitimately cover a whole level and describe themselves by area TYPE
	 * (roundstart levels, flat encounters, admin weather) leave this FALSE and keep the sweep.
	 */
	var/area_scoped = FALSE
	/// Random-weather weight table: weather typepath -> probability.
	var/list/weather_types
	/// TIMER_STOPPABLE id of the pending cooldown callback, if a storm is on cooldown here.
	var/next_hit_timer
	/// world.time the next scheduled storm is expected to telegraph. 0 when nothing is armed.
	var/next_hit_time = 0
	/// The randomly-scheduled storm this site currently owns, including its wind-down.
	var/datum/weather/active_weather
	/**
	 * Overmap zone band used to choose the downtime between this site's storms.
	 *
	 * Null means "ask the overmap zone layer", which is what the z-keyed scheduler did
	 * inline. Planets pass their own band in so packed neighbours keep independent timing.
	 */
	var/zone_band = null

/datum/weather_site/New(id, z_value, list/weather_types, zone_band)
	. = ..()
	src.id = id
	src.z_value = z_value
	src.weather_types = weather_types ? weather_types.Copy() : list()
	src.zone_band = zone_band

/datum/weather_site/Destroy(force)
	clear_next_hit()
	// Not a bare `active_weather = null`: a site deleted out from under a running storm used
	// to orphan it, leaving the storm processing and its overlays painted on areas that are
	// on their way out. end_active_weather() ends it properly and drops both references.
	end_active_weather()
	owned_areas = null
	weather_types = null
	return ..()

/**
 * Confines this site to a rectangle on its z-level.
 *
 * This is the hook the planet-packing build attaches a footprint to. Deliberately plain
 * numbers rather than a footprint datum, so the scheduler carries no dependency on how
 * footprints are allocated. A site with a rect is no longer the level's site, so the
 * z-level-keyed legacy entry points (update_z_level, make_eligible) stop addressing it.
 */
/datum/weather_site/proc/add_footprint_rect(new_low_x, new_low_y, new_high_x, new_high_y)
	low_x = new_low_x
	low_y = new_low_y
	high_x = new_high_x
	high_y = new_high_y
	return src

/// Drops the rect, putting the site back to covering its whole z-level.
/datum/weather_site/proc/clear_footprint_rect()
	low_x = null
	low_y = null
	high_x = null
	high_y = null
	return src

/// TRUE when this site is confined to a rectangle rather than covering its whole level.
/datum/weather_site/proc/has_footprint()
	return !isnull(low_x) && !isnull(low_y) && !isnull(high_x) && !isnull(high_y)

/// TRUE when the given coordinates fall inside this site.
/datum/weather_site/proc/contains_coords(x, y, z)
	if(z != z_value)
		return FALSE
	if(!has_footprint())
		return TRUE
	return (x >= low_x) && (x <= high_x) && (y >= low_y) && (y <= high_y)

/// TRUE when the given turf falls inside this site.
/datum/weather_site/proc/contains_turf(turf/checked)
	if(isnull(checked))
		return FALSE
	return contains_coords(checked.x, checked.y, checked.z)

/**
 * Sets the area instances this site owns. Pass null to clear the list, which puts the
 * site's storms back on the z-wide get_areas() fallback.
 */
/datum/weather_site/proc/set_owned_areas(list/new_areas)
	owned_areas = length(new_areas) ? new_areas.Copy() : null
	return src

/// Adds a single area instance to the site's owned list.
/datum/weather_site/proc/add_owned_area(area/new_area)
	if(isnull(new_area))
		return src
	LAZYINITLIST(owned_areas)
	owned_areas |= new_area
	return src

/**
 * The area instances a storm launched from this site should impact, or null when the
 * site has no area scoping and the storm should fall back to get_areas(area_type).
 */
/datum/weather_site/proc/get_weather_areas()
	if(!length(owned_areas))
		return null
	// Areas can be deleted out from under a site (a shuttle leaving, a ruin torn down).
	var/list/live_areas = list()
	for(var/area/owned as anything in owned_areas)
		if(!QDELETED(owned))
			live_areas += owned
	return length(live_areas) ? live_areas : null

/**
 * Marks this site as one whose storms are confined to the areas it owns.
 *
 * Set by the tenant that registers the site, not inferred from `owned_areas` - the whole
 * point is to describe a site that does not have its areas YET.
 */
/datum/weather_site/proc/set_area_scoped(scoped = TRUE)
	area_scoped = scoped
	return src

/// TRUE while an area-scoped site is still waiting for the areas its storms would fall on.
/// A site in this state is registered and armed but has nothing to storm on yet.
/datum/weather_site/proc/awaiting_owned_areas()
	return area_scoped && !length(get_weather_areas())

/// Replaces the site's random-weather weight table.
/datum/weather_site/proc/set_weather_types(list/new_types)
	weather_types = length(new_types) ? new_types.Copy() : list()
	return src

/// TRUE while any stage of this site's own storm is still running.
/datum/weather_site/proc/has_active_weather()
	return !isnull(active_weather) && !QDELETED(active_weather) && active_weather.stage != END_STAGE

/// Cancels the pending cooldown callback, if any.
/datum/weather_site/proc/clear_next_hit()
	if(next_hit_timer)
		deltimer(next_hit_timer)
	next_hit_timer = null
	next_hit_time = 0

/// Ends this site's storm, if it has one running, and drops the reference either way.
/datum/weather_site/proc/end_active_weather()
	var/datum/weather/ending = active_weather
	active_weather = null
	if(isnull(ending) || QDELETED(ending))
		return
	if(ending.weather_site == src)
		ending.weather_site = null
	if(ending.stage != END_STAGE)
		// end() schedules its own deletion, which is what releases the storm's impacted_areas.
		ending.end()
		return
	// Already finished, but nobody has freed it yet - it can still be sitting on the site
	// between its end() and the tick its scheduled deletion lands on. Delete it now so the
	// area instances it impacted go with the site rather than outliving it.
	qdel(ending)

/**
 * Rolls a fresh downtime between this site's storms.
 *
 * A zone band set at registration wins. Otherwise use the existing level lookup.
 * Sites outside the overmap keep the stock weather downtime.
 */
/datum/weather_site/proc/roll_downtime()
	if(!isnull(zone_band))
		return SSovermap_zones.weather_downtime_for_zone(zone_band)
	return SSovermap_zones.weather_downtime_for_z(z_value)
