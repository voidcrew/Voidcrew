/**
 * Autopilot finds the quickest safe course on the wrapping overmap, then follows
 * it with normal engine thrust. Hazards are walls; the only crew preferences
 * are which zones may be entered. A valid course is kept until it is obstructed,
 * the ship leaves it, or the crew changes the destination or allowed zones.
 *
 * Navigation has private map knowledge. It never charts contacts, changes sensor
 * discoveries, or sends the route/route length to a client. Sight still belongs
 * to the crew's sensors. Manual flight and combat interrupts retain control.
 */
#define AUTOPILOT_MAX_EXPANSIONS 6000
#define AUTOPILOT_POLL_INTERVAL (2 SECONDS)
#define AUTOPILOT_BURN_POLL (0.2 SECONDS)
#define OVERMAP_PATH_LOW_X (OVERMAP_LEFT_SIDE_COORD + 1)
#define OVERMAP_PATH_HIGH_X (OVERMAP_RIGHT_SIDE_COORD - 1)
#define OVERMAP_PATH_LOW_Y (OVERMAP_SOUTH_SIDE_COORD + 1)
#define OVERMAP_PATH_HIGH_Y (OVERMAP_NORTH_SIDE_COORD - 1)
#define OVERMAP_PATH_SPAN_X (OVERMAP_PATH_HIGH_X - OVERMAP_PATH_LOW_X + 1)
#define OVERMAP_PATH_SPAN_Y (OVERMAP_PATH_HIGH_Y - OVERMAP_PATH_LOW_Y + 1)

/obj/structure/overmap/ship
	var/autopilot_engaged = FALSE
	/// Absolute overmap coordinates supplied by the crew.
	var/autopilot_dest_x
	var/autopilot_dest_y
	var/autopilot_label
	/// Private remaining course, next tile first.
	var/list/autopilot_path
	var/autopilot_poll_timer
	/// Last immutable maps against which the remaining course was checked.
	var/list/autopilot_checked_danger
	var/list/autopilot_checked_zones
	var/autopilot_status
	var/datum/weakref/autopilot_dock_ref
	var/datum/weakref/autopilot_user_ref
	var/autopilot_allow_neutral = TRUE
	var/autopilot_allow_contested = TRUE
	var/autopilot_allow_lawless = TRUE

/datum/controller/subsystem/overmap
	/// Registry includes dynamically created hazards, not just roundstart events.
	var/list/autopilot_hazards = list()
	/// Shared by all ships; invalidated by hazard creation, movement and deletion.
	var/list/autopilot_blocked_tiles
	var/list/autopilot_zone_tiles

/obj/structure/overmap/event/Initialize(mapload)
	. = ..()
	if(!istype(src, /obj/structure/overmap/event/nebula))
		SSovermap.autopilot_hazards |= src
		SSovermap.autopilot_blocked_tiles = null

/obj/structure/overmap/event/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	if(!istype(src, /obj/structure/overmap/event/nebula))
		SSovermap.autopilot_blocked_tiles = null

/obj/structure/overmap/event/Destroy()
	SSovermap.autopilot_hazards -= src
	SSovermap.autopilot_blocked_tiles = null
	return ..()

/// No sensor calls here: a private navigation map must not discover anything.
/obj/structure/overmap/ship/proc/build_autopilot_danger_map()
	if(!isnull(SSovermap.autopilot_blocked_tiles))
		return SSovermap.autopilot_blocked_tiles
	var/list/blocked = list()
	for(var/obj/structure/overmap/event/hazard as anything in SSovermap.autopilot_hazards)
		if(QDELETED(hazard) || !istype(hazard.loc, /turf/open/overmap) || hazard.z != OVERMAP_Z_LEVEL)
			continue
		blocked["[hazard.x],[hazard.y]"] = TRUE
	SSovermap.autopilot_blocked_tiles = blocked
	return blocked

/// Only needed when planning or checking a changed policy. Zone bands are static.
/obj/structure/overmap/ship/proc/build_autopilot_zone_map()
	if(!isnull(SSovermap.autopilot_zone_tiles))
		return SSovermap.autopilot_zone_tiles
	var/list/zones = list()
	if(!SSovermap_zones?.initialized)
		return zones
	for(var/tile_x in OVERMAP_PATH_LOW_X to OVERMAP_PATH_HIGH_X)
		for(var/tile_y in OVERMAP_PATH_LOW_Y to OVERMAP_PATH_HIGH_Y)
			var/turf/open/overmap/tile = locate(tile_x, tile_y, OVERMAP_Z_LEVEL)
			if(istype(tile) && tile.current_zone)
				zones["[tile_x],[tile_y]"] = tile.current_zone.zone_type
	SSovermap.autopilot_zone_tiles = zones
	return zones

