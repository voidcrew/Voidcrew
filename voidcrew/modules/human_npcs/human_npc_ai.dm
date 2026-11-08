/**
 * # Human NPC AI
 *
 * Fights through the body's own hands, the way a player does. Everything goes through
 * controller.ai_interact(), which is a player's click (tg's monkey AI and ranged_skirmish use it too):
 * - a gun is fired by clicking the target with it, so the gun's real fire path runs: fire delay,
 *   firing pin, projectile, casing, recoil, wounds and the hyperviolence executions;
 * - a melee weapon (or a fist) hits through the real attack chain;
 * - a reload is the player's reload: the spare magazine comes out of a pocket, belt or bag into the
 *   free hand, the gun is clicked with it (tg's insert or tactical reload), the bolt is racked by
 *   using the gun, and the empty magazine is dropped. Nothing refills from nowhere. When the spares
 *   run out it draws another weapon it carries, or fights with what it holds.
 *
 * tg's basic controller already stops the AI at any stat above CONSCIOUS and while stunned, knocked
 * out, in stamcrit or in stasis. It also stops while cuffed, which would keep tg's escape_captivity
 * subtree from ever working the cuffs; get_able_to_run() below lets a cuffed or grabbed NPC struggle the
 * way a player does (resist), and do_after()s pause it so a breakout isn't cut short by walking. It also
 * lets the AI run in soft crit, where only the soft-crit subtree plans (human_npc_soft_crit.dm).
 *
 * The AI goes off with the body's dormancy: tg switches it off while no player is on the z-level, the
 * same test human_npc.dm uses for Life().
 *
 * Planning order: soft crit (crawl, plead, medipen), escape captivity, walk out (human_npc_states.dm),
 * surrender (human_npc_surrender.dm), then find a target, arm, shoot, melee.
 *
 * Phase B (PR #500's pirate crews) can drop these subtrees into its own planning lists:
 * human_npc_arm, human_npc_shoot and human_npc_melee need only BB_BASIC_MOB_CURRENT_TARGET and
 * BB_TARGETING_STRATEGY; the shooting keys have defaults. The helper procs at the bottom are for
 * any behaviour that has to handle a human NPC's weapons.
 */

/datum/ai_controller/basic_controller/human_npc
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic/human_npc,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
		BB_AGGRO_RANGE = HUMAN_NPC_SIGHT_RANGE,
		BB_HUMAN_NPC_SHOT_DELAY = 3 SECONDS,
		BB_HUMAN_NPC_FIRE_RANGE = 7,
		BB_HUMAN_NPC_KEEP_AWAY = 2,
	)
	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = /datum/idle_behavior/idle_random_walk/less_walking
	planning_subtrees = list(
		/datum/ai_planning_subtree/human_npc_soft_crit,
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/human_npc_walk_out,
		/datum/ai_planning_subtree/human_npc_surrender,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/human_npc_arm,
		/datum/ai_planning_subtree/human_npc_shoot,
		/datum/ai_planning_subtree/human_npc_melee,
	)

/datum/ai_controller/basic_controller/human_npc/TryPossessPawn(atom/new_pawn)
	if(!ishuman(new_pawn))
		return AI_CONTROLLER_INCOMPATIBLE
	// Relays who hit us, so we turn on someone shooting from where we weren't looking
	new_pawn.AddElement(/datum/element/relay_attackers)
	RegisterSignal(new_pawn, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_pawn_attacked))
	return ..()

/datum/ai_controller/basic_controller/human_npc/UnpossessPawn(destroy)
	if(pawn)
		UnregisterSignal(pawn, COMSIG_ATOM_WAS_ATTACKED)
	return ..()

// The basic controller's own check, except that cuffs and soft crit don't stop us (see the top of this
// file, and human_npc_soft_crit.dm).
/datum/ai_controller/basic_controller/human_npc/get_able_to_run()
	return human_npc_ai_able_to_run(src)

/datum/ai_controller/basic_controller/human_npc/on_stat_changed(mob/living/source, new_stat)
	. = ..()
	human_npc_ai_stat_changed(src, new_stat)

