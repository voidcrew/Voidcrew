/**
 * # Running from creatures
 *
 * Owner decision 2026-09-25: an experiment's creature frightens the prisoners it threatens, not the
 * whole wing for as long as it lives. A prisoner panics when a live, hostile creature is loose in the
 * cell block, or within OUTPOST_PANIC_SIGHT_RANGE tiles and in their sight (creature_threats(),
 * frightens()). A horror down regenerating frightens only prisoners within OUTPOST_PANIC_DOWNED_RANGE.
 * The changeling's slug frightens nobody until it fights; while it is in the vents its noises have
 * their own flee (outpost_prison_changeling.dm). A creature shut in (a bolted cell, a corner walled
 * off: creature_shut_in()) frightens only those who can see it. Once no creature has frightened them
 * for OUTPOST_PANIC_CALM_TIME, they calm down and go back to their day.
 *
 * - Free to move, they run (OUTPOST_PANIC_FLEE_SPEED) for their own cell, its chair or bed, and shout to be
 *   bolted in, unless the creature is in that cell, can get to its door first, or is on or near the
 *   way there. Then they run the other way: to the tile of the cell block they can walk to that is
 *   farthest from it, out of its sight if there is one (another open cell, the far end of the yard).
 *   With nowhere to go, they cower. A creature that comes into the cell they hide in sends them
 *   running again. They never run out of the cell block, and never through a staff door.
 * - Rioters and fighters with a creature within OUTPOST_PANIC_ROLL_RANGE roll, by mood and
 *   personality (outpost_prisoner_creature_fight_chance()): most run (a rioter stays a rioter), a few
 *   go at it, shiv out if they have one. Their blows count as nobody's for the containment bonus.
 * - Cuffed, down or held, they cannot run: they cower and shout.
 * - Frightened and shut in their own cell, being locked in costs them nothing
 *   (sheltering_from_creature()); the usual clocks run again once they calm down.
 * The prison runs it all every second from experiments_tick(). Numbers are in
 * voidcrew/_DEFINES/outpost_prison_experiments.dm.
 */

// What an activity's tick() wants next, as in outpost_prison_routine.dm (which undefines its own)
#define ACTIVITY_CONTINUE 0
#define ACTIVITY_DONE 1

/// How much a creature frightens prisoners: not at all, only up close (a horror down regenerating), or fully
#define CREATURE_MENACE_NONE 0
#define CREATURE_MENACE_NEAR 1
#define CREATURE_MENACE_FULL 2

/// What a rioter or fighter does with a creature close by
#define CREATURE_REACTION_FLEE "flee"
#define CREATURE_REACTION_FIGHT "fight"

// ===== THE PRISONER =====

/mob/living/basic/outpost_prisoner
	/// Seconds of fright left: full while a creature frightens them, counting down once none does. 0 when calm.
	var/creature_panic_left = 0
	/// The creature that frightened them last
	var/datum/weakref/panic_threat_ref
	/// world.time of their next shout while frightened
	var/next_panic_line = 0
	/// A rioter's or fighter's roll at a creature close by (CREATURE_REACTION_FLEE or _FIGHT), and the world.time it holds until
	var/creature_reaction
	var/creature_reaction_until = 0
	/// The creature they went for, and the world.time they give up on it
	var/datum/weakref/creature_foe_ref
	var/creature_foe_until = 0
	/// Where a rioter runs from a creature, and the world.time they stop trying to get there
	var/turf/creature_retreat_spot
	var/creature_retreat_until = 0
	/// Running at OUTPOST_PANIC_FLEE_SPEED
	var/running_scared = FALSE

/// Whether a creature has them frightened
/mob/living/basic/outpost_prisoner/proc/is_panicking()
	return creature_panic_left > 0

/// The creature that frightened them last, while it lives
/mob/living/basic/outpost_prisoner/proc/panic_threat()
	var/mob/living/threat = panic_threat_ref?.resolve()
	if(QDELETED(threat) || threat.stat == DEAD)
		return null
	return threat

/**
 * Frightened and shut in their own cell, by a creature or by the noises in the vents
 * (outpost_prison_changeling.dm): they asked for it, so the lock-in clock waits, and so does the
 * pay it stops (update_locked_in(), confined_unpaid()).
 */
/mob/living/basic/outpost_prisoner/proc/sheltering_from_creature()
	if(!is_panicking() && !istype(activity, /datum/prisoner_activity/flee_creature))
		return FALSE
	return !!cell?.contains(src) && is_confined()

