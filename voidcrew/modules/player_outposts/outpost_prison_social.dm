/**
 * # Prison social memory: the yard remembers staff
 *
 * Owner: XC (extras-plan.md 4.3). The wing keeps a hidden score for each member who deals with
 * it, moved by care, talk, games and kindness up, and by unprovoked blows down. It shows only in
 * how prisoners greet, threaten, listen to and riot against that person. Numbers in
 * voidcrew/_DEFINES/outpost_prison_social.dm.
 *
 * The score belongs to the wing, not to a prisoner: sentences are short, so new arrivals "hear
 * about you". A record is keyed by the member's mind and keeps only text and numbers. Members
 * only (is_member()); visitors never get one, and nobody's score moves for someone else's blows.
 * A masked member (visible name "Unknown") is a stranger to the prisoners whatever their record,
 * though what they do behind the mask still counts against them.
 *
 * Labels (staff_label()): "stranger" (no record, or too little to go on), "regular", "fair",
 * "hard" and "brute". What they change:
 * - who gets threatened (threat_mood_for()): a fair member only by the unhappiest, a brute sooner;
 * - how well a talk-down works (talk_mood_for()), and a brute gets turned away (refuses_talk_from());
 * - whom rioters go for (riot_victim_distance()): a brute seems nearer, a fair member farther;
 * - the talk menu's "Back to your cell" (outpost_prison_warden_tools.dm);
 * - greetings (social_extra_speech()) and what arrivals say they heard (social_tick()).
 * Mood and pay never move with it.
 */

// ===== THE RECORD =====

/// What the wing remembers about one member: text and numbers only, never an atom
/datum/prison_staff_record
	/// REF() of the member's mind
	var/key
	/// Their visible name when last seen with a face or an ID; null until then
	var/name
	/// Their real name, for the admin panel only
	var/real_name
	/// PRISON_REP_MIN to PRISON_REP_MAX
	var/score = 0
	/// Events the wing has counted for them
	var/interactions = 0
	/// world.time they were last seen or heard of
	var/last_seen = 0
	/// REF(prisoner) -> world.time of the last hand-over that counted
	var/list/care_times
	/// world.time the last hatch stocking counted, or null
	var/stocked_at

/datum/prison_staff_record/New(record_key)
	. = ..()
	key = record_key
	last_seen = world.time

/// "stranger", "regular", "fair", "hard" or "brute", from the score alone
/datum/prison_staff_record/proc/label()
	if(interactions < PRISON_REP_KNOWN_INTERACTIONS && abs(score) < PRISON_REP_KNOWN_SCORE)
		return "stranger"
	if(score >= PRISON_REP_FAIR)
		return "fair"
	if(score >= 0)
		return "regular"
	if(score > PRISON_REP_BRUTE)
		return "hard"
	return "brute"

/// Something they did moved the score by `amount` (0 still counts as dealing with the wing)
/datum/prison_staff_record/proc/adjust(amount)
	set_score(score + amount)

/// Puts the score at `value`, as one more thing the wing remembers
/datum/prison_staff_record/proc/set_score(value)
	score = clamp(value, PRISON_REP_MIN, PRISON_REP_MAX)
	interactions++
	last_seen = world.time

/// The yard saw `person`: when, and the name it knows them by
/datum/prison_staff_record/proc/saw(mob/person)
	last_seen = world.time
	real_name = person.real_name
	var/visible = person.get_visible_name()
	if(istext(visible) && length(visible) && visible != "Unknown")
		name = visible

/// Time heals: the score moves `amount` toward 0, and hand-overs older than their limit are forgotten
/datum/prison_staff_record/proc/decay(amount)
	if(score > 0)
		score = max(0, score - amount)
	else if(score < 0)
		score = min(0, score + amount)
	for(var/prisoner_key in care_times?.Copy())
		if(world.time - care_times[prisoner_key] >= PRISON_REP_CARE_GAP)
			LAZYREMOVE(care_times, prisoner_key)

/// A name for the admin panel
/datum/prison_staff_record/proc/display_name()
	return name || real_name || "someone"

// ===== THE WING'S MEMORY =====

/datum/outpost_prison
	/// REF(mind) -> /datum/prison_staff_record, oldest first
	var/list/staff_records = list()
	/// Seconds toward the next decay step
	var/rep_decay_clock = 0
	/// Percent chances for a greeting and for word on arrival; tests pin them
	var/rep_greet_chance = PRISON_REP_GREET_CHANCE
	var/rep_word_chance = PRISON_REP_WORD_CHANCE

