/**
 * Dock terminal SETTINGS, KEYS group (voidcrew/modules/lobby_terminal/lobby_settings_keys.dm):
 * a set with valid keys is stored, an unknown keybinding and a four-key list are refused, reset
 * restores one keybinding's default and reset all restores every default. Writes go through tg's
 * keybindings middleware, which calls user.client.update_special_keybinds(): the test user is a
 * stand-in whose client is a mock client.
 */

/// A terminal with no client or tgui window, editing a mock client's prefs.
/datum/lobby_terminal/lobby_keys_test
	var/datum/preferences/test_prefs

/datum/lobby_terminal/lobby_keys_test/New(datum/preferences/prefs)
	test_prefs = prefs // no ..(): no client, no window

/datum/lobby_terminal/lobby_keys_test/settings_get_prefs(mob/user)
	return test_prefs

/datum/lobby_terminal/lobby_keys_test/proc/act(action, list/params, user)
	settings_keys_act_count = 0
	return settings_keys_act(action, params || list(), user)

/// A mock client that takes tg's update_special_keybinds() call.
/datum/client_interface/lobby_keys_test
	var/keybind_updates = 0

/datum/client_interface/lobby_keys_test/proc/update_special_keybinds(datum/preferences/direct_prefs)
	keybind_updates++

/// What tg's middleware reads as `user`: only its client is used.
/datum/lobby_keys_test_user
	var/datum/client_interface/lobby_keys_test/client

/datum/unit_test/lobby_settings_keys

/datum/unit_test/lobby_settings_keys/Run()
	var/datum/client_interface/lobby_keys_test/mock = new
	var/datum/preferences/prefs = new(mock)
	mock.prefs = prefs
	var/datum/lobby_keys_test_user/user = new
	user.client = mock
	var/datum/lobby_terminal/lobby_keys_test/term = new(prefs)

	// A keybinding with a real default key.
	var/keybind_name
	var/datum/keybinding/keybinding
	for(var/name in GLOB.keybindings_by_name)
		var/datum/keybinding/candidate = GLOB.keybindings_by_name[name]
		if(length(candidate.classic_keys) && !("Unbound" in candidate.classic_keys))
			keybind_name = name
			keybinding = candidate
			break
	TEST_ASSERT(keybind_name, "no keybinding with a default key")
	var/list/default_keys = mock.hotkeys ? keybinding.hotkey_keys : keybinding.classic_keys

	// A set with valid keys is stored, through tg's middleware.
	term.act("settings_keys_set", list("keybind_name" = keybind_name, "hotkeys" = list("CtrlShiftNumpad5", "AltShiftNortheast", "F7")), user)
	var/list/stored = prefs.key_bindings[keybind_name]
	TEST_ASSERT_EQUAL(length(stored), 3, "a valid set was not stored")
	TEST_ASSERT_EQUAL(stored[1], "CtrlShiftNumpad5", "the first key was not stored")
	TEST_ASSERT_EQUAL(stored[3], "F7", "the third key was not stored")
	TEST_ASSERT(keybind_name in prefs.key_bindings_by_key["AltShiftNortheast"], "key_bindings_by_key was not rebuilt")
	TEST_ASSERT(mock.keybind_updates > 0, "tg's update_special_keybinds() was not called")
	TEST_ASSERT(prefs.lobby_compile_keys()[keybind_name], "the set is missing from the pushed block")

	// An empty list unbinds it.
	term.act("settings_keys_set", list("keybind_name" = keybind_name, "hotkeys" = list()), user)
	TEST_ASSERT_EQUAL(length(prefs.key_bindings[keybind_name]), 0, "an empty set did not unbind")
	TEST_ASSERT(!(keybind_name in prefs.lobby_compile_keys()), "an unbound keybinding is in the pushed block")

	// An unknown keybinding is refused and stores nothing.
	term.act("settings_keys_set", list("keybind_name" = "lobby_keys_test_no_such_bind", "hotkeys" = list("K")), user)
	TEST_ASSERT(!("lobby_keys_test_no_such_bind" in prefs.key_bindings), "an unknown keybinding was stored")

	// Four keys, a non-list, a non-text key and an overlong key are refused; the binding stays.
	term.act("settings_keys_set", list("keybind_name" = keybind_name, "hotkeys" = list("F1")), user)
	term.act("settings_keys_set", list("keybind_name" = keybind_name, "hotkeys" = list("F2", "F3", "F4", "F5")), user)
	TEST_ASSERT_EQUAL(prefs.key_bindings[keybind_name][1], "F1", "a four-key list replaced the binding")
	TEST_ASSERT_EQUAL(length(prefs.key_bindings[keybind_name]), 1, "a four-key list was stored")
	term.act("settings_keys_set", list("keybind_name" = keybind_name, "hotkeys" = "F2"), user)
	term.act("settings_keys_set", list("keybind_name" = keybind_name, "hotkeys" = list(5)), user)
	term.act("settings_keys_set", list("keybind_name" = keybind_name, "hotkeys" = list("[random_string(60, GLOB.alphabet)]")), user)
	TEST_ASSERT_EQUAL(prefs.key_bindings[keybind_name][1], "F1", "a bad hotkeys param replaced the binding")

	// Reset restores the default.
	term.act("settings_keys_reset", list("keybind_name" = keybind_name), user)
	TEST_ASSERT(compare_list(prefs.key_bindings[keybind_name], default_keys), "reset did not restore the default")

	// Reset all restores every default.
	term.act("settings_keys_set", list("keybind_name" = keybind_name, "hotkeys" = list("F9")), user)
	term.act("settings_keys_reset_all", list(), user)
	for(var/name in GLOB.default_hotkeys)
		TEST_ASSERT(compare_list(prefs.key_bindings[name], GLOB.default_hotkeys[name]), "reset all left [name] off its default")
	TEST_ASSERT_EQUAL(length(prefs.key_bindings), length(GLOB.default_hotkeys), "reset all kept extra keybindings")

	qdel(term)
	qdel(prefs)
	qdel(mock)
