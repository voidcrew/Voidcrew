/**
 * Outpost prison conditions: the clean, lit and powered scores, what the wing's state does to
 * prisoners' moods, flies, rats, bad air and the riot strobe.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with
 * the define named beside them. Prisons are driven with tick(seconds) or conditions_tick(seconds)
 * with their own processing stopped, never by waiting in real time, except for beams, which run
 * on timers, and light, which the lighting subsystem draws. Fixtures are in
 * voidcrew_outpost_prison_helpers.dm; the helpers below are this file's own.
 *
 * Map coordinates are the unrotated wing's: cells on rows 13-15 (cell 2 is x 6-8), the yard on
 * rows 7-11, the divider with the serving hatches on row 6 and the office on rows 2-5.
 */

/**
 * Draws the wing's lights now, as the lighting subsystem would, instead of waiting for it: in a
 * test world its queue can hold tens of thousands of sources from the levels loaded at start.
 * Returns whether every light in the wing is drawn.
 */
/datum/unit_test/voidcrew_outpost_management/proc/conditions_draw_lights(datum/outpost_prison/prison)
	prison.refresh_fixtures()
	for(var/obj/machinery/light/fixture as anything in prison.wing_lights)
		var/datum/light_source/source = fixture.light
		if(!source?.needs_update)
			continue
		source.update_corners()
		if(QDELETED(source))
			continue
		// Out of the subsystem's queues as well, as its fire() does. A drawn source left queued is
		// never dequeued by Destroy(), which only dequeues sources that still need an update, and
		// the subsystem then stalls on the deleted entry for the rest of the round.
		source.needs_update = LIGHTING_NO_UPDATE
		SSlighting.sources_queue -= source
		SSlighting.current_sources -= source
	return !prison.lighting_pending()

/// Clean for a mess load, as the curve gives it: free to 2 units per 100 floor tiles, 0 at 14 (PRISON_MESS_FREE, PRISON_MESS_SQUALID)
/datum/unit_test/voidcrew_outpost_management/proc/conditions_expected_clean(load, floor_size)
	var/density = 100 * load / floor_size
	return round(100 * (1 - clamp((density - 2) / 12, 0, 1)), 1)

/// Kills the rats a test's filth brought in
/datum/unit_test/voidcrew_outpost_management/proc/conditions_clear_rats(datum/outpost_prison/prison)
	for(var/datum/weakref/rat_ref as anything in prison.rat_refs)
		var/mob/living/rat = rat_ref.resolve()
		if(rat)
			qdel(rat)
	prison.rat_refs = list()

// ===== SCORES =====

