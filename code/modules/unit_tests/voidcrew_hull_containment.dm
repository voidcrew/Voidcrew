/**
 * # A hull's rectangle, and its berth's, must stay on their own site
 *
 * Two things were bounded only by "one encounter owns one z-level", and both of them are
 * destructive when that stops being true:
 *
 *  1. `calculate_docking_port_information()` derives a template-less hull's width, height and
 *     offsets from the bounding box of every turf registered to its shuttle areas, filtered by
 *     z-level. A hull that stranded a tile at one site and then docked at another on the SAME
 *     z gets a rectangle spanning both. Every later move then runs the shuttle-move callbacks
 *     over that whole span, and those callbacks destroy rather than refuse: cables are cut and
 *     never reconnected (no MOVE_CONTENTS, so afterShuttleMove never reaches them), airlocks
 *     are force-closed, mobs are gibbed by toShuttleMove(). canDock() never checks containment,
 *     so the neighbour is overwritten silently.
 *
 *  2. `hull_reseat_port()` drags the stationary berth the ship is standing on to the hull's new
 *     port tile so get_docked() still finds it, without recomputing dwidth/dheight - so the
 *     berth's whole 56x40 projected rectangle translates with it, as far as the hull's own
 *     extent. On a level of its own that lands in reservation padding; on a packed level it
 *     lands on the encounter across the gutter, and SSshuttle.get_dock_overlap(), the teardown
 *     hull-overlap guards and the next adjust_reserve_dock_to_shuttle() all then reason about a
 *     rectangle sitting on somebody else's ground.
 *
 * Both are driven here against two REAL co-tenant encounters dealt by the real allocator, so
 * the geometry cannot drift away from what the game actually builds.
 *
 * Literals rather than the MAP_SLOT_* / MAP_TENANT_CLASS_* defines, for the same reason
 * voidcrew_map_packing.dm spells its out: unit tests are included well before
 * voidcrew/_DEFINES in the .dme, so none of them exist yet here.
 */
/datum/unit_test/voidcrew_hull_containment

/datum/unit_test/voidcrew_hull_containment/Run()
	var/list/home_values = SSovermap.spawn_dynamic_encounter(null, FALSE)
	var/list/neighbour_values = SSovermap.spawn_dynamic_encounter(null, FALSE)
	if(length(home_values) < 4 || length(neighbour_values) < 4)
		TEST_FAIL("spawn_dynamic_encounter() did not return a footprint - hull containment cannot be tested")
		release_encounter(home_values)
		release_encounter(neighbour_values)
		return

	var/datum/map_footprint/home = home_values[4]
	var/datum/map_footprint/neighbour = neighbour_values[4]
	if(!home || !neighbour)
		TEST_FAIL("A flat encounter was built without a map footprint")
		release_encounter(home_values)
		release_encounter(neighbour_values)
		return
	if(home.z_value != neighbour.z_value)
		TEST_FAIL("Two flat encounters landed on different z-levels (z[home.z_value] and z[neighbour.z_value]). They are not packing, so nothing here is under test - fix voidcrew_map_packing first.")
		release_encounter(home_values)
		release_encounter(neighbour_values)
		return

	test_stranded_turf_rect(home, neighbour)
	test_berth_drag_clamp(home, home_values[2])

	release_encounter(home_values)
	release_encounter(neighbour_values)

/**
 * A tile stranded in the neighbour's slot must not stretch our rectangle across the gutter.
 *
 * Also covers the per-site occupancy register that replaced the raw ZTRAIT_STATION flip
 * (voidcrew/mapping/docking_port/_docking_port.dm): the hull is counted against the site it is
 * standing on and against no other, and a hull DELETED while parked releases both its site and
 * its z-level claim - the path the old `old_z_level`-gated unlink silently skipped, which left
 * an encounter's whole z flagged for the rest of the round and handed it on flagged.
 */
