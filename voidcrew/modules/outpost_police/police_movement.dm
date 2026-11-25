/**
 * How officers get past people in the way.
 *
 * Officers walk (tg walk intent) almost everywhere, and tg's MobBump() never swaps or pushes on walk intent, so two
 * officers meeting in a hall, or one standing paused in a doorway, blocked each other for good: the pathfinder plans
 * through mobs, and every repath gave the same blocked route. Here an officer walking into an outpost NPC passes it
 * the way two people on help intent do (a tg place swap), steps aside for an officer bringing someone in, asks the
 * NPC to step aside when it is the one bringing someone in, and plans a way around anyone who stays put for
 * POLICE_BLOCKED_REPATH. Players are never moved: tg's own rules apply to them.
 *
 * What an officer does about one of the outpost's own people in its way is all decided here, at a walk or a run. tg's
 * own bump is never asked: running (an alert, a search, a chase) it trades places with anyone not played, at every
 * step and with no memory of the last time, and shoves whoever it cannot trade with, so two officers after the same
 * tile traded places for as long as they both wanted it. With room to, the officer walks round whoever is in its
 * way (police_step_round()). A trade is for getting past someone in a place too narrow for that, once:
 * - never onto the tile the walk ends on (its destination, or as near what it walks to as the walk goes). That place
 *   is the other one's, and next to it will do; taking it only sends them walking back for it. (The officer making
 *   an arrest does take it, where there is no walking round to another tile beside its suspect: a scan chamber);
 * - never with someone walking somewhere themselves, unless they are walking straight into the officer (or
 *   strolling ahead of one on the run). They are out of the way in a step, and passing someone going the same way
 *   at the same pace only has them pass back;
 * - never with the officer making an arrest, who stands where the arrest needs it. It trades with whoever is in
 *   its own way;
 * - never twice by the same two within POLICE_SWAP_PAIR_GAP, whoever walks into whom. The one put off a spot it
 *   wanted waits or goes round. (The officer making an arrest is not held up by this.)
 * Too close to someone it is shooting at, an officer steps back only onto a free tile (outpost_police_step_back).
 *
 * A diagonal step is two straight ones, and nothing is settled part-way through one. Its pathfinder plans a diagonal
 * past someone standing on one leg of it even when the other leg is a wall, and plans it again every time: an officer
 * stood behind a colleague in a doorway for good that way. Walked into someone on a leg of a diagonal, it takes them
 * up straight a moment later (police_bump_straight()). And the way round a tile it asked its pathfinder for
 * (police_note_blocked()) is given up when it has not moved the officer in POLICE_BLOCKED_RESET: tg's pathfinder
 * keeps to that same diagonal, steps sideways to make it, and the sideways step can be into the wall
 * (remove_clunky_diagonals()).
 */

/// How long an officer keeps walking into the same person on the same tile before planning a way around them
#define POLICE_BLOCKED_REPATH (1.5 SECONDS)
/// A gap this long between bumps starts the wait over
#define POLICE_BLOCKED_RESET (3 SECONDS)
/// Least time between two place swaps by the same officer
#define POLICE_SWAP_COOLDOWN (1 SECONDS)
/// The same two never trade places twice within this long, whoever walks into whom
#define POLICE_SWAP_PAIR_GAP (10 SECONDS)
/// Someone with a walk of their own who moved a tile this recently is on the move, and is not traded places with
#define POLICE_WALKING_ON (1 SECONDS)
/// Least time between two straight tries at someone it walked into on a leg of a diagonal step
#define POLICE_STRAIGHT_BUMP_GAP (0.5 SECONDS)

/mob/living/carbon/human/npc/ambient_npc/outpost/police
	/// Who this officer last walked into and could not pass (police_movement.dm)
	var/datum/weakref/bump_blocker
	/// Where they stood
	var/turf/bump_blocked_turf
	/// When the officer first walked into them there
	var/bump_blocked_since = 0
	/// When the officer last walked into them
	var/bump_last = 0
	COOLDOWN_DECLARE(police_swap_cooldown)
	/// REF of whoever it traded places with -> world.time it did (police_note_trade())
	var/list/traded_with
	/// world.time it may next take someone it walked into on a diagonal up straight (police_diagonal_blocked())
	var/bump_straight_at = 0

