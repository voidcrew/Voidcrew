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
 * Zone resolution: live overmap lookup first (planet mapzones own whole
 * z-levels), falling back to the zone band SSmapping dealt the roundstart
 * planet pairs before their terrain generated. Tuning knobs live in
 * voidcrew/_DEFINES/overmap_zones.dm (ZONE_WEATHER_*).
 */

/// Registers for every weather type's telegraph signal. Called once from SSovermap_zones init.
/datum/controller/subsystem/overmap_zones/proc/setup_weather_scaling()
	for(var/datum/weather/weather_type as anything in subtypesof(/datum/weather))
		RegisterSignal(SSdcs, COMSIG_WEATHER_TELEGRAPH(weather_type), PROC_REF(on_weather_telegraph))

/**
 * Resolves the zone type for a z-level. Tries the live overmap lookup first
 * (loaded planet/outpost/ruin interiors), then the static roundstart planet
 * band assignment. Null when the z-level can't be tied to the overmap.
 */
/datum/controller/subsystem/overmap_zones/proc/zone_type_for_z_level(z)
	if(!z)
		return null
	var/zone_type = get_zone_type_anywhere(locate(1, 1, z))
	if(!isnull(zone_type))
		return zone_type
	return SSmapping.get_planet_zone_band_for_z(z)

/**
 * Multiplier on the downtime between scheduled storms for a z-level.
 * Called from SSweather's scheduler (marked VOIDCREW EDIT); the ZONE_* defines
 * aren't visible that early in the include order, so the logic lives here.
 */
/datum/controller/subsystem/overmap_zones/proc/weather_downtime_multiplier_for_z(z)
	switch(zone_type_for_z_level(z))
		if(ZONE_YELLOW)
			return ZONE_WEATHER_DOWNTIME_MULT_YELLOW
		if(ZONE_RED)
			return ZONE_WEATHER_DOWNTIME_MULT_RED
	return 1

/**
 * Telegraph hook: scales a starting storm's warning time and duration by the
 * zone of the z-level it's hitting. Green (and unresolvable) zones keep stock
 * behavior.
 */
/datum/controller/subsystem/overmap_zones/proc/on_weather_telegraph(datum/source, datum/weather/storm)
	SIGNAL_HANDLER
	if(!istype(storm) || !islist(storm.impacted_z_levels) || !length(storm.impacted_z_levels))
		return
	switch(zone_type_for_z_level(storm.impacted_z_levels[1]))
		if(ZONE_YELLOW)
			storm.telegraph_duration *= ZONE_WEATHER_TELEGRAPH_MULT_YELLOW
			storm.weather_duration_lower *= ZONE_WEATHER_DURATION_MULT_YELLOW
			storm.weather_duration_upper *= ZONE_WEATHER_DURATION_MULT_YELLOW
		if(ZONE_RED)
			storm.telegraph_duration *= ZONE_WEATHER_TELEGRAPH_MULT_RED
			storm.weather_duration_lower *= ZONE_WEATHER_DURATION_MULT_RED
			storm.weather_duration_upper *= ZONE_WEATHER_DURATION_MULT_RED
