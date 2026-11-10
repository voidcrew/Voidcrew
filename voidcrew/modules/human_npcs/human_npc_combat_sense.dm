/**
 * # Combat sense
 *
 * Armed hostile human NPCs that opt in fight back against stun weapons the way a player does, through
 * the body's own systems. Two parts:
 * - A stimulant when it tires. Past HUMAN_NPC_SENSE_STIM_SHARE of the stamina loss that would stamcrit
 *   it, and still in a fight, it takes a stimulant pen it carries into a free hand and uses it (tg's
 *   use in hand, so the pen's real reagents go in). Only what it carries, and never while a stimulant
 *   is already in its blood. What a family carries is its outfit's business: see each family's file.
 * - Stun fire. Hit by a shot that does stamina damage (a disabler bolt, a rubber round), it stops
 *   standing in the open. A gunner runs to the nearest tile out of the shooter's line of fire
 *   (human_npc_find_cover()) and keeps its head down for a moment, longer while it is winded (which is
 *   when tg's own stamina recovery catches up with it). Then the family's own fight subtrees walk it
 *   back out to shoot: it peeks. Three runs for cover in one exchange, then it stands and fights. A
 *   fighter that hits from close (a blade, fists, a shotgun) charges the shooter instead.
 *
 * Every move goes through the AI's movement (the controller's own movement type, so a family's leash
 * pathing applies, at the body's real move delay: basic controllers track cached_multiplicative_slowdown).
 * Every reaction shows in the world first ("ducks for cover!"). A family's rules say which tiles it may
 * use (tile_ok(): a criminal's leash, a pirate crew's battlefield, a guard's wing).
 *
 * Nothing here touches the body: no immunity, no stamina, health or stun change, no stand-in state.
 * Cuffed, in crit, stunned, in stamcrit, knocked down, grabbed, giving up or walking out, it does nothing
 * (can_act(); tg's controller also stops the AI in stamcrit and stuns).
 *
 * Opting in: a human NPC type sets npc_combat_sense to a /datum/npc_combat_sense typepath (its family's
 * rules), and its controller lists /datum/ai_planning_subtree/npc_combat_sense where it should plan: after
 * soft crit, breaking free, walking out, surrender and finding a target, and before arming and attacking.
 * Civilians, townsfolk and prisoners never set it. Anything else may AddComponent(/datum/component/
 * npc_combat_sense, rules_type) on a human NPC whose controller lists the subtree, and subclass
 * /datum/npc_combat_sense to change the numbers or any step (a bounty boss, say).
 */

// ===== THE RULES =====

/**
 * How a family uses its combat sense. One shared instance per type (human_npc_singleton()). The vars are
 * the numbers; each proc is a step a family may override.
 */
/datum/npc_combat_sense
	/// Whether it uses stimulant pens it carries when it tires
	var/use_stims = TRUE
	/// Stamina loss, as a share of what stamcrits it, at which it reaches for a stimulant
	var/stim_share = HUMAN_NPC_SENSE_STIM_SHARE
	/// Whether stun fire makes it move at all
	var/react_to_stun_fire = TRUE
	/// How long after its last stun hit it keeps reacting
	var/react_time = HUMAN_NPC_SENSE_REACT_TIME
	/// The furthest it walks to cover, in steps
	var/cover_steps = HUMAN_NPC_SENSE_COVER_STEPS
	/// How long it keeps its head down before it looks out
	var/peek_after = HUMAN_NPC_SENSE_PEEK_AFTER
	/// The longest it stays down while winded
	var/max_hold = HUMAN_NPC_SENSE_MAX_HOLD
	/// Runs for cover per exchange of fire before it stands and fights
	var/cover_moves = HUMAN_NPC_SENSE_COVER_MOVES
	/// A fighter that hits from this close charges the shooter instead of taking cover. 0: it never charges.
	var/close_in_reach = HUMAN_NPC_SENSE_CLOSE_IN_REACH

/**
 * Whether it can do anything about a fight right now: on its feet and free. Never cuffed, grabbed,
 * buckled, stunned, knocked down, in crit, busy with a do_after, giving up or walking out.
 */
