/**
 * # Outpost police: arrests
 *
 * Owner: P5. One /datum/outpost_police_case per suspect at one or two stars: respond, order, subdue, cuff,
 * search, escort, desk, book. Every step on the suspect's body is the tg action a player officer would take:
 * the baton is a click (outpost_prison_npc_hit()), the cuffs are tg's attempt_to_cuff() with its do_after,
 * the escort is a pull, the lift is the police lift (police.ride()). Spec 6 (the step table and 6.4).
 *
 * How it runs:
 * - The police tick (tick_cases(), once a second) calls process_case() on each case: it closes, staffs,
 *   watches for escapes and interference, times steps out and runs the current step proc.
 * - A step proc never sleeps. What takes time on a body (cuffing, the search, the lift ride, the evidence at
 *   the desk, booking, taking evidence off a fallen officer) runs as an action: begin_action() hands it to
 *   do_action() through INVOKE_ASYNC, and `acting` is set while it runs. Nothing else happens on the case
 *   meanwhile.
 * - The arresting officer's brain (the outpost_police_case subtree) only walks to the case's `goal`, or
 *   stands still while an action runs, so a do_after is never broken by the officer's own feet. The cover
 *   officer follows the arresting one, and at two stars may fire on disable through the force and shooting
 *   subtrees (police_force.dm and the human NPC base).
 *
 * When it goes wrong (spec 6.4, owner decision 37): a suspect in crit before the cuffs is cuffed where they lie,
 * then held there with a medic called until they come round; one dead before the cuffs ends the case. At three
 * stars and up only a suspect who is down is taken alive (by a stun officer if one is free). A suspect lost after the search still
 * sends the officer to the evidence locker with the evidence. Slipping police cuffs is SLIP_CUFFS, someone else
 * taking them off is ABET, pulling the suspect away is RESIST. A suspect who breaks the hold on the walk is run
 * down and held by tg's aggressive grip after that. A step stuck OUTPOST_POLICE_STEP_TIMEOUT without the officer
 * getting any nearer goes back to respond; the third time the case ends and no new one opens on that person for
 * CASE_REOPEN_HOLD. A case that ends with our cuffs still on the suspect first sends an officer to take them off
 * (the release step), and a booking with no cell to be had fines and frees them on the spot: nobody is left in
 * police cuffs. A wanted suspect down in front of an officer, at any stars, is arrested where they lie
 * (arrest_downed(), from the stealth layer).
 * No healing, no moving a downed body, no state of our own on the suspect: what they feel is tg's baton,
 * cuffs and pull.
 */

// ===== STEPS (`case.step`; tests use the literals) =====

#define CASE_STEP_RESPOND "respond"
#define CASE_STEP_ORDER "order"
#define CASE_STEP_SUBDUE "subdue"
#define CASE_STEP_CUFF "cuff"
#define CASE_STEP_SEARCH "search"
#define CASE_STEP_ESCORT "escort"
#define CASE_STEP_DESK "desk"
#define CASE_STEP_BOOK "book"
/// Standing by a suspect who went down before the cuffs
#define CASE_STEP_DOWNED "standby"
/// The arrest is called off with our cuffs still on them: an officer goes and takes them off
#define CASE_STEP_RELEASE "release"
/// Three stars and up with no cell to be had (none, or none that can be got to): held in cuffs by the desk, and the
/// booking tried again every CASE_HOLD_RETRY. Never a fine (owner decision 37, lead decision L-A2).
#define CASE_STEP_HOLD "hold"

// ===== ACTIONS (`case.acting`) =====

#define CASE_ACT_CUFFING "cuffing"
#define CASE_ACT_SEARCHING "searching"
#define CASE_ACT_RIDING "riding"
#define CASE_ACT_DISPOSING "disposing"
#define CASE_ACT_BOOKING "booking"
#define CASE_ACT_RECOVERING "recovering"
#define CASE_ACT_RELEASING "releasing"

/// Blackboard key: where the officer's case sends them
#define BB_OUTPOST_POLICE_CASE_GOAL "outpost_police_case_goal"

/// An action that has not come back in this long is taken as broken (a runtime inside it) and let go. The
/// longest real one, booking with the jail strip, is well under it.
#define CASE_ACTION_STUCK (45 SECONDS)
/// Tries at picking an evidence case back up before it is left where it lies (the arrest goes on without it)
#define CASE_RECOVER_TRIES 3
/// After a case closes on timeouts, no new case opens on that person for this long (the warrant may fade)
#define CASE_REOPEN_HOLD (2 MINUTES)
/// How far the cover officer keeps from the arresting one
#define CASE_COVER_DISTANCE 2
/// Within this many tiles (and seen) the response is over and the order is given
#define CASE_CONTACT_RANGE 4
/// A strip of the cuffs this recent is whoever took them off
#define CASE_STRIPPER_WINDOW (15 SECONDS)
/// Taking an evidence case off a fallen officer
#define CASE_RECOVER_TIME (2 SECONDS)
/// Taking police cuffs off someone when a case is called off
#define CASE_UNCUFF_TIME (2 SECONDS)
/// Longest an officer stands by a cuffed suspect in crit before the arrest is called off
#define CASE_DOWNED_LIMIT (10 MINUTES)
/// A lift point the officer gets no nearer to for this long is given up for another
#define CASE_LIFT_PATIENCE (8 SECONDS)
/// ...and left out of every lift choice for this long
#define CASE_LIFT_SKIP (30 SECONDS)
/// How often a suspect held for want of a cell is taken to one again
#define CASE_HOLD_RETRY (30 SECONDS)
/// A release no officer has done in a step's time goes to another officer, this many times; then the cuffs come off
#define CASE_RELEASE_HANDOFFS 2
/// Longest a release waits for an officer at all before the cuffs come off where the suspect stands
#define CASE_RELEASE_LIMIT (3 MINUTES)
/// A walk to the evidence locker (then the desk) that gets no nearer for this long tries the next place
#define CASE_EVIDENCE_PATIENCE (20 SECONDS)

/datum/outpost_police
	/// P5: minds no new case opens on until a world.time (their last case closed on timeouts). Written by police_arrest.dm only.
	var/list/case_holds

// =========================================================================
// THE API
// =========================================================================

/**
 * Opens an arrest for `warrant`. Returns the case (the open one, if there is one already), or null. `takedown`: the
 * suspect is down (crit, stamina crit, stunned), and is cuffed where they lie at any stars (owner decision 37).
 */
/datum/outpost_police/proc/open_case(datum/outpost_warrant/warrant, takedown = FALSE)
	var/datum/mind/who = warrant?.mind
	if(!who)
		return null
	var/datum/outpost_police_case/case = cases[who]
	if(case && !QDELETED(case))
		return case
	cases -= who
	if(LAZYACCESS(case_holds, who) > world.time)
		return null
	LAZYREMOVE(case_holds, who)
	var/mob/living/carbon/suspect = who.current
	if(!iscarbon(suspect) || QDELETED(suspect) || suspect.stat == DEAD)
		return null
	if(!takedown && HAS_TRAIT(suspect, TRAIT_CRITICAL_CONDITION))
		return null
	if(get_trader_outpost_for_turf(get_turf(suspect)) != outpost || in_custody(suspect))
		return null
	// Three stars and up: only someone down is taken alive; anyone on their feet is the squad's to stop. Where the
	// zone finishes the downed, nobody at three stars is taken alive (owner decision 39).
	if(get_stars(who) >= 3 && (!takedown || finishes_downed(suspect)))
		return null
	case = new /datum/outpost_police_case(src, warrant)
	cases[who] = case
	case.staff()
	wake()
	return case

/**
 * `fallen` went down (crit, stamina crit, a stun) in front of `barker`, an officer: at any stars they are cuffed where
 * they lie and taken to a cell, whatever the case limit or a hold from an earlier case (owner decision 37). The
 * nearest free stun officer takes it; with none free, `barker` does it himself. TRUE if an arrest is on them.
 */
/datum/outpost_police/proc/arrest_downed(mob/living/fallen, mob/living/carbon/human/npc/ambient_npc/outpost/police/barker)
	if(!iscarbon(fallen) || QDELETED(fallen) || !fallen.mind || fallen.stat == DEAD)
		return FALSE
	var/datum/outpost_warrant/warrant = get_warrant(fallen.mind)
	if(!warrant || get_stars(fallen.mind) < 1)
		return FALSE
	// Not taken alive where the zone finishes the downed (owner decision 39)
	if(finishes_downed(fallen, barker))
		return FALSE
	LAZYREMOVE(case_holds, fallen.mind)
	var/datum/outpost_police_case/case = cases[fallen.mind]
	if(!case || QDELETED(case))
		case = open_case(warrant, TRUE)
	if(!case)
		return FALSE
	// No stun officer free (or nobody at all): the officer who saw them go down does it himself
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/lead = case.arresting()
	// Covering someone else's arrest is not making one: he leaves that to see this one through
	if(istype(barker) && barker.case && barker.case != case && barker.case.arresting() != barker)
		barker.case.drop_officer(barker)
	// Not in the middle of something on the body (the cuffs, the search), and not once they are in cuffs: whoever has
	// them in hand sees it through
	if(istype(barker) && lead != barker && !barker.case && !case.acting && !case.cuffed && case.officer_fit(barker))
		if(!lead || (get_stars(fallen.mind) >= 3 && role_of(lead) != POLICE_ROLE_STUN))
			if(lead)
				case.drop_officer(lead)
			case.take_officer(barker)
			case.officers.Insert(1, WEAKREF(barker))
			case.staff()
	return TRUE

