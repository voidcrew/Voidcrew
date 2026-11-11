/**
 * # Stealth patrols
 *
 * A template maps one group marker (/obj/effect/landmark/stealth_group) and any number of patrol points
 * (/obj/effect/landmark/stealth_patrol). Points and guards belong to the nearest marker in their own map
 * region within STEALTH_GROUP_RADIUS, so two dens on one packed planet never share routes (abuse R1).
 * Nothing is matched by z-level alone, and no group processes on a timer.
 *
 * A guard claims the route with a stop within STEALTH_ROUTE_CLAIM_RANGE of where it spawned, starting at
 * that stop. With none in range it is a sentry at its spawn turf, facing the way the spawner faced.
 *
 * A guard drawn off its route or post (a chase, a search) walks back, however far. One that can't get back
 * waits and tries again. Only being carried to another level or map region makes it a sentry where it is.
 */

/// Every live patrol group
GLOBAL_LIST_EMPTY(stealth_groups)
/// Patrol points not yet handed to a group
GLOBAL_LIST_EMPTY(stealth_unassigned_points)

/datum/stealth_stop
	var/turf/spot
	var/wait = STEALTH_PATROL_DEFAULT_WAIT
	var/dir = SOUTH
	var/chatter = FALSE
	var/order = 0

/datum/stealth_group
	/// A unique id, for admins
	var/id
	/// Weakref to its map region (a footprint or reservation), or null on an unpacked level
	var/datum/weakref/region_ref
	/// Whether its region was null when made (so a null region is a match, not a lost one)
	var/no_region = FALSE
	/// Where its marker stood
	var/turf/home
	/// Its marker, while it exists
	var/obj/effect/landmark/stealth_group/marker
	/// Route id => list of /datum/stealth_stop in order
	var/list/routes = list()
	/// Route id => "loop" or "pingpong"
	var/list/route_modes = list()
	/// Weakrefs to its guards
	var/list/datum/weakref/members = list()
	/// REFs of fallen members someone has already reported
	var/list/reported_bodies = list()
	/// world.time chatter is next allowed
	var/next_chatter = 0

GLOBAL_VAR_INIT(stealth_group_count, 0)

/datum/stealth_group/New(turf/where)
	id = "group-[++GLOB.stealth_group_count]"
	home = where
	var/datum/region = map_region_for_turf(where)
	if(region)
		region_ref = WEAKREF(region)
	else
		no_region = TRUE
	GLOB.stealth_groups += src
	RegisterSignal(SSdcs, COMSIG_GLOB_EXPLOSION, PROC_REF(on_explosion))

/datum/stealth_group/Destroy()
	GLOB.stealth_groups -= src
	UnregisterSignal(SSdcs, COMSIG_GLOB_EXPLOSION)
	noise_stamps = null
	lures = null
	alarms = null
	checks = null
	noise_notes = null
	if(marker)
		marker.group = null
		marker = null
	members = null
	routes = null
	home = null
	return ..()

/// Whether `tile` is in this group's map region.
/datum/stealth_group/proc/region_matches(turf/tile)
	var/datum/region = map_region_for_turf(tile)
	if(no_region)
		return isnull(region)
	return !isnull(region) && region == region_ref?.resolve()

/datum/stealth_group/proc/add_member(mob/living/guard)
	members |= WEAKREF(guard)

/datum/stealth_group/proc/remove_member(mob/living/guard)
	if(isnull(members))
		return
	members -= WEAKREF(guard)
	prune()

/// Its guards that still exist.
/datum/stealth_group/proc/living_members()
	. = list()
	for(var/datum/weakref/ref as anything in members?.Copy())
		var/mob/living/guard = ref?.resolve()
		if(QDELETED(guard))
			members -= ref
			continue
		. += guard

/// Removes the group once its marker and every member are gone.
/datum/stealth_group/proc/prune()
	if(QDELETED(src))
		return
	if(marker || length(living_members()))
		return
	qdel(src)

