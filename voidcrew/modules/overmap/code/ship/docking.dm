///
/// Berth docking.
///
/// The dock/undock state machine against sites: warmups, complete_dock's retry
/// chains, the stalled-manoeuvre watchdog, berth flag bookkeeping and the
/// background site-load handshake. Ship-to-ship rendezvous mechanics live in
/// ship_to_ship.dm.

/obj/structure/overmap/ship
	/// Timer ID for dock warmup
	var/dock_warmup_timer
	/// Timer ID for undock warmup
	var/undock_warmup_timer
	/// The site complete_undock_warmup() launched us away from, kept so check_manoeuvre_stalled()
	/// can restart a lost undock with the same argument the timer chain was carrying - without it
	/// the recovery cannot hand the berth back, because `docked` is cleared on the way out. Weak
	/// because the site can be torn down the moment we leave it. Null whenever we are not undocking.
	var/datum/weakref/undock_origin
	/// Transitional state check_manoeuvre_stalled() last saw us in, and when it first saw it.
	/// Watchdog bookkeeping only - observed by the poll rather than stamped at each `state`
	/// assignment, so a new assignment site cannot forget to arm it.
	var/manoeuvre_watch_state
	var/manoeuvre_watch_since = 0

/**
  * Acts on the specified option. Used for docking.
  * * user - Mob that started the action
  * * object - Overmap object to act on
  */
/obj/structure/overmap/ship/proc/overmap_object_act(mob/user, obj/structure/overmap/object, obj/structure/overmap/ship/optional_partner)
	if(!is_still() || state != OVERMAP_SHIP_FLYING)
		to_chat(user, "<span class='warning'>Ship must be still to interact!</span>")
		return

	INVOKE_ASYNC(object, TYPE_PROC_REF(/obj/structure/overmap, ship_act), user, src, optional_partner)

/// How many one-second complete_dock() retries to spend waiting for the shuttle to
/// physically finish a move before giving up and putting the ship back into a state the
/// helm can actually drive. A healthy move lands on the next SSshuttle fire; a shuttle
/// waiting on a transit reservation retries every 2 seconds and may never get one (the
/// global budget, MAX_TRANSIT_TILE_COUNT, is finite and shared by every flying ship), and
/// the old code retried forever - leaving `state` pinned at DOCKING/UNDOCKING, which the
/// helm's ui_act has no branch for, so every button on the console silently did nothing.
#define DOCK_MOVE_MAX_ATTEMPTS 30

/// How long a ship may sit in one transitional overmap state - DOCKING, UNDOCKING or ACTING -
/// before SSovermap's poll treats the sequence as lost and reconciles the ship against where its
/// hull physically is. Every one of those states greys out all four helm ops buttons and the
/// cargo console's call button, so a sequence that quietly stops advancing is a dead ship for the
/// rest of the round; today the only exit is an admin editing `state` by hand.
///
/// Generous on purpose. A healthy dock is the warmup plus at most DOCK_MOVE_MAX_ATTEMPTS of
/// retries, and the waits that legitimately run longer than that - a destination still generating
/// its interior, a sector build somebody else is holding the worldgen queue for - hold the clock
/// rather than counting against it. Reaching this means nothing is coming.
#define MANOEUVRE_STALL_TIMEOUT (90 SECONDS)

/// Dock warmup time in deciseconds
#define DOCK_WARMUP_TIME (10 SECONDS)
/// Undock warmup time in deciseconds
#define UNDOCK_WARMUP_TIME (10 SECONDS)
/// Undock cooldown time in deciseconds (after docking, before can undock)
#define UNDOCK_COOLDOWN_TIME (20 SECONDS)

/**
 * Messaging only, no flow change: request() (mobile_port.dm) drops a dock call on the
 * floor when its berth check fails - no return value and no player-facing sign, so the
 * sequence just sits until the stall watchdog reconciles it and the crew invents a
 * reason. Run the same side-effect-free geometry check request() is about to run and
 * TELL the crew when the request is going to be refused. Changes no state and blocks
 * nothing - the caller still issues the request exactly as before.
 *
 * Returns TRUE when a refusal was detected (and broadcast), FALSE when the request
 * should go through.
 */
