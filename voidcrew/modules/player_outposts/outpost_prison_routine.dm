/**
 * # Prisoner routine
 *
 * Prisoners live by activities. Each one picks something to do by its needs, its personality and
 * what is free, walks there with JPS pathing, does it for 30 to 120 seconds and picks again:
 * resting or sleeping on their bed, sitting on it, the cell toilet and sink, carrying a meal from
 * the hatch to a mess table (and the wrapper to the bin after), shooting hoops, reading in the
 * chair by the bookcase, the water cooler, chatting with another prisoner, pacing and working out,
 * looking out of a window, tidying up litter when in a good mood, waiting at the hatch when
 * hungry or dirty, and going over to anyone holding dressings when hurt. Bolted into a cell, they
 * make do with what is inside it and call out through the door.
 *
 * The AI controller only plans walks and ticks; all the logic sits on the activity datums, so
 * tests can drive an activity by hand while the AI sleeps. While nobody is on the level the AI is
 * off and prisoners stay put; the prison then lets them help themselves to food and uniforms
 * within reach (fend_for_self()).
 */

/// What an activity's tick() wants next
#define ACTIVITY_CONTINUE 0
#define ACTIVITY_DONE 1
/// It set a new `spot` to walk to
#define ACTIVITY_MOVE 2

/// Seconds an activity type is skipped after a prisoner gives up on it
#define ACTIVITY_GIVE_UP_TIME (60 SECONDS)

/// Leisure activities, picked by weight when no need or duty comes first: every activity type with `leisure` set
GLOBAL_LIST_INIT(outpost_prisoner_leisure, outpost_prisoner_leisure_types())

/proc/outpost_prisoner_leisure_types()
	var/list/types = list()
	for(var/datum/prisoner_activity/activity_type as anything in subtypesof(/datum/prisoner_activity))
		if(initial(activity_type.leisure))
			types += activity_type
	return types

// ===== PRISONER SIDE =====

/// Whether their routine may run now: not while down, cuffed, pulled, in trouble or held by the talk menu (outpost_prison_warden_tools.dm)
/mob/living/basic/outpost_prisoner/proc/routine_allowed()
	return prison && stat == CONSCIOUS && phase == PRISONER_PRESENT && !can_be_dragged() && !pulledby && !in_trouble() && !held_by_talk_menu()

/// Ends what they are doing, putting things down and getting up
/mob/living/basic/outpost_prisoner/proc/end_activity(cancel_ai = TRUE)
	if(!activity)
		return
	var/datum/prisoner_activity/old = activity
	activity = null
	reaching_ref = null
	last_activity_type = old.type
	old.finish()
	qdel(old)
	if(cancel_ai)
		ai_controller?.CancelActions()

/// Starts `new_activity` in place of whatever they were doing
/mob/living/basic/outpost_prisoner/proc/start_activity(datum/prisoner_activity/new_activity)
	end_activity()
	activity = new_activity
	return new_activity

/// A walk failed: try once more, then give up on it for a while
/mob/living/basic/outpost_prisoner/proc/activity_move_failed()
	if(!activity)
		return
	if(++activity.failed_moves < 2)
		return
	LAZYSET(activity_cooldowns, activity.type, world.time + ACTIVITY_GIVE_UP_TIME)
	end_activity(cancel_ai = FALSE)

/// Whether they gave up on this kind of activity recently
/mob/living/basic/outpost_prisoner/proc/activity_on_cooldown(activity_type)
	return LAZYACCESS(activity_cooldowns, activity_type) > world.time

/**
 * Picks their next activity: duties and needs first (heading home at release, eating, changing,
 * calling for the hatch), then leisure by weight. Returns the activity, already set up.
 */
/mob/living/basic/outpost_prisoner/proc/choose_activity()
	if(!prison)
		return null
	if(!walkable)
		prison.refresh_prisoner_reach(src)
	var/list/duties = list()
	// Unhappy, and a serving hatch left open on both sides: that comes before anything.
	if(mood < PRISONER_CLIMB_MOOD && prison.trouble_enabled && prison.open_hatch_for(src))
		duties += /datum/prisoner_activity/climb_hatch
	if(sentence_left <= OUTPOST_PRISON_RELEASE_WALK)
		duties += /datum/prisoner_activity/go_home
	if(wants_food())
		duties += /datum/prisoner_activity/eat
	if(wants_clean_uniform())
		duties += /datum/prisoner_activity/change
	if(health_factor() < PRISONER_INJURED_BELOW && COOLDOWN_FINISHED(src, sick_call_cooldown))
		duties += /datum/prisoner_activity/sick_call
	if((hunger < PRISONER_HUNGER_HUNGRY || uniform_grime >= PRISONER_GRIME_DIRTY) && prob(60))
		duties += /datum/prisoner_activity/hatch_wait
	for(var/duty_type in duties)
		if(activity_on_cooldown(duty_type))
			continue
		var/datum/prisoner_activity/duty = new duty_type(src)
		if(duty.setup())
			return start_activity(duty)
		qdel(duty)

	var/list/candidates = list()
	for(var/leisure_type in GLOB.outpost_prisoner_leisure)
		if(activity_on_cooldown(leisure_type))
			continue
		var/datum/prisoner_activity/candidate = new leisure_type(src)
		var/candidate_weight = candidate.get_weight()
		if(leisure_type == last_activity_type)
			candidate_weight *= 0.3
		if(candidate_weight > 0)
			candidates[candidate] = max(1, round(candidate_weight * 10))
		else
			qdel(candidate)
	var/datum/prisoner_activity/chosen
	while(length(candidates))
		var/datum/prisoner_activity/pick = pick_weight(candidates)
		candidates -= pick
		if(pick.setup())
			chosen = pick
			break
		qdel(pick)
	for(var/datum/prisoner_activity/unused as anything in candidates)
		qdel(unused)
	if(chosen)
		return start_activity(chosen)
	return null

/// The nearest free tile beside `target` they can stand on, or its own tile when walkable
/mob/living/basic/outpost_prisoner/proc/approach_turf(atom/target)
	var/turf/target_turf = get_turf(target)
	if(!target_turf || !walkable)
		return null
	if(walkable[target_turf] && (target_turf == loc || !tile_taken(target_turf)))
		return target_turf
	var/turf/best
	var/best_distance = INFINITY
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(target_turf, direction)
		if(!beside || !walkable[beside] || (beside != loc && tile_taken(beside)))
			continue
		var/distance = get_dist(src, beside)
		if(distance < best_distance)
			best = beside
			best_distance = distance
	return best

/// Somewhere to hang about: the yard, or their own cell, not someone else's
/mob/living/basic/outpost_prisoner/proc/may_loiter(turf/tile)
	var/datum/outpost_prison_cell/holder = prison?.cell_at(tile)
	return !holder || holder == cell || holder == prison.cell_at(get_turf(src))

/// Whether someone else stands on this tile
/mob/living/basic/outpost_prisoner/proc/tile_taken(turf/tile)
	for(var/mob/living/other in tile)
		if(other != src && other.density)
			return TRUE
	return FALSE

/// Their bed if they can get to it, else any free bed they can
/mob/living/basic/outpost_prisoner/proc/find_bed()
	var/obj/structure/bed/own = cell?.bed()
	if(own && walkable?[get_turf(own)] && !prison.claimed_by_other(own, src))
		return own
	for(var/obj/structure/bed/bed as anything in prison.fixtures_of("bed"))
		if(walkable?[get_turf(bed)] && !prison.claimed_by_other(bed, src) && !(prison.bed_owner(bed) && prison.bed_owner(bed) != src))
			return bed
	return null

