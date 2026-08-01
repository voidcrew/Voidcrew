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
