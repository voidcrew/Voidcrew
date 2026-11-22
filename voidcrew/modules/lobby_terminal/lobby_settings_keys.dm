/**
 * # Dock terminal: SETTINGS, KEYS group (the keybindings)
 *
 * The terminal's copy of tg's keybindings page (SettingsKeys.tsx). Names, categories and
 * descriptions come from tg's keybindings.json asset on the page; the server sends the player's
 * bindings. Every write goes through tg's own keybindings middleware
 * (code/modules/client/preferences/middleware/keybindings.dm), so its checks and side effects
 * (key_bindings_by_key, update_special_keybinds(), tg's window) stay tg's.
 *
 * Actions (routed here by settings_act()):
 *   settings_keys_open        sends keybindings.json, pushes the block
 *   settings_keys_close       stops pushing
 *   settings_keys_set         {keybind_name, hotkeys[]} (at most three)
 *   settings_keys_reset       {keybind_name}: that one back to its default
 *   settings_keys_reset_all   every keybinding back to its default
 *
 * Pushes, never per-tick data: `settings_keys` = list("rev" = n, "binds" = list(keybind_name =
 * list(key, ...))) on open, after every action (accepted or refused, so the page snaps back) and
 * when tg's own window changes a keybinding. Keybindings with no key are left out.
 *
 * tg's window lists every category, ADMIN included, to every player and lets anyone bind them;
 * the admin keybindings check for an admin holder when pressed. This screen does the same.
 */

/// The most keys tg keeps on one keybinding (MAX_HOTKEY_SLOTS in tg's middleware).
#define LOBBY_KEYS_SLOTS 3
/// The longest key name accepted. tg allows 100; the longest real name is about 30.
#define LOBBY_KEYS_NAME_MAX 40
/// settings_keys_* actions a client may send per second; the rest are dropped.
#define LOBBY_KEYS_ACTS_PER_SECOND 20

/datum/lobby_terminal
	/// TRUE while the KEYS group is open in this window.
	var/settings_keys_open = FALSE
	/// Bumped on every push of the settings_keys block.
	var/settings_keys_rev = 0
	var/settings_keys_act_window = 0
	var/settings_keys_act_count = 0

/datum/lobby_terminal/settings_keys_act(action, list/params, mob/user)
	if(!islist(params))
		params = list()
	if(world.time >= settings_keys_act_window + 1 SECONDS)
		settings_keys_act_window = world.time
		settings_keys_act_count = 0
	if(++settings_keys_act_count > LOBBY_KEYS_ACTS_PER_SECOND)
		return FALSE
	var/datum/preferences/prefs = settings_get_prefs(user)
	if(!prefs)
		return FALSE
	switch(action)
		if("settings_keys_open")
			return settings_keys_open_screen(user)
		if("settings_keys_close")
			settings_keys_open = FALSE
			return FALSE
		if("settings_keys_set")
			return settings_keys_set(user, prefs, params["keybind_name"], params["hotkeys"])
		if("settings_keys_reset")
			return settings_keys_reset(user, prefs, params["keybind_name"])
		if("settings_keys_reset_all")
			return settings_keys_reset_all(user, prefs)
	return FALSE

/datum/lobby_terminal/proc/settings_keys_open_screen(mob/user)
	// The names, categories and descriptions are in tg's asset (SettingsKeys.tsx fetches it).
	if(ui && !QDELETED(ui) && ui.window)
		if(ui.send_asset(get_asset_datum(/datum/asset/json/keybindings)))
			owner?.browse_queue_flush()
		if(QDELETED(src) || !ui || QDELETED(ui))
			return FALSE
	settings_keys_open = TRUE
	settings_keys_push(user)
	return FALSE

/// Sends the settings_keys block as a one-off update.
/datum/lobby_terminal/proc/settings_keys_push(mob/user)
	if(!settings_keys_open || !ui || QDELETED(ui))
		return
	if(!user)
		user = owner?.mob
	var/datum/preferences/prefs = settings_get_prefs(user)
	if(!prefs)
		return
	settings_keys_rev++
	ui.send_update(list("settings_keys" = list("rev" = settings_keys_rev, "binds" = prefs.lobby_compile_keys())))

