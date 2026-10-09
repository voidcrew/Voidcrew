/**
 * How singers move in a rhythm battle, after how Boyfriend moves in Friday Night Funkin':
 * - Between notes, they bop on every beat, dipping down and springing back up, mic bobbing.
 * - A note snaps them into its pose, overshooting and settling, and a long note makes them
 *   vibrate in it for as long as it's held.
 * - The mic stays in one hand, up at the mouth. Singing at the rival thrusts it at them.
 *
 * The two singers face each other, like in Funkin': the challenger on the right looks left, the
 * opponent looks right. So the arrow pointing at the rival means leaning in, and the one pointing
 * away means rearing back. Rigged mobs (Experiments, and anyone Overanimated) do all that with the
 * limb rig; anyone else gets a little bump.
 */

/// Mic up at the mouth.
#define FNF_MIC_UP list("swing" = 50, "raise" = 10, "hand_y" = 27)
/// The free hand balled into a fist at the side.
#define FNF_FIST list("swing" = 15, "raise" = 10, "elbow" = 75)

/// A deep copy of a pose, safe to change.
/proc/fnf_copy_pose(list/pose)
	. = list()
	for(var/part_id in pose)
		var/list/entry = pose[part_id]
		.[part_id] = entry.Copy()

/// A pose with every angle scaled, for overshooting into it. Hand heights stay put.
/proc/fnf_scale_pose(list/pose, factor)
	. = fnf_copy_pose(pose)
	for(var/part_id in .)
		var/list/entry = .[part_id]
		for(var/key in entry)
			if(key != "hand_y")
				entry[key] *= factor

/// A pose with one value nudged, for a held note's vibrato.
/proc/fnf_nudge_pose(list/pose, part_id, key, amount)
	. = fnf_copy_pose(pose)
	var/list/entry = .[part_id]
	if(!entry)
		entry = list()
		.[part_id] = entry
	entry[key] = (entry[key] || 0) + amount

/**
 * A battle pose.
 *
 * * kind - "rest", "bop", "hey", "miss", or a lane: 0 to 3 for left, down, up, right. Also the
 *   one-off moves events and special notes call for (see fnf_act()): "ugh", "kick", "cock",
 *   "shoot", and Blazin's fight: "punch_high", "punch_low", "block", "dodge_high", "dodge_low",
 *   "hit_high", "hit_low", "prep", "uppercut", "uppercut_hit", "taunt". And "aim", the gun
 *   levelled straight out ("aim_both" for two), and the backup dancers' "dance_left" and
 *   "dance_right". And Corruption+'s "scream", Kapi's "meow", "confused", and Marble's "stare".
 * * mic_arm - the arm with the mic in it, RIG_L_ARM or RIG_R_ARM
 * * facing - which way the singer faces, WEST or EAST, to tell which arrow points at the rival
 * * style - a character's own way of moving on top (see fnf_apply_style), or null
 */
