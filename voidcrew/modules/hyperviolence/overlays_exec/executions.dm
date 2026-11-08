// Hyperviolence: gun executions.
//
// After CM-SS13's handle_battlefield_execution() (cmss13-devs/cmss13 @ e9b299d266c2be727403751c3474e085803b5934,
// code/modules/projectiles/gun.dm, AGPL-3.0, by the CM-SS13 team), rewritten for tg's guns.
//
// The trigger: a point-blank click with the head or the mouth selected, on a humanoid who can't fight
// back (down, out cold, dead, cuffed, stunned, held in an aggressive grab, or an NPC staggering on
// its last legs), is an execution: a short wind-up that both have to hold still for, then the gun's
// own shot into the head. A round heavy enough bursts the head (hv_burst_head, which keeps the
// brain); a lighter one leaves a heavy skull wound and finishes them. The brain is never destroyed,
// so revival works as usual. An NPC that leaves a human corpse has the outcome replayed on that
// corpse (corpses/). The mouth click reaches us through tg's handle_suicide(); the head click through
// hv_try_head_execution(), called from a marked line in tg's fire_gun(). Anyone the execution does
// not apply to keeps tg's behaviour: a normal point-blank shot to the head, or tg's slow mouth
// version (which is also how you shoot yourself). Holding someone up (right click) and gun bashes are
// unchanged.

/obj/item/gun/handle_suicide(mob/living/carbon/human/user, mob/living/carbon/human/target, params, bypass_timer)
	if(bypass_timer || !hv_execution_possible(user, target))
		return ..()
	hv_start_execution(user, target, params)

/// Called by tg's fire_gun() for a point-blank shot, after its own checks (safeties, firing pins, the
/// mouth). A head-aimed one at someone who can be executed starts the execution instead of firing.
/// Returns TRUE if it did.
/obj/item/gun/proc/hv_try_head_execution(mob/living/user, atom/target, params)
	if(!doafter_self_shoot || !isliving(user) || user.zone_selected != BODY_ZONE_HEAD)
		return FALSE
	if(!hv_execution_possible(user, target))
		return FALSE
	hv_start_execution(user, target, params)
	return TRUE

/// Whether a head- or mouth-aimed point-blank click by `user` on `target` should be an execution.
/obj/item/gun/proc/hv_execution_possible(mob/living/user, mob/living/target)
	if(!isliving(user) || !isliving(target) || user == target)
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
	var/held = do_after(user, HV_EXECUTION_WINDUP, target, extra_checks = CALLBACK(src, PROC_REF(hv_execution_holds), user, target), interaction_key = DOAFTER_SOURCE_HV_EXECUTION)
	fire_cd = FALSE
	if(!held || QDELETED(src) || QDELETED(user) || QDELETED(target))
		return
	hv_fire_execution(user, target, params)

/// do_after check: the shooter still holds the gun to the head of someone who still can't fight back.
/obj/item/gun/proc/hv_execution_holds(mob/living/user, mob/living/target)
	if(!user.is_holding(src) || !target.hv_can_be_executed())
		return FALSE
	return user.zone_selected == BODY_ZONE_HEAD || user.zone_selected == BODY_ZONE_PRECISE_MOUTH

/// Fires the execution shot. Returns TRUE if the gun went off.
/obj/item/gun/proc/hv_fire_execution(mob/living/user, mob/living/target, params)
	if(!user.is_holding(src) || !user.Adjacent(target) || !can_trigger_gun(user))
		return FALSE
	if(!can_shoot())
		shoot_with_empty_chamber(user)
		return FALSE
	if(!hv_execution_round_ok()) // the round changed under the wind-up: just a point-blank shot
		return process_fire(target, user, TRUE, params, BODY_ZONE_HEAD)
	var/blow = hv_execution_blow(target)
	var/shot_dir = get_dir(user, target)
	// An NPC the bullet itself kills dies before the shot is settled below, so tell it now.
	if((target.hv_leaves_human_corpse || target.hv_gory_own_body) && target.hv_execution_killable())
		target.hv_note_npc_execution(blow, shot_dir)
	if(!process_fire(target, user, TRUE, params, BODY_ZONE_HEAD))
		return FALSE
	log_combat(user, target, "executed", src)
	if(burst_size > 1) // the burst lands over the next few ticks; settle the outcome once it has
		addtimer(CALLBACK(src, PROC_REF(hv_finish_execution), WEAKREF(user), WEAKREF(target), blow, shot_dir), burst_delay * (burst_size - 1) + 1)
	else
		hv_finish_execution(WEAKREF(user), WEAKREF(target), blow, shot_dir)
	return TRUE

/// How hard the chambered round hits a head with the barrel against it, after that head's armour.
/obj/item/gun/proc/hv_execution_blow(mob/living/target)
	var/obj/projectile/bullet = chambered?.loaded_projectile
	if(!bullet)
		return 0
	var/pellets = max(1, chambered.pellets)
	var/blow = bullet.damage * projectile_damage_multiplier * pellets * max(1, burst_size) * HV_EXECUTION_POINT_BLANK_MULT
	if(pellets > 1)
		blow *= HV_EXECUTION_PELLET_MULT
	var/armor = target.run_armor_check(BODY_ZONE_HEAD, bullet.armor_flag, armour_penetration = bullet.armour_penetration, silent = TRUE, weak_against_armour = bullet.weak_against_armour)
	return blow * max(0, 100 - armor) / 100

