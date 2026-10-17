// Voidcrew defines are included after unit tests; state/signal strings below mirror them.
// Supply a movement datum because the base controller's Destroy() expects one.
/datum/ai_controller/npc_ship/boarding_docking_test
	ai_movement = /datum/ai_movement/basic_avoidance

/// Deterministic band and connected crew snapshot; the production accounting stays intact.
/datum/ai_controller/npc_ship/boarding_docking_test/profile
	var/datum/overmap_zone/test_zone
	var/test_crew = 3
	var/turf/test_floor

/datum/ai_controller/npc_ship/boarding_docking_test/profile/get_raid_zone(obj/structure/overmap/ship/target)
	return test_zone

/datum/ai_controller/npc_ship/boarding_docking_test/profile/count_player_crew(obj/structure/overmap/ship/target)
	return test_crew

/datum/ai_controller/npc_ship/boarding_docking_test/profile/get_target_spawn_turfs(obj/structure/overmap/ship/target)
	return test_floor ? list(test_floor) : list()

/datum/unit_test/voidcrew_npc_boarding_budget/Run()
	var/obj/structure/overmap/ship/npc/pirate/pirate = allocate(/obj/structure/overmap/ship/npc/pirate)
	var/obj/structure/overmap/ship/target = allocate(/obj/structure/overmap/ship)
	var/datum/ai_controller/npc_ship/boarding_docking_test/profile/controller = allocate(/datum/ai_controller/npc_ship/boarding_docking_test/profile, pirate)
	for(var/band in list(2, 3))
		for(var/timed_out in list(FALSE, TRUE))
			target.state = "flying"
			controller.test_zone = allocate(/datum/overmap_zone, band)
			controller.test_crew = 3
			controller.set_target(target)
			TEST_ASSERT_EQUAL(controller.boarding_budget, 3, "The raid did not capture one boarder per connected crew member")
			TEST_ASSERT_EQUAL(controller.get_boarding_wave_count(), 1, "A raid has more than one ordinary wave")
			controller.test_crew = 8
			controller.test_zone = allocate(/datum/overmap_zone, band == 2 ? 3 : 2)
			controller.capture_boarding_encounter(target)
			TEST_ASSERT_EQUAL(controller.boarding_context.zone_type, band, "Movement changed the captured band")
			TEST_ASSERT_EQUAL(controller.boarding_budget, 3, "Late arrivals changed the initial boarding budget")
			TEST_ASSERT_EQUAL(controller.reserve_boarders(target, 2), 2, "Combat pods could not reserve part of the wave")
			controller.cleanup_boarding_signals()
			TEST_ASSERT_EQUAL(controller.reserve_boarders(target, 10), 1, "Escalation replenished the ordinary budget")
			TEST_ASSERT_EQUAL(controller.reserve_boarders(target, 1), 0, "A later volley exceeded the engagement budget")
			controller.set_combat_state("boarding")
			controller.blackboard["npc_boarding_wave_boarders"] = list()
			if(timed_out)
				controller.handle_wave_timeout()
			else
				controller.check_wave_complete()
			TEST_ASSERT_EQUAL(controller.get_combat_state(), band == 3 ? "boarding_cooldown" : "idle", "Clearance/timeout took the wrong band transition")
			TEST_ASSERT_EQUAL(isnull(controller.get_target()), band != 3, "Yellow did not disengage or red lost its target")
			controller.clear_target()
	controller.test_crew = 0
	controller.set_target(target)
	TEST_ASSERT_EQUAL(controller.boarding_budget, 1, "An empty crew snapshot did not retain the minimum boarder")
	controller.clear_target()
	// A disconnected human with a mind is not connected crew.
	var/mob/living/carbon/human/consistent/disconnected = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	disconnected.mind_initialize()
	TEST_ASSERT_EQUAL(controller.count_living_crew(target), -1, "An unreadable hull was treated as a crew wipe")
	var/obj/docking_port/mobile/voidcrew/port = allocate(/obj/docking_port/mobile/voidcrew, run_loc_floor_bottom_left)
	port.shuttle_areas = list((get_area(disconnected)) = TRUE)
	target.shuttle = port
	var/already_listed = (disconnected in GLOB.player_list)
	GLOB.player_list |= disconnected
	var/living_count = controller.count_living_crew(target)
	if(!already_listed)
		GLOB.player_list -= disconnected
	target.shuttle = null
	port.shuttle_areas = list()
	qdel(port, force = TRUE)
	TEST_ASSERT_EQUAL(living_count, 0, "A disconnected body inflated the connected crew count")