/mob/living/carbon/human/npc/ambient_npc/outpost/police/MobBump(mob/M)
	if(client || mind || !isliving(M) || stat != CONSCIOUS)
		return ..()
	// One of the outpost's people, nobody playing them: settled here, never by tg's own swap and shove (see the top)
	if(istype(M, /mob/living/carbon/human/npc) && !M.client && !M.mind)
		if(!police_make_room(M))
			police_note_blocked(M)
			police_diagonal_blocked(M)
		return TRUE
	// The person it leads by the arm is in its own way (a lane one tile wide, rails either side): it steps past them,
	// trading places, as tg lets anyone do with whoever they pull. tg's bump does nothing at a walk, and an officer
	// walking its prisoner out of the Undertow's queue lane stood facing them for good.
	if(pulling == M && !moving_diagonally && COOLDOWN_FINISHED(src, police_swap_cooldown) && !LAZYLEN(do_afters))
		COOLDOWN_START(src, police_swap_cooldown, POLICE_SWAP_COOLDOWN)
		if(pirate_crew_swap_places(src, M))
			return TRUE
	// Someone with an arrest on them and not yet held is never traded places with or pushed along: the officer comes
	// to a stop by them, or finds a way round. (tg's bump has a running NPC swap with anyone not in combat mode, which
	// walked the arresting officer through the person it was coming to cuff.)
	var/mob/living/bumped = M
	if(police?.arrest_on(bumped) && !police.in_custody(bumped))
		police_note_blocked(M)
		police_diagonal_blocked(M)
		return TRUE
	var/turf/before = get_turf(src)
	. = ..()
	if(get_turf(src) == before)
		police_note_blocked(M)
		police_diagonal_blocked(M)

/// Walked into `blocker` on one leg of a diagonal step, where nothing is settled: a tick later they are taken up straight
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_diagonal_blocked(mob/living/blocker)
	if(!moving_diagonally || world.time < bump_straight_at)
		return
	bump_straight_at = world.time + POLICE_STRAIGHT_BUMP_GAP
	addtimer(CALLBACK(src, PROC_REF(police_bump_straight), WEAKREF(blocker)), 1)

