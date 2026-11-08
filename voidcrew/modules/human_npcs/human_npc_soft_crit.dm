/**
 * # Human NPCs in soft crit (N5)
 *
 * A person in soft crit is on the floor, can crawl, and (Voidcrew's soft-crit item use, PR #284,
 * voidcrew/edits/modules/mob/mob.dm) can use what is on them at a quarter of the speed. An NPC does the
 * same, and nothing else: it crawls away from whoever is nearest, pleads now and then, and injects a
 * medipen it carries. Elites and bosses also fire wild from the floor, at the ground around their
 * attacker, the way a player shooting from crit does. Everything goes through tg: the crawl is a crawl,
 * the medipen is the player's "use in hand" (execute_mode()), the shot is a click with the gun.
 * Brute packs and other medical stacks need a do_after, which tg refuses to anyone incapacitated, so a
 * person in soft crit can't use them, and neither can an NPC.
 *
 * tg's basic controller turns the AI off at any stat above CONSCIOUS. human_npc_ai_able_to_run() lets a
 * human NPC's AI run in soft crit; this subtree must then come first in its planning list, so nothing
 * else plans while it is down. Hard crit, unconscious and dead still stop the AI.
 *
 * Who a family keeps attacking is npc_target_stat on the NPC (HUMAN_NPC_FINISHES_DOWNED or
 * HUMAN_NPC_SPARES_DOWNED), written into BB_TARGET_MINIMUM_STAT at spawn.
 */

/**
 * The run check for any controller whose pawn is a human NPC: the basic controller's, except that cuffs
 * don't stop it (so escape_captivity can work at them, phase A) and soft crit doesn't either (so the
 * soft-crit subtree runs). A controller of another type (PR #500's pirate crew) calls this from its own
 * get_able_to_run().
 */
/proc/human_npc_ai_able_to_run(datum/ai_controller/controller)
	var/mob/living/living_pawn = controller.pawn
	if(HAS_TRAIT(living_pawn, TRAIT_AI_PAUSED) || world.time < controller.paused_until)
		return AI_UNABLE_TO_RUN
	if(living_pawn.stat && living_pawn.stat != SOFT_CRIT && !(controller.ai_traits & CAN_ACT_WHILE_DEAD))
		return AI_UNABLE_TO_RUN
	var/ignore_incap_flags = INCAPABLE_RESTRAINTS
	if(controller.ai_traits & CAN_ACT_IN_STASIS)
		ignore_incap_flags |= INCAPABLE_STASIS
	if(controller.ai_traits & CAN_ACT_WHILE_GRABBED)
		ignore_incap_flags |= INCAPABLE_GRAB
	// The same test the click code uses in soft crit: crit's own incapacitation doesn't count, a stun does.
	if(living_pawn.incapacitated_except_softcrit(ignore_incap_flags))
		return AI_UNABLE_TO_RUN
	if((controller.ai_traits & PAUSE_DURING_DO_AFTER) && LAZYLEN(living_pawn.do_afters))
		return AI_UNABLE_TO_RUN | AI_PREVENT_CANCEL_ACTIONS
	return NONE

/// For a human NPC controller's on_stat_changed(): falling into soft crit drops whatever it was doing
/// on its feet (a reload, a shot, a chase), so only the soft-crit subtree's behaviours run.
/proc/human_npc_ai_stat_changed(datum/ai_controller/controller, new_stat)
	if(new_stat == SOFT_CRIT)
		controller.CancelActions()

/// In soft crit: treat itself, fire wild (elites and bosses), crawl away, plead. Must come first.
/datum/ai_planning_subtree/human_npc_soft_crit

/datum/ai_planning_subtree/human_npc_soft_crit/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/carbon/npc = controller.pawn
	if(npc.stat != SOFT_CRIT)
		return
	var/mob/living/carbon/human/npc/human_npc = ishumannpc(npc) ? npc : null
	if(human_npc && world.time >= human_npc.npc_next_plead)
		human_npc.npc_next_plead = world.time + HUMAN_NPC_PLEAD_INTERVAL
		human_npc.npc_bark(HUMAN_NPC_BARK_PLEAD)
	if(world.time >= controller.blackboard[BB_HUMAN_NPC_NEXT_TREAT])
		var/obj/item/treatment = human_npc_soft_crit_treatment(npc)
		if(treatment)
			controller.set_blackboard_key(BB_HUMAN_NPC_TREAT_ITEM, treatment)
			controller.queue_behavior(/datum/ai_behavior/human_npc_treat_self, BB_HUMAN_NPC_TREAT_ITEM)
			return SUBTREE_RETURN_FINISH_PLANNING
	var/mob/living/threat = human_npc_nearest_threat(controller)
	if(isnull(threat))
		return SUBTREE_RETURN_FINISH_PLANNING
	controller.set_blackboard_key(BB_HUMAN_NPC_FLEE_FROM, threat)
	if(human_npc?.npc_rank >= HUMAN_NPC_RANK_ELITE && !isnull(human_npc_loaded_gun(npc)))
		controller.queue_behavior(/datum/ai_behavior/human_npc_fire_wild, BB_HUMAN_NPC_FLEE_FROM)
	controller.queue_behavior(/datum/ai_behavior/run_away_from_target, BB_HUMAN_NPC_FLEE_FROM)
	return SUBTREE_RETURN_FINISH_PLANNING

