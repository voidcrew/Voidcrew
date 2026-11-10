// Hyperviolence visuals: boss finishers (finishers/).
// 18. The wind-up: the boss rears up, bigger and leaning back, then comes down as the pin lands.
//     Stages with a lift raise the victim off the floor (in the matriarch's and the empress's jaws).
//     The matriarch shakes her victim like a dog with a rat. When the Black Knight cuts someone in
//     half the halves slide apart. The killing blow gets a hit-stop on both, and the screens of
//     players who saw it shake a little.
// Everything is let go when the finisher stops, however it stops.

/datum/hv_finisher_stage
	/// Pixels the victim is lifted off the floor during this stage. 0 sets them back down.
	var/hv_vis_lift = 0

/datum/hv_finisher_stage/maul/hoarfrost
	hv_vis_lift = 8

/datum/hv_finisher_stage/kill/rip_limb/hoarfrost
	hv_vis_lift = 8

/datum/hv_finisher_stage/hold/alien_empress_jaws
	hv_vis_lift = 6

/datum/hv_finisher_stage/kill/decapitate/alien_empress
	hv_vis_lift = 6

/datum/hv_finisher_stage/enter()
	. = ..()
	if(!host?.running || QDELETED(host.victim))
		return
	if(hv_vis_lift)
		host.victim.hv_vis_lift(hv_vis_lift, duration + 1 SECONDS)
	else
		host.victim.hv_vis_release(HV_VIS_TAG_LIFT, 2)

/datum/hv_finisher_stage/windup/enter()
	. = ..()
	if(host?.running && !QDELETED(host.user) && !QDELETED(host.victim))
		host.user.hv_vis_rear(host.victim, duration)

/datum/hv_finisher_stage/maul/hoarfrost/effect()
	. = ..()
	if(!host?.running || QDELETED(host.victim) || QDELETED(host.user))
		return
	host.victim.hv_vis_dog_shake(get_dir(host.user, host.victim))
	host.user.hv_vis_head_shake()

/// The killing blow: a hit-stop on both, and the screens of those who saw it shake.
/datum/hv_finisher_stage/kill/effect()
	. = ..()
	if(!host || QDELETED(host.victim) || QDELETED(host.user))
		return
	var/kill_dir = get_dir(host.user, host.victim) || host.user.dir
	host.victim.hv_vis_big_hit(kill_dir, host.user)
	hv_vis_shake_viewers(host.victim, HV_VIS_KILL_SHAKE_RANGE, HV_VIS_KILL_SHAKE_TIME, HV_VIS_KILL_SHAKE_STRENGTH)

