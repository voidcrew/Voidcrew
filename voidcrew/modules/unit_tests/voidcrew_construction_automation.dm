/// Keep the real placement/material/damage-journal code, with a small test ship and crew.
/obj/machinery/computer/camera_advanced/base_construction/ship/automation_test
	var/obj/docking_port/mobile/test_port
	var/mob/test_operator
	var/test_docked = TRUE

/obj/machinery/computer/camera_advanced/base_construction/ship/automation_test/can_operate()
	return test_docked

/obj/machinery/computer/camera_advanced/base_construction/ship/automation_test/is_crew_member(mob/user)
	return user == test_operator

/obj/machinery/computer/camera_advanced/base_construction/ship/automation_test/get_docking_port()
	return test_port

/obj/machinery/computer/camera_advanced/base_construction/ship/automation_test/Destroy()
	test_port = null
	test_operator = null
	return ..()

/datum/unit_test/voidcrew_construction_automation
	var/obj/machinery/computer/camera_advanced/base_construction/ship/automation_test/builder
	var/obj/docking_port/mobile/voidcrew/port
	var/obj/item/construction/rcd/internal/ship/rcd
	var/datum/component/material_container/materials
	var/mob/living/carbon/human/engineer

/datum/unit_test/voidcrew_construction_automation/Destroy()
	if(builder)
		builder.clear_repair_journal(TRUE)
		builder.test_port = null
	if(port)
		qdel(port, force = TRUE)
	port = null
	builder = null
	rcd = null
	materials = null
	engineer = null
	return ..()

/datum/unit_test/voidcrew_construction_automation/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/datum/unit_test/voidcrew_construction_automation/Run()
	builder = allocate(/obj/machinery/computer/camera_advanced/base_construction/ship/automation_test)
	engineer = allocate(/mob/living/carbon/human/consistent)
	builder.test_operator = engineer
	builder.set_is_operational(TRUE)
	port = new(spot(0, 0))
	port.register()
	port.shuttle_areas = list(get_area(builder) = TRUE)
	builder.test_port = port
	// Fork defines occur later than the test includes: instant and repair flags.
	builder.console_upgrades = (1<<9) | (1<<10)
	var/obj/item/ship_construction_upgrade/area/area_disk = allocate(/obj/item/ship_construction_upgrade/area)
	builder.item_interaction(engineer, area_disk, list())
	TEST_ASSERT(QDELETED(area_disk), "Area construction could not install without a queue disk")
	builder.update_build_speed()
	rcd = builder.internal_rcd
	qdel(rcd.silo_mats)
	rcd.silo_mats = rcd.AddComponent(/datum/component/remote_materials, FALSE, TRUE)
	rcd.silo_link = TRUE
	materials = rcd.silo_mats.mat_container
	TEST_ASSERT_NOTNULL(materials, "Test console has no material container")
	materials.insert_amount_mat(10000, /datum/material/iron)
	materials.insert_amount_mat(10000, /datum/material/glass)
	materials.insert_amount_mat(10000, /datum/material/titanium)
	materials.insert_amount_mat(10000, /datum/material/plasma)
	materials.insert_amount_mat(1000, /datum/material/plastic)
	TEST_ASSERT_EQUAL(rcd.get_build_speed_mod(), 0, "Instant speed was replaced by the default multiplier")
	TEST_ASSERT_EQUAL(rcd.delay_mod, 0, "Generic RCD jobs did not inherit instant speed")

	// A 3x3 stroke, then one tile left: exactly twelve floors and twelve charges.
	for(var/dx in 1 to 4)
		for(var/dy in 2 to 4)
			var/turf/tile = spot(dx, dy)
			tile.ChangeTurf(/turf/open/space)
	builder.build_size = 3
	builder.turf_build_mode = "floor"
	builder.queue_enabled = TRUE
	var/iron_before = materials.get_material_amount(/datum/material/iron)
	TEST_ASSERT(builder.queue_construction(spot(3, 3), engineer), "Could not queue the first brush")
	TEST_ASSERT_EQUAL(length(builder.construction_queue), 9, "3x3 did not enqueue nine cells")
	builder.queue_construction(spot(3, 3), engineer)
	TEST_ASSERT_EQUAL(length(builder.construction_queue), 9, "Duplicate stroke duplicated queued work")
	// UI changes after enqueue must not change the job's floor material.
	rcd.selected_floor_type = "Titanium Floor"
	builder.process_construction_queue()
	TEST_ASSERT_EQUAL(length(builder.construction_queue), 0, "Instant stroke did not finish")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_before - 900, "First brush did not charge exactly nine floors")
	TEST_ASSERT_EQUAL(spot(3, 3).type, /turf/open/floor/plating, "Changing blueprints changed a queued job")
	rcd.selected_floor_type = "Plating"
	builder.queue_construction(spot(2, 3), engineer)
	TEST_ASSERT_EQUAL(length(builder.construction_queue), 3, "Overlapping brush did not skip six completed cells")
	builder.process_construction_queue()
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_before - 1200, "Overlapping stroke wasted material")
	for(var/dx in 1 to 4)
		for(var/dy in 2 to 4)
			TEST_ASSERT(isfloorturf(spot(dx, dy)), "Overlapping floor brush turned a floor into a wall")

	// A job becoming complete before execution must neither build nor charge again.
	builder.build_size = 1
	builder.turf_build_mode = "wall"
	builder.queue_construction(spot(2, 3), engineer)
	var/turf/target = spot(2, 3)
	target.place_on_top(/turf/closed/wall)
	iron_before = materials.get_material_amount(/datum/material/iron)
	builder.process_construction_queue()
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_before, "Already completed job spent resources")

	// Unavailable ships and paused queues cannot complete work.
	builder.queue_construction(spot(3, 3), engineer)
	builder.test_docked = FALSE
	builder.process_construction_queue()
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_before, "Queue built while the ship was unavailable")
	builder.test_docked = TRUE
	builder.queue_paused = TRUE
	builder.process_construction_queue()
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_before, "Paused queue spent resources")
	builder.clear_construction_queue()
	builder.queue_paused = FALSE

	// Tile placement snapshots the chosen finish and skips overlapping finished floors.
	builder.internal_rtd = new(builder)
	builder.internal_rtd.ship_console = builder
	var/datum/ship_construction_job/tile_job = builder.capture_construction_job(spot(3, 3), engineer, "floor", "tile")
	TEST_ASSERT(builder.complete_decoration_job(tile_job, spot(3, 3), engineer), "Tile placer did not lay its selected tile")
	iron_before = materials.get_material_amount(/datum/material/iron)
	TEST_ASSERT(!builder.complete_decoration_job(tile_job, spot(3, 3), engineer), "Tile placer rebuilt an existing floor")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_before, "Duplicate tile placement spent material")
	qdel(tile_job)
	test_tile_replacement()
	test_damage_repairs()

	// Decal duplicate detection reads the actual turf, not a per-console history cache.
	builder.internal_painter = new(builder)
	builder.internal_painter.ship_console = builder
	var/datum/ship_construction_job/paint_job = builder.capture_construction_job(spot(3, 3), engineer, "floor", "decal")
	var/plastic_before = materials.get_material_amount(/datum/material/plastic)
	rcd.silo_link = FALSE
	TEST_ASSERT(builder.complete_decoration_job(paint_job, spot(3, 3), engineer), "Decal painter failed")
	rcd.silo_link = TRUE
	var/plastic_after = materials.get_material_amount(/datum/material/plastic)
	TEST_ASSERT_EQUAL(plastic_after, plastic_before, "Free decal painting consumed plastic")
	var/turf/painted = spot(3, 3)
	var/list/appearances = islist(painted.managed_overlays) ? painted.managed_overlays : list(painted.managed_overlays)
	var/list/observed = list()
	for(var/mutable_appearance/overlay as anything in appearances)
		observed += list(list("icon" = "[overlay.icon]", "state" = overlay.icon_state, "dir" = overlay.dir, "color" = overlay.color, "alpha" = overlay.alpha))
	TEST_ASSERT(!builder.complete_decoration_job(paint_job, painted, engineer), "Duplicate decal was painted: picker [json_encode(paint_job.decal_data)], actual [json_encode(observed)]")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/plastic), plastic_after, "Duplicate decal consumed pigment")
	test_decal_removal(paint_job)
	qdel(paint_job)
	test_free_piping()
	test_drone_clicks()
	test_queue_supply_and_failure()

/datum/unit_test/voidcrew_construction_automation/proc/test_decal_removal(datum/ship_construction_job/paint_job)
	var/turf/painted = spot(3, 3)
	var/turf/neighbor = spot(4, 3)
	var/floor_type = painted.type
	// Mapped markings and a directionless decal must be removed alongside the painted one.
	new /obj/effect/turf_decal(painted)
	painted.AddElement(/datum/element/decal, 'icons/turf/decals.dmi', "warningline", NONE)
	// The same shared element on another tile must survive removal here.
	TEST_ASSERT(builder.complete_decoration_job(paint_job, neighbor, engineer), "Could not paint neighboring floor")
	painted.AddElement(/datum/element/decal, 'icons/effects/crayondecal.dmi', "star", EAST, _cleanable = CLEAN_TYPE_HARD_DECAL)
	var/list/decals = list()
	SEND_SIGNAL(painted, COMSIG_ATOM_GET_DECALS, decals)
	var/datum/element/decal/preserved = decals[length(decals)]
	TEST_ASSERT_EQUAL(length(builder.construction_floor_decals(painted)), 3, "Mapped and directionless decals were not found")
	var/iron_before = materials.get_material_amount(/datum/material/iron)
	var/plastic_before = materials.get_material_amount(/datum/material/plastic)
	builder.build_size = 1
	builder.queue_enabled = FALSE
	rcd.silo_link = FALSE
	TEST_ASSERT(builder.decorate_turf(painted, engineer, "decal_remove"), "Direct decal removal required a silo")
	TEST_ASSERT_EQUAL(painted.type, floor_type, "Removing decals changed the floor")
	TEST_ASSERT_EQUAL(length(builder.construction_floor_decals(painted)), 0, "Floor markings remained attached")
	TEST_ASSERT_EQUAL(length(builder.construction_floor_decals(neighbor)), 1, "Removing a shared decal affected another tile")
	decals.Cut()
	SEND_SIGNAL(painted, COMSIG_ATOM_GET_DECALS, decals)
	TEST_ASSERT((length(decals) == 1) && (preserved in decals), "Removal detached an unrelated decal")
	TEST_ASSERT(painted._listen_lookup?[COMSIG_ATOM_DIR_CHANGE], "Remaining decal lost its rotation handler")
	preserved.Detach(painted)
	painted.update_appearance(UPDATE_OVERLAYS)
	TEST_ASSERT(!builder.decorate_turf(painted, engineer, "decal_remove"), "An empty tile was treated as removable")
	TEST_ASSERT(builder.complete_decoration_job(paint_job, painted, engineer), "Could not repaint immediately after removal")
	// Area removal skips blank tiles and rechecks jobs if another action already clears them.
	builder.build_size = 3
	builder.queue_enabled = TRUE
	TEST_ASSERT(builder.decorate_turf(painted, engineer, "decal_remove"), "Could not queue area decal removal")
	TEST_ASSERT_EQUAL(length(builder.construction_queue), 2, "Area removal queued undecorated floors")
	var/datum/ship_construction_job/job = builder.construction_queue[1]
	TEST_ASSERT_EQUAL(job.kind, "decal_remove", "Removal became a construction job")
	TEST_ASSERT(builder.complete_decoration_job(job, painted, engineer), "Could not clear a tile before its queued removal")
	builder.process_construction_queue()
	TEST_ASSERT_EQUAL(length(builder.construction_queue), 0, "Area removal retained a completed or empty job")
	TEST_ASSERT_EQUAL(length(builder.construction_floor_decals(neighbor)), 0, "Area removal left neighboring decals")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_before, "Decal removal changed iron reserves")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/plastic), plastic_before, "Decal removal changed plastic reserves")
	rcd.silo_link = TRUE
	builder.build_size = 1

