/**
 * Pirate crew AI: what one member of a /datum/pirate_crew (pirate_crew.dm) does.
 *
 * Fights whoever it can see, breaks through doors that won't open for it, holds the helm if it
 * is the captain or the guard, and otherwise walks to wherever the crew last knew a hostile to
 * be. Doors it may open are walked through, never hit. Allies in a corridor swap places.
 *
 * NPC ship crews and boarders are human NPCs and run the human controller (pirate_crew_human.dm),
 * which fights and breaks doors with the body's own hands. The basic-mob controllers below are what
 * a basic pirate gets if it is enlisted (an admin spawn, a basic boarding type).
 */

// ===== CONTROLLERS =====

/datum/ai_controller/basic_controller/pirate_crew
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
	)
	ai_movement = /datum/ai_movement/pirate_crew
	idle_behavior = /datum/idle_behavior/pirate_crew_wander
	// A hunt across two docked hulls runs far past tg's 14-tile give-up distance
	max_target_distance = 90
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/pirate_crew_find_target,
		/datum/ai_planning_subtree/pirate_crew_doors,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
		/datum/ai_planning_subtree/pirate_crew_hold_post,
		/datum/ai_planning_subtree/pirate_crew_hunt,
		/datum/ai_planning_subtree/pirate_crew_leash,
	)
	/// Doors given up on, REF(door) -> world.time the pirate tries them again
	var/list/skipped_doors
	/// REF() of a door that should open for us but didn't when we walked into it
	var/stuck_door_ref
	/// world.time we first walked into it
	var/stuck_door_since = 0
	/// The last turf we stood on that was on the battlefield
	var/turf/last_battlefield_turf
	/// world.time the hunt may try an unreachable destination again
	var/hunt_backoff_until = 0
	/// The destination that turned out unreachable
	var/turf/unreachable_turf
	/// world.time a waypoint was set
	var/waypoint_set_at = 0
	/// Whether this mob has said its "into their ship" line
	var/crossed_over = FALSE
	/// Set while the current target may be shot at from where we stand but not chased
	var/target_hold_ground = FALSE
	COOLDOWN_DECLARE(swap_cooldown)
	COOLDOWN_DECLARE(breach_search_cooldown)
	COOLDOWN_DECLARE(spot_bark_cooldown)
	COOLDOWN_DECLARE(target_scan_cooldown)
	COOLDOWN_DECLARE(no_way_log_cooldown)

/datum/ai_controller/basic_controller/pirate_crew/ranged
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/pirate_crew_find_target,
		/datum/ai_planning_subtree/pirate_crew_doors,
		/datum/ai_planning_subtree/basic_ranged_attack_subtree/trooper/pirate_crew,
		/datum/ai_planning_subtree/pirate_crew_hold_post,
		/datum/ai_planning_subtree/pirate_crew_hunt,
		/datum/ai_planning_subtree/pirate_crew_leash,
	)

/**
 * tg's trooper gunfire, except that planning carries on while it shoots. Upstream's ranged attack
 * blocks planning until it ends, which would let a gunner follow its target off the battlefield
 * or away from the helm, since nothing would get to check.
 */
/datum/ai_planning_subtree/basic_ranged_attack_subtree/trooper/pirate_crew
	ranged_attack_behavior = /datum/ai_behavior/basic_ranged_attack/trooper/pirate_crew

/datum/ai_planning_subtree/basic_ranged_attack_subtree/trooper/pirate_crew/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	if(!controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return
	var/datum/ai_controller/basic_controller/pirate_crew/pirate_controller = controller
	var/behavior = ranged_attack_behavior
	if(istype(pirate_controller) && pirate_controller.target_hold_ground)
		behavior = /datum/ai_behavior/basic_ranged_attack/trooper/pirate_crew/hold_ground
	controller.queue_behavior(behavior, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_behavior/basic_ranged_attack/trooper/pirate_crew
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/// Returns fire at someone it may not go after (off the battlefield, or past the helm's leash) without taking a step towards them
/datum/ai_behavior/basic_ranged_attack/trooper/pirate_crew/hold_ground
	required_distance = PIRATE_CREW_SIGHT_RANGE
	chase_range = PIRATE_CREW_SIGHT_RANGE

/datum/ai_controller/basic_controller/pirate_crew/TryPossessPawn(atom/new_pawn)
	if(!isliving(new_pawn))
		return AI_CONTROLLER_INCOMPATIBLE
	// Only relays who hit us; harmless to leave on the mob afterwards
	new_pawn.AddElement(/datum/element/relay_attackers)
	RegisterSignal(new_pawn, COMSIG_MOVABLE_BUMP, PROC_REF(on_pawn_bump))
	RegisterSignal(new_pawn, COMSIG_LIVING_PRE_MOB_BUMP, PROC_REF(on_pre_mob_bumped))
	RegisterSignal(new_pawn, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_pawn_attacked))
	RegisterSignal(new_pawn, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_pawn_damaged))
	RegisterSignal(new_pawn, COMSIG_AI_BLACKBOARD_KEY_PRECLEAR(BB_BASIC_MOB_CURRENT_TARGET), PROC_REF(on_target_dropped))
	return ..()

/datum/ai_controller/basic_controller/pirate_crew/UnpossessPawn(destroy)
	if(pawn)
		UnregisterSignal(pawn, list(COMSIG_MOVABLE_BUMP, COMSIG_LIVING_PRE_MOB_BUMP, COMSIG_ATOM_WAS_ATTACKED, COMSIG_MOB_AFTER_APPLY_DAMAGE, COMSIG_AI_BLACKBOARD_KEY_PRECLEAR(BB_BASIC_MOB_CURRENT_TARGET)))
	return ..()

/datum/ai_controller/basic_controller/pirate_crew/Destroy(force)
	skipped_doors = null
	last_battlefield_turf = null
	unreachable_turf = null
	return ..()

/datum/ai_controller/basic_controller/pirate_crew/proc/get_crew()
	var/datum/pirate_crew/crew = blackboard[BB_PIRATE_CREW]
	return QDELETED(crew) ? null : crew

