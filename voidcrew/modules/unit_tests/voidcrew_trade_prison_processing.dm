/**
 * Processing, on Quartermain Depot's mapped lockup: the two-door room everyone joins and leaves the cell block
 * through. Nothing here waits for a walk: the tests put the prisoner where their own legs would have taken them
 * and call processing_tick(). The doors are real airlocks, so the tests wait for them to open and shut.
 */
/datum/unit_test/voidcrew_trade_prison_processing
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_trade_prison_processing/proc/door_is_open(obj/machinery/door/airlock/door)
	return !door.density && !door.operating

/datum/unit_test/voidcrew_trade_prison_processing/proc/door_is_shut(obj/machinery/door/airlock/door)
	return door.density && !door.operating

/// Ticks Processing once a second for up to `seconds`, until `door` is open (or shut), checking all the while that the two doors are never open together
/datum/unit_test/voidcrew_trade_prison_processing/proc/work_until(datum/outpost_prison/prison, obj/machinery/door/airlock/door, open, seconds = 12)
	var/obj/machinery/door/airlock/inner = prison.processing_door(TRUE)
	var/obj/machinery/door/airlock/outer = prison.processing_door(FALSE)
	for(var/i in 1 to seconds * 2)
		TEST_ASSERT(inner.density || outer.density, "Both of Processing's doors were open at once")
		if(open ? door_is_open(door) : door_is_shut(door))
			return TRUE
		if(i % 2)
			prison.processing_tick(1)
		sleep(0.5 SECONDS)
	return FALSE

