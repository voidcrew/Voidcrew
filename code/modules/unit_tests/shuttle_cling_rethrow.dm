/// Hyperspace drift launches an unheld object once; each tile it then travels must not start another throw.
/datum/unit_test/shuttle_cling_rethrow
	var/list/turf/changed_turfs = list()
	var/list/original_turf_types = list()

/datum/unit_test/shuttle_cling_rethrow/Destroy()
	for(var/i in 1 to length(changed_turfs))
		var/turf/changed = changed_turfs[i]
		changed.ChangeTurf(original_turf_types[i])
	return ..()

/datum/unit_test/shuttle_cling_rethrow/Run()
	// A short corridor of hyperspace flowing north, so the launched item stays in transit after its first step.
	for(var/offset in 0 to 3)
		var/turf/corridor = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 1 + offset, run_loc_floor_bottom_left.z)
		original_turf_types += corridor.type
		changed_turfs += corridor.ChangeTurf(/turf/open/space/transit)
	var/turf/open/space/transit/entry = changed_turfs[1]

	var/obj/item/debris = allocate(/obj/item)
	var/alive_before = GLOB.thrownthing_alive
	debris.forceMove(entry)

	var/datum/component/shuttle_cling/cling = debris.GetComponent(/datum/component/shuttle_cling)
	TEST_ASSERT(cling && !QDELETED(cling), "Entering hyperspace did not attach drift.")
	var/datum/thrownthing/launch = debris.throwing
	TEST_ASSERT_NOTNULL(launch, "Drift did not launch the unheld item.")
	TEST_ASSERT(istype(debris.loc, /turf/open/space/transit), "The launched item left the transit corridor on its first step.")
	TEST_ASSERT_EQUAL(GLOB.thrownthing_alive, alive_before + 1, "The launch's own movement started extra throws.")

	for(var/i in 1 to 5)
		cling.update_state()
	TEST_ASSERT(!QDELETED(cling), "Drift removed itself while the item was still in transit.")
	TEST_ASSERT_EQUAL(debris.throwing, launch, "Drift replaced the throw that was already carrying the item.")
	TEST_ASSERT_EQUAL(SSthrowing.processing[debris], launch, "Drift replaced the queued throw.")
	TEST_ASSERT_EQUAL(GLOB.thrownthing_alive, alive_before + 1, "Drift created throw datums while the item was already airborne.")

	qdel(launch)
	TEST_ASSERT_NULL(debris.throwing, "Ending the launch left it on the item.")
	TEST_ASSERT_EQUAL(GLOB.thrownthing_alive, alive_before, "Ending the launch did not release its datum.")
