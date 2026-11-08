// Hyperviolence visuals: getting hit.
// 1. A flinch along the blow, scaled by its damage: a pistol round twitches a body, a shotgun's
//    pellets together stagger it back past where it stood.
// 2. A head hit whips the body back and tilts it hard.
// 3. A sever, a burst head or a crit holds the flinch at its peak for a few frames (hit-stop), with a
//    pale flash, and whoever landed it holds their pose too (_motion_core.dm).
// 4. Losing a limb lurches the body toward the missing side; with a leg gone, every step dips and
//    leans that way.
// The idea of a flinch on apply_damage() is Shiptest's shake_animation() (code/__HELPERS/matrices.dm,
// AGPL-3.0); this is a rewrite with the direction of the blow and named sequences.

/**
 * The steps of a flinch: out along the blow and tilted away from it, held for `hold` if this is a
 * hit-stop, then back. A big enough blow (a stagger) reels back past the start before it settles.
 * A lying body only jolts. Returns the steps for hv_vis_play(), ending where the body is now.
 */
/mob/living/proc/hv_vis_flinch_steps(damage, attack_dir, headshot = FALSE, hold = 0)
	var/dx = HV_VIS_DX(attack_dir)
	var/dy = HV_VIS_DY(attack_dir)
	var/push = clamp(round(damage / HV_VIS_FLINCH_DAMAGE_PER_PIXEL), 1, HV_VIS_FLINCH_MAX_PUSH)
	var/tilt = clamp(damage / HV_VIS_FLINCH_DAMAGE_PER_DEGREE, 2, HV_VIS_FLINCH_MAX_TILT)
	var/stagger = damage >= HV_VIS_STAGGER_DAMAGE
	if(headshot)
		push = min(push + 2, HV_VIS_FLINCH_MAX_PUSH)
		tilt = clamp(tilt * 1.8, HV_VIS_HEADSHOT_MIN_TILT, HV_VIS_HEADSHOT_MAX_TILT)
	if(body_position == LYING_DOWN || stat == DEAD)
		push = max(1, round(push / 2))
		tilt = 0
		stagger = FALSE
	if(hv_vis_is_huge())
		push = max(1, round(push / 2))
		tilt /= 2
	// A diagonal push covers as much ground as a straight one.
	if(dx && dy)
		push = max(1, round(push * 0.7))
	// Tilted away from the blow; a blow from straight above or below tips it a little either way.
	var/tilt_sign = dx
	if(!dx)
		tilt_sign = pick(-1, 1)
		tilt *= 0.5
	var/base_w = pixel_w
	var/base_z = pixel_z
	var/matrix/base = matrix(transform)
	var/pivot = hv_vis_pivot()
	var/matrix/peak = hv_vis_turned(base, tilt * tilt_sign, pivot)
	var/list/steps = list()
	var/out_time = stagger ? 1 : (headshot ? 0.4 : 0.6)
	steps += list(list(base_w + dx * push, base_z + dy * push, peak, out_time, QUAD_EASING|EASE_OUT))
	if(hold > 0)
		steps += list(list(base_w + dx * push, base_z + dy * push, peak, hold, LINEAR_EASING))
	if(stagger)
		var/matrix/rebound = hv_vis_turned(base, -tilt * tilt_sign * 0.35, pivot)
		steps += list(list(base_w - round(dx * push * 0.35), base_z - round(dy * push * 0.35), rebound, 2.5, SINE_EASING))
		steps += list(list(base_w, base_z, base, 2.5, SINE_EASING))
	else
		steps += list(list(base_w, base_z, base, headshot ? 4 : 3, ELASTIC_EASING))
	return steps

/// Flinches from a blow of `damage` travelling `attack_dir`. See hv_vis_flinch_steps().
/mob/living/proc/hv_vis_flinch(damage, attack_dir, headshot = FALSE, hold = 0)
	if(damage < HV_VIS_FLINCH_MIN || !attack_dir || !isturf(loc))
		return
	hv_vis_play(HV_VIS_TAG_FLINCH, hv_vis_flinch_steps(damage, attack_dir, headshot, hold))

// ---- Crits ask for a hit-stop ----

/mob/living/carbon/hv_try_aimed_crit(obj/item/bodypart/limb, aimed_zone, wounding_type, damage, wound_bonus, exposed_wound_bonus, attack_direction, atom/source, mob/living/attacker, forced_roll)
	. = ..()
	if(.)
		hv_vis_big_hit(attack_direction, attacker)

/mob/living/basic/hv_try_basic_crit(hit_zone, aimed_zone, wounding_type, damage, wound_bonus, attack_direction, atom/source, mob/living/attacker, forced_roll)
	. = ..()
	if(.)
		hv_vis_big_hit(attack_direction, attacker)

// ---- Lost limbs ----

/mob/living/proc/hv_vis_on_limb_lost(obj/item/bodypart/lost_limb, special, dismembered)
	return

/mob/living/carbon/hv_vis_on_limb_lost(obj/item/bodypart/lost_limb, special, dismembered)
	if(special || QDELETED(src))
		return
	var/zone = lost_limb.body_zone
	if(dismembered)
		hv_vis_big_hit(hv_blood_recent_hit_dir())
	if(stat == DEAD || zone == BODY_ZONE_CHEST)
		return
	if(zone != BODY_ZONE_HEAD)
		hv_vis_lurch(zone)
	if((zone == BODY_ZONE_L_LEG || zone == BODY_ZONE_R_LEG) && default_num_legs >= 2)
		AddComponent(/datum/component/hv_limp)