/proc/fnf_pose(kind, mic_arm, facing, style)
	var/free_arm = mic_arm == RIG_L_ARM ? RIG_R_ARM : RIG_L_ARM
	if(isnum(kind) && (kind == 0 || kind == 3))
		kind = (kind == 0) == (facing == WEST) ? "toward" : "away"
	. = list()
	.[mic_arm] = FNF_MIC_UP
	.[free_arm] = FNF_FIST
	switch(kind)
		if("bop")
			// Dipped: knees bent, squashed down, head and mic bobbing with it.
			.[RIG_CHEST] = list("breath" = -0.035, "bend" = 8)
			.[RIG_HEAD] = list("nod" = 10)
			.[RIG_L_LEG] = list("swing" = 12, "knee" = 22)
			.[RIG_R_LEG] = list("swing" = 12, "knee" = 22)
			.[mic_arm] = list("swing" = 45, "raise" = 10, "hand_y" = 24)
			.[RIG_TAIL] = list("lift" = -8)
		if("toward")
			// Leaning in at the rival, mic thrust right in their face, a foot stepping in.
			.[RIG_CHEST] = list("bend" = 15)
			.[RIG_HEAD] = list("nod" = -6)
			.[mic_arm] = list("swing" = 90, "raise" = 5, "elbow" = 0)
			.[free_arm] = list("swing" = -25, "raise" = 10, "elbow" = 60)
			.[RIG_L_LEG] = list("swing" = 30, "knee" = 15)
			.[RIG_R_LEG] = list("swing" = -15)
			.[RIG_TAIL] = list("lift" = 25)
		if("away")
			// Rearing back, the free fist flung behind, mic still at the mouth.
			.[RIG_CHEST] = list("bend" = -14)
			.[RIG_HEAD] = list("nod" = -12)
			.[mic_arm] = list("swing" = 60, "raise" = 10, "hand_y" = 28)
			.[free_arm] = list("swing" = -70, "raise" = 15, "elbow" = 25)
			.[RIG_L_LEG] = list("swing" = -20, "knee" = 10)
			.[RIG_R_LEG] = list("swing" = 15)
			.[RIG_TAIL] = list("lift" = -15)
		if(1)
			// Down: a deep crouch, head down, mic thrust down at the floor.
			.[RIG_CHEST] = list("bend" = 28, "breath" = -0.05)
			.[RIG_HEAD] = list("nod" = 20)
			.[RIG_L_LEG] = list("swing" = 35, "knee" = 55)
			.[RIG_R_LEG] = list("swing" = 35, "knee" = 55)
			.[mic_arm] = list("swing" = 35, "raise" = 5, "elbow" = 0)
			.[free_arm] = list("swing" = -20, "raise" = 15, "elbow" = 50)
			.[RIG_TAIL] = list("lift" = -25)
		if(2)
			// Up: chin up, mic up high, up on the toes, fist in the air.
			.[RIG_CHEST] = list("bend" = -10, "breath" = 0.05, "air" = 3)
			.[RIG_HEAD] = list("nod" = -25)
			.[mic_arm] = list("swing" = 100, "raise" = 5, "hand_y" = 32)
			.[free_arm] = list("swing" = 150, "raise" = 10, "elbow" = 30)
			.[RIG_TAIL] = list("lift" = 35)
		if("miss")
			// Recoiling: leaning back, arms up in a flinch.
			.[RIG_CHEST] = list("bend" = -15, "breath" = -0.03)
			.[RIG_HEAD] = list("nod" = -15)
			.[mic_arm] = list("swing" = 60, "raise" = 15, "elbow" = 90)
			.[free_arm] = list("swing" = 70, "raise" = 15, "elbow" = 90)
			.[RIG_TAIL] = list("lift" = -30)
		if("hey")
			// Hey! Free arm thrown up, mic still at the mouth, up on the toes.
			.[free_arm] = list("swing" = 170, "raise" = 10, "elbow" = 10)
			.[RIG_CHEST] = list("air" = 4, "breath" = 0.04, "bend" = -6)
			.[RIG_HEAD] = list("nod" = -15)
			.[RIG_TAIL] = list("lift" = 35, "wag" = 20)
		if("ugh")
			// Ugh! Hunched over the mic, head dropped, free fist shaken low.
			.[RIG_CHEST] = list("bend" = 22, "breath" = -0.04)
			.[RIG_HEAD] = list("nod" = 28, "tilt" = 10)
			.[free_arm] = list("swing" = 30, "raise" = 20, "elbow" = 100)
			.[RIG_L_LEG] = list("swing" = 15, "knee" = 25)
			.[RIG_R_LEG] = list("swing" = 15, "knee" = 25)
		if("scream")
			// Screaming in agony: rearing back, head thrown back and to the side, the free hand
			// clamped to it and the mic arm up across the face.
			.[RIG_CHEST] = list("bend" = -14, "breath" = 0.05)
			.[RIG_HEAD] = list("nod" = -22, "tilt" = 14)
			.[free_arm] = list("swing" = 130, "raise" = 25, "hand_y" = 29)
			.[mic_arm] = list("swing" = 95, "raise" = 10, "elbow" = 75)
			.[RIG_L_LEG] = list("swing" = 10, "knee" = 25)
			.[RIG_R_LEG] = list("swing" = 10, "knee" = 25)
			.[RIG_TAIL] = list("lift" = -35)
		if("meow")
			// Meow! Both paws curled up by the face, head cocked, tail up and swishing.
			.[RIG_CHEST] = list("bend" = 6, "breath" = 0.03)
			.[RIG_HEAD] = list("nod" = -8, "tilt" = 12)
			.[free_arm] = list("swing" = 60, "raise" = 15, "elbow" = 110)
			.[mic_arm] = list("swing" = 55, "raise" = 15, "elbow" = 115)
			.[RIG_TAIL] = list("lift" = 30, "wag" = 18)
		if("confused")
			// Huh? Scratching the head, head cocked the other way.
			.[RIG_CHEST] = list("bend" = -4)
			.[RIG_HEAD] = list("nod" = 6, "tilt" = -16)
			.[free_arm] = list("swing" = 125, "raise" = 20, "hand_y" = 30)
			.[RIG_TAIL] = list("lift" = -10)
		if("kick")
			// Punting something up off the foot.
			.[RIG_CHEST] = list("bend" = -12)
			.[RIG_HEAD] = list("nod" = 10)
			.[RIG_L_LEG] = list("swing" = 80, "knee" = 10)
			.[RIG_R_LEG] = list("swing" = -10, "knee" = 15)
			.[free_arm] = list("swing" = -40, "raise" = 30, "elbow" = 20)
		if("cock")
			// Racking the gun, held up by the face.
			.[free_arm] = list("swing" = 120, "raise" = 5, "elbow" = 100)
			.[RIG_HEAD] = list("nod" = -8)
			.[RIG_CHEST] = list("bend" = -4)
		if("shoot")
			// Gun levelled up at the sky's corner, kicking back.
			.[free_arm] = list("swing" = 125, "raise" = 5, "elbow" = 0)
			.[RIG_CHEST] = list("bend" = -10)
			.[RIG_HEAD] = list("nod" = -18)
		if("punch_high", "punch_low")
			// A straight jab from the free fist, the body turning into it.
			var/low = kind == "punch_low"
			.[free_arm] = list("swing" = low ? 70 : 95, "raise" = 5, "elbow" = 0)
			.[mic_arm] = list("swing" = 60, "raise" = 10, "elbow" = 110)
			.[RIG_CHEST] = list("bend" = low ? 26 : 14, "lean" = 4)
			.[RIG_HEAD] = list("nod" = low ? 8 : -4)
			.[RIG_L_LEG] = list("swing" = 30, "knee" = low ? 35 : 15)
			.[RIG_R_LEG] = list("swing" = -20, "knee" = low ? 20 : 0)
		if("block")
			// Guard up: both forearms across the face.
			.[free_arm] = list("swing" = 70, "raise" = 10, "elbow" = 120)
			.[mic_arm] = list("swing" = 75, "raise" = 10, "elbow" = 115)
			.[RIG_CHEST] = list("bend" = 12)
			.[RIG_HEAD] = list("nod" = 18)
			.[RIG_L_LEG] = list("swing" = 10, "knee" = 25)
			.[RIG_R_LEG] = list("swing" = 10, "knee" = 25)
		if("dodge_high", "dodge_low")
			// Ducking under a punch, or swaying back out of one.
			var/low = kind == "dodge_low"
			.[RIG_CHEST] = list("bend" = low ? 40 : -28, "breath" = -0.04)
			.[RIG_HEAD] = list("nod" = low ? 10 : -20)
			.[RIG_L_LEG] = list("swing" = low ? 45 : -10, "knee" = low ? 70 : 10)
			.[RIG_R_LEG] = list("swing" = low ? 45 : 20, "knee" = low ? 70 : 10)
			.[free_arm] = list("swing" = 40, "raise" = 20, "elbow" = 90)
		if("hit_high", "hit_low", "uppercut_hit")
			// Rocked by a punch: head snapped back (or folded over one to the gut), arms flung.
			var/low = kind == "hit_low"
			var/big = kind == "uppercut_hit"
			.[RIG_CHEST] = list("bend" = low ? 30 : (big ? -35 : -22), "breath" = -0.05, "air" = big ? 6 : 0)
			.[RIG_HEAD] = list("nod" = low ? 25 : (big ? -40 : -30), "tilt" = 12)
			.[free_arm] = list("swing" = low ? 30 : 110, "raise" = 40, "elbow" = 30)
			.[mic_arm] = list("swing" = low ? 40 : 100, "raise" = 35, "elbow" = 40)
			.[RIG_L_LEG] = list("swing" = -15, "knee" = 20)
			.[RIG_R_LEG] = list("swing" = 20, "knee" = 10)
			.[RIG_TAIL] = list("lift" = -30)
		if("prep")
			// Winding up an uppercut: crouched low, fist drawn right back.
			.[RIG_CHEST] = list("bend" = 30)
			.[RIG_HEAD] = list("nod" = -10)
			.[free_arm] = list("swing" = -40, "raise" = 10, "elbow" = 100)
			.[RIG_L_LEG] = list("swing" = 40, "knee" = 70)
			.[RIG_R_LEG] = list("swing" = 30, "knee" = 60)
		if("uppercut")
			// And up: the fist driven skyward, off the ground with it.
			.[free_arm] = list("swing" = 165, "raise" = 5, "elbow" = 20)
			.[RIG_CHEST] = list("bend" = -12, "air" = 5)
			.[RIG_HEAD] = list("nod" = -20)
			.[RIG_L_LEG] = list("swing" = 10, "knee" = 30)
			.[RIG_R_LEG] = list("swing" = -25)
		if("aim", "aim_both")
			// Gun levelled straight out at something, or both of them.
			.[free_arm] = list("swing" = 90, "raise" = 5, "elbow" = 0)
			if(kind == "aim_both")
				.[mic_arm] = list("swing" = 82, "raise" = 12, "elbow" = 0)
			.[RIG_CHEST] = list("bend" = 4)
		if("dance_left", "dance_right")
			// Hands up, hips swung out to one side and the head the other way.
			var/way = kind == "dance_left" ? 1 : -1
			.[RIG_L_ARM] = list("swing" = 150, "raise" = 25 + 15 * way, "elbow" = 40)
			.[RIG_R_ARM] = list("swing" = 150, "raise" = 25 - 15 * way, "elbow" = 40)
			.[RIG_CHEST] = list("lean" = 8 * way, "bend" = 4)
			.[RIG_HEAD] = list("tilt" = -12 * way, "nod" = 6)
			.[way > 0 ? RIG_L_LEG : RIG_R_LEG] = list("swing" = 20, "knee" = 25)
		if("stare")
			// Corrupted Marble behind the speaker: glaring at the enemy, head cocked, the near arm (the
			// free one) reached up and out at them, clear of her face, claws spread, the other hand
			// back on the speaker behind her.
			.[free_arm] = list("swing" = 110, "raise" = 20, "elbow" = 40)
			.[mic_arm] = list("swing" = -35, "raise" = 10, "elbow" = 20)
			.[RIG_CHEST] = list("bend" = 4)
			.[RIG_HEAD] = list("nod" = 8, "tilt" = 10)
			.[RIG_TAIL] = list("lift" = -10, "wag" = 10)
		if("taunt")
			// Come on then: beckoning, chin up, weight back.
			.[free_arm] = list("swing" = 80, "raise" = 10, "elbow" = 80)
			.[RIG_CHEST] = list("bend" = -10)
			.[RIG_HEAD] = list("nod" = -18, "tilt" = -10)
	if(style)
		fnf_apply_style(., kind, style, mic_arm, free_arm)