/obj/structure/overmap/ship/proc/explain_dock_refusal(obj/docking_port/stationary/dock_to_use)
	if(!shuttle || !dock_to_use)
		return FALSE
	var/status = shuttle.canDock(dock_to_use)
	// ALREADY_DOCKED is benign - request() treats it as "nothing to do", not a fault
	if(status == SHUTTLE_CAN_DOCK || status == SHUTTLE_ALREADY_DOCKED)
		return FALSE
	var/reason
	switch(status)
		if(SHUTTLE_DWIDTH_TOO_LARGE, SHUTTLE_WIDTH_TOO_LARGE, SHUTTLE_DHEIGHT_TOO_LARGE, SHUTTLE_HEIGHT_TOO_LARGE)
			reason = "this ship does not fit that berth ([status]). A hull extension can outgrow a berth's clearance."
		if(SHUTTLE_SOMEONE_ELSE_DOCKED)
			reason = "another vessel is already occupying that berth."
		else
			reason = "the berth rejected the request ([status])."
	ship_notify("DOCKING FAULT: [reason]", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
	return TRUE

/**
  * Docks the shuttle by requesting a port at the requested spot.
  * * to_dock - The [/obj/structure/overmap] to dock to.
  * * dock_to_use - The [/obj/docking_port/mobile] to dock to.
  * * instant - If TRUE, bypasses the dock warmup (used for force dock)
  */
/obj/structure/overmap/ship/proc/dock(obj/structure/overmap/to_dock, obj/docking_port/stationary/dock_to_use, instant = FALSE)
	// Can't dock while being interdicted (unless it's a force dock)
	if(is_interdicted && !instant)
		// ship_act() callers pre-check interdiction, but if a refused dock still
		// reaches here with the ship locked into ACTING, restore it - a ship left
		// in ACTING can never move, dock, or undock again
		if(state == OVERMAP_SHIP_ACTING)
			state = OVERMAP_SHIP_FLYING
		ship_notify("DOCKING ABORTED: Interdiction field preventing dock sequence!", "NAVIGATION", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return "Cannot dock while interdicted!"

	refresh_engines()

	// Clear thrust when docking, and the commanded course with it - a berth is
	// where every course ends
	burn_direction = BURN_NONE
	commanded_course = BURN_NONE
	thrust_processing = FALSE
	update_ship_processing()

	docked = to_dock
	state = OVERMAP_SHIP_DOCKING

	// Check if target is a planet that's still loading
	if(istype(to_dock, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/current_planet = to_dock
		current_planet.visited = TRUE
		if(current_planet.loading)
			// Register signal to complete dock when planet finishes loading
			RegisterSignal(current_planet, COMSIG_VOIDCREW_PLANET_LOADED, PROC_REF(on_planet_loaded))
			return "Commencing docking, awaiting zone loading..."

	// Instant dock (force dock) - bypass warmup
	if(instant)
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SHIP_ABOUT_TO_DOCK)
		// Messaging only - the request below is issued either way, and the stall
		// watchdog still owns recovery. See explain_dock_refusal().
		var/refused = explain_dock_refusal(dock_to_use)
		shuttle.request(dock_to_use)
		shuttle.setTimer(1 SECONDS)
		addtimer(CALLBACK(src, PROC_REF(complete_dock), WEAKREF(to_dock)), 1 SECONDS)
		// On a refusal the fault broadcast has already said everything; don't follow it
		// with a contradictory "Commencing docking..." echo
		return refused ? null : "Commencing docking..."

	// Start dock warmup. Return nothing: ship_notify() has already told the whole crew,
	// including whoever pressed the button, and callers echo a returned string straight
	// back to that person - returning the same line printed it twice, once bold from the
	// broadcast and once plain from the echo. Only refusals get a return value now.
	ship_notify("Initiating docking sequence. Docking in [DOCK_WARMUP_TIME / 10] seconds.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	dock_warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_dock_warmup), dock_to_use, WEAKREF(to_dock)), DOCK_WARMUP_TIME, TIMER_STOPPABLE)
	return null

/**
  * Called after dock warmup completes - actually begins the shuttle dock
  */
/obj/structure/overmap/ship/proc/complete_dock_warmup(obj/docking_port/stationary/dock_to_use, datum/weakref/to_dock_ref)
	dock_warmup_timer = null

	// Check if we're still in docking state (might have been cancelled)
	if(state != OVERMAP_SHIP_DOCKING)
		return

	var/obj/structure/overmap/to_dock = to_dock_ref?.resolve()
	if(!to_dock)
		state = OVERMAP_SHIP_FLYING
		docked = null
		ship_notify("Docking aborted: destination no longer available.", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return

	var/obj/structure/overmap/dynamic/player_outpost/home = astype(to_dock)
	if(home)
		var/denial = home.get_docking_denial(src)
		if(denial)
			home.on_ship_undock_complete(src)
			state = OVERMAP_SHIP_FLYING
			docked = null
			ship_notify(denial, "DOCKING", SHIP_NOTIFY_WARNING)
			return
	SEND_SIGNAL(src, COMSIG_VOIDCREW_SHIP_ABOUT_TO_DOCK)
	// Messaging only - the request is issued either way and the stall watchdog still
	// owns recovery. On a refusal, skip the "Docking now." line so the crew isn't told
	// a move is happening right after being told why it can't.
	var/refused = explain_dock_refusal(dock_to_use)
	shuttle.request(dock_to_use)
	if(!refused)
		ship_notify("Docking now.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	shuttle.setTimer(1 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(complete_dock), to_dock_ref), 1 SECONDS)

/**
  * Signal handler - completes docking when a planet finishes loading.
  */
/obj/structure/overmap/ship/proc/on_planet_loaded(obj/structure/overmap/planet/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_VOIDCREW_PLANET_LOADED)

	if(state != OVERMAP_SHIP_DOCKING || docked != source)
		return // Ship state changed, abort

	// Get the dock port to use
	var/obj/docking_port/stationary/dock_to_use = shuttle.port_destinations

	// Start dock warmup
	ship_notify("Destination loaded. Docking in [DOCK_WARMUP_TIME / 10] seconds.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	dock_warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_dock_warmup), dock_to_use, WEAKREF(source)), DOCK_WARMUP_TIME, TIMER_STOPPABLE)

/**
 * Requests generation of an ungenerated site's interior WITHOUT holding the helm:
 * the ship stays fully controllable, progress is broadcast crew-wide, and the
 * docking approach resumes on its own when the site charts.
 *
 * Called from the ship_act() of planets, space ruins and meteor fields when their
 * interior isn't generated yet. Completion (success or failure) arrives via
 * COMSIG_VOIDCREW_SITE_LOAD_FINISHED; while queued, progress comes from
 * worldgen_claim()'s notify_ship routing.
 *
 * * site - the overmap object that needs its interior generated.
 * * user - the mob that pressed Dock, if any; kept by weakref for the resume.
 */
/obj/structure/overmap/ship/proc/request_site_load(obj/structure/overmap/site, mob/user)
	// A second destination while one is already queued supersedes the first rather
	// than stacking: only the newest approach gets to auto-resume.
	var/obj/structure/overmap/old_site = awaiting_load_site?.resolve()
	if(old_site == site)
		awaiting_load_user = WEAKREF(user)
		ship_notify("Survey of [site.get_site_label()] is already underway - the approach resumes on its own when it charts.", "SURVEY", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		return
	if(old_site)
		UnregisterSignal(old_site, list(COMSIG_VOIDCREW_SITE_LOAD_FINISHED, COMSIG_QDELETING))
		ship_notify("Survey request for [old_site.get_site_label()] superseded by a new approach.", "SURVEY", SHIP_NOTIFY_NOTICE)

	awaiting_load_site = WEAKREF(site)
	awaiting_load_user = WEAKREF(user)
	RegisterSignal(site, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, PROC_REF(on_site_load_finished))
	RegisterSignal(site, COMSIG_QDELETING, PROC_REF(on_site_load_qdeleting))

	// The site may have finished loading between the helm's check and now - never
	// sit waiting for a signal that already fired.
	if(site.is_loaded())
		UnregisterSignal(site, list(COMSIG_VOIDCREW_SITE_LOAD_FINISHED, COMSIG_QDELETING))
		awaiting_load_site = null
		awaiting_load_user = null
		INVOKE_ASYNC(site, TYPE_PROC_REF(/obj/structure/overmap, ship_act), user, src)
		return

	var/queue_depth = SSovermap.worldgen_queue_length() + (SSovermap.worldgen_owner ? 1 : 0)
	var/queue_status = queue_depth ? "[queue_depth] survey operation[queue_depth == 1 ? "" : "s"] ahead of us." : "The survey starts immediately."
	ship_notify("Survey request logged for [site.get_site_label()]. [queue_status] Helm remains free - we will broadcast when the site is charted.", "SURVEY", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	if(site.is_loading())
		// Another crew (or our own earlier press) already started this one; its
		// load sends the same completion signal we just registered for.
		ship_notify("A survey of this site is already underway - the approach resumes on its own when it charts.", "SURVEY", SHIP_NOTIFY_NOTICE)
	else
		site.start_level_load(user, src)

/**
 * Signal handler - a site we were waiting on finished (or failed) its generation.
 * Resumes the docking approach if the ship is still in a position to take it:
 * flying, stationary, on the site's tile, and not interdicted. Anything else gets
 * a "dock when ready" broadcast instead - the ship may have moved on deliberately.
 */
/obj/structure/overmap/ship/proc/on_site_load_finished(obj/structure/overmap/site, success)
	SIGNAL_HANDLER
	UnregisterSignal(site, list(COMSIG_VOIDCREW_SITE_LOAD_FINISHED, COMSIG_QDELETING))
	awaiting_load_site = null
	var/mob/user = awaiting_load_user?.resolve()
	awaiting_load_user = null

	if(QDELETED(site))
		return
	if(!success)
		ship_notify("Survey of [site.get_site_label()] could not be completed right now - sector traffic is too heavy. Helm remains free; try docking again shortly.", "SURVEY", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return

	if(state == OVERMAP_SHIP_FLYING && is_still() && site.x == x && site.y == y && !is_interdicted && site.is_loaded())
		ship_notify("Chart complete: [site.get_site_label()]. Resuming docking approach.", "SURVEY", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		INVOKE_ASYNC(site, TYPE_PROC_REF(/obj/structure/overmap, ship_act), user, src)
	else
		// "Dock when ready" is not open-ended any more: a charted interior nobody has
		// landed on counts down and then drifts to another sector. Quote the window.
		var/obj/structure/overmap/planet/charted = astype(site, /obj/structure/overmap/planet)
		var/hold_remaining = charted?.get_interior_hold_remaining()
		if(hold_remaining)
			ship_notify("Chart complete: [site.get_site_label()]. It holds for [DisplayTimeText(hold_remaining)] - dock within that window or it drifts.", "SURVEY", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		else
			ship_notify("Chart complete: [site.get_site_label()]. It will hold position - dock when ready.", "SURVEY", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

/**
 * Signal handler - the site we were waiting on was deleted mid-survey.
 */
/obj/structure/overmap/ship/proc/on_site_load_qdeleting(obj/structure/overmap/site)
	SIGNAL_HANDLER
	UnregisterSignal(site, list(COMSIG_VOIDCREW_SITE_LOAD_FINISHED, COMSIG_QDELETING))
	awaiting_load_site = null
	awaiting_load_user = null
	ship_notify("Survey target lost from the chart. Approach cancelled.", "SURVEY", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

/**
  * Proc called after a shuttle is moved, used for checking a ship's location when it's moved manually (E.G. calling the mining shuttle via a console)
  */
/obj/structure/overmap/ship/proc/check_loc()
	var/docked_object = shuttle.current_ship
	if(docked_object == loc) //The docked object is correct, move along
		return TRUE
	if(state == OVERMAP_SHIP_DOCKING || state == OVERMAP_SHIP_UNDOCKING)
		return
	if(!istype(loc, /obj/structure/overmap) && is_reserved_level(shuttle)) //The object isn't currently docked, and doesn't think it is. This is correct.
		return TRUE
	if(!istype(loc, /obj/structure/overmap) && !docked_object) //The overmap object thinks it's docked to something, but it really isn't. Move to a random tile on the overmap
		forceMove(SSovermap.get_unused_overmap_square())
		state = OVERMAP_SHIP_FLYING
		update_screen()
		return FALSE
	if(isturf(loc) && docked_object) //The overmap object thinks it's NOT docked to something, but it actually is. Move to the correct place.
		forceMove(docked_object)
		state = OVERMAP_SHIP_IDLE
		decelerate(max_speed)
		update_screen()
		return FALSE
	return TRUE

/**
*	To properly fix the bug of two ships docking at the same time causing issues,
*	we need to keep track of whether or not a ship is requesting to dock at a
*	port IMMEDIATELY after the command is issued.
*	This also includes keeping track of when the ship is no longer there, upon which
*	the bools need to be set to false.
*	This function should be called whenever an action occurs that would remove a ship from the map
*/
/obj/structure/overmap/ship/proc/update_docked_bools()
	var/obj/structure/overmap/dynamic/dockable_place = docked
	if (!dockable_place)
		return
	if (dock_index == 1)
		dockable_place.first_dock_taken = FALSE
		dock_index = 0
	else if (dock_index == 2)
		dockable_place.second_dock_taken = FALSE
		dock_index = 0

/**
  * Undocks the shuttle by launching the shuttle with no destination (this causes it to remain in transit)
  */
/obj/structure/overmap/ship/proc/undock()
	if(!is_still()) //how the hell is it even moving (is the question I've asked multiple times) //fuck you past me this didn't help at all
		decelerate(max_speed)
	if(isturf(loc))
		check_loc()
		return "Ship not docked!"
	if(!shuttle)
		return "Shuttle not found!"
	// Already undocking
	if(state == OVERMAP_SHIP_UNDOCKING)
		return "Already undocking!"
	// Check undock cooldown (after docking)
	if(!COOLDOWN_FINISHED(src, undock_cooldown))
		return "Undock systems stabilizing! [DisplayTimeText(COOLDOWN_TIMELEFT(src, undock_cooldown))] remaining."
	// Check interdiction undock lockout
	if(!COOLDOWN_FINISHED(src, interdiction_undock_lockout))
		return "Undocking systems locked! [DisplayTimeText(COOLDOWN_TIMELEFT(src, interdiction_undock_lockout))] remaining."
	// Check post-failure lockout. Deliberately not cleared by repairing the hull - see
	// SHIP_INTEGRITY_UNDOCK_LOCKOUT - so this can still refuse a ship reading 100%.
	if(!COOLDOWN_FINISHED(src, integrity_undock_lockout))
		return "Hull failure logged! Structural recertification in progress, [DisplayTimeText(COOLDOWN_TIMELEFT(src, integrity_undock_lockout))] remaining."

	// Hull standing out past the docking port lands inside whatever the ship berths against
	// (hull_port_overhang() in hull_survey.dm has the geometry), so it cannot be allowed to
	// leave in that state.
	//
	// The reckoning is here rather than at the moment the hull grows because a build-time
	// refusal is unsatisfiable: the first tile built past the port already overhangs it, so a
	// crew could never reach the point of having a door out on the new outer face. Building
	// out is legal; leaving with the port still buried is not. This is also the last moment
	// the ship is guaranteed to be sitting still and reachable by its own construction gear.
	//
	// Reseat rather than refuse wherever the hull allows it. By the time there is a door on the
	// outermost plating the crew has done everything that makes the hull legal, and all that is
	// left is bookkeeping they would otherwise have to know to do by hand on the construction
	// console - a console they may well have just built over, or lost. A refusal is kept for the
	// hull with genuinely nowhere to put its port, which is the only case a message can help.
	//
	// Placed after the cooldown checks on purpose: the scan walks every turf of every hull area,
	// and there is no reason to pay for it on an undock that is about to be refused anyway.
	var/list/undock_overhang = hull_port_overhang(shuttle, null)
	if(undock_overhang[1] > 0)
		var/turf/reseat_to = hull_port_reseat_target(shuttle, null)
		if(!reseat_to)
			return "Launch refused: [undock_overhang[1]] metre\s of hull stand out past the docking \
				port, and there is no door on the outermost plating to move it to. Fit an airlock or \
				a firelock on that face - until then this ship would be driven through anything it \
				berths against."
		// Moves the port, drags the berth we are still standing on with it, recalculates the
		// hull's bounds and drops the stale transit reservation - which matters here more than
		// anywhere, since transit is where we are about to go.
		hull_reseat_port(shuttle, reseat_to)
		var/obj/machinery/door/reseated_door = hull_port_door(reseat_to)
		ship_notify("Hull extends past the old docking port. Port reseated to [reseated_door ? "the [reseated_door.name]" : "the outer hull"] \
			at ([reseat_to.x], [reseat_to.y]) - that door is now where other ships berth.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		log_shuttle("[shuttle] reseated its docking port to ([reseat_to.x], [reseat_to.y]) on undock, clearing a [undock_overhang[1]] tile overhang.")

	// Start undock warmup. Returns nothing for the same reason dock() does - the
	// broadcast below already reaches everyone, and the helm speaks any returned
	// string, so returning this line said it twice.
	state = OVERMAP_SHIP_UNDOCKING
	ship_notify("Initiating undocking sequence. Undocking in [UNDOCK_WARMUP_TIME / 10] seconds.", "UNDOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	undock_warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_undock_warmup)), UNDOCK_WARMUP_TIME, TIMER_STOPPABLE)
	return null

/**
  * Called after undock warmup completes - actually begins the shuttle undock
  */
/obj/structure/overmap/ship/proc/complete_undock_warmup()
	undock_warmup_timer = null

	// Check if we're still in undocking state (might have been cancelled)
	if(state != OVERMAP_SHIP_UNDOCKING)
		return

	// Don't clear dock flags here - wait until shuttle has actually moved in complete_dock
	// Otherwise the z-level might be unloaded while we're still on it
	// Clear port destinations when undocking from empty space to prevent confusion
	if(istype(docked, /obj/structure/overmap/planet/empty))
		shuttle.port_destinations = null
	// Store docked location for complete_dock to use, then clear it
	var/obj/structure/overmap/undock_from = docked
	docked = null
	shuttle.destination = null
	shuttle.mode = SHUTTLE_IGNITING
	shuttle.setTimer(1 SECONDS)
	// Kept on the ship as well as in the callback: if the chain below is ever lost, the
	// timer's copy goes with it, and check_manoeuvre_stalled() has no other way to learn
	// which berth to hand back.
	undock_origin = WEAKREF(undock_from)
	addtimer(CALLBACK(src, PROC_REF(complete_dock), undock_origin), 1 SECONDS)
	// Crash state is not cleared here. The integrity latch re-arms itself when the hull is
	// repaired back past its recovery threshold (see on_ship_recovered), and clearing the flag
	// on undock as well used to desync the two: the ship stopped reporting as a wreck while
	// still latched DISABLED, which meant a further hit could never fire on_ship_destroyed again.

/**
  * Sets the ship, shuttle, and shuttle areas to a new name.
  */

/**
  * Called after the shuttle docks, and finishes the transfer to the new location.
  */
/obj/structure/overmap/ship/proc/complete_dock(datum/weakref/to_dock, attempt = 1)
	// Commented out as it was being used by deleting planets during undock
	// var/old_loc = loc
	switch(state)
		if(OVERMAP_SHIP_DOCKING) //so that the shuttle is truly docked first
			// The honest "did the hull actually move?" test, and the exact inverse of the one
			// the UNDOCKING branch below already uses (see shuttle_is_in_transit's docstring).
			// The mode check this replaced could not tell the two ends of the move apart:
			// SHUTTLE_CALL is a voidcrew port's resting state in open flight and SHUTTLE_IDLE
			// is its resting state once berthed, and request() leaves a flying port on
			// SHUTTLE_CALL - so the test passed a second after the request exactly as readily
			// as it did after the arrival, and walked the overmap token onto the site whether
			// or not the hull followed. That is a ship the chart calls docked with its crew
			// still in transit, it made abort_stalled_dock() below unreachable, and it hid a
			// live race: complete_dock() is armed for warmup + 1s while the hull waits for the
			// next SSshuttle fire after setTimer(1 SECONDS), and which lands first is not
			// deterministic.
			//
			// Every dock in this fork starts from flight - the helm only offers docking in
			// OVERMAP_SHIP_FLYING, and both ship-to-ship paths dock two flying hulls into
			// empty space - so "no longer standing on a transit dock" is exactly "arrived".
			if(!shuttle_is_in_transit())
				var/obj/structure/overmap/docking_target = to_dock?.resolve()
				if(!docking_target) //Panic, somehow the docking target is gone but the shuttle has likely docked somewhere, get it out quickly
					state = OVERMAP_SHIP_FLYING
					shuttle.enterTransit()
					return

				if(istype(docking_target, /obj/structure/overmap/ship)) //hardcoded and bad
					var/obj/structure/overmap/ship/S = docking_target
					S.shuttle.shuttle_areas |= shuttle.shuttle_areas
					// Notify the target ship that we docked to them
					SEND_SIGNAL(S, COMSIG_VOIDCREW_SHIP_DOCKED_BY, src)
				// If docking to empty space, notify any other ships already docked there
				// This creates a ship-to-ship dock situation via shared empty space
				else if(istype(docking_target, /obj/structure/overmap/planet/empty))
					for(var/obj/structure/overmap/ship/other_ship in SSovermap.simulated_ships)
						if(other_ship == src)
							continue
						if(other_ship.docked == docking_target)
							// Another ship is already docked to this empty space - notify them
							SEND_SIGNAL(other_ship, COMSIG_VOIDCREW_SHIP_DOCKED_BY, src)
				forceMove(docking_target)
				state = OVERMAP_SHIP_IDLE
				// Start undock cooldown
				COOLDOWN_START(src, undock_cooldown, UNDOCK_COOLDOWN_TIME)
				SEND_SIGNAL(src, COMSIG_VOIDCREW_SHIP_DOCKED)
				// The counterpart to the "complete_dock UNDOCKING" line further down, whose
				// absence is why a round-4 strand could not be diagnosed from the logs at all:
				// 168 undock lines and not one for docking. The attempt count is the useful
				// part now that a dock can legitimately take more than one.
				log_shuttle("complete_dock DOCKING: [name] docked at [docking_target] after [attempt] attempt\s, hull on [shuttle.get_docked() || "NO DOCK"], mode=[shuttle.mode]")
			else
				// Still standing on the transit dock: SSshuttle has not moved the hull yet, or
				// cannot. check_transit_zone() refuses outright while the global transit budget
				// is spent and initiate_docking() can be refused by a blocked berth or the
				// port's own move lock, in which case check() just retries every 2 seconds.
				// Wait for the hull rather than declaring the dock finished without it - and
				// give up eventually, because "never" is one of the outcomes.
				if(attempt >= DOCK_MOVE_MAX_ATTEMPTS)
					abort_stalled_dock(to_dock?.resolve())
					return
				addtimer(CALLBACK(src, PROC_REF(complete_dock), to_dock, attempt + 1), 1 SECONDS)
				return
		if(OVERMAP_SHIP_UNDOCKING)
			// Get the location we're undocking from (passed via weakref from undock())
			var/obj/structure/overmap/old_docked_location = to_dock?.resolve()
			// The hull leaves under SSshuttle's power, not ours: complete_undock_warmup()
			// only sets the port to SHUTTLE_IGNITING, and it cannot move until
			// check_transit_zone() hands it a transit reservation - which takes at least
			// one SSshuttle fire, retries on a 2 second cadence, and is refused outright
			// while the global transit budget is spent. This branch used to fire one
			// second later regardless and walk the overmap token off the dock anyway,
			// stranding the hull (and its crew) inside the site it had just "left" while
			// the chart showed the ship flying. Confirm the move actually happened.
			// A site that vanished under us (null weakref) still takes the old path -
			// there is nothing left to stay docked to, so leaving is the lesser evil.
			if(!isnull(old_docked_location) && !shuttle_is_in_transit())
				if(attempt >= DOCK_MOVE_MAX_ATTEMPTS)
					abort_stalled_undock(old_docked_location)
					return
				addtimer(CALLBACK(src, PROC_REF(complete_dock), to_dock, attempt + 1), 1 SECONDS)
				return
			if(!isturf(loc))
				if(istype(loc, /obj/structure/overmap/ship)) //Even more hardcoded, even more bad
					var/obj/structure/overmap/ship/S = loc
					adjust_speed(S.speed[1], S.speed[2])
					// Notify the target ship that we undocked from them
					SEND_SIGNAL(S, COMSIG_VOIDCREW_SHIP_UNDOCKED_BY, src)
				var/turf/target_turf = get_turf(loc)
				log_shuttle("complete_dock UNDOCKING: Moving ship [src] from [loc] to turf [target_turf]")
				forceMove(target_turf)
			else
				log_shuttle("complete_dock UNDOCKING: Ship [src] already on turf [loc]")

			// Hand our areas back. complete_dock() used to do this only while we were still
			// inside the host's contents, so an undock that found us already on a turf left
			// the host holding our areas in its shuttle_areas forever. That list decides
			// what the host's shuttle moves carry (area/beforeShuttleMove() grants
			// MOVE_AREA from it) and what refresh_engines() treats as aboard, so stale
			// entries make the host claim our decks in every later move and teardown.
			// Removing areas that were never added is a no-op, so reconcile
			// unconditionally against the host.
			if(istype(old_docked_location, /obj/structure/overmap/ship))
				var/obj/structure/overmap/ship/old_host = old_docked_location
				if(old_host.shuttle && old_host.shuttle != shuttle)
					old_host.shuttle.shuttle_areas -= shuttle.shuttle_areas

			// Now that the ship has moved, clear dock flags on the old location
			// This must happen AFTER move but BEFORE unload_level check
			// Note: Both /obj/structure/overmap/dynamic and /obj/structure/overmap/planet have dock flags
			if(istype(old_docked_location, /obj/structure/overmap/dynamic))
				var/obj/structure/overmap/dynamic/dockable_place = old_docked_location
				if(dock_index == 1)
					dockable_place.first_dock_taken = FALSE
				else if(dock_index == 2)
					dockable_place.second_dock_taken = FALSE
				dock_index = 0
			else if(istype(old_docked_location, /obj/structure/overmap/planet))
				var/obj/structure/overmap/planet/planet_place = old_docked_location
				if(dock_index == 1)
					planet_place.first_dock_taken = FALSE
				else if(dock_index == 2)
					planet_place.second_dock_taken = FALSE
				dock_index = 0

			// Note: Empty space cleanup is now handled via COMSIG_VOIDCREW_SHIP_UNDOCKED signal
			// registered in /obj/structure/overmap/planet/empty/Entered()

			// If undocking from empty space, notify any other ships still docked there
			// This allows them to reactivate shields now that they're alone
			if(istype(old_docked_location, /obj/structure/overmap/planet/empty))
				for(var/obj/structure/overmap/ship/other_ship in SSovermap.simulated_ships)
					if(other_ship == src)
						continue
					if(other_ship.docked == old_docked_location)
						// Another ship is still docked to this empty space - notify them we left
						SEND_SIGNAL(other_ship, COMSIG_VOIDCREW_SHIP_UNDOCKED_BY, src)

			// Free the ship's hangar berth (the outpost itself never unloads, it's permanent)
			// (trader outposts and player outposts with a hangar elevator; no-op elsewhere)
			old_docked_location?.on_ship_undock_complete(src)

			// Handle space ruin dock flags and cleanup
			if(istype(old_docked_location, /obj/structure/overmap/space_ruin))
				var/obj/structure/overmap/space_ruin/ruin_place = old_docked_location
				if(dock_index == 1)
					ruin_place.first_dock_taken = FALSE
				else if(dock_index == 2)
					ruin_place.second_dock_taken = FALSE
				dock_index = 0
				// Start the cleanup grace after the departing ship has moved clear.
				addtimer(CALLBACK(ruin_place, TYPE_PROC_REF(/obj/structure/overmap/space_ruin, check_start_despawn)), 3 SECONDS)

			// Handle landable asteroid field (meteor storm) dock flags and cleanup - unlike
			// space ruins, the event itself never respawns/relocates, only its reservation frees up
			if(istype(old_docked_location, /obj/structure/overmap/event/meteor))
				var/obj/structure/overmap/event/meteor/field_place = old_docked_location
				if(dock_index == 1)
					field_place.first_dock_taken = FALSE
				else if(dock_index == 2)
					field_place.second_dock_taken = FALSE
				dock_index = 0
				// Check if we should unload the field (small delay to ensure ship is fully moved)
				addtimer(CALLBACK(field_place, TYPE_PROC_REF(/obj/structure/overmap/event/meteor, unload_level)), 0.5 SECONDS)

			// Always set state to FLYING when undocking completes
			state = OVERMAP_SHIP_FLYING
			undock_origin = null
			SEND_SIGNAL(src, COMSIG_VOIDCREW_SHIP_UNDOCKED)
			// Force refresh close_overmap_objects for all ships on this turf
			var/turf/our_turf = get_turf(src)
			if(our_turf)
				for(var/obj/structure/overmap/other in our_turf)
					if(other == src)
						continue
					LAZYOR(other.close_overmap_objects, src)
					LAZYOR(close_overmap_objects, other)
			//if(repair_timer)
				//deltimer(repair_timer)
			//addtimer(CALLBACK(src, TYPE_PROC_REF(/obj/structure/overmap/ship, tick_autopilot)), 5 SECONDS) //TODO: Improve this SOMEHOW
		else
			// complete_dock() is the only thing that can move a ship out of DOCKING or
			// UNDOCKING, and it is driven by one non-repeating timer per attempt. A callback
			// that lands in any other state is a sequence that ended somewhere it did not
			// announce, and it used to leave nothing behind at all - no log line, no runtime,
			// nothing to tell the strand apart from a dock that simply never started.
			log_shuttle("complete_dock: [name] fired in unexpected state [state] (to_dock=[to_dock?.resolve() || "gone"], attempt=[attempt]) - no action taken")
			stack_trace("complete_dock in state [state]")

	// With area-based mass tracking, no re-registration needed - areas persist through shuttle movement
	update_appearance(UPDATE_ICON_STATE)
	update_screen()

/// Human-readable name for the ship's current overmap state, for consoles that need to
/// explain why they are refusing input.
/obj/structure/overmap/ship/proc/get_state_readout()
	switch(state)
		if(OVERMAP_SHIP_DOCKING)
			return "docking sequence in progress"
		if(OVERMAP_SHIP_UNDOCKING)
			return "undocking sequence in progress"
		if(OVERMAP_SHIP_ACTING)
			return "plotting approach vector"
		if(OVERMAP_SHIP_IDLE)
			return "docked"
	return "underway"

/**
 * TRUE while the hull is physically parked on a transit dock - the state a voidcrew ship
 * is in whenever it is flying the overmap rather than sitting in somebody's berth.
 *
 * This is the honest "did the shuttle actually move?" test. The port's `mode` is not:
 * enterTransit() only warns when its initiate_docking() is refused, so a shuttle can
 * reach SHUTTLE_CALL with an infinite timer - open flight, as far as every mode check
 * goes - while its hull never left the dock it was standing on.
 */
/obj/structure/overmap/ship/proc/shuttle_is_in_transit()
	return istype(shuttle?.get_docked(), /obj/docking_port/stationary/transit)

/**
 * The hull could not leave the site we were undocking from before we ran out of retries.
 * Almost always because the shuttle never got a transit reservation (the global budget
 * is finite; see release_assigned_transit() for how it used to be leaked away).
 *
 * Put the ship back into the state it is physically in - still berthed - instead of
 * walking the overmap token off and leaving the crew inside a site the chart says they
 * left. The berth flags and dock_index were never cleared (that happens further down the
 * undock branch we bailed out of), so the berth is still ours and nothing needs reclaiming.
 */
/obj/structure/overmap/ship/proc/abort_stalled_undock(obj/structure/overmap/old_docked_location)
	var/stuck_mode = shuttle?.mode
	docked = old_docked_location // complete_undock_warmup() cleared this on the way out
	undock_origin = null
	state = OVERMAP_SHIP_IDLE
	// Leave the port in the resting state a docked shuttle sits in, rather than the
	// SHUTTLE_IGNITING it is stuck retrying from - otherwise the next undock's request()
	// lands on a port that thinks a launch is already in progress.
	if(shuttle)
		shuttle.mode = SHUTTLE_IDLE
		shuttle.destination = null
		shuttle.timer = 0
	log_shuttle("[name]: undock from [old_docked_location] ABORTED - shuttle never entered transit after [DOCK_MOVE_MAX_ATTEMPTS] seconds (mode=[stuck_mode], assigned_transit=[shuttle?.assigned_transit || "null"]). Ship restored to docked.")
	message_admins("\[SHUTTLE]: [display_name] failed to undock from [old_docked_location] - no transit space available. Ship left docked. [ADMIN_COORDJMP(shuttle?.loc)]")
	ship_notify(
		"UNDOCK FAILED: Bluespace corridor could not be established. Moorings still attached - try again shortly.",
		"UNDOCKING",
		SHIP_NOTIFY_WARNING,
		'voidcrew/sound/warn.ogg',
		25,
	)
	update_appearance(UPDATE_ICON_STATE)
	update_screen()

/**
 * Hands back whichever of a site's two berths we had claimed.
 *
 * The four dockable overmap types each declare their own first_dock_taken/second_dock_taken
 * rather than inheriting them, so this has to name them individually - update_docked_bools()
 * gets away with a single /obj/structure/overmap/dynamic cast only because DM resolves the
 * var by name at runtime, which quietly runtimes on any type that happens not to have it.
 */
/obj/structure/overmap/ship/proc/release_berth_flags(obj/structure/overmap/site)
	if(!dock_index)
		return
	if(!istype(site, /obj/structure/overmap/dynamic) \
		&& !istype(site, /obj/structure/overmap/planet) \
		&& !istype(site, /obj/structure/overmap/space_ruin) \
		&& !istype(site, /obj/structure/overmap/event/meteor))
		dock_index = 0
		return
	var/obj/structure/overmap/dynamic/berth = site // all four declare the same two vars
	if(dock_index == 1)
		berth.first_dock_taken = FALSE
	else if(dock_index == 2)
		berth.second_dock_taken = FALSE
	dock_index = 0

/**
 * Mirror of abort_stalled_undock() for a dock that never completed: the hull is still
 * flying, so give the berth back and hand the helm its flight controls again rather than
 * pinning `state` at DOCKING, which the console has no branch for at all.
 */
/obj/structure/overmap/ship/proc/abort_stalled_dock(obj/structure/overmap/docking_target)
	release_berth_flags(docking_target || docked)
	docked = null
	state = OVERMAP_SHIP_FLYING
	// Open flight for a voidcrew port is SHUTTLE_CALL with no destination and an infinite
	// timer (see /obj/docking_port/mobile/voidcrew/postregister) - the hull never left its
	// transit dock, so that is exactly where it still is.
	if(shuttle)
		shuttle.mode = SHUTTLE_CALL
		shuttle.destination = null
		shuttle.timer = INFINITY
	log_shuttle("[name]: dock to [docking_target || "unknown"] ABORTED - shuttle never completed its move after [DOCK_MOVE_MAX_ATTEMPTS] seconds (assigned_transit=[shuttle?.assigned_transit || "null"]). Ship restored to flight.")
	message_admins("\[SHUTTLE]: [display_name] failed to dock at [docking_target || "unknown"] - no transit space available. Ship left flying. [ADMIN_COORDJMP(shuttle?.loc)]")
	ship_notify(
		"DOCKING FAILED: Bluespace corridor could not be established. Holding position - try again shortly.",
		"DOCKING",
		SHIP_NOTIFY_WARNING,
		'voidcrew/sound/warn.ogg',
		25,
	)
	update_appearance(UPDATE_ICON_STATE)
	update_screen()

/**
 * Polled once a second by SSovermap for a manoeuvre that has stopped advancing.
 *
 * DOCKING, UNDOCKING and ACTING all grey out every helm ops control and the cargo console's
 * call button, and every exit from them runs on a one-shot timer or a one-shot signal:
 * complete_dock()'s retry chain, complete_dock_warmup(), on_planet_loaded(), and the
 * `acting.state = prev_state` restores at the bottom of each site's ship_act(). A runtime
 * anywhere in those unwinds the proc without arming the next step, and DM says nothing. The
 * ship is then pinned in a dead state for the rest of the round - the only exit today is an
 * admin editing `state` by hand.
 *
 * So this is a poll, not a timer: the failure being covered IS a lost callback, and a recovery
 * that depends on one is covering nothing. It is also driven off the state it observes rather
 * than a deadline stamped at each `state =` assignment, so a new assignment site cannot forget
 * to arm it - the cost is up to a second of lag against a 90 second timeout.
 *
 * Recovery reconciles against the hull's own docking port, which is the only honest source of
 * truth here (`state`, `docked` and `loc` are all bookkeeping that can and did drift from it).
 * Returns TRUE if it acted.
 */
/obj/structure/overmap/ship/proc/check_manoeuvre_stalled()
	if(state != OVERMAP_SHIP_DOCKING && state != OVERMAP_SHIP_UNDOCKING && state != OVERMAP_SHIP_ACTING)
		manoeuvre_watch_state = null
		manoeuvre_watch_since = 0
		return FALSE

	// First sighting, or a state that changed under us: start the clock. Every transition
	// between transitional states is progress by definition.
	if(manoeuvre_watch_state != state)
		manoeuvre_watch_state = state
		manoeuvre_watch_since = world.time
		return FALSE

	// Legal waits that outlast the timeout, held rather than counted. A destination still
	// generating its interior is progress, just slow (dock() parks in DOCKING on
	// COMSIG_VOIDCREW_PLANET_LOADED for exactly as long as that takes)...
	var/obj/structure/overmap/planet/loading_target = docked
	if(istype(loading_target) && loading_target.loading)
		manoeuvre_watch_since = world.time
		return FALSE
	// ...and ACTING with worldgen work active is a legal wait, not a stall. Legacy:
	// ship_act() used to hold ships in ACTING while their survey queued; surveys now
	// run in the background off request_site_load() and the ship never leaves FLYING.
	// This remains as a safety net for anything that still sets ACTING near a build.
	if(state == OVERMAP_SHIP_ACTING && (SSovermap.worldgen_owner || SSovermap.worldgen_queue_length()))
		manoeuvre_watch_since = world.time
		return FALSE

	if(world.time - manoeuvre_watch_since < MANOEUVRE_STALL_TIMEOUT)
		return FALSE

	var/stalled_for = world.time - manoeuvre_watch_since
	// Restart the clock before acting: a recovery can need a second pass (complete_dock()
	// spends up to DOCK_MOVE_MAX_ATTEMPTS before it gives up), and this must not re-fire on
	// every SSovermap fire while that runs.
	manoeuvre_watch_since = world.time

	log_shuttle("[name]: STRANDED in state [state] for [stalled_for / 10]s (loc=[loc], docked=[docked || "null"], \
		hull on [shuttle?.get_docked() || "NO DOCK"], mode=[shuttle?.mode]) - reconciling against the hull")
	message_admins("\[SHUTTLE]: [display_name] was stuck in [get_state_readout()] for [stalled_for / 10]s and is being resynchronised. [ADMIN_COORDJMP(shuttle?.loc)]")

	switch(state)
		if(OVERMAP_SHIP_ACTING)
			// Nothing has moved the hull in ACTING - a site sets it, loads, and hands over to
			// dock(), which sets DOCKING itself. Give the helm back. A site that does get
			// there late simply sets its own state again.
			state = OVERMAP_SHIP_FLYING
			ship_notify("Approach plot timed out - navigation control restored.", "NAVIGATION", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
			update_appearance(UPDATE_ICON_STATE)
			update_screen()
		if(OVERMAP_SHIP_DOCKING)
			if(shuttle_is_in_transit())
				// The hull never left flight, whatever the chart says.
				abort_stalled_dock(docked)
			else
				// The hull is berthed and only the paperwork is missing. Hand it to the branch
				// that does the paperwork, which now agrees with the hull.
				ship_notify("Docking computer desynchronised from the hull - resynchronising.", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
				INVOKE_ASYNC(src, PROC_REF(complete_dock), WEAKREF(docked))
		if(OVERMAP_SHIP_UNDOCKING)
			// complete_dock()'s UNDOCKING branch already tests transit and calls
			// abort_stalled_undock() on its own, so restarting the lost chain with the berth
			// we launched from is the whole recovery.
			INVOKE_ASYNC(src, PROC_REF(complete_dock), undock_origin)
	return TRUE

/**
 * Initializes uninitialized space turfs around the shuttle so they can be built on.
 * /turf/open/space/basic turfs skip initialization for performance, but that breaks interactions.
 */
/obj/structure/overmap/ship/proc/initialize_nearby_space_turfs()
	if(!shuttle)
		return

	var/ship_z = shuttle.z

	// Get ship boundaries from shuttle areas
	var/min_x = INFINITY
	var/min_y = INFINITY
	var/max_x = 0
	var/max_y = 0

	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
		for(var/turf/T in shuttle_area)
			if(T.z != ship_z)
				continue
			min_x = min(min_x, T.x)
			min_y = min(min_y, T.y)
			max_x = max(max_x, T.x)
			max_y = max(max_y, T.y)

	if(min_x == INFINITY)
		return

	// Expand boundaries by 5 tiles
	var/expanded_min_x = max(1, min_x - 5)
	var/expanded_min_y = max(1, min_y - 5)
	var/expanded_max_x = min(world.maxx, max_x + 5)
	var/expanded_max_y = min(world.maxy, max_y + 5)

	var/list/turfs_to_init = list()

	// Get all turfs in the expanded area and find uninitialized space turfs
	for(var/turf/open/space/S in block(locate(expanded_min_x, expanded_min_y, ship_z), locate(expanded_max_x, expanded_max_y, ship_z)))
		if(!(S.flags_1 & INITIALIZED_1))
			turfs_to_init += S

	if(length(turfs_to_init))
		SSatoms.InitializeAtoms(turfs_to_init)

#undef DOCK_MOVE_MAX_ATTEMPTS
#undef MANOEUVRE_STALL_TIMEOUT
#undef DOCK_WARMUP_TIME
#undef UNDOCK_WARMUP_TIME
#undef UNDOCK_COOLDOWN_TIME
