/datum/unit_test/shuttle_cling_lifecycle
	var/turf/changed_turf
	var/original_turf_type

/datum/unit_test/shuttle_cling_lifecycle/Destroy()
	if(changed_turf && original_turf_type)
		changed_turf.ChangeTurf(original_turf_type)
	return ..()

/datum/unit_test/shuttle_cling_lifecycle/Run()
	var/obj/effect/recipient = allocate(/obj/effect)
	TEST_ASSERT(!recipient.AddComponent(/datum/component/shuttle_cling, SOUTH), "A movable outside transit must decline a drift component without an initialization runtime.")
	TEST_ASSERT(!HAS_TRAIT(recipient, TRAIT_HYPERSPACED), "Declining a drift component left its hyperspace trait behind.")

	changed_turf = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	original_turf_type = changed_turf.type
	var/turf/open/space/transit/transit = changed_turf.ChangeTurf(/turf/open/space/transit)
	changed_turf = transit
	transit.initialize_drifting(transit, recipient)
	TEST_ASSERT(!recipient.GetComponent(/datum/component/shuttle_cling), "A stale transit callback attached drift to an object on a different turf.")

	// Place without automatically receiving a component, then exercise a stopped corridor.
	ADD_TRAIT(recipient, TRAIT_HYPERSPACED, "test-placement")
	recipient.forceMove(transit)
	REMOVE_TRAIT(recipient, TRAIT_HYPERSPACED, "test-placement")
	ADD_TRAIT(transit, TRAIT_HYPERSPACE_STOPPED, "test-stopped")
	TEST_ASSERT(!recipient.AddComponent(/datum/component/shuttle_cling, SOUTH), "Stopped transit must decline drift without deleting a component during Initialize.")
	REMOVE_TRAIT(transit, TRAIT_HYPERSPACE_STOPPED, "test-stopped")

	// A real component should register, retain its trait, then cleanly leave with the parent.
	ADD_TRAIT(recipient, TRAIT_FREE_HYPERSPACE_MOVEMENT, "test-stationary")
	var/datum/component/shuttle_cling/cling = recipient.AddComponent(/datum/component/shuttle_cling, SOUTH)
	TEST_ASSERT(cling && !QDELETED(cling), "Active transit did not register a drift component.")
	TEST_ASSERT_EQUAL(recipient.GetComponent(/datum/component/shuttle_cling), cling, "The component was not registered on its parent.")
	TEST_ASSERT(HAS_TRAIT(recipient, TRAIT_HYPERSPACED), "Active drift lost its hyperspace trait.")
	recipient.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(QDELETED(cling), "Moving off transit should remove drift.")
	TEST_ASSERT(!recipient.GetComponent(/datum/component/shuttle_cling), "Leaving transit retained the removed component.")
	TEST_ASSERT(!HAS_TRAIT(recipient, TRAIT_HYPERSPACED), "Leaving transit retained the component's trait.")
	REMOVE_TRAIT(recipient, TRAIT_FREE_HYPERSPACE_MOVEMENT, "test-stationary")

	// Drift can move its own parent immediately. Removal must happen after registration.
	ADD_TRAIT(recipient, TRAIT_HYPERSPACED, "test-placement")
	recipient.forceMove(transit)
	REMOVE_TRAIT(recipient, TRAIT_HYPERSPACED, "test-placement")
	TEST_ASSERT(!recipient.AddComponent(/datum/component/shuttle_cling/lifecycle_test, SOUTH, run_loc_floor_bottom_left), "The immediately removed component should not survive creation.")
	TEST_ASSERT_EQUAL(recipient.loc, run_loc_floor_bottom_left, "The drift callback did not move its parent.")
	TEST_ASSERT(!recipient.GetComponent(/datum/component/shuttle_cling), "Immediate movement left a stale component registration.")
	TEST_ASSERT(!HAS_TRAIT(recipient, TRAIT_HYPERSPACED), "Immediate movement left a stale hyperspace trait.")

/datum/component/shuttle_cling/lifecycle_test
	var/turf/destination

/datum/component/shuttle_cling/lifecycle_test/Initialize(direction, turf/destination)
	src.destination = destination
	return ..(direction)

/datum/component/shuttle_cling/lifecycle_test/launch_very_hard(atom/movable/byebye)
	byebye.forceMove(destination)