/// Whether we can hit `target` from where we stand, so a door in the way can wait
/datum/ai_controller/basic_controller/pirate_crew/proc/can_hit_now(atom/target)
	if(QDELETED(target))
		return FALSE
	if(istype(src, /datum/ai_controller/basic_controller/pirate_crew/ranged))
		return can_see(pawn, target, 5)
	return get_dist(pawn, target) <= 1

// ----- Door bookkeeping -----

/datum/ai_controller/basic_controller/pirate_crew/proc/door_skipped(obj/door)
	var/door_ref = REF(door)
	var/until = LAZYACCESS(skipped_doors, door_ref)
	if(!until)
		return FALSE
	if(world.time >= until)
		LAZYREMOVE(skipped_doors, door_ref)
		return FALSE
	return TRUE

/datum/ai_controller/basic_controller/pirate_crew/proc/skip_door(obj/door)
	LAZYSET(skipped_doors, REF(door), world.time + PIRATE_CREW_BREACH_SKIP_TIME)

/datum/ai_controller/basic_controller/pirate_crew/proc/start_breach(obj/target, turf/stand)
	if(blackboard[BB_PIRATE_BREACH_TARGET] != target)
		log_shuttle("PIRATE_CREW: [pawn] breaking [target] at [AREACOORD(target)]")
	set_blackboard_key(BB_PIRATE_BREACH_TARGET, target)
	set_blackboard_key(BB_PIRATE_BREACH_STAND, stand || get_turf(pawn))
	set_blackboard_key(BB_PIRATE_BREACH_TURF, get_turf(target))
	set_blackboard_key(BB_PIRATE_BREACH_STARTED, world.time)
	clear_blackboard_key(BB_PIRATE_BREACH_INTEGRITY)
	clear_blackboard_key(BB_PIRATE_BREACH_PROGRESS_AT)

/datum/ai_controller/basic_controller/pirate_crew/proc/clear_breach()
	clear_blackboard_key(BB_PIRATE_BREACH_TARGET)
	clear_blackboard_key(BB_PIRATE_BREACH_STAND)
	clear_blackboard_key(BB_PIRATE_BREACH_TURF)
	clear_blackboard_key(BB_PIRATE_BREACH_STARTED)
	clear_blackboard_key(BB_PIRATE_BREACH_INTEGRITY)
	clear_blackboard_key(BB_PIRATE_BREACH_PROGRESS_AT)

// ----- Pawn signals -----

/**
 * Walking into a door that won't let us through marks it for breaking. A door that ought to
 * open but stays shut while we keep walking into it is treated the same way.
 */
/datum/ai_controller/basic_controller/pirate_crew/proc/on_pawn_bump(mob/living/source, atom/bumped)
	SIGNAL_HANDLER
	// Iron, wood and the other mineral doors only open for mobs with a player in them
	// (TryToSwitchState() checks client), so a pirate pushes one open itself
	if(istype(bumped, /obj/structure/mineral_door))
		var/obj/structure/mineral_door/slab = bumped
		if(pirate_can_open_mineral_door(slab))
			INVOKE_ASYNC(slab, TYPE_PROC_REF(/obj/structure/mineral_door, Open))
		return
	if(!istype(bumped, /obj/machinery/door) && !istype(bumped, /obj/structure/door_assembly))
		return
	var/obj/blocker = bumped
	if(!blocker.density || blackboard[BB_PIRATE_BREACH_TARGET] == blocker)
		return
	var/turf/here = get_turf(source)
	if(istype(blocker, /obj/machinery/door))
		var/obj/machinery/door/door = blocker
		if(door.operating)
			return
		if(pirate_can_open_door(source, door))
			var/door_ref = REF(door)
			if(stuck_door_ref != door_ref || world.time > stuck_door_since + PIRATE_CREW_STUCK_DOOR_RESET)
				stuck_door_ref = door_ref
				stuck_door_since = world.time
				return
			if(world.time < stuck_door_since + PIRATE_CREW_STUCK_DOOR_TIME)
				return
	if(door_skipped(blocker) || !pirate_door_breachable(blocker, here))
		return
	stuck_door_ref = null
	start_breach(blocker, here)

/// An ally walked into us: trade places, the way tg lets two people on help intent pass
/datum/ai_controller/basic_controller/pirate_crew/proc/on_pre_mob_bumped(mob/living/source, mob/living/bumper)
	SIGNAL_HANDLER
	var/datum/ai_controller/basic_controller/pirate_crew/bumper_controller = bumper.ai_controller
	if(!istype(bumper_controller) || GET_CLIENT(bumper) || GET_CLIENT(source))
		return
	if(!source.faction_check_atom(bumper) || !COOLDOWN_FINISHED(bumper_controller, swap_cooldown))
		return
	// Busy fighting someone, or breaking a door, right next to us: let them go around
	var/atom/our_target = blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!QDELETED(our_target) && source.Adjacent(our_target))
		return
	var/obj/our_door = blackboard[BB_PIRATE_BREACH_TARGET]
	if(!QDELETED(our_door) && source.Adjacent(our_door))
		return
	if(source.buckled || bumper.buckled || source.has_buckled_mobs() || bumper.has_buckled_mobs() || source.pulledby || bumper.pulledby)
		return
	if(bumper.moving_diagonally || !(source.mobility_flags & MOBILITY_MOVE))
		return
	COOLDOWN_START(bumper_controller, swap_cooldown, PIRATE_CREW_SWAP_COOLDOWN)
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(pirate_crew_swap_places), bumper, source)
	return COMPONENT_LIVING_BLOCK_PRE_MOB_BUMP

/// Someone hit us: the crew goes on alert, and we turn on them if we have nothing better to do
/datum/ai_controller/basic_controller/pirate_crew/proc/on_pawn_attacked(mob/living/source, atom/attacker, attack_flags)
	SIGNAL_HANDLER
	if(source == attacker || QDELETED(attacker))
		return
	var/datum/pirate_crew/crew = get_crew()
	crew?.raise_alert(source)
	var/atom/foe = attacker
	if(isliving(attacker) && ismecha(attacker.loc))
		foe = attacker.loc
	crew?.report_sighting(attacker, get_turf(attacker))
	if(blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(blackboard[BB_TARGETING_STRATEGY])
	if(strategy?.can_attack(source, foe, PIRATE_CREW_SIGHT_RANGE))
		set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, foe)

