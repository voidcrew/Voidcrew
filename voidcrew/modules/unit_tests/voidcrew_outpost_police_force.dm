/**
 * Outpost police tests: who uses force on whom, and when (voidcrew/modules/outpost_police/police_force.dm and the
 * notice stages of voidcrew/modules/stealth_police/police_stealth.dm).
 *
 * The room and police of voidcrew_stealth_live/police (voidcrew_outpost_police_stealth.dm), on the real stealth rules.
 * Nothing sleeps: the scan, the case and the force subtree are stepped by hand, and what puts someone on the floor is
 * tg's own knockdown. Fork defines are included after the tests, so values are written out: states "unaware",
 * "suspicious", "alert"; arrest steps "respond", "order", "subdue", "cuff"; the crime "resist"; the line kind
 * "stealth_suspicious"; heat 25 is two stars and 55 three (OUTPOST_POLICE_STAR_HEAT); OUTPOST_POLICE_YIELD_TIME and
 * OUTPOST_POLICE_STANCE_STALE are 2 s, OUTPOST_POLICE_COVER_RANGE 3 tiles.
 */

/// A two-star suspect at (6, 4) with the arrest's two officers beside them and a third officer, alert on them and not on the arrest, four tiles off. Returns list(suspect, case, arresting, cover, watcher).
/datum/unit_test/voidcrew_stealth_live/police/proc/force_scene()
	if(!police_room(20, 9))
		TEST_FAIL("No room for the test")
		return null
	allocate(/obj/effect/landmark/stealth_group, at(0, 8))
	person_at(19, 8)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/arresting = ready_officer(5, 4, EAST)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/cover = ready_officer(6, 6, NORTH)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/watcher = ready_officer(10, 4, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/watcher_brain = watcher.ai_controller
	var/mob/living/carbon/human/suspect = visitor_at(6, 4)
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 25) // two stars
	watcher_brain.stealth_go_alert(suspect)
	var/datum/outpost_police_case/case = police.open_case(warrant)
	if(!case || case.arresting() != arresting || case.cover() != cover || watcher.case)
		TEST_FAIL("Fixture: the arrest is not the two officers beside the suspect (arresting [case?.arresting()], cover [case?.cover()], third officer's case [watcher.case])")
		return null
	if(watcher_brain.stealth_state() != "alert" || !watcher.police_will_fight(suspect))
		TEST_FAIL("Fixture: the third officer is not alert on the two-star suspect")
		return null
	return list(suspect, case, arresting, cover, watcher)

/**
 * The soak's force_on_the_held: a two-star suspect who stands still is not fired on by an officer off the arrest,
 * before the order, in the time to comply, or once they have done as told and the cuffs are coming. A shot it had
 * already planned is not taken either.
 */
/datum/unit_test/voidcrew_stealth_live/police/gave_up_no_fire

