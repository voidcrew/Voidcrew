/**
 * Jukeboxes only track mobs that have a player.
 *
 * Upstream registers every mob that walks into range, NPCs included, and keeps
 * signals on them for as long as they stay. A mob without a client never hears
 * the sound, so tracking it is wasted work. A player who takes over a mob in
 * range is picked up the next time that mob moves.
 */
/datum/jukebox/register_listener(mob/new_listener)
	if(isnull(new_listener.client))
		return
	return ..()

/**
 * Builds the song's sound when nobody could be registered at the start.
 *
 * Upstream only builds it when the first listener registers. A song started
 * while every player in range is out of sight then counts as silent, and
 * players who walk up later never hear it.
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

/// Whether any player is close enough to hear this jukebox.
/datum/jukebox/proc/player_in_range()
	var/turf/sound_turf = get_turf(parent)
	if(isnull(sound_turf))
		return FALSE
	for(var/mob/player as anything in GLOB.player_list)
		if(isnewplayer(player))
			continue
		var/turf/player_turf = get_turf(player)
		if(player_turf?.z != sound_turf.z)
			continue
		if(abs(player_turf.x - sound_turf.x) <= x_cutoff && abs(player_turf.y - sound_turf.y) <= z_cutoff)
			return TRUE
	return FALSE
