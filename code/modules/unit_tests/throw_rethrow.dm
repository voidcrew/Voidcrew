/// Throwing something that is already airborne must end the previous throw instead of orphaning it.
/datum/unit_test/throw_rethrow

/datum/unit_test/throw_rethrow/Run()
	var/obj/item/thrown = allocate(/obj/item, run_loc_floor_bottom_left)
	var/alive_before = GLOB.thrownthing_alive

	thrown.throw_at(run_loc_floor_top_right, 3, 1, quickstart = FALSE)
	var/datum/thrownthing/first = thrown.throwing
	TEST_ASSERT_NOTNULL(first, "The first throw did not create a throw datum.")
	TEST_ASSERT_EQUAL(SSthrowing.processing[thrown], first, "The first throw was not queued.")
	TEST_ASSERT_EQUAL(GLOB.thrownthing_alive, alive_before + 1, "The first throw did not count itself as alive.")

	thrown.throw_at(run_loc_floor_top_right, 3, 1, quickstart = FALSE)
	var/datum/thrownthing/second = thrown.throwing
	TEST_ASSERT_NOTNULL(second, "The second throw did not create a throw datum.")
	TEST_ASSERT_NOTEQUAL(second, first, "The second throw reused the first throw datum.")
	TEST_ASSERT(QDELETED(first), "Re-throwing an airborne item left the superseded throw alive.")
	TEST_ASSERT_EQUAL(SSthrowing.processing[thrown], second, "The second throw is not the queued throw.")
	TEST_ASSERT_EQUAL(GLOB.thrownthing_alive, alive_before + 1, "Re-throwing did not release the superseded throw datum.")

	// A stale datum that is destroyed after being replaced must not release the live throw.
	var/datum/thrownthing/stale = allocate(/datum/thrownthing, thrown, run_loc_floor_top_right, NORTH, 3, 1)
	qdel(stale)
	TEST_ASSERT(QDELETED(stale), "The stale throw datum was not deleted.")
	TEST_ASSERT_EQUAL(thrown.throwing, second, "Destroying a stale throw datum cleared the live throw.")
	TEST_ASSERT_EQUAL(SSthrowing.processing[thrown], second, "Destroying a stale throw datum dequeued the live throw.")

	// Neither can a stale datum that finishes or ticks after being replaced.
	stale = allocate(/datum/thrownthing, thrown, run_loc_floor_top_right, NORTH, 3, 1)
	stale.finalize()
	TEST_ASSERT(QDELETED(stale), "A finalized stale throw datum was not deleted.")
	TEST_ASSERT_EQUAL(thrown.throwing, second, "Finalizing a stale throw datum cleared the live throw.")
	TEST_ASSERT_EQUAL(SSthrowing.processing[thrown], second, "Finalizing a stale throw datum dequeued the live throw.")

	stale = allocate(/datum/thrownthing, thrown, run_loc_floor_top_right, NORTH, 3, 1)
	stale.start_time = world.time
	var/turf/before_tick = thrown.loc
	stale.tick()
	TEST_ASSERT(QDELETED(stale), "A stale throw datum survived ticking.")
	TEST_ASSERT_EQUAL(thrown.loc, before_tick, "A stale throw datum moved the item.")
	TEST_ASSERT_EQUAL(thrown.throwing, second, "Ticking a stale throw datum cleared the live throw.")
	TEST_ASSERT_EQUAL(SSthrowing.processing[thrown], second, "Ticking a stale throw datum dequeued the live throw.")
	TEST_ASSERT_EQUAL(GLOB.thrownthing_alive, alive_before + 1, "Stale throw datums did not release themselves.")

	// The live throw still ends cleanly.
	qdel(second)
	TEST_ASSERT_NULL(thrown.throwing, "Ending the live throw left it on the item.")
	TEST_ASSERT(!(thrown in SSthrowing.processing), "Ending the live throw left the item queued.")
	TEST_ASSERT_EQUAL(GLOB.thrownthing_alive, alive_before, "Ending every throw did not return the alive count to its start.")
