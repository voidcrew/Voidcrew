/// Mission field spawns stay off turfs a player could be looking at, and walls count as cover
/datum/unit_test/voidcrew_mission_spawn_cover

/datum/unit_test/voidcrew_mission_spawn_cover/Run()
	var/turf/eye_turf = run_loc_floor_bottom_left
	var/turf/beside = locate(eye_turf.x + 1, eye_turf.y, eye_turf.z)
	var/turf/near = locate(eye_turf.x + 2, eye_turf.y, eye_turf.z)
	// Well past any screen, on the same level
	var/far_x = (eye_turf.x + 40 <= world.maxx) ? eye_turf.x + 40 : eye_turf.x - 40
	var/turf/far = locate(far_x, eye_turf.y, eye_turf.z)
	TEST_ASSERT_NOTNULL(near, "The test room must be at least three tiles wide.")
	TEST_ASSERT_NOTNULL(far, "The test level must be wider than one screen.")

	// No z: nobody is registered as watching
	var/datum/spawn_cover/cover = new
	TEST_ASSERT(cover.is_hidden(near), "With nobody watching, every turf is hidden.")

	cover.add_watcher(eye_turf, 9, 7)
	TEST_ASSERT(!cover.is_hidden(near), "A turf two tiles from a watcher, in the open, is in view.")
	TEST_ASSERT(!cover.is_hidden(beside), "The turf next to a watcher is in view.")
	TEST_ASSERT_EQUAL(cover.fallback, near, "The fallback is the seen turf farthest from the watcher.")
	TEST_ASSERT(cover.is_hidden(far), "A turf forty tiles away is off the watcher's screen.")

	// An opaque wall between them hides what's behind it
	allocate(/obj/structure/falsewall, beside)
	TEST_ASSERT(IS_OPAQUE_TURF(beside), "The false wall must make its turf opaque.")
	TEST_ASSERT(cover.is_hidden(near), "A turf behind a wall is hidden from the watcher.")

	// The list picker never hands back anything but one of its candidates
	var/list/candidates = list(beside, near)
	TEST_ASSERT(pick_unwatched_turf(candidates) in candidates, "The picker must return one of its candidates.")
	TEST_ASSERT_NULL(pick_unwatched_turf(list()), "An empty candidate list has nothing to pick.")

/// Set dressing is effects only, stays off walls, and leaves the objective's tile to the objective
/datum/unit_test/voidcrew_mission_site_dressing

/datum/unit_test/voidcrew_mission_site_dressing/Run()
	var/turf/anchor = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/item/mission_recovery/objective = allocate(__IMPLIED_TYPE__, anchor)
	for(var/scene_type in subtypesof(/datum/mission_scene))
		dress_mission_scene(scene_type, anchor, null)
	var/pieces = 0
	for(var/turf/tile as anything in RANGE_TURFS(3, anchor))
		for(var/obj/item/loot in tile)
			TEST_ASSERT_EQUAL(loot, objective, "Set dressing must not leave items lying around ([loot.type]).")
		for(var/obj/effect/decal/mission_scene/piece in tile)
			pieces++
			TEST_ASSERT(!isclosedturf(tile), "[piece.type] was placed on a wall.")
			if(tile == anchor)
				TEST_ASSERT(istype(piece, /obj/effect/decal/mission_scene/scorch) || istype(piece, /obj/effect/decal/mission_scene/skid), "Only ground marks may share the objective's tile, not [piece.type].")
	TEST_ASSERT(pieces > 0, "The scenes must lay something down.")
	TEST_ASSERT_EQUAL(objective.loc, anchor, "Dressing must not move the objective.")
