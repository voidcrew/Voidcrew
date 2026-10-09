/**
 * Serverblight: an admin smite that gets into a body's physics and ruins it, then sets it loose.
 *
 * Nothing here is animated. The body is made physical and hung upright by the neck from nothing,
 * and everything that keeps a ragdoll looking like a body is turned against it: every joint is
 * bent the way it doesn't go, and a motor seizes it back and forth at random every tick. The arms
 * carry on past the hands into long stiff limbs ending in six long fingers, a second pair of arms
 * comes out of the ribs, a hand comes out of the mouth, and the head splits into mirrored copies.
 * All of it collides with itself, and the solver gets too few iterations to ever settle any of
 * it: the shaking is the simulation failing to, every step.
 *
 * Then it hunts (see serverblight_chase.dm): the body slides after the nearest person without
 * walking tile to tile, and anyone it gets every hand on is taken out of their body, which joins
 * the mass.
 *
 * Turning limb physics off (the Limb Physics: Toggle admin verb) ends it and lets go of everyone.
 */
/datum/smite/serverblight
	name = "Serverblight"

/datum/smite/serverblight/effect(client/user, mob/living/target)
	. = ..()
	if(!iscarbon(target))
		to_chat(user, span_warning("This must be used on a carbon mob."), confidential = TRUE)
		return
	if(!vcphys_available())
		to_chat(user, span_warning("The physics library (vcphys) isn't loaded. It goes next to the game, like rust_g."), confidential = TRUE)
		return
	var/mob/living/carbon/victim = target
	if(!victim.set_limb_physics(TRUE))
		to_chat(user, span_warning("[victim] has no sprite-built limb rig to corrupt."), confidential = TRUE)
		return
	var/datum/limb_physics/physics = victim.limb_rig.physics
	if(!physics.blight())
		to_chat(user, span_warning("[victim] is already blighted, or the physics library refused."), confidential = TRUE)
		return
	new /datum/serverblight_chase(physics)
	playsound(victim, 'sound/effects/wounds/crack2.ogg', 100, TRUE)
	to_chat(victim, span_userdanger("Something reaches into you and rewrites where your bones go. Your body gets up without you."))
	victim.visible_message(span_danger("[victim]'s body folds the wrong way, and keeps folding."), ignored_mobs = victim)

/**
 * How far each joint is forced, in degrees relative to where it started: list(lower, upper).
 * Facing east, every band is on the side the joint can't go; mirrored facing west.
 */
/proc/serverblight_joint_band(joint, facing)
	var/static/list/bands = list(
		"neck" = list(100, 170),
		"shoulder" = list(120, 179),
		"elbow" = list(-175, -110),
		"hip" = list(-55, -15),
		"knee" = list(45, 95),
		"ankle" = list(100, 175),
	)
	var/list/band = bands[joint] || list(100, 150)
	if(facing == WEST)
		return list(-band[2], -band[1])
	return band.Copy()

/**
 * Blights the body. It must already be physical. Returns FALSE if it was already, or the library
 * wouldn't have it.
 */
