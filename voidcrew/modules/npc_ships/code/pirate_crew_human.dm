/**
 * Pirate crew AI on human NPC bodies (human NPC migration, phase B).
 *
 * The crew AI itself is PR #500's (pirate_crew.dm, pirate_crew_ai.dm): the crew's intel, the captain and
 * guard at the helm, the hunt, door breaking that never vents a ship, swapping places in corridors. This
 * file gives it a human body's hands, through the human NPC base (voidcrew/modules/human_npcs/):
 * - it runs in soft crit and while cuffed (human_npc_ai_able_to_run()), with the soft-crit branch first,
 *   so a downed pirate crawls, pleads and, if it is an elite or a boss, fires wild, and a cuffed one
 *   works at its cuffs;
 * - gunners fire the real gun in their hands in volleys (pirate_guns.dm), reload from the magazines and
 *   shells they carry the way a player does, and fight with a knife or their fists when they run dry;
 * - doors that won't open are pried with a crowbar or a fireaxe it carries (an unpowered airlock, a
 *   firelock), else shot, else hit with a blade heavy enough to dent them;
 * - captains and bosses inject the stimulant they carry when their fight starts; a boss with a flask
 *   drinks from it when hurt; a boss gunner puts its gun to the head of a hunter who is down (the
 *   hyperviolence execution, with its wind-up the crew can interrupt), once a minute at most.
 * Everything goes through ai_interact(), a player's click.
 */

/datum/ai_controller/basic_controller/pirate_crew/human
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic/human_npc,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
		BB_AGGRO_RANGE = PIRATE_CREW_SIGHT_RANGE,
		BB_HUMAN_NPC_SHOT_DELAY = 3 SECONDS,
		BB_HUMAN_NPC_FIRE_RANGE = 7,
		BB_HUMAN_NPC_KEEP_AWAY = 2,
	)
	// Holds still through its own do_afters: a cuff breakout, a gun to someone's head
	ai_traits = PAUSE_DURING_DO_AFTER
	planning_subtrees = list(
		/datum/ai_planning_subtree/human_npc_soft_crit,
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/human_npc_surrender/crewless,
		/datum/ai_planning_subtree/pirate_crew_find_target,
		/datum/ai_planning_subtree/pirate_crew_human_self_care,
		/datum/ai_planning_subtree/npc_combat_sense,
		/datum/ai_planning_subtree/pirate_crew_doors,
		/datum/ai_planning_subtree/human_npc_arm/pirate_crew,
		/datum/ai_planning_subtree/pirate_crew_human_shoot,
		/datum/ai_planning_subtree/human_npc_melee/pirate_crew,
		/datum/ai_planning_subtree/pirate_crew_hold_post,
		/datum/ai_planning_subtree/pirate_crew_hunt,
		/datum/ai_planning_subtree/pirate_crew_leash,
		/datum/ai_planning_subtree/pirate_crewless_home,
	)

/datum/ai_controller/basic_controller/pirate_crew/human/TryPossessPawn(atom/new_pawn)
	if(!ishuman(new_pawn))
		return AI_CONTROLLER_INCOMPATIBLE
	return ..()

// The human NPC base's run check: cuffs and soft crit don't stop it (human_npc_soft_crit.dm).
/datum/ai_controller/basic_controller/pirate_crew/human/get_able_to_run()
	return human_npc_ai_able_to_run(src)

/datum/ai_controller/basic_controller/pirate_crew/human/on_stat_changed(mob/living/source, new_stat)
	. = ..()
	human_npc_ai_stat_changed(src, new_stat)

// A hit during an SMG's spin-up or a shotgun's aim spoils the volley.
/datum/ai_controller/basic_controller/pirate_crew/human/on_pawn_damaged(mob/living/source, damage_dealt)
	. = ..()
	if(damage_dealt <= 0 || blackboard[BB_PIRATE_WINDUP_UNTIL] <= world.time)
		return
	clear_blackboard_key(BB_PIRATE_WINDUP_UNTIL)
	set_blackboard_key(BB_PIRATE_VOLLEY_LEFT, 0)
	set_blackboard_key(BB_HUMAN_NPC_NEXT_SHOT, world.time + 1 SECONDS)

