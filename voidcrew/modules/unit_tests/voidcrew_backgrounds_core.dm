/// Backgrounds: owned by P1.

// Unit tests compile before the voidcrew defines: every BACKGROUND_* value below is a literal with
// its define named beside it.

/// A background with no key of its own, so the registry never picks it up. A test pins it under a key.
/datum/background/bg_core_test
	name = "Test start"
	/// Every player handed to roundstart()
	var/list/recorded = list()
	/// The memory line
	var/goal = "Hold the line."

/datum/background/bg_core_test/roundstart(list/mob/dead/new_player/players)
	recorded += players
	return list()

/datum/background/bg_core_test/goal_line(datum/background_state/state)
	return goal

/// Base for the core tests: pins registry entries and globals and puts them back afterwards
/datum/unit_test/voidcrew_backgrounds_core
	abstract_type = /datum/unit_test/voidcrew_backgrounds_core
	/// key -> the registry entry that was there before the test pinned it
	var/list/pinned_backgrounds = list()
	/// The real minted counts, put back afterwards
	var/list/saved_minted
	/// The real round lists, put back afterwards
	var/list/saved_states
	var/list/saved_minds

/datum/unit_test/voidcrew_backgrounds_core/New()
	. = ..()
	saved_minted = GLOB.background_hulls_minted.Copy()
	saved_states = GLOB.background_states.Copy()
	saved_minds = GLOB.background_minds.Copy()

/datum/unit_test/voidcrew_backgrounds_core/Destroy()
	for(var/key in pinned_backgrounds)
		if(pinned_backgrounds[key])
			GLOB.backgrounds[key] = pinned_backgrounds[key]
		else
			GLOB.backgrounds -= key
	GLOB.background_hulls_minted = saved_minted
	GLOB.background_states = saved_states
	GLOB.background_minds = saved_minds
	return ..()

/// Puts a test double under `key` until the test ends
/datum/unit_test/voidcrew_backgrounds_core/proc/pin_background(key)
	var/datum/background/bg_core_test/double = new
	double.key = key
	if(!(key in pinned_backgrounds))
		pinned_backgrounds[key] = GLOB.backgrounds[key]
	GLOB.backgrounds[key] = double
	return double

/// A lobby player with a stand-in client, so the start code counts them as connected
/datum/unit_test/voidcrew_backgrounds_core/proc/lobby_player()
	var/mob/dead/new_player/player = allocate(/mob/dead/new_player)
	player.mock_client = new /datum/client_interface
	return player

/// The preference defaults to Spacefarer and is never randomised
/datum/unit_test/voidcrew_backgrounds_core/preference

/datum/unit_test/voidcrew_backgrounds_core/preference/Run()
	var/datum/preference/choiced/background/preference = GLOB.preference_entries[/datum/preference/choiced/background]
	TEST_ASSERT_NOTNULL(preference, "The background preference is not registered")
	TEST_ASSERT_EQUAL(preference.create_default_value(), "spacefarer", "The background preference does not default to Spacefarer") // BACKGROUND_SPACEFARER
	TEST_ASSERT(!preference.can_randomize, "The background preference can be randomised")
	var/list/values = preference.init_possible_values()
	for(var/key in list("spacefarer", "convict", "homesteader", "bounty_hunter", "pirate")) // BACKGROUND_ALL_KEYS
		TEST_ASSERT(key in values, "The background preference does not offer [key]")
		TEST_ASSERT_NOTNULL(background_by_key(key), "No background is registered under [key]")

/// 10 ready players with 6 pirates: 2 start as pirates (25%), 4 overflow to Spacefarer
/datum/unit_test/voidcrew_backgrounds_core/share_caps