/mob/living/basic/outpost_prisoner
	/// Record key -> world.time they last greeted that person
	var/list/rep_greeted
	/// Record keys already thanked for bringing them mail this stay
	var/list/rep_mail_keys
	/// Whether the wing's memory has seen them arrive yet
	var/rep_noticed = FALSE
	/// Seconds until they say what they heard about staff (null: they won't), and seconds left to find a quiet moment
	var/rep_word_left
	var/rep_word_wait = 0

/// The key of `person`'s record: their mind, so it follows them into a new body
/datum/outpost_prison/proc/rep_key(mob/person)
	if(!ismob(person) || !person.mind)
		return null
	return REF(person.mind)

/// The record under `key`, made when `create` is set and there is none
/datum/outpost_prison/proc/rep_record(key, create = FALSE)
	if(!istext(key))
		return null
	var/datum/prison_staff_record/record = staff_records[key]
	if(record || !create)
		return record
	record = new(key)
	staff_records[key] = record
	rep_trim(key)
	return record

/// A member's record, noting that the yard saw them. Visitors and prisoners have none.
/datum/outpost_prison/proc/rep_record_for(mob/person, create = FALSE)
	if(!is_member(person))
		return null
	var/datum/prison_staff_record/record = rep_record(rep_key(person), create)
	record?.saw(person)
	return record

/// Forgets the least recently seen members past PRISON_REP_RECORDS, never `keep`
/datum/outpost_prison/proc/rep_trim(keep)
	while(length(staff_records) > PRISON_REP_RECORDS)
		var/oldest_key
		var/oldest_seen = INFINITY
		for(var/key in staff_records)
			if(key == keep)
				continue
			var/datum/prison_staff_record/record = staff_records[key]
			if(record.last_seen < oldest_seen)
				oldest_seen = record.last_seen
				oldest_key = key
		if(!oldest_key)
			return
		var/datum/prison_staff_record/dropped = staff_records[oldest_key]
		staff_records -= oldest_key
		qdel(dropped)

/// Moves a member's score by `amount`. FALSE for anyone who is not a member.
/datum/outpost_prison/proc/rep_adjust(mob/person, amount)
	var/datum/prison_staff_record/record = rep_record_for(person, TRUE)
	if(!record)
		return FALSE
	record.adjust(amount)
	return TRUE

/// The people behind a blow: the attacker, or whoever drives the mech that struck
/datum/outpost_prison/proc/rep_people_behind(atom/attacker)
	if(ismob(attacker))
		return list(attacker)
	var/list/people = list()
	if(ismecha(attacker))
		var/obj/vehicle/sealed/mecha/mech = attacker
		for(var/mob/driver in mech.return_drivers())
			people += driver
	return people

// ===== LABELS =====

/// "stranger", "regular", "fair", "hard" or "brute": how the yard sees `person`
/datum/outpost_prison/proc/staff_label(mob/person)
	// A face the yard can't see is a stranger's, whoever is behind it.
	if(!staff_greeting_name(person))
		return "stranger"
	var/datum/prison_staff_record/record = rep_record_for(person)
	return record ? record.label() : "stranger"

/// The name prisoners call `person` by: the first name of their visible name, or null when masked
/datum/outpost_prison/proc/staff_greeting_name(mob/person)
	if(!ismob(person))
		return null
	var/visible = person.get_visible_name()
	if(!istext(visible) || !length(visible) || visible == "Unknown")
		return null
	return first_name(visible)

// ===== WHAT MOVES IT =====
// note_staff_care() and note_staff_hit() run inside signal handlers: nothing here may sleep.

/// `person` fed, clothed or treated `prisoner` by hand: once per prisoner per PRISON_REP_CARE_GAP
/datum/outpost_prison/proc/note_staff_care(mob/person, mob/living/basic/outpost_prisoner/prisoner)
	if(!prisoner || !ismob(person))
		return FALSE
	// note_carer() runs as a dressing is offered, so a dressing held to someone unhurt is not care.
	if(prisoner.health >= prisoner.maxHealth && istype(person.get_active_held_item(), /obj/item/stack/medical))
		return FALSE
	var/datum/prison_staff_record/record = rep_record_for(person, TRUE)
	if(!record)
		return FALSE
	var/prisoner_key = REF(prisoner)
	var/last = LAZYACCESS(record.care_times, prisoner_key)
	if(!isnull(last) && world.time - last < PRISON_REP_CARE_GAP)
		return FALSE
	LAZYSET(record.care_times, prisoner_key, world.time)
	record.adjust(PRISON_REP_CARE)
	return TRUE

