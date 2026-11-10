/**
 * # The grab-slam
 *
 * With someone in an aggressive grab, a click on the floor under them, an open floor beside the bearer or a table
 * presses them up and drives them down onto it (gorilla_arms/proc/try_slam(), gorilla_punch.dm). The lift is drawn
 * with the puppet rig (chrome_puppet_rig.dm), so neither real body is moved or turned by it.
 *
 * - Grip: he leans in and both fists take the body, by belt and collar seen from the side. For the first moment of it
 *   the real bodies still show, while the puppets' pictures reach the client: hidden at once, both would blink.
 * - Hoist: up and over, turning flat. Gorilla Arms press it overhead; Brawler myomers bring it to the shoulder.
 * - Top: one held beat. A body taken from behind or beside him is turned to the table or tile here.
 * - Slam: driven down with his fists still on it. Seen from the side he bends at the belt; from the front or back he
 *   drops and lunges.
 * - Impact: the damage, the knockdown and the grab letting go all land here, and the real body is put on the tile.
 *   A ring, and on a floor cracks (and dust and the heavy crash, for Gorilla Arms); both cameras shake and the body
 *   flashes white. Blood only if the blow made them bleed (a wound through the skin, or tg's cracked ribs bleeding
 *   inside), as a few drops thrown out round the body.
 * - Rebound: the body bounces once and he comes up, hands off. The puppets go once both are still, with the real body
 *   lying in the same pixels.
 *
 * Until the impact nothing has happened to anyone. The bearer can't step, the grab is held, and the slam is called off
 * if he is stunned or knocked down, loses the grab, or either of them is moved: the body comes down on its feet, unhurt.
 *
 * The poses are keys (the grip, the top, the impact, the rebound) played as short straight steps. While his fists are on
 * the body they are solved onto it at every step, so they never leave it. Every puppet stands on the bearer's tile and is
 * moved by its transform alone, which keeps its place in the draw order: the client sorts by row before layer, so a puppet
 * that must draw over a table or a ring on the row nearer the viewer is put on that row.
 */

/mob/living
	/// The grab-slam this mob is doing or is held in, if any (gorilla_slam.dm). Cleared when it ends.
	var/datum/gorilla_slam/gorilla_slam

// What an arm does in a key pose.
/// On the body: list(kind, x, y) in the body's own pixels, from the middle of its picture.
#define SLAM_ARM_GRIP 1
/// On the body, at a point of the scene: list(kind, x, y) pixels from where the bearer stands.
#define SLAM_ARM_POINT 2
/// On the body, wherever a swing puts the hand: list(kind, angle, reach) as swing_arm() takes them.
#define SLAM_ARM_HELD 3
/// Off the body: list(kind, angle, reach).
#define SLAM_ARM_SWING 4

// How a key pose is eased into.
#define SLAM_EASE_LINEAR 0
#define SLAM_EASE_OUT 1
#define SLAM_EASE_IN 2
#define SLAM_EASE_SINE 3

/// Where the belt sits, from the middle of the picture: seen from the side the bearer bends about it.
#define SLAM_WAIST_Y -7
/// The puppet rig's filter that hides a real body (CHROME_RIG_HIDE_FILTER in chrome_puppet_rig.dm).
#define SLAM_RIG_HIDE_FILTER "chrome_rig_hide"

/// [progress] (0 to 1) eased as [kind] (SLAM_EASE_*).
/proc/gorilla_slam_ease(kind, progress)
	progress = clamp(progress, 0, 1)
	switch(kind)
		if(SLAM_EASE_OUT)
			return 1 - (1 - progress) ** 2
		if(SLAM_EASE_IN)
			return progress ** 2
		if(SLAM_EASE_SINE)
			return (1 - cos(180 * progress)) / 2
	return progress

/// One key pose of the bearer.
/datum/gorilla_slam_pose
	/// Deciseconds from the click
	var/time = 0
	/// The facing of the rig that shows it
	var/facing
	/// How the move eases into it from the pose before (SLAM_EASE_*)
	var/ease = SLAM_EASE_LINEAR
	/// Pixels the whole bearer is moved
	var/shift_x = 0
	var/shift_y = 0
	/// Degrees he leans forward from the feet, seen from the side
	var/lean = 0
	/// Degrees he bends forward at the belt, seen from the side
	var/waist = 0
	/// The crouch seen from the front or back: his height as a share, and pixels dropped
	var/squash = 1
	var/drop = 0
	/// Side -> list(SLAM_ARM_*, a, b)
	var/list/arms
	/// Side -> list(x, y): where the fist is on the body, in the body's own pixels. No entry for an arm that is off it.
	var/list/grips = list()
	/// Side -> list(turn, length): the arm as it is in this pose
	var/list/reached = list()

/datum/gorilla_slam_pose/New(time, facing, ease = SLAM_EASE_LINEAR)
	src.time = time
	src.facing = facing
	src.ease = ease

/// One grab-slam, from the click to the puppets coming down.
/datum/gorilla_slam
	/// Who slams
	var/mob/living/carbon/human/bearer
	/// Who is slammed
	var/mob/living/victim
	/// The arm that does it, and its hand: the attacking item
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm
	var/obj/item/bodypart/fist
	/// The tile the body is brought down on, and the table there if it is slammed onto one
	var/turf/spot
	var/datum/weakref/table_ref
	/// Where the two stood at the click
	var/turf/bearer_spot
	var/turf/victim_spot
	/// The way the bearer faces to take the body, and the way he faces to bring it down
	var/taking
	var/facing
	/// The zone he aimed at the click
	var/aimed_zone
	/// TRUE for a head-aimed table slam: the body lands face down
	var/face_down = FALSE
	/// world.time at the click
	var/started_at = 0
	/// TRUE once the impact has landed
	var/landed = FALSE
	/// TRUE once it is over, or called off
	var/ended = FALSE
	/// TRUE while the slam itself lets go of the grab and moves the body
	var/placing = FALSE
	/// FALSE when a body couldn't be rigged: the slam happens without the poses
	var/posed = FALSE
	// The beats, in deciseconds from the click
	var/t_grip = GORILLA_SLAM_GRIP_TIME
	var/t_top
	var/t_drive
	var/t_hit
	var/t_mid
	var/t_up
	var/t_end
	// The body's middle, in pixels from where the bearer is drawn, and its turn (degrees clockwise): held at the click,
	// at the top, and where it lands
	var/held_x = 0
	var/held_y = 0
	var/held_angle = 0
	var/top_x = 0
	var/top_y = 0
	var/top_angle = 0
	var/land_x = 0
	var/land_y = 0
	var/land_angle = 0
	/// The middle of the tile it lands on
	var/tile_x = 0
	var/tile_y = 0
	/// Where the bearer is drawn on his own tile: every puppet stands there
	var/origin_x = 0
	var/origin_y = 0
	/// Where the real body lies after the impact: the puppet settles there
	var/final_x = 0
	var/final_y = 0
	var/final_angle = 0
	/// Facing ("[dir]") -> the bearer's rig in that facing
	var/list/rigs
	/// The body's puppets, one for each of the bearer's rigs ("body_[dir]")
	var/datum/chrome_rig/victim_rig
	/// The key poses, in order (/datum/gorilla_slam_pose)
	var/list/keys
	var/hit_timer
	var/end_timer

