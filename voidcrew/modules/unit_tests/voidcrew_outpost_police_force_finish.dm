/**
 * Outpost police tests: an officer whose gun is dry finishing someone down where the zone finishes the downed, and
 * nobody firing on a three-star suspect the arrest is cuffing (police_force.dm police_finish_with_baton(),
 * police_holds_fire()).
 *
 * The room and police of voidcrew_stealth_live/police (voidcrew_outpost_police_stealth.dm). Nothing sleeps: the force
 * subtree and the blow are run by hand. Fork defines are included after the tests, so values are written out: heat 55
 * is three stars and 150 five (OUTPOST_POLICE_STAR_HEAT); force 3 is POLICE_FORCE_LETHAL; the role "lethal"
 * (POLICE_ROLE_LETHAL); the arrest step "cuff"; OUTPOST_POLICE_YIELD_TIME is 2 s.
 */

/**
 * Soak kill_then_hide and five_star_heavy, Quartermain (jobs 1124234412b3d, 1124234412ad0, 112421235786d): a
 * three-star suspect, down, is being cuffed; tg's stamina lets them up again under the arresting officer's hands, and an
 * officer off the arrest at lethal force fired on them. While the cuffs are going on and they give up, nobody fires;
 * once they pull away or fight, they are fair game again.
 */
/datum/unit_test/voidcrew_stealth_live/police/cuffing_three_stars_no_fire

/datum/unit_test/voidcrew_stealth_live/police/cuffing_three_stars_no_fire/Run()
	TEST_ASSERT(police_room(20, 9), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 8))
	person_at(19, 8)
	ready_officer(5, 4, EAST)
	ready_officer(6, 6, NORTH)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/watcher = ready_officer(10, 4, WEST)
	watcher.police_role = "lethal" // POLICE_ROLE_LETHAL
	var/mob/living/carbon/human/suspect = visitor_at(6, 4)
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 55) // three stars
	TEST_ASSERT(police_plans_shot(watcher, suspect), "Fixture: a lethal officer plans no shot at a three-star suspect on their feet")

	// Put down, and the arrest goes for the cuffs
	suspect.Paralyze(5 SECONDS)
	TEST_ASSERT(police_suspect_down(suspect), "Fixture: a paralysed suspect is not down")
	var/datum/outpost_police_case/case = police.open_case(warrant, TRUE)
	TEST_ASSERT_NOTNULL(case, "Fixture: no arrest opened on a downed three-star suspect")
	case.set_step("cuff")
	TEST_ASSERT(police.arrest_cuffing(suspect), "Fixture: the arrest is not cuffing the suspect")

	// Up again under the cuffs, staying put
	suspect.SetParalyzed(0)
	TEST_ASSERT(!police_suspect_down(suspect), "Fixture: the suspect is still down")
	police.gives_up(suspect)
	TEST_ASSERT(police.gives_up(suspect), "Fixture: a suspect staying put under the cuffs is not giving up")
	TEST_ASSERT(watcher.police_will_fight(suspect), "An officer off the arrest lost a three-star suspect not yet in cuffs as someone to watch")
	TEST_ASSERT(!police_plans_shot(watcher, suspect), "A lethal officer off the arrest plans a shot at a three-star suspect being cuffed who gives up")

	// A shot planned a moment before is not taken
	watcher.sync_force(3) // POLICE_FORCE_LETHAL
	var/obj/item/gun/energy/sidearm = watcher.get_sidearm()
	TEST_ASSERT_NOTNULL(sidearm, "Fixture: the officer has no sidearm")
	TEST_ASSERT_EQUAL(watcher.police_loaded_gun_for(3), sidearm, "Fixture: the officer's gun is not in its hand and set to kill")
	var/charge = sidearm.cell.charge
	var/datum/ai_controller/watcher_brain = watcher.ai_controller
	watcher_brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, suspect)
	watcher_brain.set_blackboard_key("human_npc_next_shot", 0) // BB_HUMAN_NPC_NEXT_SHOT
	var/datum/ai_behavior/human_npc_shoot/outpost_police/shot = GET_AI_BEHAVIOR(/datum/ai_behavior/human_npc_shoot/outpost_police)
	shot.perform(1, watcher_brain, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	TEST_ASSERT_EQUAL(sidearm.cell.charge, charge, "A lethal officer off the arrest fired on a three-star suspect being cuffed who gives up")
	watcher_brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)

	// A step of their own away from the cuffs: fair game
	var/datum/outpost_police_stance/stance = police.stance_of(suspect)
	suspect.Move(at(6, 3), SOUTH)
	TEST_ASSERT_EQUAL(get_turf(suspect), at(6, 3), "Fixture: the suspect did not take a step")
	TEST_ASSERT(police.arrest_pulled_away(suspect), "Fixture: a step of the suspect's own did not count as pulling away from the cuffs")
	TEST_ASSERT(police_plans_shot(watcher, suspect), "A lethal officer plans no shot at a three-star suspect stepping away from the cuffs")

	// Still again, then a blow on an officer: fair game
	stance.moved_at -= 2 SECONDS // OUTPOST_POLICE_YIELD_TIME
	case.suspect_moved = FALSE
	TEST_ASSERT(!police_plans_shot(watcher, suspect), "A lethal officer plans a shot at a three-star suspect who stood still again under the cuffs")
	police.note_fought(suspect)
	TEST_ASSERT(police_plans_shot(watcher, suspect), "A lethal officer plans no shot at a three-star suspect who hit out under the cuffs")
	police.close_case(suspect.mind)
	police_pin_warrant(police, suspect.mind, 0)
