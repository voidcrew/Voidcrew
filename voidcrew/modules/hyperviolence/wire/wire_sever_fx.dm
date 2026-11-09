/**
 * # The Widowline's cut, drawn
 *
 * Visual only: the sever, the sear and the through-cut have already happened (wire_cut.dm) when these run.
 *
 * - The delayed cut. The limb is off at the hit, but for WIRE_CUT_DELAY it is still drawn on its body:
 *   a held copy (the limb's own sprite, plus the jumpsuit, suit, glove or shoe cut to its shape) rides the
 *   body in its vis_contents, over the stump the gore overlays hold back. Then it slides along the cut,
 *   turns, falls and fades while the severed limb on the floor fades in, and the stump shows. The held copy
 *   deletes itself on a hard timer, and with its body; if the limb is back on, or the body was carried off
 *   meanwhile, it just fades.
 * - The seam: a white flash across the limb that cools to the wire's colour and beads with blood, or on a
 *   seared cut glows white to orange to embers, with a little light and smoke.
 * - The through-cut: a line of the wire's light through both bodies, then a line of blood.
 */

/// The colour a body's blood is drawn in, as the gore overlays draw it.
/proc/wire_blood_color(mob/living/bleeder)
	return bleeder.get_bloodtype()?.get_damage_color(bleeder) || BLOOD_COLOR_RED

/// Which way a limb in `zone` falls away from a body facing `facing`, cut by a swing going `swing_dir`:
/// -1 to screen left, 1 to screen right. Seen from the front or back it falls out on its own side; in profile
/// it falls the way the swing carries it, away from the wielder.
/proc/wire_limb_side(zone, facing, swing_dir)
	if(facing == EAST || facing == WEST)
		if(swing_dir & EAST)
			return 1
		if(swing_dir & WEST)
			return -1
		return facing == EAST ? 1 : -1
	if(facing == NORTH)
		return (zone == BODY_ZONE_R_ARM || zone == BODY_ZONE_R_LEG) ? 1 : -1
	return (zone == BODY_ZONE_R_ARM || zone == BODY_ZONE_R_LEG) ? -1 : 1

/// The middle of a human limb in `zone` as a body facing `facing` draws it, in pixels from the middle of the
/// tile. An arm on the far side of a body in profile is hidden, so it is placed as the near one. list(x, y)
/proc/wire_limb_centre(zone, facing)
	var/arm = (zone == BODY_ZONE_L_ARM || zone == BODY_ZONE_R_ARM)
	var/right = (zone == BODY_ZONE_R_ARM || zone == BODY_ZONE_R_LEG)
	var/y = arm ? 0 : -11
	switch(facing)
		if(EAST)
			return list(arm ? -2 : 0, y)
		if(WEST)
			return list(arm ? 2 : 0, y)
		if(NORTH)
			return list(arm ? (right ? 6 : -7) : (right ? 3 : -4), y)
	return list(arm ? (right ? -7 : 6) : (right ? -4 : 3), y)

/**
 * Where a cut limb comes to rest, as a transform for something drawing it with its middle at `centre`. Upright, it
 * has toppled over `side` and lies on the floor beside the feet; off a body already lying down it only slides out a
 * little, since it is on the floor already. For something drawn apart from the body, `body` places and turns it as
 * that body is drawn. A dropped limb shifts its own picture by (`shift_x`, `shift_y`) after any transform, so that
 * is taken back off at the end.
 */
/proc/wire_limb_rest(list/centre, side, lying, mob/living/body, shift_x = 0, shift_y = 0)
	var/list/target = lying ? list(centre[1] + side * 7, centre[2] - 2) : list(side * 10, -13)
	return wire_part_pose(centre, lying ? side * 10 : side * 90, target, body, shift_x, shift_y)

/**
 * A transform that draws a part whose middle is at `centre` turned `turn` degrees about that middle, with the middle
 * at `target` (both in its body's own frame), then placed and turned as `body` is drawn, if given; less a shift
 * the picture applies after its transform.
 */
/proc/wire_part_pose(list/centre, turn, list/target, mob/living/body, shift_x = 0, shift_y = 0)
	var/list/spot = target
	if(body)
		turn += body.body_position == LYING_DOWN ? body.lying_angle : 0
		var/matrix/shape = body.transform
		spot = list(shape.a * target[1] + shape.b * target[2] + shape.c, shape.d * target[1] + shape.e * target[2] + shape.f)
	var/matrix/pose = matrix()
	pose.Translate(-centre[1], -centre[2])
	pose.Turn(turn)
	pose.Translate(spot[1] - shift_x, spot[2] - shift_y)
	return pose