/// Whatever made us drop our target (lost sight, out of reach), the crew hears where it was
/datum/ai_controller/basic_controller/pirate_crew/proc/on_target_dropped(mob/living/source)
	SIGNAL_HANDLER
	var/atom/target = blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!QDELETED(target))
		get_crew()?.report_sighting(target, get_turf(target))

/datum/ai_controller/basic_controller/pirate_crew/proc/on_pawn_damaged(mob/living/source, damage_dealt)
	SIGNAL_HANDLER
	if(damage_dealt <= 0)
		return
	get_crew()?.raise_alert(source)

/// Swaps two mobs the way /mob/living/MobBump() does, putting both back if either move fails
/proc/pirate_crew_swap_places(mob/living/mover, mob/living/blocker)
	if(QDELETED(mover) || QDELETED(blocker))
		return FALSE
	var/turf/mover_loc = mover.loc
	var/turf/blocker_loc = blocker.loc
	if(!isturf(mover_loc) || !isturf(blocker_loc) || !mover_loc.Adjacent(blocker_loc))
		return FALSE
	mover.now_pushing = TRUE
	var/mover_passmob = (mover.pass_flags & PASSMOB)
	var/blocker_passmob = (blocker.pass_flags & PASSMOB)
	mover.pass_flags |= PASSMOB
	blocker.pass_flags |= PASSMOB
	var/swapped = TRUE
	if(!blocker.Move(mover_loc) || !mover.Move(blocker_loc))
		blocker.forceMove(blocker_loc)
		mover.forceMove(mover_loc)
		swapped = FALSE
	if(!mover_passmob)
		mover.pass_flags &= ~PASSMOB
	if(!blocker_passmob)
		blocker.pass_flags &= ~PASSMOB
	mover.now_pushing = FALSE
	return swapped

// ===== MOVEMENT =====

/**
 * JPS that reaches across two docked hulls, never plans a route through space, and tells the AI
 * when it finds no way at all.
 *
 * Not a /datum/ai_movement/jps subtype on purpose. That one lets anything with TRAIT_SPACEWALK
 * (every faction pirate) path through space, and it decides so before a subtype could step in,
 * so a pirate kept out of its own docking airlock by blast doors walked out another airlock and
 * across open space instead. The body below is upstream's start_moving_towards() with space
 * routing switched off. Two hulls berthed exit-to-exit share no space tiles, so crossing over
 * still works.
 */
/datum/ai_movement/pirate_crew
	max_pathing_attempts = 10
	/// Longest route the pathfinder plans in one go; the hunt adds waypoints past this
	var/maximum_length = PIRATE_CREW_MAX_PATH
	/// How diagonal steps are handled, as upstream JPS does it
	var/diagonal_flags = DIAGONAL_REMOVE_CLUNKY

/datum/ai_movement/pirate_crew/start_moving_towards(datum/ai_controller/controller, atom/current_movement_target, min_distance)
	. = ..()
	var/datum/move_loop/has_target/jps/loop = GLOB.move_manager.jps_move(controller.pawn,
		current_movement_target,
		controller.movement_delay,
		repath_delay = 0.5 SECONDS,
		simulated_only = TRUE,
		max_path_length = maximum_length,
		minimum_distance = controller.get_minimum_distance(),
		access = controller.get_access(),
		subsystem = SSai_movement,
		diagonal_handling = diagonal_flags,
		extra_info = controller,
	)
	RegisterSignal(loop, COMSIG_MOVELOOP_PREPROCESS_CHECK, PROC_REF(pre_move))
	RegisterSignal(loop, COMSIG_MOVELOOP_POSTPROCESS, PROC_REF(post_move))
	RegisterSignal(loop, COMSIG_MOVELOOP_JPS_REPATH, PROC_REF(repath_incoming))
	RegisterSignal(loop, COMSIG_MOVELOOP_JPS_FINISHED_PATHING, PROC_REF(on_path_finished))
	return loop

/// Same as upstream JPS: the next route uses our current access and reach
/datum/ai_movement/pirate_crew/proc/repath_incoming(datum/move_loop/has_target/jps/source)
	SIGNAL_HANDLER
	var/datum/ai_controller/controller = source.extra_info
	source.access = controller.get_access()
	source.minimum_distance = controller.get_minimum_distance()

/datum/ai_movement/pirate_crew/proc/on_path_finished(datum/move_loop/has_target/jps/source, list/path)
	SIGNAL_HANDLER
	if(length(path))
		return
	var/datum/ai_controller/controller = source.extra_info
	if(QDELETED(controller))
		return
	note_no_path(controller, get_turf(source.target))

/datum/ai_movement/pirate_crew/increment_pathing_failures(datum/ai_controller/controller)
	if(controller.consecutive_pathing_attempts + 1 >= max_pathing_attempts)
		note_no_path(controller, get_turf(controller.current_movement_target))
	return ..()

/datum/ai_movement/pirate_crew/proc/note_no_path(datum/ai_controller/controller, turf/goal)
	if(!goal)
		return
	controller.set_blackboard_key(BB_PIRATE_NO_PATH_AT, world.time)
	controller.set_blackboard_key(BB_PIRATE_NO_PATH_DEST, goal)

/// Wanders near home, never off the battlefield, onto a door or into space. Post holders stand still.
/datum/idle_behavior/pirate_crew_wander
	/// Chance per second to take a step
	var/walk_chance = 15

