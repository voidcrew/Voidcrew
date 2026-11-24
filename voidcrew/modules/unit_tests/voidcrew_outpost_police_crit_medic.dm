/**
 * Outpost police tests for owner decision 60: a suspect in crit is cuffed, searched, dragged in and booked in crit,
 * and a medic is called to the cell (police_cell_medic.dm). Fork defines are included after the tests: values are
 * written out with a comment naming the define. Helpers are in voidcrew_outpost_police_helpers.dm and
 * voidcrew_outpost_police_arrest.dm.
 */

/// Deletes every medic called to a cell at `police` (they are not allocated by the test)
/datum/unit_test/proc/crit_medic_cleanup(datum/outpost_police/police)
	if(!police)
		return
	for(var/datum/weakref/key as anything in police.cell_medics)
		var/datum/weakref/medic_ref = police.cell_medics[key]
		var/mob/living/medic = medic_ref?.resolve()
		if(!QDELETED(medic))
			qdel(medic)
	police.cell_medics.Cut()

/// Real brute damage that puts `person` in crit, as the recovery medic tests do
/datum/unit_test/proc/crit_medic_beat(mob/living/carbon/human/person)
	person.apply_damage(70, BRUTE, BODY_ZONE_CHEST)
	person.apply_damage(50, BRUTE, BODY_ZONE_HEAD)
	person.updatehealth()

/**
 * A cuffed, searched suspect in crit is dragged to the cell and booked while still in crit: stripped, the cuffs off,
 * held, the term standing still. The booking officer calls one medic, and a second call does nothing. The medic is
 * let in, treats the prisoner out of crit with the items on their belt, and walks out; the door shuts. A free player
 * in crit is never a cell medic's patient.
 */
/datum/unit_test/voidcrew_outpost_police_crit_medic_booked
	var/datum/outpost_police/test_police

/datum/unit_test/voidcrew_outpost_police_crit_medic_booked/Destroy()
	crit_medic_cleanup(test_police)
	test_police = null
	return ..()

