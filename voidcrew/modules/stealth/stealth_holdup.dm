/**
 * # Hands up
 *
 * tg's own hold-up (code/datums/components/gunpoint.dm): a gun's right-click on someone within
 * GUNPOINT_SHOOTER_STRAY_RANGE (2 tiles) aims it at them, and tg drops the aim when the aimer moves off past that range
 * or out of sight, puts the gun away or bumps them. tg offers a player held up that way a surrender (its *surrender:
 * hands on the head, a 20 s Paralyze). A stealth guard takes it, through the NPC surrender path (npc_surrender():
 * weapons stowed, a line, tg's *surrender), unless:
 * - he is a boss (HUMAN_NPC_RANK_BOSS);
 * - he is alert with a weapon in his hands: he has already drawn;
 * - an alert friend is in view within STEALTH_HOLDUP_BACKUP_RANGE: he has backup.
 * A guard who refuses goes alert on the aimer, and tg's hold-up fires the aimer's gun if he moves or shoots.
 *
 * While he has his hands up (holdup_aimer) his scan is off, he doesn't struggle out of a grab (escape_captivity/stealth,
 * stealth_grip.dm), a grab or a hand on him doesn't set him off, and his AI holds still (stealth_holdup subtree). So the
 * aimer can walk up and take him hostage or cuff him. His surrender's Paralyze running out under the gun, he gives up
 * again. He keeps still while anyone holds him up, holds him in a grab, or the one he gave up to stands next to him gun in hand.
 * Once none of that is true for STEALTH_HOLDUP_BEAT, he makes his move: he goes alert on the aimer, shouts, calls it
 * in and reaches for his weapon once tg's surrender Paralyze lets him up (it runs its full time, as it does for a
 * player who surrenders). Cuffed, hit or
 * out cold, the deal is over and the usual rules take over.
 */

/datum/ai_controller/basic_controller/human_npc/stealth
	/// Who it put its hands up for, while it keeps them up.
	var/datum/weakref/holdup_aimer
	/// world.time its own surrender (tg's *surrender Paralyze) runs out.
	var/holdup_surrender_ends = 0
	/// Timer for its next look at whether it is still covered.
	var/holdup_timer

// ---------------------------------------------------------------------------------------------
// tg's hold-up starting and ending

/datum/component/gunpoint/Initialize(mob/living/targ, obj/item/gun/wep)
	. = ..()
	if(. == COMPONENT_INCOMPATIBLE)
		return
	var/mob/living/carbon/human/npc/guard = targ
	if(ishumannpc(guard))
		var/datum/ai_controller/basic_controller/human_npc/stealth/brain = guard.ai_controller
		if(istype(brain))
			brain.stealth_held_up(parent)

/datum/component/gunpoint/Destroy(force)
	var/mob/living/carbon/human/npc/guard = target
	. = ..()
	if(ishumannpc(guard) && !QDELETED(guard))
		var/datum/ai_controller/basic_controller/human_npc/stealth/brain = guard.ai_controller
		if(istype(brain))
			brain.stealth_holdup_watch()

// ---------------------------------------------------------------------------------------------
// The choice

/// `shooter` has just aimed a gun at it (tg's hold-up): it puts its hands up, or doesn't.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_held_up(mob/living/shooter)
	var/mob/living/carbon/human/npc/guard = pawn
	if(!isliving(shooter) || QDELETED(guard) || guard.stat != CONSCIOUS || stealth_driven())
		return
	// tg's hold-up has just held it still for a moment (Immobilize): that has a name, it isn't harm from nowhere.
	explained_at = world.time
	if(holdup_aimer)
		stealth_holdup_watch()
		return
	if(guard.faction_check_atom(shooter) || stealth_captive() || guard.npc_surrendering)
		return
	var/refusal = stealth_holdup_refusal(shooter)
	if(refusal)
		log_combat(guard, shooter, "refused to give up to a hold-up", null, "([refusal])")
		stealth_touched(shooter)
		return
	holdup_aimer = WEAKREF(shooter)
	stealth_set_wary()
	// It has had a good look at them (decision 40): a disguise won't fool it again, a mask will.
	stealth_make(shooter, FALSE)
	stealth_drop_call()
	stealth_drop_walk()
	log_combat(shooter, guard, "held up", null, "(stealth guard puts their hands up)")
	INVOKE_ASYNC(src, PROC_REF(stealth_holdup_give_up))

/// Why it won't put its hands up for `shooter`, or null if it will.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_holdup_refusal(mob/living/shooter)
	var/mob/living/carbon/human/npc/guard = pawn
	if(guard.npc_rank >= HUMAN_NPC_RANK_BOSS)
		return "boss"
	if(stealth_state() == STEALTH_ALERT)
		for(var/obj/item/held in guard.held_items)
			if(isgun(held) || human_npc_is_melee_weapon(held))
				return "already armed"
	for(var/mob/living/carbon/human/npc/friend in oview(STEALTH_HOLDUP_BACKUP_RANGE, guard))
		if(friend.stat != CONSCIOUS || friend.client || !guard.faction_check_atom(friend))
			continue
		var/datum/ai_controller/basic_controller/human_npc/stealth/friend_brain = friend.ai_controller
		if(istype(friend_brain) && friend_brain.stealth_state() == STEALTH_ALERT)
			return "backup"
	return null