/obj/structure/overmap/ship/proc/autopilot_zone_allowed(zone_type)
	switch(zone_type)
		if(ZONE_GREEN)
			return autopilot_allow_neutral
		if(ZONE_YELLOW)
			return autopilot_allow_contested
		if(ZONE_RED)
			return autopilot_allow_lawless
	return TRUE

/// Folds an x coordinate back into the flyable band, the same way tick_move() does.
/proc/overmap_wrap_x(value)
	var/span = OVERMAP_PATH_SPAN_X
	return (((value - OVERMAP_PATH_LOW_X) % span + span) % span) + OVERMAP_PATH_LOW_X

/// Folds a y coordinate back into the flyable band, the same way tick_move() does.
/proc/overmap_wrap_y(value)
	var/span = OVERMAP_PATH_SPAN_Y
	return (((value - OVERMAP_PATH_LOW_Y) % span + span) % span) + OVERMAP_PATH_LOW_Y

/**
 * The shorter of the two ways round for a coordinate delta. The overmap wraps, so
 * a ship at x=3 is four tiles from x=48, not forty-five, routing and steering both
 * have to agree with the wraparound tick_move() actually performs.
 */
/proc/overmap_wrapped_delta(delta, span)
	if(delta > span * 0.5)
		return delta - span
	if(delta < -span * 0.5)
		return delta + span
	return delta

/// Tiles between two overmap positions when diagonal steps are free, which they
/// are: a diagonal burn crosses one tile on each axis per tick.
/proc/overmap_course_heuristic(from_x, from_y, to_x, to_y)
	var/step_x = abs(overmap_wrapped_delta(to_x - from_x, OVERMAP_PATH_SPAN_X))
	var/step_y = abs(overmap_wrapped_delta(to_y - from_y, OVERMAP_PATH_SPAN_Y))
	return max(step_x, step_y)

