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
	for(var/tick in 1 to 5)
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
	TEST_ASSERT_EQUAL(taker?.pulling, suspect, "[heat] heat: [taker] took the arrest on and did not take hold of the prisoner (step [case.step])")
	TEST_ASSERT(case.step in list(walk_step, "escort", "desk"), "[heat] heat: the walk went back to [case.step] when its officer fell")
	police_pin_warrant(outpost.police, suspect.mind, 0)
	outpost.police.close_case(suspect.mind)

/datum/unit_test/voidcrew_outpost_police_fallen_escort/proc/describe_roster(datum/outpost_police/police, mob/living/suspect)
	var/list/roster = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/someone in police.officers)
		roster += "[someone] ([someone.unit_kind], [get_dist(someone, suspect)] tiles, stat [someone.stat], case [someone.case ? "yes" : "no"])"
	return jointext(roster, "; ")
