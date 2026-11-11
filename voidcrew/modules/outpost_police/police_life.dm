/**
 * # Outpost police: life and voice
 *
 * Owner: P3. The officers' routines (the beat, coffee, chat, the sergeant's desk, looking in on a sleeper),
 * the ambient roles that bring them, what they say and the radio. Spec 11. Lines come from
 * AMBIENT_STRINGS_POLICE by profile section (`profile.voice_section`).
 *
 * How officers sit with the ambient system (build plan P0 note 18, the 8-person cap):
 * - They are ambient outpost NPCs in their place's `npcs`, so the empty-outpost pause, the leash, the place's
 *   speech clock and the killed-slot wait all work on them as on anyone.
 * - They are NOT part of the crowd the cap counts: living_npcs() of an outpost leaves them out (that list is
 *   "the crowd": the cap, the violence ducking, the convoy, the kingpin's shootout), and crowd_count() puts
 *   them back for the one thing they matter to there, life_standing room. Their own roles count them separately
 *   (wanted() is how many are missing), and the subsystem's settle pass is wrapped so that its running count
 *   never includes an officer (settle_outpost() below). The ambient roles test sums only roles that apply to
 *   an outpost, and these apply only where the map has a police station (life_has_station()), so it is unchanged.
 *
 * What each line context means (POLICE_LINE_*; the text is in the JSON, and a package may call any of them):
 *   knock       the warning under one star ("Hey. Knock it off.")        warn      the first call at one star
 *   order       the order to a suspect to comply                        chase     shouted after a runner
 *   stun        the call at two stars ("On the ground!")                shots     "Shots fired" at three stars
 *   all_units   the call at four stars                                  marshal   the marshal at five
 *   lost        lost sight, look about                                  cuff/walk/make_way   the escort
 *   book        into the cell                                           release/bail   let out / paid for
 *   medic       a suspect or prisoner down                              officer_down / clear   radio calls
 *   cell_alarm  a cell door being forced                                move_along   told to a sleeper
 *   radio_call  the desk calling a change of level (with %PLACE% %LOOK%) radio_ack   an officer answering it
 *   search / evidence / strip / locker_thief   the property steps
 * Extra contexts of mine: radio_call_hot (the same at three stars and up), check_in / check_in_reply (a beat
 * officer reporting in), beat / trader_reply (a word to a shop), guard / guard_reply (the sergeant and the
 * checkpoint guard), cell_check / cell_reply (the sergeant and a prisoner), talk_prior (to someone with a record).
 */

/// The police radio frequency, the same at every outpost: messages are scoped to the speaker's network (the map
/// region), so three outposts never hear each other, and it lies in the band any handheld radio can tune to.
#define OUTPOST_POLICE_RADIO_FREQ 1473
/// Nobody says a line of the same kind within this long of someone else saying it
#define POLICE_SAY_GAP (4 SECONDS)
/// The same words are not said again within this long
#define POLICE_TEXT_GAP (20 SECONDS)
/// After an officer falls every order is a level harder, in voice only, for this long
#define POLICE_HARDER_TIME (60 SECONDS)
/// Routine radio check-ins are no closer than this
#define POLICE_CHECK_IN_GAP (150 SECONDS)
/// Shop fronts on one patrol
#define POLICE_BEAT_STOPS 3
/// How far from a shop front the beat officer stands
#define POLICE_BEAT_DISTANCE_LOW 3
#define POLICE_BEAT_DISTANCE_HIGH 4
/// How far round their post a sleeper is looked for
#define POLICE_CHECK_RANGE 10

// =========================================================================
// WHAT THEY HAVE SAID (one per police, kept off the frozen core)
// =========================================================================

/// Cooldowns and the state of the radio for one outpost's officers. Holds no references to anything.
/datum/outpost_police_voice
	/// Context -> world.time anyone may speak a line of that kind again
	var/list/context_free_at = list()
	/// Text -> world.time it may be said again
	var/list/text_free_at = list()
	/// The alert level the desk last called
	var/called_level = 0
	/// The marshal has spoken for this incident
	var/marshal_spoke = FALSE
	/// REFs of the officers already called down
	var/list/called_down = list()
	/// world.time until which orders run a level harder in voice
	var/harder_until = 0
	/// world.time the next routine radio check-in may be made
	var/next_check_in_at = 0

/// Declared here, not in police_core.dm: the core is frozen and this is only mine
/datum/outpost_police
	/// What the officers have said lately (police_life.dm)
	var/datum/outpost_police_voice/voice

/datum/outpost_police/proc/life_voice()
	if(!voice)
		voice = new
	return voice

/// Whether the map gave this outpost a police station: a desk or a police lift
/datum/outpost_police/proc/life_has_station()
	return !!desk_turf || length(lift_turfs) > 0

/// The first free tile behind a police door, or null
/datum/outpost_police/proc/life_free_lift_turf()
	for(var/turf/lift as anything in shuffle(lift_turfs.Copy()))
		if(!lift.is_blocked_turf(exclude_mobs = FALSE))
			return lift
	return null

/// Officers on the roster of this unit kind that are alive and not leaving
/datum/outpost_police/proc/life_standing(unit_kind)
	. = 0
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(!QDELETED(officer) && officer.stat != DEAD && !officer.fading && officer.unit_kind == unit_kind)
			.++

/// Whether `who` is held in a cell right now
/datum/outpost_police/proc/life_prisoner_held(datum/mind/who)
	if(!who)
		return FALSE
	for(var/datum/outpost_police_cell/cell as anything in cells)
		if(who in cell.prisoners)
			return TRUE
	return FALSE

