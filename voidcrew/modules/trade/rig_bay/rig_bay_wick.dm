/**
 * # Wick's routine
 *
 * Wick (/mob/living/basic/outpost_trader/suit_fitter) works on the mechs hanging in the Rig Bay
 * between customers. He walks to a stand, welds or ratchets at the mech for a while, walks back
 * to his counter and waits there before the next job. Nothing he does changes the mech: it is for
 * show, like the rest of the ambient work loop (voidcrew/modules/player_outposts/outpost_ambient_work.dm).
 *
 * Serving comes first. While a player is within RIG_BAY_WICK_SERVE_RANGE tiles of him in the bay, or
 * has his shop window open, he drops what he is doing, faces them and stays put. He takes no new job
 * until RIG_BAY_WICK_RESUME after they have gone. A player waiting at the counter while he is out on
 * the floor calls him back.
 *
 * Nothing here knows the map. His room is the floor he can reach from his spawn tile, closed off by
 * walls, doors, windows and /obj/effect/landmark/outpost_work_threshold. Stands are found in it at
 * runtime. He never stands on a stand or on the tile in front of one (the lane a sold mech drives
 * out along), not even in passing: he walks his own cardinal path over his room, which leaves those
 * tiles out.
 *
 * Hooked up from setup_from_shop() below, which the outpost's interior link (or Initialize, on the
 * round-start pre-load) already calls. The shop and stand code need no call into this file.
 */

/// How far from his spawn tile Wick's room may reach: the ordinary worker range. Walls and thresholds close it.
#define RIG_BAY_WICK_RANGE OUTPOST_WORK_RANGE
/// A player this close to him (or to his counter, see below) is a customer
#define RIG_BAY_WICK_SERVE_RANGE 3
/// No new job until this long after the last customer left
#define RIG_BAY_WICK_RESUME (30 SECONDS)
/// Rest at the counter between two jobs
#define RIG_BAY_WICK_REST_LOW (20 SECONDS)
#define RIG_BAY_WICK_REST_HIGH (60 SECONDS)
/// One step of his walk
#define RIG_BAY_WICK_STEP_TIME (0.5 SECONDS)
/// Beat of the work itself, as the base work loop
#define RIG_BAY_WICK_WORK_BEAT (2 SECONDS)
/// Failed steps in a row before he gives up on a walk
#define RIG_BAY_WICK_STUCK_LIMIT 6
/// Which of the outfit's people Wick is, so he looks the same every round
#define RIG_BAY_WICK_LOOK_NUMBER 3
/// Chance he mutters something when he starts on a mech
#define RIG_BAY_WICK_WORK_LINE_CHANCE 25

#define BB_RIG_BAY_WICK_CUSTOMER "rig_bay_wick_customer"
/// Blackboard: failed steps in a row on the current walk
#define BB_RIG_BAY_WICK_STUCK "rig_bay_wick_stuck"

// =========================================================================
// THE MOB
// =========================================================================

/mob/living/basic/outpost_trader/suit_fitter
	ai_controller = /datum/ai_controller/basic_controller/rig_bay_wick
	/// What he holds right now: "weld", "tool" or null
	var/rig_bay_look
	/// Bumped per look build, so a slow build never lands over a newer one
	var/rig_bay_look_serial = 0

/**
 * As the parent, but dressed through the outpost worker looks (one person, three poses: idle,
 * welding, wrench), so his face doesn't change when he picks up a tool. The parent's
 * apply_dynamic_human_appearance() is async too and would race the work looks, so it is not called.
 */
/mob/living/basic/outpost_trader/suit_fitter/setup_from_shop()
	if(shop_setup_done || !shop)
		return
	shop_setup_done = TRUE
	name = shop.trader_name
	real_name = shop.trader_name
	gender = shop.trader_gender
	if(shop.trader_voice_pack)
		set_bark_voice_pack(shop.trader_voice_pack)
		var/datum/atom_voice/bark_voice = get_bark_voice()
		if(bark_voice)
			bark_voice.pitch = shop.trader_voice_pitch
	show_rig_bay_look(null)
	start_rig_bay_routine()

