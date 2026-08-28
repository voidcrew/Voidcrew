/**
 * # Overmap flight and the helm: 4,566 lines nothing has ever flown
 *
 * `ship.dm` is the biggest single file in the fork and carries the most upstream
 * subsystem surface of any feature in it, and until this file existed **no test
 * had ever moved a ship**. `voidcrew_autopilot_course.dm` plans courses with a
 * null pilot and never flies one; `voidcrew_docking_transit.dm` transplants a
 * hull between berths but never touches the overmap token. The helm - the single
 * screen every one of those systems is driven from - had no coverage at all, so
 * its gates broke silently in merges: an action string renamed on the .tsx side,
 * a `ui_data` key drifting, the crew check quietly passing everyone.
 *
 * The three breakage classes this file is built against:
 *
 *  1. **Movement rules that stop gating when the engines go cold.** The fork's
 *     own comment at `ship.dm:3031-3043` records the live bug: the zone-boundary
 *     check used to live only in `burn_engines()`, "and the ordinary way to fly
 *     is to burn up to speed and then coast", so **every coasting hull crossed
 *     zone lines for free** and the autopilot did it on every single flight,
 *     because `autopilot_steer()` deliberately drops the burn at cruise. A rule
 *     that is not inside `tick_move()` does not apply to a moving ship. Two of
 *     those rules are flown here on a genuinely coasting hull (wraparound and the
 *     zone crossing), and `/datum/unit_test/voidcrew_flight/rule_census` pins the
 *     shape of the tick path itself so a rule cannot be quietly lifted back out.
 *  2. **Thrust that silently produces nothing.** `est_thrust` is a sum of rated
 *     `engine_power` (`refresh_engines()`, ship.dm:867) while a burn returns the
 *     share actually delivered, and for an ion thruster the helm's fuel gauge
 *     reads **stored SMES charge** while `burn_engine()` draws **live wire
 *     power** (`electric.dm:46-55`). The reconciliation is one line -
 *     `electric.dm:61-62`, "report a dead wire as an empty tank" - and nothing
 *     tested it. A ship that will not move with every gauge reading healthy is
 *     the single most expensive support call this fork has.
 *  3. **Helm gates that pass everyone.** `is_crew_member()` (`_helm.dm:611-624`)
 *     is the only server-side authorisation the flight controls have, it is read
 *     off `usr`, and every one of the console's 24 actions sits behind it.
 *
 * ## Determinism
 *
 * Nothing here waits on a subsystem. `tick_move()` is armed by `addtimer()`
 * (ship.dm:2994, :3090) and `process()` by SSfastprocess/SSobj, and **both are
 * plain procs**: every tick in this file is a direct call, so the whole test runs
 * inside one BYOND tick and no timer, no MC fire and no autopilot poll can land
 * in the middle of an assertion. The one rule that follows from that: never
 * sleep between arming a burn and asserting on it, and never leave the fixture
 * ship burning or moving when `vc_release_test_ship()` (which does sleep) is
 * called. Every phase ends by putting the ship back at rest.
 *
 * Two sources of run-to-run variation are pinned rather than tolerated: a drunk
 * pilot fumbles manual headings (`drunken_heading()`, `_helm.dm:778-799`), so
 * sobriety is asserted before any heading is driven; and the autopilot brakes for
 * anything in its danger map, so the flights below are run down a lane checked against
 * that map itself rather than against a guess at what might be standing on it.
 *
 * ## Coverage boundary
 *
 * - `voidcrew_engine_interactions.dm` owns the per-engine contract - `burn_engine()`
 *   fuel maths, `thrust_refusal_reason()` on a plasma thruster, the heater. This
 *   file owns the *ship-level* integration above it: engine list -> summed thrust
 *   -> acceleration -> velocity -> tile step, and how the helm reports its absence.
 * - `voidcrew_docking_transit.dm` owns dock cycles and the transit reservation.
 *   `dock` / `undock` / `act_overmap` are enumerated in the action census here and
 *   deliberately not driven; see the census table for the per-action reasons.
 * - `voidcrew_autopilot_course.dm` owns `plan_overmap_course()` as pure geometry.
 *   This file owns the flying of a plan: engage, steer, arrive, cancel.
 *
 * ## Defines
 *
 * Unit tests compile at the `code/modules/unit_tests` include position
 * (`tgstation.dme:6898`), which is **before** `voidcrew/_DEFINES/` (7203-7209) and
 * before `ship.dm` (7689). No fork define is reachable here: not
 * `OVERMAP_SHIP_FLYING`, not `BURN_NONE`/`BURN_STOP` (which are file-local to
 * ship.dm anyway), not `MAGNITUDE()`, not the overmap coordinate band. They are
 * spelled as literals below with the define named, the convention
 * `voidcrew_loot.dm:196` and `voidcrew_docking_transit.dm` already use, and the
 * band literals are validated against the wrap helpers at runtime before anything
 * trusts them.
 */

/// `OVERMAP_Z_LEVEL` (voidcrew/_DEFINES/overmap.dm:2) - the centcom z, which every
/// map configuration has, so the overmap exists even in a CIBUILDING world.
#define FLIGHT_OVERMAP_Z 1
/// `OVERMAP_LEFT_SIDE_COORD` / `OVERMAP_RIGHT_SIDE_COORD` (overmap.dm:8-9). These are
/// the closed edge columns; the flyable band is the two tiles inside them.
#define FLIGHT_LEFT_EDGE 1
#define FLIGHT_RIGHT_EDGE 51
/// The band `tick_move()` wraps between (ship.dm:3014-3015): `low_x` and `high_x`.
#define FLIGHT_WRAP_LOW_X 2
#define FLIGHT_WRAP_HIGH_X 50
/// `BURN_NONE` / `BURN_STOP` - ship.dm:11-12, file-local there.
#define FLIGHT_BURN_NONE 0
#define FLIGHT_BURN_STOP -1
/// `OVERMAP_SHIP_FLYING` - overmap.dm:32.
#define FLIGHT_STATE_FLYING "flying"
/**
 * The hull both ship tests build.
 *
 * NOT the fixture's default. `vc_create_test_ship()` picks the smallest purchasable hull
 * by footprint, which is the Pill-class-B(lack) "Suicide Device" - a **three tile** novelty
 * hull whose every tile is furniture, with no open deck at all. The first run of these tests
 * failed on exactly that: there is nowhere aboard it to bolt a thruster, and nowhere for a
 * crewman to stand at a console either.
 *
 * The Goon is the smallest hull with real rooms - its own catalog entry says so
 * ("The cheapest hull with real rooms", goon.dm:24-26) - at 209 tiles with ~35 genuinely
 * empty deck tiles, and it is already the hull `voidcrew_ship_lifecycle.dm:186` builds for
 * the same reason. It is fully modular, so building it also exercises the module load path
 * rather than a single flat .dmm.
 *
 * Its helm arrives with a module rather than with the hull, and that is safe by design:
 * `goon_cockpit_standard` is `is_default = TRUE`, the loader falls back to a slot's default
 * whenever a player has selected nothing, and goon.dm:58-61 makes "EVERY module here must
 * ship a helm console" a documented invariant of the slot. Every cockpit .dmm on disk, in
 * all four themes, maps one.
 */
#define FLIGHT_TEST_HULL /datum/map_template/shuttle/voidcrew/goon

/// Source files the census tests read.
#define FLIGHT_SHIP_SOURCE "voidcrew/modules/overmap/code/modules/overmap/ship.dm"
#define FLIGHT_HELM_SOURCE "voidcrew/modules/shuttle/helm/_helm.dm"
#define FLIGHT_ION_SOURCE "voidcrew/modules/shuttle/engine/electric.dm"

/datum/unit_test/voidcrew_flight
	abstract_type = /datum/unit_test/voidcrew_flight
	/// Deck tiles this test has already bolted something onto, so a second mount does
	/// not stack on the first. Instance state: one list per running test.
	var/list/turf/flight_used_mounts = list()

// ===========================================================================
// Shared helpers
// ===========================================================================

/// `MAGNITUDE(speed[1], speed[2])`, spelled out because the macro is a fork define.
/// `speed` starts as `list(null, null)` (ship.dm:121), hence the `|| 0`.
/datum/unit_test/voidcrew_flight/proc/flight_magnitude(obj/structure/overmap/ship/ship)
	var/speed_x = ship.speed[1] || 0
	var/speed_y = ship.speed[2] || 0
	return sqrt(speed_x * speed_x + speed_y * speed_y)

/// The overmap turf at a tile coordinate, or null if that is not flyable ground.
/datum/unit_test/voidcrew_flight/proc/flight_tile(tile_x, tile_y)
	var/turf/tile = locate(tile_x, tile_y, FLIGHT_OVERMAP_Z)
	if(!istype(tile, /turf/open/overmap))
		return null
	return tile

/// `zone_type` of the zone a tile belongs to (1/2/3 = ZONE_GREEN/YELLOW/RED,
/// voidcrew/_DEFINES/overmap_zones.dm:5-9), or null off the zone grid.
/datum/unit_test/voidcrew_flight/proc/flight_zone_type(turf/tile)
	if(!tile)
		return null
	var/datum/overmap_zone/zone = SSovermap_zones?.get_zone(tile)
	return zone?.zone_type

/**
 * Tiles holding an overmap EVENT, as an assoc "x,y" -> TRUE, optionally with a halo.
 *
 * Deliberately events and nothing else. The first version of this excluded every
 * `/obj/structure/overmap` with a five-tile halo, which in a UNIT_TESTS world is
 * self-defeating: `spawn_initial_ship()` parks one hull per template on the overmap
 * (overmap.dm:987-1004), so ~44 hulls each stamping an 11x11 box saturates a 49-wide
 * map and no lane exists anywhere. It was also excluding the wrong things. What can
 * actually interfere with a test flight is a short list:
 *
 *  - **`check_hazards()`** (ship.dm:3053) fires on entry and reads only
 *    `/obj/structure/overmap/event` on the tile stepped onto. A parked hull, a planet,
 *    a ruin or an outpost on the lane does nothing at all: the step is a `forceMove()`,
 *    the overmap has no collision, and none of them is an event.
 *  - **The autopilot's brake** trips on the danger map at or above
 *    AUTOPILOT_HARM_THRESHOLD, which only the hazard core (1000) and the hostile core
 *    (400) reach - the halo bands (60/80) exist to bias the planner toward a wide berth
 *    and explicitly never brake (ship_autopilot.dm:83-90).
 *  - And that danger map is built from `discovered_contacts`, i.e. only what this hull's
 *    own sensors have actually seen, so it is nearly empty for a freshly built ship
 *    however busy the map is.
 *
 * So the cheap scan excludes event tiles - an undiscovered event still hurts you when
 * you fly onto it - and the autopilot lane is then verified against the ship's REAL
 * danger map rather than against a proxy for it. See flight_find_autopilot_lane().
 */
/datum/unit_test/voidcrew_flight/proc/flight_event_map(halo = 0)
	var/list/dirty = list()
	var/turf/corner_low = locate(FLIGHT_WRAP_LOW_X, world.maxy - 49, FLIGHT_OVERMAP_Z)
	var/turf/corner_high = locate(FLIGHT_WRAP_HIGH_X, world.maxy - 1, FLIGHT_OVERMAP_Z)
	if(!corner_low || !corner_high)
		return dirty
	for(var/turf/tile as anything in block(corner_low, corner_high))
		if(!istype(tile, /turf/open/overmap))
			continue
		if(!(locate(/obj/structure/overmap/event) in tile))
			continue
		for(var/offset_x in -halo to halo)
			for(var/offset_y in -halo to halo)
				dirty["[tile.x + offset_x],[tile.y + offset_y]"] = TRUE
	return dirty

/// TRUE when every listed x on `row` is flyable ground, empty of traffic, and in the
/// same zone as the first - i.e. nothing on the run can brake, damage or re-zone us.
/datum/unit_test/voidcrew_flight/proc/flight_run_is_clear(list/dirty, row, list/columns)
	var/reference_zone
	for(var/column in columns)
		var/turf/tile = flight_tile(column, row)
		if(!tile)
			return FALSE
		if(dirty["[column],[row]"])
			return FALSE
		var/zone_type = flight_zone_type(tile)
		if(isnull(zone_type))
			return FALSE
		if(isnull(reference_zone))
			reference_zone = zone_type
		else if(zone_type != reference_zone)
			return FALSE
	return TRUE

/// Candidate west-to-east runs of `run_length` clear tiles, as `list(start_x, row)`, at
/// most one per row so the candidates are spread across the map rather than bunched into
/// one corner of it. Rows are walked from the south edge inward, so the set of candidates
/// is the same on every run.
/datum/unit_test/voidcrew_flight/proc/flight_collect_lanes(list/dirty, run_length, max_lanes = 16)
	var/list/lanes = list()
	for(var/row in (world.maxy - 48) to (world.maxy - 2))
		for(var/start_x in (FLIGHT_WRAP_LOW_X + 1) to (FLIGHT_WRAP_HIGH_X - run_length))
			var/list/columns = list()
			for(var/step in 0 to run_length - 1)
				columns += start_x + step
			if(!flight_run_is_clear(dirty, row, columns))
				continue
			lanes += list(list(start_x, row))
			break // one candidate per row
		if(length(lanes) >= max_lanes)
			break
	return lanes

