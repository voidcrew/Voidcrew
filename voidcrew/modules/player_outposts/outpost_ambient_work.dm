/**
 * # Ambient work
 *
 * NPCs that look busy: the ship bay droids (outpost_yard_droids.dm) and ambient outpost staff
 * (voidcrew/modules/ambient_npcs/). A worker keeps to the room it was put in and walks about now
 * and then. Every so often it picks something nearby it knows how to work
 * on (a machine, a wall, a pipe, a crate, a bar table, a dirty floor), walks up to it, faces it and
 * works on it for a while with the right sounds and sparks, then moves on.
 *
 * It is all for show. A worker never changes, damages, moves or hands out anything, and it only
 * acts while a living player is near it (its AI controller is on), so an empty room costs nothing.
 *
 * A worker's room is the open floor it can reach from where it was put, within
 * OUTPOST_WORK_RANGE tiles, in the same area, without passing a door, a window or a fence, and
 * never onto a docking floor or an elevator lift. A docking floor is a landing pad at its largest, a
 * margin round it, and all the open floor joined to it without a door between: in a ship bay, the
 * whole hangar floor. Hulls land and are rebuilt only on the pad, so a worker is never under one.
 * The worker refuses any move out of its room, and a worker that ends up far from it anyway
 * (carried off, admin moved) is put back where it started.
 */

/// How far from where it was put a worker may go
#define OUTPOST_WORK_RANGE 6
/// Tiles round a landing pad kept clear of workers, walls or no walls
#define OUTPOST_WORK_PAD_MARGIN 2
/// How far from where it stands a worker looks for something to work on
#define OUTPOST_WORK_SEARCH_RANGE 4
/// Most objects looked at in one search, however much junk is piled nearby
#define OUTPOST_WORK_SEARCH_LIMIT 300
/// A room is worked out again this often
#define OUTPOST_WORK_ROOM_REFRESH (5 MINUTES)
/// Rest between two jobs
#define OUTPOST_WORK_REST_LOW (15 SECONDS)
#define OUTPOST_WORK_REST_HIGH (40 SECONDS)
/// When nothing nearby needs work, look again after this
#define OUTPOST_WORK_RETRY (20 SECONDS)
/// Chance per second of a step while not working
#define OUTPOST_WORK_WANDER_CHANCE 15
/// How long one step takes, for gliding
#define OUTPOST_WORK_STEP_TIME (0.8 SECONDS)
/// Work sounds carry less far than ordinary ones
#define OUTPOST_WORK_SOUND_RANGE -4
/// Blue-white light of a welding arc
#define OUTPOST_WORK_WELD_LIGHT "#B5DCFF"

#define BB_OUTPOST_WORK_TARGET "outpost_work_target"
#define BB_OUTPOST_WORK_SPOT "outpost_work_spot"

/// The shared instance of each kind of work
/proc/outpost_ambient_work(work_type)
	var/static/list/works = list()
	if(!works[work_type])
		works[work_type] = new work_type
	return works[work_type]

// =========================================================================
// THE WORKER
// =========================================================================

/datum/component/outpost_ambient_worker
	/// Where the worker was put; its room is worked out from here
	var/turf/home
	/// The kinds of work it does: /datum/outpost_ambient_work types, each with a weight
	var/list/work_weights
	/// A dense worker (a person) never stops beside a door, so it never blocks a doorway
	var/keep_off_doorways = FALSE
	/// Called with the look of the work ("weld", "tool" or null) when work starts, and with null when it stops
	var/datum/callback/on_look
	/// The tiles the worker may be on, as an assoc list of turfs. Built when first needed.
	var/list/room
	/// When the room was last worked out
	var/room_built_at = 0
	/// The work picked by the planner, started on arrival
	var/datum/outpost_ambient_work/planned_work
	/// The work being done now
	var/datum/outpost_ambient_work/work
	/// What it is being done to
	var/datum/weakref/work_target
	/// The way the worker faces while working
	var/work_dir = SOUTH
	/// When the current job is done
	var/work_ends_at = 0
	/// No new job before this
	var/next_work_at = 0
	/// The last thing worked on, so the worker moves on to something else
	var/datum/weakref/last_target
	/// Sparks and the like shown while working
	var/mutable_appearance/work_overlay
	/// A box carried between two jobs (the loader). A droid's carried box overlay; a person shows it through `on_look` instead.
	var/mutable_appearance/carried
	/// Whether it is carrying something between two jobs right now
	var/carrying = FALSE