/**
 * The straight try at someone it walked into on a leg of a diagonal step: beside them still, and still walking, it
 * settles it with one of the outpost's people by the rules above (round them, or a trade of places), and walks
 * straight into anyone else as tg has it. Its pathfinder would only plan the same diagonal again.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_bump_straight(datum/weakref/blocker_ref)
	var/mob/living/blocker = blocker_ref?.resolve()
	if(QDELETED(blocker) || QDELETED(src) || client || mind || stat != CONSCIOUS || moving_diagonally || now_pushing || !isturf(loc) || !isturf(blocker.loc))
		return
	var/way = get_dir(src, blocker)
	if(!way || (way & (way - 1)) || get_dist(src, blocker) != 1)
		return
	var/datum/move_loop/loop = GLOB.move_manager.processing_on(src, SSai_movement)
	if(isnull(loop) || !(loop.status & MOVELOOP_STATUS_RUNNING) || (loop.status & MOVELOOP_STATUS_PAUSED))
		return
	if(istype(blocker, /mob/living/carbon/human/npc) && !blocker.client && !blocker.mind)
		if(!police_make_room(blocker))
			police_bump_other_leg(way)
	else
		Move(get_turf(blocker), way)

/**
 * The one it took up straight on a leg of its diagonal could not make way (seated, held), nor could it walk round
 * them: whoever stands on the diagonal's other leg is taken up straight instead. Only the first leg's blocker ever
 * was (POLICE_STRAIGHT_BUMP_GAP), and an officer at the Undertow's tables stood behind a seated patron for good with a
 * townsperson it could have passed on the other leg (pass 13 soak, hangar_wait).
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_bump_other_leg(tried_way)
	var/turf/here = get_turf(src)
	var/turf/next = outpost_npc_path_next(src)
	if(isnull(here) || isnull(next) || next.z != here.z || get_dist(here, next) != 1)
		return FALSE
	var/diagonal = get_dir(here, next)
	if(!(diagonal & (diagonal - 1)) || !(diagonal & tried_way))
		return FALSE
	var/turf/other_leg = get_step(here, diagonal & ~tried_way)
	for(var/mob/living/other in other_leg)
		if(other != src && istype(other, /mob/living/carbon/human/npc) && !other.client && !other.mind)
			return police_make_room(other)
	return FALSE

/**
 * `other`, an outpost NPC, is in this officer's way. An officer bringing someone in has the NPC step aside; an
 * officer meeting someone else bringing someone in steps aside for them; otherwise it walks round them if there is
 * room, or the two trade places by the rules at the top of this file. TRUE when the officer or the NPC moved, FALSE
 * when nothing did.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_make_room(mob/living/other)
	if(now_pushing || buckled)
		return FALSE
	var/they_can_move = outpost_npc_can_make_room(other)
	// Bringing someone in: the other one makes way
	if(isliving(pulling))
		return they_can_move && outpost_npc_step_aside(other, src, list())
	// They are bringing someone in: we make way
	if(isliving(other.pulling))
		return they_can_move && outpost_npc_step_aside(src, other, list())
	if(pulling || other.pulling)
		return FALSE
	// Partway through a diagonal step nothing is settled (tg MobBump() trades no places then either): the step is taken
	// the other way round, or straight at them next time
	if(moving_diagonally)
		return FALSE
	// Where they stand is where this walk ends: the place is theirs. A tile beside them that is as good will do, and
	// with none, next to them will. Room to walk round them otherwise: round them it goes
	var/ends_here = police_walk_ends_on(get_turf(other))
	if(police_step_round(other, ends_here))
		return TRUE
	// Except for the officer making an arrest, with no other tile beside its suspect to be had (a scan chamber, a
	// doorway): the place of whoever stands there and is not making one is its to trade for, or the cuffs never go on
	if(ends_here && !outpost_police_making_arrest(src))
		return FALSE
	if(!they_can_move || outpost_police_making_arrest(other))
		return FALSE
	// They are walking somewhere themselves, and not into us: out of the way in a step. (Someone strolling ahead of
	// an officer on the run is passed.)
	var/turf/their_next = outpost_npc_next_step(other)
	if(their_next && their_next != get_turf(src) && (move_intent != MOVE_INTENT_RUN || other.move_intent == MOVE_INTENT_RUN))
		return FALSE
	// The same two do not trade again for a while: the one put off its spot waits or goes round
	if(police_traded_lately(other) && !outpost_police_making_arrest(src))
		return FALSE
	if(!COOLDOWN_FINISHED(src, police_swap_cooldown) || LAZYLEN(other.do_afters))
		return FALSE
	COOLDOWN_START(src, police_swap_cooldown, POLICE_SWAP_COOLDOWN)
	if(!pirate_crew_swap_places(src, other))
		// Someone who may not take this tile (one at work keeps to their own corner, never a doorway:
		// outpost_ambient_work.dm on_pre_move()) steps aside instead. The Undertow's barback, wiping down in front of Bar
		// Access, refused the trade every second and the officer stood in the doorway (pass 14 soak, crowded_gate).
		return outpost_npc_step_aside(other, src, list())
	police_note_trade(other)
	return TRUE

/**
 * Walks round `other`, who is straight ahead: one step onto a free tile beside them, past a free tile beside us, as
 * anyone walks round someone standing in a hall. Never into a doorway, an exit gate or the checkpoint's chamber, and
 * never where a rail or a counter is in the way. `to_walk_end`: only onto a tile this walk ends on too (another tile
 * beside the suspect it is closing on). TRUE if it moved.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_step_round(mob/living/other, to_walk_end = FALSE)
	var/turf/here = get_turf(src)
	var/turf/there = get_turf(other)
	if(isnull(here) || isnull(there) || !isturf(loc) || !(mobility_flags & MOBILITY_MOVE))
		return FALSE
	var/way = get_dir(here, there)
	if(!way || (way & (way - 1)) || get_dist(here, there) != 1)
		return FALSE
	var/turf/walking_to = get_turf(ai_controller?.current_movement_target)
	var/turf/best
	var/best_side
	var/best_distance = INFINITY
	for(var/turn_by in list(45, -45))
		var/side = turn(way, turn_by)
		var/turf/beside_us = get_step(here, turn(way, turn_by * 2))
		var/turf/beside_them = get_step(here, side)
		if(isnull(beside_us) || isnull(beside_them) || !police_step_round_ok(here, beside_us) || !police_step_round_ok(beside_us, beside_them))
			continue
		if(to_walk_end && !police_walk_ends_on(beside_them))
			continue
		var/distance = (walking_to && walking_to.z == beside_them.z) ? get_dist(beside_them, walking_to) : 0
		if(distance < best_distance)
			best = beside_them
			best_side = side
			best_distance = distance
	if(isnull(best))
		return FALSE
	Move(best, best_side)
	return get_turf(src) != here

/// Whether a step from `from` onto `spot` is one for walking round someone: free of people and things, a clear step, no doorway, gate or chamber
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_step_round_ok(turf/from, turf/spot)
	if(spot.is_blocked_turf(exclude_mobs = FALSE, source_atom = src) || !outpost_police_way_step_ok(from, spot))
		return FALSE
	if((locate(/obj/machinery/door) in spot) || (locate(/obj/structure/outpost_exit_gate) in spot) || (locate(/obj/effect/landmark/outpost_checkpoint_chamber) in spot))
		return FALSE
	return isopenturf(spot) && !isspaceturf(spot) && !isgroundlessturf(spot) && !islava(spot) && !ischasm(spot)

/**
 * Whether standing on `tile` would be the end of this officer's walk: the tile it is walking to, or as near to what
 * it is walking to as the walk goes (beside a suspect it is closing on, within reach of the officer it covers).
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_walk_ends_on(turf/tile)
	var/datum/ai_controller/brain = ai_controller
	var/atom/walking_to = brain?.current_movement_target
	if(isnull(tile) || QDELETED(walking_to))
		return FALSE
	var/turf/walk_end = get_turf(walking_to)
	if(isnull(walk_end) || walk_end.z != tile.z)
		return FALSE
	return tile == walk_end || get_dist(tile, walk_end) <= (brain.blackboard[BB_CURRENT_MIN_MOVE_DISTANCE] || 0)

/// Whether `who` is the officer making an arrest (its case's arresting officer): it stands where the arrest needs it
/proc/outpost_police_making_arrest(mob/living/who)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = who
	return istype(officer) && !QDELETED(officer.case) && officer.case.arresting() == officer

/// Whether this officer and `other` traded places within POLICE_SWAP_PAIR_GAP
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_traded_lately(mob/living/other)
	var/when = LAZYACCESS(traded_with, REF(other))
	return when && world.time - when < POLICE_SWAP_PAIR_GAP

/// This officer and `other` have just traded places: both of them remember it
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_note_trade(mob/living/other)
	for(var/key in traded_with)
		if(world.time - traded_with[key] >= POLICE_SWAP_PAIR_GAP)
			traded_with -= key
	LAZYSET(traded_with, REF(other), world.time)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/colleague = other
	if(istype(colleague))
		LAZYSET(colleague.traded_with, REF(src), world.time)

/**
 * The tile `walker`'s own walk takes them onto next, or null when they are not walking anywhere: the next tile of a
 * path they follow, or a step straight at something they are not yet near enough to. One of the outpost's people who
 * has not moved a tile in POLICE_WALKING_ON is not walking, whatever their path says: they are held up themselves.
 */
