// Package: P8 effects. Unit tests for voidcrew/modules/plasma_weapons/.

/// Soot is one per turf, capped globally with the oldest dropped first, and leaves the global list when deleted
/datum/unit_test/voidcrew_plasma_soot_caps

/datum/unit_test/voidcrew_plasma_soot_caps/Run()
	var/list/start_soot = GLOB.plasma_soot_decals.Copy()
	var/turf/open/first_turf = run_loc_floor_bottom_left
	var/turf/open/second_turf = get_step(first_turf, EAST)
	var/turf/open/third_turf = get_step(second_turf, EAST)
	TEST_ASSERT(isopenturf(first_turf) && isopenturf(second_turf) && isopenturf(third_turf), "The test room has no three open floor tiles in a row")
	var/cap = length(start_soot) + 2

	var/obj/effect/decal/cleanable/plasma_soot/first = plasma_soot_at(first_turf, cap = cap)
	TEST_ASSERT_NOTNULL(first, "No soot was made on an open floor")
	TEST_ASSERT(first in GLOB.plasma_soot_decals, "New soot was not added to the global list")

	var/obj/effect/decal/cleanable/plasma_soot/again = plasma_soot_at(first_turf, cap = cap)
	TEST_ASSERT_EQUAL(again, first, "A second hit on the same tile made a second soot decal")
	var/on_turf = 0
	for(var/obj/effect/decal/cleanable/plasma_soot/soot in first_turf)
		on_turf++
	TEST_ASSERT_EQUAL(on_turf, 1, "A tile holds more than one soot decal")

	var/obj/effect/decal/cleanable/plasma_soot/second = plasma_soot_at(second_turf, cap = cap)
	var/obj/effect/decal/cleanable/plasma_soot/third = plasma_soot_at(third_turf, cap = cap)
	TEST_ASSERT(QDELETED(first), "Soot over the cap did not drop the oldest decal")
	TEST_ASSERT(!QDELETED(second) && !QDELETED(third), "Soot over the cap dropped a newer decal")
	TEST_ASSERT_EQUAL(length(GLOB.plasma_soot_decals), cap, "The global soot list grew past its cap")

	qdel(second)
	TEST_ASSERT(!(second in GLOB.plasma_soot_decals), "Deleted soot stayed in the global list")
	qdel(third)
	TEST_ASSERT_EQUAL(length(GLOB.plasma_soot_decals), length(start_soot), "The global soot list kept test decals")


/// Wall glows are capped per z-level, and a deleted glow frees its slot
/datum/unit_test/voidcrew_plasma_glow_cap

/datum/unit_test/voidcrew_plasma_glow_cap/Run()
	var/turf/here = run_loc_floor_bottom_left
	var/key = "[here.z]"
	var/start_count = GLOB.plasma_wall_glows_by_z[key] || 0
	var/cap = start_count + 2

	var/obj/effect/temp_visual/plasma_wall_glow/first = plasma_wall_glow_at(here, cap = cap)
	var/obj/effect/temp_visual/plasma_wall_glow/second = plasma_wall_glow_at(here, cap = cap)
	TEST_ASSERT(first && second, "Glows under the cap were not made")
	TEST_ASSERT_NULL(plasma_wall_glow_at(here, cap = cap), "A glow over the per-z cap was made")
	TEST_ASSERT_EQUAL(GLOB.plasma_wall_glows_by_z[key], cap, "The per-z glow count is wrong")

	// Soot glows count against the same cap, so soot made at the cap gets none
	var/turf/open/soot_turf = get_step(here, EAST)
	var/room_for_glow = plasma_glow_allowed(here.z)
	var/obj/effect/decal/cleanable/plasma_soot/soot = plasma_soot_at(soot_turf)
	TEST_ASSERT_NOTNULL(soot, "Soot was not made")
	if(room_for_glow)
		TEST_ASSERT_NOTNULL(soot.glow, "Fresh soot under the real cap has no glow")
	qdel(soot)

	qdel(first)
	TEST_ASSERT(plasma_glow_allowed(here.z, cap), "A deleted glow did not free its slot")
	qdel(second)
	TEST_ASSERT_EQUAL(GLOB.plasma_wall_glows_by_z[key] || 0, start_count, "Deleted glows stayed counted")

/// The distant firing sound only reaches listeners past normal hearing range and inside the far range
/datum/unit_test/voidcrew_plasma_far_sound

/datum/unit_test/voidcrew_plasma_far_sound/Run()
	var/turf/source = run_loc_floor_bottom_left
	TEST_ASSERT_EQUAL(plasma_far_sound_volume(source, source), 0, "The far sound plays at the source")
	var/list/expected = list("10" = FALSE, "17" = FALSE, "18" = TRUE, "40" = TRUE, "41" = FALSE)
	for(var/dist_text in expected)
		var/dist = text2num(dist_text)
		if(source.x + dist > world.maxx)
			continue
		var/turf/listener_turf = locate(source.x + dist, source.y, source.z)
		var/volume = plasma_far_sound_volume(listener_turf, source)
		if(expected[dist_text])
			TEST_ASSERT(volume >= 30 && volume <= 60, "A listener [dist] tiles away got far-sound volume [volume]")
		else
			TEST_ASSERT_EQUAL(volume, 0, "A listener [dist] tiles away heard the far sound")

	if(source.x + 25 > world.maxx)
		return
	var/mob/living/carbon/human/near = allocate(/mob/living/carbon/human/consistent, locate(source.x + 5, source.y, source.z))
	var/mob/living/carbon/human/far = allocate(/mob/living/carbon/human/consistent, locate(source.x + 25, source.y, source.z))
	var/list/picked = plasma_far_sound_pick(source, list(near, far))
	TEST_ASSERT(!(near in picked), "A listener inside normal hearing range was picked for the far sound")
	// The far listener stands on whatever turf is there; in thin air it is rightly skipped
	var/turf/far_turf = get_turf(far)
	var/datum/gas_mixture/far_air = far_turf.return_air_readonly()
	var/datum/gas_mixture/source_air = source.return_air_readonly()
	if(far_air?.return_pressure() >= ONE_ATMOSPHERE && source_air?.return_pressure() >= ONE_ATMOSPHERE)
		TEST_ASSERT(far in picked, "A listener 25 tiles away in air was not picked for the far sound")
