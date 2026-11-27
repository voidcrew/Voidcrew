/**
 * Outpost police tests, pass 3 of the arrest (voidcrew/modules/outpost_police/police_arrest.dm): the officer on the spot
 * makes the arrest, someone who runs in the cuffs is stunned and held again, an arrest that cannot finish holds them
 * rather than letting them go, a player standing in the arrest's way is resisting, and a shove is not the suspect's step.
 *
 * The room and police of voidcrew_stealth_live/police/crowd (voidcrew_outpost_police_crowd.dm), the police tick
 * stopped and the case stepped by hand. Written out: heat 12 is one star, 40 is two; POLICE_FORCE_STUN is 2;
 * CASE_ON_THE_SPOT_WAIT is 8 s, CASE_BLOCK_GRACE 4 s, CASE_HOLD_FINE_AFTER 3 minutes; OUTPOST_CRIME_RESIST is "resist".
 */

/**
 * Someone giving up beside an officer that is not the arresting one waits for the arresting officer only so long: then
 * the officer on the spot makes the arrest, the one it was taken from covers it, and the old cover goes back to its
 * beat. Never for someone with a weapon in their hands, and once handed over the arrest stays.
 */
/datum/unit_test/voidcrew_stealth_live/police/crowd/on_the_spot

/datum/unit_test/voidcrew_stealth_live/police/crowd/on_the_spot/Run()
	TEST_ASSERT(police_room(14, 7), "No room for the test")
	open_place()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/far = squad_officer(12, 3, WEST)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/far_cover = squad_officer(13, 3, WEST)
	var/datum/outpost_police_case/case = arrest_at(1, 3, 40)
	if(!case)
		return
	case.staff()
	TEST_ASSERT_EQUAL(case.arresting(), far, "Fixture: the far officer is not the arresting officer")
	TEST_ASSERT_EQUAL(case.cover(), far_cover, "Fixture: the second far officer is not the cover")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/near = squad_officer(2, 3, WEST)
	police_arrest_kit(near)

	// Armed, they have not given up: nobody takes it on the spot
	var/obj/item/gun/energy/laser/gun = allocate(/obj/item/gun/energy/laser)
	suspect.put_in_hands(gun)
	case.check_on_the_spot(suspect)
	case.spot_since = world.time - 9 SECONDS
	case.check_on_the_spot(suspect)
	TEST_ASSERT_EQUAL(case.arresting(), far, "The arrest went to the officer beside an armed suspect")
	qdel(gun)
	var/datum/outpost_police_stance/stance = LAZYACCESS(police.stances, WEAKREF(suspect.mind))
	if(stance)
		stance.fought_at = 0

	// Giving up beside it: not at once, the arresting officer gets its time to come
	case.check_on_the_spot(suspect)
	TEST_ASSERT_EQUAL(case.arresting(), far, "The arrest was taken from its officer the moment someone gave up beside another")
	TEST_ASSERT_EQUAL(case.spot_ref?.resolve(), near, "The officer beside someone giving up was not seen as on the spot")
	case.spot_since = world.time - 9 SECONDS
	case.check_on_the_spot(suspect)
	TEST_ASSERT_EQUAL(case.arresting(), near, "The officer beside someone giving up did not take the arrest when the arresting officer did not come")
	TEST_ASSERT_EQUAL(case.cover(), far, "The officer the arrest was taken from does not cover it")
	TEST_ASSERT_EQUAL(near.case, case, "The officer on the spot is not on the arrest")
	TEST_ASSERT_NULL(far_cover.case, "The old cover is still on the arrest: three officers on one suspect")

	// No ping-pong: the old officer arriving beside them does not take it back
	far.forceMove(at(1, 4))
	case.staff()
	case.check_on_the_spot(suspect)
	TEST_ASSERT_EQUAL(case.arresting(), near, "The arrest went back to the officer it was taken from")
	// The step goes on with the new officer: beside them, the order
	case.step_respond()
	TEST_ASSERT_EQUAL(case.step, "order", "The officer on the spot did not go on with the arrest")
	police.close_case(suspect.mind)