/datum/unit_test/voidcrew_outpost_police_crit_medic_booked/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	test_police = police
	TEST_ASSERT(length(police.cells), "The outpost has no cells")
	var/list/parts = police_arrest_setup(outpost)
	if(!parts)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = parts[1]
	var/mob/living/carbon/human/suspect = parts[2]
	var/datum/outpost_police_case/case = parts[3]

	crit_medic_beat(suspect)
	TEST_ASSERT(suspect.stat != DEAD && recovery_in_crit(suspect), "Setup: the suspect is not in crit (stat [suspect.stat], health [suspect.health])")
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	suspect.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	case.cuffs_on(suspect)
	TEST_ASSERT_EQUAL(case.step, "search", "A cuffed suspect in crit is not searched next (the case is on [case.step])")
	for(var/i in 1 to 6)
		if(QDELETED(case) || case.searched)
			break
		case.process_case()
		police_arrest_wait(case)
	TEST_ASSERT(case.searched, "A cuffed suspect in crit was not searched where they lie")

	// The evidence goes first, then the cell door, the suspect in hand
	police_evidence_locker(outpost)
	case.set_step("desk")
	case.step_desk()
	police_arrest_wait(case)
	case.disposed_at = max(case.disposed_at, 1)
	police_jail_carry(officer, suspect, police.cell_door_turf(officer))
	TEST_ASSERT(recovery_in_crit(suspect), "Setup: the suspect came out of crit before the cell")
	case.set_step("book")
	case.step_book()
	police_arrest_wait(case, 40 SECONDS)

	var/datum/outpost_police_cell/cell = police.cell_holding(suspect.mind)
	TEST_ASSERT_NOTNULL(cell, "A suspect in crit was not booked into a cell")
	TEST_ASSERT(get_turf(suspect) in cell.tiles, "The prisoner in crit is not on the cell floor")
	TEST_ASSERT(recovery_in_crit(suspect), "The prisoner was not still in crit when booked")
	TEST_ASSERT_NULL(suspect.handcuffed, "The cuffs stayed on a prisoner booked in crit")
	TEST_ASSERT(cell.jailed[suspect.mind], "A prisoner booked in crit was not jailed (stripped)")
	TEST_ASSERT(QDELETED(case), "The case did not close after booking a suspect in crit")
	TEST_ASSERT(police.cell_at(get_turf(officer)) != cell, "The officer did not step out of the cell")
	TEST_ASSERT(police.in_custody(suspect), "A prisoner in crit is out of custody")

	// One medic, called once
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell/medic = police.cell_medic_for(suspect)
	TEST_ASSERT_NOTNULL(medic, "No medic was called for a prisoner booked in crit")
	TEST_ASSERT(police.call_cell_medic(suspect), "A second call for the same prisoner said no medic is coming")
	TEST_ASSERT_EQUAL(police.cell_medic_count(), 1, "A second call for the same prisoner sent another medic")
	TEST_ASSERT_EQUAL(police.cell_medic_for(suspect), medic, "A second call replaced the medic on the way")

	// The cell waits for the medic with its door shut, and the term runs (owner decision 104)
	police.tick_cells()
	TEST_ASSERT(cell.medic_called[suspect.mind], "The cell does not know a medic is coming")
	TEST_ASSERT_EQUAL(cell.medic_until, 0, "The door was held open with a medic on the way")
	TEST_ASSERT(!(suspect.mind in cell.return_by), "A prisoner in crit in the cell is waited for as if out of it")
	TEST_ASSERT(cell.prisoners[suspect.mind] > world.time, "A prisoner in crit has no term running")
	// The term runs out while they are still in crit: let out, and the medic called for them still comes
	cell.prisoners[suspect.mind] = world.time - 1
	police.tick_cells()
	TEST_ASSERT(!(suspect.mind in cell.prisoners), "A term that ran out in crit did not let the prisoner out")
	TEST_ASSERT(!police.in_custody(suspect), "A prisoner let out in crit is still in custody")
	TEST_ASSERT(recovery_in_crit(suspect), "Setup: the prisoner came out of crit before the medic")
	TEST_ASSERT_EQUAL(police.cell_medic_for(suspect), medic, "The medic's claim lapsed when the prisoner was let out")
	TEST_ASSERT(police.cell_patient_ok(suspect, cell), "Someone let out in crit on the cell floor is not the medic's patient")
	TEST_ASSERT(!police.cell_patient_ok(suspect), "Someone let out is a patient for a newly called medic")

	// The medic at the door: let in, the kit, out again. The test drives the job; their own AI is paused.
	var/obj/item/reagent_containers/hypospray/medipen/pen = locate() in medic.belt?.contents
	TEST_ASSERT_NOTNULL(pen, "The medic has no medipen on their belt")
	ADD_TRAIT(medic, TRAIT_AI_PAUSED, "outpost_police_test")
	medic.end_activity()
	medic.forceMove(cell.outside_turf)
	var/datum/ambient_activity/treat_prisoner/job = medic.start_activity(new /datum/ambient_activity/treat_prisoner(medic))
	TEST_ASSERT_NOTNULL(job, "The medic at the cell door has no job")
	var/until = world.time + 150 SECONDS
	var/went_in = FALSE
	while(world.time < until && !QDELETED(job) && medic.activity == job)
		if(!job.acting)
			var/result = job.act(1)
			if(result == 2) // AMBIENT_STEP_DONE
				break
			if(result == 1) // AMBIENT_STEP_MOVE
				TEST_FAIL("The medic was sent walking from the cell door ([AREACOORD(medic)])")
				break
		if(get_turf(medic) in cell.tiles)
			went_in = TRUE
		sleep(5)
	TEST_ASSERT(went_in, "The medic never got into the cell")
	TEST_ASSERT(suspect.stat != DEAD, "The prisoner died under treatment")
	TEST_ASSERT(!recovery_in_crit(suspect), "The prisoner is still in crit after the medic (health [suspect.health])")
	TEST_ASSERT(QDELETED(pen) || pen.used_up, "The medic's medipen was not used")
	TEST_ASSERT(medic.visit_over, "The medic is still on the job for a prisoner out of crit")
	TEST_ASSERT_NULL(police.cell_at(get_turf(medic)), "The medic did not walk out of the cell")
	TEST_ASSERT_NULL(police.cell_medic_for(suspect), "The medic's claim stands after they are done")
	sleep(3 SECONDS)
	cell.close_check()
	TEST_ASSERT(!cell.door.density, "The cell door shut on someone let out while the medic was at work")
	TEST_ASSERT_NULL(police.cell_holding(suspect.mind), "Someone let out is held again after the medic")

	// Never a free player
	var/mob/living/carbon/human/free = police_arrest_person(police_floor(outpost))
	crit_medic_beat(free)
	TEST_ASSERT(recovery_in_crit(free), "Setup: the free player is not in crit")
	TEST_ASSERT(!police.cell_patient_ok(free), "A free player in crit is a cell medic's patient")
	TEST_ASSERT(!police.call_cell_medic(free), "A medic was called for a free player in crit")
	TEST_ASSERT(!outpost.ensure_recovery().patient_ok(free), "A free player in crit is a recovery medic's patient")

