/**
 * Outpost police tests: no blow on someone already down (police_arrest.dm strike()). Helpers are in
 * voidcrew_outpost_police_arrest.dm and voidcrew_outpost_police_helpers.dm.
 *
 * The arresting officer's AI plans a baton blow on every planning tick while its case is on the subdue step
 * (plan_for()); the case itself only moves on to the cuffs once a second. A suspect a colleague's disabler put into
 * stamina crit in between was struck again (soak shove_officers, Quartermain).
 */
/datum/unit_test/voidcrew_outpost_police_no_blow_on_downed

/datum/unit_test/voidcrew_outpost_police_no_blow_on_downed/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/list/parts = police_arrest_setup(outpost)
	if(!parts)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = parts[1]
	var/mob/living/carbon/human/suspect = parts[2]
	var/datum/outpost_police_case/case = parts[3]

	// Fighting on after the order: the subdue step
	suspect.set_combat_mode(TRUE)
	case.set_step("order")
	case.step_order()
	case.order_at = world.time - 10 SECONDS
	case.step_order()
	TEST_ASSERT_EQUAL(case.step, "subdue", "A suspect in combat mode was not to be subdued")

	// Put down by someone else before the case's next second: the officer's AI plans again first
	suspect.adjustStaminaLoss(200)
	TEST_ASSERT(HAS_TRAIT(suspect, TRAIT_INCAPACITATED), "200 stamina damage did not put the suspect down")
	TEST_ASSERT_EQUAL(case.step, "subdue", "The case left the subdue step on its own")
	TEST_ASSERT(officer.Adjacent(suspect), "The officer is not beside the suspect")
	case.plan_for(officer.ai_controller, officer)
	sleep(1)
	TEST_ASSERT_EQUAL(case.strikes, 0, "The arresting officer struck a suspect already down in stamina crit")

	// Lying there of their own accord, not stunned: the cuffs come next, not the baton
	suspect.setStaminaLoss(0)
	suspect.remove_status_effect(/datum/status_effect/incapacitating/stamcrit)
	suspect.SetAllImmobility(0)
	suspect.set_resting(TRUE, silent = TRUE, instant = TRUE)
	TEST_ASSERT(!HAS_TRAIT(suspect, TRAIT_INCAPACITATED), "The suspect is still stunned")
	TEST_ASSERT_EQUAL(suspect.body_position, LYING_DOWN, "The suspect did not lie down")
	officer.next_move = 0
	officer.next_click = 0
	case.plan_for(officer.ai_controller, officer)
	sleep(1)
	TEST_ASSERT_EQUAL(case.strikes, 0, "The arresting officer struck a suspect lying down for the cuffs")

	// Up and fighting again: the baton is still there for them
	suspect.set_resting(FALSE, silent = TRUE, instant = TRUE)
	TEST_ASSERT_EQUAL(suspect.body_position, STANDING_UP, "The suspect did not get up")
	officer.next_move = 0
	officer.next_click = 0
	case.plan_for(officer.ai_controller, officer)
	sleep(1)
	TEST_ASSERT(case.strikes >= 1, "The arresting officer threw no blow at a suspect up and fighting on the subdue step")

/**
 * The desk step's walk to the evidence locker takes the suspect along, as the escort does: a hold that slipped is
 * taken again first. It used to walk on to the locker alone, leaving the suspect standing in the cuffs; their next
 * steps counted as a bolt and two officers batoned them "in custody" (soak shove_officers, Undertow).
 */
/datum/unit_test/voidcrew_outpost_police_desk_keeps_hold

/datum/unit_test/voidcrew_outpost_police_desk_keeps_hold/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/list/parts = police_arrest_setup(outpost)
	if(!parts)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = parts[1]
	var/mob/living/carbon/human/suspect = parts[2]
	var/datum/outpost_police_case/case = parts[3]

	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	suspect.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	case.step_cuff()
	TEST_ASSERT_EQUAL(case.step, "search", "Cuffs on did not lead to the search")
	case.searched = TRUE

	// Carrying evidence for the locker, on the desk step, with no hold on the suspect beside it
	var/obj/item/evidence = allocate(/obj/item/outpost_sealed_case/evidence)
	evidence.forceMove(officer)
	var/obj/structure/closet/secure_closet/outpost_evidence/locker = police_evidence_locker(outpost)
	TEST_ASSERT_NOTNULL(locker, "The outpost has no evidence locker")
	case.set_step("desk")
	TEST_ASSERT_NOTNULL(case.evidence_spot(officer), "The officer has no evidence to put away")
	officer.stop_pulling()
	TEST_ASSERT(officer.Adjacent(suspect), "The officer is not beside the suspect")
	case.step_desk()
	TEST_ASSERT_EQUAL(officer.pulling, suspect, "On the way to the evidence locker the officer left the cuffed suspect standing alone")

