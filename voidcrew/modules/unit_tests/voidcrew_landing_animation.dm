/**
 * # Planet landing visuals clean up after themselves
 *
 * A planet dock warmup puts a shadow and a picture of the ship over the berth
 * (voidcrew/modules/landing_animation). Both must be gone once the hull has landed, once the dock is called
 * off, and a few seconds after the hull lifts off again.
 */
/datum/unit_test/voidcrew_landing_animation
	var/datum/map_zone/zone
	var/datum/map_footprint/footprint
	var/obj/docking_port/stationary/primary
	var/obj/docking_port/stationary/secondary
	var/obj/structure/overmap/planet/wasteland/site
	var/obj/structure/overmap/ship/ship

/datum/unit_test/voidcrew_landing_animation/Destroy()
	if(ship)
		qdel(ship) // takes its hull with it
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

/// Every landing picture or shadow standing anywhere in the box around [turfs]
/datum/unit_test/voidcrew_landing_animation/proc/effects_on(list/turfs)
	var/list/found = list()
	var/turf/first = turfs[1]
	var/min_x = first.x
	var/max_x = first.x
	var/min_y = first.y
	var/max_y = first.y
	for(var/turf/place as anything in turfs)
		min_x = min(min_x, place.x)
		max_x = max(max_x, place.x)
		min_y = min(min_y, place.y)
		max_y = max(max_y, place.y)
	for(var/turf/place as anything in block(min_x, min_y, first.z, max_x, max_y, first.z))
		for(var/obj/effect/abstract/effect in place)
			if(istype(effect, /obj/effect/abstract/landing_proxy) || istype(effect, /obj/effect/abstract/landing_shadow))
				found += effect
	return found

/datum/unit_test/voidcrew_landing_animation/proc/start_descent(label)
	ship.forceMove(get_turf(site))
	ship.state = "flying" // OVERMAP_SHIP_FLYING
	ship.docked = null
	site.adjust_dock_to_shuttle(primary, ship.shuttle)
	ship.dock(site, primary)
	var/datum/landing_animation/descent = ship.landing_animation
	TEST_ASSERT_NOTNULL(descent, "A planet dock warmup did not start the descent ([label])")
	// Skip the wait for the shadow and the ship; the timers would fire the same procs a few seconds in
	descent.show_shadow()
	descent.show_proxies()
	return descent

/datum/unit_test/voidcrew_landing_animation/Run()
	var/list/values = SSovermap.spawn_dynamic_encounter(/datum/overmap/planet/empty, FALSE)
	if(length(values) < 4 || !values[1] || !values[2] || !values[3] || !values[4])
		TEST_FAIL("spawn_dynamic_encounter() did not build a site with a berth")
		return
	zone = values[1]
	primary = values[2]
	secondary = values[3]
	footprint = values[4]
	// Planet type decides whether the landing plays; the berth itself can be any ground
	site = allocate(/obj/structure/overmap/planet/wasteland)
	site.mapzone = zone
	site.footprint = footprint
	site.reserve_dock = primary
	site.reserve_dock_secondary = secondary
	TEST_ASSERT(landing_animation_wanted(site), "A terrain planet does not play the landing")
	TEST_ASSERT(!landing_animation_wanted(allocate(/obj/structure/overmap/planet/empty)), "Empty space plays the planet landing")

	ship = SSshuttle.create_ship(/datum/map_template/shuttle/voidcrew/box)
	TEST_ASSERT_NOTNULL(ship, "No test ship")
	var/obj/docking_port/stationary/transit/transit = ship.shuttle.get_docked()
	TEST_ASSERT(istype(transit), "The test ship did not start in transit")

	// Warmup: a picture with every hull tile in it, plus the shadow
	var/datum/landing_animation/descent = start_descent("first approach")
	var/list/hull_turfs = descent.hull_turfs.Copy()
	var/list/berth_turfs = descent.berth_turfs.Copy()
	TEST_ASSERT(length(hull_turfs) > 0, "The descent found no hull tiles")
	var/obj/effect/abstract/landing_proxy/picture = descent.proxy
	TEST_ASSERT_NOTNULL(picture, "The descent has no ship")
	TEST_ASSERT(length(picture.overlays) >= length(hull_turfs), "The ship's picture is missing hull tiles")
	TEST_ASSERT_EQUAL(picture.mouse_opacity, MOUSE_OPACITY_TRANSPARENT, "The picture catches the mouse")
	TEST_ASSERT(!picture.density, "The picture is dense")
	TEST_ASSERT_NOTNULL(descent.shadow, "The descent has no shadow")

	// Called off mid-warmup: everything goes at the next check
	deltimer(ship.dock_warmup_timer)
	ship.dock_warmup_timer = null
	ship.state = "flying" // OVERMAP_SHIP_FLYING
	ship.docked = null
	descent.watch()
	TEST_ASSERT(QDELETED(descent), "A cancelled dock kept its descent")
	TEST_ASSERT_NULL(ship.landing_animation, "A cancelled dock left the ship pointing at its descent")
	TEST_ASSERT_EQUAL(length(effects_on(berth_turfs)), 0, "A cancelled dock left the ship's picture or shadow on the berth")

	// Landing: the hull's move removes everything in the same tick
	descent = start_descent("second approach")
	deltimer(ship.dock_warmup_timer)
	ship.dock_warmup_timer = null
	TEST_ASSERT_EQUAL(ship.shuttle.initiate_docking(primary), DOCKING_SUCCESS, "The test ship could not land")
	TEST_ASSERT_NULL(ship.landing_animation, "The landed ship still points at its descent")
	// For a moment the picture covers the landed hull while its lighting is rebuilt
	picture = descent.proxy
	TEST_ASSERT_NOTNULL(picture, "The picture went before the landed hull's lighting was rebuilt")
	TEST_ASSERT_EQUAL(picture.pixel_z, 0, "At touchdown the picture is still in the air")
	sleep(4 SECONDS)
	TEST_ASSERT(QDELETED(descent), "Touchdown kept the descent")
	TEST_ASSERT_EQUAL(length(effects_on(berth_turfs)), 0, "Touchdown left the picture or the shadow on the berth")

	// Takeoff: a climbing proxy is left behind, and it is gone a few seconds later
	ship.docked = null
	ship.state = "undocking" // OVERMAP_SHIP_UNDOCKING
	ship.undock_origin = WEAKREF(site)
	var/obj/docking_port/stationary/transit/departure = ship.shuttle.assigned_transit || SSshuttle.generate_transit_dock(ship.shuttle)
	TEST_ASSERT_NOTNULL(departure, "No transit dock to leave into")
	TEST_ASSERT_EQUAL(ship.shuttle.initiate_docking(departure), DOCKING_SUCCESS, "The test ship could not take off")
	TEST_ASSERT(length(effects_on(berth_turfs)) > 0, "Takeoff left no climbing picture")
	sleep(6 SECONDS)
	TEST_ASSERT_EQUAL(length(effects_on(berth_turfs)), 0, "The takeoff picture or shadow stayed behind")
	ship.state = "flying" // OVERMAP_SHIP_FLYING
