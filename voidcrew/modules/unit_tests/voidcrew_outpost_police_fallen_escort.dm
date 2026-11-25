/**
 * Outpost police tests: an arresting officer who falls on the walk to the cells (police_arrest.dm staff()). A colleague
 * on their feet takes the cuffed prisoner on. Fork defines are included after the tests, so values are written out:
 * step "escort", one star is 12 heat and four stars 95 (OUTPOST_POLICE_STAR_HEAT).
 */
/datum/unit_test/voidcrew_outpost_police_fallen_escort

/datum/unit_test/voidcrew_outpost_police_fallen_escort/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	for(var/heat in list(12, 95))
		check_takeover(outpost, heat)

/datum/unit_test/voidcrew_outpost_police_fallen_escort/proc/check_takeover(obj/structure/overmap/trader_outpost/outpost, heat)
	// At three stars and up an arrest is only opened on someone who went down (open_case()): the takedown
	var/list/parts = police_arrest_setup(outpost, heat, heat >= 50)
	if(!parts)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = parts[1]
	var/mob/living/carbon/human/suspect = parts[2]
	var/datum/outpost_police_case/case = parts[3]
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	suspect.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	case.cuffs_on(suspect)
	case.searched = TRUE
	case.set_step("escort")
	case.step_escort()
	TEST_ASSERT_EQUAL(officer.pulling, suspect, "[heat] heat: the officer did not take hold of a cuffed suspect")
	var/walk_step = case.step
	// A colleague a few tiles off, on their feet with nothing to do
	var/turf/near = police_arrest_beside(suspect)
	TEST_ASSERT_NOTNULL(near, "[heat] heat: no floor beside the suspect")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/colleague = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, near)
	police_arrest_kit(colleague)
	// The arresting officer goes down on the walk
	officer.adjustBruteLoss(officer.health + 20)
	TEST_ASSERT(officer.stat != CONSCIOUS, "[heat] heat: setup: the arresting officer is still up at [officer.health] health")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/taker
	// The nearest officer takes a cuffed prisoner on at any stars (nearest_free_officer())
	for(var/tick in 1 to 30)
		case.process_case()
		if(QDELETED(case))
			break
		taker = case.arresting()
		if(taker && taker != officer && taker.pulling == suspect)
			break
		sleep(1 SECONDS)
	TEST_ASSERT(!QDELETED(case), "[heat] heat: the arrest ended when its officer fell on the walk")
	if(QDELETED(case))
		return
	TEST_ASSERT_NOTNULL(taker, "[heat] heat: nobody took on the cuffed prisoner when the arresting officer fell ([describe_roster(outpost.police, suspect)])")
	TEST_ASSERT(taker != officer, "[heat] heat: the fallen officer is still the arresting officer")
	TEST_ASSERT_EQUAL(taker, colleague, "[heat] heat: [taker] ([taker?.unit_kind], [get_dist(taker, suspect)] tiles off) took the cuffed prisoner on, not the colleague beside them")
	TEST_ASSERT_EQUAL(taker?.pulling, suspect, "[heat] heat: [taker] took the arrest on and did not take hold of the prisoner (step [case.step])")
	TEST_ASSERT(case.step in list(walk_step, "escort", "desk"), "[heat] heat: the walk went back to [case.step] when its officer fell")
	police_pin_warrant(outpost.police, suspect.mind, 0)
	outpost.police.close_case(suspect.mind)

/datum/unit_test/voidcrew_outpost_police_fallen_escort/proc/describe_roster(datum/outpost_police/police, mob/living/suspect)
	var/list/roster = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/someone in police.officers)
		roster += "[someone] ([someone.unit_kind], [get_dist(someone, suspect)] tiles, stat [someone.stat], case [someone.case ? "yes" : "no"])"
	return jointext(roster, "; ")

/**
 * The arresting officer falls on the walk and nobody is fit to take the prisoner on: the step's clock stands still on
 * purpose, and the case keeps since when it has had nobody (unstaffed_since), cleared once an officer is on it again.
 */
/datum/unit_test/voidcrew_outpost_police_unstaffed_escort
	/// Officers this test held still: let go however the test ends
	var/list/held = list()

