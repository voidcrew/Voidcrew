/datum/weather/sand_storm/end()
	GLOB.sand_storm_sounds -= weak_sounds
	GLOB.sand_storm_sounds -= strong_sounds
	return ..()
