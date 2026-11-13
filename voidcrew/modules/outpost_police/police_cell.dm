/**
 * # Outpost police: cells
 *
 * Owner: P6. The holding cells (/datum/outpost_police_cell), booking, processing, jail terms, bail and
 * release, and the police doors and cell doors (types in police_core.dm). Spec 6.2-6.4 and the cell half of 7.
 *
 * A cell is one /datum/outpost_police_cell per cell_id, built from the landmarks, door and sign the map
 * placed (build_cells()). A bump, a click or an ID never opens its door. The cell opens it to bring a prisoner
 * in, to let an officer out, on release, for a medic, and for a forced door (a crowbar or jaws, from either side
 * while somebody is held or it is shut on someone it does not hold). Otherwise it is hacked like any airlock and
 * mends itself (owner decision 47; the door type below). A cell holding nobody never shuts on a body or a person
 * (abuse MF2).
 *
 * A prisoner is a mind in `prisoners` (mind -> world.time they are let out). `jailed` marks the ones who could
 * not pay. Everything slow about a booking happens in book() on the officer's own actions (the fine, the
 * property strip, the cuffs coming off); the once-a-second tick_cells() does the rest: the wall clock, bail,
 * release, a prisoner in crit or dead, and who is standing where (a prisoner who leaves early is a jailbreak).
 *
 * Player text: the officers speak POLICE_LINE_* contexts and the sign shows "CELL" and a clock. Nothing a
 * player wrote reaches either (abuse M15).
 */

/// A booking that has run this long is treated as over, so a runtime in book() can never hold a prisoner for good
#define CELL_BOOKING_STALE (90 SECONDS)
/// The door stays open this long for an officer to step out
#define CELL_OFFICER_PASS (2 SECONDS)
/// Taking a pair of cuffs off (spec 6.2)
#define CELL_UNCUFF_TIME (2 SECONDS)
/// Longest a booking waits for a knocked-down officer to get up and take the cuffs off
#define CELL_UNCUFF_WAIT (10 SECONDS)
/// Banging on a cell door is heard no more often than this
#define CELL_KNOCK_GAP (2 SECONDS)
/// How far off an officer who can see a cell door answers a bang on it
#define CELL_KNOCK_HEARD 7

// =========================================================================
// THE CELL
// =========================================================================

/datum/outpost_police_cell
	/// The police that keep this cell
	var/datum/outpost_police/police
	/// The lobby tile outside the door: where an officer steps out
	var/turf/outside_turf
	/// Prisoners being booked right now: mind -> world.time the booking started
	var/list/booking = list()
	/// Where each prisoner's body is: mind -> weakref. A prisoner is the mind that was booked, wherever it goes.
	var/list/bodies = list()
	/// Jailed prisoners: mind -> world.time their fine is next tried
	var/list/bail_due = list()
	/// Prisoners someone else moved out of the cell: mind -> world.time they must be back by (abuse M4)
	var/list/return_by = list()
	/// ...and how much of their term was left when they went: mind -> time
	var/list/time_left = list()
	/// ...and who moved them: mind -> weakref
	var/list/carried_by = list()
	/// Prisoners who stepped out of the cell by their own hand: mind -> TRUE (abuse MF1)
	var/list/walked_out = list()
	/// The last time each prisoner took a step of their own: mind -> world.time (the client's move)
	var/list/stepped_at = list()
	/// Who last shoved each prisoner, and when: mind -> list(weakref, world.time)
	var/list/shoved_by = list()
	/// Somebody is working on the door with a crowbar right now
	var/forcing = FALSE
	/// The door stays open until this
	var/open_until = 0
	/// Until this, the cell drives its door past a hack (lifts its bolts, shuts it whatever its wires say) for an
	/// officer at work: booking, release, a medic (decision 47)
	var/override_until = 0
	/// The door is held open for a body to be taken out until this (a prisoner in crit or dead)
	var/medic_until = 0
	/// Weakrefs to those bodies
	var/list/medic_bodies = list()
	/// Prisoners in crit whose mover has been charged with taking them out: mind -> TRUE
	var/list/carry_reported = list()

/datum/outpost_police_cell/New(datum/outpost_police/new_police, new_cell_id)
	. = ..()
	police = new_police
	cell_id = new_cell_id

/datum/outpost_police_cell/Destroy()
	for(var/datum/mind/prisoner in bodies)
		var/mob/living/body = body_of(prisoner)
		if(body)
			UnregisterSignal(body, list(COMSIG_MOVABLE_MOVED, COMSIG_MOB_CLIENT_PRE_MOVE, COMSIG_LIVING_DISARM_HIT))
	if(door)
		if(door.holding_cell == src)
			door.holding_cell = null
			// Nobody stays shut in a cell nobody keeps
			if(!QDELETED(door) && door.density)
				door.cell_open_permitted = TRUE
				INVOKE_ASYNC(door, TYPE_PROC_REF(/obj/machinery/door, open))
		door = null
	sign = null
	police = null
	outside_turf = null
	tiles.Cut()
	prisoners.Cut()
	jailed.Cut()
	booking.Cut()
	bodies.Cut()
	bail_due.Cut()
	return_by.Cut()
	time_left.Cut()
	carried_by.Cut()
	walked_out.Cut()
	stepped_at.Cut()
	shoved_by.Cut()
	medic_bodies.Cut()
	carry_reported.Cut()
	return ..()

/// This cell is being replaced by a rebuild: it lets go of its door and sign without opening anything
/datum/outpost_police_cell/proc/retire()
	if(door?.holding_cell == src)
		door.holding_cell = null
	door = null
	sign = null

/// Whether this cell can take a prisoner: it has floor, a door and a way out of it (looked for again if somebody built over it)
/datum/outpost_police_cell/proc/usable()
	if(QDELETED(src) || QDELETED(police) || !length(tiles) || QDELETED(door))
		return FALSE
	if(!outside_turf || outside_turf.density)
		find_outside(TRUE)
	return !!outside_turf

/// Finds the lobby tile outside the door: across the door from the cell floor. Null (and a mapping error unless `quiet`) if there is none.
/datum/outpost_police_cell/proc/find_outside(quiet = FALSE)
	outside_turf = null
	var/turf/door_turf = get_turf(door)
	if(!door_turf)
		return
	var/inside_dir
	for(var/direction in GLOB.cardinals)
		if(get_step(door_turf, direction) in tiles)
			inside_dir = direction
			break
	if(!inside_dir)
		if(!quiet)
			log_mapping("OUTPOST POLICE: cell '[cell_id]' has a door at [AREACOORD(door_turf)] that does not touch its floor.")
		return
	var/turf/across = get_step(door_turf, turn(inside_dir, 180))
	if(across && !(across in tiles) && !across.density)
		outside_turf = across
		return
	// A door in a corner: any open tile around it that is not the cell
	for(var/direction in GLOB.cardinals)
		var/turf/neighbor = get_step(door_turf, direction)
		if(neighbor && !(neighbor in tiles) && !neighbor.density)
			outside_turf = neighbor
			return
	if(!quiet)
		log_mapping("OUTPOST POLICE: cell '[cell_id]' has no open floor outside its door at [AREACOORD(door_turf)].")

/// The body `prisoner` was booked in, or null once it is gone
/datum/outpost_police_cell/proc/body_of(datum/mind/prisoner)
	var/datum/weakref/ref = bodies[prisoner]
	return ref?.resolve()

/// A tile of the cell with nobody on it if there is one, else any tile; never `avoid` unless it is the only one
/datum/outpost_police_cell/proc/free_tile(turf/avoid)
	var/turf/fallback
	for(var/turf/tile in tiles)
		if(tile == avoid)
			continue
		fallback ||= tile
		if(!tile.density && !(locate(/mob/living) in tile))
			return tile
	return fallback || avoid

/// Whether `prisoner` is still held with `body` alive and about (a booking checks this between its steps)
/datum/outpost_police_cell/proc/holds(datum/mind/prisoner, mob/living/body)
	return !QDELETED(src) && !QDELETED(body) && body.mind == prisoner && (prisoner in prisoners)

// ----- the prisoner list -----

/**
 * Takes `body` into the cell: it is a prisoner until `release_at`, `jail_term` marking one who could not pay.
 * Registers the move watch (abuse M4). Called by book_in(); a test uses it to set a prisoner up.
 */
/datum/outpost_police_cell/proc/admit(mob/living/body, release_at, jail_term = FALSE)
	var/datum/mind/prisoner = body.mind
	if(!prisoner)
		return
	prisoners[prisoner] = release_at
	bodies[prisoner] = WEAKREF(body)
	if(jail_term)
		jailed[prisoner] = TRUE
		bail_due[prisoner] = world.time + OUTPOST_POLICE_BAIL_RETRY
	RegisterSignal(body, COMSIG_MOVABLE_MOVED, PROC_REF(on_prisoner_moved), override = TRUE)
	RegisterSignal(body, COMSIG_MOB_CLIENT_PRE_MOVE, PROC_REF(on_prisoner_step), override = TRUE)
	RegisterSignal(body, COMSIG_LIVING_DISARM_HIT, PROC_REF(on_prisoner_shoved), override = TRUE)
	police?.wake()

/// `prisoner` is no longer held here (released, escaped, down, or gone). Warrant and signals are the caller's.
/datum/outpost_police_cell/proc/forget_prisoner(datum/mind/prisoner)
	var/mob/living/body = body_of(prisoner)
	if(body)
		UnregisterSignal(body, list(COMSIG_MOVABLE_MOVED, COMSIG_MOB_CLIENT_PRE_MOVE, COMSIG_LIVING_DISARM_HIT))
	prisoners -= prisoner
	jailed -= prisoner
	booking -= prisoner
	bodies -= prisoner
	bail_due -= prisoner
	return_by -= prisoner
	time_left -= prisoner
	carried_by -= prisoner
	walked_out -= prisoner
	stepped_at -= prisoner
	shoved_by -= prisoner
	carry_reported -= prisoner

