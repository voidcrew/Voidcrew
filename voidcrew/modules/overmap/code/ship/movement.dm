///
/// Flight.
///
/// Velocity, the burn/throttle loop and cruise governor, tile stepping
/// (tick_move), overmap wraparound, interior parallax theming for the crew and
/// the 10-second zone-boundary crossing.

/obj/structure/overmap/ship
	///Timer ID of the looping movement timer
	var/movement_callback_id

/obj/structure/overmap/ship
	///ONLY USED FOR NON-SIMULATED SHIPS. The amount per burn that this ship accelerates
	var/acceleration_speed = 0.02

/obj/structure/overmap/ship
	///Max possible speed (1 tile per second)
	var/static/max_speed = 1/(1 SECONDS)
	///Minimum speed. Any lower is rounded down. (0.5 tiles per minute)
	var/static/min_speed = 1/(2 MINUTES)
	///The current speed in x/y direction in grid squares per minute
	var/list/speed[2]
	///Vessel estimated thrust
	var/est_thrust
	///Average fuel fullness percentage
	var/avg_fuel_amnt = 100
	/// The direction currently being burned (0 = none, direction = thrust, -1 = active braking)
	var/burn_direction = 0
	/// Both the engine burn intensity (1-100) and the cruise-speed target as a
	/// percentage of max_speed, one throttle for how hard to burn and how fast
	/// to end up going. 100 = flat out.
	var/burn_percentage = 100
	/// The course the pilot has commanded via the helm (dir bits), independent of
	/// burn_direction: it persists while the engines coast at cruise, and
	/// BURN_NONE means no course is held. Never holds BURN_STOP.
	var/commanded_course = BURN_NONE
	/// Course latched when a zone transition seizes the ship, re-commanded when
	/// the crossing completes so a hand-flown hull doesn't come out the far side
	/// dead in space.
	var/zone_resume_burn = BURN_NONE
	/// Whether we're currently registered with SSfastprocess for thrust
	var/thrust_processing = FALSE

/obj/structure/overmap/ship
	// ===== ZONE TRANSITION =====
	/// Whether we're currently transitioning between zones (10 second delay)
	var/zone_transitioning = FALSE
	/// Timer ID for zone transition completion
	var/zone_transition_timer
	/// The target turf we're trying to transition to
	var/turf/zone_transition_target
	/// When the zone transition started (for progress calculation)
	var/zone_transition_start_time

/obj/structure/overmap/ship
	/// Rate limit on the "engines producing no thrust" crew warning
	COOLDOWN_DECLARE(no_thrust_warning)

/obj/structure/overmap/ship/proc/adjust_speed(n_x, n_y)
	var/offset = 1
	if(movement_callback_id)
		var/magnitude = MAGNITUDE(speed[1], speed[2])
		if(magnitude > 0)
			var/previous_time = 1 / magnitude
			offset = timeleft(movement_callback_id) / previous_time
		deltimer(movement_callback_id)
		movement_callback_id = null //just in case

	speed[1] += n_x
	speed[2] += n_y

	// Hard ceiling on velocity: the burn loop integrates thrust every 0.2s with no
	// other bound, so light hulls (the pill masses 4 turfs) would otherwise sail to
	// several times max_speed. Scaling both axes by the same positive factor keeps
	// the heading, tick_move() only reads the SIGNs.
	var/new_magnitude = MAGNITUDE(speed[1], speed[2])
	if(new_magnitude > max_speed)
		var/rescale = max_speed / new_magnitude
		speed[1] *= rescale
		speed[2] *= rescale

	update_icon_state()
	update_flight_parallax()

	if(QDELETED(src))
		return

	if(is_still() || movement_callback_id)
		// Coming to a stop is a change the chart has to hear about too, or it keeps
		// gliding the token toward a tile the ship is no longer heading for.
		push_helm_frame()
		return

	var/timer = 1 / MAGNITUDE(speed[1], speed[2]) * offset
	movement_callback_id = addtimer(CALLBACK(src, PROC_REF(tick_move)), timer, TIMER_STOPPABLE)
	// The chart glides over exactly get_move_interval(), which this call has just
	// rewritten. Push it now rather than letting the console wait for the next tile
	// crossing: otherwise a throttle change keeps interpolating at the old rate and
	// the ship visibly snaps forward when it arrives early.
	push_helm_frame()