/datum/idle_behavior/pirate_crew_wander/perform_idle_behavior(seconds_per_tick, datum/ai_controller/controller)
	. = ..()
	var/mob/living/living_pawn = controller.pawn
	if(!isliving(living_pawn) || LAZYLEN(living_pawn.do_afters))
		return
	var/datum/pirate_crew/crew = controller.blackboard[BB_PIRATE_CREW]
	if(QDELETED(crew))
		crew = null
	if(crew?.holds_post(living_pawn))
		return
	if(!SPT_PROB(walk_chance, seconds_per_tick))
		return
	if(!(living_pawn.mobility_flags & MOBILITY_MOVE) || !isturf(living_pawn.loc) || living_pawn.pulledby)
		return
	var/move_dir = pick(GLOB.alldirs)
	var/turf/destination = get_step(living_pawn, move_dir)
	if(!destination || pirate_turf_is_void(destination) || (locate(/obj/machinery/door) in destination) || destination.is_blocked_turf(TRUE))
		return
	if(crew && !crew.turf_on_battlefield(destination))
		return
	var/turf/home = controller.blackboard[BB_PIRATE_HOME_TURF]
	if(home && home.z == destination.z)
		var/new_dist = get_dist(destination, home)
		if(new_dist > PIRATE_CREW_IDLE_LEASH && new_dist >= get_dist(living_pawn, home))
			return
	if(!destination.can_cross_safely(living_pawn))
		return
	living_pawn.Move(destination, move_dir)

// ===== DOORS =====

/**
 * Whether walking into `door` would open it for `pawn`. FALSE for welded, bolted, sealed,
 * emagged and unpowered doors, closed firedoors, shutters, doors with a cut ID scanner, and any
 * door that refuses the pawn's access. Mirrors /obj/machinery/door/Bumped() and bumpopen().
 */
/proc/pirate_can_open_door(mob/living/pawn, obj/machinery/door/door)
	if(QDELETED(door))
		return FALSE
	if(!door.density)
		return TRUE
	if(door.welded || door.locked || (door.obj_flags & EMAGGED) || !door.can_open_with_hands)
		return FALSE
	if(istype(door, /obj/machinery/door/firedoor))
		return FALSE
	if(!door.hasPower())
		return FALSE
	if(istype(door, /obj/machinery/door/airlock))
		var/obj/machinery/door/airlock/airlock = door
		if(airlock.seal)
			return FALSE
		// A docked or air-safe external airlock opens for anyone from inside (try_safety_unlock()),
		// unless its ship's crew lock refuses us (try_to_activate_door() in ship_access.dm)
		if(istype(airlock, /obj/machinery/door/airlock/external) && !(airlock.requiresID() && airlock.refused_by_ship_crew_lock(pawn)))
			var/obj/machinery/door/airlock/external/hatch = airlock
			if(hatch.space_dir && (hatch.shuttledocked || hatch.cyclelinkedairlock?.shuttledocked || is_safe_turf(get_step(hatch, hatch.space_dir), TRUE, FALSE)))
				return TRUE
		if(!airlock.requiresID())
			return FALSE
	return door.allowed(pawn)

/// Whether a pirate can push mineral door `slab` open: shut, bolted to the floor and not already moving
/proc/pirate_can_open_mineral_door(obj/structure/mineral_door/slab)
	return !QDELETED(slab) && slab.density && !slab.door_opened && !slab.isSwitchingStates && slab.anchored

/**
 * Lets a pirate crew's routes run through shut mineral doors. They open them on contact
 * (on_pawn_bump()), but tg only opens them for players, so the pathfinder treats them as
 * walls for every NPC. Only a pirate crew's own path searches are affected.
 */
/obj/structure/mineral_door/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	. = ..()
	if(. || !anchored || door_opened)
		return
	var/mob/living/requester = pass_info?.requester_ref?.resolve()
	if(isliving(requester) && istype(requester.ai_controller, /datum/ai_controller/basic_controller/pirate_crew))
		return TRUE

/**
 * Whether breaking `door` would open the ship to space: an external airlock or blast door with nothing
 * beyond it, or a firelock holding back a room that has lost its air.
 */
/proc/pirate_door_vents_space(obj/machinery/door/door, turf/from)
	if(istype(door, /obj/machinery/door/firedoor))
		var/turf/firelock_turf = get_turf(door)
		var/turf/beyond = (from && firelock_turf) ? get_turf_through_door(from, firelock_turf) : null
		return beyond && !is_safe_turf(beyond, TRUE, FALSE)
	if(!istype(door, /obj/machinery/door/airlock/external) && !istype(door, /obj/machinery/door/poddoor))
		return FALSE
	var/turf/door_turf = get_turf(door)
	if(!door_turf)
		return TRUE
	if(from)
		var/turf/far_side = get_turf_through_door(from, door_turf)
		if(far_side && pirate_turf_is_void(far_side))
			return TRUE
	for(var/dir in GLOB.cardinals)
		var/turf/side = get_step(door_turf, dir)
		if(side && pirate_turf_is_void(side))
			return TRUE
	return FALSE

/// Whether a pirate may break `target` (a closed door, or the frame a broken door left) coming from `from`
/proc/pirate_door_breachable(obj/target, turf/from)
	if(QDELETED(target) || !target.density || (target.resistance_flags & INDESTRUCTIBLE))
		return FALSE
	if(istype(target, /obj/structure/door_assembly))
		return TRUE
	if(!istype(target, /obj/machinery/door))
		return FALSE
	return !pirate_door_vents_space(target, from)

/// The first thing on `where` a pirate has to break to get through, if any
/proc/pirate_breach_blocker(mob/living/pawn, turf/where)
	for(var/obj/machinery/door/door in where)
		if(door.density && !pirate_can_open_door(pawn, door))
			return door
	for(var/obj/structure/door_assembly/frame in where)
		if(frame.density)
			return frame
	return null

/// Whether the breach search may step onto `next` from `from`: open floor, doors it can open or break, nothing else dense
/proc/pirate_breach_search_passable(mob/living/pawn, turf/next, turf/from, list/skipped_doors)
	if(isclosedturf(next) || next.density)
		return FALSE
	for(var/obj/thing in next)
		if(!thing.density)
			continue
		if(istype(thing, /obj/structure/mineral_door))
			// Pushed open on contact; a loose one is just a slab in the way
			var/obj/structure/mineral_door/slab = thing
			if(slab.anchored)
				continue
			return FALSE
		if(istype(thing, /obj/machinery/door))
			var/obj/machinery/door/door = thing
			if(pirate_can_open_door(pawn, door))
				continue
		else if(!istype(thing, /obj/structure/door_assembly))
			// Walls of glass, grilles, tables, machines: never broken, so never a way through
			return FALSE
		var/until = LAZYACCESS(skipped_doors, REF(thing))
		if(until && until > world.time)
			return FALSE
		if(!pirate_door_breachable(thing, from))
			return FALSE
	return TRUE

