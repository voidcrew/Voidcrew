/**
 * Outpost police tests for small walking faults found by the soak (voidcrew/modules/outpost_police/police_movement.dm,
 * voidcrew/modules/ambient_npcs/outpost_workers.dm and the townspeople's walking).
 * Written out: OUTPOST_GIVE_WAY_HOLD is 5 seconds, OUTPOST_GIVE_WAY_RANGE 2 tiles.
 */

/// An officer that stepped out of an escort's way does not walk straight back into it while the escort is by; once the escort has gone, it may
/datum/unit_test/voidcrew_stealth_live/police/give_way_once

/datum/unit_test/voidcrew_stealth_live/police/give_way_once/Run()
	TEST_ASSERT(police_room(8, 5), "No room for the test")
	var/mob/living/carbon/human/prisoner = person_at(1, 2, FALSE)
	var/mob/living/carbon/human/escort = person_at(2, 2, FALSE)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(3, 2, WEST)
	if(officer.move_intent == MOVE_INTENT_RUN)
		officer.toggle_move_intent()
	escort.start_pulling(prisoner)
	TEST_ASSERT_EQUAL(escort.pulling, prisoner, "Setup: the escort is not leading anyone")
	var/turf/in_the_way = at(3, 2)
	TEST_ASSERT(outpost_npc_step_aside(officer, escort, list()), "The officer did not step out of the escort's way")
	var/turf/stepped_to = get_turf(officer)
	TEST_ASSERT(stepped_to != in_the_way, "The officer did not move")
	TEST_ASSERT(!officer.Move(in_the_way, get_dir(stepped_to, in_the_way)), "The officer walked straight back into the escort's way")
	TEST_ASSERT_EQUAL(get_turf(officer), stepped_to, "The officer left the tile it stepped aside to")

	// Running (sent to search a spot) it is held all the same
	officer.toggle_move_intent()
	TEST_ASSERT_EQUAL(officer.move_intent, MOVE_INTENT_RUN, "Setup: the officer is not running")
	TEST_ASSERT(!officer.Move(in_the_way, get_dir(stepped_to, in_the_way)), "A running officer ran straight back into the escort's way")
	officer.toggle_move_intent()

	// The escort has gone on: the way is the officer's again
	escort.stop_pulling()
	escort.forceMove(at(7, 0))
	TEST_ASSERT(officer.Move(in_the_way, get_dir(stepped_to, in_the_way)), "The officer was still kept off the tile after the escort had gone")

/// A janitor's mess list takes the tile they stand on as the nearest (get_dist() of a turf with itself is -1 in BYOND)
/datum/unit_test/voidcrew_ambient_add_by_distance

/datum/unit_test/voidcrew_ambient_add_by_distance/Run()
	var/turf/here = run_loc_floor_bottom_left
	var/turf/near = get_step(here, NORTH)
	var/list/by_distance = new /list(3)
	ambient_add_by_distance(by_distance, here, here)
	ambient_add_by_distance(by_distance, here, near)
	TEST_ASSERT(here in by_distance[1], "The tile underfoot is not first in the mess list")
	TEST_ASSERT(near in by_distance[2], "The tile a step away is not second in the mess list")

/// Two townspeople head-on in a one-tile hall trade places; either side of a door, one goes into it; a player in the way is waited for
/datum/unit_test/voidcrew_stealth_live/police/townspeople_head_on

