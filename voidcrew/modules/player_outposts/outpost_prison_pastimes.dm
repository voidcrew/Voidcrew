/**
 * # Prison pastimes: cards, dice, birthdays, the courtside crowd, marks on the wall
 *
 * Owner: XD (extras-plan.md 4.6, 4.9, 4.12 and 4.13). Numbers in
 * voidcrew/_DEFINES/outpost_prison_life.dm. Friends and rivals are in outpost_prison_life.dm.
 *
 * - Cards and dice: a prisoner takes the deck or a die off a mess table, sits at it and calls one
 *   or two others over, friends first. Real cards are dealt face down in front of each seat, turned
 *   over, and gathered back into the deck; a member of the wing sitting at the table is dealt in.
 *   Dice are rolled across the table at each other. Both are mood activities.
 * - Birthdays: a whole cake put on a serving hatch, or handed to the prisoner whose birthday it is,
 *   is kept for them. They carry it to a mess table, the yard gathers round, the candles go out,
 *   everyone gets a slice and the host thanks whoever brought it. While the party has the floor
 *   (scene_active()) the yard's idle chatter waits.
 * - The courtside crowd: while someone shoots hoops, others stand beside the court and watch,
 *   clapping and heckling. A game with a member of the wing is played to five.
 * - Marks on the wall: once a stay, a prisoner scratches their initial or a doodle into a wall of
 *   their cell. A cell keeps four. Newcomers notice them; a prisoner notices their own scrubbed off.
 *
 * Activities count their own ticks, about one a second while the AI runs (the AI's
 * seconds_per_tick is not a second); the prison's side counts seconds in pastimes_tick(). Every
 * step is a proc tests can call with the prisoners already in place.
 */

// What an activity's tick() wants next, as in outpost_prison_routine.dm (which undefines its own)
#define ACTIVITY_CONTINUE 0
#define ACTIVITY_DONE 1
#define ACTIVITY_MOVE 2

/// Party stages: a cake kept for the host, then the scene
#define PARTY_WAITING "waiting"
#define PARTY_GATHERING "gathering"
#define PARTY_CANDLES "candles"
#define PARTY_EATING "eating"

/datum/outpost_prison
	/// The birthday party: null, PARTY_WAITING (a cake is kept for the host) or a stage of the scene
	var/party_stage
	var/datum/weakref/party_host_ref
	var/datum/weakref/party_cake_ref
	/// Who put the cake on the hatch or handed it over, to be thanked
	var/datum/weakref/party_giver_ref
	/// Seconds the cake stays kept for a party that has not started
	var/party_reserve_left = 0
	/// Seconds in the current stage of the scene, and since the scene began
	var/party_stage_seconds = 0
	var/party_scene_seconds = 0
	/// Where the cake was set down: a mess table tile, or the floor
	var/turf/party_spot
	/// Weakrefs to the prisoners called over
	var/list/party_guests = list()
	/// Who took a slice: list(weakref to the diner, weakref to the slice)
	var/list/party_diners = list()
	/// Between grumbles about a short deck
	COOLDOWN_DECLARE(cards_missing_cooldown)
	/// The last shot the crowd saw, as REF() and world.time: a shot heard through several players' games counts once
	var/last_basket_shooter
	var/last_basket_at = 0
	/// A game with a member of the wing: baskets each, seconds before it lapses, and the member who last shot
	var/staff_game_yard = 0
	var/staff_game_staff = 0
	var/staff_game_left = 0
	var/datum/weakref/staff_game_shooter_ref
	/// How the last game with staff ended: "yard" or "staff"
	var/staff_game_result
	COOLDOWN_DECLARE(crowd_line_cooldown)
	COOLDOWN_DECLARE(crowd_clap_cooldown)
	/// Marks on the cells' walls: "[cell number]" -> weakrefs to the decals, oldest first
	var/list/cell_marks = list()
	/// Seconds since the last look for scrubbed marks
	var/mark_check_clock = 0

/mob/living/basic/outpost_prisoner
	/// Between the lifts a card game gives them
	COOLDOWN_DECLARE(cards_mood_cooldown)
	/// Between the lifts a game of basketball with staff gives them
	COOLDOWN_DECLARE(staff_game_mood_cooldown)
	/// They scratched their mark into the wall this stay
	var/made_wall_mark = FALSE
	/// Their mark and the wall it is on, while they would still notice it gone
	var/datum/weakref/wall_mark_ref
	var/turf/wall_mark_spot

/// Hooks up the prisoner's side of the pastimes; called from setup_extras(). Nothing to hook: the
/// pastimes run from activities and the prison's clock.
/mob/living/basic/outpost_prisoner/proc/setup_pastimes()
	return

/// Advances the party, the game with staff and the marks on the walls by `seconds`
/datum/outpost_prison/proc/pastimes_tick(seconds)
	party_tick(seconds)
	if(staff_game_left > 0)
		staff_game_left -= seconds
		if(staff_game_left <= 0)
			reset_staff_game()
	mark_check_clock += seconds
	if(mark_check_clock >= PRISON_MARK_CHECK_SECONDS)
		mark_check_clock = 0
		check_scrubbed_marks()

/// Everything the pastimes hold, for life_destroy(). Card games and guests end with their prisoners.
/datum/outpost_prison/proc/clear_pastimes()
	clear_party_state()
	cell_marks.Cut()
	last_basket_shooter = null
	reset_staff_game()
	staff_game_result = null

// ===== MESS TABLES =====

/// The mess table tiles joined to `start`, up to PRISON_TABLE_MAX_TILES; empty when `start` is not a mess table
/datum/outpost_prison/proc/mess_table_group(turf/start)
	var/list/group = list()
	if(!is_mess_table(start))
		return group
	group += start
	var/index = 1
	while(index <= length(group) && length(group) < PRISON_TABLE_MAX_TILES)
		var/turf/current = group[index++]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || (next in group) || !is_mess_table(next))
				continue
			group += next
			if(length(group) >= PRISON_TABLE_MAX_TILES)
				break
	return group

/// The stools facing one of `table_turfs`
/datum/outpost_prison/proc/stools_at(list/table_turfs)
	var/list/found = list()
	if(!length(table_turfs))
		return found
	for(var/obj/structure/chair/stool in fixtures_of("stool"))
		if(QDELETED(stool))
			continue
		var/turf/front = table_beside(stool)
		if(front && (front in table_turfs))
			found += stool
	return found

/// Whether `prisoner` could sit on `stool` now: they can walk there, and nobody else sits on it, stands on it or has it
/datum/outpost_prison/proc/stool_free_for(obj/structure/chair/stool, mob/living/basic/outpost_prisoner/prisoner)
	var/turf/seat = get_turf(stool)
	if(QDELETED(stool) || !seat || !prisoner.walkable?[seat] || claimed_by_other(stool, prisoner))
		return FALSE
	if(stool.has_buckled_mobs() && !(prisoner in stool.buckled_mobs))
		return FALSE
	return seat == prisoner.loc || !prisoner.tile_taken(seat)

/// A playing card's rank by its name: Ace 14, King 13, Queen 12, Jack 11, numbers as printed, Jokers 0
/proc/outpost_prison_card_rank(cardname)
	if(!istext(cardname))
		return 0
	var/space = findtext(cardname, " ")
	var/first = space ? copytext(cardname, 1, space) : cardname
	switch(first)
		if("Ace")
			return 14
		if("King")
			return 13
		if("Queen")
			return 12
		if("Jack")
			return 11
		if("Joker")
			return 0
	var/number = text2num(first)
	return isnum(number) ? number : 0

// ===== TABLE GAMES =====

/**
 * A game at a mess table. The host takes what it is played with (fetching it first when their
 * stool is not beside it), sits and calls one or two others over, friends first and never a rival.
 * With someone else seated they play; the subtypes say how. A game nobody sits down to within
 * PRISON_GAME_WAIT ticks is called off. A host's activity has no `game_ref`; a joiner's seat has one.
 */
/datum/prisoner_activity/table_game
	name = "playing at a table"
	weight = 0
	interruptible = FALSE
	mood_activity = TRUE
	/// What the game is played with (the deck, the bag of dice)
	var/datum/weakref/gear_ref
	/// The stool they play from
	var/datum/weakref/stool_ref
	/// The table it is played at
	var/list/turf/table_turfs
	/// The host's part: "fetch", "seat", "wait", "play", "tidy" or "done"
	var/stage = "seat"
	/// Ticks in the current stage
	var/steps = 0
	/// How many others the host calls over
	var/max_joiners = 2
	/// The host's weakrefs to those they called over
	var/list/joiner_refs
	/// A joiner's weakref to the host's game
	var/datum/weakref/game_ref
	/// What the host's joiners are given
	var/seat_type
	/// Whether members of the wing sitting at the table are dealt in
	var/deals_in_members = FALSE

/datum/prisoner_activity/table_game/New(mob/living/basic/outpost_prisoner/doer, datum/prisoner_activity/table_game/host_game)
	. = ..(doer)
	if(host_game)
		game_ref = WEAKREF(host_game)
		table_turfs = host_game.table_turfs?.Copy()

/datum/prisoner_activity/table_game/Destroy()
	table_turfs = null
	joiner_refs = null
	return ..()

/// Whether this is a joiner's seat rather than a host's game
/datum/prisoner_activity/table_game/proc/is_seat()
	return !!game_ref

/// What the game is played with, if it still exists
/datum/prisoner_activity/table_game/proc/gear()
	var/obj/item/thing = gear_ref?.resolve()
	return QDELETED(thing) ? null : thing

/// Whether `thing` is what this game is played with, ready to use; subtypes say what
/datum/prisoner_activity/table_game/proc/gear_usable(obj/item/thing)
	return FALSE

/// Takes up what the game is played with, from where they stand. TRUE if they have it.
/datum/prisoner_activity/table_game/proc/take_gear()
	return FALSE

/// Whether the game can go on with what it is played with
/datum/prisoner_activity/table_game/proc/gear_in_play()
	var/obj/item/thing = gear()
	if(!thing)
		return FALSE
	return thing.loc == prisoner || (isturf(thing.loc) && get_dist(prisoner, thing) <= 1)

/// The first round; subtypes set up their play
/datum/prisoner_activity/table_game/proc/start_play()
	return

/// One tick of play; subtypes play the game
/datum/prisoner_activity/table_game/proc/play_step()
	return ACTIVITY_DONE

/// Puts away what the game was played with; subtypes say how
/datum/prisoner_activity/table_game/proc/end_game()
	return

