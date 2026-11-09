// Hyperviolence visuals: gun executions (overlays_exec/executions.dm).
// 17. The press: the shooter leans in over the victim, the victim trembles, and both go still for a
//     short, deliberate moment before the shot. The shot: a big muzzle flash, a hit-stop on both, and
//     a burst head throws its gibs in arcs (flying_gore.dm). The body holds for a beat, then slumps
//     forward along the shot (death_falls.dm).
// The press is only drawn over the wind-up the execution already has; nothing here changes its timing.

/obj/item/gun/hv_start_execution(mob/living/user, mob/living/target, params)
	// The same checks that stop the wind-up before it starts.
	var/pressing = !fire_cd && !firing_burst && !HAS_TRAIT(user, TRAIT_PACIFISM) && isturf(user.loc) && isturf(target.loc)
	if(pressing)
		user.hv_vis_press_in(target, HV_EXECUTION_WINDUP)
		target.hv_vis_tremble(HV_EXECUTION_WINDUP - HV_VIS_PRESS_PAUSE, 1)
	. = ..()
	if(!pressing)
		return
	// Shot or called off, the shooter straightens up.
	if(!QDELETED(user))
		user.hv_vis_release(HV_VIS_TAG_PRESS, 1.5)
	if(!QDELETED(target) && target.stat != DEAD)
		target.hv_vis_release(HV_VIS_TAG_TREMBLE, 1)

/obj/item/gun/hv_fire_execution(mob/living/user, mob/living/target, params)
	if(!QDELETED(target))
		target.hv_vis_execution_time = world.time
	. = ..()
	if(!. || QDELETED(user))
		return
	hv_vis_muzzle_flash(user, target)
	if(!QDELETED(target))
		target.hv_vis_big_hit(get_dir(user, target), user)

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
	animate(src, pixel_w = base_w + strength, pixel_z = base_z, transform = base, time = 0.5, loop = loops, tag = HV_VIS_TAG_TREMBLE)
	animate(pixel_w = base_w - strength, pixel_z = base_z, transform = base, time = 1)
	animate(pixel_w = base_w, pixel_z = base_z, transform = base, time = 0.5)

/// A muzzle flash much bigger than a normal shot's, with a flash of light.
/proc/hv_vis_muzzle_flash(mob/living/shooter, atom/target)
	var/turf/spot = get_turf(shooter)
	if(!spot)
		return
	new /obj/effect/temp_visual/hv_muzzle_flash(spot, get_dir(shooter, target) || shooter.dir)
	spot.flash_lighting_fx(3, 2, LIGHT_COLOR_ORANGE, 2)

/obj/effect/temp_visual/hv_muzzle_flash
	name = "muzzle flash"
	icon = 'icons/effects/effects.dmi'
	icon_state = "firing_effect"
	plane = GAME_PLANE
	layer = ABOVE_MOB_LAYER
	randomdir = FALSE
	duration = 4

/obj/effect/temp_visual/hv_muzzle_flash/Initialize(mapload, shot_dir)
	. = ..()
	setDir(shot_dir || SOUTH)
	// At the end of the barrel, between the two of them.
	pixel_w = HV_VIS_DX(dir) * 14
	pixel_z = HV_VIS_DY(dir) * 14
	var/matrix/big = matrix()
	big.Scale(2.2)
	transform = big
	var/matrix/bigger = matrix()
	bigger.Scale(2.8)
	animate(src, transform = bigger, alpha = 0, time = duration, easing = QUAD_EASING|EASE_OUT)
