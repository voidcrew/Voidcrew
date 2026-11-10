/**
 * Dock terminal CHARACTER section (voidcrew/modules/lobby_terminal/lobby_character*.dm).
 * Written by package C1: crafted char_* acts for quirk budget and caps, species-blocked
 * quirks, bad loadout paths and colours, names with markup, out-of-range slots, game-pref
 * and deny-listed keys in char_set, the species confirm, and writes while tg's window is
 * on the game tab.
 */

/// A terminal with no client or tgui window, editing a mock client's prefs.
/datum/lobby_terminal/lobby_char_test
	var/datum/preferences/test_prefs

/datum/lobby_terminal/lobby_char_test/New(datum/preferences/prefs)
	test_prefs = prefs // no ..(): no client, no window

/datum/lobby_terminal/lobby_char_test/char_get_prefs(mob/user)
	return test_prefs

/datum/lobby_terminal/lobby_char_test/char_preview_request(dir)
	return // keep the renderer out of this test

/datum/lobby_terminal/lobby_char_test/proc/act(action, list/params)
	char_act_count = 0
	return char_act(action, params || list(), null)

/datum/unit_test/lobby_character

/datum/unit_test/lobby_character/Run()
	var/datum/client_interface/mock = new
	var/datum/preferences/prefs = new(mock)
	mock.prefs = prefs
	var/datum/lobby_terminal/lobby_char_test/term = new(prefs)
	prefs.all_quirks = list()
	TEST_ASSERT(term.act("char_set", list("key" = "species", "value" = SPECIES_HUMAN)) || prefs.read_preference(/datum/preference/choiced/species) == /datum/species/human, "could not start as a human")

	// is_accessible: tg's rule without the flag, both windows; the flag never opens game prefs.
	var/datum/preference/age_pref = GLOB.preference_entries[/datum/preference/numeric/age]
	var/datum/preference/fancy_pref = GLOB.preference_entries_by_key["tgui_fancy"]
	prefs.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	TEST_ASSERT(age_pref.is_accessible(prefs), "age not accessible on the character tab")
	TEST_ASSERT(!fancy_pref.is_accessible(prefs), "a game pref is accessible on the character tab")
	prefs.current_window = PREFERENCE_TAB_GAME_PREFERENCES
	TEST_ASSERT(!age_pref.is_accessible(prefs), "tg's window rule changed: age accessible on the game tab without the flag")
	TEST_ASSERT(fancy_pref.is_accessible(prefs), "a game pref is not accessible on the game tab")
	prefs.lobby_char_writes = 1
	TEST_ASSERT(age_pref.is_accessible(prefs), "the flag does not open character prefs on the game tab")
	TEST_ASSERT(fancy_pref.is_accessible(prefs), "the flag closed a game pref on the game tab")
	TEST_ASSERT_EQUAL(prefs.current_window, PREFERENCE_TAB_GAME_PREFERENCES, "is_accessible did not restore current_window")
	prefs.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	TEST_ASSERT(!fancy_pref.is_accessible(prefs), "the flag opened a game pref on the character tab")
	prefs.lobby_char_writes = 0

	// The current_window trap: a terminal write while tg's window is on the game tab succeeds.
	prefs.current_window = PREFERENCE_TAB_GAME_PREFERENCES
	TEST_ASSERT(term.act("char_set", list("key" = "age", "value" = 31)), "age write refused while tg's window is on the game tab")
	TEST_ASSERT_EQUAL(prefs.read_preference(/datum/preference/numeric/age), 31, "age not written")
	TEST_ASSERT_EQUAL(prefs.current_window, PREFERENCE_TAB_GAME_PREFERENCES, "current_window changed by a terminal write")
	TEST_ASSERT_EQUAL(prefs.lobby_char_writes, 0, "lobby_char_writes left set")
	TEST_ASSERT(length(prefs.lobby_compile_char(null)), "lobby_compile_char empty while tg's window is on the game tab")
	prefs.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES

	// Keys the terminal must refuse.
	TEST_ASSERT(!term.act("char_set", list("key" = "tgui_fancy", "value" = 0)), "game pref written through char_set")
	TEST_ASSERT(!term.act("char_set", list("key" = "random_name", "value" = "Always")), "deny-listed key written")
	TEST_ASSERT(!term.act("char_set", list("key" = "ai_name", "value" = "HAL")), "alt-name written")
	TEST_ASSERT(!term.act("char_set", list("key" = "loadout_list", "value" = list("/obj/item/gun/energy/pulse" = list()))), "loadout written through char_set")
	TEST_ASSERT(!term.act("char_set", list("key" = "no_such_key", "value" = 1)), "unknown key accepted")
	TEST_ASSERT(!term.act("char_set", list("key" = list("age"), "value" = 40)), "list key accepted")
	TEST_ASSERT(!("ai_name" in prefs.lobby_compile_char(null)), "alt-name sent to the client")

	// Names: markup and length never survive.
	term.act("char_set", list("key" = "real_name", "value" = "<b>Mara</b> <script>Voss"))
	var/name = prefs.read_preference(/datum/preference/name/real_name)
	TEST_ASSERT(!findtext(name, "<") && !findtext(name, ">"), "markup kept in a name: [name]")
	term.act("char_set", list("key" = "real_name", "value" = "Mara [repeat_string(300, "a")]"))
	name = prefs.read_preference(/datum/preference/name/real_name)
	TEST_ASSERT(length_char(name) <= MAX_NAME_LEN, "name over MAX_NAME_LEN")

	// Colours.
	TEST_ASSERT(!term.act("char_set", list("key" = "eye_color", "value" = "nothex")), "bad hex accepted")
	TEST_ASSERT(!term.act("char_set", list("key" = "eye_color", "value" = "#12ab3")), "5-digit hex accepted")
	TEST_ASSERT(term.act("char_set", list("key" = "eye_color", "value" = "#1A2B3C")), "good hex refused")
	TEST_ASSERT_EQUAL(lowertext(prefs.read_preference(/datum/preference/color/eye_color)), "#1a2b3c", "eye colour not written")
	TEST_ASSERT(!term.act("char_color_pick", list("key" = "underwear_color")), "native picker opened for a non-BODY colour")

	// Slots.
	var/start_slot = prefs.default_slot
	TEST_ASSERT(!term.act("char_slot", list("slot" = 0)), "slot 0 accepted")
	TEST_ASSERT(!term.act("char_slot", list("slot" = 99)), "slot 99 accepted")
	TEST_ASSERT(!term.act("char_slot", list("slot" = 1.5)), "slot 1.5 accepted")
	TEST_ASSERT(!term.act("char_slot", list("slot" = "abc")), "slot abc accepted")
	TEST_ASSERT_EQUAL(prefs.default_slot, start_slot, "bad slot changed the slot")
	var/other_slot = start_slot == 1 ? 2 : 1
	TEST_ASSERT(term.act("char_slot", list("slot" = other_slot)), "valid slot refused")
	TEST_ASSERT_EQUAL(prefs.default_slot, other_slot, "slot not switched")
	TEST_ASSERT(term.act("char_slot", list("slot" = start_slot)), "switching back refused")
	TEST_ASSERT_EQUAL(prefs.read_preference(/datum/preference/numeric/age), 31, "slot switch lost the age")
	prefs.all_quirks = list()
	term.act("char_set", list("key" = "species", "value" = SPECIES_HUMAN))

	// Roles: one HIGH. (Category names as text: the unit tests are included before JOB_CAT_* is defined.)
	TEST_ASSERT(!term.act("char_role", list("category" = "Nope", "level" = 3)), "unknown category accepted")
	TEST_ASSERT(!term.act("char_role", list("category" = "Cargo", "level" = 7)), "level 7 accepted")
	TEST_ASSERT(term.act("char_role", list("category" = "Engineering", "level" = 3)), "HIGH refused")
	TEST_ASSERT(term.act("char_role", list("category" = "Cargo", "level" = 3)), "second HIGH refused")
	TEST_ASSERT_EQUAL(prefs.ship_category_preferences["Engineering"], JP_MEDIUM, "old HIGH not demoted to MED")
	TEST_ASSERT_EQUAL(prefs.ship_category_preferences["Cargo"], JP_HIGH, "new HIGH not set")
	TEST_ASSERT(term.act("char_role", list("category" = "Cargo", "level" = 0)), "NEVER refused")
	TEST_ASSERT(isnull(prefs.ship_category_preferences["Cargo"]), "NEVER kept the role")

	check_quirks(term, prefs)
	check_species_confirm(term, prefs)
	check_kit(term, prefs)

	// Action spam: the 21st act in one second is dropped.
	term.char_act_count = 0
	term.char_act_window = world.time
	for(var/i in 1 to 20)
		term.char_act("char_turn", list("dir" = SOUTH), null)
	TEST_ASSERT(!term.char_act("char_turn", list("dir" = SOUTH), null), "action spam not limited")
	TEST_ASSERT(!term.act("char_turn", list("dir" = 3)), "diagonal facing accepted")
	TEST_ASSERT(!term.act("char_no_such_action"), "unknown action accepted")

	qdel(term)