/**
 * For when the pathfinder finds no way to `goal`: a breadth-first search over the given areas
 * that counts doors as passable. Returns list("door" = the first door on the way that won't
 * open for `pawn`, "stand" = the turf to break it from), or, when every door on the way would
 * open, list("waypoint" = a turf part way along, "length" = the route's length). Null when
 * there is no way through at all.
 */
/proc/pirate_crew_breach_search(mob/living/pawn, turf/start, turf/goal, list/allowed_areas, list/skipped_doors)
	if(!start || !goal || start.z != goal.z || !length(allowed_areas))
		return null
	var/list/parents = list()
	parents[start] = start
	var/list/queue = list(start)
	var/index = 1
	var/found = FALSE
	while(index <= length(queue) && index <= PIRATE_CREW_BREACH_SEARCH_LIMIT)
		var/turf/current = queue[index]
		index++
		if(current == goal)
			found = TRUE
			break
		for(var/dir in GLOB.cardinals)
			var/turf/next = get_step(current, dir)
			if(!next || parents[next])
				continue
			if(next != goal && !allowed_areas[next.loc])
				continue
			if(!pirate_breach_search_passable(pawn, next, current, skipped_doors))
				continue
			parents[next] = current
			queue += next
	if(!found)
		return null
	var/list/route = list()
	var/turf/step_back = goal
	while(step_back != start)
		route.Insert(1, step_back)
		step_back = parents[step_back]
	var/turf/previous = start
	for(var/turf/route_turf as anything in route)
		var/obj/blocker = pirate_breach_blocker(pawn, route_turf)
		if(blocker)
			return list("door" = blocker, "stand" = previous)
		previous = route_turf
	if(!length(route))
		return null
	return list("waypoint" = route[min(length(route), PIRATE_CREW_WAYPOINT_STEPS)], "length" = length(route))

// ===== PLANNING =====

/**
 * Finds someone to fight: the nearest thing in sight within PIRATE_CREW_SIGHT_RANGE the
 * targeting strategy accepts, players first, mechs included. Keeps a current target while it's
 * still in sight and in bounds. One that slipped out of sight is reported to the crew and
 * dropped, so the hunt takes over.
 */
/datum/ai_planning_subtree/pirate_crew_find_target

/datum/ai_planning_subtree/pirate_crew_find_target/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/datum/ai_controller/basic_controller/pirate_crew/pirate_controller = controller
	var/mob/living/basic/pawn = controller.pawn
	var/turf/pawn_turf = get_turf(pawn)
	if(!istype(pirate_controller) || !pawn_turf)
		return
	var/datum/pirate_crew/crew = pirate_controller.get_crew()
	if(crew?.turf_on_battlefield(pawn_turf))
		pirate_controller.last_battlefield_turf = pawn_turf
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(controller.blackboard[BB_TARGETING_STRATEGY])
	if(!strategy)
		return
	var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!QDELETED(target))
		var/reach = strategy.can_attack(pawn, target, PIRATE_CREW_SIGHT_RANGE) ? target_reach(pirate_controller, crew, target) : PIRATE_TARGET_OUT
		if(reach != PIRATE_TARGET_OUT)
			pirate_controller.target_hold_ground = (reach == PIRATE_TARGET_HOLD)
			return
		// Out of sight or out of bounds: drop it and let the hunt take over. on_target_dropped()
		// tells the crew where it was.
		controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
		controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	else if(target)
		controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	if(!COOLDOWN_FINISHED(pirate_controller, target_scan_cooldown))
		return
	COOLDOWN_START(pirate_controller, target_scan_cooldown, PIRATE_CREW_SCAN_COOLDOWN)
	var/atom/found = scan_for_target(pirate_controller, crew, strategy, pawn, pawn_turf)
	if(!found)
		return
	pirate_controller.target_hold_ground = (target_reach(pirate_controller, crew, found) == PIRATE_TARGET_HOLD)
	controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, found)
	if(crew)
		crew.on_member_spotted(pawn, found)
	else if(ishumannpc(pawn))
		// A faction pirate met in a ruin or a contract, with no crew to tell
		var/mob/living/carbon/human/npc/loner = pawn
		loner.npc_bark(PIRATE_BARK_SPOT)

/datum/ai_planning_subtree/pirate_crew_find_target/proc/scan_for_target(datum/ai_controller/basic_controller/pirate_crew/controller, datum/pirate_crew/crew, datum/targeting_strategy/strategy, mob/living/basic/pawn, turf/pawn_turf)
	var/atom/best_player
	var/best_player_dist = INFINITY
	var/atom/best_other
	var/best_other_dist = INFINITY
	// Players inside a mech or a hiding place may not be among hearers(). A mech is fought as
	// itself; for the hiding places tg's find_hidden_mobs() knows, the attack behaviours go for
	// the container on their own.
	for(var/mob/living/player in GLOB.alive_player_list)
		var/atom/player_loc = player.loc
		if(!ismecha(player_loc) && !istype(player_loc, /obj/structure/closet) && !istype(player_loc, /obj/machinery/disposal) && !istype(player_loc, /obj/machinery/sleeper))
			continue
		var/atom/candidate = ismecha(player_loc) ? player_loc : player
		var/turf/candidate_turf = get_turf(candidate)
		if(!candidate_turf || candidate_turf.z != pawn_turf.z)
			continue
		var/dist = get_dist(pawn_turf, candidate_turf)
		if(dist > PIRATE_CREW_SIGHT_RANGE || dist >= best_player_dist)
			continue
		if(strategy.can_attack(pawn, candidate, PIRATE_CREW_SIGHT_RANGE) && target_reach(controller, crew, candidate) != PIRATE_TARGET_OUT)
			best_player = candidate
			best_player_dist = dist
	for(var/mob/living/candidate in hearers(PIRATE_CREW_SIGHT_RANGE, pawn_turf))
		if(candidate == pawn || candidate.stat == DEAD)
			continue
		var/dist = get_dist(pawn_turf, candidate)
		var/is_player = !!GET_CLIENT(candidate)
		if(dist >= (is_player ? best_player_dist : best_other_dist))
			continue
		if(!strategy.can_attack(pawn, candidate, PIRATE_CREW_SIGHT_RANGE) || target_reach(controller, crew, candidate) == PIRATE_TARGET_OUT)
			continue
		if(is_player)
			best_player = candidate
			best_player_dist = dist
		else
			best_other = candidate
			best_other_dist = dist
	return best_player || best_other

