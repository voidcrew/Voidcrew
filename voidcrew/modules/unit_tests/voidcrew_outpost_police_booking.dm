/**
 * Outpost police: a booking whose officer falls in the cell is finished by the next officer, from the cell door.
 * No walker plans a route into a cell, so an officer sent to the suspect themselves stood still (pass 13 soak).
 */

/// Sets up a three-star arrest in used police cuffs, searched and with the evidence handed in. list(officer, suspect, case, ships, cell) or null.
/datum/unit_test/proc/police_booking_setup(obj/structure/overmap/trader_outpost/outpost)
	var/datum/outpost_police/police = outpost.police
	var/list/parts = police_arrest_setup(outpost, 55) // three stars (OUTPOST_POLICE_STAR_HEAT 50)
	if(!parts)
		return null
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = parts[1]
	var/mob/living/carbon/human/suspect = parts[2]
	var/datum/outpost_police_case/case = parts[3]
	var/list/ships = list(wanted_ship(suspect, 0))
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	suspect.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	case.searched = TRUE
	case.cuffs_on(suspect)
	case.disposed_at = world.time
	var/datum/outpost_police_cell/cell = police.cell_best(officer)
	if(!cell?.outside_turf)
		TEST_FAIL("The outpost has no usable cell")
		wanted_cleanup(ships)
		return null
	// Left on the cell floor with nobody holding them, the door shut
	officer.stop_pulling()
	suspect.forceMove(cell.free_tile())
	cell.shut_door(TRUE)
	return list(officer, suspect, case, ships, cell)

/// The suspect is on the cell floor, not yet booked: the next officer walks to the door, not at them, and books them there
/datum/unit_test/voidcrew_outpost_police_booking_takeover
	var/saved_scale

/datum/unit_test/voidcrew_outpost_police_booking_takeover/Destroy()
	if(!isnull(saved_scale))
		GLOB.outpost_police_property_time_scale = saved_scale
	return ..()

/datum/unit_test/voidcrew_outpost_police_booking_takeover/Run()
	saved_scale = GLOB.outpost_police_property_time_scale
	GLOB.outpost_police_property_time_scale = 0.01
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	var/list/parts = police_booking_setup(outpost)
	if(!parts)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = parts[1]
	var/mob/living/carbon/human/suspect = parts[2]
	var/datum/outpost_police_case/case = parts[3]
	var/list/ships = parts[4]
	var/datum/outpost_police_cell/cell = parts[5]
	TEST_ASSERT_NULL(police.cell_holding(suspect.mind), "The suspect is held before any booking")

	// A step off the door: the walk is to the door, never to the suspect behind it
	var/turf/near_door = police_arrest_beside(cell.outside_turf)
	TEST_ASSERT_NOTNULL(near_door, "No floor beside the cell's outside tile")
	officer.forceMove(near_door)
	case.set_step("desk") // CASE_STEP_DESK
	case.step_desk()
	TEST_ASSERT_EQUAL(case.goal, cell.outside_turf, "The officer walks to [case.goal] ([AREACOORD(case.goal)]), not the cell door at [AREACOORD(cell.outside_turf)]")
	TEST_ASSERT_EQUAL(case.step, "desk", "Away from the door the case is on [case.step]")

	// At the door: booked from there
	officer.forceMove(cell.outside_turf)
	case.step_desk()
	TEST_ASSERT_EQUAL(case.step, "book", "At the cell door the case is on [case.step]") // CASE_STEP_BOOK
	case.step_book()
	TEST_ASSERT_EQUAL(case.acting, "booking", "At the door the officer is [case.acting || "doing nothing"], not booking") // CASE_ACT_BOOKING
	police_arrest_wait(case, 40 SECONDS)
	TEST_ASSERT(QDELETED(case), "The arrest did not end with the booking")
	TEST_ASSERT_EQUAL(police.cell_holding(suspect.mind), cell, "The suspect is not held in the cell they were on")
	TEST_ASSERT(get_turf(suspect) in cell.tiles, "The suspect is not in the cell")
	TEST_ASSERT_NULL(suspect.handcuffed, "The prisoner is still cuffed in the cell")
	TEST_ASSERT(!(get_turf(officer) in cell.tiles), "The officer is still in the cell")
	wanted_cleanup(ships)

/// Booked, but the cuffs never came off (the officer fell): the next officer comes to the door, goes in and takes them off
/datum/unit_test/voidcrew_outpost_police_booking_uncuff
	var/saved_scale

/datum/unit_test/voidcrew_outpost_police_booking_uncuff/Destroy()
	if(!isnull(saved_scale))
		GLOB.outpost_police_property_time_scale = saved_scale
	return ..()

/datum/unit_test/voidcrew_outpost_police_booking_uncuff/Run()
	saved_scale = GLOB.outpost_police_property_time_scale
	GLOB.outpost_police_property_time_scale = 0.01
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	var/list/parts = police_booking_setup(outpost)
	if(!parts)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = parts[1]
	var/mob/living/carbon/human/suspect = parts[2]
	var/datum/outpost_police_case/case = parts[3]
	var/list/ships = parts[4]
	var/datum/outpost_police_cell/cell = parts[5]
	// Held, with a jail term, as book_in() leaves one whose cuffs its officer could not take off
	cell.admit(suspect, world.time + 10 MINUTES, TRUE)
	TEST_ASSERT_EQUAL(police.cell_holding(suspect.mind), cell, "The suspect is not held")

	officer.forceMove(cell.outside_turf)
	case.set_step("book") // CASE_STEP_BOOK
	case.step_book()
	TEST_ASSERT_EQUAL(case.acting, "booking", "At the door the officer is [case.acting || "doing nothing"], not seeing to the cuffs") // CASE_ACT_BOOKING
	police_arrest_wait(case, 40 SECONDS)
	TEST_ASSERT_NULL(suspect.handcuffed, "The prisoner is still cuffed in the cell")
	TEST_ASSERT(QDELETED(case), "The arrest did not end once the cuffs were off")
	TEST_ASSERT_EQUAL(police.cell_holding(suspect.mind), cell, "The prisoner is no longer held")
	TEST_ASSERT(get_turf(suspect) in cell.tiles, "The prisoner is not in the cell")
	TEST_ASSERT(!(get_turf(officer) in cell.tiles), "The officer is still in the cell")
	wanted_cleanup(ships)