/// The nearest usable gear on a mess table in reach that nobody else has
/datum/prisoner_activity/table_game/proc/find_gear()
	var/datum/outpost_prison/prison = prisoner.prison
	if(!prisoner.reachable)
		prison.refresh_prisoner_reach(prisoner)
	var/obj/item/best
	var/best_distance = INFINITY
	for(var/obj/structure/table/table in prison.fixtures_of("table"))
		var/turf/top = table.loc
		if(QDELETED(table) || !isturf(top) || !prisoner.reachable?[top] || !prison.is_mess_table(top))
			continue
		for(var/obj/item/thing in top)
			if(!gear_usable(thing) || prison.claimed_by_other(thing, prisoner))
				continue
			var/distance = get_dist(prisoner, thing)
			if(distance < best_distance)
				best = thing
				best_distance = distance
	return best

/// The free stool at this table nearest to `near`, other than `except`
/datum/prisoner_activity/table_game/proc/nearest_free_stool(atom/near, obj/structure/chair/except)
	var/datum/outpost_prison/prison = prisoner.prison
	var/obj/structure/chair/best
	var/best_distance = INFINITY
	for(var/obj/structure/chair/stool as anything in prison.stools_at(table_turfs))
		if(stool == except || !prison.stool_free_for(stool, prisoner))
			continue
		var/distance = get_dist(stool, near)
		if(distance < best_distance)
			best = stool
			best_distance = distance
	return best

/// Whether `other` may be called over: free for leisure (the chat's rule), not hungry, and no rival of the host
/datum/prisoner_activity/table_game/proc/can_invite(mob/living/basic/outpost_prisoner/other)
	if(other == prisoner || QDELETED(other) || !other.routine_allowed() || !other.ai_running())
		return FALSE
	var/datum/prisoner_activity/doing = other.activity
	if(doing && (doing.sleeping || !doing.leisure || !doing.interruptible || istype(doing, /datum/prisoner_activity/chat)))
		return FALSE
	return !other.wants_food() && !prisoner.prison.are_rivals(prisoner, other)

/// Whether someone could play with the host at `host_stool`: a member already seated, or a prisoner free to come over to a free stool
/datum/prisoner_activity/table_game/proc/partners_about(obj/structure/chair/host_stool)
	var/datum/outpost_prison/prison = prisoner.prison
	if(deals_in_members && length(seated_members()))
		return TRUE
	var/free_stools = 0
	for(var/obj/structure/chair/stool as anything in prison.stools_at(table_turfs))
		if(stool != host_stool && !stool.has_buckled_mobs() && !prison.claimed_by_other(stool, prisoner))
			free_stools++
	if(!free_stools)
		return FALSE
	for(var/mob/living/basic/outpost_prisoner/other in prison.prisoners)
		if(can_invite(other))
			return TRUE
	return FALSE

/datum/prisoner_activity/table_game/setup()
	if(is_seat())
		return take_seat()
	if(prisoner.held_item)
		return FALSE
	var/obj/item/thing = find_gear()
	if(!thing)
		return FALSE
	table_turfs = prisoner.prison.mess_table_group(get_turf(thing))
	var/obj/structure/chair/stool = nearest_free_stool(thing)
	if(!stool || !partners_about(stool) || !claim(thing) || !claim(stool))
		return FALSE
	gear_ref = WEAKREF(thing)
	stool_ref = WEAKREF(stool)
	if(get_dist(stool, thing) <= 1)
		stage = "seat"
		spot = get_turf(stool)
	else
		stage = "fetch"
		spot = prisoner.approach_turf(thing)
	return !!spot

/// A joiner's side of setup: a free stool at the host's table, nearest to them
/datum/prisoner_activity/table_game/proc/take_seat()
	var/datum/prisoner_activity/table_game/game = game_ref?.resolve()
	if(QDELETED(game) || !length(table_turfs))
		return FALSE
	var/obj/structure/chair/stool = nearest_free_stool(prisoner, game.stool_ref?.resolve())
	if(!stool || !claim(stool))
		return FALSE
	stool_ref = WEAKREF(stool)
	spot = get_turf(stool)
	return TRUE

/// Sits on their stool, facing the table
/datum/prisoner_activity/table_game/proc/seat_down()
	var/obj/structure/chair/stool = stool_ref?.resolve()
	if(!stool || prisoner.loc != stool.loc)
		return FALSE
	var/turf/front = prisoner.prison?.table_beside(stool)
	return prisoner.sit_on(stool, front ? get_cardinal_dir(prisoner, front) : stool.dir)

/// The table tile in front of `player`'s stool, if they sit at this table
/datum/prisoner_activity/table_game/proc/front_of(mob/living/player)
	var/obj/structure/chair/stool = player?.buckled
	if(!istype(stool))
		return null
	var/turf/front = prisoner.prison?.table_beside(stool)
	return (front && (front in table_turfs)) ? front : null

/datum/prisoner_activity/table_game/arrive()
	spot = null
	if(!started)
		started = TRUE
		ends_at = INFINITY
	if(is_seat())
		seat_down()
		return TRUE
	if(stage == "seat")
		if(!seat_down())
			return FALSE
		take_gear()
		stage = "wait"
		steps = 0
		invite()
	return TRUE

/datum/prisoner_activity/table_game/tick(seconds)
	if(is_seat())
		return seat_tick()
	switch(stage)
		if("fetch")
			var/obj/item/thing = gear()
			if(!thing)
				return ACTIVITY_DONE
			if(!take_gear())
				switch(prisoner.try_reach(thing))
					if(PRISONER_REACH_WAIT)
						return ++steps > 6 ? ACTIVITY_DONE : ACTIVITY_CONTINUE
					if(PRISONER_REACH_FAILED)
						return ACTIVITY_DONE
				if(!take_gear())
					return ACTIVITY_DONE
			var/obj/structure/chair/stool = stool_ref?.resolve()
			if(!stool)
				return ACTIVITY_DONE
			stage = "seat"
			steps = 0
			spot = get_turf(stool)
			return ACTIVITY_MOVE
		if("seat")
			// Standing on the stool already: sit down without a walk.
			var/obj/structure/chair/stool = stool_ref?.resolve()
			spot = stool ? get_turf(stool) : null
			return spot ? ACTIVITY_MOVE : ACTIVITY_DONE
		if("wait")
			if(!gear_in_play())
				return ACTIVITY_DONE
			if(length(players()) >= 2)
				stage = "play"
				steps = 0
				start_play()
				return ACTIVITY_CONTINUE
			if(++steps >= PRISON_GAME_WAIT)
				return ACTIVITY_DONE
			if(!(steps % PRISON_GAME_INVITE_EVERY))
				invite()
			return ACTIVITY_CONTINUE
		if("play")
			if(!gear_in_play() || length(players()) < 2)
				return ACTIVITY_DONE
			steps++
			return play_step()
		if("tidy")
			return tidy_step()
	return ACTIVITY_DONE

/// Putting things away after play; subtypes that need it walk about
/datum/prisoner_activity/table_game/proc/tidy_step()
	return ACTIVITY_DONE

/// A joiner's tick: sits at the table while the host's game goes on
/datum/prisoner_activity/table_game/proc/seat_tick()
	var/datum/prisoner_activity/table_game/game = game_ref?.resolve()
	if(QDELETED(game) || game.prisoner?.activity != game || game.stage == "done" || game.stage == "tidy")
		return ACTIVITY_DONE
	var/obj/structure/chair/stool = stool_ref?.resolve()
	if(!stool)
		return ACTIVITY_DONE
	if(prisoner.buckled != stool && !seat_down())
		return ACTIVITY_DONE
	return ACTIVITY_CONTINUE

/**
 * Who is sitting at the table and playing: list(list(player, stool, the table tile in front of
 * them)), the host first, then their joiners, then (for cards) members of the wing on a stool there.
 */
/datum/prisoner_activity/table_game/proc/players()
	var/list/seats = list()
	var/datum/outpost_prison/prison = prisoner?.prison
	if(!prison)
		return seats
	var/obj/structure/chair/own = stool_ref?.resolve()
	if(own && prisoner.buckled == own)
		seats += list(list(prisoner, own, prison.table_beside(own)))
	for(var/datum/weakref/joiner_ref as anything in joiner_refs)
		var/mob/living/basic/outpost_prisoner/joiner = joiner_ref.resolve()
		var/datum/prisoner_activity/table_game/seat = joiner?.activity
		if(!istype(seat) || seat.game_ref?.resolve() != src || !seat.started)
			continue
		var/obj/structure/chair/stool = seat.stool_ref?.resolve()
		if(stool && joiner.buckled == stool)
			seats += list(list(joiner, stool, prison.table_beside(stool)))
	if(deals_in_members)
		seats += seated_members()
	return seats

/// Members of the wing sitting on a stool at this table, awake: list(list(member, stool, table tile))
/datum/prisoner_activity/table_game/proc/seated_members()
	var/list/seats = list()
	var/datum/outpost_prison/prison = prisoner?.prison
	if(!prison)
		return seats
	for(var/obj/structure/chair/stool as anything in prison.stools_at(table_turfs))
		for(var/mob/living/person in stool.buckled_mobs)
			if(is_outpost_prisoner(person) || person.stat != CONSCIOUS || !prison.is_member(person))
				continue
			seats += list(list(person, stool, prison.table_beside(stool)))
	return seats

/// The prisoners seated and playing, the host included
/datum/prisoner_activity/table_game/proc/seated_prisoners()
	var/list/found = list()
	for(var/list/seat as anything in players())
		if(is_outpost_prisoner(seat[1]))
			found += seat[1]
	return found

/// Calls others over, friends first, until the table has max_joiners of them. Returns how many came.
/datum/prisoner_activity/table_game/proc/invite()
	var/datum/outpost_prison/prison = prisoner.prison
	var/list/live = list()
	for(var/datum/weakref/joiner_ref as anything in joiner_refs)
		var/mob/living/basic/outpost_prisoner/joiner = joiner_ref.resolve()
		var/datum/prisoner_activity/table_game/seat = joiner?.activity
		if(istype(seat) && seat.game_ref?.resolve() == src)
			live += joiner_ref
	joiner_refs = live
	var/room = max_joiners - length(joiner_refs)
	if(room <= 0)
		return 0
	var/list/candidates = list()
	for(var/mob/living/basic/outpost_prisoner/other in shuffle(prison.prisoners))
		if(can_invite(other))
			candidates += other
	var/mob/living/basic/outpost_prisoner/first_called
	var/came = 0
	while(room > 0 && length(candidates))
		var/mob/living/basic/outpost_prisoner/best
		for(var/mob/living/basic/outpost_prisoner/other as anything in candidates)
			if(!best || prison.affinity(prisoner, other) > prison.affinity(prisoner, best))
				best = other
		candidates -= best
		if(!seat_joiner(best))
			continue
		first_called ||= best
		room--
		came++
	if(first_called && context && prison.wing_can_speak())
		prisoner.face_atom(first_called)
		if(prisoner.say_context(context, first_called))
			prison.note_speech()
	return came

