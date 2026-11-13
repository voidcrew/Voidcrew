// Hyperviolence visuals: knife executions (overlays_exec/knife_executions.dm).
//
// Beats over the execution's own wind-up and kill (purely visual; every sequence ends where it began):
// 1. Wind-up grab (0 - 0.3 s): the attacker steps in toward the victim, a side-facing victim's head
//    tilts back 2 deg about their feet, and for S/E/W facings a scaled (~10 px) blade prop and small
//    skin-tinted hand prop move from the attacker's real knife hand to the throat, grip under the hand
//    every frame. When a standing victim faces NORTH the cut is hidden behind their head, so no blade
//    or hand prop is drawn.
// 2. Hold (0.3 - 1.5 s): attacker, victim, blade and hand hold steady together so the cutting edge
//    stays locked on the drawn throat every frame.
// 3. The cut (1.5 - 1.75 s, held 0.1 s): the blade draws across the throat so the edge crosses the
//    throat and the sharp tip finishes on the front of the throat with the hand on the grip; a short
//    jet spurts off the front of the neck (S/E/W) and a forward floor spray runs along the victim's
//    facing once the wound lands.
// 4. Release: the blade and knife-hand props vanish together, the attacker steps back to exact zero
//    offset, and a survivor still standing hunches 9 deg forward about their feet (0.15 s in, 0.4 s
//    hold, 0.3 s out) while their own hand clutches their throat; if the blow dropped them, tg's own
//    fall and death_falls.dm take over. A broken wind-up releases everything in 0.2 s with no blood.

/mob/living
	/// Suppresses tg's centre-body lunge and floating item flick during the execution's own head stab.
	var/hv_vis_knife_executing = FALSE
	/// Wind-up start time for the active knife execution pose on this victim.
	var/hv_vis_knife_t0 = -1
	/// Time the wind-up head pull reaches its full back-tilt.
	var/hv_vis_knife_t1 = -1
	/// Time the throat cut and its short hold finish.
	var/hv_vis_knife_t2 = -1
	/// Time a standing survivor's forward hunch reaches its peak.
	var/hv_vis_knife_t3 = -1
	/// Time a standing survivor's forward hunch returns to zero.
	var/hv_vis_knife_t4 = -1
	/// Clockwise degrees this victim is tilted back during the wind-up and cut.
	var/hv_vis_knife_tilt = 0
	/// Clockwise degrees this victim hunches forward after release when still standing.
	var/hv_vis_knife_hunch = 0
	/// Peak x/y pixel lurch of a standing survivor's hunch after release.
	var/hv_vis_knife_lurch_x = 0
	var/hv_vis_knife_lurch_y = 0
	/// Until this world.time, a victim felled by the cut is still drawn upright over tg's lying turn.
	var/hv_vis_knife_upright_until = -1
	/// Copy of the standing base transform while held upright through the cut.
	var/matrix/hv_vis_knife_pose_base

/obj/item/knife
	/// Weakref to the active blade prop (/obj/effect/temp_visual/hv_knife_exec_blade) during a wind-up.
	var/datum/weakref/hv_vis_blade_ref
	/// Weakref to the attacker's knife-hand prop (/obj/effect/temp_visual/hv_knife_exec_arm) during a wind-up.
	var/datum/weakref/hv_vis_knife_arm_ref
	/// Whether the current execution completed its cut so hv_start_knife_execution skips broken cleanup.
	var/hv_vis_cut_landed = FALSE

/obj/item/knife/Destroy()
	hv_vis_clear_exec_props()
	return ..()

/mob/living/do_attack_animation(atom/A, visual_effect_icon, obj/item/used_item, no_effect)
	if(hv_vis_knife_executing)
		return
	return ..()

/mob/living/carbon/hv_vis_on_death(gibbed)
	if(hv_vis_knife_t0 >= 0)
		hv_vis_knife_clear_pose()
		hv_vis_stop(list(HV_VIS_TAG_KNIFE_VICTIM))
	return ..()

/// Pixel offset list(x, y) of `victim`'s drawn throat from their icon centre at `world.time`'s pose.
/proc/hv_knife_exec_throat_point(mob/living/victim)
	if(!isliving(victim))
		return list(0, 0)
	var/base_x = (victim.dir & EAST) ? 3.5 : ((victim.dir & WEST) ? -3.5 : -0.5)
	var/base_y = 5.5
	var/angle = victim.hv_vis_knife_pose_angle()
	var/list/lurch = victim.hv_vis_knife_pose_lurch()
	var/held_upright = victim.hv_vis_knife_pose_base && world.time < victim.hv_vis_knife_upright_until
	var/matrix/base = held_upright ? matrix(victim.hv_vis_knife_pose_base) : matrix(victim.transform)
	var/pivot = held_upright ? (HV_VIS_FEET_Y * victim.current_size) : victim.hv_vis_pivot()
	var/matrix/pose = hv_vis_turned(base, angle, pivot)
	return list(
		round(pose.a * base_x + pose.b * base_y + pose.c + lurch[1], 0.01),
		round(pose.d * base_x + pose.e * base_y + pose.f + lurch[2], 0.01),
	)

/// Current clockwise lean angle (degrees) our knife execution animation adds to this mob at world.time.
/mob/living/proc/hv_vis_knife_pose_angle()
	if(hv_vis_knife_t0 < 0 || world.time < hv_vis_knife_t0)
		return 0
	if(world.time < hv_vis_knife_t1)
		var/span = max(hv_vis_knife_t1 - hv_vis_knife_t0, 1)
		var/frac = (world.time - hv_vis_knife_t0) / span
		return hv_vis_knife_tilt * (1 - (1 - frac) * (1 - frac))
	if(world.time <= hv_vis_knife_t2)
		return hv_vis_knife_tilt
	if(hv_vis_knife_hunch && hv_vis_knife_t3 > hv_vis_knife_t2 && world.time < hv_vis_knife_t4)
		if(world.time <= hv_vis_knife_t3)
			var/in_span = max(hv_vis_knife_t3 - hv_vis_knife_t2, 1)
			return LERP(hv_vis_knife_tilt, hv_vis_knife_hunch, (world.time - hv_vis_knife_t2) / in_span)
		var/hold_end = min(hv_vis_knife_t3 + HV_VIS_KNIFE_HUNCH_HOLD, hv_vis_knife_t4)
		if(world.time <= hold_end)
			return hv_vis_knife_hunch
		var/out_span = max(hv_vis_knife_t4 - hold_end, 1)
		return hv_vis_knife_hunch * (1 - (world.time - hold_end) / out_span)
	return 0