/// Which arm a singer has the mic in: the hand holding a battle microphone, or else the arm
/// nearer the crowd when facing that way.
/mob/living/proc/fnf_mic_arm(facing)
	for(var/obj/item/fnf_microphone/microphone in held_items)
		return IS_RIGHT_INDEX(get_held_index_of_item(microphone)) ? RIG_R_ARM : RIG_L_ARM
	return facing == WEST ? RIG_L_ARM : RIG_R_ARM

/// Snaps into an arrow's pose, holds it for hold deciseconds (vibrating if it's long), then goes back to the mic.
/mob/living/proc/fnf_sing(lane, hold, mic_arm, facing, style)
	setDir(facing)
	var/static/list/nudges = list(list(-3, 0), list(0, -3), list(0, 3), list(3, 0))
	var/list/nudge = nudges[lane + 1]
	fnf_nudge(nudge[1], nudge[2])

/mob/living/carbon/fnf_sing(lane, hold, mic_arm, facing, style)
	if(!limb_rig)
		return ..()
	fnf_hide_mic(style)
	setDir(facing)
	var/static/list/faces = list("left", "down", "up", "right")
	// The character's own move, traced off their sprites, held for the note.
	var/list/traced = fnf_traced_keyframes(style, "sing[uppertext(faces[lane + 1])]", facing)
	if(traced)
		limb_rig.play(fnf_traced_hold(traced, hold, fnf_traced_rest(style, mic_arm, facing)), settle_after = FALSE)
		limb_rig.set_fnf_face(faces[lane + 1], max(hold, 1.5))
		fnf_idle_until = 0
		if((style == "pico" || style == "cpico") && (lane == 0 || lane == 3) && ((lane == 0) == (facing == WEST)))
			fnf_spin_guns(mic_arm, style, 3)
		return
	var/list/pose = fnf_pose(lane, mic_arm, facing, style)
	var/list/keyframes = list(
		list(fnf_scale_pose(pose, 1.2), 0.5, CUBIC_EASING|EASE_OUT),
		list(pose, 1, SINE_EASING),
	)
	// Held notes: a vibrato, mic and head working with the voice.
	var/held = hold - 1.5
	var/beat = 0
	while(held > 0.6)
		beat++
		var/amount = beat % 2 ? 4 : -4
		var/list/wobble = fnf_nudge_pose(pose, mic_arm, "swing", amount)
		wobble = fnf_nudge_pose(wobble, RIG_HEAD, "nod", amount * 0.6)
		keyframes += list(list(wobble, 0.6, SINE_EASING))
		held -= 0.6
	keyframes += list(list(fnf_pose("rest", mic_arm, facing, style), 2, SINE_EASING))
	limb_rig.play(keyframes, settle_after = FALSE)
	// The face for the note, held as long as the note is.
	limb_rig.set_fnf_face(faces[lane + 1], 1.5 + beat * 0.6)
	// Pico spins his gun round into aiming it at the rival.
	if((style == "pico" || style == "cpico") && (lane == 0 || lane == 3) && ((lane == 0) == (facing == WEST)))
		fnf_spin_guns(mic_arm, style, 3)

