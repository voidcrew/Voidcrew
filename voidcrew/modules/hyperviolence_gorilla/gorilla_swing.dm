/**
 * # Arm swings
 *
 * A Gorilla fist is thrown by an arm that moves: the piston punch draws its fist back and drives it out
 * (gorilla_thrust.dm), and the haymaker winds its arm up, throws it and follows through (gorilla_haymaker.dm). Both
 * are drawn with the puppet rig's pictures and maths (chrome_puppet_rig.dm), and both land their blow when the fist
 * arrives, not at the click. What they share is here:
 *
 * - A swing is a list of beats (where the body and each arm are when the beat ends), cut into frames of a few degrees
 *   so a shoulder never leaves its body, and played on every piece at once.
 * - The fist is sent to the part of the body the blow lands on, where that part is drawn. The body steps in behind it
 *   as far as it takes; an arm is only drawn so long.
 */

/// Most degrees an arm or a body turns in one frame of a swing.
#define SWING_FRAME_TURN 12
/// The longest one frame of an eased beat lasts.
#define SWING_FRAME_TIME (0.03 SECONDS)

// A frame of a swing: list(time, the body's matrix, side -> list(turn, length), side -> a layer the arm takes)
#define SWING_FRAME_TIME_INDEX 1
#define SWING_FRAME_BASE 2
#define SWING_FRAME_ARMS 3
#define SWING_FRAME_LAYERS 4

// =========================================================================
// BEATS AND FRAMES
// =========================================================================

/// One beat of a swing: where the body and its arms are when it ends.
/datum/chrome_swing_beat
	/// How long the beat lasts
	var/time = 0
	/// Its pace (CHROME_SWING_*)
	var/easing = CHROME_SWING_LINEAR
	/// Pixels the body has moved from its rest, across and up the screen
	var/shift_x = 0
	var/shift_y = 0
	/// Degrees the body is tipped, clockwise
	var/tip = 0
	/// Side -> list(turn, length): the arms that move in this beat. One left out stays as it is
	var/list/arms
	/// Side -> the layer that arm takes as the beat starts
	var/list/layers
	/// Side -> list(degrees, layer): the layer that arm takes once it is turned less than that from hanging
	var/list/layer_once_under

/datum/chrome_swing_beat/New(time = 0, easing = CHROME_SWING_LINEAR, shift_x = 0, shift_y = 0, tip = 0)
	src.time = time
	src.easing = easing
	src.shift_x = shift_x
	src.shift_y = shift_y
	src.tip = tip

/// Sends the arm on [side] to [pose] (list(turn, length)) in this beat, on [layer] from its start if one is given.
/datum/chrome_swing_beat/proc/arm(side, list/pose, layer)
	LAZYSET(arms, side, pose)
	if(!isnull(layer))
		LAZYSET(layers, side, layer)
	return src

/// The body's matrix [tip] degrees over and moved by [shift_x], [shift_y]: tipped about its middle, then moved.
/proc/chrome_swing_base(shift_x = 0, shift_y = 0, tip = 0)
	var/matrix/base = matrix()
	if(tip)
		base.Turn(tip)
	if(shift_x || shift_y)
		base.Translate(shift_x, shift_y)
	return base

/**
 * Cuts [beats] into frames. [arms_from] (side -> list(turn, length)) is where each arm starts, and [shift_x], [shift_y]
 * and [tip] where the body does. Every arm in [arms_from] is in every frame, moving or not.
 */
