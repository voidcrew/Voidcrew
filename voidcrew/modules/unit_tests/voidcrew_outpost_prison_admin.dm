/**
 * The Outpost Manipulator's Prison tools (manage_prison(), prison_admin_data()): the data and every
 * admin action, for the quiet side of the prison and for trouble.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with
 * the define named beside them. Prisons are driven with tick(seconds) with their own processing
 * stopped, never by waiting in real time, except for beams, which run on timers. Fixtures are
 * in voidcrew_outpost_prison_helpers.dm.
 */

// ===== ADMIN TOOLS =====

/// Counts what the manipulator logs, without an admin client
/datum/outpost_manipulator/unit_test/prison
	var/list/operations = list()

/datum/outpost_manipulator/unit_test/prison/record_prison(mob/user, datum/outpost_prison/prison, operation)
	operations += operation
	return ..()

/datum/unit_test/voidcrew_outpost_prison_admin
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_admin/proc/all_present(datum/outpost_prison/prison)
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner in prison.prisoners)
		if(prisoner.phase != "present")
			return FALSE
	return TRUE

/datum/unit_test/voidcrew_outpost_prison_admin/Run()
	var/obj/structure/overmap/trader_outpost/prison_test_host/home = prison_test_claim("prisonadminowner")
	TEST_ASSERT_NOTNULL(home, "The admin test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/operator = make_player(prison_spot(home, 8, 4), "prisonadmin")
	var/datum/outpost_manipulator/unit_test/prison/panel = allocate(__IMPLIED_TYPE__, operator)

	// The Prison section for a lockup; null for a lockup that is gone.
	var/list/section = panel.prison_admin_data(prison)
	TEST_ASSERT(islist(section), "The lockup sends no prison section")
	for(var/key in list("intake_open", "next_arrival", "powered", "conditions", "cells", "prisoners"))
		TEST_ASSERT(key in section, "The prison section sends no [key]")
	TEST_ASSERT_EQUAL(length(section["cells"]), 4, "The prison section lists [length(section["cells"])] cells")
	for(var/list/cell_row as anything in section["cells"])
		TEST_ASSERT(("number" in cell_row) && ("occupant_ref" in cell_row), "A cell row lacks its number or occupant")
	TEST_ASSERT_NULL(panel.prison_admin_data(null), "No lockup sent a prison section")

	// Only admins: a manipulator without R_ADMIN does nothing.
	var/datum/outpost_manipulator/unauthorized = allocate(/datum/outpost_manipulator, operator)
	unauthorized.manage_prison(prison, operator, "prison_spawn", list())
	unauthorized.manage_prison(prison, operator, "prison_intake", list("open" = 1))
	TEST_ASSERT_EQUAL(length(prison.prisoners), 0, "A non-admin spawned a prisoner")
	TEST_ASSERT(!prison.intake_open, "A non-admin opened intake")
	panel.allow_actions = FALSE
	panel.manage_prison(prison, operator, "prison_spawn", list())
	TEST_ASSERT_EQUAL(length(prison.prisoners), 0, "A revoked admin panel spawned a prisoner")
	panel.allow_actions = TRUE

	// Intake, validated.
	panel.manage_prison(prison, operator, "prison_intake", list("open" = "yes"))
	TEST_ASSERT(!prison.intake_open && panel.error, "A bad intake setting was accepted")
	panel.manage_prison(prison, operator, "prison_intake", list("open" = 1))
	TEST_ASSERT(prison.intake_open, "The admin could not open intake")
	panel.manage_prison(prison, operator, "prison_intake", list("open" = 0))
	TEST_ASSERT(!prison.intake_open, "The admin could not close intake")

	// Spawn one now, then fill the rest; nothing when full.
	panel.manage_prison(prison, operator, "prison_spawn", list())
	TEST_ASSERT_EQUAL(length(prison.prisoners), 1, "Spawn did not beam in one prisoner")
	var/mob/living/carbon/human/npc/outpost_prisoner/first = prison.prisoners[1]
	TEST_ASSERT_EQUAL(first.cell, prison.cells[1], "The spawned prisoner is not in a free cell")
	panel.manage_prison(prison, operator, "prison_fill", list())
	TEST_ASSERT_EQUAL(length(prison.prisoners), 4, "Fill did not fill every cell")
	panel.manage_prison(prison, operator, "prison_spawn", list())
	TEST_ASSERT(length(prison.prisoners) == 4 && panel.error, "Spawn into a full prison did not refuse")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(all_present), prison), 8 SECONDS), "The spawned prisoners never finished beaming in")
	for(var/mob/living/carbon/human/npc/outpost_prisoner/arrival as anything in prison.prisoners)
		ADD_TRAIT(arrival, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	section = panel.prison_admin_data(prison)
	TEST_ASSERT_EQUAL(length(section["prisoners"]), 4, "The prison section lists [length(section["prisoners"])] prisoners")
	var/list/first_row = section["prisoners"][1]
	for(var/key in list("ref", "name", "cell", "personality", "crime", "activity", "hunger", "grime", "health", "care", "kept", "sentence_left", "dead", "locked_in"))
		TEST_ASSERT(key in first_row, "A prisoner row sends no [key]")
	TEST_ASSERT(istext(first_row["activity"]) && length(first_row["activity"]), "A prisoner row has no activity text")
	var/list/first_cell_row = section["cells"][1]
	TEST_ASSERT_EQUAL(first_cell_row["occupant_ref"], REF(first), "Cell 1's row does not name its prisoner")

	// Per-prisoner settings, validated.
	var/ref = REF(first)
	panel.manage_prison(prison, operator, "prison_set", list("ref" = ref, "field" = "hunger", "value" = 20))
	TEST_ASSERT(abs(first.hunger - 20) < 0.01, "Setting hunger left it at [first.hunger]")
	panel.manage_prison(prison, operator, "prison_set", list("ref" = ref, "field" = "grime", "value" = "70"))
	TEST_ASSERT(abs(first.uniform_grime - 70) < 0.01, "Setting grime left it at [first.uniform_grime]")
	panel.manage_prison(prison, operator, "prison_set", list("ref" = ref, "field" = "health", "value" = 50))
	TEST_ASSERT(abs(first.health_factor() - 50) < 0.01, "Setting health left it at [first.health_factor()]")
	panel.manage_prison(prison, operator, "prison_set", list("ref" = ref, "field" = "sentence", "value" = 1000))
	TEST_ASSERT_EQUAL(first.sentence_left, 1000, "Setting the sentence left it at [first.sentence_left]")
	panel.manage_prison(prison, operator, "prison_set", list("ref" = ref, "field" = "hunger", "value" = "lots"))
	TEST_ASSERT(abs(first.hunger - 20) < 0.01 && panel.error, "A non-number setting was accepted")
	panel.manage_prison(prison, operator, "prison_set", list("ref" = ref, "field" = "happiness", "value" = 5))
	TEST_ASSERT(panel.error, "An unknown field was accepted")
	panel.manage_prison(prison, operator, "prison_set", list("ref" = "not a ref", "field" = "hunger", "value" = 5))
	TEST_ASSERT(panel.error, "A bad prisoner reference was accepted")
	panel.manage_prison(prison, operator, "prison_set", list("ref" = REF(operator), "field" = "hunger", "value" = 5))
	TEST_ASSERT(panel.error, "A non-prisoner reference was accepted")

	// Everyone at once.
	panel.manage_prison(prison, operator, "prison_all", list("what" = "starve"))
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner as anything in prison.prisoners)
		TEST_ASSERT(prisoner.hunger < 0.01, "Starve all left [prisoner] at [prisoner.hunger]")
	panel.manage_prison(prison, operator, "prison_all", list("what" = "feed"))
	panel.manage_prison(prison, operator, "prison_all", list("what" = "dirty"))
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner as anything in prison.prisoners)
		TEST_ASSERT(prisoner.hunger > 99.99 && prisoner.uniform_grime > 99.99, "Feed and dirty all missed [prisoner]")
	panel.manage_prison(prison, operator, "prison_all", list("what" = "clean"))
	panel.manage_prison(prison, operator, "prison_all", list("what" = "hurt"))
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner as anything in prison.prisoners)
		TEST_ASSERT(prisoner.uniform_grime < 0.01 && prisoner.health < prisoner.maxHealth && prisoner.stat != DEAD, "Clean and hurt all missed [prisoner] or killed them")
	panel.manage_prison(prison, operator, "prison_all", list("what" = "heal"))
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner as anything in prison.prisoners)
		TEST_ASSERT_EQUAL(prisoner.health, prisoner.maxHealth, "Heal all missed [prisoner]")
	panel.manage_prison(prison, operator, "prison_all", list("what" = "riot"))
	TEST_ASSERT(panel.error, "An unknown prisoner-wide action was accepted")

	// Time, mess, lights and power.
	var/mob/living/carbon/human/npc/outpost_prisoner/second = prison.prisoners[2]
	var/sentence_before = second.sentence_left
	panel.manage_prison(prison, operator, "prison_advance", list("minutes" = 2))
	TEST_ASSERT_EQUAL(sentence_before - second.sentence_left, 120, "Advancing 2 minutes took [sentence_before - second.sentence_left] s off a sentence")
	for(var/bad_minutes in list(0, 61, 1.5, "soon"))
		panel.manage_prison(prison, operator, "prison_advance", list("minutes" = bad_minutes))
		TEST_ASSERT(panel.error, "Advancing by [bad_minutes] minutes was accepted")
	// Measured as the mess the wing holds: Clean itself only drops past PRISON_MESS_FREE, and the hurt above
	// may already have bled on the floor (real wounds), so the score alone says little here.
	prison.refresh_conditions()
	var/mess_before = prison.mess_load
	panel.manage_prison(prison, operator, "prison_mess", list())
	TEST_ASSERT(prison.mess_load > mess_before, "Spawning mess did not dirty the wing (mess [mess_before] to [prison.mess_load])")
	// Lit is measured light, so glow from machines and the outer windows keeps it above 0 with
	// every bulb broken; the wing must still count as dark (PRISON_DARK_BELOW 50).
	var/lit_before = prison.lit_score
	panel.manage_prison(prison, operator, "prison_break_lights", list())
	TEST_ASSERT(prison.lit_score < lit_before && prison.lit_score < 50, "Breaking the lights left the wing [prison.lit_score]% lit (was [lit_before]%)")
	// A cut only drops Power once the outage debt passes its grace (PRISON_POWER_GRACE 30) and
	// ramp (PRISON_POWER_RAMP 90), so the debt is pushed to the end of the ramp.
	panel.manage_prison(prison, operator, "prison_power", list("on" = 0))
	TEST_ASSERT_EQUAL(prison.powered_score, 100, "Cutting power dropped Power before the grace ran out")
	panel.manage_prison(prison, operator, "prison_outage", list("seconds" = 120))
	TEST_ASSERT_EQUAL(prison.powered_score, 0, "A cut past its grace and ramp left the wing [prison.powered_score]% powered")
	panel.manage_prison(prison, operator, "prison_power", list("on" = 2))
	TEST_ASSERT(panel.error && !prison.powered_score, "A bad power setting was accepted")
	panel.manage_prison(prison, operator, "prison_power", list("on" = 1))
	TEST_ASSERT_EQUAL(prison.powered_score, 100, "Restoring power left the wing unpowered")

	// Release, kill, remove.
	var/mob/living/carbon/human/npc/outpost_prisoner/third = prison.prisoners[3]
	var/mob/living/carbon/human/npc/outpost_prisoner/fourth = prison.prisoners[4]
	panel.manage_prison(prison, operator, "prison_release", list("ref" = REF(first)))
	TEST_ASSERT_EQUAL(first.phase, "leaving", "Release did not beam the prisoner out")
	panel.manage_prison(prison, operator, "prison_kill", list("ref" = REF(third)))
	TEST_ASSERT_EQUAL(third.stat, DEAD, "Kill did not kill the prisoner")
	panel.manage_prison(prison, operator, "prison_kill", list("ref" = REF(third)))
	TEST_ASSERT(panel.error, "Killing a body again was accepted")
	var/datum/outpost_prison_cell/fourth_cell = fourth.cell
	panel.manage_prison(prison, operator, "prison_remove", list("ref" = REF(fourth)))
	TEST_ASSERT(QDELETED(fourth), "Remove did not delete the prisoner")
	TEST_ASSERT_NULL(fourth_cell.occupant, "Remove did not free the cell")
	panel.manage_prison(prison, operator, "prison_release", list("ref" = REF(third)))
	TEST_ASSERT(panel.error, "Releasing a body was accepted")

	// Every successful action was logged once; failed ones were not.
	TEST_ASSERT_EQUAL(length(panel.operations), 23, "The manipulator logged [length(panel.operations)] prison actions: [jointext(panel.operations, "; ")]")
	settle_prison_air(home)

