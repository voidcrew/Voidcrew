/**
 * Rioters breaking out (outpost_prison_breakout.dm): they go for the ways out of the cell block from
 * the start and spread over them, smash fixtures only on the side, break staff doors, hatch window
 * doors and windows with real damage while the crew is home, are announced once per way out, and
 * walk out through the gap, going loose.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with tick() with their own processing stopped;
 * nobody is on the level, so the AI sleeps and the tests call the blows (confront()) themselves.
 * The stock wing's ways out are along row 6: hatches at (5,6) and (13,6), windows at (7,6), (8,6),
 * (10,6) and (11,6), and the staff door at (9,6). Fixtures are in voidcrew_outpost_prison_helpers.dm.
 */

/// How many of the prison's log lines contain `text`
/datum/unit_test/voidcrew_outpost_management/proc/breakout_log_count(datum/outpost_prison/prison, text)
	var/count = 0
	for(var/list/entry as anything in prison.entries)
		if(findtext(entry["text"], text))
			count++
	return count

/// A riot of everyone in the wing, past its wind-up, with the crew home and no fixtures on the way
/datum/unit_test/voidcrew_outpost_management/proc/breakout_riot(datum/outpost_prison/prison)
	prison.crew_home_override = TRUE
	prison.riot_detour_chance = 0
	if(!prison.start_riot("test", everyone = TRUE))
		return FALSE
	prison.riot_windup_left = 0
	return TRUE

// ===== CHOOSING A WAY OUT =====

/datum/unit_test/voidcrew_outpost_prison_breakout_targets
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_breakout_targets/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("breakouttargets")
	TEST_ASSERT_NOTNULL(home, "The breakout target test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/list/rioters = list(
		trouble_prisoner(prison, prison_spot(home, 8, 8)),
		trouble_prisoner(prison, prison_spot(home, 9, 8)),
		trouble_prisoner(prison, prison_spot(home, 10, 8)),
		trouble_prisoner(prison, prison_spot(home, 9, 9)),
	)
	TEST_ASSERT(breakout_riot(prison), "The riot did not start")

	// Their first target is a way out: never a fixture, a cell door or the wing's outer wall.
	var/list/at_exit = list()
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in rioters)
		var/atom/target = rioter.riot_target()
		TEST_ASSERT(prison.is_exit_blocker(target), "[rioter] went for [target || "nothing"] before a way out")
		var/turf/tile = get_turf(target)
		TEST_ASSERT(prison.leads_out_of_cell_block(tile) && !prison.on_wing_edge(tile), "[rioter] went for [target] at [tile.x],[tile.y], which leads nowhere")
		TEST_ASSERT(!istype(target, /obj/machinery/door) || !prison.is_cell_door(target), "[rioter] went for a cell door")
		at_exit[tile] = (at_exit[tile] || 0) + 1
	// Spread over several, two at most at one (PRISON_RIOT_EXIT_CROWD)
	TEST_ASSERT(length(at_exit) >= 3, "Four rioters went for [length(at_exit)] ways out, not three or more")
	for(var/turf/tile as anything in at_exit)
		TEST_ASSERT(at_exit[tile] <= 2, "[at_exit[tile]] rioters went for the way out at [tile.x],[tile.y]")
	// The nearest: a rioter at the staff door goes for it, and keeps at it.
	var/mob/living/basic/outpost_prisoner/by_door = rioters[1]
	var/obj/machinery/door/airlock/security/prison_staff/staff_door = locate() in prison_spot(home, 9, 6)
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in rioters)
		rioter.riot_target_ref = null
	by_door.forceMove(prison_spot(home, 9, 7))
	prison.refresh_reach()
	TEST_ASSERT_EQUAL(by_door.riot_target(), staff_door, "A rioter beside the staff door went for [by_door.riot_target()]")
	by_door.riot_target_hits = 20
	TEST_ASSERT_EQUAL(by_door.riot_target(), staff_door, "A rioter gave up on the staff door after 20 blows") // PRISON_RIOT_TARGET_HITS is for fixtures

	// Waiting their turn at a crowded way out: a fixture near it meanwhile. Only the staff door for all four.
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in rioters)
		rioter.riot_target_ref = null
		for(var/turf/tile as anything in prison.exit_tiles(rioter))
			if(tile != get_turf(staff_door))
				LAZYSET(rioter.riot_skips, REF(prison.exit_blocker(tile)), world.time + 5 MINUTES)
	var/mob/living/basic/outpost_prisoner/second = rioters[2]
	var/mob/living/basic/outpost_prisoner/third = rioters[3]
	var/mob/living/basic/outpost_prisoner/fourth = rioters[4]
	TEST_ASSERT_EQUAL(by_door.riot_target(), staff_door, "The first rioter did not go for the only way out")
	TEST_ASSERT_EQUAL(second.riot_target(), staff_door, "The second rioter did not go for the only way out")
	var/atom/waiting = third.riot_target()
	TEST_ASSERT(prison.is_riot_fixture(waiting, get_turf(waiting)), "A third rioter at a crowded door went for [waiting || "nothing"], not a fixture")
	TEST_ASSERT(get_dist(waiting, staff_door) <= 3, "A rioter waiting their turn smashed [waiting] [get_dist(waiting, staff_door)] tiles from the door") // PRISON_RIOT_DETOUR_RANGE
	// Breaking out, crowded or not, it is the way out.
	third.trouble = "breakout" // PRISONER_TROUBLE_BREAKOUT
	third.riot_target_ref = null
	TEST_ASSERT_EQUAL(third.riot_target(), staff_door, "A rioter breaking out waited at a crowded door")
	third.trouble = "riot" // PRISONER_TROUBLE_RIOT

	// Now and then a fixture on the way (riot_detour_chance)
	prison.riot_detour_chance = 100
	fourth.riot_skips = null
	fourth.riot_target_ref = null
	var/atom/detour = fourth.riot_target()
	TEST_ASSERT(prison.is_riot_fixture(detour, get_turf(detour)) && get_dist(detour, fourth) <= 3, "A rioter at detour chance 100 went for [detour || "nothing"], not a fixture nearby")
	prison.riot_detour_chance = 0

	// With no way out they can get at, the wing's fixtures.
	for(var/turf/tile as anything in prison.exit_tiles(fourth))
		LAZYSET(fourth.riot_skips, REF(prison.exit_blocker(tile)), world.time + 5 MINUTES)
	TEST_ASSERT(!length(prison.exit_tiles(fourth)), "A rioter who gave up on every way out still has one")
	for(var/i in 1 to 20)
		fourth.riot_target_ref = null
		var/atom/fixture = fourth.riot_target()
		TEST_ASSERT(prison.is_riot_fixture(fixture, get_turf(fixture)), "A rioter with no way out went for [fixture || "nothing"], not a fixture")
		if(istype(fixture, /obj/structure/window))
			TEST_ASSERT(!prison.on_wing_edge(get_turf(fixture)), "A rioter went for a window in the outer wall")
	prison.admin_calm()
	settle_prison_air(home)

