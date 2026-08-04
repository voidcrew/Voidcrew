/**
 * # Breaking a wall must not conjure air
 *
 * A closed turf holds no gas, so the mix a freshly revealed floor rolls off its
 * initial_gas_mix is invented out of nothing. Assimilate_Air() is supposed to reconcile
 * that against the surroundings, but it runs before the new turf has an adjacency list,
 * so it used to early-return and leave the invented atmosphere in place. The result was
 * a full tile of breathable air per dismantled wall - free pressure for anyone willing
 * to swing a pickaxe at a depressurised hull.
 *
 * The test room is /turf/open/floor/iron, which bottoms out at /turf/open/floor/plating,
 * which takes /turf's default OPENTURF_DEFAULT_ATMOS. That is what makes the vacuum half
 * of this test meaningful - the revealed turf really does want to hold 104 moles.
 */
/datum/unit_test/voidcrew_wall_break_atmos

/// Total moles held by every open turf in the 3x3 around `center`. Assimilate_Air() only
/// reaches our cardinal neighbours, so nothing it does can escape this window.
/datum/unit_test/voidcrew_wall_break_atmos/proc/moles_around(turf/center)
	var/total = 0
	for(var/turf/open/nearby in RANGE_TURFS(1, center))
		if(nearby.air)
			total += nearby.air.total_moles()
	return total

/datum/unit_test/voidcrew_wall_break_atmos/Run()
	var/turf/site = run_loc_floor_bottom_left
	var/original_type = site.type
	var/list/original_baseturfs = site.baseturfs

	// A wall in a depressurised section. Breaking it in must not hand anyone a breath.
	site.ChangeTurf(/turf/closed/wall)
	var/turf/closed/wall/vacuum_wall = site
	TEST_ASSERT(istype(vacuum_wall), "could not build a test wall, got [site.type]")

	for(var/turf/open/nearby in RANGE_TURFS(1, vacuum_wall))
		nearby.air?.remove_ratio(1)
		nearby.air_update_turf(FALSE, FALSE)
	TEST_ASSERT_EQUAL(round(moles_around(vacuum_wall), 0.01), 0, "failed to evacuate the test site before breaking the wall")

	vacuum_wall.dismantle_wall()
	var/turf/open/vented = site
	TEST_ASSERT(isopenturf(vented), "dismantling the wall did not leave an open turf, got [site.type]")
	TEST_ASSERT(vented.air.total_moles() < 0.01, "breaking a wall in a vacuum conjured [vented.air.total_moles()] moles at [vented.air.return_pressure()] kPa")

	// And in a pressurised room the opened tile has to take a share of what is already
	// there rather than adding a tile's worth of its own.
	site.ChangeTurf(original_type, original_baseturfs)
	restore_atmos()

	site.ChangeTurf(/turf/closed/wall)
	var/turf/closed/wall/room_wall = site
	TEST_ASSERT(istype(room_wall), "could not rebuild the test wall, got [site.type]")

	var/moles_before = moles_around(room_wall)
	TEST_ASSERT(moles_before > 0, "the test room held no air, so this half of the test proves nothing")

	room_wall.dismantle_wall()
	var/moles_after = moles_around(site)
	TEST_ASSERT(moles_after <= moles_before + 0.01, "breaking a wall created [moles_after - moles_before] moles of gas out of nothing")

	site.ChangeTurf(original_type, original_baseturfs)
	restore_atmos()