/// With the arresting officer on another level, the officer on the spot takes the arrest at once
/datum/unit_test/voidcrew_stealth_live/police/crowd/on_the_spot_no_way

/datum/unit_test/voidcrew_stealth_live/police/crowd/on_the_spot_no_way/Run()
	TEST_ASSERT(police_room(9, 7), "No room for the test")
	open_place()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/far = squad_officer(7, 3, WEST)
	var/datum/outpost_police_case/case = arrest_at(1, 3, 40)
	if(!case)
		return
	TEST_ASSERT_EQUAL(case.arresting(), far, "Fixture: the far officer is not the arresting officer")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/near = squad_officer(2, 3, WEST)
	// Out of action: knocked down
	far.Paralyze(20 SECONDS)
	case.check_on_the_spot(suspect)
	TEST_ASSERT_EQUAL(case.arresting(), near, "With the arresting officer down, the officer beside someone giving up did not take the arrest at once")
	police.close_case(suspect.mind)

/**
 * Someone in police cuffs who gets out of the hold and runs is stunned by the arrest's officers, never by anyone else,
 * and taken hold of again, firmly, once down. Being pushed, pulled or put somewhere is not running.
 */
/datum/unit_test/voidcrew_stealth_live/police/crowd/cuffed_bolt

/datum/unit_test/voidcrew_stealth_live/police/crowd/cuffed_bolt/Run()
	TEST_ASSERT(police_room(12, 7), "No room for the test")
	open_place()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = squad_officer(4, 4, SOUTH)
	police_arrest_kit(officer)
	var/datum/outpost_police_case/case = arrest_at(4, 3)
	if(!case)
		return
	TEST_ASSERT_EQUAL(case.arresting(), officer, "Fixture: the officer is not the arresting officer")
	cuffed_for_the_walk(case)
	case.step_escort()
	TEST_ASSERT_EQUAL(officer.pulling, suspect, "Fixture: the officer did not take hold of the cuffed suspect")

	// Pulled and put about: not running
	var/mob/living/carbon/human/puller = visitor_at(5, 2)
	officer.stop_pulling()
	puller.start_pulling(suspect)
	puller.Move(at(6, 2), EAST)
	puller.Move(at(7, 2), EAST)
	puller.stop_pulling()
	suspect.forceMove(at(5, 3))
	case.process_case()
	TEST_ASSERT(!case.bolting(suspect), "Being pulled or put somewhere was taken for running in the cuffs ([case.bolt_steps] steps)")
	qdel(puller)

	// Three steps of their own, nobody holding them: running
	officer.forceMove(at(4, 3))
	officer.stop_pulling()
	for(var/dx in 6 to 8)
		TEST_ASSERT(suspect.Move(at(dx, 3), EAST), "Fixture: the suspect could not step east")
	TEST_ASSERT(case.bolting(suspect), "Three steps of their own out of the hold in the cuffs are not running ([case.bolt_steps] steps)")
	TEST_ASSERT(officer.police_will_fight(suspect), "The arresting officer will not stop someone running in its cuffs")
	TEST_ASSERT_EQUAL(officer.force_for(suspect), 2, "The force for someone running in the cuffs is not a stun") // POLICE_FORCE_STUN
	// An officer off the arrest (made now: the case's own tick would take it on as the cover)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/other = squad_officer(10, 5, WEST)
	TEST_ASSERT_NULL(other.case, "Fixture: the other officer is on the arrest")
	TEST_ASSERT(!other.police_will_fight(suspect), "An officer off the arrest goes for someone in its cuffs")
	case.step_escort()
	TEST_ASSERT_EQUAL(case.goal, suspect, "The arresting officer is not going after someone running in the cuffs")

	// Caught up: the baton, not a hand
	officer.forceMove(at(9, 3))
	var/blow_by = world.time + 4 SECONDS
	while(case.strikes < 1 && world.time < blow_by)
		case.bolted_at = world.time
		case.step_escort()
		sleep(5)
	TEST_ASSERT(case.strikes >= 1, "No blow at someone running in the cuffs")

	// Down: hold of them again, tg's firm grip
	suspect.Knockdown(10 SECONDS)
	TEST_ASSERT(!case.bolting(suspect), "Someone on the floor counts as running")
	var/hold_by = world.time + 3 SECONDS
	while(officer.pulling != suspect && world.time < hold_by)
		case.step_escort()
		sleep(2)
	TEST_ASSERT_EQUAL(officer.pulling, suspect, "Someone put down after running in the cuffs was not taken hold of again")
	TEST_ASSERT(officer.grab_state >= GRAB_AGGRESSIVE, "The hold after running in the cuffs is not a firm grip")
	TEST_ASSERT(!case.bolting(suspect), "Someone held counts as running")
	police.close_case(suspect.mind)