/datum/unit_test/voidcrew_backgrounds_core/share_caps/Run()
	var/datum/background/bg_core_test/pirate = pin_background("pirate") // BACKGROUND_PIRATE
	var/list/players = list()
	var/list/choices = list()
	for(var/count in 1 to 10)
		var/mob/dead/new_player/player = lobby_player()
		players += player
		choices[player] = count <= 6 ? "pirate" : "spacefarer" // BACKGROUND_PIRATE, BACKGROUND_SPACEFARER

	var/list/left = SSticker.run_background_starts(players, choices)
	TEST_ASSERT_EQUAL(length(pirate.recorded), 2, "10 ready players with 6 pirates should start 2 pirates (BACKGROUND_SHARE_PIRATE 0.25)")
	TEST_ASSERT_EQUAL(length(left), 8, "The 4 Spacefarers and the 4 pirate overflow should ship out with a crew")
	for(var/mob/dead/new_player/player as anything in players)
		var/started = (player in pirate.recorded)
		TEST_ASSERT(started != (player in left), "A player was both started and returned, or neither")
		if(choices[player] == "spacefarer")
			TEST_ASSERT(!started, "A Spacefarer was handed to the pirate start")

	// Ruling R1: one ready player may always try a share-capped start
	var/datum/background/bg_core_test/hunter = pin_background("bounty_hunter") // BACKGROUND_BOUNTY_HUNTER
	var/mob/dead/new_player/lone = lobby_player()
	var/mob/dead/new_player/other = lobby_player()
	left = SSticker.run_background_starts(list(lone, other), list((lone) = "bounty_hunter", (other) = "spacefarer"))
	TEST_ASSERT_EQUAL(length(hunter.recorded), 1, "A lone hunter among 2 ready players should still start (ruling R1)")
	TEST_ASSERT_EQUAL(length(left), 1, "Only the Spacefarer should be left to ship out with a crew")

	// No background chosen: everyone is handed straight back
	left = SSticker.run_background_starts(list(lone, other), list((lone) = "spacefarer", (other) = null))
	TEST_ASSERT_EQUAL(length(left), 2, "Spacefarers were held back from the fleet")

/// Three hulls a kind a round, destroyed ones included: the fourth is refused before any load
/datum/unit_test/voidcrew_backgrounds_core/minted_cap

/datum/unit_test/voidcrew_backgrounds_core/minted_cap/Run()
	var/datum/background/hull_start/pirate = background_by_key("pirate") // BACKGROUND_PIRATE
	TEST_ASSERT(istype(pirate), "The pirate background is not a hull start")
	GLOB.background_hulls_minted["pirate"] = 2
	TEST_ASSERT(background_hull_available("pirate"), "The third pirate hull was refused")
	GLOB.background_hulls_minted["pirate"] = 3 // BACKGROUND_MAX_HULLS_PER_KIND
	TEST_ASSERT(!background_hull_available("pirate"), "A fourth pirate hull was allowed")
	TEST_ASSERT_NULL(pirate.spawn_hull(), "spawn_hull() minted a fourth pirate hull")
	TEST_ASSERT_EQUAL(GLOB.background_hulls_minted["pirate"], 3, "A refused hull changed the minted count")
	var/list/new_entry
	for(var/list/entry as anything in pirate.latejoin_options(null))
		if(entry["id"] == "pirate:new")
			new_entry = entry
	TEST_ASSERT_NOTNULL(new_entry, "The join menu does not offer a new pirate ship")
	TEST_ASSERT_EQUAL(new_entry["refusal"], "None left", "The new pirate ship entry is open past the cap")
	TEST_ASSERT(!background_hull_available(null), "A hull with no background was allowed")

/// A ckey's second start ends its first; the memory is one line that never makes a story
/datum/unit_test/voidcrew_backgrounds_core/begin

