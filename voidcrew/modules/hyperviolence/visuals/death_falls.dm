// Hyperviolence visuals: dying.
// 5. A body falls away from the blow that killed it: tg's turn onto its side is pointed that way, and
//    it slides along the blow within its tile. A blow of HV_VIS_FULL_SLIDE_DAMAGE or more (a
//    shotgun at close range) slides it a whole tile, a real step onto open floor, never into space,
//    lava, a chasm, a wall or a standing person.
// 6. Deaths read differently: a head shot drops straight down and lies limp, a body that bled out
//    kneels and sways before it collapses, a burned body draws up and curls.
// 7. Most bodies twitch a few times in the seconds after death.
// Every pose is held by the animation itself and let go by /datum/component/hv_motion_hold the moment
// the body is moved, stands up or is revived.

/// Falls point away from the hit that dropped the body, when one just landed from the side.
/mob/living/carbon/set_lying_angle(new_lying)
	var/falling = !lying_angle && new_lying
	if(falling && hv_vis_hit_time == world.time && (new_lying == LYING_ANGLE_EAST || new_lying == LYING_ANGLE_WEST))
		var/dx = HV_VIS_DX(hv_vis_hit_dir)
		if(dx)
			new_lying = dx > 0 ? LYING_ANGLE_EAST : LYING_ANGLE_WEST
	// tg can lay a dying body down twice in one tick, the second time on a random side: keep the side
	// this tick's hit chose.
	else if(lying_angle && new_lying && hv_vis_fell_time == world.time && hv_vis_hit_time == world.time && HV_VIS_DX(hv_vis_hit_dir))
		new_lying = lying_angle
	. = ..()
	if(falling && lying_angle)
		hv_vis_fell_time = world.time
		hv_vis_after_fall()

/// A body that just went down. One collapsing into crit from blood loss kneels and sways first.
/// Deaths are shown by hv_vis_on_death(), a moment later in the same tick.
/mob/living/carbon/proc/hv_vis_after_fall()
	if(stat == CONSCIOUS || stat == DEAD || hv_vis_hit_time == world.time)
		return
	if(blood_volume >= BLOOD_VOLUME_BAD || !can_bleed() || HAS_TRAIT(src, TRAIT_MOVE_FLOATING) || !isturf(loc))
		return
	hv_vis_play_over(hv_vis_kneel_collapse_steps())

/mob/living/proc/hv_vis_on_death(gibbed)
	hv_vis_died_time = world.time

/mob/living/carbon/hv_vis_on_death(gibbed)
	. = ..()
	hv_vis_stop(list(HV_VIS_TAG_TREMBLE, HV_VIS_TAG_LEAN, HV_VIS_TAG_LIMP))
	if(gibbed || QDELETED(src) || !isturf(loc))
		return
	var/fell = hv_vis_fell_time == world.time
	var/hit_dir = hv_vis_hit_time == world.time ? hv_vis_hit_dir : 0
	var/big = hv_vis_big_hit_time == world.time
	if(big)
		hv_vis_hitstop_extras(hit_dir)
	switch(hv_vis_death_kind())
		if(HV_VIS_DEATH_EXECUTED)
			hv_vis_death_slump(hit_dir, fell)
		if(HV_VIS_DEATH_HEADSHOT)
			hv_vis_death_drop(hit_dir, fell, big)
		if(HV_VIS_DEATH_BURNED)
			hv_vis_death_curl(fell)
		if(HV_VIS_DEATH_BLED_OUT)
			hv_vis_death_bleed_out(fell)
		if(HV_VIS_DEATH_HIT)
			hv_vis_death_hit(hit_dir, fell, big)
		else
			hv_vis_twitches(2, fell ? 5 : 3)