/// A* with eight-way steps. Charge zone crossings their real waiting time, so
/// clipping a boundary cannot save one tile at the cost of two ten-second waits.
/// Bearing breaks ties into straight legs; there are no terrain surcharges.
/proc/plan_overmap_course(start_x, start_y, dest_x, dest_y, list/danger, obj/structure/overmap/ship/pilot, list/zones)
	start_x = overmap_wrap_x(start_x)
	start_y = overmap_wrap_y(start_y)
	dest_x = overmap_wrap_x(dest_x)
	dest_y = overmap_wrap_y(dest_y)

	var/transition_cost = pilot ? CEILING(ZONE_TRANSITION_TIME * pilot.max_speed, 1) : 0
	var/max_frontier = OVERMAP_PATH_SPAN_X * OVERMAP_PATH_SPAN_Y * (1 + transition_cost)
	var/start_key = "[start_x],[start_y]"
	var/dest_key = "[dest_x],[dest_y]"
	if(start_key == dest_key)
		return list()

	if(!danger)
		danger = list()
	var/list/came_from = list()
	var/list/cost_so_far = list()
	var/list/buckets = list()

	if(danger[dest_key] || (pilot && !pilot.autopilot_zone_allowed(zones?[dest_key])))
		return null

	cost_so_far[start_key] = 0
	var/frontier = overmap_course_heuristic(start_x, start_y, dest_x, dest_y)
	buckets["[frontier]"] = list(start_key)
	var/queued = 1
	var/expansions = 0
	var/found = FALSE

	while(queued > 0)
		var/list/bucket = buckets["[frontier]"]
		if(!length(bucket))
			frontier++
			if(frontier > max_frontier)
				break
			continue

		var/current = bucket[length(bucket)]
		bucket.len--
		queued--

		if(current == dest_key)
			found = TRUE
			break

		var/current_cost = cost_so_far[current]
		if(isnull(current_cost))
			continue

		var/list/parts = splittext(current, ",")
		var/current_x = text2num(parts[1])
		var/current_y = text2num(parts[2])

		// A cheaper route to this tile was found after this entry was queued, so
		// this copy sits in a bucket above its real f and has already been beaten.
		if(current_cost + overmap_course_heuristic(current_x, current_y, dest_x, dest_y) < frontier)
			continue

		expansions++
		if(expansions > AUTOPILOT_MAX_EXPANSIONS)
			break

		// The tie-breaking order (see the doc comment): each axis runs worst-to-
		// best against the bearing so the bearing-matching step is pushed last and
		// popped first. An already-aligned axis (bearing 0) puts its straight step
		// last for the same reason.
		var/bearing_x = SIGN(overmap_wrapped_delta(dest_x - current_x, OVERMAP_PATH_SPAN_X))
		var/bearing_y = SIGN(overmap_wrapped_delta(dest_y - current_y, OVERMAP_PATH_SPAN_Y))
		var/list/steps_x = bearing_x ? list(-bearing_x, 0, bearing_x) : list(-1, 1, 0)
		var/list/steps_y = bearing_y ? list(-bearing_y, 0, bearing_y) : list(-1, 1, 0)
		for(var/step_x in steps_x)
			for(var/step_y in steps_y)
				if(!step_x && !step_y)
					continue
				var/next_x = overmap_wrap_x(current_x + step_x)
				var/next_y = overmap_wrap_y(current_y + step_y)
				var/next_key = "[next_x],[next_y]"
				if(danger[next_key])
					continue
				// A disabled starting zone may be left, but never entered again.
				if(pilot && !pilot.autopilot_zone_allowed(zones?[next_key]) && zones?[next_key] != zones?[current])
					continue
				var/new_cost = current_cost + 1
				if(zones?[current] && zones?[next_key] && zones[current] != zones[next_key])
					new_cost += transition_cost
				var/existing = cost_so_far[next_key]
				if(!isnull(existing) && existing <= new_cost)
					continue
				cost_so_far[next_key] = new_cost
				came_from[next_key] = current
				var/priority = new_cost + overmap_course_heuristic(next_x, next_y, dest_x, dest_y)
				var/list/target_bucket = buckets["[priority]"]
				if(!target_bucket)
					target_bucket = list()
					buckets["[priority]"] = target_bucket
				target_bucket += next_key
				queued++

	if(!found)
		return null

	// Walked destination-first off came_from, then flipped, rather than inserting
	// at the head each step: the course is short but the insert is not free.
	var/list/reversed = list()
	var/cursor = dest_key
	// A consistent heuristic can't produce a cycle in came_from, but an unbounded
	// while() walking a parent chain hangs the whole server if that ever stops
	// being true. The grid is the ceiling on any honest path length.
	var/steps_left = OVERMAP_PATH_SPAN_X * OVERMAP_PATH_SPAN_Y
	while(cursor != start_key)
		var/list/parts = splittext(cursor, ",")
		reversed += list(list(text2num(parts[1]), text2num(parts[2])))
		cursor = came_from[cursor]
		if(!cursor)
			return null
		steps_left--
		if(steps_left <= 0)
			CRASH("plan_overmap_course walked a cycle reconstructing a path to [dest_key]")

	var/list/course = list()
	for(var/index in length(reversed) to 1 step -1)
		course += list(reversed[index])
	return course

/obj/structure/overmap/ship/proc/engage_autopilot(dest_x, dest_y, label, mob/user, obj/structure/overmap/dock_target = null)
	if(state != OVERMAP_SHIP_FLYING)
		return "ERROR: Autopilot requires the ship to be under way."
	if(hidden_in_nebula)
		return "ERROR: Cannot plot a course while concealed."
	if(is_interdicted)
		return "ERROR: Interdiction field is holding us. Autopilot unavailable."
	if(!can_thrust())
		return "ERROR: No engine power. Autopilot unavailable."

	dest_x = overmap_wrap_x(dest_x)
	dest_y = overmap_wrap_y(dest_y)
	if(dest_x == x && dest_y == y)
		return "Autopilot: already at those coordinates."

	var/list/danger = build_autopilot_danger_map()
	var/list/course = plan_overmap_course(x, y, dest_x, dest_y, danger, src, build_autopilot_zone_map())
	if(isnull(course))
		return "ERROR: No safe route with the selected zones."

	if(zone_transitioning)
		cancel_zone_transition()
	autopilot_engaged = TRUE
	autopilot_dest_x = dest_x
	autopilot_dest_y = dest_y
	autopilot_label = label
	autopilot_path = course
	autopilot_checked_danger = null
	autopilot_checked_zones = null
	autopilot_status = null
	autopilot_dock_ref = dock_target ? WEAKREF(dock_target) : null
	autopilot_user_ref = user ? WEAKREF(user) : null
	// The autopilot owns the ship now; the commanded course (and the rose it
	// lights on the helm) stands down with the rest of manual control.
	commanded_course = BURN_NONE

	if(user)
		log_shuttle("[key_name(user)] engaged autopilot on [name] to ([dest_x], [dest_y])")

	schedule_autopilot_poll()
	autopilot_steer()
	push_helm_frame()

	if(dock_target)
		return "Autopilot engaged to [label || "the selected position"]. Docking on arrival."
	return "Autopilot engaged to [label || "the selected position"]."

