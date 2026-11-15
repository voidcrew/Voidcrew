/**
 * # Trader outpost jukebox autoplay
 *
 * An autoplaying jukebox starts a song by itself and starts the next one after
 * a song finishes. NPCs in range are never tracked as listeners.
 */
/datum/unit_test/voidcrew_trader_jukebox

/datum/unit_test/voidcrew_trader_jukebox/Run()
	var/mob/living/carbon/human/consistent/npc = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/jukebox/no_access/box = allocate(/obj/machinery/jukebox/no_access, get_step(npc, EAST))
	box.autoplay = TRUE

	box.autoplay_next()
	TEST_ASSERT_NOTNULL(box.music_player.active_song_sound, "Autoplay did not start a song")
	TEST_ASSERT(!(npc in box.music_player.get_active_listeners()), "A mob without a player was tracked as a jukebox listener")

	// A song that ran to the end hands over to the next one.
	box.song_ends_at = world.time
	box.stop_music()
	TEST_ASSERT_NULL(box.music_player.active_song_sound, "stop_music() left the song playing")
	box.autoplay_next()
	TEST_ASSERT_NOTNULL(box.music_player.active_song_sound, "Autoplay did not start the next song")

	// A song already playing is never cut off by the playlist.
	var/datum/track/playing = box.music_player.selection
	box.autoplay_next()
	TEST_ASSERT_EQUAL(box.music_player.selection, playing, "Autoplay replaced a song that was still playing")

	box.autoplay = FALSE
	box.stop_music()
