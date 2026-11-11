// Stealth guards, owner decision 33 (voidcrew/modules/stealth/stealth_closet.dm): a guard that saw its target get into
// a locker opens it; one that didn't leaves it shut. Values from voidcrew/_DEFINES are written out:
// STEALTH_LOSE_TARGET_TIME 4 s, STEALTH_CLOSET_SEEN_WINDOW 1.5 s. States are written as text.

/// Claims, with the AI off: the locker it sees someone in when it goes alert; dropped when they get out, when it is
/// deleted, and when the guard stops being alert.
/datum/unit_test/voidcrew_stealth_closet_claim

/datum/unit_test/voidcrew_stealth_closet_claim/Run()
	var/datum/turf_reservation/block = stealth_block(8, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 1, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 5, 1)
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, stealth_at(block, 4, 1))
	person.forceMove(locker)
	stealth_ai.stealth_go_alert(person)
	TEST_ASSERT_EQUAL(stealth_ai.shut_in, locker, "A guard alerted on someone in a locker in plain view didn't claim it")
	// Out of it: the claim goes.
	person.forceMove(stealth_at(block, 5, 1))
	TEST_ASSERT_NULL(stealth_ai.stealth_closet_check(person), "A claim held after its target got out")
	TEST_ASSERT_NULL(stealth_ai.shut_in, "A guard kept a locker its target had left")
	// Back in, then the locker is destroyed.
	person.forceMove(locker)
	stealth_ai.stealth_go_alert(person)
	TEST_ASSERT_EQUAL(stealth_ai.shut_in, locker, "A guard didn't claim the locker the second time")
	qdel(locker)
	TEST_ASSERT_NULL(stealth_ai.shut_in, "A guard kept a deleted locker")
	// A new one, and the guard calms down.
	var/obj/structure/closet/second = allocate(/obj/structure/closet, stealth_at(block, 4, 1))
	person.forceMove(second)
	stealth_ai.stealth_go_alert(person)
	TEST_ASSERT_EQUAL(stealth_ai.shut_in, second, "A guard didn't claim the second locker (state [stealth_ai.stealth_state()], target [stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET] || "none"], person in [person.loc || "nullspace"], person deleted [QDELETED(person)])")
	stealth_ai.stealth_go_searching(stealth_at(block, 4, 1))
	TEST_ASSERT_NULL(stealth_ai.shut_in, "A guard that stopped being alert kept its locker")

/// Real AI: alert on someone who walks into an open locker and pulls the door shut in front of it, it opens the locker.
/datum/unit_test/voidcrew_stealth_live/closet_seen

/datum/unit_test/voidcrew_stealth_live/closet_seen/Run()
	TEST_ASSERT(make_room(12, 5), "No room for the test")
	var/mob/living/carbon/human/npc/guard = guard_at(2, 2, EAST)
	var/mob/living/carbon/human/person = person_at(6, 2)
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, at(7, 2))
	locker.open()
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = wake(guard)
	stealth_ai.stealth_go_alert(person)
	step(person, EAST)
	TEST_ASSERT_EQUAL(get_turf(person), at(7, 2), "The person couldn't step into the open locker")
	TEST_ASSERT(locker.close(person), "The person couldn't shut the locker on themselves")
	TEST_ASSERT_EQUAL(person.loc, locker, "The person isn't in the locker")
	var/start_integrity = locker.get_integrity()
	var/deadline = world.time + 30 SECONDS
	while(!locker.opened && world.time < deadline)
		sleep(2)
	TEST_ASSERT(locker.opened, "A guard that saw someone shut themselves in a locker never opened it (claim: [stealth_ai.shut_in ? "yes" : "no"], state [stealth_ai.stealth_state()])")
	TEST_ASSERT(get_dist(guard, locker) <= 1, "The locker opened with the guard [get_dist(guard, locker)] tiles away")
	TEST_ASSERT_EQUAL(locker.get_integrity(), start_integrity, "A guard hit a locker it could just open")
	TEST_ASSERT(isturf(person.loc), "The person is still shut in after the locker opened")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "The guard isn't alert on whoever was in the locker")
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "The guard isn't after whoever was in the locker")

/// Real AI: alert on someone who got into a locker behind a wall, it can see the locker once the wall is gone, but
/// leaves it shut: it loses them, searches, and never hits or opens it.
/datum/unit_test/voidcrew_stealth_live/closet_unseen

