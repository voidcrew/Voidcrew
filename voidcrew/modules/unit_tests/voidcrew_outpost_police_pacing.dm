/**
 * An officer whose shot a colleague spoils never steps aside onto a tile nearer its target than it keeps away from them.
 * Pass 14: behind a colleague lying in soft crit between it and the suspect, the only tile with a clear line was the
 * colleague's own, a step from the suspect. police_reposition() stepped onto it; the keep-away step back
 * (outpost_police_step_back) stepped straight off it again, and so on twice a second (soak "pacing", the Undertow
 * shot_down_crawl, B1 at 28,19/29,19).
 */
/datum/unit_test/voidcrew_stealth_live/police/reposition_keep_away

/datum/unit_test/voidcrew_stealth_live/police/reposition_keep_away/Run()
	// A hall one tile wide: officer, colleague on the floor, suspect
	TEST_ASSERT(police_room(6, 1), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(1, 0, EAST)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/downed = officer_at(2, 0, EAST)
	var/mob/living/carbon/human/target = visitor_at(3, 0)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/someone as anything in list(officer, downed))
		ADD_TRAIT(someone, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(downed, TRAIT_FLOORED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(downed.body_position, LYING_DOWN, "Fixture: the colleague is not on the floor")
	// BB_HUMAN_NPC_KEEP_AWAY
	TEST_ASSERT_EQUAL(officer.ai_controller?.blackboard["human_npc_keep_away"], 2, "Fixture: the officer keeps no distance of 2")
	TEST_ASSERT_EQUAL(officer.bystander_in_line(target), downed, "Fixture: the colleague on the floor does not spoil the officer's line")
	var/turf/start = get_turf(officer)
	officer.police_reposition(target)
	TEST_ASSERT_EQUAL(get_turf(officer), start, "The officer stepped aside onto [get_turf(officer)], [get_dist(officer, target)] tile(s) from its target, nearer than it keeps away")
	TEST_ASSERT_NULL(officer.police_clear_shot_spot(target), "A tile nearer the target than the officer keeps away was offered for a clear shot")
	REMOVE_TRAIT(downed, TRAIT_FLOORED, TRAIT_SOURCE_UNIT_TESTS)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/someone as anything in list(officer, downed))
		REMOVE_TRAIT(someone, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)

/**
 * An officer standing with the suspect it leads, facing them (taking the evidence off them, or turned to them while it
 * waits), moves nobody along the way it faces: that way is behind the suspect, not where it is going. Pass 14:
 * make_way() moved the cover officer standing behind the suspect on ahead a tile every second, and its cover walk
 * brought it straight back (soak "pacing", the Undertow crime_then_hide, B2 at 23,2/24,2 at the desk).
 */
/datum/unit_test/voidcrew_stealth_live/police/make_way_facing_suspect

/datum/unit_test/voidcrew_stealth_live/police/make_way_facing_suspect/Run()
	// A hall one tile wide: the officer, its suspect, its cover, as by the Undertow's desk
	TEST_ASSERT(police_room(7, 1), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(1, 0, EAST)
	var/mob/living/carbon/human/suspect = person_at(2, 0, FALSE)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/cover = officer_at(3, 0, WEST)
	// The cover is left awake: a paused NPC is never moved aside (outpost_npc_can_make_room())
	ADD_TRAIT(officer, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
	officer.start_pulling(suspect)
	TEST_ASSERT_EQUAL(officer.pulling, suspect, "Setup: the officer is not leading the suspect")
	TEST_ASSERT(outpost_npc_can_make_room(cover), "Setup: the cover officer cannot step out of anyone's way")
	var/datum/outpost_police_case/case = allocate(/datum/outpost_police_case, police, null)
	officer.setDir(EAST)
	case.make_way(officer, suspect)
	TEST_ASSERT_EQUAL(get_turf(cover), at(3, 0), "The officer, facing the suspect it leads, moved the colleague behind them to [get_turf(cover)]")
	// Facing its way, with someone on it: they still step on ahead
	officer.stop_pulling()
	suspect.forceMove(at(0, 0))
	officer.start_pulling(suspect)
	officer.setDir(EAST)
	case.make_way(officer, suspect)
	TEST_ASSERT_NOTEQUAL(get_turf(cover), at(3, 0), "The officer facing its way with someone a step ahead did not move them on")
	REMOVE_TRAIT(officer, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
