/**
 * A ship landing at a claim never reaches an upgrade. Ships only berth in the hangar and ship
 * bay zones (outpost_level_layout.dm), which lie outside the build region behind cordon, so the
 * claim keeps no landing pads of its own and every zone tile is refused to upgrades.
 */
/datum/unit_test/voidcrew_outpost_dock_clearance
	parent_type = /datum/unit_test/voidcrew_outpost_management
	/// Bare mobile ports standing in for hulls; docking ports only delete when forced.
	var/list/obj/docking_port/mobile/fake_ports = list()

/datum/unit_test/voidcrew_outpost_dock_clearance/Destroy()
	for(var/obj/docking_port/mobile/port as anything in fake_ports)
		if(!QDELETED(port))
			qdel(port, force = TRUE)
	fake_ports.Cut()
	return ..()

/datum/unit_test/voidcrew_outpost_dock_clearance/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("dockclearanceowner")
	TEST_ASSERT_NOTNULL(home, "The dock clearance outpost did not load")
	var/level_z = home.upgrade_level_z()
	TEST_ASSERT(isnull(home.reserve_dock) && isnull(home.reserve_dock_secondary), "The claim kept a reserve landing pad")
	for(var/obj/docking_port/stationary/dock as anything in SSshuttle.stationary_docking_ports)
		if(dock.z == level_z)
			TEST_ASSERT(!home.is_turf_buildable(get_turf(dock)), "A docking port ([dock.name]) stands on the claim at ([dock.x],[dock.y])")
	TEST_ASSERT_EQUAL(length(home.level_zones), 4 + 3, "The claim has [length(home.level_zones)] zones")
	for(var/key in home.level_zones)
		var/datum/outpost_zone/zone = home.level_zones[key]
		for(var/turf/corner as anything in list(zone.get_bottom_left(), zone.get_top_right(), locate(zone.low_x, zone.high_y, level_z), locate(zone.high_x, zone.low_y, level_z)))
			TEST_ASSERT(home.is_upgrade_ground_reserved(corner) || !home.is_upgrade_turf_clear(corner), "The [key] zone's tile ([corner.x],[corner.y]) accepts an upgrade")
			TEST_ASSERT(!home.is_turf_buildable(corner), "The [key] zone's tile ([corner.x],[corner.y]) is buildable")

/// Without its hangar lift a claim refuses ships outright, and a refusal leaves nothing claimed.
/datum/unit_test/voidcrew_outpost_dock_needs_lift
	parent_type = /datum/unit_test/voidcrew_outpost_dock_clearance
	/// The bare ship fixture, unhooked from its fake port before cleanup
	var/obj/structure/overmap/ship/visitor_ship
	/// The claim whose hangar elevator this test hid, and its elevator panels
	var/obj/structure/overmap/dynamic/player_outpost/test_home
	var/list/saved_elevator_panels

/datum/unit_test/voidcrew_outpost_dock_needs_lift/Destroy()
	if(test_home && saved_elevator_panels)
		test_home.lobby_panels = saved_elevator_panels
	test_home = null
	saved_elevator_panels = null
	if(visitor_ship)
		visitor_ship.shuttle = null
		visitor_ship.dock_index = 0
	return ..()

/datum/unit_test/voidcrew_outpost_dock_needs_lift/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("liftlessowner")
	TEST_ASSERT_NOTNULL(home, "The liftless outpost did not load")
	test_home = home
	saved_elevator_panels = home.lobby_panels
	home.lobby_panels = list()
	TEST_ASSERT(!home.has_hangar_elevator(), "The claim still has a working hangar elevator")

	var/obj/docking_port/mobile/voidcrew/port = new(run_loc_floor_bottom_left)
	fake_ports += port
	port.width = 5
	port.height = 5
	port.dwidth = 2
	port.dheight = 2
	port.port_direction = NORTH
	visitor_ship = allocate(/obj/structure/overmap/ship)
	visitor_ship.shuttle = port
	var/previous_state = visitor_ship.state
	var/mob/living/carbon/human/pilot = make_player(run_loc_floor_bottom_left, "liftlesspilot")

	home.ship_act(pilot, visitor_ship)
	for(var/datum/outpost_berth/berth as anything in home.berths)
		TEST_ASSERT_NULL(berth, "A refused dock left berth [berth?.berth_number] claimed")
	// A ship that never held a pad has a null index, one that handed its pad back has 0: either means none
	TEST_ASSERT(!visitor_ship.dock_index, "A refused dock left the ship holding pad index [visitor_ship.dock_index]")
	TEST_ASSERT_EQUAL(visitor_ship.state, previous_state, "A refused dock did not restore the ship's state")
	TEST_ASSERT_NULL(visitor_ship.docked, "The ship docked at a claim without a hangar lift")
	TEST_ASSERT(!home.concerned, "A refused dock left the outpost busy")
