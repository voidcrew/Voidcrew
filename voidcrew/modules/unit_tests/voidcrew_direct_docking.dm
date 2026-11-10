/**
 * # Ship-to-ship docking berths the pair in the middle of the site
 *
 * position_docks_for_direct_docking() lays two hulls exit-to-exit inside an empty-space
 * encounter. It used to drop the first ship's berth on the site's centre and then let
 * adjust_dock_to_shuttle() re-orient it, which slid the port up to ~45 turfs towards one edge.
 * Only a small hull then fitted across from it, and every bigger pairing (a Scarab against a
 * silverscale or geode pirate, for one) fell back to separate berths with no airlock contact.
 *
 * Builds a real empty-space site and lays several pairs out on it, up to two maximum-size
 * hulls, from every facing. Every pair must berth exit-to-exit, entirely inside the site.
 */
/datum/unit_test/voidcrew_direct_docking_centred
	var/datum/map_zone/zone
	var/datum/map_footprint/footprint
	var/obj/docking_port/stationary/primary
	var/obj/docking_port/stationary/secondary
	var/obj/structure/overmap/planet/empty/site

/datum/unit_test/voidcrew_direct_docking_centred/Destroy()
	if(site)
		site.mapzone = null
		site.footprint = null
		site.reserve_dock = null
		site.reserve_dock_secondary = null
	if(zone && footprint)
		zone.clear_to_uninitialized_space(footprint)
		zone.release_slot(footprint)
	qdel(primary, force = TRUE)
	qdel(secondary, force = TRUE)
	return ..()

/// A registered mobile port with no hull areas (so it never counts as overhanging) and the given shape
/datum/unit_test/voidcrew_direct_docking_centred/proc/make_port(width, height, dwidth, dheight, port_direction)
	var/obj/docking_port/mobile/voidcrew/port = allocate(/obj/docking_port/mobile/voidcrew, run_loc_floor_bottom_left)
	port.shuttle_areas = list()
	port.register()
	port.width = width
	port.height = height
	port.dwidth = dwidth
	port.dheight = dheight
	port.port_direction = port_direction
	return port

/// Whether every turf `port` would cover berthed on `dock` lies inside the site
/datum/unit_test/voidcrew_direct_docking_centred/proc/inside_site(obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	var/list/coords = port.return_coords(dock.x, dock.y, dock.dir)
	return min(coords[1], coords[3]) >= footprint.low_x && max(coords[1], coords[3]) <= footprint.high_x \
		&& min(coords[2], coords[4]) >= footprint.low_y && max(coords[2], coords[4]) <= footprint.high_y

/datum/unit_test/voidcrew_direct_docking_centred/Run()
	var/list/values = SSovermap.spawn_dynamic_encounter(/datum/overmap/planet/empty, FALSE)
	if(length(values) < 4 || !values[1] || !values[2] || !values[3] || !values[4])
		TEST_FAIL("spawn_dynamic_encounter() did not build an empty-space site with two berths")
		return
	zone = values[1]
	primary = values[2]
	secondary = values[3]
	footprint = values[4]
	site = allocate(/obj/structure/overmap/planet/empty)
	site.mapzone = zone
	site.footprint = footprint
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)

	// list(name, width, height, dwidth, dheight) for each hull of a pair. The Scarab, silverscale
	// and geode shapes are the ones a playtest saw fall back to separate berths; the last pairs
	// are two maximum hulls (RESERVE_DOCK_MAX_SIZE_LONG 56 x SHORT 40), ports at opposite corners.
	var/list/pairs = list(
		list(list("scarab", 20, 33, 15, 1), list("silverscale", 17, 27, 13, 0)),
		list(list("scarab", 20, 33, 15, 1), list("geode", 21, 19, 10, 1)),
		list(list("max long", 40, 56, 0, 0), list("max long", 40, 56, 39, 0)),
		list(list("max wide", 56, 40, 0, 0), list("max wide", 56, 40, 55, 0)),
	)
	for(var/list/pair as anything in pairs)
		var/list/shape_a = pair[1]
		var/list/shape_b = pair[2]
		for(var/facing in GLOB.cardinals)
			var/obj/docking_port/mobile/port_a = make_port(shape_a[2], shape_a[3], shape_a[4], shape_a[5], facing)
			var/obj/docking_port/mobile/port_b = make_port(shape_b[2], shape_b[3], shape_b[4], shape_b[5], facing)
			var/label = "[shape_a[1]] + [shape_b[1]] (port facing [dir2text(facing)])"
			if(!ship.position_docks_for_direct_docking(site, primary, secondary, port_a, port_b))
				TEST_FAIL("[label] did not fit exit-to-exit in a [footprint.get_width()]x[footprint.get_height()] site")
				continue
			TEST_ASSERT_EQUAL(secondary.dir, REVERSE_DIR(primary.dir), "[label]: the second berth doesn't face the first")
			TEST_ASSERT_EQUAL(get_turf(secondary), get_step(primary, REVERSE_DIR(primary.dir)), "[label]: the berths aren't exit-to-exit")
			TEST_ASSERT(inside_site(port_a, primary), "[label]: the first hull would hang off the site")
			TEST_ASSERT(inside_site(port_b, secondary), "[label]: the second hull would hang off the site")
			qdel(port_a, force = TRUE)
			qdel(port_b, force = TRUE)