// ---- The held limb ----

/// A severed limb, still drawn on its body for the beat before it slides off.
/obj/effect/abstract/cyberware_anim/wire_ghost
	name = "severed limb"
	appearance_flags = KEEP_TOGETHER | TILE_BOUND | PIXEL_SCALE
	/// The body zone it was cut from
	var/zone
	/// Cut by a hot wire: no blood when it goes
	var/seared = FALSE
	/// Which way the blood goes when it slides off: along the swing
	var/spray_dir
	/// Where the body stood when it was cut. Moved since, and there's no slide.
	var/turf/cut_at
	/// The severed limb lying on the floor
	var/datum/weakref/severed_ref
	/// Timer of the slide
	var/slide_timer
	/// Which way the body faced when it was cut
	var/facing = SOUTH
	/// Which way the limb falls: -1 to screen left, 1 to screen right
	var/side = 1
	/// The body was lying down when it was cut
	var/lying = FALSE

/obj/effect/abstract/cyberware_anim/wire_ghost/Destroy()
	if(slide_timer)
		deltimer(slide_timer)
		slide_timer = null
	cut_at = null
	severed_ref = null
	return ..()

/**
 * Draws `limb` held on `victim` until it slides off. Called while the limb is still attached, since what it
 * draws (the limb and the clothes over it) is read off the body. Returns the held copy, or null.
 */
/proc/wire_ghost_limb(mob/living/carbon/victim, obj/item/bodypart/limb, seared, spray_dir)
	if(QDELETED(victim) || !isturf(victim.loc) || limb?.owner != victim)
		return null
	var/obj/effect/abstract/cyberware_anim/wire_ghost/ghost = new(null)
	ghost.zone = limb.body_zone
	ghost.seared = seared
	ghost.spray_dir = spray_dir
	ghost.cut_at = get_turf(victim)
	ghost.facing = victim.dir
	ghost.side = wire_limb_side(ghost.zone, victim.dir, spray_dir)
	ghost.lying = victim.body_position == LYING_DOWN
	ghost.dress(victim, limb)
	ghost.bearer = victim
	ghost.RegisterSignal(victim, COMSIG_QDELETING, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim, on_bearer_deleted))
	victim.vis_contents += ghost
	ghost.slide_timer = addtimer(CALLBACK(ghost, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim/wire_ghost, slide)), WIRE_CUT_DELAY, TIMER_STOPPABLE)
	// Whatever happens to the body meanwhile, it never outlives its beat.
	QDEL_IN(ghost, WIRE_CUT_DELAY + WIRE_SLIDE_TIME + WIRE_FALL_TIME + 0.3 SECONDS)
	return ghost

/// Whether a limb in `zone` is on the far side of a body facing `facing`, drawn behind its chest: the left arm and
/// leg of a body facing east, the right of one facing west.
/proc/wire_limb_far(zone, facing)
	if(facing == EAST)
		return zone == BODY_ZONE_L_ARM || zone == BODY_ZONE_L_LEG
	if(facing == WEST)
		return zone == BODY_ZONE_R_ARM || zone == BODY_ZONE_R_LEG
	return FALSE

/// Builds the picture: the limb as the body drew it, with the clothes over it cut to its shape.
/obj/effect/abstract/cyberware_anim/wire_ghost/proc/dress(mob/living/carbon/victim, obj/item/bodypart/limb)
	icon = null
	// A far limb stays behind the chest, as the body drew it, until it falls clear.
	layer = wire_limb_far(zone, victim.dir) ? -(BODYPARTS_LOW_LAYER - 0.1) : WIRE_GHOST_LAYER
	var/mob/living/carbon/human/dressed = ishuman(victim) ? victim : null
	var/reshaped = dressed && dressed.mob_height != HUMAN_HEIGHT_MEDIUM
	// The dropped form carries its bruising and burns, which the body draws on a layer of its own.
	// A seared limb shows burns where the cut would have bled.
	var/list/parts = limb.get_limb_icon(TRUE, victim)
	if(seared)
		for(var/image/part_image in parts)
			if(part_image.layer == -DAMAGE_LAYER)
				parts -= part_image
		parts += image('icons/mob/effects/dam_mob.dmi', "[limb.dmg_overlay_type]_[zone]_0[max(limb.burnstate, 2)]", -DAMAGE_LAYER)
	for(var/image/part_image in parts)
		if(PLANE_TO_TRUE(part_image.plane) == EMISSIVE_PLANE)
			continue
		if(reshaped)
			dressed.apply_height_filters(part_image)
		overlays += part_image
	if(!dressed || (dressed.bodyshape & (BODYSHAPE_MONKEY | BODYSHAPE_DIGITIGRADE)))
		return
	var/list/layers = list(UNIFORM_LAYER, SUIT_LAYER)
	layers += (zone == BODY_ZONE_L_ARM || zone == BODY_ZONE_R_ARM) ? GLOVES_LAYER : SHOES_LAYER
	var/mutable_appearance/clothes = mutable_appearance()
	clothes.appearance_flags = KEEP_TOGETHER
	var/found = FALSE
	for(var/index in layers)
		var/mutable_appearance/worn = dressed.overlays_standing[index]
		if(!istype(worn))
			continue
		clothes.overlays += new /mutable_appearance(worn)
		found = TRUE
	if(!found)
		return
	var/mutable_appearance/cutout = mutable_appearance(HV_SLEEVE_MASK_ICON, "limb_[zone]")
	cutout.render_target = "*wire_ghost [REF(src)]"
	clothes.overlays += cutout
	clothes.add_filter("wire_ghost_cutout", 0, alpha_mask_filter(render_source = cutout.render_target))
	overlays += clothes

