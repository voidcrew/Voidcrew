/**
 * # The puppet rig ("arm rig")
 *
 * tg bodies have no poses, so a chrome finisher that needs a real arm swing, a body held up by the
 * collar or folded over a knee draws one: the real body is hidden for a few seconds and stand-ins
 * ("puppets") cut from one flat picture of it are posed in its place.
 *
 * - One getFlatIcon() of the body, facing the way the finisher needs, at the start. Whatever tg draws on the
 *   hidden body after that (blood on its clothes, a stump) is hidden with it, so a move that bloodies or
 *   wounds a rigged body takes the picture again at that moment (snapshot(), redraw_arms()).
 * - The picture is cut with masks drawn from tg's human base sprite (gorilla_gore.dmi, rig_*): the arms
 *   (with their sleeves, gloves and chrome, whatever is worn), the body without one or both arms, and
 *   the upper and lower halves at the belt. In a side view the near arm covers the torso, so the torso
 *   under it is filled from the torso just beside it.
 * - Each puppet is a plain object on the body's tile, posed with its own transform and offsets, so
 *   nothing ever touches the real body's transform, offsets or layer; tg's lying turn, grab offsets and
 *   height filters stay right. A puppet turns about a pivot (a shoulder, the belt) with chrome_rig_turn().
 * - The real body is hidden with a colour filter, and made clickable over its whole tile while hidden,
 *   so the crew can still click the body to stop it. Puppets never take clicks.
 * - The pictures are made at runtime, and each client has to fetch them before it can draw a puppet. Until
 *   they land a puppet is drawn as nothing: a body hidden at once was simply gone for that moment, and a
 *   bearer whose body had landed stood there with no arms. So a copy of the body's own look, which needs
 *   no new picture, stands where it was drawn (the stand-in), cut out by a solid box kept in the same
 *   file as the puppets' pictures. Every rig that goes up in one tick shares one file (the sheet), so on
 *   each client the stand-ins go and all the puppets show in the same frame, the frame the file lands.
 * - Off: the filter and the click area come back and every puppet is deleted. That happens when the rig
 *   is deleted, which its owner does on every way a finisher ends, and which the rig does itself if the
 *   body is deleted.
 *
 * A body whose flat picture isn't 32x32 (something huge worn or held) gets no rig: the move still
 * happens, just without the poses.
 */

/// Mask states and pivots below are for tg's human base body, medium height.
#define CHROME_RIG_HIDE_FILTER "chrome_rig_hide"
/// The filter that cuts a body's stand-in out once the puppets' pictures have reached a client.
#define CHROME_RIG_SWAP_FILTER "chrome_rig_swap"
/// The solid box's name in a sheet.
#define CHROME_RIG_BOX_STATE "box"

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

/**
 * Pixels from a shoulder pivot to the middle of the hand on a hanging arm, per facing, from the rig masks.
 * list(dir = list(left_x, left_y, right_x, right_y)). In a side view the far arm is drawn as the near one a
 * pixel further back (arm_picture()), so its hand is a pixel further back too.
 */
GLOBAL_LIST_INIT(chrome_rig_hands, list(
	"[SOUTH]" = list(2, -9, -1, -9),
	"[NORTH]" = list(-1, -9, 2, -9),
	"[EAST]" = list(0.5, -6, 1.5, -6),
	"[WEST]" = list(-1.5, -6, -0.5, -6),
))

/// The soles of a standing human, from the icon's centre: a body bends forward about them.
#define CHROME_RIG_FEET_Y -15
/// The lowest pixel row (from the bottom, 1-based) of a human head; the neck is under it.
#define CHROME_RIG_NECK_Y 23
/// The neck line, from the icon's centre: the bottom edge of the head's lowest row. A head squashed or
/// turned about it stays on the shoulders.
#define CHROME_RIG_NECK_PIVOT_Y (CHROME_RIG_NECK_Y - 1 - ICON_SIZE_Y / 2)

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

/// A hidden body's own look, standing where it was drawn until its puppets' pictures reach a client (conceal()).
/obj/effect/abstract/chrome_rig_stand_in
	name = "body"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	animate_movement = NO_STEPS

/// The solid box a stand-in is cut out by, riding on it and never drawn itself. It comes from the puppets' file.
/obj/effect/abstract/chrome_rig_cutout
	name = ""
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	// Upright whatever the stand-in's own turn: a filter cuts it before it is turned
	appearance_flags = RESET_TRANSFORM | RESET_COLOR | RESET_ALPHA
	vis_flags = VIS_INHERIT_PLANE | VIS_INHERIT_LAYER

