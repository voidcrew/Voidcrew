/// Storage dumping must catalogue accepted items without dropping rejected contents onto the floor.
/datum/unit_test/voidcrew_smart_locker

/datum/unit_test/voidcrew_smart_locker/Run()
	var/obj/machinery/smartfridge/storage/locker = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/obj/item/storage/backpack/bag = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/obj/item/storage/belt/nested_container = allocate(__IMPLIED_TYPE__, bag)
	var/obj/item/wrench/first_tool = allocate(__IMPLIED_TYPE__, bag)
	var/obj/item/screwdriver/second_tool = allocate(__IMPLIED_TYPE__, bag)
	var/obj/item/crowbar/excess_tool = allocate(__IMPLIED_TYPE__, bag)
	locker.set_machine_stat(NONE)
	locker.max_n_of_items = 2

	// The public storage dump entry point supplies the same signal as dragging a bag.
	bag.atom_storage.dump_content_at(locker, locker.drop_location(), user)
	TEST_ASSERT_EQUAL(first_tool.loc, locker, "The first accepted item must enter the smart locker.")
	TEST_ASSERT_EQUAL(second_tool.loc, locker, "The second accepted item must enter the smart locker.")
	TEST_ASSERT_EQUAL(excess_tool.loc, bag, "Items beyond the locker capacity must stay in their container.")
	TEST_ASSERT_EQUAL(nested_container.loc, bag, "A nested storage container must stay in the source bag.")
	TEST_ASSERT_EQUAL(bag.loc, run_loc_floor_bottom_left, "Dumping must not consume or move the source container.")
	TEST_ASSERT_EQUAL(locker.visible_items(), 2, "A partial transfer must never exceed locker capacity.")

	bag.atom_storage.dump_content_at(locker, locker.drop_location(), user)
	TEST_ASSERT_EQUAL(excess_tool.loc, bag, "Dumping into a full locker must not spill contents onto the floor.")

	locker.max_n_of_items = 3
	bag.atom_storage.set_locked(STORAGE_FULLY_LOCKED)
	bag.atom_storage.dump_content_at(locker, locker.drop_location(), user)
	TEST_ASSERT_EQUAL(excess_tool.loc, bag, "Locked storage must not unload into the locker.")
	bag.atom_storage.set_locked(STORAGE_NOT_LOCKED)

	locker.set_machine_stat(NOPOWER)
	bag.atom_storage.dump_content_at(locker, locker.drop_location(), user)
	TEST_ASSERT_EQUAL(excess_tool.loc, bag, "An unpowered locker must leave the bag contents untouched.")
	locker.set_machine_stat(NONE)

	// Clicking a bag uses the same capacity and removal checks as dragging one.
	locker.attackby(bag, user)
	TEST_ASSERT_EQUAL(excess_tool.loc, locker, "Clicking a storage container should unload accepted contents too.")
	TEST_ASSERT_EQUAL(nested_container.loc, bag, "Clicking must retain rejected nested storage.")
	TEST_ASSERT_EQUAL(locker.visible_items(), 3, "Clicking must respect the same locker capacity.")

	locker.max_n_of_items = 4
	bag.atom_storage.dump_content_at(locker, locker.drop_location(), user)
	TEST_ASSERT_EQUAL(nested_container.loc, bag, "A bag containing only refused items must not spill them.")
	nested_container.forceMove(run_loc_floor_bottom_left)
	bag.atom_storage.dump_content_at(locker, locker.drop_location(), user)
	TEST_ASSERT_EQUAL(locker.visible_items(), 3, "Dumping an empty bag must not alter locker contents.")

	var/obj/item/soap/distant_item = allocate(__IMPLIED_TYPE__, bag)
	bag.forceMove(locate(run_loc_floor_top_right.x, run_loc_floor_top_right.y, run_loc_floor_top_right.z))
	if(get_dist(user, bag) > 1)
		bag.atom_storage.dump_content_at(locker, locker.drop_location(), user)
		TEST_ASSERT_EQUAL(distant_item.loc, bag, "Storage outside the user's reach must not unload.")
