/datum/biome/wasteland
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
		/obj/effect/mine/explosive = 8,
		/obj/structure/geyser/random = 4,
		/obj/item/shard = 30,
		/obj/item/stack/cable_coil/cut = 30,
		/obj/item/stack/rods = 30,
		/obj/structure/spawner/ice_moon/demonic_portal/blobspore = 3,
		/obj/structure/spawner/ice_moon/demonic_portal/hivebot = 3,
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
	// Meaner tier for dangerous-zone planets (see dangerous_mob_spawn_list)
	dangerous_mob_spawn_list = list(
		/mob/living/basic/mining/legion/wasteland = 3,
		/mob/living/basic/spider/giant/tarantula/wasteland = 2,
		/mob/living/basic/spider/giant/wasteland = 2,
	)

/datum/biome/wasteland/plains
	open_turf_types = list(/turf/open/misc/dust = 1)
	flora_spawn_list = list(/obj/structure/flora/deadgrass/tall = 50, /obj/structure/flora/deadgrass/tall/dense = 5, /obj/structure/flora/rock/wasteland = 1)
	flora_spawn_chance = 45
	mob_spawn_chance = 15

/datum/biome/wasteland/forest
	open_turf_types = list(/turf/open/misc/dirt/dry = 1)
	flora_spawn_list = list(
		/obj/structure/flora/tree/dead/tall = 35,
		/obj/structure/flora/branches = 10,
		/obj/structure/flora/deadgrass = 80,
		/obj/structure/flora/tree/dead_pine = 15,
		/obj/structure/flora/tree/dead_african = 4
	)
	flora_spawn_chance = 25

/**
 * Fallout zone. This is the only biome that seeds /obj/structure/radioactive, so it
 * is the only part of a wasteland that will irradiate someone for standing in it.
 * Its ground lights itself green (see /turf/open/misc/asteroid/sand/lit/nuclear) so
 * the zone is identifiable from outside it - the surrounding wasteland biomes light
 * neutral, and the boundary between them is the warning.
 *
 * These are the only planet surface turfs that still carry their own light source.
 * Every other biome dropped its /lit turfs for one area-wide ambient light
 * (see /area/overmap_encounter/planetoid/wasteland); the fallout green is a hazard
 * telegraph rather than daylight, so it has to stay on the ground that is dangerous
 * and nowhere else. It now reads as green added on top of the neutral ambient
 * instead of green replacing it, so the boundary is softer than it used to be.
 *
 * Surface areas are dynamic - their ground carries no lighting objects at all - so these
 * tiles are also the one kind of surface ground that still gets one, on the strength of
 * lighting itself. /turf/proc/skips_lighting_object() is the rule, and every place that
 * builds a lighting object honours it. A contaminated blob therefore renders green tile by
 * tile; what it no longer does is spill green a couple of tiles into the clean wasteland
 * around it, because that ground has nothing to render the spill on. The boundary is a
 * step again rather than a fade, which is arguably the better telegraph.
 */
/datum/biome/nuclear
	open_turf_types = list(/turf/open/misc/asteroid/sand/lit/nuclear = 5, /turf/open/misc/asteroid/sand/dark/lit/nuclear = 1)
	feature_spawn_chance = 2.5
	feature_spawn_list = list(
		/obj/structure/radioactive = 10,
		/obj/structure/radioactive/stack = 10,
		/obj/structure/radioactive/waste = 10,
		/obj/item/stack/ore/slag = 10,
		/obj/structure/flora/cactus = 20,
		/obj/structure/spawner/ice_moon/demonic_portal/blobspore = 1,
		/obj/structure/spawner/ice_moon/demonic_portal/hivebot = 1
	)
	flora_spawn_chance = 1
	flora_spawn_list = list(/obj/structure/flora/rock/wasteland = 30, /obj/effect/decal/cleanable/greenglow = 30, /obj/structure/elite_tumor = 1)
	mob_spawn_chance = 20
	mob_spawn_list = list(
		/mob/living/simple_animal/hostile/asteroid/hermit/ranged/hunter = 10,
		/mob/living/simple_animal/hostile/asteroid/hermit/ranged/gunslinger = 7,
		/mob/living/basic/hivebot/rapid/wasteland = 5,
		/mob/living/basic/spider/giant/wasteland = 1,
		/mob/living/basic/spider/giant/tarantula/wasteland = 1
	)
	dangerous_mob_spawn_list = list(
		/mob/living/basic/hivebot/rapid/wasteland = 3,
		/mob/living/basic/spider/giant/tarantula/wasteland = 1,
	)

