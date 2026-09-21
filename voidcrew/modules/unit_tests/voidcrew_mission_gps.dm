/// Keep the board's GPS upload path physical without constructing a ship interior for this test.
/obj/machinery/computer/mission_board/mission_gps_test
	var/obj/structure/overmap/ship/test_ship

/obj/machinery/computer/mission_board/mission_gps_test/get_ship()
	return test_ship

/datum/unit_test/voidcrew_mission_mod_gps/Run()
	var/obj/machinery/computer/mission_board/mission_gps_test/board = allocate(__IMPLIED_TYPE__)
	board.test_ship = allocate(/obj/structure/overmap/ship)
	board.set_machine_stat(NONE)
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__)
	var/obj/item/mod/control/suit = allocate(__IMPLIED_TYPE__)
	var/obj/item/mod/module/gps/module = allocate(__IMPLIED_TYPE__)
	suit.install(module)
	var/datum/component/gps/item/mod_gps = module.GetComponent(/datum/component/gps/item)
	TEST_ASSERT_NOTNULL(mod_gps, "A real MOD GPS module must own a GPS component.")
	TEST_ASSERT_NULL(board.get_worn_mod_gps(user), "A nearby suit must not count as the user's worn GPS.")
	user.equip_to_slot_or_del(suit, ITEM_SLOT_BACK)
	TEST_ASSERT_EQUAL(board.get_worn_mod_gps(user), mod_gps, "The board must find the module inside the worn suit.")

	var/datum/mission/mission = allocate(/datum/mission)
	mission.gps_tag = "Unit Test Specimen"
	board.test_ship.active_missions += mission
	var/obj/item/target = allocate(/obj/item)
	mission.quest_atom = target
	var/obj/item/gps/handheld = allocate(__IMPLIED_TYPE__)
	var/datum/component/gps/item/other_gps = handheld.GetComponent(/datum/component/gps/item)

	TEST_ASSERT(board.link_worn_mod_gps(user), "A nearby wearer should be able to link their installed GPS.")
	var/datum/weakref/uploaded_target = mod_gps.linked_mission_signals[mission.gps_tag]
	TEST_ASSERT_EQUAL(uploaded_target?.resolve(), target, "The installed GPS must track the mission's actual target.")
	TEST_ASSERT(!length(other_gps.linked_mission_signals), "The upload must not broadcast to an unrelated nearby GPS.")
	TEST_ASSERT_EQUAL(module.loc, suit, "Linking must leave the GPS module installed.")
	TEST_ASSERT_EQUAL(suit.wearer, user, "Linking must leave the suit equipped.")

	mission.clear_gps_signals()
	board.set_machine_stat(NOPOWER)
	TEST_ASSERT(!board.link_worn_mod_gps(user), "A board without power must not upload mission beacons.")
	TEST_ASSERT(!length(mod_gps.linked_mission_signals), "A rejected upload must leave the GPS unchanged.")
	board.set_machine_stat(NONE)

	suit.uninstall(module)
	TEST_ASSERT_NULL(board.get_worn_mod_gps(user), "An uninstalled module must stop being offered even while it remains inside the suit.")
	TEST_ASSERT(!board.link_worn_mod_gps(user), "A stale UI click after removal must not link the old module.")
	suit.install(module)
	user.temporarilyRemoveItemFromInventory(suit)
	suit.forceMove(user.drop_location())
	TEST_ASSERT_NULL(board.get_worn_mod_gps(user), "Dropping the suit must invalidate a stale UI action.")
	TEST_ASSERT(!board.link_worn_mod_gps(user), "A nearby unworn suit must not receive the user's mission upload.")

	// The old tap-a-handheld path still registers the exact clicked device.
	board.item_interaction(user, handheld)
	var/datum/weakref/handheld_target = other_gps.linked_mission_signals[mission.gps_tag]
	TEST_ASSERT_EQUAL(handheld_target?.resolve(), target, "The handheld upload path must keep working.")