/// A fixture of `category` they can walk up to and nobody else is using, own cell's first, never in another's cell
/mob/living/basic/outpost_prisoner/proc/find_fixture(category, stand_on = FALSE)
	var/list/options = list()
	for(var/atom/fixture as anything in prison.fixtures_of(category))
		if(QDELETED(fixture) || prison.claimed_by_other(fixture, src))
			continue
		var/turf/stand = stand_on ? get_turf(fixture) : approach_turf(fixture)
		if(!stand || !walkable?[stand] || !may_loiter(stand))
			continue
		options += fixture
	if(!length(options))
		return null
	for(var/atom/fixture as anything in options)
		if(cell?.contains(fixture))
			return fixture
	return pick(options)

/// Whether `person` is a member of the wing awake in the cell block, close by, holding dressings
/mob/living/basic/outpost_prisoner/proc/is_medic(mob/living/person)
	if(!istype(person) || QDELETED(person) || person.stat != CONSCIOUS || is_outpost_prisoner(person))
		return FALSE
	if(get_dist(src, person) > PRISONER_SICK_CALL_RANGE || !prison?.in_cell_block(person) || !prison.is_member(person))
		return FALSE
	return !!person.is_holding_item_of_type(/obj/item/stack/medical)

/// The nearest medic they can see and walk up to
/mob/living/basic/outpost_prisoner/proc/find_medic()
	var/mob/living/best
	var/best_distance = INFINITY
	for(var/mob/living/person in view(PRISONER_SICK_CALL_RANGE, src))
		if(!is_medic(person) || !approach_turf(person))
			continue
		var/distance = get_dist(src, person)
		if(distance < best_distance)
			best = person
			best_distance = distance
	return best

/**
 * Hurt, with a medic in sight: drops whatever idle thing they were doing and goes over. Called
 * every few seconds by the prison while anyone is on the level. Returns TRUE if they went.
 */
/mob/living/basic/outpost_prisoner/proc/check_sick_call()
	if(!ai_running())
		return FALSE
	return start_sick_call()

/// Starts a sick call if they are hurt, free and someone holding dressings is near. Returns TRUE if it started.
/mob/living/basic/outpost_prisoner/proc/start_sick_call()
	if(!routine_allowed() || health_factor() >= PRISONER_INJURED_BELOW || !COOLDOWN_FINISHED(src, sick_call_cooldown))
		return FALSE
	// A need, a duty or sleep comes first; anything idle can wait.
	if(activity && (!activity.leisure || activity.sleeping || !activity.interruptible))
		return FALSE
	var/datum/prisoner_activity/sick_call/asking = new(src)
	if(!asking.setup())
		qdel(asking)
		return FALSE
	start_activity(asking)
	return TRUE

/**
 * A ball thrown at them: caught by anyone in a game, and by an idle prisoner when staff throw it,
 * who then starts shooting hoops. Returns TRUE if they caught it.
 */
/mob/living/basic/outpost_prisoner/proc/try_catch_ball(atom/movable/thrown_thing, datum/thrownthing/throwing)
	var/obj/item/toy/basketball/ball = thrown_thing
	if(!istype(ball) || held_item || !routine_allowed() || activity?.sleeping)
		return FALSE
	var/mob/thrower = throwing?.get_thrower()
	if(thrower == src)
		return FALSE
	var/playing = istype(activity, /datum/prisoner_activity/basketball)
	if(!playing && (is_outpost_prisoner(thrower) || (activity && (!activity.leisure || !activity.interruptible))))
		return FALSE
	if(!take_item(ball))
		return FALSE
	visible_message(span_notice("[src] catches [ball]."))
	if(!playing)
		var/datum/prisoner_activity/basketball/game = new(src)
		if(game.setup())
			start_activity(game)
		else
			qdel(game)
	return TRUE

/mob/living/basic/outpost_prisoner/hitby(atom/movable/AM, skipcatch, hitpush = TRUE, blocked = FALSE, datum/thrownthing/throwingdatum)
	if(try_catch_ball(AM, throwingdatum))
		return TRUE
	return ..()

// ===== AI =====

/datum/ai_controller/basic_controller/outpost_prisoner
	blackboard = list()
	ai_traits = PASSIVE_AI_FLAGS
	ai_movement = /datum/ai_movement/jps
	// The routine plans everything, idle time included.
	idle_behavior = null
	// Stay awake while anyone is on the level.
	can_idle = FALSE
	planning_subtrees = list(
		// Cuffed, nothing at all (outpost_prison_capture.dm).
		/datum/ai_planning_subtree/outpost_prisoner_cuffed,
		// Threats, fights and riots come first (outpost_prison_trouble.dm).
		/datum/ai_planning_subtree/outpost_prisoner_trouble,
		/datum/ai_planning_subtree/outpost_prisoner_routine,
	)

/// Walks to the current activity's spot, or ticks it once there
/datum/ai_planning_subtree/outpost_prisoner_routine

/datum/ai_planning_subtree/outpost_prisoner_routine/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/outpost_prisoner/prisoner = controller.pawn
	if(!istype(prisoner) || !prisoner.routine_allowed())
		return
	var/datum/prisoner_activity/activity = prisoner.activity || prisoner.choose_activity()
	if(!activity)
		return
	if(activity.spot && prisoner.loc != activity.spot)
		controller.queue_behavior(/datum/ai_behavior/outpost_prisoner_travel)
		return SUBTREE_RETURN_FINISH_PLANNING
	if(activity.spot || !activity.started)
		if(!activity.arrive())
			prisoner.end_activity(cancel_ai = FALSE)
			return
		if(activity.spot && prisoner.loc != activity.spot)
			controller.queue_behavior(/datum/ai_behavior/outpost_prisoner_travel)
			return SUBTREE_RETURN_FINISH_PLANNING
	controller.queue_behavior(/datum/ai_behavior/outpost_prisoner_activity)
	return SUBTREE_RETURN_FINISH_PLANNING

/// Walks onto the activity's spot
/datum/ai_behavior/outpost_prisoner_travel
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT
	required_distance = 0
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/outpost_prisoner_travel/setup(datum/ai_controller/controller)
	var/mob/living/basic/outpost_prisoner/prisoner = controller.pawn
	var/turf/spot = prisoner.activity?.spot
	if(!spot)
		return FALSE
	prisoner.stand_up()
	set_movement_target(controller, spot)
	return TRUE

/datum/ai_behavior/outpost_prisoner_travel/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/basic/outpost_prisoner/prisoner = controller.pawn
	var/datum/prisoner_activity/activity = prisoner.activity
	if(!activity || prisoner.loc != activity.spot)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	if(!activity.arrive())
		prisoner.end_activity(cancel_ai = FALSE)
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/outpost_prisoner_travel/finish_action(datum/ai_controller/controller, succeeded)
	. = ..()
	if(!succeeded)
		var/mob/living/basic/outpost_prisoner/prisoner = controller.pawn
		prisoner?.activity_move_failed()

/// Ticks the activity about once a second until it wants to move or is done
/datum/ai_behavior/outpost_prisoner_activity
	action_cooldown = 1 SECONDS

/datum/ai_behavior/outpost_prisoner_activity/setup(datum/ai_controller/controller)
	var/mob/living/basic/outpost_prisoner/prisoner = controller.pawn
	return !!prisoner.activity