/datum/gorilla_slam/New(mob/living/carbon/human/bearer, mob/living/victim, turf/spot, obj/structure/table/table, obj/item/organ/cyberimp/cyberware/gorilla_arms/arm, obj/item/bodypart/fist)
	. = ..()
	src.bearer = bearer
	src.victim = victim
	src.spot = spot
	src.arm = arm
	src.fist = fist
	if(table)
		table_ref = WEAKREF(table)

/datum/gorilla_slam/Destroy()
	ended = TRUE
	if(hit_timer)
		deltimer(hit_timer)
		hit_timer = null
	if(end_timer)
		deltimer(end_timer)
		end_timer = null
	take_down()
	if(bearer)
		stop_listening()
		REMOVE_TRAIT(bearer, TRAIT_IMMOBILIZED, GORILLA_SLAM_TRAIT)
		if(bearer.gorilla_slam == src)
			bearer.gorilla_slam = null
	if(victim?.gorilla_slam == src)
		victim.gorilla_slam = null
	bearer = null
	victim = null
	arm = null
	fist = null
	spot = null
	bearer_spot = null
	victim_spot = null
	keys = null
	return ..()

/// Takes every puppet down and shows both bodies.
/datum/gorilla_slam/proc/take_down()
	QDEL_NULL(victim_rig)
	if(rigs)
		QDEL_LIST_ASSOC_VAL(rigs)
		rigs = null

/// The facing toward [target] from where the bearer stands, as face_atom() picks it. Null for his own tile.
/datum/gorilla_slam/proc/toward(turf/target)
	var/dx = target.x - bearer_spot.x
	var/dy = target.y - bearer_spot.y
	if(!dx && !dy)
		return null
	if(abs(dx) < abs(dy))
		return dy > 0 ? NORTH : SOUTH
	return dx > 0 ? EAST : WEST

/**
 * Starts the slam: the rigs go up, the bearer is held where he stands and the impact is set for t_hit. Returns FALSE if
 * it can't start; nothing has changed then.
 */
/datum/gorilla_slam/proc/start()
	if(QDELETED(bearer) || QDELETED(victim) || QDELETED(arm) || bearer.gorilla_slam || victim.gorilla_slam)
		return FALSE
	bearer_spot = bearer.loc
	victim_spot = victim.loc
	if(!isturf(bearer_spot) || !isturf(victim_spot) || !isturf(spot))
		return FALSE
	// A body on its feet can't be put down where he stands himself
	if(spot == bearer_spot && victim.density)
		return FALSE
	for(var/mob/living/in_the_way in spot)
		if(in_the_way != victim && in_the_way != bearer && in_the_way.density)
			return FALSE
	bearer.gorilla_slam = src
	victim.gorilla_slam = src
	started_at = world.time
	aimed_zone = check_zone(bearer.zone_selected)
	face_down = !isnull(table_ref) && aimed_zone == BODY_ZONE_HEAD
	var/now_facing = (bearer.dir in GLOB.cardinals) ? bearer.dir : ((bearer.dir & (EAST|WEST)) || SOUTH)
	taking = toward(victim_spot) || now_facing
	facing = toward(spot) || taking
	bearer.setDir(taking)
	t_top = t_grip + (arm.slam_overhead ? GORILLA_SLAM_HOIST_TIME : BRAWLER_SLAM_HOIST_TIME)
	t_drive = t_top + GORILLA_SLAM_TOP_TIME
	t_hit = t_drive + GORILLA_SLAM_DRIVE_TIME
	t_mid = t_hit + GORILLA_SLAM_REBOUND_TIME / 2
	t_up = t_hit + GORILLA_SLAM_RISE_TIME
	t_end = t_hit + GORILLA_SLAM_SETTLE_TIME
	measure()
	posed = build_rigs()
	if(posed)
		build_keys()
		set_stage()
		play(0, t_hit)
	else
		take_down()
	ADD_TRAIT(bearer, TRAIT_IMMOBILIZED, GORILLA_SLAM_TRAIT)
	listen()
	hit_timer = addtimer(CALLBACK(src, PROC_REF(hit)), t_hit, TIMER_STOPPABLE | TIMER_DELETE_ME)
	return TRUE

/// Where [body] is drawn: list(x, y) pixels from where the bearer was drawn at the click.
/datum/gorilla_slam/proc/drawn_at(mob/living/body)
	var/turf/here = get_turf(body)
	return list((here.x - bearer_spot.x) * ICON_SIZE_X + body.pixel_x + body.pixel_w - origin_x, (here.y - bearer_spot.y) * ICON_SIZE_Y + body.pixel_y + body.pixel_z - origin_y)

/// [body]'s lying turn in degrees clockwise, the short way round: 0 on its feet, 90 or -90 lying.
/datum/gorilla_slam/proc/turn_of(mob/living/body)
	return body.lying_angle > 180 ? body.lying_angle - 360 : body.lying_angle

/// Works out where the body is held, where the top of the lift is and where it lands, all from where the bearer is drawn.
/datum/gorilla_slam/proc/measure()
	origin_x = bearer.pixel_x + bearer.pixel_w
	origin_y = bearer.pixel_y + bearer.pixel_z
	var/list/victim_at = drawn_at(victim)
	held_x = victim_at[1]
	held_y = victim_at[2]
	held_angle = turn_of(victim)
	tile_x = (spot.x - bearer_spot.x) * ICON_SIZE_X
	tile_y = (spot.y - bearer_spot.y) * ICON_SIZE_Y
	var/side_on = facing & (EAST|WEST)
	var/ahead = facing == WEST ? -1 : 1
	// Seen from the side the head ends at his feet, under his fists; from the front or back the body lies head east
	var/turned = facing == EAST ? -1 : 1
	if(arm.slam_overhead)
		top_x = side_on ? GORILLA_SLAM_TOP_SIDE_X * ahead : GORILLA_SLAM_TOP_FRONT_X
		top_y = side_on ? GORILLA_SLAM_TOP_SIDE_Y : (facing == NORTH ? GORILLA_SLAM_TOP_BACK_Y : GORILLA_SLAM_TOP_FRONT_Y)
		top_angle = 90 * turned
	else
		top_x = side_on ? BRAWLER_SLAM_TOP_SIDE_X * ahead : BRAWLER_SLAM_TOP_FRONT_X
		top_y = side_on ? BRAWLER_SLAM_TOP_SIDE_Y : BRAWLER_SLAM_TOP_FRONT_Y
		top_angle = BRAWLER_SLAM_TOP_TURN * turned
	land_angle = 90 * turned
	land_x = tile_x
	// Where tg draws a body lying there: a little down the tile, and up on a table top
	land_y = tile_y + PIXEL_Y_OFFSET_LYING + (table_ref ? GORILLA_SLAM_TABLE_TOP : 0)
	final_x = land_x
	final_y = land_y
	final_angle = land_angle

