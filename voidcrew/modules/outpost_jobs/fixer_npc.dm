/**
 * # Outpost jobs: the fixers
 *
 * Owner: P1. One fixer at each trader outpost, an ambient outpost NPC on a role of its own (spec 2): Nan Tolliver at
 * Halcyon, Lot Brannigan at the Quartermain, Mister Quill at the Undertow.
 *
 * - Their day (2.2, 8): they keep to their outpost's bar (ambient_outpost_bar(): the Chowder Pot, the crew room's
 *   coffee machine, the Dregs). Most of the time they hold their seat with a real prop in hand (a book and a cup of
 *   tea, a clipboard, a deck of cards and a lit cigarette: /datum/ambient_activity/fixer_haunt); now and then they
 *   drink, chat or stretch their legs. With an officer close they watch the officer.
 * - Talk (2.3): an empty hand in reach, or within FIXER_TALK_RANGE across a table, opens the kingpin's style of radial.
 *   Each option is the player's own spoken line, and every option is checked again when picked (abuse J22). Offers are
 *   a lean-in only the asker reads; the job is handed over as a folded note (/obj/item/paper/fixer_note).
 * - Real people (4.7, J20): killable, cuffable, draggable and carryable, but while alive no closet, crate, bag or pod
 *   takes them (the traders' rule), and every ambient NPC already refuses teleports, polymorph and type changes. A
 *   counted crime against one burns the offender (fixer_network.dm). A dead one's place stays empty for the role's
 *   killed-slot time; then a stand-in comes, same type, a new name (2.6). A fixer drops nothing.
 * - The crowd cap (L24): fixers are never counted against AMBIENT_OUTPOST_TRANSIENT_CAP and never crowd out the
 *   regulars. Their role is settled and brought off the lift in a pass of its own, before the crowd's (job_goods.dm).
 */

/// Trait source: a living fixer can't be boxed
#define FIXER_ALIVE_TRAIT "outpost_fixer_alive"

/mob/living/carbon/human/npc/ambient_npc/outpost/fixer
	name = "stranger"
	desc = "Someone minding a seat that isn't theirs."
	random_name = FALSE
	random_gender = FALSE
	dialogue_file = FIXER_STRINGS_FIXER
	dialogue_section = FIXER_VOICE_STAND_IN
	speech_pace = 2
	death_cash_low = 0
	death_cash_high = 0
	outfit = /datum/outfit/outpost_fixer_quill
	routine = list(
		/datum/ambient_activity/fixer_haunt = 8,
		/datum/ambient_activity/drink/fixer = 2,
		/datum/ambient_activity/chat = 1,
		/datum/ambient_activity/wander = 1,
	)
	/// FIXER_VOICE_*: their section of FIXER_STRINGS_FIXER
	var/fixer_voice = FIXER_VOICE_STAND_IN
	/// How they sign a note
	var/note_initial = "X"
	/// They sit at their haunt (FALSE: they stand by it)
	var/haunt_sits = TRUE
	/// What they hold at their haunt, in turn (item types, made as locked props)
	var/list/haunt_props = list()
	/// What they do there now and then (emote text, said after their name)
	var/list/haunt_beats = list()
	/// What they drink when they drink
	var/drink_reagent = /datum/reagent/consumable/tonic
	/// Their own hair colour, or null for a random one
	var/hair_override
	/// Their own hairstyle (a hairstyle name), or null for a random one
	var/hairstyle_override
	/// They came after the fixer who was here died
	var/stand_in = FALSE

/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/Initialize(mapload, datum/human_npc_order/order)
	// Loaded before the ambient dialogue reader first looks for the file (it only knows AMBIENT_STRINGS_DIR)
	fixer_strings()
	if(!person)
		person = new_outpost_npc_person(gender)
		if(hairstyle_override)
			person.hairstyle = hairstyle_override
		if(hair_override)
			person.hair_color = hair_override
			person.facial_hair_color = hair_override
	. = ..()
	GLOB.fixer_network.fixers += src
	guard_alive(TRUE)
	RegisterSignal(src, COMSIG_LIVING_REVIVE, PROC_REF(on_revived))
	RegisterSignal(src, COMSIG_MOUSEDROP_ONTO, PROC_REF(block_drag_while_alive))

