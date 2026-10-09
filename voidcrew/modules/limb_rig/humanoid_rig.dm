/**
 * The body every roundstart species is drawn with: a generated, shaded body a quarter bigger than
 * a human, built piece by piece like the Experiment's (see sprite_rig.dm), so an arm or leg moves
 * as a whole limb rather than a cut-out of a flat sprite.
 *
 * What makes the species stays their own. The body is tinted to each limb's colour (skin tone,
 * scales, fur; prosthetics come out their own colour). The real head goes on top, with its hair,
 * eyes, snout, horns, frills, ears and antennae, stretched onto the bigger body like a hat. Tails
 * come off the torso onto the tail bone, wings onto their own piece behind the back, and markings
 * and spines onto the torso like a shirt.
 */
/datum/limb_rig/sprites/humanoid
	/// Wings off the torso, unmasked, stretched onto the body like the shirt is. Hung on the mob, not
	/// the upper body, so they can go behind the legs.
	var/obj/effect/abstract/limb_rig_part/wings_part
	/// The head, as the species draws it, on the head's cloth piece.
	var/list/head_images
	/// Markings and spines off the torso, on the torso's cloth piece.
	var/list/chest_marks
	/// The body sprite on each piece, by piece id.
	var/list/skin_images = list()
	/// How much deeper (or shallower) clothes are drawn on the torso side-on. torso_width is front-on.
	var/torso_depth = 1

/datum/limb_rig/sprites/humanoid/refresh_shape()
	. = ..()
	var/mob/living/carbon/human/human_owner = owner
	torso_depth = human_owner.dna.species.limb_rig_shape["torso_depth"] || torso_width

/**
 * Clothes are stretched from human bones, but a human limb's joint isn't the middle of the limb
 * (a human arm hangs a pixel or so outside its shoulder). Line the middle of each human sleeve and
 * trouser leg up with the middle of this body's limb instead, and draw the torso side-on to its
 * own depth.
 */
/datum/limb_rig/sprites/humanoid/get_cloth_map(part_id, facing)
	var/matrix/map = ..()
	var/facing_name = dir2text(facing)
	if(part_id == RIG_CHEST && (facing & (EAST|WEST)))
		var/list/hips = skeleton[facing_name][RIG_CHEST]
		map.Translate(16.5 - hips[1], 0)
		map.Scale(torso_depth / torso_width, 1)
		map.Translate(hips[1] - 16.5, 0)
	var/middle = get_human_limb_middles()[facing_name][part_id]
	if(isnull(middle))
		return map
	var/side = copytext(part_id, 1, 2)
	var/segment = copytext(part_id, 3)
	var/is_arm = findtext(segment, "arm")
	var/list/root = part_id == RIG_CHEST ? list(16, 0) : get_rig_joint(side == "l" ? (is_arm ? RIG_L_ARM : RIG_L_LEG) : (is_arm ? RIG_R_ARM : RIG_R_LEG), facing)
	var/width = part_id == RIG_CHEST ? ((facing & (EAST|WEST)) ? torso_depth : torso_width) : (cloth_widths?[segment] || 1)
	map.Translate(-(middle - root[1]) * width, 0)
	return map

/// Where the middle of each piece of a human is across, by direction then piece: sleeves and
/// trouser legs are cut around these. Arms hidden behind the body aren't moved.
/proc/get_human_limb_middles()
	var/static/list/middles = list(
		"south" = list("l_arm" = 22, "r_arm" = 10, "l_forearm" = 22.5, "r_forearm" = 9.5, "l_thigh" = 18.5, "r_thigh" = 13.5, "l_shin" = 19.1, "r_shin" = 12.9),
		"north" = list("l_arm" = 10, "r_arm" = 22, "l_forearm" = 9.5, "r_forearm" = 22.5, "l_thigh" = 13.5, "r_thigh" = 18.5, "l_shin" = 12.9, "r_shin" = 19.1),
		"east" = list("r_arm" = 13.25, "r_forearm" = 14.5, "l_thigh" = 16.5, "r_thigh" = 15.8, "l_shin" = 17.1, "r_shin" = 17.1, RIG_CHEST = 16.1),
		"west" = list("l_arm" = 19.75, "l_forearm" = 18.5, "l_thigh" = 17.2, "r_thigh" = 16.5, "l_shin" = 16.9, "r_shin" = 16.9, RIG_CHEST = 16.9),
	)
	return middles

/datum/limb_rig/sprites/humanoid/build_pieces()
	. = ..()
	wings_part = new_part(RIG_CHEST)
	hang_on_owner(wings_part)
	// The tail as the species draws it, carried on the tail bone.
	tail_part = new_part(RIG_TAIL)
	hang_on_owner(tail_part)

// The body sprite goes on in refresh_skin(), tinted.
/datum/limb_rig/sprites/humanoid/refresh_sprite_image(part_id)
	return

/datum/limb_rig/sprites/humanoid/set_sprite_saturation(value)
	if(sprite_saturation == value)
		return
	sprite_saturation = value
	if(length(parts))
		refresh_skin()

/datum/limb_rig/sprites/humanoid/Destroy()
	. = ..()
	QDEL_NULL(wings_part)
	head_images = null
	chest_marks = null
	skin_images = null

/datum/limb_rig/sprites/humanoid/set_layer(cache_index, standing)
	. = ..()
	if(cache_index == BODYPARTS_LAYER)
		refresh_species_parts()

/datum/limb_rig/sprites/humanoid/refresh_limbs()
	. = ..()
	refresh_skin()

