/**
 * Friends, games and birthdays (outpost_prison_life.dm, outpost_prison_pastimes.dm). Owner: XD.
 * Affinity and what moves it, friends breaking up arguments, farewells and release lines, card and
 * dice games, the birthday party, the courtside crowd and marks on the wall (extras-plan.md 4.4,
 * 4.6, 4.9, 4.12 and 4.13).
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with tick(seconds), or the procs it calls, with their
 * own processing stopped; fixtures are in voidcrew_outpost_prison_helpers.dm. Walks are done by
 * teleport and the steps they lead to are called directly. Prisoners that must count as awake use
 * trouble_awake_prisoner() (voidcrew_outpost_prison_trouble.dm).
 */

/datum/unit_test/voidcrew_outpost_prison_life_files

/datum/unit_test/voidcrew_outpost_prison_life_files/Run()
	// The file is read the way outpost_prisoner_extra_dialogue() reads it (the strings directory is a define)
	load_strings_file("outpost_prison_life.json", "voidcrew/modules/player_outposts/strings")
	var/list/contents = GLOB.string_cache["outpost_prison_life.json"]
	TEST_ASSERT(islist(contents), "outpost_prison_life.json did not load")
	TEST_ASSERT(islist(contents["lines"]), "outpost_prison_life.json has no lines block")
	TEST_ASSERT(islist(contents["conversations_friendly"]), "outpost_prison_life.json has no conversations_friendly block")
	TEST_ASSERT(islist(contents["conversations_hostile"]), "outpost_prison_life.json has no conversations_hostile block")
	// Every context the life and pastime files say by name
	var/list/lines = contents["lines"]
	var/list/contexts = list(
		"arrival_crew_friend", "arrival_crew_rival", "fight_argue_grudge", "friend_breaks_up", "farewell",
		"farewell_reply", "release_thanks", "release_bitter", "cards", "cards_win", "cards_lose", "cards_put_down",
		"cards_missing", "dice", "dice_win", "birthday_arrival", "birthday", "birthday_party", "birthday_thanks",
		"watch_cheer", "game_heckle", "game_score_call", "game_won", "game_lost", "cell_marks", "mark_scrubbed",
	)
	for(var/context in contexts)
		TEST_ASSERT(islist(lines[context]), "outpost_prison_life.json has no [context] lines")
	// Friends' and rivals' own conversations, in the main file's shape
	for(var/pool_key in list("conversations_friendly", "conversations_hostile"))
		var/list/pool = contents[pool_key]
		TEST_ASSERT(length(pool) >= 5, "[pool_key] has [length(pool)] conversations, not 5 or more")
		for(var/list/conversation in pool)
			TEST_ASSERT(istext(conversation["opener"]) && length(conversation["replies"]), "[pool_key] has a conversation with no opener or no replies")

// ===== SHARED HELPERS =====

/// The life tests' own helpers; not a test itself
/datum/unit_test/voidcrew_outpost_prison_life_base
	parent_type = /datum/unit_test/voidcrew_outpost_management
	abstract_type = /datum/unit_test/voidcrew_outpost_prison_life_base

/// Whether `line` is one of `context`'s lines in any prisoner dialogue file, placeholders filled in
/datum/unit_test/voidcrew_outpost_prison_life_base/proc/life_line_for(line, context)
	var/list/entry = outpost_prisoner_context_lines(context)
	if(!islist(entry) || !istext(line))
		return FALSE
	for(var/pool_key in entry)
		for(var/candidate in entry[pool_key])
			if(!findtext(candidate, "{"))
				if(candidate == line)
					return TRUE
				continue
			// A line with placeholders: compare what is left of it around them.
			var/all_found = TRUE
			for(var/part in splittext(candidate, regex("\\{\[a-z_\]+\\}")))
				if(length(part) && !findtext(line, part))
					all_found = FALSE
					break
			if(all_found)
				return TRUE
	return FALSE

/// Whether the last thing `speaker` said was a `context` line
/datum/unit_test/voidcrew_outpost_prison_life_base/proc/life_said(mob/living/basic/outpost_prisoner/speaker, context)
	return life_line_for(speaker.last_line, context)

/// Whether `prisoner` has a `context` line queued
/datum/unit_test/voidcrew_outpost_prison_life_base/proc/life_queued(mob/living/basic/outpost_prisoner/prisoner, context)
	for(var/list/entry in prisoner.life_lines)
		if(entry[2] == context)
			return TRUE
	return FALSE

/// Whether a dice game's roll has come down
/datum/unit_test/voidcrew_outpost_prison_life_base/proc/life_dice_down(datum/prisoner_activity/dice/game)
	return !game.in_flight

// ===== FRIENDS AND RIVALS (4.4) =====

/datum/unit_test/voidcrew_outpost_prison_life_affinity
	parent_type = /datum/unit_test/voidcrew_outpost_prison_life_base

