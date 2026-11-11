// Stealth guards, owner decision 32 (voidcrew/modules/stealth/): point-blank sight, behind in the dark, the overdue
// line over a body already reported, guards' lights ignoring each other, and a running guard's pace. Values from
// voidcrew/_DEFINES are written out: STEALTH_POINT_BLANK_RANGE 2, STEALTH_NEAR_RANGE 4, STEALTH_NEAR_MULT 3,
// STEALTH_ALERT_AT 2.5, STEALTH_LIGHT_HOLD 5 s. States are written as text: "unaware", "suspicious", "alert".

/// Point-blank: seen plainly within 2 tiles in front is an alert on that look; 3-4 tiles fill fast; further is as before.
/datum/unit_test/voidcrew_stealth_point_blank

/datum/unit_test/voidcrew_stealth_point_blank/Run()
	var/datum/turf_reservation/block = stealth_block(12, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/person = stealth_person(block, 0, 0)
	// Lit, one and two tiles ahead (and two ahead, one aside): alert on the first scan, after them.
	for(var/list/offset as anything in list(list(1, 0), list(2, 0), list(2, 1)))
		person.forceMove(stealth_at(block, 2 + offset[1], 2 + offset[2]))
		var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
		var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
		stealth_scans(guard, 1)
		TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "Someone at offset ([offset[1]], [offset[2]]) in the light wasn't an alert on the first look")
		TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "A point-blank alert has no target")
		qdel(guard)
	// Three ahead: suspicious on the first look, alert on the second.
	person.forceMove(stealth_at(block, 5, 2))
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "Someone 3 tiles ahead in the light: [stealth_ai.stealth_state()] after one look")
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "Someone 3 tiles ahead in the light: [stealth_ai.stealth_state()] after two looks")
	qdel(guard)
	// Six ahead: unchanged (0.375 a look, so one look is not suspicious).
	person.forceMove(stealth_at(block, 8, 2))
	guard = stealth_guard(block, 2, 2)
	stealth_ai = stealth_ai(guard)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "Someone 6 tiles ahead was noticed in one look")
	qdel(guard)
	// Two ahead in the dark (not at its elbow): no instant alert.
	var/turf/dark = stealth_at(block, 4, 2)
	GLOB.stealth_test_dark_turfs[dark] = TRUE
	person.forceMove(dark)
	guard = stealth_guard(block, 2, 2)
	stealth_ai = stealth_ai(guard)
	stealth_scans(guard, 1)
	TEST_ASSERT(stealth_ai.stealth_state() != "alert", "Someone 2 tiles ahead in the dark was an alert on the first look")
	GLOB.stealth_test_dark_turfs[dark] = FALSE
	qdel(guard)
	// Between scans: someone who steps in front of it is an alert without waiting for the next scan.
	person.forceMove(stealth_at(block, 1, 2))
	guard = stealth_guard(block, 2, 2)
	stealth_ai = stealth_ai(guard)
	stealth_scans(guard, 1)
	TEST_ASSERT(stealth_ai.next_scan > world.time, "The scan didn't set its next time")
	TEST_ASSERT(!stealth_ai.stealth_quick_look(), "The quick look saw someone behind it")
	person.forceMove(stealth_at(block, 3, 2))
	TEST_ASSERT(stealth_ai.stealth_quick_look(), "The quick look missed someone a tile in front")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "The quick look didn't make it alert")
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "The quick look's alert has no target")
	qdel(guard)
	qdel(block)

/// Real lighting: standing still right behind a guard in the dark, its light on, is never seen; two ahead is.
/datum/unit_test/voidcrew_stealth_behind_dark

/datum/unit_test/voidcrew_stealth_behind_dark/Run()
	var/datum/turf_reservation/block = stealth_block(9, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	stealth_unlist(block, 9, 5)
	var/mob/living/carbon/human/person = stealth_person(block, 1, 2)
	var/turf/behind = get_turf(person)
	TEST_ASSERT(stealth_tile_is_dark(behind), "Reserved test space isn't dark, so the light can't be tested")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A guard in the dark didn't switch its light on")
	stealth_settle_light()
	// Its pool lands ahead of it (decision 39): the tile behind it stays dark.
	TEST_ASSERT(stealth_tile_is_dark(behind), "The guard's pool lights the tile behind it")
	stealth_scans(guard, 10)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard saw someone standing still right behind it in the dark")
	var/list/entry = stealth_ai.notice_map[REF(person)]
	TEST_ASSERT(isnull(entry) || entry[1] == 0, "A guard built notice on someone right behind it in the dark ([entry?[1]])")
	// Two tiles ahead, in its pool: an alert.
	person.forceMove(stealth_at(block, 4, 2))
	TEST_ASSERT(!stealth_tile_is_dark(get_turf(person)), "The guard's pool doesn't reach 2 tiles ahead")
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard didn't see someone 2 tiles ahead in its own light")
	qdel(guard)
	qdel(block)

/// Decision 39: someone walking about behind a guard in the dark, never touching it, gains no notice at all.
/datum/unit_test/voidcrew_stealth_behind_walking

/datum/unit_test/voidcrew_stealth_behind_walking/Run()
	var/datum/turf_reservation/block = stealth_block(9, 7)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	stealth_unlist(block, 9, 7)
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 5, 3)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 4, 3)
	TEST_ASSERT_EQUAL(person.move_intent, MOVE_INTENT_WALK, "Test fixture: the person isn't walking")
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A guard in the dark didn't switch its light on")
	stealth_settle_light()
	// A walk round its back: behind, behind-diagonal and the tiles two back, every step a new tile.
	var/list/path = list(list(4, 3), list(4, 4), list(3, 4), list(3, 3), list(3, 2), list(4, 2), list(4, 3), list(3, 3))
	for(var/list/step as anything in path)
		var/turf/tile = stealth_at(block, step[1], step[2])
		TEST_ASSERT(stealth_tile_is_dark(tile), "Behind the guard at ([step[1]], [step[2]]) isn't dark")
		person.forceMove(tile)
		stealth_scans(guard, 1)
		var/list/entry = stealth_ai.notice_map[REF(person)]
		TEST_ASSERT(isnull(entry) || entry[1] == 0, "Walking behind a guard in the dark at ([step[1]], [step[2]]) built notice ([entry?[1]])")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard noticed someone walking behind it in the dark")
	qdel(block)