/// A cell with someone in it, or null
/datum/outpost_police/proc/life_occupied_cell()
	for(var/datum/outpost_police_cell/cell as anything in cells)
		if(length(cell.prisoners))
			return cell
	return null

/// The sergeant, or failing that any officer who can speak: whoever is on the radio
/datum/outpost_police/proc/life_dispatcher()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/fallback
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(QDELETED(officer) || officer.stat != CONSCIOUS || officer.fading)
			continue
		if(officer.unit_kind == POLICE_UNIT_SERGEANT)
			return officer
		fallback ||= officer
	return fallback

/// The officer nearest `where` within `range`, awake, not `except`; null if none
/datum/outpost_police/proc/life_nearest_officer(turf/where, range = 12, mob/living/except)
	if(!where)
		return null
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/best
	var/best_distance = INFINITY
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(QDELETED(officer) || officer == except || officer.stat != CONSCIOUS || officer.fading)
			continue
		var/turf/there = get_turf(officer)
		if(!there || there.z != where.z)
			continue
		var/distance = get_dist(there, where)
		if(distance <= range && distance < best_distance)
			best = officer
			best_distance = distance
	return best

// =========================================================================
// LINES
// =========================================================================

/**
 * `values` as a list of cleaned text: "place" and "look" (a key may be written place, PLACE or %PLACE%).
 * Markup is stripped and each value is bounded: speech carries only type names and catalog shop names (M15).
 */
/proc/outpost_police_values(list/values)
	. = list()
	for(var/key in values)
		var/text = values[key]
		if(!istext(text))
			continue
		text = replacetext(text, "\improper ", "")
		text = replacetext(replacetext(replacetext(text, "<", ""), ">", ""), "%", "")
		text = copytext_char(trimtext(text), 1, 41)
		if(length(text))
			.[lowertext(replacetext("[key]", "%", ""))] = text

/**
 * One of `lines` that `values` can fill (a line with %PLACE% needs a place, one with %LOOK% a look), filled in.
 * Null if there is none.
 */
/proc/outpost_police_pick_line(list/lines, list/values)
	var/list/usable = list()
	for(var/line in lines)
		if(!istext(line))
			continue
		if(findtext(line, "%PLACE%") && !values["place"])
			continue
		if(findtext(line, "%LOOK%") && !values["look"])
			continue
		usable += line
	if(!length(usable))
		return null
	var/text = pick(usable)
	text = replacetext(text, "%PLACE%", values["place"])
	text = replacetext(text, "%LOOK%", values["look"])
	return text

/// One level harder, in voice only (after an officer falls)
/proc/outpost_police_harder(context)
	switch(context)
		if(POLICE_LINE_KNOCK)
			return POLICE_LINE_WARN
		if(POLICE_LINE_WARN)
			return POLICE_LINE_ORDER
		if(POLICE_LINE_ORDER)
			return POLICE_LINE_STUN
		if(POLICE_LINE_STUN)
			return POLICE_LINE_SHOTS
	return context

// Everything an officer says comes from the police file, by the zone's voice
/mob/living/carbon/human/npc/ambient_npc/outpost/police
	dialogue_file = AMBIENT_STRINGS_POLICE
	dialogue_section = "halcyon"
	speech_pace = 0.7
	routine = list(
		/datum/ambient_activity/idle = 3,
		/datum/ambient_activity/chat = 1,
	)
	/// Weakref to the coffee machine they use, and when it was last looked for
	var/datum/weakref/coffee_ref
	var/coffee_looked_at = 0

/// The beat: round the shop fronts, a coffee, a word with whoever is about, an eye on the benches
/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat
	routine = list(
		/datum/ambient_activity/wander/police_beat = 6,
		/datum/ambient_activity/police_coffee = 1,
		/datum/ambient_activity/chat = 2,
		/datum/ambient_activity/police_check = 1,
		/datum/ambient_activity/idle = 1,
	)

/// The desk: sits, writes, looks in on the cell, a word with the guard
/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant
	routine = list(
		/datum/ambient_activity/police_desk = 8,
		/datum/ambient_activity/police_coffee = 1,
		/datum/ambient_activity/chat = 1,
	)

/// The zone's voice: their section of the police file
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/life_voice_section()
	return police?.profile?.voice_section || "halcyon"

/mob/living/carbon/human/npc/ambient_npc/outpost/police/get_lines(context)
	var/list/lines = ambient_dialogue_lines(AMBIENT_STRINGS_POLICE, life_voice_section(), context)
	return length(lines) ? lines : ..()

/mob/living/carbon/human/npc/ambient_npc/outpost/police/pick_conversation()
	var/list/entry = ambient_dialogue_section(AMBIENT_STRINGS_POLICE, life_voice_section())
	var/list/conversations = entry?["conversations"]
	if(!length(conversations))
		return ..()
	var/list/conversation = pick(conversations)
	if(!islist(conversation) || !istext(conversation["opener"]))
		return null
	var/list/replies = conversation["replies"]
	return list(conversation["opener"], length(replies) ? pick(replies) : null)