/// Gives `other` a seat at this game and sends them to it. TRUE if they are coming.
/datum/prisoner_activity/table_game/proc/seat_joiner(mob/living/basic/outpost_prisoner/other)
	if(!seat_type || QDELETED(other))
		return FALSE
	var/datum/prisoner_activity/table_game/seat = new seat_type(other, src)
	if(!seat.setup())
		qdel(seat)
		return FALSE
	other.start_activity(seat)
	LAZYOR(joiner_refs, WEAKREF(other))
	return TRUE

/// Sends everyone the host called over back to their own business
/datum/prisoner_activity/table_game/proc/release_joiners()
	for(var/datum/weakref/joiner_ref as anything in joiner_refs)
		var/mob/living/basic/outpost_prisoner/joiner = joiner_ref.resolve()
		var/datum/prisoner_activity/table_game/seat = joiner?.activity
		if(istype(seat) && seat.game_ref?.resolve() == src)
			joiner.end_activity()
	joiner_refs = null

/// Puts down what they hold for the game, on the table in front of them
/datum/prisoner_activity/table_game/proc/put_gear_down()
	var/obj/item/thing = prisoner?.held_item
	if(!thing || thing != gear())
		return
	var/obj/structure/chair/stool = stool_ref?.resolve()
	var/turf/front = stool ? prisoner.prison?.table_beside(stool) : null
	prisoner.drop_held_item((front && get_dist(prisoner, front) <= 1) ? front : null)

/datum/prisoner_activity/table_game/finish()
	if(is_seat())
		// Holding the die when the game ended: it goes on the table.
		var/obj/item/held = prisoner?.held_item
		if(istype(held, /obj/item/dice))
			var/obj/structure/chair/stool = stool_ref?.resolve()
			var/turf/front = stool ? prisoner.prison?.table_beside(stool) : null
			prisoner.drop_held_item((front && get_dist(prisoner, front) <= 1) ? front : null)
		return ..()
	stage = "done"
	end_game()
	release_joiners()
	put_gear_down()
	return ..()

// ----- cards -----

/**
 * A few hands of high card. The host deals a real card face down in front of each seat, turns them
 * over, and gathers them back into the deck. A member of the wing sitting at the table is dealt
 * in; one who picks their card up sits the hand out.
 */
/datum/prisoner_activity/cards
	parent_type = /datum/prisoner_activity/table_game
	name = "playing cards"
	leisure = TRUE
	context = "cards"
	weight = 5
	personality_weights = list("chatty" = 1.5, "cheerful" = 1.3, "quiet" = 0.6)
	deals_in_members = TRUE
	seat_type = /datum/prisoner_activity/cards/join
	/// Hands left, what comes next in this one ("deal", "flip" or "collect"), and ticks until it does
	var/rounds_left = 0
	var/round_stage = "deal"
	var/round_wait = 0
	/// Cards out on the table: list(weakref to the card, weakref to its player, the tile it lies on)
	var/list/dealt = list()
	/// Who sat the last hand out, having picked their card up or lost it
	var/list/sat_out = list()
	/// Who won the last hand; null for a push
	var/datum/weakref/last_winner_ref
	/// REF() of the members given credit for sitting in, once a game each
	var/list/credited = list()

/// Sitting in at someone else's card game
/datum/prisoner_activity/cards/join
	name = "playing cards"
	leisure = FALSE
	weight = 0

/datum/prisoner_activity/cards/Destroy()
	dealt = null
	sat_out = null
	return ..()

/datum/prisoner_activity/cards/gear_usable(obj/item/thing)
	var/obj/item/toy/cards/deck/deck = thing
	return istype(deck) && deck.count_cards() >= 2

/datum/prisoner_activity/cards/take_gear()
	var/obj/item/toy/cards/deck/deck = gear()
	if(!deck)
		return FALSE
	if(deck.loc == prisoner)
		return TRUE
	if(prisoner.held_item || prisoner.try_reach(deck) != PRISONER_REACH_OK)
		return FALSE
	return prisoner.take_item(deck)

/datum/prisoner_activity/cards/start_play()
	rounds_left = rand(PRISON_CARDS_ROUNDS_MIN, PRISON_CARDS_ROUNDS_MAX)
	round_stage = "deal"
	round_wait = 1
	playsound(prisoner, 'sound/items/cards/cardshuffle.ogg', 40, TRUE)
	prisoner.manual_emote("shuffles the deck.")
	check_short_deck()

/datum/prisoner_activity/cards/play_step()
	if(--round_wait > 0)
		return ACTIVITY_CONTINUE
	switch(round_stage)
		if("deal")
			if(rounds_left <= 0 || !deal_round())
				return ACTIVITY_DONE
			round_stage = "flip"
			round_wait = 2
		if("flip")
			flip_round()
			round_stage = "collect"
			round_wait = 2
		if("collect")
			collect_round()
			rounds_left--
			round_stage = "deal"
			round_wait = rand(2, 4)
			table_talk()
	return ACTIVITY_CONTINUE

/// Whether the deck is with the host or on the table beside them
/datum/prisoner_activity/cards/proc/deck_at_hand()
	var/obj/item/toy/cards/deck/deck = gear()
	return deck && (deck.loc == prisoner || (isturf(deck.loc) && get_dist(prisoner, deck) <= 2))

/**
 * Deals a card face down onto the table in front of each seat, nudged toward it. FALSE, dealing
 * nothing, when fewer than two sit at the table or the deck cannot go round.
 */
/datum/prisoner_activity/cards/proc/deal_round()
	var/obj/item/toy/cards/deck/deck = gear()
	if(!deck || !deck_at_hand())
		return FALSE
	var/list/seats = players()
	if(length(seats) < 2)
		return FALSE
	var/list/cards = deck.fetch_card_atoms()
	if(length(cards) < length(seats))
		check_short_deck()
		return FALSE
	dealt = list()
	for(var/list/seat as anything in seats)
		var/mob/living/player = seat[1]
		var/obj/structure/chair/stool = seat[2]
		var/turf/front = seat[3]
		if(!front)
			continue
		var/obj/item/toy/singlecard/card = pick(cards)
		cards -= card
		card.forceMove(front)
		card.Flip(CARD_FACEDOWN)
		card.pixel_x = (stool.x - front.x) * 8 + rand(-2, 2)
		card.pixel_y = (stool.y - front.y) * 8 + rand(-2, 2)
		dealt += list(list(WEAKREF(card), WEAKREF(player), front))
	deck.update_appearance()
	playsound(prisoner, 'sound/items/cards/cardflip.ogg', 35, TRUE)
	return TRUE

/**
 * Turns the cards over. The highest wins (outpost_prison_card_rank()); a tie at the top is a push.
 * A card no longer where it was dealt sits its player out, and a member caught holding their own
 * card is told to put it down. Everyone playing cheers up a little, at most every
 * PRISON_CARDS_MOOD_GAP, and a member sitting in counts as a kindness once a game. Returns the
 * winner, or null.
 */
/datum/prisoner_activity/cards/proc/flip_round()
	sat_out = list()
	last_winner_ref = null
	var/list/in_hand = list()
	var/list/best_players = list()
	var/best = -1
	for(var/list/entry as anything in dealt.Copy())
		var/datum/weakref/card_ref = entry[1]
		var/datum/weakref/player_ref = entry[2]
		var/obj/item/toy/singlecard/card = card_ref.resolve()
		var/mob/living/player = player_ref.resolve()
		if(!card || card.loc != entry[3])
			// Picked up or gone: whoever took it keeps it, and this seat is out of the hand.
			dealt -= list(entry)
			if(player)
				sat_out += player
				if(card && get(card, /mob/living) == player && !is_outpost_prisoner(player))
					prisoner.face_atom(player)
					prisoner.say_to_staff("cards_put_down", player)
			continue
		card.Flip(CARD_FACEUP)
		if(!player || player.stat != CONSCIOUS)
			continue
		in_hand += player
		var/rank = outpost_prison_card_rank(card.cardname)
		if(rank > best)
			best = rank
			best_players = list(player)
		else if(rank == best)
			best_players += player
	playsound(prisoner, 'sound/items/cards/cardflip.ogg', 30, TRUE)
	reward_players(in_hand)
	if(length(in_hand) < 2 || length(best_players) != 1)
		return null
	var/mob/living/winner = best_players[1]
	last_winner_ref = WEAKREF(winner)
	react_to_hand(winner, in_hand)
	return winner

/// Mood for the prisoners who played a hand, credit for the members who sat in
/datum/prisoner_activity/cards/proc/reward_players(list/in_hand)
	var/datum/outpost_prison/prison = prisoner.prison
	for(var/mob/living/player as anything in in_hand)
		var/mob/living/basic/outpost_prisoner/inmate = player
		if(istype(inmate))
			if(COOLDOWN_FINISHED(inmate, cards_mood_cooldown))
				COOLDOWN_START(inmate, cards_mood_cooldown, PRISON_CARDS_MOOD_GAP)
				inmate.adjust_mood(PRISON_CARDS_MOOD)
			continue
		var/key = REF(player)
		if(key in credited)
			continue
		credited += key
		prison?.note_staff_kindness(player, PRISON_CARDS_KINDNESS)

/// Someone at the table says something about the hand: the winner crows or a loser grumbles
/datum/prisoner_activity/cards/proc/react_to_hand(mob/living/winner, list/in_hand)
	if(!prob(PRISON_CARDS_TALK_CHANCE))
		return
	var/list/inmate_losers = list()
	for(var/mob/living/basic/outpost_prisoner/loser in in_hand)
		if(loser != winner)
			inmate_losers += loser
	var/mob/living/basic/outpost_prisoner/inmate_winner = is_outpost_prisoner(winner) ? winner : null
	if(inmate_winner && (!length(inmate_losers) || prob(55)))
		var/mob/living/basic/outpost_prisoner/beaten = length(inmate_losers) ? pick(inmate_losers) : null
		if(beaten)
			inmate_winner.face_atom(beaten)
		inmate_winner.say_context("cards_win", beaten)
		return
	if(!length(inmate_losers))
		return
	var/mob/living/basic/outpost_prisoner/grumbler = pick(inmate_losers)
	grumbler.face_atom(winner)
	if(inmate_winner)
		grumbler.say_context("cards_lose", inmate_winner)
	else
		grumbler.say_to_staff("cards_lose", winner)

