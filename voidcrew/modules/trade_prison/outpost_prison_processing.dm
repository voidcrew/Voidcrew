/**
 * # Processing
 *
 * The small room with two doors between a lockup's front room and its yard. Everyone who joins or leaves the cell
 * block goes through it, one at a time: an arriving prisoner is put inside with both doors shut, the inner door
 * opens and they walk out to their cell; someone leaving walks in, the door shuts behind them and they are gone.
 * Its walls are solid, so nobody sees what happens inside with both doors shut.
 *
 * The doors are airlocks (outpost_prison_host.dm) and are worked only through the airlock's own open() and
 * close(): a bolted, welded or unpowered one does not move, and Processing waits for it. The two are never open
 * together, nothing starts while anyone is in the room, and nobody is taken away while a player stands in it.
 *
 * One job at a time (processing_state): idle, letting an arrival in, or taking someone out. processing_tick()
 * moves the job on; the walking is the prisoner's own AI (the planning subtree below), so with nobody at the
 * outpost to see it nothing walks: an arrival is then put straight in their cell (admit_next()), and someone
 * leaving is gone from where they stand once no client has been able to see them for
 * OUTPOST_PRISON_LEAVE_UNSEEN. A wing with no Processing room mapped (the unit tests' wing) does the same at once.
 */

/datum/outpost_prison
	/// OUTPOST_PROCESSING_IDLE, _IN, _OUT or _CROSS
	var/processing_state = OUTPOST_PROCESSING_IDLE
	/// Who the room is working for
	var/datum/weakref/processing_who_ref
	/// Seconds the current job has run
	var/processing_seconds = 0
	/// The door the one leaving comes in by: the inner from the cell block, the outer from anywhere else
	var/datum/weakref/processing_entry_ref
	/// Everyone waiting to leave, first come first out
	var/list/mob/living/processing_leavers = list()
	/// The room's doors, found once
	var/datum/weakref/processing_inner_ref
	var/datum/weakref/processing_outer_ref

/mob/living/carbon/human/npc/outpost_prisoner
	/// Where Processing has them walking: out to their cell as they arrive, into the room as they leave
	var/turf/processing_goal
	/// Seconds they have been leaving with no client able to see them
	var/leave_unseen = 0

// ===== THE ROOM =====

/// Who Processing is working for now, or null
/datum/outpost_prison/proc/processing_who()
	return processing_who_ref?.resolve()

/// Processing's inner (yard side) or outer (front room side) door, or null
/datum/outpost_prison/proc/processing_door(inner = TRUE)
	var/datum/weakref/known = inner ? processing_inner_ref : processing_outer_ref
	var/obj/machinery/door/airlock/security/prison_staff/processing/door = known?.resolve()
	if(!QDELETED(door))
		return door
	var/door_type = inner ? /obj/machinery/door/airlock/security/prison_staff/processing/inner : /obj/machinery/door/airlock/security/prison_staff/processing/outer
	for(var/turf/tile as anything in processing_turfs)
		for(var/direction in GLOB.cardinals)
			door = locate(door_type) in get_step(tile, direction)
			if(door)
				if(inner)
					processing_inner_ref = WEAKREF(door)
				else
					processing_outer_ref = WEAKREF(door)
				return door
	return null

/// Whether the wing has a Processing room: its tiles and both doors
/datum/outpost_prison/proc/has_processing()
	return length(processing_turfs) && !!processing_door(TRUE) && !!processing_door(FALSE)

/// Whether a door is shut and not moving
/datum/outpost_prison/proc/processing_shut(obj/machinery/door/airlock/door)
	return !!door && door.density && !door.operating

/// Whether something is in the room
/datum/outpost_prison/proc/in_processing(atom/thing)
	var/turf/spot = get_turf(thing)
	return !!spot && (spot in processing_turfs)

/// Everyone in the room, including anyone shut in a crate, locker or mech
/datum/outpost_prison/proc/processing_occupants()
	. = list()
	for(var/turf/tile as anything in processing_turfs)
		. |= tile.get_all_contents_type(/mob/living)

/// Whether a player is in the room: nobody is taken away around one
/datum/outpost_prison/proc/processing_player_inside()
	for(var/mob/living/person as anything in processing_occupants())
		if(person.client || person.mind)
			return TRUE
	return FALSE

/// Whether any living outsider (not staff, not a cleanbot, not a wing prisoner or inmate) is in the room
/datum/outpost_prison/proc/processing_outsider_inside(mob/living/except = null)
	for(var/mob/living/person as anything in processing_occupants())
		if(person == except || QDELETED(person) || person.stat == DEAD || istype(person, /mob/living/basic/bot/cleanbot))
			continue
		if(is_staff(person) || is_inmate(person) || (person in prisoners))
			continue
		return TRUE
	return FALSE

/// Whether any living held player inmate is inside Processing
/datum/outpost_prison/proc/processing_inmate_inside(mob/living/except = null)
	for(var/mob/living/person as anything in processing_occupants())
		if(person == except || QDELETED(person) || person.stat == DEAD)
			continue
		if(is_inmate(person))
			return TRUE
	return FALSE

/// Whether a live AI cleanbot is in the room with no other live non-cleanbot occupant
/datum/outpost_prison/proc/processing_cleanbot_only()
	var/found_bot = FALSE
	for(var/mob/living/person as anything in processing_occupants())
		if(QDELETED(person) || person.stat == DEAD)
			continue
		if(istype(person, /mob/living/basic/bot/cleanbot) && isnull(person.client) && isnull(person.mind))
			found_bot = TRUE
			continue
		return FALSE
	return found_bot

