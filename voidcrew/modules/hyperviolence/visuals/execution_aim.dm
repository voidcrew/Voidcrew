// The Sandevistan replay plays a move again: animate() here is journaled for it (cyberware/ware_sandy_replay.dm).
#define animate(arguments...) sandy_replay_animate(arguments)

/**
 * # A gun execution's aim
 *
 * tg draws a held gun low at the hip and a body has no poses, so a shooter holding the barrel to a head stood in the
 * middle of his own tile with the gun at his side. For the length of the hold he is drawn by the puppet rig
 * (hyperviolence_gorilla/chrome_puppet_rig.dm) instead: his body without the gun arm, the gun arm, and the gun, three
 * pictures posed so the barrel's end is on the victim's head where that head is drawn, whichever way the victim lies
 * and whichever side the shooter stands on.
 *
 * - Everything is measured in pixels from the middle of the shooter as he is drawn, x to the right and y up, and each
 *   picture is moved by its transform alone.
 * - He faces along the longer side of the way to the head. Seen side-on he bends forward from the feet. He leans
 *   toward the victim as far as it takes for his arm and the gun to span the rest: a little for a head at his feet,
 *   half a tile for one at the far end of the victim's tile.
 * - The barrel's line runs through the middle of the head and stops HV_AIM_GAP short of it. The hand is where that puts
 *   the grip, and the arm turns and stretches from the shoulder to the hand.
 * - The gun at his hip is left out of the picture the rig takes of him, and only out of that picture: the real body,
 *   hidden under the rig, keeps it.
 * - Purely a drawing. It goes when the execution does: fired (after the recoil), called off, the shooter moved or
 *   knocked down, the gun out of his hand, either of them deleted.
 *
 * A shooter the rig can't draw (not human, lying down, cloaked, already in a finisher's rig, a picture that isn't one
 * tile) leans in as before (hv_vis_press_in()).
 */

/// How far short of the middle of the head the barrel's end stops: the head is about four pixels in radius.
#define HV_AIM_GAP 5
/// How big the gun is drawn, of its item icon.
#define HV_AIM_GUN_SCALE 0.6
/// The least and the most the shooter leans toward the victim, in pixels.
#define HV_AIM_LEAN_MIN 4
#define HV_AIM_LEAN_MAX 17
/// The bend of the body seen side-on, in degrees: for a head at his feet, and what a head a tile further adds.
#define HV_AIM_BEND 8
#define HV_AIM_BEND_FAR 10
/// How long the lift from the hip to the head takes, the kick of the shot, how long the kick is held, and the way back down.
#define HV_AIM_RAISE (0.3 SECONDS)
#define HV_AIM_KICK (0.05 SECONDS)
#define HV_AIM_KICK_HOLD (0.25 SECONDS)
#define HV_AIM_LOWER (0.3 SECONDS)
/// The way back down of a hold that was called off.
#define HV_AIM_CALLED_OFF (0.15 SECONDS)
/// How far the shot throws the gun back along the barrel, in pixels, and how far it tips the barrel up, in degrees.
#define HV_AIM_KICK_BACK 2
#define HV_AIM_KICK_CLIMB 20

/obj/item/gun
	/// The aimed pose of the execution this gun is being held to a head for
	var/datum/hv_exec_aim/hv_aim
	/// TRUE while the rig takes its picture of the shooter: the gun in his hand is left out of it
	var/hv_aim_out_of_hand = FALSE

// The gun is in the hand all along; only its drawing at the hip is left out of the rig's picture.
/obj/item/gun/build_worn_icon(default_layer = 0, default_icon_file = null, isinhands = FALSE, female_uniform = NO_FEMALE_UNIFORM, override_state = null, override_file = null)
	. = ..()
	if(isinhands && hv_aim_out_of_hand && .)
		var/mutable_appearance/standing = .
		standing.alpha = 0

