/// The admin view must describe the same occupancy gates that protect real teardowns.
/datum/unit_test/voidcrew_overmap_management
	var/list/obj/structure/overmap/sites = list()

/datum/unit_test/voidcrew_overmap_management/Destroy()
	for(var/obj/structure/overmap/site as anything in sites)
		if(QDELETED(site))
			continue
		// These fixtures borrow the test turf; they must never sweep it on deletion.
		if(istype(site, /obj/structure/overmap/planet))
			var/obj/structure/overmap/planet/planet = site
			planet.mapzone = null
			planet.footprint = null
			planet.remove_docks()
		else if(istype(site, /obj/structure/overmap/space_ruin))
			var/obj/structure/overmap/space_ruin/ruin = site
			ruin.mapzone = null
			ruin.footprint = null
		else if(istype(site, /obj/structure/overmap/event/meteor))
			var/obj/structure/overmap/event/meteor/field = site
			field.mapzone = null
			field.footprint = null
	return ..()

/datum/unit_test/voidcrew_overmap_management/Run()
	var/mob/living/basic/operator = allocate(/mob/living/basic)
	var/datum/overmap_management/panel = allocate(/datum/overmap_management, operator)
	TEST_ASSERT(!panel.authorized(operator), "Opening a panel must not grant admin rights")

	var/turf/inside = run_loc_floor_bottom_left
	var/datum/map_zone/zone = allocate(/datum/map_zone)
	zone.z_levels = list(reservation)
	var/datum/map_footprint/footprint = allocate(/datum/map_footprint)
	footprint.z_value = inside.z
	footprint.set_rect(inside.x, inside.y, 1, 1)
	var/obj/structure/overmap/planet/planet = allocate(/obj/structure/overmap/planet)
	sites += planet
	planet.mapzone = zone
	planet.footprint = footprint
	TEST_ASSERT(planet in GLOB.overmap_objects, "The registry missed a contact without an overmap turf")
	TEST_ASSERT_NULL(planet.admin_unload_blocker(), "An empty planet was reported as blocked")
	TEST_ASSERT(planet.admin_load_blocker(), "The panel offered a second allocation for a loaded planet")
	planet.first_dock_taken = TRUE
	TEST_ASSERT(planet.admin_unload_blocker(), "A reserved berth was not reported")
	TEST_ASSERT(!planet.can_release_interior(), "The teardown ignored its reported berth blocker")
	planet.first_dock_taken = FALSE
	planet.preserve_level = TRUE
	TEST_ASSERT(planet.admin_unload_blocker() && planet.admin_delete_blocker(), "Preservation did not block both destructive actions")
	planet.preserve_level = FALSE
	planet.loading = TRUE
	TEST_ASSERT(planet.admin_load_blocker() && planet.admin_unload_blocker() && planet.admin_delete_blocker(), "A generation in progress allowed an overlapping admin operation")
	planet.loading = FALSE

	var/mob/living/basic/body = allocate(/mob/living/basic, inside)
	body.mind_initialize()
	var/obj/structure/overmap/space_ruin/ruin = allocate(/obj/structure/overmap/space_ruin)
	sites += ruin
	ruin.mapzone = zone
	ruin.footprint = footprint
	TEST_ASSERT(ruin.admin_unload_blocker(), "An offline body with a mind was not reported for a ruin")
	TEST_ASSERT(!ruin.can_release_interior(), "The ruin teardown disagreed with the admin body blocker")
	body.forceMove(get_step(inside, EAST))
	TEST_ASSERT_NULL(ruin.admin_unload_blocker(), "A neighbouring body's mind pinned this ruin")
	ruin.mission_claims = 1
	TEST_ASSERT(ruin.admin_delete_blocker(), "A contract's contact could be deleted")
	TEST_ASSERT_NULL(ruin.admin_unload_blocker(), "A contract prevented unloading an otherwise empty interior")
	ruin.mission_locked = TRUE
	TEST_ASSERT(ruin.admin_unload_blocker(), "An exclusive mission's interior could be unloaded")

	var/obj/structure/overmap/event/meteor/field = allocate(/obj/structure/overmap/event/meteor)
	sites += field
	field.mapzone = zone
	field.footprint = footprint
	field.second_dock_taken = TRUE
	TEST_ASSERT(field.admin_unload_blocker() && !field.can_release_interior(), "An asteroid field's secondary reservation was missed")
	field.second_dock_taken = FALSE
	TEST_ASSERT_NULL(field.admin_unload_blocker(), "An empty asteroid field was blocked")

	var/obj/docking_port/stationary/port = allocate(/obj/docking_port/stationary, inside)
	planet.reserve_dock = port
	var/list/ports = planet.admin_ports()
	TEST_ASSERT_EQUAL(ports["Landing pad 1"], port, "The assigned primary port was not exposed")
	TEST_ASSERT_EQUAL(planet.admin_interior_turf(), inside, "Interior jump ignored the assigned berth")
	planet.concerned = TRUE
	TEST_ASSERT_NULL(planet.admin_interior_turf(), "The panel allowed an interior jump during teardown")
	planet.concerned = FALSE

	var/timer = addtimer(CALLBACK(planet, TYPE_PROC_REF(/obj/structure/overmap/planet, attempt_despawn)), 5 MINUTES, TIMER_STOPPABLE)
	var/list/timers = planet.admin_cleanup_timers()
	TEST_ASSERT_EQUAL(length(timers), 1, "The real cleanup timer was not exposed")
	TEST_ASSERT_EQUAL(planet.admin_status(), "Unload scheduled", "The scheduled cleanup was not visible in the contact list")
	deltimer(timer)
	TEST_ASSERT_EQUAL(length(planet.admin_cleanup_timers()), 0, "A cancelled cleanup still appeared scheduled")

	var/obj/structure/overmap/planet/empty/temporary = allocate(/obj/structure/overmap/planet/empty, planet)
	sites += temporary
	TEST_ASSERT(temporary in GLOB.overmap_objects, "A contact nested inside another contact was missed")
	temporary.admin_operation = "delete"
	temporary.admin_run_operation("delete", operator)
	TEST_ASSERT(!QDELETED(temporary), "Calling the operation directly bypassed admin authorization")
	TEST_ASSERT_NULL(temporary.admin_operation, "A rejected operation left the contact locked")
	var/datum/weakref/temporary_ref = WEAKREF(temporary)
	qdel(temporary)
	TEST_ASSERT(!(temporary in GLOB.overmap_objects), "A deleted contact remained in the registry")
	TEST_ASSERT_NULL(temporary_ref.resolve(), "The selection could still resolve a deleted contact")

	// Reproduce deleting a docked ship through a try/catch, with a real mobile port.
	// The old teardown raised its ownership diagnostic before removing the overmap ship.
	var/obj/structure/overmap/ship/visitor = allocate(/obj/structure/overmap/ship, planet)
	visitor.name = "Test shuttle A"
	visitor.display_name = "Test shuttle"
	visitor.docked = planet
	visitor.dock_index = 1
	planet.first_dock_taken = TRUE
	var/obj/docking_port/mobile/voidcrew/mobile = allocate(/obj/docking_port/mobile/voidcrew, inside)
	mobile.register()
	mobile.current_ship = visitor
	visitor.shuttle = mobile
	TEST_ASSERT_EQUAL(visitor.admin_name(), "Test shuttle A", "Ship names lost their unique designation")
	panel.select_contact(visitor, planet)
	TEST_ASSERT(findtext(planet.admin_unload_blocker(), "Test shuttle A is docked here"), "The blocker did not identify the ship's actual state")
	TEST_ASSERT_EQUAL(planet.admin_unload_blocker(), planet.admin_delete_blocker(), "Unload and delete gave conflicting docking explanations")
	var/retry = addtimer(CALLBACK(planet, TYPE_PROC_REF(/obj/structure/overmap/planet, check_start_despawn)), 30 SECONDS, TIMER_STOPPABLE)
	TEST_ASSERT_EQUAL(planet.admin_status(), "Cleanup blocked", "A retry timer was presented as scheduled deletion")
	var/deleted = FALSE
	try
		deleted = visitor.despawn_derelict()
	catch(var/exception/exception)
		TEST_FAIL("Planned ship teardown threw an exception: [exception]")
	TEST_ASSERT(deleted && QDELETED(visitor) && QDELETED(mobile), "Deleting a ship left its hull or overmap entry behind")
	TEST_ASSERT_EQUAL(panel.selected_ref?.resolve(), planet, "Deleting an inspected ship did not return to its parent location")
	TEST_ASSERT(!planet.first_dock_taken, "The deleted ship kept its landing pad reserved")
	TEST_ASSERT_NULL(planet.admin_unload_blocker(), "The deleted ship still blocked planet cleanup")
	TEST_ASSERT_NULL(planet.admin_delete_blocker(), "The deleted ship still blocked planet deletion")
	deltimer(retry)
	planet.cancel_despawn_timer()

	var/obj/structure/overmap/ship/approach = allocate(/obj/structure/overmap/ship)
	SSovermap.simulated_ships |= approach
	approach.pending_dock_target = planet
	TEST_ASSERT(approach in planet.get_docking_ships(), "An approaching ship was missing from the ship list")
	TEST_ASSERT_EQUAL(approach.presence_at(planet), "Arriving", "An approach was described as docked")
	TEST_ASSERT(!planet.can_release_interior(), "An approaching ship did not hold cleanup")
	approach.pending_dock_target = null
	qdel(approach)

	panel.build_spawn_catalog()
	var/planet_options = 0
	for(var/id in panel.spawn_catalog)
		var/list/option = panel.spawn_catalog[id]
		if(!ispath(option["path"], /obj/structure/overmap/planet))
			continue
		var/obj/structure/overmap/planet/marker = option["path"]
		var/datum/overmap/planet/definition = initial(marker.planet)
		TEST_ASSERT_EQUAL(option["name"], capitalize(initial(definition.name)), "A spawn option used its sensor disguise instead of its planet definition")
		planet_options++
	var/expected_options = 0
	for(var/obj/structure/overmap/planet/marker as anything in subtypesof(/obj/structure/overmap/planet))
		if(initial(marker.planet))
			expected_options++
	TEST_ASSERT_EQUAL(planet_options, expected_options, "The automatic catalog omitted a planet definition")

	panel.watch_load(planet)
	panel.site_load_finished(planet, FALSE)
	TEST_ASSERT(panel.error && !panel.notice, "A failed asynchronous load was not visible in the panel")
	panel.watch_load(planet)
	panel.site_load_finished(planet, TRUE)
	TEST_ASSERT(panel.notice && !panel.error, "A completed load left a stale error in the panel")