/// Whether `leaver` is already inside Processing with both doors shut and no other live occupant or player
/datum/outpost_prison/proc/processing_leaver_ready_inside(mob/living/leaver)
	if(!in_processing(leaver) || processing_player_inside())
		return FALSE
	if(!processing_shut(processing_door(TRUE)) || !processing_shut(processing_door(FALSE)))
		return FALSE
	for(var/mob/living/person as anything in processing_occupants())
		if(person != leaver && !QDELETED(person) && person.stat != DEAD)
			return FALSE
	return TRUE

/// Whether the room can start on someone: it exists, it is idle, both doors are shut and nobody is inside
/datum/outpost_prison/proc/processing_free()
	if(processing_state != OUTPOST_PROCESSING_IDLE || !has_processing())
		return FALSE
	if(!processing_shut(processing_door(TRUE)) || !processing_shut(processing_door(FALSE)))
		return FALSE
	return !length(processing_occupants())

/// A passable tile of the room nobody stands on, or null
/datum/outpost_prison/proc/processing_spot(mob/living/except)
	for(var/turf/tile as anything in processing_turfs)
		if(tile.is_blocked_turf(TRUE))
			continue
		var/taken = FALSE
		for(var/mob/living/person as anything in tile.get_all_contents_type(/mob/living))
			if(person != except)
				taken = TRUE
				break
		if(!taken)
			return tile
	return null

/// Asks a door to open or shut the way anything asks an airlock to: it may refuse (bolts, a weld, no power), and a breached one stays open until it mends
/datum/outpost_prison/proc/processing_work_door(obj/machinery/door/airlock/door, open)
	if(QDELETED(door) || door.operating || door.density != !!open)
		return
	var/obj/machinery/door/airlock/security/prison_staff/staff_door = door
	if(!open && istype(staff_door) && staff_door.lockup_breached())
		return
	if(open)
		INVOKE_ASYNC(door, TYPE_PROC_REF(/obj/machinery/door, open))
	else
		INVOKE_ASYNC(door, TYPE_PROC_REF(/obj/machinery/door, close))

/// Whether any player is close enough, with a clear line, to see `thing`
/datum/outpost_prison/proc/seen_by_client(atom/thing)
	var/turf/spot = get_turf(thing)
	if(!spot || !islist(SSmobs.clients_by_zlevel) || spot.z > length(SSmobs.clients_by_zlevel))
		return FALSE
	for(var/mob/viewer in SSmobs.clients_by_zlevel[spot.z])
		var/turf/viewer_turf = get_turf(viewer)
		if(viewer_turf && get_dist(viewer_turf, spot) <= OUTPOST_PRISON_SEEN_RANGE && can_see(viewer_turf, spot, OUTPOST_PRISON_SEEN_RANGE))
			return TRUE
	return FALSE

// ===== IN AND OUT =====

/**
 * Starts an arrival: `who` is put in the room (if they are not standing in it already) with both doors shut, and
 * from there processing_tick() opens the inner door and sees them out into the yard. Only when the room is free
 * (processing_free()). Returns TRUE if they are inside and the room is theirs.
 */
/datum/outpost_prison/proc/processing_send_in(mob/living/who)
	if(QDELETED(who) || !isliving(who))
		return FALSE
	if(processing_state != OUTPOST_PROCESSING_IDLE || !has_processing())
		return FALSE
	if(!processing_shut(processing_door(TRUE)) || !processing_shut(processing_door(FALSE)))
		return FALSE
	for(var/mob/living/person as anything in processing_occupants())
		if(person != who)
			return FALSE
	if(!in_processing(who))
		who.forceMove(processing_spot(who) || processing_turfs[1])
	processing_state = OUTPOST_PROCESSING_IN
	processing_who_ref = WEAKREF(who)
	processing_entry_ref = null
	processing_seconds = 0
	return TRUE

/**
 * `who` is leaving the wing: they join the queue for the room, walk in when it is their turn, and are gone once
 * the door has shut behind them (processing_tick()). Returns TRUE once they are in the queue.
 */
/datum/outpost_prison/proc/processing_send_out(mob/living/who)
	if(QDELETED(who) || !isliving(who))
		return FALSE
	processing_leavers |= who
	return TRUE

/// Takes someone who has left out of the world. Only ever the wing's own NPC prisoners: never a body a player is or was in.
/datum/outpost_prison/proc/processing_remove(mob/living/who)
	processing_leavers -= who
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = who
	if(!istype(prisoner) || QDELETED(prisoner) || prisoner.npc_ever_played())
		return FALSE
	prisoner.processing_goal = null
	qdel(prisoner)
	return TRUE

/// The job is over: the room is idle again, and the idle tick shuts whatever is open
/datum/outpost_prison/proc/processing_done()
	processing_state = OUTPOST_PROCESSING_IDLE
	processing_who_ref = null
	processing_entry_ref = null
	processing_seconds = 0

