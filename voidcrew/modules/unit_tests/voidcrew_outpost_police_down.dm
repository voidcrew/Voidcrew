/**
 * Outpost police tests: people on the floor (voidcrew/modules/stealth_police/police_stealth.dm and the body rule of
 * voidcrew/modules/stealth/stealth_ai.dm). Who is a body, and what the squad does while a suspect is down with the
 * cuffs not yet on.
 *
 * The room and police of voidcrew_stealth_live/police (voidcrew_outpost_police_stealth.dm), on the real stealth rules.
 * Nothing sleeps: the scan, the police tick and the case are stepped by hand, and what puts someone on the floor is
 * tg's own (Knockdown, Paralyze, stamina damage, Unconscious, cuffs). Fork defines are included after the tests, so
 * values are written out: states "unaware", "suspicious", "searching", "alert"; lines "stealth_body" and
 * "stealth_helpless"; the blackboard key "stealth_wary"; SHOVE_KNOCKDOWN_SOLID 2 s and SHOVE_CHAIN_PARALYZE 3 s are tg's.
 */

/// An officer at (dx, dy) with its routine running and its brain set up, as one on a concourse with a player on it
/datum/unit_test/voidcrew_stealth_live/police/proc/ready_officer(dx, dy, facing = EAST)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(dx, dy, facing)
	officer.resume_routine()
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = wake(officer)
	brain.stealth_setup()
	return officer

/// One look for fallen colleagues by `brain`, from unaware; returns the state it left it in
/datum/unit_test/voidcrew_stealth_live/police/proc/body_look(datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain)
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	brain.stealth_go_unaware()
	brain.next_body_scan = 0
	brain.stealth_check_bodies()
	return brain.stealth_state()

/// A colleague awake on the floor (shoved over, kicked onto their side, out of stamina, lying down) is nobody's body. Awake in cuffs they are found, but not called a body. Out cold or dead they are one.
/datum/unit_test/voidcrew_stealth_live/police/floored_no_body

