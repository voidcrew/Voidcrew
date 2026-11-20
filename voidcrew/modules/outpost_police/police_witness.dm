/**
 * # Outpost police: townspeople tell someone (owner decisions 51 and 52)
 *
 * A townsperson, an outpost worker or a trader away from their counter has no radio. Their report waits on them
 * telling someone who can raise the alarm, in person: an officer with a working radio, the police desk, a trader at
 * their counter, a gate guard in their booth or an on-duty lockup guard (lockup_listeners()). Until they have,
 * nobody is wanted.
 *
 * - process_pending_reports() (police_wanted.dm) calls tick_tellers() once a second for each report. A teller who
 *   stands within OUTPOST_POLICE_TELL_RANGE of a listener, in clear sight of them, for OUTPOST_POLICE_RADIOLESS_TIME
 *   has told them. The desk, a trader, a gate guard or a lockup guard makes the report count at once; an officer joins
 *   its witnesses and makes the usual radio call (nudge_witness()), and the report counts when the call goes out.
 * - Up to OUTPOST_POLICE_TELL_RUNNERS of a report's tellers, nearest to a listener first, run to one
 *   (/datum/ambient_activity/outpost_report: plain walking, on their own feet). The rest do as they did. A runner who
 *   has told, whose report is made or dropped, or who can reach nobody, goes on as before (done_telling()).
 * - Held (grabbed, cuffed, buckled, shut in, on fire), stunned or out cold, they tell nobody (perception can_report());
 *   their AI gets free first (ambient_escape runs before the routine). Free again inside the report's keep, they go on.
 * - The police learn where a witness last saw the offender, not where they are now (report_scene(), police_wanted.dm).
 *
 * Everything holds weakrefs: a teller, a listener or an offender may be deleted at any moment (abuse SF4).
 */

// =========================================================================
// THE TICK
// =========================================================================

/**
 * One second of `report`'s townspeople: those beside someone who can raise the alarm tell them, and up to
 * OUTPOST_POLICE_TELL_RUNNERS more are sent to find someone. Sets `report.confirmed` when a teller made it.
 */
/datum/outpost_police/proc/tick_tellers(datum/outpost_pending_report/report, mob/living/offender)
	var/running = 0
	var/list/mob/living/carbon/human/npc/ambient_npc/waiting = list()
	for(var/datum/weakref/ref as anything in report.witnesses.Copy())
		var/mob/living/carbon/human/npc/ambient_npc/teller = ref.resolve()
		if(QDELETED(teller) || teller.stat == DEAD || (ref in report.told) || !perception.tells_in_person(teller))
			continue
		var/runner = (ref in report.runners)
		if(!perception.can_report(teller))
			// Held or out cold: no telling, but a runner keeps their place and goes on once free
			LAZYREMOVE(report.telling, ref)
			if(runner)
				running++
			continue
		if(tell_step(report, teller, ref))
			return
		if(runner)
			running++
			keep_running(teller, report)
		else
			waiting += teller
	// The nearest to someone they can tell go first
	while(running < OUTPOST_POLICE_TELL_RUNNERS && length(waiting))
		var/mob/living/carbon/human/npc/ambient_npc/best
		var/best_dist = INFINITY
		for(var/mob/living/carbon/human/npc/ambient_npc/candidate as anything in waiting)
			var/dist = listener_distance(candidate)
			if(dist < best_dist)
				best = candidate
				best_dist = dist
		if(!best)
			best = waiting[1]
		waiting -= best
		send_runner(best, report)
		running++

/**
 * `teller`'s telling this second: beside a listener they start or carry on; after OUTPOST_POLICE_RADIOLESS_TIME they
 * have told them (witness_told()). TRUE when that made the report.
 */
/datum/outpost_police/proc/tell_step(datum/outpost_pending_report/report, mob/living/carbon/human/npc/ambient_npc/teller, datum/weakref/teller_ref)
	var/list/entry = LAZYACCESS(report.telling, teller_ref)
	var/datum/weakref/listener_ref = entry?[1]
	var/atom/listener = listener_ref?.resolve()
	if(!entry || !listener_ready(listener) || !in_telling_reach(teller, listener))
		listener = listener_in_reach(teller)
		if(!listener)
			LAZYREMOVE(report.telling, teller_ref)
			return FALSE
		LAZYSET(report.telling, teller_ref, list(WEAKREF(listener), world.time))
		start_telling(teller, listener)
		return FALSE
	if(world.time - entry[2] < OUTPOST_POLICE_RADIOLESS_TIME)
		return FALSE
	return witness_told(report, teller, teller_ref, listener)

