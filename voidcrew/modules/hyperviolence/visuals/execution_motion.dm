// The Sandevistan replay plays a move again: animate() here is journaled for it (cyberware/ware_sandy_replay.dm).
#define animate(arguments...) sandy_replay_animate(arguments)

// Hyperviolence visuals: gun executions (overlays_exec/executions.dm).
// 17. The press: the shooter leans in over the victim with the barrel on the head (execution_aim.dm), the
//     victim trembles, and both go still for a short, deliberate moment before the shot. The shot: a big
//     muzzle flash at the barrel's end, the gun kicks and the shooter rocks back from it, a hit-stop on the
//     victim, and a burst head throws its gibs in arcs (flying_gore.dm). The body holds for a beat, then
//     slumps forward along the shot (death_falls.dm). Then the shooter lowers the gun and straightens up.
// The press is only drawn over the wind-up the execution already has; nothing here changes its timing.

/obj/item/gun/hv_start_execution(mob/living/user, mob/living/target, params)
	// The same checks that stop the wind-up before it starts.
	var/pressing = !fire_cd && !firing_burst && !HAS_TRAIT(user, TRAIT_PACIFISM) && isturf(user.loc) && isturf(target.loc)
	var/datum/hv_exec_aim/aim
	if(pressing)
		user.face_atom(target)
		// He is drawn with the gun on the head (execution_aim.dm); one who can't be only leans in.
		QDEL_NULL(hv_aim)
		aim = new(src, user, target)
		if(aim.raise())
			hv_aim = aim
		else
			QDEL_NULL(aim)
			user.hv_vis_press_in(target, HV_EXECUTION_WINDUP)
		target.hv_vis_tremble(HV_EXECUTION_WINDUP - HV_VIS_PRESS_PAUSE, 1)
	. = ..()
	if(!pressing)
		return
	// Called off, the shooter straightens up at once. Having fired he holds the lean through the flash and the burst:
	// straightening on the shot's own tick, he stood idle while the head went off beside him.
	if(aim)
		// The shot's recoil ends in the gun coming down (hv_fire_execution()); anything else lowers it now
		if(!QDELETED(aim) && !aim.down_timer)
			aim.lower()
	else if(!QDELETED(user))
		if(.)
			addtimer(CALLBACK(user, TYPE_PROC_REF(/atom, hv_vis_release), HV_VIS_TAG_PRESS, 1.5), 0.4 SECONDS)
		else
			user.hv_vis_release(HV_VIS_TAG_PRESS, 1.5)
	if(!QDELETED(target) && target.stat != DEAD)
		target.hv_vis_release(HV_VIS_TAG_TREMBLE, 1)

/obj/item/gun/hv_fire_execution(mob/living/user, mob/living/target, params)
	// Where the barrel is: against the head, wherever that is on a body on its feet or on the floor.
	// Read before the shot, which can drop the body or take the head off.
	var/turf/head_turf
	var/list/head_at
	var/behind_head = FALSE
	if(!QDELETED(target))
		target.hv_vis_execution_time = world.time
		head_turf = get_turf(target)
		head_at = target.hv_vis_head_offset()
		// A shot from the far side of someone on their feet goes off behind their head.
		behind_head = target.body_position == STANDING_UP && (get_dir(user, target) & SOUTH)
	. = ..()
	if(!. || QDELETED(user))
		return
	// With the gun drawn on the head the flash is at its barrel's end, and the gun kicks
	var/datum/hv_exec_aim/aim = hv_aim?.is_up() ? hv_aim : null
	hv_vis_muzzle_flash(user, head_turf || target, head_at, behind_head, aim)
	aim?.recoil()
	if(!QDELETED(target))
		target.hv_vis_big_hit(get_dir(user, target), user)

/// Where this mob's head is drawn, in pixels from the middle of its tile: list(x, y).
/mob/living/proc/hv_vis_head_offset()
	return list(0, 8 * current_size)

/mob/living/carbon/hv_vis_head_offset()
	return hv_vis_part_offset(BODY_ZONE_HEAD)

/// Leans in toward `target` and stays there for `hold`, as if pressing something to their head.
/mob/living/proc/hv_vis_press_in(atom/target, hold)
	var/toward = get_dir(src, target)
	var/dx = HV_VIS_DX(toward) * HV_VIS_PRESS_LEAN
	var/dy = HV_VIS_DY(toward) * HV_VIS_PRESS_LEAN
	var/matrix/base = matrix(transform)
	var/matrix/hunched = hv_vis_turned(base, HV_VIS_DX(toward) * 6, hv_vis_pivot())
	hv_vis_play(HV_VIS_TAG_PRESS, list(
		list(pixel_w + dx, pixel_z + dy, hunched, 4, SINE_EASING),
		list(pixel_w + dx, pixel_z + dy, hunched, hold + 1 SECONDS, LINEAR_EASING),
		list(pixel_w, pixel_z, base, 3, SINE_EASING),
	))

