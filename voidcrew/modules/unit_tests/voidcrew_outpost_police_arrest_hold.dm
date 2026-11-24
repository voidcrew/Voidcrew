/**
 * Outpost police tests: the mechanics of taking someone in (voidcrew/modules/outpost_police/police_arrest.dm).
 * The hold while the cuffs go on, the walk off with someone reached over a rail, the step's clock, and the arrest's
 * two officers never being left with nothing planned.
 *
 * The room and police of voidcrew_stealth_live/police/crowd (voidcrew_outpost_police_crowd.dm). The case is stepped
 * by hand; what is done to a body is tg's own (Knockdown, the pull, a step, the cuffs' do_after). Fork defines are
 * included after the tests, so values are written out: steps "respond", "cuff", "subdue", "escort"; the action
 * "cuffing"; states "unaware", "searching"; heat 12 is one star, 40 is two; OUTPOST_POLICE_STEP_TIMEOUT is 60 s.
 */

/// A wanted person at (dx, dy) and the arrest on them, the police's own tick stopped. Returns the case (null, and the test has failed, without one).
/datum/unit_test/voidcrew_stealth_live/police/crowd/proc/arrest_at(dx, dy, heat = 12)
	wanted_at(dx, dy, heat, FALSE)
	var/datum/outpost_police_case/case = police.open_case(police.get_warrant(suspect.mind))
	police.sleep_tick()
	if(!case)
		TEST_FAIL("Fixture: no arrest opened on the suspect")
	return case

/// The suspect in a pair of used police cuffs, searched, with the walk to the desk next
/datum/unit_test/voidcrew_stealth_live/police/crowd/proc/cuffed_for_the_walk(datum/outpost_police_case/case)
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	suspect.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	case.cuffs_on(suspect)
	case.searched = TRUE
	case.set_step("escort")

/**
 * A suspect put on the floor by the baton is held while the cuffs go on. tg's knockdown floors someone and leaves them
 * able to crawl, and its cuffing breaks off when they move: the owner crawled out of it. One who breaks the hold and
 * crawls off gets the baton again before the next try, and is cuffed in the end.
 */
/datum/unit_test/voidcrew_stealth_live/police/crowd/cuff_hold

/datum/unit_test/voidcrew_stealth_live/police/crowd/cuff_hold/Run()
	TEST_ASSERT(police_room(9, 7), "No room for the test")
	open_place()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = squad_officer(4, 4, SOUTH)
	police_arrest_kit(officer)
	var/datum/outpost_police_case/case = arrest_at(4, 3)
	if(!case)
		return
	TEST_ASSERT_EQUAL(case.arresting(), officer, "Fixture: the officer is not the arresting officer")

	suspect.Knockdown(30 SECONDS)
	TEST_ASSERT_EQUAL(suspect.body_position, LYING_DOWN, "Fixture: the knockdown did not floor the suspect")
	TEST_ASSERT(!HAS_TRAIT(suspect, TRAIT_INCAPACITATED), "Fixture: a knockdown should leave them able to crawl")
	case.enter_cuff(suspect)
	case.step_cuff()
	TEST_ASSERT_EQUAL(case.acting, "cuffing", "The cuffing of a suspect on the floor did not start")
	TEST_ASSERT_EQUAL(officer.pulling, suspect, "The officer cuffs someone knocked down without a hand on them: they only have to crawl a tile")
	TEST_ASSERT(officer.grab_state >= GRAB_AGGRESSIVE, "Someone put on the floor who can still crawl is held in a plain pull, not tg's firm grip")

	// The roll goes their way (tg's resist_grab() lets go of them), and they crawl a tile
	officer.stop_pulling()
	var/turf/crawled_to = at(4, 2)
	suspect.Move(crawled_to, SOUTH)
	TEST_ASSERT_EQUAL(suspect.loc, crawled_to, "Fixture: the suspect did not crawl a tile")
	police_arrest_wait(case)
	TEST_ASSERT(!suspect.handcuffed, "Fixture: the cuffs went on someone who crawled off")
	TEST_ASSERT_EQUAL(case.step, "subdue", "A suspect who crawled off from the cuffs is not put down again")

	// The baton again, on the floor, before the next try at the cuffs. The grip it took a moment ago is a click of
	// its own (tg's CLICK_CD_GRABBING, one second), so the blow is the case's next try or the one after
	officer.forceMove(at(4, 3))
	case.step_subdue()
	TEST_ASSERT_EQUAL(case.step, "subdue", "A suspect who crawled off was taken back to the cuffs before any blow")
	var/blow_by = world.time + 4 SECONDS
	while(case.strikes < 1 && world.time < blow_by)
		sleep(5)
		case.step_subdue()
	TEST_ASSERT(case.strikes >= 1, "No blow was thrown at a suspect crawling off from the cuffs")
	sleep(2)
	case.step_subdue()
	TEST_ASSERT_EQUAL(case.step, "cuff", "After the blow the arrest did not go back to the cuffs")
	case.step_cuff()
	TEST_ASSERT_EQUAL(officer.pulling, suspect, "The second try at the cuffs was made without a hand on them")
	police_arrest_wait(case)
	TEST_ASSERT(suspect.handcuffed, "A suspect held on the floor was not cuffed")
	police.close_case(suspect.mind)

