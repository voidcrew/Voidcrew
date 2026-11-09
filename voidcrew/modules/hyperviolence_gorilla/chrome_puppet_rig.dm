/**
 * # The puppet rig ("arm rig")
 *
 * tg bodies have no poses, so a chrome finisher that needs a real arm swing, a body held up by the
 * collar or folded over a knee draws one: the real body is hidden for a few seconds and stand-ins
 * ("puppets") cut from one flat picture of it are posed in its place.
 *
 * - One getFlatIcon() of the body, facing the way the finisher needs, at the start.
 * - The picture is cut with masks drawn from tg's human base sprite (gorilla_gore.dmi, rig_*): the arms
 *   (with their sleeves, gloves and chrome, whatever is worn), the body without one or both arms, and
 *   the upper and lower halves at the belt. In a side view the near arm covers the torso, so the torso
 *   under it is filled from the torso just beside it.
 * - Each puppet is a plain object on the body's tile, posed with its own transform and offsets, so
 *   nothing ever touches the real body's transform, offsets or layer; tg's lying turn, grab offsets and
 *   height filters stay right. A puppet turns about a pivot (a shoulder, the belt) with chrome_rig_turn().
 * - The real body is hidden with a colour filter, and made clickable over its whole tile while hidden,
 *   so the crew can still click the body to stop it. Puppets never take clicks.
 * - Off: the filter and the click area come back and every puppet is deleted. That happens when the rig
 *   is deleted, which its owner does on every way a finisher ends, and which the rig does itself if the
 *   body is deleted.
 *
 * A body whose flat picture isn't 32x32 (something huge worn or held) gets no rig: the move still
 * happens, just without the poses.
 */

/// Mask states and pivots below are for tg's human base body, medium height.
#define CHROME_RIG_HIDE_FILTER "chrome_rig_hide"

/**
 * Shoulder pivots (pixels from the icon's centre, x right, y up) per facing, from the human base
 * sprite. list(dir = list(left_x, left_y, right_x, right_y)).
 */
GLOBAL_LIST_INIT(chrome_rig_shoulders, list(
	"[SOUTH]" = list(4, 4, -6, 4),
	"[NORTH]" = list(-6, 4, 4, 4),
	"[EAST]" = list(-4, 2, -4, 2),
	"[WEST]" = list(4, 2, 4, 2),
))

/// Pixels from a shoulder pivot to the fist on a hanging arm, per facing.
GLOBAL_LIST_INIT(chrome_rig_arm_length, list(
	"[SOUTH]" = 10,
	"[NORTH]" = 10,
	"[EAST]" = 7,
	"[WEST]" = 7,
))

/// The lowest pixel row (from the bottom, 1-based) of a human head; the neck is under it.
#define CHROME_RIG_NECK_Y 23
/// The middle of the head, from the icon's centre.
#define CHROME_RIG_HEAD_PIVOT_Y 9

/// Most degrees an arm turns in one animation step.
#define CHROME_RIG_SWING_STEP 12
/// The shortest an arm is drawn, as a share of its length.
#define CHROME_RIG_MIN_ARM_LENGTH 0.4

/// Where the torso under a side view's near arm is filled from: a pixel takes the one this far behind
/// it along x (negative: from in front). list(dir = shift).
GLOBAL_LIST_INIT(chrome_rig_fill_shift, list(
	"[EAST]" = -4,
	"[WEST]" = 4,
))

/**
 * A matrix turning a puppet by [angle] (clockwise) about [pivot_x], [pivot_y] (pixels from the centre),
 * then moving it by [shift_x], [shift_y].
 */
/proc/chrome_rig_turn(angle, pivot_x = 0, pivot_y = 0, shift_x = 0, shift_y = 0, scale_x = 1, scale_y = 1)
	var/matrix/turned = matrix()
	turned.Translate(-pivot_x, -pivot_y)
	if(scale_x != 1 || scale_y != 1)
		turned.Scale(scale_x, scale_y)
	turned.Turn(angle)
	turned.Translate(pivot_x + shift_x, pivot_y + shift_y)
	return turned

