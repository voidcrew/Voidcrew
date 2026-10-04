/**
 * # Map-loaded floors keep their mapped dir
 *
 * The map loader places a template turf with ChangeTurf() and hands the turf its
 * mapped vars through the preloader in /atom/New(). /turf/open/floor/ChangeTurf()
 * then restores the dir of the floor that was there before, which on a ship upgrade
 * module - loaded over hull plating - snapped every mapped stair, edge and corner
 * floor to SOUTH. Shuttles and ruins never showed it because they load onto space.
 *
 * This drives the same preloader + ChangeTurf sequence reader.dm runs, so it needs
 * no fixture map, and also pins the runtime behaviour the restore exists for: a
 * floor rebuilt without the loader keeps the facing it had.
 */
/datum/unit_test/voidcrew_mapload_floor_dir

/datum/unit_test/voidcrew_mapload_floor_dir/Run()
	var/turf/open/floor/target = run_loc_floor_bottom_left
	var/original_type = target.type

	// A mapped `/turf/open/floor/iron/smooth_edge{dir = 4}` placed over plating, exactly
	// as reader.dm builds it for a template with should_place_on_top (preloader_setup,
	// load_on_top with CHANGETURF_DEFER_CHANGE, then the second preloader pass for
	// atoms whose New() did not consume it).
	world.preloader_setup(list("dir" = EAST), /turf/open/floor/iron/smooth_edge)
	var/turf/open/floor/loaded = target.load_on_top(/turf/open/floor/iron/smooth_edge, CHANGETURF_DEFER_CHANGE)
	if(GLOB.use_preloader && loaded)
		world.preloader_load(loaded)
	TEST_ASSERT_EQUAL(loaded.type, /turf/open/floor/iron/smooth_edge, "The map-loaded floor did not get placed")
	TEST_ASSERT_EQUAL(loaded.dir, EAST, "A map-loaded floor lost its mapped dir to the floor underneath it")
	TEST_ASSERT(!GLOB.use_preloader, "The preloader was left armed after the map-loaded floor was placed")

	// Runtime rebuilds (RCD, tile placement, repair) are not map loads and must still
	// carry the old facing across, or every rebuilt edge tile would spin to SOUTH.
	var/turf/open/floor/rebuilt = loaded.ChangeTurf(/turf/open/floor/iron/smooth_corner)
	TEST_ASSERT_EQUAL(rebuilt.dir, EAST, "A floor rebuilt outside the map loader did not keep the old floor's dir")

	rebuilt.ChangeTurf(original_type)
