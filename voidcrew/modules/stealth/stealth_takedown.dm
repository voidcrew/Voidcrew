/**
 * # Takedowns: the garrotte and the chokehold (stealth step 3b, owner decisions 9, 12, 22, 36)
 *
 * Both are tg's own strangle (a GRAB_KILL hold: the victim is held on his feet where he stands, can't breathe, and
 * struggles out with tg's resist), closed quickly from behind, plus the pressure of the wire or the arm as oxygen
 * damage. Knocking out and dying are tg's: TRAIT_KNOCKEDOUT at 50 oxygen loss, crit and death from the same damage.
 *
 * - Who can be taken: a human with a head, not buckled, not held by someone else, adjacent, and either taken from behind
 *   (tg's check_behind()) while not on guard, or helpless (hv_is_helpless(): down, cuffed, stunned, held). A stealth
 *   guard is on guard unless stealth_caught_off_guard(); anyone else (players included, decision 22) counts as off
 *   guard from behind. Only attackers hv_can_execute() lets (players, boss NPCs), never pacifists.
 * - The garrotte (stealth_garrotte.dm), held in both hands, combat-mode click: the lethal one. It holds until the
 *   victim is dead unless the garroter lets go (tg's own stop-pulling), drops the wire or is pulled off.
 * - The chokehold: empty-handed, combat mode, a grab (ctrl-click or the grab intent): the non-lethal one. It lets go by
 *   itself once the victim is out and STEALTH_CHOKE_RELEASE_OXY deep, so he wakes about 10 s later on tg's breathing.
 * - Wind-up (STEALTH_TAKEDOWN_WINDUP): both hold still; the victim turning to face the attacker, either moving or the
 *   attacker losing the wire or his free hand ends it with nothing done.
 * - Protection: the neck's melee cover, worn armour and physiology armour such as dermal cyberware stacked as tg stacks
 *   them (hv_crit_cover_rating()), slows the wire or the arm in proportion; a sealed helmet or cover at
 *   STEALTH_TAKEDOWN_MAX_COVER stops it closing at all. tg's own strangle still runs under any cover, as it does
 *   for any GRAB_KILL.
 * - While the hold is on the victim is mute (TRAIT_MUTE): no shout, no radio. tg's can_speak() does the rest.
 * - Machines and anything that doesn't breathe (TRAIT_NOBREATH, a breathing tube) take no oxygen damage from it.
 *
 * Visuals are stealth_takedown_motion.dm and change nothing here.
 */

/mob/living
	/// The takedown this mob is doing, if any.
	var/datum/stealth_takedown/stealth_takedown_doing
	/// The takedown this mob is caught in, if any.
	var/datum/stealth_takedown/stealth_takedown_caught

/// Why a takedown can't start, or null if it can. `kind` is STEALTH_TAKEDOWN_*.
/proc/stealth_takedown_refusal(mob/living/attacker, mob/living/target, kind, obj/item/garrotte/wire)
	if(!isliving(attacker) || !ishuman(target) || attacker == target)
		return "no"
	var/mob/living/carbon/human/victim = target
	if(!attacker.combat_mode || HAS_TRAIT(attacker, TRAIT_PACIFISM) || !attacker.hv_can_execute())
		return "no"
	if(attacker.stealth_takedown_doing || victim.stealth_takedown_caught || attacker.incapacitated)
		return "no"
	if(victim.stat == DEAD || isnull(victim.get_bodypart(BODY_ZONE_HEAD)) || victim.buckled)
		return "no"
	if(!attacker.Adjacent(victim) || !isturf(attacker.loc) || !isturf(victim.loc))
		return "no"
	if(victim.pulledby && victim.pulledby != attacker)
		return "no"
	if(kind == STEALTH_TAKEDOWN_GARROTTE)
		if(isnull(wire) || !attacker.is_holding(wire) || !HAS_TRAIT(wire, TRAIT_WIELDED))
			return "no"
	else if(attacker.get_active_held_item())
		return "no"
	if(!stealth_takedown_off_guard(attacker, victim))
		return "front"
	if(stealth_takedown_neck_cover(victim) >= STEALTH_TAKEDOWN_MAX_COVER)
		return "cover"
	return null

