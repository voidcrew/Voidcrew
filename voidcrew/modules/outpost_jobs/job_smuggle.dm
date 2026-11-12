/**
 * # Outpost jobs: smuggle
 *
 * Owner: P4. Spec 6.2: a sealed case carried to another outpost's fixer, through a checkpoint scanner that refuses
 * it (the checkpoint calls fixer_is_contraband(), trade/outpost_checkpoint.dm).
 *
 * The run is a mission whose `job_outpost` is where it was handed out and whose `pay_outpost` is where the case
 * goes. The case is handed to the crew at accept (stage()); the deed and the pay are one step, at the destination
 * fixer's "It's done." (can_pay() takes the deed, pay_out() shows the fixer looking inside). Nothing is placed in
 * the world but the case, so there are no job people here.
 *
 * Depends on P2's goods and ledger (bind_job(), track(), mark_deed(), ledger.watch()) and P1's fixer_at(); against
 * the P0 stubs the case still exists and is refused, and the destination checks run on position.
 */

/datum/mission/fixer_job/smuggle
	job_kind = FIXER_JOB_SMUGGLE
	base_pay = FIXER_PAY_SMUGGLE
	duration = FIXER_TIME_SMUGGLE
	slate_weight = FIXER_WEIGHT_SMUGGLE
	goods_type = /obj/item/mission_recovery/fixer_goods/case
	scene_crimes = list(OUTPOST_CRIME_GATE_TAMPER, OUTPOST_CRIME_CHECKPOINT_BREACH)
	/// Weakref to the case this run carries
	var/datum/weakref/case_ref

/datum/mission/fixer_job/smuggle/Destroy()
	if(pay_outpost)
		UnregisterSignal(pay_outpost, COMSIG_QDELETING)
	var/obj/item/mission_recovery/fixer_goods/case/case = case_ref?.resolve()
	case_ref = null
	if(!QDELETED(case))
		qdel(case)
	return ..()

// ===== THE SLATE: WHERE IT GOES =====

/// A run needs another outpost to head for, in a zone the asking crew may work in (spec 6, "needs the far zone")
/datum/mission/fixer_job/smuggle/allowed_at(obj/structure/overmap/trader_outpost/outpost, datum/voidcrew_crew_record/crew)
	if(!..())
		return FALSE
	if(pay_outpost) // an earlier ask fixed the run's end
		return !QDELETED(pay_outpost) && pay_outpost != outpost \
			&& (!crew || crew.can_work_in_zone(smuggle_zone(pay_outpost))) && !pair_taken(outpost, pay_outpost)
	var/list/options = destinations(outpost, crew)
	if(!length(options))
		return FALSE
	if(crew) // a slate entry with no one asking is not fixed to a crew's zones
		pay_outpost = pick(options)
	return TRUE

/// The zone `outpost` lies in, or null when it cannot be told
/datum/mission/fixer_job/smuggle/proc/smuggle_zone(obj/structure/overmap/trader_outpost/outpost)
	return SSovermap_zones?.get_zone_type_anywhere(get_turf(outpost))

/**
 * The other trader outposts a run from `origin` can head for: not `origin`, in a zone `crew` may work in (any zone
 * when there is no crew), and not the other end of a live run with `origin` already.
 */
/datum/mission/fixer_job/smuggle/proc/destinations(obj/structure/overmap/trader_outpost/origin, datum/voidcrew_crew_record/crew)
	. = list()
	for(var/obj/structure/overmap/trader_outpost/candidate in GLOB.trader_outposts)
		if(QDELETED(candidate) || candidate == origin)
			continue
		if(crew && !crew.can_work_in_zone(smuggle_zone(candidate)))
			continue
		if(pair_taken(origin, candidate))
			continue
		. += candidate

/// Whether a live smuggle run already connects these two outposts, either way round (spec 6: one per pair)
/datum/mission/fixer_job/smuggle/proc/pair_taken(obj/structure/overmap/trader_outpost/one, obj/structure/overmap/trader_outpost/other)
	if(!one || !other)
		return FALSE
	for(var/datum/mission/fixer_job/smuggle/run in SSmissions.all_active_missions)
		if(run == src || QDELETED(run) || run.failed || run.completed)
			continue
		var/obj/structure/overmap/trader_outpost/from = run.giver_outpost || run.job_outpost
		if((from == one && run.pay_outpost == other) || (from == other && run.pay_outpost == one))
			return TRUE
	return FALSE

