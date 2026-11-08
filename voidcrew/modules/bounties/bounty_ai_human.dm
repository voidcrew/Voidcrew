/**
 * # Bounty hunting: AI pieces for human bodies
 *
 * Owner: P2 body. Shared by every bounty AI controller (criminals, companions, decoys, mini-bosses,
 * the kingpin's crew, the mafia club), whose pawns are real humans (voidcrew/modules/human_npcs/).
 *
 * - Breaking free (bounty_escape_captivity): tg's escape_captivity, without the cases that would undo
 *   what a criminal chose to do: it never resists out of a chair it sat down on or a locker it hid in.
 *   It works at its cuffs (tg's breakout times), breaks grabs by anyone it may fight, and squirms off a
 *   carrier's shoulders, the way a player does.
 * - Self-treatment (N6, bounty_treat_self): hurt, with nothing it can see attacking it, it uses what it
 *   carries on itself the way a player does: a medipen through the human NPC base's
 *   human_npc_treat_self ("use in hand"), a bruise pack, ointment, suture or mesh clicked on itself on its
 *   worst limb (tg's own self-treatment delay). No heal comes from anywhere else.
 * - Injectors (bounty_ai_use_injector()): a boss's stimulant at the start of a fight, a meek criminal's
 *   stimpack as it bolts: a real pen, used on itself.
 */

// ===== BREAKING FREE =====

/datum/ai_planning_subtree/bounty_escape_captivity
	/// Blackboard key of the targeting strategy that says whose grab it fights
	var/targeting_strategy_key = BB_TARGETING_STRATEGY

/datum/ai_planning_subtree/bounty_escape_captivity/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/carbon/pawn = controller.pawn
	if(!iscarbon(pawn) || pawn.stat != CONSCIOUS)
		return
	if(HAS_TRAIT(pawn, TRAIT_RESTRAINED))
		controller.queue_behavior(/datum/ai_behavior/resist)
		return SUBTREE_RETURN_FINISH_PLANNING
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = istype(pawn, /mob/living/carbon/human/npc/bounty_criminal) ? pawn : null
	// Shut in something it didn't choose to hide in: it gets out the way a person does.
	if(!isturf(pawn.loc) && !ismob(pawn.loc) && !criminal?.hidden)
		controller.queue_behavior(/datum/ai_behavior/resist)
		return SUBTREE_RETURN_FINISH_PLANNING
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(controller.blackboard[targeting_strategy_key])
	var/mob/living/puller = pawn.pulledby
	if(puller && puller.grab_state > GRAB_PASSIVE && bounty_ai_fights_holder(pawn, puller, strategy))
		controller.queue_behavior(/datum/ai_behavior/resist)
		return SUBTREE_RETURN_FINISH_PLANNING
	// Over someone's shoulders, or on a buckle it didn't sit down on, it gets off.
	if(ismob(pawn.buckled))
		if(bounty_ai_fights_holder(pawn, pawn.buckled, strategy))
			controller.queue_behavior(/datum/ai_behavior/resist)
			return SUBTREE_RETURN_FINISH_PLANNING
	else if(pawn.buckled?.buckle_requires_restraints)
		controller.queue_behavior(/datum/ai_behavior/resist)
		return SUBTREE_RETURN_FINISH_PLANNING

/// Whether `pawn` fights its way out of `holder`'s hold: someone it may fight, or any player while it is wanted
/proc/bounty_ai_fights_holder(mob/living/pawn, mob/living/holder, datum/targeting_strategy/strategy)
	if(!isliving(holder) || holder == pawn || pawn.faction_check_atom(holder))
		return FALSE
	if(strategy?.can_attack(pawn, holder))
		return TRUE
	return !isnull(holder.mind) || !isnull(holder.client)

// ===== SELF-TREATMENT (N6) =====

/**
 * Hurt and unthreatened, it treats itself with what it carries. Put it after the fight subtrees: it
 * only plans when nothing before it did, and never with a living hostile in sight that has hurt it.
 */
/datum/ai_planning_subtree/bounty_treat_self

