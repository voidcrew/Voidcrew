/// Derelict outpost tests. Owner: P4. Voidcrew defines are not visible here: literals, with the define named beside them.

/// A minimal home site for leash tests: habitat is whatever turfs are listed, not a real built level.
/obj/structure/overmap/dynamic/player_outpost/derelict/leash_test
	var/list/habitat = list()

/obj/structure/overmap/dynamic/player_outpost/derelict/leash_test/is_habitat_turf(turf/location)
	return location in habitat

/datum/unit_test/voidcrew_derelict_leash_returns
	parent_type = /datum/unit_test/voidcrew_derelict

/datum/unit_test/voidcrew_derelict_leash_returns/Run()
	var/obj/structure/overmap/dynamic/player_outpost/derelict/leash_test/site = allocate(/obj/structure/overmap/dynamic/player_outpost/derelict/leash_test)
	site.habitat = list(run_loc_floor_bottom_left, get_step(run_loc_floor_bottom_left, EAST))

	var/mob/living/basic/skeleton/pawn = allocate(/mob/living/basic/skeleton, run_loc_floor_bottom_left)
	pawn.AddComponent(/datum/component/derelict_leash, site)

	pawn.forceMove(run_loc_floor_top_right)
	TEST_ASSERT_EQUAL(get_turf(pawn), run_loc_floor_bottom_left, "a leashed hostile that left the habitat was not returned")

	do_teleport(pawn, run_loc_floor_top_right, channel = TELEPORT_CHANNEL_BLUESPACE)
	TEST_ASSERT_EQUAL(get_turf(pawn), run_loc_floor_bottom_left, "a leashed hostile was teleported off the habitat")

/datum/unit_test/voidcrew_derelict_leash_carried_off
	parent_type = /datum/unit_test/voidcrew_derelict

/datum/unit_test/voidcrew_derelict_leash_carried_off/Run()
	var/obj/structure/overmap/dynamic/player_outpost/derelict/leash_test/site = allocate(/obj/structure/overmap/dynamic/player_outpost/derelict/leash_test)
	site.habitat = list(run_loc_floor_bottom_left)

	var/obj/structure/closet/box = allocate(/obj/structure/closet, run_loc_floor_bottom_left)
	var/mob/living/basic/skeleton/pawn = allocate(/mob/living/basic/skeleton, run_loc_floor_bottom_left)
	pawn.AddComponent(/datum/component/derelict_leash, site)
	pawn.forceMove(box)

	box.forceMove(run_loc_floor_top_right)
	pawn.forceMove(run_loc_floor_top_right)
	sleep(2)
	TEST_ASSERT(QDELETED(pawn), "a hostile carried off the derelict in a closet was not removed")

/datum/unit_test/voidcrew_derelict_leash_players
	parent_type = /datum/unit_test/voidcrew_derelict

/datum/unit_test/voidcrew_derelict_leash_players/Run()
	var/obj/structure/overmap/dynamic/player_outpost/derelict/leash_test/site = allocate(/obj/structure/overmap/dynamic/player_outpost/derelict/leash_test)
	site.habitat = list(run_loc_floor_bottom_left)

	var/mob/living/basic/skeleton/dead_pawn = allocate(/mob/living/basic/skeleton, run_loc_floor_bottom_left)
	dead_pawn.basic_mob_flags &= ~DEL_ON_DEATH // skeletons crumble on death; keep the body for this check
	dead_pawn.AddComponent(/datum/component/derelict_leash, site)
	dead_pawn.death()
	TEST_ASSERT(!QDELETED(dead_pawn), "the dead hostile was deleted, so the leash check below proves nothing")
	dead_pawn.forceMove(run_loc_floor_top_right)
	TEST_ASSERT_EQUAL(get_turf(dead_pawn), run_loc_floor_top_right, "a dead leashed hostile moved outside the habitat was pulled back")

	var/mob/living/basic/skeleton/player_pawn = allocate(/mob/living/basic/skeleton, run_loc_floor_bottom_left)
	var/datum/component/derelict_leash/leash = player_pawn.AddComponent(/datum/component/derelict_leash, site)
	// A clientless test world never runs Login() for a set key; send what Login() sends when a player takes the body.
	SEND_SIGNAL(player_pawn, COMSIG_MOB_LOGIN)
	TEST_ASSERT(QDELETED(leash), "a hostile taken over by a player kept its leash")

	player_pawn.forceMove(run_loc_floor_top_right)
	TEST_ASSERT_EQUAL(get_turf(player_pawn), run_loc_floor_top_right, "a former hostile taken over by a player was pulled back to the habitat")