/datum/npc_combat_sense/proc/can_act(mob/living/carbon/human/npc, datum/ai_controller/controller)
	if(npc.stat != CONSCIOUS || !isturf(npc.loc) || npc.buckled || npc.pulledby)
		return FALSE
	if(HAS_TRAIT(npc, TRAIT_RESTRAINED) || HAS_TRAIT(npc, TRAIT_HANDS_BLOCKED) || HAS_TRAIT(npc, TRAIT_INCAPACITATED))
		return FALSE
	if(HAS_TRAIT(npc, TRAIT_IMMOBILIZED) || HAS_TRAIT(npc, TRAIT_FLOORED) || npc.body_position == LYING_DOWN)
		return FALSE
	if(LAZYLEN(npc.do_afters))
		return FALSE
	var/mob/living/carbon/human/npc/human_npc = npc
	if(istype(human_npc) && (human_npc.npc_surrendering || human_npc.npc_exit))
		return FALSE
	return TRUE

/// Whether it is in a fight: it has a target, or someone is shooting stun rounds at it.
/datum/npc_combat_sense/proc/in_fight(mob/living/carbon/human/npc, datum/ai_controller/controller, datum/component/npc_combat_sense/sense)
	return controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET) || sense.under_fire()

/// Whether it is winded: stamina loss past stim_share of what would stamcrit it.
/datum/npc_combat_sense/proc/winded(mob/living/carbon/human/npc)
	return npc.getStaminaLoss() >= stim_share * (npc.maxHealth - npc.crit_threshold)

/// A stimulant pen it carries and could take out now, or null.
/datum/npc_combat_sense/proc/find_stim(mob/living/carbon/human/npc)
	return human_npc_find_stim(npc)

/// Whether the one who fired `shooter`'s stun shot is on its side, so the shot is friendly fire.
/datum/npc_combat_sense/proc/allied(mob/living/carbon/human/npc, atom/shooter)
	return isliving(shooter) && npc.faction_check_atom(shooter)

/// Whether a stun shot from `shooter` is one to react to: a person or a mech, not itself, not a friend.
/datum/npc_combat_sense/proc/threat_ok(mob/living/carbon/human/npc, atom/shooter)
	if(QDELETED(shooter) || shooter == npc || !(isliving(shooter) || ismecha(shooter)))
		return FALSE
	return !allied(npc, shooter)

/**
 * How close it fights from, in tiles: its gun's range if it holds or carries one that fires (the shooting
 * subtrees' BB_HUMAN_NPC_FIRE_RANGE), else 1. At or under close_in_reach it charges; over it, it takes cover.
 */
/datum/npc_combat_sense/proc/reach(mob/living/carbon/human/npc, datum/ai_controller/controller)
	if(HAS_TRAIT(npc, TRAIT_NOGUNS))
		return 1
	if(human_npc_held_gun(npc) || isgun(human_npc_backup_weapon(npc)))
		return controller.blackboard[BB_HUMAN_NPC_FIRE_RANGE] || 7
	return 1

/// Whether it may leave where it stands for this fight at all (a pirate holding the helm's line doesn't).
/datum/npc_combat_sense/proc/may_move(mob/living/carbon/human/npc, datum/ai_controller/controller)
	return TRUE

/**
 * Whether it may stand on `tile` (and walk through it on the way to cover): open floor that is safe to
 * cross, in the NPC's own map region. Families add their leash.
 */
/datum/npc_combat_sense/proc/tile_ok(mob/living/carbon/human/npc, datum/ai_controller/controller, turf/tile)
	if(!isopenturf(tile) || isspaceturf(tile) || isopenspaceturf(tile) || isgroundlessturf(tile) || islava(tile) || ischasm(tile))
		return FALSE
	if(!tile.can_cross_safely(npc))
		return FALSE
	return !map_region_excludes_turf(map_region_for_turf(get_turf(npc)), tile)

