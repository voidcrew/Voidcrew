/**
 * How an Experiment moves: its own animations rather than the human ones, recreated as key poses
 * from how the creature moves in its home game. Each clip is a list of list(fraction of the loop,
 * pose), with whole joint angles (see sprite_rig.dm). Legs listed as the right one are the near leg
 * side-on.
 */

/// Standing: weight rocking between the legs, arms swaying.
GLOBAL_LIST_INIT(expie_idle, list(
	list(0.0, list(RIG_R_LEG = list("thigh" = -8, "shin" = -64, "foot" = 3), RIG_L_LEG = list("thigh" = 23, "shin" = -47, "foot" = 13), RIG_R_ARM = list("upper" = -8, "lower" = 9), RIG_L_ARM = list("upper" = 0, "lower" = 8))),
	list(0.25, list(RIG_R_LEG = list("thigh" = -6, "shin" = -68, "foot" = 5), RIG_L_LEG = list("thigh" = 24, "shin" = -50, "foot" = 16), RIG_R_ARM = list("upper" = -10, "lower" = 11), RIG_L_ARM = list("upper" = 2, "lower" = 10))),
	list(0.5, list(RIG_R_LEG = list("thigh" = -5, "shin" = -73, "foot" = 6), RIG_L_LEG = list("thigh" = 25, "shin" = -53, "foot" = 20), RIG_R_ARM = list("upper" = -13, "lower" = 12), RIG_L_ARM = list("upper" = 3, "lower" = 12))),
	list(0.75, list(RIG_R_LEG = list("thigh" = -6, "shin" = -68, "foot" = 5), RIG_L_LEG = list("thigh" = 24, "shin" = -50, "foot" = 16), RIG_R_ARM = list("upper" = -10, "lower" = 11), RIG_L_ARM = list("upper" = 2, "lower" = 10))),
))

/// Running: leaning well forward, long bounding strides, arms pumping. One loop is two steps.
GLOBAL_LIST_INIT(expie_run, list(
	list(0.0, list(RIG_R_LEG = list("thigh" = 45, "shin" = -58, "foot" = -21), RIG_L_LEG = list("thigh" = -18, "shin" = -53, "foot" = -27), RIG_R_ARM = list("upper" = -76, "lower" = 9), RIG_L_ARM = list("upper" = 1, "lower" = 94), RIG_CHEST = list("bend" = 35), RIG_HEAD = list("nod" = 0))),
	list(0.125, list(RIG_R_LEG = list("thigh" = 69, "shin" = -26, "foot" = -1), RIG_L_LEG = list("thigh" = -44, "shin" = -88, "foot" = -63), RIG_R_ARM = list("upper" = -56, "lower" = 35), RIG_L_ARM = list("upper" = -10, "lower" = 83), RIG_CHEST = list("bend" = 29), RIG_HEAD = list("nod" = 1))),
	list(0.25, list(RIG_R_LEG = list("thigh" = 56, "shin" = -3, "foot" = 24), RIG_L_LEG = list("thigh" = -41, "shin" = -87, "foot" = -81), RIG_R_ARM = list("upper" = -27, "lower" = 71), RIG_L_ARM = list("upper" = -29, "lower" = 61), RIG_CHEST = list("bend" = 24), RIG_HEAD = list("nod" = 1))),
	list(0.375, list(RIG_R_LEG = list("thigh" = 17, "shin" = -25, "foot" = 1), RIG_L_LEG = list("thigh" = -3, "shin" = -76, "foot" = -69), RIG_R_ARM = list("upper" = -5, "lower" = 89), RIG_L_ARM = list("upper" = -56, "lower" = 30), RIG_CHEST = list("bend" = 30), RIG_HEAD = list("nod" = 1))),
	list(0.5, list(RIG_R_LEG = list("thigh" = -20, "shin" = -53, "foot" = -29), RIG_L_LEG = list("thigh" = 49, "shin" = -60, "foot" = -34), RIG_R_ARM = list("upper" = 7, "lower" = 95), RIG_L_ARM = list("upper" = -73, "lower" = 10), RIG_CHEST = list("bend" = 35), RIG_HEAD = list("nod" = 0))),
	list(0.625, list(RIG_R_LEG = list("thigh" = -46, "shin" = -88, "foot" = -69), RIG_L_LEG = list("thigh" = 71, "shin" = -25, "foot" = 2), RIG_R_ARM = list("upper" = -5, "lower" = 89), RIG_L_ARM = list("upper" = -56, "lower" = 30), RIG_CHEST = list("bend" = 30), RIG_HEAD = list("nod" = 0))),
	list(0.75, list(RIG_R_LEG = list("thigh" = -39, "shin" = -87, "foot" = -81), RIG_L_LEG = list("thigh" = 55, "shin" = 6, "foot" = 18), RIG_R_ARM = list("upper" = -27, "lower" = 71), RIG_L_ARM = list("upper" = -29, "lower" = 61), RIG_CHEST = list("bend" = 24), RIG_HEAD = list("nod" = 1))),
	list(0.875, list(RIG_R_LEG = list("thigh" = 3, "shin" = -70, "foot" = -58), RIG_L_LEG = list("thigh" = 13, "shin" = -23, "foot" = 2), RIG_R_ARM = list("upper" = -56, "lower" = 35), RIG_L_ARM = list("upper" = -10, "lower" = 83), RIG_CHEST = list("bend" = 29), RIG_HEAD = list("nod" = 1))),
))

