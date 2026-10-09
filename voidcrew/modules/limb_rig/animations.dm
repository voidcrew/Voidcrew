/**
 * What the rig does with its pieces.
 *
 * A pose is a list of part id -> joint angles:
 * - arms: "raise" (out to the side), "swing" (forward and back) and "elbow" (forearm bends forward),
 *   Arms hang off the torso, so they bend with it;
 *   "aim" instead of "swing" points the whole arm that way in the world, whatever the torso and
 *   posture are doing (90 is straight out in front). "hand_y" works the elbow out for you so the
 *   hand ends up at that height on the sprite (the face is about 26), however long the arm is.
 * - legs: "raise", "swing" and "knee" (shin bends back)
 * - head: "nod" (down is positive) and "tilt" (toward the mob's right)
 * - torso: "bend" (forward) and "lean" (toward the mob's right), plus "breath" (0.03 = 3% taller,
 *   negative squashes), and "air" (pixels the whole body is off the floor)
 * - head and torso: "skew", sheared sideways by this much (0.3 is a lot)
 * - tail (species with one): "lift" (up, degrees) and "wag" (side to side, degrees)
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
 *
 * * size - how much bigger to draw it, from the joint it hangs off (the neck, for a head)
 * * joint - where it hangs off, if not the human joint (list(x, y))
 */
/proc/rig_pose_matrix(part_id, list/entry, facing, size = 1, list/joint)
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
	joint = joint || get_rig_joint(part_id, facing)
	var/matrix/pose = rig_joint_matrix(joint[1], joint[2], scale_y * size, angle, joint[1], joint[2], size)
	var/skew = entry?["skew"]
	if(skew)
		pose = matrix(1, skew, 0, 0, 1, 0) * pose
	pose.Translate(entry?["dx"] || 0, dy)
	return pose

/**
 * The tail's transform: "lift" raises it, "wag" swings it from side to side.
 *
 * Side-on, lifting turns it about its root and wagging foreshortens it. From the front or back,
 * wagging turns it and lifting stands it up taller.
 */
/proc/rig_tail_matrix(list/root, list/entry, facing)
	var/lift = entry?["lift"] || 0
	var/wag = entry?["wag"] || 0
	if(facing == NORTH || facing == SOUTH)
		return rig_joint_matrix(root[1], root[2], 1 + lift / 200, facing == NORTH ? wag : -wag, root[1], root[2])
	return rig_joint_matrix(root[1], root[2], 1, facing == EAST ? lift : -lift, root[1], root[2], cos(wag))

/**
 * Transforms for one arm or leg in a pose.
 *
 * Returns list(upper piece, lower piece, end, end height). The end is for whatever rides on the
 * hand without being stretched (held items). The end height is where the hand or foot finished
 * up, before any lift.
 *
 * * bend - how far the torso is bent forward, for arms: they hang off it and tip back with it.
 */