/datum/ai_behavior/outpost_prisoner_activity/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/basic/outpost_prisoner/prisoner = controller.pawn
	var/datum/prisoner_activity/activity = prisoner.activity
	if(!activity || !prisoner.routine_allowed())
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	switch(activity.tick(seconds_per_tick))
		if(ACTIVITY_CONTINUE)
			return AI_BEHAVIOR_DELAY
		if(ACTIVITY_DONE)
			prisoner.end_activity(cancel_ai = FALSE)
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

// ===== ACTIVITIES =====

/**
 * Something a prisoner does for a while. setup() picks what to use and sets `spot`; the prisoner
 * walks there and arrive() runs, which starts the clock the first time; tick() runs about once a
 * second and may send them somewhere else by setting `spot` and returning ACTIVITY_MOVE;
 * finish() puts everything back.
 */
/datum/prisoner_activity
	/// Short text for the admin panel
	var/name = "hanging around"
	/// Dialogue context for lines said while doing it, if any
	var/context
	/// Whether it is picked as leisure, by weight, when no need or duty comes first
	var/leisure = FALSE
	/// Weight when picking leisure, before personality
	var/weight = 10
	/// Weight multipliers by personality
	var/list/personality_weights
	/// How long it lasts once started (deciseconds)
	var/min_duration = 30 SECONDS
	var/max_duration = 120 SECONDS
	/// Whether another prisoner may pull them into a chat
	var/interruptible = TRUE
	/// Whether doing it lifts their mood by PRISONER_MOOD_ACTIVITY a minute
	var/mood_activity = FALSE
	/// Asleep: no chatting, only sleep talk
	var/sleeping = FALSE
	var/mob/living/basic/outpost_prisoner/prisoner
	/// Where they are headed; null once there
	var/turf/spot
	/// When it ends, once started
	var/ends_at = 0
	var/started = FALSE
	/// Walks that failed so far
	var/failed_moves = 0
	/// REF() keys of what this activity has claimed in the prison
	var/list/claimed

/datum/prisoner_activity/New(mob/living/basic/outpost_prisoner/doer)
	. = ..()
	prisoner = doer

/datum/prisoner_activity/Destroy()
	release_claims()
	prisoner = null
	spot = null
	return ..()

/// How much they feel like it now; 0 means not at all
/datum/prisoner_activity/proc/get_weight()
	var/scale = personality_weights ? (personality_weights[prisoner.personality] || 1) : 1
	return weight * scale

/// Finds what to use and where to go. FALSE when it can't be done now.
/datum/prisoner_activity/proc/setup()
	return TRUE

/// Reached `spot`. FALSE abandons the activity.
/datum/prisoner_activity/proc/arrive()
	spot = null
	if(!started)
		begin()
	return TRUE

/// Starts the clock
/datum/prisoner_activity/proc/begin()
	started = TRUE
	ends_at = world.time + rand(min_duration, max_duration)

/// About once a second while in place
/datum/prisoner_activity/proc/tick(seconds)
	return world.time >= ends_at ? ACTIVITY_DONE : ACTIVITY_CONTINUE

/// Gets up and lets go of everything
/datum/prisoner_activity/proc/finish()
	prisoner?.stand_up()
	release_claims()

/// Who they are talking to, if this is a chat
/datum/prisoner_activity/proc/chat_partner()
	return null

/// Reserves `thing` so nobody else uses it. FALSE if someone else has it.
/datum/prisoner_activity/proc/claim(atom/thing)
	if(!thing || !prisoner?.prison?.claim(thing, prisoner))
		return FALSE
	LAZYOR(claimed, REF(thing))
	return TRUE

/// Lets go of one thing it claimed
/datum/prisoner_activity/proc/unclaim(atom/thing)
	var/key = REF(thing)
	var/datum/outpost_prison/prison = prisoner?.prison
	if(prison?.claims[key] == prisoner)
		prison.claims -= key
	LAZYREMOVE(claimed, key)

/datum/prisoner_activity/proc/release_claims()
	var/datum/outpost_prison/prison = prisoner?.prison
	if(prison)
		for(var/key in claimed)
			if(prison.claims[key] == prisoner)
				prison.claims -= key
	claimed = null

// ----- beds -----

/// Lying on their bed, awake
/datum/prisoner_activity/rest
	name = "resting"
	leisure = TRUE
	context = "resting"
	weight = 10
	personality_weights = list("grumpy" = 1.5, "quiet" = 1.5, "chatty" = 0.6, "cheerful" = 0.8)
	min_duration = 30 SECONDS
	max_duration = 90 SECONDS
	var/datum/weakref/bed_ref

/datum/prisoner_activity/rest/get_weight()
	. = ..()
	if(prisoner.locked_in_seconds)
		. *= 2

/datum/prisoner_activity/rest/setup()
	var/obj/structure/bed/bed = prisoner.find_bed()
	if(!bed || !claim(bed))
		return FALSE
	bed_ref = WEAKREF(bed)
	spot = get_turf(bed)
	return TRUE

/datum/prisoner_activity/rest/begin()
	. = ..()
	var/obj/structure/bed/bed = bed_ref?.resolve()
	if(bed && prisoner.loc == bed.loc)
		bed.buckle_mob(prisoner, force = TRUE)

/datum/prisoner_activity/rest/tick(seconds)
	var/obj/structure/bed/bed = bed_ref?.resolve()
	if(!bed || prisoner.buckled != bed)
		return ACTIVITY_DONE
	return ..()

/// Asleep in their bed
/datum/prisoner_activity/rest/sleep
	name = "sleeping"
	context = "sleeping"
	weight = 5
	personality_weights = list("quiet" = 1.4, "grumpy" = 1.2, "chatty" = 0.7)
	min_duration = 60 SECONDS
	max_duration = 150 SECONDS
	interruptible = FALSE
	sleeping = TRUE

/**
 * Sitting in their cell for a bit: in its chair, or with the chair taken, gone or out of reach,
 * lying on a bed awake (see sit_in_cell())
 */
/datum/prisoner_activity/sit_cell
	name = "sitting in their cell"
	leisure = TRUE
	context = "idle"
	weight = 6
	min_duration = 20 SECONDS
	max_duration = 60 SECONDS
	var/datum/weakref/seat_ref

/datum/prisoner_activity/sit_cell/setup()
	var/obj/structure/seat = prisoner.home_seat() || prisoner.find_bed()
	if(!seat || !claim(seat))
		return FALSE
	seat_ref = WEAKREF(seat)
	spot = get_turf(seat)
	if(istype(seat, /obj/structure/bed))
		name = "lying on their bed"
	return TRUE

/datum/prisoner_activity/sit_cell/begin()
	. = ..()
	var/obj/machinery/door/door = prisoner.cell?.door()
	prisoner.sit_in_cell(door ? get_cardinal_dir(prisoner, door) : SOUTH)

/datum/prisoner_activity/sit_cell/tick(seconds)
	var/obj/structure/seat = seat_ref?.resolve()
	if(!seat || prisoner.loc != seat.loc)
		return ACTIVITY_DONE
	return ..()

// ----- the cell -----

/datum/prisoner_activity/toilet
	name = "using the toilet"
	leisure = TRUE
	weight = 3
	min_duration = 10 SECONDS
	max_duration = 25 SECONDS
	interruptible = FALSE
	var/datum/weakref/toilet_ref

/datum/prisoner_activity/toilet/setup()
	var/obj/structure/toilet/toilet = prisoner.find_fixture("toilet", stand_on = TRUE)
	if(!toilet || !claim(toilet))
		return FALSE
	toilet_ref = WEAKREF(toilet)
	spot = get_turf(toilet)
	return TRUE

