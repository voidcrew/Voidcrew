/// A checkpoint rebuild keeps a portal's venue, and a portal with no venue can still be deleted.
/datum/unit_test/voidcrew_restaurant_portal

/datum/unit_test/voidcrew_restaurant_portal/Run()
	var/obj/machinery/restaurant_portal/restaurant/kitchen = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT_EQUAL(kitchen.checkpoint_type(), /obj/machinery/restaurant_portal/restaurant, "A restaurant portal should rebuild as a restaurant portal")

	var/obj/machinery/restaurant_portal/bar/tavern = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT_EQUAL(tavern.checkpoint_type(), /obj/machinery/restaurant_portal/bar, "A bar portal should rebuild as a bar portal")

	var/obj/machinery/restaurant_portal/built = allocate(__IMPLIED_TYPE__)
	var/obj/item/circuitboard/machine/restaurant_portal/board = built.circuit
	board.venue_type = /datum/venue/bar
	board.configure_machine(built)
	TEST_ASSERT_EQUAL(built.checkpoint_type(), /obj/machinery/restaurant_portal/bar, "A portal built and set to the bar should rebuild as a bar portal")

	var/obj/machinery/restaurant_portal/unlinked = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT_NULL(unlinked.linked_venue, "A plain portal should start with no venue")
	qdel(unlinked)
	TEST_ASSERT(QDELETED(unlinked), "A portal with no venue should delete cleanly")
