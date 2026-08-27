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
	reset_block()
	// force = TRUE is not optional. /obj/docking_port/Destroy() returns QDEL_HINT_LETMELIVE
	// unless forced (code/modules/shuttle/shuttle.dm:56-63), so a bare qdel() is a NO-OP that
	// still runs /obj/docking_port/mobile/Destroy() first - which nulls shuttle_areas. What
	// survives is a live, non-QDELETED mobile port with a null shuttle_areas standing on this
	// reservation's ground, and /turf/proc/empty() never deletes docking ports, so it rides
	// the release back into the free pool. The next SSshuttle.load_template() scans its fresh
	// block, finds that leftover port FIRST, hands it back as SSshuttle.preview_shuttle and
	// qdels the hull's own port as a "duplicate" - which is how it killed
	// voidcrew_hull_mount_integrity with a bare "bad index".
	qdel(port, force = TRUE)
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
