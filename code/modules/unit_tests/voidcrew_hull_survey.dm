/**
 * # Voidcrew hull survey tests
 *
 * The survey is how a crew grows a hull by hand: seal a room, stand in it, press the button.
 * Everything it decides is invisible - there is no readout, only a yes or a refusal - so the
 * three rules that make it usable are exactly the three that can rot without anyone noticing.
 *
 * 1. Air is the only test. If nothing can breathe through the skin, it is a hull, whether the
 *    skin is a wall, a full-tile window or a thin directional one. The old fill checked for
 *    space before it checked whether air could reach it, so a window-walled room read as
 *    open to vacuum and every glass build was refused.
 *
 * 2. Corners come with the room. Corner tiles are only ever diagonal to the space they close
 *    off, so a cardinals-only sweep leaves them behind and the hull launches without them.
 *
 * 3. A neighbouring hull is a boundary, not a disqualification. A room that borrows the
 *    ship's existing wall used to be refused outright - the ship's wall landed in the claim
 *    and tripped the "already belongs to a hull" check - which is what forced crews to build
 *    free-standing boxes alongside their ship with a dead gap behind one wall.
 *
 * These run in a reserved space block rather than the unit-test floor, because
 * hull_claim_area_valid() only ever accepts space and planetoid ground.
 */
/datum/unit_test/voidcrew_hull_survey
	var/datum/turf_reservation/reserved
	/// Bottom-left corner of the working block.
	var/turf/anchor

/datum/unit_test/voidcrew_hull_survey/New()
	..()
	reserved = SSmapping.request_turf_block_reservation(12, 12, 1)
	anchor = reserved?.bottom_left_turfs[1]

/datum/unit_test/voidcrew_hull_survey/Destroy()
	qdel(reserved)
	return ..()

/// Turf at a block-relative offset. (1, 1) is the reservation's bottom-left corner.
/datum/unit_test/voidcrew_hull_survey/proc/spot(offset_x, offset_y)
	return locate(anchor.x + offset_x - 1, anchor.y + offset_y - 1, anchor.z)

/**
 * Wipes the working block back to bare space and republishes atmos adjacency for it.
 *
 * The republish is not optional. Outside DEBUG builds a ChangeTurf only *queues* the
 * adjacency recalculation on SSair, so a test that built its room and read the result in the
 * same tick would be measuring the layout from before it built anything.
 */
/datum/unit_test/voidcrew_hull_survey/proc/reset_block()
	for(var/offset_x in 1 to 12)
		for(var/offset_y in 1 to 12)
			var/turf/scratch = spot(offset_x, offset_y)
			for(var/obj/leftover in scratch)
				qdel(leftover)
			if(!isspaceturf(scratch))
				scratch.ChangeTurf(/turf/open/space, /turf/open/space)
	settle()

/// Forces every turf in the block to recompute the adjacency the survey reads.
/datum/unit_test/voidcrew_hull_survey/proc/settle()
	for(var/offset_x in 1 to 12)
		for(var/offset_y in 1 to 12)
			var/turf/scratch = spot(offset_x, offset_y)
			scratch.immediate_calculate_adjacent_turfs()

/datum/unit_test/voidcrew_hull_survey/Run()
	TEST_ASSERT(reserved, "could not reserve a turf block to build test hulls in")

	test_thin_window_room()
	test_open_window_room_leaks()
	test_walled_room_takes_its_corners()
	test_room_sharing_a_hull_wall()
	test_commission_needs_an_outer_door()
	test_port_seat_rejects_an_interior_door()
	test_new_hull_area_belongs_to_the_ship()
	test_expansion_past_the_port_needs_a_door_on_the_new_face()
	test_drone_growth_reseats_or_warns()
	test_survey_bearing_reports_both_legs()