/// Current list(dx, dy) lurch offset added by a standing survivor's forward hunch at world.time.
/mob/living/proc/hv_vis_knife_pose_lurch()
	if(hv_vis_knife_t3 <= hv_vis_knife_t2 || world.time <= hv_vis_knife_t2 || world.time >= hv_vis_knife_t4)
		return list(0, 0)
	var/weight = 1
	if(world.time < hv_vis_knife_t3)
		weight = (world.time - hv_vis_knife_t2) / max(hv_vis_knife_t3 - hv_vis_knife_t2, 1)
	else
		var/hold_end = min(hv_vis_knife_t3 + HV_VIS_KNIFE_HUNCH_HOLD, hv_vis_knife_t4)
		if(world.time > hold_end)
			weight = 1 - (world.time - hold_end) / max(hv_vis_knife_t4 - hold_end, 1)
	return list(hv_vis_knife_lurch_x * weight, hv_vis_knife_lurch_y * weight)

/// Clears tracked knife execution pose timestamps on this mob.
/mob/living/proc/hv_vis_knife_clear_pose()
	hv_vis_knife_t0 = -1
	hv_vis_knife_t1 = -1
	hv_vis_knife_t2 = -1
	hv_vis_knife_t3 = -1
	hv_vis_knife_t4 = -1
	hv_vis_knife_tilt = 0
	hv_vis_knife_hunch = 0
	hv_vis_knife_lurch_x = 0
	hv_vis_knife_lurch_y = 0
	hv_vis_knife_upright_until = -1
	hv_vis_knife_pose_base = null

/obj/item/knife/hv_start_knife_execution(mob/living/user, mob/living/carbon/victim, list/modifiers, list/attack_modifiers)
	var/staging = !DOING_INTERACTION(user, HV_KNIFE_EXECUTION_DOAFTER) && hv_knife_execution_possible(user, victim) && isturf(user.loc) && isturf(victim.loc)
	hv_vis_cut_landed = FALSE
	if(staging)
		hv_vis_begin_knife_windup(user, victim)
	. = ..()
	if(!staging)
		return
	if(!hv_vis_cut_landed)
		hv_vis_abort_knife_windup(user, victim)

/obj/item/knife/hv_finish_knife_execution(mob/living/user, mob/living/carbon/victim, list/modifiers, list/attack_modifiers)
	if(!isturf(user?.loc) || !isturf(victim?.loc))
		return ..()
	var/was_standing = victim.body_position == STANDING_UP
	var/pre_pixel_y = victim.pixel_y
	var/matrix/pre_base = matrix(victim.transform)
	var/sealed_before = !isnull(victim.is_mouth_covered(ITEM_SLOT_HEAD))
	var/obj/item/bodypart/head/head_before = victim.get_bodypart(BODY_ZONE_HEAD)
	var/cover_before = head_before ? hv_crit_cover_rating(victim, head_before, MELEE, armour_penetration) : 100

	// Suppress hv_blood_on_damaged's 3-fan hit spray during the stab so we fire our own forward throat spray.
	var/prev_spray_until = victim.hv_blood_spray_until
	var/prev_spray_strength = victim.hv_blood_spray_strength
	victim.hv_blood_spray_until = world.time + HV_BLOOD_SPRAY_WINDOW
	victim.hv_blood_spray_strength = HV_BLOOD_MAX_RANGE

	victim.hv_vis_execution_time = world.time
	user.hv_vis_knife_executing = TRUE
	. = ..()
	if(!QDELETED(user))
		user.hv_vis_knife_executing = FALSE
	if(!QDELETED(victim))
		victim.hv_blood_spray_until = prev_spray_until
		victim.hv_blood_spray_strength = prev_spray_strength
	if(!.)
		return

	hv_vis_cut_landed = TRUE
	hv_vis_play_knife_cut_and_release(user, victim, was_standing, pre_pixel_y, pre_base, sealed_before, cover_before)

// ---- Wind-up, cut and release choreography ----