/datum/prisoner_activity/toilet/begin()
	. = ..()
	var/obj/structure/toilet/toilet = toilet_ref?.resolve()
	if(toilet)
		prisoner.sit_on(toilet, toilet.dir)

/datum/prisoner_activity/toilet/finish()
	var/obj/structure/toilet/toilet = toilet_ref?.resolve()
	if(started && toilet)
		playsound(toilet, 'sound/machines/toilet_flush.ogg', 30, TRUE)
	return ..()

/datum/prisoner_activity/sink
	name = "washing up"
	leisure = TRUE
	weight = 3
	min_duration = 8 SECONDS
	max_duration = 15 SECONDS
	var/datum/weakref/sink_ref

/datum/prisoner_activity/sink/setup()
	var/obj/structure/sink/sink = prisoner.find_fixture("sink", stand_on = TRUE)
	if(!sink || !claim(sink))
		return FALSE
	sink_ref = WEAKREF(sink)
	spot = get_turf(sink)
	return TRUE

/datum/prisoner_activity/sink/begin()
	. = ..()
	var/obj/structure/sink/sink = sink_ref?.resolve()
	if(sink)
		// A wall sink hangs on the far side of its tile from where it faces.
		prisoner.setDir(REVERSE_DIR(sink.dir))
		playsound(sink, 'sound/machines/sink-faucet.ogg', 25, TRUE)

/// Standing inside a bolted cell door, calling through it
/datum/prisoner_activity/call_out
	name = "calling through the cell door"
	leisure = TRUE
	context = "locked_in"
	weight = 0
	min_duration = 20 SECONDS
	max_duration = 45 SECONDS
	var/datum/weakref/door_ref

/datum/prisoner_activity/call_out/get_weight()
	if(prisoner.locked_in_seconds < OUTPOST_PRISON_LOCKED_IN_COMPLAINT)
		return 0
	return 8 + (prisoner.hunger < PRISONER_HUNGER_HUNGRY ? 8 : 0)

/datum/prisoner_activity/call_out/setup()
	var/datum/outpost_prison_cell/holding = prisoner.prison.cell_at(get_turf(prisoner))
	var/obj/machinery/door/airlock/door = holding?.door()
	if(!door)
		return FALSE
	door_ref = WEAKREF(door)
	spot = prisoner.approach_turf(door)
	return !!spot

/datum/prisoner_activity/call_out/begin()
	. = ..()
	var/obj/machinery/door/airlock/door = door_ref?.resolve()
	if(door)
		prisoner.face_atom(door)

// ----- the yard -----

/// Pacing up and down, sometimes working out
/datum/prisoner_activity/pace
	name = "pacing"
	leisure = TRUE
	context = "pacing"
	weight = 6
	personality_weights = list("nervous" = 2, "grumpy" = 1.3, "quiet" = 0.8)
	min_duration = 30 SECONDS
	max_duration = 80 SECONDS
	var/turf/end_a
	var/turf/end_b
	/// Ticks to stand at an end before turning round
	var/pause = 0
	/// Push-ups and sit-ups instead of pacing
	var/exercising = FALSE

/datum/prisoner_activity/pace/get_weight()
	. = ..()
	// A tense wing paces.
	var/tense_stage = prisoner.prison?.stage
	if(tense_stage == PRISON_STAGE_GRUMBLING || tense_stage == PRISON_STAGE_RESTLESS)
		. *= 1.5

/datum/prisoner_activity/pace/setup()
	var/list/starts = list()
	for(var/turf/tile as anything in prisoner.walkable)
		if(get_dist(prisoner, tile) <= 5 && prisoner.may_loiter(tile))
			starts += tile
	for(var/attempt in 1 to 8)
		if(!length(starts))
			return FALSE
		var/turf/start = pick_n_take(starts)
		if(prisoner.tile_taken(start) && start != prisoner.loc)
			continue
		var/direction = pick(GLOB.cardinals)
		var/turf/far = start
		var/steps = 0
		for(var/i in 1 to 4)
			var/turf/next = get_step(far, direction)
			if(!next || !prisoner.walkable[next] || !prisoner.may_loiter(next))
				break
			far = next
			steps++
		if(steps < 2)
			continue
		end_a = start
		end_b = far
		spot = end_a
		exercising = prob(25)
		if(exercising)
			name = "exercising"
		return TRUE
	return FALSE

/datum/prisoner_activity/pace/tick(seconds)
	if(world.time >= ends_at)
		return ACTIVITY_DONE
	if(pause > 0)
		pause--
		return ACTIVITY_CONTINUE
	if(exercising)
		if(prob(20))
			prisoner.manual_emote(pick("does a set of push-ups.", "does some sit-ups.", "stretches.", "shadowboxes for a bit."))
		pause = rand(3, 6)
		return ACTIVITY_CONTINUE
	spot = prisoner.loc == end_a ? end_b : end_a
	pause = rand(0, 2)
	return ACTIVITY_MOVE

/datum/prisoner_activity/pace/Destroy()
	end_a = null
	end_b = null
	return ..()

/// Standing somewhere for a bit
/datum/prisoner_activity/wander
	name = "hanging around"
	leisure = TRUE
	context = "idle"
	weight = 4
	min_duration = 10 SECONDS
	max_duration = 30 SECONDS

/datum/prisoner_activity/wander/setup()
	var/list/options = list()
	for(var/turf/tile as anything in prisoner.walkable)
		if(get_dist(prisoner, tile) <= 5 && !prisoner.tile_taken(tile) && prisoner.may_loiter(tile))
			options += tile
	if(!length(options))
		return FALSE
	spot = pick(options)
	return TRUE

/// Looking out of a window
/datum/prisoner_activity/window
	name = "looking out the window"
	leisure = TRUE
	context = "window"
	weight = 5
	personality_weights = list("nervous" = 1.5, "quiet" = 1.5)
	min_duration = 30 SECONDS
	max_duration = 90 SECONDS
	var/datum/weakref/window_ref

/datum/prisoner_activity/window/setup()
	var/obj/structure/window/window = prisoner.find_fixture("window")
	if(!window || !claim(window))
		return FALSE
	window_ref = WEAKREF(window)
	spot = prisoner.approach_turf(window)
	return !!spot

/datum/prisoner_activity/window/begin()
	. = ..()
	var/obj/structure/window/window = window_ref?.resolve()
	if(window)
		prisoner.face_atom(window)

/// A drink at the water cooler
/datum/prisoner_activity/water
	name = "getting a drink"
	leisure = TRUE
	context = "water"
	weight = 4
	min_duration = 10 SECONDS
	max_duration = 25 SECONDS
	var/datum/weakref/cooler_ref
	var/drank = FALSE

/datum/prisoner_activity/water/setup()
	var/obj/structure/reagent_dispensers/water_cooler/cooler = prisoner.find_fixture("cooler")
	if(!cooler || !claim(cooler))
		return FALSE
	cooler_ref = WEAKREF(cooler)
	spot = prisoner.approach_turf(cooler)
	return !!spot

/datum/prisoner_activity/water/tick(seconds)
	var/obj/structure/reagent_dispensers/water_cooler/cooler = cooler_ref?.resolve()
	if(!cooler)
		return ACTIVITY_DONE
	prisoner.face_atom(cooler)
	if(!drank)
		drank = TRUE
		playsound(cooler, 'sound/items/drink.ogg', 25, TRUE)
	return ..()