/datum/unit_test/voidcrew_stealth_live/closet_unseen/Run()
	TEST_ASSERT(make_room(12, 5), "No room for the test")
	for(var/dy in 0 to 4)
		var/turf/wall_spot = at(6, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	var/mob/living/carbon/human/npc/guard = guard_at(2, 2, EAST)
	var/mob/living/carbon/human/person = person_at(9, 2)
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, at(9, 2))
	person.forceMove(locker)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = wake(guard)
	stealth_ai.stealth_go_alert(person)
	TEST_ASSERT_NULL(stealth_ai.shut_in, "A guard claimed a locker behind a wall")
	for(var/dy in 0 to 4)
		var/turf/gap = at(6, dy)
		gap.ChangeTurf(/turf/open/floor/iron)
		GLOB.stealth_test_dark_turfs[gap] = FALSE
	var/start_integrity = locker.get_integrity()
	var/deadline = world.time + 15 SECONDS
	while(stealth_ai.stealth_state() == "alert" && world.time < deadline)
		sleep(2)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "searching", "A guard whose target hid unseen didn't lose them")
	sleep(6 SECONDS)
	TEST_ASSERT(!locker.opened, "A guard opened a locker it never saw anyone get into")
	TEST_ASSERT_EQUAL(person.loc, locker, "The person was taken out of the locker")
	TEST_ASSERT_EQUAL(locker.get_integrity(), start_integrity, "A guard hit a locker it never saw anyone get into")
	TEST_ASSERT_NULL(stealth_ai.shut_in, "A searching guard claimed a locker")

/// Real AI: a gunner that saw someone shut in a locker that is then locked shoots it open from beside it, not from range.
/datum/unit_test/voidcrew_stealth_live/closet_locked

/datum/unit_test/voidcrew_stealth_live/closet_locked/Run()
	TEST_ASSERT(make_room(12, 5), "No room for the test")
	var/mob/living/carbon/human/npc/guard = allocate(/mob/living/carbon/human/npc/ruin/trooper/scav/gunner, at(2, 2))
	guard.setDir(EAST)
	guard.AddElement(/datum/element/forced_gravity, 1)
	var/mob/living/carbon/human/person = person_at(6, 2)
	var/obj/structure/closet/secure_closet/locker = allocate(/obj/structure/closet/secure_closet, at(7, 2))
	locker.locked = FALSE
	locker.open()
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = wake(guard)
	stealth_ai.stealth_go_alert(person)
	step(person, EAST)
	TEST_ASSERT(locker.close(person), "The person couldn't shut the locker on themselves")
	locker.locked = TRUE
	locker.update_appearance()
	// Near breaking, so the test takes a couple of shots, not a magazine.
	locker.update_integrity(locker.max_integrity * locker.integrity_failure + 25)
	var/start_integrity = locker.get_integrity()
	var/first_hit_dist
	var/deadline = world.time + 40 SECONDS
	while(!locker.opened && world.time < deadline)
		if(isnull(first_hit_dist) && locker.get_integrity() < start_integrity)
			first_hit_dist = get_dist(guard, locker)
		sleep(1)
	TEST_ASSERT(locker.opened, "A gunner never broke open a locked locker it saw someone get into (claim: [stealth_ai.shut_in ? "yes" : "no"], integrity [locker.get_integrity()]/[start_integrity])")
	TEST_ASSERT_NOTNULL(first_hit_dist, "The locked locker opened without being hit")
	TEST_ASSERT(first_hit_dist <= 1, "A gunner shot a locker from [first_hit_dist] tiles away")
	TEST_ASSERT(isturf(person.loc), "The person is still shut in after the locker broke")
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "The gunner isn't after whoever was in the locker")

/// Real AI: two guards saw it; only one opens the locker, the other covers it.
/datum/unit_test/voidcrew_stealth_live/closet_two_guards

/datum/unit_test/voidcrew_stealth_live/closet_two_guards/Run()
	TEST_ASSERT(make_room(12, 5), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 4))
	var/mob/living/carbon/human/npc/first = guard_at(2, 1, EAST)
	var/mob/living/carbon/human/npc/second = guard_at(2, 3, EAST)
	var/mob/living/carbon/human/person = person_at(6, 2)
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, at(7, 2))
	locker.open()
	var/datum/ai_controller/basic_controller/human_npc/stealth/first_ai = wake(first)
	var/datum/ai_controller/basic_controller/human_npc/stealth/second_ai = wake(second)
	first_ai.stealth_setup()
	second_ai.stealth_setup()
	TEST_ASSERT_NOTNULL(first_ai.group, "The guards have no group")
	TEST_ASSERT_EQUAL(first_ai.group, second_ai.group, "The guards aren't in one group")
	first_ai.stealth_go_alert(person)
	second_ai.stealth_go_alert(person)
	step(person, EAST)
	TEST_ASSERT(locker.close(person), "The person couldn't shut the locker on themselves")
	var/datum/ai_behavior/opening = GET_AI_BEHAVIOR(/datum/ai_behavior/stealth_open_closet)
	var/list/openers = list()
	var/both_claimed = FALSE
	var/deadline = world.time + 30 SECONDS
	while(!locker.opened && world.time < deadline)
		if(first_ai.shut_in == locker && second_ai.shut_in == locker)
			both_claimed = TRUE
		for(var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai as anything in list(first_ai, second_ai))
			if(opening in guard_ai.current_behaviors)
				openers |= guard_ai
		sleep(1)
	TEST_ASSERT(locker.opened, "Two guards that saw someone shut in a locker never opened it")
	TEST_ASSERT(both_claimed, "The two guards never both went after the locker (the test can't tell one opener from one watcher)")
	TEST_ASSERT_EQUAL(length(openers), 1, "[length(openers)] guards tried to open one locker")