/// Points and the positive cap: the client can't push past either.
/datum/unit_test/lobby_character/proc/check_quirks(datum/lobby_terminal/lobby_char_test/term, datum/preferences/prefs)
	prefs.all_quirks = list()
	var/list/all = SSquirks.get_quirks()
	var/points_enabled = !CONFIG_GET(flag/disable_quirk_points)
	var/max_positive = CONFIG_GET(number/max_positive_quirks)
	TEST_ASSERT(!term.act("char_quirk", list("quirk" = "No Such Quirk", "on" = 1)), "unknown quirk accepted")

	if(points_enabled)
		for(var/quirk_name in all)
			if(SSquirks.quirk_points[quirk_name] > 0)
				TEST_ASSERT(!term.act("char_quirk", list("quirk" = quirk_name, "on" = 1)), "positive quirk [quirk_name] taken with no points")
				TEST_ASSERT(!length(prefs.all_quirks), "quirk list changed by a refused quirk")
				break

	// Fund with negatives, then take every positive the server allows (by quirk_info key).
	for(var/quirk_name in all)
		if(SSquirks.quirk_points[quirk_name] < 0)
			term.act("char_quirk", list("quirk" = sanitize_css_class_name(quirk_name), "on" = 1))
	for(var/quirk_name in all)
		if(SSquirks.quirk_points[quirk_name] > 0)
			term.act("char_quirk", list("quirk" = sanitize_css_class_name(quirk_name), "on" = 1))
	TEST_ASSERT(SSquirks.filter_invalid_quirks(prefs.all_quirks) == prefs.all_quirks, "terminal built an invalid quirk set: [jointext(prefs.all_quirks, ", ")]")
	if(max_positive >= 0)
		TEST_ASSERT(prefs.GetPositiveQuirkCount() <= max_positive, "over the positive quirk cap")
	if(points_enabled)
		TEST_ASSERT(prefs.GetQuirkBalance() >= 0, "quirk points negative")
	prefs.all_quirks = list()

