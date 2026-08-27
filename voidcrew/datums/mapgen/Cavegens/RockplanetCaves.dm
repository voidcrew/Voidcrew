/turf/closed/mineral/random/asteroid/rockplanet
	name = "iron rock"
	// Upstream's Yapmining rework (#95682) renamed the sprite: mining.dmi's
	// "redrock" is now "red_rock", and the smoothing sheet red_wall.dmi is now
	// red_rock.dmi. Mirrors /turf/closed/mineral/random/stationside/asteroid.
	icon = MAP_SWITCH('icons/turf/walls/red_rock.dmi', 'icons/turf/mining.dmi')
	icon_state = "red_rock"
	base_icon_state = "red_rock"
	transform = MAP_SWITCH(TRANSLATE_MATRIX(-8, -8), matrix())
	smoothing_groups = SMOOTH_GROUP_CLOSED_TURFS + SMOOTH_GROUP_RED_ROCK_WALLS
	canSmoothWith = SMOOTH_GROUP_RED_ROCK_WALLS
	wall_icon_state = "red_rock"
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	baseturfs = /turf/open/misc/asteroid/rockplanet
	turf_type = /turf/open/misc/asteroid/rockplanet
	//mineralSpawnChanceList = list(/obj/item/stack/ore/uranium = 7, /obj/item/stack/ore/diamond = 1, /obj/item/stack/ore/gold = 5,
	//	/obj/item/stack/ore/silver = 7, /obj/item/stack/ore/plasma = 15, /obj/item/stack/ore/iron = 55, /obj/item/stack/ore/titanium = 6,
	//	/turf/closed/mineral/gibtonite/rockplanet = 4, /obj/item/stack/ore/bluespace_crystal = 1)
	mineral_chance = 30

/turf/closed/mineral/gibtonite/rockplanet
	name = "iron rock"
	// See the comment on /turf/closed/mineral/random/asteroid/rockplanet above.
	// Mirrors /turf/closed/mineral/gibtonite/volcanic/red_rock.
	icon = MAP_SWITCH('icons/turf/walls/red_rock.dmi', 'icons/turf/mining.dmi')
	icon_state = "red_rock"
	base_icon_state = "red_rock"
	transform = MAP_SWITCH(TRANSLATE_MATRIX(-8, -8), matrix())
	smoothing_groups = SMOOTH_GROUP_CLOSED_TURFS + SMOOTH_GROUP_RED_ROCK_WALLS
	canSmoothWith = SMOOTH_GROUP_RED_ROCK_WALLS
	wall_icon_state = "red_rock"
	baseturfs = /turf/open/misc/asteroid/rockplanet
	turf_type = /turf/open/misc/asteroid/rockplanet

/turf/open/misc/asteroid/rockplanet
	name = "rockplanet sand"
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/rockplanet

/turf/open/floor/plating/rockplanet
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/rockplanet

/turf/open/floor/plating/rust/rockplanet
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/rockplanet