/// How this body died, from what happened to it this tick (HV_VIS_DEATH_*).
/mob/living/carbon/proc/hv_vis_death_kind()
	var/recent = hv_vis_hit_time == world.time
	if(hv_vis_execution_time == world.time)
		return HV_VIS_DEATH_EXECUTED
	if(recent && hv_vis_hit_type != STAMINA && (hv_vis_hit_zone == BODY_ZONE_HEAD || !get_bodypart(BODY_ZONE_HEAD)))
		return HV_VIS_DEATH_HEADSHOT
	if(hv_vis_big_hit_time == world.time && !get_bodypart(BODY_ZONE_HEAD))
		return HV_VIS_DEATH_HEADSHOT
	if((recent && hv_vis_hit_type == BURN) || on_fire || HAS_TRAIT(src, TRAIT_HUSK))
		return HV_VIS_DEATH_BURNED
	if(recent && hv_vis_hit_dir)
		return HV_VIS_DEATH_HIT
	if(blood_volume < BLOOD_VOLUME_BAD && can_bleed())
		return HV_VIS_DEATH_BLED_OUT
	return HV_VIS_DEATH_QUIET

// ---- Upright for a moment, then down ----

/// The body's transform and pixel_y as it stood a moment ago, before tg turned it onto its side.
/// Returns list(pixel_y, transform).
/mob/living/carbon/proc/hv_vis_upright()
	var/matrix/upright = matrix(transform)
	var/angle = round(arctan(upright.a, upright.b))
	if(angle)
		upright.Turn(-angle)
	return list(pixel_y - has_offset(LYING_DOWN_TRAIT, PIXEL_Y_OFFSET), upright)

/// Holds the body upright for `hold`, then lets it fall over `fall_time`. Steps for hv_vis_play_over().
/mob/living/carbon/proc/hv_vis_hold_then_fall_steps(hold, fall_time, fall_easing = QUAD_EASING|EASE_IN)
	var/list/upright = hv_vis_upright()
	return list(
		list(upright[1], upright[2], 0, LINEAR_EASING),
		list(upright[1], upright[2], hold, LINEAR_EASING),
		list(pixel_y, matrix(transform), fall_time, fall_easing),
	)

/// Sinks to the knees, sways twice and collapses: a body out of blood. Steps for hv_vis_play_over().
/mob/living/carbon/proc/hv_vis_kneel_collapse_steps()
	var/list/upright = hv_vis_upright()
	var/matrix/standing = upright[2]
	// Shorter from the feet up: down on the knees.
	var/matrix/kneeling = hv_vis_local(standing, 1, 0.86, 0, 0, HV_VIS_FEET_Y * 0.14)
	return list(
		list(upright[1], standing, 0, LINEAR_EASING),
		list(upright[1], kneeling, 3, SINE_EASING),
		list(upright[1], hv_vis_turned(kneeling, 5, HV_VIS_FEET_Y), 4, SINE_EASING),
		list(upright[1], hv_vis_turned(kneeling, -4, HV_VIS_FEET_Y), 5, SINE_EASING),
		list(upright[1], hv_vis_turned(kneeling, 2, HV_VIS_FEET_Y), 3, SINE_EASING),
		list(pixel_y, matrix(transform), 3, QUAD_EASING|EASE_IN),
	)

/// Whether the body may be held up over tg's fall: not while floating, where it would stop the bob.
/mob/living/carbon/proc/hv_vis_can_hold_fall()
	return !HAS_TRAIT(src, TRAIT_MOVE_FLOATING)

// ---- The kinds of death ----