/// Advances Processing by `seconds`
/datum/outpost_prison/proc/processing_tick(seconds)
	processing_leavers_tick(seconds)
	if(corpse_doors_open() && has_processing())
		if(processing_state != OUTPOST_PROCESSING_BOOK)
			if(processing_state != OUTPOST_PROCESSING_IDLE)
				processing_done()
			processing_work_door(processing_door(TRUE), TRUE)
			processing_work_door(processing_door(FALSE), TRUE)
			return
	switch(processing_state)
		if(OUTPOST_PROCESSING_IN)
			processing_in_tick(seconds)
		if(OUTPOST_PROCESSING_OUT)
			processing_out_tick(seconds)
		if(OUTPOST_PROCESSING_CROSS)
			processing_cross_tick(seconds)
		if(OUTPOST_PROCESSING_RELEASE)
			processing_release_tick(seconds)
		if(OUTPOST_PROCESSING_BOOK)
			processing_seconds += seconds
			if(processing_seconds >= OUTPOST_PRISON_PROCESSING_WAIT)
				booking_mover_ref = null
				processing_done()
		else
			processing_idle_tick()

/// The open floor tile just outside `door` (in the yard for the inner door, in the front room for the outer), or null
/datum/outpost_prison/proc/processing_outside_turf(obj/machinery/door/airlock/door)
	var/turf/door_turf = get_turf(door)
	if(!door_turf)
		return null
	for(var/direction in GLOB.cardinals)
		var/turf/step_tile = get_step(door_turf, direction)
		if(!step_tile || !contains_turf(step_tile) || isclosedturf(step_tile) || (step_tile in processing_turfs))
			continue
		if((locate(/obj/machinery/door) in step_tile) || (locate(/obj/structure/table) in step_tile))
			continue
		return step_tile
	return null

/// One open step beyond `processing_outside_turf(door)` so a puller draws a towed person clear of `door`'s threshold
/datum/outpost_prison/proc/processing_clear_turf(obj/machinery/door/airlock/door)
	var/turf/door_turf = get_turf(door)
	var/turf/beyond = processing_outside_turf(door)
	if(!door_turf || !beyond)
		return null
	var/list/directions = list(get_dir(door_turf, beyond))
	for(var/direction in GLOB.cardinals)
		directions |= direction
	for(var/direction in directions)
		var/turf/step_tile = get_step(beyond, direction)
		if(!step_tile || step_tile == door_turf || !contains_turf(step_tile) || isclosedturf(step_tile) || (step_tile in processing_turfs))
			continue
		if((locate(/obj/machinery/door) in step_tile) || (locate(/obj/structure/table) in step_tile) || step_tile.is_blocked_turf(TRUE))
			continue
		return step_tile
	return null

/// Processing tile for `who` to step onto from `entry`: deep in the pocket when pulling someone so they clear `entry`
/datum/outpost_prison/proc/processing_cross_spot(mob/living/who, obj/machinery/door/airlock/entry)
	var/mob/living/towed = isliving(who?.pulling) ? who.pulling : null
	var/turf/entry_turf = get_turf(entry)
	if(towed && entry_turf)
		var/turf/fallback_deep
		for(var/turf/tile as anything in processing_turfs)
			if(tile.is_blocked_turf(TRUE) || (abs(tile.x - entry_turf.x) + abs(tile.y - entry_turf.y)) <= 1)
				continue
			fallback_deep ||= tile
			var/taken = FALSE
			for(var/mob/living/person as anything in tile.get_all_contents_type(/mob/living))
				if(person != who && person != towed && person.density)
					taken = TRUE
					break
			if(!taken)
				return tile
		if(fallback_deep)
			return fallback_deep
	return processing_spot(who) || processing_turfs[1]

/// Whether `who` is pulling someone who has not yet stepped through `entry` into Processing
/datum/outpost_prison/proc/processing_tow_entering(mob/living/who, obj/machinery/door/airlock/security/prison_staff/entry, into_yard)
	var/mob/living/towed = isliving(who?.pulling) ? who.pulling : null
	if(!towed || !entry || entry.lockup_breached())
		return FALSE
	var/turf/tow_turf = get_turf(towed)
	var/obj/machinery/door/airlock/exit_door = (entry == processing_door(TRUE)) ? processing_door(FALSE) : processing_door(TRUE)
	if(!tow_turf || in_processing(tow_turf) || tow_turf == get_turf(exit_door))
		return FALSE
	return !(into_yard ? processing_on_yard_side(tow_turf) : in_front_room(tow_turf))

/// Whether `who` is pulling someone still inside Processing or standing in `exit_door`
/datum/outpost_prison/proc/processing_tow_exiting(mob/living/who, obj/machinery/door/airlock/exit_door)
	var/mob/living/towed = isliving(who?.pulling) ? who.pulling : null
	if(!towed)
		return FALSE
	return in_processing(towed) || (!!exit_door && get_turf(towed) == get_turf(exit_door))

/// Whether `spot` lies on the yard/office side of Processing (inside the wing, past Processing and the front room)
/datum/outpost_prison/proc/processing_on_yard_side(turf/spot)
	if(!spot || !contains_turf(spot) || in_front_room(spot) || in_processing(spot))
		return FALSE
	return spot != get_turf(processing_door(TRUE)) && spot != get_turf(processing_door(FALSE))

/// Whether `door` is shut (or jammed open by a breach that Processing cannot close until it mends)
/datum/outpost_prison/proc/processing_cross_other_ready(obj/machinery/door/airlock/security/prison_staff/door)
	return processing_shut(door) || (istype(door) && door.lockup_breached() && !door.operating)

/**
 * Claims Processing to pass a conscious member of staff (`who`) from the front room into the yard (`into_yard` TRUE)
 * or back out into the front room (`into_yard` FALSE), one door at a time. Returns TRUE when Processing is working
 * for `who`.
 */
