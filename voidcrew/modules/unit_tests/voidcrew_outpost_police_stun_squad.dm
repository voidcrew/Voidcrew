/**
 * Outpost police tests: the mixed squad at three stars and up (owner decision 37). Stun officers take a downed
 * suspect alive to a cell with no fine; lethal officers hold fire on anyone in custody; a breakout makes the
 * suspect fair game again; whoever says a suspect is down sees the arrest through; the extra units go home.
 * Helpers are in voidcrew_outpost_police_helpers.dm and voidcrew_outpost_police_arrest.dm. Fork defines are
 * included after the tests: literal values, with the define named.
 *
 * Heat: 55 is three stars, 100 four, 150 five (OUTPOST_POLICE_STAR_HEAT 10, 25, 50, 90, 140).
 * Roles: "stun" and "lethal" (POLICE_ROLE_*). Force: 2 STUN, 3 LETHAL (POLICE_FORCE_*).
 */

/// Takes every officer the outpost came with off its roster, so the test counts only its own
/datum/unit_test/proc/stun_squad_isolate(datum/outpost_police/police)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in police.officers.Copy())
		police.remove_officer(officer)

/// `count` new response officers on `outpost`'s roster, each with cuffs and a baton
/datum/unit_test/proc/stun_squad_officers(obj/structure/overmap/trader_outpost/outpost, count, officer_type = /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	. = list()
	for(var/i in 1 to count)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, officer_type)
		police_arrest_kit(officer)
		. += officer

/// An open arrest on `suspect` that has them in hand, as if its cuffs just went on (no officer staffed); in_custody() reads it
/datum/unit_test/proc/stun_squad_holding(datum/outpost_police/police, mob/living/carbon/suspect)
	var/datum/outpost_police_case/case = new(police, police.warrants[suspect.mind])
	police.cases[suspect.mind] = case
	case.cuffed = TRUE
	return case

/// How many of `officers` have `role`
/datum/unit_test/proc/stun_squad_count(list/officers, role)
	. = 0
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in officers)
		if(officer.police_role == role)
			.++

/// Roles by the star mix: half at three stars, a quarter at five, never a long gun; cleared below three
/datum/unit_test/voidcrew_outpost_police_stun_squad_roles

/datum/unit_test/voidcrew_outpost_police_stun_squad_roles/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	police.sleep_tick()
	stun_squad_isolate(police)
	var/mob/living/carbon/human/suspect = police_arrest_person(police_floor(outpost))
	police_pin_warrant(police, suspect.mind, 55) // three stars
	var/list/squad = stun_squad_officers(outpost, 4)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in squad)
		police.role_of(officer)
	TEST_ASSERT_EQUAL(stun_squad_count(squad, "stun"), 2, "At three stars a squad of four has [stun_squad_count(squad, "stun")] stun officers, not two")
	TEST_ASSERT_EQUAL(stun_squad_count(squad, "lethal"), 2, "At three stars a squad of four has [stun_squad_count(squad, "lethal")] lethal officers, not two")
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in squad)
		var/expected = officer.police_role == "stun" ? 2 : 3 // POLICE_FORCE_STUN, POLICE_FORCE_LETHAL
		TEST_ASSERT_EQUAL(officer.force_for(suspect), expected, "A [officer.police_role] officer goes at a three-star suspect with force [officer.force_for(suspect)]")
		TEST_ASSERT(officer.police_will_fight(suspect), "A [officer.police_role] officer will not stop a three-star suspect on their feet")

	// A tactical officer's long gun is never a stun officer's
	var/list/tactical = stun_squad_officers(outpost, 1, /mob/living/carbon/human/npc/ambient_npc/outpost/police/tactical)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/gunner = tactical[1]
	TEST_ASSERT_NOTNULL(gunner.get_longgun(), "The tactical officer has no long gun")
	TEST_ASSERT_EQUAL(police.role_of(gunner), "lethal", "A tactical officer with a long gun was given stun duty")

	// Below three stars the roles go
	police_pin_warrant(police, suspect.mind, 30) // two stars
	police.dispatch_next_wave = world.time + 1 MINUTES
	police.dispatch_respond(police.alert_level())
	TEST_ASSERT_EQUAL(stun_squad_count(squad, "stun") + stun_squad_count(squad, "lethal"), 0, "Roles stayed on at two stars")

	// Five stars: a quarter, and at least one in a squad of two or more
	police_pin_warrant(police, suspect.mind, 150) // five stars
	gunner.police_role = null
	police.remove_officer(gunner)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in squad)
		police.role_of(officer)
	TEST_ASSERT_EQUAL(stun_squad_count(squad, "stun"), 1, "At five stars a squad of four has [stun_squad_count(squad, "stun")] stun officers, not one")
	police_pin_warrant(police, suspect.mind, 0)
	dispatch_clear(police)

/**
 * A stun officer takes a three-star suspect in stamina crit alive: cuffed where they lie, then booked straight into
 * jail with no fine, their crew's money untouched, a ten-minute sentence and no bail.
 */
/datum/unit_test/voidcrew_outpost_police_stun_squad_jail
	var/saved_scale

/datum/unit_test/voidcrew_outpost_police_stun_squad_jail/Destroy()
	if(!isnull(saved_scale))
		GLOB.outpost_police_property_time_scale = saved_scale
	return ..()

