/**
 * # Outpost jobs: assassination
 *
 * Owner: P6. Spec 6.4: a visitor the job brings, and proof that he is dead.
 *
 * The mark is an ambient outpost NPC with no role (his death empties no slot), set in the outpost's
 * ambient place by fixer_job_npc_setup(), so hurting him is a crime against a townsperson and killing
 * him is KILL_CIVILIAN, by the police's ordinary rules. He steps off the lift and comes through the
 * checkpoint, then loops until his shuttle: a counter (the customer's shop visit, with the trader's
 * own answer), the bar (he orders, sits with a real drink, talks to whoever is beside him), and every
 * few minutes a call on his headset at a quiet tile with his back to the room. At the clock he walks
 * to the lift and is gone.
 *
 * A gun drawn at him or a blow he lives through sends him running for the nearest officer or
 * checkpoint guard, shouting, and he stays by them a minute. He buys his own drinks and takes none
 * from strangers (abuse J6).
 *
 * The deed is his death, anywhere. The hands rule input is the last player to hit him in the
 * FIXER_HAND_WINDOW before he died (abuse J4): the death is settled a tick later, so a melee killing
 * blow (reported after its damage) is counted. His proof is the one item he carries that is not gear:
 * it falls at his feet when he dies, once. Revived, he carries nothing and leaves (abuse J39).
 */

/// How far the mark looks for a gun drawn at him
#define MARK_GUN_RANGE 5
/// How often he looks
#define MARK_GUN_CHECK_EVERY (2 SECONDS)
/// How long he stays by the officer he ran to
#define MARK_FLEE_STAY (60 SECONDS)
/// Longest a run for help lasts, there and back
#define MARK_FLEE_MAX (2 MINUTES)
/// How far he looks for an officer or a guard to run to
#define MARK_HELPER_RANGE 24
/// How far he looks for a seat near the bar
#define MARK_BAR_RANGE 8
/// Most rounds he has at the bar on one visit
#define MARK_BAR_ROUNDS 3
/// The mark's section of FIXER_STRINGS_HIT
#define MARK_SECTION "mark"

// =========================================================================
// THE JOB
// =========================================================================

/datum/mission/fixer_job/hit
	job_kind = FIXER_JOB_HIT
	base_pay = FIXER_PAY_HIT
	duration = FIXER_TIME_HIT
	trust_tier = FIXER_TRUST_TIER1
	slate_weight = FIXER_WEIGHT_HIT
	goods_type = /obj/item/mission_recovery/fixer_goods/proof
	/// The mark's name, rolled with the offer so the fixer can say it before he arrives
	var/mark_name
	/// His outfit (a /datum/outfit/fixer_mark subtype), rolled with the offer
	var/mark_outfit
	/// The mark, once staged
	var/datum/weakref/mark_ref

/datum/mission/fixer_job/hit/Destroy()
	mark_ref = null
	return ..()

/// Rolls who the mark is, once: a man's name and one of the looks a crew is told to watch for
/datum/mission/fixer_job/hit/proc/roll_mark()
	if(!mark_name)
		mark_name = generate_random_name(MALE)
	if(!ispath(mark_outfit, /datum/outfit/fixer_mark))
		mark_outfit = pick(subtypesof(/datum/outfit/fixer_mark))

/// The mark, if he is still there
/datum/mission/fixer_job/hit/proc/get_mark()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = mark_ref?.resolve()
	return QDELETED(mark) ? null : mark

/// world.time his shuttle leaves: the deed's deadline once the job runs, or what it would be if taken now
/datum/mission/fixer_job/hit/proc/clock_time()
	if(active && time_started)
		return time_started + duration
	return world.time + duration

/// The words for what he wears, before cutting
/datum/mission/fixer_job/hit/proc/look_words()
	var/datum/outfit/fixer_mark/kit = mark_outfit
	return ispath(kit, /datum/outfit/fixer_mark) ? initial(kit.look_words) : "Travelling clothes"