/// Real RCD rejection must refund payment, and a depleted/disconnected silo retains jobs.
/datum/unit_test/voidcrew_construction_automation/proc/test_queue_supply_and_failure()
	var/turf/target = spot(4, 1)
	var/obj/machinery/door/window/windoor = allocate(/obj/machinery/door/window, target)
	windoor.set_density(FALSE)
	rcd.construction_mode = RCD_WINDOWGRILLE
	rcd.rcd_design_path = /obj/structure/window
	builder.build_size = 1
	TEST_ASSERT(builder.queue_construction(target, engineer), "Could not queue blocked directional window")
	var/datum/ship_construction_job/job = builder.construction_queue[1]
	job.build_dir = turn(windoor.dir, dir2angle(builder.queue_origin.dir))
	var/iron_before = materials.get_material_amount(/datum/material/iron)
	for(var/retry in 1 to 3)
		job.ready_at = world.time
		TEST_ASSERT(builder.can_build_at(target), "Blocked window target left the test ship")
		TEST_ASSERT(builder.construction_job_needed(job, target), "Blocked window was already satisfied")
		builder.process_construction_queue()
		TEST_ASSERT_EQUAL(length(builder.construction_queue), 1, "Blocked job was discarded: [builder.queue_status], target [target.type], window [locate(/obj/structure/window) in target]")
		TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_before, "Failed queued placement spent materials")
	TEST_ASSERT_NULL(locate(/obj/structure/window) in target, "Window overlapped an open windoor")
	builder.clear_construction_queue()
	qdel(windoor)

	// Two paid floors, then two waiting floors. Refill finishes exactly the latter pair.
	materials.use_amount_mat(materials.get_material_amount(/datum/material/iron), /datum/material/iron)
	materials.insert_amount_mat(200, /datum/material/iron)
	rcd.construction_mode = RCD_TURF
	rcd.rcd_design_path = /turf/open/floor/plating/rcd
	rcd.selected_floor_type = "Plating"
	builder.turf_build_mode = "floor"
	for(var/dx in 1 to 4)
		target = spot(dx, 5).ChangeTurf(/turf/open/space)
		TEST_ASSERT(builder.queue_construction(target, engineer), "Could not queue supply test floor")
	builder.process_construction_queue()
	TEST_ASSERT_EQUAL(length(builder.construction_queue), 2, "Out-of-material queue lost unfinished jobs")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 0, "Partial queue charged an incorrect amount")
	job = builder.construction_queue[1]
	job.ready_at = world.time
	builder.process_construction_queue()
	TEST_ASSERT_EQUAL(length(builder.construction_queue), 2, "Empty silo discarded a waiting job")
	materials.insert_amount_mat(200, /datum/material/iron)
	rcd.silo_link = FALSE
	job.ready_at = world.time
	builder.process_construction_queue()
	TEST_ASSERT_EQUAL(length(builder.construction_queue), 2, "Disconnected silo discarded jobs")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 200, "Disconnected silo spent materials")
	rcd.silo_link = TRUE
	job.ready_at = world.time
	builder.process_construction_queue()
	TEST_ASSERT_EQUAL(length(builder.construction_queue), 0, "Refilled queue failed to resume")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 0, "Resumed queue did not charge exactly the unfinished floors")
	// Temporary occupants must not turn a waiting wall into a discarded job.
	target = spot(4, 5)
	builder.turf_build_mode = "wall"
	TEST_ASSERT(builder.queue_construction(target, engineer), "Could not queue waiting wall")
	engineer.forceMove(target)
	materials.insert_amount_mat(200, /datum/material/iron)
	builder.process_construction_queue()
	TEST_ASSERT_EQUAL(length(builder.construction_queue), 1, "Occupant discarded a queued wall")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 200, "Occupied wall tile consumed material")
	engineer.forceMove(spot(3, 5))
	job = builder.construction_queue[1]
	job.ready_at = world.time
	builder.process_construction_queue()
	TEST_ASSERT_EQUAL(length(builder.construction_queue), 0, "Wall did not resume after occupant left")
	TEST_ASSERT(iswallturf(spot(4, 5)), "Resumed wall job built no wall")

/// Exercise the actual console actions, including multiple layers and removal without a silo.
/datum/unit_test/voidcrew_construction_automation/proc/test_free_piping()
	var/turf/target_turf = spot(1, 1)
	engineer.forceMove(target_turf)
	var/mob/eye/camera/remote/base_construction/eye = allocate(/mob/eye/camera/remote/base_construction, target_turf, builder)
	engineer.remote_control = eye
	builder.internal_rpd = new(builder)
	var/obj/item/pipe_dispenser/internal/rpd = builder.internal_rpd
	rpd.atmos_build_speed = 0
	rpd.mode = 1 // BUILD_MODE is private to RPD.dm; leave the pipes unwrenched.
	rpd.multi_layer = TRUE
	rpd.pipe_layers = (1 << 1) | (1 << 2)
	rcd.silo_link = FALSE
	var/iron_before = materials.get_material_amount(/datum/material/iron)
	builder.drone_place_pipe(engineer, target_turf)
	var/list/pipes = list()
	for(var/obj/item/pipe/pipe in target_turf)
		pipes += pipe
	TEST_ASSERT_EQUAL(length(pipes), 2, "Free piping did not build both layers without a silo")
	builder.drone_remove_pipe(engineer, target_turf)
	builder.drone_remove_pipe(engineer, target_turf)
	TEST_ASSERT_NULL(locate(/obj/item/pipe) in target_turf, "Free pipe removal required a silo link")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_before, "Free pipe placement or removal changed stored iron")
	rcd.silo_link = TRUE
	builder.drone_place_pipe(engineer, target_turf)
	builder.drone_remove_pipe(engineer, target_turf)
	builder.drone_remove_pipe(engineer, target_turf)
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_before, "Removing free pipes generated silo iron")
	engineer.remote_control = null

/// Clicks reach tiles around the drone, right-click removes, and modified clicks keep their meaning.
/datum/unit_test/voidcrew_construction_automation/proc/test_drone_clicks()
	var/mob/eye/camera/remote/base_construction/ship/eye = allocate(/mob/eye/camera/remote/base_construction/ship, spot(1, 1), builder)
	var/mob/living/carbon/human/other = allocate(/mob/living/carbon/human/consistent)
	builder.eyeobj = eye
	builder.current_user = engineer
	engineer.remote_control = eye
	builder.internal_rpd = builder.internal_rpd || new(builder)
	var/obj/item/pipe_dispenser/internal/rpd = builder.internal_rpd
	rpd.atmos_build_speed = 0
	rpd.mode = 1 // BUILD_MODE is private to RPD.dm; leave the pipes unwrenched.
	rpd.multi_layer = FALSE
	// The RPD builds every selected layer; test_free_piping leaves two selected. One pipe per click here.
	rpd.pipe_layers = (1 << 2)
	builder.selected_tool = "pipe" // SHIP_DRONE_TOOL_PIPE: fork defines occur later than the test includes
	// Earlier steps left these tiles in unknown states: use bare plating, and put back what was there.
	// The last eight are the wall-mount layout of test_wall_mount_choice().
	var/list/spots_used = list(spot(4, 0), spot(5, 1), spot(4, 1), spot(3, 1), spot(3, 2), spot(3, 3), spot(1, 3), spot(2, 3), spot(3, 4), spot(1, 4), spot(2, 4), spot(1, 5), spot(2, 5), spot(3, 5))
	var/list/original_types = list()
	for(var/turf/used as anything in spots_used)
		original_types[used] = used.type
		if(!isfloorturf(used))
			used.ChangeTurf(/turf/open/floor/plating)
	var/turf/drone_turf = spot(1, 1)
	var/turf/click_turf = spot(4, 0)

	// Left-click builds on the clicked tile, not under the drone. The piping test above left a click cooldown.
	engineer.next_move = 0
	TEST_ASSERT(builder.InterceptClickOn(engineer, "[LEFT_CLICK]=1", click_turf), "A click within reach was not taken")
	TEST_ASSERT_NOTNULL(locate(/obj/item/pipe) in click_turf, "Clicking a tile did not build on it")
	TEST_ASSERT_NULL(locate(/obj/item/pipe) in drone_turf, "Clicking a tile built under the drone")

	// Out of reach is consumed but does nothing.
	engineer.next_move = 0
	TEST_ASSERT(builder.InterceptClickOn(engineer, "[LEFT_CLICK]=1", spot(5, 1)), "A click out of reach fell through to the operator")
	TEST_ASSERT_NULL(locate(/obj/item/pipe) in spot(5, 1), "Built four tiles from the drone")

	// Right-click removes.
	engineer.next_move = 0
	TEST_ASSERT(builder.InterceptClickOn(engineer, "[RIGHT_CLICK]=1", click_turf), "A right-click within reach was not taken")
	TEST_ASSERT_NULL(locate(/obj/item/pipe) in click_turf, "Right-click did not remove the pipe")

	// Modified clicks and other people keep their usual meaning.
	engineer.next_move = 0
	TEST_ASSERT(!builder.InterceptClickOn(engineer, "[LEFT_CLICK]=1;[SHIFT_CLICK]=1", click_turf), "A shift-click was taken")
	TEST_ASSERT(!builder.InterceptClickOn(other, "[LEFT_CLICK]=1", click_turf), "Someone else's click was taken")

	// Wall mounting: a clicked wall is fitted on its face toward the drone.
	spot(3, 1).ChangeTurf(/turf/closed/wall)
	eye.abstract_move(spot(3, 3))
	var/list/mount = builder.drone_wall_mount(spot(3, 1))
	TEST_ASSERT_NOTNULL(mount, "No mounting side found for a wall north of it")
	TEST_ASSERT_EQUAL(mount[1], spot(3, 2), "Wall fixture went on the wrong tile")
	TEST_ASSERT_EQUAL(mount[2], SOUTH, "Wall fixture hung on the wrong wall")
	eye.abstract_move(spot(5, 1))
	mount = builder.drone_wall_mount(spot(3, 1))
	TEST_ASSERT_NOTNULL(mount, "No mounting side found for a wall to the west")
	TEST_ASSERT_EQUAL(mount[1], spot(4, 1), "Wall fixture from the east went on the wrong tile")
	TEST_ASSERT_EQUAL(mount[2], WEST, "Wall fixture from the east hung on the wrong wall")
	// An open tile uses the wall the drone faces.
	eye.abstract_move(spot(3, 3))
	eye.setDir(SOUTH)
	mount = builder.drone_wall_mount(spot(3, 2))
	TEST_ASSERT_NOTNULL(mount, "An open tile beside a wall found no mounting side")
	TEST_ASSERT_EQUAL(mount[1], spot(3, 2), "Open tile mount moved to another tile")
	TEST_ASSERT_EQUAL(mount[2], SOUTH, "Open tile mount ignored the drone's facing")
	eye.setDir(NORTH)
	TEST_ASSERT_NULL(builder.drone_wall_mount(spot(3, 2)), "Mounted on a wall the drone was not facing")

	// Where on the tile the operator clicked, and a chosen wall, decide where a fixture hangs.
	test_wall_mount_choice()
	test_light_settings(other)
	test_light_placement()

	for(var/turf/used as anything in spots_used)
		var/original_type = original_types[used]
		var/turf/current = locate(used.x, used.y, used.z)
		if(current.type != original_type)
			current.ChangeTurf(original_type)
	builder.eyeobj = null
	builder.current_user = null
	engineer.remote_control = null
	engineer.click_intercept = null

