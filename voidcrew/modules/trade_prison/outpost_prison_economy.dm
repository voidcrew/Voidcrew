/**
 * # Lockup comings and goings
 *
 * Intake (arrivals and each cell's wait), releases, deaths and what becomes of a body. Nobody is
 * paid for holding prisoners and nobody is fined for losing them. The numbers are in
 * voidcrew/_DEFINES/outpost_prison_economy.dm. Everyone comes and goes through Processing
 * (outpost_prison_processing.dm).
 *
 * Each cell keeps the world.time from which it takes a new arrival, and opening or closing intake
 * never brings that forward. Arrivals come one at a time, with a gap after each, so an empty wing
 * fills over a few minutes rather than all at once.
 */

/datum/outpost_prison
	/// Whether prisoners are being sent here. A wing takes prisoners from the start; an admin can shut it.
	var/intake_open = TRUE
	/// world.time of each prisoner lost (escaped or moved on after a riot) within OUTPOST_PRISON_LOST_WINDOW, oldest first
	var/list/lost_log = list()
	/// Seconds until the next prisoner is due, or null while none is; see next_arrival_in()
	var/arrival_countdown
	/// Seconds before another prisoner may arrive after the last one. Counts down while intake is shut too.
	var/arrival_gap = OUTPOST_PRISON_FIRST_ARRIVAL

// ===== HOW WELL THEY ARE KEPT =====

/**
 * How well a prisoner is kept right now, 0 to 1: their care (fed, clean, whole) against the wing's
 * conditions. Nothing while they are in trouble or shut in their cell too long. Averaged over a
 * stay it decides how they say goodbye (on_prisoner_releasing()).
 */
/datum/outpost_prison/proc/kept_well(mob/living/carbon/human/npc/outpost_prisoner/prisoner)
	if(QDELETED(prisoner) || prisoner.stat == DEAD || prisoner.phase != PRISONER_PRESENT || prisoner.trouble)
		return 0
	if((prisoner.locked_in_seconds > OUTPOST_PRISON_CONFINED_SOUR_AFTER && !protective_custody()) || prisoner.cuffs_souring())
		return 0
	var/care = clamp((prisoner.care() - OUTPOST_PRISON_GRADE_FLOOR) / (OUTPOST_PRISON_GRADE_FULL - OUTPOST_PRISON_GRADE_FLOOR), 0, 1)
	return care * (0.5 + 0.5 * conditions_score() / 100)

/// A prisoner served `served` seconds of their sentence: the seconds served, and how well kept they were
/datum/outpost_prison/proc/note_served(mob/living/carbon/human/npc/outpost_prisoner/prisoner, served)
	prisoner.served_seconds += served
	prisoner.kept_seconds += kept_well(prisoner) * served

// ===== LOST PRISONERS =====

/// A prisoner is lost to the wing for good (escaped, or moved on after a riot)
/datum/outpost_prison/proc/note_prisoner_lost(mob/living/carbon/human/npc/outpost_prisoner/prisoner, reason)
	lost_log += world.time
	log_game("OUTPOST LOCKUP: '[outpost_log_name()]' lost [prisoner?.real_name || "a prisoner"] ([reason || "lost"]), [lost_recently()] lost recently")

/// Prisoners lost within the last OUTPOST_PRISON_LOST_WINDOW
/datum/outpost_prison/proc/lost_recently()
	while(length(lost_log) && world.time - lost_log[1] > OUTPOST_PRISON_LOST_WINDOW)
		lost_log.Cut(1, 2)
	return length(lost_log)

// ===== INTAKE =====

/// Opens or closes intake. Neither brings forward a cell's ready time or the gap since the last arrival.
/datum/outpost_prison/proc/set_intake(open, mob/user)
	open = !!open
	if(open == intake_open)
		return TRUE
	intake_open = open
	if(open)
		arrival_gap = max(arrival_gap, OUTPOST_PRISON_FIRST_ARRIVAL)
	arrival_countdown = next_arrival_in()
	if(user)
		log_game("OUTPOST LOCKUP: [key_name(user)] [intake_open ? "opened" : "closed"] intake at '[outpost_log_name()]'")
	return TRUE

/// Whether prisoners may arrive now: intake open and power
/datum/outpost_prison/proc/arrivals_allowed()
	return intake_open && is_powered()

/// Why prisoners are or are not arriving: "open", "closed" or "no_power"
/datum/outpost_prison/proc/intake_state()
	if(!intake_open)
		return "closed"
	if(!is_powered())
		return "no_power"
	return "open"

