/**
 * # Prison wing economy
 *
 * Money and the comings and goings that make it: what each prisoner earns the treasury and its
 * deposits, release bonuses, fines and the debt they leave, intake (arrivals, suspensions and each
 * cell's wait), releases, deaths and the collection of bodies, and what becomes of the wing when
 * the outpost is abandoned. The pay model and its numbers are in
 * voidcrew/_DEFINES/outpost_prison_economy.dm. The warden console is outpost_prison_warden.dm;
 * it shows none of the money but the debt.
 *
 * A fine never stops at what the treasury holds: the rest becomes the treasury's debt (tg's
 * account_debt, which takes 75% of every later deposit), and no prisoner arrives while it is owed,
 * so the wing's own stipends work it off. Each cell keeps the world.time from which it takes a new
 * arrival, and opening or closing intake never brings that forward.
 *
 * Arrivals come in lanes: one for the wing and one more for each cell block extension
 * (outpost_prison_extension.dm). Each lane brings one prisoner at a time and then waits its own
 * gap, so a ten-cell wing fills three cells in parallel rather than one after another. The
 * extensions' lanes, and their cells, only take new prisoners while the extensions are staffed:
 * a member of the wing home now, or within OUTPOST_PRISON_EXTENSION_STAFFED_GRACE
 * (extension_staffed()). The extra intake needs staff around to process it, and a wing left alone
 * should earn next to nothing however big it is. The lanes' gaps still count down meanwhile.
 */

/datum/outpost_prison
	var/intake_open = FALSE
	/// The corrections service suspended transfers after prisoners were lost; a manager reopening intake lifts it
	var/intake_suspended = FALSE
	/// world.time of each prisoner lost (escaped or transferred out) since transfers were last suspended, oldest first
	var/list/lost_log = list()
	/// Seconds until the next prisoner is due, or null while none is; see next_arrival_in()
	var/arrival_countdown
	/// Seconds before the first arrival lane may bring another prisoner after its last one. Counts down while intake is shut too.
	var/arrival_gap = 0
	/// The same for each further lane, one per extension (arrival_lanes()), in lane order from the second.
	/// These lanes bring nobody while the extensions are unstaffed (lane_open()), though their gaps count down.
	var/list/lane_gaps = list()
	/// world.time a member of the wing was last home, or null; see extension_staffed()
	var/last_crew_home_at
	/// Whether the extensions took new prisoners at the last intake tick, to log it when that changes
	var/extension_intake_was_open = TRUE
	/// Seconds into the current deposit interval
	var/pay_clock = 0
	/// Credits earned and not yet deposited; deposits are whole credits, every OUTPOST_PRISON_DEPOSIT_INTERVAL
	var/pay_owed = 0
	/// Since the wing was placed: paid into the treasury (stipends and bonuses; the admin panel shows it), and fined
	var/paid_total = 0
	var/fined_total = 0
	/// Whether an incident (a riot, its breakout, its escapes and transfers) is open, and its fines so far
	var/incident_open = FALSE
	var/incident_fined = 0

// ===== PAY =====

/// G(care): the share of full pay a level of care earns, 0 to 1. Nothing at or below OUTPOST_PRISON_GRADE_FLOOR, all of it from OUTPOST_PRISON_GRADE_FULL.
/datum/outpost_prison/proc/care_grade(care)
	return clamp((care - OUTPOST_PRISON_GRADE_FLOOR) / (OUTPOST_PRISON_GRADE_FULL - OUTPOST_PRISON_GRADE_FLOOR), 0, 1)

/**
 * Whether a prisoner has been shut in their cell, or kept in cuffs (outpost_prison_capture.dm),
 * long enough to stop paying. Not while it is for their own safety, or they are hiding in their own
 * cell from a creature (outpost_prison_panic.dm), or for lockdown they owe.
 */
/datum/outpost_prison/proc/confined_unpaid(mob/living/basic/outpost_prisoner/prisoner)
	return (prisoner.locked_in_seconds > OUTPOST_PRISON_CONFINED_PAY_AFTER && !protective_custody() && !prisoner.sheltering_from_creature()) || prisoner.cuffs_souring()