/**
 * Whether `target` has just been given an arrest's order and is still in the time to comply (one or two stars):
 * nobody fires on them meanwhile. Fire comes with the subdue (spec 6), never on someone standing still as told.
 */
/datum/outpost_police/proc/order_pending(mob/living/target)
	if(!isliving(target) || !target.mind)
		return FALSE
	var/datum/outpost_police_case/case = cases[target.mind]
	if(!case || QDELETED(case) || case.step != CASE_STEP_ORDER || case.get_suspect() != target)
		return FALSE
	return get_stars(target.mind) <= 2

/// Closes `who`'s arrest, if any
/datum/outpost_police/proc/close_case(datum/mind/who)
	var/datum/outpost_police_case/case = cases[who]
	cases -= who
	if(case && !QDELETED(case))
		qdel(case)

/// Once a second (police_core.dm tick()): start, reassign and close cases
/datum/outpost_police/proc/tick_cases()
	for(var/datum/mind/who as anything in cases.Copy())
		var/datum/outpost_police_case/case = cases[who]
		if(QDELETED(case))
			cases -= who
			continue
		case.process_case()

// =========================================================================
// THE CASE
// =========================================================================

/datum/outpost_police_case
	/// The police it is for
	var/datum/outpost_police/police
	/// The suspect's body when the case opened: a different body later is a lost suspect
	var/datum/weakref/suspect_ref
	/// The action running (CASE_ACT_*), or null
	var/acting
	/// world.time the action started
	var/acting_since = 0
	/// The sector a ride goes to
	var/ride_sector
	/// Where the arresting officer walks, or null to stand
	var/atom/goal
	/// How close to `goal` counts as there
	var/goal_distance = 0
	/// The lift tile the officer is walking to, to change sector
	var/turf/lift_goal
	/// world.time the order was given, or 0
	var/order_at = 0
	/// The suspect took a step of their own after the order
	var/suspect_moved = FALSE
	/// world.time the suspect went down before the cuffs, or 0
	var/downed_since = 0
	/// The medic was called for this fall
	var/medic_called = FALSE
	/// The suspect is in cuffs (ours, or on them already)
	var/cuffed = FALSE
	/// Those cuffs are police cuffs: getting out of them is a crime
	var/police_cuffs = FALSE
	/// The search is done
	var/searched = FALSE
	/// confiscate() calls made
	var/search_calls = 0
	/// The evidence case the search filled, if any
	var/datum/weakref/evidence_ref
	/// world.time the evidence was dealt with at the desk, or 0
	var/disposed_at = 0
	/// world.time book() was called, or 0
	var/booked_at = 0
	/// The suspect died, went down after the cuffs or the search, or is gone: only the evidence still goes to the desk
	var/suspect_lost = FALSE
	/// Baton blows thrown
	var/strikes = 0
	/// Whoever last started taking the suspect's cuffs off, and when
	var/datum/weakref/stripper_ref
	var/stripped_at = 0
	/// Minds reported for pulling the suspect: mind -> world.time of the last report
	var/list/resist_reports
	/// Lines said once this case: line -> TRUE
	var/list/said
	/// The arresting officer the last time staff() ran
	var/datum/weakref/last_arresting_ref
	/// Nearest the arresting officer has got to what it walks to this step: closing in keeps the step's clock fresh
	var/progress_dist = INFINITY
	/// REF() of what progress_dist is measured to
	var/progress_target
	/// world.time until which the police lift is not tried again (a ride that went nowhere): the officer walks
	var/ride_failed_until = 0
	/// Failed tries at picking the evidence case back up
	var/recover_tries = 0
	/// The officer had hold of the suspect on the walk
	var/escort_held = FALSE
	/// Times the suspect got out of the officer's hold on the walk: after the first, the hold is a firm grip
	var/pull_breaks = 0
	/// The suspect cannot be cuffed (fewer than two hands): held by tg's aggressive grip instead, for the whole walk
	var/grip_held = FALSE
	/// Nearest the officer has got to `lift_goal`, and when
	var/lift_best = INFINITY
	var/lift_best_at = 0
	/// Walks to the evidence locker that went nowhere: 1, the desk instead; 2, wherever the officer stands
	var/evidence_stalls = 0
	/// world.time a suspect held for want of a cell is next taken to one (CASE_STEP_HOLD)
	var/hold_retry_at = 0
	/// world.time the release step began
	var/release_since = 0
	/// Officers who had the release and did not get it done: not given it again
	var/list/release_tried
	/// Times the release went to another officer
	var/release_handoffs = 0

/datum/outpost_police_case/New(datum/outpost_police/new_police, datum/outpost_warrant/new_warrant)
	. = ..()
	police = new_police
	warrant = new_warrant
	var/mob/living/carbon/suspect = warrant?.mind?.current
	suspect_ref = suspect ? WEAKREF(suspect) : null
	set_step(CASE_STEP_RESPOND)

/datum/outpost_police_case/Destroy()
	var/mob/living/carbon/suspect = suspect_ref?.resolve()
	if(suspect)
		UnregisterSignal(suspect, list(COMSIG_MOVABLE_MOVED, COMSIG_BEING_STRIPPED))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/releaser
	for(var/datum/weakref/ref as anything in officers)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = ref?.resolve()
		if(!officer)
			continue
		if(!releaser && suspect && officer_fit(officer) && officer.Adjacent(suspect))
			releaser = officer
		drop_officer(officer)
	// Called off with police cuffs still on and nobody booking them: whoever stands by takes them off
	if(cuffed && police_cuffs && !booked_at && suspect && suspect.stat != DEAD && istype(suspect.handcuffed, /obj/item/restraints/handcuffs/outpost_police))
		if(step == CASE_STEP_RELEASE)
			// The release is over and no officer got the cuffs off (lead decision L-A2): the used pair comes off where
			// they stand, so nobody let go stays in police cuffs
			if(!police?.cell_holding(suspect.mind))
				outpost_police_drop_used_cuffs(suspect)
		else if(releaser)
			INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(outpost_police_take_cuffs_off), releaser, suspect)
	if(police && warrant?.mind && police.cases[warrant.mind] == src)
		police.cases -= warrant.mind
	officers = list()
	goal = null
	lift_goal = null
	warrant = null
	police = null
	return ..()

/// The suspect's body, or null if they are gone or in another body now
/datum/outpost_police_case/proc/get_suspect()
	var/mob/living/carbon/suspect = suspect_ref?.resolve()
	if(QDELETED(suspect) || warrant?.mind?.current != suspect)
		return null
	return suspect

/// Moves to `new_step` and starts its clock
/datum/outpost_police_case/proc/set_step(new_step)
	step = new_step
	step_started_at = world.time
	progress_dist = INFINITY
	goal = null

/// Sends the arresting officer to `where`, stopping `distance` from it (null: stand)
/datum/outpost_police_case/proc/set_goal(atom/where, distance = 0)
	goal = where
	goal_distance = distance

/// Ends the case
/datum/outpost_police_case/proc/close()
	if(QDELETED(src))
		return
	if(police && warrant?.mind)
		police.close_case(warrant.mind)
	if(!QDELETED(src))
		qdel(src)

/**
 * Ends the case, unless the suspect still wears our cuffs with nobody booking them: then an officer goes and takes
 * them off first (the release step), so nobody is left in police cuffs when an arrest is called off.
 */
/datum/outpost_police_case/proc/finish()
	if(QDELETED(src))
		return
	if(step != CASE_STEP_RELEASE && needs_release())
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
		var/mob/living/carbon/suspect = suspect_ref?.resolve()
		if(officer && suspect && officer.pulling == suspect)
			officer.stop_pulling()
		unregister_order(suspect)
		lift_goal = null
		set_step(CASE_STEP_RELEASE)
		release_since = world.time
		return
	close()

/// Whether the suspect still wears the used police cuffs this arrest put on, alive and at our outpost
/datum/outpost_police_case/proc/needs_release()
	var/mob/living/carbon/suspect = suspect_ref?.resolve()
	if(!police || QDELETED(suspect) || suspect.stat == DEAD || booked_at || !police_cuffs)
		return FALSE
	if(!istype(suspect.handcuffed, /obj/item/restraints/handcuffs/outpost_police/used))
		return FALSE
	return get_trader_outpost_for_turf(get_turf(suspect)) == police.outpost

/// The case goes back to the start (a step timed out). The third time it closes and the warrant is left to fade.
/datum/outpost_police_case/proc/reset_case()
	resets++
	if(resets >= 3)
		if(police && warrant?.mind)
			LAZYSET(police.case_holds, warrant.mind, world.time + CASE_REOPEN_HOLD)
		finish()
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	var/mob/living/carbon/suspect = get_suspect()
	if(officer && suspect && officer.pulling == suspect)
		officer.stop_pulling()
	unregister_order(suspect)
	lift_goal = null
	set_step(CASE_STEP_RESPOND)

// ----- officers -----

