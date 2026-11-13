/**
 * How officers get past people in the way.
 *
 * Officers walk (tg walk intent) almost everywhere, and tg's MobBump() never swaps or pushes on walk intent, so two
 * officers meeting in a hall, or one standing paused in a doorway, blocked each other for good: the pathfinder plans
 * through mobs, and every repath gave the same blocked route. Here an officer walking into an outpost NPC passes it
 * the way two people on help intent do (a tg place swap), steps aside for an officer bringing someone in, asks the
 * NPC to step aside when it is the one bringing someone in, and plans a way around anyone who stays put for
 * POLICE_BLOCKED_REPATH. Players are never moved: tg's own rules apply to them.
 */

/// How long an officer keeps walking into the same person on the same tile before planning a way around them
#define POLICE_BLOCKED_REPATH (1.5 SECONDS)
/// A gap this long between bumps starts the wait over
#define POLICE_BLOCKED_RESET (3 SECONDS)
/// Least time between two place swaps by the same officer, so two officers never trade back and forth
#define POLICE_SWAP_COOLDOWN (1 SECONDS)

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

/mob/living/carbon/human/npc/ambient_npc/outpost/police/MobBump(mob/M)
	if(client || mind || !isliving(M) || stat != CONSCIOUS)
		return ..()
	var/turf/before = get_turf(src)
	if(police_make_room(M))
		return TRUE
	. = ..()
	if(get_turf(src) == before)
		police_note_blocked(M)

/**
 * `other`, an outpost NPC, is in this officer's way. An officer bringing someone in has the NPC step aside; an
 * officer meeting someone else bringing someone in steps aside for them; otherwise the two trade places. TRUE when
 * the way is clear (or the officer stepped aside), FALSE when nothing moved.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_make_room(mob/living/other)
	if(now_pushing || buckled || !outpost_npc_can_make_room(other))
		return FALSE
	// Bringing someone in: the other one makes way
	if(isliving(pulling))
		return outpost_npc_step_aside(other, src, list())
	// They are bringing someone in: we make way
	if(isliving(other.pulling))
		return outpost_npc_step_aside(src, other, list())
	if(pulling || other.pulling)
		return FALSE
	// No place swap partway through a diagonal step (tg MobBump()); they step aside instead
	if(moving_diagonally)
		return outpost_npc_step_aside(other, src, list())
	if(!COOLDOWN_FINISHED(src, police_swap_cooldown) || LAZYLEN(other.do_afters))
		return FALSE
	COOLDOWN_START(src, police_swap_cooldown, POLICE_SWAP_COOLDOWN)
	return pirate_crew_swap_places(src, other)

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