/// Laying a tile on a floor the tile tool can lift replaces it: the old tile is refunded and the new one charged.
/datum/unit_test/voidcrew_construction_automation/proc/test_tile_replacement()
	var/obj/item/construction/rtd/internal/rtd = builder.internal_rtd
	var/datum/tile_info/base_design = rtd.selected_design
	var/datum/tile_info/dark_design = GLOB.floor_designs["Decorated"]["Dark Colored"][1]["datum"]
	var/original_direction = rtd.selected_direction
	var/turf/target = spot(3, 3)
	var/original_type = target.type
	var/original_dir = target.dir
	var/list/stock = list()
	for(var/material in list(/datum/material/iron, /datum/material/titanium))
		stock[material] = materials.get_material_amount(material)
	check_tile_replacement(rtd, base_design, dark_design)
	// Put back what the checks changed, whether or not they finished.
	rtd.selected_design = base_design
	rtd.selected_direction = original_direction
	target = spot(3, 3)
	if(target.type != original_type)
		target = target.ChangeTurf(original_type)
	target.setDir(original_dir)
	for(var/material in stock)
		var/difference = stock[material] - materials.get_material_amount(material)
		if(difference > 0)
			materials.insert_amount_mat(difference, material)
		else if(difference < 0)
			materials.use_amount_mat(-difference, material)

/datum/unit_test/voidcrew_construction_automation/proc/check_tile_replacement(obj/item/construction/rtd/internal/rtd, datum/tile_info/base_design, datum/tile_info/dark_design)
	TEST_ASSERT_NOTNULL(base_design, "The RTD had no tile design selected")
	TEST_ASSERT_NOTNULL(dark_design, "The dark tile design was never built")
	TEST_ASSERT(isfloorturf(spot(3, 3)) && !istype(spot(3, 3), /turf/open/floor/plating), "The replacement test needs a finished floor to start from")
	// Another tile over a finished floor replaces it, and the refund covers the new tile.
	if(!replace_tile(dark_design, SOUTH))
		return
	// The same tile facing another way is a different floor.
	if(!replace_tile(dark_design, NORTH))
		return
	// A silo that cannot pay leaves the old floor alone.
	var/iron_stock = materials.get_material_amount(/datum/material/iron)
	materials.use_amount_mat(iron_stock, /datum/material/iron)
	rtd.selected_design = base_design
	rtd.selected_direction = SOUTH
	var/datum/ship_construction_job/broke_job = builder.capture_construction_job(spot(3, 3), engineer, "floor", "tile")
	var/laid = builder.complete_decoration_job(broke_job, spot(3, 3), engineer)
	materials.insert_amount_mat(iron_stock, /datum/material/iron)
	qdel(broke_job)
	TEST_ASSERT(!laid, "Tile placer replaced a floor it could not pay for")
	TEST_ASSERT_EQUAL(spot(3, 3).type, dark_design.turf_type, "A failed replacement changed the floor")
	TEST_ASSERT_EQUAL(spot(3, 3).dir, NORTH, "A failed replacement turned the floor")
	// A floor that refunds something other than iron: the refund is of the old floor's own kind.
	var/turf/plating = spot(3, 3).ChangeTurf(/turf/open/floor/plating)
	plating.place_on_top(/turf/open/floor/mineral/titanium)
	TEST_ASSERT(istype(spot(3, 3), /turf/open/floor/mineral/titanium), "Could not lay a titanium floor for the refund check")
	replace_tile(base_design, SOUTH)

/// Lays `design` facing `direction` over the floor at (3, 3) the way the drone does, and checks the swap and what it cost.
/// Returns TRUE when every check passed.
/datum/unit_test/voidcrew_construction_automation/proc/replace_tile(datum/tile_info/design, direction)
	var/turf/target = spot(3, 3)
	var/obj/item/construction/rtd/internal/rtd = builder.internal_rtd
	rtd.selected_design = design
	rtd.selected_direction = direction
	var/list/refund = rcd.get_deconstruction_materials(target) || list()
	var/tile_iron = 100 // SHIP_RTD_TILE_IRON: fork defines occur later than the test includes
	var/iron_expected = materials.get_material_amount(/datum/material/iron) - tile_iron + (refund[/datum/material/iron] || 0)
	var/titanium_expected = materials.get_material_amount(/datum/material/titanium) + (refund[/datum/material/titanium] || 0)
	var/datum/ship_construction_job/job = builder.capture_construction_job(target, engineer, "floor", "tile")
	TEST_ASSERT(builder.construction_job_needed(job, target), "A different tile was not wanted over a finished floor")
	TEST_ASSERT(builder.complete_decoration_job(job, target, engineer), "Tile placer did not replace the floor")
	var/turf/replaced = spot(3, 3)
	TEST_ASSERT_EQUAL(replaced.type, design.turf_type, "The replacement is not the selected tile")
	TEST_ASSERT_EQUAL(replaced.dir, direction, "The replacement does not face the selected way")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_expected, "Replacing a floor charged the wrong iron")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/titanium), titanium_expected, "Replacing a floor refunded the wrong titanium")
	// The same job again finds the floor as it should be: nothing to do, nothing to pay.
	TEST_ASSERT(!builder.construction_job_needed(job, replaced), "An identical floor was still wanted")
	TEST_ASSERT(!builder.complete_decoration_job(job, replaced, engineer), "Tile placer replaced an identical floor")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_expected, "Skipping an identical floor spent iron")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/titanium), titanium_expected, "Skipping an identical floor moved titanium")
	qdel(job)
	return TRUE

/// Walls at (1, 4), (1, 5) and (2, 5) of the block x 1..3, y 3..5, everything else open floor. The open tile (2, 4) has a wall to
/// its north and west, and the wall at (2, 5) has open faces south and east.
/datum/unit_test/voidcrew_construction_automation/proc/test_wall_mount_choice()
	for(var/list/wall_at as anything in list(list(1, 4), list(1, 5), list(2, 5)))
		spot(wall_at[1], wall_at[2]).ChangeTurf(/turf/closed/wall)
	var/turf/open_tile = spot(2, 4)
	var/turf/north_wall = spot(2, 5)
	var/turf/east_open = spot(3, 5)

	// An open tile with walls on two sides: the click picks the nearer wall, and only walls count.
	var/list/mount = builder.drone_wall_mount(open_tile, list(3, 16))
	TEST_ASSERT_NOTNULL(mount, "A click beside a wall found no mounting side")
	TEST_ASSERT_EQUAL(mount[1], open_tile, "An open tile mount moved to another tile")
	TEST_ASSERT_EQUAL(mount[2], WEST, "A click near the west wall did not pick it")
	mount = builder.drone_wall_mount(open_tile, list(16, 29))
	TEST_ASSERT_EQUAL(mount?[2], NORTH, "A click near the north wall did not pick it")
	mount = builder.drone_wall_mount(open_tile, list(30, 16))
	TEST_ASSERT_EQUAL(mount?[2], NORTH, "A click near a bare edge picked no wall")
	mount = builder.drone_wall_mount(open_tile, list(16, 16))
	TEST_ASSERT_EQUAL(mount?[2], NORTH, "A tied click did not go to the first direction")

	// A wall with two open faces: the click picks the face, and the fixture goes beyond it facing back at the wall.
	mount = builder.drone_wall_mount(north_wall, list(16, 3))
	TEST_ASSERT_NOTNULL(mount, "A click near a wall face found no mounting side")
	TEST_ASSERT_EQUAL(mount[1], open_tile, "A click near the south face put the fixture on the wrong tile")
	TEST_ASSERT_EQUAL(mount[2], NORTH, "A click near the south face hung the fixture on the wrong wall")
	mount = builder.drone_wall_mount(north_wall, list(29, 16))
	TEST_ASSERT_NOTNULL(mount, "A click near the east face found no mounting side")
	TEST_ASSERT_EQUAL(mount[1], east_open, "A click near the east face put the fixture on the wrong tile")
	TEST_ASSERT_EQUAL(mount[2], WEST, "A click near the east face hung the fixture on the wrong wall")
	// A click in the middle of that wall ties between its faces: the face toward the drone wins.
	var/turf/drone_was = get_turf(builder.eyeobj)
	builder.eyeobj.abstract_move(east_open)
	mount = builder.drone_wall_mount(north_wall, list(16, 16))
	TEST_ASSERT_EQUAL(mount?[1], east_open, "A tied click on a wall ignored the drone to its east")
	builder.eyeobj.abstract_move(spot(2, 3))
	mount = builder.drone_wall_mount(north_wall, list(16, 16))
	TEST_ASSERT_EQUAL(mount?[1], open_tile, "A tied click on a wall ignored the drone to its south")
	builder.eyeobj.abstract_move(drone_was)

	// A chosen wall on an open tile: the wall must be there, and the choice beats the click.
	mount = builder.drone_wall_mount(open_tile, null, NORTH)
	TEST_ASSERT_EQUAL(mount?[1], open_tile, "A chosen wall moved the fixture to another tile")
	TEST_ASSERT_EQUAL(mount?[2], NORTH, "The chosen north wall was not used")
	mount = builder.drone_wall_mount(open_tile, null, WEST)
	TEST_ASSERT_EQUAL(mount?[2], WEST, "The chosen west wall was not used")
	mount = builder.drone_wall_mount(open_tile, list(3, 16), NORTH)
	TEST_ASSERT_EQUAL(mount?[2], NORTH, "The click overrode the chosen wall")
	TEST_ASSERT_NULL(builder.drone_wall_mount(open_tile, null, EAST), "Hung a fixture on a wall that is not there (east)")
	TEST_ASSERT_NULL(builder.drone_wall_mount(open_tile, list(3, 16), SOUTH), "Hung a fixture on a wall that is not there (south)")

	// A chosen wall on a clicked wall: the tile on the other side, facing the chosen way.
	mount = builder.drone_wall_mount(north_wall, null, NORTH)
	TEST_ASSERT_EQUAL(mount?[1], open_tile, "A chosen north wall put the fixture on the wrong tile")
	TEST_ASSERT_EQUAL(mount?[2], NORTH, "A chosen north wall was not kept")
	mount = builder.drone_wall_mount(north_wall, null, WEST)
	TEST_ASSERT_EQUAL(mount?[1], east_open, "A chosen west wall put the fixture on the wrong tile")
	TEST_ASSERT_EQUAL(mount?[2], WEST, "A chosen west wall was not kept")
	TEST_ASSERT_NULL(builder.drone_wall_mount(north_wall, null, EAST), "Hung a fixture on the far side of a wall that has another wall there")

	// The click position comes from the click's own coordinates, shifted by how the clicked object is drawn.
	TEST_ASSERT_NULL(builder.drone_click_point(open_tile, list()), "A click without a position produced one")
	var/list/point = builder.drone_click_point(open_tile, list(ICON_X = "12", ICON_Y = "20"))
	TEST_ASSERT(islist(point) && point[1] == 12 && point[2] == 20, "A tile click did not report its own coordinates: [json_encode(point)]")
	var/obj/item/screwdriver/marker = allocate(/obj/item/screwdriver, open_tile)
	marker.pixel_x = 4
	marker.pixel_y = -2
	point = builder.drone_click_point(marker, list(ICON_X = "12", ICON_Y = "20"))
	TEST_ASSERT(islist(point) && point[1] == 16 && point[2] == 18, "An object click did not add the object's offset: [json_encode(point)]")

/// The Lights tab sets what the drone builds and which wall it hangs on; only the drone's operator may.
/datum/unit_test/voidcrew_construction_automation/proc/test_light_settings(mob/living/carbon/human/other)
	var/original_type = builder.light_build_type
	var/original_dir = builder.light_build_dir
	check_light_settings(other)
	builder.light_build_type = original_type
	builder.light_build_dir = original_dir