/// The nearest tile it may reach that is out of a shot's line from `threat_turf`, or null.
/datum/npc_combat_sense/proc/find_cover(mob/living/carbon/human/npc, datum/ai_controller/controller, turf/threat_turf, pass_flags)
	return human_npc_find_cover(npc, threat_turf, cover_steps, pass_flags, CALLBACK(src, PROC_REF(tile_ok), npc, controller))

/// How long it keeps down in cover it reached at `arrived_at`: peek_after, or up to max_hold while winded.
/datum/npc_combat_sense/proc/hold_until(mob/living/carbon/human/npc, datum/component/npc_combat_sense/sense)
	return sense.arrived_at + (winded(npc) ? max_hold : peek_after)

/**
 * What the people around see it do, before it does it (and a line from its voice, if its family has one
 * for `kind`). In the world and in character: no rules, no numbers.
 */
/datum/npc_combat_sense/proc/telegraph(mob/living/carbon/human/npc, kind, atom/about, obj/item/used)
	switch(kind)
		if(HUMAN_NPC_BARK_TAKE_COVER)
			npc.visible_message(span_warning("[npc] ducks for cover!"))
		if(HUMAN_NPC_BARK_CHARGE)
			npc.visible_message(span_warning("[npc] charges at [about]!"))
		if(HUMAN_NPC_BARK_STIMULANT)
			npc.visible_message(span_warning("[npc] jabs [used] into [npc.p_their()] thigh."))
			return
	var/mob/living/carbon/human/npc/human_npc = npc
	if(istype(human_npc))
		human_npc.npc_bark(kind)

// ===== PLANNING =====

/**
 * One plan. Under stun fire a gunner gets out of the line of fire first and uses its stimulant from
 * cover; out of cover's reach (none near, out of runs, looking out) it uses the stimulant where it is.
 * A close fighter takes its stimulant first, then charges. Returns SUBTREE_RETURN_FINISH_PLANNING while it
 * is doing something about it, so the attacks below wait.
 */
/datum/npc_combat_sense/proc/plan(mob/living/carbon/human/npc, datum/ai_controller/controller, datum/component/npc_combat_sense/sense)
	if(!can_act(npc, controller))
		sense.stand_down(controller)
		return
	var/under_fire = sense.under_fire()
	if(!under_fire && sense.hits)
		sense.end_exchange(controller)
	var/reacting = under_fire && react_to_stun_fire && may_move(npc, controller)
	var/close_fighter = reacting && close_in_reach && reach(npc, controller) <= close_in_reach
	if(reacting && !close_fighter)
		. = plan_cover(npc, controller, sense)
		if(.)
			return
	if(plan_stim(npc, controller, sense))
		return SUBTREE_RETURN_FINISH_PLANNING
	if(close_fighter)
		return plan_close_in(npc, controller, sense)

/// Queues the stimulant it wants now, if any. Returns TRUE if it did.
/datum/npc_combat_sense/proc/plan_stim(mob/living/carbon/human/npc, datum/ai_controller/controller, datum/component/npc_combat_sense/sense)
	var/obj/item/reagent_containers/hypospray/medipen/stim = wants_stim(npc, controller, sense)
	if(isnull(stim))
		return FALSE
	controller.set_blackboard_key(BB_HUMAN_NPC_STIM_ITEM, stim)
	controller.queue_behavior(/datum/ai_behavior/npc_combat_sense_stim, BB_HUMAN_NPC_STIM_ITEM)
	return TRUE

/// The stimulant pen it should use now, or null: the one in hand from the last plan, or one it carries while winded in a fight.
/datum/npc_combat_sense/proc/wants_stim(mob/living/carbon/human/npc, datum/ai_controller/controller, datum/component/npc_combat_sense/sense)
	if(!use_stims || world.time < sense.next_stim_at)
		return null
	var/obj/item/reagent_containers/hypospray/medipen/using = controller.blackboard[BB_HUMAN_NPC_STIM_ITEM]
	if(istype(using) && !QDELETED(using) && human_npc_is_stim(using) && human_npc_holding(using) == npc)
		return using
	if(!winded(npc) || !in_fight(npc, controller, sense) || human_npc_stimmed(npc))
		return null
	. = find_stim(npc)
	// Nothing on it: don't turn its pockets out again every plan
	if(isnull(.))
		sense.next_stim_at = world.time + HUMAN_NPC_SENSE_STIM_RETRY

