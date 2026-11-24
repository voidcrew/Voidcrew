/**
 * Outpost police tests for small walking faults found by the soak (voidcrew/modules/outpost_police/police_movement.dm,
 * voidcrew/modules/ambient_npcs/outpost_workers.dm and the townspeople's walking).
 * Written out: OUTPOST_GIVE_WAY_HOLD is 5 seconds, OUTPOST_GIVE_WAY_RANGE 2 tiles.
 */

/// An officer that stepped out of an escort's way does not walk straight back into it while the escort is by; once the escort has gone, it may
/datum/unit_test/voidcrew_stealth_live/police/give_way_once

/datum/unit_test/voidcrew_stealth_live/police/give_way_once/Run()
	TEST_ASSERT(police_room(8, 5), "No room for the test")
	var/mob/living/carbon/human/prisoner = person_at(1, 2, FALSE)
	var/mob/living/carbon/human/escort = person_at(2, 2, FALSE)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(3, 2, WEST)
	if(officer.move_intent == MOVE_INTENT_RUN)
		officer.toggle_move_intent()
	escort.start_pulling(prisoner)
	TEST_ASSERT_EQUAL(escort.pulling, prisoner, "Setup: the escort is not leading anyone")
	var/turf/in_the_way = at(3, 2)
	TEST_ASSERT(outpost_npc_step_aside(officer, escort, list()), "The officer did not step out of the escort's way")
	var/turf/stepped_to = get_turf(officer)
	TEST_ASSERT(stepped_to != in_the_way, "The officer did not move")
	TEST_ASSERT(!officer.Move(in_the_way, get_dir(stepped_to, in_the_way)), "The officer walked straight back into the escort's way")
	TEST_ASSERT_EQUAL(get_turf(officer), stepped_to, "The officer left the tile it stepped aside to")

	// The escort has gone on: the way is the officer's again
	escort.stop_pulling()
	escort.forceMove(at(7, 0))
	TEST_ASSERT(officer.Move(in_the_way, get_dir(stepped_to, in_the_way)), "The officer was still kept off the tile after the escort had gone")