/datum/unit_test/voidcrew_outpost_prison_conditions_basic
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_conditions_basic/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("conditionsowner")
	TEST_ASSERT_NOTNULL(home, "The conditions test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)

	// A fresh wing is clean, lit and powered, once any bulb that came broken (tg breaks 2-5% of
	// lights at load) is replaced.
	var/list/lights = all_lights(prison)
	TEST_ASSERT_EQUAL(length(lights), 10, "The wing should have 10 lights")
	for(var/obj/machinery/light/fixture as anything in lights)
		if(fixture.status != LIGHT_OK)
			fixture.fix()
	prison.refresh_conditions()
	TEST_ASSERT_EQUAL(prison.clean_score, 100, "A fresh wing is not clean")
	TEST_ASSERT_EQUAL(prison.lit_score, 100, "A fresh wing is not fully lit")
	TEST_ASSERT_EQUAL(prison.powered_score, 100, "A fresh wing has no power")
	TEST_ASSERT(abs(prison.conditions_score() - 100) < 0.01, "A fresh wing's conditions are [prison.conditions_score()]")
	TEST_ASSERT(abs(prison.conditions_pay_factor() - 1) < 0.001, "A fresh wing pays [prison.conditions_pay_factor()] of full pay")

	// Mess counts, and light is measured, on the cell block's floor: the cells and their doors, the
	// yard with its tables and fixtures, and the serving hatches; not the office, the windows or
	// the staff door.
	TEST_ASSERT(prison.mess_floor_size >= 105 && prison.mess_floor_size <= 125, "The cell block floor has [prison.mess_floor_size] tiles")
	TEST_ASSERT_EQUAL(prison.mess_floor_size, length(prison.mess_floor), "The floor size was not taken from the placed wing")
	TEST_ASSERT_EQUAL(length(prison.light_tiles), length(prison.mess_floor), "Light is measured on [length(prison.light_tiles)] tiles, not the floor's [length(prison.mess_floor)]")
	TEST_ASSERT(prison_spot(home, 8, 8) in prison.mess_floor, "The yard is not floor")
	TEST_ASSERT(prison_spot(home, 3, 14) in prison.mess_floor, "Cell 1 is not floor")
	TEST_ASSERT(prison_spot(home, 3, 12) in prison.mess_floor, "Cell 1's door is not floor")
	TEST_ASSERT(prison_spot(home, 4, 9) in prison.mess_floor, "A mess table is not floor")
	TEST_ASSERT(prison_spot(home, 9, 11) in prison.mess_floor, "The hoop's tile is not floor")
	TEST_ASSERT(prison_spot(home, 5, 6) in prison.mess_floor, "A serving hatch is not floor")
	TEST_ASSERT(!(prison_spot(home, 6, 12) in prison.mess_floor), "Cell 2's window is floor")
	TEST_ASSERT(!(prison_spot(home, 9, 6) in prison.mess_floor), "The staff door is floor")
	TEST_ASSERT(!(prison_spot(home, 8, 3) in prison.mess_floor), "The office is floor")

	// Conditions weigh clean 0.45, lit 0.35 and power 0.2 (PRISON_WEIGHT_*), and pay is scaled by
	// 0.5 + 0.5 x conditions (OUTPOST_PRISON_CONDITIONS_PAY_FLOOR).
	prison.clean_score = 60
	prison.lit_score = 40
	prison.powered_score = 50
	TEST_ASSERT(abs(prison.conditions_score() - 51) < 0.01, "Clean 60, lit 40 and power 50 made conditions [prison.conditions_score()], not 51")
	TEST_ASSERT(abs(prison.conditions_pay_factor() - 0.755) < 0.001, "Conditions 51 paid [prison.conditions_pay_factor()], not 0.755")
	prison.clean_score = 0
	prison.lit_score = 0
	prison.powered_score = 0
	TEST_ASSERT(abs(prison.conditions_pay_factor() - 0.5) < 0.001, "Conditions 0 paid [prison.conditions_pay_factor()], not half")

	// The console's block.
	prison.refresh_conditions()
	var/list/payload = prison.conditions_payload()
	for(var/key in list("clean", "lit", "powered", "score", "mess_spots", "dark_cells", "battery"))
		TEST_ASSERT(key in payload, "The conditions block has no [key]")
	TEST_ASSERT_EQUAL(payload["score"], 100, "The conditions block's score is [payload["score"]]")
	TEST_ASSERT(islist(payload["dark_cells"]) && !length(payload["dark_cells"]), "A lit wing has dark cells")
	settle_prison_air(home)

// ===== MESS =====

/datum/unit_test/voidcrew_outpost_prison_conditions_mess
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_conditions_mess/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("messowner")
	TEST_ASSERT_NOTNULL(home, "The mess test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.refresh_conditions()
	TEST_ASSERT_EQUAL(prison.clean_score, 100, "The mess test wing did not start clean")
	var/size = prison.mess_floor_size
	var/list/mess = list()

	// Three wrappers are a lived-in wing, not a dirty one: 1.5 units, under the 2 per 100 tiles
	// that are free (PRISON_MESS_WEIGHT_LIGHT 0.5, PRISON_MESS_FREE).
	for(var/x in 8 to 10)
		mess += allocate(/obj/item/trash/candy, prison_spot(home, x, 7))
	prison.refresh_conditions()
	TEST_ASSERT(abs(prison.mess_load - 1.5) < 0.01, "Three wrappers weighed [prison.mess_load], not 1.5")
	TEST_ASSERT_EQUAL(prison.mess_spots, 3, "Three wrappers made [prison.mess_spots] mess spots")
	TEST_ASSERT_EQUAL(prison.clean_score, 100, "Three wrappers cost [100 - prison.clean_score] cleanliness")

	// A pile on one tile counts for 2 at most (PRISON_MESS_TILE_CAP).
	for(var/i in 1 to 8)
		mess += allocate(/obj/item/trash/candy, prison_spot(home, 8, 8))
	prison.refresh_conditions()
	TEST_ASSERT(abs(prison.mess_load - 3.5) < 0.01, "Eight wrappers on one tile weighed [prison.mess_load - 1.5], not 2")
	TEST_ASSERT_EQUAL(prison.clean_score, conditions_expected_clean(3.5, size), "3.5 units of mess left the wing [prison.clean_score] clean")
	QDEL_LIST(mess)

	// The office is not where prisoners live: vomit there costs nothing.
	for(var/x in 3 to 12)
		mess += allocate(/obj/effect/decal/cleanable/vomit, prison_spot(home, x, 3))
	prison.refresh_conditions()
	TEST_ASSERT_EQUAL(prison.mess_load, 0, "Mess in the office weighed [prison.mess_load]")
	TEST_ASSERT_EQUAL(prison.clean_score, 100, "Mess in the office made the wing [prison.clean_score] clean")
	QDEL_LIST(mess)

	// Vomit under a pile of junk still counts, and as heavy mess (PRISON_MESS_WEIGHT_HEAVY 1.5).
	var/turf/pile = prison_spot(home, 11, 8)
	var/list/junk = list()
	for(var/i in 1 to 50)
		junk += new /obj/item/pen(pile)
	mess += allocate(/obj/effect/decal/cleanable/vomit, pile)
	for(var/i in 1 to 20)
		junk += new /obj/item/pen(pile)
	prison.refresh_conditions()
	TEST_ASSERT(abs(prison.mess_load - 1.5) < 0.01, "Vomit under 70 pens weighed [prison.mess_load], not 1.5")
	TEST_ASSERT(!isnull(prison.heavy_since[pile]), "Vomit under a pile of junk was not seen as heavy mess")
	// Nor does pushing a crate or building a grille over it hide it.
	for(var/cover_type in list(/obj/structure/closet/crate, /obj/structure/grille))
		var/obj/structure/cover = allocate(cover_type, pile)
		prison.refresh_conditions()
		TEST_ASSERT(pile in prison.mess_floor, "[cover] took the tile under it off the floor")
		TEST_ASSERT(abs(prison.mess_load - 1.5) < 0.01, "Vomit under [cover] weighed [prison.mess_load], not 1.5")
		qdel(cover)

	// The scan looks at 3000 atoms at a time (PRISON_SCAN_BUDGET) and finishes on the next go.
	var/list/floor = prison.mess_floor
	for(var/i in 1 to 3)
		var/turf/stack_spot = floor[i]
		for(var/j in 1 to 1100)
			junk += new /obj/item/pen(stack_spot)
	var/turf/last = floor[length(floor)]
	if(last == pile)
		last = floor[length(floor) - 1]
	mess += allocate(/obj/effect/decal/cleanable/vomit, last)
	TEST_ASSERT(!prison.scan_mess(), "The scan got through 3300 pens and the rest of the floor in one go")
	TEST_ASSERT_EQUAL(prison.mess_scan_index, 4, "The scan stopped before tile [prison.mess_scan_index], not after the third")
	TEST_ASSERT(abs(prison.mess_load - 1.5) < 0.01, "An unfinished scan changed the mess load to [prison.mess_load]")
	TEST_ASSERT(prison.scan_mess(), "The scan did not finish on its second go")
	TEST_ASSERT(abs(prison.mess_load - 3) < 0.01, "The finished scan weighed [prison.mess_load], not 3")
	QDEL_LIST(junk)
	QDEL_LIST(mess)

	// Heavy mess left five minutes draws flies (PRISON_FLY_AFTER), on six tiles at most
	// (PRISON_FLY_MAX); cleaning it up sends them away.
	var/list/cell_spots = list(prison_spot(home, 3, 13), prison_spot(home, 3, 14), prison_spot(home, 7, 13), prison_spot(home, 7, 14), prison_spot(home, 11, 13), prison_spot(home, 11, 14), prison_spot(home, 15, 13), prison_spot(home, 15, 14))
	for(var/turf/spot as anything in cell_spots)
		mess += allocate(/obj/effect/decal/cleanable/vomit, spot)
	prison.conditions_tick(5)
	TEST_ASSERT_EQUAL(length(prison.heavy_since), 8, "[length(prison.heavy_since)] tiles of vomit were seen, not 8")
	TEST_ASSERT(!length(prison.fly_effects), "Fresh vomit drew flies")
	prison.conditions_tick(300)
	TEST_ASSERT_EQUAL(length(prison.fly_effects), 6, "Old vomit on 8 tiles drew flies on [length(prison.fly_effects)]")
	var/list/flies = list()
	for(var/turf/spot as anything in prison.fly_effects)
		var/datum/weakref/fly_ref = prison.fly_effects[spot]
		var/obj/effect/outpost_prison_flies/fly = fly_ref.resolve()
		TEST_ASSERT(fly?.loc == spot, "The flies for [spot] are not on it")
		flies += fly
	var/clean_before = prison.clean_score
	TEST_ASSERT(clean_before < 100, "Eight tiles of vomit left the wing clean")

	// Walling off part of the yard makes the floor smaller but never the mess lighter: the floor's
	// size stays the placed wing's. The new walls leave the floor; the yard behind them was inside
	// the cell block and stays inside (refresh_cell_block() keeps what was inside).
	for(var/x in 2 to 16)
		var/turf/wall_spot = prison_spot(home, x, 10)
		wall_spot.ChangeTurf(/turf/closed/wall)
	prison.refresh_cell_block()
	prison.refresh_conditions()
	TEST_ASSERT(length(prison.mess_floor) < size, "Walling off the yard left [length(prison.mess_floor)] of [size] floor tiles")
	TEST_ASSERT(!(prison_spot(home, 8, 10) in prison.mess_floor), "The new wall is still floor")
	TEST_ASSERT(prison_spot(home, 8, 8) in prison.mess_floor, "The walled-off yard left the floor")
	TEST_ASSERT_EQUAL(prison.mess_floor_size, size, "Walling off the yard changed the floor size")
	TEST_ASSERT_EQUAL(prison.clean_score, clean_before, "Walling off the yard changed Clean from [clean_before] to [prison.clean_score]")

	QDEL_LIST(mess)
	prison.conditions_tick(5)
	TEST_ASSERT(!length(prison.fly_effects), "Flies stayed after the vomit was cleaned up")
	for(var/obj/effect/outpost_prison_flies/fly as anything in flies)
		TEST_ASSERT(QDELETED(fly), "Flies were left behind at [fly.x],[fly.y]")
	TEST_ASSERT_EQUAL(prison.clean_score, 100, "The wing is not clean once the vomit is gone")
	conditions_clear_rats(prison)
	settle_prison_air(home)

// ===== LIGHT =====

/datum/unit_test/voidcrew_outpost_prison_conditions_light
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_conditions_light/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("lightowner")
	TEST_ASSERT_NOTNULL(home, "The light test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	for(var/obj/machinery/light/fixture as anything in all_lights(prison))
		if(fixture.status != LIGHT_OK)
			fixture.fix()
	TEST_ASSERT(conditions_draw_lights(prison), "The wing's lights were never drawn")
	prison.refresh_conditions()
	TEST_ASSERT(prison.lit_samples >= 95, "Only [prison.lit_samples] tiles were measured")
	TEST_ASSERT_EQUAL(prison.lit_score, 100, "A wing with every light working measured [prison.lit_score]")
	TEST_ASSERT(!length(prison.dark_cells()), "A lit wing has dark cells: [jointext(prison.dark_cells(), ", ")]")

	// A dead bulb darkens its own cell; the wing as a whole barely notices.
	var/datum/outpost_prison_cell/cell_two = prison.cell_at(prison_spot(home, 7, 14))
	TEST_ASSERT_NOTNULL(cell_two, "There is no cell at 7,14")
	var/obj/machinery/light/cell_bulb = locate() in prison_spot(home, 6, 15)
	TEST_ASSERT_NOTNULL(cell_bulb, "Cell 2's bulb is not where the map puts it")
	cell_bulb.break_light_tube(TRUE)
	prison.refresh_conditions()
	var/cell_value = prison.cell_light(cell_two)
	TEST_ASSERT(cell_value < 50, "A cell with a dead bulb measured [cell_value]") // PRISON_DARK_BELOW
	TEST_ASSERT(cell_two.number in prison.dark_cells(), "Cell [cell_two.number] with a dead bulb is not a dark cell")
	for(var/datum/outpost_prison_cell/other as anything in prison.cells)
		if(other != cell_two)
			TEST_ASSERT(prison.cell_light(other) >= 50, "Cell [other.number] went dark with cell [cell_two.number]'s bulb")
	var/lit_with_dark_cell = prison.lit_score
	TEST_ASSERT(lit_with_dark_cell < 100 && lit_with_dark_cell >= 85, "One dead cell bulb left the wing [lit_with_dark_cell] lit")

	// Lights nobody in the cell block can see add nothing: six in a sealed office closet.
	for(var/list/wall_at in list(list(4, 2), list(2, 3), list(3, 3)))
		var/turf/wall_spot = prison_spot(home, wall_at[1], wall_at[2])
		wall_spot.ChangeTurf(/turf/closed/wall)
	var/list/closet_lights = list()
	for(var/light_type in list(/obj/machinery/light/directional/north, /obj/machinery/light/directional/south, /obj/machinery/light/directional/west))
		closet_lights += allocate(light_type, prison_spot(home, 2, 2))
	for(var/light_type in list(/obj/machinery/light/directional/north, /obj/machinery/light/directional/south, /obj/machinery/light/directional/east))
		closet_lights += allocate(light_type, prison_spot(home, 3, 2))
	TEST_ASSERT(conditions_draw_lights(prison), "The closet lights were never drawn")
	TEST_ASSERT_EQUAL(length(prison.wing_lights), 16, "The wing has [length(prison.wing_lights)] lights, not 16")
	prison.refresh_conditions()
	TEST_ASSERT(prison.lit_samples > 0, "The closet lights stopped the light being measured")
	TEST_ASSERT_EQUAL(prison.lit_score, lit_with_dark_cell, "Six lights in a sealed closet took Lit from [lit_with_dark_cell] to [prison.lit_score]")

	// The riot strobe: every light goes red, only the 12 nearest the cell block strobe
	// (PRISON_STROBE_MAX_LIGHTS), and Lit holds.
	prison.set_riot_lights(TRUE)
	TEST_ASSERT_EQUAL(length(prison.strobe_lights), 12, "[length(prison.strobe_lights)] lights strobe, not 12")
	var/list/strobing = list()
	for(var/datum/weakref/light_ref as anything in prison.strobe_lights)
		strobing += light_ref.resolve()
	for(var/obj/machinery/light/fixture as anything in prison.wing_lights)
		TEST_ASSERT(fixture.major_emergency, "[fixture] at [fixture.x],[fixture.y] did not go red")
		// Every light of the cells and the yard is among the nearest; the four left out are the office's.
		if(prison.cell_block[get_turf(fixture)])
			TEST_ASSERT(fixture in strobing, "The cell block light at [fixture.x],[fixture.y] does not strobe")
		else if(!(fixture in strobing))
			TEST_ASSERT(fixture.y <= prison_spot(home, 1, 4).y, "The light at [fixture.x],[fixture.y] does not strobe though it is not in the office")
	sleep(1.5 SECONDS)
	prison.refresh_conditions()
	TEST_ASSERT_EQUAL(prison.lit_score, lit_with_dark_cell, "The strobe took Lit from [lit_with_dark_cell] to [prison.lit_score]")
	prison.set_riot_lights(FALSE)
	for(var/obj/machinery/light/fixture as anything in prison.wing_lights)
		TEST_ASSERT(!fixture.major_emergency, "[fixture] at [fixture.x],[fixture.y] stayed in emergency mode")
		if(fixture.on)
			TEST_ASSERT(fixture.light_color != fixture.bulb_emergency_colour, "[fixture] at [fixture.x],[fixture.y] stayed red after the strobe")

	// A riot over before the lighting drew the red still leaves every light as it was.
	TEST_ASSERT(conditions_draw_lights(prison), "The wing's lights were never redrawn after the strobe")
	prison.set_riot_lights(TRUE)
	prison.set_riot_lights(FALSE)
	for(var/obj/machinery/light/fixture as anything in prison.wing_lights)
		if(!fixture.on)
			continue
		TEST_ASSERT(fixture.light_color != fixture.bulb_emergency_colour, "[fixture] at [fixture.x],[fixture.y] stayed red after a riot shorter than a lighting pass")
		var/normal_range = fixture.nightshift_enabled ? fixture.nightshift_brightness : fixture.brightness
		TEST_ASSERT_EQUAL(fixture.light_range, normal_range, "[fixture] at [fixture.x],[fixture.y] kept the emergency range")

	// The lights going out puts the wing on edge on the second dark sample in a row, once.
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))
	TEST_ASSERT_NOTNULL(prisoner, "No prisoner for the lights-out check")
	for(var/obj/machinery/light/fixture as anything in prison.wing_lights)
		fixture.break_light_tube(TRUE)
	prison.tension_spike = 0
	prison.refresh_conditions()
	TEST_ASSERT(prison.lit_score < 50, "A wing with every light broken measured [prison.lit_score]")
	TEST_ASSERT_EQUAL(prison.tension_spike, 0, "One dark sample put the wing on edge")
	prison.sample_light()
	TEST_ASSERT(prison.tension_spike >= 10, "Two dark samples did not put the wing on edge") // PRISON_SPIKE_LIGHTS_OUT
	prison.tension_spike = 0
	prison.sample_light()
	TEST_ASSERT_EQUAL(prison.tension_spike, 0, "A third dark sample put the wing on edge again")
	settle_prison_air(home)

// ===== POWER =====

/datum/unit_test/voidcrew_outpost_prison_conditions_power
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_conditions_power/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("powerowner")
	TEST_ASSERT_NOTNULL(home, "The power test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.refresh_conditions()
	var/obj/machinery/power/apc/apc = prison.wing.apc
	TEST_ASSERT_NOTNULL(apc, "The wing has no APC")
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))
	TEST_ASSERT_NOTNULL(prisoner, "No prisoner for the power checks")
	prison.tension_spike = 0

	// A 20 second cut is a blip: Power stays 100 and nobody minds (PRISON_POWER_GRACE 30).
	apc.operating = FALSE
	apc.update()
	TEST_ASSERT(!prison.is_powered(), "The breaker did not cut the wing's power")
	prison.conditions_tick(20)
	TEST_ASSERT_EQUAL(prison.powered_score, 100, "A 20 second cut left Power at [prison.powered_score]")
	TEST_ASSERT_EQUAL(prison.tension_spike, 0, "A 20 second cut put the wing on edge")
	apc.operating = TRUE
	apc.update()
	prison.conditions_tick(1)
	TEST_ASSERT_EQUAL(prison.powered_score, 100, "Power did not come back")
	// The cut is remembered, and drains at half speed (PRISON_POWER_DEBT_RECOVERY 0.5).
	TEST_ASSERT(abs(prison.outage_debt - 19.5) < 0.01, "The outage debt was [prison.outage_debt], not 19.5")
	prison.conditions_tick(60)
	TEST_ASSERT_EQUAL(prison.outage_debt, 0, "The outage debt did not drain")

	// A breaker flicked every 25 seconds does not keep the grace fresh.
	var/lowest = 100
	for(var/i in 1 to 6)
		apc.operating = FALSE
		apc.update()
		prison.conditions_tick(25)
		lowest = min(lowest, prison.powered_score)
		apc.operating = TRUE
		apc.update()
		prison.conditions_tick(25)
	TEST_ASSERT(lowest < 100, "A breaker flicked every 25 seconds kept Power at 100")
	TEST_ASSERT(prison.tension_spike >= 10, "Power dropping never put the wing on edge") // PRISON_SPIKE_POWER_CUT

	// A real outage: 100 through the grace, half way down the ramp at 75 s, 0 from 120 s
	// (PRISON_POWER_RAMP 90), and back to 100 the moment power returns.
	prison.outage_debt = 0
	prison.powered_score = 100
	apc.operating = FALSE
	apc.update()
	prison.conditions_tick(30)
	TEST_ASSERT_EQUAL(prison.powered_score, 100, "Power was [prison.powered_score] at the end of the grace")
	prison.conditions_tick(45)
	TEST_ASSERT_EQUAL(prison.powered_score, 50, "Power was [prison.powered_score] 75 seconds into a cut, not 50")
	prison.conditions_tick(45)
	TEST_ASSERT_EQUAL(prison.powered_score, 0, "Power was [prison.powered_score] two minutes into a cut")
	prison.conditions_tick(600)
	TEST_ASSERT_EQUAL(prison.powered_score, 0, "Power came back on its own")
	TEST_ASSERT_EQUAL(prison.outage_debt, 120, "The outage debt grew past the end of the ramp to [prison.outage_debt]")
	apc.operating = TRUE
	apc.update()
	prison.conditions_tick(1)
	TEST_ASSERT_EQUAL(prison.powered_score, 100, "Power did not jump back when the breaker went on")

	// While the wing runs on its battery, the console shows how much is left.
	if(apc.cell)
		apc.charging = APC_NOT_CHARGING
		TEST_ASSERT_EQUAL(prison.conditions_payload()["battery"], round(apc.cell.percent(), 1), "The console does not show the battery running down")
	settle_prison_air(home)

