/**
 * # An assault pod cuts a doorway, not a tunnel
 *
 * The whole point of a boarding pod is that the people inside it come out the
 * other side of the hull, so `breach_hull()` has two jobs that pull against each
 * other: open enough plating that the pod is never entombed, and stop soon
 * enough that one pod isn't a free three-tile hole into somebody's engine room.
 *
 * The failure modes are silent - a pod that lands inside a wall just sits there
 * with its riders in it, and a pod that chews too deep only looks like "the hull
 * was already weak". Both are worth pinning down.
 *
 * The test flies pods EAST from the bottom-left of the test room, which has four
 * open tiles that way before the indestructible border.
 *
 * `normal_floor_required` because the test builds hull plating out of the test room's
 * own floor and then asks a pod to cut through it. The room's floor is
 * `/turf/open/indestructible`, which is not a `/turf/open/floor` at all and cannot be
 * torn up; the flag has the harness swap the whole room to real plating for the run and
 * put it back afterwards. Upstream added both the indestructible floor and this opt-in
 * in the same pass, so a fork test written against the old iron-floor room needs the flag.
 */
/datum/unit_test/voidcrew_assault_pod_breach
	normal_floor_required = TRUE
	/// Turfs we converted to walls, so they can be put back as we found them
	var/list/turf/dirtied = list()
	/// Original type of each dirtied turf, parallel to `dirtied`
	var/list/original_types = list()
	/// Original baseturfs of each dirtied turf, parallel to `dirtied`
	var/list/original_baseturfs = list()

/// Builds a wall at `site`, remembering what was there so Run() can restore it
/datum/unit_test/voidcrew_assault_pod_breach/proc/build_wall(turf/site, indestructible = FALSE)
	dirtied += site
	original_types += site.type
	original_baseturfs += list(site.baseturfs)
	site.ChangeTurf(/turf/closed/wall)
	if(indestructible)
		site.resistance_flags |= INDESTRUCTIBLE
	return site

/// Puts every turf this test converted back the way it was
/datum/unit_test/voidcrew_assault_pod_breach/proc/restore_walls()
	for(var/index in 1 to length(dirtied))
		var/turf/site = dirtied[index]
		site.resistance_flags &= ~INDESTRUCTIBLE
		site.ChangeTurf(original_types[index], original_baseturfs[index])
	dirtied.Cut()
	original_types.Cut()
	original_baseturfs.Cut()

/**
 * A pod parked on `where` and pointed east, with no target and no ship.
 *
 * Passing a null target keeps the parent from starting a move loop, so the
 * effect sits still and only the breach logic is under test.
 */
/datum/unit_test/voidcrew_assault_pod_breach/proc/make_pod(turf/where)
	var/obj/effect/ship_missile/assault_pod/flier = new(where, null, null, null)
	flier.travel_dir = EAST
	return flier

/datum/unit_test/voidcrew_assault_pod_breach/Run()
	var/turf/launch_site = run_loc_floor_bottom_left
	var/turf/first = get_step(launch_site, EAST)
	var/turf/second = get_step(first, EAST)
	var/turf/third = get_step(second, EAST)
	TEST_ASSERT(isfloorturf(third), "[third] is not plating the pod could cut: either the test room has shrunk east of the landmark, or normal_floor_required stopped swapping the room's indestructible floor for real plating")

	// Single hull plate: the hole opens and the pod ends up on the far side of it
	var/turf/hull = build_wall(first)
	var/obj/effect/ship_missile/assault_pod/flier = make_pod(launch_site)
	var/turf/landing = flier.breach_hull(hull)
	TEST_ASSERT_EQUAL(landing, second, "a pod that hit a single wall came to rest on [landing] instead of the tile behind the wall")
	TEST_ASSERT(isopenturf(first), "the wall the pod hit is still closed ([first.type])")
	qdel(flier)
	restore_walls()

	// Double hull: still gets through, because two plates is a normal ship wall
	build_wall(first)
	build_wall(second)
	flier = make_pod(launch_site)
	landing = flier.breach_hull(first)
	TEST_ASSERT_EQUAL(landing, third, "a pod that hit a double wall came to rest on [landing] instead of the tile behind both plates")
	TEST_ASSERT(isopenturf(first) && isopenturf(second), "a double wall was not fully opened ([first.type], [second.type])")
	qdel(flier)
	restore_walls()

	// Three deep is past the bite limit: the pod stops in the hole it made rather
	// than boring on through the ship, and it never ends up inside a wall
	build_wall(first)
	build_wall(second)
	build_wall(third)
	flier = make_pod(launch_site)
	landing = flier.breach_hull(first)
	TEST_ASSERT(isclosedturf(third), "a pod chewed past its breach depth and opened [third]")
	TEST_ASSERT(!flier.is_pod_blocked(landing), "a pod stopped on a blocked tile ([landing.type]) and would have entombed its riders")
	qdel(flier)
	restore_walls()

	// Armour it can't cut: the pod stops on the outside face, hull intact
	build_wall(first, indestructible = TRUE)
	flier = make_pod(launch_site)
	landing = flier.breach_hull(first)
	TEST_ASSERT(isclosedturf(first), "an indestructible hull was breached by an assault pod")
	TEST_ASSERT_EQUAL(landing, launch_site, "a pod stopped by armour came to rest on [landing] instead of backing off to open space")
	qdel(flier)
	restore_walls()
