// Hyperviolence: gun executions.
//
// After CM-SS13's handle_battlefield_execution() (cmss13-devs/cmss13 @ e9b299d266c2be727403751c3474e085803b5934,
// code/modules/projectiles/gun.dm, AGPL-3.0, by the CM-SS13 team), rewritten for tg's guns.
//
// The trigger: a point-blank click with the head or the mouth selected, on a humanoid who can't fight
// back (in crit, out cold, dead, lying down, cuffed, stunned or in stamcrit, or held in an aggressive
// grab: tg's own states, nothing else), is an execution: a short wind-up that both have to hold still
// for, then the gun's own round fired into the head, its damage multiplied by
// HV_EXECUTION_POINT_BLANK_MULT for the barrel against the skull. Everything after that is tg's: the
// round's damage after the head's armour, wounds, dismemberment, and death if the damage kills. If the
// round dealt HV_EXECUTION_BURST_DAMAGE or more to the head, the head bursts (hv_burst_head, which keeps
// the brain, so revival works as usual); a lighter round leaves the skull wound its real damage earns.
// A laser or other burn round never bursts the head: it burns a hole in and out of the skull, with
// hardly any blood, and one that heavy goes through the brain (tg's brain damage, which kills on the
// brain's next Life tick and can be treated like any other). Nothing else is added to finish the target off.
//
// The mouth click reaches us through tg's handle_suicide(); the head click through
// hv_try_head_execution(), called from a marked line in tg's fire_gun(). Anyone the execution does
// not apply to keeps tg's behaviour: a normal point-blank shot to the head, or tg's slow mouth
// version (which is also how you shoot yourself). Holding someone up (right click) and gun bashes are
// unchanged. Human NPCs execute only if they are bosses (owner rulings D4 and OC-9, hv_can_execute()).
// Every human-looking NPC is a real body, so what the round does shows on that body; a basic mob shows
// nothing more than the shot.

/obj/item/gun
	/// While an execution round is being fired: the damage it has dealt to the victim's head
	var/hv_execution_head_damage = 0
	/// Counts clicks that went to an execution, so try_fire_gun() can tell its own click took that path
	var/hv_execution_claims = 0

/obj/item/gun/handle_suicide(mob/living/carbon/human/user, mob/living/carbon/human/target, params, bypass_timer)
	if(bypass_timer || !hv_execution_possible(user, target))
		return ..()
	hv_execution_claims++
	hv_start_execution(user, target, params)

/**
 * tg's fire_gun() returns nothing after the mouth path and after the marked head execution hook, so its click carries
 * on down tg's attack chain and the gun also clubs the target (a pistol-whip on top of the execution). A click that
 * went to an execution, whether the barrel was held or the wind-up was refused or broken, ends here instead.
 */
/obj/item/gun/try_fire_gun(atom/target, mob/living/user, params)
	var/claims_before = hv_execution_claims
	. = ..()
	if(hv_execution_claims != claims_before)
		return TRUE

/// Called by tg's fire_gun() for a point-blank shot, after its own checks (safeties, firing pins, the
/// mouth). A head-aimed one at someone who can be executed starts the execution instead of firing.
/// Returns TRUE if it did.
/obj/item/gun/proc/hv_try_head_execution(mob/living/user, atom/target, params)
	if(!doafter_self_shoot || !isliving(user) || user.zone_selected != BODY_ZONE_HEAD)
		return FALSE
	if(!hv_execution_possible(user, target))
		return FALSE
	hv_execution_claims++
	hv_start_execution(user, target, params)
	return TRUE

/// Whether a head- or mouth-aimed point-blank click by `user` on `target` should be an execution.
/obj/item/gun/proc/hv_execution_possible(mob/living/user, mob/living/target)
	if(!isliving(user) || !isliving(target) || user == target)
		return FALSE
	// Only players and boss NPCs execute; anyone else just fires a point-blank shot (owner ruling OC-9).
	if(!user.hv_can_execute())
		return FALSE
	if(!target.hv_can_be_executed() || !user.Adjacent(target))
		return FALSE
	return can_shoot() && hv_execution_round_ok()

/// Whether the chambered round can kill: a harmful brute or burn round, not a toy or a beanbag.
/obj/item/gun/proc/hv_execution_round_ok()
	var/obj/projectile/bullet = chambered?.loaded_projectile
	if(!bullet || !chambered.harmful)
		return FALSE
	if(bullet.damage_type != BRUTE && bullet.damage_type != BURN)
		return FALSE
	if(bullet.stamina > bullet.damage) // less-lethal: beanbags, rubbershot
		return FALSE
	return bullet.damage * projectile_damage_multiplier * max(1, chambered.pellets) >= HV_EXECUTION_MIN_DAMAGE

