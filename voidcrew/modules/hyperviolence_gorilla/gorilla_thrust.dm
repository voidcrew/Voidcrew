/**
 * # The piston punch's arm
 *
 * A piston punch is thrown by its arm: the fist draws back, drives out onto the part it hits with the body lunging
 * behind it, stays there as the blow lands, and comes back to rest, in three tenths of a second (the swing is
 * gorilla_swing.dm's).
 *
 * The punch comes about once a second, so it does not take the whole body's picture each time and stand puppets for
 * all of it, as a finisher does. The punching arm alone is cut from one picture of the bearer, kept until their look
 * changes, and drawn by a puppet over the real body, whose own arm is masked out for as long as the punch lasts. The
 * real body does its own lunging. A bearer who can't be drawn that way lunges as tg has them lunge.
 */

/// The mask on a body whose punching arm is drawn by a puppet.
#define GORILLA_THRUST_FILTER "gorilla_thrust"

/mob/living/carbon/human
	/// The pictures a piston punch's arm is drawn from, by facing: "[dir]" -> /datum/gorilla_arm_look (gorilla_swing.dm)
	var/list/gorilla_arm_looks
	/// The piston punch being drawn on us now
	var/datum/gorilla_thrust/gorilla_thrust

/// One picture of a bearer in one facing, and the arms cut from it. Good until their look changes.
/datum/gorilla_arm_look
	/// What the bearer looked like when it was taken (gorilla_look_key())
	var/key
	/// Holds the picture and does the maths. Never hides anyone and stands no puppets
	var/datum/chrome_rig/rig
	/// Cuts made from the picture so far, by name
	var/list/pictures = list()
	/// Side -> TRUE once that arm's picture has been shown
	var/list/shown = list()

/datum/gorilla_arm_look/Destroy()
	QDEL_NULL(rig)
	pictures = null
	return ..()

/// The picture of the arm on [side].
/datum/gorilla_arm_look/proc/arm_picture(side)
	. = pictures["arm_[side]"]
	if(isnull(.))
		. = (rig.behind_body(side) && far_arm_picture(side)) || rig.arm_picture(side)
		pictures["arm_[side]"] = .

/**
 * The picture of the arm on [side] when it is the far one, hidden behind the body in this facing: that arm as it shows
 * from the bearer's other side, turned round, a pixel further back and in shadow. The rig's own far arm is a copy of
 * the near one, which would bring along whatever the near hand holds; the far hand is the one punching, and empty.
 * Null if the other side can't be pictured.
 */
/datum/gorilla_arm_look/proc/far_arm_picture(side)
	var/mob/living/body = rig.body
	if(QDELETED(body))
		return null
	var/datum/chrome_rig/other_side = new(body, REVERSE_DIR(rig.facing))
	// getFlatIcon() draws a body in its own facing, so it is turned for the picture
	var/real_dir = body.dir
	body.dir = other_side.facing
	var/taken = other_side.snapshot()
	body.dir = real_dir
	var/icon/picture = taken ? other_side.cut("rig_arm_[side]") : null
	qdel(other_side)
	if(isnull(picture))
		return null
	picture.Flip(EAST)
	picture.Shift(rig.facing == EAST ? WEST : EAST, 1)
	picture.Blend(rgb(170, 170, 178), ICON_MULTIPLY)
	return picture

/// The torso under the arm on [side], or null where there is none.
/datum/gorilla_arm_look/proc/fill_picture(side)
	if("fill_[side]" in pictures)
		return pictures["fill_[side]"]
	. = rig.fill_picture(side)
	pictures["fill_[side]"] = .

/// What [bearer] looks like, as text: everything drawn on them and the way they face. Not where or how they stand.
/proc/gorilla_look_key(mob/living/carbon/human/bearer)
	var/list/parts = list("[bearer.dir]", "[bearer.icon]", "[bearer.icon_state]")
	for(var/overlay in bearer.overlays)
		parts += ref(overlay)
	for(var/underlay in bearer.underlays)
		parts += ref(underlay)
	return parts.Join("|")

