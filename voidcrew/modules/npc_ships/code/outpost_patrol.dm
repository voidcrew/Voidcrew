/**
 * # Outpost patrols
 *
 * The boarding patrol from mob_patrol.dm, pointed at a player outpost instead of a ship. Prisoners
 * who break out of an outpost's prison wing walk it door to door, search the rooms in between and
 * fight anyone who is not another prisoner (/datum/ai_controller/basic_controller/outpost_breakout).
 *
 * The patrol subtrees use BB_MOB_PATROL_SHIP_REF only as a key into the room tables
 * (GLOB.ship_rooms, GLOB.turf_to_room, GLOB.door_to_rooms). An outpost patrol files its rooms there
 * under REF(outpost), so those subtrees run unchanged.
 *
 * Doors come from the outpost's own area and every installed upgrade's area on the main level
 * (outpost_owned_turfs()). Each outpost has one path list, shared by all of its patrollers and
 * rebuilt in place when the doors change. The path holds at most OUTPOST_PATROL_MAX_STOPS doors,
 * the ones nearest the prison wing. Looking for doors and rebuilding walk every tile the outpost
 * owns, so both yield whenever the tick is full; callers on a subsystem use
 * assign_mob_to_outpost_patrol_async(), since a sleep there stalls the whole subsystem. A door or
 * locker that is deleted is dropped from the path and the room tables straight away, so nothing
 * keeps it from being garbage collected.
 */

/// Other code can test for this API with #ifdef. Keep it defined.
#define OUTPOST_PATROL_API

/// How long a checked door list is trusted before the next assignment looks for new doors
#define OUTPOST_PATROL_RECHECK (5 SECONDS)
/// The most doors a patrol path visits: the ones nearest where the patrol starts
#define OUTPOST_PATROL_MAX_STOPS 40

/// Patrol caches by REF(outpost)
GLOBAL_LIST_EMPTY(outpost_patrol_caches)

// ===== API =====

/**
 * Puts `pawn` on its outpost's door-to-door patrol. The pawn needs a controller that runs the
 * patrol subtrees, such as /datum/ai_controller/basic_controller/outpost_breakout.
 * Returns TRUE when the pawn is patrolling; FALSE when the outpost has no interior doors to visit,
 * or when the pawn changed controller while the doors were being found. Sleeps on a big outpost.
 */
/proc/assign_mob_to_outpost_patrol(mob/living/pawn, obj/structure/overmap/dynamic/player_outpost/outpost)
	if(QDELETED(pawn) || QDELETED(outpost))
		return FALSE
	var/datum/ai_controller/controller = pawn.ai_controller
	if(!controller)
		return FALSE
	var/list/path = get_outpost_patrol_path(outpost)
	// Recaptured (a new controller) or deleted while the lookup yielded: not wanted on patrol any more.
	if(QDELETED(pawn) || pawn.ai_controller != controller || QDELETED(outpost))
		return FALSE
	if(!length(path))
		return FALSE
	var/key = REF(outpost)

	clear_all_patrol_state(controller)
	// Set directly, as assign_mob_to_patrol() does: every patroller shares the cached list.
	controller.blackboard[BB_MOB_PATROL_PATH] = path
	controller.blackboard[BB_MOB_PATROL_SHIP_REF] = key

	// Start at the nearest door, staggered so a crowd does not queue at one door
	var/turf/pawn_turf = get_turf(pawn)
	var/start_index = 1
	var/best_distance = INFINITY
	if(pawn_turf)
		for(var/index in 1 to length(path))
			var/obj/machinery/door/door = path[index]
			if(QDELETED(door))
				continue
			var/distance = get_dist(pawn_turf, door)
			if(distance < best_distance)
				best_distance = distance
				start_index = index
	var/stagger = GLOB.patrol_stagger_counter[key] || 0
	GLOB.patrol_stagger_counter[key] = stagger + 1
	controller.blackboard[BB_MOB_PATROL_INDEX] = ((start_index - 1 + stagger * 3) % length(path)) + 1

	// Nobody breaking out has access: doors that need it are attacked, not bumped
	var/list/locked_doors = GLOB.boarding_locked_doors[key]
	if(length(locked_doors))
		controller.blackboard["_failed_blocking_doors"] = locked_doors.Copy()

	var/starting_room = get_room_for_turf(pawn_turf, key)
	if(starting_room)
		controller.set_blackboard_key(BB_LAST_KNOWN_ROOM, starting_room)
		maybe_start_room_exploration(controller, starting_room, key)
	return TRUE

