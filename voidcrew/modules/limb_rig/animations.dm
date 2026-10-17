/**
 * What the rig does with its pieces.
 *
 * A pose is a list of part id -> joint angles:
 * - arms: "raise" (out to the side), "swing" (forward and back) and "elbow" (forearm bends forward),
 *   plus "reach" (fingers stretch by this much more) and "bird" (how far a raised middle finger
 *   is out: 0 is all the way, -1 is still curled). Arms hang off the torso, so they bend with it;
 *   "aim" instead of "swing" points the whole arm that way in the world, whatever the torso and
 *   posture are doing (90 is straight out in front). "hand_y" works the elbow out for you so the
 *   hand ends up at that height on the sprite (the face is about 26), however long the arm is.
 * - legs: "raise", "swing" and "knee" (shin bends back)
 * - head: "nod" (down is positive) and "tilt" (toward the mob's right)
 * - torso: "bend" (forward) and "lean" (toward the mob's right), plus "breath" (0.03 = 3% taller,
 *   negative squashes), and "air" (pixels the whole body is off the floor)
 * - head and torso: "skew", sheared sideways by this much (0.3 is a lot)
 * - any part: "dx" and "dy" in pixels
 *
 * Angles are in 3D terms, and the pose maths works out how they look from the way the mob is
 * facing: a raised arm points out sideways from the front and barely moves side-on, a swung
 * arm does the opposite and foreshortens from the front. So one pose works for all four
 * directions, and turning mid-animation still looks right.
 *
 * Arms and legs are two pieces each, laid along a little joint chain: shoulder to elbow to
 * hand, hip to knee to foot. Each piece gets its own complete transform rather than hanging
 * off the one above it, so foreshortening the upper arm doesn't squash the forearm too.
 * Limbs are also drawn longer than the sprite (RIG_ARM_STRETCH, RIG_LEG_STRETCH, or whatever
 * the species' limb_rig_shape says), and the body is lifted so the lowest foot always rests on
 * the floor, whatever the legs are doing. A species can also give the rig a posture, which is
 * added to every pose (a hunch, say), and its own walk.
 *
 * A sequence is a list of keyframes, each list(pose, time in deciseconds).
 */

/// Heights of the elbow, the middle of the hand, the knee and the sole, in BYOND pixel
/// coordinates from the bottom of the sprite. The same in every direction.
#define RIG_ELBOW_Y 17
#define RIG_HAND_Y 12.5
#define RIG_KNEE_Y 5
#define RIG_SOLE_Y 0

/// Joint positions per part and direction, in BYOND pixel coordinates (from the bottom left).
/// Arms swing at the shoulder, legs at the hip, the head at the neck, the torso at the hips.
/proc/get_rig_joint(part_id, facing)
	switch(part_id)
		if(RIG_HEAD)
			return (facing & (NORTH|SOUTH)) ? list(16, 23) : list(16, 22)
		if(RIG_CHEST)
			return list(16, 11)
		if(RIG_L_ARM)
			switch(facing)
				if(NORTH)
					return list(11, 21)
				if(SOUTH)
					return list(21, 21)
				if(EAST)
					return list(17, 20)
				else
					return list(19, 20)
		if(RIG_R_ARM)
			switch(facing)
				if(NORTH)
					return list(21, 21)
				if(SOUTH)
					return list(11, 21)
				if(EAST)
					return list(14, 20)
				else
					return list(16, 20)
		if(RIG_L_LEG)
			switch(facing)
				if(NORTH)
					return list(14, 10)
				if(SOUTH)
					return list(18, 10)
				else
					return list(16, 10)
		if(RIG_R_LEG)
			switch(facing)
				if(NORTH)
					return list(18, 10)
				if(SOUTH)
					return list(14, 10)
				else
					return list(17, 10)
	return list(16, 16)

/// A transform that scales a piece along its length (and optionally across it) from a point,
/// turns it about that point, then moves that point somewhere else. Points are in BYOND pixel
/// coordinates.
/proc/rig_joint_matrix(from_x, from_y, length_scale, angle, to_x, to_y, width_scale = 1)
	var/matrix/joint = matrix()
	joint.Translate(16.5 - from_x, 16.5 - from_y)
	joint.Scale(width_scale, length_scale)
	joint.Turn(angle)
	joint.Translate(to_x - 16.5, to_y - 16.5)
	return joint

/**
 * Transforms for the head or torso in a pose.
 */
/proc/rig_pose_matrix(part_id, list/entry, facing)
	var/front = (facing == NORTH || facing == SOUTH)
	var/angle = 0
	var/scale_y = 1
	var/dy = entry?["dy"] || 0
	switch(part_id)
		if(RIG_HEAD)
			var/nod = entry?["nod"] || 0
			var/tilt = entry?["tilt"] || 0
			if(front)
				angle = facing == SOUTH ? -tilt : tilt
				dy -= nod / 15
			else
				angle = facing == EAST ? nod : -nod
		if(RIG_CHEST)
			var/bend = entry?["bend"] || 0
			var/lean = entry?["lean"] || 0
			if(front)
				angle = facing == SOUTH ? -lean : lean
				scale_y = cos(bend)
			else
				angle = facing == EAST ? bend : -bend
			scale_y *= 1 + (entry?["breath"] || 0)
	var/list/joint = get_rig_joint(part_id, facing)
	var/matrix/pose = rig_joint_matrix(joint[1], joint[2], scale_y, angle, joint[1], joint[2])
	var/skew = entry?["skew"]
	if(skew)
		pose = matrix(1, skew, 0, 0, 1, 0) * pose
	pose.Translate(entry?["dx"] || 0, dy)
	return pose

/**
 * Transforms for one arm or leg in a pose.
 *
 * Returns list(upper piece, lower piece, end, fingers, end height, middle finger). The end is
 * for whatever rides on the hand without being stretched (held items). Fingers are stretched by
 * finger_stretch and foreshortened with the forearm, so they point the way the hand does. The
 * end height is where the hand or foot finished up, before any lift.
 *
 * * bend - how far the torso is bent forward, for arms: they hang off it and tip back with it.
 */
