/**
 * # The charged haymaker
 *
 * A chrome wheel chip on each real Gorilla arm. Hold Use chrome to wind up and let go to throw it at
 * whoever is in the tile you face; or tap Use chrome (or pick the chip) and click someone next to you.
 * The wind-up slows the bearer, lets go of any grab and leans back, so the target has a
 * beat to step out of line. The hit sends the body flying along the safe path, further for a full
 * charge; into a wall it hits harder and cracks the chest. A swing at nobody staggers the bearer.
 * Held too long, or called off, the charge is lost.
 *
 * The haymaker and every Gorilla finisher share one cooldown, kept on the bearer, so they never chain.
 */

/datum/action/cooldown/cyberware/gorilla_haymaker
	name = "Haymaker"
	desc = "Wind up one fist and put everything behind it."
	button_icon = GORILLA_GORE_ICON
	button_icon_state = "chip_haymaker"
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED | AB_CHECK_HANDS_BLOCKED
	cooldown_time = GORILLA_PISTONS_COOLDOWN
	click_to_activate = TRUE
	unset_after_click = TRUE
	/// world.time the wind-up began, 0 when not winding up
	var/charge_started = 0
	/// world.time Use chrome went down for this charge, so a short press reads as a tap
	var/pressed_at = 0
	/// Set while a release unsets the click ability, so that doesn't read as calling it off
	var/releasing = FALSE
	/// Timer that vents a charge held too long
	var/vent_timer
	/// Timer for a release made before the minimum wind-up: it lands when the wind-up is done
	var/release_timer

/datum/action/cooldown/cyberware/gorilla_haymaker/Destroy()
	stop_charge()
	return ..()

/datum/action/cooldown/cyberware/gorilla_haymaker/Remove(mob/remove_from)
	if(charge_started)
		stop_charge()
	return ..()

/datum/action/cooldown/cyberware/gorilla_haymaker/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return
	if(!TIMER_COOLDOWN_FINISHED(owner, COOLDOWN_GORILLA_PISTONS))
		if(feedback)
			owner.balloon_alert(owner, "pistons still hot!")
		return FALSE
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm = organ
	if(!istype(arm) || !arm.heavy_moves || !gorilla_may_use_heavy_moves(owner) || HAS_TRAIT(owner, TRAIT_PACIFISM))
		return FALSE
	return TRUE

/// Whether a wind-up is running.
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/charging()
	return charge_started > 0

// A second press while winding up throws it at the tile you face.
/datum/action/cooldown/cyberware/gorilla_haymaker/Trigger(mob/clicker, trigger_flags, atom/target)
	if(charging() && !target && owner)
		if(!IsAvailable(feedback = TRUE))
			return FALSE
		release(get_step(owner, owner.dir))
		return TRUE
	return ..()

/datum/action/cooldown/cyberware/gorilla_haymaker/set_click_ability(mob/on_who)
	. = ..()
	start_charge()

/datum/action/cooldown/cyberware/gorilla_haymaker/unset_click_ability(mob/on_who, refund_cooldown = TRUE)
	. = ..()
	// Called off by hand (the chip again, a stun, the arm going dark): the pistons vent.
	if(charging() && !releasing && !release_timer)
		vent()

/datum/action/cooldown/cyberware/gorilla_haymaker/Activate(atom/target)
	return release(target)

/// Use chrome came back up: a held press throws it at the tile you face, a tap waits for a click.
/datum/action/cooldown/cyberware/gorilla_haymaker/chrome_use_released(mob/living/carbon/bearer)
	if(!charging() || bearer != owner || release_timer)
		return FALSE
	if(world.time - pressed_at < GORILLA_HAYMAKER_TAP || !IsAvailable(feedback = TRUE))
		return FALSE
	release(get_step(owner, owner.dir))
	return TRUE