/**
 * Says one line of kind `line` (POLICE_LINE_* or one of mine), with `values` ("place", "look") filled in, on
 * the radio too if `radio`. Nobody says a line of the same kind within POLICE_SAY_GAP of someone else, and the
 * same words are not said twice in a row. Never sleeps. Returns the words said, or null if nothing was.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_say(line, list/values, radio = FALSE)
	if(QDELETED(src) || stat != CONSCIOUS || fading || paused_at)
		return null
	var/datum/outpost_police_voice/voice = police?.life_voice()
	var/context = line
	if(voice && voice.harder_until > world.time)
		context = outpost_police_harder(line)
	if(voice && voice.context_free_at[context] > world.time)
		return null
	var/text = outpost_police_pick_line(get_lines(context), outpost_police_values(values))
	if(!text || (voice && voice.text_free_at[text] > world.time))
		return null
	if(voice)
		voice.context_free_at[context] = world.time + POLICE_SAY_GAP
		voice.text_free_at[text] = world.time + POLICE_TEXT_GAP
		if(length(voice.text_free_at) > 30)
			for(var/old_text in voice.text_free_at.Copy())
				if(voice.text_free_at[old_text] <= world.time)
					voice.text_free_at -= old_text
	// A moment of quiet after a line that matters, so nobody chats over it
	next_line_at = max(next_line_at, world.time + 6 SECONDS)
	life_speak(text, radio)
	return text

/// Says `text` aloud, over the headset if `radio` and they wear one
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/life_speak(text, radio)
	if(radio && life_headset())
		// Everyone on the roster is tuned to the frequency, so the others hear it
		police?.life_tune_all()
		INVOKE_ASYNC(src, TYPE_PROC_REF(/atom/movable, say), ";[text]")
		return
	INVOKE_ASYNC(src, TYPE_PROC_REF(/atom/movable, say), text)

/// Their headset, tuned to the police frequency, or null if they wear none
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/life_headset()
	var/obj/item/radio/headset = ears
	if(!istype(headset))
		return null
	if(headset.frequency != OUTPOST_POLICE_RADIO_FREQ)
		headset.set_frequency(OUTPOST_POLICE_RADIO_FREQ)
	return headset

/// Tunes every officer's headset to the police frequency
/datum/outpost_police/proc/life_tune_all()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		officer.life_headset()

/// The desk: the sergeant (or the nearest officer) says `line` on the radio
/datum/outpost_police/proc/say_dispatch(line, list/values)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/speaker = life_dispatcher()
	return speaker?.police_say(line, values, TRUE)

/// Up to `count` officers answer the desk, nearest `where` first, a moment apart
/datum/outpost_police/proc/life_acknowledge(count, turf/where, mob/living/except)
	var/list/answered = list()
	for(var/i in 1 to count)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer
		var/best_distance = INFINITY
		for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/candidate in officers)
			if(QDELETED(candidate) || candidate == except || (candidate in answered) || candidate.stat != CONSCIOUS || candidate.fading)
				continue
			var/distance = where ? get_dist(candidate, where) : rand(1, 20)
			if(distance < best_distance)
				officer = candidate
				best_distance = distance
		if(!officer)
			break
		answered += officer
		addtimer(CALLBACK(officer, TYPE_PROC_REF(/mob/living/carbon/human/npc/ambient_npc/outpost/police, police_say), POLICE_LINE_RADIO_ACK, null, TRUE), (1 SECONDS) + (i * 1.5 SECONDS), TIMER_DELETE_ME)

/// A beat officer reporting in over the radio, and the desk answering; not too often
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/life_check_in()
	var/datum/outpost_police_voice/voice = police?.life_voice()
	if(!voice || voice.next_check_in_at > world.time)
		return
	voice.next_check_in_at = world.time + POLICE_CHECK_IN_GAP
	if(!police_say("check_in", null, TRUE))
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/desk = police.life_dispatcher()
	if(desk && desk != src)
		addtimer(CALLBACK(desk, TYPE_PROC_REF(/mob/living/carbon/human/npc/ambient_npc/outpost/police, police_say), "check_in_reply", null, TRUE), 2 SECONDS, TIMER_DELETE_ME)

// ----- what they say when someone talks to them -----

/mob/living/carbon/human/npc/ambient_npc/outpost/police/talked_to(mob/living/user)
	if(!talk_ready(user))
		return
	if(!buckled)
		face_atom(user)
	var/datum/outpost_warrant/record = user.mind ? police?.get_warrant(user.mind) : null
	speak_context(record && (record.prior > 0 || record.heat > 0) ? "talk_prior" : AMBIENT_LINE_TALK, user, force = TRUE)

// ----- an officer falls -----

/mob/living/carbon/human/npc/ambient_npc/outpost/police/Initialize(mapload, datum/human_npc_order/order)
	. = ..()
	RegisterSignal(src, COMSIG_LIVING_DEATH, PROC_REF(life_on_death))
	// Whatever headset their outfit gave them listens to the police
	life_headset()

/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/life_on_death(datum/source, gibbed)
	SIGNAL_HANDLER
	police?.life_call_officer_down(src)

/// "Officer down!" from whoever sees it (the desk if nobody does), and every order runs a level harder for a while
/datum/outpost_police/proc/life_call_officer_down(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/datum/outpost_police_voice/voice = life_voice()
	var/key = REF(officer)
	if(key in voice.called_down)
		return
	voice.called_down += key
	if(length(voice.called_down) > 24)
		voice.called_down.Cut(1, 2)
	voice.harder_until = world.time + POLICE_HARDER_TIME
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/witness = life_nearest_officer(get_turf(officer), 12, officer)
	if(witness)
		witness.police_say(POLICE_LINE_OFFICER_DOWN, null, TRUE)
	else
		say_dispatch(POLICE_LINE_OFFICER_DOWN)

// ----- the sergeant overhears a prisoner -----

/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/Initialize(mapload, datum/human_npc_order/order)
	. = ..()
	RegisterSignal(src, COMSIG_MOVABLE_HEAR, PROC_REF(life_on_overheard))
	become_hearing_sensitive(AMBIENT_NPC_TRAIT)

/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/proc/life_on_overheard(datum/source, list/hearing_args)
	SIGNAL_HANDLER
	var/atom/movable/speaker = hearing_args[HEARING_SPEAKER]
	if(!ismob(speaker) || speaker == src || hearing_args[HEARING_RADIO_FREQ] || stat != CONSCIOUS || fading || paused_at)
		return
	var/mob/prisoner = speaker
	if(get_dist(src, prisoner) > 9 || !police?.life_prisoner_held(prisoner.mind) || !reaction_ready("cell reply", 20 SECONDS))
		return
	addtimer(CALLBACK(src, PROC_REF(life_answer_cell), WEAKREF(prisoner)), rand(AMBIENT_REPLY_DELAY_LOW, AMBIENT_REPLY_DELAY_HIGH), TIMER_DELETE_ME)

/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/proc/life_answer_cell(datum/weakref/prisoner_ref)
	var/mob/prisoner = prisoner_ref?.resolve()
	if(QDELETED(prisoner) || stat != CONSCIOUS || fading)
		return
	if(!buckled)
		face_atom(prisoner)
	speak_context("cell_reply", prisoner, force = TRUE)

// =========================================================================
// DISPATCH CHATTER (the tick)
// =========================================================================

/// Once a second (police_core.dm tick()): the desk calls each change of level, officers answer, all clear
/datum/outpost_police/proc/tick_life()
	var/datum/outpost_police_voice/voice = life_voice()
	var/level = alert_level()
	if(level != voice.called_level)
		var/old_level = voice.called_level
		voice.called_level = level
		if(level > old_level)
			life_call_level(level, old_level)
		else if(!level)
			life_call_clear()
	if(level >= 5 && !voice.marshal_spoke)
		for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
			if(officer.unit_kind == POLICE_UNIT_MARSHAL && officer.stat == CONSCIOUS && !officer.fading)
				voice.marshal_spoke = !!officer.police_say(POLICE_LINE_MARSHAL, null, TRUE)
				break
	else if(level < 5)
		voice.marshal_spoke = FALSE

/// The level rose from `old_level` to `level`: the desk calls it, officers answer, and the louder calls follow
/datum/outpost_police/proc/life_call_level(level, old_level)
	var/list/values = life_suspect_values()
	var/datum/outpost_warrant/top = life_top_warrant()
	var/turf/where = get_turf(top?.mind?.current)
	say_dispatch(level >= 3 ? "radio_call_hot" : POLICE_LINE_RADIO_CALL, values)
	life_acknowledge(level >= 3 ? 2 : 1, where)
	if(level >= 3 && old_level < 3)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/shouter = where ? life_nearest_officer(where, 20) : null
		shouter ||= life_dispatcher()
		shouter?.police_say(POLICE_LINE_SHOTS, null, TRUE)
	if(level >= 4 && old_level < 4)
		addtimer(CALLBACK(src, PROC_REF(say_dispatch), POLICE_LINE_ALL_UNITS), 3 SECONDS, TIMER_DELETE_ME)

/// Nobody is wanted any more: the nearest unit reports clear and the desk answers
/datum/outpost_police/proc/life_call_clear()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/reporter
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(officer.stat == CONSCIOUS && !officer.fading && officer.unit_kind != POLICE_UNIT_SERGEANT)
			reporter = officer
			if(officer.case || officer.force != POLICE_FORCE_NONE)
				break
	if(!reporter?.police_say(POLICE_LINE_CLEAR, null, TRUE))
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/desk = life_dispatcher()
	if(desk && desk != reporter)
		addtimer(CALLBACK(desk, TYPE_PROC_REF(/mob/living/carbon/human/npc/ambient_npc/outpost/police, police_say), POLICE_LINE_RADIO_ACK, null, TRUE), 2 SECONDS, TIMER_DELETE_ME)

/// The warrant at the outpost with the most stars, or null
/datum/outpost_police/proc/life_top_warrant()
	var/datum/outpost_warrant/best
	var/best_stars = 0
	for(var/datum/outpost_warrant/warrant as anything in suspects_at_outpost())
		var/stars = get_stars(warrant.mind)
		if(stars > best_stars)
			best = warrant
			best_stars = stars
	return best

/// "look" (what the top suspect wears, by the type's own name) and "place" (the nearest shop's catalog name), for the radio
/datum/outpost_police/proc/life_suspect_values()
	var/mob/living/suspect = life_top_warrant()?.mind?.current
	if(!istype(suspect))
		return list()
	var/list/values = list()
	var/look = outpost_police_look(suspect)
	if(look)
		values["look"] = look
	var/place_name = life_nearest_shop_name(get_turf(suspect))
	if(place_name)
		values["place"] = place_name
	return values

/// What `suspect` wears, named by the type of their outer clothing or jumpsuit and never the item's own name (M15)
/proc/outpost_police_look(mob/living/suspect)
	var/obj/item/worn = suspect.get_item_by_slot(ITEM_SLOT_OCLOTHING) || suspect.get_item_by_slot(ITEM_SLOT_ICLOTHING)
	if(!worn)
		return null
	var/obj/item/worn_type = worn.type
	return initial(worn_type.name)

/// The catalog name of the shop nearest `where` within 15 tiles (never the checkpoint), or null
/datum/outpost_police/proc/life_nearest_shop_name(turf/where)
	if(!where || !outpost)
		return null
	var/best_shop
	var/best_distance = 16
	for(var/mob/living/basic/outpost_trader/trader as anything in outpost.traders)
		if(QDELETED(trader) || trader.z != where.z)
			continue
		var/shop_type = ambient_trader_shop(trader)
		if(!ispath(shop_type, /datum/outpost_shop) || ispath(shop_type, /datum/outpost_shop/vendor/checkpoint))
			continue
		var/distance = get_dist(trader, where)
		if(distance < best_distance)
			best_shop = shop_type
			best_distance = distance
	if(!best_shop)
		return null
	var/datum/outpost_shop/shop_name_type = best_shop
	return initial(shop_name_type.outpost_name)

// =========================================================================
// ROLES: who is on duty
// =========================================================================

/**
 * The police roles: they apply only where the map has a police station, wait a short while between arrivals,
 * and come off a police lift (arrive()) or are found at their post (settle()). They are not part of the crowd
 * the cap counts (see the header), so wanted() is how many are missing, not how many there should be.
 */
