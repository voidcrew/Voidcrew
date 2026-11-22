/**
 * # Dock terminal: SETTINGS (game preferences)
 *
 * The terminal's own screen for every game preference tg's window lists on its game page
 * (Settings.tsx). Names, categories and descriptions come from tg's TSX feature registry on the
 * page; the server sends what the page can't know: each preference's kind, value and limits.
 *
 * Actions: settings_open (push the block), settings_set {key, value}, settings_close. The KEYS
 * group's settings_keys_* actions go to settings_keys_act() (lobby_settings_keys.dm).
 *
 * Pushes, never per-tick data: `settings` (the block) on open, after every set (accepted or
 * refused, so the page snaps back and rows that depend on a parent toggle come and go) and when
 * tg's own window changes a preference; `settings_saved` (a counter) after every write to disk.
 *
 * The block: list("rev" = n, "rows" = list(row, ...)), one row per preference:
 *   key        savefile_key (the TSX registry key)
 *   kind       "toggle", "choice", "number", "color", "text" or "other" (from the DM type)
 *   value      compile_ui_data() of the current value (toggles as 0/1)
 *   min/max/step   numbers only
 *   max_length     text only
 *   locked     1 when tg's window shows it but won't let this player change it (BYOND members only)
 * Choices are not sent: tg's preferences.json catalog has every choiced preference's choices and
 * display names, and settings_open sends that asset as char_open does.
 */

/// Wait after the last SETTINGS edit before the game preferences are written to disk.
#define LOBBY_SETTINGS_SAVE_DELAY (1 SECONDS)
/// settings_* actions a client may send per second; the rest are dropped.
#define LOBBY_SETTINGS_ACTS_PER_SECOND 20

/datum/lobby_terminal
	/// Bumped on every push of the settings block.
	var/settings_rev = 0
	/// An edit since the last write to disk.
	var/settings_dirty = FALSE
	/// Writes to disk so far; pushed as settings_saved so the page can show SAVED.
	var/settings_saved_count = 0
	var/settings_act_window = 0
	var/settings_act_count = 0

/// The prefs SETTINGS edits. A proc so the unit test can hand in a mock client's prefs.
/datum/lobby_terminal/proc/settings_get_prefs(mob/user)
	return user?.client?.prefs

/datum/lobby_terminal/settings_act(action, list/params, mob/user)
	if(!islist(params))
		params = list()
	// KEYS (lobby_settings_keys.dm): the keybindings group routes its own actions from this one line.
	if(copytext(action, 1, 15) == "settings_keys_")
		return settings_keys_act(action, params, user)
	var/datum/preferences/prefs = settings_get_prefs(user)
	if(!prefs)
		return FALSE
	prefs.lobby_game_writes = 0 // in case a runtime left it set
	if(world.time >= settings_act_window + 1 SECONDS)
		settings_act_window = world.time
		settings_act_count = 0
	if(++settings_act_count > LOBBY_SETTINGS_ACTS_PER_SECOND)
		return FALSE
	switch(action)
		if("settings_open")
			return settings_open_screen(user, prefs)
		if("settings_close")
			settings_open = FALSE
			settings_save()
			return FALSE
		if("settings_set")
			return settings_set_pref(user, prefs, params["key"], params["value"])
	return FALSE

/datum/lobby_terminal/proc/settings_open_screen(mob/user, datum/preferences/prefs)
	// The choice lists and their display names are in tg's catalog (usePrefsCatalog on the page).
	if(ui && !QDELETED(ui) && ui.window)
		if(ui.send_asset(get_asset_datum(/datum/asset/json/preferences)))
			owner?.browse_queue_flush()
		if(QDELETED(src) || !ui || QDELETED(ui))
			return FALSE
	settings_open = TRUE
	settings_push(user)
	return FALSE

/// Sends the settings block as a one-off update.
/datum/lobby_terminal/proc/settings_push(mob/user)
	if(!settings_open || !ui || QDELETED(ui))
		return
	if(!user)
		user = owner?.mob
	var/datum/preferences/prefs = settings_get_prefs(user)
	if(!prefs)
		return
	settings_rev++
	ui.send_update(list("settings" = list("rev" = settings_rev, "rows" = prefs.lobby_compile_settings(user))))

