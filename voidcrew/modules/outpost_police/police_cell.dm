/**
 * # Outpost police: cells
 *
 * Owner: P6. The holding cells (/datum/outpost_police_cell), booking, processing, jail terms, bail and
 * release, and the police doors and cell doors (types in police_core.dm). Spec 6.2-6.4 and the cell half of 7.
 *
 * A cell is one /datum/outpost_police_cell per cell_id, built from the landmarks, door and sign the map
 * placed (build_cells()). Its door opens only for the cell itself: a bump, a click, an ID, a wire or a pry
 * never gets it open, and an emag does nothing. The cell opens it to bring a prisoner in, to let an officer
 * out, on release, for a medic, and for a minute-long forced door (a crowbar or jaws, from either side while
 * somebody is held or it is shut on someone it does not hold). A cell holding nobody never shuts on a body or a
 * person (abuse MF2).
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
	return !QDELETED(src) && !QDELETED(body) && (prisoner in prisoners)

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
		if(body_of(held) == body)
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
/datum/outpost_police_cell/proc/can_walk_back(mob/living/body)
	if(body.incapacitated || HAS_TRAIT(body, TRAIT_RESTRAINED) || body.pulledby || body.buckled || body.throwing)
		return FALSE
	// Asleep at the keyboard (a player's mind and no client): the clock waits for them
	if(body.mind?.key && !body.client)
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

/// Opens the door and keeps it open for `duration` (waits for it to be open if `wait`). TRUE if it is, or will be.
/datum/outpost_police_cell/proc/open_door(duration, wait = FALSE)
	if(QDELETED(door))
		return FALSE
	open_until = max(open_until, world.time + duration)
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
	log_game("OUTPOST POLICE: [key_name(user)] forced [door] at [AREACOORD(door)].")
	var/held = length(prisoners)
	open_door(OUTPOST_POLICE_CELL_OPEN)
	if(held)
		police?.report_crime(user, OUTPOST_CRIME_JAILBREAK, null, tool)
	return TRUE

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
			else if(!can_walk_back(body))
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
	if(mover && mover != body)
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
		if(mover && mover != body && mover.mind)
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

/// One physical cardinal `Move()` step for booking, keeping hold of `keep_pulled` when swapping places
/datum/outpost_police_cell/proc/cell_walk_step(mob/living/mover, turf/next_turf, mob/living/keep_pulled = null)
	if(QDELETED(mover) || mover.stat == DEAD || !next_turf)
		return FALSE
	if(get_turf(mover) == next_turf)
		return TRUE
	mover.set_combat_mode(FALSE)
	var/saved_grab = mover.grab_state
	mover.Move(next_turf, get_dir(mover, next_turf))
	if(keep_pulled && !QDELETED(keep_pulled) && mover.Adjacent(keep_pulled) && mover.pulling != keep_pulled)
		mover.start_pulling(keep_pulled, supress_message = TRUE)
		mover.grab_state = saved_grab
	var/pause = round(0.1 SECONDS * GLOB.outpost_police_property_time_scale)
	if(pause > 0)
		sleep(pause)
	return !QDELETED(mover) && get_turf(mover) == next_turf

/// Walks `officer` physically out of the cell through `door` onto `outside_turf`
/datum/outpost_police_cell/proc/cell_walk_out(mob/living/officer)
	if(QDELETED(officer) || officer.stat == DEAD || QDELETED(door) || !outside_turf)
		return FALSE
	var/turf/door_turf = get_turf(door)
	if(!door_turf || !((get_turf(officer) in tiles) || get_turf(officer) == door_turf))
		return get_turf(officer) == outside_turf
	if(door.density && !open_door(CELL_OFFICER_PASS, TRUE))
		return FALSE
	for(var/step_num in 1 to (length(tiles) + 2))
		if(QDELETED(officer) || officer.stat == DEAD)
			return FALSE
		var/turf/here = get_turf(officer)
		if(here == outside_turf)
			return TRUE
		if(here == door_turf)
			cell_walk_step(officer, outside_turf)
			break
		if(get_dist(here, door_turf) == 1)
			cell_walk_step(officer, door_turf)
			continue
		var/turf/closer
		var/best_dist = get_dist(here, door_turf)
		for(var/dir in GLOB.cardinals)
			var/turf/candidate = get_step(here, dir)
			if((candidate in tiles) && !candidate.is_blocked_turf(exclude_mobs = TRUE) && get_dist(candidate, door_turf) < best_dist)
				closer = candidate
				best_dist = get_dist(candidate, door_turf)
		if(!closer || !cell_walk_step(officer, closer))
			break
	if(!QDELETED(officer) && officer.stat != DEAD && get_turf(officer) == door_turf)
		cell_walk_step(officer, outside_turf)
	return !QDELETED(officer) && get_turf(officer) == outside_turf

/**
 * Brings `suspect` in and books them: physically walks and pulls them through the cell door, shuts it, tries the
 * fine, then processing (paid) or the jail strip (not paid), takes the cuffs off, and walks the officer back out.
 * At three stars and up there is no fine: the jail strip and a sentence that grows with the stars (owner decision 37).
 * Sleeps. TRUE once the suspect is held; FALSE (nothing taken) if they could not be.
 */