/// Someone who did as they were told is held by a plain pull while the cuffs go on, never tg's firm grip, and takes no blow
/datum/unit_test/voidcrew_stealth_live/police/crowd/cuff_hold_complied

/datum/unit_test/voidcrew_stealth_live/police/crowd/cuff_hold_complied/Run()
	TEST_ASSERT(police_room(9, 7), "No room for the test")
	open_place()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = squad_officer(4, 4, SOUTH)
	police_arrest_kit(officer)
	var/datum/outpost_police_case/case = arrest_at(4, 3)
	if(!case)
		return
	// Lay down when told to
	suspect.set_resting(TRUE, TRUE, TRUE)
	TEST_ASSERT_EQUAL(suspect.body_position, LYING_DOWN, "Fixture: the suspect did not lie down")
	case.set_step("order")
	case.step_order()
	TEST_ASSERT_EQUAL(case.step, "cuff", "A suspect who lay down at the order did not go to the cuffs")
	case.step_cuff()
	TEST_ASSERT_EQUAL(officer.pulling, suspect, "The officer cuffs someone lying down without a hand on them")
	TEST_ASSERT_EQUAL(officer.grab_state, GRAB_PASSIVE, "Someone who did as they were told is held in tg's firm grip")
	police_arrest_wait(case)
	TEST_ASSERT(suspect.handcuffed, "A suspect who lay down was not cuffed")
	TEST_ASSERT_EQUAL(case.strikes, 0, "A suspect who did as they were told was struck")
	police.close_case(suspect.mind)

/**
 * A suspect cuffed over a rail (hands reach over one, feet do not cross it) is not walked off from the far side of it:
 * the pull would break at the second step, and at the Undertow the officer took hold and lost it every three seconds
 * for the rest of the round. The officer goes round to a tile they can step onto, takes hold there, and they follow.
 */
/datum/unit_test/voidcrew_stealth_live/police/crowd/rail_escort

/datum/unit_test/voidcrew_stealth_live/police/crowd/rail_escort/Run()
	TEST_ASSERT(police_room(9, 7), "No room for the test")
	open_place()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = squad_officer(4, 4, SOUTH)
	var/datum/outpost_police_case/case = arrest_at(4, 3)
	if(!case)
		return
	// A booth: a rail along the north side of the suspect's tile and the tiles either side of it
	for(var/dx in 3 to 5)
		var/obj/structure/railing/rail = allocate(/obj/structure/railing, at(dx, 3))
		rail.setDir(NORTH)
	TEST_ASSERT(officer.Adjacent(suspect), "Fixture: a hand should reach over the rail")
	cuffed_for_the_walk(case)
	// Somewhere to walk to: the evidence goes to the desk
	var/obj/item/outpost_sealed_case/evidence/box = allocate(/obj/item/outpost_sealed_case/evidence)
	officer.put_in_hands(box)
	case.evidence_ref = WEAKREF(box)
	police.desk_turf = at(1, 6)

	case.step_escort()
	var/turf/walk_to = get_turf(case.goal)
	TEST_ASSERT(!(officer.pulling == suspect && walk_to && get_dist(walk_to, suspect) > 1), "The officer set off for the desk holding a suspect across a rail they cannot follow over")
	TEST_ASSERT_EQUAL(case.step, "escort", "The walk went on though nobody can be led from across the rail")
	TEST_ASSERT(isturf(case.goal) && get_dist(case.goal, suspect) == 1, "The officer was not sent round to a tile beside the suspect ([case.goal])")
	var/turf/round_at = case.goal
	TEST_ASSERT(round_at.y <= suspect.y, "The tile to lead them off from is across the rail")
	TEST_ASSERT_EQUAL(case.pull_breaks, 0, "Letting go to walk round was counted as the suspect breaking the hold")

	// Round on their side: it takes hold, and they follow its first step
	officer.forceMove(round_at)
	case.step_escort()
	TEST_ASSERT_EQUAL(officer.pulling, suspect, "On the suspect's side of the rail the officer did not take hold of them")
	var/turf/officer_was = get_turf(officer)
	var/turf/onward = get_step(officer, get_dir(suspect, officer))
	TEST_ASSERT(officer.Move(onward, get_dir(officer, onward)), "Fixture: the officer could not step on")
	TEST_ASSERT_EQUAL(officer.pulling, suspect, "The hold broke at the officer's first step")
	TEST_ASSERT_EQUAL(suspect.loc, officer_was, "The suspect did not follow the officer's step")
	police.close_case(suspect.mind)