// =========================================================================
// THE RIGS
// =========================================================================

/// A flat picture of [body] facing [way], into [rig]. getFlatIcon() draws a body in its own facing unless it faces south, so it is turned for the picture.
/datum/gorilla_slam/proc/picture(datum/chrome_rig/rig, mob/living/body, way)
	var/real_dir = body.dir
	body.dir = way
	. = rig.snapshot()
	body.dir = real_dir

/**
 * Stands a puppet of [rig] under [key] where the bearer stands, [row] tiles up the map from him (-1: the row nearer the
 * viewer), on [puppet_layer]. It is moved by its transform from there.
 */
/datum/gorilla_slam/proc/stand(datum/chrome_rig/rig, key, icon/picture, row, puppet_layer)
	var/obj/effect/abstract/chrome_puppet/puppet = new(bearer_spot)
	puppet.name = rig.body.name
	puppet.icon = picture
	puppet.dir = SOUTH
	puppet.plane = bearer.plane
	puppet.layer = puppet_layer
	puppet.pixel_x = bearer.pixel_x
	puppet.pixel_w = bearer.pixel_w
	puppet.pixel_y = bearer.pixel_y + row * ICON_SIZE_Y
	puppet.pixel_z = bearer.pixel_z - row * ICON_SIZE_Y
	rig.puppets[key] = puppet
	return puppet

/// The two arms of [rig] in the order key poses name them: the near one then the far one seen from the side, else the one on the viewer's left then the other.
/datum/gorilla_slam/proc/arm_pair(datum/chrome_rig/rig)
	if(rig.facing & (EAST|WEST))
		var/near = rig.near_side()
		return list(near, near == "l" ? "r" : "l")
	return rig.facing == NORTH ? list("l", "r") : list("r", "l")

/**
 * Builds the bearer's rig for each way he faces in the move, and a puppet of the body for each. Back to front:
 * seen from the side, far arm, legs and torso, the body, near arm; from behind, the body, torso, arms; from the front,
 * torso, the body, arms. Returns FALSE if either couldn't be rigged.
 */
/datum/gorilla_slam/proc/build_rigs()
	rigs = list()
	var/list/ways = taking == facing ? list(taking) : list(taking, facing)
	for(var/way in ways)
		var/datum/chrome_rig/rig = new(bearer, way)
		rigs["[way]"] = rig
		if(!picture(rig, bearer, way))
			return FALSE
	victim_rig = new(victim, face_down ? NORTH : SOUTH)
	if(!picture(victim_rig, victim, victim_rig.facing))
		return FALSE
	var/base = bearer.layer
	for(var/way in ways)
		var/datum/chrome_rig/rig = rigs["[way]"]
		// The row of the tile the body is on while this rig shows: the one it is taken from, then the one it lands on
		var/turf/from = way == taking ? victim_spot : spot
		var/turf/onto = way == facing ? spot : victim_spot
		var/body_row = min(from.y, onto.y) < bearer_spot.y ? -1 : 0
		// The body's picture first: it is the one that changes on screen the moment the puppets come on
		stand(victim_rig, "body_[way]", victim_rig.flat, way == NORTH ? 0 : body_row, way == NORTH ? base - 0.02 : base + 0.02)
		var/icon/whole = rig.cut_without_arms("both")
		if(way & (EAST|WEST))
			// Split at the belt, the halves sharing three rows so no gap opens behind the bend
			var/icon/legs = icon(whole)
			legs.DrawBox(null, 1, 13, ICON_SIZE_X, ICON_SIZE_Y)
			var/icon/torso = icon(whole)
			torso.DrawBox(null, 1, 1, ICON_SIZE_X, 9)
			stand(rig, "legs", legs, 0, base)
			stand(rig, "body", torso, 0, base + 0.001)
			var/near = rig.near_side()
			stand(rig, "arm_[near]", rig.arm_picture(near), body_row, base + 0.03)
			var/far = near == "l" ? "r" : "l"
			stand(rig, "arm_[far]", rig.arm_picture(far), 0, base - 0.02)
		else if(way == NORTH)
			stand(rig, "body", whole, 0, base)
			for(var/side in list("l", "r"))
				stand(rig, "arm_[side]", rig.arm_picture(side), 0, base + 0.02)
		else
			stand(rig, "body", whole, 0, base)
			for(var/side in list("l", "r"))
				stand(rig, "arm_[side]", rig.arm_picture(side), body_row, base + 0.03)
	conceal_after_hold(rigs["[taking]"])
	conceal_after_hold(victim_rig)
	// The rig he turns into hides no body of its own: its puppets still go in the same file as the rest
	if(taking != facing)
		var/datum/chrome_rig/turned = rigs["[facing]"]
		turned.pack()
	return TRUE

/**
 * Hides [rig]'s real body as the rig does, but only when the hold is over by the client's own clock, in step with the
 * puppets. Until then the bearer's puppets stand exactly over him and the body's is unseen, so nothing changes on screen
 * while their pictures arrive.
 */
/datum/gorilla_slam/proc/conceal_after_hold(datum/chrome_rig/rig)
	rig.conceal()
	var/hide = rig.body.get_filter(SLAM_RIG_HIDE_FILTER)
	if(!hide)
		return
	var/static/list/hidden = list(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0)
	animate(hide, color = COLOR_MATRIX_IDENTITY, time = 0)
	animate(color = COLOR_MATRIX_IDENTITY, time = GORILLA_SLAM_HOLD_TIME)
	animate(color = hidden, time = GORILLA_SLAM_SWAP)

// =========================================================================
// THE POSES
// =========================================================================

/// The body at [time]: list(x, y, turn), its middle in pixels from where the bearer is drawn and its turn in degrees clockwise.
/datum/gorilla_slam/proc/body_at(time)
	if(time <= t_grip)
		return list(held_x, held_y, held_angle)
	if(time <= t_top)
		// Fast out of the floor, easing into the top
		var/up = gorilla_slam_ease(SLAM_EASE_OUT, (time - t_grip) / (t_top - t_grip))
		return list(held_x + (top_x - held_x) * up, held_y + (top_y - held_y) * up, held_angle + (top_angle - held_angle) * up)
	if(time <= t_drive)
		return list(top_x, top_y, top_angle)
	if(time <= t_hit)
		// Straight down, faster all the way
		var/down = gorilla_slam_ease(SLAM_EASE_IN, (time - t_drive) / (t_hit - t_drive))
		return list(top_x + (land_x - top_x) * down, top_y + (land_y - top_y) * down, top_angle + (land_angle - top_angle) * down)
	// It bounces once, tipping, and drops back onto where the real body lies
	var/settled = clamp((time - t_hit) / GORILLA_SLAM_REBOUND_TIME, 0, 1)
	var/hop = sin(180 * settled)
	var/tip = (land_angle < 0 ? GORILLA_SLAM_BOUNCE_TIP : -GORILLA_SLAM_BOUNCE_TIP) * hop
	return list(
		land_x + (final_x - land_x) * settled,
		land_y + (final_y - land_y) * settled + (arm?.slam_overhead ? GORILLA_SLAM_BOUNCE : BRAWLER_SLAM_BOUNCE) * hop,
		land_angle + (final_angle - land_angle) * settled + tip,
	)