/datum/limb_physics/proc/blight()
	if(blighted || !world_handle)
		return FALSE
	var/list/states = read_states()
	if(!states)
		return FALSE
	blighted = TRUE
	// Too few iterations to ever solve all of it: what's left over each step is the shaking. Enough
	// position iterations, though, that its joints hold together.
	velocity_iterations = 4
	position_iterations = 3
	var/mirror = facing == WEST ? -1 : 1
	var/side_on = facing & (EAST|WEST)

	// Every segment collides with every other: a second, weightless box outside the ragdoll's group.
	for(var/part_id in body_by_part)
		var/list/segment = segments[part_id]
		var/list/origin = segment["origin"]
		var/list/end = segment["end"]
		vcphys_call("fixture_box", world_handle, body_by_part[part_id], segment["width"] / 2 / LIMB_PHYSICS_PPM, segment_length(segment) / 2 / LIMB_PHYSICS_PPM, ((origin[1] + end[1]) / 2 - origin[1]) / LIMB_PHYSICS_PPM, ((origin[2] + end[2]) / 2 - origin[2]) / LIMB_PHYSICS_PPM, 0, 0, 0.7, 0.05, 0)

	// Every joint bent the way it doesn't go, seizing.
	for(var/part_id in joint_by_part)
		var/list/band = serverblight_joint_band(segments[part_id]["joint"], facing)
		var/joint = joint_by_part[part_id]
		vcphys_call("joint_set_limits", world_handle, joint, TORADIANS(band[1]), TORADIANS(band[2]))
		spasms += list(list(joint, 30, 150))
	// Its legs walk it about (see walk_legs()), each in step with the other, the wrong way.
	for(var/side in list("l", "r"))
		make_leg(joint_by_part["[side]_thigh"], joint_by_part["[side]_shin"], side == "l" ? 0 : PI)

	// Hung by the neck from nothing, so it never gets to lie down, lurching on the pin.
	var/list/chest = states["[body_by_part[RIG_CHEST]]"]
	var/list/chest_segment = segments[RIG_CHEST]
	var/list/hips = chest_segment["origin"]
	var/list/neck = chest_segment["end"]
	var/anchor = vcphys_call("body_create", world_handle, LIMB_PHYSICS_STATIC, 0, 0, 0, 0, 0)
	var/list/neck_at = segment_point(chest, hips, neck)
	neck_pin = anchor && vcphys_call("joint_revolute", world_handle, anchor, body_by_part[RIG_CHEST], neck_at[1], neck_at[2], TORADIANS(-18), TORADIANS(18), 0)
	if(neck_pin)
		spasms += list(list(neck_pin, 6, 600))

	// The arms go on past the hands into long stiff limbs, ending in six long fingers.
	for(var/side in list("l", "r"))
		var/sign = (side == "l" ? 1 : -1) * mirror
		var/source = "[side]_forearm"
		var/list/segment = segments[source]
		var/list/at = segment_point(states["[body_by_part[source]]"], segment["origin"], segment["end"])
		var/angle = TORADIANS(110 * sign)
		var/layer = rig.parts[source].layer <= -6 ? -7.5 : -1.6
		var/parent = body_by_part[source]
		for(var/link in 1 to 3)
			parent = grow(rig, source, segment, parent, at[1], at[2], angle, 1.6, 0.9, 20, 60, -25, 25, layer)
			if(!parent)
				return TRUE
			chain_joints += last_growth_joint
			at = growth_end(at, angle, segment, 1.6, 0.9)
		var/list/hand = list()
		for(var/spread in list(-60, -35, -12, 12, 35, 60))
			var/finger = grow(rig, source, segment, parent, at[1], at[2], angle + TORADIANS(spread), 1.25, 0.3, 25, 5, -70, 70, layer)
			if(finger)
				hand += list(list(finger, segment_offset(segment, 1.25, 0.3)))
		hands += list(hand)

	// A second pair of arms out of the ribs.
	for(var/side in list("l", "r"))
		var/list/root = segment_point(chest, hips, list(hips[1], hips[2] + (neck[2] - hips[2]) * (side == "l" ? 0.6 : 0.35)))
		var/angle = TORADIANS((side == "l" ? 75 : -75) * mirror)
		var/layer = rig.parts["[side]_arm"].layer <= -6 ? -7.4 : -1.7
		var/list/arm_segment = segments["[side]_arm"]
		var/arm = grow(rig, "[side]_arm", arm_segment, body_by_part[RIG_CHEST], root[1], root[2], angle, 1.4, 1, 15, 40, -100, 100, layer)
		if(!arm)
			return TRUE
		var/list/elbow = growth_end(root, angle, arm_segment, 1.4, 1)
		var/list/forearm_segment = segments["[side]_forearm"]
		var/hand = grow(rig, "[side]_forearm", forearm_segment, arm, elbow[1], elbow[2], angle, 1.6, 1, 15, 40, -120, 120, layer)
		if(hand)
			hands += list(list(list(hand, segment_offset(forearm_segment, 1.6, 1))))

	// A hand out of the mouth: forward side-on, straight down from the front.
	var/list/head_segment = segments[RIG_HEAD]
	var/list/head_origin = head_segment["origin"]
	var/list/head_end = head_segment["end"]
	var/list/mouth = segment_point(states["[body_by_part[RIG_HEAD]]"], head_origin, list(head_origin[1] + (side_on ? 2 * mirror : 0), head_origin[2] + (head_end[2] - head_origin[2]) * 0.3))
	var/mouth_angle = side_on ? TORADIANS(90 * mirror) : 0
	var/list/mouth_segment = segments["r_forearm"]
	var/mouth_hand = grow(rig, "r_forearm", mouth_segment, body_by_part[RIG_HEAD], mouth[1], mouth[2], mouth_angle, 1.1, 0.9, 20, 20, -40, 40, -1.5)
	if(mouth_hand)
		var/list/fingers_at = growth_end(mouth, mouth_angle, mouth_segment, 1.1, 0.9)
		var/list/hand = list()
		for(var/spread in list(-40, 0, 40))
			var/finger = grow(rig, "r_forearm", mouth_segment, mouth_hand, fingers_at[1], fingers_at[2], mouth_angle + TORADIANS(spread), 0.8, 0.3, 25, 3, -60, 60, -1.5)
			if(finger)
				hand += list(list(finger, segment_offset(mouth_segment, 0.8, 0.3)))
		hands += list(hand)

	// The head splitting into mirrored copies of itself.
	var/head_angle = states["[body_by_part[RIG_HEAD]]"][3]
	for(var/spread in list(-28, 28))
		grow(rig, RIG_HEAD, head_segment, body_by_part[RIG_CHEST], neck_at[1], neck_at[2], head_angle + TORADIANS(spread), 1, -1, 10, 40, spread - 20, spread + 20, -2.6)

	for(var/list/hand as anything in hands)
		for(var/list/finger as anything in hand)
			tips += finger[1]
	add_surroundings()
	rig.sort_pieces()
	ADD_TRAIT(rig.owner, TRAIT_IMMOBILIZED, SERVERBLIGHT_TRAIT)
	ADD_TRAIT(rig.owner, TRAIT_HANDS_BLOCKED, SERVERBLIGHT_TRAIT)
	return TRUE