/// Starts Beats 1 and 2: attacker step-in, steady victim head-pull, and (for S/E/W) scaled blade + hand props.
/obj/item/knife/proc/hv_vis_begin_knife_windup(mob/living/user, mob/living/carbon/victim)
	hv_vis_clear_exec_props()
	var/turf/victim_turf = get_turf(victim)
	if(!victim_turf)
		return

	var/cut_hold_total = HV_KNIFE_EXECUTION_WINDUP + HV_VIS_KNIFE_CUT_TIME + HV_VIS_KNIFE_CUT_HOLD
	var/toward = get_dir(user, victim) || user.dir || SOUTH
	var/step_px = (HV_VIS_DX(toward) && HV_VIS_DY(toward)) ? round(HV_VIS_KNIFE_STEP_IN * 0.78, 1) : HV_VIS_KNIFE_STEP_IN
	var/step_dx = HV_VIS_DX(toward) * step_px
	var/step_dy = HV_VIS_DY(toward) * step_px

	// Stop any prior sequence on these tags so nothing overlaps when the wind-up starts.
	user.hv_vis_stop(list(HV_VIS_TAG_KNIFE_STEP))
	victim.hv_vis_stop(list(HV_VIS_TAG_KNIFE_VICTIM, HV_VIS_TAG_TREMBLE))

	// Attacker steps in behind the victim and stays pressed in until the cut releases.
	var/matrix/attacker_base = matrix(user.transform)
	var/matrix/attacker_lean = hv_vis_turned(attacker_base, HV_VIS_DX(toward) * 4, user.hv_vis_pivot())
	user.hv_vis_play(HV_VIS_TAG_KNIFE_STEP, list(
		list(user.pixel_w + step_dx, user.pixel_z + step_dy, attacker_lean, HV_VIS_KNIFE_GRAB_TIME, QUAD_EASING|EASE_OUT),
		list(user.pixel_w + step_dx, user.pixel_z + step_dy, attacker_lean, cut_hold_total - HV_VIS_KNIFE_GRAB_TIME + 0.5 SECONDS, LINEAR_EASING),
		list(user.pixel_w, user.pixel_z, attacker_base, HV_VIS_KNIFE_RELEASE_TIME, SINE_EASING),
	))

	// Victim is pulled back about their feet and held steady so the blade edge stays on the throat every frame.
	var/tilt = victim.hv_vis_knife_windup_tilt(user)
	var/matrix/victim_base = matrix(victim.transform)
	var/matrix/victim_tilted = hv_vis_turned(victim_base, tilt, victim.hv_vis_pivot())
	victim.hv_vis_knife_t0 = world.time
	victim.hv_vis_knife_t1 = world.time + HV_VIS_KNIFE_GRAB_TIME
	victim.hv_vis_knife_t2 = world.time + cut_hold_total
	victim.hv_vis_knife_t3 = -1
	victim.hv_vis_knife_t4 = -1
	victim.hv_vis_knife_tilt = tilt
	victim.hv_vis_knife_hunch = 0
	victim.hv_vis_knife_lurch_x = 0
	victim.hv_vis_knife_lurch_y = 0
	victim.hv_vis_knife_upright_until = -1
	victim.hv_vis_knife_pose_base = victim.body_position == STANDING_UP ? matrix(victim_base) : null

	victim.hv_vis_play(HV_VIS_TAG_KNIFE_VICTIM, list(
		list(victim.pixel_w, victim.pixel_z, victim_tilted, HV_VIS_KNIFE_GRAB_TIME, QUAD_EASING|EASE_OUT),
		list(victim.pixel_w, victim.pixel_z, victim_tilted, cut_hold_total - HV_VIS_KNIFE_GRAB_TIME + 0.5 SECONDS, LINEAR_EASING),
		list(victim.pixel_w, victim.pixel_z, victim_base, HV_VIS_KNIFE_RELEASE_TIME, SINE_EASING),
	))

	// Standing victim facing NORTH: the throat and reach are completely behind the victim's head and attacker's body.
	if((victim.dir & NORTH) && victim.body_position == STANDING_UP)
		return

	// Compute the throat target at full wind-up tilt (t1..t2) so the blade edge rests right on the tilted throat.
	var/list/tilted_throat = victim.hv_vis_throat_for_angle(tilt)
	var/throat_w = victim.pixel_w + tilted_throat[1]
	var/throat_z = victim.pixel_z + tilted_throat[2]

	var/knife_zone = user.get_hand_zone_of_item(src) || BODY_ZONE_R_ARM
	var/list/knife_hand_start = hv_vis_hand_in_victim_frame(user, victim, knife_zone, 0, 0)
	var/hold_deg = hv_vis_knife_hold_angle(victim, knife_zone)
	var/hold_along = hv_vis_knife_hold_contact(victim)

	var/obj/effect/temp_visual/hv_knife_exec_blade/blade = new(
		victim_turf,
		src,
		victim.pixel_x,
		victim.pixel_y,
		0,
		0,
		hold_deg,
		HV_VIS_KNIFE_BLADE_LAYER,
		cut_hold_total + 1 SECONDS,
	)
	var/list/grip_off = blade.hv_point_offset(hold_deg, HV_VIS_KNIFE_SPRITE_GRIP)
	var/list/hold_off = blade.hv_point_offset(hold_deg, hold_along)

	// Start with the scaled knife's grip at the attacker's real knife hand, then bring hold_along onto the throat.
	var/start_blade_w = knife_hand_start[1] - grip_off[1]
	var/start_blade_z = knife_hand_start[2] - grip_off[2]
	var/cut_start_w = throat_w - hold_off[1]
	var/cut_start_z = throat_z - hold_off[2]
	var/fist_start_w = start_blade_w + grip_off[1]
	var/fist_start_z = start_blade_z + grip_off[2]
	var/fist_in_w = cut_start_w + grip_off[1]
	var/fist_in_z = cut_start_z + grip_off[2]

	blade.hv_place_at(start_blade_w, start_blade_z, hold_deg)
	blade.hv_animate_to(cut_start_w, cut_start_z, hold_deg, HV_VIS_KNIFE_GRAB_TIME, QUAD_EASING|EASE_OUT)
	hv_vis_blade_ref = WEAKREF(blade)

	// Small skin-tinted hand prop centred on the fist, locked onto the scaled knife's grip every frame.
	var/obj/effect/temp_visual/hv_knife_exec_arm/knife_arm = new(
		victim_turf,
		user,
		knife_zone,
		victim.pixel_x,
		victim.pixel_y,
		fist_start_w,
		fist_start_z,
		HV_VIS_KNIFE_HAND_LAYER,
		cut_hold_total + 1 SECONDS,
	)
	knife_arm.hv_animate_to(fist_in_w, fist_in_z, HV_VIS_KNIFE_GRAB_TIME, QUAD_EASING|EASE_OUT)
	hv_vis_knife_arm_ref = WEAKREF(knife_arm)

