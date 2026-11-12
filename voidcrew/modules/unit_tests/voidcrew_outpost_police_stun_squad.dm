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
	var/datum/outpost_police_case/case = police.cases[suspect.mind]
	TEST_ASSERT_NOTNULL(case, "A three-star suspect in stamina crit is not under arrest")
	TEST_ASSERT_EQUAL(case.arresting(), stunner, "The arrest went to [case.arresting()], not the free stun officer")

	for(var/i in 1 to 6)
		if(QDELETED(case) || suspect.handcuffed)
			break
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
	TEST_ASSERT_EQUAL(busy.case, police.cases[other.mind], "The stun officer is not on the other arrest")

	var/mob/living/carbon/human/suspect = police_arrest_person(police_arrest_beside(barker))
	police_pin_warrant(police, suspect.mind, 55) // three stars
	suspect.adjustStaminaLoss(200)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = barker.ai_controller
	brain.stealth_setup()
	brain.stealth_target_downed(suspect)
	var/datum/outpost_police_case/case = police.cases[suspect.mind]
	TEST_ASSERT_NOTNULL(case, "Nobody followed up on a three-star suspect the officer saw go down")
	TEST_ASSERT_EQUAL(case?.arresting(), barker, "With no stun officer free, the arrest went to [case?.arresting()], not the officer who saw it")
	for(var/i in 1 to 6)
		if(QDELETED(case) || suspect.handcuffed)
			break
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