/// Presses the barrel to the target's head and, if both hold still, fires.
/obj/item/gun/proc/hv_start_execution(mob/living/user, mob/living/target, params)
	if(fire_cd || firing_burst)
		return
	if(HAS_TRAIT(user, TRAIT_PACIFISM))
		to_chat(user, span_warning("[src] is lethally chambered! You don't want to risk harming anyone..."))
		return
	user.visible_message(
		span_danger("[user] presses the barrel of [src] to [target]'s head."),
		span_danger("You press the barrel of [src] to [target]'s head."),
		ignored_mobs = target,
	)
	to_chat(target, span_userdanger("[user] presses the barrel of [src] to your head!"))
	// Like tg's version: no other shot from this gun while the barrel is held there.
	fire_cd = TRUE
	// Everyone in view sees the bar over the shooter (finisher_bar.dm), so do_after shows none of its own.
	var/obj/effect/abstract/hv_exec_bar/bar = hv_exec_bar_start(user, HV_EXECUTION_WINDUP)
	var/held = do_after(user, HV_EXECUTION_WINDUP, target, progress = FALSE, extra_checks = CALLBACK(src, PROC_REF(hv_execution_holds), user, target), interaction_key = DOAFTER_SOURCE_HV_EXECUTION)
	fire_cd = FALSE
	if(!QDELETED(bar))
		bar.finish(held && !QDELETED(src) && !QDELETED(user) && !QDELETED(target))
	if(!held || QDELETED(src) || QDELETED(user) || QDELETED(target))
		return
	hv_fire_execution(user, target, params)

/// do_after check: the shooter still holds the gun to the head of someone who still can't fight back.
/obj/item/gun/proc/hv_execution_holds(mob/living/user, mob/living/target)
	if(!user.is_holding(src) || !target.hv_can_be_executed())
		return FALSE
	return user.zone_selected == BODY_ZONE_HEAD || user.zone_selected == BODY_ZONE_PRECISE_MOUTH

/**
 * Fires the execution round: the gun's own shot at the head through its real fire path, with the
 * point-blank multiplier on its damage. A point-blank round lands inside process_fire(), so what it
 * did to the head is known when that returns. Returns TRUE if the gun went off.
 */
/obj/item/gun/proc/hv_fire_execution(mob/living/user, mob/living/target, params)
	if(!user.is_holding(src) || !user.Adjacent(target) || !can_trigger_gun(user))
		return FALSE
	if(!can_shoot())
		shoot_with_empty_chamber(user)
		return FALSE
	if(!hv_execution_round_ok()) // the round changed under the wind-up: just a point-blank shot
		return process_fire(target, user, TRUE, params, BODY_ZONE_HEAD)
	var/shot_dir = get_dir(user, target)
	var/was_dead = target.stat == DEAD
	var/burns = chambered.loaded_projectile.damage_type == BURN
	hv_execution_head_damage = 0
	RegisterSignal(target, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(hv_execution_hit))
	var/normal_multiplier = projectile_damage_multiplier
	projectile_damage_multiplier *= HV_EXECUTION_POINT_BLANK_MULT
	// Only the first round of a burst is held to the head; the rest are ordinary shots.
	var/fired = process_fire(target, user, TRUE, params, BODY_ZONE_HEAD)
	projectile_damage_multiplier = normal_multiplier
	if(!QDELETED(target))
		UnregisterSignal(target, COMSIG_MOB_APPLY_DAMAGE)
	if(!fired)
		return FALSE
	log_combat(user, target, "executed", src, "([round(hv_execution_head_damage, 0.1)] damage to the head)")
	if(!QDELETED(target))
		target.hv_take_execution(hv_execution_head_damage, shot_dir, was_dead, burns)
		hv_execution_witnesses(user, target)
	return TRUE

/// Adds up what this gun's rounds do to the victim's head while an execution round is fired.
/obj/item/gun/proc/hv_execution_hit(mob/living/source, damage, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, atom/attacking_item)
	SIGNAL_HANDLER
	var/obj/projectile/round = attacking_item
	if(!istype(round) || round.fired_from != src || (damagetype != BRUTE && damagetype != BURN))
		return
	// A body without limbs (a basic mob) takes the whole round in the head it was pressed to.
	if(!iscarbon(source))
		hv_execution_head_damage += damage
		return
	var/zone
	if(isbodypart(def_zone))
		var/obj/item/bodypart/limb = def_zone
		zone = limb.body_zone
	else
		zone = check_zone(def_zone)
	if(zone == BODY_ZONE_HEAD)
		hv_execution_head_damage += damage