/// Runs Beats 3 and 4 once the wind-up succeeded and the real stab + slash wound landed.
/obj/item/knife/proc/hv_vis_play_knife_cut_and_release(mob/living/user, mob/living/carbon/victim, was_standing, pre_pixel_y, matrix/pre_base, sealed_before, cover_before)
	var/cut_total = HV_VIS_KNIFE_CUT_TIME + HV_VIS_KNIFE_CUT_HOLD
	if(!QDELETED(user))
		user.hv_vis_stop(list(HV_VIS_TAG_HITSTOP))

	if(QDELETED(victim) || !isturf(victim.loc))
		hv_vis_clear_exec_props()
		if(!QDELETED(user))
			user.hv_vis_release(HV_VIS_TAG_KNIFE_STEP, HV_VIS_KNIFE_ABORT_TIME)
		return

	// Stop the wind-up sequence and any hit flinch before starting the cut/release pose on the victim.
	victim.hv_vis_stop(list(HV_VIS_TAG_FLINCH, HV_VIS_TAG_TREMBLE, HV_VIS_TAG_KNIFE_VICTIM))
	victim.hv_vis_flash()

	// If the stab dropped a standing victim into crit (non-dead), hold them upright through the 0.25 s cut
	// before tg's own lying fall takes over, matching death_falls.dm's execution hold on lethal cuts.
	var/fell_now = was_standing && victim.body_position == LYING_DOWN
	if(fell_now && victim.hv_vis_can_hold_fall())
		victim.hv_vis_knife_upright_until = world.time + cut_total
		if(victim.stat != DEAD)
			var/matrix/tilted_upright = hv_vis_turned(pre_base, victim.hv_vis_knife_tilt, HV_VIS_FEET_Y * victim.current_size)
			victim.hv_vis_play_over(list(
				list(pre_pixel_y, tilted_upright, 0, LINEAR_EASING),
				list(pre_pixel_y, tilted_upright, cut_total, LINEAR_EASING),
				list(victim.pixel_y, matrix(victim.transform), 3, QUAD_EASING|EASE_IN),
			))

	// Exact drawn throat at the moment of the cut, through the same transform on the victim.
	var/list/throat = hv_knife_exec_throat_point(victim)
	var/throat_w = victim.pixel_w + throat[1]
	var/throat_z = victim.pixel_z + throat[2]
	var/row_pixel_y = (fell_now && victim.hv_vis_can_hold_fall()) ? pre_pixel_y : victim.pixel_y

	var/knife_zone = (!QDELETED(user) && user.get_hand_zone_of_item(src)) || BODY_ZONE_R_ARM
	var/cut_deg = hv_vis_knife_cut_angle(victim, knife_zone)

	var/toward = !QDELETED(user) ? (get_dir(user, victim) || user.dir || SOUTH) : SOUTH
	var/step_px = (HV_VIS_DX(toward) && HV_VIS_DY(toward)) ? round(HV_VIS_KNIFE_STEP_IN * 0.78, 1) : HV_VIS_KNIFE_STEP_IN
	var/step_dx = HV_VIS_DX(toward) * step_px
	var/step_dy = HV_VIS_DY(toward) * step_px

	var/obj/effect/temp_visual/hv_knife_exec_blade/blade = hv_vis_blade_ref?.resolve()
	var/obj/effect/temp_visual/hv_knife_exec_arm/knife_arm = hv_vis_knife_arm_ref?.resolve()
	if(blade && !QDELETED(blade))
		blade.pixel_y = row_pixel_y
		var/list/tip_off = blade.hv_point_offset(cut_deg, HV_VIS_KNIFE_SPRITE_TIP)
		var/list/grip_off = blade.hv_point_offset(cut_deg, HV_VIS_KNIFE_SPRITE_GRIP)
		// End of Beat 3: blade draws across the throat so the sharp tip lands on (throat_w, throat_z) and grip stays under the hand.
		var/cut_end_w = throat_w - tip_off[1]
		var/cut_end_z = throat_z - tip_off[2]
		var/fist_end_w = cut_end_w + grip_off[1]
		var/fist_end_z = cut_end_z + grip_off[2]
		blade.hv_animate_to(cut_end_w, cut_end_z, cut_deg, HV_VIS_KNIFE_CUT_TIME, QUAD_EASING|EASE_OUT)
		QDEL_IN(blade, cut_total)
		if(knife_arm && !QDELETED(knife_arm))
			knife_arm.pixel_y = row_pixel_y
			knife_arm.hv_animate_to(fist_end_w, fist_end_z, HV_VIS_KNIFE_CUT_TIME, QUAD_EASING|EASE_OUT)
			QDEL_IN(knife_arm, cut_total)
	else if(knife_arm && !QDELETED(knife_arm))
		qdel(knife_arm)

	hv_vis_blade_ref = null
	hv_vis_knife_arm_ref = null

	// Blood from the throat in the direction the victim faces, starting now as the wound lands.
	var/spray_dir = victim.dir || toward || SOUTH
	var/obj/item/bodypart/head/head_after = victim.get_bodypart(BODY_ZONE_HEAD)
	var/can_bleed_throat = (head_after ? head_after.can_bleed() : victim.can_bleed()) && !(sealed_before && cover_before >= HV_KNIFE_EXECUTION_HIGH_COVER)
	if(can_bleed_throat)
		var/spray_tiles = (sealed_before || cover_before >= HV_KNIFE_EXECUTION_LOW_COVER) ? 1 : 2
		victim.hv_blood_spray_until = 0
		victim.hv_blood_spray_strength = 0
		victim.hv_blood_spray(spray_dir, spray_tiles)
		if(!(victim.dir & NORTH))
			var/blood_color = get_color_from_blood_list(victim.get_blood_dna_list()) || BLOOD_COLOR_RED
			new /obj/effect/temp_visual/hv_throat_spurt(
				get_turf(victim),
				victim.pixel_x,
				row_pixel_y,
				throat_w,
				throat_z,
				spray_dir,
				ABOVE_MOB_LAYER,
				blood_color,
				spray_tiles,
			)

	// Beat 4 release: stop the wind-up step tag first, then hold through cut_total and step back to exact zero offset.
	if(!QDELETED(user) && isturf(user.loc))
		user.hv_vis_stop(list(HV_VIS_TAG_KNIFE_STEP))
		var/matrix/attacker_base = matrix(user.transform)
		var/matrix/attacker_lean = hv_vis_turned(attacker_base, HV_VIS_DX(toward) * 4, user.hv_vis_pivot())
		user.hv_vis_play(HV_VIS_TAG_KNIFE_STEP, list(
			list(user.pixel_w + step_dx, user.pixel_z + step_dy, attacker_lean, 0, LINEAR_EASING),
			list(user.pixel_w + step_dx, user.pixel_z + step_dy, attacker_lean, cut_total, LINEAR_EASING),
			list(user.pixel_w, user.pixel_z, attacker_base, HV_VIS_KNIFE_RELEASE_TIME, SINE_EASING),
		))

	// Beat 4 on the victim: if still standing after the cut, hunch forward clutching the throat, then return.
	if(victim.stat != DEAD && victim.body_position == STANDING_UP)
		var/hunch_angle = victim.hv_vis_knife_hunch_tilt()
		var/lurch_dx = HV_VIS_DX(spray_dir) * 2
		var/lurch_dy = (victim.dir & SOUTH) ? -2 : ((victim.dir & (EAST|WEST)) ? -1 : 0)
		var/pivot = victim.hv_vis_pivot()
		var/matrix/base = matrix(victim.transform)
		var/matrix/tilted = hv_vis_turned(base, victim.hv_vis_knife_tilt, pivot)
		var/matrix/hunched = hv_vis_turned(base, hunch_angle, pivot)
		var/hunch_total = cut_total + HV_VIS_KNIFE_HUNCH_IN + HV_VIS_KNIFE_HUNCH_HOLD + HV_VIS_KNIFE_HUNCH_OUT

		victim.hv_vis_knife_t2 = world.time + cut_total
		victim.hv_vis_knife_t3 = victim.hv_vis_knife_t2 + HV_VIS_KNIFE_HUNCH_IN
		victim.hv_vis_knife_t4 = victim.hv_vis_knife_t3 + HV_VIS_KNIFE_HUNCH_HOLD + HV_VIS_KNIFE_HUNCH_OUT
		victim.hv_vis_knife_hunch = hunch_angle
		victim.hv_vis_knife_lurch_x = lurch_dx
		victim.hv_vis_knife_lurch_y = lurch_dy

		victim.hv_vis_play(HV_VIS_TAG_KNIFE_VICTIM, list(
			list(victim.pixel_w, victim.pixel_z, tilted, 0, LINEAR_EASING),
			list(victim.pixel_w, victim.pixel_z, tilted, cut_total, LINEAR_EASING),
			list(victim.pixel_w + lurch_dx, victim.pixel_z + lurch_dy, hunched, HV_VIS_KNIFE_HUNCH_IN, QUAD_EASING|EASE_OUT),
			list(victim.pixel_w + lurch_dx, victim.pixel_z + lurch_dy, hunched, HV_VIS_KNIFE_HUNCH_HOLD, LINEAR_EASING),
			list(victim.pixel_w, victim.pixel_z, base, HV_VIS_KNIFE_HUNCH_OUT, SINE_EASING),
		))
		victim.hv_vis_hold(list(HV_VIS_TAG_KNIFE_VICTIM), HV_VIS_END_LIE|HV_VIS_END_DEATH, hunch_total)
		if(!(victim.dir & NORTH))
			addtimer(CALLBACK(victim, TYPE_PROC_REF(/mob/living/carbon, hv_vis_spawn_clutch_hand), hunch_angle, lurch_dx, lurch_dy), cut_total, TIMER_DELETE_ME)
	else if(victim.stat != DEAD && !fell_now)
		victim.hv_vis_knife_t2 = world.time + cut_total
		victim.hv_vis_knife_hunch = 0
		victim.hv_vis_knife_lurch_x = 0
		victim.hv_vis_knife_lurch_y = 0
		var/matrix/base_lying = matrix(victim.transform)
		var/matrix/tilted_lying = hv_vis_turned(base_lying, victim.hv_vis_knife_tilt, victim.hv_vis_pivot())
		victim.hv_vis_play(HV_VIS_TAG_KNIFE_VICTIM, list(
			list(victim.pixel_w, victim.pixel_z, tilted_lying, 0, LINEAR_EASING),
			list(victim.pixel_w, victim.pixel_z, tilted_lying, cut_total, LINEAR_EASING),
			list(victim.pixel_w, victim.pixel_z, base_lying, HV_VIS_KNIFE_RELEASE_TIME, SINE_EASING),
		))
	else
		victim.hv_vis_knife_clear_pose()