/datum/unit_test/voidcrew_outpost_police_stun_squad_jail/Run()
	saved_scale = GLOB.outpost_police_property_time_scale
	GLOB.outpost_police_property_time_scale = 0.01
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	police.sleep_tick()
	stun_squad_isolate(police)
	var/list/squad = stun_squad_officers(outpost, 2)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/lethal = squad[1]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/stunner = squad[2]
	var/mob/living/carbon/human/suspect = police_arrest_person(police_arrest_beside(stunner))
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 55) // three stars
	lethal.police_role = "lethal"
	stunner.police_role = "stun"
	lethal.forceMove(police_floor(outpost))
	var/list/ships = list(wanted_ship(suspect, 5000))
	TEST_ASSERT_NULL(police.open_case(warrant), "A case opened on a three-star suspect on their feet")

	// Disabled into stamina crit: the lethal officer saw it, the stun officer takes it
	suspect.adjustStaminaLoss(200)
	TEST_ASSERT(HAS_TRAIT(suspect, TRAIT_INCAPACITATED), "200 stamina damage did not put the suspect down")
	TEST_ASSERT(!lethal.police_will_fight(suspect), "A lethal officer still fights a three-star suspect in stamina crit")
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = lethal.ai_controller
	brain.stealth_setup()
	brain.stealth_target_downed(suspect)
	police.sleep_tick() // the new case woke it
	var/datum/outpost_police_case/case = police.cases[suspect.mind]
	TEST_ASSERT_NOTNULL(case, "A three-star suspect in stamina crit is not under arrest")
	TEST_ASSERT_EQUAL(case.arresting(), stunner, "The arrest went to [case.arresting()], not the free stun officer")

	for(var/i in 1 to 6)
		if(QDELETED(case) || suspect.handcuffed)
			break
		suspect.adjustStaminaLoss(200) // still down however long the steps take
		case.process_case()
		police_arrest_wait(case)
	TEST_ASSERT(istype(suspect.handcuffed, /obj/item/restraints/handcuffs/outpost_police/used), "The stun officer did not cuff the downed suspect (the case is on [QDELETED(case) ? "nothing" : case.step])")
	TEST_ASSERT(!QDELETED(case), "The arrest of a cuffed three-star suspect ended")
	TEST_ASSERT(police.in_custody(suspect), "A cuffed three-star suspect is not in custody")

	// Straight to the cell (the search and the evidence are the ordinary arrest's)
	var/datum/outpost_police_cell/cell = police.cell_best()
	TEST_ASSERT_NOTNULL(cell, "The outpost has no cell")
	case.searched = TRUE
	case.disposed_at = world.time
	police_jail_carry(stunner, suspect, cell.outside_turf)
	case.set_step("book")
	case.step_book()
	police_arrest_wait(case, 40 SECONDS)
	TEST_ASSERT(QDELETED(case), "The arrest did not end at the cell")
	TEST_ASSERT(get_turf(suspect) in cell.tiles, "The suspect is not in the cell")
	var/obj/structure/overmap/ship/ship = ships[1]
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 5000, "A three-star suspect was fined")
	TEST_ASSERT(cell.jailed[suspect.mind], "A three-star suspect was not jailed")
	var/left = cell.prisoners[suspect.mind] - world.time
	TEST_ASSERT(left > 5900 && left <= 6000, "A three-star sentence is [left / 10] seconds, not ten minutes") // OUTPOST_POLICE_JAIL at three stars
	TEST_ASSERT(cell.bail_due[suspect.mind] > world.time + 1 HOURS, "A three-star prisoner can make bail")
	TEST_ASSERT(police.in_custody(suspect), "A jailed suspect is not in custody")
	cell.forget_prisoner(suspect.mind)
	police.close_warrant(suspect.mind, TRUE)
	wanted_cleanup(ships)
	dispatch_clear(police)

/// Lethal officers hold fire on a three-star suspect in our cuffs or in a cell
/datum/unit_test/voidcrew_outpost_police_stun_squad_hold_fire

/datum/unit_test/voidcrew_outpost_police_stun_squad_hold_fire/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	police.sleep_tick()
	stun_squad_isolate(police)
	var/list/turf/row = dispatch_row(outpost)
	TEST_ASSERT_NOTNULL(row, "No three free tiles in a row on the concourse")
	var/list/squad = stun_squad_officers(outpost, 1)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/lethal = squad[1]
	lethal.forceMove(row[1])
	lethal.police_role = "lethal"
	var/mob/living/carbon/human/suspect = police_arrest_person(row[3])
	police_pin_warrant(police, suspect.mind, 55) // three stars
	TEST_ASSERT(police_plans_shot(lethal, suspect), "A lethal officer plans no shot at a free three-star suspect in view")

	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	suspect.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	// Our cuffs with nobody walking them in: got away from the escort, fair game again (review-1 S5)
	TEST_ASSERT(lethal.police_will_fight(suspect), "A lethal officer will not fight a three-star suspect who got away in our cuffs")
	stun_squad_holding(police, suspect)
	TEST_ASSERT(!lethal.police_will_fight(suspect), "A lethal officer will fight a suspect in our cuffs")
	TEST_ASSERT(!police_plans_shot(lethal, suspect), "A lethal officer plans a shot at a suspect in our cuffs")

	police.close_case(suspect.mind)
	suspect.uncuff()
	var/datum/outpost_police_cell/cell = police.cell_best()
	TEST_ASSERT_NOTNULL(cell, "The outpost has no cell")
	cell.admit(suspect, world.time + 10 MINUTES, TRUE)
	TEST_ASSERT(!lethal.police_will_fight(suspect), "A lethal officer will fight a suspect held in a cell")
	TEST_ASSERT(!police_plans_shot(lethal, suspect), "A lethal officer plans a shot at a suspect held in a cell")
	cell.forget_prisoner(suspect.mind)
	police_pin_warrant(police, suspect.mind, 0)
	dispatch_clear(police)

