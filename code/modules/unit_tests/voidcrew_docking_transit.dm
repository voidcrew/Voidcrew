/**
 * # Docking, transit and berths: the cycle nothing has ever driven
 *
 * `voidcrew_hull_containment.dm` measures a hull's rectangle and a berth's rectangle very
 * carefully, and then never moves either of them. Every assertion in this fork about docking
 * is geometry on a stationary object; `initiate_docking()` - the proc that actually
 * transplants a hull, the one upstream rewrites every release - has never been called by a
 * test. The two files are complementary: that one asks "is the rectangle right", this one
 * asks "does the move the rectangle describes actually happen, and does it come back".
 *
 * ## What is driven here, and what is not
 *
 * Everything is driven by DIRECT PROC CALL. Nothing waits on SSshuttle's schedule and nothing
 * sleeps hoping a subsystem tick lands. `initiate_docking()` is synchronous - it yields on
 * CHECK_TICK but it returns a status code - so a dock is `port.initiate_docking(berth, dir)`
 * and an undock is `port.enterTransit()`, which is exactly what SSshuttle's own `check()`
 * calls one line deeper. The one place the subsystem itself is the object under test (the
 * transit-dock reaper, which lives inline in `SSshuttle.fire()` and cannot be reached any
 * other way) is driven by calling `SSshuttle.fire()` by hand, in the second test.
 *
 * The coverage boundary is the OVERMAP layer above this: `ship.dock()` /
 * `complete_dock_warmup()` / `complete_dock()` are a chain of `addtimer()` callbacks with a
 * 10 second warmup and a one-second retry cadence, and driving them honestly means either
 * sleeping through real time or reimplementing the chain. Neither is a test. What that chain
 * does that this file does not cover: the warmup timers, the dock_index/first_dock_taken
 * bookkeeping, and `abort_stalled_dock()`/`abort_stalled_undock()`. The MOVE those callbacks
 * are waiting on, and every invariant that survives it, is covered here.
 *
 * ## The hull: borrowed, not built
 *
 * `spawn_initial_ship()` has an `#ifdef UNIT_TESTS` branch that loads EVERY
 * `/datum/map_template/shuttle/voidcrew` subtype at boot, so the test world already holds ~48
 * real assembled hulls, each parked on its own transit dock. This test borrows the smallest
 * one rather than calling `vc_create_test_ship()`, which is a second full map load costing
 * three sleeps and an `SSair.can_fire` toggle for a hull no better than the ones already
 * standing there. `vc_create_test_ship()` is kept as a fallback for a world that has none.
 *
 * Borrowing means the ship must be handed back in the state it was found in, and the teardown
 * order here is not negotiable: the hull goes home to its transit dock FIRST, and only then is
 * the encounter released. `clear_to_uninitialized_space()` scrapes every turf of the
 * footprint, so releasing an encounter with a borrowed hull still standing in it would delete
 * a live ship's decks out from under the rest of the suite. If the hull cannot be brought
 * home, this test LEAKS the encounter on purpose and says so.
 *
 * ## Breakage classes the assertions here are aimed at
 *
 *  1. **"Did it move?" answered with `shuttle.mode`.** `SHUTTLE_CALL` is a voidcrew port's
 *     resting state in open flight, so a mode check reads the same one second after the
 *     request as it does after the arrival. The honest test is `get_docked()` - is the hull
 *     still standing on a transit dock - and `complete_dock()` was walking overmap tokens onto
 *     sites without their crews until it started using it. Pinned by asserting the mode does
 *     NOT change across a successful move.
 *  2. **The rotation trap.** `preferred_direction` vs the dir `adjust_reserve_dock_to_shuttle()`
 *     picks for the berth. A dock/undock round trip must put every atom back on the turf it
 *     left, because the transit dock never moved; anything else is a hull that spins a quarter
 *     turn per visit.
 *  3. **Areas left behind.** A hull tile that does not travel is how rounds 803/804/811 lost
 *     thrusters and deck sections. A witness object aboard must change turf and keep its area
 *     instance - a new area, or the same turf, is the whole failure.
 *  4. **Transit reservation lifecycle.** A leaked reservation spends a finite global budget
 *     (`MAX_TRANSIT_TILE_COUNT`); a reservation released too eagerly strands the hull at the
 *     berth it is trying to leave, because `enterTransit()` has nothing to move to.
 *  5. **The landmark sweep.** `/obj/docking_port/mobile/voidcrew/jumpToNullSpace()` deletes
 *     every landmark inside the hull rectangle. It is correct there and catastrophic anywhere
 *     else: a normal transit move must not touch a single one, or the ship loses its job spawn
 *     points the first time it undocks.
 *  6. **Back-references to a dead berth.** `previous` and `destination` point at stationary
 *     ports that this fork force-qdels on every site teardown.
 *
 * ## Defines
 *
 * Unit tests compile at the `code/modules/unit_tests` include position, well before
 * `voidcrew/_DEFINES/`, so `RESERVE_DOCK_MAX_SIZE_LONG` and friends do not exist yet here and
 * are spelled as literals with the define named in a comment - the same convention
 * `voidcrew_map_packing.dm` and `voidcrew_hull_containment.dm` use.
 * `SOFT_TRANSIT_RESERVATION_THRESHOLD` is worse than out of scope: it is `#undef`'d at the
 * bottom of `code/controllers/subsystem/shuttle.dm`, so it is unreachable from anywhere.
 */
/datum/unit_test/voidcrew_docking_cycle
	priority = TEST_LONGER