/// Spawns a small prop of this standing victim's own visible hand reaching up to clutch their throat during Beat 4.
/mob/living/carbon/proc/hv_vis_spawn_clutch_hand(hunch_angle, lurch_dx = 0, lurch_dy = 0)
	if(QDELETED(src) || stat == DEAD || body_position != STANDING_UP || (dir & NORTH) || !isturf(loc))
		return
	var/preferred_zone = (dir & WEST) ? BODY_ZONE_L_ARM : BODY_ZONE_R_ARM
	var/fallback_zone = (preferred_zone == BODY_ZONE_R_ARM) ? BODY_ZONE_L_ARM : BODY_ZONE_R_ARM
	var/clutch_zone = get_bodypart(preferred_zone) ? preferred_zone : (get_bodypart(fallback_zone) ? fallback_zone : null)
	if(!clutch_zone)
		return
	var/list/local_hand = hv_vis_local_hand_offset(src, clutch_zone)
	var/start_w = pixel_w + local_hand[1]
	var/start_z = pixel_z + local_hand[2]
	var/list/hunched_throat = hv_vis_throat_for_angle(hunch_angle)
	var/clutch_w = round(pixel_w + lurch_dx + hunched_throat[1], 1)
	var/clutch_z = round(pixel_z + lurch_dy + hunched_throat[2], 1)
	var/total_life = HV_VIS_KNIFE_HUNCH_IN + HV_VIS_KNIFE_HUNCH_HOLD + HV_VIS_KNIFE_HUNCH_OUT
	var/obj/effect/temp_visual/hv_knife_clutch_hand/clutch = new(
		get_turf(src),
		src,
		clutch_zone,
		pixel_x,
		pixel_y,
		start_w,
		start_z,
		ABOVE_MOB_LAYER,
		total_life,
	)
	animate(clutch, pixel_w = clutch_w, pixel_z = clutch_z, time = HV_VIS_KNIFE_HUNCH_IN, easing = QUAD_EASING|EASE_OUT)
	animate(pixel_w = clutch_w, pixel_z = clutch_z, time = HV_VIS_KNIFE_HUNCH_HOLD, easing = LINEAR_EASING)
	animate(pixel_w = start_w, pixel_z = start_z, time = HV_VIS_KNIFE_HUNCH_OUT, easing = SINE_EASING)