/// Puts every dealt card still lying where it was dealt back into the deck. A card someone took stays taken.
/datum/prisoner_activity/cards/proc/collect_round()
	var/obj/item/toy/cards/deck/deck = deck_at_hand() ? gear() : null
	for(var/list/entry as anything in dealt)
		var/datum/weakref/card_ref = entry[1]
		var/obj/item/toy/singlecard/card = card_ref.resolve()
		if(deck && card && card.loc == entry[3])
			deck.insert(card)
	dealt = list()

/// Between hands, now and then, a line from someone at the table
/datum/prisoner_activity/cards/proc/table_talk()
	var/datum/outpost_prison/prison = prisoner.prison
	if(!prob(30) || !prison?.wing_can_speak())
		return
	var/list/talkers = seated_prisoners()
	if(!length(talkers))
		return
	var/mob/living/basic/outpost_prisoner/speaker = pick(talkers)
	var/mob/living/basic/outpost_prisoner/other = length(talkers) > 1 ? pick(talkers - speaker) : null
	if(speaker.say_context("cards", other))
		prison.note_speech()

/// A deck with cards missing: one of the players says so, at most every PRISON_CARDS_MISSING_GAP. TRUE if they did.
/datum/prisoner_activity/cards/proc/check_short_deck()
	var/obj/item/toy/cards/deck/deck = gear()
	var/datum/outpost_prison/prison = prisoner.prison
	if(!deck || !prison || length(dealt) || deck.count_cards() >= length(deck.initial_cards))
		return FALSE
	if(!COOLDOWN_FINISHED(prison, cards_missing_cooldown))
		return FALSE
	COOLDOWN_START(prison, cards_missing_cooldown, PRISON_CARDS_MISSING_GAP)
	var/list/talkers = seated_prisoners()
	var/mob/living/basic/outpost_prisoner/speaker = length(talkers) ? pick(talkers) : prisoner
	return speaker.say_context("cards_missing")

/datum/prisoner_activity/cards/end_game()
	collect_round()

/// The admin panel's card game: a prisoner free to play takes a deck to its table and calls others over. A log line, or null.
/datum/outpost_prison/proc/admin_start_cards()
	for(var/mob/living/basic/outpost_prisoner/host in shuffle(prisoners))
		if(!host.ai_running() || !host.routine_allowed())
			continue
		var/datum/prisoner_activity/doing = host.activity
		if(doing && (doing.sleeping || !doing.leisure || istype(doing, /datum/prisoner_activity/table_game)))
			continue
		var/datum/prisoner_activity/cards/game = new(host)
		if(!game.setup())
			qdel(game)
			continue
		host.start_activity(game)
		return "start a card game dealt by prisoner [host.real_name]"
	return null

// ----- dice -----

/**
 * A few rounds of dice: the host rolls a six-sided die across the table to the other player, who
 * rolls it back. tg's dice roll where they land (throw_impact()); the higher roll wins. The die goes
 * back in its bag after.
 */
/datum/prisoner_activity/dice
	parent_type = /datum/prisoner_activity/table_game
	name = "playing dice"
	leisure = TRUE
	context = "dice"
	weight = 3
	personality_weights = list("chatty" = 1.3, "grumpy" = 1.2, "quiet" = 0.7)
	max_joiners = 1
	seat_type = /datum/prisoner_activity/dice/join
	/// The die in play, out of the bag
	var/datum/weakref/die_ref
	/// Who rolls against the host
	var/datum/weakref/partner_ref
	var/rounds_left = 0
	/// 1 while the host rolls, 2 while the partner does
	var/turn = 1
	/// This round's rolls: host, partner
	var/list/rolls = list(0, 0)
	/// A roll is in the air, and ticks it has been
	var/in_flight = FALSE
	var/flight_steps = 0
	/// Ticks before the next roll
	var/roll_wait = 0
	/// Who won the last round; null for a draw
	var/datum/weakref/last_winner_ref
	/// Tries at putting the die away
	var/tidy_tries = 0

/// Rolling against someone else's dice
/datum/prisoner_activity/dice/join
	name = "playing dice"
	leisure = FALSE
	weight = 0

/// A six-sided die with plain numbers in `bag`
/proc/outpost_prison_plain_die(obj/item/storage/dice/bag)
	for(var/obj/item/dice/die in bag)
		if(die.sides == 6 && !length(die.special_faces))
			return die
	return null

/datum/prisoner_activity/dice/gear_usable(obj/item/thing)
	return istype(thing, /obj/item/storage/dice) && !!outpost_prison_plain_die(thing)

/datum/prisoner_activity/dice/take_gear()
	var/obj/item/dice/die = die_ref?.resolve()
	if(die && die.loc == prisoner)
		return TRUE
	var/obj/item/storage/dice/bag = gear()
	if(!bag || prisoner.held_item || prisoner.try_reach(bag) != PRISONER_REACH_OK)
		return FALSE
	die = outpost_prison_plain_die(bag)
	if(!die || !prisoner.take_item(die))
		return FALSE
	die_ref = WEAKREF(die)
	return TRUE

/datum/prisoner_activity/dice/gear_in_play()
	var/obj/item/dice/die = die_ref?.resolve()
	if(QDELETED(die))
		return FALSE
	if(isturf(die.loc))
		return get_dist(prisoner, die) <= 3
	var/mob/living/holder = die.loc
	return istype(holder) && get_dist(prisoner, holder) <= 3

/datum/prisoner_activity/dice/start_play()
	var/list/seats = players()
	partner_ref = length(seats) >= 2 ? WEAKREF(seats[2][1]) : null
	rounds_left = rand(PRISON_DICE_ROUNDS_MIN, PRISON_DICE_ROUNDS_MAX)
	turn = 1
	rolls = list(0, 0)
	roll_wait = 1

/// The prisoner rolling against the host, while they still sit at the table
/datum/prisoner_activity/dice/proc/partner()
	var/mob/living/basic/outpost_prisoner/other = partner_ref?.resolve()
	return (other && front_of(other)) ? other : null

/datum/prisoner_activity/dice/play_step()
	if(in_flight)
		// A roll that never came down counts as it lies.
		if(++flight_steps > PRISON_DICE_FLIGHT_STEPS)
			die_landed(null)
		return ACTIVITY_CONTINUE
	if(--roll_wait > 0)
		return ACTIVITY_CONTINUE
	var/mob/living/basic/outpost_prisoner/roller = turn == 1 ? prisoner : partner()
	if(rounds_left <= 0 || !roller || !roll_die(roller))
		stage = "tidy"
		steps = 0
		return tidy_step()
	return ACTIVITY_CONTINUE

/// Where `roller` rolls to: the table in front of the other player, else the table two tiles off
/datum/prisoner_activity/dice/proc/roll_target(mob/living/basic/outpost_prisoner/roller)
	var/mob/living/basic/outpost_prisoner/other = roller == prisoner ? partner() : prisoner
	var/turf/front = front_of(other)
	if(front && front != get_turf(roller))
		return front
	for(var/turf/tile as anything in table_turfs)
		if(get_dist(roller, tile) == 2)
			return tile
	return front_of(roller)

/// `roller` picks up the die and rolls it across the table. TRUE if it is rolling.
/datum/prisoner_activity/dice/proc/roll_die(mob/living/basic/outpost_prisoner/roller)
	var/obj/item/dice/die = die_ref?.resolve()
	if(QDELETED(die))
		return FALSE
	if(roller.held_item != die)
		if(roller.held_item || roller.try_reach(die) != PRISONER_REACH_OK || !roller.take_item(die))
			return FALSE
	var/turf/target = roll_target(roller)
	if(!target)
		return FALSE
	if(prob(35))
		roller.say_context("dice", roller == prisoner ? partner() : prisoner)
	roller.drop_held_item(roller.loc)
	in_flight = TRUE
	flight_steps = 0
	die.throw_at(target, 3, 1, roller, TRUE, FALSE, CALLBACK(src, PROC_REF(die_landed), WEAKREF(roller)))
	return TRUE

/// A roll came down: reads the die (tg rolled it on impact), and after both rolls, settles the round
/datum/prisoner_activity/dice/proc/die_landed(datum/weakref/roller_ref)
	if(QDELETED(src) || !in_flight || QDELETED(prisoner))
		return
	in_flight = FALSE
	var/obj/item/dice/die = die_ref?.resolve()
	rolls[turn] = (die && isnum(die.result)) ? die.result : 0
	if(turn == 1)
		turn = 2
		roll_wait = 2
		return
	settle_round()
	turn = 1
	rolls = list(0, 0)
	roll_wait = 3
	rounds_left--

/// Both have rolled: the higher roll wins and usually says so. Returns the winner, or null for a draw.
/datum/prisoner_activity/dice/proc/settle_round()
	last_winner_ref = null
	var/mob/living/basic/outpost_prisoner/other = partner_ref?.resolve()
	if(!other || rolls[1] == rolls[2])
		return null
	var/mob/living/basic/outpost_prisoner/winner = rolls[1] > rolls[2] ? prisoner : other
	var/mob/living/basic/outpost_prisoner/loser = winner == prisoner ? other : prisoner
	last_winner_ref = WEAKREF(winner)
	if(prob(70) && winner.stat == CONSCIOUS)
		winner.face_atom(loser)
		winner.say_context("dice_win", loser)
	return winner

/datum/prisoner_activity/dice/tidy_step()
	var/obj/item/dice/die = die_ref?.resolve()
	var/obj/item/storage/dice/bag = gear()
	if(QDELETED(die) || !bag || die.loc == bag || ++tidy_tries > 8)
		return ACTIVITY_DONE
	if(prisoner.held_item != die)
		if(prisoner.try_reach(die) == PRISONER_REACH_OK)
			if(prisoner.held_item || !prisoner.take_item(die))
				return ACTIVITY_DONE
		else
			if(!isturf(die.loc))
				return ACTIVITY_DONE
			spot = prisoner.approach_turf(die)
			return spot ? ACTIVITY_MOVE : ACTIVITY_DONE
	if(prisoner.try_reach(bag) == PRISONER_REACH_OK)
		prisoner.drop_held_item(bag)
		return ACTIVITY_DONE
	if(!isturf(bag.loc))
		return ACTIVITY_DONE
	spot = prisoner.approach_turf(bag)
	return spot ? ACTIVITY_MOVE : ACTIVITY_DONE