/datum/unit_test/voidcrew_backgrounds_core/begin/Run()
	var/datum/background/bg_core_test/double = pin_background("bg_core_test")
	var/mob/living/carbon/human/first_body = bg_test_human(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/second_body = bg_test_human(run_loc_floor_bottom_left)
	// The same player, a second life
	second_body.mind.key = first_body.mind.key

	var/datum/background_state/first = background_begin(first_body.mind, "bg_core_test")
	TEST_ASSERT_NOTNULL(first, "background_begin() made no state")
	TEST_ASSERT_EQUAL(first.character_name, first_body.real_name, "The state did not take the character's name")
	TEST_ASSERT_EQUAL(first_body.mind.background_state, first, "The state is not on the mind")
	var/datum/memory/key/background/memory = first_body.mind.memories[/datum/memory/key/background]
	TEST_ASSERT_NOTNULL(memory, "background_begin() gave no memory")
	TEST_ASSERT(memory.memory_flags & MEMORY_NO_STORY, "The background memory can be used for stories")
	var/list/names = memory.get_names()
	TEST_ASSERT_EQUAL(length(names), 1, "The background memory should have exactly one name")
	TEST_ASSERT_EQUAL(memory.name, "Hold the line.", "The background memory does not read the goal line")

	double.goal = "Hold the line again."
	first.refresh_memory()
	var/count = 0
	for(var/memory_type in first_body.mind.memories)
		if(ispath(memory_type, /datum/memory/key/background))
			count++
	TEST_ASSERT_EQUAL(count, 1, "Refreshing the memory added a second one")
	memory = first_body.mind.memories[/datum/memory/key/background]
	TEST_ASSERT_EQUAL(memory.name, "Hold the line again.", "Refreshing the memory did not update its line")

	var/datum/background_state/second = background_begin(second_body.mind, "bg_core_test")
	TEST_ASSERT(first.ended, "The ckey's first state did not end when its second began")
	TEST_ASSERT_EQUAL(first.outcome, "ended", "The replaced state's outcome is not BACKGROUND_OUTCOME_ENDED")
	TEST_ASSERT(!second.ended, "The new state began ended")
	TEST_ASSERT_NULL(first_body.mind.memories[/datum/memory/key/background], "The ended life kept its goal memory")
	TEST_ASSERT_EQUAL(background_latest_state(second.ckey), second, "The ledger does not point at the newest state")
	var/list/active = background_active_minds("bg_core_test")
	TEST_ASSERT(second_body.mind in active, "The new life is not active")
	TEST_ASSERT(!(first_body.mind in active), "The ended life is still active")

	// Progress, settling and freezing
	second.goal_target = 2
	second.add_progress(1)
	TEST_ASSERT_EQUAL(second.outcome, "ongoing", "One of two settled the goal") // BACKGROUND_OUTCOME_ONGOING
	second.add_progress(1)
	TEST_ASSERT_EQUAL(second.outcome, "done", "Reaching goal_target did not complete the goal") // BACKGROUND_OUTCOME_DONE
	TEST_ASSERT(!second.fail("Too late."), "A settled goal was failed afterwards")
	background_end(second_body.mind, "failed") // BACKGROUND_OUTCOME_FAILED
	TEST_ASSERT(second.ended, "background_end() did not end the state")
	TEST_ASSERT_EQUAL(second.outcome, "done", "Ending a finished goal changed its outcome")
	second.add_progress(5)
	TEST_ASSERT_EQUAL(second.progress, 2, "An ended state still took progress")

/// Background hulls never sit in the ship list, and an abandoned one is ordinary salvage
/datum/unit_test/voidcrew_backgrounds_core/hulls

/datum/unit_test/voidcrew_backgrounds_core/hulls/Run()
	var/datum/background/bg_core_test/pirate = pin_background("pirate") // BACKGROUND_PIRATE
	var/obj/structure/overmap/ship/ship = bg_test_ship(/datum/map_template/shuttle/voidcrew/pill)
	TEST_ASSERT_NOTNULL(ship, "The test hull did not load")
	TEST_ASSERT_NULL(ship.background_key(), "An ordinary hull has a background")
	TEST_ASSERT(ship in get_joinable_ships(), "The ordinary test hull is not joinable")

	// Pin the template var: this hull is now a pirate start
	ship.source_template.background_start = "pirate"
	TEST_ASSERT_EQUAL(ship.background_key(), "pirate", "background_key() does not read the template")
	TEST_ASSERT(!(ship in get_joinable_ships()), "get_joinable_ships() lists a background hull")

	// A site arrival is begun by its own background, never by the join watcher
	var/mob/living/carbon/human/arrival = bg_test_human(run_loc_floor_bottom_left)
	arrival.mind.set_assigned_role(ship.job_slots[1])
	GLOB.background_site_arrivals[arrival.ckey] = TRUE
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_CREWMEMBER_JOINED, arrival, "Captain")
	GLOB.background_site_arrivals -= arrival.ckey
	TEST_ASSERT_NULL(arrival.mind.background_state, "The join watcher began a site arrival")
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_CREWMEMBER_JOINED, arrival, "Captain")
	TEST_ASSERT_NOTNULL(arrival.mind.background_state, "Joining a pirate hull began no background")
	TEST_ASSERT_EQUAL(arrival.mind.background_state.key, "pirate", "Joining a pirate hull began the wrong background")
	TEST_ASSERT_EQUAL(length(pirate.recorded), 0, "The join watcher called roundstart()")

	ship.abandon_ship(crash = FALSE)
	TEST_ASSERT_NULL(ship.background_key(), "background_key() is still set after abandon_ship()")