/datum/outpost_prison/proc/processing_request_cross(mob/living/who, into_yard)
	if(QDELETED(who) || !isliving(who) || who.stat != CONSCIOUS || !is_staff(who) || !has_processing())
		return FALSE
	var/turf/here = get_turf(who)
	if(!contains_turf(here))
		return FALSE
	var/obj/machinery/door/airlock/security/prison_staff/inner = processing_door(TRUE)
	var/obj/machinery/door/airlock/security/prison_staff/outer = processing_door(FALSE)
	var/obj/machinery/door/airlock/security/prison_staff/entry = into_yard ? outer : inner
	if(processing_state == OUTPOST_PROCESSING_CROSS && processing_who() == who)
		processing_entry_ref = WEAKREF(entry)
		return TRUE
	if(processing_state != OUTPOST_PROCESSING_IDLE)
		return FALSE
	if(!in_processing(here) && (!processing_cross_other_ready(inner) || !processing_cross_other_ready(outer)))
		return FALSE
	processing_state = OUTPOST_PROCESSING_CROSS
	processing_who_ref = WEAKREF(who)
	processing_entry_ref = WEAKREF(entry)
	processing_seconds = 0
	return TRUE

/// Passes a staff member through Processing: entry door opens with exit shut, shuts behind them, then exit opens
/datum/outpost_prison/proc/processing_cross_tick(seconds)
	var/mob/living/who = processing_who()
	var/turf/here = get_turf(who)
	if(QDELETED(who) || who.stat != CONSCIOUS || !is_staff(who) || !contains_turf(here) || !has_processing())
		processing_done()
		return
	var/obj/machinery/door/airlock/security/prison_staff/inner = processing_door(TRUE)
	var/obj/machinery/door/airlock/security/prison_staff/outer = processing_door(FALSE)
	var/obj/machinery/door/airlock/security/prison_staff/entry = processing_entry_ref?.resolve()
	if(entry != inner && entry != outer)
		entry = outer
	var/obj/machinery/door/airlock/security/prison_staff/exit_door = (entry == inner) ? outer : inner
	var/into_yard = (exit_door == inner)
	if(into_yard ? processing_on_yard_side(here) : in_front_room(here))
		if(processing_tow_exiting(who, exit_door))
			processing_seconds += seconds
			if(processing_seconds < OUTPOST_PRISON_PROCESSING_WAIT)
				if(processing_cross_other_ready(entry) && exit_door.density)
					processing_work_door(exit_door, TRUE)
				return
		processing_done()
		processing_idle_tick()
		return
	if((in_processing(here) && !processing_tow_entering(who, entry, into_yard)) || here == get_turf(exit_door))
		if(!processing_cross_other_ready(entry))
			processing_work_door(entry, FALSE)
			return
		if(exit_door.density)
			processing_work_door(exit_door, TRUE)
		return
	processing_seconds += seconds
	if(processing_seconds >= OUTPOST_PRISON_PROCESSING_WAIT)
		processing_done()
		return
	if(!processing_cross_other_ready(exit_door))
		processing_work_door(exit_door, FALSE)
		return
	if(entry.density)
		processing_work_door(entry, TRUE)

/**
 * Returns the next turf `who` (a staff member) should walk to in order to cross Processing (`into_yard` TRUE for
 * front room -> yard/office, FALSE for yard/office -> front room), `get_turf(who)` when they should stand at the
 * door waiting for Processing to cycle, or null when they are already on the destination side (or both doors are
 * breached open so normal pathing crosses directly).
 */
/datum/outpost_prison/proc/processing_step_through(mob/living/who, into_yard)
	var/turf/here = get_turf(who)
	if(QDELETED(who) || !isliving(who) || who.stat != CONSCIOUS || !is_staff(who) || !contains_turf(here) || !has_processing())
		return null
	var/obj/machinery/door/airlock/security/prison_staff/inner = processing_door(TRUE)
	var/obj/machinery/door/airlock/security/prison_staff/outer = processing_door(FALSE)
	var/obj/machinery/door/airlock/security/prison_staff/entry = into_yard ? outer : inner
	var/obj/machinery/door/airlock/security/prison_staff/exit_door = into_yard ? inner : outer
	var/turf/beyond = processing_outside_turf(exit_door)
	if(into_yard ? processing_on_yard_side(here) : in_front_room(here))
		if(processing_tow_exiting(who, exit_door))
			return (here == beyond) ? (processing_clear_turf(exit_door) || null) : null
		if(processing_state == OUTPOST_PROCESSING_CROSS && processing_who() == who)
			processing_done()
		return null
	if(!inner.density && inner.lockup_breached() && !outer.density && outer.lockup_breached())
		return null
	if(here == get_turf(exit_door))
		return beyond || here
	var/turf/inside = processing_cross_spot(who, entry)
	if(in_processing(here))
		processing_request_cross(who, into_yard)
		if(processing_tow_entering(who, entry, into_yard))
			return (inside && here != inside) ? inside : here
		var/exit_passable = !exit_door.density && !exit_door.operating && (exit_door.lockup_breached() || processing_who() == who)
		if(exit_passable && beyond)
			var/mob/living/towed = isliving(who.pulling) ? who.pulling : null
			var/turf/tow_turf = get_turf(towed)
			var/turf/exit_turf = get_turf(exit_door)
			if(towed && towed.density && in_processing(tow_turf) && exit_turf && here.Adjacent(tow_turf) && !who.moving_diagonally)
				if((abs(tow_turf.x - exit_turf.x) + abs(tow_turf.y - exit_turf.y)) < (abs(here.x - exit_turf.x) + abs(here.y - exit_turf.y)))
					pirate_crew_swap_places(who, towed)
			return beyond
		return here
	if(here == get_turf(entry))
		processing_request_cross(who, into_yard)
		return inside
	var/turf/wait_turf = processing_outside_turf(entry)
	if(wait_turf && here != wait_turf)
		return wait_turf
	if(!wait_turf && get_dist(here, entry) > 1)
		return null
	processing_request_cross(who, into_yard)
	var/entry_passable = !entry.density && !entry.operating && (entry.lockup_breached() || processing_who() == who)
	return entry_passable ? inside : here