/// `teller` starts telling `listener`: a line, and they turn to each other
/datum/outpost_police/proc/start_telling(mob/living/carbon/human/npc/ambient_npc/teller, atom/listener)
	if(!teller.buckled)
		teller.face_atom(listener)
	teller.speak_context(AMBIENT_LINE_REPORT_TELL, ismob(listener) ? listener : null, force = TRUE)
	var/mob/living/heard_by = listener
	if(isliving(heard_by) && heard_by.stat == CONSCIOUS && !heard_by.buckled)
		heard_by.face_atom(teller)

/**
 * `teller` has told `listener` about `report`. The desk, a trader, a gate guard or a lockup guard raises the alarm at
 * once (TRUE: made). An officer now knows of it as if it had seen it and makes its radio call (nudge_witness()); the
 * report counts when that goes out, so dropping the officer before the call still silences it.
 */
/datum/outpost_police/proc/witness_told(datum/outpost_pending_report/report, mob/living/carbon/human/npc/ambient_npc/teller, datum/weakref/teller_ref, atom/listener)
	LAZYREMOVE(report.telling, teller_ref)
	LAZYOR(report.told, teller_ref)
	log_game("OUTPOST POLICE: [teller] told [listener] about [report.crime] at [outpost].")
	if(perception.is_officer(listener))
		var/datum/weakref/officer_ref = WEAKREF(listener)
		if(!(officer_ref in report.witnesses))
			report.witnesses += officer_ref
		var/mob/living/officer = listener
		if(officer.stat == CONSCIOUS && !officer.buckled)
			officer.face_atom(teller)
		return FALSE
	report.confirmed = TRUE
	return TRUE

// =========================================================================
// WHO THEY CAN TELL
// =========================================================================

/// Everyone and everything at this outpost a townsperson could tell now
/datum/outpost_police/proc/report_listeners()
	. = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(listener_ready(officer))
			. += officer
	if(desk_turf)
		. += desk_turf
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/trader in outpost?.traders)
		if(listener_ready(trader))
			. += trader
	for(var/atom/guard as anything in lockup_listeners())
		if(listener_ready(guard))
			. += guard

/**
 * The on-duty lockup guards at this outpost's central prison who can take a townsperson's report and raise the alarm.
 * None on this branch: the lockup fills this in.
 */
/datum/outpost_police/proc/lockup_listeners()
	return list()

/// Whether `listener` can take a report now: an officer with a working radio, the desk, a trader at their counter or gate guard in their booth, a lockup guard
/datum/outpost_police/proc/listener_ready(atom/listener)
	if(QDELETED(listener))
		return FALSE
	if(isturf(listener))
		return listener == desk_turf
	if(perception.is_officer(listener))
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = listener
		return officer.stat == CONSCIOUS && perception.can_report(officer) && !!officer.stealth_radio_ready()
	if(istype(listener, /mob/living/carbon/human/npc/ambient_npc/outpost/trader))
		return perception.trader_at_desk(listener) && perception.can_report(listener)
	if(listener in lockup_listeners())
		var/mob/living/guard = listener
		return !isliving(guard) || perception.can_report(guard)
	return FALSE

/// Whether `teller` is close enough to `listener`, in clear sight of them, to tell them
/datum/outpost_police/proc/in_telling_reach(atom/teller, atom/listener)
	var/turf/here = get_turf(teller)
	var/turf/there = get_turf(listener)
	if(!here || !there || here.z != there.z || get_dist(here, there) > OUTPOST_POLICE_TELL_RANGE)
		return FALSE
	return outpost_police_clear_line(teller, listener, OUTPOST_POLICE_TELL_RANGE)

/// The nearest listener `teller` could tell from where they stand, or null
/datum/outpost_police/proc/listener_in_reach(atom/teller)
	var/atom/best
	var/best_dist = INFINITY
	for(var/atom/listener as anything in report_listeners())
		if(!in_telling_reach(teller, listener))
			continue
		var/dist = get_dist(teller, listener)
		if(dist < best_dist)
			best = listener
			best_dist = dist
	return best

/// How far `teller` is from the nearest listener on their level (INFINITY if none)
/datum/outpost_police/proc/listener_distance(atom/teller)
	. = INFINITY
	var/turf/here = get_turf(teller)
	if(!here)
		return
	for(var/atom/listener as anything in report_listeners())
		var/turf/there = get_turf(listener)
		if(there?.z == here.z)
			. = min(., get_dist(here, there))

