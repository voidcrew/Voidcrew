/**
 * Standard hangar berths are built to the docking ship's size.
 *
 * Checks the sizing formula, then allocates real berths for a small, a largest and a
 * turned hull, several at once, and docks every purchasable class into one. Each berth
 * must be exactly the formula's size, fit the dock to the hull, leave clear deck round the
 * pad, reach the elevator, and hand its turfs back when released. A player outpost builds its
 * berths in the berth zones on its own level (outpost_level_layout.dm) and never reserves
 * turfs; a trader outpost keeps reserving them, and is checked too.
 *
 * Fork defines are included after the tests, so sizes are written out here:
 * 56x40 is RESERVE_DOCK_MAX_SIZE_LONG x RESERVE_DOCK_MAX_SIZE_SHORT; a berth zone is 66x59,
 * four to a claim (OUTPOST_BERTH_ZONE_WIDTH/HEIGHT, OUTPOST_LEVEL_BERTHS).
 */
/datum/unit_test/voidcrew_outpost_sized_berths
	var/list/obj/structure/overmap/ship/test_ships = list()
	/// Bare mobile ports standing in for hulls; docking ports only delete when forced.
	var/list/obj/docking_port/mobile/fake_ports = list()

/datum/unit_test/voidcrew_outpost_sized_berths/Destroy()
	for(var/obj/docking_port/mobile/voidcrew/port as anything in fake_ports)
		if(QDELETED(port))
			continue
		if(port.current_ship)
			port.current_ship.shuttle = null
		port.current_ship = null
		qdel(port, force = TRUE)
	fake_ports.Cut()
	for(var/obj/structure/overmap/ship/ship as anything in test_ships)
		if(!QDELETED(ship))
			qdel(ship)
	test_ships.Cut()
	return ..()

/datum/unit_test/voidcrew_outpost_sized_berths/Run()
	test_layout_formula()

	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "sizedberthowner"
	TEST_ASSERT(home.load_level(), "Could not load the berth test outpost")
	TEST_ASSERT(home.has_hangar_elevator(), "The berth test outpost has no hangar elevator")

	// Small, largest and turned hulls, covering all four ways the dock can face.
	var/list/reservations_before = SSmapping.turf_reservations?.Copy() || list()
	var/list/fake_facings = list()
	fake_facings |= check_fake_berth(home, 5, 7, NORTH, "small, faces west")
	fake_facings |= check_fake_berth(home, 7, 5, NORTH, "small, faces south")
	fake_facings |= check_fake_berth(home, 7, 5, SOUTH, "small, faces north")
	fake_facings |= check_fake_berth(home, 5, 7, SOUTH, "small, faces east")
	fake_facings |= check_fake_berth(home, 56, 40, NORTH, "largest")
	fake_facings |= check_fake_berth(home, 40, 56, EAST, "largest, port on its side")
	fake_facings |= check_fake_berth(home, 9, 21, EAST, "port on its side")
	for(var/facing in GLOB.cardinals)
		TEST_ASSERT("[facing]" in fake_facings, "No test hull faced [dir2text(facing)] in its berth")
	TEST_ASSERT_NULL(home.allocate_berth(fake_ship(57, 20, NORTH)), "A hull longer than any berth was given one")
	check_several_berths(home)
	var/list/new_reservations = (SSmapping.turf_reservations || list()) - reservations_before
	TEST_ASSERT(!length(new_reservations), "Berthing at a player outpost reserved [length(new_reservations)] turf block\s")

	// Trader outposts still build their berths in turf reservations.
	var/obj/structure/overmap/trader_outpost/market = allocate(/obj/structure/overmap/trader_outpost/general)
	check_fake_berth(market, 5, 7, NORTH, "trader, small")
	check_fake_berth(market, 56, 40, NORTH, "trader, largest")

	var/list/facings = list()
	for(var/label in SSmapping.ship_purchase_list)
		var/template_type = SSmapping.ship_purchase_list[label]
		var/datum/map_template/shuttle/voidcrew/template_path = template_type
		if(initial(template_path.abstract) == template_type || ispath(template_type, /datum/map_template/shuttle/voidcrew/commissioned))
			continue
		var/facing = dock_real_ship(home, template_type, redock = !length(facings))
		if(facing)
			facings["[template_type]"] = dir2text(facing)
	TEST_ASSERT(length(facings), "No purchasable ship docked in a standard berth")
	var/list/report = list()
	for(var/template_type in facings)
		report += "[template_type]: [facings[template_type]]"
	log_test("Standard berth facings:\n[report.Join("\n")]")

	check_host_deletion()

