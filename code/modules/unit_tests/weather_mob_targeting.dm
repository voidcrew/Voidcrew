/datum/unit_test/weather_mob_targeting/Run()
	var/mob/living/basic/pet/dog/corgi/planetary_mob = allocate(/mob/living/basic/pet/dog/corgi)
	var/mob/living/carbon/human/consistent/player_mob = allocate(/mob/living/carbon/human/consistent)
	var/datum/weather/test_weather = allocate(/datum/weather, list(run_loc_floor_bottom_left.z))

	test_weather.impacted_z_levels = list(run_loc_floor_bottom_left.z)
	test_weather.impacted_areas_lookup[get_area(run_loc_floor_bottom_left)] = TRUE

	TEST_ASSERT(!test_weather.can_weather_act_mob(planetary_mob), \
		"A mindless basic mob was eligible for weather effects.")

	player_mob.mind_initialize()
	TEST_ASSERT(test_weather.can_weather_act_mob(player_mob), \
		"A mob with a current mind was not eligible for weather effects.")

	player_mob.mind.transfer_to(planetary_mob)
	TEST_ASSERT(test_weather.can_weather_act_mob(planetary_mob), \
		"A basic mob with a current mind was not eligible for weather effects.")

	planetary_mob.mind.transfer_to(player_mob)
	TEST_ASSERT(test_weather.can_weather_act_mob(planetary_mob), \
		"A formerly mind-controlled basic mob was not eligible for weather effects.")

	var/mob/living/basic/pet/dog/corgi/ordinary_mob = allocate(/mob/living/basic/pet/dog/corgi)
	var/ordinary_health = ordinary_mob.health
	var/player_health = player_mob.health
	var/queued_light_turfs = length(SSexplosions.lowturf)
	test_weather.thunder_act_turf(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(ordinary_mob.health, ordinary_health, \
		"Weather lightning directly damaged a mindless basic mob.")
	TEST_ASSERT(player_mob.health < player_health, \
		"Weather lightning did not affect a mob with a current mind.")
	TEST_ASSERT_EQUAL(length(SSexplosions.lowturf), queued_light_turfs, \
		"Weather lightning queued an unfiltered explosion.")

/// Isolated weather subsystem used to force a pause after every processed mob.
/datum/controller/subsystem/weather/unit_test/New()
	return

/**
 * Both scratch datums below keep MOB references for the duration of the test, and both are
 * allocate()d, so both are soft-deleted the moment the test ends and then sit in the GC
 * queue with their vars intact. That is enough to poison `create_and_destroy`: it
 * hard-deletes the mobs it creates, BYOND reuses their refs, and REFERENCE_TRACKING's
 * search then FINDS the reused ref sitting in one of these lists and reports the brand new
 * mob as un-collectable. Each such report costs a full REF SEARCH over every atom and datum
 * in the world - measured at ~3.5 minutes apiece on 2026-08-19, which is what stopped the
 * local suite from ever reaching its verdict.
 *
 * Dropping the references on Destroy() costs nothing (the test has already made its
 * assertions by then) and keeps the scratch state from outliving the test that made it.
 */
/datum/controller/subsystem/weather/unit_test/Destroy(force)
	mobs_by_z_cache = null
	processing = null
	currentrun = null
	return ..()

/datum/weather/unit_test/resume_tracking
	weather_flags = WEATHER_MOBS
	var/list/hit_counts = list()

/datum/weather/unit_test/resume_tracking/Destroy(force)
	hit_counts = null
	return ..()

/datum/weather/unit_test/resume_tracking/can_weather_act_mob(mob/living/mob_to_check)
	return TRUE

/datum/weather/unit_test/resume_tracking/weather_act_mob(mob/living/target)
	hit_counts[target] = hit_counts[target] + 1

/datum/unit_test/weather_subsystem_resume/Run()
	var/datum/controller/subsystem/weather/unit_test/test_subsystem = allocate(/datum/controller/subsystem/weather/unit_test)
	var/list/targets = list()
	for(var/index in 1 to 3)
		var/mob/living/basic/pet/dog/corgi/target = allocate(/mob/living/basic/pet/dog/corgi, run_loc_floor_bottom_left)
		target.ever_had_mind = TRUE
		targets += target

	var/z_key = "[run_loc_floor_bottom_left.z]"
	test_subsystem.mobs_by_z_cache = list()
	test_subsystem.mobs_by_z_cache[z_key] = targets
	test_subsystem.mobs_by_z_cache_fire = test_subsystem.times_fired

	var/datum/weather/unit_test/resume_tracking/first_event = allocate(/datum/weather/unit_test/resume_tracking, list(run_loc_floor_bottom_left.z))
	var/datum/weather/unit_test/resume_tracking/second_event = allocate(/datum/weather/unit_test/resume_tracking, list(run_loc_floor_bottom_left.z))
	first_event.stage = MAIN_STAGE
	second_event.stage = MAIN_STAGE
	test_subsystem.processing = list(first_event, second_event)

	// A non-running state makes MC_TICK_CHECK return after each target deterministically.
	test_subsystem.state = SS_IDLE
	test_subsystem.fire(FALSE)
	var/resume_count = 0
	while(length(test_subsystem.currentrun) && resume_count < 20)
		resume_count++
		test_subsystem.fire(TRUE)

	TEST_ASSERT(!length(test_subsystem.currentrun), \
		"Weather did not finish its saved run after [resume_count] resumes.")
	for(var/mob/living/target as anything in targets)
		TEST_ASSERT_EQUAL(first_event.hit_counts[target], 1, \
			"The first weather event processed [target] more than once across resumes.")
		TEST_ASSERT_EQUAL(second_event.hit_counts[target], 1, \
			"The second weather event processed [target] more than once across resumes.")

/datum/space_level/weather_unit_test/New()
	return

/datum/unit_test/weather_zlevel_reconfiguration/Run()
	var/datum/controller/subsystem/weather/unit_test/test_subsystem = allocate(/datum/controller/subsystem/weather/unit_test)
	var/datum/space_level/weather_unit_test/test_level = allocate(/datum/space_level/weather_unit_test)
	test_level.z_value = world.maxz + 100
	test_level.traits = list(ZTRAIT_ASHSTORM = TRUE)

	var/list/ash_levels = SSmapping.z_trait_levels[ZTRAIT_ASHSTORM]
	if(!ash_levels)
		ash_levels = list()
		SSmapping.z_trait_levels[ZTRAIT_ASHSTORM] = ash_levels
	ash_levels |= list(test_level.z_value)
	test_subsystem.update_z_level(test_level)

	test_subsystem.set_z_level_weather_trait(test_level, ZTRAIT_SANDSTORM)
	var/removed_old_trait = !test_level.traits[ZTRAIT_ASHSTORM]
	var/removed_old_index = !(test_level.z_value in SSmapping.z_trait_levels[ZTRAIT_ASHSTORM])
	var/added_new_trait = test_level.traits[ZTRAIT_SANDSTORM]
	var/added_new_index = (test_level.z_value in SSmapping.z_trait_levels[ZTRAIT_SANDSTORM])
	var/datum/weather_site/level_site = test_subsystem.get_level_weather_site(test_level.z_value)
	var/list/new_weather_weights = level_site?.weather_types
	var/replaced_weather_weights = length(new_weather_weights) && new_weather_weights[/datum/weather/sand_storm] && !new_weather_weights[/datum/weather/particle/ash_storm]

	// Restore the global trait index before making assertions that may return early.
	test_subsystem.set_z_level_weather_trait(test_level, null)

	TEST_ASSERT(removed_old_trait, "A recycled z-level retained its old weather trait.")
	TEST_ASSERT(removed_old_index, "The mapping weather-trait index retained the recycled z-level.")
	TEST_ASSERT(added_new_trait, "The replacement weather trait was not added to the recycled z-level.")
	TEST_ASSERT(added_new_index, "The replacement weather trait was not added to the mapping index.")
	TEST_ASSERT(replaced_weather_weights, "The weather scheduler retained weights from the prior planet type.")