/datum/unit_test/voidcrew_outpost_prison_life_affinity/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("affinityowner")
	TEST_ASSERT_NOTNULL(home, "The affinity test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/rosa = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/dale = trouble_prisoner(prison, prison_spot(home, 10, 8))
	var/mob/living/basic/outpost_prisoner/cole = trouble_prisoner(prison, prison_spot(home, 8, 10))

	// Each source moves affinity by its amount, whichever way round the pair comes
	TEST_ASSERT_EQUAL(prison.affinity(rosa, dale), 0, "Two new prisoners started with an affinity")
	prison.note_chat(rosa, dale)
	TEST_ASSERT_EQUAL(prison.affinity(dale, rosa), 4, "A finished chat moved affinity to [prison.affinity(dale, rosa)], not 4") // PRISON_AFFINITY_CHAT
	prison.note_shared_meal(list(rosa, dale, cole))
	TEST_ASSERT_EQUAL(prison.affinity(rosa, dale), 7, "A shared meal did not add 3 to a pair who chatted") // PRISON_AFFINITY_SHARED_MEAL
	TEST_ASSERT_EQUAL(prison.affinity(rosa, cole), 3, "A shared meal did not add 3 to every pair of diners")
	TEST_ASSERT_EQUAL(prison.affinity(dale, cole), 3, "A shared meal did not add 3 to every pair of diners")
	prison.note_spat(rosa, cole)
	TEST_ASSERT_EQUAL(prison.affinity(rosa, cole), -3, "A spat did not take 6") // PRISON_AFFINITY_SPAT
	prison.note_fight(dale, cole)
	TEST_ASSERT_EQUAL(prison.affinity(dale, cole), -17, "A fight did not take 20") // PRISON_AFFINITY_FIGHT
	// Basketball together: +2 for each full minute (PRISON_AFFINITY_BASKETBALL)
	for(var/mob/living/basic/outpost_prisoner/player as anything in list(rosa, dale))
		var/datum/prisoner_activity/basketball/game = player.start_activity(new /datum/prisoner_activity/basketball(player))
		game.started = TRUE
	prison.coplay_tick(59)
	TEST_ASSERT_EQUAL(prison.affinity(rosa, dale), 7, "Under a minute of basketball together moved affinity")
	prison.coplay_tick(1)
	TEST_ASSERT_EQUAL(prison.affinity(rosa, dale), 9, "A minute of basketball together did not add 2")
	prison.coplay_tick(120)
	TEST_ASSERT_EQUAL(prison.affinity(rosa, dale), 13, "Two more minutes of basketball did not add 4")
	rosa.end_activity(cancel_ai = FALSE)
	dale.end_activity(cancel_ai = FALSE)

	// Fight chance: rivals x1.5, friends x0.5 (PRISON_FIGHT_MULT_RIVAL, _FRIEND; bands PRISON_AFFINITY_RIVAL -25, _FRIEND 25)
	prison.set_affinity(rosa, dale, 25)
	TEST_ASSERT_EQUAL(prison.fight_chance_mult(rosa, dale), 0.5, "Friends fought as readily as anyone")
	prison.set_affinity(rosa, dale, -25)
	TEST_ASSERT_EQUAL(prison.fight_chance_mult(rosa, dale), 1.5, "Rivals fought no more readily than anyone")
	prison.set_affinity(rosa, dale, 0)
	TEST_ASSERT_EQUAL(prison.fight_chance_mult(rosa, dale), 1, "Strangers' fight chance changed")
	TEST_ASSERT(!(prison.affinity_key(rosa, dale) in prison.affinities), "A pair back at 0 was still kept")

	// A grudge: at -30 or below, with nothing else to fight over (PRISON_AFFINITY_GRUDGE)
	prison.set_affinity(rosa, dale, -29)
	TEST_ASSERT_NULL(prison.fight_cause_extra(rosa, dale), "A pair at -29 fought over a grudge")
	prison.set_affinity(rosa, dale, -30)
	TEST_ASSERT_EQUAL(prison.fight_cause_extra(rosa, dale), "grudge", "A pair at -30 had no grudge")
	TEST_ASSERT_EQUAL(prison.fight_cause(rosa, dale), "grudge", "A fed pair at -30 argued over [prison.fight_cause(rosa, dale)], not a grudge")

	// Chat partners: a friend at 50 (weight 3) comes up at least twice as often as a stranger (weight 1)
	prison.set_affinity(rosa, dale, 50)
	prison.set_affinity(rosa, cole, 0)
	var/friend_picks = 0
	var/stranger_picks = 0
	for(var/i in 1 to 300)
		var/list/options = list(dale, cole)
		var/mob/living/basic/outpost_prisoner/picked = prison.take_chat_partner(rosa, options)
		TEST_ASSERT_EQUAL(length(options), 1, "The chosen chat partner was not taken out of the options")
		if(picked == dale)
			friend_picks++
		else if(picked == cole)
			stranger_picks++
	TEST_ASSERT(friend_picks >= 2 * stranger_picks, "A friend was picked [friend_picks] times and a stranger [stranger_picks] in 300")

	// Spats: rivals come up three times as often (PRISON_SPAT_RIVAL_WEIGHT)
	prison.set_affinity(rosa, dale, -40)
	var/rival_spats = 0
	for(var/i in 1 to 300)
		var/list/pair = prison.pick_spat_pair(list(list(rosa, cole), list(rosa, dale)))
		if(pair[2] == dale)
			rival_spats++
	TEST_ASSERT(rival_spats >= 2 * (300 - rival_spats), "Rivals had [rival_spats] of 300 spats")

	// Examine names a friend and a rival; the talk menu gets the rival's first name
	prison.set_affinity(rosa, cole, 40)
	var/examined = prison.relationship_examine(rosa)
	TEST_ASSERT(findtext(examined, cole.speech_name()) && findtext(examined, dale.speech_name()), "Examine said '[examined]'")
	TEST_ASSERT_EQUAL(prison.worst_rival_name(rosa), dale.speech_name(), "The worst rival's name was wrong")

	// Friends and rivals mostly open with their own conversations (PRISON_TIE_CONVERSATION_CHANCE); strangers never do
	var/list/friendly = outpost_prisoner_extra_dialogue("outpost_prison_life.json", "conversations_friendly")
	var/list/hostile = outpost_prisoner_extra_dialogue("outpost_prison_life.json", "conversations_hostile")
	var/list/opened
	for(var/i in 1 to 50)
		opened = prison.pick_conversation(rosa, cole)
		if(opened)
			break
	TEST_ASSERT(opened && (opened in friendly), "Friends never opened with a friendly conversation")
	opened = null
	for(var/i in 1 to 50)
		opened = prison.pick_conversation(rosa, dale)
		if(opened)
			break
	TEST_ASSERT(opened && (opened in hostile), "Rivals never opened with a hostile conversation")
	prison.set_affinity(rosa, cole, 10)
	for(var/i in 1 to 50)
		TEST_ASSERT_NULL(prison.pick_conversation(rosa, cole), "A pair at 10 opened with a friends' or rivals' conversation")

	// At most six pairs; a new one pushes out the mildest (PRISON_AFFINITY_MAX_PAIRS)
	var/mob/living/basic/outpost_prisoner/ed = trouble_prisoner(prison, prison_spot(home, 10, 10))
	var/mob/living/basic/outpost_prisoner/fay = trouble_prisoner(prison, prison_spot(home, 12, 7))
	TEST_ASSERT_NULL(prison.relationship_examine(ed), "A prisoner with no friends or rivals had a relationship line")
	TEST_ASSERT_NULL(prison.worst_rival_name(ed), "A prisoner with no rivals had a worst rival")
	prison.affinities.Cut()
	prison.set_affinity(rosa, dale, 40)
	prison.set_affinity(rosa, cole, 35)
	prison.set_affinity(rosa, ed, 30)
	prison.set_affinity(dale, cole, -45)
	prison.set_affinity(dale, ed, 50)
	prison.set_affinity(cole, ed, 5)
	prison.set_affinity(fay, rosa, 20)
	TEST_ASSERT_EQUAL(length(prison.affinities), 6, "The wing kept [length(prison.affinities)] pairs")
	TEST_ASSERT_EQUAL(prison.affinity(cole, ed), 0, "The mildest pair was not the one pushed out")
	TEST_ASSERT_EQUAL(prison.affinity(fay, rosa), 20, "The new pair was not kept")

	// Arrivals who crewed with someone inside, or fell out with them (PRISON_CREW_TIE 30), and say so later
	prison.affinities.Cut()
	var/mob/living/basic/outpost_prisoner/newcomer = trouble_prisoner(prison, prison_spot(home, 12, 10))
	var/mob/living/basic/outpost_prisoner/crewmate = prison.roll_crew_tie(newcomer, "friend")
	TEST_ASSERT_NOTNULL(crewmate, "An arrival found no crewmate with others inside")
	TEST_ASSERT_EQUAL(prison.affinity(newcomer, crewmate), 30, "An arrival's crewmate started at [prison.affinity(newcomer, crewmate)]")
	TEST_ASSERT(life_queued(newcomer, "arrival_crew_friend"), "An arrival did not mean to greet their crewmate")
	var/mob/living/basic/outpost_prisoner/enemy = prison.roll_crew_tie(newcomer, "rival")
	TEST_ASSERT_EQUAL(prison.affinity(newcomer, enemy), -30, "An arrival's rival started at [prison.affinity(newcomer, enemy)]")
	TEST_ASSERT(life_queued(newcomer, "arrival_crew_rival"), "An arrival did not mean to say who they fell out with")
	// About 8% have a birthday (PRISON_BIRTHDAY_CHANCE); 2000 rolls keep this steady
	var/birthdays = 0
	for(var/i in 1 to 2000)
		if(prison.roll_birthday())
			birthdays++
	TEST_ASSERT(birthdays >= 100 && birthdays <= 220, "[birthdays] of 2000 arrivals had a birthday, not 5-11%")
	prison.give_birthday(newcomer)
	TEST_ASSERT(newcomer.has_birthday && life_queued(newcomer, "birthday_arrival"), "A birthday was not given or not queued to be said")
	// Queued lines are said once due (PRISON_BIRTHDAY_LINE_DELAY 10)
	prison.life_lines_tick(11)
	TEST_ASSERT(!length(newcomer.life_lines), "Lines due were still queued")
	TEST_ASSERT(life_said(newcomer, "birthday_arrival"), "The birthday line was not said ([newcomer.last_line])")

	// Leaving: every pair and basketball clock of theirs goes with them
	var/cole_ref = REF(cole)
	prison.set_affinity(rosa, cole, 40)
	prison.set_affinity(dale, cole, -40)
	qdel(cole)
	for(var/key in prison.affinities)
		TEST_ASSERT(!findtext(key, cole_ref), "A pair outlived a prisoner who left")
	for(var/key in prison.coplay_seconds)
		TEST_ASSERT(!findtext(key, cole_ref), "A basketball clock outlived a prisoner who left")
	settle_prison_air(home)

/datum/unit_test/voidcrew_outpost_prison_life_breakup
	parent_type = /datum/unit_test/voidcrew_outpost_prison_life_base

/datum/unit_test/voidcrew_outpost_prison_life_breakup/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("breakupowner")
	TEST_ASSERT_NOTNULL(home, "The break-up test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/first = trouble_awake_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/second = trouble_awake_prisoner(prison, prison_spot(home, 9, 8))
	var/mob/living/basic/outpost_prisoner/pal = trouble_awake_prisoner(prison, prison_spot(home, 8, 10))
	prison.set_affinity(first, pal, 40)

	// One try per fight: a friend who fails does not get another (PRISON_BREAKUP_CHANCE forced)
	var/datum/outpost_prison_fight/brawl = prison.start_fight(first, second, "none")
	TEST_ASSERT_NOTNULL(brawl, "The test fight did not start")
	pal.set_mood(70) // Seeing the fight cost them some
	prison.breakup_chance_override = 0
	TEST_ASSERT_NULL(prison.breakup_tick(), "A friend broke up a fight at a 0% chance")
	prison.breakup_chance_override = 100
	TEST_ASSERT_NULL(prison.breakup_tick(), "A friend got a second try at the same fight")
	prison.end_fight(brawl)

	// A friend close by, awake and content ends the argument
	brawl = prison.start_fight(first, second, "none")
	pal.set_mood(70)
	TEST_ASSERT_EQUAL(prison.breakup_tick(), pal, "The friend did not break up the argument")
	TEST_ASSERT(!(brawl in prison.fights) && isnull(first.fight) && isnull(second.fight), "The argument went on after a friend broke it up")
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_prison_life_base, life_said), pal, "friend_breaks_up"), 3 SECONDS), "The friend said nothing as they broke it up")

	// Not once blows are thrown, and not by a friend in a sour mood (PRISON_BREAKUP_MOOD 50)
	brawl = prison.start_fight(first, second, "none")
	brawl.fighting = TRUE
	pal.set_mood(70)
	TEST_ASSERT_NULL(prison.breakup_tick(), "A friend broke up a fight already trading blows")
	brawl.fighting = FALSE
	pal.set_mood(40)
	TEST_ASSERT_NULL(prison.breakup_tick(), "A friend in a sour mood broke up a fight")
	prison.end_fight(brawl)

	// Farewells: a friend in sight says goodbye and feels it (PRISON_FAREWELL_MOOD 3, chatty); the leaver answers
	prison.set_affinity(first, pal, 40)
	pal.set_mood(70)
	TEST_ASSERT(prison.on_prisoner_releasing(first, 0.6), "A release with a friend in sight made no farewell")
	TEST_ASSERT(abs(pal.mood - 67) < 0.01, "A friend's mood went to [pal.mood] at a release, not 67")
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_prison_life_base, life_said), pal, "farewell"), 5 SECONDS), "The friend did not say goodbye")
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_prison_life_base, life_said), first, "farewell_reply"), 5 SECONDS), "The leaver did not answer their friend")

	// Release lines by how the stay was kept (PRISON_RELEASE_THANKS_AVERAGE 0.9, _BITTER_AVERAGE 0.4)
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 11, 10), "breakupowner")
	var/mob/living/basic/outpost_prisoner/lucky = trouble_awake_prisoner(prison, prison_spot(home, 12, 10))
	TEST_ASSERT(prison.on_prisoner_releasing(lucky, 0.95), "A stay kept well did not end in thanks")
	TEST_ASSERT(life_said(lucky, "release_thanks"), "The thanks were not a release_thanks line ([lucky.last_line])")
	TEST_ASSERT_EQUAL(lucky.dir, get_dir(lucky, warden), "The leaver did not turn to the member in sight")
	var/mob/living/basic/outpost_prisoner/sour = trouble_awake_prisoner(prison, prison_spot(home, 13, 7))
	TEST_ASSERT(prison.on_prisoner_releasing(sour, 0.3), "A poor stay did not end in a bitter word")
	TEST_ASSERT(life_said(sour, "release_bitter"), "The bitter word was not a release_bitter line ([sour.last_line])")
	TEST_ASSERT(!prison.on_prisoner_releasing(sour, 0.6), "A middling stay with no friends in sight replaced the usual release line")
	settle_prison_air(home)

