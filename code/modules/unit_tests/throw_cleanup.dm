/// Throw cleanup must work during startup, before SSthrowing has a current-run list.
/datum/unit_test/throw_cleanup
	var/list/saved_run
	var/run_overridden = FALSE

/datum/unit_test/throw_cleanup/Destroy()
	if(run_overridden)
		SSthrowing.currentrun = saved_run
	return ..()

/datum/unit_test/throw_cleanup/Run()
	var/obj/effect/recipient = allocate(/obj/effect)
	var/datum/thrownthing/throw_packet = allocate(/datum/thrownthing, recipient, run_loc_floor_top_right, NORTH, 2, 1)
	recipient.throwing = throw_packet
	SSthrowing.processing[recipient] = throw_packet
	saved_run = SSthrowing.currentrun
	run_overridden = TRUE
	SSthrowing.currentrun = null
	qdel(throw_packet)
	SSthrowing.currentrun = saved_run
	run_overridden = FALSE
	TEST_ASSERT(QDELETED(throw_packet), "The throw packet should be deleted before the subsystem's first run.")
	TEST_ASSERT(!recipient.throwing, "Cleanup before the first run left the deleted packet on its movable.")
	TEST_ASSERT(!(recipient in SSthrowing.processing), "Cleanup before the first run left the movable queued.")

	// The normal in-flight path must still remove only the completed throw from both lists.
	var/obj/effect/other = allocate(/obj/effect)
	var/datum/thrownthing/other_throw = allocate(/datum/thrownthing, other, run_loc_floor_top_right, NORTH, 2, 1)
	other.throwing = other_throw
	SSthrowing.processing[other] = other_throw
	throw_packet = allocate(/datum/thrownthing, recipient, run_loc_floor_top_right, NORTH, 2, 1)
	recipient.throwing = throw_packet
	SSthrowing.processing[recipient] = throw_packet
	var/list/active_run = list()
	active_run[recipient] = throw_packet
	active_run[other] = other_throw
	run_overridden = TRUE
	SSthrowing.currentrun = active_run
	qdel(recipient)
	SSthrowing.currentrun = saved_run
	run_overridden = FALSE
	TEST_ASSERT(QDELETED(throw_packet), "Deleting a movable did not clean up its active throw.")
	TEST_ASSERT(!(recipient in SSthrowing.processing), "A deleted movable remained in the processing queue.")
	TEST_ASSERT(!(recipient in active_run), "A deleted movable remained in the current run.")
	TEST_ASSERT_EQUAL(active_run[other], other_throw, "Cleanup removed an unrelated throw from the current run.")
	TEST_ASSERT_EQUAL(SSthrowing.processing[other], other_throw, "Cleanup removed an unrelated throw from the processing queue.")