// ===== RATS AND AIR =====

/datum/unit_test/voidcrew_outpost_prison_conditions_rats_air
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_conditions_rats_air/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("ratowner")
	TEST_ASSERT_NOTNULL(home, "The rat test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)

	// Filth left three minutes brings rats (PRISON_RAT_CLEAN_BELOW 40, PRISON_RAT_AFTER), two at most (PRISON_RAT_MAX).
	var/list/mess = list()
	for(var/x in 3 to 15)
		mess += allocate(/obj/effect/decal/cleanable/vomit, prison_spot(home, x, 7))
	for(var/x in 7 to 11)
		mess += allocate(/obj/effect/decal/cleanable/vomit, prison_spot(home, x, 8))
	prison.refresh_conditions()
	TEST_ASSERT_EQUAL(prison.clean_score, 0, "Eighteen tiles of vomit left the wing [prison.clean_score] clean")
	prison.conditions_tick(60)
	prison.conditions_tick(60)
	TEST_ASSERT_EQUAL(prison.living_rats(), 0, "Rats came before the wing had been filthy for three minutes")
	for(var/i in 1 to 100)
		prison.conditions_tick(60)
		if(prison.living_rats())
			break
	TEST_ASSERT(prison.living_rats() >= 1, "No rat came in 100 filthy minutes")
	var/datum/weakref/first_ref = prison.rat_refs[1]
	var/mob/living/basic/mouse/first_rat = first_ref.resolve()
	TEST_ASSERT(first_rat && prison.cell_block[get_turf(first_rat)], "The rat did not turn up in the cell block")
	for(var/i in 1 to 60)
		prison.conditions_tick(60)
		TEST_ASSERT(prison.living_rats() <= 2, "[prison.living_rats()] rats in the wing")

	// Cleaned up, no more come (PRISON_RAT_STOP_ABOVE 60).
	QDEL_LIST(mess)
	conditions_clear_rats(prison)
	prison.conditions_tick(5)
	TEST_ASSERT_EQUAL(prison.clean_score, 100, "The wing is not clean once the vomit is gone")
	for(var/i in 1 to 60)
		prison.conditions_tick(60)
	TEST_ASSERT_EQUAL(prison.living_rats(), 0, "Rats kept coming to a clean wing")

	// Bad air hurts, a point every 5 seconds (PRISON_AIR_DAMAGE), never below 30% (PRISON_AIR_HEALTH_FLOOR).
	var/turf/open/spot = prison_spot(home, 8, 8)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, spot)
	TEST_ASSERT_NOTNULL(prisoner, "No prisoner for the air checks")
	var/datum/gas_mixture/air = spot.return_air()
	TEST_ASSERT(!outpost_prison_unsafe_air(air), "The wing's own air counts as unsafe")
	prison.conditions_tick(5)
	TEST_ASSERT_EQUAL(prisoner.health, 100, "Good air hurt a prisoner")
	air.remove_ratio(1)
	TEST_ASSERT(outpost_prison_unsafe_air(air), "A vented tile's air counts as safe")
	prison.conditions_tick(5)
	TEST_ASSERT_EQUAL(prisoner.health, 99, "Five seconds on vented air took [100 - prisoner.health] health, not 1")
	prison.conditions_tick(2000)
	TEST_ASSERT_EQUAL(prisoner.health, 30, "Vented air left a prisoner at [prisoner.health] health, not 30")
	prison.conditions_tick(2000)
	TEST_ASSERT_EQUAL(prisoner.health, 30, "Vented air took a prisoner below 30 health")
	TEST_ASSERT_EQUAL(prisoner.stat, CONSCIOUS, "Vented air knocked a prisoner out")
	settle_prison_air(home)