/datum/unit_test/voidcrew_trade_prison_processing/Run()
	var/obj/structure/overmap/trader_outpost/outpost = lockup_test_outpost()
	TEST_ASSERT_NOTNULL(outpost, "Quartermain Depot's interior did not load")
	var/datum/outpost_prison/prison = outpost.prison
	TEST_ASSERT_NOTNULL(prison, "Quartermain Depot has no lockup")
	var/obj/machinery/door/airlock/security/prison_staff/processing/inner = prison.processing_door(TRUE)
	var/obj/machinery/door/airlock/security/prison_staff/processing/outer = prison.processing_door(FALSE)
	TEST_ASSERT(prison.processing_free(), "Processing is not free in a wing nobody has used")
	TEST_ASSERT_EQUAL(prison.processing_state, "idle", "Processing starts [prison.processing_state], not idle") // OUTPOST_PROCESSING_IDLE

	// Nobody's ID opens Processing's doors: not a guard's, not a player's
	var/mob/living/carbon/human/squatter = make_player(prison.alcove_turfs[1], "lockupsquatter")
	TEST_ASSERT(!outer.allowed(squatter), "Processing's outer door would open for a player")
	TEST_ASSERT(!inner.allowed(squatter), "Processing's inner door would open for a player")

	// A prisoner in the yard, their time up
	var/datum/outpost_prison_cell/first_cell = prison.cells[1]
	var/mob/living/carbon/human/npc/outpost_prisoner/leaver = new(first_cell.arrival_turf())
	prison.admit(leaver, first_cell)
	var/mob/living/carbon/human/npc/outpost_prisoner/bystander = new(prison.cells[2].arrival_turf())
	prison.admit(bystander, prison.cells[2])
	TEST_ASSERT(!inner.lets_prisoner(leaver), "Processing's inner door lets a prisoner through who is going nowhere")

	// With a player standing in the room nothing starts: no arrival is put in, and nobody is called in to leave.
	// Neither door opens or paths for them: only code works Processing's doors.
	squatter.forceMove(prison.processing_turfs[2])
	TEST_ASSERT(!outer.allowed(squatter), "Processing's outer door would open for a player inside")
	TEST_ASSERT(!inner.allowed(squatter), "Processing's inner door would let an inside player into the yard")
	TEST_ASSERT(!outer.CanAStarPass(EAST, new /datum/can_pass_info(squatter)), "Processing's shut outer door allowed JPS pathing")
	TEST_ASSERT(!inner.CanAStarPass(WEST, new /datum/can_pass_info(squatter)), "Processing's shut inner door allowed JPS pathing into the yard")
	TEST_ASSERT(!prison.processing_free(), "Processing is free with a player standing in it")
	TEST_ASSERT(!prison.processing_send_in(bystander), "Someone was put into Processing with a player standing in it")
	TEST_ASSERT_EQUAL(get_turf(bystander), prison.cells[2].arrival_turf(), "A refused arrival was moved")
	var/datum/weakref/leaver_ref = WEAKREF(leaver)
	TEST_ASSERT(prison.release(leaver), "A prisoner could not be released")
	TEST_ASSERT_EQUAL(leaver.phase, "leaving", "A released prisoner is [leaver.phase], not leaving") // PRISONER_LEAVING
	TEST_ASSERT(leaver in prison.processing_leavers, "A released prisoner is not waiting for Processing")
	TEST_ASSERT(!leaver.routine_allowed(), "A prisoner on their way out still has a routine")
	TEST_ASSERT(!leaver.may_speak(), "A prisoner on their way out can still chat")
	for(var/i in 1 to 3)
		prison.processing_tick(1)
	TEST_ASSERT_EQUAL(prison.processing_state, "idle", "Processing started on someone with a player standing in it")
	TEST_ASSERT(door_is_shut(inner) && door_is_shut(outer), "A door of Processing moved with a player standing in it")
	squatter.forceMove(prison.alcove_turfs[1])
	TEST_ASSERT(!inner.CanAStarPass(SOUTH, null) && !outer.CanAStarPass(NORTH, null), "Processing doors passed CanAStarPass with null pass_info")
	var/obj/structure/closet/hideout = allocate(/obj/structure/closet, prison.processing_turfs[1])
	squatter.forceMove(hideout)
	TEST_ASSERT(prison.processing_player_inside(), "A player shut inside a closet in Processing was missed")
	TEST_ASSERT(!prison.processing_free(), "Processing looked free with a player inside a closet")
	squatter.forceMove(prison.alcove_turfs[1])
	TEST_ASSERT_EQUAL(prison.processing_spot(), prison.processing_turfs[2], "processing_spot() picked a tile blocked by a closed closet")
	qdel(hideout)

	// The room is theirs: the inner door opens for them, with the outer shut, and for nobody else
	prison.processing_tick(1)
	TEST_ASSERT_EQUAL(prison.processing_state, "going_out", "Processing did not start on the prisoner waiting to leave") // OUTPOST_PROCESSING_OUT
	TEST_ASSERT_EQUAL(prison.processing_who(), leaver, "Processing is working for someone else")
	TEST_ASSERT(work_until(prison, inner, TRUE), "Processing's inner door never opened for a prisoner leaving from the yard")
	TEST_ASSERT(door_is_shut(outer), "Processing's outer door opened for a prisoner leaving from the yard")
	TEST_ASSERT(inner.lets_prisoner(leaver), "Processing's open inner door would not let the prisoner it opened for through")
	TEST_ASSERT(!inner.lets_prisoner(bystander), "Processing's open inner door would let another prisoner through")
	var/mob/living/carbon/human/npc/outpost_prison_guard/test_guard = allocate(/mob/living/carbon/human/npc/outpost_prison_guard, prison.guard_office_spot())
	test_guard.prison = prison
	var/mob/living/basic/bot/cleanbot/outpost_lockup/test_bot = allocate(/mob/living/basic/bot/cleanbot/outpost_lockup, prison.guard_office_spot())
	TEST_ASSERT(inner.CanAllowThrough(leaver, get_dir(leaver, inner)), "Processing's open inner door blocked the prisoner it opened for")
	TEST_ASSERT(!inner.CanAllowThrough(bystander, SOUTH), "Processing's open inner door let another prisoner step in")
	TEST_ASSERT(!inner.CanAllowThrough(squatter, SOUTH), "Processing's open inner door let a player step in from outside")
	TEST_ASSERT(!inner.CanAllowThrough(test_guard, SOUTH), "Processing's open inner door let a guard step in from outside")
	TEST_ASSERT(!inner.CanAllowThrough(test_bot, SOUTH), "Processing's open inner door let a cleanbot step in from outside")
	TEST_ASSERT(inner.CanAStarPass(SOUTH, new /datum/can_pass_info(leaver)), "Processing's open inner door refused JPS pathing to the prisoner it opened for")
	TEST_ASSERT(!inner.CanAStarPass(SOUTH, new /datum/can_pass_info(bystander)), "Processing's open inner door allowed JPS pathing to another prisoner")
	TEST_ASSERT(!inner.CanAStarPass(SOUTH, new /datum/can_pass_info(test_guard)), "Processing's open inner door allowed JPS pathing to a guard")
	TEST_ASSERT(!inner.CanAStarPass(SOUTH, new /datum/can_pass_info(test_bot)), "Processing's open inner door allowed JPS pathing to a cleanbot")
	test_guard.forceMove(prison.processing_turfs[2])
	TEST_ASSERT(inner.CanAStarPass(WEST, new /datum/can_pass_info(test_guard)), "Processing's open inner door blocked an inside guard's JPS pathing out")
	TEST_ASSERT(!outer.CanAStarPass(EAST, new /datum/can_pass_info(test_guard)), "Processing's shut outer door allowed JPS pathing while the inner door was open")
	test_guard.forceMove(prison.guard_office_spot())
	test_guard.prison = null
	prison.processing_tick(1)
	TEST_ASSERT(leaver.processing_goal in prison.processing_turfs, "A prisoner leaving was not sent into Processing")

	// In the room: nothing becomes of them until the door has shut behind them, and not while a player is in there with them
	leaver.forceMove(leaver.processing_goal)
	TEST_ASSERT(!outer.allowed(leaver), "Processing's outer door would open for a prisoner inside")
	squatter.forceMove(prison.processing_spot(leaver))
	TEST_ASSERT(!outer.allowed(squatter), "Processing's outer door would open for a player while the inner door was still open")
	TEST_ASSERT(inner.CanAllowThrough(squatter, NORTH), "A player already inside Processing could not step back out through an open door")
	squatter.forceMove(prison.alcove_turfs[1])
	prison.processing_tick(1)
	TEST_ASSERT(!is_qdeleted_ref(leaver_ref), "A prisoner was taken out of Processing with its inner door open")
	TEST_ASSERT(work_until(prison, inner, FALSE), "Processing's inner door never shut behind the prisoner")
	squatter.forceMove(prison.processing_spot(leaver))
	prison.processing_tick(1)
	prison.processing_tick(1)
	TEST_ASSERT(!is_qdeleted_ref(leaver_ref), "A prisoner was taken out of Processing with a player standing beside them")
	squatter.forceMove(prison.alcove_turfs[1])
	prison.processing_tick(1)
	TEST_ASSERT(is_qdeleted_ref(leaver_ref), "A prisoner shut in Processing was never taken away")
	TEST_ASSERT_EQUAL(prison.processing_state, "idle", "Processing is [prison.processing_state] after its job")
	TEST_ASSERT_NULL(first_cell.occupant, "The released prisoner's cell was not freed")
	TEST_ASSERT(!(bystander in prison.processing_leavers), "A prisoner who is staying is waiting to leave")
	leaver = null

	// An arrival: made in Processing with both doors shut, and nothing to the wing until they step out
	TEST_ASSERT(prison.processing_free(), "Processing is not free again after a release")
	var/mob/living/carbon/human/npc/outpost_prisoner/arrival = prison.admit_next(TRUE)
	TEST_ASSERT_NOTNULL(arrival, "No prisoner arrived with a cell free")
	TEST_ASSERT(prison.in_processing(arrival), "An arrival with someone at the outpost was not put in Processing")
	TEST_ASSERT_EQUAL(arrival.phase, "arriving", "An arrival in Processing is [arrival.phase], not arriving") // PRISONER_ARRIVING
	TEST_ASSERT_EQUAL(prison.processing_state, "going_in", "Processing is [prison.processing_state] with an arrival in it") // OUTPOST_PROCESSING_IN
	TEST_ASSERT(door_is_shut(inner) && door_is_shut(outer), "An arrival was put into Processing with a door open")
	TEST_ASSERT(!arrival.routine_allowed(), "An arrival shut in Processing has a routine")
	TEST_ASSERT(!arrival.may_speak(), "An arrival shut in Processing can chat")
	TEST_ASSERT_NULL(arrival.bubble, "An arrival shut in Processing shows a thought bubble")
	TEST_ASSERT(!prison.arrival_way_clear(), "A second arrival could come while Processing is busy")
	TEST_ASSERT_NULL(prison.admit_next(), "A second arrival came while Processing was busy")

	// The inner door opens, the outer stays shut, and they are sent to their cell
	TEST_ASSERT(work_until(prison, inner, TRUE), "Processing's inner door never opened for an arrival")
	TEST_ASSERT(door_is_shut(outer), "Processing's outer door opened for an arrival")
	prison.processing_tick(1)
	TEST_ASSERT_EQUAL(arrival.processing_goal, arrival.cell.arrival_turf(), "An arrival was not sent to their own cell")
	TEST_ASSERT_EQUAL(arrival.phase, "arriving", "An arrival still in Processing is [arrival.phase]")

	// In their cell: one of the wing's prisoners, Processing shut and free again
	arrival.forceMove(arrival.cell.arrival_turf())
	prison.processing_tick(1)
	TEST_ASSERT_EQUAL(arrival.phase, "present", "An arrival out of Processing is [arrival.phase], not present") // PRISONER_PRESENT
	TEST_ASSERT(arrival.walkable?[get_turf(arrival)], "An arrival out of Processing does not know the ground they stand on")
	TEST_ASSERT(work_until(prison, inner, FALSE), "Processing's inner door never shut after an arrival")
	TEST_ASSERT(door_is_shut(outer), "Processing's outer door is not shut after an arrival")
	TEST_ASSERT(prison.processing_free(), "Processing is not free after an arrival")
	TEST_ASSERT_EQUAL(prison.cell_at(get_turf(arrival)), arrival.cell, "The arrival is not in their own cell")

	// Leaving, and unable to get there (nothing walks in a test): gone from where they stand once no client has
	// been able to see them for a minute (OUTPOST_PRISON_LEAVE_UNSEEN 60), and not a second sooner
	var/datum/weakref/arrival_ref = WEAKREF(arrival)
	arrival.leave()
	prison.processing_tick(59)
	TEST_ASSERT(!is_qdeleted_ref(arrival_ref), "A prisoner leaving out of everyone's sight was gone early")
	prison.processing_tick(1)
	TEST_ASSERT(is_qdeleted_ref(arrival_ref), "A prisoner leaving out of everyone's sight was still there after a minute")
	arrival = null
	TEST_ASSERT(work_until(prison, inner, FALSE), "Processing's inner door was left open for someone who never came")
	TEST_ASSERT(work_until(prison, outer, FALSE), "Processing's outer door was left open")

	// While someone can see them, they stay: a client standing in the yard
	var/mob/living/carbon/human/npc/outpost_prisoner/watched = prison.admit_next(TRUE)
	TEST_ASSERT_NOTNULL(watched, "No prisoner arrived for the watched leaving")
	watched.forceMove(watched.cell.arrival_turf())
	prison.processing_tick(1)
	var/turf/cell_front = get_step(watched.cell.door_turf, get_dir(watched.cell.arrival_turf(), watched.cell.door_turf))
	var/mob/living/carbon/human/consistent/onlooker = allocate(/mob/living/carbon/human/consistent, cell_front)
	SSmobs.clients_by_zlevel[cell_front.z] += onlooker
	watched.forceMove(get_step(cell_front, get_dir(watched.cell.door_turf, cell_front)))
	TEST_ASSERT(prison.seen_by_client(watched), "A client two tiles off across open floor cannot see a prisoner")
	var/obj/structure/closet/viewer_closet = allocate(/obj/structure/closet, cell_front)
	onlooker.forceMove(viewer_closet)
	TEST_ASSERT(prison.seen_by_client(watched), "A client inside a container on an adjacent tile could not see a prisoner")
	onlooker.forceMove(cell_front)
	qdel(viewer_closet)
	var/datum/weakref/watched_ref = WEAKREF(watched)
	watched.leave()
	prison.processing_tick(120)
	prison.processing_tick(1)
	TEST_ASSERT(!is_qdeleted_ref(watched_ref), "A prisoner was taken from where they stood in front of a player")
	SSmobs.clients_by_zlevel[cell_front.z] -= onlooker
	squatter.forceMove(cell_front)
	squatter.start_pulling(watched)
	prison.processing_tick(60)
	TEST_ASSERT(!is_qdeleted_ref(watched_ref), "A leaving prisoner being pulled by a player was deleted unseen")
	squatter.stop_pulling()
	squatter.forceMove(prison.alcove_turfs[1])
	prison.processing_tick(60)
	TEST_ASSERT(is_qdeleted_ref(watched_ref), "A prisoner nobody could see any more was still there after a minute")
	watched = null

	// A leaver already outside the wing frees their cell at once, does not cycle the front-room door open, and clears once unseen for a minute
	var/mob/living/carbon/human/npc/outpost_prisoner/off_wing = prison.admit_next(TRUE)
	TEST_ASSERT_NOTNULL(off_wing, "No prisoner arrived for the off-wing leaving check")
	var/datum/outpost_prison_cell/off_wing_cell = off_wing.cell
	off_wing.forceMove(off_wing.cell.arrival_turf())
	prison.processing_tick(1)
	off_wing.forceMove(outpost.lobby_alcove_turfs[1])
	var/datum/weakref/off_wing_ref = WEAKREF(off_wing)
	off_wing.leave()
	TEST_ASSERT_NULL(off_wing_cell.occupant, "An off-wing leaver kept occupying their lockup cell")
	TEST_ASSERT_NULL(off_wing.cell, "An off-wing leaver kept a cell reference")
	prison.processing_tick(1)
	TEST_ASSERT_EQUAL(prison.processing_state, "idle", "Processing started on a leaver already outside the wing") // OUTPOST_PROCESSING_IDLE
	TEST_ASSERT(door_is_shut(inner) && door_is_shut(outer), "Processing opened a door for a leaver outside the wing")
	prison.processing_tick(59)
	TEST_ASSERT(is_qdeleted_ref(off_wing_ref), "An off-wing leaver unseen for a minute was not cleared")
	off_wing = null

	// A corpse shut inside Processing is cleared once both doors are shut, and an arrival dropped from the roster does not jam Processing
	prison.bodies_cleared = TRUE
	var/mob/living/carbon/human/npc/outpost_prisoner/dead_arrival = prison.admit_next(TRUE)
	TEST_ASSERT_NOTNULL(dead_arrival, "No prisoner arrived for the Processing corpse check")
	var/datum/outpost_prison_cell/dead_cell = dead_arrival.cell
	var/datum/weakref/dead_arrival_ref = WEAKREF(dead_arrival)
	dead_arrival.death()
	dead_arrival = null
	prison.tick(1)
	TEST_ASSERT_EQUAL(prison.processing_state, "idle", "A dead arrival left Processing in [prison.processing_state]")
	prison.processing_tick(1)
	TEST_ASSERT(is_qdeleted_ref(dead_arrival_ref), "An unseen corpse shut inside Processing was not cleared")
	TEST_ASSERT_NULL(dead_cell.occupant, "Clearing a corpse inside Processing did not free their cell")
	TEST_ASSERT(prison.processing_free(), "Processing stayed blocked after clearing a corpse inside")
	prison.bodies_cleared = FALSE
	var/mob/living/carbon/human/npc/outpost_prisoner/orphan = prison.admit_next(TRUE)
	TEST_ASSERT_NOTNULL(orphan, "No prisoner arrived for the orphaned arrival check")
	var/datum/weakref/orphan_ref = WEAKREF(orphan)
	prison.forget(orphan)
	orphan = null
	prison.processing_tick(1)
	TEST_ASSERT_EQUAL(prison.processing_state, "idle", "An arrival dropped from the roster left Processing stuck in [prison.processing_state]")
	TEST_ASSERT(is_qdeleted_ref(orphan_ref), "An unwatched arrival dropped from the roster was not cleared")

	// A prisoner leaving from the office can exit the staff door to the yard and Processing opens its inner door (never the front room's outer door); one whose escape ends in the front room uses the outer door
	var/obj/machinery/door/airlock/security/prison_staff/office_door = locate() in prison.guard_yard_doors()[1]
	TEST_ASSERT_NOTNULL(office_door, "No office staff airlock found on guard_yard_doors()")
	var/mob/living/carbon/human/npc/outpost_prisoner/office_leaver = prison.admit_next(TRUE)
	TEST_ASSERT_NOTNULL(office_leaver, "No prisoner arrived for the office-side leaving check")
	office_leaver.forceMove(office_leaver.cell.arrival_turf())
	prison.processing_tick(1)
	TEST_ASSERT(work_until(prison, inner, FALSE), "Processing's inner door did not shut after admitting office_leaver")
	var/datum/weakref/office_leaver_ref = WEAKREF(office_leaver)
	office_leaver.forceMove(prison.guard_office_spot())
	office_leaver.leave()
	TEST_ASSERT(office_door.allowed(office_leaver), "The office staff door refused to open for a leaving prisoner inside the office")
	TEST_ASSERT(office_door.lets_prisoner(office_leaver), "The office staff door would not let a leaving prisoner step out of the office")
	TEST_ASSERT(office_door.CanAllowThrough(office_leaver, SOUTH), "The office staff door blocked a leaving prisoner stepping out of the office")
	TEST_ASSERT(office_door.CanAStarPass(SOUTH, new /datum/can_pass_info(office_leaver)), "The office staff door refused JPS pathing out of the office to a leaving prisoner")
	office_leaver.forceMove(prison.processing_outside_turf(inner))
	TEST_ASSERT(!office_door.allowed(office_leaver) && !office_door.lets_prisoner(office_leaver), "The office staff door let a leaving prisoner already in the yard enter the office")
	office_leaver.forceMove(prison.guard_office_spot())
	prison.processing_tick(1)
	TEST_ASSERT_EQUAL(prison.processing_state, "going_out", "Processing did not start for a leaving prisoner in the office") // OUTPOST_PROCESSING_OUT
	TEST_ASSERT(work_until(prison, inner, TRUE), "Processing did not open its inner yard door for a prisoner leaving from the office")
	TEST_ASSERT(door_is_shut(outer), "Processing opened its front-room outer door for a prisoner still behind the office")
	prison.processing_tick(1)
	office_leaver.forceMove(office_leaver.processing_goal)
	prison.processing_tick(1)
	TEST_ASSERT(work_until(prison, inner, FALSE), "Processing's inner door did not shut behind the office leaver")
	prison.processing_tick(1)
	TEST_ASSERT(is_qdeleted_ref(office_leaver_ref), "The office leaver shut in Processing was not cleared")
	office_leaver = null
	TEST_ASSERT(prison.processing_free(), "Processing was not free after clearing the office leaver")

	var/mob/living/carbon/human/npc/outpost_prisoner/front_leaver = prison.admit_next(TRUE)
	TEST_ASSERT_NOTNULL(front_leaver, "No prisoner arrived for the front-room leaving check")
	front_leaver.forceMove(front_leaver.cell.arrival_turf())
	prison.processing_tick(1)
	TEST_ASSERT(work_until(prison, inner, FALSE), "Processing's inner door did not shut after admitting front_leaver")
	var/datum/weakref/front_leaver_ref = WEAKREF(front_leaver)
	front_leaver.forceMove(prison.processing_outside_turf(outer))
	front_leaver.leave()
	prison.processing_tick(1)
	TEST_ASSERT(work_until(prison, outer, TRUE), "Processing did not open its outer door for a prisoner leaving from the front room")
	TEST_ASSERT(door_is_shut(inner), "Processing opened its inner door for a prisoner leaving from the front room")
	prison.processing_tick(1)
	front_leaver.forceMove(front_leaver.processing_goal)
	prison.processing_tick(1)
	TEST_ASSERT(work_until(prison, outer, FALSE), "Processing's outer door did not shut behind the front-room leaver")
	prison.processing_tick(1)
	TEST_ASSERT(is_qdeleted_ref(front_leaver_ref), "The front-room leaver shut in Processing was not cleared")
	front_leaver = null
	TEST_ASSERT(prison.processing_free(), "Processing was not free after clearing the front-room leaver")

	// Breached outer Processing door defers mending shut while an outsider stands inside, while inner mends to seal the cell block
	inner.lockup_hack.breached_open = TRUE
	outer.lockup_hack.breached_open = TRUE
	INVOKE_ASYNC(inner, TYPE_PROC_REF(/obj/machinery/door/airlock, open), FORCING_DOOR_CHECKS)
	INVOKE_ASYNC(outer, TYPE_PROC_REF(/obj/machinery/door/airlock, open), FORCING_DOOR_CHECKS)
	sleep(2 SECONDS)
	TEST_ASSERT(!inner.density && !outer.density, "Setup: breached Processing doors did not open")
	squatter.forceMove(prison.processing_turfs[2])
	inner.mend_hack()
	outer.mend_hack()
	sleep(2 SECONDS)
	TEST_ASSERT(door_is_shut(inner), "Processing's breached inner door did not mend shut to seal the cell block")
	TEST_ASSERT(!outer.density, "Processing's breached outer door mended shut and entombed an outsider inside")
	squatter.forceMove(prison.alcove_turfs[1])
	outer.mend_hack()
	sleep(2 SECONDS)
	TEST_ASSERT(door_is_shut(outer), "Processing's outer door did not mend shut once the outsider stepped out")

	// Cleanbot never enters breached Processing on its own, and if dropped inside while idle, Processing opens inner (with outer shut) to let it out
	var/turf/inner_outside = prison.processing_outside_turf(inner)
	test_bot.forceMove(inner_outside)
	inner.lockup_hack.breached_open = TRUE
	INVOKE_ASYNC(inner, TYPE_PROC_REF(/obj/machinery/door/airlock, open), FORCING_DOOR_CHECKS)
	sleep(2 SECONDS)
	TEST_ASSERT(!inner.CanAllowThrough(test_bot, get_dir(test_bot, inner)), "Breached Processing inner door allowed an unpulled cleanbot to enter from outside")
	TEST_ASSERT(!inner.CanAStarPass(get_dir(test_bot, inner), new /datum/can_pass_info(test_bot)), "Breached Processing inner door allowed cleanbot JPS pathing from outside")
	inner.mend_hack()
	sleep(2 SECONDS)
	TEST_ASSERT(door_is_shut(inner), "Processing's inner door did not mend shut after the cleanbot check")
	test_bot.forceMove(prison.processing_turfs[2])
	TEST_ASSERT(work_until(prison, inner, TRUE), "Processing did not open its inner door to clear an abandoned cleanbot")
	TEST_ASSERT(door_is_shut(outer), "Processing opened its outer door while clearing an abandoned cleanbot")
	test_bot.forceMove(prison.guard_office_spot())
	TEST_ASSERT(work_until(prison, inner, FALSE), "Processing's inner door did not shut once the cleanbot cleared out")

	// An orphaned leaver already inside Processing while a player stood inside is cleared once the player leaves
	var/mob/living/carbon/human/npc/outpost_prisoner/trapped_orphan = prison.admit_next(TRUE)
	TEST_ASSERT_NOTNULL(trapped_orphan, "No prisoner arrived for the trapped orphan check")
	var/datum/weakref/trapped_orphan_ref = WEAKREF(trapped_orphan)
	squatter.forceMove(prison.processing_spot(trapped_orphan))
	prison.forget(trapped_orphan)
	trapped_orphan = null
	prison.processing_tick(1)
	TEST_ASSERT(!is_qdeleted_ref(trapped_orphan_ref) && prison.processing_state == "idle", "An orphaned arrival was removed while a player stood in Processing") // OUTPOST_PROCESSING_IDLE
	squatter.forceMove(prison.alcove_turfs[1])
	prison.processing_tick(1)
	prison.processing_tick(1)
	TEST_ASSERT(is_qdeleted_ref(trapped_orphan_ref) && prison.processing_free(), "An orphaned leaver left inside Processing jammed it after the player left")

	// A prison guard pushed into the front room claims Processing through walk_goal() to return to their post
	test_guard.forceMove(prison.processing_outside_turf(outer))
	test_guard.prison = prison
	test_guard.phase = "present" // OUTPOST_GUARD_PRESENT
	test_guard.give_response("leash", 1, "leash", null, prison.guard_office_spot(test_guard)) // OUTPOST_GUARD_PRIORITY_LEASH
	TEST_ASSERT_EQUAL(test_guard.walk_goal(), get_turf(test_guard), "A guard in the front room did not claim Processing through walk_goal()")
	TEST_ASSERT_EQUAL(prison.processing_state, "crossing", "A guard's walk_goal() in the front room did not start a Processing crossing") // OUTPOST_PROCESSING_CROSS
	test_guard.end_response(cancel_ai = FALSE)
	test_guard.prison = null
	test_guard.forceMove(prison.guard_office_spot())
	prison.processing_done()
	TEST_ASSERT(work_until(prison, outer, FALSE) && work_until(prison, inner, FALSE), "Processing did not return to shut doors after the guard check")

	// Two released inmates already inside shut Processing do not block each other from opening outer to step out
	var/mob/living/carbon/human/released_a = make_player(prison.processing_turfs[1], "lockuprelpaira")
	var/mob/living/carbon/human/released_b = make_player(prison.processing_turfs[2], "lockuprelpairb")
	prison.processing_release_refs |= list(WEAKREF(released_a), WEAKREF(released_b))
	TEST_ASSERT(prison.try_start_processing_release(released_a), "Two released inmates inside shut Processing deadlocked try_start_processing_release()")
	TEST_ASSERT_EQUAL(prison.processing_state, "releasing", "try_start_processing_release() inside Processing did not enter releasing") // OUTPOST_PROCESSING_RELEASE
	TEST_ASSERT(work_until(prison, outer, TRUE), "Processing did not open outer for two released inmates inside")
	TEST_ASSERT(door_is_shut(inner), "Processing opened inner while letting released inmates out")
	released_a.forceMove(prison.alcove_turfs[1])
	released_b.forceMove(prison.alcove_turfs[1])
	prison.processing_release_refs.Cut()
	prison.processing_done()
	TEST_ASSERT(work_until(prison, outer, FALSE), "Processing did not shut outer after the paired release check")
	released_a.key = null
	qdel(released_a)
	released_b.key = null
	qdel(released_b)

	// With nobody at the outpost an arrival is simply in their cell, and Processing is not used
	prison.audience_override = FALSE
	var/mob/living/carbon/human/npc/outpost_prisoner/quiet = prison.admit_next(TRUE)
	TEST_ASSERT_NOTNULL(quiet, "No prisoner arrived with nobody at the outpost")
	TEST_ASSERT_EQUAL(quiet.phase, "present", "An arrival nobody saw is [quiet.phase], not present")
	TEST_ASSERT_EQUAL(quiet.loc, quiet.cell.arrival_turf(), "An arrival nobody saw is not in their cell")
	TEST_ASSERT_EQUAL(prison.processing_state, "idle", "Processing was used with nobody at the outpost")
	prison.audience_override = TRUE