/datum/hv_exec_aim
	/// The gun
	var/obj/item/gun/gun
	/// Who holds it
	var/mob/living/carbon/human/shooter
	/// Whose head it is on
	var/mob/living/target
	/// The rig drawing the shooter
	var/datum/chrome_rig/rig
	/// The way the shooter is drawn facing
	var/facing
	/// The arm the gun is in: "l" or "r"
	var/side
	/// The grip and the barrel's end on the gun's picture: list(grip x, grip y, muzzle x, muzzle y)
	var/list/shape
	/// The middle of the victim's drawn head
	var/head_x = 0
	var/head_y = 0
	/// The way the barrel points, a unit vector
	var/aim_x = 0
	var/aim_y = 0
	/// -1 for a gun pointing left: its picture is mirrored so it isn't held upside down
	var/flip = 1
	/// The barrel's turn, in degrees clockwise from pointing east
	var/barrel_turn = 0
	/// The barrel's end in the aimed pose
	var/list/muzzle
	/// The aimed pose (see pose_for())
	var/list/aimed
	/// The pose the pictures were last sent to
	var/list/held
	/// The timer that takes the rig down once he is back upright
	var/down_timer

/datum/hv_exec_aim/New(obj/item/gun/gun, mob/living/shooter, mob/living/target)
	. = ..()
	src.gun = gun
	src.shooter = shooter
	src.target = target

/datum/hv_exec_aim/Destroy()
	if(down_timer)
		deltimer(down_timer)
		down_timer = null
	if(gun)
		UnregisterSignal(gun, list(COMSIG_ITEM_DROPPED, COMSIG_QDELETING))
		if(gun.hv_aim == src)
			gun.hv_aim = null
	if(shooter)
		UnregisterSignal(shooter, COMSIG_QDELETING)
	QDEL_NULL(rig)
	take_from_hand(FALSE)
	gun = null
	shooter = null
	target = null
	return ..()

/// Leaves the gun at the hip out of the shooter's look (`out`), or puts it back.
/datum/hv_exec_aim/proc/take_from_hand(out)
	if(QDELETED(gun) || gun.hv_aim_out_of_hand == out)
		return
	gun.hv_aim_out_of_hand = out
	if(!QDELETED(shooter))
		shooter.update_held_items()

/// Whether the rig is up and the barrel is on the head.
/datum/hv_exec_aim/proc/is_up()
	return !QDELETED(src) && !isnull(rig) && !isnull(aimed)

/**
 * Stands the rig up and lifts the gun onto the head. Returns FALSE if the shooter can't be drawn that way, with
 * nothing left behind.
 */
