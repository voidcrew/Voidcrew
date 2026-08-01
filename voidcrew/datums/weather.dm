/**
 * Planet weather is scoped to planet areas.
 *
 * Upstream these all use `area_type = /area`, which matches everything on the z-level.
 * That was harmless when a planet filled its whole z-level, but planets are a bounded
 * region now with cordon and empty space around them - unscoped weather draws its
 * overlays out there too, on tiles that aren't part of the planet at all.
 */

// NOTE: upstream reparented ash_storm and rain_storm under /datum/weather/particle
// (code/datums/weather/particle_weather.dm). snow_storm and sand_storm did NOT move.
// Getting these paths wrong fails silently: DM happily creates the phantom
// /datum/weather/ash_storm type, this file compiles, and the real storm simply never
// gets its area_type scoped.
/datum/weather/particle/ash_storm
	area_type = /area/overmap_encounter/planetoid

/datum/weather/snow_storm
	area_type = /area/overmap_encounter/planetoid

/datum/weather/particle/rain_storm
	area_type = /area/overmap_encounter/planetoid

/datum/weather/sand_storm
	area_type = /area/overmap_encounter/planetoid