/// Killed by a blow from the side: slides along it, a whole tile for a heavy blow, then twitches.
/mob/living/carbon/proc/hv_vis_death_hit(hit_dir, fell, big)
	if(big && fell && hv_vis_can_hold_fall())
		hv_vis_play_over(hv_vis_hold_then_fall_steps(HV_VIS_HITSTOP_TIME, 2))
	if(hv_vis_hit_damage >= HV_VIS_FULL_SLIDE_DAMAGE && hv_vis_can_slide_tile(hit_dir))
		// Next tick: the blow that killed it may still be resolving (a shotgun's other pellets).
		addtimer(CALLBACK(src, PROC_REF(hv_vis_slide_tile), hit_dir), cyberware_dilated_time(src, 1), TIMER_DELETE_ME) // waits out a Sandevistan freeze
		return
	hv_vis_slide_in_tile(hit_dir, hv_vis_hit_damage, big ? HV_VIS_HITSTOP_TIME : 0)
	hv_vis_twitches(rand(3, 5), big ? 6 : 4)

/// The steps of a slide along `slide_dir` inside the tile, held as the corpse's pose.
/mob/living/carbon/proc/hv_vis_slide_steps(slide_dir, damage, delay = 0)
	var/dx = HV_VIS_DX(slide_dir)
	var/dy = HV_VIS_DY(slide_dir)
	var/distance = clamp(round(damage / 4), 2, HV_VIS_MAX_SLIDE)
	if(dx && dy)
		distance = max(2, round(distance * 0.7))
	var/matrix/base = matrix(transform)
	return list(
		list(pixel_w, pixel_z, base, delay, LINEAR_EASING),
		list(pixel_w + dx * distance, pixel_z + dy * distance, base, 3, CUBIC_EASING|EASE_OUT),
		list(pixel_w + dx * distance, pixel_z + dy * distance, base, HV_VIS_POSE_HOLD, LINEAR_EASING),
		list(pixel_w, pixel_z, base, 10, SINE_EASING),
	)

/mob/living/carbon/proc/hv_vis_slide_in_tile(slide_dir, damage, delay = 0)
	if(!slide_dir)
		return
	hv_vis_play(HV_VIS_TAG_SLIDE, hv_vis_slide_steps(slide_dir, damage, delay))
	hv_vis_hold(list(HV_VIS_TAG_SLIDE), HV_VIS_END_MOVE|HV_VIS_END_STAND|HV_VIS_END_REVIVE, HV_VIS_POSE_HOLD + 3 SECONDS)

/// Whether a corpse can be slid one tile along `slide_dir`: onto open floor with gravity, nothing
/// solid or standing there, not into space, lava or a chasm, and nobody holding or carrying it.
/mob/living/carbon/proc/hv_vis_can_slide_tile(slide_dir)
	if(!slide_dir || buckled || pulledby || throwing || anchored || !isturf(loc))
		return FALSE
	if(HAS_TRAIT(src, TRAIT_MOVE_FLOATING) || has_status_effect(/datum/status_effect/hv_finisher_hold))
		return FALSE
	var/turf/here = loc
	if(here.has_gravity() <= 0)
		return FALSE
	var/turf/next = get_step(here, slide_dir)
	if(!next || next.z != here.z || !isopenturf(next) || isgroundlessturf(next) || islava(next) || ischasm(next))
		return FALSE
	if(next.has_gravity() <= 0 || next.is_blocked_turf(FALSE, src) || !here.Adjacent(next))
		return FALSE
	// A lying body may move into a standing person's tile in tg; a thrown corpse never lands on one.
	for(var/mob/living/standing in next)
		if(standing.body_position == STANDING_UP)
			return FALSE
	return TRUE

/// Slides the corpse a whole tile along the killing blow, a real move with a slow glide.
/mob/living/carbon/proc/hv_vis_slide_tile(slide_dir)
	if(QDELETED(src) || stat != DEAD)
		return
	if(hv_vis_can_slide_tile(slide_dir) && Move(get_step(loc, slide_dir), slide_dir, DELAY_TO_GLIDE_SIZE(cyberware_dilated_time(src, HV_VIS_SLIDE_TIME))))
		// Thrown back as it falls: a little lift over the slide.
		var/matrix/base = matrix(transform)
		hv_vis_play(HV_VIS_TAG_FALL, list(
			list(pixel_w, pixel_z, base, 0, LINEAR_EASING),
			list(pixel_w, pixel_z + HV_VIS_LAUNCH_LIFT, base, HV_VIS_SLIDE_TIME * 0.4, QUAD_EASING|EASE_OUT),
			list(pixel_w, pixel_z, base, HV_VIS_SLIDE_TIME * 0.6, QUAD_EASING|EASE_IN),
		))
	hv_vis_twitches(rand(3, 5), HV_VIS_SLIDE_TIME + 2)

