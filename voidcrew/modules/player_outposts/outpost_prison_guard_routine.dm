/**
 * # Prison guards: routine
 *
 * Owner: XA (extras-plan.md 4.1). The guards' AI controller, their peaceful activities (post,
 * rounds, watching the yard, a drink at the cooler, a chat, checking on a prisoner) and the
 * response datum the dispatcher in outpost_prison_guards.dm hands out.
 *
 * As with the prisoners' routine (outpost_prison_routine.dm), the AI only walks: to the goal of
 * the guard's response when there is one, else to their activity's. The dispatcher deals with
 * responses every second; the AI ticks activities. While nobody is on the level the AI is off and
 * guards stand where they are.
 */

// What an activity's tick() wants next
#define GUARD_ACTIVITY_CONTINUE 0
#define GUARD_ACTIVITY_DONE 1
/// It set a new goal to walk to
#define GUARD_ACTIVITY_MOVE 2
/// Seconds an activity type is skipped after a guard gives up on it
#define GUARD_ACTIVITY_GIVE_UP_TIME (60 SECONDS)
/// Blackboard key: where the guard is walking to
#define BB_OUTPOST_GUARD_GOAL "outpost_guard_goal"

/// Routine activities, picked by weight: every activity type with `leisure` set
GLOBAL_LIST_INIT(outpost_guard_leisure, outpost_guard_leisure_types())

/proc/outpost_guard_leisure_types()
	var/list/types = list()
	for(var/datum/outpost_guard_activity/activity_type as anything in subtypesof(/datum/outpost_guard_activity))
		if(initial(activity_type.leisure))
			types += activity_type
	return types

// ===== RESPONSES =====

/**
 * Something the dispatcher sent a guard to deal with: an argument or fight ("fight"), a threat, a
 * hatch climb, a riot, a creature out ("shelter") or wandering off ("leash"). The guard's
 * perform_response() sets `goal` each second, which the AI walks them to.
 */
/datum/outpost_guard_response
	var/kind
	/// What incident it is, so one incident gets one guard
	var/key
	var/priority = 0
	/// The prisoner it is about, if any
	var/datum/weakref/target_ref
	/// A tile the response is about (the hatch's office side, a riot hold)
	var/turf/spot
	/// Where the guard should be now: a mob to stand beside or a tile to stand on; null when in place
	var/datum/weakref/goal_ref
	/// world.time by which they must have got there
	var/expires_at = 0
	/// Got there at least once: it no longer expires
	var/reached = FALSE
	/// The warning line is said
	var/said = FALSE
	/// Tried talking an argument down
	var/talked = FALSE
	/// A riot's doctrine right now: "hold", "follow" or "fallback"
	var/mode

/datum/outpost_guard_response/New(kind, key, priority, atom/target, turf/spot)
	. = ..()
	src.kind = kind
	src.key = key
	src.priority = priority
	target_ref = target ? WEAKREF(target) : null
	src.spot = spot

/datum/outpost_guard_response/Destroy()
	spot = null
	goal_ref = null
	target_ref = null
	return ..()

/datum/outpost_guard_response/proc/target()
	return target_ref?.resolve()

/datum/outpost_guard_response/proc/goal()
	return goal_ref?.resolve()

/datum/outpost_guard_response/proc/set_goal(atom/goal)
	goal_ref = goal ? WEAKREF(goal) : null

// ===== THE GUARD'S SIDE =====

/// Where their AI should walk them now, or null to stay put
/mob/living/basic/outpost_prison_guard/proc/walk_goal()
	if(phase == OUTPOST_GUARD_DISMISSED)
		return (leave_spot && loc != leave_spot) ? leave_spot : null
	if(phase != OUTPOST_GUARD_PRESENT)
		return null
	if(response)
		var/atom/goal = response.goal()
		return (goal && !at_goal(goal)) ? goal : null
	var/atom/goal = activity?.goal()
	return (goal && !at_goal(goal)) ? goal : null

