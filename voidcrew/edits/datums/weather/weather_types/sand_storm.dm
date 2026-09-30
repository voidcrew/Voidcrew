// Voidcrew extensions to code/datums/weather/weather_types/sand_storm.dm.

/datum/weather/sand_storm/end()
	GLOB.sand_storm_sounds -= weak_sounds
	GLOB.sand_storm_sounds -= strong_sounds
	return ..()

/datum/weather/sand_storm
	var/list/weak_sounds = list()
	var/list/strong_sounds = list()