/proc/rig_limb_matrices(part_id, list/entry, facing, stretch, finger_stretch = 1, bend = 0)
	var/is_leg = (part_id == RIG_L_LEG || part_id == RIG_R_LEG)
	var/list/root = get_rig_joint(part_id, facing)
	var/mid_y = is_leg ? RIG_KNEE_Y : RIG_ELBOW_Y
	var/end_y = is_leg ? RIG_SOLE_Y : RIG_HAND_Y
	var/upper_length = root[2] - mid_y
	var/lower_length = mid_y - end_y

	var/raise = entry?["raise"] || 0
	var/swing = entry?["swing"] || 0
	// Elbows fold the forearm forward; knees fold the shin back.
	var/lower_swing = swing + (is_leg ? -(entry?["knee"] || 0) : (entry?["elbow"] || 0))
	var/hand_y = entry?["hand_y"]
	if(!isnull(hand_y))
		// Bend the elbow however far it takes to put the hand at that height. Heights come out
		// the same from every side, so this holds whichever way the mob faces. It's worked out
		// as things really stand with the torso bent over, which takes the face down with it.
		var/hips_y = get_rig_joint(RIG_CHEST, facing)[2]
		var/shoulder_height = hips_y + (root[2] - hips_y) * cos(bend)
		var/target_height = hips_y + (hand_y - hips_y) * cos(bend)
		var/elbow_height = shoulder_height - upper_length * stretch * cos(swing - bend) * cos(raise)
		var/forearm_drop = lower_length * stretch * max(cos(raise), 0.1)
		lower_swing = arccos(clamp((elbow_height - target_height) / forearm_drop, -1, 1)) + bend

	var/upper_angle
	var/lower_angle
	var/upper_scale
	var/lower_scale
	// How much bigger the hand draws for being closer to the viewer.
	var/near = 1
	if(facing == NORTH || facing == SOUTH)
		// From the front, the mob's right side is on the left of the screen. From behind it flips.
		var/right = (part_id == RIG_R_ARM || part_id == RIG_R_LEG)
		upper_angle = (right == (facing == SOUTH)) ? raise : -raise
		lower_angle = upper_angle
		// Swinging toward or away from the viewer just shortens the limb. Past 90 degrees the
		// scale goes negative and the piece flips up over its joint. Arms go by where they really
		// point once the torso's bend tips them back, and undo the squash the bending torso already
		// gives everything on it.
		var/torso_squash = max(cos(bend), 0.25)
		upper_scale = cos(swing - bend) / torso_squash
		lower_scale = cos(lower_swing - bend) / torso_squash
		if(!is_leg)
			// Closer is bigger: a hand reaching out at the viewer grows, one reaching away shrinks.
			var/toward = sin(lower_swing - bend) * (facing == SOUTH ? 1 : -1)
			near = 1 + toward * (toward > 0 ? 0.35 : 0.15)
	else
		upper_angle = facing == EAST ? -swing : swing
		lower_angle = facing == EAST ? -lower_swing : lower_swing
		upper_scale = cos(raise)
		lower_scale = upper_scale
	upper_scale *= stretch
	lower_scale *= stretch

	var/offset_x = entry?["dx"] || 0
	var/offset_y = entry?["dy"] || 0
	var/root_x = root[1] + offset_x
	var/root_y = root[2] + offset_y
	// Where the elbow or knee ends up, and then the hand or foot. Turn() is clockwise.
	var/mid_x = root_x - upper_length * upper_scale * sin(upper_angle)
	var/mid_to_y = root_y - upper_length * upper_scale * cos(upper_angle)
	var/end_x = mid_x - lower_length * lower_scale * sin(lower_angle)
	var/end_to_y = mid_to_y - lower_length * lower_scale * cos(lower_angle)
	// Fingers foreshorten with the forearm, but never all the way: pointed straight at the
	// viewer they'd collapse into a flat line.
	var/finger_foreshorten = lower_scale / stretch
	var/finger_scale = near * finger_stretch * (finger_foreshorten < 0 ? -1 : 1) * max(abs(finger_foreshorten), 0.4)
	return list(
		rig_joint_matrix(root[1], root[2], upper_scale, upper_angle, root_x, root_y),
		rig_joint_matrix(root[1], mid_y, lower_scale, lower_angle, mid_x, mid_to_y, near),
		rig_joint_matrix(root[1], end_y, near, lower_angle, end_x, end_to_y, near),
		rig_joint_matrix(root[1], end_y, finger_scale * (1 + (entry?["reach"] || 0)), lower_angle, end_x, end_to_y, near),
		end_to_y,
		rig_joint_matrix(root[1], end_y, finger_scale * max(0.05, 1 + (entry?["bird"] || 0)), lower_angle, end_x, end_to_y, near),
	)

/// Adds a posture to a pose, angle by angle.
/proc/rig_merge_pose(list/posture, list/pose)
	if(!posture)
		return pose
	. = list()
	for(var/part_id in posture | (pose || list()))
		var/list/merged = list()
		var/list/base_entry = posture[part_id]
		var/list/pose_entry = pose?[part_id]
		for(var/key in base_entry)
			merged[key] = base_entry[key]
		for(var/key in pose_entry)
			merged[key] = (merged[key] || 0) + pose_entry[key]
		.[part_id] = merged

/**
 * Turns any "aim" on the arms of a pose into the swing that points them that way, once the
 * posture and the torso's bend are added on. Returns the pose, or a changed copy.
 */
/proc/rig_resolve_aim(list/posture, list/pose)
	. = pose
	for(var/arm_id in list(RIG_L_ARM, RIG_R_ARM))
		var/list/entry = pose?[arm_id]
		if(isnull(entry?["aim"]))
			continue
		if(. == pose)
			. = pose.Copy()
		var/list/posture_chest = posture?[RIG_CHEST]
		var/list/pose_chest = pose[RIG_CHEST]
		var/bend = (posture_chest?["bend"] || 0) + (pose_chest?["bend"] || 0)
		var/list/posture_arm = posture?[arm_id]
		var/list/aimed = entry.Copy()
		aimed -= "aim"
		// The posture's swing and elbow are added back on when it's merged, so take them off here.
		aimed["swing"] = entry["aim"] + bend - (posture_arm?["swing"] || 0)
		aimed["elbow"] = (entry["elbow"] || 0) - (posture_arm?["elbow"] || 0)
		.[arm_id] = aimed

