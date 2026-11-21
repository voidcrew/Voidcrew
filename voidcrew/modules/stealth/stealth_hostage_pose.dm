/**
 * # Hostages: the hold at gunpoint (stealth step 5, decision 62)
 *
 * Visual only, under hyperviolence's motion rules (voidcrew/modules/hyperviolence/visuals/_motion_core.dm): nothing
 * here moves, stuns, roots or hurts anyone.
 *
 * A body held at gunpoint (stealth_hostage_of()), or with a hand over its mouth (stealth_grip.dm, for now: its own
 * animation comes later), is drawn tight against the front of its holder, facing his way,
 * through tg's own grab offsets (GRABBING_TRAIT), which tg clears when he lets go:
 * - facing south it stands low in front of him, to his free-hand side, so his gun shows beside its head;
 * - facing north it stands beyond him, to the same side, and he is drawn over it;
 * - side-on it stands a quarter of a tile ahead and he is drawn over it, so his gun shows against its back.
 * The gun is never touched: it is tg's own in-hand picture, in his hand.
 *
 * Draw order is never set here. The body's pixel_y puts it on a screen row in front of or behind its holder, and the
 * client draws rows back to front (SIDE_MAP), so whoever is higher on the screen is behind, on every frame of a turn.
 *
 * Only the drawing between poses is ours, as a named animation (HOSTAGE_POSE_ANIM) that ends on the real offsets:
 * - the neck grab landing: tg moves the body onto the holder's tile at once and glides it there. For those few ticks
 *   the body is hidden by a colour filter (not its alpha or invisibility, which sight and AI read) and a copy of its
 *   look (/obj/effect/abstract/hostage_standin, unclickable) is drawn pulled into the pose instead; then the copy goes
 *   and the body shows again in place;
 * - a turn: the holder turns at once; the body swings round him to his new front, facing outward from him as it goes;
 * - letting go: tg leaves the two on one tile. The holder shoves and the freed body is pushed a few pixels out from
 *   where it was held, and goes on standing there (HOSTAGE_POSE_FREED offsets) until either of them moves, it falls
 *   or it is grabbed again; then it is back on the middle of its tile within a tick or two. If it is still held, only
 *   no longer at gunpoint (the gun put away), it goes straight back to tg's grab spot.
 * - the holder's own part is two short named sequences that end where he stands: a reach and tug as the neck grab
 *   lands, and the shove as he lets go.
 */

/// The filter that hides a body while its stand-in is drawn.
#define HOSTAGE_VIS_HIDE_FILTER "hostage_vis_hide"

/mob/living
	/// The copy drawn in this body's place while the neck grab lands, if any.
	var/obj/effect/abstract/hostage_standin/hostage_standin

/obj/effect/abstract/hostage_standin
	name = ""
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	animate_movement = NO_STEPS
	/// The body this is drawn in place of.
	var/atom/movable/body
	/// The steps it is playing, as given to play(), and when they started: for whoever takes over from here.
	var/list/steps
	var/steps_started = 0
	/// The timer that ends it.
	var/life_timer

/**
 * Hides `body` and stands a copy of its look on `at` for `time` deciseconds. The copy starts with no offsets and the
 * body's own facing and transform; the caller plays it from there (play()). A body that already has a copy gets a new
 * one in its place.
 */
/obj/effect/abstract/hostage_standin/Initialize(mapload, atom/movable/body, time = 5)
	. = ..()
	if(QDELETED(body))
		return INITIALIZE_HINT_QDEL
	if(isliving(body))
		var/mob/living/alive = body
		if(alive.hostage_standin)
			qdel(alive.hostage_standin)
		alive.hostage_standin = src
	src.body = body
	appearance = body.appearance
	// a look does not bring its facing with it
	setDir(body.dir)
	name = ""
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	pixel_x = 0
	pixel_y = 0
	pixel_w = 0
	pixel_z = 0
	body.add_filter(HOSTAGE_VIS_HIDE_FILTER, 20, color_matrix_filter(list(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,0)))
	RegisterSignal(body, COMSIG_QDELETING, PROC_REF(body_gone))
	live_for(time)

/obj/effect/abstract/hostage_standin/Destroy()
	if(life_timer)
		deltimer(life_timer)
		life_timer = null
	if(body)
		UnregisterSignal(body, COMSIG_QDELETING)
		body.remove_filter(HOSTAGE_VIS_HIDE_FILTER)
		if(isliving(body))
			var/mob/living/alive = body
			if(alive.hostage_standin == src)
				alive.hostage_standin = null
		body = null
	return ..()