/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/Destroy()
	GLOB.fixer_network.fixers -= src
	return ..()

// Joining an outpost: the network hears its police for crimes against them
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/set_place(datum/ambient_place/new_place)
	. = ..()
	var/obj/structure/overmap/trader_outpost/outpost = get_outpost()
	if(outpost?.police)
		GLOB.fixer_network.watch_police(outpost.police)

/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/death(gibbed)
	var/was_alive = stat != DEAD
	var/obj/structure/overmap/trader_outpost/outpost = get_outpost()
	. = ..()
	if(!was_alive || stat != DEAD)
		return
	guard_alive(FALSE)
	GLOB.fixer_network.fixer_died(outpost)

/// Alive, no closet, crate, bag or pod takes them (the traders' rule, trade/trader_npc.dm); a body goes in a bag like anyone's
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/guard_alive(alive)
	if(alive)
		ADD_TRAIT(src, TRAIT_NO_CONTAINMENT, FIXER_ALIVE_TRAIT)
		ADD_TRAIT(src, TRAIT_NO_STORAGE_INSERT, FIXER_ALIVE_TRAIT)
	else
		REMOVE_TRAIT(src, TRAIT_NO_CONTAINMENT, FIXER_ALIVE_TRAIT)
		REMOVE_TRAIT(src, TRAIT_NO_STORAGE_INSERT, FIXER_ALIVE_TRAIT)

/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/on_revived(datum/source, full_heal_flags)
	SIGNAL_HANDLER
	guard_alive(TRUE)

/// Drag-dropping a living fixer onto a crate, bed or disposal unit does nothing; a body moves like any other
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/block_drag_while_alive(atom/over, mob/user)
	SIGNAL_HANDLER
	if(stat == DEAD)
		return NONE
	return COMPONENT_CANCEL_MOUSEDROP_ONTO

/// They came after a dead fixer: a new name, the stand-in's voice, the same seat (spec 2.6)
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/become_stand_in()
	if(stand_in)
		return
	stand_in = TRUE
	fixer_voice = FIXER_VOICE_STAND_IN
	dialogue_section = FIXER_VOICE_STAND_IN
	desc = initial(desc)
	var/new_name = generate_random_name(gender)
	fully_replace_character_name(real_name, new_name)
	note_initial = uppertext(copytext(new_name, 1, 2))

// =========================================================================
// THEIR DAY
// =========================================================================

/// Where they keep: their outpost's bar (the barkeep, or the crew room's coffee machine), or null
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/haunt_anchor()
	var/list/bar = ambient_outpost_bar(place)
	return length(bar) ? bar[1] : null

/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/pick_activity()
	return pick_anchored(routine, haunt_anchor(), list(/datum/ambient_activity/fixer_haunt, /datum/ambient_activity/drink/fixer, /datum/ambient_activity/wander))

/// Already in their seat when players come
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/settle_in()
	var/atom/anchor = haunt_anchor()
	if(anchor && settle_at(/datum/ambient_activity/fixer_haunt, anchor, AMBIENT_SETTLE_TRIES, anchor, AMBIENT_ACTIVITY_RANGE))
		return TRUE
	return ..()

/// A seat near `near` to keep: one with a table beside it and a bar stool both score, and the nearer the better
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/haunt_seat(atom/near, list/avoid)
	var/turf/center = get_turf(near) || get_turf(src)
	if(!center)
		return null
	var/obj/structure/chair/best
	var/best_score = -INFINITY
	for(var/obj/structure/chair/seat in range(AMBIENT_ACTIVITY_RANGE, center))
		if(!seat_usable(seat, avoid))
			continue
		var/score = rand(0, 10) / 10 - get_dist(center, seat) / 3
		if(table_beside(seat))
			score += 2
		if(istype(seat, /obj/structure/chair/stool/bar))
			score += 1
		if(score > best_score)
			best = seat
			best_score = score
	return best