/datum/component/outpost_ambient_worker/Initialize(list/work_weights, keep_off_doorways = FALSE, datum/callback/on_look)
	if(!ismovable(parent))
		return COMPONENT_INCOMPATIBLE
	src.work_weights = work_weights
	src.keep_off_doorways = keep_off_doorways
	src.on_look = on_look
	home = get_turf(parent)
	// Workers placed side by side do not all start at once
	next_work_at = world.time + rand(5 SECONDS, 25 SECONDS)

/datum/component/outpost_ambient_worker/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(on_pre_move))
	RegisterSignal(parent, COMSIG_MOVABLE_TELEPORTING, PROC_REF(on_teleporting))
	if(isliving(parent))
		RegisterSignal(parent, COMSIG_LIVING_PRE_WABBAJACKED, PROC_REF(on_wabbajack))
		RegisterSignal(parent, COMSIG_PRE_MOB_CHANGED_TYPE, PROC_REF(on_type_change))

/datum/component/outpost_ambient_worker/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOVABLE_PRE_MOVE, COMSIG_MOVABLE_TELEPORTING, COMSIG_LIVING_PRE_WABBAJACKED, COMSIG_PRE_MOB_CHANGED_TYPE))

/datum/component/outpost_ambient_worker/Destroy(force)
	on_look = null
	stop_work()
	set_carried(FALSE)
	home = null
	room = null
	planned_work = null
	return ..()

/// Never walks out of its room on its own. Being thrown or pulled is left to whatever did it.
/datum/component/outpost_ambient_worker/proc/on_pre_move(atom/movable/source, atom/new_loc)
	SIGNAL_HANDLER
	if(!isturf(new_loc) || source.throwing || source.pulledby)
		return NONE
	var/list/tiles = get_room()
	if(!tiles[new_loc])
		return COMPONENT_MOVABLE_BLOCK_PRE_MOVE
	return NONE

/// Teleports of any kind, forced ones included, leave it where it is
/datum/component/outpost_ambient_worker/proc/on_teleporting(datum/source, atom/destination, channel)
	SIGNAL_HANDLER
	return TRUE

/datum/component/outpost_ambient_worker/proc/on_wabbajack(datum/source, what_to_randomize)
	SIGNAL_HANDLER
	return STOP_WABBAJACK

/datum/component/outpost_ambient_worker/proc/on_type_change(datum/source)
	SIGNAL_HANDLER
	return COMPONENT_BLOCK_MOB_CHANGE

/**
 * The tiles this worker may be on: open floor reachable from home within OUTPOST_WORK_RANGE, in
 * home's area, never through a door, window or fence, never on a docking floor or an elevator lift.
 * Tiles with furniture on them are kept; whether one can be entered is decided when stepping.
 * A worker put down on a docking floor gets no room at all and stays where it is.
 */
/datum/component/outpost_ambient_worker/proc/get_room()
	if(room && world.time < room_built_at + OUTPOST_WORK_ROOM_REFRESH)
		return room
	room_built_at = world.time
	room = list()
	if(!isopenturf(home))
		return room
	var/area/home_area = get_area(home)
	var/list/docking_floor = docking_floor_near(home)
	var/list/lifts = lift_turfs_near(home, OUTPOST_WORK_RANGE)
	room[home] = TRUE
	if(docking_floor[home])
		return room
	var/list/seen = list()
	seen[home] = TRUE
	var/list/queue = list(home)
	var/index = 1
	while(index <= length(queue))
		var/turf/tile = queue[index++]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(tile, direction)
			if(isnull(next) || seen[next])
				continue
			seen[next] = TRUE
			if(get_dist(next, home) > OUTPOST_WORK_RANGE || !room_tile_allowed(next, home_area, docking_floor, lifts))
				continue
			room[next] = TRUE
			queue += next
	return room

/datum/component/outpost_ambient_worker/proc/room_tile_allowed(turf/tile, area/home_area, list/docking_floor, list/lifts)
	if(!isopenturf(tile) || get_area(tile) != home_area || lifts[tile] || docking_floor[tile])
		return FALSE
	return !outpost_work_barrier(tile)

/// Whether `tile` closes a room off: a door, a full window, a fence, a grille, flaps or the lift nook
/proc/outpost_work_barrier(turf/tile)
	var/static/list/barriers = typecacheof(list(
		/obj/effect/landmark/outpost_elevator_alcove,
		/obj/machinery/door,
		/obj/structure/fence,
		/obj/structure/grille,
		/obj/structure/plasticflaps,
	))
	for(var/atom/movable/thing as anything in tile)
		if(is_type_in_typecache(thing, barriers))
			return TRUE
		if(istype(thing, /obj/structure/window))
			var/obj/structure/window/pane = thing
			if(pane.fulltile)
				return TRUE
	return FALSE