/**
 * A gunner under stun fire: on the way to cover, it keeps going; in cover, it keeps down (using its
 * stimulant or reloading there if it needs to) until it is time to look out or the shooter can see it
 * there anyway; in the open, each new stun hit is weighed once, and it runs for the nearest cover if it
 * has runs left. Returns null when it has nothing to do about it here.
 */
/datum/npc_combat_sense/proc/plan_cover(mob/living/carbon/human/npc, datum/ai_controller/controller, datum/component/npc_combat_sense/sense)
	var/turf/here = get_turf(npc)
	var/turf/threat_turf = sense.threat_turf(npc)
	if(isnull(here) || isnull(threat_turf))
		return
	if(sense.cover)
		var/blown = human_npc_line_of_fire(threat_turf, sense.cover, sense.shot_pass_flags)
		if(here == sense.cover)
			sense.arrived_at ||= world.time
			// Whoever it is fighting at arm's length gets fought, cover or not
			var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
			if(target && get_dist(npc, target) <= 1)
				blown = TRUE
			if(!blown && world.time < hold_until(npc, sense))
				// Hits taken getting here or in here were answered by being here
				sense.decided_at = world.time
				// Its stimulant or a fresh magazine while it is out of sight, else it keeps its head down
				if(!plan_stim(npc, controller, sense) && !human_npc_cover_reload(npc, controller))
					controller.queue_behavior(/datum/ai_behavior/npc_combat_sense_hold)
				return SUBTREE_RETURN_FINISH_PLANNING
			// Time to look out, or it is seen here anyway: the fight subtrees take it from here
			sense.stand_down(controller)
			return
		if(!blown && world.time < sense.cover_deadline && tile_ok(npc, controller, sense.cover))
			sense.decided_at = world.time
			controller.queue_behavior(/datum/ai_behavior/npc_combat_sense_take_cover, BB_HUMAN_NPC_COVER)
			return SUBTREE_RETURN_FINISH_PLANNING
		sense.stand_down(controller)
		return
	if(sense.last_hit_at <= sense.decided_at)
		return
	sense.decided_at = world.time
	if(sense.cover_moves >= cover_moves || !human_npc_line_of_fire(threat_turf, here, sense.shot_pass_flags))
		return
	var/turf/spot = find_cover(npc, controller, threat_turf, sense.shot_pass_flags)
	if(isnull(spot))
		return
	sense.take_cover(controller, spot)
	telegraph(npc, HUMAN_NPC_BARK_TAKE_COVER, sense.threat())
	controller.queue_behavior(/datum/ai_behavior/npc_combat_sense_take_cover, BB_HUMAN_NPC_COVER)
	return SUBTREE_RETURN_FINISH_PLANNING

/**
 * A close fighter under stun fire: it runs at the shooter, if the shooter is who it is already fighting,
 * until it is close enough to hit. Then the family's attacks take over.
 */
/datum/npc_combat_sense/proc/plan_close_in(mob/living/carbon/human/npc, datum/ai_controller/controller, datum/component/npc_combat_sense/sense)
	var/atom/shooter = sense.threat()
	if(isnull(shooter) || shooter != controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET])
		return
	var/reach = max(reach(npc, controller), 1)
	if(get_dist(npc, shooter) <= reach && can_see(npc, shooter, reach))
		return
	if(world.time - sense.charged_at > react_time)
		telegraph(npc, HUMAN_NPC_BARK_CHARGE, shooter)
	sense.charged_at = world.time
	sense.decided_at = world.time
	controller.set_blackboard_key(BB_HUMAN_NPC_STUN_SHOOTER, shooter)
	controller.queue_behavior(/datum/ai_behavior/human_npc_close_in, BB_HUMAN_NPC_STUN_SHOOTER, reach)
	return SUBTREE_RETURN_FINISH_PLANNING

/// Plans the combat sense of a pawn that has one. Controllers that support it list this where it should run.
/datum/ai_planning_subtree/npc_combat_sense