/// The between-notes bop, one beat long.
/mob/living/proc/fnf_bop(beat_time, mic_arm, facing, style)
	fnf_nudge(0, -1)

/mob/living/carbon/fnf_bop(beat_time, mic_arm, facing, style)
	if(!limb_rig)
		return ..()
	fnf_hide_mic(style)
	if(!limb_rig.is_pulling_fnf_face())
		limb_rig.set_fnf_face("idle")
	// A traced idle plays right through, then starts again on the next beat after.
	var/list/idle = fnf_traced_keyframes(style, "idle", facing) || fnf_traced_sway(style, facing)
	if(idle)
		if(world.time < fnf_idle_until)
			return
		fnf_idle_until = world.time + fnf_keyframes_time(idle) - 0.5
		limb_rig.play(idle, settle_after = FALSE)
		return
	limb_rig.play(list(
		list(fnf_pose("bop", mic_arm, facing, style), beat_time * 0.25, CUBIC_EASING|EASE_OUT),
		list(fnf_pose("rest", mic_arm, facing, style), beat_time * 0.75, SINE_EASING),
	), settle_after = FALSE)

/mob/living/proc/fnf_nudge(x_offset, z_offset)
	// Back to where the mob rests (up on the speakers, say), not to the floor.
	var/home_w = base_pixel_w + has_offset(null, PIXEL_W_OFFSET)
	var/home_z = base_pixel_z + has_offset(null, PIXEL_Z_OFFSET)
	animate(src, pixel_w = home_w + x_offset, pixel_z = home_z + z_offset, time = 0.5, flags = ANIMATION_PARALLEL)
	animate(pixel_w = home_w, pixel_z = home_z, time = 2, easing = SINE_EASING)

/**
 * Hanging there instead of bopping, still but for a twitch now and then: Purification's Girlfriend,
 * once Boyfriend's swooped in to sing for her.
 */
/mob/living/proc/fnf_hang(beat_time, mic_arm, facing, style)
	if(prob(25))
		fnf_nudge(pick(-1, 1), 0)

/mob/living/carbon/fnf_hang(beat_time, mic_arm, facing, style)
	if(!limb_rig)
		return ..()
	if(!limb_rig.is_pulling_fnf_face())
		limb_rig.set_fnf_face("idle")
	// Purification's Girlfriend has her own, traced.
	var/list/traced = fnf_traced_keyframes(style, "idle-alt", facing)
	if(traced)
		if(world.time >= fnf_idle_until)
			fnf_idle_until = world.time + fnf_keyframes_time(traced) - 0.5
			limb_rig.play(traced, settle_after = FALSE)
		return
	var/list/pose = fnf_pose("rest", mic_arm, facing, style)
	if(!prob(30))
		limb_rig.play(list(list(pose, beat_time, SINE_EASING)), settle_after = FALSE)
		return
	var/list/twitch = fnf_nudge_pose(pose, RIG_HEAD, "tilt", pick(-14, 12))
	twitch = fnf_nudge_pose(twitch, RIG_HEAD, "nod", pick(-6, 8))
	twitch = fnf_nudge_pose(twitch, mic_arm == RIG_L_ARM ? RIG_R_ARM : RIG_L_ARM, "elbow", 25)
	limb_rig.play(list(
		list(twitch, 0.4),
		list(twitch, 0.5),
		list(pose, max(beat_time - 0.9, 1), SINE_EASING),
	), settle_after = FALSE)

/mob/living/proc/fnf_flash(colour, duration)
	add_atom_colour(colour, TEMPORARY_COLOUR_PRIORITY)
	addtimer(CALLBACK(src, TYPE_PROC_REF(/atom, remove_atom_colour), TEMPORARY_COLOUR_PRIORITY, colour), duration, TIMER_UNIQUE|TIMER_OVERRIDE)

/mob/living/proc/fnf_miss(mic_arm, facing, style)
	fnf_flash("#8a8aff", 3)
	fnf_nudge(0, -2)