/proc/outpost_npc_next_step(mob/living/walker)
	var/datum/move_loop/has_target/loop = GLOB.move_manager.processing_on(walker, SSai_movement)
	if(!istype(loop) || !(loop.status & MOVELOOP_STATUS_RUNNING) || (loop.status & MOVELOOP_STATUS_PAUSED))
		return null
	var/mob/living/carbon/human/npc/ambient_npc/outpost/local = walker
	if(istype(local) && world.time - local.last_step_at > POLICE_WALKING_ON)
		return null
	var/datum/move_loop/has_target/jps/path_loop = loop
	if(istype(path_loop))
		return length(path_loop.movement_path) ? path_loop.movement_path[1] : null
	var/datum/move_loop/has_target/dist_bound/straight_loop = loop
	if(istype(straight_loop) && !QDELETED(straight_loop.target) && get_dist(walker, straight_loop.target) > straight_loop.distance)
		return get_step_towards(walker, straight_loop.target)
	return null

// On an arrest or riding a lift an officer goes where it must (outpost_doorways.dm)
/mob/living/carbon/human/npc/ambient_npc/outpost/police/doorway_manners()
	if(case || dispatch_riding)
		return FALSE
	return ..()

// One of the outpost's own people beyond a door is no reason to wait outside it: an officer gets past them by the rules
// above (round them, or a trade of places), where two townspeople would only stand and look at each other
/mob/living/carbon/human/npc/ambient_npc/outpost/police/doorway_waits_for(mob/living/someone)
	return !istype(someone, /mob/living/carbon/human/npc) || someone.client || someone.mind