/// Gives him the worker component. Home is the tile he stands on now (his mapped spot).
/mob/living/basic/outpost_trader/suit_fitter/proc/start_rig_bay_routine()
	if(GetComponent(/datum/component/outpost_ambient_worker))
		return
	AddComponent(/datum/component/outpost_ambient_worker/rig_bay_wick, list(
		/datum/outpost_ambient_work/mech_service = 6,
		/datum/outpost_ambient_work/weld = 1,
		/datum/outpost_ambient_work/wrench = 1,
		/datum/outpost_ambient_work/panel = 1,
	), TRUE, CALLBACK(src, PROC_REF(show_rig_bay_look)))

/// The worker component's look callback: "weld", "tool" or null for free hands
/mob/living/basic/outpost_trader/suit_fitter/proc/show_rig_bay_look(look)
	rig_bay_look = look
	INVOKE_ASYNC(src, PROC_REF(build_rig_bay_look))

/// Can sleep: the first build dresses a dummy
/mob/living/basic/outpost_trader/suit_fitter/proc/build_rig_bay_look()
	if(QDELETED(src) || !shop)
		return
	var/serial = ++rig_bay_look_serial
	var/list/looks = get_outpost_worker_looks(shop.trader_outfit, shop.trader_gender, RIG_BAY_WICK_LOOK_NUMBER)
	if(QDELETED(src) || serial != rig_bay_look_serial || !length(looks))
		return
	apply_outpost_npc_look(src, looks[rig_bay_look] || looks["idle"])
	// Applying a look wipes every overlay, the welding sparks included
	var/datum/component/outpost_ambient_worker/worker = GetComponent(/datum/component/outpost_ambient_worker)
	if(worker?.work_overlay)
		add_overlay(worker.work_overlay)

// =========================================================================
// THE WORKER
// =========================================================================

/**
 * The ambient worker with a bigger room, no stand or lane tiles in it, his own walk over it, a
 * longer rest and a way back to the counter.
 */
/datum/component/outpost_ambient_worker/rig_bay_wick
	/// The way he faces at his counter
	var/home_dir = SOUTH
	/// Stand tiles in reach of home, as an assoc list. Rebuilt with the room.
	var/list/stand_tiles
	/// The tile in front of each stand, as an assoc list. Rebuilt with the room.
	var/list/lane_tiles

/datum/component/outpost_ambient_worker/rig_bay_wick/Initialize(list/work_weights, keep_off_doorways = FALSE, datum/callback/on_look)
	. = ..()
	if(. == COMPONENT_INCOMPATIBLE)
		return
	var/atom/movable/body = parent
	home_dir = body.dir

/datum/component/outpost_ambient_worker/rig_bay_wick/Destroy(force)
	stand_tiles = null
	lane_tiles = null
	return ..()

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

/datum/component/outpost_ambient_worker/rig_bay_wick/stop_work()
	var/was_working = !isnull(work)
	..()
	if(was_working)
		next_work_at = world.time + rand(RIG_BAY_WICK_REST_LOW, RIG_BAY_WICK_REST_HIGH)

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
// AI
// =========================================================================

/**
 * Passive, like the ambient NPCs: no targeting, so the outpost turrets read him as harmless, and
 * nothing at all while no player is near.
 */
/datum/ai_controller/basic_controller/rig_bay_wick
	blackboard = list()
	ai_traits = PASSIVE_AI_FLAGS
	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = null
	planning_subtrees = list(
		/datum/ai_planning_subtree/rig_bay_serve,
		/datum/ai_planning_subtree/rig_bay_wick_work,
	)
	/// When a customer was last seen
	var/last_customer_at = -RIG_BAY_WICK_RESUME
	/// The customer being served now, if any
	var/datum/weakref/customer_ref

/datum/ai_controller/basic_controller/rig_bay_wick/TryPossessPawn(atom/new_pawn)
	if(!istype(new_pawn, /mob/living/basic/outpost_trader))
		return AI_CONTROLLER_INCOMPATIBLE
	return ..()

