// The impaling lunge. A lunge that arrives with both blades on someone already hurt or down skewers them:
// held up on the blades for a beat (pinned to the wall for longer, if one is right behind them), then the
// blades rip out with a spray and they drop. The bearer is rooted with full hands the whole time, and
// the victim's hands stay free, so they can still shoot.

/// Whether a lunge arriving with [housings] skewers [victim]: both blades out and able, a person no bigger
/// than a person, and already hurt or down.
/proc/mantis_can_impale(mob/living/lunger, mob/living/victim, list/housings)
	if(!iscarbon(victim) || victim.stat == DEAD || victim.mob_size > MOB_SIZE_HUMAN)
		return FALSE
	if(!lunger.hv_can_land_aimed_crits())
		return FALSE
	var/list/blades = mantis_housing_blades(housings)
	if(length(blades) < 2)
		return FALSE
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in blades)
		if(!(blade.gore_moves & MANTIS_MOVE_IMPALE))
			return FALSE
	if(HAS_TRAIT_FROM(victim, TRAIT_IMMOBILIZED, MANTIS_IMPALE_TRAIT) || victim.has_status_effect(/datum/status_effect/hv_finisher_hold))
		return FALSE
	if(victim.buckled || !isturf(victim.loc))
		return FALSE
	if(victim.health <= victim.maxHealth * MANTIS_IMPALE_HEALTH_FRACTION)
		return TRUE
	return victim.body_position == LYING_DOWN || victim.stat >= SOFT_CRIT || HAS_TRAIT(victim, TRAIT_INCAPACITATED)

/// Skewers [victim] on the blades of [housings]. Returns TRUE if it took hold.
/proc/mantis_start_impale(datum/action/cooldown/cyberware/mantis_lunge/lunge, mob/living/carbon/lunger, mob/living/carbon/victim, list/housings, knockdown)
	var/datum/mantis_impale/skewer = new(lunger, victim, housings, knockdown)
	if(!skewer.start())
		qdel(skewer)
		return FALSE
	lunge?.impale = skewer
	return TRUE

/datum/action/cooldown/cyberware/mantis_lunge
	/// The skewer this lunge is holding, while it holds.
	var/datum/mantis_impale/impale

/datum/mantis_impale
	var/mob/living/carbon/bearer
	var/mob/living/carbon/victim
	/// The housings whose blades went in.
	var/list/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housings
	/// The way the lunge travelled. The tips come out on that side.
	var/lunge_dir
	/// TRUE when a wall right behind them takes the points.
	var/wall_pin = FALSE
	/// How long they are held.
	var/hold_time = MANTIS_IMPALE_HOLD
	/// How long they go down for when the blades come out.
	var/knockdown = 2 SECONDS
	var/started_at = 0
	/// Damage the bearer has taken since it began.
	var/taken = 0
	var/tick_timer
	/// The tips showing through them.
	var/datum/weakref/tips_ref
	var/running = FALSE

/datum/mantis_impale/New(mob/living/carbon/bearer, mob/living/carbon/victim, list/housings, knockdown)
	. = ..()
	src.bearer = bearer
	src.victim = victim
	src.housings = housings.Copy()
	if(isnum(knockdown))
		src.knockdown = knockdown

/datum/mantis_impale/Destroy()
	if(running)
		finish()
	bearer = null
	victim = null
	housings = null
	return ..()

/datum/mantis_impale/proc/start()
	if(running || QDELETED(bearer) || QDELETED(victim))
		return FALSE
	lunge_dir = get_dir(bearer, victim) || bearer.dir
	var/turf/behind = get_step(victim, lunge_dir)
	wall_pin = !isnull(behind) && hv_blood_spray_blocked(behind)
	hold_time = wall_pin ? MANTIS_IMPALE_PIN_HOLD : MANTIS_IMPALE_HOLD
	running = TRUE
	started_at = world.time
	bearer.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED), MANTIS_IMPALE_TRAIT)
	ADD_TRAIT(victim, TRAIT_IMMOBILIZED, MANTIS_IMPALE_TRAIT)
	// Held up off their feet, or shoved back into the wall.
	if(wall_pin)
		var/shove_x = (lunge_dir & EAST) ? 5 : ((lunge_dir & WEST) ? -5 : 0)
		var/shove_z = (lunge_dir & NORTH) ? 5 : ((lunge_dir & SOUTH) ? -5 : 0)
		victim.add_offsets(MANTIS_IMPALE_TRAIT, w_add = shove_x, z_add = shove_z)
	else
		victim.add_offsets(MANTIS_IMPALE_TRAIT, z_add = 5)
	mantis_pose_blades(housings, MANTIS_POSE_LUNGE)
	tips_ref = WEAKREF(mantis_impale_tips_fx(victim, lunge_dir, model()))
	RegisterSignal(bearer, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_bearer_damaged))
	RegisterSignals(bearer, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING, COMSIG_MOVABLE_MOVED), PROC_REF(on_lost))
	RegisterSignals(victim, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING, COMSIG_MOVABLE_MOVED), PROC_REF(on_lost))
	if(wall_pin)
		victim.visible_message(
			span_danger("[bearer] drives both blades through [victim] and pins [victim.p_them()] to the wall!"),
			span_userdanger("Two blades punch through you and into the wall!"),
		)
	else
		victim.visible_message(
			span_danger("[bearer] drives both blades through [victim] and lifts [victim.p_them()] off [victim.p_their()] feet!"),
			span_userdanger("Two blades punch through you!"),
		)
	schedule_tick()
	return TRUE

/// The model of the blades in them, for the tips.
/datum/mantis_impale/proc/model()
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_housing_blades(housings))
		return blade.base_icon_state
	return "mantis"