/// One stand-in picture on a hidden body's tile.
/obj/effect/abstract/chrome_puppet
	name = "body"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	appearance_flags = PIXEL_SCALE | TILE_BOUND | LONG_GLIDE
	plane = GAME_PLANE
	layer = MOB_LAYER
	vis_flags = NONE

/// Hides a body and stands puppets in its place.
/datum/chrome_rig
	/// The hidden body
	var/mob/living/body
	/// The flat picture puppets are cut from
	var/icon/flat
	/// The facing the picture was taken in
	var/facing
	/// Key -> /obj/effect/abstract/chrome_puppet
	var/list/puppets = list()
	/// The body's click area before it was hidden
	var/old_mouse_opacity
	/// TRUE while the body is hidden
	var/hidden = FALSE
	/// Side -> list(turn, length) the arm was last sent to
	var/list/arm_poses = list()

/datum/chrome_rig/New(mob/living/body, facing)
	. = ..()
	src.body = body
	src.facing = facing || body.dir
	if(!(src.facing in GLOB.cardinals))
		src.facing = (src.facing & (EAST|WEST)) || SOUTH
	RegisterSignal(body, COMSIG_QDELETING, PROC_REF(on_body_deleted))

/datum/chrome_rig/Destroy()
	reveal()
	for(var/key in puppets)
		qdel(puppets[key])
	puppets = null
	if(body)
		UnregisterSignal(body, COMSIG_QDELETING)
	body = null
	flat = null
	return ..()

/datum/chrome_rig/proc/on_body_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// Takes the flat picture. Returns FALSE if the body can't be rigged (gone, or not a 32x32 picture).
/datum/chrome_rig/proc/snapshot()
	if(QDELETED(body) || !isturf(body.loc))
		return FALSE
	var/icon/picture = getFlatIcon(body, facing, no_anim = TRUE)
	if(!picture || picture.Width() != ICON_SIZE_X || picture.Height() != ICON_SIZE_Y)
		return FALSE
	flat = picture
	return TRUE

/// A copy of the flat picture cut by [mask_state] (white keeps, clear cuts) from the rig masks.
/datum/chrome_rig/proc/cut(mask_state)
	var/icon/piece = icon(flat)
	piece.Blend(icon(GORILLA_GORE_ICON, mask_state, facing), ICON_MULTIPLY)
	return piece

/// The flat picture with the arm on [side] ("l", "r" or "both") cut out, the torso under it filled.
/datum/chrome_rig/proc/cut_without_arms(side = "both")
	var/icon/piece = cut(side == "both" ? "rig_keep" : "rig_keep_[side]")
	var/shift = GLOB.chrome_rig_fill_shift["[facing]"]
	if(!shift)
		return piece
	for(var/fill_side in (side == "both" ? list("l", "r") : list(side)))
		var/icon/fill = icon(flat)
		fill.Shift(shift > 0 ? EAST : WEST, abs(shift))
		fill.Blend(icon(GORILLA_GORE_ICON, "rig_fill_[fill_side]", facing), ICON_MULTIPLY)
		piece.Blend(fill, ICON_OVERLAY)
	return piece

/// The flat picture above the neck (the head, with its hair and hat) if [head], else below it.
/datum/chrome_rig/proc/cut_at_neck(head = TRUE)
	var/icon/piece = icon(flat)
	if(head)
		piece.DrawBox(null, 1, 1, ICON_SIZE_X, CHROME_RIG_NECK_Y - 1)
	else
		piece.DrawBox(null, 1, CHROME_RIG_NECK_Y, ICON_SIZE_X, ICON_SIZE_Y)
	return piece