/**
 * The one picture file every puppet of the rigs that go up in the same tick is drawn from: a solid box (what
 * the stand-ins are cut out by) and each puppet's picture, every one under a name of its own. One file lands
 * on a client at one moment, so nothing of those rigs is drawn before the rest.
 */
/datum/chrome_rig_sheet
	/// The world.time it was started in
	var/made_at
	/// The rigs drawn from it
	var/list/datum/chrome_rig/rigs = list()
	/// The file
	var/icon/pictures

/// The sheet for rigs going up in this tick.
/proc/chrome_rig_sheet_now()
	var/static/datum/chrome_rig_sheet/current
	if(isnull(current) || current.made_at != world.time)
		current = new
		current.made_at = world.time
	return current

/// Builds the file again from every puppet its rigs have now, and points them and the stand-ins' cut-outs at it.
/datum/chrome_rig_sheet/proc/redraw()
	var/static/icon/box
	if(isnull(box))
		box = icon('icons/blanks/32x32.dmi', "nothing")
		box.DrawBox("#ffffff", 1, 1, ICON_SIZE_X, ICON_SIZE_Y)
	var/icon/file = icon(box)
	file.Insert(box, CHROME_RIG_BOX_STATE)
	var/list/states = list()
	for(var/datum/chrome_rig/rig as anything in rigs)
		for(var/key in rig.puppets)
			var/obj/effect/abstract/chrome_puppet/puppet = rig.puppets[key]
			if(QDELETED(puppet) || (isnull(puppet.picture) && isnull(puppet.icon)))
				continue
			// One stood up by its owner, not add_puppet(): its picture is whatever it shows
			if(isnull(puppet.picture))
				puppet.picture = icon(puppet.icon, puppet.icon_state)
			var/state = "puppet_[length(states) + 1]"
			file.Insert(puppet.picture, state)
			states[puppet] = state
	pictures = file
	for(var/obj/effect/abstract/chrome_puppet/puppet as anything in states)
		puppet.icon = file
		puppet.icon_state = states[puppet]
	for(var/datum/chrome_rig/rig as anything in rigs)
		if(rig.cutout)
			rig.cutout.icon = file
			rig.cutout.icon_state = CHROME_RIG_BOX_STATE

/// One stand-in picture on a hidden body's tile.
/obj/effect/abstract/chrome_puppet
	name = "body"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	appearance_flags = PIXEL_SCALE | TILE_BOUND | LONG_GLIDE
	// A puppet moved to the next tile is re-offset by a tile at once; a glide would draw it a tile out and slide it back
	animate_movement = NO_STEPS
	plane = GAME_PLANE
	layer = MOB_LAYER
	vis_flags = NONE
	/// The picture it was given, as it was before it went into a sheet
	var/icon/picture

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
	/// The body's own look, standing in for it until the puppets' pictures reach a client
	var/obj/effect/abstract/chrome_rig_stand_in/stand_in
	/// What the stand-in is cut out by
	var/obj/effect/abstract/chrome_rig_cutout/cutout
	/// The file this rig's puppets are drawn from
	var/datum/chrome_rig_sheet/sheet
	/// Side -> list(turn, length) the arm was last sent to
	var/list/arm_poses = list()
	/// The body's own transform (a lying body's turn) under every pose of its arms, or null for none
	var/matrix/base_transform
	/// Degrees the body is bent forward from the feet (negative: leaning back), seen from the side
	var/bend_angle = 0

/datum/chrome_rig/New(mob/living/body, facing)
	. = ..()
	src.body = body
	src.facing = facing || body.dir
	if(!(src.facing in GLOB.cardinals))
		src.facing = (src.facing & (EAST|WEST)) || SOUTH
	RegisterSignal(body, COMSIG_QDELETING, PROC_REF(on_body_deleted))

/datum/chrome_rig/Destroy()
	reveal()
	QDEL_NULL(stand_in)
	QDEL_NULL(cutout)
	if(sheet)
		sheet.rigs -= src
		sheet = null
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

/**
 * The flat picture above the neck (the head, with its hair and hat) if [head], else below it. The head keeps
 * the body's top row too, so the two overlap at the neck and no seam opens while the head is squashed.
 */
