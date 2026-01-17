/atom/movable
	var/datum/atom_voice/voice_bark = null
	/// When barks are queued, this gets passed to the bark proc. If long_bark_start_time doesn't match the args passed to the bark proc (if passed at all), then the bark simply doesn't play. Basic curtailing of spam~
	var/long_bark_start_time = -1

/atom/movable/proc/initial_voice_pack_id()
	return null

/atom/movable/proc/get_voice_bark() as /datum/atom_voice
	if (voice_bark)
		return voice_bark
	voice_bark = new()
	voice_bark.set_voice_pack(initial_voice_pack_id())
	return voice_bark

/// Sets the voicepack for the atom, using the voicepack's ID
/atom/movable/proc/set_voice_pack(id)
	if (voice_bark)
		voice_bark.set_voice_pack(id)
	else
		voice_bark = new()
		voice_bark.set_voice_pack(id)

/// Copies the voice from another atom or voice datum.
/atom/movable/proc/copy_voice_from(datum/atom_voice/other)
	if(ismovable(other))
		var/atom/movable/other_movable = other
		other = other_movable.get_voice_bark()
	if(!istype(other))
		CRASH("Something other than a movable or an atom_voice was passed to copy_voice_from!")
	get_voice_bark().copy_from(other)

/atom/movable/proc/can_long_bark()
	return FALSE

/mob/living/initial_voice_pack_id()
	return pick(GLOB.random_voice_packs)

/mob/can_long_bark()
	return !isnull(client)
