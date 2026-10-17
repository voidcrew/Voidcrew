/**
 * Incoming missiles pick the side they fly in from by asking whether the line to the
 * target is clear. "Clear" has to mean the missile actually gets there. A missile
 * detonates on any dense thing it bumps, windows and grilles included, so a line
 * through a window must lose to an open breach on another side. Border objects such
 * as railings only stop it when it crosses their blocking edge.
 *
 * Built in a reserved space block around a small walled target.
 */
/datum/unit_test/voidcrew_missile_approach
	var/datum/turf_reservation/reserved
	/// Bottom-left corner of the working block.
	var/turf/anchor

/datum/unit_test/voidcrew_missile_approach/New()
	..()
	reserved = SSmapping.request_turf_block_reservation(15, 15, 1)
	anchor = reserved?.bottom_left_turfs[1]

/datum/unit_test/voidcrew_missile_approach/Destroy()
	qdel(reserved)
	return ..()

/// Turf at a block-relative offset. (1, 1) is the reservation's bottom-left corner.
/datum/unit_test/voidcrew_missile_approach/proc/spot(offset_x, offset_y)
	return locate(anchor.x + offset_x - 1, anchor.y + offset_y - 1, anchor.z)

/datum/unit_test/voidcrew_missile_approach/Run()
	TEST_ASSERT(reserved, "Could not reserve a turf block to build the target in")

	var/obj/machinery/ship_combat/mount = allocate(/obj/machinery/ship_combat)

	// The target sits at (8, 8). South and west are hull wall, north is a window,
	// east is a breach down to bare plating.
	var/turf/target = spot(8, 8)
	target.ChangeTurf(/turf/open/floor/plating)
	var/turf/north_edge = spot(8, 9)
	north_edge.ChangeTurf(/turf/open/floor/plating)
	spot(8, 7).ChangeTurf(/turf/closed/wall)
	spot(7, 8).ChangeTurf(/turf/closed/wall)
	var/turf/breach = spot(9, 8)
	breach.ChangeTurf(/turf/open/floor/plating)
	var/obj/structure/window/fulltile/north_window = allocate(/obj/structure/window/fulltile, north_edge)

	// Approaches spawn 3 tiles outside a 5x5 footprint, so every lane is equally long
	// and nothing but the geometry decides between them.
	var/min_x = target.x - 2
	var/max_x = target.x + 2
	var/min_y = target.y - 2
	var/max_y = target.y + 2
	var/turf/north_spawn = locate(target.x, max_y + 3, target.z)
	var/turf/east_spawn = locate(max_x + 3, target.y, target.z)

	var/list/east_path = mount.get_missile_flight_path(east_spawn, target)
	TEST_ASSERT_EQUAL(length(east_path), 5, "A straight flight from 5 tiles out should take 5 steps")
	TEST_ASSERT_EQUAL(east_path[length(east_path)], target, "The flight path does not end on the target")
	TEST_ASSERT_EQUAL(east_path[4], breach, "The flight path does not run straight through the breach")

	TEST_ASSERT(!mount.check_path_clear(north_spawn, target), "A line through a window counted as clear, but the missile detonates on the window")
	TEST_ASSERT(mount.check_path_clear(east_spawn, target), "The open breach did not count as a clear line")
	TEST_ASSERT_EQUAL(mount.find_clear_approach_direction(target, min_x, max_x, min_y, max_y, 3), EAST, "The missile approached through the window instead of the open breach")

	// Grilles stop missiles as well.
	qdel(north_window)
	var/obj/structure/grille/north_grille = allocate(/obj/structure/grille, north_edge)
	TEST_ASSERT(!mount.check_path_clear(north_spawn, target), "A line through a grille counted as clear")
	TEST_ASSERT_EQUAL(mount.find_clear_approach_direction(target, min_x, max_x, min_y, max_y, 3), EAST, "The missile approached through the grille instead of the open breach")
	qdel(north_grille)
	TEST_ASSERT(mount.check_path_clear(north_spawn, target), "An empty doorway did not count as a clear line")

	// Railings only block across their own edge. One running along the flight line
	// is never crossed; one across it is.
	for(var/railing_dir in list(NORTH, SOUTH))
		var/obj/structure/railing/side_rail = allocate(/obj/structure/railing, breach)
		side_rail.setDir(railing_dir)
		TEST_ASSERT(mount.check_path_clear(east_spawn, target), "A railing along the flight line ([dir2text(railing_dir)]-facing) blocked the missile")
		qdel(side_rail)
	for(var/railing_dir in list(EAST, WEST))
		var/obj/structure/railing/cross_rail = allocate(/obj/structure/railing, breach)
		cross_rail.setDir(railing_dir)
		TEST_ASSERT(!mount.check_path_clear(east_spawn, target), "A railing across the flight line ([dir2text(railing_dir)]-facing) did not block the missile")
		qdel(cross_rail)

	// A railing on the target tile's own edge is crossed on the way in, but the missile
	// bumps it while entering the target tile and detonates there anyway.
	var/obj/structure/railing/target_rail = allocate(/obj/structure/railing, target)
	target_rail.setDir(EAST)
	TEST_ASSERT(mount.check_path_clear(east_spawn, target), "A railing on the target tile stopped the line short of the target")
	qdel(target_rail)

	// Directional windows follow the same edge rule.
	var/obj/structure/window/side_pane = allocate(/obj/structure/window, breach, NORTH)
	TEST_ASSERT(mount.check_path_clear(east_spawn, target), "A directional window along the flight line blocked the missile")
	qdel(side_pane)
	var/obj/structure/window/cross_pane = allocate(/obj/structure/window, breach, WEST)
	TEST_ASSERT(!mount.check_path_clear(east_spawn, target), "A directional window across the flight line did not block the missile")
	qdel(cross_pane)

	// Missiles fly through each other, but a raised shield stops them.
	allocate(/obj/effect/ship_missile, spot(10, 8))
	TEST_ASSERT(mount.check_path_clear(east_spawn, target), "Another missile in flight blocked the line")
	var/obj/structure/ship_shield_wall/shield = allocate(/obj/structure/ship_shield_wall, breach)
	TEST_ASSERT(!mount.check_path_clear(east_spawn, target), "A line through a raised shield counted as clear to the target")
	qdel(shield)
