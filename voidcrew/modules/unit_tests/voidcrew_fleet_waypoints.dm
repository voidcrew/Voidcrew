/**
 * # Fleet-beacon conformance
 *
 * A handful of sites chart themselves onto every helm in the galaxy the moment
 * they surface: the Verdigris, the Grand Colosseum, a contested cache. Each of
 * them used to do that by walking `SSovermap.simulated_ships` once and pushing a
 * waypoint per ship, which is correct for exactly as long as the fleet does not
 * change. Every hull built afterwards (a mid-round requisition, a commissioned
 * vessel, a respawn into a fresh ship) came up with an empty Events list for a
 * site the rest of the fleet had been staring at for twenty minutes, and the
 * crew had no way to tell they were missing anything.
 *
 * The fix was to make the push repeatable, `broadcast_fleet_waypoint()`
 * registers the site in `GLOB.overmap_fleet_beacons`, and a new ship collects
 * from that register as it joins `simulated_ships`. This test guards the shape
 * rather than the behaviour, because a CIBUILDING world boots MetaStation and
 * has no overmap to fly (see voidcrew_helpers.dm's header):
 *
 * - **Nobody fans a waypoint out over `simulated_ships` by hand.** That loop is
 *   the bug. It is invisible in review, invisible in play until someone builds a
 *   ship late, and there is now a one-line replacement for it.
 * - **A site that broadcasts declares what to call itself.** Without
 *   `fleet_waypoint_name` the broadcast CRASHes at surface time, which is a
 *   round-event that silently does not happen.
 */

/// Source root holding every site that could broadcast to the fleet.
#define FLEET_BEACON_SOURCE_ROOT "voidcrew/"

/// How far past a `for(... simulated_ships)` header to look for the fan-out.
#define FLEET_BEACON_LOOP_LOOKAHEAD 5

/datum/unit_test/fleet_waypoint_broadcast
	priority = TEST_LONGER

/datum/unit_test/fleet_waypoint_broadcast/Run()
	var/list/sources = list()
	vc_test_collect_dm_files(FLEET_BEACON_SOURCE_ROOT, sources)
	TEST_ASSERT(length(sources) > 100, "the fleet-beacon source scan found only [length(sources)] .dm files under [FLEET_BEACON_SOURCE_ROOT], wrong root?")

	var/broadcasters = 0
	for(var/file_path in sources)
		var/text = sources[file_path]

		if(findtext(text, "broadcast_fleet_waypoint("))
			broadcasters++
			// The name is what the helm entry reads, and its absence is what
			// broadcast_fleet_waypoint() refuses on.
			if(!findtext(text, "fleet_waypoint_name"))
				TEST_FAIL("[file_path] calls broadcast_fleet_waypoint() but never sets fleet_waypoint_name, so the broadcast CRASHes and the site surfaces with nothing on any helm")

		var/list/lines = splittext(text, "\n")
		for(var/index in 1 to length(lines))
			var/line = lines[index]
			if(!findtext(line, "for(") || !findtext(line, "SSovermap.simulated_ships"))
				continue
			for(var/scan in (index + 1) to min(index + FLEET_BEACON_LOOP_LOOKAHEAD, length(lines)))
				if(!findtext(lines[scan], "add_waypoint("))
					continue
				TEST_FAIL("[file_path]:[scan] pushes a waypoint inside a loop over SSovermap.simulated_ships. That charts the fleet as it stands right now and never again, so every ship built later (a mid-round hull requisition, a commissioned vessel, a respawn) comes up blind to this site. Set fleet_waypoint_name and call broadcast_fleet_waypoint() instead (voidcrew/modules/overmap/code/modules/overmap/ship_waypoints.dm).")
				break

	TEST_ASSERT(broadcasters >= 3, "only [broadcasters] file(s) call broadcast_fleet_waypoint(), expected at least the Verdigris, the Colosseum and the contested cache. A scan that matches nothing passes vacuously.")

	// The three shipped sites, checked against the live type table rather than
	// the source text: a rename that misses one is otherwise a clean pass.
	var/list/known_beacons = list(
		/obj/structure/overmap/space_ruin/lich_lair,
		/obj/structure/overmap/colosseum,
		/obj/structure/overmap/space_ruin/contested_cache,
	)
	for(var/obj/structure/overmap/beacon_type as anything in known_beacons)
		if(!initial(beacon_type.fleet_waypoint_name))
			TEST_FAIL("[beacon_type] broadcasts itself to the galaxy but declares no fleet_waypoint_name")

#undef FLEET_BEACON_SOURCE_ROOT
#undef FLEET_BEACON_LOOP_LOOKAHEAD