// ===== CARDS AND DICE (4.6) =====

/datum/unit_test/voidcrew_outpost_prison_life_cards
	parent_type = /datum/unit_test/voidcrew_outpost_prison_life_base

/datum/unit_test/voidcrew_outpost_prison_life_cards/Run()
	// Ranks by name: Ace 14, faces 13-11, numbers as printed, Jokers 0
	TEST_ASSERT_EQUAL(outpost_prison_card_rank("Ace of Spades"), 14, "An ace did not rank 14")
	TEST_ASSERT_EQUAL(outpost_prison_card_rank("King of Clubs"), 13, "A king did not rank 13")
	TEST_ASSERT_EQUAL(outpost_prison_card_rank("Jack of Hearts"), 11, "A jack did not rank 11")
	TEST_ASSERT_EQUAL(outpost_prison_card_rank("10 of Hearts"), 10, "A ten did not rank 10")
	TEST_ASSERT_EQUAL(outpost_prison_card_rank("2 of Diamonds"), 2, "A two did not rank 2")
	TEST_ASSERT_EQUAL(outpost_prison_card_rank("Joker Clown"), 0, "A joker did not rank 0")
	// Both games lift mood while played, for the host and the players they call over
	for(var/datum/prisoner_activity/game_type as anything in list(/datum/prisoner_activity/cards, /datum/prisoner_activity/cards/join, /datum/prisoner_activity/dice, /datum/prisoner_activity/dice/join))
		TEST_ASSERT(initial(game_type.mood_activity), "[game_type] is not a mood activity")
	// Hosts pick a game as leisure; the players they call over never pick one on their own
	var/datum/prisoner_activity/host_type = /datum/prisoner_activity/cards
	var/datum/prisoner_activity/seat_type = /datum/prisoner_activity/cards/join
	TEST_ASSERT(initial(host_type.leisure) && !initial(seat_type.leisure), "Card games are picked the wrong way")
	TEST_ASSERT((host_type in GLOB.outpost_prisoner_leisure) && !(seat_type in GLOB.outpost_prisoner_leisure), "The leisure list has the wrong card games")

	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("cardsowner")
	TEST_ASSERT_NOTNULL(home, "The cards test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/obj/item/toy/cards/deck/deck = locate() in prison_spot(home, 5, 9)
	TEST_ASSERT_NOTNULL(deck, "The deck is not on the mess table where the map puts it")
	var/full = deck.count_cards()
	var/mob/living/basic/outpost_prisoner/dealer = trouble_awake_prisoner(prison, prison_spot(home, 5, 10))
	var/mob/living/basic/outpost_prisoner/player = trouble_awake_prisoner(prison, prison_spot(home, 5, 8))
	prison.refresh_reach()

	// The dealer takes the deck, sits at its table and calls the other over
	var/datum/prisoner_activity/cards/game = dealer.start_activity(new /datum/prisoner_activity/cards(dealer))
	TEST_ASSERT(game.setup(), "A card game could not be set up with a deck on the table and someone free to play")
	TEST_ASSERT_EQUAL(game.gear(), deck, "The game is not played with the deck on the table")
	dealer.forceMove(game.spot)
	TEST_ASSERT(game.arrive(), "The dealer could not sit down at the table")
	TEST_ASSERT_EQUAL(deck.loc, dealer, "The dealer did not pick up the deck")
	var/datum/prisoner_activity/cards/join/seat = player.activity
	TEST_ASSERT(istype(seat), "The other prisoner was not called over to play")
	player.forceMove(seat.spot)
	seat.arrive()
	TEST_ASSERT_EQUAL(length(game.players()), 2, "Two seated players counted as [length(game.players())]")
	TEST_ASSERT_EQUAL(game.tick(1), 0, "The game did not go on with two at the table") // ACTIVITY_CONTINUE
	TEST_ASSERT_EQUAL(game.stage, "play", "Play did not start with two at the table")

	// A hand: one card face down in front of each seat, turned over, then back in the deck
	TEST_ASSERT(game.deal_round(), "The dealer did not deal")
	TEST_ASSERT_EQUAL(length(game.dealt), 2, "[length(game.dealt)] cards were dealt to two players")
	TEST_ASSERT_EQUAL(deck.count_cards(), full - 2, "The deck did not give up a card per seat")
	for(var/list/entry as anything in game.dealt)
		var/datum/weakref/card_ref = entry[1]
		var/obj/item/toy/singlecard/card = card_ref.resolve()
		TEST_ASSERT(card && card.loc == entry[3] && prison.is_mess_table(card.loc), "A dealt card is not on the table in front of its seat")
		TEST_ASSERT(!card.flipped, "A card was dealt face up")
	game.flip_round()
	for(var/list/entry as anything in game.dealt)
		var/datum/weakref/card_ref = entry[1]
		var/obj/item/toy/singlecard/card = card_ref.resolve()
		TEST_ASSERT(card?.flipped, "A card was not turned over")
	// Everyone at the table cheers up, once per 5 minutes (PRISON_CARDS_MOOD 3, _GAP)
	TEST_ASSERT(abs(dealer.mood - 73) < 0.01 && abs(player.mood - 73) < 0.01, "A hand left the players at [dealer.mood] and [player.mood], not 73")
	game.collect_round()
	TEST_ASSERT_EQUAL(deck.count_cards(), full, "The cards did not all go back in the deck")
	TEST_ASSERT(!length(game.dealt), "Cards were still out after they were gathered")

	// A member sitting at the table is dealt in; one who picks their card up sits the hand out and keeps it
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 7, 9), "cardsowner")
	var/obj/structure/chair/spare
	for(var/obj/structure/chair/stool as anything in prison.stools_at(game.table_turfs))
		if(!stool.has_buckled_mobs() && !prison.claimant(stool) && !(locate(/mob/living) in stool.loc))
			spare = stool
			break
	TEST_ASSERT_NOTNULL(spare, "No free stool at the table for the member")
	warden.forceMove(spare.loc)
	spare.buckle_mob(warden, force = TRUE)
	TEST_ASSERT_EQUAL(length(game.players()), 3, "A member sitting at the table was not counted in")
	TEST_ASSERT(game.deal_round(), "The dealer did not deal with a member at the table")
	var/obj/item/toy/singlecard/warden_card
	for(var/list/entry as anything in game.dealt)
		var/datum/weakref/card_ref = entry[1]
		var/datum/weakref/player_ref = entry[2]
		if(player_ref.resolve() == warden)
			warden_card = card_ref.resolve()
	TEST_ASSERT_NOTNULL(warden_card, "The member was not dealt a card")
	warden.put_in_active_hand(warden_card)
	game.flip_round()
	TEST_ASSERT(warden in game.sat_out, "A member who picked up their card was not sat out")
	TEST_ASSERT(abs(dealer.mood - 73) < 0.01, "A second hand inside 5 minutes lifted the dealer again")
	game.collect_round()
	TEST_ASSERT_EQUAL(deck.count_cards(), full - 1, "The table's cards did not go back, or the member's card was taken from them")
	TEST_ASSERT_EQUAL(warden_card.loc, warden, "The member lost the card they picked up")

	// A stolen deck ends the game without fuss, and the other player goes back to their day
	warden.put_in_inactive_hand(deck)
	TEST_ASSERT_EQUAL(deck.loc, warden, "The member could not take the deck from the dealer")
	TEST_ASSERT_EQUAL(game.tick(1), 1, "The game went on with the deck in someone else's hands") // ACTIVITY_DONE
	dealer.end_activity(cancel_ai = FALSE)
	TEST_ASSERT_NULL(player.activity, "The other player kept sitting at a game that was over")
	TEST_ASSERT(!dealer.buckled && !player.buckled, "The players stayed seated after the game")
	spare.unbuckle_mob(warden, force = TRUE)
	settle_prison_air(home)