// On an arrest, or with someone to fight, an officer stands where it must
/mob/living/carbon/human/npc/ambient_npc/outpost/police/doorway_can_leave()
	if(case || dispatch_riding || !QDELETED(ai_controller?.blackboard[BB_BASIC_MOB_CURRENT_TARGET]))
		return FALSE
	return ..()

// =========================================================================
// THE PATHFINDER, ALWAYS
// =========================================================================

/**
 * An officer chases by its pathfinder too (police_stealth.dm, stealth_set_state()). Stealth's guards are put back on
 * tg's straight chase whenever a walk of theirs ends on an alert (stealth_goto's finish_action()); an officer that
 * had walked to where it last saw someone then went at them in a straight line again, pushing at the queue rails and
 * the lockers (owner playtest 3). Asked for the straight chase, an officer's brain keeps its pathfinder.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/change_ai_movement_type(datum/ai_movement/new_movement)
	if(ispath(new_movement, /datum/ai_movement/basic_avoidance/stealth))
		new_movement = /datum/ai_movement/jps/stealth
	return ..()

// =========================================================================
// A STEP BACK
// =========================================================================

/**
 * One step back from a target too close to shoot at, onto a tile with nobody on it. tg's step_away
 * (maintain_distance.dm) only looks for walls and furniture: it backs into whoever stands behind, which between two
 * officers was a trade of places that put the other one too close in turn, and so on back and forth. With no free
 * tile to step to it stays where it is and shoots from there.
 */
/datum/ai_behavior/outpost_police_step_back
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION
	required_distance = 0
	action_cooldown = 0.2 SECONDS

/datum/ai_behavior/outpost_police_step_back/setup(datum/ai_controller/controller, target_key)
	. = ..()
	var/atom/target = controller.blackboard[target_key]
	var/mob/living/officer = controller.pawn
	if(QDELETED(target) || !isliving(officer))
		return FALSE
	var/turf/spot = outpost_police_step_back_spot(officer, target)
	if(isnull(spot))
		return FALSE
	officer.face_atom(target)
	// The walk its pathfinder was on is stopped with it: left alone, the pathfinder goes on believing it is walking
	// there, and never sets off for the same target again
	human_npc_set_ai_movement(controller, /datum/ai_movement/basic_avoidance/backstep)
	set_movement_target(controller, spot)