/// Settles an execution once the shot has landed.
/obj/item/gun/proc/hv_finish_execution(datum/weakref/user_ref, datum/weakref/target_ref, blow, shot_dir)
	var/mob/living/target = target_ref?.resolve()
	if(QDELETED(target))
		return
	target.hv_take_execution(blow, shot_dir)
	hv_execution_witnesses(user_ref?.resolve(), target)

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

/// Whether this mob is down, out cold, cuffed, stunned or held in an aggressive grab.
/mob/living/proc/hv_is_helpless()
	if(stat >= UNCONSCIOUS || body_position == LYING_DOWN)
		return TRUE
	if(HAS_TRAIT(src, TRAIT_RESTRAINED) || HAS_TRAIT(src, TRAIT_INCAPACITATED) || HAS_TRAIT(src, TRAIT_FLOORED))
		return TRUE
	return pulledby?.grab_state >= GRAB_AGGRESSIVE

// An NPC has no crit to fall into: it fights on until it dies. On its last legs it is staggering.
/mob/living/basic/hv_is_helpless()
	if(..())
		return TRUE
	return maxHealth > 0 && stat != DEAD && health <= maxHealth * HV_EXECUTION_STAGGER_HEALTH

// Bounty criminals keep their own cuffs, downed and stunned states (voidcrew/modules/bounties/).
/mob/living/basic/bounty_criminal/hv_is_helpless()
	return ..() || is_restrained() || is_downed() || body_is_stunned()

// ---- What the shot does ----

/// Takes an execution shot that hit with `blow` force, travelling `shot_dir`. Past the shot itself, a
/// target too tough to finish (see hv_execution_killable()) takes nothing extra. A human-looking NPC
/// notes the shot first, so the corpse it leaves, or its own body as it dies, shows the same outcome
/// (corpses/); one already dead shows it at once.
/mob/living/proc/hv_take_execution(blow, shot_dir)
	if(stat != DEAD && !hv_execution_killable())
		return
	var/heavy = blow >= HV_EXECUTION_BURST_DAMAGE
	hv_blood_spray(shot_dir, heavy ? 4 : 3)
	if(hv_body_headless)
		return // nothing left to shoot
	// Only an NPC whose corpse or own body can show it has a head to burst.
	var/bursts = heavy && (hv_leaves_human_corpse || hv_body_head_can_burst())
	if(stat != DEAD && (hv_leaves_human_corpse || hv_gory_own_body))
		hv_note_npc_execution(blow, shot_dir, TRUE)
	if(bursts)
		hv_add_hit_line("[src]'s head bursts apart!", HV_LINE_HUGE, null, DEFAULT_MESSAGE_RANGE)
	else
		hv_add_hit_line("The shot blows out the back of [src]'s skull.", HV_LINE_HUGE, null, DEFAULT_MESSAGE_RANGE)
	if(stat != DEAD)
		hv_execution_kill()
		return
	// A body already dead: nothing settles it at death any more, so it shows now.
	if(bursts)
		hv_burst_body_head(shot_dir, FALSE)
	else if(hv_gory_own_body && hv_looks_human())
		hv_body_skull = 3
		update_appearance(UPDATE_OVERLAYS)

/mob/living/carbon/hv_take_execution(blow, shot_dir)
	if(stat != DEAD && !hv_execution_killable())
		return
	if(blow >= HV_EXECUTION_BURST_DAMAGE && hv_burst_head(shot_dir))
		hv_execution_kill()
		return
	var/obj/item/bodypart/head/head = get_bodypart(BODY_ZONE_HEAD)
	if(isnull(head)) // the shot itself took it
		hv_execution_kill()
		return
	if(!HAS_TRAIT(src, TRAIT_GODMODE) && head.brute_dam < HV_SKULL_HEAVY_BRUTE)
		apply_damage(HV_SKULL_HEAVY_BRUTE - head.brute_dam, BRUTE, head, forced = TRUE, wound_bonus = CANT_WOUND)
	if(!QDELETED(head) && head.owner == src && head.hv_open_skull())
		hv_blood_spray(shot_dir, 3)
		hv_add_hit_line("The shot blows out the back of [src]'s skull.", HV_LINE_HUGE, null, DEFAULT_MESSAGE_RANGE)
	hv_execution_kill()

/// Whether an execution may finish this mob off: alive, mortal, and not a boss-sized health pool.
/mob/living/proc/hv_execution_killable()
	return stat != DEAD && !HAS_TRAIT(src, TRAIT_GODMODE) && maxHealth <= HV_EXECUTION_MAX_HEALTH

/// Finishes off an execution victim if hv_execution_killable() allows it.
/mob/living/proc/hv_execution_kill()
	if(hv_execution_killable())
		adjustBruteLoss(health + 1)

/mob/living/carbon/hv_execution_kill()
	if(!hv_execution_killable())
		return
	// The rest goes in as oxygen damage, not more trauma, so the body stays inside defibrillator limits.
	adjustOxyLoss(health - HEALTH_THRESHOLD_DEAD + 1, forced = TRUE)
