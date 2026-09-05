/**
 * # Zone-scaled planet weather
 *
 * Planets in dangerous overmap zones get harsher weather: storms are scheduled
 * more often (see the VOIDCREW EDIT in code/controllers/subsystem/weather.dm),
 * give less warning before they hit, and last longer once they do.
 *
 * Severity is applied through the COMSIG_WEATHER_TELEGRAPH global signal, which
 * every /datum/weather sends at the very top of telegraph(), before it rolls
 * its duration or arms the start timer, so mutating the storm instance there
 * is race-free. Each storm instance is one-shot, so the multipliers never stack.
 *
 * Zone resolution: the storm's weather site names the rectangle it falls on, and a live
 * overmap lookup on a turf inside that rectangle names the planet; failing that, the zone
 * band SSmapping dealt the roundstart planet pairs before their terrain generated. Nothing
 * here assumes a z-level is one place. Tuning knobs live in
 * voidcrew/_DEFINES/overmap_zones.dm (ZONE_WEATHER_*).
 */

/// Registers for every weather type's telegraph signal. Called once from SSovermap_zones init.
/datum/controller/subsystem/overmap_zones/proc/setup_weather_scaling()
	for(var/datum/weather/weather_type as anything in subtypesof(/datum/weather))
		RegisterSignal(SSdcs, COMSIG_WEATHER_TELEGRAPH(weather_type), PROC_REF(on_weather_telegraph))

/**
 * Resolves the zone type for a turf. Tries the live overmap lookup first
 * (loaded planet/outpost/ruin interiors), then the static roundstart planet
 * band assignment. Null when the turf can't be tied to the overmap.
 */
/datum/controller/subsystem/overmap_zones/proc/zone_type_for_turf(turf/checked_turf)
	if(!checked_turf)
		return null
	var/zone_type = get_zone_type_anywhere(checked_turf)
	if(!isnull(zone_type))
		return zone_type
	return SSmapping.get_planet_zone_band_for_turf(checked_turf)

/**
 * Zone type for a weather site: the danger band of the place its storms fall on.
 *
 * A site is either a rectangle on a level or the whole level (see /datum/weather_site), and
 * either way its centre is a turf inside it - so this is exact for a packed planet rather
 * than "whichever tenant the corner of the z belongs to".
 */
/datum/controller/subsystem/overmap_zones/proc/zone_type_for_weather_site(datum/weather_site/site)
	if(isnull(site) || !site.z_value)
		return null
	var/probe_x = site.has_footprint() ? round((site.low_x + site.high_x) / 2) : round(world.maxx / 2)
	var/probe_y = site.has_footprint() ? round((site.low_y + site.high_y) / 2) : round(world.maxy / 2)
	return zone_type_for_turf(locate(probe_x, probe_y, site.z_value))

/**
 * Zone type for a running storm.
 *
 * A scheduled storm knows the site it came from, and the site knows where it falls; that is
 * the answer whenever there is one. Storms with no site - admin weather, station traits,
 * wizard rain - have nothing but their z-levels, so they get the level probe.
 */
/datum/controller/subsystem/overmap_zones/proc/zone_type_for_storm(datum/weather/storm)
	if(!istype(storm))
		return null
	if(storm.weather_site)
		return zone_type_for_weather_site(storm.weather_site)
	if(!islist(storm.impacted_z_levels) || !length(storm.impacted_z_levels))
		return null
	return zone_type_for_z_level(storm.impacted_z_levels[1])

/**
 * DEPRECATED z-taking wrapper around zone_type_for_turf(). Pass a turf, a weather site or a
 * storm instead.
 *
 * Probes the CENTRE of the level rather than (1, 1). The corner is cordon - outside every
 * tenant's footprint, so it resolves to nobody - while the centre is inside the footprint of
 * any whole-level tenant, which is every planet today. On a packed level the centre lands in
 * the gutter and this answers null, i.e. stock weather, which is the safe direction.
 */
/datum/controller/subsystem/overmap_zones/proc/zone_type_for_z_level(z)
	if(!z)
		return null
	var/turf/probe = locate(round(world.maxx / 2), round(world.maxy / 2), z)
	var/zone_type = probe ? zone_type_for_turf(probe) : null
	if(!isnull(zone_type))
		return zone_type
	return SSmapping.get_planet_zone_band_for_z(z)

/**
 * Rolls the downtime between scheduled storms for a z-level.
 * Called from SSweather's scheduler (marked VOIDCREW EDIT); the ZONE_* defines
 * aren't visible that early in the include order, so the logic lives here.
 *
 * Prefer weather_downtime_for_site() for sites on packed levels. Planets store their own
 * band at registration and call weather_downtime_for_zone() directly.
 */
/datum/controller/subsystem/overmap_zones/proc/weather_downtime_for_z(z)
	return weather_downtime_for_zone(zone_type_for_z_level(z))

/// Rolls downtime using the zone of the site's own rectangle.
/datum/controller/subsystem/overmap_zones/proc/weather_downtime_for_site(datum/weather_site/site)
	return weather_downtime_for_zone(zone_type_for_weather_site(site))

/**
 * Rolls downtime from an explicit range for the zone type.
 *
 * Each scheduled storm gets a new roll. Non-overmap weather keeps the stock 5-10 minutes.
 */
/datum/controller/subsystem/overmap_zones/proc/weather_downtime_for_zone(zone_type)
	switch(zone_type)
		if(ZONE_GREEN)
			return rand(ZONE_WEATHER_DOWNTIME_MIN_GREEN, ZONE_WEATHER_DOWNTIME_MAX_GREEN)
		if(ZONE_YELLOW)
			return rand(ZONE_WEATHER_DOWNTIME_MIN_YELLOW, ZONE_WEATHER_DOWNTIME_MAX_YELLOW)
		if(ZONE_RED)
			return rand(ZONE_WEATHER_DOWNTIME_MIN_RED, ZONE_WEATHER_DOWNTIME_MAX_RED)
	return rand(5 MINUTES, 10 MINUTES)

/**
 * Telegraph hook: scales a starting storm's warning time and duration by the
 * zone of the place it's hitting. Green (and unresolvable) zones keep stock
 * behavior.
 *
 * Resolved from the storm's weather site, not its z-level: a packed level can carry a
 * green-band planet next to a red-band one, and a level probe would hand one of them the
 * other's storm severity.
 */
/datum/controller/subsystem/overmap_zones/proc/on_weather_telegraph(datum/source, datum/weather/storm)
	SIGNAL_HANDLER
	if(!istype(storm))
		return
	switch(zone_type_for_storm(storm))
		if(ZONE_YELLOW)
			storm.telegraph_duration *= ZONE_WEATHER_TELEGRAPH_MULT_YELLOW
			storm.weather_duration_lower *= ZONE_WEATHER_DURATION_MULT_YELLOW
			storm.weather_duration_upper *= ZONE_WEATHER_DURATION_MULT_YELLOW
		if(ZONE_RED)
			storm.telegraph_duration *= ZONE_WEATHER_TELEGRAPH_MULT_RED
			storm.weather_duration_lower *= ZONE_WEATHER_DURATION_MULT_RED
			storm.weather_duration_upper *= ZONE_WEATHER_DURATION_MULT_RED