/// The creature they are going for, while they still are: a menace still, close, and not given up on
/mob/living/basic/outpost_prisoner/proc/creature_foe()
	if(!creature_foe_ref)
		return null
	var/mob/living/foe = creature_foe_ref.resolve()
	if(QDELETED(foe) || world.time >= creature_foe_until || outpost_creature_menace(foe) != CREATURE_MENACE_FULL || foe.z != z || get_dist(src, foe) > OUTPOST_PANIC_SIGHT_RANGE)
		creature_foe_ref = null
		return null
	return foe

/// They run while running from a creature, and walk otherwise
/mob/living/basic/outpost_prisoner/proc/update_flee_speed()
	var/wanted = stat != DEAD && (istype(activity, /datum/prisoner_activity/creature_panic) || (!!creature_retreat_spot && world.time < creature_retreat_until))
	if(wanted == running_scared)
		return
	running_scared = wanted
	// A loose meek bounty prisoner keeps their pace (outpost_prison_bounty.dm).
	set_varspeed(wanted ? OUTPOST_PANIC_FLEE_SPEED : bounty_base_speed())

/**
 * A rioter running from a creature, planned from the trouble subtree: TRUE while they are on the
 * way. At the spot, out of time or no longer rioting, they stop and riot on.
 */
/mob/living/basic/outpost_prisoner/proc/plan_creature_retreat(datum/ai_controller/controller)
	if(!creature_retreat_spot)
		return FALSE
	if(loc == creature_retreat_spot || world.time >= creature_retreat_until || !is_rioting())
		finish_creature_retreat()
		return FALSE
	if(stat != CONSCIOUS || phase != PRISONER_PRESENT || can_be_dragged() || pulledby || climb_ref)
		return FALSE
	controller.queue_behavior(/datum/ai_behavior/outpost_prisoner_creature_retreat)
	return TRUE

/mob/living/basic/outpost_prisoner/proc/finish_creature_retreat()
	creature_retreat_spot = null
	creature_retreat_until = 0
	update_flee_speed()

/// Runs to where a rioter is getting away from a creature
/datum/ai_behavior/outpost_prisoner_creature_retreat
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT
	required_distance = 0
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/outpost_prisoner_creature_retreat/setup(datum/ai_controller/controller)
	var/mob/living/basic/outpost_prisoner/prisoner = controller.pawn
	var/turf/spot = prisoner?.creature_retreat_spot
	if(!spot)
		return FALSE
	prisoner.stand_up()
	set_movement_target(controller, spot)
	return TRUE

/datum/ai_behavior/outpost_prisoner_creature_retreat/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/basic/outpost_prisoner/prisoner = controller.pawn
	if(!prisoner?.creature_retreat_spot || prisoner.loc != prisoner.creature_retreat_spot)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	prisoner.finish_creature_retreat()
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/outpost_prisoner_creature_retreat/finish_action(datum/ai_controller/controller, succeeded)
	. = ..()
	if(!succeeded)
		// No way through: they riot on from where they are.
		var/mob/living/basic/outpost_prisoner/prisoner = controller.pawn
		prisoner?.finish_creature_retreat()

/**
 * Percent chance a rioter or fighter with a creature close by goes at it rather than running: likelier
 * the worse their mood, likelier for the grumpy and less likely for the nervous and the cheerful,
 * and never certain either way
 */
/proc/outpost_prisoner_creature_fight_chance(mood, personality)
	var/chance = OUTPOST_PANIC_FIGHT_CHANCE + (OUTPOST_PANIC_FIGHT_MID_MOOD - clamp(mood, 0, 100)) * OUTPOST_PANIC_FIGHT_PER_MOOD
	if(personality == "grumpy")
		chance *= OUTPOST_PANIC_FIGHT_PERSONALITY_MULT
	else if(personality == "nervous" || personality == "cheerful")
		chance /= OUTPOST_PANIC_FIGHT_PERSONALITY_MULT
	return clamp(round(chance), OUTPOST_PANIC_FIGHT_MIN, OUTPOST_PANIC_FIGHT_MAX)

// ===== THE CREATURES =====

/**
 * How much `creature` frightens prisoners now. Only on the ground (not in a vent, a locker or someone's
 * arms) and not in Kessler's hands. The changeling's slug frightens once it fights; a horror down
 * regenerating only up close; anything else while turrets would shoot it (is_hostile_creature()).
 */