/// They settle in at their haunt: the first prop in hand, and anything they light
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/haunt_begin()
	if(length(haunt_props))
		set_held(haunt_props[1])

/// A moment at their haunt: an officer close gets watched; otherwise one of their small habits
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/haunt_beat()
	var/mob/living/officer = GLOB.fixer_network.officer_near(src)
	if(officer)
		face_atom(officer)
		return
	if(length(haunt_props) > 1 && prob(30))
		set_held(pick(haunt_props))
	if(length(haunt_beats))
		manual_emote(pick(haunt_beats))

/// Up from their haunt: the prop goes away
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/haunt_end()
	set_held(null)

// =========================================================================
// TALK (spec 2.3)
// =========================================================================

/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/talked_to(mob/living/user)
	if(!buckled)
		face_atom(user)
	// show_radial_menu sleeps; the click chain doesn't wait
	INVOKE_ASYNC(src, PROC_REF(open_talk), user)

// An empty hand from across their table
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/ranged_attack_hand(mob/living/user, list/modifiers)
	if(!can_be_talked_to() || !talk_check(user))
		return FALSE
	if(!buckled)
		face_atom(user)
	INVOKE_ASYNC(src, PROC_REF(open_talk), user)
	return TRUE

/// Whether `user` can talk with them now: they are up and about, and `user` is awake, close and in sight
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/talk_check(mob/living/user)
	if(QDELETED(src) || QDELETED(user) || !isliving(user) || user.stat != CONSCIOUS || user.z != z)
		return FALSE
	if(!can_be_talked_to())
		return FALSE
	return get_dist(src, user) <= FIXER_TALK_RANGE && can_see(user, src, FIXER_TALK_RANGE)

/// The radial's options for `user` now, in order (FIXER_TALK_*), each with its icon
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/talk_options(mob/living/user)
	var/datum/fixer_network/network = GLOB.fixer_network
	var/datum/voidcrew_crew_record/crew = fixer_crew_of(user)
	var/obj/structure/overmap/trader_outpost/outpost = get_outpost()
	. = list()
	.[FIXER_TALK_WORK] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_talk")
	var/datum/mission/fixer_job/offered = (crew && outpost) ? network.live_offer(outpost, crew) : null
	if(offered)
		var/list/others = network.open_entries(outpost, crew) - offered
		if(length(others))
			.[FIXER_TALK_ELSE] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_next")
		.[FIXER_TALK_TAKE] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_yes")
	var/datum/mission/fixer_job/held = network.crew_job(crew)
	if(held)
		// A run to another fixer (a smuggle) is done when its case is handed over here: the hand-over is its deed
		var/obj/item/goods = held.goods_ref?.resolve()
		if(held.deed_done || (held.pay_outpost && held.pay_outpost == outpost && !QDELETED(goods) && (goods in user.held_items)))
			.[FIXER_TALK_DONE] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_buy")
		if(!held.deed_done)
			.[FIXER_TALK_DROP] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_no")

/// The talk radial for `user`. Sleeps.
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/open_talk(mob/living/user)
	if(!talk_check(user))
		return
	var/list/options = talk_options(user)
	var/choice = show_radial_menu(user, src, options, custom_check = CALLBACK(src, PROC_REF(talk_check), user), tooltips = TRUE)
	if(!choice || !talk_check(user))
		return
	// Things may have changed while the radial was open (abuse J22)
	if(!(choice in talk_options(user)))
		return
	talk(user, choice)

/// `user` says `option` (FIXER_TALK_*) and they answer. TRUE if it was one they know.
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/talk(mob/living/user, option)
	if(QDELETED(user) || stat != CONSCIOUS)
		return FALSE
	if(user.stat == CONSCIOUS)
		user.say(option, forced = "fixer talk")
	if(!buckled)
		face_atom(user)
	switch(option)
		if(FIXER_TALK_WORK)
			ask_work(user)
		if(FIXER_TALK_ELSE)
			ask_else(user)
		if(FIXER_TALK_TAKE)
			take_offer(user)
		if(FIXER_TALK_DONE)
			report_done(user)
		if(FIXER_TALK_DROP)
			drop_job(user)
		else
			return FALSE
	log_game("FIXER: [key_name(user)] told [src] \"[option]\" at [AREACOORD(src)]")
	return TRUE