/datum/prisoner_activity/dice/put_gear_down()
	var/obj/item/dice/die = die_ref?.resolve()
	if(!die || prisoner?.held_item != die)
		return
	var/obj/item/storage/dice/bag = gear()
	if(bag && prisoner.try_reach(bag) == PRISONER_REACH_OK)
		prisoner.drop_held_item(bag)
		return
	var/obj/structure/chair/stool = stool_ref?.resolve()
	var/turf/front = stool ? prisoner.prison?.table_beside(stool) : null
	prisoner.drop_held_item((front && get_dist(prisoner, front) <= 1) ? front : null)

// ===== BIRTHDAYS =====

/// The cake kept for the party, if there is one
/datum/outpost_prison/proc/party_cake()
	var/obj/item/food/cake/cake = party_cake_ref?.resolve()
	return QDELETED(cake) ? null : cake

/// The prisoner whose birthday it is and who has not had their party, if any is in the wing
/datum/outpost_prison/proc/birthday_host()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.has_birthday && !prisoner.party_done && prisoner.stat != DEAD && prisoner.phase == PRISONER_PRESENT)
			return prisoner
	return null

/**
 * Keeps `cake` for `host`'s party: nobody eats it as a meal while it waits (reserved_supply()).
 * `giver` is whoever put it on the hatch or handed it over. Never sleeps. Returns TRUE if it is kept.
 */
/datum/outpost_prison/proc/start_party(mob/living/basic/outpost_prisoner/host, obj/item/food/cake/cake, mob/living/giver)
	if(party_stage || QDELETED(host) || !istype(cake) || QDELETED(cake))
		return FALSE
	if(!host.has_birthday || host.party_done || host.stat == DEAD || host.phase != PRISONER_PRESENT || !(host in prisoners))
		return FALSE
	clear_party_state()
	party_stage = PARTY_WAITING
	party_host_ref = WEAKREF(host)
	party_cake_ref = WEAKREF(cake)
	party_giver_ref = giver ? WEAKREF(giver) : null
	party_reserve_left = PRISON_PARTY_RESERVE
	add_log("A cake came in for [host.real_name]'s birthday.")
	return TRUE

/// Sends the host to fetch the cake, once they are free. TRUE if they are on it.
/datum/outpost_prison/proc/try_start_party_host()
	var/mob/living/basic/outpost_prisoner/host = party_host_ref?.resolve()
	if(!host || party_stage != PARTY_WAITING || !party_cake())
		return FALSE
	if(istype(host.activity, /datum/prisoner_activity/party_host))
		return TRUE
	if(!host.ai_running() || !host.routine_allowed())
		return FALSE
	var/datum/prisoner_activity/doing = host.activity
	// A meal, a duty or sleep comes first; leisure and games stop for cake.
	if(doing && (doing.sleeping || (!doing.leisure && !doing.interruptible && !istype(doing, /datum/prisoner_activity/table_game))))
		return FALSE
	var/datum/prisoner_activity/party_host/hosting = new(host)
	if(!hosting.setup())
		qdel(hosting)
		return FALSE
	host.start_activity(hosting)
	return TRUE

/// Whether `guest` would come over to the party: awake, free and not busy with a meal or a duty
/datum/outpost_prison/proc/party_guest_free(mob/living/basic/outpost_prisoner/guest)
	if(QDELETED(guest) || !guest.ai_running() || !guest.routine_allowed())
		return FALSE
	var/datum/prisoner_activity/doing = guest.activity
	if(!doing)
		return TRUE
	if(doing.sleeping)
		return FALSE
	return doing.leisure || doing.interruptible || istype(doing, /datum/prisoner_activity/table_game)

/**
 * The host has set the cake down at `spot`: the scene begins, and every free prisoner comes over.
 * Returns TRUE if it began.
 */
/datum/outpost_prison/proc/party_ready(turf/spot)
	var/mob/living/basic/outpost_prisoner/host = party_host_ref?.resolve()
	if(party_stage != PARTY_WAITING || !host || !spot)
		return FALSE
	party_spot = spot
	party_stage = PARTY_GATHERING
	party_stage_seconds = 0
	party_scene_seconds = 0
	party_guests = list()
	for(var/mob/living/basic/outpost_prisoner/guest in prisoners)
		if(guest != host)
			invite_party_guest(guest)
	host.manual_emote("waves everyone over.")
	return TRUE

/// Calls `guest` over to the party. TRUE if they are coming.
/datum/outpost_prison/proc/invite_party_guest(mob/living/basic/outpost_prisoner/guest)
	if(!party_spot || !party_guest_free(guest))
		return FALSE
	var/datum/prisoner_activity/party_guest/coming = new(guest)
	if(!coming.setup())
		qdel(coming)
		return FALSE
	guest.start_activity(coming)
	party_guests += WEAKREF(guest)
	return TRUE

/// The guests at the party now: called over and awake, and (with `arrived_only`) there already
/datum/outpost_prison/proc/present_guests(arrived_only = TRUE)
	var/list/found = list()
	for(var/datum/weakref/guest_ref as anything in party_guests)
		var/mob/living/basic/outpost_prisoner/guest = guest_ref.resolve()
		var/datum/prisoner_activity/party_guest/attending = guest?.activity
		if(!istype(attending) || guest.stat != CONSCIOUS || (arrived_only && !attending.started))
			continue
		found += guest
	return found

/**
 * Advances the party by `seconds`. A kept cake waits PRISON_PARTY_RESERVE seconds for the host to
 * be free to fetch it; after that it is ordinary food. The scene runs gathering (up to
 * PRISON_PARTY_GATHER), the candles, then slices and thanks, and never longer than
 * PRISON_PARTY_SCENE_MAX. A host pulled away mid-scene puts the party back to waiting.
 */
/datum/outpost_prison/proc/party_tick(seconds)
	if(!party_stage)
		return
	var/mob/living/basic/outpost_prisoner/host = party_host_ref?.resolve()
	if(!host || !(host in prisoners) || host.stat == DEAD || host.phase != PRISONER_PRESENT)
		end_party()
		return
	if(party_stage == PARTY_WAITING)
		party_reserve_left -= seconds
		if(!party_cake() || party_reserve_left <= 0)
			end_party()
			return
		try_start_party_host()
		return
	party_stage_seconds += seconds
	party_scene_seconds += seconds
	if(party_scene_seconds > PRISON_PARTY_SCENE_MAX)
		end_party()
		return
	if(!istype(host.activity, /datum/prisoner_activity/party_host))
		pause_party()
		return
	switch(party_stage)
		if(PARTY_GATHERING)
			if(!party_cake())
				end_party()
				return
			if(party_stage_seconds >= PRISON_PARTY_GATHER || length(present_guests()) >= length(present_guests(FALSE)))
				blow_candles()
		if(PARTY_CANDLES)
			if(party_stage_seconds >= PRISON_PARTY_CANDLES_SECONDS)
				serve_party()
		if(PARTY_EATING)
			if(party_stage_seconds >= PRISON_PARTY_EAT_SECONDS)
				finish_party()

/// The candles go out, and the guests cheer and clap
/datum/outpost_prison/proc/blow_candles()
	var/mob/living/basic/outpost_prisoner/host = party_host_ref?.resolve()
	var/obj/item/food/cake/cake = party_cake()
	if(!host || !cake)
		end_party()
		return
	party_stage = PARTY_CANDLES
	party_stage_seconds = 0
	host.face_atom(cake)
	host.manual_emote("blows out the candles.")
	var/cheers = 0
	for(var/mob/living/basic/outpost_prisoner/guest as anything in shuffle(present_guests()))
		guest.face_atom(cake)
		if(cheers < 2)
			addtimer(CALLBACK(src, PROC_REF(say_life_line), WEAKREF(guest), "birthday_party", WEAKREF(host)), (0.5 + 0.8 * cheers) SECONDS)
			cheers++
		else if(prob(70))
			guest.manual_emote("claps.")
			playsound(guest, pick('sound/mobs/humanoids/human/clap/clap1.ogg', 'sound/mobs/humanoids/human/clap/clap2.ogg', 'sound/mobs/humanoids/human/clap/clap3.ogg'), 35, TRUE)

/**
 * The cake is cut: it goes, and a slice of it (cake.slice_type, else a plain slice) goes to the host
 * and every guest within PRISON_PARTY_REACH of it. Anything hidden in the cake falls out onto the
 * table. Crumbs are left behind.
 */
/datum/outpost_prison/proc/serve_party()
	var/mob/living/basic/outpost_prisoner/host = party_host_ref?.resolve()
	var/obj/item/food/cake/cake = party_cake()
	var/turf/center = party_spot || get_turf(cake)
	if(!host || !cake || !center)
		end_party()
		return
	party_stage = PARTY_EATING
	party_stage_seconds = 0
	var/slice_type = cake.slice_type || /obj/item/food/cakeslice/plain
	var/datum/component/food_storage/storage = cake.GetComponent(/datum/component/food_storage)
	var/obj/item/hidden = storage?.stored_item
	if(!QDELETED(hidden) && hidden.loc == cake)
		hidden.forceMove(center)
		center.visible_message(span_notice("[hidden] falls out of [cake]."))
	host.visible_message(span_notice("[host] cuts [cake] and passes the slices round."))
	qdel(cake)
	var/list/diners = list(host)
	for(var/mob/living/basic/outpost_prisoner/guest as anything in present_guests())
		if(get_dist(guest, center) <= PRISON_PARTY_REACH)
			diners += guest
	party_diners = list()
	for(var/mob/living/basic/outpost_prisoner/diner as anything in diners)
		diner.drop_held_item()
		// Beside the table they take theirs off it; further round, the slice is passed along to them.
		// Nobody picks anything up from further off than they can reach (take_item()).
		var/obj/item/food/slice = new slice_type(get_dist(diner, center) <= 1 ? center : diner)
		if(slice.loc == center)
			slice.pixel_x = rand(-6, 6)
			slice.pixel_y = rand(-4, 6)
		if(!diner.take_item(slice))
			qdel(slice)
			continue
		party_diners += list(list(WEAKREF(diner), WEAKREF(slice)))
	new /obj/effect/decal/cleanable/food/crumbs(center)
	playsound(center, 'sound/items/eatfood.ogg', 30, TRUE)