/// The numbers the berth is built from. Margin 4 is OUTPOST_BERTH_MARGIN; the strip is 15x11.
/datum/unit_test/voidcrew_outpost_sized_berths/proc/test_layout_formula()
	var/datum/map_template/outpost_berth_strip/strip = get_outpost_berth_strip()
	TEST_ASSERT_EQUAL(strip.width, 15, "The exit strip changed width; update the expected sizes")
	TEST_ASSERT_EQUAL(strip.height, 11, "The exit strip changed height; update the expected sizes")

	var/datum/outpost_berth_layout/small = new(3, 3, 15, 11)
	TEST_ASSERT_EQUAL(small.margin, 4, "The berth margin changed; update the expected sizes")
	TEST_ASSERT_EQUAL(small.width, 15, "A tiny berth is narrower than its exit strip")
	TEST_ASSERT_EQUAL(small.height, 11 + 3 + 8, "Tiny berth height")
	TEST_ASSERT_EQUAL(small.pad_x, 7, "A tiny pad is not centred in a strip-wide berth")
	TEST_ASSERT_EQUAL(small.pad_y, 15, "The pad does not sit a margin above the south walkway")
	TEST_ASSERT_EQUAL(small.strip_x, 1, "The strip is not centred")

	var/datum/outpost_berth_layout/snug = new(7, 9, 15, 11)
	TEST_ASSERT_EQUAL(snug.width, 7 + 10, "Pad plus margins and walls")
	TEST_ASSERT_EQUAL(snug.height, 11 + 9 + 8, "Strip plus pad plus margins")
	TEST_ASSERT_EQUAL(snug.pad_x, 6, "Pad x with no extra width")
	TEST_ASSERT_EQUAL(snug.strip_x, 2, "Strip x in a wider berth")

	var/datum/outpost_berth_layout/largest = new(56, 40, 15, 11)
	TEST_ASSERT_EQUAL(largest.width, 66, "Largest berth width")
	TEST_ASSERT_EQUAL(largest.height, 59, "Largest berth height")
	var/datum/outpost_berth_layout/turned = new(40, 56, 15, 11)
	TEST_ASSERT_EQUAL(turned.width, 50, "Largest turned berth width")
	TEST_ASSERT_EQUAL(turned.height, 75, "Largest turned berth height")
	TEST_ASSERT(SSmapping.reservation_can_ever_fit(largest.width, largest.height), "The largest berth exceeds the reservation ceiling")
	TEST_ASSERT(SSmapping.reservation_can_ever_fit(turned.width, turned.height), "The largest turned berth exceeds the reservation ceiling")

	// The pad is the ground the hull covers after the dock turns it.
	var/obj/docking_port/mobile/voidcrew/sideways = new(run_loc_floor_bottom_left)
	fake_ports += sideways
	sideways.width = 9
	sideways.height = 21
	sideways.port_direction = EAST
	var/list/ground = outpost_berth_pad_size(sideways)
	var/facing = reserve_dock_facing_for(sideways)
	if(facing & (NORTH|SOUTH))
		TEST_ASSERT(ground[1] == 9 && ground[2] == 21, "Pad size does not follow a north or south facing hull")
	else
		TEST_ASSERT(ground[1] == 21 && ground[2] == 9, "Pad size does not follow an east or west facing hull")
	// Every generated path must exist; a DMM load silently drops unknown ones.
	var/datum/parsed_map/generated = new(outpost_berth_map_text(largest, strip))
	var/datum/map_report/report = generated.check_for_errors()
	if(report)
		TEST_FAIL("Generated berth map has errors: bad paths [jointext(report.bad_paths, ", ")], bad keys [jointext(report.bad_keys, ", ")]")
		qdel(report)
	var/list/fallback = outpost_berth_pad_size(null)
	TEST_ASSERT(fallback[1] == 56 && fallback[2] == 40, "A berth without a shuttle did not get the largest pad")

/// A ship record with a bare mobile port of the given size; nothing is placed in the world.
/datum/unit_test/voidcrew_outpost_sized_berths/proc/fake_ship(width, height, port_direction)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/obj/docking_port/mobile/voidcrew/port = new(run_loc_floor_bottom_left)
	fake_ports += port
	port.current_ship = ship
	port.width = width
	port.height = height
	port.dwidth = round(width / 2)
	port.dheight = 0
	port.port_direction = port_direction
	ship.shuttle = port
	return ship

/datum/unit_test/voidcrew_outpost_sized_berths/proc/check_fake_berth(obj/structure/overmap/home, width, height, port_direction, label)
	var/obj/structure/overmap/ship/ship = fake_ship(width, height, port_direction)
	var/datum/outpost_berth/berth = home.allocate_berth(ship)
	TEST_ASSERT_NOTNULL(berth, "No berth for the [label] hull")
	var/datum/outpost_berth_layout/layout = check_berth_layout(berth, ship.shuttle, label)
	check_zone_placement(berth, label)
	check_dock_fit(berth, ship.shuttle, layout, label)
	check_elevator_reachable(berth, layout, null, label)
	. = "[berth.dock.dir]"
	release_and_check(berth, label)

/**
 * A player outpost's berth is built along the south edge of its own berth zone, centred, holds
 * no reservation, and its dock is kept inside the hangar when dragged. A trader berth has no zone.
 */
/datum/unit_test/voidcrew_outpost_sized_berths/proc/check_zone_placement(datum/outpost_berth/berth, label)
	if(!istype(berth.outpost, /obj/structure/overmap/dynamic/player_outpost))
		TEST_ASSERT_NULL(berth.zone, "[label]: a trader berth took a level zone")
		TEST_ASSERT(!QDELETED(berth.reservation), "[label]: a trader berth holds no reservation")
		return
	var/obj/structure/overmap/dynamic/player_outpost/home = berth.outpost
	var/datum/outpost_zone/zone = berth.zone
	TEST_ASSERT_NOTNULL(zone, "[label]: the berth has no zone")
	TEST_ASSERT_NULL(berth.reservation, "[label]: the berth holds a turf reservation")
	TEST_ASSERT_EQUAL(zone, home.berth_zone(berth.berth_number), "[label]: berth [berth.berth_number] is not in its own zone")
	TEST_ASSERT_EQUAL(zone.state, "in use", "[label]: the zone is [zone.state], not in use")
	TEST_ASSERT(zone.is_held_by(berth), "[label]: the zone is held by something else")
	var/turf/low = berth.get_bottom_left()
	var/turf/high = berth.get_top_right()
	TEST_ASSERT(zone.contains_turf(low) && zone.contains_turf(high), "[label]: the hangar spills out of its zone")
	TEST_ASSERT_EQUAL(low.y, zone.low_y, "[label]: the hangar does not stand on the zone's south edge")
	var/west_gap = low.x - zone.low_x
	var/east_gap = zone.high_x - high.x
	TEST_ASSERT(abs(west_gap - east_gap) <= 1, "[label]: the hangar is not centred in its zone ([west_gap] west, [east_gap] east)")
	TEST_ASSERT_EQUAL(low.z, home.upgrade_level_z(), "[label]: the berth is not on the outpost's level")
	TEST_ASSERT_EQUAL(berth.dock.site_rect?.Join(","), "[low.x],[low.y],[high.x],[high.y]", "[label]: the dock does not keep to its hangar")
	// A dock dragged off with a hull is pulled back inside the hangar, not the whole outpost.
	var/turf/home_turf = get_turf(berth.dock)
	berth.dock.forceMove(locate(low.x + 1, max(1, low.y - 20), low.z))
	clamp_reserve_dock_to_site(berth.dock)
	var/list/coords = berth.dock.return_coords()
	TEST_ASSERT(min(coords[1], coords[3]) >= low.x && max(coords[1], coords[3]) <= high.x && min(coords[2], coords[4]) >= low.y && max(coords[2], coords[4]) <= high.y, \
		"[label]: a dragged dock was not clamped back into its hangar")
	berth.dock.forceMove(home_turf)
	berth.dock.dwidth = 0
	berth.dock.dheight = 0