/datum/npc_combat_interface/boarding_budget_test
	var/turf/test_floor

/datum/npc_combat_interface/boarding_budget_test/get_random_target_turf(obj/structure/overmap/ship/target_ship)
	return test_floor

/datum/unit_test/voidcrew_npc_boarding_volley_budget/Run()
	var/obj/structure/overmap/ship/npc/pirate/pirate = allocate(/obj/structure/overmap/ship/npc/pirate)
	pirate.boss_type = /mob/living/basic/trooper/pirate/faction/boss/silverscale
	pirate.boarding_pod_mob_types = list(/mob/living/basic/npc_zone_test)
	var/obj/structure/overmap/ship/target = allocate(/obj/structure/overmap/ship)
	var/datum/ai_controller/npc_ship/boarding_docking_test/profile/controller = allocate(/datum/ai_controller/npc_ship/boarding_docking_test/profile, pirate)
	var/datum/npc_combat_interface/boarding_budget_test/combat = allocate(/datum/npc_combat_interface/boarding_budget_test)
	combat.owner_ship = pirate
	combat.test_floor = run_loc_floor_bottom_left
	controller.test_floor = combat.test_floor
	for(var/band in list(2, 3))
		target.state = "flying"
		pirate.state = "flying"
		controller.test_zone = allocate(/datum/overmap_zone, band)
		controller.set_target(target)
		TEST_ASSERT(combat.fire_boarding_pods(target, 5, list(/mob/living/basic/npc_zone_test)), "Combat volley fixture did not launch")
		TEST_ASSERT_EQUAL(controller.boarding_pending, 3, "Combat volley exceeded the captured crew size")
		TEST_ASSERT(!combat.fire_boarding_pods(target, 5), "An overlapping volley exceeded the reserved budget")
		controller.escalate_to_full_combat(target)
		TEST_ASSERT_EQUAL(controller.boarding_pending, 0, "Escalation retained cancelled reservations")
		TEST_ASSERT_EQUAL(controller.boarding_committed, 0, "Escalation spent pods it cancelled")
		TEST_ASSERT(combat.fire_boarding_pods(target, 5, list(/mob/living/basic/npc_zone_test)), "Cancelled pods did not return to the same engagement budget")
		// Execute the actual callbacks directly, after cancelling their timers.
		for(var/timer_id in controller.boarding_timers)
			deltimer(timer_id)
		controller.boarding_timers.Cut()
		for(var/i in 1 to 3)
			var/mob/living/boarder = controller.deploy_combat_boarder(combat.test_floor, target, /mob/living/basic/npc_zone_test, controller.boarding_context)
			TEST_ASSERT_NOTNULL(boarder, "A reserved combat pod lost its encounter")
			TEST_ASSERT_EQUAL(boarder.npc_spawn_context.zone_type, band, "Combat pod used a different band")
		TEST_ASSERT_EQUAL(controller.boarding_pending, 0, "Deployed pods retained reservations")
		TEST_ASSERT_EQUAL(combat.fire_boarding_pods(target, 5), band == 3, "Exhausting the ordinary budget took the wrong boss transition")
		TEST_ASSERT(!combat.fire_boarding_pods(target, 5), "A later combat volley replenished the budget or boss")
		target.state = "idle"
		for(var/obj/effect/pod_landingzone/boarding/landing in combat.test_floor)
			landing.cancel_if_target_docked()
		controller.clear_target()
		// The scripted route spends the same budget and cannot launch another wave.
		target.state = "flying"
		controller.set_target(target)
		controller.set_combat_state("boarding")
		TEST_ASSERT(controller.launch_boarding_wave(1), "The scripted boarding fixture did not launch")
		TEST_ASSERT_EQUAL(length(controller.blackboard["npc_boarding_wave_boarders"]), 3, "Scripted raid did not launch exactly one boarder per initial crew")
		TEST_ASSERT_EQUAL(controller.boarding_committed, 3, "Scripted raid escaped shared engagement accounting")
		var/obj/effect/cleanup_probe = allocate(/obj/effect, combat.test_floor)
		controller.set_blackboard_key("boarding_cleanup_probe", cleanup_probe)
		qdel(cleanup_probe)
		TEST_ASSERT_NULL(controller.blackboard["boarding_cleanup_probe"], "Deleting a tracked object did not clear its blackboard key")
		var/list/initial_position = controller.blackboard["npc_boarding_target_pos"]
		TEST_ASSERT_EQUAL(initial_position["x"], target.x, "Blackboard cleanup changed the boarding target's x coordinate")
		TEST_ASSERT_EQUAL(initial_position["y"], target.y, "Blackboard cleanup changed the boarding target's y coordinate")
		TEST_ASSERT(!controller.launch_boarding_wave(2), "A second ordinary wave was allowed")
		TEST_ASSERT(!combat.fire_boarding_pods(target, 5, list(/mob/living/basic/npc_zone_test)) || band == 3, "Combat replenished a scripted raid's ordinary budget")
		target.state = "idle"
		for(var/obj/effect/pod_landingzone/boarding/landing in combat.test_floor)
			landing.cancel_if_target_docked()
		controller.clear_target()