/datum/ambient_outpost_role/police_beat
	name = "police beat"
	npc_type = /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat
	max_count = 3
	weight = 2
	gap_low = 20 SECONDS
	gap_high = 40 SECONDS

/datum/ambient_outpost_role/police_beat/applies_to(obj/structure/overmap/trader_outpost/outpost)
	return ..() && !!outpost?.police?.life_has_station()

/datum/ambient_outpost_role/police_beat/wanted(datum/ambient_place/outpost/place)
	return outpost_police_missing(place, POLICE_UNIT_BEAT, place?.outpost()?.police?.profile?.beat_count || 2)

/datum/ambient_outpost_role/police_beat/settle(datum/ambient_place/outpost/place)
	return outpost_police_settle(src, place, istype(place) ? place.settle_turf() : null)

/datum/ambient_outpost_role/police_beat/arrive(datum/ambient_place/outpost/place, turf/where)
	return outpost_police_arrive(src, place, where)

/datum/ambient_outpost_role/police_sergeant
	name = "police sergeant"
	npc_type = /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant
	max_count = 1
	weight = 2
	gap_low = 20 SECONDS
	gap_high = 40 SECONDS

/datum/ambient_outpost_role/police_sergeant/applies_to(obj/structure/overmap/trader_outpost/outpost)
	return ..() && !!outpost?.police?.desk_turf

