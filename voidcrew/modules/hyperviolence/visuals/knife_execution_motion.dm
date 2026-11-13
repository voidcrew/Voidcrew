// Hyperviolence visuals: knife executions (overlays_exec/knife_executions.dm).
//
// Beats over the execution's own wind-up and kill (purely visual; every sequence ends where it began):
// 1. Wind-up grab (0 - 0.3 s): the attacker steps in toward the victim, the off-hand reaches to the
//    crown of the head and tilts the victim back about their feet, and the knife hand brings the real
//    knife's blade from that hand to the start of the throat cut, grip in the hand every frame.
// 2. Hold (0.3 - 1.5 s): the attacker stays pressed in while the victim trembles and then goes still.
// 3. The cut (1.5 - 1.75 s, held 0.1 s): the blade draws across the drawn throat with its sharp edge
//    on the throat the whole way, ending with its edge/tip on the throat; blood spurts from the throat
//    point and sprays along the floor in the direction the victim faces once the wound lands.
// 4. Release: the blade prop disappears, the attacker steps back to zero offset, and a survivor still
//    on their feet hunches forward clutching their throat before returning; if the blow dropped them,
//    tg's own fall and death_falls.dm take over. A broken wind-up releases everything cleanly, no blood.

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
	/// Until this world.time, a victim felled by the cut is still drawn upright over tg's lying turn.
	var/hv_vis_knife_upright_until = -1
	/// Copy of the standing base transform while held upright through the cut.
	var/matrix/hv_vis_knife_pose_base

/obj/item/knife
	/// Weakref to the active blade prop (/obj/effect/temp_visual/hv_knife_exec_blade) during a wind-up.
	var/datum/weakref/hv_vis_blade_ref
	/// Weakref to the attacker's knife-hand forearm prop during a wind-up.
	var/datum/weakref/hv_vis_knife_arm_ref
	/// Weakref to the attacker's off-hand grabbing forearm prop during a wind-up.
	var/datum/weakref/hv_vis_grab_arm_ref
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
	if(world.time >= hv_vis_knife_t2)
		hv_vis_knife_clear_pose()
		hv_vis_stop(list(HV_VIS_TAG_KNIFE_VICTIM))
	return ..()