/datum/unit_test/voidcrew_stealth_live/police/floored_no_body/Run()
	TEST_ASSERT(police_room(14, 7), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 6))
	person_at(13, 6)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = ready_officer(2, 3, EAST)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/colleague = ready_officer(5, 3, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/colleague_brain = colleague.ai_controller
	TEST_ASSERT_NOTNULL(brain.group, "Fixture: the officer has no patrol group")
	TEST_ASSERT_EQUAL(brain.group, colleague_brain.group, "Fixture: the two officers are not one patrol group")
	TEST_ASSERT_EQUAL(body_look(brain), "unaware", "Fixture: a colleague on their feet set the officer off")

	// Shoved to the floor (tg's shove against something solid)
	colleague.Knockdown(2 SECONDS) // SHOVE_KNOCKDOWN_SOLID
	TEST_ASSERT_EQUAL(colleague.body_position, LYING_DOWN, "Fixture: a knockdown did not put the colleague on the floor")
	TEST_ASSERT_EQUAL(body_look(brain), "unaware", "An officer took a colleague who was shoved to the floor for a body")
	TEST_ASSERT(!brain.bark_ready_at["stealth_body"], "An officer called in a colleague who was shoved to the floor as a body")
	colleague.SetKnockdown(0)

	// Kicked onto their side (tg's second shove)
	colleague.Paralyze(3 SECONDS) // SHOVE_CHAIN_PARALYZE
	TEST_ASSERT_EQUAL(body_look(brain), "unaware", "An officer took a colleague kicked onto their side for a body")
	colleague.SetParalyzed(0)

	// Out of stamina
	colleague.adjustStaminaLoss(200)
	TEST_ASSERT(HAS_TRAIT(colleague, TRAIT_INCAPACITATED) && colleague.stat == CONSCIOUS, "Fixture: 200 stamina damage did not put the colleague in stamina crit")
	TEST_ASSERT_EQUAL(body_look(brain), "unaware", "An officer took a colleague who is out of stamina for a body")
	colleague.setStaminaLoss(0)
	TEST_ASSERT(!HAS_TRAIT(colleague, TRAIT_INCAPACITATED), "Fixture: the colleague did not get their stamina back")

	// Lying down
	colleague.set_resting(TRUE, silent = TRUE, instant = TRUE)
	TEST_ASSERT_EQUAL(colleague.body_position, LYING_DOWN, "Fixture: the colleague did not lie down")
	TEST_ASSERT_EQUAL(body_look(brain), "unaware", "An officer took a colleague who is lying down for a body")
	colleague.set_resting(FALSE, silent = TRUE, instant = TRUE)
	TEST_ASSERT(!brain.bark_ready_at["stealth_body"], "An officer called in a colleague who is awake on the floor as a body")

	// Awake in cuffs: found, and asked after, but no body
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	colleague.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	TEST_ASSERT(HAS_TRAIT(colleague, TRAIT_RESTRAINED) && colleague.stat == CONSCIOUS, "Fixture: the colleague is not awake in cuffs")
	TEST_ASSERT_EQUAL(body_look(brain), "suspicious", "An officer walked past a colleague in cuffs")
	TEST_ASSERT(!brain.bark_ready_at["stealth_body"], "An officer called in a colleague who is awake in cuffs as a body")
	TEST_ASSERT(brain.bark_ready_at["stealth_helpless"] > world.time, "An officer had no word for a colleague in cuffs")
	colleague.uncuff()
	TEST_ASSERT_EQUAL(body_look(brain), "unaware", "A colleague out of the cuffs and on their feet set the officer off")

	// Out cold: a body
	colleague.Unconscious(20 SECONDS)
	TEST_ASSERT(colleague.stat != CONSCIOUS && colleague.stat != DEAD, "Fixture: the colleague is not out cold")
	TEST_ASSERT_EQUAL(body_look(brain), "suspicious", "An officer walked past a colleague who is out cold")
	TEST_ASSERT(brain.bark_ready_at["stealth_body"] > world.time, "An officer did not call in a colleague who is out cold")
	colleague.SetUnconscious(0)
	TEST_ASSERT_EQUAL(colleague.stat, CONSCIOUS, "Fixture: the colleague did not come round")
	TEST_ASSERT_EQUAL(body_look(brain), "unaware", "A colleague who came round set the officer off")

	// Dead: a body
	colleague.death()
	TEST_ASSERT_EQUAL(body_look(brain), "suspicious", "An officer walked past a dead colleague")

/**
 * The owner's "stun critted me then all the cops walked away": a two-star suspect is put out of stamina with an
 * arrest on them while the arresting officer is on the floor. Nobody uses force on them and their fall brings
 * nobody, but the squad does not stand down and the officer who was on them does not walk off. Up again before the
 * cuffs, that officer is on them at once. Of the arrest's two officers, the nearer one on its feet does the cuffing.
 * Only the cuffs are the all clear.
 */
/datum/unit_test/voidcrew_stealth_live/police/down_keeps_squad

/datum/unit_test/voidcrew_stealth_live/police/down_keeps_squad/Run()
	TEST_ASSERT(police_room(20, 9), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 8))
	person_at(19, 8)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/arresting = ready_officer(5, 4, EAST)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/cover = ready_officer(8, 5, WEST)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/watcher = ready_officer(10, 4, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/watcher_brain = watcher.ai_controller
	var/mob/living/carbon/human/suspect = visitor_at(6, 4)
	suspect.physiology.stamina_mod = 1
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 25) // two stars

	// One officer fights them on stealth's rules; the arrest is the nearest two's
	watcher_brain.stealth_go_alert(suspect)
	TEST_ASSERT_EQUAL(watcher_brain.stealth_state(), "alert", "Fixture: the third officer is not alert on a two-star suspect")
	police.stealth_tick_squad()
	TEST_ASSERT(police.stealth_trouble, "Fixture: a two-star suspect on their feet is not at large")
	var/datum/outpost_police_case/case = police.open_case(warrant)
	TEST_ASSERT_NOTNULL(case, "Fixture: no arrest opened at two stars")
	TEST_ASSERT_EQUAL(case.arresting(), arresting, "Fixture: the officer beside the suspect is not the arresting one")
	TEST_ASSERT_EQUAL(case.cover(), cover, "Fixture: the second officer is not the cover")
	TEST_ASSERT(isnull(watcher.case), "Fixture: the third officer was put on the arrest")

	// The arresting officer is kicked onto its side, and the disablers put the suspect out of stamina
	arresting.Paralyze(3 SECONDS) // SHOVE_CHAIN_PARALYZE
	suspect.adjustStaminaLoss(200)
	TEST_ASSERT(HAS_TRAIT(suspect, TRAIT_INCAPACITATED) && suspect.stat == CONSCIOUS, "Fixture: 200 stamina damage did not put the suspect in stamina crit")
	TEST_ASSERT(police.arrest_on(suspect) && !police.in_custody(suspect), "Fixture: the suspect is not under arrest with the cuffs still to come")
	watcher_brain.stealth_keep_target()
	police.stealth_tick_squad()
	police.stealth_tick_officer(watcher)

	// Nobody uses force on them, and the noise they make brings nobody (owner decisions 37 and 58)
	TEST_ASSERT(!watcher.police_will_fight(suspect), "An officer would fight a suspect who is down with an arrest on them")
	TEST_ASSERT_NULL(watcher_brain.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "An officer kept a suspect who is down as its target")
	TEST_ASSERT(!police_plans_shot(watcher, suspect), "An officer plans a shot at a suspect who is down with an arrest on them")
	TEST_ASSERT_EQUAL(stealth_noise(get_turf(suspect), "scream", null, suspect), 0, "An officer went to look at a scream from a suspect who is down with an arrest on them")
	TEST_ASSERT(watcher_brain.stealth_state() != "alert", "An officer is on alert over a suspect who is down")

	// But it is not over: no all clear, and the officer who was on them stays by them, closing in to stand over them
	TEST_ASSERT(police.stealth_trouble, "The squad stood down over a suspect who is down with no cuffs on")
	TEST_ASSERT(police.has_in_hand(suspect) && police.has_down(suspect) && !police.has_secured(suspect), "A suspect who is down with no cuffs on is not in hand and still to be cuffed")
	TEST_ASSERT_EQUAL(watcher_brain.police_covered(), suspect, "An officer who was on a suspect left them when they went down with no cuffs on")
	watcher_brain.SelectBehaviors(1)
	TEST_ASSERT_EQUAL(watcher_brain.police_covered(), suspect, "An officer standing over a downed suspect left them at its next thought")
	TEST_ASSERT(locate(/datum/ai_behavior/human_npc_close_in) in watcher_brain.planned_behaviors, "An officer four tiles from a downed suspect it is on did not close in to stand over them")
	TEST_ASSERT_EQUAL(watcher_brain.stealth_state(), "unaware", "An officer standing over a downed suspect is [watcher_brain.stealth_state()]")

	// Up again before the cuffs (their stamina comes back, as tg gives it back): it is on them at once
	suspect.setStaminaLoss(0)
	TEST_ASSERT(!HAS_TRAIT(suspect, TRAIT_INCAPACITATED), "Fixture: the suspect did not get their stamina back")
	watcher_brain.SelectBehaviors(1)
	TEST_ASSERT_EQUAL(watcher_brain.stealth_state(), "alert", "An officer who stood over a downed suspect is [watcher_brain.stealth_state()] when they get up before the cuffs")
	TEST_ASSERT_EQUAL(watcher_brain.blackboard[BB_BASIC_MOB_CURRENT_TARGET], suspect, "An officer who stood over a downed suspect is not on them when they get up before the cuffs")

	// Down again: at its next thought, before any scan, it is standing over them with its weapon still out
	var/force_before = watcher.force
	TEST_ASSERT(force_before >= 2, "Fixture: the officer fighting a two-star suspect is not at stun force ([force_before])") // POLICE_FORCE_STUN
	suspect.adjustStaminaLoss(200)
	TEST_ASSERT(HAS_TRAIT(suspect, TRAIT_INCAPACITATED), "Fixture: the suspect did not go down again")
	watcher_brain.SelectBehaviors(1)
	TEST_ASSERT_EQUAL(watcher_brain.police_covered(), suspect, "An officer fighting a suspect left them when they went down again")
	TEST_ASSERT_NULL(watcher_brain.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "An officer kept a suspect who went down again as its target")
	TEST_ASSERT_EQUAL(watcher.force, force_before, "An officer standing over a downed suspect put its weapon away")
	// The arrest: the cover officer on its feet takes it from the one on the floor
	case.process_case()
	TEST_ASSERT(!QDELETED(case), "The arrest ended with the suspect down")
	TEST_ASSERT_EQUAL(case.arresting(), cover, "The cover officer did not take the arrest from an arresting officer on the floor")
	// Back on its feet beside the suspect, with the other further off: the nearer one does the cuffing
	arresting.SetParalyzed(0)
	TEST_ASSERT(!HAS_TRAIT(arresting, TRAIT_INCAPACITATED), "Fixture: the first officer is still on the floor")
	TEST_ASSERT(get_dist(arresting, suspect) < get_dist(cover, suspect), "Fixture: the first officer is not the nearer one")
	case.process_case()
	TEST_ASSERT(!QDELETED(case), "The arrest ended with the suspect down")
	TEST_ASSERT_EQUAL(case.arresting(), arresting, "An officer on its feet beside a downed suspect left the cuffing to one further off")
	police.stealth_tick_squad()
	TEST_ASSERT(police.stealth_trouble, "The squad stood down over a suspect who is down with no cuffs on")

	// The cuffs go on: now it is over, and everyone stands down calm
	case.cuffs_on(suspect)
	TEST_ASSERT(police.in_custody(suspect), "Fixture: the cuffed suspect is not in custody")
	police.stealth_tick_squad()
	TEST_ASSERT(!police.stealth_trouble, "The squad did not stand down once the cuffs were on")
	TEST_ASSERT_EQUAL(watcher_brain.stealth_state(), "unaware", "An officer is [watcher_brain.stealth_state()] once the cuffs are on")
	TEST_ASSERT(!watcher_brain.blackboard["stealth_wary"], "An officer was left on edge once the cuffs were on")
	TEST_ASSERT_NULL(watcher_brain.police_covered(), "An officer still stands over a suspect in cuffs")
	TEST_ASSERT(police.has_secured(suspect) && !police.has_down(suspect), "A suspect in cuffs is not held")
	police.close_case(suspect.mind)