/// Shakes with fear for `duration`, small quick jerks side to side. `strength` in pixels.
/mob/living/proc/hv_vis_tremble(duration, strength = 1)
	if(duration <= 0 || !isturf(loc))
		return
	var/matrix/base = matrix(transform)
	var/loops = max(1, round(duration / 2))
	var/base_w = pixel_w
	var/base_z = pixel_z
	// Slower in a Sandevistan field (cyberware/ware_sandy_timestop.dm).
	var/list/real = cyberware_dilated_steps(src, list(0.5, 1, 0.5), loops) || list(0.5, 1, 0.5)
	animate(src, pixel_w = base_w + strength, pixel_z = base_z, transform = base, time = real[1], loop = loops, tag = HV_VIS_TAG_TREMBLE)
	animate(pixel_w = base_w - strength, pixel_z = base_z, transform = base, time = real[2])
	animate(pixel_w = base_w, pixel_z = base_z, transform = base, time = real[3])

/**
 * A muzzle flash bigger than a normal shot's, with a flash of light. It is where the barrel's end is: where
 * `aim` draws it (execution_aim.dm), turned the way the barrel points; without one, just short of the head it
 * is pressed to, `head_at` pixels from the middle of the target's tile (list(x, y)). It stands on the target's
 * tile, so it sorts with the target: a shooter standing nearer the camera than the victim is drawn over it, as
 * their body is between us and the gun. `behind_target` draws it under the target too: the barrel is on the far
 * side of their head.
 */
/proc/hv_vis_muzzle_flash(mob/living/shooter, atom/target, list/head_at, behind_target = FALSE, datum/hv_exec_aim/aim)
	var/turf/shooter_turf = get_turf(shooter)
	var/turf/spot = get_turf(target) || shooter_turf
	if(!shooter_turf || !spot)
		return
	var/shot_dir = get_dir(shooter_turf, spot) || shooter.dir
	var/list/barrel_end
	var/turn = 0
	if(aim)
		barrel_end = aim.muzzle_from(spot)
		shot_dir = abs(aim.aim_x) >= abs(aim.aim_y) ? (aim.aim_x >= 0 ? EAST : WEST) : (aim.aim_y >= 0 ? NORTH : SOUTH)
		// The flash's picture points along its facing; the rest of the way to the barrel's line it is turned
		turn = aim.barrel_turn + 90 - dir2angle(shot_dir)
		while(turn > 180)
			turn -= 360
		while(turn < -180)
			turn += 360
	else
		barrel_end = list((head_at ? head_at[1] : 0) - HV_VIS_DX(shot_dir) * HV_VIS_FLASH_SHORT, (head_at ? head_at[2] : 0) - HV_VIS_DY(shot_dir) * HV_VIS_FLASH_SHORT)
	new /obj/effect/temp_visual/hv_muzzle_flash(spot, shot_dir, barrel_end, behind_target, turn)
	shooter_turf.flash_lighting_fx(3, 2, LIGHT_COLOR_ORANGE, 2)

/// The flash is one still picture, tg's muzzle flash at its brightest, grown and faded here. tg's own
/// state is a short loop that every flash on screen plays in step, so a flash borrowed from it began
/// on whatever frame the loop had reached: sometimes the bright one, sometimes the last few sparks.
/obj/effect/temp_visual/hv_muzzle_flash
	name = "muzzle flash"
	icon = 'voidcrew/modules/hyperviolence/overlays_exec/icons/muzzle_flash.dmi'
	icon_state = "flash"
	plane = GAME_PLANE
	layer = ABOVE_MOB_LAYER
	randomdir = FALSE
	duration = 4

/// `barrel_end` is where the barrel ends, in pixels from the middle of this tile (list(x, y)); `turn` the degrees
/// clockwise the barrel's line is off the flash's facing.
/obj/effect/temp_visual/hv_muzzle_flash/Initialize(mapload, shot_dir, list/barrel_end, behind_target = FALSE, turn = 0)
	. = ..()
	if(behind_target)
		layer = BELOW_MOB_LAYER
	setDir(shot_dir || SOUTH)
	// tg's flash art sits off the middle of its tile, toward the way it faces. It grows and turns about that
	// point, and that point goes at the end of the barrel.
	var/core_w = HV_VIS_DX(dir) * HV_VIS_FLASH_CORE
	var/core_z = HV_VIS_DY(dir) * HV_VIS_FLASH_CORE
	pixel_w = round((barrel_end ? barrel_end[1] : 0) - core_w)
	pixel_z = round((barrel_end ? barrel_end[2] : 0) - core_z)
	transform = hv_vis_scaled_about(1.7, core_w, core_z, turn)
	animate(src, transform = hv_vis_scaled_about(2.3, core_w, core_z, turn), alpha = 0, time = duration, easing = QUAD_EASING|EASE_OUT)

/// A matrix that scales by `scale` and turns `turn` degrees clockwise about the point (x, y) pixels from the middle of the icon.
/proc/hv_vis_scaled_about(scale, x, y, turn = 0)
	var/matrix/scaled = matrix()
	scaled.Translate(-x, -y)
	scaled.Scale(scale)
	if(turn)
		scaled.Turn(turn)
	scaled.Translate(x, y)
	return scaled

#undef animate