/datum/outpost_police_cell/proc/book_in(mob/living/carbon/suspect, mob/living/officer, datum/outpost_warrant/warrant)
	var/turf/door_turf = get_turf(door)
	if(!door_turf || !outside_turf || officer.z != door_turf.z || suspect.z != door_turf.z)
		return FALSE
	if(get_dist(officer, door_turf) > 2 || get_dist(suspect, door_turf) > 2)
		return FALSE
	var/turf/entry_tile
	for(var/dir in GLOB.cardinals)
		var/turf/candidate = get_step(door_turf, dir)
		if((candidate in tiles) && !candidate.is_blocked_turf(exclude_mobs = TRUE))
			entry_tile = candidate
			break
	if(!entry_tile)
		return FALSE
	var/datum/mind/prisoner = suspect.mind
	var/full_stars = clamp(police.get_stars(prisoner), 1, 5)
	var/no_fine = full_stars >= 3
	var/stars = clamp(full_stars, 1, 2)
	if(suspect.buckled)
		suspect.buckled.unbuckle_mob(suspect, TRUE)
	officer.set_combat_mode(FALSE)
	if(!officer.Adjacent(suspect))
		var/turf/towards = get_step_towards(officer, suspect)
		if(towards)
			cell_walk_step(officer, towards)
	if(officer.pulling != suspect && officer.Adjacent(suspect))
		officer.start_pulling(suspect, supress_message = TRUE)
	if(officer.pulling != suspect && !(get_turf(suspect) in tiles))
		return FALSE
	if(!open_door(OUTPOST_POLICE_CELL_OPEN, TRUE))
		return FALSE
	// Walk the officer and pulled suspect physically through the doorway into the cell
	if(!(get_turf(officer) in tiles) && get_turf(officer) != door_turf && get_turf(officer) != outside_turf)
		cell_walk_step(officer, outside_turf, suspect)
	if(get_turf(officer) == outside_turf && !(get_turf(suspect) in tiles))
		cell_walk_step(officer, door_turf, suspect)
	if(get_turf(officer) == door_turf)
		cell_walk_step(officer, entry_tile, suspect)
	if(!(get_turf(suspect) in tiles) && get_turf(officer) == entry_tile)
		for(var/pass in 1 to 2)
			for(var/dir in GLOB.cardinals)
				var/turf/deeper = get_step(entry_tile, dir)
				if(!(deeper in tiles) || deeper.is_blocked_turf(exclude_mobs = (pass == 2)))
					continue
				if(cell_walk_step(officer, deeper, suspect) && (get_turf(suspect) in tiles))
					break
			if(get_turf(suspect) in tiles)
				break
		if(!(get_turf(suspect) in tiles) && get_turf(officer) == entry_tile && get_turf(suspect) == door_turf)
			cell_walk_step(officer, door_turf, suspect)
	if(QDELETED(suspect) || suspect.stat == DEAD || !(get_turf(suspect) in tiles))
		if(!QDELETED(officer) && officer.pulling == suspect)
			officer.stop_pulling()
		cell_walk_out(officer)
		shut_door(TRUE)
		return FALSE
	// Until the booking is over they are held but not on a clock
	admit(suspect, world.time + OUTPOST_POLICE_HOLDS[stars])
	booking[prisoner] = world.time
	// The booking line is the arresting officer's (police_arrest.dm act_book())
	if(get_turf(officer) != door_turf)
		shut_door(TRUE)
	if(!holds(prisoner, suspect))
		if(!QDELETED(officer) && officer.pulling == suspect)
			officer.stop_pulling()
		cell_walk_out(officer)
		shut_door(TRUE)
		return FALSE
	// The fine, with the door shut on the two of them
	var/paid = no_fine ? FALSE : police.charge_fine(warrant)
	if(paid)
		police.say_fine_paid(officer)
	else
		// Gear into a locker before the cuffs come off (abuse M25)
		police.store_property(suspect, officer)
		if(!holds(prisoner, suspect))
			if(!QDELETED(officer) && officer.pulling == suspect)
				officer.stop_pulling()
			cell_walk_out(officer)
			shut_door(TRUE)
			return FALSE
	// Step to the doorway side before taking the cuffs off so an uncuffed prisoner cannot block the exit in a 1x2 cell
	if(!QDELETED(officer) && officer.stat != DEAD && (get_turf(officer) in tiles) && get_turf(officer) != entry_tile && officer.Adjacent(entry_tile))
		if(officer.pulling != suspect && officer.Adjacent(suspect))
			officer.start_pulling(suspect, supress_message = TRUE)
		cell_walk_step(officer, entry_tile, suspect)
	if(!QDELETED(officer) && officer.pulling == suspect)
		officer.stop_pulling()
	police.cell_remove_cuffs(suspect, officer)
	if(!holds(prisoner, suspect))
		cell_walk_out(officer)
		shut_door(TRUE)
		return FALSE
	// The officer walks out through the cell door
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