/// A destination whose interior can finish loading after the ship arrives.
/datum/mission_target/mission_gps_test
	var/turf/spawn_turf
	var/interior_loaded = FALSE

/datum/mission_target/mission_gps_test/is_interior_loaded()
	return interior_loaded

/datum/mission_target/mission_gps_test/get_spawn_turf()
	return spawn_turf

/datum/unit_test/voidcrew_mission_coasting_gps/Run()
	var/obj/structure/overmap/ship/ship = allocate(__IMPLIED_TYPE__)
	var/datum/mission/mission = allocate(__IMPLIED_TYPE__)
	mission.gps_tag = "Coasting Objective"
	mission.objective_name = "coasting test objective"
	var/datum/mission_target/mission_gps_test/target = allocate(__IMPLIED_TYPE__, mission)
	mission.target = target
	target.spawn_turf = run_loc_floor_top_right
	target.cache_coords_from(target.spawn_turf)
	var/datum/mission_objective/goto_coords/approach = allocate(__IMPLIED_TYPE__)
	approach.arrival_message = null
	mission.add_objective(approach)
	var/datum/mission_objective/field/plant_quest/field_step = allocate(__IMPLIED_TYPE__)
	mission.add_objective(field_step)
	mission.add_objective(allocate(/datum/mission_objective/deliver/bound))
	TEST_ASSERT(mission.start_mission(ship), "The travel/field mission must start.")
	TEST_ASSERT(!approach.completed, "The ship starts outside the destination's arrival range.")

	var/obj/machinery/computer/mission_board/mission_gps_test/board = allocate(__IMPLIED_TYPE__)
	board.test_ship = ship
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__)
	var/obj/item/gps/handheld = allocate(__IMPLIED_TYPE__)
	var/datum/component/gps/item/gps_unit = handheld.GetComponent(/datum/component/gps/item)
	board.item_interaction(user, handheld)
	TEST_ASSERT(!length(gps_unit.linked_mission_signals), "Linking before arrival must wait for the field objective.")

	// tick_move() uses forceMove while coasting, without an engine-burn signal.
	ship.forceMove(target.spawn_turf)
	TEST_ASSERT(approach.completed, "Coasting to the destination must complete the travel step without an engine burn.")
	TEST_ASSERT(!approach.active, "Arrival must deactivate the travel step and its movement listener.")
	TEST_ASSERT_EQUAL(mission.current_objective(), field_step, "Arrival must activate the field step.")
	TEST_ASSERT(!field_step.spawned, "The field step must wait for the destination interior to load.")
	target.interior_loaded = TRUE
	mission.on_target_interior_loaded()
	TEST_ASSERT_NOTNULL(mission.quest_atom, "Loading the destination must spawn the mission objective.")
	TEST_ASSERT_EQUAL(get_turf(mission.quest_atom), target.spawn_turf, "The objective must spawn at the destination.")
	var/datum/weakref/uploaded_target = gps_unit.linked_mission_signals?[mission.gps_tag]
	TEST_ASSERT_EQUAL(uploaded_target?.resolve(), mission.quest_atom, "The previously linked GPS must receive the spawned beacon automatically.")
	var/list/gps_data = gps_unit.ui_data(user)
	var/beacon_visible = FALSE
	for(var/list/signal as anything in gps_data["signals"])
		if(signal["entrytag"] == mission.gps_tag)
			beacon_visible = TRUE
			TEST_ASSERT_EQUAL(signal["coords"], "[target.spawn_turf.x], [target.spawn_turf.y], [target.spawn_turf.z]", "The GPS must display the objective's coordinates.")
	TEST_ASSERT(beacon_visible, "The mission beacon must appear in the GPS UI.")

	var/atom/movable/first_objective = mission.quest_atom
	ship.forceMove(run_loc_floor_bottom_left)
	board.item_interaction(user, handheld)
	TEST_ASSERT_EQUAL(mission.quest_atom, first_objective, "Moving away and linking again must not restart the completed travel step.")
