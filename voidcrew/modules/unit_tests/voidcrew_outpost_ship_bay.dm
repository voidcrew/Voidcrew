/// Real map load, payment boundary, visit permissions, and bay zone teardown.
/datum/unit_test/voidcrew_outpost_ship_bay
	parent_type = /datum/unit_test/voidcrew_outpost_management

/// Exercise the same destination list players see, including unused installed bays.
/datum/unit_test/voidcrew_outpost_ship_bay/proc/bay_floors(obj/machinery/outpost_elevator/panel, mob/user)
	var/list/data = panel.ui_data(user)
	var/list/result = list()
	for(var/list/floor as anything in data["floors"])
		if(findtext(floor["name"], "Ship Bay ") == 1)
			result += list(floor)
	return result

/datum/unit_test/voidcrew_outpost_ship_bay/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "bayowner"
	TEST_ASSERT(home.load_level(), "Could not load the bay test outpost")
	var/mob/living/carbon/human/owner = make_player(get_turf(home.management_console), "bayowner")
	var/mob/living/carbon/human/visitor = make_player(get_turf(home.management_console), "bayvisitor")
	var/obj/machinery/outpost_elevator/panel = allocate(__IMPLIED_TYPE__, get_turf(owner))
	panel.outpost = home
	panel.is_lobby = TRUE
	TEST_ASSERT_EQUAL(length(bay_floors(panel, owner)), 0, "An uninstalled ship bay appeared in the elevator")
	var/obj/machinery/ore_silo/home_silo = home.ship_bay_silo()
	TEST_ASSERT_NOTNULL(home_silo, "The mapped outpost silo required a construction console link")
	var/obj/machinery/ore_silo/second_silo = allocate(__IMPLIED_TYPE__, get_turf(home.construction_console))
	TEST_ASSERT_NULL(home.ship_bay_silo(), "Multiple silos were silently selected")
	TEST_ASSERT(!home.select_service_silo(visitor, home_silo), "A visitor selected outpost storage")
	TEST_ASSERT(home.select_service_silo(owner, home_silo), "The owner could not select outpost storage")
	TEST_ASSERT_EQUAL(home.ship_bay_silo(), home_silo, "Selected storage was ignored")
	qdel(second_silo)
	TEST_ASSERT_NOTNULL(home.install_ship_bay(owner), "Unfunded installation succeeded")
	home.treasury.adjust_money(10000, "Ship bay test") // Fork defines follow the test includes.
	TEST_ASSERT_NOTNULL(home.install_ship_bay(owner), "Installation without materials succeeded")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 10000, "Missing materials still charged the treasury")
	var/list/cost = home.ship_bay_material_cost()
	for(var/material in cost)
		home_silo.materials.insert_amount_mat(cost[material], material)
	TEST_ASSERT_NOTNULL(home.install_ship_bay(visitor), "A visitor spent the outpost treasury")
	TEST_ASSERT_NULL(home.install_ship_bay(owner), "A funded owner could not install the bays")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 0, "Bay installation charged the wrong price")
	TEST_ASSERT(!home_silo.materials.has_materials(cost), "Installation did not consume its materials")
	TEST_ASSERT_NOTNULL(home.install_ship_bay(owner), "Repeated installation succeeded")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 0, "Repeated installation charged again")
	var/list/floors = bay_floors(panel, owner)
	TEST_ASSERT_EQUAL(length(floors), 1, "Installed empty bays were invisible in the elevator")
	for(var/list/floor as anything in floors)
		TEST_ASSERT(floor["occupied"], "The permanent empty bay cannot be visited")
		TEST_ASSERT_NOTNULL(home.get_floor_alcove(floor["id"]), "The empty bay has no elevator destination")

	var/obj/structure/overmap/ship/ship = allocate(__IMPLIED_TYPE__)
	visitor_port = new(run_loc_floor_bottom_left)
	visitor_port.width = 1
	visitor_port.height = 1
	visitor_port.dwidth = 0
	visitor_port.dheight = 0
	visitor_port.current_ship = ship
	ship.shuttle = visitor_port
	SSovermap.simulated_ships |= ship
	ship.ship_team = new /datum/team/voidcrew
	ship.ship_team.add_member(visitor.mind)
	var/datum/outpost_berth/ship_bay/bay = home.allocate_ship_bay(ship)
	TEST_ASSERT_NOTNULL(bay, "Bay allocation failed")
	TEST_ASSERT_NULL(home.allocate_ship_bay(ship), "One visit acquired two construction bays")
	TEST_ASSERT_NOTNULL(bay.console, "Mapped bay console is missing")
	TEST_ASSERT_EQUAL(bay.console.internal_rcd.matter, 0, "A fresh bay minted free RCD charge")
	TEST_ASSERT_EQUAL(get_outpost_from_atom(bay.console), home, "Bay fixtures lost their outpost identity")
	TEST_ASSERT(!bay.console.can_operate(), "Bay could operate before arrival")
	TEST_ASSERT(!bay.console.is_crew_member(owner), "Outpost ownership granted control over a visiting ship")
	TEST_ASSERT(!bay.console.can_link_silo(home_silo), "Outpost materials were available without approval")
	var/floor_id = bay.berth_number
	TEST_ASSERT_EQUAL(home.get_floor_alcove(floor_id), bay.alcove_turfs, "The elevator cannot reach the bay")
	floors = bay_floors(panel, visitor)
	var/list/active_floor = floors[1]
	TEST_ASSERT_EQUAL(active_floor["id"], floor_id, "The elevator did not replace the vacancy with the visit's floor")
	TEST_ASSERT(active_floor["occupied"] && active_floor["your_ship"], "The active bay was not reachable and identified for its crew")

	visitor_turf = get_turf(bay.dock)
	original_visitor_area = get_area(visitor_turf)
	visitor_area = new
	visitor_turf.change_area(original_visitor_area, visitor_area)
	visitor_port.forceMove(visitor_turf)
	visitor_port.shuttle_areas = list()
	visitor_port.shuttle_areas[visitor_area] = TRUE
	visitor_area.shuttle_port = visitor_port
	visitor_port.register()
	ship.docked = home
	ship.state = "idle"
	var/obj/machinery/ore_silo/ship_silo = allocate(__IMPLIED_TYPE__, visitor_turf)
	bay.on_ship_docked(ship)
	TEST_ASSERT(bay.console.can_operate(), "The arrived ship could not use its bay")
	TEST_ASSERT_EQUAL(bay.console.get_linked_silo(), ship_silo, "Arrival did not link the visiting ship's silo")
	TEST_ASSERT(!bay.request_silo(owner), "A non-crew member requested materials for a visiting ship")
	TEST_ASSERT(bay.request_silo(visitor), "Crew could not request outpost materials")
	TEST_ASSERT(!bay.approve_silo(visitor), "The visitor approved its own spending request")
	TEST_ASSERT(bay.approve_silo(owner), "The owner could not approve a current request")
	TEST_ASSERT_EQUAL(bay.console.get_linked_silo(), home_silo, "Approval did not connect the selected outpost silo")
	for(var/material in cost)
		home_silo.materials.insert_amount_mat(cost[material], material)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/bay/console = bay.console
	var/obj/item/construction/rcd/internal/ship/rcd = console.internal_rcd
	TEST_ASSERT(rcd.useResource(0, visitor), "An authorized zero-cost action was treated as a failed payment")
	TEST_ASSERT(console.internal_rtd.use_tile_materials(visitor), "Approved tiling could not consume materials")
	TEST_ASSERT(console.internal_rld.use_wall_light_materials(visitor), "Approved lighting could not consume materials")
	// A stale component must reject use immediately, before the periodic cleanup.
	ship.state = "undocking"
	TEST_ASSERT(!rcd.useResource(0, visitor), "A zero-cost action bypassed revoked material access")
	TEST_ASSERT(!rcd.check_materials(list(/datum/material/iron = 1), visitor), "Departure retained RCD access to the outpost silo")
	TEST_ASSERT(!console.internal_rtd.use_tile_materials(visitor), "Departure allowed free tiling after the silo refused payment")
	TEST_ASSERT(!console.internal_rld.use_wall_light_materials(visitor), "Departure allowed free lights after the silo refused payment")
	ship.state = "idle"
	home.founder_ckey = "replacementowner"
	TEST_ASSERT(!console.can_link_silo(home_silo), "A new owner inherited the previous owner's material approval")
	bay.reconcile_silo()
	TEST_ASSERT_NULL(bay.approved_silo, "Invalid material approval survived reconciliation")
	TEST_ASSERT_EQUAL(console.get_linked_silo(), ship_silo, "Revocation did not return the console to ship materials")

	// Returning home uses the owner's crew relationship, without a request or grant.
	home.founder_ckey = owner.ckey
	home.founder_mind = WEAKREF(owner.mind)
	ship.ship_team.add_member(owner.mind)
	bay.on_ship_docked(ship)
	TEST_ASSERT_EQUAL(console.get_linked_silo(), home_silo, "Returning home did not automatically connect outpost storage")
	TEST_ASSERT_NULL(bay.silo_requested_at, "Returning home requested approval from the owner")
	TEST_ASSERT_NULL(bay.approved_silo, "Automatic owner access created a visitor grant")
	var/list/console_data = console.ui_data(visitor)
	TEST_ASSERT(console_data["bay"]["available"], "Owner crew still sees the material request flow")
	TEST_ASSERT(console.use_ship_silo(), "Owner crew could not switch to ship storage")
	bay.reconcile_silo()
	TEST_ASSERT_EQUAL(console.get_linked_silo(), ship_silo, "Reconciliation overrode the crew's source selection")
	TEST_ASSERT(console.use_outpost_silo(), "Owner crew could not switch directly to outpost storage")
	TEST_ASSERT(bay.request_silo(visitor), "A stale request button could not connect owner storage")
	TEST_ASSERT_NULL(bay.silo_requested_at, "A stale request button created a self-approval request")
	second_silo = allocate(/obj/machinery/ore_silo, get_turf(home.management_console))
	TEST_ASSERT(home.select_service_silo(owner, second_silo), "Owner could not change service storage")
	TEST_ASSERT_EQUAL(console.get_linked_silo(), second_silo, "Owner's connected bay did not follow the service silo selection")
	TEST_ASSERT(!console.can_link_silo(home_silo), "The old outpost silo remained available")
	TEST_ASSERT(home.select_service_silo(owner, home_silo), "Owner could not restore service storage")
	ship.ship_team.remove_member(owner.mind)
	TEST_ASSERT(!console.can_link_silo(home_silo), "A former owner crew kept automatic spending access")
	TEST_ASSERT(!rcd.check_materials(list(/datum/material/iron = 1), visitor), "A stale automatic link spent the outpost's materials")
	bay.reconcile_silo()
	TEST_ASSERT_EQUAL(console.get_linked_silo(), ship_silo, "Loss of owner crew membership did not restore ship storage")
	TEST_ASSERT(!console.use_outpost_silo(), "A former owner crew reconnected without approval")
	TEST_ASSERT(bay.request_silo(visitor) && bay.silo_requested_at, "A former owner crew did not return to visitor approval")
	bay.revoke_silo()
	qdel(second_silo)

	// Departure leaves the permanent floor, occupants and fixtures in place.
	owner.forceMove(bay.alcove_turfs[1])
	visitor_turf.change_area(visitor_area, original_visitor_area)
	visitor_turf = null
	visitor_port.forceMove(run_loc_floor_bottom_left)
	ship_silo.forceMove(run_loc_floor_bottom_left)
	ship.docked = null
	ship.state = "flying"
	var/datum/outpost_zone/bay_ground = bay.zone
	var/turf/bay_origin = bay.hangar_bottom_left
	home.on_ship_undock_complete(ship)
	TEST_ASSERT(!QDELETED(bay) && bay.zone == bay_ground && bay_ground?.state == "in use" && !QDELETED(console), "Departure unloaded the permanent bay")
	TEST_ASSERT_EQUAL(get_turf(owner), bay.alcove_turfs[1], "Departure displaced a shore-side occupant")
	TEST_ASSERT_EQUAL(home.get_floor_alcove(floor_id), bay.alcove_turfs, "Departure removed the elevator destination")
	TEST_ASSERT(bay.is_available(), "The physically departed ship retained its reservation")
	TEST_ASSERT_NULL(console.current_ship, "The permanent console retained its departed ship")
	TEST_ASSERT_NULL(console.get_linked_silo(), "The empty bay retained the visitor's material link")
	floors = bay_floors(panel, owner)
	active_floor = floors[1]
	TEST_ASSERT_EQUAL(length(floors), 1, "Departure changed bay capacity")
	TEST_ASSERT(active_floor["occupied"], "Departure disabled the permanent floor")
	TEST_ASSERT_EQUAL(active_floor["id"], floor_id, "Departure replaced the permanent elevator destination")
	var/datum/outpost_berth/ship_bay/replacement = home.allocate_ship_bay(ship)
	TEST_ASSERT_EQUAL(replacement, bay, "A return visit replaced the bay")
	TEST_ASSERT(replacement.zone == bay_ground && replacement.hangar_bottom_left == bay_origin && replacement.console == console, "A return visit reloaded the bay map")
	TEST_ASSERT_NULL(replacement.approved_silo, "A new visit inherited material access")
	replacement.check_arrival()
	TEST_ASSERT(!QDELETED(bay) && bay.is_available(), "An aborted arrival removed or retained the permanent bay")
	TEST_ASSERT_EQUAL(bay.dock.ship_bay, bay, "Releasing a visit removed docking protection")