/datum/mission/fixer_job/hit/offer_tokens()
	roll_mark()
	var/obj/structure/overmap/trader_outpost/outpost = job_outpost
	return list(
		FIXER_TOKEN_NAME = html_encode(fixer_hit_cut(mark_name, FIXER_BOUND_NAME)),
		FIXER_TOKEN_LOOK = html_encode(fixer_hit_cut(look_words(), FIXER_BOUND_LOOK)),
		FIXER_TOKEN_CLOCK = station_time_timestamp("hh:mm", clock_time()),
		FIXER_TOKEN_PLACE = html_encode(fixer_hit_cut(outpost?.name || "here", FIXER_BOUND_PLACE)),
	)

/datum/mission/fixer_job/hit/note_lines()
	roll_mark()
	return list(
		html_encode(fixer_hit_cut(mark_name, FIXER_BOUND_NOTE_LINE)),
		html_encode(fixer_hit_cut(look_words(), FIXER_BOUND_NOTE_LINE)),
		"The [station_time_timestamp("hh:mm", clock_time())] shuttle.",
	)

/**
 * Brings the mark: off the lift in the lobby (he comes through the checkpoint like any visitor), or
 * at a free spot by the lift if the lift is taken. FALSE if there is nowhere for him.
 */
/datum/mission/fixer_job/hit/stage()
	var/obj/structure/overmap/trader_outpost/outpost = job_outpost
	if(QDELETED(outpost))
		return FALSE
	var/turf/where = SSambient_npcs.lift_arrival_turf(outpost)
	if(!where)
		var/list/spots = fixer_job_spot(outpost, FIXER_SPOT_ARRIVE)
		where = length(spots) ? spots[1] : null
	if(!where)
		return FALSE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = make_mark(where)
	if(!mark)
		return FALSE
	mark.fade_in()
	// Off the lift on the lobby side of the weapons checkpoint: through it first
	ambient_cross_checkpoint_on_arrival(mark, outpost)
	return TRUE

/**
 * Makes the mark at `where`: who the offer said, set up as a job person at the job's outpost, his
 * proof in his pocket. Returns him, or null. Tests call this with the spot already chosen.
 */
/datum/mission/fixer_job/hit/proc/make_mark(turf/where)
	roll_mark()
	var/obj/structure/overmap/trader_outpost/outpost = job_outpost
	if(QDELETED(outpost) || !get_turf(where))
		return null
	var/list/identity = list("name" = mark_name, "gender" = MALE, "outfit" = mark_outfit)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = ambient_build_npc(/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark, where, null, identity)
	if(QDELETED(mark))
		return null
	mark_ref = WEAKREF(mark)
	mark.job_ref = WEAKREF(src)
	mark.leave_at = clock_time()
	fixer_job_npc_setup(mark, src)
	// set_place() is the setup's job; a hit on him is only a crime through his place, so make sure of it
	if(!mark.place)
		mark.set_place(SSambient_npcs.outpost_place(outpost))
	var/obj/item/mission_recovery/fixer_goods/proof/proof = new(mark)
	proof.name = "[mark.real_name]'s papers"
	if(!mark.equip_to_slot_if_possible(proof, ITEM_SLOT_LPOCKET, disable_warning = TRUE) && !mark.equip_to_slot_if_possible(proof, ITEM_SLOT_RPOCKET, disable_warning = TRUE))
		proof.forceMove(mark)
	proof.bind_job(src)
	goods_ref ||= WEAKREF(proof)
	return mark

/datum/mission/fixer_job/hit/on_deadline()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = get_mark()
	if(mark && mark.stat != DEAD)
		mark.catch_shuttle()
	return ..()

/// The mark walks off in the world (a body stays for the outpost's morgue crew); the rest goes
/datum/mission/fixer_job/hit/unstage()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = get_mark()
	if(mark)
		job_atoms -= WEAKREF(mark)
		mark.job_ref = null
		if(mark.stat != DEAD)
			mark.catch_shuttle()
	mark_ref = null
	return ..()

/// `text` cut to `bound` characters, with an ellipsis when it was longer
/proc/fixer_hit_cut(text, bound)
	if(!istext(text))
		return ""
	if(length_char(text) <= bound)
		return text
	return "[copytext_char(text, 1, bound)]…"

// =========================================================================
// THE PROOF
// =========================================================================