/// While the arresting officer goes round a rail, the cover beside the suspect keeps a hand on them, and gives them up when the arresting officer takes them
/datum/unit_test/voidcrew_stealth_live/police/crowd/rail_cover_holds

/datum/unit_test/voidcrew_stealth_live/police/crowd/rail_cover_holds/Run()
	TEST_ASSERT(police_room(9, 7), "No room for the test")
	open_place()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = squad_officer(4, 4, SOUTH)
	var/datum/outpost_police_case/case = arrest_at(4, 3)
	if(!case)
		return
	TEST_ASSERT_EQUAL(case.arresting(), officer, "Fixture: the officer is not the arresting officer")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/second = squad_officer(5, 4, SOUTH)
	case.staff()
	TEST_ASSERT_EQUAL(case.cover(), second, "Fixture: the second officer is not the cover")
	for(var/dx in 3 to 5)
		var/obj/structure/railing/rail = allocate(/obj/structure/railing, at(dx, 3))
		rail.setDir(NORTH)
	cuffed_for_the_walk(case)
	var/obj/item/outpost_sealed_case/evidence/box = allocate(/obj/item/outpost_sealed_case/evidence)
	officer.put_in_hands(box)
	case.evidence_ref = WEAKREF(box)
	police.desk_turf = at(1, 6)
	officer.start_pulling(suspect)

	case.step_escort()
	TEST_ASSERT_NULL(officer.pulling, "The arresting officer kept hold across the rail as it set off round it")
	TEST_ASSERT_EQUAL(second.pulling, suspect, "The cover beside a suspect the arresting officer let go of did not take hold of them")
	TEST_ASSERT(police.in_custody(suspect), "A cuffed suspect in the cover's hands is not in custody")
	officer.forceMove(case.goal)
	case.step_escort()
	TEST_ASSERT_EQUAL(officer.pulling, suspect, "The arresting officer did not take the suspect from the cover")
	TEST_ASSERT_NULL(second.pulling, "The cover kept hold of a suspect the arresting officer has")
	police.close_case(suspect.mind)

/// Which way someone can be drawn: over no rail, counter or shut door, and a corner rail stops only its own two sides
/datum/unit_test/voidcrew_stealth_live/police/crowd/can_draw

/datum/unit_test/voidcrew_stealth_live/police/crowd/can_draw/Run()
	TEST_ASSERT(police_room(9, 7), "No room for the test")
	var/mob/living/carbon/human/person = person_at(4, 3, FALSE)
	var/obj/structure/railing/corner = allocate(/obj/structure/railing, at(4, 3))
	corner.setDir(NORTHWEST)
	TEST_ASSERT(!outpost_police_can_draw(person, at(4, 4)), "Drawn north over a rail")
	TEST_ASSERT(!outpost_police_can_draw(person, at(3, 3)), "Drawn west over a rail")
	TEST_ASSERT(!outpost_police_can_draw(person, at(3, 4)), "Drawn through a rail's corner")
	TEST_ASSERT(outpost_police_can_draw(person, at(5, 3)), "A corner rail on the north and west stops a step east")
	TEST_ASSERT(outpost_police_can_draw(person, at(4, 2)), "A corner rail on the north and west stops a step south")
	TEST_ASSERT(outpost_police_can_draw(person, at(5, 2)), "A corner rail on the north and west stops a step south-east")
	TEST_ASSERT(outpost_police_can_draw(person, at(4, 3)), "Someone cannot be drawn onto the tile they are on")
	TEST_ASSERT(!outpost_police_can_draw(person, at(6, 3)), "Drawn two tiles in one step")
	allocate(/obj/structure/table, at(5, 3))
	TEST_ASSERT(!outpost_police_can_draw(person, at(5, 3)), "Drawn onto a table")