/// Checks size, pad, walls, area, fixtures and signs. Returns the layout it expected.
/datum/unit_test/voidcrew_outpost_sized_berths/proc/check_berth_layout(datum/outpost_berth/berth, obj/docking_port/mobile/shuttle, label)
	var/list/pad_size = outpost_berth_pad_size(shuttle)
	var/datum/outpost_berth_layout/layout = new(pad_size[1], pad_size[2], 15, 11)
	TEST_ASSERT_EQUAL(berth.get_width(), layout.width, "[label]: berth width does not match the formula")
	TEST_ASSERT_EQUAL(berth.get_height(), layout.height, "[label]: berth height does not match the formula")
	TEST_ASSERT_EQUAL(berth.pad_width, pad_size[1], "[label]: pad width")
	TEST_ASSERT_EQUAL(berth.pad_height, pad_size[2], "[label]: pad height")
	TEST_ASSERT_EQUAL(get_turf(berth.dock), local(berth, layout.pad_x, layout.pad_y), "[label]: the dock is not on the pad's corner")
	TEST_ASSERT_EQUAL(length(berth.alcove_turfs), 9, "[label]: the elevator alcove is incomplete")
	TEST_ASSERT_NOTNULL(berth.panel, "[label]: no elevator panel")
	TEST_ASSERT(length(berth.status_signs) >= 1, "[label]: no berth display")
	TEST_ASSERT_EQUAL(berth.outpost.get_floor_alcove(berth.berth_number), berth.alcove_turfs, "[label]: the elevator cannot reach the berth")
	// TRAIT_OUTPOST_PROPERTY; fork defines follow the tests.
	TEST_ASSERT(HAS_TRAIT(berth.panel, "outpost_property"), "[label]: the elevator panel is not outpost property")

	var/area/hangar_area = get_area(berth.alcove_turfs[1])
	TEST_ASSERT(istype(hangar_area, /area/voidcrew/outpost_hangar/berth), "[label]: the berth is not a standard berth area")
	var/pad_right = layout.pad_x + layout.pad_width - 1
	var/pad_top = layout.pad_y + layout.pad_height - 1
	var/south_wall = layout.south_wall_y()
	for(var/local_x in 1 to layout.width)
		for(var/local_y in south_wall to layout.height)
			var/turf/tile = local(berth, local_x, local_y)
			TEST_ASSERT_EQUAL(get_area(tile), hangar_area, "[label]: ([local_x],[local_y]) is outside the berth's one area")
			var/border = local_x == 1 || local_x == layout.width || local_y == south_wall || local_y == layout.height
			var/on_pad = local_x >= layout.pad_x && local_x <= pad_right && local_y >= layout.pad_y && local_y <= pad_top
			if(on_pad)
				TEST_ASSERT(!tile.density, "[label]: pad tile ([local_x],[local_y]) is solid")
				for(var/atom/movable/thing as anything in tile)
					if(!istype(thing, /obj/effect/turf_decal) && !istype(thing, /obj/docking_port))
						TEST_FAIL("[label]: [thing.type] stands on the landing pad at ([local_x],[local_y])")
			else if(!border)
				TEST_ASSERT(!tile.density, "[label]: margin tile ([local_x],[local_y]) is solid")
			else if(local_y != south_wall || !(local_x >= layout.strip_x + 4 && local_x <= layout.strip_x + 10))
				TEST_ASSERT(tile.density, "[label]: hangar wall tile ([local_x],[local_y]) is open")
			for(var/obj/machinery/status_display/outpost_sign/sign in tile)
				if(!istype(sign, /obj/machinery/status_display/outpost_sign/elevator))
					TEST_FAIL("[label]: a wayfinding sign was left in a standard berth")
	var/doors = 0
	for(var/turf/tile as anything in berth.get_block())
		// Hosts find a berth's occupants by its area, so no tile may be left as open space.
		var/area/tile_area = get_area(tile)
		if(tile_area != hangar_area)
			TEST_FAIL("[label]: ([tile.x],[tile.y]) on the berth's ground is [tile_area?.type], not the berth's area")
		for(var/obj/machinery/door/airlock/outpost/door in tile)
			doors++
			TEST_ASSERT_EQUAL(door.outpost, berth.outpost, "[label]: an exit airlock is not linked to the outpost")
	TEST_ASSERT_EQUAL(doors, 2, "[label]: the exit strip's airlocks are missing")
	return layout

