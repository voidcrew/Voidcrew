/**
 * # Outpost NPCs and doorways
 *
 * None of a trader outpost's people stands in a doorway (an airlock's tile; the checkpoint's doors are airlocks).
 * Someone standing in one held the checkpoint's chamber open and its queue out, and shut a shop off. Two rules, both
 * on steps of their own:
 *
 * - At a walk they do not step into a doorway while someone stands on the tile beyond it. They wait in front of the
 *   door until the way through is clear, so they walk straight through (doorway_step_ok()). Running (a fight, an
 *   alarm, a chase), pulled, or with someone in hand, they go where they must.
 * - One left standing in a doorway all the same (the way on was shut in front of them, or their walk ended there)
 *   steps off it after OUTPOST_DOORWAY_LINGER: on through if that tile is free, else back the way they came
 *   (leave_doorway()). One put there (dragged, shoved, carried) steps to the side nearer where they belong. Someone
 *   who cannot move, is held, or is at work on something stays; they are looked at again. Someone at what they are
 *   doing (a medic over a body that lies by a door) only steps to a tile they can go on doing it from.
 *
 * Their routines never send them to stand in one either (standable(), outpost_patrons.dm).
 */

/// How long one of the outpost's people may stand in a doorway before they step off it
#define OUTPOST_DOORWAY_LINGER (1.5 SECONDS)

/// The airlock whose doorway `tile` is, or null
/proc/outpost_doorway_of(turf/tile)
	return tile ? (locate(/obj/machinery/door/airlock) in tile) : null

/mob/living/carbon/human/npc/ambient_npc/outpost
	/// The tile they stepped into a doorway from, by a step of their own (leave_doorway() goes on from it, or back to it)
	var/turf/doorway_from
	/// world.time they last moved a tile (police_movement.dm: someone on the move is not traded places with)
	var/last_step_at = 0
	/// The timer that looks at them again while they stand in a doorway
	var/doorway_timer

/mob/living/carbon/human/npc/ambient_npc/outpost/Destroy()
	deltimer(doorway_timer)
	doorway_timer = null
	doorway_from = null
	return ..()

/// Whether they mind who is beyond a door before stepping into it: walking about by themselves, nobody in hand, nobody holding them
/mob/living/carbon/human/npc/ambient_npc/outpost/proc/doorway_manners()
	if(client || mind || stat != CONSCIOUS || move_intent != MOVE_INTENT_WALK)
		return FALSE
	// PASSMOB: partway through trading places with someone (police_movement.dm)
	if(pulling || pulledby || buckled || throwing || (pass_flags & PASSMOB) || !isturf(loc))
		return FALSE
	return TRUE

/// Whether a step of their own onto `newloc` leaves them free to walk on: into a doorway only with nobody standing on the tile beyond it
/mob/living/carbon/human/npc/ambient_npc/outpost/proc/doorway_step_ok(turf/newloc)
	var/turf/here = loc
	if(!isturf(newloc) || !isturf(here) || newloc == here || !outpost_doorway_of(newloc))
		return TRUE
	var/way = get_dir(here, newloc)
	// A diagonal step is taken as two straight ones, each asked about here
	if(way & (way - 1))
		return TRUE
	var/turf/beyond = get_step(newloc, way)
	if(!beyond)
		return TRUE
	for(var/mob/living/someone in beyond)
		// One of the townspeople waiting to come through this door the other way is passed in it (outpost_head_on_pass())
		if(someone != src && someone.density && doorway_waits_for(someone) && !(outpost_townsperson(someone) && outpost_npc_path_next(someone) == newloc))
			return FALSE
	return TRUE

/// Whether `someone`, standing just beyond a door, keeps them from stepping into its doorway. Override for those who can get past people.
/mob/living/carbon/human/npc/ambient_npc/outpost/proc/doorway_waits_for(mob/living/someone)
	return TRUE

/mob/living/carbon/human/npc/ambient_npc/outpost/own_step_allowed(atom/newloc)
	. = ..()
	if(. && doorway_manners())
		return doorway_step_ok(newloc)

/mob/living/carbon/human/npc/ambient_npc/outpost/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	last_step_at = world.time
	if(doorway_timer)
		deltimer(doorway_timer)
		doorway_timer = null
	if(!isturf(loc) || !outpost_doorway_of(loc))
		doorway_from = null
		return
	// Where they came from counts only when they walked in themselves: dragged or shoved in, they go back where they belong
	if(forced || pulledby || throwing || !isturf(old_loc) || get_dist(old_loc, loc) != 1)
		doorway_from = null
	else if(!outpost_doorway_of(old_loc))
		doorway_from = old_loc
	watch_doorway()

/// Looks at them again in OUTPOST_DOORWAY_LINGER if they stand in a doorway
/mob/living/carbon/human/npc/ambient_npc/outpost/proc/watch_doorway()
	if(doorway_timer || QDELETED(src) || stat == DEAD || !isturf(loc) || !outpost_doorway_of(loc))
		return
	doorway_timer = addtimer(CALLBACK(src, PROC_REF(leave_doorway), loc), OUTPOST_DOORWAY_LINGER, TIMER_STOPPABLE | TIMER_DELETE_ME)

// Held still in a doorway with nobody at the outpost: they step off it when someone comes
/mob/living/carbon/human/npc/ambient_npc/outpost/resume_routine()
	. = ..()
	watch_doorway()

/// Whether stepping off a doorway is theirs to do now: up, free, their own, and not in the middle of something
/mob/living/carbon/human/npc/ambient_npc/outpost/proc/doorway_can_leave()
	if(client || mind || stat != CONSCIOUS || fading || body_position == LYING_DOWN || !(mobility_flags & MOBILITY_MOVE))
		return FALSE
	if(buckled || pulledby || isliving(pulling) || LAZYLEN(do_afters) || HAS_TRAIT(src, TRAIT_INCAPACITATED) || HAS_TRAIT(src, TRAIT_RESTRAINED))
		return FALSE
	return TRUE