/datum/hv_exec_aim/proc/raise()
	if(!ishuman(shooter) || QDELETED(target) || QDELETED(gun) || !isturf(shooter.loc) || !isturf(target.loc))
		return FALSE
	if(shooter.body_position == LYING_DOWN || shooter.alpha < 255 || shooter.invisibility || sandy_rig_hidden(shooter))
		return FALSE
	var/held_index = shooter.get_held_index_of_item(gun)
	if(!held_index)
		return FALSE
	side = IS_LEFT_INDEX(held_index) ? "l" : "r"
	var/icon/gun_picture = getFlatIcon(gun, SOUTH, no_anim = TRUE)
	if(!gun_picture)
		return FALSE
	if(gun_picture.Width() != ICON_SIZE_X || gun_picture.Height() != ICON_SIZE_Y)
		gun_picture.Scale(ICON_SIZE_X, ICON_SIZE_Y)
	shape = hv_gun_shape(gun, gun_picture)
	// Where the head is drawn, from where the shooter is drawn
	var/turf/shooter_turf = shooter.loc
	var/turf/target_turf = target.loc
	var/list/head_at = target.hv_vis_head_offset()
	head_x = (target_turf.x - shooter_turf.x) * ICON_SIZE_X + head_at[1] - (shooter.pixel_x + shooter.pixel_w)
	head_y = (target_turf.y - shooter_turf.y) * ICON_SIZE_Y + head_at[2] - (shooter.pixel_y + shooter.pixel_z)
	facing = abs(head_x) >= abs(head_y) ? (head_x >= 0 ? EAST : WEST) : (head_y >= 0 ? NORTH : SOUTH)
	if(shooter.dir != facing)
		shooter.setDir(facing)

	rig = new(shooter, facing)
	take_from_hand(TRUE)
	if(!rig.snapshot())
		take_from_hand(FALSE)
		QDEL_NULL(rig)
		return FALSE
	// What is drawn over what. On one row the gun arm and the gun are over both bodies; seen from behind they are
	// under his own. A far arm, in a side view, is under his body with its gun.
	var/far_arm = rig.behind_body(side)
	// A body lying a row nearer the viewer is drawn over everything on his row: the arm and the gun stand on its row.
	var/on_their_row = target.body_position == LYING_DOWN && target_turf.y < shooter_turf.y
	var/top = max(shooter.layer, target.layer)
	var/arm_layer = top + 0.02
	var/gun_layer = top + 0.01
	if(facing == NORTH)
		arm_layer = shooter.layer - 0.01
		gun_layer = shooter.layer - 0.02
	else if(far_arm && !on_their_row)
		arm_layer = shooter.layer - 0.02
		gun_layer = shooter.layer - 0.01
	rig.add_puppet("body", rig.cut_without_arms(side))
	var/obj/effect/abstract/chrome_puppet/gun_puppet = rig.add_puppet("gun", gun_picture, FALSE, gun_layer)
	var/obj/effect/abstract/chrome_puppet/arm_puppet = rig.add_puppet("arm_[side]", rig.arm_picture(side), FALSE, arm_layer)
	if(on_their_row)
		for(var/obj/effect/abstract/chrome_puppet/puppet as anything in list(gun_puppet, arm_puppet))
			puppet.pixel_y -= ICON_SIZE_Y
			puppet.pixel_z += ICON_SIZE_Y
	rig.conceal()
	take_from_hand(FALSE)
	// Moved or knocked down, the gun out of his hand, or gone: the drawing comes down at once
	rig.watch_body(CALLBACK(src, PROC_REF(drop)))
	RegisterSignals(gun, list(COMSIG_ITEM_DROPPED, COMSIG_QDELETING), PROC_REF(on_lost))
	RegisterSignal(shooter, COMSIG_QDELETING, PROC_REF(on_lost))

	solve()
	var/list/rest = rest_pose()
	set_pose(rest)
	play(through(rest, aimed, 3), HV_AIM_RAISE)
	return TRUE

/datum/hv_exec_aim/proc/on_lost(datum/source)
	SIGNAL_HANDLER
	drop()

/// Takes the drawing down at once.
/datum/hv_exec_aim/proc/drop()
	if(!QDELETED(src))
		qdel(src)

