/**
 * Outpost prison comings and goings: how well prisoners are kept, lost prisoners, the cells,
 * arrivals, releases and deaths.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with
 * the define named beside them. Prisons are driven with tick(seconds) with their own processing
 * stopped, never by waiting in real time, except for beams, which run on timers. Each cell's ready
 * time is a world.time, which tick() does not move, so tests set it to now to end a wait. Other
 * packages' inputs (hunger, grime, health, condition scores, confinement) are pinned directly,
 * and how well a prisoner is kept is worked out from conditions_score() and care(), which other
 * packages own. Shared fixtures are in voidcrew_outpost_prison_helpers.dm.
 */

/// This file's fixtures, shared by its tests
/datum/unit_test/voidcrew_outpost_prison_economy_kit
	parent_type = /datum/unit_test/voidcrew_outpost_management
	abstract_type = /datum/unit_test/voidcrew_outpost_prison_economy_kit

/// A prisoner booked in and standing still at `spot`: fed, in a clean uniform and unhurt
/datum/unit_test/voidcrew_outpost_prison_economy_kit/proc/kept_prisoner(datum/outpost_prison/prison, turf/spot)
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = test_prisoner(prison, spot)
	set_health_percent(prisoner, 100)
	return prisoner

/// Sets a prisoner's health to `percent` of their maximum
/datum/unit_test/voidcrew_outpost_prison_economy_kit/proc/set_health_percent(mob/living/carbon/human/npc/outpost_prisoner/prisoner, percent)
	// Limbs count for less of a body's health than the chest, so this measures as it bruises.
	outpost_prison_set_health(prisoner, prisoner.maxHealth * percent / 100)

/// Every bulb in the wing working (tg breaks a few at load) and drawn, and the condition scores refreshed
/datum/unit_test/voidcrew_outpost_prison_economy_kit/proc/fix_wing(datum/outpost_prison/prison)
	for(var/turf/tile as anything in prison.wing_turfs())
		for(var/obj/machinery/light/fixture in tile)
			if(fixture.status != LIGHT_OK)
				fixture.fix()
	// conditions_tick() only measures light once the fixtures are drawn and scans mess a budget at a time
	conditions_draw_lights(prison)
	prison.refresh_conditions()

/// The wing's conditions as kept_well() weighs them: 0.5 for the worst wing, 1 for the best
/datum/unit_test/voidcrew_outpost_prison_economy_kit/proc/conditions_factor(datum/outpost_prison/prison)
	return 0.5 + 0.5 * prison.conditions_score() / 100

/datum/unit_test/voidcrew_outpost_prison_economy_kit/proc/all_present(datum/outpost_prison/prison)
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner in prison.prisoners)
		if(prisoner.phase != "present")
			return FALSE
	return TRUE

/datum/unit_test/voidcrew_outpost_prison_economy_kit/proc/roster_empty(datum/outpost_prison/prison)
	return !length(prison.prisoners)

// ===== HOW WELL THEY ARE KEPT =====

/datum/unit_test/voidcrew_outpost_prison_economy
	parent_type = /datum/unit_test/voidcrew_outpost_prison_economy_kit