/**
 * Winds up and lets go at [target] after [hold_time], with no click or key: the same wind-up anyone can see
 * and dodge. For an AI. Returns TRUE if the wind-up began.
 */
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/wind_up_at(atom/target, hold_time = GORILLA_HAYMAKER_FULL_CHARGE)
	if(charging() || !IsAvailable())
		return FALSE
	start_charge()
	if(!charging())
		return FALSE
	release_timer = addtimer(CALLBACK(src, PROC_REF(queued_release), WEAKREF(target)), max(hold_time, GORILLA_HAYMAKER_MIN_CHARGE), TIMER_STOPPABLE|TIMER_DELETE_ME)
	return TRUE

/// Begins the wind-up.
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/start_charge()
	var/mob/living/carbon/bearer = owner
	if(!iscarbon(bearer) || charging())
		return
	charge_started = world.time
	pressed_at = world.time
	bearer.apply_status_effect(/datum/status_effect/gorilla_windup, src)
	vent_timer = addtimer(CALLBACK(src, PROC_REF(vent)), GORILLA_HAYMAKER_VENT_AFTER, TIMER_STOPPABLE|TIMER_DELETE_ME)

/// Ends the wind-up without throwing anything. Clears every timer and the look.
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/stop_charge()
	charge_started = 0
	pressed_at = 0
	if(vent_timer)
		deltimer(vent_timer)
		vent_timer = null
	if(release_timer)
		deltimer(release_timer)
		release_timer = null
	var/mob/living/bearer = owner
	if(!QDELETED(bearer))
		var/datum/status_effect/gorilla_windup/windup = bearer.has_status_effect(/datum/status_effect/gorilla_windup)
		if(windup?.action == src)
			qdel(windup)

/// Held too long, or called off: a short cooldown, nothing thrown.
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/vent()
	vent_timer = null
	if(!charging())
		return
	var/mob/living/bearer = owner
	stop_charge()
	if(QDELETED(bearer))
		return
	gorilla_spend_pistons(bearer, GORILLA_PISTONS_VENTED)
	if(bearer.click_intercept == src)
		releasing = TRUE
		unset_click_ability(bearer, refund_cooldown = FALSE)
		releasing = FALSE

/// The wind-up's status effect went away under it (a stun, death): end quietly, no vent.
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/windup_lost()
	if(!charging())
		return
	charge_started = 0
	pressed_at = 0
	if(vent_timer)
		deltimer(vent_timer)
		vent_timer = null
	if(release_timer)
		deltimer(release_timer)
		release_timer = null
	if(owner?.click_intercept == src)
		releasing = TRUE
		unset_click_ability(owner, refund_cooldown = FALSE)
		releasing = FALSE

/**
 * Lets it go at [target] (a mob, or a tile to swing into). Before the minimum wind-up the blow waits
 * and lands when it is done. Returns TRUE if anything was thrown or queued.
 */
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/release(atom/target)
	if(!charging() || release_timer)
		return FALSE
	var/held = world.time - charge_started
	if(held < GORILLA_HAYMAKER_MIN_CHARGE)
		var/datum/weakref/target_ref = WEAKREF(target)
		release_timer = addtimer(CALLBACK(src, PROC_REF(queued_release), target_ref), GORILLA_HAYMAKER_MIN_CHARGE - held, TIMER_STOPPABLE|TIMER_DELETE_ME)
		return TRUE
	throw_haymaker(target, held)
	return TRUE

/datum/action/cooldown/cyberware/gorilla_haymaker/proc/queued_release(datum/weakref/target_ref)
	release_timer = null
	if(!charging() || !IsAvailable())
		stop_charge()
		return
	throw_haymaker(target_ref?.resolve(), world.time - charge_started)

