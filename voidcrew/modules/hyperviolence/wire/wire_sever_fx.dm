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
 * - The through-cut: a fan of drops from each of the two bodies. Its line is the lash's own (wire_lash_through()).
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
	/// A far arm in profile: drawn as the near arm of a body facing the other way, flipped back
	var/mirrored = FALSE
	/// Copies of what the body wore over the limb (uniform, suit, gloves or shoes) when it was cut, uncut
	var/list/worn
	/// The other foot's shoe, still drawn on while the leg is held: tg takes both shoes off with a leg
	var/obj/effect/abstract/cyberware_anim/kept_shoe

/obj/effect/abstract/cyberware_anim/wire_ghost/Destroy()
	if(slide_timer)
		deltimer(slide_timer)
		slide_timer = null
	cut_at = null
	severed_ref = null
	worn = null
	QDEL_NULL(kept_shoe)
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
	ghost.keep_other_shoe(victim)
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
	var/arm = (zone == BODY_ZONE_L_ARM || zone == BODY_ZONE_R_ARM)
	if(wire_limb_far(zone, victim.dir))
		// A far limb is behind the body, so it goes under all of it until it falls clear. Visual contents don't sort
		// among their body's own overlays; as an underlay it is under every one of them.
		layer = FLOAT_LAYER
		vis_flags |= VIS_UNDERLAY
		// Side on, the body hides a far arm all but a sliver. It is drawn as the near arm of a body facing the other
		// way, flipped back, as the severed arm on the floor is (hold_severed()), so the arm that falls is the one
		// that lands.
		if(arm)
			mirrored = TRUE
			vis_flags &= ~VIS_INHERIT_DIR
			dir = REVERSE_DIR(victim.dir)
			transform = matrix(-1, 0, 0, 0, 1, 0)
	else
		layer = WIRE_GHOST_LAYER
	var/mob/living/carbon/human/dressed = ishuman(victim) ? victim : null
	var/reshaped = dressed && dressed.mob_height != HUMAN_HEIGHT_MEDIUM
	// A clean cut: no bruising (tg draws it as a dither the clothes normally hide). A seared limb shows burns.
	var/list/parts = limb.get_limb_icon(TRUE, victim)
	for(var/image/part_image in parts)
		if(part_image.layer == -DAMAGE_LAYER)
			parts -= part_image
	if(seared)
		parts += image('icons/mob/effects/dam_mob.dmi', "[limb.dmg_overlay_type]_[zone]_0[max(limb.burnstate, 2)]", -DAMAGE_LAYER)
	for(var/image/part_image in parts)
		if(PLANE_TO_TRUE(part_image.plane) == EMISSIVE_PLANE)
			continue
		if(reshaped)
			dressed.apply_height_filters(part_image)
		overlays += part_image
	if(!dressed || (dressed.bodyshape & (BODYSHAPE_MONKEY | BODYSHAPE_DIGITIGRADE)))
		return
	worn = wire_worn_over(dressed, arm ? list(UNIFORM_LAYER, SUIT_LAYER, GLOVES_LAYER) : list(UNIFORM_LAYER, SUIT_LAYER, SHOES_LAYER))
	for(var/mutable_appearance/clothes as anything in wire_dress_limb(worn, "limb_[zone]", "ghost [REF(src)]"))
		overlays += clothes

/// Copies of the overlays `body` wears at `layers` (UNIFORM_LAYER and so on), as they are now. list(layer = copy)
/proc/wire_worn_over(mob/living/carbon/human/body, list/layers)
	. = list()
	for(var/index in layers)
		var/mutable_appearance/worn_overlay = body.overlays_standing[index]
		if(istype(worn_overlay))
			.["[index]"] = new /mutable_appearance(worn_overlay)

/**
 * One picture of the `worn` overlays (from wire_worn_over()) cut to the shape of a limb: `mask_state` in the sleeve
 * masks. `key` names its mask; no two pictures on screen at once may share one. Null if nothing is worn.
 */
