// Pictures for the Mantis line's gore. Nothing here changes who gets hit, when or how hard: the
// mechanics call in after they have happened. One-shot holders and temp visuals only; every animate()
// on a mob here is relative and parallel and ends where it began, so tg's offsets, lying turn and #509's
// death throes stay right. (The impale's hoist, which turns a body upright for the hold, is in
// mantis_impale.dm and gives tg's turn back. The blades going into a body are drawn by the blade rig,
// mantis_rig.dm.)

// =========================================================================
// THE LUNGE
// =========================================================================

/// Whether a dash must stop before [step]: a drop, lava or open space. Never crossed, whatever the reach.
/proc/mantis_lunge_unsafe_turf(turf/step)
	if(isnull(step))
		return TRUE
	return istype(step, /turf/open/chasm) || islava(step) || isspaceturf(step) || istype(step, /turf/open/openspace)

/// A hardlight afterimage left along the dash.
/obj/effect/temp_visual/decoy/fading/mantis_afterimage
	duration = 4

/obj/effect/temp_visual/decoy/fading/mantis_afterimage/Initialize(mapload, atom/mimiced_atom, model, fade = 1)
	. = ..()
	// Washed out to the blade's light, fainter the further back down the line.
	color = model == "mantis_scorch" ? list(0.5, 0.3, 0.15, 0.5, 0.3, 0.15, 0.5, 0.3, 0.15, 0.45, 0.25, 0.1) : list(0.25, 0.35, 0.5, 0.25, 0.35, 0.5, 0.25, 0.35, 0.5, 0.15, 0.3, 0.45)
	alpha = round(200 * fade)
	animate(src, alpha = 0, time = duration)

/// The streak a lunge leaves at blade height across a tile it passed.
/obj/effect/temp_visual/mantis_trail
	icon = MANTIS_GORE_ICON
	icon_state = "mantis_trail"
	layer = ABOVE_MOB_LAYER
	randomdir = FALSE
	duration = 5

/obj/effect/temp_visual/mantis_trail/Initialize(mapload, trail_dir, model)
	. = ..()
	if(model == "mantis_scorch")
		icon_state = "mantis_scorch_trail"
	// The art runs east-west and north-south; a diagonal dash uses the nearer of the two.
	setDir((trail_dir & (EAST|WEST)) ? ((trail_dir & EAST) ? EAST : WEST) : ((trail_dir & NORTH) ? NORTH : SOUTH))
	add_overlay(emissive_appearance(icon, icon_state, src))

/**
 * The dash, drawn after the lunger has already arrived: the body glides in from where it started, and
 * each afterimage and streak shows as the body passes it, so the line trails behind.
 */
/proc/mantis_lunge_dash_fx(mob/living/lunger, turf/start, list/passed, charged, model)
	var/turf/finish = get_turf(lunger)
	if(isnull(finish) || isnull(start) || !length(passed))
		return
	var/dash_dir = get_dir(start, finish)
	var/count = length(passed)
	var/glide = charged ? 2 : MANTIS_LUNGE_GLIDE
	// The body is already there: draw it back where it started and let it slide in.
	var/back_w = (start.x - finish.x) * ICON_SIZE_X
	var/back_z = (start.y - finish.y) * ICON_SIZE_Y
	animate(lunger, pixel_w = back_w, pixel_z = back_z, time = 0, flags = ANIMATION_RELATIVE|ANIMATION_PARALLEL)
	if(charged)
		// A pounce arcs, higher the further it goes.
		var/arc = min(2 * get_dist(start, finish) + 4, 16)
		animate(pixel_w = -back_w * 0.5, pixel_z = -back_z * 0.5 + arc, time = glide * 0.5, easing = SINE_EASING|EASE_OUT, flags = ANIMATION_RELATIVE)
		animate(pixel_w = -back_w * 0.5, pixel_z = -back_z * 0.5 - arc, time = glide * 0.5, easing = SINE_EASING|EASE_IN, flags = ANIMATION_RELATIVE)
		cyberware_grey_dust(start)
	else
		animate(pixel_w = -back_w, pixel_z = -back_z, time = glide, easing = SINE_EASING|EASE_OUT, flags = ANIMATION_RELATIVE)
	var/list/spots = list()
	for(var/turf/spot as anything in passed)
		spots += WEAKREF(spot)
	for(var/i in 1 to count)
		var/delay = round(glide * (i - 1) / count, world.tick_lag)
		if(delay <= 0)
			mantis_dash_ghost(WEAKREF(lunger), spots[i], dash_dir, i / (count + 1), model)
		else
			addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(mantis_dash_ghost), WEAKREF(lunger), spots[i], dash_dir, i / (count + 1), model), delay)