/// Shooting hoops. Two can play: whoever is closer gets the rebound.
/datum/prisoner_activity/basketball
	name = "shooting hoops"
	leisure = TRUE
	mood_activity = TRUE
	context = "basketball"
	weight = 8
	personality_weights = list("cheerful" = 1.8, "chatty" = 1.2, "quiet" = 0.5, "nervous" = 0.7)
	min_duration = 40 SECONDS
	max_duration = 120 SECONDS
	var/datum/weakref/hoop_ref
	var/datum/weakref/ball_ref
	/// Ticks spent lining up a shot
	var/aim = 0
	/// A shot is in the air
	var/in_flight = FALSE
	/// Ticks spent waiting on someone who picked the ball up
	var/waited_on_staff = 0
	/// The hoop's score when the ball was last thrown, to tell when someone else sinks one
	var/score_at_throw = 0

/datum/prisoner_activity/basketball/get_weight()
	. = ..()
	if(prisoner.prison.anyone_doing(type, prisoner))
		. *= 2

/datum/prisoner_activity/basketball/setup()
	var/obj/structure/hoop/hoop = prisoner.find_fixture("hoop")
	var/obj/item/toy/basketball/ball = prisoner.prison.find_ball(prisoner)
	if(!hoop || !ball)
		return FALSE
	hoop_ref = WEAKREF(hoop)
	ball_ref = WEAKREF(ball)
	RegisterSignal(ball, COMSIG_MOVABLE_POST_THROW, PROC_REF(on_ball_thrown))
	RegisterSignal(ball, COMSIG_MOVABLE_THROW_LANDED, PROC_REF(on_ball_landed))
	return TRUE

/datum/prisoner_activity/basketball/Destroy()
	var/obj/item/toy/basketball/ball = ball_ref?.resolve()
	if(ball)
		UnregisterSignal(ball, list(COMSIG_MOVABLE_POST_THROW, COMSIG_MOVABLE_THROW_LANDED))
	return ..()

/datum/prisoner_activity/basketball/proc/on_ball_thrown(datum/source, datum/thrownthing/thrown, spin)
	SIGNAL_HANDLER
	var/obj/structure/hoop/hoop = hoop_ref?.resolve()
	score_at_throw = hoop?.total_score || 0

/// Someone else's shot came down: if staff sank it, the players cheer
/datum/prisoner_activity/basketball/proc/on_ball_landed(datum/source, datum/thrownthing/thrown)
	SIGNAL_HANDLER
	var/obj/structure/hoop/hoop = hoop_ref?.resolve()
	var/mob/living/thrower = thrown?.get_thrower()
	if(!hoop || !istype(thrower) || is_outpost_prisoner(thrower))
		return
	var/scored = hoop.total_score > score_at_throw
	// The courtside crowd (outpost_prison_pastimes.dm) sees every shot.
	prisoner?.prison?.on_basket(thrower, hoop, scored)
	if(!scored)
		return
	prisoner?.prison?.staff_basket(thrower, hoop)

/datum/prisoner_activity/basketball/tick(seconds)
	var/obj/structure/hoop/hoop = hoop_ref?.resolve()
	var/obj/item/toy/basketball/ball = ball_ref?.resolve()
	if(!hoop || QDELETED(ball))
		return ACTIVITY_DONE
	if(in_flight)
		return ACTIVITY_CONTINUE
	if(world.time >= ends_at)
		return ACTIVITY_DONE
	if(prisoner.held_item == ball)
		if(!good_shooting_spot(prisoner.loc, hoop))
			spot = pick_spot(hoop, 2, 4)
			aim = 0
			return spot ? ACTIVITY_MOVE : ACTIVITY_DONE
		prisoner.face_atom(hoop)
		if(++aim < 2)
			return ACTIVITY_CONTINUE
		shoot(hoop, ball)
		return ACTIVITY_CONTINUE
	if(isturf(ball.loc))
		if(prisoner.prison.claimed_by_other(ball, prisoner))
			return wait_near(hoop)
		claim(ball)
		if(prisoner.try_reach(ball) == PRISONER_REACH_OK)
			prisoner.take_item(ball)
			return ACTIVITY_CONTINUE
		spot = prisoner.approach_turf(ball)
		return spot ? ACTIVITY_MOVE : ACTIVITY_DONE
	if(is_outpost_prisoner(ball.loc))
		return wait_near(hoop)
	// Staff picked it up: they wait a while to see if it comes back.
	if(ismob(ball.loc) && get_dist(prisoner, ball) <= 7 && ++waited_on_staff <= 20)
		return wait_near(hoop)
	return ACTIVITY_DONE

/// Standing near the hoop while the other player shoots
/datum/prisoner_activity/basketball/proc/wait_near(obj/structure/hoop/hoop)
	if(get_dist(prisoner, hoop) <= 2 && good_court_tile(prisoner.loc, hoop))
		var/obj/item/toy/basketball/ball = ball_ref?.resolve()
		prisoner.face_atom(ball ? get_turf(ball) : hoop)
		return ACTIVITY_CONTINUE
	spot = pick_spot(hoop, 1, 2)
	return spot ? ACTIVITY_MOVE : ACTIVITY_CONTINUE

/// In front of the hoop, on ground they can walk
/datum/prisoner_activity/basketball/proc/good_court_tile(turf/tile, obj/structure/hoop/hoop)
	return tile && prisoner.walkable?[tile] && (get_dir(hoop, tile) & hoop.dir)

/datum/prisoner_activity/basketball/proc/good_shooting_spot(turf/tile, obj/structure/hoop/hoop)
	var/distance = get_dist(tile, hoop)
	return distance >= 2 && distance <= 4 && good_court_tile(tile, hoop)

/// A free court tile between `near` and `far` tiles from the hoop
/datum/prisoner_activity/basketball/proc/pick_spot(obj/structure/hoop/hoop, near, far)
	var/list/options = list()
	for(var/turf/tile as anything in prisoner.walkable)
		var/distance = get_dist(tile, hoop)
		if(distance < near || distance > far || !good_court_tile(tile, hoop))
			continue
		if(tile != prisoner.loc && prisoner.tile_taken(tile))
			continue
		options += tile
	return length(options) ? pick(options) : null

/datum/prisoner_activity/basketball/proc/shoot(obj/structure/hoop/hoop, obj/item/toy/basketball/ball)
	waited_on_staff = 0
	prisoner.drop_held_item(prisoner.loc)
	// Whoever is closer gets the rebound.
	unclaim(ball)
	in_flight = TRUE
	aim = 0
	ball.throw_at(hoop, 6, 1, prisoner, TRUE, FALSE, CALLBACK(src, PROC_REF(shot_landed), hoop.total_score))

/datum/prisoner_activity/basketball/proc/shot_landed(old_score)
	in_flight = FALSE
	if(QDELETED(src) || QDELETED(prisoner))
		return
	var/obj/structure/hoop/hoop = hoop_ref?.resolve()
	var/scored = hoop && hoop.total_score > old_score
	if(hoop)
		prisoner.prison?.on_basket(prisoner, hoop, scored)
	if(prob(scored ? 50 : 35))
		prisoner.say_context(scored ? "basketball_score" : "basketball_miss")

/datum/prisoner_activity/basketball/finish()
	var/obj/item/toy/basketball/ball = ball_ref?.resolve()
	if(ball && prisoner?.held_item == ball)
		prisoner.drop_held_item()
	return ..()