/// Says their line for `key` out loud
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/answer(key)
	say_line(fixer_line(fixer_voice, key))

/// Leans in and tells `user` `line`: everyone sees it, only `user` reads it (bounty_outpost.dm's lean-in)
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/lean_in(mob/living/user, line)
	if(!line || stat != CONSCIOUS)
		return
	visible_message(span_notice("[src] leans in and says something quietly to [user]."), vision_distance = COMBAT_MESSAGE_RANGE, ignored_mobs = list(user))
	// xss-safe: the line is from FIXER_STRINGS_FIXER, its tokens are cut and html_encode()d by the job (offer_tokens())
	to_chat(user, span_notice("<b>[src]</b> says quietly, \"[line]\""))

/// Says the refusal `key` for `user`, watching the officer it is about
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/refuse(mob/living/user, key)
	if(key == FIXER_LINE_OFFICER)
		var/mob/living/officer = GLOB.fixer_network.officer_near(src)
		if(officer && !buckled)
			face_atom(officer)
	if(key == FIXER_LINE_FAILED)
		GLOB.fixer_network.failed_line_said(fixer_crew_of(user), get_outpost())
	answer(key)

/// "Got any work?": a refusal, or the offer of the first job on their slate `user`'s crew may take
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/ask_work(mob/living/user)
	var/datum/fixer_network/network = GLOB.fixer_network
	var/key = network.refusal(user, src)
	if(key)
		refuse(user, key)
		return FALSE
	var/obj/structure/overmap/trader_outpost/outpost = get_outpost()
	var/datum/voidcrew_crew_record/crew = fixer_crew_of(user)
	var/datum/mission/fixer_job/current = network.live_offer(outpost, crew)
	var/list/open = network.open_entries(outpost, crew)
	var/datum/mission/fixer_job/job = (current in open) ? current : open[1]
	offer(user, job, job == current)
	return TRUE

/// "What else?": the other job on their slate
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/ask_else(mob/living/user)
	var/datum/fixer_network/network = GLOB.fixer_network
	var/key = network.refusal(user, src)
	if(key)
		refuse(user, key)
		return FALSE
	var/obj/structure/overmap/trader_outpost/outpost = get_outpost()
	var/datum/voidcrew_crew_record/crew = fixer_crew_of(user)
	var/list/others = network.open_entries(outpost, crew) - network.live_offer(outpost, crew)
	if(!length(others))
		answer(FIXER_LINE_NOTHING)
		return FALSE
	offer(user, others[1], FALSE)
	return TRUE

/// Offers `job` to `user`'s crew: a lean-in with the job's words; `again` if it is the one already offered
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/offer(mob/living/user, datum/mission/fixer_job/job, again = FALSE)
	if(!job)
		return
	GLOB.fixer_network.make_offer(get_outpost(), fixer_crew_of(user), job)
	if(again)
		lean_in(user, fixer_line(fixer_voice, FIXER_LINE_REPEAT))
	lean_in(user, fixer_line(fixer_voice, "offer_[job.job_kind]", job.offer_tokens()))

/// "I'll take it.": the job offered to `user`'s crew starts, and they slide over the note
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/take_offer(mob/living/user)
	var/result = GLOB.fixer_network.accept(user, src)
	if(istext(result))
		refuse(user, result)
		return null
	var/datum/mission/fixer_job/job = result
	if(!istype(job))
		return null
	lean_in(user, fixer_line(fixer_voice, FIXER_LINE_TAKEN))
	hand_note(user, job)
	return job

