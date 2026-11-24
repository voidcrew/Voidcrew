/**
 * Dock terminal WELCOME box (lobby_bezel.dm, voidcrew/modules/onboarding/first_time_notice.dm):
 * due while the savefile flag is unset; each pick writes the control scheme and the flag; a bad
 * mode writes nothing; once answered, another pick changes nothing; LATER closes it for the
 * connection without answering.
 */

/// A terminal with no client or tgui window, answering for a mock client's prefs.
/datum/lobby_terminal/lobby_welcome_test
	var/datum/preferences/test_prefs

/datum/lobby_terminal/lobby_welcome_test/New(datum/preferences/prefs)
	test_prefs = prefs // no ..(): no client, no window

/datum/lobby_terminal/lobby_welcome_test/welcome_prefs(mob/user)
	return test_prefs

/datum/unit_test/lobby_welcome

/datum/unit_test/lobby_welcome/Run()
	var/datum/preference/intents = GLOB.preference_entries[/datum/preference/toggle/use_intents]
	var/mob/dead/new_player/player = allocate(/mob/dead/new_player)
	GLOB.new_player_list -= player

	// INTENTS: the pref goes on and the flag is set.
	var/datum/lobby_terminal/lobby_welcome_test/term = new(new_test_prefs())
	TEST_ASSERT(first_time_notice_due(term.test_prefs), "not due on a fresh savefile")
	TEST_ASSERT_EQUAL(welcome_field(term, player), 1, "the welcome field is not 1 on a fresh savefile")
	term.shell_act("welcome_pick", list("mode" = "bogus"), player)
	TEST_ASSERT(first_time_notice_due(term.test_prefs), "a bad mode set the flag")
	TEST_ASSERT_EQUAL(term.test_prefs.read_preference(intents.type), FALSE, "a bad mode wrote the pref")
	term.shell_act("welcome_pick", list(), player)
	TEST_ASSERT(first_time_notice_due(term.test_prefs), "a missing mode set the flag")
	term.shell_act("welcome_pick", list("mode" = "intents"), player)
	TEST_ASSERT(!first_time_notice_due(term.test_prefs), "INTENTS did not set the flag")
	TEST_ASSERT_EQUAL(term.test_prefs.read_preference(intents.type), TRUE, "INTENTS did not turn intents on")
	TEST_ASSERT_EQUAL(welcome_field(term, player), 0, "the welcome field is still 1 after a pick")
	// Answered: a second pick does nothing.
	TEST_ASSERT(!term.shell_act("welcome_pick", list("mode" = "combat"), player), "a second pick was accepted")
	TEST_ASSERT_EQUAL(term.test_prefs.read_preference(intents.type), TRUE, "a second pick changed the pref")

	// COMBAT MODE: the pref goes off, from on.
	term = new(new_test_prefs())
	term.test_prefs.write_preference(intents, TRUE)
	term.shell_act("welcome_pick", list("mode" = "combat"), player)
	TEST_ASSERT(!first_time_notice_due(term.test_prefs), "COMBAT MODE did not set the flag")
	TEST_ASSERT_EQUAL(term.test_prefs.read_preference(intents.type), FALSE, "COMBAT MODE did not turn intents off")

	// LATER: gone for the connection, still due next visit.
	term = new(new_test_prefs())
	term.shell_act("welcome_later", list(), player)
	TEST_ASSERT_EQUAL(welcome_field(term, player), 0, "the welcome field is still 1 after LATER")
	TEST_ASSERT(first_time_notice_due(term.test_prefs), "LATER set the flag")

/datum/unit_test/lobby_welcome/proc/new_test_prefs()
	var/datum/client_interface/mock = new
	var/datum/preferences/prefs = new(mock)
	mock.prefs = prefs
	return prefs

/datum/unit_test/lobby_welcome/proc/welcome_field(datum/lobby_terminal/term, mob/dead/new_player/player)
	var/list/data = list()
	term.shell_data(player, data)
	return data["welcome"]