/proc/wire_cut_clothes(list/worn, mask_state, key)
	if(!length(worn))
		return null
	var/mutable_appearance/clothes = mutable_appearance(appearance_flags = KEEP_TOGETHER)
	for(var/index in worn)
		clothes.overlays += worn[index]
	// Built as tg builds the missing-hand glove mask (update_worn_gloves()), and the sleeve mask: an atom's appearance
	// carries the render target. A mutable_appearance carrying one draws nothing through the filter. A new atom for
	// each picture: one shared atom given a second picture's target for the same limb took the first one's mask away,
	// and that picture drew nothing (a cut leg's trouser, made just before its shoe's picture).
	var/atom/movable/cutout = new(null)
	cutout.icon = HV_SLEEVE_MASK_ICON
	cutout.icon_state = mask_state
	cutout.render_target = "*wire_cut [key] [mask_state]"
	clothes.overlays += cutout
	clothes.add_filter("wire_cut_clothes", 0, alpha_mask_filter(render_source = cutout.render_target))
	qdel(cutout)
	return clothes

/**
 * The `worn` overlays cut to a limb's shape (wire_cut_clothes()), layered as tg layers them on a body: the jumpsuit
 * under the hand, the suit, gloves and shoes over it. Side on, a jumpsuit has cloth behind the hand that would
 * otherwise cover it. list() if nothing is worn.
 */
/proc/wire_dress_limb(list/worn, mask_state, key)
	. = list()
	var/uniform_key = "[UNIFORM_LAYER]"
	var/list/over = worn.Copy()
	if(worn[uniform_key])
		over -= uniform_key
		var/mutable_appearance/under = wire_cut_clothes(list("[UNIFORM_LAYER]" = worn[uniform_key]), mask_state, "[key] under")
		under.layer = -UNIFORM_LAYER
		. += under
	var/mutable_appearance/rest = wire_cut_clothes(over, mask_state, "[key] over")
	if(rest)
		. += rest

/// The leg's own shoe goes with the leg, but tg takes the other one off too. It stays drawn on its foot until the leg
/// slides off.
/obj/effect/abstract/cyberware_anim/wire_ghost/proc/keep_other_shoe(mob/living/carbon/victim)
	if(!worn || !worn["[SHOES_LAYER]"] || (zone != BODY_ZONE_L_LEG && zone != BODY_ZONE_R_LEG))
		return
	var/other = zone == BODY_ZONE_L_LEG ? BODY_ZONE_R_LEG : BODY_ZONE_L_LEG
	if(!victim.get_bodypart(other))
		return
	var/mutable_appearance/shoe = wire_cut_clothes(list("[SHOES_LAYER]" = worn["[SHOES_LAYER]"]), "limb_[other]", "shoe [REF(src)]")
	if(!shoe)
		return
	kept_shoe = new(null)
	kept_shoe.icon = null
	// Over the body, and under the held leg if that is the near one.
	kept_shoe.layer = WIRE_GHOST_LAYER - 0.05
	kept_shoe.overlays += shoe
	kept_shoe.bearer = victim
	kept_shoe.RegisterSignal(victim, COMSIG_QDELETING, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim, on_bearer_deleted))
	victim.vis_contents += kept_shoe

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
	// It keeps the sleeve, trouser leg or shoe it was cut with. tg took both shoes off; the pair lies beside it
	// (hold_shoes()), as the other foot's.
	if(worn)
		severed.hv_wire_dressing = wire_dress_limb(worn, "limb_[zone]", "limb [REF(severed)]")
		severed.update_icon_dropped()
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

/// Shoes lying by a cut leg are drawn at this scale: tg's shoe on the floor is as big as a leg.
#define WIRE_SHOE_SCALE 0.6

/**
 * The shoe tg pulls off a leg that comes away goes with the leg: unseen until the leg lands, then lying on the floor
 * just past it, not hanging in the air at the hip where tg drops it.
 */
