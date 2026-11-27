/**
 * # Wick's routine
 *
 * Wick (/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter) works on the mechs hanging
 * in the Rig Bay between customers. He walks to a stand, welds or ratchets at the mech for a while, walks
 * back to his counter and waits there before the next job. Nothing he does changes the mech: it is for
 * show, like the rest of the ambient work loop (voidcrew/modules/player_outposts/outpost_ambient_work.dm).
 *
 * It runs on the ambient NPC routine (voidcrew/modules/ambient_npcs/ambient_activity.dm) in place of the
 * plain trader's keep_counter: pick_activity() below chooses between a job on the floor
 * (/datum/ambient_activity/rig_bay_job), the walk back, and minding the counter. Ducking, fleeing and
 * every other trader reaction outrank these and replace them as for any trader.
 *
 * Serving comes first. His shop only trades while he is at his counter (shop.is_open()), so while a
 * player is in the bay within RIG_BAY_WICK_SERVE_RANGE tiles of him or of his counter, or has his shop
 * window open, he drops what he is doing and walks back to the counter. He takes no new job until
 * RIG_BAY_WICK_RESUME after the last of them has gone.
 *
 * Nothing here knows the map. His room is the floor he can reach from his counter, closed off by walls,
 * doors, windows and /obj/effect/landmark/outpost_work_threshold. Stands are found in it at runtime. He
 * never stands on a stand or on the tile in front of one (the lane a sold mech drives out along), not
 * even in passing: he walks his own cardinal path over his room, which leaves those tiles out. The room
 * is kept by a /datum/component/outpost_ambient_worker/rig_bay_wick that stays on him; it holds him in
 * only while he takes a step of that path, so grabs, shoves, fleeing and the trader's own walks are left
 * alone.
 *
 * Hooked up from setup_from_shop() below. The shop and stand code need no call into this file.
 */

/// How far from his counter Wick's room may reach: the ordinary worker range. Walls and thresholds close it.
#define RIG_BAY_WICK_RANGE OUTPOST_WORK_RANGE
/// A player this close to him (or to his counter) is a customer
#define RIG_BAY_WICK_SERVE_RANGE 3
/// No new job until this long after the last customer left
#define RIG_BAY_WICK_RESUME (30 SECONDS)
/// Rest at the counter between two jobs
#define RIG_BAY_WICK_REST_LOW (20 SECONDS)
#define RIG_BAY_WICK_REST_HIGH (60 SECONDS)
/// One step of his walk
#define RIG_BAY_WICK_STEP_TIME (0.5 SECONDS)
/// Failed steps in a row before he gives up on a walk
#define RIG_BAY_WICK_STUCK_LIMIT 6
/// Chance he mutters something when he starts on a mech
#define RIG_BAY_WICK_WORK_LINE_CHANCE 25

// =========================================================================
// THE MAN
// =========================================================================

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter
	/// world.time he may take his next job
	var/rig_bay_next_job_at = 0
	/// When a customer was last seen
	var/rig_bay_last_customer_at = -RIG_BAY_WICK_RESUME
	/// The customer seen last, so a new face gets a word
	var/datum/weakref/rig_bay_customer_ref
	/// The way he faces at his counter, as mapped
	var/rig_bay_home_dir = SOUTH

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter/Destroy()
	rig_bay_customer_ref = null
	return ..()

// His leash takes in the bay floor round his counter. His room (the worker component) keeps his own
// steps off the stands and their lanes. He trades only while back within reach of the counter.
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter/leash_to(turf/counter)
	if(!counter)
		leash_bounds = null
		return
	leash_bounds = list(counter.x - RIG_BAY_WICK_RANGE, counter.y - RIG_BAY_WICK_RANGE, counter.x + RIG_BAY_WICK_RANGE, counter.y + RIG_BAY_WICK_RANGE, counter.z)

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter/setup_from_shop()
	. = ..()
	if(shop_setup_done)
		start_rig_bay_routine()