/// Works out the aimed pose: how far he bends and leans, and from that the arm and the gun.
/datum/hv_exec_aim/proc/solve()
	var/side_view = facing == EAST || facing == WEST
	var/bend = side_view ? HV_AIM_BEND + HV_AIM_BEND_FAR * clamp((abs(head_x) - 20) / 21, 0, 1) : 0
	var/matrix/bent = body_matrix(bend, 0, 0)
	var/list/pivot = rig.shoulder(side)
	var/list/shoulder = chrome_rig_apply(bent, pivot[1], pivot[2])
	var/to_x = head_x - shoulder[1]
	var/to_y = head_y - shoulder[2]
	// He leans the way he faces; sideways as well only for a head a tile off that line (a diagonal)
	var/way_x = (side_view || abs(to_x) >= ICON_SIZE_X / 2) ? to_x : 0
	var/way_y = (!side_view || abs(to_y) >= ICON_SIZE_Y / 2) ? to_y : 0
	var/way_length = sqrt(way_x * way_x + way_y * way_y) || 1
	way_x /= way_length
	way_y /= way_length
	// What his arm and the gun span when the arm is easy: the lean covers the rest
	var/list/hand = rig.hand_offset(side)
	var/arm_ease = side_view ? 1.25 : (facing == SOUTH ? 1.1 : 0.7)
	var/span = HV_AIM_GAP + (shape[3] - shape[1]) * HV_AIM_GUN_SCALE + sqrt(hand[1] * hand[1] + hand[2] * hand[2]) * arm_ease
	var/along = to_x * way_x + to_y * way_y
	var/aside = to_x * to_x + to_y * to_y - along * along
	var/lean = clamp(along - sqrt(max(0, span * span - aside)), HV_AIM_LEAN_MIN, HV_AIM_LEAN_MAX)
	aimed = pose_for(bend, round(way_x * lean), round(way_y * lean))
	muzzle = barrel_end(aimed)

/**
 * The pose with the body bent `bend` degrees and moved `lean_x`, `lean_y`, the barrel on the head and thrown `kick`
 * pixels back from it: list(bend, lean x, lean y, arm turn, arm length, gun turn). The first full pose (no kick) sets
 * the way the barrel points for the rest.
 */
/datum/hv_exec_aim/proc/pose_for(bend, lean_x, lean_y, kick = 0)
	var/matrix/body = body_matrix(bend, lean_x, lean_y)
	var/list/pivot = rig.shoulder(side)
	var/list/shoulder = chrome_rig_apply(body, pivot[1], pivot[2])
	if(!kick)
		var/to_x = head_x - shoulder[1]
		var/to_y = head_y - shoulder[2]
		var/distance = sqrt(to_x * to_x + to_y * to_y) || 1
		aim_x = to_x / distance
		aim_y = to_y / distance
		flip = aim_x < 0 ? -1 : 1
		barrel_turn = -arctan(aim_x, aim_y)
	// From the grip to the barrel's end as the gun is drawn, then back from where the barrel ends to where the hand is
	var/matrix/drawn = matrix()
	drawn.Scale(HV_AIM_GUN_SCALE, HV_AIM_GUN_SCALE * flip)
	drawn.Turn(barrel_turn)
	var/list/barrel = chrome_rig_apply(drawn, shape[3] - shape[1], shape[4] - shape[2])
	var/hand_x = head_x - aim_x * (HV_AIM_GAP + kick) - barrel[1]
	var/hand_y = head_y - aim_y * (HV_AIM_GAP + kick) - barrel[2]
	var/list/arm = rig.pose_reaching(side, hand_x, hand_y, 0, body)
	var/longest = (facing == EAST || facing == WEST) ? 1.7 : (facing == SOUTH ? 1.4 : 1.2)
	return list(bend, lean_x, lean_y, arm[1], min(arm[2], longest), barrel_turn - (kick ? HV_AIM_KICK_CLIMB * flip : 0))

/// The pose he starts from and ends in: upright on his tile, the arm hanging, the gun low and pointing down ahead of him.
/datum/hv_exec_aim/proc/rest_pose()
	var/low = 90
	switch(facing)
		if(EAST)
			low = 70
		if(WEST)
			low = 110
		if(NORTH) // behind his own body: it only comes up
			low = barrel_turn
	// The short way round from where it points on the head
	while(low - barrel_turn > 180)
		low -= 360
	while(low - barrel_turn < -180)
		low += 360
	return list(0, 0, 0, 0, 1, low)

/// The body's matrix bent `bend` degrees from the feet (side views only) and moved `lean_x`, `lean_y`.
/datum/hv_exec_aim/proc/body_matrix(bend, lean_x, lean_y)
	var/matrix/body = rig.bend_matrix(bend) || matrix()
	body.Translate(lean_x, lean_y)
	return body