/**
 * A 3x3 of plating whose only skin is thin directional windows on its outward edges.
 *
 * This is the shape the old fill could never accept. Every tile of the room is a perimeter
 * tile, so every tile is cardinally next to vacuum; the seal is an object standing on the
 * room's own tiles, not a tile of its own. Nothing outside is claimed, because there is
 * nothing out there to claim - the windows are already inside the footprint.
 */
/datum/unit_test/voidcrew_hull_survey/proc/test_thin_window_room()
	reset_block()
	build_window_room()
	settle()

	var/datum/hull_claim/claim = survey_enclosure(spot(3, 3))
	TEST_ASSERT_NULL(claim.refusal, "a room sealed with thin directional windows was refused: [claim.refusal]")
	TEST_ASSERT_EQUAL(length(claim.turfs), 9, "the window room should claim its own 9 tiles and nothing outside them")

/// The same room with one pane missing: now air really can get out, and it must be refused.
/datum/unit_test/voidcrew_hull_survey/proc/test_open_window_room_leaks()
	reset_block()
	build_window_room()
	// The north face of the middle-north tile - the one pane between the room and vacuum.
	for(var/obj/structure/window/pane in spot(3, 4))
		if(pane.dir == NORTH)
			qdel(pane)
	settle()

	var/datum/hull_claim/claim = survey_enclosure(spot(3, 3))
	TEST_ASSERT_NOTNULL(claim.refusal, "a window room with a missing pane was accepted as airtight")
	TEST_ASSERT_EQUAL(claim.refusal_turf, spot(3, 5), "the refusal should point at the vacuum the room leaks into, not [claim.refusal_turf]")

/**
 * A 3x3 room inside a ring of walls claims 25 tiles, not 21.
 *
 * The four corner walls are diagonal to the room and cardinal to nothing inside it. Collect
 * barriers on cardinals alone and they stay behind on the first launch, opening the hull.
 */
/datum/unit_test/voidcrew_hull_survey/proc/test_walled_room_takes_its_corners()
	reset_block()
	for(var/offset_x in 2 to 6)
		for(var/offset_y in 2 to 6)
			var/turf/scratch = spot(offset_x, offset_y)
			var/on_edge = (offset_x == 2 || offset_x == 6 || offset_y == 2 || offset_y == 6)
			scratch.ChangeTurf(on_edge ? /turf/closed/wall : /turf/open/floor/plating, /turf/open/space)
	settle()

	var/datum/hull_claim/claim = survey_enclosure(spot(4, 4))
	TEST_ASSERT_NULL(claim.refusal, "a plainly walled room was refused: [claim.refusal]")
	TEST_ASSERT_EQUAL(length(claim.turfs), 25, "the claim should be 9 floors plus all 16 wall tiles, corners included")
	TEST_ASSERT(claim.turfs[spot(2, 2)], "the south-west corner wall was left out of the claim")
	TEST_ASSERT(claim.turfs[spot(6, 6)], "the north-east corner wall was left out of the claim")

/**
 * A room that uses an existing hull's wall as its own fourth wall.
 *
 * The hull turf must act as a boundary: not walked, not claimed, and not grounds for refusal.
 * Anything else and the only legal way to grow a ship is a free-standing box beside it.
 */
