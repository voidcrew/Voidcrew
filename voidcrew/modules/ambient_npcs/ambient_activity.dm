/**
 * # World population: routines
 *
 * Owner: P0 seams (frozen). Packages add /datum/ambient_activity subtypes in their own files.
 *
 * One routine base for every ambient NPC (spec 2.1). An NPC always has at most one activity: a
 * /datum/ambient_activity that finds what it uses once (setup()), is walked to (`spot`), starts
 * there (arrive()), carries on about once a second (act()) and puts everything back (finish()).
 * The NPC's `routine` picks the next one when it ends; a reaction (a fight, a storm, leaving)
 * replaces it at once if it outranks it (`priority`).
 *
 * The runner is an AI planning subtree, so it only runs while the NPC's AI is on (a living player
 * near), and nothing here costs anything while nobody watches. At a trader outpost nobody is on,
 * their AI is off and their activity's times are moved on when someone comes (shift_times()), so
 * they carry on where they stopped. Someone who was there all along is set going at their
 * activity's spot without walking there, part-way in (settle_in(), settle_here(), settle()).
 *
 * Working at an object reuses the trader mechanics' work loop as it is
 * (voidcrew/modules/player_outposts/outpost_ambient_work.dm): /datum/ambient_activity/work puts an
 * /datum/component/outpost_ambient_worker on the NPC for one job, finds the job, walks to it, runs
 * the job's /datum/outpost_ambient_work kind (welding, a wrench, a panel, pipes, hauling, wiping,
 * pouring, mopping, with their sounds, sparks and working looks) and takes the component off
 * again. The mechanics are now ambient too, working one job at a time like this; only the yard
 * droids keep that component permanently.
 *
 * Generic activities here: idle, wander (near a spot), sit, drink, chat, work, leave (by the lift),
 * go home (the leash), take cover (the kingpin's shootout) and shelter (a storm).
 */

// =========================================================================
// THE RUNNER
// =========================================================================

/**
 * Starts `new_activity` unless something more important is going on (a higher `priority`). The
 * current activity is finished and replaced. Returns the activity, or null if it could not be set
 * up here or was outranked; a refused activity is deleted.
 */
/mob/living/basic/ambient_npc/proc/start_activity(datum/ambient_activity/new_activity)
	if(QDELETED(new_activity))
		return null
	if(fading || stat == DEAD || (activity && activity.priority > new_activity.priority))
		qdel(new_activity)
		return null
	end_activity()
	if(!new_activity.setup())
		qdel(new_activity)
		return null
	activity = new_activity
	travel_failures = 0
	SEND_SIGNAL(src, COMSIG_AMBIENT_NPC_ACTIVITY_STARTED, new_activity)
	return new_activity

/// Stops their activity: it puts everything back and goes
/mob/living/basic/ambient_npc/proc/end_activity()
	if(!activity)
		return
	var/datum/ambient_activity/old = activity
	activity = null
	old.finish()
	qdel(old)

/// Their activity, or a new one from their routine. Null while they wait after a failure.
/mob/living/basic/ambient_npc/proc/next_activity()
	if(activity)
		return activity
	if(world.time < activity_retry_at)
		return null
	if(!pick_activity())
		activity_retry_at = world.time + AMBIENT_ACTIVITY_RETRY
	return activity

/**
 * Picks and starts something from their `routine`, trying each kind in weighted order until one
 * can be set up, then standing around. Override to choose by other rules (time spent, a bar, a
 * stall). Returns the started activity or null.
 */
/mob/living/basic/ambient_npc/proc/pick_activity()
	var/list/weights = routine?.Copy()
	while(length(weights))
		var/activity_type = pick_weight(weights)
		weights -= activity_type
		if(start_activity(new activity_type(src)))
			return activity
	return start_activity(new /datum/ambient_activity/idle(src))

/// One step of their activity where they stand: arriving the first time, then its business. Returns AMBIENT_STEP_*.
/mob/living/basic/ambient_npc/proc/activity_step(seconds)
	if(!activity)
		return AMBIENT_STEP_DONE
	if(!activity.arrived)
		activity.arrived = TRUE
		activity.arrive()
	if(!activity)
		return AMBIENT_STEP_DONE
	if(activity.ends_at && world.time >= activity.ends_at)
		return AMBIENT_STEP_DONE
	return activity.act(seconds)

/// A walk to their activity's spot ended stuck
/mob/living/basic/ambient_npc/proc/travel_failed()
	if(++travel_failures < AMBIENT_TRAVEL_FAILURES_MAX)
		return
	travel_failures = 0
	activity?.spot_unreachable()

// =========================================================================
// SETTLING IN (already there when players come)
// =========================================================================

/**
 * They were here before anyone came: set going at something from their routine, at its own spot
 * and part-way through it. Called once, just after they are made at their place
 * (/datum/ambient_outpost_role/proc/settle()), while nobody watches. TRUE if they are at an
 * activity; if nothing could be set up they stand somewhere out of the way, and their routine
 * starts when someone comes. Override to start them at something in particular (settle_at()).
 */
/mob/living/basic/ambient_npc/proc/settle_in()
	// Where they were made is only somewhere on the floor: first somewhere they may stand
	move_to_settle_tile()
	for(var/attempt in 1 to AMBIENT_SETTLE_TRIES)
		if(pick_activity() && !istype(activity, /datum/ambient_activity/leave) && !istype(activity, /datum/ambient_activity/go_home) && settle_here())
			return TRUE
		end_activity()
		if(!move_to_settle_tile())
			break
	return FALSE

