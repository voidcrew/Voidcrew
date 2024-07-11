/datum/biome/debug
	open_turf_types = list(/turf/open/misc/debug = 1)

/datum/biome/cave/debug
	open_turf_types = list(/turf/open/misc/debug = 1)
	closed_turf_types = list(/turf/closed/mineral/random/debug = 1)

/turf/closed/mineral/random/debug
	baseturfs = /turf/open/misc/debug

/turf/open/misc/debug
	gender = PLURAL
	name = "dirt"
	desc = "Upon closer examination, it's still dirt."
	icon = 'icons/turf/floors.dmi'
	icon_state = "dirt"
	base_icon_state = "dirt"
	baseturfs = /turf/open/misc/debug
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	planetary_atmos = TRUE
	light_range = 2
	light_power = 0.80