/// Beat 5: wind-up broke early; ease both bodies straight back to their exact starting poses in under 0.3 s with no blood.
/obj/item/knife/proc/hv_vis_abort_knife_windup(mob/living/user, mob/living/carbon/victim)
	hv_vis_clear_exec_props()
	if(!QDELETED(user))
		user.hv_vis_release(HV_VIS_TAG_KNIFE_STEP, HV_VIS_KNIFE_ABORT_TIME)
	if(!QDELETED(victim))
		victim.hv_vis_knife_clear_pose()
		if(victim.stat != DEAD)
			victim.hv_vis_release(HV_VIS_TAG_KNIFE_VICTIM, HV_VIS_KNIFE_ABORT_TIME)
			victim.hv_vis_stop(list(HV_VIS_TAG_TREMBLE))
		else
			victim.hv_vis_stop(list(HV_VIS_TAG_KNIFE_VICTIM, HV_VIS_TAG_TREMBLE))

/// Deletes any active knife execution props tracked by weakref on this knife.
/obj/item/knife/proc/hv_vis_clear_exec_props()
	var/atom/blade = hv_vis_blade_ref?.resolve()
	if(blade && !QDELETED(blade))
		qdel(blade)
	var/atom/knife_arm = hv_vis_knife_arm_ref?.resolve()
	if(knife_arm && !QDELETED(knife_arm))
		qdel(knife_arm)
	hv_vis_blade_ref = null
	hv_vis_knife_arm_ref = null

// ---- Geometry helpers ----

/// Throat offset list(x, y) from this mob's icon centre when leaned by `angle` degrees clockwise.
/mob/living/proc/hv_vis_throat_for_angle(angle)
	var/base_x = (dir & EAST) ? 3.5 : ((dir & WEST) ? -3.5 : -0.5)
	var/base_y = 5.5
	var/matrix/pose = hv_vis_turned(matrix(transform), angle, hv_vis_pivot())
	return list(
		round(pose.a * base_x + pose.b * base_y + pose.c, 0.01),
		round(pose.d * base_x + pose.e * base_y + pose.f, 0.01),
	)

/// Clockwise tilt angle (degrees) that pulls this victim's head back toward `attacker`.
/mob/living/proc/hv_vis_knife_windup_tilt(mob/living/attacker)
	if(body_position == LYING_DOWN)
		var/toward_attacker = HV_VIS_DX(get_dir(src, attacker)) || -1
		return toward_attacker * HV_VIS_KNIFE_TILT_LYING
	if(dir & EAST)
		return -HV_VIS_KNIFE_TILT_SIDE
	if(dir & WEST)
		return HV_VIS_KNIFE_TILT_SIDE
	var/back_dx = HV_VIS_DX(get_dir(src, attacker))
	if(back_dx)
		return back_dx * HV_VIS_KNIFE_TILT_FRONT
	return (dir & NORTH) ? HV_VIS_KNIFE_TILT_FRONT : -HV_VIS_KNIFE_TILT_FRONT

/// Clockwise tilt angle (degrees) for a standing survivor hunching forward about their feet after release.
/mob/living/proc/hv_vis_knife_hunch_tilt()
	if(dir & EAST)
		return HV_VIS_KNIFE_HUNCH_TILT
	if(dir & WEST)
		return -HV_VIS_KNIFE_HUNCH_TILT
	return (dir & NORTH) ? -HV_VIS_KNIFE_HUNCH_TILT : HV_VIS_KNIFE_HUNCH_TILT

/// Clockwise angle from EAST (0 deg) along which the knife blade points while held against `victim`'s throat.
/proc/hv_vis_knife_hold_angle(mob/living/victim, knife_zone)
	if(victim.body_position == STANDING_UP)
		if(victim.dir & EAST)
			return -12
		if(victim.dir & WEST)
			return 192
	return (knife_zone == BODY_ZONE_R_ARM) ? 0 : 180

/// Clockwise angle from EAST (0 deg) along which the knife blade finishes at the end of the throat cut.
/proc/hv_vis_knife_cut_angle(mob/living/victim, knife_zone)
	if(victim.body_position == STANDING_UP)
		if(victim.dir & EAST)
			return 6
		if(victim.dir & WEST)
			return 174
	return (knife_zone == BODY_ZONE_R_ARM) ? 0 : 180

/// Unscaled axial sprite coordinate on the blade that rests on `victim`'s throat during the wind-up hold.
/proc/hv_vis_knife_hold_contact(mob/living/victim)
	if(victim.body_position == STANDING_UP && (victim.dir & (EAST|WEST)))
		return HV_VIS_KNIFE_SPRITE_SIDE_HOLD
	return HV_VIS_KNIFE_SPRITE_HEEL

/// Pixel offset list(x, y) of `arm_zone`'s hand (rows 16-17 in bodyparts_greyscale.dmi) from `holder`'s icon centre.
/proc/hv_vis_local_hand_offset(mob/living/holder, arm_zone)
	var/right_hand = (arm_zone == BODY_ZONE_R_ARM)
	switch(holder.dir)
		if(NORTH)
			return list(right_hand ? 6 : -7, -1)
		if(EAST)
			return list(right_hand ? -3 : 2, -1)
		if(WEST)
			return list(right_hand ? -3 : 3, -1)
	return list(right_hand ? -7 : 6, -1)