/// The prisoner whose body `body` is, or null
/datum/outpost_police_cell/proc/prisoner_of(mob/living/body)
	for(var/datum/mind/held in bodies)
		if(body_of(held) == body && body.mind == held)
			return held
	return null

/**
 * A prisoner moved. Outside the cell, remember how they left: pulled, carried on a bed or an arm, thrown, pushed,
 * swapped or shoved by someone (abuse M4, MF1), or a step of their own. The tick decides what it means, at most a
 * second later. A move nobody can be found behind (a teleport) is neither: the prisoner gets the time to walk back.
 */
/datum/outpost_police_cell/proc/on_prisoner_moved(mob/living/source, atom/old_loc, movement_dir, forced, list/old_locs)
	SIGNAL_HANDLER
	if(QDELETED(src) || (get_turf(source) in tiles))
		return
	var/datum/mind/prisoner = prisoner_of(source)
	if(!prisoner || (prisoner in carried_by) || (prisoner in walked_out))
		return
	var/mob/living/mover = mover_now(source) || pusher_of(source, old_loc, prisoner)
	if(mover && mover != source)
		carried_by[prisoner] = WEAKREF(mover)
	else if(stepped_at[prisoner] == world.time)
		walked_out[prisoner] = TRUE

/// A prisoner's own player moves them (tg's client move): the step is theirs
/datum/outpost_police_cell/proc/on_prisoner_step(mob/living/source, list/move_args)
	SIGNAL_HANDLER
	var/datum/mind/prisoner = prisoner_of(source)
	if(prisoner)
		stepped_at[prisoner] = world.time

/// Someone shoved a prisoner: the shove's move comes right after this, in the same tick
/datum/outpost_police_cell/proc/on_prisoner_shoved(mob/living/source, mob/living/attacker, zone, obj/item/weapon)
	SIGNAL_HANDLER
	var/datum/mind/prisoner = prisoner_of(source)
	if(prisoner && isliving(attacker) && attacker != source)
		shoved_by[prisoner] = list(WEAKREF(attacker), world.time)

/// Whoever shoved `body` this tick, or is pushing it or swapping places with it in a bump beside `old_loc` (abuse MF1). Null if nobody.
/datum/outpost_police_cell/proc/pusher_of(mob/living/body, atom/old_loc, datum/mind/prisoner)
	var/list/shove = shoved_by[prisoner]
	if(shove && shove[2] == world.time)
		var/datum/weakref/shover_ref = shove[1]
		var/mob/living/shover = shover_ref?.resolve()
		shoved_by -= prisoner
		if(shover)
			return shover
	var/turf/old_turf = get_turf(old_loc)
	if(!old_turf)
		return null
	for(var/mob/living/other in range(1, old_turf))
		if(other != body && other.now_pushing)
			return other
	return null

/// Whether `body`, out of the cell, could walk back by itself: up, free, not held or carried, and its player at the keys
/datum/outpost_police_cell/proc/can_walk_back(mob/living/body, datum/mind/prisoner)
	if(body.incapacitated || HAS_TRAIT(body, TRAIT_RESTRAINED) || body.pulledby || body.buckled || body.throwing)
		return FALSE
	// Asleep at the keyboard (a player's mind and no client): the clock waits for them
	if((body.mind?.key || prisoner?.key) && !body.client)
		return FALSE
	return TRUE

/// Whoever is moving `body` against its will right now: its puller, the one carrying it, the one pushing its bed, its thrower. Null if nobody.
/datum/outpost_police_cell/proc/mover_now(mob/living/body)
	if(isliving(body.pulledby))
		return body.pulledby
	if(isliving(body.buckled))
		return body.buckled
	var/atom/movable/seat = body.buckled
	if(seat && isliving(seat.pulledby))
		return seat.pulledby
	var/datum/thrownthing/flight = body.throwing
	var/mob/thrower = flight?.get_thrower()
	if(isliving(thrower))
		return thrower
	return null

// ----- the door -----

/// The door, shut now if it can be, else as soon as it can be; waits for it if `wait`. TRUE if it is shut.
/datum/outpost_police_cell/proc/shut_door(wait = FALSE)
	open_until = 0
	if(QDELETED(door))
		return FALSE
	if(!wait)
		INVOKE_ASYNC(src, PROC_REF(close_check))
		return door.density
	for(var/attempt in 1 to 6)
		if(QDELETED(src) || QDELETED(door))
			return FALSE
		if(door.density)
			return TRUE
		close_check()
		if(QDELETED(src) || QDELETED(door))
			return FALSE
		if(door.density)
			return TRUE
		sleep(0.5 SECONDS)
	return !QDELETED(door) && door.density

/**
 * Opens the door and keeps it open for `duration` (waits for it to be open if `wait`). TRUE if it is, or will be.
 * `take_over`: an officer is at work, so the cell drives the door past any hack until it is shut behind them.
 */
/datum/outpost_police_cell/proc/open_door(duration, wait = FALSE, take_over = TRUE)
	if(QDELETED(door))
		return FALSE
	open_until = max(open_until, world.time + duration)
	if(take_over)
		override_until = max(override_until, open_until + 10 SECONDS)
	schedule_close_check(max(duration, 1 SECONDS))
	if(!door.density)
		return TRUE
	if(!wait)
		INVOKE_ASYNC(src, PROC_REF(pass_door))
		return TRUE
	return pass_door()

/// Gives the door permission to open and waits until it has. TRUE if it is open.
/datum/outpost_police_cell/proc/pass_door()
	for(var/attempt in 1 to 6)
		if(QDELETED(src) || QDELETED(door))
			return FALSE
		if(!door.density)
			return TRUE
		if(world.time < override_until)
			door.cell_take_over()
		door.cell_open_permitted = TRUE
		if(door.open())
			return TRUE
		sleep(0.5 SECONDS)
	if(QDELETED(door))
		return FALSE
	door.cell_open_permitted = FALSE
	return !door.density

/// Look at the door again after `delay`
/datum/outpost_police_cell/proc/schedule_close_check(delay)
	addtimer(CALLBACK(src, PROC_REF(close_check)), max(delay, 1), TIMER_UNIQUE | TIMER_NO_HASH_WAIT | TIMER_OVERRIDE | TIMER_DELETE_ME)

/// Whether anyone (standing or lying) or anything bulky is in the doorway, so it must not close yet
/datum/outpost_police_cell/proc/doorway_blocked()
	for(var/atom/movable/thing in get_turf(door))
		if(thing == door || iseffect(thing))
			continue
		if(isliving(thing) || thing.density)
			return TRUE
	return FALSE

/// Whether anyone the cell does not hold, alive or dead, is on its floor: a body, a visitor pushed in, a released prisoner (abuse MF2)
/datum/outpost_police_cell/proc/stray_inside()
	for(var/turf/tile as anything in tiles)
		for(var/mob/living/someone in tile)
			if(!prisoner_of(someone))
				return TRUE
	return FALSE

/// Whether a body the medic hold is for is still on the cell floor
/datum/outpost_police_cell/proc/medic_body_inside()
	for(var/datum/weakref/ref in medic_bodies)
		var/mob/living/body = ref.resolve()
		if(body && (get_turf(body) in tiles))
			return TRUE
	return FALSE

/**
 * Shuts the door once nothing holds it open: the open time is up, no medic hold is on, and the doorway is
 * clear. Anything still holding it comes back here later. Sleeps while the door closes.
 */
/datum/outpost_police_cell/proc/close_check()
	if(QDELETED(src) || QDELETED(door) || door.density)
		return
	if(world.time < medic_until)
		if(medic_body_inside())
			schedule_close_check(1 SECONDS)
			return
		medic_until = 0 // the body is out
	if(medic_until && world.time >= medic_until)
		medic_until = 0
	if(!medic_until && length(medic_bodies))
		medic_bodies.Cut()
	if(world.time < open_until)
		schedule_close_check(open_until - world.time)
		return
	if(door.operating || doorway_blocked())
		schedule_close_check(1 SECONDS)
		return
	// Abuse MF2: a cell holding nobody never shuts on a body or on anyone it does not hold
	if(!length(prisoners) && stray_inside())
		schedule_close_check(5 SECONDS)
		return
	// An officer at work: the cell shuts its door whatever a hack did to it. Otherwise a door bolted open stays open
	// until it mends (decision 47).
	if(world.time < override_until)
		door.cell_take_over()
		door.close(BYPASS_DOOR_CHECKS)
	else
		door.close(FORCING_DOOR_CHECKS)
	if(!QDELETED(src) && !QDELETED(door) && !door.density)
		schedule_close_check(1 SECONDS)

/// Whether a crowbar can still be working on the door: shut on a prisoner, or on anyone or any body it does not hold (abuse MF2)
/datum/outpost_police_cell/proc/still_forceable()
	return !QDELETED(door) && door.density && (length(prisoners) || stray_inside())

/**
 * `user` pries the door with `tool`, from either side, while somebody is held (spec 7), or while it is shut on
 * somebody it does not hold (abuse MF2). Sleeps for the whole attempt. The door gives for OUTPOST_POLICE_CELL_OPEN;
 * whoever forced it while a prisoner was held, held or not, is a jailbreak.
 */