/datum/biome/ruins
	open_turf_types = list(/turf/open/misc/dust = 45, /turf/open/floor/plating/rust = 1)
	feature_spawn_chance = 5
	feature_spawn_list = list(
		/obj/structure/barrel/flaming = 6,
		/obj/structure/barrel = 10,
		/obj/structure/reagent_dispensers/fueltank = 6,
		/obj/item/shard = 12,
		/obj/item/stack/cable_coil/cut = 12,
		/obj/effect/mine/explosive = 2,
		/obj/item/food/canned/beans = 2,
		/obj/structure/mecha_wreckage/ripley = 6,
		/obj/structure/mecha_wreckage/ripley/mk2 = 2,
		/obj/structure/spawner/ice_moon/demonic_portal/blobspore = 1,
		/obj/structure/spawner/ice_moon/demonic_portal/hivebot = 1,
		/obj/structure/ammo_printer = 1
	)
	flora_spawn_chance = 1
	flora_spawn_list = list(
		/obj/structure/girder = 1
	)
	mob_spawn_chance = 10
	mob_spawn_list = list(
		/mob/living/basic/mining/legion/wasteland = 15,
		/mob/living/basic/mining/legion/crystal/wasteland = 1,
		/mob/living/basic/mining/watcher/forgotten/wasteland = 1
	)
	dangerous_mob_spawn_list = list(
		/mob/living/basic/mining/legion/crystal/wasteland = 1,
		/mob/living/basic/mining/watcher/forgotten/wasteland = 1,
	)

/datum/biome/cave/wasteland
	open_turf_types = list(/turf/open/misc/dirt/dry = 1, /turf/open/misc/dust = 1)
	closed_turf_types = list(/turf/closed/mineral/random/high_chance/wasteland = 1)
	mob_spawn_chance = 1
	mob_spawn_list = list(
		/mob/living/basic/wumborian_fugu/wasteland = 15,
		/mob/living/basic/mining/wolf/wasteland/random = 15,
		/obj/structure/spawner/ice_moon/demonic_portal/blobspore = 1,
		/obj/structure/spawner/ice_moon/demonic_portal/hivebot = 1
	)
	dangerous_mob_spawn_list = list(
		/mob/living/basic/mining/goliath/wasteland = 3,
		/mob/living/basic/mining/goliath/ancient/wasteland = 1,
	)
	flora_spawn_chance = 10
	flora_spawn_list = list(
		/obj/structure/flora/rock/wasteland = 5,
		/obj/structure/flora/ash/leaf_shroom = 4,
		/obj/structure/flora/ash/cap_shroom = 4,
		/obj/structure/flora/ash/stem_shroom = 4,
		/obj/structure/flora/ash/cacti = 2,
		/obj/structure/flora/ash/tall_shroom = 4,
		/obj/structure/flora/ash/whitesands/puce = 1
	)
	feature_spawn_chance = 3
	feature_spawn_list = list(
		/obj/structure/spawner/cave = 20,
		/obj/structure/closet/crate/grave/filled = 40,
		/obj/structure/closet/crate/grave/filled/lead_researcher = 20,
		/obj/item/pickaxe/rusted = 40,
		/obj/item/pickaxe/diamond = 1,
		/obj/item/shovel/serrated = 30,
		/obj/structure/radioactive = 30,
		/obj/structure/radioactive/stack = 50,
		/obj/structure/radioactive/waste = 50,
		/obj/item/stack/ore/slag = 60,
		/obj/structure/ammo_printer = 10
	)