/**
 * Whether a cell could take a new arrival once it is ready: empty, with somewhere to stand, and its
 * door not bolted or welded
 */
/datum/outpost_prison/proc/cell_takes_arrivals(datum/outpost_prison_cell/cell)
	if(cell.occupant || !cell.arrival_turf())
		return FALSE
	var/obj/machinery/door/airlock/door = cell.door()
	return !door || (!door.locked && !door.welded)

/// Seconds until the next prisoner is due: the gap since the last or the wait for a cell, whichever is longer. Null while none is due.
/datum/outpost_prison/proc/next_arrival_in()
	if(!arrivals_allowed() || !free_slots())
		return null
	var/soonest
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(!cell_takes_arrivals(cell))
			continue
		var/wait = max(0, (cell.ready_at - world.time) / (1 SECONDS))
		if(isnull(soonest) || wait < soonest)
			soonest = wait
	if(isnull(soonest))
		return null
	return max(arrival_gap, soonest)

/**
 * Advances arrivals by `seconds`: while arrivals are allowed and the gap is up, the next prisoner
 * comes into a ready cell. One a step, however long the step: several ready cells never fill back
 * to back.
 */
/datum/outpost_prison/proc/intake_tick(seconds)
	arrival_gap = max(arrival_gap - seconds, 0)
	if(arrivals_allowed() && arrival_gap <= 0 && free_slots() && arrival_way_clear())
		admit_next()
	arrival_countdown = next_arrival_in()

/// Whether an arrival would come through Processing: the wing has one, and someone is at the outpost to see them walk in
/datum/outpost_prison/proc/arrives_through_processing()
	return has_processing() && has_audience()

/// Whether the next arrival can come in now: Processing is free, or they would not come through it
/datum/outpost_prison/proc/arrival_way_clear()
	return !arrives_through_processing() || processing_free()

/// After an arrival the next waits OUTPOST_PRISON_ARRIVAL_GAP_MIN to _MAX seconds, never less than it already had to
/datum/outpost_prison/proc/start_arrival_gap()
	arrival_gap = max(arrival_gap, rand(OUTPOST_PRISON_ARRIVAL_GAP_MIN, OUTPOST_PRISON_ARRIVAL_GAP_MAX))

/**
 * Brings a new prisoner in for the lowest-numbered cell that can take one: empty, ready and its door
 * not bolted or welded, and starts the gap before the next (start_arrival_gap()). They come through
 * Processing and walk to the cell; with nobody at the outpost to see it, or Processing busy when an
 * admin forces it, they are simply in the cell. `forced` (for the admin panel) skips the wait and the
 * door, though it still starts a new gap. Returns the prisoner, or null.
 */
/datum/outpost_prison/proc/admit_next(forced = FALSE)
	if(!free_slots())
		return null
	// Processing is busy: the next one waits their turn
	if(!forced && !arrival_way_clear())
		return null
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell.occupant)
			continue
		if(!forced && (cell.ready_at > world.time || !cell_takes_arrivals(cell)))
			continue
		var/turf/spot = cell.arrival_turf()
		if(!spot)
			continue
		var/through_processing = arrives_through_processing() && processing_free()
		if(through_processing)
			spot = processing_turfs[1]
		// An ordinary arrival may be a caught bounty criminal from the pool; the admin panel's never is (outpost_prison_bounty.dm).
		var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = new(spot, forced ? null : bounty_pool_take(src))
		admit(prisoner, cell)
		prisoner.arrive(through_processing)
		start_arrival_gap()
		arrival_countdown = next_arrival_in()
		return prisoner
	return null

/// Books a prisoner into a cell (the first free one when none is given), in the mood the yard puts newcomers in
/datum/outpost_prison/proc/admit(mob/living/carbon/human/npc/outpost_prisoner/prisoner, datum/outpost_prison_cell/into)
	if(!into)
		for(var/datum/outpost_prison_cell/cell as anything in cells)
			if(!cell.occupant)
				into = cell
				break
	// Worked out before they join the roster, so the yard's mood is the others'.
	var/starting_mood = arrival_mood()
	prisoner.prison = src
	prisoners |= prisoner
	prisoner.ai_controller?.reset_ai_status()
	if(into)
		into.occupant = prisoner
		prisoner.cell = into
	prisoner.sentence_left = rand(OUTPOST_PRISON_SENTENCE_MIN, OUTPOST_PRISON_SENTENCE_MAX)
	prisoner.set_mood(starting_mood)
	refresh_prisoner_reach(prisoner)
	add_log("[prisoner.real_name] arrived in cell [into ? into.number : "-"], [round(prisoner.sentence_left / 60)] min sentence.")
	extras_prisoner_admitted(prisoner)

