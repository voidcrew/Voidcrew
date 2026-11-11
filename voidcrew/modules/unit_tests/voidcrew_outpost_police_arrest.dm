/**
 * Outpost police tests: police_arrest.dm (voidcrew/modules/outpost_police/). Owner: P5.
 * Helpers are in voidcrew_outpost_police_helpers.dm. Fork defines are included after the tests: use
 * literal values with a comment naming the define.
 *
 * Each test puts an officer and a suspect side by side at a loaded outpost, pins the suspect's heat, opens
 * the case and calls its step procs directly. The police tick is stopped so the steps run only when the test
 * calls them. Actions (cuffing, the search, the desk, booking) run in the background: the test waits for them.
 * Case steps are the strings in police_arrest.dm: "respond", "order", "subdue", "cuff", "search", "escort",
 * "desk", "book", "standby".
 */

/// Heat for one star and for three (OUTPOST_POLICE_STAR_HEAT: 10, 25, 50, ...)
#define POLICE_ARREST_TEST_HEAT_1 12
#define POLICE_ARREST_TEST_HEAT_3 55

/// An open floor tile next to `thing` (a cardinal step) at the same outpost, or null
/datum/unit_test/proc/police_arrest_beside(atom/thing)
	var/turf/origin = get_turf(thing)
	for(var/dir in GLOB.cardinals)
		var/turf/open/spot = get_step(origin, dir)
		if(istype(spot) && !spot.is_blocked_turf(TRUE) && get_trader_outpost_for_turf(spot) == get_trader_outpost_for_turf(origin))
			return spot
	return null

/// A person with a mind on `where`
/datum/unit_test/proc/police_arrest_person(turf/where)
	var/mob/living/carbon/human/person = allocate(/mob/living/carbon/human/consistent, where)
	person.mind_initialize()
	return person

/// Cuffs and a loaded baton for `officer`, if their kit has none
/datum/unit_test/proc/police_arrest_kit(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(!officer.get_cuffs())
		officer.put_in_hands(allocate(/obj/item/restraints/handcuffs/outpost_police))
	if(!officer.get_baton())
		officer.put_in_hands(allocate(/obj/item/melee/baton/security/loaded))

/**
 * A new officer with their kit and a suspect beside them, the suspect pinned at `heat`, the case open and the
 * police tick stopped. Returns list(officer, suspect, case), or null (and the test has failed).
 */
/datum/unit_test/proc/police_arrest_setup(obj/structure/overmap/trader_outpost/outpost, heat = POLICE_ARREST_TEST_HEAT_1)
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost)
	if(!officer)
		TEST_FAIL("No officer could be built")
		return null
	police_arrest_kit(officer)
	var/turf/beside = police_arrest_beside(officer)
	if(!beside)
		TEST_FAIL("No floor beside the officer at [AREACOORD(officer)]")
		return null
	var/mob/living/carbon/human/suspect = police_arrest_person(beside)
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, heat)
	var/datum/outpost_police_case/case = police.open_case(warrant)
	police.sleep_tick()
	if(!case)
		TEST_FAIL("No case opened on a suspect at [heat] heat")
		return null
	if(case.arresting() != officer)
		TEST_FAIL("The officer beside the suspect is not the arresting officer ([case.arresting()])")
		return null
	return list(officer, suspect, case)

/// Waits for the case's action to end, `limit` at most
/datum/unit_test/proc/police_arrest_wait(datum/outpost_police_case/case, limit = 15 SECONDS)
	var/until = world.time + limit
	while(!QDELETED(case) && case.acting && world.time < until)
		sleep(1)

/// Ordered, the suspect stands still with empty hands: cuffed with no baton swung, in a pair of used police cuffs
/datum/unit_test/voidcrew_outpost_police_arrest_comply