/datum/ai_controller/basic_controller/pirate_crew/human/can_hit_now(atom/target)
	if(QDELETED(target))
		return FALSE
	var/mob/living/carbon/npc = pawn
	var/obj/item/gun/gun = human_npc_loaded_gun(npc)
	if(gun)
		var/datum/pirate_gun_handling/handling = pirate_gun_handling_for(gun)
		var/reach = handling.close_range || blackboard[BB_HUMAN_NPC_FIRE_RANGE] || 7
		return get_dist(npc, target) <= reach && can_see(npc, target, reach)
	return npc.Adjacent(target)

// ===== WITH NO CREW: ruins, planets, contracts =====

/// A pirate with no crew gives up by its family's rules (npc_surrender, human_npc_surrender.dm). One in a
/// crew fights on with it.
/datum/ai_planning_subtree/human_npc_surrender/crewless

/datum/ai_planning_subtree/human_npc_surrender/crewless/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/datum/ai_controller/basic_controller/pirate_crew/pirate_controller = controller
	if(istype(pirate_controller) && pirate_controller.get_crew())
		return
	return ..()

/// A pirate with no crew and nobody to fight walks back to where it was put once it has strayed more
/// than PIRATE_CREWLESS_LEASH tiles (a chase, a flight from its surrender).
/datum/ai_planning_subtree/pirate_crewless_home