/// The matrices that draw `pose`: list(body, arm, gun).
/datum/hv_exec_aim/proc/matrices_of(list/pose)
	var/matrix/body = body_matrix(pose[1], pose[2], pose[3])
	var/list/hand = rig.hand_at(side, list(pose[4], pose[5], body))
	var/matrix/gun_matrix = matrix()
	gun_matrix.Translate(-shape[1], -shape[2])
	gun_matrix.Scale(HV_AIM_GUN_SCALE, HV_AIM_GUN_SCALE * flip)
	gun_matrix.Turn(pose[6])
	gun_matrix.Translate(hand[1], hand[2])
	return list(body, rig.arm_matrix(side, pose[4], pose[5], body), gun_matrix)

/// Where the barrel's end is drawn in `pose`: list(x, y).
/datum/hv_exec_aim/proc/barrel_end(list/pose)
	var/list/matrices = matrices_of(pose)
	return chrome_rig_apply(matrices[3], shape[3], shape[4])

/// The poses from `first` to `last` in `steps` short straight steps, eased in and out, so the arm stays on its
/// shoulder and the gun in the hand on the way.
/datum/hv_exec_aim/proc/through(list/first, list/last, steps)
	. = list()
	for(var/i in 1 to steps)
		var/progress = (1 - cos(180 * i / steps)) / 2
		var/list/pose = list()
		for(var/part in 1 to length(last))
			pose += first[part] + (last[part] - first[part]) * progress
		. += list(pose)

/// Puts the pictures in `pose` at once.
/datum/hv_exec_aim/proc/set_pose(list/pose)
	var/list/matrices = matrices_of(pose)
	var/list/pictures = pictures()
	for(var/i in 1 to length(pictures))
		var/obj/effect/abstract/chrome_puppet/picture = pictures[i]
		if(picture)
			picture.transform = matrices[i]
	held = pose

/// The rig's pictures in the order matrices_of() gives their matrices: the body, the arm, the gun.
/datum/hv_exec_aim/proc/pictures()
	return list(rig.puppet("body"), rig.puppet("arm_[side]"), rig.puppet("gun"))

/**
 * Sends the pictures through `poses`, each step taking `times` (one number: the whole run, shared evenly; or a list, one
 * per pose), at the shooter's own pace in a Sandevistan slow-mo. Returns how long it takes in real time.
 */
/datum/hv_exec_aim/proc/play(list/poses, times, easing = LINEAR_EASING)
	var/list/each = times
	if(!islist(each))
		each = list()
		for(var/i in 1 to length(poses))
			each += times / length(poses)
	var/list/real = cyberware_dilated_steps(shooter, each) || each
	var/list/pictures = pictures()
	var/list/steps = list()
	for(var/list/pose as anything in poses)
		steps += list(matrices_of(pose))
	for(var/i in 1 to length(pictures))
		var/obj/effect/abstract/chrome_puppet/picture = pictures[i]
		if(!picture)
			continue
		for(var/step in 1 to length(steps))
			if(step == 1)
				animate(picture, transform = steps[step][i], time = real[step], easing = easing)
			else
				animate(transform = steps[step][i], time = real[step], easing = easing)
	held = poses[length(poses)]
	. = 0
	for(var/time in real)
		. += time

/// The shot: the gun kicks back and up, he rocks back with it and holds there through the flash, then lowers the gun
/// and straightens up, and the rig comes down.
/datum/hv_exec_aim/proc/recoil()
	if(!is_up() || QDELETED(shooter) || !isturf(shooter.loc))
		drop()
		return
	// The shot can bloody him: his pictures are taken again, where they stand
	take_from_hand(TRUE)
	if(rig.snapshot())
		rig.repaint("body", rig.cut_without_arms(side))
		rig.repaint("arm_[side]", rig.arm_picture(side))
	take_from_hand(FALSE)
	var/list/kicked = pose_for(max(aimed[1] - 3, 0), aimed[2] - round(aim_x * HV_AIM_KICK_BACK), aimed[3] - round(aim_y * HV_AIM_KICK_BACK), HV_AIM_KICK_BACK)
	var/list/poses = list(kicked, kicked) + through(kicked, rest_pose(), 3)
	var/length = play(poses, list(HV_AIM_KICK, HV_AIM_KICK_HOLD, HV_AIM_LOWER / 3, HV_AIM_LOWER / 3, HV_AIM_LOWER / 3))
	comes_down_in(length)