/// Keep the capacity/deletion test independent of payment and construction failures.
/datum/unit_test/voidcrew_outpost_ship_bay_capacity
	parent_type = /datum/unit_test/voidcrew_outpost_management
	var/list/ports = list()

/datum/unit_test/voidcrew_outpost_ship_bay_capacity/Destroy()
	for(var/obj/docking_port/mobile/voidcrew/port as anything in ports)
		if(!QDELETED(port))
			if(port.current_ship)
				port.current_ship.shuttle = null
			port.current_ship = null
			qdel(port, force = TRUE)
	return ..()

/datum/unit_test/voidcrew_outpost_ship_bay_capacity/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	TEST_ASSERT(home.load_level(), "Capacity test outpost did not load")
	TEST_ASSERT_NULL(home.enable_ship_bays(), "Permanent bay installation failed")
	var/list/visitors = list()
	for(var/i in 1 to 3)
		var/obj/structure/overmap/ship/ship = allocate(__IMPLIED_TYPE__)
		var/obj/docking_port/mobile/voidcrew/port = new(run_loc_floor_bottom_left)
		ports += port
		ship.shuttle = port
		port.current_ship = ship
		visitors += ship
	var/datum/outpost_berth/ship_bay/first = home.allocate_ship_bay(visitors[1])
	TEST_ASSERT_NOTNULL(first, "The installed bay could not be reserved")
	TEST_ASSERT_NULL(home.allocate_ship_bay(visitors[2]), "A second ship bypassed the single bay reservation")
	var/obj/docking_port/mobile/voidcrew/intruder = ports[2]
	TEST_ASSERT_EQUAL(intruder.canDock(first.dock), SHUTTLE_SOMEONE_ELSE_DOCKED, "Another ship can target the reserved bay")
	TEST_ASSERT_EQUAL(intruder.initiate_docking(first.dock, force = TRUE), DOCKING_BLOCKED, "A forced move bypassed the bay reservation")
	var/datum/outpost_zone/first_ground = first.zone
	var/obj/structure/overmap/ship/deleted_ship = visitors[1]
	deleted_ship.shuttle = null
	qdel(deleted_ship)
	TEST_ASSERT(!QDELETED(first) && first.zone == first_ground && first_ground?.state == "in use", "Deleting a visiting ship unloaded the permanent bay")
	TEST_ASSERT(first.is_available(), "Deleted ship retained the bay reservation")
	var/datum/job = allocate(/datum)
	TEST_ASSERT_EQUAL(home.reserve_rebuild_bay(job), first, "A rebuild could not reserve an empty permanent bay")
	for(var/i in 1 to 3)
		first.check_arrival()
		first.release(force = TRUE)
	TEST_ASSERT(!first.is_available(), "Arrival timeout or visit cleanup released a rebuild reservation")
	TEST_ASSERT_NULL(home.allocate_ship_bay(visitors[2]), "A visitor took the bay during reconstruction")
	TEST_ASSERT_NULL(home.reserve_rebuild_bay(src), "A second rebuild took an occupied reservation")
	TEST_ASSERT_EQUAL(intruder.initiate_docking(first.dock, force = TRUE), DOCKING_BLOCKED, "A visitor physically landed during reconstruction")
	first.finish_rebuild(src)
	TEST_ASSERT(!first.is_available(), "Another job unlocked the reconstruction bay")
	first.finish_rebuild(job)
	TEST_ASSERT(first.is_available(), "A completed empty job did not release its reservation")
	TEST_ASSERT_EQUAL(home.allocate_ship_bay(visitors[2]), first, "The same permanent bay could not be reassigned")
	qdel(home)
	TEST_ASSERT(QDELETED(first) && QDELETED(first_ground), "Deleting the outpost leaked its permanent bay")