/// Someone hit us: with nothing else to fight, fight them, if we can see them.
/datum/ai_controller/basic_controller/human_npc/proc/on_pawn_attacked(mob/living/source, atom/attacker, attack_flags)
	SIGNAL_HANDLER
	if(source == attacker || QDELETED(attacker) || blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(blackboard[BB_TARGETING_STRATEGY])
	if(strategy?.can_attack(source, attacker))
		set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, attacker)

// ===== TARGETING =====

/**
 * tg's basic targeting, but a check made without a range (target finding filters its candidates
 * that way) uses the NPC's sight range instead of can_see()'s default of 5 tiles. It also never
 * picks someone in another packed encounter on the same z-level, who can't be reached across the
 * cordon (the containment the old simple-animal hostiles have in ListTargetsLazy()).
 */
/datum/targeting_strategy/basic/human_npc

/datum/targeting_strategy/basic/human_npc/can_attack(mob/living/living_mob, atom/the_target, vision_range)
	if(isnull(vision_range))
		vision_range = living_mob.ai_controller?.blackboard[BB_AGGRO_RANGE] || HUMAN_NPC_SIGHT_RANGE
	if(!..(living_mob, the_target, vision_range))
		return FALSE
	return !map_region_excludes_turf(map_region_for_turf(get_turf(living_mob)), get_turf(the_target))

// ===== ARMING: RELOAD OR DRAW =====

/// Keeps a usable weapon in hand: reloads a spent gun from the magazines it carries, or draws another weapon.
/datum/ai_planning_subtree/human_npc_arm

/datum/ai_planning_subtree/human_npc_arm/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/carbon/npc = controller.pawn
	if(HAS_TRAIT(npc, TRAIT_HANDS_BLOCKED) || LAZYLEN(npc.do_afters))
		return
	if(world.time < controller.blackboard[BB_HUMAN_NPC_ARMING_RETRY_AT])
		return
	var/obj/item/gun/gun = human_npc_held_gun(npc)
	if(gun?.can_shoot())
		return
	if(human_npc_can_reload(npc, gun))
		controller.queue_behavior(/datum/ai_behavior/human_npc_reload)
		return SUBTREE_RETURN_FINISH_PLANNING
	if(human_npc_held_melee_weapon(npc))
		return
	var/obj/item/backup = human_npc_backup_weapon(npc)
	if(isnull(backup))
		return
	controller.set_blackboard_key(BB_HUMAN_NPC_DRAW_ITEM, backup)
	controller.queue_behavior(/datum/ai_behavior/human_npc_draw, BB_HUMAN_NPC_DRAW_ITEM)
	return SUBTREE_RETURN_FINISH_PLANNING

/**
 * A player's reload, one step per action: drop the spent magazine, rack a loaded gun, take a spare
 * into the free hand, click the gun with it. Fails, and the NPC fights on with something else, if
 * it has no spare or no hand free.
 */
/datum/ai_behavior/human_npc_reload
	action_cooldown = 0.8 SECONDS
	/// Gives up after this long, so a gun that won't take what it carries can't hold the NPC forever
	var/give_up_after = 8 SECONDS

/datum/ai_behavior/human_npc_reload/setup(datum/ai_controller/controller)
	. = ..()
	var/mob/living/carbon/npc = controller.pawn
	var/obj/item/gun/ballistic/gun = human_npc_held_gun(npc)
	if(!istype(gun))
		return FALSE
	controller.set_blackboard_key(BB_HUMAN_NPC_RELOAD_UNTIL, world.time + give_up_after)
	npc.visible_message(span_notice("[npc] reloads [gun]."))

/datum/ai_behavior/human_npc_reload/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/carbon/npc = controller.pawn
	var/obj/item/gun/ballistic/gun = human_npc_held_gun(npc)
	if(!istype(gun) || world.time >= controller.blackboard[BB_HUMAN_NPC_RELOAD_UNTIL])
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	var/obj/item/spent = human_npc_spent_ammo_in_hand(npc, gun)
	if(spent)
		npc.dropItemToGround(spent, force = TRUE)
		return AI_BEHAVIOR_DELAY
	if(gun.can_shoot())
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	if(human_npc_gun_needs_rack(gun))
		if(!human_npc_ready_item(npc, gun))
			return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
		controller.ai_interact(target = gun, combat_mode = FALSE)
		return AI_BEHAVIOR_DELAY
	var/obj/item/ammo = human_npc_find_ammo(npc, gun)
	if(isnull(ammo))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	if(!npc.is_holding(ammo))
		if(!human_npc_take_in_hand(npc, ammo))
			return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
		return AI_BEHAVIOR_DELAY
	if(!human_npc_ready_item(npc, ammo))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	controller.ai_interact(target = gun, combat_mode = FALSE)
	return AI_BEHAVIOR_DELAY