/**
 * The share of full pay a prisoner earns the treasury right now, 0 to 1: G(care) x F(conditions).
 * Nothing while they are dead, arriving or leaving, not earning (fighting, rioting, loose and the
 * like), or confined to their cell too long.
 */
/datum/outpost_prison/proc/pay_factor(mob/living/basic/outpost_prisoner/prisoner)
	if(QDELETED(prisoner) || prisoner.stat == DEAD || prisoner.phase != PRISONER_PRESENT || !prisoner.earning_pay())
		return 0
	if(confined_unpaid(prisoner))
		return 0
	return care_grade(prisoner.care()) * conditions_pay_factor()

/// A prisoner served `served` seconds of their sentence: their stipend for it, and the seconds served and kept for the release bonus
/datum/outpost_prison/proc/accrue_pay(mob/living/basic/outpost_prisoner/prisoner, served)
	var/factor = pay_factor(prisoner)
	pay_owed += OUTPOST_PRISON_BASE_PAY * bounty_pay_mult(prisoner) * factor * served / 60
	prisoner.served_seconds += served
	prisoner.kept_seconds += factor * served

/**
 * Advances the deposit clock by `seconds`, depositing what is owed every
 * OUTPOST_PRISON_DEPOSIT_INTERVAL. Last in the tick, it also closes an incident nobody is still in.
 */
/datum/outpost_prison/proc/pay_tick(seconds)
	pay_clock += seconds
	while(pay_clock >= OUTPOST_PRISON_DEPOSIT_INTERVAL)
		pay_clock -= OUTPOST_PRISON_DEPOSIT_INTERVAL
		deposit_pay()
	if(incident_open && !incident_ongoing())
		end_incident()

/// Pays the outpost treasury. Returns TRUE if it was paid.
/datum/outpost_prison/proc/pay_treasury(amount, reason)
	if(amount <= 0 || QDELETED(outpost))
		return FALSE
	outpost.ensure_home_services()
	if(!outpost.treasury?.adjust_money(amount, reason))
		return FALSE
	paid_total += amount
	outpost.record_income(OUTPOST_INCOME_PRISON, reason, amount)
	return TRUE

/// Deposits the whole credits owed; the fraction waits for the next deposit. Returns what was deposited.
/datum/outpost_prison/proc/deposit_pay()
	// The epsilon keeps float error from turning 32 owed into 31.99999 and a credit short.
	var/whole = round(pay_owed + 0.001)
	if(whole >= 1 && pay_treasury(whole, "Prison wing stipend, [OUTPOST_PRISON_DEPOSIT_INTERVAL / 60] min"))
		pay_owed -= whole
		return whole
	return 0

/// What a prisoner earns the treasury per minute right now
/datum/outpost_prison/proc/prisoner_pay_rate(mob/living/basic/outpost_prisoner/prisoner)
	return OUTPOST_PRISON_BASE_PAY * bounty_pay_mult(prisoner) * pay_factor(prisoner)

/// What every prisoner earns the treasury per minute right now
/datum/outpost_prison/proc/pay_rate()
	var/total = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		total += prisoner_pay_rate(prisoner)
	return total

// ===== FINES AND DEBT =====

/// What the outpost treasury owes, 0 if nothing
/datum/outpost_prison/proc/treasury_debt()
	var/datum/bank_account/treasury = outpost?.treasury
	return treasury ? max(0, treasury.account_debt) : 0

/**
 * Fines the outpost treasury `amount` for `reason`. What it holds is taken now and the rest
 * becomes its debt, with a line in its history. An `incident` fine counts toward the current
 * incident's OUTPOST_PRISON_INCIDENT_FINE_CAP, and opens an incident if none is open. Returns the
 * fine levied: `amount`, less anything over the cap.
 */