/// Turf at a berth-local coordinate; (1, 1) is the loaded hangar's bottom-left corner.
/datum/unit_test/voidcrew_outpost_sized_berths/proc/local(datum/outpost_berth/berth, local_x, local_y)
	var/turf/origin = berth.hangar_bottom_left
	return locate(origin.x + local_x - 1, origin.y + local_y - 1, origin.z)

/// The turned dock and the hull it will carry must cover the pad exactly.
/datum/unit_test/voidcrew_outpost_sized_berths/proc/check_dock_fit(datum/outpost_berth/berth, obj/docking_port/mobile/shuttle, datum/outpost_berth_layout/layout, label)
	adjust_reserve_dock_to_shuttle(berth.dock, shuttle)
	TEST_ASSERT_EQUAL(berth.dock.dir, reserve_dock_facing_for(shuttle), "[label]: the dock faces a different way than the pad was sized for")
	TEST_ASSERT(shuttle.width <= berth.dock.width && shuttle.height <= berth.dock.height, "[label]: the hull does not fit its own berth")
	var/turf/pad_low = local(berth, layout.pad_x, layout.pad_y)
	var/turf/pad_high = local(berth, layout.pad_x + layout.pad_width - 1, layout.pad_y + layout.pad_height - 1)
	var/expected = "[pad_low.x],[pad_low.y],[pad_high.x],[pad_high.y]"
	TEST_ASSERT_EQUAL(normalise_rect(berth.dock.return_coords()), expected, "[label]: the dock does not cover the pad")
	var/hull_rect = normalise_rect(shuttle.return_coords(berth.dock.x, berth.dock.y, berth.dock.dir))
	TEST_ASSERT_EQUAL(hull_rect, expected, "[label]: the docked hull would not cover the pad exactly")

/// "low x,low y,high x,high y" for a return_coords() list, whichever way it is turned.
/datum/unit_test/voidcrew_outpost_sized_berths/proc/normalise_rect(list/coords)
	return "[min(coords[1], coords[3])],[min(coords[2], coords[4])],[max(coords[1], coords[3])],[max(coords[2], coords[4])]"

/**
 * Walks from the deck on each side of the pad to the elevator alcove, through the strip's
 * airlocks. A docked hull blocks its own tiles, so every side must lead round it.
 */
/datum/unit_test/voidcrew_outpost_sized_berths/proc/check_elevator_reachable(datum/outpost_berth/berth, datum/outpost_berth_layout/layout, obj/docking_port/mobile/docked, label)
	var/list/blocked = list()
	if(docked)
		for(var/turf/hull as anything in docked.return_turfs())
			if(docked.shuttle_areas[get_area(hull)])
				blocked[hull] = TRUE
	var/mid_x = layout.pad_x + round(layout.pad_width / 2)
	var/mid_y = layout.pad_y + round(layout.pad_height / 2)
	var/list/starts = list(
		"north" = local(berth, mid_x, layout.pad_y + layout.pad_height),
		"south" = local(berth, mid_x, layout.pad_y - 1),
		"west" = local(berth, layout.pad_x - 1, mid_y),
		"east" = local(berth, layout.pad_x + layout.pad_width, mid_y),
	)
	var/list/alcove = list()
	for(var/turf/alcove_turf as anything in berth.alcove_turfs)
		alcove[alcove_turf] = TRUE
	for(var/side in starts)
		var/turf/start = starts[side]
		var/list/seen = list()
		seen[start] = TRUE
		var/list/queue = list(start)
		var/reached = FALSE
		while(length(queue) && !reached)
			var/turf/current = queue[1]
			queue.Cut(1, 2)
			if(alcove[current])
				reached = TRUE
				break
			for(var/step_dir in GLOB.cardinals)
				var/turf/next = get_step(current, step_dir)
				if(!next || seen[next] || blocked[next] || !berth.contains_turf(next) || !walkable(next))
					continue
				seen[next] = TRUE
				queue += next
		TEST_ASSERT(reached, "[label]: the elevator cannot be reached on foot from the [side] side of the pad")

/// Open floor with nothing solid on it except the hangar's own airlocks.
/datum/unit_test/voidcrew_outpost_sized_berths/proc/walkable(turf/tile)
	if(tile.density)
		return FALSE
	for(var/atom/movable/thing as anything in tile)
		if(thing.density && !istype(thing, /obj/machinery/door/airlock/outpost))
			return FALSE
	return TRUE

/datum/unit_test/voidcrew_outpost_sized_berths/proc/release_and_check(datum/outpost_berth/berth, label)
	if(berth.zone)
		release_and_check_zone(berth, label)
		return
	var/datum/turf_reservation/reservation = berth.reservation
	var/turf/low = berth.get_bottom_left()
	var/turf/high = berth.get_top_right()
	var/obj/structure/overmap/host = berth.outpost
	var/slot = berth.berth_number
	berth.release()
	TEST_ASSERT(QDELETED(berth), "[label]: an empty berth was not released")
	TEST_ASSERT(QDELETED(reservation), "[label]: the berth's reservation was kept")
	TEST_ASSERT_NULL(LAZYACCESS(host.berths, slot), "[label]: the elevator still offers a released berth")
	TEST_ASSERT_NULL(SSmapping.used_turfs[low], "[label]: the berth's bottom-left turf is still claimed")
	TEST_ASSERT_NULL(SSmapping.used_turfs[high], "[label]: the berth's top-right turf is still claimed")
	var/timeout = world.time + 60 SECONDS
	while(world.time < timeout && !((low.turf_flags & UNUSED_RESERVATION_TURF) && (high.turf_flags & UNUSED_RESERVATION_TURF)))
		sleep(world.tick_lag)
	TEST_ASSERT(low.turf_flags & UNUSED_RESERVATION_TURF, "[label]: the berth's turfs never returned to the free pool")
	TEST_ASSERT(high.turf_flags & UNUSED_RESERVATION_TURF, "[label]: the berth's far corner never returned to the free pool")