/datum/ai_behavior/human_npc_reload/finish_action(datum/ai_controller/controller, succeeded)
	. = ..()
	// A reload that got nowhere isn't tried again straight away; the NPC fights with what it has.
	controller.set_blackboard_key(BB_HUMAN_NPC_ARMING_RETRY_AT, succeeded ? 0 : world.time + 10 SECONDS)

/// Takes another weapon it carries into hand: a loaded gun, or failing that a melee weapon.
/datum/ai_behavior/human_npc_draw
	action_cooldown = 0.6 SECONDS

/datum/ai_behavior/human_npc_draw/perform(seconds_per_tick, datum/ai_controller/controller, item_key)
	var/mob/living/carbon/npc = controller.pawn
	var/obj/item/weapon = controller.blackboard[item_key]
	if(QDELETED(weapon) || human_npc_holding(weapon) != npc)
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	if(!npc.is_holding(weapon))
		if(!length(npc.get_empty_held_indexes()))
			// Both hands full: holster the spent gun first, if it has somewhere to go.
			var/obj/item/gun/spent = human_npc_held_gun(npc)
			if(isnull(spent) || spent.can_shoot() || !spent.equip_to_best_slot(npc))
				return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
			return AI_BEHAVIOR_DELAY
		if(!human_npc_take_in_hand(npc, weapon))
			return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	human_npc_ready_weapon(npc, weapon)
	human_npc_ready_item(npc, weapon)
	return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/human_npc_draw/finish_action(datum/ai_controller/controller, succeeded, item_key)
	. = ..()
	controller.clear_blackboard_key(item_key)
	if(!succeeded)
		controller.set_blackboard_key(BB_HUMAN_NPC_ARMING_RETRY_AT, world.time + 10 SECONDS)

// ===== SHOOTING =====

/**
 * With a loaded gun in hand: shoots the target from up to BB_HUMAN_NPC_FIRE_RANGE, stepping back
 * from anyone closer than BB_HUMAN_NPC_KEEP_AWAY, and closes in when it can't see them or they are
 * too far.
 */
/datum/ai_planning_subtree/human_npc_shoot