/obj/effect/abstract/cyberware_anim/wire_ghost/proc/hold_shoes(obj/item/shoes)
	if(QDELETED(shoes) || !isturf(shoes.loc))
		return
	var/mob/living/body = bearer
	// By the foot end of the leg as it lies (wire_limb_rest()), not the hip end.
	var/list/spot = lying ? list(side * 12, -9) : list(side * 6, -13)
	if(body)
		var/matrix/shape = body.transform
		spot = list(shape.a * spot[1] + shape.b * spot[2] + shape.c + body.pixel_x, shape.d * spot[1] + shape.e * spot[2] + shape.f + body.pixel_y)
	shoes.pixel_x = round(spot[1])
	shoes.pixel_y = round(spot[2])
	// tg draws a shoe on the floor as big as a leg. These lie by a cut leg at the leg's scale.
	shoes.transform = matrix(WIRE_SHOE_SCALE, 0, 0, 0, WIRE_SHOE_SCALE, 0)
	shoes.RegisterSignal(shoes, COMSIG_MOVABLE_MOVED, TYPE_PROC_REF(/obj/item, wire_show_shoes), override = TRUE)
	shoes.alpha = 0
	animate(shoes, alpha = 0, time = WIRE_CUT_DELAY + WIRE_SLIDE_TIME + WIRE_FALL_TIME)
	animate(alpha = 255, time = 0.5)

/// Shoes that came off with a cut leg, once moved: drawn as any item.
/obj/item/proc/wire_show_shoes()
	SIGNAL_HANDLER
	UnregisterSignal(src, COMSIG_MOVABLE_MOVED)
	animate(src, alpha = 255, time = 0)
	transform = matrix()
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

/obj/item/bodypart
	/// The sleeve or trouser leg a wire cut this limb off with, drawn on it while it lies severed (wire_dress_limb())
	var/list/hv_wire_dressing

/obj/item/bodypart/update_icon_dropped()
	. = ..()
	if(!length(hv_wire_dressing) || owner)
		return
	// Shifted as get_limb_icon()'s pieces are, to sit on the limb.
	for(var/mutable_appearance/piece as anything in hv_wire_dressing)
		var/mutable_appearance/dressing = new(piece)
		dressing.pixel_w += px_x
		dressing.pixel_z += px_y
		add_overlay(dressing)

// Back on a body, it wears that body's clothes again.
/obj/item/bodypart/try_attach_limb(mob/living/carbon/new_limb_owner, special, lazy)
	. = ..()
	if(.)
		hv_wire_dressing = null

/// A limb cut clean by a wire: no bruising on the picture of it. Only the picture; its damage is as it was.
/obj/item/bodypart/proc/wire_clean_look()
	brutestate = 0
	update_icon_dropped()

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
	// The other shoe is off now, as it has been since the cut.
	QDEL_NULL(kept_shoe)
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
	if(mirrored)
		// Flipped first, then moved, as the arm on the floor is.
		var/list/poses = list(slid, tipping, rest)
		for(var/i in 1 to length(poses))
			var/matrix/flipped = matrix(-1, 0, 0, 0, 1, 0)
			flipped.Multiply(poses[i])
			poses[i] = flipped
		slid = poses[1]
		tipping = poses[2]
		rest = poses[3]
	animate(src, transform = slid, time = WIRE_SLIDE_TIME, easing = SINE_EASING | EASE_IN)
	animate(transform = tipping, time = WIRE_FALL_TIME / 2, easing = QUAD_EASING | EASE_IN)
	animate(transform = rest, time = WIRE_FALL_TIME / 2, easing = QUAD_EASING | EASE_IN)
	// Down: the limb on the floor takes over.
	animate(alpha = 0, time = 0.5)
	// The blood starts now, as the limb leaves: a short spray from the stump and a drop falling under it.
	if(!seared)
		victim.hv_wire_spray(spray_dir, 2, zone)
		wire_stump_drip(victim, zone, side)
	QDEL_IN(src, WIRE_SLIDE_TIME + WIRE_FALL_TIME + 0.1 SECONDS)