/// One step of the dash's wake: two afterimages half a tile apart and the streak, on the tile the body just crossed.
/proc/mantis_dash_ghost(datum/weakref/lunger_ref, datum/weakref/spot_ref, dash_dir, fade, model)
	var/mob/living/lunger = lunger_ref?.resolve()
	var/turf/spot = spot_ref?.resolve()
	if(QDELETED(lunger) || isnull(spot))
		return
	var/step_x = (dash_dir & EAST) ? 16 : ((dash_dir & WEST) ? -16 : 0)
	var/step_y = (dash_dir & NORTH) ? 16 : ((dash_dir & SOUTH) ? -16 : 0)
	new /obj/effect/temp_visual/decoy/fading/mantis_afterimage(spot, lunger, model, fade * 0.7)
	var/obj/effect/temp_visual/decoy/fading/mantis_afterimage/half = new(spot, lunger, model, fade)
	half.pixel_x += step_x
	half.pixel_y += step_y
	new /obj/effect/temp_visual/mantis_trail(spot, dash_dir, model)

/// The lunge lands: one impact, a flash and a puff of dust, as the gliding body reaches them. A [pounce]
/// lands with both blades, the second mirrored a beat later.
/proc/mantis_lunge_arrival_fx(mob/living/lunger, mob/living/victim, impact_state, pounce = FALSE)
	if(QDELETED(victim))
		return
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(mantis_lunge_land_fx), WEAKREF(lunger), WEAKREF(victim), impact_state, pounce), MANTIS_LUNGE_GLIDE)

/// Knocks [victim] down when the lunging body lands on them, with the impact, rather than as the lunge
/// starts its glide in.
/proc/mantis_lunge_knockdown(mob/living/victim, amount)
	if(QDELETED(victim))
		return
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(mantis_lunge_knockdown_now), WEAKREF(victim), amount), MANTIS_LUNGE_GLIDE)

/proc/mantis_lunge_knockdown_now(datum/weakref/victim_ref, amount)
	var/mob/living/victim = victim_ref?.resolve()
	if(QDELETED(victim))
		return
	victim.Knockdown(amount)

/proc/mantis_lunge_land_fx(datum/weakref/lunger_ref, datum/weakref/victim_ref, impact_state, pounce)
	var/mob/living/lunger = lunger_ref?.resolve()
	var/mob/living/victim = victim_ref?.resolve()
	if(QDELETED(lunger) || QDELETED(victim))
		return
	// Skewered: the blades in them are the picture of this hit.
	if(HAS_TRAIT_FROM(victim, TRAIT_IMMOBILIZED, MANTIS_IMPALE_TRAIT))
		return
	cyberware_play_impact(lunger, victim, impact_state)
	if(pounce)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(mantis_mirrored_impact), lunger_ref, victim_ref, impact_state), 0.4)
	cyberware_flash_fx(victim, 0.2 SECONDS)
	var/obj/effect/temp_visual/mook_dust/dust = cyberware_grey_dust(get_turf(victim))
	if(dust)
		dust.transform = matrix(0.5, 0, 0, 0, 0.5, 0)

/// The second blade's impact, from the other side.
/proc/mantis_mirrored_impact(datum/weakref/lunger_ref, datum/weakref/victim_ref, impact_state)
	var/mob/living/lunger = lunger_ref?.resolve()
	var/mob/living/victim = victim_ref?.resolve()
	if(QDELETED(lunger) || QDELETED(victim))
		return
	// Skewered: the blades in them are the picture of this hit.
	if(HAS_TRAIT_FROM(victim, TRAIT_IMMOBILIZED, MANTIS_IMPALE_TRAIT))
		return
	var/obj/effect/abstract/cyberware_anim/impact = cyberware_play_impact(lunger, victim, impact_state)
	if(impact)
		var/matrix/flipped = matrix(impact.transform)
		flipped.a = -flipped.a
		impact.transform = flipped

// =========================================================================
// THE CUTS
// =========================================================================