/// tg's window changed a preference or a keybinding: the KEYS block too (coalesced).
/datum/lobby_terminal/settings_changed()
	. = ..()
	if(settings_keys_open)
		addtimer(CALLBACK(src, PROC_REF(settings_keys_push)), 0.2 SECONDS, TIMER_UNIQUE)

/// tg's keybindings middleware of these prefs, or null.
/datum/lobby_terminal/proc/settings_keys_middleware(datum/preferences/prefs)
	var/datum/preference_middleware/keybindings/middleware = locate() in prefs.middleware
	return middleware

/// TRUE when that is the name of a keybinding tg knows.
/datum/lobby_terminal/proc/settings_keys_known(keybind_name)
	return istext(keybind_name) && length(keybind_name) <= 100 && !isnull(GLOB.keybindings_by_name[keybind_name])

/**
 * One settings_keys_set. tg's set_keybindings() checks the name, the slot count and that every key
 * is text; this adds a tighter length cap and refuses empty and repeated keys in one list before
 * tg sees it.
 */
/datum/lobby_terminal/proc/settings_keys_set(mob/user, datum/preferences/prefs, keybind_name, list/hotkeys)
	if(!settings_keys_known(keybind_name))
		return FALSE
	if(!islist(hotkeys) || length(hotkeys) > LOBBY_KEYS_SLOTS)
		return settings_keys_refused(user)
	var/list/clean = list()
	for(var/hotkey in hotkeys)
		if(!istext(hotkey) || !length(hotkey) || length(hotkey) > LOBBY_KEYS_NAME_MAX || (hotkey in clean))
			return settings_keys_refused(user)
		clean += hotkey
	var/datum/preference_middleware/keybindings/middleware = settings_keys_middleware(prefs)
	if(!middleware?.set_keybindings(list("keybind_name" = keybind_name, "hotkeys" = clean), user))
		return settings_keys_refused(user)
	return settings_keys_edited(user, prefs)

/datum/lobby_terminal/proc/settings_keys_reset(mob/user, datum/preferences/prefs, keybind_name)
	if(!settings_keys_known(keybind_name))
		return FALSE
	var/datum/preference_middleware/keybindings/middleware = settings_keys_middleware(prefs)
	if(!middleware?.reset_keybinds_to_defaults(list("keybind_name" = keybind_name), user))
		return settings_keys_refused(user)
	return settings_keys_edited(user, prefs)

/datum/lobby_terminal/proc/settings_keys_reset_all(mob/user, datum/preferences/prefs)
	var/datum/preference_middleware/keybindings/middleware = settings_keys_middleware(prefs)
	if(!middleware?.reset_all_keybinds(list(), user))
		return settings_keys_refused(user)
	return settings_keys_edited(user, prefs)

/// A refused change: push the block so the page snaps back.
/datum/lobby_terminal/proc/settings_keys_refused(mob/user)
	settings_keys_push(user)
	return TRUE

/// After a change: SETTINGS' save timer and SAVED mark (settings_edited()), and the push.
/datum/lobby_terminal/proc/settings_keys_edited(mob/user, datum/preferences/prefs)
	settings_edited(user, prefs)
	settings_keys_push(user)
	return TRUE

/// The player's bindings: keybind_name -> its keys (tg's "Unbound" placeholder left out).
/datum/preferences/proc/lobby_compile_keys()
	SHOULD_NOT_SLEEP(TRUE)
	var/list/binds = list()
	for(var/keybind_name in key_bindings)
		var/list/keys = key_bindings[keybind_name]
		if(!islist(keys))
			continue
		var/list/shown = list()
		for(var/key in keys)
			if(istext(key) && key != "Unbound")
				shown += key
		if(length(shown))
			binds[keybind_name] = shown
	return binds

#undef LOBBY_KEYS_SLOTS
#undef LOBBY_KEYS_NAME_MAX
#undef LOBBY_KEYS_ACTS_PER_SECOND