/// Proof of a hit: the mark's travel wallet and papers. Named for him when he is made.
/obj/item/mission_recovery/fixer_goods/proof
	name = "travel papers"
	desc = "A worn travel wallet."
	icon = 'icons/obj/storage/storage.dmi'
	icon_state = "wallet"
	inhand_icon_state = null
	w_class = WEIGHT_CLASS_TINY

// =========================================================================
// THE MARK
// =========================================================================

/// The mark: a visitor off a shuttle with a few hours at the outpost
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark
	desc = "Someone off one of the shuttles, here for the day."
	gender = MALE
	random_gender = FALSE
	dialogue_file = FIXER_STRINGS_HIT
	dialogue_section = MARK_SECTION
	outfit_choices = null
	outfit = /datum/outfit/fixer_mark
	// He keeps the base's few loose credits (every outpost NPC drops a little, voidcrew_ambient_outposts.dm checks it); his kit is locked
	routine = list(
		/datum/ambient_activity/idle = 2,
		/datum/ambient_activity/wander = 2,
		/datum/ambient_activity/sit = 1,
		/datum/ambient_activity/chat = 2,
	)
	/// His job
	var/datum/weakref/job_ref
	/// world.time his shuttle leaves: he walks to the lift then. Real time, never moved on while he holds still.
	var/leave_at = 0
	/// world.time of his next call
	var/next_call_at = 0
	/// Counters left to visit
	var/visits_left = 1
	/// Rounds he has had at the bar
	var/bar_rounds = 0
	/// He ordered at the bar and has a drink coming: next, a seat with it
	var/drink_due = FALSE
	/// The bar: list(where, barkeep or null, its section of AMBIENT_STRINGS_PATRONS), or null for none
	var/list/bar
	/// Weakref to the last player who hit him, and when
	var/datum/weakref/last_hit_ref
	var/last_hit_at = 0
	/// He has died once: the deed is reported for that death only
	var/died_once = FALSE
	/// That death has gone to the job
	var/death_settled = FALSE
	/// world.time he next looks for a gun drawn at him
	var/next_gun_check = 0

/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/Initialize(mapload, datum/human_npc_order/order)
	// His lines are in this feature's strings, which ambient_dialogue_lines() only finds once they are loaded
	fixer_hit_load_strings()
	. = ..()
	next_call_at = world.time + rand(FIXER_MARK_CALL_LOW, FIXER_MARK_CALL_HIGH)
	visits_left = rand(1, 2)

/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/Destroy()
	// Gone in the same tick he died (a gib): the death still counts
	if(died_once && !death_settled)
		settle_death()
	var/datum/mission/fixer_job/hit/job = live_job()
	job_ref = null
	last_hit_ref = null
	bar = null
	// Gone alive before the deed (walked off, deleted): the job has lost its man
	if(job && !died_once && !job.deed_done)
		job.fail_reason ||= FIXER_FAIL_LOST
		job.fail()
	return ..()

/// His job, while it runs
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/proc/live_job()
	var/datum/mission/fixer_job/hit/job = job_ref?.resolve()
	if(QDELETED(job) || job.failed || job.completed)
		return null
	return job

/// Time to go: to the lift, now
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/proc/catch_shuttle()
	if(stat == DEAD || fading || istype(activity, /datum/ambient_activity/leave))
		return
	if(stat == CONSCIOUS && prob(50))
		speak_context(AMBIENT_LINE_LEAVE, null, force = TRUE)
	start_activity(new /datum/ambient_activity/leave(src))

// ----- his day -----