/// Whether `teller` still has a report waiting on them telling someone
/datum/outpost_police/proc/has_untold_report(mob/living/teller)
	var/datum/weakref/teller_ref = WEAKREF(teller)
	for(var/datum/outpost_pending_report/report as anything in pending_reports)
		if(!QDELETED(report) && (teller_ref in report.witnesses) && !(teller_ref in report.told))
			return TRUE
	return FALSE

/// `teller` gave up on telling anyone (nobody reachable before the keep ran out): their reports no longer send them
/datum/outpost_police/proc/stop_telling(mob/living/teller)
	var/datum/weakref/teller_ref = WEAKREF(teller)
	for(var/datum/outpost_pending_report/report as anything in pending_reports)
		if(!QDELETED(report) && (teller_ref in report.witnesses))
			LAZYOR(report.told, teller_ref)
			LAZYREMOVE(report.telling, teller_ref)

// =========================================================================
// RUNNERS
// =========================================================================

/// Sends `teller` off to tell someone about `report`, with a shout officers in earshot come to look at
/datum/outpost_police/proc/send_runner(mob/living/carbon/human/npc/ambient_npc/teller, datum/outpost_pending_report/report)
	var/datum/weakref/teller_ref = WEAKREF(teller)
	LAZYOR(report.runners, teller_ref)
	if(!teller.start_activity(new /datum/ambient_activity/outpost_report(teller, null, src, report.expires)))
		// Nobody they can get to: they go on as before, and the report waits on its other witnesses or dies with its keep
		LAZYOR(report.told, teller_ref)
		teller.done_telling()
		return
	teller.speak_context(AMBIENT_LINE_REPORT_RUN, null, force = TRUE)
	stealth_noise(teller, STEALTH_NOISE_SCREAM)

/// A runner who lost their way there (knocked out and back up) sets off again, without another shout
/datum/outpost_police/proc/keep_running(mob/living/carbon/human/npc/ambient_npc/teller, datum/outpost_pending_report/report)
	if(istype(teller.activity, /datum/ambient_activity/outpost_report) || teller.fading)
		return
	if(!teller.start_activity(new /datum/ambient_activity/outpost_report(teller, null, src, report.expires)))
		stop_telling(teller)
		teller.done_telling()

/// Done telling, or nobody to tell: what they do next. Townspeople leave by the lift, as after any trouble.
/mob/living/carbon/human/npc/ambient_npc/proc/done_telling()
	if(istype(place, /datum/ambient_place/outpost) && !fading && stat == CONSCIOUS)
		start_activity(new /datum/ambient_activity/leave(src))

// Staff stay at work after trouble (react_violence())
/mob/living/carbon/human/npc/ambient_npc/outpost/worker/done_telling()
	return

// She never leaves over it (react_violence())
/mob/living/carbon/human/npc/ambient_npc/outpost/dancer/done_telling()
	return

// A trader goes back to their counter (their routine), never down the lift
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/done_telling()
	return

/**
 * Running to someone who can raise the alarm: the nearest listener they can reach, re-picked when one moves off, goes
 * down or can't be reached. Beside them, they stand and tell (the police tick does the telling: tell_step()). Gives
 * up at the report's keep. Outranks leaving, so a fight breaking out near them doesn't send them to the lift first.
 */
/datum/ambient_activity/outpost_report
	name = "reporting a crime"
	priority = OUTPOST_POLICE_TELL_PRIORITY
	/// The police they report to
	var/datum/weakref/police_ref
	/// Who or what they are heading for
	var/datum/weakref/listener_ref
	/// Listeners they could find no way to: weakref -> TRUE
	var/list/failed_listeners
	/// world.time they give up
	var/give_up_at = 0

/datum/ambient_activity/outpost_report/New(mob/living/carbon/human/npc/ambient_npc/new_doer, atom/anchor, datum/outpost_police/police, give_up_at)
	. = ..()
	police_ref = police ? WEAKREF(police) : null
	src.give_up_at = give_up_at || (world.time + OUTPOST_POLICE_PENDING_KEEP)

/datum/ambient_activity/outpost_report/Destroy()
	police_ref = null
	listener_ref = null
	failed_listeners = null
	return ..()

/datum/ambient_activity/outpost_report/proc/police()
	var/datum/outpost_police/police = police_ref?.resolve()
	return QDELETED(police) ? null : police

/datum/ambient_activity/outpost_report/setup()
	if(!police() || world.time >= give_up_at)
		return FALSE
	if(!pick_listener())
		return FALSE
	doer.set_pace(running = TRUE)
	return TRUE

/datum/ambient_activity/outpost_report/finish()
	if(!QDELETED(doer))
		doer.set_pace(running = FALSE)
	return ..()

