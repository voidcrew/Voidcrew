// Stealth fix 3: a run step while stopped only blows the disguise when it takes them farther off
// (voidcrew/modules/stealth/stealth_disguise.dm), and only real guns take hostages or keep hands up
// (stealth_threat_gun(), voidcrew/modules/stealth/stealth_hostage.dm). Values are written out as in
// voidcrew_stealth_disguise.dm: states as text.

/// Stopped without a pass, a run step away from the guard blows it; toward it, to the side or being dragged doesn't.
/datum/unit_test/voidcrew_stealth_fix3_run_step

/datum/unit_test/voidcrew_stealth_fix3_run_step/Run()
	var/datum/turf_reservation/block = stealth_block(20, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	// how => where they end up (dx, dy), and whether it blows the disguise. The guard is at (6, 2), they start at (8, 2).
	var/list/cases = list(
		"away" = list(9, 2, TRUE),
		"toward" = list(7, 2, FALSE),
		"sideways" = list(8, 3, FALSE),
		"dragged away" = list(9, 2, FALSE),
	)
	for(var/how in cases)
		var/list/spec = cases[how]
		var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2)
		var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
		var/mob/living/carbon/human/person = stealth_person(block, 8, 2)
		stealth_dress(person, TRUE, TRUE, FALSE)
		stealth_scans(guard, 2)
		TEST_ASSERT_EQUAL(stealth_ai.challenge?.resolve(), person, "[how]: a guard didn't stop someone in clothing and mask 2 tiles in front of it")
		person.toggle_move_intent()
		TEST_ASSERT_EQUAL(person.move_intent, MOVE_INTENT_RUN, "Test fixture: [how]: not on run")
		var/mob/living/carbon/human/puller
		if(how == "dragged away")
			// A friend in the whole set steps off east and drags them along, through tg's own pull.
			for(var/dx in 8 to 10)
				stealth_ground(stealth_at(block, dx, 2))
			puller = stealth_person(block, 9, 2)
			stealth_dress(puller)
			puller.start_pulling(person, supress_message = TRUE)
			TEST_ASSERT_EQUAL(person.pulledby, puller, "Test fixture: not being pulled")
			puller.Move(stealth_at(block, 10, 2), EAST)
			TEST_ASSERT_EQUAL(person.pulledby, puller, "Test fixture: the pull broke on the drag")
			TEST_ASSERT_EQUAL(get_turf(person), stealth_at(block, spec[1], spec[2]), "Test fixture: the drag didn't move them")
		else
			person.forceMove(stealth_at(block, spec[1], spec[2]))
		stealth_scans(guard, 1)
		if(spec[3])
			TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "[how]: a run step away from the guard didn't blow it")
			TEST_ASSERT(!stealth_ai.stealth_fooled(person), "[how]: the disguise still holds after running off")
		else
			TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "[how]: a run step left the guard [stealth_ai.stealth_state()]")
			TEST_ASSERT_EQUAL(stealth_ai.challenge?.resolve(), person, "[how]: the guard let go of the one it stopped")
		if(puller)
			puller.stop_pulling()
			qdel(puller)
		qdel(guard)
		qdel(person)
	qdel(block)

/// Only a real gun takes a hostage, picks the pose's gun hand and keeps a guard's hands up: not a foam toy or a medbeam.
/datum/unit_test/voidcrew_stealth_fix3_real_guns

/datum/unit_test/voidcrew_stealth_fix3_real_guns/Run()
	// gun => whether it is a real gun
	var/list/guns = list(
		/obj/item/gun/ballistic/automatic/pistol = TRUE,
		/obj/item/gun/energy/disabler = TRUE,
		/obj/item/gun/ballistic/automatic/pistol/toy = FALSE,
		/obj/item/gun/medbeam = FALSE,
		/obj/item/gun/ballistic/shotgun/toy/crossbow = FALSE,
		/obj/item/gun/energy/laser/redtag = FALSE,
		/obj/item/gun/energy/laser/practice = FALSE,
		/obj/item/gun/syringe = FALSE,
	)
	var/datum/turf_reservation/block = stealth_block(10, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	for(var/gun_type in guns)
		var/real = guns[gun_type]
		var/obj/item/gun/gun = allocate(gun_type)
		TEST_ASSERT_EQUAL(!!stealth_threat_gun(gun), real, "[gun_type] is[real ? " not" : ""] a real gun")
		// A hostage: a neck grab, the gun in the off hand so the pose has to find it.
		var/mob/living/carbon/human/npc/friend = stealth_guard(block, 3, 2, WEST)
		var/mob/living/carbon/human/holder = stealth_person(block, 2, 2)
		holder.put_in_inactive_hand(gun, forced = TRUE)
		TEST_ASSERT_EQUAL(holder.get_inactive_held_item(), gun, "Test fixture: [gun_type] not in hand")
		stealth_test_grab(holder, friend, GRAB_NECK)
		if(real)
			TEST_ASSERT_EQUAL(stealth_hostage_of(holder), friend, "A neck grab with [gun_type] isn't a hostage")
			var/expected_hand = IS_RIGHT_INDEX(holder.get_held_index_of_item(gun)) ? "R" : "L"
			TEST_ASSERT_EQUAL(holder.hostage_pose_hand(), expected_hand, "The pose's gun hand isn't the one holding [gun_type]")
		else
			TEST_ASSERT_NULL(stealth_hostage_of(holder), "A neck grab with [gun_type] is a hostage")
		holder.stop_pulling()
		// Covered: the one it gave up to, right next to it, gun in hand.
		var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 4, WEST)
		var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_ai(guard)
		holder.forceMove(stealth_at(block, 5, 4))
		guard_ai.holdup_aimer = WEAKREF(holder)
		TEST_ASSERT_EQUAL(!!guard_ai.stealth_holdup_covered(), real, "Next to someone with [gun_type], the guard is[real ? " not" : ""] covered")
		guard_ai.holdup_aimer = null
		qdel(guard)
		qdel(friend)
		qdel(holder)
	qdel(block)
