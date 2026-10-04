/// Standard hangar berths refuse to extend a hull; ship bays (the base hangar area) allow it,
/// which voidcrew_construction_hangar covers.
/datum/unit_test/voidcrew_construction_berth
	parent_type = /datum/unit_test/voidcrew_hull_survey
	var/obj/machinery/computer/camera_advanced/base_construction/ship/automation_test/builder
	var/obj/docking_port/mobile/voidcrew/port
	var/area/voidcrew/outpost_hangar/berth/berth_area
	var/area/shuttle/voidcrew/hull_area
	/// The berth dock the hull stands on; its rect is the ground the berth was built for
	var/obj/docking_port/stationary/berth_dock

/datum/unit_test/voidcrew_construction_berth/Destroy()
	QDEL_NULL(builder)
	if(berth_dock)
		qdel(berth_dock, force = TRUE)
	berth_dock = null
	if(port)
		qdel(port, force = TRUE)
	port = null
	evacuate_area(hull_area)
	evacuate_area(berth_area)
	QDEL_NULL(hull_area)
	QDEL_NULL(berth_area)
	return ..()

/datum/unit_test/voidcrew_construction_berth/Run()
	TEST_ASSERT(reserved, "Could not reserve a test berth")
	reset_block()
	berth_area = new
	hull_area = new
	hull_area.setup("Construction test hull")
	for(var/turf/deck as anything in block(spot(2, 2), spot(10, 10)))
		deck.ChangeTurf(/turf/open/indestructible/dark/smooth_large, /turf/open/space)
		deck.change_area(get_area(deck), berth_area)
	port = new(spot(4, 3))
	port.register()
	port.dir = NORTH
	port.shuttle_areas = list()
	port.shuttle_areas[hull_area] = TRUE
	for(var/turf/hull as anything in block(spot(3, 3), spot(5, 5)))
		hull.place_on_top(/turf/open/floor/plating)
		hull.insert_baseturf(turf_type = /turf/baseturf_skipover/shuttle)
		hull.change_area(berth_area, hull_area)
		port.underlying_areas_by_turf[hull] = berth_area
	port.calculate_docking_port_information()
	builder = allocate(/obj/machinery/computer/camera_advanced/base_construction/ship/automation_test, spot(4, 4))
	builder.test_port = port
	var/mob/living/carbon/human/engineer = allocate(/mob/living/carbon/human/consistent, spot(4, 4))
	builder.test_operator = engineer
	builder.set_is_operational(TRUE)
	// Fork defines are included after the tests: queue, area construction and instant servos.
	builder.console_upgrades = (1<<6) | (1<<7) | (1<<9)
	var/obj/item/construction/rcd/internal/ship/rcd = builder.internal_rcd
	qdel(rcd.silo_mats)
	rcd.silo_mats = rcd.AddComponent(/datum/component/remote_materials, FALSE, TRUE)
	rcd.silo_link = TRUE
	var/datum/component/material_container/materials = rcd.silo_mats.mat_container
	materials.insert_amount_mat(1000, /datum/material/iron)
	materials.insert_amount_mat(100, /datum/material/titanium)

	var/turf/edge = spot(6, 4)
	// A standard berth: the hull may not grow onto the deck around it.
	TEST_ASSERT(!builder.can_move_to(edge), "The drone left the hull in a standard berth")
	TEST_ASSERT(!builder.can_build_at(edge), "A standard berth accepted hull construction")
	TEST_ASSERT(!rcd.can_build_floor(edge), "A standard berth accepted ship flooring")
	TEST_ASSERT_EQUAL(builder.get_expansion_denial(edge), "Unavailable in standard hangar parking.", "Standard berth refusal has the wrong message")
	TEST_ASSERT_NULL(builder.get_expansion_denial(spot(4, 4)), "The hull's own deck reported a berth refusal")
	TEST_ASSERT(!rcd.build_floor(edge, engineer), "Direct floor construction extended a hull in a standard berth")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 1000, "A refused berth floor still charged materials")
	builder.build_size = 1
	builder.turf_build_mode = "auto"
	TEST_ASSERT(!builder.queue_construction(edge, engineer), "Hangar flooring was queued in a standard berth")
	TEST_ASSERT_EQUAL(builder.queue_status, "Unavailable in standard hangar parking.", "The queue did not report the standard berth refusal")
	TEST_ASSERT(!isshuttleturf(edge), "A refused berth tile joined the hull")

	// Deck inside the berth's own landing rect is footprint the hull lost, not extension:
	// a breach handed back to the hangar must still be floored again.
	berth_dock = new(get_turf(port))
	berth_dock.dir = NORTH
	berth_dock.width = 3
	berth_dock.height = 3
	berth_dock.dwidth = 1
	berth_dock.dheight = 0
	TEST_ASSERT_EQUAL(port.get_docked(), berth_dock, "The test hull is not standing on its berth dock")
	TEST_ASSERT(!builder.can_build_at(edge), "Deck past the berth's landing rect accepted construction")
	berth_dock.width = 4 // the rect now reaches the edge tile, as if the hull had lost it
	TEST_ASSERT(builder.can_build_at(edge), "Lost footprint inside the berth's landing rect cannot be rebuilt")
	TEST_ASSERT(rcd.can_build_floor(edge), "Lost footprint inside the berth's landing rect cannot be floored")
	TEST_ASSERT_NULL(builder.get_expansion_denial(edge), "Lost footprint reported a berth refusal")
	qdel(berth_dock, force = TRUE)
	berth_dock = null

	// Ship bays use the base hangar area, where construction stays open.
	for(var/datum/map_template/bay_type as anything in outpost_style_maps(/datum/map_template/outpost_hangar/ship_bay))
		var/ship_bay_map = file2text(initial(bay_type.mappath))
		TEST_ASSERT(findtext(ship_bay_map, "/area/voidcrew/outpost_hangar"), "The [bay_type] map no longer uses the hangar area")
		TEST_ASSERT(!findtext(ship_bay_map, "/area/voidcrew/outpost_hangar/berth"), "The [bay_type] map uses the standard berth area, which refuses construction")