/datum/unit_test/voidcrew_hull_containment/proc/test_stranded_turf_rect(datum/map_footprint/home, datum/map_footprint/neighbour)
	var/z_value = home.z_value

	// Well clear of the berth band along the bottom of a slot, and well clear of the gutter.
	var/list/hull_turfs = list()
	for(var/offset_x in 0 to 2)
		for(var/offset_y in 0 to 2)
			var/turf/tile = locate(home.low_x + 60 + offset_x, home.low_y + 60 + offset_y, z_value)
			if(tile)
				hull_turfs += tile
	var/turf/stranded = locate(neighbour.low_x + 60, neighbour.low_y + 60, z_value)
	var/turf/port_turf = locate(home.low_x + 61, home.low_y + 61, z_value)
	if(length(hull_turfs) != 9 || !stranded || !port_turf)
		TEST_FAIL("Could not resolve a 3x3 hull patch in [home.describe()] and a stranded turf in [neighbour.describe()]")
		return

	// If the region resolver cannot tell the two slots apart there is nothing for the
	// containment filter to do, and everything below would pass for the wrong reason.
	if(map_region_for_turf(port_turf) != home)
		TEST_FAIL("map_region_for_turf() resolved our own ground to [map_region_for_turf(port_turf) || "nothing"] instead of [home.describe()] - hull containment has nothing to work with")
		return
	if(map_region_for_turf(stranded) != neighbour)
		TEST_FAIL("map_region_for_turf() resolved the neighbour's ground to [map_region_for_turf(stranded) || "nothing"] instead of [neighbour.describe()] - a stranded tile there is indistinguishable from our own")
		return

	var/was_station_level = is_station_level(z_value)

	var/area/shuttle/hull_area = new
	var/list/original_areas = list()
	for(var/turf/tile as anything in (hull_turfs + list(stranded)))
		original_areas[tile] = get_area(tile)
		tile.change_area(original_areas[tile], hull_area)

	// The whole point of the test: the stranded tile really is registered to one of our areas,
	// on our own z-level, exactly as rounds 803/804/811 left them.
	if(!(stranded in hull_area.get_turfs_by_zlevel(z_value)))
		TEST_FAIL("The stranded turf was not registered in the hull's area on z[z_value] - this test is not guarding anything")
		restore_areas(original_areas, hull_area)
		return

	var/obj/docking_port/mobile/voidcrew/port = new(port_turf)
	// Subscript assignment, not list(hull_area = TRUE): a bare identifier on the left of `=`
	// inside a list() literal is read as an argument NAME, so that form registers the string
	// "hull_area" and every consumer runtimes on it. Same note as voidcrew_hull_survey.dm.
	port.shuttle_areas = list()
	port.shuttle_areas[hull_area] = TRUE
	port.calculate_docking_port_information()

	if(port.width != 3 || port.height != 3)
		TEST_FAIL("The hull's computed bounds are [port.width]x[port.height] for a 3x3 hull. The tile stranded in [neighbour.describe()] \
			stretched the extents across the gutter; every later move would scan that whole span and cut, force-close and gib its way \
			through the neighbour's site.")

	var/list/rect = port.return_coords()
	var/rect_low_x = min(rect[1], rect[3])
	var/rect_high_x = max(rect[1], rect[3])
	var/rect_low_y = min(rect[2], rect[4])
	var/rect_high_y = max(rect[2], rect[4])

	if(!home.contains_coords(rect_low_x, rect_low_y, z_value) || !home.contains_coords(rect_high_x, rect_high_y, z_value))
		TEST_FAIL("The hull rectangle ([rect_low_x],[rect_low_y])-([rect_high_x],[rect_high_y]) escapes its own site [home.describe()]")

	var/spans_neighbour = rect_low_x <= neighbour.high_x && neighbour.low_x <= rect_high_x \
		&& rect_low_y <= neighbour.high_y && neighbour.low_y <= rect_high_y
	if(spans_neighbour)
		TEST_FAIL("The hull rectangle ([rect_low_x],[rect_low_y])-([rect_high_x],[rect_high_y]) overlaps the co-tenant at [neighbour.describe()]. \
			Shuttle moves are not refused on containment - this rectangle is what initiate_docking() hands to the destructive move callbacks.")

	// ---- Per-site occupancy: the replacement for the raw z-trait flip --------------------

	if(site_ship_occupancy(home) != 1)
		TEST_FAIL("The site occupancy register counts [site_ship_occupancy(home)] hull(s) on [home.describe()], expected 1 - \
			link_to_z_level() is not registering the hull against the ground it is standing on")
	if(site_ship_occupancy(neighbour))
		TEST_FAIL("The site occupancy register counts [site_ship_occupancy(neighbour)] hull(s) on [neighbour.describe()], which has never seen one. \
			turf_has_ship_presence() would report the neighbour's ground as occupied.")
	if(!turf_has_ship_presence(port_turf))
		TEST_FAIL("turf_has_ship_presence() says no ship is standing on the hull's own tile")
	if(turf_has_ship_presence(stranded))
		TEST_FAIL("turf_has_ship_presence() reports the co-tenant's ground as ship-occupied - it is answering per z-level, not per site")
	if(!is_station_level(z_value))
		TEST_FAIL("A docked hull did not flag its z-level ZTRAIT_STATION - stationloving and everything downstream of it stops working aboard ships")

	// A hull deleted while parked (destroyed, despawned, admin-deleted) has to release
	// everything it holds. This is the path that used to leak: unlink_from_z_level() was gated
	// on a beforeShuttleMove() snapshot, which only a MOVE ever set.
	qdel(port, force = TRUE)

	if(site_ship_occupancy(home))
		TEST_FAIL("[site_ship_occupancy(home)] hull(s) are still counted on [home.describe()] after the only one was deleted - \
			the site would read as occupied for the rest of the round")
	if(!was_station_level && is_station_level(z_value))
		TEST_FAIL("z[z_value] is still ZTRAIT_STATION after the only hull on it was deleted. The freed slot is dealt to the next tenant \
			still flagged, and on a packed level three co-tenants that never saw a ship are flagged with it.")

	restore_areas(original_areas, hull_area)

