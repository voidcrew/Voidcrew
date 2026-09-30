/// Planet cleanup deletes NPC hosts; ordinary combat death must instead release them.
/datum/unit_test/voidcrew_legion_cleanup/Run()
	var/turf/surface = run_loc_floor_bottom_left
	var/datum/map_footprint/footprint = allocate(/datum/map_footprint)
	footprint.z_value = surface.z
	footprint.set_rect(surface.x, surface.y, 2, 2)
	var/datum/planet_mob_tracker/tracker = allocate(/datum/planet_mob_tracker)
	tracker.surface_z = surface.z
	tracker.footprint = footprint
	TEST_ASSERT(!SSplanet_mobs.check_players(tracker), "Legion cleanup fixture must have no connected players")

	var/mob/living/basic/mining/legion/legion = allocate(/mob/living/basic/mining/legion, surface)
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent, surface)
	TEST_ASSERT_NULL(body.mind, "NPC cleanup fixture must not have a player mind")
	legion.consume(body)
	TEST_ASSERT_EQUAL(legion.stored_mob, body, "Legion did not consume the test body")
	SSplanet_mobs.despawn_planet_mobs(tracker)
	TEST_ASSERT(QDELETED(legion) && QDELETED(body), "Planet cleanup did not delete the ordinary Legion and its NPC host")

	legion = allocate(/mob/living/basic/mining/legion, surface)
	body = allocate(/mob/living/carbon/human/consistent, surface)
	legion.consume(body)
	legion.death()
	TEST_ASSERT(QDELETED(legion), "Defeated Legion was not removed")
	TEST_ASSERT(!QDELETED(body) && isturf(body.loc), "Ordinary Legion death did not release its consumed host")
	TEST_ASSERT_NULL(body.has_status_effect(/datum/status_effect/grouped/stasis), "Released Legion host remained in stasis")