/// The transform for every moving piece in a pose, seen from the given direction.
/datum/limb_rig/proc/get_pose_matrices(list/pose, facing)
	. = list()
	pose = rig_merge_pose(posture, rig_resolve_aim(posture, pose))
	var/list/legs = list()
	var/lowest_foot = INFINITY
	var/list/chest_entry = pose?[RIG_CHEST]
	var/bend = chest_entry?["bend"] || 0
	for(var/side in list("l", "r"))
		var/arm_id = side == "l" ? RIG_L_ARM : RIG_R_ARM
		// With no fingers dangling off the end, a stretched arm stops short of whatever it's
		// holding, so it reaches a little further to get there.
		var/obj/item/bodypart/arm/hand = owner.get_bodypart(side == "l" ? BODY_ZONE_L_ARM : BODY_ZONE_R_ARM)
		var/stretch = arm_stretch * (hand?.should_draw_fingers() ? 1 : RIG_FINGERLESS_ARM_STRETCH)
		var/list/arm = rig_limb_matrices(arm_id, pose?[arm_id], facing, stretch, finger_stretch, bend)
		.[parts[arm_id]] = arm[1]
		.[parts["[side]_forearm"]] = arm[2]
		.[item_parts[side]] = arm[3]
		.[finger_parts[side]] = arm[4]
		.[bird_parts[side]] = arm[6]
		var/leg_id = side == "l" ? RIG_L_LEG : RIG_R_LEG
		var/list/leg = rig_limb_matrices(leg_id, pose?[leg_id], facing, leg_stretch)
		legs[parts[leg_id]] = leg[1]
		legs[parts["[side]_shin"]] = leg[2]
		lowest_foot = min(lowest_foot, leg[5])
	// Stand the body up (or crouch it down) so the lowest foot is on the floor.
	// "air" on the torso then lifts the whole body off the floor on top of that, for jumps and
	// the airborne part of a run.
	var/lift = RIG_SOLE_Y - lowest_foot + (chest_entry?["air"] || 0)
	for(var/obj/effect/abstract/limb_rig_part/leg_part as anything in legs)
		var/matrix/leg_matrix = legs[leg_part]
		leg_matrix.Translate(0, lift)
		.[leg_part] = leg_matrix
	var/matrix/torso = rig_pose_matrix(RIG_CHEST, pose?[RIG_CHEST], facing)
	torso.Translate(0, lift)
	.[pivot] = torso
	.[parts[RIG_HEAD]] = rig_pose_matrix(RIG_HEAD, pose?[RIG_HEAD], facing)

/// Puts every piece in a pose immediately.
/datum/limb_rig/proc/snap_to(list/pose)
	var/list/matrices = get_pose_matrices(pose, owner.dir)
	for(var/obj/effect/abstract/limb_rig_part/part as anything in matrices)
		animate(part, transform = matrices[part], time = 0)

/**
 * Animates every piece through a sequence of keyframes.
 *
 * * keyframes - list of list(pose, deciseconds), with an optional third entry for the easing
 * * loop - how many times to play it, -1 for forever
 * * activity - what the rig is doing while this plays
 * * settle_after - go back to idle once the sequence has played through (ignored when looping)
 */
/datum/limb_rig/proc/play(list/keyframes, loop = 1, activity = RIG_ACTIVITY_ONESHOT, settle_after = TRUE)
	src.activity = activity
	deltimer(settle_timer)
	settle_timer = null
	var/facing = owner.dir
	var/total_time = 0
	for(var/list/keyframe as anything in keyframes)
		total_time += keyframe[2]
	var/list/last_keyframe = keyframes[length(keyframes)]
	held_pose = last_keyframe[1]
	var/list/matrices_per_keyframe = list()
	for(var/list/keyframe as anything in keyframes)
		matrices_per_keyframe += list(get_pose_matrices(keyframe[1], facing))
	for(var/obj/effect/abstract/limb_rig_part/part as anything in matrices_per_keyframe[1])
		for(var/i in 1 to length(keyframes))
			var/list/keyframe = keyframes[i]
			var/list/matrices = matrices_per_keyframe[i]
			var/easing = length(keyframe) >= 3 ? keyframe[3] : SINE_EASING
			if(i == 1)
				animate(part, transform = matrices[part], time = keyframe[2], loop = loop, easing = easing)
			else
				animate(transform = matrices[part], time = keyframe[2], easing = easing)
	if(settle_after && loop == 1)
		settle_timer = addtimer(CALLBACK(src, PROC_REF(settle)), total_time, TIMER_STOPPABLE|TIMER_DELETE_ME)

/// Goes back to the right background loop: working a tool, or just breathing.
/datum/limb_rig/proc/settle()
	deltimer(settle_timer)
	settle_timer = null
	if(QDELETED(owner))
		return
	if(working && owner.stat == CONSCIOUS)
		play_work()
		return
	if(wants_menace())
		play_menace()
		return
	menacing = FALSE
	menace_reach = 0
	stop_menace_fx()
	var/deep = owner.stat != CONSCIOUS
	var/list/inhale = list(RIG_CHEST = list("breath" = deep ? 0.05 : 0.035), RIG_HEAD = list("nod" = deep ? 4 : 0))
	var/list/exhale = list(RIG_HEAD = list("nod" = deep ? 4 : 0))
	play(list(
		list(inhale, deep ? 22 : 15),
		list(exhale, deep ? 28 : 20),
	), loop = -1, activity = RIG_ACTIVITY_IDLE)
	held_pose = exhale

/// Whether this body should be in its empty-handed combat stance: reaching out, fingers creeping.
/datum/limb_rig/proc/wants_menace()
	if(!can_menace || !owner.combat_mode || owner.stat != CONSCIOUS || owner.body_position == LYING_DOWN)
		return FALSE
	for(var/obj/item/held in owner.held_items)
		if(!(held.item_flags & (ABSTRACT|HAND_ITEM)))
			return FALSE
	return TRUE

