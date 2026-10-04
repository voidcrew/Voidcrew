/**
 * # Prisoner dialogue
 *
 * What prisoners say comes from strings/outpost_prisoners.json:
 *   personalities: the personalities a prisoner can get
 *   crimes: what they can be in for
 *   lines: context -> {"any": [...], "<personality>": [...]}
 *   conversations: [{"opener": "...", "replies": [...]}], two-person exchanges
 * Lines fill {name} (the speaker's first name), {other} (who they talk to), {crime} (the
 * speaker's crime) and {time_left} (the speaker's sentence left). The extras add their own files
 * and placeholders ({staff} and others); see outpost_prison_extras.dm.
 *
 * Spontaneous lines wait out a per-prisoner cooldown (longer for quiet ones) and a short
 * cooldown shared by the whole wing, so a full wing never talks over itself. Replies, thanks,
 * arrivals and releases skip the prisoner's own cooldown.
 *
 * Other files say lines by context name as things happen (a stocked hatch, a fight, a riot, an
 * experiment); voidcrew_outpost_prison_dialogue.dm checks the file has every context they use.
 * Complaints about a dirty or dark wing get likelier as the score falls, and with staff in sight
 * the prisoner points at the mess or the dead light they mean.
 */

#define PRISONER_DIALOGUE_FILE "outpost_prisoners.json"
#define PRISONER_DIALOGUE_DIR "voidcrew/modules/player_outposts/strings"
/// Percent chance of a complaint about a clean or lit score of 0; none at PRISON_WING_MOOD_LINE and above
#define PRISONER_COMPLAINT_MAX_CHANCE 50
/// How far a complaining prisoner looks for the mess or the dead light to point at
#define PRISONER_POINT_RANGE 5

/// One top-level entry of the dialogue file, or an empty list
/proc/outpost_prisoner_dialogue(key)
	var/list/entry = strings(PRISONER_DIALOGUE_FILE, key, PRISONER_DIALOGUE_DIR)
	return islist(entry) ? entry : list()

/// Scales a prisoner's pause between spontaneous lines
/mob/living/basic/outpost_prisoner/proc/speech_pace()
	switch(personality)
		if("chatty")
			return 0.6
		if("cheerful")
			return 0.8
		if("grumpy")
			return 1.1
		if("quiet")
			return 1.8
	return 1

/// Their sentence left in words, for {time_left}
/mob/living/basic/outpost_prisoner/proc/time_left_text()
	var/seconds = max(0, round(sentence_left))
	var/minutes = round(seconds / 60 + 0.5)
	if(minutes >= 2)
		return "[minutes] minutes"
	if(seconds >= 45)
		return "a minute"
	return "[max(seconds, 1)] seconds"

/// Fills a line's placeholders for this speaker, talking to `other`
/mob/living/basic/outpost_prisoner/proc/fill_line(line, mob/living/basic/outpost_prisoner/other)
	line = replacetext(line, "{name}", speech_name())
	line = replacetext(line, "{other}", other ? other.speech_name() : "pal")
	line = replacetext(line, "{crime}", crime)
	line = replacetext(line, "{time_left}", time_left_text())
	// {staff}, {place} and the rest, for one line at a time (outpost_prison_extras.dm)
	for(var/placeholder in extra_line_values)
		line = replacetext(line, placeholder, "[extra_line_values[placeholder]]")
	return line

/**
 * A line for `context`, filled in, or null when the file has none that fits. Personality lines
 * come up more often than the shared ones; lines naming {other} need someone to talk to.
 */
/mob/living/basic/outpost_prisoner/proc/pick_line(context, mob/living/basic/outpost_prisoner/other)
	// The main file first, then the extras' files (outpost_prison_extras.dm)
	var/list/by_personality = outpost_prisoner_context_lines(context)
	if(!islist(by_personality))
		return null
	var/list/own = by_personality[personality]
	var/list/shared = by_personality["any"]
	var/list/first_pool = (length(own) && prob(60)) ? own : shared
	var/list/usable = usable_lines(first_pool, other)
	if(!length(usable))
		usable = usable_lines(first_pool == own ? shared : own, other)
	if(!length(usable))
		return null
	return fill_line(pick(usable), other)