/// Nothing on: both doors are shut, unseen dead bodies inside are cleared, and the next one waiting to leave gets the room
/datum/outpost_prison/proc/processing_idle_tick()
	if(!has_processing())
		return
	var/obj/machinery/door/airlock/inner = processing_door(TRUE)
	var/obj/machinery/door/airlock/outer = processing_door(FALSE)
	if(processing_cleanbot_only())
		processing_work_door(outer, FALSE)
		if(processing_shut(outer))
			processing_work_door(inner, TRUE)
			if(!inner.density && !inner.operating)
				var/turf/yard_step = processing_outside_turf(inner)
				if(yard_step)
					for(var/mob/living/basic/bot/cleanbot/outpost_lockup/bot in processing_occupants())
						if(bot.stat != DEAD && !bot.client && bot.mode == BOT_IDLE)
							bot.send_to_mess(yard_step)
		return
	processing_work_door(inner, FALSE)
	processing_work_door(outer, FALSE)
	if(processing_shut(inner) && processing_shut(outer) && !processing_player_inside())
		processing_clear_dead()
	if(processing_shut(inner) && processing_shut(outer))
		for(var/mob/living/occupant as anything in processing_occupants())
			if(!occupant.client && !occupant.mind?.key && is_inmate(occupant) && try_start_processing_inmate_in(occupant))
				return
	if(processing_check_releases())
		return
	if(!length(processing_leavers))
		return
	var/room_free = processing_free()
	for(var/mob/living/leaver in processing_leavers)
		if(leaver.stat != CONSCIOUS || get_area(leaver) != wing)
			continue
		if(!room_free && !processing_leaver_ready_inside(leaver))
			continue
		processing_state = OUTPOST_PROCESSING_OUT
		processing_who_ref = WEAKREF(leaver)
		processing_entry_ref = WEAKREF(processing_on_yard_side(get_turf(leaver)) ? inner : outer)
		processing_seconds = 0
		return

/// With both solid doors shut and no player inside, clears any unseen dead NPC or pest body blocking the room
/datum/outpost_prison/proc/processing_clear_dead()
	for(var/mob/living/body as anything in processing_occupants())
		if(QDELETED(body) || body.stat != DEAD || body.client || body.mind)
			continue
		var/mob/living/carbon/human/npc/npc = body
		if(istype(npc) && npc.npc_ever_played())
			continue
		if(ishuman(body) && !istype(npc))
			continue
		if(outpost_prison_body_held(body) || seen_by_client(body))
			continue
		if((body in prisoners) && !bodies_cleared)
			continue
		if(body in prisoners)
			add_log("[body.real_name]'s body was taken away.")
		qdel(body)

/**
 * An arrival: with the outer door shut the inner one opens, they walk out, and the job is over once they are in
 * the yard. One who has not stepped out after OUTPOST_PRISON_PROCESSING_WAIT, with no client able to see them, is
 * put in their cell.
 */
/datum/outpost_prison/proc/processing_in_tick(seconds)
	var/mob/living/who = processing_who()
	if(QDELETED(who))
		processing_done()
		return
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = who
	if(!istype(prisoner))
		prisoner = null
	if(who.stat == DEAD)
		// Dead before they stepped out: a body like any other, the wing's to deal with (body_tick())
		if(prisoner?.phase == PRISONER_ARRIVING)
			prisoner.phase = PRISONER_PRESENT
			prisoner.processing_goal = null
		processing_done()
		return
	if(prisoner && !(prisoner in prisoners))
		prisoner.processing_goal = null
		if(in_processing(prisoner) && processing_shut(processing_door(TRUE)) && processing_shut(processing_door(FALSE)) && !processing_player_inside())
			processing_remove(prisoner)
		else if(in_processing(prisoner))
			processing_send_out(prisoner)
		else
			outpost_prison_clear_unseen(prisoner)
		processing_done()
		return
	var/obj/machinery/door/airlock/inner = processing_door(TRUE)
	var/obj/machinery/door/airlock/outer = processing_door(FALSE)
	var/turf/here = get_turf(who)
	if(!in_processing(who) && here != get_turf(inner))
		// Out in the yard
		prisoner?.finish_arrival()
		processing_done()
		return
	processing_seconds += seconds
	if(!prisoner && (processing_seconds >= OUTPOST_PRISON_PROCESSING_WAIT || who.stat != CONSCIOUS))
		processing_done()
		return
	if(!processing_shut(outer))
		processing_work_door(outer, FALSE)
		return
	if(inner.density)
		processing_work_door(inner, TRUE)
	else if(prisoner && !prisoner.processing_goal)
		prisoner.processing_goal = prisoner.cell?.arrival_turf() || get_step(inner, get_dir(here, inner))
	else if(!prisoner && !inner.operating && !who.client && !who.mind?.key && who.stat == CONSCIOUS && who.body_position != LYING_DOWN && !HAS_TRAIT(who, TRAIT_INCAPACITATED))
		var/turf/yard_step = processing_outside_turf(inner)
		if(here == get_turf(inner) && yard_step)
			who.Move(yard_step, get_dir(who, yard_step))
		else
			step_towards(who, get_turf(inner))
	if(prisoner && processing_seconds >= OUTPOST_PRISON_PROCESSING_WAIT && !seen_by_client(prisoner))
		var/turf/home = prisoner.cell?.arrival_turf()
		if(home)
			prisoner.forceMove(home)
			prisoner.processing_goal = null

