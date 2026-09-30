/**
 * Prisoners running from creatures (outpost_prison_panic.dm), and trouble that goes on through an
 * experiment: what frightens them and what does not, calming down, where they run, rioters and
 * fighters rolling to run or fight, and a lock-in that costs nothing while they hide.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with the procs tick() calls, with their own
 * processing stopped. Nobody is on the level, so the creatures and the prisoners stay where they are
 * put. Fixtures are in voidcrew_outpost_prison_helpers.dm, voidcrew_outpost_prison_trouble.dm and
 * voidcrew_outpost_prison_experiments.dm.
 */

/// The cell tile farthest from both its bed and its door: where a creature leaves a way out past it
/datum/unit_test/voidcrew_outpost_management/proc/panic_far_corner(datum/outpost_prison_cell/cell)
	var/turf/bed_turf = get_turf(cell.bed())
	var/turf/best
	var/best_score = -1
	for(var/turf/tile as anything in cell.turfs)
		if(tile == bed_turf || tile.is_blocked_turf(TRUE))
			continue
		var/score = get_dist(tile, bed_turf) + get_dist(tile, cell.door_turf)
		if(score > best_score)
			best = tile
			best_score = score
	return best

// ===== WHAT FRIGHTENS THEM =====

/datum/unit_test/voidcrew_outpost_prison_panic_triggers
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_panic_triggers/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = experiment_test_claim("panicowner", trouble = TRUE)
	TEST_ASSERT_NOTNULL(home, "The panic test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	trouble_fund(home, 0)
	// One by the bookcases in the yard's corner, one in front of the office windows
	var/mob/living/basic/outpost_prisoner/corner = trouble_prisoner(prison, prison_spot(home, 3, 8))
	var/mob/living/basic/outpost_prisoner/watcher = trouble_prisoner(prison, prison_spot(home, 8, 8))

	// A hulk in the office behind the wall: outside the cell block and out of their sight, so nobody runs.
	var/mob/living/basic/outpost_experiment/hulk/hulk = allocate(/mob/living/basic/outpost_experiment/hulk, prison_spot(home, 3, 3), prison, null)
	TEST_ASSERT(!prison.in_cell_block(hulk), "The office counts as the cell block")
	TEST_ASSERT(!can_see(corner, hulk, 7) && !can_see(watcher, hulk, 7), "The test spots in the yard can see the office corner")
	prison.experiment_creature_appeared(hulk, "hulk")
	prison.creature_panic_tick(1)
	TEST_ASSERT(!corner.is_panicking() && !watcher.is_panicking(), "A creature out of sight outside the cell block frightened the yard")
	TEST_ASSERT(!istype(watcher.activity, /datum/prisoner_activity/creature_panic), "A prisoner ran from a creature they cannot see")

	// Behind the office windows, four tiles off: it frightens the one who can see it, who runs.
	hulk.forceMove(prison_spot(home, 8, 4))
	TEST_ASSERT(!prison.in_cell_block(hulk), "The office counts as the cell block")
	TEST_ASSERT(can_see(watcher, hulk, 7), "The prisoner at the office windows cannot see into the office")
	prison.creature_panic_tick(1)
	TEST_ASSERT(watcher.is_panicking(), "A creature in sight within range did not frighten a prisoner")
	TEST_ASSERT(istype(watcher.activity, /datum/prisoner_activity/creature_panic), "A frightened prisoner did not run ([watcher.activity?.type])")
	TEST_ASSERT_EQUAL(watcher.speed, 1.3, "A running prisoner moves at [watcher.speed], not 1.3") // OUTPOST_PANIC_FLEE_SPEED
	if(!can_see(corner, hulk, 7))
		TEST_ASSERT(!corner.is_panicking(), "A creature out of sight frightened a prisoner")

	// Out of sight again: still frightened for a minute, then back to their day.
	hulk.forceMove(prison_spot(home, 3, 3))
	prison.creature_panic_tick(59)
	TEST_ASSERT(watcher.is_panicking(), "A prisoner calmed down before a minute was up") // OUTPOST_PANIC_CALM_TIME
	TEST_ASSERT(istype(watcher.activity, /datum/prisoner_activity/creature_panic), "A prisoner stopped hiding before a minute was up")
	prison.creature_panic_tick(2)
	TEST_ASSERT(!watcher.is_panicking(), "A prisoner was still frightened a minute after the creature went out of sight")
	TEST_ASSERT(!istype(watcher.activity, /datum/prisoner_activity/creature_panic), "A calm prisoner kept running")
	TEST_ASSERT_EQUAL(watcher.speed, 2, "A calm prisoner kept running at [watcher.speed]")
	prison.calm_from_panic(corner)

	// Loose in the cell block, it frightens everyone, however far off and out of sight.
	var/datum/outpost_prison_cell/far_cell = prison.cell_at(prison_spot(home, 15, 14))
	TEST_ASSERT_NOTNULL(far_cell, "No cell at the far end of the row")
	TEST_ASSERT(!far_cell.occupant, "The far cell is taken")
	hulk.forceMove(prison_spot(home, 15, 14))
	TEST_ASSERT(prison.in_cell_block(hulk), "A cell is not in the cell block")
	TEST_ASSERT(get_dist(corner, hulk) > 7, "The far cell is within sight range of the corner")
	prison.creature_panic_tick(1)
	TEST_ASSERT(corner.is_panicking(), "A creature loose in the cell block did not frighten a prisoner out of its sight")

	// Shut in that cell behind a bolted door, it frightens only those who can see it.
	var/obj/machinery/door/airlock/far_door = far_cell.door()
	TEST_ASSERT_NOTNULL(far_door, "The far cell has no door")
	if(!far_door.density)
		far_door.close()
	far_door.bolt()
	TEST_ASSERT(prison.creature_shut_in(hulk), "A hulk in a bolted cell does not count as shut in")
	TEST_ASSERT(!prison.creature_out(), "The guards would hide from a hulk shut in a bolted cell")
	prison.calm_from_panic(corner)
	prison.calm_from_panic(watcher)
	prison.creature_panic_tick(1)
	TEST_ASSERT(!corner.is_panicking(), "A creature shut in a bolted cell frightened a prisoner who cannot see it")
	far_door.unbolt()
	TEST_ASSERT(!prison.creature_shut_in(hulk), "A hulk behind an unbolted door counts as shut in")
	TEST_ASSERT(prison.creature_out(), "The guards would stay out with a hulk loose")

	// A horror down regenerating frightens only up close, loose or not.
	var/mob/living/basic/outpost_experiment/horror/horror = allocate(/mob/living/basic/outpost_experiment/horror, prison_spot(home, 10, 8))
	TEST_ASSERT_EQUAL(outpost_creature_menace(horror), 2, "A horror on its feet does not fully frighten") // CREATURE_MENACE_FULL
	horror.regenerating = TRUE
	TEST_ASSERT_EQUAL(outpost_creature_menace(horror), 1, "A horror down regenerating frightens from afar") // CREATURE_MENACE_NEAR
	TEST_ASSERT(prison.frightens(watcher, horror, 1, TRUE), "A horror down two tiles off frightened nobody")
	TEST_ASSERT(!prison.frightens(corner, horror, 1, TRUE), "A horror down seven tiles off frightened someone")
	horror.regenerating = FALSE
	qdel(horror)

	// In Kessler's hands, nothing frightens anyone.
	prison.experiment_end_admin()
	TEST_ASSERT_EQUAL(outpost_creature_menace(hulk), 0, "A hulk Kessler is taking still frightens") // CREATURE_MENACE_NONE
	settle_prison_air(home)

// ===== WHERE THEY RUN =====

/datum/unit_test/voidcrew_outpost_prison_panic_flight
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_panic_flight/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = experiment_test_claim("fleeowner", trouble = TRUE)
	TEST_ASSERT_NOTNULL(home, "The flight test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	trouble_fund(home, 0)
	var/turf/middle = prison_spot(home, 9, 8)
	var/mob/living/basic/outpost_prisoner/runner = trouble_prisoner(prison, middle)
	var/datum/outpost_prison_cell/own = runner.cell
	TEST_ASSERT_NOTNULL(own, "The test prisoner has no cell")
	var/obj/structure/chair/seat = own.chair()
	TEST_ASSERT_NOTNULL(seat, "The test prisoner's cell has no chair")
	var/turf/seat_turf = get_turf(seat)

	// Across the yard from their cell: home is safe, and they run for their cell's chair.
	var/far_x = own.door_turf.x < middle.x ? 15 : 3
	var/mob/living/basic/outpost_experiment/hulk/hulk = allocate(/mob/living/basic/outpost_experiment/hulk, prison_spot(home, far_x, 8), prison, null)
	prison.experiment_creature_appeared(hulk, "hulk")
	var/datum/prisoner_activity/creature_panic/panic = runner.activity
	TEST_ASSERT(istype(panic), "A prisoner in the yard with a hulk loose in it did not run ([runner.activity?.type])")
	TEST_ASSERT_EQUAL(panic.plan, "home", "With the hulk across the yard, the prisoner did not run for their cell")
	TEST_ASSERT_EQUAL(panic.spot, seat_turf, "The prisoner did not run for their cell's chair")
	runner.forceMove(seat_turf)
	panic.arrive()
	TEST_ASSERT(own.contains(runner), "The prisoner is not in their cell")
	TEST_ASSERT_EQUAL(runner.buckled, seat, "Home from a hulk, the prisoner did not sit in their cell's chair")

	// It comes into the cell where they hide: out they go, and away from it.
	var/turf/far_corner = panic_far_corner(own)
	TEST_ASSERT_NOTNULL(far_corner, "The cell has no free corner")
	hulk.forceMove(far_corner)
	prison.creature_panic_tick(1)
	TEST_ASSERT_EQUAL(runner.activity, panic, "The prisoner stopped running")
	TEST_ASSERT_EQUAL(panic.plan, "away", "A prisoner hiding in their cell stayed with the hulk in there with them ([panic.plan])")
	var/turf/away = panic.spot
	TEST_ASSERT_NOTNULL(away, "The prisoner had nowhere to run from their cell")
	TEST_ASSERT(!own.contains(away), "The prisoner ran to somewhere in their own cell")
	TEST_ASSERT(get_dist(away, hulk) > 2, "The prisoner ran to [get_dist(away, hulk)] tiles from the hulk") // OUTPOST_PANIC_SPOT_MARGIN
	TEST_ASSERT(prison.in_cell_block(away), "The prisoner ran out of the cell block")
	TEST_ASSERT(!can_see(hulk, away, 7), "The prisoner ran somewhere the hulk can see, with places it cannot")

	// Between them and their cell door: it would get there first, so they run the other way.
	prison.calm_from_panic(runner)
	runner.forceMove(middle)
	prison.refresh_prisoner_reach(runner)
	var/turf/door = own.door_turf
	var/turf/between = locate(door.x + (door.x < middle.x ? 2 : -2), door.y - 2, door.z)
	hulk.forceMove(between)
	prison.creature_panic_tick(1)
	panic = runner.activity
	TEST_ASSERT(istype(panic), "A prisoner with a hulk near their cell door did not run ([runner.activity?.type])")
	TEST_ASSERT_EQUAL(panic.plan, "away", "The prisoner ran for home past a hulk nearer their cell door than they were")
	TEST_ASSERT(get_dist(panic.spot, hulk) > get_dist(runner, hulk), "The prisoner ran toward the hulk")
	TEST_ASSERT(!own.contains(panic.spot), "The prisoner ran into their cell with the hulk at its door")
	prison.experiment_end_admin()
	settle_prison_air(home)

// ===== RIOTERS AND FIGHTERS =====

/datum/unit_test/voidcrew_outpost_prison_panic_rioters
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_panic_rioters/Run()
	// The odds: a quarter at mood 30, likelier the sourer, likelier grumpy, less likely nervous, never certain.
	TEST_ASSERT_EQUAL(outpost_prisoner_creature_fight_chance(30, "chatty"), 25, "A chatty prisoner at 30 goes for a creature [outpost_prisoner_creature_fight_chance(30, "chatty")]% of the time, not 25") // OUTPOST_PANIC_FIGHT_CHANCE
	TEST_ASSERT(outpost_prisoner_creature_fight_chance(30, "grumpy") > 25, "A grumpy prisoner is no likelier to fight a creature")
	TEST_ASSERT(outpost_prisoner_creature_fight_chance(30, "nervous") < 25, "A nervous prisoner is no less likely to fight a creature")
	TEST_ASSERT(outpost_prisoner_creature_fight_chance(0, "chatty") > outpost_prisoner_creature_fight_chance(60, "chatty"), "A sour prisoner is no likelier to fight a creature than a content one")
	TEST_ASSERT(outpost_prisoner_creature_fight_chance(0, "grumpy") <= 50 && outpost_prisoner_creature_fight_chance(100, "nervous") >= 5, "The odds of fighting a creature leave their bounds") // OUTPOST_PANIC_FIGHT_MAX, _MIN

	var/obj/structure/overmap/dynamic/player_outpost/home = experiment_test_claim("rioterowner", trouble = TRUE)
	TEST_ASSERT_NOTNULL(home, "The rioter test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	trouble_fund(home, 0)
	var/mob/living/basic/outpost_prisoner/first = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/second = trouble_prisoner(prison, prison_spot(home, 10, 8))
	set_moods(list(first, second), 20)

	// Two fighters who roll to run: the fight is over, and they run like anyone.
	prison.forced_creature_reaction = "flee"
	TEST_ASSERT_NOTNULL(prison.start_fight(first, second), "The test fight did not start")
	var/mob/living/basic/outpost_experiment/hulk/hulk = allocate(/mob/living/basic/outpost_experiment/hulk, prison_spot(home, 9, 10), prison, null)
	prison.experiment_creature_appeared(hulk, "hulk")
	TEST_ASSERT(!length(prison.fights), "Two fighters who ran from a hulk kept fighting")
	for(var/mob/living/basic/outpost_prisoner/fighter as anything in list(first, second))
		TEST_ASSERT(fighter.trouble != "fight", "[fighter] is still fighting") // PRISONER_TROUBLE_FIGHT
		TEST_ASSERT(istype(fighter.activity, /datum/prisoner_activity/creature_panic), "[fighter] did not run from the hulk ([fighter.activity?.type])")

	// A fighter who rolls to fight goes for it instead.
	prison.calm_from_panic(first)
	prison.calm_from_panic(second)
	TEST_ASSERT_NOTNULL(prison.start_fight(first, second), "The second test fight did not start")
	prison.forced_creature_reaction = "fight"
	prison.creature_panic_tick(1)
	TEST_ASSERT(!length(prison.fights), "The fight went on after a fighter turned on the hulk")
	TEST_ASSERT_EQUAL(first.creature_foe(), hulk, "A fighter who rolled to fight did not go for the hulk")
	TEST_ASSERT_EQUAL(first.trouble_target(), hulk, "A fighter going for the hulk is going for [first.trouble_target() || "nothing"]")
	TEST_ASSERT(first.in_trouble(), "A prisoner going for the hulk went back to their routine")
	TEST_ASSERT(outpost_prison_turret_verdict(first) != 2, "A turret would shoot a prisoner for going at a creature") // OUTPOST_PRISON_TURRET_SHOOT

	// A riot starts with the hulk loose. A rioter who rolls to run stays a rioter, running.
	prison.calm_from_panic(first)
	prison.calm_from_panic(second)
	TEST_ASSERT(prison.start_riot("test"), "A riot could not start during an experiment")
	TEST_ASSERT(first.is_rioting() && second.is_rioting(), "The sour prisoners did not join the riot")
	prison.forced_creature_reaction = "flee"
	prison.creature_panic_tick(1)
	TEST_ASSERT(first.is_rioting(), "A rioter who ran from the hulk stopped rioting")
	TEST_ASSERT_NOTNULL(first.creature_retreat_spot, "A rioter who rolled to run did not run")
	TEST_ASSERT(get_dist(first.creature_retreat_spot, hulk) > get_dist(first, hulk), "The rioter ran toward the hulk")
	TEST_ASSERT(prison.in_cell_block(first.creature_retreat_spot), "The rioter ran out of the cell block")
	TEST_ASSERT_EQUAL(first.speed, 1.3, "A running rioter moves at [first.speed], not 1.3") // OUTPOST_PANIC_FLEE_SPEED

	// The roll runs out, and the next one sends them at it, shiv and all.
	first.creature_reaction_until = 0
	prison.forced_creature_reaction = "fight"
	prison.creature_panic_tick(1)
	TEST_ASSERT_EQUAL(first.creature_foe(), hulk, "A rioter who rolled to fight did not go for the hulk")
	TEST_ASSERT_EQUAL(first.trouble_target(), hulk, "A rioter going for the hulk is going for [first.trouble_target() || "nothing"]")
	TEST_ASSERT_NULL(first.creature_retreat_spot, "A rioter going for the hulk is still running from it")

	// Down, they cannot run: they cower where they lie.
	second.creature_reaction_until = 0
	second.collapse()
	prison.forced_creature_reaction = "flee"
	prison.creature_panic_tick(1)
	TEST_ASSERT(second.is_panicking(), "A prisoner down with a hulk beside them is not frightened")
	TEST_ASSERT_NULL(second.creature_retreat_spot, "A prisoner who is down ran")
	TEST_ASSERT(!istype(second.activity, /datum/prisoner_activity/creature_panic), "A prisoner who is down ran")
	second.recover()

	prison.forced_creature_reaction = null
	prison.admin_calm()
	prison.set_subdued(0)
	prison.experiment_end_admin()
	settle_prison_air(home)

// ===== HIDING, AND TROUBLE THAT GOES ON =====

/datum/unit_test/voidcrew_outpost_prison_panic_shelter
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_panic_shelter/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = experiment_test_claim("shelterowner", trouble = TRUE)
	TEST_ASSERT_NOTNULL(home, "The shelter test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	trouble_fund(home, 0)
	var/mob/living/basic/outpost_prisoner/subject = trouble_prisoner(prison, prison_spot(home, 12, 8))
	var/mob/living/basic/outpost_prisoner/hider = trouble_prisoner(prison, prison_spot(home, 8, 8))

	// While the serum works, nothing waits for it: no protective custody, incidents and wing events
	// can come, a riot can start, and the guards stay on duty.
	TEST_ASSERT(prison.start_experiment("hulk", subject), "The subject could not be dosed")
	TEST_ASSERT(!prison.protective_custody(), "An experiment made bolting prisoners in protective custody")
	TEST_ASSERT(!prison.creature_out(), "The guards would hide from a serum that has not taken")
	prison.wildcards_enabled = TRUE
	prison.wildcard_gap_left = 0
	TEST_ASSERT_NULL(prison.wildcard_clock_paused(), "The incident clock waits for the experiment ([prison.wildcard_clock_paused()])")
	TEST_ASSERT_NULL(prison.wildcard_refusal("snap"), "An admin cannot start a snap during an experiment")
	prison.wildcards_enabled = FALSE
	prison.wing_events_enabled = TRUE
	TEST_ASSERT_NULL(prison.wing_event_clock_paused(), "The wing events wait for the experiment ([prison.wing_event_clock_paused()])")
	prison.wing_events_enabled = FALSE
	// A spark in a restless wing
	hider.set_mood(20)
	prison.stage = "restless" // PRISON_STAGE_RESTLESS
	TEST_ASSERT(prison.trouble_event(1, "test"), "A spark in a restless wing started no riot during an experiment")
	TEST_ASSERT(prison.riot_active, "No riot during the experiment")
	prison.admin_calm()
	prison.set_subdued(0)
	prison.experiment_end_admin()
	hider.set_mood(70)

	// Shut in their own cell with a hulk loose in the yard: frightened, and the lock-in costs them nothing.
	var/datum/outpost_prison_cell/own = hider.cell
	TEST_ASSERT_NOTNULL(own?.bed(), "The hider has no cell with a bed")
	hider.forceMove(get_turf(own.bed()))
	var/obj/machinery/door/airlock/door = own.door()
	TEST_ASSERT_NOTNULL(door, "The hider's cell has no door")
	if(!door.density)
		door.close()
	door.bolt()
	prison.refresh_reach()
	TEST_ASSERT(hider.is_confined(), "The hider is not shut in their cell")
	var/mob/living/basic/outpost_experiment/hulk/hulk = allocate(/mob/living/basic/outpost_experiment/hulk, prison_spot(home, 9, 9), prison, null)
	prison.experiment_creature_appeared(hulk, "hulk")
	TEST_ASSERT(hider.is_panicking(), "A hulk loose in the yard did not frighten a prisoner in their cell")
	TEST_ASSERT(hider.sheltering_from_creature(), "A frightened prisoner bolted in their own cell is not sheltering")
	prison.update_locked_in(hider, 150)
	TEST_ASSERT_EQUAL(hider.locked_in_seconds, 0, "Hiding from a hulk in their own cell counted as [hider.locked_in_seconds] s locked in")
	hider.locked_in_seconds = 200
	TEST_ASSERT(!prison.confined_unpaid(hider), "Hiding from a hulk stopped their pay") // OUTPOST_PRISON_CONFINED_PAY_AFTER
	TEST_ASSERT(prison.pay_factor(hider) > 0, "A prisoner hiding from a hulk earned nothing")
	var/sheltered_drift = hider.mood_drift_per_minute()
	hider.locked_in_seconds = 0

	// The hulk out of sight in the office: a minute later they calm down, and the usual clock runs again.
	hulk.forceMove(prison_spot(home, 3, 3))
	prison.creature_panic_tick(61)
	TEST_ASSERT(!hider.is_panicking(), "The hider did not calm down a minute after the hulk went out of sight")
	TEST_ASSERT(!hider.sheltering_from_creature(), "A calm prisoner still counts as sheltering")
	prison.update_locked_in(hider, 150)
	TEST_ASSERT_EQUAL(hider.locked_in_seconds, 150, "Once calm, being bolted in counted [hider.locked_in_seconds] s, not 150")
	hider.locked_in_seconds = 200
	TEST_ASSERT(prison.confined_unpaid(hider), "Once calm, a long lock-in still paid")
	TEST_ASSERT(hider.mood_drift_per_minute() < sheltered_drift, "Once calm, a long lock-in cost no mood")
	hider.locked_in_seconds = 0
	door.unbolt()
	prison.experiment_end_admin()
	settle_prison_air(home)