/datum/unit_test/voidcrew_construction_automation/proc/check_light_settings(mob/living/carbon/human/other)
	// SHIP_DRONE_LIGHT_*: fork defines occur later than the test includes.
	TEST_ASSERT(builder.drone_tool_act("light_type", list("type" = "floor"), engineer), "Choosing a light type was not handled")
	TEST_ASSERT_EQUAL(builder.light_build_type, "floor", "Choosing a light type did nothing")
	builder.drone_tool_act("light_type", list("type" = "chandelier"), engineer)
	TEST_ASSERT_EQUAL(builder.light_build_type, "floor", "An unknown light type was accepted")
	builder.drone_tool_act("light_type", list("type" = "glow"), other)
	TEST_ASSERT_EQUAL(builder.light_build_type, "floor", "Someone else changed the light type")
	builder.drone_tool_act("light_dir", list("dir" = "west"), engineer)
	TEST_ASSERT_EQUAL(builder.light_build_dir, WEST, "Choosing a wall did nothing")
	builder.drone_tool_act("light_dir", list("dir" = "up"), engineer)
	builder.drone_tool_act("light_dir", list("dir" = "northeast"), engineer)
	TEST_ASSERT_EQUAL(builder.light_build_dir, WEST, "An unknown wall was accepted")
	builder.drone_tool_act("light_dir", list("dir" = "east"), other)
	TEST_ASSERT_EQUAL(builder.light_build_dir, WEST, "Someone else changed the wall")
	builder.drone_tool_act("light_dir", list("dir" = "auto"), engineer)
	TEST_ASSERT_EQUAL(builder.light_build_dir, NONE, "Choosing auto did not clear the wall")

/// Lights built on the wall-mount layout of test_wall_mount_choice(), paid out of the RLD's own stock.
/datum/unit_test/voidcrew_construction_automation/proc/test_light_placement()
	var/obj/item/construction/rld/internal/rld = new(builder)
	builder.internal_rld = rld
	rld.ship_console = builder
	rld.silo_mats = rld.AddComponent(/datum/component/remote_materials, FALSE, TRUE)
	rld.silo_link = TRUE
	var/datum/component/material_container/light_stock = rld.silo_mats.mat_container
	var/original_type = builder.light_build_type
	var/original_dir = builder.light_build_dir
	if(light_stock)
		light_stock.insert_amount_mat(1000, /datum/material/iron)
		light_stock.insert_amount_mat(1000, /datum/material/glass)
		check_light_placement(light_stock)
	else
		Fail("The test RLD has no material container")
	builder.light_build_type = original_type
	builder.light_build_dir = original_dir
	for(var/obj/machinery/light/light in spot(2, 4))
		qdel(light)
	builder.internal_rld = null
	qdel(rld)

/datum/unit_test/voidcrew_construction_automation/proc/check_light_placement(datum/component/material_container/light_stock)
	// SHIP_DRONE_LIGHT_* and SHIP_RLD_*_LIGHT_*: fork defines occur later than the test includes.
	// A wall light costs 25 iron and 50 glass, a floor light 50 iron and 25 glass.
	var/turf/open_tile = spot(2, 4)
	var/turf/north_wall = spot(2, 5)
	var/iron_before = light_stock.get_material_amount(/datum/material/iron)
	var/glass_before = light_stock.get_material_amount(/datum/material/glass)

	// A tube goes on the wall nearest the click.
	builder.light_build_type = "tube"
	builder.light_build_dir = NONE
	TEST_ASSERT(builder.drone_place_light(engineer, open_tile, list(16, 30)), "Could not build a tube light")
	var/obj/machinery/light/tube = locate() in open_tile
	TEST_ASSERT_NOTNULL(tube, "The tube light was not built")
	TEST_ASSERT_EQUAL(tube.type, /obj/machinery/light, "A tube was built as something else")
	TEST_ASSERT_EQUAL(tube.dir, NORTH, "The tube did not hang on the nearest wall")
	TEST_ASSERT_EQUAL(light_stock.get_material_amount(/datum/material/iron), iron_before - 25, "A wall light charged the wrong iron")
	TEST_ASSERT_EQUAL(light_stock.get_material_amount(/datum/material/glass), glass_before - 50, "A wall light charged the wrong glass")
	// One light to a wall.
	TEST_ASSERT(!builder.drone_place_light(engineer, open_tile, list(16, 30)), "Built a second light on the same wall")
	TEST_ASSERT(!builder.drone_place_light(engineer, north_wall, list(16, 3)), "Built a second light on the same wall from the wall's side")
	TEST_ASSERT_EQUAL(light_stock.get_material_amount(/datum/material/iron), iron_before - 25, "A refused light was charged")

	// A bulb goes on the chosen wall of the same tile.
	builder.light_build_type = "bulb"
	builder.light_build_dir = WEST
	TEST_ASSERT(builder.drone_place_light(engineer, open_tile, null), "The tile's other wall could not take a light")
	var/obj/machinery/light/small/bulb = locate() in open_tile
	TEST_ASSERT_NOTNULL(bulb, "The bulb light was not built")
	TEST_ASSERT_EQUAL(bulb.dir, WEST, "The bulb did not hang on the chosen wall")
	TEST_ASSERT_EQUAL(tube.dir, NORTH, "Building a second light turned the first")
	TEST_ASSERT_EQUAL(light_stock.get_material_amount(/datum/material/iron), iron_before - 50, "A bulb was charged differently from a tube (iron)")
	TEST_ASSERT_EQUAL(light_stock.get_material_amount(/datum/material/glass), glass_before - 100, "A bulb was charged differently from a tube (glass)")

	// A floor light does not care about the wall lights, and needs a floor.
	builder.light_build_type = "floor"
	builder.light_build_dir = NONE
	TEST_ASSERT(builder.drone_place_light(engineer, open_tile, null), "A wall light blocked a floor light")
	TEST_ASSERT_NOTNULL(locate(/obj/machinery/light/floor) in open_tile, "The floor light was not built")
	TEST_ASSERT_EQUAL(light_stock.get_material_amount(/datum/material/iron), iron_before - 100, "A floor light charged the wrong iron")
	TEST_ASSERT_EQUAL(light_stock.get_material_amount(/datum/material/glass), glass_before - 125, "A floor light charged the wrong glass")
	TEST_ASSERT(!builder.drone_place_light(engineer, open_tile, null), "Built a second floor light on the same tile")
	TEST_ASSERT(!builder.drone_place_light(engineer, north_wall, null), "Built a floor light on a wall")

	// A bulb comes down for the same refund as a tube.
	var/silo_iron = materials.get_material_amount(/datum/material/iron)
	var/silo_glass = materials.get_material_amount(/datum/material/glass)
	TEST_ASSERT(builder.drone_remove_light(engineer, open_tile, bulb), "Could not take the bulb down")
	TEST_ASSERT(QDELETED(bulb), "The bulb was not removed")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), silo_iron + 25, "A bulb refunded the wrong iron")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/glass), silo_glass + 50, "A bulb refunded the wrong glass")