/datum/unit_test/voidcrew_outpost_prison_life_dice
	parent_type = /datum/unit_test/voidcrew_outpost_prison_life_base

/datum/unit_test/voidcrew_outpost_prison_life_dice/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("diceowner")
	TEST_ASSERT_NOTNULL(home, "The dice test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/obj/item/storage/dice/bag = locate() in prison_spot(home, 13, 9)
	TEST_ASSERT_NOTNULL(bag, "The bag of dice is not on the mess table where the map puts it")
	var/mob/living/basic/outpost_prisoner/roller = trouble_awake_prisoner(prison, prison_spot(home, 13, 10))
	var/mob/living/basic/outpost_prisoner/opponent = trouble_awake_prisoner(prison, prison_spot(home, 13, 8))
	prison.refresh_reach()

	var/datum/prisoner_activity/dice/game = roller.start_activity(new /datum/prisoner_activity/dice(roller))
	TEST_ASSERT(game.setup(), "A dice game could not be set up with the bag on the table and someone free to play")
	roller.forceMove(game.spot)
	TEST_ASSERT(game.arrive(), "The roller could not sit down at the table")
	var/obj/item/dice/die = game.die_ref?.resolve()
	TEST_ASSERT(die && die.loc == roller && die.sides == 6, "The roller did not take a six-sided die out of the bag")
	var/datum/prisoner_activity/dice/join/seat = opponent.activity
	TEST_ASSERT(istype(seat), "The other prisoner was not called over to roll")
	opponent.forceMove(seat.spot)
	seat.arrive()
	TEST_ASSERT_EQUAL(game.tick(1), 0, "The game did not go on with two at the table") // ACTIVITY_CONTINUE
	TEST_ASSERT_EQUAL(game.stage, "play", "Play did not start with two at the table")

	// Each roll is read off the die where it came down, and the higher wins
	game.in_flight = TRUE
	die.result = 5
	game.die_landed(null)
	TEST_ASSERT_EQUAL(game.rolls[1], 5, "The host's roll read [game.rolls[1]], not the die's 5")
	game.in_flight = TRUE
	die.result = 2
	game.die_landed(null)
	TEST_ASSERT_EQUAL(game.last_winner_ref?.resolve(), roller, "A 5 did not beat a 2")

	// A real roll goes across the table and lands on it showing a number
	TEST_ASSERT(game.roll_die(roller), "The roller could not roll the die")
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_prison_life_base, life_dice_down), game), 5 SECONDS), "The die never came down")
	TEST_ASSERT(isturf(die.loc) && prison.is_mess_table(die.loc), "The die did not land on the table")
	TEST_ASSERT(game.rolls[1] >= 1 && game.rolls[1] <= 6, "The roll read [game.rolls[1]]")

	// Afterwards the die goes back in its bag
	game.stage = "tidy"
	TEST_ASSERT_EQUAL(game.tidy_step(), 1, "Putting the die away did not finish") // ACTIVITY_DONE
	TEST_ASSERT_EQUAL(die.loc, bag, "The die was not put back in its bag")
	roller.end_activity(cancel_ai = FALSE)
	TEST_ASSERT_NULL(opponent.activity, "The other player kept sitting at a game that was over")
	settle_prison_air(home)