/// The body puppet's transform at [time].
/datum/gorilla_slam/proc/body_matrix(time)
	var/list/at = body_at(time)
	var/matrix/placed
	if(landed && time >= t_hit + GORILLA_SLAM_REBOUND_TIME && !QDELETED(victim))
		// The real body's own turn, so the puppet ends in its pixels
		placed = matrix(victim.transform)
	else
		placed = matrix()
		placed.Turn(at[3])
	placed.Translate(at[1], at[2])
	return placed

/// The point [x], [y] of the scene (pixels from where the bearer is drawn) in the body's own pixels at [time].
/datum/gorilla_slam/proc/on_body(time, x, y)
	var/list/at = body_at(time)
	var/dx = x - at[1]
	var/dy = y - at[2]
	return list(dx * cos(at[3]) - dy * sin(at[3]), dx * sin(at[3]) + dy * cos(at[3]))

/**
 * The bearer's transforms in a pose of the rig facing [way]: list(legs, torso, arms' base). Seen from the side the legs lean
 * from the feet and the torso bends on at the belt; from the front or back the whole body is squashed and the legs are null.
 */
/datum/gorilla_slam/proc/bases(way, shift_x, shift_y, lean, waist, squash, drop)
	if(way & (EAST|WEST))
		var/forward = way == EAST ? 1 : -1
		var/matrix/legs = chrome_rig_turn(forward * lean, 0, CHROME_RIG_FEET_Y)
		var/matrix/torso = chrome_rig_turn(forward * waist, 0, SLAM_WAIST_Y)
		torso.Multiply(legs)
		torso.Translate(shift_x, shift_y)
		legs.Translate(shift_x, shift_y)
		return list(legs, torso, torso)
	var/datum/chrome_rig/rig = rigs["[way]"]
	var/shoulder_y = rig.shoulder("l")[2]
	// The arms come down with the squashed shoulders
	return list(null, matrix(1, 0, shift_x, 0, squash, shift_y - drop), matrix(1, 0, shift_x, 0, 1, shift_y + shoulder_y * squash - drop - shoulder_y))

/// The bases of key pose [pose].
/datum/gorilla_slam/proc/bases_of(datum/gorilla_slam_pose/pose)
	return bases(pose.facing, pose.shift_x, pose.shift_y, pose.lean, pose.waist, pose.squash, pose.drop)

/// The arm of [rig] on [side] as swing_arm() would leave it: list(turn, length).
/datum/gorilla_slam/proc/swung(datum/chrome_rig/rig, side, angle, reach)
	return list(angle * rig.raise_sign(side), max(GORILLA_SLAM_MIN_REACH, 1 + reach / (GLOB.chrome_rig_arm_length["[rig.facing]"] || 10)))

/// The arm of [rig] on [side] with its hand at [x], [y] of the scene, the body under it turned by [base]: list(turn, length). It stops short past its longest.
/datum/gorilla_slam/proc/reaching(datum/chrome_rig/rig, side, x, y, matrix/base)
	var/list/pose = rig.pose_reaching(side, x, y, 0, base)
	pose[2] = min(pose[2], GORILLA_SLAM_MAX_REACH)
	return pose

/**
 * Poses [pose] with both fists on a body lying on the tile at [at_x], [at_y] (pixels from where the bearer stands), its
 * middle [rise] pixels above the tile's: bent at the belt and leaning in, seen from the side; dropped and lunging, from the
 * front or back. [on_table] is the shallower reach onto a table top.
 */
/datum/gorilla_slam/proc/press(datum/gorilla_slam_pose/pose, at_x, at_y, rise, on_table)
	var/datum/chrome_rig/rig = rigs["[pose.facing]"]
	var/way_x = (pose.facing == EAST) - (pose.facing == WEST)
	var/way_y = (pose.facing == NORTH) - (pose.facing == SOUTH)
	// How far in front of him the tile is: a whole tile, or none for his own
	var/ahead = at_x * way_x + at_y * way_y
	var/body_y = at_y + rise
	pose.arms = list()
	if(way_x)
		pose.waist = on_table ? 30 : 50
		pose.shift_x = way_x * ((on_table ? 10 : 12) + (ahead - ICON_SIZE_X) * 18 / ICON_SIZE_X)
		// A tile up or down the map as well: he goes most of the way with it
		pose.shift_y = at_y * 22 / ICON_SIZE_Y
		var/list/pair = arm_pair(rig)
		pose.arms[pair[1]] = list(SLAM_ARM_POINT, pose.shift_x + way_x * (on_table ? 11 : 15), body_y + (on_table ? 2 : 3))
		pose.arms[pair[2]] = list(SLAM_ARM_POINT, pose.shift_x + way_x * (on_table ? 9 : 12), body_y + (on_table ? 2 : 3))
		return
	var/share = ahead / ICON_SIZE_Y
	var/edge
	if(way_y > 0)
		pose.squash = 0.8
		pose.drop = 3
		pose.shift_y = (on_table ? 13 : 10) * share
		edge = body_y - (on_table ? 7 : 4)
	else
		pose.squash = on_table ? 0.85 : 0.8
		pose.drop = on_table ? 2.25 : 3
		pose.shift_y = (on_table ? -4 : -14) * share
		edge = body_y + (on_table ? 6 : 7) * share + 2 * (1 - share)
	for(var/side in list("l", "r"))
		pose.arms[side] = list(SLAM_ARM_POINT, rig.shoulder(side)[1], edge)

/// Works out [pose]'s arms: where each fist is on the body (grips) and the arm's own turn and length there (reached).
/datum/gorilla_slam/proc/settle_arms(datum/gorilla_slam_pose/pose)
	var/datum/chrome_rig/rig = rigs["[pose.facing]"]
	var/matrix/base = bases_of(pose)[3]
	for(var/side in list("l", "r"))
		var/list/does = pose.arms[side]
		switch(does[1])
			if(SLAM_ARM_SWING)
				pose.reached[side] = swung(rig, side, does[2], does[3])
				continue
			if(SLAM_ARM_GRIP)
				pose.grips[side] = list(does[2], does[3])
			if(SLAM_ARM_POINT)
				pose.grips[side] = on_body(pose.time, does[2], does[3])
			if(SLAM_ARM_HELD)
				var/list/swing = swung(rig, side, does[2], does[3])
				var/list/hand = rig.hand_at(side, list(swing[1], swing[2], base))
				pose.grips[side] = on_body(pose.time, hand[1], hand[2])
		var/list/grip = pose.grips[side]
		var/list/point = chrome_rig_apply(body_matrix(pose.time), grip[1], grip[2])
		pose.reached[side] = reaching(rig, side, point[1], point[2], base)

