/**
 * # The grip from behind: the hand over the mouth, and the squeeze
 *
 * An empty hand on a guard's mouth from behind: tg's grab (ctrl-click) with the mouth aimed at, on a stealth guard
 * caught off guard (stealth_caught_off_guard(): unaware or only suspicious, awake, not already held, no player in the
 * body), standing, from behind (tg's check_behind()). Only the start is special, as with the instant knife cut: it is
 * tg's own grab, set straight to a neck grab on the holder's tile, with tg's chokehold traits (can't move, hands
 * blocked). Anyone else, a player or a guard on guard, gets tg's ordinary grab. A sealed helmet keeps the hand off.
 *
 * While the hand is on (/datum/stealth_grip):
 * - he is mute (TRAIT_MUTE from STEALTH_GRIP_TRAIT): no shout, no radio, by tg's own can_speak();
 * - his AI doesn't struggle (escape_captivity/stealth below). tg's resist is still there for a player in the body;
 * - he is held up in front, in the hostage pose (stealth_held_in_front(), stealth_hostage_pose.dm).
 * From the hold:
 * - a gun in either hand: a hostage (stealth_hostage_of(), stealth_hostage.dm);
 * - a knife: the throat cut on the click (knife_executions.dm);
 * - another grab click with the hand still empty: the squeeze. tg's strangle (GRAB_KILL) plus the arm's pressure as
 *   oxygen damage, slowed by the neck's cover (the cut chokehold's numbers). Non-lethal: he is out in about 9 s and
 *   let go once out and STEALTH_SQUEEZE_RELEASE_OXY deep, or sooner if he is hurt enough to be near tg's full crit.
 *   Placeholder visuals (the pose); a real animation comes through the storyboard gate later.
 * It ends with tg's grab: let go, moved apart, the holder stunned, anything tg drops a grab for, or the grab going
 * below a neck grab. Let go awake, he knows who held him: alert on them, and he shouts and calls it in now he can.
 */

/mob/living
	/// The hand-over-the-mouth hold this mob has on someone, if any.
	var/datum/stealth_grip/stealth_grip_holding
	/// The hand-over-the-mouth hold this mob is in, if any.
	var/datum/stealth_grip/stealth_grip_held

/// Whether `holder` can clamp a hand over `target`'s mouth now (see the top of this file).
/proc/stealth_grip_can_clamp(mob/living/holder, mob/living/target)
	return isnull(stealth_grip_refusal(holder, target))

/// Why `holder` can't clamp a hand over `target`'s mouth now, for the logs, or null if it can. "not a guard" for
/// anyone the hold never applies to.
/proc/stealth_grip_refusal(mob/living/holder, mob/living/target)
	if(!isliving(holder) || !ishumannpc(target) || holder == target)
		return "not a guard"
	var/mob/living/carbon/human/npc/guard = target
	if(!istype(guard.ai_controller, /datum/ai_controller/basic_controller/human_npc/stealth))
		return "not a guard"
	if(holder.zone_selected != BODY_ZONE_PRECISE_MOUTH)
		return "mouth not aimed at ([holder.zone_selected])"
	var/obj/item/in_hand = holder.get_active_held_item()
	if(in_hand)
		return "active hand holds [in_hand]"
	if(holder.incapacitated || HAS_TRAIT(holder, TRAIT_PACIFISM) || !holder.hv_can_execute())
		return "holder can't (incapacitated or pacifist)"
	if(holder.stealth_grip_holding || guard.stealth_grip_held || holder.pulling == guard || holder.max_grab < GRAB_NECK)
		return "already holding or held"
	if(!(guard.status_flags & CANPUSH) || HAS_TRAIT(guard, TRAIT_PUSHIMMUNE) || guard.buckled || guard.pulledby)
		return "guard can't be grabbed (buckled, pulled or push immune)"
	if(!isturf(holder.loc) || !isturf(guard.loc) || !holder.Adjacent(guard) || guard.body_position != STANDING_UP)
		return "not adjacent or guard not standing"
	if(isnull(guard.get_bodypart(BODY_ZONE_HEAD)) || guard.is_mouth_covered(ITEM_SLOT_HEAD))
		return "no head or mouth covered by headgear"
	if(!check_behind(holder, guard))
		return "not behind (guard faces [dir2text(guard.dir)], holder is [dir2text(get_dir(guard, holder))] of him)"
	if(!guard.stealth_caught_off_guard(holder))
		var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
		return "guard on guard ([guard_ai.stealth_state()])"
	return null