/**
 * Settles them at an `activity_type` made with `anchor`: from a free tile of their place's floor
 * (within `radius` of `near`, if given), then from others, up to `tries` places in all. For
 * activities that look round where the NPC stands (the work loop). TRUE if settled.
 */
/mob/living/basic/ambient_npc/proc/settle_at(activity_type, atom/anchor, tries = AMBIENT_SETTLE_TRIES, atom/near, radius = 6)
	if(near || !standable(get_turf(src)))
		move_to_settle_tile(near, radius)
	for(var/attempt in 1 to tries)
		if(start_activity(new activity_type(src, anchor)) && settle_here())
			return TRUE
		end_activity()
		if(attempt < tries && !move_to_settle_tile(near, radius))
			break
	return FALSE

/**
 * Puts them at their current activity's spot as if they had walked there long ago, starts it there
 * (arrive()) and sets it part-way in (settle()). Their leash is anchored where they end up. FALSE
 * when they have no activity or its spot is taken.
 */
/mob/living/basic/ambient_npc/proc/settle_here()
	if(!activity)
		return FALSE
	if(!activity.at_spot())
		var/turf/stand = activity.spot
		if(!isturf(stand) || (stand != loc && (locate(/mob/living) in stand)))
			stand = activity.spot_distance ? free_tile_beside(activity.spot, activity.spot_distance) : null
		if(!stand)
			return FALSE
		forceMove(stand)
		if(!activity.at_spot())
			return FALSE
	home = get_turf(src)
	activity.arrived = TRUE
	activity.arrive()
	if(!activity)
		return FALSE
	activity.settle()
	return TRUE

/// Moves them (with nobody watching) to a free tile of their place's floor they could stand on, within `radius` of `near` if given. FALSE if there is none.
/mob/living/basic/ambient_npc/proc/move_to_settle_tile(atom/near, radius = 6)
	var/turf/tile = place?.settle_turf(src, near, radius)
	if(!tile)
		return FALSE
	forceMove(tile)
	home = tile
	return TRUE

// =========================================================================
// SPOTS
// =========================================================================

/**
 * Whether they could go and stand on `tile`: ground they can stand on, free, on their leash, and
 * where their place lets activities send them (an outpost's public floor). `ignore_floor` skips
 * the place's floor (taking cover). Spots in `avoid` are skipped.
 */
/mob/living/basic/ambient_npc/proc/standable(turf/tile, list/avoid, ignore_floor = FALSE)
	if(!isturf(tile) || LAZYACCESS(avoid, tile))
		return FALSE
	if(!isopenturf(tile) || isspaceturf(tile) || isgroundlessturf(tile) || islava(tile) || ischasm(tile))
		return FALSE
	if(tile != loc && tile.is_blocked_turf(source_atom = src))
		return FALSE
	if(!leash_ok(tile))
		return FALSE
	return ignore_floor || !place || place.spot_allowed(tile, src)

/// Whether they could stand about on `tile`: standable, and their place's loiter rules. `ignore` is not counted in the crowd (their chat partner).
/mob/living/basic/ambient_npc/proc/loiter_spot_ok(turf/tile, list/avoid, atom/ignore)
	return standable(tile, avoid) && (!place || place.loiter_ok(tile, src, ignore))

/**
 * The nearest free tile within `distance` of `thing` they could stand on (not its own tile), or
 * null. Right beside it (distance 1), nothing may stand between them (Adjacent(): no wall, glass or
 * rail), since they use it from there.
 */
/mob/living/basic/ambient_npc/proc/free_tile_beside(atom/thing, distance = 1, list/avoid, ignore_floor = FALSE)
	var/turf/center = get_turf(thing)
	if(!center)
		return null
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/tile as anything in RANGE_TURFS(distance, center))
		if(tile == center || !standable(tile, avoid, ignore_floor))
			continue
		if(distance <= 1 && !tile.Adjacent(thing))
			continue
		var/from_us = get_dist(src, tile)
		if(from_us < best_distance)
			best = tile
			best_distance = from_us
	return best

/// A random free tile within `radius` of `center` in the same area, or null
/mob/living/basic/ambient_npc/proc/random_tile_near(turf/center, radius, list/avoid)
	center = get_turf(center)
	if(!center)
		return null
	var/area/center_area = get_area(center)
	for(var/attempt in 1 to 8)
		var/turf/tile = locate(center.x + rand(-radius, radius), center.y + rand(-radius, radius), center.z)
		if(tile && tile != loc && get_area(tile) == center_area && can_see(center, tile, radius + 1) && loiter_spot_ok(tile, avoid))
			return tile
	return null

/**
 * The best loiter spot within `radius` of `near`, in sight of it: a random score favouring nearer
 * tiles, a couple of points for one with a wall, a table or a dense anchored machine at its side
 * (somewhere to lean on). Or null.
 */
/mob/living/basic/ambient_npc/proc/find_loiter_spot(atom/near, radius = AMBIENT_LOITER_RANGE, list/avoid)
	var/turf/center = get_turf(near)
	if(!center)
		return null
	var/turf/best
	var/best_score = -INFINITY
	for(var/turf/tile as anything in RANGE_TURFS(radius, center))
		if(!can_see(center, tile, radius + 1) || !loiter_spot_ok(tile, avoid))
			continue
		var/score = rand(0, 20) / 10 - get_dist(src, tile) / 2
		if(ambient_backed_by_wall_or_table(tile))
			score += 2
		if(score > best_score)
			best_score = score
			best = tile
	return best