/mob/living/carbon/fnf_miss(mic_arm, facing, style)
	if(!limb_rig)
		return ..()
	fnf_flash("#8a8aff", 3)
	// Recoil, shake it off, back to the mic.
	var/list/flinch = fnf_pose("miss", mic_arm, facing, style)
	limb_rig.play(list(
		list(fnf_scale_pose(flinch, 1.15), 0.5, CUBIC_EASING|EASE_OUT),
		list(fnf_nudge_pose(flinch, RIG_HEAD, "nod", 12), 0.7, SINE_EASING),
		list(flinch, 0.7, SINE_EASING),
		list(fnf_pose("rest", mic_arm, facing, style), 1.5, SINE_EASING),
	), settle_after = FALSE)
	limb_rig.set_fnf_face("miss", 1.9)

/mob/living/proc/fnf_hey(mic_arm, facing, style)
	fnf_nudge(0, 4)
	if(is_species(src, /datum/species/experiment))
		playsound(src, get_expie_exert_sound(), 40, TRUE)

/mob/living/carbon/fnf_hey(mic_arm, facing, style)
	. = ..()
	if(!limb_rig)
		return
	var/list/hey = fnf_pose("hey", mic_arm, facing, style)
	limb_rig.play(list(
		list(fnf_scale_pose(hey, 1.15), 0.6, BACK_EASING|EASE_OUT),
		list(hey, 5),
		list(fnf_pose("rest", mic_arm, facing, style), 2, SINE_EASING),
	), settle_after = FALSE)
	limb_rig.set_fnf_face("hey", 5.6)

/// Screaming in agony (Corruption+'s corrupted Pico, fighting it): snaps into it and shakes.
/mob/living/proc/fnf_scream(mic_arm, facing, style)
	fnf_nudge(0, 2)

/mob/living/carbon/fnf_scream(mic_arm, facing, style)
	. = ..()
	if(!limb_rig)
		return
	setDir(facing)
	// Corrupted Pico's own, traced: into it, then shaking in its last two frames.
	var/list/traced = fnf_traced_keyframes(style, "scream", facing)
	if(length(traced) >= 2)
		var/list/shaking = traced.Copy()
		for(var/i in 1 to 4)
			shaking += traced.Copy(length(traced) - 1)
		shaking += list(list(fnf_traced_rest(style, mic_arm, facing), 3, SINE_EASING))
		limb_rig.play(shaking, settle_after = FALSE)
		limb_rig.set_fnf_face("miss", 4)
		fnf_idle_until = 0
		return
	var/list/scream = fnf_pose("scream", mic_arm, facing, style)
	var/list/frames = list(list(fnf_scale_pose(scream, 1.15), 0.5, CUBIC_EASING|EASE_OUT))
	// Shaking with it.
	for(var/i in 1 to 4)
		frames += list(list(fnf_nudge_pose(scream, RIG_HEAD, "tilt", i % 2 ? -8 : 8), 0.8))
	frames += list(list(fnf_pose("rest", mic_arm, facing, style), 3, SINE_EASING))
	limb_rig.play(frames, settle_after = FALSE)
	limb_rig.set_fnf_face("miss", 4)

/**
 * Standing still and staring (Corruption+'s Marble, behind the speaker): side-on, so the face shows,
 * held in her pose but for a twitch now and then, the head jerking and the raised hand clenching.
 */
/mob/living/proc/fnf_stare(beat_time, facing)
	setDir(facing)
	if(prob(30))
		fnf_nudge(facing == EAST ? 1 : -1, 0)

/mob/living/carbon/fnf_stare(beat_time, facing)
	if(!limb_rig)
		return ..()
	setDir(facing)
	if(!limb_rig.is_pulling_fnf_face())
		limb_rig.set_fnf_face("idle")
	// Her own idle, traced, with a twitch thrown in now and then.
	var/list/traced = fnf_traced_keyframes("marble", "idle", facing)
	if(traced)
		if(world.time < fnf_idle_until)
			return
		var/list/frames = traced.Copy()
		if(prob(35))
			var/list/last = frames[length(frames)]
			var/list/twitch = fnf_nudge_pose(fnf_nudge_pose(last[1], RIG_HEAD, "tilt", pick(-16, 14)), RIG_HEAD, "nod", pick(-8, 6))
			frames += list(list(twitch, 0.4), list(last[1], 0.6))
		fnf_idle_until = world.time + fnf_keyframes_time(frames) - 0.5
		limb_rig.play(frames, settle_after = FALSE)
		return
	// The near arm's the one reaching out: the far one goes back to the speaker.
	var/near_arm = facing == WEST ? RIG_L_ARM : RIG_R_ARM
	var/list/pose = fnf_pose("stare", near_arm == RIG_L_ARM ? RIG_R_ARM : RIG_L_ARM, facing, null)
	if(!prob(30))
		limb_rig.play(list(list(pose, beat_time, SINE_EASING)), settle_after = FALSE)
		return
	var/list/twitch = fnf_nudge_pose(pose, RIG_HEAD, "tilt", pick(-16, 14))
	twitch = fnf_nudge_pose(twitch, RIG_HEAD, "nod", pick(-8, 6))
	twitch = fnf_nudge_pose(twitch, near_arm, "elbow", 30)
	limb_rig.play(list(
		list(twitch, 0.4),
		list(twitch, 0.6),
		list(pose, max(beat_time - 1, 1), SINE_EASING),
	), settle_after = FALSE)

/// A one-off move (see fnf_pose()): snaps into it, holds it for hold deciseconds, and goes back.
/mob/living/proc/fnf_act(kind, mic_arm, facing, style, hold = 3)
	var/static/list/nudges = list("hit_high" = -4, "hit_low" = -3, "uppercut_hit" = -6, "punch_high" = 4, "punch_low" = 4, "uppercut" = 3, "dodge_high" = -3, "shoot" = -2)
	var/push = nudges[kind] || 0
	fnf_nudge(facing == EAST ? push : -push, kind == "uppercut" || kind == "uppercut_hit" ? 4 : 0)