/// assign_mob_to_outpost_patrol() without holding up the caller while the doors are found
/proc/assign_mob_to_outpost_patrol_async(mob/living/pawn, obj/structure/overmap/dynamic/player_outpost/outpost)
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(assign_mob_to_outpost_patrol), pawn, outpost)

/**
 * Takes `pawn` off whatever patrol it is on: stops what it is doing and clears every blackboard
 * key the patrol, its door handling, room searches and fighting set. Returns FALSE with no controller.
 */
/proc/clear_outpost_patrol(mob/living/pawn)
	var/datum/ai_controller/controller = pawn?.ai_controller
	if(!controller)
		return FALSE
	controller.CancelActions()
	for(var/key in outpost_patrol_blackboard_keys())
		controller.clear_blackboard_key(key)
	return TRUE

/// Every blackboard key an outpost patrol and the breakout controller's fighting can set
/proc/outpost_patrol_blackboard_keys()
	var/static/list/keys = list(
		BB_MOB_PATROL_PATH,
		BB_MOB_PATROL_INDEX,
		BB_MOB_PATROL_TARGET,
		BB_MOB_PATROL_SHIP_REF,
		BB_MOB_PATROL_TARGET_TURF,
		BB_MOB_PATROL_ORIGIN_ROOM,
		BB_DOOR_TO_OPEN,
		BB_LAST_KNOWN_ROOM,
		BB_EXPLORED_ROOMS,
		BB_EXPLORING_ROOM,
		BB_EXPLORATION_TARGETS,
		BB_EXPLORATION_INDEX,
		BB_EXPLORATION_TARGET,
		BB_BASIC_MOB_CURRENT_TARGET,
		"_patrol_door_start_time",
		"_patrol_last_dist",
		"_patrol_assembly_to_attack",
		"_patrol_started_logged",
		"_last_crossed_door",
		"_failed_blocking_doors",
		"_skipped_blocking_doors",
		"_blocking_door_attack_times",
		"_blocking_door_to_open",
		"_blocking_door_to_attack",
		"_blocking_assembly_to_attack",
		"_blocking_obstacle_to_attack",
	)
	return keys

/// The outpost `pawn` is patrolling, or null
/proc/outpost_patrol_of(mob/living/pawn)
	var/datum/ai_controller/controller = pawn?.ai_controller
	if(!controller)
		return null
	var/key = controller.blackboard[BB_MOB_PATROL_SHIP_REF]
	if(!istext(key))
		return null
	var/datum/outpost_patrol_cache/cache = GLOB.outpost_patrol_caches[key]
	return cache?.outpost

/**
 * The outpost's patrol path: doors in visiting order. The list is shared with every patroller and
 * changed only in place. Rebuilt when the doors changed; `force_check` looks for new doors even if
 * the last look was recent.
 */
/proc/get_outpost_patrol_path(obj/structure/overmap/dynamic/player_outpost/outpost, force_check = FALSE)
	if(QDELETED(outpost))
		return null
	var/datum/outpost_patrol_cache/cache = GLOB.outpost_patrol_caches[REF(outpost)]
	if(!cache)
		cache = new(outpost)
	return cache.get_path(force_check)

/**
 * Replaces a basic mob's AI controller with a new one of `controller_type`. What the old controller
 * was doing is cancelled first; the old controller and its blackboard are deleted. Returns the new
 * controller, or null if it could not take the mob.
 */
/proc/swap_basic_ai_controller(mob/living/basic/pawn, controller_type)
	if(QDELETED(pawn) || !ispath(controller_type, /datum/ai_controller))
		return null
	var/datum/ai_controller/old_controller = pawn.ai_controller
	if(old_controller?.type == controller_type)
		return old_controller
	old_controller?.CancelActions()
	// PossessPawn() deletes the old controller and sets the new one's status.
	var/datum/ai_controller/new_controller = new controller_type(pawn)
	if(QDELETED(new_controller) || pawn.ai_controller != new_controller)
		return null
	return new_controller