/// Gives him the worker component, rooted at his counter. Safe to call again.
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter/proc/start_rig_bay_routine()
	if(rig_bay_worker())
		return
	var/turf/counter = shop?.counter_turf || home || get_turf(src)
	if(!counter)
		return
	rig_bay_home_dir = dir
	var/datum/component/outpost_ambient_worker/rig_bay_wick/worker = AddComponent(/datum/component/outpost_ambient_worker/rig_bay_wick, list(
		/datum/outpost_ambient_work/mech_service = 6,
		/datum/outpost_ambient_work/weld = 1,
		/datum/outpost_ambient_work/wrench = 1,
		/datum/outpost_ambient_work/panel = 1,
	), TRUE, CALLBACK(src, TYPE_PROC_REF(/mob/living/carbon/human/npc/ambient_npc, show_work_look)))
	if(worker)
		worker.home = counter
		worker.room = null
	rig_bay_next_job_at = world.time + rand(5 SECONDS, 25 SECONDS)

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter/proc/rig_bay_worker()
	return GetComponent(/datum/component/outpost_ambient_worker/rig_bay_wick)

/**
 * Back to the counter when away from it, a job when one is due and nobody wants him, the counter
 * otherwise. Without his routine (no worker yet) he is a plain trader.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter/pick_activity()
	var/datum/component/outpost_ambient_worker/rig_bay_wick/worker = rig_bay_worker()
	if(isnull(worker) || isnull(worker.home))
		return ..()
	if(get_turf(src) != worker.home)
		if(start_activity(new /datum/ambient_activity/rig_bay_job/return_home(src)))
			return activity
	else if(world.time >= rig_bay_next_job_at && !rig_bay_check_customers())
		if(start_activity(new /datum/ambient_activity/rig_bay_job(src)))
			return activity
		rig_bay_next_job_at = world.time + OUTPOST_WORK_RETRY
	return start_activity(new /datum/ambient_activity/keep_counter/rig_bay(src))

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter/shift_times(delay)
	. = ..()
	rig_bay_next_job_at = ambient_shifted(rig_bay_next_job_at, delay)
	rig_bay_last_customer_at = ambient_shifted(rig_bay_last_customer_at, delay)

/// Whether `someone` is a player who could want serving
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter/proc/rig_bay_is_customer(mob/living/someone)
	return someone != src && someone.stat != DEAD && !!GET_CLIENT(someone)

/**
 * A player within RIG_BAY_WICK_SERVE_RANGE of `center`, standing in the bay (so someone walking past
 * outside the windows doesn't count), on foot or in a vehicle. Null if there is none.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter/proc/rig_bay_find_customer(atom/center)
	var/datum/component/outpost_ambient_worker/rig_bay_wick/worker = rig_bay_worker()
	if(isnull(worker) || isnull(get_turf(center)))
		return null
	for(var/atom/movable/thing in range(RIG_BAY_WICK_SERVE_RANGE, center))
		if(thing == src || !worker.in_bay(get_turf(thing)))
			continue
		if(isliving(thing))
			if(rig_bay_is_customer(thing))
				return thing
		else if(istype(thing, /obj/vehicle))
			var/obj/vehicle/ride = thing
			for(var/mob/living/rider in ride.occupants)
				if(rig_bay_is_customer(rider))
					return rider
	return null

/// Someone with his shop window open, wherever they stand
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter/proc/rig_bay_find_shopper()
	if(!shop_ui)
		return null
	for(var/datum/tgui/window as anything in shop_ui.open_uis)
		var/mob/living/viewer = window.user
		if(istype(viewer) && rig_bay_is_customer(viewer))
			return viewer
	return null

/**
 * The customer who wants him now, if any: near him, near his counter or in his shop window. Notes the
 * time (no job until RIG_BAY_WICK_RESUME after) and gives a new face a word.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter/proc/rig_bay_check_customers()
	var/datum/component/outpost_ambient_worker/rig_bay_wick/worker = rig_bay_worker()
	if(isnull(worker))
		return null
	var/away = !isnull(worker.home) && get_turf(src) != worker.home
	var/mob/living/customer = rig_bay_find_customer(src) || rig_bay_find_shopper()
	if(isnull(customer) && away)
		customer = rig_bay_find_customer(worker.home)
	if(isnull(customer))
		rig_bay_customer_ref = null
		return null
	var/mob/living/old_customer = rig_bay_customer_ref?.resolve()
	var/greet = customer != old_customer && world.time > rig_bay_last_customer_at + RIG_BAY_WICK_RESUME
	rig_bay_last_customer_at = world.time
	rig_bay_next_job_at = max(rig_bay_next_job_at, world.time + RIG_BAY_WICK_RESUME)
	rig_bay_customer_ref = WEAKREF(customer)
	if(greet)
		speak_line(TRADER_LINE_IDLE, rig_bay_wick_greeting(away))
	return customer

/// What he says to a new customer: on his way over, or face to face
/proc/rig_bay_wick_greeting(calling)
	if(calling)
		return pick("Be right with you.", "Coming. Don't touch anything.", "One second.")
	return pick("Yeah?", "What do you need?", "Help you?", "What can I get you?")

// =========================================================================
// THE COUNTER
// =========================================================================

/// Minding the counter between jobs: facing whoever wants him, or the way he was set
/datum/ambient_activity/keep_counter/rig_bay
	duration_low = RIG_BAY_WICK_REST_LOW
	duration_high = RIG_BAY_WICK_REST_HIGH

/datum/ambient_activity/keep_counter/rig_bay/act(seconds)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter/wick = doer
	if(!istype(wick))
		return ..()
	var/mob/living/customer = wick.rig_bay_check_customers()
	if(wick.buckled)
		return AMBIENT_STEP_CONTINUE
	if(customer && get_turf(customer) != get_turf(wick))
		wick.setDir(get_cardinal_dir(wick, customer))
	else if(!customer && wick.dir != wick.rig_bay_home_dir && prob(20))
		wick.setDir(wick.rig_bay_home_dir)
	return AMBIENT_STEP_CONTINUE

// =========================================================================
// THE JOB
// =========================================================================

/**
 * A job on the bay floor: his own walk to the spot, the work, and his own walk back to the counter. A
 * customer turning up sends him straight back. Walks happen here, step by step over his room, rather
 * than through the ambient runner's pathing, which would cut across the stands' lanes.
 */
