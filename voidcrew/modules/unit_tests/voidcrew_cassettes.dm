/// Mixtapes come out blank with no server songs, and filled from the song list when there are some.
/datum/unit_test/cassette_mixtape_spawn
	/// The real song list, put back when the test ends.
	var/list/saved_tracks

/datum/unit_test/cassette_mixtape_spawn/Run()
	saved_tracks = GLOB.cassette_tracks

	GLOB.cassette_tracks = list()
	var/obj/item/cassette_tape/mixtape/empty_tape = allocate(/obj/item/cassette_tape/mixtape)
	TEST_ASSERT(!empty_tape.has_tracks(), "A mixtape spawned with no songs configured still has tracks")
	TEST_ASSERT_EQUAL(empty_tape.name, "cassette tape", "A blank mixtape kept its mixtape name")

	var/list/fake_tracks = list()
	for(var/i in 1 to 10)
		var/datum/track/track = allocate(/datum/track)
		track.song_name = "test song [i]"
		track.song_path = 'sound/machines/click.ogg'
		track.song_length = 5 SECONDS
		fake_tracks += track
	GLOB.cassette_tracks = fake_tracks

	var/obj/item/cassette_tape/mixtape/full_tape = allocate(/obj/item/cassette_tape/mixtape)
	TEST_ASSERT_EQUAL(full_tape.name, "mixtape", "A filled mixtape lost its name")
	for(var/side_number in 1 to 2)
		var/list/side = full_tape.sides[side_number]
		TEST_ASSERT(length(side) >= 1 && length(side) <= full_tape.max_side_tracks, "Mixtape side [side_number] has [length(side)] tracks")
		var/list/unique = unique_list(side)
		TEST_ASSERT_EQUAL(length(unique), length(side), "Mixtape side [side_number] repeats a song")
		for(var/datum/track/track as anything in side)
			TEST_ASSERT(track in fake_tracks, "Mixtape side [side_number] holds a track that isn't in the song list")
	TEST_ASSERT(full_tape.sides[1] != full_tape.sides[2], "Both sides of a mixtape share one list")
	TEST_ASSERT(full_tape.icon_state != "cassette_flip", "A mixtape kept the plain sticker")

/datum/unit_test/cassette_mixtape_spawn/Destroy()
	GLOB.cassette_tracks = saved_tracks
	saved_tracks = null
	return ..()

/// Copying between tapes, flipping and erasing never makes two tapes share a track list.
/datum/unit_test/cassette_copy_and_flip