/datum/unit_test/voidcrew_npc_boarding_docking

/datum/unit_test/voidcrew_npc_boarding_docking/Run()
	var/obj/structure/overmap/ship/npc/pirate/pirate = allocate(/obj/structure/overmap/ship/npc/pirate)
	var/obj/structure/overmap/ship/target = allocate(/obj/structure/overmap/ship)
	var/datum/ai_controller/npc_ship/boarding_docking_test/profile/controller = allocate(/datum/ai_controller/npc_ship/boarding_docking_test/profile, pirate)
	controller.test_zone = allocate(/datum/overmap_zone, 3)
	var/datum/ai_planning_subtree/npc_ship_combat/planner = allocate(/datum/ai_planning_subtree/npc_ship_combat)

	for(var/ship_state in list("docking", "idle", "undocking"))
		for(var/combat_state in list("boarding", "boarding_cooldown", "boss_phase"))
			target.state = "flying"
			controller.set_target(target)
			TEST_ASSERT(controller.start_boarding_phase(), "Flying ships should be able to start a boarding encounter")
			var/list/pending_timers = controller.boarding_timers.Copy()
			TEST_ASSERT(length(pending_timers), "The encounter must have delayed actions to cancel")
			controller.set_combat_state(combat_state)
			target.state = ship_state
			planner.SelectBehaviors(controller, 1)
			TEST_ASSERT_NULL(controller.get_target(), "[combat_state] must release a target that is [ship_state]")
			TEST_ASSERT_EQUAL(controller.get_combat_state(), "idle", "Docking must end the combat encounter")
			TEST_ASSERT_NULL(target.engaging_pirate_ref, "Docking must release the pirate's engagement claim")
			TEST_ASSERT_EQUAL(length(controller.boarding_timers), 0, "Docking must clear delayed boarding actions")
			for(var/timer_id in pending_timers)
				TEST_ASSERT(!SStimer.timer_id_dict[timer_id], "A cancelled encounter must not retain a live boarding timer")

	// A timer can fire after docking starts but before the next planning pass.
	target.state = "flying"
	controller.set_target(target)
	TEST_ASSERT(controller.start_boarding_phase(), "The next encounter should start normally")
	target.state = "docking"
	TEST_ASSERT(!controller.launch_boarding_wave(1), "A delayed wave must not launch after docking starts")
	TEST_ASSERT_NULL(controller.get_target(), "A delayed wave must abort the docked encounter")

	target.state = "flying"
	controller.set_target(target)
	controller.start_boss_cooldown()
	TEST_ASSERT_EQUAL(controller.get_combat_state(), "boarding_cooldown", "The red encounter did not schedule a boss")
	target.state = "idle"
	controller.spawn_boarding_boss()
	TEST_ASSERT_NULL(controller.get_target(), "A delayed boss must abort the docked encounter")
	TEST_ASSERT_EQUAL(controller.get_combat_state(), "idle", "A docked target must not enter the boss phase")

	// Already-landed boarders survive encounter cleanup.
	var/mob/living/boarder = allocate(/mob/living/basic/carp)
	controller.blackboard["npc_boarding_wave_boarders"] = list(boarder)
	controller.clear_target()
	TEST_ASSERT(!QDELETED(boarder), "Disengaging must leave boarders already aboard alive")