/datum/unit_test/voidcrew_construction_automation/proc/test_damage_repairs()
	var/obj/structure/overmap/ship/integrity_dummy/hull = allocate(/obj/structure/overmap/ship/integrity_dummy)
	hull.shuttle = port
	builder.current_ship = hull
	hull.state = "idle"
	var/initial_records = SSship_repairs.record_count
	TEST_ASSERT(builder.set_repair_tracking(TRUE), "Could not enable flight damage tracking")
	TEST_ASSERT_EQUAL(length(builder.repair_records), 0, "Arming repair tracking saved intact hull data")
	TEST_ASSERT_EQUAL(SSship_repairs.record_count, initial_records, "Arming allocated per-tile records")
	// A host's merged area list must not steal a visiting ship's damage listener.
	var/area/crew_area = get_area(builder)
	// allocate() supplies the fixture turf as loc, which would silently reassign its area.
	var/area/shuttle/voidcrew/guest_area = new
	allocated += guest_area
	TEST_ASSERT_EQUAL(get_area(builder), crew_area, "Creating a guest area moved the console out of its power area")
	var/obj/docking_port/mobile/voidcrew/guest_port = new(spot(0, 0))
	var/obj/machinery/computer/camera_advanced/base_construction/ship/guest_console = allocate(/obj/machinery/computer/camera_advanced/base_construction/ship)
	guest_area.shuttle_port = guest_port
	port.shuttle_areas[guest_area] = TRUE
	SSship_repairs.area_controllers[guest_area] = guest_console
	builder.refresh_repair_areas()
	TEST_ASSERT_EQUAL(SSship_repairs.area_controllers[guest_area], guest_console, "Host stole its guest's repair tracking")
	port.shuttle_areas -= guest_area
	SSship_repairs.area_controllers -= guest_area
	guest_area.shuttle_port = null
	qdel(guest_port, force = TRUE)
	var/turf/window_tile = spot(4, 4)
	var/obj/structure/window/reinforced/shuttle/window = new(window_tile)
	window.set_anchored(TRUE)
	window.take_damage(20, BRUTE, MELEE, sound_effect = FALSE, armour_penetration = 100)
	TEST_ASSERT_EQUAL(length(builder.repair_records), 0, "Docked damage was recorded")
	hull.state = "flying"
	window.take_damage(20, BRUTE, MELEE, sound_effect = FALSE, armour_penetration = 100)
	var/window_key = builder.repair_coordinate_key(window_tile)
	var/datum/ship_repair_record/window_record = builder.repair_records[window_key]
	TEST_ASSERT_NOTNULL(window_record, "Actual fixture damage hook did not record flight damage")
	window.take_damage(20, BRUTE, MELEE, sound_effect = FALSE, armour_penetration = 100)
	TEST_ASSERT_EQUAL(length(builder.repair_records), 1, "Repeated hits created duplicate damage records")
	// A full server journal rejects new damage without evicting an existing repair.
	var/saved_count = SSship_repairs.record_count
	SSship_repairs.record_count = 8192 // mirrors the server-wide journal cap
	var/overflow_accepted = builder.capture_repair_damage(spot(3, 4))
	SSship_repairs.record_count = saved_count
	TEST_ASSERT(!overflow_accepted, "Full server journal accepted additional damage")
	TEST_ASSERT_EQUAL(builder.repair_records[window_key], window_record, "Overflow evicted existing damage")
	window.deconstruct(FALSE)
	hull.state = "idle"
	TEST_ASSERT(builder.perform_record_repair(window_record), "Destroyed shuttle window was not rebuilt")
	var/titanium_after = materials.get_material_amount(/datum/material/titanium)
	TEST_ASSERT(!builder.perform_record_repair(window_record), "Completed repair ran twice")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/titanium), titanium_after, "Duplicate repair spent titanium")
	builder.forget_repair_record(window_key)
	// Numerical health alone does not reset the native broken-fixture state.
	var/obj/structure/grille/grille = allocate(/obj/structure/grille, spot(3, 4))
	hull.state = "flying"
	grille.take_damage(35, BRUTE, damage_flag = NONE, sound_effect = FALSE)
	TEST_ASSERT(grille.broken && !grille.density, "Test grille did not break")
	var/grille_key = builder.repair_coordinate_key(get_turf(grille))
	hull.state = "idle"
	TEST_ASSERT(builder.perform_record_repair(builder.repair_records[grille_key]), "Broken grille repair failed")
	TEST_ASSERT(!grille.broken && grille.density && grille.rods_amount == 2, "Repaired grille stayed broken")
	builder.forget_repair_record(grille_key)
	qdel(grille)

	// Preserve destroyed door configuration and claim one record per drone.
	var/turf/door_tile = spot(4, 2)
	var/obj/machinery/door/airlock/door = new(door_tile)
	door.req_access = list(ACCESS_ENGINEERING)
	door.name = "Test engineering airlock"
	var/obj/machinery/door/airlock/cycle_partner = allocate(/obj/machinery/door/airlock, spot(5, 2))
	door.closeOtherId = "repair-test-[REF(src)]"
	cycle_partner.closeOtherId = door.closeOtherId
	door.update_other_id()
	hull.state = "flying"
	door.take_damage(door.max_integrity * 0.8, BRUTE, damage_flag = NONE, sound_effect = FALSE)
	TEST_ASSERT(door.machine_stat & BROKEN, "Test airlock did not break")
	var/broken_door_key = builder.repair_coordinate_key(door_tile)
	hull.state = "idle"
	TEST_ASSERT(builder.perform_record_repair(builder.repair_records[broken_door_key]), "Broken airlock repair failed")
	TEST_ASSERT(!(door.machine_stat & BROKEN), "Repaired airlock stayed broken")
	builder.forget_repair_record(broken_door_key)
	hull.state = "flying"
	door.deconstruct(FALSE)
	var/door_key = builder.repair_coordinate_key(door_tile)
	var/datum/ship_repair_record/door_record = builder.repair_records[door_key]
	TEST_ASSERT_NOTNULL(door_record, "Airlock destruction did not create a record")
	hull.state = "idle"
	builder.console_upgrades &= ~(1<<9)
	builder.repair_enabled = TRUE
	var/obj/structure/ship_repair_drone/first = allocate(/obj/structure/ship_repair_drone, spot(3, 2))
	var/obj/structure/ship_repair_drone/second = allocate(/obj/structure/ship_repair_drone, spot(4, 1))
	first.console = builder
	second.console = builder
	// Flight is direct: walls, windows and closed doors do not require a route.
	var/turf/obstacle = spot(2, 1).place_on_top(/turf/closed/wall)
	var/obj/machinery/door/airlock/route_door = allocate(/obj/machinery/door/airlock, spot(3, 1))
	route_door.locked = TRUE
	route_door.welded = TRUE
	route_door.wires.cut(WIRE_OPEN)
	first.forceMove(spot(1, 1))
	var/obj/structure/window/border = allocate(/obj/structure/window, spot(1, 1))
	border.setDir(EAST)
	first.move_to_repair(spot(4, 1))
	TEST_ASSERT_EQUAL(get_turf(first), obstacle, "Drone could not hover across a window and onto a wall")
	first.move_to_repair(spot(4, 1))
	TEST_ASSERT_EQUAL(get_turf(first), get_turf(route_door), "Closed airlock blocked the hovering drone")
	TEST_ASSERT(route_door.density && route_door.locked && route_door.welded, "Drone opened or altered the airlock")
	qdel(border)
	qdel(route_door)
	obstacle = obstacle.ChangeTurf(/turf/open/floor/plating)
	// Noclip still respects the linked ship's boundary.
	var/area/obstacle_area = get_area(obstacle)
	var/area/shuttle/voidcrew/foreign_area = new
	allocated += foreign_area
	obstacle.change_area(obstacle_area, foreign_area)
	first.forceMove(spot(1, 1))
	first.move_to_repair(spot(4, 1))
	TEST_ASSERT_EQUAL(get_turf(first), spot(1, 1), "Drone crossed into another ship's area")
	obstacle.change_area(foreign_area, obstacle_area)
	first.forceMove(spot(3, 2))
	builder.repair_drones = list(first, second)
	// Pausing an unavailable fleet must release the global scheduler budget.
	hull.state = "flying"
	builder.test_docked = FALSE
	builder.repair_enabled = FALSE
	SSship_repairs.workers |= first
	first.next_step = 0
	first.process(0.5)
	TEST_ASSERT(!(first in SSship_repairs.workers), "Paused airborne drone stayed scheduled")
	builder.repair_enabled = TRUE
	builder.wake_repair_drones()
	// Losing console capability pauses existing work without unlinking the swarm.
	builder.console_upgrades &= ~(1<<10)
	first.next_step = 0
	first.process(0.5)
	TEST_ASSERT_NULL(first.job, "Unupgraded console assigned a pending repair")
	TEST_ASSERT_EQUAL(first.console, builder, "Missing console upgrade unlinked an active drone")
	TEST_ASSERT(!builder.perform_record_repair(door_record), "Unupgraded console completed a pending repair")
	TEST_ASSERT(!builder.can_record_repair_damage(), "Unupgraded console continued recording damage")
	TEST_ASSERT_EQUAL(builder.repair_records[door_key], door_record, "Missing console upgrade discarded pending damage")
	builder.console_upgrades |= (1<<10)
	builder.wake_repair_drones()
	var/previous_stat = builder.machine_stat
	builder.set_machine_stat(previous_stat | NOPOWER)
	first.next_step = 0
	first.process(0.5)
	TEST_ASSERT_NULL(first.job, "Unpowered console started a repair")
	TEST_ASSERT_EQUAL(first.status, "Console unpowered", "Drone did not identify the power blocker")
	builder.set_machine_stat(previous_stat)
	hull.state = "docking"
	first.next_step = 0
	first.process(0.5)
	TEST_ASSERT_NULL(first.job, "Drone repaired while the hull was being relocated")
	hull.state = "flying"
	first.next_step = 0
	first.process(0.5)
	TEST_ASSERT(first in SSship_repairs.workers, "Flight repair did not resume automatically")
	second.process(0.5)
	TEST_ASSERT_EQUAL(door_record.claimed_by, first, "Second drone stole a repair claim")
	TEST_ASSERT_NULL(second.job, "Two workers claimed one repair")
	first.work_finishes = world.time
	first.next_step = 0
	first.process(0.5)
	TEST_ASSERT_EQUAL(first.repaired, 1, "Unattended drone did not complete its repair during flight")
	TEST_ASSERT(!builder.can_operate(), "Flight repair test accidentally allowed manual construction")
	builder.test_docked = TRUE
	door = locate() in door_tile
	TEST_ASSERT_NOTNULL(door, "Airlock was not restored")
	TEST_ASSERT(ACCESS_ENGINEERING in door.req_access, "Rebuilt airlock lost access restrictions")
	TEST_ASSERT_EQUAL(door.name, "Test engineering airlock", "Rebuilt airlock lost its name")
	TEST_ASSERT((cycle_partner in door.close_others) && (door in cycle_partner.close_others), "Rebuilt airlock lost its cycle connection")
	qdel(cycle_partner)
	// Crew work on the wreckage supersedes its recorded airlock configuration.
	hull.state = "flying"
	door.deconstruct(FALSE)
	var/obj/structure/door_assembly/frame = locate() in door_tile
	TEST_ASSERT_NOTNULL(frame, "Destroyed door did not leave its assembly")
	frame.set_anchored(!frame.anchored)
	TEST_ASSERT_NULL(builder.next_record_repair(builder.repair_records[door_key]), "Drone would overwrite a crew-modified frame")
	qdel(frame)
	qdel(first)
	qdel(second)
	builder.repair_enabled = FALSE
	builder.console_upgrades |= (1<<9)
	builder.clear_repair_journal()

	// The ship's existing turf signal records walls before a direct explosion scrape.
	hull.integrity_initialized = TRUE
	hull.setup_mass_tracking()
	hull.state = "flying"
	var/turf/wall_tile = spot(2, 3)
	// The unit-test room is not /area/shuttle, so give its sample wall a real hull marker.
	wall_tile.insert_baseturf(turf_type = /turf/baseturf_skipover/shuttle)
	TEST_ASSERT(isshuttleturf(wall_tile), "Test wall is missing its ship baseturf")
	wall_tile.ChangeTurf(/turf/open/space)
	var/wall_key = builder.repair_coordinate_key(spot(2, 3))
	var/datum/ship_repair_record/wall_record = builder.repair_records[wall_key]
	TEST_ASSERT_NOTNULL(wall_record, "Ship turf-change event failed to record a breach")
	hull.state = "idle"
	TEST_ASSERT(builder.perform_record_repair(wall_record), "Wall breach did not get a floor")
	TEST_ASSERT(isfloorturf(spot(2, 3)), "Wall repair skipped its supporting floor")
	TEST_ASSERT(builder.perform_record_repair(wall_record), "Wall was not restored")
	TEST_ASSERT_EQUAL(builder.repair_records[wall_key], wall_record, "Drone repair canceled its own record")

	// Docked remodeling cancels old orders; it must not be undone by the swarm.
	var/turf/remodel = spot(2, 3)
	remodel.ChangeTurf(/turf/open/floor/plating)
	TEST_ASSERT_NULL(builder.repair_records[wall_key], "Docked construction retained a stale wall order")
	hull.state = "flying"
	window = locate() in window_tile
	window.take_damage(20, BRUTE, MELEE, sound_effect = FALSE, armour_penetration = 100)
	TEST_ASSERT_NOTNULL(builder.repair_records[window_key], "Fixture damage tracking stopped after a repair")
	hull.state = "idle"
	var/obj/item/screwdriver/screwdriver = allocate(/obj/item/screwdriver)
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	screwdriver.toolspeed = 0
	wrench.toolspeed = 0
	window.state = WINDOW_OUT_OF_FRAME
	window.screwdriver_act(engineer, screwdriver)
	TEST_ASSERT(!window.anchored, "Window screwdriver did not unfasten the frame")
	window.wrench_act(engineer, wrench)
	TEST_ASSERT(QDELETED(window), "Window wrench disassembly did not finish")
	TEST_ASSERT_NULL(builder.repair_records[window_key], "Hand-tool disassembly retained a stale window order")

	// Real hand tools cancel old orders without treating flight remodeling as damage.
	hull.state = "flying"
	var/turf/closed/wall/manual_wall = spot(2, 3).place_on_top(/turf/closed/wall)
	var/manual_key = builder.repair_coordinate_key(manual_wall)
	builder.capture_repair_damage(manual_wall)
	TEST_ASSERT_NOTNULL(builder.repair_records[manual_key], "Could not prepare old wall damage")
	var/obj/item/weldingtool/welder = allocate(/obj/item/weldingtool)
	welder.toolspeed = 0
	// An unlit tool cannot complete demolition or discard its old repair order.
	manual_wall.try_decon(welder, engineer)
	TEST_ASSERT_NOTNULL(builder.repair_records[manual_key], "Failed hand demolition discarded existing damage")
	welder.set_welding(TRUE)
	manual_wall.try_decon(welder, engineer)
	TEST_ASSERT(isfloorturf(spot(2, 3)), "Welder did not dismantle the wall")
	var/obj/structure/girder/girder = locate() in spot(2, 3)
	TEST_ASSERT_NOTNULL(girder, "Hand wall demolition left no girder")
	girder.wrench_act(engineer, wrench)
	girder = locate() in spot(2, 3)
	girder.screwdriver_act(engineer, screwdriver)
	TEST_ASSERT(QDELETED(girder), "Hand girder demolition did not finish")
	TEST_ASSERT_NULL(builder.repair_records[manual_key], "Flight hand demolition queued a replacement wall")
	TEST_ASSERT(!builder.repair_applying, "Hand demolition left damage capture suppressed")
	manual_wall = spot(2, 3).place_on_top(/turf/closed/wall)
	manual_wall.ChangeTurf(/turf/open/floor/plating)
	TEST_ASSERT_NOTNULL(builder.repair_records[manual_key], "Later genuine wall destruction was not recorded")
	builder.forget_repair_record(manual_key)

	// A breached coordinate transfers only its area when landing on natural ground.
	var/turf/landing = spot(1, 4)
	var/area/original_area = get_area(landing)
	var/area/shuttle/voidcrew/landing_area = new
	allocated += landing_area
	TEST_ASSERT_EQUAL(get_area(builder), crew_area, "Creating a landing area moved the console out of its power area")
	landing_area.shuttle_port = port
	port.shuttle_areas[landing_area] = TRUE
	landing.change_area(original_area, landing_area)
	builder.refresh_repair_areas()
	landing.insert_baseturf(turf_type = /turf/baseturf_skipover/shuttle)
	hull.state = "flying"
	builder.capture_repair_damage(landing)
	var/landing_key = builder.repair_coordinate_key(landing)
	var/datum/ship_repair_record/landing_record = builder.repair_records[landing_key]
	TEST_ASSERT_NOTNULL(landing_record, "Could not record a landing breach")
	// Area-only movement exposes site ground with none of the ship's baseturfs.
	hull.state = "docking"
	landing = landing.ChangeTurf(/turf/open/misc/wasteland, /turf/open/misc/wasteland)
	hull.state = "idle"
	TEST_ASSERT(builder.perform_record_repair(landing_record), "Natural landing terrain erased a floor repair")
	landing = spot(1, 4)
	TEST_ASSERT(isfloorturf(landing) && isshuttleturf(landing), "Landing repair did not restore movable ship deck")
	TEST_ASSERT(/turf/open/misc/wasteland in landing.baseturfs, "Landing repair destroyed the underlying site terrain")
	builder.forget_repair_record(landing_key)
	landing.change_area(landing_area, original_area)
	port.shuttle_areas -= landing_area
	landing_area.shuttle_port = null
	builder.refresh_repair_areas()

	// Relocating console/port does not shift coordinates. Origins rotate with the hull.
	hull.state = "flying"
	builder.capture_repair_damage(spot(3, 3))
	var/key = builder.repair_records[1]
	var/datum/ship_repair_record/record = builder.repair_records[key]
	var/turf/original_target = builder.repair_record_turf(record)
	builder.forceMove(spot(0, 1))
	port.forceMove(spot(0, 2))
	TEST_ASSERT_EQUAL(builder.repair_record_turf(record), original_target, "Moving console/port translated damage records")
	var/old_dir = builder.repair_origin.dir
	builder.repair_origin.setDir(turn(old_dir, 90))
	TEST_ASSERT(builder.repair_record_turf(record) != original_target, "Damage record did not rotate with origin")
	builder.repair_origin.setDir(old_dir)
	builder.set_repair_tracking(FALSE)
	TEST_ASSERT(!builder.capture_repair_damage(spot(3, 4)), "Disabled tracking recorded demolition")
	builder.clear_repair_journal(TRUE)
	TEST_ASSERT_NULL(port.ship_repair_controller, "Disconnect left a controller claim")
	TEST_ASSERT_EQUAL(SSship_repairs.record_count, initial_records, "Clearing leaked damage records")
	test_floor_breach_refill(hull)
	hull.shuttle = null
	builder.current_ship = null