/// Converts `attacker`'s hand position (with optional extra step `step_dx`, `step_dy`) into `victim`'s turf pixel_w/pixel_z frame.
/proc/hv_vis_hand_in_victim_frame(mob/living/attacker, mob/living/victim, arm_zone, step_dx = 0, step_dy = 0)
	var/list/local_hand = hv_vis_local_hand_offset(attacker, arm_zone)
	var/frame_x = (attacker.x - victim.x) * ICON_SIZE_X + (attacker.pixel_x - victim.pixel_x) + attacker.pixel_w + step_dx + local_hand[1]
	var/frame_y = (attacker.y - victim.y) * ICON_SIZE_Y + (attacker.pixel_y - victim.pixel_y) + attacker.pixel_z + step_dy + local_hand[2]
	return list(round(frame_x, 1), round(frame_y, 1))

/// Builds a small skin-tinted hand mutable_appearance from `holder`'s `arm_zone` shifted so its fist sits on (0, 0).
/proc/hv_vis_build_hand_overlay(mob/living/holder, arm_zone)
	if(!iscarbon(holder))
		return null
	var/mob/living/carbon/carbon_holder = holder
	var/obj/item/bodypart/arm = carbon_holder.get_bodypart(arm_zone)
	if(!arm)
		return null
	var/expected_hand_state = arm.aux_zone ? "[arm.limb_id]_[arm.aux_zone]" : null
	var/image/chosen
	var/image/fallback_limb
	var/list/limb_layers = arm.get_limb_icon(dropped = FALSE, update_on = carbon_holder)
	for(var/entry in limb_layers)
		if(!istype(entry, /image))
			continue
		var/image/img = entry
		if(img.plane == EMISSIVE_PLANE)
			continue
		if(expected_hand_state && img.icon_state == expected_hand_state)
			chosen = img
			break
		if(!fallback_limb && img.icon && img.icon_state)
			fallback_limb = img
	if(!chosen)
		chosen = fallback_limb
	if(!chosen)
		return null
	// In SOUTH, human_r_hand sits at cols 7-10 rows 16-17 (-7, -1) and human_l_hand at cols 20-23 rows 16-17 (+6, -1).
	var/mutable_appearance/hand_overlay = mutable_appearance(chosen.icon, chosen.icon_state, FLOAT_LAYER)
	hand_overlay.dir = SOUTH
	hand_overlay.color = chosen.color
	hand_overlay.alpha = chosen.alpha
	hand_overlay.pixel_w = (arm.body_zone == BODY_ZONE_R_ARM) ? 7 : -6
	hand_overlay.pixel_z = 1
	return hand_overlay

// ---- Visual props ----

/// Temporary visual copy of the real knife blade, scaled to ~11 px and drawn across the victim's throat.
/obj/effect/temp_visual/hv_knife_exec_blade
	name = "knife blade"
	plane = GAME_PLANE
	layer = HV_VIS_KNIFE_BLADE_LAYER
	randomdir = FALSE
	duration = 25
	/// Marker read by the recording harness to locate the active knife execution blade prop.
	var/hv_knife_exec_blade = TRUE
	/// Native icon_angle of the source knife so rotations align its blade along any target angle.
	var/hv_native_icon_angle = -90

/obj/effect/temp_visual/hv_knife_exec_blade/Initialize(mapload, obj/item/knife/source_knife, row_x = 0, row_y = 0, start_w = 0, start_z = 0, blade_deg = 0, draw_layer = HV_VIS_KNIFE_BLADE_LAYER, life = 25)
	if(life > 0)
		duration = life
	. = ..()
	if(!istype(source_knife))
		return INITIALIZE_HINT_QDEL
	name = source_knife.name
	icon = source_knife.icon
	icon_state = source_knife.icon_state
	color = source_knife.color
	alpha = source_knife.alpha
	hv_native_icon_angle = source_knife.icon_angle
	layer = draw_layer
	pixel_x = row_x
	pixel_y = row_y
	hv_place_at(start_w, start_z, blade_deg)

/// Matrix scaling this knife to ~10 px overall, orienting its blade along `blade_deg` clockwise from EAST, with optional sub-pixel shift.
/obj/effect/temp_visual/hv_knife_exec_blade/proc/hv_turn_matrix(blade_deg, shift_x = 0, shift_y = 0)
	var/axis_span = max(abs(cos(hv_native_icon_angle)), abs(sin(hv_native_icon_angle)), 0.7071)
	var/blade_scale = HV_VIS_KNIFE_SCALE * (axis_span / 0.7071)
	var/matrix/turned = matrix()
	turned.Scale(blade_scale, blade_scale)
	turned.Turn(blade_deg - hv_native_icon_angle)
	if(shift_x || shift_y)
		turned.Translate(shift_x, shift_y)
	return turned

/// Places this blade prop at exact float `(exact_w, exact_z)` and `blade_deg`, putting the sub-pixel remainder in `transform`.
/obj/effect/temp_visual/hv_knife_exec_blade/proc/hv_place_at(exact_w, exact_z, blade_deg)
	var/int_w = round(exact_w, 1)
	var/int_z = round(exact_z, 1)
	pixel_w = int_w
	pixel_z = int_z
	transform = hv_turn_matrix(blade_deg, exact_w - int_w, exact_z - int_z)

/// Animates this blade prop to exact float `(exact_w, exact_z)` and `blade_deg` with sub-pixel accuracy.
/obj/effect/temp_visual/hv_knife_exec_blade/proc/hv_animate_to(exact_w, exact_z, blade_deg, anim_time, anim_easing)
	var/int_w = round(exact_w, 1)
	var/int_z = round(exact_z, 1)
	var/matrix/blade_turn = hv_turn_matrix(blade_deg, exact_w - int_w, exact_z - int_z)
	animate(src, pixel_w = int_w, pixel_z = int_z, transform = blade_turn, time = anim_time, easing = anim_easing)

/// Pixel offset list(dx, dy) from this blade prop's centre for axial sprite point `along_px`, through `hv_turn_matrix`.
/obj/effect/temp_visual/hv_knife_exec_blade/proc/hv_point_offset(blade_deg, along_px)
	var/nx = cos(hv_native_icon_angle)
	var/ny = -sin(hv_native_icon_angle)
	var/axis_span = max(abs(nx), abs(ny), 0.5)
	var/local_x = along_px * nx / axis_span
	var/local_y = along_px * ny / axis_span
	var/matrix/turned = hv_turn_matrix(blade_deg)
	return list(
		turned.a * local_x + turned.b * local_y + turned.c,
		turned.d * local_x + turned.e * local_y + turned.f,
	)

