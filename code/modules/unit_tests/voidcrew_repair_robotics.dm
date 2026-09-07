/// Exercise the same reversible component and consumed parts used by player assembly.
/datum/unit_test/voidcrew_repair_robotics/Run()
	var/datum/techweb/research = allocate(/datum/techweb)
	var/datum/techweb_node/swarm = SSresearch.techweb_node_by_id("ship_repair_swarm")
	TEST_ASSERT_NOTNULL(swarm, "Repair swarm research is missing")
	research.researched_nodes = list("ship_automation" = TRUE, TECHWEB_NODE_ROBOTICS = TRUE, TECHWEB_NODE_MECH_ASSEMBLY = TRUE)
	for(var/required_node in list(TECHWEB_NODE_ROBOTICS, TECHWEB_NODE_MECH_ASSEMBLY))
		research.researched_nodes -= required_node
		research.update_node_status(swarm)
		TEST_ASSERT(!research.available_nodes[swarm.id], "Repair swarm research bypassed [required_node]")
		research.researched_nodes[required_node] = TRUE
	research.update_node_status(swarm)
	TEST_ASSERT(research.available_nodes[swarm.id], "Repair swarm unavailable after all prerequisites")
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/ship_repair_drone_part/chassis/frame = allocate(/obj/item/ship_repair_drone_part/chassis)
	frame.setDir(EAST)
	var/datum/component/construction/assembly = frame.GetComponent(/datum/component/construction/ship_repair_drone)
	TEST_ASSERT_NOTNULL(assembly, "Robotics chassis has no assembly component")
	var/obj/item/ship_repair_drone_part/controller/board = allocate(/obj/item/ship_repair_drone_part/controller)
	user.put_in_hands(board)
	TEST_ASSERT(!assembly.check_step(board, user), "Controller bypassed missing propulsion and arm")
	user.dropItemToGround(board)
	var/obj/item/ship_repair_drone_part/propulsion/drive = allocate(/obj/item/ship_repair_drone_part/propulsion)
	user.put_in_hands(drive)
	TEST_ASSERT(assembly.check_step(drive, user), "Propulsion unit could not be fitted")
	TEST_ASSERT(QDELETED(drive), "Fitted propulsion part was not consumed")
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar)
	crowbar.toolspeed = 0
	TEST_ASSERT(assembly.check_step(crowbar, user), "Assembly could not be reversed")
	drive = locate() in get_turf(frame)
	TEST_ASSERT_NOTNULL(drive, "Reversing assembly did not return the propulsion unit")
	user.put_in_hands(drive)
	TEST_ASSERT(assembly.check_step(drive, user), "Returned propulsion could not be refitted")
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	wrench.toolspeed = 0
	TEST_ASSERT(assembly.check_step(wrench, user), "Propulsion could not be secured")
	var/obj/item/ship_repair_drone_part/arm/arm = allocate(/obj/item/ship_repair_drone_part/arm)
	user.put_in_hands(arm)
	TEST_ASSERT(assembly.check_step(arm, user), "Fabricator arm could not be fitted")
	var/obj/item/stack/cable_coil/cable = allocate(/obj/item/stack/cable_coil, null, 4)
	TEST_ASSERT(!assembly.check_step(cable, user), "Four cable lengths paid for five")
	cable.add(1)
	TEST_ASSERT(assembly.check_step(cable, user), "Five cables could not wire the drone")
	user.put_in_hands(board)
	TEST_ASSERT(assembly.check_step(board, user), "Controller could not be installed")
	var/obj/item/screwdriver/screwdriver = allocate(/obj/item/screwdriver)
	screwdriver.toolspeed = 0
	var/turf/build_location = get_turf(frame)
	TEST_ASSERT(assembly.check_step(screwdriver, user), "Final screwdriver step failed")
	var/obj/structure/ship_repair_drone/drone = locate() in build_location
	TEST_ASSERT_NOTNULL(drone, "Completed chassis did not produce a drone")
	TEST_ASSERT_EQUAL(drone.dir, EAST, "Completing assembly changed the drone's facing")
	TEST_ASSERT_NULL(drone.console, "Newly assembled drone linked itself to an arbitrary ship")
	TEST_ASSERT(!(drone in SSship_repairs.workers), "Unlinked drone was scheduled for work")
	qdel(drone)
	test_timed_assembly(user)