/datum/ai_behavior/outpost_police_step_back/perform(seconds_per_tick, datum/ai_controller/controller)
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/outpost_police_step_back/finish_action(datum/ai_controller/controller, succeeded)
	. = ..()
	human_npc_set_ai_movement(controller, initial(controller.ai_movement))

/**
 * The tile `officer` steps back onto from `target`: straight away from it, else to either side of that. Further from
 * the target than it stands now, with nobody and nothing on it, a clear step to it, and no doorway. Null if none.
 */
/proc/outpost_police_step_back_spot(mob/living/officer, atom/target)
	var/turf/here = get_turf(officer)
	var/turf/from = get_turf(target)
	if(isnull(here) || isnull(from) || here.z != from.z || !isturf(officer.loc))
		return null
	var/away = get_dir(from, here) || REVERSE_DIR(officer.dir)
	var/gap = here == from ? 0 : get_dist(here, from)
	for(var/direction in list(away, turn(away, 45), turn(away, -45)))
		var/turf/spot = get_step(here, direction)
		if(isnull(spot) || get_dist(spot, from) <= gap || outpost_doorway_of(spot))
			continue
		if(spot.is_blocked_turf(exclude_mobs = FALSE, source_atom = officer) || !outpost_police_way_step_ok(here, spot))
			continue
		return spot
	return null

/**
 * The officer walked into `blocker` and could not pass. After POLICE_BLOCKED_REPATH of walking into the same person
 * on the same tile, the officer's path is planned again around that tile, as a mulebot does.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_note_blocked(mob/living/blocker)
	var/turf/blocked_at = get_turf(blocker)
	if(!blocked_at)
		return
	if(bump_blocker?.resolve() != blocker || bump_blocked_turf != blocked_at || world.time - bump_last > POLICE_BLOCKED_RESET)
		bump_blocker = WEAKREF(blocker)
		bump_blocked_turf = blocked_at
		bump_blocked_since = world.time
	bump_last = world.time
	if(world.time - bump_blocked_since < POLICE_BLOCKED_REPATH)
		return
	var/datum/move_loop/has_target/jps/loop = GLOB.move_manager.processing_on(src, SSai_movement)
	if(!istype(loop) || loop.avoid == blocked_at || get_turf(loop.target) == blocked_at)
		return
	loop.avoid = blocked_at
	// The next step plans again, with the tile left out
	loop.movement_path = null
	addtimer(CALLBACK(src, PROC_REF(police_avoid_check), blocked_at, get_turf(src)), POLICE_BLOCKED_RESET)

/// The way round `avoided` it asked its pathfinder for has not moved it off `stood_at`: the tile is given back, and it walks at whoever stands there again
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_avoid_check(turf/avoided, turf/stood_at)
	if(QDELETED(src) || get_turf(src) != stood_at)
		return
	var/datum/move_loop/has_target/jps/loop = GLOB.move_manager.processing_on(src, SSai_movement)
	if(!istype(loop) || loop.avoid != avoided)
		return
	loop.avoid = null
	loop.movement_path = null
	bump_blocked_since = world.time

/**
 * Whether `blocker`, an outpost NPC, can take a step out of someone's way: up, free and not held, and not a trader at
 * their post or an officer riding the lift. A wave forming up at the lift, or an NPC idling with nobody near
 * (paused for performance), still moves; any other pause holds them.
 */