/// The folded note for `job`, put in `user`'s hand (spec 2.5, 6.3)
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/hand_note(mob/living/user, datum/mission/fixer_job/job)
	var/obj/item/paper/fixer_note/note = new(get_turf(user), fixer_note_text(job, note_initial))
	visible_message(span_notice("[src] slides [user] a folded note."), vision_distance = COMBAT_MESSAGE_RANGE)
	if(!user.put_in_hands(note))
		note.forceMove(get_turf(user))
	return note

/// "It's done.": they take the goods if there are any and pay the ship (spec 4.5), or say why not
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/report_done(mob/living/user)
	var/datum/fixer_network/network = GLOB.fixer_network
	var/datum/mission/fixer_job/job = network.crew_job(fixer_crew_of(user))
	if(!job || (!job.deed_done && !job.pay_outpost))
		answer(FIXER_LINE_NOTHING)
		return 0
	if(!job.on_roster(user.mind))
		answer(FIXER_LINE_NOT_YOURS)
		return 0
	var/obj/structure/overmap/trader_outpost/outpost = get_outpost()
	if(network.crew_wanted_at(user, outpost))
		answer(FIXER_LINE_WANTED)
		return 0
	if(network.officer_near(src))
		refuse(user, FIXER_LINE_OFFICER)
		return 0
	if(job.job_kind == FIXER_JOB_SMUGGLE)
		look_in(user, job)
	var/key = job.can_pay(user, src)
	if(key)
		answer(key)
		return 0
	var/noise = job.noise()
	var/paid = job.pay_out(user, src)
	if(paid <= 0)
		return 0
	// The job's receipt (notify_completed()) is the one "Paid to the ship" line
	answer(noise <= 0 ? FIXER_LINE_PAY_CLEAN : (noise >= 3 ? FIXER_LINE_PAY_LOUD : FIXER_LINE_PAY_SOME))
	return paid

/// The receiving fixer opens the case `user` holds a crack and looks inside before saying a word (spec 8)
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/look_in(mob/living/user, datum/mission/fixer_job/job)
	var/obj/item/goods = job.goods_ref?.resolve()
	if(QDELETED(goods) || !(goods in user.held_items))
		return
	visible_message(span_notice("[src] opens [goods] a crack and looks inside."), vision_distance = COMBAT_MESSAGE_RANGE)

/// "Forget it.": the job is dropped, and they are not pleased
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/proc/drop_job(mob/living/user)
	var/datum/voidcrew_crew_record/crew = fixer_crew_of(user)
	var/datum/mission/fixer_job/job = GLOB.fixer_network.crew_job(crew)
	if(!job || job.deed_done)
		answer(FIXER_LINE_NOTHING)
		return FALSE
	if(!job.on_roster(user.mind))
		answer(FIXER_LINE_NOT_YOURS)
		return FALSE
	var/obj/structure/overmap/trader_outpost/giver = job.giver_outpost
	job.fail_reason = FIXER_FAIL_DROPPED
	job.fail()
	answer(FIXER_LINE_FAILED)
	if(giver == get_outpost())
		GLOB.fixer_network.failed_line_said(crew, giver)
	return TRUE

// =========================================================================
// THE HAUNT
// =========================================================================

/// At their seat (or by their counter) with a prop in hand, a small habit now and then, a word now and again
/datum/ambient_activity/fixer_haunt
	name = "keeping their seat"
	accepts_company = TRUE
	duration_low = 3 MINUTES
	duration_high = 6 MINUTES
	var/datum/weakref/seat_ref
	/// world.time of their next small habit
	var/next_beat = 0

/datum/ambient_activity/fixer_haunt/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer = doer
	if(!istype(fixer))
		return FALSE
	var/atom/bar = anchor()
	var/obj/structure/chair/seat = fixer.haunt_sits ? fixer.haunt_seat(bar || fixer, failed_spots) : null
	if(seat)
		seat_ref = WEAKREF(seat)
		go_to(get_turf(seat))
	else
		var/turf/stand = bar ? fixer.free_tile_beside(bar, 1, failed_spots) : null
		stand ||= fixer.find_loiter_spot(bar || fixer, AMBIENT_LOITER_RANGE, failed_spots)
		if(!stand)
			return FALSE
		go_to(stand)
	set_duration()
	next_beat = world.time + rand(10 SECONDS, 25 SECONDS)
	next_line = world.time + rand(40 SECONDS, 90 SECONDS)
	return TRUE