/proc/chrome_swing_frames(list/beats, list/arms_from, shift_x = 0, shift_y = 0, tip = 0)
	var/list/frames = list()
	var/list/arms_now = list()
	for(var/side in arms_from)
		var/list/pose = arms_from[side]
		arms_now[side] = list(pose[1], pose[2])
	for(var/datum/chrome_swing_beat/beat as anything in beats)
		var/steps = 1
		if(beat.time > 0)
			for(var/side in beat.arms)
				var/list/from_pose = arms_now[side]
				var/list/to_pose = beat.arms[side]
				if(from_pose)
					steps = max(steps, CEILING(abs(to_pose[1] - from_pose[1]) / SWING_FRAME_TURN, 1))
			steps = max(steps, CEILING(abs(beat.tip - tip) / SWING_FRAME_TURN, 1))
			if(beat.easing != CHROME_SWING_LINEAR)
				steps = max(steps, min(CEILING(beat.time / SWING_FRAME_TIME, 1), 12))
		var/list/switched = list()
		for(var/i in 1 to steps)
			var/progress = i / steps
			switch(beat.easing)
				if(CHROME_SWING_EASE_OUT)
					progress = sin(90 * progress)
				if(CHROME_SWING_EASE_IN_OUT)
					progress = (1 - cos(180 * progress)) / 2
			var/matrix/base = chrome_swing_base(shift_x + (beat.shift_x - shift_x) * progress, shift_y + (beat.shift_y - shift_y) * progress, tip + (beat.tip - tip) * progress)
			var/list/frame_arms = list()
			var/list/frame_layers
			for(var/side in arms_now)
				var/list/from_pose = arms_now[side]
				var/list/to_pose = beat.arms?[side]
				var/list/pose = to_pose ? list(from_pose[1] + (to_pose[1] - from_pose[1]) * progress, from_pose[2] + (to_pose[2] - from_pose[2]) * progress) : from_pose
				frame_arms[side] = pose
				if(i == 1 && !isnull(beat.layers?[side]))
					LAZYSET(frame_layers, side, beat.layers[side])
				var/list/under = beat.layer_once_under?[side]
				if(under && !switched[side] && abs(pose[1]) < under[1])
					switched[side] = TRUE
					LAZYSET(frame_layers, side, under[2])
			frames += list(list(beat.time / steps, base, frame_arms, frame_layers))
		for(var/side in beat.arms)
			if(arms_now[side])
				var/list/to_pose = beat.arms[side]
				arms_now[side] = list(to_pose[1], to_pose[2])
		shift_x = beat.shift_x
		shift_y = beat.shift_y
		tip = beat.tip
	return frames

/**
 * Plays [frames] on the pieces of one body, with [rig]'s maths. Everything in [bodies] (a puppet standing for the body,
 * anything that rides on it) takes each frame's matrix; each arm in [arms] (side -> its puppet) takes its pose on that
 * matrix, and any layer the frame gives it. [real_body] is the body itself when it is the one on show: it takes the
 * matrices alongside whatever else is moving it, as tg's own lunge does. [settle] (piece -> list(pixel_w, pixel_x,
 * pixel_y, pixel_z)) are offsets a piece eases to over its first frame.
 */
/proc/chrome_swing_play(datum/chrome_rig/rig, list/frames, list/bodies, list/arms, atom/movable/real_body, list/settle)
	if(!length(frames))
		return
	for(var/atom/movable/piece as anything in bodies)
		var/list/rest = settle?[piece]
		var/first = TRUE
		for(var/list/frame as anything in frames)
			if(!first)
				animate(transform = frame[SWING_FRAME_BASE], time = frame[SWING_FRAME_TIME_INDEX])
				continue
			first = FALSE
			if(rest)
				animate(piece, transform = frame[SWING_FRAME_BASE], pixel_w = rest[1], pixel_x = rest[2], pixel_y = rest[3], pixel_z = rest[4], time = frame[SWING_FRAME_TIME_INDEX])
			else
				animate(piece, transform = frame[SWING_FRAME_BASE], time = frame[SWING_FRAME_TIME_INDEX])
	if(real_body)
		var/first = TRUE
		for(var/list/frame as anything in frames)
			if(first)
				animate(real_body, transform = frame[SWING_FRAME_BASE], time = frame[SWING_FRAME_TIME_INDEX], flags = ANIMATION_PARALLEL)
				first = FALSE
			else
				animate(transform = frame[SWING_FRAME_BASE], time = frame[SWING_FRAME_TIME_INDEX])
	for(var/side in arms)
		var/atom/movable/arm = arms[side]
		if(isnull(arm))
			continue
		var/list/rest = settle?[arm]
		var/first = TRUE
		for(var/list/frame as anything in frames)
			var/list/pose = frame[SWING_FRAME_ARMS][side]
			if(isnull(pose))
				continue
			var/matrix/posed = rig.arm_matrix(side, pose[1], pose[2], frame[SWING_FRAME_BASE])
			var/new_layer = frame[SWING_FRAME_LAYERS]?[side]
			if(!first)
				if(!isnull(new_layer))
					animate(layer = new_layer, time = 0)
				animate(transform = posed, time = frame[SWING_FRAME_TIME_INDEX])
				continue
			first = FALSE
			if(!isnull(new_layer))
				arm.layer = new_layer
			if(rest)
				animate(arm, transform = posed, pixel_w = rest[1], pixel_x = rest[2], pixel_y = rest[3], pixel_z = rest[4], time = frame[SWING_FRAME_TIME_INDEX])
			else
				animate(arm, transform = posed, time = frame[SWING_FRAME_TIME_INDEX])