/// Everyone eats their slice; the host thanks whoever brought the cake, and has had their party
/datum/outpost_prison/proc/finish_party()
	var/mob/living/basic/outpost_prisoner/host = party_host_ref?.resolve()
	var/fed = 0
	for(var/list/entry as anything in party_diners)
		var/datum/weakref/diner_ref = entry[1]
		var/datum/weakref/slice_ref = entry[2]
		var/mob/living/basic/outpost_prisoner/diner = diner_ref.resolve()
		var/obj/item/food/slice = slice_ref.resolve()
		if(!diner || !slice || diner.held_item != slice || diner.stat != CONSCIOUS)
			continue
		party_feed(diner, slice)
		diner.adjust_mood(diner == host ? PRISON_PARTY_HOST_MOOD : PRISON_PARTY_GUEST_MOOD)
		qdel(slice)
		fed++
	party_diners = list()
	if(host)
		host.party_done = TRUE
		var/mob/living/giver = party_giver_ref?.resolve()
		if(giver && !QDELETED(giver))
			if(giver in view(7, host))
				host.face_atom(giver)
			host.say_to_staff("birthday_thanks", giver)
			note_staff_kindness(giver, PRISON_PARTY_KINDNESS)
		else
			host.say_context("birthday_thanks")
		add_log("[host.real_name] had a birthday party: [fed] slice\s of cake.")
	end_party()

/**
 * `diner` eats a slice of the birthday cake. It counts as a cooked meal however the cake was made
 * (a birthday cake is junk food to outpost_prisoner_food_tier()), as the build plan asks.
 */
/datum/outpost_prison/proc/party_feed(mob/living/basic/outpost_prisoner/diner, obj/item/food/slice)
	if(outpost_prisoner_food_tier(slice) == "cooked")
		diner.eat_food(slice)
		return
	diner.set_hunger(diner.hunger + PRISONER_FOOD_COOKED)
	diner.adjust_mood(PRISONER_MOOD_FED_COOKED)
	diner.well_fed_left = PRISONER_WELL_FED_TIME / (1 SECONDS)

/// The host was pulled away mid-scene: the guests drift off and the cake waits for them again
/datum/outpost_prison/proc/pause_party()
	var/list/guests = party_guests
	party_guests = list()
	party_stage = PARTY_WAITING
	party_spot = null
	party_stage_seconds = 0
	party_scene_seconds = 0
	dismiss_party_guests(guests)

/// The party is over or off: everyone goes back to their day, and the cake (if uneaten) is ordinary food
/datum/outpost_prison/proc/end_party()
	var/list/guests = party_guests
	var/mob/living/basic/outpost_prisoner/host = party_host_ref?.resolve()
	clear_party_state()
	dismiss_party_guests(guests)
	if(host && istype(host.activity, /datum/prisoner_activity/party_host))
		host.end_activity()

/datum/outpost_prison/proc/dismiss_party_guests(list/guests)
	for(var/datum/weakref/guest_ref as anything in guests)
		var/mob/living/basic/outpost_prisoner/guest = guest_ref.resolve()
		if(guest && istype(guest.activity, /datum/prisoner_activity/party_guest))
			guest.end_activity()

/datum/outpost_prison/proc/clear_party_state()
	party_stage = null
	party_host_ref = null
	party_cake_ref = null
	party_giver_ref = null
	party_reserve_left = 0
	party_stage_seconds = 0
	party_scene_seconds = 0
	party_spot = null
	party_guests = list()
	party_diners = list()

/// Whether `thing` is the cake kept for a party, which nobody may eat as a meal
/datum/outpost_prison/proc/reserved_supply(obj/item/thing, mob/living/basic/outpost_prisoner/prisoner)
	return !!party_stage && !!thing && thing == party_cake()

/**
 * `prisoner` is about to eat `food` fed by `feeder`; TRUE cancels the eat. The party cake is never
 * eaten this way. A whole cake handed to the prisoner whose birthday it is starts their party: they
 * take it, and fetch it to a table once they are free. Runs in a signal handler: never sleeps.
 */
/datum/outpost_prison/proc/pastime_pre_eat(mob/living/basic/outpost_prisoner/prisoner, atom/food, mob/living/feeder)
	if(reserved_supply(food, prisoner))
		// Handing the kept cake to the birthday prisoner saves them fetching it.
		if(party_stage == PARTY_WAITING && prisoner == party_host_ref?.resolve() && istype(feeder) && food.loc == feeder && !prisoner.held_item && feeder.temporarilyRemoveItemFromInventory(food))
			if(!prisoner.take_item(food))
				var/obj/item/dropped = food
				dropped.forceMove(prisoner.drop_location())
			INVOKE_ASYNC(src, PROC_REF(try_start_party_host))
		return TRUE
	var/obj/item/food/cake/cake = food
	if(!istype(cake) || !istype(feeder) || is_outpost_prisoner(feeder) || party_stage)
		return FALSE
	if(!prisoner.has_birthday || prisoner.party_done || prisoner.stat != CONSCIOUS || prisoner.phase != PRISONER_PRESENT)
		return FALSE
	if(cake.loc == feeder && !feeder.temporarilyRemoveItemFromInventory(cake))
		return FALSE
	prisoner.drop_held_item()
	if(!prisoner.take_item(cake))
		cake.forceMove(prisoner.drop_location())
		return TRUE
	start_party(prisoner, cake, feeder)
	INVOKE_ASYNC(prisoner, TYPE_PROC_REF(/atom, manual_emote), "takes [cake] carefully in both hands.")
	INVOKE_ASYNC(src, PROC_REF(try_start_party_host))
	return TRUE

/**
 * Something went on a serving hatch. A whole cake, with a prisoner whose birthday it is waiting on
 * one, is kept for their party. TRUE (no "Food's up!") when the cake was all that went on.
 */
/datum/outpost_prison/proc/pastime_hatch_stocked(obj/structure/table/reinforced/prison_hatch/hatch, list/stocked, mob/user)
	if(party_stage)
		return FALSE
	var/obj/item/food/cake/cake
	for(var/obj/item/food/cake/whole in stocked)
		if(!QDELETED(whole) && whole.loc == hatch?.loc)
			cake = whole
			break
	var/mob/living/basic/outpost_prisoner/host = birthday_host()
	if(!cake || !host || !start_party(host, cake, user))
		return FALSE
	INVOKE_ASYNC(src, PROC_REF(try_start_party_host))
	return length(stocked) == 1

/**
 * The birthday prisoner's part: fetch the cake (unless it is already on a mess table), carry it to
 * a stool at a mess table and set it down there (party_ready()), then stay for the party.
 */
/datum/prisoner_activity/party_host
	name = "throwing a birthday party"
	weight = 0
	interruptible = FALSE
	/// "fetch", "carry" or "party"
	var/stage = "fetch"
	var/datum/weakref/seat_ref
	/// Where the cake goes: a mess table tile, or null for the floor at their feet
	var/turf/table_turf
	var/waited = 0

/datum/prisoner_activity/party_host/Destroy()
	table_turf = null
	return ..()

/datum/prisoner_activity/party_host/setup()
	var/datum/outpost_prison/prison = prisoner.prison
	var/obj/item/food/cake/cake = prison?.party_cake()
	if(!cake)
		return FALSE
	if(prisoner.held_item == cake)
		return pick_table()
	if(!isturf(cake.loc))
		return FALSE
	// Already on a mess table (a party put off earlier): it happens there.
	if(prison.is_mess_table(cake.loc))
		return pick_table(cake.loc)
	spot = prisoner.approach_turf(cake)
	return !!spot

/**
 * Where to set the cake down: a free stool at `at_table` (a mess table tile), else at the mess table
 * with the most free stools, else beside any mess table, else right where they stand.
 */
/datum/prisoner_activity/party_host/proc/pick_table(turf/at_table)
	var/datum/outpost_prison/prison = prisoner.prison
	stage = "carry"
	var/list/tables = list()
	if(at_table)
		tables += list(prison.mess_table_group(at_table))
	else
		var/list/seen = list()
		for(var/obj/structure/table/table in prison.fixtures_of("table"))
			var/turf/top = table.loc
			if(!isturf(top) || seen[top] || !prison.is_mess_table(top) || !prisoner.reachable?[top])
				continue
			var/list/group = prison.mess_table_group(top)
			for(var/turf/tile as anything in group)
				seen[tile] = TRUE
			tables += list(group)
	var/obj/structure/chair/best_stool
	var/best_free = 0
	for(var/list/group as anything in tables)
		var/list/free = list()
		for(var/obj/structure/chair/stool as anything in prison.stools_at(group))
			if(prison.stool_free_for(stool, prisoner))
				free += stool
		if(length(free) <= best_free)
			continue
		best_free = length(free)
		best_stool = null
		// Beside the cake when it is on the table already, else the nearest to walk to
		var/atom/near = at_table || prisoner
		for(var/obj/structure/chair/stool as anything in free)
			if(!best_stool || get_dist(near, stool) < get_dist(near, best_stool))
				best_stool = stool
	if(best_stool && claim(best_stool))
		seat_ref = WEAKREF(best_stool)
		table_turf = prison.table_beside(best_stool)
		spot = get_turf(best_stool)
		return TRUE
	for(var/list/group as anything in tables)
		for(var/turf/tile as anything in group)
			var/turf/stand = prisoner.approach_turf(tile)
			if(stand)
				table_turf = tile
				spot = stand
				return TRUE
	table_turf = null
	spot = null
	return TRUE

/datum/prisoner_activity/party_host/arrive()
	spot = null
	if(!started)
		started = TRUE
		ends_at = INFINITY
	if(stage == "carry")
		return set_down()
	return TRUE

/**
 * At the table: sits down and puts the cake in front of them (or sits by it, when it is on the
 * table already), and the party begins. FALSE if the cake is neither in their hands nor beside them.
 */
/datum/prisoner_activity/party_host/proc/set_down()
	var/datum/outpost_prison/prison = prisoner.prison
	var/obj/item/food/cake/cake = prison?.party_cake()
	if(!cake)
		return FALSE
	var/turf/put
	if(prisoner.held_item == cake)
		put = (table_turf && get_dist(prisoner, table_turf) <= 1) ? table_turf : get_turf(prisoner)
	else if(isturf(cake.loc) && get_dist(prisoner, cake) <= 1)
		put = cake.loc
	else
		return FALSE
	var/obj/structure/chair/stool = seat_ref?.resolve()
	if(stool && prisoner.loc == stool.loc)
		prisoner.sit_on(stool, get_cardinal_dir(prisoner, put) || stool.dir)
	if(prisoner.held_item == cake)
		prisoner.drop_held_item(put)
	stage = "party"
	return prison.party_ready(put)