/datum/outpost_prison/proc/charge_fine(amount, reason, incident = FALSE)
	amount = round(amount)
	if(amount <= 0 || QDELETED(outpost))
		return 0
	if(incident)
		if(!incident_open)
			begin_incident()
		amount = min(amount, OUTPOST_PRISON_INCIDENT_FINE_CAP - incident_fined)
		if(amount <= 0)
			return 0
		incident_fined += amount
	outpost.ensure_home_services()
	var/datum/bank_account/treasury = outpost.treasury
	var/had_debt = treasury.account_debt > 0
	var/taken = clamp(round(treasury.account_balance), 0, amount)
	if(taken > 0 && !treasury.adjust_money(-taken, reason))
		taken = 0
	var/owed = amount - taken
	if(owed > 0)
		treasury.account_debt += owed
		treasury.add_log_to_history(0, "[reason]: [owed] cr owed")
	fined_total += amount
	log_game("PLAYER OUTPOST PRISON: '[outpost.name]' fined [amount] cr ([reason]), [owed] cr of it owed")
	if(owed > 0 && !had_debt)
		announce("Corrections service: the outpost owes [owed] cr in prison fines. Transfers are on hold.", SHIP_NOTIFY_WARNING)
	return amount

/// Pays what the treasury holds toward its debt. Returns what was paid.
/datum/outpost_prison/proc/pay_treasury_debt(mob/user)
	var/datum/bank_account/treasury = outpost?.treasury
	if(!treasury)
		return 0
	var/amount = min(round(treasury.account_balance), treasury.account_debt)
	if(amount <= 0)
		return 0
	var/paid = treasury.pay_debt(amount)
	if(paid <= 0)
		return 0
	add_log("Paid [paid] cr of the treasury's debt.")
	log_game("PLAYER OUTPOST PRISON: [key_name(user)] paid [paid] cr of the treasury's debt at '[outpost?.name]', [treasury.account_debt] cr left")
	arrival_countdown = next_arrival_in()
	return paid

/// A riot starts an incident: its fines, and those of its breakout, escapes and transfers, share one cap
/datum/outpost_prison/proc/begin_incident()
	if(incident_open)
		return
	incident_open = TRUE
	incident_fined = 0

/// The incident is over: nobody is rioting, breaking out or loose any more
/datum/outpost_prison/proc/end_incident()
	incident_open = FALSE
	incident_fined = 0

/**
 * Whether anyone is still rioting, breaking out or loose and not yet caught, so the incident goes
 * on. A runner left in cuffs keeps no incident, and its fine cap, open.
 */
/datum/outpost_prison/proc/incident_ongoing()
	if(riot_active)
		return TRUE
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase == PRISONER_PRESENT && prisoner.stat != DEAD && (prisoner.is_rioting() || (prisoner.trouble == PRISONER_TROUBLE_LOOSE && !prisoner.cuffs)))
			return TRUE
	return FALSE

// ===== LOST PRISONERS =====

/**
 * A prisoner is lost to the wing for good (escaped or transferred out). With
 * OUTPOST_PRISON_LOST_TO_SUSPEND lost within OUTPOST_PRISON_LOST_WINDOW, the corrections service
 * suspends transfers until a manager reopens intake.
 */
/datum/outpost_prison/proc/note_prisoner_lost(mob/living/basic/outpost_prisoner/prisoner, reason)
	lost_log += world.time
	var/lost = lost_recently()
	log_game("PLAYER OUTPOST PRISON: '[outpost?.name]' lost [prisoner?.real_name || "a prisoner"] ([reason || "lost"]), [lost] lost recently")
	if(!intake_suspended && lost >= OUTPOST_PRISON_LOST_TO_SUSPEND)
		suspend_intake(lost)

/// Prisoners lost within the last OUTPOST_PRISON_LOST_WINDOW since transfers were last suspended
/datum/outpost_prison/proc/lost_recently()
	while(length(lost_log) && world.time - lost_log[1] > OUTPOST_PRISON_LOST_WINDOW)
		lost_log.Cut(1, 2)
	return length(lost_log)

/// The corrections service stops sending prisoners until a manager reopens intake
/datum/outpost_prison/proc/suspend_intake(lost)
	intake_suspended = TRUE
	intake_open = FALSE
	arrival_countdown = null
	add_log("Transfers suspended after [lost] prisoners were lost.")
	announce("Corrections service: transfers suspended after [lost] prisoners were lost.", SHIP_NOTIFY_WARNING)

// ===== INTAKE =====

/**
 * Opens or closes intake. Opening is refused while the treasury owes a debt (returns FALSE), and
 * lifts a suspension. Neither brings forward a cell's ready time or the gap since the last arrival.
 */
