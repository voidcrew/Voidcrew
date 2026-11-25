/**
 * An officer whose shot a colleague spoils steps aside only onto a tile with a clear line, and otherwise holds.
 * Pass 13: the sidestep took any free tile no further from the target, every half second, clear line or not. In a hall
 * two tiles wide, behind colleagues firing ahead, an officer stepped from one side to the other and back for as long as
 * they stood there (soak "pacing": Quartermain jailbreak_shootout B1 at 16-17,7, the Undertow kill_then_hide O2 at
 * 21-23,25, Halcyon kill_then_hide O1 and O2 at 36-38,32).
 */
/datum/unit_test/voidcrew_stealth_live/police/reposition_hall

/datum/unit_test/voidcrew_stealth_live/police/reposition_hall/Run()
	// A hall two tiles wide
	TEST_ASSERT(police_room(12, 2), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(1, 0, EAST)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/front_low = officer_at(3, 0, EAST)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/front_high = officer_at(3, 1, EAST)
	var/mob/living/carbon/human/target = visitor_at(9, 0)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/someone as anything in list(officer, front_low, front_high))
		ADD_TRAIT(someone, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(officer.bystander_in_line(target), front_low, "Fixture: the colleague ahead is not in the officer's line")
	// Both sides of the hall are behind a colleague: no step clears the line, so it holds where it is
	var/turf/start = get_turf(officer)
	var/moves = 0
	for(var/i in 1 to 6)
		var/turf/before = get_turf(officer)
		officer.police_reposition(target)
		if(get_turf(officer) != before)
			moves++
	TEST_ASSERT_EQUAL(moves, 0, "With a colleague ahead on both sides of a hall, the officer stepped [moves] times in 6 tries, ending at [get_turf(officer) == start ? "where it began" : "another tile"]")
	TEST_ASSERT_EQUAL(get_turf(officer), start, "The officer left its tile with no clear line to be had")
	// One side clears: it steps there, and the line from there is clear
	front_high.forceMove(at(11, 1))
	officer.police_reposition(target)
	TEST_ASSERT_EQUAL(get_turf(officer), at(2, 1), "With the upper side of the hall clear, the officer stepped to [get_turf(officer)] and not beside the colleague")
	TEST_ASSERT_NULL(officer.bystander_in_line(target), "The officer stepped aside onto a tile with its line still spoiled by [officer.bystander_in_line(target)]")
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/someone as anything in list(officer, front_low, front_high))
		REMOVE_TRAIT(someone, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
