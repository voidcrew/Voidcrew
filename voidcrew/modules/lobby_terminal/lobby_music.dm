/**
 * Title music and the start-up screen.
 *
 * A player whose terminal still has its start-up screen to play hears that screen's own sounds
 * first: the title music waits and starts when they press LOGIN. It starts at once when the
 * screen is not shown (a return to the lobby mid-round, an interview), and anyway when LOGIN
 * never comes: the terminal did not load and the classic lobby came back, or
 * LOBBY_MUSIC_HOLD_MAX passed.
 *
 * Everything that starts the title music goes through /client/proc/playtitlemusic()
 * (code/game/sound/sound.dm), so that is the one place overridden. The parent still reads the
 * player's own lobby music volume when the music does start.
 */

/// The longest the title music waits for LOGIN.
#define LOBBY_MUSIC_HOLD_MAX (20 SECONDS)

/// TRUE once this connection's title music no longer waits for the start-up screen.
/client/var/lobby_music_free = FALSE
/// The volume multiplier of the title music waiting for LOGIN, or null when none is waiting.
/client/var/lobby_music_held

/client/playtitlemusic(volume_multiplier = 1)
	if(lobby_music_waits())
		if(isnull(lobby_music_held))
			addtimer(CALLBACK(src, PROC_REF(lobby_music_release)), LOBBY_MUSIC_HOLD_MAX)
		lobby_music_held = volume_multiplier
		return
	return ..()

/// TRUE while the title music must wait: a lobby player whose terminal has not been logged in to yet.
/client/proc/lobby_music_waits()
	if(lobby_music_free)
		return FALSE
	// An interviewee gets the classic lobby and no terminal.
	if(!isnewplayer(mob) || interviewee)
		return FALSE
	// The terminal is made just after the first title music call of a connection, so none yet means "still to play".
	if(lobby_terminal?.boot_done)
		return FALSE
	return TRUE

/// Starts the title music that was waiting for LOGIN, if any. From then on this connection's title music never waits.
/client/proc/lobby_music_release()
	if(lobby_music_free)
		return
	lobby_music_free = TRUE
	var/held = lobby_music_held
	lobby_music_held = null
	if(isnull(held) || !isnewplayer(mob))
		return
	playtitlemusic(held)

#undef LOBBY_MUSIC_HOLD_MAX