/datum/unit_test/voidcrew_outpost_prison_economy/Run()
	var/obj/structure/overmap/trader_outpost/prison_test_host/home = prison_test_claim("payowner")
	TEST_ASSERT_NOTNULL(home, "The economy test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	fix_wing(prison)
	// kept_well() is G(care) x (0.5 + 0.5 x conditions / 100).
	var/conditions = conditions_factor(prison)
	TEST_ASSERT(conditions >= 0.5 && conditions <= 1, "The wing's conditions factor is [conditions]")

	var/mob/living/carbon/human/npc/outpost_prisoner/kept = kept_prisoner(prison, prison_spot(home, 3, 8))
	var/mob/living/carbon/human/npc/outpost_prisoner/other = kept_prisoner(prison, prison_spot(home, 12, 8))

	// Full care: kept as well as the wing's conditions allow.
	TEST_ASSERT(abs(kept.care() - 100) < 0.01, "A well kept prisoner's care was [kept.care()]")
	TEST_ASSERT(abs(prison.kept_well(kept) - conditions) < 0.001, "Full care was kept [prison.kept_well(kept)], not the conditions factor [conditions]")

	// Starving and nothing else wrong: two thirds care, so not kept well at all (G is 0 at or below
	// 70% care, OUTPOST_PRISON_GRADE_FLOOR, and 1 from 95%, _GRADE_FULL).
	other.set_hunger(0)
	TEST_ASSERT_EQUAL(prison.kept_well(other), 0, "A starving prisoner was still kept [prison.kept_well(other)]")
	other.set_hunger(100)

	// Care 82 (fed, clean, 46% health): 0.48 of the best.
	set_health_percent(other, 46)
	TEST_ASSERT(abs(other.care() - 82) < 0.01, "Fed, clean and at 46% health came to care [other.care()], not 82")
	TEST_ASSERT(abs(prison.kept_well(other) - 0.48 * conditions) < 0.001, "Care 82 was kept [prison.kept_well(other)], not 0.48 of the best")
	set_health_percent(other, 100)

	// A stained arrival is kept short until they change.
	other.set_uniform_grime(62)
	var/stained_care = other.care()
	TEST_ASSERT(stained_care < 95, "A stained uniform left care at [stained_care]")
	var/stained_grade = clamp((stained_care - 70) / 25, 0, 1)
	TEST_ASSERT(abs(prison.kept_well(other) - stained_grade * conditions) < 0.001, "A stained arrival was kept [prison.kept_well(other)], not G(care) x conditions")
	if(abs(other.clean_factor() - 60) < 0.5)
		TEST_ASSERT(abs(stained_grade - 0.667) < 0.01, "A stained arrival graded [stained_grade], not about 0.67")
	other.set_uniform_grime(0)
	TEST_ASSERT(abs(prison.kept_well(other) - conditions) < 0.001, "A changed prisoner did not go back to being kept well")

	// Conditions are one factor: pinned at 50, full care is kept 0.5 + 0.5 x the score.
	prison.clean_score = 50
	prison.lit_score = 50
	prison.powered_score = 50
	var/half_conditions = conditions_factor(prison)
	TEST_ASSERT(half_conditions >= 0.5 && half_conditions < 1, "Conditions 50 give a factor of [half_conditions]")
	TEST_ASSERT(abs(prison.kept_well(kept) - half_conditions) < 0.001, "At conditions 50 full care was kept [prison.kept_well(kept)], not [half_conditions]")
	fix_wing(prison)
	TEST_ASSERT(abs(conditions_factor(prison) - conditions) < 0.001, "The wing's conditions did not come back after the pin")

	// Confined to a cell for more than 2 minutes (OUTPOST_PRISON_CONFINED_SOUR_AFTER): not kept
	// well, unless it is protective custody.
	kept.locked_in_seconds = 120
	TEST_ASSERT(prison.kept_well(kept) > 0, "Two minutes confined already counted as badly kept")
	kept.locked_in_seconds = 121
	TEST_ASSERT_EQUAL(prison.kept_well(kept), 0, "Over two minutes confined still counted as kept well")
	prison.riot_active = TRUE
	TEST_ASSERT_EQUAL(prison.kept_well(kept) > 0, !!prison.protective_custody(), "Protective custody and how well kept disagree for a confined prisoner")
	prison.riot_active = FALSE
	kept.locked_in_seconds = 0

	// Nothing while in trouble, dead or not present.
	other.trouble = "fight" // PRISONER_TROUBLE_FIGHT
	TEST_ASSERT_EQUAL(prison.kept_well(other), 0, "A fighter counted as kept well")
	other.trouble = null
	other.phase = "arriving" // PRISONER_ARRIVING
	TEST_ASSERT_EQUAL(prison.kept_well(other), 0, "A prisoner in the beam counted as kept well")
	other.phase = "present"

	// Shut in their bolted cell, a prisoner is confined.
	var/turf/kept_spot = kept.loc
	var/datum/outpost_prison_cell/kept_cell = kept.cell
	kept.forceMove(kept_cell.arrival_turf())
	capture_bolt(prison, kept_cell)
	TEST_ASSERT(kept.is_confined(), "The prisoner is not shut in their bolted cell")
	capture_bolt(prison, kept_cell, FALSE)
	kept.forceMove(kept_spot)
	prison.refresh_reach()

	// A stay is averaged: a minute kept in full, a minute at care 82, and the release is logged.
	qdel(other)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 1, "Deleting a prisoner left them on the roster")
	kept.set_hunger(100)
	kept.set_uniform_grime(0)
	kept.sentence_left = 120
	kept.served_seconds = 0
	kept.kept_seconds = 0
	var/first_factor = prison.kept_well(kept)
	prison.tick(60)
	TEST_ASSERT_EQUAL(kept.served_seconds, 60, "A minute's tick served [kept.served_seconds] s")
	TEST_ASSERT(abs(kept.kept_seconds - 60 * first_factor) < 0.01, "A minute kept in full counted [kept.kept_seconds] s kept, not [60 * first_factor]")
	set_health_percent(kept, 46)
	var/second_factor = prison.kept_well(kept)
	TEST_ASSERT(abs(second_factor - 0.48 * first_factor) < 0.001, "The second minute's factor is [second_factor]")
	var/kept_name = kept.real_name
	prison.tick(60)
	TEST_ASSERT_EQUAL(kept.phase, "leaving", "A prisoner whose sentence ended was not being beamed out") // PRISONER_LEAVING
	TEST_ASSERT_EQUAL(kept.served_seconds, 120, "The stay served [kept.served_seconds] s, not 120")
	TEST_ASSERT(abs(kept.kept_seconds - 60 * (first_factor + second_factor)) < 0.01, "The stay counted [kept.kept_seconds] s kept, not [60 * (first_factor + second_factor)]")
	var/list/newest = prison.entries[1]
	TEST_ASSERT(findtext(newest["text"], kept_name) && findtext(newest["text"], "released"), "The release was not logged first: [newest["text"]]")
	TEST_ASSERT(!prison.release(kept), "A prisoner already being beamed out was released again")
	// A prisoner present in the yard is released at once.
	var/mob/living/carbon/human/npc/outpost_prisoner/half = kept_prisoner(prison, prison_spot(home, 12, 8))
	half.served_seconds = 600
	half.kept_seconds = 300
	TEST_ASSERT(prison.release(half), "A present prisoner was not released")
	TEST_ASSERT_EQUAL(half.phase, "leaving", "A released prisoner was not being beamed out")
	TEST_ASSERT(wait_until(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(is_qdeleted_ref), WEAKREF(kept)), 6 SECONDS), "The released prisoner was never beamed out")

	// A newcomer takes the mood the yard gives them.
	var/mob/living/carbon/human/npc/outpost_prisoner/settled = kept_prisoner(prison, prison_spot(home, 10, 8))
	settled.set_mood(40)
	var/expected_mood = prison.arrival_mood()
	var/mob/living/carbon/human/npc/outpost_prisoner/newcomer = kept_prisoner(prison, prison_spot(home, 8, 8))
	TEST_ASSERT(abs(newcomer.mood - expected_mood) < 0.01, "A newcomer arrived at mood [newcomer.mood], not the arrival mood [expected_mood]")
	settle_prison_air(home)