/// The join menu lists background hulls only under Other starts, and refuses what it cannot offer
/datum/unit_test/voidcrew_backgrounds_core/join_menu

/datum/unit_test/voidcrew_backgrounds_core/join_menu/Run()
	var/mob/dead/new_player/player = allocate(/mob/dead/new_player)
	player.key = "bgtestlobby"
	var/datum/ship_join_menu/menu = new(player)
	var/list/data = menu.ui_data(player)
	for(var/list/entry as anything in data["ships"])
		var/obj/structure/overmap/ship/listed = locate(entry["ref"])
		TEST_ASSERT(istype(listed), "The ship list holds an entry that is not a ship")
		TEST_ASSERT_NULL(listed.background_key(), "The ship list shows a background hull: [listed.name]")
	var/list/seen_ids = list()
	for(var/list/start as anything in data["starts"])
		TEST_ASSERT(istext(start["id"]), "An Other starts entry has no id")
		TEST_ASSERT(!(start["id"] in seen_ids), "Two Other starts entries share the id [start["id"]]")
		seen_ids += start["id"]
		TEST_ASSERT_NOTNULL(background_by_key(start["kind"]), "An Other starts entry has an unknown kind: [start["kind"]]")
		var/list/id_parts = splittext(start["id"], ":")
		if(length(id_parts) == 2 && id_parts[2] != "new")
			var/obj/structure/overmap/ship/hull = locate(id_parts[2])
			TEST_ASSERT(istype(hull), "A hull entry does not name a ship")
			TEST_ASSERT_EQUAL(hull.background_key(), start["kind"], "A hull entry names a ship of another background")
	TEST_ASSERT(!menu.background_join_act("select_ship", list()), "background_join_act() took an action that is not its own")
	TEST_ASSERT(menu.background_join_act("join_start", list("id" = "pirate:nowhere")), "background_join_act() did not handle join_start")
	qdel(menu)

/// The round-end section has one line per state, and Spacefarers are not listed
/datum/unit_test/voidcrew_backgrounds_core/roundend

/datum/unit_test/voidcrew_backgrounds_core/roundend/Run()
	pin_background("bg_core_test")
	GLOB.background_states = list()
	TEST_ASSERT_NULL(background_roundend_section(), "An empty round printed a Backgrounds section")
	var/mob/living/carbon/human/first_body = bg_test_human(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/second_body = bg_test_human(run_loc_floor_bottom_left)
	var/datum/background_state/first = background_begin(first_body.mind, "bg_core_test")
	var/datum/background_state/second = background_begin(second_body.mind, "bg_core_test")
	second.complete("Held it.")
	var/section = background_roundend_section()
	TEST_ASSERT_NOTNULL(section, "Two states printed no Backgrounds section")
	TEST_ASSERT(findtext(section, "Backgrounds"), "The section has no header")
	var/list/lines = splittext(section, "<br>")
	TEST_ASSERT_EQUAL(length(lines), 3, "The section should be a header and one line per state: [section]")
	TEST_ASSERT(findtext(section, first.character_name), "The first state is missing from the section")
	TEST_ASSERT(findtext(section, "[second.character_name], Test start: Held it."), "The settled state's line is wrong: [section]")
	var/personal = background_personal_line(second.ckey)
	TEST_ASSERT_EQUAL(personal, "You were [second.character_name], Test start. Held it.", "The personal line is wrong")

	var/mob/living/carbon/human/spacer = bg_test_human(run_loc_floor_bottom_left)
	background_begin(spacer.mind, "spacefarer") // BACKGROUND_SPACEFARER
	lines = splittext(background_roundend_section(), "<br>")
	TEST_ASSERT_EQUAL(length(lines), 3, "A Spacefarer was listed at round end")