/**
 * The run's end: the one already fixed if the crew may still work there, else a fresh pick. Null when no other
 * outpost will do. `crew` is the crew taking the run, or null when none is known yet.
 */
/datum/mission/fixer_job/smuggle/proc/ensure_destination(datum/voidcrew_crew_record/crew)
	if(pay_outpost && !QDELETED(pay_outpost) && (!crew || crew.can_work_in_zone(smuggle_zone(pay_outpost))))
		return pay_outpost
	var/list/options = destinations(giver_outpost || job_outpost, crew)
	if(!length(options))
		return null
	pay_outpost = pick(options)
	return pay_outpost

// ===== WHAT THE OFFER AND THE NOTE SAY =====

/datum/mission/fixer_job/smuggle/offer_tokens()
	var/obj/structure/overmap/trader_outpost/far = ensure_destination(null)
	var/clock = station_time_timestamp("hh:mm", (time_started || world.time) + duration)
	return list(
		FIXER_TOKEN_NAME = html_encode(fixer_smuggle_cut("the case", FIXER_BOUND_NAME)),
		FIXER_TOKEN_LOOK = html_encode(fixer_smuggle_cut("a black case, locked", FIXER_BOUND_LOOK)),
		FIXER_TOKEN_CLOCK = html_encode(clock),
		FIXER_TOKEN_PLACE = html_encode(fixer_smuggle_cut(fixer_smuggle_dest_place(far), FIXER_BOUND_PLACE)),
		FIXER_TOKEN_TO = html_encode(fixer_smuggle_cut(fixer_smuggle_dest_name(far), FIXER_BOUND_TO)),
	)

/datum/mission/fixer_job/smuggle/note_lines()
	var/obj/structure/overmap/trader_outpost/far = ensure_destination(null)
	var/dest_name = fixer_smuggle_cut(fixer_smuggle_dest_name(far), FIXER_BOUND_TO)
	var/place = fixer_smuggle_cut(fixer_smuggle_dest_place(far), FIXER_BOUND_PLACE)
	return list(
		fixer_smuggle_cut("A locked case. It stays locked.", FIXER_BOUND_NOTE_LINE),
		fixer_smuggle_cut("To [dest_name] at [place].", FIXER_BOUND_NOTE_LINE),
	)

// ===== STAGING: THE CASE CHANGES HANDS =====

/datum/mission/fixer_job/smuggle/stage()
	var/datum/voidcrew_crew_record/crew = servant?.get_crew_record()
	var/obj/structure/overmap/trader_outpost/far = ensure_destination(crew)
	if(!far)
		return FALSE
	var/obj/structure/overmap/trader_outpost/origin = giver_outpost || job_outpost
	var/mob/living/giver = origin ? GLOB.fixer_network.fixer_at(origin) : null
	var/mob/living/recipient = case_recipient(origin, giver)
	if(!recipient)
		return FALSE
	// P2's start flow may have made the goods already: adopt them rather than make a second case
	var/obj/item/mission_recovery/fixer_goods/case/case = goods_ref?.resolve()
	if(!istype(case) || QDELETED(case))
		case = new(get_turf(recipient))
	bind_item(case)
	case.bind_job(src)
	case_ref = WEAKREF(case)
	track(case, FALSE)
	RegisterSignal(far, COMSIG_QDELETING, PROC_REF(on_far_outpost_deleted), override = TRUE)
	hand_over(case, recipient, giver)
	return TRUE

/**
 * Who gets the case: the living roster member at the giving outpost nearest the fixer there, or failing that
 * any living roster member (an admin handing a crew a run from afar). Null when there is no one.
 */
/datum/mission/fixer_job/smuggle/proc/case_recipient(obj/structure/overmap/trader_outpost/origin, mob/living/giver)
	var/list/mob/living/here = list()
	var/list/mob/living/anywhere = list()
	for(var/datum/weakref/ref as anything in roster)
		var/datum/mind/member = ref?.resolve()
		var/mob/living/body = member?.current
		if(!isliving(body) || QDELETED(body) || body.stat == DEAD)
			continue
		anywhere += body
		if(origin && get_trader_outpost_for_turf(get_turf(body)) == origin)
			here += body
	var/list/mob/living/pool = length(here) ? here : anywhere
	var/mob/living/best
	var/best_distance = INFINITY
	for(var/mob/living/body as anything in pool)
		var/distance = giver ? get_dist(giver, body) : 0
		if(distance < best_distance)
			best = body
			best_distance = distance
	return best

