/**
 * # Prison life: friends, rivals and farewells
 *
 * Owner: XD (extras-plan.md 4.4, and the scene gate of 4.9). Pairs of prisoners grow friendly or
 * hostile through chats, shared meals, games, spats and fights. Friends seek each other out, break
 * up each other's arguments and say goodbye at release; rivals argue over grudges. Numbers in
 * voidcrew/_DEFINES/outpost_prison_life.dm.
 *
 * Affinity is kept per pair, -100 to 100, keyed by the two prisoners' REF()s in sorted order, and
 * dropped when either leaves. Nothing here holds a prisoner itself, so a hard delete leaves no
 * dangling reference. Only an arrival who beams in through intake can turn out to know someone
 * inside or have a birthday; a prisoner made any other way (an admin spawn, a test) starts with no
 * history.
 *
 * The birthday party itself, the card and dice games, the courtside crowd and marks on the wall
 * are in outpost_prison_pastimes.dm. life_destroy() clears both files' state.
 */

/datum/outpost_prison
	/// How pairs of prisoners get on: "[REF(one)]|[REF(two)]" (REFs in sorted order) -> -100 to 100
	var/list/affinities = list()
	/// Seconds two prisoners have played basketball together since their last PRISON_AFFINITY_BASKETBALL, by pair key
	var/list/coplay_seconds = list()
	/// Tests pin the break-up chance here (percent); null uses PRISON_BREAKUP_CHANCE
	var/breakup_chance_override

/datum/outpost_prison_fight
	/// A friend of one of the fighters has had their one try at breaking it up
	var/breakup_tried = FALSE

/mob/living/basic/outpost_prisoner
	/// It is their birthday; `party_done` once the yard has had the cake
	var/has_birthday = FALSE
	var/party_done = FALSE
	/// Lines they are due to say shortly: list(list(seconds left, context, weakref to who they say it to))
	var/list/life_lines

// ===== AFFINITY =====

