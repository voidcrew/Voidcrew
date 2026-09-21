// Voidcrew extensions to code/datums/weather/weather.dm.

/**
 * VOIDCREW EDIT ADDITION - diagnostic for issue #196 (a lava planet's ash storm painting
 * an ocean planet). Changes nothing about the storm.
 *
 * get_areas() matches by area TYPE, and every packed planet's surface and caves share
 * area_type = /area/overmap_encounter/planetoid - so on a z-level carrying more than one
 * map tenant this sweep can only over-reach, and a storm that takes it paints, telegraphs
 * and burns on all four planets rather than on the one it belongs to. In a live round
 * every planet is packed, so that is the whole of the reported symptom.
 *
 * Nothing in the tree is supposed to reach here on a shared level: scheduled planet storms
 * carry an area-scoped site, and a site-scoped storm with no areas yet is held out of the
 * scheduler entirely (SSweather.fire -> awaiting_owned_areas). An audit of every
 * run_weather() caller, the site registry lifecycle, and three days of prod admin.log
 * found no route that does. So rather than guess at a cause, name the offender in the
 * runtime log the next time it happens - the stack trace is the caller.
 */
/datum/weather/proc/log_packed_level_area_sweep()
	if(!islist(impacted_z_levels))
		return
	for(var/z in impacted_z_levels)
		if(!isnum(z) || z < 1 || z > length(SSmapping.z_list))
			continue
		var/datum/space_level/level = SSmapping.z_list[z]
		if(length(level?.footprints) <= 1)
			continue
		stack_trace("weather [type] fell back to the z-wide get_areas([area_type]) sweep on packed z[z] ([length(level.footprints)] tenants) - it will impact every tenant on that level. Site: [weather_site?.id || "none"]")
		return

/datum/weather
	/// Assoc mirror of impacted_areas (area = TRUE), for cheap membership checks in the per-mob hot path
	var/list/impacted_areas_lookup = list()
	/// The /datum/weather_site that scheduled this storm, if it came from one.
	var/datum/weather_site/weather_site
	/// Area INSTANCES this storm is confined to. Null means the z-wide get_areas(area_type) sweep.
	var/list/scoped_areas
	/// If TRUE, weather_act_turf() only tops up open reagent containers (and waters hydroponics trays when
	/// the reagent is water) instead of running full reagent exposure + washing on every struck turf.
	/// Planet-scale weathers pick hundreds of turfs per second. Full exposure at that rate eats whole ticks.
	var/turf_act_containers_only = FALSE