/// The body `holder` has in the hand-over-the-mouth hold on his tile, or null. `at` asks about the body on another
/// tile instead (one it has been pushed or dragged onto).
/proc/stealth_grip_victim_of(mob/living/holder, atom/at)
	var/datum/stealth_grip/grip = holder?.stealth_grip_holding
	if(isnull(grip) || grip.ended || holder.pulling != grip.held || holder.grab_state < GRAB_NECK || grip.held.loc != (at || holder.loc))
		return null
	return grip.held

/// Whether `holder` has `victim` in the hand-over-the-mouth hold, on his tile (or on `at`).
/proc/stealth_grip_holds(mob/living/holder, mob/living/victim, atom/at)
	return !isnull(victim) && stealth_grip_victim_of(holder, at) == victim

/// The body `holder` holds up in front of him: at gunpoint (stealth_hostage_of()) or with a hand over its mouth.
/proc/stealth_held_in_front(mob/living/holder)
	return stealth_hostage_of(holder) || stealth_grip_victim_of(holder)

/// How well the neck is covered against the squeeze (0-100): a sealed helmet is 100, otherwise the head's melee cover
/// from worn and physiology armour, stacked as tg stacks them.
/proc/stealth_grip_neck_cover(mob/living/carbon/human/victim)
	if(victim.is_mouth_covered(ITEM_SLOT_HEAD))
		return 100
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)
	if(isnull(head))
		return 100
	return clamp(hv_crit_cover_rating(victim, head, MELEE), 0, 100)

// ---------------------------------------------------------------------------------------------
// The trigger: tg's grab (ctrl-click)

/mob/living/grab(mob/living/target)
	if(isliving(target))
		var/datum/stealth_grip/grip = stealth_grip_holding
		if(grip && grip.held == target && pulling == target && grip.squeeze())
			return TRUE
		// A body held up in front with something in the grabbing hand (the gun): the click does nothing. tg's grab would
		// tighten it to a strangle, and the squeeze is only for an empty hand.
		if(pulling == target && grab_state >= GRAB_NECK && get_active_held_item() && isturf(target.loc) && (stealth_hostage_of(src, target.loc) == target || stealth_grip_holds(src, target, target.loc)))
			return TRUE
		var/refusal = stealth_grip_refusal(src, target)
		// Aimed at a guard's mouth and it didn't take: say why in the attack log (playtest diagnosis).
		if(refusal && refusal != "not a guard" && zone_selected == BODY_ZONE_PRECISE_MOUTH)
			log_combat(src, target, "tried a hand over the mouth on", addition = "refused: [refusal]")
		if(isnull(refusal))
			// tg's grab signal first, as tg's grab() sends it: a martial art or anything else hooked there may take it
			if(SEND_SIGNAL(src, COMSIG_LIVING_GRAB, target) & (COMPONENT_CANCEL_ATTACK_CHAIN|COMPONENT_SKIP_ATTACK))
				return FALSE
			if(target.check_block(src, 0, "[src]'s grab", UNARMED_ATTACK))
				return FALSE
			var/datum/stealth_grip/new_grip = new(src, target)
			// Taken or not, this was the grab: tg's grab() below would send the signal and roll the block again.
			return new_grip.close_hand() || pulling == target
	return ..()

// ---------------------------------------------------------------------------------------------
// The hold

/datum/stealth_grip
	var/mob/living/holder
	var/mob/living/carbon/human/held
	/// TRUE once the squeeze is on.
	var/squeezing = FALSE
	/// Oxygen damage a second on top of tg's strangle, after the neck's cover.
	var/oxy_rate = 0
	/// The timer for the next squeeze_tick().
	var/tick_timer
	/// TRUE once it has ended, so it ends once.
	var/ended = FALSE

/datum/stealth_grip/New(mob/living/holder, mob/living/carbon/human/held)
	src.holder = holder
	src.held = held
	holder.stealth_grip_holding = src
	held.stealth_grip_held = src
	RegisterSignals(holder, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH), PROC_REF(on_gone))
	RegisterSignals(held, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH), PROC_REF(on_gone))

/datum/stealth_grip/Destroy()
	if(!ended)
		end(FALSE)
	holder = null
	held = null
	return ..()

/datum/stealth_grip/proc/on_gone(datum/source)
	SIGNAL_HANDLER
	end(FALSE)

/datum/stealth_grip/proc/on_let_go(datum/source, atom/movable/last_pulled)
	SIGNAL_HANDLER
	end(FALSE)

