/**
 * Outpost prison economy: pay and its deposits, release bonuses, fines, debt, lost prisoners and
 * suspended transfers, the cells, arrivals, releases, deaths, abandonment and the warden console.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with
 * the define named beside them. Prisons are driven with tick(seconds) with their own processing
 * stopped, never by waiting in real time, except for beams, which run on timers. Each cell's ready
 * time is a world.time, which tick() does not move, so tests set it to now to end a wait. Other
 * packages' inputs (hunger, grime, health, condition scores, confinement) are pinned directly,
 * and expected pay is worked out from conditions_pay_factor() and care(), which other packages
 * own. Shared fixtures are in voidcrew_outpost_prison_helpers.dm.
 */

/// This file's fixtures, shared by its tests
/datum/unit_test/voidcrew_outpost_prison_economy_kit
	parent_type = /datum/unit_test/voidcrew_outpost_management
	abstract_type = /datum/unit_test/voidcrew_outpost_prison_economy_kit

/// A prisoner booked in and standing still at `spot`: fed, in a clean uniform and unhurt
/datum/unit_test/voidcrew_outpost_prison_economy_kit/proc/kept_prisoner(datum/outpost_prison/prison, turf/spot)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, spot)
	set_health_percent(prisoner, 100)
	return prisoner

/// Sets a prisoner's health to `percent` of their maximum
/datum/unit_test/voidcrew_outpost_prison_economy_kit/proc/set_health_percent(mob/living/basic/outpost_prisoner/prisoner, percent)
	var/target_loss = prisoner.maxHealth * (100 - percent) / 100
	prisoner.adjustBruteLoss(target_loss - prisoner.getBruteLoss(), forced = TRUE)

/// Every bulb in the wing working (tg breaks a few at load) and drawn, and the condition scores refreshed
/datum/unit_test/voidcrew_outpost_prison_economy_kit/proc/fix_wing(datum/outpost_prison/prison)
	for(var/turf/tile as anything in prison.wing_turfs())
		for(var/obj/machinery/light/fixture in tile)
			if(fixture.status != LIGHT_OK)
				fixture.fix()
	// conditions_tick() only measures light once the fixtures are drawn and scans mess a budget at a time
	conditions_draw_lights(prison)
	prison.refresh_conditions()

/datum/unit_test/voidcrew_outpost_prison_economy_kit/proc/console_act(obj/machinery/computer/outpost_prison_warden/console, mob/user, action)
	var/datum/tgui/ui = allocate(/datum/tgui, user, console, "OutpostPrison")
	return console.ui_act(action, list(), ui, GLOB.always_state)

/datum/unit_test/voidcrew_outpost_prison_economy_kit/proc/all_present(datum/outpost_prison/prison)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prison.prisoners)
		if(prisoner.phase != "present")
			return FALSE
	return TRUE

/datum/unit_test/voidcrew_outpost_prison_economy_kit/proc/roster_empty(datum/outpost_prison/prison)
	return !length(prison.prisoners)

/// The newest line of a bank account's history
/datum/unit_test/voidcrew_outpost_prison_economy_kit/proc/last_history(datum/bank_account/account)
	var/list/history = account.transaction_history
	return length(history) ? history[length(history)] : null

// ===== PAY =====

/datum/unit_test/voidcrew_outpost_prison_economy
	parent_type = /datum/unit_test/voidcrew_outpost_prison_economy_kit