/datum/unit_test/voidcrew_repair_linking/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/structure/ship_repair_drone/drone = allocate(/obj/structure/ship_repair_drone)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/automation_test/builder = allocate(/obj/machinery/computer/camera_advanced/base_construction/ship/automation_test)
	var/obj/docking_port/mobile/port = new(get_turf(builder))
	port.register()
	port.shuttle_areas = list(get_area(builder) = TRUE)
	builder.test_port = port
	var/obj/machinery/ore_silo/silo = allocate(/obj/machinery/ore_silo)
	var/obj/item/multitool/tool = allocate(/obj/item/multitool)
	user.set_combat_mode(FALSE)
	user.put_in_active_hand(tool, forced = TRUE)
	var/health_before = drone.get_integrity()
	tool.melee_attack_chain(user, drone)
	TEST_ASSERT_NULL(drone.console, "Empty multitool linked an arbitrary console")
	TEST_ASSERT_EQUAL(drone.get_integrity(), health_before, "Failed multitool linking damaged the drone")
	// A fresh console must be copyable; crew access is checked when linking the drone.
	var/console_health_before = builder.get_integrity()
	tool.melee_attack_chain(user, builder)
	TEST_ASSERT_EQUAL(tool.buffer, builder, "Fresh console could not be saved to an empty multitool")
	TEST_ASSERT_EQUAL(builder.get_integrity(), console_health_before, "Saving a fresh console hit it instead")
	tool.set_buffer(null)
	tool.melee_attack_chain(user, builder)
	TEST_ASSERT_EQUAL(tool.buffer, builder, "Saving a console required crew authorization")
	tool.melee_attack_chain(user, drone)
	TEST_ASSERT_NULL(drone.console, "Saved reference bypassed crew authorization")
	builder.test_operator = user
	tool.set_buffer(silo)
	tool.melee_attack_chain(user, builder)
	TEST_ASSERT_EQUAL(builder.get_linked_silo(), silo, "Multitool did not link the console's silo")
	TEST_ASSERT_EQUAL(tool.buffer, builder, "Silo linking did not save the repair controller")
	tool.melee_attack_chain(user, drone)
	TEST_ASSERT_EQUAL(drone.console, builder, "Multitool could not link the completed drone")
	TEST_ASSERT(drone in builder.repair_drones, "Linked drone missing from console controls")
	TEST_ASSERT(!builder.repair_tracking, "Unupgraded console armed damage monitoring")
	TEST_ASSERT_NULL(builder.repair_origin, "Unupgraded console allocated a repair origin")
	TEST_ASSERT_NULL(port.ship_repair_controller, "Pairing to an unupgraded console claimed the ship's repair controller")
	TEST_ASSERT(!builder.set_repair_tracking(TRUE), "Unupgraded console enabled monitoring")
	TEST_ASSERT(!builder.repair_control_act("repair_toggle", list(), user), "Unupgraded console enabled its swarm")
	SSship_repairs.workers |= drone
	drone.next_step = 0
	drone.process(0.5)
	TEST_ASSERT_EQUAL(drone.status, "Console upgrade required", "Unupgraded console did not keep its linked drone idle")
	TEST_ASSERT(!(drone in SSship_repairs.workers), "Unupgraded console kept an idle drone scheduled")
	TEST_ASSERT_EQUAL(drone.console, builder, "Missing console upgrade unlinked the drone")
	// Installing the control disk later must enable the already-paired swarm.
	var/obj/item/ship_construction_upgrade/repair/repair_disk = allocate(/obj/item/ship_construction_upgrade/repair)
	builder.item_interaction(user, repair_disk, list())
	TEST_ASSERT(QDELETED(repair_disk), "Console could not install its repair upgrade")
	TEST_ASSERT(!(builder.console_upgrades & (1<<6)), "Repair upgrade unexpectedly installed the manual job queue")
	TEST_ASSERT(builder.repair_tracking, "Upgrading the console did not arm its already-linked swarm")
	TEST_ASSERT(builder.repair_control_act("repair_toggle", list(), user), "Upgraded console could not deploy its linked swarm")
	TEST_ASSERT(builder.repair_enabled, "Upgraded console left its swarm disabled")
	tool.melee_attack_chain(user, drone)
	TEST_ASSERT_EQUAL(length(builder.repair_drones), 1, "Repeated multitool linking duplicated drone")
	drone.unlink_console()
	builder.set_repair_tracking(FALSE)
	tool.melee_attack_chain(user, drone)
	TEST_ASSERT_EQUAL(drone.console, builder, "Upgraded console could not accept a new drone link")
	TEST_ASSERT(builder.repair_tracking, "Linking to an upgraded console did not arm monitoring")
	builder.clear_repair_journal(TRUE)
	builder.test_port = null
	qdel(port, force = TRUE)

