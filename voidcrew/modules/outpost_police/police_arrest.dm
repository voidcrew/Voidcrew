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
 * When it goes wrong (spec 6.4): a suspect in crit or dead before the cuffs is left where they lie for
 * OUTPOST_POLICE_CRIT_WAIT with a medic called, then the case closes. A suspect lost after the search still
 * sends the officer to the desk with the evidence. Slipping police cuffs is SLIP_CUFFS, someone else taking
 * them off is ABET, pulling the suspect away is RESIST. A step stuck OUTPOST_POLICE_STEP_TIMEOUT goes back to
 * respond; the third time the case closes and no new one opens on that person for CASE_REOPEN_HOLD.
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

// ===== ACTIONS (`case.acting`) =====

#define CASE_ACT_CUFFING "cuffing"
#define CASE_ACT_SEARCHING "searching"
#define CASE_ACT_RIDING "riding"
#define CASE_ACT_DISPOSING "disposing"
#define CASE_ACT_BOOKING "booking"
#define CASE_ACT_RECOVERING "recovering"

/// Blackboard key: where the officer's case sends them
#define BB_OUTPOST_POLICE_CASE_GOAL "outpost_police_case_goal"

/// An action that has not come back in this long is taken as broken (a runtime inside it) and let go
#define CASE_ACTION_STUCK (2 MINUTES)
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

/datum/outpost_police
	/// P5: minds no new case opens on until a world.time (their last case closed on timeouts). Written by police_arrest.dm only.
	var/list/case_holds

// =========================================================================
// THE API
// =========================================================================

/// Opens an arrest for `warrant`. Returns the case (the open one, if there is one already), or null.
/datum/outpost_police/proc/open_case(datum/outpost_warrant/warrant)
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
	if(!iscarbon(suspect) || QDELETED(suspect) || suspect.stat == DEAD || HAS_TRAIT(suspect, TRAIT_CRITICAL_CONDITION))
		return null
	if(get_trader_outpost_for_turf(get_turf(suspect)) != outpost || in_custody(suspect))
		return null
	if(get_stars(who) >= 3)
		return null
	case = new /datum/outpost_police_case(src, warrant)
	cases[who] = case
	case.staff()
	wake()
	return case

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
	if(cuffed && police_cuffs && !booked_at && releaser && suspect && suspect.stat != DEAD && istype(suspect.handcuffed, /obj/item/restraints/handcuffs/outpost_police))
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

/// The case goes back to the start (a step timed out). The third time it closes and the warrant is left to fade.
/datum/outpost_police_case/proc/reset_case()
	resets++
	if(resets >= 3)
		if(police && warrant?.mind)
			LAZYSET(police.case_holds, warrant.mind, world.time + CASE_REOPEN_HOLD)
		close()
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

/// Whether `officer` can work a case: up, free, on our roster, at the outpost and not leaving
/datum/outpost_police_case/proc/officer_fit(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(QDELETED(officer) || officer.stat != CONSCIOUS || HAS_TRAIT(officer, TRAIT_RESTRAINED) || officer.fading || officer.npc_exit)
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
		if(officer.case == src && officer_fit(officer))
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

/// The nearest officer with no case, beat and response officers before the desk sergeant
/datum/outpost_police_case/proc/nearest_free_officer(mob/living/carbon/suspect, list/exclude)
	var/turf/where = get_turf(suspect)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/best
	var/best_score = INFINITY
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police?.officers)
		if(officer.case || (officer in exclude) || !officer_fit(officer))
			continue
		var/turf/officer_turf = get_turf(officer)
		var/score = (where && officer_turf?.z == where.z) ? get_dist(officer_turf, where) : 500
		if(officer.unit_kind == POLICE_UNIT_SERGEANT)
			score += 1000
		if(score < best_score)
			best = officer
			best_score = score
	return best

