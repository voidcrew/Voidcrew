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

/// Real overmap tiles and disk research drive the quote and completion paths.
/datum/unit_test/voidcrew_research_movement/survey_capabilities/rewards
	var/list/overmap_turfs = list()

/datum/unit_test/voidcrew_research_movement/survey_capabilities/rewards/Destroy()
	for(var/turf/open/overmap/tile as anything in overmap_turfs)
		tile.current_zone = null
		tile.ChangeTurf(overmap_turfs[tile])
	return ..()

/datum/unit_test/voidcrew_research_movement/survey_capabilities/rewards/proc/zone_tile(turf/location, zone_type)
	var/old_type = location.type
	var/turf/open/overmap/tile = location.ChangeTurf(/turf/open/overmap)
	overmap_turfs[tile] = old_type
	tile.current_zone = allocate(/datum/overmap_zone, zone_type)
	return tile

/datum/unit_test/voidcrew_research_movement/survey_capabilities/rewards/Run()
	TEST_ASSERT(setup_links(), "No local research disk exists for survey reward testing")
	var/obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test/map_gate_test/console = map_console()
	// Voidcrew zone defines are included later: green = 1, yellow = 2, red = 3.
	var/turf/green = zone_tile(get_step(run_loc_floor_bottom_left, NORTH), 1)
	var/turf/open/overmap/target_tile = zone_tile(get_step(green, EAST), 1)
	var/list/bases = list(
		/obj/structure/overmap/star = 250,
		/obj/structure/overmap/planet = 150,
		/obj/structure/overmap/space_ruin = 75,
		/obj/structure/overmap/event/emp = 100,
		/obj/structure/overmap/event/electric = 75,
		/obj/structure/overmap/event/meteor = 50,
		/obj/structure/overmap/event/nebula = 25, // SURVEY_NEBULA_BASE, including dangerous variants.
	)
	for(var/family in bases)
		for(var/variant_type in typesof(family))
			var/obj/structure/overmap/variant = variant_type
			var/expected = ispath(variant_type, /obj/structure/overmap/planet/empty) ? 0 : bases[family]
			TEST_ASSERT_EQUAL(initial(variant.survey_value), expected, "[variant_type] has an incorrect survey base")
	var/list/tier_multipliers = list(1, 1, 1.1, 1.25)
	var/list/zone_multipliers = list(1, 1.25, 1.5)
	for(var/tier in 1 to 4)
		learn_tiers(web, tier)
		for(var/zone in 1 to 3)
			target_tile.current_zone = allocate(/datum/overmap_zone, zone)
			for(var/family in bases)
				var/obj/structure/overmap/target = allocate(family, target_tile)
				if(istype(target, /obj/structure/overmap/planet))
					// Substitute surface generation only; record and reward code still runs.
					var/obj/structure/overmap/planet/planet = target
					planet.loaded = TRUE
				console.ship_port.current_ship.forceMove(target_tile)
				check_award(console, target, bases[family] * tier_multipliers[tier] * zone_multipliers[zone])
			// The ship stays in green while each remote storm is in the target's zone.
			console.ship_port.current_ship.forceMove(green)
			for(var/family in list(/obj/structure/overmap/event/emp, /obj/structure/overmap/event/electric))
				var/obj/structure/overmap/target = allocate(family, target_tile)
				TEST_ASSERT(console.is_survey_at_range(target), "Remote-storm fixture shares the ship's tile")
				check_award(console, target, bases[family] * tier_multipliers[tier] * zone_multipliers[zone] * 0.6)
	// Removing the disk must revoke its multiplier even without another UI refresh.
	var/obj/structure/overmap/star/star = allocate(/obj/structure/overmap/star, green)
	console.ship_port.current_ship.forceMove(green)
	server.source_code_hdd.forceMove(run_loc_floor_bottom_left)
	check_award(console, star, 250)
	// Printing is the boundary: fractional awards must survive both banking and notes.
	var/points_before = console.banked_points
	var/list/old_notes = list()
	for(var/obj/item/research_notes/notes in get_turf(console))
		old_notes += notes
	console.print_survey_notes(user)
	var/obj/item/research_notes/printed
	for(var/obj/item/research_notes/notes in get_turf(console))
		if(!(notes in old_notes))
			printed = notes
			allocated += notes
	TEST_ASSERT(printed, "Survey notes were not printed")
	TEST_ASSERT_EQUAL(printed.value, points_before, "Printing changed the banked research value")
	TEST_ASSERT_EQUAL(console.banked_points, 0, "Printing did not empty the banked research")

/datum/unit_test/voidcrew_research_movement/survey_capabilities/rewards/proc/check_award(obj/machinery/computer/camera_advanced/shuttle_docker/survey/launch_test/console, obj/structure/overmap/target, expected)
	console.test_candidates = list(target)
	var/list/quote = console.get_survey_value(target)
	TEST_ASSERT_EQUAL(quote["cash"], 0, "[target.type] quoted currency")
	TEST_ASSERT(abs(quote["points"] - expected) < 0.001, "[target.type] quoted [quote["points"]] research instead of [expected]")
	var/list/ui_data = console.ui_data(user)
	TEST_ASSERT(!("bankedCash" in ui_data), "Survey UI still exposes a cash balance")
	var/list/targets = ui_data["surveyTargets"]
	var/list/target_quote = targets[1]
	TEST_ASSERT(!("cash" in target_quote), "Survey target UI still exposes currency")
	TEST_ASSERT_EQUAL(target_quote["points"], quote["points"], "Target UI disagrees with the reward quote")
	var/points_before = console.banked_points
	console.survey_celestial_object(user, ref(target))
	TEST_ASSERT(console.survey_in_progress, "[target.type] could not start a survey")
	deltimer(console.survey_timer)
	console.complete_survey(target)
	TEST_ASSERT(abs(console.banked_points - points_before - expected) < 0.01, "[target.type] awarded different research from its quote")
	TEST_ASSERT(console.is_object_surveyed(target), "[target.type] completion did not retain the survey record")

/// Checkpoint snapshots preserve fittings, never a console's accumulated research.
/datum/unit_test/voidcrew_survey_checkpoint_points/Run()
	var/obj/machinery/computer/camera_advanced/shuttle_docker/survey/console = allocate(/obj/machinery/computer/camera_advanced/shuttle_docker/survey)
	console.banked_points = 123.75
	var/datum/ship_checkpoint/snapshot = allocate(/datum/ship_checkpoint)
	var/serialized = snapshot.atom_text(console)
	TEST_ASSERT(!findtext(serialized, "banked_points"), "Checkpoint serialized banked survey research")
	var/map_text = "//[DMM2TGM_MESSAGE]\n\"a\" = (\n[serialized],\n/turf/template_noop,\n/area/template_noop)\n\n(1,1,1) = {\"\na\n\"}\n"
	var/datum/parsed_map/parsed = allocate(/datum/parsed_map, map_text)
	var/turf/destination = run_loc_floor_top_right
	TEST_ASSERT(parsed.load(destination.x, destination.y, destination.z, crop_map = TRUE), "Checkpoint survey fitting could not be reconstructed")
	var/obj/machinery/computer/camera_advanced/shuttle_docker/survey/rebuilt = locate() in destination
	TEST_ASSERT(rebuilt && rebuilt != console, "Checkpoint did not create a new survey console")
	allocated += rebuilt
	SSatoms.InitializeAtoms(list(rebuilt))
	TEST_ASSERT_EQUAL(rebuilt.banked_points, 0, "Checkpoint reconstruction duplicated banked research")
	TEST_ASSERT_EQUAL(console.banked_points, 123.75, "Snapshot changed the original console's research")