/// tg's window changed a preference: push the terminal's copy soon (coalesced).
/datum/lobby_terminal/proc/settings_changed()
	if(!settings_open)
		return
	addtimer(CALLBACK(src, PROC_REF(settings_push)), 0.2 SECONDS, TIMER_UNIQUE)

/**
 * One settings_set. The key must be a game preference this player can see right now (so admin
 * preferences never reach a non-admin), and the value is checked here against the preference's
 * own type before tg's update_preference() sees it: tg's deserialize() would quietly turn a bad
 * choice into the default instead of refusing it.
 */
/datum/lobby_terminal/proc/settings_set_pref(mob/user, datum/preferences/prefs, key, value)
	if(!istext(key))
		return FALSE
	var/list/legacy = prefs.lobby_legacy_settings(user)
	if(key in legacy)
		var/on = lobby_char_int(value)
		if(on != 0 && on != 1)
			return settings_refused(user)
		var/datum/preference_middleware/legacy_toggles/middleware = locate() in prefs.middleware
		if(!middleware?.pre_set_preference(user, key, on))
			return settings_refused(user)
		settings_edited(user, prefs)
		return TRUE
	var/datum/preference/preference = GLOB.preference_entries_by_key[key]
	if(!prefs.lobby_setting_allowed(preference))
		return FALSE
	value = prefs.lobby_setting_clean(preference, value)
	if(isnull(value))
		return settings_refused(user)
	prefs.lobby_game_writes = 1
	var/applied = prefs.update_preference(preference, value)
	prefs.lobby_game_writes = 0
	if(!applied)
		return settings_refused(user)
	for(var/datum/preference_middleware/preference_middleware as anything in prefs.middleware)
		preference_middleware.post_set_preference(user, preference.savefile_key, value)
	settings_edited(user, prefs)
	return TRUE

/// A refused settings_set: push the block so the page snaps back.
/datum/lobby_terminal/proc/settings_refused(mob/user)
	settings_push(user)
	return TRUE

/// Bookkeeping after a change: the save timer, the push, tg's own window if it is open.
/datum/lobby_terminal/proc/settings_edited(mob/user, datum/preferences/prefs)
	settings_dirty = TRUE
	addtimer(CALLBACK(src, PROC_REF(settings_save)), LOBBY_SETTINGS_SAVE_DELAY, TIMER_UNIQUE | TIMER_OVERRIDE)
	settings_push(user)
	if(user && SStgui.get_open_ui(user, prefs))
		addtimer(CALLBACK(src, PROC_REF(char_sync_tg_window)), 0.5 SECONDS, TIMER_UNIQUE)

/datum/lobby_terminal/settings_save()
	SHOULD_NOT_SLEEP(TRUE)
	if(!settings_dirty)
		return
	var/datum/preferences/prefs = owner?.prefs
	if(!prefs)
		return
	settings_dirty = FALSE
	if(!prefs.path || !prefs.savefile)
		return // a guest's preferences are never written
	prefs.save_preferences()
	// SAVED on the SETTINGS box for a moment.
	settings_saved_count++
	if(settings_open && ui && !QDELETED(ui))
		ui.send_update(list("settings_saved" = settings_saved_count))

// ---------------------------------------------------------------------------
// Reading and checking game preferences

/// TRUE when that preference is a game preference this player can see (tg's own is_accessible()).
/datum/preferences/proc/lobby_setting_allowed(datum/preference/preference)
	SHOULD_NOT_SLEEP(TRUE)
	if(!istype(preference) || preference.category != PREFERENCE_CATEGORY_GAME_PREFERENCES)
		return FALSE
	if(preference.savefile_identifier != PREFERENCE_PLAYER)
		return FALSE
	lobby_game_writes = 1
	. = preference.is_accessible(src)
	lobby_game_writes = 0
	if(. && lobby_setting_locked(preference))
		return FALSE

/// Shown by tg's window, but not changeable by this player there (it greys them out for non-members).
/datum/preferences/proc/lobby_setting_locked(datum/preference/preference)
	var/static/list/members_only = list(
		/datum/preference/choiced/ghost_form,
		/datum/preference/choiced/ghost_orbit,
	)
	return (preference.type in members_only) && !unlock_content

