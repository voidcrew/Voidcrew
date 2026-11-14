/**
 * The mapped lockups. Every trader outpost whose interior holds a lockup is loaded and its wing checked: the
 * parts the code looks for are all there, the block is sealed (the only way in is the lift), nothing in it is
 * public floor or past the gate, and the cell block the code works out holds no front room or office tile.
 */

/// The trader outposts whose map has a lockup
#define LOCKUP_TEST_OUTPOSTS list( \
	/obj/structure/overmap/trader_outpost/general, \
	/obj/structure/overmap/trader_outpost/outfitter, \
	/obj/structure/overmap/trader_outpost/black_market, \
)

/**
 * A trader outpost with its interior loaded and its lockup's own clock stopped, so a test drives the wing with
 * tick(). Intake is shut, trouble, wildcards and wing events are off, and the wing does not keep itself (no
 * galley, standing roster, cleanbot or clearing of its dead): a test turns on what it is about. Somebody is
 * always there to see it (audience_override): a test world has no clients.
 */
/datum/unit_test/voidcrew_outpost_management/proc/lockup_test_outpost(outpost_type = /obj/structure/overmap/trader_outpost/outfitter)
	var/obj/structure/overmap/trader_outpost/outpost = allocate(outpost_type)
	if(!outpost.load_level())
		TEST_NOTICE(src, "[outpost_type]'s interior did not load")
		return null
	var/datum/outpost_prison/prison = outpost.prison
	if(prison)
		STOP_PROCESSING(SSprocessing, prison)
		prison.intake_open = FALSE
		prison.arrival_gap = 0
		prison.arrival_countdown = null
		prison.trouble_enabled = FALSE
		prison.wildcards_enabled = FALSE
		prison.wing_events_enabled = FALSE
		prison.galley_on = FALSE
		prison.roster_kept = FALSE
		prison.bot_kept = FALSE
		prison.bodies_cleared = FALSE
		prison.audience_override = TRUE
	return outpost

/// Every open tile reached from `start` on foot, four ways. With `doors_open`, doors and counters are floor; without, any tile with a door or a table on it is a wall.
/datum/unit_test/voidcrew_outpost_management/proc/lockup_flood(turf/start, doors_open = TRUE)
	var/list/reached = list()
	var/list/queue = list(start)
	reached[start] = TRUE
	var/index = 1
	while(index <= length(queue))
		var/turf/current = queue[index++]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || reached[next] || isclosedturf(next))
				continue
			if(!doors_open && ((locate(/obj/machinery/door) in next) || (locate(/obj/structure/table) in next)))
				continue
			reached[next] = TRUE
			queue += next
	return reached

/datum/unit_test/voidcrew_trade_prison_map
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_trade_prison_map/Run()
	for(var/outpost_type in LOCKUP_TEST_OUTPOSTS)
		check_wing(outpost_type)