/// The usable cell with the fewest prisoners, the one nearest `near` of equals. Null if there is none.
/datum/outpost_police/proc/cell_best(atom/near)
	var/datum/outpost_police_cell/best
	var/best_load
	var/best_distance
	for(var/datum/outpost_police_cell/cell in cells)
		if(!cell.usable())
			continue
		var/load = length(cell.prisoners)
		var/distance = near ? get_dist(near, cell.door) : 0
		if(isnull(best) || load < best_load || (load == best_load && distance < best_distance))
			best = cell
			best_load = load
			best_distance = distance
	return best

/// The lobby tile outside the door of the cell the next booking uses, or null
/datum/outpost_police/proc/cell_door_turf()
	return cell_best()?.outside_turf

/**
 * Whether `who` is in police custody: from an arrest's cuffs (or grip) going on to release from a cell. By the police's
 * own state, not the cuffs alone: someone in police cuffs nobody is arresting any more (carried off and brought back,
 * a case that fell through) is an ordinary suspect again, to be chased and taken back in (review-1 S5).
 */
/datum/outpost_police/proc/in_custody(mob/living/who)
	if(!who?.mind)
		return FALSE
	var/datum/outpost_police_case/case = cases[who.mind]
	if(case && !QDELETED(case) && case.cuffed && case.get_suspect() == who)
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
		if(do_after(officer, CELL_UNCUFF_TIME, prisoner, IGNORE_TARGET_LOC_CHANGE | IGNORE_HELD_ITEM, extra_checks = CALLBACK(src, PROC_REF(property_strip_check), prisoner, officer)))
			prisoner.uncuff()
			return

/// Someone bangs on the door of `cell`: the nearest officer who can see the door tells them to knock it off
/datum/outpost_police_cell/proc/answer_knock(mob/living/knocker)
	var/turf/door_turf = get_turf(door)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police?.life_nearest_officer(door_turf, CELL_KNOCK_HEARD)
	if(!officer || officer.client || !(door_turf in view(CELL_KNOCK_HEARD, officer)))
		return null
	officer.face_atom(door)
	return officer.police_say(POLICE_LINE_KNOCK)

