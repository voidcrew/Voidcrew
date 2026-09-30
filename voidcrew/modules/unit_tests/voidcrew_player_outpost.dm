/**
 * A purchased outpost owns its whole level: construction and powered-area adoption
 * must reach beyond the starter shell, and incoming shots must still enter from an edge.
 */
/datum/unit_test/voidcrew_player_outpost

/datum/unit_test/voidcrew_player_outpost/Run()
	var/datum/map_template/player_outpost/shell = allocate(/datum/map_template/player_outpost/small)
	var/obj/structure/overmap/dynamic/player_outpost/outpost = allocate(/obj/structure/overmap/dynamic/player_outpost)
	outpost.shell_template = shell
	TEST_ASSERT(outpost.load_level(), "Could not load the purchased outpost")
	TEST_ASSERT_NOTNULL(outpost.outpost_area, "The outpost has no powered area")
	var/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/builder = outpost.construction_console
	TEST_ASSERT_NOTNULL(builder, "The starter construction console did not link to its outpost")
	var/site_z = outpost.template_bottom_left.z

	// Every corner must be reachable, including the former dock-row exclusion.
	for(var/corner_x in list(1, world.maxx))
		for(var/corner_y in list(1, world.maxy))
			var/turf/corner = locate(corner_x, corner_y, site_z)
			TEST_ASSERT(builder.can_move_to(corner), "The drone cannot reach corner ([corner_x],[corner_y])")
			TEST_ASSERT(builder.can_build_at(corner), "Construction is blocked at corner ([corner_x],[corner_y])")
			TEST_ASSERT(builder.check_expansion_dimensions(corner, null), "Expansion is blocked at corner ([corner_x],[corner_y])")
	TEST_ASSERT(!builder.can_build_at(run_loc_floor_bottom_left), "The outpost allows construction on another z-level")

	// Hand-built rooms far outside the old 15-tile margin still join APC coverage.
	var/turf/distant_floor = locate(5, world.maxy - 5, site_z)
	distant_floor = distant_floor.ChangeTurf(/turf/open/floor/plating)
	outpost.adopt_built_turfs()
	TEST_ASSERT_EQUAL(get_area(distant_floor), outpost.outpost_area, "A distant hand-built floor was not adopted into the outpost area")

	var/obj/machinery/ship_combat/mount = allocate(/obj/machinery/ship_combat)
	var/turf/target = outpost.arrival_turf
	TEST_ASSERT_NOTNULL(target, "The outpost has no arrival turf to target")
	for(var/approach in GLOB.cardinals)
		var/turf/entry_turf = mount.get_missile_spawn_turf(target, outpost, approach)
		TEST_ASSERT_NOTNULL(entry_turf, "A shot approaching from [dir2text(approach)] would spawn outside the world")
		TEST_ASSERT_EQUAL(entry_turf.z, site_z, "The shot would spawn on the wrong z-level")
		switch(approach)
			if(NORTH)
				TEST_ASSERT_EQUAL(entry_turf.y, world.maxy, "An approach from the north must enter at the north edge")
			if(SOUTH)
				TEST_ASSERT_EQUAL(entry_turf.y, 1, "An approach from the south must enter at the south edge")
			if(EAST)
				TEST_ASSERT_EQUAL(entry_turf.x, world.maxx, "An approach from the east must enter at the east edge")
			if(WEST)
				TEST_ASSERT_EQUAL(entry_turf.x, 1, "An approach from the west must enter at the west edge")

	var/turf/automatic_spawn = mount.get_missile_spawn_turf(target, outpost)
	TEST_ASSERT_NOTNULL(automatic_spawn, "Automatic approach selection could not find a map edge")
	TEST_ASSERT(automatic_spawn.x == 1 || automatic_spawn.x == world.maxx || automatic_spawn.y == 1 || automatic_spawn.y == world.maxy, "Automatic approach selection spawned a shot inside the outpost")

	// Ordinary targets with space around them retain the existing ten-tile approach.
	var/turf/ordinary_target = locate(64, 64, site_z)
	TEST_ASSERT_EQUAL(mount.get_missile_spawn_turf(ordinary_target, null, NORTH), locate(64, 74, site_z), "An ordinary target's north approach changed")
	TEST_ASSERT_EQUAL(mount.get_missile_spawn_turf(ordinary_target, null, SOUTH), locate(64, 54, site_z), "An ordinary target's south approach changed")
	TEST_ASSERT_EQUAL(mount.get_missile_spawn_turf(ordinary_target, null, EAST), locate(74, 64, site_z), "An ordinary target's east approach changed")
	TEST_ASSERT_EQUAL(mount.get_missile_spawn_turf(ordinary_target, null, WEST), locate(54, 64, site_z), "An ordinary target's west approach changed")