/datum/outpost_police_cell/proc/force_door(mob/living/user, obj/item/tool)
	if(forcing || !still_forceable())
		return FALSE
	forcing = TRUE
	tool?.play_tool_sound(door, 50)
	if(tool)
		user.visible_message(
			span_warning("[user] wedges [tool] into [door] and starts forcing it!"),
			span_notice("You wedge [tool] into [door] and start forcing it."),
		)
	else
		user.visible_message(
			span_warning("[user] starts forcing [door]!"),
			span_notice("You start forcing [door]."),
		)
	if(length(prisoners))
		playsound(door, 'sound/machines/warning-buzzer.ogg', 60, FALSE, MEDIUM_RANGE_SOUND_EXTRARANGE)
		police?.cell_station_say(POLICE_LINE_CELL_ALARM)
	log_game("OUTPOST POLICE: [key_name(user)] started forcing [door] at [AREACOORD(door)] with [tool].")
	var/succeeded = do_after(user, OUTPOST_POLICE_CELL_FORCE_TIME, target = door, extra_checks = CALLBACK(src, PROC_REF(still_forceable)))
	if(QDELETED(src))
		return FALSE
	forcing = FALSE
	if(!succeeded)
		return FALSE
	if(!QDELETED(door))
		tool?.play_tool_sound(door, 50)
		user.visible_message(
			span_danger("[user] forces [door] open!"),
			span_notice("You force [door] open."),
		)
	log_game("OUTPOST POLICE: [key_name(user)] forced [door] at [AREACOORD(door)].")
	var/held = length(prisoners)
	open_door(OUTPOST_POLICE_CELL_OPEN, take_over = FALSE)
	if(held)
		police?.report_crime(user, OUTPOST_CRIME_JAILBREAK, null, QDELETED(tool) ? null : tool)
	return TRUE

/**
 * The door was hacked open (a pulsed wire, a pry with the power out, an override card): it stands open a
 * while as a forced door does, and opening it while somebody is held is `culprit`'s jailbreak, as forcing it is.
 */
/datum/outpost_police_cell/proc/door_hacked_open(mob/living/culprit, obj/item/tool = null)
	if(QDELETED(src) || QDELETED(door))
		return
	open_door(OUTPOST_POLICE_CELL_OPEN, take_over = FALSE)
	log_game("OUTPOST POLICE: [culprit ? key_name(culprit) : "nobody known"] hacked [door] open at [AREACOORD(door)].")
	if(!length(prisoners))
		return
	playsound(door, 'sound/machines/warning-buzzer.ogg', 60, FALSE, MEDIUM_RANGE_SOUND_EXTRARANGE)
	police?.cell_station_say(POLICE_LINE_CELL_ALARM)
	if(culprit)
		police?.report_crime(culprit, OUTPOST_CRIME_JAILBREAK, null, QDELETED(tool) ? null : tool)

// ----- the wall clock -----

/// Puts "CELL" and the time to the next release on the sign (nothing under it while the cell is empty)
/datum/outpost_police_cell/proc/update_sign()
	if(QDELETED(sign))
		return
	var/soonest
	for(var/datum/mind/prisoner in prisoners)
		if(!isnull(booking[prisoner]) || (prisoner in return_by))
			continue
		var/release_at = prisoners[prisoner]
		soonest = isnull(soonest) ? release_at : min(soonest, release_at)
	var/clock = ""
	if(!isnull(soonest))
		var/seconds = max(0, ceil((soonest - world.time) / (1 SECONDS)))
		var/minutes = min(round(seconds / 60), 99)
		var/rest = seconds % 60
		clock = "[minutes]:[rest < 10 ? "0" : ""][rest]"
	sign.set_messages("CELL", clock)

// ----- the tick -----

/**
 * Once a second: who is gone, who is down, who has left the cell, whose time is up, whose fine now pays.
 * A prisoner whose warrant is gone (an admin lifted it) is let out.
 */
/datum/outpost_police_cell/proc/tick_cell()
	if(QDELETED(src) || QDELETED(police))
		return
	for(var/datum/mind/prisoner in prisoners.Copy())
		var/mob/living/body = body_of(prisoner)
		if(!body)
			forget_prisoner(prisoner)
			police.close_warrant(prisoner, TRUE)
			police.mark_locker_released(prisoner)
			continue
		if(body.mind != prisoner)
			var/was_booking = !isnull(booking[prisoner])
			forget_prisoner(prisoner)
			if(!was_booking)
				outpost_police_drop_used_cuffs(body)
			police.mark_locker_released(prisoner)
			continue
		if(body.stat == DEAD)
			down_prisoner(prisoner, body)
			continue
		if(HAS_TRAIT(body, TRAIT_CRITICAL_CONDITION))
			crit_prisoner(prisoner, body)
			continue
		var/started = booking[prisoner]
		if(!isnull(started))
			if(world.time - started < CELL_BOOKING_STALE)
				continue // book() is still working on them
			booking -= prisoner // it never finished; the term they were given stands
		var/datum/outpost_warrant/warrant = police.get_warrant(prisoner)
		if(!warrant || warrant.heat <= 0)
			release(prisoner, body, POLICE_LINE_RELEASE)
			continue
		var/inside = (get_turf(body) in tiles)
		if(prisoner in return_by)
			if(inside)
				prisoners[prisoner] = world.time + (time_left[prisoner] || 0)
				return_by -= prisoner
				time_left -= prisoner
				carried_by -= prisoner
				walked_out -= prisoner
				carry_reported -= prisoner
				end_medic_hold(body)
			else if(!can_walk_back(body, prisoner))
				// Down, held, carried or asleep: the time to walk back starts once they can (abuse MF1)
				return_by[prisoner] = max(return_by[prisoner], world.time + OUTPOST_POLICE_CELL_RETURN)
			else if(world.time >= return_by[prisoner])
				escaped(prisoner, body) // the time to walk back is up
			continue
		if(!inside)
			left_cell(prisoner, body)
			continue
		if(world.time >= prisoners[prisoner])
			release(prisoner, body, POLICE_LINE_RELEASE)
			continue
		if(jailed[prisoner] && world.time >= (bail_due[prisoner] || 0))
			bail_due[prisoner] = world.time + OUTPOST_POLICE_BAIL_RETRY
			if(police.charge_fine(warrant))
				release(prisoner, body, POLICE_LINE_BAIL)
	// Abuse MF2: a cell that holds nobody opens for whoever or whatever is shut in it
	if(!length(prisoners) && !QDELETED(door) && door.density && !door.operating && stray_inside())
		open_door(OUTPOST_POLICE_CELL_OPEN)
	update_sign()

/**
 * `prisoner` is outside the cell before their time is up. Only a step of their own is a jailbreak on them; someone
 * else moving them (a pull, a carry, a throw, a push, a swap, a shove) is the mover's jailbreak (abuse M4, MF1), and
 * a move nobody can be found behind charges nobody yet. Either way the prisoner gets the time to walk back.
 */
/datum/outpost_police_cell/proc/left_cell(datum/mind/prisoner, mob/living/body)
	var/datum/weakref/ref = carried_by[prisoner]
	var/mob/living/mover = ref?.resolve() || mover_now(body)
	if(walked_out[prisoner] && (!mover || mover == body))
		escaped(prisoner, body)
		return
	time_left[prisoner] = max(prisoners[prisoner] - world.time, 0)
	return_by[prisoner] = world.time + OUTPOST_POLICE_CELL_RETURN
	if(mover && mover != body && !is_outpost_police_npc(mover))
		police.report_crime(mover, OUTPOST_CRIME_JAILBREAK)

/// `prisoner` walked out (or was teleported out): they are not held any more, and that is a jailbreak
/datum/outpost_police_cell/proc/escaped(datum/mind/prisoner, mob/living/body)
	forget_prisoner(prisoner) // out of custody before the report, so the officers may act on it
	police.report_crime(body, OUTPOST_CRIME_JAILBREAK)

/// `prisoner` is let out: the warrant closes, the door opens, the sergeant says `line`
/datum/outpost_police_cell/proc/release(datum/mind/prisoner, mob/living/body, line)
	forget_prisoner(prisoner)
	// Booked while the officer could not get the cuffs off: nobody walks out of a served term in police cuffs
	outpost_police_drop_used_cuffs(body)
	police.close_warrant(prisoner, TRUE)
	SEND_SIGNAL(police, COMSIG_OUTPOST_POLICE_RELEASED, body)
	police.cell_station_say(line)
	open_door(OUTPOST_POLICE_CELL_OPEN)

/**
 * `prisoner` is in crit: the term stops, not ends (abuse review 3 SF1). The door opens for a medic and the time
 * left is kept, as for a prisoner carried out: once they can walk again they have OUTPOST_POLICE_CELL_RETURN to be
 * back inside, or it is a jailbreak. Whoever takes them out of the cell meanwhile answers for it.
 */
/datum/outpost_police_cell/proc/crit_prisoner(datum/mind/prisoner, mob/living/body)
	var/started = booking[prisoner]
	if(!isnull(started) && world.time - started < CELL_BOOKING_STALE)
		return // book_in() is still working on them; their term is set when it is done
	if(!(prisoner in return_by))
		booking -= prisoner
		time_left[prisoner] = max(prisoners[prisoner] - world.time, 0)
		medic_bodies |= WEAKREF(body)
		medic_until = world.time + OUTPOST_POLICE_CELL_MEDIC_OPEN
		police.cell_station_say(POLICE_LINE_MEDIC)
		open_door(0)
	return_by[prisoner] = max(return_by[prisoner], world.time + OUTPOST_POLICE_CELL_RETURN)
	if(!(get_turf(body) in tiles) && !carry_reported[prisoner])
		var/datum/weakref/ref = carried_by[prisoner]
		var/mob/living/mover = ref?.resolve() || mover_now(body)
		if(mover && mover != body && mover.mind && !is_outpost_police_npc(mover))
			carry_reported[prisoner] = TRUE
			police.report_crime(mover, OUTPOST_CRIME_JAILBREAK)