/**
 * The loop until his shuttle: a call when one is due, a seat with the drink he just ordered, then a
 * counter, a round at the bar or a stand about. At the clock, or with no job left, the lift.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/pick_activity()
	if(!live_job() || died_once || world.time >= leave_at)
		catch_shuttle()
		return activity
	if(world.time >= next_call_at)
		if(start_activity(new /datum/ambient_activity/mark_call(src)))
			return activity
		next_call_at = world.time + 30 SECONDS
	var/atom/bar_spot = get_bar()
	if(drink_due)
		drink_due = FALSE
		if(bar_spot && start_activity(new /datum/ambient_activity/drink/mark_round(src, bar_spot)))
			return activity
	var/list/choices = list("routine" = 2)
	if(visits_left > 0)
		choices["counter"] = 3
	if(bar_spot && bar_rounds < MARK_BAR_ROUNDS)
		choices["bar"] = 3
	while(length(choices))
		var/choice = pick_weight(choices)
		choices -= choice
		switch(choice)
			if("counter")
				visits_left--
				if(start_activity(new /datum/ambient_activity/shop_visit(src)))
					return activity
			if("bar")
				bar_rounds++
				if(start_activity(new /datum/ambient_activity/mark_order(src, bar_spot)))
					return activity
			if("routine")
				return ..()
	return ..()

/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/shift_times(delay)
	. = ..()
	// His shuttle keeps its time; his calls come on his own clock
	next_call_at = ambient_shifted(next_call_at, delay)
	next_gun_check = ambient_shifted(next_gun_check, delay)
	last_hit_at = ambient_shifted(last_hit_at, delay)

/// His outpost's bar (ambient_outpost_bar()), found once and kept while it stands
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/proc/get_bar()
	var/atom/where = length(bar) ? bar[1] : null
	var/mob/living/bar_person = where
	if(QDELETED(where) || (istype(bar_person) && bar_person.stat == DEAD))
		bar = ambient_outpost_bar(place)
		where = length(bar) ? bar[1] : null
	return QDELETED(where) ? null : where

/// The bar's barkeep, if it has one and they are still there
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/proc/get_barkeep()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/barkeep = length(bar) >= 2 ? bar[2] : null
	return (QDELETED(barkeep) || barkeep.stat == DEAD) ? null : barkeep

/// What the bar pours him: coffee at the crew room, a short at the Dregs, a beer anywhere else
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/proc/bar_pour()
	var/section = length(bar) >= 3 ? bar[3] : null
	switch(section)
		if("bar_crew_room") // PATRON_BAR_CREW_ROOM
			return /datum/reagent/consumable/coffee
		if("bar_dregs") // PATRON_BAR_DREGS
			return pick(/datum/reagent/consumable/ethanol/whiskey, /datum/reagent/consumable/ethanol/beer)
	return /datum/reagent/consumable/ethanol/beer

/// A word with whoever is right beside him: one of his exchanges, or a chat line and their reply. TRUE if he spoke.
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/proc/talk_to_neighbour()
	if(world.time < next_line_at || (place && world.time < place.next_line_at))
		return FALSE
	for(var/mob/living/carbon/human/npc/ambient_npc/other in range(1, src))
		if(other == src || !other.can_act() || other.client)
			continue
		var/list/conversation = pick_conversation()
		if(length(conversation) >= 2 && prob(50))
			say_line(fill_line(conversation[1], other))
			other.reply_to(src, AMBIENT_LINE_REPLY, conversation[2])
		else if(speak_context(AMBIENT_LINE_CHAT, other, force = TRUE))
			other.reply_to(src)
		else
			return FALSE
		if(!buckled)
			face_atom(other)
		return TRUE
	return FALSE

/// A line into his headset: low, so only someone right by him makes it out
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/proc/call_line()
	if(stat != CONSCIOUS || fading)
		return FALSE
	var/list/lines = ambient_dialogue_lines(dialogue_file, dialogue_section, "call")
	if(!length(lines))
		return FALSE
	var/line = pick(lines)
	if(!istext(line))
		return FALSE
	INVOKE_ASYNC(src, TYPE_PROC_REF(/mob, whisper), fill_line(line))
	return TRUE

/**
 * A quiet tile for a call: on the loiter floor, as far from anyone as can be found nearby, a wall at
 * his back the better. Null if none.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/proc/quiet_spot()
	var/datum/ambient_place/outpost/outpost_place = place
	var/turf/here = get_turf(src)
	if(!istype(outpost_place) || !here)
		return null
	var/list/floor = outpost_place.get_loiter_floor()
	if(!length(floor))
		return null
	var/turf/best
	var/best_score = -INFINITY
	for(var/attempt in 1 to 30)
		var/turf/tile = pick(floor)
		if(tile.z != here.z || get_dist(tile, here) > 15 || !loiter_spot_ok(tile))
			continue
		var/alone = 8
		for(var/mob/living/other in range(7, tile))
			if(other != src && other.stat != DEAD)
				alone = min(alone, get_dist(other, tile))
		var/score = alone + (ambient_backed_by_wall_or_table(tile) ? 2 : 0) - get_dist(tile, here) / 6
		if(score > best_score)
			best = tile
			best_score = score
	return best

/// Turns his back to the room: faces a wall or something solid beside him, if there is one
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/proc/face_the_wall()
	if(buckled)
		return
	for(var/cdir in shuffle(GLOB.cardinals.Copy()))
		var/turf/next = get_step(src, cdir)
		if(!next)
			continue
		if(!isopenturf(next))
			setDir(cdir)
			return
		for(var/obj/thing in next)
			if(thing.density && thing.anchored)
				setDir(cdir)
				return

// ----- what he does about trouble -----

/**
 * His hands rule input: the last player who hit him, while within FIXER_HAND_WINDOW. Noted on every
 * blow (relay_attackers), before the base hands it to his place and reacts.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/on_attacked(datum/source, atom/attacker, attack_flags)
	SIGNAL_HANDLER
	if((attack_flags & (ATTACKER_DAMAGING_ATTACK | ATTACKER_STAMINA_ATTACK)) && !died_once)
		note_hit(attacker)
	return ..()

/// `attacker` hit him: remembered if a player did it
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/proc/note_hit(atom/attacker)
	var/mob/living/hitter = attacker
	if(!isliving(hitter) || !hitter.mind || hitter == src)
		return
	last_hit_ref = WEAKREF(hitter)
	last_hit_at = world.time

/// The player whose hand the death is: the last to hit him within FIXER_HAND_WINDOW, or null
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/proc/death_hand()
	if(!last_hit_at || world.time - last_hit_at > FIXER_HAND_WINDOW)
		return null
	var/mob/living/hitter = last_hit_ref?.resolve()
	return QDELETED(hitter) ? null : hitter

/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(!was_alive || stat != DEAD || died_once)
		return
	died_once = TRUE
	// A tick later: a melee killing blow reports its hitter after the damage that killed him
	addtimer(CALLBACK(src, PROC_REF(settle_death)), 1, TIMER_DELETE_ME)

/// His (first) death goes to the job as the deed, with the hand that did it. Once.
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/proc/settle_death()
	if(death_settled || !died_once)
		return
	death_settled = TRUE
	var/datum/mission/fixer_job/hit/job = live_job()
	if(!job || job.deed_done)
		return
	job.mark_deed(death_hand())

/// Hit and still up: he shouts and runs for help (never for the lift)
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/react_attacked(atom/attacker)
	if(stat != CONSCIOUS || fading || !reaction_ready("attacked", 10 SECONDS))
		return
	run_for_help(attacker, AMBIENT_LINE_ATTACKED)

/// A fight near him: he gets himself beside an officer, and stays
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/react_violence(mob/living/offender)
	if(stat != CONSCIOUS || fading || !reaction_ready("violence"))
		return
	run_for_help(offender, AMBIENT_LINE_VIOLENCE)

/// Off for the nearest officer or guard, with a shout of `context`. TRUE if he went.
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/proc/run_for_help(atom/threat, context)
	if(istype(activity, /datum/ambient_activity/mark_flee))
		return FALSE
	if(!start_activity(new /datum/ambient_activity/mark_flee(src, threat)))
		return FALSE
	speak_context(context, threat, force = TRUE)
	return TRUE

/// The nearest awake officer or checkpoint guard at his outpost, or null
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/proc/find_helper()
	var/obj/structure/overmap/trader_outpost/outpost = get_outpost()
	var/turf/here = get_turf(src)
	if(!outpost || !here)
		return null
	var/list/helpers = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in outpost.police?.officers)
		helpers += officer
	for(var/checkpoint_id in outpost.checkpoints)
		var/datum/outpost_checkpoint/post = outpost.checkpoints[checkpoint_id]
		if(!QDELETED(post?.guard))
			helpers += post.guard
	var/mob/living/best
	var/best_distance = INFINITY
	for(var/mob/living/helper in helpers)
		if(QDELETED(helper) || helper.stat != CONSCIOUS)
			continue
		var/turf/there = get_turf(helper)
		if(!there || there.z != here.z)
			continue
		var/distance = get_dist(here, there)
		if(distance <= MARK_HELPER_RANGE && distance < best_distance)
			best = helper
			best_distance = distance
	return best

// Each step of what he is doing, he keeps an eye out
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/activity_step(seconds)
	. = ..()
	if(world.time >= next_gun_check)
		next_gun_check = world.time + MARK_GUN_CHECK_EVERY
		watch_for_guns()

/// A player close by with a gun out and turned his way: he runs for help. TRUE if he went.
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/proc/watch_for_guns()
	if(!can_act() || istype(activity, /datum/ambient_activity/leave) || istype(activity, /datum/ambient_activity/mark_flee))
		return FALSE
	for(var/mob/living/visitor in oview(MARK_GUN_RANGE, src))
		if(!visitor.mind || visitor.stat != CONSCIOUS || !outpost_weapon_drawn(visitor))
			continue
		// Pointed his way, or close enough that it doesn't matter
		if(get_dist(visitor, src) > 2 && !(get_dir(visitor, src) & visitor.dir))
			continue
		if(!reaction_ready("gun", 90 SECONDS))
			return FALSE
		return run_for_help(visitor, "gun")
	return FALSE

// ----- drinks -----

/**
 * A drink or a bite handed to him is turned down: he buys his own (abuse J6). Combat mode is the
 * usual attack chain (a splash, a force-feed), as for anyone.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!user.combat_mode && can_act() && (istype(tool, /obj/item/reagent_containers/cup) || istype(tool, /obj/item/food)))
		refuse_handout(user)
		return ITEM_INTERACT_BLOCKING
	return ..()

/// "I buy my own, thanks."
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/proc/refuse_handout(mob/living/user)
	if(!buckled)
		face_atom(user)
	if(reaction_ready("handed", 10 SECONDS))
		speak_context("refuse", user, force = TRUE)

/// Loads FIXER_STRINGS_HIT into the string cache, where the ambient dialogue reads it
/proc/fixer_hit_load_strings()
	if(!(FIXER_STRINGS_HIT in GLOB.string_cache) && fexists("[FIXER_STRINGS_DIR]/[FIXER_STRINGS_HIT]"))
		load_strings_file(FIXER_STRINGS_HIT, FIXER_STRINGS_DIR)

// =========================================================================
// HIS ACTIVITIES
// =========================================================================

/**
 * A call: to a quiet tile away from people, his back to the room, a hand to his headset, and
 * FIXER_MARK_CALL_TIME_LOW to _HIGH of low talk. This is when he is alone.
 */
