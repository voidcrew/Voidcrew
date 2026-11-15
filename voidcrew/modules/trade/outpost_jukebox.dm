/// Gap between two autoplayed songs.
#define JUKEBOX_AUTOPLAY_GAP (rand(4, 10) SECONDS)
/// How long an autoplaying jukebox stays quiet after someone stops it or it loses power.
#define JUKEBOX_AUTOPLAY_PAUSE (5 MINUTES)

/**
 * Trader outpost jukeboxes play by themselves, one song after another.
 *
 * Every jukebox inside a trader outpost area works through the jukebox
 * playlist in shuffled order, then shuffles again. Autoplay plays only the
 * music: the dance machine's lights and dancing still need someone to start a
 * song by hand. Anyone can still stop the music or pick their own song. After a
 * song a player started ends, the playlist picks up again. After someone stops
 * the music, it stays quiet for a while before starting again.
 */
/obj/machinery/jukebox
	/// Plays songs by itself, one after another. Set for jukeboxes inside trader outposts.
	var/autoplay = FALSE
	/// Songs still to come in the current shuffled pass.
	var/list/autoplay_queue
	/// world.time at which the current song finishes on its own.
	var/song_ends_at = 0

/obj/machinery/jukebox/Initialize(mapload)
	. = ..()
	if(istype(get_area(src), /area/voidcrew/trader_outpost))
		autoplay = TRUE
	if(autoplay)
		queue_autoplay(rand(5, 20) SECONDS)

/obj/machinery/jukebox/activate_music()
	. = ..()
	if(.)
		song_ends_at = world.time + music_player.selection.song_length

/obj/machinery/jukebox/stop_music()
	var/finished = world.time >= song_ends_at - 1
	. = ..()
	if(!autoplay || QDELING(src))
		return
	queue_autoplay(finished ? JUKEBOX_AUTOPLAY_GAP : JUKEBOX_AUTOPLAY_PAUSE)

/// Starts the next autoplayed song after the given delay, replacing any earlier one.
/obj/machinery/jukebox/proc/queue_autoplay(delay)
	addtimer(CALLBACK(src, PROC_REF(autoplay_next)), delay, TIMER_UNIQUE|TIMER_OVERRIDE|TIMER_DELETE_ME)

/// Plays the next song in the shuffled playlist.
/obj/machinery/jukebox/proc/autoplay_next()
	if(!autoplay || QDELETED(src))
		return
	if(!isnull(music_player.active_song_sound))
		return // A song is already on; when it ends, stop_music() queues the next one.
	if(!is_operational || !anchored || !length(music_player.songs))
		queue_autoplay(JUKEBOX_AUTOPLAY_PAUSE)
		return

	if(!length(autoplay_queue))
		autoplay_queue = shuffle(music_player.songs.Copy())
		// Don't repeat the last song across two shuffled passes.
		if(length(autoplay_queue) > 1 && autoplay_queue[1] == music_player.selection?.song_name)
			autoplay_queue.Swap(1, length(autoplay_queue))
	var/song_name = autoplay_queue[1]
	autoplay_queue.Cut(1, 2)
	var/datum/track/next_song = music_player.songs[song_name]
	if(isnull(next_song))
		queue_autoplay(JUKEBOX_AUTOPLAY_GAP)
		return

	music_player.selection = next_song
	music_player.sound_loops = FALSE
	// Same as activate_music() minus the dance machine's light show and dancing.
	music_player.start_music()
	music_player.prepare_song_sound()
	update_use_power(ACTIVE_POWER_USE)
	update_appearance(UPDATE_ICON_STATE)
	song_ends_at = world.time + next_song.song_length
	song_timerid = addtimer(CALLBACK(src, PROC_REF(stop_music)), next_song.song_length, TIMER_UNIQUE|TIMER_STOPPABLE|TIMER_DELETE_ME)

#undef JUKEBOX_AUTOPLAY_GAP
#undef JUKEBOX_AUTOPLAY_PAUSE