/// `person` stocked a serving hatch with food or clean uniforms: once per PRISON_REP_STOCK_GAP
/datum/outpost_prison/proc/note_staff_stock(mob/person)
	var/datum/prison_staff_record/record = rep_record_for(person, TRUE)
	if(!record)
		return FALSE
	if(!isnull(record.stocked_at) && world.time - record.stocked_at < PRISON_REP_STOCK_GAP)
		return FALSE
	record.stocked_at = world.time
	record.adjust(PRISON_REP_STOCK)
	return TRUE

/// `person` talked `prisoner` down
/datum/outpost_prison/proc/note_staff_talk(mob/person, mob/living/basic/outpost_prisoner/prisoner)
	return rep_adjust(person, PRISON_REP_TALK)

/// `person` sank a shot while prisoners played
/datum/outpost_prison/proc/note_staff_basket(mob/person)
	return rep_adjust(person, PRISON_REP_BASKET)

/// A kindness another package noticed (a card game, a birthday cake): `amount` of score, at most PRISON_REP_KINDNESS_MAX
/datum/outpost_prison/proc/note_staff_kindness(mob/person, amount)
	if(!isnum(amount) || !(amount > 0))
		return FALSE
	return rep_adjust(person, min(amount, PRISON_REP_KINDNESS_MAX))

/// An unprovoked hit on `prisoner` that cost them mood (hit_by_staff() has already ruled out deserved ones)
/datum/outpost_prison/proc/note_staff_hit(atom/attacker, mob/living/basic/outpost_prisoner/prisoner)
	var/counted = FALSE
	for(var/mob/person in rep_people_behind(attacker))
		if(rep_adjust(person, PRISON_REP_HIT))
			counted = TRUE
	return counted

/**
 * Staff got the blame for `prisoner`: `event` is "beaten" (an unprovoked beating down, on top of
 * the hits) or "killed" (the score goes to PRISON_REP_MIN). The blame goes to whoever last hit them.
 */
/datum/outpost_prison/proc/note_staff_blamed(mob/living/basic/outpost_prisoner/prisoner, event)
	if(event != "beaten" && event != "killed")
		return FALSE
	var/atom/attacker = prisoner?.last_staff_attacker_ref?.resolve()
	if(!attacker)
		return FALSE
	var/counted = FALSE
	for(var/mob/person in rep_people_behind(attacker))
		var/datum/prison_staff_record/record = rep_record_for(person, TRUE)
		if(!record)
			continue
		if(event == "killed")
			record.set_score(PRISON_REP_MIN)
		else
			record.adjust(PRISON_REP_BEATEN)
		counted = TRUE
	return counted

/**
 * Something else `person` did that the yard remembers, from XF and XG: "mail_delivered" (once per
 * prisoner per stay), "mail_opened", "search_found", "search_empty", "patdown_found",
 * "patdown_empty". Events it does not know, and anyone who is not a member, are ignored.
 */
/datum/outpost_prison/proc/note_staff_event(mob/person, mob/living/basic/outpost_prisoner/prisoner, event)
	var/amount
	switch(event)
		if("mail_delivered")
			amount = PRISON_REP_MAIL_DELIVERED
		if("mail_opened")
			amount = PRISON_REP_MAIL_OPENED
		if("search_found")
			amount = PRISON_REP_SEARCH_FOUND
		if("search_empty")
			amount = PRISON_REP_SEARCH_EMPTY
		if("patdown_found")
			amount = PRISON_REP_PATDOWN_FOUND
		if("patdown_empty")
			amount = PRISON_REP_PATDOWN_EMPTY
		else
			return FALSE
	var/datum/prison_staff_record/record = rep_record_for(person, TRUE)
	if(!record)
		return FALSE
	if(event == "mail_delivered")
		if(!istype(prisoner) || (record.key in prisoner.rep_mail_keys))
			return FALSE
		LAZYADD(prisoner.rep_mail_keys, record.key)
	record.adjust(amount)
	return TRUE

// ===== WHAT IT DOES =====

/// Below this mood `prisoner` squares up to `person`: lower for a fair member, higher for a brute, and higher for some bounty prisoners (outpost_prison_bounty.dm)
/datum/outpost_prison/proc/threat_mood_for(mob/living/basic/outpost_prisoner/prisoner, mob/person)
	. = PRISONER_THREAT_MOOD
	switch(staff_label(person))
		if("fair")
			. = PRISON_REP_THREAT_FAIR
		if("brute")
			. = PRISON_REP_THREAT_BRUTE
	. += prisoner ? prisoner.bounty_threat_bonus() : 0