/datum/unit_test/voidcrew_npc_boarding_pod_docking
	var/boarding_signals = 0

/datum/unit_test/voidcrew_npc_boarding_pod_docking/proc/on_boarded()
	SIGNAL_HANDLER
	boarding_signals++

/datum/unit_test/voidcrew_npc_boarding_pod_docking/Run()
	var/obj/structure/overmap/ship/npc/pirate/pirate = allocate(/obj/structure/overmap/ship/npc/pirate)
	var/obj/structure/overmap/ship/target = allocate(/obj/structure/overmap/ship)
	var/datum/npc_combat_interface/combat = allocate(/datum/npc_combat_interface)
	combat.owner_ship = pirate
	RegisterSignal(target, "ship_boarded", PROC_REF(on_boarded))

	for(var/ship_state in list("docking", "idle", "undocking"))
		target.state = ship_state
		TEST_ASSERT(!combat.fire_boarding_pods(target), "Combat volleys must reject a target that is [ship_state]")
		TEST_ASSERT_NULL(create_boarding_pod(run_loc_floor_bottom_left, target, pirate, /mob/living/basic/carp), "Delayed pods must reject a target that is [ship_state]")
		TEST_ASSERT_NULL(create_boss_boarding_pod(run_loc_floor_bottom_left, target, pirate, /mob/living/basic/trooper/pirate/faction/boss/silverscale), "Boss pods must reject a target that is [ship_state]")

	// Both ordinary and boss pods must cancel before impact, including mid-animation.
	for(var/pod_type in list(/obj/structure/closet/supplypod/boarding, /obj/structure/closet/supplypod/boarding/boss))
		for(var/during_fall in list(FALSE, TRUE))
			target.state = "flying"
			var/obj/structure/closet/supplypod/boarding/pod = allocate(pod_type)
			pod.target_ship = target
			pod.source_ship = pirate
			var/mob/living/boarder = allocate(/mob/living/basic/carp, pod)
			pod.boarder_ref = WEAKREF(boarder)
			var/obj/effect/pod_landingzone/boarding/landing = allocate(/obj/effect/pod_landingzone/boarding, run_loc_floor_bottom_left, pod, target, pirate)
			var/obj/effect/pod_landingzone_effect/helper = landing.helper
			TEST_ASSERT(!landing.cancel_if_target_docked(), "Flying targets must allow inbound pods")
			if(during_fall)
				landing.beginLaunch(FALSE)
			target.state = "idle"
			if(during_fall)
				landing.endLaunch()
			else
				landing.beginLaunch(FALSE)
			TEST_ASSERT(QDELETED(landing), "Docking must remove the inbound landing zone")
			TEST_ASSERT(QDELETED(helper), "Docking must remove the landing indicator")
			TEST_ASSERT(QDELETED(pod), "Docking must cancel the inbound pod")
			TEST_ASSERT(QDELETED(boarder), "A cancelled pod must not release its boarder")
			TEST_ASSERT_EQUAL(boarding_signals, 0, "Cancelling a pod must not announce a successful boarding")