/datum/unit_test/voidcrew_hull_survey/proc/test_room_sharing_a_hull_wall()
	reset_block()
	for(var/offset_x in 2 to 6)
		for(var/offset_y in 2 to 6)
			var/turf/scratch = spot(offset_x, offset_y)
			var/on_edge = (offset_x == 2 || offset_x == 6 || offset_y == 2 || offset_y == 6)
			scratch.ChangeTurf(on_edge ? /turf/closed/wall : /turf/open/floor/plating, /turf/open/space)

	// Hand the whole west wall over to an imaginary ship. isshuttleturf() reads the baseturf
	// skipover, which is exactly what create_shuttle() stacks onto a turf it takes, so this
	// is the same thing the survey sees when it meets a real hull.
	var/list/borrowed = list()
	for(var/offset_y in 2 to 6)
		var/turf/hull_wall = spot(2, offset_y)
		hull_wall.insert_baseturf(turf_type = /turf/baseturf_skipover/shuttle)
		borrowed += hull_wall
		TEST_ASSERT(isshuttleturf(hull_wall), "test setup failed to mark [hull_wall] as hull")
	settle()

	var/datum/hull_claim/claim = survey_enclosure(spot(4, 4))
	// Scrub the fake hull marking before asserting. A skipover baseturf left on a turf that
	// goes back into the reservation pool would read as hull to whatever recycles it next.
	reset_block()

	TEST_ASSERT_NULL(claim.refusal, "a room built onto an existing hull's wall was refused: [claim.refusal]")
	for(var/turf/hull_wall as anything in borrowed)
		TEST_ASSERT(!claim.turfs[hull_wall], "the claim tried to take [hull_wall], which already belongs to a hull")
	TEST_ASSERT_EQUAL(length(claim.turfs), 20, "the claim should be the 25 tile room minus the 5 hull tiles it borrows")

/**
 * A commissioned vessel must have a door on its outer hull to serve as the docking port.
 *
 * create_shuttle() seats the mobile port on the turf it is handed and nothing moves it
 * afterwards, so a hull commissioned with the port stranded inboard could never be reseated
 * from anywhere but a construction console it does not have. Worse, the port is the origin
 * docking plants on the berth tile, so every tile standing further out than it lands inside
 * whatever the ship berths against and overwrites it - a big enough scratch-built hull is a
 * battering ram aimed at other players' ships.
 */
/datum/unit_test/voidcrew_hull_survey/proc/test_commission_needs_an_outer_door()
	reset_block()
	build_walled_room()
	settle()

	var/datum/hull_claim/bare = survey_enclosure(spot(4, 4))
	TEST_ASSERT_NOTNULL(validate_hull_claim(bare, null), "a sealed room with no door anywhere was accepted for commissioning; its docking port would have nowhere to sit but inside the hull")

	// Cut an airlock into the south wall. Nothing else about the room changes.
	var/turf/door_turf = spot(4, 2)
	door_turf.ChangeTurf(/turf/open/floor/plating, /turf/open/space)
	new /obj/machinery/door/airlock(door_turf)
	settle()

	var/datum/hull_claim/doored = survey_enclosure(spot(4, 4))
	var/refusal = validate_hull_claim(doored, null)
	TEST_ASSERT_NULL(refusal, "a room with an airlock in its outer wall was refused for commissioning: [refusal]")

	var/list/seat = hull_claim_port_seat(doored.turfs)
	TEST_ASSERT_NOTNULL(seat, "no port seat was found for a room with an airlock in its outer wall")
	TEST_ASSERT_EQUAL(seat[1], door_turf, "the port should seat on the airlock tile, not [seat[1]]")
	// The door picks the facing: it is in the south wall, so the ship's exit faces south.
	TEST_ASSERT_EQUAL(seat[2], SOUTH, "the exit should face out through the wall the airlock is in")

/**
 * A door has to stand on the outermost plane of the face it opens through.
 *
 * A door with hull in front of it is the exact geometry that makes a ship dangerous to dock
 * with, so it is not a seat, no matter that the ship has a door.
 */