/datum/stealth_grip/proc/on_grab_state(datum/source, new_state)
	SIGNAL_HANDLER
	if(new_state < GRAB_NECK)
		end(FALSE)
	else if(new_state < GRAB_KILL && squeezing)
		squeezing = FALSE

/**
 * The hand goes over his mouth: tg's grab, stepped through the same states grippedby() steps through, straight to the
 * neck grab. FALSE (and ended) if tg's pull didn't take.
 */
/datum/stealth_grip/proc/close_hand()
	// Mute first: tg's pull tells his AI he has been grabbed (on_pulled), and he mustn't get a word out.
	ADD_TRAIT(held, TRAIT_MUTE, STEALTH_GRIP_TRAIT)
	if(!holder.start_pulling(held, supress_message = TRUE) || holder.pulling != held)
		end(FALSE)
		return FALSE
	if(holder.grab_state < GRAB_AGGRESSIVE)
		holder.setGrabState(GRAB_AGGRESSIVE)
		held.stop_pulling()
	holder.setGrabState(GRAB_NECK)
	// As tg's neck grab: onto the holder's tile.
	if(!held.buckled && !held.density)
		held.Move(holder.loc)
	if(ended || holder.pulling != held)
		end(FALSE)
		return FALSE
	RegisterSignal(holder, COMSIG_ATOM_NO_LONGER_PULLING, PROC_REF(on_let_go))
	RegisterSignal(holder, COMSIG_MOVABLE_SET_GRAB_STATE, PROC_REF(on_grab_state))
	holder.set_pull_offsets(held, holder.grab_state)
	// as tg's grabbedby() after its grippedby()
	held.update_incapacitated()
	holder.changeNext_move(CLICK_CD_GRABBING)
	playsound(held, 'sound/items/weapons/thudswoosh.ogg', 50, TRUE, -1)
	held.visible_message(
		span_danger("[holder] clamps a hand over [held]'s mouth!"),
		span_userdanger("A hand clamps over your mouth!"),
		span_hear("You hear a muffled struggle."),
		COMBAT_MESSAGE_RANGE,
		holder,
	)
	to_chat(holder, span_danger("You clamp a hand over [held]'s mouth."))
	log_combat(holder, held, "grabbed", addition = "hand over the mouth from behind (neck grab)")
	return TRUE

/// The squeeze, from the hold: TRUE if the click was this (started, already on, or refused here), FALSE for tg's grab.
/datum/stealth_grip/proc/squeeze()
	if(ended)
		return FALSE
	if(squeezing)
		return TRUE
	if(holder.get_active_held_item() || holder.incapacitated || HAS_TRAIT(holder, TRAIT_PACIFISM))
		return FALSE
	var/cover = stealth_grip_neck_cover(held)
	if(cover >= STEALTH_SQUEEZE_MAX_COVER)
		to_chat(holder, span_warning("You can't get your arm round [held]'s neck."))
		return TRUE
	oxy_rate = STEALTH_SQUEEZE_OXY_RATE * (100 - cover) / 100
	holder.setGrabState(GRAB_KILL)
	if(ended || holder.grab_state < GRAB_KILL)
		return TRUE
	squeezing = TRUE
	holder.set_pull_offsets(held, holder.grab_state)
	held.update_incapacitated()
	holder.changeNext_move(CLICK_CD_GRABBING)
	playsound(held, 'sound/items/weapons/thudswoosh.ogg', 50, TRUE, -1)
	held.visible_message(
		span_danger("[holder] locks an arm round [held]'s neck!"),
		span_userdanger("You can't breathe!"),
		span_hear("You hear a struggle."),
		COMBAT_MESSAGE_RANGE,
		holder,
	)
	to_chat(holder, span_danger("You squeeze."))
	log_combat(holder, held, "choked from behind", null, "(squeeze, neck cover [round(cover)])")
	tick_timer = addtimer(CALLBACK(src, PROC_REF(timed_tick)), 1 SECONDS, TIMER_STOPPABLE|TIMER_DELETE_ME)
	return TRUE

/// One second of the squeeze, then the next. A timer, not a processing subsystem, so it runs the same in any runlevel.
/datum/stealth_grip/proc/timed_tick()
	tick_timer = null
	if(squeeze_tick(1) && !ended)
		tick_timer = addtimer(CALLBACK(src, PROC_REF(timed_tick)), 1 SECONDS, TIMER_STOPPABLE|TIMER_DELETE_ME)