/proc/outpost_creature_menace(mob/living/creature)
	if(QDELETED(creature) || creature.stat == DEAD || !isturf(creature.loc) || HAS_TRAIT(creature, TRAIT_GODMODE))
		return CREATURE_MENACE_NONE
	var/mob/living/basic/outpost_experiment/horror/horror = creature
	if(istype(horror) && horror.regenerating)
		return CREATURE_MENACE_NEAR
	var/mob/living/basic/headslug/beakless/outpost/slug = creature
	if(istype(slug))
		return slug.mode == "fight" ? CREATURE_MENACE_FULL : CREATURE_MENACE_NONE
	return is_hostile_creature(creature) ? CREATURE_MENACE_FULL : CREATURE_MENACE_NONE

/datum/outpost_prison
	/// For tests: CREATURE_REACTION_FLEE or _FIGHT for every rioter's and fighter's roll, instead of rolling
	var/forced_creature_reaction

/// The experiment's creatures that frighten prisoners now: creature = how much (outpost_creature_menace())
/datum/outpost_prison/proc/creature_threats()
	var/list/found = list()
	if(!experiment_active())
		return found
	for(var/mob/living/creature as anything in experiment.live_creatures())
		var/menace = outpost_creature_menace(creature)
		if(menace != CREATURE_MENACE_NONE)
			found[creature] = menace
	return found

/**
 * Whether a creature in the cell block is shut in: over floor a prisoner could stand on, it cannot
 * get to the doorway of any cell but the one it is in, as in a bolted cell or a corner of the yard
 * walled off. It frightens only those who can see it, so a creature kept locked away never keeps the
 * whole wing hiding for free. One outside the cell block is never shut in.
 */
/datum/outpost_prison/proc/creature_shut_in(mob/living/creature)
	var/turf/start = get_turf(creature)
	if(!start || start.loc != wing || !in_cell_block(start))
		return FALSE
	// The yard-side tiles in front of every other cell's door
	var/datum/outpost_prison_cell/own_cell = cell_at(start)
	var/list/doorsteps = list()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell == own_cell || !cell.door_turf)
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/doorstep = get_step(cell.door_turf, direction)
			if(doorstep && !cell.turf_set[doorstep])
				doorsteps[doorstep] = TRUE
	if(doorsteps[start])
		return FALSE
	var/list/seen = list()
	seen[start] = TRUE
	var/list/queue = list(start)
	var/index = 1
	while(index <= length(queue))
		var/turf/current = queue[index++]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || seen[next] || next.loc != wing || !in_cell_block(next))
				continue
			// At a cell door, whatever is piled on the step
			if(doorsteps[next])
				return FALSE
			if(!prisoner_can_stand(next))
				continue
			seen[next] = TRUE
			queue += next
	return TRUE

/// Whether a creature that fully frightens is out and about, not shut in. The guards keep to the office meanwhile (outpost_prison_guards.dm).
/datum/outpost_prison/proc/creature_out()
	var/list/threats = creature_threats()
	for(var/mob/living/creature as anything in threats)
		if(threats[creature] == CREATURE_MENACE_FULL && !creature_shut_in(creature))
			return TRUE
	return FALSE

/**
 * Whether `creature`, of `menace`, frightens `prisoner`. One `loose` in the cell block frightens
 * everyone; otherwise it has to be within OUTPOST_PANIC_SIGHT_RANGE and in their sight, or within
 * OUTPOST_PANIC_DOWNED_RANGE for one that only frightens up close.
 */
/datum/outpost_prison/proc/frightens(mob/living/basic/outpost_prisoner/prisoner, mob/living/creature, menace, loose)
	var/turf/here = get_turf(prisoner)
	var/turf/there = get_turf(creature)
	if(!here || !there || here.z != there.z)
		return FALSE
	if(menace == CREATURE_MENACE_NEAR)
		return get_dist(here, there) <= OUTPOST_PANIC_DOWNED_RANGE && can_see(here, there, OUTPOST_PANIC_DOWNED_RANGE)
	if(loose)
		return TRUE
	return get_dist(here, there) <= OUTPOST_PANIC_SIGHT_RANGE && can_see(here, there, OUTPOST_PANIC_SIGHT_RANGE)

