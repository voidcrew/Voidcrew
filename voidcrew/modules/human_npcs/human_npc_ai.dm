// AI for human combat NPCs (human_npc.dm).
//
// Built on tg's basic_controller: it only needs a /mob/living pawn, and its get_able_to_run()
// stops the AI at any stat above CONSCIOUS (soft crit, unconscious, hard crit, dead) and while
// incapacitated, so a downed NPC stops acting and lies there for executions and capture.
// Target finding is stock (simple_find_target / basic targeting strategy). Attacks go through the
// held item with controller.ai_interact(), the same click path a player uses, the way tg's monkey
// AI fires guns: guns run their real fire path (projectiles, wounds, crits, executions), melee
// weapons their real attack chain.

/// Blackboard key: world.time at which the current reload finishes.
#define BB_HUMAN_NPC_RELOAD_DONE_AT "human_npc_reload_done_at"

/datum/ai_controller/basic_controller/human_npc
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
	)
	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = /datum/idle_behavior/idle_random_walk
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/human_npc_combat,
	)

/// Picks between shooting the held gun, reloading it, and meleeing with whatever is held.
/datum/ai_planning_subtree/human_npc_combat

/datum/ai_planning_subtree/human_npc_combat/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	if(!controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return
	var/mob/living/carbon/npc = controller.pawn
	var/obj/item/gun/gun = locate() in npc.held_items
	if(gun)
		if(!gun.can_shoot())
			controller.queue_behavior(/datum/ai_behavior/human_npc_reload)
			return SUBTREE_RETURN_FINISH_PLANNING
		controller.queue_behavior(/datum/ai_behavior/basic_ranged_attack/human_npc, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
		return SUBTREE_RETURN_FINISH_PLANNING
	controller.queue_behavior(/datum/ai_behavior/basic_melee_attack/human_npc, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	return SUBTREE_RETURN_FINISH_PLANNING

/// Body zones an NPC aims at, weighted. Players pick their own zone; an NPC's shots spread out.
/proc/human_npc_pick_aim_zone()
	var/static/list/aim_zones = list(
		BODY_ZONE_CHEST = 40,
		BODY_ZONE_HEAD = 15,
		BODY_ZONE_L_ARM = 10,
		BODY_ZONE_R_ARM = 10,
		BODY_ZONE_L_LEG = 10,
		BODY_ZONE_R_LEG = 10,
		BODY_ZONE_PRECISE_GROIN = 5,
	)
	return pick_weight(aim_zones)

/// Makes `item` the NPC's active hand. Returns FALSE if it isn't held.
/proc/human_npc_ready_item(mob/living/carbon/npc, obj/item/item)
	if(isnull(item))
		return FALSE
	if(npc.get_active_held_item() == item)
		return TRUE
	var/index = npc.get_held_index_of_item(item)
	if(!index)
		return FALSE
	npc.swap_hand(index, silent = TRUE)
	return npc.get_active_held_item() == item

// Ranged: the stock trooper ranged attack (spacing, line of sight, friendly fire check), but the
// shot is a click with the held gun. One shot per 3 seconds matches a trooper gunner's damage
// (two lasers every 6 seconds).
/datum/ai_behavior/basic_ranged_attack/human_npc
	action_cooldown = 3 SECONDS
	required_distance = 5
	avoid_friendly_fire = TRUE

/datum/ai_behavior/basic_ranged_attack/human_npc/perform(seconds_per_tick, datum/ai_controller/controller, target_key, targeting_strategy_key, hiding_location_key)
	var/mob/living/carbon/npc = controller.pawn
	var/atom/target = controller.blackboard[target_key]
	var/datum/targeting_strategy/targeting_strategy = GET_TARGETING_STRATEGY(controller.blackboard[targeting_strategy_key])

	if(!targeting_strategy.can_attack(npc, target, chase_range))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED

	var/obj/item/gun/gun = locate() in npc.held_items
	if(isnull(gun) || !gun.can_shoot())
		// Succeed so the target is kept; the next plan reloads or switches to melee.
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED

	var/atom/hiding_target = targeting_strategy.find_hidden_mobs(npc, target)
	var/atom/final_target = hiding_target || target

	if(!can_see(npc, final_target, required_distance))
		return AI_BEHAVIOR_INSTANT

	if(avoid_friendly_fire && check_friendly_in_path(npc, target, targeting_strategy))
		adjust_position(npc, target)
		return AI_BEHAVIOR_DELAY

	controller.set_blackboard_key(hiding_location_key, hiding_target)
	if(!human_npc_ready_item(npc, gun))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	npc.zone_selected = human_npc_pick_aim_zone()
	controller.ai_interact(target = final_target, combat_mode = TRUE)
	return AI_BEHAVIOR_DELAY

// Melee: stock basic melee attack, which already clicks the target through ai_interact(). We only
// make sure the weapon is in the active hand and pick where to hit.
/datum/ai_behavior/basic_melee_attack/human_npc

/datum/ai_behavior/basic_melee_attack/human_npc/perform(seconds_per_tick, datum/ai_controller/controller, target_key, targeting_strategy_key, hiding_location_key)
	var/mob/living/carbon/npc = controller.pawn
	var/obj/item/weapon = npc.get_active_held_item() || npc.get_inactive_held_item()
	if(weapon)
		human_npc_ready_item(npc, weapon)
	npc.zone_selected = human_npc_pick_aim_zone()
	return ..()

/// Stands still for two seconds, then refills the held gun.
/datum/ai_behavior/human_npc_reload
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/human_npc_reload/setup(datum/ai_controller/controller)
	. = ..()
	var/mob/living/carbon/npc = controller.pawn
	var/obj/item/gun/gun = locate() in npc.held_items
	if(isnull(gun))
		return FALSE
	controller.set_blackboard_key(BB_HUMAN_NPC_RELOAD_DONE_AT, world.time + 2 SECONDS)
	npc.visible_message(span_notice("[npc] reloads [gun]."))
	playsound(npc, 'sound/items/weapons/gun/general/magazine_insert_full.ogg', 40, TRUE)

/datum/ai_behavior/human_npc_reload/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/carbon/npc = controller.pawn
	var/obj/item/gun/gun = locate() in npc.held_items
	if(isnull(gun))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	if(world.time < controller.blackboard[BB_HUMAN_NPC_RELOAD_DONE_AT])
		return AI_BEHAVIOR_DELAY
	gun.npc_refill()
	return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/human_npc_reload/finish_action(datum/ai_controller/controller, succeeded)
	. = ..()
	controller.clear_blackboard_key(BB_HUMAN_NPC_RELOAD_DONE_AT)

#undef BB_HUMAN_NPC_RELOAD_DONE_AT