/// The ground `port` lands hulls on at its largest, as list(min x, min y, max x, max y)
/proc/outpost_work_landing_rect(obj/docking_port/stationary/port)
	var/list/coords = port.return_coords()
	var/list/rect = list(min(coords[1], coords[3]), min(coords[2], coords[4]), max(coords[1], coords[3]), max(coords[2], coords[4]))
	// A reserve berth turns and shifts to fit each arrival. Where it was built, it is at its largest.
	if(port.reserve_home_z && port.reserve_home_z == port.z)
		rect[1] = min(rect[1], port.reserve_home_x)
		rect[2] = min(rect[2], port.reserve_home_y)
		rect[3] = max(rect[3], port.reserve_home_x + RESERVE_DOCK_MAX_SIZE_LONG - 1)
		rect[4] = max(rect[4], port.reserve_home_y + RESERVE_DOCK_MAX_SIZE_SHORT - 1)
	return rect

/**
 * The docking floors a worker at `center` could reach, as an assoc list of turfs. For each landing
 * pad near it: the pad at its largest, OUTPOST_WORK_PAD_MARGIN tiles round it whatever stands there,
 * and every open tile joined to the pad without a door, window or fence between. A ship bay's
 * docking floor may run anywhere in the bay; elsewhere it is followed only as far as a worker could
 * reach from beside the pad.
 */
/datum/component/outpost_ambient_worker/proc/docking_floor_near(turf/center)
	. = list()
	var/reach = OUTPOST_WORK_PAD_MARGIN + OUTPOST_WORK_RANGE
	for(var/obj/docking_port/stationary/port as anything in SSshuttle.stationary_docking_ports)
		if(QDELETED(port) || port.z != center.z)
			continue
		var/list/pad = outpost_work_landing_rect(port)
		var/datum/outpost_berth/ship_bay/bay = port.ship_bay
		if(bay?.has_ground())
			if(!bay.contains_turf(center))
				continue
		else if(center.x < pad[1] - reach || center.x > pad[3] + reach || center.y < pad[2] - reach || center.y > pad[4] + reach)
			continue
		add_docking_floor(., pad, center.z, bay?.has_ground() ? bay : null, reach + OUTPOST_WORK_RANGE)

/// Adds one pad's docking floor to `floor`. Followed inside `bay`'s ground, or `bound` tiles round the pad.
/datum/component/outpost_ambient_worker/proc/add_docking_floor(list/floor, list/pad, z, datum/outpost_berth/ship_bay/bay, bound)
	var/list/seen = list()
	var/list/queue = list()
	for(var/x in max(1, pad[1] - OUTPOST_WORK_PAD_MARGIN) to min(world.maxx, pad[3] + OUTPOST_WORK_PAD_MARGIN))
		for(var/y in max(1, pad[2] - OUTPOST_WORK_PAD_MARGIN) to min(world.maxy, pad[4] + OUTPOST_WORK_PAD_MARGIN))
			var/turf/tile = locate(x, y, z)
			floor[tile] = TRUE
			// Only the pad spreads: a margin tile behind a wall must not carry the floor into the room there
			if(x >= pad[1] && x <= pad[3] && y >= pad[2] && y <= pad[4])
				seen[tile] = TRUE
				queue += tile
	var/index = 1
	while(index <= length(queue))
		var/turf/tile = queue[index++]
		if(!isopenturf(tile) || outpost_work_barrier(tile))
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(tile, direction)
			if(isnull(next) || seen[next])
				continue
			seen[next] = TRUE
			if(bay ? !bay.contains_turf(next) : (next.x < pad[1] - bound || next.x > pad[3] + bound || next.y < pad[2] - bound || next.y > pad[4] + bound))
				continue
			if(!isopenturf(next) || outpost_work_barrier(next))
				continue
			floor[next] = TRUE
			queue += next

/// Elevator lift tiles near `center`: the lift carries off whatever stands on it
/datum/component/outpost_ambient_worker/proc/lift_turfs_near(turf/center, range)
	. = list()
	for(var/obj/machinery/outpost_elevator/panel as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/outpost_elevator))
		if(QDELETED(panel) || panel.z != center.z || get_dist(panel, center) > range + 4)
			continue
		var/list/lift = panel.berth ? panel.berth.alcove_turfs : panel.outpost?.get_floor_alcove(0)
		for(var/turf/tile as anything in lift)
			.[tile] = TRUE

/// Whether the worker could stop on `tile` now
/datum/component/outpost_ambient_worker/proc/can_stand_at(turf/tile)
	var/list/tiles = get_room()
	if(!tiles[tile] || tile.is_blocked_turf(exclude_mobs = FALSE, ignore_atoms = list(parent)))
		return FALSE
	if(keep_off_doorways)
		for(var/direction in GLOB.cardinals)
			if(locate(/obj/machinery/door) in get_step(tile, direction))
				return FALSE
	return TRUE