/// Claims Processing to let a held inmate already inside Processing step out into the yard once the outer door is shut
/datum/outpost_prison/proc/try_start_processing_inmate_in(mob/living/who)
	if(QDELETED(who) || !is_inmate(who) || !in_processing(who) || !has_processing())
		return FALSE
	if(who.stat != CONSCIOUS || who.body_position == LYING_DOWN || HAS_TRAIT(who, TRAIT_INCAPACITATED))
		return FALSE
	if((who.mind?.key && !who.client) || processing_state != OUTPOST_PROCESSING_IDLE)
		return FALSE
	var/obj/machinery/door/airlock/inner = processing_door(TRUE)
	var/obj/machinery/door/airlock/outer = processing_door(FALSE)
	if(!inner || !outer || !processing_shut(outer) || processing_outsider_inside())
		return FALSE
	processing_state = OUTPOST_PROCESSING_IN
	processing_who_ref = WEAKREF(who)
	processing_entry_ref = null
	processing_seconds = 0
	processing_work_door(inner, TRUE)
	return TRUE

/// Prunes `processing_release_refs` and starts `OUTPOST_PROCESSING_RELEASE` for the first released inmate ready at the inner door
/datum/outpost_prison/proc/processing_check_releases()
	if(!length(processing_release_refs) || !has_processing())
		return FALSE
	for(var/datum/weakref/ref as anything in processing_release_refs.Copy())
		var/mob/living/who = ref?.resolve()
		if(QDELETED(who) || who.stat == DEAD || holds(who.mind) || !contains_turf(get_turf(who)) || in_front_room(who))
			processing_release_refs -= ref
			continue
		if(try_start_processing_release(who))
			return TRUE
	return FALSE

/// Claims Processing to pass a released player inmate (`who`) out to the front room once they arrive at the inner door
/datum/outpost_prison/proc/try_start_processing_release(mob/living/who)
	if(QDELETED(who) || who.stat != CONSCIOUS || who.body_position == LYING_DOWN || HAS_TRAIT(who, TRAIT_INCAPACITATED))
		return FALSE
	if((who.mind?.key && !who.client) || holds(who.mind) || !has_processing() || processing_state != OUTPOST_PROCESSING_IDLE)
		return FALSE
	var/obj/machinery/door/airlock/inner = processing_door(TRUE)
	var/obj/machinery/door/airlock/outer = processing_door(FALSE)
	if(!inner || !outer || processing_outsider_inside(who) || processing_inmate_inside(who))
		return FALSE
	if(in_processing(who))
		processing_state = OUTPOST_PROCESSING_RELEASE
		processing_who_ref = WEAKREF(who)
		processing_entry_ref = WEAKREF(inner)
		processing_seconds = 0
		processing_release_tick(0)
		return TRUE
	if(!processing_on_yard_side(get_turf(who)) || get_dist(who, inner) > 2)
		return FALSE
	if(!processing_shut(outer) || !processing_shut(inner))
		return FALSE
	processing_state = OUTPOST_PROCESSING_RELEASE
	processing_who_ref = WEAKREF(who)
	processing_entry_ref = WEAKREF(inner)
	processing_seconds = 0
	processing_work_door(inner, TRUE)
	return TRUE

/// Cycles a released inmate out through Processing: inner opens when they arrive, shuts once inside, then outer opens
/datum/outpost_prison/proc/processing_release_tick(seconds)
	var/mob/living/who = processing_who()
	if(QDELETED(who) || who.stat == DEAD || holds(who.mind) || !contains_turf(get_turf(who)) || in_front_room(who) || !has_processing())
		if(who)
			processing_release_refs -= WEAKREF(who)
		processing_done()
		processing_idle_tick()
		return
	var/obj/machinery/door/airlock/inner = processing_door(TRUE)
	var/obj/machinery/door/airlock/outer = processing_door(FALSE)
	var/turf/here = get_turf(who)
	if(in_processing(who) || here == get_turf(outer))
		processing_seconds += seconds
		if(processing_seconds >= OUTPOST_PRISON_PROCESSING_WAIT || who.stat != CONSCIOUS || processing_inmate_inside(who))
			processing_done()
			return
		if(!processing_shut(inner))
			processing_work_door(inner, FALSE)
			return
		if(outer.density)
			processing_work_door(outer, TRUE)
			return
		if(!outer.operating && !who.client && !who.mind?.key && who.stat == CONSCIOUS && who.body_position != LYING_DOWN && !HAS_TRAIT(who, TRAIT_INCAPACITATED))
			var/turf/front_step = processing_outside_turf(outer)
			if(here == get_turf(outer) && front_step)
				who.Move(front_step, get_dir(who, front_step))
			else
				step_towards(who, get_turf(outer))
		return
	processing_seconds += seconds
	if(processing_seconds >= OUTPOST_PRISON_PROCESSING_WAIT || who.stat != CONSCIOUS || who.body_position == LYING_DOWN)
		processing_done()
		return
	if(!processing_shut(outer))
		processing_work_door(outer, FALSE)
		return
	if(inner.density)
		processing_work_door(inner, TRUE)
		return
	if(!inner.operating && !who.client && !who.mind?.key && !HAS_TRAIT(who, TRAIT_INCAPACITATED))
		var/turf/spot = processing_spot(who)
		if(spot)
			step_towards(who, spot)