/// A book off the shelf, read in the chair by the bookcase. The book goes back, or stays out.
/datum/prisoner_activity/read
	name = "reading"
	leisure = TRUE
	mood_activity = TRUE
	context = "reading"
	weight = 7
	personality_weights = list("quiet" = 1.8, "nervous" = 1.2, "cheerful" = 0.8, "chatty" = 0.7)
	min_duration = 60 SECONDS
	max_duration = 150 SECONDS
	var/datum/weakref/book_ref
	var/datum/weakref/shelf_ref
	var/datum/weakref/seat_ref
	/// "fetch", "seat", "reading" or "return"
	var/stage = "fetch"
	/// Ticks spent waiting to reach a book
	var/waited = 0

/datum/prisoner_activity/read/setup()
	// A book someone left out, or one off a shelf with books on it.
	var/obj/item/book/loose = prisoner.prison.find_loose_book(prisoner)
	if(loose && claim(loose))
		book_ref = WEAKREF(loose)
		spot = prisoner.approach_turf(loose)
		return !!spot
	for(var/obj/structure/bookcase/shelf as anything in shuffle(prisoner.prison.fixtures_of("bookcase")))
		if(QDELETED(shelf) || !(locate(/obj/item/book) in shelf) || !prisoner.approach_turf(shelf))
			continue
		shelf_ref = WEAKREF(shelf)
		spot = prisoner.approach_turf(shelf)
		return TRUE
	return FALSE

/datum/prisoner_activity/read/arrive()
	spot = null
	if(!started)
		started = TRUE
		ends_at = INFINITY
	switch(stage)
		if("seat")
			var/obj/structure/chair/seat = seat_ref?.resolve()
			if(seat)
				prisoner.sit_on(seat, seat.dir)
			start_reading()
		if("return")
			var/obj/structure/bookcase/shelf = shelf_ref?.resolve()
			var/obj/item/book/book = book_ref?.resolve()
			if(shelf && book && prisoner.held_item == book && prisoner.Adjacent(shelf))
				book.forceMove(shelf)
				shelf.update_appearance()
			stage = "done"
	return TRUE

/datum/prisoner_activity/read/tick(seconds)
	switch(stage)
		if("fetch")
			return fetch()
		if("reading")
			if(world.time < ends_at)
				return ACTIVITY_CONTINUE
			var/obj/structure/bookcase/shelf = shelf_ref?.resolve()
			if(shelf && prob(60) && prisoner.approach_turf(shelf))
				stage = "return"
				prisoner.stand_up()
				spot = prisoner.approach_turf(shelf)
				return ACTIVITY_MOVE
			// Left out for someone else to find, or to put away.
			prisoner.drop_held_item()
			return ACTIVITY_DONE
	return ACTIVITY_DONE

/// Takes the book from the shelf or the floor, then heads for a seat
/datum/prisoner_activity/read/proc/fetch()
	var/obj/item/book/book = book_ref?.resolve()
	if(!book)
		var/obj/structure/bookcase/shelf = shelf_ref?.resolve()
		if(!shelf || !prisoner.Adjacent(shelf))
			return ACTIVITY_DONE
		book = locate() in shelf
		if(!book)
			return ACTIVITY_DONE
		book.forceMove(get_turf(prisoner))
		shelf.update_appearance()
		book_ref = WEAKREF(book)
		prisoner.take_item(book)
	else if(prisoner.held_item != book)
		switch(prisoner.try_reach(book))
			if(PRISONER_REACH_WAIT)
				return ++waited > 6 ? ACTIVITY_DONE : ACTIVITY_CONTINUE
			if(PRISONER_REACH_FAILED)
				return ACTIVITY_DONE
		if(!prisoner.take_item(book))
			return ACTIVITY_DONE
	// Somewhere to sit: the reading chair, else their own bed, else right here.
	var/obj/structure/chair/seat = prisoner.find_fixture("reading_chair", stand_on = TRUE)
	if(seat && claim(seat))
		seat_ref = WEAKREF(seat)
		stage = "seat"
		spot = get_turf(seat)
		return ACTIVITY_MOVE
	start_reading()
	return ACTIVITY_CONTINUE

/datum/prisoner_activity/read/proc/start_reading()
	stage = "reading"
	ends_at = world.time + rand(min_duration, max_duration)
	var/obj/item/book/book = book_ref?.resolve()
	if(book)
		prisoner.visible_message(span_notice("[prisoner] opens [book] and starts reading."))

/datum/prisoner_activity/read/finish()
	var/obj/item/book/book = book_ref?.resolve()
	if(book && prisoner?.held_item == book)
		prisoner.drop_held_item()
	return ..()

/// Walks over to another prisoner and talks with them
/datum/prisoner_activity/chat
	name = "chatting"
	leisure = TRUE
	mood_activity = TRUE
	weight = 7
	personality_weights = list("chatty" = 2, "cheerful" = 1.5, "grumpy" = 0.6, "quiet" = 0.4)
	min_duration = 30 SECONDS
	max_duration = 60 SECONDS
	var/datum/weakref/partner_ref
	/// When the next exchange starts
	var/next_exchange = 0

/datum/prisoner_activity/chat/chat_partner()
	return partner_ref?.resolve()

/datum/prisoner_activity/chat/setup()
	var/list/options = list()
	for(var/mob/living/basic/outpost_prisoner/other as anything in prisoner.prison.prisoners)
		if(other == prisoner || !can_join(other))
			continue
		options += other
	while(length(options))
		// Friends first (outpost_prison_life.dm); the pick comes out of options either way.
		var/mob/living/basic/outpost_prisoner/other = prisoner.prison.take_chat_partner(prisoner, options)
		var/turf/beside = prisoner.approach_turf(other)
		if(!beside)
			continue
		partner_ref = WEAKREF(other)
		spot = beside
		return TRUE
	return FALSE

/// Whether `other` is free to talk
/datum/prisoner_activity/chat/proc/can_join(mob/living/basic/outpost_prisoner/other)
	if(QDELETED(other) || !other.routine_allowed() || other.activity?.sleeping)
		return FALSE
	if(other.activity && (!other.activity.interruptible || istype(other.activity, /datum/prisoner_activity/chat)))
		return FALSE
	return TRUE

/datum/prisoner_activity/chat/arrive()
	var/mob/living/basic/outpost_prisoner/partner = partner_ref?.resolve()
	if(!partner || get_dist(prisoner, partner) > 1 || !can_join(partner))
		return FALSE
	. = ..()
	partner.start_activity(new /datum/prisoner_activity/chat/listen(partner, prisoner))
	prisoner.face_atom(partner)
	partner.face_atom(prisoner)
	next_exchange = world.time + 1 SECONDS

/datum/prisoner_activity/chat/tick(seconds)
	var/mob/living/basic/outpost_prisoner/partner = partner_ref?.resolve()
	if(!partner || get_dist(prisoner, partner) > 1 || partner.activity?.chat_partner() != prisoner)
		return ACTIVITY_DONE
	prisoner.face_atom(partner)
	if(world.time >= next_exchange)
		next_exchange = world.time + rand(15, 25) SECONDS
		if(prisoner.prison.wing_can_speak() && !prisoner.prison.speech_hushed(prisoner, "conversation"))
			prisoner.start_conversation(partner)
	return ..()

/datum/prisoner_activity/chat/finish()
	var/mob/living/basic/outpost_prisoner/partner = partner_ref?.resolve()
	if(partner && istype(partner.activity, /datum/prisoner_activity/chat/listen) && partner.activity.chat_partner() == prisoner)
		partner.end_activity()
	if(started && partner)
		prisoner?.prison?.note_chat(prisoner, partner)
	return ..()

/// The other half of a chat: stays put and faces whoever came over
/datum/prisoner_activity/chat/listen
	leisure = FALSE
	weight = 0