/datum/unit_test/voidcrew_docking_cycle/Run()
	var/list/encounter = SSovermap.spawn_dynamic_encounter(null, FALSE)
	if(length(encounter) < 4)
		TEST_FAIL("spawn_dynamic_encounter() returned no encounter - there is no real berth to dock at, and nothing below is under test")
		release_encounter(encounter)
		return

	var/obj/docking_port/stationary/berth = encounter[2]
	var/obj/docking_port/stationary/spare_berth = encounter[3]
	var/datum/map_footprint/site = encounter[4]
	if(isnull(berth) || isnull(spare_berth) || isnull(site))
		TEST_FAIL("The test encounter was built without its two reserve berths or without a footprint")
		release_encounter(encounter)
		return

	var/built_own_hull = FALSE
	var/obj/structure/overmap/ship/ship = borrow_parked_hull(berth, spare_berth)
	if(isnull(ship))
		// A world without the UNIT_TESTS fleet. Pay for a real map load rather than skip.
		ship = vc_create_test_ship()
		built_own_hull = TRUE
	if(isnull(ship) || isnull(ship.shuttle))
		release_encounter(encounter)
		return

	var/obj/docking_port/mobile/voidcrew/port = ship.shuttle

	run_dock_cycle(ship, port, berth, spare_berth, site)

	// ---- Teardown, in the only order that is safe ------------------------------------
	// The hull first: release_encounter() scrapes the footprint's turfs, and a hull still
	// standing on them would be deleted with the ground.
	var/came_home = bring_hull_home(port)

	if(built_own_hull)
		vc_release_test_ship(ship)
		release_encounter(encounter)
		return

	if(!came_home)
		TEST_FAIL("The borrowed hull [ship] could not be returned to its transit dock, so this encounter is being LEAKED rather than \
			released - clearing the footprint under a live hull would delete its decks and take out every later test that touches that ship. \
			The leaked map-zone slot and its two berths are held for the rest of the run.")
		return

	release_encounter(encounter)

	// The berths are gone now. /obj/docking_port/stationary/Destroy(force) is supposed to
	// walk every mobile port and null the back-references to itself; without it the departed
	// berth is pinned by the ship's `previous` until the GC hard-deletes it (round 4: 92 of
	// them, 22 seconds of world freeze).
	if(port.previous == berth || port.destination == berth)
		TEST_FAIL("The hull still back-references the force-deleted berth ([port.previous == berth ? "previous" : "destination"]). \
			/obj/docking_port/stationary/Destroy() is no longer clearing those, so every encounter teardown pins its berth behind a \
			live ship until the garbage collector hard-deletes it.")

/**
 * One full dock/undock cycle against a real berth, with every invariant checked at the point
 * it is decided rather than at the end.
 */
