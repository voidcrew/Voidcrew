/**
 * # Wear Them: Ilthuun's mind control
 *
 * `/datum/status_effect/lich_thrall`. Ten seconds of genuine possession: the victim's
 * own input is discarded and an AI controller drives them into their nearest living ally.
 * This is the real mechanic, not a suggestion. The owner was asked and picked full
 * temporary mind control over the softer options.
 *
 * ## How agency is actually removed
 *
 * Four moving parts, all of them borrowed rather than invented:
 *
 * 1. **An AI controller is installed on a player mob.** In-repo precedent:
 *    `/datum/brain_trauma/special/primal_instincts` (`code/datums/brain_damage/special.dm:484-503`)
 *    does exactly this, it replaces a human's `ai_controller` with
 *    `/datum/ai_controller/monkey` and sets `continue_processing_when_client = TRUE`,
 *    which is the flag that stops `get_expected_ai_status()` from switching the AI off
 *    the moment it notices a client is attached (`_ai_controller.dm:259-260`).
 *
 * 2. **Attacks are forced through `ai_interact()`.**
 *    `/datum/ai_controller/proc/ai_interact` (`_ai_controller.dm:348-366`) sets combat
 *    mode and calls `living_pawn.ClickOn(target)`, i.e. it drives the mob through the
 *    same click path a player would. `/datum/ai_behavior/monkey_attack_mob/proc/monkey_attack`
 *    (`code/datums/ai/monkey/monkey_behaviors.dm:193, 202, 209`) is the precedent for
 *    using it on a *carbon*, including firing a held gun and swinging a held weapon, and
 *    [/datum/ai_behavior/lich_thrall_strike/proc/strike] below is a compressed version of it.
 *
 * 3. **Movement is forced** by the standard behavior movement path: `set_movement_target`
 *    plus `AI_BEHAVIOR_REQUIRE_MOVEMENT`, which routes through `/datum/ai_movement` and
 *    `GLOB.move_manager`. Positional, so it works fine inside the lair's `NOTELEPORT` areas.
 *
 * 4. **The player's own input is dropped on the floor.** Client movement is cancelled with
 *    `COMSIG_MOB_CLIENT_PRE_MOVE` → `COMSIG_MOB_CLIENT_BLOCK_PRE_MOVE`
 *    (`code/modules/mob/mob_movement.dm:99`; precedent `code/datums/drift_handler.dm:208`)
 *    and clicks with `COMSIG_MOB_CLICKON` → `COMSIG_MOB_CANCEL_CLICKON`
 *    (`code/_onclick/click.dm:76`). The AI's own synthetic clicks are let through by
 *    [puppet_acting], which the strike behavior raises around its `ai_interact` call.
 *
 * Speech is deliberately *not* blocked. A victim yelling that they are not in control is
 * the single best piece of attribution this effect can have.
 *
 * ## Guardrails
 *
 * These are about legibility and attribution, not about softening the mechanic:
 *
 * - Loud `visible_message` naming the possessor at apply **and** at expiry.
 * - A pulsing green outline plus a green colour wash for the whole duration, on the mob's
 *   appearance, so every player in the room can see who is being worn.
 * - `log_message(..., LOG_ATTACK)` on both the victim and whoever is doing it, plus a
 *   `log_game` line, so the possession window is reconstructable from the logs.
 * - Never applies to a dead or unconscious mob, never stacks, and leaves a
 *   [LICH_THRALL_IMMUNITY]-long per-victim immunity behind so one player cannot be
 *   chain-locked for the whole fight.
 * - Antimagic blocks it (`MAGIC_RESISTANCE|MAGIC_RESISTANCE_MIND`), like any other spell
 *   here, the same flags `/datum/action/cooldown/spell/pointed/dominate` uses.
 * - Dies with its caster: [tick] drops the effect if Ilthuun is gone or dead.
 *
 * ## Attribution is threaded, not hardcoded
 *
 * Ilthuun is not the only thing that can cast this any more, the verdigris bridle
 * (lich_loot.dm) is a player-wielded, charge-limited version of the same possession, and a
 * player taking another player's body away must be named for it everywhere. So every place
 * this effect says *who is doing it* goes through [attribution_name] (chat) and
 * [attribution_log] (logs and admin readback) rather than naming Ilthuun inline, and the
 * lines spoken with the victim's mouth go through [possessed_line]. The base
 * implementations answer "Ilthuun"; `/datum/status_effect/lich_thrall/bridle` answers with
 * the wielder. Nothing about the possession itself is duplicated for the player version.
 */