/// A released zoned berth wipes its zone back to vacant space, then the zone can be used again.
/datum/unit_test/voidcrew_outpost_sized_berths/proc/release_and_check_zone(datum/outpost_berth/berth, label)
	var/datum/outpost_zone/zone = berth.zone
	var/obj/structure/overmap/host = berth.outpost
	var/slot = berth.berth_number
	berth.release()
	TEST_ASSERT(QDELETED(berth), "[label]: an empty berth was not released")
	TEST_ASSERT_NULL(LAZYACCESS(host.berths, slot), "[label]: the elevator still offers a released berth")
	TEST_ASSERT(zone.state == "wiping" || zone.state == "vacant", "[label]: the released zone is [zone.state]")
	wait_for_vacant(zone, label)
	check_zone_clean(zone, label)

/// Waits (bounded) for a zone's wipe to finish.
/datum/unit_test/voidcrew_outpost_sized_berths/proc/wait_for_vacant(datum/outpost_zone/zone, label)
	var/timeout = world.time + 60 SECONDS
	while(world.time < timeout && !zone.is_vacant())
		sleep(world.tick_lag)
	TEST_ASSERT(zone.is_vacant(), "[label]: the zone was never wiped back to vacant")

/// Every tile of a vacant zone is bare space in the vacant area with nothing left on it.
/datum/unit_test/voidcrew_outpost_sized_berths/proc/check_zone_clean(datum/outpost_zone/zone, label)
	var/problem = outpost_zone_leftovers(zone)
	TEST_ASSERT_NULL(problem, "[label]: the wiped zone is not bare: [problem]")

/// Three berths of different sizes at once: separate ground, separate floors, all released.
/datum/unit_test/voidcrew_outpost_sized_berths/proc/check_several_berths(obj/structure/overmap/dynamic/player_outpost/home)
	var/list/datum/outpost_berth/held = list()
	held += home.allocate_berth(fake_ship(6, 8, NORTH))
	held += home.allocate_berth(fake_ship(30, 44, WEST))
	held += home.allocate_berth(fake_ship(12, 12, SOUTH))
	for(var/i in 1 to length(held))
		var/datum/outpost_berth/berth = held[i]
		TEST_ASSERT_NOTNULL(berth, "Concurrent berth [i] was not allocated")
		TEST_ASSERT_EQUAL(berth.berth_number, i, "Concurrent berths took the wrong elevator floors")
		for(var/j in i + 1 to length(held))
			var/datum/outpost_berth/other = held[j]
			for(var/turf/corner as anything in list(other.get_bottom_left(), other.get_top_right()))
				TEST_ASSERT(!berth.contains_turf(corner), "Berths [i] and [j] share ground")
	for(var/datum/outpost_berth/berth as anything in held)
		release_and_check(berth, "concurrent berth")

/**
 * Docks one purchasable class into a standard berth for real, walks round it to the
 * elevator, checks the hull cannot claim the berth's deck, then undocks it and checks
 * the berth is torn down only after the hull has left. Returns the dock's facing.
 */
/datum/unit_test/voidcrew_outpost_sized_berths/proc/dock_real_ship(obj/structure/overmap/dynamic/player_outpost/home, template_type, redock = FALSE)
	var/obj/structure/overmap/ship/ship = SSshuttle.create_ship(template_type)
	if(!ship)
		TEST_FAIL("[template_type] could not be spawned")
		return null
	test_ships += ship
	var/label = "[template_type]"
	. = null
	for(var/visit in 1 to (redock ? 2 : 1))
		var/datum/outpost_berth/berth = home.allocate_berth(ship)
		if(!berth)
			TEST_FAIL("[label]: no standard berth could take it")
			break
		var/datum/outpost_berth_layout/layout = check_berth_layout(berth, ship.shuttle, label)
		adjust_reserve_dock_to_shuttle(berth.dock, ship.shuttle)
		ship.shuttle.mode = SHUTTLE_PREARRIVAL
		var/docked = ship.shuttle.initiate_docking(berth.dock)
		ship.shuttle.mode = SHUTTLE_IDLE
		if(docked != DOCKING_SUCCESS)
			TEST_FAIL("[label]: does not fit its own berth ([docked])")
			berth.release(force = TRUE)
			break
		ship.docked = home
		ship.forceMove(home)
		ship.state = "idle"
		berth.on_ship_docked(ship)
		TEST_ASSERT(berth.arrived, "[label]: the berth did not register the arrival")
		. = berth.dock.dir

		var/turf/pad_low = local(berth, layout.pad_x, layout.pad_y)
		var/turf/pad_high = local(berth, layout.pad_x + layout.pad_width - 1, layout.pad_y + layout.pad_height - 1)
		for(var/turf/hull as anything in ship.shuttle.return_turfs())
			if(!ship.shuttle.shuttle_areas[get_area(hull)])
				continue
			if(hull.x < pad_low.x || hull.x > pad_high.x || hull.y < pad_low.y || hull.y > pad_high.y)
				TEST_FAIL("[label]: hull tile ([hull.x],[hull.y]) landed off the pad")
		check_elevator_reachable(berth, layout, ship.shuttle, label)
		// Construction refuses hull growth by this area type; the ship bay uses the parent type.
		var/turf/beside = local(berth, layout.pad_x - 1, layout.pad_y)
		TEST_ASSERT(istype(get_area(beside), /area/voidcrew/outpost_hangar/berth), "[label]: the deck beside the pad is not standard berth deck")

		// Leave for transit; the berth may only go once the hull is off it.
		var/datum/turf_reservation/reservation = berth.reservation
		var/datum/outpost_zone/zone = berth.zone
		var/obj/docking_port/stationary/transit/transit = ship.shuttle.assigned_transit
		if(QDELETED(transit))
			transit = SSshuttle.generate_transit_dock(ship.shuttle)
		ship.shuttle.mode = SHUTTLE_PREARRIVAL
		var/left = ship.shuttle.initiate_docking(transit)
		ship.shuttle.mode = SHUTTLE_IDLE
		TEST_ASSERT_EQUAL(left, DOCKING_SUCCESS, "[label]: could not leave its berth")
		ship.docked = null
		ship.forceMove(get_turf(home))
		ship.state = "flying"
		var/hull_tiles_before = count_hull_tiles(ship.shuttle)
		home.on_ship_undock_complete(ship)
		TEST_ASSERT(QDELETED(berth) && QDELETED(reservation), "[label]: the berth outlived the departed ship")
		if(zone)
			wait_for_vacant(zone, label)
			check_zone_clean(zone, label)
		TEST_ASSERT_EQUAL(count_hull_tiles(ship.shuttle), hull_tiles_before, "[label]: berth teardown touched the departed hull")
	ship.shuttle?.admin_delete_shuttle()