/// The nearest of `threats` (creature = menace) that frightens `prisoner`, or null. `loose` marks those loose in the cell block.
/datum/outpost_prison/proc/frightening_creature(mob/living/basic/outpost_prisoner/prisoner, list/threats, list/loose)
	var/mob/living/nearest
	var/nearest_distance = INFINITY
	for(var/mob/living/creature as anything in threats)
		if(!frightens(prisoner, creature, threats[creature], loose[creature]))
			continue
		var/distance = get_dist(prisoner, creature)
		if(distance < nearest_distance)
			nearest = creature
			nearest_distance = distance
	return nearest

// ===== THE PRISON'S TICK =====

/// Whether a creature can frighten `prisoner` now: present and awake in the wing's custody, not loose, and not the experiment's subject
/datum/outpost_prison/proc/can_panic(mob/living/basic/outpost_prisoner/prisoner)
	return prisoner.prison == src && prisoner.phase == PRISONER_PRESENT && prisoner.stat == CONSCIOUS && !prisoner.experiment_subject && prisoner.trouble != PRISONER_TROUBLE_LOOSE

/**
 * Every second from experiments_tick(), and at once when a creature shows (with `seconds` 0): who
 * a creature frightens and what each of them does about it, and who has calmed down.
 */
/datum/outpost_prison/proc/creature_panic_tick(seconds)
	var/list/threats = creature_threats()
	var/list/loose = list()
	for(var/mob/living/creature as anything in threats)
		loose[creature] = threats[creature] == CREATURE_MENACE_FULL && in_cell_block(creature) && !creature_shut_in(creature)
	var/shouts = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners.Copy())
		if(QDELETED(prisoner))
			continue
		if(!can_panic(prisoner))
			if(prisoner.is_panicking())
				calm_from_panic(prisoner)
			continue
		var/mob/living/threat = length(threats) ? frightening_creature(prisoner, threats, loose) : null
		if(threat)
			var/fresh = !prisoner.is_panicking()
			prisoner.creature_panic_left = OUTPOST_PANIC_CALM_TIME
			prisoner.panic_threat_ref = WEAKREF(threat)
			if(react_to_creature(prisoner, threat, seconds, fresh && shouts < 2))
				shouts++
		else if(prisoner.is_panicking())
			prisoner.creature_panic_left = max(0, prisoner.creature_panic_left - seconds)
			if(prisoner.is_panicking())
				keep_hiding(prisoner)
			else
				calm_from_panic(prisoner)
		prisoner.update_flee_speed()

/**
 * `threat` frightens `prisoner`. Cuffed, down or held, they cower and shout. A rioter or fighter
 * with it close rolls to run or go at it (creature_roll()); farther off they carry on. Anyone else
 * drops what they were doing (a wreck, squaring up to staff) and runs (start_panic()), or, already
 * running, rethinks the way (the panic's reconsider()). Returns TRUE if they shouted.
 */
/datum/outpost_prison/proc/react_to_creature(mob/living/basic/outpost_prisoner/prisoner, mob/living/threat, seconds, may_shout)
	if(prisoner.can_be_dragged() || prisoner.pulledby)
		// Down, they neither run nor fight.
		prisoner.creature_foe_ref = null
		prisoner.finish_creature_retreat()
		return cower_in_fright(prisoner, may_shout)
	if(prisoner.is_rioting() || prisoner.trouble == PRISONER_TROUBLE_FIGHT || prisoner.creature_foe())
		if(get_dist(prisoner, threat) <= OUTPOST_PANIC_ROLL_RANGE)
			creature_roll(prisoner, threat)
		// A fighter who ran is out of the fight, and runs like anyone else below.
		if(prisoner.is_rioting() || prisoner.trouble == PRISONER_TROUBLE_FIGHT || prisoner.creature_foe())
			return FALSE
	if(prisoner.trouble == PRISONER_TROUBLE_WRECK)
		stop_wreck(prisoner)
	if(prisoner.threat_ref || prisoner.swing_ref)
		prisoner.cancel_threat()
	var/datum/prisoner_activity/creature_panic/panic = prisoner.activity
	if(istype(panic))
		panic.reconsider(threat, seconds)
		return FALSE
	return start_panic(prisoner, may_shout)

/**
 * `prisoner` breaks and runs (/datum/prisoner_activity/creature_panic), if their routine is free to.
 * `shout` has them say so. Returns TRUE if they shouted.
 */