/// Both arms hanging.
/datum/gorilla_slam/proc/arms_down()
	return list("l" = list(SLAM_ARM_SWING, 0, 0), "r" = list(SLAM_ARM_SWING, 0, 0))

/// Builds the key poses: standing through the hold, the grip, the top (the end of the hoist in the rig that takes the body, then held in the rig that brings it down), the impact, half way up, and upright.
/datum/gorilla_slam/proc/build_keys()
	var/datum/chrome_rig/take_rig = rigs["[taking]"]
	var/datum/chrome_rig/slam_rig = rigs["[facing]"]
	var/take_x = (taking == EAST) - (taking == WEST)
	var/slam_x = (facing == EAST) - (facing == WEST)

	var/datum/gorilla_slam_pose/stood = new(0, taking)
	stood.arms = arms_down()
	var/datum/gorilla_slam_pose/waited = new(GORILLA_SLAM_HOLD_TIME, taking)
	waited.arms = arms_down()

	// The grip. A body on its feet: he leans in and takes its near side by belt and collar, or its sides seen from the
	// front or back. A body on the floor: he goes down to it as he will at the impact.
	var/datum/gorilla_slam_pose/grip = new(t_grip, taking, SLAM_EASE_SINE)
	var/list/pair = arm_pair(take_rig)
	if(held_angle)
		press(grip, held_x, held_y - PIXEL_Y_OFFSET_LYING, PIXEL_Y_OFFSET_LYING, FALSE)
	else if(take_x)
		grip.waist = 18
		grip.shift_x = 4 * take_x
		grip.shift_y = held_y * 22 / ICON_SIZE_Y
		grip.arms = list()
		grip.arms[pair[1]] = list(SLAM_ARM_GRIP, -5 * take_x, -6)
		grip.arms[pair[2]] = list(SLAM_ARM_GRIP, -4 * take_x, 3)
	else if(taking == NORTH)
		grip.arms = list()
		grip.arms[pair[1]] = list(SLAM_ARM_GRIP, -5, -3)
		grip.arms[pair[2]] = list(SLAM_ARM_GRIP, 5, -3)
	else
		grip.squash = 0.9
		grip.drop = 1.5
		grip.shift_y = -4
		grip.arms = list()
		grip.arms[pair[1]] = list(SLAM_ARM_GRIP, -6, 2)
		grip.arms[pair[2]] = list(SLAM_ARM_GRIP, 6, 2)

	// The top. Gorilla Arms: pressed overhead at full reach, leaning back under it. Brawler myomers: at the shoulder.
	var/datum/gorilla_slam_pose/top = new(t_top, facing)
	pair = arm_pair(slam_rig)
	top.arms = list()
	if(slam_x)
		if(arm.slam_overhead)
			top.lean = -6
			top.arms[pair[1]] = list(SLAM_ARM_HELD, 166, 6)
			top.arms[pair[2]] = list(SLAM_ARM_HELD, 174, 6)
		else
			top.arms[pair[1]] = list(SLAM_ARM_GRIP, -7 * slam_x, 0)
			top.arms[pair[2]] = list(SLAM_ARM_GRIP, -5 * slam_x, 4.5)
	else
		if(arm.slam_overhead && facing == NORTH)
			top.shift_y = GORILLA_SLAM_TOP_BACK_RISE
		for(var/side in list("l", "r"))
			top.arms[side] = list(SLAM_ARM_POINT, slam_rig.shoulder(side)[1], top_y - (arm.slam_overhead ? 8 : 7))
	settle_arms(top)
	var/datum/gorilla_slam_pose/top_held = new(t_drive, facing)
	top_held.lean = top.lean
	top_held.shift_y = top.shift_y
	top_held.arms = list()
	// The hoist ends with the fists where the top has them, in the rig that took the body
	var/datum/gorilla_slam_pose/hoisted = new(t_top, taking, SLAM_EASE_OUT)
	hoisted.arms = list()
	if(taking == facing)
		hoisted.lean = top.lean
		hoisted.shift_y = top.shift_y
	for(var/side in list("l", "r"))
		var/list/grip_at = top.grips[side]
		top_held.arms[side] = list(SLAM_ARM_GRIP, grip_at[1], grip_at[2])
		hoisted.arms[side] = list(SLAM_ARM_GRIP, grip_at[1], grip_at[2])

	// The impact, and half way back up with his hands off it
	var/datum/gorilla_slam_pose/impact = new(t_hit, facing, SLAM_EASE_IN)
	press(impact, tile_x, tile_y, land_y - tile_y, !isnull(table_ref))
	var/datum/gorilla_slam_pose/rising = new(t_mid, facing, SLAM_EASE_OUT)
	rising.shift_x = impact.shift_x / 2
	rising.shift_y = impact.shift_y / 2
	rising.arms = list()
	if(slam_x)
		rising.waist = 24
		rising.arms[pair[1]] = list(SLAM_ARM_SWING, 38, 2)
		rising.arms[pair[2]] = list(SLAM_ARM_SWING, 46, 2)
	else
		rising.squash = 0.9
		rising.drop = 1.5
		for(var/side in list("l", "r"))
			rising.arms[side] = list(SLAM_ARM_SWING, 24, 0)
	var/datum/gorilla_slam_pose/upright = new(t_up, facing, SLAM_EASE_SINE)
	upright.arms = arms_down()
	var/datum/gorilla_slam_pose/still = new(t_end, facing)
	still.arms = arms_down()

	keys = list(stood, waited, grip, hoisted, top, top_held, impact, rising, upright, still)
	for(var/datum/gorilla_slam_pose/pose as anything in keys)
		if(pose != top)
			settle_arms(pose)

/**
 * The bearer's puppets in the rig facing [way] at [time]: key ("legs", "body", "arm_l", "arm_r") -> transform. The body
 * pose is eased between the keys either side; an arm on the body is solved onto its grip, which slides between the keys'
 * grips, and the hand of an arm coming off it or going onto it is carried straight between where the two keys have it.
 */
