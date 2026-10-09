/**
 * *skibidi: for a chorus of the song, the body's gone and there's a toilet, and their head comes up out
 * of it on a long neck, grinning far too wide, bobbing to the beat, twitching, and turning about.
 * Then it's all as it was.
 *
 * The body's masked away below the neck (gags_mask.dmi) and the head drawn twice the size, as
 * the meme's heads are; the face over it is drawn at that size too (gags_face.dmi), so it gets
 * every pixel of its grin.
 */
/datum/emote/living/carbon/human/skibidi
	key = "skibidi"
	key_third_person = "skibidis"
	message = "goes skibidi."
	emote_type = EMOTE_VISIBLE | EMOTE_AUDIBLE
	cooldown = 15 SECONDS

/datum/emote/living/carbon/human/skibidi/can_run_emote(mob/user, status_check = TRUE, intentional, params)
	var/mob/living/carbon/human/human_user = user
	if(!istype(human_user) || human_user.current_gag || human_user.body_position == LYING_DOWN || human_user.buckled || !isturf(human_user.loc) || !human_user.get_bodypart(BODY_ZONE_HEAD))
		return FALSE
	return ..()

/datum/emote/living/carbon/human/skibidi/run_emote(mob/user, params, type_override, intentional = FALSE)
	. = ..()
	new /datum/gag/skibidi(user)

/// How long the song is, and how far apart its beats are.
#define SKIBIDI_LENGTH (11.4 SECONDS)
#define SKIBIDI_BEAT 3
/// The bottom of the toilet's bowl, where the neck comes out, in pixels up its sprite.
#define SKIBIDI_BOWL 12
/// How far the bottom of the head is above the bowl (pixels): sunk into it, and out on the neck.
#define SKIBIDI_SUNK 2
#define SKIBIDI_OUT 24
/// How tall the head's drawn, in pixels, whatever size it really is (the meme's heads are big).
#define SKIBIDI_HEAD_HEIGHT 15
/// Where a human's head sits in its sprite: the bottom of it, and the top.
#define SKIBIDI_HUMAN_NECK 21.5
#define SKIBIDI_HUMAN_CROWN 29

/datum/gag/skibidi
	var/obj/effect/abstract/skibidi_part/toilet
	var/obj/effect/abstract/skibidi_part/neck
	var/mutable_appearance/face
	/// What the face is drawn on: the rig's face piece, or the mob itself.
	var/atom/face_holder
	/// How high the bottom of their head is in their sprite, and how much bigger it's drawn.
	var/neck_y = SKIBIDI_HUMAN_NECK
	var/head_scale = 2

/obj/effect/abstract/skibidi_part
	icon = 'icons/obj/watercloset.dmi'
	icon_state = "toilet10"
	layer = MOB_LAYER - 0.02
	appearance_flags = PIXEL_SCALE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/datum/gag/skibidi/act()
	playsound(victim, 'voidcrew/modules/gags/sound/skibidi.ogg', 75, FALSE)
	victim.setDir(SOUTH)
	toilet = new(get_turf(victim))
	neck = new(get_turf(victim))
	neck.icon = 'icons/effects/alphacolors.dmi'
	neck.icon_state = "white"
	neck.layer = MOB_LAYER - 0.01
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	neck.color = head?.get_rig_skin_colour() || "#d9b98c"
	face = mutable_appearance('voidcrew/modules/gags/icons/gags_face.dmi', "skibidi", FLOAT_LAYER + 0.1)
	// The face is drawn at twice a human head's size: 64 pixels for its 32, drawn from 16 off.
	face.pixel_w = -16
	face.pixel_z = -16
	var/matrix/fitted = matrix() * 0.5
	face_holder = victim
	// On a rig, the head's wherever its skeleton puts it.
	var/datum/limb_rig/sprites/rig = victim.limb_rig
	if(istype(rig) && rig.face_part)
		face_holder = rig.face_part
		var/list/bones = rig.skeleton[dir2text(SOUTH)]
		var/list/rig_neck = bones["head"]
		var/list/crown = bones["crown"]
		neck_y = rig_apply_matrix(rig.pivot.transform, rig_neck[1], rig_neck[2])[2]
		head_scale = clamp(SKIBIDI_HEAD_HEIGHT / max(crown[2] - rig_neck[2], 1), 1, 2)
		// Everyone else's face piece is already laid out like a human head (see get_face_anchor());
		// an Experiment's is its own head, so the face is fitted from its neck to its crown.
		if(!istype(rig, /datum/limb_rig/sprites/humanoid))
			var/size = (crown[2] - rig_neck[2]) / (SKIBIDI_HUMAN_CROWN - SKIBIDI_HUMAN_NECK)
			fitted = matrix() * (0.5 * size)
			fitted.Translate(rig_neck[1] - 16, rig_neck[2] - 16 - (SKIBIDI_HUMAN_NECK - 16) * size)
	face.transform = fitted
	if(face_holder == victim)
		face.layer = MOB_LAYER + 0.1
	face_holder.add_overlay(face)
	// Nothing of them below the head.
	victim.add_filter("gag_skibidi", 1, alpha_mask_filter(y = round(neck_y - SKIBIDI_HUMAN_NECK), icon = icon('voidcrew/modules/gags/icons/gags_mask.dmi', "head_only")))
	raise(SKIBIDI_SUNK, 0, 0)
	raise(SKIBIDI_OUT, 0, 6)
	var/beat = 0
	var/static/list/turning = list(SOUTH, WEST, NORTH, EAST)
	while(world.time < started + SKIBIDI_LENGTH - 8)
		GAG_AT(6 + beat * SKIBIDI_BEAT)
		beat++
		// Up and down with the beat, never still, and about every bar.
		raise(beat % 2 ? SKIBIDI_OUT + 5 : SKIBIDI_OUT - 2, rand(-7, 7), SKIBIDI_BEAT)
		if(beat % 4 == 0)
			victim.setDir(turning[(beat / 4) % 4 + 1])
	raise(SKIBIDI_SUNK, 0, 5)
	GAG_AT(SKIBIDI_LENGTH)
	qdel(src)

/// Puts the bottom of the head this many pixels above the bowl, tilted a little, over this long;
/// the neck stretched from the bowl up to it.
/datum/gag/skibidi/proc/raise(height, tilt, time)
	// Where the bottom of the head ends up once it's drawn bigger, about the sprite's middle.
	var/head_bottom = 16 + (neck_y - 16) * head_scale
	var/matrix/head = matrix(old_transform)
	head.Scale(head_scale)
	head.Turn(tilt)
	head.Translate(rand(-1, 1), SKIBIDI_BOWL + height - head_bottom)
	animate(victim, transform = head, time = time, easing = SINE_EASING)
	var/neck_length = max(height + 2, 1)
	var/matrix/stretched = matrix()
	stretched.Scale(8 / 32, neck_length / 32)
	stretched.Translate(0, SKIBIDI_BOWL - (16 - neck_length / 2))
	animate(neck, transform = stretched, time = time, easing = SINE_EASING)

/datum/gag/skibidi/Destroy()
	if(victim)
		victim.remove_filter("gag_skibidi")
	face_holder?.cut_overlay(face)
	face_holder = null
	QDEL_NULL(toilet)
	QDEL_NULL(neck)
	return ..()

#undef SKIBIDI_LENGTH
#undef SKIBIDI_BEAT
#undef SKIBIDI_BOWL
#undef SKIBIDI_SUNK
#undef SKIBIDI_OUT
#undef SKIBIDI_HEAD_HEIGHT
#undef SKIBIDI_HUMAN_NECK
#undef SKIBIDI_HUMAN_CROWN