/datum/outpost_prison/proc/start_panic(mob/living/basic/outpost_prisoner/prisoner, shout = FALSE)
	if(prisoner.prison != src || prisoner.experiment_subject || !prisoner.routine_allowed())
		return FALSE
	if(istype(prisoner.activity, /datum/prisoner_activity/creature_panic))
		return FALSE
	// What they were doing lets go of its things first, so the seat the panic claims stays claimed.
	prisoner.end_activity()
	var/datum/prisoner_activity/creature_panic/panic = new(prisoner)
	panic.setup()
	prisoner.start_activity(panic)
	prisoner.update_flee_speed()
	if(!shout || !prisoner.ai_running())
		return FALSE
	prisoner.next_panic_line = world.time + OUTPOST_EXPERIMENT_PANIC_GAP * rand(4, 6) / 10 SECONDS
	INVOKE_ASYNC(prisoner, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), "creature_flee")
	return TRUE

/// Still frightened with nothing in sight: they stay where they ran to, and go back to it if something else took them away
/datum/outpost_prison/proc/keep_hiding(mob/living/basic/outpost_prisoner/prisoner)
	if(istype(prisoner.activity, /datum/prisoner_activity/creature_panic) || istype(prisoner.activity, /datum/prisoner_activity/flee_creature))
		return
	start_panic(prisoner)

/// Cuffed, down or held: nowhere to go, so they cower and shout now and then. Returns TRUE if they shouted.
/datum/outpost_prison/proc/cower_in_fright(mob/living/basic/outpost_prisoner/prisoner, may_shout)
	if(!may_shout && world.time < prisoner.next_panic_line)
		return FALSE
	prisoner.next_panic_line = world.time + OUTPOST_EXPERIMENT_PANIC_GAP * rand(8, 12) / 10 SECONDS
	if(!prisoner.ai_running())
		return FALSE
	prisoner.manual_emote(pick("cowers.", "cringes away.", "shrinks back."))
	if(!may_shout && !wing_can_speak())
		return FALSE
	note_speech()
	INVOKE_ASYNC(prisoner, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), "creature_panic")
	return TRUE

/// Nothing has frightened them for OUTPOST_PANIC_CALM_TIME, or they can no longer be frightened: back to their day
/datum/outpost_prison/proc/calm_from_panic(mob/living/basic/outpost_prisoner/prisoner)
	prisoner.creature_panic_left = 0
	prisoner.panic_threat_ref = null
	prisoner.creature_reaction = null
	prisoner.creature_reaction_until = 0
	prisoner.creature_foe_ref = null
	prisoner.finish_creature_retreat()
	if(istype(prisoner.activity, /datum/prisoner_activity/creature_panic))
		prisoner.end_activity()
	prisoner.update_flee_speed()

// ===== RIOTERS AND FIGHTERS =====

/**
 * A rioter or fighter with a creature close by: they run (most of the time) or go at it, rolled by
 * mood and personality (outpost_prisoner_creature_fight_chance()). The roll holds for
 * OUTPOST_PANIC_ROLL_HOLD. Returns what they did.
 */
/datum/outpost_prison/proc/creature_roll(mob/living/basic/outpost_prisoner/prisoner, mob/living/threat)
	if(prisoner.creature_reaction && world.time < prisoner.creature_reaction_until)
		return prisoner.creature_reaction
	var/reaction = forced_creature_reaction
	if(!reaction)
		reaction = prob(outpost_prisoner_creature_fight_chance(prisoner.mood, prisoner.personality)) ? CREATURE_REACTION_FIGHT : CREATURE_REACTION_FLEE
	prisoner.creature_reaction = reaction
	prisoner.creature_reaction_until = world.time + OUTPOST_PANIC_ROLL_HOLD
	if(reaction == CREATURE_REACTION_FIGHT)
		stand_against_creature(prisoner, threat)
	else
		run_from_creature(prisoner, threat)
	return reaction

/// Goes at the creature, with their shiv if they have one. A fight they were in is forgotten.
/datum/outpost_prison/proc/stand_against_creature(mob/living/basic/outpost_prisoner/prisoner, mob/living/threat)
	if(prisoner.fight)
		end_fight(prisoner.fight)
	prisoner.cancel_threat()
	prisoner.finish_creature_retreat()
	prisoner.creature_foe_ref = WEAKREF(threat)
	prisoner.creature_foe_until = world.time + OUTPOST_PANIC_STAND_TIME
	prisoner.ai_controller?.CancelActions()
	prisoner.face_atom(threat)
	prisoner.manual_emote(prisoner.has_shiv() ? "goes for [threat] with [prisoner.p_their()] shiv!" : "goes for [threat]!")