/// A table right beside `thing`, or null
/mob/living/basic/ambient_npc/proc/table_beside(atom/thing)
	var/turf/center = get_turf(thing)
	if(!center)
		return null
	for(var/turf/tile as anything in RANGE_TURFS(1, center))
		var/obj/structure/table/table = locate() in tile
		if(table)
			return table
	return null

/**
 * Whether they could sit on `seat`: loose on the floor, nobody on it, where they may go. Stools
 * (bar stools too) refuse people by default; they are sat on with a forced buckle all the same.
 */
/mob/living/basic/ambient_npc/proc/seat_usable(obj/structure/chair/seat, list/avoid)
	if(QDELETED(seat) || !isturf(seat.loc) || istype(seat, /obj/structure/chair/e_chair))
		return FALSE
	if(seat.has_buckled_mobs() && !(src in seat.buckled_mobs))
		return FALSE
	for(var/mob/living/other in seat.loc)
		// A body lying there counts too
		if(other != src && (other.density || other.stat == DEAD))
			return FALSE
	return seat.loc == loc || standable(seat.loc, avoid)

/// A random one of the three nearest seats within `range` of `near` they could sit on, beside a table if `needs_table`, in sight of `near`
/mob/living/basic/ambient_npc/proc/find_seat(atom/near, range = AMBIENT_ACTIVITY_RANGE, needs_table = FALSE, list/avoid)
	var/turf/center = get_turf(near) || get_turf(src)
	if(!center)
		return null
	var/list/distances = list()
	for(var/obj/structure/chair/seat in range(range, center))
		if(!seat_usable(seat, avoid) || (needs_table && !table_beside(seat)) || !can_see(center, seat, range + 1))
			continue
		distances[seat] = get_dist(src, seat)
	if(!length(distances))
		return null
	var/list/nearest = list()
	for(var/obj/structure/chair/seat as anything in sortTim(distances, GLOBAL_PROC_REF(cmp_numeric_asc), associative = TRUE))
		nearest += seat
		if(length(nearest) >= 3)
			break
	return pick(nearest)

/// The nearest table within `range` of `near`, in sight of it, with room to stand at, or null
/mob/living/basic/ambient_npc/proc/find_table(atom/near, range = AMBIENT_ACTIVITY_RANGE, list/avoid)
	var/turf/center = get_turf(near) || get_turf(src)
	if(!center)
		return null
	var/obj/structure/table/best
	var/best_distance = INFINITY
	for(var/obj/structure/table/table in range(range, center))
		if(!leash_ok(get_turf(table)) || !can_see(center, table, range + 1))
			continue
		var/distance = get_dist(src, table)
		if(distance < best_distance && free_tile_beside(table, 1, avoid))
			best = table
			best_distance = distance
	return best

/// Another ambient NPC within `range`, in sight, who is free to talk (awake, unplayed, doing nothing that can't wait, standing somewhere not already crowded), or null
/mob/living/basic/ambient_npc/proc/find_chat_partner(range = AMBIENT_ACTIVITY_RANGE)
	var/turf/here = get_turf(src)
	if(!here)
		return null
	var/list/options = list()
	for(var/mob/living/basic/ambient_npc/other in range(range, here))
		if(other == src || other.client || !other.can_act())
			continue
		if(other.activity && !other.activity.accepts_company)
			continue
		if(!can_see(here, other, range + 1))
			continue
		var/turf/other_turf = get_turf(other)
		if(place && other_turf)
			if(!other.buckled && !place.loiter_ok(other_turf, src, other))
				continue
			if(place.crowded(other_turf, src, other))
				continue
		options += other
	return length(options) ? pick(options) : null

/// Whether `tile` has a wall, a table or a dense anchored machine on a cardinal side: somewhere worth standing about beside
/proc/ambient_backed_by_wall_or_table(turf/tile)
	for(var/cdir in GLOB.cardinals)
		var/turf/next = get_step(tile, cdir)
		if(!next || !isopenturf(next))
			return TRUE
		if(locate(/obj/structure/table) in next)
			return TRUE
		for(var/obj/thing in next)
			if(thing.density && thing.anchored)
				return TRUE
	return FALSE

// =========================================================================
// AI
// =========================================================================

/**
 * An ambient NPC's brain: passive (no targeting, so trader outpost turrets read it as harmless),
 * long paths for crossing a concourse, and nothing at all while idle (nobody near).
 */
/datum/ai_controller/basic_controller/ambient_npc
	blackboard = list()
	ai_traits = PASSIVE_AI_FLAGS
	ai_movement = /datum/ai_movement/jps/ambient
	idle_behavior = null
	max_target_distance = AMBIENT_PATH_LENGTH
	planning_subtrees = list(/datum/ai_planning_subtree/ambient_routine)

// Their AI time, for the Ambient NPCs line in the MC tab (SSambient_npcs.note_ai_cost())
/datum/ai_controller/basic_controller/ambient_npc/SelectBehaviors(seconds_per_tick)
	var/start = TICK_USAGE_REAL
	. = ..()
	SSambient_npcs.note_ai_cost(start)