/datum/stealth_group/proc/add_point(obj/effect/landmark/stealth_patrol/point)
	var/datum/stealth_stop/stop = new
	stop.spot = get_turf(point)
	stop.wait = point.wait < 0 ? STEALTH_PATROL_DEFAULT_WAIT : point.wait
	stop.dir = point.dir
	stop.chatter = point.chatter
	stop.order = point.order
	var/list/route = routes[point.route]
	if(isnull(route))
		routes[point.route] = route = list()
	var/index = 1
	while(index <= length(route))
		var/datum/stealth_stop/other = route[index]
		if(other.order > stop.order)
			break
		index++
	route.Insert(index, stop)
	if(point.order == 1 || isnull(route_modes[point.route]))
		route_modes[point.route] = point.route_mode

/// The nearest group to `tile` in its own region within STEALTH_GROUP_RADIUS, or null.
/proc/stealth_group_for(turf/tile)
	if(isnull(tile))
		return null
	stealth_assign_points()
	var/datum/stealth_group/best
	var/best_dist = INFINITY
	for(var/datum/stealth_group/group as anything in GLOB.stealth_groups)
		if(group.home?.z != tile.z)
			continue
		var/dist = get_dist(group.home, tile)
		if(dist > STEALTH_GROUP_RADIUS || dist >= best_dist || !group.region_matches(tile))
			continue
		best = group
		best_dist = dist
	return best

/// Hands every loaded patrol point to its group. Points with no group yet wait for one.
/proc/stealth_assign_points()
	for(var/obj/effect/landmark/stealth_patrol/point as anything in GLOB.stealth_unassigned_points)
		if(QDELETED(point))
			GLOB.stealth_unassigned_points -= point
			continue
		var/turf/spot = get_turf(point)
		var/datum/stealth_group/best
		var/best_dist = INFINITY
		for(var/datum/stealth_group/group as anything in GLOB.stealth_groups)
			if(group.home?.z != spot?.z || !group.marker)
				continue
			var/dist = get_dist(group.home, spot)
			if(dist > STEALTH_GROUP_RADIUS || dist >= best_dist || !group.region_matches(spot))
				continue
			best = group
			best_dist = dist
		if(best)
			best.add_point(point)
			GLOB.stealth_unassigned_points -= point

// ===== Landmarks =====

/// One per template: the patrol group its points and guards join.
/obj/effect/landmark/stealth_group
	name = "stealth patrol group"
	icon_state = "x"
	var/datum/stealth_group/group

/obj/effect/landmark/stealth_group/Initialize(mapload)
	. = ..()
	group = new(get_turf(src))
	group.marker = src

/obj/effect/landmark/stealth_group/Destroy()
	var/datum/stealth_group/old = group
	group = null
	if(old)
		old.marker = null
		old.prune()
	return ..()

/// A stop on a guard route. Its dir is the way the guard faces there.
/obj/effect/landmark/stealth_patrol
	name = "stealth patrol point"
	icon_state = "x3"
	/// The route it belongs to ("a", "b", ...)
	var/route = "a"
	/// Its place on the route, from 1
	var/order = 1
	/// Deciseconds to stand here; -1 for STEALTH_PATROL_DEFAULT_WAIT, 0 to walk straight through
	var/wait = -1
	/// TRUE: guards here talk to each other
	var/chatter = FALSE
	/// "loop" or "pingpong", read from the order 1 point
	var/route_mode = "loop"

/obj/effect/landmark/stealth_patrol/Initialize(mapload)
	. = ..()
	GLOB.stealth_unassigned_points += src

/obj/effect/landmark/stealth_patrol/Destroy()
	GLOB.stealth_unassigned_points -= src
	return ..()

// ===== Guards on routes =====

/// Joins a group and claims a route, once, on its first plan (after its map has loaded).
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_setup()
	if(stealth_ready)
		return
	stealth_ready = TRUE
	var/mob/living/guard = pawn
	var/turf/spawn_turf = get_turf(guard)
	// Its skill comes from where it starts (decision 38), settled now, before it walks anywhere.
	stealth_skill()
	home_turf = spawn_turf
	sentry_dir = stealth_facing(guard)
	stand_dir = sentry_dir
	// A sentry's first look aside comes after a full turn at its post, not on its first step.
	next_turn = world.time + STEALTH_SENTRY_TURN_INTERVAL
	group = stealth_group_for(spawn_turf)
	if(isnull(group))
		group = new(spawn_turf)
	group.add_member(guard)
	// The route with a stop nearest its spawn, within reach.
	var/best_dist = INFINITY
	for(var/route in group.routes)
		var/list/stops = group.routes[route]
		for(var/index in 1 to length(stops))
			var/datum/stealth_stop/stop = stops[index]
			var/dist = get_dist(stop.spot, spawn_turf)
			if(dist > STEALTH_ROUTE_CLAIM_RANGE || dist >= best_dist)
				continue
			best_dist = dist
			route_id = route
			route_index = index
	if(route_id)
		var/datum/stealth_stop/start = group.routes[route_id][route_index]
		home_turf = start.spot