/// Where on the body the artery of [zone] is, in pixels up from the middle of the sprite.
/proc/mantis_artery_height(zone)
	switch(zone)
		if(BODY_ZONE_HEAD)
			return 6
		if(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
			return -8
	return 0

/**
 * One heartbeat out of a torn artery: a jet thrown the way the cut went. Drawn upright in the world
 * (it does not lie down with the body), in the blood's own colour.
 */
/proc/mantis_spurt_fx(mob/living/victim, zone, spurt_dir, weak = FALSE)
	if(QDELETED(victim))
		return null
	var/obj/effect/abstract/cyberware_anim/jet = cyberware_anim_play(victim, MANTIS_GORE_LARGE_ICON, "mantis_spurt", MANTIS_ANIM_TOP_LAYER, 0.6 SECONDS)
	if(!jet)
		return null
	jet.vis_flags &= ~VIS_INHERIT_DIR
	jet.appearance_flags |= RESET_TRANSFORM|RESET_COLOR|PIXEL_SCALE
	jet.pixel_x = -16
	jet.pixel_y = -16 + mantis_artery_height(zone)
	jet.color = victim.get_blood_dna_color() || BLOOD_COLOR_RED
	if(weak)
		jet.alpha = 170
	var/matrix/turned = matrix()
	if(spurt_dir & WEST)
		turned.Scale(-1, 1)
	if(spurt_dir == NORTH)
		turned.Turn(-90)
	else if(spurt_dir == SOUTH)
		turned.Turn(90)
	else if(spurt_dir & NORTH)
		turned.Turn((spurt_dir & WEST) ? 35 : -35)
	else if(spurt_dir & SOUTH)
		turned.Turn((spurt_dir & WEST) ? -35 : 35)
	// Straight up or down the arc reads shorter.
	if(spurt_dir == NORTH || spurt_dir == SOUTH)
		turned.Scale(0.75, 0.75)
	if(weak)
		turned.Scale(0.6, 0.6)
	jet.transform = turned
	return jet

/// A Scorch cut: a white-hot seam across the limb that cools to char.
/proc/mantis_scorch_seam_fx(mob/living/carbon/victim, obj/item/bodypart/limb)
	var/state = "scorch_gash_[limb.body_zone]"
	if(!icon_exists(MANTIS_GORE_ICON, state))
		return null
	return cyberware_anim_play(victim, MANTIS_GORE_ICON, state, MANTIS_ANIM_BLADE_LAYER, 1.5 SECONDS, glow = TRUE)

/// The X-slash: both impacts at once, bigger, and a flash of light off the blades.
/proc/mantis_xslash_fx(mob/living/user, mob/living/victim, impact_state)
	if(QDELETED(victim))
		return
	for(var/flip in list(FALSE, TRUE))
		var/obj/effect/abstract/cyberware_anim/impact = cyberware_play_impact(user, victim, impact_state)
		if(!impact)
			continue
		var/matrix/bigger = matrix(impact.transform)
		if(flip)
			bigger.a = -bigger.a
		bigger.Scale(1.4, 1.4)
		impact.transform = bigger
	cyberware_flash_fx(victim, 0.15 SECONDS)
	victim.mob_light(2, 1.5, impact_state == "impact_scorch" ? LIGHT_COLOR_FIRE : "#bfe6ff", 0.2 SECONDS)

// =========================================================================
// IMPALE, SCISSOR, CROUCH
// =========================================================================

/// The way [looker] turns to look at [seen], as face_atom() picks it, whatever state [looker] is in.
/proc/mantis_face_dir(atom/looker, atom/seen)
	var/dx = seen.x - looker.x
	var/dy = seen.y - looker.y
	if(abs(dx) < abs(dy))
		return dy > 0 ? NORTH : SOUTH
	return dx > 0 ? EAST : WEST

/// How [victim] lies, for the scissor's art: "stand", or "lie90"/"lie270" by the way tg has turned them.
/proc/mantis_scissor_posture(mob/living/victim)
	if(victim.body_position != LYING_DOWN || !victim.rotate_on_lying)
		return "stand"
	return victim.lying_angle == 270 ? "lie270" : "lie90"

/// Someone under the raised blades shudders: small sideways jolts, relative, ending where they began.
/proc/mantis_struggle_fx(mob/living/victim, duration)
	if(QDELETED(victim))
		return
	var/static/list/jolts = list(1, -1, 1, 0, -1, 1, -1, 0)
	var/step_time = duration / length(jolts)
	var/offset = 0
	for(var/i in 1 to length(jolts))
		var/shift = jolts[i] - offset
		offset = jolts[i]
		if(i == 1)
			animate(victim, pixel_w = shift, time = step_time, flags = ANIMATION_RELATIVE|ANIMATION_PARALLEL)
		else
			animate(pixel_w = shift, time = step_time, flags = ANIMATION_RELATIVE)

/// The crouched blade's glow, brightening over the charge. Gone with the crouch.
/proc/mantis_coil_glow_fx(mob/living/bearer, obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade)
	var/state = "[blade.base_icon_state]_coil_glow_[blade.hand_side()]"
	if(!icon_exists(MANTIS_GORE_ICON, state))
		return null
	var/obj/effect/abstract/cyberware_anim/glow = cyberware_anim_play(bearer, MANTIS_GORE_ICON, state, MANTIS_ANIM_BLADE_LAYER, MANTIS_CHARGE_MAX_HOLD + 1 SECONDS, glow = TRUE)
	if(!glow)
		return null
	glow.alpha = 0
	animate(glow, alpha = 255, time = MANTIS_CHARGE_FULL - MANTIS_CHARGE_TAP)
	return glow