/// Hands up: the NPC surrender (weapons stowed, its line, tg's *surrender).
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_holdup_give_up()
	var/mob/living/carbon/human/npc/guard = pawn
	if(!holdup_aimer || QDELETED(guard))
		return
	if(!guard.npc_surrender())
		stealth_holdup_clear()
		return
	holdup_surrender_ends = world.time + STEALTH_HOLDUP_SURRENDER_TIME
	// The aim may already be gone: tg drops it as fast as the aimer moves.
	stealth_holdup_watch()

// ---------------------------------------------------------------------------------------------
// Keeping them up, and the move

/// Looks again in STEALTH_HOLDUP_BEAT whether anyone still covers it.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_holdup_watch()
	if(!holdup_aimer)
		return
	holdup_timer = addtimer(CALLBACK(src, PROC_REF(stealth_holdup_check)), STEALTH_HOLDUP_BEAT, TIMER_UNIQUE|TIMER_OVERRIDE|TIMER_STOPPABLE|TIMER_DELETE_ME)

/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_holdup_check()
	holdup_timer = null
	if(!holdup_aimer)
		return
	var/mob/living/guard = pawn
	if(QDELETED(guard) || guard.stat != CONSCIOUS || stealth_driven() || HAS_TRAIT(guard, TRAIT_RESTRAINED))
		stealth_holdup_clear()
		return
	if(stealth_holdup_covered())
		stealth_holdup_watch()
		return
	stealth_holdup_break()

/// Whether someone still has it covered: a gun held on it (tg's hold-up, anyone's), a hostile's grab on it, or the one
/// it gave up to right next to it with a gun still in hand (walking up to cuff it).
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_holdup_covered()
	var/mob/living/guard = pawn
	if(guard.has_status_effect(/datum/status_effect/grouped/heldup))
		return TRUE
	var/mob/living/holder = guard.pulledby
	if(isliving(holder) && !guard.faction_check_atom(holder))
		return TRUE
	var/mob/living/aimer = holdup_aimer?.resolve()
	if(QDELETED(aimer) || aimer.stat != CONSCIOUS || get_dist(aimer, guard) > 1)
		return FALSE
	return isgun(aimer.get_active_held_item()) || isgun(aimer.get_inactive_held_item())

/// Nobody covers it any more: it makes its move.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_holdup_break()
	var/mob/living/carbon/human/npc/guard = pawn
	var/mob/living/aimer = holdup_aimer?.resolve()
	stealth_holdup_clear()
	guard.npc_surrender_redecide = FALSE
	if(QDELETED(aimer))
		stealth_first_hand(get_turf(guard))
		return
	log_combat(guard, aimer, "made a move once the hold-up lapsed")
	stealth_touched(aimer)
	stealth_first_hand(get_turf(aimer))

/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_holdup_clear()
	holdup_aimer = null
	holdup_surrender_ends = 0
	if(holdup_timer)
		deltimer(holdup_timer)
		holdup_timer = null

/// Its surrender's Paralyze ran out while a gun is still held on it: it gives up again.
/mob/living/carbon/human/npc/npc_surrender_ended()
	var/datum/ai_controller/basic_controller/human_npc/stealth/brain = ai_controller
	if(istype(brain) && brain.holdup_aimer && !IsParalyzed() && stat == CONSCIOUS && !HAS_TRAIT(src, TRAIT_RESTRAINED) \
		&& has_status_effect(/datum/status_effect/grouped/heldup))
		npc_surrendering = FALSE
		if(npc_surrender())
			brain.holdup_surrender_ends = world.time + STEALTH_HOLDUP_SURRENDER_TIME
			return
	return ..()

// ---------------------------------------------------------------------------------------------
// Holding still

/datum/ai_controller/basic_controller/human_npc/stealth/stealth_scanning()
	. = ..()
	if(. && holdup_aimer)
		return FALSE

// Getting up from its surrender with its hands still up: nothing new happened.
/datum/ai_controller/basic_controller/human_npc/stealth/stealth_came_round()
	if(holdup_aimer)
		stealth_set_wary()
		return
	return ..()

// A grab or a hand on it while its hands are up: it lets it happen.
/datum/ai_controller/basic_controller/human_npc/stealth/on_pulled(mob/living/source, atom/movable/puller)
	SIGNAL_HANDLER
	if(holdup_aimer)
		stealth_set_wary()
		return
	return ..()

/datum/ai_controller/basic_controller/human_npc/stealth/on_handled(mob/living/source, mob/living/toucher)
	SIGNAL_HANDLER
	if(holdup_aimer)
		stealth_set_wary()
		return
	return ..()

// Hurt with its hands up: the deal is off.
/datum/ai_controller/basic_controller/human_npc/stealth/on_pawn_attacked(mob/living/source, atom/attacker, attack_flags)
	if(holdup_aimer)
		stealth_holdup_clear()
	return ..()

/// Hands up: it stands where it is and does nothing else (its surrender's Paralyze does the rest while it lasts).
/datum/ai_planning_subtree/stealth_holdup

/datum/ai_planning_subtree/stealth_holdup/SelectBehaviors(datum/ai_controller/basic_controller/human_npc/stealth/controller, seconds_per_tick)
	if(!istype(controller) || !controller.holdup_aimer)
		return
	var/mob/living/guard = controller.pawn
	if(guard.stat != CONSCIOUS || HAS_TRAIT(guard, TRAIT_RESTRAINED))
		controller.stealth_holdup_clear()
		return
	controller.stealth_drop_walk()
	if(!controller.holdup_timer)
		controller.stealth_holdup_watch()
	return SUBTREE_RETURN_FINISH_PLANNING