/datum/ambient_activity/fixer_haunt/arrive()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer = doer
	var/obj/structure/chair/seat = seat_ref?.resolve()
	if(seat && !doer.sit_on(seat))
		seat_ref = null
	var/atom/bar = anchor()
	if(!seat_ref && bar && !doer.buckled)
		doer.face_atom(bar)
	fixer.haunt_begin()

/datum/ambient_activity/fixer_haunt/act(seconds)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer = doer
	if(world.time >= next_beat)
		next_beat = world.time + rand(20 SECONDS, 50 SECONDS)
		fixer.haunt_beat()
	chatter(low = 60 SECONDS, high = 2 MINUTES)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/fixer_haunt/finish()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer = doer
	if(istype(fixer) && !QDELETED(fixer))
		fixer.haunt_end()
	return ..()

/datum/ambient_activity/fixer_haunt/spot_unreachable()
	. = ..()
	seat_ref = null

/datum/ambient_activity/fixer_haunt/shift_times(delay)
	. = ..()
	next_beat = ambient_shifted(next_beat, delay)

/// A drink at their bar: what they always have
/datum/ambient_activity/drink/fixer
	name = "having a drink"

/datum/ambient_activity/drink/fixer/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer = doer
	if(istype(fixer))
		reagent_type = fixer.drink_reagent
	return ..()

// =========================================================================
// THE NOTE (spec 2.5, 6.3)
// =========================================================================

/// A real paper that holds no state: losing, burning or forging it changes nothing
/obj/item/paper/fixer_note
	name = "folded note"
	desc = "A scrap of paper folded small."
	can_become_message_in_bottle = FALSE

/obj/item/paper/fixer_note/Initialize(mapload, text)
	if(istext(text))
		default_raw_text = text
	return ..()

/**
 * The note's text for `job`: up to FIXER_NOTE_LINES of the job's lines, then the pay and `initial`. The job's lines
 * come already cut and html_encode()d (note_lines()), so they are used as they are: cutting or encoding them again
 * would break an entity or show "&amp;".
 */
/proc/fixer_note_text(datum/mission/fixer_job/job, initial)
	var/list/out = list()
	var/list/lines = job?.note_lines()
	for(var/line in lines)
		if(length(out) >= FIXER_NOTE_LINES)
			break
		if(istext(line) && length(line))
			out += line // xss-safe: note_lines() are cut and html_encode()d by the job
	// The quote the job was bound with (base x zone, the higher of both ends for a run); the table if it is unbound
	var/list/zone_pay = FIXER_ZONE_PAY
	var/pay = job?.bind_target() ? job.value : round((job?.base_pay || 0) * zone_pay[fixer_outpost_band(job?.job_outpost)], 10)
	out += "[fixer_credits_text(pay)] cr. - [html_encode(initial)]"
	return jointext(out, "<br>")

// =========================================================================
// THE THREE
// =========================================================================

/// Nan Tolliver, Waystation Halcyon: the corner seat at the Chowder Pot
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/nan
	name = "Nan Tolliver"
	desc = "An old woman with a paperback and a cup of tea."
	gender = FEMALE
	dialogue_section = FIXER_VOICE_NAN
	fixer_voice = FIXER_VOICE_NAN
	note_initial = "N"
	outfit = /datum/outfit/outpost_fixer_nan
	hair_override = "#c9c5bd"
	hairstyle_override = "Bun Head"
	drink_reagent = /datum/reagent/consumable/tea
	haunt_props = list(/obj/item/book, /obj/item/reagent_containers/cup/glass/mug/tea)
	haunt_beats = list("turns a page.", "sips her tea.", "looks over the top of her book.", "marks her page with a finger.")

