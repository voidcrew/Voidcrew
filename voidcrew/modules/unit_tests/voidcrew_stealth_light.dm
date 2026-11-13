// Stealth guards: flashlights, elbow-to-elbow sight, volleys and sentry facing (owner decisions 31 and 39,
// voidcrew/modules/stealth/stealth_light.dm). Values from voidcrew/_DEFINES are written out: STEALTH_LIGHT_HOLD
// 5 s, STEALTH_TORCH_REACH 3, STEALTH_TORCH_REACH_DIAGONAL 2, STEALTH_NOISE_COALESCE 3 s,
// STEALTH_SENTRY_TURN_INTERVAL 8 s, STEALTH_SENTRY_GLANCE_TIME 2 s.

/// Waits for tg's static lighting to apply what was just switched or moved (it updates on its own subsystem).
/datum/unit_test/proc/stealth_settle_light()
	sleep(1)
	for(var/i in 1 to 50)
		if(!length(SSlighting.sources_queue) && !length(SSlighting.current_sources))
			return
		sleep(1)

/// The guard switches its light on in the dark and while on edge, off in the light, and can't while it is cut out.
/datum/unit_test/voidcrew_stealth_light_switch

/datum/unit_test/voidcrew_stealth_light_switch/Run()
	var/datum/turf_reservation/block = stealth_block(9, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/obj/item/flashlight/light = stealth_ai.stealth_light()
	TEST_ASSERT_NOTNULL(light, "A scav guard has no flashlight on its body")
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "A guard's light starts on")
	var/turf/here = get_turf(guard)
	stealth_ai.stealth_update_light()
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "An unaware guard in the light switched its light on")
	GLOB.stealth_test_dark_turfs[here] = TRUE
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A guard standing in the dark didn't switch its light on")
	TEST_ASSERT(!light.light_on, "The seclite item lit its own beam as well as the pool")
	// Back in the light it keeps it on a moment, then switches it off.
	GLOB.stealth_test_dark_turfs[here] = FALSE
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A guard switched its light off the moment it stepped into the light")
	stealth_ai.light_hold_until = 0
	stealth_ai.stealth_update_light()
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "An unaware guard in the light kept its light on")
	// On edge, it is on even in the light.
	stealth_ai.stealth_go_suspicious(stealth_at(block, 6, 2))
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A suspicious guard's light isn't on")
	stealth_ai.stealth_go_searching(stealth_at(block, 6, 2))
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A searching guard's light isn't on")
	stealth_ai.stealth_go_unaware()
	stealth_ai.light_hold_until = 0
	stealth_ai.stealth_update_light()
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "A calm guard in the light kept its light on")
	// An EMP cuts it out at once, and the guard can't switch it back on until it recovers.
	GLOB.stealth_test_dark_turfs[here] = TRUE
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "The light didn't come on in the dark")
	guard.emp_act(EMP_LIGHT)
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "An EMP didn't cut the guard's light out")
	stealth_ai.stealth_update_light()
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "A guard switched an EMP'd light straight back on")
	light.disabled_time = 0
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "The light didn't come back on once the EMP wore off")
	// Stunned, it has no light.
	guard.Paralyze(5 SECONDS)
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "A stunned guard kept its light on")
	guard.SetParalyzed(0)
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "The light didn't come back once the guard was up")
	// Gone from its body, it goes out at once.
	light.forceMove(stealth_at(block, 4, 4))
	TEST_ASSERT_NULL(stealth_ai.stealth_light(), "A guard still counts a light that left its body")
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "A guard's pool stayed on after its seclite was taken")
	GLOB.stealth_test_dark_turfs[here] = FALSE
	qdel(block)

/// Decision 39: the pool lands 3 tiles ahead (2 on a diagonal), stops short of a wall or a closed door, goes through
/// glass, and follows the guard's turns and steps.
/datum/unit_test/voidcrew_stealth_light_pool

/datum/unit_test/voidcrew_stealth_light_pool/Run()
	var/datum/turf_reservation/block = stealth_block(10, 7)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/turf/from = stealth_at(block, 2, 3)
	TEST_ASSERT_EQUAL(stealth_torch_spot(from, EAST), stealth_at(block, 5, 3), "An open floor's pool isn't 3 tiles ahead")
	TEST_ASSERT_EQUAL(stealth_torch_spot(from, NORTHEAST), stealth_at(block, 4, 5), "A diagonal pool isn't 2 tiles out")
	// A wall 3 ahead: the pool is on the last open tile before it.
	var/turf/wall = stealth_at(block, 5, 3)
	wall.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT_EQUAL(stealth_torch_spot(from, EAST), stealth_at(block, 4, 3), "The pool went into or past a wall")
	// Right at its nose: no pool.
	var/turf/near_wall = stealth_at(block, 3, 3)
	near_wall.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT_NULL(stealth_torch_spot(from, EAST), "A guard facing a wall at its nose has a pool")
	// A closed glass airlock stops it; glass does not.
	var/obj/machinery/door/airlock/glass/door = allocate(/obj/machinery/door/airlock/glass, stealth_at(block, 2, 5))
	TEST_ASSERT(door.density, "Test fixture: the airlock isn't closed")
	TEST_ASSERT_EQUAL(stealth_torch_spot(from, NORTH), stealth_at(block, 2, 4), "The pool went through a closed glass door")
	allocate(/obj/structure/window/fulltile, stealth_at(block, 2, 1))
	TEST_ASSERT_EQUAL(stealth_torch_spot(from, SOUTH), stealth_at(block, 2, 0), "The pool stopped at a window")
	// A guard's pool follows it.
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 3, SOUTH)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	GLOB.stealth_test_dark_turfs[get_turf(guard)] = TRUE
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A guard in the dark has no pool")
	TEST_ASSERT_EQUAL(get_turf(stealth_ai.torch), stealth_at(block, 6, 0), "The pool isn't 3 ahead of a guard facing south")
	guard.setDir(EAST)
	TEST_ASSERT_EQUAL(get_turf(stealth_ai.torch), stealth_at(block, 9, 3), "The pool didn't follow the guard's turn")
	// A wall goes up where the pool was; after its next step the pool sits short of it, and smaller.
	var/turf/far_wall = stealth_at(block, 9, 3)
	far_wall.ChangeTurf(/turf/closed/wall)
	guard.forceMove(stealth_at(block, 7, 3))
	TEST_ASSERT_EQUAL(get_turf(stealth_ai.torch), stealth_at(block, 8, 3), "The pool didn't stop short of a wall after a step")
	TEST_ASSERT(stealth_ai.torch.light_range < 2.5, "A pool a tile off is as wide as one 3 off")
	var/obj/effect/abstract/stealth_torch/old_torch = stealth_ai.torch
	GLOB.stealth_test_dark_turfs[stealth_at(block, 6, 3)] = FALSE
	qdel(guard)
	TEST_ASSERT(QDELETED(old_torch), "A deleted guard left its pool behind")
	qdel(block)