/**
 * A client's value as the preference's own type, or null when it isn't one: a toggle takes 0 or 1,
 * a choice one of its choices, a number a step within its limits, a colour a hex, a text a string.
 */
/datum/preferences/proc/lobby_setting_clean(datum/preference/preference, value)
	if(istype(preference, /datum/preference/toggle))
		var/on = lobby_char_int(value)
		return (on == 0 || on == 1) ? on : null
	if(istype(preference, /datum/preference/choiced))
		var/datum/preference/choiced/choiced = preference
		if(!istext(value) && !isnum(value))
			return null
		for(var/choice in choiced.get_choices())
			if("[choiced.serialize(choice)]" == "[value]")
				return choiced.serialize(choice)
		return null
	if(istype(preference, /datum/preference/numeric))
		var/datum/preference/numeric/numeric = preference
		if(istext(value))
			value = text2num(value)
		if(!isnum(value) || value < numeric.minimum || value > numeric.maximum)
			return null
		var/steps = (value - numeric.minimum) / numeric.step
		if(abs(steps - round(steps)) > 0.001)
			return null
		return value
	if(istype(preference, /datum/preference/color))
		return lobby_char_clean_hex(value)
	if(istype(preference, /datum/preference/text))
		var/datum/preference/text/text = preference
		if(!istext(value) || length(value) >= text.maximum_value_length)
			return null
		return value
	return null

/**
 * tg's legacy bitfield toggles (preference_middleware/legacy_toggles), as savefile key -> 0/1,
 * exactly as tg's game page gets them: the admin-only ones for admins only. Empty with no client.
 */
/datum/preferences/proc/lobby_legacy_settings(mob/user)
	SHOULD_NOT_SLEEP(TRUE)
	if(!user?.client)
		return list()
	var/datum/preference_middleware/legacy_toggles/legacy_middleware = locate() in src.middleware
	if(!legacy_middleware)
		return list()
	// get_character_preferences() answers only while tg's window is on its game page. It can't sleep.
	var/real_window = current_window
	current_window = PREFERENCE_TAB_GAME_PREFERENCES
	var/list/out = legacy_middleware.get_character_preferences(user)
	current_window = real_window
	if(!islist(out) || !islist(out[PREFERENCE_CATEGORY_GAME_PREFERENCES]))
		return list()
	return out[PREFERENCE_CATEGORY_GAME_PREFERENCES]

/// Every game preference this player can see, as rows of the settings block (see the top of this file).
/datum/preferences/proc/lobby_compile_settings(mob/user)
	SHOULD_NOT_SLEEP(TRUE)
	var/list/rows = list()
	for(var/datum/preference/preference as anything in get_preferences_in_priority_order())
		if(preference.category != PREFERENCE_CATEGORY_GAME_PREFERENCES || preference.savefile_identifier != PREFERENCE_PLAYER)
			continue
		lobby_game_writes = 1
		var/accessible = preference.is_accessible(src)
		lobby_game_writes = 0
		if(!accessible)
			continue
		var/list/row = list(
			"key" = preference.savefile_key,
			"value" = preference.compile_ui_data(user, read_preference(preference.type)),
		)
		if(istype(preference, /datum/preference/toggle))
			row["kind"] = "toggle"
			row["value"] = row["value"] ? 1 : 0
		else if(istype(preference, /datum/preference/choiced))
			row["kind"] = "choice"
		else if(istype(preference, /datum/preference/numeric))
			var/datum/preference/numeric/numeric = preference
			row["kind"] = "number"
			row["min"] = numeric.minimum
			row["max"] = numeric.maximum
			row["step"] = numeric.step
		else if(istype(preference, /datum/preference/color))
			row["kind"] = "color"
		else if(istype(preference, /datum/preference/text))
			var/datum/preference/text/text = preference
			row["kind"] = "text"
			row["max_length"] = text.maximum_value_length
		else
			row["kind"] = "other"
		if(lobby_setting_locked(preference))
			row["locked"] = 1
		rows += list(row)
	var/list/legacy = lobby_legacy_settings(user)
	for(var/key in legacy)
		rows += list(list("key" = key, "kind" = "toggle", "value" = legacy[key] ? 1 : 0))
	return rows

#undef LOBBY_SETTINGS_SAVE_DELAY
#undef LOBBY_SETTINGS_ACTS_PER_SECOND