/// How long a possession lasts.
#define LICH_THRALL_DURATION (10 SECONDS)
/// How long after a possession ends before the same victim can be taken again.
#define LICH_THRALL_IMMUNITY (90 SECONDS)
/// Trait marking a victim as recently possessed, and therefore off limits.
#define TRAIT_LICH_THRALL_SPENT "lich_thrall_spent"
/// Trait source.
#define LICH_THRALL_TRAIT "lich_thrall"
/// Filter key for the green outline.
#define LICH_THRALL_FILTER "lich_thrall_glow"
/// How far a thrall looks for someone to turn on.
#define LICH_THRALL_SIGHT 7

/**
 * The single gate on who can be possessed.
 *
 * Lives here rather than on the spell so that the spell (lich_abilities.dm), the AI
 * planning subtree that decides whether the ability is worth queueing, and
 * [/datum/status_effect/lich_thrall/on_apply] all ask exactly the same question. It is
 * checked three times on purpose. There are sleeps and a cooldown between "the AI wants
 * to cast this" and "the effect lands", and this must never end up on a corpse.
 *
 * `charge_cost = 0` on the antimagic check so that merely being *considered* as a target
 * does not burn a charge off the victim's antimagic item (see `can_block_magic`,
 * `code/modules/mob/mob.dm:1013`).
 */
/proc/can_be_lich_thralled(mob/living/target)
	if(!isliving(target) || QDELETED(target))
		return FALSE
	if(target.stat != CONSCIOUS) // never a corpse, never a crit victim
		return FALSE
	if(HAS_TRAIT(target, TRAIT_LICH_THRALL_SPENT))
		return FALSE
	if(target.has_status_effect(/datum/status_effect/lich_thrall))
		return FALSE
	// His own garrison is already his. Possessing a skeleton is not a fight.
	if(target.mob_biotypes & MOB_UNDEAD)
		return FALSE
	if(faction_check(target.faction, list(FACTION_LICH)))
		return FALSE
	if(target.can_block_magic(MAGIC_RESISTANCE|MAGIC_RESISTANCE_MIND, charge_cost = 0))
		return FALSE
	return TRUE

/datum/status_effect/lich_thrall
	id = "lich_thrall"
	duration = LICH_THRALL_DURATION
	tick_interval = 1 SECONDS
	status_type = STATUS_EFFECT_UNIQUE
	processing_speed = STATUS_EFFECT_NORMAL_PROCESS
	alert_type = /atom/movable/screen/alert/status_effect/lich_thrall
	show_duration = TRUE
	// Anything that fully heals you also gets the lich out of your head.
	remove_on_fullheal = TRUE
	// Make sure the teardown below always runs, even if the victim is deleted outright.
	on_remove_on_mob_delete = TRUE

	/// Weakref to Ilthuun. The possession does not outlive him.
	var/datum/weakref/master_ref
	/// The controller we installed to drive the victim.
	var/datum/ai_controller/lich_thrall/puppet_controller
	/// The victim's own AI controller type, if they had one, restored on release.
	var/old_ai_controller_type
	/// The victim's factions before we rewrote them, restored on release.
	var/list/original_faction
	/// Failed eligibility checks must not run release effects or grant post-possession immunity.
	var/possession_applied = FALSE
	/**
	 * TRUE only for the instant the strike behavior is pushing a synthetic click through
	 * `ai_interact()`. [block_own_clicks] lets a click through while it is raised.
	 *
	 * Caveat, stated rather than hidden: melee and gunfire resolve synchronously, but a
	 * held item with a `do_after` in its attack chain would sleep with this still raised,
	 * leaving a window in which the player's own click would be honoured. For a
	 * ten-second effect in a boss room that is an acceptable seam, and it fails in the
	 * harmless direction, the victim gets a fraction of their agency back, rather than
	 * the lich getting extra.
	 */
	var/puppet_acting = FALSE

	/// Things Ilthuun says with somebody else's mouth.
	var/static/list/possessed_lines = list(
		"HOLD STILL. THIS IS EASIER IF YOU HOLD STILL.",
		"THEY ARE STANDING SO CLOSE TOGETHER.",
		"THESE HANDS ARE BETTER THAN MINE. WARMER.",
		"I HAVE WORN BETTER BODIES THAN THIS ONE.",
		"DO NOT BLAME THEM. THEY ARE NOT THE ONE DOING THIS.",
	)