/**
  * Called by /proc/adjust_speed(), this continually moves the ship according to it's speed
  */
/obj/structure/overmap/ship/proc/tick_move()
	if(is_still() || QDELETED(src))
		deltimer(movement_callback_id)
		movement_callback_id = null
		return

	var/new_x = overmap_wrap_x(x + SIGN(speed[1]))
	var/new_y = overmap_wrap_y(y + SIGN(speed[2]))
	var/turf/newloc = locate(new_x, new_y, z)
	if(autopilot_engaged && !autopilot_can_enter(newloc))
		full_stop()
		autopilot_path = null
		autopilot_steer()
		return

	// The crossing is enforced here, on the step that actually leaves the zone.
	//
	// burn_engines() has its own copy of this check, but it only runs while the
	// engines are lit, and the ordinary way to fly is to burn up to speed and
	// then coast, at which point burn_direction is BURN_NONE, process() stops
	// calling burn_engines() at all, and nothing was left watching where the
	// ship went. Every coasting hull crossed zone lines for free, and the
	// autopilot did it every time: autopilot_steer() deliberately drops the burn
	// once it is up to cruise and pointed the right way, so its normal cruise is
	// exactly the state the old gate couldn't see.
	//
	// start_zone_transition() cuts the velocity and kills the movement timer
	// itself, so there is nothing left to reschedule on this path.
	var/datum/overmap_zone/crossing = zone_crossing(get_turf(src), newloc)
	if(crossing)
		start_zone_transition(newloc, crossing)
		update_screen()
		push_helm_frame()
		return

	if(newloc)
		forceMove(newloc)
		check_hazards()

	reschedule_movement()
	update_screen()
	push_helm_frame()
	// One tile crossed is one steering decision. There is no sub-tile position to
	// steer with in between (see autopilot.dm).
	if(autopilot_engaged)
		autopilot_steer()

/**
  * Deciseconds the ship takes to cross one overmap tile at its current speed, or
  * 0 when it isn't moving. Single source of truth for both the movement timer and
  * the interval the helm chart glides its token over, so the two can't drift.
  */
/obj/structure/overmap/ship/proc/get_move_interval()
	var/current_speed = MAGNITUDE(speed[1], speed[2])
	if(!current_speed)
		return 0

	// Apply speed multiplier as hard cap (for interdiction effects)
	if(speed_multiplier < SHIP_SPEED_MULTIPLIER_DEFAULT)
		current_speed *= speed_multiplier

	return 1 / current_speed

/**
  * Helper proc to reschedule the movement timer
  */
/obj/structure/overmap/ship/proc/reschedule_movement()
	if(movement_callback_id)
		deltimer(movement_callback_id)

	var/timer = get_move_interval()
	if(!timer)
		return

	movement_callback_id = addtimer(CALLBACK(src, PROC_REF(tick_move)), timer, TIMER_STOPPABLE)

/**
 * Keeps the interior space parallax scrolling to match the ship's overmap heading
 * while it flies through transit space.
 *
 * Only acts while the shuttle interior is parked at its transit dock (i.e. the ship
 * is in flight); docked/landed interiors keep upstream behavior (no scroll). The
 * current scroll direction is kept as long as it still describes our motion, which
 * avoids direction flip-flopping during diagonal burns; a fresh direction is picked
 * from the dominant velocity axis otherwise. A still ship (no speed on either axis)
 * gets NONE, which makes set_parallax_movedir() ease the scroll to a stop, no
 * thrust means no drifting stars.
 */