/// Slipping the cuffs or walking out of the cell at three stars: lethal officers shoot again, stun officers chase
/datum/unit_test/voidcrew_outpost_police_stun_squad_breakout

/datum/unit_test/voidcrew_outpost_police_stun_squad_breakout/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	police.sleep_tick()
	stun_squad_isolate(police)
	var/list/squad = stun_squad_officers(outpost, 2)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/lethal = squad[1]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/stunner = squad[2]
	lethal.police_role = "lethal"
	stunner.police_role = "stun"
	var/mob/living/carbon/human/suspect = police_arrest_person(police_arrest_beside(stunner))
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 55) // three stars
	suspect.Knockdown(20 SECONDS)
	TEST_ASSERT(police.arrest_downed(suspect, stunner), "No arrest on a three-star suspect knocked down")
	var/datum/outpost_police_case/case = police.cases[suspect.mind]
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	suspect.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	case.cuffs_on(suspect)
	TEST_ASSERT(!lethal.police_will_fight(suspect), "A lethal officer will fight a suspect in our cuffs")

	// Out of the cuffs and back on their feet
	var/heat_before = warrant.heat
	suspect.uncuff()
	suspect.SetKnockdown(0)
	suspect.SetParalyzed(0)
	suspect.set_resting(FALSE, instant = TRUE)
	// Two police ticks: the first sees the cuffs gone, the second the suspect on their feet
	case.process_case()
	if(!QDELETED(case))
		case.process_case()
	TEST_ASSERT(warrant.heat > heat_before, "Slipping the cuffs at three stars was not a crime")
	TEST_ASSERT(QDELETED(case) || !police.cases[suspect.mind], "The arrest stayed open on a three-star suspect up and out of the cuffs")
	TEST_ASSERT(lethal.police_will_fight(suspect), "A lethal officer will not fight a suspect who slipped the cuffs")
	TEST_ASSERT_EQUAL(lethal.force_for(suspect), 3, "A lethal officer does not go to kill a suspect who slipped the cuffs") // POLICE_FORCE_LETHAL
	TEST_ASSERT(stunner.police_will_fight(suspect), "A stun officer will not chase a suspect who slipped the cuffs")
	TEST_ASSERT_EQUAL(stunner.force_for(suspect), 2, "A stun officer goes past stun on a suspect who slipped the cuffs") // POLICE_FORCE_STUN

	// Walked out of a cell
	var/datum/outpost_police_cell/cell = police.cell_best()
	TEST_ASSERT_NOTNULL(cell, "The outpost has no cell")
	cell.admit(suspect, world.time + 10 MINUTES, TRUE)
	TEST_ASSERT(!lethal.police_will_fight(suspect), "A lethal officer will fight a suspect held in a cell")
	cell.escaped(suspect.mind, suspect)
	TEST_ASSERT(!police.in_custody(suspect), "A suspect who walked out of the cell is still in custody")
	TEST_ASSERT(lethal.police_will_fight(suspect), "A lethal officer will not fight a suspect who walked out of the cell")
	TEST_ASSERT(stunner.police_will_fight(suspect), "A stun officer will not chase a suspect who walked out of the cell")
	police.close_case(suspect.mind)
	police_pin_warrant(police, suspect.mind, 0)
	dispatch_clear(police)

/// The officer who saw a suspect go down does the arrest himself when no stun officer is free, at three stars
/datum/unit_test/voidcrew_outpost_police_stun_squad_no_stun_free

