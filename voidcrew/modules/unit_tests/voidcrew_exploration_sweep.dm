/// An exploration contract aimed at whatever test-room spot the test caches into its target
/datum/mission/exploration/sweep_test
	// Never rolled onto a real board
	weight = 0

/datum/mission/exploration/sweep_test/setup_target()
	target = new /datum/mission_target/exploration_sweep_test(src)
	return TRUE

/// A green destination with no overmap object behind it
/datum/mission_target/exploration_sweep_test

/datum/mission_target/exploration_sweep_test/get_zone_type()
	return 1 // ZONE_GREEN

/**
 * Arriving at an exploration site starts a sweep rather than finishing the job: the
 * ship holds station, drifting off pauses it without losing it, two crews on one site
 * sweep independently, and the only thing a sweep turns up is an ordinary derelict
 * signal that was already out there.
 */
/datum/unit_test/voidcrew_exploration_sweep

/datum/unit_test/voidcrew_exploration_sweep/proc/make_ship()
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	ship.ship_team = allocate(/datum/team/voidcrew)
	ship.ship_team.ship = ship
	allocated += ship.get_crew_record()
	return ship

/datum/unit_test/voidcrew_exploration_sweep/proc/make_contract(turf/site)
	var/datum/mission/exploration/sweep_test/contract = allocate(/datum/mission/exploration/sweep_test)
	contract.target?.cache_coords_from(site)
	return contract

/datum/unit_test/voidcrew_exploration_sweep/Run()
	var/turf/site = run_loc_floor_top_right
	var/turf/away = run_loc_floor_bottom_left
	// Two tiles off the site: past the arrival range, still on station for the sweep
	var/turf/edge = locate(site.x - 2, site.y, site.z)
	TEST_ASSERT_NOTNULL(edge, "The test room must have a tile two west of its top right corner.")

	var/obj/structure/overmap/ship/first_ship = make_ship()
	var/obj/structure/overmap/ship/second_ship = make_ship()
	first_ship.forceMove(away)
	second_ship.forceMove(away)

	var/datum/mission/exploration/sweep_test/first = make_contract(site)
	var/datum/mission/exploration/sweep_test/second = make_contract(site)
	TEST_ASSERT(!first.generation_failed && !second.generation_failed, "The test exploration contracts must generate.")
	var/datum/mission_objective/sector_sweep/first_sweep = first.sweep
	var/datum/mission_objective/sector_sweep/second_sweep = second.sweep
	TEST_ASSERT_NOTNULL(first_sweep, "Exploration must build a sweep step.")
	TEST_ASSERT_EQUAL(length(first.objectives), 2, "Exploration is travel, then the sweep.")
	var/datum/mission_objective/goto_coords/first_approach = first.objectives[1]
	TEST_ASSERT(istype(first_approach), "Exploration must still open with the travel step.")
	TEST_ASSERT_NULL(first_approach.arrival_message, "The sweep announces the arrival, not the travel step.")
	TEST_ASSERT_EQUAL(first.objectives[2], first_sweep, "The sweep must be the contract's last step.")
	TEST_ASSERT(!first.requires_item, "Exploration is still claimed at the board, with nothing to hand over.")

	// Only the second crew's sweep can pick anything up
	first_sweep.find_chance = 0
	second_sweep.find_chance = 100
	var/obj/structure/overmap/space_ruin/rumour_site = allocate(/obj/structure/overmap/space_ruin, away)
	rumour_site.rare = TRUE
	var/obj/structure/overmap/space_ruin/derelict = allocate(/obj/structure/overmap/space_ruin, away)

	TEST_ASSERT(first.start_mission(first_ship), "The first exploration contract must start.")
	TEST_ASSERT(second.start_mission(second_ship), "The second exploration contract must start.")
	TEST_ASSERT(!first_sweep.active, "The sweep waits until the ship reaches the site.")

	// Arrival: the travel step is done, the sweep runs, and the contract is not claimable yet
	first_ship.forceMove(site)
	TEST_ASSERT(first_approach.completed, "Reaching the site must finish the travel step.")
	TEST_ASSERT(first_sweep.active && first_sweep.running, "Reaching the site must start the sweep.")
	TEST_ASSERT_NOTNULL(first_sweep.finish_timer, "A running sweep must have its finish timer armed.")
	TEST_ASSERT(!first.can_complete(), "Arriving alone must not make the contract claimable.")
	TEST_ASSERT(!second_sweep.active, "One crew reaching the site must not start another crew's sweep.")

	second_ship.forceMove(site)
	TEST_ASSERT(second_sweep.running, "The second crew's sweep must start when its own ship arrives.")
	TEST_ASSERT_EQUAL(second_sweep.find_ref?.resolve(), derelict, "The sweep must pick up the plain derelict signal and pass over the rumour site.")

	// Drifting to the edge of the site keeps sweeping
	first_ship.forceMove(edge)
	TEST_ASSERT(first_sweep.running, "A ship two tiles off the site is still on station.")

	// Leaving pauses this crew's sweep only, and keeps it
	first_ship.forceMove(away)
	TEST_ASSERT(!first_sweep.running, "Leaving the site must pause the sweep.")
	TEST_ASSERT_NULL(first_sweep.finish_timer, "A paused sweep must not finish on its own.")
	TEST_ASSERT(first_sweep.active && !first_sweep.completed, "A paused sweep stays the contract's current step.")
	TEST_ASSERT_EQUAL(first_sweep.get_progress_string(), "Sweep broken off", "The board must show the sweep as broken off.")
	TEST_ASSERT(!first.can_complete(), "A broken-off sweep must not make the contract claimable.")
	TEST_ASSERT(second_sweep.running, "Another crew leaving must not pause this crew's sweep.")

	first_ship.forceMove(site)
	TEST_ASSERT(first_sweep.running, "Coming back must resume the sweep.")
	TEST_ASSERT_NOTNULL(first_sweep.finish_timer, "A resumed sweep must re-arm its finish timer.")

	// The find is rolled once: breaking off and coming back with no luck left keeps it
	second_ship.forceMove(away)
	second_sweep.find_chance = 0
	second_ship.forceMove(site)
	TEST_ASSERT_EQUAL(second_sweep.find_ref?.resolve(), derelict, "Breaking off and coming back must not reroll the find.")

	first_sweep.finish_sweep()
	TEST_ASSERT(first_sweep.completed, "A finished sweep must complete its step.")
	TEST_ASSERT(first.can_complete(), "A finished sweep must leave the contract ready to claim at the board.")
	var/datum/ship_waypoint/site_mark = first_ship.get_waypoint(REF(first))
	TEST_ASSERT_NOTNULL(site_mark, "The contract's site stays on the helm until it is claimed.")
	TEST_ASSERT_EQUAL(site_mark.name, "Charted sector", "The site's helm label must change once it is charted.")
	TEST_ASSERT_NULL(first_ship.get_waypoint(REF(derelict)), "A sweep with no find must chart nothing extra.")

	second_sweep.finish_sweep()
	TEST_ASSERT(second.can_complete(), "The second crew's contract must finish on its own sweep.")
	TEST_ASSERT_NOTNULL(second_ship.get_waypoint(REF(derelict)), "The find must be charted on the sweeping crew's helm.")
	TEST_ASSERT_NULL(second_ship.get_waypoint(REF(rumour_site)), "A rumour site must never be charted by a sweep.")
	TEST_ASSERT_NULL(first_ship.get_waypoint(REF(derelict)), "One crew's find must not chart on another crew's helm.")