/datum/ai_controller/basic_controller/ambient_npc/ProcessBehavior(seconds_per_tick, datum/ai_behavior/behavior)
	var/start = TICK_USAGE_REAL
	. = ..()
	SSambient_npcs.note_ai_cost(start)

/// Long walks. The leash is kept by the NPC's own Move(), which refuses a step off it.
/datum/ai_movement/jps/ambient
	maximum_length = AMBIENT_PATH_LENGTH

/// Keeps them on their leash, then walks to their activity's spot or carries it on there
/datum/ai_planning_subtree/ambient_routine

/datum/ai_planning_subtree/ambient_routine/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/ambient_npc/npc = controller.pawn
	if(!istype(npc) || controller.ai_status != AI_STATUS_ON || !npc.can_act())
		return
	npc.check_leash()
	if(npc.fading)
		return
	var/datum/ambient_activity/current = npc.next_activity()
	if(!current)
		return
	if(!current.at_spot())
		controller.set_blackboard_key(BB_AMBIENT_DESTINATION, current.spot)
		controller.queue_behavior(current.spot_distance ? /datum/ai_behavior/travel_towards/ambient/adjacent : /datum/ai_behavior/travel_towards/ambient, BB_AMBIENT_DESTINATION)
		return SUBTREE_RETURN_FINISH_PLANNING
	controller.queue_behavior(/datum/ai_behavior/ambient_activity)
	return SUBTREE_RETURN_FINISH_PLANNING

/**
 * Walks to the turf in the blackboard key, planning going on meanwhile. A new spot ends the walk so
 * the new one starts at once; a walk that ends stuck counts toward giving the spot up.
 */
/datum/ai_behavior/travel_towards/ambient
	action_cooldown = 0.5 SECONDS
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION | AI_BEHAVIOR_MOVE_AND_PERFORM

/datum/ai_behavior/travel_towards/ambient/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/atom/target = controller.blackboard[target_key]
	if(QDELETED(target) || controller.current_movement_target != target)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	if(get_dist(controller.pawn, target) <= required_distance)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY

/datum/ai_behavior/travel_towards/ambient/finish_action(datum/ai_controller/controller, succeeded, target_key)
	var/atom/target = controller.blackboard[target_key]
	var/stuck = !succeeded && controller.consecutive_pathing_attempts > 0 && target && controller.current_movement_target == target
	. = ..()
	var/mob/living/basic/ambient_npc/npc = controller.pawn
	if(!istype(npc))
		return
	if(succeeded)
		npc.travel_failures = 0
	else if(stuck)
		npc.travel_failed()

/// The same, stopping beside the spot
/datum/ai_behavior/travel_towards/ambient/adjacent
	required_distance = 1

/// Carries the activity on about once a second, planning going on meanwhile so a reaction is picked up
/datum/ai_behavior/ambient_activity
	action_cooldown = 1 SECONDS
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/ambient_activity/setup(datum/ai_controller/controller)
	var/mob/living/basic/ambient_npc/npc = controller.pawn
	return istype(npc) && !!npc.activity

/datum/ai_behavior/ambient_activity/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/basic/ambient_npc/npc = controller.pawn
	var/datum/ambient_activity/current = npc.activity
	if(!current)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	if(!current.at_spot())
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	switch(npc.activity_step(seconds_per_tick))
		if(AMBIENT_STEP_MOVE)
			return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
		if(AMBIENT_STEP_DONE)
			npc.end_activity()
			return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY

// =========================================================================
// THE ACTIVITY BASE
// =========================================================================

/datum/ambient_activity/New(mob/living/basic/ambient_npc/new_doer, atom/anchor)
	. = ..()
	doer = new_doer
	anchor_ref = anchor ? WEAKREF(anchor) : null

/datum/ambient_activity/Destroy()
	doer = null
	spot = null
	failed_spots = null
	return ..()

/// What it happens at, if it is still there
/datum/ambient_activity/proc/anchor()
	var/atom/anchor = anchor_ref?.resolve()
	return QDELETED(anchor) ? null : anchor

/// Finds what it uses and where to go. FALSE when it can't be done here. Override.
/datum/ambient_activity/proc/setup()
	return TRUE

/// Sends them to `where` next (null: where they stand), stopping `distance` from it
/datum/ambient_activity/proc/go_to(turf/where, distance = 0)
	spot = where
	spot_distance = distance
	arrived = FALSE

/// Whether they are where the activity happens
/datum/ambient_activity/proc/at_spot()
	if(!spot)
		return TRUE
	if(!isturf(doer.loc))
		return FALSE
	return spot_distance ? get_dist(doer, spot) <= spot_distance : doer.loc == spot

/// They got there. Override.
/datum/ambient_activity/proc/arrive()
	return

/// About once a second in place. Returns AMBIENT_STEP_*. Override.
/datum/ambient_activity/proc/act(seconds)
	return AMBIENT_STEP_CONTINUE

/// Puts everything back: the drink down, up on their feet. Override and call the parent.
/datum/ambient_activity/proc/finish()
	if(QDELETED(doer))
		return
	if(doer.held_item)
		doer.put_drink_down(null)
	doer.stand_up()

/// They could not walk to `spot`: it is not picked again, and they carry on where they are. Override.
/datum/ambient_activity/proc/spot_unreachable()
	if(isturf(spot))
		LAZYSET(failed_spots, spot, TRUE)
		if(length(failed_spots) > AMBIENT_FAILED_SPOTS_MAX)
			failed_spots.Cut(1, 2)
	spot = null
	arrived = FALSE