/// Killed by a head shot, or the head came off: straight down, no fall, lying limp. A burst gets its
/// hit-stop first.
/mob/living/carbon/proc/hv_vis_death_drop(hit_dir, fell, big)
	var/whip = 0
	if(fell && hv_vis_can_hold_fall())
		if(big)
			hv_vis_play_over(hv_vis_hold_then_fall_steps(HV_VIS_HITSTOP_TIME, 0.5))
		else
			// The head whips back from the shot, then the body drops.
			whip = HV_VIS_KILL_WHIP_TIME
			hv_vis_play_over(hv_vis_whip_then_fall_steps(hit_dir))
	var/dx = HV_VIS_DX(hit_dir)
	var/dy = HV_VIS_DY(hit_dir)
	var/matrix/base = matrix(transform)
	// Lands with a small bounce and stays where it fell.
	hv_vis_play(HV_VIS_TAG_FALL, list(
		list(pixel_w, pixel_z, base, big ? HV_VIS_HITSTOP_TIME + 0.5 : whip + 0.5, LINEAR_EASING),
		list(pixel_w + dx * 2, pixel_z + dy * 2 + 2, base, 0.5, QUAD_EASING|EASE_OUT),
		list(pixel_w, pixel_z, base, 1.5, BOUNCE_EASING),
	))

/// Upright, the head whipped back along the shot, then down. Steps for hv_vis_play_over().
/mob/living/carbon/proc/hv_vis_whip_then_fall_steps(hit_dir)
	var/list/upright = hv_vis_upright()
	var/matrix/standing = upright[2]
	// Back along the shot. A shot from straight ahead or behind whips it the way the body is about to
	// fall, so it never rocks one way and drops the other.
	var/back = HV_VIS_DX(hit_dir) || (lying_angle == LYING_ANGLE_WEST ? -1 : 1)
	var/matrix/whipped = hv_vis_turned(standing, back * 14, HV_VIS_FEET_Y)
	return list(
		list(upright[1], standing, 0, LINEAR_EASING),
		list(upright[1], whipped, HV_VIS_KILL_WHIP_TIME * 0.5, QUAD_EASING|EASE_OUT),
		list(upright[1], whipped, HV_VIS_KILL_WHIP_TIME * 0.5, LINEAR_EASING),
		list(pixel_y, matrix(transform), 1, QUAD_EASING|EASE_IN),
	)

/// Burned to death: the body draws up and curls, and keeps that shape.
/mob/living/carbon/proc/hv_vis_death_curl(fell)
	hv_vis_play(HV_VIS_TAG_POSE, hv_vis_curl_steps(fell ? 3 : 0))
	hv_vis_hold(list(HV_VIS_TAG_POSE), HV_VIS_END_MOVE|HV_VIS_END_STAND|HV_VIS_END_REVIVE, HV_VIS_POSE_HOLD + 3 SECONDS)
	hv_vis_twitches(2, 10)

/// The steps of a curl: shorter along the body's own length, drawn in a little, held.
/mob/living/carbon/proc/hv_vis_curl_steps(delay = 0)
	var/matrix/base = matrix(transform)
	var/matrix/curled = hv_vis_local(base, 0.92, 0.8, -8)
	return list(
		list(pixel_w, pixel_z, base, delay, LINEAR_EASING),
		list(pixel_w, pixel_z, curled, 8, SINE_EASING|EASE_OUT),
		list(pixel_w, pixel_z, curled, HV_VIS_POSE_HOLD, LINEAR_EASING),
		list(pixel_w, pixel_z, base, 10, SINE_EASING),
	)

