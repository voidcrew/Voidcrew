/**
 * The R&D Kit is the only route most crews have to a research bay, so what it hands over matters.
 * It used to hand over six loose boards and a computer disk; it now hands over four flatpacks, the
 * console board, the disk, and the materials to frame the console.
 *
 * The assertions are deliberately about both halves of that: the four flatpacks must each carry
 * the right machine board, and the three items that stay loose must still be there. The last
 * assertion pins the box itself: flatpacks are WEIGHT_CLASS_HUGE and arrive through spawn-time
 * insertion, which bypasses storage limits, so the box deliberately keeps the standard small-item
 * datum - a kit that could swallow machine frames would be a free bag of holding.
 */
/datum/unit_test/voidcrew_rnd_kit

/datum/unit_test/voidcrew_rnd_kit/Run()
	var/obj/item/storage/box/rndboards/all/kit = allocate(/obj/item/storage/box/rndboards/all)

	// ---- the machines arrive packed ----------------------------------------------------------
	var/list/still_expected = list(
		/obj/item/circuitboard/machine/rdserver/ship,
		/obj/item/circuitboard/machine/protolathe,
		/obj/item/circuitboard/machine/destructive_analyzer,
		/obj/item/circuitboard/machine/circuit_imprinter,
	)
	var/flatpack_count = 0
	for(var/obj/item/flatpack/packed as anything in kit)
		flatpack_count++
		TEST_ASSERT_NOTNULL(packed.board, "a flatpack in the R&D kit has no board to deploy")
		still_expected -= packed.board.type
	TEST_ASSERT_EQUAL(flatpack_count, 4, "the R&D kit should ship four flatpacks")
	TEST_ASSERT(!length(still_expected), "the R&D kit is missing flatpacks for: [json_encode(still_expected)]")

	// ---- the console is still hand-built, so everything it needs must survive -----------------
	TEST_ASSERT_NOTNULL(locate(/obj/item/circuitboard/computer/rdconsole) in kit, "the R&D console board must stay loose - it cannot be flat-packed")
	TEST_ASSERT_NOTNULL(locate(/obj/item/computer_disk/ship_disk) in kit, "the R&D server source disk is missing from the kit")
	TEST_ASSERT_NOTNULL(locate(/obj/item/stack/sheet/iron) in kit, "the console frame iron is missing from the kit")
	TEST_ASSERT_NOTNULL(locate(/obj/item/stack/sheet/glass) in kit, "the console frame glass is missing from the kit")
	TEST_ASSERT_NOTNULL(locate(/obj/item/stack/cable_coil) in kit, "the console frame cable coil is missing from the kit")

	// ---- and the box must NOT become a container for oversized items --------------------------
	// The flatpacks are inserted at spawn, which bypasses storage limits, but the box's own datum
	// stays the standard small-item one - so an emptied kit cannot then be used to lug machine
	// frames around like a bag of holding. Pinned on purpose.
	TEST_ASSERT(kit.atom_storage.max_specific_storage <= WEIGHT_CLASS_SMALL, "the R&D kit's box must stay a normal box, not a container for huge items")
