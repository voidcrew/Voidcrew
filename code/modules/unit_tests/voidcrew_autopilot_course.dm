/** Navigation tests use synthetic maps, so they also run on CI's MetaStation. */
/datum/unit_test/autopilot_course

/datum/unit_test/autopilot_course/proc/check_course(list/course, start_x, start_y, dest_x, dest_y, list/blocked)
	TEST_ASSERT(!isnull(course), "No course found to [dest_x],[dest_y]")
	var/previous_x = start_x
	var/previous_y = start_y
	for(var/list/node as anything in course)
		TEST_ASSERT_EQUAL(overmap_course_heuristic(previous_x, previous_y, node[1], node[2]), 1, "Nonadjacent course step")
		TEST_ASSERT(!blocked?["[node[1]],[node[2]]"], "Course enters a blocked tile")
		previous_x = node[1]
		previous_y = node[2]
	TEST_ASSERT_EQUAL(previous_x, dest_x, "Wrong destination X")
	TEST_ASSERT_EQUAL(previous_y, dest_y, "Wrong destination Y")

/datum/unit_test/autopilot_course/Run()
	// Voidcrew defines are included after tests: validate the 2..50 / 49-tile band.
	TEST_ASSERT_EQUAL(overmap_wrap_x(1), 50, "Update test bounds if the overmap changes")
	TEST_ASSERT_EQUAL(overmap_wrap_x(51), 2, "East seam should wrap to 2")
	TEST_ASSERT_EQUAL(overmap_wrap_x(-48), 50, "Negative coordinates must wrap")
	var/row = world.maxy - 25
	var/list/straight = plan_overmap_course(10, row, 20, row)
	check_course(straight, 10, row, 20, row)
	TEST_ASSERT_EQUAL(length(straight), 10, "Open-space route must be shortest")
	for(var/list/node as anything in straight)
		TEST_ASSERT_EQUAL(node[2], row, "A due-east route should not bow away from its row")

	var/list/wrapped = plan_overmap_course(10, row, 35, row)
	check_course(wrapped, 10, row, 35, row)
	TEST_ASSERT_EQUAL(length(wrapped), 24, "Wrapping must not carry an artificial surcharge")

	var/list/corner = plan_overmap_course(2, world.maxy - 1, 50, world.maxy - 49)
	check_course(corner, 2, world.maxy - 1, 50, world.maxy - 49)
	TEST_ASSERT_EQUAL(length(corner), 1, "Both seams should cross in one diagonal step")

	var/list/blocked = list()
	for(var/wall_y in row - 3 to row + 3)
		blocked["15,[wall_y]"] = TRUE
	var/list/detour = plan_overmap_course(10, row, 20, row, blocked)
	check_course(detour, 10, row, 20, row, blocked)
	TEST_ASSERT_EQUAL(length(detour), 10, "Diagonal detour should still take ten steps")

	// A previously unseen storm immediately across the seam is a real wall.
	blocked = list("50,[row]" = TRUE)
	detour = plan_overmap_course(2, row, 49, row, blocked)
	check_course(detour, 2, row, 49, row, blocked)
	TEST_ASSERT_EQUAL(length(detour), 2, "Seam hazard should have a short safe detour")
	TEST_ASSERT(isnull(plan_overmap_course(2, row, 50, row, blocked)), "A hazardous destination must be refused")

	blocked = list()
	for(var/offset_x in -1 to 1)
		for(var/offset_y in -1 to 1)
			if(offset_x || offset_y)
				blocked["[10 + offset_x],[row + offset_y]"] = TRUE
	TEST_ASSERT(isnull(plan_overmap_course(10, row, 20, row, blocked)), "Boxed-in ships must not be offered a dangerous fallback")
	// Starting in a hazard allows a clean exit, never another hazardous step.
	blocked = list("10,[row]" = TRUE)
	check_course(plan_overmap_course(10, row, 20, row, blocked), 10, row, 20, row, blocked)