/datum/unit_test/voidcrew_hull_survey/proc/test_port_seat_rejects_an_interior_door()
	reset_block()
	var/list/block = list()
	for(var/offset_x in 2 to 6)
		for(var/offset_y in 2 to 6)
			var/turf/scratch = spot(offset_x, offset_y)
			scratch.ChangeTurf(/turf/open/floor/plating, /turf/open/space)
			block += scratch

	// Dead centre: plating stands further out than this door on all four faces.
	new /obj/machinery/door/airlock(spot(4, 4))
	settle()
	TEST_ASSERT_NULL(hull_claim_port_seat(block), "a door buried inside the hull was accepted as a port seat - the plating around it would be driven through anything the ship docked with")

	// The same door in the west face is a seat, and sets the ship's exit facing with it.
	reset_block()
	for(var/turf/scratch as anything in block)
		scratch.ChangeTurf(/turf/open/floor/plating, /turf/open/space)
	var/turf/west_face = spot(2, 4)
	new /obj/machinery/door/airlock(west_face)
	settle()

	var/list/seat = hull_claim_port_seat(block)
	TEST_ASSERT_NOTNULL(seat, "a door standing on the outermost plating was rejected as a port seat")
	TEST_ASSERT_EQUAL(seat[1], west_face, "the port should seat on the airlock tile, not [seat[1]]")
	TEST_ASSERT_EQUAL(seat[2], WEST, "the exit should face west, out through the face the airlock is in")

/**
 * A compartment made by the survey has to be registered on the ship, not merely created.
 *
 * beforeShuttleMove() decides whether a tile travels by area membership, so an area that is
 * not in shuttle_areas leaves its whole room - and everyone standing in it - behind the first
 * time the hull moves. That failure is invisible until launch, which is exactly the shape of
 * the stranded-engine bugs this codebase keeps rediscovering, so it is asserted here rather
 * than trusted.
 *
 * Runs against a stub port rather than a real vessel: create_shuttle() would need an overmap
 * token and an encounter to sit in, and none of that is what this is testing.
 */
/datum/unit_test/voidcrew_hull_survey/proc/test_new_hull_area_belongs_to_the_ship()
	reset_block()
	var/list/room = list()
	for(var/offset_x in 2 to 4)
		for(var/offset_y in 2 to 4)
			var/turf/scratch = spot(offset_x, offset_y)
			scratch.ChangeTurf(/turf/open/floor/plating, /turf/open/space)
			room += scratch
	settle()

	var/area/shuttle/voidcrew/default_area = new()
	default_area.setup("Test Hull")
	var/obj/docking_port/mobile/voidcrew/port = new(spot(3, 3))
	// A port built by hand is never registered - SSshuttle does that for mapped ones -
	// and Destroy() unregisters unconditionally, so without this the teardown logs a
	// "docking_port unregistered multiple times" WARNING and the run is not clean.
	port.register()
	// Subscript assignment, not list(default_area = TRUE): a bare identifier on the left of
	// `=` inside a list() literal is not reliably read as the variable's value.
	port.shuttle_areas = list()
	port.shuttle_areas[default_area] = TRUE
	set_turfs_to_area(room, default_area)

	var/area/fresh = create_hull_area(port, "Aft Storage")
	TEST_ASSERT(port.shuttle_areas[fresh], "a compartment made by create_hull_area() was not registered on the ship; its room would be left behind on the first launch")
	TEST_ASSERT_EQUAL(fresh.type, port.area_type, "the new compartment should be the hull's own area type, not [fresh.type]")
	TEST_ASSERT_EQUAL(fresh.name, "Aft Storage", "the new compartment kept the wrong name: [fresh.name]")
	// hull_area_is_guest() reads shuttle_port to tell our plating from a docked visitor's.
	TEST_ASSERT(!hull_area_is_guest(fresh, port), "the new compartment reads as another ship's area, so the hull would miscount its own footprint")

	// Only the tiles handed over move; the rest of the hull stays where it was.
	var/list/moved = list(spot(2, 2), spot(2, 3))
	assign_hull_area(port, moved, fresh, fresh_area = TRUE)
	for(var/turf/scratch as anything in moved)
		TEST_ASSERT_EQUAL(get_area(scratch), fresh, "[scratch] should have moved into the new compartment")
	TEST_ASSERT_EQUAL(get_area(spot(4, 4)), default_area, "a tile that was not part of the claim was moved out of the default compartment")
	// The default area is kept even when emptied - clear_empty_shuttle_turfs() relies on it.
	TEST_ASSERT(port.shuttle_areas[default_area], "the hull's default compartment was dropped from shuttle_areas")

	// Leave nothing behind: these areas and the port outlive the reservation otherwise.
	// The port goes first, and forced: docking ports answer a plain qdel with
	// QDEL_HINT_LETMELIVE, so an unforced one leaves the port standing in the block, and
	// every later reset_block() qdels it again - each of those runs
	// /obj/docking_port/mobile/Destroy() -> unregister() -> a WARNING, which is on its own
	// enough to stop a CI run being reported clean.
	qdel(port, force = TRUE)
	reset_block()
	// Hand the tiles back to space BEFORE the areas die. reset_block() only swaps turf
	// types, and ChangeTurf keeps a turf's area, so all nine tiles are still standing in
	// these two /area/shuttle instances. Areas are meant to live forever; /area/Destroy()
	// nulls turfs_by_zlevel and turfs_to_uncontain_by_zlevel, and every turf left inside
	// one goes on pointing at the corpse. When this test's reservation is released a few
	// milliseconds later, SSmapping/fire() reads exactly that null list - and because the
	// runtime unwinds fire() before the packet entry is consumed, it retries the same turf
	// every fire for the rest of the round, so no reservation ever drains again. The dead
	// areas are also permanent hard-delete blockers (a turf's loc is a real reference),
	// which is minutes of REF SEARCH per area in a test run.
	evacuate_area(fresh)
	evacuate_area(default_area)
	qdel(fresh)
	qdel(default_area)

