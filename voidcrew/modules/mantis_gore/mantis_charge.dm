// The charged leap. With the lunge armed, press and hold on a target: past a short tap the bearer sinks
// into a crouch, rooted, blades swept back and glowing brighter the longer they hold. Release to pounce,
// further for a longer hold. A tap is still the ordinary lunge. One solid hit or a stun knocks them out
// of the crouch and costs the whole cooldown; holding too long they straighten up on their own.
//
// The input is tg's hold pattern (full-auto, the Justice mech): the armed button listens to its
// bearer's client for the press and the release. AI bearers, with no client, only ever tap.

/datum/action/cooldown/cyberware/mantis_lunge
	/// The client the armed button listens to.
	var/client/charge_client
	/// world.time the press began, or 0.
	var/charge_started = 0
	/// Who the press was on.
	var/datum/weakref/charge_target
	/// TRUE once the crouch shows.
	var/crouched = FALSE
	/// The body crouched, so it is stood up again even if the button has moved on.
	var/datum/weakref/crouch_body
	/// The glow on each blade while crouched.
	var/list/datum/weakref/crouch_glows
	/// Timer of the crouch showing.
	var/charge_timer
	/// Timer of the next crouch check.
	var/crouch_tick_timer

/datum/action/cooldown/cyberware/mantis_lunge/set_click_ability(mob/on_who)
	. = ..()
	listen_for_charge(on_who)

/datum/action/cooldown/cyberware/mantis_lunge/unset_click_ability(mob/on_who, refund_cooldown = TRUE)
	stop_listening_for_charge()
	cancel_charge()
	return ..()

/datum/action/cooldown/cyberware/mantis_lunge/Remove(mob/removed_from)
	stop_listening_for_charge()
	cancel_charge()
	impale?.finish()
	return ..()

/datum/action/cooldown/cyberware/mantis_lunge/Destroy()
	stop_listening_for_charge()
	cancel_charge()
	impale?.finish()
	impale = null
	return ..()

/datum/action/cooldown/cyberware/mantis_lunge/proc/listen_for_charge(mob/on_who)
	stop_listening_for_charge()
	if(isnull(on_who?.client))
		return
	charge_client = on_who.client
	RegisterSignal(charge_client, COMSIG_CLIENT_MOUSEDOWN, PROC_REF(on_mouse_down))

/datum/action/cooldown/cyberware/mantis_lunge/proc/stop_listening_for_charge()
	if(isnull(charge_client))
		return
	UnregisterSignal(charge_client, list(COMSIG_CLIENT_MOUSEDOWN, COMSIG_CLIENT_MOUSEUP))
	charge_client = null

/datum/action/cooldown/cyberware/mantis_lunge/proc/on_mouse_down(client/source, atom/object, turf/location, control, params)
	SIGNAL_HANDLER
	var/list/modifiers = params2list(params)
	if(!LAZYACCESS(modifiers, LEFT_CLICK) || LAZYACCESS(modifiers, SHIFT_CLICK) || LAZYACCESS(modifiers, CTRL_CLICK) || LAZYACCESS(modifiers, ALT_CLICK))
		return
	if(owner?.click_intercept != src || !isliving(object))
		return
	INVOKE_ASYNC(src, PROC_REF(begin_charge), object)

/datum/action/cooldown/cyberware/mantis_lunge/proc/on_mouse_up(client/source, atom/object, turf/location, control, params)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_CLIENT_MOUSEUP)
	if(!charge_started)
		return
	if(!crouched)
		// A tap: the click that follows is the ordinary lunge.
		cancel_charge(rearm = FALSE)
		return
	INVOKE_ASYNC(src, PROC_REF(release_charge))
	// The crouch was the press: the click that follows it is spent.
	return COMPONENT_CLIENT_MOUSEUP_INTERCEPT

/// How far a leap held for [held] reaches, from a lunge of [base_range].
/proc/mantis_charge_range(held, base_range)
	var/progress = clamp((held - MANTIS_CHARGE_TAP) / (MANTIS_CHARGE_FULL - MANTIS_CHARGE_TAP), 0, 1)
	return base_range + round(MANTIS_CHARGE_EXTRA_RANGE * progress, 1)