/**
 * The step's clock. Going back and forth between two things (a hold lost and taken again: to the suspect, to the
 * desk, to the suspect) is not getting anywhere, and the step runs out; it used to start the clock again at every
 * turn, and one arrest sat on "desk" at nought seconds for four minutes. Holding fire for a hostage is waiting on
 * purpose, and the clock waits with it.
 */
/datum/unit_test/voidcrew_stealth_live/police/crowd/step_clock

/datum/unit_test/voidcrew_stealth_live/police/crowd/step_clock/Run()
	TEST_ASSERT(police_room(14, 7), "No room for the test")
	open_place()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = squad_officer(6, 3)
	var/datum/outpost_police_case/case = arrest_at(11, 3)
	if(!case)
		return
	TEST_ASSERT_EQUAL(case.arresting(), officer, "Fixture: the officer is not the arresting officer")
	var/turf/desk = at(1, 3)
	// The first walk at each is a start
	case.route_to(officer, suspect, 1)
	case.route_to(officer, desk, 1)
	for(var/turn in 1 to 3)
		case.step_started_at = world.time - 30 SECONDS
		case.route_to(officer, suspect, 1)
		TEST_ASSERT_EQUAL(case.step_started_at, world.time - 30 SECONDS, "Turning back to the suspect, no nearer than before, started the step's clock again (turn [turn])")
		case.route_to(officer, desk, 1)
		TEST_ASSERT_EQUAL(case.step_started_at, world.time - 30 SECONDS, "Turning back to the desk, no nearer than before, started the step's clock again (turn [turn])")
	// Getting nearer still counts
	officer.forceMove(at(8, 3))
	case.route_to(officer, suspect, 1)
	TEST_ASSERT_EQUAL(case.step_started_at, world.time, "Getting nearer the suspect did not keep the step's clock fresh")

	// A step that has run out goes back to the start; one spent holding fire for a hostage does not
	var/datum/ai_controller/basic_controller/human_npc/stealth/brain = officer.ai_controller
	brain.standoff_holder = WEAKREF(suspect)
	case.step_started_at = world.time - 61 SECONDS
	case.process_case()
	TEST_ASSERT_EQUAL(case.resets, 0, "An arrest whose officer is holding fire for a hostage ran out its step")
	brain.standoff_holder = null
	case.step_started_at = world.time - 61 SECONDS
	case.process_case()
	TEST_ASSERT_EQUAL(case.resets, 1, "A step that got nowhere for a minute did not run out")
	police.close_case(suspect.mind)

/**
 * The arrest's two officers always have something planned. A plan with nothing in it is a failed one to tg, which
 * switches the AI off for a second and a half at a time, and the stealth scan with it: the arresting officer while
 * the cuffs go on, and the cover standing by, spent most of an arrest switched off.
 */
/datum/unit_test/voidcrew_stealth_live/police/crowd/never_idle

/datum/unit_test/voidcrew_stealth_live/police/crowd/never_idle/Run()
	TEST_ASSERT(police_room(9, 7), "No room for the test")
	open_place()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = squad_officer(4, 4, SOUTH)
	police_arrest_kit(officer)
	var/datum/outpost_police_case/case = arrest_at(4, 3)
	if(!case)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/second = squad_officer(4, 5, SOUTH)
	case.staff()
	TEST_ASSERT_EQUAL(case.arresting(), officer, "Fixture: the officer is not the arresting officer")
	TEST_ASSERT_EQUAL(case.cover(), second, "Fixture: the second officer is not the cover")
	var/datum/ai_controller/brain = wake(officer)
	var/datum/ai_controller/second_brain = wake(second)
	police.note_seen(suspect.mind, get_turf(suspect))

	// Beside the suspect with the cuffs going on, and the cover within reach of its colleague: nowhere to walk
	case.enter_cuff(suspect)
	case.step_cuff()
	TEST_ASSERT_EQUAL(case.acting, "cuffing", "Fixture: the cuffing did not start")
	brain.SelectBehaviors(1)
	TEST_ASSERT(length(brain.current_behaviors), "The arresting officer has nothing planned while the cuffs go on: tg switches its AI off")
	second_brain.SelectBehaviors(1)
	TEST_ASSERT(length(second_brain.current_behaviors), "The cover standing by its colleague has nothing planned: tg switches its AI off")
	police_arrest_wait(case)
	TEST_ASSERT(suspect.handcuffed, "Fixture: the suspect was not cuffed")
	// Standing, they face the one they have
	second.setDir(NORTH)
	var/datum/ai_behavior/outpost_police_case_stand/stand = locate() in second_brain.current_behaviors
	TEST_ASSERT_NOTNULL(stand, "The cover standing by is not on the arrest's own standing behaviour")
	stand.perform(1, second_brain)
	TEST_ASSERT_EQUAL(second.dir, get_dir(second, suspect), "The cover standing by does not face the suspect")
	police.close_case(suspect.mind)