/// The highest line threat_mood_for() can return (for `prisoner`, when given), so a prisoner above it looks for nobody
/datum/outpost_prison/proc/threat_mood_ceiling(mob/living/basic/outpost_prisoner/prisoner)
	return max(PRISONER_THREAT_MOOD, PRISON_REP_THREAT_BRUTE) + (prisoner ? prisoner.bounty_threat_bonus() : 0)

/// The mood a talk-down from `person` gives `prisoner`
/datum/outpost_prison/proc/talk_mood_for(mob/living/basic/outpost_prisoner/prisoner, mob/person)
	return staff_label(person) == "fair" ? PRISON_REP_TALK_MOOD_FAIR : PRISONER_MOOD_TALK

/// Whether `prisoner` refuses to be talked down by `person`: a brute, below PRISON_REP_REFUSE_BRUTE_BELOW. It says so itself (async).
/datum/outpost_prison/proc/refuses_talk_from(mob/living/basic/outpost_prisoner/prisoner, mob/person)
	if(!prisoner || prisoner.mood >= PRISON_REP_REFUSE_BRUTE_BELOW || staff_label(person) != "brute")
		return FALSE
	prisoner.balloon_alert(person, "not listening")
	INVOKE_ASYNC(prisoner, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, turn_away_brute), person)
	return TRUE

/// Won't hear a word from a brute
/mob/living/basic/outpost_prisoner/proc/turn_away_brute(mob/person)
	if(!QDELETED(person))
		face_atom(person)
	say_to_staff("talk_refuse_brute", person)

/// How far `person` seems to a rioter picking whom to go for: a brute nearer, a fair member farther
/datum/outpost_prison/proc/riot_victim_distance(mob/living/basic/outpost_prisoner/prisoner, mob/person, distance)
	switch(staff_label(person))
		if("brute")
			return distance - PRISON_REP_RIOT_BRUTE_NEARER
		if("fair")
			return distance + PRISON_REP_RIOT_FAIR_FARTHER
	return distance

// ===== GREETINGS AND WORD ON ARRIVAL =====

/**
 * A greeting `prisoner` wants to say now, as list(context, other, values), or null. Asked only when
 * they are about to speak anyway: PRISON_REP_GREET_CHANCE of the time, someone within
 * PRISON_REP_GREET_RANGE tiles in view gets greet_<label>, with {staff} filled, once per person
 * per PRISON_REP_GREET_GAP. Visitors let in are strangers; a masked face gets greet_masked.
 */
/datum/outpost_prison/proc/social_extra_speech(mob/living/basic/outpost_prisoner/prisoner)
	if(!prisoner || prisoner.stat != CONSCIOUS || prisoner.phase != PRISONER_PRESENT || prisoner.in_trouble())
		return null
	if(!prob(rep_greet_chance))
		return null
	var/list/greetable = list()
	for(var/mob/living/person in view(PRISON_REP_GREET_RANGE, prisoner))
		// The wing's own guards have their own lines (outpost_prison_guards.dm).
		if(!is_outpost_prison_staff(person) || is_outpost_prison_guard(person))
			continue
		var/key = rep_key(person)
		if(!key)
			continue
		var/greeted_at = LAZYACCESS(prisoner.rep_greeted, key)
		if(!isnull(greeted_at) && world.time - greeted_at < PRISON_REP_GREET_GAP)
			continue
		greetable += person
	if(!length(greetable))
		return null
	var/mob/living/person = pick(greetable)
	LAZYSET(prisoner.rep_greeted, rep_key(person), world.time)
	var/staff_name = staff_greeting_name(person)
	if(!staff_name)
		return list("greet_masked", null)
	return list("greet_[staff_label(person)]", null, list("{staff}" = staff_name))

/**
 * Advances the wing's memory by `seconds`: every PRISON_REP_DECAY_SECONDS each score moves toward 0,
 * and each arrival, PRISON_REP_WORD_CHANCE of the time, says what they heard about the most notable
 * member at home once they have been in PRISON_REP_WORD_DELAY seconds.
 */
/datum/outpost_prison/proc/social_tick(seconds)
	rep_decay_clock += seconds
	while(rep_decay_clock >= PRISON_REP_DECAY_SECONDS)
		rep_decay_clock -= PRISON_REP_DECAY_SECONDS
		for(var/key in staff_records)
			var/datum/prison_staff_record/record = staff_records[key]
			record.decay(PRISON_REP_DECAY)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		rep_word_tick(prisoner, seconds)

