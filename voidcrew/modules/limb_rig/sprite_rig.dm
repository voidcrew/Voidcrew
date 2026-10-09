/**
 * A rig for a body drawn piece by piece.
 *
 * The human rig cuts one flat sprite into pieces with masks. A species can instead hand the rig a
 * sprite for every piece (limb_rig_shape["sprites"]) and the skeleton they hang off. Each piece then
 * shows exactly its own bit of body, so nothing is left stuck to the torso when a leg swings, and
 * the body can be any size or shape: bigger than a tile, with digitigrade legs in three segments.
 *
 * Worn clothes are still drawn for a human. They're cut with human-shaped masks (the "cloth_masks"
 * icon) onto cloth pieces, and each cloth piece is stretched from the human bone onto this body's
 * bone: a human thigh's worth of trousers onto this thigh, a hat onto the head. Shoes get pieces of
 * their own, taking the whole shoe onto the paw, so no boot top ends up halfway up the leg.
 *
 * Piece sprites are 64x64, drawn 16 pixels left, so they can reach past the tile on every side.
 * Skeleton points are in pixels from the bottom left of the tile.
 *
 * Poses work as usual, and can also give whole angles: "thigh", "shin" and "foot" on a leg, and
 * "upper" and "lower" on an arm, each forward from straight down.
 */

/// Human bone heights the clothes are drawn around (see icons/rig_masks.dmi and the cloth masks).
#define HUMAN_HIPS_Y 11
#define HUMAN_ELBOW_Y 16.5
#define HUMAN_HAND_Y 12.5
#define HUMAN_KNEE_Y 4.5
#define HUMAN_ANKLE_Y 2.5
#define HUMAN_CROWN_Y 29

/datum/limb_rig/sprites
	/// One state per piece, 64x64.
	var/sprite_icon
	/// Rest joints by dir2text(): "l_arm" = list(shoulder, elbow, wrist), "l_leg" = list(hip, knee, hock, sole),
	/// "head" = neck, "crown" = top of the head, "chest" = hips, "tail" = root. Limbs hang straight down in the sprites.
	var/list/skeleton
	/// How the legs bend at rest: list(thigh forward, knee back, ankle forward), in degrees.
	var/list/leg_rest
	/// Human-shaped masks cutting worn clothes into the pieces they get stretched onto.
	var/cloth_masks
	/// How much bigger hats and the like are drawn, to fit the head. They sit on its crown.
	var/hat_scale = 1
	/// How much of the bottom of the foot shoes cover, in pixels.
	var/paw_height = 4
	/// How much bigger held items are drawn, to fit the hand.
	var/item_scale = 1
	/// How much wider (or narrower) clothes are drawn on the torso.
	var/torso_width = 1
	/// How much wider clothes are drawn on each kind of limb segment ("arm", "forearm", "thigh", "shin"),
	/// so sleeves and trouser legs fit round this body's limbs rather than a human's.
	var/list/cloth_widths
	/// Pieces showing worn clothing, by piece id.
	var/list/obj/effect/abstract/limb_rig_part/cloth_parts = list()
	/// Pieces showing each foot's shoe, "l" and "r".
	var/list/obj/effect/abstract/limb_rig_part/shoe_parts = list()
	/// Per-piece brute and burn marks ("<piece>_brute_<1-3>", "<piece>_burn_<1-3>"), or null to leave damage alone.
	var/damage_icon
	/// The marks currently on each piece, by piece id.
	var/list/damage_marks = list()
	/// The body sprite on each piece, by piece id.
	var/list/sprite_images = list()
	/// A piece over the head for anything drawn on the face (a rhythm battle's faces), moving with the
	/// head but not coloured with it: nothing that tints the head's piece reaches it.
	var/obj/effect/abstract/limb_rig_part/face_part
	/// How much colour the body sprites keep, 0 to 1 (see set_sprite_saturation()).
	var/sprite_saturation = 1

/datum/limb_rig/sprites/refresh_shape()
	. = ..()
	var/mob/living/carbon/human/human_owner = owner
	var/list/shape = human_owner.dna.species.limb_rig_shape
	sprite_icon = shape["sprites"]
	skeleton = shape["skeleton"]
	leg_rest = shape["leg_rest"]
	cloth_masks = shape["cloth_masks"]
	hat_scale = shape["hat_scale"] || 1
	item_scale = shape["item_scale"] || 1
	paw_height = shape["paw_height"] || 4
	torso_width = shape["torso_width"] || 1
	cloth_widths = shape["cloth_widths"]
	damage_icon = shape["damage"]