/datum/ai_controller/basic_controller/rig_bay_wick/proc/get_worker()
	return pawn?.GetComponent(/datum/component/outpost_ambient_worker/rig_bay_wick)

/**
 * A player within RIG_BAY_WICK_SERVE_RANGE of `center`, standing in the bay (so someone walking
 * past outside the windows doesn't count), on foot or in a vehicle. Null if there is none.
 */
/datum/ai_controller/basic_controller/rig_bay_wick/proc/find_customer(atom/center)
	var/datum/component/outpost_ambient_worker/rig_bay_wick/worker = get_worker()
	if(isnull(worker) || isnull(get_turf(center)))
		return null
	for(var/atom/movable/thing in range(RIG_BAY_WICK_SERVE_RANGE, center))
		if(thing == pawn || !worker.in_bay(get_turf(thing)))
			continue
		if(isliving(thing))
			if(is_customer(thing))
				return thing
		else if(istype(thing, /obj/vehicle))
			var/obj/vehicle/ride = thing
			for(var/mob/living/rider in ride.occupants)
				if(is_customer(rider))
					return rider
	return null

/datum/ai_controller/basic_controller/rig_bay_wick/proc/is_customer(mob/living/someone)
	return someone != pawn && someone.stat != DEAD && !!GET_CLIENT(someone)

/// Someone with his shop window open, wherever they stand
/datum/ai_controller/basic_controller/rig_bay_wick/proc/find_shopper()
	var/mob/living/basic/outpost_trader/wick = pawn
	if(!istype(wick) || !wick.shop_ui)
		return null
	for(var/datum/tgui/window as anything in wick.shop_ui.open_uis)
		var/mob/living/viewer = window.user
		if(istype(viewer) && is_customer(viewer))
			return viewer
	return null

/// Whether a customer is at him right now. Checked by his jobs on every beat.
/datum/ai_controller/basic_controller/rig_bay_wick/proc/customer_at_hand()
	return find_customer(pawn) || find_shopper()

/**
 * First in planning. With a customer at him: drop everything, face them and stay. With one
 * waiting at his counter while he is out on the floor: walk back. Either way no new job until
 * RIG_BAY_WICK_RESUME after the last of them has gone.
 */
/datum/ai_planning_subtree/rig_bay_serve

/datum/ai_planning_subtree/rig_bay_serve/SelectBehaviors(datum/ai_controller/basic_controller/rig_bay_wick/controller, seconds_per_tick)
	var/datum/component/outpost_ambient_worker/rig_bay_wick/worker = controller.get_worker()
	if(isnull(worker) || controller.ai_status != AI_STATUS_ON)
		return
	var/mob/living/customer = controller.customer_at_hand()
	var/calling = FALSE
	if(isnull(customer) && get_turf(controller.pawn) != worker.home)
		customer = controller.find_customer(worker.home)
		calling = !isnull(customer)
	var/mob/living/old_customer = controller.customer_ref?.resolve()
	if(isnull(customer))
		controller.customer_ref = null
		controller.clear_blackboard_key(BB_RIG_BAY_WICK_CUSTOMER)
		return
	// A new face, or someone back after he'd gone back to work, gets a word
	var/greet = customer != old_customer && world.time > controller.last_customer_at + RIG_BAY_WICK_RESUME
	controller.last_customer_at = world.time
	worker.next_work_at = max(worker.next_work_at, world.time + RIG_BAY_WICK_RESUME)
	controller.customer_ref = WEAKREF(customer)
	controller.set_blackboard_key(BB_RIG_BAY_WICK_CUSTOMER, customer)
	if(greet)
		var/mob/living/basic/outpost_trader/wick = controller.pawn
		wick.speak_line(TRADER_LINE_IDLE, rig_bay_wick_greeting(calling))
	if(calling)
		controller.queue_behavior(/datum/ai_behavior/rig_bay_wick_go_home)
		return SUBTREE_RETURN_FINISH_PLANNING
	controller.queue_behavior(/datum/ai_behavior/rig_bay_wick_serve, BB_RIG_BAY_WICK_CUSTOMER)
	return SUBTREE_RETURN_FINISH_PLANNING