/**
 * An arrest that times out three times with the suspect in its cuffs holds them, never takes the cuffs off; at one or
 * two stars, held long enough with no cell to be got to, they are fined where they stand and let go, warrant closed.
 */
/datum/unit_test/voidcrew_stealth_live/police/crowd/held_not_freed

/datum/unit_test/voidcrew_stealth_live/police/crowd/held_not_freed/Run()
	TEST_ASSERT(police_room(9, 7), "No room for the test")
	open_place()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = squad_officer(4, 4, SOUTH)
	var/datum/outpost_police_case/case = arrest_at(4, 3)
	if(!case)
		return
	cuffed_for_the_walk(case)
	case.resets = 2
	case.reset_case()
	TEST_ASSERT(!QDELETED(case), "The arrest ended on its third timeout with the suspect in its cuffs")
	TEST_ASSERT_EQUAL(case.step, "hold", "On its third timeout with the suspect in its cuffs the arrest is on [case.step], not holding them")
	TEST_ASSERT(istype(suspect.handcuffed, /obj/item/restraints/handcuffs/outpost_police), "The cuffs came off on the third timeout")
	TEST_ASSERT(case.held_since, "The hold did not start its clock")

	// Held, with no way to a cell, long enough: fined where they stand and let go
	case.step_hold()
	TEST_ASSERT_EQUAL(officer.pulling, suspect, "The officer holding them has no hand on them")
	case.held_since = world.time - 181 SECONDS
	case.step_hold()
	TEST_ASSERT_EQUAL(case.acting, "fining", "Held three minutes with no cell at one star, they were not fined where they stood")
	var/datum/mind/who = suspect.mind
	police_arrest_wait(case)
	TEST_ASSERT(QDELETED(case), "The arrest is still open after the fine on the spot")
	TEST_ASSERT(!suspect.handcuffed, "The cuffs stayed on after the fine on the spot")
	TEST_ASSERT_EQUAL(police.get_stars(who), 0, "The warrant is still open after the fine on the spot")

/**
 * A player standing in the way of an arrest, told to make way, is charged with resisting a few seconds later if they
 * stay; one who steps aside is not, nor is one of the outpost's own people. Standing on the tile the officer means to
 * lead its prisoner off from, with no other way to lead them, counts too.
 */
/datum/unit_test/voidcrew_stealth_live/police/crowd/blocking_resists