/// One step of the squeeze, `seconds_per_tick` long. FALSE once the squeeze is over.
/datum/stealth_grip/proc/squeeze_tick(seconds_per_tick)
	if(ended || !squeezing)
		return FALSE
	if(QDELETED(holder) || QDELETED(held) || holder.pulling != held || holder.grab_state < GRAB_KILL)
		squeezing = FALSE
		return FALSE
	if(holder.incapacitated || holder.stat != CONSCIOUS)
		end(TRUE)
		return FALSE
	if(held.stat == DEAD)
		end(TRUE)
		return FALSE
	if(!HAS_TRAIT(held, TRAIT_NOBREATH) && !held.get_organ_slot(ORGAN_SLOT_BREATHING_TUBE))
		held.adjustOxyLoss(oxy_rate * seconds_per_tick)
	if((held.getOxyLoss() >= STEALTH_SQUEEZE_RELEASE_OXY && HAS_TRAIT(held, TRAIT_KNOCKEDOUT)) || held.health <= HEALTH_THRESHOLD_FULLCRIT + STEALTH_SQUEEZE_CRIT_MARGIN)
		held.visible_message(span_danger("[holder] lets [held] slump to the floor."), null, null, COMBAT_MESSAGE_RANGE, holder)
		to_chat(holder, span_notice("You let [held] slump."))
		end(TRUE)
		return FALSE
	return TRUE

/// Ends the hold. `release` also lets go of him (tg's stop_pulling()).
/datum/stealth_grip/proc/end(release)
	if(ended)
		return
	ended = TRUE
	squeezing = FALSE
	if(tick_timer)
		deltimer(tick_timer)
		tick_timer = null
	var/mob/living/was_holder = holder
	var/mob/living/carbon/human/was_held = held
	if(!isnull(was_holder))
		UnregisterSignal(was_holder, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH, COMSIG_ATOM_NO_LONGER_PULLING, COMSIG_MOVABLE_SET_GRAB_STATE))
		if(was_holder.stealth_grip_holding == src)
			was_holder.stealth_grip_holding = null
		if(release && !QDELETED(was_holder) && was_holder.pulling == was_held)
			was_holder.stop_pulling()
	if(!isnull(was_held))
		UnregisterSignal(was_held, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH))
		REMOVE_TRAIT(was_held, TRAIT_MUTE, STEALTH_GRIP_TRAIT)
		if(was_held.stealth_grip_held == src)
			was_held.stealth_grip_held = null
		stealth_grip_freed(was_held, was_holder)
	if(!QDELETED(src))
		qdel(src)

/// Let go awake: he knows who held him. Alert on them (or wary and looking, if he can't fight them), and he shouts and
/// calls it in now that his mouth is free (tg's can_speak() decides, so a cut throat still can't).
/proc/stealth_grip_freed(mob/living/carbon/human/guard, mob/living/holder)
	if(QDELETED(guard) || guard.stat != CONSCIOUS)
		return
	var/datum/ai_controller/basic_controller/human_npc/stealth/brain = guard.ai_controller
	if(!istype(brain) || brain.stealth_driven())
		return
	brain.stealth_set_wary()
	if(QDELETED(holder))
		return
	brain.stealth_touched(holder)
	brain.stealth_first_hand(get_turf(holder))

// ---------------------------------------------------------------------------------------------
// Not struggling

/// tg's escape_captivity, except that a guard with a hand over his mouth, or one who has put his hands up
/// (stealth_holdup.dm), doesn't try to break a grab. Cuffs, lockers and straps are worked as before.
/datum/ai_planning_subtree/escape_captivity/stealth

/datum/ai_planning_subtree/escape_captivity/stealth/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/body = controller.pawn
	var/datum/ai_controller/basic_controller/human_npc/stealth/brain = controller
	var/holds_still = body.stealth_grip_held || (istype(brain) && brain.holdup_aimer)
	if(holds_still && isturf(body.loc) && !(body.buckled && !ismob(body.buckled)) && !HAS_TRAIT(body, TRAIT_RESTRAINED))
		return
	return ..()

/datum/ai_controller/basic_controller/human_npc/stealth/init_subtrees()
	if(LAZYLEN(planning_subtrees))
		var/list/subtrees = planning_subtrees.Copy()
		var/at = subtrees.Find(/datum/ai_planning_subtree/escape_captivity)
		if(at)
			subtrees[at] = /datum/ai_planning_subtree/escape_captivity/stealth
		else
			at = subtrees.Find(/datum/ai_planning_subtree/escape_captivity/stealth)
		if(at && !(/datum/ai_planning_subtree/stealth_holdup in subtrees))
			subtrees.Insert(at + 1, /datum/ai_planning_subtree/stealth_holdup)
		planning_subtrees = subtrees
	return ..()