/datum/unit_test/voidcrew_docking_cycle/proc/run_dock_cycle(
	obj/structure/overmap/ship/ship,
	obj/docking_port/mobile/voidcrew/port,
	obj/docking_port/stationary/berth,
	obj/docking_port/stationary/spare_berth,
	datum/map_footprint/site,
)
	// ---- Preconditions. If any of these is false the cycle below proves nothing --------
	var/obj/docking_port/stationary/transit/home = port.assigned_transit
	if(isnull(home))
		TEST_FAIL("[ship] holds no transit reservation while parked - there is nothing to undock back to, so the cycle cannot run")
		return
	if(port.get_docked() != home)
		TEST_FAIL("[ship] is not standing on its own transit dock at the start of the cycle (get_docked() = [port.get_docked() || "nothing"])")
		return

	var/obj/machinery/witness = find_hull_witness(port)
	if(isnull(witness))
		TEST_FAIL("Found no machine aboard [ship] to witness the move with. Without one this test cannot tell a hull that moved from a \
			hull that reported moving, which is the entire point of it.")
		return

	var/turf/witness_home = get_turf(witness)
	var/area/witness_area = get_area(witness)
	var/home_dir = port.dir
	var/home_mode = port.mode
	var/landmarks_before = length(GLOB.landmarks_list)
	var/start_landmarks_before = length(GLOB.start_landmarks_list)
	var/transit_docks_before = length(SSshuttle.transit_docking_ports)
	var/mobile_ports_before = length(SSshuttle.mobile_docking_ports)
	var/transit_utilized_before = SSshuttle.transit_utilized

	var/snapshot = vc_runtime_snapshot()

	// ---- Leg 1: fit the berth the way the arrival path does ---------------------------
	// This is space_ruin.dm's own sequence: put the free berths back on their home layout,
	// then rotate and offset the chosen one around this particular hull. Skipping the reset
	// carries the last visitor's offset into the placement; skipping the adjust leaves a
	// 56x40 berth with dwidth/dheight 0, which refuses any hull with a non-zero dwidth.
	reset_free_reserve_docks_for(berth, spare_berth, FALSE, FALSE)
	adjust_reserve_dock_to_shuttle(berth, port)

	var/fit = port.canDock(berth)
	if(fit != SHUTTLE_CAN_DOCK)
		TEST_FAIL("After adjust_reserve_dock_to_shuttle() a [port.width]x[port.height] hull still cannot dock at a 56x40 reserve berth \
			(RESERVE_DOCK_MAX_SIZE_LONG x RESERVE_DOCK_MAX_SIZE_SHORT): [fit]. Every arrival at every encounter, planet and ruin goes \
			through that proc, so this is every ship in the fork unable to land.")
		return

	// ---- Leg 2: the move itself -------------------------------------------------------
	// Same call SSshuttle's check() makes: initiate_docking(destination, preferred_direction).
	var/result = port.initiate_docking(berth, port.preferred_direction)
	if(result != DOCKING_SUCCESS)
		TEST_FAIL("initiate_docking() refused a berth it had just passed canDock() on, with code [result]. \
			(DOCKING_BLOCKED = a second check_dock() failed mid-move, DOCKING_IMMOBILIZED = canMove() said no, \
			DOCKING_NULL_DESTINATION = the berth's rectangle runs off the map.)")
		return

	// The hull is on the site now. Everything from here to the undock has to run so the
	// teardown can bring it home; assertions record and continue rather than returning.
	if(port.get_docked() != berth)
		TEST_FAIL("initiate_docking() reported success but the hull is not standing on the berth (get_docked() = [port.get_docked() || "nothing"])")

	// The invariant that took four rounds to find: `mode` is not a "did it move" test.
	// It is UNCHANGED by a successful move, which is exactly why complete_dock() had to stop
	// asking it and start asking get_docked() (shuttle_is_in_transit()).
	if(port.mode != home_mode)
		TEST_FAIL("A completed dock changed the port's mode from [home_mode] to [port.mode]. That would make `mode` look like a usable \
			arrival test again - it is not one, and complete_dock() walking the overmap token onto a site without its crew is what \
			happens when someone believes it is.")
	if(ship.shuttle_is_in_transit())
		TEST_FAIL("shuttle_is_in_transit() still reports the hull in transit after it docked at a berth. complete_dock() reads this to \
			decide whether the ship actually arrived; a stuck TRUE retries until abort_stalled_dock() puts the ship back in flight.")

	// Did the hull physically travel, and did it take its area with it?
	var/turf/witness_now = get_turf(witness)
	if(witness_now == witness_home)
		TEST_FAIL("[witness] aboard [ship] is still standing on [witness_home] after the hull docked. The move reported success and left \
			the deck behind - this is the stranded-turf class that cost rounds 803/804/811 their thrusters.")
	if(get_area(witness) != witness_area)
		TEST_FAIL("[witness] changed area instance across the move ([witness_area] -> [get_area(witness)]). A hull tile that lands in a \
			different instance of its own area type fails every shuttle_areas membership test while stringifying identically in logs, \
			and will not travel on the next move.")
	if(witness_now && map_region_for_turf(witness_now) != site)
		TEST_FAIL("The hull landed on ground that does not belong to the encounter it docked at (map_region_for_turf() resolved \
			[map_region_for_turf(witness_now) || "nothing"], expected [site.describe()])")

	// Per-site occupancy and the z-trait it backs.
	if(site_ship_occupancy(site) != 1)
		TEST_FAIL("The site occupancy register counts [site_ship_occupancy(site)] hull(s) on [site.describe()] with exactly one docked. \
			turf_has_ship_presence() - undock refusals, assault pod targeting, stationloving relocation - reads this.")
	if(!is_station_level(site.z_value))
		TEST_FAIL("z[site.z_value] was not flagged ZTRAIT_STATION by a hull docking on it. Stationloving and everything downstream of \
			is_station_level() stops working aboard the ship.")

	// Berth bookkeeping: ours is taken, the other one is still free, and we are told so.
	if(berth.get_docked() != port)
		TEST_FAIL("The berth does not resolve the docked hull ([berth.get_docked() || "nothing"]). get_docked() finds a berth by the \
			mobile port's turf, so this means the two are no longer standing on the same tile.")
	if(!isnull(spare_berth.get_docked()))
		TEST_FAIL("The encounter's SECOND berth reports a hull standing on it after only one ship docked - the two berths overlap, and \
			a ship-to-ship pairing (which takes both) would be handed the same ground twice.")
	if(port.canDock(berth) != SHUTTLE_ALREADY_DOCKED)
		TEST_FAIL("A hull asking to dock at the berth it is already standing on got [port.canDock(berth)] instead of SHUTTLE_ALREADY_DOCKED. \
			request() treats that code as 'nothing to do'; anything else re-runs the whole turf transplant in place.")

	// The transit reservation MUST survive the landing, and it is worth being precise about
	// why. SSshuttle.fire() reaps a transit dock whose owner is SHUTTLE_IDLE, whose
	// launch_status is NOLAUNCH, and which has nothing standing on it. A docked voidcrew hull
	// satisfies the third and neither of the first two - `mode` stays SHUTTLE_CALL and
	// /obj/docking_port/mobile/voidcrew sets launch_status = UNLAUNCHED. Lose either and the
	// reservation is reclaimed while the ship is berthed, enterTransit() has nothing to move
	// to, and the undock stalls into abort_stalled_undock() with the crew still inside.
	if(port.assigned_transit != home || QDELETED(home))
		TEST_FAIL("The hull lost its transit reservation by docking (assigned_transit = [port.assigned_transit || "null"]). It cannot \
			undock again until SSshuttle grants it a new one, and the global transit budget is finite and shared.")
	if(port.launch_status == NOLAUNCH)
		TEST_FAIL("A voidcrew hull is carrying launch_status NOLAUNCH. That is the upstream default, and /obj/docking_port/mobile/voidcrew \
			overrides it to UNLAUNCHED for a load-bearing reason: NOLAUNCH is one of the three conditions SSshuttle.fire() reaps an idle \
			ship's transit dock on. Restore the override or every docked hull loses its reservation.")
	if(!isnull(home.get_docked()))
		TEST_FAIL("The vacated transit dock still reports a hull standing on it after the ship left for a berth")

	// The fresh jumpToNullSpace() landmark sweep is scoped to a hull being DESTROYED. A
	// transit move must not fire it - a ship that loses its job spawn points on its first
	// undock has no crew for the rest of the round.
	if(length(GLOB.landmarks_list) != landmarks_before)
		TEST_FAIL("GLOB.landmarks_list went [landmarks_before] -> [length(GLOB.landmarks_list)] across a plain dock. \
			jumpToNullSpace()'s landmark sweep is firing on a move; it must only fire when the hull is being destroyed.")
	if(length(GLOB.start_landmarks_list) != start_landmarks_before)
		TEST_FAIL("GLOB.start_landmarks_list went [start_landmarks_before] -> [length(GLOB.start_landmarks_list)] across a plain dock - \
			the hull's job spawn points were swept by a move")

	// ---- Leg 3: two ships, two berths -------------------------------------------------
	assert_berth_contention(port, berth, spare_berth)

	// ---- Leg 4: the berth that does not fit -------------------------------------------
	assert_undersized_berth_refusal(ship, port, berth, witness, witness_now)

	// ---- Leg 5: undock ----------------------------------------------------------------
	// enterTransit() is what complete_undock_warmup() is really waiting for SSshuttle to
	// call. Driving it directly removes the timer chain and nothing else.
	port.enterTransit()

	if(port.get_docked() != home)
		TEST_FAIL("After enterTransit() the hull is standing on [port.get_docked() || "nothing"] rather than its transit dock. \
			This is the undock that leaves a ship parked at the berth it just 'left' while the chart shows it flying.")
		return
	if(!ship.shuttle_is_in_transit())
		TEST_FAIL("shuttle_is_in_transit() is FALSE with the hull standing on its transit dock - complete_dock()'s UNDOCKING branch \
			would retry until abort_stalled_undock() puts the ship back on the dock it just left")

	if(port.previous != berth)
		TEST_FAIL("enterTransit() did not record the berth it left in `previous` (got [port.previous || "null"]). SHUTTLE_RECALL docks \
			back to `previous`, so a recall from open flight would have nowhere to go.")
	if(!isnull(berth.get_docked()))
		TEST_FAIL("The berth still reports a hull standing on it after the undock - the next arrival is refused with \
			SHUTTLE_SOMEONE_ELSE_DOCKED against a berth nobody is using")
	if(site_ship_occupancy(site))
		TEST_FAIL("[site_ship_occupancy(site)] hull(s) still counted on [site.describe()] after the only one undocked. The site reads as \
			occupied for the rest of the round, and the freed slot is dealt to the next tenant that way.")

	// The round trip. The transit dock never moved, so a hull that came home rotated - or
	// offset - did so inside the move, which is the preferred_direction /
	// adjust_reserve_dock_to_shuttle disagreement.
	if(get_turf(witness) != witness_home)
		TEST_FAIL("[witness] came back to [get_turf(witness) || "nowhere"] instead of [witness_home] after a dock/undock round trip. \
			The transit dock did not move, so the hull was put back rotated or offset - the preferred_direction vs \
			adjust_reserve_dock_to_shuttle() trap. Every cycle compounds it.")
	if(port.dir != home_dir)
		TEST_FAIL("The hull came home facing [port.dir] instead of [home_dir]. return_coords() projects the rectangle from this dir, so \
			every later bounds test - engine membership, berth fit, containment - is computed against ground the hull is not on.")
	if(get_area(witness) != witness_area)
		TEST_FAIL("[witness] is in a different area instance ([get_area(witness)]) after the round trip than it started in ([witness_area])")

	// ---- Leg 6: nothing leaked --------------------------------------------------------
	if(port.assigned_transit != home)
		TEST_FAIL("The hull is holding a different transit dock after the cycle than the one it started and ended parked on")
	if(length(SSshuttle.transit_docking_ports) != transit_docks_before)
		TEST_FAIL("SSshuttle.transit_docking_ports went [transit_docks_before] -> [length(SSshuttle.transit_docking_ports)] across one \
			dock/undock cycle. A transit dock minted and not released spends the global budget permanently; the budget is what \
			check_transit_zone() gates on, and exhausting it means no ship can dock or undock again.")
	if(SSshuttle.transit_utilized != transit_utilized_before)
		TEST_FAIL("SSshuttle.transit_utilized went [transit_utilized_before] -> [SSshuttle.transit_utilized] across one cycle that \
			minted and released nothing. transit_utilized is only decremented by the reservation's own COMSIG_QDELETING handler, so \
			drift here is permanent.")
	if(length(SSshuttle.mobile_docking_ports) != mobile_ports_before)
		TEST_FAIL("SSshuttle.mobile_docking_ports went [mobile_ports_before] -> [length(SSshuttle.mobile_docking_ports)] across one cycle")
	if(length(GLOB.landmarks_list) != landmarks_before)
		TEST_FAIL("GLOB.landmarks_list went [landmarks_before] -> [length(GLOB.landmarks_list)] across a full dock/undock cycle")
	if(length(GLOB.start_landmarks_list) != start_landmarks_before)
		TEST_FAIL("GLOB.start_landmarks_list went [start_landmarks_before] -> [length(GLOB.start_landmarks_list)] across a full cycle")

	assert_no_duplicate_shuttle_ids()

	vc_assert_no_new_runtimes(snapshot, "one dock/undock cycle against a real encounter berth")