/// A real explosion, docked door removal, and partial refill must preserve every floor job.
/datum/unit_test/voidcrew_construction_automation/proc/test_floor_breach_refill(obj/structure/overmap/ship/hull)
	hull.state = "idle"
	TEST_ASSERT(builder.set_repair_tracking(TRUE), "Could not enable breach tracking")
	for(var/dx in 1 to 3)
		var/turf/floor = spot(dx, 5).ChangeTurf(/turf/open/floor/iron)
		floor.baseturfs = list(/turf/open/space, /turf/baseturf_skipover/shuttle, /turf/open/floor/plating)
	hull.state = "flying"
	for(var/dx in 1 to 3)
		spot(dx, 5).ex_act(EXPLODE_DEVASTATE)
		TEST_ASSERT(isspaceturf(spot(dx, 5)), "Explosion did not open the test floor")
	TEST_ASSERT_EQUAL(length(builder.repair_records), 3, "Explosion failed to record all three missing floors")
	hull.state = "idle"
	var/obj/machinery/door/airlock/blocker = allocate(/obj/machinery/door/airlock, spot(4, 5))
	blocker.deconstruct(TRUE)
	var/obj/structure/door_assembly/removed_frame = locate() in spot(4, 5)
	qdel(removed_frame)
	TEST_ASSERT_EQUAL(length(builder.repair_records), 3, "Removing a nearby door discarded the floor breach")
	var/iron_before = materials.get_material_amount(/datum/material/iron)
	materials.use_amount_mat(iron_before, /datum/material/iron)
	var/list/other_supplies = list()
	for(var/material in list(/datum/material/titanium, /datum/material/plasma, /datum/material/glass))
		other_supplies[material] = materials.get_material_amount(material)
		materials.use_amount_mat(other_supplies[material], material)
	var/obj/structure/ship_repair_drone/worker = allocate(/obj/structure/ship_repair_drone, spot(1, 4))
	worker.console = builder
	builder.repair_drones += worker
	builder.repair_enabled = TRUE
	builder.wake_repair_drones()
	worker.process(0.5)
	TEST_ASSERT_EQUAL(worker.repaired, 0, "Empty silo counted a floor as repaired")
	TEST_ASSERT_EQUAL(length(builder.repair_records), 3, "Empty silo discarded floor repairs")
	// Enough for one floor only: completing it must not retire the other two.
	materials.insert_amount_mat(100, /datum/material/iron)
	for(var/attempt in 1 to 15)
		for(var/key in builder.repair_records)
			var/datum/ship_repair_record/record = builder.repair_records[key]
			record.retry_after = 0
		worker.next_step = 0
		worker.process(0.5)
	TEST_ASSERT_EQUAL(worker.repaired, 1, "Partial refill did not repair exactly one floor")
	TEST_ASSERT_EQUAL(length(builder.repair_records), 2, "One completed floor erased the rest of the breach")
	materials.insert_amount_mat(200, /datum/material/iron)
	for(var/attempt in 1 to 20)
		for(var/key in builder.repair_records)
			var/datum/ship_repair_record/record = builder.repair_records[key]
			record.retry_after = 0
		worker.next_step = 0
		worker.process(0.5)
	for(var/dx in 1 to 3)
		TEST_ASSERT(isfloorturf(spot(dx, 5)), "Drone declared completion while a floor hole remained")
	TEST_ASSERT_EQUAL(worker.repaired, 3, "Refilled drone did not finish every floor")
	TEST_ASSERT_EQUAL(length(builder.repair_records), 0, "Completed floor repairs stayed queued")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 0, "Floor repair charged the wrong amount")
	// Hull plating and catwalks were absent from the old whitelist; unsupported
	// finishes must still receive a standard iron floor.
	var/list/floor_cases = list(
		/turf/open/floor/engine/hull = list(/turf/open/floor/engine/hull, 200),
		/turf/open/floor/catwalk_floor = list(/turf/open/floor/catwalk_floor, 100),
		/turf/open/floor/carpet = list(/turf/open/floor/iron, 100),
		/turf/open/floor/wood = list(/turf/open/floor/iron, 100),
	)
	for(var/floor_path in floor_cases)
		hull.state = "idle"
		var/turf/floor = spot(1, 5).ChangeTurf(floor_path)
		floor.baseturfs = list(/turf/open/space, /turf/baseturf_skipover/shuttle, /turf/open/floor/plating)
		hull.state = "flying"
		floor.ScrapeAway(2, flags = CHANGETURF_INHERIT_AIR)
		TEST_ASSERT(isspaceturf(spot(1, 5)), "Could not destroy [floor_path]")
		TEST_ASSERT_EQUAL(length(builder.repair_records), 1, "Destroyed [floor_path] was omitted from tracking")
		var/list/expected = floor_cases[floor_path]
		materials.insert_amount_mat(expected[2], /datum/material/iron)
		for(var/attempt in 1 to 10)
			worker.next_step = 0
			worker.process(0.5)
		TEST_ASSERT_EQUAL(spot(1, 5).type, expected[1], "Drone did not restore the expected floor for [floor_path]")
		TEST_ASSERT_EQUAL(length(builder.repair_records), 0, "Restored [floor_path] kept its repair record")
		TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 0, "Incorrect [floor_path] repair cost")
	// A completely missing exotic wall needs both a paid deck and an iron wall.
	hull.state = "idle"
	var/turf/closed/wall/exotic_wall = spot(1, 5).place_on_top(/turf/closed/wall/mineral/gold)
	exotic_wall.baseturfs = list(/turf/open/space, /turf/baseturf_skipover/shuttle, /turf/open/floor/plating)
	hull.state = "flying"
	exotic_wall.ChangeTurf(/turf/open/space, list(/turf/open/space, /turf/baseturf_skipover/shuttle))
	TEST_ASSERT_EQUAL(length(builder.repair_records), 1, "Unsupported wall was omitted from tracking")
	var/datum/ship_repair_record/wall_record = builder.repair_records[builder.repair_coordinate_key(spot(1, 5))]
	TEST_ASSERT(!builder.perform_record_repair(wall_record), "Fallback wall spent unavailable iron")
	TEST_ASSERT_EQUAL(length(builder.repair_records), 1, "Fallback wall was forgotten while out of materials")
	materials.insert_amount_mat(300, /datum/material/iron)
	for(var/attempt in 1 to 10)
		worker.next_step = 0
		worker.process(0.5)
	TEST_ASSERT_EQUAL(spot(1, 5).type, /turf/closed/wall, "Unsupported wall did not fall back to iron")
	TEST_ASSERT_EQUAL(length(builder.repair_records), 0, "Completed fallback wall stayed queued")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 0, "Fallback wall charged more than iron wall and deck costs")
	hull.state = "idle"
	spot(1, 5).ChangeTurf(/turf/open/floor/iron)
	test_supply_aware_repairs(hull, worker)
	test_repair_holofans(hull, worker)
	test_repair_effects(hull, worker)
	test_drone_return_home(hull, worker)
	materials.insert_amount_mat(iron_before, /datum/material/iron)
	for(var/material in other_supplies)
		materials.insert_amount_mat(other_supplies[material], material)
	qdel(worker)
	builder.repair_enabled = FALSE
	builder.clear_repair_journal(TRUE)

/// An empty journal sends enabled drones home; fresh damage can interrupt the trip.
/datum/unit_test/voidcrew_construction_automation/proc/test_drone_return_home(obj/structure/overmap/ship/hull, obj/structure/ship_repair_drone/worker)
	builder.clear_repair_journal()
	worker.forceMove(spot(4, 5))
	builder.wake_repair_drones()
	TEST_ASSERT(worker in SSship_repairs.workers, "An enabled drone with no repairs was not scheduled to return home")
	var/distance_before = get_dist(worker, builder)
	repair_step(worker)
	TEST_ASSERT_EQUAL(worker.status, "Returning", "Empty repair queue did not send the drone home")
	TEST_ASSERT(get_dist(worker, builder) < distance_before, "Returning drone did not approach its console")
	TEST_ASSERT(!worker.recalling && worker.enabled, "Automatic return disabled the drone like a manual recall")
	hull.state = "flying"
	spot(1, 5).ChangeTurf(/turf/open/space)
	materials.insert_amount_mat(100, /datum/material/iron)
	repair_step(worker)
	TEST_ASSERT_NOTNULL(worker.job, "New damage did not interrupt the return home")
	TEST_ASSERT_EQUAL(builder.repair_record_turf(worker.job), spot(1, 5), "Returning drone claimed the wrong damage")
	for(var/attempt in 1 to 12)
		repair_step(worker)
	TEST_ASSERT_EQUAL(length(builder.repair_records), 0, "Returning drone did not finish its new repair")
	TEST_ASSERT(worker.is_home(), "Drone did not park by its console after completing the final repair")
	TEST_ASSERT_EQUAL(worker.status, "Standby", "Home drone did not enter standby")
	TEST_ASSERT(!(worker in SSship_repairs.workers), "Home drone kept using the global repair budget")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 0, "Returning home consumed extra materials")
	// Damage also wakes a drone that has already left the scheduler at home.
	spot(1, 5).ChangeTurf(/turf/open/space)
	TEST_ASSERT(worker in SSship_repairs.workers, "Fresh damage did not wake the parked drone")
	builder.clear_repair_journal()
	worker.forceMove(spot(4, 5))
	worker.enabled = FALSE
	var/turf/paused_at = get_turf(worker)
	repair_step(worker)
	TEST_ASSERT_EQUAL(get_turf(worker), paused_at, "Automatic return moved a deliberately paused drone")
	TEST_ASSERT(!(worker in SSship_repairs.workers), "Paused drone kept using the global repair budget")
	worker.enabled = TRUE
	builder.repair_control_act("repair_drone_recall", list("ref" = REF(worker)), engineer)
	for(var/attempt in 1 to 8)
		repair_step(worker)
	TEST_ASSERT(worker.is_home() && !worker.enabled && !worker.recalling, "Manual recall failed to park and pause the drone")
	TEST_ASSERT(!(worker in SSship_repairs.workers), "Recalled drone stayed scheduled")
	worker.enabled = TRUE
	hull.state = "idle"
	spot(1, 5).ChangeTurf(/turf/open/floor/iron)

