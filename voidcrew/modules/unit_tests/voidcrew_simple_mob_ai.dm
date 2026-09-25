/**
 * A hostile simple animal that has gone AI_IDLE must be able to wake back up.
 *
 * SSnpcpool only ticks GLOB.simple_animals[AI_ON], and a hostile with no target idles
 * itself out of that list on its first tick. Upstream deleted the subsystem that walked
 * the idle list (tg #82469), which silently made AI_IDLE permanent - every mapped hermit
 * in the wasteland ruins loaded, idled, and then ignored players for the rest of the
 * round. SSidlenpcpool + consider_wakeup() (voidcrew/controllers/subsystem/idle_npc_wakeup.dm)
 * restore the wakeup; this guards it against being dropped in an upstream merge.
 */
/datum/unit_test/voidcrew_simple_mob_wakeup

/datum/unit_test/voidcrew_simple_mob_wakeup/Run()
	var/mob/living/simple_animal/hostile/asteroid/hermit/survivor/hermit = allocate(/mob/living/simple_animal/hostile/asteroid/hermit/survivor)
	var/turf/hermit_turf = get_turf(hermit)
	TEST_ASSERT(hermit_turf, "the test hermit was allocated without a turf")

	// The state handle_automated_action() leaves a hostile in when it finds nothing to fight.
	hermit.toggle_ai(AI_IDLE)
	TEST_ASSERT_EQUAL(hermit.AIStatus, AI_IDLE, "toggle_ai(AI_IDLE) did not take")

	// No living clients on the z-level: staying asleep is the whole point of the idle state.
	hermit.consider_wakeup()
	TEST_ASSERT_EQUAL(hermit.AIStatus, AI_IDLE, "an idle hostile woke up with nobody on its z-level")

	// Now put someone it wants to kill in front of it. Both mobs are allocated onto
	// run_loc_floor_bottom_left, so this is well inside the hermit's vision_range of 2.
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	SSmobs.clients_by_zlevel[hermit_turf.z] += victim
	hermit.consider_wakeup()
	SSmobs.clients_by_zlevel[hermit_turf.z] -= victim

	TEST_ASSERT_EQUAL(hermit.AIStatus, AI_ON, "an idle hostile failed to wake up for a valid target standing on top of it")
	TEST_ASSERT_EQUAL(hermit.target, victim, "the woken hostile did not take the only valid target as its target")