/**
 * A second hull may not take a berth that is already occupied, and the encounter's other
 * berth is still open to it.
 *
 * Two ships contending for the two encounter berths is the ordinary case (a ship-to-ship dock
 * takes both), and the only thing standing between it and a hull overwritten in place is
 * canDock()'s occupancy check - containment is never checked by the move itself.
 */
/datum/unit_test/voidcrew_docking_cycle/proc/assert_berth_contention(
	obj/docking_port/mobile/voidcrew/port,
	obj/docking_port/stationary/berth,
	obj/docking_port/stationary/spare_berth,
)
	// A stand-in for the second ship. `list()` as the areas argument is deliberate: it is
	// truthy, so Initialize() takes the "areas were supplied" branch and skips the turf scan
	// that would otherwise register whatever this port was created on top of.
	var/obj/docking_port/mobile/contender = new(run_loc_floor_bottom_left, list())
	contender.width = 5
	contender.height = 5
	contender.dwidth = 0
	contender.dheight = 0

	var/against_taken = contender.canDock(berth)
	if(against_taken != SHUTTLE_SOMEONE_ELSE_DOCKED)
		TEST_FAIL("A second hull asking for the berth our ship is standing on got [against_taken] instead of SHUTTLE_SOMEONE_ELSE_DOCKED. \
			Nothing else refuses it - initiate_docking() runs the destructive move callbacks over whatever is in the rectangle, so the \
			docked ship would be cut, force-closed and gibbed in place.")

	var/against_free = contender.canDock(spare_berth)
	if(against_free != SHUTTLE_CAN_DOCK)
		TEST_FAIL("The encounter's free second berth refused a 5x5 hull with [against_free]. Both berths are built 56x40 \
			(RESERVE_DOCK_MAX_SIZE_LONG x RESERVE_DOCK_MAX_SIZE_SHORT) with dwidth/dheight 0, so a small hull with matching offsets fits \
			without adjustment; a refusal here means one ship docking has moved or resized the OTHER berth.")

	qdel(contender, force = TRUE) // never optional on a docking port - a bare qdel is a no-op

/**
 * The documented refusal path: a berth the hull does not fit does not move it and does not
 * corrupt anything.
 *
 * request() drops a refused dock call on the floor with no return value, which is why
 * explain_dock_refusal() exists - it runs the same side-effect-free geometry check and tells
 * the crew. Both halves are checked: the reason is the documented one, and the request that
 * follows really is inert.
 */
/datum/unit_test/voidcrew_docking_cycle/proc/assert_undersized_berth_refusal(
	obj/structure/overmap/ship/ship,
	obj/docking_port/mobile/voidcrew/port,
	obj/docking_port/stationary/berth,
	obj/machinery/witness,
	turf/witness_expected,
)
	// Built in nullspace: canDock() is pure geometry and never looks at where the berth
	// stands, and a port dropped on real ground would be found by get_docked() calls from
	// anything that happened to be standing there.
	var/obj/docking_port/stationary/pocket = new(null)
	// One tile narrower than the hull, with the hull's own docking offsets - so the dwidth,
	// dheight and height clauses of canDock() all pass and the WIDTH clause is the only thing
	// that can refuse. A pocket berth that failed on dwidth would prove nothing about size.
	pocket.dwidth = port.dwidth
	pocket.dheight = port.dheight
	pocket.width = max(port.width - 1, port.dwidth)
	pocket.height = port.height

	var/status = port.canDock(pocket)
	if(status != SHUTTLE_WIDTH_TOO_LARGE)
		TEST_FAIL("A hull [port.width] wide measured against a [pocket.width] wide berth got [status] instead of SHUTTLE_WIDTH_TOO_LARGE. \
			canDock() is the only fit test in the fork - a hull extension that outgrows its berth is refused here or not at all.")

	if(!ship.explain_dock_refusal(pocket))
		TEST_FAIL("explain_dock_refusal() did not report a refusal for a berth the hull cannot fit. request() drops the call silently, \
			so the crew gets no sign at all until the stall watchdog reconciles the ship 90 seconds later.")
	if(port.check_dock(pocket, silent = TRUE))
		TEST_FAIL("check_dock() passed a berth canDock() had just refused")
	if(ship.explain_dock_refusal(berth))
		TEST_FAIL("explain_dock_refusal() reported a fault for the berth the ship is already docked at. SHUTTLE_ALREADY_DOCKED is \
			benign - request() treats it as 'nothing to do' - and a fault broadcast there tells the crew a working dock failed.")

	// And the refusal really is inert: no state moved, no hull moved.
	var/mode_before = port.mode
	var/destination_before = port.destination
	var/timer_before = port.timer
	var/turf/port_turf_before = get_turf(port)

	port.request(pocket)

	if(port.mode != mode_before)
		TEST_FAIL("A refused request() changed the port's mode ([mode_before] -> [port.mode]). A port left mid-launch by a dock that \
			was never going to happen refuses the NEXT undock too, because request() sees a launch already in progress.")
	if(port.destination != destination_before)
		TEST_FAIL("A refused request() set the port's destination to [port.destination || "null"]. check() docks to `destination` the \
			moment the timer expires, so this is a hull that flies to a berth it does not fit.")
	if(port.timer != timer_before)
		TEST_FAIL("A refused request() armed the port's timer")
	if(get_turf(port) != port_turf_before)
		TEST_FAIL("A refused request() moved the docking port")
	if(get_turf(witness) != witness_expected)
		TEST_FAIL("A refused request() moved the hull: [witness] left [witness_expected] for [get_turf(witness) || "nowhere"]")
	if(berth.get_docked() != port)
		TEST_FAIL("A refused request() at an unrelated berth broke the hull's link to the berth it is standing on")

	qdel(pocket, force = TRUE)