/// TRUE if `victim` can be taken by `attacker` now: helpless, or from behind while not on guard.
/proc/stealth_takedown_off_guard(mob/living/attacker, mob/living/carbon/human/victim)
	if(victim.hv_is_helpless())
		return TRUE
	if(!check_behind(attacker, victim))
		return FALSE
	var/mob/living/carbon/human/npc/guard = victim
	if(istype(guard) && istype(guard.ai_controller, /datum/ai_controller/basic_controller/human_npc/stealth))
		return guard.stealth_caught_off_guard(attacker)
	return TRUE

/// How well the neck is covered against the wire or the arm (0-100): a sealed helmet is 100, otherwise the head's melee
/// cover from worn and physiology armour, stacked as tg stacks them.
/proc/stealth_takedown_neck_cover(mob/living/carbon/human/victim)
	if(victim.is_mouth_covered(ITEM_SLOT_HEAD))
		return 100
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)
	if(isnull(head))
		return 100
	return clamp(hv_crit_cover_rating(victim, head, MELEE), 0, 100)

// ---------------------------------------------------------------------------------------------
// The chokehold's trigger: tg's grab (ctrl-click, or the grab intent's click)

/mob/living/grab(mob/living/target)
	if(combat_mode && ishuman(target) && pulling != target && !stealth_takedown_refusal(src, target, STEALTH_TAKEDOWN_CHOKE))
		var/datum/stealth_takedown/hold = new(src, target, STEALTH_TAKEDOWN_CHOKE)
		INVOKE_ASYNC(hold, TYPE_PROC_REF(/datum/stealth_takedown, start))
		return TRUE
	return ..()

// ---------------------------------------------------------------------------------------------
// The hold

/datum/stealth_takedown
	var/mob/living/attacker
	var/mob/living/carbon/human/victim
	/// STEALTH_TAKEDOWN_*
	var/kind
	var/obj/item/garrotte/wire
	/// Oxygen damage a second on top of tg's strangle, after the neck's cover.
	var/oxy_rate = 0
	/// TRUE once the hold has closed (the GRAB_KILL is on).
	var/closed = FALSE
	/// TRUE once it has ended, so it ends once.
	var/ended = FALSE
	/// The timer for the next hold_tick().
	var/tick_timer

/datum/stealth_takedown/New(mob/living/attacker, mob/living/carbon/human/victim, kind, obj/item/garrotte/wire)
	src.attacker = attacker
	src.victim = victim
	src.kind = kind
	src.wire = wire
	attacker.stealth_takedown_doing = src
	victim.stealth_takedown_caught = src
	RegisterSignals(attacker, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH), PROC_REF(on_gone))
	RegisterSignal(victim, COMSIG_QDELETING, PROC_REF(on_gone))
	if(wire)
		RegisterSignal(wire, COMSIG_QDELETING, PROC_REF(on_gone))

/datum/stealth_takedown/Destroy()
	if(!ended)
		end(FALSE)
	attacker = null
	victim = null
	wire = null
	return ..()

/datum/stealth_takedown/proc/on_gone(datum/source)
	SIGNAL_HANDLER
	end(FALSE)

/// The wind-up, then the hold closes. Runs async.
/datum/stealth_takedown/proc/start()
	var/garrotte = kind == STEALTH_TAKEDOWN_GARROTTE
	var/unseen = check_behind(attacker, victim) || victim.is_blind()
	if(garrotte)
		attacker.visible_message(
			span_danger("[attacker] drops a wire over [victim]'s head!"),
			span_danger("You drop the wire over [victim]'s head."),
			ignored_mobs = victim,
			vision_distance = COMBAT_MESSAGE_RANGE,
		)
		to_chat(victim, span_userdanger((unseen ? "A wire drops over your head!" : "[attacker] drops a wire over your head!")))
	else
		attacker.visible_message(
			span_danger("[attacker] hooks an arm round [victim]'s neck!"),
			span_danger("You hook an arm round [victim]'s neck."),
			ignored_mobs = victim,
			vision_distance = COMBAT_MESSAGE_RANGE,
		)
		to_chat(victim, span_userdanger((unseen ? "An arm locks round your neck!" : "[attacker] locks an arm round your neck!")))
	attacker.changeNext_move(CLICK_CD_GRABBING)
	vis_windup()
	var/held = do_after(
		attacker,
		STEALTH_TAKEDOWN_WINDUP,
		victim,
		extra_checks = CALLBACK(src, PROC_REF(windup_holds)),
		interaction_key = STEALTH_TAKEDOWN_DOAFTER,
		hidden = TRUE,
	)
	if(ended)
		return
	if(!held || !windup_holds() || !close())
		end(FALSE)