/// Everyone who saw it close up feels it, bar the shooter, the victim and those who enjoy that sort of thing.
/proc/hv_execution_witnesses(mob/living/shooter, mob/living/victim)
	for(var/mob/living/carbon/witness in viewers(7, victim))
		if(witness == shooter || witness == victim || witness.stat != CONSCIOUS || witness.is_blind())
			continue
		if(HAS_MIND_TRAIT(witness, TRAIT_MORBID) || HAS_MIND_TRAIT(witness, TRAIT_EVIL))
			continue
		witness.add_mood_event("hv_saw_execution", /datum/mood_event/hv_saw_execution)

/datum/mood_event/hv_saw_execution
	description = "I watched someone get executed."
	mood_change = -4
	timeout = 5 MINUTES

// ---- Who can be executed ----

/// Whether this mob is humanoid and can't fight back, so a gun to the mouth is an execution.
/mob/living/proc/hv_can_be_executed()
	if(!ishuman(src) && !(mob_biotypes & MOB_HUMANOID))
		return FALSE
	return hv_is_helpless()

/// Whether this mob is in crit, out cold, dead, lying down, cuffed, stunned or in stamcrit, or held
/// in an aggressive grab. tg's own states only.
/mob/living/proc/hv_is_helpless()
	if(stat >= SOFT_CRIT || body_position == LYING_DOWN)
		return TRUE
	if(HAS_TRAIT(src, TRAIT_RESTRAINED) || HAS_TRAIT(src, TRAIT_INCAPACITATED) || HAS_TRAIT(src, TRAIT_FLOORED))
		return TRUE
	return pulledby?.grab_state >= GRAB_AGGRESSIVE

// ---- What the round did ----

/**
 * Shows what an execution round did. `head_damage` is what it dealt to the head; `was_dead` whether
 * the target was already dead before it; `burns` whether it was a burn round (a laser). A brute round
 * adds no damage and kills nothing: the round did that or not. A burn round's is hv_burn_through_head().
 * Only a body with a head shows it (below); anything else just took the shot.
 */
/mob/living/proc/hv_take_execution(head_damage, shot_dir, was_dead, burns = FALSE)
	return

/mob/living/carbon/hv_take_execution(head_damage, shot_dir, was_dead, burns = FALSE)
	var/obj/item/bodypart/head/head = get_bodypart(BODY_ZONE_HEAD)
	if(isnull(head) || head_damage <= 0)
		return // the round took the head off itself, or never reached it
	if(burns)
		hv_burn_through_head(head, head_damage, shot_dir)
		return
	if(head_damage >= HV_EXECUTION_BURST_DAMAGE && hv_burst_head(shot_dir))
		return
	// The skull wound the round's real damage earns (gore_overlays.dm); the line only for the worst.
	if(head.hv_open_skull() && head.hv_skull_wound >= 3)
		hv_blood_spray(shot_dir, 3)
		hv_add_hit_line("The shot blows out the back of [src]'s skull.", HV_LINE_HUGE, null, DEFAULT_MESSAGE_RANGE)

/**
 * A beam fired with the barrel to the head: a scorched hole in and a hole out, and next to no blood. As heavy a round
 * as would burst a head goes through the brain instead: tg brain damage at its death line, so the brain's own Life
 * tick kills (brain_item.dm) and a brain repair can bring the body back, as with a burst head.
 */
/mob/living/carbon/proc/hv_burn_through_head(obj/item/bodypart/head/head, head_damage, shot_dir)
	if(head.hv_shows_gore() && !head.hv_burn_hole)
		head.hv_burn_hole = TRUE
		update_damage_overlays()
	if(head_damage < HV_EXECUTION_BURST_DAMAGE)
		return
	adjustOrganLoss(ORGAN_SLOT_BRAIN, BRAIN_DAMAGE_DEATH)
	hv_add_hit_line("The beam burns clean through [src]'s skull.", HV_LINE_HUGE, null, DEFAULT_MESSAGE_RANGE)

/// Whether this mob turns a point-blank head shot on someone helpless into an execution. Players can;
/// human NPCs only at boss rank (human_npcs/human_npc.dm).
/mob/living/proc/hv_can_execute()
	return hv_can_land_aimed_crits()