/// Bled out: on its feet it kneels and sways before it goes down; already down it sags one last time.
/mob/living/carbon/proc/hv_vis_death_bleed_out(fell)
	if(fell && hv_vis_can_hold_fall())
		hv_vis_play_over(hv_vis_kneel_collapse_steps())
		hv_vis_twitches(1, 18)
		return
	var/matrix/base = matrix(transform)
	hv_vis_play(HV_VIS_TAG_FALL, list(
		list(pixel_w, pixel_z - 1, hv_vis_local(base, 1, 0.96), 8, SINE_EASING),
		list(pixel_w, pixel_z, base, 12, SINE_EASING),
	))
	hv_vis_twitches(1, 12)

/// Executed: the body holds where it was for a beat, then slumps forward along the shot.
/mob/living/carbon/proc/hv_vis_death_slump(shot_dir, fell)
	var/beat = HV_VIS_HITSTOP_TIME + HV_VIS_SLUMP_BEAT
	if(fell && hv_vis_can_hold_fall())
		hv_vis_play_over(hv_vis_hold_then_fall_steps(beat, 3))
		beat += 3
	if(!shot_dir)
		return
	var/dx = HV_VIS_DX(shot_dir)
	var/dy = HV_VIS_DY(shot_dir)
	var/matrix/base = matrix(transform)
	var/matrix/slumped = hv_vis_local(base, 1, 0.94)
	hv_vis_play(HV_VIS_TAG_SLIDE, list(
		list(pixel_w, pixel_z, base, beat, LINEAR_EASING),
		list(pixel_w + dx * 4, pixel_z + dy * 4, slumped, 3, QUAD_EASING|EASE_IN),
		list(pixel_w + dx * 4, pixel_z + dy * 4, slumped, HV_VIS_POSE_HOLD, LINEAR_EASING),
		list(pixel_w, pixel_z, base, 10, SINE_EASING),
	))
	hv_vis_hold(list(HV_VIS_TAG_SLIDE), HV_VIS_END_MOVE|HV_VIS_END_STAND|HV_VIS_END_REVIVE, HV_VIS_POSE_HOLD + 3 SECONDS)

// ---- Twitches ----

/// `count` twitches after `start_delay`, each smaller than the last, a second or so apart.
/mob/living/carbon/proc/hv_vis_twitch_steps(count, start_delay)
	var/matrix/base = matrix(transform)
	var/list/steps = list(list(pixel_w, pixel_z, base, start_delay, LINEAR_EASING))
	for(var/i in 1 to count)
		var/strength = 1 - (i - 1) / (count + 1)
		var/jerk = pick(-1, 1) * max(1, round(2 * strength))
		var/matrix/twitched = hv_vis_turned(base, pick(-1, 1) * 3 * strength)
		steps += list(list(pixel_w + jerk, pixel_z, twitched, 0.5, LINEAR_EASING))
		steps += list(list(pixel_w, pixel_z, base, 1, QUAD_EASING|EASE_OUT))
		steps += list(list(pixel_w, pixel_z, base, rand(5, 12), LINEAR_EASING))
	return steps

/mob/living/carbon/proc/hv_vis_twitches(count, start_delay = 4)
	if(count <= 0 || !isturf(loc))
		return
	var/list/steps = hv_vis_twitch_steps(count, start_delay)
	var/total = 0
	for(var/list/step as anything in steps)
		total += step[4]
	hv_vis_play(HV_VIS_TAG_TWITCH, steps)
	hv_vis_hold(list(HV_VIS_TAG_TWITCH), HV_VIS_END_MOVE|HV_VIS_END_STAND|HV_VIS_END_REVIVE, total + 1)
