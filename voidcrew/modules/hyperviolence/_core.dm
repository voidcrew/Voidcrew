// Hyperviolence core: the shared hooks every gore part uses.
// hv_add_hit_line() (a line added to the combat message of the hit being resolved on a mob) lives
// in hitlines/hit_lines.dm, which batches the lines into the attack message.

/// Sprays blood from src toward spray_dir: streaks and a splash on the floor, a smear on the first
/// wall in the way, and anyone standing in the line is drenched. The body lives in the blood part
/// (blood/blood_spray.dm).
/mob/living/proc/hv_blood_spray(spray_dir, strength = 3)
	return hv_blood_throw(spray_dir, strength)

/// Bursts src's head: it comes apart in gibs and the brain is thrown out intact. burst_dir is the way
/// the shot or blow travelled. The body is in braingut/brain_burst.dm.
/// Returns TRUE if the head was burst.
/mob/living/carbon/proc/hv_burst_head(burst_dir)
	return hv_burst_head_apart(burst_dir)

/// Sends a loose part (a severed limb or head, a brain, an eye) up to `distance` tiles along `fling_dir`,
/// tumbling, and calls `on_landed` when it comes to rest. Never tg's throw: a thrown part hurts and shoves
/// whoever it hits, and can be caught. `from` is where on its tile it comes from, in pixels from the
/// middle (list(x, y)): the head an eye is torn out of, say. Without it the part starts from the middle.
/// The body is in visuals/flying_gore.dm. Returns TRUE if it took off.
/obj/item/proc/hv_fling(fling_dir, distance = 2, datum/callback/on_landed, list/from)
	if(from && !hv_vis_fling_from)
		hv_vis_fling_from = from
	return hv_vis_fly(fling_dir, distance, on_landed)

/**
 * A body shudders as it dies. With `rise` (a body that has just fallen) it is first drawn upright over
 * its lying pose, seizing, then falls the way tg lays a body down. Human NPCs give it from their death
 * signal (human_npcs/human_npc_barks.dm), after tg's own deathgasp. Every step is relative and ends where
 * it began, so the body's real transform and offsets are untouched.
 */
/mob/living/proc/hv_death_throes(rise = FALSE)
	// How far it is turned now: tg lays a body down by turning it.
	var/angle = round(arctan(transform.a, transform.b))
	if(rise && angle)
		var/matrix/fallen = matrix(transform)
		var/matrix/upright = matrix(transform)
		upright.Turn(-angle)
		// In a Sandevistan field (cyberware/ware_sandy_timestop.dm) it holds through the freeze and runs slow.
		var/list/real = cyberware_dilated_steps(src, list(HV_DEATH_THROES_TIME, UPDATE_TRANSFORM_ANIMATION_TIME)) || list(0, HV_DEATH_THROES_TIME, UPDATE_TRANSFORM_ANIMATION_TIME)
		animate(src, transform = upright, time = 0)
		animate(transform = upright, time = real[1] + real[2])
		animate(transform = fallen, time = real[3], easing = EASE_IN|EASE_OUT)
	// The shudder: sideways offsets that die down, each step relative to the last, ending where it began.
	var/static/list/shudder = list(3, -3, 2, -2, 2, -1, 1, 0)
	var/step_time = HV_DEATH_THROES_TIME / length(shudder)
	var/list/shudder_times = list()
	for(var/i in 1 to length(shudder))
		shudder_times += step_time
	var/list/shudder_real = cyberware_dilated_steps(src, shudder_times)
	if(shudder_real && shudder_real[1] > 0)
		animate(src, pixel_w = 0, time = shudder_real[1], flags = ANIMATION_RELATIVE|ANIMATION_PARALLEL)
	var/offset = 0
	for(var/i in 1 to length(shudder))
		var/shift = shudder[i] - offset
		offset = shudder[i]
		var/time = shudder_real ? shudder_real[i + 1] : step_time
		if(i == 1 && !(shudder_real && shudder_real[1] > 0))
			animate(src, pixel_w = shift, time = time, flags = ANIMATION_RELATIVE|ANIMATION_PARALLEL)
		else
			animate(pixel_w = shift, time = time, flags = ANIMATION_RELATIVE)