// ===== DOORS AND WINDOWS =====

/datum/unit_test/voidcrew_outpost_prison_breakout_doors
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_breakout_doors/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("breakoutdoors")
	TEST_ASSERT_NOTNULL(home, "The breakout door test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	// Out of the rioters' reach even once the door is down
	var/mob/living/carbon/human/warden = make_player(run_loc_floor_bottom_left, "breakoutdoors")
	var/turf/doorway = prison_spot(home, 9, 6)
	var/obj/machinery/door/airlock/security/prison_staff/staff_door = locate() in doorway
	TEST_ASSERT_NOTNULL(staff_door, "The staff door is not where the map puts it")
	var/mob/living/basic/outpost_prisoner/rioter = trouble_prisoner(prison, prison_spot(home, 9, 7))
	var/mob/living/basic/outpost_prisoner/glazier = trouble_prisoner(prison, prison_spot(home, 7, 7))
	TEST_ASSERT(breakout_riot(prison), "The riot did not start")
	TEST_ASSERT_EQUAL(rioter.riot_target(), staff_door, "A rioter beside the staff door went for [rioter.riot_target()]")

	// With nobody home a blow only booms: no damage, and nothing to announce.
	var/full = staff_door.get_integrity()
	TEST_ASSERT_EQUAL(full, 400, "The glass staff door has [full] integrity, not 400")
	prison.crew_home_override = FALSE
	TEST_ASSERT(rioter.confront(staff_door), "A rioter could not bang on the staff door")
	TEST_ASSERT_EQUAL(staff_door.get_integrity(), full, "A rioter damaged the staff door with nobody home")
	TEST_ASSERT(!length(prison.exit_alert_queue), "A door nobody damaged was queued for an alert")

	// With the crew home, 10 a blow (PRISON_RIOT_DOOR_DAMAGE), and the damage shows.
	prison.crew_home_override = TRUE
	rioter.confront(staff_door)
	TEST_ASSERT_EQUAL(staff_door.get_integrity(), full - 10, "A rioter's blow left the staff door at [staff_door.get_integrity()], not [full - 10]")
	TEST_ASSERT(findtext(jointext(staff_door.examine(warden), " "), "damaged"), "Examining the damaged staff door does not show it")

	// The alert: once, whatever the blows after.
	TEST_ASSERT_EQUAL(length(prison.exit_alert_queue), 1, "The first blow queued [length(prison.exit_alert_queue)] alerts")
	prison.tick(1)
	TEST_ASSERT_EQUAL(breakout_log_count(prison, "breaking at the staff door"), 1, "The first blow at the staff door was not announced once")
	TEST_ASSERT(!length(prison.exit_alert_queue), "The alert stayed queued after it went out")
	// Damaging blows 2 to 39 (the one with nobody home did nothing)
	for(var/blow in 2 to 39)
		rioter.confront(staff_door)
	prison.tick(20)
	TEST_ASSERT_EQUAL(breakout_log_count(prison, "breaking at the staff door"), 1, "The staff door was announced again in the same riot")
	TEST_ASSERT(!QDELETED(staff_door), "The staff door broke before 40 blows")

	// 40 blows: broken down, nothing left standing in the doorway.
	rioter.confront(staff_door)
	TEST_ASSERT(QDELETED(staff_door), "Forty blows did not break the staff door (integrity [staff_door?.get_integrity()])") // 400 / PRISON_RIOT_DOOR_DAMAGE
	TEST_ASSERT_NULL(prison.exit_blocker(doorway), "Something still blocks the broken doorway")
	TEST_ASSERT_EQUAL(breakout_log_count(prison, "broke through the staff door"), 1, "Breaking the staff door was not logged")

	// With nobody home, nobody walks out through the gap.
	prison.crew_home_override = FALSE
	var/atom/away_target = rioter.riot_target()
	TEST_ASSERT(!isturf(away_target), "A rioter made for the gap with nobody home")
	prison.crew_home_override = TRUE

	// With the crew home they go through, and out of the cell block they are loose.
	rioter.riot_target_ref = null
	var/turf/way_out = rioter.riot_target()
	TEST_ASSERT(isturf(way_out) && !prison.in_cell_block(way_out), "A rioter at the broken door did not make for the office ([way_out])")
	rioter.forceMove(way_out)
	prison.tick(1)
	TEST_ASSERT_EQUAL(rioter.trouble, "loose", "A rioter through the broken door is [rioter.trouble], not loose") // PRISONER_TROUBLE_LOOSE
	TEST_ASSERT(rioter.loose_left > 0, "A rioter through the broken door has no loose clock")
	TEST_ASSERT(prison.broke_out, "A rioter through the broken door did not count as breaking out")

	// A window: the pane, 7 a blow (PRISON_RIOT_WINDOW_DAMAGE, 150 integrity), then its grille (50, broken at 20).
	var/turf/window_tile = prison_spot(home, 7, 6)
	var/obj/structure/window/pane = locate() in window_tile
	var/obj/structure/grille/grille = locate() in window_tile
	TEST_ASSERT(pane && grille, "The yard window is not where the map puts it")
	TEST_ASSERT(prison.is_exit_blocker(pane), "The yard window does not count as a way out")
	for(var/blow in 1 to 21)
		glazier.confront(pane)
	TEST_ASSERT(!QDELETED(pane), "The window broke before 22 blows")
	glazier.confront(pane)
	TEST_ASSERT(QDELETED(pane), "Twenty-two blows did not break the window")
	TEST_ASSERT_EQUAL(prison.exit_blocker(window_tile), grille, "The grille does not stand in the way once the pane is gone")
	for(var/blow in 1 to 5)
		glazier.confront(grille)
	TEST_ASSERT(!grille.density, "Five blows did not break the grille")
	TEST_ASSERT_NULL(prison.exit_blocker(window_tile), "Something still blocks the broken window")
	// Its own alert, once; a new one goes out at most every 15 seconds (PRISON_EXIT_ALERT_GAP).
	prison.tick(1)
	TEST_ASSERT_EQUAL(breakout_log_count(prison, "breaking at a window"), 1, "The window was not announced once")
	TEST_ASSERT_EQUAL(prison.exit_alert_wait, 15, "The next alert may go out in [prison.exit_alert_wait] s, not 15")
	prison.admin_calm()
	settle_prison_air(home)

// ===== THE SERVING HATCH =====

/datum/unit_test/voidcrew_outpost_prison_breakout_hatch
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_breakout_hatch/proc/staff_side_fitted(obj/structure/table/reinforced/prison_hatch/hatch)
	return !isnull(hatch.staff_windoor())

/datum/unit_test/voidcrew_outpost_prison_breakout_hatch/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("breakouthatch")
	TEST_ASSERT_NOTNULL(home, "The breakout hatch test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/warden = make_player(run_loc_floor_bottom_left, "breakouthatch")
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in prison_spot(home, 5, 6)
	TEST_ASSERT_NOTNULL(hatch, "The serving hatch is not where the map puts it")
	var/obj/machinery/door/window/staff_side = hatch.staff_windoor()
	var/mob/living/basic/outpost_prisoner/rioter = trouble_prisoner(prison, prison_spot(home, 5, 7))
	TEST_ASSERT(breakout_riot(prison), "The riot did not start")
	var/mob/living/basic/outpost_prisoner/calm = trouble_prisoner(prison, prison_spot(home, 12, 8))
	TEST_ASSERT_EQUAL(rioter.riot_target(), hatch, "A rioter in front of the hatch went for [rioter.riot_target()]")

	// Outpost property: nothing else damages the window door, but a rioter's blows do, 10 each
	// (PRISON_RIOT_WINDOOR_DAMAGE), and the damage shows.
	var/full = staff_side.get_integrity()
	TEST_ASSERT_EQUAL(full, 300, "The office side has [full] integrity, not 300")
	staff_side.take_damage(100)
	TEST_ASSERT_EQUAL(staff_side.get_integrity(), full, "The office side took damage from something other than a rioter")
	TEST_ASSERT(rioter.confront(hatch), "A rioter could not hit the hatch")
	TEST_ASSERT_EQUAL(staff_side.get_integrity(), full - 10, "A rioter's blow left the office side at [staff_side.get_integrity()], not [full - 10]")
	TEST_ASSERT(findtext(jointext(staff_side.examine(warden), " "), "damaged"), "Examining the damaged window door does not show it")
	TEST_ASSERT(findtext(jointext(hatch.examine(warden), " "), "cracked"), "Examining the hatch does not show its cracked window door")

	// Thirty blows and it shatters: the hatch is forced open and climbed.
	for(var/blow in 2 to 29)
		rioter.confront(hatch)
	TEST_ASSERT(!QDELETED(staff_side) && !hatch.both_sides_open(), "The office side gave before thirty blows")
	rioter.confront(hatch)
	TEST_ASSERT(QDELETED(staff_side), "Thirty blows did not smash the office side") // 300 / PRISON_RIOT_WINDOOR_DAMAGE
	TEST_ASSERT(wait_until(CALLBACK(hatch, TYPE_PROC_REF(/obj/structure/table/reinforced/prison_hatch, both_sides_open)), 5 SECONDS), "The smashed hatch did not open")
	TEST_ASSERT(findtext(jointext(hatch.examine(warden), " "), "smashed out"), "Examining the hatch does not show its missing window door")
	TEST_ASSERT_EQUAL(rioter.riot_target(), hatch, "A rioter did not go for the smashed hatch")
	TEST_ASSERT(rioter.confront(hatch), "A rioter did not start over the smashed hatch")
	prison.tick(3)
	TEST_ASSERT_EQUAL(rioter.loc, prison_spot(home, 5, 5), "The rioter did not come down in the office")
	TEST_ASSERT_EQUAL(rioter.trouble, "loose", "A rioter over the smashed hatch is [rioter.trouble], not loose") // PRISONER_TROUBLE_LOOSE

	// A window door fitted where the office side was becomes the hatch's own again: outpost property
	// that no prisoner opens.
	var/obj/machinery/door/window/brigdoor/fitted = new(hatch.loc, REVERSE_DIR(hatch.yard_dir))
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(staff_side_fitted), hatch)), "A window door fitted to the hatch never became its office side")
	TEST_ASSERT(QDELETED(fitted), "The fitted window door was left beside the hatch's own")
	var/obj/machinery/door/window/restored = hatch.staff_windoor()
	TEST_ASSERT(restored.resistance_flags & INDESTRUCTIBLE, "The fitted office side is not outpost property")
	TEST_ASSERT(!restored.allowed(calm), "The fitted office side opens for prisoners")
	TEST_ASSERT_EQUAL(restored.dir, REVERSE_DIR(hatch.yard_dir), "The fitted office side faces [dir2text(restored.dir)]")
	prison.admin_calm()
	settle_prison_air(home)
