/// Override planet weather types to scope area_type to planet areas only.
/// Without this, weather uses area_type = /area which matches ALL areas,
/// causing weather overlays to appear on space tiles outside planet bounds.

/datum/weather/ash_storm
	area_type = /area/overmap_encounter/planetoid

/datum/weather/snow_storm
	area_type = /area/overmap_encounter/planetoid

/datum/weather/rain_storm
	area_type = /area/overmap_encounter/planetoid

/datum/weather/sand_storm
	area_type = /area/overmap_encounter/planetoid