// ===== BIRTHDAYS (4.9) =====

/datum/unit_test/voidcrew_outpost_prison_life_birthday
	parent_type = /datum/unit_test/voidcrew_outpost_prison_life_base

/datum/unit_test/voidcrew_outpost_prison_life_birthday/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("partyowner")
	TEST_ASSERT_NOTNULL(home, "The birthday test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 5, 5), "partyowner")
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in prison_spot(home, 5, 6)
	TEST_ASSERT_NOTNULL(hatch, "The serving hatch is not where the map puts it")
	var/mob/living/basic/outpost_prisoner/host = trouble_awake_prisoner(prison, prison_spot(home, 5, 7))
	var/mob/living/basic/outpost_prisoner/guest = trouble_awake_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/other_guest = trouble_awake_prisoner(prison, prison_spot(home, 10, 8))
	var/mob/living/basic/outpost_prisoner/starving = test_prisoner(prison, prison_spot(home, 4, 7))
	prison.refresh_reach()

	// A cake handed to a prisoner with no birthday is ordinary food
	guest.set_hunger(20)
	var/obj/item/food/cake/plain/plain_cake = allocate(/obj/item/food/cake/plain)
	warden.put_in_active_hand(plain_cake)
	TEST_ASSERT(!prison.pastime_pre_eat(guest, plain_cake, warden), "A cake handed to a prisoner with no birthday was held back")
	TEST_ASSERT_EQUAL(guest.on_pre_eat(guest, plain_cake, warden), NONE, "A hungry prisoner with no birthday would not eat a cake")
	TEST_ASSERT_NULL(prison.party_stage, "A cake for a prisoner with no birthday started a party")
	warden.dropItemToGround(plain_cake)
	guest.set_hunger(100)

	// Handed to the birthday prisoner, it is theirs for the party and the eat is called off.
	// Handing takes arm's reach, as it does in play, so the warden steps up beside them.
	prison.give_birthday(host)
	// A closer look says it is their birthday (the warden's roster no longer does)
	TEST_ASSERT(findtext(jointext(host.examine_more(warden), " "), "birthday today"), "A closer look at the birthday prisoner does not say so")
	warden.forceMove(prison_spot(home, 6, 7))
	var/obj/item/food/cake/birthday/handed = allocate(/obj/item/food/cake/birthday)
	warden.put_in_active_hand(handed)
	TEST_ASSERT_EQUAL(host.on_pre_eat(host, handed, warden), COMSIG_MOB_CANCEL_EAT, "The birthday prisoner ate the cake they were handed")
	TEST_ASSERT_EQUAL(handed.loc, host, "The birthday prisoner did not take the cake")
	TEST_ASSERT_EQUAL(prison.party_stage, "waiting", "A handed cake did not start the party")
	TEST_ASSERT(prison.reserved_supply(handed, guest), "The party cake was not kept for the party")
	prison.end_party()
	TEST_ASSERT(!prison.reserved_supply(handed, guest), "A cake was still kept after the party was off")
	TEST_ASSERT(isturf(handed.loc), "The birthday prisoner kept hold of the cake after the party was off")
	qdel(handed)
	warden.forceMove(prison_spot(home, 5, 5))

	// On the hatch, it is kept for them: no call-out, and nobody takes it as a meal
	var/obj/item/food/cake/birthday/cake = new(hatch.loc)
	TEST_ASSERT_NULL(prison.on_hatch_stocked(hatch, list(cake), warden), "A birthday cake on the hatch got the food call-out")
	TEST_ASSERT_EQUAL(prison.party_stage, "waiting", "A cake on the hatch did not start the party")
	TEST_ASSERT_EQUAL(prison.party_host_ref?.resolve(), host, "The cake was kept for the wrong prisoner")
	starving.set_hunger(10)
	TEST_ASSERT_NULL(prison.find_supply(starving), "The party cake was offered as a meal")
	starving.fend_for_self()
	TEST_ASSERT(!QDELETED(cake) && cake.loc == hatch.loc, "A hungry prisoner left alone ate the party cake")
	var/datum/prisoner_activity/eat/meal = new(starving)
	TEST_ASSERT(!meal.setup(), "A hungry prisoner set off to eat the party cake")
	qdel(meal)

	// The birthday prisoner takes it to a mess table and the yard gathers round (walks done by hand)
	var/datum/prisoner_activity/party_host/hosting = host.activity
	TEST_ASSERT(istype(hosting), "The birthday prisoner did not go for the cake")
	TEST_ASSERT(reach_until_ok(host, cake), "The birthday prisoner could not reach the cake on the hatch")
	TEST_ASSERT_EQUAL(hosting.tick(1), 2, "The birthday prisoner did not set off for a table with the cake") // ACTIVITY_MOVE
	TEST_ASSERT_EQUAL(cake.loc, host, "The birthday prisoner did not pick the cake up")
	host.forceMove(hosting.spot)
	TEST_ASSERT(hosting.arrive(), "The birthday prisoner could not set the cake down")
	TEST_ASSERT(prison.is_mess_table(get_turf(cake)), "The cake was not set down on a mess table")
	TEST_ASSERT(prison.scene_active(), "The party did not take the floor")
	TEST_ASSERT(!prison.wing_can_speak(), "The yard's chatter did not wait for the party")
	TEST_ASSERT(!istype(starving.activity, /datum/prisoner_activity/party_guest), "A prisoner whose AI sleeps was called to the party")
	for(var/mob/living/basic/outpost_prisoner/attending as anything in list(guest, other_guest))
		var/datum/prisoner_activity/party_guest/coming = attending.activity
		TEST_ASSERT(istype(coming), "[attending] was not called over to the party")
		attending.forceMove(coming.spot)
		coming.arrive()

	// Candles, slices, thanks: everyone at the table is fed once, as a cooked meal (PRISONER_FOOD_COOKED 60,
	// PRISONER_MOOD_FED_COOKED 15), and cheers up: the host 20, guests 8 (PRISON_PARTY_HOST_MOOD, _GUEST_MOOD)
	var/list/diners = list(host, guest, other_guest)
	set_moods(diners, 50)
	for(var/mob/living/basic/outpost_prisoner/diner as anything in diners)
		diner.set_hunger(30)
		diner.well_fed_left = 0
	prison.party_tick(1)
	TEST_ASSERT_EQUAL(prison.party_stage, "candles", "The candles did not go out once the guests sat down")
	prison.party_tick(2) // PRISON_PARTY_CANDLES_SECONDS
	TEST_ASSERT_EQUAL(prison.party_stage, "eating", "The cake was not cut after the candles")
	TEST_ASSERT(QDELETED(cake), "The cake was still whole after it was cut")
	for(var/mob/living/basic/outpost_prisoner/diner as anything in diners)
		TEST_ASSERT(istype(diner.held_item, /obj/item/food/cakeslice), "[diner] got no slice")
	prison.party_tick(5) // PRISON_PARTY_EAT_SECONDS
	TEST_ASSERT_NULL(prison.party_stage, "The party did not end")
	TEST_ASSERT(!prison.scene_active(), "The party kept the floor after it ended")
	TEST_ASSERT(host.party_done, "The birthday prisoner could have another party")
	TEST_ASSERT(!findtext(jointext(host.examine_more(warden), " "), "birthday today"), "A closer look still gives the birthday after the party")
	for(var/mob/living/basic/outpost_prisoner/diner as anything in diners)
		TEST_ASSERT(abs(diner.hunger - 90) < 0.01, "[diner] was fed to [diner.hunger], not 90")
		TEST_ASSERT(diner.well_fed_left > 0, "[diner]'s slice did not count as a cooked meal")
		TEST_ASSERT_NULL(diner.held_item, "[diner] still held something after eating")
	TEST_ASSERT(abs(host.mood - 85) < 0.01, "The host's mood went to [host.mood], not 85")
	TEST_ASSERT(abs(guest.mood - 73) < 0.01, "A guest's mood went to [guest.mood], not 73")
	TEST_ASSERT(!istype(guest.activity, /datum/prisoner_activity/party_guest), "A guest stayed at a party that was over")
	TEST_ASSERT(life_said(host, "birthday_thanks"), "The host did not thank whoever brought the cake ([host.last_line])")
	prison.party_tick(10)
	TEST_ASSERT(abs(guest.hunger - 90) < 0.01, "A guest was fed again after the party")

	// One party per birthday: another cake is ordinary food
	var/obj/item/food/cake/birthday/second_cake = new(hatch.loc)
	prison.on_hatch_stocked(hatch, list(second_cake), warden)
	TEST_ASSERT_NULL(prison.party_stage, "A second party started for the same birthday")
	TEST_ASSERT(!prison.reserved_supply(second_cake, starving), "A second cake was kept for a party")
	qdel(second_cake)

	// A kept cake is ordinary food again after 10 minutes without a party (PRISON_PARTY_RESERVE 600)
	prison.give_birthday(guest)
	var/obj/item/food/cake/plain/late_cake = new(hatch.loc)
	TEST_ASSERT_NULL(prison.on_hatch_stocked(hatch, list(late_cake), warden), "A cake for a second birthday got the food call-out")
	TEST_ASSERT(prison.reserved_supply(late_cake, starving), "A cake for a second birthday was not kept")
	prison.pastimes_tick(601)
	TEST_ASSERT_NULL(prison.party_stage, "A party waited more than 10 minutes")
	TEST_ASSERT_EQUAL(prison.find_supply(starving), late_cake, "A cake no longer kept was not ordinary food")
	qdel(late_cake)
	settle_prison_air(home)

// ===== THE COURTSIDE CROWD (4.12) =====

/datum/unit_test/voidcrew_outpost_prison_life_crowd
	parent_type = /datum/unit_test/voidcrew_outpost_prison_life_base

/datum/unit_test/voidcrew_outpost_prison_life_crowd/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("crowdowner")
	TEST_ASSERT_NOTNULL(home, "The crowd test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/obj/structure/hoop/hoop = locate() in prison_spot(home, 9, 11)
	TEST_ASSERT_NOTNULL(hoop, "The hoop is not where the map puts it")
	var/mob/living/carbon/human/coach = make_player(prison_spot(home, 9, 7), "crowdowner")
	var/mob/living/basic/outpost_prisoner/shooter = trouble_awake_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/teammate = trouble_awake_prisoner(prison, prison_spot(home, 10, 8))
	var/mob/living/basic/outpost_prisoner/fan = trouble_awake_prisoner(prison, prison_spot(home, 8, 10))
	prison.refresh_reach()

	// Watching: only while someone plays, from beside the court, facing the hoop
	var/datum/prisoner_activity/watch_game/watching = new(fan)
	TEST_ASSERT_EQUAL(watching.get_weight(), 0, "A prisoner wanted to watch with nobody playing")
	for(var/mob/living/basic/outpost_prisoner/player as anything in list(shooter, teammate))
		var/datum/prisoner_activity/basketball/game = player.start_activity(new /datum/prisoner_activity/basketball(player))
		TEST_ASSERT(game.setup(), "[player] could not start a game of basketball")
		game.started = TRUE
	TEST_ASSERT(watching.get_weight() > 0, "Nobody wanted to watch a game")
	fan.start_activity(watching)
	TEST_ASSERT(watching.setup(), "A watcher found nowhere to stand")
	var/distance = get_dist(watching.spot, hoop)
	TEST_ASSERT(distance >= 2 && distance <= 4 && !(get_dir(hoop, watching.spot) & hoop.dir), "A watcher stood on the court, [distance] tiles from the hoop") // PRISON_WATCH_NEAR, _FAR
	fan.forceMove(watching.spot)
	watching.arrive()
	TEST_ASSERT(fan in prison.game_watchers(hoop), "The watcher was not counted in the crowd")

	// A member shooting makes it a game with staff: the players cheer up, once per 5 minutes (PRISON_STAFF_GAME_MOOD 5)
	set_moods(list(shooter, teammate), 50)
	prison.on_basket(coach, hoop, FALSE)
	TEST_ASSERT_EQUAL(prison.staff_game_left, 120, "A member's shot did not start a game with staff") // PRISON_STAFF_GAME_LAPSE
	TEST_ASSERT(abs(shooter.mood - 55) < 0.01 && abs(teammate.mood - 55) < 0.01, "Playing with staff left the players at [shooter.mood] and [teammate.mood], not 55")
	sleep(1)
	prison.on_basket(coach, hoop, FALSE)
	TEST_ASSERT(abs(shooter.mood - 55) < 0.01, "Playing with staff lifted a player twice inside 5 minutes")

	// One shot heard through several players' games counts once
	sleep(1)
	prison.on_basket(shooter, hoop, TRUE)
	prison.on_basket(shooter, hoop, TRUE)
	TEST_ASSERT_EQUAL(prison.staff_game_yard, 1, "One basket counted [prison.staff_game_yard] times")

	// Played to five (PRISON_STAFF_GAME_POINTS)
	for(var/i in 1 to 4)
		sleep(1)
		prison.on_basket(i % 2 ? shooter : teammate, hoop, TRUE)
	TEST_ASSERT_EQUAL(prison.staff_game_result, "yard", "The yard's fifth basket did not win the game")
	TEST_ASSERT_EQUAL(prison.staff_game_yard, 0, "The score was not reset after the game")
	TEST_ASSERT_EQUAL(prison.staff_game_left, 0, "The game with staff went on after it was won")

	// Prisoners' baskets outside a game with staff keep no score; staff can win too
	sleep(1)
	prison.on_basket(shooter, hoop, TRUE)
	TEST_ASSERT_EQUAL(prison.staff_game_yard, 0, "A basket counted with no game with staff on")
	for(var/i in 1 to 5)
		sleep(1)
		prison.on_basket(coach, hoop, TRUE)
	TEST_ASSERT_EQUAL(prison.staff_game_result, "staff", "Five staff baskets did not win the game")

	// A game with staff lapses two minutes after their last shot
	sleep(1)
	prison.on_basket(coach, hoop, TRUE)
	TEST_ASSERT_EQUAL(prison.staff_game_staff, 1, "A new game with staff did not start at 1")
	prison.pastimes_tick(121)
	TEST_ASSERT_EQUAL(prison.staff_game_staff, 0, "A game with staff outlived its lapse")

	// With nobody playing there is no game with staff, and the watchers drift off
	shooter.end_activity(cancel_ai = FALSE)
	teammate.end_activity(cancel_ai = FALSE)
	sleep(1)
	prison.on_basket(coach, hoop, TRUE)
	TEST_ASSERT_EQUAL(prison.staff_game_left, 0, "A game with staff started with no prisoner playing")
	var/result
	for(var/i in 1 to 10)
		result = watching.tick(1)
		if(result == 1) // ACTIVITY_DONE
			break
	TEST_ASSERT_EQUAL(result, 1, "A watcher kept watching an empty court")
	fan.end_activity(cancel_ai = FALSE)
	settle_prison_air(home)

// ===== MARKS ON THE WALL (4.13) =====

/datum/unit_test/voidcrew_outpost_prison_life_marks
	parent_type = /datum/unit_test/voidcrew_outpost_prison_life_base

/datum/unit_test/voidcrew_outpost_prison_life_marks/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("marksowner")
	TEST_ASSERT_NOTNULL(home, "The marks test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/tenant = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/datum/outpost_prison_cell/home_cell = tenant.cell
	TEST_ASSERT_NOTNULL(home_cell, "The tenant has no cell")
	tenant.forceMove(home_cell.arrival_turf())
	prison.refresh_reach()
	var/list/walls = prison.cell_walls(home_cell)
	TEST_ASSERT(length(walls), "The cell has no walls to mark")
	prison.refresh_conditions()
	var/clean_before = prison.clean_score

	// Once a stay, from inside their own cell, facing one of its walls
	var/datum/prisoner_activity/mark_wall/scratch = tenant.start_activity(new /datum/prisoner_activity/mark_wall(tenant))
	TEST_ASSERT(scratch.get_weight() > 0, "A new prisoner had no wish to mark the wall")
	TEST_ASSERT(scratch.setup(), "A prisoner found no wall of their cell to mark")
	TEST_ASSERT(home_cell.turf_set[scratch.spot] && (scratch.wall in walls), "The mark was to go somewhere other than a wall of their own cell")
	tenant.forceMove(scratch.spot)
	scratch.arrive()
	var/result
	for(var/i in 1 to 10)
		result = scratch.tick(1)
		if(result == 1) // ACTIVITY_DONE
			break
	TEST_ASSERT_EQUAL(result, 1, "Marking the wall never finished")
	tenant.end_activity(cancel_ai = FALSE)
	var/obj/effect/decal/cleanable/crayon/first_mark = tenant.wall_mark_ref?.resolve()
	TEST_ASSERT(first_mark && (first_mark.loc in walls), "No mark was left on the cell's wall")
	TEST_ASSERT(findtext(first_mark.desc, "was here."), "The mark does not say who was here ([first_mark.desc])")
	var/datum/prisoner_activity/mark_wall/again = new(tenant)
	TEST_ASSERT_EQUAL(again.get_weight(), 0, "A prisoner could mark the wall twice in one stay")
	qdel(again)

	// A cell keeps four marks; the fifth replaces the oldest (PRISON_CELL_MARKS_MAX)
	for(var/i in 1 to 4)
		TEST_ASSERT_NOTNULL(prison.add_cell_mark(tenant, walls[1]), "A mark could not be added")
	TEST_ASSERT(QDELETED(first_mark), "The oldest mark was not replaced")
	TEST_ASSERT_EQUAL(length(prison.live_cell_marks(home_cell)), 4, "The cell keeps [length(prison.live_cell_marks(home_cell))] marks, not 4")
	TEST_ASSERT(prison.cell_has_marks(home_cell), "A marked cell counted as unmarked")

	// Marks are not mess
	prison.refresh_conditions()
	TEST_ASSERT_EQUAL(prison.clean_score, clean_before, "Marks on the walls changed the clean score")

	// A scrubbed mark is noticed once, back by its wall (PRISON_MARK_SCRUBBED_MOOD 3, chatty; PRISON_MARK_CHECK_SECONDS 10)
	var/obj/effect/decal/cleanable/crayon/own = tenant.wall_mark_ref?.resolve()
	TEST_ASSERT_NOTNULL(own, "The tenant lost track of their own mark")
	tenant.set_mood(70)
	qdel(own)
	prison.pastimes_tick(10)
	TEST_ASSERT(abs(tenant.mood - 67) < 0.01, "A scrubbed mark left the tenant at [tenant.mood], not 67")
	TEST_ASSERT(life_said(tenant, "mark_scrubbed"), "The tenant did not say their mark was gone ([tenant.last_line])")
	prison.pastimes_tick(10)
	TEST_ASSERT(abs(tenant.mood - 67) < 0.01, "A scrubbed mark was noticed twice")
	settle_prison_air(home)