/// The wing with no Processing room (the fixture): arrivals are in their cells, and those leaving are gone at the next tick
/datum/unit_test/voidcrew_trade_prison_no_processing
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_trade_prison_no_processing/Run()
	var/obj/structure/overmap/trader_outpost/prison_test_host/home = prison_test_claim("lockupnoroom")
	TEST_ASSERT_NOTNULL(home, "The test wing did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	TEST_ASSERT(!prison.has_processing(), "The fixture wing has a Processing room")
	TEST_ASSERT(!prison.processing_free(), "A wing with no Processing room has a free one")
	TEST_ASSERT(prison.arrival_way_clear(), "A wing with no Processing room waits on it for arrivals")
	var/mob/living/carbon/human/npc/outpost_prisoner/arrival = prison.admit_next(TRUE)
	TEST_ASSERT_NOTNULL(arrival, "No prisoner arrived in the fixture wing")
	TEST_ASSERT_EQUAL(arrival.phase, "present", "An arrival in a wing with no Processing room is [arrival.phase]")
	TEST_ASSERT_EQUAL(arrival.loc, arrival.cell.arrival_turf(), "An arrival in a wing with no Processing room is not in their cell")
	var/datum/weakref/arrival_ref = WEAKREF(arrival)
	arrival.leave()
	TEST_ASSERT_EQUAL(arrival.phase, "leaving", "A prisoner told to leave is [arrival.phase]")
	TEST_ASSERT(!is_qdeleted_ref(arrival_ref), "A prisoner told to leave was gone before the wing's clock moved")
	arrival = null
	prison.processing_tick(1)
	TEST_ASSERT(is_qdeleted_ref(arrival_ref), "A prisoner leaving a wing with no Processing room was still there after a tick")
	TEST_ASSERT_EQUAL(length(prison.prisoners), 0, "A prisoner who left is still on the roster")
	settle_prison_air(home)
