/datum/map_generator/cave_generator/lavaland
	open_turf_types = list(/turf/open/misc/asteroid/basalt/lava_land_surface = 1)
	closed_turf_types =  list(/turf/closed/mineral/random/volcanic = 1)

	feature_spawn_chance = 2
	feature_spawn_list = list(/obj/structure/geyser/random = 2, /obj/structure/elite_tumor = 1)
	// upstream deleted the necropolis-tendril spawner family (/obj/structure/spawner/lavaland*).
	// The generic tendril is now the mob /mob/living/basic/mining/tendril, which CaveGenerator
	// still special-cases for the tendril exclusion radius exactly as the old structure was.
	// The goliath den survives as /obj/structure/spawner/mining/goliath; there is no legion den
	// any more, so that slot falls back to the generic monster den.
	mob_spawn_list = list(
		/obj/effect/spawner/random/lavaland_mob/goliath = 50, /obj/structure/spawner/mining/goliath = 3, \
		/mob/living/basic/mining/watcher = 40, /mob/living/basic/mining/tendril = 3, \
		/mob/living/basic/mining/legion = 30, /obj/structure/spawner/mining = 3, \
		SPAWN_MEGAFAUNA = 4, /mob/living/basic/mining/goldgrub = 10)
	flora_spawn_list = list(/obj/structure/flora/ash/whitesands/fireblossom = 2, /obj/structure/flora/ash/whitesands/puce = 2, /obj/structure/flora/ash/leaf_shroom = 2 , /obj/structure/flora/ash/cap_shroom = 2 , /obj/structure/flora/ash/stem_shroom = 2 , /obj/structure/flora/ash/cacti = 1, /obj/structure/flora/ash/tall_shroom = 2, /obj/structure/flora/ash/whitesands/fern = 2)

	// Upstream replaced the flat cellular-automata generator (rustg_cnoise_generate) with a
	// BSP-rooms-plus-CA generator (rustg_cave_system_generator_generate) and renamed its knobs:
	//   initial_closed_chance -> noise_percent, but INVERTED: noise_percent is initial *floor*
	//                            density, so 45% closed == 55% floor
	//   smoothing_iterations  -> ca_steps       (default 20 -> 8)
	//   death_limit           -> survival_limit (default 3 -> 4)
	// VOIDCREW EDIT ORIGINAL: initial_closed_chance = 45 / smoothing_iterations = 50 / birth_limit = 4 / death_limit = 3
	// smoothing_iterations/birth_limit/death_limit are deliberately NOT carried over: 45, 4 and 3
	// were the *old base class defaults*, i.e. the fork was restating them, not tuning them, and
	// the iteration count has no comparable meaning under the new room-based generator.
	noise_percent = 55

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
