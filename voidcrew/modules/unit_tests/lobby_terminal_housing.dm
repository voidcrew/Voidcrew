/**
 * Dock terminal HOUSING (voidcrew/modules/lobby_terminal/lobby_housing.dm): which refusals the page draws on
 * an outpost's block, that a sent request raises no notice, that a second press keeps a CONFIRMED box, and
 * that every notice fits one line.
 */

/// Voidcrew defines load after the unit tests, so these mirror them.
#define LOBBY_HOUSING_TEST_LOCKDOWN "lockdown" // OUTPOST_DOCK_MODE_LOCKDOWN
#define LOBBY_HOUSING_TEST_OPEN_DOCK "open" // OUTPOST_DOCK_MODE_OPEN
/// The longest notice the notice row holds on one line.
#define LOBBY_HOUSING_TEST_NOTICE_MAX 59
#define LOBBY_HOUSING_TEST_KEY "housingtest"

/// A terminal with no client or window. The residents on shift are stand-ins: no test mob has a client.
/datum/lobby_terminal/housing_test
	var/list/fake_recipients = list()

/datum/lobby_terminal/housing_test/New()
	return

/datum/lobby_terminal/housing_test/housing_request_recipients(obj/structure/overmap/dynamic/player_outpost/home)
	return fake_recipients.Copy()

/datum/unit_test/lobby_terminal_housing
	var/old_ticker_state

/datum/unit_test/lobby_terminal_housing/New()
	. = ..()
	old_ticker_state = SSticker.current_state

/datum/unit_test/lobby_terminal_housing/Destroy()
	SSticker.current_state = old_ticker_state
	for(var/entry_key in GLOB.lobby_housing_requests.Copy())
		if(findtext(entry_key, LOBBY_HOUSING_TEST_KEY) == 1)
			GLOB.lobby_housing_requests -= entry_key
	GLOB.lobby_join_locks -= LOBBY_HOUSING_TEST_KEY
	for(var/entry_key in GLOB.cryo_rejoin_cooldowns.Copy())
		if(findtext(entry_key, LOBBY_HOUSING_TEST_KEY) == 1)
			GLOB.cryo_rejoin_cooldowns -= entry_key
	return ..()

/datum/unit_test/lobby_terminal_housing/Run()
	var/datum/lobby_terminal/housing_test/term = new
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	home.founder_ckey = "housingfounder"
	var/mob/dead/new_player/player = allocate(/mob/dead/new_player)
	player.key = LOBBY_HOUSING_TEST_KEY
	TEST_ASSERT_EQUAL(player.ckey, LOBBY_HOUSING_TEST_KEY, "The test player has no ckey")

	check_why(term, home)
	check_request(term, home, player)
	check_kept_confirmation(term, home, player)
	check_notice_lengths()
	qdel(term)

/// Sets the outpost up and checks what its block says.
/datum/unit_test/lobby_terminal_housing/proc/expect(datum/lobby_terminal/housing_test/term, obj/structure/overmap/dynamic/player_outpost/home, why, blocked, case_name)
	var/list/entry = term.housing_entry(home, LOBBY_HOUSING_TEST_KEY)
	TEST_ASSERT(!("denial" in entry), "[case_name]: the block still carries the denial")
	TEST_ASSERT_EQUAL(entry["blocked"], blocked, "[case_name]: blocked is wrong")
	TEST_ASSERT_EQUAL(entry["why"], why, "[case_name]: the reason on the block is wrong")
	return entry