// ===== LOST PRISONERS =====

/datum/unit_test/voidcrew_outpost_prison_fines
	parent_type = /datum/unit_test/voidcrew_outpost_prison_economy_kit

/datum/unit_test/voidcrew_outpost_prison_fines/Run()
	var/obj/structure/overmap/trader_outpost/prison_test_host/home = prison_test_claim("fineowner")
	TEST_ASSERT_NOTNULL(home, "The lost prisoners test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 7, 4), "fineowner")

	// Lost prisoners are counted over 30 minutes (OUTPOST_PRISON_LOST_WINDOW) and never shut intake.
	TEST_ASSERT(prison.set_intake(TRUE, owner), "Intake would not open")
	TEST_ASSERT_EQUAL(prison.intake_state(), "open", "Open intake shows as [prison.intake_state()]")
	prison.note_prisoner_lost(null, "escaped")
	prison.note_prisoner_lost(null, "transferred")
	TEST_ASSERT_EQUAL(prison.lost_recently(), 2, "Two lost prisoners counted as [prison.lost_recently()]")
	TEST_ASSERT(prison.intake_open, "Lost prisoners shut intake")
	// A loss from longer ago than the window does not count.
	prison.lost_log = list(world.time - 31 MINUTES)
	TEST_ASSERT_EQUAL(prison.lost_recently(), 0, "A loss from 31 minutes ago still counted")
	prison.note_prisoner_lost(null, "escaped")
	TEST_ASSERT_EQUAL(prison.lost_recently(), 1, "A fresh loss after an old one counted as [prison.lost_recently()]")
	TEST_ASSERT(prison.set_intake(FALSE, owner), "Intake would not close")
	TEST_ASSERT_EQUAL(prison.intake_state(), "closed", "Closed intake shows as [prison.intake_state()]")
	settle_prison_air(home)

// ===== CELLS, ARRIVALS AND RELEASES =====

/datum/unit_test/voidcrew_outpost_prison_cells
	parent_type = /datum/unit_test/voidcrew_outpost_prison_economy_kit

/datum/unit_test/voidcrew_outpost_prison_cells/Run()
	var/obj/structure/overmap/trader_outpost/prison_test_host/home = prison_test_claim("cellsowner")
	TEST_ASSERT_NOTNULL(home, "The cells test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 7, 4), "cellsowner")

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

	TEST_ASSERT_EQUAL(prison.free_slots(), 4, "The prison does not hold 4") // OUTPOST_PRISON_CAPACITY
	TEST_ASSERT_NULL(prison.arrival_countdown, "An arrival was due with intake closed")
	TEST_ASSERT_EQUAL(prison.intake_state(), "closed", "Closed intake shows as [prison.intake_state()]")

	// Opening intake: the first prisoner is due in 5 seconds (OUTPOST_PRISON_FIRST_ARRIVAL).
	TEST_ASSERT(prison.set_intake(TRUE, owner), "Intake would not open")
	TEST_ASSERT(prison.intake_open, "Intake did not open")
	TEST_ASSERT_EQUAL(prison.arrival_countdown, 5, "The first prisoner is not due in 5 seconds")
	TEST_ASSERT_EQUAL(prison.intake_state(), "open", "Open intake does not show as open")

	// One at a time, each into their own cell, 30 seconds to 3 minutes apart (OUTPOST_PRISON_ARRIVAL_GAP_*).
	prison.tick(4)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 0, "A prisoner arrived early")
	prison.tick(1)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 1, "Only one prisoner should arrive at a time")
	var/mob/living/carbon/human/npc/outpost_prisoner/first = prison.prisoners[1]
	// The fixture wing has no Processing room, so an arrival is simply in their cell (outpost_prison_processing.dm).
	TEST_ASSERT_EQUAL(first.console_status(), "present", "An arrival in a wing with no Processing room is [first.console_status()], not present")
	TEST_ASSERT(first.came_by_intake, "An arrival through intake was not marked as one")
	var/list/seen_cells = list()
	for(var/i in 1 to 3)
		var/gap = prison.arrival_countdown
		TEST_ASSERT(gap >= 30 && gap <= 180, "The next arrival is [gap] s away, not 30-180")
		prison.tick(gap - 1)
		TEST_ASSERT_EQUAL(length(prison.prisoners), i, "A prisoner arrived before the gap was up")
		prison.tick(1)
		TEST_ASSERT_EQUAL(length(prison.prisoners), i + 1, "No prisoner arrived when the gap was up")
	for(var/mob/living/carbon/human/npc/outpost_prisoner/arrival as anything in prison.prisoners)
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
	for(var/mob/living/carbon/human/npc/outpost_prisoner/arrival as anything in prison.prisoners)
		TEST_ASSERT(!HAS_TRAIT(arrival, TRAIT_IMMOBILIZED), "[arrival] was still held after beaming in")
		ADD_TRAIT(arrival, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
		// Long enough that the rest of the test releases nobody by accident.
		arrival.sentence_left = 3600
	TEST_ASSERT_EQUAL(length(prison.entries), 4, "The arrivals were not logged")
	// Long after the last arrival: from here only each cell's own wait holds arrivals back
	// (voidcrew_outpost_prison_arrival_gap tests the gap between arrivals).
	prison.arrival_gap = 0

	TEST_ASSERT_NULL(prison.arrival_countdown, "An arrival was due with the prison full")

	// Staff doors: shut to prisoners whether open or closed, free to the wing's members.
	var/mob/living/carbon/human/npc/outpost_prisoner/tester = prison.prisoners[1]
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
	var/mob/living/carbon/human/npc/outpost_prisoner/leaver = prison.prisoners[2]
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
	TEST_ASSERT_EQUAL(leaver.phase, "leaving", "A released prisoner was not leaving")
	TEST_ASSERT(wait_until(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(is_qdeleted_ref), leaver_ref), 6 SECONDS), "The released prisoner never left")
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
	prison.set_intake(FALSE, owner)
	TEST_ASSERT(!prison.intake_open, "Intake would not close")
	var/mob/living/carbon/human/npc/outpost_prisoner/removed = prison.prisoners[4]
	var/datum/outpost_prison_cell/removed_cell = removed.cell
	qdel(removed)
	var/removed_ready = removed_cell.ready_at
	TEST_ASSERT(removed_ready > world.time, "A freed cell was ready at once")
	prison.tick(10 * 60)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 3, "A prisoner arrived with intake closed")
	TEST_ASSERT_NULL(prison.arrival_countdown, "An arrival was due with intake closed")
	prison.set_intake(TRUE, owner)
	prison.set_intake(FALSE, owner)
	prison.set_intake(TRUE, owner)
	TEST_ASSERT(prison.intake_open, "Intake is not open after three toggles")
	TEST_ASSERT_EQUAL(removed_cell.ready_at, removed_ready, "Toggling intake moved the cell's ready time")
	prison.tick(45)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 3, "Toggling intake skipped the freed cell's wait")
	removed_cell.ready_at = world.time
	prison.tick(1)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 4, "The reopened intake did not refill the ready cell")
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_prison_economy_kit, all_present), prison), 8 SECONDS), "The reopened intake's arrival never finished beaming in")
	for(var/mob/living/carbon/human/npc/outpost_prisoner/arrival as anything in prison.prisoners)
		ADD_TRAIT(arrival, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
		arrival.sentence_left = max(arrival.sentence_left, 3600)

	// A death is logged. Nobody comes for the body: it keeps its cell while it lies in the cell block
	// and sours the yard; carried out, it leaves the roster and the cell waits a refill.
	var/mob/living/carbon/human/npc/outpost_prisoner/victim = prison.prisoners[1]
	var/datum/outpost_prison_cell/victim_cell = victim.cell
	var/mob/living/carbon/human/npc/outpost_prisoner/witness = prison.prisoners[2]
	var/drift_before = witness.mood_drift_per_minute()
	victim.death()
	TEST_ASSERT_EQUAL(victim.console_status(), "dead", "A dead prisoner was not listed as dead")
	TEST_ASSERT_EQUAL(victim.body_position, LYING_DOWN, "A dead prisoner did not fall down")
	var/list/newest = prison.entries[1]
	TEST_ASSERT(findtext(newest["text"], "died"), "The death was not logged first: [newest["text"]]")
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
	var/mob/living/carbon/human/npc/outpost_prisoner/gibbed = prison.prisoners[1]
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

	settle_prison_air(home)

/datum/unit_test/voidcrew_outpost_prison_cells/proc/door_bolted(obj/machinery/door/airlock/door)
	return door?.locked

// ===== THE GAP BETWEEN ARRIVALS =====

/**
 * After any prisoner beams in, the next waits 30 seconds to 3 minutes (OUTPOST_PRISON_ARRIVAL_GAP_MIN,
 * _MAX), wing-wide, however many cells stand ready, and a long stretch brings one arrival, not a
 * crowd. A cell's own refill wait still holds when it is the longer. The countdown runs to
 * whichever is longer, and an admin's forced arrival skips the gap but starts a new one.
 */
/datum/unit_test/voidcrew_outpost_prison_arrival_gap
	parent_type = /datum/unit_test/voidcrew_outpost_prison_economy_kit

/datum/unit_test/voidcrew_outpost_prison_arrival_gap/Run()
	var/obj/structure/overmap/trader_outpost/prison_test_host/home = prison_test_claim("arrivalgapowner")
	TEST_ASSERT_NOTNULL(home, "The arrival gap test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)

	// Every cell ready at once; the first arrival comes 5 seconds after intake opens (OUTPOST_PRISON_FIRST_ARRIVAL).
	for(var/datum/outpost_prison_cell/cell as anything in prison.cells)
		cell.ready_at = world.time
	TEST_ASSERT(prison.set_intake(TRUE), "Intake would not open")
	prison.intake_tick(5)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 1, "[length(prison.prisoners)] prisoners arrived at once into four ready cells")

	// Three cells stand ready, and still the next waits out the gap, which the countdown shows.
	var/gap = prison.arrival_gap
	TEST_ASSERT(gap >= 30 && gap <= 180, "The gap after an arrival is [gap] s, not 30-180")
	TEST_ASSERT_EQUAL(prison.arrival_countdown, gap, "The countdown does not show the gap")
	prison.intake_tick(gap - 1)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 1, "A ready cell filled before the gap was up")
	TEST_ASSERT_EQUAL(prison.arrival_countdown, 1, "The countdown shows [prison.arrival_countdown] s with 1 s of the gap left")
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

	// A cell's own refill wait, when it is the longer, is what the countdown shows and what holds them back.
	prison.arrival_gap = 20
	for(var/datum/outpost_prison_cell/cell as anything in prison.cells)
		if(!cell.occupant)
			cell.ready_at = world.time + 100 SECONDS
	prison.intake_tick(0)
	TEST_ASSERT(prison.arrival_countdown >= 99 && prison.arrival_countdown <= 100, "The countdown shows [prison.arrival_countdown] s, not the cells' 100 s wait")
	prison.intake_tick(30)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 2, "A prisoner arrived once the gap was up but no cell was ready")

	// An admin's forced arrival skips the gap and the cell's wait, and starts a new gap.
	prison.arrival_gap = 0
	var/mob/living/carbon/human/npc/outpost_prisoner/forced = prison.admit_next(TRUE)
	TEST_ASSERT_NOTNULL(forced, "The forced arrival did not come")
	TEST_ASSERT(prison.arrival_gap >= 30 && prison.arrival_gap <= 180, "A forced arrival left a [prison.arrival_gap] s gap, not 30-180")
	prison.arrival_gap = 150
	TEST_ASSERT_NOTNULL(prison.admit_next(TRUE), "A forced arrival waited for the gap")
	TEST_ASSERT(prison.arrival_gap >= 150, "A forced arrival shortened the gap to [prison.arrival_gap] s")
	TEST_ASSERT_EQUAL(length(prison.prisoners), 4, "The forced arrivals did not fill the wing")
	prison.set_intake(FALSE)
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_prison_economy_kit, all_present), prison), 8 SECONDS), "The arrivals never finished beaming in")
	for(var/mob/living/carbon/human/npc/outpost_prisoner/arrival as anything in prison.prisoners)
		ADD_TRAIT(arrival, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	settle_prison_air(home)