/datum/unit_test/voidcrew_stealth_live/police/gave_up_no_fire/Run()
	var/list/scene = force_scene()
	if(!scene)
		return
	var/mob/living/carbon/human/suspect = scene[1]
	var/datum/outpost_police_case/case = scene[2]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/watcher = scene[5]
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/watcher_brain = watcher.ai_controller

	// Nobody has spoken to them yet, and they are standing there
	TEST_ASSERT_EQUAL(case.step, "respond", "Fixture: the arrest did not start at respond")
	TEST_ASSERT(!police_plans_shot(watcher, suspect), "An officer off the arrest plans a shot at a two-star suspect who stands still, before anyone has given them an order")

	// The order, and the time to comply
	case.set_step("order")
	case.step_order()
	TEST_ASSERT(police.order_pending(suspect), "Fixture: the suspect was not given the order")
	TEST_ASSERT(!police_plans_shot(watcher, suspect), "An officer off the arrest plans a shot at a suspect in the time to comply")

	// They did as told: the cuffs are coming
	case.order_at = world.time - 10 SECONDS
	case.step_order()
	TEST_ASSERT_EQUAL(case.step, "cuff", "Fixture: a suspect who stood still with empty hands was not taken as having complied")
	TEST_ASSERT(watcher.police_will_fight(suspect), "An officer off the arrest lost a suspect who is not yet in cuffs as someone to watch")
	TEST_ASSERT(!police_plans_shot(watcher, suspect), "An officer off the arrest plans a shot at a suspect who gave up and is about to be cuffed")
	TEST_ASSERT_EQUAL(watcher_brain.stealth_state(), "alert", "An officer off the arrest is [watcher_brain.stealth_state()] with the cuffs still to come")

	// A shot planned a moment before is not taken
	watcher.sync_force(2) // POLICE_FORCE_STUN
	var/obj/item/gun/energy/sidearm = watcher.get_sidearm()
	TEST_ASSERT_NOTNULL(sidearm, "Fixture: the officer has no sidearm")
	TEST_ASSERT_EQUAL(watcher.police_loaded_gun_for(2), sidearm, "Fixture: the officer's disabler is not in its hand and ready")
	var/charge = sidearm.cell.charge
	watcher_brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, suspect)
	watcher_brain.set_blackboard_key("human_npc_next_shot", 0) // BB_HUMAN_NPC_NEXT_SHOT
	var/datum/ai_behavior/human_npc_shoot/outpost_police/shot = GET_AI_BEHAVIOR(/datum/ai_behavior/human_npc_shoot/outpost_police)
	shot.perform(1, watcher_brain, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	TEST_ASSERT_EQUAL(sidearm.cell.charge, charge, "An officer off the arrest fired on a suspect who gave up and is about to be cuffed")
	police.close_case(suspect.mind)

/**
 * The owner's playtest, 18:55:07 to 18:55:10: a two-star suspect knocked down by the baton, awake and not stunned,
 * with the arresting officer going for the cuffs. The officers off the arrest hold their fire, and so does the
 * arrest's cover.
 */
/datum/unit_test/voidcrew_stealth_live/police/floored_no_fire

/datum/unit_test/voidcrew_stealth_live/police/floored_no_fire/Run()
	var/list/scene = force_scene()
	if(!scene)
		return
	var/mob/living/carbon/human/suspect = scene[1]
	var/datum/outpost_police_case/case = scene[2]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/cover = scene[4]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/watcher = scene[5]

	// They would not do as told: the baton. tg's stun baton floors them two seconds after the blow.
	case.set_step("subdue")
	suspect.Knockdown(5 SECONDS) // /obj/item/melee/baton/security knockdown_time
	TEST_ASSERT(suspect.body_position == LYING_DOWN && !police_suspect_down(suspect), "Fixture: a knockdown did not leave the suspect awake on the floor")
	case.step_subdue()
	TEST_ASSERT_EQUAL(case.step, "cuff", "Fixture: the arrest did not go for the cuffs with the suspect on the floor")
	TEST_ASSERT(!police.has_in_hand(suspect), "Fixture: a suspect who is only knocked down counts as in hand")
	TEST_ASSERT(!police_plans_shot(watcher, suspect), "An officer off the arrest plans a shot at a two-star suspect who is knocked down with the arresting officer going for the cuffs")

	// Pushed a tile by someone else, they have not moved. A crawl of their own, of one tile, is pulling away from the
	// cuffs (tg's cuffing breaks on it): fair game again, until they have lain still a while
	var/datum/outpost_police_stance/stance = police.stance_of(suspect)
	suspect.forceMove(at(7, 4))
	TEST_ASSERT(!police.arrest_pulled_away(suspect), "Fixture: a push counted as the suspect's own step")
	TEST_ASSERT(!police_plans_shot(watcher, suspect), "An officer off the arrest plans a shot at a suspect who was pushed a tile with the cuffs coming")
	suspect.Move(at(7, 5), NORTH)
	TEST_ASSERT_EQUAL(get_turf(suspect), at(7, 5), "Fixture: the suspect did not crawl a tile")
	TEST_ASSERT(police.arrest_pulled_away(suspect), "Fixture: a crawl of the suspect's own did not count as pulling away from the cuffs")
	TEST_ASSERT_EQUAL(case.step, "cuff", "Fixture: the arrest left the cuffs")
	TEST_ASSERT(police_plans_shot(watcher, suspect), "An officer off the arrest plans no shot at a two-star suspect crawling off from the cuffs")
	stance.moved_at -= 2 SECONDS // OUTPOST_POLICE_YIELD_TIME
	TEST_ASSERT(!police_plans_shot(watcher, suspect), "An officer off the arrest plans a shot at a suspect who has lain still again")
	suspect.Move(at(8, 5), EAST)
	TEST_ASSERT(police_plans_shot(watcher, suspect), "An officer off the arrest plans no shot at a suspect who crawls another tile from the cuffs")
	stance.moved_at -= 2 SECONDS // OUTPOST_POLICE_YIELD_TIME
	// So is a kick at the arresting officer from the floor (a blow on an officer is the crime "resist")
	police.report_crime(suspect, "resist", scene[3]) // OUTPOST_CRIME_RESIST
	TEST_ASSERT_EQUAL(stance.fought_at, world.time, "A blow on an officer was not marked against the suspect who gave it")
	TEST_ASSERT(police_plans_shot(watcher, suspect), "An officer off the arrest plans no shot at a two-star suspect who kicked the arresting officer from the floor")
	stance.fought_at -= 2 SECONDS // OUTPOST_POLICE_YIELD_TIME
	TEST_ASSERT(!police_plans_shot(watcher, suspect), "An officer off the arrest still plans a shot at a suspect who has lain still since the kick")
	police.close_case(suspect.mind)
	// Back where they were, and a while later
	suspect.forceMove(at(6, 4))
	police.gives_up(suspect)
	stance.moved_at = 0

	// The arrest's cover fires while they are to be subdued, but not at someone who is staying where they are
	var/datum/outpost_police_case/second = police.open_case(police.get_warrant(suspect.mind))
	TEST_ASSERT_NOTNULL(second, "Fixture: no second arrest opened")
	suspect.SetKnockdown(0)
	suspect.get_up(TRUE)
	TEST_ASSERT_EQUAL(suspect.body_position, STANDING_UP, "Fixture: the suspect did not get back up")
	second.set_step("subdue")
	TEST_ASSERT_EQUAL(second.cover(), cover, "Fixture: the second officer is not the cover")
	TEST_ASSERT(!police_plans_shot(cover, suspect), "The arrest's cover plans a shot at a two-star suspect who stands still while the arresting officer subdues them")
	// Off and running, the cover fires
	suspect.forceMove(at(9, 6))
	TEST_ASSERT(police_plans_shot(cover, suspect), "The arrest's cover plans no shot at a two-star suspect who makes off while they are being subdued")
	police.close_case(suspect.mind)

/// A two-star person who has given up and stands in an officer's line of fire at someone else is not shot through
/datum/unit_test/voidcrew_stealth_live/police/gave_up_in_the_line

/datum/unit_test/voidcrew_stealth_live/police/gave_up_in_the_line/Run()
	var/list/scene = force_scene()
	if(!scene)
		return
	var/mob/living/carbon/human/suspect = scene[1]
	var/datum/outpost_police_case/case = scene[2]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/watcher = scene[5]
	case.set_step("order")
	case.step_order()
	case.order_at = world.time - 10 SECONDS
	case.step_order()
	TEST_ASSERT_EQUAL(case.step, "cuff", "Fixture: the suspect was not taken as having complied")
	// Someone else, also two stars, further along the same line
	var/mob/living/carbon/human/other = visitor_at(3, 4)
	police_pin_warrant(police, other.mind, 25) // two stars
	watcher.set_force(2) // POLICE_FORCE_STUN
	TEST_ASSERT_EQUAL(watcher.bystander_in_line(other), suspect, "An officer would fire through someone who gave up and is about to be cuffed")
	police.close_case(suspect.mind)

/// Three stars: nobody holds fire for someone standing still (owner decision 37: only someone down is taken alive)
/datum/unit_test/voidcrew_stealth_live/police/three_stars_no_hold

/datum/unit_test/voidcrew_stealth_live/police/three_stars_no_hold/Run()
	TEST_ASSERT(police_room(20, 9), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 8))
	person_at(19, 8)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/lethal = ready_officer(10, 4, WEST)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/stunner = ready_officer(10, 5, WEST)
	lethal.police_role = "lethal" // POLICE_ROLE_LETHAL
	stunner.police_role = "stun" // POLICE_ROLE_STUN
	var/mob/living/carbon/human/suspect = visitor_at(6, 4)
	police_pin_warrant(police, suspect.mind, 55) // three stars
	TEST_ASSERT(police_plans_shot(lethal, suspect), "A lethal officer holds fire for a three-star suspect who stands still")
	TEST_ASSERT(police_plans_shot(stunner, suspect), "A stun officer holds fire for a three-star suspect who stands still")

