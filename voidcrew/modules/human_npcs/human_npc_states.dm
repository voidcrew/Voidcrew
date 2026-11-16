/**
 * # Shared state rules for human NPCs
 *
 * N4, out of the fight: one test for "this body isn't fighting any more", read from tg state, used by
 * boarding waves and the pirate pool slot (owner ruling OC-7), hull turrets, bounty pay, and AI morale.
 *
 * N8, walking out: a living NPC that leaves (a goon running off, a decoy heading for the lift, a crewman
 * abandoning a fight) walks to its exit for real. Shots land, wounds slow it, cuffs and grabs stop it.
 * It is deleted only when it stands on its exit tile, or when no player is near enough to see it
 * (human_npc_watched()), and never while it is down, cuffed, dragged, carried or buckled. There is no
 * godmode beam. SShuman_npcs checks the NPCs that are leaving once a second.
 */

/**
 * Whether `body` is out of the fight: dead, in crit (tg's TRAIT_CRITICAL_CONDITION, soft or hard,
 * asleep or not), or restrained (handcuffs, a straitjacket). Stamcrit and stuns pass, so they don't
 * count. Works on any mob; a basic mob is out only once dead.
 */
/proc/human_npc_out_of_fight(mob/living/body)
	if(QDELETED(body) || body.stat == DEAD)
		return TRUE
	return HAS_TRAIT(body, TRAIT_CRITICAL_CONDITION) || HAS_TRAIT(body, TRAIT_RESTRAINED)

// ===== Walking out =====

/**
 * Sends it walking to `exit` (an atom; its turf is used). It is deleted on that tile, or wherever nobody
 * can see it (npc_may_vanish()). `on_left`, if given, is called with it just before it goes, after
 * COMSIG_HUMAN_NPC_LEFT. Call npc_stop_leaving() to call it back.
 */
/mob/living/carbon/human/npc/proc/npc_walk_out(atom/exit, datum/callback/on_left)
	var/turf/exit_turf = get_turf(exit)
	if(isnull(exit_turf) || stat == DEAD)
		return FALSE
	npc_exit = exit_turf
	npc_on_left = on_left
	SShuman_npcs.leavers |= src
	if(istype(ai_controller))
		ai_controller.set_blackboard_key(BB_HUMAN_NPC_EXIT, exit_turf)
		// The way out may be round corners: walk it with a pathfinder, as a person would.
		human_npc_set_ai_movement(ai_controller, /datum/ai_movement/jps)
	return TRUE

/// Calls off its walk out.
/mob/living/carbon/human/npc/proc/npc_stop_leaving()
	npc_exit = null
	npc_on_left = null
	SShuman_npcs.leavers -= src
	if(istype(ai_controller))
		ai_controller.clear_blackboard_key(BB_HUMAN_NPC_EXIT)
		human_npc_set_ai_movement(ai_controller, initial(ai_controller.ai_movement))

/**
 * Whether a living NPC that is leaving may be deleted now: up and free (not in crit, not cuffed, not
 * stunned, not dragged, carried or buckled, standing on a turf), and either on its exit tile or out of
 * sight of every player.
 */
/mob/living/carbon/human/npc/proc/npc_may_vanish()
	if(isnull(npc_exit) || stat != CONSCIOUS || human_npc_out_of_fight(src))
		return FALSE
	if(INCAPACITATED_IGNORING(src, NONE) || pulledby || buckled || !isturf(loc))
		return FALSE
	return get_turf(src) == npc_exit || !human_npc_watched(src)

/// Switches a controller's movement type, stopping any walk the old one was doing.
/proc/human_npc_set_ai_movement(datum/ai_controller/controller, datum/ai_movement/movement_type)
	if(!ispath(movement_type, /datum/ai_movement))
		return
	if(controller.ai_movement?.moving_controllers[controller])
		controller.ai_movement.stop_moving_towards(controller)
	controller.change_ai_movement_type(movement_type)

/// It has left: what it carries that isn't gear drops where it stood, and it is deleted with its kit.
/mob/living/carbon/human/npc/proc/npc_vanish()
	SShuman_npcs.leavers -= src
	SEND_SIGNAL(src, COMSIG_HUMAN_NPC_LEFT)
	npc_on_left?.Invoke(src)
	npc_on_left = null
	npc_drop_not_gear()
	qdel(src)

/// While it has somewhere to walk out to, it walks there and does nothing else.
/datum/ai_planning_subtree/human_npc_walk_out

/datum/ai_planning_subtree/human_npc_walk_out/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/npc = controller.pawn
	if(npc.stat != CONSCIOUS || !controller.blackboard_key_exists(BB_HUMAN_NPC_EXIT))
		return
	controller.queue_behavior(/datum/ai_behavior/human_npc_walk_out, BB_HUMAN_NPC_EXIT)
	return SUBTREE_RETURN_FINISH_PLANNING

/// Walks to the exit. SShuman_npcs deletes it when it may go (npc_may_vanish()).
/datum/ai_behavior/human_npc_walk_out
	required_distance = 0
	action_cooldown = 1 SECONDS
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/human_npc_walk_out/setup(datum/ai_controller/controller, exit_key)
	. = ..()
	var/turf/exit = controller.blackboard[exit_key]
	if(isnull(exit))
		return FALSE
	set_movement_target(controller, exit)

/datum/ai_behavior/human_npc_walk_out/perform(seconds_per_tick, datum/ai_controller/controller, exit_key)
	if(!controller.blackboard_key_exists(exit_key))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	return AI_BEHAVIOR_DELAY