/**
 * A lane the autopilot will fly in a straight line, verified against the ship's own
 * danger map rather than against a guess at it.
 *
 * The cheap scan above only knows about events. This walks the candidates it produced,
 * stands the ship on each in turn, and asks `build_autopilot_danger_map()` - the exact
 * list `autopilot_steer()` brakes and re-plans from - whether the run is clean. That
 * catches the two things the scan cannot: a hostile this hull can see, which stamps a
 * two-tile core at the braking threshold, and any halo band that would bend the plotted
 * course off the row and break the one-tile-per-tick assertions.
 *
 * The cache is dropped between candidates: it lives for AUTOPILOT_DANGER_LIFETIME and is
 * keyed to nothing, so a stale one would answer for the previous position.
 *
 * Returns `list(start_x, row)`, with the ship already standing on the start tile.
 */
/datum/unit_test/voidcrew_flight/proc/flight_find_autopilot_lane(obj/structure/overmap/ship/ship, run_length)
	var/list/dirty = flight_event_map(0)
	var/list/candidates = flight_collect_lanes(dirty, run_length)
	if(!length(candidates))
		TEST_FAIL("no [run_length]-tile run of event-free, single-zone overmap ground exists anywhere to fly a course down")
		return null

	var/rejected = 0
	for(var/list/lane as anything in candidates)
		var/start_x = lane[1]
		var/row = lane[2]
		ship.full_stop()
		ship.forceMove(flight_tile(start_x, row))
		// Both caches, not just the danger one: the contact snapshot behind it is cached
		// for a second too, and no time passes inside this loop, so a stale one would have
		// every candidate judged on what the sensors saw from the FIRST candidate.
		ship.autopilot_danger_cache = null
		ship.contact_snapshot = null
		var/list/danger = ship.build_autopilot_danger_map()
		var/clean = TRUE
		for(var/step in 0 to run_length - 1)
			if(danger["[start_x + step],[row]"])
				clean = FALSE
				break
		if(clean)
			return lane
		rejected++
	TEST_FAIL("all [rejected] candidate lane\s carried something on the ship's own autopilot danger map. That map holds only what this hull has DISCOVERED (ship_autopilot.dm:510-532), \
		and a freshly built hull has discovered almost nothing, so every candidate coming back dirty means either the sensors are pre-loading contacts at spawn or the danger map has \
		started stamping things it did not stamp before.")
	return null

/// The first row on which the ship can be flown off the east edge and back on at the
/// west one - the seam `tick_move()` wraps across (ship.dm:3019-3022).
/datum/unit_test/voidcrew_flight/proc/flight_find_seam_row(list/dirty)
	for(var/row in (world.maxy - 48) to (world.maxy - 2))
		if(flight_run_is_clear(dirty, row, list(FLIGHT_WRAP_HIGH_X - 2, FLIGHT_WRAP_HIGH_X - 1, FLIGHT_WRAP_HIGH_X, FLIGHT_WRAP_LOW_X, FLIGHT_WRAP_LOW_X + 1)))
			return row
	return null

/**
 * A tile pair that straddles a zone boundary west-to-east, as `list(turf, turf)`.
 *
 * Zones are concentric rings by distance from the sun (zone_controller.dm:101-122), so any
 * row crossing the middle of the map passes through two of them. `dirty` is normally empty
 * here, and that is correct rather than lax: the step under test never completes - the
 * crossing is caught and the ship is held on the near side - so nothing on either tile can
 * be flown into, and excluding traffic would only shrink the search for no reason.
 */
/datum/unit_test/voidcrew_flight/proc/flight_find_zone_boundary(list/dirty)
	for(var/row in (world.maxy - 40) to (world.maxy - 10))
		for(var/column in (FLIGHT_WRAP_LOW_X + 2) to (FLIGHT_WRAP_HIGH_X - 2))
			var/turf/from_tile = flight_tile(column, row)
			var/turf/to_tile = flight_tile(column + 1, row)
			if(!from_tile || !to_tile)
				continue
			if(dirty["[column],[row]"] || dirty["[column + 1],[row]"])
				continue
			var/from_zone = flight_zone_type(from_tile)
			var/to_zone = flight_zone_type(to_tile)
			if(isnull(from_zone) || isnull(to_zone) || from_zone == to_zone)
				continue
			return list(from_tile, to_tile)
	return null

/**
 * Parks the ship on ordinary ground: stopped, and with two clear tiles of the SAME zone
 * to its east.
 *
 * A phase that leaves the ship standing where it happened to finish hands the next phase
 * a loaded gun, and one of them is genuinely loaded: the zone-crossing phase deliberately
 * ends with the hull held one tile west of a zone line. `burn_engines()` carries its own
 * crossing check (ship.dm:4339-4345) for the case where the crew is already sitting on the
 * line, so the very next eastward burn starts a fresh transition instead of burning - and
 * `autopilot_steer()` returns without touching an engine while `zone_transitioning` is set
 * (ship_autopilot.dm:764) while `engage_autopilot()` does not check it at all. That
 * combination reports as an autopilot that plots a course and never lights the engines,
 * which is a convincing impression of a broken autopilot and was not one.
 *
 * So phases that move the ship put it back on neutral ground, and the phases that burn
 * assert they are on it.
 */
/datum/unit_test/voidcrew_flight/proc/flight_park_on_neutral_ground(obj/structure/overmap/ship/ship)
	var/list/lanes = flight_collect_lanes(flight_event_map(0), 3, 1)
	if(!length(lanes))
		TEST_FAIL("no three-tile run of event-free, single-zone overmap ground exists to park the test ship on between phases")
		return FALSE
	var/list/lane = lanes[1]
	ship.full_stop()
	ship.forceMove(flight_tile(lane[1], lane[2]))
	return TRUE

/**
 * The first free deck tile aboard, in map order, never handing out the same one twice.
 *
 * Deliberately not `get_random_open_ship_turf()` (ship_event_helpers.dm:57-62), which the
 * in-tree thruster harness uses. Two reasons, both learned from the first run of this file:
 *
 *  - **It gives up.** It rolls a random hull tile 20 times and returns null if all 20 were
 *    furniture. On a hull that is a sixth open floor that is a few-percent chance of a red
 *    test on a perfectly good tree, which is the definition of a flaky one. An ordered walk
 *    of every hull tile either finds a free tile or proves there is none.
 *  - **It repeats.** Two mounts in one test could land on one tile. Whether that matters
 *    depends on the density of what was placed first, which is not something a test should
 *    be quietly depending on; the used-tile list makes it explicit instead.
 *
 * `return_turfs()` walks the port's rectangle in a fixed order, so the tile picked is the
 * same on every run - no random anywhere in this file.
 */
/datum/unit_test/voidcrew_flight/proc/flight_find_mount_turf(obj/structure/overmap/ship/ship)
	var/scanned = 0
	var/open_floors = 0
	for(var/turf/hull_turf as anything in ship.shuttle.return_turfs())
		if(!hull_turf)
			continue
		scanned++
		if(!istype(hull_turf, /turf/open/floor))
			continue
		open_floors++
		if(hull_turf in flight_used_mounts)
			continue
		if(hull_turf.is_blocked_turf())
			continue
		flight_used_mounts += hull_turf
		return hull_turf
	TEST_FAIL("no free deck tile aboard [ship.source_template?.name || ship.name] to bolt a test machine onto: [scanned] hull tile\s, [open_floors] of them open floor, none of those unblocked and unused. The hull this file builds is FLIGHT_TEST_HULL, chosen because the fixture's default is a three-tile novelty with no deck at all - if the Goon has stopped having open floor, pick another hull rather than loosening this, because a hull with nowhere to stand cannot be flown by a crew either.")
	return null

/**
 * Bolts a void thruster onto the hull's own deck and registers it, the way a
 * player-built engine registers.
 *
 * `/obj/machinery/power/shuttle_engine/ship/void` (voidcrew/modules/shuttle/engine/
 * void.dm) is production code whose `return_fuel()`/`return_fuel_cap()` are both
 * TRUE and whose `burn_engine()` needs no powernet and no heater. That is exactly
 * why it is used here: the hull's own thrusters are fuelled and electric ones whose
 * output depends on what its heaters and its powernet happen to hold at the moment
 * the test runs, and a flight test whose first assertion is a coin toss on the ship's
 * fuel and power state tests the fuel and power, not the flight. The same affordance, for the same
 * reason, is already in-tree at `tools/instance_census/ghost_round.dm:1489-1515`,
 * which documents that it skips no part of the flight path: `can_thrust()`,
 * `burn_engines()`, `accelerate()`, `adjust_speed()` and `tick_move()` all run
 * exactly as they do for a fuelled hull.
 *
 * The registration is the real one: `set_anchored()` then `on_construction()`
 * (code/game/shuttle_engines.dm:56-62), which resolves the hull with
 * `SSshuttle.get_containing_shuttle(src)` and calls `connect_to_shuttle()`. That
 * an engine bolted to a ship's own deck ends up in `shuttle.engine_list` is itself
 * asserted here - it is the thing every "my thrusters vanished" report is about.
 */
/datum/unit_test/voidcrew_flight/proc/flight_mount_thruster(obj/structure/overmap/ship/ship, engine_type = /obj/machinery/power/shuttle_engine/ship/void)
	var/turf/mount = flight_find_mount_turf(ship)
	if(!mount)
		return null
	var/obj/machinery/power/shuttle_engine/ship/thruster = new engine_type(mount)
	thruster.set_anchored(TRUE)
	thruster.on_construction()
	if(!(thruster in ship.shuttle.engine_list))
		TEST_FAIL("a [thruster.type] bolted down on the hull's own deck at [AREACOORD(thruster)] did not register in shuttle.engine_list. \
			connect_to_shuttle() resolves the hull through SSshuttle.get_containing_shuttle(); an engine the hull does not list produces no thrust and \
			never appears on the helm (shuttle_engine.dm:160-170).")
		qdel(thruster)
		return null
	return thruster

/// Puts the ship back at rest and off every processing list, so nothing fires
/// between the last assertion and the fixture teardown (which does sleep).
/datum/unit_test/voidcrew_flight/proc/flight_park(obj/structure/overmap/ship/ship)
	if(QDELETED(ship))
		return
	ship.disengage_autopilot(null, notify = FALSE)
	ship.cancel_zone_transition()
	ship.full_stop()
	// full_stop() clears the course and the burn; this is the belt on top, because a
	// ship left registered with SSfastprocess would burn again during the teardown's
	// own sleeps, on a hull whose turfs are being scraped back to space.
	ship.burn_direction = FLIGHT_BURN_NONE
	ship.thrust_processing = FALSE
	ship.update_ship_processing()
	if(ship.movement_callback_id)
		deltimer(ship.movement_callback_id)
		ship.movement_callback_id = null

/**
 * The body of one proc, as source text, from a pre-read file.
 *
 * A definition ends at the next line that starts at column 0 with a `/`, which is
 * how every proc and type block in this codebase begins.
 */
/datum/unit_test/voidcrew_flight/proc/flight_proc_body(source_text, header)
	var/start = findtextEx(source_text, header)
	if(!start)
		return null
	var/cursor = start + length(header)
	var/limit = length(source_text)
	while(cursor <= limit)
		var/newline = findtextEx(source_text, "\n", cursor)
		if(!newline)
			return copytext(source_text, start)
		if(copytext(source_text, newline + 1, newline + 2) == "/")
			return copytext(source_text, start, newline)
		cursor = newline + 1
	return copytext(source_text, start)

/// Source text with `/* ... */` blocks removed, so a commented-out branch is not
/// counted by the action census below.
/datum/unit_test/voidcrew_flight/proc/flight_strip_block_comments(source_text)
	var/list/kept = list()
	var/cursor = 1
	while(TRUE)
		var/opener = findtextEx(source_text, "/*", cursor)
		if(!opener)
			kept += copytext(source_text, cursor)
			break
		kept += copytext(source_text, cursor, opener)
		var/closer = findtextEx(source_text, "*/", opener + 2)
		if(!closer)
			break
		cursor = closer + 2
	return kept.Join("")

/// Source text with `//` line comments removed. The tick-path census below asserts on
/// tokens that must NOT appear in a proc body, and `tick_move()`'s own comment explains
/// the regression by naming `burn_direction` - so the comments have to go before that
/// can be a statement about the code.
/datum/unit_test/voidcrew_flight/proc/flight_strip_line_comments(source_text)
	var/list/kept = list()
	for(var/line in splittext(source_text, "\n"))
		var/comment_at = findtextEx(line, "//")
		kept += comment_at ? copytext(line, 1, comment_at) : line
	return kept.Join("\n")

