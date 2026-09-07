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
	qdel(paint_job)
	test_free_piping()
	test_queue_supply_and_failure()

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
	var/datum/action/innate/construction/ship/rpd_build/build = allocate(/datum/action/innate/construction/ship/rpd_build, builder)
	var/datum/action/innate/construction/ship/rpd_destroy/remove = allocate(/datum/action/innate/construction/ship/rpd_destroy, builder)
	build.Grant(engineer)
	remove.Grant(engineer)
	rcd.silo_link = FALSE
	var/iron_before = materials.get_material_amount(/datum/material/iron)
	build.Activate()
	var/list/pipes = list()
	for(var/obj/item/pipe/pipe in target_turf)
		pipes += pipe
	TEST_ASSERT_EQUAL(length(pipes), 2, "Free piping did not build both layers without a silo")
	remove.Activate()
	remove.Activate()
	TEST_ASSERT_NULL(locate(/obj/item/pipe) in target_turf, "Free pipe removal required a silo link")
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_before, "Free pipe placement or removal changed stored iron")
	rcd.silo_link = TRUE
	build.Activate()
	remove.Activate()
	remove.Activate()
	TEST_ASSERT_EQUAL(materials.get_material_amount(/datum/material/iron), iron_before, "Removing free pipes generated silo iron")
	engineer.remote_control = null

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
			var/obj/item/ship_construction_upgrade/disk = allocate(disk_type)
			TEST_ASSERT_EQUAL(console.item_interaction(user, disk, list()), ITEM_INTERACT_SUCCESS, "[disk_type] could not install by itself on [console_type]")
			TEST_ASSERT(QDELETED(disk), "Successful standalone installation did not consume [disk_type]")
			TEST_ASSERT_EQUAL(console.get_build_speed_mod(), standalone_disks[disk_type], "Standalone [disk_type] applied the wrong fabrication speed")
			TEST_ASSERT_EQUAL(console.internal_rcd.delay_mod, standalone_disks[disk_type], "Standalone [disk_type] did not update RCD speed")
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