/// An officer who was not on a downed suspect but sees them lying there with an arrest on them stays by them too, and one searching for them out of sight stops searching
/datum/unit_test/voidcrew_stealth_live/police/down_seen_is_covered

/datum/unit_test/voidcrew_stealth_live/police/down_seen_is_covered/Run()
	TEST_ASSERT(police_room(20, 9), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 8))
	person_at(19, 8)
	ready_officer(5, 4, EAST)
	ready_officer(6, 5, NORTH)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/passer = ready_officer(10, 4, WEST)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/searcher = ready_officer(16, 4, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/passer_brain = passer.ai_controller
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/searcher_brain = searcher.ai_controller
	var/mob/living/carbon/human/suspect = visitor_at(6, 4)
	suspect.physiology.stamina_mod = 1
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 25) // two stars
	var/datum/outpost_police_case/case = police.open_case(warrant)
	TEST_ASSERT_NOTNULL(case, "Fixture: no arrest opened at two stars")
	TEST_ASSERT(isnull(passer.case) && isnull(searcher.case), "Fixture: the far officers were put on the arrest")
	for(var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/each as anything in list(passer_brain, searcher_brain))
		each.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
		each.stealth_go_unaware()
		each.stealth_drop_call()
	// One has its back to them and is looking for them where they were last seen
	searcher_brain.police_hunt = WEAKREF(suspect.mind)
	searcher_brain.stealth_go_searching(at(18, 4))
	suspect.adjustStaminaLoss(200)
	TEST_ASSERT(police.has_down(suspect), "Fixture: the suspect is not down with the cuffs still to come")
	TEST_ASSERT(police.perception.sees(passer, suspect), "Fixture: the passing officer does not see the downed suspect")
	TEST_ASSERT(!police.perception.sees(searcher, suspect), "Fixture: the searching officer sees the downed suspect")
	police.stealth_tick_officer(passer)
	police.stealth_tick_officer(searcher)
	TEST_ASSERT_EQUAL(passer_brain.police_covered(), suspect, "An officer who sees a suspect down with no cuffs on walked past them")
	TEST_ASSERT_EQUAL(passer_brain.stealth_state(), "unaware", "An officer went [passer_brain.stealth_state()] over a suspect who is down")
	passer_brain.SelectBehaviors(1)
	TEST_ASSERT_EQUAL(passer_brain.police_covered(), suspect, "An officer standing over a downed suspect left them at its next thought")
	TEST_ASSERT(passer_brain.blackboard["stealth_wary"], "An officer standing over a downed suspect with no cuffs on is not on edge")
	TEST_ASSERT(locate(/datum/ai_behavior/human_npc_close_in) in passer_brain.planned_behaviors, "An officer four tiles from a downed suspect did not close in to stand over them")
	TEST_ASSERT_EQUAL(searcher_brain.stealth_state(), "unaware", "An officer went on searching for a suspect who is down with an arrest on them")
	TEST_ASSERT_NULL(searcher_brain.police_covered(), "An officer who cannot see a downed suspect stands over them")
	police.close_case(suspect.mind)