/// One step to a random free tile of the room, or back towards it after being moved off it
/datum/component/outpost_ambient_worker/proc/wander_step()
	var/atom/movable/worker = parent
	if(work || !isturf(worker.loc))
		return FALSE
	var/list/tiles = get_room()
	var/turf/here = worker.loc
	if(!tiles[here])
		// Thrown or shoved off it: the way back in nearest home
		var/turf/back
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(here, direction)
			if(next && tiles[next] && (!back || get_dist(next, home) < get_dist(back, home)))
				back = next
		return back ? step_to_tile(back) : FALSE
	var/list/options = list()
	for(var/direction in GLOB.cardinals)
		var/turf/next = get_step(here, direction)
		if(next && can_stand_at(next))
			options += next
	if(!length(options))
		return FALSE
	return step_to_tile(pick(options))

/datum/component/outpost_ambient_worker/proc/step_to_tile(turf/next)
	var/atom/movable/worker = parent
	worker.set_glide_size(DELAY_TO_GLIDE_SIZE(OUTPOST_WORK_STEP_TIME))
	return worker.Move(next, get_dir(worker, next))

/**
 * A worker that ended up away from its room (thrown, carried off, on another level, moved by an
 * admin) goes back where it was put. One step off it, it walks back in by itself. TRUE if moved.
 */
/datum/component/outpost_ambient_worker/proc/check_leash()
	var/atom/movable/worker = parent
	var/turf/here = get_turf(worker)
	if(isnull(home) || here == home)
		return FALSE
	if(isturf(worker.loc) && here.z == home.z)
		var/list/tiles = get_room()
		if(tiles[here])
			return FALSE
		for(var/direction in GLOB.cardinals)
			if(tiles[get_step(here, direction)])
				return FALSE
	stop_work()
	worker.forceMove(home)
	return TRUE

/**
 * Picks something nearby to work on and where to stand for it. Returns list(target, spot, work)
 * or null. Kinds of work are tried in weighted random order; every search together looks at no
 * more than OUTPOST_WORK_SEARCH_LIMIT objects.
 */
/datum/component/outpost_ambient_worker/proc/find_work()
	var/turf/here = get_turf(parent)
	if(isnull(here) || !length(work_weights))
		return null
	var/list/weights = work_weights.Copy()
	var/list/turfs = shuffle(RANGE_TURFS(OUTPOST_WORK_SEARCH_RANGE, here))
	var/area/home_area = get_area(home)
	var/checked = 0
	while(length(weights))
		var/work_type = pick_weight(weights)
		weights -= work_type
		var/datum/outpost_ambient_work/kind = outpost_ambient_work(work_type)
		for(var/turf/tile as anything in turfs)
			if(get_area(tile) != home_area)
				continue
			if(kind.works_on_floor)
				if(tile != here && !IS_WEAKREF_OF(tile, last_target) && kind.accepts(tile) && can_stand_at(tile))
					return list(tile, tile, kind)
				continue
			if(kind.accepts(tile) && !IS_WEAKREF_OF(tile, last_target))
				var/turf/spot = spot_for(tile)
				if(spot)
					return list(tile, spot, kind)
			for(var/obj/thing in tile)
				if(++checked > OUTPOST_WORK_SEARCH_LIMIT)
					return null
				if(thing.invisibility || IS_WEAKREF_OF(thing, last_target) || !kind.accepts(thing))
					continue
				var/turf/spot = spot_for(thing)
				if(spot)
					return list(thing, spot, kind)
	return null

/// The tiles `target` covers: several for a big machine
/proc/outpost_ambient_footprint(atom/target)
	if(ismovable(target))
		var/atom/movable/thing = target
		return thing.locs
	return list(get_turf(target))

/// Whether `thing` hangs on a wall (a wall mount on the floor tile beside it)
/proc/outpost_ambient_wall_mounted(atom/thing)
	return isobj(thing) && !thing.density && (abs(thing.pixel_x) >= 16 || abs(thing.pixel_y) >= 16)

/// Where to stand to work on `target`, or null
/datum/component/outpost_ambient_worker/proc/spot_for(atom/target)
	var/turf/target_turf = get_turf(target)
	if(isnull(target_turf))
		return null
	if(outpost_ambient_wall_mounted(target))
		return can_stand_at(target_turf) ? target_turf : null
	var/list/footprint = outpost_ambient_footprint(target)
	var/list/spots = list()
	for(var/turf/part as anything in footprint)
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(part, direction)
			if(next && !(next in footprint) && can_stand_at(next))
				spots += next
	return length(spots) ? pick(spots) : null