/datum/unit_test/voidcrew_outpost_prison_economy/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("payowner")
	TEST_ASSERT_NOTNULL(home, "The economy test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/datum/bank_account/treasury = home.treasury
	fix_wing(prison)
	var/conditions = prison.conditions_pay_factor()
	TEST_ASSERT(conditions > 0 && conditions <= 1, "The wing's conditions pay factor is [conditions]")

	var/mob/living/basic/outpost_prisoner/kept = kept_prisoner(prison, prison_spot(home, 3, 8))
	var/mob/living/basic/outpost_prisoner/other = kept_prisoner(prison, prison_spot(home, 12, 8))

	// G(care) is 0 at or below 70% care (OUTPOST_PRISON_GRADE_FLOOR) and 1 from 95% (_GRADE_FULL).
	TEST_ASSERT_EQUAL(prison.care_grade(70), 0, "70% care paid something")
	TEST_ASSERT_EQUAL(prison.care_grade(95), 1, "95% care did not pay in full")
	TEST_ASSERT(abs(prison.care_grade(82) - 0.48) < 0.001, "82% care graded [prison.care_grade(82)], not 0.48")

	// Full care: full pay, times the wing's conditions.
	TEST_ASSERT(abs(kept.care() - 100) < 0.01, "A well kept prisoner's care was [kept.care()]")
	TEST_ASSERT(abs(prison.pay_factor(kept) - conditions) < 0.001, "Full care paid [prison.pay_factor(kept)], not the conditions factor [conditions]")
	TEST_ASSERT(abs(prison.prisoner_pay_rate(kept) - 12 * conditions) < 0.01, "Full care earned [prison.prisoner_pay_rate(kept)] cr/min, not 12 x conditions") // OUTPOST_PRISON_BASE_PAY

	// Starving and nothing else wrong: two thirds care, so nothing at all.
	other.set_hunger(0)
	TEST_ASSERT_EQUAL(prison.pay_factor(other), 0, "A starving prisoner still paid [prison.pay_factor(other)]")
	other.set_hunger(100)

	// Care 82 (fed, clean, 46% health): 0.48 of full pay.
	set_health_percent(other, 46)
	TEST_ASSERT(abs(other.care() - 82) < 0.01, "Fed, clean and at 46% health came to care [other.care()], not 82")
	TEST_ASSERT(abs(prison.pay_factor(other) - 0.48 * conditions) < 0.001, "Care 82 paid [prison.pay_factor(other)], not 0.48 of full")
	var/mean_share = (prison.pay_factor(kept) + prison.pay_factor(other)) / 2
	TEST_ASSERT(abs(mean_share - (conditions + 0.48 * conditions) / 2) < 0.001, "The wing's mean share of full pay is [mean_share]")
	set_health_percent(other, 100)

	// A stained arrival pays short until they change; about 0.67 once uniforms go filthy at 80.
	other.set_uniform_grime(62)
	var/stained_care = other.care()
	TEST_ASSERT(stained_care < 95, "A stained uniform left care at [stained_care]")
	TEST_ASSERT(abs(prison.pay_factor(other) - prison.care_grade(stained_care) * conditions) < 0.001, "A stained arrival paid [prison.pay_factor(other)], not G(care) x conditions")
	if(abs(other.clean_factor() - 60) < 0.5)
		TEST_ASSERT(abs(prison.care_grade(stained_care) - 0.667) < 0.01, "A stained arrival graded [prison.care_grade(stained_care)], not about 0.67")
	other.set_uniform_grime(0)
	TEST_ASSERT(abs(prison.pay_factor(other) - conditions) < 0.001, "A changed prisoner did not go back to full pay")

	// Conditions are one factor: pinned at 50, pay is G x conditions_pay_factor().
	prison.clean_score = 50
	prison.lit_score = 50
	prison.powered_score = 50
	var/half_conditions = prison.conditions_pay_factor()
	TEST_ASSERT(half_conditions >= 0.5 && half_conditions < 1, "Conditions 50 give a pay factor of [half_conditions]")
	TEST_ASSERT(abs(prison.pay_factor(kept) - half_conditions) < 0.001, "At conditions 50 full care paid [prison.pay_factor(kept)], not [half_conditions]")
	fix_wing(prison)
	TEST_ASSERT(abs(prison.conditions_pay_factor() - conditions) < 0.001, "The wing's conditions did not come back after the pin")

	// Confined to a cell for more than 2 minutes (OUTPOST_PRISON_CONFINED_PAY_AFTER): nothing,
	// unless it is protective custody.
	kept.locked_in_seconds = 120
	TEST_ASSERT(prison.pay_factor(kept) > 0, "Two minutes confined already stopped pay")
	kept.locked_in_seconds = 121
	TEST_ASSERT_EQUAL(prison.pay_factor(kept), 0, "Over two minutes confined still paid")
	prison.riot_active = TRUE
	TEST_ASSERT_EQUAL(prison.pay_factor(kept) > 0, !!prison.protective_custody(), "Protective custody and pay disagree for a confined prisoner")
	prison.riot_active = FALSE
	kept.locked_in_seconds = 0

	// Nothing while not earning, dead or not present.
	other.trouble = "fight" // PRISONER_TROUBLE_FIGHT
	TEST_ASSERT_EQUAL(prison.pay_factor(other), 0, "A fighter earned pay")
	other.trouble = null
	other.phase = "arriving" // PRISONER_ARRIVING
	TEST_ASSERT_EQUAL(prison.pay_factor(other), 0, "A prisoner in the beam earned pay")
	other.phase = "present"

	// The roster names the new states. Shut in a cell is "confined" (Locked in) whatever the
	// reason, not only once it stops their pay; a long lock-in alone is not.
	var/list/statuses = list()
	kept.locked_in_seconds = 121
	TEST_ASSERT_EQUAL(prison.roster_status(kept), "present", "A prisoner in the yard with a long lock-in behind them is listed as [prison.roster_status(kept)]")
	kept.locked_in_seconds = 0
	var/turf/kept_spot = kept.loc
	var/datum/outpost_prison_cell/kept_cell = kept.cell
	kept.forceMove(kept_cell.arrival_turf())
	capture_bolt(prison, kept_cell)
	TEST_ASSERT(kept.is_confined(), "The prisoner is not shut in their bolted cell")
	statuses["confined"] = prison.roster_status(kept)
	capture_bolt(prison, kept_cell, FALSE)
	kept.forceMove(kept_spot)
	prison.refresh_reach()
	kept.experiment_subject = TRUE
	statuses["subject"] = prison.roster_status(kept)
	kept.experiment_subject = FALSE
	other.trouble = "riot" // PRISONER_TROUBLE_RIOT
	statuses["rioting"] = prison.roster_status(other)
	other.trouble = "loose" // PRISONER_TROUBLE_LOOSE
	statuses["loose"] = prison.roster_status(other)
	other.trouble = null
	statuses["present"] = prison.roster_status(other)
	for(var/expected in statuses)
		TEST_ASSERT_EQUAL(statuses[expected], expected, "The roster showed [statuses[expected]] for a prisoner who is [expected]")

	// Stipends are deposited every 5 minutes (OUTPOST_PRISON_DEPOSIT_INTERVAL), as one line.
	prison.pay_clock = 0
	prison.pay_owed = 0
	var/start = treasury.account_balance
	var/factor = prison.pay_factor(kept)
	TEST_ASSERT(abs(prison.pay_factor(other) - factor) < 0.001, "The two test prisoners are not kept alike")
	prison.tick(299)
	TEST_ASSERT_EQUAL(treasury.account_balance, start, "A stipend was deposited before 5 minutes")
	prison.tick(1)
	var/expected_stipend = round(2 * 12 * 5 * factor + 0.001)
	TEST_ASSERT_EQUAL(treasury.account_balance - start, expected_stipend, "Five minutes of two prisoners deposited [treasury.account_balance - start], not [expected_stipend]")
	var/list/deposit_line = last_history(treasury)
	TEST_ASSERT_EQUAL(deposit_line?["reason"], "Prison wing stipend, 5 min", "The deposit reads [deposit_line?["reason"]]")
	TEST_ASSERT_EQUAL(prison.paid_total, expected_stipend, "The prison's paid total did not count the stipend")

	// The release bonus is 200 (OUTPOST_PRISON_RELEASE_BONUS) x G x F averaged over the stay:
	// a minute kept in full, a minute at care 82.
	qdel(other)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 1, "Deleting a prisoner left them on the roster")
	kept.set_hunger(100)
	kept.set_uniform_grime(0)
	kept.sentence_left = 120
	kept.served_seconds = 0
	kept.kept_seconds = 0
	var/first_factor = prison.pay_factor(kept)
	prison.tick(60)
	set_health_percent(kept, 46)
	var/second_factor = prison.pay_factor(kept)
	TEST_ASSERT(abs(second_factor - 0.48 * first_factor) < 0.001, "The second minute's factor is [second_factor]")
	start = treasury.account_balance
	var/paid_before = prison.paid_total
	var/kept_name = kept.real_name
	prison.pay_clock = 0
	prison.tick(60)
	TEST_ASSERT_EQUAL(kept.phase, "leaving", "A prisoner whose sentence ended was not being beamed out") // PRISONER_LEAVING
	var/expected_bonus = round(200 * (first_factor + second_factor) / 2)
	TEST_ASSERT_EQUAL(treasury.account_balance - start, expected_bonus, "The release paid [treasury.account_balance - start], not the stay's average [expected_bonus]")
	TEST_ASSERT_EQUAL(prison.paid_total - paid_before, expected_bonus, "The paid total missed the release")
	var/list/newest = prison.entries[1]
	TEST_ASSERT(findtext(newest["text"], kept_name) && findtext(newest["text"], "released"), "The release was not logged first: [newest["text"]]")
	// Half the stay kept halves the bonus.
	var/mob/living/basic/outpost_prisoner/half = kept_prisoner(prison, prison_spot(home, 12, 8))
	half.served_seconds = 600
	half.kept_seconds = 300
	start = treasury.account_balance
	TEST_ASSERT_EQUAL(prison.release(half), 100, "Half the stay kept did not halve the bonus")
	TEST_ASSERT_EQUAL(treasury.account_balance - start, 100, "The half bonus was not paid")
	TEST_ASSERT(wait_until(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(is_qdeleted_ref), WEAKREF(kept)), 6 SECONDS), "The released prisoner was never beamed out")

	// A newcomer takes the mood the yard gives them.
	var/mob/living/basic/outpost_prisoner/settled = kept_prisoner(prison, prison_spot(home, 10, 8))
	settled.set_mood(40)
	var/expected_mood = prison.arrival_mood()
	var/mob/living/basic/outpost_prisoner/newcomer = kept_prisoner(prison, prison_spot(home, 8, 8))
	TEST_ASSERT(abs(newcomer.mood - expected_mood) < 0.01, "A newcomer arrived at mood [newcomer.mood], not the arrival mood [expected_mood]")
	settle_prison_air(home)