/// Construction effects must follow actual work and never spend supplies on cancellation.
/datum/unit_test/voidcrew_construction_automation/proc/test_repair_effects(obj/structure/overmap/ship/hull, obj/structure/ship_repair_drone/worker)
	builder.clear_repair_journal()
	hull.state = "idle"
	var/turf/closed/wall/wall = spot(1, 5).place_on_top(/turf/closed/wall/mineral/plastitanium)
	hull.state = "flying"
	wall.ScrapeAway()
	materials.insert_amount_mat(200, /datum/material/iron)
	builder.console_upgrades &= ~(1<<9) // Disable instant fabrication for progress checks.
	worker.forceMove(spot(2, 5))
	repair_step(worker)
	var/obj/effect/constructing_effect/ship_repair/effect = worker.work_effect
	var/datum/beam/beam = worker.work_beam
	TEST_ASSERT_NOTNULL(effect, "Timed repair did not display an RCD construction effect")
	TEST_ASSERT_NOTNULL(beam, "Timed repair did not connect the drone to its construction effect")
	TEST_ASSERT_EQUAL(effect.loc, spot(1, 5), "Construction preview appeared on the wrong tile")
	TEST_ASSERT_EQUAL(effect.design_path, /turf/closed/wall, "Preview showed the unaffordable wall instead of its iron fallback")
	var/iron_before = materials.get_material_amount(/datum/material/iron)
	materials.use_amount_mat(iron_before, /datum/material/iron)
	repair_step(worker)
	TEST_ASSERT(QDELETED(effect) && QDELETED(beam), "Running out of materials left construction effects active")
	TEST_ASSERT_EQUAL(length(builder.repair_records), 1, "Interrupted construction discarded pending damage")
	materials.insert_amount_mat(iron_before, /datum/material/iron)
	repair_step(worker)
	effect = worker.work_effect
	TEST_ASSERT_NOTNULL(effect, "Refilling supplies did not restart the construction preview")
	effect.attacked(engineer)
	repair_step(worker)
	TEST_ASSERT_EQUAL(worker.status, "Repair interrupted", "Punching the RCD effect did not interrupt construction")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_before, "Interrupted construction consumed materials")
	repair_step(worker)
	effect = worker.work_effect
	worker.forceMove(spot(2, 4))
	TEST_ASSERT(QDELETED(effect), "Moving the drone left its old construction preview active")
	repair_step(worker)
	effect = worker.work_effect
	worker.enabled = FALSE
	repair_step(worker)
	TEST_ASSERT(QDELETED(effect), "Pausing a drone left its construction preview active")
	worker.enabled = TRUE
	repair_step(worker)
	effect = worker.work_effect
	worker.beforeShuttleMove(spot(2, 5), 0, MOVE_AREA, port)
	TEST_ASSERT(!QDELETED(effect), "Shuttle preflight deleted an effect while iterating turf contents")
	worker.afterShuttleMove(get_turf(worker), list(), SOUTH, SOUTH, SOUTH, 0)
	TEST_ASSERT(QDELETED(effect), "Shuttle transfer retained an obsolete repair preview")
	repair_step(worker)
	effect = worker.work_effect
	worker.work_finishes = world.time
	repair_step(worker)
	TEST_ASSERT_EQUAL(spot(1, 5).type, /turf/closed/wall, "Resumed construction did not finish its iron fallback")
	TEST_ASSERT_NULL(worker.work_effect, "Completed repair kept ownership of its animation")
	TEST_ASSERT_NULL(worker.work_beam, "Completed repair left its construction beam active")
	TEST_ASSERT_EQUAL(effect.icon_state, "rcd_end", "Successful repair did not play the RCD completion animation")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_before - 200, "Resumed construction charged more than once")
	qdel(effect)
	builder.console_upgrades |= (1<<9)
	hull.state = "idle"
	spot(1, 5).ChangeTurf(/turf/open/floor/iron)

/// Upgrade disks work independently on both console types and preserve redundant disks.
/datum/unit_test/voidcrew_construction_upgrades/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/list/standalone_disks = list(
		/obj/item/ship_construction_upgrade/servo/mk2 = 0.5,
		/obj/item/ship_construction_upgrade/servo/mk3 = 0.2,
		/obj/item/ship_construction_upgrade/servo/mk4 = 0,
		/obj/item/ship_construction_upgrade/area = 1,
		/obj/item/ship_construction_upgrade/repair = 1,
	)
	for(var/console_type in list(/obj/machinery/computer/camera_advanced/base_construction/ship, /obj/machinery/computer/camera_advanced/base_construction/ship/outpost))
		for(var/disk_type in standalone_disks)
			var/obj/machinery/computer/camera_advanced/base_construction/ship/console = allocate(console_type)
			var/base_rcd_delay = console.internal_rcd.delay_mod
			var/obj/item/ship_construction_upgrade/disk = allocate(disk_type)
			TEST_ASSERT_EQUAL(console.item_interaction(user, disk, list()), ITEM_INTERACT_SUCCESS, "[disk_type] could not install by itself on [console_type]")
			TEST_ASSERT(QDELETED(disk), "Successful standalone installation did not consume [disk_type]")
			TEST_ASSERT_EQUAL(console.get_build_speed_mod(), standalone_disks[disk_type], "Standalone [disk_type] applied the wrong fabrication speed")
			TEST_ASSERT_EQUAL(console.internal_rcd.delay_mod, base_rcd_delay * standalone_disks[disk_type], "Standalone [disk_type] did not update RCD speed")
			if(disk_type == /obj/item/ship_construction_upgrade/area)
				var/list/controls = console.construction_controls_data()
				TEST_ASSERT(controls["queueUnlocked"] && controls["areaUnlocked"], "Standalone area disk did not enable both the queue and brushes")
			qdel(console)
		// A partial overlap must not reject a disk that still adds capabilities.
		var/obj/machinery/computer/camera_advanced/base_construction/ship/console = allocate(console_type)
		var/obj/item/ship_construction_upgrade/queue/queue_disk = allocate(/obj/item/ship_construction_upgrade/queue)
		console.item_interaction(user, queue_disk, list())
		var/obj/item/ship_construction_upgrade/area/area_disk = allocate(/obj/item/ship_construction_upgrade/area)
		console.item_interaction(user, area_disk, list())
		TEST_ASSERT(QDELETED(area_disk), "An existing queue prevented the area disk from installing")
		queue_disk = allocate(/obj/item/ship_construction_upgrade/queue)
		TEST_ASSERT_EQUAL(console.item_interaction(user, queue_disk, list()), ITEM_INTERACT_FAILURE, "An area-enabled console accepted a redundant queue disk")
		TEST_ASSERT(!QDELETED(queue_disk), "Redundant queue disk was wasted")
		var/obj/item/ship_construction_upgrade/servo/servo_disk = allocate(/obj/item/ship_construction_upgrade/servo)
		console.item_interaction(user, servo_disk, list())
		servo_disk = allocate(/obj/item/ship_construction_upgrade/servo/mk3)
		console.item_interaction(user, servo_disk, list())
		TEST_ASSERT(QDELETED(servo_disk), "An existing mk1 prevented a direct upgrade to mk3")
		TEST_ASSERT_EQUAL(console.get_build_speed_mod(), 0.2, "Skipping mk2 did not apply mk3 speed")
		servo_disk = allocate(/obj/item/ship_construction_upgrade/servo/mk2)
		TEST_ASSERT_EQUAL(console.item_interaction(user, servo_disk, list()), ITEM_INTERACT_FAILURE, "Mk3 accepted a redundant slower disk")
		TEST_ASSERT(!QDELETED(servo_disk), "Redundant servo disk was wasted")
		TEST_ASSERT_EQUAL(console.get_build_speed_mod(), 0.2, "A slower disk downgraded the installed servos")
		qdel(console)

/// Advance one scheduler step without waiting for its cooldown in an instant-build test.
/datum/unit_test/voidcrew_construction_automation/proc/repair_step(obj/structure/ship_repair_drone/worker)
	for(var/key in builder.repair_records)
		var/datum/ship_repair_record/record = builder.repair_records[key]
		record.retry_after = 0
	worker.next_step = 0
	worker.process(0.5)

/datum/unit_test/voidcrew_construction_automation/proc/test_supply_aware_repairs(obj/structure/overmap/ship/hull, obj/structure/ship_repair_drone/worker)
	hull.state = "idle"
	for(var/dx in list(1, 3))
		var/turf/wall = spot(dx, 5).place_on_top(/turf/closed/wall/mineral/plastitanium)
		wall.baseturfs = list(/turf/open/space, /turf/baseturf_skipover/shuttle, /turf/open/floor/plating)
	hull.state = "flying"
	for(var/dx in list(1, 3))
		spot(dx, 5).ChangeTurf(/turf/open/space, list(/turf/open/space, /turf/baseturf_skipover/shuttle))
	TEST_ASSERT_EQUAL(length(builder.repair_records), 2, "Could not prepare paired wall breaches")
	worker.forceMove(spot(0, 1))
	var/turf/waiting_at = get_turf(worker)
	for(var/attempt in 1 to 4)
		repair_step(worker)
		TEST_ASSERT_EQUAL(get_turf(worker), waiting_at, "Unfunded drone travelled between unaffordable repairs")
		TEST_ASSERT_EQUAL(worker.status, "Waiting for materials", "Unfunded drone advertised travel or work")
	// Use titanium for the deck so the two available iron sheets can finish its wall.
	materials.insert_amount_mat(200, /datum/material/iron)
	materials.insert_amount_mat(50, /datum/material/titanium)
	worker.forceMove(spot(1, 4))
	repair_step(worker)
	TEST_ASSERT_EQUAL(spot(1, 5).type, /turf/open/floor/mineral/titanium, "Deck consumed materials needed for its wall")
	var/datum/ship_repair_record/first_record = builder.repair_records[builder.repair_coordinate_key(spot(1, 5))]
	TEST_ASSERT_EQUAL(first_record.claimed_by, worker, "Drone abandoned the wall after building its deck")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 200, "Deck spent the wall's iron")
	var/obj/structure/ship_repair_drone/other = allocate(/obj/structure/ship_repair_drone, spot(3, 4))
	other.console = builder
	builder.repair_drones += other
	repair_step(other)
	TEST_ASSERT(isspaceturf(spot(3, 5)), "Another worker consumed the started wall's materials")
	qdel(other)
	repair_step(worker)
	TEST_ASSERT_EQUAL(spot(1, 5).type, /turf/closed/wall, "Plastitanium wall did not fall back to available iron")
	TEST_ASSERT(isspaceturf(spot(3, 5)), "Worker left its first wall unfinished to lay another deck")
	TEST_ASSERT_NULL(worker.reserved_wall_materials, "Completed wall retained a material claim")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 0, "Fallback wall charged the wrong iron cost")
	// With no iron at all, both pieces can instead use titanium.
	materials.insert_amount_mat(250, /datum/material/titanium)
	worker.forceMove(spot(3, 4))
	repair_step(worker)
	TEST_ASSERT_EQUAL(spot(3, 5).type, /turf/open/floor/mineral/titanium, "Iron shortage blocked an affordable titanium deck")
	repair_step(worker)
	TEST_ASSERT_EQUAL(spot(3, 5).type, /turf/closed/wall/mineral/titanium, "Iron shortage blocked an affordable titanium wall")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/titanium), 0, "Titanium wall/deck pair charged the wrong cost")
	TEST_ASSERT_EQUAL(length(builder.repair_records), 0, "Completed wall pairs stayed queued")
	// Prefer the original material when both the original and iron are affordable.
	hull.state = "idle"
	var/turf/wall = spot(1, 5).ChangeTurf(/turf/closed/wall/mineral/plastitanium)
	wall.baseturfs = list(/turf/open/space, /turf/baseturf_skipover/shuttle, /turf/open/floor/plating)
	hull.state = "flying"
	wall.ChangeTurf(/turf/open/floor/plating)
	materials.insert_amount_mat(200, /datum/material/iron)
	materials.insert_amount_mat(100, /datum/material/titanium)
	materials.insert_amount_mat(100, /datum/material/plasma)
	worker.forceMove(spot(1, 4))
	repair_step(worker)
	TEST_ASSERT_EQUAL(spot(1, 5).type, /turf/closed/wall/mineral/plastitanium, "Drone downgraded an affordable original wall")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 200, "Original alloy wall also charged fallback iron")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/titanium), 0, "Original wall did not consume titanium")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/plasma), 0, "Original wall did not consume plasma")
	materials.use_amount_mat(200, /datum/material/iron)
	hull.state = "idle"
	for(var/dx in list(1, 3))
		spot(dx, 5).ChangeTurf(/turf/open/floor/iron)