/datum/gorilla_slam/proc/pose_at(time, way)
	var/datum/gorilla_slam_pose/from_key
	var/datum/gorilla_slam_pose/to_key
	for(var/i in 1 to length(keys) - 1)
		var/datum/gorilla_slam_pose/first = keys[i]
		var/datum/gorilla_slam_pose/second = keys[i + 1]
		if(first.facing != way || second.facing != way || second.time <= first.time)
			continue
		from_key = first
		to_key = second
		if(time <= second.time)
			break
	if(!from_key)
		return null
	var/datum/chrome_rig/rig = rigs["[way]"]
	var/progress = gorilla_slam_ease(to_key.ease, (time - from_key.time) / (to_key.time - from_key.time))
	var/list/base = bases(way,
		from_key.shift_x + (to_key.shift_x - from_key.shift_x) * progress,
		from_key.shift_y + (to_key.shift_y - from_key.shift_y) * progress,
		from_key.lean + (to_key.lean - from_key.lean) * progress,
		from_key.waist + (to_key.waist - from_key.waist) * progress,
		from_key.squash + (to_key.squash - from_key.squash) * progress,
		from_key.drop + (to_key.drop - from_key.drop) * progress)
	. = list("body" = base[2])
	if(base[1])
		.["legs"] = base[1]
	var/matrix/held
	for(var/side in list("l", "r"))
		var/list/grip_from = from_key.grips[side]
		var/list/grip_to = to_key.grips[side]
		var/list/arm_pose
		if(grip_from && grip_to)
			held ||= body_matrix(time)
			var/list/point = chrome_rig_apply(held, grip_from[1] + (grip_to[1] - grip_from[1]) * progress, grip_from[2] + (grip_to[2] - grip_from[2]) * progress)
			arm_pose = reaching(rig, side, point[1], point[2], base[3])
		else
			// Coming off the body or going onto it: the hand goes straight from where one key has it to where the other
			// does, in his own pixels, so the arm folds in past the shoulder and never swings out wide
			var/list/hand_from = rig.hand_at(side, from_key.reached[side])
			var/list/hand_to = rig.hand_at(side, to_key.reached[side])
			arm_pose = rig.pose_reaching(side, hand_from[1] + (hand_to[1] - hand_from[1]) * progress, hand_from[2] + (hand_to[2] - hand_from[2]) * progress)
			arm_pose[2] = min(arm_pose[2], GORILLA_SLAM_MAX_REACH)
		.["arm_[side]"] = rig.arm_matrix(side, arm_pose[1], arm_pose[2], base[3])

/// Every puppet takes its first pose: the rig that takes the body as he stands, the rig that brings it down at the top and unseen until then.
/datum/gorilla_slam/proc/set_stage()
	for(var/way_text in rigs)
		var/datum/chrome_rig/rig = rigs[way_text]
		var/way = rig.facing
		var/first_time = way == taking ? 0 : t_top
		var/list/poses = pose_at(first_time, way)
		var/obj/effect/abstract/chrome_puppet/held = victim_rig.puppet("body_[way]")
		// Unseen at first: through the hold in the rig that takes the body, until the top in the rig that brings it down
		held.alpha = 0
		if(way == taking)
			// Exactly as the real body is drawn, whatever its size
			var/matrix/as_held = matrix(victim.transform)
			as_held.Translate(held_x, held_y)
			held.transform = as_held
		else
			held.transform = body_matrix(first_time)
		for(var/key in poses)
			var/obj/effect/abstract/chrome_puppet/puppet = rig.puppet(key)
			puppet.transform = poses[key]
			if(way != taking)
				puppet.alpha = 0

/**
 * Plays the move from [from_time] to [to_time] (deciseconds from the click, now being [from_time]): every puppet goes
 * through its poses in straight steps of GORILLA_SLAM_STEP. The rig that takes the body shows until the top and the rig
 * that brings it down from then on.
 */
/datum/gorilla_slam/proc/play(from_time, to_time)
	for(var/way_text in rigs)
		var/datum/chrome_rig/rig = rigs[way_text]
		var/way = rig.facing
		var/on_from = max(from_time, way == taking ? 0 : t_top)
		var/on_to = min(to_time, way == facing ? t_end : t_top)
		if(on_to <= on_from)
			continue
		var/steps = max(1, round((on_to - on_from) / GORILLA_SLAM_STEP))
		var/step_time = (on_to - on_from) / steps
		var/list/chains = list()
		for(var/i in 1 to steps)
			var/time = on_from + step_time * i
			var/list/poses = pose_at(time, way)
			poses["body_[way]"] = body_matrix(time)
			for(var/key in poses)
				if(!chains[key])
					chains[key] = list()
				chains[key] += poses[key]
		for(var/key in chains)
			var/of_body = key == "body_[way]"
			var/obj/effect/abstract/chrome_puppet/puppet = of_body ? victim_rig.puppet(key) : rig.puppet(key)
			if(!puppet)
				continue
			var/list/poses = chains[key]
			var/wait = on_from - from_time
			if(of_body && way == taking && on_from < GORILLA_SLAM_HOLD_TIME)
				// The body's own puppet comes on when the hold ends, as the real body goes
				poses.Cut(1, round((GORILLA_SLAM_HOLD_TIME - on_from) / step_time) + 1)
				wait = GORILLA_SLAM_HOLD_TIME - from_time
			send_through(puppet, poses, step_time, wait, on_to < to_time)

/**
 * Sends [puppet] through [poses] (transforms), [step_time] each. With a [wait] it stays unseen that long first; with
 * [leave] it goes unseen at the end. The swap takes a hundredth of a second, so two rigs never show at once.
 */
/datum/gorilla_slam/proc/send_through(obj/effect/abstract/chrome_puppet/puppet, list/poses, step_time, wait = 0, leave = FALSE)
	var/begun = FALSE
	var/first_step = step_time
	if(wait > 0)
		animate(puppet, alpha = 0, time = wait)
		animate(alpha = 255, time = GORILLA_SLAM_SWAP)
		first_step = max(0, step_time - GORILLA_SLAM_SWAP)
		begun = TRUE
	for(var/i in 1 to length(poses))
		if(begun)
			animate(transform = poses[i], time = i == 1 ? first_step : step_time)
		else
			animate(puppet, transform = poses[i], time = step_time)
			begun = TRUE
	if(leave)
		animate(alpha = 0, time = GORILLA_SLAM_SWAP)

// =========================================================================
// CALLING IT OFF
// =========================================================================

/datum/gorilla_slam/proc/listen()
	RegisterSignals(bearer, list(
		COMSIG_MOVABLE_MOVED,
		COMSIG_ATOM_NO_LONGER_PULLING,
		COMSIG_LIVING_SET_BODY_POSITION,
		COMSIG_MOB_STATCHANGE,
		SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED),
	), PROC_REF(on_change))
	RegisterSignal(victim, COMSIG_MOVABLE_MOVED, PROC_REF(on_change))
	RegisterSignal(bearer, COMSIG_QDELETING, PROC_REF(on_deleted))
	RegisterSignal(victim, COMSIG_QDELETING, PROC_REF(on_deleted))

/datum/gorilla_slam/proc/stop_listening()
	if(bearer)
		UnregisterSignal(bearer, list(
			COMSIG_MOVABLE_MOVED,
			COMSIG_ATOM_NO_LONGER_PULLING,
			COMSIG_LIVING_SET_BODY_POSITION,
			COMSIG_MOB_STATCHANGE,
			SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED),
			COMSIG_QDELETING,
		))
	if(victim)
		UnregisterSignal(victim, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))