/// `officer` tells the prisoner their fine went through: the receipt, said in the cell
/datum/outpost_police/proc/say_fine_paid(mob/living/officer)
	if(!istype(officer, /mob/living/carbon/human/npc/ambient_npc/outpost/police))
		return
	INVOKE_ASYNC(officer, TYPE_PROC_REF(/mob/living/carbon/human/npc/ambient_npc/outpost/police, police_say), POLICE_LINE_FINE_PAID)

/// The sergeant says `line` (a POLICE_LINE_* context) at the station; with none alive, whoever is on the radio
/datum/outpost_police/proc/cell_station_say(line)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(officer.stat != DEAD && officer.unit_kind == POLICE_UNIT_SERGEANT)
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

// Abuse SF5: from the lift side anyone may leave, so nobody who followed an officer in is shut in the lift closet.
// The lift side is the one nearer a police lift than the door itself. Coming in still takes an officer's ID.
/obj/machinery/door/airlock/outpost/police/unrestricted_side(mob/opener)
	. = ..()
	if(. || !opener)
		return
	var/obj/structure/overmap/trader_outpost/home = outpost
	var/datum/outpost_police/police = istype(home) ? home.police : null
	var/turf/door_turf = get_turf(src)
	var/turf/from = get_turf(opener)
	if(!police || !door_turf || !from || from == door_turf)
		return
	var/from_distance = INFINITY
	var/door_distance = INFINITY
	for(var/turf/lift as anything in police.lift_turfs)
		if(lift.z != door_turf.z)
			continue
		from_distance = min(from_distance, get_dist(from, lift))
		door_distance = min(door_distance, get_dist(door_turf, lift))
	return from_distance < door_distance

/**
 * A holding cell's door. Nothing opens it but its cell (police_cell.dm, build_cells()): a bump, a click, an
 * ID, a wire, a spell or a pry gets a refusal, and an emag does nothing (abuse M1). A crowbar or jaws work on
 * it only while somebody is held or shut in, as a forced door (force_door()).
 */
/obj/machinery/door/airlock/outpost/glass/police_cell
	desc = "A cell door with a view."
	autoclose = FALSE
	// Nobody plans a route through a cell: it is a dead end, and an open door must not draw anyone in
	can_astar_pass = CANASTARPASS_ALWAYS_PROC
	/// The cell this door shuts, set by build_cells()
	var/datum/outpost_police_cell/holding_cell
	/// Permission for the next open() call only
	var/cell_open_permitted = FALSE
	/// Banging on the glass makes a noise no more often than this
	COOLDOWN_DECLARE(knock_cooldown)

/obj/machinery/door/airlock/outpost/glass/police_cell/Destroy()
	if(holding_cell?.door == src)
		holding_cell.door = null
	holding_cell = null
	return ..()

/obj/machinery/door/airlock/outpost/glass/police_cell/open(forced = DEFAULT_DOOR_CHECKS)
	if(!density)
		return TRUE
	if(!cell_open_permitted)
		return FALSE
	cell_open_permitted = FALSE
	return ..()

// The cell's permission is the only check an opening needs: no power, no ID, no wires
/obj/machinery/door/airlock/outpost/glass/police_cell/try_to_force_door_open(force_type = DEFAULT_DOOR_CHECKS)
	return ..(BYPASS_DOOR_CHECKS)

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

/obj/machinery/door/airlock/outpost/glass/police_cell/try_to_crowbar(obj/item/tool, mob/living/user, forced = FALSE)
	return

// Not an emag target (abuse M1)
/obj/machinery/door/airlock/outpost/glass/police_cell/emag_act(mob/user, obj/item/card/emag/emag_card)
	return FALSE

// A dead end for every walker, open or shut
/obj/machinery/door/airlock/outpost/glass/police_cell/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	return FALSE

// Outpost property lets a crowbar through to this one door (see /datum/element/outpost_property)
/obj/machinery/door/airlock/outpost/glass/police_cell/outpost_forceable()
	return TRUE

/obj/machinery/door/airlock/outpost/glass/police_cell/crowbar_act(mob/living/user, obj/item/tool)
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