/datum/prisoner_activity/chat/listen/New(mob/living/basic/outpost_prisoner/doer, mob/living/basic/outpost_prisoner/talker)
	. = ..(doer)
	partner_ref = WEAKREF(talker)
	started = TRUE
	ends_at = INFINITY

/datum/prisoner_activity/chat/listen/setup()
	return TRUE

/datum/prisoner_activity/chat/listen/arrive()
	spot = null
	return TRUE

/datum/prisoner_activity/chat/listen/tick(seconds)
	var/mob/living/basic/outpost_prisoner/talker = partner_ref?.resolve()
	if(!talker || get_dist(prisoner, talker) > 1 || talker.activity?.chat_partner() != prisoner)
		return ACTIVITY_DONE
	prisoner.face_atom(talker)
	return ACTIVITY_CONTINUE

/datum/prisoner_activity/chat/listen/finish()
	prisoner?.stand_up()
	release_claims()

// ----- needs and duties -----

/**
 * Hungry: gets food from a serving hatch (or eats what they carry), takes it to a mess table and
 * eats. In a good mood they take the wrapper to the bin afterwards.
 */
/datum/prisoner_activity/eat
	name = "eating"
	context = "eating"
	weight = 0
	interruptible = FALSE
	var/datum/weakref/food_ref
	var/datum/weakref/seat_ref
	/// The table in front of their seat, if they found one
	var/turf/table_turf
	/// "fetch", "seat", "eating", "bin" or "done"
	var/stage = "fetch"
	var/waited = 0
	var/eat_until = 0
	/// The wrapper they are taking to the bin, and the bin
	var/datum/weakref/trash_ref
	var/datum/weakref/bin_ref

/datum/prisoner_activity/eat/setup()
	// A held cake saved for a party is not a meal (outpost_prison_pastimes.dm).
	var/obj/item/food/meal = (istype(prisoner.held_item, /obj/item/food) && !prisoner.prison.reserved_supply(prisoner.held_item, prisoner)) ? prisoner.held_item : null
	if(meal)
		// Set down on the table while they eat, it stays theirs
		claim(meal)
		food_ref = WEAKREF(meal)
		return go_to_seat()
	meal = prisoner.prison.find_supply(prisoner, FALSE)
	if(!meal || !claim(meal))
		return FALSE
	food_ref = WEAKREF(meal)
	spot = prisoner.approach_turf(meal)
	return !!spot

/datum/prisoner_activity/eat/arrive()
	spot = null
	if(!started)
		started = TRUE
		ends_at = INFINITY
	if(stage == "bin")
		var/obj/item/trash = trash_ref?.resolve()
		var/obj/structure/closet/crate/bin/bin = bin_ref?.resolve()
		if(trash && prisoner.held_item == trash && !prisoner.bin_litter(trash, bin))
			// Filled up while they walked over.
			prisoner.say_context("bin_full")
			prisoner.drop_held_item()
		stage = "done"
		return TRUE
	if(stage == "seat")
		var/obj/structure/chair/seat = seat_ref?.resolve()
		var/obj/item/food/meal = food_ref?.resolve()
		if(seat)
			prisoner.sit_on(seat, table_turf ? get_cardinal_dir(prisoner, table_turf) : seat.dir)
		if(meal && prisoner.held_item == meal && table_turf)
			prisoner.drop_held_item(table_turf)
		start_eating()
	return TRUE

/datum/prisoner_activity/eat/tick(seconds)
	if(stage == "bin" || stage == "done")
		return ACTIVITY_DONE
	var/obj/item/food/meal = food_ref?.resolve()
	if(QDELETED(meal))
		return ACTIVITY_DONE
	switch(stage)
		if("fetch")
			if(prisoner.held_item != meal)
				// Beside the hatch or the food, facing it, the window door all the way open: a hand
				// goes out, and the tick after, they take it.
				switch(prisoner.reach_for(meal))
					if(PRISONER_REACH_WAIT)
						return ++waited > 6 ? ACTIVITY_DONE : ACTIVITY_CONTINUE
					if(PRISONER_REACH_FAILED)
						return ACTIVITY_DONE
				if(!prisoner.take_item(meal, announce = TRUE))
					return ACTIVITY_DONE
				if(prob(50))
					prisoner.thank("thanks_food")
			if(!go_to_seat())
				return ACTIVITY_DONE
			return spot ? ACTIVITY_MOVE : ACTIVITY_CONTINUE
		if("eating")
			if(prob(35))
				playsound(prisoner, 'sound/items/eatfood.ogg', 20, TRUE)
			if(world.time < eat_until)
				return ACTIVITY_CONTINUE
			return carry_to_bin(prisoner.finish_meal(meal, get_turf(prisoner), table_turf))
	return ACTIVITY_CONTINUE

/// After the meal: takes the wrapper over to the bin, if they meant to and can get there
/datum/prisoner_activity/eat/proc/carry_to_bin(obj/item/trash)
	if(QDELETED(trash))
		return ACTIVITY_DONE
	var/obj/structure/closet/crate/bin/bin = prisoner.prison.find_bin(prisoner)
	var/turf/stand = bin ? prisoner.approach_turf(bin) : null
	if(!stand || !prisoner.take_item(trash))
		return ACTIVITY_DONE
	trash_ref = WEAKREF(trash)
	bin_ref = WEAKREF(bin)
	stage = "bin"
	spot = stand
	return ACTIVITY_MOVE

/// A free stool at a mess table, or eating where they stand when there is none
/datum/prisoner_activity/eat/proc/go_to_seat()
	for(var/obj/structure/chair/stool in prisoner.prison.fixtures_of("stool"))
		if(QDELETED(stool) || !prisoner.walkable?[get_turf(stool)] || prisoner.prison.claimed_by_other(stool, prisoner))
			continue
		if(get_turf(stool) != prisoner.loc && prisoner.tile_taken(get_turf(stool)))
			continue
		var/turf/table = prisoner.prison.table_beside(stool)
		if(!table || !claim(stool))
			continue
		seat_ref = WEAKREF(stool)
		table_turf = table
		stage = "seat"
		spot = get_turf(stool)
		return TRUE
	start_eating()
	return TRUE

/datum/prisoner_activity/eat/proc/start_eating()
	stage = "eating"
	spot = null
	eat_until = world.time + rand(8, 15) SECONDS
	if(table_turf)
		prisoner.prison?.note_table_meal(prisoner)

/datum/prisoner_activity/eat/finish()
	var/obj/item/food/meal = food_ref?.resolve()
	var/obj/item/trash = trash_ref?.resolve()
	if(prisoner?.held_item && (prisoner.held_item == meal || prisoner.held_item == trash))
		prisoner.drop_held_item()
	table_turf = null
	return ..()

/// Dirty: fetches a cleaner uniform from a serving hatch and changes
/datum/prisoner_activity/change
	name = "changing"
	weight = 0
	interruptible = FALSE
	var/datum/weakref/uniform_ref
	var/waited = 0

/datum/prisoner_activity/change/setup()
	var/obj/item/clothing/under/rank/prisoner/outpost/fresh = prisoner.prison.find_supply(prisoner, TRUE)
	if(!fresh || !claim(fresh))
		return FALSE
	uniform_ref = WEAKREF(fresh)
	spot = prisoner.approach_turf(fresh)
	return !!spot