/datum/unit_test/autopilot_zones/Run()
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/row = world.maxy - 25
	var/list/zones = list()
	// ZONE_GREEN=1, ZONE_YELLOW=2, ZONE_RED=3; defines follow tests in the DME.
	for(var/tile_x in 2 to 50)
		for(var/tile_y in world.maxy - 49 to world.maxy - 1)
			zones["[tile_x],[tile_y]"] = 1
	zones["15,[row]"] = 2
	zones["16,[row]"] = 3
	var/list/quickest = plan_overmap_course(10, row, 20, row, null, ship, zones)
	TEST_ASSERT(!isnull(quickest), "No course found with every zone allowed")
	for(var/list/node as anything in quickest)
		TEST_ASSERT_EQUAL(zones["[node[1]],[node[2]]"], 1, "Route added unnecessary ten-second zone crossings")
	TEST_ASSERT(ship.set_autopilot_pref("allowContested", FALSE), "Contested toggle rejected")
	TEST_ASSERT(ship.set_autopilot_pref("allowLawless", FALSE), "Lawless toggle rejected")
	var/list/course = plan_overmap_course(10, row, 20, row, null, ship, zones)
	TEST_ASSERT(!isnull(course), "No route around disabled zones")
	for(var/list/node as anything in course)
		TEST_ASSERT_EQUAL(zones["[node[1]],[node[2]]"], 1, "Route enters a disabled zone")
	TEST_ASSERT(isnull(plan_overmap_course(10, row, 15, row, null, ship, zones)), "Disabled destination must be rejected")
	TEST_ASSERT(isnull(plan_overmap_course(10, row, 16, row, null, ship, zones)), "Disabled Lawless destination must be rejected")
	ship.set_autopilot_pref("allowContested", TRUE)
	TEST_ASSERT(!isnull(plan_overmap_course(10, row, 15, row, null, ship, zones)), "Enabling a zone must allow its destination")
	TEST_ASSERT(!ship.autopilot_allow_lawless, "Zone toggles must be independent")
	ship.set_autopilot_pref("allowNeutral", FALSE)
	TEST_ASSERT(!isnull(plan_overmap_course(10, row, 15, row, null, ship, zones)), "Ships must be able to leave a disabled starting zone")
	ship.set_autopilot_pref("allowContested", FALSE)
	TEST_ASSERT(isnull(plan_overmap_course(10, row, 15, row, null, ship, zones)), "All-disabled policy must refuse travel")
	TEST_ASSERT(!ship.set_autopilot_pref("crossMeteor", TRUE), "Removed hazard override must not be accepted")

/datum/unit_test/autopilot_private_navigation/Run()
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/list/blocked = ship.build_autopilot_danger_map()
	TEST_ASSERT_EQUAL(blocked, ship.build_autopilot_danger_map(), "Unchanged hazards should reuse the map")
	TEST_ASSERT_EQUAL(length(ship.discovered_contacts), 0, "Navigation must not discover contacts")
	TEST_ASSERT(isnull(ship.surveyed_tiles), "Navigation must not survey space")
	TEST_ASSERT(isnull(ship.contact_snapshot), "Navigation must not invoke sensors")
	ship.autopilot_engaged = TRUE
	ship.autopilot_dest_x = ship.x + 2
	ship.autopilot_dest_y = ship.y
	ship.autopilot_path = list(list(ship.x + 1, ship.y), list(ship.x + 2, ship.y))
	var/list/data = ship.get_autopilot_data()
	TEST_ASSERT(!("path" in data), "Private route leaked to client")
	TEST_ASSERT(!("remaining" in data), "Private route length leaked to client")
	TEST_ASSERT(!("danger" in data), "Private hazard map leaked to client")
	// A safe course does not expire; a newly blocked step does force replanning.
	TEST_ASSERT(!ship.autopilot_course_needs_replan(list(), list()), "Safe route should be retained")
	TEST_ASSERT(ship.autopilot_course_needs_replan(list("[ship.x + 1],[ship.y]" = TRUE), list()), "Newly blocked route must be replaced")
	ship.autopilot_engaged = FALSE

/datum/unit_test/overmap_seam_sight/Run()
	TEST_ASSERT(in_view_ring(list(2, 25), list(50, 25)), "Sight must cross the west/east seam")
	TEST_ASSERT(in_view_ring(list(25, 2), list(25, 50)), "Sight must cross the south/north seam")
	TEST_ASSERT(in_view_ring(list(2, 2), list(50, 50)), "Sight must cross both seams at a corner")
	TEST_ASSERT(!in_view_ring(list(2, 2), list(47, 47)), "Wrapped sight must still respect circular range")
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	ship.mark_surveyed(list(2, 2))
	TEST_ASSERT(ship.is_tile_surveyed(50, 50), "Visible corner tile was not surveyed")
	TEST_ASSERT(!ship.is_tile_surveyed(47, 47), "Survey extended beyond sight")