/// The drop under a fresh stump leaves it this long after the limb starts to slide, as the stump shows...
#define WIRE_STUMP_DRIP_WAIT 1
/// ...and falls for this long (both in deciseconds, as the drop's flight is given).
#define WIRE_STUMP_DRIP_FALL 2

/// A drop of blood falls from a fresh stump and lands on the floor under it: where the feet stand on a body standing
/// (not at the foot of the tile, where it would sit on the head of anyone standing below), at the stump of one lying.
/// Side on, it lands clear of the feet, away from the limb that fell to `side`: under them, it shows past the legs as a
/// red bar. From a limb on the far side it falls behind the body.
/proc/wire_stump_drip(mob/living/carbon/victim, zone, side = 1)
	var/turf/floor = get_turf(victim)
	if(!floor || isgroundlessturf(floor) || !floor.has_gravity() || victim.can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
		return
	var/list/spot = wire_zone_point(victim, zone)
	var/start_x = spot[1]
	var/start_y = spot[2]
	var/land_x
	var/land_y
	var/behind = FALSE
	if(victim.body_position == LYING_DOWN)
		// Down already: it only runs off the stump onto the floor.
		land_x = clamp(spot[1], -12, 12)
		land_y = clamp(spot[2], -12, 12)
		start_x = land_x
		start_y = land_y + 3
	else
		// On the floor at the feet: higher, it shows through the gap a leg leaves as a blot at the hip.
		land_x = (victim.dir & (EAST | WEST)) ? victim.pixel_x - side * 9 : clamp(spot[1], -12, 12)
		land_y = -13
		behind = wire_limb_far(zone, victim.dir)
	new /obj/effect/temp_visual/wire_blood_drop(floor, list(start_x, start_y, land_x, land_y, 1, WIRE_STUMP_DRIP_FALL, WIRE_STUMP_DRIP_WAIT, behind), wire_blood_color(victim), victim.get_blood_dna_list(), victim.get_static_viruses())

#undef WIRE_STUMP_DRIP_WAIT
#undef WIRE_STUMP_DRIP_FALL

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
	// Gone as the limb slides: its last frame left behind would hang in the air where the limb was.
	cyberware_anim_play(victim, WIRE_GORE_ICON, "wire_cut_[zone]", WIRE_FX_LAYER, WIRE_CUT_DELAY, glow = TRUE)
	// No blood until the limb comes away.
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(wire_seam_beads), victim, zone), WIRE_CUT_DELAY)

/// The seam beads with blood as the limb slides off it. The beads keep to the body's side of the cut (the stump):
/// past it there is only air now.
/proc/wire_seam_beads(mob/living/carbon/victim, zone)
	if(QDELETED(victim) || victim.get_bodypart(zone) || victim.can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
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
	// Side on, the face is just above a shoulder: the smoke leans back over the shoulders, away from it.
	if(victim.dir & (EAST | WEST))
		var/back = victim.dir == EAST ? -1 : 1
		puff.velocity = list(back * 0.3, 0.15, 0)
		puff.gravity = list(back * 0.12, 0.18)
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

/**
 * The wire of `user` went through `target` and on into `behind`: each throws a short fan of drops the way it went, from
 * where it was cut: the pixel the swing's lash passes on `target` and the one it ends on in `behind`'s chest
 * (wire_through_cuts()). No line of light and no line of blood: that lash runs on to `behind` (wire_lash_through()).
 * `clean`: `target` throws none here, its own cut showing another way (a limb coming off, a crossing cut).
 */
/obj/item/melee/cyberware_monowire/proc/wire_through_fx(mob/living/user, mob/living/target, mob/living/behind, direction, clean = FALSE)
	var/list/cuts = clean ? null : wire_through_cuts(user, target, behind)
	if(!clean)
		target.hv_wire_spray(direction, 2, from = cuts ? cuts[1] : null)
	behind.hv_wire_spray(direction, 2, from = cuts ? cuts[2] : wire_zone_point(behind, BODY_ZONE_CHEST))

#undef WIRE_SHOE_SCALE