/// Whether the slam can still land: the bearer up and able, the grab on, both where they stood, the arm running.
/datum/gorilla_slam/proc/still_held()
	if(QDELETED(bearer) || QDELETED(victim) || QDELETED(arm) || arm.owner != bearer || !arm.gorilla_running())
		return FALSE
	if(bearer.stat != CONSCIOUS || HAS_TRAIT(bearer, TRAIT_INCAPACITATED) || bearer.body_position == LYING_DOWN)
		return FALSE
	if(bearer.pulling != victim || bearer.grab_state < GRAB_AGGRESSIVE || victim.buckled)
		return FALSE
	return bearer.loc == bearer_spot && victim.loc == victim_spot

/// Something changed for one of them: before the impact the slam is called off if it can't land any more; after it, a body that is moved shows as it is.
/datum/gorilla_slam/proc/on_change(datum/source)
	SIGNAL_HANDLER
	if(ended || placing)
		return
	if(!landed)
		if(!still_held())
			call_off()
		return
	if(bearer.loc != bearer_spot || victim.loc != spot)
		finish()

/datum/gorilla_slam/proc/on_deleted(datum/source)
	SIGNAL_HANDLER
	finish()

/**
 * Calls the slam off before the impact. The bearer shows as he is now, free to move, and the body comes down on its feet
 * where it stands, unhurt.
 */
/datum/gorilla_slam/proc/call_off()
	if(landed || ended)
		return
	ended = TRUE
	if(hit_timer)
		deltimer(hit_timer)
		hit_timer = null
	stop_listening()
	if(QDELETED(bearer) || QDELETED(victim))
		finish()
		return
	REMOVE_TRAIT(bearer, TRAIT_IMMOBILIZED, GORILLA_SLAM_TRAIT)
	victim.visible_message(span_danger("[bearer] loses [bearer.p_their()] hold on [victim]!"), span_userdanger("[bearer] loses [bearer.p_their()] hold on you!"), ignored_mobs = bearer)
	to_chat(bearer, span_danger("You lose your hold on [victim]!"))
	var/showing = world.time - started_at < t_top ? taking : facing
	var/obj/effect/abstract/chrome_puppet/held = posed ? victim_rig?.puppet("body_[showing]") : null
	if(!held || !isturf(victim.loc))
		finish()
		return
	// His own puppets go at once; the body's puppet comes down onto the real body, and the one not on yet never shows
	QDEL_LIST_ASSOC_VAL(rigs)
	rigs = null
	for(var/key in victim_rig.puppets)
		if(victim_rig.puppets[key] != held)
			victim_rig.drop_puppet(key)
	var/list/victim_at = drawn_at(victim)
	var/matrix/down = matrix(victim.transform)
	down.Translate(victim_at[1], victim_at[2])
	animate(held, transform = down, alpha = 255, time = GORILLA_SLAM_SET_DOWN_TIME, easing = SINE_EASING | EASE_IN)
	end_timer = addtimer(CALLBACK(src, PROC_REF(finish)), GORILLA_SLAM_SET_DOWN_TIME, TIMER_STOPPABLE | TIMER_DELETE_ME)

/// The slam is over: the puppets go and both bodies show.
/datum/gorilla_slam/proc/finish()
	end_timer = null
	if(!QDELETED(src))
		qdel(src)

// =========================================================================
// THE IMPACT
// =========================================================================

/// The body comes down, if the slam can still land: the grab lets go, the body is put on the tile, and the blow lands.
/datum/gorilla_slam/proc/hit()
	hit_timer = null
	if(landed || ended)
		return
	if(!still_held())
		call_off()
		return
	var/obj/structure/table/table = table_ref?.resolve()
	if(table && (QDELETED(table) || table.loc != spot))
		table = null
	if(!table && !gorilla_slam_floor_ok(spot))
		call_off()
		return
	placing = TRUE
	bearer.stop_pulling()
	if(victim.loc != spot)
		var/passtable_key = REF(src)
		if(table)
			passtable_on(victim, passtable_key)
		victim.Move(spot, get_dir(victim, spot))
		if(table)
			passtable_off(victim, passtable_key)
	placing = FALSE
	if(victim.loc != spot)
		// Something stopped them getting there
		call_off()
		return
	landed = TRUE
	bearer.setDir(facing)
	// On its back, or face down for a head-aimed table slam: tg's fall keeps a body facing north or south as it is
	if(victim.rotate_on_lying)
		victim.setDir(face_down ? NORTH : SOUTH)
	var/on_table = !isnull(table)
	var/bled = strike(table)
	if(!QDELETED(src) && !QDELETED(victim) && !QDELETED(bearer))
		impact_fx(on_table, bled)
	if(QDELETED(src) || QDELETED(victim) || QDELETED(bearer))
		if(!QDELETED(src))
			finish()
		return
	if(victim.rotate_on_lying && victim.body_position == LYING_DOWN)
		victim.set_lying_angle(facing == EAST ? LYING_ANGLE_WEST : LYING_ANGLE_EAST)
	if(!posed)
		finish()
		return
	// The real body is under the puppets: whatever tg is still easing on it (the fall, the grab's pull, a table's lift) ends now
	animate(victim, transform = victim.transform, pixel_x = victim.pixel_x, pixel_y = victim.pixel_y, pixel_w = victim.pixel_w, pixel_z = victim.pixel_z, time = 0, flags = ANIMATION_END_NOW)
	var/list/victim_at = drawn_at(victim)
	final_x = victim_at[1]
	final_y = victim_at[2]
	final_angle = turn_of(victim)
	play(t_hit, t_end)
	end_timer = addtimer(CALLBACK(src, PROC_REF(finish)), t_end - t_hit, TIMER_STOPPABLE | TIMER_DELETE_ME)

/**
 * The blow itself on the body, now on the tile: the damage through #509 as one line, the stamina, the knockdown, and what
 * the table takes. Returns TRUE if it opened a wound that bleeds.
 */