/// Whether a door shares its tile with furniture, like a serving hatch's windoors on their table
/proc/door_on_furniture(obj/machinery/door/door)
	for(var/obj/structure/furniture in get_turf(door))
		if(furniture.density)
			return TRUE
	return FALSE

/// Whether a breakout controller leaves `target` alone: prisoners, and anyone else breaking out
/proc/is_outpost_breakout_ally(mob/living/target)
	if(istype(target, /mob/living/basic/outpost_prisoner))
		return TRUE
	return istype(target?.ai_controller, /datum/ai_controller/basic_controller/outpost_breakout)

// ===== PATH CACHE =====

/datum/outpost_patrol_cache
	/// The outpost the path runs through
	var/obj/structure/overmap/dynamic/player_outpost/outpost
	/// REF(outpost): the room tables' key and the patrollers' BB_MOB_PATROL_SHIP_REF
	var/key
	/// Doors in visiting order. Patrollers hold this very list, so it only changes in place.
	var/list/path = list()
	/// Every interior door at the last build (door = TRUE), on the path or not
	var/list/doors = list()
	/// Doors and lockers the path and room tables hold (atom = TRUE), watched for deletion
	var/list/watched = list()
	/// A door went away since the last build
	var/dirty = TRUE
	/// world.time of the last look for doors
	var/checked_at = 0
	/// world.time a look for doors or a rebuild started, while one is running (both can yield); callers get the current path meanwhile
	var/rebuilding = 0

/datum/outpost_patrol_cache/New(obj/structure/overmap/dynamic/player_outpost/owner)
	. = ..()
	outpost = owner
	key = REF(owner)
	GLOB.outpost_patrol_caches[key] = src
	RegisterSignal(owner, COMSIG_QDELETING, PROC_REF(on_outpost_deleted))

/datum/outpost_patrol_cache/Destroy()
	unwatch_all()
	if(GLOB.outpost_patrol_caches[key] == src)
		GLOB.outpost_patrol_caches -= key
	GLOB.ship_rooms -= key
	GLOB.turf_to_room -= key
	GLOB.door_to_rooms -= key
	GLOB.boarding_locked_doors -= key
	GLOB.patrol_stagger_counter -= key
	// Patrollers still holding the list find it empty and stop.
	path.Cut()
	doors = null
	outpost = null
	return ..()

/datum/outpost_patrol_cache/proc/on_outpost_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/datum/outpost_patrol_cache/proc/get_path(force_check)
	if(QDELETED(outpost))
		return null
	// A rebuild that runtimed never finished: after a minute, it no longer holds the others up.
	if(rebuilding && world.time < rebuilding + 1 MINUTES)
		// Someone else is looking. Use the current path, or with none yet, wait for theirs, so a
		// crowd breaking out together all get the first one.
		var/started = rebuilding
		while(!length(path) && rebuilding == started && world.time < started + 1 MINUTES && !QDELETED(src))
			stoplag()
		return QDELETED(src) ? null : path
	if(!dirty && !force_check && world.time < checked_at + OUTPOST_PATROL_RECHECK)
		return path
	checked_at = world.time
	rebuilding = world.time
	var/list/owned = list()
	for(var/turf/owned_turf as anything in outpost.outpost_owned_turfs())
		if(!isspaceturf(owned_turf))
			owned[owned_turf] = TRUE
		CHECK_TICK
	if(QDELETED(src))
		return null
	var/list/found = find_interior_doors(owned)
	if(QDELETED(src))
		return null
	if(dirty || !same_doors(found))
		rebuild(owned, found)
	if(QDELETED(src))
		return null
	rebuilding = 0
	return path

/// Whether `found` (door = TRUE) is the same set as the last build's
/datum/outpost_patrol_cache/proc/same_doors(list/found)
	if(length(found) != length(doors))
		return FALSE
	for(var/door in found)
		if(!doors[door])
			return FALSE
	return TRUE

/**
 * Interior doors on `owned` ground (door = TRUE), leaving out what the ship patrol leaves out:
 * firedoors, blast doors and shutters, external airlocks, and doors that open onto space or onto
 * ground that is not the outpost's.
 */