/datum/ambient_outpost_role/police_sergeant/wanted(datum/ambient_place/outpost/place)
	return place?.outpost()?.police?.desk_turf ? outpost_police_missing(place, POLICE_UNIT_SERGEANT, 1) : 0

/datum/ambient_outpost_role/police_sergeant/settle(datum/ambient_place/outpost/place)
	var/turf/desk = istype(place) ? place.outpost()?.police?.desk_turf : null
	if(!desk || (locate(/mob/living) in desk))
		return null
	return outpost_police_settle(src, place, desk)

/datum/ambient_outpost_role/police_sergeant/arrive(datum/ambient_place/outpost/place, turf/where)
	return outpost_police_arrive(src, place, where)

/// Whether `role` brings officers
/proc/is_outpost_police_role(datum/ambient_outpost_role/role)
	return istype(role, /datum/ambient_outpost_role/police_beat) || istype(role, /datum/ambient_outpost_role/police_sergeant)

/// How many of `unit_kind` the outpost is short of, with `posts` wanted: 0 where the map has no police station
/proc/outpost_police_missing(datum/ambient_place/outpost/place, unit_kind, posts)
	var/datum/outpost_police/police = place?.outpost()?.police
	if(!police?.life_has_station())
		return 0
	return max(0, posts - police.life_standing(unit_kind))

/// One of `role`'s officers made at `where`, in `place` and on the roster; null if there is nowhere to put them
/proc/outpost_police_make(datum/ambient_outpost_role/role, datum/ambient_place/outpost/place, turf/where)
	var/datum/outpost_police/police = place?.outpost()?.police
	if(!police || !role.npc_type || !where)
		return null
	var/officer_type = role.npc_type
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = new officer_type(where)
	officer.role = role.type
	officer.set_place(place)
	police.add_officer(officer)
	return officer

/// An officer found at their post `start` while nobody is about, going about their routine part-way in
/proc/outpost_police_settle(datum/ambient_outpost_role/role, datum/ambient_place/outpost/place, turf/start)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = outpost_police_make(role, place, start)
	officer?.settle_in()
	return officer

/// A replacement stepping off a police lift. Where the map has police lifts and none is free, nobody comes (never off the public lift).
/proc/outpost_police_arrive(datum/ambient_outpost_role/role, datum/ambient_place/outpost/place, turf/where)
	var/datum/outpost_police/police = place?.outpost()?.police
	if(!police)
		return null
	var/turf/lift = police.life_free_lift_turf()
	if(!lift)
		if(length(police.lift_turfs))
			return null
		lift = where
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = outpost_police_make(role, place, lift)
	officer?.fade_in()
	return officer

// ----- the crowd and the cap -----

// The crowd is the civilians: the cap, the ducking, the convoy and the shootout leave officers out (see the header)
/datum/ambient_place/outpost/living_npcs()
	. = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/npc as anything in ..())
		if(!istype(npc, /mob/living/carbon/human/npc/ambient_npc/outpost/police))
			. += npc