/// The case goes into `recipient`'s hands, from the fixer's if the fixer is there to be seen doing it
/datum/mission/fixer_job/smuggle/proc/hand_over(obj/item/case, mob/living/recipient, mob/living/giver)
	recipient.put_in_hands(case)
	if(giver && get_dist(giver, recipient) <= FIXER_TALK_RANGE + 1)
		giver.visible_message(span_notice("[giver] slips [recipient] a locked case."))
	else
		to_chat(recipient, span_notice("A locked case is pressed into your hands."))

/// Takes the case away when the run is over, whoever holds it and wherever it is
/datum/mission/fixer_job/smuggle/unstage()
	. = ..()
	var/obj/item/mission_recovery/fixer_goods/case/case = case_ref?.resolve()
	case_ref = null
	if(!QDELETED(case))
		qdel(case)

/// The ledger hears the far end's police as well (spec 5.1): its gate is the scene of this job too
/datum/mission/fixer_job/smuggle/on_mission_started()
	. = ..()
	if(failed || QDELETED(src))
		return
	watch_far_end()

/datum/mission/fixer_job/smuggle/proc/watch_far_end()
	var/datum/outpost_police/police = pay_outpost?.police
	if(ledger && police)
		ledger.watch(police)

/// The destination went away: the run has nowhere to go
/datum/mission/fixer_job/smuggle/proc/on_far_outpost_deleted(datum/source)
	SIGNAL_HANDLER
	pay_outpost = null
	fail_reason ||= FIXER_FAIL_GONE
	INVOKE_ASYNC(src, PROC_REF(fail), "The case has nowhere to go.")

// ===== THE DEADLINE =====

/// Whether no living fixer stands at the destination to take the case
/datum/mission/fixer_job/smuggle/proc/destination_unmanned()
	return !QDELETED(pay_outpost) && !GLOB.fixer_network.fixer_at(pay_outpost)

/// The run waits while its destination has no fixer, so killing the fixer cannot fail it (abuse J12, spec 4.6)
/datum/mission/fixer_job/smuggle/hold_deadline()
	. = ..()
	if(.)
		return
	if(deed_done || failed || completed || QDELETED(src) || !destination_unmanned())
		return FALSE
	if(timeout_timer)
		deltimer(timeout_timer)
	timeout_timer = addtimer(CALLBACK(src, PROC_REF(on_timeout)), FIXER_DEADLINE_HOLD, TIMER_STOPPABLE)
	return TRUE

// ===== THE DEED AND THE PAY =====

/// Whether `fixer` is a living fixer standing at the destination
/datum/mission/fixer_job/smuggle/proc/is_destination_fixer(atom/fixer)
	if(QDELETED(pay_outpost) || !istype(fixer, /mob/living/carbon/human/npc/ambient_npc/outpost/fixer))
		return FALSE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/who = fixer
	if(who.stat == DEAD)
		return FALSE
	return get_trader_outpost_for_turf(get_turf(who)) == pay_outpost

/// The case, if `user` holds it in a hand
/datum/mission/fixer_job/smuggle/proc/case_held_by(mob/living/user)
	var/obj/item/mission_recovery/fixer_goods/case/case = case_ref?.resolve()
	if(QDELETED(case) || !user?.is_holding(case))
		return null
	return case

/// Only the destination's fixer takes the case
/datum/mission/fixer_job/smuggle/can_turn_in_at(atom/reward_anchor)
	return is_destination_fixer(reward_anchor) && ..()

/**
 * Delivery is the deed: with the case in hand at the destination fixer, the deed is taken here, and the rest of the
 * checks (the roster, who is wanted, the port) are the base's. Any other fixer says it is not theirs.
 */
/datum/mission/fixer_job/smuggle/can_pay(mob/living/user, mob/fixer)
	if(QDELETED(src) || failed || completed)
		return FIXER_LINE_NOTHING
	if(!is_destination_fixer(fixer))
		return FIXER_LINE_WRONG_FIXER
	if(!case_held_by(user))
		return ..() || FIXER_LINE_NOTHING
	if(!deed_done)
		mark_deed(user)
		if(QDELETED(src) || failed || completed)
			return FIXER_LINE_NOT_YOURS
	return ..()