/// The lines of `pool` they can say now: not the last thing they said, naming nobody when alone, and no extra placeholder they have no value for
/mob/living/basic/outpost_prisoner/proc/usable_lines(list/pool, mob/living/basic/outpost_prisoner/other)
	var/list/usable = list()
	for(var/line in pool)
		if(!istext(line) || line == last_line || (!other && findtext(line, "{other}")))
			continue
		if(missing_extra_value(line))
			continue
		usable += line
	return usable

/// Whether `line` names an extra placeholder ({staff}, {place}, ...) that extra_line_values has no value for
/mob/living/basic/outpost_prisoner/proc/missing_extra_value(line)
	for(var/placeholder in GLOB.outpost_prisoner_extra_placeholders)
		if(findtext(line, placeholder) && isnull(LAZYACCESS(extra_line_values, placeholder)))
			return TRUE
	return FALSE

/**
 * Whether they may say anything now: awake and all the way here. Never while beaming in or out,
 * when they are invisible or only half there.
 */
/mob/living/basic/outpost_prisoner/proc/may_speak()
	return !QDELETED(src) && stat == CONSCIOUS && phase == PRISONER_PRESENT

/// Says a line for `context`. Returns TRUE if they said something.
/mob/living/basic/outpost_prisoner/proc/say_context(context, mob/living/basic/outpost_prisoner/other)
	if(!may_speak())
		return FALSE
	var/line = pick_line(context, other)
	if(!line)
		return FALSE
	last_line = line
	say(line)
	return TRUE

/// Thanks whoever fed, clothed or treated them, no more than every 20 seconds
/mob/living/basic/outpost_prisoner/proc/thank(context)
	if(phase != PRISONER_PRESENT || !COOLDOWN_FINISHED(src, thanks_cooldown))
		return FALSE
	if(!say_context(context))
		return FALSE
	COOLDOWN_START(src, thanks_cooldown, 20 SECONDS)
	return TRUE

/**
 * Opens a two-person exchange with `partner`, who answers a few seconds later with one of the
 * opener's replies. Returns TRUE if it started.
 */
/mob/living/basic/outpost_prisoner/proc/start_conversation(mob/living/basic/outpost_prisoner/partner)
	if(!may_speak() || QDELETED(partner) || !partner.may_speak())
		return FALSE
	var/list/conversations = outpost_prisoner_dialogue("conversations")
	if(!length(conversations))
		return FALSE
	// Friends and rivals have their own (outpost_prison_life.dm).
	var/list/conversation = prison?.pick_conversation(src, partner) || pick(conversations)
	var/opener = conversation["opener"]
	var/list/replies = conversation["replies"]
	if(!istext(opener) || !length(replies))
		return FALSE
	last_line = opener
	say(fill_line(opener, partner))
	addtimer(CALLBACK(partner, PROC_REF(reply_in_conversation), pick(replies), WEAKREF(src)), rand(3, 5) SECONDS)
	prison?.note_speech()
	return TRUE

/// The second half of a conversation
/mob/living/basic/outpost_prisoner/proc/reply_in_conversation(line, datum/weakref/opener_ref)
	var/mob/living/basic/outpost_prisoner/opener = opener_ref?.resolve()
	if(!may_speak() || QDELETED(opener) || get_dist(src, opener) > 5)
		return FALSE
	face_atom(opener)
	last_line = line
	say(fill_line(line, opener))
	return TRUE

/// Whether a member of staff (see is_outpost_prison_staff()) is in sight, borgs included
/mob/living/basic/outpost_prisoner/proc/staff_in_view()
	for(var/mob/living/person in view(5, src))
		if(is_outpost_prison_staff(person))
			return TRUE
	return FALSE