/// One arrival's word on staff: rolled when first seen, said after the delay in a quiet moment, or let go
/datum/outpost_prison/proc/rep_word_tick(mob/living/basic/outpost_prisoner/prisoner, seconds)
	if(!prisoner.rep_noticed)
		prisoner.rep_noticed = TRUE
		if(prisoner.phase != PRISONER_LEAVING && prob(rep_word_chance))
			prisoner.rep_word_left = PRISON_REP_WORD_DELAY
			prisoner.rep_word_wait = PRISON_REP_WORD_WAIT
		return
	if(isnull(prisoner.rep_word_left) || prisoner.phase != PRISONER_PRESENT)
		return
	if(prisoner.rep_word_left > 0)
		prisoner.rep_word_left = max(0, prisoner.rep_word_left - seconds)
		return
	prisoner.rep_word_wait -= seconds
	if(prisoner.rep_word_wait < 0 || prisoner.stat != CONSCIOUS)
		prisoner.rep_word_left = null
		return
	if(!wing_can_speak() || prisoner.in_trouble() || !prisoner.ai_running() || prisoner.activity?.sleeping)
		return
	var/datum/prison_staff_record/notable = rep_notable_home()
	if(!notable)
		return
	// A hushed yard (outpost_prison_ambience.dm) keeps it for a quieter moment.
	if(speech_hushed(prisoner, rep_word_context(notable)))
		return
	prisoner.rep_word_left = null
	if(rep_say_word(prisoner, notable))
		note_speech()

/// The fair or brute member at home (awake on the wing's level) with the score furthest from 0, or null
/datum/outpost_prison/proc/rep_notable_home()
	var/z = wing_z()
	if(!z || z > length(SSmobs.clients_by_zlevel))
		return null
	var/datum/prison_staff_record/best
	for(var/mob/living/person in SSmobs.clients_by_zlevel[z])
		if(QDELETED(person) || person.stat != CONSCIOUS || is_outpost_prisoner(person) || !is_member(person))
			continue
		var/datum/prison_staff_record/record = rep_record(rep_key(person))
		if(!record?.name)
			continue
		var/label = record.label()
		if(label != "fair" && label != "brute")
			continue
		if(!best || abs(record.score) > abs(best.score))
			best = record
	return best

/// What newcomers say about the member behind `record`: "wing_word_fair", "wing_word_brute", or null for anyone else
/datum/outpost_prison/proc/rep_word_context(datum/prison_staff_record/record)
	switch(record?.label())
		if("fair")
			return "wing_word_fair"
		if("brute")
			return "wing_word_brute"
	return null

/// `prisoner` says what they heard about the member behind `record`. Returns TRUE if they said it.
/datum/outpost_prison/proc/rep_say_word(mob/living/basic/outpost_prisoner/prisoner, datum/prison_staff_record/record)
	if(!prisoner || !record?.name)
		return FALSE
	var/context = rep_word_context(record)
	if(!context)
		return FALSE
	var/staff_name = first_name(record.name)
	if(!length(staff_name))
		return FALSE
	return prisoner.say_context_with(context, list("{staff}" = staff_name))

// ===== LIFE AND THE ADMIN PANEL =====

/datum/outpost_prison/proc/social_destroy()
	QDEL_LIST_ASSOC_VAL(staff_records)
	rep_decay_clock = 0

/// The admin panel's records: list of {key, name, score, label}
/datum/outpost_prison/proc/social_admin_payload()
	var/list/rows = list()
	for(var/key in staff_records)
		var/datum/prison_staff_record/record = staff_records[key]
		rows += list(list(
			"key" = key,
			"name" = record.display_name(),
			"score" = round(record.score, 0.1),
			"label" = record.label(),
		))
	return rows

/// prison_rep {key, score}: sets a member's score, -10 to 10. A log line, list("error" = text), or null for other actions.
/datum/outpost_prison/proc/social_admin_act(action, list/params, mob/user)
	if(action != "prison_rep")
		return null
	var/key = params?["key"]
	var/datum/prison_staff_record/record = istext(key) ? staff_records[key] : null
	if(!record)
		return list("error" = "Nobody on record by that key.")
	var/score = params["score"]
	if(istext(score))
		score = text2num(score)
	if(!isnum(score) || score != score || score < PRISON_REP_MIN || score > PRISON_REP_MAX)
		return list("error" = "Reputation is [PRISON_REP_MIN] to [PRISON_REP_MAX].")
	record.score = score
	record.last_seen = world.time
	return "set [record.display_name()]'s prison reputation to [score] ([record.label()])"