/// Drops its route and holds `where` as a sentry from now on: it was carried off its level or out of its
/// region (abuse R3). A guard that only walked or was chased away keeps its route and walks back.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_become_sentry(turf/where)
	route_id = null
	at_stop = FALSE
	home_retry_at = 0
	stealth_drop_walk()
	if(where)
		home_turf = where
	sentry_dir = stealth_facing(pawn)
	stand_dir = sentry_dir
	next_turn = world.time + STEALTH_SENTRY_TURN_INTERVAL

/// Its route's stops, or null.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_stops()
	if(isnull(route_id) || isnull(group))
		return null
	return group.routes[route_id]

/// Back from a suspicion, a search or a chase: heads for the nearest stop of its route it can still try.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_rejoin_route()
	at_stop = FALSE
	wait_until = 0
	home_retry_at = 0
	var/list/stops = stealth_stops()
	if(!length(stops))
		return
	var/turf/here = get_turf(pawn)
	var/best_dist = INFINITY
	for(var/index in 1 to length(stops))
		if(world.time < stop_skip_until["[index]"])
			continue
		var/datum/stealth_stop/stop = stops[index]
		var/dist = get_dist(stop.spot, here)
		if(dist < best_dist)
			best_dist = dist
			route_index = index

/// The next stop after the current one that isn't being skipped, or 0 if every stop is skipped.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_next_index()
	var/list/stops = stealth_stops()
	var/count = length(stops)
	if(!count)
		return 0
	var/pingpong = group.route_modes[route_id] == "pingpong"
	var/index = route_index
	for(var/tries in 1 to count * 2)
		index += route_step
		if(index > count || index < 1)
			if(pingpong && count > 1)
				route_step = -route_step
				index += route_step * 2
			else
				index = index > count ? 1 : count
		if(world.time >= stop_skip_until["[index]"])
			return index
	return 0

