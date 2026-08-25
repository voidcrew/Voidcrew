/**
 * # Autopilot course-planner conformance
 *
 * `plan_overmap_course()` (voidcrew/modules/overmap/code/modules/overmap/
 * ship_autopilot.dm) is the pure A* core the ship autopilot flies. Two of its
 * behaviours shipped subtly wrong once and were only caught in play, so they
 * are pinned here:
 *
 * - **Optimality and tie-breaking.** Any two tiles are joined by many
 *   equal-cost Chebyshev courses; the expansion order must resolve ties into
 *   the straight line a pilot would draw, not an arc (the original fixed push
 *   order bowed every eastbound course north-east).
 * - **Edge wrap needs to be earned.** The overmap wraps and the planner may
 *   route through the seam, but the 2026-08 playtests showed a wrap that
 *   merely TIES a flat route reads as "wrong direction" on the chart and
 *   flips between re-plans. A wrap step now carries a small surcharge
 *   (AUTOPILOT_WRAP_COST, 3 at the time of writing), so the seam only wins
 *   when it saves real distance.
 *
 * Everything here is pure list/string arithmetic on the X band, which is fixed
 * by compile-time defines (tiles 2..50, span 49). A CIBUILDING world boots
 * MetaStation with no overmap z-level to fly (see voidcrew_helpers.dm), so the
 * tests pass no pilot ship: with a null pilot the planner reads no turfs and
 * no ship state, which is exactly the surface under test.
 */

/**
 * Flyable X band. HARDCODED, not derived from OVERMAP_LEFT/RIGHT_SIDE_COORD:
 * those are voidcrew defines and the dme includes code/ before voidcrew/, so
 * they do not exist yet when this file compiles. The values are validated at
 * runtime against the wrap helpers before anything else runs (first block of
 * Run()), so a change to OVERMAP_SIZE fails loudly here with instructions
 * instead of silently testing the wrong band.
 */
#define COURSE_TEST_LOW_X 2
#define COURSE_TEST_HIGH_X 50

/datum/unit_test/autopilot_course

/datum/unit_test/autopilot_course/proc/course_contains(list/course, tile_x, tile_y)
	for(var/list/node as anything in course)
		if(node[1] == tile_x && node[2] == tile_y)
			return TRUE
	return FALSE

/datum/unit_test/autopilot_course/Run()
	// Guard the hardcoded band before trusting it: the wrap helpers embed the
	// real OVERMAP_PATH_* values, so if these fail, the map size changed and
	// COURSE_TEST_LOW_X/HIGH_X above must be updated to match.
	TEST_ASSERT_EQUAL(overmap_wrap_x(COURSE_TEST_LOW_X - 1), COURSE_TEST_HIGH_X, "hardcoded band stale: update COURSE_TEST_LOW_X/HIGH_X to the current OVERMAP_PATH_* values")
	TEST_ASSERT_EQUAL(overmap_wrap_x(COURSE_TEST_HIGH_X + 1), COURSE_TEST_LOW_X, "hardcoded band stale: update COURSE_TEST_LOW_X/HIGH_X to the current OVERMAP_PATH_* values")
	TEST_ASSERT_EQUAL(overmap_wrap_x(COURSE_TEST_LOW_X), COURSE_TEST_LOW_X, "wrap_x mangled an in-band value")

	var/start_x = COURSE_TEST_LOW_X + 8 // absolute x 10
	// A mid-band Y row, well away from the Y seam so only X behaviour is in
	// play. The Y band hangs off world.maxy (OVERMAP_NORTH_SIDE_COORD), which
	// is runtime state, so this needs no define.
	var/row = world.maxy - 25

	// A flat hop east is planned as exactly that: no arc, no detour, and the
	// destination is the last node. 10 steps, every node on the row.
	var/list/straight = plan_overmap_course(start_x, row, start_x + 10, row, null)
	TEST_ASSERT(!isnull(straight), "no course found for a trivial 10-tile hop")
	TEST_ASSERT_EQUAL(length(straight), 10, "a 10-tile flat hop planned [length(straight)] steps")
	for(var/list/node as anything in straight)
		TEST_ASSERT_EQUAL(node[2], row, "a flat eastbound course left its row (tie-break regression: node at [node[1]],[node[2]])")
	var/list/last = straight[length(straight)]
	TEST_ASSERT_EQUAL(last[1], start_x + 10, "course did not end on the destination")

	// 25 tiles east: the seam route is 24 steps, a tie in real distance once
	// its surcharge is paid (24 + 3 > 25), so the flat route must win. Before
	// the surcharge this was a coin toss that flipped between re-plans.
	var/list/flat = plan_overmap_course(start_x, row, start_x + 25, row, null)
	TEST_ASSERT(!isnull(flat), "no course found for the 25-tile hop")
	TEST_ASSERT_EQUAL(length(flat), 25, "25 tiles east should stay flat (wrap surcharge regression), planned [length(flat)] steps")

	// 30 tiles east is 19 through the seam: saves 11 tiles, well past the
	// surcharge, so the wrap must still be taken. The seam stays a real route,
	// it just has to be earned.
	var/list/wrapped = plan_overmap_course(start_x, row, start_x + 30, row, null)
	TEST_ASSERT(!isnull(wrapped), "no course found for the 30-tile hop")
	TEST_ASSERT_EQUAL(length(wrapped), 19, "30 tiles east should wrap in 19 steps, planned [length(wrapped)]")

	// A hazard wall across the straight line is routed around, not through:
	// stamp a 1000-cost core the way build_autopilot_danger_map() does and
	// assert no course node lands on a wall tile, at a detour cost of at most
	// a couple of tiles.
	var/list/danger = list()
	var/wall_x = start_x + 5
	for(var/wall_y in row - 1 to row + 1)
		stamp_autopilot_danger(danger, wall_x, wall_y, 0, 1000, 1, 60)
	var/list/detour = plan_overmap_course(start_x, row, start_x + 10, row, danger)
	TEST_ASSERT(!isnull(detour), "no course found around a 3-tile wall")
	for(var/wall_y in row - 1 to row + 1)
		TEST_ASSERT(!course_contains(detour, wall_x, wall_y), "course crossed the hazard wall at [wall_x],[wall_y]")
	TEST_ASSERT(length(detour) <= 13, "a 3-tile wall cost [length(detour) - 10] extra tiles; the detour should hug the wall")

#undef COURSE_TEST_LOW_X
#undef COURSE_TEST_HIGH_X