/// Real lighting: in a dark room the guard's pool lights what it lands on and nothing behind it.
/datum/unit_test/voidcrew_stealth_light_sight

/datum/unit_test/voidcrew_stealth_light_sight/Run()
	var/datum/turf_reservation/block = stealth_block(12, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	stealth_unlist(block, 12, 5)
	var/mob/living/carbon/human/person = stealth_person(block, 5, 2)
	var/turf/spot = get_turf(person)
	TEST_ASSERT(stealth_tile_is_dark(spot), "Reserved test space isn't dark, so the light can't be tested")
	// Without a light: 3 tiles off in the dark fills slowly (no near fill in the dark, decision 39).
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	qdel(stealth_ai.stealth_light())
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard with no light noticed someone 3 tiles off in the dark in one look")
	qdel(guard)
	// With one: it switches it on, the pool lands on them, and it notices them.
	guard = stealth_guard(block, 2, 2)
	stealth_ai = stealth_ai(guard)
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A guard standing in the dark didn't switch its light on")
	stealth_settle_light()
	TEST_ASSERT(!stealth_tile_is_dark(spot), "The guard's pool doesn't light the tile it lands on")
	TEST_ASSERT(!stealth_tile_is_dark(stealth_at(block, 6, 2)), "The guard's pool doesn't light the tile past it")
	TEST_ASSERT(stealth_tile_is_dark(get_turf(guard)), "The guard's pool lights its own tile")
	TEST_ASSERT(stealth_tile_is_dark(stealth_at(block, 1, 2)), "The guard's pool lights the tile behind it")
	TEST_ASSERT(stealth_tile_is_dark(stealth_at(block, 8, 2)), "The guard's pool lights 6 tiles ahead")
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "A guard didn't notice someone its pool was on")
	qdel(guard)
	stealth_settle_light()
	TEST_ASSERT(stealth_tile_is_dark(spot), "The pool stayed lit after its guard was gone")
	qdel(block)

/// Real lighting: a searching guard sees as far as in daylight onto the tiles its pool lights.
/datum/unit_test/voidcrew_stealth_light_body

/datum/unit_test/voidcrew_stealth_light_body/Run()
	var/datum/turf_reservation/block = stealth_block(12, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	stealth_unlist(block, 12, 5)
	allocate(/obj/effect/landmark/stealth_group, stealth_at(block, 7, 4))
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 1, 2)
	var/mob/living/carbon/human/npc/friend = stealth_guard(block, 4, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/datum/ai_controller/basic_controller/human_npc/stealth/friend_ai = stealth_ai(friend)
	stealth_ai.stealth_setup()
	friend_ai.stealth_setup()
	qdel(friend_ai.stealth_light())
	friend.death()
	var/turf/body_turf = get_turf(friend)
	TEST_ASSERT(stealth_tile_is_dark(body_turf), "Reserved test space isn't dark, so the light can't be tested")
	var/datum/stealth_skill/profile = stealth_ai.stealth_skill()
	// Its light cut out, the body's tile is dark to it.
	var/obj/item/flashlight/light = stealth_ai.stealth_light()
	light.on_saboteur(null, 1 MINUTES)
	stealth_ai.stealth_go_searching(get_turf(guard))
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "A guard's cut-out light shows a pool")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_range_onto(body_turf), profile.dark_sight_range, "A guard sees into the dark as if it were lit")
	// With it on, it is lit, and it finds the body.
	light.disabled_time = 0
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A searching guard's light didn't come on")
	stealth_settle_light()
	TEST_ASSERT_EQUAL(stealth_ai.stealth_range_onto(body_turf), profile.sight_range, "A guard's pool doesn't light the body it lands on")
	stealth_ai.next_body_scan = 0
	stealth_ai.stealth_check_bodies()
	TEST_ASSERT(REF(friend) in stealth_ai.blackboard["stealth_bodies_seen"], "A searching guard with its light on didn't find the body")
	TEST_ASSERT(get_dist(stealth_ai.search_center, friend) <= 1, "The search didn't move to the body")
	TEST_ASSERT(stealth_ai.search_for_body, "The search isn't marked as over a body")
	qdel(block)

/// Elbow to elbow: someone on the next tile in front is seen in the dark (an alert, decision 32); behind or side-on
/// is not; two ahead in the dark fills slowly (no near fill in the dark, decision 39).
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
		list(2, 0, "unaware"),
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
