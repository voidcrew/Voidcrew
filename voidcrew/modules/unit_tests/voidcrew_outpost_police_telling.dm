/**
 * Outpost police tests: townspeople tell someone in person (owner decisions 51 and 52;
 * voidcrew/modules/outpost_police/police_witness.dm) and outpost people react to grabs (decision 53, police_grab.dm).
 *
 * The room and police of voidcrew_stealth_live/police (voidcrew_outpost_police_stealth.dm), on the real stealth rules.
 * Nothing sleeps: the police tick is stepped by hand and a teller's start is moved back. Fork defines are included
 * after the tests, so values are written out: crimes "shot" (25 heat), "civilian"; OUTPOST_POLICE_RADIOLESS_TIME 3 s;
 * OUTPOST_POLICE_TELL_RANGE 3.
 */

/// A townsperson of this outpost at (dx, dy)
/datum/unit_test/voidcrew_stealth_live/police/proc/local_at(dx, dy)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/local = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost, at(dx, dy))
	local.set_place(SSambient_npcs.outpost_place(outpost))
	local.AddElement(/datum/element/forced_gravity, 1)
	return local

/// Shuts `who` in a closed locker at (dx, dy), out of everyone's sight
/datum/unit_test/voidcrew_stealth_live/police/proc/hide_in_locker(mob/living/who, dx, dy)
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, at(dx, dy))
	locker.opened = FALSE
	who.forceMove(locker)
	return locker

/// Moves `teller`'s telling of `report` on past OUTPOST_POLICE_RADIOLESS_TIME; FALSE if they are not telling anyone
/datum/unit_test/voidcrew_stealth_live/police/proc/hurry_telling(datum/outpost_pending_report/report, mob/living/teller)
	var/list/entry = LAZYACCESS(report.telling, WEAKREF(teller))
	if(!entry)
		return FALSE
	entry[2] = world.time - 3 SECONDS // OUTPOST_POLICE_RADIOLESS_TIME
	return TRUE

/// A townsperson who saw a crime, with nobody they can tell, makes no warrant; the report dies with its keep
/datum/unit_test/voidcrew_stealth_live/police/telling_nobody

/datum/unit_test/voidcrew_stealth_live/police/telling_nobody/Run()
	TEST_ASSERT(police_room(20, 9), "No room for the test")
	var/mob/living/carbon/human/suspect = visitor_at(4, 4)
	var/mob/living/carbon/human/dummy = person_at(6, 4, FALSE)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/local = local_at(5, 4)
	TEST_ASSERT_NULL(police.report_crime(suspect, "shot", dummy), "A townsperson's report counted before they told anyone")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 1, "Setup: the townsperson's report was not queued")
	var/datum/outpost_pending_report/report = police.pending_reports[1]
	for(var/i in 1 to 5)
		police.tick_warrants()
	TEST_ASSERT_NULL(police.get_warrant(suspect.mind), "A townsperson with nobody to tell made a warrant by waiting")
	TEST_ASSERT_NULL(LAZYACCESS(report.telling, WEAKREF(local)), "A townsperson started telling with nobody there")
	report.expires = world.time
	police.tick_warrants()
	TEST_ASSERT_EQUAL(length(police.pending_reports), 0, "An untold report outlived its keep")
	TEST_ASSERT_NULL(police.get_warrant(suspect.mind), "An untold report made a warrant when it was dropped")

/// A townsperson who stands by an officer long enough gets the officer to call it in; the warrant starts at the scene
/datum/unit_test/voidcrew_stealth_live/police/telling_officer

/datum/unit_test/voidcrew_stealth_live/police/telling_officer/Run()
	TEST_ASSERT(police_room(20, 9), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(16, 4, EAST) // its back to the crime
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	var/mob/living/carbon/human/suspect = visitor_at(4, 4)
	var/mob/living/carbon/human/dummy = person_at(5, 3, FALSE)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/local = local_at(6, 4)
	var/turf/scene = get_turf(suspect)
	TEST_ASSERT_NULL(police.report_crime(suspect, "shot", dummy), "A townsperson's report counted before they told anyone")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 1, "Setup: the townsperson's report was not queued")
	var/datum/outpost_pending_report/report = police.pending_reports[1]
	TEST_ASSERT(!(WEAKREF(officer) in report.witnesses), "Setup: the officer saw the crime itself")

	// The suspect slips away out of sight; the townsperson goes to the officer
	hide_in_locker(suspect, 1, 7)
	local.forceMove(at(14, 4))
	police.tick_warrants()
	TEST_ASSERT(hurry_telling(report, local), "A townsperson two tiles from an officer with a radio did not start telling it")
	TEST_ASSERT_NULL(police.get_warrant(suspect.mind), "A warrant was made as soon as a townsperson started telling")
	police.tick_warrants()
	TEST_ASSERT(WEAKREF(officer) in report.witnesses, "The officer who was told did not take the report on")
	TEST_ASSERT_NULL(police.get_warrant(suspect.mind), "Telling an officer made a warrant before its radio call")
	TEST_ASSERT_NOTNULL(brain.pending_call, "The officer who was told has no radio call going")
	brain.stealth_rewind(4 SECONDS)
	brain.stealth_deliver_call()
	var/datum/outpost_warrant/warrant = police.get_warrant(suspect.mind)
	TEST_ASSERT_EQUAL(warrant?.heat, 25, "The told report did not count when the officer's call went out")
	TEST_ASSERT_EQUAL(warrant?.last_seen_turf, scene, "The police learned where the suspect hid, not where the townsperson saw them")
	TEST_ASSERT(warrant?.unseen_since, "A suspect nobody can see counted as seen when the told report landed")