/// Real trader interiors and hangars exercise both the admin readout and reservation teardown.
/datum/unit_test/voidcrew_trader_management/Run()
	var/mob/living/basic/operator = allocate(/mob/living/basic)
	var/datum/overmap_management/panel = allocate(/datum/overmap_management, operator)
	panel.build_spawn_catalog()
	var/list/expected = list(
		/obj/structure/overmap/trader_outpost/black_market,
		/obj/structure/overmap/trader_outpost/outfitter,
		/obj/structure/overmap/trader_outpost/general,
	)
	for(var/id in panel.spawn_catalog)
		var/list/option = panel.spawn_catalog[id]
		if(option["category"] != "Trader outposts")
			continue
		var/path = option["path"]
		TEST_ASSERT(path in expected, "The trader catalog contains an unexpected or duplicate variant")
		expected -= path
		var/obj/structure/overmap/trader_outpost/outpost = allocate(path)
		TEST_ASSERT_EQUAL(option["name"], outpost.admin_name(), "The trader catalog did not use the shop's outpost name")
		TEST_ASSERT_NULL(outpost.admin_load_blocker(), "A fresh trader could not be loaded")
		TEST_ASSERT_NULL(outpost.admin_delete_blocker(), "An unloaded trader could not be deleted")
		TEST_ASSERT(!outpost.admin_is_active(), "An unloaded trader was reported as active")
		outpost.loading = TRUE
		TEST_ASSERT(outpost.admin_load_blocker() && outpost.admin_delete_blocker(), "Loading allowed a concurrent trader operation")
		outpost.loading = FALSE
		panel.watch_load(outpost)
		outpost.start_level_load(operator)
		var/load_deadline = world.time + 1 MINUTES
		UNTIL(!outpost.is_loading() || world.time >= load_deadline)
		TEST_ASSERT(outpost.is_loaded(), "Trader interior failed to load")
		TEST_ASSERT(panel.notice && !panel.error, "Trader load completion did not reach the admin panel")
		TEST_ASSERT(outpost.admin_load_blocker(), "The panel offered to load an already loaded trader")
		TEST_ASSERT_NULL(outpost.admin_delete_blocker(), "Uncontrolled trader NPCs prevented deletion")
		TEST_ASSERT_EQUAL(outpost.admin_interior_turf(), outpost.template_bottom_left, "The trader interior could not be visited")
		var/list/details = panel.contact_details(outpost)
		TEST_ASSERT(details["has_interior"] && details["supports_interior"] && !details["supports_unload"], "Trader interior controls have the wrong capabilities")
		TEST_ASSERT_EQUAL(length(details["players"]), 0, "Uncontrolled NPCs were counted as players")
		var/datum/turf_reservation/concourse = outpost.reservation
		var/datum/map_template/template = outpost.outpost_template
		qdel(outpost)
		TEST_ASSERT(QDELETED(concourse) && QDELETED(template), "Trader deletion leaked its concourse or template")
		TEST_ASSERT(!(outpost in GLOB.trader_outposts) && !(outpost in GLOB.overmap_objects), "Deleted trader remained in an overmap registry")
	TEST_ASSERT_EQUAL(length(expected), 0, "The trader catalog omitted a variant")

	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost/general)
	// An invalid template must report failure, clear loading, and allow a retry.
	outpost.outpost_template = new /datum/map_template/trader_outpost
	panel.watch_load(outpost)
	TEST_ASSERT(!outpost.load_level(), "An invalid trader template reported success")
	TEST_ASSERT(panel.error && !panel.notice && !outpost.is_loading(), "A failed trader load left the panel waiting")
	TEST_ASSERT_NULL(outpost.reservation, "A failed load retained a reservation")
	QDEL_NULL(outpost.outpost_template)
	TEST_ASSERT(outpost.load_level(), "Could not load the occupancy fixture")
	var/mob/living/basic/player = allocate(/mob/living/basic, outpost.template_bottom_left)
	player.mind_initialize()
	var/list/locations = outpost.admin_player_locations()
	TEST_ASSERT_EQUAL(locations[player], "Concourse", "An offline player body was missed in the concourse")
	TEST_ASSERT(outpost.admin_delete_blocker(), "An offline player did not block deletion")
	player.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_NULL(outpost.admin_delete_blocker(), "A player outside the outpost prevented deletion")

	var/obj/structure/overmap/ship/visitor = allocate(/obj/structure/overmap/ship)
	SSovermap.simulated_ships |= visitor
	visitor.pending_dock_target = outpost
	TEST_ASSERT(outpost.admin_delete_blocker(), "An approaching ship did not block trader deletion")
	visitor.pending_dock_target = null
	var/datum/outpost_berth/berth = outpost.allocate_berth(visitor)
	TEST_ASSERT_NOTNULL(berth, "Could not allocate the hangar fixture")
	TEST_ASSERT(outpost.admin_delete_blocker(), "An assigned hangar did not block deletion before the ship arrived")
	// Leave an unassigned hangar so only its occupant, not a ship, holds deletion.
	// Fork signal defines are included after unit tests.
	berth.UnregisterSignal(visitor, list("voidcrew_ship_docked", COMSIG_QDELETING))
	berth.ship = null
	var/turf/hangar_turf = berth.alcove_turfs[1]
	var/obj/structure/closet/container = allocate(/obj/structure/closet, hangar_turf)
	player.forceMove(container)
	locations = outpost.admin_player_locations()
	TEST_ASSERT_EQUAL(locations[player], "Hangar 1", "A player inside a hangar container was missed")
	TEST_ASSERT(outpost.admin_delete_blocker(), "A hangar occupant did not block deletion")
	player.death()
	locations = outpost.admin_player_locations()
	TEST_ASSERT_EQUAL(locations[player], "Hangar 1", "A dead player body was missed in the hangar")
	var/list/details = panel.contact_details(outpost)
	var/list/players = details["players"]
	TEST_ASSERT_EQUAL(length(players), 1, "The hangar occupant was missing or double-counted in the UI")
	var/list/player_details = players[1]
	TEST_ASSERT(player_details["dead"] && !player_details["connected"], "The UI did not report the offline body's state")
	var/list/ports = details["ports"]
	var/list/port = ports[1]
	TEST_ASSERT_EQUAL(port["location"], player_details["location"], "The body was not associated with its docking bay")
	var/turf/outside = get_step(berth.reservation.top_right_turfs[1], EAST)
	player.forceMove(outside)
	TEST_ASSERT_EQUAL(length(outpost.admin_player_locations()), 0, "A neighbouring turf on the same z-level was counted as occupied")
	TEST_ASSERT_NULL(outpost.admin_delete_blocker(), "An empty hangar prevented deletion")
	player.forceMove(run_loc_floor_bottom_left)
	var/datum/turf_reservation/hangar = berth.reservation
	var/datum/turf_reservation/concourse = outpost.reservation
	qdel(outpost)
	TEST_ASSERT(QDELETED(berth) && QDELETED(hangar) && QDELETED(concourse), "Trader deletion leaked a concourse or hangar reservation")