/datum/limb_rig/sprites/build_pieces()
	pivot = new_part(RIG_CHEST)
	hang_on_owner(pivot)
	for(var/part_id in list(RIG_CHEST, RIG_HEAD, "l_arm", "l_forearm", "r_arm", "r_forearm"))
		add_piece(part_id, pivot)
	face_part = new_part(RIG_HEAD)
	pivot.vis_contents += face_part
	// The pivot draws as one flat group over the legs, so the tail hangs off the mob instead:
	// it has to go under the legs, or over everything seen from behind.
	add_piece(RIG_TAIL, null)
	for(var/side in list("l", "r"))
		item_parts[side] = new_part(side == "l" ? RIG_L_ARM : RIG_R_ARM)
		pivot.vis_contents += item_parts[side]
		for(var/segment in list("thigh", "shin", "foot"))
			add_piece("[side]_[segment]", null)
		shoe_parts[side] = new_part("[side]_foot")
		hang_on_owner(shoe_parts[side])

/// Makes a body piece showing its sprite, and a cloth piece to go with it (the tail wears nothing).
/datum/limb_rig/sprites/proc/add_piece(part_id, obj/effect/abstract/limb_rig_part/container)
	var/obj/effect/abstract/limb_rig_part/part = new_part(part_id)
	parts[part_id] = part
	refresh_sprite_image(part_id)
	var/obj/effect/abstract/limb_rig_part/cloth
	if(part_id != RIG_TAIL)
		cloth = new_part(part_id)
		cloth_parts[part_id] = cloth
	if(container)
		container.vis_contents += part
		if(cloth)
			container.vis_contents += cloth
	else
		hang_on_owner(part)
		if(cloth)
			hang_on_owner(cloth)

/// Puts a piece's body sprite on, as drained of colour as the body is.
/datum/limb_rig/sprites/proc/refresh_sprite_image(part_id)
	var/obj/effect/abstract/limb_rig_part/part = parts[part_id]
	part.cut_overlay(sprite_images[part_id])
	var/image/sprite = image(sprite_icon, part_id)
	sprite.pixel_w = -16
	if(sprite_saturation < 1)
		sprite.color = color_matrix_saturation(sprite_saturation)
	part.add_overlay(sprite)
	sprite_images[part_id] = sprite

/datum/limb_rig/sprites/set_sprite_saturation(value)
	if(sprite_saturation == value)
		return
	sprite_saturation = value
	for(var/part_id in sprite_images)
		refresh_sprite_image(part_id)

/datum/limb_rig/sprites/Destroy()
	QDEL_LIST_ASSOC_VAL(cloth_parts)
	QDEL_LIST_ASSOC_VAL(shoe_parts)
	QDEL_NULL(face_part)
	sprite_images = null
	return ..()

/datum/limb_rig/sprites/set_layer(cache_index, standing)
	if(cache_index == HANDS_LAYER)
		refresh_held_items()
		return
	if(cache_index == BODYPARTS_LAYER)
		// The body is the pieces' own sprites. The bodyparts only say which limbs are there.
		refresh_limbs()
		return
	if(cache_index == DAMAGE_LAYER && damage_icon)
		return // Drawn on the pieces themselves, by refresh_damage_marks().
	// Shoes go on the shoe pieces, everything else on the cloth pieces.
	var/list/targets = cache_index == SHOES_LAYER ? shoe_parts : cloth_parts
	var/key = "[cache_index]"
	var/old = mirrored_layers[key]
	if(old)
		for(var/part_id in targets)
			var/obj/effect/abstract/limb_rig_part/cloth = targets[part_id]
			cloth.cut_overlay(old)
		mirrored_layers -= key
	if(!standing)
		return
	for(var/part_id in targets)
		var/obj/effect/abstract/limb_rig_part/cloth = targets[part_id]
		cloth.add_overlay(standing)
	mirrored_layers[key] = standing

/// Which bodypart each piece belongs to.
/proc/get_rig_piece_zones()
	var/static/list/zones = list(
		RIG_HEAD = BODY_ZONE_HEAD,
		RIG_CHEST = BODY_ZONE_CHEST,
		"l_arm" = BODY_ZONE_L_ARM, "l_forearm" = BODY_ZONE_L_ARM,
		"r_arm" = BODY_ZONE_R_ARM, "r_forearm" = BODY_ZONE_R_ARM,
		"l_thigh" = BODY_ZONE_L_LEG, "l_shin" = BODY_ZONE_L_LEG, "l_foot" = BODY_ZONE_L_LEG,
		"r_thigh" = BODY_ZONE_R_LEG, "r_shin" = BODY_ZONE_R_LEG, "r_foot" = BODY_ZONE_R_LEG,
	)
	return zones

