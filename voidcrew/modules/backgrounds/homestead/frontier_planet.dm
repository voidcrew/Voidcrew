/// Backgrounds: owned by P6. See data/backgrounds/spec.md.

// The Frontier: the one permanent planet, built at boot on the preloaded path (frontier_world.dm).
// Wasteland ground and weather, prairie-heavy tables, no fallout, no mines and no portals on the
// surface. The caves are the wasteland's.

/datum/planet_environment/frontier
	area_type = /area/overmap_encounter/planetoid/frontier
	baseturf = /turf/open/misc/wasteland
	weather_type = /datum/weather/sand_storm
	weather_trait = ZTRAIT_SANDSTORM

/datum/planet/frontier
	terrain_generator = /datum/map_generator/planet_generator/lava
	environment = /datum/planet_environment/frontier
	ruin_settings = /datum/planet_ruins/wasteland
	// The wasteland's table, with prairie in its fallout and junkyard cells
	overworld_biomes = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/frontier_badlands/plains,
			BIOME_LOW_HUMIDITY = /datum/biome/frontier_badlands/plains,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/frontier_badlands,
			BIOME_HIGH_HUMIDITY = /datum/biome/frontier_badlands,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/frontier_badlands/plains
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/frontier_badlands,
			BIOME_LOW_HUMIDITY = /datum/biome/frontier_badlands,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/frontier_badlands/forest,
			BIOME_HIGH_HUMIDITY = /datum/biome/frontier_badlands/plains,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/frontier_badlands/plains
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/frontier_badlands,
			BIOME_LOW_HUMIDITY = /datum/biome/frontier_badlands,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/frontier_badlands/forest,
			BIOME_HIGH_HUMIDITY = /datum/biome/frontier_badlands/plains,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/frontier_badlands/plains
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/frontier_badlands/plains,
			BIOME_LOW_HUMIDITY = /datum/biome/frontier_badlands/forest,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/frontier_badlands/forest,
			BIOME_HIGH_HUMIDITY = /datum/biome/frontier_badlands/plains,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/frontier_badlands
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/frontier_badlands,
			BIOME_LOW_HUMIDITY = /datum/biome/frontier_badlands/forest,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/frontier_badlands,
			BIOME_HIGH_HUMIDITY = /datum/biome/frontier_badlands/plains,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/frontier_badlands
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/frontier_badlands,
			BIOME_LOW_HUMIDITY = /datum/biome/frontier_badlands/forest,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/frontier_badlands,
			BIOME_HIGH_HUMIDITY = /datum/biome/frontier_badlands/plains,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/frontier_badlands/plains
		),
	)
	// The wasteland's caves, unchanged
	cave_biomes = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/wasteland,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/wasteland,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/mossy_stone,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/rubble,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/rubble
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/wasteland,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/wasteland,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/rubble,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/rubble,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/rubble
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/rubble,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/wasteland,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/wasteland,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/rubble,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/mossy_stone
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/wasteland,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/wasteland,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/rubble,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/mossy_stone,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/rubble
		)
	)

/**
 * The wasteland's badlands without its explosive mines and hivebot or blobspore portals. Not a
 * subtype of /datum/biome/wasteland: the wasteland's plains and forest inherit those features from
 * it, so the Frontier carries its own plains and forest under this type instead.
 */
/datum/biome/frontier_badlands
	open_turf_types = list(/turf/open/misc/wasteland = 1)
	flora_spawn_list = list(
		/obj/structure/flora/rock/asteroid = 30,
		/obj/structure/flora/tree/dead/tall = 10,
		/obj/structure/flora/tree/dead_pine = 4,
		/obj/structure/flora/tree/dead_african = 1,
		/obj/structure/flora/rock/wasteland = 10,
		/obj/structure/flora/cactus = 10
	)
	flora_spawn_chance = 5
	feature_spawn_list = list(
		/obj/item/bodypart/arm/right/robot = 40,
		/obj/item/assembly/prox_sensor = 40,
		/obj/structure/geyser/random = 4,
		/obj/item/shard = 30,
		/obj/item/stack/cable_coil/cut = 30,
		/obj/item/stack/rods = 30,
		/obj/structure/ammo_printer = 1
	)
	feature_spawn_chance = 3
	mob_spawn_chance = 7
	mob_spawn_list = list(
		/mob/living/simple_animal/hostile/asteroid/hermit/ranged/hunter = 5,
		/mob/living/simple_animal/hostile/asteroid/hermit/ranged/gunslinger = 5,
		/mob/living/basic/spider/giant/wasteland = 1,
		/mob/living/basic/spider/giant/tarantula/wasteland = 1,
		/mob/living/basic/mining/legion/wasteland = 3
	)
	dangerous_mob_spawn_list = list(
		/mob/living/basic/mining/legion/wasteland = 3,
		/mob/living/basic/spider/giant/tarantula/wasteland = 2,
		/mob/living/basic/spider/giant/wasteland = 2,
	)

/// Dust and tall dead grass, as /datum/biome/wasteland/plains
/datum/biome/frontier_badlands/plains
	open_turf_types = list(/turf/open/misc/dust = 1)
	flora_spawn_list = list(/obj/structure/flora/deadgrass/tall = 50, /obj/structure/flora/deadgrass/tall/dense = 5, /obj/structure/flora/rock/wasteland = 1)
	flora_spawn_chance = 45
	mob_spawn_chance = 15

/// Dry dirt and dead trees, as /datum/biome/wasteland/forest
/datum/biome/frontier_badlands/forest
	open_turf_types = list(/turf/open/misc/dirt/dry = 1)
	flora_spawn_list = list(
		/obj/structure/flora/tree/dead/tall = 35,
		/obj/structure/flora/branches = 10,
		/obj/structure/flora/deadgrass = 80,
		/obj/structure/flora/tree/dead_pine = 15,
		/obj/structure/flora/tree/dead_african = 4
	)
	flora_spawn_chance = 25

/area/overmap_encounter/planetoid/frontier
	name = "Frontier"
	sound_environment = SOUND_ENVIRONMENT_PLAIN
	ambientsounds = MINING
	planet_type = /datum/planet/frontier

/area/overmap_encounter/planetoid/cave/frontier
	name = "Frontier Caves"
	planet_type = /datum/planet/frontier

/datum/overmap/planet/frontier
	name = "Frontier"
	desc = "Dry prairie under a white sun. Someone farms down there."
	color = COLOR_BEIGE
	planet_template = /datum/planet/frontier
	chart_variant = "wasteland"