/// A prisoner who was down is back on their feet in the cell: the door no longer waits for a medic
/datum/outpost_police_cell/proc/end_medic_hold(mob/living/body)
	var/datum/weakref/ref = WEAKREF(body)
	if(!(ref in medic_bodies))
		return
	medic_bodies -= ref
	if(!length(medic_bodies))
		medic_until = 0
	schedule_close_check(1 SECONDS)

/// `prisoner` is dead in the cell: the term is over, the door opens and stays open for a medic
/datum/outpost_police_cell/proc/down_prisoner(datum/mind/prisoner, mob/living/body)
	forget_prisoner(prisoner)
	police.close_warrant(prisoner, TRUE)
	SEND_SIGNAL(police, COMSIG_OUTPOST_POLICE_RELEASED, body)
	medic_bodies += WEAKREF(body)
	medic_until = world.time + OUTPOST_POLICE_CELL_MEDIC_OPEN
	police.cell_station_say(POLICE_LINE_MEDIC)
	open_door(0)

/// The cell floor tile right inside `door`, or null
/datum/outpost_police_cell/proc/cell_entry_tile()
	var/turf/door_turf = get_turf(door)
	if(!door_turf)
		return null
	for(var/direction in GLOB.cardinals)
		var/turf/candidate = get_step(door_turf, direction)
		if((candidate in tiles) && !candidate.density)
			return candidate
	return null

/// Any standing dense mob on `spot` other than `ignore_a` or `ignore_b`
/datum/outpost_police_cell/proc/cell_standing_on(turf/spot, mob/living/ignore_a, mob/living/ignore_b)
	if(!spot)
		return null
	for(var/mob/living/someone in spot)
		if(someone == ignore_a || someone == ignore_b || !someone.density)
			continue
		return someone
	return null

/// A cardinal neighbor of `from_tile` inside `tiles` with no dense obstacle or standing mob
/datum/outpost_police_cell/proc/cell_open_neighbor(turf/from_tile, mob/living/ignore_a, mob/living/ignore_b)
	if(!from_tile)
		return null
	for(var/direction in GLOB.cardinals)
		var/turf/neighbor = get_step(from_tile, direction)
		if((neighbor in tiles) && !neighbor.density && !cell_standing_on(neighbor, ignore_a, ignore_b))
			return neighbor
	return null

/// An outpost NPC standing on `next`, the officer's next step in or out of the cell, steps out of the way first
/datum/outpost_police_cell/proc/cell_clear_step(mob/living/officer, turf/next)
	if(!next || QDELETED(officer))
		return
	var/turf/door_turf = get_turf(door)
	for(var/mob/living/someone in next)
		if(someone == officer || officer.pulling == someone || !someone.density || prisoner_of(someone))
			continue
		outpost_npc_step_aside(someone, officer, list(next, door_turf))

/// Delay between physical walk steps when entering or leaving a cell
/datum/outpost_police_cell/proc/cell_step_pause()
	return max(1, round(0.15 SECONDS * GLOB.outpost_police_property_time_scale))

/**
 * Physically walks `officer` and `suspect` into the cell through `door` using real movement and pulling (never
 * forceMove; owner bug 3). Leaves `suspect` on a cell tile and `officer` adjacent inside the cell (or in the open
 * doorway when every other cell tile is already occupied). Sleeps. TRUE if `suspect` is inside and in reach.
 */
/datum/outpost_police_cell/proc/cell_walk_in(mob/living/carbon/suspect, mob/living/officer)
	var/turf/door_turf = get_turf(door)
	var/turf/entry_tile = cell_entry_tile()
	if(!door_turf || !entry_tile || !outside_turf)
		return FALSE
	if(suspect.z != door_turf.z || officer.z != door_turf.z || get_dist(suspect, door_turf) > 3 || get_dist(officer, door_turf) > 3)
		return FALSE
	if(!open_door(OUTPOST_POLICE_CELL_OPEN, TRUE))
		return FALSE
	if(QDELETED(suspect) || QDELETED(officer) || officer.stat == DEAD)
		return FALSE
	if(suspect.buckled)
		suspect.buckled.unbuckle_mob(suspect, TRUE)
	var/old_officer_intent = officer.move_intent
	var/old_officer_combat = officer.combat_mode
	var/old_suspect_intent = suspect.move_intent
	officer.move_intent = MOVE_INTENT_RUN
	officer.combat_mode = FALSE
	suspect.move_intent = MOVE_INTENT_RUN
	var/pause = cell_step_pause()

	if(!(get_turf(suspect) in tiles))
		for(var/step_try in 1 to 4)
			if(QDELETED(src) || QDELETED(officer) || QDELETED(suspect) || officer.stat == DEAD || officer.Adjacent(suspect))
				break
			step_towards(officer, suspect)
			sleep(pause)
		if(QDELETED(src) || QDELETED(officer) || QDELETED(suspect) || officer.stat == DEAD || !officer.Adjacent(suspect))
			suspect?.move_intent = old_suspect_intent
			officer?.move_intent = old_officer_intent
			officer?.combat_mode = old_officer_combat
			return FALSE
		if(officer.pulling != suspect)
			officer.start_pulling(suspect)
		if(officer.pulling != suspect)
			suspect.move_intent = old_suspect_intent
			officer.move_intent = old_officer_intent
			officer.combat_mode = old_officer_combat
			return FALSE

		for(var/step_try in 1 to 3)
			if(QDELETED(src) || QDELETED(officer) || QDELETED(suspect) || officer.stat == DEAD)
				break
			var/turf/here = get_turf(officer)
			if(!here || here == outside_turf || here == door_turf || (here in tiles))
				break
			cell_clear_step(officer, get_step_towards(officer, outside_turf))
			step_towards(officer, outside_turf)
			sleep(pause)

		if(!QDELETED(src) && !QDELETED(officer) && !QDELETED(suspect) && officer.stat != DEAD && get_turf(officer) != door_turf && !(get_turf(officer) in tiles))
			if(officer.pulling != suspect && officer.Adjacent(suspect))
				officer.start_pulling(suspect)
			cell_clear_step(officer, door_turf)
			officer.Move(door_turf, get_dir(officer, door_turf))
			sleep(pause)

		if(!QDELETED(src) && !QDELETED(officer) && !QDELETED(suspect) && officer.stat != DEAD && !(get_turf(officer) in tiles))
			cell_clear_step(officer, entry_tile)
			var/mob/living/entry_blocker = cell_standing_on(entry_tile, suspect, officer)
			if(entry_blocker && ishuman(officer) && ishuman(entry_blocker))
				var/turf/shove_tile = get_step(entry_tile, get_dir(door_turf, entry_tile))
				if(shove_tile && ((shove_tile in tiles) || shove_tile.density))
					var/mob/living/carbon/human/cop = officer
					cop.disarm(entry_blocker)
			if(!cell_standing_on(entry_tile, suspect, officer))
				if(officer.pulling != suspect && officer.Adjacent(suspect))
					officer.start_pulling(suspect)
				officer.Move(entry_tile, get_dir(officer, entry_tile))
				sleep(pause)

		if(!QDELETED(src) && !QDELETED(officer) && !QDELETED(suspect) && officer.stat != DEAD && get_turf(officer) == entry_tile)
			var/turf/inner_tile = cell_open_neighbor(entry_tile, suspect, officer)
			if(inner_tile)
				if(officer.pulling != suspect && officer.Adjacent(suspect))
					officer.start_pulling(suspect)
				officer.Move(inner_tile, get_dir(officer, inner_tile))
				sleep(pause)
				officer.stop_pulling()
				// Keep the officer between the prisoner and the door so an uncuffed prisoner cannot block the exit
				if(!QDELETED(src) && !QDELETED(officer) && !QDELETED(suspect) && officer.stat != DEAD && get_turf(suspect) == entry_tile && get_turf(officer) == inner_tile)
					officer.Move(entry_tile, get_dir(officer, entry_tile))
					sleep(pause)
			else if(!(get_turf(suspect) in tiles) && get_turf(suspect) == door_turf)
				if(officer.pulling != suspect && officer.Adjacent(suspect))
					officer.start_pulling(suspect)
				officer.Move(door_turf, get_dir(officer, door_turf))
				sleep(pause)
		officer?.stop_pulling()
	else
		officer.stop_pulling()
		if(!officer.Adjacent(suspect))
			if(get_turf(officer) != door_turf && !(get_turf(officer) in tiles))
				officer.Move(door_turf, get_dir(officer, door_turf))
				sleep(pause)
			if(!QDELETED(officer) && !QDELETED(suspect) && !officer.Adjacent(suspect) && !cell_standing_on(entry_tile, suspect, officer))
				officer.Move(entry_tile, get_dir(officer, entry_tile))
				sleep(pause)

	if(!QDELETED(suspect))
		suspect.move_intent = old_suspect_intent
	if(!QDELETED(officer))
		officer.move_intent = old_officer_intent
		officer.combat_mode = old_officer_combat
	return !QDELETED(src) && !QDELETED(suspect) && !QDELETED(officer) && officer.stat != DEAD && (get_turf(suspect) in tiles) && officer.Adjacent(suspect)

