/// Exercise both ways of self-injecting after actually falling into soft crit and picking the pen back up.
/datum/unit_test/soft_crit_medipen/Run()
	for(var/use_hotkey in list(FALSE, TRUE))
		var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
		var/obj/item/reagent_containers/hypospray/medipen/pen = allocate(/obj/item/reagent_containers/hypospray/medipen)
		patient.put_in_active_hand(pen)
		patient.adjustToxLoss(patient.maxHealth - patient.crit_threshold + 10)
		TEST_ASSERT_EQUAL(patient.stat, SOFT_CRIT, "Patient did not enter soft crit")
		TEST_ASSERT_EQUAL(patient.get_active_held_item(), null, "Entering crit should still drop held items")
		TEST_ASSERT_EQUAL(patient.body_position, LYING_DOWN, "Soft crit should still floor the patient")
		TEST_ASSERT(patient.incapacitated, "Soft crit must still block actions that do not opt in")
		patient.next_click = -1
		patient.ClickOn(pen)
		TEST_ASSERT_EQUAL(patient.get_active_held_item(), pen, "Could not pick up a medipen in soft crit")
		patient.next_click = -1
		patient.next_move = -1
		if(use_hotkey)
			patient.execute_mode()
		else
			patient.ClickOn(patient)
		TEST_ASSERT(pen.used_up, "Could not self-inject in soft crit using [use_hotkey ? "activation" : "a click"]")
		TEST_ASSERT(patient.reagents.has_reagent(/datum/reagent/medicine/epinephrine), "Self-injection did not deliver epinephrine")

/// A new incapacitation source must block clicks even when the cached incapacitation value does not change.
/datum/unit_test/soft_crit_incapacitation/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/reagent_containers/hypospray/medipen/pen = allocate(/obj/item/reagent_containers/hypospray/medipen)
	patient.set_stat(SOFT_CRIT)
	patient.put_in_active_hand(pen)
	for(var/blocking_trait in list(TRAIT_INCAPACITATED, TRAIT_RESTRAINED, TRAIT_HANDS_BLOCKED))
		ADD_TRAIT(patient, blocking_trait, TRAIT_SOURCE_UNIT_TESTS)
		patient.put_in_active_hand(pen, forced = TRUE)
		patient.next_click = -1
		patient.next_move = -1
		patient.ClickOn(patient)
		patient.next_move = -1
		patient.execute_mode()
		TEST_ASSERT(!pen.used_up, "[blocking_trait] did not block item use during soft crit")
		REMOVE_TRAIT(patient, blocking_trait, TRAIT_SOURCE_UNIT_TESTS)
	patient.next_move = -1
	patient.execute_mode()
	TEST_ASSERT(pen.used_up, "Removing the extra blocker did not restore item use in soft crit")

/// Losing consciousness must block hands again, including when recovering from hard crit into soft crit.
/datum/unit_test/soft_crit_transitions/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/reagent_containers/hypospray/medipen/pen = allocate(/obj/item/reagent_containers/hypospray/medipen)
	for(var/blocked_stat in list(UNCONSCIOUS, HARD_CRIT, DEAD))
		patient.set_stat(SOFT_CRIT)
		TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_HANDS_BLOCKED), "Recovering into soft crit did not free the patient's hands")
		patient.put_in_active_hand(pen)
		patient.set_stat(blocked_stat)
		TEST_ASSERT_EQUAL(patient.get_active_held_item(), null, "Entering stat [blocked_stat] from soft crit did not drop the medipen")
		TEST_ASSERT(HAS_TRAIT(patient, TRAIT_HANDS_BLOCKED), "Entering stat [blocked_stat] from soft crit did not block hands")
		patient.put_in_active_hand(pen, forced = TRUE)
		patient.next_click = -1
		patient.next_move = -1
		patient.ClickOn(patient)
		patient.execute_mode()
		TEST_ASSERT(!pen.used_up, "Stat [blocked_stat] allowed item use")
	patient.set_stat(CONSCIOUS)
	TEST_ASSERT(!patient.incapacitated, "Full recovery left the patient incapacitated")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_HANDS_BLOCKED), "Full recovery left the patient's hands blocked")

/// Replace only client rendering so the real storage access checks can run without a connected player.
/datum/storage/soft_crit_test/show_contents(mob/to_show)
	return TRUE

/obj/item/storage/soft_crit_test
	storage_type = /datum/storage/soft_crit_test

/datum/unit_test/soft_crit_storage/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/storage/bag = allocate(/obj/item/storage/soft_crit_test)
	var/obj/item/reagent_containers/hypospray/medipen/pen = allocate(/obj/item/reagent_containers/hypospray/medipen, bag)
	patient.set_stat(SOFT_CRIT)
	TEST_ASSERT(bag.atom_storage.open_storage(patient), "Could not open storage in soft crit")
	TEST_ASSERT(!patient.can_perform_action(bag, ALLOW_RESTING), "Unrelated actions should still require consciousness")
	patient.next_click = -1
	patient.ClickOn(pen)
	TEST_ASSERT_EQUAL(patient.get_active_held_item(), pen, "Could not take a medipen out of storage in soft crit")
	for(var/blocking_trait in list(TRAIT_INCAPACITATED, TRAIT_RESTRAINED, TRAIT_HANDS_BLOCKED, TRAIT_STASIS))
		ADD_TRAIT(patient, blocking_trait, TRAIT_SOURCE_UNIT_TESTS)
		TEST_ASSERT(!bag.atom_storage.open_storage(patient), "[blocking_trait] did not block storage access during soft crit")
		REMOVE_TRAIT(patient, blocking_trait, TRAIT_SOURCE_UNIT_TESTS)
	var/mob/living/carbon/human/grabber = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(grabber.start_pulling(patient), "Could not start pulling the patient")
	grabber.setGrabState(GRAB_AGGRESSIVE)
	TEST_ASSERT_EQUAL(grabber.grab_state, GRAB_AGGRESSIVE, "Could not tighten the grab")
	TEST_ASSERT(!bag.atom_storage.open_storage(patient), "An aggressive grab did not block storage access in soft crit")
	grabber.stop_pulling()
	TEST_ASSERT(bag.atom_storage.open_storage(patient), "Releasing the grab did not restore storage access")

/datum/unit_test/soft_crit_action_delay/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	patient.next_move_modifier = 2
	patient.next_move_adjust = 3
	patient.changeNext_move(10)
	var/normal_delay = patient.next_move - world.time
	patient.set_stat(SOFT_CRIT)
	patient.changeNext_move(10)
	TEST_ASSERT_EQUAL(patient.next_move - world.time, normal_delay * 4, "Soft crit did not multiply the existing action delay by four")
	patient.set_stat(CONSCIOUS)
	patient.changeNext_move(10)
	TEST_ASSERT_EQUAL(patient.next_move - world.time, normal_delay, "Recovery did not restore normal action speed")