/**
 * Someone leaving: the door on their side opens with the other shut, they walk in, it shuts, and they are gone.
 * One who cannot get there within OUTPOST_PRISON_PROCESSING_WAIT goes to the back of the queue and keeps trying.
 */
/datum/outpost_prison/proc/processing_out_tick(seconds)
	var/mob/living/who = processing_who()
	if(QDELETED(who) || who.stat == DEAD || !(who in processing_leavers))
		processing_done()
		return
	var/obj/machinery/door/airlock/inner = processing_door(TRUE)
	var/obj/machinery/door/airlock/outer = processing_door(FALSE)
	var/obj/machinery/door/airlock/entry = processing_entry_ref?.resolve()
	if(entry != inner && entry != outer)
		entry = inner
	var/obj/machinery/door/airlock/other = (entry == inner) ? outer : inner
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = who
	if(!istype(prisoner))
		prisoner = null
	if(in_processing(who))
		if(!processing_shut(entry))
			processing_work_door(entry, FALSE)
			return
		if(!processing_shut(other))
			processing_work_door(other, FALSE)
			return
		if(processing_player_inside())
			return
		processing_remove(who)
		processing_done()
		return
	processing_seconds += seconds
	if(processing_seconds >= OUTPOST_PRISON_PROCESSING_WAIT)
		// Could not get there: someone else may go first
		prisoner?.processing_goal = null
		processing_leavers -= who
		processing_leavers += who
		processing_done()
		return
	if(!processing_shut(other))
		processing_work_door(other, FALSE)
		return
	if(entry.density)
		processing_work_door(entry, TRUE)
		return
	if(prisoner && !prisoner.processing_goal)
		prisoner.processing_goal = processing_spot(prisoner)

/**
 * Everyone waiting to leave. The dead are no longer leaving (their body is the wing's again). A wing with no
 * Processing room has nothing to walk to, so its people go at once; elsewhere one of the wing's prisoners who has
 * not made it into the room is gone from where they stand once no client has been able to see them for
 * OUTPOST_PRISON_LEAVE_UNSEEN.
 */
/datum/outpost_prison/proc/processing_leavers_tick(seconds)
	if(!length(processing_leavers))
		return
	var/room = has_processing()
	for(var/mob/living/leaver in processing_leavers.Copy())
		var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = leaver
		if(!istype(prisoner))
			prisoner = null
		if(QDELETED(leaver))
			processing_leavers -= leaver
			continue
		if(leaver.stat == DEAD)
			processing_leavers -= leaver
			if(prisoner?.phase == PRISONER_LEAVING)
				prisoner.phase = PRISONER_PRESENT
				prisoner.processing_goal = null
			if(prisoner && !(prisoner in prisoners))
				outpost_prison_clear_unseen(prisoner)
			continue
		if(!prisoner)
			continue
		if(prisoner.cell && wing && get_area(prisoner) != wing)
			vacate_cell(prisoner)
		if(!room)
			processing_remove(prisoner)
			continue
		if(in_processing(prisoner))
			continue
		if(outpost_prison_body_held(prisoner) || seen_by_client(prisoner))
			prisoner.leave_unseen = 0
			continue
		prisoner.leave_unseen += seconds
		if(prisoner.leave_unseen >= OUTPOST_PRISON_LEAVE_UNSEEN)
			if(processing_who() == prisoner)
				processing_done()
			processing_remove(prisoner)

/// Frees `prisoner`'s cell and starts its refill wait while keeping `prisoner` on the wing until they are gone
/datum/outpost_prison/proc/vacate_cell(mob/living/carbon/human/npc/outpost_prisoner/prisoner)
	var/datum/outpost_prison_cell/emptied = prisoner?.cell
	if(!emptied)
		return
	if(emptied.occupant == prisoner)
		emptied.occupant = null
	prisoner.cell = null
	on_cell_emptied(emptied)

/// Lets go of the room's doors and everyone waiting on it (Destroy())
/datum/outpost_prison/proc/processing_destroy()
	processing_state = OUTPOST_PROCESSING_IDLE
	processing_who_ref = null
	processing_entry_ref = null
	processing_inner_ref = null
	processing_outer_ref = null
	processing_leavers.Cut()

// ===== THE PRISONER'S SIDE =====

/**
 * They are in: bruised if the transfer was rough (real limb damage, nobody to blame), and either sent out of
 * Processing to walk to their cell (`through_processing`, admit_next()) or, made in their cell with nobody at the
 * outpost to see them come in, simply there.
 */