/datum/unit_test/voidcrew_outpost_police_stun_squad_no_stun_free/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	police.sleep_tick()
	stun_squad_isolate(police)
	var/list/squad = stun_squad_officers(outpost, 2)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/barker = squad[1]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/busy = squad[2]
	barker.police_role = "lethal"
	busy.police_role = "stun"
	// The only stun officer is already on another arrest
	var/mob/living/carbon/human/other = police_arrest_person(police_arrest_beside(busy))
	var/datum/outpost_warrant/other_warrant = police_pin_warrant(police, other.mind, 12) // one star
	police.open_case(other_warrant)
	// Opening a case wakes the police tick: its dispatch, warrants and the other case would run through the waits below
	police.sleep_tick()
	TEST_ASSERT_EQUAL(busy.case, police.cases[other.mind], "The stun officer is not on the other arrest")

	var/mob/living/carbon/human/suspect = police_arrest_person(police_arrest_beside(barker))
	police_pin_warrant(police, suspect.mind, 55) // three stars
	suspect.adjustStaminaLoss(200)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = barker.ai_controller
	brain.stealth_setup()
	brain.stealth_target_downed(suspect)
	police.sleep_tick()
	var/datum/outpost_police_case/case = police.cases[suspect.mind]
	TEST_ASSERT_NOTNULL(case, "Nobody followed up on a three-star suspect the officer saw go down")
	TEST_ASSERT_EQUAL(case?.arresting(), barker, "With no stun officer free, the arrest went to [case?.arresting()], not the officer who saw it")
	for(var/i in 1 to 6)
		if(QDELETED(case) || suspect.handcuffed)
			break
		// Still down however long the steps take: a suspect back on their feet at three stars is the squad's, not this arrest's
		suspect.adjustStaminaLoss(200)
		case.process_case()
		police_arrest_wait(case)
	TEST_ASSERT(istype(suspect.handcuffed, /obj/item/restraints/handcuffs/outpost_police/used), "The lethal officer did not cuff the suspect himself")
	police.close_case(suspect.mind)
	police.close_case(other.mind)
	suspect.uncuff()
	police_pin_warrant(police, suspect.mind, 0)
	police_pin_warrant(police, other.mind, 0)
	dispatch_clear(police)

/**
 * A wanted suspect in crit in view puts nobody on alert: no fight, no alert from the arrest, and the arrest cuffs
 * them where they lie and stands by them until they come round.
 */
/datum/unit_test/voidcrew_outpost_police_stun_squad_crit_no_alert

/datum/unit_test/voidcrew_outpost_police_stun_squad_crit_no_alert/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	police.sleep_tick()
	stun_squad_isolate(police)
	var/list/squad = stun_squad_officers(outpost, 1)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = squad[1]
	var/mob/living/carbon/human/suspect = police_arrest_person(police_arrest_beside(officer))
	police_pin_warrant(police, suspect.mind, 55) // three stars
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	brain.stealth_setup()
	brain.stealth_go_alert(suspect)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "alert", "The officer did not go on alert at a three-star suspect") // STEALTH_ALERT

	suspect.adjustOxyLoss(120)
	suspect.updatehealth()
	TEST_ASSERT(HAS_TRAIT(suspect, TRAIT_CRITICAL_CONDITION) && suspect.stat != DEAD, "The suspect is not in crit (stat [suspect.stat], health [suspect.health])")
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(brain.blackboard[BB_TARGETING_STRATEGY])
	TEST_ASSERT(!strategy.can_attack(officer, suspect, 9), "A suspect in crit is still a target")
	brain.stealth_target_downed(suspect)
	police.sleep_tick() // the new case woke it
	TEST_ASSERT(brain.stealth_state() != "alert", "The officer stayed on alert over a suspect in crit")
	var/datum/outpost_police_case/case = police.cases[suspect.mind]
	TEST_ASSERT_NOTNULL(case, "Nobody followed up on a suspect in crit")
	// Seen again, looked at again, put on the arrest again: still no alert
	brain.stealth_look()
	officer.police_alert_on(suspect)
	TEST_ASSERT(brain.stealth_state() != "alert", "Seeing a suspect in crit again put the officer back on alert")
	TEST_ASSERT_NULL(brain.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "The officer targets a suspect in crit")

	var/stamina_before = suspect.getStaminaLoss()
	for(var/i in 1 to 6)
		if(QDELETED(case) || suspect.handcuffed)
			break
		case.process_case()
		police_arrest_wait(case)
	TEST_ASSERT(istype(suspect.handcuffed, /obj/item/restraints/handcuffs/outpost_police/used), "A suspect in crit was not cuffed (the case is on [QDELETED(case) ? "nothing" : case.step])")
	TEST_ASSERT_EQUAL(suspect.getStaminaLoss(), stamina_before, "A suspect in crit was struck")
	case.process_case()
	TEST_ASSERT_EQUAL(case.step, "standby", "A cuffed suspect in crit is not stood by (the case is on [case.step])")
	TEST_ASSERT(brain.stealth_state() != "alert", "The officer went on alert over a cuffed suspect in crit")
	case.process_case()
	TEST_ASSERT(!QDELETED(case), "The arrest of a cuffed suspect in crit ended")
	police.close_case(suspect.mind)
	suspect.uncuff()
	police_pin_warrant(police, suspect.mind, 0)
	dispatch_clear(police)

/// Once the three-star suspect is in custody, the response units walk out to a lift and the beat officers stay
/datum/unit_test/voidcrew_outpost_police_stun_squad_stand_down

