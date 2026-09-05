/// Tests Shadow Walk can be entered and exited
/datum/unit_test/shadow_jaunt

/datum/unit_test/shadow_jaunt/Run()
	var/mob/living/carbon/human/jaunter = allocate(/mob/living/carbon/human/consistent)
	var/datum/action/cooldown/spell/jaunt/shadow_walk/walk = allocate(/datum/action/cooldown/spell/jaunt/shadow_walk, jaunter)
	walk.Grant(jaunter)

	var/turf/jaunt_turf = jaunter.loc
	TEST_ASSERT(istype(jaunt_turf), "Jaunter was not allocated to a turf, instead to [jaunt_turf || "nullspace"].")
	TEST_ASSERT(walk.IsAvailable(), "Unit test room is not suitable to test [walk].")

	walk.Trigger()

	TEST_ASSERT_NOTEQUAL(jaunter.loc, jaunt_turf, "Jaunter's loc did not change on casting [walk].")
	TEST_ASSERT(istype(jaunter.loc, walk.jaunt_type), "Jaunter failed to enter jaunt on casting [walk].")

	walk.next_use_time = -1
	walk.Trigger()

	TEST_ASSERT_EQUAL(jaunter.loc, jaunt_turf, "Jaunter failed to exit jaunt on exiting [walk].")

/// A nearby pool across a ruin boundary must not invoke the random jaunt ejection fallback.
/datum/unit_test/blood_jaunt_destinations
	var/turf/pool_turf
	var/area/original_area
	var/area/overmap_encounter/planet_ruin/ruin_area
	var/original_turf_flags

/datum/unit_test/blood_jaunt_destinations/Destroy()
	if(pool_turf)
		pool_turf.turf_flags = original_turf_flags
		pool_turf.change_area(ruin_area, original_area)
	QDEL_NULL(ruin_area)
	return ..()

/datum/unit_test/blood_jaunt_destinations/Run()
	var/mob/living/carbon/human/jaunter = allocate(/mob/living/carbon/human/consistent)
	var/datum/action/cooldown/spell/jaunt/bloodcrawl/crawl = allocate(/datum/action/cooldown/spell/jaunt/bloodcrawl)
	crawl.Grant(jaunter)
	crawl.equip_blood_hands = FALSE
	var/obj/effect/decal/cleanable/blood/entry_pool = allocate(/obj/effect/decal/cleanable/blood)
	pool_turf = get_step(run_loc_floor_bottom_left, EAST)
	original_area = get_area(pool_turf)
	original_turf_flags = pool_turf.turf_flags
	ruin_area = new
	pool_turf.change_area(original_area, ruin_area)
	var/obj/effect/decal/cleanable/blood/exit_pool = allocate(/obj/effect/decal/cleanable/blood, pool_turf)

	TEST_ASSERT(!crawl.try_enter_jaunt(exit_pool, jaunter, forced = TRUE), "Blood Crawl entered a pool inside a NOTELEPORT ruin")
	TEST_ASSERT_EQUAL(get_turf(jaunter), run_loc_floor_bottom_left, "Refused blood entry moved the caster")
	TEST_ASSERT(crawl.try_enter_jaunt(entry_pool, jaunter, forced = TRUE), "Blood Crawl could not enter an ordinary pool")
	var/obj/effect/dummy/phased_mob/holder = jaunter.loc
	qdel(entry_pool)

	TEST_ASSERT(isnull(crawl.find_nearby_blood(get_turf(jaunter))), "Blood Crawl offered a pool across a NOTELEPORT boundary")
	var/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor/trapdoor = allocate(/datum/action/cooldown/spell/jaunt/bloodcrawl/vestige_trapdoor)
	TEST_ASSERT(isnull(trapdoor.find_wet_door(get_turf(jaunter))), "The trapdoor pact offered a pool across a NOTELEPORT boundary")
	TEST_ASSERT(!crawl.try_exit_jaunt(exit_pool, jaunter, forced = TRUE), "Blood Crawl exited into a NOTELEPORT ruin")
	TEST_ASSERT_EQUAL(jaunter.loc, holder, "A refused blood exit ejected or scattered the caster")
	TEST_ASSERT_EQUAL(get_turf(holder), run_loc_floor_bottom_left, "A refused blood exit moved the holder")

	// Turf-level wards must also apply to pool selection and direct entry/exit.
	ruin_area.area_flags &= ~NOTELEPORT
	pool_turf.turf_flags |= NOJAUNT
	TEST_ASSERT(isnull(crawl.find_nearby_blood(get_turf(jaunter))), "Blood Crawl offered a pool on a NOJAUNT turf")
	TEST_ASSERT(!crawl.try_exit_jaunt(exit_pool, jaunter, forced = TRUE), "Blood Crawl exited onto a NOJAUNT turf")
	pool_turf.turf_flags = original_turf_flags

	TEST_ASSERT_EQUAL(crawl.find_nearby_blood(get_turf(jaunter)), exit_pool, "Blood Crawl did not offer the now-unprotected pool")
	TEST_ASSERT_EQUAL(trapdoor.find_wet_door(get_turf(jaunter)), exit_pool, "The trapdoor pact did not offer the now-unprotected pool")

	// The destination can become protected after selection, during the bubbling delay.
	crawl.exit_blood_time = 1 SECONDS
	addtimer(CALLBACK(src, PROC_REF(ward_destination)), 0.5 SECONDS)
	TEST_ASSERT(!crawl.try_exit_jaunt(exit_pool, jaunter), "Blood Crawl ignored a ward applied during its exit delay")
	TEST_ASSERT(ruin_area.area_flags & NOTELEPORT, "The destination was never warded during the exit delay")
	TEST_ASSERT_EQUAL(jaunter.loc, holder, "A ward applied during the exit delay scattered the caster")
	TEST_ASSERT_EQUAL(get_turf(holder), run_loc_floor_bottom_left, "A ward applied during the exit delay moved the holder")

	ruin_area.area_flags &= ~NOTELEPORT
	TEST_ASSERT(crawl.try_exit_jaunt(exit_pool, jaunter, forced = TRUE), "Blood Crawl could not exit through an unprotected pool")
	TEST_ASSERT_EQUAL(jaunter.loc, pool_turf, "Blood Crawl did not surface at the chosen pool")
	TEST_ASSERT(!HAS_TRAIT(jaunter, TRAIT_MAGICALLY_PHASED), "Blood Crawl left the caster phased after a successful exit")

/datum/unit_test/blood_jaunt_destinations/proc/ward_destination()
	ruin_area.area_flags |= NOTELEPORT