/**
 * The smallest hull in the test world that is parked on its own transit dock, has nobody
 * aboard, and genuinely fits a real encounter berth. Null if the world has none.
 *
 * Smallest by rectangle because this is a speed choice - two full turf transplants are paid
 * for per run. Crewless because the move gibs and evicts. And fit-VERIFIED rather than
 * size-filtered, because whether a hull fits is not a question of area: after
 * `adjust_reserve_dock_to_shuttle()` re-faces the berth, `canDock()` compares the hull's
 * width against the berth's width with no rotation accounting, and which way round those end
 * up is decided by the aspect-ratio guess inside that proc. A hull whose `preferred_direction`
 * disagrees with the guess is legitimately refused - the game refuses it too, with "Ship is
 * too large to dock at this location" - so a hull that does not fit is skipped rather than
 * failed, and only a world where NOTHING fits is a finding.
 *
 * The berth is left re-faced for whichever hull was tested last, so the caller must run
 * reset + adjust again for the one it takes. run_dock_cycle() does, as its first act.
 */
/datum/unit_test/voidcrew_docking_cycle/proc/borrow_parked_hull(
	obj/docking_port/stationary/berth,
	obj/docking_port/stationary/spare_berth,
)
	var/obj/structure/overmap/ship/best
	var/best_area = 0
	var/considered = 0
	for(var/obj/structure/overmap/ship/candidate as anything in SSovermap.simulated_ships)
		if(!istype(candidate) || QDELETED(candidate))
			continue
		var/obj/docking_port/mobile/voidcrew/candidate_port = candidate.shuttle
		if(!istype(candidate_port) || QDELETED(candidate_port))
			continue
		if(isnull(candidate_port.assigned_transit))
			continue
		if(candidate_port.get_docked() != candidate_port.assigned_transit)
			continue
		if(!length(candidate_port.shuttle_areas))
			continue
		var/candidate_area = candidate_port.width * candidate_port.height
		if(!candidate_area)
			continue
		// 56x40 is RESERVE_DOCK_MAX_SIZE_LONG x RESERVE_DOCK_MAX_SIZE_SHORT. A cheap
		// rejection before the expensive checks; the real fit test is the canDock() below.
		if(max(candidate_port.width, candidate_port.height) > 56 || min(candidate_port.width, candidate_port.height) > 40)
			continue
		// Nothing below can improve on a hull we already have, so stop paying for it.
		if(!isnull(best) && candidate_area >= best_area)
			continue
		if(hull_has_living_aboard(candidate_port))
			continue
		considered++
		reset_free_reserve_docks_for(berth, spare_berth, FALSE, FALSE)
		adjust_reserve_dock_to_shuttle(berth, candidate_port)
		if(candidate_port.canDock(berth) != SHUTTLE_CAN_DOCK)
			continue
		best = candidate
		best_area = candidate_area

	reset_free_reserve_docks_for(berth, spare_berth, FALSE, FALSE)

	if(isnull(best) && considered)
		TEST_FAIL("[considered] crewless hull\s in the test fleet are small enough for a 56x40 reserve berth and not one of them passed \
			canDock() after adjust_reserve_dock_to_shuttle() re-faced it. That proc picks the berth's facing from an aspect-ratio guess \
			about the hull, and a hull whose preferred_direction disagrees with the guess cannot land anywhere in the game.")
	return best

/// TRUE if anything alive is standing on this hull.
/datum/unit_test/voidcrew_docking_cycle/proc/hull_has_living_aboard(obj/docking_port/mobile/voidcrew/port)
	for(var/turf/hull_turf as anything in port.return_turfs())
		if(isnull(hull_turf))
			continue
		var/mob/living/aboard = locate() in hull_turf
		if(aboard && !QDELETED(aboard))
			return TRUE
	return FALSE

/// A machine standing on one of the hull's own registered area tiles, used as the "did the
/// deck actually travel" witness. Machinery rather than any movable because every hull has
/// APCs and air alarms, and they are anchored, so nothing but the move can relocate them.
/datum/unit_test/voidcrew_docking_cycle/proc/find_hull_witness(obj/docking_port/mobile/voidcrew/port)
	for(var/turf/hull_turf as anything in port.return_turfs())
		if(isnull(hull_turf))
			continue
		if(!port.shuttle_areas[hull_turf.loc])
			continue
		var/obj/machinery/found = locate() in hull_turf
		if(found && !QDELETED(found))
			return found
	return null

/**
 * Puts the borrowed hull back on a transit dock, by whatever route is still available.
 *
 * Returns TRUE only when the hull is verifiably standing on one, which is the gate on
 * releasing the encounter afterwards.
 */
/datum/unit_test/voidcrew_docking_cycle/proc/bring_hull_home(obj/docking_port/mobile/voidcrew/port)
	if(isnull(port) || QDELETED(port))
		return TRUE // nothing borrowed is still standing anywhere
	if(istype(port.get_docked(), /obj/docking_port/stationary/transit))
		return TRUE
	if(isnull(port.assigned_transit))
		// The reservation was reclaimed while we were berthed. Ask for a new one directly
		// rather than through the requester queue, which only drains on an SSshuttle fire.
		SSshuttle.generate_transit_dock(port)
	if(isnull(port.assigned_transit))
		return FALSE
	port.enterTransit()
	return istype(port.get_docked(), /obj/docking_port/stationary/transit)