/// Exercise the player click path, real delay, cancellation, and combat fallback.
/datum/unit_test/voidcrew_repair_robotics/proc/test_timed_assembly(mob/living/carbon/human/user)
	var/turf/start = get_turf(user)
	var/obj/item/ship_repair_drone_part/chassis/frame = allocate(/obj/item/ship_repair_drone_part/chassis, start)
	var/datum/component/construction/ship_repair_drone/assembly = frame.GetComponent(/datum/component/construction/ship_repair_drone)
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	user.put_in_active_hand(wrench, forced = TRUE)
	var/health_before = frame.get_integrity()
	wrench.melee_attack_chain(user, frame)
	TEST_ASSERT_EQUAL(frame.get_integrity(), health_before, "Noncombat wrenching an empty chassis damaged it")
	var/obj/item/ship_repair_drone_part/propulsion/drive = allocate(/obj/item/ship_repair_drone_part/propulsion)
	user.put_in_active_hand(drive, forced = TRUE)
	drive.melee_attack_chain(user, frame)
	TEST_ASSERT_EQUAL(assembly.index, 2, "Player click did not fit propulsion")
	user.put_in_active_hand(wrench, forced = TRUE)
	wrench.melee_attack_chain(user, frame)
	TEST_ASSERT(assembly.working && assembly.index == 2, "Wrench step did not start a timed action")
	TEST_ASSERT_EQUAL(frame.get_integrity(), health_before, "Timed wrench click also hit the chassis")
	sleep(1)
	user.forceMove(get_step(start, NORTH))
	sleep(3 SECONDS)
	TEST_ASSERT_EQUAL(assembly.index, 2, "Cancelled wrench action advanced assembly")
	user.forceMove(start)
	wrench.melee_attack_chain(user, frame)
	wrench.melee_attack_chain(user, frame)
	sleep(3 SECONDS)
	TEST_ASSERT_EQUAL(assembly.index, 3, "Timed wrench action failed or advanced twice")
	TEST_ASSERT(!assembly.working, "Completed wrench action left the chassis locked")
	user.set_combat_mode(TRUE)
	wrench.melee_attack_chain(user, frame)
	TEST_ASSERT(frame.get_integrity() < health_before, "Combat wrench hit was swallowed by assembly")
	user.set_combat_mode(FALSE)