/datum/chrome_rig/proc/cut_at_neck(head = TRUE)
	var/icon/piece = icon(flat)
	if(head)
		piece.DrawBox(null, 1, 1, ICON_SIZE_X, CHROME_RIG_NECK_Y - 2)
	else
		piece.DrawBox(null, 1, CHROME_RIG_NECK_Y, ICON_SIZE_X, ICON_SIZE_Y)
	return piece

/**
 * Hides the real body. Its whole tile still takes clicks. Call it once the rig's puppets are up: they go into
 * the tick's sheet here. Until that file reaches a client the body's stand-in shows, [shift_x], [shift_y]
 * pixels from where the body is drawn: where its puppets start, if not on the body.
 */
/datum/chrome_rig/proc/conceal(shift_x = 0, shift_y = 0)
	if(hidden || QDELETED(body))
		return
	hidden = TRUE
	var/turf/spot = get_turf(body)
	if(spot)
		// Taken before the body is hidden, or it would be a copy of nothing
		stand_in = new(spot)
		stand_in.appearance = body.appearance
		// A look carries no facing: without the body's own it would stand facing the viewer
		stand_in.dir = body.dir
		stand_in.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		stand_in.pixel_x = body.pixel_x + shift_x
		stand_in.pixel_y = body.pixel_y + shift_y
		stand_in.pixel_w = body.pixel_w
		stand_in.pixel_z = body.pixel_z
		// The body's own filters stay on its copy when the cut-out goes on
		stand_in.filter_data = body.filter_data?.Copy()
		cutout = new(null)
		cutout.render_target = "*chrome_rig_[REF(src)]"
		stand_in.vis_contents += cutout
		stand_in.add_filter(CHROME_RIG_SWAP_FILTER, 1, alpha_mask_filter(render_source = cutout.render_target, flags = MASK_INVERSE))
	old_mouse_opacity = body.mouse_opacity
	body.mouse_opacity = MOUSE_OPACITY_OPAQUE
	body.add_filter(CHROME_RIG_HIDE_FILTER, 1, color_matrix_filter(list(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0)))
	pack()

/**
 * Puts this rig's puppets in the sheet of the tick it goes up in (conceal() does). A rig that is never
 * concealed, because another rig of the same body is, calls this itself.
 */
/datum/chrome_rig/proc/pack()
	if(sheet && sheet.made_at != world.time)
		// Its file has gone out: a puppet added now is a picture of its own
		return
	sheet = chrome_rig_sheet_now()
	sheet.rigs |= src
	sheet.redraw()

/// Shows the real body again.
/datum/chrome_rig/proc/reveal()
	if(!hidden)
		return
	hidden = FALSE
	QDEL_NULL(stand_in)
	QDEL_NULL(cutout)
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
	puppet.picture = picture
	puppet.dir = SOUTH
	puppet.pixel_x = body.pixel_x
	puppet.pixel_y = body.pixel_y
	puppet.pixel_w = body.pixel_w
	puppet.pixel_z = body.pixel_z
	puppet.layer = puppet_layer || body.layer
	if(copy_transform)
		puppet.transform = body.transform
	puppets[key] = puppet
	// Stood up after the rig was packed, in the same tick: into the same file
	if(sheet?.made_at == world.time)
		sheet.redraw()
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
	for(var/side in list("l", "r"))
		var/obj/effect/abstract/chrome_puppet/arm = add_puppet("arm_[side]", arm_picture(side))
		arm.layer = body.layer + (behind_body(side) ? -0.01 : 0.01)
	conceal()
	return TRUE

/**
 * Takes the flat picture again and gives the standard bearer puppets their new cuts, where they stand and as
 * they are posed. Blood that lands on the hidden body mid-move shows on its stand-ins at once, not only when
 * the rig comes down. Returns FALSE if the picture can't be taken; the old one stays.
 */
/datum/chrome_rig/proc/redraw_arms()
	if(!snapshot())
		return FALSE
	repaint("body", cut_without_arms("both"))
	for(var/side in list("l", "r"))
		repaint("arm_[side]", arm_picture(side))
	return TRUE

/**
 * Draws [picture] over the puppet under [key], in place of anything drawn over it before. Not a swap of its icon:
 * a picture made at runtime takes a moment to reach each client, and a puppet whose only picture is still on its
 * way is drawn as nothing, so it would blink out. The old picture stays under the new one until that lands.
 */
/datum/chrome_rig/proc/repaint(key, icon/picture)
	var/obj/effect/abstract/chrome_puppet/puppet = puppets?[key]
	if(!puppet || !picture)
		return
	puppet.cut_overlays()
	puppet.add_overlay(mutable_appearance(picture))