/// A walk to `goal` failed: a response gets another try until it expires; an activity gets one more, then a rest
/mob/living/basic/outpost_prison_guard/proc/walk_failed(atom/goal)
	if(response || !activity || goal != activity.goal())
		return
	if(++activity.failed_moves < 2)
		return
	LAZYSET(activity_cooldowns, activity.type, world.time + GUARD_ACTIVITY_GIVE_UP_TIME)
	end_activity(cancel_ai = FALSE)

/// Ends what they are doing on routine
/mob/living/basic/outpost_prison_guard/proc/end_activity(cancel_ai = TRUE)
	if(!activity)
		return
	var/datum/outpost_guard_activity/old = activity
	activity = null
	last_activity_type = old.type
	old.finish()
	qdel(old)
	if(cancel_ai && !QDELETED(src))
		ai_controller?.CancelActions()

/// Starts `new_activity` in place of whatever they were doing on routine
/mob/living/basic/outpost_prison_guard/proc/start_activity(datum/outpost_guard_activity/new_activity)
	end_activity()
	activity = new_activity
	return new_activity

/mob/living/basic/outpost_prison_guard/proc/activity_on_cooldown(activity_type)
	return LAZYACCESS(activity_cooldowns, activity_type) > world.time

/// Picks their next routine activity by weight. Returns it, already set up, or null.
/mob/living/basic/outpost_prison_guard/proc/choose_activity()
	if(!prison || !on_duty())
		return null
	var/list/candidates = list()
	for(var/activity_type in GLOB.outpost_guard_leisure)
		if(activity_on_cooldown(activity_type))
			continue
		var/datum/outpost_guard_activity/candidate = new activity_type(src)
		var/candidate_weight = candidate.get_weight()
		if(activity_type == last_activity_type)
			candidate_weight *= 0.3
		if(candidate_weight > 0)
			candidates[candidate] = max(1, round(candidate_weight * 10))
		else
			qdel(candidate)
	var/datum/outpost_guard_activity/chosen
	while(length(candidates))
		var/datum/outpost_guard_activity/pick = pick_weight(candidates)
		candidates -= pick
		if(pick.setup())
			chosen = pick
			break
		qdel(pick)
	for(var/datum/outpost_guard_activity/unused as anything in candidates)
		qdel(unused)
	if(chosen)
		return start_activity(chosen)
	return null

/**
 * A two-guard exchange: they open with a line from the file's guard_conversations, and `partner`
 * answers a few seconds later. Returns TRUE if it started.
 */
/mob/living/basic/outpost_prison_guard/proc/start_guard_conversation(mob/living/basic/outpost_prison_guard/partner)
	if(!on_duty() || !partner?.on_duty())
		return FALSE
	var/list/conversations = outpost_guard_dialogue("guard_conversations")
	if(!length(conversations))
		return FALSE
	var/list/conversation = pick(conversations)
	var/opener = conversation["opener"]
	var/list/replies = conversation["replies"]
	if(!istext(opener) || !length(replies))
		return FALSE
	last_line = opener
	say(replacetext(opener, "{other}", partner.record?.surname || partner.name))
	addtimer(CALLBACK(partner, PROC_REF(reply_to_guard), pick(replies), WEAKREF(src)), rand(3, 5) SECONDS)
	prison?.note_speech()
	return TRUE

/// The second half of a guards' exchange
/mob/living/basic/outpost_prison_guard/proc/reply_to_guard(line, datum/weakref/opener_ref)
	var/mob/living/basic/outpost_prison_guard/opener = opener_ref?.resolve()
	if(!on_duty() || !opener || get_dist(src, opener) > 5 || !istext(line))
		return FALSE
	face_atom(opener)
	last_line = line
	say(replacetext(line, "{other}", opener.record?.surname || opener.name))
	return TRUE

// ===== AI =====

/datum/ai_controller/basic_controller/outpost_prison_guard
	blackboard = list()
	ai_traits = PASSIVE_AI_FLAGS
	ai_movement = /datum/ai_movement/jps
	// The routine plans everything, idle time included.
	idle_behavior = null
	// Stay awake while anyone is on the level.
	can_idle = FALSE
	// No finding targets: guards only ever strike through the dispatcher (outpost_prison_guards.dm),
	// so turrets never read them as hostile.
	planning_subtrees = list(/datum/ai_planning_subtree/outpost_prison_guard)

