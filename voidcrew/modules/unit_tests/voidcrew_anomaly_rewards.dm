/// Small footprints borrow the test level without owning its ground or teardown.
/datum/unit_test/voidcrew_anomaly_rewards
	abstract_type = /datum/unit_test/voidcrew_anomaly_rewards
	var/list/planets = list()

/datum/unit_test/voidcrew_anomaly_rewards/Destroy()
	for(var/obj/structure/overmap/planet/planet in planets)
		planet.footprint = null
		planet.mapzone = null
	planets.Cut()
	return ..()

/datum/unit_test/voidcrew_anomaly_rewards/proc/attach_surface(obj/structure/overmap/planet/planet, turf/site)
	var/datum/map_footprint/footprint = allocate(/datum/map_footprint, null, "planet", 1, planet)
	footprint.attach_level(SSmapping.z_list[site.z])
	footprint.set_rect(site.x, site.y, 1, 1)
	planet.footprint = footprint
	planet.loaded = TRUE
	return footprint

/datum/unit_test/voidcrew_anomaly_rewards/proc/make_planet(turf/site, band = 1)
	var/obj/structure/overmap/planet/planet = allocate(/obj/structure/overmap/planet)
	planets += planet
	planet.zone_band = band // ZONE_GREEN/YELLOW/RED are included after test files.
	attach_surface(planet, site)
	return planet

/datum/unit_test/voidcrew_anomaly_rewards/proc/make_demon(demon_type, turf/site, chance = 100)
	var/mob/living/demon = allocate(demon_type, site)
	var/datum/component/ice_demon_core_reward/reward = demon.GetComponent(/datum/component/ice_demon_core_reward)
	TEST_ASSERT_NOTNULL(reward, "[demon_type] has no core reward component")
	if(istype(demon, /mob/living/basic/mining/ice_demon))
		var/mob/living/basic/mining/ice_demon/watcher = demon
		TEST_ASSERT_EQUAL(reward.drop_chance, 5, "Watcher core probability changed")
		TEST_ASSERT_EQUAL(watcher.crusher_loot, /obj/item/crusher_trophy/ice_demon_cube, "Watcher lost its crusher trophy")
		watcher.basic_mob_flags &= ~DEL_ON_DEATH
	else
		var/mob/living/simple_animal/hostile/asteroid/old_demon/primordial = demon
		TEST_ASSERT_EQUAL(reward.drop_chance, 20, "Primordial core probability changed")
		primordial.del_on_death = FALSE
	reward.drop_chance = chance
	return demon

/datum/unit_test/voidcrew_anomaly_rewards/proc/cores_on(turf/site)
	. = 0
	for(var/obj/item/item in site)
		if(istype(item, /obj/item/raw_anomaly_core) || istype(item, /obj/item/assembly/signaler/anomaly))
			.++

/datum/unit_test/voidcrew_anomaly_rewards/proc/ore_on(turf/site)
	. = 0
	for(var/obj/item/stack/ore/bluespace_crystal/ore in site)
		. += ore.amount

