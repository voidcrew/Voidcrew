/**
 * # Grand Colosseum map contract
 *
 * The venue is one hand-authored map that the controller drives by string id
 * and by landmark type. link_interior() indexes the landmarks and every
 * consumer carries a geometric fallback, which is good for robustness and bad
 * for visibility: a landmark that goes missing in a map edit does not break
 * anything loudly, it silently moves seating and flags to hardcoded fallback
 * coordinates. The map has already drifted out from under the dryrun harness
 * once (colosseum_dryrun.dm's gallery coordinates are stale), and the dryrun
 * cannot live in this suite. It is #ifdef'd and drives a real two-cycle match
 * with sleeps.
 *
 * This is the cheap half of that harness: everything the controller reaches for
 * by name must still be somewhere in the map text.
 */

/datum/unit_test/colosseum_map_contract

/datum/unit_test/colosseum_map_contract/Run()
	var/datum/map_template/colosseum/venue_type = /datum/map_template/colosseum
	var/mappath = initial(venue_type.mappath)
	var/text = vc_test_file_text(mappath)
	TEST_ASSERT_NOTNULL(text, "the colosseum map '[mappath]' is missing. The venue can never open")
	TEST_ASSERT(!findtext(text, "/turf/open/misc/beach/sand,"), "the colosseum must use fish-free arena sand instead of beach fishing spots")
	TEST_ASSERT(findtext(text, "/turf/open/misc/beach/sand/colosseum,"), "the colosseum map has no arena sand")

	// Door ids set_gates() drives. Literals = COLOSSEUM_GATE_RED / _BLUE / _SOLO
	// and COLOSSEUM_SEAL (voidcrew/_DEFINES/colosseum.dm); unit-test files
	// compile before voidcrew/_DEFINES, so the defines are not available here.
	for(var/gate_id in list("colo_gate_red", "colo_gate_blue", "colo_gate_solo", "colo_seal"))
		if(!findtext(text, "id = \"[gate_id]\""))
			TEST_FAIL("no door in the colosseum map carries id '[gate_id]', set_gates() drives an empty list and that gate never opens or closes")

	// Landmarks the seating and the game modes index.
	for(var/landmark_path in list(
		/obj/effect/landmark/colosseum/spawn_cell,
		/obj/effect/landmark/colosseum/spawn_red,
		/obj/effect/landmark/colosseum/spawn_blue,
		/obj/effect/landmark/colosseum/flag_red,
		/obj/effect/landmark/colosseum/flag_blue,
		/obj/effect/landmark/colosseum/koth,
		/obj/effect/landmark/colosseum/arena_event,
		/obj/effect/landmark/colosseum/infirmary,
	))
		if(!vc_test_map_has_path(text, landmark_path))
			TEST_FAIL("the colosseum map places no [landmark_path]; every consumer falls back to hardcoded coordinates instead, which drift silently on the next map edit")

	// The venue's own machinery. link_interior() only fallback-spawns these with
	// a log line, so a missing one is invisible in a live round.
	for(var/machine_path in list(
		/obj/machinery/computer/colosseum_signup,
		/obj/machinery/computer/colosseum_bookmaker,
		/obj/machinery/colosseum_vault,
		/mob/living/basic/outpost_trader/colosseum,
	))
		if(!vc_test_map_has_path(text, machine_path))
			TEST_FAIL("the colosseum map places no [machine_path]")

	// The two-level build: the spectator gallery is a real second z-slice
	// reached by stairs, over a glass deck. This is the part that drifted.
	for(var/area_path in list(
		/area/voidcrew/colosseum/arena,
		/area/voidcrew/colosseum/lobby,
		/area/voidcrew/colosseum/staging,
		/area/voidcrew/colosseum/spectator,
		/area/voidcrew/colosseum/vault,
	))
		if(!findtext(text, "[area_path]"))
			TEST_FAIL("the colosseum map has no [area_path], the venue's area-driven behaviour (staging seals, vault claim window) has nothing to hang on")
	if(!findtext(text, "/obj/structure/stairs"))
		TEST_FAIL("the colosseum map has no stairs. The spectator gallery is unreachable")
	if(!findtext(text, "/turf/open/indestructible/glass"))
		TEST_FAIL("the colosseum map has no glass gallery deck, spectators cannot see the arena below")

/// Blasts must not produce fishing rewards, including after a lava hazard resets.
/datum/unit_test/colosseum_terrain_explosions
	var/turf/test_turf
	var/original_type
	var/list/original_baseturfs

/datum/unit_test/colosseum_terrain_explosions/Destroy()
	if(test_turf)
		test_turf.ChangeTurf(original_type, original_baseturfs, flags = CHANGETURF_IGNORE_AIR)
	return ..()

/datum/unit_test/colosseum_terrain_explosions/Run()
	test_turf = get_step(run_loc_floor_bottom_left, NORTHEAST)
	original_type = test_turf.type
	original_baseturfs = test_turf.baseturfs.Copy()
	for(var/turf_type in list(
		/turf/open/misc/beach/sand/colosseum,
		/turf/open/lava/smooth/colosseum,
		/turf/open/misc/beach/sand/colosseum,
	))
		test_turf = test_turf.ChangeTurf(turf_type, flags = CHANGETURF_IGNORE_AIR)
		TEST_ASSERT_NULL(test_turf.fish_source, "[turf_type] must not have a fishing source")
		TEST_ASSERT(!HAS_TRAIT(test_turf, TRAIT_FISHING_SPOT), "[turf_type] must not accept fishing rods")
		for(var/severity in list(EXPLODE_LIGHT, EXPLODE_HEAVY, EXPLODE_DEVASTATE))
			var/list/contents_before = test_turf.contents.Copy()
			EX_ACT(test_turf, severity)
			TEST_ASSERT_EQUAL(test_turf.type, turf_type, "Blasting arena terrain must preserve its type")
			var/list/spawned = test_turf.contents - contents_before
			TEST_ASSERT_EQUAL(length(spawned), 0, "Blasting [turf_type] at severity [severity] spawned fishing rewards")

	// Fishing sources outside the venue must still register normally.
	for(var/turf_type in list(/turf/open/misc/beach/sand, /turf/open/lava/smooth))
		test_turf = test_turf.ChangeTurf(turf_type, flags = CHANGETURF_IGNORE_AIR)
		TEST_ASSERT_NOTNULL(test_turf.fish_source, "Normal [turf_type] lost its fishing source")
		TEST_ASSERT(HAS_TRAIT(test_turf, TRAIT_FISHING_SPOT), "Normal [turf_type] must still accept fishing rods")