/// Walks to the response's goal, else the activity's, or ticks the activity once there
/datum/ai_planning_subtree/outpost_prison_guard

/datum/ai_planning_subtree/outpost_prison_guard/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/outpost_prison_guard/guard = controller.pawn
	if(!istype(guard) || guard.stat != CONSCIOUS || HAS_TRAIT(guard, TRAIT_IMMOBILIZED))
		return
	if(guard.phase == OUTPOST_GUARD_DISMISSED || guard.response)
		var/atom/goal = guard.walk_goal()
		if(goal)
			guard.queue_walk(controller, goal)
		return SUBTREE_RETURN_FINISH_PLANNING
	if(guard.phase != OUTPOST_GUARD_PRESENT)
		return
	var/datum/outpost_guard_activity/doing = guard.activity || guard.choose_activity()
	if(!doing)
		return
	var/atom/goal = guard.walk_goal()
	if(goal)
		guard.queue_walk(controller, goal)
		return SUBTREE_RETURN_FINISH_PLANNING
	if(doing.goal() || !doing.started)
		if(!doing.arrive())
			guard.end_activity(cancel_ai = FALSE)
			return
		goal = guard.walk_goal()
		if(goal)
			guard.queue_walk(controller, goal)
			return SUBTREE_RETURN_FINISH_PLANNING
	controller.queue_behavior(/datum/ai_behavior/outpost_prison_guard_activity)
	return SUBTREE_RETURN_FINISH_PLANNING

/// Queues the walk to `goal`: onto a tile, or up beside a mob
/mob/living/basic/outpost_prison_guard/proc/queue_walk(datum/ai_controller/controller, atom/goal)
	controller.set_blackboard_key(BB_OUTPOST_GUARD_GOAL, goal)
	controller.queue_behavior(isturf(goal) ? /datum/ai_behavior/outpost_prison_guard_travel : /datum/ai_behavior/outpost_prison_guard_travel/approach, BB_OUTPOST_GUARD_GOAL)

/// Walks onto a tile. Gives up the moment the guard's goal changes, so the plan catches up.
/datum/ai_behavior/outpost_prison_guard_travel
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM
	required_distance = 0
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/outpost_prison_guard_travel/setup(datum/ai_controller/controller, goal_key)
	. = ..()
	var/atom/goal = controller.blackboard[goal_key]
	if(QDELETED(goal))
		return FALSE
	set_movement_target(controller, goal)

/datum/ai_behavior/outpost_prison_guard_travel/perform(seconds_per_tick, datum/ai_controller/controller, goal_key)
	var/mob/living/basic/outpost_prison_guard/guard = controller.pawn
	var/atom/goal = controller.blackboard[goal_key]
	if(QDELETED(goal) || !istype(guard))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	if(guard.at_goal(goal))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	if(goal != guard.walk_goal())
		// The goal moved on (a new response, a new stop on the rounds): plan again.
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY

/datum/ai_behavior/outpost_prison_guard_travel/finish_action(datum/ai_controller/controller, succeeded, goal_key)
	var/atom/goal = controller.blackboard[goal_key]
	. = ..()
	controller.clear_blackboard_key(goal_key)
	if(!succeeded)
		var/mob/living/basic/outpost_prison_guard/guard = controller.pawn
		if(istype(guard))
			guard.walk_failed(goal)

/// Walks up beside a mob
/datum/ai_behavior/outpost_prison_guard_travel/approach
	required_distance = 1

/// Ticks the routine activity about once a second until it wants to move or is done
/datum/ai_behavior/outpost_prison_guard_activity
	action_cooldown = 1 SECONDS

/datum/ai_behavior/outpost_prison_guard_activity/setup(datum/ai_controller/controller)
	var/mob/living/basic/outpost_prison_guard/guard = controller.pawn
	return istype(guard) && !!guard.activity

/datum/ai_behavior/outpost_prison_guard_activity/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/basic/outpost_prison_guard/guard = controller.pawn
	var/datum/outpost_guard_activity/doing = guard.activity
	if(!doing || guard.response || !guard.on_duty())
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	switch(doing.tick(seconds_per_tick))
		if(GUARD_ACTIVITY_CONTINUE)
			return AI_BEHAVIOR_DELAY
		if(GUARD_ACTIVITY_DONE)
			guard.end_activity(cancel_ai = FALSE)
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