/datum/prisoner_activity/change/tick(seconds)
	var/obj/item/clothing/under/rank/prisoner/outpost/fresh = uniform_ref?.resolve()
	if(!fresh || !prisoner.would_change_into(fresh))
		return ACTIVITY_DONE
	switch(prisoner.reach_for(fresh))
		if(PRISONER_REACH_WAIT)
			return ++waited > 6 ? ACTIVITY_DONE : ACTIVITY_CONTINUE
		if(PRISONER_REACH_FAILED)
			return ACTIVITY_DONE
	if(prisoner.take_uniform(fresh))
		prisoner.thank("thanks_uniform")
	return ACTIVITY_DONE

/// Hungry or dirty with nothing to be had: standing at the hatch, waiting
/datum/prisoner_activity/hatch_wait
	name = "waiting at the hatch"
	context = "hatch_wait"
	weight = 0
	min_duration = 30 SECONDS
	max_duration = 60 SECONDS
	var/datum/weakref/hatch_ref

/datum/prisoner_activity/hatch_wait/setup()
	for(var/obj/structure/table/reinforced/prison_hatch/hatch in shuffle(prisoner.prison.fixtures_of("hatch")))
		if(QDELETED(hatch))
			continue
		var/turf/front = hatch.yard_side_turf()
		if(!front || !prisoner.walkable?[front] || prisoner.prison.claimed_by_other(hatch, prisoner))
			continue
		if(front != prisoner.loc && prisoner.tile_taken(front))
			continue
		if(!claim(hatch))
			continue
		hatch_ref = WEAKREF(hatch)
		spot = front
		return TRUE
	return FALSE

/datum/prisoner_activity/hatch_wait/tick(seconds)
	var/obj/structure/table/reinforced/prison_hatch/hatch = hatch_ref?.resolve()
	if(!hatch)
		return ACTIVITY_DONE
	prisoner.face_atom(hatch)
	// Something turned up: go and get it.
	if(prisoner.wants_food() && prisoner.prison.find_supply(prisoner, FALSE))
		return ACTIVITY_DONE
	if(prisoner.wants_clean_uniform() && prisoner.prison.find_supply(prisoner, TRUE))
		return ACTIVITY_DONE
	return ..()

/**
 * Hurt, with someone holding dressings in the yard: goes over to them and asks. Ends once they are
 * treated, or when the medic walks off.
 */
/datum/prisoner_activity/sick_call
	name = "asking for the medic"
	weight = 0
	interruptible = FALSE
	var/datum/weakref/medic_ref
	/// Whether they have asked yet
	var/asked = FALSE

/datum/prisoner_activity/sick_call/setup()
	var/mob/living/medic = prisoner.find_medic()
	if(!medic)
		return FALSE
	medic_ref = WEAKREF(medic)
	spot = prisoner.approach_turf(medic)
	if(!spot)
		return FALSE
	COOLDOWN_START(prisoner, sick_call_cooldown, PRISONER_SICK_CALL_COOLDOWN)
	return TRUE

/datum/prisoner_activity/sick_call/begin()
	started = TRUE
	ends_at = world.time + PRISONER_SICK_CALL_TIME

/datum/prisoner_activity/sick_call/tick(seconds)
	var/mob/living/medic = medic_ref?.resolve()
	if(prisoner.health_factor() >= PRISONER_INJURED_BELOW || world.time >= ends_at || !prisoner.is_medic(medic))
		return ACTIVITY_DONE
	if(get_dist(prisoner, medic) > 1)
		spot = prisoner.approach_turf(medic)
		return spot ? ACTIVITY_MOVE : ACTIVITY_DONE
	prisoner.face_atom(medic)
	if(!asked)
		asked = TRUE
		prisoner.say_context("sick_call")
	return ACTIVITY_CONTINUE

/// Content and idle: picks up a piece of litter and puts it in the bin
/datum/prisoner_activity/tidy
	name = "tidying up"
	leisure = TRUE
	weight = 3
	personality_weights = list("cheerful" = 1.5, "nervous" = 1.3, "grumpy" = 0.4)
	var/datum/weakref/litter_ref
	var/datum/weakref/bin_ref
	/// "fetch", "carry" or "done"
	var/stage = "fetch"
	var/waited = 0

/datum/prisoner_activity/tidy/get_weight()
	if(prisoner.mood < PRISONER_TIDY_MOOD || !COOLDOWN_FINISHED(prisoner, tidy_cooldown))
		return 0
	return ..()

/datum/prisoner_activity/tidy/setup()
	var/obj/structure/closet/crate/bin/bin = prisoner.prison.find_bin(prisoner)
	if(!outpost_bin_has_room(bin) || !prisoner.approach_turf(bin))
		return FALSE
	var/obj/item/trash/litter = prisoner.prison.find_litter(prisoner)
	if(!litter || !claim(litter))
		return FALSE
	spot = prisoner.approach_turf(litter)
	if(!spot)
		return FALSE
	litter_ref = WEAKREF(litter)
	bin_ref = WEAKREF(bin)
	COOLDOWN_START(prisoner, tidy_cooldown, PRISONER_TIDY_COOLDOWN)
	return TRUE

/datum/prisoner_activity/tidy/arrive()
	spot = null
	if(!started)
		started = TRUE
		ends_at = world.time + 60 SECONDS
	if(stage == "carry")
		var/obj/item/trash/litter = litter_ref?.resolve()
		var/obj/structure/closet/crate/bin/bin = bin_ref?.resolve()
		if(litter && prisoner.held_item == litter && prisoner.bin_litter(litter, bin))
			prisoner.say_context("tidy")
		stage = "done"
	return TRUE

/datum/prisoner_activity/tidy/tick(seconds)
	if(stage != "fetch" || world.time >= ends_at)
		return ACTIVITY_DONE
	var/obj/item/trash/litter = litter_ref?.resolve()
	if(QDELETED(litter))
		return ACTIVITY_DONE
	if(prisoner.held_item != litter)
		switch(prisoner.reach_for(litter))
			if(PRISONER_REACH_WAIT)
				return ++waited > 6 ? ACTIVITY_DONE : ACTIVITY_CONTINUE
			if(PRISONER_REACH_FAILED)
				return ACTIVITY_DONE
		if(!prisoner.take_item(litter, announce = TRUE))
			return ACTIVITY_DONE
	var/obj/structure/closet/crate/bin/bin = bin_ref?.resolve()
	spot = bin ? prisoner.approach_turf(bin) : null
	if(!spot)
		return ACTIVITY_DONE
	stage = "carry"
	return ACTIVITY_MOVE

/datum/prisoner_activity/tidy/finish()
	var/obj/item/trash/litter = litter_ref?.resolve()
	if(litter && prisoner?.held_item == litter)
		prisoner.drop_held_item()
	return ..()

/// The end of their sentence: back to their cell to be beamed out
/datum/prisoner_activity/go_home
	name = "heading to their cell"
	weight = 0
	interruptible = FALSE

/datum/prisoner_activity/go_home/setup()
	var/turf/home = prisoner.cell?.arrival_turf()
	if(home && prisoner.walkable?[home] && (home == prisoner.loc || !prisoner.tile_taken(home)))
		spot = home
		return TRUE
	for(var/turf/tile as anything in prisoner.cell?.turfs)
		if(prisoner.walkable?[tile] && (tile == prisoner.loc || !prisoner.tile_taken(tile)))
			spot = tile
			return TRUE
	// Can't get there: they wait where they are.
	return TRUE

/datum/prisoner_activity/go_home/begin()
	started = TRUE
	ends_at = INFINITY

/datum/prisoner_activity/go_home/tick(seconds)
	return ACTIVITY_CONTINUE

#undef ACTIVITY_CONTINUE
#undef ACTIVITY_DONE
#undef ACTIVITY_MOVE
#undef ACTIVITY_GIVE_UP_TIME