/**
 * A room built out past the docking port is legal only if it hands the port a new seat.
 *
 * This is the shape of the "survey rejects my expansion" report: the ship already has an
 * external airlock in its bow, the crew bolt one more row of hull in front of it, and the
 * airlock stops being the outermost thing on that side. The port cannot move to it any more,
 * because a partner ship berthing on it would be planted straight through the new row.
 *
 * Both halves matter. The refusal has to be a refusal - anything else commissions a battering
 * ram - and it has to say where the door goes, in coordinates, because from inside the room
 * the old airlock looks like a perfectly good door and the advice otherwise reads as a lie.
 */
/datum/unit_test/voidcrew_hull_survey/proc/test_expansion_past_the_port_needs_a_door_on_the_new_face()
	reset_block()

	// Hull: 5 wide, 3 deep, at (3,3)-(7,5). The port stands on its north face at (5,5) and
	// faces SOUTH, into the ship - so the side that meets a berth is the north one.
	var/list/hull = list()
	for(var/offset_x in 3 to 7)
		for(var/offset_y in 3 to 5)
			var/turf/scratch = spot(offset_x, offset_y)
			scratch.ChangeTurf(/turf/open/floor/plating, /turf/open/space)
			hull += scratch

	var/area/shuttle/voidcrew/hull_area = new()
	hull_area.setup("Test Hull")
	var/obj/docking_port/mobile/voidcrew/port = new(spot(5, 5))
	// See test_new_hull_area_belongs_to_the_ship(): a hand-built port is unregistered,
	// and Destroy() unregisters regardless, which WARNINGs and dirties the run.
	port.register()
	// Direct assignment, as hull_reseat_port() does: a docking port's dir is bookkeeping
	// paired with port_direction, not something with a visual to update.
	port.dir = SOUTH
	port.shuttle_areas = list()
	port.shuttle_areas[hull_area] = TRUE
	set_turfs_to_area(hull, hull_area)

	// Nothing stands out past the port yet.
	var/list/flush = hull_port_overhang(port, null)
	TEST_ASSERT_EQUAL(flush[1], 0, "a hull whose port sits on its own outer face reported an overhang of [flush[1]]")

	// The new room: two more rows on the bow, (3,6)-(7,7). Not hull yet - this is a claim.
	var/datum/hull_claim/claim = new
	for(var/offset_y in 6 to 7)
		for(var/offset_x in 3 to 7)
			var/turf/scratch = spot(offset_x, offset_y)
			scratch.ChangeTurf(/turf/open/floor/plating, /turf/open/space)
			claim.turfs[scratch] = TRUE
	claim.touched_ports[port] = TRUE
	settle()

	var/turf/outer_line = spot(5, 7)
	var/list/overhang = hull_port_overhang(port, claim.turfs)
	TEST_ASSERT_EQUAL(overhang[1], 2, "two rows built past the port should read as a 2 metre overhang, not [overhang[1]]")

	TEST_ASSERT_NULL(hull_port_reseat_target(port, claim.turfs), "the port was offered a seat on a face with no door on it")
	var/refusal = validate_hull_claim(claim, port)
	TEST_ASSERT_NOTNULL(refusal, "a room built two rows past the docking port, with no door on its new outer face, was accepted")
	// The advice has to name the face and hand over coordinates on the outermost line, or
	// the player rebuilds the door they already have and gets refused again.
	TEST_ASSERT(findtext(refusal, "north"), "the refusal never says which face needs the door: [refusal]")
	TEST_ASSERT(findtext(refusal, ", [outer_line.y])"), "the refusal never gives coordinates on the outermost line (y = [outer_line.y]): [refusal]")

	// Cut an airlock into the new bow. Now the port has somewhere to go and the claim is legal.
	var/obj/machinery/door/airlock/bow_door = new(outer_line)
	settle()

	TEST_ASSERT_EQUAL(hull_port_reseat_target(port, claim.turfs), outer_line, "the port was not offered the airlock standing on the new outermost plating")
	var/accepted = validate_hull_claim(claim, port)
	TEST_ASSERT_NULL(accepted, "an expansion that hands the port a door on its new outer face was still refused: [accepted]")

	// A door one row short of the outermost plating is not a seat: everything in front of it
	// is still driven through whatever the ship berths against.
	qdel(bow_door)
	new /obj/machinery/door/airlock(spot(5, 6))
	settle()
	TEST_ASSERT_NULL(hull_port_reseat_target(port, claim.turfs), "a door set back behind the outermost plating was accepted as a port seat")

	// force, and before the block is wiped. Docking ports answer a plain qdel with
	// QDEL_HINT_LETMELIVE, so the port would survive, reset_block() would qdel it a second
	// time, and /obj/docking_port/mobile/Destroy()'s unregister() would log a WARNING - which
	// is enough on its own to stop a CI run being called clean.
	qdel(port, force = TRUE)
	reset_block()
	evacuate_area(hull_area)
	qdel(hull_area)