/datum/unit_test/voidcrew_outpost_sized_berths/proc/count_hull_tiles(obj/docking_port/mobile/port)
	. = 0
	for(var/turf/tile as anything in port.return_turfs())
		if(port.shuttle_areas[get_area(tile)] && !isspaceturf(tile))
			.++

/// Deleting the host frees every berth it holds, and the berths' zones go with its level.
/datum/unit_test/voidcrew_outpost_sized_berths/proc/check_host_deletion()
	var/obj/structure/overmap/dynamic/player_outpost/doomed = new
	doomed.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	TEST_ASSERT(doomed.load_level(), "Could not load the deletion test outpost")
	var/level_z = doomed.upgrade_level_z()
	var/list/datum/outpost_berth/held = list()
	var/list/datum/outpost_zone/zones = list()
	for(var/size in list(5, 20))
		var/datum/outpost_berth/berth = doomed.allocate_berth(fake_ship(size, size + 4, NORTH))
		TEST_ASSERT_NOTNULL(berth, "No berth at the outpost being deleted")
		TEST_ASSERT_NULL(berth.reservation, "A berth at the outpost being deleted holds a reservation")
		held += berth
		zones += berth.zone
	var/datum/outpost_berth/first_berth = held[1]
	var/turf/berth_corner = first_berth.get_bottom_left()
	qdel(doomed)
	for(var/datum/outpost_berth/berth as anything in held)
		TEST_ASSERT(QDELETED(berth), "Deleting the outpost left berth [berth.berth_number] behind")
	for(var/datum/outpost_zone/zone as anything in zones)
		TEST_ASSERT(QDELETED(zone), "Deleting the outpost left its [zone.key] zone behind")
	// The level goes back to the pool as bare space: no berth walls, no vacant area. The level
	// teardown yields, so give it a moment.
	var/timeout = world.time + 30 SECONDS
	while(world.time < timeout && !(isspaceturf(berth_corner) && istype(get_area(berth_corner), /area/space)))
		sleep(world.tick_lag)
	TEST_ASSERT(isspaceturf(berth_corner) && istype(get_area(berth_corner), /area/space), "Deleting the outpost left a berth standing on z[level_z]")

/**
 * The berth ground procs agree with what holds the ground: the reservation for a trader outpost
 * berth, the hangar loaded into its zone for a player outpost berth and ship bay. The corners,
 * the size, the block, and which tiles are on it. Given-back ground reads as none.
 */
/datum/unit_test/voidcrew_outpost_berth_ground

/datum/unit_test/voidcrew_outpost_berth_ground/Run()
	var/obj/structure/overmap/trader_outpost/market = allocate(/obj/structure/overmap/trader_outpost/general)
	var/datum/outpost_berth/trader_berth = market.allocate_berth(allocate(/obj/structure/overmap/ship))
	TEST_ASSERT_NOTNULL(trader_berth, "The trader outpost gave no berth")
	check_ground(trader_berth, "trader berth")
	var/turf/trader_corner = trader_berth.get_top_right()
	TEST_ASSERT_EQUAL(get_trader_outpost_for_turf(trader_corner), market, "The trader berth is not under its outpost's protection")
	TEST_ASSERT(get_trader_outpost_for_turf(get_step(trader_corner, NORTHEAST)) != market, "Trader protection reached past the berth")
	TEST_ASSERT(market.contains_site_turf(trader_corner), "The trader berth is not part of its outpost")

	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "berthgroundowner"
	TEST_ASSERT(home.load_level(), "Could not load the berth ground test outpost")
	var/datum/outpost_berth/home_berth = home.allocate_berth(allocate(/obj/structure/overmap/ship))
	TEST_ASSERT_NOTNULL(home_berth, "The player outpost gave no berth")
	check_zone_ground(home_berth, "player outpost berth")
	var/turf/home_corner = home_berth.get_bottom_left()
	TEST_ASSERT(home.contains_service_turf(home_corner), "The player outpost berth is not outpost service ground")
	TEST_ASSERT(home.contains_site_turf(home_corner), "The player outpost berth is not part of its outpost")
	TEST_ASSERT(!home.contains_service_turf(get_step(home_corner, SOUTHWEST)), "Outpost service ground reached past the berth")

	TEST_ASSERT_NULL(home.enable_ship_bays(), "The ship bay did not load")
	var/datum/outpost_berth/ship_bay/bay = LAZYACCESS(home.bay_berths, 1)
	TEST_ASSERT_NOTNULL(bay, "The player outpost has no ship bay")
	check_zone_ground(bay, "ship bay")
	var/turf/bay_corner = bay.get_top_right()
	TEST_ASSERT(home.contains_site_turf(bay_corner), "The ship bay is not part of its outpost")
	TEST_ASSERT(checkpoint_yard_noise_at(bay_corner), "The ship bay is not heard as a construction yard")
	TEST_ASSERT(!checkpoint_yard_noise_at(get_step(bay_corner, NORTHEAST)), "The construction yard reached past the ship bay")

	var/turf/released = trader_berth.get_bottom_left()
	trader_berth.release(force = TRUE)
	check_no_ground(trader_berth, released, "released trader berth")
	released = home_berth.get_bottom_left()
	home_berth.release(force = TRUE)
	check_no_ground(home_berth, released, "released player outpost berth")
	released = bay.get_bottom_left()
	qdel(home)
	check_no_ground(bay, released, "ship bay of a deleted outpost")