/mob/living/carbon/fnf_act(kind, mic_arm, facing, style, hold = 3)
	. = ..()
	if(!limb_rig)
		return
	setDir(facing)
	var/list/traced = fnf_traced_keyframes(style, kind, facing)
	if(traced)
		limb_rig.play(fnf_traced_hold(traced, hold, fnf_traced_rest(style, mic_arm, facing)), settle_after = FALSE)
		fnf_idle_until = 0
	else
		var/list/pose = fnf_pose(kind, mic_arm, facing, style)
		limb_rig.play(list(
			list(fnf_scale_pose(pose, 1.15), 0.5, CUBIC_EASING|EASE_OUT),
			list(pose, hold, SINE_EASING),
			list(fnf_pose("rest", mic_arm, facing, style), 2, SINE_EASING),
		), settle_after = FALSE)
	// Pico twirls his gun for a taunt, or getting cocky.
	if((style == "pico" || style == "cpico") && (kind == "taunt" || kind == "cock"))
		fnf_spin_guns(mic_arm, style, max(hold, 4), 2)
	// Taking a hit winces; throwing one, or anything else, is effort. A meow's a grin, and confusion's
	// a look to the side.
	var/static/list/faces = list("meow" = "hey", "confused" = "left")
	limb_rig.set_fnf_face(faces[kind] || (findtext(kind, "hit") ? "miss" : "down"), 0.5 + hold)

/// Spins the gun in the free hand round about the hand.
/mob/living/carbon/proc/fnf_spin_guns(mic_arm, style, time, turns = 1)
	limb_rig?.spin_held_item(mic_arm == RIG_L_ARM ? "r" : "l", time, turns)

// Traced animations (traced_anims.dm).

/mob/living
	/// Until when a traced idle is still playing through (see fnf_bop()).
	var/fnf_idle_until = 0

/**
 * A move traced off the sprites of a style's character, as rig keyframes (list(pose, deciseconds,
 * easing)), or null if nobody's traced it. Their left and right swap for a singer facing the other way
 * from the sprite.
 */
/proc/fnf_traced_keyframes(style, anim, facing)
	var/static/list/sheets = list(
		"cpico" = list("corruptedpico", "corruptedpico2"),
		"kapi" = list("corruptedkapi"),
		"gf" = list("corruptedgirlfriendflying"),
		"gf_flying" = list("corruptedgirlfriendflying"),
		"marble" = list("corruptedmarble2", "corruptedmarble"),
	)
	for(var/sheet in sheets[style])
		var/name = anim
		var/sprite_facing = GLOB.fnf_traced_facing[sheet]
		if((sprite_facing == "right" && facing == WEST) || (sprite_facing == "left" && facing == EAST))
			if(anim == "singLEFT")
				name = "singRIGHT"
			else if(anim == "singRIGHT")
				name = "singLEFT"
		var/list/frames = GLOB.fnf_traced_anims[sheet]?[name]
		if(!length(frames))
			continue
		. = list()
		for(var/list/frame as anything in frames)
			. += list(list(frame[1], frame[2], LINEAR_EASING))
		return

/**
 * Corruption+'s cast mostly don't sing into a mic (Kapi dances, Girlfriend floats, corrupted Pico has
 * his gun): whoever's moving as one of them keeps the battle mic, but it isn't drawn.
 */
/mob/living/carbon/proc/fnf_hide_mic(style)
	var/static/list/micless = list("cpico", "kapi", "gf", "gf_flying", "marble")
	limb_rig?.set_hidden_held((style in micless) ? list(/obj/item/fnf_microphone) : null)

/**
 * For someone traced without an idle of their own (flying corrupted Girlfriend), a slow, slight sway
 * about the first pose of their alt idle: leaning in and back, the head and arms drifting with it.
 */
/proc/fnf_traced_sway(style, facing)
	var/list/alt = fnf_traced_keyframes(style, "idle-alt", facing)
	if(!alt)
		return null
	var/list/first = alt[1]
	var/list/base = first[1]
	. = list()
	for(var/way in list(1, -1))
		var/list/swayed = fnf_nudge_pose(base, RIG_CHEST, "bend", 3 * way)
		swayed = fnf_nudge_pose(swayed, RIG_HEAD, "nod", -2 * way)
		for(var/arm in list(RIG_L_ARM, RIG_R_ARM))
			if(swayed[arm])
				swayed = fnf_nudge_pose(swayed, arm, "upper", 4 * way)
				swayed = fnf_nudge_pose(swayed, arm, "lower", 4 * way)
		. += list(list(swayed, 8, SINE_EASING))

/// How long some keyframes take altogether, in deciseconds.
/proc/fnf_keyframes_time(list/keyframes)
	. = 0
	for(var/list/keyframe as anything in keyframes)
		. += keyframe[2]

/**
 * A traced move for a note held hold deciseconds, then back to rest. A long note stutters on the
 * move's first two frames until it's let go, the way Funkin' starts the move over on every bit of a
 * held note, then plays it through.
 */
/proc/fnf_traced_hold(list/keyframes, hold, list/rest)
	. = list()
	var/left = hold - fnf_keyframes_time(keyframes)
	if(length(keyframes) >= 2)
		var/list/first = keyframes[1]
		var/list/second = keyframes[2]
		var/first_time = min(first[2], 0.5)
		var/second_time = min(second[2], 0.5)
		while(left > first_time + second_time)
			. += list(list(first[1], first_time), list(second[1], second_time))
			left -= first_time + second_time
	. += keyframes
	if(left > 0)
		var/list/last = keyframes[length(keyframes)]
		. += list(list(last[1], left))
	. += list(list(rest, 2, SINE_EASING))