// ===== ACTIVITIES =====

/**
 * Something a guard does on routine. setup() picks where and sets the goal (a tile, or a mob to
 * stand beside); the guard walks there and arrive() runs, which starts the clock the first time;
 * tick() runs about once a second and may send them on by setting a new goal and returning
 * GUARD_ACTIVITY_MOVE; finish() tidies up.
 */
/datum/outpost_guard_activity
	/// Short text for the admin panel
	var/name = "on duty"
	/// What the warden's console calls it: "post", "rounds" or "routine"
	var/status = "routine"
	/// Whether it is picked by weight as routine
	var/leisure = FALSE
	var/weight = 10
	/// Weight multipliers by guard personality
	var/list/personality_weights
	/// How long it lasts once started (deciseconds)
	var/min_duration = 30 SECONDS
	var/max_duration = 90 SECONDS
	/// Whether rounds or the other guard's chat may take its place
	var/interruptible = TRUE
	var/mob/living/basic/outpost_prison_guard/guard
	/// Where they are headed: a tile, or a mob to stand beside; null once there
	var/datum/weakref/goal_ref
	var/started = FALSE
	var/ends_at = 0
	var/failed_moves = 0

/datum/outpost_guard_activity/New(mob/living/basic/outpost_prison_guard/doer)
	. = ..()
	guard = doer

/datum/outpost_guard_activity/Destroy()
	guard = null
	goal_ref = null
	return ..()

/datum/outpost_guard_activity/proc/goal()
	return goal_ref?.resolve()

/datum/outpost_guard_activity/proc/set_goal(atom/goal)
	goal_ref = goal ? WEAKREF(goal) : null

/// The tile they are headed for, if the goal is a tile
/datum/outpost_guard_activity/proc/goal_turf()
	var/atom/goal = goal()
	return isturf(goal) ? goal : null

/// How much they feel like it now; 0 means not at all
/datum/outpost_guard_activity/proc/get_weight()
	var/scale = personality_weights ? (personality_weights[guard.personality] || 1) : 1
	return weight * scale

/// Finds where to go. FALSE when it can't be done now.
/datum/outpost_guard_activity/proc/setup()
	return TRUE

/// Reached the goal. FALSE abandons the activity.
/datum/outpost_guard_activity/proc/arrive()
	set_goal(null)
	if(!started)
		begin()
	return TRUE

/// Starts the clock
/datum/outpost_guard_activity/proc/begin()
	started = TRUE
	ends_at = world.time + rand(min_duration, max_duration)

/// About once a second while in place
/datum/outpost_guard_activity/proc/tick(seconds)
	return world.time >= ends_at ? GUARD_ACTIVITY_DONE : GUARD_ACTIVITY_CONTINUE

/datum/outpost_guard_activity/proc/finish()
	return

/// The other guard of the wing on the payroll, if any is here
/datum/outpost_guard_activity/proc/other_guard()
	for(var/mob/living/basic/outpost_prison_guard/other in guard.prison?.guard_mobs)
		if(other != guard && other.on_duty())
			return other
	return null

// ----- post -----

/// Standing post in the office beside the staff door, facing the yard
/datum/outpost_guard_activity/post
	name = "on post"
	status = "post"
	leisure = TRUE
	weight = 10
	personality_weights = list("by_the_book" = 1.6, "hard_nosed" = 1.5, "tired" = 1.2, "easygoing" = 0.7)
	min_duration = 2 MINUTES
	max_duration = 5 MINUTES
	/// The staff door they watch
	var/turf/door

/datum/outpost_guard_activity/post/setup()
	var/datum/outpost_prison/prison = guard.prison
	for(var/turf/spot as anything in prison.guard_hold_spots())
		if(prison.guard_spot_taken(spot, guard))
			continue
		for(var/turf/yard_door as anything in prison.guard_yard_doors())
			if(get_dist(spot, yard_door) <= 1)
				door = yard_door
				break
		set_goal(spot)
		return TRUE
	return FALSE