/// Physically walks `officer` back out of the cell onto `outside_turf` using real Move() steps. Sleeps.
/datum/outpost_police_cell/proc/cell_walk_out(mob/living/officer)
	if(QDELETED(src) || QDELETED(officer) || officer.stat == DEAD || !outside_turf)
		return FALSE
	var/turf/door_turf = get_turf(door)
	if(!door_turf)
		return FALSE
	if(get_turf(officer) == outside_turf)
		return TRUE
	if(!(get_turf(officer) in tiles) && get_turf(officer) != door_turf)
		return FALSE
	if((get_turf(officer) in tiles) && !open_door(CELL_OFFICER_PASS, TRUE))
		return FALSE
	if(QDELETED(src) || QDELETED(officer) || officer.stat == DEAD)
		return FALSE
	var/old_intent = officer.move_intent
	var/old_combat = officer.combat_mode
	officer.move_intent = MOVE_INTENT_RUN
	officer.combat_mode = FALSE
	officer.stop_pulling()
	var/pause = cell_step_pause()
	var/turf/entry_tile = cell_entry_tile()

	if((get_turf(officer) in tiles) && entry_tile && get_turf(officer) != entry_tile)
		for(var/step_try in 1 to 4)
			if(QDELETED(src) || QDELETED(officer) || officer.stat == DEAD || get_turf(officer) == entry_tile)
				break
			var/turf/next_step = get_step_towards(officer, entry_tile)
			cell_clear_step(officer, next_step)
			var/mob/living/blocker = cell_standing_on(next_step, null, officer)
			if(blocker && blocker.combat_mode && ishuman(officer) && ishuman(blocker))
				var/mob/living/carbon/human/cop = officer
				cop.disarm(blocker)
			step_towards(officer, entry_tile)
			sleep(pause)

	if(!QDELETED(src) && !QDELETED(officer) && officer.stat != DEAD && get_turf(officer) == entry_tile)
		cell_clear_step(officer, door_turf)
		var/mob/living/door_blocker = cell_standing_on(door_turf, null, officer)
		if(door_blocker)
			if(door_blocker.combat_mode && ishuman(officer) && ishuman(door_blocker))
				var/mob/living/carbon/human/cop = officer
				cop.disarm(door_blocker)
		officer.Move(door_turf, get_dir(officer, door_turf))
		sleep(pause)

	if(!QDELETED(src) && !QDELETED(officer) && officer.stat != DEAD && get_turf(officer) == door_turf)
		cell_clear_step(officer, outside_turf)
		var/mob/living/outside_blocker = cell_standing_on(outside_turf, null, officer)
		if(outside_blocker)
			if(outside_blocker.combat_mode && ishuman(officer) && ishuman(outside_blocker))
				var/mob/living/carbon/human/cop = officer
				cop.disarm(outside_blocker)
		officer.Move(outside_turf, get_dir(officer, outside_turf))
		sleep(pause)

	if(!QDELETED(officer))
		officer.move_intent = old_intent
		officer.combat_mode = old_combat
	return !QDELETED(officer) && get_turf(officer) == outside_turf

/**
 * Brings `suspect` in and books them: the fine, then processing (paid) or the jail strip (not paid), the cuffs
 * off, the officer out. At three stars and up there is no fine: the jail strip and a sentence that grows with the
 * stars (owner decision 37). Sleeps. TRUE once the suspect is held; FALSE (nothing taken) if they could not be.
 */
/datum/outpost_police_cell/proc/book_in(mob/living/carbon/suspect, mob/living/officer, datum/outpost_warrant/warrant)
	var/datum/mind/prisoner = suspect.mind
	var/full_stars = clamp(police.get_stars(prisoner), 1, 5)
	var/no_fine = full_stars >= 3
	var/stars = clamp(full_stars, 1, 2)
	if(!cell_walk_in(suspect, officer))
		cell_walk_out(officer)
		shut_door(TRUE)
		return FALSE
	// Until the booking is over they are held but not on a clock
	admit(suspect, world.time + OUTPOST_POLICE_HOLDS[stars])
	booking[prisoner] = world.time
	// The booking line is the arresting officer's (police_arrest.dm act_book())
	var/guarding_doorway = (get_turf(officer) == get_turf(door))
	var/old_guard_combat = officer.combat_mode
	if(guarding_doorway)
		officer.combat_mode = TRUE
	else if(!doorway_blocked())
		shut_door(TRUE)
	if(!holds(prisoner, suspect))
		if(!QDELETED(officer) && guarding_doorway)
			officer.combat_mode = old_guard_combat
		cell_walk_out(officer)
		shut_door(TRUE)
		return FALSE
	// The fine, with the door shut on the two of them (or the officer blocking the doorway when every cell tile is full)
	var/paid = no_fine ? FALSE : police.charge_fine(warrant)
	if(paid)
		police.say_fine_paid(officer)
	else
		// Gear into a locker before the cuffs come off (abuse M25); never uncuff or book an unstripped prisoner
		if(!police.cell_strip_prisoner(suspect, officer))
			forget_prisoner(prisoner)
			if(!QDELETED(officer) && guarding_doorway)
				officer.combat_mode = old_guard_combat
			cell_walk_out(officer)
			if(length(prisoners))
				shut_door(TRUE)
			else if(stray_inside())
				open_door(OUTPOST_POLICE_CELL_OPEN)
			update_sign()
			return FALSE
		if(!holds(prisoner, suspect))
			if(!QDELETED(officer) && guarding_doorway)
				officer.combat_mode = old_guard_combat
			cell_walk_out(officer)
			shut_door(TRUE)
			return FALSE
	var/list/worn_restraints = list()
	if(suspect.handcuffed)
		worn_restraints += suspect.handcuffed
	if(suspect.legcuffed)
		worn_restraints += suspect.legcuffed
	police.cell_remove_cuffs(suspect, officer)
	for(var/obj/item/restraint as anything in worn_restraints)
		if(QDELETED(restraint) || restraint == suspect.handcuffed || restraint == suspect.legcuffed)
			continue
		if(paid)
			if(isturf(restraint.loc) && !QDELETED(suspect))
				suspect.put_in_hands(restraint)
		else if(!police.store_extra_property(suspect, restraint) && isturf(restraint.loc) && !outpost_police_untouchable(restraint) && usable())
			restraint.forceMove(outside_turf)
	if(!holds(prisoner, suspect))
		if(!QDELETED(officer) && guarding_doorway)
			officer.combat_mode = old_guard_combat
		cell_walk_out(officer)
		shut_door(TRUE)
		return FALSE
	if(!QDELETED(officer) && guarding_doorway)
		officer.combat_mode = old_guard_combat
	// The officer steps out
	cell_walk_out(officer)
	var/term = paid ? OUTPOST_POLICE_HOLDS[stars] : OUTPOST_POLICE_JAIL[full_stars]
	prisoners[prisoner] = world.time + term
	if(!paid)
		jailed[prisoner] = TRUE
		// No bail at three stars and up: the sentence is served
		bail_due[prisoner] = no_fine ? INFINITY : world.time + OUTPOST_POLICE_BAIL_RETRY
	booking -= prisoner
	shut_door(TRUE)
	update_sign()
	SEND_SIGNAL(police, COMSIG_OUTPOST_POLICE_BOOKED, suspect, !paid)
	return TRUE

// =========================================================================
// THE STATION'S CELLS
// =========================================================================

/**
 * Builds one cell per cell_id from the interior's landmarks, doors and signs (called by link_interior()). A
 * cell needs floor and a door; a sign is optional. Anything that does not fit together is a mapping error.
 */
/datum/outpost_police/proc/build_cells(list/cell_landmarks, list/cell_doors, list/cell_signs)
	for(var/datum/outpost_police_cell/old_cell in cells)
		old_cell.retire()
	QDEL_LIST(cells)
	var/list/tiles_by_id = list()
	var/list/doors_by_id = list()
	var/list/signs_by_id = list()
	for(var/obj/effect/landmark/outpost_police_cell/mark in cell_landmarks)
		var/turf/tile = get_turf(mark)
		if(isnull(mark.cell_id) || !tile)
			log_mapping("OUTPOST POLICE: [outpost] has a cell landmark with no cell_id or no floor ([AREACOORD(mark)]).")
			continue
		LAZYADD(tiles_by_id["[mark.cell_id]"], tile)
	for(var/obj/machinery/door/airlock/outpost/glass/police_cell/cell_door in cell_doors)
		if(isnull(cell_door.cell_id))
			log_mapping("OUTPOST POLICE: [outpost] has a cell door with no cell_id ([AREACOORD(cell_door)]).")
			continue
		LAZYADD(doors_by_id["[cell_door.cell_id]"], cell_door)
	for(var/obj/machinery/status_display/outpost_berth/police_cell/cell_sign in cell_signs)
		if(isnull(cell_sign.cell_id))
			log_mapping("OUTPOST POLICE: [outpost] has a cell sign with no cell_id ([AREACOORD(cell_sign)]).")
			continue
		LAZYADD(signs_by_id["[cell_sign.cell_id]"], cell_sign)
	for(var/cell_id in tiles_by_id)
		var/list/cell_doors_here = doors_by_id[cell_id]
		if(!length(cell_doors_here))
			log_mapping("OUTPOST POLICE: [outpost] has cell '[cell_id]' floor and no door for it.")
			continue
		if(length(cell_doors_here) > 1)
			log_mapping("OUTPOST POLICE: [outpost] has [length(cell_doors_here)] doors for cell '[cell_id]'; only the first is used.")
		var/datum/outpost_police_cell/cell = new(src, cell_id)
		cell.tiles = tiles_by_id[cell_id]
		cell.door = cell_doors_here[1]
		cell.door.holding_cell = cell
		var/list/cell_signs_here = signs_by_id[cell_id]
		if(length(cell_signs_here))
			cell.sign = cell_signs_here[1]
			cell.sign.set_messages("CELL", "")
		cell.find_outside()
		if(!cell.outside_turf)
			log_mapping("OUTPOST POLICE: [outpost]'s cell '[cell_id]' cannot be used.")
		cells += cell
	for(var/cell_id in doors_by_id)
		if(!(cell_id in tiles_by_id))
			log_mapping("OUTPOST POLICE: [outpost] has a cell door for '[cell_id]' and no floor for it.")
	for(var/cell_id in signs_by_id)
		if(!(cell_id in tiles_by_id))
			log_mapping("OUTPOST POLICE: [outpost] has a cell sign for '[cell_id]' and no cell.")
	if(!length(cells))
		log_mapping("OUTPOST POLICE: [outpost] has no holding cell; a one or two star arrest is fined and let go, three or more is held cuffed at the desk.")

