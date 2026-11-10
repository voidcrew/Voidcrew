// The scissor: both blades out, head aimed, a swing at someone adjacent who is dying. The blades rise,
// catch the light, then come down and close on the neck, one blade behind it and one in front, and #509's
// decapitation takes the head. The bearer is drawn by the blade rig (mantis_rig.dm) from the raise to the
// recovery, so the far blade can pass under the neck while the bearer stands over the body. A #509 finisher
// (voidcrew/modules/hyperviolence/finishers/), drawn the way the bosses' are rather than as real blows,
// so the bearer stands rooted and exposed through the wind-up and a hit makes them reel. No mark over the
// victim (owner D34): the wind-up reads only from the bodies. An Atlas frame stops the cut.

/// Starts the scissor on [target] if this swing is one. Returns TRUE if it started.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_try_scissor(mob/living/target, mob/living/user)
	if(!(gore_moves & MANTIS_MOVE_SCISSOR) || !iscarbon(target) || target == user)
		return FALSE
	if(!user.combat_mode || user.zone_selected != BODY_ZONE_HEAD || HAS_TRAIT(user, TRAIT_PACIFISM))
		return FALSE
	// The cheap checks first: most head swings are at someone on their feet.
	if(!mantis_in_crit(target) || length(mantis_held_blades(user, MANTIS_MOVE_SCISSOR)) < 2)
		return FALSE
	var/datum/mantis_bearer/state = user.get_mantis_state()
	if(world.time < state.next_scissor || state.scissor)
		return FALSE
	var/datum/hv_finisher/mantis_scissor/scissor = new(user, target, CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(mantis_scissor_ended)))
	scissor.model = base_icon_state
	if(!scissor.start())
		scissor.on_end = null
		qdel(scissor)
		return FALSE
	state.scissor = scissor
	state.next_scissor = world.time + MANTIS_SCISSOR_COOLDOWN
	return TRUE

/// The scissor ended, however it ended: the blades go back to the guard, and the rig fades into the real bearer.
/proc/mantis_scissor_ended(datum/hv_finisher/mantis_scissor/scissor, result)
	var/mob/living/bearer = scissor.user
	var/datum/mantis_rig/rig = scissor.rig
	scissor.rig = null
	if(!QDELETED(bearer))
		if(bearer.mantis_state?.scissor == scissor)
			bearer.mantis_state.scissor = null
		for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_held_blades(bearer))
			blade.set_mantis_pose(MANTIS_POSE_GUARD)
	rig?.hand_back()
	qdel(scissor)

/datum/hv_finisher/mantis_scissor
	name = "mantis scissor"
	interrupt_damage = 15
	vulnerability = 1.25
	stagger_time = 1 SECONDS
	zone_preference = list(BODY_ZONE_HEAD)
	stages = list(
		/datum/hv_finisher_stage/windup/mantis,
		/datum/hv_finisher_stage/kill/decapitate/mantis,
		/datum/hv_finisher_stage/recover/mantis,
	)
	/// The model of the blades doing it, for the pictures.
	var/model = "mantis"
	/// The bearer drawn around the victim, while it runs.
	var/datum/mantis_rig/rig

/datum/hv_finisher/mantis_scissor/Destroy()
	QDEL_NULL(rig)
	return ..()

/// Draws [beat] of the scissor, if the bearer is drawn by the rig, leaning into it over [time].
/datum/hv_finisher/mantis_scissor/proc/show_beat(beat, time = 0.1 SECONDS)
	rig?.show(beat, time = time)

// Drawn, not real blows: a bearer with two blades fused to the arms makes no aggressive grab, and the
// head comes off by the finisher's own hand. That also roots them and makes them take more damage.
/datum/hv_finisher/mantis_scissor/New(mob/living/user, mob/living/carbon/victim, datum/callback/on_end)
	. = ..()
	real_hits = FALSE

/**
 * #509's check, made for people: it refuses anyone of the attacker's faction, and every player shares
 * one. The scissor goes for anyone dying, as a gun execution does (owner D34). Dying means crit, not
 * just lying down: a lunge knockdown alone is not enough. A human NPC only scissors at execution rank.
 */