/datum/unit_test/voidcrew_stealth_live/police/crowd/blocking_resists/Run()
	TEST_ASSERT(police_room(9, 7), "No room for the test")
	open_place()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = squad_officer(4, 5, SOUTH)
	var/datum/outpost_police_case/case = arrest_at(4, 2)
	if(!case)
		return
	var/mob/living/carbon/human/blocker = visitor_at(4, 4)
	blocker.set_combat_mode(TRUE)

	// Walked into on the way to the suspect: told first
	officer.bump_blocker = WEAKREF(blocker)
	officer.bump_last = world.time
	case.check_blocking(officer, suspect)
	var/list/entry = LAZYACCESS(case.blockers, WEAKREF(blocker.mind))
	TEST_ASSERT_NOTNULL(entry, "A player the arresting officer walked into is not seen as in its way")
	TEST_ASSERT(entry && entry[1], "A player in the arrest's way was not told to make way")
	TEST_ASSERT_NULL(police.get_warrant(blocker.mind), "A player in the arrest's way was charged with no time to step aside")
	// Still there after the warning and a few seconds more: resisting
	entry[1] = world.time - 5 SECONDS
	officer.bump_last = world.time
	case.check_blocking(officer, suspect)
	var/datum/outpost_warrant/blocker_warrant = police.get_warrant(blocker.mind)
	TEST_ASSERT(blocker_warrant?.heat > 0 || length(police.pending_reports), "A player who stayed in the arrest's way after being told was not charged")

	// One of the outpost's own, walked into: never charged
	var/mob/living/carbon/human/local = local_at(3, 4)
	officer.bump_blocker = WEAKREF(local)
	officer.bump_last = world.time
	case.check_blocking(officer, suspect)
	TEST_ASSERT_EQUAL(LAZYLEN(case.blockers), 1, "One of the outpost's own was counted as standing in the arrest's way")
	police.close_case(suspect.mind)

/// In a booth behind a rail, the prisoner in hand: a player on the only tile they could be led off from is in the way
/datum/unit_test/voidcrew_stealth_live/police/crowd/blocking_lead_tile

/datum/unit_test/voidcrew_stealth_live/police/crowd/blocking_lead_tile/Run()
	TEST_ASSERT(police_room(9, 7), "No room for the test")
	open_place()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = squad_officer(4, 4, SOUTH)
	var/datum/outpost_police_case/case = arrest_at(4, 3)
	if(!case)
		return
	// The booth: rails along the north of three tiles, a wall of tables round the rest
	for(var/dx in 3 to 5)
		var/obj/structure/railing/rail = allocate(/obj/structure/railing, at(dx, 3))
		rail.setDir(NORTH)
	for(var/dx in 3 to 5)
		allocate(/obj/structure/table, at(dx, 2))
	allocate(/obj/structure/table, at(3, 3))
	cuffed_for_the_walk(case)
	police.desk_turf = at(1, 6)
	officer.start_pulling(suspect)
	var/mob/living/carbon/human/blocker = visitor_at(5, 3)
	blocker.set_combat_mode(TRUE)
	case.step_escort()
	case.check_blocking(officer, suspect)
	var/list/entry = LAZYACCESS(case.blockers, WEAKREF(blocker.mind))
	TEST_ASSERT_NOTNULL(entry, "A player on the only tile the prisoner can be led off from is not in the arrest's way")
	police.close_case(suspect.mind)

/**
 * A shove from someone else is not the suspect's own step: standing still as told and shoved, they have not walked off,
 * for the arrest or for the officers holding their fire. Their own step still counts.
 */
/datum/unit_test/voidcrew_stealth_live/police/crowd/shove_not_a_step