/// Every string literal that immediately follows `opener`, deduplicated, appended to
/// `labels`. Used to read action names out of a `ui_act` body.
/datum/unit_test/voidcrew_flight/proc/flight_collect_labels(block_text, opener, list/labels)
	var/opener_length = length(opener)
	var/cursor = 1
	while(TRUE)
		var/found_at = findtextEx(block_text, opener, cursor)
		if(!found_at)
			break
		var/value_start = found_at + opener_length
		var/closer = findtextEx(block_text, "\"", value_start)
		if(!closer)
			break
		labels |= copytext(block_text, value_start, closer)
		cursor = closer + 1
	return labels

/**
 * Every action string a `ui_act` body answers.
 *
 * Two spellings, because the helm uses both: the `switch(action)` blocks are written
 * `if("change_heading")` and the ship-state blocks that hold a single action are
 * written `if(action == "undock")`. A census that knew only the first form would have
 * silently not counted the undock control at all - which is the same class of quiet
 * omission the census exists to catch.
 */
/datum/unit_test/voidcrew_flight/proc/flight_switch_labels(block_text)
	var/list/labels = list()
	flight_collect_labels(block_text, "if(\"", labels)
	flight_collect_labels(block_text, "action == \"", labels)
	return labels

// ===========================================================================
// 1. Flight dynamics: thrust, velocity, the tile step, and the rules that must
//    still apply once the engines go cold.
// ===========================================================================

/datum/unit_test/voidcrew_flight/dynamics
	priority = TEST_LONGER

/datum/unit_test/voidcrew_flight/dynamics/Run()
	// FLIGHT_TEST_HULL, not the fixture default - see the define. The default hull has no
	// open deck tile to bolt a thruster onto.
	var/obj/structure/overmap/ship/ship = vc_create_test_ship(FLIGHT_TEST_HULL)
	if(isnull(ship))
		return

	// Everything past this point runs through helper procs. TEST_ASSERT expands to
	// `return Fail(...)`, so an assertion in Run() itself would skip the teardown and
	// leak a hull holding a transit reservation and a ZTRAIT_STATION claim for the
	// rest of the suite (voidcrew_test_fixtures.dm:393-408). The helpers record their
	// own failures and hand control back here, and the teardown is unconditional.
	var/turf/home = get_turf(ship)
	var/obj/machinery/power/shuttle_engine/ship/thruster

	if(assert_flight_preconditions(ship))
		thruster = flight_mount_thruster(ship)
		if(thruster)
			assert_burn_moves_the_ship(ship)
			assert_helm_input_turns_the_ship(ship)
			assert_speed_is_capped(ship)
			assert_coasting_ship_steps_and_wraps(ship)
			assert_coasting_ship_still_crosses_zones(ship)
			assert_no_thrust_is_diagnosed(ship)
			assert_autopilot_flies_and_arrives(ship)

	flight_park(ship)
	if(thruster && !QDELETED(thruster))
		qdel(thruster)
	if(home && !QDELETED(ship))
		ship.forceMove(home)
	vc_release_test_ship(ship)

/// The state a freshly purchased hull is handed to its crew in. Every assertion in
/// this file is written against these, so they are checked rather than assumed - and
/// the hardcoded coordinate band is validated against the wrap helpers, which embed
/// the real `OVERMAP_PATH_*` values, exactly as voidcrew_autopilot_course.dm does.
/datum/unit_test/voidcrew_flight/dynamics/proc/assert_flight_preconditions(obj/structure/overmap/ship/ship)
	TEST_ASSERT_EQUAL(overmap_wrap_x(FLIGHT_WRAP_LOW_X - 1), FLIGHT_WRAP_HIGH_X, "the hardcoded overmap band is stale: update FLIGHT_WRAP_LOW_X/HIGH_X to the current OVERMAP_PATH_* values")
	TEST_ASSERT_EQUAL(overmap_wrap_x(FLIGHT_WRAP_HIGH_X + 1), FLIGHT_WRAP_LOW_X, "the hardcoded overmap band is stale: update FLIGHT_WRAP_LOW_X/HIGH_X to the current OVERMAP_PATH_* values")

	// The columns the band literals name must actually be the closed edge and the last
	// flyable tile, or the wraparound assertion below is aimed at the wrong pair.
	TEST_ASSERT(istype(locate(FLIGHT_RIGHT_EDGE, world.maxy - 25, FLIGHT_OVERMAP_Z), /turf/closed/overmap_edge), "column [FLIGHT_RIGHT_EDGE] is not the overmap's closed east edge; OVERMAP_SIZE changed and this file's band literals are stale")
	TEST_ASSERT(istype(locate(FLIGHT_WRAP_HIGH_X, world.maxy - 25, FLIGHT_OVERMAP_Z), /turf/open/overmap), "column [FLIGHT_WRAP_HIGH_X] is not flyable ground; OVERMAP_SIZE changed and this file's band literals are stale")

	var/turf/token_turf = get_turf(ship)
	TEST_ASSERT(istype(token_turf, /turf/open/overmap), "the fixture ship's overmap token is standing on [token_turf?.type || "nothing"], not flyable overmap ground - create_ship() places it with get_unused_overmap_square_in_green_zone()")
	TEST_ASSERT_EQUAL(token_turf.z, FLIGHT_OVERMAP_Z, "the overmap is not on z [FLIGHT_OVERMAP_Z] any more; OVERMAP_Z_LEVEL moved and this file's literal is stale")
	TEST_ASSERT_EQUAL(ship.state, FLIGHT_STATE_FLYING, "a freshly built hull is in state '[ship.state]', not '[FLIGHT_STATE_FLYING]' - burn_engines() (ship.dm:4315) and command_course() both refuse outright in any other state, so nothing below would be testing flight")
	TEST_ASSERT(ship.is_still(), "a freshly built hull already has velocity ([ship.speed[1]], [ship.speed[2]])")
	TEST_ASSERT_EQUAL(ship.burn_direction, FLIGHT_BURN_NONE, "a freshly built hull is already burning")
	TEST_ASSERT(!ship.autopilot_engaged, "a freshly built hull is already flying a course")
	TEST_ASSERT(!ship.zone_transitioning, "a freshly built hull is already mid zone crossing")
	TEST_ASSERT(!ship.is_interdicted, "the fixture hull is interdicted, which throttles every timing assertion below")
	TEST_ASSERT(ship.mass > 0, "the fixture hull has no mass, and burn_engines() divides thrust by it (ship.dm:4368) - create_ship() calls calculate_mass()")
	TEST_ASSERT_NOTNULL(SSovermap_zones, "SSovermap_zones does not exist, so zone_crossing() (ship.dm:3213) can never return a crossing and the coasting-zone assertion below would pass vacuously")
	TEST_ASSERT(SSovermap_zones.initialized, "SSovermap_zones never initialised; zone_crossing() bails at ship.dm:3213 and the zone rule cannot be tested")
	return TRUE

/**
 * A burn produces velocity; no burn produces none.
 *
 * The whole integration in one line each way. `command_course()` is the fly-by-wire
 * entry every manual control routes through (ship.dm:4422), `process()` is the
 * thrust tick, and the two together are what a crew holding a direction key does.
 * The negative half matters as much as the positive: there is no drag anywhere in
 * this codebase (`newtonian_move()` is overridden to a bare return, ship.dm:973),
 * so a coasting ship must hold its velocity exactly, and a ship that bleeds speed
 * while coasting would make every arrival calculation on the helm wrong.
 */
/datum/unit_test/voidcrew_flight/dynamics/proc/assert_burn_moves_the_ship(obj/structure/overmap/ship/ship)
	// Neutral ground first: burn_engines() answers an eastward step that crosses a zone
	// line by starting a transition and returning before it looks at any engine
	// (ship.dm:4339-4345), and create_ship() drops a new hull anywhere in the green ring -
	// including its inner edge, one tile from yellow. See flight_park_on_neutral_ground().
	flight_park_on_neutral_ground(ship)
	ship.full_stop()
	TEST_ASSERT(ship.can_thrust(), "the hull cannot thrust with a void thruster bolted to its deck. can_thrust() (ship.dm:4138) wants an engine in shuttle.engine_list that is enabled, thruster_active, and either fuelled or capless.")

	ship.command_course(EAST)
	TEST_ASSERT_EQUAL(ship.commanded_course, EAST, "command_course(EAST) did not take: commanded_course is [ship.commanded_course]. The helm's compass rose lights from this var and the cruise governor reads it.")
	TEST_ASSERT_EQUAL(ship.burn_direction, EAST, "commanding a course from rest did not light the engines: burn_direction is [ship.burn_direction]")
	TEST_ASSERT(ship.thrust_processing, "commanding a course did not put the ship on the thrust tick, so process() would never burn (update_ship_processing(), ship.dm:561)")

	ship.process(1)
	TEST_ASSERT(ship.speed[1] > 0, "a full burn east produced no eastward velocity (speed is [ship.speed[1] || 0], [ship.speed[2] || 0]). burn_engines() sums shuttle.engine_list, divides by mass*100 and hands the result to accelerate() (ship.dm:4357-4374).")
	TEST_ASSERT_EQUAL(ship.speed[2] || 0, 0, "a burn due east moved the ship on the north/south axis as well ([ship.speed[2]])")
	TEST_ASSERT_EQUAL(ship.get_heading(), EAST, "the ship's heading reads [dir2text(ship.get_heading()) || "nothing"] after an eastward burn; get_heading() is derived from the signs of speed\[1..2\] and is what the helm displays")
	TEST_ASSERT(ship.est_thrust > 0, "est_thrust is [ship.est_thrust || 0] after a successful burn - the helm's thrust gauge would read zero on a ship that is accelerating")

	// Engines cold: the velocity must not change at all, in either direction.
	ship.change_heading(FLIGHT_BURN_NONE)
	TEST_ASSERT_EQUAL(ship.burn_direction, FLIGHT_BURN_NONE, "change_heading(BURN_NONE) did not cut the burn")
	var/coast_x = ship.speed[1]
	var/coast_y = ship.speed[2] || 0
	ship.process(1)
	ship.process(1)
	TEST_ASSERT_EQUAL(ship.speed[1], coast_x, "a coasting ship's eastward velocity changed from [coast_x] to [ship.speed[1]] across two thrust ticks with the engines cold. process() must not burn while burn_direction is BURN_NONE (ship.dm:620), and nothing in this codebase applies drag.")
	TEST_ASSERT_EQUAL(ship.speed[2] || 0, coast_y, "a coasting ship gained north/south velocity ([ship.speed[2]]) with the engines cold")

	ship.full_stop()
	TEST_ASSERT(ship.is_still(), "full_stop() left the ship moving at ([ship.speed[1]], [ship.speed[2]])")
	TEST_ASSERT_EQUAL(ship.commanded_course, FLIGHT_BURN_NONE, "full_stop() left a course commanded, so the helm's rose stays lit on a stationary ship")
	return TRUE

/**
 * A commanded turn kills the drift it no longer wants and burns up the axis it does.
 *
 * `tick_move()` steps by the SIGN of each axis and nothing else (ship.dm:3010-3011),
 * so turning is not a matter of shedding speed - it is a matter of getting two signs
 * right. `command_course()` and `autopilot_steer()` deliberately share
 * `autopilot_aim_drift()` for this so a hand-flown hull turns exactly as well as an
 * automated one; if the manual path ever stops killing the wrong-way axis, a ship
 * ordered north while moving east keeps going east until the burn overpowers it.
 */
/datum/unit_test/voidcrew_flight/dynamics/proc/assert_helm_input_turns_the_ship(obj/structure/overmap/ship/ship)
	flight_park_on_neutral_ground(ship) // see assert_burn_moves_the_ship()
	ship.full_stop()
	ship.command_course(EAST)
	ship.process(1)
	TEST_ASSERT(ship.speed[1] > 0, "the setup burn produced no eastward drift to turn out of")

	ship.command_course(NORTH)
	TEST_ASSERT_EQUAL(ship.commanded_course, NORTH, "the ship is still holding course [ship.commanded_course] after being commanded north")
	TEST_ASSERT_EQUAL(ship.speed[1] || 0, 0, "commanding north left [ship.speed[1]] of eastward drift on the ship. autopilot_aim_drift() (ship_autopilot.dm:733) must kill_drift() any axis carrying the ship the wrong way, or tick_move() keeps stepping east.")
	TEST_ASSERT(ship.burn_direction & NORTH, "commanding north did not light a northward burn (burn_direction is [ship.burn_direction])")

	ship.process(1)
	TEST_ASSERT(ship.speed[2] > 0, "a northward burn produced no northward velocity ([ship.speed[2] || 0])")
	TEST_ASSERT_EQUAL(ship.get_heading(), NORTH, "the ship's heading reads [dir2text(ship.get_heading()) || "nothing"] after turning north")

	ship.full_stop()
	return TRUE

/**
 * The velocity ceiling holds however long the engines are held open.
 *
 * `adjust_speed()` is the only sanctioned writer and rescales both axes when the
 * magnitude passes `max_speed` (ship.dm:2975-2979); the cruise governor cuts the
 * burn a hair under the throttle's target (`check_cruise()`, ship.dm:4463). Between
 * them a held key is supposed to reach cruise and stop burning. Without them a burn
 * integrates every 0.2s with nothing watching it, which is how a light hull used to
 * sail to several times max_speed - and `max_speed` is a `var/static/`, so it is
 * read, never written, here.
 */