/// Lot Brannigan, Quartermain Depot: the crew room's coffee counter, on his feet
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/lot
	name = "Lot Brannigan"
	desc = "A man with a clipboard and a pen behind his ear."
	gender = MALE
	dialogue_section = FIXER_VOICE_LOT
	fixer_voice = FIXER_VOICE_LOT
	note_initial = "L"
	outfit = /datum/outfit/outpost_fixer_lot
	haunt_sits = FALSE
	drink_reagent = /datum/reagent/consumable/coffee
	haunt_props = list(/obj/item/clipboard)
	haunt_beats = list("ticks something off on his clipboard.", "flips a page on his clipboard.", "taps his pen against the clipboard.", "counts something under his breath.")

/// Mister Quill, the Undertow: the end stool at the Dregs
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/quill
	name = "Mister Quill"
	desc = "A thin man in a dark suit, dealing himself a hand of cards."
	gender = MALE
	dialogue_section = FIXER_VOICE_QUILL
	fixer_voice = FIXER_VOICE_QUILL
	note_initial = "Q"
	outfit = /datum/outfit/outpost_fixer_quill
	hair_override = "#1c1a19"
	hairstyle_override = "Cut Hair"
	drink_reagent = /datum/reagent/consumable/tonic
	haunt_props = list(/obj/item/toy/cards/deck)
	haunt_beats = list("deals himself a hand.", "gathers the cards and squares the deck.", "turns over a card.", "watches the door.")

/// He smokes at his stool: a real cigarette, lit, on his lip (it burns down and drops like any other)
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/quill/haunt_begin()
	. = ..()
	if(get_item_by_slot(ITEM_SLOT_MASK))
		return
	var/obj/item/cigarette/smoke = new(src)
	if(!equip_to_slot_if_possible(smoke, ITEM_SLOT_MASK, disable_warning = TRUE))
		qdel(smoke)
		return
	npc_lock_item(smoke)
	smoke.light()

// =========================================================================
// THEIR ROLES
// =========================================================================

/datum/ambient_outpost_role/fixer
	name = "fixer"
	max_count = 1
	gap_low = 20 SECONDS
	gap_high = 40 SECONDS

/datum/ambient_outpost_role/fixer/settle(datum/ambient_place/outpost/place)
	. = ..()
	fixer_came(.)

/datum/ambient_outpost_role/fixer/arrive(datum/ambient_place/outpost/place, turf/where)
	. = ..()
	fixer_came(.)

/// A fixer has come: after a dead one, a stand-in
/datum/ambient_outpost_role/fixer/proc/fixer_came(mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer)
	if(!istype(fixer))
		return
	var/obj/structure/overmap/trader_outpost/outpost = fixer.get_outpost()
	if(outpost && GLOB.fixer_network.lost_originals[REF(outpost)])
		fixer.become_stand_in()

/datum/ambient_outpost_role/fixer/nan
	name = "fixer (Halcyon)"
	npc_type = /mob/living/carbon/human/npc/ambient_npc/outpost/fixer/nan
	outpost_types = list(/obj/structure/overmap/trader_outpost/general)

/datum/ambient_outpost_role/fixer/lot
	name = "fixer (Quartermain)"
	npc_type = /mob/living/carbon/human/npc/ambient_npc/outpost/fixer/lot
	outpost_types = list(/obj/structure/overmap/trader_outpost/outfitter)

/datum/ambient_outpost_role/fixer/quill
	name = "fixer (Undertow)"
	npc_type = /mob/living/carbon/human/npc/ambient_npc/outpost/fixer/quill
	outpost_types = list(/obj/structure/overmap/trader_outpost/black_market)

// =========================================================================
// THE CROWD CAP (L24): see job_goods.dm, which holds the one rule for fixers and job people
// =========================================================================

/// This place's living fixers
/datum/ambient_place/outpost/proc/living_fixers()
	. = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer in npcs)
		if(!QDELETED(fixer) && fixer.stat != DEAD && !fixer.fading)
			. += fixer

#undef FIXER_ALIVE_TRAIT