/// The fixer takes the case, opens it a crack, looks in and puts it away, then the base pays
/datum/mission/fixer_job/smuggle/pay_out(mob/living/user, mob/fixer)
	var/obj/item/case = case_held_by(user)
	if(case && fixer)
		fixer_smuggle_look_in(fixer)
	return ..()

// ===== THE CASE =====

/// The sealed case: refused by every trader outpost's scanner for as long as its run is live
/obj/item/mission_recovery/fixer_goods/case
	name = "locked case"
	desc = "A locked case. Something inside shifts when it's tilted."

/// Whether this is the case of a run still on its way: bound to a smuggle job that has not failed, finished or been delivered
/obj/item/mission_recovery/fixer_goods/case/proc/run_is_live()
	var/datum/mission/fixer_job/smuggle/run = mission_ref?.resolve()
	if(!istype(run) || QDELETED(run))
		return FALSE
	return !run.failed && !run.completed && !run.deed_done

/// Whether the checkpoint scanner refuses `thing`: a case whose run is live. P4.
/proc/fixer_is_contraband(atom/movable/thing)
	if(!istype(thing, /obj/item/mission_recovery/fixer_goods/case))
		return FALSE
	var/obj/item/mission_recovery/fixer_goods/case/case = thing
	return case.run_is_live()

// ===== WORDS =====

/// `text` cut to `bound` characters, the last three an ellipsis when it was longer
/proc/fixer_smuggle_cut(text, bound)
	if(length_char(text) <= bound)
		return text
	return "[copytext_char(text, 1, bound - 2)]..."

/// The fixer at `outpost`, as the note names them (spec 2.1)
/proc/fixer_smuggle_dest_name(obj/structure/overmap/trader_outpost/outpost)
	if(istype(outpost, /obj/structure/overmap/trader_outpost/black_market))
		return "Mister Quill"
	if(istype(outpost, /obj/structure/overmap/trader_outpost/outfitter))
		return "Lot Brannigan"
	if(istype(outpost, /obj/structure/overmap/trader_outpost/general))
		return "Nan Tolliver"
	return "the fixer"

/// `outpost`, as the fixers there call it (spec 2.4)
/proc/fixer_smuggle_dest_place(obj/structure/overmap/trader_outpost/outpost)
	if(istype(outpost, /obj/structure/overmap/trader_outpost/black_market))
		return "the Undertow"
	if(istype(outpost, /obj/structure/overmap/trader_outpost/outfitter))
		return "the Quartermain"
	if(istype(outpost, /obj/structure/overmap/trader_outpost/general))
		return "Halcyon"
	return "the outpost"

/// Which of the strings file's speakers `fixer` is
/proc/fixer_smuggle_voice(atom/fixer)
	if(istype(fixer, /mob/living/carbon/human/npc/ambient_npc/outpost/fixer/nan))
		return FIXER_VOICE_NAN
	if(istype(fixer, /mob/living/carbon/human/npc/ambient_npc/outpost/fixer/lot))
		return FIXER_VOICE_LOT
	if(istype(fixer, /mob/living/carbon/human/npc/ambient_npc/outpost/fixer/quill))
		return FIXER_VOICE_QUILL
	return FIXER_VOICE_STAND_IN

/// The lines of `voice` for `moment` ("look", "stow") in strings/job_smuggle.json, or the stand-in's, or an empty list
/proc/fixer_smuggle_lines(voice, moment)
	load_strings_file(FIXER_STRINGS_SMUGGLE, FIXER_STRINGS_DIR)
	var/list/table = GLOB.string_cache[FIXER_STRINGS_SMUGGLE]
	for(var/speaker in list(voice, FIXER_VOICE_STAND_IN))
		var/list/section = table[speaker]
		var/list/lines = section?[moment]
		if(length(lines))
			return lines
	return list()

/// `fixer` looks inside the case and puts it away, said to the room: no one else learns what is in it
/proc/fixer_smuggle_look_in(mob/living/fixer)
	var/voice = fixer_smuggle_voice(fixer)
	for(var/moment in list("look", "stow"))
		var/list/lines = fixer_smuggle_lines(voice, moment)
		if(!length(lines))
			continue
		fixer.visible_message(span_notice(replacetext(pick(lines), "{fixer}", "[fixer]")))