/// Something it carries that it can use on itself in soft crit: a medipen with something in it.
/proc/human_npc_soft_crit_treatment(mob/living/carbon/npc)
	for(var/obj/item/reagent_containers/hypospray/medipen/pen in npc.get_all_contents_type(/obj/item/reagent_containers/hypospray/medipen))
		if(pen.used_up || !pen.reagents?.total_volume)
			continue
		if(npc.is_holding(pen) || human_npc_can_draw(npc, pen))
			return pen
	return null

/// The closest mob it can see that it would fight, whatever state that mob is in. Its target first.
/proc/human_npc_nearest_threat(datum/ai_controller/controller)
	var/mob/living/npc = controller.pawn
	var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(isliving(target) && !QDELETED(target) && target.z == npc.z && can_see(npc, target, HUMAN_NPC_SIGHT_RANGE))
		return target
	var/mob/living/closest
	var/closest_distance = INFINITY
	for(var/mob/living/other in oview(HUMAN_NPC_SIGHT_RANGE, npc))
		if(other.stat == DEAD || npc.faction_check_atom(other))
			continue
		var/distance = get_dist(npc, other)
		if(distance < closest_distance)
			closest = other
			closest_distance = distance
	return closest

/**
 * Uses a medipen on itself the way a player in soft crit does: takes it in hand (holstering its gun if
 * both hands are full), then "use in hand", then lets the empty pen fall.
 */
/datum/ai_behavior/human_npc_treat_self
	action_cooldown = 1 SECONDS
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/human_npc_treat_self/perform(seconds_per_tick, datum/ai_controller/controller, item_key)
	var/mob/living/carbon/npc = controller.pawn
	var/obj/item/reagent_containers/hypospray/medipen/pen = controller.blackboard[item_key]
	if(!istype(pen) || QDELETED(pen) || human_npc_holding(pen) != npc)
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	if(pen.used_up)
		if(npc.is_holding(pen))
			npc.dropItemToGround(pen)
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	if(!npc.is_holding(pen))
		if(!length(npc.get_empty_held_indexes()))
			var/obj/item/gun/gun = human_npc_held_gun(npc)
			if(isnull(gun) || !gun.equip_to_best_slot(npc))
				return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
			return AI_BEHAVIOR_DELAY
		if(!human_npc_take_in_hand(npc, pen))
			return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
		return AI_BEHAVIOR_DELAY
	if(!human_npc_ready_item(npc, pen))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	if(npc.next_move > world.time)
		return AI_BEHAVIOR_DELAY
	npc.execute_mode()
	return AI_BEHAVIOR_DELAY

/datum/ai_behavior/human_npc_treat_self/finish_action(datum/ai_controller/controller, succeeded, item_key)
	. = ..()
	controller.clear_blackboard_key(item_key)
	controller.set_blackboard_key(BB_HUMAN_NPC_NEXT_TREAT, world.time + (succeeded ? 30 SECONDS : 10 SECONDS))

/**
 * Fires its gun from the floor at the ground around `target`, not at the person: it can barely aim.
 * Half the rate of a standing shooter. Only for elites and bosses (the soft-crit subtree decides).
 */
/datum/ai_behavior/human_npc_fire_wild
	action_cooldown = 0.5 SECONDS
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/human_npc_fire_wild/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/mob/living/carbon/npc = controller.pawn
	var/atom/target = controller.blackboard[target_key]
	if(npc.stat != SOFT_CRIT || QDELETED(target) || !can_see(npc, target, controller.blackboard[BB_HUMAN_NPC_FIRE_RANGE] || 7))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	var/obj/item/gun/gun = human_npc_loaded_gun(npc)
	if(isnull(gun))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	if(world.time < controller.blackboard[BB_HUMAN_NPC_NEXT_SHOT] || npc.next_move > world.time)
		return AI_BEHAVIOR_DELAY
	if(!human_npc_ready_item(npc, gun))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	var/turf/aim = pick(RANGE_TURFS(1, get_turf(target)))
	controller.ai_interact(target = aim, combat_mode = TRUE)
	controller.set_blackboard_key(BB_HUMAN_NPC_NEXT_SHOT, world.time + 2 * (controller.blackboard[BB_HUMAN_NPC_SHOT_DELAY] || 3 SECONDS))
	return AI_BEHAVIOR_DELAY