/datum/unit_test/voidcrew_flight/dynamics/proc/assert_speed_is_capped(obj/structure/overmap/ship/ship)
	flight_park_on_neutral_ground(ship) // see assert_burn_moves_the_ship()
	ship.full_stop()

	// The ceiling itself, asserted on a single write rather than on a burn. A burn is the
	// wrong instrument for it: check_cruise() trims the magnitude back to the throttle
	// target on the same tick, so a hull with no ceiling at all still reads capped one
	// line later. Only a direct over-cap write shows whether adjust_speed() has one.
	ship.adjust_speed(ship.max_speed * 5, 0)
	var/after_overcap = flight_magnitude(ship)
	TEST_ASSERT(after_overcap <= ship.max_speed + 0.000001, "a single velocity write of five times max_speed left the ship at [after_overcap], past the [ship.max_speed] ceiling. \
		adjust_speed() (ship.dm:2975-2979) is the only bound on the velocity - the burn loop integrates every 0.2s with nothing else watching - and it rescales both axes so the heading survives the trim.")
	TEST_ASSERT(ship.speed[1] > 0, "the over-cap write was rescaled to a standstill; the clamp scales the vector, it does not zero it")
	TEST_ASSERT_EQUAL(ship.speed[2] || 0, 0, "an over-cap write on the x axis put velocity on the y axis; the clamp scales both axes by the same factor and cannot change a sign")

	ship.full_stop()
	TEST_ASSERT_EQUAL(ship.burn_percentage, 100, "the throttle is at [ship.burn_percentage]%, so the cruise ceiling below is not max_speed")
	ship.command_course(EAST)
	// Bounded rather than fixed: how many ticks a hull needs to reach cruise is
	// thrust/mass, and the ceiling has to hold on every one of them, not just the last.
	var/ticks_burned = 0
	var/magnitude = 0
	for(var/tick in 1 to 200)
		ship.process(1)
		ticks_burned = tick
		magnitude = flight_magnitude(ship)
		if(magnitude > ship.max_speed + 0.000001)
			TEST_FAIL("thrust tick [tick] at full throttle took the ship to [magnitude], past the [ship.max_speed] ceiling. adjust_speed() rescales both axes whenever the magnitude passes max_speed (ship.dm:2975-2979); without it a burn integrates every 0.2s with nothing bounding it and a light hull sails to several times the cap.")
			break
		if(ship.burn_direction == FLIGHT_BURN_NONE)
			break
	TEST_ASSERT(magnitude > 0, "[ticks_burned] thrust ticks produced no velocity at all")
	TEST_ASSERT_EQUAL(ship.burn_direction, FLIGHT_BURN_NONE, "the engines are still burning after [ticks_burned] ticks at [magnitude] against a [ship.max_speed] ceiling. check_cruise() (ship.dm:4463) cuts the burn once every commanded axis is pointed right and the throttle target is met; a burn that never goes cold is the forever-burn that governor exists to end.")
	TEST_ASSERT_EQUAL(ship.commanded_course, EAST, "the cruise cut-out dropped the commanded course as well as the burn - coasting at cruise IS the course, and the helm's rose lights from it")

	ship.full_stop()
	return TRUE

/**
 * A coasting ship steps one tile per tick by the sign of its velocity, and wraps at
 * the seam.
 *
 * Both are rules that live inside `tick_move()` and nowhere else. The wrap in
 * particular has no counterpart anywhere in the burn path - `handle_wraparound()`
 * (ship.dm:4283) is dead code whose only caller is a commented-out `Bump()`, and it
 * uses a different boundary - so if the wrap ever moves out of the tick path, a
 * coasting hull walks off the edge of the map onto a closed edge turf.
 *
 * The ship is genuinely coasting for all three steps: `burn_direction` is BURN_NONE
 * and `thrust_processing` is FALSE, so `process()` is not even registered, let alone
 * running. Velocity is set through `adjust_speed()`, which is a velocity write and
 * not a burn.
 */
/datum/unit_test/voidcrew_flight/dynamics/proc/assert_coasting_ship_steps_and_wraps(obj/structure/overmap/ship/ship)
	// Events only, and only the tiles actually flown over. Nothing else on the overmap
	// can affect a step: check_hazards() reads events on the entered tile and nothing
	// else, and the overmap has no collision, so the ~44 parked hulls are irrelevant here.
	var/list/dirty = flight_event_map(0)
	var/row = flight_find_seam_row(dirty)
	if(isnull(row))
		TEST_FAIL("no row of the overmap has both sides of the east/west seam free of hazard events, so the wraparound rule cannot be flown. \
			The overmap is [FLIGHT_WRAP_HIGH_X - FLIGHT_WRAP_LOW_X + 1] tiles across and only five of its tiles are needed on one row, all of them in the outer \
			ring, so this failing means overmap events now blanket the entire east/west seam.")
		return FALSE

	ship.full_stop()
	var/turf/start = flight_tile(FLIGHT_WRAP_HIGH_X - 2, row)
	ship.forceMove(start)
	TEST_ASSERT_EQUAL(ship.x, FLIGHT_WRAP_HIGH_X - 2, "the ship did not land on the lane tile it was placed on")

	// A velocity write, not a burn: this is a hull with cold engines and momentum.
	ship.adjust_speed(0.05, 0)
	TEST_ASSERT_EQUAL(ship.burn_direction, FLIGHT_BURN_NONE, "the test ship is burning, so the rules below would be reachable from burn_engines() and this would not be testing the coasting path")
	TEST_ASSERT(!ship.thrust_processing, "the test ship is still on the thrust tick, so it is not coasting")

	ship.tick_move()
	TEST_ASSERT_EQUAL(ship.x, FLIGHT_WRAP_HIGH_X - 1, "one tick of a coasting ship moving east did not advance it exactly one tile (x is [ship.x], expected [FLIGHT_WRAP_HIGH_X - 1]). tick_move() steps by sign(speed) and never by magnitude (ship.dm:3010).")
	TEST_ASSERT_EQUAL(ship.y, row, "a due-east step changed the ship's row to [ship.y]")

	ship.tick_move()
	TEST_ASSERT_EQUAL(ship.x, FLIGHT_WRAP_HIGH_X, "the second coasting step did not reach the last flyable column (x is [ship.x])")

	ship.tick_move()
	TEST_ASSERT_EQUAL(ship.x, FLIGHT_WRAP_LOW_X, "a COASTING ship flying east off column [FLIGHT_WRAP_HIGH_X] did not wrap to column [FLIGHT_WRAP_LOW_X]; it is at [ship.x]. \
		The wraparound is applied in tick_move() (ship.dm:3019-3022) and NOWHERE in the burn path, so a ship that reaches the seam with the engines cold - which is the ordinary \
		way to cross the map - depends on this and nothing else. handle_wraparound() is dead code and is not a substitute.")
	TEST_ASSERT_EQUAL(ship.y, row, "the wrap moved the ship off its row, to [ship.y]")
	TEST_ASSERT(ship.speed[1] > 0, "the wrap cost the ship its velocity ([ship.speed[1]]); wrapping is a step, not a stop")

	ship.full_stop()
	return TRUE

/**
 * # The documented one: a coasting ship still stops at a zone boundary.
 *
 * This is the bug class the whole file is named for, and the fork's own comment at
 * ship.dm:3031-3043 is the account of it: the boundary check used to live only in
 * `burn_engines()`, which "only runs while the engines are lit, and the ordinary way
 * to fly is to burn up to speed and then coast, at which point burn_direction is
 * BURN_NONE, process() stops calling burn_engines() at all, and nothing was left
 * watching where the ship went. Every coasting hull crossed zone lines for free, and
 * the autopilot did it every time."
 *
 * So the ship here is coasting on purpose - engines cold, off the thrust tick - and
 * the assertion is that the crossing is still caught, the ship is held on the near
 * side of the line, and the velocity and the movement timer are both taken off it.
 * Driving this with a burn instead would exercise `burn_engines()`'s early copy of
 * the same check (ship.dm:4339-4345) and prove nothing about the case that broke.
 */
/datum/unit_test/voidcrew_flight/dynamics/proc/assert_coasting_ship_still_crosses_zones(obj/structure/overmap/ship/ship)
	// No traffic exclusion: the step under test never completes, so there is nothing on
	// either tile that could be flown into. See flight_find_zone_boundary().
	var/list/boundary = flight_find_zone_boundary(list())
	if(isnull(boundary))
		TEST_FAIL("no west-to-east zone boundary was found anywhere on the overmap, so the zone rule cannot be flown. Zones are concentric rings by distance from the sun \
			(zone_controller.dm:101-122), so a map with only one zone type means the ring maths or SSovermap_zones' assignment has changed.")
		return FALSE

	var/turf/near_side = boundary[1]
	var/turf/far_side = boundary[2]
	var/near_zone = flight_zone_type(near_side)
	var/far_zone = flight_zone_type(far_side)

	ship.full_stop()
	ship.forceMove(near_side)
	ship.adjust_speed(0.05, 0)
	TEST_ASSERT_EQUAL(ship.burn_direction, FLIGHT_BURN_NONE, "the ship is burning; burn_engines()'s own boundary check would fire first and this would not be testing tick_move()'s")
	TEST_ASSERT(!ship.thrust_processing, "the ship is on the thrust tick, so it is not coasting")
	TEST_ASSERT(!ship.zone_transitioning, "the ship is already mid-crossing before the step under test")

	ship.tick_move()

	TEST_ASSERT(ship.zone_transitioning, "a COASTING ship stepped from zone [near_zone] at ([near_side.x], [near_side.y]) into zone [far_zone] at ([far_side.x], [far_side.y]) without starting a zone transition. \
		This is the exact regression ship.dm:3031-3043 documents: with the engines cold nothing else in the game is watching where the ship goes, so a boundary check that is not inside \
		tick_move() lets every coasting hull - and every autopilot cruise, which deliberately coasts - cross zone lines for free.")
	TEST_ASSERT_EQUAL(ship.x, near_side.x, "the ship crossed the line anyway: it is at ([ship.x], [ship.y]), not held at ([near_side.x], [near_side.y]). start_zone_transition() must stop the ship on the near side.")
	TEST_ASSERT_EQUAL(ship.zone_transition_target, far_side, "the transition is aimed at [ship.zone_transition_target || "nothing"] rather than the tile the ship was stepping onto")
	TEST_ASSERT(ship.is_still(), "the crossing did not cut the ship's velocity ([ship.speed[1]], [ship.speed[2]]); start_zone_transition() calls decelerate(max_speed) at ship.dm:3253")
	TEST_ASSERT_NULL(ship.movement_callback_id, "the crossing left the movement timer armed, so the ship keeps stepping through the boundary it is supposed to be waiting at")
	TEST_ASSERT_EQUAL(ship.burn_direction, FLIGHT_BURN_NONE, "the crossing did not clear the burn direction")

	// The latch is what hands the course back on the far side; a coasting hull has no
	// commanded course, so what it resumes is the heading its velocity was carrying.
	TEST_ASSERT_EQUAL(ship.zone_resume_burn, EAST, "a coasting ship's crossing latched [ship.zone_resume_burn] to resume with, not the eastward heading it was carrying. \
		Without the latch a hand-flown hull comes out the far side dead in space (ship.dm:3240-3247).")

	ship.cancel_zone_transition()
	TEST_ASSERT(!ship.zone_transitioning, "cancel_zone_transition() did not clear the crossing, so the ship is frozen at the boundary for the rest of the run")
	TEST_ASSERT_NULL(ship.zone_transition_timer, "cancel_zone_transition() left the 10 second completion timer armed; it would fire on a released fixture ship")

	// Off the line before the next phase inherits the ship. See
	// flight_park_on_neutral_ground() - leaving it here makes the next eastward burn start
	// a crossing rather than produce thrust.
	flight_park_on_neutral_ground(ship)
	return TRUE

/**
 * No thrust is reported, never silently absorbed.
 *
 * Two halves of the fork's documented diagnosis contract (`warn_no_thrust()`,
 * ship.dm:4376-4386): "an ion engine's helm gauge reads stored SMES charge, but
 * burns draw live wire power, so the display can sit at 100% while the ship refuses
 * to move."
 *
 *  1. **A burn that produces nothing moves nothing and says so.** With every engine
 *     switched off, `burn_engines()` must bail at its `thrust_used <= 0` gate
 *     (ship.dm:4364) rather than dividing by mass and accelerating by zero, `est_thrust`
 *     must fall to zero so the helm's gauge stops lying, and `engine_diagnostic_report()`
 *     - which the helm's Refresh Engines button reads back to the crew - must name
 *     each dead thruster and why.
 *  2. **A dead wire reads as an empty tank.** The one line that reconciles the gauge
 *     with the burn is `electric.dm:61-62`: `return_fuel()` returns 0 whenever
 *     `avail()` and `newavail()` are both zero, whatever the SMES holds. An ion
 *     thruster with no cable under it is the cheapest deterministic case of that -
 *     no powernet at all - and it must report zero fuel and a refusal reason naming
 *     the cabling, rather than a healthy gauge on an engine that cannot move the ship.
 */