/mob/living/carbon/human/npc/outpost_prisoner/proc/arrive(through_processing = FALSE)
	came_by_intake = TRUE
	if(arrival_brute > 0)
		outpost_prison_bruise(src, arrival_brute)
		arrival_brute = 0
		arrived_hurt = TRUE
	if(through_processing && prison?.processing_send_in(src))
		// Shut in the room: no routine, trouble, speech or thought bubble until they step out (finish_arrival())
		phase = PRISONER_ARRIVING
		update_bubble()
		drop_bubble()
		return
	finish_arrival()

/// In the yard, or in their cell: one of the wing's prisoners from here on, and they say how they came in
/mob/living/carbon/human/npc/outpost_prisoner/proc/finish_arrival()
	var/was_arriving = (phase == PRISONER_ARRIVING)
	phase = PRISONER_PRESENT
	update_bubble()
	if(was_arriving)
		prison?.refresh_prisoner_reach(src)
	// A bounty prisoner names the crew that caught them (outpost_prison_bounty.dm)
	if(bounty_arrival_speech())
		return
	// How they came in, if it shows; otherwise hello.
	if(arrived_hurt && say_context("arrival_hurt"))
		return
	if(arrived_stained && say_context("arrival_stained"))
		return
	say_context("arrival")

/**
 * They are leaving the wing for good (released, moved on after a riot, got away): from here they are
 * PRISONER_LEAVING, with no routine, trouble, speech or thought bubble, and walk to Processing
 * (/datum/outpost_prison/proc/processing_send_out()). Off any wing's roster, they are gone as soon as nobody is
 * near enough to see it.
 */
/mob/living/carbon/human/npc/outpost_prisoner/proc/leave()
	if(phase == PRISONER_LEAVING)
		return
	var/was_loose = (trouble == PRISONER_TROUBLE_LOOSE)
	phase = PRISONER_LEAVING
	end_activity()
	clear_trouble()
	if(was_loose)
		// Their own AI walks them to Processing, not the breakout's
		swap_basic_ai_controller(src, /datum/ai_controller/basic_controller/outpost_prisoner)
	drop_held_item()
	remove_cuffs()
	stand_up()
	pulledby?.stop_pulling()
	set_prison_pace(hurry = FALSE)
	processing_goal = null
	leave_unseen = 0
	update_bubble()
	drop_bubble()
	if(prison)
		if(prison.wing && get_area(src) != prison.wing)
			prison.vacate_cell(src)
		prison.processing_send_out(src)
	else
		outpost_prison_clear_unseen(src)

/**
 * One of a lockup's people who is no longer its business (a prisoner revived after their body left the roster, a
 * guard carried off): gone the first time nobody is near enough to see it go, looked at every few seconds.
 * Never a body a player is or was in, and never while it is dragged, carried or shut in something.
 */
/proc/outpost_prison_clear_unseen(mob/living/carbon/human/npc/who)
	if(!istype(who) || QDELETED(who) || who.npc_ever_played())
		return
	if(who.stat == DEAD)
		// A body is cleared the way any human NPC's is (human_npc_spawning.dm)
		who.npc_corpse_lifetime ||= HUMAN_NPC_CORPSE_LIFETIME
		SShuman_npcs.track_corpse(who)
		return
	if(!isturf(who.loc) || who.pulledby || who.buckled || human_npc_watched(who))
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(outpost_prison_clear_unseen_ref), WEAKREF(who)), 5 SECONDS)
		return
	qdel(who)

/proc/outpost_prison_clear_unseen_ref(datum/weakref/who_ref)
	outpost_prison_clear_unseen(who_ref?.resolve())

/// Processing has them walking: out to their cell as they arrive, or into the room as they leave. Until they are there, nothing else.
/datum/ai_planning_subtree/outpost_prisoner_processing

/datum/ai_planning_subtree/outpost_prisoner_processing/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = controller.pawn
	if(!istype(prisoner) || !prisoner.processing_goal)
		return
	// An arrival who gets into trouble on the way to their cell has other things on their mind
	if(prisoner.phase == PRISONER_PRESENT && prisoner.in_trouble())
		prisoner.processing_goal = null
		return
	if(prisoner.stat != CONSCIOUS || prisoner.can_be_dragged() || prisoner.pulledby)
		return
	if(prisoner.loc == prisoner.processing_goal)
		if(prisoner.phase == PRISONER_LEAVING)
			// In the room: they wait for the door
			return SUBTREE_RETURN_FINISH_PLANNING
		prisoner.processing_goal = null
		return
	controller.queue_behavior(/datum/ai_behavior/outpost_prisoner_processing_walk)
	return SUBTREE_RETURN_FINISH_PLANNING

/// Walks to where Processing wants them
/datum/ai_behavior/outpost_prisoner_processing_walk
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT
	required_distance = 0
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/outpost_prisoner_processing_walk/setup(datum/ai_controller/controller)
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = controller.pawn
	var/turf/goal = prisoner.processing_goal
	if(!goal)
		return FALSE
	prisoner.stand_up()
	set_movement_target(controller, goal)
	return TRUE

/datum/ai_behavior/outpost_prisoner_processing_walk/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = controller.pawn
	if(prisoner.processing_goal && prisoner.loc == prisoner.processing_goal)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

/datum/ai_behavior/outpost_prisoner_processing_walk/finish_action(datum/ai_controller/controller, succeeded)
	. = ..()
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = controller.pawn
	// An arrival who cannot get to their cell gets on with their day; someone leaving keeps trying
	if(!succeeded && istype(prisoner) && prisoner.phase == PRISONER_PRESENT)
		prisoner.processing_goal = null