/// Where a traced character rests: the first frame of their traced idle, or the usual rest.
/proc/fnf_traced_rest(style, mic_arm, facing)
	var/list/idle = fnf_traced_keyframes(style, "idle", facing)
	if(idle)
		var/list/first = idle[1]
		return first[1]
	return fnf_pose("rest", mic_arm, facing, style)

/// A backup dancer's move for one beat: into one side of the dance, then easing off it.
/mob/living/proc/fnf_dance(beat_time, left)
	fnf_nudge(left ? -2 : 2, -1)

/mob/living/carbon/fnf_dance(beat_time, left)
	if(!limb_rig)
		return ..()
	limb_rig.play(list(
		list(fnf_pose(left ? "dance_left" : "dance_right", RIG_R_ARM, SOUTH, null), beat_time * 0.3, CUBIC_EASING|EASE_OUT),
		list(fnf_scale_pose(fnf_pose(left ? "dance_left" : "dance_right", RIG_R_ARM, SOUTH, null), 0.6), beat_time * 0.7, SINE_EASING),
	), settle_after = FALSE)

/// Lost. Run off the health bar means going down in a heap.
/mob/living/proc/fnf_lose(knocked_out)
	fnf_flash("#6f6fff", 3 SECONDS)
	if(is_species(src, /datum/species/experiment))
		playsound(src, get_expie_pain_sound(), 50, TRUE)
	if(!knocked_out)
		return
	visible_message(span_danger("[src] got blue-balled!"))
	if(iscarbon(src))
		var/mob/living/carbon/loser = src
		loser.limb_rig?.set_fnf_face("dead")
	// A player's game over has them on the floor already; anyone else just drops.
	if(!client)
		Knockdown(3 SECONDS)

/// Back to standing about normally once the battle's over.
/mob/living/proc/fnf_rest()
	return

/mob/living/carbon/fnf_rest()
	limb_rig?.set_hidden_held(null)
	limb_rig?.clear_fnf_face()
	limb_rig?.settle()

/// Adds to one angle of a pose in place, making the entry if it isn't there.
/proc/fnf_pose_add(list/pose, part_id, key, amount)
	var/list/entry = pose[part_id]
	if(!entry)
		entry = list()
		pose[part_id] = entry
	entry[key] = (entry[key] || 0) + amount

/**
 * A summoned character's own way of moving, on top of the shared poses.
 *
 * * pose - the pose so far, changed in place
 * * kind - as for fnf_pose(), with the side arrows already turned into "toward" and "away"
 */