/datum/unit_test/voidcrew_outpost_police_arrest_comply/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/list/parts = police_arrest_setup(outpost)
	if(!parts)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = parts[1]
	var/mob/living/carbon/human/suspect = parts[2]
	var/datum/outpost_police_case/case = parts[3]

	case.step_respond()
	TEST_ASSERT_EQUAL(case.step, "order", "An officer beside the suspect did not go on to the order")
	case.step_order()
	TEST_ASSERT(case.order_at, "The order step gave no order")
	TEST_ASSERT_EQUAL(case.step, "order", "The order step did not wait for the suspect to comply")
	case.order_at = world.time - 10 SECONDS
	case.step_order()
	TEST_ASSERT_EQUAL(case.step, "cuff", "A suspect who stood still with empty hands did not go to the cuffs")

	case.step_cuff()
	police_arrest_wait(case)
	TEST_ASSERT(suspect.handcuffed, "The cuff step put no cuffs on a still suspect")
	TEST_ASSERT(istype(suspect.handcuffed, /obj/item/restraints/handcuffs/outpost_police/used), "The suspect wears [suspect.handcuffed.type], not used police cuffs")
	TEST_ASSERT_EQUAL(case.strikes, 0, "A compliant suspect was struck")
	TEST_ASSERT_EQUAL(suspect.getStaminaLoss(), 0, "A compliant suspect took stamina damage")
	TEST_ASSERT_EQUAL(case.step, "search", "After the cuffs the case is on [case.step], not the search")
	TEST_ASSERT(officer.get_cuffs(), "The officer has no cuffs left after cuffing someone")

	// A second suspect, on the floor: cuffed where they lie
	var/list/more = police_arrest_setup(outpost)
	if(!more)
		return
	var/mob/living/carbon/human/downed = more[2]
	var/datum/outpost_police_case/second = more[3]
	downed.Knockdown(20 SECONDS)
	second.set_step("cuff")
	second.step_cuff()
	police_arrest_wait(second)
	TEST_ASSERT(istype(downed.handcuffed, /obj/item/restraints/handcuffs/outpost_police/used), "A suspect on the floor was not put in used police cuffs ([downed.handcuffed?.type])")

/// Ordered, the suspect fights on: the subdue step lands a real baton blow that costs stamina
/datum/unit_test/voidcrew_outpost_police_arrest_subdue

/datum/unit_test/voidcrew_outpost_police_arrest_subdue/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/list/parts = police_arrest_setup(outpost)
	if(!parts)
		return
	var/mob/living/carbon/human/suspect = parts[2]
	var/datum/outpost_police_case/case = parts[3]

	suspect.set_combat_mode(TRUE)
	case.set_step("order")
	case.step_order()
	case.order_at = world.time - 10 SECONDS
	case.step_order()
	TEST_ASSERT_EQUAL(case.step, "subdue", "A suspect in combat mode was not to be subdued")
	case.step_subdue()
	sleep(1)
	TEST_ASSERT(case.strikes >= 1, "The subdue step threw no blow at a suspect beside the officer")
	TEST_ASSERT(suspect.getStaminaLoss() > 0, "The baton blow did no stamina damage")
	TEST_ASSERT(!suspect.handcuffed, "The subdue step cuffed someone")

/// The search calls confiscate() once and the case waits for it; the desk deals with the evidence before booking
/datum/unit_test/voidcrew_outpost_police_arrest_search

