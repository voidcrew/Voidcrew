// tg floors a standing body by laying it down and then picking the side it lies on. For a carbon, lying down
// has already picked a side (lying_angle_on_lying_down()), so the side was picked twice, and half the time the
// second pick was the other one. update_transform() applies a turn straight onto the other side with no tween,
// so half of all knockdowns went flat in a single frame instead of falling. Here the first pick is kept.
// Found on the Mantis lunge's landing (voidcrew/modules/mantis_gore/), true of every knockdown.
/mob/living/carbon/on_floored_start()
	on_fall()
	if(body_position != STANDING_UP)
		return
	set_body_position(LYING_DOWN)
	// Still upright only if lying down picked nothing: buckled upright, or unable to lie down.
	if(!lying_angle)
		set_lying_angle(pick(LYING_ANGLE_EAST, LYING_ANGLE_WEST))