/datum/gorilla_slam/proc/strike(obj/structure/table/table)
	var/obj/item/bodypart/limb = victim.get_bodypart(aimed_zone) || victim.get_bodypart(BODY_ZONE_CHEST)
	var/others
	var/self
	if(table)
		others = face_down ? "[bearer] slams [victim] face first into [table]!" : "[bearer] slams [victim] onto [table]!"
		self = face_down ? "[bearer] slams you face first into [table]!" : "[bearer] slams you onto [table]!"
	else
		others = "[bearer] slams [victim] into the floor!"
		self = "[bearer] slams you into the floor!"
	victim.hv_hold_attack_message(others, self, null, bearer, vision_range = DEFAULT_MESSAGE_RANGE)
	var/armour = victim.run_armor_check(limb, MELEE)
	// No attack direction: a body driven into the floor throws no blood across the room (#509's heavy-hit spray)
	gorilla_hold_spray(victim)
	var/mob/living/carbon/carbon_victim = iscarbon(victim) ? victim : null
	var/list/wounds_before = carbon_victim?.gorilla_wound_snapshot()
	// What tg lays itself for a chest that bleeds inside from the blow (below): where, and what is there already
	var/list/coughed_on = list(spot)
	var/turf/faced = get_step(spot, victim.dir)
	if(faced)
		coughed_on += faced
	var/list/blood_before = list()
	for(var/turf/where as anything in coughed_on)
		for(var/obj/effect/blood in where)
			if(istype(blood, /obj/effect/decal/cleanable/blood) || istype(blood, /obj/effect/temp_visual/dir_setting/bloodsplatter))
				blood_before += blood
	victim.apply_damage(table ? arm.slam_table_damage : arm.slam_floor_damage, BRUTE, limb || BODY_ZONE_CHEST, armour, wound_bonus = arm.punch_wound_bonus, attacking_item = fist)
	victim.hv_flush_hit()
	if(QDELETED(victim))
		return FALSE
	. = !isnull(carbon_victim) && gorilla_slam_opened_wound(carbon_victim, wounds_before)
	// A chest that bleeds inside from the blow coughs it up (tg's cracked ribs): real blood, which tg bursts one way over
	// the top of the body and splashes on the tile it faces. A body on its back throws the slam's drops instead, so what
	// tg has just laid is taken up and the drops (the same blood) go down in its place.
	for(var/turf/where as anything in coughed_on)
		for(var/obj/effect/blood in where)
			if(blood in blood_before)
				continue
			if(istype(blood, /obj/effect/decal/cleanable/blood) || istype(blood, /obj/effect/temp_visual/dir_setting/bloodsplatter))
				qdel(blood)
				. = TRUE
	victim.apply_damage(table ? arm.slam_table_stamina : arm.slam_floor_stamina, STAMINA)
	victim.Knockdown(arm.slam_knockdown)
	gorilla_register_aggression(victim, bearer)
	if(table)
		var/datum/component/table_smash/smash = table.GetComponent(/datum/component/table_smash)
		table.take_damage(arm.slam_table_break)
		// Glass tables break as they do under any slammed body
		if(!QDELETED(table))
			smash?.after_smash?.Invoke(victim)
	log_combat(bearer, victim, table ? "piston-slammed onto a table" : "piston-slammed into the floor", "gorilla arms")

/**
 * What the impact looks and sounds like. Both cameras shake and the body flashes white. A ring spreads from under it: on
 * the table top for a table slam, with the table's own crash; on a floor with cracks, and for Gorilla Arms dust and the
 * heavy crash. With [bled], a few drops of blood are thrown out round it.
 */
/datum/gorilla_slam/proc/impact_fx(on_table, bled)
	var/heavy = arm.slam_full_fx
	for(var/mob/living/shaken in list(bearer, victim))
		shake_camera(shaken, heavy ? 3 : 2, heavy ? 2 : 1)
	cyberware_flash_fx((posed && victim_rig?.puppet("body_[facing]")) || victim, 0.2 SECONDS)
	// Level with the middle of the body: a table top is half way up to where tg draws a body lying on it
	new /obj/effect/temp_visual/circle_wave/cyberware_slam/under_body(spot, heavy ? 0.8 : 0.5, on_table ? GORILLA_SLAM_TABLE_TOP / 2 : 0)
	if(on_table)
		playsound(victim, 'sound/effects/tableslam.ogg', 90, TRUE)
	else if(heavy)
		playsound(spot, 'sound/effects/meteorimpact.ogg', 40, TRUE)
		new /obj/effect/temp_visual/cyberware_impact_cracks(spot, "damaged1", 220)
		var/obj/effect/temp_visual/mook_dust/dust = cyberware_grey_dust(spot)
		if(dust)
			// On the tile's own row, as the ring is, so the body lying there draws over it
			dust.pixel_x = 0
			dust.pixel_y = 0
			dust.pixel_w = -ICON_SIZE_X / 2
			dust.pixel_z = -ICON_SIZE_Y / 2
	else
		playsound(spot, SFX_BODYFALL, 70, TRUE)
		new /obj/effect/temp_visual/cyberware_impact_cracks(spot, "damaged1", 70)
	if(bled && iscarbon(victim))
		gorilla_slam_blood(victim, spot)

/**
 * The slam's ring. tg's ring is drawn from half a tile toward the viewer, which puts it on the row in front of its own
 * tile and over anybody lying there; this one stays on its tile's row and is centred by eye only, so the body draws over it.
 */
/obj/effect/temp_visual/circle_wave/cyberware_slam/under_body
	pixel_x = 0
	pixel_y = 0
	pixel_w = -16
	pixel_z = -16

/obj/effect/temp_visual/circle_wave/cyberware_slam/under_body/Initialize(mapload, reach = 2, rise = 0)
	pixel_z += rise
	return ..()

/// Whether [victim] has a wound that bleeds which it didn't have, or had milder, at [before] (gorilla_wound_snapshot()): a cut, a stab, or bone through the skin.
/proc/gorilla_slam_opened_wound(mob/living/carbon/victim, list/before)
	for(var/datum/wound/wound as anything in victim.all_wounds)
		if((wound in before) && before[wound] >= wound.severity)
			continue
		if(wound.blood_flow > 0 || (istype(wound, /datum/wound/blunt/bone) && wound.severity >= WOUND_SEVERITY_CRITICAL))
			return TRUE
	return FALSE

/// A few drops of [victim]'s blood thrown out round where it lies on [floor], in a ragged ring: no two the same size or the same way up.
/proc/gorilla_slam_blood(mob/living/carbon/victim, turf/floor)
	if(!isturf(floor) || isgroundlessturf(floor) || victim.can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
		return
	var/list/blood_dna = victim.get_blood_dna_list()
	var/list/viruses = victim.get_static_viruses()
	var/drops = rand(GORILLA_SLAM_DROPS_MIN, GORILLA_SLAM_DROPS_MAX)
	var/first = rand(0, 359)
	for(var/i in 1 to drops)
		var/obj/effect/decal/cleanable/blood/splatter/gorilla_skid/drop = new(floor, viruses, blood_dna)
		if(QDELETED(drop))
			continue
		var/way = first + i * 360 / drops + rand(-18, 18)
		var/far = rand(GORILLA_SLAM_DROPS_NEAR, GORILLA_SLAM_DROPS_FAR)
		var/matrix/shape = matrix()
		shape.Scale(pick(0.45, 0.55, 0.7))
		shape.Turn(pick(0, 90, 180, 270))
		drop.transform = shape
		// From under the body outward. The floor is seen from above and a little from the front, so the ring is flattened.
		drop.pixel_x = 0
		drop.pixel_y = PIXEL_Y_OFFSET_LYING
		animate(drop, pixel_x = round(cos(way) * far), pixel_y = round(sin(way) * far * 0.75) + PIXEL_Y_OFFSET_LYING, time = 0.12 SECONDS, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)

#undef SLAM_ARM_GRIP
#undef SLAM_ARM_POINT
#undef SLAM_ARM_HELD
#undef SLAM_ARM_SWING
#undef SLAM_EASE_LINEAR
#undef SLAM_EASE_OUT
#undef SLAM_EASE_IN
#undef SLAM_EASE_SINE
#undef SLAM_WAIST_Y
#undef SLAM_RIG_HIDE_FILTER