/**
 * Runs from the creature. A fighter's fight is over, and they run as anyone does (start_panic(),
 * from react_to_creature()). A rioter stays a rioter: they run to the far side of the cell block
 * (flee_spot()) and riot on from there, or back off where they stand with nowhere to go. Returns
 * TRUE if a rioter ran.
 */
/datum/outpost_prison/proc/run_from_creature(mob/living/basic/outpost_prisoner/prisoner, mob/living/threat)
	prisoner.creature_foe_ref = null
	if(!prisoner.is_rioting())
		if(prisoner.fight)
			end_fight(prisoner.fight)
		return FALSE
	prisoner.riot_target_ref = null
	prisoner.riot_target_hits = 0
	prisoner.riot_victim_ref = null
	prisoner.ai_controller?.CancelActions()
	var/turf/spot = flee_spot(prisoner, threat)
	if(!spot || spot == get_turf(prisoner))
		prisoner.manual_emote("backs away from [threat].")
		return FALSE
	prisoner.creature_retreat_spot = spot
	prisoner.creature_retreat_until = world.time + OUTPOST_PANIC_RETREAT_TIME
	prisoner.update_flee_speed()
	if(prisoner.ai_running() && prob(50))
		INVOKE_ASYNC(prisoner, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), "creature_flee")
	return TRUE

// ===== WHERE TO RUN =====

/**
 * Steps from `start` to each tile of `walkable` in the cell block that it can reach, never entering
 * `avoid` (turf = TRUE): turf = steps. `parents`, if given, gets each tile's step before it.
 */
/datum/outpost_prison/proc/panic_steps(turf/start, list/walkable, list/avoid, list/parents)
	var/list/steps = list()
	if(!start || !walkable)
		return steps
	steps[start] = 0
	var/list/queue = list(start)
	var/index = 1
	while(index <= length(queue))
		var/turf/current = queue[index++]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || !isnull(steps[next]) || !walkable[next] || avoid?[next] || !in_cell_block(next))
				continue
			steps[next] = steps[current] + 1
			if(parents)
				parents[next] = current
			queue += next
	return steps

/// Where they hide at home: their own cell's chair or bed (home_seat()), or failing that any free tile of their own cell they can walk to, or null
/datum/outpost_prison/proc/panic_home_spot(mob/living/basic/outpost_prisoner/prisoner)
	var/datum/outpost_prison_cell/home = prisoner.cell
	if(!home || !prisoner.walkable)
		return null
	var/obj/structure/seat = prisoner.home_seat()
	if(seat)
		return get_turf(seat)
	for(var/turf/tile as anything in home.turfs)
		if(prisoner.walkable[tile] && (tile == prisoner.loc || !prisoner.tile_taken(tile)))
			return tile
	return null

/**
 * Whether `prisoner` can run home to `home` in their cell with `threat` about: not with it in the
 * cell or its doorway, nor when it can get to the cell door before they can, nor when the way there
 * passes within OUTPOST_PANIC_PATH_MARGIN of it and no farther from it than they stand now. Once they
 * are inside the cell, only it coming in makes home unsafe.
 */
/datum/outpost_prison/proc/home_is_safe(mob/living/basic/outpost_prisoner/prisoner, turf/home, mob/living/threat)
	var/datum/outpost_prison_cell/own = prisoner.cell
	if(!own || !home)
		return FALSE
	var/turf/danger = get_turf(threat)
	if(!danger || danger.z != home.z)
		return TRUE
	if(own.contains(danger) || danger == own.door_turf)
		return FALSE
	var/turf/here = get_turf(prisoner)
	if(own.contains(here))
		return TRUE
	var/list/parents = list()
	var/list/steps = panic_steps(here, prisoner.walkable, null, parents)
	if(isnull(steps[home]))
		return FALSE
	// It would get to the door first.
	var/turf/door = own.door_turf
	if(door && !isnull(steps[door]))
		var/list/its_steps = panic_steps(danger, prisoner.walkable)
		if(!isnull(its_steps[door]) && its_steps[door] < steps[door])
			return FALSE
	// The way there
	var/here_distance = get_dist(here, danger)
	var/turf/on_way = home
	while(on_way && on_way != here)
		var/distance = get_dist(on_way, danger)
		if(distance <= OUTPOST_PANIC_PATH_MARGIN && distance <= here_distance)
			return FALSE
		on_way = parents[on_way]
	return TRUE