/// Hides the pieces of any limb that's gone.
/datum/limb_rig/sprites/proc/refresh_limbs()
	var/list/zones = get_rig_piece_zones()
	for(var/part_id in zones)
		var/obj/effect/abstract/limb_rig_part/part = parts[part_id]
		part.alpha = owner.get_bodypart(zones[part_id]) ? 255 : 0

/datum/limb_rig/sprites/refresh_damage_marks()
	if(!damage_icon)
		return
	var/blood_color = owner.get_bloodtype()?.get_damage_color(owner)
	var/list/zones = get_rig_piece_zones()
	for(var/part_id in zones)
		var/obj/effect/abstract/limb_rig_part/part = parts[part_id]
		part.cut_overlay(damage_marks[part_id])
		var/obj/item/bodypart/limb = owner.get_bodypart(zones[part_id])
		var/list/marks = list()
		if(limb?.brutestate)
			var/image/brute = image(damage_icon, "[part_id]_brute_[limb.brutestate]")
			brute.pixel_w = -16
			brute.color = blood_color
			marks += brute
		if(limb?.burnstate)
			var/image/burn = image(damage_icon, "[part_id]_burn_[limb.burnstate]")
			burn.pixel_w = -16
			marks += burn
		part.add_overlay(marks)
		damage_marks[part_id] = marks

/datum/limb_rig/sprites/refresh_facing()
	var/facing = get_facing()
	for(var/part_id in cloth_parts)
		var/obj/effect/abstract/limb_rig_part/cloth = cloth_parts[part_id]
		var/mask_state = part_id
		var/flags = NONE
		if(part_id == RIG_HEAD)
			mask_state = "head_cut"
			flags = MASK_INVERSE
		else if(part_id == RIG_CHEST)
			mask_state = "torso_cut"
			flags = MASK_INVERSE
		cloth.add_filter("limb_rig_mask", 1, alpha_mask_filter(icon = get_rig_mask(mask_state, facing, cloth_masks), flags = flags))
	for(var/side in shoe_parts)
		shoe_parts[side].add_filter("limb_rig_mask", 1, alpha_mask_filter(icon = get_rig_mask("[side]_shoe", facing, cloth_masks)))

	// Side-on, the far limbs go behind the body. From behind, the arms do too, and the tail,
	// pointing at the viewer, goes over everything; otherwise it's under everything, legs included.
	// (Everything on the pivot draws together, at the pivot's layer.)
	var/far_side = facing == EAST ? "l" : (facing == WEST ? "r" : null)
	pivot.layer = -2
	parts[RIG_CHEST].layer = -5
	parts[RIG_HEAD].layer = -4
	parts[RIG_TAIL].layer = facing == NORTH ? -1 : -9
	for(var/side in list("l", "r"))
		for(var/segment in list("thigh", "shin", "foot"))
			parts["[side]_[segment]"].layer = side == far_side ? -6 : -3
		var/behind = (side == far_side || facing == NORTH)
		parts["[side]_arm"].layer = behind ? -7 : -3
		parts["[side]_forearm"].layer = parts["[side]_arm"].layer + 0.2
		item_parts[side].layer = behind ? -6.5 : -2
	for(var/part_id in cloth_parts)
		cloth_parts[part_id].layer = parts[part_id].layer + 0.1
	for(var/side in shoe_parts)
		shoe_parts[side].layer = parts["[side]_foot"].layer + 0.2
	face_part.layer = parts[RIG_HEAD].layer + 0.15
	sort_pieces()

/**
 * Poses a limb hanging straight down from points[1] through the rest of points.
 *
 * * angles - how far each segment swings forward from straight down, in degrees
 * * raise - how far the whole limb swings out to the side
 * * right - whether it's on the mob's right, which decides which way raising turns it from the front
 *
 * Returns list(a matrix per segment..., end x, end y, the last segment's turn).
 */
/proc/rig_chain(list/points, list/angles, facing, raise, right)
	. = list()
	var/front = (facing == NORTH || facing == SOUTH)
	var/side_turn = front ? ((right == (facing == SOUTH)) ? raise : -raise) : 0
	var/list/start = points[1]
	var/posed_x = start[1]
	var/posed_y = start[2]
	var/turn = 0
	for(var/i in 1 to length(points) - 1)
		var/list/top = points[i]
		var/list/bottom = points[i + 1]
		var/length = top[2] - bottom[2]
		var/angle = angles[i]
		if(front)
			// Swinging toward or away from the viewer just shortens the segment.
			var/foreshorten = cos(angle)
			turn = side_turn
			. += rig_joint_matrix(top[1], top[2], foreshorten, turn, posed_x, posed_y)
			posed_x -= length * foreshorten * sin(turn)
			posed_y -= length * foreshorten * cos(turn)
		else
			turn = facing == EAST ? -angle : angle
			. += rig_joint_matrix(top[1], top[2], 1, turn, posed_x, posed_y, cos(raise))
			posed_x += length * sin(angle) * (facing == EAST ? 1 : -1)
			posed_y -= length * cos(angle)
	. += posed_x
	. += posed_y
	. += turn