/datum/unit_test/voidcrew_outpost_police_stun_squad_stand_down/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	police.sleep_tick()
	stun_squad_isolate(police)
	dispatch_two_lifts(outpost)
	var/mob/living/suspect = dispatch_suspect(outpost, 55) // three stars
	var/list/patrol = list()
	for(var/i in 1 to 2)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat = police_officer(outpost)
		beat.resume_routine()
		patrol += beat
	var/list/responders = list()
	for(var/i in 1 to 4)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
		officer.resume_routine()
		officer.dispatch_mind = WEAKREF(suspect.mind)
		responders += officer
	police.dispatch_next_wave = world.time + 1 MINUTES
	police.dispatch_respond(police.alert_level())
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in responders)
		TEST_ASSERT(!officer.npc_exit, "A response officer left while a three-star suspect was free")

	// Cuffed: the case is the arresting officer's, and the rest go home
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	var/mob/living/carbon/carbon_suspect = suspect
	carbon_suspect.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	stun_squad_holding(police, carbon_suspect)
	police.dispatch_respond(police.alert_level())
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in responders)
		TEST_ASSERT(officer.npc_exit, "A response officer stayed on once the three-star suspect was in custody")
	var/staying = 0
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in police.officers)
		if(officer.stat != DEAD && !officer.npc_exit)
			staying++
	TEST_ASSERT_EQUAL(staying, length(patrol), "[staying] officers stay on, not the [length(patrol)] on the beat")
	police.close_case(carbon_suspect.mind)
	carbon_suspect.uncuff()
	police_pin_warrant(police, suspect.mind, 0)
	dispatch_clear(police)

/**
 * Owner decisions 39 and 43: at the red zone's outpost (its profile finishes the downed) the squad at three stars is
 * all lethal, and a three-star suspect who goes down is shot until dead, not cuffed: still a target, no arrest, no
 * alert dropped, and no officer, the marshal included, has a finishing move. At two stars the downed are still
 * arrested there.
 */
/datum/unit_test/voidcrew_outpost_police_stun_squad_red_finishes

/datum/unit_test/voidcrew_outpost_police_stun_squad_red_finishes/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(/obj/structure/overmap/trader_outpost/black_market)
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	TEST_ASSERT(!police.profile.spares_downed, "Setup: the red zone's police spare the downed")
	police.sleep_tick()
	stun_squad_isolate(police)
	var/list/turf/row = dispatch_row(outpost)
	TEST_ASSERT_NOTNULL(row, "No three free tiles in a row on the concourse")
	var/list/squad = stun_squad_officers(outpost, 4)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = squad[1]
	officer.forceMove(row[1])
	var/mob/living/carbon/human/suspect = police_arrest_person(row[3])
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 55) // three stars
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/member as anything in squad)
		police.role_of(member)
	TEST_ASSERT_EQUAL(stun_squad_count(squad, "lethal"), 4, "At three stars the red zone's squad of four has [stun_squad_count(squad, "stun")] stun officers")

	// Down at three stars: finished, not cuffed
	suspect.adjustStaminaLoss(200)
	TEST_ASSERT(HAS_TRAIT(suspect, TRAIT_INCAPACITATED), "200 stamina damage did not put the suspect down")
	TEST_ASSERT(police.finishes_downed(suspect, officer), "The red zone does not finish a downed three-star suspect")
	TEST_ASSERT(officer.police_will_fight(suspect), "A red zone officer stopped fighting a downed three-star suspect")
	TEST_ASSERT(police_plans_shot(officer, suspect), "A red zone officer plans no shot at a downed three-star suspect")
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	brain.stealth_setup()
	officer.police_alert_on(suspect)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "alert", "A red zone officer will not go on alert at a downed three-star suspect") // STEALTH_ALERT
	TEST_ASSERT(!police.arrest_downed(suspect, officer), "A downed three-star suspect in the red zone was put under arrest")
	TEST_ASSERT_NULL(police.open_case(warrant, TRUE), "An arrest opened on a downed three-star suspect in the red zone")
	TEST_ASSERT_NULL(police.cases[suspect.mind], "A downed three-star suspect in the red zone has an arrest")
	TEST_ASSERT_NULL(suspect.handcuffed, "A downed three-star suspect in the red zone was cuffed")

	// Two stars there: still taken alive
	police_pin_warrant(police, suspect.mind, 30) // two stars
	TEST_ASSERT(!police.finishes_downed(suspect, officer), "The red zone finishes a downed two-star suspect")
	TEST_ASSERT(police.arrest_downed(suspect, officer), "A downed two-star suspect in the red zone was not arrested")
	police.close_case(suspect.mind)
	police_pin_warrant(police, suspect.mind, 0)

	// Gunfire only: nobody on the squad, nor the marshal at the top of the ladder, can do a gun execution
	var/list/everyone = squad + stun_squad_officers(outpost, 1, /mob/living/carbon/human/npc/ambient_npc/outpost/police/marshal)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/member as anything in everyone)
		TEST_ASSERT(!member.hv_can_execute(), "A red zone [member.type] can do a finishing move")
	dispatch_clear(police)

/**
 * Force and fire-discipline edge cases: stun officers still pursue three-star cuffed runaways with no open arrest;
 * mech force matches who is aboard; lethal fire holds for stun-only accomplices and charges deliberate body-blockers;
 * tactical officers at stun force never fire their rifle, and switch to their baton when their sidearm is dry.
 */
/datum/unit_test/voidcrew_outpost_police_force_discipline