/datum/outpost_prison/proc/set_intake(open, mob/user)
	open = !!open
	if(open && treasury_debt() > 0)
		return FALSE
	if(open == intake_open)
		return TRUE
	intake_open = open
	if(open)
		if(intake_suspended)
			intake_suspended = FALSE
			lost_log.Cut()
		arrival_gap = max(arrival_gap, OUTPOST_PRISON_FIRST_ARRIVAL)
		// The other lanes start on a gap of their own, so a wing with extensions does not fill several cells at once.
		for(var/lane in 1 to length(lane_gaps))
			lane_gaps[lane] = max(lane_gaps[lane], rand(OUTPOST_PRISON_ARRIVAL_GAP_MIN, OUTPOST_PRISON_ARRIVAL_GAP_MAX))
	arrival_countdown = next_arrival_in()
	if(user)
		log_game("PLAYER OUTPOST: [key_name(user)] [intake_open ? "opened" : "closed"] prison intake at '[outpost?.name]'")
	return TRUE

/// Whether prisoners may arrive now: intake open, no debt and power. An experiment does not hold them up.
/datum/outpost_prison/proc/arrivals_allowed()
	return intake_open && treasury_debt() <= 0 && is_powered()

/// Why prisoners are or are not arriving: "open", "closed", "suspended", "debt" or "no_power"
/datum/outpost_prison/proc/intake_state()
	if(treasury_debt() > 0)
		return "debt"
	if(!intake_open)
		return intake_suspended ? "suspended" : "closed"
	if(!is_powered())
		return "no_power"
	return "open"

/**
 * Whether a cell could take a new arrival once it is ready: empty, with somewhere to stand, and its
 * door not bolted or welded. An extension's cell also needs the extensions staffed (extension_staffed()).
 */
/datum/outpost_prison/proc/cell_takes_arrivals(datum/outpost_prison_cell/cell)
	if(cell.occupant || !cell.arrival_turf())
		return FALSE
	if(cell.in_extension() && !extension_staffed())
		return FALSE
	var/obj/machinery/door/airlock/door = cell.door()
	return !door || (!door.locked && !door.welded)

/// Seconds until the next prisoner is due: the soonest lane's gap or the wait for a cell, whichever is longer. Null while none is due.
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
	return max(lane_gap(soonest_lane()), soonest)

// ===== ARRIVAL LANES =====

/// Lanes prisoners arrive in at once: one, and one more for each extension
/datum/outpost_prison/proc/arrival_lanes()
	return 1 + length(lane_gaps)

/// Gives the prison one arrival lane per extension. A new lane starts on a gap of its own.
/datum/outpost_prison/proc/sync_arrival_lanes()
	var/wanted = extension_count()
	while(length(lane_gaps) < wanted)
		lane_gaps += rand(OUTPOST_PRISON_ARRIVAL_GAP_MIN, OUTPOST_PRISON_ARRIVAL_GAP_MAX)
	if(length(lane_gaps) > wanted)
		lane_gaps.Cut(wanted + 1)

/// Seconds before lane `lane` (1 is the wing's own) may bring another prisoner
/datum/outpost_prison/proc/lane_gap(lane)
	if(lane <= 1)
		return arrival_gap
	return lane - 1 <= length(lane_gaps) ? lane_gaps[lane - 1] : 0

/**
 * Whether the extensions take new prisoners: a member of the wing is home now, or has been within
 * the last OUTPOST_PRISON_EXTENSION_STAFFED_GRACE. The extra intake needs staff around to process it.
 */
/datum/outpost_prison/proc/extension_staffed()
	if(crew_home())
		last_crew_home_at = world.time
		return TRUE
	return !isnull(last_crew_home_at) && world.time - last_crew_home_at < OUTPOST_PRISON_EXTENSION_STAFFED_GRACE

/// Whether lane `lane` may bring prisoners now. The wing's own lane always may; an extension's only while the extensions are staffed.
/datum/outpost_prison/proc/lane_open(lane)
	return lane <= 1 || extension_staffed()

/// Notes in the warden's log when the extension cells stop or start taking new prisoners while intake is open
/datum/outpost_prison/proc/note_extension_intake()
	if(!extension_count())
		return
	var/open = extension_staffed()
	if(open == extension_intake_was_open)
		return
	extension_intake_was_open = open
	if(!intake_open)
		return
	if(open)
		add_log("Extension cells open to transfers again.")
	else
		add_log("Extension cells closed to transfers: no staff on hand.")