/datum/ambient_activity/rig_bay_job
	name = "working on a rig"
	/// His worker component
	var/datum/component/outpost_ambient_worker/rig_bay_wick/worker
	var/datum/weakref/target_ref
	var/datum/outpost_ambient_work/kind
	/// Where he stands to work
	var/turf/work_spot
	/// Done here, or called back: on his way to the counter
	var/going_home = FALSE
	/// Failed steps in a row
	var/stuck = 0

/datum/ambient_activity/rig_bay_job/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter/wick = doer
	if(!istype(wick) || !isturf(wick.loc))
		return FALSE
	worker = wick.rig_bay_worker()
	if(QDELETED(worker) || isnull(worker.home))
		return FALSE
	if(going_home)
		return TRUE
	var/list/job = worker.find_work()
	if(length(job) != 3)
		return FALSE
	target_ref = WEAKREF(job[1])
	work_spot = job[2]
	kind = job[3]
	return TRUE

/datum/ambient_activity/rig_bay_job/Destroy()
	worker = null
	kind = null
	work_spot = null
	return ..()

/datum/ambient_activity/rig_bay_job/act(seconds)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter/wick = doer
	if(QDELETED(worker))
		return AMBIENT_STEP_DONE
	if(wick.rig_bay_check_customers() && !going_home)
		head_home()
	// A gun on him: he stands still
	if(wick.has_status_effect(/datum/status_effect/grouped/heldup))
		worker.stop_work()
		return AMBIENT_STEP_CONTINUE
	if(going_home)
		return walk_home()
	if(worker.work)
		if(worker.continue_work())
			return AMBIENT_STEP_CONTINUE
		wick.rig_bay_next_job_at = world.time + rand(RIG_BAY_WICK_REST_LOW, RIG_BAY_WICK_REST_HIGH)
		head_home()
		return walk_home()
	var/atom/target = target_ref?.resolve()
	if(QDELETED(target))
		head_home()
		return walk_home()
	if(get_turf(wick) == work_spot)
		worker.planned_work = kind
		if(!worker.start_work(target))
			give_up()
		return AMBIENT_STEP_CONTINUE
	if(!worker.can_stand_at(work_spot) || !take_step(work_spot))
		give_up()
	return AMBIENT_STEP_CONTINUE

/// Off the job, and back to the counter
/datum/ambient_activity/rig_bay_job/proc/head_home()
	going_home = TRUE
	stuck = 0
	if(!QDELETED(worker))
		worker.planned_work = null
		worker.stop_work()

/// Couldn't get to it or start it: back to the counter, and a while before the next try
/datum/ambient_activity/rig_bay_job/proc/give_up()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter/wick = doer
	wick.rig_bay_next_job_at = max(wick.rig_bay_next_job_at, world.time + OUTPOST_WORK_RETRY)
	head_home()