/// Sets `ends_at` from `duration_low` and `duration_high`
/datum/ambient_activity/proc/set_duration()
	ends_at = world.time + rand(duration_low, duration_high)

/**
 * They have been at it a while: the outpost was busy before anyone came (settle_here(), just after
 * arrive()). The default brings its end nearer. Override to start further in; call the parent.
 */
/datum/ambient_activity/proc/settle()
	ends_at = ambient_part_way(ends_at)

/**
 * They stood still for `delay` (nobody at their outpost): every world.time it waits for moves on by
 * as much, so it carries on where it stopped. Override for your own times; call the parent.
 */
/datum/ambient_activity/proc/shift_times(delay)
	ends_at = ambient_shifted(ends_at, delay)
	next_line = ambient_shifted(next_line, delay)

/// A line for `context` now and then: no sooner than `low` to `high` after the last one, and only when the NPC's own and place's pauses allow
/datum/ambient_activity/proc/chatter(context = AMBIENT_LINE_IDLE, low = 20 SECONDS, high = 45 SECONDS)
	if(world.time < next_line)
		return
	next_line = world.time + rand(low, high)
	doer.speak_context(context)

// =========================================================================
// GENERIC ACTIVITIES
// =========================================================================

/// Standing about, looking around, a word now and then. The fallback when nothing else can be set up.
/datum/ambient_activity/idle
	name = "standing around"
	accepts_company = TRUE
	duration_low = 20 SECONDS
	duration_high = 60 SECONDS

/datum/ambient_activity/idle/setup()
	set_duration()
	next_line = world.time + rand(10 SECONDS, 30 SECONDS)
	if(doer.place && isturf(doer.loc) && !doer.buckled && !doer.loiter_spot_ok(doer.loc))
		var/turf/better = doer.find_loiter_spot(doer)
		if(!better && istype(doer.place, /datum/ambient_place/outpost))
			better = doer.place.settle_turf(doer, doer, AMBIENT_LOITER_RANGE * 2)
		if(better)
			go_to(better)
	return TRUE

/datum/ambient_activity/idle/act(seconds)
	if(prob(8) && !doer.buckled)
		doer.setDir(pick(GLOB.cardinals))
	chatter()
	return AMBIENT_STEP_CONTINUE

/// A slow stroll: a few spots near where they are (or near the anchor), with a pause at each
/datum/ambient_activity/wander
	name = "strolling"
	accepts_company = TRUE
	/// How far from the middle they stroll
	var/radius = 4
	/// Where the stroll is centred
	var/turf/middle
	/// Spots left to walk to
	var/stops_left = 0
	/// world.time they move on from this spot
	var/linger_until = 0

/datum/ambient_activity/wander/setup()
	middle = get_turf(anchor()) || get_turf(doer)
	stops_left = rand(2, 4)
	return next_stop()

/datum/ambient_activity/wander/Destroy()
	middle = null
	return ..()

/// Picks the next spot; FALSE when there is none
/datum/ambient_activity/wander/proc/next_stop()
	var/turf/stop = doer.random_tile_near(middle, radius, failed_spots)
	if(!stop)
		return FALSE
	go_to(stop)
	return TRUE

/datum/ambient_activity/wander/arrive()
	linger_until = world.time + rand(3 SECONDS, 10 SECONDS)

/datum/ambient_activity/wander/act(seconds)
	if(world.time < linger_until)
		if(prob(10))
			doer.setDir(pick(GLOB.cardinals))
		chatter(low = 30 SECONDS, high = 60 SECONDS)
		return AMBIENT_STEP_CONTINUE
	if(--stops_left <= 0 || !next_stop())
		return AMBIENT_STEP_DONE
	return AMBIENT_STEP_MOVE

/datum/ambient_activity/wander/spot_unreachable()
	. = ..()
	stops_left = min(stops_left, 1)

/datum/ambient_activity/wander/shift_times(delay)
	. = ..()
	linger_until = ambient_shifted(linger_until, delay)

/// A seat, beside a table if `needs_table`, for a while
/datum/ambient_activity/sit
	name = "sitting"
	accepts_company = TRUE
	duration_low = 45 SECONDS
	duration_high = 2 MINUTES
	/// Only a seat with a table beside it
	var/needs_table = FALSE
	var/datum/weakref/seat_ref

/datum/ambient_activity/sit/setup()
	var/obj/structure/chair/seat = anchor()
	if(!istype(seat) || !doer.seat_usable(seat, failed_spots))
		seat = doer.find_seat(anchor() || doer, AMBIENT_ACTIVITY_RANGE, needs_table, failed_spots)
	if(!seat)
		return FALSE
	seat_ref = WEAKREF(seat)
	go_to(get_turf(seat))
	set_duration()
	next_line = world.time + rand(15 SECONDS, 40 SECONDS)
	return TRUE

/datum/ambient_activity/sit/arrive()
	var/obj/structure/chair/seat = seat_ref?.resolve()
	if(!seat || !doer.sit_on(seat))
		seat_ref = null

/datum/ambient_activity/sit/act(seconds)
	if(!seat_ref)
		return AMBIENT_STEP_DONE
	chatter()
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/sit/spot_unreachable()
	. = ..()
	seat_ref = null