/datum/unit_test/voidcrew_outpost_police_force_discipline/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	police.sleep_tick()
	stun_squad_isolate(police)
	var/list/turf/row = dispatch_row(outpost)
	TEST_ASSERT_NOTNULL(row, "No three free tiles in a row on the concourse")

	var/list/squad = stun_squad_officers(outpost, 2)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/lethal = squad[1]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/stunner = squad[2]
	lethal.police_role = "lethal"
	stunner.police_role = "stun"
	lethal.forceMove(row[1])
	stunner.forceMove(row[1])

	// 1. A three-star runaway wearing cuffs (not in custody, no arrest case open) is still chased by stun officers
	var/mob/living/carbon/human/runaway = police_arrest_person(row[3])
	police_pin_warrant(police, runaway.mind, 55) // three stars
	var/obj/item/restraints/handcuffs/loose_cuffs = allocate(/obj/item/restraints/handcuffs)
	runaway.equip_to_slot(loose_cuffs, ITEM_SLOT_HANDCUFFED)
	TEST_ASSERT(HAS_TRAIT(runaway, TRAIT_RESTRAINED), "Fixture: runaway is not restrained")
	TEST_ASSERT(!police.in_custody(runaway) && !police.arrest_on(runaway), "Fixture: runaway has custody or an arrest case")
	TEST_ASSERT(stunner.police_will_fight(runaway), "A stun officer ignored a three-star cuffed runaway not in custody")
	TEST_ASSERT_EQUAL(stunner.force_for(runaway), 2, "A stun officer went past stun on a three-star cuffed runaway") // POLICE_FORCE_STUN
	// At two stars with an open arrest case, non-case stun officers leave a restrained suspect to the arresting officer
	var/datum/outpost_warrant/runaway_warrant = police_pin_warrant(police, runaway.mind, 30) // two stars
	var/datum/outpost_police_case/open_arrest = new(police, runaway_warrant)
	police.cases[runaway.mind] = open_arrest
	TEST_ASSERT(!stunner.police_will_fight(runaway), "A non-case stun officer still fights a restrained two-star suspect under arrest")
	police.close_case(runaway.mind)
	runaway.uncuff()

	// 2. Mech force follows the occupant's warrant and the officer's role, never defaulting to lethal
	var/obj/vehicle/sealed/mecha/ripley/mech = allocate(/obj/vehicle/sealed/mecha/ripley, row[3])
	mech.mob_enter(runaway, silent = TRUE)
	police_pin_warrant(police, runaway.mind, 0)
	TEST_ASSERT_EQUAL(stunner.force_for(mech), 0, "A clean pilot's mech got force [stunner.force_for(mech)]") // POLICE_FORCE_NONE
	police_pin_warrant(police, runaway.mind, 12) // one star
	TEST_ASSERT_EQUAL(lethal.force_for(mech), 1, "A one-star pilot's mech got force [lethal.force_for(mech)]") // POLICE_FORCE_ARREST
	TEST_ASSERT(!police_plans_shot(lethal, mech), "An officer planned a shot at a one-star mech")
	police_pin_warrant(police, runaway.mind, 30) // two stars
	TEST_ASSERT_EQUAL(lethal.force_for(mech), 2, "A two-star pilot's mech got force [lethal.force_for(mech)]") // POLICE_FORCE_STUN
	police_pin_warrant(police, runaway.mind, 55) // three stars
	TEST_ASSERT_EQUAL(stunner.force_for(mech), 2, "A stun officer went lethal on a three-star mech") // POLICE_FORCE_STUN
	TEST_ASSERT_EQUAL(lethal.force_for(mech), 3, "A lethal officer did not go lethal on a three-star mech") // POLICE_FORCE_LETHAL
	mech.mob_exit(runaway, silent = TRUE)
	qdel(mech)
	runaway.forceMove(row[3])

	// 3. A two-star accomplice standing in a lethal officer's line of fire holds the lethal shot and accrues resist
	var/mob/living/carbon/human/accomplice = police_arrest_person(row[2])
	var/datum/outpost_warrant/acc_warrant = police_pin_warrant(police, accomplice.mind, 30) // two stars (STUN, not LETHAL)
	lethal.set_force(3) // POLICE_FORCE_LETHAL
	lethal.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, runaway)
	TEST_ASSERT_EQUAL(lethal.bystander_in_line(runaway), accomplice, "A lethal officer would shoot straight through a two-star suspect")
	var/acc_heat_before = acc_warrant.heat
	lethal.check_body_block()
	lethal.dispatch_block_since -= 6 SECONDS // past OUTPOST_POLICE_BLOCK_TIME (5 s)
	lethal.check_body_block()
	TEST_ASSERT(acc_warrant.heat > acc_heat_before, "A two-star accomplice body-blocking lethal fire was not charged with resist")
	lethal.ai_controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	police_pin_warrant(police, accomplice.mind, 0)

	// 4. A tactical officer at stun force stows its rifle, fires stun only, and draws its active baton when the sidearm is dry
	var/list/tactical_list = stun_squad_officers(outpost, 1, /mob/living/carbon/human/npc/ambient_npc/outpost/police/tactical)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/tactical = tactical_list[1]
	tactical.forceMove(row[1])
	police_pin_warrant(police, runaway.mind, 30) // two stars (POLICE_FORCE_STUN)
	var/obj/item/gun/longgun = tactical.get_longgun()
	var/obj/item/gun/energy/sidearm = tactical.get_sidearm()
	var/obj/item/melee/baton/security/baton = tactical.get_baton()
	TEST_ASSERT_NOTNULL(longgun, "Fixture: tactical officer has no long gun")
	TEST_ASSERT_NOTNULL(sidearm, "Fixture: tactical officer has no energy sidearm")
	TEST_ASSERT_NOTNULL(baton, "Fixture: tactical officer has no baton")
	tactical.sync_force(2) // POLICE_FORCE_STUN
	TEST_ASSERT_EQUAL(tactical.police_loaded_gun_for(2), sidearm, "At stun force a tactical officer picked [tactical.police_loaded_gun_for(2)] instead of its stun sidearm")
	TEST_ASSERT(!outpost_police_mode_lethal(sidearm), "At stun force the sidearm was left on lethal")
	sidearm.cell.charge = 0
	var/datum/ai_controller/tac_brain = tactical.ai_controller
	var/datum/ai_planning_subtree/outpost_police_force/force_tree = locate() in tac_brain.planning_subtrees
	tac_brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, runaway)
	tac_brain.planned_behaviors.Cut()
	force_tree.SelectBehaviors(tac_brain, 1)
	TEST_ASSERT_NULL(tactical.police_loaded_gun_for(2), "A tactical officer with a dry sidearm still had a stun gun to fire")
	TEST_ASSERT(tactical.is_holding(baton) && baton.active, "With a dry sidearm at stun force the tactical officer did not draw and switch on its baton")
	TEST_ASSERT(!!(locate(/datum/ai_behavior/basic_melee_attack/human_npc) in tac_brain.planned_behaviors), "With a dry sidearm at stun force the tactical officer did not plan baton melee")
	tac_brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	tac_brain.planned_behaviors.Cut()

	police_pin_warrant(police, runaway.mind, 0)
	dispatch_clear(police)