/datum/biome/cave/rubble
	open_turf_types = list(/turf/open/floor/plating/rubble = 1, /turf/open/floor/plating/tunnel = 6)
	closed_turf_types = list(/turf/closed/wall/r_wall/rust = 1, /turf/closed/wall/rust = 4,/turf/closed/mineral/random/high_chance/wasteland = 10)
	feature_spawn_list = list(
		/obj/effect/spawner/random/maintenance = 10,
		/obj/item/stack/rods = 5,
		/obj/structure/closet/crate/secure/loot = 1,
		/obj/structure/spawner/cave = 2,
		/obj/structure/barrel/flaming = 2,
		/obj/structure/reagent_dispensers/fueltank = 2,
		/obj/structure/girder = 2,
		/obj/item/shard = 2,
		/obj/item/stack/cable_coil/cut = 2,
		/obj/effect/mine/explosive = 2,
		///obj/item/ammo_casing/caseless/arrow/bone = 2,
		/obj/item/healthanalyzer = 2,
		/obj/item/storage/medkit = 2,
		/obj/structure/ammo_printer = 1
	)
	feature_spawn_chance = 5
	flora_spawn_list = list(/obj/structure/flora/rock/wasteland = 1)
	flora_spawn_chance = 1
	mob_spawn_chance = 5
	mob_spawn_list = list(
		/mob/living/basic/spider/giant/tarantula/wasteland = 1,
		/mob/living/basic/mining/goliath/wasteland = 20,
		/mob/living/basic/mining/goliath/ancient/wasteland = 15,
		/obj/structure/spawner/ice_moon/demonic_portal/blobspore = 1,
		/obj/structure/spawner/ice_moon/demonic_portal/hivebot = 1
	)

/**
 * The one wasteland cave biome that never declared its own walls, so it inherited
 * /datum/biome/cave's lavaland default. Those walls mine into
 * /turf/open/misc/asteroid/basalt/lava_land_surface: LAVALAND_DEFAULT_ATMOS is
 * rolled between 30 and 49 kPa, always under WARNING_LOW_PRESSURE, and the turf is
 * planetary, so every tile mined here read as depressurized forever and fought the
 * surrounding 101 kPa ground for air. It also mined poorly (the volcanic wall is
 * proximity_based with mineralChance 5, and a planet has no vents when its terrain
 * generates) and it sat on a lava baseturf, so anything that broke the new floor
 * opened a lava tile on a wasteland.
 */
/datum/biome/cave/mossy_stone
	open_turf_types = list(/turf/open/floor/plating/mossy_stone = 5, /turf/open/misc/dirt/dry = 1)
	closed_turf_types = list(/turf/closed/mineral/random/high_chance/wasteland = 1)
	feature_spawn_list = list(
		/obj/effect/decal/cleanable/greenglow = 30,
		/obj/machinery/portable_atmospherics/canister/plasma = 15,
		/obj/machinery/portable_atmospherics/canister/miasma = 15,
		/obj/machinery/portable_atmospherics/canister/carbon_dioxide = 15,
		/obj/structure/barrel/flaming = 20,
		/obj/structure/geyser/random = 1,
		/obj/structure/spawner/cave = 5
	)
	feature_spawn_chance = 5
	flora_spawn_list = list(
		/obj/structure/flora/glowshroom = 20,
	)
	flora_spawn_chance = 30
	mob_spawn_chance = 5
	mob_spawn_list = list(
		/mob/living/basic/blob_minion/blobbernaut/wasteland = 1,
		/mob/living/basic/mining/watcher/magmawing/wasteland = 4,
		/mob/living/basic/mining/goldgrub = 3,
		/mob/living/basic/mining/legion/wasteland = 3,
		/obj/structure/spawner/ice_moon/demonic_portal/blobspore = 1,
		/obj/structure/spawner/ice_moon/demonic_portal/hivebot = 1
	)