/// `officer` joins the case: whatever they were doing stops
/datum/outpost_police_case/proc/take_officer(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	officer.case = src
	if(officer.activity)
		officer.end_activity()
	officer.ai_controller?.CancelActions()

/// `officer` leaves the case: lets go of the suspect, stops walking for it and stops shooting at them
/datum/outpost_police_case/proc/drop_officer(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(QDELETED(officer))
		return
	var/mob/living/carbon/suspect = suspect_ref?.resolve()
	if(officer.case == src)
		officer.case = null
	if(suspect && officer.pulling == suspect)
		officer.stop_pulling()
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

/// The %LOOK% token for a line about `suspect`: the type name of what they wear on top (abuse M15)
/datum/outpost_police_case/proc/line_values(mob/living/carbon/suspect)
	var/mob/living/carbon/human/person = suspect
	if(!istype(person))
		return null
	var/obj/item/worn = person.wear_suit || person.w_uniform
	if(!worn)
		return null
	return list("%LOOK%" = initial(worn.name))

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
	if(step != CASE_STEP_DOWNED && step != CASE_STEP_BOOK && world.time - step_started_at >= OUTPOST_POLICE_STEP_TIMEOUT)
		reset_case()
		return
	if(recover_evidence(officer))
		return
	run_step()

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

/**
 * Whether the case is over, and closes it if so: the warrant gone, no stars, three or more stars on someone
 * not yet in cuffs (the lethal response takes over), or the suspect gone with no evidence left for the desk.
 */
/datum/outpost_police_case/proc/check_close(mob/living/carbon/suspect)
	if(!warrant?.mind || police.warrants[warrant.mind] != warrant)
		close()
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
	// In cuffs at three stars they are no danger to anyone: the arrest carries on
	if(stars <= 0 || (stars >= 3 && !cuffed))
		close()
		return TRUE
	return FALSE

/// Only the evidence goes on to the desk now. Nobody moves the body.
/datum/outpost_police_case/proc/mark_lost(mob/living/carbon/suspect)
	if(suspect_lost)
		return
	suspect_lost = TRUE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	if(officer && suspect && officer.pulling == suspect)
		officer.stop_pulling()
	unregister_order(suspect)
	lift_goal = null
	if(step != CASE_STEP_DESK)
		set_step(CASE_STEP_ESCORT)

/// Out of the cuffs before the cell: their own doing is SLIP_CUFFS, someone else's ABET. Back to respond.
/datum/outpost_police_case/proc/check_escape(mob/living/carbon/suspect)
	if(!cuffed || step == CASE_STEP_BOOK || suspect.handcuffed)
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

/// Down before the cuffs and the search: officers stand back. Down after either: only the evidence goes on.
/datum/outpost_police_case/proc/check_down(mob/living/carbon/suspect)
	if(!suspect_downed(suspect))
		return
	if(cuffed || searched)
		if(!suspect_lost)
			say_once(arresting(), POLICE_LINE_MEDIC, suspect, TRUE)
			if(searched)
				mark_lost(suspect)
			else
				// Cuffed and down: the search still happens where they lie, then the desk
				suspect_lost = TRUE
				var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
				if(officer?.pulling == suspect)
					officer.stop_pulling()
		return
	if(step == CASE_STEP_DOWNED)
		return
	set_step(CASE_STEP_DOWNED)
	downed_since = world.time
	medic_called = FALSE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	if(officer?.pulling == suspect)
		officer.stop_pulling()
	unregister_order(suspect)
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
 * Gets `officer` within `distance` of `target`: on foot in the same sector, by the police lift between sectors.
 * TRUE once there; otherwise it has set the goal or started the ride.
 */
/datum/outpost_police_case/proc/route_to(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, atom/target, distance = 1)
	var/turf/here = get_turf(officer)
	var/turf/there = get_turf(target)
	if(!here || !there)
		set_goal(null)
		return FALSE
	if(here.z == there.z && get_dist(here, there) <= distance)
		set_goal(null)
		return TRUE
	var/from_sector = police.sector_of(here)
	var/to_sector = police.sector_of(there)
	if(from_sector == to_sector)
		lift_goal = null
		set_goal(target, distance)
		return FALSE
	if(!lift_goal || police.sector_of(lift_goal) != from_sector)
		lift_goal = police.lift_point(from_sector)
	if(!lift_goal)
		// No lift from here: try the walk
		set_goal(target, distance)
		return FALSE
	if(here != lift_goal)
		set_goal(lift_goal, 0)
		return FALSE
	set_goal(null)
	ride_sector = to_sector
	begin_action(CASE_ACT_RIDING)
	return FALSE

/// Keeps `officer` pulling the suspect, walking up to them first. TRUE while pulling.
/datum/outpost_police_case/proc/keep_pulling(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, mob/living/carbon/suspect)
	if(officer.pulling == suspect)
		return TRUE
	if(!officer.Adjacent(suspect))
		route_to(officer, suspect, 1)
		return FALSE
	officer.start_pulling(suspect)
	return officer.pulling == suspect

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
	if(officer.Adjacent(suspect))
		set_goal(null)
		after_contact()
		return
	if(police.perception?.sees(officer, suspect))
		police.note_seen(warrant.mind, get_turf(suspect))
		if(get_dist(officer, suspect) <= CASE_CONTACT_RANGE)
			set_goal(null)
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
	if(suspect_subdued(suspect))
		clear_cover_target(suspect)
		enter_cuff(suspect)
		return
	if(officer.force != POLICE_FORCE_ARREST)
		officer.set_force(POLICE_FORCE_ARREST)
	if(police.get_stars(warrant.mind) >= 2)
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
	if(!suspect_subdued(suspect) && (suspect.combat_mode || suspect_armed(suspect) || suspect_moved))
		unregister_order(suspect)
		set_step(CASE_STEP_SUBDUE)
		return
	if(!officer.Adjacent(suspect))
		route_to(officer, suspect, 1)
		return
	set_goal(null)
	begin_action(CASE_ACT_CUFFING)

/// The cuffs are on: watch who takes them off, then the search
/datum/outpost_police_case/proc/cuffs_on(mob/living/carbon/suspect)
	unregister_order(suspect)
	cuffed = TRUE
	police_cuffs = istype(suspect.handcuffed, /obj/item/restraints/handcuffs/outpost_police)
	stripper_ref = null
	RegisterSignal(suspect, COMSIG_BEING_STRIPPED, PROC_REF(on_suspect_stripped), override = TRUE)
	clear_cover_target(suspect)
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
	var/turf/desk = police.desk_turf
	if(!desk || route_to(officer, desk, 1))
		set_step(CASE_STEP_DESK)

/// Desk: the evidence is dealt with (the chute and the lockers, P12), then on to the cell door. A lost suspect's case ends here.
/datum/outpost_police_case/proc/step_desk()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	if(!officer)
		return
	if(!disposed_at)
		var/turf/desk = police.desk_turf
		if(!desk || route_to(officer, desk, 1))
			set_goal(null)
			begin_action(CASE_ACT_DISPOSING)
		return
	if(suspect_lost)
		close()
		return
	var/mob/living/carbon/suspect = get_suspect()
	if(!suspect || !keep_pulling(officer, suspect))
		return
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
	if(!officer.Adjacent(suspect))
		keep_pulling(officer, suspect)
		return
	set_goal(null)
	begin_action(CASE_ACT_BOOKING)

/// Standing by a suspect who went down before the cuffs: nobody touches them, a medic is called, and after OUTPOST_POLICE_CRIT_WAIT the case closes. Up again: back to respond.
/datum/outpost_police_case/proc/step_downed()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = arresting()
	var/mob/living/carbon/suspect = get_suspect()
	if(!suspect)
		return
	if(!suspect_downed(suspect))
		downed_since = 0
		set_step(CASE_STEP_RESPOND)
		return
	set_goal(null)
	if(officer && !medic_called)
		medic_called = TRUE
		officer.police_say(POLICE_LINE_MEDIC, line_values(suspect), TRUE)
	if(world.time - downed_since >= OUTPOST_POLICE_CRIT_WAIT)
		close()

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
	if(!QDELETED(src) && acting == action)
		acting = null

/// tg's own cuffing, cuffs in hand. Police cuffs dispense a /used pair (police_units.dm, P2).
/datum/outpost_police_case/proc/act_cuff(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, mob/living/carbon/suspect)
	if(!suspect || !officer.Adjacent(suspect))
		return
	var/obj/item/restraints/handcuffs/cuffs = officer.get_cuffs()
	if(!cuffs)
		return
	if(!officer.is_holding(cuffs))
		human_npc_take_in_hand(officer, cuffs)
	officer.face_atom(suspect)
	say_once(officer, POLICE_LINE_CUFF, suspect)
	cuffs.attempt_to_cuff(suspect, officer)
	if(QDELETED(src) || QDELETED(suspect))
		return
	if(suspect.handcuffed)
		cuffs_on(suspect)
	else if(!suspect_subdued(suspect) && suspect_moved && step == CASE_STEP_CUFF)
		// They pulled away from the cuffs
		unregister_order(suspect)
		set_step(CASE_STEP_SUBDUE)

/// The search: P12 takes the offending items into an evidence case in the officer's hand
/datum/outpost_police_case/proc/act_search(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, mob/living/carbon/suspect)
	if(searched || !suspect)
		return
	searched = TRUE
	search_calls++
	officer.police_say(POLICE_LINE_SEARCH, line_values(suspect))
	var/obj/item/found = police.confiscate(suspect, officer)
	if(QDELETED(src))
		return
	evidence_ref = QDELETED(found) ? null : WEAKREF(found)
	if(step == CASE_STEP_SEARCH)
		set_step(CASE_STEP_ESCORT)

/// The police lift, with whoever they pull (P4)
/datum/outpost_police_case/proc/act_ride(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/to_sector = ride_sector
	police.ride(officer, to_sector)
	if(QDELETED(src))
		return
	lift_goal = null
	ride_sector = null

/// At the desk: the chute and the lockers (P12)
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

/// The cell (P6). The case closes after, booked or not.
/datum/outpost_police_case/proc/act_book(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, mob/living/carbon/suspect)
	if(booked_at || !suspect)
		return
	booked_at = world.time
	officer.police_say(POLICE_LINE_BOOK, line_values(suspect))
	var/shut = police.book(suspect, officer)
	if(QDELETED(src))
		return
	if(!shut)
		log_game("OUTPOST POLICE: [key_name(suspect)] was not put in a cell at [police.outpost] ([AREACOORD(suspect)]).")
	close()

/// Takes the evidence case off the floor, or off a fallen officer the way stripping them would
/datum/outpost_police_case/proc/act_recover(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/obj/item/evidence = evidence_ref?.resolve()
	if(QDELETED(evidence))
		return
	var/atom/holder = evidence.loc
	if(ismob(holder))
		var/mob/living/fallen = holder
		if(!officer.Adjacent(fallen) || !do_after(officer, CASE_RECOVER_TIME, fallen))
			return
		if(QDELETED(evidence) || evidence.loc != fallen)
			return
		if(!fallen.dropItemToGround(evidence))
			fallen.dropItemToGround(evidence, TRUE)
	else if(!isturf(holder) || !officer.Adjacent(evidence))
		return
	if(!QDELETED(evidence) && isturf(evidence.loc))
		officer.put_in_hands(evidence)

/// `officer` takes the police cuffs off `suspect` (an arrest called off), with the same wait as the strip menu's
/proc/outpost_police_take_cuffs_off(mob/living/carbon/human/officer, mob/living/carbon/suspect)
	if(QDELETED(officer) || QDELETED(suspect) || !officer.Adjacent(suspect))
		return
	// Only the used pair, which is gone once off: a whole pair on the floor would be free cuffs
	var/obj/item/cuffs = suspect.handcuffed
	if(!istype(cuffs, /obj/item/restraints/handcuffs/outpost_police/used))
		return
	if(!do_after(officer, CASE_UNCUFF_TIME, suspect))
		return
	if(suspect.handcuffed == cuffs)
		suspect.dropItemToGround(cuffs, TRUE)

// =========================================================================
// THE OFFICER'S BRAIN
// =========================================================================

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
	// The cover
	if(suspect && (step == CASE_STEP_ORDER || step == CASE_STEP_SUBDUE) && police?.force_level(suspect) >= POLICE_FORCE_STUN)
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
#undef CASE_ACT_CUFFING
#undef CASE_ACT_SEARCHING
#undef CASE_ACT_RIDING
#undef CASE_ACT_DISPOSING
#undef CASE_ACT_BOOKING
#undef CASE_ACT_RECOVERING
#undef BB_OUTPOST_POLICE_CASE_GOAL
#undef CASE_ACTION_STUCK
#undef CASE_REOPEN_HOLD
#undef CASE_COVER_DISTANCE
#undef CASE_CONTACT_RANGE
#undef CASE_STRIPPER_WINDOW
#undef CASE_RECOVER_TIME
#undef CASE_UNCUFF_TIME