/// The key a pair of prisoners is kept under, the same whichever way round they come
/datum/outpost_prison/proc/affinity_key(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	var/one_ref = REF(one)
	var/two_ref = REF(two)
	return (sorttext(one_ref, two_ref) > 0) ? "[one_ref]|[two_ref]" : "[two_ref]|[one_ref]"

/// How two prisoners get on, -100 (rivals) to 100 (friends)
/datum/outpost_prison/proc/affinity(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	if(!one || !two || one == two)
		return 0
	return affinities[affinity_key(one, two)] || 0

/// Sets how two prisoners get on. A wing keeps at most PRISON_AFFINITY_MAX_PAIRS pairs: a new one pushes out the mildest.
/datum/outpost_prison/proc/set_affinity(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two, value)
	if(!one || !two || one == two)
		return 0
	var/key = affinity_key(one, two)
	value = clamp(round(value, 0.1), PRISON_AFFINITY_MIN, PRISON_AFFINITY_MAX)
	if(!value)
		affinities -= key
		return 0
	if(!(key in affinities) && length(affinities) >= PRISON_AFFINITY_MAX_PAIRS)
		var/mildest
		for(var/other_key in affinities)
			if(isnull(mildest) || abs(affinities[other_key]) < abs(affinities[mildest]))
				mildest = other_key
		affinities -= mildest
		coplay_seconds -= mildest
	affinities[key] = value
	return value

/datum/outpost_prison/proc/adjust_affinity(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two, amount)
	return set_affinity(one, two, affinity(one, two) + amount)

/datum/outpost_prison/proc/are_friends(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	return affinity(one, two) >= PRISON_AFFINITY_FRIEND

/datum/outpost_prison/proc/are_rivals(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	return affinity(one, two) <= PRISON_AFFINITY_RIVAL

/// The prisoner `prisoner` gets on with best, if a friend; with `worst`, the one they get on with worst, if a rival
/datum/outpost_prison/proc/closest_tie(mob/living/basic/outpost_prisoner/prisoner, worst = FALSE)
	var/mob/living/basic/outpost_prisoner/found
	var/found_value = worst ? PRISON_AFFINITY_RIVAL : PRISON_AFFINITY_FRIEND
	for(var/mob/living/basic/outpost_prisoner/other in prisoners)
		if(other == prisoner || other.stat == DEAD || other.phase == PRISONER_LEAVING)
			continue
		var/value = affinity(prisoner, other)
		var/qualifies = worst ? value <= found_value : value >= found_value
		var/better = worst ? value < found_value : value > found_value
		if(qualifies && (!found || better))
			found = other
			found_value = value
	return found

/// Picks, removes from `options` and returns the prisoner `prisoner` goes to chat with, friends by preference
/datum/outpost_prison/proc/take_chat_partner(mob/living/basic/outpost_prisoner/prisoner, list/options)
	if(!length(options))
		return null
	var/list/weights = list()
	var/total = 0
	for(var/mob/living/basic/outpost_prisoner/other as anything in options)
		var/weight = clamp(1 + affinity(prisoner, other) / 25, PRISON_CHAT_WEIGHT_MIN, PRISON_CHAT_WEIGHT_MAX)
		weights += weight
		total += weight
	var/roll = rand() * total
	for(var/index in 1 to length(options))
		roll -= weights[index]
		if(roll <= 0)
			var/mob/living/basic/outpost_prisoner/chosen = options[index]
			options.Cut(index, index + 1)
			return chosen
	return pick_n_take(options)

// ===== WHAT CHANGES IT =====

/// A chat between two prisoners finished
/datum/outpost_prison/proc/note_chat(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	adjust_affinity(one, two, PRISON_AFFINITY_CHAT)

/// Prisoners who shared a meal and got its lift: every pair of them
/datum/outpost_prison/proc/note_shared_meal(list/diners)
	for(var/first_index in 1 to length(diners) - 1)
		for(var/second_index in first_index + 1 to length(diners))
			adjust_affinity(diners[first_index], diners[second_index], PRISON_AFFINITY_SHARED_MEAL)

/datum/outpost_prison/proc/note_spat(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	adjust_affinity(one, two, PRISON_AFFINITY_SPAT)

/datum/outpost_prison/proc/note_fight(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	adjust_affinity(one, two, PRISON_AFFINITY_FIGHT)

/// Each full minute two prisoners spend playing basketball together brings them a little closer
/datum/outpost_prison/proc/coplay_tick(seconds)
	var/list/players = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.stat == CONSCIOUS && prisoner.phase == PRISONER_PRESENT && istype(prisoner.activity, /datum/prisoner_activity/basketball) && prisoner.activity.started)
			players += prisoner
	for(var/first_index in 1 to length(players) - 1)
		for(var/second_index in first_index + 1 to length(players))
			var/key = affinity_key(players[first_index], players[second_index])
			var/played = coplay_seconds[key] + seconds
			while(played >= 60)
				played -= 60
				adjust_affinity(players[first_index], players[second_index], PRISON_AFFINITY_BASKETBALL)
			coplay_seconds[key] = played

// ===== WHAT IT CHANGES =====

/// Rivals fight more readily, friends less
/datum/outpost_prison/proc/fight_chance_mult(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	if(are_rivals(one, two))
		return PRISON_FIGHT_MULT_RIVAL
	if(are_friends(one, two))
		return PRISON_FIGHT_MULT_FRIEND
	return 1

/// A fight cause beyond food, ball and bed: an old grudge between two who can't stand each other
/datum/outpost_prison/proc/fight_cause_extra(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	if(affinity(one, two) <= PRISON_AFFINITY_GRUDGE)
		return "grudge"
	return null

/// Which pair of `pairs` (each list(one, two)) has a spat: rivals go at it PRISON_SPAT_RIVAL_WEIGHT times as often
/datum/outpost_prison/proc/pick_spat_pair(list/pairs)
	if(!length(pairs))
		return null
	var/list/weights = list()
	var/total = 0
	for(var/list/pair as anything in pairs)
		var/weight = are_rivals(pair[1], pair[2]) ? PRISON_SPAT_RIVAL_WEIGHT : 1
		weights += weight
		total += weight
	var/roll = rand() * total
	for(var/index in 1 to length(pairs))
		roll -= weights[index]
		if(roll <= 0)
			return pairs[index]
	return pick(pairs)

/**
 * The two-person conversation `speaker` opens with `partner`: friends and rivals mostly open with
 * one of their own (conversations_friendly, conversations_hostile), falling back to the main pool.
 */
/datum/outpost_prison/proc/pick_conversation(mob/living/basic/outpost_prisoner/speaker, mob/living/basic/outpost_prisoner/partner)
	var/value = affinity(speaker, partner)
	var/pool_key
	if(value >= PRISON_AFFINITY_FRIEND)
		pool_key = "conversations_friendly"
	else if(value <= PRISON_AFFINITY_RIVAL)
		pool_key = "conversations_hostile"
	if(!pool_key || !prob(PRISON_TIE_CONVERSATION_CHANCE))
		return null
	var/list/pool = list()
	for(var/list/conversation in outpost_prisoner_extra_dialogue("outpost_prison_life.json", pool_key))
		if(istext(conversation["opener"]) && length(conversation["replies"]))
			pool += list(conversation)
	return length(pool) ? pick(pool) : null

/// "Seems to get on with Rosa." for examine, or null
/datum/outpost_prison/proc/relationship_examine(mob/living/basic/outpost_prisoner/prisoner)
	var/mob/living/basic/outpost_prisoner/friend = closest_tie(prisoner)
	var/mob/living/basic/outpost_prisoner/rival = closest_tie(prisoner, worst = TRUE)
	if(friend && rival)
		return "Seems to get on with [friend.speech_name()], and keeps away from [rival.speech_name()]."
	if(friend)
		return "Seems to get on with [friend.speech_name()]."
	if(rival)
		return "Keeps away from [rival.speech_name()]."
	return null

/// The first name of `prisoner`'s worst rival in the wing, or null
/datum/outpost_prison/proc/worst_rival_name(mob/living/basic/outpost_prisoner/prisoner)
	var/mob/living/basic/outpost_prisoner/rival = closest_tie(prisoner, worst = TRUE)
	return rival?.speech_name()

// ===== A FRIEND BREAKS IT UP =====

/**
 * While two prisoners are still arguing, a friend of either close by, in a good enough mood and
 * awake, has one PRISON_BREAKUP_CHANCE percent try at talking them out of it. Returns the friend
 * who ended one, or null.
 */
/datum/outpost_prison/proc/breakup_tick()
	for(var/datum/outpost_prison_fight/brawl in fights.Copy())
		if(brawl.fighting || brawl.breakup_tried)
			continue
		for(var/mob/living/basic/outpost_prisoner/fighter as anything in list(brawl.first, brawl.second))
			var/mob/living/basic/outpost_prisoner/friend = peacemaker_for(fighter, brawl)
			if(!friend)
				continue
			brawl.breakup_tried = TRUE
			var/chance = isnull(breakup_chance_override) ? PRISON_BREAKUP_CHANCE : breakup_chance_override
			if(!prob(chance))
				break
			var/mob/living/basic/outpost_prisoner/opponent = brawl.opponent_of(fighter)
			friend.face_atom(fighter)
			friend.manual_emote(opponent ? "steps in between [fighter] and [opponent]." : "puts a hand on [fighter]'s shoulder.")
			end_fight(brawl)
			add_log("[friend.real_name] talked [fighter.real_name] and [opponent?.real_name] out of a fight.")
			INVOKE_ASYNC(friend, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), "friend_breaks_up", fighter)
			return friend
	return null

/// A friend of `fighter` who could step in: close by, awake, in a good enough mood and out of trouble
/datum/outpost_prison/proc/peacemaker_for(mob/living/basic/outpost_prisoner/fighter, datum/outpost_prison_fight/brawl)
	if(QDELETED(fighter))
		return null
	for(var/mob/living/basic/outpost_prisoner/other in prisoners)
		if(other == brawl.first || other == brawl.second || !are_friends(fighter, other))
			continue
		// Down or cuffed, they can't step in between anyone
		if(other.stat != CONSCIOUS || other.phase != PRISONER_PRESENT || other.in_trouble() || other.can_be_dragged() || !other.ai_running() || other.mood < PRISON_BREAKUP_MOOD)
			continue
		if(get_dist(other, fighter) <= PRISON_BREAKUP_RANGE)
			return other
	return null

// ===== ARRIVALS =====

/// A prisoner was booked in. Whether they know anyone inside, and their birthday, wait until they beam in.
/datum/outpost_prison/proc/on_prisoner_admitted(mob/living/basic/outpost_prisoner/prisoner)
	// admit_next() beams them in straight after admit(); anyone booked in any other way stays put.
	addtimer(CALLBACK(src, PROC_REF(greet_arrival), WEAKREF(prisoner)), 1)

/// An arrival beaming in through intake: a crewmate or a rival already inside, a birthday, marks on the wall
/datum/outpost_prison/proc/greet_arrival(datum/weakref/prisoner_ref)
	var/mob/living/basic/outpost_prisoner/prisoner = prisoner_ref?.resolve()
	if(!prisoner || prisoner.prison != src || prisoner.phase != PRISONER_ARRIVING)
		return FALSE
	roll_crew_tie(prisoner)
	if(roll_birthday())
		give_birthday(prisoner)
	if(prisoner.cell && cell_has_marks(prisoner.cell) && prob(PRISON_CELL_MARKS_LINE_CHANCE))
		queue_life_line(prisoner, "cell_marks", null, OUTPOST_PRISON_BEAM_TIME / (1 SECONDS) + PRISON_CELL_MARKS_LINE_DELAY)
	return TRUE

/**
 * Whether an arrival crewed with someone already inside (+PRISON_CREW_TIE) or fell out with them
 * (-PRISON_CREW_TIE). `forced` is "friend" or "rival" to skip the roll. The arrival says so once
 * they have beamed in. Returns the other prisoner, or null.
 */
/datum/outpost_prison/proc/roll_crew_tie(mob/living/basic/outpost_prisoner/prisoner, forced)
	var/list/others = list()
	for(var/mob/living/basic/outpost_prisoner/other in prisoners)
		if(other != prisoner && other.phase == PRISONER_PRESENT && other.stat != DEAD && other.trouble != PRISONER_TROUBLE_LOOSE)
			others += other
	if(!length(others))
		return null
	var/tie = forced
	if(isnull(tie))
		if(prob(PRISON_CREW_FRIEND_CHANCE))
			tie = "friend"
		else if(prob(PRISON_CREW_RIVAL_CHANCE))
			tie = "rival"
	if(tie != "friend" && tie != "rival")
		return null
	var/mob/living/basic/outpost_prisoner/other = pick(others)
	set_affinity(prisoner, other, tie == "friend" ? PRISON_CREW_TIE : -PRISON_CREW_TIE)
	var/delay = (prisoner.phase == PRISONER_ARRIVING ? OUTPOST_PRISON_BEAM_TIME / (1 SECONDS) : 0) + PRISON_CREW_LINE_DELAY
	queue_life_line(prisoner, tie == "friend" ? "arrival_crew_friend" : "arrival_crew_rival", other, delay)
	return other

/// Whether an arrival has a birthday today
/datum/outpost_prison/proc/roll_birthday()
	return prob(PRISON_BIRTHDAY_CHANCE)

/// It is their birthday: they say so once they are in, and the yard can throw them a party (outpost_prison_pastimes.dm)
/datum/outpost_prison/proc/give_birthday(mob/living/basic/outpost_prisoner/prisoner)
	prisoner.has_birthday = TRUE
	prisoner.party_done = FALSE
	var/delay = (prisoner.phase == PRISONER_ARRIVING ? OUTPOST_PRISON_BEAM_TIME / (1 SECONDS) : 0) + PRISON_BIRTHDAY_LINE_DELAY
	queue_life_line(prisoner, "birthday_arrival", null, delay)

// ===== LINES DUE =====

/// Queues a line for `prisoner` to say to `other` in `seconds`
/datum/outpost_prison/proc/queue_life_line(mob/living/basic/outpost_prisoner/prisoner, context, mob/living/basic/outpost_prisoner/other, seconds)
	LAZYADD(prisoner.life_lines, list(list(seconds, context, other ? WEAKREF(other) : null)))

/// Counts down queued lines and says the ones that are due, once the speaker has beamed in
/datum/outpost_prison/proc/life_lines_tick(seconds)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(!length(prisoner.life_lines))
			continue
		for(var/list/entry as anything in prisoner.life_lines.Copy())
			entry[1] -= seconds
			if(entry[1] > 0 || prisoner.phase == PRISONER_ARRIVING)
				continue
			LAZYREMOVE(prisoner.life_lines, list(entry))
			if(prisoner.phase != PRISONER_PRESENT || prisoner.stat != CONSCIOUS)
				continue
			var/datum/weakref/other_ref = entry[3]
			var/mob/living/basic/outpost_prisoner/other = other_ref?.resolve()
			if(other && other.stat == CONSCIOUS && (other in view(7, prisoner)))
				prisoner.face_atom(other)
			else
				other = null
			prisoner.say_context(entry[2], other)

/// Says a line for a prisoner who may have gone by now; for timers
/datum/outpost_prison/proc/say_life_line(datum/weakref/speaker_ref, context, datum/weakref/other_ref)
	var/mob/living/basic/outpost_prisoner/speaker = speaker_ref?.resolve()
	if(!speaker || speaker.stat != CONSCIOUS)
		return FALSE
	var/mob/living/basic/outpost_prisoner/other = other_ref?.resolve()
	if(other)
		speaker.face_atom(other)
	return speaker.say_context(context, other)

// ===== LEAVING =====

/// A prisoner is leaving the roster: their pairs go, and a party for them is off
/datum/outpost_prison/proc/on_prisoner_leaving(mob/living/basic/outpost_prisoner/prisoner)
	var/prisoner_ref = REF(prisoner)
	for(var/key in affinities.Copy())
		if(findtext(key, prisoner_ref))
			affinities -= key
	for(var/key in coplay_seconds.Copy())
		if(findtext(key, prisoner_ref))
			coplay_seconds -= key
	prisoner.life_lines = null
	if(party_host_ref?.resolve() == prisoner)
		end_party()

/**
 * A prisoner is being released after a stay that averaged `average` care x conditions. A stay kept
 * well ends with a wave at the nearest member and thanks; a poor one with a bitter word. Friends in
 * sight say goodbye, a second or so apart, and feel it; the leaver answers the first before the beam
 * takes them. Returns TRUE if any of that replaced the usual release line.
 */
/datum/outpost_prison/proc/on_prisoner_releasing(mob/living/basic/outpost_prisoner/prisoner, average)
	var/spoke = FALSE
	if(average >= PRISON_RELEASE_THANKS_AVERAGE)
		var/mob/living/member = nearest_member_in_view(prisoner)
		if(member)
			prisoner.face_atom(member)
			prisoner.manual_emote("waves at [member].")
			spoke = prisoner.say_to_staff("release_thanks", member)
		else
			spoke = prisoner.say_context("release_thanks")
	else if(average <= PRISON_RELEASE_BITTER_AVERAGE)
		spoke = prisoner.say_context("release_bitter")
	var/list/friends = list()
	for(var/mob/living/basic/outpost_prisoner/other in view(PRISON_FAREWELL_RANGE, prisoner))
		if(other == prisoner || !(other in prisoners) || other.stat != CONSCIOUS || other.phase != PRISONER_PRESENT)
			continue
		if(are_friends(prisoner, other))
			friends += other
	if(!length(friends))
		return spoke
	// The first goodbye and the leaver's answer come before the beam starts, since nobody talks while
	// beaming out; later friends call after them anyway, a second or two apart.
	var/delay = 0
	for(var/mob/living/basic/outpost_prisoner/friend as anything in friends)
		friend.adjust_mood(-PRISON_FAREWELL_MOOD)
		friend.face_atom(prisoner)
		if(friend == friends[1])
			say_life_line(WEAKREF(friend), "farewell", WEAKREF(prisoner))
			say_life_line(WEAKREF(prisoner), "farewell_reply", WEAKREF(friend))
		else
			addtimer(CALLBACK(src, PROC_REF(say_life_line), WEAKREF(friend), "farewell", WEAKREF(prisoner)), delay)
		delay += rand(10, 20)
	return TRUE

/// The nearest member of the wing awake in sight of `prisoner`, or null
/datum/outpost_prison/proc/nearest_member_in_view(mob/living/basic/outpost_prisoner/prisoner)
	var/mob/living/nearest
	var/nearest_distance = INFINITY
	for(var/mob/living/person in view(7, prisoner))
		if(person.stat != CONSCIOUS || is_outpost_prisoner(person) || !is_member(person))
			continue
		var/distance = get_dist(prisoner, person)
		if(distance < nearest_distance)
			nearest = person
			nearest_distance = distance
	return nearest

// ===== THE SCENE GATE =====

/// Whether a set piece (a birthday party) has the floor, so idle chatter waits
/datum/outpost_prison/proc/scene_active()
	return !!party_stage && party_stage != "waiting"

// ===== TIME =====

/// Queued lines, basketball friendships, friends breaking up arguments and birthday chatter
/datum/outpost_prison/proc/life_tick(seconds)
	life_lines_tick(seconds)
	coplay_tick(seconds)
	if(trouble_enabled)
		breakup_tick()
	birthday_chatter()

/// A birthday prisoner free to talk brings it up now and then, until they get their party
/datum/outpost_prison/proc/birthday_chatter()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(!prisoner.has_birthday || prisoner.party_done || prisoner.stat != CONSCIOUS || prisoner.phase != PRISONER_PRESENT)
			continue
		if(!prisoner.ai_running() || prisoner.in_trouble() || prisoner.activity?.sleeping)
			continue
		if(!COOLDOWN_FINISHED(prisoner, speech_cooldown) || !wing_can_speak() || !prob(PRISON_BIRTHDAY_IDLE_CHANCE))
			continue
		if(prisoner.say_context("birthday"))
			COOLDOWN_START(prisoner, speech_cooldown, rand(35, 80) SECONDS * prisoner.speech_pace())
			note_speech()

/// The prison is being deleted: everything both life files hold
/datum/outpost_prison/proc/life_destroy()
	affinities.Cut()
	coplay_seconds.Cut()
	clear_pastimes()

// ===== ADMIN =====

/// The admin panel's life block: {pairs, birthdays, scene}
/datum/outpost_prison/proc/life_admin_payload()
	var/list/pairs = list()
	for(var/key in affinities)
		var/list/refs = splittext(key, "|")
		if(length(refs) != 2)
			continue
		var/mob/living/basic/outpost_prisoner/one = locate(refs[1]) in prisoners
		var/mob/living/basic/outpost_prisoner/two = locate(refs[2]) in prisoners
		if(!one || !two)
			continue
		pairs += list(list(
			"a_ref" = REF(one),
			"b_ref" = REF(two),
			"a_name" = one.real_name,
			"b_name" = two.real_name,
			"affinity" = round(affinities[key]),
		))
	var/list/birthdays = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.has_birthday && !prisoner.party_done)
			birthdays += REF(prisoner)
	var/scene
	var/mob/living/basic/outpost_prisoner/host = party_host_ref?.resolve()
	if(party_stage && host)
		scene = party_stage == "waiting" ? "cake waiting for [host.real_name]" : "birthday party for [host.real_name]"
	return list(
		"pairs" = pairs,
		"birthdays" = birthdays,
		"scene" = scene,
	)

/// prison_affinity, prison_birthday, prison_party, prison_cards: a log line, list("error" = text), or null
/datum/outpost_prison/proc/life_admin_act(action, list/params, mob/user)
	switch(action)
		if("prison_affinity")
			var/mob/living/basic/outpost_prisoner/one = locate(params?["a_ref"]) in prisoners
			var/mob/living/basic/outpost_prisoner/two = locate(params?["b_ref"]) in prisoners
			if(QDELETED(one) || QDELETED(two) || one == two)
				return list("error" = "Pick two different prisoners.")
			var/value = params["value"]
			if(istext(value))
				value = text2num(value)
			if(!isnum(value) || value != value || value < PRISON_AFFINITY_MIN || value > PRISON_AFFINITY_MAX)
				return list("error" = "Affinity is [PRISON_AFFINITY_MIN] to [PRISON_AFFINITY_MAX].")
			set_affinity(one, two, value)
			return "set how [one.real_name] and [two.real_name] get on to [round(affinity(one, two))]"
		if("prison_birthday", "prison_party")
			var/mob/living/basic/outpost_prisoner/prisoner = locate(params?["ref"]) in prisoners
			if(QDELETED(prisoner) || prisoner.stat == DEAD || prisoner.phase != PRISONER_PRESENT)
				return list("error" = "Only a living prisoner in the wing.")
			if(action == "prison_birthday")
				give_birthday(prisoner)
				return "give prisoner [prisoner.real_name] a birthday"
			if(party_stage)
				return list("error" = "A party is already on.")
			prisoner.has_birthday = TRUE
			prisoner.party_done = FALSE
			var/obj/item/food/cake/birthday/cake = new(get_turf(prisoner))
			if(!start_party(prisoner, cake, null))
				qdel(cake)
				return list("error" = "The party did not start.")
			// Fetched as soon as they are free; with nobody on the level it waits for someone to come.
			try_start_party_host()
			return "start a birthday party for prisoner [prisoner.real_name]"
		if("prison_cards")
			var/result = admin_start_cards()
			if(!istext(result))
				return list("error" = "No card game: it takes a deck on a mess table and two prisoners free to play.")
			return result
	return null