// ===== TROUBLE ADMIN TOOLS =====

/datum/unit_test/voidcrew_outpost_prison_trouble_admin
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_trouble_admin/Run()
	var/obj/structure/overmap/trader_outpost/prison_test_host/home = trouble_test_claim("troubleadminowner")
	TEST_ASSERT_NOTNULL(home, "The trouble admin test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/operator = make_player(prison_spot(home, 8, 4), "troubleadmin")
	var/datum/outpost_manipulator/unit_test/prison/panel = allocate(__IMPLIED_TYPE__, operator)
	var/mob/living/carbon/human/npc/outpost_prisoner/first = trouble_prisoner(prison, prison_spot(home, 7, 8))
	var/mob/living/carbon/human/npc/outpost_prisoner/second = trouble_prisoner(prison, prison_spot(home, 9, 8))
	var/mob/living/carbon/human/npc/outpost_prisoner/third = trouble_prisoner(prison, prison_spot(home, 12, 8))

	// The section carries tension, stage and the breakout countdown; each row mood, state and loose time.
	var/list/section = panel.prison_admin_data(prison)
	for(var/key in list("tension", "stage", "breakout_in"))
		TEST_ASSERT(key in section, "The prison section sends no [key]")
	TEST_ASSERT_EQUAL(section["stage"], "calm", "A calm wing's stage is [section["stage"]]")
	TEST_ASSERT_NULL(section["breakout_in"], "A calm wing has a breakout countdown")
	var/list/row = section["prisoners"][1]
	for(var/key in list("mood", "state", "loose_left"))
		TEST_ASSERT(key in row, "A prisoner row sends no [key]")
	TEST_ASSERT_EQUAL(row["state"], "normal", "A calm prisoner's state is [row["state"]]")
	TEST_ASSERT_NULL(row["loose_left"], "A prisoner in the yard has a loose countdown")

	// Mood, one and all.
	panel.manage_prison(prison, operator, "prison_set", list("ref" = REF(first), "field" = "mood", "value" = 20))
	TEST_ASSERT(abs(first.mood - 20) < 0.01, "Setting mood left it at [first.mood]")
	panel.manage_prison(prison, operator, "prison_set", list("ref" = REF(first), "field" = "mood", "value" = "lots"))
	TEST_ASSERT(panel.error && abs(first.mood - 20) < 0.01, "A non-number mood was accepted")
	panel.manage_prison(prison, operator, "prison_all", list("what" = "enrage"))
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner as anything in list(first, second, third))
		TEST_ASSERT(prisoner.mood < 20, "Enrage left [prisoner] at [prisoner.mood]")
	panel.manage_prison(prison, operator, "prison_all", list("what" = "calm"))
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner as anything in list(first, second, third))
		TEST_ASSERT(prisoner.mood > 99, "Calm all left [prisoner] at [prisoner.mood]")

	// A fight with the nearest other; refused with nobody free to fight.
	panel.manage_prison(prison, operator, "prison_fight", list("ref" = REF(first)))
	TEST_ASSERT(first.fight && first.fight == second.fight, "The admin fight did not pair the nearest prisoner")
	TEST_ASSERT_EQUAL(panel.prison_admin_data(prison)["prisoners"][1]["state"], "fighting", "A fighter's state is not fighting")
	panel.manage_prison(prison, operator, "prison_fight", list("ref" = REF(third)))
	TEST_ASSERT(panel.error, "A fight with nobody free to fight was accepted")
	TEST_ASSERT(isnull(third.trouble) && !third.fight, "A refused fight changed the prisoner")
	panel.manage_prison(prison, operator, "prison_calm", list())
	TEST_ASSERT(!first.fight && isnull(first.trouble), "Calm did not end the fight")
	TEST_ASSERT(abs(first.mood - 70) < 0.01, "Calm set mood to [first.mood], not 70")

	// A riot everyone joins; a second is refused.
	panel.manage_prison(prison, operator, "prison_riot", list())
	TEST_ASSERT(prison.riot_active, "The admin riot did not start")
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner as anything in list(first, second, third))
		TEST_ASSERT_EQUAL(prisoner.trouble, "riot", "[prisoner] stayed out of the admin riot")
	section = panel.prison_admin_data(prison)
	TEST_ASSERT_EQUAL(section["breakout_in"], 180, "The riot's breakout is due in [section["breakout_in"]]")
	TEST_ASSERT_EQUAL(section["prisoners"][1]["state"], "rioting", "A rioter's state is [section["prisoners"][1]["state"]]")
	panel.manage_prison(prison, operator, "prison_riot", list())
	TEST_ASSERT(panel.error, "A second riot was accepted")
	panel.manage_prison(prison, operator, "prison_calm", list())
	TEST_ASSERT(!prison.riot_active, "Calm did not end the riot")
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner as anything in list(first, second, third))
		TEST_ASSERT(isnull(prisoner.trouble) && !istype(prisoner.held_item, /obj/item/knife/shiv), "[prisoner] kept rioting after the calm")

	// A breakout: that prisoner alone riots and goes for the ways out, from where they stand, in the
	// quiet after the calm too; refused for someone already breaking out.
	var/turf/breakout_spot = get_turf(second)
	panel.manage_prison(prison, operator, "prison_breakout", list("ref" = REF(second)))
	TEST_ASSERT(!panel.error, "The admin breakout was refused: [panel.error]")
	TEST_ASSERT_EQUAL(second.trouble, "breakout", "The admin breakout left the prisoner [second.trouble]") // PRISONER_TROUBLE_BREAKOUT
	TEST_ASSERT_EQUAL(get_turf(second), breakout_spot, "The admin breakout moved the prisoner")
	TEST_ASSERT(prison.in_cell_block(second), "The admin breakout put the prisoner outside the cell block")
	TEST_ASSERT(prison.riot_active, "The admin breakout started no riot")
	TEST_ASSERT(isnull(first.trouble) && isnull(third.trouble), "Others joined a breakout of one")
	TEST_ASSERT_EQUAL(second.loose_left, 300, "The breakout's loose clock is [second.loose_left] s, not 300") // OUTPOST_PRISON_LOOSE_TIME
	var/list/breakout_row
	for(var/list/prisoner_row as anything in panel.prison_admin_data(prison)["prisoners"])
		if(prisoner_row["ref"] == REF(second))
			breakout_row = prisoner_row
	TEST_ASSERT_EQUAL(breakout_row["state"], "breaking out", "A prisoner breaking out shows [breakout_row["state"]]")
	panel.manage_prison(prison, operator, "prison_breakout", list("ref" = REF(second)))
	TEST_ASSERT(panel.error, "Breaking out a prisoner already breaking out was accepted")
	TEST_ASSERT_EQUAL(get_turf(second), breakout_spot, "A refused breakout moved the prisoner")
	panel.manage_prison(prison, operator, "prison_breakout", list("ref" = "not a ref"))
	TEST_ASSERT(panel.error, "A breakout for a bad reference was accepted")
	panel.manage_prison(prison, operator, "prison_all", list("what" = "riot"))
	TEST_ASSERT(panel.error, "An unknown prisoner-wide action was accepted")

	// Every successful action was logged once: set, enrage, calm all, fight, calm, riot, calm, breakout.
	TEST_ASSERT_EQUAL(length(panel.operations), 8, "The manipulator logged [length(panel.operations)] trouble actions: [jointext(panel.operations, "; ")]")
	settle_prison_air(home)