/datum/outpost_patrol_cache/proc/find_interior_doors(list/owned)
	var/list/found = list()
	for(var/turf/door_turf as anything in owned)
		for(var/obj/machinery/door/door in door_turf)
			if(istype(door, /obj/machinery/door/firedoor) || istype(door, /obj/machinery/door/poddoor) || istype(door, /obj/machinery/door/airlock/external))
				continue
			if(findtext(door.name, "external"))
				continue
			var/opens_outside = FALSE
			for(var/direction in GLOB.cardinals)
				var/turf/beside = get_step(door_turf, direction)
				if(!beside || !owned[beside])
					opens_outside = TRUE
					break
			if(!opens_outside)
				found[door] = TRUE
		CHECK_TICK
	return found

/// Whether a window or grille stands on a tile, making it wall between rooms rather than floor
/datum/outpost_patrol_cache/proc/room_divider_on(turf/tile)
	for(var/obj/structure/divider in tile)
		if(divider.density && (istype(divider, /obj/structure/window) || istype(divider, /obj/structure/grille)))
			return TRUE
	return FALSE

/**
 * Splits `owned` into rooms, with every interior door as a wall between them, files them in the
 * shared room tables, and orders the doors into a path. A door on furniture parts rooms but is
 * never a stop. The path keeps the OUTPOST_PATROL_MAX_STOPS stops nearest patrol_origin() and
 * starts at the nearest of them. After that, stops a patroller can reach through the rooms come
 * first, nearest first; the rest are appended nearest first, and JPS finds a way or the patrol
 * times out on them. Yields on a big outpost; the old path stays in use until the new one is done.
 */