/**
 * After hull_reseat_port() drags the berth, the berth's rectangle stays inside its own site.
 *
 * The berth is the real one spawn_dynamic_encounter() built, so its size, facing and home
 * coordinates are the game's, not restated ones.
 */
/datum/unit_test/voidcrew_hull_containment/proc/test_berth_drag_clamp(datum/map_footprint/home, obj/docking_port/stationary/berth)
	if(!berth)
		TEST_FAIL("The test encounter was built without a primary reserve berth - the berth drag cannot be tested")
		return
	var/z_value = home.z_value
	var/turf/berth_turf = get_turf(berth)
	if(!berth_turf || berth_turf.z != z_value)
		TEST_FAIL("The reserve berth is not on its own encounter's z-level")
		return

	// The far corner of the slot: the furthest a reseat can legally drag the port, and what a
	// hull built out to the edge of its site actually produces.
	var/turf/reseat_to = locate(home.high_x - 2, home.high_y - 2, z_value)
	if(!reseat_to)
		TEST_FAIL("Could not resolve a reseat target inside [home.describe()]")
		return

	// Where the berth WOULD land if the drag were left uncorrected: same offsets, new tile.
	// If that is inside the slot anyway this test proves nothing, so say so rather than pass.
	var/list/dragged = berth.return_coords(reseat_to.x, reseat_to.y, berth.dir)
	var/dragged_low_x = min(dragged[1], dragged[3])
	var/dragged_high_x = max(dragged[1], dragged[3])
	var/dragged_low_y = min(dragged[2], dragged[4])
	var/dragged_high_y = max(dragged[2], dragged[4])
	var/would_escape = dragged_low_x < home.low_x || dragged_high_x > home.high_x \
		|| dragged_low_y < home.low_y || dragged_high_y > home.high_y
	if(!would_escape)
		TEST_FAIL("A [berth.width]x[berth.height] berth dragged to ([reseat_to.x],[reseat_to.y]) would stay inside [home.describe()] on its own, \
			so this test is not exercising the clamp. Pick a reseat target further from the berth.")

	// A small hull patch around the reseat target: calculate_docking_port_information() runs
	// inside hull_reseat_port() and CRASHes on a port with no area turfs.
	var/list/hull_turfs = list()
	for(var/offset_x in -1 to 1)
		for(var/offset_y in -1 to 1)
			var/turf/tile = locate(reseat_to.x + offset_x, reseat_to.y + offset_y, z_value)
			if(tile)
				hull_turfs += tile
	if(!length(hull_turfs))
		TEST_FAIL("Could not resolve a hull patch around the reseat target")
		return

	var/area/shuttle/hull_area = new
	var/list/original_areas = list()
	for(var/turf/tile as anything in hull_turfs)
		original_areas[tile] = get_area(tile)
		tile.change_area(original_areas[tile], hull_area)

	// Built on the berth's own tile so get_docked() resolves it - that is what makes
	// hull_reseat_port() drag the berth at all.
	var/obj/docking_port/mobile/voidcrew/port = new(berth_turf)
	// Subscript assignment - see the note in test_stranded_turf_rect().
	port.shuttle_areas = list()
	port.shuttle_areas[hull_area] = TRUE

	hull_reseat_port(port, reseat_to)

	if(get_turf(berth) != reseat_to)
		TEST_FAIL("hull_reseat_port() did not drag the berth onto the port's new tile - get_docked() would no longer find it, and the clamp is untested")

	var/list/seated = berth.return_coords()
	var/seated_low_x = min(seated[1], seated[3])
	var/seated_high_x = max(seated[1], seated[3])
	var/seated_low_y = min(seated[2], seated[4])
	var/seated_high_y = max(seated[2], seated[4])

	if(seated_low_x < home.low_x || seated_high_x > home.high_x || seated_low_y < home.low_y || seated_high_y > home.high_y)
		TEST_FAIL("After the reseat the berth claims ([seated_low_x],[seated_low_y])-([seated_high_x],[seated_high_y]), outside its own site [home.describe()]. \
			The drag moves the berth's tile without recomputing dwidth/dheight, so the whole rectangle translates with it - onto the cordon \
			gutter and the co-tenant beyond it.")

	// The clamp slides the rectangle; it must not resize the berth, or the next ship that
	// canDock()s against it is measured against a berth that no longer describes the ground.
	if(berth.width * berth.height != (seated_high_x - seated_low_x + 1) * (seated_high_y - seated_low_y + 1))
		TEST_FAIL("The clamp changed the berth's area: [berth.width]x[berth.height] declared, \
			[seated_high_x - seated_low_x + 1]x[seated_high_y - seated_low_y + 1] projected")

	qdel(port, force = TRUE)
	for(var/obj/structure/fans/fan in reseat_to)
		qdel(fan)
	restore_areas(original_areas, hull_area)

/// Puts every turf back in the area it came from and drops the throwaway hull area.
/datum/unit_test/voidcrew_hull_containment/proc/restore_areas(list/original_areas, area/hull_area)
	for(var/turf/tile as anything in original_areas)
		var/area/original = original_areas[tile]
		if(original)
			tile.change_area(hull_area, original)
	original_areas.Cut()
	if(hull_area && !hull_area.has_contained_turfs())
		qdel(hull_area)

/// Tears one spawn_dynamic_encounter() result back down: berths by force (a non-forced qdel on
/// a docking port is a no-op), then the ground, then the slot.
/datum/unit_test/voidcrew_hull_containment/proc/release_encounter(list/encounter_values)
	if(length(encounter_values) < 4)
		return
	var/datum/map_zone/zone = encounter_values[1]
	var/datum/map_footprint/footprint = encounter_values[4]
	for(var/index in 2 to 3)
		var/obj/docking_port/stationary/berth = encounter_values[index]
		if(berth)
			qdel(berth, force = TRUE)
	if(!zone)
		return
	zone.clear_to_uninitialized_space(footprint)
	zone.release_slot(footprint)