/datum/prisoner_activity/party_host/tick(seconds)
	var/datum/outpost_prison/prison = prisoner.prison
	var/obj/item/food/cake/cake = prison?.party_cake()
	switch(stage)
		if("fetch")
			if(!cake)
				return ACTIVITY_DONE
			if(prisoner.held_item != cake)
				switch(prisoner.try_reach(cake))
					if(PRISONER_REACH_WAIT)
						return ++waited > 6 ? ACTIVITY_DONE : ACTIVITY_CONTINUE
					if(PRISONER_REACH_FAILED)
						return ACTIVITY_DONE
				prisoner.drop_held_item()
				if(!prisoner.take_item(cake))
					return ACTIVITY_DONE
				prisoner.visible_message(span_notice("[prisoner] picks up [cake], grinning."))
			pick_table()
			if(spot)
				return ACTIVITY_MOVE
			return set_down() ? ACTIVITY_CONTINUE : ACTIVITY_DONE
		if("carry")
			// Nowhere to walk to: the party is where they stand.
			if(!cake || (!spot && !set_down()))
				return ACTIVITY_DONE
			return ACTIVITY_CONTINUE
		if("party")
			if(!prison?.scene_active())
				return ACTIVITY_DONE
			if(cake)
				prisoner.face_atom(cake)
			return ACTIVITY_CONTINUE
	return ACTIVITY_DONE

/datum/prisoner_activity/party_host/finish()
	// The cake goes down with them, kept or not: nobody walks about holding a cake after the party is off.
	if(istype(prisoner?.held_item, /obj/item/food/cake))
		prisoner.drop_held_item((table_turf && get_dist(prisoner, table_turf) <= 1) ? table_turf : null)
	return ..()

/// A guest at a birthday party: a stool at the party's table, or a spot beside the cake, facing it
/datum/prisoner_activity/party_guest
	name = "at a birthday party"
	weight = 0
	interruptible = FALSE
	var/datum/weakref/seat_ref

/datum/prisoner_activity/party_guest/setup()
	var/datum/outpost_prison/prison = prisoner.prison
	var/turf/center = prison?.party_spot
	if(!center)
		return FALSE
	var/obj/structure/chair/best_stool
	for(var/obj/structure/chair/stool as anything in prison.stools_at(prison.mess_table_group(center)))
		if(!prison.stool_free_for(stool, prisoner))
			continue
		if(!best_stool || get_dist(stool, center) < get_dist(best_stool, center))
			best_stool = stool
	if(best_stool && claim(best_stool))
		seat_ref = WEAKREF(best_stool)
		spot = get_turf(best_stool)
		return TRUE
	var/turf/best
	for(var/turf/tile as anything in prisoner.walkable)
		var/distance = get_dist(tile, center)
		if(distance < 1 || distance > PRISON_PARTY_REACH || prison.cell_at(tile))
			continue
		if((tile != prisoner.loc && prisoner.tile_taken(tile)) || prison.claimed_by_other(tile, prisoner))
			continue
		if(!best || distance < get_dist(best, center) || (distance == get_dist(best, center) && get_dist(prisoner, tile) < get_dist(prisoner, best)))
			best = tile
	if(!best || !claim(best))
		return FALSE
	spot = best
	return TRUE

/datum/prisoner_activity/party_guest/arrive()
	spot = null
	if(!started)
		started = TRUE
		ends_at = INFINITY
	var/turf/center = prisoner.prison?.party_spot
	var/obj/structure/chair/stool = seat_ref?.resolve()
	if(stool && prisoner.loc == stool.loc)
		prisoner.sit_on(stool, center ? get_cardinal_dir(prisoner, center) : stool.dir)
	else if(center)
		prisoner.face_atom(center)
	return TRUE

/datum/prisoner_activity/party_guest/tick(seconds)
	var/datum/outpost_prison/prison = prisoner.prison
	if(!prison?.scene_active())
		return ACTIVITY_DONE
	if(prison.party_spot && !prisoner.buckled)
		prisoner.face_atom(prison.party_spot)
	return ACTIVITY_CONTINUE

/datum/prisoner_activity/party_guest/finish()
	// Called away before they ate their slice: it goes down with them, ordinary food again.
	if(istype(prisoner?.held_item, /obj/item/food))
		prisoner.drop_held_item()
	return ..()

// ===== THE COURTSIDE CROWD =====

/// The hoop a prisoner is shooting at now, or null when nobody is playing
/datum/outpost_prison/proc/game_hoop()
	for(var/mob/living/basic/outpost_prisoner/player in prisoners)
		var/datum/prisoner_activity/basketball/game = player.activity
		if(!istype(game) || !game.started || player.stat != CONSCIOUS)
			continue
		var/obj/structure/hoop/hoop = game.hoop_ref?.resolve()
		if(hoop)
			return hoop
	return null

/// Prisoners playing basketball now
/datum/outpost_prison/proc/basketball_players()
	var/list/players = list()
	for(var/mob/living/basic/outpost_prisoner/player in prisoners)
		if(player.stat == CONSCIOUS && istype(player.activity, /datum/prisoner_activity/basketball) && player.activity.started)
			players += player
	return players

/// Prisoners watching the game at `hoop`
/datum/outpost_prison/proc/game_watchers(obj/structure/hoop/hoop)
	var/list/watchers = list()
	for(var/mob/living/basic/outpost_prisoner/watcher in prisoners)
		var/datum/prisoner_activity/watch_game/watching = watcher.activity
		if(istype(watching) && watching.started && watcher.stat == CONSCIOUS && watching.hoop_ref?.resolve() == hoop)
			watchers += watcher
	return watchers

/datum/outpost_prison/proc/reset_staff_game()
	staff_game_yard = 0
	staff_game_staff = 0
	staff_game_left = 0
	staff_game_shooter_ref = null

/// The score of the game with staff, from the yard's side: "3-2 to us", "2 all"
/datum/outpost_prison/proc/staff_game_band()
	if(staff_game_yard == staff_game_staff)
		return "[staff_game_yard] all"
	if(staff_game_yard > staff_game_staff)
		return "[staff_game_yard]-[staff_game_staff] to us"
	return "[staff_game_staff]-[staff_game_yard] to you lot"

/**
 * A shot at the hoop by `shooter` came down. Every playing prisoner's game hears a shot by anyone
 * else, so one shot is counted once, by shooter and world.time. A member shooting while prisoners
 * play makes it a game with staff, to PRISON_STAFF_GAME_POINTS, lapsing PRISON_STAFF_GAME_LAPSE
 * seconds after their last shot; the players cheer up for it, at most every
 * PRISON_STAFF_GAME_MOOD_GAP each. The crowd reacts. Runs in a signal handler: the reaction is async.
 */
/datum/outpost_prison/proc/on_basket(mob/living/shooter, obj/structure/hoop/hoop, scored)
	if(!istype(shooter) || !hoop)
		return
	var/shooter_key = REF(shooter)
	if(last_basket_shooter == shooter_key && last_basket_at == world.time)
		return
	last_basket_shooter = shooter_key
	last_basket_at = world.time
	var/score_event
	if(!is_outpost_prisoner(shooter))
		if(is_member(shooter) && length(basketball_players()))
			staff_game_left = PRISON_STAFF_GAME_LAPSE
			staff_game_shooter_ref = WEAKREF(shooter)
			lift_staff_game_players()
			if(scored)
				staff_game_staff++
				score_event = "call"
	else if(scored && staff_game_left > 0)
		staff_game_yard++
		score_event = "call"
	var/band = staff_game_band()
	var/datum/weakref/staff_ref = staff_game_shooter_ref
	if(staff_game_yard >= PRISON_STAFF_GAME_POINTS || staff_game_staff >= PRISON_STAFF_GAME_POINTS)
		staff_game_result = staff_game_yard >= PRISON_STAFF_GAME_POINTS ? "yard" : "staff"
		score_event = staff_game_result == "yard" ? "yard_won" : "staff_won"
		reset_staff_game()
	INVOKE_ASYNC(src, PROC_REF(crowd_reacts), WEAKREF(shooter), hoop, scored, score_event, band, staff_ref)

/// Each prisoner playing now cheers up for playing with staff, at most every PRISON_STAFF_GAME_MOOD_GAP
/datum/outpost_prison/proc/lift_staff_game_players()
	for(var/mob/living/basic/outpost_prisoner/player as anything in basketball_players())
		if(!COOLDOWN_FINISHED(player, staff_game_mood_cooldown))
			continue
		COOLDOWN_START(player, staff_game_mood_cooldown, PRISON_STAFF_GAME_MOOD_GAP)
		player.adjust_mood(PRISON_STAFF_GAME_MOOD)

/**
 * The crowd at `hoop` sees a shot: in a game with staff someone calls the score or the result;
 * otherwise watchers clap a basket and one of them cheers it, or heckles a miss.
 */
/datum/outpost_prison/proc/crowd_reacts(datum/weakref/shooter_ref, obj/structure/hoop/hoop, scored, score_event, band, datum/weakref/staff_ref)
	if(QDELETED(hoop))
		return
	var/mob/living/shooter = shooter_ref?.resolve()
	var/list/watchers = game_watchers(hoop)
	for(var/mob/living/basic/outpost_prisoner/watcher as anything in watchers)
		watcher.face_atom(hoop)
	if(score_event)
		var/list/announcers = length(watchers) ? watchers : basketball_players()
		var/mob/living/basic/outpost_prisoner/announcer = length(announcers) ? pick(announcers) : null
		var/mob/living/staff = staff_ref?.resolve()
		switch(score_event)
			if("call")
				announcer?.say_context_with("game_score_call", list("{band}" = band))
			if("yard_won")
				announcer?.say_to_staff("game_won", staff)
			if("staff_won")
				announcer?.say_to_staff("game_lost", staff)
	if(scored && length(watchers) && COOLDOWN_FINISHED(src, crowd_clap_cooldown))
		COOLDOWN_START(src, crowd_clap_cooldown, PRISON_CROWD_CLAP_GAP)
		for(var/mob/living/basic/outpost_prisoner/watcher as anything in watchers)
			if(prob(70))
				watcher.manual_emote("claps.")
				playsound(watcher, pick('sound/mobs/humanoids/human/clap/clap1.ogg', 'sound/mobs/humanoids/human/clap/clap2.ogg', 'sound/mobs/humanoids/human/clap/clap3.ogg'), 35, TRUE)
	if(score_event || !length(watchers) || !COOLDOWN_FINISHED(src, crowd_line_cooldown))
		return
	var/context = scored ? "watch_cheer" : (prob(60) ? "game_heckle" : null)
	if(!context)
		return
	COOLDOWN_START(src, crowd_line_cooldown, PRISON_CROWD_LINE_GAP)
	var/mob/living/basic/outpost_prisoner/speaker = pick(watchers)
	if(is_outpost_prisoner(shooter))
		speaker.say_context(context, shooter)
	else if(shooter)
		speaker.say_to_staff(context, shooter)
	else
		speaker.say_context(context)