// ===== RELEASES, DEATHS AND EMPTY CELLS =====

/**
 * After a tick of a prisoner's sentence: released once it has run out, and sent back to their
 * cell in its last OUTPOST_PRISON_RELEASE_WALK seconds.
 */
/datum/outpost_prison/proc/check_release(mob/living/carbon/human/npc/outpost_prisoner/prisoner)
	if(prisoner.sentence_left <= 0)
		release(prisoner)
	else if(prisoner.sentence_left <= OUTPOST_PRISON_RELEASE_WALK && !istype(prisoner.activity, /datum/prisoner_activity/go_home) && !prisoner.in_trouble())
		// Time to head back to the cell; the routine picks this up.
		prisoner.end_activity()

/// Sentence served: the prisoner says goodbye and heads for Processing. TRUE if they were released.
/datum/outpost_prison/proc/release(mob/living/carbon/human/npc/outpost_prisoner/prisoner)
	if(prisoner.phase != PRISONER_PRESENT || prisoner.stat == DEAD)
		return FALSE
	var/average = prisoner.served_seconds ? prisoner.kept_seconds / prisoner.served_seconds : 0
	add_log("[prisoner.real_name] released.")
	close_bounty_record(prisoner, BOUNTY_RECORD_RELEASED)
	// Friends may say goodbye instead (outpost_prison_life.dm).
	if(!on_prisoner_releasing(prisoner, average))
		prisoner.say_context("release")
	prisoner.leave()
	return TRUE

/**
 * A prisoner died. The body lies where it fell and keeps its cell (body_tick()) until it is carried
 * out of the cell block, or nobody has been able to see it for a while. A death blamed on staff is
 * taken hard by the yard (blame_death()).
 */
/datum/outpost_prison/proc/on_prisoner_death(mob/living/carbon/human/npc/outpost_prisoner/prisoner)
	add_log("[prisoner.real_name] died.")
	close_bounty_record(prisoner, BOUNTY_RECORD_DEAD)
	prisoner.died_at = world.time
	prisoner.body_unseen = 0
	prisoner.clear_trouble()
	if(prisoner.staff_to_blame())
		blame_death(prisoner)
	if(!loose_count() && !riot_active)
		broke_out = FALSE
	update_riot_lights()

/**
 * A body is a body. While it lies in the cell block it keeps its cell and sours the yard
 * (bodies_in_cell_block()). Once it is out of the cell block (carried out, anywhere) it leaves the
 * roster, and its cell waits a refill. Lying in the cell block with no client able to see it for
 * OUTPOST_PRISON_BODY_UNSEEN, it is cleared away: never a body a player is or was in, and never one
 * being dragged, carried or shut in something.
 */
/datum/outpost_prison/proc/body_tick(mob/living/carbon/human/npc/outpost_prisoner/prisoner, seconds = 1)
	if(!in_cell_block(prisoner))
		add_log("[prisoner.real_name]'s body is out of the cell block.")
		forget(prisoner)
		return
	if(!bodies_cleared)
		return
	if(outpost_prison_body_held(prisoner) || seen_by_client(prisoner))
		prisoner.body_unseen = 0
		return
	prisoner.body_unseen += seconds
	if(prisoner.body_unseen < OUTPOST_PRISON_BODY_UNSEEN || prisoner.npc_ever_played())
		return
	add_log("[prisoner.real_name]'s body was taken away.")
	qdel(prisoner)

/// Prisoners' bodies lying in the cell block, which nobody comes for
/datum/outpost_prison/proc/bodies_in_cell_block()
	. = 0
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner in prisoners)
		if(prisoner.stat == DEAD && prisoner.phase == PRISONER_PRESENT && in_cell_block(prisoner))
			.++

/**
 * A prisoner has left the roster (released, escaped, carried out dead or deleted) and their cell
 * is free: it waits a refill. `cell` is the cell they had, or null. A ready time is never brought
 * forward.
 */
/datum/outpost_prison/proc/on_cell_emptied(datum/outpost_prison_cell/cell)
	if(cell)
		cell.ready_at = max(cell.ready_at, world.time + rand(OUTPOST_PRISON_REFILL_MIN, OUTPOST_PRISON_REFILL_MAX) SECONDS)
	arrival_countdown = next_arrival_in()