// ...but they take up room like anyone, so nobody settles on top of one
/datum/ambient_place/outpost/crowd_count(turf/tile, mob/living/carbon/human/npc/ambient_npc/asker, atom/ignore)
	. = ..()
	if(. == INFINITY || !tile)
		return
	var/datum/outpost_police/police = outpost()?.police
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police?.officers)
		if(QDELETED(officer) || officer == asker || officer == ignore || officer.stat == DEAD || officer.fading)
			continue
		var/datum/ambient_activity/current = officer.activity
		var/turf/at = (current && current.spot && !current.at_spot()) ? current.spot : get_turf(officer)
		if(!at || at.z != tile.z)
			continue
		if(at == tile)
			return INFINITY
		if(get_dist(at, tile) <= AMBIENT_CROWD_RADIUS)
			.++

/**
 * Makes the officers this place is short of, at their posts, up to `budget` of them: the desk first, then the
 * beat. Run by settle_outpost() before the crowd, while nobody is on the concourse. Returns how many were made.
 */
/datum/ambient_place/outpost/proc/settle_police(budget)
	. = 0
	var/obj/structure/overmap/trader_outpost/outpost = outpost()
	if(!outpost?.police?.life_has_station())
		return
	for(var/role_type in list(/datum/ambient_outpost_role/police_sergeant, /datum/ambient_outpost_role/police_beat))
		var/datum/ambient_outpost_role/role = SSambient_npcs.get_outpost_role(role_type)
		if(!role?.npc_type || !role.applies_to(outpost))
			continue
		var/missing = open_slots(role)
		while(missing > 0 && . < budget)
			if(!role.settle(src))
				break
			.++
			missing--

/// The shared instance of outpost role `role_type`, or null
/datum/controller/subsystem/ambient_npcs/proc/get_outpost_role(role_type)
	for(var/datum/ambient_outpost_role/role as anything in get_outpost_roles())
		if(role.type == role_type)
			return role
	return null

/**
 * Officers are settled in their own pass, and the crowd's pass is given only the crowd's roles: the subsystem's
 * running count in settle_outpost() would otherwise take an officer for one of the crowd and stop short (or
 * stop the officers short) when the concourse is full. Tests that hand over their own `roles` are untouched.
 */
/datum/controller/subsystem/ambient_npcs/settle_outpost(datum/ambient_place/outpost/place, list/roles, budget = AMBIENT_OUTPOST_SETTLE_PER_FIRE)
	if(roles || budget <= 0 || !place?.needs_settling || place.occupied)
		return ..()
	var/made = place.settle_police(budget)
	if(made >= budget)
		return made
	var/list/crowd = list()
	for(var/datum/ambient_outpost_role/role as anything in get_outpost_roles())
		if(!is_outpost_police_role(role))
			crowd += role
	if(!length(crowd))
		return made
	return made + ..(place, crowd, budget - made)

// =========================================================================
// ROUTINES
// =========================================================================

/// The coffee machine they use: the one nearest the desk, looked for now and then
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/life_coffee_machine()
	var/obj/machinery/vending/coffee/known = coffee_ref?.resolve()
	if(!QDELETED(known))
		return known
	if(world.time < coffee_looked_at + 5 MINUTES)
		return null
	coffee_looked_at = world.time
	var/turf/near = police?.desk_turf || get_turf(src)
	var/obj/machinery/vending/coffee/best
	var/best_distance = INFINITY
	for(var/obj/machinery/vending/coffee/machine in range(14, near))
		var/distance = get_dist(machine, near)
		if(distance < best_distance && !life_keeps_off(get_turf(machine)))
			best = machine
			best_distance = distance
	best ||= ambient_outpost_find(get_outpost(), /obj/machinery/vending/coffee)
	coffee_ref = best ? WEAKREF(best) : null
	return best

/// Whether this officer keeps away from `tile` for now: the kingpin's fight is on near it (M16)
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/life_keeps_off(turf/tile)
	var/turf/fight = ambient_kingpin_fight_center(get_outpost())
	return fight && tile && tile.z == fight.z && get_dist(fight, tile) <= AMBIENT_VIOLENCE_RANGE + 3

// The coffee break is taken at the machine by the desk
/mob/living/carbon/human/npc/ambient_npc/outpost/police/pick_activity()
	return pick_anchored(routine, life_coffee_machine(), list(/datum/ambient_activity/police_coffee))

/// The sergeant is found at the desk
/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/settle_in()
	if(start_activity(new /datum/ambient_activity/police_desk(src)) && settle_here())
		return TRUE
	end_activity()
	return ..()

/// A sip of the coffee in hand; an empty cup is put away
/proc/outpost_police_sip(mob/living/carbon/human/npc/ambient_npc/officer)
	var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = officer.held_item
	if(!istype(glass) || QDELETED(glass))
		return
	if(!glass.reagents?.total_volume)
		officer.put_drink_down(null)
		return
	officer.sip()

/**
 * The beat: a loop of the shop fronts, a stop at each. They stand a few tiles out, face the counter, say a word to
 * the trader, who answers, and carry a coffee if they took one; at the end of the round they report in.
 */
/datum/ambient_activity/wander/police_beat
	name = "walking the beat"
	/// Stops still to make: tiles, and (same order) weakrefs to the trader each is the front of
	var/list/stops
	var/list/stop_traders
	/// The trader at the stop they are at
	var/datum/weakref/trader_ref
	var/next_sip = 0
	var/checked_in = FALSE

