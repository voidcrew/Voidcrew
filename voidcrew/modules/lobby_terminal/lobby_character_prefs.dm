/**
 * # Dock terminal: CHARACTER preference adapters (package C1)
 *
 * Owns /datum/preferences/var/lobby_char_writes, the flag-gated /datum/preference/is_accessible()
 * override that lets the terminal write character prefs whatever tg's window last showed,
 * the /datum/preferences/ui_act() override that tells the terminal when tg's window changed
 * something, lobby_compile_char() and the null-safe slot switch.
 */

/datum/preferences
	/// Set (1) only while the dock terminal reads or writes character preferences. While set,
	/// is_accessible() judges character prefs as if tg's window were on the character tab, so a
	/// player whose tg window was last on game settings can still edit their character from the
	/// terminal. Cleared after every use and at the top of every char_act().
	var/lobby_char_writes = 0

/**
 * The current_window trap. tg hides every character preference while its window is on the game
 * tab, which would make every terminal edit (and tg's own loadout middleware) silently fail.
 * The swap is invisible to anything else: is_accessible() is SHOULD_NOT_SLEEP, so nothing can run
 * between setting and restoring current_window. Without the flag this is tg's proc unchanged.
 */
/datum/preference/is_accessible(datum/preferences/preferences)
	if(preferences?.lobby_char_writes && savefile_identifier == PREFERENCE_CHARACTER && preferences.current_window != PREFERENCE_TAB_CHARACTER_PREFERENCES)
		var/real_window = preferences.current_window
		preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
		. = ..()
		preferences.current_window = real_window
		return .
	return ..()

/// tg's window changed something: the terminal re-reads it (coalesced in char_changed()).
/datum/preferences/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		parent?.lobby_terminal?.char_changed()

/// update_preference() with the terminal flag held, so the current_window trap can't refuse it.
/datum/preferences/proc/lobby_update_preference(datum/preference/preference, value)
	lobby_char_writes = 1
	. = update_preference(preference, value)
	lobby_char_writes = 0

/// TRUE when that preference is one the terminal shows and may write.
/datum/preferences/proc/lobby_char_key_allowed(datum/preference/preference)
	SHOULD_NOT_SLEEP(TRUE)
	if(!istype(preference) || preference.savefile_identifier != PREFERENCE_CHARACTER)
		return FALSE
	if(istype(preference, /datum/preference/loadout))
		return FALSE // char_kit*
	if(istype(preference, /datum/preference/name) && !istype(preference, /datum/preference/name/real_name))
		return FALSE // AI, cyborg, clown, mime, religion and alias names: no tg alt-names here
	var/static/list/denied = list(
		"random_body",
		"random_name",
		"random_hardcore",
		"persistent_scars",
		"uplink_loc",
		"prefered_security_department",
		"operative_species",
		"preferred_ai_core_display",
		"preferred_ai_emote_display",
		"preferred_ai_hologram_display",
		"silicon_gender",
	)
	return !(preference.savefile_key in denied)

/**
 * Every accessible, allowed PREFERENCE_CHARACTER preference as savefile_key -> compile_ui_data().
 * A flat copy of compile_character_preferences() with no middleware extras.
 */
/datum/preferences/proc/lobby_compile_char(mob/user)
	SHOULD_NOT_SLEEP(TRUE)
	var/list/out = list()
	lobby_char_writes = 1
	for(var/datum/preference/preference as anything in get_preferences_in_priority_order())
		if(!lobby_char_key_allowed(preference))
			continue
		if(!preference.is_accessible(src))
			continue
		out[preference.savefile_key] = preference.compile_ui_data(user, read_preference(preference.type))
	lobby_char_writes = 0
	return out

/**
 * switch_to_slot() without its unguarded character_preview_view.update_body() (tg's preview only
 * exists while tg's window is open). Saves the current slot first. FALSE for a slot out of range.
 */
/datum/preferences/proc/lobby_switch_to_slot(new_slot, mob/user)
	if(!isnum(new_slot) || new_slot != round(new_slot) || new_slot < 1 || new_slot > max_save_slots)
		return FALSE
	save_character()
	if(!load_character(new_slot))
		randomise_appearance_prefs()
		save_character()
	tainted_character_profiles = TRUE
	for(var/datum/preference_middleware/preference_middleware as anything in middleware)
		preference_middleware.on_new_character(user)
	character_preview_view?.update_body()
	return TRUE
