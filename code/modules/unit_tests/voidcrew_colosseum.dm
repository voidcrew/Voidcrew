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