/**
 * A drink at a table or counter, seated if there is a seat: a real glass in hand, sipped now and
 * then, set down on the table at the end (a few per NPC and per table; otherwise it just goes).
 */
/datum/ambient_activity/drink
	name = "drinking"
	accepts_company = TRUE
	duration_low = 1 MINUTES
	duration_high = 3 MINUTES
	/// What is in the glass
	var/reagent_type = /datum/reagent/consumable/ethanol/beer
	var/datum/weakref/seat_ref
	var/datum/weakref/table_ref
	var/next_sip = 0

/datum/ambient_activity/drink/setup()
	var/atom/anchor = anchor()
	var/obj/structure/chair/seat
	var/obj/structure/table/table
	if(istype(anchor, /obj/structure/chair) && doer.seat_usable(anchor, failed_spots))
		seat = anchor
	else if(istype(anchor, /obj/structure/table))
		table = anchor
	if(!seat)
		seat = doer.find_seat(table || anchor || doer, AMBIENT_ACTIVITY_RANGE, TRUE, failed_spots)
	if(seat)
		if(!table || get_dist(table, seat) > 1)
			table = doer.table_beside(seat)
		seat_ref = WEAKREF(seat)
		go_to(get_turf(seat))
	else
		table = table || doer.find_table(anchor || doer, AMBIENT_ACTIVITY_RANGE, failed_spots)
		var/turf/stand = table && doer.free_tile_beside(table, 1, failed_spots)
		if(!stand)
			return FALSE
		go_to(stand)
	table_ref = table ? WEAKREF(table) : null
	set_duration()
	return TRUE

/datum/ambient_activity/drink/arrive()
	var/obj/structure/chair/seat = seat_ref?.resolve()
	var/obj/structure/table/table = table_ref?.resolve()
	if(seat && !doer.sit_on(seat))
		seat_ref = null
	if(table && !doer.buckled)
		doer.face_atom(table)
	doer.take_drink(reagent_type)
	next_sip = world.time + rand(6 SECONDS, 12 SECONDS)
	next_line = world.time + rand(10 SECONDS, 25 SECONDS)

/datum/ambient_activity/drink/act(seconds)
	if(world.time >= next_sip)
		next_sip = world.time + rand(12 SECONDS, 25 SECONDS)
		if(!doer.sip())
			return AMBIENT_STEP_DONE
	chatter()
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/drink/finish()
	if(!QDELETED(doer) && doer.held_item)
		doer.put_drink_down(table_ref?.resolve())
	return ..()

/datum/ambient_activity/drink/spot_unreachable()
	. = ..()
	seat_ref = null

/datum/ambient_activity/drink/shift_times(delay)
	. = ..()
	next_sip = ambient_shifted(next_sip, delay)

/**
 * Talking with another NPC: the one who starts it walks over; the other stops what it was doing
 * (if it may) and answers each line. The first exchange is one of the section's "conversations",
 * the rest are chat lines and replies.
 */
/datum/ambient_activity/chat
	name = "talking"
	duration_low = 40 SECONDS
	duration_high = 90 SECONDS
	var/datum/weakref/partner_ref
	/// The other side of a chat someone else started: they only answer
	var/responding = FALSE
	/// Lines left to say
	var/lines_left = 4
	/// Whether the opening exchange was had
	var/opened = FALSE

/datum/ambient_activity/chat/setup()
	var/mob/living/partner = anchor()
	if(!isliving(partner) || partner == doer || partner.stat != CONSCIOUS)
		if(responding)
			return FALSE
		partner = doer.find_chat_partner(AMBIENT_ACTIVITY_RANGE)
	if(!partner)
		return FALSE
	partner_ref = WEAKREF(partner)
	if(responding)
		// For as long as the one who started it talks
		if(!ends_at)
			set_duration()
		go_to(null)
		return TRUE
	set_duration()
	lines_left = rand(3, 6)
	// An NPC partner drops what it was doing and answers. `responding` is set before its setup runs, so it never invites back.
	if(istype(partner, /mob/living/basic/ambient_npc))
		var/mob/living/basic/ambient_npc/other = partner
		var/datum/ambient_activity/chat/answer = new(other, doer)
		answer.responding = TRUE
		answer.ends_at = ends_at + 10 SECONDS
		if(!other.start_activity(answer))
			return FALSE
	return approach()

/// Walks up beside their partner, if not there already: the nearest loiter-ok tile actually adjacent to them
/datum/ambient_activity/chat/proc/approach()
	var/mob/living/partner = partner()
	if(!partner)
		return FALSE
	if(get_dist(doer, partner) <= 1)
		go_to(null)
		return TRUE
	var/turf/center = get_turf(partner)
	if(!center)
		return FALSE
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/tile as anything in RANGE_TURFS(1, center))
		if(tile == center || !tile.Adjacent(partner) || !doer.loiter_spot_ok(tile, failed_spots, partner))
			continue
		var/from_doer = get_dist(doer, tile)
		if(from_doer < best_distance)
			best = tile
			best_distance = from_doer
	if(!best)
		return FALSE
	go_to(best)
	return TRUE

/// Who they are talking to
/datum/ambient_activity/chat/proc/partner()
	var/mob/living/partner = partner_ref?.resolve()
	return QDELETED(partner) ? null : partner