// ===== BALANCE PASS ADMIN TOOLS =====

/**
 * The balance pass's admin data and actions. Each action calls a hook another prison package
 * fills in; this test checks the validation, the logging, and the hook's effect where it shows
 * both with the seams stubs and with the real hooks.
 */
/datum/unit_test/voidcrew_outpost_prison_admin_hooks
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_admin_hooks/proc/row_for(list/section, mob/living/carbon/human/npc/outpost_prisoner/prisoner)
	for(var/list/row as anything in section["prisoners"])
		if(row["ref"] == REF(prisoner))
			return row
	return null

/datum/unit_test/voidcrew_outpost_prison_admin_hooks/Run()
	var/obj/structure/overmap/trader_outpost/prison_test_host/home = trouble_test_claim("prisonhooksowner")
	TEST_ASSERT_NOTNULL(home, "The admin hooks test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/operator = make_player(prison_spot(home, 8, 4), "prisonhooks")
	var/datum/outpost_manipulator/unit_test/prison/panel = allocate(__IMPLIED_TYPE__, operator)
	var/mob/living/carbon/human/npc/outpost_prisoner/first = trouble_prisoner(prison, prison_spot(home, 7, 8))
	var/mob/living/carbon/human/npc/outpost_prisoner/second = trouble_prisoner(prison, prison_spot(home, 9, 8))
	var/mob/living/carbon/human/npc/outpost_prisoner/third = trouble_prisoner(prison, prison_spot(home, 12, 8))

	// Wing data: every key, whether or not the package behind it has landed.
	var/list/section = panel.prison_admin_data(prison)
	for(var/key in list("intake_state", "audience", "audience_mode", "riot_active", "riot_elapsed", "riot_absent", "subdued_left", "lost_recent", "hatch", "mess_units", "floor_size", "lit_samples", "outage_debt"))
		TEST_ASSERT(key in section, "The prison section sends no [key]")
	TEST_ASSERT(section["intake_state"] in list("open", "closed", "no_power"), "The intake state is [section["intake_state"]]")
	var/list/hatch = section["hatch"]
	TEST_ASSERT(islist(hatch), "The prison section's hatch is not a list")
	for(var/key in list("meals", "clean_suits", "dirty_suits", "capacity", "lasts_minutes"))
		TEST_ASSERT(key in hatch, "The hatch stock sends no [key]")

	// Prisoner data: care, how well kept and confinement. Needs are pinned: fed, clean, and
	// 76% health make care 92 (OUTPOST_PRISON_GRADE_FLOOR 70, _FULL 95).
	panel.manage_prison(prison, operator, "prison_set", list("ref" = REF(first), "field" = "health", "value" = 76))
	section = panel.prison_admin_data(prison)
	var/list/row = row_for(section, first)
	for(var/key in list("care", "kept", "confined_seconds", "confined", "mood", "state"))
		TEST_ASSERT(key in row, "A prisoner row sends no [key]")
	TEST_ASSERT_EQUAL(row["care"], 92, "Fed, clean and at 76% health, care shows [row["care"]]")
	TEST_ASSERT_EQUAL(row["kept"], round(prison.kept_well(first), 0.01), "The row's kept [row["kept"]] is not the prison's")
	TEST_ASSERT(row["kept"] >= 0 && row["kept"] <= 1, "A kept value of [row["kept"]]")
	TEST_ASSERT(!row["confined"], "A prisoner standing in the yard shows as confined")
	TEST_ASSERT_EQUAL(row["confined_seconds"], 0, "A prisoner never shut in shows [row["confined_seconds"]] s confined")

	// The audience, validated. The fixture starts it on; auto first, so the bad modes are seen not to change it.
	panel.manage_prison(prison, operator, "prison_audience", list("mode" = "auto"))
	TEST_ASSERT(!panel.error && isnull(prison.audience_override), "Auto did not clear the override")
	TEST_ASSERT_EQUAL(panel.prison_admin_data(prison)["audience_mode"], "auto", "A wing with no override shows audience mode [panel.prison_admin_data(prison)["audience_mode"]]")
	panel.manage_prison(prison, operator, "prison_audience", list("mode" = "sideways"))
	TEST_ASSERT(panel.error && isnull(prison.audience_override), "A bad audience mode was accepted")
	panel.manage_prison(prison, operator, "prison_audience", list("mode" = 1))
	TEST_ASSERT(panel.error && isnull(prison.audience_override), "A numeric audience mode was accepted")
	panel.manage_prison(prison, operator, "prison_audience", list("mode" = "off"))
	TEST_ASSERT(!panel.error && !isnull(prison.audience_override) && !prison.has_audience(), "Off did not take the audience away")
	section = panel.prison_admin_data(prison)
	TEST_ASSERT(section["audience_mode"] == "off" && !section["audience"], "The section shows audience mode [section["audience_mode"]], audience [section["audience"]] after off")
	panel.manage_prison(prison, operator, "prison_audience", list("mode" = "on"))
	TEST_ASSERT(prison.audience_override == TRUE && prison.has_audience(), "On did not bring an audience")

	// The confinement clock, validated and clamped (3,600 s at most).
	panel.manage_prison(prison, operator, "prison_set", list("ref" = REF(first), "field" = "locked_in", "value" = "lots"))
	TEST_ASSERT(panel.error && !first.locked_in_seconds, "A non-number confinement time was accepted")
	panel.manage_prison(prison, operator, "prison_set", list("ref" = REF(first), "field" = "locked_in", "value" = 130))
	TEST_ASSERT_EQUAL(first.locked_in_seconds, 130, "Setting the confinement clock left it at [first.locked_in_seconds]")
	TEST_ASSERT_EQUAL(row_for(panel.prison_admin_data(prison), first)["confined_seconds"], 130, "The row does not show the confinement clock")
	panel.manage_prison(prison, operator, "prison_set", list("ref" = REF(first), "field" = "locked_in", "value" = 5000))
	TEST_ASSERT_EQUAL(first.locked_in_seconds, 3600, "A long confinement time was not clamped: [first.locked_in_seconds]")

	// Subdued time, validated. The trouble package reports it once its hook is real.
	for(var/bad_seconds in list(-1, 1.5, 4000, "soon"))
		panel.manage_prison(prison, operator, "prison_subdue", list("seconds" = bad_seconds))
		TEST_ASSERT(panel.error, "Subduing for [bad_seconds] s was accepted")
	panel.manage_prison(prison, operator, "prison_subdue", list("seconds" = 360))
	TEST_ASSERT(!panel.error, "Subduing for 360 s was refused: [panel.error]")
	var/subdued = prison.trouble_payload()["subdued_left"]
	TEST_ASSERT(isnull(subdued) || subdued == 360, "Subduing for 360 s left [subdued] s")
	panel.manage_prison(prison, operator, "prison_subdue", list("seconds" = 0))
	subdued = prison.trouble_payload()["subdued_left"]
	TEST_ASSERT(!panel.error && !subdued, "Ending the subdued time left [subdued] s")

	// Hatches, filled to capacity once the needs package has hatches to fill.
	panel.manage_prison(prison, operator, "prison_fill_hatch", list())
	TEST_ASSERT(!panel.error, "Filling the hatches was refused: [panel.error]")
	var/list/stock = prison.hatch_stock()
	TEST_ASSERT(!stock["capacity"] || stock["meals"] + stock["clean_suits"] + stock["dirty_suits"] == stock["capacity"], "Filled hatches hold [stock["meals"]] meals and [stock["clean_suits"]] clean suits of [stock["capacity"]]")

	// A rat: logged when one is placed, an error when none is (the seams stub places none).
	var/logs_before = length(panel.operations)
	panel.manage_prison(prison, operator, "prison_spawn_rat", list())
	var/rat_logged = length(panel.operations) - logs_before
	TEST_ASSERT_EQUAL(rat_logged, panel.error ? 0 : 1, "A rat [panel.error ? "refused" : "placed"] was logged [rat_logged] times")

	// Outage debt, validated, with the power off. The conditions package may count a refresh's
	// worth of seconds on top, so the value is checked to within one refresh.
	panel.manage_prison(prison, operator, "prison_power", list("on" = 0))
	for(var/bad_seconds in list(-5, 2.5, 5000, "x"))
		panel.manage_prison(prison, operator, "prison_outage", list("seconds" = bad_seconds))
		TEST_ASSERT(panel.error, "An outage of [bad_seconds] s was accepted")
	panel.manage_prison(prison, operator, "prison_outage", list("seconds" = 90))
	TEST_ASSERT(!panel.error && abs(prison.outage_debt - 90) <= 10, "Setting the outage debt to 90 s left it at [prison.outage_debt]")
	TEST_ASSERT(abs(panel.prison_admin_data(prison)["outage_debt"] - 90) <= 10, "The section does not show the outage debt")
	panel.manage_prison(prison, operator, "prison_power", list("on" = 1))

	// Wrecking: refused for a bad reference and a body, taken for a living prisoner with a cell.
	panel.manage_prison(prison, operator, "prison_wreck", list("ref" = "not a ref"))
	TEST_ASSERT(panel.error, "Wrecking for a bad reference was accepted")
	panel.manage_prison(prison, operator, "prison_kill", list("ref" = REF(third)))
	panel.manage_prison(prison, operator, "prison_wreck", list("ref" = REF(third)))
	TEST_ASSERT(panel.error, "A body was set to wreck its cell")
	panel.manage_prison(prison, operator, "prison_set", list("ref" = REF(third), "field" = "locked_in", "value" = 10))
	TEST_ASSERT(panel.error, "A body's confinement clock was set")
	panel.manage_prison(prison, operator, "prison_wreck", list("ref" = REF(first)))
	TEST_ASSERT(!panel.error, "Wrecking was refused for a prisoner with a cell: [panel.error]")
	var/list/wrecker = row_for(panel.prison_admin_data(prison), first)
	TEST_ASSERT(wrecker["state"] in list("normal", "wreck"), "A wrecking prisoner's state is [wrecker["state"]]")

	// Transfer: refused with no riot, taken during one.
	panel.manage_prison(prison, operator, "prison_transfer", list())
	TEST_ASSERT(panel.error, "A transfer with no riot was accepted")
	panel.manage_prison(prison, operator, "prison_riot", list())
	TEST_ASSERT(prison.riot_active && second.is_rioting(), "The riot for the transfer did not start")
	panel.manage_prison(prison, operator, "prison_transfer", list())
	TEST_ASSERT(!panel.error, "A transfer during a riot was refused: [panel.error]")

	// Logged once each: health, 3 audience modes, 2 clocks, 2 subdues, fill, (rat), power off,
	// outage, power on, kill, wreck, riot, transfer.
	TEST_ASSERT_EQUAL(length(panel.operations), 16 + rat_logged, "The manipulator logged [length(panel.operations)] actions: [jointext(panel.operations, "; ")]")
	settle_prison_air(home)