/datum/outpost_patrol_cache/proc/rebuild(list/owned, list/interior)
	unwatch_all()
	dirty = FALSE
	doors = interior

	var/list/rooms = list()
	var/list/turf_rooms = list()
	var/list/door_rooms = list()
	GLOB.ship_rooms[key] = rooms
	GLOB.turf_to_room[key] = turf_rooms
	GLOB.door_to_rooms[key] = door_rooms

	var/list/door_turfs = list()
	for(var/obj/machinery/door/door as anything in interior)
		var/turf/door_turf = get_turf(door)
		if(door_turf && !door_turfs[door_turf])
			door_turfs[door_turf] = door
		CHECK_TICK

	// Rooms: flood fills that stop at doors, walls, windows and grilles (compute_ship_rooms() rules)
	var/list/cardinal_dirs = GLOB.cardinals
	var/list/placed = list()
	var/room_count = 0
	for(var/turf/start_turf as anything in owned)
		// Most tiles are already placed or are wall; skipping tens of thousands still takes time.
		CHECK_TICK
		if(placed[start_turf] || door_turfs[start_turf] || start_turf.density || room_divider_on(start_turf))
			continue
		room_count++
		var/room_id = "room_[room_count]"
		var/list/room_turfs = list()
		var/list/room_closets = list()
		var/list/room_doors = list()
		var/list/queue = list(start_turf)
		var/list/queued = list()
		queued[start_turf] = TRUE
		var/queue_index = 1
		while(queue_index <= length(queue))
			var/turf/current = queue[queue_index]
			queue_index++
			var/obj/machinery/door/door_here = door_turfs[current]
			if(door_here)
				room_doors |= door_here
				continue
			room_turfs += current
			placed[current] = TRUE
			turf_rooms[REF(current)] = room_id
			for(var/obj/structure/closet/closet in current)
				room_closets |= closet
			for(var/direction in cardinal_dirs)
				var/turf/neighbour = get_step(current, direction)
				if(!neighbour || queued[neighbour] || !owned[neighbour])
					continue
				var/is_door_turf = !!door_turfs[neighbour]
				if(neighbour.density && !is_door_turf)
					continue
				if(!is_door_turf && room_divider_on(neighbour))
					continue
				queued[neighbour] = TRUE
				queue += neighbour
			CHECK_TICK
		rooms[room_id] = list(
			"turfs" = room_turfs,
			"closets" = room_closets,
			"doors" = room_doors,
		)
	if(QDELETED(src))
		return
	// Anything deleted while this yielded leaves the rooms before they are watched.
	for(var/room_id in rooms)
		var/list/room = rooms[room_id]
		for(var/obj/structure/closet/closet as anything in room["closets"])
			if(QDELETED(closet))
				room["closets"] -= closet
			else
				watch(closet)
		for(var/obj/machinery/door/door as anything in room["doors"])
			if(QDELETED(door))
				room["doors"] -= door
		CHECK_TICK
	if(QDELETED(src))
		return

	// Which rooms each door joins, and which stops each room holds
	var/list/stops = list()
	for(var/obj/machinery/door/door as anything in interior)
		CHECK_TICK
		if(QDELETED(door))
			continue
		watch(door)
		var/turf/door_turf = get_turf(door)
		var/list/joined = list()
		for(var/direction in cardinal_dirs)
			var/turf/beside = get_step(door_turf, direction)
			var/room_id = beside && turf_rooms[REF(beside)]
			if(room_id && !(room_id in joined))
				joined += room_id
		if(length(joined))
			door_rooms[REF(door)] = joined
		if(!door_on_furniture(door))
			stops += door
	if(QDELETED(src))
		return
	stops = nearest_stops(stops)
	var/list/room_stops = list()
	for(var/obj/machinery/door/door as anything in stops)
		for(var/room_id in door_rooms[REF(door)])
			LAZYADD(room_stops[room_id], door)

	// Visiting order: the nearest unvisited stop sharing a room, else the fewest rooms away,
	// else (another part of the outpost) the nearest by distance
	var/list/ordered = list()
	var/list/unvisited = list()
	for(var/obj/machinery/door/door as anything in stops)
		unvisited[door] = TRUE
	var/obj/machinery/door/current_stop = length(stops) ? stops[1] : null
	while(current_stop)
		ordered += current_stop
		unvisited -= current_stop
		if(!length(unvisited))
			break
		current_stop = next_stop(current_stop, unvisited, door_rooms, room_stops)
		CHECK_TICK
	if(QDELETED(src))
		return

	// A second door between the same two rooms adds nothing but back-and-forth
	var/list/used_pairs = list()
	var/list/new_path = list()
	for(var/obj/machinery/door/door as anything in ordered)
		if(QDELETED(door))
			continue
		var/list/joined = door_rooms[REF(door)]
		if(length(joined) >= 2)
			var/room_a = joined[1]
			var/room_b = joined[2]
			var/pair = room_a < room_b ? "[room_a]-[room_b]" : "[room_b]-[room_a]"
			if(used_pairs[pair])
				continue
			used_pairs[pair] = TRUE
		new_path += door

	path.Cut()
	path += new_path

	var/list/locked_doors = list()
	for(var/obj/machinery/door/door as anything in path)
		if(door_requires_access(door))
			locked_doors[REF(door)] = TRUE
	GLOB.boarding_locked_doors[key] = locked_doors

/// Where escapes start from, to rank the doors by: the middle of the outpost's prison wing, else its arrival point
/datum/outpost_patrol_cache/proc/patrol_origin()
	var/datum/outpost_prison/prison = outpost?.running_prison()
	var/list/bounds = prison?.upgrade?.footprint_bounds
	if(bounds)
		return locate(round((bounds[1] + bounds[3]) / 2), round((bounds[2] + bounds[4]) / 2), bounds[5])
	return outpost?.arrival_turf

/**
 * The OUTPOST_PATROL_MAX_STOPS of `stops` nearest patrol_origin(), nearest first. With no origin,
 * the first stop stands in for it.
 */
/datum/outpost_patrol_cache/proc/nearest_stops(list/stops)
	if(!length(stops))
		return list()
	var/atom/origin = patrol_origin() || stops[1]
	var/list/by_distance = list()
	for(var/obj/machinery/door/door as anything in stops)
		// Gone while the rebuild yielded
		if(!QDELETED(door))
			by_distance[door] = get_dist(origin, door)
	sortTim(by_distance, cmp = GLOBAL_PROC_REF(cmp_numeric_asc), associative = TRUE)
	var/list/nearest = list()
	for(var/obj/machinery/door/door as anything in by_distance)
		nearest += door
		if(length(nearest) >= OUTPOST_PATROL_MAX_STOPS)
			break
	return nearest