/datum/hv_finisher/mantis_scissor/can_start()
	if(QDELETED(user) || user.stat != CONSCIOUS || HAS_TRAIT(user, TRAIT_INCAPACITATED) || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED) || HAS_TRAIT(user, TRAIT_PACIFISM))
		return FALSE
	if(!iscarbon(victim) || QDELETED(victim) || victim == user || HAS_TRAIT(victim, TRAIT_GODMODE))
		return FALSE
	if(!mantis_in_crit(victim))
		return FALSE
	if(victim.has_status_effect(/datum/status_effect/hv_finisher_hold) || HAS_TRAIT_FROM(victim, TRAIT_IMMOBILIZED, MANTIS_IMPALE_TRAIT))
		return FALSE
	if(victim.buckled || !isturf(victim.loc) || !isturf(user.loc) || victim.z != user.z)
		return FALSE
	if(isnull(victim.get_bodypart(BODY_ZONE_HEAD)))
		return FALSE
	if(!user.hv_can_execute())
		return FALSE
	if(length(mantis_held_blades(user, MANTIS_MOVE_SCISSOR)) < 2)
		return FALSE
	// Square on only: from a corner the swing is just a swing
	return get_dist(user, victim) <= 1 && user.Adjacent(victim) && finisher_square_on(user, victim)

// A blade stowed (an EMP, a retract) or the hands bound: it can't close.
/datum/hv_finisher/mantis_scissor/safety_check()
	. = ..()
	if(. || completed)
		return
	if(length(mantis_held_blades(user, MANTIS_MOVE_SCISSOR)) < 2 || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED))
		return HV_FINISHER_ATTACKER_DOWN
	if(finisher_on_corner(user, victim))
		return HV_FINISHER_LOST_GRIP

// #509's wording, but the bearer reels back rather than letting go of a grip they never took.
/datum/hv_finisher/mantis_scissor/interrupt(reason)
	if(!running || completed)
		return
	for(var/datum/hv_finisher_stage/stage as anything in stages)
		if(stage.entered)
			stage.on_interrupt()
	if(reason == HV_FINISHER_DAMAGED)
		user.visible_message(span_danger("[user] reels back from [victim]!"))
		user.apply_status_effect(/datum/status_effect/hv_finisher_reeling, stagger_time)
	stop(reason)

/// Puts the bearer's blades in [pose].
/datum/hv_finisher/mantis_scissor/proc/pose_blades(pose)
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_held_blades(user))
		blade.set_mantis_pose(pose)

// ---- The wind-up -----------------------------------------------------------

/// Someone on the floor is turned so their head lies toward [bearer], the way tg turns someone dragged.
/// Straight above or below them, the head goes to the left, where the blades are drawn to close on it.
/proc/mantis_turn_head_toward(mob/living/victim, mob/living/bearer)
	if(victim.body_position != LYING_DOWN || !victim.rotate_on_lying || !victim.lying_angle)
		return
	if(bearer.x == victim.x)
		victim.set_lying_angle(LYING_ANGLE_WEST)
		return
	victim.set_lying_angle(bearer.x > victim.x ? LYING_ANGLE_EAST : LYING_ANGLE_WEST)

/// Both blades rise. A glint runs along them, and the victim shudders.
/datum/hv_finisher_stage/windup/mantis
	duration = MANTIS_SCISSOR_WINDUP
	rise = 1
	enter_sound = 'sound/items/unsheath.ogg'
	enter_volume = 50
	/// Timer of the glint halfway through.
	var/glint_timer

/datum/hv_finisher_stage/windup/mantis/enter()
	. = ..()
	var/datum/hv_finisher/mantis_scissor/scissor = host
	scissor.pose_blades(MANTIS_POSE_RAISE)
	mantis_turn_head_toward(host.victim, host.user)
	QDEL_NULL(scissor.rig)
	scissor.rig = new(host.user, host.victim, mantis_rig_facing(host.user, host.victim), scissor.model, "scissor")
	if(!scissor.rig.start())
		QDEL_NULL(scissor.rig)
	scissor.show_beat("raise")
	glint_timer = addtimer(CALLBACK(src, PROC_REF(glint)), duration * 0.5, TIMER_STOPPABLE|TIMER_DELETE_ME)

/// Halfway through the wind-up the light runs along the near blade (the rig draws it) and the victim shudders.
/datum/hv_finisher_stage/windup/mantis/proc/glint()
	glint_timer = null
	if(!host?.running)
		return
	var/datum/hv_finisher/mantis_scissor/scissor = host
	scissor.show_beat("glint")
	mantis_struggle_fx(host.victim, duration * 0.5)
	// Not drawn by the rig: the light runs along one held blade instead.
	if(!scissor.rig)
		var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = locate() in host.user.held_items
		blade?.play_glint(MANTIS_POSE_RAISE)

