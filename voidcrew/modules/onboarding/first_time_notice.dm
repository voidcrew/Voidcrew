/**
 * # First-Time Player Notice
 *
 * A one-time question for players the server has never seen before: which melee controls they
 * want, tg-style combat mode or classic intents, written straight into their saved preferences.
 * It exists because of a recorded loss: a brand-new player's entire first visit was "connect /
 * see combat mode / disconnect", six seconds. The "Use Intent System" toggle already exists in
 * Game Preferences (voidcrew/modules/intents/preferences.dm), but a first-time player has no
 * reason to know it does.
 *
 * The dock terminal asks it in its own WELCOME box (lobby_bezel.dm, the welcome data field and
 * the welcome_pick / welcome_later actions). When the terminal fails to load and the classic
 * lobby comes back instead, the native popup below asks it (show_first_time_notice()).
 *
 * Shown once per ckey, ever: a pick writes a flag into the player's preferences savefile.
 * LATER, or closing the popup without answering, leaves the flag unset, so their next visit asks
 * again. Guests have no savefile path, so they are asked every visit. This is distinct from the
 * orientation briefing in orientation.dm, which is per-round and only fires after a spawn.
 */

/// Preferences-savefile key marking that this player has answered the notice.
#define FIRST_TIME_NOTICE_SAVEFILE_KEY "voidcrew_seen_first_time_notice"

/// Ckeys with the native popup open right now, so it can't stack a second one on an unanswered
/// first, and the terminal doesn't ask in its own box at the same time.
GLOBAL_LIST_EMPTY(first_time_notice_pending)

/// TRUE when these preferences have never answered the notice. An in-memory lookup, cheap enough for ui_data.
/proc/first_time_notice_due(datum/preferences/prefs)
	if(!prefs?.savefile)
		return FALSE
	return !prefs.savefile.get_entry(FIRST_TIME_NOTICE_SAVEFILE_KEY, FALSE)

/**
 * Applies an answer: the control scheme, then the flag, then a save. FALSE when there was
 * nothing to answer (no savefile, or already answered), so a second pick changes nothing.
 */
/proc/first_time_notice_answer(datum/preferences/prefs, use_intents)
	if(!first_time_notice_due(prefs))
		return FALSE
	// write_preference, not update_preference: the latter refuses preferences that aren't
	// visible on the player's currently open prefs page, which from the lobby is none of them.
	prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/use_intents], use_intents ? TRUE : FALSE)
	prefs.savefile.set_entry(FIRST_TIME_NOTICE_SAVEFILE_KEY, TRUE)
	prefs.savefile.save()
	return TRUE

/**
 * The native popup, for when the dock terminal did not load (lobby_terminal on_load_timeout()).
 *
 * waitfor = FALSE because tgui_alert sleeps. The ckey is re-resolved to a client after the
 * prompt rather than holding a client ref across it, since the player may already be gone.
 */
/proc/show_first_time_notice(ckey)
	set waitfor = FALSE
	var/client/player = GLOB.directory[ckey]
	if(!player || player.interviewee || !first_time_notice_due(player.prefs))
		return
	if(ckey in GLOB.first_time_notice_pending)
		return
	GLOB.first_time_notice_pending += ckey

	var/message = "First time here. Pick your melee controls. Combat Mode: F raises or drops your guard. Classic Intents: help, disarm, grab and harm on keys 1-4. Game Preferences can change it later."
	var/choice = tgui_alert(player, message, "Welcome", list("Combat Mode", "Classic Intents", "Not Now"), timeout = 5 MINUTES)
	GLOB.first_time_notice_pending -= ckey

	// Re-resolve: the client can disconnect while the prompt is open.
	player = GLOB.directory[ckey]
	if(!player)
		return
	switch(choice)
		if("Combat Mode")
			first_time_notice_answer(player.prefs, FALSE)
		if("Classic Intents")
			first_time_notice_answer(player.prefs, TRUE)
	// Not Now, closed or timed out: ask again next visit.

#undef FIRST_TIME_NOTICE_SAVEFILE_KEY