/datum/ambient_activity/mark_call
	name = "on a call"
	accepts_company = FALSE

/datum/ambient_activity/mark_call/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = doer
	if(!istype(mark))
		return FALSE
	var/turf/spot = mark.quiet_spot()
	if(!spot)
		return FALSE
	go_to(spot)
	return TRUE

/datum/ambient_activity/mark_call/arrive()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = doer
	ends_at = world.time + rand(FIXER_MARK_CALL_TIME_LOW, FIXER_MARK_CALL_TIME_HIGH)
	next_line = world.time + rand(2 SECONDS, 4 SECONDS)
	if(istype(mark))
		mark.face_the_wall()
	doer.manual_emote(pick("presses a hand to [doer.p_their()] headset.", "turns away and taps [doer.p_their()] headset."))

/datum/ambient_activity/mark_call/act(seconds)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = doer
	if(!istype(mark))
		return AMBIENT_STEP_DONE
	if(world.time >= next_line)
		next_line = world.time + rand(8 SECONDS, 14 SECONDS)
		mark.call_line()
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/mark_call/finish()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = doer
	if(istype(mark) && !QDELETED(mark))
		mark.next_call_at = world.time + rand(FIXER_MARK_CALL_LOW, FIXER_MARK_CALL_HIGH)
	return ..()