/datum/hv_finisher_stage/windup/mantis/on_stop()
	if(glint_timer)
		deltimer(glint_timer)
		glint_timer = null

/datum/hv_finisher_stage/windup/mantis/Destroy()
	if(glint_timer)
		deltimer(glint_timer)
		glint_timer = null
	return ..()

/datum/hv_finisher_stage/windup/mantis/enter_message()
	return "[host.user] raises both blades over [host.victim]!"

// ---- The cut ---------------------------------------------------------------

/datum/hv_finisher_stage/kill/decapitate/mantis
	duration = 0.6 SECONDS
	// The swing shuts the blades itself, on its own clock (strike()); this only catches a swing that never got there.
	effect_delay = 0.4 SECONDS
	// The blade rig draws the bearer's lean; without it, enter() leans the real bearer.
	lunge = 0
	effect_sound = 'sound/items/weapons/bladeslice.ogg'
	spray_strength = 4
	/// The swing's next frame and the blades shutting, to come.
	var/close_timer
	var/strike_timer
	/// The bearer straightening up out of the cut, to come.
	var/recover_timer

/datum/hv_finisher_stage/kill/decapitate/mantis/Destroy()
	stop_timers()
	return ..()

/datum/hv_finisher_stage/kill/decapitate/mantis/proc/stop_timers()
	for(var/timer in list(close_timer, strike_timer, recover_timer))
		if(timer)
			deltimer(timer)
	close_timer = null
	strike_timer = null
	recover_timer = null

/**
 * The swing: the blades come down out of the raise, close on the neck (the far one passes under it, the near
 * one over it; the blade rig draws both) and shut through it, a frame apart, and the head comes off as they
 * shut. The bearer leans in as they come down.
 */
/datum/hv_finisher_stage/kill/decapitate/mantis/enter()
	. = ..()
	var/datum/hv_finisher/mantis_scissor/scissor = host
	scissor.pose_blades(MANTIS_POSE_GUARD)
	if(!scissor.rig)
		// Drawn as the bearer: a lean, further if the head lies on the far side of the body.
		var/posture = mantis_scissor_posture(host.victim)
		var/toward = get_dir(host.user, host.victim)
		var/far = (posture == "lie90" && (toward & EAST)) || (posture == "lie270" && (toward & WEST))
		host.pose_user(far ? MANTIS_SCISSOR_FAR_LEAN : MANTIS_SCISSOR_LEAN, rise)
	scissor.show_beat("swing", MANTIS_SCISSOR_SWING_STEP)
	close_timer = addtimer(CALLBACK(src, PROC_REF(close)), MANTIS_SCISSOR_SWING_STEP, TIMER_STOPPABLE|TIMER_DELETE_ME)
	strike_timer = addtimer(CALLBACK(src, PROC_REF(strike)), 1.5 * MANTIS_SCISSOR_SWING_STEP, TIMER_STOPPABLE|TIMER_DELETE_ME)

/// The blades meet at the neck.
/datum/hv_finisher_stage/kill/decapitate/mantis/proc/close()
	close_timer = null
	if(!host?.running)
		return
	var/datum/hv_finisher/mantis_scissor/scissor = host
	scissor.show_beat("close", MANTIS_SCISSOR_SWING_STEP)

/// The blades shut through the neck: the stage's beat (effect()), checked the way #509's tick checks it.
/datum/hv_finisher_stage/kill/decapitate/mantis/proc/strike()
	strike_timer = null
	if(!host?.running || host.current_stage != src || effect_done)
		return
	var/reason = host.safety_check()
	if(reason)
		host.end_early(reason)
		return
	host.fire_effect()

/// The blades are through: the bearer straightens back to the guard.
/datum/hv_finisher_stage/kill/decapitate/mantis/proc/recover()
	recover_timer = null
	if(!host?.running)
		return
	var/datum/hv_finisher/mantis_scissor/scissor = host
	scissor.show_beat("recover", MANTIS_SCISSOR_STRAIGHTEN)

/datum/hv_finisher_stage/kill/decapitate/mantis/on_stop()
	. = ..()
	stop_timers()

/**
 * The blades come together at the neck: one line for the cut, a huge one if the head comes off. An
 * Atlas frame (or anything else that won't let the head go) takes a deep cut instead.
 */
