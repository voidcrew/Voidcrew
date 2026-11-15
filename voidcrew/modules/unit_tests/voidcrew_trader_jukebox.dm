/**
 * # Trader outpost jukebox autoplay
 *
 * An autoplaying jukebox plays through its playlist, stops once nobody is
 * around, and never tracks NPCs as listeners.
 */
/datum/unit_test/voidcrew_trader_jukebox

/datum/unit_test/voidcrew_trader_jukebox/Run()
	var/mob/living/carbon/human/consistent/npc = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/jukebox/no_access/box = allocate(/obj/machinery/jukebox/no_access, get_step(npc, EAST))
	box.autoplay = TRUE

	box.autoplay_next()
	TEST_ASSERT_NOTNULL(box.music_player.active_song_sound, "Autoplay did not start a song")
	TEST_ASSERT(!(npc in box.music_player.get_active_listeners()), "A mob without a player was tracked as a jukebox listener")

	// A song already playing is never cut off while someone could be listening.
	var/datum/track/playing = box.music_player.selection
	box.autoplay_empty_checks = 0
	box.autoplay_check()
	TEST_ASSERT_EQUAL(box.music_player.selection, playing, "Autoplay changed a song that was still playing")
	TEST_ASSERT_NOTNULL(box.music_player.active_song_sound, "Autoplay stopped the music after one empty check")

	// With no player anywhere near, the music stops after a few checks.
	for(var/i in 1 to 5)
		box.autoplay_check()
	TEST_ASSERT_NULL(box.music_player.active_song_sound, "Autoplay kept playing with nobody nearby")

	// A song that ran to the end only waits a short gap; a stopped one waits longer.
	box.autoplay_wait_until = 0
	box.autoplay_next()
	box.song_ends_at = world.time
	box.stop_music()
	TEST_ASSERT(box.autoplay_wait_until <= world.time + 10 SECONDS, "A finished song held the next one back too long")

	box.autoplay = FALSE