/datum/ambient_activity/chat/arrive()
	var/mob/living/partner = partner()
	if(partner && !doer.buckled)
		doer.face_atom(partner)
	next_line = world.time + rand(1 SECONDS, 3 SECONDS)

/datum/ambient_activity/chat/act(seconds)
	var/mob/living/partner = partner()
	if(!partner || partner.stat != CONSCIOUS)
		return AMBIENT_STEP_DONE
	if(responding)
		// Only while the one who started it is still talking to them
		var/mob/living/basic/ambient_npc/starter = partner
		var/datum/ambient_activity/chat/their_chat = istype(starter) ? starter.activity : null
		if(!istype(their_chat) || their_chat.partner() != doer)
			return AMBIENT_STEP_DONE
		if(get_dist(doer, partner) <= 1 && !doer.buckled)
			doer.face_atom(partner)
		return AMBIENT_STEP_CONTINUE
	if(get_dist(doer, partner) > 1)
		if(get_dist(doer, partner) > AMBIENT_ACTIVITY_RANGE || !approach())
			return AMBIENT_STEP_DONE
		return AMBIENT_STEP_MOVE
	if(!doer.buckled)
		doer.face_atom(partner)
	if(world.time < next_line)
		return AMBIENT_STEP_CONTINUE
	if(lines_left-- <= 0)
		return AMBIENT_STEP_DONE
	next_line = world.time + rand(7 SECONDS, 12 SECONDS)
	var/mob/living/basic/ambient_npc/other = istype(partner, /mob/living/basic/ambient_npc) ? partner : null
	var/list/conversation = opened ? null : doer.pick_conversation()
	opened = TRUE
	if(conversation)
		doer.say_line(doer.fill_line(conversation[1], partner))
		other?.reply_to(doer, AMBIENT_LINE_REPLY, conversation[2])
	else if(doer.speak_context(AMBIENT_LINE_CHAT, partner, force = TRUE))
		other?.reply_to(doer)
	if(prob(15))
		doer.manual_emote(pick("laughs.", "shrugs.", "nods.", "shakes [doer.p_their()] head."))
	return AMBIENT_STEP_CONTINUE

/**
 * Work at an object, with the trader mechanics' own work loop (outpost_ambient_work.dm): the job,
 * its sounds, sparks and working look. `work_weights` (or the NPC's) are
 * /datum/outpost_ambient_work types with weights; the job is found within a few tiles.
 */
/datum/ambient_activity/work
	name = "working"
	/// The kinds of work, or null for the NPC's own `work_weights`
	var/list/work_weights
	/// The worker component, on the NPC for this job only
	var/datum/component/outpost_ambient_worker/worker
	var/datum/weakref/target_ref
	var/datum/outpost_ambient_work/kind

/datum/ambient_activity/work/setup()
	var/list/weights = work_weights || doer.work_weights
	if(!length(weights) || !isturf(doer.loc))
		return FALSE
	// Its room is worked out around where they stand now, and it keeps them in it until the job is done
	worker = doer.AddComponent(/datum/component/outpost_ambient_worker, weights, TRUE, CALLBACK(doer, TYPE_PROC_REF(/mob/living/basic/ambient_npc, show_work_look)))
	// A job whose spot they keep off (a doorway, a counter's reach) is skipped for the next one found
	var/list/job
	for(var/attempt in 1 to AMBIENT_WORK_FIND_TRIES)
		job = worker?.find_work()
		if(length(job) != 3)
			job = null
			break
		if(doer.standable(job[2], failed_spots))
			break
		worker.last_target = WEAKREF(job[1])
		job = null
	if(!job)
		drop_worker()
		return FALSE
	target_ref = WEAKREF(job[1])
	kind = job[3]
	go_to(job[2])
	next_line = world.time + rand(10 SECONDS, 30 SECONDS)
	return TRUE

/datum/ambient_activity/work/Destroy()
	drop_worker()
	kind = null
	return ..()

/// Takes the worker component off again
/datum/ambient_activity/work/proc/drop_worker()
	if(QDELETED(worker))
		worker = null
		return
	var/datum/component/outpost_ambient_worker/old = worker
	worker = null
	old.stop_work()
	qdel(old)
	if(!QDELETED(doer) && doer.work_look)
		doer.show_work_look(null)

/datum/ambient_activity/work/arrive()
	var/atom/target = target_ref?.resolve()
	if(QDELETED(worker) || QDELETED(target))
		return
	worker.planned_work = kind
	worker.start_work(target)

/datum/ambient_activity/work/act(seconds)
	if(QDELETED(worker) || !worker.continue_work())
		return AMBIENT_STEP_DONE
	chatter(AMBIENT_LINE_WORK, 30 SECONDS, 60 SECONDS)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/work/finish()
	drop_worker()
	return ..()

/datum/ambient_activity/work/spot_unreachable()
	. = ..()
	drop_worker()

// Found mid-job: the job has less of it left
/datum/ambient_activity/work/settle()
	. = ..()
	if(!QDELETED(worker))
		worker.work_ends_at = ambient_part_way(worker.work_ends_at)

/datum/ambient_activity/work/shift_times(delay)
	. = ..()
	if(!QDELETED(worker))
		worker.work_ends_at = ambient_shifted(worker.work_ends_at, delay)
		worker.next_work_at = ambient_shifted(worker.next_work_at, delay)