/// The picture a piston punch's arm is cut from for the way [bearer] faces and looks now, taken if there is none. Null if they can't be drawn.
/proc/gorilla_arm_look(mob/living/carbon/human/bearer)
	var/key = gorilla_look_key(bearer)
	var/datum/gorilla_arm_look/look = bearer.gorilla_arm_looks?["[bearer.dir]"]
	if(look?.key == key && !QDELETED(look.rig))
		return look
	if(look)
		qdel(look)
	LAZYREMOVE(bearer.gorilla_arm_looks, "[bearer.dir]")
	var/datum/chrome_rig/rig = new(bearer, bearer.dir)
	if(!rig.snapshot())
		qdel(rig)
		return null
	look = new
	look.key = key
	look.rig = rig
	LAZYSET(bearer.gorilla_arm_looks, "[bearer.dir]", look)
	return look

/// The mask that cuts the hanging arm on [side] out of a body facing [facing]. Each is made once.
/proc/gorilla_arm_mask(facing, side)
	var/static/list/masks = list()
	var/key = "[facing]-[side]"
	. = masks[key]
	if(isnull(.))
		. = icon(GORILLA_GORE_ICON, "rig_arm_[side]", facing, 1)
		masks[key] = .

/// One piston punch's arm on its bearer: the puppets, and the mask on the real body. Deleting it puts the real arm back.
/datum/gorilla_thrust
	/// Who is punching
	var/mob/living/carbon/human/bearer
	/// The puppets: the arm, and the torso under it where there is any
	var/list/pieces = list()
	/// Takes it down when the arm is back at rest
	var/end_timer