/**
 * Still standing in the doorway `tile` after OUTPOST_DOORWAY_LINGER: they step off it, on through if that tile is
 * free, else back the way they came. One who did not walk in (dragged, shoved, put there) steps to the free side
 * nearer their home. Never into another doorway. Boxed in from behind by one of the outpost's people, that one
 * makes room. While they cannot or may not move they are looked at again.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/proc/leave_doorway(turf/tile)
	doorway_timer = null
	if(QDELETED(src) || stat == DEAD || loc != tile || !outpost_doorway_of(tile))
		return
	// Held still with nobody at the outpost: resume_routine() looks again
	if(paused_at)
		return
	if(!doorway_can_leave())
		watch_doorway()
		return
	var/list/turf/ways = list()
	var/turf/back = doorway_from
	if(back && get_dist(back, tile) == 1)
		ways += get_step(tile, get_dir(back, tile))
		ways += back
	// The sides of the door, the one nearer home first
	var/list/turf/sides = list()
	for(var/direction in GLOB.cardinals)
		var/turf/side = get_step(tile, direction)
		if(side && !(side in ways))
			sides += side
	if(home && home.z == tile.z && length(sides) > 1)
		var/list/turf/by_home = list()
		while(length(sides))
			var/turf/nearest = sides[1]
			for(var/turf/side as anything in sides)
				if(get_dist(side, home) < get_dist(nearest, home))
					nearest = side
			sides -= nearest
			by_home += nearest
		sides = by_home
	ways += sides
	// At what they are doing: only to a tile they can go on doing it from
	var/atom/busy_at = (activity?.spot && activity.at_spot()) ? activity.spot : null
	for(var/turf/way as anything in ways)
		if(isnull(way) || outpost_doorway_of(way) || way.is_blocked_turf(exclude_mobs = FALSE, source_atom = src))
			continue
		if(busy_at && (activity.spot_distance ? get_dist(way, busy_at) > activity.spot_distance : way != get_turf(busy_at)))
			continue
		if(Move(way, get_dir(tile, way)) && loc == way)
			return
	if(back && !busy_at)
		for(var/mob/living/behind in back)
			if(outpost_npc_step_aside(behind, src, list()))
				break
	watch_doorway()

// =========================================================================
// TWO OF THEM HEAD-ON
// =========================================================================

/**
 * Two of the townspeople walking into each other head-on, each one's next step the other's tile, trade places as two
 * people on help intent do in tg. tg's bump does nothing at a walk, and in a one-tile gap each stood until its walk had
 * failed three times (about 25 seconds). Either side of a door, each waited for the other to clear the tile beyond it
 * (doorway_step_ok()); now one steps into the doorway and they pass there. Officers keep their own rules
 * (police_movement.dm), and nobody played is ever moved.
 */

/// Least time between two head-on trades of places by the same townsperson
#define OUTPOST_HEAD_ON_GAP (2 SECONDS)

/mob/living/carbon/human/npc/ambient_npc/outpost
	COOLDOWN_DECLARE(head_on_cooldown)

/mob/living/carbon/human/npc/ambient_npc/outpost/MobBump(mob/M)
	if(outpost_head_on_pass(M))
		return TRUE
	return ..()

/// Whether `who` is one of the townspeople: the outpost's own, not an officer, nobody playing them
/proc/outpost_townsperson(mob/living/who)
	return istype(who, /mob/living/carbon/human/npc/ambient_npc/outpost) && !istype(who, /mob/living/carbon/human/npc/ambient_npc/outpost/police) && !who.client && !who.mind

/**
 * The tile `walker`'s own walk takes them onto next, held up or not: the next tile of the path they follow, or null
 * when they follow none. (outpost_npc_next_step() counts someone held up as not walking.)
 */
/proc/outpost_npc_path_next(mob/living/walker)
	var/datum/move_loop/has_target/jps/loop = GLOB.move_manager.processing_on(walker, SSai_movement)
	if(!istype(loop) || !(loop.status & MOVELOOP_STATUS_RUNNING) || (loop.status & MOVELOOP_STATUS_PAUSED))
		return null
	return length(loop.movement_path) ? loop.movement_path[1] : null

/// They walked into `other`, another townsperson walking into them: the two trade places. TRUE if they did.
/mob/living/carbon/human/npc/ambient_npc/outpost/proc/outpost_head_on_pass(mob/living/other)
	if(!outpost_townsperson(src) || !outpost_townsperson(other) || stat != CONSCIOUS || move_intent != MOVE_INTENT_WALK)
		return FALSE
	if(!outpost_npc_can_make_room(src) || !outpost_npc_can_make_room(other) || pulling || other.pulling || moving_diagonally || now_pushing)
		return FALSE
	if(LAZYLEN(do_afters) || LAZYLEN(other.do_afters) || !COOLDOWN_FINISHED(src, head_on_cooldown))
		return FALSE
	var/turf/here = get_turf(src)
	var/turf/there = get_turf(other)
	if(!here || !there || get_dist(here, there) != 1 || outpost_npc_path_next(src) != there || outpost_npc_path_next(other) != here)
		return FALSE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/them = other
	COOLDOWN_START(src, head_on_cooldown, OUTPOST_HEAD_ON_GAP)
	COOLDOWN_START(them, head_on_cooldown, OUTPOST_HEAD_ON_GAP)
	return pirate_crew_swap_places(src, other)

#undef OUTPOST_HEAD_ON_GAP
#undef OUTPOST_DOORWAY_LINGER