/**
 * How far the pawn may take a fight with `target`: chase it (PIRATE_TARGET_CHASE) when it's on the
 * battlefield or only just off it on solid ground, and within PIRATE_CREW_POST_LEASH of the helm
 * for the captain and the guard. Past that a gunner standing on the battlefield still shoots back
 * at a player from where it stands (PIRATE_TARGET_HOLD); anything else is let go (PIRATE_TARGET_OUT).
 * Nobody follows a target into space: a crewman adrift is lost to the crew (pirate_crew.dm).
 */
/datum/ai_planning_subtree/pirate_crew_find_target/proc/target_reach(datum/ai_controller/basic_controller/pirate_crew/controller, datum/pirate_crew/crew, atom/target)
	if(!crew)
		return PIRATE_TARGET_CHASE
	var/turf/target_turf = get_turf(target)
	if(!target_turf)
		return PIRATE_TARGET_OUT
	var/mob/living/pawn = controller.pawn
	var/fallback = PIRATE_TARGET_OUT
	if(pirate_crew_is_ranged(pawn) && crew.turf_on_battlefield(get_turf(pawn)) && pirate_crew_player_target(target))
		fallback = PIRATE_TARGET_HOLD
	if(crew.holds_post(pawn))
		var/turf/post = crew.post_for(pawn)
		if(post && (post.z != target_turf.z || get_dist(post, target_turf) > PIRATE_CREW_POST_LEASH))
			return fallback
	if(crew.turf_on_battlefield(target_turf))
		return PIRATE_TARGET_CHASE
	if(pirate_turf_is_void(target_turf))
		return fallback
	var/turf/edge = controller.last_battlefield_turf
	if(edge && edge.z == target_turf.z && get_dist(edge, target_turf) <= PIRATE_CREW_CHASE_MARGIN)
		return PIRATE_TARGET_CHASE
	return fallback

/// Whether `target` is a player, or a mech with one inside
/proc/pirate_crew_player_target(atom/target)
	if(ismob(target))
		var/mob/target_mob = target
		return !!GET_CLIENT(target_mob)
	if(ismecha(target))
		var/obj/vehicle/sealed/mecha/mech = target
		for(var/mob/occupant in mech.occupants)
			if(GET_CLIENT(occupant))
				return TRUE
	return FALSE

/**
 * Breaks through doors that won't open: one we walked into, or, when the pathfinder found no
 * way at all, the first one a search of the battlefield finds on the way. A search that finds
 * every door open but the route too long for one path leaves a waypoint for the hunt instead.
 */
/datum/ai_planning_subtree/pirate_crew_doors

/datum/ai_planning_subtree/pirate_crew_doors/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/datum/ai_controller/basic_controller/pirate_crew/pirate_controller = controller
	if(!istype(pirate_controller))
		return
	var/mob/living/basic/pawn = controller.pawn
	var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(controller.blackboard[BB_PIRATE_BREACH_TARGET] || controller.blackboard[BB_PIRATE_BREACH_TURF])
		if(keep_breaching(pirate_controller, pawn))
			// Someone in reach comes first
			if(pirate_controller.can_hit_now(target))
				return
			controller.queue_behavior(/datum/ai_behavior/pirate_crew_breach, BB_PIRATE_BREACH_TARGET, BB_PIRATE_BREACH_STAND)
			return SUBTREE_RETURN_FINISH_PLANNING
		pirate_controller.clear_breach()

	var/failed_at = controller.blackboard[BB_PIRATE_NO_PATH_AT]
	if(!failed_at || world.time > failed_at + PIRATE_CREW_NO_PATH_WINDOW)
		return
	if(!COOLDOWN_FINISHED(pirate_controller, breach_search_cooldown))
		return
	COOLDOWN_START(pirate_controller, breach_search_cooldown, PIRATE_CREW_BREACH_SEARCH_COOLDOWN)
	var/turf/goal = controller.blackboard[BB_PIRATE_NO_PATH_DEST]
	controller.clear_blackboard_key(BB_PIRATE_NO_PATH_AT)
	controller.clear_blackboard_key(BB_PIRATE_NO_PATH_DEST)
	var/datum/pirate_crew/crew = pirate_controller.get_crew()
	if(!goal || !crew)
		return
	var/list/result = pirate_crew_breach_search(pawn, get_turf(pawn), goal, crew.battlefield_areas, pirate_controller.skipped_doors)
	if(!result)
		// No way there at all; the hunt waits a moment before trying it again
		if(COOLDOWN_FINISHED(pirate_controller, no_way_log_cooldown))
			COOLDOWN_START(pirate_controller, no_way_log_cooldown, PIRATE_CREW_NO_WAY_LOG_COOLDOWN)
			log_shuttle("PIRATE_CREW: [pawn] found no way from [AREACOORD(pawn)] to [AREACOORD(goal)]")
		pirate_controller.unreachable_turf = goal
		pirate_controller.hunt_backoff_until = world.time + PIRATE_CREW_UNREACHABLE_BACKOFF
		return
	var/obj/blocker = result["door"]
	if(blocker)
		pirate_controller.start_breach(blocker, result["stand"])
		if(pirate_controller.can_hit_now(target))
			return
		controller.queue_behavior(/datum/ai_behavior/pirate_crew_breach, BB_PIRATE_BREACH_TARGET, BB_PIRATE_BREACH_STAND)
		return SUBTREE_RETURN_FINISH_PLANNING
	var/turf/waypoint = result["waypoint"]
	if(waypoint && result["length"] > PIRATE_CREW_WAYPOINT_STEPS)
		controller.set_blackboard_key(BB_PIRATE_WAYPOINT, waypoint)
		pirate_controller.waypoint_set_at = world.time