/// The arresting officer, or null
/datum/outpost_police_case/proc/arresting()
	var/datum/weakref/ref = length(officers) ? officers[1] : null
	return ref?.resolve()

/// The cover officer, or null
/datum/outpost_police_case/proc/cover()
	var/datum/weakref/ref = length(officers) >= 2 ? officers[2] : null
	return ref?.resolve()

/**
 * Whether `officer` can work a case: up, free, on our roster, at the outpost and not leaving. One held still by the
 * empty-outpost pause can (take_officer() wakes them); one held for anything else, such as a wave still forming up
 * in its lift, cannot (review-1 M1).
 */
/datum/outpost_police_case/proc/officer_fit(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(QDELETED(officer) || officer.stat != CONSCIOUS || HAS_TRAIT(officer, TRAIT_RESTRAINED) || officer.fading || officer.npc_exit)
		return FALSE
	if(HAS_TRAIT_NOT_FROM(officer, TRAIT_AI_PAUSED, AMBIENT_PAUSED_TRAIT))
		return FALSE
	if(!police || officer.police != police || !(officer in police.officers))
		return FALSE
	return get_trader_outpost_for_turf(get_turf(officer)) == police.outpost

/// Keeps two fit officers on the case: the arresting one first, then the cover. The cover takes over from a lost arresting officer.
/datum/outpost_police_case/proc/staff()
	var/list/kept = list()
	for(var/datum/weakref/ref as anything in officers)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = ref?.resolve()
		if(!officer || (officer in kept))
			continue
		if(officer.case == src && officer_fit(officer) && !(release_tried && (WEAKREF(officer) in release_tried)))
			kept += officer
		else
			drop_officer(officer)
	// A stunned arresting officer hands over to a cover officer on their feet
	if(length(kept) >= 2)
		var/mob/living/first = kept[1]
		var/mob/living/second = kept[2]
		if(HAS_TRAIT(first, TRAIT_INCAPACITATED) && !HAS_TRAIT(second, TRAIT_INCAPACITATED))
			kept.Swap(1, 2)
	var/mob/living/carbon/suspect = get_suspect()
	while(length(kept) < 2)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/found = nearest_free_officer(suspect, kept)
		if(!found)
			break
		take_officer(found)
		kept += found
	officers = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in kept)
		officers += WEAKREF(officer)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/lead = length(kept) ? kept[1] : null
	if(lead != last_arresting_ref?.resolve())
		last_arresting_ref = lead ? WEAKREF(lead) : null
		goal = null
		lift_goal = null
		// A new arresting officer starts the step's clock afresh
		step_started_at = world.time

/// The nearest officer with no case, beat and response officers before the desk sergeant; at three stars and up a
/// stun officer before anyone else (owner decision 37)
/datum/outpost_police_case/proc/nearest_free_officer(mob/living/carbon/suspect, list/exclude)
	var/turf/where = get_turf(suspect)
	var/high = warrant?.mind && police?.get_stars(warrant.mind) >= 3
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/best
	var/best_score = INFINITY
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police?.officers)
		if(officer.case || (officer in exclude) || !officer_fit(officer))
			continue
		if(release_tried && (WEAKREF(officer) in release_tried))
			continue
		var/turf/officer_turf = get_turf(officer)
		var/score = (where && officer_turf?.z == where.z) ? get_dist(officer_turf, where) : 500
		if(officer.unit_kind == POLICE_UNIT_SERGEANT)
			score += 1000
		if(high && police.role_of(officer) != POLICE_ROLE_STUN)
			score += 2000
		if(score < best_score)
			best = officer
			best_score = score
	return best

/// `officer` joins the case: whatever they were doing stops, and one who can see the suspect is on them (spec-stealth P5)
/datum/outpost_police_case/proc/take_officer(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	officer.case = src
	// Held still by an empty concourse (the suspect ran to a hangar or a ship): on a case nobody freezes (owner decision 34)
	officer.resume_routine()
	if(officer.activity)
		officer.end_activity()
	officer.ai_controller?.CancelActions()
	var/mob/living/carbon/suspect = get_suspect()
	// On their feet and in view: on them. Someone down is only walked up to and cuffed.
	if(suspect && !cuffed && officer.police_will_fight(suspect) && police?.perception?.sees(officer, suspect))
		officer.police_alert_on(suspect)

/// `officer` leaves the case: lets go of the suspect, stops walking for it and stops shooting at them
/datum/outpost_police_case/proc/drop_officer(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(QDELETED(officer))
		return
	var/mob/living/carbon/suspect = suspect_ref?.resolve()
	if(officer.case == src)
		officer.case = null
	if(suspect && officer.pulling == suspect)
		officer.stop_pulling()
	police?.clear_checkpoint_crossing(officer)
	// The case is over and the suspect is nobody to them now (booked, let go, faded): back to the beat, and held
	// still again if nobody is on the concourse
	if(!suspect || !police || police.force_level(suspect, officer) == POLICE_FORCE_NONE)
		officer.police_stand_easy()
		var/datum/ambient_place/outpost/place = officer.place
		if(istype(place) && !place.occupied && !officer.case)
			officer.pause_routine()
	var/datum/ai_controller/controller = officer.ai_controller
	if(controller)
		controller.clear_blackboard_key(BB_OUTPOST_POLICE_CASE_GOAL)
		if(suspect && controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET] == suspect)
			controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)

// ----- the suspect -----

/// Dead or in crit
/datum/outpost_police_case/proc/suspect_downed(mob/living/carbon/suspect)
	return suspect.stat == DEAD || HAS_TRAIT(suspect, TRAIT_CRITICAL_CONDITION)

/// Subdued: on the floor, stunned, stamcrit, already restrained, or lying there after *surrender
/datum/outpost_police_case/proc/suspect_subdued(mob/living/carbon/suspect)
	return suspect.body_position == LYING_DOWN || HAS_TRAIT(suspect, TRAIT_INCAPACITATED) || HAS_TRAIT(suspect, TRAIT_RESTRAINED)

/// A gun or a melee weapon in their hands
/datum/outpost_police_case/proc/suspect_armed(mob/living/carbon/suspect)
	for(var/obj/item/held in suspect.held_items)
		if(isgun(held) || human_npc_is_melee_weapon(held))
			return TRUE
	return FALSE

/// Did as told: down, or stood still since the order with empty hands and no fight in them
/datum/outpost_police_case/proc/suspect_complied(mob/living/carbon/suspect)
	if(suspect_subdued(suspect))
		return TRUE
	return !suspect_moved && !suspect.combat_mode && !suspect_armed(suspect)

/// After the order their own steps count against them; being pushed, pulled or thrown does not
/datum/outpost_police_case/proc/on_suspect_moved(mob/living/carbon/source, atom/old_loc, dir, forced, list/old_locs)
	SIGNAL_HANDLER
	if(!forced && !source.pulledby && !source.throwing && !source.buckled)
		suspect_moved = TRUE

/**
 * Someone starts taking the suspect's cuffs off through the strip menu. COMSIG_TRY_STRIP is the same string,
 * sent when the suspect strips someone else: then `item` is not their cuffs and nothing happens.
 */
/datum/outpost_police_case/proc/on_suspect_stripped(mob/living/carbon/source, mob/stripper, obj/item/item)
	SIGNAL_HANDLER
	if(!item || item != source.handcuffed || stripper == source || istype(stripper, /mob/living/carbon/human/npc/ambient_npc/outpost/police))
		return
	stripper_ref = WEAKREF(stripper)
	stripped_at = world.time

/// The "look" token for a line about `suspect` (police_life.dm fills %LOOK% from it): the type name of what they wear (abuse M15)
/datum/outpost_police_case/proc/line_values(mob/living/carbon/suspect)
	var/look = suspect && outpost_police_look(suspect)
	return look ? list("look" = look) : null

/// `officer` says `line` once per case
/datum/outpost_police_case/proc/say_once(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, line, mob/living/carbon/suspect, radio = FALSE)
	if(!officer || LAZYACCESS(said, line))
		return
	LAZYSET(said, line, TRUE)
	officer.police_say(line, line_values(suspect), radio)

/// Files a crime from the case
/datum/outpost_police_case/proc/report(mob/living/offender, crime, atom/victim, obj/item/source)
	if(!police || QDELETED(offender))
		return
	police.report_crime(offender, crime, victim, source)

// =========================================================================
// ONCE A SECOND
// =========================================================================

/// Closes, staffs, watches and runs the current step. Never sleeps.
/datum/outpost_police_case/proc/process_case()
	if(QDELETED(src) || !police)
		return
	if(acting)
		if(world.time - acting_since < CASE_ACTION_STUCK)
			return
		acting = null
	if(step == CASE_STEP_RELEASE)
		process_release()
		return
	var/mob/living/carbon/suspect = get_suspect()
	if(check_close(suspect))
		return
	staff()
	if(suspect)
		check_escape(suspect)
		check_interference(suspect)
		check_down(suspect)
	if(QDELETED(src))
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	if(!officer)
		// Nobody to work it: the case waits for dispatch, and the clock waits with it
		step_started_at = world.time
		return
	if(step != CASE_STEP_DOWNED && step != CASE_STEP_HOLD && world.time - step_started_at >= OUTPOST_POLICE_STEP_TIMEOUT)
		// Three stars and up, in cuffs with the evidence handed in, and the cell can't be got to: held, not let go
		if((step == CASE_STEP_DESK || step == CASE_STEP_BOOK) && hold_for_cell())
			start_hold()
			return
		reset_case()
		return
	// Nobody stands over someone in crit for ever (review-1 S1): the arrest is called off and the cuffs come off
	if(step == CASE_STEP_DOWNED && downed_since && world.time - downed_since >= CASE_DOWNED_LIMIT)
		if(police && warrant?.mind)
			LAZYSET(police.case_holds, warrant.mind, world.time + CASE_REOPEN_HOLD)
		finish()
		return
	if(recover_evidence(officer))
		return
	run_step()