/// Called off: the gun comes down, and the rig with it.
/datum/hv_exec_aim/proc/lower()
	if(!is_up() || QDELETED(shooter) || !isturf(shooter.loc))
		drop()
		return
	comes_down_in(play(through(held, rest_pose(), 2), HV_AIM_CALLED_OFF))

/datum/hv_exec_aim/proc/comes_down_in(time)
	if(down_timer)
		deltimer(down_timer)
	down_timer = addtimer(CALLBACK(src, PROC_REF(drop)), time, TIMER_STOPPABLE|TIMER_DELETE_ME)

/// Where the barrel's end is in pixels from the middle of `spot`: list(x, y).
/datum/hv_exec_aim/proc/muzzle_from(turf/spot)
	var/turf/shooter_turf = get_turf(shooter)
	var/x = muzzle[1] + shooter.pixel_x + shooter.pixel_w
	var/y = muzzle[2] + shooter.pixel_y + shooter.pixel_z
	return list(x + (shooter_turf.x - spot.x) * ICON_SIZE_X, y + (shooter_turf.y - spot.y) * ICON_SIZE_Y)

/**
 * Where the grip and the barrel's end are on a gun's picture, in pixels from its middle: list(grip x, grip y, muzzle
 * x, muzzle y). tg's gun icons point east: the barrel ends at the right edge, the grip hangs under the back of it.
 */
/proc/hv_gun_shape(obj/item/gun/gun, icon/picture)
	var/static/list/shapes = list()
	var/key = "[gun.type]-[gun.icon_state]"
	if(shapes[key])
		return shapes[key]
	var/left = 0
	var/right = 0
	var/bottom = 0
	var/top = 0
	var/list/filled = list()
	for(var/x in 1 to ICON_SIZE_X)
		var/list/column = list()
		for(var/y in 1 to ICON_SIZE_Y)
			if(isnull(picture.GetPixel(x, y)))
				continue
			column += y
			left ||= x
			right = x
			bottom = bottom ? min(bottom, y) : y
			top = max(top, y)
		filled += list(column)
	if(!right)
		return shapes[key] = list(-7, -3, 10, 2)
	// The barrel's height: the middle of what is drawn two pixels in from its end
	var/list/barrel = filled[max(right - 2, left)]
	var/barrel_y = 0
	for(var/y in barrel)
		barrel_y += y
	barrel_y = length(barrel) ? barrel_y / length(barrel) : (top + bottom) / 2
	return shapes[key] = list(min(left + 3, right) - 0.5 - ICON_SIZE_X / 2, bottom + (top - bottom) * 0.4 - 0.5 - ICON_SIZE_Y / 2, right - ICON_SIZE_X / 2, barrel_y - 0.5 - ICON_SIZE_Y / 2)

#undef HV_AIM_GAP
#undef HV_AIM_GUN_SCALE
#undef HV_AIM_LEAN_MIN
#undef HV_AIM_LEAN_MAX
#undef HV_AIM_BEND
#undef HV_AIM_BEND_FAR
#undef HV_AIM_RAISE
#undef HV_AIM_KICK
#undef HV_AIM_KICK_HOLD
#undef HV_AIM_LOWER
#undef HV_AIM_CALLED_OFF
#undef HV_AIM_KICK_BACK
#undef HV_AIM_KICK_CLIMB

#undef animate