/**
 * Ends the current course. `reason` is shown to the crew and left on the helm;
 * pass null for a silent stand-down (the crew took the controls back themselves).
 *
 * The ship is left coasting rather than braked. An autopilot that slams on the
 * brakes the instant someone locks weapons on you hands back a stationary target;
 * keeping the velocity means the crew inherits a ship that is still going
 * somewhere and can decide what to do with it.
 */
/obj/structure/overmap/ship/proc/disengage_autopilot(reason, notify = TRUE)
	if(!autopilot_engaged)
		return
	autopilot_engaged = FALSE
	autopilot_path = null
	autopilot_checked_danger = null
	autopilot_checked_zones = null
	autopilot_status = reason
	autopilot_dock_ref = null
	autopilot_user_ref = null
	if(autopilot_poll_timer)
		deltimer(autopilot_poll_timer)
		autopilot_poll_timer = null
	if(burn_direction != BURN_NONE)
		change_heading(BURN_NONE)
	if(notify && reason && ship_team)
		ship_notify("Autopilot disengaged: [reason]. Manual control restored.", "AUTOPILOT", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
	push_helm_frame()

/// Interrupt hook for the events that should break a course. Safe from a
/// SIGNAL_HANDLER: nothing below it sleeps.
/obj/structure/overmap/ship/proc/interrupt_autopilot(reason)
	if(!autopilot_engaged)
		return
	disengage_autopilot(reason)

/// Course flown. Unlike an interrupt this does bring the ship to rest, arriving
/// is the one case where stopping is the whole point. A course carrying a dock
/// target then hands it straight to the ship_act() docking path (see the header).
/obj/structure/overmap/ship/proc/complete_autopilot()
	autopilot_engaged = FALSE
	autopilot_path = null
	autopilot_checked_danger = null
	autopilot_checked_zones = null
	autopilot_status = "arrived"
	if(autopilot_poll_timer)
		deltimer(autopilot_poll_timer)
		autopilot_poll_timer = null
	full_stop()

	// Compared against the target's LIVE position rather than close_overmap_objects,
	// which is maintained by enter/exit signals and need not have caught up with the
	// forceMove that just landed us here. The target validated at engage time can
	// also be gone or moved by now. Then this is just an arrival like any other.
	var/obj/structure/overmap/dock_target = autopilot_dock_ref?.resolve()
	var/mob/pilot = autopilot_user_ref?.resolve()
	autopilot_dock_ref = null
	autopilot_user_ref = null
	if(dock_target && !QDELETED(dock_target) && dock_target.x == x && dock_target.y == y)
		if(ship_team)
			ship_notify("Autopilot: arrived at [autopilot_label || "the plotted position"], commencing docking approach.", "AUTOPILOT", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		// We just stopped, so overmap_object_act()'s stillness gate passes; it
		// INVOKE_ASYNCs ship_act, and this runs from a timer, so nothing sleeps here.
		overmap_object_act(pilot, dock_target)
	else if(ship_team)
		ship_notify("Autopilot: arrived at [autopilot_label || "the plotted position"]. Holding station.", "AUTOPILOT", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	push_helm_frame()

// ---------------------------------------------------------------- steering

/obj/structure/overmap/ship/proc/schedule_autopilot_poll(delay = AUTOPILOT_POLL_INTERVAL)
	if(autopilot_poll_timer)
		deltimer(autopilot_poll_timer)
	autopilot_poll_timer = addtimer(CALLBACK(src, PROC_REF(autopilot_poll)), delay, TIMER_STOPPABLE)

/obj/structure/overmap/ship/proc/autopilot_poll()
	autopilot_poll_timer = null
	if(!autopilot_engaged || QDELETED(src))
		return
	autopilot_steer()
	if(autopilot_engaged && !autopilot_poll_timer)
		schedule_autopilot_poll()

/// The direction to burn to reach an adjacent course node, ignoring velocity.
/obj/structure/overmap/ship/proc/autopilot_step_dir(node_x, node_y)
	var/step_x = overmap_wrapped_delta(node_x - x, OVERMAP_PATH_SPAN_X)
	var/step_y = overmap_wrapped_delta(node_y - y, OVERMAP_PATH_SPAN_Y)
	var/step_dir = NONE
	if(step_x > 0)
		step_dir |= EAST
	else if(step_x < 0)
		step_dir |= WEST
	if(step_y > 0)
		step_dir |= NORTH
	else if(step_y < 0)
		step_dir |= SOUTH
	return step_dir

/**
 * tick_move() uses velocity signs to choose its tile. Cancel axes pointing away
 * from the next node, retain correct drift, and burn only the missing axes.
 * Manual course controls share this steering helper.
 */
/obj/structure/overmap/ship/proc/autopilot_aim_drift(want_x, want_y)
	var/drift_x = SIGN(speed[1])
	var/drift_y = SIGN(speed[2])
	kill_drift(drift_x && drift_x != want_x, drift_y && drift_y != want_y)

	var/burn = NONE
	if(want_x && SIGN(speed[1]) != want_x)
		burn |= (want_x > 0) ? EAST : WEST
	if(want_y && SIGN(speed[2]) != want_y)
		burn |= (want_y > 0) ? NORTH : SOUTH
	return burn

/obj/structure/overmap/ship/proc/autopilot_steer()
	if(!autopilot_engaged || QDELETED(src))
		return
	if(state != OVERMAP_SHIP_FLYING)
		disengage_autopilot("ship is no longer under way")
		return
	if(hidden_in_nebula)
		disengage_autopilot("concealment engaged")
		return
	// A zone crossing cuts the engines for its duration and clears the burn. Sit
	// through it, the poll timer picks the course back up on the far side, which
	// is the whole reason the poll runs independently of tile crossings.
	if(zone_transitioning)
		return
	if(!can_thrust())
		disengage_autopilot("no engine power")
		return

	// On the destination tile. Nothing to wind down, complete_autopilot() stops the
	// ship where it stands, which is why there is no braking approach further down.
	if(x == autopilot_dest_x && y == autopilot_dest_y)
		complete_autopilot()
		return

	// Drop the nodes we've already flown through.
	while(length(autopilot_path))
		var/list/node = autopilot_path[1]
		if(node[1] == x && node[2] == y)
			autopilot_path.Cut(1, 2)
		else
			break

	var/list/danger = build_autopilot_danger_map()
	var/list/zones = build_autopilot_zone_map()
	if(autopilot_course_needs_replan(danger, zones))
		var/list/course = plan_overmap_course(x, y, autopilot_dest_x, autopilot_dest_y, danger, src, zones)
		if(isnull(course))
			full_stop()
			disengage_autopilot("no safe route with the selected zones")
			return
		autopilot_path = course
		autopilot_checked_danger = null
		autopilot_checked_zones = null
	if(!length(autopilot_path))
		full_stop()
		return

	var/list/next_node = autopilot_path[1]
	var/step_dir = autopilot_step_dir(next_node[1], next_node[2])
	if(!step_dir)
		return

	var/cruise = max_speed
	clamp_speed(cruise)

	// Where the velocity has to point for the next tick to land us on the next node.
	var/want_x = ((step_dir & EAST) ? 1 : 0) - ((step_dir & WEST) ? 1 : 0)
	var/want_y = ((step_dir & NORTH) ? 1 : 0) - ((step_dir & SOUTH) ? 1 : 0)
	var/burn = autopilot_aim_drift(want_x, want_y)
	if(burn)
		if(burn_direction != burn)
			change_heading(burn)
		// A burn keeps thrusting until something stops it, and nothing else looks
		// again until the next tile crossing, which at low speed is many seconds
		// away, long enough to blow well past the ceiling. Look again next thrust tick.
		schedule_autopilot_poll(AUTOPILOT_BURN_POLL)
		return

	// Drifting the right way: hold what we have once we're up to speed. Coasting
	// costs nothing to leave running, so this is the one case that goes back to
	// the slow poll.
	if(MAGNITUDE(speed[1], speed[2]) >= cruise * 0.999)
		if(burn_direction != BURN_NONE)
			change_heading(BURN_NONE)
		return

	if(burn_direction != step_dir)
		change_heading(step_dir)
	schedule_autopilot_poll(AUTOPILOT_BURN_POLL)

/// A valid course has no expiry timer. Replanning cannot improve unchanged terrain.
/obj/structure/overmap/ship/proc/autopilot_course_needs_replan(list/danger, list/zones)
	if(!length(autopilot_path))
		return TRUE
	var/list/next_node = autopilot_path[1]
	if(overmap_course_heuristic(x, y, next_node[1], next_node[2]) != 1)
		return TRUE
	if(danger == autopilot_checked_danger && zones == autopilot_checked_zones)
		return FALSE
	var/previous_zone = zones?["[x],[y]"]
	for(var/list/node as anything in autopilot_path)
		var/key = "[node[1]],[node[2]]"
		var/next_zone = zones?[key]
		if(danger[key] || (!autopilot_zone_allowed(next_zone) && next_zone != previous_zone))
			return TRUE
		previous_zone = next_zone
	if(!autopilot_zone_allowed(previous_zone))
		return TRUE
	autopilot_checked_danger = danger
	autopilot_checked_zones = zones
	return FALSE

/// Last check immediately before an actual move, including a delayed zone crossing.
/// Never enter a hazard because it appeared between a steering poll and a move.
/obj/structure/overmap/ship/proc/autopilot_can_enter(turf/target)
	if(!target)
		return FALSE
	// An axis may still be accelerating into a turn. Hold until the actual
	// velocity reaches the planned heading instead of drifting off the route.
	if(length(autopilot_path))
		var/list/next_node = autopilot_path[1]
		if(target.x != next_node[1] || target.y != next_node[2])
			return FALSE
	var/list/danger = build_autopilot_danger_map()
	if(danger["[target.x],[target.y]"])
		return FALSE
	var/list/zones = build_autopilot_zone_map()
	var/target_zone = zones["[target.x],[target.y]"]
	return autopilot_zone_allowed(target_zone) || target_zone == zones["[x],[y]"]

/obj/structure/overmap/ship/proc/set_autopilot_pref(key, value)
	value = value ? TRUE : FALSE
	switch(key)
		if("allowNeutral")
			autopilot_allow_neutral = value
		if("allowContested")
			autopilot_allow_contested = value
		if("allowLawless")
			autopilot_allow_lawless = value
		else
			return FALSE
	if(autopilot_engaged)
		if(zone_transitioning)
			cancel_zone_transition()
		autopilot_path = null
		autopilot_steer()
	push_helm_frame()
	return TRUE

/// Only destination and controls are public. Route geometry and length would
/// reveal detours around undiscovered hazards, even without sending the hazards.
/obj/structure/overmap/ship/proc/get_autopilot_data()
	var/list/data = list(
		"engaged" = autopilot_engaged,
		"label" = autopilot_label,
		"status" = autopilot_status,
		"dockOnArrival" = !!autopilot_dock_ref,
		"prefs" = list(
			"allowNeutral" = autopilot_allow_neutral,
			"allowContested" = autopilot_allow_contested,
			"allowLawless" = autopilot_allow_lawless,
		),
	)
	if(autopilot_engaged)
		data["destX"] = autopilot_dest_x - OVERMAP_LEFT_SIDE_COORD + 1
		data["destY"] = autopilot_dest_y - OVERMAP_SOUTH_SIDE_COORD + 1
	return data

#undef AUTOPILOT_MAX_EXPANSIONS
#undef AUTOPILOT_POLL_INTERVAL
#undef AUTOPILOT_BURN_POLL
#undef OVERMAP_PATH_LOW_X
#undef OVERMAP_PATH_HIGH_X
#undef OVERMAP_PATH_LOW_Y
#undef OVERMAP_PATH_HIGH_Y
#undef OVERMAP_PATH_SPAN_X
#undef OVERMAP_PATH_SPAN_Y