/datum/hv_finisher_stage/kill/decapitate/mantis/effect()
	var/mob/living/carbon/victim = host.victim
	var/mob/living/bearer = host.user
	var/datum/hv_finisher/mantis_scissor/scissor = host
	scissor.show_beat("cut", MANTIS_SCISSOR_SWING_STEP)
	// The cut holds, then the bearer straightens.
	if(!recover_timer)
		recover_timer = addtimer(CALLBACK(src, PROC_REF(recover)), MANTIS_SCISSOR_RECOVER_BEAT, TIMER_STOPPABLE|TIMER_DELETE_ME)
	if(effect_sound)
		playsound(victim, effect_sound, effect_volume, TRUE)
	var/spray_dir = away_dir()
	mantis_note_hit(victim, bearer)
	victim.hv_hold_attack_message(
		"[bearer] brings both blades together at [victim]'s neck!",
		"[bearer] brings both blades together at your neck!",
		null,
		null,
		null,
		DEFAULT_MESSAGE_RANGE,
	)
	var/beheads = can_gore()
	if(beheads)
		victim.hv_add_hit_line("[victim]'s head comes off!", HV_LINE_HUGE, "Your head comes off!", DEFAULT_MESSAGE_RANGE)
		gore(spray_dir)
	else
		fallback(spray_dir)
	if(!QDELETED(victim))
		victim.hv_flush_hit()
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_held_blades(bearer))
		blade.drench(victim, light = TRUE)
	// The blades come out of the neck red, and it sprays.
	if(scissor.rig)
		scissor.rig.dress()
		switch(scissor.rig.facing)
			if(NORTH)
				scissor.rig.burst("cut_spray", 0.4 SECONDS, "T")
			if(SOUTH)
				scissor.rig.burst("cut_spray", 0.4 SECONDS, "arms")
			else
				scissor.rig.burst("cut_spray", 0.4 SECONDS, "near", under = TRUE)
	log_combat(bearer, victim, "scissored", addition = "([beheads ? "beheaded" : "cut"])")

// The head stays on: a deep cut across the neck. Atlas plating stops the blades on metal.
/datum/hv_finisher_stage/kill/decapitate/mantis/fallback(spray_dir)
	var/mob/living/carbon/victim = host.victim
	var/mob/living/bearer = host.user
	if(HAS_TRAIT(victim, TRAIT_NODISMEMBER))
		victim.hv_add_hit_line("The blades grind to a stop on metal!", HV_LINE_BOLD, null, DEFAULT_MESSAGE_RANGE)
		playsound(victim, 'sound/items/weapons/block_blade.ogg', 70, TRUE)
	else
		victim.hv_add_hit_line("[bearer]'s blades bite deep into [victim]'s neck!", HV_LINE_BOLD, "[bearer]'s blades bite deep into your neck!", DEFAULT_MESSAGE_RANGE)
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = locate() in bearer.held_items
	victim.apply_damage(MANTIS_SCISSOR_FALLBACK_DAMAGE, BRUTE, BODY_ZONE_HEAD, wound_bonus = 20, sharpness = SHARP_EDGED, attack_direction = spray_dir, attacking_item = blade)
	if(!QDELETED(victim))
		victim.hv_blood_spray(spray_dir, 2)

// #509's: the spray, and the head comes off. Then it comes away from the neck on the floor.
/datum/hv_finisher_stage/kill/decapitate/mantis/gore(spray_dir)
	var/mob/living/carbon/victim = host.victim
	var/angle = victim.lying_angle
	victim.hv_blood_spray(spray_dir, spray_strength)
	var/obj/item/bodypart/head/head = hv_finisher_take_head(victim, WOUND_SLASH)
	mantis_roll_head(head, angle)

/// [head], just cut off a body lying at [angle], comes away from the neck on the floor: from where the neck
/// was to a hand's width off it. Only where it is drawn on its tile.
/proc/mantis_roll_head(obj/item/bodypart/head/head, angle)
	if(QDELETED(head) || !isturf(head.loc) || !angle)
		return
	var/side = angle == LYING_ANGLE_EAST ? 1 : -1
	head.pixel_w = side * MANTIS_HEAD_ROLL_FROM
	head.pixel_z = -MANTIS_HEAD_ROLL_DROP
	animate(head, pixel_w = side * MANTIS_HEAD_ROLL_TO, pixel_z = -MANTIS_HEAD_ROLL_DROP - 2, time = 0.3 SECONDS, easing = SINE_EASING|EASE_OUT)

// ---- After -------------------------------------------------------------------

/// The bearer straightens up out of the cut.
/datum/hv_finisher_stage/recover/mantis
	duration = 0.5 SECONDS
