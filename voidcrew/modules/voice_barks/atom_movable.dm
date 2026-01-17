// Atom movable extensions for voice barks - ported from Monkestation
// This adds the bark voice datum to all movable atoms
// Note: We use bark_voice to avoid conflict with the existing TTS `voice` var

/atom/movable
	/// The bark voice datum for this atom
	var/datum/atom_voice/bark_voice = null
	/// When barks are queued, this gets passed to the bark proc. If long_bark_start_time doesn't match the args passed to the bark proc (if passed at all), then the bark simply doesn't play. Basic curtailing of spam
	var/long_bark_start_time = -1

/atom/movable/proc/initial_voice_pack_id()
	return null

/atom/movable/proc/get_bark_voice() as /datum/atom_voice
	if(bark_voice)
		return bark_voice
	bark_voice = new()
	bark_voice.set_voice_pack(initial_voice_pack_id())
	return bark_voice

/// Sets the voicepack for the atom, using the voicepack's ID
/atom/movable/proc/set_bark_voice_pack(id)
	if(bark_voice)
		bark_voice.set_voice_pack(id)
	else
		bark_voice = new()
		bark_voice.set_voice_pack(id)

/// Copies the voice from another atom or voice datum.
/atom/movable/proc/copy_bark_voice_from(datum/atom_voice/other)
	if(ismovable(other))
		var/atom/movable/other_movable = other
		other = other_movable.get_bark_voice()
	if(!istype(other))
		CRASH("Something other than a movable or an atom_voice was passed to copy_bark_voice_from!")
	get_bark_voice().copy_from(other)

/atom/movable/proc/can_long_bark()
	return FALSE

/mob/living/initial_voice_pack_id()
	return pick(GLOB.random_voice_packs)

/mob/can_long_bark()
	return !isnull(client)