/datum/status_effect/lich_thrall/on_creation(mob/living/new_owner, mob/living/new_master)
	if(new_master)
		master_ref = WEAKREF(new_master)
	return ..()

/datum/status_effect/lich_thrall/on_apply()
	// Last of the three checks. The spell checked at cast time and the AI subtree checked
	// at planning time; a lot can happen in between.
	if(!can_be_lich_thralled(owner))
		return FALSE
	possession_applied = TRUE

	// His dead must not carve up his own puppet. Restored in on_remove.
	original_faction = owner.faction?.Copy()
	owner.faction = list(FACTION_LICH)

	apply_green_wash()
	take_the_wheel()

	var/mob/living/master = master_ref?.resolve()
	// `duration` is read through initial() because /datum/status_effect/on_creation rewrites
	// the var into an absolute world.time the moment on_apply returns, and because the
	// bridle subtype runs shorter than Ilthuun does, so the define is the wrong number to
	// quote here.
	var/seconds_of_it = initial(duration) / 10
	owner.visible_message(
		span_boldwarning("Green light pours out of [owner]'s eyes and mouth. [attribution_name()] has [owner.p_them()]."),
		span_userdanger("A cold green weight settles over your mind. [attribution_name()] is wearing you. \
			You can feel your own hands moving, and you are not the one moving them."),
	)
	owner.balloon_alert_to_viewers("possessed!")
	playsound(owner, 'sound/effects/magic/curse.ogg', 65, vary = TRUE)

	owner.log_message("was possessed by [attribution_log()] for [seconds_of_it] seconds (lich_thrall)", LOG_ATTACK, color = "green")
	master?.log_message("possessed [key_name(owner)] with lich_thrall for [seconds_of_it] seconds", LOG_ATTACK, color = "green")
	log_game("LICH: [key_name(owner)] possessed by [attribution_log()] (lich_thrall) at [AREACOORD(owner)].")

	return TRUE

/datum/status_effect/lich_thrall/on_remove()
	if(!possession_applied)
		return
	possession_applied = FALSE
	// Teardown first and unconditionally: the victim may be mid-deletion.
	release_the_wheel()

	if(!isnull(original_faction))
		owner.faction = original_faction
		original_faction = null

	if(QDELETED(owner))
		return

	remove_green_wash()

	owner.visible_message(
		span_boldwarning("The green drains out of [owner]'s eyes. [attribution_name()] has let go of [owner.p_them()]."),
		span_userdanger("The weight lifts. Your hands are yours again, and you remember every second of it."),
	)
	owner.balloon_alert_to_viewers("released")
	playsound(owner, 'sound/effects/magic/blind.ogg', 45, vary = TRUE)
	owner.log_message("was released from possession by [attribution_log()] (lich_thrall)", LOG_ATTACK, color = "green")

	// No chain-locking one player for the whole fight.
	ADD_TRAIT(owner, TRAIT_LICH_THRALL_SPENT, LICH_THRALL_TRAIT)
	addtimer(TRAIT_CALLBACK_REMOVE(owner, TRAIT_LICH_THRALL_SPENT, LICH_THRALL_TRAIT), LICH_THRALL_IMMUNITY)

/datum/status_effect/lich_thrall/tick(seconds_between_ticks)
	// The possession dies with the possessor.
	var/mob/living/master = master_ref?.resolve()
	if(QDELETED(master) || master.stat == DEAD)
		qdel(src)
		return
	// And it never rides a body that has stopped being a person.
	if(owner.stat != CONSCIOUS)
		qdel(src)
		return

	retarget()

	if(prob(35))
		owner.visible_message(span_boldwarning("\"[possessed_line()]\", [owner]'s mouth moves, but that is not [owner.p_their()] voice."))

