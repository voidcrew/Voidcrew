/**
 * Planet weather is scoped to planet areas.
 *
 * Upstream these all use `area_type = /area`, which matches everything on the z-level.
 * That was harmless when a planet filled its whole z-level, but planets are a bounded
 * region now with cordon and empty space around them - unscoped weather draws its
 * overlays out there too, on tiles that aren't part of the planet at all.
 */

/datum/weather/ash_storm
	area_type = /area/overmap_encounter/planetoid

/datum/weather/snow_storm
	area_type = /area/overmap_encounter/planetoid

/datum/weather/rain_storm
	area_type = /area/overmap_encounter/planetoid

/datum/weather/sand_storm
	area_type = /area/overmap_encounter/planetoid

/**
 * Radiation storm, as weather on red-band planets.
 *
 * This replaces the ship-scoped Radiation Storm dynamic event, which is now admin-only
 * (voidcrew/modules/dynamic_events/events/radiation_storm.dm). The event's whole shape
 * was "shelter in an interior compartment", and a shuttle is a bad place to ask that: on
 * a small hull nearly every compartment borders space, so the correct play was frequently
 * unavailable and the crew simply absorbed it.
 *
 * A planet is where that design works. The storm gets a 40-second telegraph before it does
 * anything, and there are three separate ways to not be caught by it, go underground, go
 * back to the ship, or wear rad-protective clothing. It also arrives on the planet's own
 * weather schedule rather than the event roster, so it is a thing about the place the crew
 * flew to, not a thing that follows them around.
 *
 * Red band only, and only ever on the surface: see apply_planet_level_traits().
 */
/datum/weather/rad_storm/planetary
	name = "radiation front"
	desc = "A front of hard radiation sweeps the surface, mutating anyone caught in the open."

	area_type = /area/overmap_encounter/planetoid
	target_trait = ZTRAIT_RADSTORM
	/// Weighed against the planet's climate storm, which sits at 90. Roughly one storm in
	/// six on a red-band planet is this one; the rest are its ordinary weather.
	probability = 20

	/**
	 * Surface only, unlike the station version.
	 *
	 * Dropping WEATHER_INDOORS makes setup_weather_areas() skip every area with
	 * outdoors = FALSE, which on a planet is the whole cave system, so rock overhead
	 * shelters a crew. Their own hull already does: ship areas are /area/shuttle/voidcrew/...,
	 * which `area_type` never matches to begin with.
	 */
	weather_flags = WEATHER_MOBS

	/// TG's list is fourteen station area types, maintenance, the AI satellite, the brig.
	/// None of them exist out here, and each one costs a get_areas() sweep at setup.
	protected_areas = list()

	telegraph_message = span_danger("Your dosimeter starts clicking steadily. Radiation levels are climbing.")
	weather_message = span_userdanger("<i>Hard radiation washes over the surface! Get underground, or back to the ship!</i>")
	end_message = span_notice("The clicking dies away. Radiation levels are back to normal.")

/// No status displays on a planet to alarm.
/datum/weather/rad_storm/planetary/status_alarm(active)
	return

/**
 * Everything below is /datum/weather/end() verbatim, deliberately.
 *
 * /datum/weather/rad_storm/end() announces to GLOB.player_list, every player in the
 * round, including crews several sectors away who cannot see this planet, and DM has no
 * way to call a grandparent implementation. The base proc is stable bookkeeping (stage,
 * processing list, area refresh, two signals) and the player-facing end_message is sent
 * from wind_down() instead, so nothing is lost by not reaching the parent.
 *
 * If an upstream merge changes /datum/weather/end(), mirror the change here.
 */
/datum/weather/rad_storm/planetary/end()
	if(stage == END_STAGE)
		return
	SEND_GLOBAL_SIGNAL(COMSIG_WEATHER_END(type), src)
	stage = END_STAGE
	SSweather.processing -= src
	update_areas()
	for(var/area/impacted_area as anything in impacted_areas)
		SEND_SIGNAL(impacted_area, COMSIG_WEATHER_ENDED_IN_AREA(type), src)
	// Mirrors the release-and-delete tail of /datum/weather/end(). Without it a planetary
	// radiation front is the one storm type that survives its own ending, holding its site
	// and every area instance it impacted until the round ends.
	if(weather_site?.active_weather == src)
		weather_site.active_weather = null
	weather_site = null
	QDEL_IN(src, 0)