/// The states an officer goes through over `scans` looks, from where it stands
/datum/unit_test/voidcrew_stealth_live/police/proc/notice_stages(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, scans = 12)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	. = list()
	for(var/i in 1 to scans)
		brain.stealth_scan_once()
		. += brain.stealth_state()
		if(brain.stealth_state() == "alert")
			return

/// An officer on its beat and someone with two stars five tiles in front of it
/datum/unit_test/voidcrew_stealth_live/police/proc/notice_scene()
	if(!police_room(20, 9))
		TEST_FAIL("No room for the test")
		return null
	allocate(/obj/effect/landmark/stealth_group, at(0, 8))
	person_at(19, 8)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = ready_officer(4, 4, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	var/mob/living/carbon/human/suspect = visitor_at(9, 4)
	police_pin_warrant(police, suspect.mind, 25) // two stars
	if(brain.stealth_state() != "unaware" || !officer.police_will_fight(suspect))
		TEST_FAIL("Fixture: the officer is not unaware with a two-star suspect to notice")
		return null
	return list(officer, suspect)

/**
 * The owner's playtest, 18:55:31: "Just a moment. What's that?" to someone an arrest was open on. An officer who
 * sees someone the police have an arrest open on is on them at once: no second look, and no line for one.
 */
/datum/unit_test/voidcrew_stealth_live/police/wanted_seen_at_once

/datum/unit_test/voidcrew_stealth_live/police/wanted_seen_at_once/Run()
	var/list/scene = notice_scene()
	if(!scene)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = scene[1]
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	var/mob/living/carbon/human/suspect = scene[2]
	// An arrest open on them, with its officers still on their way
	var/datum/outpost_police_case/case = new(police, police.get_warrant(suspect.mind))
	police.cases[suspect.mind] = case
	TEST_ASSERT(police.arrest_on(suspect) && isnull(officer.case), "Fixture: no arrest open on the suspect with the officer off it")
	var/list/stages = notice_stages(officer)
	TEST_ASSERT(!("suspicious" in stages), "An officer took a second look at someone an arrest is open on ([stages.Join(", ")])")
	TEST_ASSERT_EQUAL(brain.stealth_state(), "alert", "An officer who sees someone an arrest is open on is [brain.stealth_state()] ([stages.Join(", ")])")
	TEST_ASSERT_EQUAL(brain.blackboard[BB_BASIC_MOB_CURRENT_TARGET], suspect, "An officer who sees someone an arrest is open on is not on them")
	TEST_ASSERT(!brain.bark_ready_at["stealth_suspicious"], "An officer said its \"what's that\" line to someone an arrest is open on")
	police.close_case(suspect.mind)

/// The same for someone the police have sent units after
/datum/unit_test/voidcrew_stealth_live/police/sought_seen_at_once

/datum/unit_test/voidcrew_stealth_live/police/sought_seen_at_once/Run()
	var/list/scene = notice_scene()
	if(!scene)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = scene[1]
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	var/mob/living/carbon/human/suspect = scene[2]
	// A unit sent after them, far off with its back turned
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/unit = ready_officer(1, 1, WEST)
	unit.dispatch_mind = WEAKREF(suspect.mind)
	TEST_ASSERT(!police.arrest_on(suspect) && isnull(officer.dispatch_mind), "Fixture: an arrest is open, or the officer itself was sent")
	var/list/stages = notice_stages(officer)
	TEST_ASSERT(!("suspicious" in stages), "An officer took a second look at someone units were sent after ([stages.Join(", ")])")
	TEST_ASSERT_EQUAL(brain.stealth_state(), "alert", "An officer who sees someone units were sent after is [brain.stealth_state()] ([stages.Join(", ")])")
	TEST_ASSERT(!brain.bark_ready_at["stealth_suspicious"], "An officer said its \"what's that\" line to someone units were sent after")

/// Someone with stars the police are not yet after is noticed as before: a second look first
/datum/unit_test/voidcrew_stealth_live/police/wanted_unsought_second_look

/datum/unit_test/voidcrew_stealth_live/police/wanted_unsought_second_look/Run()
	var/list/scene = notice_scene()
	if(!scene)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = scene[1]
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	var/mob/living/carbon/human/suspect = scene[2]
	TEST_ASSERT(!police.arrest_on(suspect), "Fixture: an arrest is open on the suspect")
	var/list/stages = notice_stages(officer)
	TEST_ASSERT("suspicious" in stages, "An officer went straight at someone the police are not yet after ([stages.Join(", ")])")
	TEST_ASSERT_EQUAL(brain.stealth_state(), "alert", "An officer never went alert on a two-star suspect in front of it ([stages.Join(", ")])")

/**
 * What giving up is, to the officers: staying where they are with empty hands and going for nobody, for two seconds.
 * A step to the next tile is not walking off; further is. A weapon in hand, or a blow, is not giving up. The moment
 * the cuffs come out, what they did before is past. Nobody having looked at them for a while, they are seen afresh.
 */
/datum/unit_test/voidcrew_stealth_live/police/giving_up

/datum/unit_test/voidcrew_stealth_live/police/giving_up/Run()
	var/list/scene = force_scene()
	if(!scene)
		return
	var/mob/living/carbon/human/suspect = scene[1]
	var/datum/outpost_police_case/case = scene[2]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/watcher = scene[5]
	TEST_ASSERT(police.gives_up(suspect), "Someone first seen standing there is not taken as giving up")
	TEST_ASSERT(watcher.police_holds_fire(suspect), "An officer does not hold its fire for a two-star suspect who is giving up")
	var/datum/outpost_police_stance/stance = police.stance_of(suspect)

	// A step aside, then off across the room
	suspect.forceMove(at(7, 5))
	TEST_ASSERT(police.gives_up(suspect), "A step to the next tile was taken as walking off")
	suspect.forceMove(at(8, 6))
	TEST_ASSERT(!police.gives_up(suspect), "Someone two tiles from where they stood is still taken as staying put")
	TEST_ASSERT(police_plans_shot(watcher, suspect), "An officer plans no shot at a two-star suspect who walks off")
	stance.moved_at -= 1 SECONDS
	TEST_ASSERT(!police.gives_up(suspect), "Someone who stopped a second ago is already taken as giving up")
	stance.moved_at -= 1 SECONDS // OUTPOST_POLICE_YIELD_TIME in all
	TEST_ASSERT(police.gives_up(suspect), "Someone who has stood still for two seconds is not taken as giving up")

	// A weapon in their hand, then put down
	var/obj/item/knife/kitchen/knife = allocate(/obj/item/knife/kitchen)
	suspect.put_in_active_hand(knife, forced = TRUE)
	TEST_ASSERT(!police.gives_up(suspect), "Someone with a knife in their hand is taken as giving up")
	TEST_ASSERT(police_plans_shot(watcher, suspect), "An officer plans no shot at a two-star suspect with a knife out")
	suspect.dropItemToGround(knife, TRUE)
	TEST_ASSERT(!police.gives_up(suspect), "Someone who dropped their knife this instant is already taken as giving up")
	stance.fought_at -= 2 SECONDS // OUTPOST_POLICE_YIELD_TIME
	TEST_ASSERT(police.gives_up(suspect), "Someone who dropped their knife two seconds ago is not taken as giving up")

	// A blow
	police.note_fought(suspect)
	TEST_ASSERT(!police.gives_up(suspect), "Someone who just hit out is taken as giving up")
	// The cuffs come out (they are on the floor): what came before is past, and where they lie is where they are
	stance.moved_at = world.time
	suspect.Knockdown(5 SECONDS)
	case.set_step("subdue")
	case.step_subdue()
	TEST_ASSERT(police.arrest_cuffing(suspect), "Fixture: the arrest is not going for the cuffs")
	TEST_ASSERT(police.gives_up(suspect), "With the cuffs coming, a suspect on the floor is still held to what they did before")
	TEST_ASSERT(!stance.fought_at && !stance.moved_at, "The cuffs coming out did not put what came before behind them")
	// From the cuffs, one step of their own is one too many
	suspect.Move(get_step(suspect, EAST), EAST)
	TEST_ASSERT(police.arrest_pulled_away(suspect), "Fixture: the suspect's own step from the cuffs was not counted")
	TEST_ASSERT(!police.gives_up(suspect), "Someone who crawled a tile from the cuffs is taken as lying still for them")
	stance.moved_at -= 2 SECONDS // OUTPOST_POLICE_YIELD_TIME
	TEST_ASSERT(police.gives_up(suspect), "Someone who has lain still for two seconds since crawling from the cuffs is not taken as giving up")

	// Nobody looked for a while: seen afresh where they are
	stance.looked_at -= 5 SECONDS // past OUTPOST_POLICE_STANCE_STALE
	suspect.forceMove(at(12, 6))
	TEST_ASSERT(police.gives_up(suspect), "Someone nobody had looked at for five seconds was held to where they stood then")

	// Three stars: no holding fire, whatever they do
	police_pin_warrant(police, suspect.mind, 55) // three stars
	TEST_ASSERT(!watcher.police_holds_fire(suspect), "An officer holds its fire for a three-star suspect who stands still")
	police_pin_warrant(police, suspect.mind, 25)

	// Pulled along by someone is no step of their own
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/puller = scene[3]
	puller.forceMove(at(11, 6))
	TEST_ASSERT(police.gives_up(suspect), "Fixture: the suspect is not giving up before they are pulled")
	puller.start_pulling(suspect)
	for(var/i in 1 to 3)
		puller.Move(get_step(puller, WEST), WEST)
	TEST_ASSERT(suspect.pulledby == puller && get_dist(suspect, at(12, 6)) >= 2, "Fixture: the suspect was not pulled two tiles or more (at [suspect.x - at(0, 0).x],[suspect.y - at(0, 0).y], pulled by [suspect.pulledby])")
	TEST_ASSERT(police.gives_up(suspect), "Someone pulled along three tiles was taken as walking off")
	puller.stop_pulling()
	police.close_case(suspect.mind)

/// An officer holding its fire keeps its weapon out, tells them to stay where they are, and closes to three tiles in sight of them
/datum/unit_test/voidcrew_stealth_live/police/holds_its_aim

/datum/unit_test/voidcrew_stealth_live/police/holds_its_aim/Run()
	var/list/scene = force_scene()
	if(!scene)
		return
	var/mob/living/carbon/human/suspect = scene[1]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/watcher = scene[5]
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = watcher.ai_controller
	var/datum/ai_planning_subtree/outpost_police_force/force_tree = locate() in brain.planning_subtrees
	brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, suspect)
	brain.planned_behaviors.Cut()
	TEST_ASSERT_EQUAL(force_tree.SelectBehaviors(brain, 1), SUBTREE_RETURN_FINISH_PLANNING, "An officer holding its fire went on to the shooting and melee subtrees")
	TEST_ASSERT_EQUAL(watcher.force, 2, "An officer holding its fire on a two-star suspect is at force [watcher.force]") // POLICE_FORCE_STUN
	TEST_ASSERT_NOTNULL(watcher.police_loaded_gun_for(2), "An officer holding its fire has no disabler in its hand")
	TEST_ASSERT(locate(/datum/ai_behavior/human_npc_close_in) in brain.planned_behaviors, "An officer holding its fire four tiles off did not close in")
	TEST_ASSERT(!(locate(/datum/ai_behavior/human_npc_shoot) in brain.planned_behaviors) && !(locate(/datum/ai_behavior/basic_melee_attack) in brain.planned_behaviors), "An officer holding its fire planned a shot or a blow")
	var/datum/outpost_police_stance/stance = police.stance_of(suspect)
	TEST_ASSERT_EQUAL(stance.told_at, world.time, "The first officer to hold its fire on someone nobody has spoken to yet said nothing")
	TEST_ASSERT_EQUAL(brain.stealth_state(), "alert", "An officer holding its fire is [brain.stealth_state()]")

	// Three tiles off and in sight: it stands and watches
	watcher.forceMove(at(9, 4))
	brain.planned_behaviors.Cut()
	force_tree.SelectBehaviors(brain, 1)
	TEST_ASSERT(locate(/datum/ai_behavior/outpost_police_watch) in brain.planned_behaviors, "An officer holding its fire three tiles off does not stand and watch")
	TEST_ASSERT(!(locate(/datum/ai_behavior/human_npc_close_in) in brain.planned_behaviors), "An officer holding its fire three tiles off went on closing in")
	brain.planned_behaviors.Cut()
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	police.close_case(suspect.mind)

/// Someone wanted who hit somebody a moment ago gets no second look either, arrest or no arrest: a crime in front of an officer is answered at once
/datum/unit_test/voidcrew_stealth_live/police/fresh_fight_seen_at_once

/datum/unit_test/voidcrew_stealth_live/police/fresh_fight_seen_at_once/Run()
	var/list/scene = notice_scene()
	if(!scene)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = scene[1]
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	var/mob/living/carbon/human/suspect = scene[2]
	TEST_ASSERT(!police.is_after(suspect), "Fixture: the police are already after the suspect")
	police.note_fought(suspect)
	var/list/stages = notice_stages(officer)
	TEST_ASSERT(!("suspicious" in stages), "An officer took a second look at a wanted person who had just hit somebody ([stages.Join(", ")])")
	TEST_ASSERT_EQUAL(brain.stealth_state(), "alert", "An officer who sees a wanted person fresh from a fight is [brain.stealth_state()] ([stages.Join(", ")])")
	TEST_ASSERT(!brain.bark_ready_at["stealth_suspicious"], "An officer said its \"what's that\" line to a wanted person who had just hit somebody")