/// Telling the police desk makes the report at once
/datum/unit_test/voidcrew_stealth_live/police/telling_desk

/datum/unit_test/voidcrew_stealth_live/police/telling_desk/Run()
	TEST_ASSERT(police_room(20, 9), "No room for the test")
	var/mob/living/carbon/human/suspect = visitor_at(4, 4)
	var/mob/living/carbon/human/dummy = person_at(5, 3, FALSE)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/local = local_at(6, 4)
	var/turf/scene = get_turf(suspect)
	police.desk_turf = at(14, 4)
	TEST_ASSERT_NULL(police.report_crime(suspect, "shot", dummy), "A townsperson's report counted before they told anyone")
	var/datum/outpost_pending_report/report = police.pending_reports[1]
	hide_in_locker(suspect, 1, 7)
	police.tick_warrants()
	TEST_ASSERT(istype(local.activity, /datum/ambient_activity/outpost_report), "A townsperson with the desk to run to did not set off")
	TEST_ASSERT_NULL(LAZYACCESS(report.telling, WEAKREF(local)), "A townsperson eight tiles off started telling the desk")
	local.forceMove(at(12, 4))
	police.tick_warrants()
	TEST_ASSERT(hurry_telling(report, local), "A townsperson two tiles from the desk did not start telling it")
	TEST_ASSERT_NULL(police.get_warrant(suspect.mind), "A warrant was made before the desk was told")
	police.tick_warrants()
	var/datum/outpost_warrant/warrant = police.get_warrant(suspect.mind)
	TEST_ASSERT_EQUAL(warrant?.heat, 25, "Telling the desk did not make the report at once")
	TEST_ASSERT_EQUAL(warrant?.last_seen_turf, scene, "The desk sent the police where the suspect hid, not to the scene")
	police.desk_turf = null

/// A grabbed or cuffed townsperson tells nobody until they are free again
/datum/unit_test/voidcrew_stealth_live/police/telling_held

/datum/unit_test/voidcrew_stealth_live/police/telling_held/Run()
	TEST_ASSERT(police_room(20, 9), "No room for the test")
	var/mob/living/carbon/human/suspect = visitor_at(4, 4)
	var/mob/living/carbon/human/dummy = person_at(5, 3, FALSE)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/local = local_at(6, 4)
	police.desk_turf = at(14, 4)
	TEST_ASSERT_NULL(police.report_crime(suspect, "shot", dummy), "A townsperson's report counted before they told anyone")
	var/datum/outpost_pending_report/report = police.pending_reports[1]
	local.forceMove(at(12, 4))
	var/mob/living/carbon/human/grabber = visitor_at(11, 4)
	grabber.start_pulling(local)
	TEST_ASSERT_EQUAL(grabber.pulling, local, "Setup: the townsperson could not be grabbed")
	police.tick_warrants()
	TEST_ASSERT_NULL(LAZYACCESS(report.telling, WEAKREF(local)), "A grabbed townsperson started telling the desk")
	grabber.stop_pulling()
	police.tick_warrants()
	TEST_ASSERT_NOTNULL(LAZYACCESS(report.telling, WEAKREF(local)), "A townsperson let go beside the desk did not start telling it")
	ADD_TRAIT(local, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	police.tick_warrants()
	TEST_ASSERT_NULL(LAZYACCESS(report.telling, WEAKREF(local)), "A cuffed townsperson kept telling the desk")
	TEST_ASSERT_NULL(police.get_warrant(suspect.mind), "A held townsperson made their report")
	REMOVE_TRAIT(local, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	police.tick_warrants()
	TEST_ASSERT(hurry_telling(report, local), "A townsperson freed of their cuffs did not start telling the desk again")
	police.tick_warrants()
	TEST_ASSERT_EQUAL(police.get_warrant(suspect.mind)?.heat, 25, "A freed townsperson's report never landed")
	police.desk_turf = null

/// A neck grab on a townsperson is the civilian assault; a plain pull is no crime, and one grab is one charge
/datum/unit_test/voidcrew_stealth_live/police/grab_reaction

/datum/unit_test/voidcrew_stealth_live/police/grab_reaction/Run()
	TEST_ASSERT(police_room(20, 9), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/local = local_at(5, 4)
	var/mob/living/carbon/human/grabber = visitor_at(6, 4)
	grabber.start_pulling(local)
	TEST_ASSERT_EQUAL(grabber.pulling, local, "Setup: the townsperson could not be grabbed")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 0, "A plain pull on a townsperson was reported as a crime")
	TEST_ASSERT_NULL(police.get_warrant(grabber.mind), "A plain pull on a townsperson made a warrant")
	grabber.setGrabState(GRAB_AGGRESSIVE)
	TEST_ASSERT_EQUAL(length(police.pending_reports), 1, "A rough grab on a townsperson was not reported")
	var/datum/outpost_pending_report/report = police.pending_reports[1]
	TEST_ASSERT_EQUAL(report.crime, "civilian", "A rough grab on a townsperson was not the civilian assault") // OUTPOST_CRIME_ASSAULT_CIVILIAN
	TEST_ASSERT_EQUAL(report.offender?.resolve(), grabber, "A rough grab was charged to someone else")
	police.recent_reports.Cut()
	grabber.setGrabState(GRAB_NECK)
	TEST_ASSERT_EQUAL(length(police.pending_reports), 1, "Tightening the same grab was charged again")
	grabber.stop_pulling()
