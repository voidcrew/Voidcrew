/// How often an autoplaying jukebox checks for players nearby.
#define JUKEBOX_AUTOPLAY_CHECK (3 SECONDS)
/// Gap between two autoplayed songs.
#define JUKEBOX_AUTOPLAY_GAP (rand(4, 10) SECONDS)
/// How long an autoplaying jukebox stays quiet after someone stops it.
#define JUKEBOX_AUTOPLAY_PAUSE (5 MINUTES)
/// How many checks in a row with nobody nearby before the music stops.
#define JUKEBOX_AUTOPLAY_EMPTY_CHECKS 3

/**
 * Trader outpost jukebox autoplay.
 *
 * Every jukebox inside a trader outpost area works through the jukebox
 * playlist in shuffled order while players are nearby, exactly as if someone
 * had pressed play: the dance machine brings its lights and dancing. When
 * everyone leaves, the music stops, so an empty outpost costs nothing.
 * Players can still stop the music or pick their own song. After someone stops
 * it, it stays quiet for a while before starting again.
 */
/obj/machinery/jukebox
	/// Plays songs by itself while players are nearby. Set for jukeboxes inside trader outposts.
	var/autoplay = FALSE
	/// Songs still to come in the current shuffled pass.
	var/list/autoplay_queue
	/// world.time at which the current song finishes on its own.
	var/song_ends_at = 0
	/// world.time before which autoplay won't start a song.
	var/autoplay_wait_until = 0
	/// Checks in a row that found nobody nearby while a song played.
	var/autoplay_empty_checks = 0
	/// Set while autoplay itself stops the music, so it isn't taken for a player stopping it.
	var/autoplay_stopping = FALSE
	/// The current song was started by autoplay. The dance machine skips its light spin-up for these.
	var/autoplay_song = FALSE

/obj/machinery/jukebox/Initialize(mapload)
	. = ..()
	if(istype(get_area(src), /area/voidcrew/trader_outpost))
		autoplay = TRUE
	if(autoplay)
		addtimer(CALLBACK(src, PROC_REF(autoplay_check)), JUKEBOX_AUTOPLAY_CHECK, TIMER_LOOP|TIMER_DELETE_ME)

/obj/machinery/jukebox/activate_music()
	. = ..()
	if(.)
		// Before the dance machine's light show, which stops at once if the song has no sound.
		music_player.prepare_song_sound()
		song_ends_at = world.time + music_player.selection.song_length
		autoplay_empty_checks = 0

/obj/machinery/jukebox/stop_music()
	var/finished = world.time >= song_ends_at - 1
	. = ..()
	autoplay_song = FALSE
	if(!autoplay || QDELING(src) || autoplay_stopping)
		return
	autoplay_wait_until = world.time + (finished ? JUKEBOX_AUTOPLAY_GAP : JUKEBOX_AUTOPLAY_PAUSE)

/// Starts a song when players come near, stops it when they've all left.
/obj/machinery/jukebox/proc/autoplay_check()
	if(!autoplay || QDELETED(src))
		return
	var/players_near = music_player.player_in_range()

	if(!isnull(music_player.active_song_sound))
		if(players_near)
			autoplay_empty_checks = 0
			return
		if(++autoplay_empty_checks < JUKEBOX_AUTOPLAY_EMPTY_CHECKS)
			return
		autoplay_stopping = TRUE
		stop_music()
		autoplay_stopping = FALSE
		return

	if(!players_near || world.time < autoplay_wait_until)
		return
	if(!is_operational || !anchored || !length(music_player.songs))
		return
	autoplay_next()

/// Plays the next song in the shuffled playlist, light show and all.
/obj/machinery/jukebox/proc/autoplay_next()
	if(!length(autoplay_queue))
		autoplay_queue = shuffle(music_player.songs.Copy())
		// Don't repeat the last song across two shuffled passes.
		if(length(autoplay_queue) > 1 && autoplay_queue[1] == music_player.selection?.song_name)
			autoplay_queue.Swap(1, length(autoplay_queue))
	var/song_name = autoplay_queue[1]
	autoplay_queue.Cut(1, 2)
	var/datum/track/next_song = music_player.songs[song_name]
	if(isnull(next_song))
		return

	music_player.selection = next_song
	music_player.sound_loops = FALSE
	autoplay_song = TRUE
	if(!activate_music())
		autoplay_song = FALSE

#undef JUKEBOX_AUTOPLAY_CHECK
#undef JUKEBOX_AUTOPLAY_GAP
#undef JUKEBOX_AUTOPLAY_PAUSE
#undef JUKEBOX_AUTOPLAY_EMPTY_CHECKS