/// Whether the arm on [side] is the far one in a side view, under the body. Seen from the front or back both arms are over it.
/datum/chrome_rig/proc/behind_body(side)
	return (facing in list(EAST, WEST)) && side != near_side()

/**
 * The picture of the arm on [side]. The far arm is hidden behind the body in a side view, so its cut is
 * empty: it is drawn as the near arm, a pixel further back and in shadow, so a raised pair reads as two arms.
 */
/datum/chrome_rig/proc/arm_picture(side)
	if(!behind_body(side))
		return cut("rig_arm_[side]")
	var/icon/picture = cut("rig_arm_[near_side()]")
	picture.Shift(facing == EAST ? WEST : EAST, 1)
	picture.Blend(rgb(170, 170, 178), ICON_MULTIPLY)
	return picture

/// Pixels from the shoulder pivot on [side] to the middle of its hand, on a hanging arm.
/datum/chrome_rig/proc/hand_offset(side)
	var/list/hands = GLOB.chrome_rig_hands["[facing]"]
	return side == "l" ? list(hands[1], hands[2]) : list(hands[3], hands[4])

/// The length of the arm on [side]: shoulder pivot to the middle of the hand.
/datum/chrome_rig/proc/arm_reach(side)
	var/list/hand = hand_offset(side)
	return sqrt(hand[1] * hand[1] + hand[2] * hand[2])

/**
 * The matrix posing the arm on [side]: turned [turn] degrees about its shoulder, [length] times as long, then
 * turned with the body ([base], else the rig's base_transform).
 */
/datum/chrome_rig/proc/arm_matrix(side, turn, length, matrix/base)
	var/list/pivot = shoulder(side)
	var/matrix/pose = chrome_rig_turn(turn, pivot[1], pivot[2], 0, 0, 1, length)
	var/matrix/under = base || base_transform
	if(under)
		pose.Multiply(under)
	return pose

/// The body bent forward [angle] degrees from the feet, seen from the side; null when it doesn't turn (no angle, or seen from the front or back).
/datum/chrome_rig/proc/bend_matrix(angle)
	if(!angle || !(facing in list(EAST, WEST)))
		return null
	return chrome_rig_turn(facing == WEST ? -angle : angle, 0, CHROME_RIG_FEET_Y)

/**
 * Bends the body to [to_bend] degrees from the feet (see bend_matrix()) while both arms swing to [angle], as
 * swing_arm() does, step for step so the arms stay on the shoulders, over [time].
 */
/datum/chrome_rig/proc/bend_and_swing(to_bend, angle, time, reach = 0)
	var/steps = swing_steps(bend_angle, to_bend)
	var/list/targets = list()
	for(var/side in list("l", "r"))
		var/list/from = arm_poses[side] || list(0, 1)
		var/to_turn = angle * raise_sign(side)
		targets[side] = list(to_turn, max(CHROME_RIG_MIN_ARM_LENGTH, 1 + reach / (GLOB.chrome_rig_arm_length["[facing]"] || 10)))
		steps = max(steps, swing_steps(from[1], to_turn))
	var/list/bases = list()
	for(var/i in 1 to steps)
		bases += list(bend_matrix(bend_angle + (to_bend - bend_angle) * (1 - cos(180 * i / steps)) / 2))
	for(var/side in list("l", "r"))
		var/list/from = arm_poses[side] || list(0, 1)
		var/list/to_pose = targets[side]
		var/list/poses = list()
		for(var/i in 1 to steps)
			var/progress = (1 - cos(180 * i / steps)) / 2
			poses += list(list(from[1] + (to_pose[1] - from[1]) * progress, from[2] + (to_pose[2] - from[2]) * progress, bases[i]))
		pose_arm_through(side, poses, time / steps)
	body_through(bases, time / steps)
	bend_angle = to_bend
	base_transform = bend_matrix(to_bend)

/// Sends the body puppet through [bases] (matrices, null for upright), one straight step of [step_time] each (or of step_time[i], given a list), as its arms go through theirs.
/datum/chrome_rig/proc/body_through(list/bases, step_time)
	var/obj/effect/abstract/chrome_puppet/body_puppet = puppet("body")
	if(!body_puppet)
		return
	for(var/i in 1 to length(bases))
		var/matrix/base = bases[i] || matrix()
		var/this_step = islist(step_time) ? step_time[i] : step_time
		if(i == 1)
			animate(body_puppet, transform = base, time = this_step)
		else
			animate(transform = base, time = this_step)