/**
 * Leaving: to their place's exit (a trader outpost's hangar lift), then they fade. Anyone who can't
 * get there, or is still walking after AMBIENT_LEAVE_TIMEOUT, fades where they are. `delay` keeps
 * them where they are (ducking) that long first.
 */
/datum/ambient_activity/leave
	name = "leaving"
	priority = AMBIENT_PRIORITY_LEAVE
	/// world.time they set off
	var/wait_until = 0
	/// world.time they give up walking and fade where they are
	var/give_up_at = 0

/datum/ambient_activity/leave/New(mob/living/basic/ambient_npc/new_doer, atom/anchor, delay = 0)
	. = ..()
	wait_until = world.time + delay

/datum/ambient_activity/leave/setup()
	give_up_at = wait_until + AMBIENT_LEAVE_TIMEOUT
	var/turf/exit = get_turf(anchor()) || doer.place?.exit_turf(doer)
	go_to(exit)
	return TRUE

// Stays put while ducking
/datum/ambient_activity/leave/at_spot()
	if(world.time < wait_until)
		return TRUE
	return ..()

/datum/ambient_activity/leave/act(seconds)
	if(world.time < wait_until)
		return AMBIENT_STEP_CONTINUE
	if(doer.crouching || doer.buckled)
		doer.stand_up()
	if(!spot || at_spot() || world.time >= give_up_at)
		doer.fade_out()
		return AMBIENT_STEP_CONTINUE
	return AMBIENT_STEP_MOVE

/datum/ambient_activity/leave/spot_unreachable()
	doer.fade_out()

/datum/ambient_activity/leave/shift_times(delay)
	. = ..()
	wait_until = ambient_shifted(wait_until, delay)
	give_up_at = ambient_shifted(give_up_at, delay)

/// Back onto their leash, to where they were made
/datum/ambient_activity/go_home
	name = "heading back"
	priority = AMBIENT_PRIORITY_REACTION

/datum/ambient_activity/go_home/setup()
	var/turf/target = doer.home
	if(!target || !doer.leash_ok(target))
		return FALSE
	go_to(target, 1)
	return TRUE

/datum/ambient_activity/go_home/act(seconds)
	return AMBIENT_STEP_DONE

/datum/ambient_activity/go_home/spot_unreachable()
	doer.give_up_leash()

/// Heads down somewhere out of the line of fire until it is over (the kingpin's shootout)
/datum/ambient_activity/take_cover
	name = "taking cover"
	priority = AMBIENT_PRIORITY_REACTION
	duration_low = 4 MINUTES
	duration_high = 5 MINUTES

/datum/ambient_activity/take_cover/setup()
	var/turf/refuge = get_turf(anchor())
	if(!refuge)
		return FALSE
	set_duration()
	var/datum/ambient_place/outpost/outpost_place = istype(doer.place, /datum/ambient_place/outpost) ? doer.place : null
	var/obj/structure/overmap/trader_outpost/outpost = outpost_place?.outpost()
	var/turf/fight = outpost ? ambient_kingpin_fight_center(outpost) : null
	var/turf/doer_turf = get_turf(doer)
	if(fight && doer_turf && (fight.z != doer_turf.z || get_dist(fight, doer_turf) > AMBIENT_VIOLENCE_RANGE || !can_see(fight, doer_turf, AMBIENT_VIOLENCE_RANGE + 1)))
		// Out of sight or out of range of the actual fight: duck where they are
		go_to(null)
		return TRUE
	var/turf/stand
	// Cover goes by who stands on or is heading to a tile, not by the crowd around it
	if(doer.standable(refuge, failed_spots, TRUE) && !(outpost_place && outpost_place.crowd_count(refuge, doer) == INFINITY))
		stand = refuge
	else
		var/list/candidates = list()
		for(var/turf/tile as anything in RANGE_TURFS(AMBIENT_COVER_SPREAD, refuge))
			if(tile == refuge || !doer.standable(tile, failed_spots, TRUE) || !can_see(refuge, tile, AMBIENT_COVER_SPREAD + 1))
				continue
			if(outpost_place && outpost_place.crowd_count(tile, doer) == INFINITY)
				continue
			candidates += tile
		stand = length(candidates) ? pick(candidates) : null
	go_to(stand)
	return TRUE

/datum/ambient_activity/take_cover/arrive()
	doer.crouch()

/datum/ambient_activity/take_cover/act(seconds)
	var/datum/ambient_place/outpost/outpost_place = doer.place
	if(istype(outpost_place) && !outpost_place.shootout_refuge)
		return AMBIENT_STEP_DONE
	return AMBIENT_STEP_CONTINUE

/// Waits out a storm: in their shelter if they have one, or crouched where they are
/datum/ambient_activity/shelter
	name = "sheltering"
	priority = AMBIENT_PRIORITY_REACTION
	/// How long the storm lasts
	var/duration = 2 MINUTES

/datum/ambient_activity/shelter/New(mob/living/basic/ambient_npc/new_doer, atom/anchor, duration)
	. = ..()
	if(duration)
		src.duration = duration

/datum/ambient_activity/shelter/setup()
	var/turf/shelter = get_turf(anchor())
	if(shelter)
		go_to(doer.standable(shelter, failed_spots, TRUE) ? shelter : doer.free_tile_beside(shelter, 2, failed_spots, TRUE))
	ends_at = world.time + duration
	return TRUE

/datum/ambient_activity/shelter/arrive()
	doer.crouch()