/proc/fnf_apply_style(list/pose, kind, style, mic_arm, free_arm)
	switch(style)
		if("cpico")
			// Corrupted Pico (Corruption+): hunched, the gun held out one-handed, as cool as ever:
			// up at the chest, levelled at the rival, straight out low, up at the sky, or slung back
			// over the shoulder, spun round into aiming it.
			switch(kind)
				if("rest", "bop", "miss")
					pose[free_arm] = list("swing" = 50, "raise" = 10, "elbow" = 55)
				if("toward")
					pose[free_arm] = list("swing" = 85, "raise" = 5, "elbow" = 5)
				if("away")
					pose[free_arm] = list("swing" = 140, "raise" = 10, "elbow" = 120)
				if(1)
					pose[free_arm] = list("swing" = 90, "raise" = 5, "elbow" = 0)
					fnf_pose_add(pose, RIG_L_LEG, "knee", 20)
					fnf_pose_add(pose, RIG_R_LEG, "knee", 20)
				if(2, "hey")
					pose[free_arm] = list("swing" = 165, "raise" = 5, "elbow" = 10)
			fnf_pose_add(pose, RIG_CHEST, "bend", 8)
			fnf_pose_add(pose, RIG_HEAD, "nod", 6)
			fnf_pose_add(pose, RIG_L_LEG, "knee", 12)
			fnf_pose_add(pose, RIG_R_LEG, "knee", 12)
		if("pico", "tankman")
			// The gun's in the free hand, and goes where the note does: levelled at the rival, up at
			// the sky, down at the floor. Pico sings the rival note into the mic and lets the gun talk.
			switch(kind)
				if("rest", "bop", "miss")
					pose[free_arm] = list("swing" = 40, "raise" = 10, "elbow" = 45)
				if("toward")
					pose[free_arm] = list("swing" = 90, "raise" = 5, "elbow" = 0)
					pose[mic_arm] = FNF_MIC_UP
				if("away")
					pose[free_arm] = list("swing" = -35, "raise" = 25, "elbow" = 70)
				if(1)
					pose[free_arm] = list("swing" = 35, "raise" = 5, "elbow" = 0)
				if(2, "hey")
					pose[free_arm] = list("swing" = 175, "raise" = 5, "elbow" = 0)
				if("ugh")
					pose[free_arm] = list("swing" = 20, "raise" = 15, "elbow" = 60)
			if(style == "tankman")
				// Parade-ground stiff: stands up straight whatever he's singing.
				var/list/chest = pose[RIG_CHEST]
				if(chest)
					chest["bend"] = (chest["bend"] || 0) * 0.4
				fnf_pose_add(pose, RIG_HEAD, "nod", -4)
		if("dad", "parents")
			// Rockstar: legs planted wide, headbanging, the mic thrown to the sky on the high notes.
			fnf_pose_add(pose, RIG_L_LEG, "raise", 10)
			fnf_pose_add(pose, RIG_R_LEG, "raise", 10)
			if(kind == "bop" || kind == 1)
				fnf_pose_add(pose, RIG_HEAD, "nod", 14)
				fnf_pose_add(pose, RIG_CHEST, "bend", 8)
			if(kind == 2)
				pose[mic_arm] = list("swing" = 160, "raise" = 10, "elbow" = 5)
		if("mom")
			// Swaying her hips into every note.
			fnf_pose_add(pose, RIG_CHEST, "lean", kind == "away" ? -8 : 8)
			fnf_pose_add(pose, RIG_HEAD, "tilt", kind == "away" ? 8 : -8)
			if(kind == "bop")
				fnf_pose_add(pose, RIG_CHEST, "bend", -4)
		if("spooky")
			// Hopping into everything, arms everywhere.
			fnf_pose_add(pose, RIG_CHEST, "air", 5)
			fnf_pose_add(pose, mic_arm, "raise", 30)
			fnf_pose_add(pose, free_arm, "raise", 45)
			fnf_pose_add(pose, RIG_L_LEG, "knee", 25)
		if("senpai")
			// Far too cool to move much.
			for(var/part_id in pose)
				var/list/entry = pose[part_id]
				for(var/key in entry)
					if(key != "hand_y")
						entry[key] *= 0.55
			fnf_pose_add(pose, RIG_HEAD, "tilt", 10)
		if("monster")
			// Hunched right over, head jerking about.
			fnf_pose_add(pose, RIG_CHEST, "bend", 16)
			fnf_pose_add(pose, RIG_HEAD, "nod", kind == 2 ? -20 : 12)
		if("darnell")
			// Laid back, leaning away, all swagger.
			fnf_pose_add(pose, RIG_CHEST, "bend", -8)
			fnf_pose_add(pose, RIG_HEAD, "nod", -6)
			fnf_pose_add(pose, RIG_L_LEG, "swing", 15)
		// Corruption+'s cast, as the mod animates them.
		if("kapi")
			// Dancing on his arcade's dance pad more than singing: an arm flung up, a stamp, a tucked
			// jump, a knee and fist driven forward, slouching between them, tail going.
			switch(kind)
				if("rest", "bop")
					pose[free_arm] = list("swing" = 5, "raise" = 8, "elbow" = 15)
					fnf_pose_add(pose, RIG_CHEST, "bend", 6)
					fnf_pose_add(pose, RIG_HEAD, "nod", 6)
				if("away")
					pose[free_arm] = list("swing" = 160, "raise" = 40, "elbow" = 30)
					pose[RIG_R_LEG] = list("swing" = 35, "knee" = 60)
					fnf_pose_add(pose, RIG_CHEST, "lean", -6)
				if("toward")
					pose[free_arm] = list("swing" = 90, "raise" = 10, "elbow" = 10)
					pose[RIG_L_LEG] = list("swing" = 60, "knee" = 70)
				if(1)
					pose[RIG_L_LEG] = list("swing" = 75, "knee" = 15)
					pose[RIG_R_LEG] = list("swing" = -5, "knee" = 25)
				if(2)
					pose[RIG_L_LEG] = list("swing" = 55, "knee" = 90)
					pose[RIG_R_LEG] = list("swing" = 55, "knee" = 90)
					fnf_pose_add(pose, RIG_CHEST, "air", 6)
			fnf_pose_add(pose, RIG_TAIL, "wag", kind == "away" ? -18 : 18)
		if("skarlet")
			// All attitude: a hand on her cocked hip, pointing at the rival, a shrug thrown away from them.
			switch(kind)
				if("rest", "bop")
					pose[free_arm] = list("swing" = 10, "raise" = 35, "elbow" = 110)
					fnf_pose_add(pose, RIG_CHEST, "lean", 6)
					fnf_pose_add(pose, RIG_HEAD, "tilt", -6)
				if("toward")
					pose[free_arm] = list("swing" = 95, "raise" = 5, "elbow" = 0)
					pose[mic_arm] = list("swing" = 50, "raise" = 10, "hand_y" = 27)
				if("away")
					pose[free_arm] = list("swing" = 40, "raise" = 40, "elbow" = 60)
					fnf_pose_add(pose, RIG_HEAD, "tilt", 10)
				if(1)
					fnf_pose_add(pose, RIG_HEAD, "nod", 10)
			fnf_pose_add(pose, RIG_CHEST, "bend", -3)
		if("carol", "carol_flying")
			// Shy: the mic held up in both hands, feet together, hardly moving.
			pose[free_arm] = list("swing" = 50, "raise" = 5, "elbow" = 100)
			for(var/part_id in pose)
				var/list/entry = pose[part_id]
				if(part_id == free_arm || part_id == mic_arm)
					continue
				for(var/key in entry)
					if(key != "hand_y")
						entry[key] *= 0.6
			fnf_pose_add(pose, RIG_HEAD, "tilt", 8)
			if(style == "carol_flying")
				// Up on her wings, curled up in the air.
				pose[RIG_L_LEG] = list("swing" = 45, "knee" = 80)
				pose[RIG_R_LEG] = list("swing" = 30, "knee" = 70)
		if("gf", "gf_flying")
			// Corrupted, she sings like she dances: the mic swung out wide, a leg kicked up on the high
			// notes, a hand on her hip in between. Flying, her legs dangle.
			switch(kind)
				if("rest", "bop")
					pose[free_arm] = list("swing" = 10, "raise" = 35, "elbow" = 110)
				if("toward", "away")
					pose[mic_arm] = list("swing" = 85, "raise" = 35, "elbow" = 40)
					pose[free_arm] = list("swing" = 20, "raise" = 30, "elbow" = 100)
				if(2)
					pose[RIG_L_LEG] = list("swing" = 70, "knee" = 40)
					pose[free_arm] = list("swing" = 165, "raise" = 10, "elbow" = 10)
			if(style == "gf_flying")
				pose[RIG_L_LEG] = list("swing" = 15, "knee" = 30)
				pose[RIG_R_LEG] = list("swing" = -10, "knee" = 20)

#undef FNF_MIC_UP
#undef FNF_FIST