/// The stop to visit after `from`: see rebuild(). `unvisited` is a set (door = TRUE).
/datum/outpost_patrol_cache/proc/next_stop(obj/machinery/door/from, list/unvisited, list/door_rooms, list/room_stops)
	var/obj/machinery/door/best
	var/best_distance = INFINITY
	for(var/room_id in door_rooms[REF(from)])
		for(var/obj/machinery/door/candidate as anything in room_stops[room_id])
			if(!unvisited[candidate])
				continue
			var/distance = get_dist(from, candidate)
			if(distance < best_distance)
				best_distance = distance
				best = candidate
	if(best)
		return best

	// Breadth-first through rooms and doors to the first unvisited stop
	var/list/seen_rooms = list()
	var/list/frontier = list()
	for(var/room_id in door_rooms[REF(from)])
		seen_rooms[room_id] = TRUE
		frontier += room_id
	while(length(frontier))
		var/list/next_frontier = list()
		for(var/room_id in frontier)
			for(var/obj/machinery/door/through as anything in room_stops[room_id])
				if(unvisited[through])
					var/distance = get_dist(from, through)
					if(distance < best_distance)
						best_distance = distance
						best = through
					continue
				for(var/further_room in door_rooms[REF(through)])
					if(!seen_rooms[further_room])
						seen_rooms[further_room] = TRUE
						next_frontier += further_room
		if(best)
			return best
		frontier = next_frontier

	for(var/obj/machinery/door/candidate as anything in unvisited)
		var/distance = get_dist(from, candidate)
		if(distance < best_distance)
			best_distance = distance
			best = candidate
	return best

/datum/outpost_patrol_cache/proc/watch(atom/thing)
	if(watched[thing])
		return
	watched[thing] = TRUE
	RegisterSignal(thing, COMSIG_QDELETING, PROC_REF(on_watched_deleted))

/datum/outpost_patrol_cache/proc/unwatch_all()
	for(var/atom/thing as anything in watched)
		UnregisterSignal(thing, COMSIG_QDELETING)
	watched = list()

/// A door or locker is going: out of the path (nulled in place, which the patrol skips) and the rooms
/datum/outpost_patrol_cache/proc/on_watched_deleted(atom/source)
	SIGNAL_HANDLER
	watched -= source
	var/index = path.Find(source)
	while(index)
		path[index] = null
		index = path.Find(source, index + 1)
	if(doors[source])
		doors -= source
		dirty = TRUE
	for(var/room_id in GLOB.ship_rooms[key])
		var/list/room = GLOB.ship_rooms[key][room_id]
		room["closets"] -= source
		room["doors"] -= source

// ===== BREAKOUT AI =====

/**
 * Someone who broke out of an outpost prison. Walks the outpost's patrol path, opens or smashes the
 * doors on the way, searches lockers, and fights anyone who is not a prisoner with its own melee.
 * Swapped onto a prisoner with swap_basic_ai_controller(), then given a path with
 * assign_mob_to_outpost_patrol(). Without a path it wanders and still fights.
 */
/datum/ai_controller/basic_controller/outpost_breakout
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic/outpost_breakout,
		// People are beaten down, not finished off
		BB_TARGET_MINIMUM_STAT = SOFT_CRIT,
	)
	ai_movement = /datum/ai_movement/jps
	idle_behavior = /datum/idle_behavior/idle_random_walk
	// Keep going while anyone is on the level, not only when someone is close
	can_idle = FALSE
	// Outpost doors can be further apart than a ship's; JPS paths reach this far
	max_target_distance = AI_MAX_PATH_LENGTH
	planning_subtrees = list(
		// Cuffed, a caught runner plans nothing until walked home (outpost_prison_capture.dm)
		/datum/ai_planning_subtree/outpost_prisoner_cuffed,
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/aggressive_find_target,
		/datum/ai_planning_subtree/attack_obstacle_in_path/trooper/include_mobs/outpost_breakout,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
		/datum/ai_planning_subtree/handle_blocking_door/outpost_breakout,
		/datum/ai_planning_subtree/explore_room,
		/datum/ai_planning_subtree/patrol_path,
		/datum/ai_planning_subtree/try_open_door_in_path,
		/datum/ai_planning_subtree/attack_patrol_door/outpost_breakout,
	)