/// One step back to the counter; done there, facing the way he was set
/datum/ambient_activity/rig_bay_job/proc/walk_home()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter/wick = doer
	if(get_turf(wick) == worker.home)
		if(!wick.buckled)
			wick.setDir(wick.rig_bay_home_dir)
		return AMBIENT_STEP_DONE
	// No way back over his room: the plain counter activity walks him back by the ordinary path
	return take_step(worker.home) ? AMBIENT_STEP_CONTINUE : AMBIENT_STEP_DONE

/// One step towards `goal` now and another half a beat later. FALSE once he has been stuck too long.
/datum/ambient_activity/rig_bay_job/proc/take_step(turf/goal)
	if(!step_toward(goal))
		return ++stuck < RIG_BAY_WICK_STUCK_LIMIT
	stuck = 0
	if(get_turf(doer) != goal)
		addtimer(CALLBACK(src, PROC_REF(half_step), goal), RIG_BAY_WICK_STEP_TIME)
	return TRUE

/// The second step of a beat, if he is still on the same walk
/datum/ambient_activity/rig_bay_job/proc/half_step(turf/goal)
	if(QDELETED(doer) || QDELETED(worker) || doer.activity != src || !doer.can_act())
		return
	if(worker.work || get_turf(doer) == goal || goal != (going_home ? worker.home : work_spot))
		return
	if(doer.has_status_effect(/datum/status_effect/grouped/heldup))
		return
	step_toward(goal)

/datum/ambient_activity/rig_bay_job/proc/step_toward(turf/goal)
	if(QDELETED(worker) || !isturf(doer.loc) || doer.pulledby || doer.buckled)
		return FALSE
	return worker.walk_toward(goal)

/datum/ambient_activity/rig_bay_job/finish()
	if(!QDELETED(worker))
		worker.planned_work = null
		worker.stop_work()
	return ..()

/datum/ambient_activity/rig_bay_job/shift_times(delay)
	. = ..()
	if(!QDELETED(worker))
		worker.work_ends_at = ambient_shifted(worker.work_ends_at, delay)

/// Just the walk back to the counter (after a fight, a shove or a quiet spell found him out on the floor)
/datum/ambient_activity/rig_bay_job/return_home
	name = "heading back to the counter"
	going_home = TRUE

// =========================================================================
// THE ROOM
// =========================================================================

/**
 * The ambient worker with a bigger room, no stand or lane tiles in it, the whole room searched for work
 * and his own walk over it. It stays on him, but holds him in his room only while he takes a step of
 * that walk; the base worker's teleport and polymorph guards are left off (the trader has its own).
 */
/datum/component/outpost_ambient_worker/rig_bay_wick
	/// Stand tiles in reach of home, as an assoc list. Rebuilt with the room.
	var/list/stand_tiles
	/// The tile in front of each stand, as an assoc list. Rebuilt with the room.
	var/list/lane_tiles
	/// Set while he takes a step of his own walk
	var/stepping = FALSE

/datum/component/outpost_ambient_worker/rig_bay_wick/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(on_pre_move))

/datum/component/outpost_ambient_worker/rig_bay_wick/Destroy(force)
	stand_tiles = null
	lane_tiles = null
	return ..()

/datum/component/outpost_ambient_worker/rig_bay_wick/on_pre_move(atom/movable/source, atom/new_loc)
	SIGNAL_HANDLER
	if(!stepping)
		return NONE
	return ..()

/datum/component/outpost_ambient_worker/rig_bay_wick/step_to_tile(turf/next)
	var/atom/movable/body = parent
	body.set_glide_size(DELAY_TO_GLIDE_SIZE(RIG_BAY_WICK_STEP_TIME))
	stepping = TRUE
	. = body.Move(next, get_dir(body, next))
	stepping = FALSE

/**
 * As the parent's room, out to RIG_BAY_WICK_RANGE, less every stand tile and every stand's front
 * tile. Stands and thresholds are whatever the map has.
 */
/datum/component/outpost_ambient_worker/rig_bay_wick/get_room()
	if(room && world.time < room_built_at + OUTPOST_WORK_ROOM_REFRESH)
		return room
	room_built_at = world.time
	room = list()
	stand_tiles = list()
	lane_tiles = list()
	if(!isopenturf(home))
		return room
	for(var/obj/structure/rig_bay_stand/stand in range(RIG_BAY_WICK_RANGE, home))
		var/turf/stand_tile = get_turf(stand)
		stand_tiles[stand_tile] = TRUE
		var/turf/front = get_step(stand_tile, stand.dir)
		if(front)
			lane_tiles[front] = TRUE
	var/area/home_area = get_area(home)
	var/list/docking_floor = docking_floor_near(home)
	var/list/lifts = lift_turfs_near(home, RIG_BAY_WICK_RANGE)
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
			if(stand_tiles[next] || lane_tiles[next])
				continue
			if(get_dist(next, home) > RIG_BAY_WICK_RANGE || !room_tile_allowed(next, home_area, docking_floor, lifts))
				continue
			room[next] = TRUE
			queue += next
	return room