/// The swing itself, [held] deciseconds into the wind-up.
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/throw_haymaker(atom/target, held)
	var/mob/living/carbon/human/bearer = owner
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm = organ
	stop_charge()
	if(bearer?.click_intercept == src)
		releasing = TRUE
		unset_click_ability(bearer, refund_cooldown = FALSE)
		releasing = FALSE
	if(!ishuman(bearer) || !istype(arm) || arm.owner != bearer)
		return
	gorilla_spend_pistons(bearer, GORILLA_PISTONS_COOLDOWN)
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/both as anything in gorilla_heavy_arms(bearer))
		COOLDOWN_START(both, slam_cooldown, both.punch_cooldown_time)
	bearer.changeNext_move(CLICK_CD_MELEE)
	// Swinging from inside a camo field drops it, as any blow does
	cyberware_camo_drop(bearer, "haymaker")
	var/mob/living/victim = gorilla_haymaker_victim(bearer, target)
	if(isnull(victim))
		var/turf/swing_at = isturf(target) ? target : get_step(bearer, bearer.dir)
		if(swing_at)
			bearer.face_atom(swing_at)
			// The lunge only: a fist that met nothing leaves no mark on the floor
			bearer.do_attack_animation(swing_at)
		playsound(bearer, 'sound/items/weapons/punchmiss.ogg', 50, TRUE)
		bearer.visible_message(span_danger("[bearer]'s fist hits nothing but air!"), span_userdanger("Your fist hits nothing but air!"))
		bearer.adjust_staggered_up_to(1 SECONDS, 1 SECONDS)
		return
	var/charge = clamp((held - GORILLA_HAYMAKER_MIN_CHARGE) / (GORILLA_HAYMAKER_FULL_CHARGE - GORILLA_HAYMAKER_MIN_CHARGE), 0, 1)
	gorilla_haymaker_hit(bearer, victim, arm, charge)

/// Who a haymaker at [target] hits: the clicked body if it is next to the bearer, else whoever stands in that tile.
/proc/gorilla_haymaker_victim(mob/living/bearer, atom/target)
	if(isliving(target) && target != bearer && bearer.Adjacent(target))
		return target
	var/turf/swing_at = isturf(target) ? target : get_turf(target)
	if(isnull(swing_at) || get_dist(bearer, swing_at) != 1)
		swing_at = get_step(bearer, get_dir(bearer, target) || bearer.dir)
	if(isnull(swing_at) || !bearer.Adjacent(swing_at))
		return null
	var/mob/living/lying
	for(var/mob/living/body in swing_at)
		if(body == bearer || body.stat == DEAD)
			continue
		if(body.body_position != LYING_DOWN)
			return body
		lying ||= body
	return lying