/// Opens or smashes doors in the way, but walks around furniture instead of beating on it
/datum/ai_planning_subtree/handle_blocking_door/outpost_breakout
	smash_obstacles = FALSE

/datum/ai_planning_subtree/handle_blocking_door/outpost_breakout/ignores_door(datum/ai_controller/controller, obj/machinery/door/door)
	// A door on a counter leads nowhere anyone can walk
	if(door_on_furniture(door))
		return TRUE
	// One that would not open and cannot be broken is not worth a swing
	if(door.resistance_flags & INDESTRUCTIBLE)
		var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
		return failed_doors && failed_doors[REF(door)]
	return FALSE

/// Smashes a locked patrol door, and goes on to the next one when it cannot be broken
/datum/ai_planning_subtree/attack_patrol_door/outpost_breakout

/datum/ai_planning_subtree/attack_patrol_door/outpost_breakout/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	if(controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return
	var/obj/machinery/door/target_door = controller.blackboard[target_key]
	if(QDELETED(target_door) || !target_door.density || get_dist(controller.pawn, target_door) > 1)
		return
	var/door_ref = REF(target_door)
	var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
	if(!failed_doors || !failed_doors[door_ref])
		return
	var/list/attack_times = controller.blackboard["_blocking_door_attack_times"]
	if(!attack_times)
		attack_times = list()
		controller.blackboard["_blocking_door_attack_times"] = attack_times
	if(!attack_times[door_ref])
		attack_times[door_ref] = world.time
	if(!(target_door.resistance_flags & INDESTRUCTIBLE) && world.time < attack_times[door_ref] + PATROL_DOOR_ATTACK_TIMEOUT)
		return ..()
	// Give up on it for this lap: tried again, from the start, next time round
	attack_times -= door_ref
	var/list/skipped_doors = controller.blackboard["_skipped_blocking_doors"]
	if(!skipped_doors)
		skipped_doors = list()
		controller.blackboard["_skipped_blocking_doors"] = skipped_doors
	skipped_doors[door_ref] = TRUE
	var/list/patrol_path = controller.blackboard[BB_MOB_PATROL_PATH]
	if(length(patrol_path))
		var/patrol_index = controller.blackboard[BB_MOB_PATROL_INDEX] || 1
		controller.blackboard[BB_MOB_PATROL_INDEX] = (patrol_index % length(patrol_path)) + 1
	clear_patrol_tracking_keys(controller)
	controller.blackboard[BB_MOB_PATROL_TARGET] = null
	return SUBTREE_RETURN_FINISH_PLANNING

/// Anyone living but prisoners and others breaking out, whatever their faction
/datum/targeting_strategy/basic/outpost_breakout

/datum/targeting_strategy/basic/outpost_breakout/faction_check(datum/ai_controller/controller, mob/living/living_mob, mob/living/the_target)
	return is_outpost_breakout_ally(the_target)

/// Clears the way to a target, but steps around prisoners instead of hitting them
/datum/ai_planning_subtree/attack_obstacle_in_path/trooper/include_mobs/outpost_breakout
	attack_behaviour = /datum/ai_behavior/attack_obstructions/trooper/include_mobs/outpost_breakout

/datum/ai_behavior/attack_obstructions/trooper/include_mobs/outpost_breakout

/datum/ai_behavior/attack_obstructions/trooper/include_mobs/outpost_breakout/attack_in_direction(datum/ai_controller/controller, mob/living/basic/basic_mob, direction)
	var/turf/next_step = get_step(basic_mob, direction)
	if(!next_step?.is_blocked_turf(exclude_mobs = FALSE, source_atom = controller.pawn))
		return FALSE
	for(var/mob/living/blocking_mob in next_step)
		if(blocking_mob == basic_mob || is_outpost_breakout_ally(blocking_mob))
			continue
		basic_mob.melee_attack(blocking_mob)
		return TRUE
	for(var/obj/object as anything in next_step.contents)
		if(!can_smash_object(basic_mob, object))
			continue
		basic_mob.melee_attack(object)
		return TRUE
	return FALSE

#undef OUTPOST_PATROL_RECHECK
#undef OUTPOST_PATROL_MAX_STOPS
