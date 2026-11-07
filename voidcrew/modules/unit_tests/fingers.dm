/// Hands lose fingers, a hand with none can't hold anything, and fingers go back on.
/datum/unit_test/fingers

/datum/unit_test/fingers/Run()
	var/mob/living/carbon/human/consistent/dummy = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/arm/hand = dummy.get_bodypart(BODY_ZONE_R_ARM)
	TEST_ASSERT_NOTNULL(hand, "The dummy has no right arm.")
	TEST_ASSERT_NULL(hand.lose_finger("thumb"), "A hand came apart without the Fingers quirk.")
	hand.set_fingers_bird(TRUE)
	TEST_ASSERT(findtext(hand.generate_icon_key().Join(), "-lonebird"), "A hand without the Fingers quirk did not grow a middle finger to flip the bird.")
	hand.set_fingers_bird(FALSE)
	dummy.add_quirk(/datum/quirk/fingers)
	TEST_ASSERT(hand.can_have_fingers(), "The Fingers quirk did not give the hand fingers.")
	TEST_ASSERT_EQUAL(hand.get_finger_count(), 5, "A fresh hand does not have five fingers.")
	var/whole_key = hand.generate_icon_key().Join()

	var/obj/item/food/finger/thumb = hand.lose_finger("thumb")
	TEST_ASSERT(istype(thumb), "Losing a flesh thumb did not drop a severed finger.")
	TEST_ASSERT_EQUAL(thumb.finger_name, "thumb", "The dropped finger is not the thumb.")
	TEST_ASSERT_EQUAL(hand.get_finger_count(), 4, "Losing a thumb did not leave four fingers.")
	TEST_ASSERT(!hand.has_finger("thumb"), "The hand still has the thumb it lost.")
	TEST_ASSERT_NULL(hand.lose_finger("thumb"), "The same finger came off twice.")
	TEST_ASSERT_NOTEQUAL(hand.generate_icon_key().Join(), whole_key, "Losing a finger did not change the hand's icon key, so the sprite would not redraw.")

	var/list/other_fingers = list()
	while(hand.get_finger_count() > 0)
		var/obj/item/lost = hand.lose_finger()
		TEST_ASSERT_NOTNULL(lost, "A hand with fingers left failed to lose one.")
		other_fingers += lost
	TEST_ASSERT_NULL(hand.lose_finger(), "A fingerless hand lost another finger.")

	var/obj/item/pen = allocate(/obj/item/pen)
	TEST_ASSERT(!dummy.put_in_hand(pen, hand.held_index), "A hand with no fingers picked something up.")

	TEST_ASSERT(hand.regrow_finger("thumb"), "The thumb did not go back on.")
	TEST_ASSERT(!hand.regrow_finger("thumb"), "A finger the hand already has went on again.")
	TEST_ASSERT(dummy.put_in_hand(pen, hand.held_index), "A hand with a thumb back could not hold a pen.")
	TEST_ASSERT(hand.fingers_gripping, "A hand holding a pen is not gripping it.")
	TEST_ASSERT_EQUAL(hand.get_finger_pose(), "_grip", "A gripping hand does not draw its fingers curled.")
	dummy.dropItemToGround(pen)
	TEST_ASSERT(!hand.fingers_gripping, "A hand still grips a pen it dropped.")

	// A pressed-on finger is loose until it's sutured.
	TEST_ASSERT(hand.attach_loose_finger("pinky", prosthetic = TRUE), "A prosthetic would not go into an empty pinky gap.")
	TEST_ASSERT(hand.has_finger("pinky"), "A pressed-on pinky does not count as a finger.")
	TEST_ASSERT("pinky" in hand.loose_fingers, "A pressed-on pinky is not loose.")
	TEST_ASSERT("pinky" in hand.prosthetic_fingers, "A printed pinky is not marked as a prosthetic.")
	TEST_ASSERT(!hand.attach_loose_finger("pinky"), "A second finger went into a gap that was already filled.")
	// Thumb back, index to ring still gone, prosthetic pinky.
	TEST_ASSERT(findtext(hand.generate_icon_key().Join(), "-fingers1000p"), "A prosthetic finger does not draw differently from flesh.")
	var/obj/item/prosthetic_finger/popped = hand.lose_finger("pinky")
	TEST_ASSERT(istype(popped), "A prosthetic pinky came off as something other than a prosthetic finger.")
	TEST_ASSERT(!("pinky" in hand.loose_fingers), "A pinky that fell off is still listed as loose.")
	TEST_ASSERT(!("pinky" in hand.prosthetic_fingers), "A pinky that fell off is still listed as a prosthetic.")
	other_fingers += popped
	TEST_ASSERT(hand.attach_loose_finger("pinky"), "A severed pinky would not go back into its gap.")
	TEST_ASSERT(hand.secure_finger("pinky"), "Suturing did not secure a loose pinky.")
	TEST_ASSERT(!("pinky" in hand.loose_fingers), "A sutured pinky is still loose.")
	TEST_ASSERT(!hand.secure_finger("pinky"), "A pinky that was already secure got secured again.")

	dummy.fully_heal(HEAL_ALL)
	TEST_ASSERT_EQUAL(hand.get_finger_count(), 5, "A full heal did not regrow the missing fingers.")
	TEST_ASSERT_EQUAL(hand.generate_icon_key().Join(), whole_key, "A regrown hand does not draw like a whole one.")

	var/obj/item/clothing/gloves/color/black/gloves = allocate(/obj/item/clothing/gloves/color/black)
	TEST_ASSERT(dummy.equip_to_slot_if_possible(gloves, ITEM_SLOT_GLOVES), "The dummy could not put on gloves.")
	TEST_ASSERT_NOTNULL(hand.finger_covering_color, "Gloves did not recolour the fingers.")
	TEST_ASSERT_NOTEQUAL(hand.generate_icon_key().Join(), whole_key, "Gloves did not change how the hand draws.")
	dummy.dropItemToGround(gloves)
	TEST_ASSERT_NULL(hand.finger_covering_color, "The fingers kept the glove colour after the gloves came off.")

	qdel(thumb)
	QDEL_LIST(other_fingers)