/datum/ai_planning_subtree/bounty_treat_self/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/carbon/pawn = controller.pawn
	if(!iscarbon(pawn) || pawn.stat != CONSCIOUS || HAS_TRAIT(pawn, TRAIT_HANDS_BLOCKED) || LAZYLEN(pawn.do_afters))
		return
	if(world.time < controller.blackboard[BB_HUMAN_NPC_NEXT_TREAT])
		return
	if(pawn.health > pawn.maxHealth * BOUNTY_TREAT_SELF_BELOW)
		return
	if(controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return
	if(bounty_ai_queue_treat_self(controller))
		return SUBTREE_RETURN_FINISH_PLANNING

/**
 * Queues the best treatment `controller`'s pawn carries for itself: a medipen with something in it, else
 * a medical stack that suits its worst hurt. Returns TRUE if it queued one. For a retreat that wants to
 * patch up where it sits.
 */
/proc/bounty_ai_queue_treat_self(datum/ai_controller/controller)
	var/mob/living/carbon/pawn = controller.pawn
	if(!iscarbon(pawn) || world.time < controller.blackboard[BB_HUMAN_NPC_NEXT_TREAT])
		return FALSE
	var/obj/item/reagent_containers/hypospray/medipen/pen = bounty_ai_find_medipen(pawn)
	if(pen)
		controller.set_blackboard_key(BB_HUMAN_NPC_TREAT_ITEM, pen)
		controller.queue_behavior(/datum/ai_behavior/human_npc_treat_self, BB_HUMAN_NPC_TREAT_ITEM)
		return TRUE
	var/obj/item/stack/medical/stack = bounty_ai_find_medical_stack(pawn)
	if(stack)
		controller.set_blackboard_key(BB_HUMAN_NPC_TREAT_ITEM, stack)
		controller.queue_behavior(/datum/ai_behavior/bounty_apply_medical, BB_HUMAN_NPC_TREAT_ITEM)
		return TRUE
	// Nothing to use: it doesn't look again for a while.
	controller.set_blackboard_key(BB_HUMAN_NPC_NEXT_TREAT, world.time + BOUNTY_TREAT_SELF_COOLDOWN)
	return FALSE

/// A medipen it carries with something healing in it (not a stimulant: those are for a fight), that it can reach
/proc/bounty_ai_find_medipen(mob/living/carbon/pawn)
	for(var/obj/item/reagent_containers/hypospray/medipen/pen in pawn.get_all_contents_type(/obj/item/reagent_containers/hypospray/medipen))
		if(pen.used_up || !pen.reagents?.total_volume || bounty_ai_is_stimulant(pen))
			continue
		if(pawn.is_holding(pen) || human_npc_can_draw(pawn, pen))
			return pen
	return null

/// Whether `pen` is a stimulant (a fight drug), not a treatment
/proc/bounty_ai_is_stimulant(obj/item/reagent_containers/hypospray/medipen/pen)
	return istype(pen, /obj/item/reagent_containers/hypospray/medipen/stimpack) || istype(pen, /obj/item/reagent_containers/hypospray/medipen/stimulants) || istype(pen, /obj/item/reagent_containers/hypospray/medipen/methamphetamine)

/// A medical stack it carries and can reach that treats the kind of hurt it has most of
/proc/bounty_ai_find_medical_stack(mob/living/carbon/pawn)
	var/burnt = pawn.getFireLoss() > pawn.getBruteLoss()
	var/obj/item/stack/medical/fallback
	for(var/obj/item/stack/medical/stack in pawn.get_all_contents_type(/obj/item/stack/medical))
		if(stack.amount <= 0 || !(pawn.is_holding(stack) || human_npc_can_draw(pawn, stack)))
			continue
		if((burnt && stack.heal_burn > 0) || (!burnt && stack.heal_brute > 0))
			return stack
		fallback ||= stack
	return fallback

/// The limb of `pawn` with the most brute and burn on it, or the chest
/proc/bounty_ai_worst_limb(mob/living/carbon/pawn)
	var/obj/item/bodypart/worst
	var/worst_damage = 0
	for(var/obj/item/bodypart/limb as anything in pawn.bodyparts)
		var/damage = limb.brute_dam + limb.burn_dam
		if(damage > worst_damage)
			worst = limb
			worst_damage = damage
	return worst?.body_zone || BODY_ZONE_CHEST

/**
 * Applies a medical stack to itself the way a player does: takes it in hand (holstering its gun if both
 * hands are full), aims at its worst limb and clicks itself with it. tg's own self-treatment do_after
 * runs; the AI waits through it.
 */
/datum/ai_behavior/bounty_apply_medical
	action_cooldown = 1 SECONDS
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/bounty_apply_medical/perform(seconds_per_tick, datum/ai_controller/controller, item_key)
	var/mob/living/carbon/pawn = controller.pawn
	var/obj/item/stack/medical/stack = controller.blackboard[item_key]
	if(!istype(stack) || QDELETED(stack) || human_npc_holding(stack) != pawn || pawn.stat != CONSCIOUS)
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	if(LAZYLEN(pawn.do_afters))
		return AI_BEHAVIOR_DELAY
	if(pawn.health > pawn.maxHealth * BOUNTY_TREAT_SELF_BELOW && !pawn.is_holding(stack))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	if(!pawn.is_holding(stack))
		if(!length(pawn.get_empty_held_indexes()))
			var/obj/item/gun/gun = human_npc_held_gun(pawn)
			var/obj/item/stowed = gun || human_npc_held_melee_weapon(pawn)
			if(isnull(stowed) || !stowed.equip_to_best_slot(pawn))
				return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
			return AI_BEHAVIOR_DELAY
		if(!human_npc_take_in_hand(pawn, stack))
			return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
		return AI_BEHAVIOR_DELAY
	// One application per go; it puts the rest away after.
	if(controller.blackboard[BB_BOUNTY_TREAT_APPLIED])
		if(!stack.equip_to_best_slot(pawn))
			pawn.dropItemToGround(stack)
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	if(!human_npc_ready_item(pawn, stack) || pawn.next_move > world.time)
		return AI_BEHAVIOR_DELAY
	pawn.zone_selected = bounty_ai_worst_limb(pawn)
	controller.set_blackboard_key(BB_BOUNTY_TREAT_APPLIED, TRUE)
	controller.ai_interact(target = pawn, combat_mode = FALSE)
	return AI_BEHAVIOR_DELAY

/datum/ai_behavior/bounty_apply_medical/finish_action(datum/ai_controller/controller, succeeded, item_key)
	. = ..()
	controller.clear_blackboard_key(item_key)
	controller.clear_blackboard_key(BB_BOUNTY_TREAT_APPLIED)
	controller.set_blackboard_key(BB_HUMAN_NPC_NEXT_TREAT, world.time + BOUNTY_TREAT_SELF_COOLDOWN)

// ===== INJECTORS =====

/**
 * Has `controller`'s pawn inject `pen` (a medipen or autoinjector it carries) into itself, with a
 * visible emote first: a boss's combat stimulant, a meek criminal's stimpack as it bolts. A real pen and
 * a real dose; what it does is the reagent's. Returns TRUE if the injection is queued.
 */
/proc/bounty_ai_use_injector(datum/ai_controller/controller, obj/item/reagent_containers/hypospray/medipen/pen)
	var/mob/living/carbon/pawn = controller?.pawn
	if(!iscarbon(pawn) || !istype(pen) || QDELETED(pen) || pen.used_up || !pen.reagents?.total_volume)
		return FALSE
	if(human_npc_holding(pen) != pawn || !(pawn.is_holding(pen) || human_npc_can_draw(pawn, pen)))
		return FALSE
	pawn.visible_message(span_warning("[pawn] pulls out [pen]."))
	controller.set_blackboard_key(BB_HUMAN_NPC_TREAT_ITEM, pen)
	controller.queue_behavior(/datum/ai_behavior/human_npc_treat_self, BB_HUMAN_NPC_TREAT_ITEM)
	return TRUE

/// The first unused pen of `pen_type` that `pawn` carries and can reach, or null
/proc/bounty_ai_find_injector(mob/living/carbon/pawn, pen_type = /obj/item/reagent_containers/hypospray/medipen)
	for(var/obj/item/reagent_containers/hypospray/medipen/pen in pawn.get_all_contents_type(pen_type))
		if(pen.used_up || !pen.reagents?.total_volume)
			continue
		if(pawn.is_holding(pen) || human_npc_can_draw(pawn, pen))
			return pen
	return null