/**
 * Where `prisoner` runs to, away from `threat`: the tile of the cell block they can walk to without
 * passing beside it that is farthest from it, out of its sight if any is, and not within
 * OUTPOST_PANIC_SPOT_MARGIN of it. Null when there is nowhere: they are cornered.
 */
/datum/outpost_prison/proc/flee_spot(mob/living/basic/outpost_prisoner/prisoner, mob/living/threat)
	var/turf/here = get_turf(prisoner)
	var/turf/danger = get_turf(threat)
	if(!here || !danger || !length(prisoner.walkable))
		return null
	var/list/avoid = list()
	for(var/turf/beside in range(1, danger))
		if(beside != here)
			avoid[beside] = TRUE
	var/list/steps = panic_steps(here, prisoner.walkable, avoid)
	var/list/its_steps = panic_steps(danger, prisoner.walkable)
	var/turf/best
	var/best_score = -INFINITY
	for(var/turf/tile as anything in steps)
		if(tile != here && prisoner.tile_taken(tile))
			continue
		var/straight = get_dist(tile, danger)
		if(straight <= OUTPOST_PANIC_SPOT_MARGIN)
			continue
		// How far it would have to walk; somewhere it cannot walk to at all is as good as out of reach
		var/far = isnull(its_steps[tile]) ? straight + OUTPOST_PANIC_SIGHT_RANGE : its_steps[tile]
		var/score = far * 10 - steps[tile]
		if(!can_see(danger, tile, OUTPOST_PANIC_SIGHT_RANGE))
			score += 10000
		if(score > best_score)
			best = tile
			best_score = score
	return best

// ===== RUNNING =====

/**
 * Running from a creature: home to their own cell and its chair or bed, shouting to be bolted in; or, with no safe
 * way home, as far from it as they can get and out of its sight if they can; or, with nowhere to go,
 * cowering where they are. The prison rethinks it as the creature moves (reconsider()); it is over
 * once they calm down (calm_from_panic()).
 */
/datum/prisoner_activity/creature_panic
	name = "running from a creature"
	context = "creature_panic"
	weight = 0
	interruptible = FALSE
	/// "home", "away" or "cower"
	var/plan
	/// The chair or bed they are running home to
	var/datum/weakref/seat_ref
	/// Seconds to the next look at whether the plan still holds
	var/replan_left = 0

/datum/prisoner_activity/creature_panic/setup()
	make_plan(prisoner.panic_threat())
	return TRUE

/// Picks where to run from `threat` (null: they don't know where it is), and sets `spot`. Returns the plan.
/datum/prisoner_activity/creature_panic/proc/make_plan(mob/living/threat)
	var/datum/outpost_prison/prison = prisoner.prison
	replan_left = OUTPOST_PANIC_REPLAN_GAP
	var/obj/structure/old_seat = seat_ref?.resolve()
	seat_ref = null
	if(old_seat)
		unclaim(old_seat)
	spot = null
	// Their walks keep failing: they stay where they are.
	if(!prison || prisoner.activity_on_cooldown(type))
		return cower()
	var/turf/home = prison.panic_home_spot(prisoner)
	if(home && prison.home_is_safe(prisoner, home, threat))
		plan = "home"
		name = "running for their cell"
		var/obj/structure/seat = prisoner.home_seat()
		if(seat && get_turf(seat) == home && claim(seat))
			seat_ref = WEAKREF(seat)
		spot = home
		return plan
	var/turf/away = threat ? prison.flee_spot(prisoner, threat) : null
	if(away)
		plan = "away"
		name = "running from a creature"
		spot = away
		return plan
	return cower()

/datum/prisoner_activity/creature_panic/proc/cower()
	plan = "cower"
	name = "cowering"
	spot = null
	return plan

/datum/prisoner_activity/creature_panic/begin()
	started = TRUE
	ends_at = INFINITY
	settle()

/datum/prisoner_activity/creature_panic/arrive()
	spot = null
	if(started)
		settle()
	else
		begin()
	return TRUE