/datum/unit_test/voidcrew_outpost_police_arrest_search/Run()
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

	// The crime tool, in their hand and on the warrant (the cuffs make them drop it beside them)
	var/obj/item/storage/toolbox/weapon = allocate(/obj/item/storage/toolbox)
	suspect.put_in_hands(weapon)
	var/datum/outpost_warrant/warrant = police.warrants[suspect.mind]
	LAZYADD(warrant.evidence, WEAKREF(weapon))

	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	suspect.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	case.step_cuff()
	TEST_ASSERT_EQUAL(case.step, "search", "Cuffs on did not lead to the search")

	case.step_search()
	if(case.acting)
		case.process_case()
		TEST_ASSERT_EQUAL(case.step, "search", "The case moved on while the search was still going")
	police_arrest_wait(case, 20 SECONDS)
	TEST_ASSERT_EQUAL(case.search_calls, 1, "The search called confiscate() [case.search_calls] times")
	TEST_ASSERT_EQUAL(case.step, "escort", "After the search the case is on [case.step], not the escort")
	case.set_step("search")
	case.step_search()
	police_arrest_wait(case)
	TEST_ASSERT_EQUAL(case.search_calls, 1, "A second search step searched again")

	// Booking before the desk is refused
	police.desk_turf = get_turf(officer)
	case.set_step("book")
	case.step_book()
	TEST_ASSERT_EQUAL(case.step, "desk", "The case went to book before the evidence was dealt with")
	TEST_ASSERT(!case.booked_at, "The case booked before the desk")
	case.step_desk()
	police_arrest_wait(case)
	TEST_ASSERT(case.disposed_at, "The desk step did not deal with the evidence")
	TEST_ASSERT(!case.booked_at, "The desk booked the suspect")
	case.set_step("book")
	case.step_book()
	police_arrest_wait(case, 40 SECONDS)
	TEST_ASSERT(case.booked_at >= case.disposed_at, "Booking came before the evidence")
	TEST_ASSERT(QDELETED(case), "The case did not close after booking")
	TEST_ASSERT(!police.cases[suspect.mind], "A booked suspect still has an open case")

/// A suspect in crit is left alone and the case closes after the wait; one who dies after the search still sends the officer to the desk
/datum/unit_test/voidcrew_outpost_police_arrest_downed

/datum/unit_test/voidcrew_outpost_police_arrest_downed/Run()
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

	suspect.adjustOxyLoss(120)
	suspect.updatehealth()
	TEST_ASSERT(HAS_TRAIT(suspect, TRAIT_CRITICAL_CONDITION), "The suspect is not in crit (stat [suspect.stat], health [suspect.health])")
	var/stamina_before = suspect.getStaminaLoss()
	var/oxy_before = suspect.getOxyLoss()
	var/turf/lay_turf = get_turf(suspect)
	case.process_case()
	TEST_ASSERT_EQUAL(case.step, "standby", "A suspect in crit before the cuffs did not stop the arrest")
	case.process_case()
	TEST_ASSERT(officer.pulling != suspect, "An officer took hold of a suspect in crit")
	TEST_ASSERT_EQUAL(get_turf(suspect), lay_turf, "A suspect in crit was moved")
	TEST_ASSERT_EQUAL(suspect.getStaminaLoss(), stamina_before, "A suspect in crit was struck")
	TEST_ASSERT(suspect.getOxyLoss() >= oxy_before - 5, "A suspect in crit was healed")
	TEST_ASSERT(!suspect.handcuffed, "A suspect in crit was cuffed")
	case.downed_since = world.time - 46 SECONDS // OUTPOST_POLICE_CRIT_WAIT is 45 s
	case.process_case()
	TEST_ASSERT(QDELETED(case), "The case did not close after standing by a suspect in crit")
	TEST_ASSERT(!police.cases[suspect.mind], "The suspect in crit still has a case")
	TEST_ASSERT(!officer.case, "The officer is still on a closed case")
	TEST_ASSERT_NULL(police.open_case(police.warrants[suspect.mind]), "A case opened on a suspect still in crit")

	// Cuffed, searched, then dead: no more escort, but the evidence still goes to the desk
	var/list/more = police_arrest_setup(outpost)
	if(!more)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/second_officer = more[1]
	var/mob/living/carbon/human/dead = more[2]
	var/datum/outpost_police_case/second = more[3]
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	dead.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	second.cuffs_on(dead)
	second.searched = TRUE
	var/obj/item/outpost_sealed_case/evidence/evidence = allocate(/obj/item/outpost_sealed_case/evidence)
	second_officer.put_in_hands(evidence)
	second.evidence_ref = WEAKREF(evidence)
	second.set_step("escort")
	police.desk_turf = get_turf(second_officer)
	dead.death()
	second.process_case()
	TEST_ASSERT(second.suspect_lost, "A suspect who died after the search is not given up")
	TEST_ASSERT(second_officer.pulling != dead, "The officer still pulls a body")
	for(var/i in 1 to 4)
		if(QDELETED(second))
			break
		second.process_case()
		police_arrest_wait(second)
	TEST_ASSERT(second.disposed_at, "The desk step never ran for a suspect who died after the search")
	TEST_ASSERT(QDELETED(second), "The case of a suspect who died after the search did not close at the desk")

