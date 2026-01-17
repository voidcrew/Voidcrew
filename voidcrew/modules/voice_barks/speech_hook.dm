// Voice bark speech hook - ported from Monkestation
// This hooks into the speech system to automatically play barks when players talk
// The hook extends /mob/living/send_speech to add bark functionality

/mob/living/send_speech(message_raw, message_range = 6, obj/source = src, bubble_type = bubble_icon, list/spans, datum/language/message_language = null, list/message_mods = list(), forced = null, tts_message, list/tts_filter)
	. = ..()

	// Don't bark for custom emotes, sign language, or unknown speakers
	if(message_mods[MODE_CUSTOM_SAY_ERASE_INPUT])
		return
	if(HAS_TRAIT(src, TRAIT_SIGN_LANG))
		return
	if(HAS_TRAIT(src, TRAIT_UNKNOWN))
		return

	// Check if barking is enabled
	if(!GLOB.voices_enabled)
		return

	// Get the bark voice datum
	var/datum/atom_voice/my_bark_voice = get_bark_voice()
	if(!my_bark_voice?.voicepack)
		return

	// Determine whisper mode and talk icon state
	var/is_speaker_whispering = message_mods[WHISPER_MODE] ? TRUE : FALSE
	var/talk_icon_state = say_test(message_raw)

	// Get the list of hearers - we need to rebuild this list because the parent doesn't return it
	var/whisper_range = 0
	if(message_mods[WHISPER_MODE])
		whisper_range = MESSAGE_RANGE - WHISPER_RANGE

	var/list/listening = get_hearers_in_range(message_range + whisper_range, source)
	var/list/in_view = get_hearers_in_view(message_range + whisper_range, source)

	// Filter by line of sight
	for(var/atom/movable/listening_movable as anything in listening)
		if(!(listening_movable in in_view) && !HAS_TRAIT(listening_movable, TRAIT_XRAY_HEARING))
			listening.Remove(listening_movable)

	// Include ghosts if applicable
	if(client)
		for(var/mob/player_mob as anything in GLOB.player_list)
			if(QDELETED(player_mob))
				continue
			if(player_mob.stat != DEAD)
				continue
			if(player_mob.z != z || get_dist(player_mob, src) > 7)
				if(is_speaker_whispering)
					if(!(get_chat_toggles(player_mob.client) & CHAT_GHOSTWHISPER))
						continue
				else if(!(get_chat_toggles(player_mob.client) & CHAT_GHOSTEARS))
					continue
			listening |= player_mob

	// Start barking!
	my_bark_voice.start_barking(message_raw, listening, message_range, talk_icon_state, is_speaker_whispering, src)

// Also hook into base atom/movable send_speech for non-living speakers (machines, etc)
/atom/movable/send_speech(message, range = 7, obj/source = src, bubble_type, list/spans, datum/language/message_language, list/message_mods = list(), forced = FALSE, tts_message, list/tts_filter)
	. = ..()

	// Check if barking is enabled
	if(!GLOB.voices_enabled)
		return

	// Get the bark voice datum
	var/datum/atom_voice/my_bark_voice = get_bark_voice()
	if(!my_bark_voice?.voicepack)
		return

	// Get hearers
	var/list/hearers = get_hearers_in_view(range, source)

	// Start barking
	var/talk_icon_state = say_test(message)
	my_bark_voice.start_barking(message, hearers, range, talk_icon_state, FALSE, src)
