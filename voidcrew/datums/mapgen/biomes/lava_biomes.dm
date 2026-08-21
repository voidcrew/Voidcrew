/datum/biome/lavaland
	open_turf_types = list(/turf/open/misc/asteroid/planetary_basalt/lava_land_surface = 1)
	// flora_spawn_chance = 10
	// flora_spawn_list = list(
	// 	/obj/structure/flora/ausbushes/sparsegrass/hell = 100,
	// 	/obj/structure/flora/ash/whitesands/fireblossom = 1,
	// )
	feature_spawn_chance = 3
	feature_spawn_list = list(
		/obj/structure/flora/rock/hell = 100,
		/obj/structure/ladder/cave = 5,
		/obj/structure/elite_tumor = 1,
		/obj/structure/geyser/random = 5,
	)
	mob_spawn_chance = 3
	mob_spawn_list = list(
		SPAWN_MEGAFAUNA = 1,
		/obj/effect/spawner/random/lavaland_mob = 50,
		/obj/structure/spawner/planetary = 1,
		/obj/structure/spawner/planetary/legion = 1,
		/obj/structure/spawner/planetary/goliath = 1,
	)
	// Meaner tier for dangerous-zone planets: nests instead of lone mobs
	// (megafauna rolls are exempt from the upgrade (see dangerous_mob_spawn_list))
	dangerous_mob_spawn_list = list(
		/obj/structure/spawner/planetary = 1,
		/obj/structure/spawner/planetary/legion = 1,
		/obj/structure/spawner/planetary/goliath = 1,
	)
	megafauna_spawn_list = list(
		/mob/living/simple_animal/hostile/megafauna/bubblegum = 1,
		/mob/living/simple_animal/hostile/megafauna/colossus = 1
	)

/datum/biome/cave/lavaland
	open_turf_types = list(/turf/open/misc/asteroid/planetary_basalt/lava_land_surface = 1)
	closed_turf_types = list(/turf/closed/mineral/random/volcanic/voidcrew = 10, /turf/closed/mineral/random/high_chance/volcanic/voidcrew = 1)
	mob_spawn_chance = 3
	mob_spawn_list = list(
		/obj/effect/spawner/random/lavaland_mob = 40,
		/obj/structure/spawner/planetary = 5,
		/obj/structure/spawner/planetary/legion = 5,
		/obj/structure/spawner/planetary/goliath = 5,
	)
	dangerous_mob_spawn_list = list(
		/obj/structure/spawner/planetary = 1,
		/obj/structure/spawner/planetary/legion = 1,
		/obj/structure/spawner/planetary/goliath = 1,
	)
	feature_spawn_list = list(
		/obj/structure/flora/rock/hell = 70,
		/obj/structure/elite_tumor = 1,
		/obj/structure/ladder/cave = 15,
		/obj/structure/geyser/random = 7,
	)
	feature_spawn_chance = 2
	// flora_spawn_chance = 5
	// flora_spawn_list = list(
	// 	/obj/structure/flora/ausbushes/ywflowers/hell = 1,
	// 	/obj/structure/flora/ausbushes/sparsegrass/hell = 4,
	// )
