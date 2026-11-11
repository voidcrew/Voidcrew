// Stealth guards: flashlights, elbow-to-elbow sight, volleys and sentry facing (owner decision 31,
// voidcrew/modules/stealth/stealth_light.dm). Values from voidcrew/_DEFINES are written out: STEALTH_LIGHT_HOLD
// 5 s, STEALTH_NOISE_COALESCE 3 s, STEALTH_SENTRY_TURN_INTERVAL 8 s, STEALTH_SENTRY_GLANCE_TIME 2 s.

/// The guard switches its seclite on in the dark and while on edge, off in the light, and can't while it is cut out.
/datum/unit_test/voidcrew_stealth_light_switch

/datum/unit_test/voidcrew_stealth_light_switch/Run()
	var/datum/turf_reservation/block = stealth_block(9, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/obj/item/flashlight/light = stealth_ai.stealth_light()
	TEST_ASSERT_NOTNULL(light, "A scav guard has no flashlight on its body")
	TEST_ASSERT(!light.light_on, "A guard's light starts on")
	var/turf/here = get_turf(guard)
	stealth_ai.stealth_update_light()
	TEST_ASSERT(!light.light_on, "An unaware guard in the light switched its light on")
	GLOB.stealth_test_dark_turfs[here] = TRUE
	stealth_ai.stealth_update_light()
	TEST_ASSERT(light.light_on, "A guard standing in the dark didn't switch its light on")
	// Back in the light it keeps it on a moment, then switches it off.
	GLOB.stealth_test_dark_turfs[here] = FALSE
	stealth_ai.stealth_update_light()
	TEST_ASSERT(light.light_on, "A guard switched its light off the moment it stepped into the light")
	stealth_ai.light_hold_until = 0
	stealth_ai.stealth_update_light()
	TEST_ASSERT(!light.light_on, "An unaware guard in the light kept its light on")
	// On edge, it is on even in the light.
	stealth_ai.stealth_go_suspicious(stealth_at(block, 6, 2))
	TEST_ASSERT(light.light_on, "A suspicious guard's light isn't on")
	stealth_ai.stealth_go_searching(stealth_at(block, 6, 2))
	TEST_ASSERT(light.light_on, "A searching guard's light isn't on")
	stealth_ai.stealth_go_unaware()
	stealth_ai.light_hold_until = 0
	stealth_ai.stealth_update_light()
	TEST_ASSERT(!light.light_on, "A calm guard in the light kept its light on")
	// An EMP cuts it out, and the guard can't switch it back on until it recovers.
	GLOB.stealth_test_dark_turfs[here] = TRUE
	stealth_ai.stealth_update_light()
	TEST_ASSERT(light.light_on, "The light didn't come on in the dark")
	guard.emp_act(EMP_LIGHT)
	TEST_ASSERT(!light.light_on, "An EMP didn't cut the guard's light out")
	stealth_ai.stealth_update_light()
	TEST_ASSERT(!light.light_on, "A guard switched an EMP'd light straight back on")
	light.disabled_time = 0
	stealth_ai.stealth_update_light()
	TEST_ASSERT(light.light_on, "The light didn't come back on once the EMP wore off")
	// Gone from its body, it goes without.
	light.forceMove(stealth_at(block, 4, 4))
	TEST_ASSERT_NULL(stealth_ai.stealth_light(), "A guard still counts a light that left its body")
	GLOB.stealth_test_dark_turfs[here] = FALSE
	qdel(block)

/// Real lighting: in a dark room the guard sees someone 5 tiles ahead only by its own light.
/datum/unit_test/voidcrew_stealth_light_sight

/datum/unit_test/voidcrew_stealth_light_sight/Run()
	var/datum/turf_reservation/block = stealth_block(12, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	stealth_unlist(block, 12, 5)
	var/mob/living/carbon/human/person = stealth_person(block, 6, 2)
	var/turf/spot = get_turf(person)
	TEST_ASSERT(stealth_tile_is_dark(spot), "Reserved test space isn't dark, so the light can't be tested")
	// Without a light: 5 tiles off in the dark is past sight.
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 1, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	qdel(stealth_ai.stealth_light())
	stealth_scans(guard, 5)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard with no light saw someone 5 tiles off in the dark")
	qdel(guard)
	// With one: it switches it on, the light reaches them, and it notices them.
	guard = stealth_guard(block, 1, 2)
	stealth_ai = stealth_ai(guard)
	var/obj/item/flashlight/light = stealth_ai.stealth_light()
	stealth_ai.stealth_update_light()
	TEST_ASSERT(light.light_on, "A guard standing in the dark didn't switch its light on")
	TEST_ASSERT(!stealth_tile_is_dark(spot), "The guard's light doesn't reach 5 tiles ahead")
	TEST_ASSERT(stealth_tile_is_dark(get_turf(guard), light), "A guard counts its own light as the room's")
	stealth_scans(guard, 5)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "A guard didn't notice someone its light was on")
	qdel(guard)
	qdel(block)

/// Real lighting: a searching guard finds a body in the dark by its light.
/datum/unit_test/voidcrew_stealth_light_body

/datum/unit_test/voidcrew_stealth_light_body/Run()
	var/datum/turf_reservation/block = stealth_block(12, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	stealth_unlist(block, 12, 5)
	allocate(/obj/effect/landmark/stealth_group, stealth_at(block, 7, 4))
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 1, 2)
	var/mob/living/carbon/human/npc/friend = stealth_guard(block, 6, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/datum/ai_controller/basic_controller/human_npc/stealth/friend_ai = stealth_ai(friend)
	stealth_ai.stealth_setup()
	friend_ai.stealth_setup()
	qdel(friend_ai.stealth_light())
	friend.death()
	TEST_ASSERT(stealth_tile_is_dark(get_turf(friend)), "Reserved test space isn't dark, so the light can't be tested")
	// Its light cut out, it searches past the body 5 tiles off in the dark.
	var/obj/item/flashlight/light = stealth_ai.stealth_light()
	light.on_saboteur(null, 1 MINUTES)
	stealth_ai.stealth_go_searching(get_turf(guard))
	stealth_ai.stealth_check_bodies()
	TEST_ASSERT(!(REF(friend) in stealth_ai.blackboard["stealth_bodies_seen"]), "A guard saw a body 5 tiles off in the dark without a light")
	// With it on, it finds it.
	light.disabled_time = 0
	stealth_ai.stealth_update_light()
	TEST_ASSERT(light.light_on, "A searching guard's light didn't come on")
	stealth_ai.next_body_scan = 0
	stealth_ai.stealth_check_bodies()
	TEST_ASSERT(REF(friend) in stealth_ai.blackboard["stealth_bodies_seen"], "A searching guard with its light on didn't find the body")
	TEST_ASSERT(get_dist(stealth_ai.search_center, friend) <= 1, "The search didn't move to the body")
	TEST_ASSERT(stealth_ai.search_for_body, "The search isn't marked as over a body")
	qdel(block)

/// Elbow to elbow: someone on the next tile in front is seen in the dark (an alert, decision 32); behind or side-on
/// is not; two ahead in the dark fills (3x near, decision 32) to suspicious.
/datum/unit_test/voidcrew_stealth_adjacent

/datum/unit_test/voidcrew_stealth_adjacent/Run()
	var/datum/turf_reservation/block = stealth_block(7, 7)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	for(var/dx in 0 to 6)
		for(var/dy in 0 to 6)
			GLOB.stealth_test_dark_turfs[stealth_at(block, dx, dy)] = TRUE
	var/mob/living/carbon/human/person = stealth_person(block, 4, 3)
	// offset from the guard => its state after two scans
	var/list/cases = list(
		list(1, 0, "alert"),
		list(-1, 0, "unaware"),
		list(0, 1, "unaware"),
		list(2, 0, "suspicious"),
	)
	for(var/list/test_case as anything in cases)
		person.forceMove(stealth_at(block, 3 + test_case[1], 3 + test_case[2]))
		var/mob/living/carbon/human/npc/guard = stealth_guard(block, 3, 3)
		var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
		stealth_scans(guard, 2)
		TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), test_case[3], "Offset ([test_case[1]], [test_case[2]]) in the dark: state [stealth_ai.stealth_state()]")
		qdel(guard)
	for(var/dx in 0 to 6)
		for(var/dy in 0 to 6)
			GLOB.stealth_test_dark_turfs[stealth_at(block, dx, dy)] = FALSE
	qdel(block)

