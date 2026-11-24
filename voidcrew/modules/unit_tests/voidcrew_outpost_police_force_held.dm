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