/**
 * The drone's half of the same rule: never refuse, but never bury the port in silence either.
 *
 * The survey can refuse a claim before it commits. A drone build cannot - the first tile of a
 * new bow already overhangs the port, so a build-time refusal would make the outer door that
 * legalises the expansion unbuildable. The console did neither: it grew the hull and said
 * nothing, so the crew found out when cargo answered "Obstruction" and the helm refused to
 * launch, with no hint that the docking port was the thing in the way (issue #130).
 *
 * Both outcomes are asserted here because they are the two halves of one promise: with a door
 * on the new outermost plating the port moves itself, and without one the operator is told
 * which face needs the door and where.
 */
/datum/unit_test/voidcrew_hull_survey/proc/test_drone_growth_reseats_or_warns()
	reset_block()

	// Same stub as test_expansion_past_the_port_needs_a_door_on_the_new_face(): 5 wide, 3 deep
	// at (3,3)-(7,5), port on the north face at (5,5) facing SOUTH into the ship.
	var/list/hull = list()
	for(var/offset_x in 3 to 7)
		for(var/offset_y in 3 to 5)
			var/turf/scratch = spot(offset_x, offset_y)
			scratch.ChangeTurf(/turf/open/floor/plating, /turf/open/space)
			hull += scratch

	var/area/shuttle/voidcrew/hull_area = new()
	hull_area.setup("Test Drone Hull")
	var/obj/docking_port/mobile/voidcrew/port = new(spot(5, 5))
	port.register()
	port.dir = SOUTH
	port.shuttle_areas = list()
	port.shuttle_areas[hull_area] = TRUE
	set_turfs_to_area(hull, hull_area)
	settle()

	// Nothing has grown yet: the check has to be silent, or every build in the round prints.
	TEST_ASSERT_NULL(hull_reseat_after_growth(port), "a hull flush with its own docking port was told it overhangs")

	// The drone build. Unlike the survey's claim these tiles are committed straight into the
	// hull's area, which is the state expand_shuttle_to_turf() leaves behind.
	var/list/new_row = list()
	for(var/offset_x in 3 to 7)
		var/turf/scratch = spot(offset_x, 6)
		scratch.ChangeTurf(/turf/open/floor/plating, /turf/open/space)
		new_row += scratch
	set_turfs_to_area(new_row, hull_area)
	settle()

	var/turf/outer_line = spot(5, 6)

	// No door out there yet. The build stands, the port does not move, and the operator is
	// told which face and which line to put the door on.
	var/list/warned = hull_reseat_after_growth(port)
	TEST_ASSERT_NOTNULL(warned, "a drone build past the docking port said nothing at all")
	TEST_ASSERT_NULL(warned[1], "the port was reseated onto a face with no door on it")
	TEST_ASSERT_EQUAL(get_turf(port), spot(5, 5), "the port moved even though there was no door to move it to")
	var/warning = warned[2]
	TEST_ASSERT(findtext(warning, "north"), "the warning never says which face needs the door: [warning]")
	TEST_ASSERT(findtext(warning, ", [outer_line.y])"), "the warning never gives coordinates on the outermost line (y = [outer_line.y]): [warning]")

	// Now the crew do what the warning asked. The door is built on a tile that is already
	// hull, so nothing expands - this is the case the console has to catch on the airlock
	// build itself, or following the instruction appears to do nothing.
	var/obj/machinery/door/airlock/bow_door = new(outer_line)
	settle()

	var/list/reseated = hull_reseat_after_growth(port)
	TEST_ASSERT_NOTNULL(reseated, "a door on the new outermost plating did not move the port")
	TEST_ASSERT_EQUAL(reseated[1], outer_line, "the port was not reseated onto the airlock standing on the new outermost plating")
	TEST_ASSERT_EQUAL(get_turf(port), outer_line, "the reseat reported a move it did not make")
	TEST_ASSERT(findtext(reseated[2], "([outer_line.x], [outer_line.y])"), "the reseat notice never says where the port went: [reseated[2]]")

	// And the hull is legal again, so nothing further is said on the next build.
	TEST_ASSERT_NULL(hull_reseat_after_growth(port), "the hull still reported an overhang after the port was reseated onto its outermost door")

	// A door BEHIND the outermost plating is not a seat. Grow one more row past the reseated
	// port and leave the airlock where it is: the port must stay put and warn again.
	var/list/further = list()
	for(var/offset_x in 3 to 7)
		var/turf/scratch = spot(offset_x, 7)
		scratch.ChangeTurf(/turf/open/floor/plating, /turf/open/space)
		further += scratch
	set_turfs_to_area(further, hull_area)
	settle()

	var/list/warned_again = hull_reseat_after_growth(port)
	TEST_ASSERT_NOTNULL(warned_again, "a second drone build past the reseated port said nothing")
	TEST_ASSERT_NULL(warned_again[1], "a door one row behind the outermost plating was accepted as a port seat")
	TEST_ASSERT_EQUAL(get_turf(port), outer_line, "the port moved onto a door that no longer stands on the outermost plating")
	TEST_ASSERT(findtext(warned_again[2], ", [spot(5, 7).y])"), "the second warning still quotes the old outermost line: [warned_again[2]]")

	qdel(bow_door)
	// force, and before the block is wiped - see the note in the test above.
	qdel(port, force = TRUE)
	reset_block()
	evacuate_area(hull_area)
	qdel(hull_area)