/// The piece the face is drawn to fit, whose every move face_part copies.
/datum/limb_rig/sprites/proc/get_face_anchor()
	return parts[RIG_HEAD]

/// Puts face_part wherever its anchor is in a set of matrices.
/datum/limb_rig/sprites/proc/add_face_matrix(list/matrices)
	var/matrix/anchor = matrices[get_face_anchor()]
	if(anchor && face_part)
		matrices[face_part] = anchor

/// Maps a human-shaped piece of clothing onto this body's piece at rest.
/datum/limb_rig/sprites/proc/get_cloth_map(part_id, facing)
	var/list/bones = skeleton[dir2text(facing)]
	switch(part_id)
		if(RIG_HEAD)
			var/list/crown = bones["crown"]
			return rig_joint_matrix(16, HUMAN_CROWN_Y, hat_scale, 0, crown[1], crown[2], hat_scale)
		if(RIG_CHEST)
			var/list/hips = bones[RIG_CHEST]
			var/list/shoulders = bones["l_arm"][1]
			var/list/human_shoulders = get_rig_joint(RIG_L_ARM, facing)
			var/torso_scale = (shoulders[2] - hips[2]) / (human_shoulders[2] - HUMAN_HIPS_Y)
			return rig_joint_matrix(16, HUMAN_HIPS_Y, torso_scale, 0, hips[1], hips[2], torso_width)
	var/side = copytext(part_id, 1, 2)
	var/segment = copytext(part_id, 3)
	var/list/human_root = get_rig_joint(side == "l" ? (findtext(segment, "arm") ? RIG_L_ARM : RIG_L_LEG) : (findtext(segment, "arm") ? RIG_R_ARM : RIG_R_LEG), facing)
	var/list/points
	var/index
	var/list/human_heights
	switch(segment)
		if("arm", "forearm")
			points = bones["[side]_arm"]
			index = segment == "arm" ? 1 : 2
			human_heights = list(human_root[2], HUMAN_ELBOW_Y, HUMAN_HAND_Y)
		else
			points = bones["[side]_leg"]
			index = segment == "thigh" ? 1 : (segment == "shin" ? 2 : 3)
			human_heights = list(human_root[2], HUMAN_KNEE_Y, HUMAN_ANKLE_Y, 0)
	if(segment == "foot")
		// Shoes cover the paw at the bottom of a long foot, not the whole thing.
		var/list/sole = points[4]
		return rig_joint_matrix(human_root[1], HUMAN_ANKLE_Y, paw_height / HUMAN_ANKLE_Y, 0, sole[1], sole[2] + paw_height)
	var/list/top = points[index]
	var/list/bottom = points[index + 1]
	var/stretch = (top[2] - bottom[2]) / (human_heights[index] - human_heights[index + 1])
	return rig_joint_matrix(human_root[1], human_heights[index], stretch, 0, top[1], top[2], cloth_widths?[segment] || 1)