/datum/ambient_activity/mark_call/spot_unreachable()
	. = ..()
	ends_at = world.time

/**
 * Ordering at the bar: up to the barkeep's counter, or the crew room's coffee machine. He pays at the
 * bar like anyone; the drink comes with him to a seat (drink/mark_round).
 */
/datum/ambient_activity/mark_order
	name = "ordering"
	/// He said it
	var/ordered = FALSE
	/// world.time he is done here
	var/done_at = 0

/datum/ambient_activity/mark_order/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = doer
	var/atom/where = anchor()
	if(!istype(mark) || !where)
		return FALSE
	var/turf/spot
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/barkeep = where
	if(istype(barkeep))
		// Someone's being served, or the counter has its share of NPCs (PATRON_COUNTER_CROWD_MAX): not now
		if(ambient_counter_customer(barkeep) || ambient_counter_crowd(barkeep, doer) >= 2)
			return FALSE
		spot = ambient_nearest_tile(doer, ambient_counter_spots(doer, barkeep, failed_spots))
	else
		spot = doer.free_tile_beside(where, 1, failed_spots)
	if(!spot)
		return FALSE
	go_to(spot)
	ends_at = world.time + 40 SECONDS
	return TRUE

/datum/ambient_activity/mark_order/arrive()
	var/atom/where = anchor()
	if(where && !doer.buckled)
		doer.face_atom(where)
	done_at = world.time + rand(4 SECONDS, 7 SECONDS)