/datum/unit_test/voidcrew_flight/dynamics/proc/assert_no_thrust_is_diagnosed(obj/structure/overmap/ship/ship)
	// This phase burns, so it needs ground whose eastward step is not a zone crossing:
	// burn_engines() answers a boundary by starting a transition and returning, well before
	// it looks at a single engine (ship.dm:4339-4345), which would make every assertion
	// below pass for the wrong reason.
	flight_park_on_neutral_ground(ship)
	TEST_ASSERT(!ship.zone_transitioning, "the ship is mid zone-crossing at the start of this phase, so burn_engines() returns at its crossing gate and the no-thrust assertions below would all pass vacuously")
	ship.full_stop()

	var/list/was_enabled = list()
	for(var/obj/machinery/power/shuttle_engine/ship/engine as anything in ship.shuttle.engine_list)
		was_enabled[engine] = engine.enabled
		engine.enabled = FALSE
	ship.refresh_engines()

	TEST_ASSERT(!ship.can_thrust(), "a hull with every engine switched off still reports it can thrust")
	ship.burn_engines(EAST, 100, 1)
	TEST_ASSERT(ship.is_still(), "a burn with every engine switched off still accelerated the ship to ([ship.speed[1]], [ship.speed[2]]). burn_engines() returns at its thrust_used <= 0 gate (ship.dm:4364) before accelerate().")
	TEST_ASSERT_EQUAL(ship.est_thrust, 0, "est_thrust reads [ship.est_thrust] with every engine off - the helm's thrust gauge would show a healthy number on a ship that cannot move")

	var/list/report = ship.engine_diagnostic_report()
	TEST_ASSERT(length(report) > 0, "engine_diagnostic_report() said nothing about a hull whose every thruster is switched off. This report is the entire content of the helm's Refresh Engines readback (_helm.dm:875-891); silence here is the fifteen-minute cable-and-SMES mystery it was written to end.")
	var/named_switched_off = FALSE
	for(var/line in report)
		if(findtext(line, "switched off"))
			named_switched_off = TRUE
			break
	TEST_ASSERT(named_switched_off, "the engine diagnostic named no switched-off thruster. Lines were: [report.Join(" | ")]")

	for(var/obj/machinery/power/shuttle_engine/ship/engine as anything in was_enabled)
		if(!QDELETED(engine))
			engine.enabled = was_enabled[engine]
	ship.refresh_engines()
	TEST_ASSERT(ship.can_thrust(), "switching the engines back on did not restore thrust, so the restore below the assertions is not putting the hull back as it was found")

	// --- the ion gauge, which is the trap the fork documents ---
	var/obj/machinery/power/shuttle_engine/ship/electric/ion = flight_mount_thruster(ship, /obj/machinery/power/shuttle_engine/ship/electric)
	if(isnull(ion))
		return FALSE

	// The dead grid is constructed deliberately: an ion thruster bolted onto a random
	// deck tile may land on live cable (its on_construction() calls connect_to_network()),
	// and which tile the fixture hands out is not the thing under test. What IS under test
	// is what the ship and the helm say once the wire is dead, so the wire is made dead
	// through the production proc and the assertions are all on the consequences.
	ion.disconnect_from_network()
	ion.update_engine()
	TEST_ASSERT_NULL(ion.powernet, "disconnect_from_network() left the test ion thruster on a powernet, so the dead-wire case below is not what is being measured")
	TEST_ASSERT(!ion.thruster_active, "an ion thruster with no cable under it reports thruster_active; update_engine() sets it from !!powernet (electric.dm:23)")
	TEST_ASSERT_EQUAL(ion.return_fuel(), 0, "an ion thruster on a dead grid reports [ion.return_fuel()] fuel. return_fuel() must answer 0 whenever avail() and newavail() are both zero (electric.dm:61-62) - that single line is what stops a full SMES with its output off from reading 100% on the helm while the engine produces nothing.")
	TEST_ASSERT_EQUAL(ion.burn_engine(100, ship.mass, 1), 0, "an ion thruster with no live wire under it returned thrust from burn_engine(); burns draw max(avail(), newavail()) (electric.dm:52), never stored charge")

	var/refusal = ion.thrust_refusal_reason()
	TEST_ASSERT_NOTNULL(refusal, "an unpowered ion thruster gave no thrust_refusal_reason(), so the helm has nothing to tell the crew")
	TEST_ASSERT(findtext(refusal, "cable"), "an unpowered ion thruster's refusal does not mention the cabling: \"[refusal]\"")

	var/list/ion_report = ship.engine_diagnostic_report()
	var/named_the_ion = FALSE
	for(var/line in ion_report)
		if(findtext(line, ion.name) && findtext(line, "cable"))
			named_the_ion = TRUE
			break
	TEST_ASSERT(named_the_ion, "the helm's engine diagnostic did not name the unpowered ion thruster and its missing cable. Lines were: [ion_report.Join(" | ")]")

	qdel(ion)
	ship.refresh_engines()
	ship.full_stop()
	return TRUE

/**
 * The autopilot flies a course, not just plans one.
 *
 * `voidcrew_autopilot_course.dm` proves `plan_overmap_course()` draws the right line
 * with a null pilot and no ship. Nothing proved the ship then follows it. The three
 * things asserted here are the three the planner cannot give you: that engaging
 * points the engines at the destination, that each tile crossed re-steers toward it
 * (`tick_move()` calls `autopilot_steer()` on every crossing, ship.dm:3060), and that
 * standing on the destination ends the course and stops the ship rather than flying
 * through it.
 *
 * Three tiles, down a lane proven clean against the ship's OWN danger map, because
 * `autopilot_steer()` brakes on it (`autopilot_imminent_hazard()`, ship_autopilot.dm:971)
 * and re-plans around it, and a flight that stopped for a storm or bent around a halo
 * band would report as a steering failure. See flight_find_autopilot_lane().
 */
/datum/unit_test/voidcrew_flight/dynamics/proc/assert_autopilot_flies_and_arrives(obj/structure/overmap/ship/ship)
	// Verified against the ship's own danger map, not against a proxy - see
	// flight_find_autopilot_lane(). It leaves the ship standing on the lane's start tile.
	var/list/lane = flight_find_autopilot_lane(ship, 4)
	if(isnull(lane))
		return FALSE

	var/start_x = lane[1]
	var/row = lane[2]
	var/dest_x = start_x + 3

	ship.full_stop()
	ship.forceMove(flight_tile(start_x, row))
	TEST_ASSERT(ship.can_thrust(), "the hull cannot thrust, and engage_autopilot() refuses outright without it (ship_autopilot.dm:564)")
	TEST_ASSERT(!ship.zone_transitioning, "the ship is mid zone-crossing on entry to the autopilot phase. engage_autopilot() does not check that (ship_autopilot.dm:558-565) but autopilot_steer() \
		returns on it immediately (:764), so the course would engage, plot, and never light an engine - an earlier phase leaving the hull on a zone line is the way this happens.")

	// The two preconditions that decide which branch of autopilot_steer() answers, pinned
	// separately so a failure below names the reason rather than the symptom. A ship that
	// is already moving can be served by its own drift (:872) and a ship whose engines are
	// already lit would prove nothing by having them lit afterwards.
	TEST_ASSERT(ship.is_still(), "the ship is already moving at ([ship.speed[1] || 0], [ship.speed[2] || 0]) before the course is engaged, so the autopilot's already-at-cruise branch could answer instead of the burn")
	TEST_ASSERT_EQUAL(ship.burn_direction, FLIGHT_BURN_NONE, "the engines are already lit before the course is engaged")

	var/result = ship.engage_autopilot(dest_x, row, "flight test", null)
	TEST_ASSERT(!findtext(result, "ERROR"), "engage_autopilot() refused a three-tile course down a clear lane: \"[result]\"")
	TEST_ASSERT(ship.autopilot_engaged, "engage_autopilot() returned \"[result]\" without engaging")
	TEST_ASSERT_EQUAL(length(ship.autopilot_path), 3, "a three-tile hop was planned as [length(ship.autopilot_path)] steps")
	TEST_ASSERT_EQUAL(ship.commanded_course, FLIGHT_BURN_NONE, "engaging the autopilot left a manually commanded course standing; the autopilot owns the ship and the helm's rose has to stand down with the rest of manual control (ship_autopilot.dm:591)")

	// The plotted course must start on the tile next door. autopilot_steer() returns
	// without touching an engine when the step to the first node resolves to nothing
	// (ship_autopilot.dm:845-847), and that return is indistinguishable from a dead
	// autopilot, so the step is resolved here rather than inferred.
	var/list/first_node = ship.autopilot_path[1]
	var/node_step = ship.autopilot_step_dir(first_node[1], first_node[2])
	TEST_ASSERT_EQUAL(node_step, EAST, "the first node of the plotted course is ([first_node[1]], [first_node[2]]) with the ship at ([ship.x], [ship.y]): a step of [node_step], not due east. \
		plan_overmap_course() returns the tiles to fly THROUGH, the start tile excluded (voidcrew_autopilot_course.dm pins a 10-tile hop at 10 nodes ending on the destination), so a first node \
		that is not adjacent means the planner and the steerer disagree about where a course begins.")

	// engage_autopilot() steers in-call (ship_autopilot.dm:596). For a ship that is STILL,
	// with an adjacent next node and a clean danger map, that steer has exactly one legal
	// outcome: autopilot_aim_drift() reports the axis the drift does not serve, and the
	// engines light. Recorded with TEST_FAIL rather than asserted with TEST_ASSERT, which
	// would return from here: the flight below is driven either way, so one run reports
	// BOTH answers - whether engaging lights the burn, and whether the course flies at all
	// once something steers it. A test that stopped at the first symptom would need a
	// round trip to learn the second, and the second is the one the crew cares about.
	var/list/danger_now = ship.build_autopilot_danger_map()
	var/danger_ahead = danger_now["[start_x + 1],[row]"]
	if(!(ship.burn_direction & EAST))
		TEST_FAIL("engage_autopilot() plotted a [length(ship.autopilot_path)]-node course and returned with the engines cold (burn_direction [ship.burn_direction]). \
			State autopilot_steer() read: ship at ([ship.x], [ship.y]), first node ([first_node[1]], [first_node[2]]) = step [node_step], destination ([ship.autopilot_dest_x], [ship.autopilot_dest_y]), \
			still [ship.is_still() ? "yes" : "no"], speed ([ship.speed[1] || 0], [ship.speed[2] || 0]), cruise ceiling [ship.autopilot_cruise_speed()], danger on the tile ahead [danger_ahead || 0], \
			can_thrust [ship.can_thrust() ? "yes" : "no"], zone_transitioning [ship.zone_transitioning ? "yes" : "no"], status \"[ship.autopilot_status || "none"]\". \
			autopilot_steer() has exactly three returns that touch no engine: an unresolvable step (:845), an imminent hazard (:809 - itself gated behind is_still(), so it cannot fire on a stopped \
			ship), and a drift already at or above cruise (:872 - unreachable while aim_drift() still reports a missing axis). None of the three can hold for the state printed above, so if this \
			fires, a course that is planned and never burned is a DEAD AUTOPILOT and the defect is in the steer, not in this test.")

	for(var/step in 1 to 3)
		var/expected_x = start_x + step
		// The poll timer (schedule_autopilot_poll, 0.2s while burning) is what re-steers in
		// production. Driven by hand here, because a test that waits on a timer is not
		// deterministic - and because it makes the flight below a test of the course being
		// FLOWN rather than of the in-call steer having primed it, which is pinned separately
		// above. tick_move() steers again at the end of every crossing, so from the second
		// tile on this is the same call the game makes anyway.
		ship.autopilot_steer()
		ship.process(1) // one thrust tick: the burn the steer just ordered
		TEST_ASSERT(ship.speed[1] > 0, "the autopilot has no eastward velocity to cross tile [step] with (speed [ship.speed[1] || 0], [ship.speed[2] || 0], burn_direction [ship.burn_direction]). \
			A steer and a thrust tick have both been driven, so this is the whole contract failing rather than a timing artefact: a course the autopilot plots, holds and never burns for is one the ship never flies.")
		TEST_ASSERT_EQUAL(ship.speed[2] || 0, 0, "the autopilot picked up north/south drift ([ship.speed[2]]) on a due-east course, which would walk it off the lane")
		ship.tick_move() // one tile crossed, and one steering decision at the end of it
		TEST_ASSERT_EQUAL(ship.x, expected_x, "tile [step] of the autopilot course left the ship at x [ship.x], expected [expected_x]")
		TEST_ASSERT_EQUAL(ship.y, row, "the autopilot course left its row on tile [step] (y is [ship.y])")
		if(step < 3)
			TEST_ASSERT(ship.autopilot_engaged, "the autopilot disengaged part way down a clear lane, on tile [step]. Status: \"[ship.autopilot_status || "none"]\".")

	TEST_ASSERT(!ship.autopilot_engaged, "the ship reached its destination tile and the autopilot is still engaged; the arrival test is x == autopilot_dest_x && y == autopilot_dest_y (ship_autopilot.dm:769)")
	TEST_ASSERT_EQUAL(ship.autopilot_status, "arrived", "an autopilot that flew its course to the destination reports status \"[ship.autopilot_status || "none"]\"")
	TEST_ASSERT(ship.is_still(), "arriving did not stop the ship ([ship.speed[1]], [ship.speed[2]]); complete_autopilot() calls full_stop() (ship_autopilot.dm:661) because arriving is the one case where stopping is the whole point")
	TEST_ASSERT_NULL(ship.autopilot_path, "the flown course was not cleared on arrival")

	// And the cancel path, which is a different proc: it stands the course down and
	// deliberately leaves the ship coasting, so the crew inherits a ship that is still
	// going somewhere (ship_autopilot.dm:615-621).
	ship.full_stop()
	ship.forceMove(flight_tile(start_x, row))
	result = ship.engage_autopilot(dest_x, row, "flight test cancel", null)
	TEST_ASSERT(ship.autopilot_engaged, "the second engage refused: \"[result]\"")
	ship.process(1)
	var/coasting_at = ship.speed[1]
	TEST_ASSERT(coasting_at > 0, "the second course produced no velocity to be left coasting with")
	ship.disengage_autopilot("unit test stand-down")
	TEST_ASSERT(!ship.autopilot_engaged, "disengage_autopilot() did not stand the course down")
	TEST_ASSERT_NULL(ship.autopilot_path, "disengage_autopilot() left the plotted course on the ship")
	TEST_ASSERT_NULL(ship.autopilot_poll_timer, "disengage_autopilot() left the poll timer armed; it would re-steer a ship nobody is flying")
	TEST_ASSERT_EQUAL(ship.burn_direction, FLIGHT_BURN_NONE, "disengage_autopilot() left the engines burning")
	TEST_ASSERT_EQUAL(ship.speed[1], coasting_at, "disengage_autopilot() braked the ship (velocity went from [coasting_at] to [ship.speed[1]]). It leaves the hull coasting on purpose - an autopilot that slams the brakes the moment it hands back control hands back a stationary target.")

	ship.full_stop()
	return TRUE