/**
 * Grows someone's body into this one: their whole rig, standing up out of the torso (leaning a
 * little), stretched, seizing like the rest, their legs walking with its own. Their forearms are
 * two more hands to hold people with. Their rig can be anyone's;
 * nothing's drawn for someone without a sprite-built one. Kept track of, so it comes back if the
 * simulation starts over.
 */
/datum/limb_physics/proc/merge(mob/living/carbon/prey)
	merged |= prey
	var/datum/limb_rig/sprites/prey_rig = prey.limb_rig
	if(!blighted || !istype(prey_rig) || length(merged) > SERVERBLIGHT_MAX_DRAWN_MERGES)
		return FALSE
	var/list/states = last_states || read_states()
	var/list/chest = states?["[body_by_part[RIG_CHEST]]"]
	if(!chest)
		return FALSE
	var/list/chest_segment = segments[RIG_CHEST]
	var/list/hips = chest_segment["origin"]
	var/list/neck = chest_segment["end"]
	var/list/prey_segments = prey_rig.get_physics_segments(facing)

	// Their body, up out of the torso.
	var/list/attach = segment_point(chest, hips, list(hips[1], hips[2] + (neck[2] - hips[2]) * rand(30, 60) / 100))
	var/turn = chest[3] + TORADIANS(rand(-15, 15))
	var/list/made = grow_copy(prey_rig, prey_segments, prey_segments, body_by_part[RIG_CHEST], attach, turn, 1.3)
	var/prey_torso = made[RIG_CHEST]
	if(!prey_torso)
		return FALSE
	var/first_growth = length(growths) - length(made) + 1
	// Their own forearms are hands now, and their legs walk with the rest, out of step.
	var/stride = rand(0, 628) / 100
	for(var/side in list("l", "r"))
		add_hand(made["[side]_forearm"], prey_segments["[side]_forearm"], 1.3, 1)
		make_leg(last_joints["[side]_thigh"], last_joints["[side]_shin"], stride + (side == "l" ? 0 : PI))

	// Glued into everything it's grown into, so it can never get out of it.
	var/list/new_bodies = list()
	for(var/index in first_growth to length(growths))
		new_bodies += growths[index][3]
	glue(new_bodies)
	rig.sort_pieces()
	return TRUE