/// do_after check for the wind-up.
/datum/stealth_takedown/proc/windup_holds()
	if(ended || QDELETED(attacker) || QDELETED(victim))
		return FALSE
	// The takedown is already registered on both, so check the rest of the refusal by hand.
	if(!attacker.combat_mode || attacker.incapacitated || victim.stat == DEAD || victim.buckled || !attacker.Adjacent(victim))
		return FALSE
	if(victim.pulledby && victim.pulledby != attacker)
		return FALSE
	if(kind == STEALTH_TAKEDOWN_GARROTTE)
		if(QDELETED(wire) || !attacker.is_holding(wire) || !HAS_TRAIT(wire, TRAIT_WIELDED))
			return FALSE
	else if(attacker.get_active_held_item())
		return FALSE
	// Turning round to face the attacker ends it; a victim already helpless can't.
	return victim.hv_is_helpless() || check_behind(attacker, victim)

/// tg's strangle, closed at once: the same states grippedby() steps through, in the same order.
/datum/stealth_takedown/proc/close()
	if(attacker.pulling != victim && !attacker.start_pulling(victim, supress_message = TRUE))
		return FALSE
	if(attacker.pulling != victim)
		return FALSE
	var/cover = stealth_takedown_neck_cover(victim)
	if(cover >= STEALTH_TAKEDOWN_MAX_COVER)
		return FALSE
	var/base_rate = kind == STEALTH_TAKEDOWN_GARROTTE ? STEALTH_GARROTTE_OXY_RATE : STEALTH_CHOKE_OXY_RATE
	oxy_rate = base_rate * (100 - cover) / 100
	if(attacker.grab_state < GRAB_AGGRESSIVE)
		attacker.setGrabState(GRAB_AGGRESSIVE)
		victim.stop_pulling()
	attacker.setGrabState(GRAB_KILL)
	// Unlike grippedby(), the victim stays on his own tile and on his feet, held up from behind: tg's neck grab floors
	// him (CHOKEHOLD_TRAIT), this takes that one source off again. He can't move or use his hands (tg's aggressive grab
	// traits) and goes down by tg's own rules when he passes out. No pull offsets: they would turn him to face the
	// attacker; the visuals pull him in instead.
	REMOVE_TRAIT(victim, TRAIT_FLOORED, CHOKEHOLD_TRAIT)
	victim.update_incapacitated()
	closed = TRUE
	ADD_TRAIT(victim, TRAIT_MUTE, STEALTH_TAKEDOWN_TRAIT)
	playsound(victim, 'sound/items/weapons/thudswoosh.ogg', 50, TRUE, -1)
	if(kind == STEALTH_TAKEDOWN_GARROTTE)
		victim.visible_message(
			span_danger("[attacker] pulls the wire tight round [victim]'s neck!"),
			span_userdanger("The wire bites into your neck!"),
			span_hear("You hear a struggle."),
			COMBAT_MESSAGE_RANGE,
			attacker,
		)
		to_chat(attacker, span_danger("You pull the wire tight."))
	else
		victim.visible_message(
			span_danger("[attacker] drags [victim] down in a chokehold!"),
			span_userdanger("You can't breathe!"),
			span_hear("You hear a struggle."),
			COMBAT_MESSAGE_RANGE,
			attacker,
		)
		to_chat(attacker, span_danger("You squeeze."))
	log_combat(attacker, victim, kind == STEALTH_TAKEDOWN_GARROTTE ? "garrotted" : "choked from behind", wire, "(takedown, neck cover [round(cover)])")
	RegisterSignal(attacker, COMSIG_ATOM_NO_LONGER_PULLING, PROC_REF(on_let_go))
	RegisterSignal(attacker, COMSIG_MOVABLE_SET_GRAB_STATE, PROC_REF(on_grab_state))
	vis_close()
	tick_timer = addtimer(CALLBACK(src, PROC_REF(timed_tick)), 1 SECONDS, TIMER_STOPPABLE|TIMER_DELETE_ME)
	return TRUE