/// Someone pulling the suspect away from the arrest is reported for resisting
/datum/unit_test/voidcrew_outpost_police_arrest_interference

/datum/unit_test/voidcrew_outpost_police_arrest_interference/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/list/parts = police_arrest_setup(outpost)
	if(!parts)
		return
	var/mob/living/carbon/human/suspect = parts[2]
	var/datum/outpost_police_case/case = parts[3]

	var/turf/beside = police_arrest_beside(suspect)
	TEST_ASSERT_NOTNULL(beside, "No floor beside the suspect")
	var/mob/living/carbon/human/friend = police_arrest_person(beside)
	case.set_step("order")
	case.order_at = world.time
	friend.start_pulling(suspect)
	TEST_ASSERT_EQUAL(suspect.pulledby, friend, "The friend could not take hold of the suspect")
	case.process_case()
	TEST_ASSERT(LAZYACCESS(case.resist_reports, friend.mind), "A friend pulling the suspect was not reported")
	TEST_ASSERT(!LAZYACCESS(case.resist_reports, suspect.mind), "The suspect was reported for being pulled")

/// A stuck step goes back to the start; the third time the case closes; at three stars the arrest is called off unless the cuffs are on
/datum/unit_test/voidcrew_outpost_police_arrest_timeouts

/datum/unit_test/voidcrew_outpost_police_arrest_timeouts/Run()
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

	case.set_step("subdue")
	case.step_started_at = world.time - 61 SECONDS // OUTPOST_POLICE_STEP_TIMEOUT is 60 s
	case.process_case()
	TEST_ASSERT_EQUAL(case.step, "respond", "A timed-out step did not go back to respond")
	TEST_ASSERT_EQUAL(case.resets, 1, "A timed-out step was not counted")

	case.resets = 2
	case.set_step("subdue")
	case.step_started_at = world.time - 61 SECONDS
	case.process_case()
	TEST_ASSERT(QDELETED(case), "The third timeout did not close the case")
	TEST_ASSERT_NULL(police.open_case(police.warrants[suspect.mind]), "A case reopened at once after three timeouts")
	TEST_ASSERT(!officer.case, "The officer is still on the timed-out case")

	// Three stars on a suspect not yet in cuffs: the arrest is called off
	var/list/more = police_arrest_setup(outpost)
	if(!more)
		return
	var/mob/living/carbon/human/wanted = more[2]
	var/datum/outpost_police_case/second = more[3]
	var/datum/outpost_warrant/warrant = police.warrants[wanted.mind]
	warrant.heat = POLICE_ARREST_TEST_HEAT_3
	police.tick_cases()
	TEST_ASSERT(QDELETED(second), "A case stayed open on a three-star suspect")
	TEST_ASSERT_NULL(police.open_case(warrant), "A case opened on a three-star suspect")

	// Already in cuffs at three stars: the arrest carries on
	warrant.heat = POLICE_ARREST_TEST_HEAT_1
	var/datum/outpost_police_case/third = police.open_case(warrant)
	police.sleep_tick()
	TEST_ASSERT_NOTNULL(third, "No case opened on the suspect at one star again")
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	wanted.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	third.cuffs_on(wanted)
	warrant.heat = POLICE_ARREST_TEST_HEAT_3
	police.tick_cases()
	TEST_ASSERT(!QDELETED(third), "A cuffed suspect's arrest was called off at three stars")

#undef POLICE_ARREST_TEST_HEAT_1
#undef POLICE_ARREST_TEST_HEAT_3

// ===== CROSS-PACKAGE: FROM THE CRIME TO THE CELL =====

