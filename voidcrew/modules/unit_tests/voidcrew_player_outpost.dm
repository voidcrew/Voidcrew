/**
 * A purchased outpost owns one level: construction and powered-area adoption reach the whole
 * build region beyond the starter shell, and stop at the cordon round the berth, bay, shipyard
 * and ferry zones (outpost_level_layout.dm).
 */
/datum/unit_test/voidcrew_player_outpost

/datum/unit_test/voidcrew_player_outpost/Run()
	var/datum/map_template/player_outpost/shell = allocate(/datum/map_template/player_outpost/test_fixture)
	var/obj/structure/overmap/dynamic/player_outpost/outpost = allocate(/obj/structure/overmap/dynamic/player_outpost)
	outpost.shell_template = shell
	TEST_ASSERT(outpost.load_level(), "Could not load the purchased outpost")
	TEST_ASSERT_NOTNULL(outpost.outpost_area, "The outpost has no powered area")
	var/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/builder = outpost.construction_console
	TEST_ASSERT_NOTNULL(builder, "The starter construction console did not link to its outpost")
	var/site_z = outpost.template_bottom_left.z

	var/list/region = outpost_level_layout()["build"]
	TEST_ASSERT_EQUAL(outpost.build_bounds.Join(","), region.Join(","), "The claim is not the layout's build region")
	TEST_ASSERT_NULL(outpost.reserve_dock, "The outpost kept a reserve landing pad")
	TEST_ASSERT_NULL(outpost.reserve_dock_secondary, "The outpost kept its second reserve landing pad")

	// Every corner of the build region is reachable; the tile diagonally past it is not.
	for(var/corner_x in list(region[1], region[3]))
		for(var/corner_y in list(region[2], region[4]))
			var/turf/corner = locate(corner_x, corner_y, site_z)
			TEST_ASSERT(builder.can_move_to(corner), "The drone cannot reach corner ([corner_x],[corner_y])")
			TEST_ASSERT(builder.can_build_at(corner), "Construction is blocked at corner ([corner_x],[corner_y])")
			TEST_ASSERT(builder.check_expansion_dimensions(corner, null), "Expansion is blocked at corner ([corner_x],[corner_y])")
			var/turf/past = locate(corner_x + (corner_x == region[1] ? -1 : 1), corner_y + (corner_y == region[2] ? -1 : 1), site_z)
			TEST_ASSERT(!builder.can_move_to(past), "The drone left the claim at ([past.x],[past.y])")
			TEST_ASSERT(!builder.can_build_at(past), "Construction is allowed outside the claim at ([past.x],[past.y])")
			TEST_ASSERT(istype(past, /turf/cordon), "The claim's edge at ([past.x],[past.y]) is [past.type], not cordon")
	TEST_ASSERT(!builder.can_build_at(run_loc_floor_bottom_left), "The outpost allows construction on another z-level")

	// The shell sits wholly inside the build region.
	var/turf/shell_top_right = locate(outpost.template_bottom_left.x + shell.width - 1, outpost.template_bottom_left.y + shell.height - 1, site_z)
	TEST_ASSERT(outpost.is_turf_buildable(outpost.template_bottom_left) && outpost.is_turf_buildable(shell_top_right), "The shell was loaded outside the build region")

	// Hand-built rooms far from the shell still join APC coverage.
	var/turf/distant_floor = locate(region[1] + 2, region[4] - 2, site_z)
	distant_floor = distant_floor.ChangeTurf(/turf/open/floor/plating)
	outpost.adopt_built_turfs()
	TEST_ASSERT_EQUAL(get_area(distant_floor), outpost.outpost_area, "A distant hand-built floor was not adopted into the outpost area")

	// Ordinary targets with space around them retain the existing ten-tile missile approach.
	var/obj/machinery/ship_combat/mount = allocate(/obj/machinery/ship_combat)
	var/turf/ordinary_target = locate(64, 64, site_z)
	TEST_ASSERT_EQUAL(mount.get_missile_spawn_turf(ordinary_target, null, NORTH), locate(64, 74, site_z), "An ordinary target's north approach changed")
	TEST_ASSERT_EQUAL(mount.get_missile_spawn_turf(ordinary_target, null, SOUTH), locate(64, 54, site_z), "An ordinary target's south approach changed")
	TEST_ASSERT_EQUAL(mount.get_missile_spawn_turf(ordinary_target, null, EAST), locate(74, 64, site_z), "An ordinary target's east approach changed")
	TEST_ASSERT_EQUAL(mount.get_missile_spawn_turf(ordinary_target, null, WEST), locate(54, 64, site_z), "An ordinary target's west approach changed")