// ===== ATTRIBUTION =====

/**
 * Who is doing this, for chat.
 *
 * Named in the apply message, the victim's own message, the expiry message and (via
 * [possessed_line]) out of the victim's mouth. Ilthuun by default because he is the only
 * caster in the fight itself; the bridle answers with whoever is holding it.
 */
/datum/status_effect/lich_thrall/proc/attribution_name()
	return LICH_ANNOUNCER

/**
 * Who is doing this, for the logs.
 *
 * Kept separate from [attribution_name] because chat and logs want different things: chat
 * wants the name a bystander would actually see (a masked wielder reads as "Unknown", the
 * same as everything else they do), and the logs want a ckey an admin can act on.
 */
/datum/status_effect/lich_thrall/proc/attribution_log()
	return LICH_ANNOUNCER

/// One line said with the victim's mouth. A proc rather than an inlined `pick()` so a
/// subtype can name whoever is actually driving.
/datum/status_effect/lich_thrall/proc/possessed_line()
	return pick(possessed_lines)

/datum/status_effect/lich_thrall/get_examine_text()
	return span_boldwarning("[owner.p_They()] [owner.p_are()] lit from the inside with a cold green light, and [owner.p_they()] [owner.p_do()]n't look like [owner.p_theyre()] in control.")

// ===== THE VISIBLE TELL =====

/**
 * Marks the victim green for the whole duration, on their appearance, so that *everybody*
 * in the room can see who is being worn, not just the victim reading an alert.
 *
 * Two layers on purpose: a pulsing outline filter, which reads at a glance in a crowded
 * fight, and a colour wash, which survives being off-screen-edge or partly obscured.
 * Both are part of the mob's appearance, so every client renders them.
 */
/datum/status_effect/lich_thrall/proc/apply_green_wash()
	owner.add_filter(LICH_THRALL_FILTER, 3, list("type" = "outline", "color" = LICH_GREEN, "alpha" = 0, "size" = 2))
	var/thrall_filter = owner.get_filter(LICH_THRALL_FILTER)
	if(thrall_filter)
		animate(thrall_filter, alpha = 220, time = 0.5 SECONDS, loop = -1)
		animate(alpha = 60, time = 0.5 SECONDS)
	owner.add_atom_colour(LICH_GREEN, TEMPORARY_COLOUR_PRIORITY)

/datum/status_effect/lich_thrall/proc/remove_green_wash()
	var/thrall_filter = owner.get_filter(LICH_THRALL_FILTER)
	if(thrall_filter)
		animate(thrall_filter)
	owner.remove_filter(LICH_THRALL_FILTER)
	owner.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, LICH_GREEN)

// ===== POSSESSION =====

/**
 * Installs the puppet controller and cuts the player's own input out of the loop.
 *
 * `PossessPawn()` already destroys whatever controller the mob had
 * (`_ai_controller.dm:1046`-ish, "Existing AI, kill it"), so we only need to remember its
 * type in order to put it back. `reset_ai_status()` is called again afterwards because
 * `PossessPawn` runs it *before* we get to raise `continue_processing_when_client`, and
 * would otherwise have already parked the controller at AI_STATUS_OFF for having a client.
 */
/datum/status_effect/lich_thrall/proc/take_the_wheel()
	RegisterSignal(owner, COMSIG_MOB_CLIENT_PRE_MOVE, PROC_REF(block_own_movement))
	RegisterSignal(owner, COMSIG_MOB_CLICKON, PROC_REF(block_own_clicks))

	if(!isnull(owner.ai_controller))
		old_ai_controller_type = owner.ai_controller.type

	puppet_controller = new /datum/ai_controller/lich_thrall(owner)
	puppet_controller.thrall_ref = WEAKREF(src)
	puppet_controller.continue_processing_when_client = TRUE
	puppet_controller.can_idle = FALSE
	puppet_controller.reset_ai_status()