/// How far the fingers can stretch in the combat stance, on top of their usual length (2 is triple).
#define MENACE_MAX_REACH 2
/// Each beat of the stance closes this much of the gap to MENACE_MAX_REACH: fast at first, then
/// slower and slower as the fingers strain toward their limit.
#define MENACE_REACH_RATE 0.12

/// Stretches the fingers one beat further toward their limit. They never shrink back mid-stance.
/datum/limb_rig/proc/grow_menace_reach(beats = 1)
	for(var/beat in 1 to beats)
		menace_reach += (MENACE_MAX_REACH - menace_reach) * MENACE_REACH_RATE
	return menace_reach

/// Stance arms: dead level out in front however hunched the body is, spread a little so they
/// read from the front too, twitching sideways, fingers at their current stretch. The aim stays
/// put, since from the front it'd change how long the arms and fingers look, and read as pulsing.
/proc/rig_menace_arm(reach, twitch)
	return list("aim" = 90, "raise" = 20 + rand(-twitch, twitch), "reach" = reach)

/// A walking keyframe with the arms swapped for the reaching, twitching combat stance.
/proc/rig_menace_step(list/step, reach)
	var/list/stalking = step.Copy()
	stalking[RIG_L_ARM] = rig_menace_arm(reach, 6)
	stalking[RIG_R_ARM] = rig_menace_arm(reach, 6)
	var/list/old_chest = step[RIG_CHEST] || list()
	var/list/chest = old_chest.Copy()
	chest["bend"] = (chest["bend"] || 0) + 8 + rand(-3, 3)
	chest["dx"] = rand(-1, 1) / 2
	stalking[RIG_CHEST] = chest
	var/list/old_head = step[RIG_HEAD] || list()
	var/list/head = old_head.Copy()
	head["nod"] = (head["nod"] || 0) - 6 + rand(-6, 6)
	head["tilt"] = (head["tilt"] || 0) + rand(-8, 8)
	stalking[RIG_HEAD] = head
	return stalking

/**
 * Arms out in front, fingers stretching out after them, the whole body trembling.
 *
 * Plays a short stretch of tremble and comes back here when it's done, so the fingers keep
 * stretching from wherever they got to until they hit their limit, and then hold. The tremble
 * itself is a smooth shiver; the jerks are the odd stop-motion snap in among it.
 */
/datum/limb_rig/proc/play_menace()
	menacing = TRUE
	start_menace_fx()
	var/list/tremble = list()
	for(var/shudder in 1 to 12)
		var/reach = grow_menace_reach()
		if(shudder == 6 || shudder == 12)
			// Stop-motion: hold the last pose, then snap to a worse one, sheared and wrenched.
			tremble += list(list(list(
				RIG_L_ARM = rig_menace_arm(reach, 14),
				RIG_R_ARM = rig_menace_arm(reach, 14),
				RIG_CHEST = list("bend" = 8 + rand(-8, 12), "lean" = rand(-10, 10), "skew" = rand(-25, 25) / 100),
				RIG_HEAD = list("nod" = rand(-30, 25), "tilt" = rand(-35, 35), "skew" = rand(-40, 40) / 100),
				RIG_L_LEG = list("knee" = rand(0, 20)),
				RIG_R_LEG = list("knee" = rand(0, 20)),
			), rand(2, 4), JUMP_EASING))
			continue
		// Swaying from side to side and back, a little off each time.
		var/sway = (shudder % 2) ? 1 : -1
		tremble += list(list(list(
			RIG_L_ARM = rig_menace_arm(reach, 3),
			RIG_R_ARM = rig_menace_arm(reach, 3),
			RIG_CHEST = list("bend" = 8 + rand(-2, 2), "lean" = sway * rand(1, 3)),
			RIG_HEAD = list("nod" = -6 + rand(-4, 4), "tilt" = sway * rand(2, 6)),
			RIG_L_LEG = list("knee" = rand(0, 6)),
			RIG_R_LEG = list("knee" = rand(0, 6)),
		), 1.2))
	play(tremble, activity = RIG_ACTIVITY_MENACE)

/// How long crossing one tile takes right now, in deciseconds: whatever slows or speeds the mob up.
/datum/limb_rig/proc/get_move_delay()
	var/delay = owner.cached_multiplicative_slowdown
	if(!delay)
		delay = world.icon_size / max(owner.glide_size, 1) * world.tick_lag
	return clamp(delay, 0.5, 20)

/// How many tiles one step covers. Longer legs take longer strides, and running ones longer again.
/datum/limb_rig/proc/get_stride_tiles(running)
	return (running ? 1.4 : 1.25) * sqrt(leg_stretch / RIG_LEG_STRETCH)

/// How big to make each step: moving faster than usual for the gait means bigger, bouncier
/// strides, slower means little shuffling ones.
/datum/limb_rig/proc/get_gait_scale(running)
	var/usual_delay = running ? CONFIG_GET(number/movedelay/run_delay) : CONFIG_GET(number/movedelay/walk_delay)
	return clamp(sqrt(max(usual_delay, 0.5) / get_move_delay()), 0.6, 1.4)

/// A copy of a stepping pose with its swings, knees, lean and airtime scaled up or down.
/proc/rig_scale_gait(list/pose, amount)
	. = list()
	for(var/part_id in pose)
		var/list/entry = pose[part_id]
		var/list/scaled = entry.Copy()
		for(var/key in list("swing", "knee", "air", "lean", "tilt"))
			if(scaled[key])
				scaled[key] = scaled[key] * amount
		.[part_id] = scaled

/**
 * One step of walking, or one pull of crawling when lying down.
 *
 * A step takes as long as the mob takes to cross however many tiles one stride covers, so the
 * legs keep time with the actual movement speed, and long legs stride slower. Moves that land
 * mid-stride just keep it going.
 */
