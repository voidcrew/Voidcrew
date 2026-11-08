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
		animate(src, transform = upright, time = 0)
		animate(transform = upright, time = HV_DEATH_THROES_TIME)
		animate(transform = fallen, time = UPDATE_TRANSFORM_ANIMATION_TIME, easing = EASE_IN|EASE_OUT)
	// The shudder: sideways offsets that die down, each step relative to the last, ending where it began.
	var/static/list/shudder = list(3, -3, 2, -2, 2, -1, 1, 0)
	var/step_time = HV_DEATH_THROES_TIME / length(shudder)
	var/offset = 0
	for(var/i in 1 to length(shudder))
		var/shift = shudder[i] - offset
		offset = shudder[i]
		if(i == 1)
			animate(src, pixel_w = shift, time = step_time, flags = ANIMATION_RELATIVE|ANIMATION_PARALLEL)
		else
			animate(pixel_w = shift, time = step_time, flags = ANIMATION_RELATIVE)