/// Which way, on screen, the side of this body that `zone` is on lies: -1 left, 1 right, 0 neither
/// (seen side-on). Facing south, a body's left arm is drawn on the right of the screen.
/mob/living/carbon/proc/hv_vis_zone_side(zone)
	var/left = (zone == BODY_ZONE_L_ARM || zone == BODY_ZONE_L_LEG)
	switch(dir)
		if(SOUTH)
			return left ? 1 : -1
		if(NORTH)
			return left ? -1 : 1
	return 0

/// The steps of a lurch toward the side a limb was lost from. A body seen side-on pitches forward.
/mob/living/carbon/proc/hv_vis_lurch_steps(zone)
	var/side = hv_vis_zone_side(zone)
	var/dx = side
	var/dy = 0
	if(!side)
		dx = HV_VIS_DX(dir)
		dy = HV_VIS_DY(dir)
	var/tilt = HV_VIS_LURCH_TILT * (side || dx || pick(-1, 1))
	var/standing = body_position == STANDING_UP
	if(!standing)
		tilt = 0
	var/matrix/base = matrix(transform)
	var/matrix/lurched = hv_vis_turned(base, tilt, hv_vis_pivot())
	var/matrix/caught = hv_vis_turned(base, -tilt * 0.3, hv_vis_pivot())
	return list(
		list(pixel_w + dx * HV_VIS_LURCH_PUSH, pixel_z + dy * HV_VIS_LURCH_PUSH, lurched, 1, QUAD_EASING|EASE_OUT),
		list(pixel_w + dx * HV_VIS_LURCH_PUSH, pixel_z + dy * HV_VIS_LURCH_PUSH, lurched, 1.5, LINEAR_EASING),
		list(pixel_w - dx, pixel_z - dy, caught, 2.5, SINE_EASING),
		list(pixel_w, pixel_z, base, 3, SINE_EASING),
	)

/mob/living/carbon/proc/hv_vis_lurch(zone)
	if(!isturf(loc))
		return
	hv_vis_play(HV_VIS_TAG_LURCH, hv_vis_lurch_steps(zone))

/**
 * A body standing on one leg: every step dips and leans toward the missing one. Listens to the
 * body's own moves only while a leg is gone, and goes when both legs are back or the body dies.
 */
/datum/component/hv_limp
	dupe_mode = COMPONENT_DUPE_UNIQUE

/datum/component/hv_limp/Initialize()
	if(!iscarbon(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/hv_limp/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(parent, COMSIG_CARBON_POST_ATTACH_LIMB, PROC_REF(on_limb_attached))
	RegisterSignal(parent, COMSIG_LIVING_DEATH, PROC_REF(on_death))

/datum/component/hv_limp/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOVABLE_MOVED, COMSIG_CARBON_POST_ATTACH_LIMB, COMSIG_LIVING_DEATH))

/// The leg that is missing, or null if both are there.
/datum/component/hv_limp/proc/missing_leg()
	var/mob/living/carbon/body = parent
	var/has_left = !!body.get_bodypart(BODY_ZONE_L_LEG)
	var/has_right = !!body.get_bodypart(BODY_ZONE_R_LEG)
	if(has_left == has_right)
		return null // both there, or both gone and crawling
	return has_left ? BODY_ZONE_R_LEG : BODY_ZONE_L_LEG

/datum/component/hv_limp/proc/on_moved(mob/living/carbon/source, atom/old_loc, movement_dir, forced, list/old_locs)
	SIGNAL_HANDLER
	if(forced || !isturf(source.loc) || source.body_position != STANDING_UP || source.buckled || source.stat != CONSCIOUS)
		return
	var/zone = missing_leg()
	if(!zone)
		if(source.get_bodypart(BODY_ZONE_L_LEG) && source.get_bodypart(BODY_ZONE_R_LEG))
			qdel(src)
		return
	source.hv_vis_play(HV_VIS_TAG_LIMP, source.hv_vis_limp_steps(zone))

/datum/component/hv_limp/proc/on_limb_attached(datum/source)
	SIGNAL_HANDLER
	if(!missing_leg())
		var/mob/living/carbon/body = parent
		if(body.get_bodypart(BODY_ZONE_L_LEG) && body.get_bodypart(BODY_ZONE_R_LEG))
			qdel(src)

/datum/component/hv_limp/proc/on_death(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// One limping step: down and over toward the missing leg, and back up.
/mob/living/carbon/proc/hv_vis_limp_steps(zone)
	var/side = hv_vis_zone_side(zone)
	var/matrix/base = matrix(transform)
	var/matrix/leaned = hv_vis_turned(base, HV_VIS_LIMP_TILT * (side || pick(-1, 1)), HV_VIS_FEET_Y * current_size)
	return list(
		list(pixel_w + side, pixel_z - HV_VIS_LIMP_DIP, leaned, 1.5, SINE_EASING),
		list(pixel_w, pixel_z, base, 1.5, SINE_EASING),
	)