/datum/unit_test/cassette_copy_and_flip/Run()
	var/datum/track/song_one = allocate(/datum/track)
	song_one.song_name = "song one"
	var/datum/track/song_two = allocate(/datum/track)
	song_two.song_name = "song two"

	var/obj/item/cassette_tape/blank/from = allocate(/obj/item/cassette_tape/blank)
	var/obj/item/cassette_tape/blank/onto = allocate(/obj/item/cassette_tape/blank)
	TEST_ASSERT(from.sides[1] != onto.sides[1], "Two blank tapes share side A's list")
	TEST_ASSERT(from.sides[2] != onto.sides[2], "Two blank tapes share side B's list")

	// Side A of the first tape, then side B.
	TEST_ASSERT(from.record_track(song_one), "Could not record onto a blank tape")
	TEST_ASSERT_EQUAL(from.name, "cassette tape", "A recorded blank kept the blank name")
	from.flip()
	TEST_ASSERT_EQUAL(length(from.current_side()), 0, "Flipping a tape didn't turn to the empty side")
	from.record_track(song_two)
	from.flip()
	TEST_ASSERT_EQUAL(length(from.current_side()), 1, "Side A changed while recording on side B")
	TEST_ASSERT_EQUAL(from.current_side()[1], song_one, "Side A holds the wrong song")
	TEST_ASSERT_EQUAL(from.sides[2][1], song_two, "Side B holds the wrong song")

	// Copy side A onto the second tape's side B, the way the deck does.
	var/obj/item/cassette_deck/deck = allocate(/obj/item/cassette_deck)
	from.forceMove(deck)
	deck.tape_from = from
	onto.forceMove(deck)
	deck.tape_to = onto
	onto.flip()
	TEST_ASSERT(onto.record_track(deck.tape_from.current_side()[1]), "Deck copy failed")
	TEST_ASSERT_EQUAL(length(onto.sides[1]), 0, "The copy landed on the wrong side")
	TEST_ASSERT_EQUAL(onto.sides[2][1], song_one, "The copy holds the wrong song")

	// Erasing from one tape leaves the other alone.
	TEST_ASSERT(from.erase_track(1), "Could not erase a track")
	TEST_ASSERT_EQUAL(length(from.current_side()), 0, "Erase left the track on the tape")
	TEST_ASSERT_EQUAL(length(onto.sides[2]), 1, "Erasing the source tape erased the copy too")

	// A side holds a fixed number of songs.
	for(var/i in 1 to onto.max_side_tracks - 1)
		TEST_ASSERT(onto.record_track(song_two), "Side filled up after [i] extra songs")
	TEST_ASSERT(!onto.record_track(song_two), "A full side took another song")

	// Taking a tape out of the deck empties its slot.
	from.forceMove(get_turf(deck))
	TEST_ASSERT_NULL(deck.tape_from, "The deck still thinks it holds an ejected tape")
	TEST_ASSERT_EQUAL(deck.tape_to, onto, "Ejecting one slot emptied the other")

/// A walkman forgets its tape when the tape leaves it, and stops when there's no listener.
/datum/unit_test/cassette_walkman_tape

/datum/unit_test/cassette_walkman_tape/Run()
	var/obj/item/walkman/walkman = allocate(/obj/item/walkman)
	var/obj/item/cassette_tape/blank/tape = allocate(/obj/item/cassette_tape/blank)
	var/mob/living/carbon/human/consistent/listener = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(walkman.design >= 1 && walkman.design <= 5, "Walkman rolled design [walkman.design]")
	listener.put_in_hands(walkman)

	var/datum/track/song = allocate(/datum/track)
	song.song_name = "song"
	song.song_path = 'sound/machines/click.ogg'
	song.song_length = 5 SECONDS
	tape.record_track(song)

	TEST_ASSERT(!walkman.start_music(listener), "A walkman with no tape started playing")
	tape.forceMove(walkman)
	walkman.tape = tape
	TEST_ASSERT(walkman.start_music(listener), "A walkman with a recorded tape wouldn't play")
	TEST_ASSERT(walkman.playing, "The walkman isn't playing after play")
	TEST_ASSERT_EQUAL(walkman.listener, listener, "The walkman's listener isn't the person who pressed play")
	TEST_ASSERT(walkman.advance_timer, "No timer to move to the next song")

	walkman.pause_music()
	TEST_ASSERT(!walkman.playing, "Pause didn't stop the walkman")
	TEST_ASSERT(!walkman.advance_timer, "Pause left the next-song timer running")
	TEST_ASSERT(walkman.time_left_paused > 0, "Pause forgot how much of the song was left")
	TEST_ASSERT(walkman.start_music(listener), "Resume failed")
	TEST_ASSERT(walkman.advance_timer, "Resume didn't restart the next-song timer")

	// The only song on the side ends: the side is over and it stops.
	walkman.track_ended()
	TEST_ASSERT(!walkman.playing, "The walkman kept playing past the end of the side")
	TEST_ASSERT_NULL(walkman.listener, "The walkman kept its listener after stopping")

	walkman.start_music(listener)
	tape.forceMove(get_turf(listener))
	TEST_ASSERT_NULL(walkman.tape, "The walkman still thinks it holds a removed tape")
	TEST_ASSERT(!walkman.playing, "The walkman kept playing with its tape gone")
	TEST_ASSERT_NULL(walkman.advance_timer, "The next-song timer outlived the tape")