/// [x], [y] (pixels from the middle of the picture) put through [transform].
/proc/chrome_rig_apply(matrix/transform, x, y)
	return list(transform.a * x + transform.b * y + transform.c, transform.d * x + transform.e * y + transform.f)

/// [flat] (a body's own turn, a lying one's) turned on by [angle] degrees (clockwise) about the body's feet as drawn under it.
/proc/chrome_rig_turn_about_feet(matrix/flat, angle)
	var/matrix/turned = matrix(flat)
	if(!angle)
		return turned
	var/list/feet = chrome_rig_apply(turned, 0, CHROME_RIG_FEET_Y)
	turned.Multiply(chrome_rig_turn(angle, feet[1], feet[2]))
	return turned

/// Where the shoulder on [side] is drawn under [base] (else base_transform): pixels from the middle of the puppet, before its offsets.
/datum/chrome_rig/proc/shoulder_point(side, matrix/base)
	var/list/pivot = shoulder(side)
	var/matrix/under = base || base_transform
	return under ? chrome_rig_apply(under, pivot[1], pivot[2]) : pivot

/// Where the hand on [side] is drawn in the arm's last pose: pixels from the middle of the puppet, before its offsets.
/datum/chrome_rig/proc/hand_point(side)
	return hand_at(side, arm_poses[side] || list(0, 1))

/// Where the hand on [side] is drawn in [pose] (list(turn, length), or list(turn, length, base)): pixels from the middle of the puppet, before its offsets.
/datum/chrome_rig/proc/hand_at(side, list/pose)
	var/list/pivot = shoulder(side)
	var/list/hand = hand_offset(side)
	return chrome_rig_apply(arm_matrix(side, pose[1], pose[2], length(pose) > 2 ? pose[3] : null), pivot[1] + hand[1], pivot[2] + hand[2])

/**
 * The pose (list(turn, length)) that puts the hand on [side] at [x], [y] (pixels from the middle of the
 * puppet, as drawn, before its offsets) with the body turned by [base] (else base_transform): the arm turned
 * about its shoulder and stretched or shortened along its length. Turned the short way round from [from_turn].
 */
/datum/chrome_rig/proc/pose_reaching(side, x, y, from_turn = 0, matrix/base)
	// Back through the body's turn into the flat picture's own pixels
	var/matrix/body_turn = base || base_transform
	if(body_turn)
		var/det = body_turn.a * body_turn.e - body_turn.b * body_turn.d
		if(det)
			var/rel_x = x - body_turn.c
			var/rel_y = y - body_turn.f
			x = (body_turn.e * rel_x - body_turn.b * rel_y) / det
			y = (body_turn.a * rel_y - body_turn.d * rel_x) / det
	var/list/pivot = shoulder(side)
	var/list/hand = hand_offset(side)
	var/to_x = x - pivot[1]
	var/to_y = y - pivot[2]
	var/reach = sqrt(to_x * to_x + to_y * to_y)
	if(reach < 1)
		return list(from_turn, CHROME_RIG_MIN_ARM_LENGTH)
	// Only the length stretches, so the hand keeps its sideways offset from the shoulder
	var/length = max(CHROME_RIG_MIN_ARM_LENGTH, sqrt(max(0, reach * reach - hand[1] * hand[1])) / abs(hand[2]))
	var/turn = arctan(hand[1], hand[2] * length) - arctan(to_x, to_y)
	while(turn - from_turn > 180)
		turn -= 360
	while(turn - from_turn < -180)
		turn += 360
	return list(turn, length)

/// How many straight steps a swing from [from_turn] to [to_turn] takes, so the shoulder stays on its pivot.
/datum/chrome_rig/proc/swing_steps(from_turn, to_turn)
	return max(1, CEILING(abs(to_turn - from_turn) / CHROME_RIG_SWING_STEP, 1))

/**
 * Sends the arm on [side] through [poses] (each list(turn, length), or list(turn, length, base) with the
 * body's turn at that step), one straight step of [step_time] to each (or of step_time[i] to the i-th, given a
 * list). Arms sent through matching poses in the same steps move together, hand on hand.
 */