/// Hands the body back, and puts the victim's own controller back if they had one.
/datum/status_effect/lich_thrall/proc/release_the_wheel()
	if(!QDELETED(owner))
		UnregisterSignal(owner, list(COMSIG_MOB_CLIENT_PRE_MOVE, COMSIG_MOB_CLICKON))

	QDEL_NULL(puppet_controller) // Destroy() -> UnpossessPawn() nulls owner.ai_controller

	if(old_ai_controller_type && !QDELETED(owner))
		new old_ai_controller_type(owner)
	old_ai_controller_type = null

/// Their keyboard does nothing. Precedent for cancelling client movement this way:
/// `/datum/drift_handler/proc/...` at code/datums/drift_handler.dm:208.
/datum/status_effect/lich_thrall/proc/block_own_movement(mob/source, list/move_args)
	SIGNAL_HANDLER
	return COMSIG_MOB_CLIENT_BLOCK_PRE_MOVE

/// Their mouse does nothing either. Except when it is not actually their mouse.
/datum/status_effect/lich_thrall/proc/block_own_clicks(mob/source, atom/target, list/modifiers)
	SIGNAL_HANDLER
	if(puppet_acting)
		return NONE
	return COMSIG_MOB_CANCEL_CLICKON

/// Raised by the strike behavior around its `ai_interact()` call. See [puppet_acting].
/datum/status_effect/lich_thrall/proc/begin_puppet_action()
	puppet_acting = TRUE

/datum/status_effect/lich_thrall/proc/end_puppet_action()
	puppet_acting = FALSE

/**
 * Re-picks who the victim is being driven at, once a second.
 *
 * Target selection lives on the status effect rather than in the AI so that the rules
 * are in one readable place: never Ilthuun, never his dead, never another thrall (two
 * possessed crewmen circling each other reads as a bug, not a curse), and real people
 * before wildlife.
 */
/datum/status_effect/lich_thrall/proc/retarget()
	var/mob/living/best_target
	var/best_score = INFINITY

	for(var/mob/living/candidate in view(LICH_THRALL_SIGHT, owner))
		if(candidate == owner || QDELETED(candidate) || candidate.stat == DEAD)
			continue
		if(candidate.mob_biotypes & MOB_UNDEAD)
			continue
		if(faction_check(candidate.faction, list(FACTION_LICH)))
			continue // Ilthuun and his garrison
		if(candidate.has_status_effect(/datum/status_effect/lich_thrall))
			continue

		var/score = get_dist(owner, candidate)
		if(candidate.client)
			score -= 100 // a possessed crewman going for the nearest mouse is a joke
		if(score >= best_score)
			continue
		best_score = score
		best_target = candidate

	if(QDELETED(best_target))
		puppet_controller?.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
		return
	puppet_controller?.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, best_target)

// ===== THE PUPPET AI =====

/**
 * Drives a possessed mob at whatever [/datum/status_effect/lich_thrall/proc/retarget]
 * last handed it.
 *
 * Extends `/datum/ai_controller` directly, not `/datum/ai_controller/basic_controller`.
 * The pawn here is usually a `/mob/living/carbon/human`, and the basic-mob controller and
 * its subtrees assume `/mob/living/basic`. `/datum/ai_controller/monkey` is the in-repo
 * example of an ai_controller written for carbons.
 */
/datum/ai_controller/lich_thrall
	movement_delay = 0.3 SECONDS
	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = null
	planning_subtrees = list(
		/datum/ai_planning_subtree/lich_thrall_assault,
	)
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
	)
	/// Weakref back to the status effect that installed us.
	var/datum/weakref/thrall_ref

/**
 * Restraints, stuns and crit stop a thrall, which is the counterplay: cuff your friend
 * instead of shooting them. Being *grabbed* is ignored, so a thrall in someone's grip
 * still fights, otherwise the answer to the whole mechanic is "hug them".
 *
 * `/datum/ai_controller/monkey/get_able_to_run` (monkey_controller.dm:123-128) is the
 * pattern; it ignores restraints as well, which we deliberately do not.
 */
/datum/ai_controller/lich_thrall/get_able_to_run()
	var/mob/living/living_pawn = pawn
	if(!isliving(living_pawn))
		return AI_UNABLE_TO_RUN
	if(living_pawn.stat > CONSCIOUS || INCAPACITATED_IGNORING(living_pawn, INCAPABLE_GRAB))
		return AI_UNABLE_TO_RUN
	return ..()