/**
 * The severed limb on the floor stays unseen until this lands, then shows where this came to rest: facing the way
 * it hung on the body, lying on the floor beside the feet, turned as far as this fell.
 */
/obj/effect/abstract/cyberware_anim/wire_ghost/proc/hold_severed(obj/item/bodypart/severed)
	if(QDELETED(severed) || !isturf(severed.loc))
		return
	severed_ref = WEAKREF(severed)
	var/mob/living/body = bearer
	// A dropped limb is drawn facing south otherwise. An arm on the far side of a body in profile is not drawn at
	// all from that side, so that one lies as the near arm would: the other way round, flipped.
	var/far_arm = (facing == EAST && zone == BODY_ZONE_L_ARM) || (facing == WEST && zone == BODY_ZONE_R_ARM)
	severed.setDir(far_arm ? REVERSE_DIR(facing) : facing)
	var/list/centre = wire_limb_centre(zone, facing)
	// The dropped limb's picture is shifted by (px_x, px_y) to sit mid-tile, after its transform.
	var/matrix/rest = wire_limb_rest(centre, side, lying, body, severed.px_x, severed.px_y)
	if(far_arm)
		var/matrix/flipped = matrix(-1, 0, 0, 0, 1, 0)
		flipped.Multiply(rest)
		rest = flipped
	severed.transform = rest
	severed.pixel_x = body ? body.pixel_x : 0
	severed.pixel_y = body ? body.pixel_y : 0
	severed.pixel_w = body ? body.pixel_w : 0
	severed.pixel_z = body ? body.pixel_z : 0
	// Picked up, kicked or put back on, it is an ordinary limb again.
	severed.RegisterSignal(severed, COMSIG_MOVABLE_MOVED, TYPE_PROC_REF(/obj/item/bodypart, wire_stand_up), override = TRUE)
	// The server value is 255 at once; only the picture waits for the landing.
	severed.alpha = 0
	animate(severed, alpha = 0, time = WIRE_CUT_DELAY + WIRE_SLIDE_TIME + WIRE_FALL_TIME)
	animate(alpha = 255, time = 0.5)

/**
 * The shoe tg pulls off a leg that comes away goes with the leg: unseen until the leg lands, then lying on the floor
 * just past it, not hanging in the air at the hip where tg drops it.
 */
/obj/effect/abstract/cyberware_anim/wire_ghost/proc/hold_shoes(obj/item/shoes)
	if(QDELETED(shoes) || !isturf(shoes.loc))
		return
	var/mob/living/body = bearer
	var/list/spot = lying ? list(side * 14, -8) : list(side * 15, -12)
	if(body)
		var/matrix/shape = body.transform
		spot = list(shape.a * spot[1] + shape.b * spot[2] + shape.c + body.pixel_x, shape.d * spot[1] + shape.e * spot[2] + shape.f + body.pixel_y)
	shoes.pixel_x = round(spot[1])
	shoes.pixel_y = round(spot[2])
	shoes.RegisterSignal(shoes, COMSIG_MOVABLE_MOVED, TYPE_PROC_REF(/obj/item, wire_show_shoes), override = TRUE)
	shoes.alpha = 0
	animate(shoes, alpha = 0, time = WIRE_CUT_DELAY + WIRE_SLIDE_TIME + WIRE_FALL_TIME)
	animate(alpha = 255, time = 0.5)