/datum/limb_rig/proc/play_step()
	if(activity == RIG_ACTIVITY_ONESHOT)
		return // Let an emote or a swing finish; the next step catches up.
	var/move_delay = get_move_delay()
	if(activity == RIG_ACTIVITY_MOVING && world.time < step_ends_at - move_delay * 0.5)
		// Still mid-stride. Put off standing still until this move is over too.
		deltimer(settle_timer)
		settle_timer = addtimer(CALLBACK(src, PROC_REF(settle)), step_ends_at - world.time + move_delay + 1, TIMER_STOPPABLE|TIMER_DELETE_ME)
		return
	var/lying = owner.body_position == LYING_DOWN
	var/running = !lying && owner.move_intent == MOVE_INTENT_RUN
	var/step_time = lying ? move_delay : move_delay * get_stride_tiles(running)
	step_ends_at = world.time + step_time
	left_foot_forward = !left_foot_forward
	var/lead = left_foot_forward ? 1 : -1
	var/list/stride
	var/list/passing
	var/list/keyframes
	if(lying)
		// Crawling: one arm reaches past the head and drags, the legs kick a little.
		stride = list(
			RIG_L_ARM = list("raise" = lead > 0 ? 165 : 70, "elbow" = lead > 0 ? 10 : 70),
			RIG_R_ARM = list("raise" = lead > 0 ? 70 : 165, "elbow" = lead > 0 ? 70 : 10),
			RIG_L_LEG = list("raise" = 12 * lead, "knee" = lead > 0 ? 50 : 10),
			RIG_R_LEG = list("raise" = -12 * lead, "knee" = lead > 0 ? 10 : 50),
			RIG_HEAD = list("nod" = -10),
		)
		passing = list(
			RIG_L_ARM = list("raise" = 110, "elbow" = 40),
			RIG_R_ARM = list("raise" = 110, "elbow" = 40),
			RIG_HEAD = list("nod" = -6),
			RIG_CHEST = list("dx" = 1),
		)
	else if(running)
		// Running, after Kris's run in Deltarune, in the four poses a good run needs:
		// contact (front leg reaching, nearly straight), down (the stomp: body drops and squashes,
		// the planted knee gives), push (driving off) and up (off the ground, stretched out,
		// trailing knee tucked). Slamming fast into the down pose and holding it for a moment is
		// what gives it weight.
		var/list/contact = list(
			RIG_L_LEG = list("swing" = 40 * lead, "knee" = lead > 0 ? 5 : 60),
			RIG_R_LEG = list("swing" = -40 * lead, "knee" = lead > 0 ? 60 : 5),
			RIG_L_ARM = list("swing" = -50 * lead, "raise" = 6, "elbow" = 95),
			RIG_R_ARM = list("swing" = 50 * lead, "raise" = 6, "elbow" = 95),
			RIG_CHEST = list("bend" = 14, "lean" = 3 * lead),
			RIG_HEAD = list("nod" = -10, "tilt" = -3 * lead),
		)
		var/list/down = list(
			RIG_L_LEG = list("swing" = lead > 0 ? 25 : -20, "knee" = lead > 0 ? 45 : 70),
			RIG_R_LEG = list("swing" = lead > 0 ? -20 : 25, "knee" = lead > 0 ? 70 : 45),
			RIG_L_ARM = list("swing" = -40 * lead, "raise" = 8, "elbow" = 105),
			RIG_R_ARM = list("swing" = 40 * lead, "raise" = 8, "elbow" = 105),
			RIG_CHEST = list("bend" = 20, "lean" = 4 * lead, "breath" = -0.07),
			RIG_HEAD = list("nod" = 4, "tilt" = -4 * lead),
		)
		var/list/push = list(
			RIG_L_LEG = list("swing" = lead > 0 ? -15 : 40, "knee" = lead > 0 ? 10 : 110),
			RIG_R_LEG = list("swing" = lead > 0 ? 40 : -15, "knee" = lead > 0 ? 110 : 10),
			RIG_L_ARM = list("swing" = 10 * lead, "raise" = 6, "elbow" = 95),
			RIG_R_ARM = list("swing" = -10 * lead, "raise" = 6, "elbow" = 95),
			RIG_CHEST = list("bend" = 16, "air" = 1),
			RIG_HEAD = list("nod" = -8),
		)
		var/list/up = list(
			RIG_L_LEG = list("swing" = lead > 0 ? -35 : 50, "knee" = lead > 0 ? 50 : 90),
			RIG_R_LEG = list("swing" = lead > 0 ? 50 : -35, "knee" = lead > 0 ? 90 : 50),
			RIG_L_ARM = list("swing" = 45 * lead, "raise" = 6, "elbow" = 90),
			RIG_R_ARM = list("swing" = -45 * lead, "raise" = 6, "elbow" = 90),
			RIG_CHEST = list("bend" = 12, "lean" = -3 * lead, "breath" = 0.04, "air" = 3),
			RIG_HEAD = list("nod" = -12, "tilt" = 3 * lead),
		)
		keyframes = list(
			list(contact, step_time * 0.15, SINE_EASING | EASE_IN),
			list(down, step_time * 0.2, CUBIC_EASING | EASE_OUT),
			list(down, step_time * 0.1),
			list(push, step_time * 0.2, QUAD_EASING | EASE_OUT),
			list(up, step_time * 0.35, SINE_EASING | EASE_OUT),
		)
	else if(walk_style == RIG_WALK_LOPE)
		// Long legs: huge strides, the trailing knee hauled up high, the body swaying side to
		// side and the arms swinging loose from the elbow.
		stride = list(
			RIG_L_LEG = list("swing" = 38 * lead, "knee" = lead > 0 ? 4 : 35),
			RIG_R_LEG = list("swing" = -38 * lead, "knee" = lead > 0 ? 35 : 4),
			RIG_L_ARM = list("swing" = -30 * lead, "raise" = 6, "elbow" = lead > 0 ? 5 : 50),
			RIG_R_ARM = list("swing" = 30 * lead, "raise" = 6, "elbow" = lead > 0 ? 50 : 5),
			RIG_CHEST = list("lean" = 7 * lead, "bend" = 4),
			RIG_HEAD = list("tilt" = -8 * lead, "nod" = 4),
		)
		passing = list(
			RIG_L_LEG = list("swing" = lead > 0 ? 0 : 30, "knee" = lead > 0 ? 0 : 80),
			RIG_R_LEG = list("swing" = lead > 0 ? 30 : 0, "knee" = lead > 0 ? 80 : 0),
			RIG_L_ARM = list("raise" = 8, "elbow" = 30),
			RIG_R_ARM = list("raise" = 8, "elbow" = 30),
			RIG_CHEST = list("lean" = 2 * lead, "bend" = -2),
			RIG_HEAD = list("nod" = -4),
		)
	else
		// Front leg planted almost straight, back leg pushing off with a bent knee.
		stride = list(
			RIG_L_LEG = list("swing" = 26 * lead, "knee" = lead > 0 ? 6 : 28),
			RIG_R_LEG = list("swing" = -26 * lead, "knee" = lead > 0 ? 28 : 6),
			RIG_L_ARM = list("swing" = -22 * lead, "raise" = 4, "elbow" = lead > 0 ? 8 : 30),
			RIG_R_ARM = list("swing" = 22 * lead, "raise" = 4, "elbow" = lead > 0 ? 30 : 8),
			RIG_CHEST = list("bend" = 3, "lean" = 2 * lead),
			RIG_HEAD = list("tilt" = -2 * lead),
		)
		// The trailing leg swings through with its knee lifted.
		passing = list(
			RIG_CHEST = list("dy" = 1, "bend" = 2),
			RIG_L_LEG = list("swing" = lead > 0 ? 0 : 18, "knee" = lead > 0 ? 0 : 45),
			RIG_R_LEG = list("swing" = lead > 0 ? 18 : 0, "knee" = lead > 0 ? 45 : 0),
			RIG_L_ARM = list("raise" = 4, "elbow" = 15),
			RIG_R_ARM = list("raise" = 4, "elbow" = 15),
		)
	if(!lying)
		var/gait = get_gait_scale(running)
		if(keyframes)
			for(var/list/keyframe as anything in keyframes)
				keyframe[1] = rig_scale_gait(keyframe[1], gait)
		else
			stride = rig_scale_gait(stride, gait)
			passing = rig_scale_gait(passing, gait)
	if(!lying && wants_menace())
		// Stalking: the legs keep loping, but the arms stay out in front, fingers stretching and
		// twitching, and the rest of the body shudders as it goes.
		menacing = TRUE
		start_menace_fx()
		if(keyframes)
			for(var/list/keyframe as anything in keyframes)
				keyframe[1] = rig_menace_step(keyframe[1], grow_menace_reach(1))
		else
			stride = rig_menace_step(stride, grow_menace_reach(2))
			passing = rig_menace_step(passing, grow_menace_reach(2))
	if(!keyframes)
		keyframes = list(list(stride, step_time * 0.5), list(passing, step_time * 0.5))
	play(keyframes, activity = RIG_ACTIVITY_MOVING, settle_after = FALSE)
	// Stand still again if no step follows.
	settle_timer = addtimer(CALLBACK(src, PROC_REF(settle)), max(step_time, move_delay) + 1, TIMER_STOPPABLE|TIMER_DELETE_ME)