/datum/outpost_guard_activity/post/begin()
	. = ..()
	if(door)
		guard.face_atom(door)

/datum/outpost_guard_activity/post/tick(seconds)
	if(door)
		guard.face_atom(door)
	if(prob(3))
		guard.idle_say("post")
	return ..()

/datum/outpost_guard_activity/post/Destroy()
	door = null
	return ..()

// ----- rounds -----

/// Rounds of the cell block: through the staff door, a pause at each cell door, "Count's clear"
/datum/outpost_guard_activity/rounds
	name = "on rounds"
	status = "rounds"
	weight = 0
	interruptible = FALSE
	/// The yard tiles in front of each cell door, in cell order, and the doors they face
	var/list/stops = list()
	var/list/stop_doors = list()
	var/stop_index = 0
	var/pause_left = 0

/datum/outpost_guard_activity/rounds/setup()
	var/datum/outpost_prison/prison = guard.prison
	for(var/datum/outpost_prison_cell/cell as anything in prison.cells)
		var/turf/door_turf = cell.door_turf
		if(!door_turf)
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/front = get_step(door_turf, direction)
			if(front && prison.guard_yard_tile(front))
				stops += front
				stop_doors += door_turf
				break
	if(!length(stops))
		return FALSE
	stop_index = 1
	set_goal(stops[1])
	return TRUE

/datum/outpost_guard_activity/rounds/begin()
	started = TRUE
	ends_at = INFINITY
	if(guard.say_guard("rounds_start"))
		guard.prison?.note_speech()

/datum/outpost_guard_activity/rounds/arrive()
	. = ..()
	pause_left = rand(2, 3)
	var/turf/door = stop_doors[stop_index]
	if(door)
		guard.face_atom(door)

/datum/outpost_guard_activity/rounds/tick(seconds)
	if(pause_left > 0)
		pause_left -= seconds
		return GUARD_ACTIVITY_CONTINUE
	if(stop_index < length(stops))
		stop_index++
		set_goal(stops[stop_index])
		return GUARD_ACTIVITY_MOVE
	if(guard.say_guard("rounds_clear"))
		guard.prison?.note_speech()
	return GUARD_ACTIVITY_DONE

/datum/outpost_guard_activity/rounds/Destroy()
	stops = null
	stop_doors = null
	return ..()

// ----- the yard -----

/// Watching the yard from its edge, with a word now and then about the game
/datum/outpost_guard_activity/watch_yard
	name = "watching the yard"
	leisure = TRUE
	weight = 8
	personality_weights = list("easygoing" = 1.5, "soft_hearted" = 1.2, "tired" = 0.8, "hard_nosed" = 1.1)
	min_duration = 40 SECONDS
	max_duration = 90 SECONDS
	var/datum/weakref/hoop_ref

/datum/outpost_guard_activity/watch_yard/setup()
	var/datum/outpost_prison/prison = guard.prison
	var/obj/structure/hoop/hoop
	for(var/obj/structure/hoop/found in prison.fixtures_of("hoop"))
		if(!QDELETED(found))
			hoop = found
			break
	var/list/edges = list()
	var/list/others = list()
	for(var/turf/tile as anything in prison.cell_block)
		if(!prison.guard_yard_tile(tile) || prison.guard_spot_taken(tile, guard))
			continue
		if(hoop)
			var/distance = get_dist(tile, hoop)
			if(distance < 3 || distance > 5)
				continue
		var/on_edge = FALSE
		for(var/direction in GLOB.cardinals)
			var/turf/beside = get_step(tile, direction)
			if(!beside || isclosedturf(beside) || !prison.cell_block[beside])
				on_edge = TRUE
				break
		if(on_edge)
			edges += tile
		else
			others += tile
	var/list/options = length(edges) ? edges : others
	if(!length(options))
		return FALSE
	hoop_ref = hoop ? WEAKREF(hoop) : null
	set_goal(pick(options))
	return TRUE