/datum/ambient_activity/wander/police_beat/Destroy()
	stops = null
	stop_traders = null
	trader_ref = null
	return ..()

/datum/ambient_activity/wander/police_beat/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = doer
	if(!istype(officer))
		return FALSE
	stops = list()
	stop_traders = list()
	var/datum/ambient_place/outpost/place = officer.place
	if(istype(place))
		for(var/mob/living/basic/outpost_trader/trader as anything in shuffle(ambient_outpost_traders(place)))
			if(trader.z != officer.z || length(stops) >= POLICE_BEAT_STOPS)
				continue
			var/turf/stop = ambient_waiting_spot(officer, trader, POLICE_BEAT_DISTANCE_LOW, POLICE_BEAT_DISTANCE_HIGH, failed_spots)
			if(!stop || officer.life_keeps_off(stop) || (stop in stops))
				continue
			stops += stop
			stop_traders += WEAKREF(trader)
	if(!length(stops))
		// No shop fronts to walk to: a few corners of the floor
		for(var/i in 1 to POLICE_BEAT_STOPS)
			var/turf/corner = istype(place) ? place.settle_turf(officer, officer, 9) : null
			if(corner && !officer.life_keeps_off(corner) && !(corner in stops))
				stops += corner
				stop_traders += null
	if(!length(stops))
		return FALSE
	stops_left = length(stops)
	return next_stop()

/datum/ambient_activity/wander/police_beat/next_stop()
	while(length(stops))
		var/turf/stop = stops[1]
		trader_ref = stop_traders[1]
		stops.Cut(1, 2)
		stop_traders.Cut(1, 2)
		if(LAZYACCESS(failed_spots, stop))
			continue
		go_to(stop)
		return TRUE
	return FALSE

/datum/ambient_activity/wander/police_beat/arrive()
	. = ..()
	var/mob/living/basic/outpost_trader/trader = trader_ref?.resolve()
	if(QDELETED(trader) || trader.stat == DEAD)
		return
	if(!doer.buckled)
		doer.face_atom(trader)
	// A word to the shop, and its answer; not at every counter
	if(prob(70) && doer.speak_context("beat", trader, force = TRUE))
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = doer
		ambient_trader_reply(trader, doer, AMBIENT_STRINGS_POLICE, officer.life_voice_section(), "trader_reply", 6)

/datum/ambient_activity/wander/police_beat/act(seconds)
	if(doer.held_item && world.time >= next_sip && world.time < linger_until)
		next_sip = world.time + rand(10 SECONDS, 20 SECONDS)
		outpost_police_sip(doer)
	if(world.time >= linger_until && !length(stops) && !checked_in)
		checked_in = TRUE
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = doer
		if(istype(officer) && prob(40))
			officer.life_check_in()
	return ..()

/datum/ambient_activity/wander/police_beat/shift_times(delay)
	. = ..()
	next_sip = ambient_shifted(next_sip, delay)

/**
 * A coffee from the machine by the desk, drunk life_standing beside it; most take it along on the beat, in a real
 * mug with real coffee.
 */
/datum/ambient_activity/police_coffee
	name = "getting a coffee"
	accepts_company = TRUE
	duration_low = 20 SECONDS
	duration_high = 45 SECONDS
	/// They take the mug with them when they go
	var/carry_on = FALSE
	var/next_sip = 0
	/// world.time they got it
	var/took_at = 0

/datum/ambient_activity/police_coffee/setup()
	var/obj/machinery/vending/coffee/machine = anchor()
	if(!istype(machine))
		return FALSE
	var/turf/stand = doer.free_tile_beside(machine, 1, failed_spots)
	if(!stand)
		return FALSE
	go_to(stand)
	set_duration()
	carry_on = prob(70)
	return TRUE

/datum/ambient_activity/police_coffee/arrive()
	var/obj/machinery/vending/coffee/machine = anchor()
	if(machine && !doer.buckled)
		doer.face_atom(machine)
	if(machine)
		playsound(machine, 'sound/machines/machine_vend.ogg', 40, TRUE, -3)
		if(machine.icon_vend)
			flick(machine.icon_vend, machine)
	doer.take_drink(/datum/reagent/consumable/coffee)
	took_at = world.time
	next_sip = world.time + rand(5 SECONDS, 9 SECONDS)

/datum/ambient_activity/police_coffee/act(seconds)
	if(carry_on && world.time >= took_at + 6 SECONDS)
		return AMBIENT_STEP_DONE
	if(world.time >= next_sip)
		next_sip = world.time + rand(8 SECONDS, 15 SECONDS)
		outpost_police_sip(doer)
	if(!doer.held_item)
		return AMBIENT_STEP_DONE
	chatter()
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/police_coffee/finish()
	// The mug goes along on the beat: the next thing they do puts it down
	if(carry_on && !QDELETED(doer) && doer.held_item)
		doer.stand_up()
		return
	return ..()

/datum/ambient_activity/police_coffee/shift_times(delay)
	. = ..()
	next_sip = ambient_shifted(next_sip, delay)
	took_at = ambient_shifted(took_at, delay)

/**
 * The sergeant at the desk: sits if there is a chair, a clipboard in hand, writes now and then, looks in on the
 * cell when someone is in it, and has a word with the checkpoint guard.
 */
/datum/ambient_activity/police_desk
	name = "at the desk"
	accepts_company = TRUE
	duration_low = 60 SECONDS
	duration_high = 150 SECONDS
	var/datum/weakref/chair_ref
	var/next_write = 0
	var/next_cell_look = 0
	var/next_guard_word = 0