/// Whether the breach under way is still worth it. A door destroyed into a frame moves on to the frame.
/datum/ai_planning_subtree/pirate_crew_doors/proc/keep_breaching(datum/ai_controller/basic_controller/pirate_crew/controller, mob/living/basic/pawn)
	var/obj/blocker = controller.blackboard[BB_PIRATE_BREACH_TARGET]
	var/turf/stand = controller.blackboard[BB_PIRATE_BREACH_STAND]
	if(QDELETED(blocker) || !blocker.density)
		// The door is gone; the frame it left is just as much in the way
		var/turf/door_turf = controller.blackboard[BB_PIRATE_BREACH_TURF]
		blocker = null
		for(var/obj/structure/door_assembly/frame in door_turf)
			if(frame.density)
				blocker = frame
				break
		if(!blocker)
			return FALSE
		controller.set_blackboard_key(BB_PIRATE_BREACH_TARGET, blocker)
	if(istype(blocker, /obj/machinery/door) && pirate_can_open_door(pawn, blocker))
		return FALSE
	if(!pirate_door_breachable(blocker, stand))
		controller.skip_door(blocker)
		return FALSE
	// Given up once a stretch goes by with the door taking no damage at all: a human shooting a door
	// open takes longer than a basic mob smashing it, but gets somewhere.
	var/started = controller.blackboard[BB_PIRATE_BREACH_STARTED] || world.time
	if(blocker.atom_integrity < (controller.blackboard[BB_PIRATE_BREACH_INTEGRITY] || INFINITY))
		controller.set_blackboard_key(BB_PIRATE_BREACH_INTEGRITY, blocker.atom_integrity)
		controller.set_blackboard_key(BB_PIRATE_BREACH_PROGRESS_AT, world.time)
	var/progress_at = max(started, controller.blackboard[BB_PIRATE_BREACH_PROGRESS_AT])
	if(world.time > progress_at + PIRATE_CREW_BREACH_GIVE_UP)
		log_shuttle("PIRATE_CREW: [pawn] gave up breaking [blocker] at [AREACOORD(blocker)]")
		controller.skip_door(blocker)
		return FALSE
	if(blocker.z != pawn.z || get_dist(pawn, blocker) > PIRATE_CREW_SIGHT_RANGE * 2)
		return FALSE
	return TRUE

/// The captain and the guard stand at the helm while they hold the post
/datum/ai_planning_subtree/pirate_crew_hold_post

/datum/ai_planning_subtree/pirate_crew_hold_post/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/datum/pirate_crew/crew = controller.blackboard[BB_PIRATE_CREW]
	var/mob/living/pawn = controller.pawn
	if(QDELETED(crew) || !crew.holds_post(pawn))
		return
	var/turf/post = crew.post_for(pawn)
	if(!post)
		return
	if(post.z != pawn.z || get_dist(pawn, post) > 1)
		controller.set_blackboard_key(BB_PIRATE_POST_TURF, post)
		controller.queue_behavior(/datum/ai_behavior/pirate_crew_travel/post, BB_PIRATE_POST_TURF)
		return SUBTREE_RETURN_FINISH_PLANNING
	controller.queue_behavior(/datum/ai_behavior/pirate_crew_wait)
	return SUBTREE_RETURN_FINISH_PLANNING

/**
 * Alerted hunters with nothing in sight walk to wherever the crew last knew their quarry to be,
 * and wait there for the next sighting. Long routes go by way of a waypoint.
 */
/datum/ai_planning_subtree/pirate_crew_hunt

/datum/ai_planning_subtree/pirate_crew_hunt/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/datum/ai_controller/basic_controller/pirate_crew/pirate_controller = controller
	if(!istype(pirate_controller))
		return
	var/datum/pirate_crew/crew = pirate_controller.get_crew()
	var/mob/living/pawn = controller.pawn
	if(!crew?.alerted || crew.holds_post(pawn))
		return
	note_crossing(pirate_controller, crew, pawn)
	var/turf/known = crew.last_known_turf(controller.blackboard[BB_PIRATE_HUNT_TARGET])
	if(!known)
		controller.clear_blackboard_key(BB_PIRATE_HUNT_TURF)
		return
	var/turf/dest = controller.blackboard[BB_PIRATE_HUNT_TURF]
	var/arrived = dest && dest.z == pawn.z && get_dist(pawn, dest) <= 1
	// Only re-route mid-walk when the quarry has really moved; once there, follow it exactly
	if(!dest || dest.z != known.z || (arrived ? dest != known : get_dist(dest, known) > PIRATE_CREW_HUNT_REQUEUE_DIST))
		controller.set_blackboard_key(BB_PIRATE_HUNT_TURF, known)
		controller.clear_blackboard_key(BB_PIRATE_WAYPOINT)
		dest = known
		arrived = dest.z == pawn.z && get_dist(pawn, dest) <= 1
	if(arrived)
		controller.queue_behavior(/datum/ai_behavior/pirate_crew_wait)
		return SUBTREE_RETURN_FINISH_PLANNING
	var/turf/waypoint = controller.blackboard[BB_PIRATE_WAYPOINT]
	if(waypoint)
		if(waypoint.z == pawn.z && get_dist(pawn, waypoint) > 1 && world.time < pirate_controller.waypoint_set_at + PIRATE_CREW_WAYPOINT_TIMEOUT)
			controller.queue_behavior(/datum/ai_behavior/pirate_crew_travel/waypoint, BB_PIRATE_WAYPOINT)
			return SUBTREE_RETURN_FINISH_PLANNING
		controller.clear_blackboard_key(BB_PIRATE_WAYPOINT)
	// Found no way there a moment ago; wait instead of asking the pathfinder again straight away
	if(dest == pirate_controller.unreachable_turf && world.time < pirate_controller.hunt_backoff_until)
		controller.queue_behavior(/datum/ai_behavior/pirate_crew_wait)
		return SUBTREE_RETURN_FINISH_PLANNING
	controller.queue_behavior(/datum/ai_behavior/pirate_crew_travel/hunt, BB_PIRATE_HUNT_TURF)
	return SUBTREE_RETURN_FINISH_PLANNING