/// Every ground proc against the reservation it reads: corners, size, block and containment.
/datum/unit_test/voidcrew_outpost_berth_ground/proc/check_ground(datum/outpost_berth/berth, label)
	var/datum/turf_reservation/reservation = berth.reservation
	TEST_ASSERT(!QDELETED(reservation) && length(reservation.bottom_left_turfs) && length(reservation.top_right_turfs), "[label]: holds no reservation")
	TEST_ASSERT(berth.has_ground(), "[label]: reports no ground")
	var/turf/low = reservation.bottom_left_turfs[1]
	var/turf/high = reservation.top_right_turfs[1]
	TEST_ASSERT_EQUAL(berth.get_bottom_left(), low, "[label]: wrong bottom-left corner")
	TEST_ASSERT_EQUAL(berth.get_top_right(), high, "[label]: wrong top-right corner")
	TEST_ASSERT_EQUAL(berth.get_width(), reservation.width, "[label]: wrong width")
	TEST_ASSERT_EQUAL(berth.get_height(), reservation.height, "[label]: wrong height")

	var/list/turf/ground = berth.get_block()
	TEST_ASSERT_EQUAL(length(ground), reservation.width * reservation.height, "[label]: the block is the wrong size")
	TEST_ASSERT_EQUAL(ground[1], low, "[label]: the block does not start at the bottom-left corner")
	TEST_ASSERT_EQUAL(ground[length(ground)], high, "[label]: the block does not end at the top-right corner")
	var/list/on_ground = list()
	for(var/turf/tile as anything in ground)
		on_ground[tile] = TRUE
	for(var/turf/tile as anything in reservation.reserved_turfs)
		if(!on_ground[tile])
			TEST_FAIL("[label]: reserved turf ([tile.x],[tile.y]) is missing from the block")
			break

	// Inside: the four corners and the middle. Outside: a step past each edge and corner, and the
	// same spot on another level.
	var/list/turf/inside = list(
		low,
		high,
		locate(low.x, high.y, low.z),
		locate(high.x, low.y, low.z),
		locate(round((low.x + high.x) / 2), round((low.y + high.y) / 2), low.z),
	)
	var/list/turf/outside = list(
		get_step(low, WEST),
		get_step(low, SOUTH),
		get_step(high, EAST),
		get_step(high, NORTH),
		get_step(low, SOUTHWEST),
		get_step(high, NORTHEAST),
		locate(low.x, low.y, low.z == 1 ? 2 : 1),
	)
	for(var/turf/tile as anything in inside)
		TEST_ASSERT(reservation.contains_turf(tile), "[label]: the reservation does not hold inside tile ([tile.x],[tile.y])")
		TEST_ASSERT(berth.contains_turf(tile), "[label]: inside tile ([tile.x],[tile.y]) is off the berth's ground")
	for(var/turf/tile as anything in outside)
		TEST_ASSERT(!reservation.contains_turf(tile), "[label]: the reservation holds outside tile ([tile.x],[tile.y],[tile.z])")
		TEST_ASSERT(!berth.contains_turf(tile), "[label]: outside tile ([tile.x],[tile.y],[tile.z]) is on the berth's ground")
	TEST_ASSERT(!berth.contains_turf(null), "[label]: nullspace is on the berth's ground")

/// Every ground proc against the hangar a zoned berth loaded: corners, size, block and containment.
/datum/unit_test/voidcrew_outpost_berth_ground/proc/check_zone_ground(datum/outpost_berth/berth, label)
	var/datum/outpost_zone/zone = berth.zone
	TEST_ASSERT_NOTNULL(zone, "[label]: holds no zone")
	TEST_ASSERT_NULL(berth.reservation, "[label]: holds a reservation")
	TEST_ASSERT(berth.has_ground(), "[label]: reports no ground")
	var/turf/low = berth.hangar_bottom_left
	var/turf/high = locate(low.x + berth.hangar_width - 1, low.y + berth.hangar_height - 1, low.z)
	TEST_ASSERT_EQUAL(berth.get_bottom_left(), low, "[label]: wrong bottom-left corner")
	TEST_ASSERT_EQUAL(berth.get_top_right(), high, "[label]: wrong top-right corner")
	TEST_ASSERT_EQUAL(berth.get_width(), berth.hangar_width, "[label]: wrong width")
	TEST_ASSERT_EQUAL(berth.get_height(), berth.hangar_height, "[label]: wrong height")
	TEST_ASSERT(zone.contains_turf(low) && zone.contains_turf(high), "[label]: the ground is not inside its zone")
	var/list/turf/ground = berth.get_block()
	TEST_ASSERT_EQUAL(length(ground), berth.hangar_width * berth.hangar_height, "[label]: the block is the wrong size")
	TEST_ASSERT_EQUAL(ground[1], low, "[label]: the block does not start at the bottom-left corner")
	TEST_ASSERT_EQUAL(ground[length(ground)], high, "[label]: the block does not end at the top-right corner")
	var/list/turf/inside = list(low, high, locate(low.x, high.y, low.z), locate(high.x, low.y, low.z))
	var/list/turf/outside = list(get_step(low, WEST), get_step(high, EAST), get_step(high, NORTH), get_step(high, NORTHEAST), locate(low.x, low.y, low.z == 1 ? 2 : 1))
	for(var/turf/tile as anything in inside)
		TEST_ASSERT(berth.contains_turf(tile), "[label]: inside tile ([tile.x],[tile.y]) is off the berth's ground")
	for(var/turf/tile as anything in outside)
		if(tile)
			TEST_ASSERT(!berth.contains_turf(tile), "[label]: outside tile ([tile.x],[tile.y],[tile.z]) is on the berth's ground")
	TEST_ASSERT(!berth.contains_turf(null), "[label]: nullspace is on the berth's ground")