/**
 * No two live mobile ports share a shuttle_id.
 *
 * `SSshuttle.assoc_mobile` is a high-water mark rather than a refcount, deliberately never
 * decremented (see the VOIDCREW EDIT note in register()), because recycling a suffix mints a
 * live duplicate id - and linkup() resolves a duplicate by wiring the new hull's machinery to
 * the OLD hull's port. A cycle that re-registers a port is how that would start.
 */
/datum/unit_test/voidcrew_docking_cycle/proc/assert_no_duplicate_shuttle_ids()
	var/list/seen = list()
	for(var/obj/docking_port/mobile/other as anything in SSshuttle.mobile_docking_ports)
		if(isnull(other) || QDELETED(other) || !other.shuttle_id)
			continue
		if(seen[other.shuttle_id])
			TEST_FAIL("Two live mobile docking ports both answer to shuttle_id '[other.shuttle_id]'. linkup() wires machinery by id, so \
				one hull's consoles and engines are now attached to the other hull's port, and every log line naming that ship is \
				ambiguous for the rest of the round.")
			continue
		seen[other.shuttle_id] = TRUE

/// Tears one spawn_dynamic_encounter() result back down: berths by force (a non-forced qdel
/// on a docking port is a no-op), then the ground, then the slot. Same shape as
/// voidcrew_hull_containment.dm's, which is where the ordering is explained.
/datum/unit_test/voidcrew_docking_cycle/proc/release_encounter(list/encounter_values)
	if(length(encounter_values) < 4)
		return
	var/datum/map_zone/zone = encounter_values[1]
	var/datum/map_footprint/footprint = encounter_values[4]
	for(var/index in 2 to 3)
		var/obj/docking_port/stationary/berth = encounter_values[index]
		if(berth)
			qdel(berth, force = TRUE)
	if(!zone)
		return
	zone.clear_to_uninitialized_space(footprint)
	zone.release_slot(footprint)

/**
 * # Transit-dock lifecycle: who the reaper takes, and who it cannot see
 *
 * `SSshuttle.fire()` carries a reaper for transit docks, written inline in the subsystem and
 * reachable no other way. It makes two decisions per tick:
 *
 *  1. **Ownerless docks die, unconditionally.** `if(!T.owner) qdel(T, force = TRUE)`, ahead of
 *     every budget check. This is the whole content of the fork's "never create a transit dock
 *     pre-yield" rule: `generate_transit_dock()` is the only construction site in the repo and
 *     it assigns `owner` three non-yielding statements after the `new()`, so no tick can ever
 *     land between them. **There is no guard enforcing that** - no assert, no
 *     `Initialize()` owner check, nothing. It is a structural invariant held by exactly one
 *     call site, which is why it is asserted here as a property of the live register rather
 *     than as a property of a proc.
 *  2. **Past the soft budget, idle docks are reclaimed.** `owner.mode == SHUTTLE_IDLE` AND
 *     `owner.launch_status == NOLAUNCH` AND nothing standing on the dock. All three, and the
 *     budget gate above them, which is `SOFT_TRANSIT_RESERVATION_THRESHOLD` - `(200 ** 2)`,
 *     `#undef`'d at the bottom of its own file and therefore written as 40000 here.
 *
 * That second predicate is what the 2026-08-23 cargo fix (`6c6058ba618`) was about. The cargo
 * ferry is an ephemeral upstream-shaped shuttle: it sat at `SHUTTLE_IDLE`, carried the
 * upstream `NOLAUNCH` default, and docked to the customer's berth rather than to its own
 * transit port - so all three conditions held permanently and its parking ground was reclaimed
 * out from under it once the fleet pushed `transit_utilized` past the threshold. The fix does
 * not argue with the reaper: it stops handing it a target, holding the parking ground as a
 * BARE `/datum/turf_reservation` that never enters `SSshuttle.transit_docking_ports` at all.
 *
 * A voidcrew hull is spared the same predicate twice over, and both spares are one-line
 * overrides that an upstream merge could quietly drop: `mode` rests at `SHUTTLE_CALL` in open
 * flight (postregister()), and `/obj/docking_port/mobile/voidcrew` sets
 * `launch_status = UNLAUNCHED` against the upstream `NOLAUNCH` default.
 *
 * Everything below is driven by calling `SSshuttle.fire()` directly. That is the only way to
 * reach the reaper, and it is deterministic - a proc call, not a wait. Its blast radius is
 * one `check()` per registered mobile port (every one of them parked, `SHUTTLE_CALL` with an
 * infinite timer, so `check()` returns before its switch), `CheckAutoEvac()` (which returns on
 * an empty `joined_player_list`), and a drain of the transit requester queue.
 */
/datum/unit_test/voidcrew_transit_dock_lifecycle

/datum/unit_test/voidcrew_transit_dock_lifecycle/Run()
	assert_letmelive_contract()
	assert_every_transit_dock_is_owned()
	assert_reaper_predicate()
	assert_bare_reservation_is_invisible()
	assert_cargo_ferry_holds_bare_ground()

/**
 * A bare qdel() on a docking port is a no-op, and force is what makes it real.
 *
 * The sentinel for the single most expensive teardown mistake in this codebase:
 * /obj/docking_port/Destroy() answers an unforced qdel with QDEL_HINT_LETMELIVE, but only
 * AFTER the subtype destructors have run - so an unforced qdel on a mobile port leaves a live,
 * non-QDELETED port standing on the ground with a nulled shuttle_areas, and the next
 * load_template() over that block adopts it as its preview shuttle and deletes the real hull's
 * port as a duplicate.
 */
/datum/unit_test/voidcrew_transit_dock_lifecycle/proc/assert_letmelive_contract()
	var/obj/docking_port/stationary/doomed = new(null)
	qdel(doomed)
	if(QDELETED(doomed))
		TEST_FAIL("An unforced qdel() deleted a docking port. That reverses /obj/docking_port/Destroy()'s QDEL_HINT_LETMELIVE contract, \
			which every teardown in this fork is written against - berths and hull ports are force-qdel'd precisely because a bare qdel \
			was supposed to be inert.")
		return
	qdel(doomed, force = TRUE)
	if(!QDELETED(doomed))
		TEST_FAIL("A forced qdel() did not delete a docking port. Every berth, transit dock and hull port in the fork is torn down this \
			way; nothing can be released at all if force stops working.")