/**
 * A walk the pathfinder gave up on (abuse R2). A stop that fails often enough is skipped for a while; with
 * every stop skipped it waits where it is and tries again when the first skip runs out. A sentry that can't
 * reach its post waits and tries again too. Neither gives up its route or post for good: only being carried
 * off does that.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_walk_failed()
	if(goto_purpose == STEALTH_GOTO_HOME)
		home_retry_at = world.time + STEALTH_HOME_RETRY_TIME
		return
	if(goto_purpose != STEALTH_GOTO_PATROL || isnull(route_id))
		return
	var/key = "[route_index]"
	stop_fails[key]++
	if(stop_fails[key] < STEALTH_PATROL_MAX_FAILS)
		return
	stop_fails[key] = 0
	stop_skip_until[key] = world.time + STEALTH_PATROL_SKIP_TIME
	var/next = stealth_next_index()
	if(next)
		route_index = next

/// Unaware with no target: walks its route or holds its post. Last in the list: it always leaves the guard
/// something to do, so planning never comes up empty.
/datum/ai_planning_subtree/stealth_patrol

/datum/ai_planning_subtree/stealth_patrol/SelectBehaviors(datum/ai_controller/basic_controller/human_npc/stealth/controller, seconds_per_tick)
	if(!istype(controller))
		return
	var/mob/living/guard = controller.pawn
	if(guard.stat != CONSCIOUS)
		return
	if(controller.stealth_state() == STEALTH_UNAWARE && !controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		// Glancing at a noise, or holding for one: it stops and faces it, then carries on.
		if(world.time < controller.glance_until)
			controller.stealth_drop_walk()
			controller.next_turn = controller.glance_until
			if(guard.dir != controller.glance_dir)
				guard.setDir(controller.glance_dir)
			controller.queue_behavior(/datum/ai_behavior/stealth_stand)
			return SUBTREE_RETURN_FINISH_PLANNING
		if(length(controller.stealth_stops()))
			controller.stealth_plan_route()
		else
			controller.stealth_plan_post()
	// Alert with nobody in reach of the fighting subtrees, or holding: it stands and looks about.
	if(!length(controller.planned_behaviors))
		controller.queue_behavior(/datum/ai_behavior/stealth_stand)
	return SUBTREE_RETURN_FINISH_PLANNING

/// A sentry: stands its post, or walks back to it.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_plan_post()
	var/mob/living/guard = pawn
	var/turf/here = get_turf(guard)
	route_id = null
	var/turf/post = home_turf
	if(post && here != post)
		if(post.z != here.z || map_region_for_turf(post) != map_region_for_turf(here))
			// Carried off: this is its post now.
			stealth_become_sentry(here)
		else if(world.time >= home_retry_at)
			if(stealth_walk_gave_up(post))
				stealth_drop_walk()
			if(!stealth_walk_arrived(post))
				stealth_walk(post, STEALTH_GOTO_HOME)
				return
	stand_dir = sentry_dir
	queue_behavior(/datum/ai_behavior/stealth_stand)

/// A route guard: waits at its stop, then walks to the next one it can reach.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_plan_route()
	var/mob/living/guard = pawn
	var/turf/here = get_turf(guard)
	var/list/stops = stealth_stops()
	if(at_stop)
		if(world.time < wait_until)
			queue_behavior(/datum/ai_behavior/stealth_stand)
			return
		var/next = stealth_next_index()
		if(!next)
			// Every other stop is shut off: it stays here until one opens.
			queue_behavior(/datum/ai_behavior/stealth_stand)
			return
		at_stop = FALSE
		route_index = next
	if(world.time < stop_skip_until["[route_index]"])
		var/next = stealth_next_index()
		if(!next)
			// Shut in: it waits, and tries again when the first skip runs out.
			stand_dir = stealth_facing(guard)
			queue_behavior(/datum/ai_behavior/stealth_stand)
			return
		route_index = next
	var/datum/stealth_stop/stop = stops[route_index]
	// Leash (abuse R3): a stop on another level or in another region means it was carried off.
	if(stop.spot.z != here.z || !group.region_matches(here))
		stealth_become_sentry(here)
		queue_behavior(/datum/ai_behavior/stealth_stand)
		return
	if(stealth_walk_arrived(stop.spot))
		stealth_drop_walk()
		stealth_arrive(stop)
		queue_behavior(/datum/ai_behavior/stealth_stand)
		return
	// A failed try that hasn't yet shut the stop off: it tries again.
	if(stealth_walk_gave_up(stop.spot))
		stealth_drop_walk()
	stealth_walk(stop.spot, STEALTH_GOTO_PATROL)

/// At a stop: faces its way, waits, and talks if it's a chatter stop and a friend is near.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_arrive(datum/stealth_stop/stop)
	at_stop = TRUE
	home_turf = stop.spot
	stop_fails["[route_index]"] = 0
	wait_until = world.time + stop.wait
	stand_dir = stop.dir
	pawn.setDir(stop.dir)
	next_turn = world.time + STEALTH_LOOK_TURN_INTERVAL
	if(!stop.chatter || world.time < group.next_chatter)
		return
	var/mob/living/guard = pawn
	for(var/mob/living/friend as anything in group.living_members())
		if(friend == guard || friend.stat != CONSCIOUS || get_dist(friend, guard) > STEALTH_CHATTER_RANGE)
			continue
		var/datum/ai_controller/basic_controller/human_npc/stealth/friend_ai = friend.ai_controller
		if(!istype(friend_ai) || friend_ai.stealth_state() != STEALTH_UNAWARE)
			continue
		group.next_chatter = world.time + STEALTH_CHATTER_COOLDOWN
		var/datum/ai_controller/basic_controller/human_npc/stealth/speaker = pick(src, friend_ai)
		speaker.stealth_bark(STEALTH_BARK_CHATTER)
		return