/**
 * The release step, once a second: an officer walks up to the suspect and takes our cuffs off. An officer who gets
 * no nearer in a step's time hands it to another, up to CASE_RELEASE_HANDOFFS times; after that, or after
 * CASE_RELEASE_LIMIT in all, the case ends and the used pair comes off where they stand (Destroy()).
 */
/datum/outpost_police_case/proc/process_release()
	if(!needs_release())
		close()
		return
	if(world.time - release_since >= CASE_RELEASE_LIMIT)
		close()
		return
	staff()
	if(QDELETED(src))
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	if(!officer)
		// Every officer about has had a go: nobody is left to do it
		if(LAZYLEN(release_tried))
			close()
			return
		step_started_at = world.time
		return
	if(world.time - step_started_at >= OUTPOST_POLICE_STEP_TIMEOUT)
		if(release_handoffs >= CASE_RELEASE_HANDOFFS)
			close()
			return
		release_handoffs++
		LAZYADD(release_tried, WEAKREF(officer))
		drop_officer(officer)
		staff()
		step_started_at = world.time
		return
	step_release()

/// Runs the current step's proc
/datum/outpost_police_case/proc/run_step()
	switch(step)
		if(CASE_STEP_RESPOND)
			step_respond()
		if(CASE_STEP_ORDER)
			step_order()
		if(CASE_STEP_SUBDUE)
			step_subdue()
		if(CASE_STEP_CUFF)
			step_cuff()
		if(CASE_STEP_SEARCH)
			step_search()
		if(CASE_STEP_ESCORT)
			step_escort()
		if(CASE_STEP_DESK)
			step_desk()
		if(CASE_STEP_BOOK)
			step_book()
		if(CASE_STEP_DOWNED)
			step_downed()
		if(CASE_STEP_RELEASE)
			step_release()
		if(CASE_STEP_HOLD)
			step_hold()

/**
 * Whether the case is over, and closes it if so: the warrant gone, no stars, three or more stars on someone
 * not yet in cuffs (the lethal response takes over), or the suspect gone with no evidence left for the desk.
 */
/datum/outpost_police_case/proc/check_close(mob/living/carbon/suspect)
	if(!warrant?.mind || police.get_warrant(warrant.mind) != warrant)
		finish()
		return TRUE
	if(!suspect || get_trader_outpost_for_turf(get_turf(suspect)) != police.outpost)
		if(!searched || disposed_at)
			close()
			return TRUE
		mark_lost(suspect)
		return FALSE
	if(suspect_lost)
		return FALSE
	var/stars = police.get_stars(warrant.mind)
	// Three stars and up: in cuffs, or down, they are taken alive (owner decision 37). Up and free, they are the
	// squad's again.
	if(stars <= 0 || (stars >= 3 && !cuffed && (!police_suspect_down(suspect) || police.finishes_downed(suspect))))
		finish()
		return TRUE
	return FALSE

/// Only the evidence goes on to the desk now. Nobody moves the body.
/datum/outpost_police_case/proc/mark_lost(mob/living/carbon/suspect)
	if(!suspect_lost)
		suspect_lost = TRUE
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
		if(officer && suspect && officer.pulling == suspect)
			officer.stop_pulling()
		unregister_order(suspect)
		lift_goal = null
	// Lost after being stood by (dead in crit, or gone): the standby is over too (review-1 S1)
	if(step != CASE_STEP_DESK && step != CASE_STEP_ESCORT)
		set_step(CASE_STEP_ESCORT)

/// Out of the cuffs before the cell: their own doing is SLIP_CUFFS, someone else's ABET. Back to respond.
/datum/outpost_police_case/proc/check_escape(mob/living/carbon/suspect)
	if(!cuffed || step == CASE_STEP_BOOK || suspect.handcuffed)
		return
	// Held by the grip, not cuffs: getting loose is caught by keep_pulling()'s chase, not an escape from cuffs
	if(grip_held && !police_cuffs)
		return
	cuffed = FALSE
	UnregisterSignal(suspect, COMSIG_BEING_STRIPPED)
	if(police_cuffs)
		var/mob/living/stripper = stripper_ref?.resolve()
		if(stripper?.mind && world.time - stripped_at <= CASE_STRIPPER_WINDOW)
			report(stripper, OUTPOST_CRIME_ABET, suspect)
		else
			report(suspect, OUTPOST_CRIME_SLIP_CUFFS)
	police_cuffs = FALSE
	stripper_ref = null
	if(QDELETED(src) || suspect_lost)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	if(officer?.pulling == suspect)
		officer.stop_pulling()
	lift_goal = null
	set_step(CASE_STEP_RESPOND)

/// Someone other than an officer pulling the suspect once the order is given: RESIST, every OUTPOST_POLICE_BLOCK_TIME
/datum/outpost_police_case/proc/check_interference(mob/living/carbon/suspect)
	var/mob/living/puller = suspect.pulledby
	if(!isliving(puller) || !puller.mind || puller == suspect || istype(puller, /mob/living/carbon/human/npc/ambient_npc/outpost/police))
		return
	if(!order_at && !cuffed)
		return
	var/last = LAZYACCESS(resist_reports, puller.mind)
	if(last && world.time - last < OUTPOST_POLICE_BLOCK_TIME)
		return
	LAZYSET(resist_reports, puller.mind, world.time)
	report(puller, OUTPOST_CRIME_RESIST, arresting() || suspect)

/**
 * Dead, or in crit (owner decision 37). Dead before the cuffs: nobody left to arrest. Dead after the cuffs or the
 * search: only the evidence goes on. Alive in crit: cuffed where they lie, nobody shooting at them, then held there
 * (a medic called once) until they come round and can be walked to the cell.
 */
/datum/outpost_police_case/proc/check_down(mob/living/carbon/suspect)
	if(!suspect_downed(suspect))
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	if(suspect.stat == DEAD)
		if(!cuffed && !searched)
			close()
			return
		if(!suspect_lost)
			if(searched)
				mark_lost(suspect)
			else
				// Cuffed and dead: the search still happens where they lie, then the desk
				suspect_lost = TRUE
				if(officer?.pulling == suspect)
					officer.stop_pulling()
		return
	if(suspect_lost)
		return
	clear_targets(suspect)
	if(!cuffed)
		if(step != CASE_STEP_CUFF)
			if(officer?.pulling == suspect)
				officer.stop_pulling()
			enter_cuff(suspect)
		return
	if(step == CASE_STEP_DOWNED)
		return
	if(officer?.pulling == suspect)
		officer.stop_pulling()
	unregister_order(suspect)
	lift_goal = null
	set_step(CASE_STEP_DOWNED)
	downed_since = world.time
	medic_called = FALSE

/// Nobody on the case keeps `suspect` as a target
/datum/outpost_police_case/proc/clear_targets(mob/living/carbon/suspect)
	for(var/datum/weakref/ref as anything in officers)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/other = ref?.resolve()
		var/datum/ai_controller/controller = other?.ai_controller
		if(controller?.blackboard[BB_BASIC_MOB_CURRENT_TARGET] == suspect)
			controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)

/**
 * An evidence case that is not on the arresting officer: on the floor, or on a fallen officer. They go and
 * get it (spec 6.4: the cover takes over). TRUE while they are about it. One in anyone else's hands is theirs.
 */