/// Shoes that came off with a cut leg, once moved: drawn as any item.
/obj/item/proc/wire_show_shoes()
	SIGNAL_HANDLER
	UnregisterSignal(src, COMSIG_MOVABLE_MOVED)
	animate(src, alpha = 255, time = 0)
	pixel_x = base_pixel_x
	pixel_y = base_pixel_y

/// A limb the wire cut, once it is moved: drawn as any dropped limb.
/obj/item/bodypart/proc/wire_stand_up()
	SIGNAL_HANDLER
	UnregisterSignal(src, COMSIG_MOVABLE_MOVED)
	animate(src, alpha = 255, time = 0)
	transform = matrix()
	setDir(SOUTH)
	pixel_x = base_pixel_x
	pixel_y = base_pixel_y
	pixel_w = base_pixel_w
	pixel_z = base_pixel_z

/// A limb cut by a hot wire: burnt, not bloody. Only the picture; its damage is as it was.
/obj/item/bodypart/proc/wire_char()
	brutestate = 0
	burnstate = max(burnstate, 2)
	// The blood it caught coming off is burnt away too. A later wash brings the body's own back, as for any limb.
	var/list/kept = blood_dna_info
	blood_dna_info = null
	wash(CLEAN_TYPE_BLOOD)
	blood_dna_info = kept
	update_icon_dropped()

/// The limb leaves: it slides along the cut, topples and falls to the floor. The stump shows, and the blood goes.
/obj/effect/abstract/cyberware_anim/wire_ghost/proc/slide()
	slide_timer = null
	var/mob/living/carbon/victim = bearer
	if(QDELETED(victim))
		qdel(src)
		return
	victim.hv_reveal_stump(zone)
	if(victim.get_bodypart(zone) || get_turf(victim) != cut_at)
		// Put back on, or carried off: nothing slides, the picture just goes.
		animate(src, alpha = 0, time = 0.1 SECONDS)
		QDEL_IN(src, 0.1 SECONDS)
		return
	// Drawn in its body's own frame, which turns it with a lying body: so no body_shape here.
	var/list/centre = wire_limb_centre(zone, facing)
	var/matrix/slid = matrix()
	slid.Translate(-centre[1], -centre[2])
	slid.Turn(side * (lying ? 4 : 15))
	slid.Translate(centre[1] + side * 2, centre[2] - 1)
	var/matrix/rest = wire_limb_rest(centre, side, lying)
	// Halfway over: the turn is split so it turns rather than squashes on the way.
	var/matrix/tipping = matrix()
	tipping.Translate(-centre[1], -centre[2])
	tipping.Turn(side * (lying ? 7 : 50))
	if(lying)
		tipping.Translate(centre[1] + side * 5, centre[2] - 1)
	else
		tipping.Translate((centre[1] + side * 12) / 2, (centre[2] - 13) / 2)
	animate(src, transform = slid, time = WIRE_SLIDE_TIME, easing = SINE_EASING | EASE_IN)
	animate(transform = tipping, time = WIRE_FALL_TIME / 2, easing = QUAD_EASING | EASE_IN)
	animate(transform = rest, time = WIRE_FALL_TIME / 2, easing = QUAD_EASING | EASE_IN)
	// Down: the limb on the floor takes over.
	animate(alpha = 0, time = 0.5)
	if(!seared)
		victim.hv_wire_spray(spray_dir, 2)
	QDEL_IN(src, WIRE_SLIDE_TIME + WIRE_FALL_TIME + 0.1 SECONDS)

// ---- The seam ----