/// The way to face to work on `target` from where the worker stands
/datum/component/outpost_ambient_worker/proc/facing_for(atom/target)
	if(outpost_ambient_wall_mounted(target))
		if(abs(target.pixel_y) >= abs(target.pixel_x))
			return target.pixel_y > 0 ? NORTH : SOUTH
		return target.pixel_x > 0 ? EAST : WEST
	var/turf/here = get_turf(parent)
	var/list/footprint = outpost_ambient_footprint(target)
	for(var/turf/part as anything in footprint)
		if(get_dist(here, part) <= 1 && part != here)
			return get_dir(here, part)
	var/direction = get_dir(here, target)
	return direction || pick(GLOB.cardinals)

/// Starts the job the planner picked, on arriving beside `target`
/datum/component/outpost_ambient_worker/proc/start_work(atom/target)
	var/datum/outpost_ambient_work/kind = planned_work
	planned_work = null
	if(isnull(kind) || QDELETED(target))
		return FALSE
	var/atom/movable/worker = parent
	work = kind
	work_target = WEAKREF(target)
	last_target = WEAKREF(target)
	work_ends_at = world.time + rand(kind.duration_low, kind.duration_high)
	work_dir = facing_for(target)
	// A diagonal facing has no sprite: keep one of its two parts
	if(work_dir & (work_dir - 1))
		work_dir &= pick(NORTH | SOUTH, EAST | WEST)
	worker.setDir(work_dir)
	// The look first: changing it replaces every overlay
	on_look?.Invoke(kind.look || (carrying ? "carry" : null))
	lean(work_dir)
	kind.start(src, target)
	return TRUE

/// One beat of the job. FALSE once it is done.
/datum/component/outpost_ambient_worker/proc/continue_work()
	if(isnull(work) || world.time >= work_ends_at)
		return FALSE
	var/atom/target = work_target?.resolve()
	if(QDELETED(target))
		return FALSE
	work.tick(src, target)
	return TRUE

/datum/component/outpost_ambient_worker/proc/stop_work()
	if(isnull(work))
		return
	var/datum/outpost_ambient_work/kind = work
	work = null
	work_target = null
	kind.stop(src)
	set_work_overlay(null)
	lean(null)
	on_look?.Invoke(carrying ? "carry" : null)
	next_work_at = world.time + rand(OUTPOST_WORK_REST_LOW, OUTPOST_WORK_REST_HIGH)

/// Shows `overlay` on the worker while it works, replacing the last one
/datum/component/outpost_ambient_worker/proc/set_work_overlay(mutable_appearance/overlay)
	var/atom/movable/worker = parent
	if(work_overlay)
		worker.cut_overlay(work_overlay)
	work_overlay = overlay
	if(work_overlay)
		worker.add_overlay(work_overlay)

/// Picks a box up or puts it down (the loader). A droid shows a box overlay; a person shows the "carry" look in hand instead.
/datum/component/outpost_ambient_worker/proc/set_carried(carrying)
	var/atom/movable/worker = parent
	src.carrying = carrying
	if(carried)
		worker.cut_overlay(carried)
		carried = null
	if(on_look)
		on_look.Invoke(carrying ? "carry" : null)
		return
	if(!carrying)
		return
	carried = mutable_appearance('icons/obj/storage/box.dmi', "box")
	// A box sized to the droid, held low in front of it
	carried.transform = matrix(0.6, 0, 0, 0, 0.6, 0)
	carried.appearance_flags |= PIXEL_SCALE
	carried.pixel_y = -5
	worker.add_overlay(carried)

/// A droid leans a little towards its work. People do not: their offsets belong to other things.
/datum/component/outpost_ambient_worker/proc/lean(direction)
	if(!isobj(parent))
		return
	var/atom/movable/worker = parent
	var/lean_x = direction & EAST ? 3 : (direction & WEST ? -3 : 0)
	var/lean_y = direction & NORTH ? 3 : (direction & SOUTH ? -2 : 0)
	animate(worker, pixel_w = lean_x, pixel_z = lean_y, time = 0.3 SECONDS)

// =========================================================================
// AI
// =========================================================================

/// Work when something needs it, walk about otherwise. Only while a player is near.
/datum/ai_planning_subtree/outpost_ambient_work