/// A landed haymaker: [charge] 0 to 1 sets the damage and the reach.
/proc/gorilla_haymaker_hit(mob/living/carbon/human/bearer, mob/living/victim, obj/item/organ/cyberimp/cyberware/gorilla_arms/arm, charge)
	var/obj/item/bodypart/hand = bearer.get_bodypart(arm.zone)
	var/damage = round(GORILLA_HAYMAKER_MIN_DAMAGE + (GORILLA_HAYMAKER_MAX_DAMAGE - GORILLA_HAYMAKER_MIN_DAMAGE) * charge)
	var/reach = charge >= 1 ? GORILLA_HAYMAKER_MAX_RANGE : GORILLA_HAYMAKER_MIN_RANGE
	var/direction = get_dir(bearer, victim) || bearer.dir
	bearer.face_atom(victim)
	// The lunge only, as with the piston punch: the sparks are the blow's mark and stay where it landed
	bearer.do_attack_animation(victim)
	if(ishuman(victim))
		var/mob/living/carbon/human/human_victim = victim
		if(human_victim.check_block(bearer, damage, "[bearer]'s haymaker"))
			playsound(victim, 'sound/items/weapons/punchmiss.ogg', 40, TRUE)
			log_combat(bearer, victim, "attempted a haymaker on", "gorilla arms")
			return FALSE
	var/list/plan = gorilla_plan_knockback(victim, direction, reach)
	var/flies = plan[2] > 0 && victim.body_position != LYING_DOWN && !victim.buckled && !victim.anchored
	if(flies)
		victim.hv_hold_attack_message("[bearer] drives a fist into [victim] and sends [victim.p_them()] flying!", "[bearer] drives a fist into you and sends you flying!", "You drive a fist into [victim] and send [victim.p_them()] flying!", bearer, vision_range = DEFAULT_MESSAGE_RANGE)
	else
		victim.hv_hold_attack_message("[bearer] drives a fist into [victim]!", "[bearer] drives a fist into you!", "You drive a fist into [victim]!", bearer, vision_range = DEFAULT_MESSAGE_RANGE)
	var/zone = victim.get_random_valid_zone(bearer.zone_selected)
	var/armour = victim.run_armor_check(zone, MELEE, armour_penetration = hand?.unarmed_effectiveness)
	var/list/wounds_before
	if(iscarbon(victim))
		var/mob/living/carbon/carbon_victim = victim
		wounds_before = carbon_victim.gorilla_wound_snapshot()
	if(flies)
		// The flight leaves its own trail and the wall its own marks; no #509 fan on top of them
		gorilla_hold_spray(victim)
	var/dealt = victim.apply_damage(damage, BRUTE, zone, armour, wound_bonus = GORILLA_PUNCH_WOUND_BONUS + 5, attack_direction = direction, attacking_item = hand)
	var/wounded = FALSE
	if(iscarbon(victim) && !QDELETED(victim))
		var/mob/living/carbon/carbon_victim = victim
		if(dealt >= GORILLA_STRAIN_MIN_DAMAGE)
			gorilla_add_strain(carbon_victim, check_zone(zone), bearer, arm.snap_strain, hand, direction)
		wounded = gorilla_new_wound(carbon_victim, wounds_before)
	victim.hv_flush_hit()
	gorilla_register_aggression(victim, bearer)
	gorilla_haymaker_impact_sound(victim)
	arm.gorilla_punch_fx(bearer, victim, TRUE, zone)
	cyberware_flash_fx(victim, 0.2 SECONDS)
	shake_camera(victim, 3, 2)
	if(flies && !QDELETED(victim))
		gorilla_launch(victim, bearer, direction, reach, GORILLA_HAYMAKER_SPEED, FALSE, TRUE, wounded)
	log_combat(bearer, victim, "landed a haymaker on", "gorilla arms", "(charge [round(charge * 100)]%)")
	return TRUE

/// A haymaker from [bearer] at [target] with whichever arm is ready, wound up for [hold_time]. For an AI. Returns TRUE if it began.
/proc/gorilla_try_haymaker(mob/living/carbon/human/bearer, atom/target, hold_time = GORILLA_HAYMAKER_FULL_CHARGE)
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in gorilla_heavy_arms(bearer))
		for(var/datum/action/cooldown/cyberware/gorilla_haymaker/haymaker in arm.actions)
			if(haymaker.owner == bearer && haymaker.wind_up_at(target, hold_time))
				return TRUE
	return FALSE

/// Starts the pistons' shared cooldown on [bearer] and shows it on every haymaker chip.
/proc/gorilla_spend_pistons(mob/living/bearer, time)
	gorilla_cooldown(bearer, COOLDOWN_GORILLA_PISTONS, time)
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in gorilla_heavy_arms(bearer))
		for(var/datum/action/cooldown/cyberware/gorilla_haymaker/haymaker in arm.actions)
			haymaker.StartCooldownSelf(time)

// =========================================================================
// THE WIND-UP
// =========================================================================

/// The bearer winding up a haymaker: slowed, empty-handed of grabs, leaning back, trembling at full charge.
/datum/status_effect/gorilla_windup
	id = "gorilla_windup"
	alert_type = null
	duration = GORILLA_HAYMAKER_VENT_AFTER + 1 SECONDS
	tick_interval = 0.2 SECONDS
	status_type = STATUS_EFFECT_UNIQUE
	/// The haymaker winding up
	var/datum/action/cooldown/cyberware/gorilla_haymaker/action
	/// Trembling at full charge
	var/trembling = FALSE
	/// Which way the tremble's next pixel goes
	var/tremble_side = 1

