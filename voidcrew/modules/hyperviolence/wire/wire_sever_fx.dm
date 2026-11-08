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

/// Which way a limb in `zone` falls away from a body facing `facing`: -1 to screen left, 1 to screen right.
/proc/wire_limb_side(zone, facing)
	switch(facing)
		if(EAST)
			return 1
		if(WEST)
			return -1
		if(NORTH)
			return (zone == BODY_ZONE_R_ARM || zone == BODY_ZONE_R_LEG) ? 1 : -1
	return (zone == BODY_ZONE_R_ARM || zone == BODY_ZONE_R_LEG) ? -1 : 1

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
	ghost.dress(victim, limb)
	ghost.bearer = victim
	ghost.RegisterSignal(victim, COMSIG_QDELETING, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim, on_bearer_deleted))
	victim.vis_contents += ghost
	ghost.slide_timer = addtimer(CALLBACK(ghost, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim/wire_ghost, slide)), WIRE_CUT_DELAY, TIMER_STOPPABLE)
	// Whatever happens to the body meanwhile, it never outlives its beat.
	QDEL_IN(ghost, WIRE_CUT_DELAY + WIRE_SLIDE_TIME + WIRE_FALL_TIME + 0.3 SECONDS)
	return ghost

/// Builds the picture: the limb as the body drew it, with the clothes over it cut to its shape.
/obj/effect/abstract/cyberware_anim/wire_ghost/proc/dress(mob/living/carbon/victim, obj/item/bodypart/limb)
	icon = null
	layer = WIRE_GHOST_LAYER
	var/mob/living/carbon/human/dressed = ishuman(victim) ? victim : null
	var/reshaped = dressed && dressed.mob_height != HUMAN_HEIGHT_MEDIUM
	// The dropped form carries its bruising and burns, which the body draws on a layer of its own.
	for(var/image/part_image in limb.get_limb_icon(TRUE, victim))
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

/// The severed limb on the floor stays unseen until this lands, then fades in where this falls.
/obj/effect/abstract/cyberware_anim/wire_ghost/proc/hold_severed(obj/item/bodypart/severed)
	if(QDELETED(severed) || !isturf(severed.loc))
		return
	severed_ref = WEAKREF(severed)
	var/mob/living/body = bearer
	// A dropped limb draws itself shifted to the middle of its tile (px_x, px_y); undo that, so it lies
	// where the held one falls: a few pixels out from where it was, down by the feet.
	severed.pixel_x = wire_limb_side(zone, body ? body.dir : SOUTH) * 3 - severed.px_x
	severed.pixel_y = -4 - severed.px_y
	// The server value is 255 from here on; only the picture waits.
	severed.alpha = 0
	animate(severed, alpha = 0, time = WIRE_CUT_DELAY + WIRE_SLIDE_TIME)
	animate(alpha = 255, time = WIRE_FALL_TIME)
	severed.alpha = 255

/// The limb leaves: it slides along the cut, turns, falls and fades. The stump shows, and the blood goes.
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
	var/side = wire_limb_side(zone, victim.dir)
	var/matrix/turned = matrix()
	turned.Turn(side * 20)
	var/matrix/fallen = matrix()
	fallen.Turn(side * 45)
	animate(src, pixel_w = side * 2, pixel_z = -1, transform = turned, time = WIRE_SLIDE_TIME, easing = EASE_IN)
	animate(pixel_w = side * 3, pixel_z = -4, transform = fallen, alpha = 0, time = WIRE_FALL_TIME, easing = EASE_IN)
	if(!seared)
		victim.hv_wire_spray(spray_dir, 2)
	QDEL_IN(src, WIRE_SLIDE_TIME + WIRE_FALL_TIME)

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
	smoke.layer = WIRE_FX_LAYER
	var/particles/smoke/steam/mild/puff = new
	var/side = wire_limb_side(zone, victim.dir)
	var/arm = (zone == BODY_ZONE_L_ARM || zone == BODY_ZONE_R_ARM)
	puff.position = list(side * 6, arm ? 4 : -6, 0)
	smoke.particles = puff
	smoke.bearer = victim
	smoke.RegisterSignal(victim, COMSIG_QDELETING, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim, on_bearer_deleted))
	victim.vis_contents += smoke
	addtimer(CALLBACK(smoke, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim/wire_smoke, stop_smoking)), WIRE_ARC_SMOKE_TIME - 1 SECONDS)
	QDEL_IN(smoke, WIRE_ARC_SMOKE_TIME)

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