/// Cut in half: the legs slide off one way across the floor and the body the other.
/datum/hv_finisher_stage/kill/bisect/gore(spray_dir)
	var/mob/living/carbon/victim = host.victim
	// The head end of a body lying on its side points east or west.
	var/head_dir = spray_dir
	if(victim.lying_angle == LYING_ANGLE_EAST)
		head_dir = EAST
	else if(victim.lying_angle == LYING_ANGLE_WEST)
		head_dir = WEST
	// The legs slide off the feet end, or off to the side if the knight stands there.
	var/legs_dir = REVERSE_DIR(head_dir)
	var/turf/legs_to = get_step(victim, legs_dir)
	if(!legs_to || legs_to == get_turf(host.user) || legs_to.is_blocked_turf(FALSE))
		legs_dir = pick(turn(legs_dir, 90), turn(legs_dir, -90))
	for(var/zone in list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		var/obj/item/bodypart/leg = victim.get_bodypart(zone)
		if(leg?.can_dismember())
			leg.hv_vis_tumble = HV_VIS_TUMBLE_SLIDE
			leg.hv_vis_fling_dir = legs_dir
	. = ..()
	if(!QDELETED(victim) && isturf(victim.loc))
		victim.hv_vis_slide_in_tile(head_dir, 40)

/datum/hv_finisher/stop(reason)
	if(running)
		if(user && !QDELETED(user))
			user.hv_vis_release(HV_VIS_TAG_REAR, 2)
			user.hv_vis_release(HV_VIS_TAG_SHAKE, 1)
		if(victim && !QDELETED(victim))
			victim.hv_vis_release(HV_VIS_TAG_LIFT, 2)
			victim.hv_vis_release(HV_VIS_TAG_SHUDDER, 1)
	return ..()

/// Where this mob's feet are, from the middle of its icon, so it grows up from the floor.
/mob/living/proc/hv_vis_feet_y()
	var/list/size = get_icon_dimensions(icon)
	var/height = size?["height"] || ICON_SIZE_Y
	return -height / 2 * current_size

/// Rears up over `victim` for `duration`: grows a little from the feet up and leans back away from
/// them, then comes down at the end, as the pin lands.
/mob/living/proc/hv_vis_rear(atom/victim, duration)
	var/away = HV_VIS_DX(get_dir(victim, src))
	var/feet = hv_vis_feet_y()
	var/matrix/base = matrix(transform)
	// Bigger from the feet up, then leaned back about the feet.
	var/matrix/reared = matrix(base)
	reared.Translate(0, -feet)
	reared.Scale(1.12)
	reared.Turn((away || pick(-1, 1)) * 7)
	reared.Translate(0, feet)
	var/rise_time = duration * 0.6
	hv_vis_play(HV_VIS_TAG_REAR, list(
		list(pixel_w + away * 2, pixel_z + 2, reared, rise_time, SINE_EASING|EASE_OUT),
		list(pixel_w + away * 2, pixel_z + 2, reared, max(duration - rise_time - 1.5, 0), LINEAR_EASING),
		list(pixel_w, pixel_z, base, 1.5, QUAD_EASING|EASE_IN),
	))

/// Lifts this mob `height` pixels off the floor for up to `hold`. hv_vis_release() sets it back down.
/mob/living/proc/hv_vis_lift(height, hold)
	var/matrix/base = matrix(transform)
	hv_vis_play(HV_VIS_TAG_LIFT, list(
		list(pixel_w, pixel_z + height, base, 2, QUAD_EASING|EASE_OUT),
		list(pixel_w, pixel_z + height, base, hold, LINEAR_EASING),
		list(pixel_w, pixel_z, base, 2, QUAD_EASING|EASE_IN),
	))

/**
 * A short hard shudder round where the body is drawn now, up to `shift_x` and `shift_y` pixels each way for
 * `duration`, ending where it began. Not tg's Shake(): its first beat takes pixel_y from pixel_x, which throws
 * a body drawn off the middle of its tile (anyone lying down) up the screen for a frame.
 */
/mob/living/proc/hv_vis_shudder(shift_x, shift_y, duration)
	if(!isturf(loc))
		return
	var/matrix/base = matrix(transform)
	var/list/steps = list()
	for(var/i in 1 to max(round(duration / HV_VIS_SHUDDER_BEAT) - 1, 2))
		steps += list(list(pixel_w + rand(-shift_x, shift_x), pixel_z + rand(-shift_y, shift_y), base, HV_VIS_SHUDDER_BEAT, LINEAR_EASING))
	steps += list(list(pixel_w, pixel_z, base, HV_VIS_SHUDDER_BEAT, LINEAR_EASING))
	hv_vis_play(HV_VIS_TAG_SHUDDER, steps)

/// Shaken hard from side to side, as a dog shakes a rat, across the line from the beast holding it.
/mob/living/proc/hv_vis_dog_shake(beast_dir)
	// Across the line between them: a beast to the east or west shakes it up and down, and the other way round.
	var/across_w = HV_VIS_DX(beast_dir) ? 0 : 1
	var/across_z = across_w ? 0 : 1
	var/matrix/base = matrix(transform)
	var/list/swings = list(18, -16, 14, -12, 9, -6, 3)
	var/list/steps = list()
	for(var/i in 1 to length(swings))
		var/swing = swings[i]
		var/shift = round(swing / 3)
		steps += list(list(pixel_w + across_w * shift, pixel_z + across_z * shift, hv_vis_turned(base, swing), 1, SINE_EASING))
	steps += list(list(pixel_w, pixel_z, base, 1.5, SINE_EASING))
	hv_vis_play(HV_VIS_TAG_SHAKE, steps)

/// The beast's side of the shake: its head goes side to side with the victim.
/mob/living/proc/hv_vis_head_shake()
	var/matrix/base = matrix(transform)
	var/feet = hv_vis_feet_y()
	var/list/swings = list(6, -6, 5, -4, 3, -2)
	var/list/steps = list()
	for(var/swing in swings)
		steps += list(list(pixel_w, pixel_z, hv_vis_turned(base, swing, feet), 1, SINE_EASING))
	steps += list(list(pixel_w, pixel_z, base, 1.5, SINE_EASING))
	hv_vis_play(HV_VIS_TAG_SHAKE, steps)