/// What he says to a new customer: from across the bay, or face to face
/proc/rig_bay_wick_greeting(calling)
	if(calling)
		return pick("Be right with you.", "Coming. Don't touch anything.", "One second.")
	return pick("Yeah?", "What do you need?", "Help you?", "What can I get you?")

/// Mech work when it's due, the walk back to the counter after it, and waiting there between jobs
/datum/ai_planning_subtree/rig_bay_wick_work

/datum/ai_planning_subtree/rig_bay_wick_work/SelectBehaviors(datum/ai_controller/basic_controller/rig_bay_wick/controller, seconds_per_tick)
	var/datum/component/outpost_ambient_worker/rig_bay_wick/worker = controller.get_worker()
	if(worker && controller.ai_status == AI_STATUS_ON && !worker.check_leash())
		if(world.time >= worker.next_work_at)
			var/list/job = worker.find_work()
			if(job)
				worker.planned_work = job[3]
				controller.set_blackboard_key(BB_OUTPOST_WORK_TARGET, job[1])
				controller.set_blackboard_key(BB_OUTPOST_WORK_SPOT, job[2])
				controller.queue_behavior(/datum/ai_behavior/rig_bay_wick_job, BB_OUTPOST_WORK_TARGET, BB_OUTPOST_WORK_SPOT)
				return SUBTREE_RETURN_FINISH_PLANNING
			worker.next_work_at = world.time + OUTPOST_WORK_RETRY
		if(get_turf(controller.pawn) != worker.home)
			controller.queue_behavior(/datum/ai_behavior/rig_bay_wick_go_home)
			return SUBTREE_RETURN_FINISH_PLANNING
	// Queued even with nothing to do, so planning never fails and churns the controller
	controller.queue_behavior(/datum/ai_behavior/rig_bay_wick_idle)
	return SUBTREE_RETURN_FINISH_PLANNING

/// Walks to the spot by his own path, then works until the job is done or a customer turns up
/datum/ai_behavior/rig_bay_wick_job
	action_cooldown = RIG_BAY_WICK_STEP_TIME

/datum/ai_behavior/rig_bay_wick_job/get_cooldown(datum/ai_controller/basic_controller/rig_bay_wick/cooldown_for)
	var/datum/component/outpost_ambient_worker/worker = cooldown_for.pawn?.GetComponent(/datum/component/outpost_ambient_worker)
	return worker?.work ? RIG_BAY_WICK_WORK_BEAT : RIG_BAY_WICK_STEP_TIME

/datum/ai_behavior/rig_bay_wick_job/setup(datum/ai_controller/controller, target_key, spot_key)
	if(isnull(controller.blackboard[spot_key]) || isnull(controller.blackboard[target_key]))
		return FALSE
	controller.set_blackboard_key(BB_RIG_BAY_WICK_STUCK, 0)
	return TRUE

/datum/ai_behavior/rig_bay_wick_job/perform(seconds_per_tick, datum/ai_controller/basic_controller/rig_bay_wick/controller, target_key, spot_key)
	var/datum/component/outpost_ambient_worker/rig_bay_wick/worker = controller.get_worker()
	var/atom/target = controller.blackboard[target_key]
	var/turf/spot = controller.blackboard[spot_key]
	if(isnull(worker) || QDELETED(target) || controller.ai_status != AI_STATUS_ON || controller.customer_at_hand())
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	if(isnull(worker.work))
		if(get_turf(controller.pawn) == spot)
			return worker.start_work(target) ? AI_BEHAVIOR_DELAY : (AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED)
		if(!worker.can_stand_at(spot) || !rig_bay_wick_step(controller, worker, spot))
			return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
		return AI_BEHAVIOR_DELAY
	if(worker.continue_work())
		return AI_BEHAVIOR_DELAY
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/rig_bay_wick_job/finish_action(datum/ai_controller/controller, succeeded, target_key, spot_key)
	. = ..()
	var/datum/component/outpost_ambient_worker/worker = controller.pawn?.GetComponent(/datum/component/outpost_ambient_worker)
	if(worker)
		worker.planned_work = null
		worker.stop_work()
		if(!succeeded)
			worker.next_work_at = max(worker.next_work_at, world.time + OUTPOST_WORK_RETRY)
	controller.clear_blackboard_key(target_key)
	controller.clear_blackboard_key(spot_key)

