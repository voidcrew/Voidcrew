/// Make a mob hop on an optable, rest, get up, rest again, and then move to another tile.
/// While the mob is still an active patient, move another mob in too.
/// This is so the replacement code can kick in when the original mob is no longer valid.
/datum/unit_test/operating_table

/datum/unit_test/operating_table/Run()
	var/obj/structure/table/optable/table = allocate(/obj/structure/table/optable)
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent, get_step(table, NORTH))
	var/mob/living/carbon/human/replacement_human = allocate(/mob/living/carbon/human/consistent, get_step(table, NORTH))

	// Resting is a bit more high level than bodypos, gets us nicer coverage.
	human.set_resting(new_resting = FALSE, instant = TRUE)
	replacement_human.set_resting(new_resting = FALSE, instant = TRUE)

	human.forceMove(get_turf(table))
	TEST_ASSERT_NULL(table.patient, "Operating table is occupied by a non-resting patient.")

	human.set_resting(new_resting = TRUE, instant = TRUE)
	TEST_ASSERT_EQUAL(table.patient, human, "Operating table failed to update for a resting patient.")

	human.set_resting(new_resting = FALSE, instant = TRUE)
	TEST_ASSERT_NULL(table.patient, "Operating table is occupied by a non-resting patient.")

	human.set_resting(new_resting = TRUE, instant = TRUE)
	TEST_ASSERT_EQUAL(table.patient, human, "Operating table failed to update for a resting patient.")

	replacement_human.forceMove(get_turf(table))
	replacement_human.set_resting(new_resting = TRUE, instant = TRUE)
	TEST_ASSERT_EQUAL(table.patient, human, "Operating table patient unset by another patient jumping in.")

	human.forceMove(get_step(get_turf(table), NORTH))
	TEST_ASSERT_EQUAL(table.patient, replacement_human, "Operating table failed to find a replacement patient.")

/// Occupants can move between adjacent tables, while floor entry and buckling keep their normal restrictions.
/datum/unit_test/operating_table_movement

/datum/unit_test/operating_table_movement/Run()
	var/turf/first_site = get_step(run_loc_floor_bottom_left, EAST)
	var/turf/second_site = get_step(first_site, EAST)
	var/turf/floor_exit = get_step(first_site, NORTH)
	var/obj/structure/table/optable/first_table = allocate(__IMPLIED_TYPE__, first_site)
	var/obj/structure/table/optable/second_table = allocate(__IMPLIED_TYPE__, second_site)
	var/mob/living/carbon/human/consistent/human = allocate(__IMPLIED_TYPE__)

	TEST_ASSERT(!human.Move(first_site, EAST), "Walking from the floor must not bypass getting onto an operating table.")
	TEST_ASSERT(!HAS_TRAIT(human, TRAIT_ON_CLIMBABLE), "A failed attempt to enter must not grant table-walking permission.")
	human.forceMove(first_site) // Simulate having already climbed or been placed onto the table.
	TEST_ASSERT(human.Move(second_site, EAST), "An occupant must be able to walk onto an adjacent operating table.")
	TEST_ASSERT_EQUAL(human.loc, second_site, "Walking between tables must move the occupant physically.")
	TEST_ASSERT_NULL(first_table.patient, "Walking upright must not leave a patient on the first table.")
	TEST_ASSERT_NULL(second_table.patient, "Walking upright must not create a patient on the second table.")

	TEST_ASSERT(second_table.buckle_mob(human, force = TRUE), "The occupied operating table must still support buckling.")
	TEST_ASSERT(!human.Move(first_site, WEST), "A buckled patient must not walk off the table.")
	TEST_ASSERT_EQUAL(human.buckled, second_table, "Attempted movement must not unbuckle the patient.")
	second_table.unbuckle_mob(human, force = TRUE)
	human.set_resting(new_resting = TRUE, instant = TRUE)
	TEST_ASSERT_EQUAL(second_table.patient, human, "The resting occupant must be registered as the current patient.")
	TEST_ASSERT(human.Move(first_site, WEST), "An unbuckled resting occupant must be able to move between tables.")
	TEST_ASSERT_NULL(second_table.patient, "Moving away must clear the previous table's patient.")
	TEST_ASSERT_EQUAL(first_table.patient, human, "The destination table must recognize the resting patient.")

	TEST_ASSERT(human.Move(floor_exit, NORTH), "The occupant must be able to leave the table for the floor.")
	TEST_ASSERT_NULL(first_table.patient, "Leaving the table must clear its patient.")
	TEST_ASSERT(!HAS_TRAIT(human, TRAIT_ON_CLIMBABLE), "Table-walking permission must end when the occupant leaves.")
	human.set_resting(new_resting = FALSE, instant = TRUE)
	TEST_ASSERT(!human.Move(first_site, SOUTH), "An occupant on the floor must get onto the table again before crossing it.")

	human.forceMove(first_site)
	qdel(first_table)
	TEST_ASSERT(!HAS_TRAIT(human, TRAIT_ON_CLIMBABLE), "Removing the occupied table must remove its table-walking permission.")
	TEST_ASSERT(!human.Move(second_site, EAST), "A removed table must not allow walking onto a remaining adjacent table.")