/datum/ai_planning_subtree/outpost_ambient_work/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/datum/component/outpost_ambient_worker/worker = controller.pawn.GetComponent(/datum/component/outpost_ambient_worker)
	if(isnull(worker))
		return
	if(controller.ai_status == AI_STATUS_ON && !worker.check_leash() && world.time >= worker.next_work_at)
		var/list/job = worker.find_work()
		if(job)
			worker.planned_work = job[3]
			controller.set_blackboard_key(BB_OUTPOST_WORK_TARGET, job[1])
			controller.set_blackboard_key(BB_OUTPOST_WORK_SPOT, job[2])
			controller.queue_behavior(/datum/ai_behavior/outpost_ambient_work, BB_OUTPOST_WORK_TARGET, BB_OUTPOST_WORK_SPOT)
			return SUBTREE_RETURN_FINISH_PLANNING
		worker.next_work_at = world.time + OUTPOST_WORK_RETRY
	// Queued even while idle, so planning never fails and churns the controller
	controller.queue_behavior(/datum/ai_behavior/outpost_ambient_wander)

/// Walks to the spot, then works until the job is done
/datum/ai_behavior/outpost_ambient_work
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT
	required_distance = 0
	action_cooldown = 2 SECONDS

/datum/ai_behavior/outpost_ambient_work/setup(datum/ai_controller/controller, target_key, spot_key)
	var/turf/spot = controller.blackboard[spot_key]
	if(isnull(spot) || isnull(controller.blackboard[target_key]))
		return FALSE
	set_movement_target(controller, spot)
	return TRUE

/datum/ai_behavior/outpost_ambient_work/perform(seconds_per_tick, datum/ai_controller/controller, target_key, spot_key)
	var/datum/component/outpost_ambient_worker/worker = controller.pawn.GetComponent(/datum/component/outpost_ambient_worker)
	var/atom/target = controller.blackboard[target_key]
	if(isnull(worker) || QDELETED(target) || controller.ai_status != AI_STATUS_ON || get_turf(controller.pawn) != controller.blackboard[spot_key])
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	if(isnull(worker.work))
		return worker.start_work(target) ? AI_BEHAVIOR_DELAY : (AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED)
	if(worker.continue_work())
		return AI_BEHAVIOR_DELAY
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/outpost_ambient_work/finish_action(datum/ai_controller/controller, succeeded, target_key, spot_key)
	. = ..()
	var/datum/component/outpost_ambient_worker/worker = controller.pawn?.GetComponent(/datum/component/outpost_ambient_worker)
	if(worker)
		worker.planned_work = null
		worker.stop_work()
		if(!succeeded)
			worker.next_work_at = max(worker.next_work_at, world.time + OUTPOST_WORK_RETRY)
	controller.clear_blackboard_key(target_key)
	controller.clear_blackboard_key(spot_key)

/// A slow step now and then. Never finishes by itself; planning replaces it with work.
/datum/ai_behavior/outpost_ambient_wander
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION
	action_cooldown = 1 SECONDS

/datum/ai_behavior/outpost_ambient_wander/perform(seconds_per_tick, datum/ai_controller/controller)
	if(controller.ai_status == AI_STATUS_ON && SPT_PROB(OUTPOST_WORK_WANDER_CHANCE, seconds_per_tick))
		var/datum/component/outpost_ambient_worker/worker = controller.pawn.GetComponent(/datum/component/outpost_ambient_worker)
		worker?.wander_step()
	return AI_BEHAVIOR_DELAY

// =========================================================================
// KINDS OF WORK
// =========================================================================

/// One kind of work. Shared by every worker; per-worker state lives on the worker.
/datum/outpost_ambient_work
	/// Types it works on
	var/list/works_on = list()
	/// Types it leaves alone, even when they are in works_on
	var/list/leaves_alone = list()
	/// Built from works_on and leaves_alone
	var/list/works_on_cache
	/// Stands on a floor tile and works on the floor itself
	var/works_on_floor = FALSE
	/// How long one job takes
	var/duration_low = 10 SECONDS
	var/duration_high = 20 SECONDS
	/// What a person holds for it: "weld" (a lit welder, visor down), "tool" (a wrench) or null
	var/look
	/// Sounds of the work, one picked now and then
	var/list/sounds
	var/sound_volume = 30
	var/sound_chance = 60

/datum/outpost_ambient_work/New()
	works_on_cache = typecacheof(works_on)
	if(length(leaves_alone))
		works_on_cache -= typecacheof(leaves_alone)

/datum/outpost_ambient_work/proc/accepts(atom/target)
	return is_type_in_typecache(target, works_on_cache)

/datum/outpost_ambient_work/proc/start(datum/component/outpost_ambient_worker/worker, atom/target)
	return

/datum/outpost_ambient_work/proc/tick(datum/component/outpost_ambient_worker/worker, atom/target)
	if(length(sounds) && prob(sound_chance))
		playsound(worker.parent, pick(sounds), sound_volume, TRUE, OUTPOST_WORK_SOUND_RANGE)
		return TRUE
	return FALSE

