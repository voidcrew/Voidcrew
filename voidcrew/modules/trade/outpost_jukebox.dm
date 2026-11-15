/// How often an autoplaying jukebox checks for players nearby.
#define JUKEBOX_AUTOPLAY_CHECK (3 SECONDS)
/// Gap between two autoplayed songs.
#define JUKEBOX_AUTOPLAY_GAP (rand(4, 10) SECONDS)
/// How long an autoplaying jukebox stays quiet after a player stops it.
#define JUKEBOX_AUTOPLAY_PAUSE (5 MINUTES)
/// Checks in a row with nobody nearby before the music stops (about 30 seconds).
#define JUKEBOX_AUTOPLAY_EMPTY_CHECKS 10
/// How close a player must come before a song starts. Songs keep playing out to the full hearing range.
#define JUKEBOX_AUTOPLAY_START_RANGE 7

/// Every jukebox that may autoplay, so two near each other don't play at once.
GLOBAL_LIST_EMPTY(autoplay_jukeboxes)

/**
 * Trader outpost jukebox autoplay.
 *
 * Every jukebox inside a trader outpost area works through the jukebox
 * playlist in shuffled order while players are nearby, exactly as if someone
 * had pressed play: the dance machine brings its lights and dancing. When
 * everyone leaves, the music stops, so an empty outpost costs nothing.
 * Players can still stop the music or pick their own song. After a player
 * stops it, it stays quiet for a while before starting again.
 *
 * A jukebox carried out of the outpost stops autoplaying. Only one of two
 * jukeboxes within earshot of each other autoplays at a time, because both
 * play on the same sound channel.
 */
/obj/machinery/jukebox
	/// Plays songs by itself while players are nearby. Set for jukeboxes inside trader outposts.
	var/autoplay = FALSE
	/// Songs still to come in the current shuffled pass.
	var/list/autoplay_queue
	/// world.time before which autoplay won't start a song.
	var/autoplay_wait_until = 0
	/// Checks in a row that found nobody nearby while a song played.
	var/autoplay_empty_checks = 0
	/// Set while a player's stop button is being handled.
	var/player_stopping = FALSE
	/// The current song was started by autoplay. The dance machine skips its light spin-up for these.
	var/autoplay_song = FALSE

/obj/machinery/jukebox/Initialize(mapload)
	. = ..()
	if(istype(get_area(src), /area/voidcrew/trader_outpost))
		autoplay = TRUE
	if(autoplay)
		GLOB.autoplay_jukeboxes += src
		addtimer(CALLBACK(src, PROC_REF(autoplay_check)), JUKEBOX_AUTOPLAY_CHECK, TIMER_LOOP|TIMER_DELETE_ME)

/obj/machinery/jukebox/Destroy()
	GLOB.autoplay_jukeboxes -= src
	return ..()

/obj/machinery/jukebox/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(action == "toggle" && !isnull(music_player.active_song_sound))
		player_stopping = TRUE
	. = ..()
	player_stopping = FALSE

/obj/machinery/jukebox/activate_music()
	. = ..()
	if(.)
		// Before the dance machine's light show, which stops at once if the song has no sound.
		music_player.prepare_song_sound()
		autoplay_empty_checks = 0

/obj/machinery/jukebox/stop_music()
	. = ..()
	autoplay_song = FALSE
	if(!autoplay || QDELING(src))
		return
	autoplay_wait_until = world.time + (player_stopping ? JUKEBOX_AUTOPLAY_PAUSE : JUKEBOX_AUTOPLAY_GAP)

/// Starts a song when players come near, stops it when they've all left.
/obj/machinery/jukebox/proc/autoplay_check()
	if(!autoplay || QDELETED(src))
		return
	if(!istype(get_area(src), /area/voidcrew/trader_outpost))
		return // Carried off the outpost; it's an ordinary jukebox now.

	if(!isnull(music_player.active_song_sound))
		if(music_player.player_in_range())
			autoplay_empty_checks = 0
			return
		if(++autoplay_empty_checks < JUKEBOX_AUTOPLAY_EMPTY_CHECKS)
			return
		stop_music()
		return

	if(world.time < autoplay_wait_until)
		return
	if(!is_operational || !anchored || !length(music_player.songs))
		return
	if(!music_player.player_in_range(JUKEBOX_AUTOPLAY_START_RANGE))
		return
	if(other_jukebox_playing_nearby())
		return
	autoplay_next()

/// Whether another autoplay jukebox close enough to share listeners is already playing.
/obj/machinery/jukebox/proc/other_jukebox_playing_nearby()
	var/turf/our_turf = get_turf(src)
	for(var/obj/machinery/jukebox/other as anything in GLOB.autoplay_jukeboxes)
		if(other == src || isnull(other.music_player?.active_song_sound))
			continue
		var/turf/their_turf = get_turf(other)
		if(their_turf?.z != our_turf?.z)
			continue
		if(get_dist(our_turf, their_turf) <= 20) // Two hearing ranges of about ten tiles.
			return TRUE
	return FALSE

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
	music_player.set_volume_to_max() // A player can turn it down for their song, not for the rest of the round.
	autoplay_song = TRUE
	if(!activate_music())
		autoplay_song = FALSE

#undef JUKEBOX_AUTOPLAY_CHECK
#undef JUKEBOX_AUTOPLAY_GAP
#undef JUKEBOX_AUTOPLAY_PAUSE
#undef JUKEBOX_AUTOPLAY_EMPTY_CHECKS
#undef JUKEBOX_AUTOPLAY_START_RANGE