/datum/chrome_rig/proc/pose_arm_through(side, list/poses, step_time)
	var/obj/effect/abstract/chrome_puppet/arm = puppet("arm_[side]")
	if(!arm || !length(poses))
		return
	for(var/i in 1 to length(poses))
		var/list/pose = poses[i]
		var/matrix/posed = arm_matrix(side, pose[1], pose[2], length(pose) > 2 ? pose[3] : null)
		var/this_step = islist(step_time) ? step_time[i] : step_time
		if(i == 1)
			animate(arm, transform = posed, time = this_step)
		else
			animate(transform = posed, time = this_step)
	var/list/last = poses[length(poses)]
	arm_poses[side] = list(last[1], last[2])

/**
 * Sends the hand on [side] to each of [points] in turn (list(x, y), pixels from the middle of the puppet, as
 * pose_reaching() takes them), times[i] to the i-th, each leg cut into short steps so the shoulder stays put. The
 * arm is never stretched past [max_length] times its length: the hand stops short instead.
 */
/datum/chrome_rig/proc/reach_through(side, list/points, list/times, max_length = 2)
	var/list/from = arm_poses[side] || list(0, 1)
	var/list/poses = list()
	var/list/step_times = list()
	for(var/i in 1 to length(points))
		var/list/point = points[i]
		var/list/to_pose = pose_reaching(side, point[1], point[2], from[1])
		to_pose[2] = min(to_pose[2], max_length)
		var/steps = swing_steps(from[1], to_pose[1])
		for(var/j in 1 to steps)
			var/progress = (1 - cos(180 * j / steps)) / 2
			poses += list(list(from[1] + (to_pose[1] - from[1]) * progress, from[2] + (to_pose[2] - from[2]) * progress))
			step_times += times[i] / steps
		from = to_pose
	pose_arm_through(side, poses, step_times)

/**
 * Counts each arm's turn the short way round from hanging, without moving it (a full turn more or less is the same
 * pose). An arm swung on past straight up then comes down the way it points, not back up over the head.
 */
/datum/chrome_rig/proc/unwind_arms()
	for(var/side in arm_poses)
		var/list/pose = arm_poses[side]
		while(pose[1] > 180)
			pose[1] -= 360
		while(pose[1] <= -180)
			pose[1] += 360

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
	var/list/from = arm_poses[side] || list(0, 1)
	var/to_turn = angle * raise_sign(side)
	var/to_length = max(CHROME_RIG_MIN_ARM_LENGTH, 1 + reach / (GLOB.chrome_rig_arm_length["[facing]"] || 10))
	arm_poses[side] = list(to_turn, to_length)
	var/steps = max(1, CEILING(abs(to_turn - from[1]) / CHROME_RIG_SWING_STEP, 1))
	var/step_time = time / steps
	for(var/i in 1 to steps)
		// Sine in and out across the whole swing; each step itself is straight
		var/progress = (easing & SINE_EASING) ? (1 - cos(180 * i / steps)) / 2 : i / steps
		var/matrix/pose = arm_matrix(side, from[1] + (to_turn - from[1]) * progress, from[2] + (to_length - from[2]) * progress)
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

/// Every puppet (but those under the keys in [skip]: one drawn on another moves with it) trembles a pixel for [time], and ends where it began.
/datum/chrome_rig/proc/tremble(time = 0.4 SECONDS, list/skip)
	for(var/key in puppets)
		if(key in skip)
			continue
		var/obj/effect/abstract/chrome_puppet/puppet = puppets[key]
		var/moved = 0
		for(var/i in 1 to max(1, round(time / (0.1 SECONDS))))
			var/step = (i % 2) ? 1 : -1
			if(i == 1)
				animate(puppet, pixel_w = step, time = 0.05 SECONDS, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
				moved += step
			else
				animate(pixel_w = step * 2, time = 0.05 SECONDS, flags = ANIMATION_RELATIVE)
				moved += step * 2
			animate(pixel_w = -step, time = 0.05 SECONDS, flags = ANIMATION_RELATIVE)
			moved -= step
		// An even count leaves it a pixel off, which would jump back when the rig comes down
		if(moved)
			animate(pixel_w = -moved, time = 0.05 SECONDS, flags = ANIMATION_RELATIVE)

/// Every puppet flashes white and fades back.
/datum/chrome_rig/proc/flash()
	for(var/key in puppets)
		cyberware_flash_fx(puppets[key], 0.2 SECONDS)

#undef CHROME_RIG_HIDE_FILTER
#undef CHROME_RIG_SWAP_FILTER
#undef CHROME_RIG_BOX_STATE
#undef CHROME_RIG_SWING_STEP
#undef CHROME_RIG_MIN_ARM_LENGTH