/datum/unit_test/voidcrew_outpost_berth_ground/proc/check_no_ground(datum/outpost_berth/berth, turf/former_corner, label)
	TEST_ASSERT(QDELETED(berth), "[label]: was not deleted")
	TEST_ASSERT(!berth.has_ground(), "[label]: still reports ground")
	TEST_ASSERT_NULL(berth.get_bottom_left(), "[label]: still has a bottom-left corner")
	TEST_ASSERT_NULL(berth.get_top_right(), "[label]: still has a top-right corner")
	TEST_ASSERT_EQUAL(berth.get_width(), 0, "[label]: still has a width")
	TEST_ASSERT_EQUAL(berth.get_height(), 0, "[label]: still has a height")
	TEST_ASSERT_EQUAL(length(berth.get_block()), 0, "[label]: still has a block")
	TEST_ASSERT(!berth.contains_turf(former_corner), "[label]: still holds its old corner")

/**
 * A player outpost's berth zones churn cleanly: twenty visits of different sizes through the same
 * zone leave it bare, eject whoever stayed behind, reap every berth area and never reserve turfs.
 * A zone still being wiped is passed over, and the elevator offers only the claim's four berths.
 */
/datum/unit_test/voidcrew_outpost_berth_churn
	parent_type = /datum/unit_test/voidcrew_outpost_sized_berths

/datum/unit_test/voidcrew_outpost_berth_churn/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "berthchurnowner"
	TEST_ASSERT(home.load_level(), "Could not load the churn test outpost")
	TEST_ASSERT_EQUAL(home.berth_capacity(), 4, "A claim holds [home.berth_capacity()] berths, not its four zones")
	var/list/reservations_before = SSmapping.turf_reservations?.Copy() || list()
	var/berth_areas_before = count_berth_areas()
	var/datum/outpost_zone/first_zone = home.berth_zone(1)

	var/list/sizes = list(list(5, 7), list(56, 40), list(12, 30), list(40, 56), list(9, 21))
	for(var/visit in 1 to 20)
		var/list/size = sizes[(visit - 1) % length(sizes) + 1]
		var/datum/outpost_berth/berth = home.allocate_berth(fake_ship(size[1], size[2], NORTH))
		TEST_ASSERT_NOTNULL(berth, "Visit [visit]: no berth")
		TEST_ASSERT_EQUAL(berth.zone, first_zone, "Visit [visit]: the berth did not reuse the first zone")
		// Things left behind: loose kit, a stray landmark, and somebody still aboard.
		var/turf/deck = berth.alcove_turfs[1]
		new /obj/item/wrench(deck)
		new /obj/effect/landmark/outpost_berth_dock(get_step(deck, NORTH))
		var/mob/living/carbon/human/straggler = allocate(/mob/living/carbon/human/consistent, get_step(deck, NORTH))
		straggler.mind_initialize()
		release_and_check_zone(berth, "visit [visit]")
		TEST_ASSERT(home.is_turf_buildable(get_turf(straggler)), "Visit [visit]: a visitor left in the berth was not taken to the concourse")
		qdel(straggler)

	TEST_ASSERT_EQUAL(count_berth_areas(), berth_areas_before, "Churn left berth areas behind")
	var/list/new_reservations = (SSmapping.turf_reservations || list()) - reservations_before
	TEST_ASSERT(!length(new_reservations), "Berth churn reserved [length(new_reservations)] turf block\s")

	// A zone still being wiped is skipped rather than loaded over.
	var/datum/outpost_berth/leaving = home.allocate_berth(fake_ship(5, 7, NORTH))
	TEST_ASSERT_NOTNULL(leaving, "No berth for the wipe race")
	leaving.release()
	var/wiping = first_zone.state == "wiping"
	var/datum/outpost_berth/next = home.allocate_berth(fake_ship(5, 7, NORTH))
	TEST_ASSERT_NOTNULL(next, "No berth while another zone was wiping")
	if(wiping)
		TEST_ASSERT(next.zone != first_zone, "A berth was built into a zone that was still being wiped")
	next.release()
	wait_for_vacant(first_zone, "wipe race")
	wait_for_vacant(home.berth_zone(2), "wipe race")

	// The elevator lists the concourse and the claim's four berths.
	var/obj/machinery/outpost_elevator/panel = LAZYACCESS(home.lobby_panels, 1)
	TEST_ASSERT_NOTNULL(panel, "The claim has no lobby elevator panel")
	var/list/panel_data = panel.ui_data(null)
	var/list/floors = panel_data["floors"]
	TEST_ASSERT_EQUAL(length(floors), 5, "The elevator lists [length(floors)] floors, not the concourse and four berths")

/datum/unit_test/voidcrew_outpost_berth_churn/proc/count_berth_areas()
	. = 0
	for(var/area/voidcrew/outpost_hangar/berth/berth_area in GLOB.areas)
		if(!QDELETED(berth_area))
			.++
