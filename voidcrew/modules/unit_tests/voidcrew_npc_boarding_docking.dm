// Voidcrew defines are included after unit tests; state/signal strings below mirror them.
// Supply a movement datum because the base controller's Destroy() expects one.
/datum/ai_controller/npc_ship/boarding_docking_test
	ai_movement = /datum/ai_movement/basic_avoidance

/datum/unit_test/voidcrew_npc_boarding_docking

/datum/unit_test/voidcrew_npc_boarding_docking/Run()
	var/obj/structure/overmap/ship/npc/pirate/pirate = allocate(/obj/structure/overmap/ship/npc/pirate)
	var/obj/structure/overmap/ship/target = allocate(/obj/structure/overmap/ship)
	var/datum/ai_controller/npc_ship/controller = allocate(/datum/ai_controller/npc_ship/boarding_docking_test, pirate)
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