/datum/unit_test/voidcrew_stealth_live/police/townspeople_head_on/Run()
	TEST_ASSERT(police_room(7, 3), "No room for the test")
	// A hall one tile wide along the middle row
	for(var/dx in 0 to 6)
		for(var/dy in list(0, 2))
			var/turf/side = at(dx, dy)
			side.ChangeTurf(/turf/closed/wall)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/west = local_at(1, 1)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/east = local_at(2, 1)
	for(var/mob/living/local as anything in list(west, east))
		local.ai_controller?.set_ai_status(AI_STATUS_OFF)
		if(local.move_intent == MOVE_INTENT_RUN)
			local.toggle_move_intent()
	var/datum/move_loop/has_target/jps/west_loop = GLOB.move_manager.jps_move(west, at(6, 1), 10, repath_delay = 5 SECONDS, subsystem = SSai_movement)
	var/datum/move_loop/has_target/jps/east_loop = GLOB.move_manager.jps_move(east, at(0, 1), 10, repath_delay = 5 SECONDS, subsystem = SSai_movement)
	TEST_ASSERT(west_loop && east_loop, "Setup: no path loops started")

	// Head-on: they trade places
	west_loop.movement_path = list(at(2, 1))
	east_loop.movement_path = list(at(1, 1))
	west.Move(at(2, 1), EAST)
	TEST_ASSERT_EQUAL(get_turf(west), at(2, 1), "Two townspeople head-on in a narrow hall did not pass")
	TEST_ASSERT_EQUAL(get_turf(east), at(1, 1), "Head-on in a narrow hall, only one of the two moved")

	// One walking the same way, or standing about, is not traded with
	COOLDOWN_RESET(west, head_on_cooldown)
	COOLDOWN_RESET(east, head_on_cooldown)
	west.forceMove(at(1, 1))
	east.forceMove(at(2, 1))
	west_loop.movement_path = list(at(2, 1))
	east_loop.movement_path = list(at(3, 1))
	west.Move(at(2, 1), EAST)
	TEST_ASSERT_EQUAL(get_turf(west), at(1, 1), "A townsperson traded places with one walking the same way")

	// Either side of a door: a townsperson coming through the other way does not keep them out of the doorway, a player does
	var/turf/door_tile = at(3, 1)
	allocate(/obj/machinery/door/airlock/public/glass, door_tile)
	west.forceMove(at(2, 1))
	east.forceMove(at(4, 1))
	east_loop.movement_path = list(door_tile)
	TEST_ASSERT(west.doorway_step_ok(door_tile), "A townsperson waited outside a door for one waiting to come through it the other way")
	east_loop.movement_path = list(at(5, 1))
	TEST_ASSERT(!west.doorway_step_ok(door_tile), "A townsperson stepped into a doorway with someone standing beyond it")
	east.forceMove(at(5, 1))
	person_at(4, 1, FALSE)
	TEST_ASSERT(!west.doorway_step_ok(door_tile), "A townsperson stepped into a doorway with a player beyond it")

	GLOB.move_manager.stop_looping(west, SSai_movement)
	GLOB.move_manager.stop_looping(east, SSai_movement)

/**
 * An officer leading a cuffed suspect down a hall one tile wide, townspeople ahead: with no room to the side they walk
 * on ahead of it, the one in front first, until there is room. make_way() kept them off the way ahead, the only tile
 * there was, and an escort stood behind a townsperson in Quartermain's stock-room aisle for 40 s (pass 3 soak,
 * stunned_then_up). Anything else that asks someone to keep off a tile still never puts them on it.
 */
/datum/unit_test/voidcrew_stealth_live/police/escort_aisle

/datum/unit_test/voidcrew_stealth_live/police/escort_aisle/Run()
	TEST_ASSERT(police_room(9, 1), "No room for the test")
	var/mob/living/carbon/human/suspect = person_at(7, 0, FALSE)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(6, 0, WEST)
	officer.start_pulling(suspect)
	TEST_ASSERT_EQUAL(officer.pulling, suspect, "Setup: the officer is not leading the suspect")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/near = local_at(5, 0)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/far = local_at(4, 0)
	TEST_ASSERT(outpost_npc_can_make_room(near) && outpost_npc_can_make_room(far), "Setup: the townspeople cannot step out of anyone's way")
	// Asked to keep off the tile ahead, the only one there is, they stay put
	TEST_ASSERT(!outpost_npc_step_aside(near, officer, list(at(4, 0), at(3, 0))), "Someone stepped onto a tile they were asked to keep off")
	var/datum/outpost_police_case/case = allocate(/datum/outpost_police_case, police, null)
	officer.setDir(WEST)
	case.make_way(officer, suspect)
	TEST_ASSERT_EQUAL(get_turf(far), at(3, 0), "The townsperson in front did not walk on ahead of the escort in a hall one tile wide")
	TEST_ASSERT_EQUAL(get_turf(near), at(4, 0), "The townsperson beside the escort did not walk on ahead of it in a hall one tile wide")
	// Where there is room to the side, they step aside, off the way
	var/turf/side = at(3, 0)
	var/turf/wide = locate(side.x, side.y + 1, side.z)
	wide.ChangeTurf(/turf/open/floor/iron)
	officer.forceMove(at(5, 0))
	suspect.forceMove(at(6, 0))
	officer.start_pulling(suspect)
	far.forceMove(at(1, 0))
	near.forceMove(at(3, 0))
	officer.setDir(WEST)
	case.make_way(officer, suspect)
	TEST_ASSERT_EQUAL(get_turf(near), wide, "With room to the side the townsperson walked on along the escort's way")