/datum/outpost_police_case/proc/recover_evidence(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(!searched || disposed_at)
		return FALSE
	var/obj/item/evidence = evidence_ref?.resolve()
	if(QDELETED(evidence))
		evidence_ref = null
		return FALSE
	if(evidence in officer.get_all_contents())
		recover_tries = 0
		return FALSE
	if(recover_tries >= CASE_RECOVER_TRIES)
		// It cannot be carried: left where it lies, and the arrest goes on without it
		log_game("OUTPOST POLICE: [key_name(officer)] could not pick up the evidence ([evidence]) at [AREACOORD(evidence)].")
		evidence_ref = null
		recover_tries = 0
		return FALSE
	var/atom/holder = evidence.loc
	if(isturf(holder))
		if(route_to(officer, holder, 1))
			begin_action(CASE_ACT_RECOVERING)
		return TRUE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/fallen = holder
	if(istype(fallen) && fallen != officer && fallen.stat != CONSCIOUS)
		if(route_to(officer, fallen, 1))
			begin_action(CASE_ACT_RECOVERING)
		return TRUE
	// In someone's hands or bag: an ordinary case now (spec 6.1)
	evidence_ref = null
	return FALSE

/**
 * Gets `officer` within `distance` of `target`: on foot on the same floor (through the concourse exit gate or the
 * security checkpoint between concourse and lobby), or by the hangar elevator between lobby and berths.
 * TRUE once there; otherwise it has set the goal or started the elevator ride.
 */
/datum/outpost_police_case/proc/route_to(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, atom/target, distance = 1)
	var/turf/here = get_turf(officer)
	var/turf/there = get_turf(target)
	if(!here || !there)
		police?.clear_checkpoint_crossing(officer)
		set_goal(null)
		return FALSE
	if(here.z == there.z && get_dist(here, there) <= distance)
		police?.clear_checkpoint_crossing(officer)
		set_goal(null)
		return TRUE
	// Closing in (a chase, a long walk) is progress: the step only times out once the officer stops getting nearer
	if(progress_target != REF(target))
		progress_target = REF(target)
		progress_dist = INFINITY
	var/dist = here.z == there.z ? get_dist(here, there) : INFINITY
	if(dist < progress_dist)
		progress_dist = dist
		step_started_at = world.time
	var/from_sector = police.sector_of(here)
	var/to_sector = police.sector_of(there)
	// Concourse <-> berth goes by foot through the lobby, then the hangar elevator
	if(from_sector == POLICE_SECTOR_CONCOURSE && istype(to_sector, /datum/outpost_berth) && length(police.outpost?.lobby_alcove_turfs))
		to_sector = POLICE_SECTOR_LOBBY
	else if(istype(from_sector, /datum/outpost_berth) && to_sector == POLICE_SECTOR_CONCOURSE && length(police.outpost?.lobby_alcove_turfs))
		to_sector = POLICE_SECTOR_LOBBY
	if(from_sector == to_sector || world.time < ride_failed_until)
		police.clear_checkpoint_crossing(officer)
		lift_goal = null
		set_goal(target, distance)
		return FALSE
	if(police.dispatch_same_floor(from_sector, to_sector))
		lift_goal = null
		if(from_sector == POLICE_SECTOR_CONCOURSE)
			police.clear_checkpoint_crossing(officer)
			var/atom/walk_target = (police.sector_of(there) == POLICE_SECTOR_LOBBY) ? target : (police.lift_point(POLICE_SECTOR_LOBBY, null, officer) || target)
			set_goal(walk_target, walk_target == target ? distance : 0)
			return FALSE
		var/list/step_info = police.checkpoint_step_goal(officer, target)
		if(!step_info)
			set_goal(target, distance)
			return FALSE
		set_goal(step_info[1], step_info[2])
		return FALSE
	police.clear_checkpoint_crossing(officer)
	if(!lift_goal || police.sector_of(lift_goal) != from_sector)
		lift_goal = police.lift_point(from_sector, null, officer)
		lift_best = INFINITY
		lift_best_at = world.time
	if(!lift_goal)
		// No lift from here: try the walk
		set_goal(target, distance)
		return FALSE
	if(here != lift_goal)
		// A lift point the officer gets no nearer to (someone stands on it, or it is boxed in) is given up for
		// another (review-1 S4)
		var/lift_dist = here.z == lift_goal.z ? get_dist(here, lift_goal) : INFINITY
		if(lift_dist < lift_best)
			lift_best = lift_dist
			lift_best_at = world.time
		else if(world.time - lift_best_at >= CASE_LIFT_PATIENCE)
			police.dispatch_skipped[lift_goal] = world.time + CASE_LIFT_SKIP
			lift_goal = null
			set_goal(null)
			return FALSE
		set_goal(lift_goal, 0)
		return FALSE
	set_goal(null)
	ride_sector = to_sector
	begin_action(CASE_ACT_RIDING)
	return FALSE

/**
 * Suspect inside a locker or crate after contact: walks up to it and opens it the normal way (unlocking first if our
 * ID opens it). TRUE once the suspect is out on a turf; FALSE while walking to it or if it is welded or locked fast.
 */
/datum/outpost_police_case/proc/expose_suspect(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, mob/living/carbon/suspect)
	if(!officer || !suspect)
		return FALSE
	if(isturf(suspect.loc))
		return TRUE
	var/obj/structure/closet/box = suspect.loc
	if(!istype(box) || !isturf(box.loc))
		return FALSE
	if(!officer.Adjacent(box))
		route_to(officer, box, 1)
		return FALSE
	set_goal(null)
	if(box.locked)
		box.togglelock(officer, TRUE)
	if(!box.locked && !box.opened)
		box.open(officer)
	return isturf(suspect.loc)

/**
 * Keeps `officer` pulling the suspect, running after them first if they got away. Once they have broken free on
 * the walk, the officer takes tg's aggressive grip instead of a plain pull. TRUE while holding them.
 */
/datum/outpost_police_case/proc/keep_pulling(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, mob/living/carbon/suspect)
	if(!isturf(suspect.loc) && !expose_suspect(officer, suspect))
		return FALSE
	if(suspect.buckled && officer.Adjacent(suspect))
		suspect.buckled.user_unbuckle_mob(suspect, officer)
		if(suspect.buckled)
			return FALSE
	if(officer.pulling == suspect)
		escort_held = TRUE
		if((pull_breaks || grip_held) && officer.grab_state < GRAB_AGGRESSIVE && officer.Adjacent(suspect))
			suspect.grabbedby(officer, TRUE)
		police_case_pace(officer, FALSE)
		return TRUE
	if(escort_held)
		escort_held = FALSE
		pull_breaks++
	if(!officer.Adjacent(suspect))
		police_case_pace(officer, TRUE)
		route_to(officer, suspect, 1)
		return FALSE
	if(suspect.buckled)
		suspect.buckled.user_unbuckle_mob(suspect, officer)
		if(suspect.buckled)
			return FALSE
	officer.start_pulling(suspect)
	if(officer.pulling != suspect)
		return FALSE
	escort_held = TRUE
	if(pull_breaks || grip_held)
		suspect.grabbedby(officer, TRUE)
	police_case_pace(officer, FALSE)
	return TRUE

/// The arresting officer runs after a suspect and walks one it holds
/datum/outpost_police_case/proc/police_case_pace(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, run)
	var/datum/ai_controller/basic_controller/human_npc/stealth/brain = officer?.ai_controller
	if(istype(brain) && !officer.client)
		brain.stealth_set_pace(run)

/// Stops listening for the suspect's steps after the order
/datum/outpost_police_case/proc/unregister_order(mob/living/carbon/suspect)
	if(suspect)
		UnregisterSignal(suspect, COMSIG_MOVABLE_MOVED)

/// What follows reaching the suspect: the order, or (cuffs on already) the search or the walk
/datum/outpost_police_case/proc/after_contact()
	if(cuffed)
		set_step(searched ? CASE_STEP_ESCORT : CASE_STEP_SEARCH)
		return
	order_at = 0
	set_step(CASE_STEP_ORDER)

// =========================================================================
// THE STEPS (one call each; none sleeps)
// =========================================================================

/// Respond: to the suspect if seen, else where they were last seen. Over once they are close and in view.
/datum/outpost_police_case/proc/step_respond()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	var/mob/living/carbon/suspect = get_suspect()
	if(!officer || !suspect)
		return
	if(!isturf(suspect.loc) && warrant.last_seen_turf && get_turf(suspect) == warrant.last_seen_turf && officer.Adjacent(suspect.loc))
		expose_suspect(officer, suspect)
	if(isturf(suspect.loc) && officer.Adjacent(suspect))
		set_goal(null)
		officer.police_alert_on(suspect)
		after_contact()
		return
	police_case_pace(officer, TRUE)
	if(police.perception?.sees(officer, suspect))
		police.note_seen(warrant.mind, get_turf(suspect))
		if(get_dist(officer, suspect) <= CASE_CONTACT_RANGE)
			set_goal(null)
			// The order and its time to comply start once the officer is on them (spec-stealth P5)
			officer.police_alert_on(suspect)
			after_contact()
			return
		route_to(officer, suspect, 1)
		return
	// Out of sight: to where they were last seen, and look about there (the step times out if they never turn up)
	route_to(officer, warrant.last_seen_turf || get_turf(suspect), 1)

/// Order: the order, then the zone's time to comply. Complied: the cuffs. Not: the baton.
/datum/outpost_police_case/proc/step_order()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	var/mob/living/carbon/suspect = get_suspect()
	if(!officer || !suspect)
		return
	if(!isturf(suspect.loc) && !expose_suspect(officer, suspect))
		return
	if(!order_at)
		order_at = world.time
		suspect_moved = FALSE
		RegisterSignal(suspect, COMSIG_MOVABLE_MOVED, PROC_REF(on_suspect_moved), override = TRUE)
		officer.face_atom(suspect)
		officer.police_say(POLICE_LINE_ORDER, line_values(suspect))
	if(suspect_subdued(suspect))
		enter_cuff(suspect)
		return
	if(world.time - order_at < (police.profile?.comply_time || 3 SECONDS))
		// Close in while they make up their mind
		if(!officer.Adjacent(suspect))
			route_to(officer, suspect, 1)
		return
	if(suspect_complied(suspect))
		enter_cuff(suspect)
		return
	unregister_order(suspect)
	set_step(CASE_STEP_SUBDUE)

/// On to the cuffs, watching their own steps from now: walking off from the cuffs is fighting them
/datum/outpost_police_case/proc/enter_cuff(mob/living/carbon/suspect)
	suspect_moved = FALSE
	RegisterSignal(suspect, COMSIG_MOVABLE_MOVED, PROC_REF(on_suspect_moved), override = TRUE)
	set_step(CASE_STEP_CUFF)

/// Subdue: baton blows (a real click, the baton's own cooldown) until they are down
/datum/outpost_police_case/proc/step_subdue()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	var/mob/living/carbon/suspect = get_suspect()
	if(!officer || !suspect)
		return
	if(!isturf(suspect.loc) && !expose_suspect(officer, suspect))
		return
	if(suspect_subdued(suspect))
		clear_cover_target(suspect)
		enter_cuff(suspect)
		return
	if(officer.force != POLICE_FORCE_ARREST)
		officer.set_force(POLICE_FORCE_ARREST)
	// Off and running: "Stop!"; close, at two stars or more: "On the ground!"
	if(get_dist(officer, suspect) > 2)
		say_once(officer, POLICE_LINE_CHASE, suspect)
	else if(police.get_stars(warrant.mind) >= 2)
		say_once(officer, POLICE_LINE_STUN, suspect)
	if(!officer.Adjacent(suspect))
		route_to(officer, suspect, 1)
		return
	set_goal(null)
	INVOKE_ASYNC(src, PROC_REF(strike), officer, suspect)

/// One baton blow if it is ready, through outpost_prison_npc_hit() (a fist if they have no baton). TRUE if thrown.
/datum/outpost_police_case/proc/strike(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, mob/living/carbon/suspect)
	if(QDELETED(src) || QDELETED(officer) || QDELETED(suspect) || !officer.Adjacent(suspect))
		return FALSE
	var/obj/item/baton = officer.get_baton()
	if(baton && !officer.is_holding(baton) && !human_npc_take_in_hand(officer, baton))
		baton = null
	if(baton)
		human_npc_ready_weapon(officer, baton)
		var/obj/item/melee/baton/stick = baton
		if(istype(stick) && !COOLDOWN_FINISHED(stick, cooldown_check))
			return FALSE
	if(!outpost_prison_npc_hit(officer, suspect, baton))
		return FALSE
	strikes++
	return TRUE

/// The cover stops shooting a suspect who is down
/datum/outpost_police_case/proc/clear_cover_target(mob/living/carbon/suspect)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/other = cover()
	var/datum/ai_controller/controller = other?.ai_controller
	if(controller?.blackboard[BB_BASIC_MOB_CURRENT_TARGET] == suspect)
		controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)