/// Pixel offset list(x, y) of `victim`'s drawn throat from their icon centre at `world.time`'s pose.
/proc/hv_knife_exec_throat_point(mob/living/victim)
	if(!isliving(victim))
		return list(0, 0)
	var/base_x = (victim.dir & EAST) ? 3 : ((victim.dir & WEST) ? -4 : 0)
	var/base_y = 6
	var/angle = victim.hv_vis_knife_pose_angle()
	var/held_upright = victim.hv_vis_knife_pose_base && world.time < victim.hv_vis_knife_upright_until
	var/matrix/base = held_upright ? matrix(victim.hv_vis_knife_pose_base) : matrix(victim.transform)
	var/pivot = held_upright ? (HV_VIS_FEET_Y * victim.current_size) : victim.hv_vis_pivot()
	var/matrix/pose = hv_vis_turned(base, angle, pivot)
	return list(
		round(pose.a * base_x + pose.b * base_y + pose.c, 0.1),
		round(pose.d * base_x + pose.e * base_y + pose.f, 0.1),
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

/// Clears tracked knife execution pose timestamps on this mob.
/mob/living/proc/hv_vis_knife_clear_pose()
	hv_vis_knife_t0 = -1
	hv_vis_knife_t1 = -1
	hv_vis_knife_t2 = -1
	hv_vis_knife_t3 = -1
	hv_vis_knife_t4 = -1
	hv_vis_knife_tilt = 0
	hv_vis_knife_hunch = 0
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

	victim.hv_vis_execution_time = world.time
	user.hv_vis_knife_executing = TRUE
	. = ..()
	if(!QDELETED(user))
		user.hv_vis_knife_executing = FALSE
	if(!.)
		return

	hv_vis_cut_landed = TRUE
	hv_vis_play_knife_cut_and_release(user, victim, was_standing, pre_pixel_y, pre_base, sealed_before, cover_before)

// ---- Wind-up, cut and release choreography ----

/// Starts Beats 1 and 2: attacker step-in, victim head-pull + tremble, and blade + forearm props.
/obj/item/knife/proc/hv_vis_begin_knife_windup(mob/living/user, mob/living/carbon/victim)
	hv_vis_clear_exec_props()
	var/turf/victim_turf = get_turf(victim)
	if(!victim_turf)
		return

	var/cut_hold_total = HV_KNIFE_EXECUTION_WINDUP + HV_VIS_KNIFE_CUT_TIME + HV_VIS_KNIFE_CUT_HOLD
	var/toward = get_dir(user, victim) || user.dir || SOUTH
	var/step_px = (HV_VIS_DX(toward) && HV_VIS_DY(toward)) ? round(HV_VIS_KNIFE_STEP_IN * 0.78) : HV_VIS_KNIFE_STEP_IN
	var/step_dx = HV_VIS_DX(toward) * step_px
	var/step_dy = HV_VIS_DY(toward) * step_px

	// Attacker steps in behind the victim and stays pressed in until the cut releases.
	var/matrix/attacker_base = matrix(user.transform)
	var/matrix/attacker_lean = hv_vis_turned(attacker_base, HV_VIS_DX(toward) * 4, user.hv_vis_pivot())
	user.hv_vis_play(HV_VIS_TAG_KNIFE_STEP, list(
		list(user.pixel_w + step_dx, user.pixel_z + step_dy, attacker_lean, HV_VIS_KNIFE_GRAB_TIME, QUAD_EASING|EASE_OUT),
		list(user.pixel_w + step_dx, user.pixel_z + step_dy, attacker_lean, cut_hold_total - HV_VIS_KNIFE_GRAB_TIME + 0.5 SECONDS, LINEAR_EASING),
		list(user.pixel_w, user.pixel_z, attacker_base, HV_VIS_KNIFE_RELEASE_TIME, SINE_EASING),
	))

	// Victim is pulled back a few degrees about their feet and trembles until the press pause.
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
	victim.hv_vis_knife_upright_until = -1
	victim.hv_vis_knife_pose_base = victim.body_position == STANDING_UP ? matrix(victim_base) : null

	victim.hv_vis_play(HV_VIS_TAG_KNIFE_VICTIM, list(
		list(victim.pixel_w, victim.pixel_z, victim_tilted, HV_VIS_KNIFE_GRAB_TIME, QUAD_EASING|EASE_OUT),
		list(victim.pixel_w, victim.pixel_z, victim_tilted, cut_hold_total - HV_VIS_KNIFE_GRAB_TIME + 0.5 SECONDS, LINEAR_EASING),
		list(victim.pixel_w, victim.pixel_z, victim_base, HV_VIS_KNIFE_RELEASE_TIME, SINE_EASING),
	))
	victim.hv_vis_tremble(HV_KNIFE_EXECUTION_WINDUP - HV_VIS_PRESS_PAUSE, 1)

	// Compute the throat target at the full wind-up tilt (t1..t2) so the blade lands on the tilted throat.
	var/list/tilted_throat = victim.hv_vis_throat_for_angle(tilt)
	var/throat_w = victim.pixel_w + tilted_throat[1]
	var/throat_z = victim.pixel_z + tilted_throat[2]

	var/knife_zone = user.get_hand_zone_of_item(src) || BODY_ZONE_R_ARM
	var/grab_zone = (knife_zone == BODY_ZONE_R_ARM) ? BODY_ZONE_L_ARM : BODY_ZONE_R_ARM

	// Attacker's real hand and shoulder coordinates in the victim turf's pixel frame.
	var/list/knife_hand_start = hv_vis_hand_in_victim_frame(user, victim, knife_zone, 0, 0)
	var/list/grab_hand_start = hv_vis_hand_in_victim_frame(user, victim, grab_zone, 0, 0)
	var/list/knife_shoulder_in = hv_vis_shoulder_in_victim_frame(user, victim, knife_zone, step_dx, step_dy)
	var/list/grab_shoulder_in = hv_vis_shoulder_in_victim_frame(user, victim, grab_zone, step_dx, step_dy)

	var/blade_deg = hv_vis_knife_blade_angle(victim, knife_zone)
	var/ux = cos(blade_deg)
	var/uy = -sin(blade_deg)

	// Start of Beat 3: heel of the cutting edge rests on the tilted throat; grip sits in the knife hand.
	var/cut_start_w = round(throat_w - HV_VIS_KNIFE_CUT_START_REACH * ux, 0.1)
	var/cut_start_z = round(throat_z - HV_VIS_KNIFE_CUT_START_REACH * uy, 0.1)
	var/fist_in_w = round(cut_start_w - HV_VIS_KNIFE_GRIP_BACK * ux, 0.1)
	var/fist_in_z = round(cut_start_z - HV_VIS_KNIFE_GRIP_BACK * uy, 0.1)

	var/north_occluded = (victim.dir & NORTH) != 0
	var/blade_layer = north_occluded ? HV_VIS_KNIFE_BEHIND_LAYER : HV_VIS_KNIFE_BLADE_LAYER
	var/knife_arm_layer = north_occluded ? HV_VIS_KNIFE_BEHIND_HAND_LAYER : HV_VIS_KNIFE_HAND_LAYER

	// Spawn the blade at the exact hand holding the knife (grip == hand0), then bring it to the throat.
	var/start_blade_w = round(knife_hand_start[1] + HV_VIS_KNIFE_GRIP_BACK * ux, 0.1)
	var/start_blade_z = round(knife_hand_start[2] + HV_VIS_KNIFE_GRIP_BACK * uy, 0.1)
	var/obj/effect/temp_visual/hv_knife_exec_blade/blade = new(
		victim_turf,
		src,
		victim.pixel_x,
		victim.pixel_y,
		start_blade_w,
		start_blade_z,
		blade_deg,
		blade_layer,
		cut_hold_total + 1 SECONDS,
	)
	var/matrix/blade_turn = blade.hv_turn_matrix(blade_deg)
	animate(blade, pixel_w = cut_start_w, pixel_z = cut_start_z, transform = blade_turn, time = HV_VIS_KNIFE_GRAB_TIME, easing = QUAD_EASING|EASE_OUT)
	hv_vis_blade_ref = WEAKREF(blade)

	// Spawn the knife-hand forearm prop starting at that same hand and tracking the blade's grip.
	var/obj/effect/temp_visual/hv_knife_exec_arm/knife_arm = new(
		victim_turf,
		user,
		knife_zone,
		victim.pixel_x,
		victim.pixel_y,
		knife_hand_start[1],
		knife_hand_start[2],
		knife_shoulder_in[1],
		knife_shoulder_in[2],
		knife_arm_layer,
		cut_hold_total + 1 SECONDS,
	)
	knife_arm.hv_animate_to(fist_in_w, fist_in_z, knife_shoulder_in[1], knife_shoulder_in[2], HV_VIS_KNIFE_GRAB_TIME, QUAD_EASING|EASE_OUT)
	hv_vis_knife_arm_ref = WEAKREF(knife_arm)

	// Spawn the off-hand grabbing forearm prop behind the victim, reaching to the crown to pull the head back.
	var/crown_shift_x = (victim.dir & EAST) ? -2 : ((victim.dir & WEST) ? 2 : ((grab_zone == BODY_ZONE_L_ARM) ? 2 : -2))
	var/crown_w = round(throat_w + crown_shift_x, 0.1)
	var/crown_z = round(throat_z + 5, 0.1)
	var/obj/effect/temp_visual/hv_knife_exec_arm/grab_arm = new(
		victim_turf,
		user,
		grab_zone,
		victim.pixel_x,
		victim.pixel_y,
		grab_hand_start[1],
		grab_hand_start[2],
		grab_shoulder_in[1],
		grab_shoulder_in[2],
		HV_VIS_KNIFE_FAR_ARM_LAYER,
		cut_hold_total + 1 SECONDS,
	)
	grab_arm.hv_animate_to(crown_w, crown_z, grab_shoulder_in[1], grab_shoulder_in[2], HV_VIS_KNIFE_GRAB_TIME, QUAD_EASING|EASE_OUT)
	hv_vis_grab_arm_ref = WEAKREF(grab_arm)

/// Runs Beats 3 and 4 once the wind-up succeeded and the real stab + slash wound landed.
/obj/item/knife/proc/hv_vis_play_knife_cut_and_release(mob/living/user, mob/living/carbon/victim, was_standing, pre_pixel_y, matrix/pre_base, sealed_before, cover_before)
	var/cut_total = HV_VIS_KNIFE_CUT_TIME + HV_VIS_KNIFE_CUT_HOLD
	if(!QDELETED(user))
		user.hv_vis_stop(list(HV_VIS_TAG_HITSTOP))

	if(QDELETED(victim) || !isturf(victim.loc))
		hv_vis_clear_exec_props()
		if(!QDELETED(user))
			user.hv_vis_release(HV_VIS_TAG_KNIFE_STEP, HV_VIS_KNIFE_RELEASE_TIME)
		return

	// Keep the victim steady in the attacker's grip across the 0.25 s throat draw rather than flinching away early.
	victim.hv_vis_stop(list(HV_VIS_TAG_FLINCH, HV_VIS_TAG_TREMBLE))
	victim.hv_vis_flash()

	// If the stab dropped a standing victim into crit (non-dead), hold them upright through the 0.25 s cut
	// before tg's own lying fall takes over, matching death_falls.dm's execution hold on lethal cuts.
	var/fell_now = was_standing && victim.body_position == LYING_DOWN
	if(fell_now && victim.hv_vis_can_hold_fall())
		victim.hv_vis_knife_upright_until = world.time + cut_total
		if(victim.stat != DEAD)
			victim.hv_vis_stop(list(HV_VIS_TAG_KNIFE_VICTIM))
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
	var/grab_zone = (knife_zone == BODY_ZONE_R_ARM) ? BODY_ZONE_L_ARM : BODY_ZONE_R_ARM
	var/blade_deg = hv_vis_knife_blade_angle(victim, knife_zone)
	var/ux = cos(blade_deg)
	var/uy = -sin(blade_deg)

	// End of Beat 3: blade has drawn across the throat so its sharp edge/tip sits right on (throat_w, throat_z).
	var/cut_end_w = round(throat_w - HV_VIS_KNIFE_EDGE_REACH * ux, 0.1)
	var/cut_end_z = round(throat_z - HV_VIS_KNIFE_EDGE_REACH * uy, 0.1)
	var/fist_end_w = round(cut_end_w - HV_VIS_KNIFE_GRIP_BACK * ux, 0.1)
	var/fist_end_z = round(cut_end_z - HV_VIS_KNIFE_GRIP_BACK * uy, 0.1)

	var/toward = !QDELETED(user) ? (get_dir(user, victim) || user.dir || SOUTH) : SOUTH
	var/step_px = (HV_VIS_DX(toward) && HV_VIS_DY(toward)) ? round(HV_VIS_KNIFE_STEP_IN * 0.78) : HV_VIS_KNIFE_STEP_IN
	var/step_dx = HV_VIS_DX(toward) * step_px
	var/step_dy = HV_VIS_DY(toward) * step_px

	var/obj/effect/temp_visual/hv_knife_exec_blade/blade = hv_vis_blade_ref?.resolve()
	if(blade && !QDELETED(blade))
		blade.pixel_y = row_pixel_y
		var/matrix/blade_turn = blade.hv_turn_matrix(blade_deg)
		animate(blade, pixel_w = cut_end_w, pixel_z = cut_end_z, transform = blade_turn, time = HV_VIS_KNIFE_CUT_TIME, easing = QUAD_EASING|EASE_OUT)
		QDEL_IN(blade, cut_total)

	var/obj/effect/temp_visual/hv_knife_exec_arm/knife_arm = hv_vis_knife_arm_ref?.resolve()
	if(knife_arm && !QDELETED(knife_arm) && !QDELETED(user))
		knife_arm.pixel_y = row_pixel_y
		var/list/knife_shoulder_in = hv_vis_shoulder_in_victim_frame(user, victim, knife_zone, step_dx, step_dy)
		var/list/knife_hand_home = hv_vis_hand_in_victim_frame(user, victim, knife_zone, 0, 0)
		var/list/knife_shoulder_home = hv_vis_shoulder_in_victim_frame(user, victim, knife_zone, 0, 0)
		knife_arm.hv_animate_cut_and_retract(
			fist_end_w,
			fist_end_z,
			knife_shoulder_in[1],
			knife_shoulder_in[2],
			knife_hand_home[1],
			knife_hand_home[2],
			knife_shoulder_home[1],
			knife_shoulder_home[2],
		)
	else if(knife_arm && !QDELETED(knife_arm))
		QDEL_IN(knife_arm, cut_total)

	var/obj/effect/temp_visual/hv_knife_exec_arm/grab_arm = hv_vis_grab_arm_ref?.resolve()
	if(grab_arm && !QDELETED(grab_arm) && !QDELETED(user))
		grab_arm.pixel_y = row_pixel_y
		var/list/grab_shoulder_in = hv_vis_shoulder_in_victim_frame(user, victim, grab_zone, step_dx, step_dy)
		var/list/grab_hand_home = hv_vis_hand_in_victim_frame(user, victim, grab_zone, 0, 0)
		var/list/grab_shoulder_home = hv_vis_shoulder_in_victim_frame(user, victim, grab_zone, 0, 0)
		grab_arm.hv_animate_cut_and_retract(
			grab_arm.pixel_w,
			grab_arm.pixel_z,
			grab_shoulder_in[1],
			grab_shoulder_in[2],
			grab_hand_home[1],
			grab_hand_home[2],
			grab_shoulder_home[1],
			grab_shoulder_home[2],
		)
	else if(grab_arm && !QDELETED(grab_arm))
		QDEL_IN(grab_arm, cut_total)

	hv_vis_blade_ref = null
	hv_vis_knife_arm_ref = null
	hv_vis_grab_arm_ref = null

	// Blood from the throat in the direction the victim faces, starting now as the wound lands.
	var/spray_dir = victim.dir || toward || SOUTH
	var/obj/item/bodypart/head/head_after = victim.get_bodypart(BODY_ZONE_HEAD)
	var/can_bleed_throat = (head_after ? head_after.can_bleed() : victim.can_bleed()) && !(sealed_before && cover_before >= HV_KNIFE_EXECUTION_HIGH_COVER)
	if(can_bleed_throat)
		var/spray_tiles = 3
		if(sealed_before || cover_before >= HV_KNIFE_EXECUTION_HIGH_COVER)
			spray_tiles = 1
		else if(cover_before >= HV_KNIFE_EXECUTION_LOW_COVER)
			spray_tiles = 2
		// Allow the throat spray to fire in victim.dir even if the stab just triggered a hit-dir spray.
		victim.hv_blood_spray_until = 0
		victim.hv_blood_spray(spray_dir, spray_tiles)
		var/spurt_layer = (victim.dir & NORTH) ? HV_VIS_KNIFE_BEHIND_SPURT_LAYER : ABOVE_MOB_LAYER
		var/blood_color = get_color_from_blood_list(victim.get_blood_dna_list()) || BLOOD_COLOR_RED
		new /obj/effect/temp_visual/hv_throat_spurt(
			get_turf(victim),
			victim.pixel_x,
			row_pixel_y,
			throat_w,
			throat_z,
			spray_dir,
			spurt_layer,
			blood_color,
			spray_tiles,
		)

	// Beat 4 release: attacker steps back to exact zero offset after the cut + hold.
	if(!QDELETED(user) && isturf(user.loc))
		var/matrix/attacker_base = matrix(user.transform)
		var/matrix/attacker_lean = hv_vis_turned(attacker_base, HV_VIS_DX(toward) * 4, user.hv_vis_pivot())
		user.hv_vis_play(HV_VIS_TAG_KNIFE_STEP, list(
			list(user.pixel_w + step_dx, user.pixel_z + step_dy, attacker_lean, cut_total, LINEAR_EASING),
			list(user.pixel_w, user.pixel_z, attacker_base, HV_VIS_KNIFE_RELEASE_TIME, SINE_EASING),
		))

	// Beat 4 on the victim: if still standing after the cut, hunch forward clutching the throat, then return.
	if(victim.stat != DEAD && victim.body_position == STANDING_UP)
		var/hunch_angle = victim.hv_vis_knife_hunch_tilt()
		var/lurch_dx = HV_VIS_DX(spray_dir) * 2
		var/lurch_dy = HV_VIS_DY(spray_dir) * 2 - 1
		var/pivot = victim.hv_vis_pivot()
		var/matrix/base = matrix(victim.transform)
		var/matrix/tilted = hv_vis_turned(base, victim.hv_vis_knife_tilt, pivot)
		var/matrix/hunched = hv_vis_turned(base, hunch_angle, pivot)

		victim.hv_vis_knife_t2 = world.time + cut_total
		victim.hv_vis_knife_t3 = victim.hv_vis_knife_t2 + HV_VIS_KNIFE_HUNCH_IN
		victim.hv_vis_knife_t4 = victim.hv_vis_knife_t3 + HV_VIS_KNIFE_HUNCH_HOLD + HV_VIS_KNIFE_HUNCH_OUT
		victim.hv_vis_knife_hunch = hunch_angle

		victim.hv_vis_play(HV_VIS_TAG_KNIFE_VICTIM, list(
			list(victim.pixel_w, victim.pixel_z, tilted, cut_total, LINEAR_EASING),
			list(victim.pixel_w + lurch_dx, victim.pixel_z + lurch_dy, hunched, HV_VIS_KNIFE_HUNCH_IN, QUAD_EASING|EASE_OUT),
			list(victim.pixel_w + lurch_dx, victim.pixel_z + lurch_dy, hunched, HV_VIS_KNIFE_HUNCH_HOLD, LINEAR_EASING),
			list(victim.pixel_w, victim.pixel_z, base, HV_VIS_KNIFE_HUNCH_OUT, SINE_EASING),
		))
	else if(!fell_now)
		victim.hv_vis_knife_t2 = world.time + cut_total
		victim.hv_vis_knife_hunch = 0
		var/matrix/base_lying = matrix(victim.transform)
		var/matrix/tilted_lying = hv_vis_turned(base_lying, victim.hv_vis_knife_tilt, victim.hv_vis_pivot())
		victim.hv_vis_play(HV_VIS_TAG_KNIFE_VICTIM, list(
			list(victim.pixel_w, victim.pixel_z, tilted_lying, cut_total, LINEAR_EASING),
			list(victim.pixel_w, victim.pixel_z, base_lying, HV_VIS_KNIFE_RELEASE_TIME, SINE_EASING),
		))

/// Beat 5: wind-up broke early; ease both bodies straight back to their exact starting poses with no blood.
/obj/item/knife/proc/hv_vis_abort_knife_windup(mob/living/user, mob/living/carbon/victim)
	hv_vis_clear_exec_props()
	if(!QDELETED(user))
		user.hv_vis_release(HV_VIS_TAG_KNIFE_STEP, 2)
	if(!QDELETED(victim))
		victim.hv_vis_knife_clear_pose()
		if(victim.stat != DEAD)
			victim.hv_vis_release(HV_VIS_TAG_KNIFE_VICTIM, 2)
			victim.hv_vis_release(HV_VIS_TAG_TREMBLE, 1)
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
	var/atom/grab_arm = hv_vis_grab_arm_ref?.resolve()
	if(grab_arm && !QDELETED(grab_arm))
		qdel(grab_arm)
	hv_vis_blade_ref = null
	hv_vis_knife_arm_ref = null
	hv_vis_grab_arm_ref = null

// ---- Geometry helpers ----

/// Throat offset list(x, y) from this mob's icon centre when leaned by `angle` degrees clockwise.
/mob/living/proc/hv_vis_throat_for_angle(angle)
	var/base_x = (dir & EAST) ? 3 : ((dir & WEST) ? -4 : 0)
	var/base_y = 6
	var/matrix/pose = hv_vis_turned(matrix(transform), angle, hv_vis_pivot())
	return list(
		round(pose.a * base_x + pose.b * base_y + pose.c, 0.1),
		round(pose.d * base_x + pose.e * base_y + pose.f, 0.1),
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

/// Clockwise tilt angle (degrees) for a standing survivor hunching forward after release.
/mob/living/proc/hv_vis_knife_hunch_tilt()
	if(dir & EAST)
		return HV_VIS_KNIFE_HUNCH_TILT
	if(dir & WEST)
		return -HV_VIS_KNIFE_HUNCH_TILT
	return hv_vis_knife_tilt >= 0 ? -HV_VIS_KNIFE_HUNCH_TILT * 0.6 : HV_VIS_KNIFE_HUNCH_TILT * 0.6

/// Clockwise angle from EAST (0 deg) along which the knife blade points while crossing `victim`'s throat.
/proc/hv_vis_knife_blade_angle(mob/living/victim, knife_zone)
	if(victim.dir & EAST)
		return -15
	if(victim.dir & WEST)
		return 195
	if(victim.dir & NORTH)
		return (knife_zone == BODY_ZONE_R_ARM) ? 180 : 0
	return (knife_zone == BODY_ZONE_R_ARM) ? 0 : 180

/// Pixel offset list(x, y) of `arm_zone`'s hand from `holder`'s icon centre for `holder.dir`.
/proc/hv_vis_local_hand_offset(mob/living/holder, arm_zone)
	var/right_hand = (arm_zone == BODY_ZONE_R_ARM)
	switch(holder.dir)
		if(NORTH)
			return list(right_hand ? 6 : -6, -2)
		if(EAST)
			return list(right_hand ? 1 : 2, -2)
		if(WEST)
			return list(right_hand ? -2 : -1, -2)
	return list(right_hand ? -6 : 6, -2)

/// Pixel offset list(x, y) of `arm_zone`'s shoulder from `holder`'s icon centre for `holder.dir`.
/proc/hv_vis_local_shoulder_offset(mob/living/holder, arm_zone)
	var/right_hand = (arm_zone == BODY_ZONE_R_ARM)
	switch(holder.dir)
		if(NORTH)
			return list(right_hand ? 6 : -6, 5)
		if(EAST)
			return list(right_hand ? -1 : 1, 5)
		if(WEST)
			return list(right_hand ? 1 : -1, 5)
	return list(right_hand ? -6 : 6, 5)

/// Converts `attacker`'s hand position (with optional extra step `step_dx`, `step_dy`) into `victim`'s turf pixel_w/pixel_z frame.
/proc/hv_vis_hand_in_victim_frame(mob/living/attacker, mob/living/victim, arm_zone, step_dx = 0, step_dy = 0)
	var/list/local_hand = hv_vis_local_hand_offset(attacker, arm_zone)
	var/frame_x = (attacker.x - victim.x) * ICON_SIZE_X + (attacker.pixel_x - victim.pixel_x) + attacker.pixel_w + step_dx + local_hand[1]
	var/frame_y = (attacker.y - victim.y) * ICON_SIZE_Y + (attacker.pixel_y - victim.pixel_y) + attacker.pixel_z + step_dy + local_hand[2]
	return list(round(frame_x, 0.1), round(frame_y, 0.1))

/// Converts `attacker`'s shoulder position (with optional extra step `step_dx`, `step_dy`) into `victim`'s turf pixel_w/pixel_z frame.
/proc/hv_vis_shoulder_in_victim_frame(mob/living/attacker, mob/living/victim, arm_zone, step_dx = 0, step_dy = 0)
	var/list/local_shoulder = hv_vis_local_shoulder_offset(attacker, arm_zone)
	var/frame_x = (attacker.x - victim.x) * ICON_SIZE_X + (attacker.pixel_x - victim.pixel_x) + attacker.pixel_w + step_dx + local_shoulder[1]
	var/frame_y = (attacker.y - victim.y) * ICON_SIZE_Y + (attacker.pixel_y - victim.pixel_y) + attacker.pixel_z + step_dy + local_shoulder[2]
	return list(round(frame_x, 0.1), round(frame_y, 0.1))

// ---- Visual props ----

/// Temporary visual copy of the real knife blade drawn at the attacker's hand and across the throat.
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
	pixel_w = start_w
	pixel_z = start_z
	transform = hv_turn_matrix(blade_deg)

/// Matrix orienting this knife's blade along `blade_deg` clockwise from EAST, scaled small enough to read cleanly at the neck.
/obj/effect/temp_visual/hv_knife_exec_blade/proc/hv_turn_matrix(blade_deg)
	var/matrix/turned = matrix()
	turned.Turn(blade_deg - hv_native_icon_angle)
	return turned

/// Temporary forearm + hand prop built from the attacker's real arm bodypart so skin tone and species match.
/obj/effect/temp_visual/hv_knife_exec_arm
	name = "arm"
	icon = 'icons/mob/human/bodyparts_greyscale.dmi'
	icon_state = ""
	plane = GAME_PLANE
	layer = HV_VIS_KNIFE_HAND_LAYER
	appearance_flags = KEEP_TOGETHER
	randomdir = FALSE
	duration = 25

/obj/effect/temp_visual/hv_knife_exec_arm/Initialize(mapload, mob/living/attacker, arm_zone = BODY_ZONE_R_ARM, row_x = 0, row_y = 0, fist_w = 0, fist_z = 0, shoulder_w = 0, shoulder_z = 8, draw_layer = HV_VIS_KNIFE_HAND_LAYER, life = 25)
	if(life > 0)
		duration = life
	. = ..()
	layer = draw_layer
	pixel_x = row_x
	pixel_y = row_y
	pixel_w = fist_w
	pixel_z = fist_z
	hv_build_limb_overlays(attacker, arm_zone)
	transform = hv_aim_arm_matrix(fist_w, fist_z, shoulder_w, shoulder_z)

/// Copies the attacker's real arm and hand overlays shifted so the fist sits at (0, 0) and the forearm runs +y.
/obj/effect/temp_visual/hv_knife_exec_arm/proc/hv_build_limb_overlays(mob/living/attacker, arm_zone)
	if(!iscarbon(attacker))
		return
	var/mob/living/carbon/carbon_attacker = attacker
	var/obj/item/bodypart/arm = carbon_attacker.get_bodypart(arm_zone)
	if(!arm)
		return
	var/shift_x = (arm.body_zone == BODY_ZONE_R_ARM) ? 6 : -6
	var/shift_y = 2
	var/list/limb_layers = arm.get_limb_icon(dropped = FALSE, update_on = carbon_attacker)
	for(var/entry in limb_layers)
		if(!entry)
			continue
		var/mutable_appearance/part = new(entry)
		part.plane = FLOAT_PLANE
		part.layer = FLOAT_LAYER
		part.dir = SOUTH
		part.pixel_w += shift_x
		part.pixel_z += shift_y
		add_overlay(part)

/// Rotates the forearm around the fist at (0, 0) so its shoulder end points back toward (shoulder_w, shoulder_z).
/obj/effect/temp_visual/hv_knife_exec_arm/proc/hv_aim_arm_matrix(fist_w, fist_z, shoulder_w, shoulder_z)
	var/dx = shoulder_w - fist_w
	var/dy = shoulder_z - fist_z
	var/matrix/aimed = matrix()
	if(dx || dy)
		// Forearm art runs straight +y (NORTH, 90 deg CCW from EAST) from the fist at (0, 0).
		aimed.Turn(90 - ATAN2(dx, dy))
	return aimed

/// Animates this forearm's fist to `(target_w, target_z)` while aiming its shoulder back toward `(shoulder_w, shoulder_z)`.
/obj/effect/temp_visual/hv_knife_exec_arm/proc/hv_animate_to(target_w, target_z, shoulder_w, shoulder_z, step_time, step_easing = LINEAR_EASING)
	var/matrix/aimed = hv_aim_arm_matrix(target_w, target_z, shoulder_w, shoulder_z)
	animate(src, pixel_w = target_w, pixel_z = target_z, transform = aimed, time = step_time, easing = step_easing)

/// Animates the arm through Beat 3's cut + hold and Beat 4's retraction back to the attacker's hand, then deletes it.
/obj/effect/temp_visual/hv_knife_exec_arm/proc/hv_animate_cut_and_retract(cut_w, cut_z, shoulder_in_w, shoulder_in_z, home_w, home_z, shoulder_home_w, shoulder_home_z)
	var/matrix/cut_aim = hv_aim_arm_matrix(cut_w, cut_z, shoulder_in_w, shoulder_in_z)
	var/matrix/home_aim = hv_aim_arm_matrix(home_w, home_z, shoulder_home_w, shoulder_home_z)
	animate(src, pixel_w = cut_w, pixel_z = cut_z, transform = cut_aim, time = HV_VIS_KNIFE_CUT_TIME, easing = QUAD_EASING|EASE_OUT)
	animate(pixel_w = cut_w, pixel_z = cut_z, transform = cut_aim, time = HV_VIS_KNIFE_CUT_HOLD, easing = LINEAR_EASING)
	animate(pixel_w = home_w, pixel_z = home_z, transform = home_aim, time = HV_VIS_KNIFE_RELEASE_TIME, easing = SINE_EASING, alpha = 0)
	QDEL_IN(src, HV_VIS_KNIFE_CUT_TIME + HV_VIS_KNIFE_CUT_HOLD + HV_VIS_KNIFE_RELEASE_TIME)

/// On-body jet of blood spurting directly out of the victim's drawn throat in the direction they face.
/obj/effect/temp_visual/hv_throat_spurt
	name = "arterial spray"
	icon = HV_BLOOD_SPRAY_ICON
	icon_state = "squirt_greyscale"
	plane = GAME_PLANE
	layer = ABOVE_MOB_LAYER
	randomdir = FALSE
	duration = 4

/obj/effect/temp_visual/hv_throat_spurt/Initialize(mapload, row_x = 0, row_y = 0, throat_w = 0, throat_z = 0, spray_dir = SOUTH, draw_layer = ABOVE_MOB_LAYER, blood_color = BLOOD_COLOR_RED, strength = 3)
	. = ..()
	setDir(spray_dir || SOUTH)
	layer = draw_layer
	color = blood_color
	pixel_x = row_x
	pixel_y = row_y
	pixel_w = throat_w
	pixel_z = throat_z

	var/dx = HV_VIS_DX(dir)
	var/dy = HV_VIS_DY(dir)
	var/reach = 8 + strength * 3
	var/matrix/start = matrix()
	start.Scale(0.28, 0.28)
	transform = start

	var/matrix/end_mat = matrix()
	end_mat.Scale(0.55 + strength * 0.12, 0.55 + strength * 0.12)
	animate(
		src,
		pixel_w = round(throat_w + dx * reach, 0.1),
		pixel_z = round(throat_z + dy * reach, 0.1),
		transform = end_mat,
		alpha = 0,
		time = duration,
		easing = QUAD_EASING|EASE_OUT,
	)
