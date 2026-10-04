/// Substitute map loading/rendering only; the real map action and research checks run.
/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test/map_gate_test
	var/map_refreshes = 0

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test/map_gate_test/refresh(mob/user)
	map_refreshes++

/datum/unit_test/voidcrew_research_movement/survey_capabilities
	abstract_type = /datum/unit_test/voidcrew_research_movement/survey_capabilities
	var/list/test_ports = list()

/datum/unit_test/voidcrew_research_movement/survey_capabilities/Destroy()
	for(var/obj/docking_port/mobile/voidcrew/port as anything in test_ports)
		port.current_ship = null
		port.shuttle_areas = list()
		qdel(port, force = TRUE)
	return ..()

/datum/unit_test/voidcrew_research_movement/survey_capabilities/proc/learn_tiers(datum/techweb/research, highest = 4)
	var/list/nodes = list("survey_console", "survey_console_advanced", "survey_console_superior", "survey_console_elite")
	for(var/index in 1 to highest)
		research.research_node_id(nodes[index], TRUE, FALSE, FALSE)

/datum/unit_test/voidcrew_research_movement/survey_capabilities/proc/map_console()
	var/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test/map_gate_test/console = allocate(/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test/map_gate_test)
	var/obj/docking_port/mobile/voidcrew/port = new(run_loc_floor_bottom_left)
	port.width = 1
	port.height = 1
	port.dwidth = 0
	port.dheight = 0
	port.register()
	test_ports += port
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	port.current_ship = ship
	console.ship_port = port
	var/obj/structure/overmap/star/star = allocate(/obj/structure/overmap/star)
	ship.close_overmap_objects = list(star)
	console.test_candidates = list(star)
	console.link_to_techweb(web)
	return console

/datum/unit_test/voidcrew_research_movement/survey_capabilities/relink/Run()
	TEST_ASSERT(setup_links(), "No physical disk exists for survey capability testing")
	learn_tiers(web)
	var/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test/console = allocate(/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test)
	console.link_to_techweb(web)
	console.get_survey_research_tiers()
	TEST_ASSERT(console.mapping_enabled && console.mob_sight && console.obj_sight, "Learned elite survey capabilities were not available")
	var/obj/machinery/rnd/server/ship/lower_server = allocate(/obj/machinery/rnd/server/ship)
	var/obj/item/computer_disk/ship_disk/lower_disk = allocate(/obj/item/computer_disk/ship_disk)
	lower_server.attacked_by(lower_disk, user)
	learn_tiers(lower_disk.stored_research, 2)
	TEST_ASSERT(console.link_to_techweb(lower_disk.stored_research), "Local lower-tier disk could not connect")
	TEST_ASSERT(console.mapping_enabled, "Changing to an advanced disk removed its legitimate mapping unlock")
	TEST_ASSERT(!console.obj_sight && !console.mob_sight, "Lower-tier disk inherited elite sight capabilities")
	TEST_ASSERT_EQUAL(console.view_range, 10, "Lower-tier disk inherited elite view range")
	console.link_to_techweb(web)
	console.get_survey_research_tiers()
	var/mob/eye/camera/remote/shuttle_docker/eye = allocate(/mob/eye/camera/remote/shuttle_docker, run_loc_floor_bottom_left, console)
	console.eyeobj = eye
	console.current_user = user // A disconnected operator must also be released on revocation.
	console.link_to_techweb(web)
	TEST_ASSERT_EQUAL(console.current_user, user, "Repeated valid linking interrupted the same authorized map")
	TEST_ASSERT_EQUAL(console.eyeobj, eye, "Repeated valid linking discarded the authorized map eye")
	var/obj/item/computer_disk/ship_disk/disk = server.source_code_hdd
	disk.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_NULL(console.current_user, "Disk removal left the survey map occupied")
	TEST_ASSERT_NULL(console.eyeobj, "Disk removal retained an active survey map eye")
	TEST_ASSERT(!console.mapping_enabled && !console.obj_sight && !console.mob_sight, "Physical disk removal retained survey capabilities")
	TEST_ASSERT_EQUAL(console.view_range, initial(console.view_range), "Physical disk removal retained enhanced view range")
	server.attacked_by(disk, user)
	TEST_ASSERT(console.link_to_techweb(web), "Reinserted local disk could not reconnect")
	TEST_ASSERT(console.mapping_enabled && console.obj_sight && console.mob_sight, "Reinsertion did not restore learned survey capabilities")

/datum/unit_test/voidcrew_research_movement/survey_capabilities/movement/Run()
	TEST_ASSERT(setup_links(), "No separate site exists for survey capability movement testing")
	learn_tiers(web)
	for(var/move_server in list(FALSE, TRUE))
		check_movement(move_server)
		server.forceMove(run_loc_floor_bottom_left)

/datum/unit_test/voidcrew_research_movement/survey_capabilities/movement/proc/check_movement(move_server)
	var/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test/console = allocate(/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test)
	console.link_to_techweb(web)
	console.get_survey_research_tiers()
	move_apart(console, move_server)
	console.get_survey_research_tiers()
	TEST_ASSERT_NULL(console.linked_techweb, "Foreign research link survived capability validation")
	TEST_ASSERT(!console.mapping_enabled && !console.obj_sight && !console.mob_sight, "Foreign disk retained survey capabilities (server moved: [move_server])")

/datum/unit_test/voidcrew_research_movement/survey_capabilities/map_action/Run()
	TEST_ASSERT(setup_links(), "No local disk exists for survey map action testing")
	var/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test/map_gate_test/console = map_console()
	// Forged actions must fail before loading a celestial map, even without a connected client.
	console.activate_survey_map(user)
	TEST_ASSERT_EQUAL(console.map_refreshes, 0, "An unresearched direct map action reached map loading")
	var/datum/tgui/ui = allocate(/datum/tgui, user, console, "SurveyComputer")
	console.ui_act("map", list(), ui)
	TEST_ASSERT_EQUAL(console.map_refreshes, 0, "An unresearched TGUI map action reached map loading")
	learn_tiers(web, 2)
	console.activate_survey_map(user)
	TEST_ASSERT_EQUAL(console.map_refreshes, 1, "An authorized mapping action could not reach map loading")
	TEST_ASSERT(console.mapping_enabled, "Authorized map action did not resolve its learned mapping capability")
	server.source_code_hdd.forceMove(run_loc_floor_bottom_left)
	console.ui_act("map", list(), ui)
	TEST_ASSERT_EQUAL(console.map_refreshes, 1, "A removed disk authorized another map action")

/datum/unit_test/voidcrew_research_movement/survey_capabilities/debug_override/Run()
	TEST_ASSERT(setup_links(), "No physical fixture exists for survey debug testing")
	var/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test/map_gate_test/console = map_console()
	console.debug_mode = TRUE
	console.unsync_research_servers()
	var/list/tiers = console.get_survey_research_tiers()
	TEST_ASSERT("elite" in tiers, "Explicit survey debug override lost its elite tier")
	TEST_ASSERT(console.mapping_enabled && console.obj_sight && console.mob_sight, "Explicit debug override lost its sight capabilities")
	console.activate_survey_map(user)
	TEST_ASSERT_EQUAL(console.map_refreshes, 1, "Explicit debug override could not reach map loading without a disk")