// ===== FINES, DEBT AND LOST PRISONERS =====

/datum/unit_test/voidcrew_outpost_prison_fines
	parent_type = /datum/unit_test/voidcrew_outpost_prison_economy_kit

/datum/unit_test/voidcrew_outpost_prison_fines/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("fineowner")
	TEST_ASSERT_NOTNULL(home, "The fines test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/datum/bank_account/treasury = home.treasury
	var/obj/machinery/computer/outpost_prison_warden/console = locate() in prison_spot(home, 7, 5)
	TEST_ASSERT_NOTNULL(console, "The warden's console is not where the map puts it")
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 7, 4), "fineowner")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 8, 4), "finevisitor")
	var/mob/living/carbon/human/treasurer = make_player(prison_spot(home, 6, 4), "finetreasurer")
	home.treasurers += treasurer.mind

	// A fine the treasury cannot cover: all of it becomes debt, with a line in its history.
	treasury.account_balance = 0
	treasury.account_debt = 0
	TEST_ASSERT_EQUAL(prison.charge_fine(1000, "Prison escape fine: Test"), 1000, "A fine on an empty treasury was not levied in full")
	TEST_ASSERT_EQUAL(treasury.account_balance, 0, "An empty treasury went below zero")
	TEST_ASSERT_EQUAL(treasury.account_debt, 1000, "An unpaid fine left [treasury.account_debt] cr of debt, not 1000")
	var/list/debt_line = last_history(treasury)
	TEST_ASSERT_EQUAL(debt_line?["reason"], "Prison escape fine: Test: 1000 cr owed", "The debt's history line reads [debt_line?["reason"]]")
	TEST_ASSERT_EQUAL(prison.fined_total, 1000, "The console's fined total missed the fine")
	// Part covered: what the treasury holds is taken, the rest is owed.
	treasury.account_debt = 0
	treasury.account_balance = 600
	TEST_ASSERT_EQUAL(prison.charge_fine(1000, "Prison escape fine: Test"), 1000, "A part-covered fine was not levied in full")
	TEST_ASSERT_EQUAL(treasury.account_balance, 0, "A 600 cr treasury kept [treasury.account_balance] cr after a 1000 cr fine")
	TEST_ASSERT_EQUAL(treasury.account_debt, 400, "The shortfall left [treasury.account_debt] cr of debt, not 400")
	// Later deposits pay 75% of themselves toward it (tg's DEBT_COLLECTION_COEFF).
	prison.pay_owed = 100
	var/paid_before = prison.paid_total
	TEST_ASSERT_EQUAL(prison.deposit_pay(), 100, "The stipend was not deposited")
	TEST_ASSERT_EQUAL(treasury.account_debt, 325, "A 100 cr stipend left [treasury.account_debt] cr of a 400 cr debt, not 325")
	TEST_ASSERT_EQUAL(treasury.account_balance, 25, "A 100 cr stipend left the indebted treasury [treasury.account_balance] cr, not 25")
	TEST_ASSERT_EQUAL(prison.paid_total - paid_before, 100, "The paid total did not count the whole stipend")

	// No intake while the treasury owes anything.
	TEST_ASSERT(!prison.set_intake(TRUE, owner), "Intake opened with the treasury in debt")
	TEST_ASSERT(!prison.intake_open, "A refused intake is open")
	console_act(console, owner, "toggle_intake")
	TEST_ASSERT(!prison.intake_open, "The console opened intake with the treasury in debt")
	var/list/data = console.ui_data(owner)
	TEST_ASSERT_EQUAL(data["intake_state"], "debt", "Intake in debt shows as [data["intake_state"]]")
	TEST_ASSERT_EQUAL(data["debt"], 325, "The console shows [data["debt"]] cr of debt")
	// Open intake stops taking arrivals as soon as a debt appears, and goes on once it is paid.
	treasury.account_debt = 0
	TEST_ASSERT(prison.set_intake(TRUE, owner), "Intake would not open with the debt gone")
	treasury.account_debt = 50
	prison.tick(60)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 0, "A prisoner arrived while the treasury was in debt")
	TEST_ASSERT_NULL(console.ui_data(owner)["next_arrival"], "An arrival was due while the treasury was in debt")
	// Paying it: managers and treasurers only, and only what the treasury holds.
	TEST_ASSERT(!console.ui_data(visitor)["can_pay_debt"], "A visitor may pay the debt")
	TEST_ASSERT(console.ui_data(treasurer)["can_pay_debt"], "A treasurer may not pay the debt")
	treasury.account_balance = 30
	console_act(console, visitor, "pay_debt")
	TEST_ASSERT_EQUAL(treasury.account_debt, 50, "A visitor paid the treasury's debt")
	console_act(console, owner, "pay_debt")
	TEST_ASSERT_EQUAL(treasury.account_debt, 20, "The owner's payment left [treasury.account_debt] cr of a 50 cr debt with 30 cr in the treasury")
	TEST_ASSERT_EQUAL(treasury.account_balance, 0, "Paying the debt left [treasury.account_balance] cr")
	treasury.account_balance = 100
	console_act(console, treasurer, "pay_debt")
	TEST_ASSERT_EQUAL(treasury.account_debt, 0, "The treasurer did not pay off the debt")
	TEST_ASSERT_EQUAL(treasury.account_balance, 80, "Paying off a 20 cr debt left [treasury.account_balance] cr of 100")
	TEST_ASSERT_EQUAL(console.ui_data(owner)["intake_state"], "open", "Intake did not go back to open once the debt was paid")
	TEST_ASSERT(!console.ui_data(owner)["can_pay_debt"], "The console offers to pay a debt that is gone")
	// The admin panel reads the same data with no user.
	TEST_ASSERT_EQUAL(prison.ui_payload(null)["intake_state"], "open", "The console data without a user gives the wrong intake state")
	prison.tick(1)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 1, "No prisoner arrived once the debt was paid")
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_prison_economy_kit, all_present), prison), 8 SECONDS), "The arrival never finished beaming in")
	var/mob/living/basic/outpost_prisoner/arrival = prison.prisoners[1]
	ADD_TRAIT(arrival, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	arrival.sentence_left = 3600
	prison.set_intake(FALSE, owner)

	// One incident's fines stop at 2500 together (OUTPOST_PRISON_INCIDENT_FINE_CAP): three escapes
	// and a transfer. A fine outside the incident is not capped with it.
	treasury.account_balance = 5000
	prison.begin_incident()
	TEST_ASSERT_EQUAL(prison.charge_fine(1000, "Prison escape fine: One", TRUE), 1000, "The first escape was not fined in full")
	TEST_ASSERT_EQUAL(prison.charge_fine(1000, "Prison escape fine: Two", TRUE), 1000, "The second escape was not fined in full")
	TEST_ASSERT_EQUAL(prison.charge_fine(1000, "Prison escape fine: Three", TRUE), 500, "The third escape was not cut to the cap")
	TEST_ASSERT_EQUAL(prison.charge_fine(750, "Prison transfer fee: Four", TRUE), 0, "A transfer past the cap was fined") // OUTPOST_PRISON_TRANSFER_FEE
	TEST_ASSERT_EQUAL(treasury.account_balance, 2500, "One incident took [5000 - treasury.account_balance] cr, not 2500")
	TEST_ASSERT_EQUAL(prison.charge_fine(1000, "Prison fine: Five"), 1000, "A fine outside the incident was capped with it")
	TEST_ASSERT_EQUAL(treasury.account_balance, 1500, "The fine outside the incident was not taken")
	// Nobody is rioting or loose, so the incident closes on the next tick; the next one starts fresh.
	prison.tick(1)
	TEST_ASSERT(!prison.incident_open, "An incident stayed open with nobody rioting or loose")
	TEST_ASSERT_EQUAL(prison.charge_fine(1000, "Prison escape fine: Six", TRUE), 1000, "A new incident inherited the old one's fines")
	TEST_ASSERT(prison.incident_open, "An incident fine did not open an incident")
	prison.end_incident()

	// Two prisoners lost within 30 minutes (OUTPOST_PRISON_LOST_TO_SUSPEND, _LOST_WINDOW) suspend
	// transfers until a manager reopens intake.
	TEST_ASSERT(prison.set_intake(TRUE, owner), "Intake would not open")
	prison.note_prisoner_lost(null, "escaped")
	TEST_ASSERT(prison.intake_open, "One lost prisoner suspended transfers")
	prison.note_prisoner_lost(null, "transferred")
	TEST_ASSERT(!prison.intake_open && prison.intake_suspended, "Two lost prisoners did not suspend transfers")
	data = console.ui_data(owner)
	TEST_ASSERT_EQUAL(data["intake_state"], "suspended", "Suspended intake shows as [data["intake_state"]]")
	var/list/newest = prison.entries[1]
	TEST_ASSERT(findtext(newest["text"], "suspended"), "The suspension was not logged: [newest["text"]]")
	console_act(console, visitor, "toggle_intake")
	TEST_ASSERT(prison.intake_suspended, "A visitor lifted the suspension")
	console_act(console, owner, "toggle_intake")
	TEST_ASSERT(prison.intake_open && !prison.intake_suspended, "Reopening intake did not lift the suspension")
	TEST_ASSERT_EQUAL(prison.lost_recently(), 0, "Reopening left [prison.lost_recently()] losses counting toward the next suspension")
	// A loss from longer ago than the window does not count.
	prison.lost_log = list(world.time - 31 MINUTES)
	prison.note_prisoner_lost(null, "escaped")
	TEST_ASSERT(prison.intake_open, "A loss from 31 minutes ago counted toward a suspension")
	prison.set_intake(FALSE, owner)

	// Managers let visitors through the staff doors.
	var/visitors_before = prison.visitors_allowed
	console_act(console, visitor, "toggle_visitors")
	TEST_ASSERT_EQUAL(prison.visitors_allowed, visitors_before, "A visitor changed the visitor setting")
	console_act(console, owner, "toggle_visitors")
	TEST_ASSERT_EQUAL(prison.visitors_allowed, !visitors_before, "The owner could not change the visitor setting")
	TEST_ASSERT_EQUAL(console.ui_data(owner)["visitors_allowed"], prison.visitors_allowed, "The console shows the wrong visitor setting")

	// Every fine is counted, and none of the money shows on the console but the debt.
	TEST_ASSERT_EQUAL(prison.fined_total, 1000 + 1000 + 2500 + 1000 + 1000, "The fined total is [prison.fined_total]")
	var/list/owner_data = console.ui_data(owner)
	for(var/key in list("money", "pay_rate", "pay_percent", "paid_total"))
		TEST_ASSERT(!(key in owner_data), "The warden console still sends [key]")
	settle_prison_air(home)

// ===== CELLS, ARRIVALS, RELEASES AND THE CONSOLE =====

/datum/unit_test/voidcrew_outpost_prison_cells
	parent_type = /datum/unit_test/voidcrew_outpost_prison_economy_kit

/datum/unit_test/voidcrew_outpost_prison_cells/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("cellsowner")
	TEST_ASSERT_NOTNULL(home, "The cells test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/datum/bank_account/treasury = home.treasury
	var/obj/machinery/computer/outpost_prison_warden/console = locate() in prison_spot(home, 7, 5)
	TEST_ASSERT_NOTNULL(console, "The warden's console is not where the map puts it")
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 7, 4), "cellsowner")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 8, 4), "cellsvisitor")

	// Four cells, numbered by their doors, each with a bed and nine tiles inside.
	TEST_ASSERT_EQUAL(length(prison.cells), 4, "The wing does not have four cells")
	for(var/number in 1 to 4)
		var/datum/outpost_prison_cell/cell = prison.cells[number]
		TEST_ASSERT_EQUAL(cell.number, number, "Cell [number] is numbered [cell.number]")
		var/obj/machinery/door/airlock/door = cell.door()
		TEST_ASSERT_EQUAL(get_turf(door), prison_spot(home, 4 * number - 1, 12), "Cell [number]'s door is not where the map puts it")
		TEST_ASSERT_EQUAL(door.name, "Cell [number]", "Cell [number]'s door is called [door.name]")
		TEST_ASSERT_NOTNULL(cell.bed(), "Cell [number] has no bed")
		TEST_ASSERT_EQUAL(get_turf(cell.bed()), prison_spot(home, 4 * number - 2, 15), "Cell [number]'s bed is not the one in the cell")
		TEST_ASSERT_EQUAL(length(cell.turfs), 9, "Cell [number] has [length(cell.turfs)] tiles inside, not 9")
		TEST_ASSERT_EQUAL(cell.arrival_turf(), get_turf(cell.bed()), "Cell [number] does not deliver to its bed")
	TEST_ASSERT_NOTNULL(locate(/obj/item/toy/basketball) in prison_spot(home, 9, 9), "The ball is not where the intake pad was")

	// The console sends every key OutpostPrison.tsx reads, and none of the rules behind them: no
	// pay, conditions, hatch stock, tension or clocks (a player works those out on the wing).
	var/list/data = console.ui_data(visitor)
	for(var/key in list("linked", "powered", "on_battery", "intake_open", "intake_state", "next_arrival", "capacity", "debt", "visitors_allowed", "can_manage", "can_pay_debt", "trouble", "prisoners", "log", "alarm", "alarm_text"))
		TEST_ASSERT(key in data, "The warden console sends no [key]")
	for(var/key in list("intake_note", "pay_rate", "pay_percent", "paid_total", "money", "conditions", "hatch"))
		TEST_ASSERT(!(key in data), "The warden console still sends [key]")
	var/list/trouble = data["trouble"]
	TEST_ASSERT_EQUAL(length(trouble), 1, "The console's trouble block sends [length(trouble)] fields, not the stage alone")
	TEST_ASSERT_EQUAL(trouble["stage"], prison.stage, "The console's trouble block shows the stage as [trouble["stage"]]")
	TEST_ASSERT(data["linked"], "The warden console is not linked to its prison")
	TEST_ASSERT(!data["can_manage"], "A visitor could manage the prison")
	TEST_ASSERT_EQUAL(data["capacity"], 4, "The prison does not hold 4") // OUTPOST_PRISON_CAPACITY
	TEST_ASSERT_NULL(data["next_arrival"], "An arrival was due with intake closed")
	TEST_ASSERT_EQUAL(data["intake_state"], "closed", "Closed intake shows as [data["intake_state"]]")
	TEST_ASSERT_EQUAL(data["debt"], 0, "A new treasury shows a debt")

	// Only managers open intake; the first prisoner is due in 5 seconds (OUTPOST_PRISON_FIRST_ARRIVAL).
	console_act(console, visitor, "toggle_intake")
	TEST_ASSERT(!prison.intake_open, "A visitor opened intake")
	console_act(console, owner, "toggle_intake")
	TEST_ASSERT(prison.intake_open, "The owner could not open intake")
	TEST_ASSERT_EQUAL(console.ui_data(owner)["next_arrival"], 5, "The first prisoner is not due in 5 seconds")
	TEST_ASSERT_EQUAL(console.ui_data(owner)["intake_state"], "open", "Open intake does not show as open")

	// One at a time, each into their own cell, 30 seconds to 3 minutes apart (OUTPOST_PRISON_ARRIVAL_GAP_*).
	prison.tick(4)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 0, "A prisoner arrived early")
	prison.tick(1)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 1, "Only one prisoner should arrive at a time")
	var/mob/living/basic/outpost_prisoner/first = prison.prisoners[1]
	TEST_ASSERT_EQUAL(first.console_status(), "arriving", "A prisoner in the beam was not arriving")
	TEST_ASSERT(HAS_TRAIT(first, TRAIT_IMMOBILIZED), "A prisoner could move inside the beam")
	var/list/seen_cells = list()
	for(var/i in 1 to 3)
		var/gap = prison.arrival_countdown
		TEST_ASSERT(gap >= 30 && gap <= 180, "The next arrival is [gap] s away, not 30-180")
		prison.tick(gap - 1)
		TEST_ASSERT_EQUAL(length(prison.prisoners), i, "A prisoner arrived before the gap was up")
		prison.tick(1)
		TEST_ASSERT_EQUAL(length(prison.prisoners), i + 1, "No prisoner arrived when the gap was up")
	for(var/mob/living/basic/outpost_prisoner/arrival as anything in prison.prisoners)
		TEST_ASSERT_NOTNULL(arrival.cell, "[arrival] has no cell")
		TEST_ASSERT(!(arrival.cell in seen_cells), "Two prisoners share cell [arrival.cell.number]")
		seen_cells += arrival.cell
		TEST_ASSERT_EQUAL(arrival.cell.occupant, arrival, "Cell [arrival.cell.number] does not know its prisoner")
		TEST_ASSERT_EQUAL(arrival.loc, arrival.cell.arrival_turf(), "[arrival] did not beam into their own cell")
		TEST_ASSERT_EQUAL(arrival.prison, prison, "[arrival] does not know their prison")
		TEST_ASSERT(arrival.sentence_left >= 480 && arrival.sentence_left <= 900, "[arrival] got a [arrival.sentence_left] s sentence, not 8-15 min")
		TEST_ASSERT(arrival.personality && arrival.crime, "[arrival] has no personality or crime")
	TEST_ASSERT_NULL(prison.arrival_countdown, "An arrival was still due with every cell full")
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_prison_economy_kit, all_present), prison), 8 SECONDS), "The arrivals never finished beaming in")
	for(var/mob/living/basic/outpost_prisoner/arrival as anything in prison.prisoners)
		TEST_ASSERT(!HAS_TRAIT(arrival, TRAIT_IMMOBILIZED), "[arrival] was still held after beaming in")
		ADD_TRAIT(arrival, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
		// Long enough that the rest of the test releases nobody by accident.
		arrival.sentence_left = 3600
	TEST_ASSERT_EQUAL(length(prison.entries), 4, "The arrivals were not logged")
	// Long after the last arrival: from here only each cell's own wait holds arrivals back
	// (voidcrew_outpost_prison_arrival_gap tests the gap between arrivals).
	prison.arrival_gap = 0

	// The roster: name, cell, crime, time left and a bounty badge, in cell order, and nothing about their needs or birthdays.
	var/list/roster = console.ui_data(owner)["prisoners"]
	TEST_ASSERT_EQUAL(length(roster), 4, "The console roster does not list every prisoner")
	for(var/i in 1 to 4)
		var/list/row = roster[i]
		TEST_ASSERT_EQUAL(length(row), 7, "A roster row sends [length(row)] fields, not 7")
		for(var/key in list("ref", "name", "cell", "crime", "sentence_left", "status", "bounty"))
			TEST_ASSERT(key in row, "The console roster sends no [key]")
		TEST_ASSERT_NULL(row["bounty"], "An ordinary prisoner has a bounty badge")
		TEST_ASSERT_EQUAL(row["cell"], i, "The roster is not in cell order")
		TEST_ASSERT_EQUAL(row["status"], "present", "A settled prisoner is listed as [row["status"]]")
	TEST_ASSERT_NULL(console.ui_data(owner)["next_arrival"], "An arrival was due with the prison full")

	// Staff doors: shut to prisoners whether open or closed, free to the wing's members.
	var/mob/living/basic/outpost_prisoner/tester = prison.prisoners[1]
	var/obj/machinery/door/airlock/security/prison_staff/staff_door = locate() in prison_spot(home, 9, 6)
	TEST_ASSERT_NOTNULL(staff_door, "The office door is not a staff airlock")
	TEST_ASSERT(!staff_door.allowed(tester), "A prisoner may open the office door")
	TEST_ASSERT(staff_door.allowed(owner), "The office door wants an ID from the owner")
	TEST_ASSERT(!staff_door.CanAStarPass(SOUTH, new /datum/can_pass_info(tester)), "Prisoners path through the office door")
	TEST_ASSERT(staff_door.CanAStarPass(SOUTH, new /datum/can_pass_info(owner)), "The owner cannot path through the office door")
	staff_door.open()
	TEST_ASSERT(!staff_door.density, "The office door did not open")
	var/turf/tester_home = tester.loc
	tester.forceMove(prison_spot(home, 9, 7))
	REMOVE_TRAIT(tester, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	tester.Move(get_turf(staff_door), SOUTH)
	TEST_ASSERT_EQUAL(tester.loc, prison_spot(home, 9, 7), "A prisoner walked through the open office door")
	ADD_TRAIT(tester, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	tester.forceMove(tester_home)
	var/obj/machinery/door/airlock/entrance = locate() in prison_spot(home, 9, 1)
	TEST_ASSERT(istype(entrance, /obj/machinery/door/airlock/security/prison_staff), "The entrance is not a staff airlock")
	var/datum/outpost_prison_cell/first_cell = prison.cells[1]
	TEST_ASSERT(first_cell.door().allowed(tester), "A cell door refused a prisoner")

	// Release: in the last 30 seconds they head back to their cell (OUTPOST_PRISON_RELEASE_WALK)...
	var/mob/living/basic/outpost_prisoner/leaver = prison.prisoners[2]
	var/datum/outpost_prison_cell/leaver_cell = leaver.cell
	leaver.forceMove(prison_spot(home, 10, 8))
	prison.refresh_prisoner_reach(leaver)
	leaver.sentence_left = 25
	TEST_ASSERT_EQUAL(leaver.console_status(), "leaving", "A prisoner in their last 30 seconds is not listed as leaving")
	var/datum/prisoner_activity/walk_home = leaver.choose_activity()
	TEST_ASSERT(istype(walk_home, /datum/prisoner_activity/go_home), "A prisoner due out chose [walk_home?.type] instead of heading home")
	TEST_ASSERT_EQUAL(walk_home.spot, leaver_cell.arrival_turf(), "A prisoner due out did not head for their own cell")
	leaver.end_activity(cancel_ai = FALSE)
	// ...and beam out when it ends, from wherever they stand if they did not get there.
	var/datum/weakref/leaver_ref = WEAKREF(leaver)
	prison.tick(25)
	TEST_ASSERT_EQUAL(leaver.phase, "leaving", "A released prisoner was not beamed out")
	TEST_ASSERT(HAS_TRAIT(leaver, TRAIT_IMMOBILIZED), "A prisoner could walk out of the beam")
	TEST_ASSERT(wait_until(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(is_qdeleted_ref), leaver_ref), 6 SECONDS), "The beam never took the released prisoner")
	TEST_ASSERT_NULL(leaver_cell.occupant, "The released prisoner's cell was not freed")
	TEST_ASSERT_EQUAL(length(prison.prisoners), 3, "The released prisoner stayed on the roster")
	// The freed cell takes nobody for 60-120 seconds (OUTPOST_PRISON_REFILL_MIN/MAX).
	var/refill = leaver_cell.ready_at - world.time
	TEST_ASSERT(refill >= 58 SECONDS && refill <= 120 SECONDS, "The freed cell is ready in [refill / 10] s, not 60-120")
	TEST_ASSERT(prison.arrival_countdown >= 58 && prison.arrival_countdown <= 120, "The next arrival is [prison.arrival_countdown] s away, not the cell's wait")
	prison.tick(30)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 3, "The freed cell was refilled before it was ready")
	leaver_cell.ready_at = world.time
	prison.tick(1)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 4, "The freed cell was not refilled once ready")
	TEST_ASSERT(leaver_cell.occupant, "The new arrival did not take the free cell")
	TEST_ASSERT_EQUAL(leaver_cell.occupant.loc, leaver_cell.arrival_turf(), "The new arrival did not beam into the free cell")
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_prison_economy_kit, all_present), prison), 8 SECONDS), "The replacement never finished beaming in")
	ADD_TRAIT(leaver_cell.occupant, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	leaver_cell.occupant.sentence_left = 3600

	// Closing intake stops arrivals, and neither closing nor reopening it shortens a cell's wait.
	console_act(console, owner, "toggle_intake")
	TEST_ASSERT(!prison.intake_open, "The owner could not close intake")
	var/mob/living/basic/outpost_prisoner/removed = prison.prisoners[4]
	var/datum/outpost_prison_cell/removed_cell = removed.cell
	qdel(removed)
	var/removed_ready = removed_cell.ready_at
	TEST_ASSERT(removed_ready > world.time, "A freed cell was ready at once")
	prison.tick(10 * 60)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 3, "A prisoner arrived with intake closed")
	TEST_ASSERT_NULL(console.ui_data(owner)["next_arrival"], "An arrival was due with intake closed")
	console_act(console, owner, "toggle_intake")
	console_act(console, owner, "toggle_intake")
	console_act(console, owner, "toggle_intake")
	TEST_ASSERT(prison.intake_open, "Intake is not open after three toggles")
	TEST_ASSERT_EQUAL(removed_cell.ready_at, removed_ready, "Toggling intake moved the cell's ready time")
	prison.tick(45)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 3, "Toggling intake skipped the freed cell's wait")
	removed_cell.ready_at = world.time
	prison.tick(1)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 4, "The reopened intake did not refill the ready cell")
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_prison_economy_kit, all_present), prison), 8 SECONDS), "The reopened intake's arrival never finished beaming in")
	for(var/mob/living/basic/outpost_prisoner/arrival as anything in prison.prisoners)
		ADD_TRAIT(arrival, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
		arrival.sentence_left = max(arrival.sentence_left, 3600)

	// A death is logged. Nobody comes for the body: it keeps its cell while it lies in the cell block
	// and sours the yard; carried out, it leaves the roster and the cell waits a refill.
	var/mob/living/basic/outpost_prisoner/victim = prison.prisoners[1]
	var/datum/outpost_prison_cell/victim_cell = victim.cell
	var/mob/living/basic/outpost_prisoner/witness = prison.prisoners[2]
	var/drift_before = witness.mood_drift_per_minute()
	victim.death()
	TEST_ASSERT_EQUAL(victim.console_status(), "dead", "A dead prisoner was not listed as dead")
	TEST_ASSERT_EQUAL(victim.body_position, LYING_DOWN, "A dead prisoner did not fall down")
	var/list/newest = prison.entries[1]
	TEST_ASSERT(findtext(newest["text"], "died"), "The death was not logged first: [newest["text"]]")
	TEST_ASSERT_EQUAL(prison.prisoner_pay_rate(victim), 0, "A body earned a stipend")
	TEST_ASSERT_EQUAL(prison.bodies_in_cell_block(), 1, "The body in the cell block was not counted")
	TEST_ASSERT(witness.mood_drift_per_minute() < drift_before, "A body in the cell block did not sour the others")
	TEST_ASSERT("a body in the cell block" in prison.restless_causes(), "The body is not among the restless causes")
	prison.tick(130)
	TEST_ASSERT(!QDELETED(victim) && victim.phase == "present" && (victim in prison.prisoners), "The body was taken away with nobody moving it")
	TEST_ASSERT_EQUAL(victim_cell.occupant, victim, "The body lying in the cell block gave up its cell")
	var/turf/outside = prison.outside_spot_near(victim)
	TEST_ASSERT_NOTNULL(outside, "Nowhere outside the cell block to carry the body")
	victim.forceMove(outside)
	prison.tick(1)
	TEST_ASSERT(!QDELETED(victim), "The body carried out of the cell block was deleted")
	TEST_ASSERT(!(victim in prison.prisoners), "The body carried out of the cell block stayed on the roster")
	TEST_ASSERT_EQUAL(length(prison.prisoners), 3, "The body carried out kept its cell")
	var/death_wait = victim_cell.ready_at - world.time
	TEST_ASSERT(death_wait >= 60 SECONDS && death_wait <= 120 SECONDS, "The carried-out body's cell is ready in [death_wait / 10] s, not a refill") // OUTPOST_PRISON_REFILL_MIN, _MAX
	qdel(victim)

	// A gibbed prisoner's cell waits a refill too.
	var/mob/living/basic/outpost_prisoner/gibbed = prison.prisoners[1]
	var/datum/outpost_prison_cell/gibbed_cell = gibbed.cell
	gibbed.gib()
	TEST_ASSERT(QDELETED(gibbed), "The gibbed prisoner is still about")
	TEST_ASSERT_NULL(gibbed_cell.occupant, "The gibbed prisoner kept their cell")
	var/gib_wait = gibbed_cell.ready_at - world.time
	TEST_ASSERT(gib_wait >= 60 SECONDS && gib_wait <= 120 SECONDS, "A gibbed prisoner's cell is ready in [gib_wait / 10] s, not a refill")

	// Nobody is beamed into a bolted cell, ready or not.
	gibbed_cell.ready_at = world.time
	TEST_ASSERT(prison.toggle_cell_bolts(gibbed_cell.number, owner), "The gibbed prisoner's cell has no door")
	var/obj/machinery/door/airlock/gibbed_door = gibbed_cell.door()
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(door_bolted), gibbed_door), 5 SECONDS), "The cell door never bolted")
	prison.tick(60)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 2, "A prisoner was beamed into a bolted cell")
	TEST_ASSERT_NULL(gibbed_cell.occupant, "A bolted cell took an arrival")
	gibbed_door.unbolt()
	prison.tick(1)
	TEST_ASSERT_EQUAL(gibbed_cell.occupant?.prison, prison, "The unbolted cell did not take the next arrival")
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_prison_economy_kit, all_present), prison), 8 SECONDS), "The arrival into the unbolted cell never finished beaming in")

	// Abandoning the outpost closes intake and transfers everyone out, living or dead, with no
	// bonus and no stipend, and with nobody rioting or loose, no fine (see voidcrew_outpost_prison_abandon_fines).
	var/mob/living/basic/outpost_prisoner/last_victim = prison.prisoners[1]
	last_victim.death()
	prison.pay_owed = 7
	treasury.account_balance = 1234
	var/debt_before = treasury.account_debt
	var/paid_before = prison.paid_total
	var/fined_before = prison.fined_total
	prison.on_outpost_abandoned()
	TEST_ASSERT(!prison.intake_open, "Abandoning left intake open")
	TEST_ASSERT_EQUAL(prison.pay_owed, 0, "Abandoning kept the stipend owed")
	for(var/mob/living/basic/outpost_prisoner/leaving as anything in prison.prisoners)
		TEST_ASSERT_EQUAL(leaving.phase, "leaving", "[leaving] was not transferred out")
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_prison_economy_kit, roster_empty), prison), 6 SECONDS), "The transfers never took everyone")
	prison.tick(1)
	TEST_ASSERT_EQUAL(treasury.account_balance, 1234, "Abandoning moved [treasury.account_balance - 1234] cr")
	TEST_ASSERT_EQUAL(treasury.account_debt, debt_before, "Abandoning changed the debt")
	TEST_ASSERT_EQUAL(prison.paid_total, paid_before, "Abandoning paid a bonus or stipend")
	TEST_ASSERT_EQUAL(prison.fined_total, fined_before, "Abandoning fined the treasury")
	settle_prison_air(home)