/datum/ai_planning_subtree/human_npc_shoot/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(QDELETED(target))
		return
	var/mob/living/carbon/npc = controller.pawn
	if(HAS_TRAIT(npc, TRAIT_HANDS_BLOCKED) || isnull(human_npc_loaded_gun(npc)))
		return
	var/fire_range = controller.blackboard[BB_HUMAN_NPC_FIRE_RANGE] || 7
	var/distance = get_dist(npc, target)
	if(distance <= fire_range && can_see(npc, target, fire_range))
		var/keep_away = controller.blackboard[BB_HUMAN_NPC_KEEP_AWAY]
		if(keep_away && distance < keep_away && !LAZYLEN(npc.do_afters))
			controller.queue_behavior(/datum/ai_behavior/step_away, BB_BASIC_MOB_CURRENT_TARGET)
		controller.queue_behavior(/datum/ai_behavior/human_npc_shoot, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	else
		controller.queue_behavior(/datum/ai_behavior/human_npc_close_in, BB_BASIC_MOB_CURRENT_TARGET, fire_range)
	return SUBTREE_RETURN_FINISH_PLANNING

/// One pull of the trigger, then a wait of BB_HUMAN_NPC_SHOT_DELAY. Doesn't hold up planning.
/datum/ai_behavior/human_npc_shoot
	action_cooldown = 0.5 SECONDS
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/human_npc_shoot/perform(seconds_per_tick, datum/ai_controller/controller, target_key, targeting_strategy_key, hiding_location_key)
	var/mob/living/carbon/npc = controller.pawn
	var/atom/target = controller.blackboard[target_key]
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(controller.blackboard[targeting_strategy_key])
	if(QDELETED(target) || !strategy?.can_attack(npc, target))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	var/obj/item/gun/gun = human_npc_loaded_gun(npc)
	if(isnull(gun))
		// Empty now: the next plan reloads or changes weapon.
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	if(world.time < controller.blackboard[BB_HUMAN_NPC_NEXT_SHOT])
		return AI_BEHAVIOR_DELAY
	var/atom/hiding_target = strategy.find_hidden_mobs(npc, target)
	controller.set_blackboard_key(hiding_location_key, hiding_target)
	var/atom/final_target = hiding_target || target
	if(human_npc_ally_in_line(npc, final_target))
		human_npc_sidestep(npc, final_target)
		return AI_BEHAVIOR_DELAY
	if(!human_npc_ready_item(npc, gun))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	npc.zone_selected = human_npc_pick_aim_zone()
	controller.ai_interact(target = final_target, combat_mode = TRUE)
	controller.set_blackboard_key(BB_HUMAN_NPC_NEXT_SHOT, world.time + (controller.blackboard[BB_HUMAN_NPC_SHOT_DELAY] || 3 SECONDS))
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/// Walks at the target until it is within `range` and in sight.
/datum/ai_behavior/human_npc_close_in
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/human_npc_close_in/setup(datum/ai_controller/controller, target_key, range)
	. = ..()
	var/atom/target = controller.blackboard[target_key]
	if(QDELETED(target))
		return FALSE
	set_movement_target(controller, target)

/datum/ai_behavior/human_npc_close_in/perform(seconds_per_tick, datum/ai_controller/controller, target_key, range)
	var/atom/target = controller.blackboard[target_key]
	if(QDELETED(target))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	if(get_dist(controller.pawn, target) <= range && can_see(controller.pawn, target, range))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_INSTANT

// ===== MELEE =====

/// With no loaded gun: walks up and hits with the best melee weapon held, or a fist.
/datum/ai_planning_subtree/human_npc_melee

/datum/ai_planning_subtree/human_npc_melee/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	if(!controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return
	controller.queue_behavior(/datum/ai_behavior/basic_melee_attack/human_npc, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	return SUBTREE_RETURN_FINISH_PLANNING

// tg's basic melee attack already clicks the target through ai_interact(); this picks what to hit with and where.
/datum/ai_behavior/basic_melee_attack/human_npc

/datum/ai_behavior/basic_melee_attack/human_npc/perform(seconds_per_tick, datum/ai_controller/controller, target_key, targeting_strategy_key, hiding_location_key)
	var/mob/living/carbon/npc = controller.pawn
	var/obj/item/weapon = human_npc_held_melee_weapon(npc)
	if(weapon)
		human_npc_ready_item(npc, weapon)
	else
		human_npc_ready_empty_hand(npc)
	npc.zone_selected = human_npc_pick_aim_zone()
	return ..()

// ===== HELPERS =====

/// Body zones an NPC aims at, weighted. A player picks their own zone; an NPC's hits spread out.
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

/// Makes `item` the active hand. Returns FALSE if `npc` isn't holding it.
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

/// Makes an empty hand the active one, for a punch. Returns FALSE if both hands are full.
/proc/human_npc_ready_empty_hand(mob/living/carbon/npc)
	if(isnull(npc.get_active_held_item()))
		return TRUE
	var/list/empty = npc.get_empty_held_indexes()
	if(!length(empty))
		return FALSE
	npc.swap_hand(empty[1], silent = TRUE)
	return isnull(npc.get_active_held_item())

/// Switches on or wields a weapon in hand the way its user would: energy blades, batons, two-handed weapons.
/proc/human_npc_ready_weapon(mob/living/carbon/npc, obj/item/weapon)
	if(QDELETED(weapon) || !npc.is_holding(weapon))
		return
	if(weapon.GetComponent(/datum/component/transforming))
		if(!HAS_TRAIT(weapon, TRAIT_TRANSFORM_ACTIVE))
			weapon.attack_self(npc)
		return
	if(istype(weapon, /obj/item/melee/baton/security))
		var/obj/item/melee/baton/security/baton = weapon
		if(!baton.active)
			baton.attack_self(npc)
		return
	if(weapon.GetComponent(/datum/component/two_handed) && !HAS_TRAIT(weapon, TRAIT_WIELDED) && length(npc.get_empty_held_indexes()))
		weapon.attack_self(npc)

/// The gun it holds, preferring one that can fire.
/proc/human_npc_held_gun(mob/living/carbon/npc)
	var/obj/item/gun/found
	for(var/obj/item/gun/gun in npc.held_items)
		if(gun.can_shoot())
			return gun
		found ||= gun
	return found

/// A gun it holds that can fire right now, or null.
/proc/human_npc_loaded_gun(mob/living/carbon/npc)
	for(var/obj/item/gun/gun in npc.held_items)
		if(gun.can_shoot())
			return gun
	return null

/// Whether `item` is any use as a melee weapon.
/proc/human_npc_is_melee_weapon(obj/item/item)
	if(isnull(item) || isgun(item) || isbodypart(item) || isorgan(item) || (item.item_flags & ABSTRACT))
		return FALSE
	// Energy blades and batons are weak until switched on.
	return item.force >= 10 || item.GetComponent(/datum/component/transforming) || istype(item, /obj/item/melee/baton)

/// The best melee weapon it holds, or null.
/proc/human_npc_held_melee_weapon(mob/living/carbon/npc)
	var/obj/item/best
	for(var/obj/item/held in npc.held_items)
		if(human_npc_is_melee_weapon(held) && (isnull(best) || held.force > best.force))
			best = held
	return best

/// Something better to fight with that it carries but doesn't hold: a loaded gun first, then the strongest melee weapon.
/proc/human_npc_backup_weapon(mob/living/carbon/npc)
	var/obj/item/best_melee
	for(var/obj/item/thing as anything in npc.get_all_contents_type(/obj/item))
		if(npc.is_holding(thing) || !human_npc_can_draw(npc, thing))
			continue
		if(isgun(thing))
			var/obj/item/gun/spare = thing
			if(spare.can_shoot())
				return spare
			continue
		if(human_npc_is_melee_weapon(thing) && (isnull(best_melee) || thing.force > best_melee.force))
			best_melee = thing
	return best_melee

/// Whether `item` is somewhere a person can take it from in a moment: a worn slot, or a bag or pouch it wears.
/proc/human_npc_can_draw(mob/living/carbon/npc, obj/item/item)
	if(isbodypart(item) || isorgan(item) || istype(item, /obj/item/implant))
		return FALSE
	if(item.loc == npc)
		return !isnull(npc.get_slot_by_item(item))
	var/obj/item/container = item.loc
	return istype(container) && !isnull(container.atom_storage) && human_npc_holding(container) == npc

/// Takes `item` out of a slot or a bag into a free hand. Returns TRUE if it ends up held.
/proc/human_npc_take_in_hand(mob/living/carbon/npc, obj/item/item)
	if(npc.is_holding(item))
		return TRUE
	if(!length(npc.get_empty_held_indexes()) || !human_npc_can_draw(npc, item))
		return FALSE
	if(item.loc == npc)
		if(!npc.temporarilyRemoveItemFromInventory(item))
			return FALSE
	else
		var/obj/item/container = item.loc
		if(!container.atom_storage.attempt_remove(item, npc, silent = TRUE))
			return FALSE
	if(npc.put_in_hands(item))
		return TRUE
	npc.equip_to_appropriate_slot(item)
	return FALSE

/// Live rounds in a magazine, box or casing.
/proc/human_npc_live_rounds(obj/item/ammo)
	if(isammocasing(ammo))
		var/obj/item/ammo_casing/casing = ammo
		return casing.loaded_projectile ? 1 : 0
	if(istype(ammo, /obj/item/ammo_box/magazine))
		var/obj/item/ammo_box/magazine/magazine = ammo
		return magazine.ammo_count(FALSE)
	var/obj/item/ammo_box/box = ammo
	if(!istype(box))
		return 0
	. = 0
	for(var/obj/item/ammo_casing/round as anything in box.stored_ammo)
		if(ispath(round) || round.loaded_projectile)
			.++

/// Whether a ballistic gun has live rounds loaded but none chambered, so using it (rack, pump, drop the bolt) readies it.
/proc/human_npc_gun_needs_rack(obj/item/gun/ballistic/gun)
	if(gun.bolt_type == BOLT_TYPE_NO_BOLT || gun.chambered?.loaded_projectile)
		return FALSE
	return gun.magazine && human_npc_live_rounds(gun.magazine) > 0

/// Spare ammunition it carries that `gun` takes: a loaded magazine for a detachable-magazine gun,
/// or a box, clip, speedloader or loose round of its calibre for one with an internal magazine.
/proc/human_npc_find_ammo(mob/living/carbon/npc, obj/item/gun/ballistic/gun)
	if(!istype(gun))
		return null
	// Whatever is already in hand first, then pockets, belt and bags.
	for(var/obj/item/held in npc.held_items)
		if(held != gun && human_npc_ammo_fits(gun, held))
			return held
	for(var/obj/item/thing as anything in npc.get_all_contents_type(/obj/item))
		if(npc.is_holding(thing) || thing == gun.magazine || thing.loc == gun || !human_npc_can_draw(npc, thing))
			continue
		if(human_npc_ammo_fits(gun, thing))
			return thing
	return null

/// Whether `ammo` loads `gun` and has a live round in it.
/proc/human_npc_ammo_fits(obj/item/gun/ballistic/gun, obj/item/ammo)
	if(!gun.internal_magazine)
		return istype(ammo, gun.accepted_magazine_type) && human_npc_live_rounds(ammo) > 0
	var/caliber = gun.magazine?.caliber
	if(isnull(caliber))
		return FALSE
	if(istype(ammo, /obj/item/ammo_box))
		var/obj/item/ammo_box/box = ammo
		return box.caliber == caliber && human_npc_live_rounds(box) > 0
	if(isammocasing(ammo))
		var/obj/item/ammo_casing/casing = ammo
		return casing.caliber == caliber && !isnull(casing.loaded_projectile)
	return FALSE

/// Whether it carries anything that makes `gun` fire again.
/proc/human_npc_can_reload(mob/living/carbon/npc, obj/item/gun/ballistic/gun)
	if(!istype(gun))
		return FALSE
	return human_npc_gun_needs_rack(gun) || !isnull(human_npc_find_ammo(npc, gun))

/// A spent magazine, empty box or spent casing in its hands that's no use to `gun`.
/proc/human_npc_spent_ammo_in_hand(mob/living/carbon/npc, obj/item/gun/ballistic/gun)
	for(var/obj/item/held in npc.held_items)
		if(held == gun || !(istype(held, /obj/item/ammo_box) || isammocasing(held)))
			continue
		if(!human_npc_live_rounds(held))
			return held
	return null

/// Whether an ally stands between `shooter` and `target`. Shots pass over anyone lying down.
/proc/human_npc_ally_in_line(mob/living/shooter, atom/target)
	var/turf/shooter_turf = get_turf(shooter)
	var/turf/target_turf = get_turf(target)
	for(var/turf/line_turf as anything in get_line(shooter_turf, target_turf))
		if(line_turf == shooter_turf || line_turf == target_turf)
			continue
		for(var/mob/living/other in line_turf)
			if(other.stat == DEAD || other.body_position == LYING_DOWN)
				continue
			if(shooter.faction_check_atom(other))
				return TRUE
	return FALSE

/// One step sideways, keeping no further from the target, for a clear shot.
/proc/human_npc_sidestep(mob/living/shooter, atom/target)
	var/turf/our_turf = get_turf(shooter)
	var/list/possible_turfs = list()
	for(var/direction in GLOB.alldirs)
		var/turf/step_turf = get_step(our_turf, direction)
		if(isnull(step_turf) || step_turf.is_blocked_turf() || get_dist(step_turf, target) > get_dist(shooter, target))
			continue
		possible_turfs += step_turf
	if(!length(possible_turfs))
		return
	var/turf/picked = pick(possible_turfs)
	step(shooter, get_dir(shooter, picked))