// =========================================================================
// WHERE A FIST LANDS
// =========================================================================

/// Which way [facing] steps: list(across, up).
/proc/chrome_swing_way(facing)
	switch(facing)
		if(EAST)
			return list(1, 0)
		if(WEST)
			return list(-1, 0)
		if(NORTH)
			return list(0, 1)
	return list(0, -1)

/**
 * Where the middle of a fist from [bearer] stops for a blow on [zone] of [target]: list(x, y), pixels from where the
 * middle of [bearer] is drawn. The body is taken where it is drawn now: for the way it faces and lies, its offsets, and
 * short of its tile when it is hit mid-stride. A standing body beside the bearer is met at its edge, at the height of
 * the part, the knuckles just on it; anything else, on the part itself. Null when they aren't on one level.
 */
/proc/gorilla_fist_target(mob/living/bearer, atom/movable/target, zone)
	var/turf/from = get_turf(bearer)
	var/turf/onto = get_turf(target)
	if(isnull(from) || isnull(onto) || from.z != onto.z)
		return null
	var/list/part = gorilla_zone_point(target, zone)
	var/list/lag = gorilla_glide_lag(target)
	var/body_x = (onto.x - from.x) * ICON_SIZE_X + target.pixel_x + target.pixel_w + lag[1] - bearer.pixel_x - bearer.pixel_w
	var/body_y = (onto.y - from.y) * ICON_SIZE_Y + target.pixel_y + target.pixel_z + lag[2] - bearer.pixel_y - bearer.pixel_z
	var/mob/living/struck = target
	if(ishuman(target) && struck.body_position != LYING_DOWN && body_x && abs(body_x) >= abs(body_y))
		// Beside the bearer: half the width of tg's human sprite at that height, seen side on or from the front or back
		var/side_on = struck.dir & (EAST|WEST)
		var/half = 4
		switch(check_zone(zone))
			if(BODY_ZONE_CHEST)
				half = side_on ? 4 : 7
			if(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM)
				half = side_on ? 4 : 8
			if(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
				half = side_on ? 2 : 5
		return list(body_x + (body_x > 0 ? -1 : 1) * (half + GORILLA_FIST_KNUCKLES), body_y + part[2])
	// Up or down the screen, or lying: the fist is drawn on the part, a little to the bearer's side of it
	var/to_x = body_x + part[1]
	var/to_y = body_y + part[2]
	var/far = sqrt(to_x * to_x + to_y * to_y)
	if(far < 3)
		return list(to_x, to_y)
	return list(to_x - to_x / far * 2, to_y - to_y / far * 2)

/**
 * The swing that lands the fist of [rig]'s arm on [side] at [x], [y] (gorilla_fist_target()): list(step, turn, length).
 * The body steps [way] (chrome_swing_way()) by at least [least] pixels and at most [most], tipped [tip] degrees: as few
 * as bring the fist there with the arm no longer than [easy] times its length. The arm is never longer than [cap]: the
 * fist stops short instead. [near_turn] picks which way round the arm comes.
 */
/proc/chrome_swing_reach(datum/chrome_rig/rig, side, x, y, list/way, least, most, tip, easy, cap, near_turn)
	var/list/found
	for(var/step in least to most)
		var/list/pose = rig.pose_reaching(side, x, y, near_turn, chrome_swing_base(way[1] * step, way[2] * step, tip))
		found = list(step, pose[1], pose[2])
		if(pose[2] <= easy)
			break
	found[3] = min(found[3], cap)
	return found

#undef SWING_FRAME_TURN
#undef SWING_FRAME_TIME
#undef SWING_FRAME_TIME_INDEX
#undef SWING_FRAME_BASE
#undef SWING_FRAME_ARMS
#undef SWING_FRAME_LAYERS
