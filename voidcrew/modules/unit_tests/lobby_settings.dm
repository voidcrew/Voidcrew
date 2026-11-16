/**
 * Dock terminal SETTINGS section (voidcrew/modules/lobby_terminal/lobby_settings.dm): the block
 * lists only game preferences this player can see, toggle/choice/number writes land and survive
 * a re-read, bad keys and bad values are refused, admin-only and member-only preferences are
 * refused for a plain player, and tg's current_window trap doesn't hide them.
 */

/// A terminal with no client or tgui window, editing a mock client's prefs.
/datum/lobby_terminal/lobby_settings_test
	var/datum/preferences/test_prefs

/datum/lobby_terminal/lobby_settings_test/New(datum/preferences/prefs)
	test_prefs = prefs // no ..(): no client, no window

/datum/lobby_terminal/lobby_settings_test/settings_get_prefs(mob/user)
	return test_prefs

/datum/lobby_terminal/lobby_settings_test/proc/act(action, list/params)
	settings_act_count = 0
	return settings_act(action, params || list(), null)

/datum/unit_test/lobby_settings

/datum/unit_test/lobby_settings/Run()
	var/datum/client_interface/mock = new
	var/datum/preferences/prefs = new(mock)
	mock.prefs = prefs
	var/datum/lobby_terminal/lobby_settings_test/term = new(prefs)

	// The block: game preferences only, each accessible, none admin-only, none a character preference.
	var/list/keys = settings_keys(prefs)
	TEST_ASSERT(length(keys), "the settings block is empty")
	for(var/key in keys)
		var/datum/preference/preference = GLOB.preference_entries_by_key[key]
		TEST_ASSERT(preference, "unknown key [key] in the settings block")
		TEST_ASSERT_EQUAL(preference.category, PREFERENCE_CATEGORY_GAME_PREFERENCES, "[key] is not a game preference")
		TEST_ASSERT_EQUAL(preference.savefile_identifier, PREFERENCE_PLAYER, "[key] is not a player preference")
	TEST_ASSERT("windowflashing" in keys, "window flashing missing from the block")
	TEST_ASSERT(!("age" in keys), "a character preference is in the settings block")
	for(var/admin_key in list("asaycolor", "brief_outfit", "bypass_deadmin_in_centcom", "ghost_roles_as_admin", "comms_notification", "auto_deadmin_on_ready_or_latejoin"))
		TEST_ASSERT(!(admin_key in keys), "admin preference [admin_key] sent to a non-admin")

	// The current_window trap: with tg's window on the character tab the block is the same.
	prefs.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	var/list/on_char_tab = settings_keys(prefs)
	TEST_ASSERT_EQUAL(length(on_char_tab), length(keys), "game preferences hidden while tg's window is on the character tab")
	TEST_ASSERT_EQUAL(prefs.current_window, PREFERENCE_TAB_CHARACTER_PREFERENCES, "current_window changed by building the block")
	TEST_ASSERT_EQUAL(prefs.lobby_game_writes, 0, "lobby_game_writes left set")
	// The flag never opens game preferences to the character path, nor character ones here.
	var/datum/preference/age_pref = GLOB.preference_entries[/datum/preference/numeric/age]
	var/datum/preference/flash_pref = GLOB.preference_entries_by_key["windowflashing"]
	TEST_ASSERT(!flash_pref.is_accessible(prefs), "tg's window rule changed: a game pref accessible on the character tab without the flag")
	prefs.lobby_game_writes = 1
	TEST_ASSERT(flash_pref.is_accessible(prefs), "the flag does not open game prefs on the character tab")
	prefs.current_window = PREFERENCE_TAB_GAME_PREFERENCES
	TEST_ASSERT(!age_pref.is_accessible(prefs), "the game flag opened a character pref on the game tab")
	prefs.lobby_game_writes = 0
	prefs.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES

	// A toggle, written while tg's window is on the character tab.
	var/flash = prefs.read_preference(/datum/preference/toggle/window_flashing)
	TEST_ASSERT(term.act("settings_set", list("key" = "windowflashing", "value" = flash ? 0 : 1)), "toggle write refused")
	TEST_ASSERT_EQUAL(!!prefs.read_preference(/datum/preference/toggle/window_flashing), !flash, "toggle not written")
	TEST_ASSERT_EQUAL(settings_value(prefs, "windowflashing"), flash ? 0 : 1, "toggle not in the block after the write")
	TEST_ASSERT_EQUAL(prefs.current_window, PREFERENCE_TAB_CHARACTER_PREFERENCES, "current_window changed by a write")
	TEST_ASSERT_EQUAL(prefs.lobby_game_writes, 0, "lobby_game_writes left set after a write")
	term.act("settings_set", list("key" = "windowflashing", "value" = 5))
	TEST_ASSERT_EQUAL(!!prefs.read_preference(/datum/preference/toggle/window_flashing), !flash, "a toggle took 5")

	// A choice.
	var/datum/preference/choiced/others = GLOB.preference_entries[/datum/preference/choiced/ghost_others]
	var/was_other = prefs.read_preference(/datum/preference/choiced/ghost_others)
	var/next_other
	for(var/choice in others.get_choices())
		if(choice != was_other)
			next_other = choice
			break
	TEST_ASSERT(term.act("settings_set", list("key" = "ghost_others", "value" = others.serialize(next_other))), "choice write refused")
	TEST_ASSERT_EQUAL(prefs.read_preference(/datum/preference/choiced/ghost_others), next_other, "choice not written")
	TEST_ASSERT_EQUAL(settings_value(prefs, "ghost_others"), others.serialize(next_other), "choice not in the block after the write")
	term.act("settings_set", list("key" = "ghost_others", "value" = "Not a choice"))
	term.act("settings_set", list("key" = "ghost_others", "value" = list("White ghosts")))
	TEST_ASSERT_EQUAL(prefs.read_preference(/datum/preference/choiced/ghost_others), next_other, "a bad choice was written (or reset to the default)")

	// A number: in range and on a step only.
	TEST_ASSERT(term.act("settings_set", list("key" = "sound_instruments", "value" = 37)), "number write refused")
	TEST_ASSERT_EQUAL(prefs.read_preference(/datum/preference/numeric/volume/sound_instruments), 37, "number not written")
	TEST_ASSERT_EQUAL(settings_value(prefs, "sound_instruments"), 37, "number not in the block after the write")
	term.act("settings_set", list("key" = "sound_instruments", "value" = 101))
	term.act("settings_set", list("key" = "sound_instruments", "value" = -1))
	term.act("settings_set", list("key" = "sound_instruments", "value" = 37.5))
	term.act("settings_set", list("key" = "sound_instruments", "value" = "loud"))
	TEST_ASSERT_EQUAL(prefs.read_preference(/datum/preference/numeric/volume/sound_instruments), 37, "a bad number was written")

	// Keys the terminal must refuse.
	TEST_ASSERT(!term.act("settings_set", list("key" = "no_such_key", "value" = 1)), "unknown key accepted")
	TEST_ASSERT(!term.act("settings_set", list("key" = "age", "value" = 40)), "character preference written through settings_set")
	TEST_ASSERT(!term.act("settings_set", list("key" = list("windowflashing"), "value" = 1)), "list key accepted")
	TEST_ASSERT(!term.act("settings_set", list("key" = "chat_dead", "value" = 1)), "admin legacy toggle accepted without a client")
	TEST_ASSERT(!term.act("settings_nonsense"), "unknown action answered")

	// Admin-only and member-only preferences, refused for a plain player.
	var/outfit = prefs.read_preference(/datum/preference/choiced/brief_outfit)
	var/datum/preference/choiced/brief = GLOB.preference_entries[/datum/preference/choiced/brief_outfit]
	for(var/choice in brief.get_choices())
		if(choice != outfit)
			TEST_ASSERT(!term.act("settings_set", list("key" = "brief_outfit", "value" = brief.serialize(choice))), "admin preference written by a non-admin")
			break
	TEST_ASSERT_EQUAL(prefs.read_preference(/datum/preference/choiced/brief_outfit), outfit, "admin preference changed by a non-admin")
	TEST_ASSERT(!term.act("settings_set", list("key" = "asaycolor", "value" = "#123456")), "admin chat colour written by a non-admin")
	prefs.unlock_content = FALSE
	TEST_ASSERT(!term.act("settings_set", list("key" = "ghost_form", "value" = "ghost_red")), "member-only preference written by a non-member")
	var/list/form_row = settings_row(prefs, "ghost_form")
	TEST_ASSERT(form_row && form_row["locked"], "member-only preference not marked locked")

	qdel(term)

/// The keys of the settings block.
/datum/unit_test/lobby_settings/proc/settings_keys(datum/preferences/prefs)
	var/list/out = list()
	for(var/list/row in prefs.lobby_compile_settings(null))
		out += row["key"]
	return out

/// One row of the settings block, or null.
/datum/unit_test/lobby_settings/proc/settings_row(datum/preferences/prefs, key)
	for(var/list/row in prefs.lobby_compile_settings(null))
		if(row["key"] == key)
			return row
	return null

/// One value of the settings block, or null.
/datum/unit_test/lobby_settings/proc/settings_value(datum/preferences/prefs, key)
	var/list/row = settings_row(prefs, key)
	return row ? row["value"] : null