/obj/effect/abstract/hostage_standin/proc/body_gone(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// The copy goes, and the body shows again, `time` deciseconds from now (instead of when it was going to).
/obj/effect/abstract/hostage_standin/proc/live_for(time)
	if(life_timer)
		deltimer(life_timer)
	life_timer = QDEL_IN_STOPPABLE(src, time)

/**
 * Plays `steps` on the copy, from the first step's values at once: each is
 * list(time, pixel_x, pixel_y, pixel_z, transform, facing, easing). pixel_y is where it stands on the floor (which
 * also puts it on its screen row, so it is drawn in front of or behind the bodies it passes), pixel_z how high off the
 * floor it is drawn. Offsets are from the tile the copy stands on. A null transform, facing or easing keeps the last.
 */
/obj/effect/abstract/hostage_standin/proc/play(list/new_steps)
	steps = new_steps
	steps_started = world.time
	var/matrix/turned = matrix(transform)
	var/facing = dir
	for(var/i in 1 to length(steps))
		var/list/step = steps[i]
		if(step[5])
			turned = step[5]
		if(step[6])
			facing = step[6]
		if(i == 1)
			animate(src, pixel_x = step[2], pixel_y = step[3], pixel_z = step[4], transform = turned, dir = facing, time = 0)
			continue
		var/list/before = steps[i - 1]
		animate(pixel_x = step[2], pixel_y = step[3], pixel_z = step[4], transform = turned, dir = facing, time = step[1] - before[1], easing = step[7] || LINEAR_EASING)

/// Where the copy is drawn now, list(pixel_x, pixel_y, pixel_z): along its steps (straight lines between them).
/obj/effect/abstract/hostage_standin/proc/now()
	if(!length(steps))
		return list(pixel_x, pixel_y, pixel_z)
	var/elapsed = world.time - steps_started
	var/list/before = steps[1]
	for(var/list/step as anything in steps)
		if(elapsed < step[1])
			var/frac = (elapsed - before[1]) / max(step[1] - before[1], 0.01)
			return list(before[2] + (step[2] - before[2]) * frac, before[3] + (step[3] - before[3]) * frac, before[4] + (step[4] - before[4]) * frac)
		before = step
	return list(before[2], before[3], before[4])

/// The animation tag for the held body's path, so a new one takes over from wherever the last one got to.
#define HOSTAGE_POSE_ANIM "hostage_pose"
/// The offset source a let-go body keeps its held spot under.
#define HOSTAGE_POSE_FREED "hostage_pose_freed"
/// The holder's own small moves (the tug as the neck grab lands, the shove as he lets go), a named sequence.
#define HOSTAGE_POSE_HOLDER_ANIM "hostage_pose_holder"
/// How far a let-go body is shoved out from where it was held, in pixels.
#define HOSTAGE_POSE_SHOVE 3
/// Facing south: how far in front (down the screen) the body is held. Facing north: how far beyond.
#define HOSTAGE_POSE_NEAR_S 10
#define HOSTAGE_POSE_NEAR_N 12
/// Facing south or north: how far it sits toward the holder's free hand.
#define HOSTAGE_POSE_SIDE 4
/// Side-on: how far ahead it is held.
#define HOSTAGE_POSE_AHEAD 8
/// Side-on: one screen row beyond the holder (so he is drawn over it), and drawn a pixel lower to stand level with him.
#define HOSTAGE_POSE_ROW 1
#define HOSTAGE_POSE_ROW_DROP -1
/// Times, deciseconds (a game tick is half of one).
#define HOSTAGE_POSE_QUARTER_TIME 2
#define HOSTAGE_POSE_HALF_TIME 3
#define HOSTAGE_POSE_LAND_TIME 2
#define HOSTAGE_POSE_SETTLE_TIME 2

/mob/living
	/// The holder's facing this body is posed for as his hostage, or 0.
	var/hostage_pose_dir = 0
	/// Which hand ("L"/"R") holds the gun the pose was made for.
	var/hostage_pose_hand
	/// Counts poses, so steps queued for an old one are dropped.
	var/hostage_pose_serial = 0
	/// The path being drawn: list(start world.time, list of list(time, x, y, z)), grab offsets from the holder.
	var/list/hostage_pose_path
	/// Keeps this body standing where it was held, once let go, until it or its holder moves.
	var/datum/hostage_pose_freed/hostage_pose_freed

/mob/living/carbon/human
	/// The tick this body's grip last tightened to a neck grab: tg pulls the held body onto its tile in that tick.
	var/hostage_neck_grab_tick = -1

/mob/living/carbon/human/setGrabState(newstate)
	. = ..()
	if(newstate == GRAB_NECK)
		hostage_neck_grab_tick = world.time

// ---------------------------------------------------------------------------------------------
// The poses

/// The held body's offset from its holder, list(pixel_x, pixel_y, pixel_z), for his `facing` and gun `hand` ("L"/"R").
/proc/hostage_pose_offset(facing, hand = "L")
	// his left hand is on the viewer's right when he faces south, and on the viewer's left when he faces north
	var/gun_side = hand == "R" ? -1 : 1
	switch(facing)
		if(SOUTH)
			return list(-gun_side * HOSTAGE_POSE_SIDE, -HOSTAGE_POSE_NEAR_S, 0)
		if(NORTH)
			return list(gun_side * HOSTAGE_POSE_SIDE, HOSTAGE_POSE_NEAR_N, 0)
		if(EAST)
			return list(HOSTAGE_POSE_AHEAD, HOSTAGE_POSE_ROW, HOSTAGE_POSE_ROW_DROP)
		if(WEST)
			return list(-HOSTAGE_POSE_AHEAD, HOSTAGE_POSE_ROW, HOSTAGE_POSE_ROW_DROP)
	return list(0, 0, 0)

/// The way a held body faces at `angle` degrees round its holder (0 east, 90 north): outward from him.
/proc/hostage_pose_facing_at(angle)
	if(angle > 45 && angle <= 135)
		return NORTH
	if(angle > -45 && angle <= 45)
		return EAST
	if(angle > -135 && angle <= -45)
		return SOUTH
	return WEST

/// Fast start, eased stop (cubic), 0 to 1.
/proc/hostage_pose_ease_out(u)
	return 1 - (1 - u) ** 3

/// Which hand holds the gun the hostage is held with ("L"/"R"): the active hand's gun first.
/mob/living/carbon/human/proc/hostage_pose_hand()
	var/obj/item/gun = get_active_held_item()
	if(!isgun(gun))
		gun = get_inactive_held_item()
	return (isgun(gun) && IS_RIGHT_INDEX(get_held_index_of_item(gun))) ? "R" : "L"

// ---------------------------------------------------------------------------------------------
// tg's grab offsets, taken over while the body is held at gunpoint

/mob/living/set_pull_offsets(mob/living/mob_to_set, grab_state = GRAB_PASSIVE, animate = TRUE)
	// tg leaves a buckled body as it is, and so do we
	if(mob_to_set.buckled)
		return ..()
	stealth_hold_upright(mob_to_set)
	var/mob/living/carbon/human/holder = ishuman(src) ? src : null
	if(holder && stealth_held_in_front(holder) == mob_to_set)
		holder.hostage_pose_apply(mob_to_set, animate)
		return
	if(mob_to_set.hostage_pose_dir)
		mob_to_set.hostage_pose_end()
	QDEL_NULL(mob_to_set.hostage_pose_freed)
	return ..()

/mob/living/reset_pull_offsets(mob/living/M, override)
	if(M.hostage_pose_dir && (override || !M.buckled))
		M.hostage_pose_end(src)
	return ..()

/// A turn swings the hostage round to the holder's new front, on the same tick.
/mob/living/carbon/human/setDir(newdir)
	var/old_dir = dir
	. = ..()
	if(dir == old_dir || !isliving(pulling))
		return
	var/mob/living/held = pulling
	if(held.hostage_pose_dir || stealth_held_in_front(src) == held)
		set_pull_offsets(held, grab_state)

/// The pose comes and goes with the gun in his hand: posed when one comes out mid-hold, dropped back to tg's grab
/// when it goes away, moved across when it changes hands.
/mob/living/carbon/human/update_held_items()
	. = ..()
	var/mob/living/held = pulling
	if(!isliving(held))
		return
	if(stealth_held_in_front(src) == held)
		if(held.hostage_pose_dir == dir && held.hostage_pose_hand == hostage_pose_hand())
			return
	else if(!held.hostage_pose_dir)
		return
	set_pull_offsets(held, grab_state)

// ---------------------------------------------------------------------------------------------
// Posing

/// Poses `held` against this holder's front for his facing, drawn from wherever it is now.
/mob/living/carbon/human/proc/hostage_pose_apply(mob/living/held, animate = TRUE)
	var/hand = hostage_pose_hand()
	var/old_dir = held.hostage_pose_dir
	if(old_dir == dir && held.hostage_pose_hand == hand)
		return
	// where the body is drawn now: tg's grab offset at the neck grab, else along our own path
	var/list/from = held.hostage_pose_now()
	if(held.hostage_standin)
		// turned again while the neck grab's stand-in was still being pulled in: carry on from where that got to
		from = held.hostage_standin.now()
		qdel(held.hostage_standin)
	var/list/target = hostage_pose_offset(dir, hand)
	if(held.hostage_pose_freed)
		held.hostage_pose_note(HOSTAGE_POSE_FREED)
		QDEL_NULL(held.hostage_pose_freed)
	// the new spot is only noted here: the path below draws the way to it and ends on it (written first and drawn
	// after, the body could show at the new spot for a frame before its swing started)
	held.hostage_pose_note(GRABBING_TRAIT, target)
	held.hostage_pose_dir = dir
	held.hostage_pose_hand = hand
	var/pose = ++held.hostage_pose_serial
	if(!animate || !isturf(held.loc))
		held.hostage_pose_path = null
		animate(held, tag = HOSTAGE_POSE_ANIM)
		held.update_offsets(FALSE)
		hostage_pose_face(held, pose, dir)
		return
	if(!old_dir)
		hostage_pose_land(held, from, target)
	else if(old_dir == dir)
		hostage_pose_settle(held, from, target)
	else
		hostage_pose_swing(held, pose, from, target, old_dir)

/// The neck grab landing: the body faces the holder's way at once and is pulled into the pose (fast start, eased
/// stop). tg has just moved it onto this tile from the next one and glides it across at a pace each client sets for
/// itself, so for those ticks a stand-in is drawn making the pull, from tg's grab spot into the pose, and the body
/// shows again where it then really is.
/mob/living/carbon/human/proc/hostage_pose_land(mob/living/held, list/grab, list/target)
	if(held.body_position == STANDING_UP)
		held.setDir(dir)
		// tg's neck grab floors the body and the hold stands it straight back up (stealth_hold_upright()), both this
		// tick: tg's lying turn would still play there and back. It stands, so it is drawn standing from the first
		// frame. (A whole-animation call, so it goes before anything else.)
		if(!held.lying_angle)
			animate(held, transform = held.transform, time = 0)
	// tg's passive or aggressive grab draws the body toward its holder along one axis. If this tick's neck grab pulled
	// it in from the next tile that way, it is still drawn there: a tile further out than its offsets say.
	var/pulled_in = (!grab[1] != !grab[2]) && hostage_neck_grab_tick == world.time
	if(!pulled_in || held.body_position != STANDING_UP)
		hostage_pose_settle(held, grab, target)
		return
	held.hostage_pose_path = null
	held.update_offsets(FALSE)
	var/from_x = grab[1] - SIGN(grab[1]) * world.icon_size
	var/from_y = grab[2] - SIGN(grab[2]) * world.icon_size
	var/ticks = max(2, round(HOSTAGE_POSE_LAND_TIME / world.tick_lag))
	// a tick longer than the pull, so tg's glide is over on every client before the body shows
	var/obj/effect/abstract/hostage_standin/copy = new(loc, held, (ticks + 1) * world.tick_lag)
	var/list/steps = list()
	// pulled in from the side, it is on the pose's screen row (and so under or over him as in the pose) from the first
	// frame: the client reads a row where a step starts, not along it
	var/side_on = !from_y
	for(var/i in 0 to ticks)
		var/eased = hostage_pose_ease_out(i / ticks)
		steps += list(list(
			i * world.tick_lag,
			from_x + (target[1] - from_x) * eased,
			side_on ? target[2] : from_y + (target[2] - from_y) * eased,
			side_on ? target[3] : grab[3] + (target[3] - grab[3]) * eased,
			null,
			dir,
			null,
		))
	copy.play(steps)
	// his side of it: a reach toward the body, then a tug back as it comes in
	hostage_pose_holder(SIGN(from_x), SIGN(from_y), 2, -1, HOSTAGE_POSE_LAND_TIME)

/// The holder's small move: `reach` pixels along (toward_x, toward_y) in a tick, then `back` pixels along it over
/// `time`, then home.
/mob/living/carbon/human/proc/hostage_pose_holder(toward_x, toward_y, reach, back, time)
	if(!isturf(loc) || body_position != STANDING_UP)
		return
	var/matrix/still = matrix(transform)
	hv_vis_play(HOSTAGE_POSE_HOLDER_ANIM, list(
		list(pixel_w + toward_x * reach, pixel_z + toward_y * reach, still, world.tick_lag, SINE_EASING | EASE_OUT),
		list(pixel_w + toward_x * back, pixel_z + toward_y * back, still, time - world.tick_lag, SINE_EASING | EASE_OUT),
		list(pixel_w, pixel_z, still, world.tick_lag * 2, SINE_EASING),
	))

/// Same facing, new spot (the gun changed hands): a short eased slide across.
/mob/living/carbon/human/proc/hostage_pose_settle(mob/living/held, list/from, list/target)
	var/ticks = max(1, round(HOSTAGE_POSE_SETTLE_TIME / world.tick_lag))
	var/list/keys = list()
	for(var/i in 0 to ticks)
		var/eased = hostage_pose_ease_out(i / ticks)
		keys += list(list(i * world.tick_lag, from[1] + (target[1] - from[1]) * eased, from[2] + (target[2] - from[2]) * eased, from[3] + (target[3] - from[3]) * eased))
	held.hostage_pose_play(keys)

/// A turn: the holder already faces his new way. The body swings round him to his new front (fast start, eased stop),
/// the short way round on a quarter turn; on a half turn across the front of him (side to side), or round his
/// free-hand side (front to back). It faces outward from him each tick, his way on the last.
/mob/living/carbon/human/proc/hostage_pose_swing(mob/living/held, pose, list/from, list/target, old_dir)
	var/half = REVERSE_DIR(old_dir) == dir
	var/ticks = max(1, round((half ? HOSTAGE_POSE_HALF_TIME : HOSTAGE_POSE_QUARTER_TIME) / world.tick_lag))
	var/from_angle = arctan(from[1], from[2])
	var/from_far = sqrt(from[1] ** 2 + from[2] ** 2)
	var/target_far = sqrt(target[1] ** 2 + target[2] ** 2)
	var/sweep = arctan(target[1], target[2]) - from_angle
	if(sweep > 180)
		sweep -= 360
	else if(sweep <= -180)
		sweep += 360
	// side to side goes across the front of him (down the screen), where it stays in view
	if(half && (dir & (EAST|WEST)) && sin(from_angle + sweep / 2) > 0)
		sweep += sweep > 0 ? -360 : 360
	var/list/keys = list()
	var/facing = held.dir
	for(var/i in 0 to ticks)
		var/eased = hostage_pose_ease_out(i / ticks)
		var/angle = from_angle + sweep * eased
		var/far = from_far + (target_far - from_far) * eased
		if(i == ticks)
			keys += list(list(i * world.tick_lag, target[1], target[2], target[3]))
		else
			keys += list(list(i * world.tick_lag, round(cos(angle) * far, 0.01), round(sin(angle) * far, 0.01), from[3] + (target[3] - from[3]) * eased))
		if(!i)
			continue
		while(angle > 180)
			angle -= 360
		while(angle <= -180)
			angle += 360
		var/now_facing = i == ticks ? dir : hostage_pose_facing_at(angle)
		if(now_facing != facing)
			facing = now_facing
			addtimer(CALLBACK(src, PROC_REF(hostage_pose_face), held, pose, facing), i * world.tick_lag, TIMER_DELETE_ME)
	held.hostage_pose_play(keys)

/// Turns the held body to `facing`, unless posed again since. A body on the floor keeps tg's lying side.
/mob/living/carbon/human/proc/hostage_pose_face(mob/living/held, pose, facing)
	if(QDELETED(held) || pose != held.hostage_pose_serial || !held.hostage_pose_dir)
		return
	if(held.body_position == STANDING_UP)
		held.setDir(facing)

/// No longer held at gunpoint. Let go by `freed_by` on his own tile, it stays drawn where it was held; otherwise
/// the pose's offsets come off (tg's eased slide to wherever tg has it now).
/mob/living/proc/hostage_pose_end(mob/living/freed_by)
	// where it is drawn now: its pose, or part way round a swing that was still playing
	var/list/held_at = hostage_pose_now()
	hostage_pose_dir = 0
	hostage_pose_hand = null
	hostage_pose_serial++
	hostage_pose_path = null
	// a body being deleted is let go in its Destroy(): nothing to stand it anywhere (and nothing may hold on to it)
	if(!QDELETED(src) && !QDELETED(freed_by) && loc == freed_by.loc && isturf(loc) && body_position == STANDING_UP)
		// both in this tick, so nothing jumps: tg's grab offsets off, the spot it is drawn at back on under our name
		// (a swing still playing stops there). Then the shove: a few pixels further out from him, tg's own eased slide.
		held_at = list(round(held_at[1], 1), round(held_at[2], 1), round(held_at[3], 1))
		hostage_pose_note(GRABBING_TRAIT)
		hostage_pose_note(HOSTAGE_POSE_FREED, held_at)
		animate(src, tag = HOSTAGE_POSE_ANIM)
		update_offsets(FALSE)
		var/far = max(sqrt(held_at[1] ** 2 + held_at[2] ** 2), 1)
		var/out_x = held_at[1] / far
		var/out_y = held_at[2] / far
		add_offsets(HOSTAGE_POSE_FREED, x_add = round(held_at[1] + out_x * HOSTAGE_POSE_SHOVE, 1), y_add = round(held_at[2] + out_y * HOSTAGE_POSE_SHOVE, 1), animate = TRUE)
		hostage_pose_freed = new(src, freed_by)
		if(ishuman(freed_by))
			var/mob/living/carbon/human/shover = freed_by
			shover.hostage_pose_holder(out_x, out_y, 2, 1, UPDATE_TRANSFORM_ANIMATION_TIME)
		return
	animate(src, tag = HOSTAGE_POSE_ANIM)
	remove_offsets(GRABBING_TRAIT, animate = TRUE)

/// Keeps a let-go body standing where it was held until it or its holder moves, it falls, or it is grabbed again.
/datum/hostage_pose_freed
	var/mob/living/body
	var/mob/living/holder

/datum/hostage_pose_freed/New(mob/living/body, mob/living/holder)
	src.body = body
	src.holder = holder
	RegisterSignals(body, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_SET_BODY_POSITION, COMSIG_QDELETING), PROC_REF(over))
	RegisterSignals(holder, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING), PROC_REF(over))