/datum/limb_rig/sprites/get_pose_matrices(list/pose, facing)
	. = list()
	pose = rig_merge_pose(posture, rig_resolve_aim(posture, pose))
	var/list/bones = skeleton[dir2text(facing)]

	// Legs: thigh, shin and foot, bent into their rest zigzag and then posed.
	var/list/leg_chains = list()
	var/lowest_foot = INFINITY
	for(var/side in list("l", "r"))
		var/list/entry = pose?["[side]_leg"]
		// Either whole angles ("thigh", "shin", "foot", forward from straight down), or the usual
		// swing and knee on top of the rest bend.
		var/thigh = isnull(entry?["thigh"]) ? leg_rest[1] + (entry?["swing"] || 0) : entry["thigh"]
		var/shin = isnull(entry?["shin"]) ? thigh - leg_rest[2] - (entry?["knee"] || 0) : entry["shin"]
		var/foot = isnull(entry?["foot"]) ? shin + leg_rest[3] + (entry?["ankle"] || 0) : entry["foot"]
		var/list/chain = rig_chain(bones["[side]_leg"], list(thigh, shin, foot), facing, entry?["raise"] || 0, side == "r")
		leg_chains[side] = chain
		lowest_foot = min(lowest_foot, chain[5])
	var/list/chest_entry = pose?[RIG_CHEST]
	var/lift = -lowest_foot + (chest_entry?["air"] || 0)
	for(var/side in list("l", "r"))
		var/list/chain = leg_chains[side]
		var/list/segments = list("thigh", "shin", "foot")
		for(var/i in 1 to 3)
			var/matrix/segment_matrix = chain[i]
			segment_matrix.Translate(0, lift)
			var/part_id = "[side]_[segments[i]]"
			.[parts[part_id]] = segment_matrix
			.[cloth_parts[part_id]] = get_cloth_map(part_id, facing) * segment_matrix
			if(i == 3)
				.[shoe_parts[side]] = get_cloth_map(part_id, facing) * segment_matrix

	// (The face goes wherever the piece it's drawn for does: see get_face_anchor().)
	// The upper body hangs off the hips.
	var/matrix/torso = rig_pose_matrix(RIG_CHEST, chest_entry, facing, 1, bones[RIG_CHEST])
	torso.Translate(0, lift)
	.[pivot] = torso
	.[cloth_parts[RIG_CHEST]] = get_cloth_map(RIG_CHEST, facing)
	var/matrix/head = rig_pose_matrix(RIG_HEAD, pose?[RIG_HEAD], facing, 1, bones[RIG_HEAD])
	if(facing == NORTH || facing == SOUTH)
		// From the front, bending over squashes everything on the torso. The head undoes that.
		var/list/neck = bones[RIG_HEAD]
		head = rig_joint_matrix(neck[1], neck[2], 1 / max(cos(chest_entry?["bend"] || 0), 0.25), 0, neck[1], neck[2]) * head
	.[parts[RIG_HEAD]] = head
	.[cloth_parts[RIG_HEAD]] = get_cloth_map(RIG_HEAD, facing) * head
	.[parts[RIG_TAIL]] = rig_tail_matrix(bones[RIG_TAIL], pose?[RIG_TAIL], facing) * torso

	for(var/side in list("l", "r"))
		var/list/entry = pose?["[side]_arm"]
		var/list/points = bones["[side]_arm"]
		// Whole angles ("upper", "lower"), or swing and elbow.
		var/swing = isnull(entry?["upper"]) ? (entry?["swing"] || 0) : entry["upper"]
		var/raise = entry?["raise"] || 0
		var/lower = isnull(entry?["lower"]) ? swing + (entry?["elbow"] || 0) : entry["lower"]
		var/hand_y = entry?["hand_y"]
		if(!isnull(hand_y))
			// Poses give hand heights on a human; carry them over, measured from the hips to the neck.
			var/list/hips = bones[RIG_CHEST]
			var/list/neck = bones[RIG_HEAD]
			var/target = hips[2] + (hand_y - HUMAN_HIPS_Y) * (neck[2] - hips[2]) / (get_rig_joint(RIG_HEAD, facing)[2] - HUMAN_HIPS_Y)
			var/list/shoulder = points[1]
			var/list/elbow = points[2]
			var/list/wrist = points[3]
			var/elbow_height = shoulder[2] - (shoulder[2] - elbow[2]) * cos(swing) * cos(raise)
			var/forearm_drop = (elbow[2] - wrist[2]) * max(cos(raise), 0.1)
			lower = arccos(clamp((elbow_height - target) / forearm_drop, -1, 1))
		var/list/chain = rig_chain(points, list(swing, lower), facing, raise, side == "r")
		.[parts["[side]_arm"]] = chain[1]
		.[parts["[side]_forearm"]] = chain[2]
		.[cloth_parts["[side]_arm"]] = get_cloth_map("[side]_arm", facing) * chain[1]
		.[cloth_parts["[side]_forearm"]] = get_cloth_map("[side]_forearm", facing) * chain[2]
		// Held items are drawn for a human hand; move that hand to this wrist.
		var/list/human_hand = get_rig_joint(side == "l" ? RIG_L_ARM : RIG_R_ARM, facing)
		.[item_parts[side]] = rig_joint_matrix(human_hand[1], HUMAN_HAND_Y, item_scale, chain[5], chain[3], chain[4], item_scale)
	add_face_matrix(.)

#undef HUMAN_HIPS_Y
#undef HUMAN_ELBOW_Y
#undef HUMAN_HAND_Y
#undef HUMAN_KNEE_Y
#undef HUMAN_ANKLE_Y
#undef HUMAN_CROWN_Y