/// Stands in for a walk: `officer` onto `target` (or beside it), the suspect they pull beside them, the pull taken up again
/datum/unit_test/proc/police_jail_carry(mob/living/officer, mob/living/carbon/suspect, turf/target)
	officer.stop_pulling()
	var/turf/stand = (isopenturf(target) && !target.is_blocked_turf(TRUE)) ? target : police_arrest_beside(target)
	if(!stand)
		TEST_FAIL("Nowhere to stand at [AREACOORD(target)]")
		return
	officer.forceMove(stand)
	var/turf/behind = police_arrest_beside(officer)
	if(!behind)
		TEST_FAIL("No floor beside the officer at [AREACOORD(officer)]")
		return
	suspect.forceMove(behind)
	officer.start_pulling(suspect)

/// A punch, by tg's own unarmed attack
/datum/unit_test/proc/police_jail_punch(mob/living/carbon/human/attacker, mob/living/carbon/human/victim, unused)
	victim.attack_hand(attacker, list(RIGHT_CLICK = FALSE))

/// A stab with `weapon`, by tg's own melee chain
/datum/unit_test/proc/police_jail_stab(mob/living/carbon/human/attacker, mob/living/carbon/human/victim, obj/item/weapon)
	attacker.next_move = 0
	weapon.melee_attack_chain(attacker, victim)

/**
 * `suspect` does `attack` (list(proc on this test taking the offender, the victim and an argument; the argument))
 * to `victim` twice in front of a new beat officer at `outpost`, gives up, and the arrest is walked step by step:
 * dispatch opens it, then the order, the cuffs, the search, the desk and the cell. Walks are stood in for by
 * police_jail_carry(); every other step is the police's own code, stepped by hand. Returns the cell they were
 * booked into, or null (and the test has failed).
 */
/datum/unit_test/proc/police_jail_run(obj/structure/overmap/trader_outpost/outpost, mob/living/carbon/human/suspect, mob/living/carbon/human/victim, list/attack)
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/witness = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, police_arrest_beside(suspect))
	police_arrest_kit(witness)
	// A second officer, so dispatch has two to spare for one arrest
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/cover = police_officer(outpost)
	police_arrest_kit(cover)

	// The crime, twice, more than half a second apart (OUTPOST_AGGRESSION_GRACE folds hits closer than that)
	suspect.set_combat_mode(TRUE)
	for(var/blow in 1 to 2)
		call(src, attack[1])(suspect, victim, attack[2])
		police.sleep_tick()
		sleep(0.6 SECONDS)
	police.sleep_tick()
	var/stars = police.get_stars(suspect.mind)
	if(stars != 1)
		TEST_FAIL("[outpost.type]: two blows in front of an officer gave [stars] stars, not one (heat [police.warrants[suspect.mind]?.heat])")
		return null
	// They give up: fists down, hands empty
	suspect.set_combat_mode(FALSE)
	suspect.drop_all_held_items()

	// A player is on the concourse (here, the suspect): nobody holds still (no client in a test, so the ambient
	// tick would pause them again; this stands in for it just before dispatch looks for officers)
	SSambient_npcs.wake_outpost(SSambient_npcs.outpost_place(outpost))
	police.dispatch_open_cases()
	police.sleep_tick()
	var/datum/outpost_police_case/case = police.cases[suspect.mind]
	if(!case)
		TEST_FAIL("[outpost.type]: dispatch opened no arrest on a one-star suspect")
		return null
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = case.arresting()
	if(!officer)
		TEST_FAIL("[outpost.type]: the arrest has no officer")
		return null
	police_arrest_kit(officer)
	if(!officer.Adjacent(suspect))
		officer.forceMove(police_arrest_beside(suspect))

	case.step_respond()
	TEST_ASSERT_EQUAL(case.step, "order", "[outpost.type]: the officer beside the suspect did not give the order")
	case.step_order()
	case.order_at = world.time - 10 SECONDS
	case.step_order()
	TEST_ASSERT_EQUAL(case.step, "cuff", "[outpost.type]: a suspect who gave up was not to be cuffed")
	case.step_cuff()
	police_arrest_wait(case)
	TEST_ASSERT(istype(suspect.handcuffed, /obj/item/restraints/handcuffs/outpost_police), "[outpost.type]: the suspect wears [suspect.handcuffed?.type || "no cuffs"], not police cuffs")
	TEST_ASSERT_EQUAL(case.step, "search", "[outpost.type]: after the cuffs the arrest is on [case.step]")
	case.step_search()
	police_arrest_wait(case, 20 SECONDS)
	TEST_ASSERT_EQUAL(case.step, "escort", "[outpost.type]: after the search the arrest is on [case.step]")

	// The walk to the desk
	TEST_ASSERT_NOTNULL(police.desk_turf, "[outpost.type] has no desk")
	case.step_escort()
	TEST_ASSERT_EQUAL(officer.pulling, suspect, "[outpost.type]: the officer did not take the suspect along")
	police_jail_carry(officer, suspect, police.desk_turf)
	case.step_escort()
	TEST_ASSERT_EQUAL(case.step, "desk", "[outpost.type]: at the desk the arrest is on [case.step]")
	case.step_desk()
	police_arrest_wait(case)
	TEST_ASSERT(case.disposed_at, "[outpost.type]: the desk did not deal with the evidence")

	// The walk to the cell door
	var/datum/outpost_police_cell/cell = police.cell_best()
	TEST_ASSERT_NOTNULL(cell, "[outpost.type] has no cell to book into")
	case.step_desk()
	police_jail_carry(officer, suspect, cell.outside_turf)
	case.step_desk()
	TEST_ASSERT_EQUAL(case.step, "book", "[outpost.type]: at the cell door the arrest is on [case.step]")
	case.step_book()
	police_arrest_wait(case, 40 SECONDS)
	TEST_ASSERT(QDELETED(case), "[outpost.type]: the arrest did not end at the cell")
	TEST_ASSERT(suspect.mind in cell.prisoners, "[outpost.type]: the suspect is not held in the cell")
	TEST_ASSERT(get_turf(suspect) in cell.tiles, "[outpost.type]: the suspect is not inside the cell")
	TEST_ASSERT_NULL(suspect.handcuffed, "[outpost.type]: the prisoner is still cuffed in the cell")
	return cell