/datum/ambient_activity/police_desk/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = doer
	var/turf/desk = istype(officer) ? officer.police?.desk_turf : null
	if(!desk)
		return FALSE
	go_to(desk)
	set_duration()
	var/obj/structure/chair/chair = locate() in desk
	chair_ref = chair ? WEAKREF(chair) : null
	next_write = world.time + rand(3 SECONDS, 8 SECONDS)
	next_cell_look = world.time + rand(20 SECONDS, 40 SECONDS)
	next_guard_word = world.time + rand(60 SECONDS, 120 SECONDS)
	return TRUE

/datum/ambient_activity/police_desk/Destroy()
	chair_ref = null
	return ..()

/datum/ambient_activity/police_desk/arrive()
	var/obj/structure/chair/chair = chair_ref?.resolve()
	if(chair && !doer.sit_on(chair))
		chair_ref = null
	doer.set_held(/obj/item/clipboard)

/datum/ambient_activity/police_desk/act(seconds)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = doer
	if(world.time >= next_write)
		next_write = world.time + rand(8 SECONDS, 16 SECONDS)
		playsound(doer, pick('sound/effects/writing_pen/writing_pen1.ogg', 'sound/effects/writing_pen/writing_pen2.ogg', 'sound/effects/writing_pen/writing_pen3.ogg'), 15, TRUE, -5)
	if(world.time >= next_cell_look)
		next_cell_look = world.time + rand(25 SECONDS, 45 SECONDS)
		var/datum/outpost_police_cell/cell = officer.police?.life_occupied_cell()
		var/atom/cell_view = cell?.door || (length(cell?.tiles) ? cell.tiles[1] : null)
		if(cell_view)
			if(!doer.buckled)
				doer.face_atom(cell_view)
			doer.speak_context("cell_check", null, force = TRUE)
	if(world.time >= next_guard_word)
		next_guard_word = world.time + rand(90 SECONDS, 180 SECONDS)
		var/mob/living/basic/outpost_trader/checkpoint_guard/guard
		for(var/mob/living/basic/outpost_trader/checkpoint_guard/found in range(9, doer))
			if(found.stat != DEAD && can_see(doer, found, 10))
				guard = found
				break
		if(guard)
			if(!doer.buckled)
				doer.face_atom(guard)
			if(doer.speak_context("guard", guard, force = TRUE))
				ambient_trader_reply(guard, doer, AMBIENT_STRINGS_POLICE, officer.life_voice_section(), "guard_reply", 9)
	chatter(AMBIENT_LINE_WORK, 40 SECONDS, 80 SECONDS)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/police_desk/finish()
	if(!QDELETED(doer))
		doer.set_held(null)
	return ..()

/datum/ambient_activity/police_desk/shift_times(delay)
	. = ..()
	next_write = ambient_shifted(next_write, delay)
	next_cell_look = ambient_shifted(next_cell_look, delay)
	next_guard_word = ambient_shifted(next_guard_word, delay)

/**
 * Looking in on someone asleep where they should not be: walks over, looks, tells them to move along. Only
 * words; nobody is shaken awake, moved or searched. Each sleeper is left alone for a good while after.
 */
/datum/ambient_activity/police_check
	name = "checking on a sleeper"
	duration_low = 10 SECONDS
	duration_high = 16 SECONDS
	var/datum/weakref/target_ref

/datum/ambient_activity/police_check/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = doer
	if(!istype(officer))
		return FALSE
	var/mob/living/carbon/human/sleeper
	for(var/mob/living/carbon/human/candidate in range(POLICE_CHECK_RANGE, doer))
		if(candidate == doer || istype(candidate, /mob/living/carbon/human/npc/ambient_npc/outpost/police) || candidate.stat == DEAD)
			continue
		if(!can_see(doer, candidate, POLICE_CHECK_RANGE + 1))
			continue
		if(candidate.stat != UNCONSCIOUS && !candidate.IsSleeping())
			continue
		if(LAZYACCESS(doer.reaction_cooldowns, "check [REF(candidate)]") > world.time || officer.life_keeps_off(get_turf(candidate)))
			continue
		sleeper = candidate
		break
	if(!sleeper)
		return FALSE
	var/turf/stand = doer.free_tile_beside(sleeper, 1, failed_spots)
	if(!stand)
		return FALSE
	target_ref = WEAKREF(sleeper)
	LAZYSET(doer.reaction_cooldowns, "check [REF(sleeper)]", world.time + 5 MINUTES)
	go_to(stand)
	set_duration()
	return TRUE

/datum/ambient_activity/police_check/arrive()
	var/mob/living/target = target_ref?.resolve()
	if(QDELETED(target))
		return
	if(!doer.buckled)
		doer.face_atom(target)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = doer
	officer.police_say(POLICE_LINE_MOVE_ALONG)

/datum/ambient_activity/police_check/act(seconds)
	var/mob/living/target = target_ref?.resolve()
	if(QDELETED(target) || target.stat == DEAD || get_dist(doer, target) > 3)
		return AMBIENT_STEP_DONE
	if(!doer.buckled)
		doer.face_atom(target)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/police_check/Destroy()
	target_ref = null
	return ..()

#undef POLICE_CHECK_RANGE
#undef POLICE_BEAT_DISTANCE_HIGH
#undef POLICE_BEAT_DISTANCE_LOW
#undef POLICE_BEAT_STOPS