/// The cut across `zone`: a flash that cools and beads with blood, or a seared seam that glows down to embers.
/proc/wire_seam_fx(mob/living/carbon/victim, zone, seared)
	if(QDELETED(victim))
		return
	if(seared)
		cyberware_anim_play(victim, WIRE_GORE_ICON, "wire_cut_hot_[zone]", WIRE_FX_LAYER, 1.1 SECONDS, glow = TRUE)
		victim.mob_light(1.5, 0.8, "#ff9a3c", 0.6 SECONDS)
		playsound(victim, 'sound/effects/wounds/sizzle1.ogg', 60, TRUE)
		wire_stump_smoke(victim, zone)
		return
	cyberware_anim_play(victim, WIRE_GORE_ICON, "wire_cut_[zone]", WIRE_FX_LAYER, 0.7 SECONDS, glow = TRUE)
	if(victim.can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
		return
	var/obj/effect/abstract/cyberware_anim/beads = cyberware_anim_play(victim, WIRE_GORE_ICON, "wire_cut_blood_[zone]", WIRE_FX_LAYER - 0.1, 0.9 SECONDS)
	if(beads)
		beads.appearance_flags |= RESET_COLOR
		beads.color = wire_blood_color(victim)

/// A seared stump smokes for a few seconds.
/obj/effect/abstract/cyberware_anim/wire_smoke
	name = "smoke"
	icon = null

/obj/effect/abstract/cyberware_anim/wire_smoke/proc/stop_smoking()
	particles?.spawning = 0

/proc/wire_stump_smoke(mob/living/carbon/victim, zone)
	var/obj/effect/abstract/cyberware_anim/wire_smoke/smoke = new(null)
	// On the body, over the stump, not over everything on the tile.
	smoke.layer = WIRE_GHOST_LAYER
	var/particles/smoke/steam/mild/wire_stump/puff = new
	puff.position = wire_stump_joint(zone, victim.dir)
	smoke.particles = puff
	smoke.bearer = victim
	smoke.RegisterSignal(victim, COMSIG_QDELETING, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim, on_bearer_deleted))
	victim.vis_contents += smoke
	addtimer(CALLBACK(smoke, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim/wire_smoke, stop_smoking)), WIRE_ARC_SMOKE_TIME - 1 SECONDS)
	QDEL_IN(smoke, WIRE_ARC_SMOKE_TIME)

/// Where a limb in `zone` joins a body facing `facing` (the shoulder, the hip, the neck), in pixels from the middle
/// of the tile, as the body draws it standing. list(x, y, 0)
/proc/wire_stump_joint(zone, facing)
	if(zone == BODY_ZONE_HEAD)
		return list(0, 6, 0)
	var/list/centre = wire_limb_centre(zone, facing)
	var/arm = (zone == BODY_ZONE_L_ARM || zone == BODY_ZONE_R_ARM)
	return list(centre[1], arm ? 4 : -6, 0)

/// Thin wisps off a seared stump: small, rising slowly from the joint.
/particles/smoke/steam/mild/wire_stump
	scale = 0.4
	grow = 0.02
	spawning = 0.6
	lifespan = 1.2 SECONDS
	fade = 0.8 SECONDS
	velocity = list(0, 0.2, 0)
	gravity = list(0, 0.25)
	drift = generator(GEN_SPHERE, 0, 0.6, NORMAL_RAND)

// ---- Through two bodies ----

/// The line of the wire through `target` and `behind`, and on past them; then the same line in blood.
/obj/item/melee/cyberware_monowire/proc/wire_through_fx(mob/living/target, mob/living/behind, direction)
	var/turf/start = get_turf(target)
	var/turf/target_turf = get_turf(behind)
	if(!start || !target_turf)
		return
	var/turf/finish = get_step(target_turf, direction) || target_turf
	var/dx = (direction & EAST) ? 1 : ((direction & WEST) ? -1 : 0)
	var/dy = (direction & NORTH) ? 1 : ((direction & SOUTH) ? -1 : 0)
	// From half a tile before the target, at chest height.
	start.Beam(finish, icon_state = through_state(), icon = WIRE_GORE_ICON, time = 0.15 SECONDS, override_origin_pixel_x = -dx * 12, override_origin_pixel_y = -dy * 12 + 2, override_target_pixel_y = 2)
	if(behind.can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
		return
	start.Beam(finish, icon_state = "blood_line", icon = WIRE_GORE_ICON, time = 0.7 SECONDS, beam_color = wire_blood_color(behind), emissive = FALSE, override_origin_pixel_x = -dx * 12, override_origin_pixel_y = -dy * 12 + 2, override_target_pixel_y = 2)
	// One streak through both tiles and on.
	if(target.can_bleed(BLOOD_COVER_TURFS) == BLEED_SPLATTER && !isgroundlessturf(start))
		hv_blood_lay_spray(start, /obj/effect/decal/cleanable/blood/hv_spray/streak, direction, target.get_blood_dna_list(), target.get_static_viruses())
	if(!isgroundlessturf(target_turf))
		hv_blood_lay_spray(target_turf, /obj/effect/decal/cleanable/blood/hv_spray/streak, direction, behind.get_blood_dna_list(), behind.get_static_viruses())
	behind.hv_wire_spray(direction, 2)

/obj/item/melee/cyberware_monowire/proc/through_state()
	return "wire_through"

/obj/item/melee/cyberware_monowire/live/through_state()
	return "wire_through_live"