/// One second of the hold, then the next. A timer, not a processing subsystem, so it runs the same in any runlevel.
/datum/stealth_takedown/proc/timed_tick()
	tick_timer = null
	if(hold_tick(1) && !ended)
		tick_timer = addtimer(CALLBACK(src, PROC_REF(timed_tick)), 1 SECONDS, TIMER_STOPPABLE|TIMER_DELETE_ME)

/datum/stealth_takedown/proc/on_let_go(datum/source, atom/movable/last_pulled)
	SIGNAL_HANDLER
	end(FALSE)

/datum/stealth_takedown/proc/on_grab_state(datum/source, new_state)
	SIGNAL_HANDLER
	if(new_state < GRAB_KILL)
		end(FALSE)

/// One step of the hold, `seconds_per_tick` long. FALSE once it has ended.
/datum/stealth_takedown/proc/hold_tick(seconds_per_tick)
	if(ended)
		return FALSE
	if(QDELETED(attacker) || QDELETED(victim) || attacker.pulling != victim || attacker.grab_state < GRAB_KILL)
		end(FALSE)
		return FALSE
	if(attacker.incapacitated || attacker.stat != CONSCIOUS)
		end(TRUE)
		return FALSE
	if(kind == STEALTH_TAKEDOWN_GARROTTE && (QDELETED(wire) || !attacker.is_holding(wire) || !HAS_TRAIT(wire, TRAIT_WIELDED)))
		end(TRUE)
		return FALSE
	if(victim.stat == DEAD)
		attacker.visible_message(span_danger("[attacker] lets go of [victim]."), span_notice("You let go."), vision_distance = COMBAT_MESSAGE_RANGE)
		end(TRUE)
		return FALSE
	if(!HAS_TRAIT(victim, TRAIT_NOBREATH) && !victim.get_organ_slot(ORGAN_SLOT_BREATHING_TUBE))
		victim.adjustOxyLoss(oxy_rate * seconds_per_tick)
	vis_tick()
	if(kind == STEALTH_TAKEDOWN_CHOKE && victim.getOxyLoss() >= STEALTH_CHOKE_RELEASE_OXY && HAS_TRAIT(victim, TRAIT_KNOCKEDOUT))
		victim.visible_message(span_danger("[attacker] lets [victim] slump to the floor."), null, null, COMBAT_MESSAGE_RANGE, attacker)
		to_chat(attacker, span_notice("You let [victim] slump."))
		end(TRUE)
		return FALSE
	return TRUE

/// Ends the takedown. `release` also lets go of the victim (tg's stop_pulling()).
/datum/stealth_takedown/proc/end(release)
	if(ended)
		return
	ended = TRUE
	if(tick_timer)
		deltimer(tick_timer)
		tick_timer = null
	vis_end()
	if(!isnull(attacker))
		UnregisterSignal(attacker, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH, COMSIG_ATOM_NO_LONGER_PULLING, COMSIG_MOVABLE_SET_GRAB_STATE))
		if(attacker.stealth_takedown_doing == src)
			attacker.stealth_takedown_doing = null
		if(release && !QDELETED(attacker) && attacker.pulling == victim)
			attacker.stop_pulling()
	if(!isnull(victim))
		UnregisterSignal(victim, COMSIG_QDELETING)
		REMOVE_TRAIT(victim, TRAIT_MUTE, STEALTH_TAKEDOWN_TRAIT)
		if(victim.stealth_takedown_caught == src)
			victim.stealth_takedown_caught = null
	if(!isnull(wire))
		UnregisterSignal(wire, COMSIG_QDELETING)
	if(!QDELETED(src))
		qdel(src)