/// Hides the real body. Its whole tile still takes clicks.
/datum/chrome_rig/proc/conceal()
	if(hidden || QDELETED(body))
		return
	hidden = TRUE
	old_mouse_opacity = body.mouse_opacity
	body.mouse_opacity = MOUSE_OPACITY_OPAQUE
	body.add_filter(CHROME_RIG_HIDE_FILTER, 1, color_matrix_filter(list(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0)))

/// Shows the real body again.
/datum/chrome_rig/proc/reveal()
	if(!hidden)
		return
	hidden = FALSE
	if(QDELETED(body))
		return
	body.mouse_opacity = old_mouse_opacity
	body.remove_filter(CHROME_RIG_HIDE_FILTER)

/**
 * Stands a puppet showing [picture] on the body's tile under [key], replacing any under that key.
 * It starts where the body is drawn now: the body's offsets and, with [copy_transform], its transform.
 */
/datum/chrome_rig/proc/add_puppet(key, icon/picture, copy_transform = FALSE, puppet_layer)
	var/turf/spot = get_turf(body)
	if(isnull(spot))
		return null
	qdel(puppets[key])
	var/obj/effect/abstract/chrome_puppet/puppet = new(spot)
	puppet.name = body.name
	puppet.icon = picture
	puppet.dir = SOUTH
	puppet.pixel_x = body.pixel_x
	puppet.pixel_y = body.pixel_y
	puppet.pixel_w = body.pixel_w
	puppet.pixel_z = body.pixel_z
	puppet.layer = puppet_layer || body.layer
	if(copy_transform)
		puppet.transform = body.transform
	puppets[key] = puppet
	return puppet

/// The puppet under [key], or null.
/datum/chrome_rig/proc/puppet(key)
	return puppets?[key]

/// Deletes the puppet under [key].
/datum/chrome_rig/proc/drop_puppet(key)
	var/obj/effect/abstract/chrome_puppet/puppet = puppets?[key]
	if(puppet)
		puppets -= key
		qdel(puppet)

/// The pivot of the shoulder on [side] ("l" or "r") in this rig's facing.
/datum/chrome_rig/proc/shoulder(side)
	var/list/pivots = GLOB.chrome_rig_shoulders["[facing]"]
	return side == "l" ? list(pivots[1], pivots[2]) : list(pivots[3], pivots[4])

/**
 * Which way the arm on [side] turns to come up and out from the body: clockwise (1) or anticlockwise
 * (-1). In a side view both arms come up toward the facing.
 */
/datum/chrome_rig/proc/raise_sign(side)
	switch(facing)
		if(SOUTH)
			return side == "r" ? 1 : -1
		if(NORTH)
			return side == "l" ? 1 : -1
		if(EAST)
			return -1
		if(WEST)
			return 1
	return 1

/**
 * Builds the standard bearer rig: the body without arms and both arms on their own puppets. Hides the
 * real body. Returns TRUE if it is up.
 */
/datum/chrome_rig/proc/rig_arms()
	if(!snapshot())
		return FALSE
	add_puppet("body", cut_without_arms("both"))
	// The far arm in a side view sits under the body; the near one over it.
	var/near = near_side()
	for(var/side in list("l", "r"))
		var/side_view = (facing in list(EAST, WEST))
		var/icon/picture = cut("rig_arm_[side]")
		if(side_view && side != near)
			// The far arm is hidden behind the body in a side view, so its cut is empty: draw it as the
			// near arm, a pixel further back and in shadow, so a raised pair reads as two arms.
			picture = cut("rig_arm_[near]")
			picture.Shift(facing == EAST ? WEST : EAST, 1)
			picture.Blend(rgb(170, 170, 178), ICON_MULTIPLY)
		var/obj/effect/abstract/chrome_puppet/arm = add_puppet("arm_[side]", picture)
		// Seen from the front or back both arms are over the body
		arm.layer = (!side_view || side == near) ? body.layer + 0.01 : body.layer - 0.01
	conceal()
	return TRUE