// ===========================================================================
// 2. The helm: the console every one of those systems is driven from.
// ===========================================================================

/datum/unit_test/voidcrew_flight/helm_surface
	priority = TEST_LONGER

/datum/unit_test/voidcrew_flight/helm_surface/Run()
	// FLIGHT_TEST_HULL, not the fixture default - see the define. The default hull has no
	// open deck for a crewman to stand on at a console, let alone a spare tile for a thruster.
	var/obj/structure/overmap/ship/ship = vc_create_test_ship(FLIGHT_TEST_HULL)
	if(isnull(ship))
		return

	var/turf/home = get_turf(ship)
	var/obj/machinery/power/shuttle_engine/ship/thruster
	var/mob/living/carbon/human/consistent/crewman
	var/mob/living/carbon/human/consistent/outsider
	var/datum/tgui/window

	var/obj/machinery/computer/helm/console = find_linked_helm(ship)
	if(console)
		thruster = flight_mount_thruster(ship)
		crewman = allocate(/mob/living/carbon/human/consistent)
		outsider = allocate(/mob/living/carbon/human/consistent)
		crewman.mind_initialize()
		outsider.mind_initialize()

		assert_action_census()
		assert_crew_gate(ship, console, crewman, outsider)

		if(thruster)
			window = vc_open_test_ui(crewman, console)
			if(window)
				assert_heading_actions(ship, console, crewman, window)
				assert_throttle_and_brake(ship, console, crewman, window)
				assert_engine_actions(ship, console, crewman, window)
				assert_policy_toggles(ship, console, crewman, window)
				assert_autopilot_actions(ship, console, crewman, window)

	// Teardown, unconditional. The mobs come off the hull first: vc_release_test_ship()
	// sweeps and deletes every living mob standing on a hull turf, and vc_open_test_ui()
	// walks the user onto the console's tile.
	if(window)
		vc_close_test_ui(crewman, window)
	if(crewman && !QDELETED(crewman))
		if(crewman.mind && ship.ship_team)
			ship.ship_team.remove_member(crewman.mind)
		crewman.forceMove(run_loc_floor_bottom_left)
	if(outsider && !QDELETED(outsider))
		outsider.forceMove(run_loc_floor_bottom_left)
	flight_park(ship)
	if(thruster && !QDELETED(thruster))
		qdel(thruster)
	if(home && !QDELETED(ship))
		ship.forceMove(home)
	vc_release_test_ship(ship)

/**
 * The hull's own mapped helm, linked to it.
 *
 * The link is deliberately resolved here rather than assumed, because on a freshly
 * built hull it does not exist yet: `create_ship()` assigns `port.current_ship` only
 * **after** `action_load()` returns (shuttle.dm:155), so both of the console's
 * automatic hooks - `connect_to_shuttle()` during `linkup()` and
 * `attempt_ship_connection()` from `LateInitialize()` - run while the port still has
 * no ship and link to nothing. What closes the gap in play is the console's own
 * `ui_interact()`, which calls `attempt_ship_connection(last_resort = TRUE)` before
 * it will open (_helm.dm:244-247); the first crewman to touch the helm links it.
 *
 * So this calls the same proc, without the `last_resort` flag whose failure path is a
 * `stack_trace()`, and then asserts that a helm standing on a hull can in fact resolve
 * that hull - which is the thing worth pinning. A console that cannot is a bridge
 * nobody can fly the ship from.
 */
/datum/unit_test/voidcrew_flight/helm_surface/proc/find_linked_helm(obj/structure/overmap/ship/ship)
	var/obj/machinery/computer/helm/console
	for(var/turf/hull_turf as anything in ship.shuttle.return_turfs())
		if(!hull_turf)
			continue
		for(var/obj/machinery/computer/helm/candidate in hull_turf)
			if(QDELETED(candidate) || candidate.viewer)
				continue
			console = candidate
			break
		if(console)
			break

	if(isnull(console))
		TEST_FAIL("the hull built by the fixture ([ship.source_template?.name || ship.name]) maps no non-viewer helm console, so its flight controls cannot be driven at all. \
			If the default purchasable hull genuinely has no helm, this test needs an explicit hull_type - but a hull with no helm is a hull nobody can fly.")
		return null

	if(console.current_ship != ship)
		console.attempt_ship_connection()
	TEST_ASSERT_EQUAL(console.current_ship, ship, "a helm console standing on [ship.name]'s own deck could not resolve its ship (current_ship is [console.current_ship || "null"]). \
		attempt_ship_connection() resolves it through SSshuttle.get_containing_shuttle(src).current_ship (_helm.dm:718-729); a console that cannot is one that refuses to open (_helm.dm:244-247) \
		and stack_traces on the way past.")
	TEST_ASSERT(console in ship.helm_consoles, "the helm resolved its ship but was never registered in ship.helm_consoles, so the ship cannot push it a frame as it crosses a tile (set_current_ship(), _helm.dm:734-748)")
	return console

/**
 * Every action string the console answers is either driven here or listed with a
 * reason it is not.
 *
 * A census rather than a spot check, because the failure this guards is additive:
 * an action added to the switch, or renamed on one side of the DM/.tsx boundary, is
 * invisible to every test that only drives the actions it already knew about. The
 * scan reads the real `ui_act` body out of the source, so a new branch fails here
 * with its own name in the message.
 */
/datum/unit_test/voidcrew_flight/helm_surface/proc/assert_action_census()
	var/source = vc_test_file_text(FLIGHT_HELM_SOURCE)
	TEST_ASSERT_NOTNULL(source, "could not read [FLIGHT_HELM_SOURCE]; the helm moved and this census is scanning nothing")
	var/body = flight_proc_body(flight_strip_block_comments(source), "/obj/machinery/computer/helm/ui_act(")
	TEST_ASSERT_NOTNULL(body, "could not find /obj/machinery/computer/helm/ui_act() in [FLIGHT_HELM_SOURCE]")

	// Driven through vc_ui_act() somewhere in this file.
	var/static/list/covered = list(
		"change_heading",
		"set_course",
		"change_burn_percentage",
		"stop",
		"toggle_engine",
		"reload_engines",
		"autopilot_pref",
		"autopilot",
		"autopilot_cancel",
	)
	// Enumerated on purpose, with the reason. None of these is a gap that went
	// unnoticed; each is either owned by another test or undrivable in a test world.
	var/static/list/skipped = list(
		"rename_ship" = "gated on can_rename_ship(usr), which is the ship's command structure rather than the flight surface",
		"remove_waypoint" = "waypoint bookkeeping; voidcrew_fleet_waypoints.dm owns the waypoint register",
		"reveal_rumor" = "rumor charts belong to the shopkeep/chart feature, not flight",
		"reload_ship" = "re-resolves the console's own link; it writes current_ship directly and is a diagnostic, not a flight control",
		"typing_sound" = "plays a sound on a cooldown and mutates nothing else",
		"broadcast" = "ship-to-ship hailing; belongs with the comms feature",
		"claim_abandoned" = "ownership transfer of an abandoned hull, driven by the ship-lifecycle tests",
		"active_scan" = "sensors; sweeps and charts contacts, which is the sensor feature's surface",
		"act_overmap" = "docking/interaction handshake - voidcrew_docking_transit.dm owns dock cycles",
		"dock" = "same; the dock cycle and its berth contention are owned by voidcrew_docking_transit.dm",
		"undock" = "same, and it tgui_alert()s below 25% fuel, which returns null for a clientless mob",
		"bluespace_jump" = "opens a blocking tgui_alert() confirmation; a clientless test mob gets null back and the action always bails",
		"hide_in_nebula" = "nebula concealment needs a nebula event under the hull",
		"cancel_nebula_hide" = "as above",
		"unhide_from_nebula" = "as above",
	)

	var/list/found = flight_switch_labels(body)
	TEST_ASSERT(length(found) >= 20, "the helm ui_act scan found only [length(found)] action string\s ([found.Join(", ")]); the proc body extraction is reading the wrong region")

	var/list/unknown = list()
	for(var/action in found)
		if((action in covered) || (action in skipped))
			continue
		unknown += action
	TEST_ASSERT(!length(unknown), "the helm answers action(s) [unknown.Join(", ")] that this test neither drives nor lists as skipped. \
		Add it to `covered` with an assertion on the state it changes, or to `skipped` with the reason - an untested helm action is a control the crew can press that nothing checks.")

	var/list/missing = list()
	for(var/action in covered)
		if(!(action in found))
			missing += action
	for(var/action in skipped)
		if(!(action in found))
			missing += action
	TEST_ASSERT(!length(missing), "this test names helm action(s) [missing.Join(", ")] that the console no longer answers. Either they were renamed - in which case the .tsx and this file both need updating - or removed, in which case drop them from the census lists.")
	return TRUE

/**
 * The crew gate refuses a stranger and admits a crewmate, and it is the same gate
 * for every control on the console.
 *
 * `is_crew_member()` (_helm.dm:611-624) resolves membership through
 * `usr.mind in current_ship.ship_team.members` and sits above the whole switch
 * (_helm.dm:817), so it is the only server-side authorisation the flight controls
 * have. It is also the shape that breaks quietly: `if(!current_ship?.ship_team)
 * return TRUE` means a hull that ever loses its team lets the entire station fly it,
 * and nothing else would notice.
 */
/datum/unit_test/voidcrew_flight/helm_surface/proc/assert_crew_gate(obj/structure/overmap/ship/ship, obj/machinery/computer/helm/console, mob/living/carbon/human/crewman, mob/living/carbon/human/outsider)
	TEST_ASSERT_NOTNULL(ship.ship_team, "the fixture hull has no ship_team, so is_crew_member() returns TRUE for everyone (_helm.dm:620-621) and this gate cannot be tested. setup_from_template() builds one at ship.dm:675.")
	TEST_ASSERT(!ship.abandoned, "the fixture hull is flagged abandoned, which opens the console to anyone for claiming (_helm.dm:622-623)")
	TEST_ASSERT_NOTNULL(outsider.mind, "the outsider has no mind, so it would be refused for the wrong reason (a mindless mob fails at _helm.dm:618, before membership is ever read)")
	TEST_ASSERT(!(outsider.mind in ship.ship_team.members), "the outsider is already on the ship's roster")

	ship.full_stop()
	var/datum/tgui/outsider_window = vc_open_test_ui(outsider, console)
	if(isnull(outsider_window))
		return FALSE
	var/delivered = vc_ui_act(outsider, console, "change_heading", list("dir" = EAST), outsider_window)
	// Read the outcome into locals and hand the window back BEFORE asserting: TEST_ASSERT
	// returns from here, and a window left open leaves TRAIT_PRESERVE_UI_WITHOUT_CLIENT on
	// the mob. Same order the fixtures' own self-checks use, for the same reason.
	var/course_after = ship.commanded_course
	var/burn_after = ship.burn_direction
	vc_close_test_ui(outsider, outsider_window)
	if(!delivered)
		return FALSE
	TEST_ASSERT_EQUAL(course_after, FLIGHT_BURN_NONE, "a mob who is not on the ship's roster set the ship's course from the helm (commanded_course became [course_after]). \
		is_crew_member() is checked at _helm.dm:817, above the whole switch, and is the only thing standing between any passer-by and the flight controls.")
	TEST_ASSERT_EQUAL(burn_after, FLIGHT_BURN_NONE, "a non-crew heading command lit the engines")

	// The same action, from someone on the roster.
	ship.ship_team.add_member(crewman.mind)
	TEST_ASSERT(crewman.mind in ship.ship_team.members, "add_member() did not put the test crewman on the ship's roster")
	TEST_ASSERT(console.is_crew_member(crewman), "the console refuses a mob that is on its own ship's roster")
	return TRUE