/// Movement speed should track whatever the victim's own body can do.
/datum/ai_controller/lich_thrall/TryPossessPawn(atom/new_pawn)
	if(!isliving(new_pawn))
		return AI_CONTROLLER_INCOMPATIBLE
	var/mob/living/living_pawn = new_pawn
	movement_delay = living_pawn.cached_multiplicative_slowdown
	return ..()

/datum/ai_planning_subtree/lich_thrall_assault

/datum/ai_planning_subtree/lich_thrall_assault/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(QDELETED(target) || target.stat == DEAD)
		controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
		return
	controller.queue_behavior(/datum/ai_behavior/lich_thrall_strike, BB_BASIC_MOB_CURRENT_TARGET)
	return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_behavior/lich_thrall_strike
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION
	action_cooldown = 0.4 SECONDS

/datum/ai_behavior/lich_thrall_strike/setup(datum/ai_controller/controller, target_key)
	. = ..()
	var/atom/target = controller.blackboard[target_key]
	if(QDELETED(target))
		return FALSE
	set_movement_target(controller, target)

/datum/ai_behavior/lich_thrall_strike/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/mob/living/target = controller.blackboard[target_key]
	var/mob/living/puppet = controller.pawn
	if(QDELETED(target) || QDELETED(puppet) || target.stat == DEAD)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Shuttle floors move and so do people; never trust a cached movement target.
	set_movement_target(controller, target)

	if(puppet.next_move > world.time)
		return AI_BEHAVIOR_DELAY

	var/datum/ai_controller/lich_thrall/thrall_controller = controller
	strike(controller, puppet, target, thrall_controller.thrall_ref?.resolve())
	return AI_BEHAVIOR_DELAY

/**
 * Makes the victim attack, with whatever they happen to be holding.
 *
 * This is a compressed `/datum/ai_behavior/monkey_attack_mob/proc/monkey_attack`
 * (monkey_behaviors.dm:182-210): fire a held gun at range, otherwise close and swing.
 * The work is done by `controller.ai_interact()`, which sets combat mode and calls
 * `ClickOn()` on the pawn. The same code path a player's own click takes, which is
 * exactly why the possession looks and reads like the victim doing it.
 *
 * [/datum/status_effect/lich_thrall/var/puppet_acting] is raised across the call so that
 * [/datum/status_effect/lich_thrall/proc/block_own_clicks] lets this one click through
 * while still swallowing everything the player themselves tries.
 */
/datum/ai_behavior/lich_thrall_strike/proc/strike(datum/ai_controller/controller, mob/living/puppet, mob/living/target, datum/status_effect/lich_thrall/thrall)
	var/obj/item/gun/held_gun = locate() in puppet.held_items
	if(held_gun?.can_shoot())
		if(held_gun != puppet.get_active_held_item())
			puppet.swap_hand(puppet.get_inactive_hand_index())
		forced_interact(controller, target, thrall)
		return

	var/obj/item/weapon = locate() in puppet.held_items
	if(!puppet.CanReach(target, weapon))
		return
	if(weapon && weapon != puppet.get_active_held_item())
		puppet.swap_hand(puppet.get_inactive_hand_index())
	forced_interact(controller, target, thrall)

/datum/ai_behavior/lich_thrall_strike/proc/forced_interact(datum/ai_controller/controller, mob/living/target, datum/status_effect/lich_thrall/thrall)
	thrall?.begin_puppet_action()
	controller.ai_interact(target = target, combat_mode = TRUE)
	thrall?.end_puppet_action()

// ===== ALERT =====

/atom/movable/screen/alert/status_effect/lich_thrall
	name = "Possessed"
	desc = "Ilthuun, the Verdigris Lich, is wearing you. Your body is not taking instructions from you. \
		This will pass. Whatever you do in the meantime is not your fault."
	icon_state = ALERT_MIND_CONTROL

#undef LICH_THRALL_DURATION
#undef LICH_THRALL_IMMUNITY
#undef TRAIT_LICH_THRALL_SPENT
#undef LICH_THRALL_TRAIT
#undef LICH_THRALL_FILTER
#undef LICH_THRALL_SIGHT