/**
 * Pass 4 force edge cases: a wanted player in an officer body is fought and tracked for cuff stripping; multi-occupant
 * mechs resolve to their wanted passenger while holding lethal fire for a clean pilot; flat stun batons are stowed
 * rather than swung as clubs and recharged stun sidearms are redrawn; lethal sync flips stun sidearms to kill, clears
 * off-hand props for two-handed heavy guns, and falls back to the lethal sidearm when an arm is lost.
 */
/datum/unit_test/voidcrew_outpost_police_force_edge_cases

/datum/unit_test/voidcrew_outpost_police_force_edge_cases/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	police.sleep_tick()
	stun_squad_isolate(police)
	var/list/turf/row = dispatch_row(outpost)
	TEST_ASSERT_NOTNULL(row, "No three free tiles in a row on the concourse")

	var/list/squad = stun_squad_officers(outpost, 2)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/lethal = squad[1]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/stunner = squad[2]
	lethal.police_role = "lethal"
	stunner.police_role = "stun"
	lethal.forceMove(row[1])
	stunner.forceMove(row[1])
	var/mob/living/carbon/human/suspect = police_arrest_person(row[3])

	// 1. A player transplanted into an officer body is fought when wanted, tracked on cuff-strip, and checked when sleeping
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/played = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, row[3])
	var/mob/living/carbon/human/donor = police_arrest_person(police_floor(outpost))
	donor.mind.transfer_to(played)
	police_pin_warrant(police, played.mind, 55) // three stars
	TEST_ASSERT(lethal.police_will_fight(played), "An officer refused to fight a wanted player in an officer body")

	var/datum/outpost_warrant/strip_warrant = police_pin_warrant(police, suspect.mind, 15) // one star
	var/datum/outpost_police_case/strip_case = new(police, strip_warrant)
	police.cases[suspect.mind] = strip_case
	var/obj/item/restraints/handcuffs/strip_cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	suspect.equip_to_slot(strip_cuffs, ITEM_SLOT_HANDCUFFED)
	strip_case.cuffs_on(suspect)
	SEND_SIGNAL(suspect, COMSIG_BEING_STRIPPED, stunner, strip_cuffs)
	TEST_ASSERT_NULL(strip_case.stripper_ref, "An AI officer touching cuffs was recorded as an abettor")
	SEND_SIGNAL(suspect, COMSIG_BEING_STRIPPED, played, strip_cuffs)
	TEST_ASSERT_EQUAL(strip_case.stripper_ref?.resolve(), played, "A player in an officer body stripping cuffs was not recorded for abet")
	police.close_case(suspect.mind)
	suspect.uncuff()
	police_pin_warrant(police, suspect.mind, 0)
	police_pin_warrant(police, played.mind, 0)

	played.SetSleeping(10 SECONDS)
	stunner.SetSleeping(10 SECONDS)
	TEST_ASSERT(lethal.life_is_sleeper(played), "A player sleeping in an officer body was skipped as an AI officer")
	TEST_ASSERT(!lethal.life_is_sleeper(stunner), "An AI officer sleeping was treated as a public sleeper")
	played.SetSleeping(0)
	stunner.SetSleeping(0)
	qdel(played)

	// 2. Multi-occupant mech: police_mech_suspect finds the wanted passenger, and bystander_in_line holds lethal fire for a clean pilot
	var/obj/vehicle/sealed/mecha/ripley/coop_mech = allocate(/obj/vehicle/sealed/mecha/ripley, row[2])
	coop_mech.max_occupants = 2
	var/mob/living/carbon/human/clean_pilot = police_arrest_person(row[2])
	var/mob/living/carbon/human/wanted_rider = police_arrest_person(row[2])
	police_pin_warrant(police, wanted_rider.mind, 100) // four stars
	coop_mech.mob_enter(clean_pilot, silent = TRUE)
	coop_mech.mob_enter(wanted_rider, silent = TRUE)
	TEST_ASSERT_EQUAL(lethal.police_mech_suspect(coop_mech), wanted_rider, "police_mech_suspect returned [lethal.police_mech_suspect(coop_mech)] instead of the wanted passenger")
	police_pin_warrant(police, suspect.mind, 55) // three stars on row[3]
	lethal.set_force(3) // POLICE_FORCE_LETHAL
	TEST_ASSERT_EQUAL(lethal.bystander_in_line(suspect), clean_pilot, "Lethal fire did not hold for a clean pilot aboard a multi-occupant mech in the line")
	coop_mech.mob_exit(wanted_rider, silent = TRUE)
	coop_mech.mob_exit(clean_pilot, silent = TRUE)
	qdel(coop_mech)
	police_pin_warrant(police, wanted_rider.mind, 0)

	// 3. Flat stun batons are stowed at arrest and stun force, and a recharged stun sidearm is redrawn
	var/obj/item/gun/energy/stun_sidearm = stunner.get_sidearm()
	var/obj/item/melee/baton/security/stun_baton = stunner.get_baton()
	stun_sidearm.cell.charge = 0
	stun_baton.cell.charge = 0
	stun_baton.active = FALSE
	stunner.set_force(1) // POLICE_FORCE_ARREST
	TEST_ASSERT(!stunner.is_holding(stun_baton), "At arrest force an officer kept an uncharged baton out as a club")
	stunner.set_force(2) // POLICE_FORCE_STUN
	TEST_ASSERT(!stunner.is_holding(stun_baton), "At stun force an officer kept an uncharged baton out as a club")
	stun_sidearm.cell.charge = stun_sidearm.cell.maxcharge
	stunner.sync_force(2) // POLICE_FORCE_STUN
	TEST_ASSERT_EQUAL(stunner.police_loaded_gun_for(2), stun_sidearm, "A stun officer did not redraw its recharged sidearm")
	TEST_ASSERT(!outpost_police_mode_lethal(stun_sidearm), "A redrawn stun sidearm was left on lethal")

	// 4. Lethal mode checks, two-handed WEAPON_HEAVY off-hand clearing, and one-handed sidearm fallback
	var/obj/item/gun/energy/lethal_sidearm = lethal.get_sidearm()
	lethal.set_force(2) // POLICE_FORCE_STUN
	TEST_ASSERT_NULL(lethal.police_loaded_gun_for(3), "A stun-mode energy sidearm counted as a ready lethal gun")
	lethal.force = 3 // POLICE_FORCE_LETHAL
	lethal.sync_force(3)
	TEST_ASSERT(outpost_police_mode_lethal(lethal_sidearm), "sync_force at lethal left the energy sidearm on stun")
	TEST_ASSERT_EQUAL(lethal.police_loaded_gun_for(3), lethal_sidearm, "After flipping to lethal, the energy sidearm was not ready")

	var/list/tactical_list = stun_squad_officers(outpost, 1, /mob/living/carbon/human/npc/ambient_npc/outpost/police/tactical)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/tactical = tactical_list[1]
	tactical.forceMove(row[1])
	var/obj/item/gun/longgun = tactical.get_longgun()
	var/obj/item/gun/energy/tac_sidearm = tactical.get_sidearm()
	longgun.weapon_weight = WEAPON_HEAVY
	tactical.set_force(3) // POLICE_FORCE_LETHAL
	tactical.set_held(/obj/item/wrench)
	TEST_ASSERT_EQUAL(tactical.get_num_held_items(), 2, "Fixture: tactical officer did not have a prop in its off-hand")
	TEST_ASSERT_NULL(tactical.police_loaded_gun_for(3), "A WEAPON_HEAVY longgun counted as ready with the off-hand occupied")
	tactical.sync_force(3)
	TEST_ASSERT_EQUAL(tactical.get_num_held_items(), 1, "sync_force at lethal did not clear the off-hand for a WEAPON_HEAVY longgun")
	TEST_ASSERT_EQUAL(tactical.police_loaded_gun_for(3), longgun, "After clearing the off-hand, the WEAPON_HEAVY longgun was not ready")

	var/free_zone = tactical.get_hand_zone_of_item(longgun) == BODY_ZONE_L_ARM ? BODY_ZONE_R_ARM : BODY_ZONE_L_ARM
	var/obj/item/bodypart/off_arm = tactical.get_bodypart(free_zone)
	off_arm.drop_limb()
	qdel(off_arm)
	TEST_ASSERT(!tactical.police_can_handle_gun(longgun), "A one-armed officer still counted as able to fire a WEAPON_HEAVY longgun")
	tactical.sync_force(3)
	TEST_ASSERT(!tactical.is_holding(longgun), "A one-armed officer kept holding an unusable WEAPON_HEAVY longgun")
	TEST_ASSERT_EQUAL(tactical.police_loaded_gun_for(3), tac_sidearm, "A one-armed tactical officer at lethal did not fall back to its sidearm")
	TEST_ASSERT(outpost_police_mode_lethal(tac_sidearm), "A one-armed tactical officer's fallback sidearm was not on lethal")

	police_pin_warrant(police, suspect.mind, 0)
	dispatch_clear(police)