/// Small skin-tinted hand prop built from the attacker's real arm bodypart, centred on the fist over the knife grip.
/obj/effect/temp_visual/hv_knife_exec_arm
	name = "hand"
	icon = 'icons/mob/human/bodyparts_greyscale.dmi'
	icon_state = ""
	plane = GAME_PLANE
	layer = HV_VIS_KNIFE_HAND_LAYER
	appearance_flags = KEEP_TOGETHER
	randomdir = FALSE
	duration = 25

/obj/effect/temp_visual/hv_knife_exec_arm/Initialize(mapload, mob/living/holder, arm_zone = BODY_ZONE_R_ARM, row_x = 0, row_y = 0, fist_w = 0, fist_z = 0, draw_layer = HV_VIS_KNIFE_HAND_LAYER, life = 25)
	if(life > 0)
		duration = life
	. = ..()
	layer = draw_layer
	pixel_x = row_x
	pixel_y = row_y
	var/int_w = round(fist_w, 1)
	var/int_z = round(fist_z, 1)
	pixel_w = int_w
	pixel_z = int_z
	transform = hv_shift_matrix(fist_w - int_w, fist_z - int_z)
	var/mutable_appearance/hand_overlay = hv_vis_build_hand_overlay(holder, arm_zone)
	if(hand_overlay)
		add_overlay(hand_overlay)

/// Sub-pixel translation matrix for keeping the hand prop locked to the scaled knife grip.
/obj/effect/temp_visual/hv_knife_exec_arm/proc/hv_shift_matrix(shift_x = 0, shift_y = 0)
	var/matrix/shifted = matrix()
	if(shift_x || shift_y)
		shifted.Translate(shift_x, shift_y)
	return shifted

/// Animates this hand prop to exact float `(exact_w, exact_z)` with sub-pixel accuracy.
/obj/effect/temp_visual/hv_knife_exec_arm/proc/hv_animate_to(exact_w, exact_z, anim_time, anim_easing)
	var/int_w = round(exact_w, 1)
	var/int_z = round(exact_z, 1)
	var/matrix/shifted = hv_shift_matrix(exact_w - int_w, exact_z - int_z)
	animate(src, pixel_w = int_w, pixel_z = int_z, transform = shifted, time = anim_time, easing = anim_easing)

/// Small skin-tinted hand prop for a standing survivor clutching their own throat after release; vanishes early if they move or fall.
/obj/effect/temp_visual/hv_knife_clutch_hand
	name = "hand"
	icon = 'icons/mob/human/bodyparts_greyscale.dmi'
	icon_state = ""
	plane = GAME_PLANE
	layer = ABOVE_MOB_LAYER
	appearance_flags = KEEP_TOGETHER
	randomdir = FALSE
	duration = 9
	/// Weakref to the victim clutching their throat so signals clean up properly.
	var/datum/weakref/hv_owner_ref

/obj/effect/temp_visual/hv_knife_clutch_hand/Initialize(mapload, mob/living/victim, arm_zone = BODY_ZONE_R_ARM, row_x = 0, row_y = 0, fist_w = 0, fist_z = 0, draw_layer = ABOVE_MOB_LAYER, life = 9)
	if(life > 0)
		duration = life
	. = ..()
	layer = draw_layer
	pixel_x = row_x
	pixel_y = row_y
	pixel_w = fist_w
	pixel_z = fist_z
	var/mutable_appearance/hand_overlay = hv_vis_build_hand_overlay(victim, arm_zone)
	if(hand_overlay)
		add_overlay(hand_overlay)
	if(victim)
		hv_owner_ref = WEAKREF(victim)
		RegisterSignal(victim, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_SET_BODY_POSITION, COMSIG_LIVING_DEATH), PROC_REF(hv_drop_clutch))

/obj/effect/temp_visual/hv_knife_clutch_hand/Destroy()
	var/mob/living/victim = hv_owner_ref?.resolve()
	if(victim)
		UnregisterSignal(victim, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_SET_BODY_POSITION, COMSIG_LIVING_DEATH))
	hv_owner_ref = null
	return ..()

/obj/effect/temp_visual/hv_knife_clutch_hand/proc/hv_drop_clutch(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// Short on-body jet of blood spurting a few pixels off the front of the victim's neck (S, E, W only).
/obj/effect/temp_visual/hv_throat_spurt
	name = "arterial spray"
	icon = HV_BLOOD_SPRAY_ICON
	icon_state = "squirt_greyscale"
	plane = GAME_PLANE
	layer = ABOVE_MOB_LAYER
	randomdir = FALSE
	duration = 4

/obj/effect/temp_visual/hv_throat_spurt/Initialize(mapload, row_x = 0, row_y = 0, throat_w = 0, throat_z = 0, spray_dir = SOUTH, draw_layer = ABOVE_MOB_LAYER, blood_color = BLOOD_COLOR_RED, strength = 2)
	. = ..()
	setDir(spray_dir || SOUTH)
	layer = draw_layer
	color = blood_color
	pixel_x = row_x
	pixel_y = row_y

	var/dx = HV_VIS_DX(dir)
	var/dy = HV_VIS_DY(dir)
	var/start_reach = 2
	var/end_reach = (dir & SOUTH) ? (2 + strength) : (3 + strength)
	pixel_w = round(throat_w + dx * start_reach, 1)
	pixel_z = round(throat_z + dy * start_reach, 1)

	var/matrix/start = matrix()
	start.Scale(0.14, 0.14)
	transform = start

	var/matrix/end_mat = matrix()
	end_mat.Scale(0.18 + strength * 0.03, 0.18 + strength * 0.03)
	animate(
		src,
		pixel_w = round(throat_w + dx * end_reach, 1),
		pixel_z = round(throat_z + dy * end_reach, 1),
		transform = end_mat,
		alpha = 0,
		time = duration,
		easing = QUAD_EASING|EASE_OUT,
	)