/**
 * The bearing on a refusal has to be two legs, not a Chebyshev distance and one compass point.
 *
 * get_dist() reports the larger leg and get_dir() throws the smaller one away, so a tile four
 * north and two east used to come back as "4 metres northeast" - a bearing that walks you into
 * the wrong tile and reads as a bug in the survey rather than in the sentence.
 */
/datum/unit_test/voidcrew_hull_survey/proc/test_survey_bearing_reports_both_legs()
	var/turf/here = spot(3, 3)
	var/turf/there = spot(5, 7)

	var/bearing = hull_survey_bearing(here, there)
	TEST_ASSERT(findtext(bearing, "4 metres north"), "the bearing lost the north-south leg: [bearing]")
	TEST_ASSERT(findtext(bearing, "2 metres east"), "the bearing lost the east-west leg: [bearing]")
	TEST_ASSERT(findtext(bearing, "([there.x], [there.y])"), "the bearing gave no coordinates to check it against: [bearing]")

	var/straight = hull_survey_bearing(here, spot(3, 6))
	TEST_ASSERT(findtext(straight, "3 metres south") == 0, "a tile due north was reported as south: [straight]")
	TEST_ASSERT(findtext(straight, "3 metres north"), "a tile three due north was not reported as three north: [straight]")
	TEST_ASSERT(findtext(straight, "east") == 0 && findtext(straight, "west") == 0, "a tile due north invented a sideways leg: [straight]")

	var/underfoot = hull_survey_bearing(here, here)
	TEST_ASSERT(findtext(underfoot, "standing on"), "a problem on the player's own tile was not reported as such: [underfoot]")