/// A friend's passing light doesn't make a guard switch its own off: its spot is judged by the room's light. Where a
/// friend's pool really lands, it is real light.
/datum/unit_test/voidcrew_stealth_light_friends

/datum/unit_test/voidcrew_stealth_light_friends/Run()
	var/datum/turf_reservation/block = stealth_block(12, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	stealth_unlist(block, 12, 5)
	var/mob/living/carbon/human/npc/first = stealth_guard(block, 2, 2)
	var/mob/living/carbon/human/npc/second = stealth_guard(block, 5, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/first_ai = stealth_ai(first)
	var/datum/ai_controller/basic_controller/human_npc/stealth/second_ai = stealth_ai(second)
	first_ai.stealth_update_light()
	TEST_ASSERT(first_ai.stealth_light_shows(), "The first guard didn't switch its light on in the dark")
	stealth_settle_light()
	var/turf/spot = get_turf(second)
	TEST_ASSERT(!stealth_tile_is_dark(spot), "The first guard's pool doesn't reach the second, so this test proves nothing")
	TEST_ASSERT(stealth_tile_is_dark(spot, no_guard_lights = TRUE), "Without guard lights the second guard's spot isn't dark")
	second_ai.stealth_update_light()
	TEST_ASSERT(second_ai.stealth_light_shows(), "A guard in the dark left its light off because a friend's light was on it")
	stealth_settle_light()
	second_ai.light_hold_until = 0
	second_ai.stealth_update_light()
	TEST_ASSERT(second_ai.stealth_light_shows(), "A guard switched its light off because a friend's light was on it")
	first_ai.light_hold_until = 0
	first_ai.stealth_update_light()
	TEST_ASSERT(first_ai.stealth_light_shows(), "A guard switched its light off because a friend's light was on it")
	qdel(block)

/// A guard already found and called out as a body is not asked after as missing.
/datum/unit_test/voidcrew_stealth_live/hear/missing_reported

/datum/unit_test/voidcrew_stealth_live/hear/missing_reported/Run()
	TEST_ASSERT(hear_room(20, 3), "No room for the test")
	var/mob/living/carbon/human/npc/first = walker(5, 1)
	var/mob/living/carbon/human/npc/second = walker(7, 1)
	var/mob/living/carbon/human/npc/third = walker(9, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/first_ai = first.ai_controller
	var/datum/stealth_group/group = first_ai.group
	stealth_noise(at(4, 1), "knock")
	TEST_ASSERT_EQUAL(length(group.checks), 1, "No check was opened on the guard that went")
	first.death()
	group.reported_bodies += REF(first)
	group.rewind(31 SECONDS)
	group.check_overdue()
	TEST_ASSERT_EQUAL(length(group.checks), 0, "The check on a reported body wasn't closed")
	TEST_ASSERT_EQUAL(state_of(second), "unaware", "A guard went looking for a friend whose body was already reported")
	TEST_ASSERT_EQUAL(state_of(third), "unaware", "A guard went looking for a friend whose body was already reported")
	no_targets(list(second, third))

/**
 * A running guard never steps faster than a player running: the delay follows its move intent, its kit doesn't
 * make it quicker than a bare player, and a diagonal step costs what a player's does. Logs the measured times.
 */
/datum/unit_test/voidcrew_stealth_live/run_speed

/datum/unit_test/voidcrew_stealth_live/run_speed/Run()
	TEST_ASSERT(make_room(16, 16), "No room for the test")
	var/mob/living/carbon/human/person = person_at(15, 15, FALSE)
	if(person.move_intent != MOVE_INTENT_RUN)
		person.toggle_move_intent()
	var/player_run = person.cached_multiplicative_slowdown
	var/mob/living/carbon/human/npc/guard = guard_at(1, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
	stealth_ai.stealth_set_pace(FALSE)
	var/walk_delay = stealth_ai.movement_delay
	stealth_ai.stealth_set_pace(TRUE)
	TEST_ASSERT_EQUAL(guard.move_intent, MOVE_INTENT_RUN, "A running guard isn't on run")
	TEST_ASSERT_EQUAL(stealth_ai.movement_delay, guard.cached_multiplicative_slowdown, "The guard's AI step delay didn't follow its move intent")
	TEST_ASSERT(stealth_ai.movement_delay < walk_delay, "Running isn't faster than walking for a guard ([stealth_ai.movement_delay] vs [walk_delay])")
	TEST_ASSERT(stealth_ai.movement_delay >= player_run, "A running guard's step delay [stealth_ai.movement_delay] is under a running player's [player_run]")
	var/stock_diagonal = time_walk(guard, /datum/ai_movement/basic_avoidance, at(1, 1), at(13, 13))
	var/stealth_diagonal = time_walk(guard, /datum/ai_movement/basic_avoidance/stealth, at(1, 1), at(13, 13))
	var/stealth_straight = time_walk(guard, /datum/ai_movement/basic_avoidance/stealth, at(1, 1), at(13, 1))
	// The path movement (jps/stealth) shares stealth_step_cost(); it isn't timed here because tg's JPS loop stops at the
	// controller's minimum distance, which with no behaviour running is its whole target range.
	TEST_NOTICE(src, "Run speed: player run delay [player_run] ds, guard walk [walk_delay] ds, guard run [stealth_ai.movement_delay] ds. 12 tiles: stock tg diagonal [stock_diagonal] ds, guard diagonal [stealth_diagonal] ds, guard straight [stealth_straight] ds; a player takes [12 * player_run] ds straight, [round(12 * player_run * sqrt(2), 0.1)] ds diagonal.")
	TEST_ASSERT(stealth_diagonal >= 0, "The guard never finished the diagonal run")
	TEST_ASSERT(stealth_straight >= 0, "The guard never finished the straight run")
	// One tick of slack for the move loop's timing.
	var/slack = world.tick_lag
	TEST_ASSERT(stealth_straight >= 12 * player_run - slack, "12 straight tiles took a running guard [stealth_straight] ds, a player [12 * player_run] ds")
	TEST_ASSERT(stealth_diagonal >= 12 * player_run * sqrt(2) - slack, "12 diagonal tiles took a running guard [stealth_diagonal] ds, a player [12 * player_run * sqrt(2)] ds")

/// Moves `guard` from `start` to `goal` with `movement_type`'s own move loop and returns how long it took, or -1.
/datum/unit_test/voidcrew_stealth_live/proc/time_walk(mob/living/carbon/human/npc/guard, movement_type, turf/start, turf/goal)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
	guard.forceMove(start)
	stealth_ai.last_step_turf = start
	var/datum/ai_movement/mover = SSai_movement.movement_types[movement_type]
	var/began = world.time
	mover.start_moving_towards(stealth_ai, goal, 0)
	var/deadline = world.time + 15 SECONDS
	while(get_turf(guard) != goal && world.time < deadline)
		sleep(world.tick_lag)
	var/took = world.time - began
	mover.stop_moving_towards(stealth_ai)
	return get_turf(guard) == goal ? took : -1

/// Decision 39: a fresh guard walks its route from its first plan (tg starts every mob at a run), and a diagonal
/// step at a walk still costs what a player's does (decision 32).
/datum/unit_test/voidcrew_stealth_live/walk_pace

/datum/unit_test/voidcrew_stealth_live/walk_pace/Run()
	TEST_ASSERT(make_room(16, 16), "No room for the test")
	person_at(15, 15)
	var/mob/living/carbon/human/npc/guard = guard_at(1, 1)
	TEST_ASSERT_EQUAL(guard.move_intent, MOVE_INTENT_RUN, "Test fixture: tg no longer starts mobs at a run, so this test proves nothing")
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
	var/run_delay = stealth_ai.movement_delay
	stealth_ai.stealth_setup()
	TEST_ASSERT_EQUAL(guard.move_intent, MOVE_INTENT_WALK, "A fresh guard isn't walking once it has set up")
	var/walk_delay = stealth_ai.movement_delay
	TEST_ASSERT(walk_delay > run_delay, "A walking guard's step delay [walk_delay] isn't over its running one [run_delay]")
	var/diagonal = time_walk(guard, /datum/ai_movement/basic_avoidance/stealth, at(1, 1), at(13, 13))
	TEST_NOTICE(src, "Walk pace: guard walk delay [walk_delay] ds, run [run_delay] ds; 12 diagonal tiles at a walk took [diagonal] ds.")
	TEST_ASSERT(diagonal >= 0, "The guard never finished the diagonal walk")
	TEST_ASSERT(diagonal >= 12 * walk_delay * sqrt(2) - world.tick_lag, "12 diagonal tiles took a walking guard [diagonal] ds, a walking player [12 * walk_delay * sqrt(2)] ds")