/**
 * Glues each body to the few others nearest it (within half a metre): pinned together where they
 * are, still colliding with each other, the pin seizing. Every fire, glued pieces lying in each
 * other are shoved apart (see push_apart()), and the glue won't let them go.
 */
/datum/limb_physics/proc/glue(list/bodies)
	var/list/states = read_states()
	if(!states)
		return
	var/list/everything = list()
	for(var/part_id in body_by_part)
		everything += body_by_part[part_id]
	for(var/list/growth as anything in growths)
		everything += growth[3]
	var/list/already = list()
	for(var/list/pair as anything in glued)
		already["[pair[1]]-[pair[2]]"] = TRUE
		already["[pair[2]]-[pair[1]]"] = TRUE
	for(var/body in bodies)
		var/list/here = states["[body]"]
		if(!here)
			continue
		// The nearest few, nearest first.
		var/list/nearest = list()
		for(var/other in everything)
			if(other == body || already["[body]-[other]"])
				continue
			var/list/there = states["[other]"]
			var/distance = there && sqrt((there[1] - here[1]) ** 2 + (there[2] - here[2]) ** 2)
			if(isnull(distance) || distance > 0.5)
				continue
			nearest[other] = distance
		sortTim(nearest, GLOBAL_PROC_REF(cmp_numeric_asc), associative = TRUE)
		for(var/other in nearest.Copy(1, min(length(nearest), SERVERBLIGHT_GLUE_PER_PIECE) + 1))
			var/list/there = states["[other]"]
			var/joint = vcphys_call("joint_revolute", world_handle, body, other, (here[1] + there[1]) / 2, (here[2] + there[2]) / 2, 0, 0, 0, 1)
			if(!joint)
				continue
			vcphys_call("joint_set_motor", world_handle, joint, 30, 250)
			spasms += list(list(joint, 30, 250))
			glued += list(list(body, other))
			already["[body]-[other]"] = TRUE
			already["[other]-[body]"] = TRUE

/**
 * Pushback, as physics engines do for props stuck inside each other: every glued pair lying less
 * than SERVERBLIGHT_PUSHBACK_REACH apart is pushed apart, faster the deeper in they are, up to
 * SERVERBLIGHT_PUSHBACK metres a second. The glue holds, so they never get anywhere: they shake. A
 * change in speed rather than a shove, so it's the same for a fingertip as for a torso (a shove that
 * would nudge a torso sends a fingertip flying, and the body comes apart). And a governor: nothing
 * goes faster than SERVERBLIGHT_TOP_SPEED or spins faster than SERVERBLIGHT_TOP_SPIN.
 */
/datum/limb_physics/proc/push_apart()
	var/list/pushes = list()
	for(var/list/pair as anything in glued)
		var/list/first = last_states["[pair[1]]"]
		var/list/second = last_states["[pair[2]]"]
		if(!first || !second)
			continue
		var/dx = second[1] - first[1]
		var/dy = second[2] - first[2]
		var/distance = sqrt(dx ** 2 + dy ** 2)
		if(distance >= SERVERBLIGHT_PUSHBACK_REACH)
			continue
		if(distance < 0.001)
			var/direction = rand(0, 359)
			dx = cos(direction)
			dy = sin(direction)
			distance = 1
		var/push = SERVERBLIGHT_PUSHBACK * (SERVERBLIGHT_PUSHBACK_REACH - distance) / SERVERBLIGHT_PUSHBACK_REACH
		for(var/index in 1 to 2)
			var/key = "[pair[index]]"
			var/sign = index == 2 ? 1 : -1
			var/list/change = pushes[key] || list(0, 0)
			change[1] += sign * push * dx / distance
			change[2] += sign * push * dy / distance
			pushes[key] = change
	for(var/handle in last_states)
		var/list/state = last_states[handle]
		var/list/change = pushes[handle]
		var/velocity_x = state[4] + (change ? change[1] : 0)
		var/velocity_y = state[5] + (change ? change[2] : 0)
		var/speed = sqrt(velocity_x ** 2 + velocity_y ** 2)
		if(!change && speed <= SERVERBLIGHT_TOP_SPEED && abs(state[6]) <= SERVERBLIGHT_TOP_SPIN)
			continue
		var/scale = speed > SERVERBLIGHT_TOP_SPEED ? SERVERBLIGHT_TOP_SPEED / speed : 1
		vcphys_call("body_set_velocity", world_handle, handle, velocity_x * scale, velocity_y * scale, clamp(state[6], -SERVERBLIGHT_TOP_SPIN, SERVERBLIGHT_TOP_SPIN))