/datum/ambient_activity/mark_order/act(seconds)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = doer
	var/atom/where = anchor()
	if(!where || !istype(mark))
		return AMBIENT_STEP_DONE
	if(!ordered)
		ordered = TRUE
		var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/barkeep = mark.get_barkeep()
		if(barkeep)
			mark.speak_context("order", barkeep, force = TRUE)
			ambient_trader_reply(barkeep, doer, AMBIENT_STRINGS_PATRONS, mark.bar[3], "barkeep_reply")
		else
			playsound(where, 'sound/machines/machine_vend.ogg', 30, TRUE, -3)
	if(world.time >= done_at)
		mark.drink_due = TRUE
		return AMBIENT_STEP_DONE
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/mark_order/spot_unreachable()
	. = ..()
	ends_at = world.time

/datum/ambient_activity/mark_order/shift_times(delay)
	. = ..()
	done_at = ambient_shifted(done_at, delay)

/**
 * His round: a seat near the bar (a free bar stool first), a real glass of what the bar pours, a sip
 * now and then, and a word with whoever sits beside him.
 */
/datum/ambient_activity/drink/mark_round
	name = "having a drink"
	accepts_company = TRUE

/datum/ambient_activity/drink/mark_round/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = doer
	var/atom/where = anchor()
	if(!istype(mark) || !where)
		return FALSE
	reagent_type = mark.bar_pour()
	// A stool at the bar counter is his to take, while the counter keeps room for players (seat_usable())
	mark.counter_business = TRUE
	var/obj/structure/chair/seat = doer.find_seat(where, MARK_BAR_RANGE, FALSE, failed_spots)
	if(seat)
		anchor_ref = WEAKREF(seat)
	. = ..()
	mark.counter_business = FALSE

/datum/ambient_activity/drink/mark_round/act(seconds)
	. = ..()
	if(. != AMBIENT_STEP_CONTINUE)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = doer
	if(istype(mark) && prob(8))
		mark.talk_to_neighbour()

/**
 * Running for help: to the nearest officer or checkpoint guard at a run, and a minute by their side.
 * With nobody to run to, he keeps his head down where he is a while.
 */
/datum/ambient_activity/mark_flee
	name = "running for help"
	priority = AMBIENT_PRIORITY_REACTION
	/// Who he runs to
	var/datum/weakref/helper_ref
	/// world.time he feels safe enough to carry on
	var/stay_until = 0

/datum/ambient_activity/mark_flee/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = doer
	if(!istype(mark))
		return FALSE
	ends_at = world.time + MARK_FLEE_MAX
	var/mob/living/helper = mark.find_helper()
	if(!helper)
		go_to(null)
		stay_until = world.time + 20 SECONDS
		return TRUE
	helper_ref = WEAKREF(helper)
	doer.set_pace(running = TRUE)
	go_to(helper, 1)
	return TRUE

