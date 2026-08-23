/**
 * Opt-in preference for auto-translation.
 *
 * Defaults to off, and that matters for more than taste: every player who
 * turns this on generates backend traffic for every line they hear in a
 * language that is not their target. Opt-in is the single biggest lever on
 * what this feature costs to run.
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
	return AUTOTRANSLATE_PREF_OFF
