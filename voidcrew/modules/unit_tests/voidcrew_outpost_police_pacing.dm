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

/**
 * A cover two tiles from the officer it covers, across the line between the concourse and the lobby, stays where it is.
 * Pass 15: cover_follow() sent a cover on the concourse side of the checkpoint's inner door on stealth's long walk to
 * the arresting officer in the chamber; one step on, in the doorway on the lobby side, the near walk had it near enough
 * and stepped it back off the doorway onto the concourse, and so on (soak "pacing", Quartermain gate_emag_stay, B2 at
 * 19,11/19,12).
 */
/datum/unit_test/voidcrew_stealth_live/police/cover_across_checkpoint
	/// Turf -> the area it had before the test made it concourse or lobby
	var/list/old_areas = list()

/datum/unit_test/voidcrew_stealth_live/police/cover_across_checkpoint/Run()
	// A hall one tile wide: concourse at 0-2, the lobby (the checkpoint's area) at 3-5
	TEST_ASSERT(police_room(6, 1), "No room for the test")
	var/area/concourse = new /area/voidcrew/trader_outpost
	var/area/lobby = new /area/voidcrew/trader_outpost/checkpoint
	for(var/dx in 0 to 5)
		var/turf/spot = at(dx, 0)
		old_areas[spot] = get_area(spot)
		spot.change_area(get_area(spot), dx <= 2 ? concourse : lobby)
	TEST_ASSERT_EQUAL(police.sector_of(at(2, 0)), "concourse", "Fixture: the concourse side is not the concourse") // POLICE_SECTOR_CONCOURSE
	TEST_ASSERT_EQUAL(police.sector_of(at(4, 0)), "lobby", "Fixture: the lobby side is not the lobby") // POLICE_SECTOR_LOBBY
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/lead = officer_at(4, 0, EAST)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/cover = officer_at(2, 0, EAST)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/someone as anything in list(lead, cover))
		ADD_TRAIT(someone, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = cover.ai_controller
	var/datum/outpost_police_case/case = allocate(/datum/outpost_police_case, police, null)
	// Two tiles off, across the line (CASE_COVER_DISTANCE 2): near enough, no walk
	TEST_ASSERT(!case.cover_follow(brain, cover, lead), "A cover two tiles from the officer it covers, across the checkpoint line, set off walking to them")
	TEST_ASSERT_NULL(brain.goto_dest, "A cover two tiles from the officer it covers, across the checkpoint line, was given a walk to [brain.goto_dest]")
	// Three tiles off, across the line: it still walks over, the long way that knows the checkpoint
	cover.forceMove(at(1, 0))
	TEST_ASSERT(case.cover_follow(brain, cover, lead), "A cover three tiles from the officer it covers, across the checkpoint line, did not walk over")
	brain.stealth_drop_walk()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/someone as anything in list(lead, cover))
		REMOVE_TRAIT(someone, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)

/datum/unit_test/voidcrew_stealth_live/police/cover_across_checkpoint/Destroy()
	for(var/turf/spot as anything in old_areas)
		spot.change_area(get_area(spot), old_areas[spot])
	old_areas = null
	return ..()

/**
 * An officer too close to its target never takes the exit gate's tile as the one to step back onto: from the lobby side
 * the gate lets nobody in, and the backstep walk to it went round and round beside it. Pass 15: B1 in the Halcyon
 * checkpoint hall, the suspect a step off, chose the gate at 31,28 and walked 32,27/33,27 until it was shot down (soak
 * "pacing", Halcyon four_star_crawl).
 */
/datum/unit_test/voidcrew_stealth_live/police/step_back_not_into_gate

/datum/unit_test/voidcrew_stealth_live/police/step_back_not_into_gate/Run()
	TEST_ASSERT(police_room(5, 3), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(2, 1, EAST)
	ADD_TRAIT(officer, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
	var/mob/living/carbon/human/target = visitor_at(3, 1)
	// The gate straight behind the officer, letting people through eastward only (from the concourse to the lobby)
	var/obj/structure/outpost_exit_gate/gate = allocate(/obj/structure/outpost_exit_gate, at(1, 1))
	gate.setDir(EAST)
	TEST_ASSERT(!gate.CanPass(officer, EAST), "Fixture: the gate lets someone in from its far side")
	var/turf/spot = outpost_police_step_back_spot(officer, target)
	TEST_ASSERT_NOTEQUAL(spot, get_turf(gate), "An officer too close to its target chose the exit gate's tile to step back onto")
	TEST_ASSERT_NOTNULL(spot, "With room either side of the gate, an officer too close to its target found nowhere to step back to")
	REMOVE_TRAIT(officer, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)

/**
 * An officer that comes round from a wound whose author is dead or held does not get up and search for them. Pass 15:
 * B2, shot down by the suspect, was sutured back on its feet by a medic 86 s later, with the suspect long since in a
 * cell, and searched the concourse (soak "alert_after_clear", Quartermain four_star_crawl). Pass 14 made its colleagues
 * know such a fall (police_fall_known()); the officer itself did not.
 */
/datum/unit_test/voidcrew_stealth_live/police/came_round_known_wound

/datum/unit_test/voidcrew_stealth_live/police/came_round_known_wound/Run()
	TEST_ASSERT(police_room(12, 5), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 4))
	person_at(11, 4)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = ready_officer(3, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller

	// Shot by someone who is dead by the time the officer comes round
	var/mob/living/carbon/human/shooter = visitor_at(9, 2)
	police.officer_struck(officer, shooter, ATTACKER_DAMAGING_ATTACK)
	shooter.death()
	officer.adjustToxLoss(officer.maxHealth - officer.crit_threshold + 10) // the damage kind does not matter here
	TEST_ASSERT(officer.stat != CONSCIOUS, "Fixture: the officer is not down")
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	brain.stealth_go_unaware()
	officer.adjustToxLoss(-officer.getToxLoss())
	TEST_ASSERT_EQUAL(officer.stat, CONSCIOUS, "Fixture: the officer did not come round")
	TEST_ASSERT_EQUAL(brain.stealth_state(), "unaware", "An officer that came round from a wound by someone dead went looking for them")

	// Shot by someone still free: it gets up and looks round, as before
	var/mob/living/carbon/human/free = visitor_at(9, 4)
	police.officer_struck(officer, free, ATTACKER_DAMAGING_ATTACK)
	officer.adjustToxLoss(officer.maxHealth - officer.crit_threshold + 10)
	TEST_ASSERT(officer.stat != CONSCIOUS, "Fixture: the officer is not down the second time")
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	brain.stealth_go_unaware()
	officer.adjustToxLoss(-officer.getToxLoss())
	TEST_ASSERT_EQUAL(officer.stat, CONSCIOUS, "Fixture: the officer did not come round the second time")
	TEST_ASSERT(brain.stealth_state() != "unaware", "An officer that came round from a wound by someone still free did not look round")