/// Puts each piece's body sprite on, tinted to its limb.
/datum/limb_rig/sprites/humanoid/proc/refresh_skin()
	var/list/zones = get_rig_piece_zones()
	var/mob/living/carbon/human/human_owner = owner
	var/female = istype(human_owner) && human_owner.physique == FEMALE
	for(var/part_id in zones)
		var/obj/effect/abstract/limb_rig_part/part = parts[part_id]
		part.cut_overlay(skin_images[part_id])
		var/image/skin = image(sprite_icon, (part_id == RIG_CHEST && female) ? "chest_f" : part_id)
		skin.pixel_w = -16
		var/obj/item/bodypart/limb = owner.get_bodypart(zones[part_id])
		skin.color = get_drained_colour(limb?.get_rig_skin_colour(), sprite_saturation)
		part.add_overlay(skin)
		skin_images[part_id] = skin

/// A tint with only this much of its colour left (0 to 1), as a colour if it was one, else a matrix.
/proc/get_drained_colour(colour, saturation)
	if(saturation >= 1)
		return colour
	if(!istext(colour))
		return color_matrix_saturation(saturation)
	var/list/rgb = rgb2num(colour)
	var/grey = rgb[1] * 0.3 + rgb[2] * 0.59 + rgb[3] * 0.11
	return rgb(grey + (rgb[1] - grey) * saturation, grey + (rgb[2] - grey) * saturation, grey + (rgb[3] - grey) * saturation)

/// Takes the head, tail, wings and markings from the species' own limb sprites.
/datum/limb_rig/sprites/humanoid/proc/refresh_species_parts()
	var/obj/effect/abstract/limb_rig_part/head_cloth = cloth_parts[RIG_HEAD]
	var/obj/effect/abstract/limb_rig_part/chest_cloth = cloth_parts[RIG_CHEST]
	head_cloth.cut_overlay(head_images)
	chest_cloth.cut_overlay(chest_marks)
	wings_part.cut_overlays()
	tail_part.cut_overlays()
	head_images = get_limb_images(BODY_ZONE_HEAD)
	head_cloth.add_overlay(head_images)

	chest_marks = list()
	var/list/wings = list()
	var/list/tail = list()
	var/obj/item/bodypart/chest/chest = owner.get_bodypart(BODY_ZONE_CHEST)
	if(!chest)
		return
	for(var/image/overlay as anything in get_limb_images(BODY_ZONE_CHEST))
		var/state = overlay.icon_state
		// The chest sprite itself (and its emissive blocker): the body is drawn instead.
		if(!istext(state) || findtext(state, "[chest.limb_id]_chest") == 1)
			continue
		if(findtext(state, "tail"))
			tail += overlay
		else if(findtext(state, "wing"))
			wings += overlay
		else
			chest_marks += overlay
	chest_cloth.add_overlay(chest_marks)
	wings_part.add_overlay(wings)
	tail_part.add_overlay(tail)

/// The images a limb is drawn with, as the mob last drew it.
/datum/limb_rig/sprites/humanoid/proc/get_limb_images(zone)
	var/key = owner.icon_render_keys[zone]
	var/list/images = key && owner.limb_icon_cache[key]
	return images ? images.Copy() : list()

/datum/limb_rig/sprites/humanoid/refresh_facing()
	. = ..()
	var/facing = get_facing()
	// Behind everything, legs included, unless the back is what's seen.
	wings_part.layer = facing == NORTH ? -1 : -10
	tail_part.layer = parts[RIG_TAIL].layer + 0.1
	sort_pieces()

// A species' own head, and its face, are drawn on the head's cloth piece.
/datum/limb_rig/sprites/humanoid/get_face_anchor()
	return cloth_parts[RIG_HEAD]

/datum/limb_rig/sprites/humanoid/get_pose_matrices(list/pose, facing)
	. = ..()
	.[wings_part] = .[cloth_parts[RIG_CHEST]] * .[pivot]
	// From where a human's tail joins on to this body's tail bone, then swung with it.
	var/list/root = get_tail_root(facing)
	var/list/bone = skeleton[dir2text(facing)][RIG_TAIL]
	.[tail_part] = rig_joint_matrix(root[1], root[2], hat_scale, 0, bone[1], bone[2], hat_scale) * .[parts[RIG_TAIL]]

/**
 * The colour a limb's skin is, to tint the body with: what the species colours it, or for a limb
 * drawn in its own colours (moths, plasmamen, prosthetics), the average of its sprite.
 */
/obj/item/bodypart/proc/get_rig_skin_colour()
	if(should_draw_greyscale && draw_color)
		return draw_color
	var/sprite_icon = (should_draw_greyscale && icon_greyscale) ? icon_greyscale : icon_static
	var/sprite_state = is_dimorphic ? "[limb_id]_[body_zone]_[limb_gender]" : "[limb_id]_[body_zone]"
	var/static/list/colours = list()
	var/key = "[sprite_icon]-[sprite_state]"
	if(!isnull(colours[key]))
		return colours[key]
	var/icon/sprite = icon(sprite_icon, sprite_state, SOUTH)
	var/red = 0
	var/green = 0
	var/blue = 0
	var/count = 0
	for(var/x in 1 to 32)
		for(var/y in 1 to 32)
			var/pixel = sprite.GetPixel(x, y)
			if(!pixel)
				continue
			var/list/channels = rgb2num(pixel)
			if(length(channels) > 3 && channels[4] < 128)
				continue
			red += channels[1]
			green += channels[2]
			blue += channels[3]
			count++
	// Lighten it a little: the body's shading darkens it again, and averages come out dull.
	colours[key] = count ? rgb(min(red / count * 1.1, 255), min(green / count * 1.1, 255), min(blue / count * 1.1, 255)) : "#ffffff"
	return colours[key]