/datum/unit_test/lobby_terminal_housing/proc/check_why(datum/lobby_terminal/housing_test/term, obj/structure/overmap/dynamic/player_outpost/home)
	// Before the round the header already says it.
	SSticker.current_state = GAME_STATE_PREGAME
	home.resident_mode = "open"
	expect(term, home, null, TRUE, "Before the round")
	SSticker.current_state = GAME_STATE_PLAYING

	// The block's word says these.
	home.resident_mode = "closed"
	expect(term, home, null, TRUE, "Closed")
	home.resident_mode = "approved"
	var/list/entry = expect(term, home, null, TRUE, "Invite, not cleared")
	TEST_ASSERT(entry["can_ask"], "An invite outpost offered no request")

	// The block draws these.
	home.blocked_residents += LOBBY_HOUSING_TEST_KEY
	entry = expect(term, home, "You're barred from here.", TRUE, "Barred")
	TEST_ASSERT(!entry["can_ask"], "A barred player was offered a request")
	home.blocked_residents -= LOBBY_HOUSING_TEST_KEY

	home.resident_mode = "open"
	home.dock_mode = LOBBY_HOUSING_TEST_LOCKDOWN
	expect(term, home, "Locked down. Residents only.", TRUE, "Locked down")
	home.dock_mode = LOBBY_HOUSING_TEST_OPEN_DOCK

	home.resident_mode = "password"
	home.resident_password = ""
	expect(term, home, "Not taking residents.", TRUE, "Code outpost with no code set")
	home.resident_password = "hunter2"

	home.resident_mode = "open"
	GLOB.cryo_rejoin_cooldowns["[LOBBY_HOUSING_TEST_KEY]@[REF(home)]"] = world.time + 3 MINUTES
	entry = term.housing_entry(home, LOBBY_HOUSING_TEST_KEY)
	TEST_ASSERT(entry["blocked"], "Still in cryo: not blocked")
	TEST_ASSERT(findtext(entry["why"], "Still in cryo for ") == 1, "Still in cryo: the reason is [entry["why"]]")
	GLOB.cryo_rejoin_cooldowns -= "[LOBBY_HOUSING_TEST_KEY]@[REF(home)]"

	// The outpost was never loaded, so it has no cryopods.
	expect(term, home, "No free cryopods.", TRUE, "No free cryopods")

/datum/unit_test/lobby_terminal_housing/proc/check_request(datum/lobby_terminal/housing_test/term, obj/structure/overmap/dynamic/player_outpost/home, mob/dead/new_player/player)
	SSticker.current_state = GAME_STATE_PLAYING
	home.resident_mode = "approved"
	term.notice = null
	term.housing_request(player, home)
	TEST_ASSERT_EQUAL(term.notice?["text"], "Nobody's home.", "Asking an empty outpost gave the wrong answer")
	TEST_ASSERT(!term.housing_asked(home, LOBBY_HOUSING_TEST_KEY), "A request nobody heard was counted")

	var/mob/living/carbon/human/resident = allocate(/mob/living/carbon/human/consistent)
	term.fake_recipients = list(resident)
	term.notice = null
	term.housing_request(player, home)
	TEST_ASSERT_NULL(term.notice, "A sent request raised a notice")
	TEST_ASSERT(term.housing_asked(home, LOBBY_HOUSING_TEST_KEY), "A sent request was not counted")
	var/list/entry = term.housing_entry(home, LOBBY_HOUSING_TEST_KEY)
	TEST_ASSERT(entry["asked"], "The block does not show the request")

/datum/unit_test/lobby_terminal_housing/proc/check_kept_confirmation(datum/lobby_terminal/housing_test/term, obj/structure/overmap/dynamic/player_outpost/home, mob/dead/new_player/player)
	// A move-in is under way: its CONFIRMED box is up and the join lock is held.
	home.resident_mode = "open"
	var/list/confirmed = list("text" = "Moving in at [home.name].", "kind" = "ok", "at" = world.time)
	term.notice = confirmed
	GLOB.lobby_join_locks[LOBBY_HOUSING_TEST_KEY] = world.time
	term.housing_move_in(player, home, "")
	TEST_ASSERT_EQUAL(term.notice, confirmed, "A second MOVE IN replaced the CONFIRMED box")
	// With no move-in under way, the same press answers.
	GLOB.lobby_join_locks -= LOBBY_HOUSING_TEST_KEY
	term.housing_move_in(player, home, "")
	TEST_ASSERT_EQUAL(term.notice?["kind"], "warn", "A refused MOVE IN said nothing")

/// Every literal set_notice() text fits the notice row. Bracketed expressions count as nothing.
/datum/unit_test/lobby_terminal_housing/proc/check_notice_lengths()
	var/source = file2text("voidcrew/modules/lobby_terminal/lobby_housing.dm")
	TEST_ASSERT(length(source), "Could not read lobby_housing.dm")
	var/regex/call_text = new(@{"set_notice\("([^"]*)""}, "g")
	var/regex/expression = new(@"\[[^\]]*\]", "g")
	var/found = 0
	while(call_text.Find(source))
		found++
		var/text = expression.Replace(call_text.group[1], "")
		TEST_ASSERT(length(text) <= LOBBY_HOUSING_TEST_NOTICE_MAX, "Notice too long for one line ([length(text)]): [call_text.group[1]]")
	TEST_ASSERT(found >= 10, "Found only [found] notices in lobby_housing.dm")

#undef LOBBY_HOUSING_TEST_LOCKDOWN
#undef LOBBY_HOUSING_TEST_OPEN_DOCK
#undef LOBBY_HOUSING_TEST_NOTICE_MAX
#undef LOBBY_HOUSING_TEST_KEY