/// The arm nearer the viewer in a side view ("l" or "r"); the right arm in other views.
/datum/chrome_rig/proc/near_side()
	return facing == WEST ? "l" : "r"

/**
 * Turns the arm on [side] to [angle] degrees up from hanging (0) over [time]. [reach] pixels of piston
 * push the fist out along the arm (negative pulls it in, as an arm reaching toward the viewer looks
 * shorter). The arm stretches or shortens from the shoulder, so its top never leaves the shoulder.
 *
 * BYOND blends the move part of a turned matrix in a straight line, which would carry the shoulder off
 * its pivot halfway through a big swing, so a swing is cut into steps of a few degrees.
 */
/datum/chrome_rig/proc/swing_arm(side, angle, time, reach = 0, easing = SINE_EASING)
	var/obj/effect/abstract/chrome_puppet/arm = puppet("arm_[side]")
	if(!arm)
		return
	var/list/pivot = shoulder(side)
	var/list/from = arm_poses[side] || list(0, 1)
	var/to_turn = angle * raise_sign(side)
	var/to_length = max(CHROME_RIG_MIN_ARM_LENGTH, 1 + reach / (GLOB.chrome_rig_arm_length["[facing]"] || 10))
	arm_poses[side] = list(to_turn, to_length)
	var/steps = max(1, CEILING(abs(to_turn - from[1]) / CHROME_RIG_SWING_STEP, 1))
	var/step_time = time / steps
	for(var/i in 1 to steps)
		// Sine in and out across the whole swing; each step itself is straight
		var/progress = (easing & SINE_EASING) ? (1 - cos(180 * i / steps)) / 2 : i / steps
		var/matrix/pose = chrome_rig_turn(from[1] + (to_turn - from[1]) * progress, pivot[1], pivot[2], 0, 0, 1, from[2] + (to_length - from[2]) * progress)
		if(i == 1)
			animate(arm, transform = pose, time = step_time)
		else
			animate(transform = pose, time = step_time)

/**
 * The body crouches over [time]: squashed to [squash] of its height and dropped [drop] pixels, the arms
 * coming down with their shoulders. 1 and 0 stand it back up.
 */
/datum/chrome_rig/proc/crouch(squash, drop, time, easing = SINE_EASING)
	var/obj/effect/abstract/chrome_puppet/body_puppet = puppet("body")
	if(body_puppet)
		animate(body_puppet, transform = matrix(1, 0, 0, 0, squash, -drop), time = time, easing = easing)
	for(var/side in list("l", "r"))
		var/obj/effect/abstract/chrome_puppet/arm = puppet("arm_[side]")
		if(!arm)
			continue
		// Where the squashed body puts this shoulder
		var/list/pivot = shoulder(side)
		animate(arm, pixel_z = round(pivot[2] * squash - drop - pivot[2]), time = time, easing = easing, flags = ANIMATION_PARALLEL)

/// Every puppet trembles a pixel for [time].
/datum/chrome_rig/proc/tremble(time = 0.4 SECONDS)
	for(var/key in puppets)
		var/obj/effect/abstract/chrome_puppet/puppet = puppets[key]
		for(var/i in 1 to max(1, round(time / (0.1 SECONDS))))
			var/step = (i % 2) ? 1 : -1
			if(i == 1)
				animate(puppet, pixel_w = step, time = 0.05 SECONDS, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
			else
				animate(pixel_w = step * 2, time = 0.05 SECONDS, flags = ANIMATION_RELATIVE)
			animate(pixel_w = -step, time = 0.05 SECONDS, flags = ANIMATION_RELATIVE)

/// Every puppet flashes white and fades back.
/datum/chrome_rig/proc/flash()
	for(var/key in puppets)
		cyberware_flash_fx(puppets[key], 0.2 SECONDS)

#undef CHROME_RIG_HIDE_FILTER
#undef CHROME_RIG_SWING_STEP
#undef CHROME_RIG_MIN_ARM_LENGTH