/**
 * Heading actions: the direction pad, the keyboard course, the whitelist, and the
 * toggle-off behaviour the two do not share.
 *
 * `change_heading` toggles a re-pressed course back to a coast and takes any dir it
 * is handed; `set_course` never toggles - a held key holds the course - and only
 * accepts the nine values on its whitelist (_helm.dm:1003). Both take the ship off
 * autopilot silently first. Both also run the dir through `drunken_heading()`, which
 * is why the pilot's sobriety is asserted rather than assumed: a drunk pilot rolls a
 * different direction and this test would flake instead of failing.
 */
/datum/unit_test/voidcrew_flight/helm_surface/proc/assert_heading_actions(obj/structure/overmap/ship/ship, obj/machinery/computer/helm/console, mob/living/carbon/human/crewman, datum/tgui/window)
	TEST_ASSERT_EQUAL(crewman.get_drunk_amount(), 0, "the test pilot is drunk, and drunken_heading() (_helm.dm:778-799) rolls a random wrong direction above the threshold - every heading assertion below would be a coin toss")

	ship.full_stop()
	if(!vc_ui_act(crewman, console, "change_heading", list("dir" = EAST), window))
		return FALSE
	TEST_ASSERT_EQUAL(ship.commanded_course, EAST, "the helm's direction pad did not set an eastward course (commanded_course is [ship.commanded_course])")
	TEST_ASSERT_EQUAL(ship.burn_direction, EAST, "the helm's direction pad did not light the engines")

	// Pressing the course already held is how the pad releases to a coast.
	if(!vc_ui_act(crewman, console, "change_heading", list("dir" = EAST), window))
		return FALSE
	TEST_ASSERT_EQUAL(ship.commanded_course, FLIGHT_BURN_NONE, "pressing the held course again did not release it back to a coast (commanded_course is [ship.commanded_course])")

	// set_course is the keyboard path and does NOT toggle: a held key holds the course.
	if(!vc_ui_act(crewman, console, "set_course", list("dir" = NORTH), window))
		return FALSE
	TEST_ASSERT_EQUAL(ship.commanded_course, NORTH, "the keyboard course did not take (commanded_course is [ship.commanded_course])")
	if(!vc_ui_act(crewman, console, "set_course", list("dir" = NORTH), window))
		return FALSE
	TEST_ASSERT_EQUAL(ship.commanded_course, NORTH, "a repeated keyboard course toggled itself off; set_course is deliberately non-toggling so a held key holds the course (_helm.dm:998-1010)")

	// Off the whitelist: NORTH|SOUTH is not a direction anything can fly.
	if(!vc_ui_act(crewman, console, "set_course", list("dir" = NORTH|SOUTH), window))
		return FALSE
	TEST_ASSERT_EQUAL(ship.commanded_course, NORTH, "a course of [NORTH|SOUTH] got past the whitelist at _helm.dm:1003 and changed the ship's course to [ship.commanded_course]")

	ship.full_stop()
	return TRUE

/**
 * The throttle clamps and the brake toggles.
 *
 * `burn_percentage` is both the throttle and the cruise ceiling
 * (`cruise_target_speed()`, ship.dm:4401), so a value off the 1-100 range is a ship
 * that either cannot move or has no ceiling. The brake is the one control that must
 * work from every state: burning, cruising or coasting, the first press is BURN_STOP.
 */
/datum/unit_test/voidcrew_flight/helm_surface/proc/assert_throttle_and_brake(obj/structure/overmap/ship/ship, obj/machinery/computer/helm/console, mob/living/carbon/human/crewman, datum/tgui/window)
	ship.full_stop()
	if(!vc_ui_act(crewman, console, "change_burn_percentage", list("percentage" = 50), window))
		return FALSE
	TEST_ASSERT_EQUAL(ship.burn_percentage, 50, "the throttle did not move to 50% (it reads [ship.burn_percentage])")
	// Compared with a tolerance rather than for equality: cruise_target_speed() is
	// `max_speed * burn_percentage / 100` through single-precision floats.
	TEST_ASSERT(abs(ship.cruise_target_speed() - (ship.max_speed * 0.5)) < 0.000001, "at half throttle the cruise ceiling is [ship.cruise_target_speed()], not half of max_speed ([ship.max_speed * 0.5]) - the throttle doubles as the cruise target (ship.dm:4401)")

	if(!vc_ui_act(crewman, console, "change_burn_percentage", list("percentage" = 500), window))
		return FALSE
	TEST_ASSERT_EQUAL(ship.burn_percentage, 100, "a throttle of 500 was not clamped to 100 (it reads [ship.burn_percentage])")
	if(!vc_ui_act(crewman, console, "change_burn_percentage", list("percentage" = 0), window))
		return FALSE
	TEST_ASSERT_EQUAL(ship.burn_percentage, 1, "a throttle of 0 was not clamped up to 1 (it reads [ship.burn_percentage]); a zero throttle is a ship with no cruise target at all")

	if(!vc_ui_act(crewman, console, "change_burn_percentage", list("percentage" = 100), window))
		return FALSE
	TEST_ASSERT_EQUAL(ship.burn_percentage, 100, "the throttle would not go back to full")

	// The brake, from a coast: first press brakes, second releases.
	ship.full_stop()
	ship.adjust_speed(0.05, 0)
	if(!vc_ui_act(crewman, console, "stop", null, window))
		return FALSE
	TEST_ASSERT_EQUAL(ship.burn_direction, FLIGHT_BURN_STOP, "the brake did not engage on a coasting ship (burn_direction is [ship.burn_direction]). Brake always brakes: burning, cruising or coasting, the first press is BURN_STOP (_helm.dm:1068-1074).")
	if(!vc_ui_act(crewman, console, "stop", null, window))
		return FALSE
	TEST_ASSERT_EQUAL(ship.burn_direction, FLIGHT_BURN_NONE, "a second brake press did not release back to a coast (burn_direction is [ship.burn_direction])")

	ship.full_stop()
	return TRUE

/**
 * The engine controls, and the helm's half of the no-thrust diagnosis.
 *
 * `toggle_engine` is the only way a crew switches a thruster off from the bridge and
 * it takes a client-supplied ref, so it re-validates against the ship's own engine
 * list before touching anything. `reload_engines` is the diagnosis button: it
 * refreshes the roster and reads `engine_diagnostic_report()` back to the bridge,
 * which is the only place in the game that ever says *why* a thruster is missing or
 * producing nothing.
 */
/datum/unit_test/voidcrew_flight/helm_surface/proc/assert_engine_actions(obj/structure/overmap/ship/ship, obj/machinery/computer/helm/console, mob/living/carbon/human/crewman, datum/tgui/window)
	var/obj/machinery/power/shuttle_engine/ship/engine
	for(var/obj/machinery/power/shuttle_engine/ship/candidate as anything in ship.shuttle.engine_list)
		if(!QDELETED(candidate))
			engine = candidate
			break
	TEST_ASSERT_NOTNULL(engine, "the hull lists no engines at all, so the engine controls cannot be driven")

	var/was_enabled = engine.enabled
	if(!vc_ui_act(crewman, console, "toggle_engine", list("engine" = REF(engine)), window))
		return FALSE
	TEST_ASSERT_EQUAL(engine.enabled, !was_enabled, "the helm's engine switch did not flip [engine.name] (enabled is [engine.enabled])")
	if(!vc_ui_act(crewman, console, "toggle_engine", list("engine" = REF(engine)), window))
		return FALSE
	TEST_ASSERT_EQUAL(engine.enabled, was_enabled, "the helm's engine switch would not flip [engine.name] back")

	// A ref to something that is not this ship's engine must not be actionable: the
	// ref comes off the wire and locate() reaches any engine in the world.
	var/obj/machinery/power/shuttle_engine/ship/foreign = allocate(/obj/machinery/power/shuttle_engine/ship/void)
	var/foreign_enabled = foreign.enabled
	if(!vc_ui_act(crewman, console, "toggle_engine", list("engine" = REF(foreign)), window))
		return FALSE
	TEST_ASSERT_EQUAL(foreign.enabled, foreign_enabled, "the helm switched an engine that belongs to no ship of its own. Only engines in current_ship.shuttle.engine_list are the console's to touch (_helm.dm:980).")

	// The diagnosis button, on a hull carrying a thruster that cannot produce anything.
	var/obj/machinery/power/shuttle_engine/ship/electric/ion = flight_mount_thruster(ship, /obj/machinery/power/shuttle_engine/ship/electric)
	if(isnull(ion))
		return FALSE
	// See the dynamics test: the dead grid is constructed on purpose, because which deck
	// tile the fixture hands out decides whether the thruster lands on live cable.
	ion.disconnect_from_network()
	ion.update_engine()
	ship.est_thrust = -1 // so the refresh below is provably what rewrote it
	if(!vc_ui_act(crewman, console, "reload_engines", null, window))
		qdel(ion)
		return FALSE
	TEST_ASSERT(ship.est_thrust >= 0, "the helm's Refresh Engines button did not re-derive est_thrust (it is still [ship.est_thrust])")
	var/list/report = ship.engine_diagnostic_report()
	var/named_the_ion = FALSE
	for(var/line in report)
		if(findtext(line, ion.name) && findtext(line, "cable"))
			named_the_ion = TRUE
			break
	TEST_ASSERT(named_the_ion, "the helm's engine diagnosis did not name an unpowered ion thruster bolted to the hull and the cable it is missing. \
		This readback is the whole of what the crew is told about a thruster that produces nothing (_helm.dm:875-891); the alternative is the console silently listing one fewer engine. Lines were: [report.Join(" | ")]")

	qdel(ion)
	ship.refresh_engines()
	return TRUE

/**
 * Every flight-policy toggle the console draws is settable, and lands on its own var.
 *
 * A census, because the failure mode is a key that drifts on one side of the wire.
 * `get_autopilot_data()["prefs"]` is what the panel renders from and
 * `set_autopilot_pref()` is what the panel writes through, and they are two separate
 * hand-maintained lists of the same six strings (ship_autopilot.dm:1018-1032 and
 * :1055-1062). A key present in one and not the other is a switch that renders,
 * clicks, and does nothing at all.
 */
/datum/unit_test/voidcrew_flight/helm_surface/proc/assert_policy_toggles(obj/structure/overmap/ship/ship, obj/machinery/computer/helm/console, mob/living/carbon/human/crewman, datum/tgui/window)
	var/list/autopilot_data = ship.get_autopilot_data()
	var/list/prefs = autopilot_data["prefs"]
	TEST_ASSERT_NOTNULL(prefs, "the helm's autopilot block carries no flight-policy prefs, so the settings panel has nothing to render")
	TEST_ASSERT_EQUAL(length(prefs), 6, "the flight policy has [length(prefs)] toggle\s, not the 6 this census was written against ([prefs.Join(", ")]). A new policy needs an assertion here and a row in HelmComputer.tsx's AUTOPILOT_POLICY_ROWS.")

	for(var/key in prefs)
		var/before = prefs[key]
		if(!vc_ui_act(crewman, console, "autopilot_pref", list("key" = key, "value" = before ? 0 : 1), window))
			return FALSE
		var/list/after_data = ship.get_autopilot_data()
		var/list/after = after_data["prefs"]
		TEST_ASSERT_EQUAL(after[key], !before, "flipping the flight policy '[key]' from the helm did not change it (still [after[key]]). set_autopilot_pref() whitelists the key server-side (ship_autopilot.dm:1018-1032) and drops anything it does not recognise, so a key that renders but does not stick is a switch the crew can press for nothing.")
		// and back, so the hull is handed over in the state it was found in
		if(!vc_ui_act(crewman, console, "autopilot_pref", list("key" = key, "value" = before ? 1 : 0), window))
			return FALSE
		var/list/restored_data = ship.get_autopilot_data()
		var/list/restored = restored_data["prefs"]
		TEST_ASSERT_EQUAL(restored[key], before, "the flight policy '[key]' would not go back to [before]")

	// An unrecognised key is dropped, not stored.
	if(!vc_ui_act(crewman, console, "autopilot_pref", list("key" = "vcFlightTestNonsense", "value" = 1), window))
		return FALSE
	var/list/unchanged_data = ship.get_autopilot_data()
	var/list/unchanged = unchanged_data["prefs"]
	TEST_ASSERT_EQUAL(length(unchanged), 6, "an unrecognised flight-policy key was accepted into the prefs block ([unchanged.Join(", ")])")
	return TRUE