/// Cuff: up to them, then tg's attempt_to_cuff() and its do_after. Back to the baton if they fight on.
/datum/outpost_police_case/proc/step_cuff()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	var/mob/living/carbon/suspect = get_suspect()
	if(!officer || !suspect)
		return
	if(suspect.handcuffed)
		cuffs_on(suspect)
		return
	if(!isturf(suspect.loc) && !expose_suspect(officer, suspect))
		return
	if(!suspect_subdued(suspect) && (suspect.combat_mode || suspect_armed(suspect) || suspect_moved))
		unregister_order(suspect)
		set_step(CASE_STEP_SUBDUE)
		return
	if(!officer.Adjacent(suspect))
		route_to(officer, suspect, 1)
		return
	set_goal(null)
	// No cuffs fit (fewer than two hands): held in tg's aggressive grip instead, and walked in it (review-1 S3)
	if(!suspect.canBeHandcuffed())
		if(keep_pulling(officer, suspect) && officer.grab_state < GRAB_AGGRESSIVE)
			suspect.grabbedby(officer, TRUE)
		if(officer.pulling == suspect && officer.grab_state >= GRAB_AGGRESSIVE)
			grip_held = TRUE
			cuffs_on(suspect)
		return
	begin_action(CASE_ACT_CUFFING)

/// The cuffs are on: watch who takes them off, then the search
/datum/outpost_police_case/proc/cuffs_on(mob/living/carbon/suspect)
	unregister_order(suspect)
	cuffed = TRUE
	police_cuffs = istype(suspect.handcuffed, /obj/item/restraints/handcuffs/outpost_police)
	stripper_ref = null
	RegisterSignal(suspect, COMSIG_BEING_STRIPPED, PROC_REF(on_suspect_stripped), override = TRUE)
	clear_cover_target(suspect)
	// In hand: nobody to fight or look for. The walk to the desk is a calm one.
	for(var/datum/weakref/ref as anything in officers)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = ref?.resolve()
		officer?.police_stand_easy()
	set_step(searched ? CASE_STEP_ESCORT : CASE_STEP_SEARCH)

/// Search: police.confiscate() takes the offending items into an evidence case (P12). Once per case.
/datum/outpost_police_case/proc/step_search()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	var/mob/living/carbon/suspect = get_suspect()
	if(searched)
		set_step(CASE_STEP_ESCORT)
		return
	if(!officer || !suspect)
		return
	if(!isturf(suspect.loc) && !expose_suspect(officer, suspect))
		return
	// Held while searched: a cuffed suspect who is pulled cannot step off (review-1 M3)
	if(!suspect_downed(suspect) && !keep_pulling(officer, suspect))
		return
	if(!officer.Adjacent(suspect))
		route_to(officer, suspect, 1)
		return
	set_goal(null)
	begin_action(CASE_ACT_SEARCHING)

/// Escort: pull them along, the police lift to the desk's sector, then the desk. A lost suspect stays where they are; the evidence still goes.
/datum/outpost_police_case/proc/step_escort()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	if(!officer)
		return
	if(!suspect_lost)
		var/mob/living/carbon/suspect = get_suspect()
		if(!suspect || !keep_pulling(officer, suspect))
			return
		say_once(officer, POLICE_LINE_WALK, suspect)
		make_way(officer, suspect)
	var/atom/desk = evidence_spot(officer)
	if(!desk || route_to(officer, desk, 1))
		set_step(CASE_STEP_DESK)
		return
	check_evidence_stall(officer, desk)

/**
 * Walking a suspect in: someone standing in the way, on either of the next two tiles the officer faces, is told to
 * make way. Two tiles looked at, once a second; the line's own gaps keep it from repeating.
 */
/datum/outpost_police_case/proc/make_way(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, mob/living/carbon/suspect)
	var/turf/ahead = get_turf(officer)
	for(var/i in 1 to 2)
		ahead = get_step(ahead, officer.dir)
		if(!ahead || ahead.density)
			return null
		for(var/mob/living/someone in ahead)
			if(someone == suspect || someone.stat != CONSCIOUS || istype(someone, /mob/living/carbon/human/npc/ambient_npc/outpost/police))
				continue
			return officer.police_say(POLICE_LINE_MAKE_WAY)
	return null

/**
 * Where the evidence goes: the evidence locker, or the desk when the station has none or the locker can't be got to,
 * or where the officer stands when neither can (review-1 S4); null with no evidence to take
 */