/// Whether `tile` is part of the bay: his room, a stand or a lane
/datum/component/outpost_ambient_worker/rig_bay_wick/proc/in_bay(turf/tile)
	var/list/tiles = get_room()
	return tiles[tile] || stand_tiles[tile] || lane_tiles[tile]

/**
 * Mechs on the stands, or any other prop in or against his room (a wreck, a rack, a wall panel).
 * Unlike the parent, the whole room is searched, not just a few tiles round where he stands.
 */
/datum/component/outpost_ambient_worker/rig_bay_wick/find_work()
	if(isnull(get_turf(parent)) || !length(work_weights))
		return null
	var/list/weights = work_weights.Copy()
	while(length(weights))
		var/work_type = pick_weight(weights)
		weights -= work_type
		var/datum/outpost_ambient_work/kind = outpost_ambient_work(work_type)
		var/list/job = istype(kind, /datum/outpost_ambient_work/mech_service) ? find_mech_job(kind) : find_room_job(kind)
		if(job)
			return job
	return null

/// Something in or against his room that `kind` works on, never a stand's mech, as find_work() returns
/datum/component/outpost_ambient_worker/rig_bay_wick/proc/find_room_job(datum/outpost_ambient_work/kind)
	if(kind.works_on_floor)
		return null
	var/list/tiles = get_room()
	var/area/home_area = get_area(home)
	var/list/search = list()
	for(var/turf/tile as anything in tiles)
		search[tile] = TRUE
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(tile, direction)
			if(next && !stand_tiles[next] && get_area(next) == home_area)
				search[next] = TRUE
	var/checked = 0
	for(var/turf/tile as anything in shuffle(search))
		for(var/obj/thing in tile)
			if(++checked > OUTPOST_WORK_SEARCH_LIMIT)
				return null
			if(thing.invisibility || IS_WEAKREF_OF(thing, last_target) || !kind.accepts(thing))
				continue
			var/turf/spot = spot_for(thing)
			if(spot)
				return list(thing, spot, kind)
	return null

/// A mech on one of his stands that the job accepts, and a free tile beside it, as find_work() returns
/datum/component/outpost_ambient_worker/rig_bay_wick/proc/find_mech_job(datum/outpost_ambient_work/kind)
	get_room()
	var/list/options = list()
	for(var/turf/stand_tile as anything in stand_tiles)
		for(var/obj/vehicle/sealed/mecha/mech in stand_tile)
			if(!IS_WEAKREF_OF(mech, last_target) && kind.accepts(mech))
				options += mech
	// The last one worked on only when it is the only one
	if(!length(options) && last_target)
		var/obj/vehicle/sealed/mecha/last_mech = last_target.resolve()
		if(istype(last_mech) && stand_tiles[get_turf(last_mech)] && kind.accepts(last_mech))
			options += last_mech
	for(var/obj/vehicle/sealed/mecha/mech as anything in shuffle(options))
		var/turf/spot = spot_for(mech)
		if(spot)
			return list(mech, spot, kind)
	return null

/**
 * The next tile on the shortest cardinal walk over his room to `goal`, or null. Tiles with
 * something solid on them (a customer included) are walked round.
 */
/datum/component/outpost_ambient_worker/rig_bay_wick/proc/next_step_to(turf/goal)
	var/turf/here = get_turf(parent)
	if(isnull(here) || isnull(goal) || here == goal)
		return null
	var/list/tiles = get_room()
	if(!tiles[goal])
		return null
	// Searched from the goal back, so the tile that reaches `here` is the step to take
	var/list/seen = list()
	seen[goal] = TRUE
	var/list/queue = list(goal)
	var/index = 1
	while(index <= length(queue))
		var/turf/tile = queue[index++]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(tile, direction)
			if(isnull(next) || seen[next])
				continue
			if(next == here)
				return tile
			seen[next] = TRUE
			if(!tiles[next] || next.is_blocked_turf(exclude_mobs = FALSE, ignore_atoms = list(parent)))
				continue
			queue += next
	return null