/// Where they ended up: in their chair or on their bunk at home, facing the creature from a distance, or cowering
/datum/prisoner_activity/creature_panic/proc/settle()
	var/mob/living/threat = prisoner.panic_threat()
	switch(plan)
		if("home")
			if(seat_ref?.resolve() && prisoner.cell?.contains(prisoner))
				var/obj/machinery/door/door = prisoner.cell.door()
				prisoner.sit_in_cell(door ? get_cardinal_dir(prisoner, door) : SOUTH)
		if("away")
			if(threat)
				prisoner.face_atom(threat)
		if("cower")
			prisoner.sit_on_edge(threat ? get_cardinal_dir(prisoner, threat) : null)
			prisoner.manual_emote(pick("cowers.", "backs into a corner.", "freezes."))

/**
 * `threat` frightens them from where it is now. Every OUTPOST_PANIC_REPLAN_GAP seconds, or at once if
 * it has come into the cell they are hiding in, they check the plan still holds; if not, they make a
 * new one and run for it. Returns TRUE if they changed it.
 */
/datum/prisoner_activity/creature_panic/proc/reconsider(mob/living/threat, seconds)
	replan_left -= seconds
	var/urgent = plan == "home" && prisoner.cell?.contains(threat)
	if(replan_left > 0 && !urgent)
		return FALSE
	replan_left = OUTPOST_PANIC_REPLAN_GAP
	if(plan_holds(threat))
		return FALSE
	var/old_plan = plan
	var/turf/was_going = spot
	make_plan(threat)
	if(spot == prisoner.loc)
		spot = null
	// Somewhere new, or nowhere now: the walk they were on stops.
	if(spot != was_going)
		redirect()
	if(!spot && plan != old_plan)
		settle()
	return TRUE

/// Whether where they are running or hiding still makes sense with `threat` where it is
/datum/prisoner_activity/creature_panic/proc/plan_holds(mob/living/threat)
	var/datum/outpost_prison/prison = prisoner.prison
	if(!prison || !threat)
		return TRUE
	switch(plan)
		if("home")
			return prison.home_is_safe(prisoner, spot || get_turf(prisoner), threat)
		if("away")
			var/turf/target = spot || get_turf(prisoner)
			if(get_dist(target, threat) <= OUTPOST_PANIC_SPOT_MARGIN)
				return FALSE
			// Home is safe again: back there.
			var/turf/home = prison.panic_home_spot(prisoner)
			return !(home && prison.home_is_safe(prisoner, home, threat))
	// Cowering: they look for a way out.
	return FALSE

/// Heads for the new `spot` now: whatever walk or wait the AI was on stops, without counting as a failed walk
/datum/prisoner_activity/creature_panic/proc/redirect()
	prisoner.stand_up()
	failed_moves = -1
	prisoner.ai_controller?.CancelActions()
	failed_moves = max(failed_moves, 0)

/datum/prisoner_activity/creature_panic/tick(seconds)
	if(!prisoner.is_panicking())
		return ACTIVITY_DONE
	if(world.time < prisoner.next_panic_line)
		return ACTIVITY_CONTINUE
	prisoner.next_panic_line = world.time + OUTPOST_EXPERIMENT_PANIC_GAP * rand(8, 12) / 10 SECONDS
	// Bolted in their cell, they keep their heads down.
	if(prisoner.cell?.contains(prisoner) && prisoner.cell.is_bolted())
		return ACTIVITY_CONTINUE
	var/datum/outpost_prison/prison = prisoner.prison
	if(!prison?.wing_can_speak())
		return ACTIVITY_CONTINUE
	prison.note_speech()
	prisoner.say_context(panic_line())
	return ACTIVITY_CONTINUE

/// What they shout: to be bolted in, on the way home or in it; to run, otherwise; about the dark, now and then, with a nightmare about
/datum/prisoner_activity/creature_panic/proc/panic_line()
	var/mob/living/threat = prisoner.panic_threat()
	var/nightmare = istype(threat, /mob/living/basic/outpost_experiment/nightmare) || (!threat && prisoner.prison?.experiment?.form == "nightmare")
	if(nightmare && prob(50))
		return "nightmare_fear"
	return plan == "home" ? "creature_panic" : "creature_flee"

/datum/prisoner_activity/creature_panic/finish()
	. = ..()
	prisoner?.update_flee_speed()

#undef ACTIVITY_CONTINUE
#undef ACTIVITY_DONE
#undef CREATURE_MENACE_NONE
#undef CREATURE_MENACE_NEAR
#undef CREATURE_MENACE_FULL
#undef CREATURE_REACTION_FLEE
#undef CREATURE_REACTION_FIGHT
