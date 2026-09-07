/// Complete real RCD actions without waiting; cancellation still passes through the normal action pipeline.
/obj/item/construction/rcd/internal/ship/refund_test
	var/cancel_build = FALSE
	var/disconnect_during_build = FALSE
	var/mode_during_build

/obj/item/construction/rcd/internal/ship/refund_test/build_delay(mob/user, delay, atom/target)
	if(disconnect_during_build)
		silo_link = FALSE
	if(!isnull(mode_during_build))
		mode = mode_during_build
	return !cancel_build

/datum/unit_test/voidcrew_construction_refunds/Run()
	var/obj/item/construction/rcd/internal/ship/refund_test/rcd = allocate(/obj/item/construction/rcd/internal/ship/refund_test)
	var/mob/living/carbon/human/engineer = allocate(/mob/living/carbon/human/consistent)
	rcd.silo_mats = rcd.AddComponent(/datum/component/remote_materials, FALSE, TRUE)
	rcd.silo_link = TRUE
	rcd.mode = RCD_DECONSTRUCT
	rcd.matter = 0
	var/datum/component/material_container/materials = rcd.silo_mats.mat_container
	TEST_ASSERT_NOTNULL(materials, "Test RCD needs a material container")

	// An empty silo must not prevent recycling, and the deposit must happen exactly once.
	var/obj/structure/girder/girder = allocate(/obj/structure/girder)
	rcd.mode_during_build = RCD_STRUCTURE
	rcd.rcd_create(girder, engineer)
	rcd.mode_during_build = null
	rcd.mode = RCD_DECONSTRUCT
	TEST_ASSERT(QDELETED(girder), "An empty silo prevented girder deconstruction")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 200, "Girder materials were not returned")
	var/list/deconstruct_data = list("[RCD_DESIGN_MODE]" = RCD_DECONSTRUCT)
	TEST_ASSERT(!rcd.apply_rcd_action(girder, engineer, deconstruct_data), "A deleted girder was recycled twice")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 200, "Repeated recycling duplicated materials")
	TEST_ASSERT_EQUAL(rcd.matter, 0, "Recycling changed the internal matter reserve")

	// The outer rcd_create() return value reports handled cancellation as success.
	// Neither cancellation nor a lost silo link should delete the target or deposit anything.
	girder = allocate(/obj/structure/girder)
	rcd.cancel_build = TRUE
	rcd.rcd_create(girder, engineer)
	TEST_ASSERT(!QDELETED(girder), "Cancelled deconstruction deleted the girder")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 200, "Cancelled deconstruction refunded materials")
	rcd.cancel_build = FALSE
	rcd.disconnect_during_build = TRUE
	rcd.rcd_create(girder, engineer)
	TEST_ASSERT(!QDELETED(girder), "Losing the silo during deconstruction deleted the girder")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 200, "A disconnected RCD refunded materials")
	rcd.disconnect_during_build = FALSE
	rcd.silo_link = TRUE
	qdel(girder)

	// A target may refuse demolition after all prechecks have passed.
	var/turf/open/floor/floor = get_step(run_loc_floor_bottom_left, EAST)
	var/old_rcd_proof = floor.rcd_proof
	floor.rcd_proof = TRUE
	rcd.rcd_create(floor, engineer)
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 200, "Failed floor demolition refunded materials")
	floor.rcd_proof = old_rcd_proof

	// Mixed-material walls must refund their actual recipe, independent of the UI selection.
	materials.insert_amount_mat(100, /datum/material/titanium)
	materials.insert_amount_mat(100, /datum/material/plasma)
	rcd.selected_wall_type = "Plastitanium Wall"
	TEST_ASSERT(rcd.build_wall(floor, engineer), "Could not build the mixed-material test wall")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/titanium), 0, "Wall did not consume titanium")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/plasma), 0, "Wall did not consume plasma")
	rcd.selected_wall_type = "Iron Wall"
	var/turf/wall = get_step(run_loc_floor_bottom_left, EAST)
	rcd.rcd_create(wall, engineer)
	TEST_ASSERT(isfloorturf(get_step(run_loc_floor_bottom_left, EAST)), "Wall demolition did not preserve the floor")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/titanium), 100, "Wall did not return titanium")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/plasma), 100, "Wall did not return plasma")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 200, "Wall refund incorrectly used the selected iron recipe")

	// Catwalk rcd_act must accept the RCD data list and actually delete the catwalk.
	var/obj/structure/lattice/catwalk/catwalk = allocate(/obj/structure/lattice/catwalk)
	rcd.rcd_create(catwalk, engineer)
	TEST_ASSERT(QDELETED(catwalk), "Catwalk demolition failed")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 250, "Catwalk materials were not returned")

	// At the bottom of the stack, ScrapeAway returns the existing turf. That is not salvage.
	floor = get_step(run_loc_floor_bottom_left, EAST)
	var/old_baseturfs = floor.baseturfs
	floor.baseturfs = floor.type
	rcd.rcd_create(floor, engineer)
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 250, "An unchanged floor generated materials")
	floor.baseturfs = old_baseturfs

	// Memory-discounted rebuilding must still cost material if the UI switches to demolition,
	// and recycling the finished window must not generate more iron than that build consumed.
	var/old_memory = floor.rcd_memory
	floor.rcd_memory = RCD_MEMORY_WINDOWGRILLE
	rcd.mode = RCD_WINDOWGRILLE
	rcd.rcd_design_path = /obj/structure/window
	rcd.mode_during_build = RCD_DECONSTRUCT
	rcd.rcd_create(floor, engineer)
	rcd.mode_during_build = null
	var/obj/structure/window/window = locate() in floor
	TEST_ASSERT_NOTNULL(window, "Could not build a discounted window")
	TEST_ASSERT(materials.get_material_amount(/datum/material/iron) < 250, "Switching mode during construction made the build free")
	rcd.rcd_create(window, engineer)
	TEST_ASSERT(QDELETED(window), "Could not recycle the discounted window")
	TEST_ASSERT(materials.get_material_amount(/datum/material/iron) <= 250, "Discounted rebuilding and recycling generated iron")
	floor.rcd_memory = old_memory

	// Hull windows are laid grille and all in one action and paid for by recipe, so they
	// have to come back as that recipe - the generic window salvage would hand back a
	// couple of units of iron for a tile of plastitanium.
	floor = get_step(run_loc_floor_bottom_left, EAST)
	var/glass_before_window = materials.get_material_amount(/datum/material/glass)
	var/titanium_before_window = materials.get_material_amount(/datum/material/titanium)
	var/plasma_before_window = materials.get_material_amount(/datum/material/plasma)
	var/iron_before_window = materials.get_material_amount(/datum/material/iron)
	materials.insert_amount_mat(200, /datum/material/glass)
	materials.insert_amount_mat(100, /datum/material/titanium)
	materials.insert_amount_mat(100, /datum/material/plasma)
	materials.insert_amount_mat(200, /datum/material/iron)
	rcd.mode = RCD_WINDOWGRILLE
	rcd.construction_mode = RCD_WINDOWGRILLE
	rcd.rcd_design_path = /obj/structure/window/reinforced/plasma/plastitanium
	TEST_ASSERT(rcd.is_hull_window(rcd.rcd_design_path), "Plastitanium windows are not hull windows")
	TEST_ASSERT(rcd.build_hull_window(floor, engineer), "Could not build a hull window")
	var/obj/structure/window/hull_window = locate() in floor
	TEST_ASSERT_NOTNULL(hull_window, "Building a hull window produced no window")
	TEST_ASSERT_NOTNULL(locate(/obj/structure/grille) in floor, "A hull window was built without its grille")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/glass), glass_before_window, "Hull window did not consume glass")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/titanium), titanium_before_window, "Hull window did not consume titanium")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/plasma), plasma_before_window, "Hull window did not consume plasma")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_before_window, "Hull window did not consume iron")

	rcd.mode = RCD_DECONSTRUCT
	rcd.rcd_create(hull_window, engineer)
	TEST_ASSERT(QDELETED(hull_window), "Could not recycle a hull window")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/glass), glass_before_window + 200, "Hull window did not return its glass")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/titanium), titanium_before_window + 100, "Hull window did not return its titanium")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/plasma), plasma_before_window + 100, "Hull window did not return its plasma")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_before_window + 100, "Hull window did not return its iron")
	var/obj/structure/grille/hull_grille = locate() in floor
	hull_grille.deconstruct(TRUE)
	var/obj/item/stack/rods/rods = locate() in floor
	TEST_ASSERT_NOTNULL(rods, "Hull grille did not return rods")
	TEST_ASSERT_EQUAL(rods.amount, 2, "Hull grille salvage changed")
	materials.insert_amount_mat(rods.amount * SHEET_MATERIAL_AMOUNT / 2, /datum/material/iron)
	qdel(rods)
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_before_window + 200, "Hull window and hand-dismantled grille generated iron")
	for(var/cycle in 1 to 3)
		var/iron_before_cycle = materials.get_material_amount(/datum/material/iron)
		TEST_ASSERT(rcd.build_hull_window(floor, engineer), "Could not repeat hull-window construction")
		hull_window = locate() in floor
		hull_grille = locate() in floor
		rcd.rcd_create(hull_window, engineer)
		rcd.rcd_create(hull_grille, engineer)
		TEST_ASSERT(QDELETED(hull_grille), "Could not recycle the hull grille")
		TEST_ASSERT(materials.get_material_amount(/datum/material/iron) <= iron_before_cycle, "Hull window and RCD-recycled grille generated iron")