/// Another prisoner close by, to talk at
/mob/living/basic/outpost_prisoner/proc/nearby_prisoner()
	for(var/mob/living/basic/outpost_prisoner/other in view(3, src))
		if(other != src && other.stat == CONSCIOUS && other.phase == PRISONER_PRESENT)
			return other
	return null

/**
 * What to talk about now, as list(context, other), most pressing first: cuffs, trouble, lockdown,
 * being locked in, needs, the state of the wing, staff in sight, what they are doing, then small talk.
 */
/mob/living/basic/outpost_prisoner/proc/pick_speech()
	if(activity?.sleeping)
		return prob(25) ? list("sleeping", null) : null
	// Cuffed, they complain about it (outpost_prison_capture.dm).
	if(cuffs && prob(50))
		return list("cuffed", null)
	// Trouble has its own lines, said as it happens (outpost_prison_trouble.dm).
	if(trouble == PRISONER_TROUBLE_LOOSE)
		return prob(50) ? list("breakout", null) : null
	if(is_rioting())
		return list("riot", null)
	if(trouble || beaten_left > 0 || threat_ref || climb_ref)
		return null
	// Running from a creature, they shout about that instead (outpost_prison_panic.dm).
	if(is_panicking())
		return null
	// Sullen while they serve a lockdown
	if(lockdown_left > 0 && prob(50))
		return list("lockdown", null)
	if(locked_in_seconds >= OUTPOST_PRISON_LOCKED_IN_COMPLAINT && prob(60))
		return list("locked_in", null)
	// The wing's mood shows before it turns: complaints, then shouting at staff.
	switch(prison?.stage)
		if(PRISON_STAGE_RESTLESS)
			if(prob(staff_in_view() ? 60 : 40))
				return list("restless", null)
		if(PRISON_STAGE_GRUMBLING)
			if(prob(35))
				return list("grumbling", null)
	if(hunger < PRISONER_HUNGER_STARVING && prob(70))
		return list("starving", null)
	if(hunger < PRISONER_HUNGER_HUNGRY && prob(50))
		return list("hungry", null)
	if(uniform_grime >= PRISONER_GRIME_FILTHY && prob(50))
		return list("filthy", null)
	if(health_factor() < PRISONER_BLEED_BELOW && prob(50))
		return list("hurt", null)
	if(prison)
		if(prison.powered_score < 100 && prob(40))
			return list("no_power", null)
		if(prob(outpost_prisoner_complaint_chance(prison.lit_score)))
			return list("dark", null)
		if(prob(outpost_prisoner_complaint_chance(prison.clean_score)))
			return list("dirty_prison", null)
	// Greetings, mail, drink and hints from the extras (outpost_prison_extras.dm)
	var/list/extra = prison?.extra_speech(src)
	if(extra)
		return extra
	if(prob(30) && staff_in_view())
		return list("staff_near", null)
	var/mob/living/basic/outpost_prisoner/partner = activity?.chat_partner()
	if(activity?.context && prob(60))
		return list(activity.context, partner)
	return list("idle", partner || nearby_prisoner())

/**
 * Called about once a second by the prison. Most seconds they say nothing; once their own and
 * the wing's cooldowns are up there is a small chance each second.
 */
/mob/living/basic/outpost_prisoner/proc/speech_tick()
	if(stat != CONSCIOUS || phase != PRISONER_PRESENT || !prison)
		return FALSE
	if(!said_release_soon && sentence_left <= 90)
		said_release_soon = TRUE
		return say_context("release_soon")
	if(!COOLDOWN_FINISHED(src, speech_cooldown) || !prison.wing_can_speak() || !prob(10))
		return FALSE
	var/list/choice = pick_speech()
	if(!choice)
		return FALSE
	// A restless yard goes quiet (outpost_prison_ambience.dm).
	if(prison.speech_hushed(src, choice[1]))
		return FALSE
	// An extra's pick may carry values for its placeholders: list(context, other, values)
	extra_line_values = length(choice) >= 3 ? choice[3] : null
	var/said = say_context(choice[1], choice[2])
	extra_line_values = null
	if(!said)
		return FALSE
	show_complaint(choice[1])
	COOLDOWN_START(src, speech_cooldown, rand(35, 80) SECONDS * speech_pace())
	prison.note_speech()
	return TRUE