/// The usable cell with the fewest prisoners, the one with free standing room and nearest `near` of equals. Null if there is none.
/datum/outpost_police/proc/cell_best(atom/near)
	var/datum/outpost_police_cell/best
	var/best_load
	var/best_room
	var/best_distance
	for(var/datum/outpost_police_cell/cell in cells)
		if(!cell.usable())
			continue
		var/load = length(cell.prisoners)
		var/room = 0
		for(var/turf/tile as anything in cell.tiles)
			if(!tile.density && !cell.cell_standing_on(tile))
				room = 1
				break
		var/turf/near_turf = get_turf(near)
		var/distance = near ? ((near_turf && cell.door && near_turf.z == cell.door.z) ? get_dist(near_turf, cell.door) : 1000) : 0
		if(isnull(best) || load < best_load || (load == best_load && room > best_room) || (load == best_load && room == best_room && distance < best_distance))
			best = cell
			best_load = load
			best_room = room
			best_distance = distance
	return best

/// The lobby tile outside the door of the cell the next booking uses, or null
/datum/outpost_police/proc/cell_door_turf(atom/near)
	return cell_best(near)?.outside_turf

/**
 * Whether `who` is in police custody: from an arrest's cuffs (or grip) going on to release from a cell. By the police's
 * own state, not the cuffs alone: someone in police cuffs nobody is arresting any more (carried off and brought back,
 * a case that fell through) is an ordinary suspect again, to be chased and taken back in (review-1 S5).
 */
/datum/outpost_police/proc/in_custody(mob/living/who)
	if(!who?.mind)
		return FALSE
	var/datum/outpost_police_case/case = cases[who.mind]
	var/mob/living/carbon/carbon_who = who
	if(istype(carbon_who) && case && !QDELETED(case) && case.get_suspect() == carbon_who && case.suspect_restrained(carbon_who))
		return TRUE
	return !!cell_holding(who.mind)

/// The cell holding `who`, or null
/datum/outpost_police/proc/cell_holding(datum/mind/who)
	if(!who)
		return null
	for(var/datum/outpost_police_cell/cell in cells)
		if(who in cell.prisoners)
			return cell
	return null

/**
 * Books `suspect`, brought to a cell by `officer`: into the emptier cell with the officer, the fine, then
 * processing (paid) or the jail strip and a term (not paid), the cuffs off, the officer out. Sleeps. TRUE once
 * the suspect is held (or, in an outpost with no cell, fined and let go); FALSE, with nothing taken, if they
 * cannot be booked: no warrant, down, or already held.
 */
/datum/outpost_police/proc/book(mob/living/carbon/suspect, mob/living/officer)
	if(QDELETED(src) || !iscarbon(suspect) || QDELETED(suspect) || !suspect.mind || QDELETED(officer))
		return FALSE
	var/datum/mind/prisoner = suspect.mind
	var/datum/outpost_warrant/warrant = get_warrant(prisoner)
	if(!warrant || warrant.heat <= 0)
		return FALSE
	if(suspect.stat == DEAD || HAS_TRAIT(suspect, TRAIT_CRITICAL_CONDITION) || officer.stat == DEAD)
		return FALSE
	if(cell_holding(prisoner))
		return FALSE
	// The emptiest cell, however many it holds already: a cell takes more than one (lead decision L-A2)
	var/datum/outpost_police_cell/cell = cell_best(officer)
	if(cell)
		return cell.book_in(suspect, officer, warrant)
	// No cell at three stars and up: no fine and no letting go (owner decision 37). The arrest holds them until a
	// cell can be had (police_arrest.dm, CASE_STEP_HOLD).
	if(get_stars(prisoner) >= 3)
		return FALSE
	return cell_book_fallback(suspect, officer, warrant)

/// An outpost with no usable cell, one or two stars: the fine is tried on the spot and they are let go
/datum/outpost_police/proc/cell_book_fallback(mob/living/carbon/suspect, mob/living/officer, datum/outpost_warrant/warrant)
	var/datum/mind/prisoner = suspect.mind
	if(charge_fine(warrant))
		say_fine_paid(officer)
	cell_remove_cuffs(suspect, officer)
	if(QDELETED(suspect))
		return FALSE
	close_warrant(prisoner, TRUE)
	SEND_SIGNAL(src, COMSIG_OUTPOST_POLICE_BOOKED, suspect, FALSE)
	SEND_SIGNAL(src, COMSIG_OUTPOST_POLICE_RELEASED, suspect)
	return TRUE

/**
 * `officer` strips `prisoner` for jail (`store_property()`), three tries, waiting up to `CELL_UNCUFF_WAIT` if the
 * officer was stunned or knocked down meanwhile. When every property locker belongs to inmates still in the cells,
 * clothes stay on (spec) while warrant crime tools and stolen goods still come off to evidence so no weapon enters
 * the cell. FALSE if the officer could not finish stripping an unstripped prisoner.
 */
/datum/outpost_police/proc/cell_strip_prisoner(mob/living/carbon/prisoner, mob/living/officer)
	var/wait_until = world.time + CELL_UNCUFF_WAIT
	for(var/attempt in 1 to 3)
		if(QDELETED(prisoner) || !prisoner.mind || !ishuman(prisoner))
			return FALSE
		while(!QDELETED(officer) && officer.stat != DEAD && (officer.stat != CONSCIOUS || HAS_TRAIT(officer, TRAIT_INCAPACITATED)) && world.time < wait_until)
			sleep(0.5 SECONDS)
		if(QDELETED(prisoner) || !prisoner.mind || !ishuman(prisoner))
			return FALSE
		if(QDELETED(officer) || officer.stat != CONSCIOUS || HAS_TRAIT(officer, TRAIT_INCAPACITATED))
			return FALSE
		if(!property_strip_check(prisoner, officer))
			return FALSE
		if(store_property(prisoner, officer))
			return TRUE
		if(QDELETED(prisoner) || !prisoner.mind || !ishuman(prisoner))
			return FALSE
		if(QDELETED(officer) || officer.stat != CONSCIOUS || HAS_TRAIT(officer, TRAIT_INCAPACITATED))
			continue
		if(length(lockers) && !property_locker_for(prisoner, must_shut = TRUE))
			var/delay = max(1, round(OUTPOST_POLICE_STRIP_TIME * GLOB.outpost_police_property_time_scale))
			if(!do_after(officer, delay, prisoner, IGNORE_USER_LOC_CHANGE | IGNORE_TARGET_LOC_CHANGE | IGNORE_HELD_ITEM, extra_checks = CALLBACK(src, PROC_REF(property_strip_check), prisoner, officer), interaction_key = "outpost_police_strip"))
				continue
			if(QDELETED(prisoner) || QDELETED(officer) || officer.stat != CONSCIOUS || HAS_TRAIT(officer, TRAIT_INCAPACITATED))
				continue
			strip_evidence(prisoner, officer)
			return TRUE
	return FALSE

/**
 * `officer` takes `prisoner`'s cuffs off, a real do_after, three tries. An officer knocked down or out meanwhile
 * gets up and tries again, CELL_UNCUFF_WAIT at most. If the officer cannot, the cuffs stay on (a served term
 * drops them, release()).
 */
/datum/outpost_police/proc/cell_remove_cuffs(mob/living/carbon/prisoner, mob/living/officer)
	var/wait_until = world.time + CELL_UNCUFF_WAIT
	for(var/attempt in 1 to 3)
		if(QDELETED(prisoner) || (!prisoner.handcuffed && !prisoner.legcuffed))
			return
		while(!QDELETED(officer) && officer.stat != DEAD && (officer.stat != CONSCIOUS || HAS_TRAIT(officer, TRAIT_INCAPACITATED)) && world.time < wait_until)
			sleep(0.5 SECONDS)
		if(QDELETED(prisoner) || (!prisoner.handcuffed && !prisoner.legcuffed))
			return
		if(QDELETED(officer) || officer.stat != CONSCIOUS)
			return
		if(do_after(officer, CELL_UNCUFF_TIME, prisoner, IGNORE_HELD_ITEM, interaction_key = "outpost_police_uncuff"))
			prisoner.uncuff()
			return

/// Someone bangs on the door of `cell`: the nearest officer who can see the door tells them to knock it off
/datum/outpost_police_cell/proc/answer_knock(mob/living/knocker)
	if(is_outpost_police_npc(knocker))
		return null
	var/turf/door_turf = get_turf(door)
	if(!door_turf || !police)
		return null
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/best
	var/best_distance = CELL_KNOCK_HEARD + 1
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police.officers)
		if(!officer.police_can_speak() || officer.z != door_turf.z)
			continue
		var/distance = get_dist(officer, door_turf)
		if(distance >= best_distance || !(door_turf in view(CELL_KNOCK_HEARD, officer)))
			continue
		best = officer
		best_distance = distance
	if(!best)
		return null
	if(!best.buckled)
		best.face_atom(door)
	return best.police_say(POLICE_LINE_KNOCK)

