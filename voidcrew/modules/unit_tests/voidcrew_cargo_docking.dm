/// Cargo must berth outside the receiving hull after ship-to-ship rotation or port relocation.
/datum/unit_test/voidcrew_cargo_docking
	var/obj/structure/overmap/ship/ship
	var/obj/structure/overmap/planet/empty/site
	var/obj/docking_port/mobile/voidcrew/ship_port
	var/obj/docking_port/mobile/cargo_docking_test/cargo_port
	var/obj/docking_port/stationary/ship_dock
	var/obj/docking_port/stationary/cargo_dock
	var/datum/voidcrew_cargo_shuttle/cargo_docking_test/ferry

/datum/unit_test/voidcrew_cargo_docking/Destroy()
	if(ferry)
		ferry.shuttle_port = null
		ferry.target_ship = null
		ferry.docked_at = null
	if(ship)
		ship.shuttle = null
	if(site)
		site.reserve_dock = null
		site.reserve_dock_secondary = null
		site.loaded = FALSE
	for(var/obj/docking_port/port in list(ship_port, cargo_port, ship_dock, cargo_dock))
		qdel(port, force = TRUE)
	return ..()

/datum/unit_test/voidcrew_cargo_docking/Run()
	var/turf/anchor = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	ship_port = allocate(/obj/docking_port/mobile/voidcrew, anchor)
	ship_port.shuttle_areas = list()
	ship_port.register()
	ship_port.width = 3
	ship_port.height = 4
	ship_port.dwidth = 1
	ship_port.dheight = 0
	ship_port.port_direction = SOUTH
	ship_dock = allocate(/obj/docking_port/stationary, anchor)
	cargo_dock = allocate(/obj/docking_port/stationary, run_loc_floor_bottom_left)
	cargo_port = allocate(/obj/docking_port/mobile/cargo_docking_test, run_loc_floor_bottom_left)
	cargo_port.shuttle_areas = list()
	cargo_port.register()
	cargo_port.width = 3
	cargo_port.height = 3
	cargo_port.dwidth = 1
	cargo_port.dheight = 0
	ship = allocate(/obj/structure/overmap/ship)
	ship.shuttle = ship_port
	site = allocate(/obj/structure/overmap/planet/empty)
	site.loaded = TRUE
	site.first_dock_taken = TRUE
	site.second_dock_taken = TRUE
	site.reserve_dock = ship_dock
	site.reserve_dock_secondary = cargo_dock
	ferry = allocate(/datum/voidcrew_cargo_shuttle/cargo_docking_test)
	ferry.target_ship = ship
	ferry.shuttle_port = cargo_port
	ferry.docked_at = site
	ferry.cargo_dock_index = 2

	for(var/facing in GLOB.cardinals)
		ship_port.dir = facing
		// A relocated mobile port can leave the stationary port facing the old way.
		ship_dock.dir = REVERSE_DIR(facing)
		cargo_port.arrival_dock = null
		ferry.state = 1 // CARGO_SHUTTLE_ARRIVING; fork defines follow unit test includes.
		TEST_ASSERT(ferry.complete_arrival(), "Cargo arrival failed for receiving hull direction [facing]")
		TEST_ASSERT_EQUAL(cargo_port.arrival_dock, cargo_dock, "Arrival did not dispatch to the allocated cargo berth")
		TEST_ASSERT_EQUAL(get_turf(ship_port), anchor, "Delivery moved the receiving ship")
		TEST_ASSERT_EQUAL(ship_dock.dir, facing, "Arrival overwrote the receiving hull's actual direction")
		TEST_ASSERT_EQUAL(cargo_dock.dir, REVERSE_DIR(facing), "Cargo does not face away from the receiving ship")
		TEST_ASSERT_EQUAL(get_turf(cargo_dock), get_step(anchor, REVERSE_DIR(facing)), "Cargo berth lies inside the receiving hull")
		var/list/hull_tiles = ship_port.return_ordered_turfs(ship_port.x, ship_port.y, ship_port.z, ship_port.dir)
		var/list/landing_tiles = cargo_port.return_ordered_turfs(cargo_dock.x, cargo_dock.y, cargo_dock.z, cargo_dock.dir)
		TEST_ASSERT_EQUAL(length(hull_tiles & landing_tiles), 0, "Cargo's projected landing overlaps the receiving hull")

/// Keep the arrival state machine real while observing the selected landing before transplantation.
/obj/docking_port/mobile/cargo_docking_test
	var/obj/docking_port/stationary/arrival_dock

/obj/docking_port/mobile/cargo_docking_test/initiate_docking(obj/docking_port/stationary/new_dock, movement_direction, force = FALSE)
	arrival_dock = new_dock
	return DOCKING_SUCCESS

/datum/voidcrew_cargo_shuttle/cargo_docking_test/get_cargo_bay_turfs()
	return list(get_turf(shuttle_port))