/// A defender stepping onto another ship's deck calls the others on
/datum/ai_planning_subtree/pirate_crew_hunt/proc/note_crossing(datum/ai_controller/basic_controller/pirate_crew/controller, datum/pirate_crew/crew, mob/living/pawn)
	if(crew.raiding || controller.crossed_over)
		return
	var/turf/here = get_turf(pawn)
	if(!here || crew.on_home_deck(here) || !crew.turf_on_battlefield(here))
		return
	controller.crossed_over = TRUE
	crew.on_member_crossed(pawn)

/// Pirates with nothing to do walk back onto the battlefield, and home once the crew stands down
/datum/ai_planning_subtree/pirate_crew_leash

/datum/ai_planning_subtree/pirate_crew_leash/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/datum/ai_controller/basic_controller/pirate_crew/pirate_controller = controller
	if(!istype(pirate_controller) || controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return
	var/datum/pirate_crew/crew = pirate_controller.get_crew()
	var/mob/living/pawn = controller.pawn
	var/turf/here = get_turf(pawn)
	if(!crew || !here)
		return
	var/turf/rest = crew.rest_turf_for(pawn)
	var/turf/back
	if(!crew.turf_on_battlefield(here))
		back = pirate_controller.last_battlefield_turf || rest
	else if(!crew.alerted && rest && (rest.z != here.z || get_dist(here, rest) > PIRATE_CREW_IDLE_LEASH))
		back = rest
	if(!back || back == here)
		return
	controller.set_blackboard_key(BB_PIRATE_RETURN_TURF, back)
	controller.queue_behavior(/datum/ai_behavior/pirate_crew_travel/leash, BB_PIRATE_RETURN_TURF)
	return SUBTREE_RETURN_FINISH_PLANNING

// ===== BEHAVIORS =====

/// Walks to the turf in `target_key`, following it if it changes
/datum/ai_behavior/pirate_crew_travel
	required_distance = 1
	action_cooldown = 0.5 SECONDS
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/pirate_crew_travel/setup(datum/ai_controller/controller, target_key)
	var/turf/destination = controller.blackboard[target_key]
	if(!isturf(destination))
		return FALSE
	set_movement_target(controller, destination)
	return TRUE

/datum/ai_behavior/pirate_crew_travel/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/turf/destination = controller.blackboard[target_key]
	if(!isturf(destination))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	if(controller.current_movement_target != destination)
		set_movement_target(controller, destination)
	if(destination.z == controller.pawn.z && get_dist(controller.pawn, destination) <= required_distance)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY

// One subtype per purpose, so switching from one walk to another starts the new one afresh
/datum/ai_behavior/pirate_crew_travel/hunt

/datum/ai_behavior/pirate_crew_travel/waypoint

/datum/ai_behavior/pirate_crew_travel/waypoint/finish_action(datum/ai_controller/controller, succeeded, target_key)
	. = ..()
	if(succeeded)
		controller.clear_blackboard_key(target_key)

/datum/ai_behavior/pirate_crew_travel/post

/datum/ai_behavior/pirate_crew_travel/leash

/datum/ai_behavior/pirate_crew_travel/leash/finish_action(datum/ai_controller/controller, succeeded, target_key)
	. = ..()
	controller.clear_blackboard_key(target_key)

/// Stands still and keeps planning, so a sighting is acted on at once
/datum/ai_behavior/pirate_crew_wait
	action_cooldown = 1 SECONDS
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/pirate_crew_wait/perform(seconds_per_tick, datum/ai_controller/controller)
	return AI_BEHAVIOR_DELAY

/// Walks to the door in `target_key`, standing on `stand_key`, and hits it until it opens or breaks
/datum/ai_behavior/pirate_crew_breach
	required_distance = 0
	action_cooldown = PIRATE_CREW_BREACH_COOLDOWN
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/pirate_crew_breach/setup(datum/ai_controller/controller, target_key, stand_key)
	var/obj/blocker = controller.blackboard[target_key]
	if(QDELETED(blocker) || !blocker.density)
		return FALSE
	var/turf/stand = controller.blackboard[stand_key] || get_turf(controller.pawn)
	set_movement_target(controller, stand)
	return TRUE

/datum/ai_behavior/pirate_crew_breach/perform(seconds_per_tick, datum/ai_controller/controller, target_key, stand_key)
	var/obj/blocker = controller.blackboard[target_key]
	var/mob/living/pawn = controller.pawn
	if(QDELETED(blocker) || !blocker.density)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	if(istype(blocker, /obj/machinery/door) && pirate_can_open_door(pawn, blocker))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	if(ishuman(pawn))
		// A person's hands: pry it, shoot it from a step back, or hit it (pirate_crew_human.dm)
		var/turf/stand = controller.blackboard[stand_key] || get_turf(pawn)
		var/turf/spot = pirate_crew_human_breach_spot(pawn, blocker, stand)
		if(controller.current_movement_target != spot)
			set_movement_target(controller, spot)
		if(get_turf(pawn) != spot && !(spot == stand && pawn.Adjacent(blocker)))
			return AI_BEHAVIOR_DELAY
		if(!pirate_crew_human_breach(controller, pawn, blocker))
			// Nothing it carries can hurt this door: leave it to someone who can
			var/datum/ai_controller/basic_controller/pirate_crew/pirate_controller = controller
			pirate_controller.skip_door(blocker)
			pirate_controller.clear_breach()
			return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
		return AI_BEHAVIOR_DELAY
	var/mob/living/basic/basic_pawn = pawn
	if(!isbasicmob(basic_pawn) || !basic_pawn.Adjacent(blocker))
		return AI_BEHAVIOR_DELAY
	basic_pawn.melee_attack(blocker)
	return AI_BEHAVIOR_DELAY