/// The two-core allowance is shared by raw and stabilized drops in every zone.
/datum/unit_test/voidcrew_anomaly_rewards/combined_cap/Run()
	for(var/band in 1 to 3)
		var/turf/site = locate(run_loc_floor_bottom_left.x + band - 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
		var/obj/structure/overmap/planet/planet = make_planet(site, band)
		var/mob/living/watcher = make_demon(/mob/living/basic/mining/ice_demon, site)
		watcher.death(FALSE)
		TEST_ASSERT_EQUAL(ore_on(site), 3, "Watcher ore drop changed")
		TEST_ASSERT_NOTNULL(locate(/obj/item/raw_anomaly_core/bluespace) in site, "Watcher did not emit its raw core")
		var/mob/living/primordial = make_demon(/mob/living/simple_animal/hostile/asteroid/old_demon, site)
		primordial.death(FALSE)
		TEST_ASSERT_EQUAL(ore_on(site), 13, "Primordial ore drop changed")
		TEST_ASSERT_NOTNULL(locate(/obj/item/assembly/signaler/anomaly/bluespace) in site, "Primordial did not emit its stabilized core")
		for(var/demon_type in list(/mob/living/basic/mining/ice_demon, /mob/living/simple_animal/hostile/asteroid/old_demon))
			var/mob/living/excess = make_demon(demon_type, site)
			excess.death(FALSE)
		TEST_ASSERT_EQUAL(cores_on(site), 2, "Band [band] bypassed PLANET_ICE_DEMON_CORE_CAP")
		TEST_ASSERT_EQUAL(planet.ice_demon_cores_emitted, 2, "The shared counter does not match emitted items")
		TEST_ASSERT_EQUAL(ore_on(site), 26, "The core cap suppressed ore")

/// Both successful and failed first rolls remain final after repeated deaths and revival.
/datum/unit_test/voidcrew_anomaly_rewards/repeated_deaths/Run()
	var/turf/site = run_loc_floor_bottom_left
	var/list/demon_types = list(/mob/living/basic/mining/ice_demon, /mob/living/simple_animal/hostile/asteroid/old_demon)
	for(var/demon_type in demon_types)
		var/obj/structure/overmap/planet/planet = make_planet(site)
		var/mob/living/missed = make_demon(demon_type, site, 0)
		missed.death(FALSE)
		TEST_ASSERT_EQUAL(planet.ice_demon_cores_emitted, 0, "A failed roll consumed the allowance")
		var/datum/component/ice_demon_core_reward/reward = missed.GetComponent(/datum/component/ice_demon_core_reward)
		reward.drop_chance = 100
		missed.death(FALSE)
		missed.revive(HEAL_ALL)
		TEST_ASSERT_EQUAL(missed.stat, CONSCIOUS, "The failed-roll fixture did not revive")
		missed.death(FALSE)
		TEST_ASSERT_EQUAL(cores_on(site), 0, "A failed roll was rerolled by death or revival")
		var/mob/living/success = make_demon(demon_type, site)
		success.death(FALSE)
		success.death(FALSE)
		success.revive(HEAL_ALL)
		TEST_ASSERT_EQUAL(success.stat, CONSCIOUS, "The successful-roll fixture did not revive")
		success.death(FALSE)
		TEST_ASSERT_EQUAL(cores_on(site), 1, "A successful roll was repeated by death or revival")
		TEST_ASSERT_EQUAL(planet.ice_demon_cores_emitted, 1, "Repeated deaths changed the source allowance")
		// Retire this footprint before the next variant borrows the same test tile.
		qdel(planet.footprint)
		planet.footprint = null
		for(var/obj/item/item in site)
			qdel(item)

/// Real unload/relocation replaces the footprint, while transported demons retain their source.
/datum/unit_test/voidcrew_anomaly_rewards/transport_reload/Run()
	var/turf/home = run_loc_floor_bottom_left
	var/turf/away = get_step(home, EAST)
	var/turf/reloaded = get_step(home, NORTH)
	var/obj/structure/overmap/planet/source = make_planet(home)
	var/obj/structure/overmap/planet/neighbour = make_planet(away)
	var/mob/living/first = make_demon(/mob/living/basic/mining/ice_demon, home)
	var/mob/living/transported = make_demon(/mob/living/simple_animal/hostile/asteroid/old_demon, home)
	first.forceMove(away)
	transported.forceMove(away)
	first.death(FALSE)
	TEST_ASSERT_EQUAL(source.ice_demon_cores_emitted, 1, "Transport escaped the source allowance")
	TEST_ASSERT_EQUAL(neighbour.ice_demon_cores_emitted, 0, "A transported demon charged its destination")
	// An empty level list exercises the real teardown without wiping borrowed test ground.
	var/datum/map_zone/zone = allocate(/datum/map_zone)
	zone.slots = list(source.footprint)
	zone.slot_capacity = 1
	source.footprint.zone = zone
	source.mapzone = zone
	var/datum/map_footprint/old_footprint = source.footprint
	TEST_ASSERT(source.unload_level(), "The source planet did not unload")
	TEST_ASSERT(QDELETED(old_footprint), "Unloading did not replace the old footprint")
	TEST_ASSERT_EQUAL(source.ice_demon_cores_emitted, 1, "Unloading or relocation reset the allowance")
	attach_surface(source, reloaded)
	transported.death(FALSE)
	TEST_ASSERT_EQUAL(source.ice_demon_cores_emitted, 2, "A transported demon lost its source after unload")
	var/mob/living/excess = make_demon(/mob/living/basic/mining/ice_demon, reloaded)
	excess.death(FALSE)
	TEST_ASSERT_EQUAL(cores_on(reloaded), 0, "Reloading reset the allowance")
	var/mob/living/local = make_demon(/mob/living/simple_animal/hostile/asteroid/old_demon, away)
	local.death(FALSE)
	TEST_ASSERT_EQUAL(neighbour.ice_demon_cores_emitted, 1, "Independent planets shared an allowance")
	TEST_ASSERT_EQUAL(cores_on(away), 3, "Transport or independent planets lost an allowed core")

/// Roundstart surfaces receive their marker after mapped mobs, using the original spawn tile.
/datum/unit_test/voidcrew_anomaly_rewards/preloaded_source/Run()
	var/turf/home = run_loc_floor_bottom_left
	var/turf/away = get_step(home, EAST)
	var/was_initialized = SSovermap.initialized
	SSovermap.initialized = FALSE
	var/mob/living/demon = make_demon(/mob/living/basic/mining/ice_demon, home)
	SSovermap.initialized = was_initialized
	var/datum/component/ice_demon_core_reward/reward = demon.GetComponent(/datum/component/ice_demon_core_reward)
	TEST_ASSERT_EQUAL(reward.pending_spawn_turf, home, "The early spawn did not remember its source tile")
	var/obj/structure/overmap/planet/source = make_planet(home)
	var/obj/structure/overmap/planet/neighbour = make_planet(away)
	demon.forceMove(away)
	reward.on_overmap_initialized(SSovermap)
	TEST_ASSERT_EQUAL(reward.source_planet_ref?.resolve(), source, "Early-spawn adoption followed a moved demon")
	TEST_ASSERT_NULL(reward.pending_spawn_turf, "Early-spawn adoption retained a turf reference")
	demon.death(FALSE)
	TEST_ASSERT_EQUAL(source.ice_demon_cores_emitted, 1, "The preloaded source did not consume its allowance")
	TEST_ASSERT_EQUAL(neighbour.ice_demon_cores_emitted, 0, "Preloaded adoption charged the destination")

/// Drive every supermatter spawn branch, with and without changed lifespans.
/datum/unit_test/voidcrew_anomaly_rewards/supermatter/Run()
	var/list/hazards = list(
		FLUX_ANOMALY = /obj/effect/anomaly/flux/supermatter,
		GRAVITATIONAL_ANOMALY = /obj/effect/anomaly/grav/supermatter,
		PYRO_ANOMALY = /obj/effect/anomaly/pyro/supermatter,
		HALLUCINATION_ANOMALY = /obj/effect/anomaly/hallucination/supermatter/coreless,
		VORTEX_ANOMALY = /obj/effect/anomaly/bhole/supermatter,
		BIOSCRAMBLER_ANOMALY = /obj/effect/anomaly/bioscrambler/docile/supermatter,
		DIMENSIONAL_ANOMALY = /obj/effect/anomaly/dimensional/supermatter,
	)
	for(var/hazard in hazards)
		for(var/changed_lifespan in list(FALSE, TRUE))
			supermatter_anomaly_gen(run_loc_floor_bottom_left, hazard, 0, changed_lifespan)
			var/obj/effect/anomaly/anomaly = locate(/obj/effect/anomaly) in run_loc_floor_bottom_left
			TEST_ASSERT_NOTNULL(anomaly, "Supermatter failed to spawn [hazard]")
			TEST_ASSERT_EQUAL(anomaly.type, hazards[hazard], "Supermatter used the wrong hazard subtype")
			TEST_ASSERT_NULL(anomaly.anomaly_core, "Supermatter created a core inside [hazard]")
			if(istype(anomaly, /obj/effect/anomaly/hallucination/supermatter))
				var/obj/effect/anomaly/hallucination/hallucination = anomaly
				TEST_ASSERT(!hallucination.spawn_decoys, "The coreless hallucination hazard regained decoys")
			if(hazard == VORTEX_ANOMALY)
				TEST_ASSERT_EQUAL(anomaly.lifespan, 2 SECONDS, "Supermatter vortex lifespan changed")
			else if(!changed_lifespan)
				TEST_ASSERT_EQUAL(anomaly.lifespan, initial(anomaly.lifespan), "Default hazard lifespan changed")
			anomaly.anomalyNeutralize()
			TEST_ASSERT(QDELETED(anomaly), "The coreless hazard did not neutralize")
			TEST_ASSERT_EQUAL(cores_on(run_loc_floor_bottom_left), 0, "Neutralizing [hazard] yielded a core")
	var/obj/effect/anomaly/grav/ordinary = allocate(/obj/effect/anomaly/grav)
	TEST_ASSERT_NOTNULL(ordinary.anomaly_core, "Supermatter's core suppression affected ordinary anomalies")

/// Catalog entries supply functioning modules whose seated cores resist the real tool path.
/datum/unit_test/voidcrew_anomaly_rewards/trader_modules/Run()
	var/datum/outpost_shop/vendor/suit_fitter/shop = allocate(/datum/outpost_shop/vendor/suit_fitter)
	var/list/module_types = list()
	for(var/reward in shop.exclusive_rewards)
		if(ispath(reward, /obj/item/mod/module/anomaly_locked))
			module_types += reward
	var/datum/shop_sku/fitter/rare/mod_antigrav/sku = allocate(/datum/shop_sku/fitter/rare/mod_antigrav)
	module_types += sku.item_path
	TEST_ASSERT_EQUAL(length(module_types), 3, "The fitter no longer offers all three anomaly modules")
	TEST_ASSERT(/obj/item/mod/module/anomaly_locked/kinesis/prebuilt/locked in module_types, "The kinesis reward is not locked")
	TEST_ASSERT(/obj/item/mod/module/anomaly_locked/teleporter/prebuilt/locked in module_types, "The teleporter reward is not locked")
	TEST_ASSERT(/obj/item/mod/module/anomaly_locked/antigrav/prebuilt/locked in module_types, "The anti-gravity SKU is not locked")
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/screwdriver/tool = allocate(/obj/item/screwdriver)
	for(var/module_type in module_types)
		wearer.forceMove(run_loc_floor_bottom_left)
		var/obj/item/mod/control/pre_equipped/suit = allocate(/obj/item/mod/control/pre_equipped)
		var/obj/item/mod/module/anomaly_locked/module = allocate(module_type)
		TEST_ASSERT_NOTNULL(module.core, "[module_type] arrived without a core")
		TEST_ASSERT(!module.core_removable, "[module_type] has an extractable core")
		var/obj/item/assembly/signaler/anomaly/seated_core = module.core
		module.screwdriver_act(wearer, tool)
		TEST_ASSERT_EQUAL(module.core, seated_core, "The screwdriver extracted [module_type]'s core")
		TEST_ASSERT_EQUAL(seated_core.loc, module, "The seated core escaped its module")
		suit.install(module)
		TEST_ASSERT_EQUAL(module.mod, suit, "[module_type] could not be installed")
		suit.wearer = wearer
		suit.active = TRUE
		module.part_activated = TRUE
		TEST_ASSERT(module.activate(), "[module_type] could not activate")
		// Keep the ability check independent of any initial use cooldown.
		COOLDOWN_RESET(module, cooldown_timer)
		TEST_ASSERT(module.on_active_process(1), "[module_type] failed its powered core check")
		if(istype(module, /obj/item/mod/module/anomaly_locked/antigrav))
			TEST_ASSERT(!wearer.has_gravity(), "The locked anti-gravity module did not work")
		else if(istype(module, /obj/item/mod/module/anomaly_locked/kinesis))
			var/obj/item/mod/module/anomaly_locked/kinesis/kinesis = module
			var/obj/item/target = allocate(/obj/item, get_step(run_loc_floor_bottom_left, EAST))
			// The cursor catcher requires a real client; exercise the use and targeting gates headlessly.
			TEST_ASSERT(kinesis.range_check(target), "The locked kinesis module cannot reach a nearby item")
			TEST_ASSERT(kinesis.can_grab(target), "The locked kinesis module rejected an ordinary item")
			TEST_ASSERT(kinesis.used(), "The locked kinesis module failed its ability use check")
		else
			var/obj/item/mod/module/anomaly_locked/teleporter/teleporter = module
			teleporter.teleport_time = 0
			var/turf/destination = get_step(run_loc_floor_bottom_left, NORTH)
			teleporter.on_select_use(destination)
			TEST_ASSERT_EQUAL(get_turf(wearer), destination, "The locked teleporter did not teleport")
		module.deactivate(FALSE)
		suit.uninstall(module)
		suit.wearer = null