/// Standing beside the court while someone plays, facing the hoop. Cheers and heckles come from the shots themselves (crowd_reacts()).
/datum/prisoner_activity/watch_game
	name = "watching the game"
	leisure = TRUE
	weight = 8
	personality_weights = list("cheerful" = 1.4, "chatty" = 1.3, "grumpy" = 0.8, "quiet" = 0.7)
	min_duration = 30 SECONDS
	max_duration = 90 SECONDS
	var/datum/weakref/hoop_ref
	/// Ticks since anyone last played
	var/idle_steps = 0

/datum/prisoner_activity/watch_game/get_weight()
	if(!prisoner.prison?.game_hoop())
		return 0
	return ..()

/datum/prisoner_activity/watch_game/setup()
	var/obj/structure/hoop/hoop = prisoner.prison.game_hoop()
	if(!hoop)
		return FALSE
	var/turf/stand = watch_spot(hoop)
	if(!stand || !claim(stand))
		return FALSE
	hoop_ref = WEAKREF(hoop)
	spot = stand
	return TRUE

/**
 * A tile PRISON_WATCH_NEAR to PRISON_WATCH_FAR from the hoop, off the court: beside the hoop rather
 * than in front of it, where the players shoot from. Failing that, the court's far edge.
 */
/datum/prisoner_activity/watch_game/proc/watch_spot(obj/structure/hoop/hoop)
	var/datum/outpost_prison/prison = prisoner.prison
	var/list/beside = list()
	var/list/far_edge = list()
	for(var/turf/tile as anything in prisoner.walkable)
		var/distance = get_dist(tile, hoop)
		if(distance < PRISON_WATCH_NEAR || distance > PRISON_WATCH_FAR + 1 || prison.cell_at(tile) || (locate(/obj/machinery/door) in tile))
			continue
		if((tile != prisoner.loc && prisoner.tile_taken(tile)) || prison.claimed_by_other(tile, prisoner))
			continue
		if(!(get_dir(hoop, tile) & hoop.dir))
			if(distance <= PRISON_WATCH_FAR)
				beside += tile
		else if(distance > PRISON_WATCH_FAR)
			far_edge += tile
	if(length(beside))
		return pick(beside)
	return length(far_edge) ? pick(far_edge) : null

/datum/prisoner_activity/watch_game/begin()
	. = ..()
	var/obj/structure/hoop/hoop = hoop_ref?.resolve()
	if(hoop)
		prisoner.face_atom(hoop)

/datum/prisoner_activity/watch_game/tick(seconds)
	var/obj/structure/hoop/hoop = hoop_ref?.resolve()
	if(!hoop)
		return ACTIVITY_DONE
	if(prisoner.prison?.game_hoop())
		idle_steps = 0
	else if(++idle_steps > 5)
		return ACTIVITY_DONE
	prisoner.face_atom(hoop)
	return ..()

// ===== MARKS ON THE WALL =====

/// The walls around `cell`'s inside, not counting its door
/datum/outpost_prison/proc/cell_walls(datum/outpost_prison_cell/cell)
	var/list/walls = list()
	for(var/turf/tile as anything in cell?.turfs)
		for(var/direction in GLOB.cardinals)
			var/turf/beside = get_step(tile, direction)
			if(!beside || beside == cell.door_turf || !isclosedturf(beside) || beside.loc != wing || (beside in walls))
				continue
			walls += beside
	return walls

/// The marks on `cell`'s walls still there, oldest first
/datum/outpost_prison/proc/live_cell_marks(datum/outpost_prison_cell/cell)
	var/key = "[cell?.number]"
	var/list/marks = cell_marks[key]
	if(!marks)
		return list()
	for(var/datum/weakref/mark_ref as anything in marks.Copy())
		var/obj/effect/decal/cleanable/crayon/mark = mark_ref.resolve()
		if(QDELETED(mark))
			marks -= mark_ref
	return marks

/// Whether anyone left a mark on `cell`'s walls that is still there
/datum/outpost_prison/proc/cell_has_marks(datum/outpost_prison_cell/cell)
	return cell && length(live_cell_marks(cell)) > 0

/// "R.D." for Rosa Dale
/proc/outpost_prisoner_initials(name)
	var/initials = ""
	for(var/part in splittext("[name]", " "))
		if(length(part))
			initials += "[uppertext(copytext(part, 1, 2))]."
	return initials || "Someone"

/// The crayon state for a prisoner's mark: their first initial, or a doodle
/proc/outpost_prisoner_mark_state(mob/living/basic/outpost_prisoner/prisoner)
	var/letter = lowertext(copytext(prisoner.real_name, 1, 2))
	if(prob(PRISON_MARK_INITIAL_CHANCE) && length(letter) == 1 && text2ascii(letter) >= 97 && text2ascii(letter) <= 122)
		return letter
	return pick("heart", "star", "skull", "peace", "stickman")

/// What a mark of that crayon state is called
/proc/outpost_prisoner_mark_name(state)
	switch(state)
		if("peace")
			return "scratched peace sign"
		if("stickman")
			return "scratched stick figure"
	if(length(state) == 1)
		return "scratched initial"
	return "scratched [state]"

/**
 * `prisoner` scratches their mark into `wall`, a wall of their cell: their initial or a doodle,
 * "R.D. was here." A cell keeps PRISON_CELL_MARKS_MAX marks; a new one replaces the oldest.
 * Crayon marks are not mess (outpost_prison_conditions.dm). Returns the mark, or null.
 */
/datum/outpost_prison/proc/add_cell_mark(mob/living/basic/outpost_prisoner/prisoner, turf/wall)
	var/datum/outpost_prison_cell/home = prisoner?.cell
	if(!home || !isclosedturf(wall))
		return null
	var/list/marks = live_cell_marks(home)
	while(length(marks) >= PRISON_CELL_MARKS_MAX)
		var/datum/weakref/oldest_ref = marks[1]
		marks.Cut(1, 2)
		var/obj/effect/decal/cleanable/crayon/oldest = oldest_ref.resolve()
		if(oldest)
			forget_wall_mark(oldest)
			qdel(oldest)
	var/state = outpost_prisoner_mark_state(prisoner)
	var/obj/effect/decal/cleanable/crayon/mark = new(wall, PRISON_MARK_COLOUR, state, outpost_prisoner_mark_name(state), 0, null, "[outpost_prisoner_initials(prisoner.real_name)] was here.")
	if(QDELETED(mark))
		return null
	mark.pixel_x = rand(-8, 8)
	mark.pixel_y = rand(-6, 8)
	marks += WEAKREF(mark)
	cell_marks["[home.number]"] = marks
	prisoner.made_wall_mark = TRUE
	prisoner.wall_mark_ref = WEAKREF(mark)
	prisoner.wall_mark_spot = wall
	return mark

/// A mark is going for a newer one: whoever made it no longer looks for it
/datum/outpost_prison/proc/forget_wall_mark(obj/effect/decal/cleanable/crayon/mark)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.wall_mark_ref?.resolve() == mark)
			prisoner.wall_mark_ref = null
			prisoner.wall_mark_spot = null

/**
 * A prisoner whose mark has been scrubbed off notices once they are back by its wall: they say so
 * once and lose PRISON_MARK_SCRUBBED_MOOD. Returns how many noticed.
 */
/datum/outpost_prison/proc/check_scrubbed_marks()
	var/noticed = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(!prisoner.wall_mark_ref || prisoner.stat != CONSCIOUS || prisoner.phase != PRISONER_PRESENT)
			continue
		var/obj/effect/decal/cleanable/crayon/mark = prisoner.wall_mark_ref.resolve()
		if(!QDELETED(mark))
			continue
		var/turf/wall = prisoner.wall_mark_spot
		if(wall && get_dist(prisoner, wall) > PRISON_MARK_NOTICE_RANGE)
			continue
		prisoner.wall_mark_ref = null
		prisoner.wall_mark_spot = null
		prisoner.adjust_mood(-PRISON_MARK_SCRUBBED_MOOD)
		if(wall)
			prisoner.face_atom(wall)
		prisoner.say_context("mark_scrubbed")
		noticed++
	return noticed

/// Once a stay, a prisoner scratches their mark into a wall of their own cell
/datum/prisoner_activity/mark_wall
	name = "scratching at the wall"
	leisure = TRUE
	weight = 1
	personality_weights = list("grumpy" = 1.3, "nervous" = 1.2, "cheerful" = 0.8)
	var/turf/wall
	/// Ticks spent at it
	var/steps = 0

/datum/prisoner_activity/mark_wall/Destroy()
	wall = null
	return ..()

/datum/prisoner_activity/mark_wall/get_weight()
	if(prisoner.made_wall_mark || !prisoner.cell)
		return 0
	return ..()

/datum/prisoner_activity/mark_wall/setup()
	var/datum/outpost_prison_cell/home = prisoner.cell
	if(!home || prisoner.made_wall_mark)
		return FALSE
	for(var/turf/candidate as anything in shuffle(prisoner.prison.cell_walls(home)))
		for(var/direction in GLOB.cardinals)
			var/turf/stand = get_step(candidate, direction)
			if(!stand || !home.turf_set[stand] || !prisoner.walkable?[stand])
				continue
			if(stand != prisoner.loc && prisoner.tile_taken(stand))
				continue
			wall = candidate
			spot = stand
			return TRUE
	return FALSE

/datum/prisoner_activity/mark_wall/begin()
	started = TRUE
	ends_at = INFINITY
	if(wall)
		prisoner.face_atom(wall)
	prisoner.manual_emote(pick("scratches at the wall with the end of a spoon.", "starts carving something into the wall.", "scrapes at the wall, tongue between [prisoner.p_their()] teeth."))

/datum/prisoner_activity/mark_wall/tick(seconds)
	if(!wall || !prisoner.cell?.contains(prisoner))
		return ACTIVITY_DONE
	prisoner.face_atom(wall)
	if(++steps < PRISON_MARK_STEPS)
		return ACTIVITY_CONTINUE
	if(prisoner.prison?.add_cell_mark(prisoner, wall))
		prisoner.visible_message(span_notice("[prisoner] steps back and looks at [prisoner.p_their()] handiwork."))
	return ACTIVITY_DONE

#undef ACTIVITY_CONTINUE
#undef ACTIVITY_DONE
#undef ACTIVITY_MOVE
#undef PARTY_WAITING
#undef PARTY_GATHERING
#undef PARTY_CANDLES
#undef PARTY_EATING
