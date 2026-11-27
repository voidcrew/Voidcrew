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

/// Whether `officer`'s force subtree plans the baton's harm blow on `target`
/datum/unit_test/voidcrew_stealth_live/police/proc/police_plans_finish(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, atom/target)
	var/datum/ai_controller/brain = officer.ai_controller
	var/datum/ai_planning_subtree/outpost_police_force/force_tree = locate() in brain?.planning_subtrees
	if(!force_tree)
		TEST_FAIL("[officer.type]'s brain has no force subtree")
		return FALSE
	brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, target)
	brain.planned_behaviors.Cut()
	force_tree.SelectBehaviors(brain, 1)
	. = !!(locate(/datum/ai_behavior/basic_melee_attack/human_npc/outpost_police_finish) in brain.planned_behaviors)
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	brain.planned_behaviors.Cut()

/**
 * Soak jailbreak_shootout, the Undertow (jobs 1125002653ec3, 1124212358d09): O3's mini energy gun ran dry with the
 * suspect in crit at -90. At lethal force with no shot left it drew its stun baton, and the base's melee switched it on
 * and struck: stamina on someone already on the floor, every few seconds, for half a minute. Where the zone finishes the
 * downed, the officer swings the baton as tg's harm blow (a right click): the baton's brute, through tg's own attack.
 */
/datum/unit_test/voidcrew_stealth_live/police/dry_gun_finishes_downed

/datum/unit_test/voidcrew_stealth_live/police/dry_gun_finishes_downed/Run()
	TEST_ASSERT(police_room(6, 3), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 2))
	police.profile = new /datum/outpost_police_profile/undertow
	TEST_ASSERT(!police.profile.spares_downed, "Setup: the red zone's profile spares the downed")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = ready_officer(1, 1, EAST)
	police_arrest_kit(officer)
	officer.police_role = "lethal" // POLICE_ROLE_LETHAL
	var/mob/living/carbon/human/suspect = visitor_at(2, 1)
	// The room's people take no damage (person_at()); this one has to, from the blow and from staying down
	suspect.physiology.brute_mod = 1
	suspect.physiology.burn_mod = 1
	suspect.physiology.stamina_mod = 1
	police_pin_warrant(police, suspect.mind, 150) // five stars
	var/obj/item/melee/baton/security/baton = officer.get_baton()
	TEST_ASSERT(istype(baton), "Setup: the officer has no security baton")
	var/obj/item/gun/energy/sidearm = officer.get_sidearm()
	TEST_ASSERT_NOTNULL(sidearm, "Setup: the officer has no sidearm")
	sidearm.cell.use(sidearm.cell.charge)
	sidearm.update_appearance()
	TEST_ASSERT(!sidearm.can_shoot(), "Fixture: the emptied sidearm can still shoot")

	// On their feet: no harm blow, whatever the gun
	officer.sync_force(3) // POLICE_FORCE_LETHAL
	TEST_ASSERT(!officer.police_finish_with_baton(suspect), "A dry officer would take the baton's harm blow to a five-star suspect on their feet")

	// In crit, in front of it
	suspect.adjustToxLoss(suspect.maxHealth - suspect.crit_threshold + 10)
	TEST_ASSERT(suspect.stat >= SOFT_CRIT && suspect.stat != DEAD, "Fixture: the suspect is not in crit (health [suspect.health])")
	TEST_ASSERT(police.finishes_downed(suspect, officer), "Fixture: the red zone does not finish a downed five-star suspect")
	TEST_ASSERT(officer.police_will_fight(suspect), "Fixture: a red zone officer would not fight a downed five-star suspect")
	officer.sync_force(3) // POLICE_FORCE_LETHAL
	TEST_ASSERT(officer.is_holding(baton), "With its gun dry at lethal force the officer did not take its baton in hand")
	TEST_ASSERT(police_plans_finish(officer, suspect), "A red zone officer with a dry gun plans no harm blow on a downed five-star suspect beside it")

	// The blow itself: tg's harm baton, brute and no stun. An Undertow officer is built to target down to hard crit
	// (HUMAN_NPC_FINISHES_DOWNED); this one was built before the room's profile was set
	var/datum/ai_controller/brain = officer.ai_controller
	brain.set_blackboard_key(BB_TARGET_MINIMUM_STAT, HARD_CRIT)
	brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, suspect)
	brain.set_blackboard_key(BB_BASIC_MOB_MELEE_COOLDOWN_TIMER, world.time - 1)
	officer.next_move = 0
	var/brute = suspect.getBruteLoss()
	var/stamina = suspect.getStaminaLoss()
	// What it did before: the base's melee switches the baton on and stuns. Stamina on the floor, no harm
	var/datum/ai_behavior/basic_melee_attack/human_npc/stun_blow = GET_AI_BEHAVIOR(/datum/ai_behavior/basic_melee_attack/human_npc)
	stun_blow.perform(1, brain, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	TEST_ASSERT(suspect.getStaminaLoss() > stamina, "Fixture: the base's blow with the stun baton did no stamina (stamina [stamina] -> [suspect.getStaminaLoss()])")
	TEST_ASSERT_EQUAL(suspect.getBruteLoss(), brute, "Fixture: the base's blow with the stun baton did brute")
	// The next blow, as if a moment later (tg takes one click a tick)
	brain.set_blackboard_key(BB_BASIC_MOB_MELEE_COOLDOWN_TIMER, world.time - 1)
	officer.next_move = 0
	officer.next_click = 0
	stamina = suspect.getStaminaLoss()
	var/datum/ai_behavior/basic_melee_attack/human_npc/outpost_police_finish/blow = GET_AI_BEHAVIOR(/datum/ai_behavior/basic_melee_attack/human_npc/outpost_police_finish)
	blow.perform(1, brain, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	TEST_ASSERT(suspect.getBruteLoss() > brute, "The officer's blow with the baton did no brute to the downed suspect (brute [brute] -> [suspect.getBruteLoss()])")
	TEST_ASSERT_EQUAL(suspect.getStaminaLoss(), stamina, "The officer's harm blow with the baton was a stun blow (stamina [stamina] -> [suspect.getStaminaLoss()])")
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)

	// Where the zone spares the downed: nobody fights them at all, the arrest cuffs them
	police.profile = new /datum/outpost_police_profile/quartermain
	TEST_ASSERT(!officer.police_finish_with_baton(suspect), "An officer where the zone spares the downed would take the baton's harm blow to a downed suspect")
	TEST_ASSERT(!officer.police_will_fight(suspect), "An officer where the zone spares the downed would fight a downed suspect")
	police_pin_warrant(police, suspect.mind, 0)

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
	case.enter_cuff(suspect)
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
