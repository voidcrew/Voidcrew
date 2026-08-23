/**
 * # Say pipeline integration
 *
 * The decision half of the Hear() hook. The core edits in
 * code/modules/mob/living/living_say.dm are kept to three marked blocks by
 * putting all the actual logic here.
 *
 * Every one of these gates exists for a reason - see the comments. The cheap
 * ones are checked first so the common case (an English speaker hearing
 * English on a server with the feature off) costs almost nothing.
 */

/**
 * Decides whether this listener should get a translation of this line, and if
 * so builds the handle for it.
 *
 * Returns a /datum/translated_speech, or null to leave the message alone.
 * The caller must then, in order: swap raw_message for wrapped_text(), build
 * the runechat bubble, attach_runechat() it, and finally begin().
 */
/mob/living/proc/try_begin_translation(atom/movable/speaker, raw_message, is_custom_emote, understood, message_obscured)
	// Emotes are not speech and are already excluded from IC language
	// handling upstream.
	if(is_custom_emote)
		return null

	// The listener does not know the IC language, so raw_message is already
	// scrambled gibberish. Translating it produces nonsense and burns backend
	// quota on garbage.
	if(!understood)
		return null

	// Eavesdropped speech has been through stars() and reads like
	// "s..eth.ng l..e th.s". Nothing useful survives translation.
	if(message_obscured)
		return null

	// Radio arrives through a virtualspeaker standing in for whoever is on the
	// other end, so resolve that before deciding anything about the speaker.
	var/atom/movable/actual_speaker = speaker?.GetSource() || speaker

	// Player speech only. Announcement computers, bots, NPC mobs and the
	// station's automated chatter are all in English already and none of it is
	// worth spending backend quota on.
	if(!ismob(actual_speaker))
		return null
	var/mob/speaking_mob = actual_speaker
	if(!GET_CLIENT(speaking_mob))
		return null

	// Watching your own words rewrite themselves is disorienting. Drop this
	// check if you would rather see what everyone else sees.
	if(speaking_mob == src)
		return null

	var/client/listener = client
	if(isnull(listener))
		return null

	var/target_language = autotranslate_pref_to_code(listener.prefs?.read_preference(/datum/preference/choiced/autotranslate_target))
	if(isnull(target_language))
		return null

	if(!length(raw_message))
		return null

	// Script detection. Free, and it filters out the large majority of lines
	// before anything is dispatched - an English reader on an English server
	// only ever pays for the occasional Russian line.
	var/source_language = autotranslate_detect_language(raw_message)
	if(source_language == target_language)
		return null

	if(!SSautotranslate.can_translate(source_language, target_language))
		return null

	return new /datum/translated_speech(listener, raw_message, source_language, target_language)