/datum/unit_test/voidcrew_stealth_live/police/crowd/shove_not_a_step/Run()
	TEST_ASSERT(police_room(12, 7), "No room for the test")
	open_place()
	squad_officer(1, 5, EAST)
	var/datum/outpost_police_case/case = arrest_at(5, 3, 40)
	if(!case)
		return
	var/mob/living/carbon/human/griefer = visitor_at(4, 3)
	case.set_step("order")
	case.step_order()
	TEST_ASSERT(case.order_at, "Fixture: the order was not given")
	TEST_ASSERT(police.gives_up(suspect), "Fixture: someone standing still is not giving up")

	// Shoved east twice, as tg's disarm does it: the signal, then an ordinary move
	for(var/dx in 6 to 7)
		SEND_SIGNAL(suspect, COMSIG_LIVING_DISARM_HIT, griefer, BODY_ZONE_CHEST, null)
		TEST_ASSERT(suspect.Move(at(dx, 3), EAST), "Fixture: the shove did not move the suspect")
		police.gives_up(suspect)
	TEST_ASSERT(!case.suspect_moved, "A shove from someone else was counted as the suspect walking off")
	TEST_ASSERT(police.gives_up(suspect), "Shoved two tiles, the suspect was taken for walking off by the officers holding their fire")

	// Their own steps still count
	sleep(1.1 SECONDS)
	suspect.Move(at(8, 3), EAST)
	suspect.Move(at(9, 3), EAST)
	TEST_ASSERT(case.suspect_moved, "The suspect's own step after the order was not counted")
	TEST_ASSERT(!police.gives_up(suspect), "Two tiles of their own were not walking off")
	police.close_case(suspect.mind)

/**
 * The cover walking up to take hold of a suspect in cuffs is about the arrest's work too: a player it walks into is
 * told to make way, by the cover, and charged with resisting if they stay. Walked into while the cover only follows
 * its partner about, nobody is in the arrest's way.
 */
/datum/unit_test/voidcrew_stealth_live/police/crowd/blocking_cover

/datum/unit_test/voidcrew_stealth_live/police/crowd/blocking_cover/Run()
	TEST_ASSERT(police_room(9, 7), "No room for the test")
	open_place()
	squad_officer(4, 5, SOUTH)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/second = squad_officer(1, 1, EAST)
	var/datum/outpost_police_case/case = arrest_at(4, 2)
	if(!case)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = case.arresting()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/cover_officer = case.cover()
	if(!cover_officer)
		cover_officer = (officer == second) ? null : second
		if(cover_officer)
			case.take_officer(cover_officer)
			case.officers += WEAKREF(cover_officer)
	TEST_ASSERT(officer && cover_officer && cover_officer != officer, "Fixture: the arrest has no arresting officer and cover")
	officer.bump_blocker = null
	var/mob/living/carbon/human/blocker = visitor_at(2, 2)
	blocker.set_combat_mode(TRUE)

	// Walked into by the cover on its way to take hold of them: told first, nothing more
	case.cover_hold_walk_at = world.time
	cover_officer.bump_blocker = WEAKREF(blocker)
	cover_officer.bump_last = world.time
	case.check_blocking(officer, suspect)
	var/list/entry = LAZYACCESS(case.blockers, WEAKREF(blocker.mind))
	TEST_ASSERT_NOTNULL(entry, "A player the cover walked into on its way to take hold of the suspect is not seen as in the arrest's way")
	TEST_ASSERT(entry && entry[1], "A player in the cover's way was not told to make way")
	TEST_ASSERT_NULL(police.get_warrant(blocker.mind), "A player in the cover's way was charged with no time to step aside")
	// Still there a few seconds after the warning: resisting
	entry[1] = world.time - 5 SECONDS
	case.cover_hold_walk_at = world.time
	cover_officer.bump_last = world.time
	case.check_blocking(officer, suspect)
	var/datum/outpost_warrant/blocker_warrant = police.get_warrant(blocker.mind)
	TEST_ASSERT(blocker_warrant?.heat > 0 || length(police.pending_reports), "A player who stayed in the cover's way after being told was not charged")

	// The cover only following its partner about: whoever it walks into is not in the arrest's way
	var/mob/living/carbon/human/bystander = visitor_at(6, 2)
	bystander.set_combat_mode(TRUE)
	case.cover_hold_walk_at = world.time - 10 SECONDS
	cover_officer.bump_blocker = WEAKREF(bystander)
	cover_officer.bump_last = world.time
	case.check_blocking(officer, suspect)
	TEST_ASSERT_NULL(LAZYACCESS(case.blockers, WEAKREF(bystander.mind)), "Someone the cover walked into while only following its partner was counted as in the arrest's way")
	police.close_case(suspect.mind)
