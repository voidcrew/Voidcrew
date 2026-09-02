// Voice bark preferences - ported from Monkestation
// Player preferences for customizing their bark sounds

/*
	--------- Character Preferences ---------
*/

/*
	----- Bark Middleware -----
*/

/datum/preference_middleware/bark
	/// Cooldown on requesting a bark preview.
	COOLDOWN_DECLARE(bark_cooldown)

	action_delegations = list(
		"play_bark" = PROC_REF(play_bark),
		"open_voice_screen" = PROC_REF(open_voice_screen),
	)
	var/datum/voice_screen/voice_screen
	var/atom/movable/barker

/datum/preference_middleware/bark/proc/open_voice_screen(list/params, mob/user)
	if(voice_screen)
		voice_screen.ui_interact(user)
		return TRUE
	else
		voice_screen = new(src)
		voice_screen.ui_interact(user)
		return TRUE

/datum/preference_middleware/bark/proc/play_bark(list/params, mob/user)
	if(!COOLDOWN_FINISHED(src, bark_cooldown))
		return TRUE
	if(!barker)
		barker = new()
		barker.bark_voice = new()
	barker.bark_voice.set_from_prefs(preferences)
	barker.bark_voice.long_bark(list(user), 7, 300, FALSE, 32, barker)
	COOLDOWN_START(src, bark_cooldown, 2 SECONDS)
	return TRUE

/datum/preference_middleware/bark/Destroy()
	QDEL_NULL(barker)
	return ..()

/*
	----- Bark Sound -----
*/

/// Which voice pack does the player want to use for barks
/datum/preference/choiced/voice_pack
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "voice_pack"
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL

/// Only packs the player can actually pick. Hidden packs (mob/radio barks) exist in
/// GLOB.voice_pack_list for atoms to use, but the voice screen never lists them, so
/// leaving them in here just puts unselectable entries in the dropdown.
/datum/preference/choiced/voice_pack/init_possible_values()
	var/list/values = list()
	for(var/voice_pack_id in GLOB.voice_pack_list)
		var/datum/voice_pack/voicepack = GLOB.voice_pack_list[voice_pack_id]
		if(voicepack.hidden)
			continue
		values += voice_pack_id
	return values

/// The dropdown stores raw ids, so hand the UI the same "Group: Name" labels the
/// voice screen shows. Without this it renders the bare ids instead.
/datum/preference/choiced/voice_pack/compile_constant_data()
	var/list/data = ..()

	var/list/display_names = list()
	for(var/voice_pack_id in get_choices())
		var/datum/voice_pack/voicepack = GLOB.voice_pack_list[voice_pack_id]
		display_names[voice_pack_id] = "[voicepack.group_name]: [voicepack.name]"
	data[CHOICED_PREFERENCE_DISPLAY_NAMES] = display_names

	return data

/datum/preference/choiced/voice_pack/apply_to_human(mob/living/carbon/human/target, value)
	target.set_bark_voice_pack(value)

/datum/preference/choiced/voice_pack/create_default_value()
	if(!length(GLOB.random_voice_packs))
		return "fallback.fallback"
	return pick(GLOB.random_voice_packs)

/*
	----- Bark Speed / Duration -----
*/

/datum/preference/numeric/bark_speech_speed
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "bark_speech_speed"
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	minimum = VOICE_DEFAULT_MINSPEED
	maximum = VOICE_DEFAULT_MAXSPEED
	step = 0.01

/datum/preference/numeric/bark_speech_speed/apply_to_human(mob/living/carbon/human/target, value)
	target.get_bark_voice().speed = value

/datum/preference/numeric/bark_speech_speed/create_default_value()
	return 6

/*
	----- Bark Pitch -----
*/

/datum/preference/numeric/bark_speech_pitch
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "bark_speech_pitch"
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	minimum = VOICE_DEFAULT_MINPITCH
	maximum = VOICE_DEFAULT_MAXPITCH
	step = 0.01

/datum/preference/numeric/bark_speech_pitch/apply_to_human(mob/living/carbon/human/target, value)
	target.get_bark_voice().pitch = value

/datum/preference/numeric/bark_speech_pitch/create_default_value()
	return 1

/*
	----- Bark Pitch Variance -----
*/

/datum/preference/numeric/bark_pitch_range
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "bark_pitch_range"
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	minimum = VOICE_DEFAULT_MINVARY
	maximum = VOICE_DEFAULT_MAXVARY
	step = 0.01

/datum/preference/numeric/bark_pitch_range/apply_to_human(mob/living/carbon/human/target, value)
	target.get_bark_voice().pitch_range = value

/datum/preference/numeric/bark_pitch_range/create_default_value()
	return 0.2

/*
	--------- Game Preferences ---------
*/

/// Should this player only hear a single bark per message
/datum/preference/toggle/barks_short
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "voice_sounds_short"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = FALSE

/// Should this player hear barks without pitch modification
/datum/preference/toggle/barks_limited_pitch
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "voice_sounds_limited_pitch"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = FALSE

/// Should this player only hear goonstation speak barks (simple sounds)
/datum/preference/toggle/voice_sounds_only_simple
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "voice_sounds_only_goon"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = FALSE

/**
 * How loud barks are for this player. 0 turns them off entirely.
 *
 * The three toggles above only reshape a bark - fewer blips, flat pitch, simpler sample -
 * and every one of them leaves it fully audible. There was no listener-side volume or
 * mute at all, so players trying to stop hearing barks reached for "Enable TTS" and
 * "TTS Volume" instead, which belong to the unrelated SStts subsystem and gate nothing
 * here. The only off switch was the admin-global GLOB.voices_enabled.
 *
 * Inherits minimum 0 / maximum 100 from /datum/preference/numeric/volume and defaults to
 * the maximum, so nobody's audio changes until they move the slider.
 */
/datum/preference/numeric/volume/sound_barks_volume
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "sound_barks_volume"
	savefile_identifier = PREFERENCE_PLAYER
