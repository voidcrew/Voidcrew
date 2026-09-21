/**
 * A plumbed ship must still be plumbed after it docks (voidcrew/Voidcrew#342).
 *
 * Replays the real shuttle callbacks in initiate_docking()'s order - beforeShuttleMove,
 * onShuttleMove, afterShuttleMove (which rotates), lateShuttleMove - over a two-duct line
 * joining an input gate to an output gate, translated and turned 90 degrees, then checks
 * that every connection direction turned with the hull and that reagents still flow.
 *
 * Layout, machines facing SOUTH so their single pipe stub points at the duct below them:
 *
 *   before        after a 90 degree turn (dx, dy -> dy, -dx)
 *   I O           D1 I
 *   D1 D2         D2 O
 */
/datum/unit_test/voidcrew_plumbing_shuttle_move

/datum/unit_test/voidcrew_plumbing_shuttle_move/Run()
	var/turf/old_origin = run_loc_floor_bottom_left
	var/turf/new_origin = locate(old_origin.x + 3, old_origin.y + 3, old_origin.z)
	var/rotation = 90

	var/obj/machinery/duct/duct_one = allocate(/obj/machinery/duct, old_origin)
	var/obj/machinery/duct/duct_two = allocate(/obj/machinery/duct, get_step(old_origin, EAST))
	// The second duct's connection back to the first is normally finished by a timer.
	duct_one.attempt_connect()
	var/obj/machinery/plumbing/input/input = allocate(/obj/machinery/plumbing/input, get_step(old_origin, NORTH))
	var/obj/machinery/plumbing/output/output = allocate(/obj/machinery/plumbing/output, get_step(duct_two, NORTH))
	// Plumbing components allow duplicates, so GetComponent() would stack_trace.
	var/datum/component/plumbing/input_plumbing = input.GetComponents(/datum/component/plumbing)[1]
	var/datum/component/plumbing/output_plumbing = output.GetComponents(/datum/component/plumbing)[1]

	// Fixture sanity: one network joining both gates before anything moves.
	TEST_ASSERT_NOTNULL(duct_one.duct, "Adjacent ducts must form a ductnet.")
	TEST_ASSERT_EQUAL(duct_one.duct, duct_two.duct, "Adjacent ducts must share one ductnet.")
	TEST_ASSERT_EQUAL(duct_one.connects, EAST | NORTH, "The first duct must join its neighbour and the input gate.")
	TEST_ASSERT_EQUAL(duct_two.connects, WEST | NORTH, "The second duct must join its neighbour and the output gate.")
	TEST_ASSERT(input_plumbing.active, "A bolted input gate must start active.")
	TEST_ASSERT_EQUAL(input_plumbing.ducts[num2text(SOUTH)], duct_one.duct, "The input gate must register with the ductnet through its south stub.")
	TEST_ASSERT_EQUAL(output_plumbing.ducts[num2text(SOUTH)], duct_two.duct, "The output gate must register with the ductnet through its south stub.")
	// SSplumbing may also be pulling for the output gate, so only ever check that flow happened.
	input.reagents.add_reagent(/datum/reagent/water, 40)
	output.reagents.clear_reagents()
	output_plumbing.process_request(amount = 10, dir = SOUTH)
	TEST_ASSERT(output.reagents.total_volume > 0, "Reagents must flow across the fixture before the move.")

	// A move that aborts after preflight must leave the hull exactly as it was.
	var/list/movers = list(duct_one, duct_two, input, output)
	for(var/atom/movable/mover as anything in movers)
		mover.beforeShuttleMove(shuttle_destination(mover, old_origin, new_origin), rotation, MOVE_AREA, null)
	TEST_ASSERT(!input_plumbing.active, "beforeShuttleMove() must disconnect a carried plumbing machine while the layout is intact.")
	TEST_ASSERT(input_plumbing.owes_shuttle_reconnect, "A machine disconnected for a shuttle move must remember to reconnect.")
	TEST_ASSERT_EQUAL(duct_one.connects, EAST, "Disconnecting the input gate must drop the duct's stub towards it.")
	for(var/atom/movable/mover as anything in movers)
		for(var/datum/component/plumbing/plumber as anything in mover.GetComponents(/datum/component/plumbing))
			plumber.reconnect_after_shuttle_move()
	TEST_ASSERT(input_plumbing.active, "An aborted move must re-enable the machines it disconnected.")
	TEST_ASSERT(!input_plumbing.owes_shuttle_reconnect, "Reconnecting must clear the pending flag.")
	TEST_ASSERT_EQUAL(input_plumbing.ducts[num2text(SOUTH)], duct_one.duct, "An aborted move must restore the input gate's network in place.")
	TEST_ASSERT_EQUAL(duct_one.connects, EAST | NORTH, "An aborted move must restore the duct's stub towards the input gate.")

	// The real thing: translate and rotate.
	var/list/old_turfs = list()
	for(var/atom/movable/mover as anything in movers)
		old_turfs[mover] = get_turf(mover)
		mover.beforeShuttleMove(shuttle_destination(mover, old_origin, new_origin), rotation, MOVE_AREA, null)
	for(var/atom/movable/mover as anything in movers)
		mover.onShuttleMove(shuttle_destination(mover, old_origin, new_origin), old_turfs[mover], list(), EAST, null, null)
	for(var/atom/movable/mover as anything in movers)
		mover.afterShuttleMove(old_turfs[mover], list(), EAST, EAST, EAST, rotation)
	for(var/atom/movable/mover as anything in movers)
		mover.lateShuttleMove(old_turfs[mover], list(), EAST)

	TEST_ASSERT_EQUAL(get_turf(duct_one), new_origin, "The fixture must have landed where the test expects it.")
	TEST_ASSERT_EQUAL(get_turf(input), get_step(new_origin, EAST), "A turned hull must put the input gate east of its duct.")
	TEST_ASSERT_EQUAL(input.dir, WEST, "The input gate must turn with the hull.")
	TEST_ASSERT(input_plumbing.active, "The input gate must be active again once the move has landed.")
	TEST_ASSERT(output_plumbing.active, "The output gate must be active again once the move has landed.")
	TEST_ASSERT_EQUAL(input_plumbing.supply_connects, WEST, "The input gate's supply stub must point at its duct after the turn.")
	TEST_ASSERT_EQUAL(output_plumbing.demand_connects, WEST, "The output gate's demand stub must point at its duct after the turn.")
	TEST_ASSERT_EQUAL(duct_one.connects, SOUTH | EAST, "The first duct's connections must turn with the hull.")
	TEST_ASSERT_EQUAL(duct_two.connects, NORTH | EAST, "The second duct's connections must turn with the hull.")
	TEST_ASSERT_EQUAL(duct_one.neighbours[duct_two], SOUTH, "The first duct must remember which way its neighbour now lies.")
	TEST_ASSERT_EQUAL(duct_two.neighbours[duct_one], NORTH, "The second duct must remember which way its neighbour now lies.")
	TEST_ASSERT_NOTNULL(duct_one.duct, "The ductnet must survive the move.")
	TEST_ASSERT_EQUAL(duct_one.duct, duct_two.duct, "Both ducts must still share one ductnet after the move.")
	TEST_ASSERT_EQUAL(input_plumbing.ducts[num2text(WEST)], duct_one.duct, "The input gate must rejoin the ductnet through its turned stub.")
	TEST_ASSERT_EQUAL(output_plumbing.ducts[num2text(WEST)], duct_two.duct, "The output gate must rejoin the ductnet through its turned stub.")
	TEST_ASSERT_NULL(input_plumbing.ducts[num2text(SOUTH)], "The input gate must not keep a pre-rotation ductnet entry.")
	output.reagents.clear_reagents()
	output_plumbing.process_request(amount = 10, dir = WEST)
	TEST_ASSERT(output.reagents.total_volume > 0, "Reagents must still flow from gate to gate after the move.")

	// The per-layer pixel stagger is not geometry and must not spin with the hull.
	var/obj/machinery/duct/staggered = allocate(/obj/machinery/duct, get_step(new_origin, NORTH), FALSE, null, FIFTH_DUCT_LAYER)
	var/stagger_x = staggered.pixel_x
	var/stagger_y = staggered.pixel_y
	TEST_ASSERT_NOTEQUAL(stagger_x, 0, "The fifth duct layer must be drawn with a pixel stagger for this check to mean anything.")
	staggered.shuttleRotate(rotation)
	TEST_ASSERT_EQUAL(staggered.pixel_x, stagger_x, "Rotating a duct must keep its layer stagger on x.")
	TEST_ASSERT_EQUAL(staggered.pixel_y, stagger_y, "Rotating a duct must keep its layer stagger on y.")

/// Where a 90 degree clockwise turn about old_origin, re-based on new_origin, puts a mover.
/datum/unit_test/voidcrew_plumbing_shuttle_move/proc/shuttle_destination(atom/movable/mover, turf/old_origin, turf/new_origin)
	var/turf/old_turf = get_turf(mover)
	var/dx = old_turf.x - old_origin.x
	var/dy = old_turf.y - old_origin.y
	return locate(new_origin.x + dy, new_origin.y - dx, new_origin.z)
