/**
 * Auto-translation target. Defaults to English for everyone.
 *
 * Anything a listener hears that is not already in this language gets
 * translated. Script detection runs first and costs nothing, so an English
 * reader hearing English never dispatches anything - only actual Russian lines
 * reach the backend.
 *
 * The cost does not scale with player count. SSautotranslate keys both its
 * cache and its in-flight dedup on source|target|text, so one Russian line
 * heard by thirty English-target listeners is one backend request that thirty
 * callbacks ride along on, not thirty requests.
 *
 * The flip side of an English default: a Russian-speaking player has their own
 * language rewritten into English until they set this to "Translate to
 * Russian". Everything stays inert regardless until TRANSLATE_HTTP_URL is
 * configured.
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