/// The press on [target]. Returns TRUE if a charge began.
/datum/action/cooldown/cyberware/mantis_lunge/proc/begin_charge(mob/living/target)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = organ
	var/mob/living/carbon/bearer = owner
	if(charge_started || !istype(housing) || !iscarbon(bearer) || !isliving(target))
		return FALSE
	if(!IsAvailable() || !housing.blade_extended() || HAS_TRAIT(bearer, TRAIT_PACIFISM))
		return FALSE
	if(target == bearer || target.stat == DEAD || bearer.buckled || !isturf(bearer.loc))
		return FALSE
	var/datum/mantis_bearer/state = bearer.get_mantis_state()
	if(world.time < state.next_charge)
		return FALSE
	var/reach = housing.lunge_range + MANTIS_CHARGE_EXTRA_RANGE
	if(get_dist(bearer, target) > reach || !can_see(bearer, target, reach))
		return FALSE
	charge_started = world.time
	charge_target = WEAKREF(target)
	// The field drops the moment they set themselves, not when they leave the floor.
	cyberware_camo_drop(bearer)
	charge_timer = addtimer(CALLBACK(src, PROC_REF(enter_crouch)), MANTIS_CHARGE_TAP, TIMER_STOPPABLE|TIMER_DELETE_ME)
	if(charge_client)
		RegisterSignal(charge_client, COMSIG_CLIENT_MOUSEUP, PROC_REF(on_mouse_up), override = TRUE)
	return TRUE

/// Past the tap: the crouch shows.
/datum/action/cooldown/cyberware/mantis_lunge/proc/enter_crouch()
	if(charge_timer)
		deltimer(charge_timer)
		charge_timer = null
	var/mob/living/carbon/bearer = owner
	if(!charge_started || !iscarbon(bearer) || crouched)
		return
	if(!can_hold_crouch())
		cancel_charge()
		return
	crouched = TRUE
	crouch_body = WEAKREF(bearer)
	ADD_TRAIT(bearer, TRAIT_IMMOBILIZED, MANTIS_CHARGE_TRAIT)
	bearer.add_offsets(MANTIS_CHARGE_TRAIT, z_add = -MANTIS_CHARGE_CROUCH_DROP)
	var/list/housings = get_extended_housings()
	mantis_pose_blades(housings, MANTIS_POSE_COIL)
	crouch_glows = list()
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_housing_blades(housings))
		var/obj/effect/abstract/cyberware_anim/glow = mantis_coil_glow_fx(bearer, blade)
		if(glow)
			crouch_glows += WEAKREF(glow)
	var/mob/living/target = charge_target?.resolve()
	if(target)
		bearer.face_atom(target)
	bearer.visible_message(
		span_boldwarning("[bearer] sinks into a crouch, blades drawn back!"),
		span_warning("You coil to spring."),
	)
	playsound(bearer, 'sound/items/weapons/sear.ogg', 35, TRUE)
	RegisterSignal(bearer, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_crouch_damaged))
	crouch_tick_timer = addtimer(CALLBACK(src, PROC_REF(crouch_tick)), 0.2 SECONDS, TIMER_STOPPABLE|TIMER_DELETE_ME)

/// Whether the bearer can keep crouching: on their feet, unhurt enough, blade out, still meaning harm.
/datum/action/cooldown/cyberware/mantis_lunge/proc/can_hold_crouch()
	var/mob/living/carbon/bearer = owner
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = organ
	if(!iscarbon(bearer) || !istype(housing) || !housing.blade_extended())
		return FALSE
	if(bearer.stat != CONSCIOUS || bearer.buckled || !isturf(bearer.loc) || HAS_TRAIT(bearer, TRAIT_PACIFISM))
		return FALSE
	return TRUE

/// Whether something has put the crouched bearer down: a stun, a knockdown, a fall.
/datum/action/cooldown/cyberware/mantis_lunge/proc/crouch_knocked_out()
	var/mob/living/carbon/bearer = owner
	return HAS_TRAIT(bearer, TRAIT_INCAPACITATED) || HAS_TRAIT(bearer, TRAIT_FLOORED) || bearer.body_position == LYING_DOWN || HAS_TRAIT(bearer, TRAIT_HANDS_BLOCKED)

/datum/action/cooldown/cyberware/mantis_lunge/proc/crouch_tick()
	crouch_tick_timer = null
	if(!crouched)
		return
	if(!iscarbon(owner) || owner.stat != CONSCIOUS)
		cancel_charge()
		return
	if(crouch_knocked_out())
		break_crouch()
		return
	if(!can_hold_crouch())
		cancel_charge()
		return
	if(world.time - charge_started >= MANTIS_CHARGE_MAX_HOLD)
		// Held too long: they straighten up. No cooldown, a moment before they can set again.
		var/mob/living/bearer = owner
		cancel_charge()
		bearer.balloon_alert(bearer, "straightened up")
		return
	crouch_tick_timer = addtimer(CALLBACK(src, PROC_REF(crouch_tick)), 0.2 SECONDS, TIMER_STOPPABLE|TIMER_DELETE_ME)

