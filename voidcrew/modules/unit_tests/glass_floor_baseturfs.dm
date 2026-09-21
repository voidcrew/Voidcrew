/// Ground beneath glass must cover parallax; space must still display it.
/datum/unit_test/glass_floor_baseturfs
	var/datum/space_level/test_level
	var/previous_ground

/datum/unit_test/glass_floor_baseturfs/Run()
	test_level = SSmapping.z_list[run_loc_floor_bottom_left.z]
	previous_ground = test_level.traits[ZTRAIT_BASETURF]
	TEST_ASSERT(!GET_TURF_BELOW(run_loc_floor_bottom_left), "This test needs a level with no real turf below it")
	TEST_ASSERT(isnull(footprint_baseturf_for_turf(run_loc_floor_bottom_left)), "The test turf must use the level's baseturf")

	// Recreate glass over each destination, as shuttle movement does on landing.
	var/list/ground_types = list(
		/turf/open/space,
		/turf/open/misc/asteroid/basalt/lava_land_surface,
		/turf/open/misc/asteroid/snow/icemoon/breathable,
		/turf/open/misc/asteroid/sand/beach,
		/turf/open/misc/dirt/jungle,
		/turf/open/misc/wasteland,
		/turf/open/space,
	)
	for(var/glass_type in list(/turf/open/floor/glass, /turf/open/floor/glass/reinforced, /turf/open/indestructible/glass))
		for(var/turf/ground_type as anything in ground_types)
			test_level.set_trait(ZTRAIT_BASETURF, ground_type)
			var/turf/glass = run_loc_floor_bottom_left.ChangeTurf(glass_type, flags = CHANGETURF_FORCEOP)
			var/is_space = ispath(ground_type, /turf/open/space)
			var/expected_plane = MUTATE_PLANE(is_space ? PLANE_SPACE : FLOOR_PLANE, glass)
			var/found_ground = FALSE
			for(var/mutable_appearance/underlay as anything in glass.underlays)
				if(underlay.icon != initial(ground_type.icon) || underlay.icon_state != initial(ground_type.icon_state))
					continue
				found_ground = TRUE
				TEST_ASSERT_EQUAL(underlay.plane, expected_plane, "[glass_type] over [ground_type] must render ground above parallax, and space on the parallax plane")
				if(!is_space)
					TEST_ASSERT(underlay.layer < GLASS_FLOOR_LAYER, "Ground must remain beneath the glass")
			TEST_ASSERT(found_ground, "[glass_type] must display an underlay for [ground_type]")

			// Removing transparency must remove the same appearance that was installed.
			REMOVE_TURF_TRANSPARENCY(glass, INNATE_TRAIT)
			for(var/mutable_appearance/underlay as anything in glass.underlays)
				TEST_ASSERT(underlay.icon != initial(ground_type.icon) || underlay.icon_state != initial(ground_type.icon_state), "Removing transparency must clear the ground underlay")

/datum/unit_test/glass_floor_baseturfs/Destroy()
	if(test_level)
		test_level.set_trait(ZTRAIT_BASETURF, previous_ground)
		test_level = null
	run_loc_floor_bottom_left.ChangeTurf(/turf/open/floor/iron)
	run_loc_floor_bottom_left.assemble_baseturfs(initial(run_loc_floor_bottom_left.baseturfs))
	return ..()