/datum/mantis_impale/proc/schedule_tick()
	tick_timer = addtimer(CALLBACK(src, PROC_REF(tick)), 0.2 SECONDS, TIMER_STOPPABLE|TIMER_DELETE_ME)

/datum/mantis_impale/proc/tick()
	tick_timer = null
	if(!running)
		return
	if(!holds())
		finish()
		return
	if(world.time - started_at >= hold_time)
		rip()
		return
	schedule_tick()

/// Whether the hold still holds: both alive and side by side, the blades still out, the bearer on their feet.
/datum/mantis_impale/proc/holds()
	if(QDELETED(bearer) || QDELETED(victim) || bearer.stat != CONSCIOUS || victim.stat == DEAD)
		return FALSE
	if(HAS_TRAIT(bearer, TRAIT_INCAPACITATED) || HAS_TRAIT(bearer, TRAIT_FLOORED))
		return FALSE
	if(!isturf(bearer.loc) || !isturf(victim.loc) || bearer.z != victim.z || get_dist(bearer, victim) > 1)
		return FALSE
	return length(mantis_housing_blades(housings)) >= 1

/// The blades rip out. [half] when the bearer lost their grip: it tears less on the way out.
/datum/mantis_impale/proc/rip(half = FALSE)
	if(!running)
		return
	var/list/blades = mantis_housing_blades(housings)
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/first_blade = length(blades) ? blades[1] : null
	var/damage = half ? MANTIS_IMPALE_RIP_DAMAGE * 0.5 : MANTIS_IMPALE_RIP_DAMAGE
	var/mob/living/carbon/held = victim
	var/mob/living/carbon/holder = bearer
	var/rip_dir = lunge_dir
	var/pinned = wall_pin
	finish()
	if(QDELETED(held) || held.stat == DEAD)
		return
	mantis_note_hit(held, holder)
	if(half)
		held.hv_hold_attack_message("[holder] loses [holder.p_their()] grip on [held]!", "[holder] loses [holder.p_their()] grip on you!", null, null, null, COMBAT_MESSAGE_RANGE)
	else
		held.hv_hold_attack_message("[holder] rips both blades out of [held]!", "[holder] rips both blades out of you!", null, null, null, COMBAT_MESSAGE_RANGE)
	var/armour = held.run_armor_check(BODY_ZONE_CHEST, MELEE, armour_penetration = first_blade?.armour_penetration, silent = TRUE)
	for(var/i in 1 to max(1, length(blades)))
		held.apply_damage(
			damage,
			BRUTE,
			BODY_ZONE_CHEST,
			armour,
			wound_bonus = MANTIS_IMPALE_RIP_WOUND_BONUS,
			sharpness = SHARP_EDGED,
			attack_direction = rip_dir,
			attacking_item = first_blade,
		)
		if(QDELETED(held))
			return
	held.hv_flush_hit()
	if(QDELETED(held))
		return
	held.hv_blood_spray(rip_dir, half ? 2 : 3)
	if(pinned)
		held.hv_blood_lay_wall_spray(get_turf(held), rip_dir, held.get_blood_dna_list(), held.get_static_viruses())
	held.Knockdown(knockdown)
	playsound(held, 'sound/items/weapons/bladeslice.ogg', 70, TRUE)
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in blades)
		blade.drench(held)
	if(!QDELETED(holder))
		mantis_lunge_arrival_fx(holder, held, first_blade?.impact_state || "impact_mantis", 2)
		if(half)
			holder.set_staggered_if_lower(1.5 SECONDS)
	log_combat(holder, held, half ? "lost the grip on" : "ripped the mantis blades out of")

/// The bearer is hit while holding them up. Enough of it and they lose the grip.
/datum/mantis_impale/proc/on_bearer_damaged(datum/source, damage_dealt, damagetype)
	SIGNAL_HANDLER
	if(!running || damage_dealt <= 0)
		return
	taken += damage_dealt
	if(taken >= MANTIS_IMPALE_BREAK_DAMAGE)
		INVOKE_ASYNC(src, PROC_REF(rip), TRUE)

/// Either of them died, was deleted or was moved off the other.
/datum/mantis_impale/proc/on_lost(datum/source)
	SIGNAL_HANDLER
	if(!running)
		return
	// Moving within the hold (a nudge onto the same spot) is fine; apart is not.
	if(!holds())
		finish()

/// Lets go of both, puts everything back, and ends.
/datum/mantis_impale/proc/finish()
	if(!running)
		return
	running = FALSE
	if(tick_timer)
		deltimer(tick_timer)
		tick_timer = null
	var/obj/effect/abstract/cyberware_anim/tips = tips_ref?.resolve()
	if(tips)
		qdel(tips)
	tips_ref = null
	if(bearer)
		UnregisterSignal(bearer, list(COMSIG_MOB_AFTER_APPLY_DAMAGE, COMSIG_LIVING_DEATH, COMSIG_QDELETING, COMSIG_MOVABLE_MOVED))
		bearer.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED), MANTIS_IMPALE_TRAIT)
		for(var/datum/action/cooldown/cyberware/mantis_lunge/lunge as anything in mantis_lunge_actions(bearer))
			if(lunge.impale == src)
				lunge.impale = null
	if(victim)
		UnregisterSignal(victim, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING, COMSIG_MOVABLE_MOVED))
		REMOVE_TRAIT(victim, TRAIT_IMMOBILIZED, MANTIS_IMPALE_TRAIT)
		victim.remove_offsets(MANTIS_IMPALE_TRAIT)
	if(housings)
		mantis_pose_blades(housings, MANTIS_POSE_GUARD)
	if(!QDELETED(src))
		qdel(src)