/// The working hand saws away until the progress bar is done.
/datum/limb_rig/proc/play_work()
	var/arm = IS_RIGHT_INDEX(owner.active_hand_index) ? RIG_R_ARM : RIG_L_ARM
	var/list/push = list(RIG_HEAD = list("nod" = 14), RIG_CHEST = list("bend" = 6))
	push[arm] = list("swing" = 35, "raise" = 12, "elbow" = 55)
	var/list/pull = list(RIG_HEAD = list("nod" = 12), RIG_CHEST = list("bend" = 5))
	pull[arm] = list("swing" = 20, "raise" = 6, "elbow" = 95)
	play(list(list(push, 3), list(pull, 3)), loop = -1, activity = RIG_ACTIVITY_WORKING)

/// A quick swing of the active arm, for hitting things.
/datum/limb_rig/proc/play_attack()
	var/arm = IS_RIGHT_INDEX(owner.active_hand_index) ? RIG_R_ARM : RIG_L_ARM
	var/list/wind_up = list(RIG_CHEST = list("bend" = -6))
	wind_up[arm] = list("swing" = 100, "raise" = 15, "elbow" = 60)
	var/list/follow_through = list(RIG_CHEST = list("bend" = 10))
	follow_through[arm] = list("swing" = 70, "raise" = 10, "elbow" = 0)
	play(list(list(wind_up, 1), list(follow_through, 1), list(null, 2.5)))

/// An arm with the forearm held straight up in front of the shoulder, middle finger this far out.
/proc/rig_bird_arm(bird)
	return list("swing" = 20, "raise" = 20, "elbow" = 155, "bird" = bird)

/**
 * Flips someone off with the active hand.
 *
 * * slow - instead of just raising it, the hand comes up as a fist and the other hand cranks
 *   an invisible lever while the middle finger slowly unfurls.
 */
/datum/limb_rig/proc/play_bird(slow)
	var/right = IS_RIGHT_INDEX(owner.active_hand_index)
	var/bird_arm = right ? RIG_R_ARM : RIG_L_ARM
	var/crank_arm = right ? RIG_L_ARM : RIG_R_ARM
	// Forearm straight up in front of the shoulder.
	var/list/raised = rig_bird_arm(0)
	if(!slow)
		var/list/up = list(RIG_HEAD = list("tilt" = 8), RIG_CHEST = list("lean" = 3))
		up[bird_arm] = raised
		play(list(list(up, 2), list(up, 12), list(null, 3)))
		return
	var/list/keyframes = list()
	var/list/start = list(RIG_HEAD = list("nod" = 6))
	start[bird_arm] = rig_bird_arm(-0.95)
	start[crank_arm] = list("swing" = 50, "elbow" = 60, "raise" = -10)
	keyframes += list(list(start, 3))
	// Three turns of the crank, four keyframes a turn, the finger coming up a little each time.
	var/list/crank_positions = list(
		list("swing" = 70, "elbow" = 100, "raise" = -15),
		list("swing" = 90, "elbow" = 60, "raise" = -10),
		list("swing" = 70, "elbow" = 20, "raise" = -5),
		list("swing" = 50, "elbow" = 60, "raise" = -10),
	)
	var/turns = 12
	for(var/turn in 1 to turns)
		var/list/frame = list(RIG_HEAD = list("nod" = 6, "tilt" = (turn % 2) ? 3 : -3))
		frame[bird_arm] = rig_bird_arm(-0.95 + 0.95 * turn / turns)
		frame[crank_arm] = crank_positions[((turn - 1) % 4) + 1]
		keyframes += list(list(frame, 1.5))
	var/list/done = list(RIG_HEAD = list("tilt" = 8), RIG_CHEST = list("lean" = 3))
	done[bird_arm] = raised
	keyframes += list(list(done, 2), list(done, 12), list(null, 3))
	play(keyframes)