/// The open lane due soonest, the first on a tie
/datum/outpost_prison/proc/soonest_lane()
	var/soonest = 1
	for(var/lane in 2 to arrival_lanes())
		if(lane_open(lane) && lane_gap(lane) < lane_gap(soonest))
			soonest = lane
	return soonest

/**
 * Advances arrivals by `seconds`: while arrivals are allowed, each open lane (lane_open()) whose gap
 * is up beams the next prisoner into a ready cell. One per lane, however long the step: several
 * ready cells never fill back to back through one lane. Every lane's gap counts down, open or not,
 * so the crew coming home finds the extensions' lanes ready, one prisoner each.
 */
/datum/outpost_prison/proc/intake_tick(seconds)
	note_extension_intake()
	arrival_gap = max(arrival_gap - seconds, 0)
	for(var/lane in 1 to length(lane_gaps))
		lane_gaps[lane] = max(lane_gaps[lane] - seconds, 0)
	if(arrivals_allowed())
		for(var/lane in 1 to arrival_lanes())
			if(lane_open(lane) && lane_gap(lane) <= 0 && free_slots())
				admit_next(lane = lane)
	arrival_countdown = next_arrival_in()

/// After a lane's arrival its next waits OUTPOST_PRISON_ARRIVAL_GAP_MIN to _MAX seconds, never less than it already had to
/datum/outpost_prison/proc/start_arrival_gap(lane = 1)
	var/gap = rand(OUTPOST_PRISON_ARRIVAL_GAP_MIN, OUTPOST_PRISON_ARRIVAL_GAP_MAX)
	if(lane <= 1)
		arrival_gap = max(arrival_gap, gap)
	else if(lane - 1 <= length(lane_gaps))
		lane_gaps[lane - 1] = max(lane_gaps[lane - 1], gap)

/**
 * Beams a new prisoner into the lowest-numbered cell that can take one: empty, ready and its door
 * not bolted or welded, and starts the gap before `lane`'s next (start_arrival_gap()). `forced`
 * (for the admin panel) skips the wait, the door and the gap, though it still starts a new gap in
 * the lane due soonest. Returns the prisoner, or null.
 */
/datum/outpost_prison/proc/admit_next(forced = FALSE, lane)
	if(!free_slots())
		return null
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell.occupant)
			continue
		if(!forced && (cell.ready_at > world.time || !cell_takes_arrivals(cell)))
			continue
		var/turf/spot = cell.arrival_turf()
		if(!spot)
			continue
		// An ordinary arrival may be a caught bounty criminal from the pool; the admin panel's never is (outpost_prison_bounty.dm).
		var/mob/living/basic/outpost_prisoner/prisoner = new(spot, forced ? null : bounty_pool_take(src))
		admit(prisoner, cell)
		prisoner.beam_in()
		start_arrival_gap(lane || soonest_lane())
		arrival_countdown = next_arrival_in()
		return prisoner
	return null

/// Books a prisoner into a cell (the first free one when none is given), in the mood the yard puts newcomers in
/datum/outpost_prison/proc/admit(mob/living/basic/outpost_prisoner/prisoner, datum/outpost_prison_cell/into)
	if(!into)
		for(var/datum/outpost_prison_cell/cell as anything in cells)
			if(!cell.occupant)
				into = cell
				break
	// Worked out before they join the roster, so the yard's mood is the others'.
	var/starting_mood = arrival_mood()
	prisoner.prison = src
	prisoners |= prisoner
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
/datum/outpost_prison/proc/check_release(mob/living/basic/outpost_prisoner/prisoner)
	if(prisoner.sentence_left <= 0)
		release(prisoner)
	else if(prisoner.sentence_left <= OUTPOST_PRISON_RELEASE_WALK && !istype(prisoner.activity, /datum/prisoner_activity/go_home) && !prisoner.in_trouble())
		// Time to head back to the cell; the routine picks this up.
		prisoner.end_activity()