/**
 * Grows copies of some of a rig's segments, jointed to each other as the rig has them, and the
 * first to parent: laid out as the rig stands, turned by turn, with the first one's origin at
 * attach, and every limb stretched (the torso and head aren't). Returns the new bodies by piece
 * id; the joints go in last_joints.
 */
/datum/limb_physics/proc/grow_copy(datum/limb_rig/sprites/from, list/from_segments, list/part_ids, parent, list/attach, turn, stretch = 1)
	. = list()
	last_joints = list()
	var/list/placed = list()
	for(var/part_id in part_ids)
		var/list/segment = from_segments[part_id]
		var/parent_id = segment["parent"]
		var/joint_to = .[parent_id] || parent
		var/list/at = attach
		if(placed[parent_id])
			// Where its joint is on its (stretched) parent.
			var/list/parent_segment = from_segments[parent_id]
			var/parent_stretch = (parent_id == RIG_CHEST || parent_id == RIG_HEAD) ? 1 : stretch
			var/list/parent_origin = parent_segment["origin"]
			var/list/origin = segment["origin"]
			at = growth_end(placed[parent_id], turn, list("origin" = parent_origin, "end" = origin), parent_stretch, 1)
		var/length_scale = (part_id == RIG_CHEST || part_id == RIG_HEAD) ? 1 : stretch
		// The torso stands nearly upright in the host's; everything else bends the wrong way.
		var/list/band = part_id == RIG_CHEST ? list(-15, 15) : serverblight_joint_band(segment["joint"], facing)
		var/layer = -2.55 + from.parts[part_id].layer / 100
		// In the ragdoll's own group, so the bodies taken in don't collide with each other or the
		// body's own frame: with every one of them colliding with every other, the cost of a step
		// runs away and it comes apart.
		var/body = grow(from, part_id, segment, joint_to, at[1], at[2], turn, length_scale, 1, part_id == RIG_CHEST ? 8 : 30, part_id == RIG_CHEST ? 300 : 100, band[1], band[2], layer, layer + 0.0005, LIMB_PHYSICS_RAGDOLL_GROUP)
		if(!body)
			return
		.[part_id] = body
		placed[part_id] = at
		last_joints[part_id] = last_growth_joint

/**
 * Makes a leg walk, rather than seize, while the body's moving: its hip and knee driven round a
 * stride, starting stride radians into it.
 */
/datum/limb_physics/proc/make_leg(hip, knee, stride)
	for(var/list/spasm as anything in spasms.Copy())
		if(spasm[1] == hip || spasm[1] == knee)
			spasms -= list(spasm)
	if(hip)
		legs += list(list(hip, stride))
	if(knee)
		legs += list(list(knee, stride + PI / 2))

/**
 * Drives every leg round its stride as fast as the body's going (walk_speed, tiles a second), a
 * couple of strides a tile, no faster than it can be seen. Standing still, the legs seize with the
 * rest.
 */
