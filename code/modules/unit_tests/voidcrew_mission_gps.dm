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