/// Sentence served: pays the release bonus and beams the prisoner out of wherever they stand
/datum/outpost_prison/proc/release(mob/living/basic/outpost_prisoner/prisoner)
	if(prisoner.phase != PRISONER_PRESENT || prisoner.stat == DEAD)
		return 0
	var/average = prisoner.served_seconds ? prisoner.kept_seconds / prisoner.served_seconds : 0
	var/bonus = round(OUTPOST_PRISON_RELEASE_BONUS * bounty_pay_mult(prisoner) * average)
	pay_treasury(bonus, "Prison release: [prisoner.real_name]")
	add_log("[prisoner.real_name] released, +[bonus] cr.")
	close_bounty_record(prisoner, BOUNTY_RECORD_RELEASED)
	// Friends may say goodbye instead (outpost_prison_life.dm).
	if(!on_prisoner_releasing(prisoner, average))
		prisoner.say_context("release")
	prisoner.beam_out()
	return bonus

/**
 * A prisoner died. Nobody comes for the body (body_tick()): it keeps its cell until staff carry it
 * out of the cell block. A death blamed on staff costs no fine, but the yard takes it hard (blame_death()).
 */
/datum/outpost_prison/proc/on_prisoner_death(mob/living/basic/outpost_prisoner/prisoner)
	add_log("[prisoner.real_name] died.")
	close_bounty_record(prisoner, BOUNTY_RECORD_DEAD)
	prisoner.died_at = world.time
	prisoner.clear_trouble()
	if(prisoner.staff_to_blame())
		blame_death(prisoner)
	if(!loose_count() && !riot_active)
		broke_out = FALSE
	update_riot_lights()

/**
 * Nobody comes for a body. While it lies in the cell block it keeps its cell and sours the yard
 * (bodies_in_cell_block()); once it is out of the cell block (carried to a morgue, spaced, anywhere)
 * it leaves the roster, and its cell waits a refill. An experiment under way that still needs it,
 * a specimen host about to burst, keeps it on the roster wherever it is.
 */
/datum/outpost_prison/proc/body_tick(mob/living/basic/outpost_prisoner/prisoner)
	if(in_cell_block(prisoner) || held_for_experiment(prisoner))
		return
	add_log("[prisoner.real_name]'s body is out of the cell block.")
	forget(prisoner)

/// Prisoners' bodies lying in the cell block, which nobody comes for
/datum/outpost_prison/proc/bodies_in_cell_block()
	. = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
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

/**
 * The outpost was abandoned: intake closes and every prisoner, living or dead, is transferred out.
 * No bonus, and the stipend not yet deposited is dropped. Anyone rioting, breaking out or loose
 * counts as escaped first: OUTPOST_PRISON_ESCAPE_FINE each, as part of the incident (so at most
 * OUTPOST_PRISON_INCIDENT_FINE_CAP in all), and what the treasury cannot cover becomes its debt.
 * Otherwise abandoning mid-riot and claiming the outpost back would skip those fines. A suspension
 * and the count of lost prisoners go with them. A debt stays with the treasury, so whoever claims
 * the outpost next inherits it, and intake stays shut until it is paid.
 */
/datum/outpost_prison/proc/on_outpost_abandoned()
	var/out_of_hand = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase == PRISONER_PRESENT && prisoner.stat != DEAD && (prisoner.is_rioting() || prisoner.trouble == PRISONER_TROUBLE_LOOSE))
			out_of_hand++
	if(out_of_hand)
		var/fine = charge_fine(out_of_hand * OUTPOST_PRISON_ESCAPE_FINE, "Prison escape fines: [out_of_hand] prisoner\s rioting or loose when the outpost was abandoned", TRUE)
		add_log("[out_of_hand] prisoner\s [out_of_hand == 1 ? "was" : "were"] rioting or loose when the outpost was abandoned.[fine ? " Fined [fine] cr." : ""]")
	extras_abandon()
	set_intake(FALSE)
	intake_suspended = FALSE
	lost_log.Cut()
	pay_owed = 0
	var/transferred = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners.Copy())
		if(QDELETED(prisoner) || prisoner.phase == PRISONER_LEAVING)
			continue
		close_bounty_record(prisoner, BOUNTY_RECORD_CLOSED)
		prisoner.beam_out()
		transferred++
	end_incident()
	if(transferred)
		add_log("The outpost was abandoned. [transferred] prisoner\s transferred out.")