/datum/limb_physics/proc/walk_legs()
	var/moving = walk_speed > 0.5
	if(moving)
		walk_phase += min(walk_speed * 0.6, 1.2)
	for(var/list/leg as anything in legs)
		if(moving)
			vcphys_call("joint_set_motor", world_handle, leg[1], 14 * cos(TODEGREES(walk_phase + leg[2])) + rand(-30, 30) / 10, 150)
		else if(prob(60))
			vcphys_call("joint_set_motor", world_handle, leg[1], 30 * pick(-1, 1) * rand(50, 150) / 100, 150)

/**
 * Dead: everything goes slack. Every motor stops, the neck comes off its pin, and the whole mass
 * falls in a heap, still glued together. It's all put back by starting over (rebuild()).
 */
/datum/limb_physics/proc/go_dormant()
	if(dormant)
		return
	dormant = TRUE
	set_prey(null, null)
	for(var/list/spasm as anything in spasms)
		vcphys_call("joint_set_motor", world_handle, spasm[1], 0, 0)
	for(var/list/leg as anything in legs)
		vcphys_call("joint_set_motor", world_handle, leg[1], 0, 0)
	if(neck_pin)
		vcphys_call("joint_destroy", world_handle, neck_pin)
		neck_pin = null

/// Makes a body a hand with one finger: its far end, of a segment stretched this much.
/datum/limb_physics/proc/add_hand(body, list/segment, length_scale, width_scale)
	if(!body)
		return
	hands += list(list(list(body, segment_offset(segment, length_scale, width_scale))))
	tips += body

/// A segment's length in pixels, as build() gives its box.
/datum/limb_physics/proc/segment_length(list/segment)
	var/list/origin = segment["origin"]
	var/list/end = segment["end"]
	return max(sqrt((end[1] - origin[1]) ** 2 + (end[2] - origin[2]) ** 2), 2)

/// Where a point on a segment's sprite is in the world, in metres, with the segment's body in
/// state (list(x, y, angle, ...)) and its sprite hanging off origin.
/datum/limb_physics/proc/segment_point(list/state, list/origin, list/point)
	var/dx = (point[1] - origin[1]) / LIMB_PHYSICS_PPM
	var/dy = (point[2] - origin[2]) / LIMB_PHYSICS_PPM
	var/turn = TODEGREES(state[3])
	return list(state[1] + dx * cos(turn) - dy * sin(turn), state[2] + dx * sin(turn) + dy * cos(turn))

/// From a segment's origin to its end, stretched, in metres, before it's turned.
/datum/limb_physics/proc/segment_offset(list/segment, length_scale, width_scale)
	var/list/origin = segment["origin"]
	var/list/end = segment["end"]
	return list((end[1] - origin[1]) * width_scale / LIMB_PHYSICS_PPM, (end[2] - origin[2]) * length_scale / LIMB_PHYSICS_PPM)

/// Where the far end of a growth is, grown at (x, y) turned angle.
/datum/limb_physics/proc/growth_end(list/at, angle, list/segment, length_scale, width_scale)
	var/list/offset = segment_offset(segment, length_scale, width_scale)
	var/turn = TODEGREES(angle)
	return list(at[1] + offset[1] * cos(turn) - offset[2] * sin(turn), at[2] + offset[1] * sin(turn) + offset[2] * cos(turn))

/**
 * Grows a copy of one of a rig's segments off a body, pinned at (x, y), its sprite turned angle
 * and stretched, and drawn as that rig draws it (clothes too). Its joint turns between lower and
 * upper degrees (freely if they're equal), seizing at up to motor_speed with motor_torque. It
 * never sleeps, so it never stops. It collides with everything, unless it's given a group (see
 * Box2D's group_index). Returns the new body's handle.
 */