/datum/unit_test/voidcrew_trade_prison_map/proc/check_wing(outpost_type)
	var/obj/structure/overmap/trader_outpost/outpost = lockup_test_outpost(outpost_type)
	TEST_ASSERT_NOTNULL(outpost, "[outpost_type]'s interior did not load")
	var/datum/outpost_prison/prison = outpost.prison
	TEST_ASSERT_NOTNULL(prison, "[outpost_type] has no lockup")
	TEST_ASSERT_EQUAL(prison.outpost, outpost, "[outpost_type]'s lockup does not know its outpost")
	TEST_ASSERT_EQUAL(outpost.ensure_prison(), prison, "[outpost_type] made a second lockup when asked again")
	var/list/wing_turfs = prison.wing_turfs()
	TEST_ASSERT(length(wing_turfs), "[outpost_type]'s lockup has no tiles")

	// Six cells, numbered 1 to 6, each small, with a bed, a toilet and a chair, and wall on its four corners
	TEST_ASSERT_EQUAL(length(prison.cells), 6, "[outpost_type]'s lockup has [length(prison.cells)] cells, not 6")
	TEST_ASSERT_EQUAL(prison.capacity, 6, "[outpost_type]'s lockup holds [prison.capacity], not 6")
	for(var/index in 1 to length(prison.cells))
		var/datum/outpost_prison_cell/cell = prison.cells[index]
		TEST_ASSERT_EQUAL(cell.number, index, "[outpost_type]: the cells are not numbered 1 to 6 in order")
		TEST_ASSERT(length(cell.turfs) <= 16, "[outpost_type]: cell [cell.number] has [length(cell.turfs)] tiles inside, over 16") // PRISON_CELL_MAX_TILES
		TEST_ASSERT_NOTNULL(cell.bed(), "[outpost_type]: cell [cell.number] has no bed")
		TEST_ASSERT_NOTNULL(cell.chair(), "[outpost_type]: cell [cell.number] has no chair")
		var/has_toilet = FALSE
		var/min_x = INFINITY
		var/min_y = INFINITY
		var/max_x = 0
		var/max_y = 0
		for(var/turf/tile as anything in cell.turfs)
			if(locate(/obj/structure/toilet) in tile)
				has_toilet = TRUE
			min_x = min(min_x, tile.x)
			min_y = min(min_y, tile.y)
			max_x = max(max_x, tile.x)
			max_y = max(max_y, tile.y)
		TEST_ASSERT(has_toilet, "[outpost_type]: cell [cell.number] has no toilet")
		var/turf/first_tile = cell.turfs[1]
		for(var/corner_x in list(min_x - 1, max_x + 1))
			for(var/corner_y in list(min_y - 1, max_y + 1))
				TEST_ASSERT(isclosedturf(locate(corner_x, corner_y, first_tile.z)), "[outpost_type]: cell [cell.number] has no wall on its corner at ([corner_x],[corner_y])")

	// What the landmarks gave the prison, and that none is left on the map
	TEST_ASSERT_EQUAL(length(prison.alcove_turfs), 9, "[outpost_type]'s lockup lift car has [length(prison.alcove_turfs)] tiles, not 9")
	var/turf/alcove_first = prison.alcove_turfs[1]
	var/turf/alcove_last = prison.alcove_turfs[9]
	TEST_ASSERT(alcove_last.x - alcove_first.x == 2 && alcove_last.y - alcove_first.y == 2, "[outpost_type]'s lockup lift car is not a 3x3 collected from its south-west tile")
	TEST_ASSERT_EQUAL(length(prison.processing_turfs), 2, "[outpost_type]'s Processing has [length(prison.processing_turfs)] tiles, not 2")
	TEST_ASSERT_EQUAL(length(prison.staff_closet_turfs), 2, "[outpost_type]'s staff closet has [length(prison.staff_closet_turfs)] tiles, not 2")
	TEST_ASSERT_NOTNULL(prison.desk_turf, "[outpost_type]'s lockup has no place for its warden")
	TEST_ASSERT_NOTNULL(prison.claim_turf, "[outpost_type]'s lockup has no front desk")
	TEST_ASSERT_EQUAL(get_dist(prison.desk_turf, prison.claim_turf), 1, "[outpost_type]: the warden does not stand behind the front desk")
	TEST_ASSERT(locate(/obj/structure/table) in prison.claim_turf, "[outpost_type]'s front desk is not a desk")
	var/lockers = 0
	var/glass = 0
	for(var/turf/tile as anything in wing_turfs)
		TEST_ASSERT_NULL(locate(/obj/effect/landmark/outpost_lockup_alcove) in tile, "[outpost_type]: a lift alcove landmark was left on the map")
		TEST_ASSERT_NULL(locate(/obj/effect/landmark/outpost_lockup_processing) in tile, "[outpost_type]: a Processing landmark was left on the map")
		TEST_ASSERT_NULL(locate(/obj/effect/landmark/outpost_lockup_staff) in tile, "[outpost_type]: a staff closet landmark was left on the map")
		TEST_ASSERT_NULL(locate(/obj/effect/landmark/outpost_police_lift) in tile, "[outpost_type]: a police lift closet is mapped in the lockup")
		TEST_ASSERT_NULL(locate(/obj/machinery/vending) in tile, "[outpost_type]: a vendor is mapped in the lockup")
		for(var/obj/structure/closet/secure_closet/personal/outpost_police/locker in tile)
			lockers++
		// Abuse 14 and 15: the block's outer ring is wall or glass all the way round, and glass is a wall
		if(prison.on_outer_ring(tile))
			TEST_ASSERT(isclosedturf(tile), "[outpost_type]'s lockup is open to the outside at ([tile.x],[tile.y])")
		if(istype(tile, /turf/closed/indestructible/opsglass) && prison.on_outer_ring(tile))
			glass++
	TEST_ASSERT_EQUAL(lockers, 4, "[outpost_type]'s lockup has [lockers] property lockers, not 4")
	TEST_ASSERT(glass >= 8, "[outpost_type]'s lockup shows [glass] tiles of glass to the outpost, under 8")
	TEST_ASSERT_EQUAL(length(prison.hatches()), 2, "[outpost_type]'s lockup has [length(prison.hatches())] serving hatches, not 2")

	// Processing and the staff closet have their doors, and the lift has its panel
	TEST_ASSERT(prison.has_processing(), "[outpost_type]'s Processing is missing a door")
	var/obj/machinery/door/airlock/inner = prison.processing_door(TRUE)
	var/obj/machinery/door/airlock/outer = prison.processing_door(FALSE)
	TEST_ASSERT(prison.in_cell_block(inner), "[outpost_type]: Processing's inner door is not on the cell block's edge")
	TEST_ASSERT(!prison.in_cell_block(outer), "[outpost_type]: Processing's outer door is in the cell block")
	TEST_ASSERT(prison.processing_free(), "[outpost_type]'s Processing is not shut and empty as mapped")
	for(var/turf/tile as anything in prison.processing_turfs)
		for(var/direction in GLOB.alldirs)
			var/turf/beside = get_step(tile, direction)
			TEST_ASSERT(!istype(beside, /turf/closed/indestructible/opsglass), "[outpost_type]: Processing has a window at ([beside.x],[beside.y])")
	TEST_ASSERT(istype(prison.staff_closet_door(), /obj/machinery/door/airlock/security/prison_staff), "[outpost_type]'s staff closet has no staff door")
	TEST_ASSERT_NOTNULL(prison.lift_panel, "[outpost_type]'s lockup has no lift panel")
	TEST_ASSERT_EQUAL(prison.lift_panel.outpost, outpost, "[outpost_type]'s lockup lift panel is not linked to its outpost")
	TEST_ASSERT(!(prison.lift_panel in outpost.lobby_panels), "[outpost_type]'s lockup lift panel was taken for a concourse panel")
	TEST_ASSERT_EQUAL(prison.lift_panel.get_current_floor(), 90, "[outpost_type]'s lockup lift panel reads floor [prison.lift_panel.get_current_floor()], not 90") // OUTPOST_LIFT_LOCKUP

	// Sealed (abuse 15): with every door open, walking from the lift never leaves the wing, so it never reaches
	// the concourse past the gate or a checkpoint. And nothing in the wing is walled off from the rest of it.
	var/list/reached = lockup_flood(alcove_first, doors_open = TRUE)
	for(var/turf/tile as anything in reached)
		TEST_ASSERT(prison.contains_turf(tile), "[outpost_type]: from the lockup's lift one can walk out of the lockup to ([tile.x],[tile.y])")
		TEST_ASSERT(!outpost.is_secured_turf(tile), "[outpost_type]: from the lockup's lift one can walk past the gate to ([tile.x],[tile.y])")
		TEST_ASSERT(!istype(tile.loc, /area/voidcrew/trader_outpost/checkpoint), "[outpost_type]: from the lockup's lift one can walk into a checkpoint at ([tile.x],[tile.y])")
	for(var/turf/tile as anything in wing_turfs)
		if(!isclosedturf(tile))
			TEST_ASSERT(reached[tile], "[outpost_type]: the lockup tile ([tile.x],[tile.y]) cannot be reached from the rest of the lockup")

	// The front room: with the doors shut and nobody climbing the desk, the lift leads nowhere else
	var/list/front_room = lockup_flood(alcove_first, doors_open = FALSE)
	for(var/turf/tile as anything in front_room)
		TEST_ASSERT(!prison.in_cell_block(tile), "[outpost_type]: the front room reaches the cell block at ([tile.x],[tile.y]) with no door between")
		TEST_ASSERT(!(tile in prison.processing_turfs), "[outpost_type]: the front room reaches Processing with no door between")
		TEST_ASSERT(!(tile in prison.staff_closet_turfs), "[outpost_type]: the front room reaches the staff closet with no door between")
		TEST_ASSERT(tile != prison.desk_turf, "[outpost_type]: the front room reaches the warden's side of the desk")
	var/outer_on_front_room = FALSE
	for(var/direction in GLOB.cardinals)
		if(front_room[get_step(outer, direction)])
			outer_on_front_room = TRUE
	TEST_ASSERT(outer_on_front_room, "[outpost_type]: Processing's outer door does not open onto the front room")

	// No part of the wing is public floor to the outpost's crowd
	for(var/turf/tile as anything in bounty_outpost_public_floor(outpost))
		TEST_ASSERT(!prison.contains_turf(tile), "[outpost_type]: the lockup tile ([tile.x],[tile.y]) is public floor")

	// The cell block the code works out is the cells and the yard: no front room, Processing, closet or office tile
	for(var/turf/tile as anything in prison.alcove_turfs + prison.processing_turfs + prison.staff_closet_turfs + list(prison.desk_turf, prison.claim_turf))
		TEST_ASSERT(!prison.in_cell_block(tile), "[outpost_type]: ([tile.x],[tile.y]) of the front room or office counts as cell block")
	for(var/turf/tile as anything in front_room)
		TEST_ASSERT(!prison.cell_block[tile], "[outpost_type]: the front room tile ([tile.x],[tile.y]) is in the cell block")
	var/list/office = prison.office_ground()
	TEST_ASSERT(length(office), "[outpost_type]'s lockup has no office")
	TEST_ASSERT(office[prison.desk_turf], "[outpost_type]: the warden's place is not open to the office")
	for(var/turf/tile as anything in office)
		TEST_ASSERT(!prison.in_cell_block(tile), "[outpost_type]: the office tile ([tile.x],[tile.y]) counts as cell block")
		TEST_ASSERT(!front_room[tile], "[outpost_type]: the office tile ([tile.x],[tile.y]) is part of the front room")
		TEST_ASSERT(!(tile in prison.staff_closet_turfs) && !(tile in prison.processing_turfs), "[outpost_type]: the office takes in the staff closet or Processing")
	// The guards' doors onto the yard are the office's, never Processing's
	for(var/turf/door_tile as anything in prison.guard_yard_doors())
		TEST_ASSERT(door_tile != get_turf(inner), "[outpost_type]: the guards hold Processing's inner door as a staff door")
	TEST_ASSERT(length(prison.guard_yard_doors()), "[outpost_type]'s lockup has no staff door between the office and the yard")
	TEST_ASSERT_NOTNULL(prison.guard_office_spot(), "[outpost_type]'s office has nowhere for a guard to stand")

	// The yard has what the wing's days need
	TEST_ASSERT(length(prison.fixtures_of("stool")) >= 6, "[outpost_type]'s yard has [length(prison.fixtures_of("stool"))] stools")
	TEST_ASSERT(length(prison.fixtures_of("hoop")), "[outpost_type]'s yard has no hoop")
	TEST_ASSERT(length(prison.fixtures_of("bookcase")), "[outpost_type]'s yard has no bookcase")
	TEST_ASSERT(length(prison.fixtures_of("cooler")), "[outpost_type]'s wing has no water cooler")
	var/washers = 0
	for(var/turf/tile as anything in prison.cell_block)
		if(locate(/obj/machinery/washing_machine) in tile)
			washers++
	TEST_ASSERT(washers, "[outpost_type]'s cell block has no washing machine")

#undef LOCKUP_TEST_OUTPOSTS
