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
