/// Deleted map paths must not shift their variable edits onto the remaining atoms.
/datum/unit_test/map_parser_attributes

/datum/unit_test/map_parser_attributes/Run()
	var/datum/parsed_map/parsed = allocate(/datum/parsed_map)
	// This fixture builds a cache directly; initialize the bounds normally supplied by file parsing.
	parsed.bounds = list(1, 1, 1, 1, 1, 1)
	parsed.parsed_bounds = parsed.bounds.Copy()
	var/missing_path = "/obj/unit_test_missing_map_path"
	var/list/bad_paths = list()
	parsed.grid_models["a"] = {"/obj/effect/map_parser_attributes{
	name = "first";
	pixel_x = 4
	},
/obj/unit_test_missing_map_path{
	id = "must not leak";
	pixel_x = 99
	},
/obj/unit_test_missing_map_path,
/obj/effect/map_parser_attributes{
	name = "second";
	pixel_y = 7
	},
/obj/unit_test_missing_map_path{
	name = "also must not leak"
	},
/obj/effect/map_parser_attributes,
/turf/template_noop,
/area/template_noop"}
	var/list/cache = parsed.tgm_build_cache(bad_paths = bad_paths)
	var/list/model = cache["a"]
	var/list/members = model[1]
	var/list/attributes = model[2]
	TEST_ASSERT_EQUAL(length(members), 5, "The three invalid paths should be skipped.")
	TEST_ASSERT_EQUAL(length(attributes), length(members), "Each retained atom must have exactly one attribute slot.")
	TEST_ASSERT_EQUAL(attributes[1]["name"], "first", "The first valid atom lost its edits.")
	TEST_ASSERT_EQUAL(attributes[2]["name"], "second", "An invalid atom's edits shifted onto the next valid atom.")
	TEST_ASSERT_EQUAL(attributes[2]["pixel_y"], 7, "The later valid atom lost its own edits.")
	TEST_ASSERT_EQUAL(length(attributes[3]), 0, "A default atom inherited removed variable edits.")
	TEST_ASSERT_EQUAL(length(attributes[4]), 0, "The turf inherited removed variable edits.")
	TEST_ASSERT_EQUAL(length(attributes[5]), 0, "The area inherited removed variable edits.")
	TEST_ASSERT("a" in bad_paths[missing_path], "Invalid paths should still be reported under their complete path.")

	// Exercise the actual preloader as well, without replacing the test room's turf or area.
	parsed.build_coordinate(model, run_loc_floor_bottom_left, FALSE, TRUE, FALSE)
	var/list/objects = list()
	for(var/obj/effect/map_parser_attributes/created in run_loc_floor_bottom_left)
		objects += created
		allocated += created
	TEST_ASSERT_EQUAL(length(objects), 3, "The loader should instantiate every valid object and no invalid objects.")
	var/obj/effect/map_parser_attributes/first = objects[1]
	var/obj/effect/map_parser_attributes/second = objects[2]
	var/obj/effect/map_parser_attributes/unedited = objects[3]
	TEST_ASSERT_EQUAL(first.name, "first", "The first object's actual mapped name changed.")
	TEST_ASSERT_EQUAL(first.pixel_x, 4, "The first object's actual mapped offset changed.")
	TEST_ASSERT_EQUAL(second.name, "second", "The second object's actual mapped name changed.")
	TEST_ASSERT_EQUAL(second.pixel_y, 7, "The second object's actual mapped offset changed.")
	TEST_ASSERT_EQUAL(unedited.name, initial(unedited.name), "An unedited object inherited another object's name.")

/obj/effect/map_parser_attributes
	name = "map parser test object"