/// Walking: hunched nearly flat, creeping on bent legs. One loop is two steps.
GLOBAL_LIST_INIT(expie_sneak, list(
	list(0.0, list(RIG_R_LEG = list("thigh" = 71, "shin" = -73, "foot" = -40), RIG_L_LEG = list("thigh" = 37, "shin" = -95, "foot" = 7), RIG_CHEST = list("bend" = 73))),
	list(0.125, list(RIG_R_LEG = list("thigh" = 79, "shin" = -52, "foot" = -7), RIG_L_LEG = list("thigh" = 2, "shin" = -113, "foot" = -8), RIG_CHEST = list("bend" = 73))),
	list(0.25, list(RIG_R_LEG = list("thigh" = 81, "shin" = -42, "foot" = 18), RIG_L_LEG = list("thigh" = -15, "shin" = -120, "foot" = -25), RIG_CHEST = list("bend" = 73))),
	list(0.375, list(RIG_R_LEG = list("thigh" = 63, "shin" = -65, "foot" = 16), RIG_L_LEG = list("thigh" = 26, "shin" = -95, "foot" = -37), RIG_CHEST = list("bend" = 73))),
	list(0.5, list(RIG_R_LEG = list("thigh" = 38, "shin" = -96, "foot" = 7), RIG_L_LEG = list("thigh" = 75, "shin" = -64, "foot" = -38), RIG_CHEST = list("bend" = 73))),
	list(0.625, list(RIG_R_LEG = list("thigh" = 5, "shin" = -116, "foot" = 6), RIG_L_LEG = list("thigh" = 88, "shin" = -44, "foot" = -12), RIG_CHEST = list("bend" = 73))),
	list(0.75, list(RIG_R_LEG = list("thigh" = -13, "shin" = -123, "foot" = 1), RIG_L_LEG = list("thigh" = 85, "shin" = -39, "foot" = 16), RIG_CHEST = list("bend" = 73))),
	list(0.875, list(RIG_R_LEG = list("thigh" = 21, "shin" = -103, "foot" = -17), RIG_L_LEG = list("thigh" = 65, "shin" = -62, "foot" = 16), RIG_CHEST = list("bend" = 73))),
))

/// Swinging at something with both arms, overhead and down.
GLOBAL_LIST_INIT(expie_swing, list(
	list(0.0, list(RIG_R_ARM = list("upper" = 43, "lower" = 94), RIG_L_ARM = list("upper" = 28, "lower" = 104))),
	list(0.25, list(RIG_R_ARM = list("upper" = 85, "lower" = 139), RIG_L_ARM = list("upper" = 54, "lower" = 122))),
	list(0.5, list(RIG_R_ARM = list("upper" = 53, "lower" = 136), RIG_L_ARM = list("upper" = 47, "lower" = 121))),
	list(0.75, list(RIG_R_ARM = list("upper" = -9, "lower" = 61), RIG_L_ARM = list("upper" = 13, "lower" = 103))),
))

/datum/limb_rig/sprites/experiment

/datum/limb_rig/sprites/experiment/get_own_idle()
	return rig_clip_keyframes(GLOB.expie_idle, 10, tail_wag = 7)

/datum/limb_rig/sprites/experiment/get_own_step(step_time, running, lying)
	if(lying)
		return null // Crawling is crawling.
	// A clip loop is two steps: this step plays whichever half its leg leads.
	var/start = left_foot_forward ? 0 : 0.5
	return rig_clip_keyframes(running ? GLOB.expie_run : GLOB.expie_sneak, step_time, start, start + 0.5, running ? 10 : 5, running ? -12 : -5)

/datum/limb_rig/sprites/experiment/play_attack()
	if(prob(50))
		playsound(owner, get_expie_exert_sound(), 35, TRUE)
	var/list/keyframes = rig_clip_keyframes(GLOB.expie_swing, 3.3)
	keyframes += list(list(null, 2))
	play(keyframes)

/**
 * Keyframes playing part of a clip.
 *
 * * duration - how long the part takes, in deciseconds, shared out evenly between its frames
 * * start, stop - which part of the loop, as fractions. Frames after start up to and including stop
 *   play, so one part picks up where the last left off.
 * * tail_wag, tail_lift - a tail swinging from side to side with each frame
 */
/proc/rig_clip_keyframes(list/clip, duration, start = 0, stop = 1, tail_wag = 0, tail_lift = 0)
	. = list()
	var/list/poses = list()
	var/list/wrapped
	for(var/list/frame as anything in clip)
		var/fraction = frame[1]
		if(fraction > start && fraction <= stop)
			poses += list(frame[2])
		else if(fraction == 0 && stop >= 1)
			wrapped = frame[2] // The loop's first frame is also its last.
	if(wrapped)
		poses += list(wrapped)
	if(!length(poses))
		return
	var/each = duration / length(poses)
	var/beat = 0
	for(var/list/pose as anything in poses)
		beat++
		var/list/keyframe_pose = pose.Copy()
		if(tail_wag || tail_lift)
			keyframe_pose[RIG_TAIL] = list("wag" = (beat % 2) ? tail_wag : -tail_wag, "lift" = tail_lift)
		. += list(list(keyframe_pose, each))
