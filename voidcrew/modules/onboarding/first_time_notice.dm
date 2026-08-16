/**
 * # First-Time Player Notice
 *
 * A one-time popup for players the server has never seen before, shown in the
 * lobby a moment after they connect. It exists because of a recorded loss: a
 * brand-new player's entire first visit was "connect / see combat mode /
 * disconnect", six seconds, and the veterans watching agreed the join info box
 * would not have saved him because nobody reads it.
 *
 * The popup does two things and stops: it says in one line what kind of server
 * this is, and it lets the player pick their melee control scheme - tg-style
 * combat mode or classic intents - writing the choice straight into their
 * saved preferences. The choice is the whole point: the "Use Intent System"
 * toggle already exists in Game Preferences, but a first-time player has no
 * reason to know it does (voidcrew/modules/intents/preferences.dm).
 *
 * Shown once per ckey, ever: answering any button writes a flag into the
 * player's preferences savefile. Closing the window without answering (or
 * disconnecting mid-prompt, which is exactly what the six-second player did)
 * leaves the flag unset, so their next visit asks again. This is distinct from
 * the orientation briefing in orientation.dm, which is per-round and only
 * fires after a spawn - a player who bounces off the lobby never reaches it.
 */

/// Preferences-savefile key marking that this player has answered the notice.
#define FIRST_TIME_NOTICE_SAVEFILE_KEY "voidcrew_seen_first_time_notice"

/// Gap between landing in the lobby and the popup opening, so it appears over
/// the loaded lobby screen rather than mid-join.
#define FIRST_TIME_NOTICE_DELAY (2 SECONDS)

/// Ckeys with a notice queued or open right now, so repeated lobby Logins
/// (round restarts) can't stack a second popup on an unanswered first one.
GLOBAL_LIST_EMPTY(first_time_notice_pending)

/mob/dead/new_player/Login()
	. = ..()
	if(!client || client.interviewee)
		return
	try_show_first_time_notice(client)

/**
 * Queues the notice for a client who has never answered it.
 *
 * Guests get the popup too but can never save the flag (their savefile has no
 * path), so they are asked each visit - acceptable, since a guest key is a
 * first-timer every time as far as the server can tell.
 */
/proc/try_show_first_time_notice(client/player)
	if(!player?.prefs?.savefile)
		return
	if(player.prefs.savefile.get_entry(FIRST_TIME_NOTICE_SAVEFILE_KEY, FALSE))
		return
	if(player.ckey in GLOB.first_time_notice_pending)
		return
	GLOB.first_time_notice_pending += player.ckey
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(show_first_time_notice), player.ckey), FIRST_TIME_NOTICE_DELAY)

/**
 * Timer landing point: opens the popup and applies the answer.
 *
 * waitfor = FALSE because tgui_alert sleeps and this is invoked from the timer
 * subsystem. The ckey is re-resolved to a client here rather than holding a
 * client ref across the delay, since the player may already be gone.
 */
/proc/show_first_time_notice(ckey)
	set waitfor = FALSE
	var/client/player = GLOB.directory[ckey]
	if(!player?.prefs?.savefile)
		GLOB.first_time_notice_pending -= ckey
		return

	var/message = {"Looks like this is your first time on this server.

Quick version: this is a /tg/station fork where small crews fly ships around a galaxy map. The outer band of the galaxy is completely safe - nothing out there can attack your ship or your crew, including other players.

One setting worth picking before you play: melee controls. The default is tg-style Combat Mode - press F (or 4) in game to raise or drop your guard. If you prefer the classic Help/Disarm/Grab/Harm intents from other SS13 servers, pick Classic Intents below and use the 1-4 keys to switch intent. You can change this any time under Game Preferences (the "Use Intent System" toggle)."}

	var/choice = tgui_alert(player, message, "Welcome!", list("Combat Mode", "Classic Intents", "Not Now"), timeout = 5 MINUTES)
	GLOB.first_time_notice_pending -= ckey

	// Re-resolve: the client can disconnect while the prompt is open, and the
	// prompt outliving its client is the normal case this feature exists for.
	player = GLOB.directory[ckey]
	if(!player?.prefs?.savefile)
		return
	if(isnull(choice)) // Timed out or closed without reading; ask again next visit
		return

	// write_preference, not update_preference: the latter refuses preferences
	// that aren't visible on the player's currently open prefs page, which from
	// the lobby is none of them.
	switch(choice)
		if("Classic Intents")
			player.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/use_intents], TRUE)
			to_chat(player, span_notice("Classic intents enabled. Use the 1-4 keys in game to switch intent. You can change this any time under Game Preferences."))
		if("Combat Mode")
			player.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/use_intents], FALSE)
			to_chat(player, span_notice("Combat mode it is - press F (or 4) in game to toggle it. You can switch to classic intents any time under Game Preferences."))
		if("Not Now")
			to_chat(player, span_notice("No problem. If you ever want classic Help/Disarm/Grab/Harm intents, the \"Use Intent System\" toggle is under Game Preferences."))

	player.prefs.savefile.set_entry(FIRST_TIME_NOTICE_SAVEFILE_KEY, TRUE)
	player.prefs.savefile.save()

#undef FIRST_TIME_NOTICE_DELAY
#undef FIRST_TIME_NOTICE_SAVEFILE_KEY
