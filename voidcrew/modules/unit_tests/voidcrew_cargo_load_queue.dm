/// Cancellation while waiting for another ship's map must not create a late ferry.
/datum/unit_test/voidcrew_cargo_load_queue
	var/datum/shuttle_template_load/held_owner
	var/finished = FALSE
	var/spawn_result

/datum/unit_test/voidcrew_cargo_load_queue/Destroy()
	if(held_owner)
		SSshuttle.release_template_load(held_owner)
	return ..()

/datum/unit_test/voidcrew_cargo_load_queue/Run()
	var/datum/voidcrew_cargo_shuttle/ferry = allocate(/datum/voidcrew_cargo_shuttle)
	held_owner = SSshuttle.acquire_template_load(1 MINUTES)
	TEST_ASSERT(held_owner, "Could not acquire the shared load queue for the cancellation check")
	ferry.state = 1 // CARGO_SHUTTLE_ARRIVING (fork defines follow unit-test includes).
	INVOKE_ASYNC(src, PROC_REF(run_spawn), ferry)
	TEST_ASSERT(!finished && ferry.load_pending, "Freight did not wait for the active template load")
	TEST_ASSERT_NULL(ferry.shuttle_port, "A waiting ferry already loaded a physical hull")
	TEST_ASSERT(!ferry.spawn_shuttle(), "A second spawn entered the same pending ferry")
	ferry.cleanup_shuttle()
	TEST_ASSERT_EQUAL(ferry.call_shuttle(null), "Cargo shuttle is not available", "Cancelled freight accepted another dispatch before its queued load returned")
	SSshuttle.release_template_load(held_owner)
	held_owner = null
	UNTIL(finished)
	TEST_ASSERT(!spawn_result && !ferry.load_pending, "A cancelled ferry resumed its template load")
	TEST_ASSERT_NULL(ferry.shuttle_port, "Cancellation left a physical ferry")
	TEST_ASSERT_NULL(ferry.transit_reservation, "Cancellation allocated transit capacity")
	TEST_ASSERT(!SSshuttle.shuttle_loading && !SSshuttle.active_template_load, "Cancelled freight stranded shared loader ownership")

	// Deleting the claimant while it waits must also leave the shared queue usable.
	held_owner = SSshuttle.acquire_template_load(1 MINUTES)
	TEST_ASSERT(held_owner, "Could not reacquire the shared load queue for the deletion check")
	ferry.state = 1 // CARGO_SHUTTLE_ARRIVING.
	finished = FALSE
	INVOKE_ASYNC(src, PROC_REF(run_spawn), ferry)
	TEST_ASSERT(!finished && ferry.load_pending, "The deletion check did not enter the waiting state")
	qdel(ferry)
	SSshuttle.release_template_load(held_owner)
	held_owner = null
	UNTIL(finished)
	TEST_ASSERT(!spawn_result, "Deleted freight resumed its template load")
	TEST_ASSERT(!SSshuttle.shuttle_loading && !SSshuttle.active_template_load, "Deleted freight stranded shared loader ownership")

/datum/unit_test/voidcrew_cargo_load_queue/proc/run_spawn(datum/voidcrew_cargo_shuttle/ferry)
	spawn_result = ferry.spawn_shuttle()
	finished = TRUE