/datum/outpost_ambient_work/proc/stop(datum/component/outpost_ambient_worker/worker)
	return

/// Machines and fixtures a mechanic or droid may work on. Doors are never worked on: that reads as welding them shut.
#define OUTPOST_WORK_MACHINE_EXCEPTIONS list( \
	/obj/machinery/door, \
	/obj/machinery/light, \
	/obj/machinery/outpost_elevator, \
	/obj/machinery/status_display, \
	/obj/machinery/camera, \
	/obj/machinery/holopad, \
	/obj/machinery/navbeacon, \
	/obj/machinery/atmospherics/pipe, \
	/obj/machinery/atmospherics/components/unary/vent_pump, \
	/obj/machinery/atmospherics/components/unary/vent_scrubber, \
	/obj/machinery/button, \
	/obj/machinery/light_switch, \
	/obj/machinery/firealarm, \
	/obj/machinery/airalarm, \
	/obj/machinery/power/apc, \
	/obj/machinery/newscaster, \
	/obj/machinery/barsign, \
	/obj/machinery/digital_clock, \
	/obj/machinery/computer/security/telescreen, \
	/obj/machinery/vending, \
	/obj/machinery/sleeper, \
	/obj/machinery/cryopod, \
)

/// Welding at a machine, a wreck, a crate or a wall seam
/datum/outpost_ambient_work/weld
	works_on = list(
		/obj/machinery,
		/obj/structure/mecha_wreckage,
		/obj/structure/girder,
		/obj/structure/fluff,
		/obj/structure/showcase,
		/obj/structure/closet/crate,
		/obj/structure/shipping_container,
		/obj/structure/checkpoint_drone_bay,
		/obj/structure/barrel,
		/turf/closed/wall,
		/turf/closed/indestructible/reinforced,
		/turf/closed/indestructible/riveted,
		/turf/closed/indestructible/rusty,
		/turf/closed/indestructible/iron,
		/turf/closed/indestructible/oldshuttle,
		/turf/closed/indestructible/syndicate,
	)
	leaves_alone = OUTPOST_WORK_MACHINE_EXCEPTIONS
	look = "weld"
	sounds = list('sound/items/tools/welder.ogg', 'sound/items/tools/welder2.ogg')
	sound_chance = 70

/datum/outpost_ambient_work/weld/start(datum/component/outpost_ambient_worker/worker, atom/target)
	var/atom/movable/body = worker.parent
	var/mutable_appearance/sparks = mutable_appearance('icons/effects/welding_effect.dmi', "welding_sparks", GASFIRE_LAYER, body, ABOVE_LIGHTING_PLANE)
	var/direction = worker.work_dir
	sparks.pixel_x = direction & EAST ? 12 : (direction & WEST ? -12 : 0)
	sparks.pixel_y = direction & NORTH ? 12 : (direction & SOUTH ? -6 : 0)
	worker.set_work_overlay(sparks)
	playsound(body, 'sound/items/tools/welderactivate.ogg', 25, TRUE, OUTPOST_WORK_SOUND_RANGE)

/datum/outpost_ambient_work/weld/tick(datum/component/outpost_ambient_worker/worker, atom/target)
	var/atom/movable/body = worker.parent
	body.flash_lighting_fx(1.5, 0.8, OUTPOST_WORK_WELD_LIGHT, 0.5 SECONDS)
	return ..()

/datum/outpost_ambient_work/weld/stop(datum/component/outpost_ambient_worker/worker)
	if(QDELETED(worker.parent))
		return
	playsound(worker.parent, 'sound/items/tools/welderdeactivate.ogg', 25, TRUE, OUTPOST_WORK_SOUND_RANGE)

/// A wrench on a machine, a crate, a rack or a wreck
/datum/outpost_ambient_work/wrench
	works_on = list(
		/obj/machinery,
		/obj/structure/mecha_wreckage,
		/obj/structure/girder,
		/obj/structure/closet/crate,
		/obj/structure/rack,
		/obj/structure/table/rolling,
		/obj/structure/checkpoint_drone_bay,
		/obj/structure/fluff,
	)
	leaves_alone = OUTPOST_WORK_MACHINE_EXCEPTIONS
	duration_low = 8 SECONDS
	duration_high = 16 SECONDS
	look = "tool"
	sounds = list('sound/items/tools/ratchet.ogg', 'sound/items/tools/ratchet_slow.ogg', 'sound/items/tools/crowbar.ogg')

