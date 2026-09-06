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
	materials.insert_amount_mat(100, /datum/material/iron)
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

	// Multi-layer pipe placement must pay for each recoverable pipe it produces.
	var/obj/item/pipe_dispenser/internal/rpd = allocate(/obj/item/pipe_dispenser/internal)
	rpd.silo_mats = rpd.AddComponent(/datum/component/remote_materials, FALSE, TRUE)
	rpd.silo_link = TRUE
	rpd.pipe_layers = (1 << 1) | (1 << 2)
	rpd.silo_mats.mat_container.insert_amount_mat(50, /datum/material/iron)
	TEST_ASSERT(!rpd.check_pipe_materials(engineer), "One pipe's materials paid for two pipe layers")
	rpd.silo_mats.mat_container.insert_amount_mat(50, /datum/material/iron)
	TEST_ASSERT(rpd.use_pipe_materials(engineer), "Could not pay for both selected pipe layers")
	TEST_ASSERT_EQUAL(rpd.silo_mats.mat_container.get_material_amount(/datum/material/iron), 0, "Multi-layer pipe placement undercharged for its pipes")