/datum/gorilla_thrust/New(mob/living/carbon/human/bearer)
	src.bearer = bearer
	bearer.gorilla_thrust = src
	RegisterSignal(bearer, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(bearer, COMSIG_ATOM_POST_DIR_CHANGE, PROC_REF(on_turned))
	RegisterSignals(bearer, list(COMSIG_LIVING_SET_BODY_POSITION, COMSIG_QDELETING), PROC_REF(on_lost))

/datum/gorilla_thrust/Destroy()
	if(end_timer)
		deltimer(end_timer)
		end_timer = null
	QDEL_LIST(pieces)
	if(bearer)
		UnregisterSignal(bearer, list(COMSIG_MOVABLE_MOVED, COMSIG_ATOM_POST_DIR_CHANGE, COMSIG_LIVING_SET_BODY_POSITION, COMSIG_QDELETING))
		if(!QDELETED(bearer))
			bearer.remove_filter(GORILLA_THRUST_FILTER)
		if(bearer.gorilla_thrust == src)
			bearer.gorilla_thrust = null
		bearer = null
	return ..()

/// Stands a puppet showing [picture] where the bearer is drawn, on [puppet_layer].
/datum/gorilla_thrust/proc/stand(icon/picture, puppet_layer)
	var/obj/effect/abstract/chrome_puppet/puppet = new(bearer.loc)
	puppet.name = bearer.name
	puppet.icon = picture
	puppet.dir = SOUTH
	puppet.pixel_x = bearer.pixel_x
	puppet.pixel_y = bearer.pixel_y
	puppet.pixel_w = bearer.pixel_w
	puppet.pixel_z = bearer.pixel_z
	puppet.plane = bearer.plane
	puppet.layer = puppet_layer
	// It walks with the bearer (on_moved()), gliding as they glide
	puppet.animate_movement = SLIDE_STEPS
	pieces += puppet
	return puppet

/// The bearer stepped mid-punch: the arm steps with them, at their pace.
/datum/gorilla_thrust/proc/on_moved(atom/movable/source, atom/old_loc)
	SIGNAL_HANDLER
	var/turf/now = source.loc
	if(!isturf(now) || !isturf(old_loc) || get_dist(old_loc, now) > 1)
		qdel(src)
		return
	for(var/obj/effect/abstract/chrome_puppet/puppet as anything in pieces)
		puppet.set_glide_size(source.glide_size)
		puppet.forceMove(now)

/// The bearer turned to face another way: the arm is a picture of the old facing.
/datum/gorilla_thrust/proc/on_turned(datum/source, old_dir, new_dir)
	SIGNAL_HANDLER
	if(old_dir != new_dir)
		qdel(src)

/// Knocked down, or gone.
/datum/gorilla_thrust/proc/on_lost(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/datum/gorilla_thrust/proc/finish()
	end_timer = null
	qdel(src)

/**
 * [bearer] throws a piston punch at [zone] of [target] with the arm on [arm_zone]: the fist draws back and drives out
 * onto the part, the body lunging behind it, and comes back to rest. Only the picture. Returns how long the fist takes
 * to land, for the blow to wait on: the same for every punch. A bearer who can't be drawn that way (lying, turned or
 * resized, something huge worn, a target that isn't straight ahead) lunges as tg has them lunge.
 */
/proc/gorilla_thrust(mob/living/carbon/human/bearer, atom/movable/target, arm_zone, zone)
	if(!gorilla_thrust_arm(bearer, target, arm_zone, zone))
		bearer.do_attack_animation(target)
	return GORILLA_THRUST_LANDS

/// Draws gorilla_thrust()'s arm and lunge. Returns TRUE, or FALSE if it can't be drawn.
/proc/gorilla_thrust_arm(mob/living/carbon/human/bearer, atom/movable/target, arm_zone, zone)
	if(!ishuman(bearer) || !ismovable(target) || QDELETED(target) || !isturf(bearer.loc))
		return FALSE
	if(bearer.body_position == LYING_DOWN || !(bearer.dir in GLOB.cardinals) || bearer.mob_height != HUMAN_HEIGHT_MEDIUM)
		return FALSE
	// The arm is thrown the way the bearer faces. A target a corner away, or on the bearer's own tile, isn't there
	if(get_turf(target) != get_step(bearer.loc, bearer.dir))
		return FALSE
	// Faded (a camo field, a cloak): a puppet would be an arm in plain sight
	if(bearer.alpha < 255 || bearer.invisibility)
		return FALSE
	var/matrix/own = bearer.transform
	if(own && (own.a != 1 || own.b || own.c || own.d || own.e != 1 || own.f))
		return FALSE
	// One punch drawn at a time
	if(bearer.gorilla_thrust)
		qdel(bearer.gorilla_thrust)
	var/list/point = gorilla_fist_target(bearer, target, zone)
	var/datum/gorilla_arm_look/look = point && gorilla_arm_look(bearer)
	var/datum/chrome_rig/rig = look?.rig
	if(isnull(rig))
		return FALSE
	var/facing = rig.facing
	var/side = arm_zone == BODY_ZONE_L_ARM ? "l" : "r"
	// A picture no client has drawn yet may reach one late. The real arm stays on show under its puppet for the beat the
	// fist would have drawn back in, and the fist is driven straight out in what is left: it lands when it always does
	var/hold = look.shown[side] ? 0 : GORILLA_THRUST_HOLD
	look.shown[side] = TRUE

	// The poses: drawn back, then out onto the part
	var/list/way = chrome_swing_way(facing)
	var/list/back
	var/out_angle
	var/tip = GORILLA_THRUST_TIP
	switch(facing)
		if(EAST, WEST)
			back = rig.pose_of(side, -45, -2)
			out_angle = 90
			// Into the punch, as tg's lunge tips them
			tip *= facing == EAST ? 1 : -1
		if(NORTH)
			back = rig.pose_of(side, 60, -3)
			out_angle = 174
			// The punching shoulder goes forward
			tip *= side == "r" ? -1 : 1
		else
			back = rig.pose_of(side, 60, -3)
			out_angle = 12
			tip *= side == "r" ? -1 : 1
	var/list/reach = chrome_swing_reach(rig, side, point[1], point[2], way, GORILLA_THRUST_LUNGE_MIN, (facing & (EAST|WEST)) ? GORILLA_THRUST_LUNGE_MAX : GORILLA_SWING_STEP_UPRIGHT, tip, GORILLA_SWING_EASY_LENGTH, GORILLA_SWING_MAX_LENGTH, out_angle * rig.raise_sign(side))
	var/lunge = reach[1]
	var/list/out = list(reach[2], reach[3])

	// The layers. Seen from the side the near arm is over everything and the far one under its own body. Facing away
	// the thrown arm passes behind its own head; facing the viewer it is drawn back behind its own shoulder
	var/over = bearer.layer + 0.01
	var/under = bearer.layer - 0.01
	var/datum/gorilla_thrust/thrust = new(bearer)
	var/obj/effect/abstract/chrome_puppet/arm
	// The body leans back a pixel as the fist draws back (or waits, the first time). The fist is out a moment before the
	// blow is due and stays there a moment after it
	var/datum/chrome_swing_beat/back_beat = new(hold || GORILLA_THRUST_BACK, CHROME_SWING_LINEAR, -way[1], -way[2])
	var/datum/chrome_swing_beat/out_beat = new(GORILLA_THRUST_BACK + GORILLA_THRUST_OUT - back_beat.time, CHROME_SWING_LINEAR, way[1] * lunge, way[2] * lunge, tip)
	var/datum/chrome_swing_beat/dwell_beat = new(GORILLA_THRUST_DWELL, CHROME_SWING_LINEAR, way[1] * lunge, way[2] * lunge, tip)
	var/datum/chrome_swing_beat/rest_beat = new(GORILLA_THRUST_REST, CHROME_SWING_EASE_IN_OUT)
	if(!hold)
		back_beat.arm(side, back)
	switch(facing)
		if(EAST, WEST)
			arm = thrust.stand(look.arm_picture(side), rig.behind_body(side) ? under : max(bearer.layer, target.layer) + 0.01)
			out_beat.arm(side, out)
			rest_beat.arm(side, list(0, 1))
		if(NORTH)
			arm = thrust.stand(look.arm_picture(side), over)
			out_beat.arm(side, out, under)
			rest_beat.arm(side, list(0, 1))
			rest_beat.layer_once_under = list()
			rest_beat.layer_once_under[side] = list(120, over)
		else
			arm = thrust.stand(look.arm_picture(side), under)
			out_beat.arm(side, out, over)
			rest_beat.arm(side, list(0, 1))
	var/icon/fill_picture = look.fill_picture(side)
	var/obj/effect/abstract/chrome_puppet/fill = fill_picture ? thrust.stand(fill_picture, bearer.layer - 0.005) : null

	var/list/beats = list(back_beat, out_beat, dwell_beat, rest_beat)
	// The real arm goes: at once, or when the hold is over by the client's own clock, in step with the puppet. The
	// mask starts off to one side of the body, where it cuts nothing. Before the lunge, and alongside whatever else is
	// moving the bearer: an animation of a filter is one of its owner's, and a new one would end the rest
	bearer.add_filter(GORILLA_THRUST_FILTER, 1, alpha_mask_filter(x = hold ? ICON_SIZE_X * 2 : 0, icon = gorilla_arm_mask(facing, side), flags = MASK_INVERSE))
	if(hold)
		var/mask = bearer.get_filter(GORILLA_THRUST_FILTER)
		if(mask)
			animate(mask, x = ICON_SIZE_X * 2, time = hold, flags = ANIMATION_PARALLEL)
			animate(x = 0, time = 0)
			// A rebuild of the bearer's filters lands on the cut, not the wait
			bearer.filter_data[GORILLA_THRUST_FILTER]["x"] = 0
	var/list/arms_from = list()
	arms_from[side] = list(0, 1)
	var/list/arms = list()
	arms[side] = arm
	chrome_swing_play(rig, chrome_swing_frames(beats, arms_from), fill ? list(fill) : null, arms, bearer)
	play_fov_effect(target, 5, "attack")
	thrust.end_timer = addtimer(CALLBACK(thrust, TYPE_PROC_REF(/datum/gorilla_thrust, finish)), GORILLA_THRUST_BACK + GORILLA_THRUST_OUT + GORILLA_THRUST_DWELL + GORILLA_THRUST_REST, TIMER_STOPPABLE | TIMER_DELETE_ME)
	return TRUE

#undef GORILLA_THRUST_FILTER