/datum/unit_test/autopilot_hazard_cache/Run()
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/list/before = ship.build_autopilot_danger_map()
	var/obj/structure/overmap/event/hazard = allocate(/obj/structure/overmap/event)
	TEST_ASSERT(hazard in SSovermap.autopilot_hazards, "New hazards must register even when not generated at roundstart")
	TEST_ASSERT(isnull(SSovermap.autopilot_blocked_tiles), "New hazard must invalidate navigation cache")
	var/list/after = ship.build_autopilot_danger_map()
	TEST_ASSERT_NOTEQUAL(before, after, "New hazard did not rebuild the cache")
	// Unit-test turfs are outside the overmap: their contents must not leak in.
	TEST_ASSERT(!after["[hazard.x],[hazard.y]"], "Off-map hazard entered the navigation grid")
	hazard.forceMove(get_step(hazard, NORTH))
	TEST_ASSERT(isnull(SSovermap.autopilot_blocked_tiles), "Moving a hazard must invalidate navigation cache")
	ship.build_autopilot_danger_map()
	qdel(hazard)
	TEST_ASSERT(!(hazard in SSovermap.autopilot_hazards), "Deleted hazard remained registered")
	TEST_ASSERT(isnull(SSovermap.autopilot_blocked_tiles), "Deleted hazard must invalidate navigation cache")
	var/obj/structure/overmap/event/nebula/nebula = allocate(/obj/structure/overmap/event/nebula)
	TEST_ASSERT(!(nebula in SSovermap.autopilot_hazards), "Navigable nebula should not be a storm wall")

/// Exercise the real steering and movement calls without constructing an engine room.
/obj/structure/overmap/ship/autopilot_test/can_thrust()
	return TRUE

/datum/unit_test/autopilot_movement_guard
	var/list/saved_blocked
	var/list/saved_zones

/datum/unit_test/autopilot_movement_guard/Destroy()
	SSovermap.autopilot_blocked_tiles = saved_blocked
	SSovermap.autopilot_zone_tiles = saved_zones
	return ..()

/datum/unit_test/autopilot_movement_guard/Run()
	saved_blocked = SSovermap.autopilot_blocked_tiles
	saved_zones = SSovermap.autopilot_zone_tiles
	SSovermap.autopilot_zone_tiles = list()
	var/obj/structure/overmap/ship/autopilot_test/ship = allocate(/obj/structure/overmap/ship/autopilot_test)
	// Pure navigation coordinates, on the test z-level. Only the ship is moved.
	var/row = world.maxy - 25
	ship.forceMove(locate(2, row, run_loc_floor_bottom_left.z))
	ship.state = "flying" // OVERMAP_SHIP_FLYING
	SSovermap.autopilot_blocked_tiles = list()
	ship.engage_autopilot(49, row, "test")
	TEST_ASSERT(ship.autopilot_engaged, "Course did not engage")
	// A hazard appears after planning, immediately across the west seam.
	SSovermap.autopilot_blocked_tiles = list("50,[row]" = TRUE)
	ship.speed = list(-ship.max_speed, 0)
	ship.tick_move()
	TEST_ASSERT_EQUAL(ship.x, 2, "Movement guard let the ship cross into a new hazard")
	TEST_ASSERT_EQUAL(ship.y, row, "Movement guard moved ship before replanning")
	TEST_ASSERT(ship.autopilot_engaged, "Safe detour should remain engaged")
	var/list/next = ship.autopilot_path[1]
	TEST_ASSERT(next[1] != 50 || next[2] != row, "Replan still points into seam hazard")

	// Zone crossings wait before moving: new hazards during that delay count too.
	ship.full_stop()
	ship.autopilot_path = list(list(3, row), list(4, row))
	ship.autopilot_dest_x = 4
	ship.zone_transitioning = TRUE
	ship.zone_transition_target = locate(3, row, ship.z)
	SSovermap.autopilot_blocked_tiles = list("3,[row]" = TRUE)
	ship.complete_zone_transition()
	TEST_ASSERT_EQUAL(ship.x, 2, "Delayed zone crossing entered a newly blocked tile")
	TEST_ASSERT(!ship.zone_transitioning, "Blocked crossing stayed latched")

	// Policy changes cancel pending entry before replanning under the new rules.
	SSovermap.autopilot_zone_tiles = list("3,[row]" = 3, "4,[row]" = 3)
	SSovermap.autopilot_blocked_tiles = list()
	ship.zone_transitioning = TRUE
	ship.zone_transition_target = locate(3, row, ship.z)
	ship.set_autopilot_pref("allowLawless", FALSE)
	TEST_ASSERT(!ship.zone_transitioning, "Zone toggle did not cancel pending crossing")
	TEST_ASSERT(!ship.autopilot_engaged, "Disabled destination should end the course")
	TEST_ASSERT(ship.is_still(), "Failed replan must leave ship stopped")