/datum/unit_test/voidcrew_outpost_prison_cells/proc/door_bolted(obj/machinery/door/airlock/door)
	return door?.locked

// ===== THE GAP BETWEEN ARRIVALS =====

/**
 * After any prisoner beams in, the next waits 30 seconds to 3 minutes (OUTPOST_PRISON_ARRIVAL_GAP_MIN,
 * _MAX), wing-wide, however many cells stand ready, and a long stretch brings one arrival, not a
 * crowd. A cell's own refill wait still holds when it is the longer. The console counts down to
 * whichever is longer, and an admin's forced arrival skips the gap but starts a new one.
 */
/datum/unit_test/voidcrew_outpost_prison_arrival_gap
	parent_type = /datum/unit_test/voidcrew_outpost_prison_economy_kit

/datum/unit_test/voidcrew_outpost_prison_arrival_gap/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("arrivalgapowner")
	TEST_ASSERT_NOTNULL(home, "The arrival gap test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)

	// Every cell ready at once; the first arrival comes 5 seconds after intake opens (OUTPOST_PRISON_FIRST_ARRIVAL).
	for(var/datum/outpost_prison_cell/cell as anything in prison.cells)
		cell.ready_at = world.time
	TEST_ASSERT(prison.set_intake(TRUE), "Intake would not open")
	prison.intake_tick(5)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 1, "[length(prison.prisoners)] prisoners arrived at once into four ready cells")

	// Three cells stand ready, and still the next waits out the gap, which the console counts down.
	var/gap = prison.arrival_gap
	TEST_ASSERT(gap >= 30 && gap <= 180, "The gap after an arrival is [gap] s, not 30-180")
	TEST_ASSERT_EQUAL(prison.arrival_countdown, gap, "The console does not count down the gap")
	prison.intake_tick(gap - 1)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 1, "A ready cell filled before the gap was up")
	TEST_ASSERT_EQUAL(prison.arrival_countdown, 1, "The console shows [prison.arrival_countdown] s with 1 s of the gap left")
	// A long stretch at once brings one prisoner, and a fresh gap, not the whole wing.
	prison.intake_tick(10 * 60)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 2, "Ten minutes at once brought [length(prison.prisoners) - 1] prisoners, not one")
	TEST_ASSERT(prison.arrival_gap >= 30, "No gap followed the second arrival")

	// The gap is rolled afresh each time, between 30 and 180 seconds.
	var/list/rolled = list()
	for(var/i in 1 to 30)
		prison.arrival_gap = 0
		prison.start_arrival_gap()
		TEST_ASSERT(prison.arrival_gap >= 30 && prison.arrival_gap <= 180, "A gap rolled [prison.arrival_gap] s, not 30-180")
		rolled |= prison.arrival_gap
	TEST_ASSERT(length(rolled) > 1, "Thirty gaps all came out [rolled[1]] s")

	// A cell's own refill wait, when it is the longer, is what the console shows and what holds them back.
	prison.arrival_gap = 20
	for(var/datum/outpost_prison_cell/cell as anything in prison.cells)
		if(!cell.occupant)
			cell.ready_at = world.time + 100 SECONDS
	prison.intake_tick(0)
	TEST_ASSERT(prison.arrival_countdown >= 99 && prison.arrival_countdown <= 100, "The console shows [prison.arrival_countdown] s, not the cells' 100 s wait")
	prison.intake_tick(30)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 2, "A prisoner arrived once the gap was up but no cell was ready")

	// An admin's forced arrival skips the gap and the cell's wait, and starts a new gap.
	prison.arrival_gap = 0
	var/mob/living/basic/outpost_prisoner/forced = prison.admit_next(TRUE)
	TEST_ASSERT_NOTNULL(forced, "The forced arrival did not come")
	TEST_ASSERT(prison.arrival_gap >= 30 && prison.arrival_gap <= 180, "A forced arrival left a [prison.arrival_gap] s gap, not 30-180")
	prison.arrival_gap = 150
	TEST_ASSERT_NOTNULL(prison.admit_next(TRUE), "A forced arrival waited for the gap")
	TEST_ASSERT(prison.arrival_gap >= 150, "A forced arrival shortened the gap to [prison.arrival_gap] s")
	TEST_ASSERT_EQUAL(length(prison.prisoners), 4, "The forced arrivals did not fill the wing")
	prison.set_intake(FALSE)
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_prison_economy_kit, all_present), prison), 8 SECONDS), "The arrivals never finished beaming in")
	for(var/mob/living/basic/outpost_prisoner/arrival as anything in prison.prisoners)
		ADD_TRAIT(arrival, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	settle_prison_air(home)

// ===== ABANDONING MID-INCIDENT =====

/**
 * Abandoning the outpost while prisoners riot, break out or run loose counts them as escaped:
 * 1000 each (OUTPOST_PRISON_ESCAPE_FINE) as one incident, capped at 2500
 * (OUTPOST_PRISON_INCIDENT_FINE_CAP), and what the treasury cannot cover is debt. Otherwise
 * abandoning mid-riot and claiming the outpost back skipped the fines. Whoever claims it next
 * inherits the debt, and intake stays shut until it is paid.
 */
/datum/unit_test/voidcrew_outpost_prison_abandon_fines
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_abandon_fines/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("abandonfinesowner")
	TEST_ASSERT_NOTNULL(home, "The abandonment test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 9, 3), "abandonfinesowner")
	var/mob/living/basic/outpost_prisoner/rioter = trouble_prisoner(prison, prison_spot(home, 4, 10))
	var/mob/living/basic/outpost_prisoner/breaking_out = trouble_prisoner(prison, prison_spot(home, 5, 10))
	var/mob/living/basic/outpost_prisoner/runner = trouble_prisoner(prison, prison_spot(home, 6, 10))
	var/mob/living/basic/outpost_prisoner/quiet = trouble_prisoner(prison, prison_spot(home, 12, 10))
	var/datum/bank_account/treasury = trouble_fund(home, 1500)
	treasury.account_debt = 0
	rioter.start_rioting(shout = FALSE)
	breaking_out.trouble = "breakout" // PRISONER_TROUBLE_BREAKOUT
	runner.trouble = "loose" // PRISONER_TROUBLE_LOOSE, left off the patrol AI
	prison.begin_incident()

	// Three out of hand: 3000 in fines, capped at 2500; the 1500 held is taken and 1000 is owed.
	home.abandon(owner)
	TEST_ASSERT_NULL(home.founder_ckey, "The outpost was not abandoned")
	TEST_ASSERT_EQUAL(treasury.account_balance, 0, "Abandoning mid-riot left [treasury.account_balance] cr in the treasury")
	TEST_ASSERT_EQUAL(treasury.account_debt, 1000, "Abandoning mid-riot left [treasury.account_debt] cr of debt, not 1000")
	TEST_ASSERT(!prison.incident_open, "The incident stayed open after the abandonment")
	TEST_ASSERT(!prison.intake_open, "Abandoning left intake open")
	for(var/mob/living/basic/outpost_prisoner/leaving as anything in list(rioter, breaking_out, runner, quiet))
		TEST_ASSERT_EQUAL(leaving.phase, "leaving", "[leaving] was not transferred out") // PRISONER_LEAVING

	// The next claimant inherits the debt, and intake stays shut until it is paid.
	var/mob/living/carbon/human/claimant = make_player(prison_spot(home, 9, 3), "abandonfinesclaimant")
	home.founder_ckey = "abandonfinesclaimant"
	TEST_ASSERT_EQUAL(prison.intake_state(), "debt", "The claimant's intake shows [prison.intake_state()], not the inherited debt")
	TEST_ASSERT(!prison.set_intake(TRUE, claimant), "Intake opened with the abandoned outpost's fines unpaid")
	// A deposit goes to the debt first (debt collection); the console's pay button settles the rest.
	treasury.adjust_money(1000, "Prison test")
	prison.pay_treasury_debt(claimant)
	TEST_ASSERT_EQUAL(treasury.account_debt, 0, "The claimant could not pay off the inherited debt")
	TEST_ASSERT(prison.set_intake(TRUE, claimant), "Intake stayed shut after the inherited debt was paid")
	settle_prison_air(home)