/// Heads for the nearest listener not given up on, and a tile to tell them from. FALSE if there is none.
/datum/ambient_activity/outpost_report/proc/pick_listener()
	var/datum/outpost_police/police = police()
	if(!police)
		return FALSE
	var/turf/here = get_turf(doer)
	if(!here)
		return FALSE
	var/list/candidates = list()
	for(var/atom/listener as anything in police.report_listeners())
		var/turf/there = get_turf(listener)
		if(there?.z == here.z && !LAZYACCESS(failed_listeners, WEAKREF(listener)))
			candidates[listener] = get_dist(here, there)
	while(length(candidates))
		var/atom/nearest
		for(var/atom/listener as anything in candidates)
			if(!nearest || candidates[listener] < candidates[nearest])
				nearest = listener
		candidates -= nearest
		if(police.in_telling_reach(doer, nearest))
			listener_ref = WEAKREF(nearest)
			go_to(null)
			return TRUE
		var/turf/stand = tell_spot(nearest)
		if(stand)
			listener_ref = WEAKREF(nearest)
			go_to(stand)
			return TRUE
		LAZYSET(failed_listeners, WEAKREF(nearest), TRUE)
	listener_ref = null
	return FALSE

/// The nearest tile to them they could stand on to tell `listener`, or null
/datum/ambient_activity/outpost_report/proc/tell_spot(atom/listener)
	var/turf/there = get_turf(listener)
	if(!there)
		return null
	var/turf/best
	var/best_dist = INFINITY
	for(var/turf/tile as anything in RANGE_TURFS(OUTPOST_POLICE_TELL_RANGE, there))
		if((tile == there && !isturf(listener)) || !doer.standable(tile, failed_spots, TRUE))
			continue
		if(!can_see(tile, there, OUTPOST_POLICE_TELL_RANGE))
			continue
		var/dist = get_dist(doer, tile)
		if(dist < best_dist)
			best = tile
			best_dist = dist
	return best

// Close enough to tell them counts as there; a listener who walked off sends them to a new spot (act() picks it)
/datum/ambient_activity/outpost_report/at_spot()
	var/atom/listener = listener_ref?.resolve()
	var/datum/outpost_police/police = police()
	if(listener && police?.in_telling_reach(doer, listener))
		return TRUE
	if(!spot)
		return TRUE
	if(!listener || get_dist(spot, get_turf(listener)) > OUTPOST_POLICE_TELL_RANGE)
		spot = null
		return TRUE
	return ..()

/datum/ambient_activity/outpost_report/act(seconds)
	var/datum/outpost_police/police = police()
	if(!police || world.time >= give_up_at)
		return give_up()
	if(!police.has_untold_report(doer))
		return quit()
	var/atom/listener = listener_ref?.resolve()
	if(!police.listener_ready(listener))
		return pick_listener() ? AMBIENT_STEP_MOVE : give_up()
	if(police.in_telling_reach(doer, listener))
		if(!doer.buckled)
			doer.face_atom(listener)
		return AMBIENT_STEP_CONTINUE
	// Got there and still can't tell them (a door shut between them, they moved): another tile, or another listener
	if(isturf(spot))
		LAZYSET(failed_spots, spot, TRUE)
	var/turf/stand = tell_spot(listener)
	if(stand)
		go_to(stand)
		return AMBIENT_STEP_MOVE
	LAZYSET(failed_listeners, listener_ref, TRUE)
	return pick_listener() ? AMBIENT_STEP_MOVE : give_up()

// Walks that keep ending stuck give up that tile; act() picks another next to the same listener, or another listener
/datum/ambient_activity/outpost_report/spot_unreachable()
	. = ..()
	var/atom/listener = listener_ref?.resolve()
	var/datum/outpost_police/police = police()
	if(listener && police && !tell_spot(listener))
		LAZYSET(failed_listeners, listener_ref, TRUE)
		listener_ref = null

/datum/ambient_activity/outpost_report/shift_times(delay)
	. = ..()
	give_up_at = ambient_shifted(give_up_at, delay)

/// Nobody they could reach in time: their reports stop sending them, and they go on as before
/datum/ambient_activity/outpost_report/proc/give_up()
	police()?.stop_telling(doer)
	return quit()

/// Ends this and lets them go on as before (done_telling()). Deletes this activity: nothing may touch it after.
/datum/ambient_activity/outpost_report/proc/quit()
	var/mob/living/carbon/human/npc/ambient_npc/who = doer
	who.end_activity()
	who.done_telling()
	return AMBIENT_STEP_CONTINUE