/datum/unit_test/voidcrew_outpost_police_unstaffed_escort/Destroy()
	for(var/mob/living/other as anything in held)
		if(!QDELETED(other))
			REMOVE_TRAIT(other, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
	held = null
	return ..()

/datum/unit_test/voidcrew_outpost_police_unstaffed_escort/Run()
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
	case.cuffs_on(suspect)
	case.searched = TRUE
	case.set_step("escort")
	TEST_ASSERT_EQUAL(case.unstaffed_since, 0, "A staffed arrest says it has had nobody since [case.unstaffed_since]")
	// Every other officer held in a wave's lift (not fit, officer_fit())
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/other in outpost.police.officers)
		if(other != officer && !HAS_TRAIT(other, TRAIT_AI_PAUSED))
			ADD_TRAIT(other, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
			held += other
	officer.adjustBruteLoss(officer.health + 20)
	var/fell_at = world.time
	case.process_case()
	TEST_ASSERT(!QDELETED(case), "The arrest ended when its officer fell with nobody to take over")
	if(QDELETED(case))
		return
	TEST_ASSERT_NULL(case.arresting(), "[case.arresting()] took the arrest on though every officer was held")
	TEST_ASSERT_EQUAL(case.unstaffed_since, fell_at, "An arrest with nobody on it did not note since when")
	sleep(2 SECONDS)
	case.process_case()
	TEST_ASSERT_EQUAL(case.unstaffed_since, fell_at, "Another second with nobody on it moved unstaffed_since")
	TEST_ASSERT_EQUAL(case.step_started_at, world.time, "The step's clock ran with nobody on the arrest")
	// A colleague is free again: the arrest has an officer and the note clears
	for(var/mob/living/other as anything in held)
		REMOVE_TRAIT(other, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
	held.Cut()
	var/turf/near = police_arrest_beside(suspect)
	if(near)
		police_arrest_kit(police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, near))
	case.process_case()
	if(!QDELETED(case))
		TEST_ASSERT_NOTNULL(case.arresting(), "Nobody took the arrest on once officers were free again")
		TEST_ASSERT_EQUAL(case.unstaffed_since, 0, "An arrest with an officer on it again still says it has had nobody")
	police_pin_warrant(outpost.police, suspect.mind, 0)
	outpost.police.close_case(suspect.mind)

/**
 * The arresting officer falls on the walk, every officer on the floor is held, and a response unit is walking back to
 * its lift (sent home: a prisoner in our cuffs is in custody to dispatch). It is called back and takes the prisoner on.
 */
/datum/unit_test/voidcrew_outpost_police_unstaffed_escort/recalled

/datum/unit_test/voidcrew_outpost_police_unstaffed_escort/recalled/Run()
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
	case.cuffs_on(suspect)
	case.searched = TRUE
	case.set_step("escort")
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/other in outpost.police.officers)
		if(other != officer && !HAS_TRAIT(other, TRAIT_AI_PAUSED))
			ADD_TRAIT(other, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
			held += other
	// A response unit beside them, on its way out to a lift
	var/turf/near = police_arrest_beside(suspect)
	TEST_ASSERT_NOTNULL(near, "No floor beside the suspect")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/unit = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, near)
	police_arrest_kit(unit)
	if(!outpost.police.dispatch_send_home(unit) && !unit.npc_exit)
		unit.npc_walk_out(police_floor(outpost))
	TEST_ASSERT(unit.npc_exit, "Setup: the response unit is not on its way out")
	officer.adjustBruteLoss(officer.health + 20)
	TEST_ASSERT(officer.stat != CONSCIOUS, "Setup: the arresting officer is still up at [officer.health] health")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/taker
	for(var/tick in 1 to 10)
		case.process_case()
		if(QDELETED(case))
			break
		taker = case.arresting()
		if(taker == unit && unit.pulling == suspect)
			break
		sleep(1 SECONDS)
	TEST_ASSERT(!QDELETED(case), "The arrest ended when its officer fell")
	if(QDELETED(case))
		return
	TEST_ASSERT_EQUAL(taker, unit, "Nobody took the cuffed prisoner on: the response unit walking out was not called back (it is [unit.npc_exit ? "still leaving" : "not leaving"], case [unit.case ? "yes" : "no"])")
	TEST_ASSERT_NULL(unit.npc_exit, "The response unit on the arrest is still walking out")
	TEST_ASSERT_EQUAL(unit.pulling, suspect, "The recalled unit took the arrest on and did not take hold of the prisoner (step [case.step])")
	police_pin_warrant(outpost.police, suspect.mind, 0)
	outpost.police.close_case(suspect.mind)
