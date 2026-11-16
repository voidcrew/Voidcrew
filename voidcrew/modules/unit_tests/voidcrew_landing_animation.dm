/**
 * # Planet landing visuals clean up after themselves
 *
 * A planet dock warmup puts a shadow and a picture of the ship over the berth, and shows the people aboard
 * the planet coming up around their hull (voidcrew/modules/landing_animation). All of it must be gone once the
 * hull has landed, once the dock is called off, and a few seconds after the hull lifts off again.
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

/// Everything a view from aboard leaves standing around the hull in transit, and on its areas
/datum/unit_test/voidcrew_landing_animation/proc/view_leftovers(list/hull_turfs, list/area/areas)
	var/list/found = list()
	var/turf/first = hull_turfs[1]
	for(var/turf/place as anything in RANGE_TURFS(SHUTTLE_TRANSIT_BORDER + 20, first))
		for(var/obj/effect/effect in place)
			if(istype(effect, /obj/effect/abstract/landing_heat) || istype(effect, /obj/effect/temp_visual/landing_dust))
				found += effect
	for(var/area/was_masked as anything in areas)
		if(!QDELETED(was_masked) && (landing_view_mask_tile() in was_masked.overlays))
			found += was_masked
	return found

/datum/unit_test/voidcrew_landing_animation/proc/start_descent(label)
	ship.forceMove(get_turf(site))
	ship.state = "flying" // OVERMAP_SHIP_FLYING
	ship.docked = null
	// Flying over the planet with nothing under way, the people aboard see it below
	ship.update_hover_view()
	TEST_ASSERT_NOTNULL(ship.hover_view, "A ship flying over a planet does not show it under the hull ([label])")
	site.adjust_dock_to_shuttle(primary, ship.shuttle)
	ship.dock(site, primary)
	var/datum/landing_animation/descent = ship.landing_animation
	TEST_ASSERT_NOTNULL(descent, "A planet dock warmup did not start the descent ([label])")
	TEST_ASSERT_NULL(ship.hover_view, "The view of the planet from above carried on under a descent ([label])")
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
	// And for the people aboard: the planet, its clouds, the ground, on the masked planes around the hull
	var/datum/landing_view/descent/view = descent.inside_view
	TEST_ASSERT_NOTNULL(view, "The descent shows the people aboard nothing")
	TEST_ASSERT(!view.ended, "The view from aboard gave up at once")
	TEST_ASSERT(length(view.pieces) >= 8, "The view from aboard is missing pieces: it has [length(view.pieces)]")
	var/list/area/masked = view.masked.Copy()
	TEST_ASSERT(length(masked) >= 2, "The view is not masked to the hull's areas and its transit space")
	for(var/area/is_masked as anything in masked)
		TEST_ASSERT(landing_view_mask_tile() in is_masked.overlays, "[is_masked] does not carry the view's mask")
	for(var/datum/landing_view_piece/piece as anything in view.pieces)
		if(piece.sky)
			TEST_ASSERT_EQUAL(piece.sky.mouse_opacity, MOUSE_OPACITY_TRANSPARENT, "A piece of the sky catches the mouse")
			TEST_ASSERT_EQUAL(piece.sky.plane, -19, "A piece of the sky is off the view's plane") // LANDING_VIEW_PLANE
	UNTIL((length(view.ground.parts) && length(view.close.parts)) || QDELETED(view))
	TEST_ASSERT(length(view.ground.parts) > 1, "The picture of the ground from afar has nothing in it")
	TEST_ASSERT(length(view.close.parts) > 1, "The close-up picture of the ground has nothing in it")
	for(var/list/part as anything in (view.ground.parts + view.close.parts))
		var/mutable_appearance/look = part[1]
		TEST_ASSERT_EQUAL(look.plane, -19, "Part of the ground picture is off the view's plane") // LANDING_VIEW_PLANE
		TEST_ASSERT_EQUAL(look.mouse_opacity, MOUSE_OPACITY_TRANSPARENT, "Part of the ground picture catches the mouse")
	view.heat_hull(world.time, world.time + 3 SECONDS)
	TEST_ASSERT(length(view.props) > 0, "The hull's edge does not glow on the way in")

	// Called off mid-warmup: everything goes at the next check
	deltimer(ship.dock_warmup_timer)
	ship.dock_warmup_timer = null
	ship.state = "flying" // OVERMAP_SHIP_FLYING
	ship.docked = null
	descent.watch()
	TEST_ASSERT(QDELETED(descent), "A cancelled dock kept its descent")
	TEST_ASSERT_NULL(ship.landing_animation, "A cancelled dock left the ship pointing at its descent")
	TEST_ASSERT_EQUAL(length(effects_on(berth_turfs)), 0, "A cancelled dock left the ship's picture or shadow on the berth")
	TEST_ASSERT(view.ended, "A cancelled dock kept showing the planet to the people aboard")
	sleep(2 SECONDS)
	TEST_ASSERT(QDELETED(view), "A cancelled dock kept its view from aboard")
	TEST_ASSERT_NOTNULL(ship.hover_view, "The planet did not come back under a ship whose landing was called off")
	QDEL_NULL(ship.hover_view)
	TEST_ASSERT_EQUAL(length(view_leftovers(hull_turfs, masked)), 0, "A cancelled dock left the view's glow, dust or mask behind")

	// Landing: the hull's move removes everything in the same tick
	descent = start_descent("second approach")
	view = descent.inside_view
	masked = view.masked.Copy()
	hull_turfs = descent.hull_turfs.Copy()
	descent.thruster_wash()
	deltimer(ship.dock_warmup_timer)
	ship.dock_warmup_timer = null
	TEST_ASSERT_EQUAL(ship.shuttle.initiate_docking(primary), DOCKING_SUCCESS, "The test ship could not land")
	TEST_ASSERT_NULL(ship.landing_animation, "The landed ship still points at its descent")
	TEST_ASSERT(QDELETED(view), "The landed ship still shows its people the view from aboard")
	TEST_ASSERT_EQUAL(length(view_leftovers(hull_turfs, masked)), 0, "Touchdown left the view's glow, dust or mask behind in transit")
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
	var/datum/landing_view/ascent/climb = ship.launch_view
	TEST_ASSERT_NOTNULL(climb, "Takeoff shows the people aboard nothing")
	// The ground it stood on is drawn over the next few ticks: the hull itself still hides it
	var/drawn_by = world.time + 3 SECONDS
	UNTIL(length(climb.close.parts) || QDELETED(climb) || world.time > drawn_by)
	TEST_ASSERT(length(climb.close.parts) > 0, "The ground is not there under the hull soon after it lifts")
	masked = climb.masked.Copy()
	hull_turfs = climb.hull_turfs.Copy()
	ship.state = "flying" // OVERMAP_SHIP_FLYING
	sleep(6 SECONDS)
	TEST_ASSERT_EQUAL(length(effects_on(berth_turfs)), 0, "The takeoff picture or shadow stayed behind")
	sleep(5 SECONDS)
	TEST_ASSERT(QDELETED(climb), "The climb's view from aboard never ended")
	TEST_ASSERT_NULL(ship.launch_view, "The ship still points at its finished climb")
	// The climb ends on the planet as it looks from above, and that stays under the ship
	var/datum/landing_view/hover/below = ship.hover_view
	TEST_ASSERT_NOTNULL(below, "The climb did not leave the planet under the ship")
	TEST_ASSERT(length(below.pieces) >= 4, "The planet under the ship is missing pieces")
	// Until the ship flies on: then it falls away
	ship.forceMove(get_step(get_turf(site), EAST) || get_step(get_turf(site), WEST))
	TEST_ASSERT(below.leaving, "The planet stayed under a ship that had flown on")
	sleep(3 SECONDS)
	TEST_ASSERT(QDELETED(below), "The planet a ship left behind never went")
	TEST_ASSERT_NULL(ship.hover_view, "The ship still points at the planet it left behind")
	TEST_ASSERT_EQUAL(length(view_leftovers(hull_turfs, masked)), 0, "The climb left its dust or mask behind in transit")
	ship.state = "flying" // OVERMAP_SHIP_FLYING