/datum/ai_planning_subtree/pirate_crewless_home/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/datum/ai_controller/basic_controller/pirate_crew/pirate_controller = controller
	if(!istype(pirate_controller) || pirate_controller.get_crew() || controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return
	var/turf/home = controller.blackboard[BB_PIRATE_CREWLESS_HOME]
	var/turf/here = get_turf(controller.pawn)
	if(isnull(home) || isnull(here) || home.z != here.z)
		return
	if(get_dist(here, home) <= PIRATE_CREWLESS_LEASH)
		return
	controller.set_blackboard_key(BB_PIRATE_RETURN_TURF, home)
	controller.queue_behavior(/datum/ai_behavior/pirate_crew_travel/leash, BB_PIRATE_RETURN_TURF)
	return SUBTREE_RETURN_FINISH_PLANNING

/// Whether a human crewman fights at range: it holds or carries a gun it can fire, and may use guns.
/proc/pirate_crew_human_gunner(mob/living/carbon/human/npc)
	if(HAS_TRAIT(npc, TRAIT_NOGUNS))
		return FALSE
	if(locate(/obj/item/gun) in npc.held_items)
		return TRUE
	return length(npc.get_all_contents_type(/obj/item/gun)) > 0

// ===== ARMING: the base's reload and draw, with the crew's reload shouts =====

/datum/ai_planning_subtree/human_npc_arm/pirate_crew

/datum/ai_planning_subtree/human_npc_arm/pirate_crew/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/carbon/npc = controller.pawn
	var/obj/item/gun/gun = human_npc_held_gun(npc)
	var/was_dry = gun && !gun.can_shoot()
	// A pump racked between shells is no reload worth shouting about
	var/just_racking = istype(gun, /obj/item/gun/ballistic) && human_npc_gun_needs_rack(gun)
	. = ..()
	if(. != SUBTREE_RETURN_FINISH_PLANNING || !was_dry || just_racking || !prob(PIRATE_CREW_RELOAD_BARK_CHANCE))
		return
	var/datum/pirate_gun_handling/handling = pirate_gun_handling_for(gun)
	var/list/lines = human_npc_can_reload(npc, gun) ? handling.reload_lines : handling.dry_lines
	if(length(lines) && human_npc_can_talk(npc))
		INVOKE_ASYNC(npc, TYPE_PROC_REF(/atom/movable, say), pick(lines))

// ===== SHOOTING =====

/**
 * With a loaded gun in hand: fires its volleys at the target from up to the gun's range (a shotgunner
 * walks in to three tiles first), stepping back from anyone too close, and closing in when it can't see
 * them. A gunner told to hold its ground (target_reach()) shoots back from where it stands and never
 * takes a step after them. A boss gunner whose target is down puts the gun to their head instead.
 */
/datum/ai_planning_subtree/pirate_crew_human_shoot

/datum/ai_planning_subtree/pirate_crew_human_shoot/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(QDELETED(target))
		return
	var/mob/living/carbon/human/npc/npc = controller.pawn
	if(HAS_TRAIT(npc, TRAIT_HANDS_BLOCKED) || LAZYLEN(npc.do_afters))
		return
	var/obj/item/gun/gun = human_npc_loaded_gun(npc)
	if(isnull(gun))
		return
	var/datum/ai_controller/basic_controller/pirate_crew/pirate_controller = controller
	var/hold = istype(pirate_controller) && pirate_controller.target_hold_ground
	if(!hold && pirate_crew_human_wants_execution(controller, npc, target))
		if(npc.Adjacent(target))
			controller.queue_behavior(/datum/ai_behavior/pirate_crew_human_execute, BB_BASIC_MOB_CURRENT_TARGET)
		else
			controller.queue_behavior(/datum/ai_behavior/human_npc_close_in, BB_BASIC_MOB_CURRENT_TARGET, 1)
		return SUBTREE_RETURN_FINISH_PLANNING
	var/datum/pirate_gun_handling/handling = pirate_gun_handling_for(gun)
	var/fire_range = hold ? PIRATE_CREW_SIGHT_RANGE : (handling.close_range || controller.blackboard[BB_HUMAN_NPC_FIRE_RANGE] || 7)
	var/distance = get_dist(npc, target)
	if(distance <= fire_range && can_see(npc, target, fire_range))
		var/keep_away = controller.blackboard[BB_HUMAN_NPC_KEEP_AWAY]
		if(!hold && !handling.close_range && keep_away && distance < keep_away)
			controller.queue_behavior(/datum/ai_behavior/step_away, BB_BASIC_MOB_CURRENT_TARGET)
		controller.queue_behavior(/datum/ai_behavior/pirate_crew_human_shoot, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
		return SUBTREE_RETURN_FINISH_PLANNING
	if(hold)
		return
	controller.queue_behavior(/datum/ai_behavior/human_npc_close_in, BB_BASIC_MOB_CURRENT_TARGET, fire_range)
	return SUBTREE_RETURN_FINISH_PLANNING

/**
 * One pull of the trigger per step of a volley (pirate_guns.dm). A volley that needs a spin-up or a
 * moment's aim waits for it first; a hit in that moment spoils it (the controller's on_pawn_damaged()).
 * Doesn't hold up planning.
 */
/datum/ai_behavior/pirate_crew_human_shoot
	action_cooldown = 0.1 SECONDS
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/pirate_crew_human_shoot/perform(seconds_per_tick, datum/ai_controller/controller, target_key, targeting_strategy_key, hiding_location_key)
	var/mob/living/carbon/npc = controller.pawn
	var/atom/target = controller.blackboard[target_key]
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(controller.blackboard[targeting_strategy_key])
	if(QDELETED(target) || !strategy?.can_attack(npc, target))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	var/obj/item/gun/gun = human_npc_loaded_gun(npc)
	if(isnull(gun))
		// Empty now: the next plan reloads or changes weapon
		controller.set_blackboard_key(BB_PIRATE_VOLLEY_LEFT, 0)
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	var/datum/pirate_gun_handling/handling = pirate_gun_handling_for(gun)
	var/windup_until = controller.blackboard[BB_PIRATE_WINDUP_UNTIL]
	if(windup_until)
		if(world.time < windup_until)
			return AI_BEHAVIOR_DELAY
		controller.clear_blackboard_key(BB_PIRATE_WINDUP_UNTIL)
		controller.set_blackboard_key(BB_PIRATE_VOLLEY_LEFT, handling.shots)
	if(world.time < controller.blackboard[BB_HUMAN_NPC_NEXT_SHOT])
		return AI_BEHAVIOR_DELAY
	if(controller.blackboard[BB_PIRATE_VOLLEY_LEFT] <= 0)
		if(handling.windup)
			npc.face_atom(target)
			if(handling.windup_sound)
				playsound(npc, handling.windup_sound, 50, TRUE)
			controller.set_blackboard_key(BB_PIRATE_WINDUP_UNTIL, world.time + handling.windup)
			return AI_BEHAVIOR_DELAY
		controller.set_blackboard_key(BB_PIRATE_VOLLEY_LEFT, handling.shots)
	var/atom/hiding_target = strategy.find_hidden_mobs(npc, target)
	controller.set_blackboard_key(hiding_location_key, hiding_target)
	var/atom/final_target = hiding_target || target
	if(human_npc_ally_in_line(npc, final_target))
		human_npc_sidestep(npc, final_target)
		return AI_BEHAVIOR_DELAY
	if(!human_npc_ready_item(npc, gun))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	npc.zone_selected = pirate_crew_human_aim_zone(npc, final_target)
	controller.ai_interact(target = final_target, combat_mode = TRUE)
	var/volley_left = controller.blackboard[BB_PIRATE_VOLLEY_LEFT] - 1
	controller.set_blackboard_key(BB_PIRATE_VOLLEY_LEFT, volley_left)
	controller.set_blackboard_key(BB_HUMAN_NPC_NEXT_SHOT, world.time + (volley_left > 0 ? handling.shot_gap : handling.volley_gap))
	return AI_BEHAVIOR_DELAY

/// Where an ordinary shot is aimed. Never the head of someone helpless at point blank: that would be an
/// execution, which only a boss starts, and only on purpose (pirate_crew_human_execute).
/proc/pirate_crew_human_aim_zone(mob/living/shooter, atom/target)
	var/zone = human_npc_pick_aim_zone()
	if(zone == BODY_ZONE_HEAD && isliving(target) && shooter.Adjacent(target))
		var/mob/living/victim = target
		if(victim.hv_can_be_executed())
			return BODY_ZONE_CHEST
	return zone

/// Whether a boss gunner should walk up to `target` and put its gun to their head: it is a boss (OC-9),
/// its execution isn't cooling down, and the target is someone it may execute.
/proc/pirate_crew_human_wants_execution(datum/ai_controller/controller, mob/living/carbon/human/npc/npc, atom/target)
	if(!ishumannpc(npc) || npc.npc_rank < HUMAN_NPC_RANK_BOSS || !isliving(target))
		return FALSE
	if(world.time < controller.blackboard[BB_PIRATE_NEXT_EXECUTION])
		return FALSE
	var/mob/living/victim = target
	if(victim.stat == DEAD || !victim.hv_can_be_executed())
		return FALSE
	var/obj/item/gun/gun = human_npc_loaded_gun(npc)
	return gun?.hv_execution_possible(npc, victim) || (gun && !npc.Adjacent(victim))

/**
 * A boss puts the barrel of its gun to the head of someone down beside it: the hyperviolence execution
 * (executions.dm), a click aimed at the head. Its 1.5 second wind-up is a do_after, so it runs apart
 * from the AI's tick, and the crew can break it by moving either of them.
 */
/datum/ai_behavior/pirate_crew_human_execute
	action_cooldown = 1 SECONDS

/datum/ai_behavior/pirate_crew_human_execute/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/mob/living/carbon/npc = controller.pawn
	var/mob/living/victim = controller.blackboard[target_key]
	var/obj/item/gun/gun = human_npc_loaded_gun(npc)
	if(!isliving(victim) || isnull(gun) || !gun.hv_execution_possible(npc, victim) || !human_npc_ready_item(npc, gun))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	controller.set_blackboard_key(BB_PIRATE_NEXT_EXECUTION, world.time + PIRATE_CREW_EXECUTION_COOLDOWN)
	npc.zone_selected = BODY_ZONE_HEAD
	INVOKE_ASYNC(controller, TYPE_PROC_REF(/datum/ai_controller, ai_interact), victim, TRUE)
	return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED

/// tg melee with what it holds, except against someone it was told to hold its ground against: a gunner
/// whose gun ran dry doesn't run off the battlefield or away from the helm after them.
/datum/ai_planning_subtree/human_npc_melee/pirate_crew

/datum/ai_planning_subtree/human_npc_melee/pirate_crew/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/datum/ai_controller/basic_controller/pirate_crew/pirate_controller = controller
	if(istype(pirate_controller) && pirate_controller.target_hold_ground)
		return
	return ..()

// ===== STIMULANTS AND THE FLASK =====

/**
 * Captains and bosses inject the stimulant they carry once their fight has started (they have someone
 * to fight); a boss carrying a flask drinks from it when it is hurt. Real items used the way a player
 * uses them: the medipen in hand, then used; the flask clicked on itself.
 */
/datum/ai_planning_subtree/pirate_crew_human_self_care

/datum/ai_planning_subtree/pirate_crew_human_self_care/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/carbon/human/npc/npc = controller.pawn
	if(!ishumannpc(npc) || npc.npc_rank < HUMAN_NPC_RANK_ELITE || npc.stat != CONSCIOUS)
		return
	if(HAS_TRAIT(npc, TRAIT_HANDS_BLOCKED) || LAZYLEN(npc.do_afters))
		return
	if(!controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return
	var/obj/item/to_use = pirate_crew_human_stimulant(npc)
	if(isnull(to_use) && npc.health < npc.maxHealth * PIRATE_CREW_DRINK_HEALTH_SHARE && world.time >= controller.blackboard[BB_PIRATE_NEXT_DRINK])
		to_use = pirate_crew_human_flask(npc)
	if(isnull(to_use))
		return
	controller.set_blackboard_key(BB_PIRATE_SELF_ITEM, to_use)
	controller.queue_behavior(/datum/ai_behavior/pirate_crew_human_use_on_self, BB_PIRATE_SELF_ITEM)
	return SUBTREE_RETURN_FINISH_PLANNING

/// A stimulant medipen it carries and hasn't used, unless one is already in its blood.
/proc/pirate_crew_human_stimulant(mob/living/carbon/npc)
	if(npc.reagents?.has_reagent(/datum/reagent/medicine/stimulants))
		return null
	for(var/obj/item/reagent_containers/hypospray/medipen/pen in npc.get_all_contents_type(/obj/item/reagent_containers/hypospray/medipen))
		if(pen.used_up || !pen.reagents?.has_reagent(/datum/reagent/medicine/stimulants))
			continue
		if(npc.is_holding(pen) || human_npc_can_draw(npc, pen))
			return pen
	return null

/// A flask with something left in it that it can take out.
/proc/pirate_crew_human_flask(mob/living/carbon/npc)
	for(var/obj/item/reagent_containers/cup/glass/flask/flask in npc.get_all_contents_type(/obj/item/reagent_containers/cup/glass/flask))
		if(!flask.reagents?.total_volume)
			continue
		if(npc.is_holding(flask) || human_npc_can_draw(npc, flask))
			return flask
	return null

/**
 * Takes the item in a free hand (letting go of a two-handed grip, or holstering a spent gun, if both are
 * full), uses it on itself, puts a flask back and takes up its weapon again.
 */
/datum/ai_behavior/pirate_crew_human_use_on_self
	action_cooldown = 0.8 SECONDS
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/pirate_crew_human_use_on_self/perform(seconds_per_tick, datum/ai_controller/controller, item_key)
	var/mob/living/carbon/human/npc/npc = controller.pawn
	var/obj/item/thing = controller.blackboard[item_key]
	if(QDELETED(thing) || human_npc_holding(thing) != npc || npc.stat != CONSCIOUS)
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	if(!npc.is_holding(thing))
		if(!length(npc.get_empty_held_indexes()) && !pirate_crew_human_free_a_hand(npc))
			return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
		if(!human_npc_take_in_hand(npc, thing))
			return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
		return AI_BEHAVIOR_DELAY
	if(!human_npc_ready_item(npc, thing) || npc.next_move > world.time)
		return AI_BEHAVIOR_DELAY
	if(istype(thing, /obj/item/reagent_containers/hypospray/medipen))
		npc.npc_bark("stimulant", force = TRUE)
		npc.execute_mode()
		var/obj/item/reagent_containers/hypospray/medipen/pen = thing
		if(pen.used_up && npc.is_holding(pen))
			npc.dropItemToGround(pen)
	else
		npc.npc_bark("drink", force = TRUE)
		controller.ai_interact(target = npc, combat_mode = FALSE)
		controller.set_blackboard_key(BB_PIRATE_NEXT_DRINK, world.time + PIRATE_CREW_DRINK_COOLDOWN)
		if(npc.is_holding(thing))
			thing.equip_to_best_slot(npc)
	for(var/obj/item/held in npc.held_items)
		human_npc_ready_weapon(npc, held)
	return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/pirate_crew_human_use_on_self/finish_action(datum/ai_controller/controller, succeeded, item_key)
	. = ..()
	controller.clear_blackboard_key(item_key)
	if(!succeeded)
		// Couldn't get at it; it won't keep trying every tick
		controller.set_blackboard_key(BB_PIRATE_NEXT_DRINK, world.time + PIRATE_CREW_DRINK_COOLDOWN)

/// Frees a hand: lets go of a two-handed grip, or holsters a gun that can't fire. Returns TRUE if a hand is free.
/proc/pirate_crew_human_free_a_hand(mob/living/carbon/npc)
	for(var/obj/item/held in npc.held_items)
		if(held.GetComponent(/datum/component/two_handed) && HAS_TRAIT(held, TRAIT_WIELDED))
			held.attack_self(npc)
			break
	if(length(npc.get_empty_held_indexes()))
		return TRUE
	var/obj/item/gun/spent = human_npc_held_gun(npc)
	if(spent && !spent.can_shoot())
		spent.equip_to_best_slot(npc)
	return length(npc.get_empty_held_indexes()) > 0

// ===== DOORS =====

/**
 * A human crewman breaking through `blocker` (a door or the frame a broken door left), the ways a person
 * can: prying an unpowered airlock or a firelock with a crowbar or fireaxe it carries, shooting the door
 * from a step back, or hitting it with something heavy enough to dent it. Returns FALSE when it has no
 * way to hurt this door, so the crew's breach gives up on it and another member can try.
 */
/proc/pirate_crew_human_breach(datum/ai_controller/controller, mob/living/carbon/human/npc, obj/blocker)
	if(LAZYLEN(npc.do_afters) || HAS_TRAIT(npc, TRAIT_HANDS_BLOCKED) || npc.next_move > world.time)
		return TRUE
	// A pry bar on a door that will give: an airlock with no power that isn't bolted or welded, or a firelock
	var/obj/item/pry_tool = pirate_crew_human_pry_tool(npc)
	if(pry_tool && pirate_crew_human_can_pry(blocker))
		if(npc.Adjacent(blocker) && pirate_crew_human_ready_tool(npc, pry_tool))
			// A crowbar's right click forces a firelock fully open; its left click only holds it
			var/list/modifiers = (istype(blocker, /obj/machinery/door/firedoor) && pry_tool.tool_behaviour == TOOL_CROWBAR) ? list(RIGHT_CLICK = TRUE) : null
			controller.ai_interact(target = blocker, combat_mode = FALSE, modifiers = modifiers)
			return TRUE
	// A gun, from a step back so the shot isn't a bash (pirate_crew_human_breach_spot() puts it there)
	var/obj/item/gun/gun = human_npc_loaded_gun(npc)
	if(gun && !npc.Adjacent(blocker) && get_dist(npc, blocker) <= 3 && can_see(npc, blocker, 3))
		if(human_npc_ready_item(npc, gun))
			npc.face_atom(blocker)
			controller.ai_interact(target = blocker, combat_mode = TRUE)
		return TRUE
	// A blade or a club that dents it
	var/obj/item/weapon = pirate_crew_human_door_weapon(npc, blocker)
	if(weapon)
		if(npc.Adjacent(blocker) && human_npc_ready_item(npc, weapon))
			controller.ai_interact(target = blocker, combat_mode = TRUE)
		return TRUE
	return FALSE

/**
 * Where a crewman works on `blocker` from: the floor beside it (`stand`) to pry or hit it, or for a gunner
 * with nothing to pry it, the floor a step further back, so the shot isn't a bash with the gun.
 */
/proc/pirate_crew_human_breach_spot(mob/living/carbon/human/npc, obj/blocker, turf/stand)
	if(!isturf(stand))
		stand = get_turf(npc)
	if(isnull(human_npc_loaded_gun(npc)))
		return stand
	if(pirate_crew_human_can_pry(blocker) && pirate_crew_human_pry_tool(npc))
		return stand
	var/turf/back = get_step(stand, get_dir(blocker, stand))
	if(back && pirate_turf_standable(back) && can_see(back, blocker, 3))
		return back
	return stand

/// Whether a crowbar or a fireaxe in a person's hands would force `blocker`.
/proc/pirate_crew_human_can_pry(obj/blocker)
	if(istype(blocker, /obj/machinery/door/firedoor))
		var/obj/machinery/door/firedoor/firelock = blocker
		return firelock.density && !firelock.welded && !firelock.operating
	if(!istype(blocker, /obj/machinery/door/airlock))
		return FALSE
	var/obj/machinery/door/airlock/airlock = blocker
	return airlock.density && !airlock.locked && !airlock.welded && !airlock.seal && !airlock.operating && !airlock.hasPower()

/// A crowbar or a fireaxe it holds or can draw.
/proc/pirate_crew_human_pry_tool(mob/living/carbon/npc)
	for(var/obj/item/thing as anything in npc.get_all_contents_type(/obj/item))
		if(!(thing.tool_behaviour == TOOL_CROWBAR || istype(thing, /obj/item/fireaxe)))
			continue
		if(npc.is_holding(thing) || human_npc_can_draw(npc, thing))
			return thing
	return null

/// Gets `tool` into the active hand and ready (a fireaxe wielded), putting away what's in the way.
/// Returns TRUE once it can be used.
/proc/pirate_crew_human_ready_tool(mob/living/carbon/npc, obj/item/tool)
	if(!npc.is_holding(tool))
		if(!length(npc.get_empty_held_indexes()) && !pirate_crew_human_free_a_hand(npc))
			// Both hands still full: put the weaker of what it holds away
			var/obj/item/stowed = npc.get_inactive_held_item() || npc.get_active_held_item()
			if(isnull(stowed) || !stowed.equip_to_best_slot(npc))
				return FALSE
		if(!human_npc_take_in_hand(npc, tool))
			return FALSE
	if(istype(tool, /obj/item/fireaxe))
		human_npc_ready_weapon(npc, tool)
		if(!HAS_TRAIT(tool, TRAIT_WIELDED))
			return FALSE
	return human_npc_ready_item(npc, tool)

/// A melee weapon it holds or can draw that hits `blocker` hard enough to hurt it (its damage
/// deflection), or null.
/proc/pirate_crew_human_door_weapon(mob/living/carbon/npc, obj/blocker)
	var/obj/item/best
	var/best_force = 0
	for(var/obj/item/thing as anything in npc.get_all_contents_type(/obj/item))
		if(!human_npc_is_melee_weapon(thing))
			continue
		if(!npc.is_holding(thing) && !human_npc_can_draw(npc, thing))
			continue
		var/blow = pirate_crew_human_door_blow(thing)
		if(blow > best_force)
			best = thing
			best_force = blow
	if(isnull(best) || best_force < blocker.damage_deflection)
		return null
	if(!npc.is_holding(best))
		if(!length(npc.get_empty_held_indexes()) || !human_npc_take_in_hand(npc, best))
			return null
		human_npc_ready_weapon(npc, best)
	return best

/// What `weapon` hits a door for, as it would be swung: lit, wielded, and with its demolition modifier.
/proc/pirate_crew_human_door_blow(obj/item/weapon)
	var/force = weapon.force
	var/datum/component/transforming/transforming = weapon.GetComponent(/datum/component/transforming)
	if(transforming && !HAS_TRAIT(weapon, TRAIT_TRANSFORM_ACTIVE))
		force = max(force, transforming.force_on)
	var/datum/component/two_handed/two_handed = weapon.GetComponent(/datum/component/two_handed)
	if(two_handed && !HAS_TRAIT(weapon, TRAIT_WIELDED))
		force = max(force, two_handed.force_wielded)
	return force * weapon.demolition_mod