/// Moves every turf still inside `leaving` back into the reserved block's own space area,
/// so the area can be deleted without stranding turfs in a destroyed datum. See the call site.
/datum/unit_test/voidcrew_hull_survey/proc/evacuate_area(area/leaving)
	if(isnull(leaving))
		return
	var/area/space_area = GLOB.areas_by_type[world.area]
	if(isnull(space_area) || space_area == leaving)
		return
	// get_turfs_from_all_zlevels() builds a fresh list, so moving turfs out underneath it is safe
	for(var/turf/tile as anything in leaving.get_turfs_from_all_zlevels())
		tile.change_area(leaving, space_area)

/// Lays a 5x5 at (2,2)-(6,6): a ring of walls around a 3x3 of plating.
/datum/unit_test/voidcrew_hull_survey/proc/build_walled_room()
	for(var/offset_x in 2 to 6)
		for(var/offset_y in 2 to 6)
			var/turf/scratch = spot(offset_x, offset_y)
			var/on_edge = (offset_x == 2 || offset_x == 6 || offset_y == 2 || offset_y == 6)
			scratch.ChangeTurf(on_edge ? /turf/closed/wall : /turf/open/floor/plating, /turf/open/space)

/// Lays a 3x3 of plating at (2,2)-(4,4) and glazes every outward edge with a thin window.
/datum/unit_test/voidcrew_hull_survey/proc/build_window_room()
	for(var/offset_x in 2 to 4)
		for(var/offset_y in 2 to 4)
			var/turf/scratch = spot(offset_x, offset_y)
			scratch.ChangeTurf(/turf/open/floor/plating, /turf/open/space)
			if(offset_x == 2)
				glaze(scratch, WEST)
			if(offset_x == 4)
				glaze(scratch, EAST)
			if(offset_y == 2)
				glaze(scratch, SOUTH)
			if(offset_y == 4)
				glaze(scratch, NORTH)

/// One anchored directional window on `face`, which is what a player's thin window amounts to.
/// Direction goes through New() so Initialize() has it before its own air_update_turf().
/datum/unit_test/voidcrew_hull_survey/proc/glaze(turf/target, face)
	new /obj/structure/window(target, face)
	target.immediate_calculate_adjacent_turfs()