/**
 * Engaging and cancelling a course from the console.
 *
 * The console works in chart-relative coordinates and the ship works in absolute turf
 * coordinates; the conversion is done in `ui_act` (_helm.dm:1038-1042) and is exactly
 * the kind of off-by-one that survives review, so the assertion is on the absolute
 * destination the ship ends up holding.
 */
/datum/unit_test/voidcrew_flight/helm_surface/proc/assert_autopilot_actions(obj/structure/overmap/ship/ship, obj/machinery/computer/helm/console, mob/living/carbon/human/crewman, datum/tgui/window)
	// As in the dynamics test: the lane is proven clean against the ship's real danger
	// map, and the ship is left standing on its start tile.
	var/list/lane = flight_find_autopilot_lane(ship, 4)
	if(isnull(lane))
		return FALSE
	var/start_x = lane[1]
	var/row = lane[2]

	ship.full_stop()
	ship.forceMove(flight_tile(start_x, row))
	TEST_ASSERT(ship.can_thrust(), "the hull cannot thrust, and the helm's autopilot refuses without engine power")

	// What the chart sends: tile coordinates relative to the overmap's own origin.
	var/relative_x = (start_x + 3) - FLIGHT_LEFT_EDGE + 1
	var/relative_y = row - (world.maxy - 50) + 1
	if(!vc_ui_act(crewman, console, "autopilot", list("x" = relative_x, "y" = relative_y), window))
		return FALSE
	TEST_ASSERT(ship.autopilot_engaged, "the helm's autopilot button did not engage a course down a clear lane")
	TEST_ASSERT_EQUAL(ship.autopilot_dest_x, start_x + 3, "the console's relative x [relative_x] became absolute [ship.autopilot_dest_x], not [start_x + 3] - the conversion at _helm.dm:1038-1042 is off")
	TEST_ASSERT_EQUAL(ship.autopilot_dest_y, row, "the console's relative y [relative_y] became absolute [ship.autopilot_dest_y], not [row]")
	// Whether engaging lights the burn in-call is the SHIP layer's contract, and it is
	// diagnosed in full by /datum/unit_test/voidcrew_flight/dynamics. Recorded here rather
	// than asserted so a fault in that layer does not also stop the console's own
	// assertions - the cancel and hand-back paths below - from being reached and reported.
	if(!(ship.burn_direction & EAST))
		TEST_FAIL("the helm engaged a course three tiles east and the engines stayed cold (burn_direction [ship.burn_direction]). The console's half of this is done - the course is engaged and \
			aimed at ([ship.autopilot_dest_x], [ship.autopilot_dest_y]) - so the fault is below it, in autopilot_steer(); voidcrew_flight/dynamics prints the state that steer read.")

	if(!vc_ui_act(crewman, console, "autopilot_cancel", null, window))
		return FALSE
	TEST_ASSERT(!ship.autopilot_engaged, "the helm's cancel button did not stand the course down")
	TEST_ASSERT_EQUAL(ship.autopilot_status, "stood down at the helm", "cancelling from the helm left status \"[ship.autopilot_status || "none"]\", which is what the console displays to the crew")

	// And a manual heading takes the ship off autopilot without being asked twice.
	if(!vc_ui_act(crewman, console, "autopilot", list("x" = relative_x, "y" = relative_y), window))
		return FALSE
	TEST_ASSERT(ship.autopilot_engaged, "the second engage from the helm did not take")
	if(!vc_ui_act(crewman, console, "change_heading", list("dir" = WEST), window))
		return FALSE
	TEST_ASSERT(!ship.autopilot_engaged, "touching the direction pad did not take the ship off autopilot. Every manual course input disengages first (_helm.dm:989), quietly - otherwise the autopilot and the pilot fight over the engines.")
	TEST_ASSERT_EQUAL(ship.commanded_course, WEST, "the manual course that took the ship off autopilot did not itself take (commanded_course is [ship.commanded_course])")

	ship.full_stop()
	return TRUE

// ===========================================================================
// 3. The tick path itself: a structural census, so a rule cannot be lifted back
//    out of it.
// ===========================================================================

/**
 * Every movement rule is inside `tick_move()`, and `tick_move()` asks nothing about
 * thrust.
 *
 * The live flights above prove two of these rules apply to a coasting hull. This
 * proves the *shape*: that the rules are still in the tick path at all, and - the
 * half no behavioural test can express cheaply - that the tick path contains no
 * thrust gate for a rule to end up behind. Moving the zone check back under a
 * `if(burn_direction)` would leave every assertion above passing on a burning ship
 * and re-ship the exact bug ship.dm:3031-3043 describes; this fails on it.
 *
 * Source-text rather than behaviour because DM cannot introspect a proc body, and
 * this is the same trade `voidcrew_fleet_waypoints.dm` makes for its fan-out scan.
 */
/datum/unit_test/voidcrew_flight/rule_census

/datum/unit_test/voidcrew_flight/rule_census/Run()
	var/source = vc_test_file_text(FLIGHT_SHIP_SOURCE)
	TEST_ASSERT_NOTNULL(source, "could not read [FLIGHT_SHIP_SOURCE]; the overmap ship moved and this census is scanning nothing")

	var/raw_tick_body = flight_proc_body(source, "/obj/structure/overmap/ship/proc/tick_move()")
	TEST_ASSERT_NOTNULL(raw_tick_body, "could not find /obj/structure/overmap/ship/proc/tick_move() in [FLIGHT_SHIP_SOURCE]")
	TEST_ASSERT(length(raw_tick_body) > 400, "the extracted tick_move() body is only [length(raw_tick_body)] characters; the proc-body scan is not reading the whole proc")
	// Comments out: tick_move()'s own comment names burn_direction while explaining why
	// the zone check had to move here, and the forbidden-token sweep below is a claim
	// about the code, not about the prose.
	var/tick_body = flight_strip_line_comments(raw_tick_body)

	// The rules, and what each one is for. Every one of these applies to a ship with
	// cold engines, because that is the only kind of ship tick_move() ever sees a lot of.
	var/static/list/tick_rules = list(
		"is_still()" = "the stillness gate: without it a stopped ship keeps its movement timer armed forever",
		"x + sign(speed" = "the step is taken from the SIGN of the velocity, never its magnitude - one tile per fire, however fast the ship is going",
		"y + sign(speed" = "the same on the north/south axis",
		"OVERMAP_LEFT_SIDE_COORD" = "the west seam of the wraparound",
		"OVERMAP_RIGHT_SIDE_COORD" = "the east seam of the wraparound",
		"zone_crossing(" = "the zone boundary check - the rule that was once only in burn_engines(), which let every coasting hull cross zone lines for free",
		"start_zone_transition(" = "and the crossing it starts",
		"forceMove(newloc)" = "the position commit",
		"check_hazards()" = "hazard entry: a coasting ship that drifts into a storm still takes it",
		"reschedule_movement()" = "the next tick, which is also where the interdiction throttle is applied",
		"autopilot_steer()" = "one tile crossed is one steering decision",
	)
	for(var/rule in tick_rules)
		TEST_ASSERT(findtext(tick_body, rule), "tick_move() no longer contains `[rule]` - [tick_rules[rule]]. A movement rule that leaves the tick path stops applying to coasting ships, which is how the ordinary way to fly (burn up to speed, then coast) became exempt from every rule the game had.")

	// And nothing in the tick path may ask whether the engines are lit.
	var/static/list/forbidden_in_tick = list(
		"burn_direction" = "a rule behind a burn check does not apply to a coasting ship",
		"can_thrust(" = "same",
		"thrust_processing" = "same",
		"burn_engines(" = "the tick path steps the ship; it does not burn",
	)
	for(var/token in forbidden_in_tick)
		TEST_ASSERT(!findtext(tick_body, token), "tick_move() now reads `[token]` - [forbidden_in_tick[token]]. The rules in the tick path are the only ones a coasting hull is subject to, and the fork's own account of this regression is in the comment at ship.dm:3031-3043.")

	// The burn path keeps its own early copy of the boundary check, for the case where
	// the crew is already sitting on the line. Both are needed; neither replaces the other.
	var/raw_burn_body = flight_proc_body(source, "/obj/structure/overmap/ship/proc/burn_engines(")
	TEST_ASSERT_NOTNULL(raw_burn_body, "could not find burn_engines() in [FLIGHT_SHIP_SOURCE]")
	var/burn_body = flight_strip_line_comments(raw_burn_body)
	TEST_ASSERT(findtext(burn_body, "zone_crossing("), "burn_engines() lost its early zone-boundary check; ordering a burn straight at a boundary should start the crossing there and then rather than building speed the ship is only going to have taken off it a tile later")
	TEST_ASSERT(findtext(burn_body, "warn_no_thrust()"), "burn_engines() no longer warns when it produces nothing. A burn that quietly returns zero is a ship that will not move with every gauge on the helm reading healthy (ship.dm:4376-4381).")

	assert_ion_gauge_contract()

/**
 * The ion thruster's gauge and its burn read two different numbers, in that order.
 *
 * This is the fork's documented no-thrust trap, stated as source: the helm's fuel gauge
 * for an ion thruster reads the **stored charge of a SMES on its powernet**, while
 * `burn_engine()` spends **live wattage off the wire** (`max(avail(), newavail())`).
 * A full SMES with its output disabled therefore reads 100% on a bridge whose ship will
 * not move - and the one line that reconciles the two is the dead-wire guard at the top
 * of `return_fuel()`, which must come **before** the SMES lookup or it cannot shadow it.
 *
 * Asserted structurally rather than flown, and deliberately: reproducing the live case
 * needs a powernet carrying a charged SMES with its output off, which is a power-system
 * fixture rather than a flight one. What the dynamics test flies is the neighbouring
 * case (an ion thruster with no cable under it at all); what this pins is that the guard
 * and the ordering it depends on are still there, which is what a behavioural test on
 * the flown case cannot see.
 */
/datum/unit_test/voidcrew_flight/rule_census/proc/assert_ion_gauge_contract()
	var/ion_source = vc_test_file_text(FLIGHT_ION_SOURCE)
	TEST_ASSERT_NOTNULL(ion_source, "could not read [FLIGHT_ION_SOURCE]; the ion thruster moved and this census is scanning nothing")

	var/fuel_body = flight_strip_line_comments(flight_proc_body(ion_source, "/obj/machinery/power/shuttle_engine/ship/electric/return_fuel()"))
	TEST_ASSERT_NOTNULL(fuel_body, "could not find the ion thruster's return_fuel() in [FLIGHT_ION_SOURCE]")
	var/guard_at = findtext(fuel_body, "if(!avail() && !newavail())")
	TEST_ASSERT(guard_at, "the ion thruster's return_fuel() no longer refuses on a dead wire. Without `if(!avail() && !newavail()) return 0` the helm's fuel gauge reports a full SMES on a grid that is supplying nothing, which is the ship-will-not-move-and-everything-reads-fine call this guard was written to end.")
	var/smes_at = findtext(fuel_body, "total_charge()")
	if(smes_at)
		TEST_ASSERT(guard_at < smes_at, "the ion thruster's dead-wire guard now runs AFTER the SMES lookup, so stored charge is reported before the wire is ever checked - the guard only shadows the gauge if it comes first")

	var/ion_burn_body = flight_strip_line_comments(flight_proc_body(ion_source, "/obj/machinery/power/shuttle_engine/ship/electric/burn_engine("))
	TEST_ASSERT_NOTNULL(ion_burn_body, "could not find the ion thruster's burn_engine() in [FLIGHT_ION_SOURCE]")
	TEST_ASSERT(findtext(ion_burn_body, "max(avail(), newavail())"), "the ion thruster's burn no longer draws live wire power. Burns spend wattage off the wire; the moment they read stored charge instead, the gauge and the burn agree again and the whole diagnosis stops meaning anything.")
	TEST_ASSERT(!findtext(ion_burn_body, "total_charge"), "the ion thruster's burn now reads a SMES's stored charge. That is the gauge's number, not the burn's (electric.dm:57-66 vs :46-55).")

#undef FLIGHT_OVERMAP_Z
#undef FLIGHT_LEFT_EDGE
#undef FLIGHT_RIGHT_EDGE
#undef FLIGHT_WRAP_LOW_X
#undef FLIGHT_WRAP_HIGH_X
#undef FLIGHT_BURN_NONE
#undef FLIGHT_BURN_STOP
#undef FLIGHT_STATE_FLYING
#undef FLIGHT_TEST_HULL
#undef FLIGHT_SHIP_SOURCE
#undef FLIGHT_HELM_SOURCE
#undef FLIGHT_ION_SOURCE
