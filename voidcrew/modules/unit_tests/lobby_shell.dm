/**
 * Dock terminal shell (voidcrew/modules/lobby_terminal/lobby_bezel.dm): observe_confirm is
 * refused while the server is still starting, and goes straight to the observer proc with
 * the confirm already given once it has started.
 */

/// A terminal with no client or tgui window.
/datum/lobby_terminal/lobby_shell_test

/datum/lobby_terminal/lobby_shell_test/New()
	return // no ..(): no client, no window

/// A lobby mob that records the observe call instead of becoming an observer.
/mob/dead/new_player/lobby_shell_test
	var/observed = 0
	var/observed_confirmed = FALSE

/mob/dead/new_player/lobby_shell_test/make_me_an_observer(confirmed = FALSE)
	observed++
	observed_confirmed = confirmed
	return FALSE

/datum/unit_test/lobby_shell

/datum/unit_test/lobby_shell/Run()
	var/datum/lobby_terminal/lobby_shell_test/term = new
	var/mob/dead/new_player/lobby_shell_test/player = allocate(/mob/dead/new_player/lobby_shell_test)
	GLOB.new_player_list -= player
	var/old_state = SSticker.current_state

	SSticker.current_state = GAME_STATE_STARTUP
	term.shell_act("observe_confirm", list(), player)
	SSticker.current_state = old_state
	TEST_ASSERT_EQUAL(player.observed, 0, "observe_confirm went through while the server was starting")

	SSticker.current_state = GAME_STATE_PLAYING
	term.shell_act("observe_confirm", list(), player)
	SSticker.current_state = old_state
	TEST_ASSERT_EQUAL(player.observed, 1, "observe_confirm did not reach the observer proc once the server had started")
	TEST_ASSERT(player.observed_confirmed, "observe_confirm did not pass the confirm on, so the native box would ask again")

	// dismiss with a stale time leaves a newer notice alone; with the matching time it clears it.
	term.notice = list("text" = "Newer.", "kind" = "warn", "at" = 50)
	term.shell_act("dismiss", list("at" = 10), player)
	TEST_ASSERT_NOTNULL(term.notice, "dismiss with a stale time cleared a newer notice")
	term.shell_act("dismiss", list("at" = 50), player)
	TEST_ASSERT_NULL(term.notice, "dismiss with the notice's time did not clear it")
