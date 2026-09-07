/datum/unit_test/shuttle_load_ownership
	var/datum/shuttle_template_load/held_owner
	var/obj/docking_port/stationary/load_ownership_test/empty_port
	var/obj/structure/overmap/ship/context_ship
	var/waiter_finished = FALSE
	var/waiter_result
	var/operation_calls = 0
	var/operation_had_owner = FALSE

/datum/unit_test/shuttle_load_ownership/Destroy()
	if(held_owner)
		SSshuttle.release_template_load(held_owner)
	if(!QDELETED(empty_port))
		qdel(empty_port, force = TRUE)
	return ..()

/datum/unit_test/shuttle_load_ownership/Run()
	context_ship = allocate(/obj/structure/overmap/ship)
	empty_port = allocate(/obj/docking_port/stationary/load_ownership_test)
	held_owner = SSshuttle.acquire_template_load(1 MINUTES)
	TEST_ASSERT(held_owner, "The loader could not acquire ownership after waiting for background loads.")
	var/original_can_fire = held_owner.previous_air_can_fire
	var/obj/structure/overmap/ship/original_loading_ship = held_owner.previous_loading_ship
	SSair.can_fire = FALSE
	SSshuttle.loading_ship = context_ship

	// An empty transit/berth port must not queue behind this load or release its lock.
	SSshuttle.setup_shuttle_late(empty_port)
	TEST_ASSERT_EQUAL(empty_port.load_calls, 0, "A port without a template entered the load queue.")
	TEST_ASSERT_EQUAL(SSshuttle.active_template_load, held_owner, "An empty port replaced another operation's owner.")
	TEST_ASSERT(SSshuttle.shuttle_loading, "An empty port cleared another operation's loading flag.")

	// A bounded waiter must refuse without invoking its operation or touching the owner.
	INVOKE_ASYNC(src, PROC_REF(run_waiter), 2)
	UNTIL(waiter_finished)
	TEST_ASSERT(!waiter_result && !operation_calls, "A waiting operation ran while another owner held the preview.")
	TEST_ASSERT_EQUAL(SSshuttle.active_template_load, held_owner, "A timed-out waiter released the active owner.")
	TEST_ASSERT(SSshuttle.shuttle_loading, "A timed-out waiter cleared the active load flag.")
	TEST_ASSERT_EQUAL(SSshuttle.loading_ship, context_ship, "A timed-out waiter replaced the active ship context.")
	TEST_ASSERT(!SSair.can_fire, "A timed-out waiter resumed atmos during another load.")
	var/datum/shuttle_template_load/other_owner = new
	TEST_ASSERT(!SSshuttle.release_template_load(other_owner), "An unrelated owner was allowed to release the preview.")
	TEST_ASSERT_EQUAL(SSshuttle.active_template_load, held_owner, "Releasing the wrong owner changed the active operation.")
	TEST_ASSERT_EQUAL(SSshuttle.run_template_load(CALLBACK(src, PROC_REF(successful_operation)), held_owner), 73, "A nested operation lost its result.")
	TEST_ASSERT_EQUAL(SSshuttle.active_template_load, held_owner, "A nested operation released its caller's ownership.")
	TEST_ASSERT(!SSair.can_fire, "A nested operation restored atmos before its caller finished.")
	operation_calls = 0

	// A successful waiter must only enter after the first owner explicitly releases.
	waiter_finished = FALSE
	INVOKE_ASYNC(src, PROC_REF(run_waiter))
	TEST_ASSERT(!waiter_finished, "The second operation did not wait for the owner.")
	SSshuttle.release_template_load(held_owner)
	held_owner = null
	UNTIL(waiter_finished)
	TEST_ASSERT_EQUAL(waiter_result, 73, "A released waiter lost the operation's result.")
	TEST_ASSERT_EQUAL(operation_calls, 1, "The waiting operation did not run exactly once.")
	TEST_ASSERT(operation_had_owner, "The operation ran without owning the loading flag.")
	TEST_ASSERT(!SSshuttle.shuttle_loading && !SSshuttle.active_template_load, "Normal completion stranded loader ownership.")
	TEST_ASSERT_EQUAL(SSair.can_fire, original_can_fire, "Normal completion did not restore the original atmos state.")
	TEST_ASSERT_EQUAL(SSshuttle.loading_ship, original_loading_ship, "Normal completion did not restore the original ship context.")

	// A refusal still restores the context changed by its operation.
	TEST_ASSERT(!SSshuttle.run_template_load(CALLBACK(src, PROC_REF(refused_operation))), "The refused operation unexpectedly succeeded.")
	TEST_ASSERT(!SSshuttle.shuttle_loading && !SSshuttle.active_template_load, "An early refusal stranded loader ownership.")
	TEST_ASSERT_EQUAL(SSair.can_fire, original_can_fire, "An early refusal did not restore the original atmos state.")
	TEST_ASSERT_EQUAL(SSshuttle.loading_ship, original_loading_ship, "An early refusal did not restore the original ship context.")

/datum/unit_test/shuttle_load_ownership/proc/run_waiter(wait_timeout = null)
	waiter_result = SSshuttle.run_template_load(CALLBACK(src, PROC_REF(successful_operation)), wait_timeout = wait_timeout)
	waiter_finished = TRUE

/datum/unit_test/shuttle_load_ownership/proc/successful_operation(datum/shuttle_template_load/load_owner)
	operation_calls++
	operation_had_owner = SSshuttle.shuttle_loading && SSshuttle.active_template_load == load_owner
	return 73

/datum/unit_test/shuttle_load_ownership/proc/refused_operation(datum/shuttle_template_load/load_owner)
	held_owner = load_owner
	SSair.can_fire = FALSE
	SSshuttle.loading_ship = context_ship
	return FALSE

/obj/docking_port/stationary/load_ownership_test
	name = "empty loader test port"
	var/load_calls = 0

/obj/docking_port/stationary/load_ownership_test/load_roundstart()
	load_calls++