/datum/limb_physics/proc/grow(datum/limb_rig/sprites/from, part_id, list/segment, parent, x, y, angle, length_scale, width_scale, motor_speed, motor_torque, lower, upper, layer, cloth_layer, group = 0)
	var/list/origin = segment["origin"]
	var/list/end = segment["end"]
	var/body = vcphys_call("body_create", world_handle, LIMB_PHYSICS_DYNAMIC, x, y, angle, 0.05, 0.2, 0)
	if(!body)
		return null
	// The box as build() makes it, stretched with the sprite.
	var/length = segment_length(segment) * length_scale / LIMB_PHYSICS_PPM
	vcphys_call("fixture_box", world_handle, body, segment["width"] * abs(width_scale) / 2 / LIMB_PHYSICS_PPM, length / 2, ((origin[1] + end[1]) / 2 - origin[1]) * width_scale / LIMB_PHYSICS_PPM, ((origin[2] + end[2]) / 2 - origin[2]) * length_scale / LIMB_PHYSICS_PPM, 0, 12, 0.7, 0.05, group)
	last_growth_joint = vcphys_call("joint_revolute", world_handle, parent, body, x, y, TORADIANS(lower), TORADIANS(upper), 0)
	if(last_growth_joint)
		vcphys_call("joint_set_motor", world_handle, last_growth_joint, motor_speed, motor_torque)
		spasms += list(list(last_growth_joint, motor_speed, motor_torque))

	// Hung on the mob, like the legs are.
	var/obj/effect/abstract/limb_rig_part/skin = rig.new_part(part_id)
	skin.appearance = from.parts[part_id].appearance
	skin.layer = layer
	rig.owner.vis_contents += skin
	var/obj/effect/abstract/limb_rig_part/cloth
	var/matrix/cloth_map
	if(from.cloth_parts[part_id])
		cloth = rig.new_part(part_id)
		cloth.appearance = from.cloth_parts[part_id].appearance
		cloth.layer = isnull(cloth_layer) ? layer + 0.05 : cloth_layer
		rig.owner.vis_contents += cloth
		cloth_map = from.get_cloth_map(part_id, facing)
	growths += list(list(skin, cloth, body, origin, length_scale, width_scale, cloth_map))
	return body

/// Puts every growth where the simulation has it, as draw() does the body.
/datum/limb_physics/proc/draw_growths(list/states, time)
	for(var/list/growth as anything in growths)
		var/list/state = states["[growth[3]]"]
		if(!state)
			continue
		var/list/origin = growth[4]
		var/matrix/segment = rig_joint_matrix(origin[1], origin[2], growth[5], -TODEGREES(state[3]), state[1] * LIMB_PHYSICS_PPM + 16.5, state[2] * LIMB_PHYSICS_PPM, growth[6])
		animate(growth[1], transform = segment, time = time)
		if(growth[2])
			animate(growth[2], transform = growth[7] * segment, time = time)

/// Every joint that's seizing lurches one way or the other, every few ticks (its motor keeps going the
/// way it last lurched in between).
/datum/limb_physics/proc/seize()
	for(var/list/spasm as anything in spasms)
		if(prob(30))
			vcphys_call("joint_set_motor", world_handle, spasm[1], spasm[2] * pick(-1, 1) * rand(50, 150) / 100, spasm[3])

/**
 * Pulls every fingertip: outward, stretching the hands as far as they go, or with someone in
 * reach (see set_prey()), at them.
 */
/datum/limb_physics/proc/pull_tips()
	var/list/chest = last_states?["[body_by_part[RIG_CHEST]]"]
	if(!chest)
		return
	for(var/tip in tips)
		var/list/state = last_states["[tip]"]
		if(!state)
			continue
		if(!isnull(prey_x))
			var/dx = prey_x - state[1]
			var/dy = prey_y + SERVERBLIGHT_PREY_HALF_HEIGHT - state[2]
			var/distance = max(sqrt(dx ** 2 + dy ** 2), 0.01)
			vcphys_call("body_force", world_handle, tip, 140 * dx / distance, 140 * dy / distance)
			continue
		var/dx = state[1] - chest[1]
		var/dy = state[2] - chest[2]
		var/distance = max(sqrt(dx ** 2 + dy ** 2), 0.01)
		vcphys_call("body_force", world_handle, tip, 60 * dx / distance, 60 * dy / distance + 15)

/**
 * Tells the hands someone's in reach: their feet at (x, y) metres in the body's frame, or null
 * when nobody is. The long arms go slack enough to wrap round them while someone is.
 */