/datum/ai_planning_subtree/npc_combat_sense/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/carbon/human/npc = controller.pawn
	if(!istype(npc))
		return
	var/datum/component/npc_combat_sense/sense = npc.GetComponent(/datum/component/npc_combat_sense)
	if(isnull(sense))
		return
	return sense.rules.plan(npc, controller, sense)

// ===== THE COMPONENT: what it noticed =====

/**
 * On a human NPC with combat sense: notes stun hits (who, from where, what the shot could pass) and keeps
 * the state of the current exchange. The decisions are its rules' (plan()).
 */
/datum/component/npc_combat_sense
	dupe_mode = COMPONENT_DUPE_UNIQUE_PASSARGS
	/// The family's rules, a shared instance
	var/datum/npc_combat_sense/rules
	/// Whoever last shot it with stun fire
	var/datum/weakref/shooter_ref
	/// Where that shot was fired from
	var/turf/shot_from
	/// What that shot could fly through (glass, tables, grilles), to judge cover against the next one
	var/shot_pass_flags = PASSTABLE
	/// world.time of its last stun hit
	var/last_hit_at = 0
	/// Stun hits taken in this exchange
	var/hits = 0
	/// world.time it last answered a stun hit (ran for cover, charged, or chose to stand)
	var/decided_at = 0
	/// The cover it is going to or keeping down in
	var/turf/cover
	/// world.time it gives up on reaching that cover
	var/cover_deadline = 0
	/// world.time it got there, or 0
	var/arrived_at = 0
	/// Runs for cover in this exchange
	var/cover_moves = 0
	/// world.time it last charged a shooter
	var/charged_at = 0
	/// Stimulants it has used
	var/stims_used = 0
	/// world.time it may next reach for a stimulant, after a try that got nowhere
	var/next_stim_at = 0

/datum/component/npc_combat_sense/Initialize(rules_type = /datum/npc_combat_sense)
	if(!ishumannpc(parent) || !ispath(rules_type, /datum/npc_combat_sense))
		return COMPONENT_INCOMPATIBLE
	rules = human_npc_singleton(rules_type)

/datum/component/npc_combat_sense/InheritComponent(datum/component/new_comp, i_am_original, rules_type = /datum/npc_combat_sense)
	if(ispath(rules_type, /datum/npc_combat_sense))
		rules = human_npc_singleton(rules_type)

/datum/component/npc_combat_sense/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_BULLET_ACT, PROC_REF(on_shot))
	RegisterSignal(parent, COMSIG_LIVING_DEATH, PROC_REF(on_death))

/datum/component/npc_combat_sense/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_ATOM_BULLET_ACT, COMSIG_LIVING_DEATH))

/datum/component/npc_combat_sense/Destroy(force)
	rules = null
	shooter_ref = null
	shot_from = null
	cover = null
	return ..()

/// A shot landed. Stun fire is noted; the next plan decides what to do about it.
/datum/component/npc_combat_sense/proc/on_shot(mob/living/carbon/human/source, obj/projectile/shot, def_zone, piercing_hit, blocked)
	SIGNAL_HANDLER
	if(source.stat == DEAD || !human_npc_stun_projectile(shot))
		return
	var/atom/shooter = shot.firer
	if(!rules.threat_ok(source, shooter))
		return
	if(!under_fire())
		hits = 0
		cover_moves = 0
	shooter_ref = WEAKREF(shooter)
	shot_from = get_turf(shot.starting) || get_turf(shooter)
	shot_pass_flags = shot.pass_flags
	last_hit_at = world.time
	hits++

/datum/component/npc_combat_sense/proc/on_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	end_exchange(source.ai_controller)

/// Whether stun fire hit it recently enough to still react.
/datum/component/npc_combat_sense/proc/under_fire()
	return last_hit_at && world.time - last_hit_at <= rules.react_time

/// The one shooting stun rounds at it, if they are still about on its level.
/datum/component/npc_combat_sense/proc/threat()
	var/atom/shooter = shooter_ref?.resolve()
	if(QDELETED(shooter))
		return null
	var/turf/shooter_turf = get_turf(shooter)
	var/turf/our_turf = get_turf(parent)
	if(isnull(shooter_turf) || shooter_turf.z != our_turf?.z)
		return null
	return shooter

