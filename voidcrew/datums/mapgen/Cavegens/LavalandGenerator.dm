/datum/map_generator/cave_generator/lavaland
	open_turf_types = list(/turf/open/misc/asteroid/basalt/lava_land_surface = 1)
	closed_turf_types =  list(/turf/closed/mineral/random/volcanic = 1)

	feature_spawn_chance = 2
	feature_spawn_list = list(/obj/structure/geyser/random = 2, /obj/structure/elite_tumor = 1)
	mob_spawn_list = list(
		/obj/effect/spawner/random/lavaland_mob/goliath = 50, /obj/structure/spawner/lavaland/goliath = 3, \
		/mob/living/basic/mining/watcher = 40, /obj/structure/spawner/lavaland = 3, \
		/mob/living/basic/mining/legion = 30, /obj/structure/spawner/lavaland/legion = 3, \
		SPAWN_MEGAFAUNA = 4, /mob/living/basic/mining/goldgrub = 10)
	flora_spawn_list = list(/obj/structure/flora/ash/whitesands/fireblossom = 2, /obj/structure/flora/ash/whitesands/puce = 2, /obj/structure/flora/ash/leaf_shroom = 2 , /obj/structure/flora/ash/cap_shroom = 2 , /obj/structure/flora/ash/stem_shroom = 2 , /obj/structure/flora/ash/cacti = 1, /obj/structure/flora/ash/tall_shroom = 2, /obj/structure/flora/ash/whitesands/fern = 2)

	initial_closed_chance = 45
	smoothing_iterations = 50
	birth_limit = 4
	death_limit = 3

/**
 * Lavaland-looking terrain used by the volcanic encounters on frozen planets.
 *
 * These keep the basalt and rock appearance, but use the same infinite atmosphere
 * as the surrounding frozen planet. Their self baseturfs also prevent explosions
 * from uncovering a Lavaland-atmos lava source beneath the frozen terrain.
 */
/turf/open/misc/asteroid/basalt/lava_land_surface/frozen_planet
	initial_gas_mix = FROZEN_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/basalt/lava_land_surface/frozen_planet

/turf/open/misc/asteroid/basalt/lava_land_surface/no_ruins/frozen_planet
	initial_gas_mix = FROZEN_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/basalt/lava_land_surface/no_ruins/frozen_planet

/turf/open/indestructible/boss/frozen_planet
	initial_gas_mix = FROZEN_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/indestructible/boss/frozen_planet

/turf/closed/mineral/random/volcanic/frozen_planet
	turf_type = /turf/open/misc/asteroid/basalt/lava_land_surface/frozen_planet
	baseturfs = /turf/open/misc/asteroid/basalt/lava_land_surface/frozen_planet
	initial_gas_mix = FROZEN_ATMOS

/turf/closed/mineral/random/volcanic/frozen_planet/mineral_chances()
	var/list/chances = ..()
	var/gibtonite_chance = chances[/turf/closed/mineral/gibtonite/volcanic]
	chances -= /turf/closed/mineral/gibtonite/volcanic
	chances[/turf/closed/mineral/gibtonite/volcanic/frozen_planet] = gibtonite_chance
	return chances

/turf/closed/mineral/gibtonite/volcanic/frozen_planet
	turf_type = /turf/open/misc/asteroid/basalt/lava_land_surface/frozen_planet
	baseturfs = /turf/open/misc/asteroid/basalt/lava_land_surface/frozen_planet
	initial_gas_mix = FROZEN_ATMOS

/turf/closed/mineral/volcanic/lava_land_surface/frozen_planet
	turf_type = /turf/open/misc/asteroid/basalt/lava_land_surface/frozen_planet
	baseturfs = /turf/open/misc/asteroid/basalt/lava_land_surface/frozen_planet
	initial_gas_mix = FROZEN_ATMOS

/turf/closed/mineral/volcanic/lava_land_surface/do_not_chasm/frozen_planet
	turf_type = /turf/open/misc/asteroid/basalt/lava_land_surface/no_ruins/frozen_planet
	baseturfs = /turf/open/misc/asteroid/basalt/lava_land_surface/no_ruins/frozen_planet
	initial_gas_mix = FROZEN_ATMOS

/datum/map_generator/cave_generator/lavaland/frozen_planet
	weighted_open_turf_types = list(/turf/open/misc/asteroid/basalt/lava_land_surface/frozen_planet = 1)
	weighted_closed_turf_types = list(/turf/closed/mineral/random/volcanic/frozen_planet = 1)

/datum/map_generator/cave_generator/lavaland/ruin_version/frozen_planet
	weighted_open_turf_types = list(/turf/open/misc/asteroid/basalt/lava_land_surface/no_ruins/frozen_planet = 1)
	weighted_closed_turf_types = list(/turf/closed/mineral/volcanic/lava_land_surface/do_not_chasm/frozen_planet = 1)

/area/lavaland/surface/outdoors/unexplored/frozen_planet
	map_generator = /datum/map_generator/cave_generator/lavaland/frozen_planet

/area/lavaland/surface/outdoors/unexplored/danger/no_ruins/frozen_planet
	map_generator = /datum/map_generator/cave_generator/lavaland/ruin_version/frozen_planet