/// Acts out an emote, if there's an animation for it.
/datum/limb_rig/proc/play_emote(emote_key)
	switch(emote_key)
		if("bird")
			play_bird(slow = FALSE)
			return
		if("crankbird")
			play_bird(slow = TRUE)
			return
	var/list/keyframes = get_rig_emote(emote_key)
	if(keyframes)
		play(keyframes)

/// The keyframes for an emote, or null if it doesn't move anything.
/proc/get_rig_emote(emote_key)
	switch(emote_key)
		if("wave")
			var/list/up = list(RIG_R_ARM = list("raise" = 120, "elbow" = 40), RIG_HEAD = list("tilt" = 6))
			var/list/over = list(RIG_R_ARM = list("raise" = 125, "elbow" = 0), RIG_HEAD = list("tilt" = 6))
			return list(list(up, 2), list(over, 1.5), list(up, 1.5), list(over, 1.5), list(up, 1.5), list(null, 2))
		if("clap")
			var/list/apart = list(RIG_L_ARM = list("swing" = 35, "raise" = -5, "elbow" = 60), RIG_R_ARM = list("swing" = 35, "raise" = -5, "elbow" = 60))
			var/list/together = list(RIG_L_ARM = list("swing" = 35, "raise" = -25, "elbow" = 60), RIG_R_ARM = list("swing" = 35, "raise" = -25, "elbow" = 60))
			return list(list(apart, 1.5), list(together, 1), list(apart, 1), list(together, 1), list(apart, 1), list(together, 1), list(null, 2))
		if("shrug")
			var/list/shrug = list(RIG_L_ARM = list("raise" = 35, "swing" = 35), RIG_R_ARM = list("raise" = 35, "swing" = 35), RIG_HEAD = list("tilt" = 12), RIG_CHEST = list("dy" = 1))
			return list(list(shrug, 2), list(shrug, 6), list(null, 3))
		if("nod")
			var/list/down = list(RIG_HEAD = list("nod" = 22))
			return list(list(down, 1.5), list(null, 1.5), list(down, 1.5), list(null, 1.5))
		if("shake")
			var/list/left = list(RIG_HEAD = list("tilt" = -14))
			var/list/right = list(RIG_HEAD = list("tilt" = 14))
			return list(list(left, 1), list(right, 1.5), list(left, 1.5), list(right, 1.5), list(null, 1))
		if("point")
			var/list/point = list(RIG_R_ARM = list("swing" = 90, "raise" = 20), RIG_HEAD = list("nod" = -4))
			return list(list(point, 1.5), list(point, 12), list(null, 3))
		if("salute")
			var/list/salute = list(RIG_R_ARM = list("raise" = 90, "swing" = 20, "elbow" = 130), RIG_CHEST = list("dy" = 1))
			return list(list(salute, 2), list(salute, 10), list(null, 3))
		if("bow", "curtsy")
			var/list/bow = list(RIG_CHEST = list("bend" = 45), RIG_HEAD = list("nod" = 20), RIG_L_ARM = list("swing" = 20), RIG_R_ARM = list("swing" = 20))
			return list(list(bow, 4), list(bow, 6), list(null, 5))
		if("laugh", "giggle", "chuckle", "cackle", "snicker")
			var/list/up = list(RIG_CHEST = list("bend" = -8, "dy" = 1), RIG_HEAD = list("nod" = -18))
			var/list/down = list(RIG_CHEST = list("bend" = 6), RIG_HEAD = list("nod" = -8))
			return list(list(up, 1.5), list(down, 1.5), list(up, 1.5), list(down, 1.5), list(up, 1.5), list(null, 2.5))
		if("cry", "sob", "whimper", "sniff")
			// Face buried in both hands, elbows up and out so the forearms fold in over it, shoulders
			// hitching with each sob: a sharp gulp in, a slow shudder out.
			var/list/cry = list(RIG_HEAD = list("nod" = 22), RIG_L_ARM = list("swing" = 55, "raise" = 25, "hand_y" = 25), RIG_R_ARM = list("swing" = 55, "raise" = 25, "hand_y" = 25), RIG_CHEST = list("bend" = 10))
			var/list/sob = list(RIG_HEAD = list("nod" = 16), RIG_L_ARM = list("swing" = 58, "raise" = 27, "hand_y" = 26), RIG_R_ARM = list("swing" = 58, "raise" = 27, "hand_y" = 26), RIG_CHEST = list("bend" = 6, "breath" = 0.05, "dy" = 1))
			. = list(list(cry, 3))
			for(var/hitch in 1 to 3)
				. += list(list(sob, 0.8, CUBIC_EASING | EASE_OUT), list(cry, 2.2, SINE_EASING | EASE_IN))
			. += list(list(null, 4))
			return .
		if("scream", "screech", "shriek")
			var/list/scream = list(RIG_L_ARM = list("raise" = 165), RIG_R_ARM = list("raise" = 165), RIG_HEAD = list("nod" = -25), RIG_CHEST = list("bend" = -10))
			return list(list(scream, 1.5), list(scream, 8), list(null, 4))
		if("jump")
			var/list/crouch = list(RIG_L_LEG = list("swing" = 45, "knee" = 80), RIG_R_LEG = list("swing" = 45, "knee" = 80), RIG_CHEST = list("dy" = -3, "bend" = 15), RIG_L_ARM = list("swing" = -30), RIG_R_ARM = list("swing" = -30))
			var/list/air = list(RIG_L_ARM = list("raise" = 60), RIG_R_ARM = list("raise" = 60), RIG_L_LEG = list("swing" = -10), RIG_R_LEG = list("swing" = -10))
			return list(list(crouch, 1.5), list(air, 1.5), list(crouch, 1.5), list(null, 2))
		if("dance")
			. = list()
			for(var/move in 1 to 10)
				. += list(list(list(
					RIG_L_ARM = list("raise" = rand(-20, 175), "swing" = rand(-40, 90), "elbow" = rand(0, 120)),
					RIG_R_ARM = list("raise" = rand(-20, 175), "swing" = rand(-40, 90), "elbow" = rand(0, 120)),
					RIG_L_LEG = list("raise" = rand(-10, 35), "swing" = rand(-30, 40), "knee" = rand(0, 70)),
					RIG_R_LEG = list("raise" = rand(-10, 35), "swing" = rand(-30, 40), "knee" = rand(0, 70)),
					RIG_CHEST = list("bend" = rand(-15, 20), "lean" = rand(-15, 15), "dy" = rand(0, 2)),
					RIG_HEAD = list("nod" = rand(-25, 25), "tilt" = rand(-20, 20)),
				), 2.5))
			. += list(list(null, 3))
			return .
		if("wiggle")
			var/list/a = list(RIG_L_ARM = list("swing" = 45, "raise" = -6), RIG_R_ARM = list("swing" = 45, "raise" = -6))
			var/list/b = list(RIG_L_ARM = list("swing" = 50, "raise" = 4), RIG_R_ARM = list("swing" = 50, "raise" = 4))
			return list(list(a, 1.5), list(b, 1), list(a, 1), list(b, 1), list(a, 1), list(b, 1), list(null, 2))
		if("crack")
			var/list/crack = list(RIG_L_ARM = list("swing" = 85, "raise" = -30), RIG_R_ARM = list("swing" = 85, "raise" = -30), RIG_CHEST = list("bend" = 5))
			var/list/pop = list(RIG_L_ARM = list("swing" = 90, "raise" = -34), RIG_R_ARM = list("swing" = 90, "raise" = -34), RIG_CHEST = list("bend" = 7))
			return list(list(crack, 2), list(pop, 0.5), list(crack, 0.5), list(pop, 0.5), list(null, 2))
		if("snap")
			var/list/snap = list(RIG_R_ARM = list("raise" = 70, "swing" = 60))
			var/list/flick = list(RIG_R_ARM = list("raise" = 80, "swing" = 70))
			return list(list(snap, 1.5), list(flick, 0.5), list(null, 2))
		if("facepalm")
			var/list/palm = list(RIG_R_ARM = list("swing" = 55, "raise" = 22, "hand_y" = 26), RIG_HEAD = list("nod" = 20), RIG_CHEST = list("bend" = 4))
			return list(list(palm, 1.5), list(palm, 8), list(null, 3))
		if("stretch", "yawn")
			var/list/stretch = list(RIG_L_ARM = list("raise" = 170), RIG_R_ARM = list("raise" = 170), RIG_CHEST = list("bend" = -10, "breath" = 0.05), RIG_HEAD = list("nod" = -20))
			return list(list(stretch, 4), list(stretch, 5), list(null, 4))
		if("sigh")
			var/list/sigh = list(RIG_CHEST = list("dy" = -1, "bend" = 6), RIG_HEAD = list("nod" = 18), RIG_L_ARM = list("swing" = -6), RIG_R_ARM = list("swing" = -6))
			return list(list(sigh, 5), list(null, 5))
		if("cough", "sneeze")
			// Doubled over, a fist up at the mouth.
			var/list/hack = list(RIG_CHEST = list("bend" = 18), RIG_HEAD = list("nod" = 25), RIG_R_ARM = list("swing" = 55, "raise" = 25, "hand_y" = 24))
			return list(list(hack, 1), list(null, 1.5), list(hack, 1), list(null, 2))
		if("shiver", "tremble", "twitch", "twitch_s", "shudder")
			. = list()
			for(var/shake in 1 to 8)
				. += list(list(list(
					RIG_CHEST = list("lean" = rand(-6, 6)),
					RIG_HEAD = list("tilt" = rand(-8, 8)),
					RIG_L_ARM = list("raise" = rand(-8, 10)),
					RIG_R_ARM = list("raise" = rand(-8, 10)),
				), 0.6))
			. += list(list(null, 1.5))
			return .
		if("flap", "aflap")
			var/list/up = list(RIG_L_ARM = list("raise" = 120), RIG_R_ARM = list("raise" = 120))
			var/list/down = list(RIG_L_ARM = list("raise" = 30), RIG_R_ARM = list("raise" = 30))
			return list(list(up, 1), list(down, 1), list(up, 1), list(down, 1), list(null, 1.5))
		if("hug")
			var/list/hug = list(RIG_L_ARM = list("swing" = 70, "raise" = -20, "elbow" = 50), RIG_R_ARM = list("swing" = 70, "raise" = -20, "elbow" = 50), RIG_CHEST = list("bend" = 8))
			return list(list(hug, 2), list(hug, 6), list(null, 3))
		if("dab")
			var/list/dab = list(RIG_L_ARM = list("raise" = 150), RIG_R_ARM = list("raise" = 115, "swing" = 70), RIG_HEAD = list("nod" = 30, "tilt" = 20))
			return list(list(dab, 1), list(dab, 8), list(null, 3))
		if("glare", "frown", "grumble", "huff")
			var/list/glare = list(RIG_HEAD = list("nod" = 10), RIG_CHEST = list("bend" = 4))
			return list(list(glare, 2), list(glare, 5), list(null, 3))
		if("gasp", "choke")
			// Hand flying up to the mouth, head jerking back.
			var/list/gasp = list(RIG_HEAD = list("nod" = -18), RIG_CHEST = list("bend" = -6, "breath" = 0.06), RIG_R_ARM = list("swing" = 50, "raise" = 25, "hand_y" = 24))
			return list(list(gasp, 1), list(gasp, 5), list(null, 3))
		if("collapse", "faint")
			var/list/slump = list(RIG_CHEST = list("bend" = 25, "dy" = -2), RIG_HEAD = list("nod" = 30), RIG_L_ARM = list("raise" = 20), RIG_R_ARM = list("raise" = 20))
			return list(list(slump, 3), list(null, 3))
	return null

#undef RIG_ELBOW_Y
#undef RIG_HAND_Y
#undef RIG_KNEE_Y
#undef RIG_SOLE_Y
#undef MENACE_MAX_REACH
#undef MENACE_REACH_RATE