/// Where the stun fire comes from: the shooter's tile while it can tell, else where the last shot was fired from.
/datum/component/npc_combat_sense/proc/threat_turf(mob/living/npc)
	var/atom/shooter = threat()
	if(shooter && can_see(npc, shooter, HUMAN_NPC_SIGHT_RANGE))
		return get_turf(shooter)
	return shot_from

/// Sets off for `spot`.
/datum/component/npc_combat_sense/proc/take_cover(datum/ai_controller/controller, turf/spot)
	cover = spot
	arrived_at = 0
	cover_moves++
	cover_deadline = world.time + 1 SECONDS + get_dist(parent, spot) * HUMAN_NPC_SENSE_COVER_STEP_TIME
	controller.set_blackboard_key(BB_HUMAN_NPC_COVER, spot)

/// Leaves its cover plan (it is going back to the fight, or can't do anything).
/datum/component/npc_combat_sense/proc/stand_down(datum/ai_controller/controller)
	cover = null
	arrived_at = 0
	cover_deadline = 0
	controller?.clear_blackboard_key(BB_HUMAN_NPC_COVER)

/// The exchange of fire is over: next time starts afresh.
/datum/component/npc_combat_sense/proc/end_exchange(datum/ai_controller/controller)
	stand_down(controller)
	hits = 0
	cover_moves = 0
	last_hit_at = 0
	decided_at = 0
	shooter_ref = null
	shot_from = null

// ===== BEHAVIOURS =====

/// Walks to the cover turf in `cover_key`. The plan holds it there once it arrives.
/datum/ai_behavior/npc_combat_sense_take_cover
	required_distance = 0
	action_cooldown = 0.2 SECONDS
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/npc_combat_sense_take_cover/setup(datum/ai_controller/controller, cover_key)
	. = ..()
	var/turf/spot = controller.blackboard[cover_key]
	if(!isturf(spot))
		return FALSE
	set_movement_target(controller, spot)

/datum/ai_behavior/npc_combat_sense_take_cover/perform(seconds_per_tick, datum/ai_controller/controller, cover_key)
	var/turf/spot = controller.blackboard[cover_key]
	if(!isturf(spot))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	if(get_turf(controller.pawn) == spot)
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY

/// Keeps its head down where it is. Ends when the plan stops asking for it.
/datum/ai_behavior/npc_combat_sense_hold
	action_cooldown = 0.5 SECONDS
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/npc_combat_sense_hold/perform(seconds_per_tick, datum/ai_controller/controller)
	return AI_BEHAVIOR_DELAY

/**
 * Uses the stimulant pen in `item_key` on itself the way a player does: takes it in a free hand (letting
 * go of a two-handed grip, or putting away a spent gun, if both are full), then use in hand. The spent pen
 * is dropped and its weapons taken up again.
 */
/datum/ai_behavior/npc_combat_sense_stim
	action_cooldown = 0.5 SECONDS
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/npc_combat_sense_stim/perform(seconds_per_tick, datum/ai_controller/controller, item_key)
	var/mob/living/carbon/human/npc = controller.pawn
	var/obj/item/reagent_containers/hypospray/medipen/pen = controller.blackboard[item_key]
	if(!istype(pen) || QDELETED(pen) || human_npc_holding(pen) != npc || npc.stat != CONSCIOUS || HAS_TRAIT(npc, TRAIT_HANDS_BLOCKED))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	if(!human_npc_is_stim(pen))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	if(!npc.is_holding(pen))
		if(!human_npc_free_a_hand(npc) || !human_npc_take_in_hand(npc, pen))
			return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
		return AI_BEHAVIOR_DELAY
	if(!human_npc_ready_item(npc, pen) || npc.next_move > world.time)
		return AI_BEHAVIOR_DELAY
	var/datum/component/npc_combat_sense/sense = npc.GetComponent(/datum/component/npc_combat_sense)
	sense?.rules.telegraph(npc, HUMAN_NPC_BARK_STIMULANT, null, pen)
	npc.execute_mode()
	if(!pen.used_up)
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	if(sense)
		sense.stims_used++
	return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/npc_combat_sense_stim/finish_action(datum/ai_controller/controller, succeeded, item_key)
	var/mob/living/carbon/human/npc = controller.pawn
	var/obj/item/reagent_containers/hypospray/medipen/pen = controller.blackboard[item_key]
	. = ..()
	controller.clear_blackboard_key(item_key)
	if(!istype(npc))
		return
	if(istype(pen) && !QDELETED(pen) && npc.is_holding(pen))
		if(pen.used_up)
			npc.dropItemToGround(pen)
		else
			// Cut short (the plan moved on): back where it came from
			pen.equip_to_best_slot(npc)
	for(var/obj/item/held in npc.held_items)
		human_npc_ready_weapon(npc, held)
	if(!succeeded)
		var/datum/component/npc_combat_sense/sense = npc.GetComponent(/datum/component/npc_combat_sense)
		if(sense)
			sense.next_stim_at = world.time + HUMAN_NPC_SENSE_STIM_RETRY