/datum/ambient_activity/mark_flee/Destroy()
	helper_ref = null
	return ..()

/datum/ambient_activity/mark_flee/arrive()
	doer.set_pace(running = FALSE)
	var/mob/living/helper = helper_ref?.resolve()
	if(!helper)
		doer.crouch()
		return
	if(!stay_until)
		stay_until = world.time + MARK_FLEE_STAY
	if(!doer.buckled)
		doer.face_atom(helper)
	if(prob(60))
		doer.speak_context("safe", helper, force = TRUE)

/datum/ambient_activity/mark_flee/act(seconds)
	var/mob/living/helper = helper_ref?.resolve()
	if(helper_ref && (QDELETED(helper) || helper.stat != CONSCIOUS))
		return AMBIENT_STEP_DONE
	if(stay_until && world.time >= stay_until)
		return AMBIENT_STEP_DONE
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/mark_flee/finish()
	if(!QDELETED(doer))
		doer.set_pace(running = FALSE)
	return ..()

/datum/ambient_activity/mark_flee/spot_unreachable()
	. = ..()
	// Can't get to them: down where he is instead
	helper_ref = null
	doer.set_pace(running = FALSE)
	stay_until = world.time + 20 SECONDS

/datum/ambient_activity/mark_flee/shift_times(delay)
	. = ..()
	stay_until = ambient_shifted(stay_until, delay)

// =========================================================================
// HIS LOOKS (each with the words the fixer says, FIXER_BOUND_LOOK at most)
// =========================================================================

/// A man off a shuttle, dressed for a day of business. The base is his look with no job attached; the job picks a subtype.
/datum/outfit/fixer_mark
	name = "Outpost job: mark"
	uniform = /obj/item/clothing/under/suit/charcoal
	shoes = /obj/item/clothing/shoes/laceup
	ears = /obj/item/radio/headset
	/// What the fixer tells a crew to look for
	var/look_words = "Travelling clothes"

/// Charcoal suit and a red scarf: the scarf is what you see across a concourse
/datum/outfit/fixer_mark/scarf
	name = "Outpost job: mark (red scarf)"
	neck = /obj/item/clothing/neck/scarf/red
	gloves = /obj/item/clothing/gloves/color/black
	look_words = "Charcoal suit, red scarf"

/// Tan suit and dark glasses: money, a little too pleased with itself
/datum/outfit/fixer_mark/glasses
	name = "Outpost job: mark (dark glasses)"
	uniform = /obj/item/clothing/under/suit/tan
	glasses = /obj/item/clothing/glasses/sunglasses
	look_words = "Tan suit, dark glasses"

/// Navy suit under a fedora: old-fashioned, and wants you to know it
/datum/outfit/fixer_mark/fedora
	name = "Outpost job: mark (fedora)"
	uniform = /obj/item/clothing/under/suit/navy
	head = /obj/item/clothing/head/fedora
	look_words = "Navy suit and a fedora"

/// Leather jacket over a shirt and slacks, flat cap: a broker who used to be a dock hand
/datum/outfit/fixer_mark/leather
	name = "Outpost job: mark (leather jacket)"
	uniform = /obj/item/clothing/under/costume/buttondown/slacks
	suit = /obj/item/clothing/suit/jacket/leather
	head = /obj/item/clothing/head/flatcap
	shoes = /obj/item/clothing/shoes/jackboots
	look_words = "Leather jacket, flat cap"

/// Burgundy suit and a brown blazer: a salesman between ships
/datum/outfit/fixer_mark/blazer
	name = "Outpost job: mark (brown blazer)"
	uniform = /obj/item/clothing/under/suit/burgundy
	suit = /obj/item/clothing/suit/jacket/det_suit
	look_words = "Brown blazer, burgundy suit"

#undef MARK_GUN_RANGE
#undef MARK_GUN_CHECK_EVERY
#undef MARK_FLEE_STAY
#undef MARK_FLEE_MAX
#undef MARK_HELPER_RANGE
#undef MARK_BAR_RANGE
#undef MARK_BAR_ROUNDS
#undef MARK_SECTION