/datum/outpost_police_case/proc/evidence_spot(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(disposed_at || !(locate(/obj/item/outpost_sealed_case/evidence) in officer.get_all_contents()))
		return null
	if(evidence_stalls >= 2)
		return get_turf(officer)
	var/atom/locker = police.get_evidence_locker()
	if(evidence_stalls >= 1 || !locker)
		return police.desk_turf || locker
	return locker

/**
 * The walk to `spot` with the evidence, in the same sector, has gone nowhere for CASE_EVIDENCE_PATIENCE: the next
 * place to put it is tried. route_to() keeps the step's clock fresh while the officer gets nearer.
 */
/datum/outpost_police_case/proc/check_evidence_stall(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, atom/spot)
	if(!spot || evidence_stalls >= 2 || police.sector_of(get_turf(officer)) != police.sector_of(get_turf(spot)))
		return
	if(world.time - step_started_at < CASE_EVIDENCE_PATIENCE)
		return
	evidence_stalls++
	step_started_at = world.time
	progress_dist = INFINITY

/// Desk: the evidence goes in the evidence locker (P12), then on to the cell door. A lost suspect's case ends here.
/datum/outpost_police_case/proc/step_desk()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	if(!officer)
		return
	if(!disposed_at)
		var/atom/desk = evidence_spot(officer)
		if(!desk)
			// Nothing taken, or nothing carried any more: straight on
			disposed_at = world.time
		else
			if(route_to(officer, desk, 1))
				set_goal(null)
				begin_action(CASE_ACT_DISPOSING)
			else
				check_evidence_stall(officer, desk)
			return
	if(suspect_lost)
		close()
		return
	var/mob/living/carbon/suspect = get_suspect()
	if(!suspect || !keep_pulling(officer, suspect))
		return
	make_way(officer, suspect)
	var/turf/door = police.cell_door_turf()
	if(!door || route_to(officer, door, 1))
		set_step(CASE_STEP_BOOK)

/// Book: the cell (P6). Whatever comes of it, the case is done.
/datum/outpost_police_case/proc/step_book()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	var/mob/living/carbon/suspect = get_suspect()
	if(!officer || !suspect || booked_at)
		return
	if(!disposed_at)
		// The evidence goes before anything else
		set_step(CASE_STEP_DESK)
		return
	// Booked only when brought to the door in hand. Got away and caught somewhere else, they are walked back to it
	// first: booking never moves anyone further than through the door (review-1 S2)
	var/turf/door = police.cell_door_turf()
	if(officer.pulling != suspect || (door && (officer.z != door.z || get_dist(officer, door) > 1)))
		set_step(CASE_STEP_DESK)
		return
	set_goal(null)
	begin_action(CASE_ACT_BOOKING)

/**
 * Standing by a cuffed suspect in crit: a medic called once, the search done where they lie, and the step's clock
 * held while they lie there. Once they come round, on to the cell.
 */
/datum/outpost_police_case/proc/step_downed()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	var/mob/living/carbon/suspect = get_suspect()
	if(!suspect || !officer)
		return
	if(!suspect_downed(suspect))
		downed_since = 0
		after_contact()
		return
	step_started_at = world.time
	// Died while stood by (review-1 S1): searched where they lie, then only the evidence goes on
	if(suspect.stat == DEAD && searched)
		mark_lost(suspect)
		return
	if(!medic_called && suspect.stat != DEAD)
		medic_called = TRUE
		officer.police_say(POLICE_LINE_MEDIC, line_values(suspect), TRUE)
	if(!isturf(suspect.loc) && !expose_suspect(officer, suspect))
		return
	if(!officer.Adjacent(suspect))
		route_to(officer, suspect, 1)
		return
	set_goal(null)
	if(!searched)
		begin_action(CASE_ACT_SEARCHING)

/**
 * Held for want of a cell: the officer keeps hold of them and stands them by the desk, and every CASE_HOLD_RETRY
 * takes them back to a cell if there is one. No timeout: they are held until booked, let go or out of the cuffs.
 */
/datum/outpost_police_case/proc/step_hold()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	var/mob/living/carbon/suspect = get_suspect()
	if(!officer || !suspect)
		return
	if(!keep_pulling(officer, suspect))
		return
	if(world.time >= hold_retry_at)
		hold_retry_at = world.time + CASE_HOLD_RETRY
		if(police.cell_best(officer))
			set_step(CASE_STEP_DESK)
			return
	if(police.desk_turf)
		route_to(officer, police.desk_turf, CASE_COVER_DISTANCE)

/// Whether a booking that cannot be done now holds the suspect instead (three stars and up, in our hands, evidence in)
/datum/outpost_police_case/proc/hold_for_cell()
	var/mob/living/carbon/suspect = get_suspect()
	if(!suspect || !cuffed || suspect_lost || !disposed_at || !warrant?.mind || suspect.stat == DEAD)
		return FALSE
	return police.get_stars(warrant.mind) >= 3

/// Holds the suspect by the desk until a cell can be had (CASE_STEP_HOLD)
/datum/outpost_police_case/proc/start_hold()
	booked_at = 0
	lift_goal = null
	set_step(CASE_STEP_HOLD)
	hold_retry_at = world.time + CASE_HOLD_RETRY

/// Release: up to the suspect (who may have walked off in our cuffs), then the cuffs off
/datum/outpost_police_case/proc/step_release()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	var/mob/living/carbon/suspect = suspect_ref?.resolve()
	if(!officer || QDELETED(suspect))
		return
	if(!isturf(suspect.loc) && !expose_suspect(officer, suspect))
		return
	police_case_pace(officer, !officer.Adjacent(suspect))
	if(!route_to(officer, suspect, 1))
		return
	begin_action(CASE_ACT_RELEASING)

// =========================================================================
// ACTIONS (what takes time on a body; through INVOKE_ASYNC, the officer holding still)
// =========================================================================

/// Starts `action` (CASE_ACT_*) unless one is running
/datum/outpost_police_case/proc/begin_action(action)
	if(acting || QDELETED(src))
		return FALSE
	acting = action
	acting_since = world.time
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	var/datum/ai_controller/basic_controller/human_npc/stealth/brain = officer?.ai_controller
	if(istype(brain))
		brain.stealth_drop_walk()
	officer?.ai_controller?.CancelActions()
	INVOKE_ASYNC(src, PROC_REF(do_action), action)
	return TRUE

/// Runs `action` to its end. Sleeps.
/datum/outpost_police_case/proc/do_action(action)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	var/mob/living/carbon/suspect = get_suspect()
	if(officer)
		switch(action)
			if(CASE_ACT_CUFFING)
				act_cuff(officer, suspect)
			if(CASE_ACT_SEARCHING)
				act_search(officer, suspect)
			if(CASE_ACT_RIDING)
				act_ride(officer)
			if(CASE_ACT_DISPOSING)
				act_dispose(officer)
			if(CASE_ACT_BOOKING)
				act_book(officer, suspect)
			if(CASE_ACT_RECOVERING)
				act_recover(officer)
			if(CASE_ACT_RELEASING)
				act_release(officer, suspect_ref?.resolve())
	if(!QDELETED(src) && acting == action)
		acting = null

/// tg's own cuffing, cuffs in hand. Police cuffs dispense a /used pair (police_units.dm, P2).
/datum/outpost_police_case/proc/act_cuff(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, mob/living/carbon/suspect)
	if(!suspect || !officer.Adjacent(suspect))
		return
	var/obj/item/restraints/handcuffs/cuffs = officer.get_cuffs()
	if(!cuffs)
		return
	if(!officer.is_holding(cuffs) && officer.police_free_hand())
		human_npc_take_in_hand(officer, cuffs)
	officer.face_atom(suspect)
	say_once(officer, POLICE_LINE_CUFF, suspect)
	cuffs.attempt_to_cuff(suspect, officer)
	// The pair goes back on the belt: a hand is wanted for the evidence and the walk
	officer.police_put_away(cuffs)
	if(QDELETED(src) || QDELETED(suspect))
		return
	if(suspect.handcuffed)
		cuffs_on(suspect)
	else if(!suspect_subdued(suspect) && suspect_moved && step == CASE_STEP_CUFF)
		// They pulled away from the cuffs
		unregister_order(suspect)
		set_step(CASE_STEP_SUBDUE)

/**
 * The search: P12 takes the offending items into an evidence case in the officer's hand. It is done only once it
 * finished: broken off (the suspect pulled away, the officer stunned) with things still to take, the step searches
 * again (review-1 M3, owner decision 7).
 */
/datum/outpost_police_case/proc/act_search(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, mob/living/carbon/suspect)
	if(searched || !officer || !suspect)
		return
	if(!officer.Adjacent(suspect) && !police.property_search_check(suspect, officer))
		return
	search_calls++
	say_once(officer, POLICE_LINE_SEARCH, suspect)
	// Hands full (a drawn gun, the baton): something goes away so the case has a hand to go in
	officer.police_free_hand()
	var/list/search_state = list()
	var/obj/item/found = police.confiscate(suspect, officer, search_state)
	if(QDELETED(src))
		return
	if(!search_state["completed"] && !QDELETED(suspect) && length(police.evidence_candidates(suspect, officer)))
		// Broken off with the crime tools still on them: searched again
		return
	searched = TRUE
	evidence_ref = QDELETED(found) ? null : WEAKREF(found)
	if(step == CASE_STEP_SEARCH || (step == CASE_STEP_DOWNED && suspect_lost))
		set_step(CASE_STEP_ESCORT)

/// The police lift, with whoever they pull (P4)
/datum/outpost_police_case/proc/act_ride(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/to_sector = ride_sector
	var/arrived = police.ride(officer, to_sector)
	if(QDELETED(src))
		return
	if(!arrived)
		// The lift went nowhere (no lift point on the far side, or the ride was broken off): walk for a while
		ride_failed_until = world.time + 30 SECONDS
	lift_goal = null
	ride_sector = null

/// At the evidence locker: the evidence goes in it (P12)
/datum/outpost_police_case/proc/act_dispose(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(disposed_at)
		return
	var/obj/item/evidence = evidence_ref?.resolve()
	if(evidence && (evidence in officer.get_all_contents()))
		officer.police_say(POLICE_LINE_EVIDENCE, null)
	police.dispose_evidence(officer)
	if(QDELETED(src))
		return
	disposed_at = world.time
	evidence_ref = null

/**
 * The cell (P6). The case closes after, booked or not. At three stars and up a booking that fails holds the suspect
 * in cuffs until a cell can be had, and is never a fine (owner decision 37, lead decision L-A2).
 */
/datum/outpost_police_case/proc/act_book(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, mob/living/carbon/suspect)
	if(booked_at || !suspect)
		return
	booked_at = world.time
	officer.police_say(POLICE_LINE_BOOK, line_values(suspect))
	var/shut = police.book(suspect, officer)
	if(QDELETED(src))
		return
	if(shut && !QDELETED(suspect) && !police.cell_holding(suspect.mind) && istype(suspect.handcuffed, /obj/item/restraints/handcuffs/outpost_police/used))
		// Let go with no cell (fined on the spot) but the cuffs would not come off: the release step sees to them
		booked_at = 0
		finish()
		return
	if(!shut)
		log_game("OUTPOST POLICE: [key_name(suspect)] was not put in a cell at [police.outpost] ([AREACOORD(suspect)]).")
		if(hold_for_cell())
			start_hold()
			return
		// No cell to be had: the fine on the spot (never at three stars and up) and the cuffs off
		var/datum/outpost_warrant/booked_warrant = suspect.mind ? police.get_warrant(suspect.mind) : null
		if(!QDELETED(suspect) && suspect.stat != DEAD && istype(suspect.handcuffed, /obj/item/restraints/handcuffs/outpost_police) && officer.Adjacent(suspect))
			if(booked_warrant && police.get_stars(suspect.mind) < 3)
				police.cell_book_fallback(suspect, officer, booked_warrant)
			else
				police.cell_remove_cuffs(suspect, officer)
	if(QDELETED(src))
		return
	if(shut)
		close()
		return
	// Not held: whatever cuffs are still on are ours to take off
	booked_at = 0
	finish()

/// Takes the evidence case off the floor, or off a fallen officer the way stripping them would
/datum/outpost_police_case/proc/act_recover(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/obj/item/evidence = evidence_ref?.resolve()
	if(QDELETED(evidence))
		return
	var/atom/holder = evidence.loc
	if(ismob(holder))
		var/mob/living/fallen = holder
		if(!officer.Adjacent(fallen) || !do_after(officer, CASE_RECOVER_TIME, fallen, IGNORE_HELD_ITEM))
			return
		if(QDELETED(evidence) || evidence.loc != fallen)
			return
		if(!fallen.dropItemToGround(evidence))
			fallen.dropItemToGround(evidence, TRUE)
	else if(!isturf(holder) || !officer.Adjacent(evidence))
		return
	if(!QDELETED(evidence) && isturf(evidence.loc))
		officer.police_carry(evidence)
	if(!QDELETED(src) && !QDELETED(evidence) && !(evidence in officer.get_all_contents()))
		recover_tries++

/// The cuffs off, with the strip menu's wait; the case is over once they are off
/datum/outpost_police_case/proc/act_release(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, mob/living/carbon/suspect)
	if(QDELETED(suspect))
		return
	outpost_police_take_cuffs_off(officer, suspect)
	if(!QDELETED(src) && !needs_release())
		close()

/// `officer` takes the police cuffs off `suspect` (an arrest called off), with the same wait as the strip menu's
/proc/outpost_police_take_cuffs_off(mob/living/carbon/human/officer, mob/living/carbon/suspect)
	if(QDELETED(officer) || QDELETED(suspect) || !officer.Adjacent(suspect))
		return
	// Only the used pair, which is gone once off: a whole pair on the floor would be free cuffs
	var/obj/item/cuffs = suspect.handcuffed
	if(!istype(cuffs, /obj/item/restraints/handcuffs/outpost_police/used))
		return
	if(!do_after(officer, CASE_UNCUFF_TIME, suspect, IGNORE_HELD_ITEM))
		return
	if(suspect.handcuffed == cuffs)
		suspect.dropItemToGround(cuffs, TRUE)

/**
 * The used police pair comes off `suspect` with nobody taking it off: only once the police are done with them and no
 * officer could do it (a release nobody got to, a term served still in them). The pair is gone once off. TRUE if it came off.
 */
/proc/outpost_police_drop_used_cuffs(mob/living/carbon/suspect)
	if(!iscarbon(suspect) || QDELETED(suspect))
		return FALSE
	var/obj/item/cuffs = suspect.handcuffed
	if(!istype(cuffs, /obj/item/restraints/handcuffs/outpost_police/used))
		return FALSE
	log_game("OUTPOST POLICE: the used police cuffs came off [key_name(suspect)] with no officer to take them off ([AREACOORD(suspect)]).")
	suspect.dropItemToGround(cuffs, TRUE)
	return TRUE

// =========================================================================
// THE OFFICER'S BRAIN
// =========================================================================

// An officer working an arrest is never held still by the empty-outpost pause: the suspect may be in a hangar or on a
// docked ship, outside the concourse the pause watches (review-1 M1, owner decision 34)
/mob/living/carbon/human/npc/ambient_npc/outpost/police/pause_routine()
	if(case && !QDELETED(case))
		return
	return ..()

/// Owns the officer while it has a case step to do
/datum/ai_planning_subtree/outpost_police_case

/datum/ai_planning_subtree/outpost_police_case/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = controller.pawn
	if(!istype(officer) || !officer.case || officer.stat != CONSCIOUS)
		return
	var/datum/outpost_police_case/case = officer.case
	if(QDELETED(case))
		officer.case = null
		return
	return case.plan_for(controller, officer)

/// What `officer` does on this case now: walk, stand, or (the cover, at two stars) leave the shooting subtrees to fire on disable
/datum/outpost_police_case/proc/plan_for(datum/ai_controller/controller, mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/mob/living/carbon/suspect = get_suspect()
	if(officer == arresting())
		if(acting || HAS_TRAIT(officer, TRAIT_INCAPACITATED))
			return SUBTREE_RETURN_FINISH_PLANNING
		if(step == CASE_STEP_SUBDUE && suspect && officer.Adjacent(suspect))
			INVOKE_ASYNC(src, PROC_REF(strike), officer, suspect)
		queue_walk(controller, officer, goal, goal_distance)
		return SUBTREE_RETURN_FINISH_PLANNING
	// The cover: fires only once the suspect is to be subdued, never while they are given the time to comply
	if(suspect && step == CASE_STEP_SUBDUE && police?.force_level(suspect) >= POLICE_FORCE_STUN)
		var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(controller.blackboard[BB_TARGETING_STRATEGY])
		if(strategy?.can_attack(officer, suspect))
			controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, suspect)
			// The force subtree (P4) picks the weapon mode; the shooting subtrees fire
			return
	var/atom/follow = arresting() || suspect
	if(follow)
		queue_walk(controller, officer, follow, CASE_COVER_DISTANCE)
	return SUBTREE_RETURN_FINISH_PLANNING

/// Queues the walk to `where` (null, or there already: nothing queued, so any walk stops)
/datum/outpost_police_case/proc/queue_walk(datum/ai_controller/controller, mob/living/officer, atom/where, distance)
	if(QDELETED(where))
		return
	var/turf/here = get_turf(officer)
	var/turf/there = get_turf(where)
	if(!here || !there || (here.z == there.z && get_dist(here, there) <= distance))
		return
	controller.set_blackboard_key(BB_OUTPOST_POLICE_CASE_GOAL, where)
	var/walk_type = /datum/ai_behavior/outpost_police_case_walk
	if(distance >= CASE_COVER_DISTANCE)
		walk_type = /datum/ai_behavior/outpost_police_case_walk/near
	else if(distance == 1)
		walk_type = /datum/ai_behavior/outpost_police_case_walk/adjacent
	controller.queue_behavior(walk_type, BB_OUTPOST_POLICE_CASE_GOAL)

/// Walks to the atom in the key, planning going on meanwhile; a new goal ends it so the next walk starts at once
/datum/ai_behavior/outpost_police_case_walk
	action_cooldown = 0.5 SECONDS
	required_distance = 0
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION | AI_BEHAVIOR_MOVE_AND_PERFORM

/datum/ai_behavior/outpost_police_case_walk/setup(datum/ai_controller/controller, goal_key)
	. = ..()
	var/atom/target = controller.blackboard[goal_key]
	if(QDELETED(target))
		return FALSE
	set_movement_target(controller, target)

/datum/ai_behavior/outpost_police_case_walk/perform(seconds_per_tick, datum/ai_controller/controller, goal_key)
	var/atom/target = controller.blackboard[goal_key]
	if(QDELETED(target) || controller.current_movement_target != target)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	if(get_dist(controller.pawn, target) <= required_distance)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY

/datum/ai_behavior/outpost_police_case_walk/finish_action(datum/ai_controller/controller, succeeded, goal_key)
	. = ..()
	controller.clear_blackboard_key(goal_key)

/// Up beside it
/datum/ai_behavior/outpost_police_case_walk/adjacent
	required_distance = 1

/// Within a couple of tiles of it (the cover)
/datum/ai_behavior/outpost_police_case_walk/near
	required_distance = CASE_COVER_DISTANCE

#undef CASE_STEP_RESPOND
#undef CASE_STEP_ORDER
#undef CASE_STEP_SUBDUE
#undef CASE_STEP_CUFF
#undef CASE_STEP_SEARCH
#undef CASE_STEP_ESCORT
#undef CASE_STEP_DESK
#undef CASE_STEP_BOOK
#undef CASE_STEP_DOWNED
#undef CASE_STEP_RELEASE
#undef CASE_STEP_HOLD
#undef CASE_HOLD_RETRY
#undef CASE_RELEASE_HANDOFFS
#undef CASE_RELEASE_LIMIT
#undef CASE_ACT_CUFFING
#undef CASE_ACT_SEARCHING
#undef CASE_ACT_RIDING
#undef CASE_ACT_DISPOSING
#undef CASE_ACT_BOOKING
#undef CASE_ACT_RECOVERING
#undef CASE_ACT_RELEASING
#undef BB_OUTPOST_POLICE_CASE_GOAL
#undef CASE_ACTION_STUCK
#undef CASE_REOPEN_HOLD
#undef CASE_COVER_DISTANCE
#undef CASE_CONTACT_RANGE
#undef CASE_STRIPPER_WINDOW
#undef CASE_RECOVER_TIME
#undef CASE_UNCUFF_TIME
#undef CASE_DOWNED_LIMIT
#undef CASE_LIFT_PATIENCE
#undef CASE_LIFT_SKIP
#undef CASE_EVIDENCE_PATIENCE