/**
 * Item B (soak five_star_heavy, Undertow): a downed five-star suspect lay beside searching officers for a minute and
 * nobody finished them. stealth_candidates() (stealth_perception.dm) dropped anyone down or tied up with no ckey, the
 * rule for an NPC captive; a body with a mind is a person's, whether or not their player is at the keys (ghosted,
 * disconnected, or the soak's scripted suspect). An NPC down or in cuffs is still nobody's to notice.
 */
/datum/unit_test/voidcrew_outpost_police_downed_person_seen

/datum/unit_test/voidcrew_outpost_police_downed_person_seen/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(/obj/structure/overmap/trader_outpost/black_market)
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	TEST_ASSERT(!police.profile.spares_downed, "Setup: the red zone's police spare the downed")
	police.sleep_tick()
	stun_squad_isolate(police)
	var/list/turf/row = dispatch_row(outpost)
	TEST_ASSERT_NOTNULL(row, "No three free tiles in a row on the concourse")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = stun_squad_officers(outpost, 1)[1]
	officer.forceMove(row[1])
	officer.setDir(get_dir(row[1], row[3]))
	var/mob/living/carbon/human/suspect = police_arrest_person(row[3])
	police_pin_warrant(police, suspect.mind, 145) // five stars
	suspect.adjustBruteLoss(110)
	TEST_ASSERT(suspect.stat != CONSCIOUS && suspect.stat != DEAD, "110 brute did not put the suspect into crit")
	TEST_ASSERT_NULL(suspect.ckey, "Setup: the suspect has a ckey")
	TEST_ASSERT(police.finishes_downed(suspect, officer), "Setup: the red zone does not finish a downed five-star suspect")

	TEST_ASSERT(suspect in stealth_candidates(officer, 9), "A downed person with no player at the keys is not someone an officer can notice") // 9: HUMAN_NPC_SIGHT_RANGE
	// A body with no mind and no player, down: nobody's to notice, as before
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent, row[2])
	body.adjustStaminaLoss(200)
	TEST_ASSERT(HAS_TRAIT(body, TRAIT_INCAPACITATED), "200 stamina damage did not put the body down")
	TEST_ASSERT(!(body in stealth_candidates(officer, 9)), "A downed body with no mind is someone an officer can notice") // 9: HUMAN_NPC_SIGHT_RANGE
	qdel(body)

	// Searching, with them lying two tiles in front of it: alert on them and a shot planned
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	brain.stealth_setup()
	brain.stealth_go_searching(get_turf(officer))
	officer.setDir(get_dir(row[1], row[3]))
	for(var/i in 1 to 8)
		if(brain.stealth_state() == "alert") // STEALTH_ALERT
			break
		brain.stealth_look()
		sleep(5)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "alert", "A searching red zone officer did not go on alert at a downed five-star suspect two tiles in front of it")
	TEST_ASSERT_EQUAL(brain.blackboard[BB_BASIC_MOB_CURRENT_TARGET], suspect, "The officer is alert on someone else")
	TEST_ASSERT(police_plans_shot(officer, suspect), "A red zone officer plans no shot at a downed five-star suspect")
	police_pin_warrant(police, suspect.mind, 0)
	dispatch_clear(police)

/**
 * Items C and E: an officer's shot hit a colleague (soak five_star_heavy, Quartermain: M1's rubber shot on H1) or a
 * suspect down under arrest that lay on the line to someone else. bystander_in_line() let every shot pass over the
 * lying, but tg's combat-mode shot hits anyone on the floor in its first ten tiles who is not out cold
 * (projectile can_hit_target(), hit_prone_targets).
 */
/datum/unit_test/voidcrew_stealth_live/police/prone_in_line

/datum/unit_test/voidcrew_stealth_live/police/prone_in_line/Run()
	TEST_ASSERT(police_room(12, 5), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(2, 2, EAST)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/colleague = officer_at(4, 2, EAST)
	var/mob/living/carbon/human/suspect = visitor_at(8, 2)
	police_pin_warrant(police, suspect.mind, 25) // two stars
	TEST_ASSERT_EQUAL(officer.bystander_in_line(suspect), colleague, "Fixture: a colleague standing in the line is not in the way")
	colleague.adjustStaminaLoss(200)
	TEST_ASSERT_EQUAL(colleague.body_position, LYING_DOWN, "Fixture: 200 stamina damage did not floor the colleague")
	TEST_ASSERT_EQUAL(officer.bystander_in_line(suspect), colleague, "An officer fires over a colleague lying in stamina crit, whom its shot hits")
	// Out cold, tg's shot passes over them
	colleague.Unconscious(1 MINUTES)
	TEST_ASSERT(HAS_TRAIT(colleague, TRAIT_IMMOBILIZED) && HAS_TRAIT(colleague, TRAIT_FLOORED) && HAS_TRAIT(colleague, TRAIT_HANDS_BLOCKED), "Fixture: the unconscious colleague is not out cold to a bullet")
	TEST_ASSERT_NULL(officer.bystander_in_line(suspect), "An officer holds fire for a colleague out cold, whom its shot passes over")
	police_pin_warrant(police, suspect.mind, 0)