// ===== COMPLAINTS =====

/**
 * Percent chance a prisoner with nothing more pressing to say complains about a clean or lit score:
 * none at PRISON_WING_MOOD_LINE or above, rising in a straight line to PRISONER_COMPLAINT_MAX_CHANCE
 * at 0, the same shape as the mood the score costs.
 */
/proc/outpost_prisoner_complaint_chance(score)
	return PRISONER_COMPLAINT_MAX_CHANCE * clamp((PRISON_WING_MOOD_LINE - score) / PRISON_WING_MOOD_LINE, 0, 1)

/// How bad something on the floor looks, for picking what to point at: 0 if it is not mess, 3 for vomit and blood pools, otherwise 1
/proc/outpost_prisoner_eyesore(atom/movable/thing)
	if(istype(thing, /obj/item/trash) || istype(thing, /obj/item/cigbutt) || istype(thing, /obj/item/shard))
		return 1
	if(!istype(thing, /obj/effect/decal/cleanable))
		return 0
	var/obj/effect/decal/cleanable/mess = thing
	if(!mess.is_mopped || istype(mess, /obj/effect/decal/cleanable/crayon))
		return 0
	if(istype(mess, /obj/effect/decal/cleanable/vomit))
		return 3
	if(istype(mess, /obj/effect/decal/cleanable/blood) && !istype(mess, /obj/effect/decal/cleanable/blood/drip) && !istype(mess, /obj/effect/decal/cleanable/blood/footprints) && !istype(mess, /obj/effect/decal/cleanable/blood/tracks))
		return 3
	return 1

/// A piece of mess on the worst tile of the cell block's floor they can see nearby, or null
/mob/living/basic/outpost_prisoner/proc/worst_mess_in_view()
	var/list/tile_load = list()
	var/atom/movable/worst
	var/worst_load = 0
	for(var/atom/movable/thing in view(PRISONER_POINT_RANGE, src))
		var/weight = outpost_prisoner_eyesore(thing)
		if(!weight || !isturf(thing.loc))
			continue
		if(prison && (get_area(thing) != prison.wing || !prison.in_cell_block(thing)))
			continue
		var/load = tile_load[thing.loc] + weight
		tile_load[thing.loc] = load
		if(load > worst_load)
			worst_load = load
			worst = thing
	return worst

/// The nearest light in the wing they can see that gives no light, or null
/mob/living/basic/outpost_prisoner/proc/dead_light_in_view()
	var/obj/machinery/light/nearest
	var/nearest_distance = INFINITY
	for(var/obj/machinery/light/fixture in view(PRISONER_POINT_RANGE, src))
		if(fixture.status == LIGHT_OK && fixture.has_power())
			continue
		if(prison && get_area(fixture) != prison.wing)
			continue
		var/distance = get_dist(src, fixture)
		if(distance < nearest_distance)
			nearest = fixture
			nearest_distance = distance
	return nearest

/**
 * After a dirty_prison or dark line, with staff in sight, points at what they mean: the worst mess
 * or the dead light near them. Returns what they pointed at, or null.
 */
/mob/living/basic/outpost_prisoner/proc/show_complaint(context)
	if(context != "dirty_prison" && context != "dark")
		return null
	if(stat != CONSCIOUS || !isturf(loc) || !staff_in_view())
		return null
	var/atom/movable/target = context == "dark" ? dead_light_in_view() : worst_mess_in_view()
	if(!target)
		return null
	_pointed(target)
	return target

#undef PRISONER_DIALOGUE_FILE
#undef PRISONER_DIALOGUE_DIR
#undef PRISONER_COMPLAINT_MAX_CHANCE
#undef PRISONER_POINT_RANGE
