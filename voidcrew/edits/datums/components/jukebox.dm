/datum/jukebox
	/// world.time the current song started. Players who walk in later join it partway through.
	var/song_started_at = 0

/datum/jukebox/start_music()
	song_started_at = world.time
	return ..()

/**
 * Jukeboxes only track mobs that have a player.
 *
 * Upstream registers every mob that walks into range, NPCs included, and keeps
 * signals on them for as long as they stay. A mob without a client never hears
 * the sound, so tracking it is wasted work. A player who takes over a mob in
 * range is picked up the next time that mob moves.
 *
 * A player who arrives after the song started hears it from where it is now,
 * not from the beginning.
 */
/datum/jukebox/register_listener(mob/new_listener)
	if(isnull(new_listener.client))
		return
	if(!isnull(active_song_sound))
		active_song_sound.offset = max(0, (world.time - song_started_at) / (1 SECONDS))
	. = ..()
	// The sound datum is shared; later position updates must not seek anyone else.
	active_song_sound?.offset = 0

/**
 * Builds the song's sound before anyone is in range.
 *
 * Upstream only builds it when the first listener registers, so a jukebox
 * started with nobody nearby counts as silent and never plays to players who
 * walk up later.
 */
/datum/jukebox/proc/prepare_song_sound()
	if(!isnull(active_song_sound) || isnull(selection))
		return
	var/area/juke_area = get_area(parent)
	active_song_sound = sound(selection.song_path)
	active_song_sound.channel = CHANNEL_JUKEBOX
	active_song_sound.priority = 255
	active_song_sound.falloff = 2
	active_song_sound.volume = volume
	active_song_sound.y = 1
	active_song_sound.environment = juke_area?.sound_environment || SOUND_ENVIRONMENT_NONE
	active_song_sound.repeat = sound_loops
