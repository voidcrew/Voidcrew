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
	/// OUTPOST_PROCESSING_IDLE, _IN or _OUT
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
	switch(processing_state)
		if(OUTPOST_PROCESSING_IN)
			processing_in_tick(seconds)
		if(OUTPOST_PROCESSING_OUT)
			processing_out_tick(seconds)
		else
			processing_idle_tick()

/// Nothing on: both doors are shut, unseen dead bodies inside are cleared, and the next one waiting to leave gets the room
/datum/outpost_prison/proc/processing_idle_tick()
	if(!has_processing())
		return
	var/obj/machinery/door/airlock/inner = processing_door(TRUE)
	var/obj/machinery/door/airlock/outer = processing_door(FALSE)
	processing_work_door(inner, FALSE)
	processing_work_door(outer, FALSE)
	if(processing_shut(inner) && processing_shut(outer) && !processing_player_inside())
		processing_clear_dead()
	if(!length(processing_leavers) || !processing_free())
		return
	for(var/mob/living/leaver in processing_leavers)
		if(leaver.stat != CONSCIOUS || get_area(leaver) != wing)
			continue
		processing_state = OUTPOST_PROCESSING_OUT
		processing_who_ref = WEAKREF(leaver)
		processing_entry_ref = WEAKREF(in_cell_block(leaver) ? inner : outer)
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
	if(!processing_shut(outer))
		processing_work_door(outer, FALSE)
		return
	if(inner.density)
		processing_work_door(inner, TRUE)
	else if(prisoner && !prisoner.processing_goal)
		prisoner.processing_goal = prisoner.cell?.arrival_turf() || get_step(inner, get_dir(here, inner))
	if(prisoner && processing_seconds >= OUTPOST_PRISON_PROCESSING_WAIT && !seen_by_client(prisoner))
		var/turf/home = prisoner.cell?.arrival_turf()
		if(home)
			prisoner.forceMove(home)
			prisoner.processing_goal = null

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
		if(!processing_shut(other) || processing_player_inside())
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