/// Takes a test block's turfs off the test light list, so they read the real light.
/datum/unit_test/proc/stealth_unlist(datum/turf_reservation/block, width, height)
	for(var/dx in 0 to width - 1)
		for(var/dy in 0 to height - 1)
			GLOB.stealth_test_dark_turfs -= stealth_at(block, dx, dy)

/// A quick volley from one spot is one noise; the same gun 3 s later is a new one; a loud gun still alarms.
/datum/unit_test/voidcrew_stealth_live/hear/volley

/datum/unit_test/voidcrew_stealth_live/hear/volley/Run()
	TEST_ASSERT(hear_room(20, 3), "No room for the test")
	var/mob/living/carbon/human/npc/first = walker(5, 1)
	var/mob/living/carbon/human/npc/second = walker(7, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/first_ai = first.ai_controller
	var/datum/stealth_group/group = first_ai.group
	var/turf/spot = at(4, 1)
	TEST_ASSERT(stealth_noise(spot, "gun_quiet") > 0, "A suppressed shot a tile off wasn't heard")
	for(var/i in 1 to 2)
		group.rewind(0.5 SECONDS)
		TEST_ASSERT_EQUAL(stealth_noise(spot, "gun_quiet"), 0, "Shot [i + 1] of a volley counted as a new noise")
	TEST_ASSERT_EQUAL(group.lure_count(spot), 1, "A volley counted as more than one lure")
	TEST_ASSERT_EQUAL(state_of(second), "unaware", "A volley sent a second guard")
	// A loud gun from the same spot is still an alarm.
	TEST_ASSERT(stealth_noise(spot, "gun_long") > 0, "A rifle after the volley wasn't heard")
	TEST_ASSERT_EQUAL(state_of(second), "searching", "A rifle shot after a quiet volley didn't send the guards running")
	// The same quiet gun later is a new noise.
	settle(first)
	settle(second)
	group.rewind(3.5 SECONDS)
	TEST_ASSERT(stealth_noise(spot, "gun_quiet") > 0, "A shot 3.5 s after the volley was merged into it")
	no_targets(list(first, second))

/// A sentry faces the way it was placed, glancing aside only now and then.
/datum/unit_test/voidcrew_stealth_live/sentry_facing

/datum/unit_test/voidcrew_stealth_live/sentry_facing/Run()
	TEST_ASSERT(make_room(14, 5), "No room for the test")
	person_at(13, 4)
	var/mob/living/carbon/human/npc/guard = guard_at(1, 2, SOUTH)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = wake(guard)
	var/deadline = world.time + 10 SECONDS
	while(!stealth_ai.stealth_ready && world.time < deadline)
		sleep(1)
	TEST_ASSERT(stealth_ai.stealth_ready, "The sentry never planned")
	sleep(1 SECONDS)
	TEST_ASSERT_NULL(stealth_ai.route_id, "A guard with no stop near it claimed a route")
	TEST_ASSERT_EQUAL(stealth_ai.sentry_dir, SOUTH, "A sentry placed facing south took [dir2text(stealth_ai.sentry_dir)] as its post")
	TEST_ASSERT_EQUAL(guard.dir, SOUTH, "A sentry placed facing south faces [dir2text(guard.dir)] a second later")
	var/total = 0
	var/count = 0
	for(var/i in 1 to 24)
		sleep(0.5 SECONDS)
		total++
		if(guard.dir == SOUTH)
			count++
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "The sentry was disturbed during the test")
	TEST_ASSERT(count >= total * 0.7, "A sentry faced its post only [count] of [total] looks over 12 s")