// ===== HELPERS (API) =====

/// Reagents that count as a stimulant: what a person takes to keep going through a fight.
GLOBAL_LIST_INIT(human_npc_stim_reagents, typecacheof(list(
	/datum/reagent/medicine/stimulants,
	/datum/reagent/medicine/ephedrine,
	/datum/reagent/drug/methamphetamine,
)))

/// Whether `shot` does stamina damage: a disabler bolt, a rubber round.
/proc/human_npc_stun_projectile(obj/projectile/shot)
	if(!istype(shot))
		return FALSE
	return (shot.damage_type == STAMINA && shot.damage > 0) || shot.stamina > 0

/// Whether `pen` is an unspent medipen with a stimulant in it.
/proc/human_npc_is_stim(obj/item/reagent_containers/hypospray/medipen/pen)
	if(!istype(pen) || pen.used_up || !pen.reagents?.total_volume)
		return FALSE
	for(var/datum/reagent/reagent as anything in pen.reagents.reagent_list)
		if(is_type_in_typecache(reagent, GLOB.human_npc_stim_reagents))
			return TRUE
	return FALSE

/// Whether a stimulant is already in `body`'s blood.
/proc/human_npc_stimmed(mob/living/carbon/body)
	for(var/datum/reagent/reagent as anything in body.reagents?.reagent_list)
		if(is_type_in_typecache(reagent, GLOB.human_npc_stim_reagents))
			return TRUE
	return FALSE

/// A stimulant pen `npc` holds, or carries somewhere it can take it from in a moment, or null.
/proc/human_npc_find_stim(mob/living/carbon/npc)
	for(var/obj/item/reagent_containers/hypospray/medipen/pen in npc.get_all_contents_type(/obj/item/reagent_containers/hypospray/medipen))
		if(human_npc_is_stim(pen) && (npc.is_holding(pen) || human_npc_can_draw(npc, pen)))
			return pen
	return null

/// Frees a hand: lets go of a two-handed grip, else puts away a gun that can't fire. Returns TRUE if a hand is free.
/proc/human_npc_free_a_hand(mob/living/carbon/npc)
	if(length(npc.get_empty_held_indexes()))
		return TRUE
	for(var/obj/item/held in npc.held_items)
		if(HAS_TRAIT(held, TRAIT_WIELDED))
			held.attack_self(npc)
			break
	if(length(npc.get_empty_held_indexes()))
		return TRUE
	var/obj/item/gun/spent = human_npc_held_gun(npc)
	if(spent && !spent.can_shoot())
		spent.equip_to_best_slot(npc)
	return length(npc.get_empty_held_indexes()) > 0

/**
 * Whether a shot from `from_turf` could fly straight to `to_turf`: nothing on the way between the two tile
 * centres that blocks it. Walls, closed doors, machines and anything opaque block; glass, tables and grilles
 * only stop a shot that can't pass them (`pass_flags`, the projectile's). Directional things (windoors,
 * railings) are ignored. A rough line, like a person judging cover by eye.
 */