/// A small set of hull doors, leaving fan placement and resource handling on the real console.
/obj/machinery/computer/camera_advanced/base_construction/ship/fan_cost_test
	var/obj/docking_port/mobile/test_port
	var/list/test_fan_turfs = list()

/obj/machinery/computer/camera_advanced/base_construction/ship/fan_cost_test/Destroy()
	if(test_port)
		qdel(test_port, force = TRUE)
	test_port = null
	test_fan_turfs = null
	return ..()

/obj/machinery/computer/camera_advanced/base_construction/ship/fan_cost_test/can_operate()
	return TRUE

/obj/machinery/computer/camera_advanced/base_construction/ship/fan_cost_test/get_docking_port()
	return test_port

/obj/machinery/computer/camera_advanced/base_construction/ship/fan_cost_test/get_fan_turfs()
	return test_fan_turfs

/datum/unit_test/voidcrew_fan_costs/Run()
	var/obj/machinery/computer/camera_advanced/base_construction/ship/fan_cost_test/builder = allocate(/obj/machinery/computer/camera_advanced/base_construction/ship/fan_cost_test)
	builder.test_port = new(run_loc_floor_bottom_left)
	builder.test_port.register()
	builder.test_port.shuttle_areas = list(get_area(builder) = TRUE)
	var/turf/first_door = get_step(run_loc_floor_bottom_left, EAST)
	var/turf/second_door = get_step(first_door, EAST)
	var/turf/third_door = get_step(second_door, EAST)
	builder.test_fan_turfs = list(first_door, second_door, third_door)
	var/obj/structure/fans/tiny/existing = allocate(/obj/structure/fans/tiny, first_door)
	var/obj/structure/fans/tiny/interior = allocate(/obj/structure/fans/tiny, run_loc_floor_bottom_left)
	var/obj/item/construction/rcd/internal/ship/rcd = builder.internal_rcd
	qdel(rcd.silo_mats)
	rcd.silo_mats = rcd.AddComponent(/datum/component/remote_materials, FALSE, TRUE)
	rcd.silo_link = TRUE
	var/datum/component/material_container/materials = rcd.silo_mats.mat_container
	TEST_ASSERT_NOTNULL(materials, "Test console needs material storage")

	// An incomplete payment must not clear any fans or build only part of the set.
	materials.insert_amount_mat(3 * SHEET_MATERIAL_AMOUNT, /datum/material/iron)
	TEST_ASSERT(!builder.reset_fans(), "Three sheets paid for two missing fans")
	TEST_ASSERT(!QDELETED(existing) && !QDELETED(interior), "Failed reset removed an existing fan")
	TEST_ASSERT_NULL(locate(/obj/structure/fans/tiny) in second_door, "Failed reset built a partial set of fans")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 3 * SHEET_MATERIAL_AMOUNT, "Failed reset consumed iron")

	materials.insert_amount_mat(SHEET_MATERIAL_AMOUNT, /datum/material/iron)
	TEST_ASSERT(builder.reset_fans(), "Four sheets did not pay for two missing fans")
	TEST_ASSERT(!QDELETED(existing), "Reset replaced a correctly placed fan")
	TEST_ASSERT(QDELETED(interior), "Reset left a misplaced fan inside the ship")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 0, "Reset did not charge two sheets per new fan")
	var/obj/structure/fans/tiny/built = locate() in second_door
	TEST_ASSERT_NOTNULL(built, "Reset did not build the second fan")
	TEST_ASSERT_NOTNULL(locate(/obj/structure/fans/tiny) in third_door, "Reset did not build the third fan")
	TEST_ASSERT(builder.reset_fans(), "An unchanged set of fans required another payment")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 0, "Repeated reset generated iron")

	// Reproduce the reported loop: recover the sheets and feed them back into construction.
	built.deconstruct(TRUE)
	var/obj/item/stack/sheet/iron/salvage = locate() in second_door
	TEST_ASSERT_NOTNULL(salvage, "Fan disassembly returned no iron")
	TEST_ASSERT_EQUAL(salvage.amount, 2, "Fan disassembly did not return two sheets")
	materials.insert_amount_mat(salvage.amount * SHEET_MATERIAL_AMOUNT, /datum/material/iron)
	qdel(salvage)
	rcd.silo_link = FALSE
	TEST_ASSERT(!builder.reset_fans(), "Reset built a fan without a silo link")
	TEST_ASSERT_NULL(locate(/obj/structure/fans/tiny) in second_door, "Disconnected reset built a free fan")
	rcd.silo_link = TRUE
	TEST_ASSERT(builder.reset_fans(), "Recovered sheets could not rebuild their fan")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 0, "Disassembling and resetting a fan generated iron")

	// Automatic port seating must not bypass the paid reset by supplying salvageable fans.
	var/turf/port_turf = get_step(third_door, EAST)
	var/obj/structure/fans/tiny/safety = hull_seat_port_fan(builder.test_port, port_turf, null)
	TEST_ASSERT_NOTNULL(safety, "Port seating did not seal its door")
	safety.deconstruct(TRUE)
	TEST_ASSERT_NULL(locate(/obj/item/stack/sheet/iron) in port_turf, "Unpaid port seating generated iron salvage")
	safety = hull_seat_port_fan(builder.test_port, port_turf, null)
	TEST_ASSERT_NULL(safety.buildstacktype, "Repeated port seating restored iron salvage")