/**
 * At each of the three outposts: a player who punches twice in front of a beat officer gets one star, is ordered,
 * cuffed, walked to the desk and the cell and fined from their ship. The same with the ship account empty ends
 * in the prison jumpsuit with their gear in a property locker they can open. A player who stabs twice loses the
 * knife down the evidence chute.
 */
/datum/unit_test/voidcrew_outpost_police_arrest_to_jail
	var/saved_scale

/datum/unit_test/voidcrew_outpost_police_arrest_to_jail/Destroy()
	if(!isnull(saved_scale))
		GLOB.outpost_police_property_time_scale = saved_scale
	return ..()

/datum/unit_test/voidcrew_outpost_police_arrest_to_jail/Run()
	saved_scale = GLOB.outpost_police_property_time_scale
	GLOB.outpost_police_property_time_scale = 0.01
	var/list/ships = list()
	for(var/outpost_type in list(
		/obj/structure/overmap/trader_outpost/general,
		/obj/structure/overmap/trader_outpost/outfitter,
		/obj/structure/overmap/trader_outpost/black_market,
	))
		var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(outpost_type)
		if(!outpost)
			continue
		var/datum/outpost_police/police = outpost.police

		// Fined: the money comes off the ship and they keep their clothes
		var/mob/living/carbon/human/payer = police_arrest_person(police_floor(outpost))
		ADD_TRAIT(payer, TRAIT_PERFECT_ATTACKER, INNATE_TRAIT)
		var/obj/item/clothing/under/own_suit = allocate(/obj/item/clothing/under/color/grey)
		payer.equip_to_slot_if_possible(own_suit, ITEM_SLOT_ICLOTHING, disable_warning = TRUE)
		var/obj/structure/overmap/ship/rich = wanted_ship(payer, 5000)
		ships += rich
		var/mob/living/carbon/human/victim = police_arrest_person(police_arrest_beside(payer))
		var/datum/outpost_police_cell/cell = police_jail_run(outpost, payer, victim, list(PROC_REF(police_jail_punch), null))
		if(!cell)
			continue
		var/datum/outpost_warrant/paid_warrant = police.warrants[payer.mind]
		var/fine = paid_warrant?.fine_level ? police.fine_amount(paid_warrant) : 5000 - rich.ship_account.account_balance
		TEST_ASSERT(fine > 0, "[outpost_type]: no fine was charged ([fine])")
		TEST_ASSERT_EQUAL(rich.ship_account.account_balance, 5000 - fine, "[outpost_type]: the ship paid [5000 - rich.ship_account.account_balance], not the fine of [fine]")
		TEST_ASSERT(!cell.jailed[payer.mind], "[outpost_type]: a prisoner who paid was jailed")
		TEST_ASSERT_EQUAL(payer.w_uniform, own_suit, "[outpost_type]: a prisoner who paid lost their clothes")

		// Not fined: the prison jumpsuit, and their gear in a locker they can open
		var/mob/living/carbon/human/broke = police_arrest_person(police_floor(outpost))
		ADD_TRAIT(broke, TRAIT_PERFECT_ATTACKER, INNATE_TRAIT)
		var/obj/item/clothing/under/broke_suit = allocate(/obj/item/clothing/under/color/grey)
		broke.equip_to_slot_if_possible(broke_suit, ITEM_SLOT_ICLOTHING, disable_warning = TRUE)
		var/obj/item/crowbar/pocketed = allocate(/obj/item/crowbar)
		broke.equip_to_slot_if_possible(pocketed, ITEM_SLOT_LPOCKET, disable_warning = TRUE)
		var/obj/structure/overmap/ship/empty = wanted_ship(broke, 0)
		ships += empty
		var/mob/living/carbon/human/second_victim = police_arrest_person(police_arrest_beside(broke))
		cell = police_jail_run(outpost, broke, second_victim, list(PROC_REF(police_jail_punch), null))
		if(!cell)
			continue
		TEST_ASSERT(cell.jailed[broke.mind], "[outpost_type]: a prisoner whose ship could not pay was not jailed")
		TEST_ASSERT(istype(broke.w_uniform, /obj/item/clothing/under/rank/prisoner/outpost_police), "[outpost_type]: a jailed prisoner wears [broke.w_uniform?.type || "nothing"], not the prison jumpsuit")
		var/obj/structure/closet/secure_closet/personal/outpost_police/locker = police.property_locker_for(broke)
		TEST_ASSERT_NOTNULL(locker, "[outpost_type]: a jailed prisoner has no property locker")
		TEST_ASSERT(broke_suit in locker.contents, "[outpost_type]: the prisoner's own jumpsuit is not in their locker")
		TEST_ASSERT(pocketed in locker.contents, "[outpost_type]: what was in the prisoner's pocket is not in their locker")
		TEST_ASSERT(locker.locked, "[outpost_type]: a property locker was left open")
		locker.togglelock(broke)
		TEST_ASSERT(!locker.locked, "[outpost_type]: the prisoner could not open their own property locker")
		locker.lock()

		// The knife: dropped when they give up, taken off the floor at the search, gone down the chute at the desk
		var/mob/living/carbon/human/stabber = police_arrest_person(police_floor(outpost))
		ADD_TRAIT(stabber, TRAIT_PERFECT_ATTACKER, INNATE_TRAIT)
		ships += wanted_ship(stabber, 5000)
		var/obj/item/knife/kitchen/knife = allocate(/obj/item/knife/kitchen)
		stabber.put_in_active_hand(knife, forced = TRUE)
		var/mob/living/carbon/human/third_victim = police_arrest_person(police_arrest_beside(stabber))
		cell = police_jail_run(outpost, stabber, third_victim, list(PROC_REF(police_jail_stab), knife))
		if(!cell)
			continue
		TEST_ASSERT(QDELETED(knife), "[outpost_type]: the knife was not destroyed in the evidence chute (it is at [knife.loc ? AREACOORD(knife) : "nowhere"])")
	wanted_cleanup(ships)