/// A species that blocks a quirk: can't take it there, and switching to it asks first.
/datum/unit_test/lobby_character/proc/check_species_confirm(datum/lobby_terminal/lobby_char_test/term, datum/preferences/prefs)
	var/datum/preference/choiced/species/species_pref = GLOB.preference_entries[/datum/preference/choiced/species]
	var/blocking_id
	var/blocked_quirk
	for(var/datum/species/species_type as anything in species_pref.get_choices())
		if(species_type == /datum/species/human)
			continue
		var/species_id = initial(species_type.id)
		for(var/quirk_name in SSquirks.get_quirks())
			if(SSquirks.quirk_points[quirk_name] > 0)
				continue
			var/datum/quirk/prototype = SSquirks.quirk_prototypes[SSquirks.quirks[quirk_name]]
			if(!prototype || prototype.is_species_appropriate(species_type) || !prototype.is_species_appropriate(/datum/species/human))
				continue
			blocking_id = species_id
			blocked_quirk = quirk_name
			break
		if(blocking_id)
			break
	if(!blocking_id)
		TEST_NOTICE(src, "No selectable species blocks a free quirk; species confirm not exercised.")
		return

	prefs.all_quirks = list()
	TEST_ASSERT(term.act("char_set", list("key" = "species", "value" = blocking_id)), "species [blocking_id] refused")
	TEST_ASSERT(!term.act("char_quirk", list("quirk" = blocked_quirk, "on" = 1)), "species-blocked quirk [blocked_quirk] taken")
	TEST_ASSERT(term.act("char_set", list("key" = "species", "value" = SPECIES_HUMAN)), "back to human refused")
	TEST_ASSERT(term.act("char_quirk", list("quirk" = blocked_quirk, "on" = 1)), "[blocked_quirk] refused for a human")

	// Without confirm (and a client-sent confirm=1 changes nothing): asks, doesn't change.
	TEST_ASSERT(term.act("char_set", list("key" = "species", "value" = blocking_id, "confirm" = 1)), "species change not handled")
	TEST_ASSERT_EQUAL(prefs.read_preference(/datum/preference/choiced/species), /datum/species/human, "species changed without confirm")
	TEST_ASSERT(term.char_confirm_state, "no confirm asked")
	TEST_ASSERT(blocked_quirk in term.char_confirm_state["quirks"], "confirm does not name [blocked_quirk]")
	// Cancel.
	TEST_ASSERT(term.act("char_confirm", list("ok" = 0)), "cancel not handled")
	TEST_ASSERT(isnull(term.char_confirm_state), "cancel kept the confirm")
	TEST_ASSERT_EQUAL(prefs.read_preference(/datum/preference/choiced/species), /datum/species/human, "cancel changed the species")
	// Another edit clears a pending confirm.
	term.act("char_set", list("key" = "species", "value" = blocking_id))
	term.act("char_set", list("key" = "age", "value" = 32))
	TEST_ASSERT(!term.act("char_confirm", list("ok" = 1)), "stale confirm applied")
	TEST_ASSERT_EQUAL(prefs.read_preference(/datum/preference/choiced/species), /datum/species/human, "stale confirm changed the species")
	// Change.
	term.act("char_set", list("key" = "species", "value" = blocking_id))
	TEST_ASSERT(term.act("char_confirm", list("ok" = 1)), "change not handled")
	TEST_ASSERT_EQUAL(prefs.read_preference(/datum/preference/choiced/species), GLOB.species_list[blocking_id], "confirmed species not set")
	TEST_ASSERT(!(blocked_quirk in prefs.all_quirks), "blocked quirk kept after the change")

	prefs.all_quirks = list()
	term.act("char_set", list("key" = "species", "value" = SPECIES_HUMAN))