/proc/rig_limb_matrices(part_id, list/entry, facing, stretch, bend = 0)
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
	return list(
		rig_joint_matrix(root[1], root[2], upper_scale, upper_angle, root_x, root_y),
		rig_joint_matrix(root[1], mid_y, lower_scale, lower_angle, mid_x, mid_to_y, near),
		rig_joint_matrix(root[1], end_y, near, lower_angle, end_x, end_to_y, near),
		end_to_y,
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
		var/list/arm = rig_limb_matrices(arm_id, pose?[arm_id], facing, arm_stretch, bend)
		.[parts[arm_id]] = arm[1]
		.[parts["[side]_forearm"]] = arm[2]
		.[item_parts[side]] = arm[3]
		var/leg_id = side == "l" ? RIG_L_LEG : RIG_R_LEG
		var/list/leg = rig_limb_matrices(leg_id, pose?[leg_id], facing, leg_stretch)
		legs[parts[leg_id]] = leg[1]
		legs[parts["[side]_shin"]] = leg[2]
		lowest_foot = min(lowest_foot, leg[4])
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
	.[parts[RIG_HEAD]] = rig_pose_matrix(RIG_HEAD, pose?[RIG_HEAD], facing, head_scale)
	if(tail_part)
		.[tail_part] = rig_tail_matrix(get_tail_root(facing), pose?[RIG_TAIL], facing) * torso

/// Where a tail joins the body, in BYOND pixel coordinates: the small of the back, which is
/// off to one side seen side-on. A species can set its own with "tail_root", by direction.
/datum/limb_rig/proc/get_tail_root(facing)
	var/mob/living/carbon/human/human_owner = owner
	var/list/roots = istype(human_owner) ? human_owner.dna?.species?.limb_rig_shape?["tail_root"] : null
	var/list/root = roots?[dir2text(facing)]
	if(root)
		return root
	switch(facing)
		if(EAST)
			return list(13, 12)
		if(WEST)
			return list(19, 12)
	return list(16, 12)


/// Puts every piece in a pose immediately.
/datum/limb_rig/proc/snap_to(list/pose)
	// Physics has the pieces while it's on.
	if(physics)
		held_pose = pose
		return
	var/list/matrices = get_pose_matrices(pose, get_facing())
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
	// Physics has the pieces while it's on: authored animation waits until it's off again.
	if(physics)
		return
	src.activity = activity
	deltimer(settle_timer)
	settle_timer = null
	var/facing = get_facing()
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
	var/list/own_idle = (owner.stat == CONSCIOUS && owner.body_position != LYING_DOWN) ? get_own_idle() : null
	if(own_idle)
		play(own_idle, loop = -1, activity = RIG_ACTIVITY_IDLE)
		var/list/first = own_idle[1]
		held_pose = first[1]
		return
	var/deep = owner.stat != CONSCIOUS
	// A tail, if there is one, sways lazily from side to side, or droops when out cold.
	var/list/inhale = list(RIG_CHEST = list("breath" = deep ? 0.05 : 0.035), RIG_HEAD = list("nod" = deep ? 4 : 0), RIG_TAIL = list("wag" = deep ? 0 : 7, "lift" = deep ? -25 : 0))
	var/list/exhale = list(RIG_HEAD = list("nod" = deep ? 4 : 0), RIG_TAIL = list("wag" = deep ? 0 : -7, "lift" = deep ? -25 : 0))
	play(list(
		list(inhale, deep ? 22 : 15),
		list(exhale, deep ? 28 : 20),
	), loop = -1, activity = RIG_ACTIVITY_IDLE)
	held_pose = exhale

/// How long crossing one tile takes right now, in deciseconds: whatever slows or speeds the mob up.
/datum/limb_rig/proc/get_move_delay()
	if(step_delay_override)
		return step_delay_override
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
	var/list/own_step = get_own_step(step_time, running, lying)
	if(own_step)
		play(own_step, activity = RIG_ACTIVITY_MOVING, settle_after = FALSE)
		settle_timer = addtimer(CALLBACK(src, PROC_REF(settle)), max(step_time, move_delay) + 1, TIMER_STOPPABLE|TIMER_DELETE_ME)
		return
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
	// A tail swings against the stride, and streams out flatter behind a run.
	if(keyframes)
		for(var/i in 1 to length(keyframes))
			var/list/keyframe = keyframes[i]
			var/list/pose = keyframe[1]
			pose[RIG_TAIL] = list("wag" = (i % 2 ? 10 : -10) * lead, "lift" = -12 + (i % 2) * 4)
	else
		stride[RIG_TAIL] = list("wag" = -9 * lead, "lift" = -3)
		passing[RIG_TAIL] = list("wag" = 0, "lift" = 3)
	if(!lying)
		var/gait = get_gait_scale(running)
		if(keyframes)
			for(var/list/keyframe as anything in keyframes)
				keyframe[1] = rig_scale_gait(keyframe[1], gait)
		else
			stride = rig_scale_gait(stride, gait)
			passing = rig_scale_gait(passing, gait)
	if(!keyframes)
		keyframes = list(list(stride, step_time * 0.5), list(passing, step_time * 0.5))
	play(keyframes, activity = RIG_ACTIVITY_MOVING, settle_after = FALSE)
	// Stand still again if no step follows.
	settle_timer = addtimer(CALLBACK(src, PROC_REF(settle)), max(step_time, move_delay) + 1, TIMER_STOPPABLE|TIMER_DELETE_ME)

/// A body's own keyframes for one step, or null to use the ones above. left_foot_forward says which step.
/datum/limb_rig/proc/get_own_step(step_time, running, lying)
	return null

/// A body's own looping keyframes for standing still, or null to just breathe.
/datum/limb_rig/proc/get_own_idle()
	return null

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

/// Acts out an emote, if there's an animation for it.
/datum/limb_rig/proc/play_emote(emote_key)
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
