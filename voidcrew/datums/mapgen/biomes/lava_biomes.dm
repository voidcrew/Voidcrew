/datum/biome/lavaland
	open_turf_types = list(/turf/open/misc/asteroid/basalt/lava_land_surface = 1)
	flora_spawn_chance = 10
	flora_spawn_list = list(
		/obj/structure/flora/ausbushes/ywflowers/hell = 10,
		/obj/structure/flora/ausbushes/sparsegrass/hell = 40,
		/obj/structure/flora/ash/whitesands/fern = 5,
		/obj/structure/flora/ash/whitesands/fireblossom = 1,
		/obj/structure/flora/ash/whitesands/puce = 5
	)
	feature_spawn_chance = 5
	feature_spawn_list = list(
		/obj/structure/flora/rock/hell = 15,
		/obj/structure/elite_tumor = 1,
		/obj/structure/geyser/random = 1,
	)
	mob_spawn_chance = 5
	mob_spawn_list = list(
		SPAWN_MEGAFAUNA = 1,
		/obj/effect/spawner/random/lavaland_mob = 40,
		/obj/structure/spawner/lavaland = 5,
		/obj/structure/spawner/lavaland/legion = 5,
		/obj/structure/spawner/lavaland/goliath = 5,
	)
	megafauna_spawn_list = list(
		/mob/living/simple_animal/hostile/megafauna/bubblegum = 1,
		/mob/living/simple_animal/hostile/megafauna/colossus = 1
	)

/datum/biome/cave/lavaland
	open_turf_types = list(/turf/open/misc/asteroid/purple = 1)
	closed_turf_types = list(/turf/closed/mineral/random/volcanic = 10, /turf/closed/mineral/random/high_chance/volcanic = 1)
	mob_spawn_chance = 3
	mob_spawn_list = list(
		/obj/effect/spawner/random/lavaland_mob = 1,
	)
	feature_spawn_list = list(
		/obj/structure/spawner/lavaland/goliath = 1,
		/obj/structure/spawner/lavaland = 1,
		/obj/structure/spawner/lavaland/legion = 1
	)
	feature_spawn_chance = 0.5
	flora_spawn_chance = 5
	flora_spawn_list = list(
		/obj/structure/flora/ausbushes/ywflowers/hell/cave = 1,
		/obj/structure/flora/ausbushes/sparsegrass/hell/cave = 4,
	)
