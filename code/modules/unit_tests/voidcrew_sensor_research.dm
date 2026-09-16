/// Radar upgrades must work with both ordinary and disk-backed onboard servers.
/datum/unit_test/voidcrew_sensor_research
	var/list/ports = list()
	var/list/original_areas = list()
	var/list/ship_areas = list()

/datum/unit_test/voidcrew_sensor_research/Destroy()
	for(var/obj/docking_port/mobile/voidcrew/port as anything in ports)
		port.current_ship.shuttle = null
		port.current_ship = null
		port.shuttle_areas = list()
		qdel(port, force = TRUE)
	for(var/turf/location as anything in original_areas)
		location.change_area(get_area(location), original_areas[location])
	QDEL_LIST(ship_areas)
	return ..()

/datum/unit_test/voidcrew_sensor_research/proc/make_ship(turf/location)
	var/area/shuttle/voidcrew/ship_area = new
	ship_areas += ship_area
	original_areas[location] = get_area(location)
	location.change_area(get_area(location), ship_area)
	var/obj/docking_port/mobile/voidcrew/port = new(location)
	ports += port
	port.width = 1
	port.height = 1
	port.dwidth = 0
	port.dheight = 0
	port.shuttle_areas = list()
	port.shuttle_areas[ship_area] = TRUE
	ship_area.shuttle_port = port
	port.register()
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	SSovermap.simulated_ships |= ship
	ship.shuttle = port
	port.current_ship = ship
	ship.state = "idle" // OVERMAP_SHIP_IDLE; fork defines follow unit test includes.
	return ship

/datum/unit_test/voidcrew_sensor_research/Run()
	var/turf/ship_turf = run_loc_floor_bottom_left
	var/turf/other_turf = get_step(ship_turf, EAST)
	var/obj/structure/overmap/ship/ship = make_ship(ship_turf)
	var/obj/structure/overmap/ship/other_ship = make_ship(other_turf)
	var/obj/machinery/rnd/server/server = allocate(/obj/machinery/rnd/server, ship_turf)
	var/datum/techweb/web = server.stored_research
	TEST_ASSERT_NOTNULL(web, "An ordinary R&D server must host its own research")
	TEST_ASSERT_EQUAL(get_research_service_site(server), ship, "The server fixture must be aboard its own ship")
	TEST_ASSERT_EQUAL(ship.find_research_web(), web, "Ship sensors ignored an ordinary onboard R&D server")
	TEST_ASSERT_NULL(other_ship.find_research_web(), "A neighboring ship inherited the ordinary server's research")
	TEST_ASSERT_EQUAL(ship.get_sensor_range(), 4, "Unresearched radar must start at four tiles")
	TEST_ASSERT(!ship.can_identify_ruins(), "Base radar identified ruins")
	TEST_ASSERT(!ship.can_scan_ships(), "Base radar tracked vessels")

	// Use the real research path. The radar IDs are literals because fork defines follow this file.
	TEST_ASSERT(web.research_node_id("radar_array", TRUE, FALSE, FALSE), "Could not research Radar Array")
	TEST_ASSERT_EQUAL(ship.get_sensor_range(), 6, "Radar Array did not extend ordinary-server sensors to six tiles")
	TEST_ASSERT(!ship.can_identify_ruins(), "Tier-one radar identified ruins")
	TEST_ASSERT(web.research_node_id("radar_array_advanced", TRUE, FALSE, FALSE), "Could not research Signal Analysis")
	TEST_ASSERT_EQUAL(ship.get_sensor_range(), 8, "Signal Analysis did not extend sensors to eight tiles")
	TEST_ASSERT(ship.can_identify_ruins(), "Signal Analysis did not identify ruins")
	TEST_ASSERT(!ship.can_scan_ships(), "Tier-two radar tracked vessels")
	TEST_ASSERT(web.research_node_id("radar_array_elite", TRUE, FALSE, FALSE), "Could not research Vessel Tracking")
	TEST_ASSERT_EQUAL(ship.get_sensor_range(), 10, "Vessel Tracking did not extend sensors to ten tiles")
	TEST_ASSERT(ship.can_scan_ships(), "Vessel Tracking did not enable ship tracking")

	// Moving a still-live web to another hull must invalidate the cached research immediately.
	server.forceMove(other_turf)
	TEST_ASSERT_NULL(ship.get_research_web(), "The original hull retained research after its server moved away")
	TEST_ASSERT_EQUAL(ship.get_sensor_range(), 4, "The original hull retained radar upgrades without its server")
	TEST_ASSERT_EQUAL(other_ship.get_sensor_range(), 10, "The receiving hull did not use its onboard server")
	server.forceMove(ship_turf)
	COOLDOWN_RESET(ship, research_web_search_cooldown)
	TEST_ASSERT_EQUAL(ship.get_sensor_range(), 10, "Returning the server did not restore radar upgrades")
	TEST_ASSERT_EQUAL(other_ship.get_sensor_range(), 4, "The other hull kept upgrades after the server left")

	// Preserve the existing preference for a local source disk over other available servers.
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, ship_turf)
	var/obj/machinery/rnd/server/ship/disk_server = allocate(/obj/machinery/rnd/server/ship, ship_turf)
	var/obj/item/computer_disk/ship_disk/disk = allocate(/obj/item/computer_disk/ship_disk)
	disk_server.attacked_by(disk, user)
	TEST_ASSERT_EQUAL(ship.get_research_web(), disk.stored_research, "A local source disk must retain priority over ordinary servers")
	TEST_ASSERT_EQUAL(ship.get_sensor_range(), 4, "Radar upgrades were incorrectly combined across independent research webs")
	TEST_ASSERT(disk.stored_research.research_node_id("radar_array", TRUE, FALSE, FALSE), "Could not research disk-backed Radar Array")
	TEST_ASSERT_EQUAL(ship.get_sensor_range(), 6, "Disk-backed radar upgrades stopped working")
	disk.forceMove(ship_turf)
	TEST_ASSERT_EQUAL(ship.get_research_web(), web, "Removing the source disk did not restore the ordinary onboard server")
	TEST_ASSERT_EQUAL(ship.get_sensor_range(), 10, "Fallback to the ordinary server lost its radar upgrades")
	qdel(server)
	TEST_ASSERT_NULL(ship.get_research_web(), "A deleted server remained available to ship sensors")
	TEST_ASSERT_EQUAL(ship.get_sensor_range(), 4, "Deleting the last server retained radar upgrades")

	// A relay may still hold a web between losing its connection and reconciliation.
	var/obj/machinery/rnd/server/relay/relay = allocate(/obj/machinery/rnd/server/relay, ship_turf)
	relay.stored_research = disk.stored_research
	TEST_ASSERT_NULL(ship.find_research_web(), "An unavailable relay was treated as an ordinary local server")