/// One step towards `goal`. FALSE if there is no way or the step failed.
/datum/component/outpost_ambient_worker/rig_bay_wick/proc/walk_toward(turf/goal)
	var/turf/next = next_step_to(goal)
	if(isnull(next))
		return FALSE
	var/atom/movable/body = parent
	var/turf/before = body.loc
	step_to_tile(next)
	return body.loc != before

// =========================================================================
// THE WORK
// =========================================================================

/**
 * Working on a mech hanging on a stand: a welder at a seam or a ratchet on the joints, picked per
 * job. For show only; the mech is untouched.
 */
/datum/outpost_ambient_work/mech_service
	works_on = list(/obj/vehicle/sealed/mecha)
	duration_low = 15 SECONDS
	duration_high = 30 SECONDS
	look = "tool"
	sounds = list('sound/items/tools/ratchet.ogg', 'sound/items/tools/ratchet_slow.ogg', 'sound/items/tools/crowbar.ogg')
	/// Played instead of `sounds` on a welding job
	var/list/weld_sounds = list('sound/items/tools/welder.ogg', 'sound/items/tools/welder2.ogg')

/// Only a mech hanging on its stand, never one that's beaming in, sold or driven in by a customer.
/// The clamp trait goes on at arrival, so the stand's state is checked too.
/datum/outpost_ambient_work/mech_service/accepts(atom/target)
	if(!..() || !HAS_TRAIT(target, TRAIT_RIG_BAY_CLAMPED))
		return FALSE
	var/obj/structure/rig_bay_stand/stand = locate() in get_turf(target)
	return stand?.held_mech == target && stand.stand_state == RIG_BAY_STAND_CLAMPED

/datum/outpost_ambient_work/mech_service/start(datum/component/outpost_ambient_worker/worker, atom/target)
	var/atom/movable/body = worker.parent
	if(prob(50))
		// The welder: start_work already showed the wrench, so swap it, then the sparks
		worker.on_look?.Invoke("weld")
		var/mutable_appearance/sparks = mutable_appearance('icons/effects/welding_effect.dmi', "welding_sparks", GASFIRE_LAYER, body, ABOVE_LIGHTING_PLANE)
		var/direction = worker.work_dir
		sparks.pixel_x = direction & EAST ? 12 : (direction & WEST ? -12 : 0)
		sparks.pixel_y = direction & NORTH ? 12 : (direction & SOUTH ? -6 : 0)
		worker.set_work_overlay(sparks)
		playsound(body, 'sound/items/tools/welderactivate.ogg', 25, TRUE, OUTPOST_WORK_SOUND_RANGE)
	if(prob(RIG_BAY_WICK_WORK_LINE_CHANCE) && istype(body, /mob/living/carbon/human/npc/ambient_npc/outpost/trader))
		var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/wick = body
		wick.speak_line(TRADER_LINE_IDLE, pick(
			"Who torqued this? A child?",
			"That's not a bolt. That's a suggestion.",
			"Hydraulics are weeping again.",
			"Come on. Come on. There.",
			"Who keeps parking these in the rain?",
			"Somebody's been feeding this one plasma cutter grit.",
		))

/// A welding job is the one with sparks on
/datum/outpost_ambient_work/mech_service/tick(datum/component/outpost_ambient_worker/worker, atom/target)
	var/atom/movable/body = worker.parent
	if(!worker.work_overlay)
		return ..()
	body.flash_lighting_fx(1.5, 0.8, OUTPOST_WORK_WELD_LIGHT, 0.5 SECONDS)
	if(prob(sound_chance))
		playsound(body, pick(weld_sounds), sound_volume, TRUE, OUTPOST_WORK_SOUND_RANGE)
		return TRUE
	return FALSE

/datum/outpost_ambient_work/mech_service/stop(datum/component/outpost_ambient_worker/worker)
	if(QDELETED(worker.parent) || !worker.work_overlay)
		return
	playsound(worker.parent, 'sound/items/tools/welderdeactivate.ogg', 25, TRUE, OUTPOST_WORK_SOUND_RANGE)

#undef RIG_BAY_WICK_RANGE
#undef RIG_BAY_WICK_SERVE_RANGE
#undef RIG_BAY_WICK_RESUME
#undef RIG_BAY_WICK_REST_LOW
#undef RIG_BAY_WICK_REST_HIGH
#undef RIG_BAY_WICK_STEP_TIME
#undef RIG_BAY_WICK_STUCK_LIMIT
#undef RIG_BAY_WICK_WORK_LINE_CHANCE