/datum/unit_test/voidcrew_construction_automation/proc/test_repair_holofans(obj/structure/overmap/ship/hull, obj/structure/ship_repair_drone/worker)
	hull.state = "idle"
	var/turf/door_tile = spot(3, 5)
	var/obj/machinery/door/airlock/glass/door = allocate(/obj/machinery/door/airlock/glass, door_tile)
	door.req_access = list(ACCESS_ENGINEERING)
	hull.state = "flying"
	door.deconstruct(FALSE)
	var/key = builder.repair_coordinate_key(door_tile)
	var/datum/ship_repair_record/record = builder.repair_records[key]
	worker.forceMove(spot(3, 4))
	var/completed_before = worker.repaired
	repair_step(worker)
	var/obj/structure/holosign/barrier/atmos/fan = record.emergency_seal
	TEST_ASSERT_NOTNULL(fan, "Unfunded missing airlock did not receive a holofan")
	TEST_ASSERT_EQUAL(fan.can_atmos_pass, ATMOS_PASS_NO, "Emergency holofan does not block gas")
	TEST_ASSERT(!fan.density, "Emergency holofan blocks people")
	TEST_ASSERT_EQUAL(worker.repaired, completed_before, "Temporary seal counted as a permanent repair")
	var/turf/waiting_at = get_turf(worker)
	for(var/attempt in 1 to 3)
		repair_step(worker)
		TEST_ASSERT_EQUAL(record.emergency_seal, fan, "Repeated attempts duplicated the holofan")
		TEST_ASSERT_EQUAL(get_turf(worker), waiting_at, "Sealed, unfunded drone kept travelling")
	materials.insert_amount_mat(400, /datum/material/iron)
	repair_step(worker)
	var/obj/machinery/door/airlock/rebuilt_door = locate() in door_tile
	TEST_ASSERT_NOTNULL(rebuilt_door, "Refilling did not replace the temporary airlock seal")
	TEST_ASSERT_EQUAL(rebuilt_door.type, /obj/machinery/door/airlock, "Glass airlock did not fall back to affordable iron")
	TEST_ASSERT(ACCESS_ENGINEERING in rebuilt_door.req_access, "Fallback airlock lost its access requirements")
	TEST_ASSERT(QDELETED(fan), "Finished repair left its temporary holofan behind")
	TEST_ASSERT_EQUAL(length(builder.repair_records), 0, "Finished fallback airlock stayed queued")
	hull.state = "idle"
	qdel(rebuilt_door)
	var/turf/window_tile = spot(2, 5)
	var/obj/structure/window/reinforced/plasma/plastitanium/window = allocate(/obj/structure/window/reinforced/plasma/plastitanium, window_tile)
	window.set_anchored(TRUE)
	hull.state = "flying"
	window.deconstruct(FALSE)
	key = builder.repair_coordinate_key(window_tile)
	record = builder.repair_records[key]
	worker.forceMove(spot(2, 4))
	repair_step(worker)
	fan = record.emergency_seal
	TEST_ASSERT_NOTNULL(fan, "Unfunded missing window did not receive a holofan")
	builder.forget_repair_record(key)
	TEST_ASSERT(QDELETED(fan), "Canceling the repair left its temporary holofan behind")
	// Existing player holofans must survive both projection attempts and completion.
	hull.state = "idle"
	window = allocate(/obj/structure/window/reinforced/plasma/plastitanium, window_tile)
	window.set_anchored(TRUE)
	var/obj/structure/holosign/barrier/atmos/crew_fan = allocate(/obj/structure/holosign/barrier/atmos, window_tile)
	hull.state = "flying"
	window.deconstruct(FALSE)
	record = builder.repair_records[key]
	repair_step(worker)
	TEST_ASSERT_NULL(record.emergency_seal, "Drone adopted a crew holofan as its own")
	materials.insert_amount_mat(200, /datum/material/glass)
	repair_step(worker)
	var/obj/structure/window/rebuilt_window = locate() in window_tile
	TEST_ASSERT_NOTNULL(rebuilt_window, "Available plain glass did not repair an alloy window")
	TEST_ASSERT_EQUAL(rebuilt_window.type, /obj/structure/window/fulltile, "Alloy window did not fall back to plain glass")
	TEST_ASSERT(!QDELETED(crew_fan), "Completed repair deleted a crew holofan")
	TEST_ASSERT_EQUAL(length(builder.repair_records), 0, "Finished window fallback stayed queued")
	hull.state = "idle"
	qdel(rebuilt_window)

/// Exercise construction on the same indestructible deck used by outpost berths.
/datum/unit_test/voidcrew_construction_hangar
	parent_type = /datum/unit_test/voidcrew_hull_survey
	var/obj/machinery/computer/camera_advanced/base_construction/ship/automation_test/builder
	var/obj/docking_port/mobile/voidcrew/port
	var/area/voidcrew/outpost_hangar/hangar_area
	var/area/shuttle/voidcrew/hull_area

/datum/unit_test/voidcrew_construction_hangar/Destroy()
	QDEL_NULL(builder)
	if(port)
		qdel(port, force = TRUE)
	port = null
	evacuate_area(hull_area)
	evacuate_area(hangar_area)
	QDEL_NULL(hull_area)
	QDEL_NULL(hangar_area)
	return ..()

/datum/unit_test/voidcrew_construction_hangar/Run()
	TEST_ASSERT(reserved, "Could not reserve a test hangar")
	reset_block()
	hangar_area = new
	hull_area = new
	hull_area.setup("Construction test hull")
	for(var/turf/deck as anything in block(spot(2, 2), spot(10, 10)))
		deck.ChangeTurf(/turf/open/indestructible/dark/smooth_large, /turf/open/space)
		deck.change_area(get_area(deck), hangar_area)
	port = new(spot(4, 3))
	port.register()
	port.dir = NORTH
	port.shuttle_areas = list()
	port.shuttle_areas[hull_area] = TRUE
	for(var/turf/hull as anything in block(spot(3, 3), spot(5, 5)))
		hull.place_on_top(/turf/open/floor/plating)
		hull.insert_baseturf(turf_type = /turf/baseturf_skipover/shuttle)
		hull.change_area(hangar_area, hull_area)
		port.underlying_areas_by_turf[hull] = hangar_area
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
	TEST_ASSERT(builder.can_move_to(edge), "The drone cannot leave the hull onto adjacent hangar deck")
	TEST_ASSERT(builder.can_build_at(edge), "Adjacent hangar deck rejects construction")
	TEST_ASSERT(!builder.can_move_to(spot(7, 4)), "The drone can roam beyond the hull's adjacent tiles")
	TEST_ASSERT(!hull_claim_area_valid(edge), "Hull survey may absorb the outpost's bare deck")
	var/obj/machinery/light/floor/fixture = allocate(/obj/machinery/light/floor, edge)
	fixture.AddElement(/datum/element/outpost_property)
	TEST_ASSERT(!builder.can_build_at(edge), "Expansion may absorb a hangar fixture")
	qdel(fixture)

	// Direct construction uses the same floor predicate as the manual build action.
	TEST_ASSERT(rcd.build_floor(edge, engineer), "Direct floor construction rejected hangar deck")
	TEST_ASSERT(builder.expand_shuttle_to_turf(edge, engineer), "New flooring was not added to the hull")
	TEST_ASSERT(isshuttleturf(edge), "New flooring has no shuttle movement marker")
	TEST_ASSERT_EQUAL(port.underlying_areas_by_turf[edge], hangar_area, "Expansion lost the underlying hangar area")
	TEST_ASSERT(builder.can_move_to(spot(7, 4)), "The drone cannot follow the expanded hull")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 900, "Direct flooring charged the wrong material amount")

	// Queue auto mode must lay a floor, then advance onto the next adjacent deck tile.
	builder.build_size = 1
	builder.turf_build_mode = "auto"
	TEST_ASSERT(builder.queue_construction(spot(7, 4), engineer), "Hangar flooring could not be queued")
	var/datum/ship_construction_job/job = builder.construction_queue[1]
	TEST_ASSERT_EQUAL(job.kind, "floor", "Auto mode queued a wall on bare hangar deck")
	builder.process_construction_queue()
	TEST_ASSERT_EQUAL(length(builder.construction_queue), 0, "Hangar floor job did not finish")
	TEST_ASSERT(isshuttleturf(spot(7, 4)), "Queued flooring was not incorporated into the hull")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), 800, "Queued flooring charged the wrong material amount")

	// A breach retains its hull area while exposing the hangar deck below it.
	edge.ScrapeAway(edge.depth_to_find_baseturf(/turf/baseturf_skipover/shuttle))
	TEST_ASSERT_EQUAL(edge.type, /turf/open/indestructible/dark/smooth_large, "Removing new flooring destroyed the hangar deck")
	rcd.selected_floor_type = "Titanium Floor"
	TEST_ASSERT(rcd.build_floor(edge, engineer), "A breach over hangar deck could not be repaired")
	TEST_ASSERT(isshuttleturf(edge), "A repaired breach would be left behind when undocking")
	var/shuttle_markers = 0
	for(var/layer in edge.baseturfs)
		if(layer == /turf/baseturf_skipover/shuttle)
			shuttle_markers++
	TEST_ASSERT_EQUAL(shuttle_markers, 1, "Repairing hangar flooring duplicated the shuttle marker")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/titanium), 50, "Alloy flooring charged the wrong material amount")

	// Use the real turf movement callbacks to check which layers leave the berth.
	var/turf/destination = spot(11, 4)
	TEST_ASSERT(edge.fromShuttleMove(destination, MOVE_AREA) & MOVE_TURF, "New flooring is not eligible to move with the ship")
	edge.onShuttleMove(destination, list(), NORTH)
	destination.afterShuttleMove(edge, 0)
	TEST_ASSERT_EQUAL(destination.type, /turf/open/floor/mineral/titanium, "Undocking left the new ship floor behind")
	TEST_ASSERT_EQUAL(edge.type, /turf/open/indestructible/dark/smooth_large, "Undocking removed the hangar deck")
	TEST_ASSERT(!destination.depth_to_find_baseturf(/turf/open/indestructible/dark/smooth_large), "The ship carried away the hangar deck")

/datum/unit_test/voidcrew_construction_upgrade_salvage/Run()
	var/obj/machinery/computer/camera_advanced/base_construction/ship/console = allocate(/obj/machinery/computer/camera_advanced/base_construction/ship)
	var/mob/living/carbon/human/engineer = allocate(/mob/living/carbon/human/consistent)
	var/list/disk_types = list(/obj/item/ship_construction_upgrade/rpd, /obj/item/ship_construction_upgrade/servo/mk2, /obj/item/rcd_upgrade/frames, /obj/item/rpd_upgrade/unwrench)
	for(var/disk_type in disk_types)
		var/obj/item/disk = allocate(disk_type)
		console.item_interaction(engineer, disk, list())
		TEST_ASSERT(QDELETED(disk), "Installing [disk_type] did not consume the disk")
	TEST_ASSERT_EQUAL(length(console.installed_upgrade_types), length(disk_types), "Not all consumed disks were recorded")
	var/obj/item/duplicate = allocate(/obj/item/ship_construction_upgrade/servo/mk2)
	console.item_interaction(engineer, duplicate, list())
	TEST_ASSERT(!QDELETED(duplicate), "A duplicate upgrade disk was consumed")
	TEST_ASSERT_EQUAL(length(console.installed_upgrade_types), length(disk_types), "A rejected disk would be duplicated on deconstruction")
	qdel(duplicate)
	var/turf/drop = get_turf(console)
	console.deconstruct(TRUE)
	for(var/disk_type in disk_types)
		var/count = 0
		for(var/obj/item/disk in drop)
			if(disk.type == disk_type)
				count++
		TEST_ASSERT_EQUAL(count, 1, "Dismantling did not return exactly one [disk_type]")
