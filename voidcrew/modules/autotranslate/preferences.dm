/**
 * The player's auto-translation target.
 *
 * Defaults to English (owner decision): a new player reads other languages in English unless
 * they pick another target or turn it off. Every player with a target generates backend traffic
 * for every line they hear in a language that is not their target, so this default is the
 * single biggest lever on what the feature costs to run. A player who already saved a choice
 * keeps it.
 */
/datum/preference/choiced/autotranslate_target
	savefile_key = "autotranslate_target"
	savefile_identifier = PREFERENCE_PLAYER
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES

/datum/preference/choiced/autotranslate_target/init_possible_values()
	return list(
		AUTOTRANSLATE_PREF_OFF,
		AUTOTRANSLATE_PREF_ENGLISH,
		AUTOTRANSLATE_PREF_RUSSIAN,
	)

/datum/preference/choiced/autotranslate_target/create_default_value()
	return AUTOTRANSLATE_PREF_ENGLISH