/datum/hostage_pose_freed/Destroy()
	if(body)
		UnregisterSignal(body, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_SET_BODY_POSITION, COMSIG_QDELETING))
		if(body.hostage_pose_freed == src)
			body.hostage_pose_freed = null
		if(!QDELETED(body))
			// back onto the middle of its tile in two ticks (quicker than any glide it is making, so the two never
			// add up to a step past where it is going)
			var/list/was = body.hostage_pose_real(HOSTAGE_POSE_FREED)
			body.hostage_pose_note(HOSTAGE_POSE_FREED)
			if(isturf(body.loc) && (was[1] || was[2] || was[3]))
				body.hostage_pose_play(list(list(0, was[1], was[2], was[3]), list(world.tick_lag * 2, 0, 0, 0)))
		body = null
	if(holder)
		UnregisterSignal(holder, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
		holder = null
	return ..()

/datum/hostage_pose_freed/proc/over(datum/source)
	SIGNAL_HANDLER
	qdel(src)

// ---------------------------------------------------------------------------------------------
// Drawing the path

/// Notes this body's offsets from `source` as `spot` (list(x, y, z), or null for none) without drawing the change: the
/// path played next draws it, or update_offsets() does.
/mob/living/proc/hostage_pose_note(source, list/spot)
	if(isnull(spot))
		for(var/offset in offsets)
			LAZYREMOVE(offsets[offset], source)
			ASSOC_UNSETEMPTY(offsets, offset)
		UNSETEMPTY(offsets)
		return
	LAZYINITLIST(offsets)
	LAZYSET(offsets[PIXEL_X_OFFSET], source, spot[1])
	LAZYSET(offsets[PIXEL_Y_OFFSET], source, spot[2])
	LAZYSET(offsets[PIXEL_Z_OFFSET], source, spot[3])

/// One of this body's pixel offsets as its noted offsets add up to (what update_offsets() would set).
/mob/living/proc/hostage_pose_sum(pixel, base)
	. = base
	for(var/source in LAZYACCESS(offsets, pixel))
		. += offsets[pixel][source]

/// Draws this body along `keys` (list of list(time, x, y, z): its grab offsets over time, from 0), on top of its other
/// offsets, and ends it on its real offsets as noted (the last key's).
/mob/living/proc/hostage_pose_play(list/keys)
	var/list/last = keys[length(keys)]
	var/rest_x = hostage_pose_sum(PIXEL_X_OFFSET, base_pixel_x) - last[2]
	var/rest_y = hostage_pose_sum(PIXEL_Y_OFFSET, base_pixel_y) - last[3]
	var/rest_z = hostage_pose_sum(PIXEL_Z_OFFSET, base_pixel_z) - last[4]
	// The client draws whoever stands on the lower screen row in front, and reads a body's row where a step of its
	// animation starts. So a step that would carry the body across its holder's row (pixel_y 0) is cut in two there,
	// the cut a pixel onto the new side: the two swap over as it crosses, not a tick late.
	var/list/cut = list(keys[1])
	for(var/i in 2 to length(keys))
		var/list/before = keys[i - 1]
		var/list/key = keys[i]
		var/from_row = rest_y + before[3]
		var/to_row = rest_y + key[3]
		if((from_row > 0 && to_row < -1) || (from_row < 0 && to_row > 1))
			var/part = (SIGN(to_row) - from_row) / (to_row - from_row)
			cut += list(list(before[1] + (key[1] - before[1]) * part, before[2] + (key[2] - before[2]) * part, before[3] + (key[3] - before[3]) * part, before[4] + (key[4] - before[4]) * part))
		cut += list(key)
	keys = cut
	hostage_pose_path = list(world.time, keys)
	var/list/first = keys[1]
	animate(src, pixel_x = rest_x + first[2], pixel_y = rest_y + first[3], pixel_z = rest_z + first[4], time = 0, tag = HOSTAGE_POSE_ANIM)
	for(var/i in 2 to length(keys))
		var/list/key = keys[i]
		var/list/before = keys[i - 1]
		animate(pixel_x = rest_x + key[2], pixel_y = rest_y + key[3], pixel_z = rest_z + key[4], time = key[1] - before[1])

/// The offsets this body is drawn at now as a hostage (or just let go), list(x, y, z): along our path while it plays,
/// else its real ones.
/mob/living/proc/hostage_pose_now()
	var/list/path = hostage_pose_path
	if(length(path))
		var/elapsed = world.time - path[1]
		var/list/keys = path[2]
		var/list/before = keys[1]
		for(var/list/key as anything in keys)
			if(elapsed < key[1])
				var/frac = (elapsed - before[1]) / max(key[1] - before[1], 0.01)
				return list(before[2] + (key[2] - before[2]) * frac, before[3] + (key[3] - before[3]) * frac, before[4] + (key[4] - before[4]) * frac)
			before = key
	return hostage_pose_real(hostage_pose_freed ? HOSTAGE_POSE_FREED : GRABBING_TRAIT)

/// This body's real offsets from `source`, list(x, y, z).
/mob/living/proc/hostage_pose_real(source)
	return list(
		LAZYACCESS(LAZYACCESS(offsets, PIXEL_X_OFFSET), source) || 0,
		LAZYACCESS(LAZYACCESS(offsets, PIXEL_Y_OFFSET), source) || 0,
		LAZYACCESS(LAZYACCESS(offsets, PIXEL_Z_OFFSET), source) || 0,
	)

#undef HOSTAGE_POSE_ANIM
#undef HOSTAGE_POSE_FREED
#undef HOSTAGE_POSE_HOLDER_ANIM
#undef HOSTAGE_POSE_SHOVE
#undef HOSTAGE_POSE_NEAR_S
#undef HOSTAGE_POSE_NEAR_N
#undef HOSTAGE_POSE_SIDE
#undef HOSTAGE_POSE_AHEAD
#undef HOSTAGE_POSE_ROW
#undef HOSTAGE_POSE_ROW_DROP
#undef HOSTAGE_POSE_QUARTER_TIME
#undef HOSTAGE_POSE_HALF_TIME
#undef HOSTAGE_POSE_LAND_TIME
#undef HOSTAGE_POSE_SETTLE_TIME