/datum/outpost_guard_activity/watch_yard/tick(seconds)
	var/obj/structure/hoop/hoop = hoop_ref?.resolve()
	var/mob/living/basic/outpost_prisoner/player
	for(var/mob/living/basic/outpost_prisoner/prisoner in guard.prison?.prisoners)
		if(istype(prisoner.activity, /datum/prisoner_activity/basketball) && prisoner.stat == CONSCIOUS)
			player = prisoner
			break
	var/atom/look_at = player || hoop
	if(look_at)
		guard.face_atom(look_at)
	if(player && prob(8))
		guard.idle_say("yard_comment")
	return ..()

// ----- a drink -----

/// A drink at the yard's water cooler
/datum/outpost_guard_activity/coffee
	name = "getting a drink"
	leisure = TRUE
	weight = 5
	personality_weights = list("tired" = 2, "easygoing" = 1.3, "hard_nosed" = 0.7, "by_the_book" = 0.8)
	min_duration = 20 SECONDS
	max_duration = 40 SECONDS
	var/datum/weakref/cooler_ref
	var/drank = FALSE

/datum/outpost_guard_activity/coffee/setup()
	var/datum/outpost_prison/prison = guard.prison
	for(var/obj/structure/reagent_dispensers/water_cooler/cooler in prison.fixtures_of("cooler"))
		if(QDELETED(cooler))
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/stand = get_step(cooler, direction)
			if(!stand || !(prison.guard_yard_tile(stand) || prison.guard_office_tile(stand)) || prison.guard_spot_taken(stand, guard))
				continue
			cooler_ref = WEAKREF(cooler)
			set_goal(stand)
			return TRUE
	return FALSE

/datum/outpost_guard_activity/coffee/tick(seconds)
	var/obj/structure/reagent_dispensers/water_cooler/cooler = cooler_ref?.resolve()
	if(!cooler)
		return GUARD_ACTIVITY_DONE
	guard.face_atom(cooler)
	if(!drank)
		drank = TRUE
		playsound(cooler, 'sound/items/drink.ogg', 25, TRUE)
		if(prob(40))
			guard.idle_say("coffee")
	return ..()

// ----- a chat -----

/// Walks over to the other guard and trades a few words
/datum/outpost_guard_activity/chat
	name = "chatting"
	leisure = TRUE
	weight = 6
	personality_weights = list("easygoing" = 1.6, "soft_hearted" = 1.2, "by_the_book" = 0.6, "hard_nosed" = 0.6)
	min_duration = 30 SECONDS
	max_duration = 60 SECONDS
	var/datum/weakref/partner_ref
	/// When the next exchange starts
	var/next_exchange = 0

/datum/outpost_guard_activity/chat/setup()
	var/mob/living/basic/outpost_prison_guard/other = other_guard()
	if(!can_join(other))
		return FALSE
	partner_ref = WEAKREF(other)
	set_goal(other)
	return TRUE

/// Whether the other guard is free to talk
/datum/outpost_guard_activity/chat/proc/can_join(mob/living/basic/outpost_prison_guard/other)
	if(!other?.on_duty() || !other.ai_running() || other.response)
		return FALSE
	return !other.activity || (other.activity.interruptible && !istype(other.activity, /datum/outpost_guard_activity/chat))

/datum/outpost_guard_activity/chat/arrive()
	var/mob/living/basic/outpost_prison_guard/partner = partner_ref?.resolve()
	if(!partner || !guard.Adjacent(partner) || !can_join(partner))
		return FALSE
	. = ..()
	partner.start_activity(new /datum/outpost_guard_activity/chat/listen(partner, guard))
	guard.face_atom(partner)
	partner.face_atom(guard)
	next_exchange = world.time + 1 SECONDS

/datum/outpost_guard_activity/chat/tick(seconds)
	var/mob/living/basic/outpost_prison_guard/partner = partner_ref?.resolve()
	var/datum/outpost_guard_activity/chat/listen/listening = partner?.activity
	if(!partner || !guard.Adjacent(partner) || !istype(listening) || listening.partner_ref?.resolve() != guard)
		return GUARD_ACTIVITY_DONE
	guard.face_atom(partner)
	if(world.time >= next_exchange)
		next_exchange = world.time + rand(15, 25) SECONDS
		if(guard.prison?.wing_can_speak())
			guard.start_guard_conversation(partner)
	return ..()

