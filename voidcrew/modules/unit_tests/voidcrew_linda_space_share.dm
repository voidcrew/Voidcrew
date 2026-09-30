/**
 * A floor venting into space when its space neighbour already ran this LINDA cycle, and no
 * other neighbour grouped with it, still vents under an excited group. process_cell() used to
 * read a null group there ("Cannot execute null.reset cooldowns()"), which shuttle moves and
 * turf wipes reach by opening or regrouping turfs while SSair is paused mid-cycle.
 * LINDA is driven by hand with process_cell(); Run() never sleeps.
 */
/datum/unit_test/voidcrew_linda_space_share
	/// The room floor turned into space for the test, put back in Destroy()
	var/turf/space_spot
	var/space_spot_type

/datum/unit_test/voidcrew_linda_space_share/Destroy()
	var/turf/open/floor = run_loc_floor_bottom_left
	floor.excited_group?.garbage_collect()
	SSair.high_pressure_delta -= floor
	floor.pressure_difference = 0
	if(space_spot && space_spot_type)
		var/turf/restored = space_spot.ChangeTurf(space_spot_type, flags = CHANGETURF_IGNORE_AIR | CHANGETURF_RECALC_ADJACENT)
		restored?.air_update_turf(update = FALSE, remove = FALSE)
	space_spot = null
	return ..()

/datum/unit_test/voidcrew_linda_space_share/Run()
	var/turf/open/floor = run_loc_floor_bottom_left
	var/turf/open/north = get_step(floor, NORTH)
	var/turf/east = get_step(floor, EAST)
	TEST_ASSERT(isopenturf(north) && isopenturf(east), "the test room's corner has no open turfs beside it")
	space_spot_type = east.type
	space_spot = east.ChangeTurf(/turf/open/space, flags = CHANGETURF_IGNORE_AIR | CHANGETURF_RECALC_ADJACENT)
	var/turf/open/space/void = space_spot
	TEST_ASSERT(istype(void), "the corner's neighbour did not become space")
	TEST_ASSERT(floor.atmos_adjacent_turfs?[void], "the floor does not share air with the space beside it")
	floor.copy_air(SSair.parse_gas_string(floor.initial_gas_mix, /datum/gas_mixture/turf))
	var/moles_before = floor.air.total_moles()
	TEST_ASSERT(moles_before > 0, "the floor holds no air to vent")
	floor.excited_group?.garbage_collect()

	// The space and the floor's only other neighbour already ran this cycle, so neither grouped with it.
	SSair.times_fired += 1
	var/cycle = SSair.times_fired
	void.current_cycle = cycle
	north.current_cycle = cycle
	floor.process_cell(cycle)

	TEST_ASSERT_NOTNULL(floor.excited_group, "a floor venting into space was left without an excited group")
	TEST_ASSERT(floor.air.total_moles() < moles_before, "the floor did not vent into the space beside it")