/// `officer` tells the prisoner their fine went through: the receipt, said in the cell
/datum/outpost_police/proc/say_fine_paid(mob/living/officer)
	if(!istype(officer, /mob/living/carbon/human/npc/ambient_npc/outpost/police))
		return
	INVOKE_ASYNC(officer, TYPE_PROC_REF(/mob/living/carbon/human/npc/ambient_npc/outpost/police, police_say), POLICE_LINE_FINE_PAID)

/// The sergeant says `line` (a POLICE_LINE_* context) at the station; with none able to speak, whoever is on the radio
/datum/outpost_police/proc/cell_station_say(line)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(officer.unit_kind == POLICE_UNIT_SERGEANT && officer.police_can_speak())
			INVOKE_ASYNC(officer, TYPE_PROC_REF(/mob/living/carbon/human/npc/ambient_npc/outpost/police, police_say), line)
			return
	INVOKE_ASYNC(src, PROC_REF(say_dispatch), line)

/// Once a second (police_core.dm tick()): signs, bail, releases, containment
/datum/outpost_police/proc/tick_cells()
	for(var/datum/outpost_police_cell/cell in cells)
		cell.tick_cell()

// =========================================================================
// THE DOORS
// =========================================================================

/// A door officers use between the concourse and their lift: it opens for an officer's ID and for nothing else
/obj/machinery/door/airlock/outpost/police
	desc = "A door to the staff lift."

// Abuse M1: an emagged airlock stands open and broken, which would open the lift to anyone
/obj/machinery/door/airlock/outpost/police/emag_act(mob/user, obj/item/card/emag/emag_card)
	return FALSE

/// Whether `from`, next to `door_turf`, is on the inside of the small closet or booth anchored at `anchor`
/proc/outpost_inside_pocket(turf/from, turf/door_turf, turf/anchor)
	if(!anchor || anchor.z != door_turf.z || get_dist(from, door_turf) != 1 || get_dist(door_turf, anchor) > 4)
		return FALSE
	var/dot = (from.x - door_turf.x) * (anchor.x - door_turf.x) + (from.y - door_turf.y) * (anchor.y - door_turf.y)
	if(dot <= 0)
		return FALSE
	var/from_manhattan = abs(from.x - anchor.x) + abs(from.y - anchor.y)
	var/door_manhattan = abs(door_turf.x - anchor.x) + abs(door_turf.y - anchor.y)
	return from_manhattan < door_manhattan

// Abuse SF5: from the inside of a lift closet or a guard booth anyone may leave, so nobody who followed staff in is shut inside.
// Only a lift or booth desk right behind this door counts, never a police lift across the concourse. Coming in still takes an officer's ID.
/obj/machinery/door/airlock/outpost/police/unrestricted_side(mob/opener)
	. = ..()
	if(. || !opener)
		return
	var/obj/structure/overmap/trader_outpost/home = outpost
	var/datum/outpost_police/police = istype(home) ? home.police : null
	var/turf/door_turf = get_turf(src)
	var/turf/from = get_turf(opener)
	if(!police || !door_turf || !from || from.z != door_turf.z || from == door_turf)
		return
	for(var/turf/lift as anything in police.lift_turfs)
		if(outpost_inside_pocket(from, door_turf, lift))
			return TRUE
	for(var/datum/outpost_shop/shop as anything in home.get_all_shops())
		if(!istype(shop, /datum/outpost_shop/vendor/checkpoint))
			continue
		var/datum/outpost_recovery_post/post = home.recovery?.posts?[shop]
		var/turf/desk = post?.spot || shop.counter_turf
		if(!desk && istype(shop.trader_npc, /mob/living/carbon/human/npc/ambient_npc))
			var/mob/living/carbon/human/npc/ambient_npc/guard_npc = shop.trader_npc
			desk = guard_npc.home
		if(outpost_inside_pocket(from, door_turf, desk))
			return TRUE
	return FALSE

/**
 * A holding cell's door. A bump, a click or an ID never opens it: its cell does (build_cells()), to bring a prisoner
 * in, let an officer out, on release and for a medic. Otherwise it is hacked like any airlock (owner decision 47): a
 * screwdriver opens its panel, its wires cut and pulse as usual (bolts, power, the door motor and the rest), an
 * airlock authentication override card opens it, and a crowbar pries it once its power is out. With the power
 * on, a crowbar or jaws force it the slow way (force_door()). Opened on a held prisoner by any of these, it is the
 * hacker's jailbreak, as forcing it is. A hacked door mends itself after OUTPOST_CHECKPOINT_EMAG_TIME, once nobody
 * stands in the doorway: panel shut, wires whole, power, lights and bolts back.
 */
/obj/machinery/door/airlock/outpost/glass/police_cell
	desc = "A cell door with a view."
	autoclose = FALSE
	// Wired like a ship's security door: no plating over the wires, and the open wire needs the ID wire cut first
	security_level = 0 // AIRLOCK_SECURITY_NONE (airlock.dm undefines it)
	req_access = list(ACCESS_BRIG)
	// Nobody plans a route through a cell: it is a dead end, and an open door must not draw anyone in
	can_astar_pass = CANASTARPASS_ALWAYS_PROC
	/// The cell this door shuts, set by build_cells()
	var/datum/outpost_police_cell/holding_cell
	/// Permission for the next open() call only
	var/cell_open_permitted = FALSE
	/// Set while an override card swings it open
	var/hack_opening = FALSE
	/// Who last worked its panel, wires or lock (the jailbreak is theirs)
	var/datum/weakref/last_hacker
	/// What they last worked it with, so the arrest takes the hacking tool as evidence
	var/datum/weakref/last_hack_tool
	/// ...and when
	var/last_hack_at = 0
	/// A mend is on its way
	var/mend_pending = FALSE
	/// Set while it mends, so putting its wires back is not taken for more hacking
	var/mending = FALSE
	/// Banging on the glass makes a noise no more often than this
	COOLDOWN_DECLARE(knock_cooldown)

/obj/machinery/door/airlock/outpost/glass/police_cell/Destroy()
	if(holding_cell?.door == src)
		holding_cell.door = null
	holding_cell = null
	last_hacker = null
	last_hack_tool = null
	return ..()

/obj/machinery/door/airlock/outpost/glass/police_cell/get_wires()
	return new /datum/wires/airlock/security/outpost_cell(src)

/obj/machinery/door/airlock/outpost/glass/police_cell/open(forced = DEFAULT_DOOR_CHECKS)
	if(!density)
		return TRUE
	var/by_cell = cell_open_permitted
	cell_open_permitted = FALSE
	// A plain request (a bump, a click, a remote) gets nowhere; the cell's say-so, a pulsed wire, a pry with the power
	// out, an override card does
	if(!by_cell && forced == DEFAULT_DOOR_CHECKS && !hack_opening)
		return FALSE
	// Who did it and with what, taken now: the door swings open over a second or two
	var/mob/living/culprit = by_cell ? null : hack_culprit()
	var/obj/item/tool = culprit ? hack_tool() : null
	. = ..()
	if(. && !by_cell && !QDELETED(src))
		holding_cell?.door_hacked_open(culprit, tool)

// Once an opening is allowed above, power, ID and wires do not stop it
/obj/machinery/door/airlock/outpost/glass/police_cell/try_to_force_door_open(force_type = DEFAULT_DOOR_CHECKS)
	return ..(BYPASS_DOOR_CHECKS)

// Abuse MF2: nothing shuts an empty cell's door on a body or a bystander, even a pulsed wire while the station is idle
/obj/machinery/door/airlock/outpost/glass/police_cell/close(forced = DEFAULT_DOOR_CHECKS, force_crush = FALSE)
	if(holding_cell && !length(holding_cell.prisoners) && holding_cell.stray_inside())
		holding_cell.schedule_close_check(5 SECONDS)
		return FALSE
	return ..()

/// `who` worked on the door: they answer for what it does next, and a mend is coming
/obj/machinery/door/airlock/outpost/glass/police_cell/proc/note_hack(mob/living/who, obj/item/tool = null)
	if(mending || QDELETED(src))
		return
	if(isliving(who))
		var/same_hacker = (last_hacker?.resolve() == who) && last_hack_at && (world.time - last_hack_at <= 10 SECONDS)
		last_hacker = WEAKREF(who)
		last_hack_at = world.time
		if(isitem(tool) && !QDELETED(tool))
			last_hack_tool = WEAKREF(tool)
		else if(!same_hacker || !last_hack_tool?.resolve())
			last_hack_tool = null
	if(mend_pending)
		return
	mend_pending = TRUE
	addtimer(CALLBACK(src, PROC_REF(mend_hack)), OUTPOST_CHECKPOINT_EMAG_TIME, TIMER_DELETE_ME)

/// Whoever worked the door in the last few seconds, or null
/obj/machinery/door/airlock/outpost/glass/police_cell/proc/hack_culprit()
	if(!last_hack_at || world.time - last_hack_at > 10 SECONDS)
		return null
	var/mob/living/culprit = last_hacker?.resolve()
	return isliving(culprit) ? culprit : null