/datum/outpost_guard_activity/chat/finish()
	var/mob/living/basic/outpost_prison_guard/partner = partner_ref?.resolve()
	var/datum/outpost_guard_activity/chat/listen/listening = partner?.activity
	if(istype(listening) && listening.partner_ref?.resolve() == guard)
		partner.end_activity()

/// The other half of a chat: stays put and faces whoever came over
/datum/outpost_guard_activity/chat/listen
	name = "chatting"
	leisure = FALSE
	weight = 0

/datum/outpost_guard_activity/chat/listen/New(mob/living/basic/outpost_prison_guard/doer, mob/living/basic/outpost_prison_guard/talker)
	. = ..(doer)
	partner_ref = WEAKREF(talker)
	started = TRUE
	ends_at = INFINITY

/datum/outpost_guard_activity/chat/listen/setup()
	return TRUE

/datum/outpost_guard_activity/chat/listen/arrive()
	set_goal(null)
	return TRUE

/datum/outpost_guard_activity/chat/listen/tick(seconds)
	var/mob/living/basic/outpost_prison_guard/talker = partner_ref?.resolve()
	var/datum/outpost_guard_activity/chat/talking = talker?.activity
	if(!talker || !guard.Adjacent(talker) || !istype(talking) || talking.partner_ref?.resolve() != guard)
		return GUARD_ACTIVITY_DONE
	guard.face_atom(talker)
	return GUARD_ACTIVITY_CONTINUE

/datum/outpost_guard_activity/chat/listen/finish()
	return

// ----- checking on a prisoner -----

/// Walks up to a prisoner with a need showing and tells them it's in hand. It changes nothing.
/datum/outpost_guard_activity/check_on
	name = "checking on a prisoner"
	leisure = TRUE
	weight = 4
	personality_weights = list("soft_hearted" = 2.5, "by_the_book" = 1, "easygoing" = 0.8, "hard_nosed" = 0.4, "tired" = 0.5)
	min_duration = 5 SECONDS
	max_duration = 10 SECONDS
	var/datum/weakref/prisoner_ref
	/// "hungry", "dirty" or "hurt"
	var/need

/datum/outpost_guard_activity/check_on/setup()
	var/datum/outpost_prison/prison = guard.prison
	var/list/options = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prison.prisoners)
		if(prisoner.phase != PRISONER_PRESENT || !prisoner.routine_allowed() || prisoner.activity?.sleeping || !prison.in_cell_block(prisoner))
			continue
		if(prisoner.guard_noticed_at && world.time - prisoner.guard_noticed_at < OUTPOST_GUARD_CHECK_ON_GAP)
			continue
		if(!(prisoner.bubble in list("hungry", "dirty", "hurt")))
			continue
		options += prisoner
	if(!length(options))
		return FALSE
	var/mob/living/basic/outpost_prisoner/chosen = pick(options)
	prisoner_ref = WEAKREF(chosen)
	need = chosen.bubble
	chosen.guard_noticed_at = world.time
	set_goal(chosen)
	return TRUE

/datum/outpost_guard_activity/check_on/begin()
	. = ..()
	var/mob/living/basic/outpost_prisoner/prisoner = prisoner_ref?.resolve()
	if(!prisoner)
		return
	guard.face_atom(prisoner)
	var/said = guard.say_guard("check_on_[need]") || guard.say_guard("check_on")
	if(said)
		guard.prison?.note_speech()

/datum/outpost_guard_activity/check_on/tick(seconds)
	var/mob/living/basic/outpost_prisoner/prisoner = prisoner_ref?.resolve()
	if(!prisoner || !guard.Adjacent(prisoner))
		return GUARD_ACTIVITY_DONE
	guard.face_atom(prisoner)
	return ..()

#undef GUARD_ACTIVITY_CONTINUE
#undef GUARD_ACTIVITY_DONE
#undef GUARD_ACTIVITY_MOVE
#undef GUARD_ACTIVITY_GIVE_UP_TIME
#undef BB_OUTPOST_GUARD_GOAL