/obj/structure/overmap/ship/proc/update_flight_parallax()
	if(!shuttle)
		return
	if(!istype(shuttle.get_docked(), /obj/docking_port/stationary/transit))
		return

	// Ground truth for what's currently applied. Any shuttle area will do
	var/current_dir = NONE
	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
		current_dir = shuttle_area.parallax_movedir
		break

	// Keep the current direction while it still matches our motion on that axis
	if(current_dir && !is_still())
		var/current_component = (current_dir & (EAST|WEST)) ? speed[1] : speed[2]
		if((current_dir & (NORTH|EAST)) ? (current_component > 0) : (current_component < 0))
			return

	// No thrust, no drift: a still ship stops the starfield (NONE = upstream ease-out)
	var/new_dir = NONE
	if(speed[1] && abs(speed[1]) >= abs(speed[2]))
		new_dir = speed[1] > 0 ? EAST : WEST
	else if(speed[2])
		new_dir = speed[2] > 0 ? NORTH : SOUTH

	if(new_dir == current_dir)
		return

	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
		shuttle_area.parallax_movedir = new_dir
	if(shuttle.assigned_transit?.assigned_area)
		shuttle.assigned_transit.assigned_area.parallax_movedir = new_dir

	// Poke every client aboard so their parallax picks up the new direction
	for(var/turf/shuttle_turf as anything in shuttle.return_ordered_turfs(shuttle.x, shuttle.y, shuttle.z, shuttle.dir))
		if(!shuttle_turf || !istype(shuttle_turf.loc, shuttle.area_type))
			continue
		for(var/atom/movable/movable as anything in shuttle_turf)
			if(movable.client_mobs_in_contents)
				movable.update_parallax_contents()

// ===== CONTEXT-AWARE PARALLAX (see _overmap.dm for the system overview) =====

/**
 * The overmap object theming this ship's exterior view right now: whatever we're
 * docked to (following carrier ships to THEIR context), else the first themed
 * object sharing our overmap tile. Null = plain space.
 */
/obj/structure/overmap/ship/proc/get_parallax_source()
	if(docked)
		if(istype(docked, /obj/structure/overmap/ship))
			var/obj/structure/overmap/ship/carrier = docked
			if(carrier == src) // should be impossible, but never recurse into ourselves
				return null
			return carrier.get_parallax_source()
		return docked.parallax_theme ? docked : null
	var/turf/tile = loc
	if(!istype(tile, /turf/open/overmap))
		return null
	for(var/obj/structure/overmap/object in tile)
		if(object == src || !object.parallax_theme)
			continue
		return object
	return null

/// Overmap token moved: record zone crossings and refresh the crew's parallax.
/obj/structure/overmap/ship/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	var/old_zone_type = SSovermap_zones?.get_zone_type(get_turf(old_loc))
	. = ..()
	log_zone_crossing(old_zone_type, SSovermap_zones?.get_zone_type(get_turf(src)))
	update_crew_parallax_context()

/**
 * Re-resolves the ship's parallax context and re-themes every client aboard if it
 * changed. Cheap no-op while the context is stable, so it's safe to call from every
 * token move. Also forwards to ships docked to us, so a carrier flying into a nebula
 * updates its passengers' crews too.
 */
/obj/structure/overmap/ship/proc/update_crew_parallax_context()
	if(!shuttle)
		return
	var/obj/structure/overmap/source = get_parallax_source()
	var/new_key = source ? "[source.parallax_theme]-[REF(source)]" : null
	if(new_key != parallax_context_key)
		parallax_context_key = new_key
		// Same crew-enumeration pattern as update_flight_parallax()
		for(var/turf/shuttle_turf as anything in shuttle.return_ordered_turfs(shuttle.x, shuttle.y, shuttle.z, shuttle.dir))
			if(!shuttle_turf || !istype(shuttle_turf.loc, shuttle.area_type))
				continue
			for(var/atom/movable/movable as anything in shuttle_turf)
				if(!movable.client_mobs_in_contents)
					continue
				for(var/mob/client_mob as anything in movable.client_mobs_in_contents)
					if(client_mob?.hud_used)
						client_mob.hud_used.update_overmap_parallax(client_mob)
	// Ships docked to us live in our contents and see whatever we see
	for(var/obj/structure/overmap/ship/rider in contents)
		rider.update_crew_parallax_context()

// ===== ZONE TRANSITION PROCS =====

/**
  * The zone `target` belongs to, but only when stepping onto it from `origin` is
  * actually a change of zone. Null for a step within one zone, for a tile with no
  * zone, and before SSovermap_zones is up.
  *
  * Shared by the two places a crossing can happen, ordering a burn towards a
  * boundary, and the tile step that carries the ship over one, so the two can't
  * disagree about what counts as leaving a zone.
  */