/proc/outpost_npc_can_make_room(mob/living/blocker)
	if(!istype(blocker, /mob/living/carbon/human/npc) || blocker.client || blocker.mind || blocker.stat != CONSCIOUS)
		return FALSE
	if(blocker.buckled || blocker.pulledby || blocker.has_buckled_mobs() || HAS_TRAIT(blocker, TRAIT_RESTRAINED) || HAS_TRAIT(blocker, TRAIT_INCAPACITATED) || blocker.has_status_effect(/datum/status_effect/grouped/heldup))
		return FALSE
	if(HAS_TRAIT(blocker, TRAIT_AI_PAUSED))
		// "outpost_police_wave" is POLICE_WAVE_TRAIT (police_dispatch.dm keeps it to itself)
		var/static/list/movable_pauses = list(AMBIENT_PAUSED_TRAIT, "outpost_police_wave")
		if(length(GET_TRAIT_SOURCES(blocker, TRAIT_AI_PAUSED) - movable_pauses))
			return FALSE
	if(!(blocker.mobility_flags & MOBILITY_MOVE) || blocker.body_position == LYING_DOWN || blocker.moving_diagonally)
		return FALSE
	var/mob/living/carbon/human/npc/ambient_npc/ambient_blocker = blocker
	if(istype(ambient_blocker))
		if(ambient_blocker.fading)
			return FALSE
		if(istype(ambient_blocker, /mob/living/carbon/human/npc/ambient_npc/outpost/trader) && get_turf(ambient_blocker) == ambient_blocker.home)
			return FALSE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer_blocker = blocker
	if(istype(officer_blocker) && officer_blocker.dispatch_riding)
		return FALSE
	return TRUE

// =========================================================================
// GIVING WAY TO AN ESCORT
// =========================================================================

/**
 * One of the outpost's people who stepped out of the way of someone bringing a person in stays out of it: for
 * OUTPOST_GIVE_WAY_HOLD, while the escort is within OUTPOST_GIVE_WAY_RANGE with someone still in hand (led, or held
 * for the cuffs), their own walk or run does not take them back onto the tile they stepped off or any nearer the escort. They wait where they stepped
 * to, or their pathfinder finds another way. A beat officer whose patrol ran past an escort standing at the desk
 * stepped aside, walked straight back into its way, and was stepped aside again, three times in fifteen seconds
 * (pass 2 soak, Halcyon hangar_wait).
 */

/// How long one of the outpost's people who gave way to an escort keeps out of its way
#define OUTPOST_GIVE_WAY_HOLD (5 SECONDS)
/// The escort is out of the way once this far off
#define OUTPOST_GIVE_WAY_RANGE 2

/mob/living/carbon/human/npc/ambient_npc/outpost
	/// The escort they last stepped out of the way of (police_movement.dm)
	var/datum/weakref/gave_way_to
	/// The tile they stepped off for it
	var/turf/gave_way_from
	/// world.time they may walk back into its way
	var/gave_way_until = 0

/// `blocker` stepped off `from` out of `walker`'s way (outpost_npc_step_aside()). Always TRUE.
/proc/outpost_npc_gave_way(mob/living/blocker, mob/living/walker, turf/from)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/local = blocker
	if(istype(local) && isliving(walker?.pulling))
		local.gave_way_to = WEAKREF(walker)
		local.gave_way_from = from
		local.gave_way_until = world.time + OUTPOST_GIVE_WAY_HOLD
	return TRUE

/// Whether a step of their own onto `newloc` would take them back into the way of the escort they gave way to
/mob/living/carbon/human/npc/ambient_npc/outpost/proc/give_way_holds(turf/newloc)
	if(!gave_way_until)
		return FALSE
	var/mob/living/escort = gave_way_to?.resolve()
	if(world.time >= gave_way_until || QDELETED(escort) || !isliving(escort.pulling) || escort.z != z || get_dist(escort, src) > OUTPOST_GIVE_WAY_RANGE)
		gave_way_to = null
		gave_way_from = null
		gave_way_until = 0
		return FALSE
	// Their own walk only: dragged, shoved, thrown, or partway through a trade of places, they go where they are taken
	if(!isturf(newloc) || !isturf(loc) || client || mind || pulledby || buckled || throwing || (pass_flags & PASSMOB))
		return FALSE
	return newloc == gave_way_from || get_dist(newloc, escort) < get_dist(loc, escort)

/mob/living/carbon/human/npc/ambient_npc/outpost/own_step_allowed(atom/newloc)
	. = ..()
	if(. && give_way_holds(newloc))
		return FALSE

// Put somewhere else (carried, thrown, moved by a script), the meeting with that escort is over
/mob/living/carbon/human/npc/ambient_npc/outpost/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(forced && gave_way_until)
		gave_way_to = null
		gave_way_from = null
		gave_way_until = 0

