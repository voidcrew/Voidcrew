/// Exercise real drift handlers without gravity or nearby walls stopping the fixture.
/obj/drift_vector_test/Process_Spacemove(movement_dir = NONE, continuous_move = FALSE)
	return FALSE

/datum/unit_test/drift_stabilization_vectors/Run()
	for(var/direction in GLOB.cardinals)
		var/obj/drift_vector_test/drifter = allocate(/obj/drift_vector_test, run_loc_floor_bottom_left)
		var/angle = dir2angle(direction)
		drifter.newtonian_move(angle, start_delay = 1 MINUTES, drift_force = 2)
		TEST_ASSERT(drifter.drift_handler, "Failed to start drift toward [direction].")
		// At half the requested speed, the forward projection exactly cancels the correction.
		drifter.drift_handler.stabilize_drift(angle, 4, 10)
		TEST_ASSERT(drifter.drift_handler, "Stabilization stopped forward drift toward [direction].")
		TEST_ASSERT(abs(drifter.drift_handler.drift_force - 2) < 0.01, "Stabilization changed forward speed toward [direction] to [drifter.drift_handler.drift_force].")
		TEST_ASSERT(abs(sin(drifter.drift_handler.drifting_loop.angle) - sin(angle)) < 0.01 && abs(cos(drifter.drift_handler.drifting_loop.angle) - cos(angle)) < 0.01, "Stabilization changed the requested heading [direction].")
		qdel(drifter)

/datum/unit_test/drift_stabilization_crosswind/Run()
	var/obj/drift_vector_test/drifter = allocate(/obj/drift_vector_test, run_loc_floor_bottom_left)
	drifter.newtonian_move(dir2angle(EAST), start_delay = 1 MINUTES, drift_force = 2)
	TEST_ASSERT(drifter.drift_handler, "Failed to start eastward drift.")
	// Starting at (2, 0), remove the crosswind relative to a requested (2, 2).
	// This preserves the forward projection and leaves (1, 1), not an impulse due north.
	drifter.drift_handler.stabilize_drift(45, sqrt(8), 10)
	TEST_ASSERT(drifter.drift_handler, "Crosswind stabilization removed forward drift.")
	var/datum/drift_handler/handler = drifter.drift_handler
	TEST_ASSERT(abs(sin(handler.drifting_loop.angle) * handler.drift_force - 1) < 0.01, "Crosswind stabilization did not leave eastward velocity 1.")
	TEST_ASSERT(abs(cos(handler.drifting_loop.angle) * handler.drift_force - 1) < 0.01, "Crosswind stabilization did not leave northward velocity 1.")

/datum/unit_test/drift_released_pull_vectors/Run()
	for(var/angle in list(0, 45, 90, 180, 270))
		var/obj/drift_vector_test/puller = allocate(/obj/drift_vector_test, run_loc_floor_bottom_left)
		var/obj/drift_vector_test/released = allocate(/obj/drift_vector_test, run_loc_floor_bottom_left)
		puller.newtonian_move(angle, start_delay = 1 MINUTES, drift_force = 3)
		TEST_ASSERT(puller.drift_handler, "Failed to start the puller's drift.")
		SEND_SIGNAL(puller, COMSIG_ATOM_NO_LONGER_PULLING, released)
		TEST_ASSERT(released.drift_handler, "Releasing a pulled object did not preserve its drift.")
		TEST_ASSERT(abs(released.drift_handler.drift_force - 3) < 0.01, "Releasing a pulled object changed its speed.")
		TEST_ASSERT(abs(sin(released.drift_handler.drifting_loop.angle) - sin(angle)) < 0.01 && abs(cos(released.drift_handler.drifting_loop.angle) - cos(angle)) < 0.01, "Releasing an object drifting at [angle] degrees changed its heading to [released.drift_handler.drifting_loop.angle].")
		qdel(puller)
		qdel(released)

/datum/unit_test/drift_tether_vectors/Run()
	var/obj/drift_vector_test/drifter = allocate(/obj/drift_vector_test, run_loc_floor_bottom_left)
	drifter.newtonian_move(delta_to_angle(3, 4), start_delay = 1 MINUTES, drift_force = 5)
	TEST_ASSERT(drifter.drift_handler, "Failed to start diagonal drift.")
	// A taut tether blocks only outward motion, leaving the tangential component intact.
	drifter.drift_handler.remove_angle_force(dir2angle(EAST))
	TEST_ASSERT(drifter.drift_handler, "Removing outward drift also removed tangential motion.")
	var/datum/drift_handler/handler = drifter.drift_handler
	TEST_ASSERT(abs(handler.drift_force - 4) < 0.01, "Removing eastward drift left speed [handler.drift_force] instead of 4.")
	TEST_ASSERT(abs(sin(handler.drifting_loop.angle)) < 0.01 && cos(handler.drifting_loop.angle) > 0.99, "Removing eastward drift did not leave northward motion.")
	handler.remove_angle_force(dir2angle(SOUTH))
	TEST_ASSERT(abs(handler.drift_force - 4) < 0.01, "A tether opposing the direction of travel changed inward motion.")
	handler.remove_angle_force(dir2angle(NORTH))
	TEST_ASSERT(QDELETED(drifter.drift_handler), "Removing the remaining outward drift did not stop the object.")
