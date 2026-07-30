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