// On an arrest, riding a lift, or with someone to fight, an officer goes where it must. (One running to search a spot
// is held: at the Undertow's checkpoint a searcher sent to the suspect's tile was stepped aside by the officer cuffing
// them and ran straight back, three times in fifteen seconds.)
/mob/living/carbon/human/npc/ambient_npc/outpost/police/give_way_holds(turf/newloc)
	if(case || dispatch_riding || !QDELETED(ai_controller?.blackboard[BB_BASIC_MOB_CURRENT_TARGET]))
		return FALSE
	return ..()

#undef OUTPOST_GIVE_WAY_HOLD
#undef OUTPOST_GIVE_WAY_RANGE

// =========================================================================
// THE EXIT GATE WITH SOMEONE IN HAND
// =========================================================================

/**
 * An officer bringing someone through an exit gate lines up square with it first: the walk goes to the tile in front
 * of the gate, then straight through, with the person in hand a step behind. Cutting through it on a diagonal left the
 * person a knight's move behind as the gate carried the officer on, and the pull broke on the wrong side of a one-way
 * gate. Returns the tile to walk to: the officer's own tile while waiting (or once on the gate, which carries them on).
 */
/proc/outpost_police_gate_lineup(mob/living/officer, obj/structure/outpost_exit_gate/gate)
	var/turf/here = get_turf(officer)
	var/turf/gate_turf = get_turf(gate)
	if(!here || !gate_turf || here.z != gate_turf.z)
		return null
	if(here == gate_turf)
		return here
	var/turf/front = get_step(gate_turf, REVERSE_DIR(gate.dir))
	if(!front)
		return null
	var/mob/living/towed = isliving(officer.pulling) ? officer.pulling : null
	if(here != front)
		// The person in hand is standing on the tile in front: the puller trades places with them, as tg lets a puller do
		if(towed && get_turf(towed) == front && here.Adjacent(front) && !officer.moving_diagonally)
			pirate_crew_swap_places(officer, towed)
			return get_turf(officer)
		return front
	// In front of the gate: once the person in hand is beside us, straight on through
	if(towed && !officer.Adjacent(towed))
		return here
	officer.Move(gate_turf, gate.dir)
	return get_turf(officer)

/// The exit gate an officer at `from` walks someone out through: the nearest one whose near side is the concourse
/datum/outpost_police/proc/escort_exit_gate(turf/from)
	if(!from || !outpost)
		return null
	if(!length(exit_gates))
		exit_gates = list()
		var/turf/corner = outpost.template_bottom_left
		var/datum/map_template/template = outpost.outpost_template
		if(corner && template)
			var/turf/far_corner = locate(min(world.maxx, corner.x + template.width - 1), min(world.maxy, corner.y + template.height - 1), corner.z)
			for(var/turf/tile as anything in block(corner, far_corner))
				var/obj/structure/outpost_exit_gate/gate = locate() in tile
				if(gate)
					exit_gates += gate
	var/obj/structure/outpost_exit_gate/best
	var/best_dist = INFINITY
	for(var/obj/structure/outpost_exit_gate/gate as anything in exit_gates)
		if(QDELETED(gate) || gate.z != from.z)
			continue
		var/turf/front = get_step(gate, REVERSE_DIR(gate.dir))
		if(!front || sector_of(front) != POLICE_SECTOR_CONCOURSE)
			continue
		var/dist = get_dist(from, gate)
		if(dist < best_dist)
			best = gate
			best_dist = dist
	return best

/datum/outpost_police
	/// The outpost's exit gates, found once (police_movement.dm)
	var/list/obj/structure/outpost_exit_gate/exit_gates

#undef POLICE_BLOCKED_REPATH
#undef POLICE_BLOCKED_RESET
#undef POLICE_SWAP_COOLDOWN
#undef POLICE_SWAP_PAIR_GAP
#undef POLICE_WALKING_ON
#undef POLICE_STRAIGHT_BUMP_GAP