/obj/structure/overmap/ship/proc/zone_crossing(turf/origin, turf/target)
	if(!SSovermap_zones?.initialized || !origin || !target)
		return null
	var/datum/overmap_zone/from_zone = SSovermap_zones.get_zone(origin)
	var/datum/overmap_zone/to_zone = SSovermap_zones.get_zone(target)
	if(!from_zone || !to_zone || from_zone.zone_type == to_zone.zone_type)
		return null
	return to_zone

/**
  * Starts a zone transition - ship must wait 10 seconds before crossing into a new zone.
  * Engines are cut and ship stops during transition.
  * * target - The turf we're trying to move to
  * * target_zone - The zone datum of the target turf
  */
/obj/structure/overmap/ship/proc/start_zone_transition(turf/target, datum/overmap_zone/target_zone)
	if(zone_transitioning)
		return

	if(autopilot_engaged && !autopilot_can_enter(target))
		full_stop()
		autopilot_path = null
		schedule_autopilot_poll()
		return

	zone_transitioning = TRUE
	zone_transition_target = target
	zone_transition_start_time = world.time

	// Latch the course to re-command on the far side, while the velocity still
	// exists to read. A braking ship asked to stop - honor it. A commanded ship
	// gets its course back; a hand-flown coasting hull resumes the course its
	// velocity was carrying, or it comes out the far side dead in space. The
	// autopilot never uses the latch: its poll re-steers by itself.
	if(burn_direction == BURN_STOP)
		zone_resume_burn = BURN_NONE
	else
		zone_resume_burn = commanded_course || get_heading()
	commanded_course = BURN_NONE

	// Clear thrust when entering zone transition
	burn_direction = BURN_NONE
	thrust_processing = FALSE
	update_ship_processing()

	// Stop the ship - cut engines
	decelerate(max_speed)

	// Cancel any movement timer
	if(movement_callback_id)
		deltimer(movement_callback_id)
		movement_callback_id = null

	// Rotate ship to face the target zone
	var/transition_dir = get_dir(src, target)
	if(transition_dir)
		dir = transition_dir
		// Show moving icon during transition
		icon_state = "[base_icon_state]_moving"

	// Announce to ship
	ship_notify("Entering [target_zone.name]. Zone transition in progress - [ZONE_TRANSITION_TIME / 10] seconds.", "ZONE TRANSITION", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	// ...and, if this crew has nothing to meet the far side with, say so while
	// the crossing can still be cancelled (voidcrew/modules/onboarding)
	warn_zone_unprepared(target_zone)

	// Signal that zone transition has started (used by pirate AI to cancel hails)
	SEND_SIGNAL(src, COMSIG_VOIDCREW_SHIP_ZONE_TRANSITION_START, target_zone)

	// Start completion timer
	zone_transition_timer = addtimer(CALLBACK(src, PROC_REF(complete_zone_transition)), ZONE_TRANSITION_TIME, TIMER_STOPPABLE)

/**
  * Completes the zone transition - ship moves into the new zone.
  */
/obj/structure/overmap/ship/proc/complete_zone_transition()
	if(!zone_transitioning || !zone_transition_target)
		return

	var/turf/target = zone_transition_target

	// Clear transition state
	zone_transitioning = FALSE
	zone_transition_target = null
	zone_transition_start_time = null
	zone_transition_timer = null

	// The weather or allowed zones may have changed during the crossing delay.
	if(autopilot_engaged && !autopilot_can_enter(target))
		zone_resume_burn = BURN_NONE
		full_stop()
		autopilot_path = null
		autopilot_steer()
		return

	// Actually move to the target turf
	if(target && !QDELETED(src))
		forceMove(target)
		check_hazards()
		// Re-command the course the crossing latched, so a hand-flown hull
		// carries on across the boundary the way an autopilot one does.
		// Autopilot ships skip this: autopilot_steer()'s poll picks the course
		// back up itself.
		if(zone_resume_burn != BURN_NONE && !autopilot_engaged && state == OVERMAP_SHIP_FLYING && can_thrust())
			command_course(zone_resume_burn)
			ship_notify("Zone transition complete. Resuming course.", "ZONE TRANSITION", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		else
			ship_notify("Zone transition complete.", "ZONE TRANSITION", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		update_icon_state()
		update_screen()
	zone_resume_burn = BURN_NONE

/**
  * Cancels the zone transition - player pressed stop.
  */
/obj/structure/overmap/ship/proc/cancel_zone_transition()
	if(!zone_transitioning)
		return

	// Cancel the timer
	if(zone_transition_timer)
		deltimer(zone_transition_timer)
		zone_transition_timer = null

	// Clear transition state
	zone_transitioning = FALSE
	zone_transition_target = null
	zone_transition_start_time = null
	// The crew pulled out of the crossing; nothing to resume on a far side we
	// are no longer going to
	zone_resume_burn = BURN_NONE

	// Reset icon to stationary
	update_icon_state()

	ship_notify("Zone transition cancelled.", "ZONE TRANSITION", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

/**
  * Returns whether or not the ship is moving in any direction.
  */
/obj/structure/overmap/ship/proc/is_still()
	return !speed[1] && !speed[2]

/**
  * Calculates the average fuel fullness of all engines.
  */
/obj/structure/overmap/ship/proc/calculate_avg_fuel()
	if(!shuttle)
		avg_fuel_amnt = 0
		return
	var/fuel_avg = 0
	var/engine_amnt = 0
	for(var/obj/machinery/power/shuttle_engine/ship/E in shuttle.engine_list)
		if(!E.enabled || E.thruster_active == 0)
			continue
		var/fuel_cap = E.return_fuel_cap()
		if(!fuel_cap) //no (or zero) capacity reported - can't divide by it
			continue
		fuel_avg += clamp(E.return_fuel() / fuel_cap, 0, 1)
		engine_amnt++
	if(!engine_amnt || !fuel_avg)
		avg_fuel_amnt = 0
		return
	avg_fuel_amnt = round(fuel_avg / engine_amnt * 100)

///Returns TRUE if the ship has at least one working engine with fuel available.
/obj/structure/overmap/ship/proc/can_thrust()
	if(!shuttle)
		return FALSE
	// Can't thrust while hidden in a nebula
	if(hidden_in_nebula)
		return FALSE
	refresh_engines()
	for(var/obj/machinery/power/shuttle_engine/ship/engine in shuttle.engine_list)
		if(!engine.enabled || !engine.thruster_active)
			continue
		var/fuel = engine.return_fuel()
		var/fuel_cap = engine.return_fuel_cap()
		if(fuel > 0 || !fuel_cap)
			return TRUE
	return FALSE

/**
  * Returns the total speed in all directions.
  *
  * The equation for acceleration is as follows:
  * 60 SECONDS / (1 / ([ship's speed] / ([ship's mass] * 100)))
  */
/obj/structure/overmap/ship/proc/get_speed()
	if(is_still())
		return 0
	return 60 SECONDS / (1 / MAGNITUDE(speed[1], speed[2])) //It's per minute, which is 60 seconds

/**
  * Returns the direction the ship is moving in terms of dirs
  */
/obj/structure/overmap/ship/proc/get_heading()
	var/direction = 0
	if(speed[1])
		if(speed[1] > 0)
			direction |= EAST
		else
			direction |= WEST
	if(speed[2])
		if(speed[2] > 0)
			direction |= NORTH
		else
			direction |= SOUTH
	return direction

/**
  * Returns the estimated time in deciseconds to the next tile at current speed, or approx. time until reaching the destination when on autopilot
  */
/obj/structure/overmap/ship/proc/get_eta()

	. += timeleft(movement_callback_id)
	if(!.)
		return "--:--"
	. /= 10 //they're in deciseconds
	return "[add_leading(num2text((. / 60) % 60), 2, "0")]:[add_leading(num2text(. % 60), 2, "0")]"

/**
  * Change the speed in a specified dir.
  * * direction - dir to accelerate in (NORTH, SOUTH, SOUTHEAST, etc.)
  * * acceleration - How much to accelerate by
  */
/obj/structure/overmap/ship/proc/accelerate(direction, acceleration)
	var/heading = get_heading()
	if(!(direction in GLOB.cardinals))
		acceleration *= 0.5 //Makes it so going diagonally isn't 2x as efficient
	if(heading && (direction & REVERSE_DIR(heading))) //This is so if you burn in the opposite direction you're moving, you can actually reach zero
		if(EWCOMPONENT(direction))
			acceleration = min(acceleration, abs(speed[1]))
		else
			acceleration = min(acceleration, abs(speed[2]))
	if(direction & EAST)
		adjust_speed(acceleration, 0)
	if(direction & WEST)
		adjust_speed(-acceleration, 0)
	if(direction & NORTH)
		adjust_speed(0, acceleration)
	if(direction & SOUTH)
		adjust_speed(0, -acceleration)

/**
  * Reduce the speed or stop in all directions.
  * * acceleration - How much to decelerate by
  */
/obj/structure/overmap/ship/proc/decelerate(acceleration)
	if(speed[1] && speed[2]) //another check to make sure that deceleration isn't 2x as fast when moving diagonally
		adjust_speed(-SIGN(speed[1]) * min(acceleration * 0.5, abs(speed[1])), -SIGN(speed[2]) * min(acceleration * 0.5, abs(speed[2])))
	else if(speed[1])
		adjust_speed(-SIGN(speed[1]) * min(acceleration, abs(speed[1])), 0)
	else if(speed[2])
		adjust_speed(0, -SIGN(speed[2]) * min(acceleration, abs(speed[2])))

/**
 * Kills all velocity in one call, rather than shedding it a tick at a time.
 *
 * The same thing `decelerate(max_speed)` already does at the dock, on undock and
 * on a zone transition, given a name so the autopilot can ask for it directly.
 *
 * Routed through adjust_speed() rather than writing `speed` so the movement timer,
 * the flight parallax and the helm chart all hear about it, the chart in
 * particular keeps gliding its token toward a tile the ship is no longer heading
 * for otherwise.
 */
/obj/structure/overmap/ship/proc/full_stop()
	// Cleared before the early return below: a still ship can be holding a stale
	// course, and "full stop" has to kill the course too or the rose stays lit.
	commanded_course = BURN_NONE
	if(burn_direction != BURN_NONE)
		change_heading(BURN_NONE)
	if(is_still())
		return
	adjust_speed(-speed[1], -speed[2])

/**
 * Zeroes one or both axes of the velocity and leaves the other alone.
 *
 * What a turn actually needs. tick_move() steps by the SIGN of each axis, so
 * changing course is a matter of getting the two signs right rather than of
 * shedding speed, and an axis already carrying the ship the right way should keep
 * every bit of the speed it has instead of being braked along with the bad one.
 */
/obj/structure/overmap/ship/proc/kill_drift(kill_x = FALSE, kill_y = FALSE)
	if(!kill_x && !kill_y)
		return
	adjust_speed(kill_x ? -speed[1] : 0, kill_y ? -speed[2] : 0)

/**
 * Trims the velocity to a magnitude ceiling, keeping its direction.
 *
 * Scaling both axes by the same factor is what preserves the heading: tick_move()
 * reads the SIGNS, and scaling by a positive factor cannot change one.
 */
/obj/structure/overmap/ship/proc/clamp_speed(ceiling)
	var/magnitude = MAGNITUDE(speed[1], speed[2])
	if(!magnitude || magnitude <= ceiling)
		return
	var/scale = ceiling / magnitude
	adjust_speed(speed[1] * (scale - 1), speed[2] * (scale - 1))

/obj/structure/overmap/ship/Bump(atom/A)
/*
	if(istype(A, /turf/open/overmap/edge))
		handle_wraparound()
	..()
	*/

/**
  * Check if the ship is flying into the border of the overmap.
  */
/obj/structure/overmap/ship/proc/handle_wraparound()
	var/nx = x
	var/ny = y
	var/low_edge = 2
	var/high_edge = SSovermap.size - 1

	if((dir & WEST) && x == low_edge)
		nx = high_edge
	else if((dir & EAST) && x == high_edge)
		nx = low_edge
	if((dir & SOUTH)  && y == low_edge)
		ny = high_edge
	else if((dir & NORTH) && y == high_edge)
		ny = low_edge
	if((x == nx) && (y == ny))
		return //we're not flying off anywhere

	var/turf/T = locate(nx,ny,z)
	if(T)
		forceMove(T)

/**
 * Burns the engines in one direction, accelerating in that direction.
 * Unsimulated ships use the acceleration_speed var, simulated ships check eacch engine's thrust and fuel.
 * If no dir variable is provided, it decelerates the vessel.
 * * n_dir - The direction to move in
 * * percentage - Throttle percentage (1-100)
 * * burn_seconds - How many seconds of burn this call represents (fuel costs are per second of full burn)
 */
/obj/structure/overmap/ship/proc/burn_engines(n_dir = null, percentage = 100, burn_seconds = 1)
	if(state != OVERMAP_SHIP_FLYING)
		return

	// Can't thrust while transitioning zones
	if(zone_transitioning)
		return

	SEND_SIGNAL(src, COMSIG_VOIDCREW_SHIP_MOVED)

	// Clear any pending dock requests when moving
	if(pending_dock)
		clear_pending_dock()
		ship_notify("Docking request cancelled due to ship movement.", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

	// Decelerate without using fuel
	if(!n_dir)
		decelerate(acceleration_speed * (percentage / 100))
		return

	// Manual burns retain the early crossing shortcut. Autopilot turns can burn
	// just one missing axis: that is not its course, so only tick_move() may
	// choose the crossing tile for an automated ship.
	if(!autopilot_engaged)
		var/target_x = overmap_wrap_x(x + ((n_dir & EAST) ? 1 : 0) - ((n_dir & WEST) ? 1 : 0))
		var/target_y = overmap_wrap_y(y + ((n_dir & NORTH) ? 1 : 0) - ((n_dir & SOUTH) ? 1 : 0))
		var/turf/target_turf = locate(target_x, target_y, z)
		var/datum/overmap_zone/crossing = zone_crossing(get_turf(src), target_turf)
		if(crossing)
			start_zone_transition(target_turf, crossing)
			return

	var/thrust_used = 0 //The amount of thrust that the engines will provide with one burn
	refresh_engines()

	if(!shuttle)
		return

	if(!mass)
		calculate_mass()
	calculate_avg_fuel()

	for(var/obj/machinery/power/shuttle_engine/ship/E in shuttle.engine_list)
		if(!E.enabled || E.thruster_active == 0)
			continue
		thrust_used += E.burn_engine(percentage, mass, burn_seconds)
	est_thrust = thrust_used //cheeky way of rechecking the thrust, check it every time it's used

	// No thrust means no movement - engines need fuel/power to work
	if(thrust_used <= 0)
		warn_no_thrust()
		return

	thrust_used = thrust_used / max(mass * 100, 1) //do not know why this minimum check is here, but I clearly ran into an issue here before

	// Apply speed multiplier (for effects like interdiction)
	thrust_used *= speed_multiplier

	if(n_dir)
		accelerate(n_dir, thrust_used)

/**
 * Rate-limited crew warning for burn attempts that produce nothing (dead power grid,
 * disabled/damaged engines, empty fuel). Without it the failure is silent: an ion
 * engine's helm gauge reads stored SMES charge, but burns draw live wire power, so
 * the display can sit at 100% while the ship refuses to move.
 */
/obj/structure/overmap/ship/proc/warn_no_thrust()
	if(!COOLDOWN_FINISHED(src, no_thrust_warning))
		return
	COOLDOWN_START(src, no_thrust_warning, 15 SECONDS)
	ship_notify("Engines are producing no thrust! Check engine power, fuel, and status.", "ENGINES", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

/**
 * Changes the burn direction for continuous thrust.
 * Call with a direction to start thrusting, BURN_STOP to actively brake, or BURN_NONE to stop.
 * Uses SSfastprocess (0.2s ticks) for responsive controls.
 * * direction - The direction to burn in, or BURN_STOP/BURN_NONE
 */
/obj/structure/overmap/ship/proc/change_heading(direction)
	burn_direction = direction
	if(burn_direction != BURN_NONE)
		thrust_processing = TRUE
	update_ship_processing()

/// Cruise-speed ceiling the fly-by-wire layer holds, set by the throttle.
/obj/structure/overmap/ship/proc/cruise_target_speed()
	return max_speed * burn_percentage / 100

/**
 * The fly-by-wire entry point every manual control routes through: the pilot
 * commands a COURSE, and the ship works out what the engines owe it.
 *
 * tick_move() reads only the SIGNS of the velocity, so a turn is two different
 * jobs: zero the axis carrying the ship the wrong way, and burn up the axis
 * still missing. Both are done here with the same primitives the autopilot
 * steers with (autopilot_aim_drift()) - deliberate parity rather than a cheat,
 * so a hand-flown hull turns exactly as well as an automated one and no better.
 *
 * The course outlives the burn. Once every commanded axis is moving the right
 * way and the throttle's cruise target is met, the engines go cold and the ship
 * coasts - commanded_course stays set, which is what the helm's compass rose
 * lights from, and check_cruise() is what gets a running burn there.
 *
 * BURN_NONE and BURN_STOP drop the course and pass straight through to
 * change_heading(): coasting and braking are engine states, not courses.
 */
/obj/structure/overmap/ship/proc/command_course(direction)
	if(direction == BURN_NONE || direction == BURN_STOP)
		commanded_course = BURN_NONE
		change_heading(direction)
		push_helm_frame()
		return
	if(state != OVERMAP_SHIP_FLYING || zone_transitioning)
		return

	commanded_course = direction
	// Where the velocity has to point, axis by axis - the same pattern
	// autopilot_steer() uses.
	var/want_x = ((direction & EAST) ? 1 : 0) - ((direction & WEST) ? 1 : 0)
	var/want_y = ((direction & NORTH) ? 1 : 0) - ((direction & SOUTH) ? 1 : 0)
	var/burn = autopilot_aim_drift(want_x, want_y)
	if(burn)
		// Burn only the axes still missing, exactly as the autopilot does.
		change_heading(burn)
	else
		// Drift already serves every commanded axis. Trim to the cruise target
		// if the ship came in hot, top up if it came in slow, coast if it's there.
		// Same 0.1% tolerance as check_cruise(), so a ship already sitting at
		// cruise isn't sent back to the engines over a float rounding.
		clamp_speed(cruise_target_speed())
		if(MAGNITUDE(speed[1], speed[2]) < cruise_target_speed() * 0.999)
			change_heading(direction)
		else
			change_heading(BURN_NONE)
	// The rose lights from commanded_course; without a push the console waits
	// for the next tile crossing to hear about it.
	push_helm_frame()

/**
 * The cruise governor, run every thrust tick from process().
 *
 * A burn integrates thrust every 0.2s with nothing else watching it, so this is
 * what turns "hold the button" into "reach the commanded speed and coast": the
 * moment every commanded axis is moving the right way and the throttle's target
 * is met, the engines are cut and the course rides on velocity alone. It is
 * also why holding a course no longer burns fuel forever at the speed cap.
 */
/obj/structure/overmap/ship/proc/check_cruise()
	if(commanded_course == BURN_NONE || burn_direction == BURN_NONE || burn_direction == BURN_STOP)
		return
	var/want_x = ((commanded_course & EAST) ? 1 : 0) - ((commanded_course & WEST) ? 1 : 0)
	var/want_y = ((commanded_course & NORTH) ? 1 : 0) - ((commanded_course & SOUTH) ? 1 : 0)
	// Still turning: an axis isn't carrying the ship the commanded way yet.
	if(want_x && SIGN(speed[1]) != want_x)
		return
	if(want_y && SIGN(speed[2]) != want_y)
		return
	// 0.1% under the target counts as arrived. adjust_speed()'s cap rescales the
	// vector through single-precision floats, so demanding the exact ceiling can
	// park the magnitude one rounding step under max_speed with the burn never
	// going cold - the precise forever-burn this governor exists to end.
	if(MAGNITUDE(speed[1], speed[2]) < cruise_target_speed() * 0.999)
		return
	// Up to speed and pointed right: trim off what the last tick overshot by and
	// go cold. commanded_course stays set - that IS the cruise state.
	clamp_speed(cruise_target_speed())
	change_heading(BURN_NONE)
	push_helm_frame()