/proc/human_npc_line_of_fire(turf/from_turf, turf/to_turf, pass_flags = PASSTABLE)
	if(isnull(from_turf) || isnull(to_turf) || from_turf.z != to_turf.z)
		return FALSE
	var/dx = to_turf.x - from_turf.x
	var/dy = to_turf.y - from_turf.y
	// Four looks per tile along the segment, each at the tile under that point
	var/samples = max(abs(dx), abs(dy)) * 4
	var/turf/last = from_turf
	for(var/sample in 1 to samples - 1)
		var/turf/step = locate(round(from_turf.x + dx * sample / samples + 0.5), round(from_turf.y + dy * sample / samples + 0.5), from_turf.z)
		if(step == last || step == to_turf)
			continue
		last = step
		if(isnull(step) || step.density || step.opacity)
			return FALSE
		for(var/obj/thing in step)
			if(thing.opacity)
				return FALSE
			if(!thing.density || (thing.flags_1 & ON_BORDER_1) || (thing.pass_flags_self & pass_flags))
				continue
			return FALSE
	return TRUE

/// Whether someone else is standing on `tile`, so `npc` can't take cover there.
/proc/human_npc_cover_taken(turf/tile, mob/living/npc)
	for(var/mob/living/other in tile)
		if(other != npc && other.density)
			return TRUE
	return FALSE

/**
 * The nearest tile `npc` can walk to within `max_steps` that is out of a shot's line from `threat_turf`,
 * or null. One flood from where it stands, with the pathfinder's own step check (walls, windows, doors it
 * has no access for), never onto or through a tile `tile_ok` (a callback taking the turf) refuses. Of the
 * nearest, the one closest to the threat, so it can look out again. Cheap enough to run once per stun
 * hit: it never sleeps.
 */
/proc/human_npc_find_cover(mob/living/npc, turf/threat_turf, max_steps = HUMAN_NPC_SENSE_COVER_STEPS, pass_flags = PASSTABLE, datum/callback/tile_ok)
	var/turf/start = get_turf(npc)
	if(isnull(start) || isnull(threat_turf) || start.z != threat_turf.z)
		return null
	var/datum/can_pass_info/pass_info = new(npc, npc.ai_controller?.get_access())
	var/list/steps_to = list()
	steps_to[start] = 0
	var/list/queue = list(start)
	var/index = 1
	var/turf/best
	var/best_steps = INFINITY
	var/best_distance = INFINITY
	while(index <= length(queue))
		var/turf/current = queue[index++]
		var/steps = steps_to[current]
		// Breadth first: everything from here on is further than the cover already found
		if(steps >= best_steps || steps >= max_steps)
			break
		for(var/direction in GLOB.alldirs)
			var/turf/next = get_step(current, direction)
			if(isnull(next) || !isnull(steps_to[next]) || next.density)
				continue
			if(current.LinkBlockedWithAccess(next, pass_info))
				continue
			steps_to[next] = steps + 1
			if(tile_ok && !tile_ok.Invoke(next))
				continue
			queue += next
			if(human_npc_cover_taken(next, npc) || human_npc_line_of_fire(threat_turf, next, pass_flags))
				continue
			var/distance = get_dist(next, threat_turf)
			if(steps + 1 < best_steps || distance < best_distance)
				best = next
				best_steps = steps + 1
				best_distance = distance
	return best

/**
 * In cover with a gun that ran dry and a magazine to put in it: queues the human NPC base's reload (the
 * player's reload) and returns TRUE. Guns loaded a round at a time wait for the family's own arming.
 */
/proc/human_npc_cover_reload(mob/living/carbon/npc, datum/ai_controller/controller)
	if(world.time < controller.blackboard[BB_HUMAN_NPC_ARMING_RETRY_AT])
		return FALSE
	var/obj/item/gun/ballistic/gun = human_npc_held_gun(npc)
	if(!istype(gun) || gun.internal_magazine || gun.can_shoot() || !human_npc_can_reload(npc, gun))
		return FALSE
	controller.queue_behavior(/datum/ai_behavior/human_npc_reload)
	return TRUE