/// One step of a walk. FALSE once he has been stuck too long.
/proc/rig_bay_wick_step(datum/ai_controller/controller, datum/component/outpost_ambient_worker/rig_bay_wick/worker, turf/goal)
	if(worker.walk_toward(goal))
		controller.set_blackboard_key(BB_RIG_BAY_WICK_STUCK, 0)
		return TRUE
	var/stuck = controller.blackboard[BB_RIG_BAY_WICK_STUCK] + 1
	controller.set_blackboard_key(BB_RIG_BAY_WICK_STUCK, stuck)
	return stuck < RIG_BAY_WICK_STUCK_LIMIT

/// Back to the counter, then faces the way he was mapped
/datum/ai_behavior/rig_bay_wick_go_home
	action_cooldown = RIG_BAY_WICK_STEP_TIME

/datum/ai_behavior/rig_bay_wick_go_home/setup(datum/ai_controller/controller)
	controller.set_blackboard_key(BB_RIG_BAY_WICK_STUCK, 0)
	return TRUE

/datum/ai_behavior/rig_bay_wick_go_home/perform(seconds_per_tick, datum/ai_controller/basic_controller/rig_bay_wick/controller)
	var/datum/component/outpost_ambient_worker/rig_bay_wick/worker = controller.get_worker()
	if(isnull(worker) || controller.ai_status != AI_STATUS_ON)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	var/atom/movable/body = controller.pawn
	if(get_turf(body) == worker.home)
		body.setDir(worker.home_dir)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	// Someone came up to him on the way: stop here and serve them
	if(controller.customer_at_hand())
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	if(!rig_bay_wick_step(controller, worker, worker.home))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	return AI_BEHAVIOR_DELAY

/// Faces the customer and stays put. Planning runs on, and replaces it once they've gone.
/datum/ai_behavior/rig_bay_wick_serve
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION
	action_cooldown = 1 SECONDS

/datum/ai_behavior/rig_bay_wick_serve/perform(seconds_per_tick, datum/ai_controller/controller, customer_key)
	var/mob/living/customer = controller.blackboard[customer_key]
	var/atom/movable/body = controller.pawn
	if(!QDELETED(customer) && get_turf(customer) != get_turf(body))
		body.setDir(get_cardinal_dir(body, customer))
	return AI_BEHAVIOR_DELAY

/// Nothing to do: stand there. Planning runs on and replaces it.
/datum/ai_behavior/rig_bay_wick_idle
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION
	action_cooldown = 2 SECONDS

/datum/ai_behavior/rig_bay_wick_idle/perform(seconds_per_tick, datum/ai_controller/controller)
	return AI_BEHAVIOR_DELAY

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

/// Only a mech hanging on its stand, never one that's sold or driven in by a customer
/datum/outpost_ambient_work/mech_service/accepts(atom/target)
	return ..() && HAS_TRAIT(target, TRAIT_RIG_BAY_CLAMPED)

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
	if(prob(RIG_BAY_WICK_WORK_LINE_CHANCE) && istype(body, /mob/living/basic/outpost_trader))
		var/mob/living/basic/outpost_trader/wick = body
		wick.speak_line(TRADER_LINE_IDLE, pick(
			"Who torqued this? A child?",
			"That's not a bolt. That's a suggestion.",
			"Hydraulics are weeping again.",
			"Come on. Come on. There.",
			"Who keeps parking these in the rain?",
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
#undef RIG_BAY_WICK_WORK_BEAT
#undef RIG_BAY_WICK_STUCK_LIMIT
#undef RIG_BAY_WICK_LOOK_NUMBER
#undef RIG_BAY_WICK_WORK_LINE_CHANCE
#undef BB_RIG_BAY_WICK_CUSTOMER
#undef BB_RIG_BAY_WICK_STUCK