/// A screwdriver on a wall panel
/datum/outpost_ambient_work/panel
	works_on = list(
		/obj/machinery/airalarm,
		/obj/machinery/firealarm,
		/obj/machinery/power/apc,
		/obj/machinery/light_switch,
		/obj/machinery/newscaster,
		/obj/machinery/status_display,
		/obj/machinery/computer/terminal,
	)
	duration_low = 8 SECONDS
	duration_high = 14 SECONDS
	look = "tool"
	sounds = list('sound/items/tools/screwdriver.ogg', 'sound/items/tools/screwdriver2.ogg', 'sound/items/tools/screwdriver_operating.ogg')

/// Tapping along a pipe or a tank, listening to it
/datum/outpost_ambient_work/pipe
	works_on = list(
		/obj/machinery/atmospherics,
		/obj/machinery/portable_atmospherics,
		/obj/structure/steam_vent,
		/obj/structure/reagent_dispensers/watertank,
		/obj/structure/reagent_dispensers/fueltank,
	)
	leaves_alone = list(
		/obj/machinery/atmospherics/components/unary/vent_pump,
		/obj/machinery/atmospherics/components/unary/vent_scrubber,
	)
	duration_low = 6 SECONDS
	duration_high = 12 SECONDS
	look = "tool"
	sounds = list('sound/items/lead_pipe_hit.ogg', 'sound/effects/clang.ogg')
	sound_volume = 15
	sound_chance = 50

/// Carrying a box from one crate, rack or bin to another
/datum/outpost_ambient_work/haul
	works_on = list(
		/obj/structure/closet,
		/obj/structure/rack,
		/obj/structure/ore_box,
		/obj/structure/showcase,
		/obj/structure/shipping_container,
		/obj/structure/table/rolling,
		/obj/structure/checkpoint_drone_bay,
	)
	duration_low = 3 SECONDS
	duration_high = 6 SECONDS
	sounds = list('sound/items/handling/cardboard_box/cardboard_box_rustle.ogg', SFX_RUSTLE)
	sound_volume = 25
	sound_chance = 50

/// Picks the box up at one place and sets it down at the next
/datum/outpost_ambient_work/haul/start(datum/component/outpost_ambient_worker/worker, atom/target)
	var/carrying = !worker.carrying
	worker.set_carried(carrying)
	playsound(worker.parent, carrying ? 'sound/items/handling/cardboard_box/cardboardbox_pickup.ogg' : 'sound/items/handling/cardboard_box/cardboardbox_drop.ogg', 30, TRUE, OUTPOST_WORK_SOUND_RANGE)

/// Wiping down a bar or a table
/datum/outpost_ambient_work/wipe
	works_on = list(/obj/structure/table)
	leaves_alone = list(/obj/structure/table/rolling, /obj/structure/table/optable)
	duration_low = 6 SECONDS
	duration_high = 12 SECONDS
	sounds = list(SFX_CLOTH_PICKUP, SFX_CLOTH_DROP)
	sound_volume = 25

/// Pouring at the tap, the bottle rack or a table with a glass on it
/datum/outpost_ambient_work/pour
	works_on = list(
		/obj/structure/reagent_dispensers/beerkeg,
		/obj/machinery/vending/boozeomat,
		/obj/machinery/chem_dispenser/drinks,
		/obj/structure/table,
	)
	leaves_alone = list(/obj/structure/table/rolling, /obj/structure/table/optable)
	duration_low = 5 SECONDS
	duration_high = 9 SECONDS
	sounds = list(SFX_LIQUID_POUR, 'sound/items/handling/drinkglass_drop.ogg')
	sound_volume = 30

/// A table only when a glass stands on it
/datum/outpost_ambient_work/pour/accepts(atom/target)
	if(!..())
		return FALSE
	if(istype(target, /obj/structure/table))
		return !!(locate(/obj/item/reagent_containers/cup/glass) in target.loc)
	return TRUE

/// Mopping the floor, the dirty bits first
/datum/outpost_ambient_work/mop
	works_on = list(/turf/open)
	works_on_floor = TRUE
	duration_low = 6 SECONDS
	duration_high = 12 SECONDS
	sounds = list('sound/effects/slosh.ogg')
	sound_volume = 20

/// Any open floor will do, but half the time only a dirty one
/datum/outpost_ambient_work/mop/accepts(atom/target)
	if(!..())
		return FALSE
	return prob(50) || !!(locate(/obj/effect/decal/cleanable) in target)

/// The mop goes back and forth
/datum/outpost_ambient_work/mop/tick(datum/component/outpost_ambient_worker/worker, atom/target)
	var/atom/movable/body = worker.parent
	body.setDir(turn(worker.work_dir, pick(90, -90)))
	return ..()

#undef OUTPOST_WORK_MACHINE_EXCEPTIONS