/**
 * No medic to be had: the cell's door hold still opens. A medic killed on the way gives way to the hold, and with
 * the recovery port shut no medic is called and the hold opens at once.
 */
/datum/unit_test/voidcrew_outpost_police_crit_medic_fallback
	var/datum/outpost_police/test_police

/datum/unit_test/voidcrew_outpost_police_crit_medic_fallback/Destroy()
	crit_medic_cleanup(test_police)
	test_police = null
	return ..()

/datum/unit_test/voidcrew_outpost_police_crit_medic_fallback/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	test_police = police
	police.sleep_tick()
	// The ambient system makes the outpost's place once someone is there; the medic is made into it
	TEST_ASSERT_NOTNULL(SSambient_npcs.outpost_place(outpost), "The outpost has no ambient place")
	TEST_ASSERT(length(police.cells) >= 2, "The outpost has fewer than two cells")
	var/datum/outpost_police_cell/cell_a = police.cells[1]
	var/datum/outpost_police_cell/cell_b = police.cells[2]

	// A medic called, then killed on the way: the door opens for the prisoner's own people
	var/mob/living/carbon/human/prisoner = police_arrest_person(cell_a.tiles[1])
	police_pin_warrant(police, prisoner.mind, 12)
	cell_a.admit(prisoner, world.time + 1800, TRUE)
	crit_medic_beat(prisoner)
	TEST_ASSERT(recovery_in_crit(prisoner) && prisoner.stat != DEAD, "Setup: the prisoner is not in crit")
	police.tick_cells()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell/medic = police.cell_medic_for(prisoner)
	TEST_ASSERT_NOTNULL(medic, "No medic was called for a prisoner who went into crit in the cell")
	TEST_ASSERT_EQUAL(cell_a.medic_until, 0, "The door was held open with a medic on the way")
	ADD_TRAIT(medic, TRAIT_AI_PAUSED, "outpost_police_test")
	medic.death()
	police.tick_cells()
	TEST_ASSERT_NULL(police.cell_medic_for(prisoner), "A dead medic still holds the claim")
	TEST_ASSERT(cell_a.medic_until > world.time, "The door hold did not take over once the medic was killed")
	sleep(2 SECONDS)
	TEST_ASSERT(!cell_a.door.density, "The door did not open for the prisoner once the medic was killed")

	// The port shut after lost crews: no medic, the hold at once
	var/datum/outpost_recovery/recovery = outpost.ensure_recovery()
	recovery.port_shut_until = world.time + 10 MINUTES
	var/mob/living/carbon/human/second = police_arrest_person(cell_b.tiles[1])
	police_pin_warrant(police, second.mind, 12)
	cell_b.admit(second, world.time + 1800, TRUE)
	crit_medic_beat(second)
	TEST_ASSERT(recovery_in_crit(second) && second.stat != DEAD, "Setup: the second prisoner is not in crit")
	police.tick_cells()
	TEST_ASSERT_NULL(police.cell_medic_for(second), "A medic was called with the recovery port shut")
	TEST_ASSERT(cell_b.medic_until > world.time, "The door hold did not open with no medic to be had")
	sleep(2 SECONDS)
	TEST_ASSERT(!cell_b.door.density, "The door did not open for a prisoner in crit with no medic to be had")
	recovery.port_shut_until = 0