/**
 * The cover looks for a suspect nobody sees by itself, a place of its own, where it used only to walk behind the
 * arresting officer. With eyes on them again its search is over and it is back with its colleague.
 */
/datum/unit_test/voidcrew_stealth_live/police/crowd/cover_looks

/datum/unit_test/voidcrew_stealth_live/police/crowd/cover_looks/Run()
	TEST_ASSERT(police_room(40, 9), "No room for the test")
	open_place()
	// A wall across the room with a gap, so the suspect at the far end is out of sight
	for(var/dy in 0 to 6)
		var/turf/wall_spot = at(24, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	squad_officer(8, 4, WEST)
	squad_officer(10, 4, WEST)
	suspect = unseen_suspect(2, 4, 38, 1)
	var/datum/outpost_warrant/warrant = police.get_warrant(suspect.mind)
	var/datum/outpost_police_case/case = police.open_case(warrant)
	police.sleep_tick()
	TEST_ASSERT_NOTNULL(case, "Fixture: no arrest opened at two stars")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = case.arresting()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/second = case.cover()
	TEST_ASSERT(officer && second && officer != second, "Fixture: the arrest does not have its two officers")
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/first_brain = wake(officer)
	first_brain.stealth_setup()
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/second_brain = wake(second)
	second_brain.stealth_setup()

	case.process_case()
	TEST_ASSERT_EQUAL(second_brain.stealth_state(), "searching", "With the suspect out of everyone's sight the cover is not looking for them")
	TEST_ASSERT_NOTNULL(second.search_claim, "The cover was dealt no place to look")
	TEST_ASSERT_NOTEQUAL(second.search_claim, officer.search_claim, "The cover was dealt the arresting officer's place")
	second_brain.SelectBehaviors(1)
	TEST_ASSERT(length(second_brain.current_behaviors), "The cover on its own search has nothing planned")
	TEST_ASSERT_NOTEQUAL(second_brain.current_movement_target, officer, "The cover on its own search walks behind the arresting officer")

	// Someone has eyes on them: the search is over, and it is its colleague's cover again
	warrant.last_seen_turf = at(30, 2)
	warrant.last_seen_at = world.time
	warrant.unseen_since = 0
	second.forceMove(at(12, 4))
	officer.forceMove(at(17, 4))
	second_brain.SelectBehaviors(1)
	TEST_ASSERT_EQUAL(second_brain.stealth_state(), "unaware", "With eyes on the suspect again the cover went on searching")
	TEST_ASSERT(length(second_brain.current_behaviors), "The cover going back to its colleague has nothing planned")
	TEST_ASSERT_EQUAL(second_brain.current_movement_target, officer, "The cover does not go back to the arresting officer")
	police.close_case(suspect.mind)

/**
 * An officer on its way past a colleague who stands right in front of it, a wall on its other side, and the suspect
 * off on the diagonal. Its pathfinder plans the diagonal step past the colleague; the colleague stands on one leg of
 * that step and the wall is the other, so the step never happens, and it used to be planned again for good (Halcyon's
 * bar doorway, the hostage soak). It takes the colleague up straight, gets past, and makes the arrest.
 */
/datum/unit_test/voidcrew_stealth_live/police/crowd/diagonal_past

/datum/unit_test/voidcrew_stealth_live/police/crowd/diagonal_past/Run()
	TEST_ASSERT(police_room(9, 8), "No room for the test")
	open_place()
	// A wall with a gap three wide. The officer stands at the gap's west end, the colleague on the tile in front of it.
	for(var/dx in list(0, 1, 2, 3, 7, 8))
		var/turf/wall_spot = at(dx, 1)
		wall_spot.ChangeTurf(/turf/closed/wall)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = squad_officer(4, 1, NORTH)
	police_arrest_kit(officer)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/colleague = officer_at(4, 2, NORTH)
	wanted_at(1, 4, 12, FALSE)
	var/datum/outpost_police_case/case = police.open_case(police.get_warrant(suspect.mind))
	TEST_ASSERT_NOTNULL(case, "Fixture: no arrest opened on the suspect")
	if(case.arresting() != officer)
		case.officers.Swap(1, 2)
	TEST_ASSERT_EQUAL(case.arresting(), officer, "Fixture: the officer behind its colleague is not the arresting officer")
	watch(40, CALLBACK(src, PROC_REF(suspect_cuffed)))
	TEST_ASSERT(suspect.handcuffed, "The officer never got past the colleague in front of it to the suspect (officer at [officer.x - at(0, 0).x],[officer.y - at(0, 0).y], colleague at [colleague.x - at(0, 0).x],[colleague.y - at(0, 0).y], arrest on \"[case.step]\")")

/**
 * Someone wanted who stands in a pond (Halcyon has one) is waded in after. Water is not ground to the outpost's
 * people, whose own steps never go into it; the pathfinder plans through it all the same, so the arresting officer
 * stood on the pier with a walk it could not make, and the pond was a place nobody could be arrested in. An officer
 * on an arrest wades; any other officer still keeps to dry ground.
 */
/datum/unit_test/voidcrew_stealth_live/police/crowd/wade

/datum/unit_test/voidcrew_stealth_live/police/crowd/wade/Run()
	TEST_ASSERT(police_room(9, 7), "No room for the test")
	open_place()
	for(var/dx in 2 to 6)
		for(var/dy in 1 to 3)
			var/turf/pond_spot = at(dx, dy)
			pond_spot.ChangeTurf(/turf/open/water)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = squad_officer(4, 4, SOUTH)
	var/datum/outpost_police_case/case = arrest_at(4, 2)
	if(!case)
		return
	TEST_ASSERT_EQUAL(case.arresting(), officer, "Fixture: the officer is not the arresting officer")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/bystander = officer_at(7, 4, WEST)
	case.drop_officer(bystander)
	TEST_ASSERT(!bystander.case, "Fixture: the second officer is on the arrest")
	TEST_ASSERT(!bystander.Move(at(7, 3), SOUTH) || !istype(bystander.loc, /turf/open/water), "Fixture: an officer with no arrest should keep out of the water")
	bystander.forceMove(at(7, 4))
	bystander.Move(at(6, 3), SOUTHWEST)
	TEST_ASSERT(!istype(bystander.loc, /turf/open/water), "An officer with no arrest to make walked into the pond")
	TEST_ASSERT(officer.Move(at(4, 3), SOUTH), "An officer making an arrest would not step into the pond after its suspect")
	TEST_ASSERT(officer.Adjacent(suspect), "Fixture: the officer in the pond is not beside the suspect")
	police.close_case(suspect.mind)

/**
 * A cover taken from the lobby (the desk warden, when nobody else is free) goes to the concourse by the checkpoint,
 * the way an officer on any other errand does. Its plain walk at the arresting officer had no way through the gate.
 */
/datum/unit_test/voidcrew_outpost_police_arrest_cover_lobby

/datum/unit_test/voidcrew_outpost_police_arrest_cover_lobby/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	var/list/parts = police_arrest_setup(outpost)
	if(!parts)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = parts[1]
	var/mob/living/carbon/human/suspect = parts[2]
	var/datum/outpost_police_case/case = parts[3]
	TEST_ASSERT_NOTNULL(police.desk_turf, "Fixture: the outpost has no desk")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/warden = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant, police.desk_turf)
	TEST_ASSERT_NOTEQUAL(police.sector_of(get_turf(warden)), police.sector_of(get_turf(officer)), "Fixture: the desk and the arrest are in the same part of the outpost")
	case.staff()
	TEST_ASSERT_EQUAL(case.cover(), warden, "Fixture: the warden is not the cover")
	police.note_seen(suspect.mind, get_turf(suspect))
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = warden.ai_controller
	brain.reset_ai_status()
	brain.stealth_setup()
	brain.SelectBehaviors(1)
	TEST_ASSERT(length(brain.current_behaviors), "The cover in the lobby has nothing planned")
	TEST_ASSERT_NOTEQUAL(brain.current_movement_target, officer, "The cover in the lobby walks straight at the arresting officer, with no way through the checkpoint")
	TEST_ASSERT_NOTNULL(brain.goto_dest, "The cover in the lobby is not on the walk that knows the way through the checkpoint")
	TEST_ASSERT_NOTEQUAL(brain.goto_dest, get_turf(officer), "The cover in the lobby walks straight at the arresting officer's tile")
	police.close_case(suspect.mind)
	police_pin_warrant(police, suspect.mind, 0)
