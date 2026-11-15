/**
 * # Trader outpost jukebox autoplay
 *
 * An autoplaying jukebox can start a song with no player nearby to register,
 * never tracks NPCs as listeners, waits only a short gap after a song ends but
 * pauses after a player stops it, and two jukeboxes in earshot of each other
 * don't play at once.
 *
 * Starting and stopping on player presence needs a connected client and a
 * trader outpost area, so it isn't covered here.
 */
/datum/unit_test/voidcrew_trader_jukebox

/datum/unit_test/voidcrew_trader_jukebox/Run()
	var/mob/living/carbon/human/consistent/npc = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/jukebox/no_access/box = allocate(/obj/machinery/jukebox/no_access, get_step(npc, EAST))
	var/obj/machinery/jukebox/no_access/other_box = allocate(/obj/machinery/jukebox/no_access, get_step(npc, WEST))
	box.autoplay = TRUE
	other_box.autoplay = TRUE
	GLOB.autoplay_jukeboxes |= list(box, other_box)

	box.autoplay_next()
	TEST_ASSERT_NOTNULL(box.music_player.active_song_sound, "Autoplay did not start a song")
	TEST_ASSERT(box.autoplay_song, "An autoplayed song wasn't marked as autoplayed")
	TEST_ASSERT(!(npc in box.music_player.get_active_listeners()), "A mob without a player was tracked as a jukebox listener")
	TEST_ASSERT(other_box.other_jukebox_playing_nearby(), "A second jukebox in earshot would autoplay over the first")

	// A song that ends on its own hands over after a short gap.
	box.stop_music()
	TEST_ASSERT_NULL(box.music_player.active_song_sound, "stop_music() left the song playing")
	TEST_ASSERT(box.autoplay_wait_until <= world.time + 10 SECONDS, "A finished song held the next one back too long")
	TEST_ASSERT(!box.autoplay_song, "The autoplay mark outlived its song")

	// A player pressing stop pauses autoplay for longer.
	box.autoplay_next()
	box.player_stopping = TRUE
	box.stop_music()
	box.player_stopping = FALSE
	TEST_ASSERT(box.autoplay_wait_until >= world.time + 1 MINUTES, "Autoplay didn't pause after a player stopped the music")

	box.autoplay = FALSE
	other_box.autoplay = FALSE