/// Use player melee and projectile paths, including destruction of a busy worker.
/datum/unit_test/voidcrew_repair_drone_combat/Run()
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/storage/toolbox/toolbox = allocate(/obj/item/storage/toolbox)
	attacker.put_in_active_hand(toolbox, forced = TRUE)
	attacker.set_combat_mode(TRUE)
	for(var/part_type in subtypesof(/obj/item/ship_repair_drone_part))
		var/obj/item/ship_repair_drone_part/part = allocate(part_type)
		var/integrity_before = part.get_integrity()
		toolbox.melee_attack_chain(attacker, part)
		TEST_ASSERT(part.get_integrity() < integrity_before, "[part_type] ignored a player's melee attack")
		for(var/hit in 1 to 20)
			if(QDELETED(part))
				break
			toolbox.melee_attack_chain(attacker, part)
		TEST_ASSERT(QDELETED(part), "[part_type] could not be destroyed")

	// An assembly with consumed parts remains vulnerable, too.
	var/obj/item/ship_repair_drone_part/chassis/frame = allocate(/obj/item/ship_repair_drone_part/chassis)
	var/datum/component/construction/assembly = frame.GetComponent(/datum/component/construction/ship_repair_drone)
	var/obj/item/ship_repair_drone_part/propulsion/drive = allocate(/obj/item/ship_repair_drone_part/propulsion)
	attacker.put_in_hands(drive)
	TEST_ASSERT(assembly.check_step(drive, attacker), "Could not prepare an incomplete drone")
	for(var/hit in 1 to 20)
		if(QDELETED(frame))
			break
		toolbox.melee_attack_chain(attacker, frame)
	TEST_ASSERT(QDELETED(frame), "An incomplete drone could not be destroyed")
	TEST_ASSERT(QDELETED(assembly), "Destroyed chassis retained its construction component")

	var/obj/machinery/computer/camera_advanced/base_construction/ship/builder = allocate(/obj/machinery/computer/camera_advanced/base_construction/ship)
	var/obj/structure/ship_repair_drone/drone = allocate(/obj/structure/ship_repair_drone)
	drone.console = builder
	builder.repair_drones += drone
	var/datum/ship_repair_record/record = allocate(/datum/ship_repair_record)
	SSship_repairs.record_count++
	builder.repair_records["combat"] = record
	record.claimed_by = drone
	drone.job = record
	var/obj/effect/constructing_effect/ship_repair/effect = new(get_turf(drone), 3 SECONDS, /turf/closed/wall, SOUTH)
	drone.work_effect = effect
	var/datum/beam/beam = drone.Beam(effect, icon_state = "rped_upgrade")
	drone.work_beam = beam
	SSship_repairs.workers |= drone
	var/integrity_before = drone.get_integrity()
	toolbox.melee_attack_chain(attacker, drone)
	TEST_ASSERT(drone.get_integrity() < integrity_before, "Completed drone ignored a player's melee attack")

	// Nondense hovering drones must still be valid targets when directly aimed at.
	for(var/shot in 1 to 10)
		if(QDELETED(drone))
			break
		var/obj/projectile/bullet/c9mm/bullet = allocate(/obj/projectile/bullet/c9mm, get_turf(drone))
		bullet.firer = attacker
		bullet.original = drone
		TEST_ASSERT(bullet.can_hit_target(drone, direct_target = TRUE), "Aimed bullets could not hit the hovering drone")
		TEST_ASSERT_EQUAL(drone.bullet_act(bullet), BULLET_ACT_HIT, "Drone blocked a bullet without taking damage")
	TEST_ASSERT(QDELETED(drone), "Gunfire could not destroy the drone")
	TEST_ASSERT(QDELETED(effect) && QDELETED(beam), "Destroying a working drone left its construction effects behind")
	TEST_ASSERT_EQUAL(length(builder.repair_drones), 0, "Destroyed drone stayed linked to its console")
	TEST_ASSERT(!(drone in SSship_repairs.workers), "Destroyed drone stayed in the work scheduler")
	TEST_ASSERT_NULL(record.claimed_by, "Destroyed drone kept its repair claim")
	TEST_ASSERT(!QDELETED(record), "Destroying a drone discarded work another drone could finish")

/// Exercise the real soft-cordon gate without dumping test objects onto live maps.
/datum/turf_reservation/transit/repair_drone_test
	var/dump_count = 0

/datum/turf_reservation/transit/repair_drone_test/space_dump(atom/source, atom/movable/enterer)
	dump_count++