/// An officer shoved over by someone in cuffs gets up without a search: the charge is the arrest's, and nobody looks for someone they are holding (owner decision 58)
/datum/unit_test/voidcrew_stealth_live/police/shoved_from_the_cuffs

/datum/unit_test/voidcrew_stealth_live/police/shoved_from_the_cuffs/Run()
	TEST_ASSERT(police_room(16, 7), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 6))
	person_at(15, 6)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/arresting = ready_officer(5, 3, EAST)
	ready_officer(6, 4, SOUTH)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/guard = ready_officer(7, 3, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = guard.ai_controller
	var/mob/living/carbon/human/prisoner = visitor_at(6, 3)
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, prisoner.mind, 25) // two stars
	var/datum/outpost_police_case/case = police.open_case(warrant)
	TEST_ASSERT_NOTNULL(case, "Fixture: no arrest opened at two stars")
	TEST_ASSERT_EQUAL(case.arresting(), arresting, "Fixture: the officer west of the suspect is not the arresting one")
	TEST_ASSERT(isnull(guard.case), "Fixture: the third officer was put on the arrest")
	case.cuffs_on(prisoner)
	police.stealth_tick_squad()
	TEST_ASSERT(police.in_custody(prisoner), "Fixture: the cuffed suspect is not in custody")
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	brain.stealth_go_unaware()
	brain.stealth_clear_wary()
	brain.stealth_drop_call()

	// The prisoner shoves it over; it gets up
	TEST_ASSERT(!brain.stealth_touched(prisoner), "An officer took someone in cuffs for a target at a shove from them")
	guard.Knockdown(2 SECONDS) // SHOVE_KNOCKDOWN_SOLID
	TEST_ASSERT(guard.IsKnockdown(), "Fixture: the officer was not knocked down")
	guard.SetKnockdown(0)
	TEST_ASSERT(!guard.IsKnockdown(), "Fixture: the officer is still down")
	TEST_ASSERT_EQUAL(brain.stealth_state(), "unaware", "An officer shoved over by someone in cuffs got up [brain.stealth_state()]")
	TEST_ASSERT_NULL(brain.pending_call, "An officer shoved over by someone in cuffs called an alarm")

	// Someone else lays a hand on it after the prisoner did: that is not the prisoner's doing, and it looks round when it gets up
	var/mob/living/carbon/human/stranger = visitor_at(8, 3)
	brain.stealth_touched(prisoner)
	brain.stealth_touched(stranger)
	guard.Knockdown(2 SECONDS) // SHOVE_KNOCKDOWN_SOLID
	guard.SetKnockdown(0)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "searching", "An officer put on the floor after a stranger's hand on it took it for the prisoner's doing")
	police.close_case(prisoner.mind)