/datum/status_effect/gorilla_windup/on_creation(mob/living/new_owner, datum/action/cooldown/cyberware/gorilla_haymaker/action)
	src.action = action
	return ..()

/datum/status_effect/gorilla_windup/on_apply()
	if(owner.stat != CONSCIOUS)
		return FALSE
	owner.add_movespeed_modifier(/datum/movespeed_modifier/gorilla_windup)
	if(owner.pulling)
		owner.stop_pulling()
	RegisterSignal(owner, COMSIG_MOB_STATCHANGE, PROC_REF(on_stat_change))
	RegisterSignal(owner, COMSIG_ATOM_POST_DIR_CHANGE, PROC_REF(on_turned))
	lean()
	return TRUE

/**
 * Leans back from the way they face now, further as the charge builds, so the whole wind-up moves: away from the
 * target seen from the side (a pixel at once, GORILLA_HAYMAKER_LEAN at full charge), half as far up the screen when
 * they face the viewer and down it when they face away. A tracked offset tg eases to and removes cleanly.
 */
/datum/status_effect/gorilla_windup/proc/lean()
	var/charged = action?.charging() ? clamp((world.time - action.charge_started) / GORILLA_HAYMAKER_FULL_CHARGE, 0, 1) : 0
	var/back_by = 1 + round(charged * (GORILLA_HAYMAKER_LEAN - 1))
	var/up_by = CEILING(back_by / 2, 1)
	var/back = REVERSE_DIR(owner.dir)
	var/dx = (back & EAST) ? back_by : ((back & WEST) ? -back_by : 0)
	var/dz = (back & NORTH) ? up_by : ((back & SOUTH) ? -up_by : 0)
	owner.add_offsets(id, x_add = dx, z_add = dz)

/// Turned mid wind-up: the lean turns with them.
/datum/status_effect/gorilla_windup/proc/on_turned(datum/source, old_dir, new_dir)
	SIGNAL_HANDLER
	if(old_dir != new_dir)
		lean()

/datum/status_effect/gorilla_windup/on_remove()
	UnregisterSignal(owner, list(COMSIG_MOB_STATCHANGE, COMSIG_ATOM_POST_DIR_CHANGE))
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/gorilla_windup)
	owner.remove_offsets("[id]_tremble", animate = FALSE)
	owner.remove_offsets(id)
	var/datum/action/cooldown/cyberware/gorilla_haymaker/haymaker = action
	action = null
	haymaker?.windup_lost()

/datum/status_effect/gorilla_windup/Destroy()
	action = null
	return ..()

/datum/status_effect/gorilla_windup/tick(seconds_between_ticks)
	// Stunned, cuffed or knocked down mid wind-up: the swing is lost
	if(HAS_TRAIT(owner, TRAIT_INCAPACITATED) || HAS_TRAIT(owner, TRAIT_HANDS_BLOCKED) || owner.body_position == LYING_DOWN)
		qdel(src)
		return
	if(!action?.charging())
		return
	lean()
	if(world.time - action.charge_started < GORILLA_HAYMAKER_FULL_CHARGE)
		return
	// Full: a tremble for as long as it is held, a pixel either way. A tracked offset, so it can't leave them
	// off their tile, and never the pixel of nothing tg's random jitter can roll
	trembling = TRUE
	tremble_side = -tremble_side
	owner.add_offsets("[id]_tremble", w_add = tremble_side, animate = FALSE)

/datum/status_effect/gorilla_windup/proc/on_stat_change(datum/source, new_stat, old_stat)
	SIGNAL_HANDLER
	if(new_stat != CONSCIOUS)
		qdel(src)

/datum/movespeed_modifier/gorilla_windup
	multiplicative_slowdown = 1.5