/// What they last worked the door with in the last few seconds, or null
/obj/machinery/door/airlock/outpost/glass/police_cell/proc/hack_tool()
	if(!last_hack_at || world.time - last_hack_at > 10 SECONDS)
		return null
	var/obj/item/tool = last_hack_tool?.resolve()
	return isitem(tool) && !QDELETED(tool) ? tool : null

/// Whether anyone (standing or lying) or anything bulky is in the doorway
/obj/machinery/door/airlock/outpost/glass/police_cell/proc/doorway_occupied()
	for(var/atom/movable/thing in get_turf(src))
		if(thing == src || iseffect(thing))
			continue
		if(isliving(thing) || thing.density)
			return TRUE
	return FALSE

/// The hack wears off once nobody stands in the doorway: panel shut, wires whole, power, lights and bolts back
/obj/machinery/door/airlock/outpost/glass/police_cell/proc/mend_hack()
	if(QDELETED(src))
		return
	if(!still_hacked())
		mend_pending = FALSE
		return
	if(operating || doorway_occupied())
		addtimer(CALLBACK(src, PROC_REF(mend_hack)), 3 SECONDS, TIMER_UNIQUE | TIMER_DELETE_ME)
		return
	mend_pending = FALSE
	mending = TRUE
	obj_flags &= ~EMAGGED
	panel_open = FALSE
	if(wires && length(wires.assemblies))
		var/turf/drop_at = holding_cell?.outside_turf || get_turf(src)
		for(var/color in wires.assemblies.Copy())
			var/obj/item/assembly/attached = wires.detach_assembly(color)
			if(attached && drop_at)
				attached.forceMove(drop_at)
	wires?.repair()
	security_level = initial(security_level)
	set_electrified(MACHINE_NOT_ELECTRIFIED)
	regainMainPower()
	regainBackupPower()
	lights = TRUE
	safe = TRUE
	normalspeed = TRUE
	autoclose = FALSE
	emergency = FALSE
	aiControlDisabled = initial(aiControlDisabled)
	unbolt()
	mending = FALSE
	last_hacker = null
	last_hack_tool = null
	last_hack_at = 0
	do_sparks(2, TRUE, src)
	visible_message(span_notice("[src] sparks, and its lights come back on."))
	update_appearance()
	holding_cell?.schedule_close_check(1 SECONDS)

// The outpost doors' emag mend (outpost_security.dm) is this door's whole mend
/obj/machinery/door/airlock/outpost/glass/police_cell/mend_emag()
	if(QDELETED(src) || !(obj_flags & EMAGGED))
		return
	mend_hack()

/// Whether anything a hack leaves is still wrong with it
/obj/machinery/door/airlock/outpost/glass/police_cell/proc/still_hacked()
	return panel_open || (obj_flags & EMAGGED) || length(wires?.cut_wires) || length(wires?.assemblies) || locked || !hasPower() || isElectrified() || !lights || !safe || !normalspeed || emergency || autoclose || aiControlDisabled != initial(aiControlDisabled) || security_level != initial(security_level)

// Outpost property: hacked, never taken apart or plated over
/obj/machinery/door/airlock/outpost/glass/police_cell/should_try_removing_electronics()
	return FALSE

/obj/machinery/door/airlock/outpost/glass/police_cell/try_reinforce(mob/user, obj/item/stack/sheet/material, amt_required, new_security_level)
	return FALSE

/// The station's door control lifts the bolts and clears hazards for an officer at work (booking, release, a medic): see open_door()
/obj/machinery/door/airlock/outpost/glass/police_cell/proc/cell_take_over()
	if(locked)
		unbolt()
	safe = TRUE
	autoclose = FALSE
	if(isElectrified())
		set_electrified(MACHINE_NOT_ELECTRIFIED)

/obj/machinery/door/airlock/outpost/glass/police_cell/screwdriver_act(mob/living/user, obj/item/tool)
	. = ..()
	note_hack(user, tool)

/obj/machinery/door/airlock/outpost/glass/police_cell/emag_act(mob/user, obj/item/card/emag/emag_card)
	. = ..()
	if(.)
		note_hack(user, emag_card)

/obj/machinery/door/airlock/outpost/glass/police_cell/finish_emag_act()
	hack_opening = TRUE
	. = ..()
	hack_opening = FALSE

// A pry the normal way once its power is out; with the power on only the slow force works (crowbar_act())
/obj/machinery/door/airlock/outpost/glass/police_cell/try_to_crowbar(obj/item/tool, mob/living/user, forced = FALSE)
	if(!density || hasPower() || isnull(tool))
		return
	note_hack(user, tool)
	return ..()

// Its screwdriver and wirecutters get past outpost property (see /datum/element/outpost_property)
/obj/machinery/door/airlock/outpost/glass/police_cell/outpost_hackable(obj/item/tool)
	return tool?.tool_behaviour == TOOL_SCREWDRIVER || tool?.tool_behaviour == TOOL_WIRECUTTER

/// A cell door's wires: whoever cuts, pulses or wires an assembly onto one is noted as working the door
/datum/wires/airlock/security/outpost_cell
	/// Assembly weakref -> weakref of the mob who attached it, so a remote pulse still knows its hacker
	var/list/assembly_installers

/datum/wires/airlock/security/outpost_cell/Destroy()
	assembly_installers = null
	return ..()

/datum/wires/airlock/security/outpost_cell/cut(wire, mob/living/source)
	var/obj/machinery/door/airlock/outpost/glass/police_cell/door = holder
	if(istype(door))
		door.note_hack(source, isliving(source) ? source.get_active_held_item() : null)
	return ..()

// A cell door never auto-closes: its cell drives when it shuts, and mending WIRE_TIMING must not turn autoclose on
/datum/wires/airlock/security/outpost_cell/on_cut(wire, mend = FALSE, mob/living/source = null)
	if(wire == WIRE_TIMING)
		var/obj/machinery/door/airlock/door = holder
		if(istype(door))
			door.autoclose = FALSE
		return
	return ..()

/datum/wires/airlock/security/outpost_cell/pulse(wire, mob/living/user, force = FALSE)
	var/obj/machinery/door/airlock/outpost/glass/police_cell/door = holder
	if(istype(door))
		door.note_hack(user, isliving(user) ? user.get_active_held_item() : null)
	return ..()

/datum/wires/airlock/security/outpost_cell/attach_assembly(color, obj/item/assembly/S)
	var/mob/living/holder_mob = isliving(S?.loc) ? S.loc : null
	. = ..()
	if(!.)
		return
	var/obj/machinery/door/airlock/outpost/glass/police_cell/door = holder
	var/mob/living/installer = isliving(usr) ? usr : (holder_mob || (istype(door) ? door.hack_culprit() : null))
	if(installer)
		LAZYSET(assembly_installers, WEAKREF(S), WEAKREF(installer))
	if(istype(door))
		door.note_hack(installer, S)

/datum/wires/airlock/security/outpost_cell/detach_assembly(color)
	. = ..()
	if(.)
		LAZYREMOVE(assembly_installers, WEAKREF(.))

/datum/wires/airlock/security/outpost_cell/pulse_assembly(obj/item/assembly/S)
	var/datum/weakref/installer_ref = S ? LAZYACCESS(assembly_installers, WEAKREF(S)) : null
	var/mob/living/installer = installer_ref?.resolve()
	var/obj/machinery/door/airlock/outpost/glass/police_cell/door = holder
	if(istype(door) && isliving(installer))
		door.note_hack(installer, S)
	return ..()

// Someone got into the doorway as it shut: it opens again for them, and its cell closes it once they have moved
/obj/machinery/door/airlock/outpost/glass/police_cell/CheckForMobs()
	if(!(locate(/mob/living) in get_turf(src)))
		return
	cell_open_permitted = TRUE
	open()

/obj/machinery/door/airlock/outpost/glass/police_cell/bumpopen(mob/user)
	return

/obj/machinery/door/airlock/outpost/glass/police_cell/try_to_activate_door(mob/living/user, access_bypass = FALSE)
	add_fingerprint(user)
	// Nothing opens; a hand on the shut door bangs on the glass, and an officer nearby tells them to stop
	if(density && isliving(user) && Adjacent(user) && COOLDOWN_FINISHED(src, knock_cooldown))
		COOLDOWN_START(src, knock_cooldown, CELL_KNOCK_GAP)
		user.visible_message(span_notice("[user] bangs on [src]."), span_notice("You bang on [src]."))
		playsound(src, 'sound/effects/glass/glassknock.ogg', 50, TRUE)
		holding_cell?.answer_knock(user)
	return TRUE // handled

// A dead end for every walker, open or shut
/obj/machinery/door/airlock/outpost/glass/police_cell/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	return FALSE

// Outpost property lets a crowbar through to this one door (see /datum/element/outpost_property)
/obj/machinery/door/airlock/outpost/glass/police_cell/outpost_forceable()
	return TRUE

/obj/machinery/door/airlock/outpost/glass/police_cell/crowbar_act(mob/living/user, obj/item/tool)
	if(!density)
		return ITEM_INTERACT_BLOCKING
	// The power out (its wires cut): a pry the normal way
	if(!hasPower() && !locked && !welded)
		return ..()
	if(!density || !holding_cell || holding_cell.forcing || !holding_cell.still_forceable())
		return ITEM_INTERACT_BLOCKING
	INVOKE_ASYNC(holding_cell, TYPE_PROC_REF(/datum/outpost_police_cell, force_door), user, tool)
	return ITEM_INTERACT_SUCCESS

#undef CELL_BOOKING_STALE
#undef CELL_OFFICER_PASS
#undef CELL_UNCUFF_TIME
#undef CELL_UNCUFF_WAIT
#undef CELL_KNOCK_GAP
#undef CELL_KNOCK_HEARD