/datum/unit_test/voidcrew_repair_hyperspace/Run()
	var/turf/start = run_loc_floor_bottom_left
	var/turf/open/space/transit/transit = get_step(start, NORTHEAST).ChangeTurf(/turf/open/space/transit)
	var/turf/space = get_step(transit, EAST).ChangeTurf(/turf/open/space)
	var/obj/structure/ship_repair_drone/drone = allocate(/obj/structure/ship_repair_drone, start)
	drone.forceMove(transit)
	var/datum/component/shuttle_cling/cling = drone.GetComponent(/datum/component/shuttle_cling)
	TEST_ASSERT_NOTNULL(cling, "Transit entry did not exercise hyperspace drift")
	TEST_ASSERT_NULL(cling.hyperloop, "Hyperspace started dragging the repair drone")
	TEST_ASSERT_NULL(drone.throwing, "Hyperspace launched the repair drone as debris")
	TEST_ASSERT_EQUAL(get_turf(drone), transit, "Hyperspace displaced the repair drone")
	var/datum/turf_reservation/transit/repair_drone_test/reservation = allocate(/datum/turf_reservation/transit/repair_drone_test)
	reservation.space_dump_soft(transit, drone)
	TEST_ASSERT_EQUAL(reservation.dump_count, 0, "Transit's soft cordon dumped a repair drone")
	var/obj/item/stack/rods/debris = allocate(/obj/item/stack/rods, start)
	reservation.space_dump_soft(transit, debris)
	TEST_ASSERT_EQUAL(reservation.dump_count, 1, "Ordinary debris bypassed the soft cordon")
	drone.forceMove(space)
	TEST_ASSERT_EQUAL(get_turf(drone), space, "Crossing from transit into a breach dumped the repair drone")
	TEST_ASSERT_NULL(drone.GetComponent(/datum/component/shuttle_cling), "Leaving transit retained its drift component")
	var/obj/structure/ship_repair_drone/spawned = allocate(/obj/structure/ship_repair_drone, transit)
	TEST_ASSERT_NULL(spawned.throwing, "A drone spawned in transit was launched before acquiring immunity")
	TEST_ASSERT(spawned.hypotheticalShuttleMove(0, MOVE_AREA, null) & MOVE_CONTENTS, "A drone over a breached deck was omitted from the shuttle move plan")
	TEST_ASSERT(spawned.beforeShuttleMove(start, 0, MOVE_AREA, null) & MOVE_CONTENTS, "A drone over a breached deck would be left behind on arrival")
	TEST_ASSERT_EQUAL(spawned.beforeShuttleMove(start, 0, NONE, null), NONE, "A drone outside the moving ship moved with it")
	spawned.lateShuttleMove(start, list("THROW" = 5), SOUTH)
	TEST_ASSERT_NULL(spawned.throwing, "Ship acceleration threw the repair drone into hyperspace")
	qdel(spawned)
	qdel(drone)
	transit.ChangeTurf(/turf/open/floor/plating)
	space.ChangeTurf(/turf/open/floor/plating)

/// 70 busy ships must share the budget; it must not multiply by fleet size.
/obj/structure/ship_repair_drone/budget_test
	var/steps = 0

/obj/structure/ship_repair_drone/budget_test/process(seconds_per_tick)
	steps++

/datum/unit_test/voidcrew_repair_fleet_budget/Run()
	var/list/saved_workers = SSship_repairs.workers
	var/saved_cursor = SSship_repairs.worker_cursor
	SSship_repairs.workers = list()
	SSship_repairs.worker_cursor = 1
	for(var/index in 1 to 70)
		SSship_repairs.workers += allocate(/obj/structure/ship_repair_drone/budget_test)
	SSship_repairs.fire(FALSE)
	while(SSship_repairs.steps_left > 0)
		SSship_repairs.fire(TRUE)
	var/total_steps = 0
	for(var/obj/structure/ship_repair_drone/budget_test/drone as anything in SSship_repairs.workers)
		total_steps += drone.steps
	TEST_ASSERT_EQUAL(total_steps, 32, "Global repair work limit grew with the fleet")
	// Subsequent fires advance through the fleet instead of starving later ships.
	for(var/pass in 1 to 2)
		SSship_repairs.fire(FALSE)
		while(SSship_repairs.steps_left > 0)
			SSship_repairs.fire(TRUE)
	for(var/obj/structure/ship_repair_drone/budget_test/drone as anything in SSship_repairs.workers)
		TEST_ASSERT(drone.steps > 0, "A late ship was starved by the fleet scheduler")
	SSship_repairs.workers = saved_workers
	SSship_repairs.worker_cursor = saved_cursor