// ===== WHAT THE WING DOES TO MOOD =====

/datum/unit_test/voidcrew_outpost_prison_mood_wing
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_mood_wing/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("moodwingowner")
	TEST_ASSERT_NOTNULL(home, "The wing mood test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = trouble_prisoner(prison, prison_spot(home, 8, 8))
	TEST_ASSERT(abs(prison.conditions_score() - 100) < 0.01, "The mood test wing is not in perfect condition")
	// Per minute: a well kept prisoner in a clean, lit, powered wing gains 2 (PRISONER_MOOD_GOOD_WING).
	TEST_ASSERT(drift_is(prisoner, 2), "A well kept prisoner drifts [prisoner.mood_drift_per_minute()], not +2")

	// Dirty and dark cost nothing down to 70 (PRISON_WING_MOOD_LINE) and 5 a minute at 0
	// (PRISONER_MOOD_DIRTY_WING, PRISONER_MOOD_DARK), in a straight line; each also loses the +2.
	prison.clean_score = 70
	TEST_ASSERT(drift_is(prisoner, 0), "Clean 70 drifts [prisoner.mood_drift_per_minute()], not 0")
	prison.clean_score = 69
	TEST_ASSERT(drift_is(prisoner, -5 / 70), "Clean 69 drifts [prisoner.mood_drift_per_minute()], not -0.07")
	prison.clean_score = 35
	TEST_ASSERT(drift_is(prisoner, -2.5), "Clean 35 drifts [prisoner.mood_drift_per_minute()], not -2.5")
	prison.clean_score = 0
	TEST_ASSERT(drift_is(prisoner, -5), "Clean 0 drifts [prisoner.mood_drift_per_minute()], not -5")
	prison.clean_score = 100
	prison.lit_score = 35
	TEST_ASSERT(drift_is(prisoner, -2.5), "Lit 35 drifts [prisoner.mood_drift_per_minute()], not -2.5")
	prison.lit_score = 100
	// No power costs 4 a minute at 0, in proportion above it (PRISONER_MOOD_NO_POWER).
	prison.powered_score = 50
	TEST_ASSERT(drift_is(prisoner, -2), "Power 50 drifts [prisoner.mood_drift_per_minute()], not -2")
	prison.powered_score = 0
	TEST_ASSERT(drift_is(prisoner, -4), "Power 0 drifts [prisoner.mood_drift_per_minute()], not -4")
	prison.clean_score = 0
	prison.lit_score = 0
	TEST_ASSERT(drift_is(prisoner, -14), "A filthy, dark, dead wing drifts [prisoner.mood_drift_per_minute()], not -14")
	// Losses scale with personality: grumpy takes them 1.4 times as hard.
	prison.lit_score = 100
	prison.powered_score = 100
	prison.clean_score = 35
	prisoner.personality = "grumpy"
	TEST_ASSERT(drift_is(prisoner, -3.5), "A grumpy prisoner at Clean 35 drifts [prisoner.mood_drift_per_minute()], not -3.5")
	prisoner.personality = "chatty"
	prison.clean_score = 100

	// Their own cell dark costs 2 more a minute (PRISONER_MOOD_DARK_CELL); someone else's does not.
	TEST_ASSERT_NOTNULL(prisoner.cell, "The prisoner has no cell")
	prison.cell_lit["[prisoner.cell.number]"] = 20
	TEST_ASSERT(drift_is(prisoner, 0), "A dark cell of their own drifts [prisoner.mood_drift_per_minute()], not 0")
	prison.cell_lit = list()
	for(var/datum/outpost_prison_cell/other as anything in prison.cells)
		if(other != prisoner.cell)
			prison.cell_lit["[other.number]"] = 20
			break
	TEST_ASSERT(drift_is(prisoner, 2), "Someone else's dark cell drifts [prisoner.mood_drift_per_minute()], not +2")
	prison.cell_lit = list()

	// Real mess: twenty piles of dirt in the yard.
	var/list/mess = list()
	for(var/x in 3 to 15)
		mess += allocate(/obj/effect/decal/cleanable/dirt, prison_spot(home, x, 7))
	for(var/x in 7 to 11)
		mess += allocate(/obj/effect/decal/cleanable/dirt, prison_spot(home, x, 8))
	mess += allocate(/obj/effect/decal/cleanable/dirt, prison_spot(home, 3, 8))
	mess += allocate(/obj/effect/decal/cleanable/dirt, prison_spot(home, 15, 8))
	prison.refresh_conditions()
	var/expected_clean = conditions_expected_clean(10, prison.mess_floor_size)
	TEST_ASSERT_EQUAL(prison.clean_score, expected_clean, "Twenty piles of dirt left the wing [prison.clean_score] clean, not [expected_clean]")
	TEST_ASSERT(expected_clean < 70, "Twenty piles of dirt are not enough to upset anyone")
	TEST_ASSERT(drift_is(prisoner, -5 * (70 - expected_clean) / 70), "A wing at Clean [expected_clean] drifts [prisoner.mood_drift_per_minute()]")
	QDEL_LIST(mess)
	prison.refresh_conditions()
	TEST_ASSERT(drift_is(prisoner, 2), "The wing did not recover (drift [prisoner.mood_drift_per_minute()])")
	settle_prison_air(home)