/// Loadout: only real loadout items, colour slots in range, names escaped and capped.
/datum/unit_test/lobby_character/proc/check_kit(datum/lobby_terminal/lobby_char_test/term, datum/preferences/prefs)
	TEST_ASSERT(!term.act("char_kit", list("path" = "/obj/item/gun/energy/pulse", "on" = 1)), "non-loadout item packed")
	TEST_ASSERT(!term.act("char_kit", list("path" = "/datum/loadout_item", "on" = 1)), "datum path packed")
	TEST_ASSERT(!term.act("char_kit", list("path" = "nonsense", "on" = 1)), "nonsense path packed")
	TEST_ASSERT(!length(prefs.read_preference(/datum/preference/loadout)), "a refused item reached the loadout")

	var/datum/loadout_item/grey_item
	var/datum/loadout_item/named_item
	for(var/path in GLOB.all_loadout_datums)
		var/datum/loadout_item/item = GLOB.all_loadout_datums[path]
		if(!grey_item && lobby_char_kit_color_count(item))
			grey_item = item
		if(!named_item && item.can_be_named)
			named_item = item

	if(grey_item)
		var/path = "[grey_item.item_path]"
		var/count = lobby_char_kit_color_count(grey_item)
		TEST_ASSERT(term.act("char_kit", list("path" = path, "on" = 1)), "loadout item [path] refused")
		TEST_ASSERT(!term.act("char_kit_color", list("path" = path, "slot" = count, "color" = "#123456")), "colour slot past the end accepted")
		TEST_ASSERT(!term.act("char_kit_color", list("path" = path, "slot" = -1, "color" = "#123456")), "negative colour slot accepted")
		TEST_ASSERT(!term.act("char_kit_color", list("path" = path, "slot" = 0, "color" = "red;")), "bad kit colour accepted")
		TEST_ASSERT(term.act("char_kit_color", list("path" = path, "slot" = 0, "color" = "#123456")), "good kit colour refused")
		var/list/loadout = prefs.read_preference(/datum/preference/loadout)
		var/list/colors = SSgreyscale.ParseColorString(loadout[grey_item.item_path][INFO_GREYSCALE])
		TEST_ASSERT_EQUAL(length(colors), count, "wrong number of kit colours")
		TEST_ASSERT_EQUAL(colors[1], "#123456", "kit colour not written")
		TEST_ASSERT(term.act("char_kit", list("path" = path, "on" = 0)), "unpacking refused")
		TEST_ASSERT(!term.act("char_kit_color", list("path" = path, "slot" = 0, "color" = "#123456")), "colour set on an unpacked item")

	if(named_item)
		var/path = "[named_item.item_path]"
		TEST_ASSERT(term.act("char_kit", list("path" = path, "on" = 1)), "nameable item [path] refused")
		TEST_ASSERT(!term.act("char_kit_name", list("path" = path, "name" = "<script>x</script>")), "markup kit name accepted")
		TEST_ASSERT(!term.act("char_kit_name", list("path" = path, "name" = repeat_string(MAX_NAME_LEN + 1, "a"))), "kit name over the cap accepted")
		TEST_ASSERT(term.act("char_kit_name", list("path" = path, "name" = "Lucky & Co")), "plain kit name refused")
		var/list/loadout = prefs.read_preference(/datum/preference/loadout)
		TEST_ASSERT_EQUAL(loadout[named_item.item_path][INFO_NAMED], "Lucky &amp; Co", "kit name not stored escaped")
		TEST_ASSERT(term.act("char_kit_name", list("path" = path, "name" = "")), "clearing the kit name refused")
		loadout = prefs.read_preference(/datum/preference/loadout)
		TEST_ASSERT(isnull(loadout[named_item.item_path][INFO_NAMED]), "kit name not cleared")
		term.act("char_kit", list("path" = path, "on" = 0))