/datum/limb_physics/proc/set_prey(x, y)
	var/was_grabbing = !isnull(prey_x)
	prey_x = x
	prey_y = y
	var/grabbing = !isnull(x)
	if(!grabbing)
		latched.Cut()
	if(grabbing == was_grabbing)
		return
	var/limit = TORADIANS(grabbing ? 80 : 25)
	for(var/joint in chain_joints)
		vcphys_call("joint_set_limits", world_handle, joint, -limit, limit)

/**
 * How many hands are holding whoever's in reach. A hand takes hold with a fingertip within 0.3
 * metres of them, and keeps it until it's dragged more than 0.6 metres off.
 */
/datum/limb_physics/proc/count_gripping_hands()
	if(isnull(prey_x) || !last_states)
		return 0
	. = 0
	for(var/hand_index in 1 to length(hands))
		var/list/hand = hands[hand_index]
		var/closest = INFINITY
		for(var/list/finger as anything in hand)
			var/list/state = last_states["[finger[1]]"]
			if(!state)
				continue
			var/list/offset = finger[2]
			var/turn = TODEGREES(state[3])
			var/tip_x = state[1] + offset[1] * cos(turn) - offset[2] * sin(turn)
			var/tip_y = state[2] + offset[1] * sin(turn) + offset[2] * cos(turn)
			// How far outside their box the tip is (0 inside it).
			closest = min(closest, max(abs(tip_x - prey_x) - SERVERBLIGHT_PREY_HALF_WIDTH, abs(tip_y - prey_y - SERVERBLIGHT_PREY_HALF_HEIGHT) - SERVERBLIGHT_PREY_HALF_HEIGHT, 0))
		var/holding = closest <= (latched["[hand_index]"] ? 0.6 : 0.3)
		latched["[hand_index]"] = holding
		if(holding)
			.++

/// Walls and dense furniture on the tiles around the victim, as they're drawn around it: the body
/// is simulated on its own tile, a tile being 32 pixels. Replaces the last lot, as it moves.
/datum/limb_physics/proc/add_surroundings()
	for(var/handle in surroundings)
		vcphys_call("body_destroy", world_handle, handle)
	surroundings.Cut()
	var/turf/centre = get_turf(rig.owner)
	if(!centre)
		return
	var/tile = SERVERBLIGHT_TILE_METRES
	for(var/dx in -1 to 1)
		for(var/dy in -1 to 1)
			if(!dx && !dy)
				continue
			var/turf/spot = locate(centre.x + dx, centre.y + dy, centre.z)
			if(!spot)
				continue
			var/half
			if(spot.density)
				half = tile / 2
			else
				for(var/obj/thing in spot)
					if(thing.density)
						half = tile * 0.35
						break
			if(!half)
				continue
			var/handle = vcphys_call("body_create", world_handle, LIMB_PHYSICS_STATIC, dx * tile, (dy + 0.5) * tile, 0, 0, 0)
			if(handle && vcphys_call("fixture_box", world_handle, handle, half, half, 0, 0, 0, 0, 0.8, 0, 0))
				surroundings += handle

/// Whether any piece has come away from the torso further than it ever should (see SERVERBLIGHT_TORN_REACH).
/datum/limb_physics/proc/is_torn(list/states)
	var/list/chest = states["[body_by_part[RIG_CHEST]]"]
	if(!chest)
		return FALSE
	// (The walls and floor it's simulated in are all well inside that.)
	for(var/handle in states)
		var/list/state = states[handle]
		if((state[1] - chest[1]) ** 2 + (state[2] - chest[2]) ** 2 > SERVERBLIGHT_TORN_REACH ** 2)
			return TRUE
	return FALSE

/// Takes away everything Serverblight grew.
/datum/limb_physics/proc/clear_growths()
	for(var/list/growth as anything in growths)
		for(var/obj/effect/abstract/limb_rig_part/piece in growth.Copy(1, 3))
			rig?.owner?.vis_contents -= piece
			qdel(piece)
	growths.Cut()
	tips.Cut()
	spasms.Cut()
	hands.Cut()
	chain_joints.Cut()
	legs.Cut()
	glued.Cut()
	surroundings.Cut()
	latched.Cut()
	prey_x = null
	prey_y = null