/**
 * Every transit dock alive right now has an owner, and that owner points back at it.
 *
 * An ownerless one is not a leak that accumulates - it is a dock that dies on the next
 * SSshuttle fire, taking its turf reservation with it. Whoever was about to adopt it is then
 * holding a deleted port in `assigned_transit`, which is a shuttle that can never enter
 * transit again: check_transit_zone() sees a non-null assigned_transit and reports
 * TRANSIT_READY without ever asking for a new one.
 */
/datum/unit_test/voidcrew_transit_dock_lifecycle/proc/assert_every_transit_dock_is_owned()
	for(var/obj/docking_port/stationary/transit/dock as anything in SSshuttle.transit_docking_ports)
		if(!istype(dock) || QDELETED(dock))
			continue
		if(isnull(dock.owner))
			TEST_FAIL("[dock] is registered in SSshuttle.transit_docking_ports with no owner. SSshuttle.fire() force-qdels it on the very \
				next tick, ahead of every budget check - so something built a transit dock before it had an owner to give it, which the \
				fork's one construction site (generate_transit_dock()) is written specifically to never do.")
			continue
		if(dock.owner.assigned_transit != dock)
			TEST_FAIL("[dock] claims [dock.owner] as its owner, but that port's assigned_transit is [dock.owner.assigned_transit || "null"]. \
				A one-way link means the reaper's 'is anyone using this' answer and the shuttle's 'do I have transit' answer disagree.")

/**
 * The reaper's three spare conditions, isolated one at a time on a real transit dock.
 *
 * A probe port stands in for the ephemeral shuttle: a plain /obj/docking_port/mobile carries
 * the upstream defaults the cargo ferry carried - SHUTTLE_IDLE and NOLAUNCH - and it is not
 * standing on its own transit dock, which is the state a shuttle is in whenever it is docked
 * somewhere else. That is the reaped-by-construction case the 08-23 fix was written for.
 */
/datum/unit_test/voidcrew_transit_dock_lifecycle/proc/assert_reaper_predicate()
	// `list()` for areas: truthy, so Initialize() skips the turf scan that would register
	// whatever this port is standing on top of.
	//
	// Deliberately NOT register()ed. SSshuttle.fire() runs check() over every registered
	// mobile port BEFORE it reaches the transit sweep, and check() on a port with an expired
	// timer falls through its switch to `mode = SHUTTLE_IDLE` - so a registered probe would
	// have the mode this test sets wiped in the same tick that is supposed to read it. A real
	// voidcrew hull is not affected: postregister() parks it at SHUTTLE_CALL with an INFINITE
	// timer, and check() returns before its switch while the timer has not expired. The
	// unregistered probe isolates the sweep from check(); it costs one "unregistered multiple
	// times" line in world.log from unregister(), which is a log_world, not a runtime.
	var/obj/docking_port/mobile/probe = new(run_loc_floor_bottom_left, list())
	probe.width = 3
	probe.height = 3
	probe.dwidth = 1
	probe.dheight = 1
	probe.preferred_direction = NORTH
	probe.port_direction = NORTH

	// SOFT_TRANSIT_RESERVATION_THRESHOLD is (200 ** 2) and #undef'd inside
	// code/controllers/subsystem/shuttle.dm. Nudged by a DELTA, never assigned outright:
	// transit_utilized is live accounting that the reaper itself decrements through the
	// reservation's COMSIG_QDELETING handler, and clobbering it would corrupt the budget for
	// the rest of the run.
	var/inflation = 0
	if(SSshuttle.transit_utilized <= 40000)
		inflation = 40001 - SSshuttle.transit_utilized
		SSshuttle.transit_utilized += inflation

	// --- Reaped: idle, NOLAUNCH, nothing standing on it -------------------------------
	var/obj/docking_port/stationary/transit/dock = SSshuttle.generate_transit_dock(probe)
	if(!istype(dock))
		TEST_FAIL("generate_transit_dock() could not build a transit dock for a 3x3 probe port. Nothing below is under test; if the \
			global transit budget or the reservation allocator is exhausted this is a capacity condition, not this test's subject.")
		SSshuttle.transit_utilized -= inflation
		qdel(probe, force = TRUE)
		return

	if(probe.assigned_transit != dock)
		TEST_FAIL("generate_transit_dock() did not wire the new dock into the requesting port's assigned_transit")
	if(!(dock in SSshuttle.transit_docking_ports))
		TEST_FAIL("A freshly generated transit dock is not registered in SSshuttle.transit_docking_ports - the reaper cannot see it, and \
			neither can anything else that accounts for hyperspace")
	if(!isnull(dock.get_docked()))
		TEST_FAIL("The probe port is standing on its own transit dock, so the 'not in use' arm of the reaper predicate is satisfied for \
			the wrong reason and the reap below would prove nothing")
	if(probe.mode != SHUTTLE_IDLE)
		TEST_FAIL("A plain /obj/docking_port/mobile no longer rests at SHUTTLE_IDLE (it is [probe.mode]). The reaper's first condition is \
			written against that default; if it changed, every ephemeral shuttle in the codebase just changed reaping class.")
	if(probe.launch_status != NOLAUNCH)
		TEST_FAIL("A plain /obj/docking_port/mobile no longer defaults to launch_status NOLAUNCH (it is [probe.launch_status]). That \
			default is the reaper's second condition and the reason /obj/docking_port/mobile/voidcrew overrides it.")

	pump_shuttle_sweep()

	if(!QDELETED(dock))
		TEST_FAIL("SSshuttle.fire() spared a transit dock whose owner is SHUTTLE_IDLE, NOLAUNCH and standing somewhere else, with \
			transit_utilized past the soft threshold. That predicate firing is the entire premise of the 2026-08-23 cargo shuttle fix - \
			if it no longer fires, the fix is now guarding nothing and the next ephemeral shuttle will be written to hold a transit dock \
			again.")
		qdel(dock, force = TRUE)
	if(!isnull(probe.assigned_transit))
		TEST_FAIL("A reaped transit dock left its owner holding [probe.assigned_transit] in assigned_transit. check_transit_zone() reads \
			that field alone, so the shuttle reports TRANSIT_READY forever and never asks for replacement ground.")
		probe.assigned_transit = null

	// --- Spared by launch_status alone ------------------------------------------------
	dock = SSshuttle.generate_transit_dock(probe)
	if(istype(dock))
		probe.launch_status = UNLAUNCHED // the value /obj/docking_port/mobile/voidcrew sets
		pump_shuttle_sweep()
		if(QDELETED(dock))
			TEST_FAIL("A transit dock whose owner is idle but carries launch_status UNLAUNCHED was reaped. That override is what keeps a \
				DOCKED voidcrew hull's reservation alive - lose it and every berthed ship has its transit ground reclaimed, enterTransit() \
				has nowhere to move to, and the undock stalls with the crew aboard.")
		probe.launch_status = NOLAUNCH

	// --- Spared by mode alone ---------------------------------------------------------
	if(!QDELETED(dock))
		probe.mode = SHUTTLE_CALL // a voidcrew hull's resting state in open flight
		pump_shuttle_sweep()
		if(QDELETED(dock))
			TEST_FAIL("A transit dock whose owner is NOLAUNCH but sitting at SHUTTLE_CALL was reaped. SHUTTLE_CALL is where postregister() \
				parks every voidcrew hull, and it is the second of the two independent reasons a fork ship keeps its reservation.")
		probe.mode = SHUTTLE_IDLE

	// --- Reaped when ownerless, budget or no budget -----------------------------------
	if(!QDELETED(dock))
		// Back below the soft threshold first, so the only branch that can act is the
		// unconditional ownerless one at the top of the sweep.
		SSshuttle.transit_utilized -= inflation
		inflation = 0
		dock.owner = null
		pump_shuttle_sweep()
		if(!QDELETED(dock))
			TEST_FAIL("SSshuttle.fire() spared an OWNERLESS transit dock. That reap is unconditional and runs ahead of the budget gate; it \
				is the only thing enforcing the fork's 'never create a transit dock before you can own it' rule, which has no other guard \
				anywhere in the codebase.")
			qdel(dock, force = TRUE)
		// Destroy() only clears the owner's back-reference from inside `if(owner)`, and we
		// just nulled it - so this is exactly the dangling ref a pre-yield creation leaves.
		probe.assigned_transit = null

	SSshuttle.transit_utilized -= inflation
	qdel(probe, force = TRUE)