/datum/action/cooldown/cyberware/mantis_lunge/proc/on_crouch_damaged(datum/source, damage_dealt, damagetype)
	SIGNAL_HANDLER
	if(!crouched || damage_dealt < MANTIS_CHARGE_BREAK_DAMAGE)
		return
	if(!(damagetype in list(BRUTE, BURN, STAMINA)))
		return
	INVOKE_ASYNC(src, PROC_REF(break_crouch))

/// Knocked out of the crouch: no pounce, and the whole cooldown.
/datum/action/cooldown/cyberware/mantis_lunge/proc/break_crouch()
	if(!crouched)
		return
	var/mob/living/carbon/bearer = owner
	cancel_charge()
	if(!iscarbon(bearer))
		return
	for(var/datum/action/cooldown/cyberware/mantis_lunge/lunge as anything in mantis_lunge_actions(bearer))
		lunge.StartCooldown()
	bearer.do_stagger_animation()
	bearer.visible_message(
		span_danger("[bearer] is knocked out of [bearer.p_their()] crouch!"),
		span_userdanger("You're knocked out of your crouch!"),
	)
	if(bearer.click_intercept == src)
		unset_click_ability(bearer, refund_cooldown = FALSE)

/// Let go after the crouch: the leap. Returns TRUE if they sprang.
/datum/action/cooldown/cyberware/mantis_lunge/proc/release_charge()
	var/held = world.time - charge_started
	var/mob/living/target = charge_target?.resolve()
	var/mob/living/carbon/bearer = owner
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = organ
	cancel_charge(rearm = FALSE)
	if(!iscarbon(bearer) || !istype(housing))
		return FALSE
	if(QDELETED(target) || target.stat == DEAD)
		bearer.balloon_alert(bearer, "no target!")
		return FALSE
	if(!IsAvailable(feedback = TRUE) || !housing.blade_extended() || HAS_TRAIT(bearer, TRAIT_PACIFISM))
		return FALSE
	var/range = mantis_charge_range(held, housing.lunge_range)
	if(get_dist(bearer, target) > range || !can_see(bearer, target, range))
		bearer.balloon_alert(bearer, "out of reach!")
		return FALSE
	cyberware_camo_drop(bearer)
	for(var/datum/action/cooldown/cyberware/mantis_lunge/lunge as anything in mantis_lunge_actions(bearer))
		lunge.StartCooldown()
	if(bearer.click_intercept == src)
		unset_click_ability(bearer, refund_cooldown = FALSE)
	bearer.face_atom(target)
	mantis_pose_blades(get_extended_housings(), MANTIS_POSE_LUNGE)
	playsound(bearer, 'sound/items/weapons/sear.ogg', 50, TRUE)
	// The crouch was the telegraph: no second wind-up.
	do_lunge(WEAKREF(target), range, TRUE)
	return TRUE

/**
 * Ends any charge: stands the bearer back up, takes the glow off and puts the blades back in the guard.
 * [rearm] keeps them from setting again for a moment, when the crouch had shown.
 */
/datum/action/cooldown/cyberware/mantis_lunge/proc/cancel_charge(rearm = TRUE)
	if(charge_timer)
		deltimer(charge_timer)
		charge_timer = null
	if(crouch_tick_timer)
		deltimer(crouch_tick_timer)
		crouch_tick_timer = null
	if(charge_client)
		UnregisterSignal(charge_client, COMSIG_CLIENT_MOUSEUP)
	charge_started = 0
	charge_target = null
	if(!crouched)
		return
	crouched = FALSE
	for(var/datum/weakref/glow_ref as anything in crouch_glows)
		var/obj/effect/abstract/cyberware_anim/glow = glow_ref.resolve()
		if(glow)
			qdel(glow)
	crouch_glows = null
	var/mob/living/carbon/bearer = crouch_body?.resolve()
	crouch_body = null
	if(isnull(bearer))
		return
	UnregisterSignal(bearer, COMSIG_MOB_AFTER_APPLY_DAMAGE)
	REMOVE_TRAIT(bearer, TRAIT_IMMOBILIZED, MANTIS_CHARGE_TRAIT)
	bearer.remove_offsets(MANTIS_CHARGE_TRAIT, animate = FALSE)
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_held_blades(bearer))
		if(blade.mantis_pose == MANTIS_POSE_COIL)
			blade.set_mantis_pose(MANTIS_POSE_GUARD)
	if(rearm)
		var/datum/mantis_bearer/state = bearer.get_mantis_state()
		state.next_charge = world.time + MANTIS_CHARGE_REARM
