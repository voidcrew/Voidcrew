// Stealth guards, decision 39 and the 2026-11-11 playtest fixes (voidcrew/modules/stealth/stealth_turns.dm,
// stealth_patrol.dm): readable turns, the grace after a turn, stop look-rounds and arrival facing. Values from
// voidcrew/_DEFINES are written out: STEALTH_TURN_TELL 0.6 s, STEALTH_LOOK_TURN_ARC 90; yellow turn_grace 1 s.
// States are written as text.

/// After a turn where it stands (to a noise, a door or on its own), someone right in front is not an instant alert;
/// notice still fills, and once the moment has passed they are.
/datum/unit_test/voidcrew_stealth_turn_grace

/datum/unit_test/voidcrew_stealth_turn_grace/Run()
	var/datum/turf_reservation/block = stealth_block(7, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/person = stealth_person(block, 4, 2)
	// "glance" is a noise or a door's glance; "suspicious" is a door seen moving or a noise worth a look.
	for(var/how in list("glance", "suspicious"))
		var/mob/living/carbon/human/npc/guard = stealth_guard(block, 3, 2, WEST)
		var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
		stealth_ai.stealth_setup()
		TEST_ASSERT(!stealth_ai.stealth_turn_grace(), "A guard that hasn't turned is in its turn grace")
		if(how == "glance")
			stealth_ai.stealth_glance(stealth_at(block, 6, 2))
		else
			stealth_ai.stealth_go_suspicious(stealth_at(block, 6, 2))
		TEST_ASSERT_EQUAL(guard.dir, EAST, "[how]: the guard didn't turn to face the spot")
		TEST_ASSERT(stealth_ai.stealth_turn_grace(), "[how]: a guard that just turned isn't in its turn grace")
		TEST_ASSERT(!stealth_ai.stealth_quick_look(), "[how]: the quick look made someone at its elbow an alert the moment it turned")
		stealth_scans(guard, 1)
		TEST_ASSERT(stealth_ai.stealth_state() != "alert", "[how]: someone at its elbow was an alert on the look right after it turned")
		var/list/entry = stealth_ai.notice_map[REF(person)]
		TEST_ASSERT(entry && entry[1] > 0, "[how]: notice didn't fill during the turn grace")
		// The moment passes: they are seen plainly.
		stealth_ai.turned_at = world.time - 2 SECONDS
		TEST_ASSERT(!stealth_ai.stealth_turn_grace(), "[how]: the turn grace outlasted its time")
		stealth_scans(guard, 1)
		TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "[how]: someone at its elbow wasn't an alert once the turn grace was over")
		qdel(guard)
	// A step is not a look round: turning by walking gives no grace.
	var/mob/living/carbon/human/npc/walker = stealth_guard(block, 1, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/walker_ai = stealth_ai(walker)
	walker_ai.stealth_setup()
	walker.Move(stealth_at(block, 1, 3), NORTH)
	TEST_ASSERT(!walker_ai.stealth_turn_grace(), "Turning by stepping gave a turn grace")
	qdel(block)

/// A turn on its own shows a lean first and lands after STEALTH_TURN_TELL; a change of state drops it.
/datum/unit_test/voidcrew_stealth_turn_tell

/datum/unit_test/voidcrew_stealth_turn_tell/Run()
	var/datum/turf_reservation/block = stealth_block(5, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	stealth_ai.stealth_setup()
	stealth_ai.stealth_turn_to(NORTH)
	TEST_ASSERT_EQUAL(guard.dir, EAST, "A guard turned on its own with no tell first")
	TEST_ASSERT_EQUAL(stealth_ai.turn_pending, NORTH, "No turn is pending after the tell started")
	TEST_ASSERT_NOTNULL(stealth_ai.turn_lean, "The tell shows no lean")
	sleep(0.8 SECONDS)
	TEST_ASSERT_EQUAL(guard.dir, NORTH, "The turn didn't land after its tell")
	TEST_ASSERT_NULL(stealth_ai.turn_lean, "The lean stayed on after the turn")
	// A turn that is overtaken by events is dropped, lean and all.
	stealth_ai.stealth_turn_to(WEST)
	stealth_ai.stealth_go_suspicious(stealth_at(block, 2, 0))
	TEST_ASSERT_EQUAL(stealth_ai.turn_pending, 0, "A change of state kept the pending turn")
	TEST_ASSERT_NULL(stealth_ai.turn_lean, "A dropped turn left its lean on")
	sleep(0.8 SECONDS)
	TEST_ASSERT_EQUAL(guard.dir, SOUTH, "A dropped turn still landed")
	qdel(block)

/// At a stop it looks left, back, right, back: a steady beat, not a coin toss.
/datum/unit_test/voidcrew_stealth_look_rounds

/datum/unit_test/voidcrew_stealth_look_rounds/Run()
	var/datum/turf_reservation/block = stealth_block(5, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	stealth_ai.stealth_setup()
	stealth_ai.route_id = "a" // a route guard, not a sentry
	stealth_ai.stand_dir = EAST
	var/datum/ai_behavior/stealth_stand/stand = GET_AI_BEHAVIOR(/datum/ai_behavior/stealth_stand)
	var/list/seen = list()
	for(var/i in 1 to 4)
		stealth_ai.next_turn = 0
		stand.perform(1, stealth_ai)
		sleep(0.8 SECONDS)
		seen += dir2text(guard.dir)
	TEST_ASSERT_EQUAL(jointext(seen, ","), "north,east,south,east", "A guard at a stop looked [jointext(seen, ",")] instead of left, back, right, back")
	qdel(block)

/// A guard arrives at a stop facing the way it walked, unless the stop sets a facing (then it turns, with a tell).
/datum/unit_test/voidcrew_stealth_arrival_facing

/datum/unit_test/voidcrew_stealth_arrival_facing/Run()
	var/datum/turf_reservation/block = stealth_block(5, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, stealth_at(block, 4, 4))
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	stealth_ai.stealth_setup()
	var/datum/stealth_stop/plain = new
	plain.spot = get_turf(guard)
	stealth_ai.stealth_arrive(plain)
	TEST_ASSERT_EQUAL(guard.dir, WEST, "A guard turned at a stop with no facing set")
	TEST_ASSERT_EQUAL(stealth_ai.stand_dir, WEST, "A guard at a stop with no facing doesn't keep the way it walked")
	TEST_ASSERT_EQUAL(stealth_ai.turn_pending, 0, "A guard at a stop with no facing is about to turn")
	var/datum/stealth_stop/faced = new
	faced.spot = get_turf(guard)
	faced.dir = NORTH
	stealth_ai.stealth_arrive(faced)
	TEST_ASSERT_EQUAL(stealth_ai.stand_dir, NORTH, "A stop's facing wasn't taken")
	TEST_ASSERT_EQUAL(stealth_ai.turn_pending, NORTH, "A guard turned to a stop's facing with no tell")
	sleep(0.8 SECONDS)
	TEST_ASSERT_EQUAL(guard.dir, NORTH, "A guard didn't turn to its stop's facing")
	qdel(block)