/**
 * A bare turf reservation - the shape the cargo ferry was rewritten onto - is not visible to
 * the reaper at all.
 *
 * This is the regression test for the 2026-08-23 fix, stated as the property the fix actually
 * created. Before it, the ferry's parking ground was wrapped in an
 * /obj/docking_port/stationary/transit and therefore lived in SSshuttle.transit_docking_ports,
 * where the predicate above could reach it; afterwards the reservation is held bare on the
 * cargo datum and there is no transit dock to reap. Nothing in SSshuttle.fire() touches a
 * reservation nobody handed it.
 */
/datum/unit_test/voidcrew_transit_dock_lifecycle/proc/assert_bare_reservation_is_invisible()
	var/datum/turf_reservation/bare = SSmapping.request_turf_block_reservation(
		10,
		10,
		1,
		reservation_type = /datum/turf_reservation/transit,
	)
	if(isnull(bare))
		TEST_FAIL("Could not reserve a 10x10 transit block, so the bare-reservation parking ground the cargo ferry now uses cannot be \
			exercised. This is reservation capacity, not the subject of the test.")
		return

	var/turfs_before = length(bare.reserved_turfs)
	if(!turfs_before)
		TEST_FAIL("A granted turf reservation holds no turfs")

	for(var/obj/docking_port/stationary/transit/dock as anything in SSshuttle.transit_docking_ports)
		if(!istype(dock) || QDELETED(dock))
			continue
		if(dock.reserved_area == bare)
			TEST_FAIL("Reserving a block directly minted a transit DOCK over it. The cargo ferry's whole fix is that its parking ground \
				is not wrapped in one - a dock puts the ground inside SSshuttle.transit_docking_ports, where the idle-owner predicate \
				reclaims it out from under the shuttle standing there.")

	// Past the soft threshold, which is where the reaper starts reclaiming ground at all.
	var/inflation = 0
	if(SSshuttle.transit_utilized <= 40000)
		inflation = 40001 - SSshuttle.transit_utilized
		SSshuttle.transit_utilized += inflation

	pump_shuttle_sweep()

	SSshuttle.transit_utilized -= inflation

	if(QDELETED(bare))
		TEST_FAIL("SSshuttle.fire() released a bare turf reservation. Nothing in the subsystem is supposed to be able to reach one - if \
			it can, the cargo ferry is back to having its ground pulled out mid-delivery and the fix has been undone from the other side.")
		return
	if(length(bare.reserved_turfs) != turfs_before)
		TEST_FAIL("A bare reservation lost turfs across SSshuttle sweeps ([turfs_before] -> [length(bare.reserved_turfs)])")

	qdel(bare)

/**
 * The cargo ferry still parks on bare ground, not on a transit dock.
 *
 * A type-level pin on the 08-23 fix's shape, because the failure it guards against is a
 * REVERT - somebody restoring the `transit_dock` var because the surrounding code reads as
 * though a transit dock is the normal way to hold parking ground. It is cheap (the datum has
 * no constructor) and it names the commit that changed it.
 */
/datum/unit_test/voidcrew_transit_dock_lifecycle/proc/assert_cargo_ferry_holds_bare_ground()
	var/datum/voidcrew_cargo_shuttle/ferry = new
	if("transit_dock" in ferry.vars)
		TEST_FAIL("/datum/voidcrew_cargo_shuttle has a transit_dock var again. The 2026-08-23 fix removed it because a transit dock puts \
			the ferry's parking ground inside SSshuttle.transit_docking_ports, where the idle-owner predicate force-qdels it the moment \
			the fleet pushes transit_utilized past the soft threshold - the ferry is idle, NOLAUNCH and docked at the customer's berth, \
			so all three conditions hold permanently.")
	if(!("transit_reservation" in ferry.vars))
		TEST_FAIL("/datum/voidcrew_cargo_shuttle no longer holds its parking ground as a bare turf_reservation. That field IS the fix; \
			without it the ground is either wrapped in a reapable transit dock or not held at all.")
	qdel(ferry)

/// Runs the subsystem's own sweep a bounded number of times.
///
/// More than one pass on purpose: the reaper iterates SSshuttle.transit_docking_ports while
/// /obj/docking_port/stationary/transit/Destroy(force) removes entries from that same list, so
/// a pass that reaps an element skips the one after it. Four passes is a bound, not a wait -
/// nothing here depends on the subsystem being scheduled.
/datum/unit_test/voidcrew_transit_dock_lifecycle/proc/pump_shuttle_sweep(cycles = 4)
	for(var/pass in 1 to cycles)
		SSshuttle.fire()
