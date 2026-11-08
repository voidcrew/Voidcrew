/**
 * # Chrome animations
 *
 * Four pieces of motion that sit on top of chrome that already works. None of
 * them changes what the chrome does or when: every proc here only draws, and
 * the mechanics call into it after they have already happened.
 *
 * - Mantis blades swing out of the housing and fold back into it.
 * - The Ghostskin field sweeps down over its bearer, shimmers while it holds,
 *   and collapses inward with a crackle when it breaks.
 * - The Cascade's spine nodes ignite neck to hips, a ring rolls out across the
 *   floor, and the nodes die hips to neck when the crash hits.
 * - An EMP fills every worn piece with static, arcs between them, kills them one
 *   after another, and they blink back on when they reboot.
 *
 * Two ways of drawing, chosen per effect:
 * - One-shot frames ride a holder object in the bearer's vis_contents. A fresh
 *   object always plays its icon state from the first frame, which an overlay
 *   does not, so swings, arcs and sparks are holders that delete themselves.
 * - Anything that must sit at the worn chrome's layer (under suits, gloves and
 *   hands) is a "look" on the worn overlay itself: the bodypart overlay asks
 *   the implant for its look when it draws, and the look is part of the limb's
 *   render key, so a look change is one update_body_parts() away.
 *
 * Nothing here loops on the server. Timers are one-shot and owned by the thing
 * they animate, so they die with it.
 */

#define CYBERWARE_ANIM_ICON 'voidcrew/modules/cyberware/icons/cyberware_anim.dmi'
#define CYBERWARE_ANIM_LARGE_ICON 'voidcrew/modules/cyberware/icons/cyberware_anim_large.dmi'

/// Worn looks. Null is the plain overlay.
#define CHROME_LOOK_STATIC "static"
#define CHROME_LOOK_DARK "dark"
#define CHROME_LOOK_FLASH "flash"
#define CHROME_LOOK_FOLD "fold"

/// Layer for a blade swing: just over the held item it turns into.
#define CHROME_ANIM_BLADE_LAYER (-(HANDS_LAYER - 0.5))
/// Layer for arcs, sparks and crackle: over everything the bearer wears.
#define CHROME_ANIM_TOP_LAYER (-(HIGHEST_LAYER - 0.5))

// =========================================================================
// THE HOLDER
// =========================================================================

/**
 * One short animation drawn on a bearer. Created per use and deleted after
 * its lifetime, so its icon state always starts on the first frame. Inherits
 * the bearer's facing and plane; clicks pass through it.
 */
/obj/effect/abstract/cyberware_anim
	name = "chrome"
	icon = CYBERWARE_ANIM_LARGE_ICON
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	vis_flags = VIS_INHERIT_DIR | VIS_INHERIT_PLANE
	blocks_emissive = EMISSIVE_BLOCK_NONE
	/// What we are drawn on.
	var/atom/movable/bearer

/obj/effect/abstract/cyberware_anim/Destroy()
	detach()
	return ..()

/obj/effect/abstract/cyberware_anim/proc/detach()
	if(!bearer)
		return
	UnregisterSignal(bearer, COMSIG_QDELETING)
	bearer.vis_contents -= src
	bearer = null

/obj/effect/abstract/cyberware_anim/proc/on_bearer_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/**
 * Plays [state] from [icon_file] on [bearer] for [lifetime], then deletes
 * itself. Large-sheet states are 64x64 and get centred on the bearer's tile.
 * [glow] adds an emissive twin, so the frames light up in the dark.
 */
/proc/cyberware_anim_play(atom/movable/bearer, icon_file, state, anim_layer, lifetime, glow = FALSE)
	if(QDELETED(bearer) || !state)
		return null
	var/obj/effect/abstract/cyberware_anim/holder = new(null)
	holder.bearer = bearer
	holder.icon = icon_file
	holder.icon_state = state
	holder.layer = anim_layer
	if(icon_file == CYBERWARE_ANIM_LARGE_ICON)
		holder.pixel_x = -16
		holder.pixel_y = -16
	if(glow)
		holder.add_overlay(emissive_appearance(icon_file, state, bearer))
	holder.RegisterSignal(bearer, COMSIG_QDELETING, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim, on_bearer_deleted))
	bearer.vis_contents += holder
	QDEL_IN(holder, lifetime)
	return holder

// =========================================================================
// WORN LOOKS
// =========================================================================

/// The EMP look the reboot show has put on this piece. Null means "whatever
/// the reboot state says": dark while down, plain otherwise.
/datum/component/cyberware/var/emp_look

/**
 * The look this implant's worn overlay draws with right now, or null for the
 * plain overlay. Read by the bodypart overlay on every draw.
 */
/obj/item/organ/cyberimp/proc/cyberware_worn_look()
	var/datum/component/cyberware/chrome = GetComponent(/datum/component/cyberware)
	if(!chrome)
		return null
	if(chrome.emp_look)
		return chrome.emp_look
	if(chrome.emp_down)
		return CHROME_LOOK_DARK
	return null

/// What this implant adds to its limb's render key, so a look change redraws.
/obj/item/organ/cyberimp/proc/cyberware_worn_key()
	return "[cyberware_worn_look()]"

/**
 * Dresses one implant's freshly built worn images in its current look.
 * Called by /datum/bodypart_overlay/augment/cyberware before it adds
 * emissive blockers, so a see-through image gets a see-through blocker.
 */
/obj/item/organ/cyberimp/proc/cyberware_dress_worn(list/imageset, image_layer, obj/item/bodypart/limb)
	var/look = cyberware_worn_look()
	if(!look)
		return imageset
	var/list/dressed = list()
	for(var/image/part as anything in imageset)
		var/glow = PLANE_TO_TRUE(part.plane) == EMISSIVE_PLANE
		switch(look)
			if(CHROME_LOOK_FOLD)
				// The folded housing waits while the swing plays over it.
				if(glow)
					continue
				part.alpha = 0
			if(CHROME_LOOK_DARK)
				if(glow)
					continue
				part.color = list(0.18, 0.18, 0.2, 0.32, 0.32, 0.34, 0.08, 0.08, 0.1, 0.02, 0.02, 0.03)
			if(CHROME_LOOK_FLASH)
				if(glow)
					continue
				part.color = list(0.55, 0, 0, 0, 0.55, 0, 0, 0, 0.55, 0.42, 0.5, 0.55)
				dressed += part
				dressed += emissive_appearance(part.icon, part.icon_state, limb?.owner || limb, part.layer)
				continue
			if(CHROME_LOOK_STATIC)
				if(!glow)
					// Static clipped to the piece's own pixels.
					part.appearance_flags |= KEEP_TOGETHER
					var/mutable_appearance/noise = mutable_appearance('icons/effects/effects.dmi', "static_base", alpha = 170)
					noise.blend_mode = BLEND_INSET_OVERLAY
					part.overlays += noise
		dressed += part
	return dressed

// =========================================================================
// MANTIS BLADES: UNFOLD AND FOLD
// =========================================================================

/// How long the blade swings out before the held blade takes over.
#define BLADE_UNFOLD_SWING (0.3 SECONDS)
/// The whole unfold, last sparks included.
#define BLADE_UNFOLD_TIME (0.4 SECONDS)
/// How long the folded housing waits while the blade folds back in.
#define BLADE_FOLD_SWING (0.3 SECONDS)
/// The whole fold, last sparks included.
#define BLADE_FOLD_TIME (0.5 SECONDS)

/obj/item/organ/cyberimp/arm/toolkit/cyberware
	/// The swing playing on the bearer right now, if any. Weak: it deletes itself.
	var/datum/weakref/blade_anim_ref
	/// Until this world.time the folded housing is drawn see-through.
	var/fold_hide_until = 0
	/// Timer that brings the folded housing back.
	var/fold_timer
	/// Colour of the flash at the hinge when the blade swings.
	var/blade_flash_color = "#bfe6ff"
	/// One hinge flash at a time, however fast the blade is toggled.
	COOLDOWN_DECLARE(blade_flash_cooldown)

/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/street
	blade_flash_color = "#e8e0c8"

/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/scorch
	blade_flash_color = "#ffb070"

/obj/item/organ/cyberimp/arm/toolkit/cyberware/cyberware_worn_look()
	if(world.time < fold_hide_until)
		return CHROME_LOOK_FOLD
	return ..()

/// The swing state for this housing, or null when the sheet has none.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/proc/blade_anim_state(kind)
	var/state = "[aug_overlay]_[kind]_[zone == BODY_ZONE_L_ARM ? "left" : "right"]"
	return icon_exists(CYBERWARE_ANIM_LARGE_ICON, state) ? state : null

/// The swing playing on the bearer right now, if any.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/proc/blade_anim()
	return blade_anim_ref?.resolve()

/// Stops any swing and brings the folded housing back if it was waiting.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/proc/stop_blade_anim()
	qdel(blade_anim())
	blade_anim_ref = null
	if(fold_timer)
		deltimer(fold_timer)
		fold_timer = null
	fold_hide_until = 0

/// The blade swings out of the housing. Called once the blade is in a hand.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/proc/play_blade_unfold(obj/item/blade)
	var/state = blade_anim_state("unfold")
	if(!state || !owner)
		return
	stop_blade_anim()
	blade_anim_ref = WEAKREF(cyberware_anim_play(owner, CYBERWARE_ANIM_LARGE_ICON, state, CHROME_ANIM_BLADE_LAYER, BLADE_UNFOLD_TIME))
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/held_blade = blade
	if(istype(held_blade))
		held_blade.hide_inhand_for(BLADE_UNFOLD_SWING)
	blade_flash(0.7, BLADE_UNFOLD_SWING)

/**
 * The blade folds back into the housing. Called once it is stowed; the
 * folded housing stays see-through until the swing has played.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/proc/play_blade_fold()
	var/state = blade_anim_state("fold")
	if(!state || !owner)
		return
	stop_blade_anim()
	blade_anim_ref = WEAKREF(cyberware_anim_play(owner, CYBERWARE_ANIM_LARGE_ICON, state, CHROME_ANIM_BLADE_LAYER, BLADE_FOLD_TIME))
	fold_hide_until = world.time + BLADE_FOLD_SWING
	fold_timer = addtimer(CALLBACK(src, PROC_REF(end_fold_hide)), BLADE_FOLD_SWING, TIMER_STOPPABLE)
	blade_flash(0.5, BLADE_FOLD_SWING)

/// A brief light at the hinge while the blade swings.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/proc/blade_flash(power, duration)
	if(!COOLDOWN_FINISHED(src, blade_flash_cooldown))
		return
	COOLDOWN_START(src, blade_flash_cooldown, duration)
	owner.mob_light(1.5, power, blade_flash_color, duration)

/obj/item/organ/cyberimp/arm/toolkit/cyberware/proc/end_fold_hide()
	fold_timer = null
	fold_hide_until = 0
	owner?.update_body_parts()

/obj/item/melee/energy/blade/hardlight/cyberware_mantis
	/// Until this world.time the blade is not drawn in the hand: the swing is.
	var/inhand_hidden_until = 0

/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/hide_inhand_for(duration)
	inhand_hidden_until = world.time + duration
	var/mob/holder = loc
	if(ismob(holder))
		holder.update_held_items()
	addtimer(CALLBACK(src, PROC_REF(show_inhand)), duration, TIMER_UNIQUE | TIMER_OVERRIDE)

/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/show_inhand()
	if(!inhand_hidden_until)
		return
	inhand_hidden_until = 0
	var/mob/holder = loc
	if(ismob(holder))
		holder.update_held_items()

// The blade is in the hand from the first tick; only its drawing waits.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/build_worn_icon(default_layer = 0, default_icon_file = null, isinhands = FALSE, female_uniform = NO_FEMALE_UNIFORM, override_state = null, override_file = null)
	. = ..()
	if(isinhands && world.time < inhand_hidden_until)
		var/mutable_appearance/standing = .
		standing.alpha = 0

#undef BLADE_UNFOLD_SWING
#undef BLADE_UNFOLD_TIME
#undef BLADE_FOLD_SWING
#undef BLADE_FOLD_TIME

// =========================================================================
// GHOSTSKIN FIELD
// =========================================================================

#define CLOAK_MASK_FILTER "cyberware_cloak_mask"
#define CLOAK_BAND_FILTER "cyberware_cloak_band"
#define CLOAK_RIM_FILTER "cyberware_cloak_rim"
#define CLOAK_WAVE_FILTER "cyberware_cloak_wave"
#define CLOAK_RIPPLE_FILTER "cyberware_cloak_ripple"
/// How long the field takes to sweep down over its bearer.
#define CLOAK_SWEEP_TIME (1 SECONDS)
/// Mask offsets: the front starts just over the head and ends under the feet,
/// then the mask is moved clear of the bearer.
#define CLOAK_FRONT_START 45
#define CLOAK_FRONT_END 5
#define CLOAK_FRONT_AWAY 200
/// The refraction line rides one pixel under the front: from just over the
/// head (pixel_y 2) to under the feet (pixel_y -38) on a 64x64 holder.
#define CLOAK_EDGE_START 2
#define CLOAK_EDGE_END -38
/// When the crackle follows the inward collapse of a breaking field.
#define CLOAK_CRACKLE_DELAY (0.2 SECONDS)

/obj/item/organ/cyberimp/cyberware/ghostskin
	/// world.time the sweep finishes. The moving shimmer waits for it.
	var/cloak_sweep_until = 0
	/// Timer that swaps the sweep for the held shimmer.
	var/cloak_settle_timer
	/// Timer that clears the inward ripple after a break.
	var/cloak_ripple_timer
	/// Timer for the crackle that follows the collapse.
	var/cloak_crackle_timer
	/// The refraction line sweeping down with the field. Weak: it deletes itself.
	var/datum/weakref/cloak_edge_ref
	/// Who carries our filters.
	var/datum/weakref/cloak_fx_ref

/// The sweep mask for a field alpha, built once per alpha value.
/proc/cyberware_cloak_mask(field_alpha)
	var/static/list/masks = list()
	var/key = "[field_alpha]"
	if(!masks[key])
		var/icon/mask = icon(CYBERWARE_ANIM_LARGE_ICON, "cloak_mask")
		mask.ChangeOpacity((255 - field_alpha) / 255)
		masks[key] = mask
	return masks[key]

/**
 * Raises the field visually: the bearer stays solid while a mask sweeps down
 * over them, then drops to field alpha the moment the sweep ends. The alpha
 * var holds field_alpha from the first tick, as it always has; only the
 * picture takes the second.
 */
/obj/item/organ/cyberimp/cyberware/ghostskin/proc/cloak_sweep_in(mob/living/carbon/wearer)
	clear_cloak_fx()
	cloak_fx_ref = WEAKREF(wearer)
	cloak_sweep_until = world.time + CLOAK_SWEEP_TIME
	animate(wearer, alpha = 255, time = CLOAK_SWEEP_TIME)
	animate(alpha = field_alpha, time = 0)
	wearer.add_filters(list(
		list("name" = CLOAK_MASK_FILTER, "priority" = 20, "params" = alpha_mask_filter(y = CLOAK_FRONT_START, icon = cyberware_cloak_mask(field_alpha), flags = MASK_INVERSE)),
		list("name" = CLOAK_BAND_FILTER, "priority" = 21, "params" = displacement_map_filter(icon = icon(CYBERWARE_ANIM_LARGE_ICON, "cloak_band"), y = CLOAK_FRONT_START, size = 2)),
	))
	for(var/filter_name in list(CLOAK_MASK_FILTER, CLOAK_BAND_FILTER))
		animate(wearer.get_filter(filter_name), y = CLOAK_FRONT_END, time = CLOAK_SWEEP_TIME)
		animate(y = CLOAK_FRONT_AWAY, time = 0)
		// A rebuild of the bearer's filters mid-sweep lands on the end state, not the start.
		wearer.filter_data[filter_name]["y"] = CLOAK_FRONT_AWAY
	// A pale line on the front, inset so it only lights the bearer's own pixels.
	var/obj/effect/abstract/cyberware_anim/edge = cyberware_anim_play(wearer, CYBERWARE_ANIM_LARGE_ICON, "cloak_edge", CHROME_ANIM_TOP_LAYER, CLOAK_SWEEP_TIME)
	if(edge)
		edge.blend_mode = BLEND_INSET_OVERLAY
		edge.pixel_y = CLOAK_EDGE_START
		animate(edge, pixel_y = CLOAK_EDGE_END, time = CLOAK_SWEEP_TIME)
		cloak_edge_ref = WEAKREF(edge)
	cloak_settle_timer = addtimer(CALLBACK(src, PROC_REF(cloak_settle)), CLOAK_SWEEP_TIME, TIMER_STOPPABLE)

/// The sweep is done: drop its filters and leave the shimmer and a faint rim.
/obj/item/organ/cyberimp/cyberware/ghostskin/proc/cloak_settle()
	cloak_settle_timer = null
	var/mob/living/carbon/wearer = cloak_fx_ref?.resolve()
	if(!camo_active || QDELETED(wearer))
		return
	wearer.remove_filter(list(CLOAK_MASK_FILTER, CLOAK_BAND_FILTER))
	// The rim fades with the bearer, so it is drawn bright for a faint result.
	var/rim_alpha = clamp(round(40 * 255 / max(field_alpha, 1)), 40, 255)
	var/rim_bright = rgb(216, 244, 255, rim_alpha)
	var/rim_dim = rgb(216, 244, 255, round(rim_alpha * 0.7))
	wearer.add_filters(list(
		list("name" = CLOAK_RIM_FILTER, "priority" = 22, "params" = outline_filter(1, rim_bright)),
		list("name" = CLOAK_WAVE_FILTER, "priority" = 23, "params" = wave_filter(x = 0, y = 8, size = 1.2, offset = 0, flags = WAVE_SIDEWAYS)),
	))
	var/wave = wearer.get_filter(CLOAK_WAVE_FILTER)
	animate(wave, offset = 1, time = 0.8 SECONDS, loop = -1)
	animate(offset = 0, time = 0)
	var/rim = wearer.get_filter(CLOAK_RIM_FILTER)
	animate(rim, color = rim_dim, time = 0.8 SECONDS, loop = -1, easing = SINE_EASING)
	animate(color = rim_bright, time = 0.8 SECONDS, easing = SINE_EASING)

/**
 * The field is down: clear its filters and, unless it went quietly, collapse
 * it inward with a crackle. The fade back to full view is break_camo()'s own.
 */
/obj/item/organ/cyberimp/cyberware/ghostskin/proc/cloak_break_fx(mob/living/carbon/wearer, silent)
	clear_cloak_fx()
	if(silent || QDELETED(wearer))
		return
	cloak_fx_ref = WEAKREF(wearer)
	wearer.add_filter(CLOAK_RIPPLE_FILTER, 24, ripple_filter(radius = 26, size = 2.2, falloff = 0.6, repeat = 5, y = -2))
	animate(wearer.get_filter(CLOAK_RIPPLE_FILTER), radius = 3, size = 0, time = 0.3 SECONDS)
	wearer.filter_data[CLOAK_RIPPLE_FILTER]["radius"] = 3
	wearer.filter_data[CLOAK_RIPPLE_FILTER]["size"] = 0
	cloak_ripple_timer = addtimer(CALLBACK(src, PROC_REF(clear_cloak_fx)), 0.35 SECONDS, TIMER_STOPPABLE)
	// The field folds in on itself first, then crackles out.
	cloak_crackle_timer = addtimer(CALLBACK(src, PROC_REF(cloak_crackle), WEAKREF(wearer)), CLOAK_CRACKLE_DELAY, TIMER_STOPPABLE)

/obj/item/organ/cyberimp/cyberware/ghostskin/proc/cloak_crackle(datum/weakref/wearer_ref)
	cloak_crackle_timer = null
	var/mob/living/carbon/wearer = wearer_ref?.resolve()
	if(QDELETED(wearer))
		return
	cyberware_anim_play(wearer, 'icons/effects/effects.dmi', "lightning", CHROME_ANIM_TOP_LAYER, 0.5 SECONDS, glow = TRUE)
	wearer.mob_light(2, 0.8, "#9fdcff", 0.5 SECONDS)

/// Takes every field filter off whoever carries them and stops the field's timers.
/obj/item/organ/cyberimp/cyberware/ghostskin/proc/clear_cloak_fx()
	if(cloak_settle_timer)
		deltimer(cloak_settle_timer)
		cloak_settle_timer = null
	if(cloak_ripple_timer)
		deltimer(cloak_ripple_timer)
		cloak_ripple_timer = null
	if(cloak_crackle_timer)
		deltimer(cloak_crackle_timer)
		cloak_crackle_timer = null
	qdel(cloak_edge_ref?.resolve())
	cloak_edge_ref = null
	cloak_sweep_until = 0
	var/mob/living/carbon/wearer = cloak_fx_ref?.resolve()
	cloak_fx_ref = null
	if(!QDELETED(wearer))
		wearer.remove_filter(list(CLOAK_MASK_FILTER, CLOAK_BAND_FILTER, CLOAK_RIM_FILTER, CLOAK_WAVE_FILTER, CLOAK_RIPPLE_FILTER))

#undef CLOAK_MASK_FILTER
#undef CLOAK_BAND_FILTER
#undef CLOAK_RIM_FILTER
#undef CLOAK_WAVE_FILTER
#undef CLOAK_RIPPLE_FILTER
#undef CLOAK_SWEEP_TIME
#undef CLOAK_FRONT_START
#undef CLOAK_FRONT_END
#undef CLOAK_FRONT_AWAY
#undef CLOAK_EDGE_START
#undef CLOAK_EDGE_END
#undef CLOAK_CRACKLE_DELAY

// =========================================================================
// CASCADE: SPINE NODES AND THE TIME RING
// =========================================================================

/// Time between node frames.
#define CASCADE_NODE_STEP (0.1 SECONDS)
/// When the ring rolls out: as the last node lights.
#define CASCADE_RING_DELAY (0.45 SECONDS)

/obj/item/organ/cyberimp/cyberware/cascade
	/// The spine node frame drawn over the lattice, or null for the plain one.
	var/node_look
	/// Node frames still to play, in order.
	var/list/node_queue
	/// Timer for the next node frame.
	var/node_timer
	/// Timer for the floor ring.
	var/ring_timer
	/// How far the ring rolls out (transform scale of a two-tile ring).
	var/ring_scale = 3.3
	/// How bright the ring starts.
	var/ring_alpha = 235
	/// How long the ring takes to roll out and fade.
	var/ring_time = 0.65 SECONDS

/obj/item/organ/cyberimp/cyberware/cascade/milspec
	ring_scale = 2.7
	ring_alpha = 190
	ring_time = 0.55 SECONDS

/obj/item/organ/cyberimp/cyberware/cascade/street
	ring_scale = 2.2
	ring_alpha = 140
	ring_time = 0.45 SECONDS

/obj/item/organ/cyberimp/cyberware/cascade/cyberware_worn_key()
	return "[..()]-[node_look]"

/obj/item/organ/cyberimp/cyberware/cascade/cyberware_dress_worn(list/imageset, image_layer, obj/item/bodypart/limb)
	if(cyberware_worn_look() || !node_look)
		return ..()
	var/state = "[aug_overlay]_[node_look]"
	if(!icon_exists(CYBERWARE_ANIM_ICON, state))
		return imageset
	// The node frame replaces the lattice's own idle glow.
	var/list/dressed = list()
	for(var/image/part as anything in imageset)
		if(PLANE_TO_TRUE(part.plane) == EMISSIVE_PLANE)
			continue
		dressed += part
	dressed += image(icon = CYBERWARE_ANIM_ICON, icon_state = state, layer = image_layer)
	dressed += emissive_appearance(CYBERWARE_ANIM_ICON, "[state]_e", limb?.owner || limb, image_layer)
	return dressed

/// Plays node frames one after another, then holds the last.
/obj/item/organ/cyberimp/cyberware/cascade/proc/play_node_looks(list/looks)
	if(node_timer)
		deltimer(node_timer)
		node_timer = null
	node_queue = looks.Copy()
	advance_node_look()

/obj/item/organ/cyberimp/cyberware/cascade/proc/advance_node_look()
	node_timer = null
	if(!length(node_queue))
		return
	node_look = popleft(node_queue)
	owner?.update_body_parts()
	if(length(node_queue))
		node_timer = addtimer(CALLBACK(src, PROC_REF(advance_node_look)), CASCADE_NODE_STEP, TIMER_STOPPABLE)

/// Back to the plain lattice, no frames pending, no ring on the way.
/obj/item/organ/cyberimp/cyberware/cascade/proc/clear_node_looks(mob/living/carbon/redraw)
	if(node_timer)
		deltimer(node_timer)
		node_timer = null
	if(ring_timer)
		deltimer(ring_timer)
		ring_timer = null
	node_queue = null
	if(isnull(node_look))
		return
	node_look = null
	redraw?.update_body_parts()

/// The window opens: nodes ignite neck to hips, then the ring rolls out.
/obj/item/organ/cyberimp/cyberware/cascade/proc/play_window_open()
	if(!owner)
		return
	play_node_looks(list("boot1", "boot2", "boot3", "boot4", "boot5", "lit"))
	if(ring_timer)
		deltimer(ring_timer)
	ring_timer = addtimer(CALLBACK(src, PROC_REF(roll_ring)), CASCADE_RING_DELAY, TIMER_STOPPABLE)

/obj/item/organ/cyberimp/cyberware/cascade/proc/roll_ring()
	ring_timer = null
	var/turf/here = get_turf(owner)
	if(here)
		new /obj/effect/temp_visual/cyberware_time_ring(here, ring_scale, ring_alpha, ring_time)

/// The crash: nodes die hips to neck and stay dark.
/obj/item/organ/cyberimp/cyberware/cascade/proc/play_crash()
	if(!owner)
		return
	if(ring_timer)
		deltimer(ring_timer)
		ring_timer = null
	play_node_looks(list("crash1", "crash2", "crash3", "crash4", "crash5", "dead"))

/// The lattice in the bearer's OS slot, if it is a Cascade.
/proc/cyberware_bearer_lattice(mob/living/bearer)
	if(!iscarbon(bearer))
		return null
	var/mob/living/carbon/carbon_bearer = bearer
	var/obj/item/organ/cyberimp/cyberware/cascade/lattice = carbon_bearer.get_organ_slot(ORGAN_SLOT_CYBERWARE_OS)
	return istype(lattice) ? lattice : null

/// Hook for the window's on_apply().
/proc/cyberware_cascade_window_fx(mob/living/bearer)
	cyberware_bearer_lattice(bearer)?.play_window_open()

/// Hook for the window's on_remove(), after it has (or hasn't) applied the crash.
/proc/cyberware_cascade_window_end_fx(mob/living/bearer)
	var/obj/item/organ/cyberimp/cyberware/cascade/lattice = cyberware_bearer_lattice(bearer)
	if(lattice && !bearer.has_status_effect(/datum/status_effect/cyberware_cascade_crash))
		lattice.clear_node_looks(bearer)

/// Hook for the crash's on_apply().
/proc/cyberware_cascade_crash_fx(mob/living/bearer)
	cyberware_bearer_lattice(bearer)?.play_crash()

/// Hook for the crash's on_remove().
/proc/cyberware_cascade_crash_end_fx(mob/living/bearer)
	cyberware_bearer_lattice(bearer)?.clear_node_looks(bearer)

/// The floor ring that rolls out when a Cascade window opens.
/obj/effect/temp_visual/cyberware_time_ring
	icon = CYBERWARE_ANIM_LARGE_ICON
	icon_state = "time_ring"
	pixel_x = -16
	pixel_y = -16
	layer = ABOVE_OPEN_TURF_LAYER
	plane = FLOOR_PLANE
	randomdir = FALSE
	duration = 0.65 SECONDS

/obj/effect/temp_visual/cyberware_time_ring/Initialize(mapload, max_scale = 3.3, peak_alpha = 235, ring_time = 0.65 SECONDS)
	duration = ring_time
	. = ..()
	add_overlay(emissive_appearance(icon, icon_state, src))
	transform = matrix().Scale(0.2)
	alpha = peak_alpha
	animate(src, transform = matrix().Scale(max_scale), time = duration, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)
	animate(src, alpha = 0, time = duration, easing = QUAD_EASING | EASE_IN, flags = ANIMATION_PARALLEL)

#undef CASCADE_NODE_STEP
#undef CASCADE_RING_DELAY

// =========================================================================
// EMP ON CHROME
// =========================================================================

/// From the hit to the first piece going dark.
#define EMP_SHOW_FIRST_DEATH (0.55 SECONDS)
/// Between one piece going dark and the next.
#define EMP_SHOW_DEATH_STAGGER (0.2 SECONDS)
/// How long the arcs crackle.
#define EMP_SHOW_ARC_TIME (0.8 SECONDS)
/// Most arcs drawn at once.
#define EMP_SHOW_MAX_ARCS 3

/**
 * The EMP picture for one bearer. Each worn piece hit in a burst fills with
 * static, arcs jump between the pieces, and they go dark one after another;
 * the mechanical reboot timing is untouched, only the picture staggers. When a
 * piece comes back it blinks bright, dark, then on.
 *
 * Looks live on each piece's cyberware component (emp_look), and clearing
 * them always falls back to the right picture for the reboot state, so
 * deleting this at any point leaves the bearer drawn correctly.
 */
/datum/component/chrome_emp_show
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Pieces in the burst that have not gone dark yet.
	var/list/datum/weakref/crackling = list()
	/// Pieces whose look this show has set, so it can take them back off.
	var/list/datum/weakref/touched = list()
	/// When the current burst started; a later hit starts a new one.
	var/burst_started = -1
	/// Pieces scheduled to go dark in the current burst.
	var/burst_deaths = 0
	/// Holders this show is playing.
	var/list/obj/effect/abstract/cyberware_anim/holders = list()
	/// Steps still to run. At zero the show deletes itself.
	var/pending = 0
	/// The current blink batch: pieces that rebooted on the same tick.
	var/list/datum/weakref/blink_batch
	/// When the current blink batch started.
	var/blink_started = -1

/datum/component/chrome_emp_show/Initialize()
	if(!iscarbon(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/chrome_emp_show/RegisterWithParent()
	RegisterSignal(parent, COMSIG_LIVING_DEATH, PROC_REF(on_death))

/datum/component/chrome_emp_show/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_LIVING_DEATH)

/datum/component/chrome_emp_show/Destroy()
	var/list/playing = holders.Copy()
	holders.Cut()
	QDEL_LIST(playing)
	var/mob/living/carbon/bearer = parent
	var/changed = FALSE
	for(var/datum/weakref/piece_ref as anything in touched)
		var/obj/item/organ/piece = piece_ref.resolve()
		var/datum/component/cyberware/chrome = piece?.GetComponent(/datum/component/cyberware)
		if(chrome?.emp_look)
			chrome.emp_look = null
			changed = TRUE
	touched.Cut()
	crackling.Cut()
	if(changed && !QDELETED(bearer))
		bearer.update_body_parts()
	return ..()

/datum/component/chrome_emp_show/proc/on_death(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// The show for [bearer], made if there isn't one.
/proc/chrome_emp_show_for(mob/living/carbon/bearer)
	if(!iscarbon(bearer) || QDELETED(bearer) || bearer.stat == DEAD)
		return null
	return bearer.GetComponent(/datum/component/chrome_emp_show) || bearer.AddComponent(/datum/component/chrome_emp_show)

/// Worn chrome only: the show draws on the worn overlay.
/proc/chrome_emp_show_wants(obj/item/organ/piece)
	var/obj/item/organ/cyberimp/implant = piece
	return istype(implant) && implant.bodypart_aug && implant.owner

/// Region name a piece arcs from, matching the arc sheet.
/proc/chrome_emp_region(obj/item/organ/piece)
	switch(piece.zone)
		if(BODY_ZONE_R_ARM)
			return "arm_r"
		if(BODY_ZONE_L_ARM)
			return "arm_l"
		if(BODY_ZONE_R_LEG, BODY_ZONE_L_LEG)
			return "legs"
	return "chest"

/// Hook for start_emp_reboot(): the piece was just knocked offline.
/proc/cyberware_emp_hit_fx(obj/item/organ/piece)
	if(!chrome_emp_show_wants(piece))
		return
	var/datum/component/chrome_emp_show/show = chrome_emp_show_for(piece.owner)
	if(show)
		show.hit(piece)
	else
		// No show on a corpse: just draw the piece dark.
		piece.owner.update_body_parts()

/// Hook for finish_emp_reboot(): the piece is back online.
/proc/cyberware_emp_reboot_fx(obj/item/organ/piece)
	if(!chrome_emp_show_wants(piece))
		return
	var/datum/component/chrome_emp_show/show = chrome_emp_show_for(piece.owner)
	if(show)
		show.blink(piece)
	else
		piece.owner.update_body_parts()

/datum/component/chrome_emp_show/proc/set_look(obj/item/organ/piece, look)
	var/datum/component/cyberware/chrome = piece.GetComponent(/datum/component/cyberware)
	if(!chrome)
		return
	chrome.emp_look = look
	touched |= WEAKREF(piece)

/// A piece is hit: static now, dark on its turn.
/datum/component/chrome_emp_show/proc/hit(obj/item/organ/piece)
	var/datum/weakref/piece_ref = WEAKREF(piece)
	if(burst_started != world.time && !length(crackling))
		// A fresh burst. Everything hit this tick joins it; the crackle starts next tick.
		burst_started = world.time
		burst_deaths = 0
		pending++
		addtimer(CALLBACK(src, PROC_REF(start_burst)), 0)
	set_look(piece, CHROME_LOOK_STATIC)
	crackling |= piece_ref
	var/dies_at = burst_started + EMP_SHOW_FIRST_DEATH + EMP_SHOW_DEATH_STAGGER * burst_deaths
	burst_deaths++
	pending++
	addtimer(CALLBACK(src, PROC_REF(piece_dies), piece_ref), max(dies_at - world.time, 0.5))

/// The tick after the hit: show the static, throw the arcs, shake the bearer.
/datum/component/chrome_emp_show/proc/start_burst()
	var/mob/living/carbon/bearer = parent
	bearer.update_body_parts()
	var/list/regions = list()
	for(var/datum/weakref/piece_ref as anything in crackling)
		var/obj/item/organ/piece = piece_ref.resolve()
		if(piece?.owner == bearer)
			regions |= chrome_emp_region(piece)
	sortTim(regions, GLOBAL_PROC_REF(cmp_text_asc))
	var/list/arcs = list()
	if(length(regions) == 1)
		arcs += "chrome_arc_[regions[1]]"
	else
		for(var/i in 1 to length(regions) - 1)
			arcs += "chrome_arc_[regions[i]]_[regions[i + 1]]"
		if(length(regions) >= 3)
			arcs += "chrome_arc_[regions[1]]_[regions[length(regions)]]"
	for(var/i in 1 to min(length(arcs), EMP_SHOW_MAX_ARCS))
		add_holder(cyberware_anim_play(bearer, CYBERWARE_ANIM_LARGE_ICON, arcs[i], CHROME_ANIM_TOP_LAYER, EMP_SHOW_ARC_TIME, glow = TRUE))
	bearer.do_jitter_animation(0)
	var/turf/here = get_turf(bearer)
	if(here)
		new /obj/effect/temp_visual/emp(here)
	step_done()

/// One piece's turn to go dark, with a spark where it dies.
/datum/component/chrome_emp_show/proc/piece_dies(datum/weakref/piece_ref)
	crackling -= piece_ref
	var/obj/item/organ/piece = piece_ref.resolve()
	var/mob/living/carbon/bearer = parent
	if(piece?.owner == bearer)
		var/datum/component/cyberware/chrome = piece.GetComponent(/datum/component/cyberware)
		if(chrome?.emp_look == CHROME_LOOK_STATIC)
			chrome.emp_look = null
			bearer.update_body_parts()
			add_holder(cyberware_anim_play(bearer, CYBERWARE_ANIM_LARGE_ICON, "chrome_spark_[chrome_emp_region(piece)]", CHROME_ANIM_TOP_LAYER, 0.2 SECONDS, glow = TRUE))
	step_done()

/// A piece is back: bright, dark, bright, on. Pieces back on the same tick blink together.
/datum/component/chrome_emp_show/proc/blink(obj/item/organ/piece)
	crackling -= WEAKREF(piece)
	if(blink_started != world.time)
		blink_started = world.time
		blink_batch = list()
		var/list/batch = blink_batch
		pending += 3
		addtimer(CALLBACK(src, PROC_REF(blink_step), batch, CHROME_LOOK_DARK), 0.5)
		addtimer(CALLBACK(src, PROC_REF(blink_step), batch, CHROME_LOOK_FLASH), 2)
		addtimer(CALLBACK(src, PROC_REF(blink_step), batch, null), 2.5)
	blink_batch |= WEAKREF(piece)
	set_look(piece, CHROME_LOOK_FLASH)
	var/mob/living/carbon/bearer = parent
	bearer.update_body_parts()

/datum/component/chrome_emp_show/proc/blink_step(list/batch, look)
	var/mob/living/carbon/bearer = parent
	for(var/datum/weakref/piece_ref as anything in batch)
		var/obj/item/organ/piece = piece_ref.resolve()
		var/datum/component/cyberware/chrome = piece?.GetComponent(/datum/component/cyberware)
		// A piece hit again mid-blink belongs to the new burst now.
		if(!chrome || piece.owner != bearer || chrome.emp_down)
			continue
		chrome.emp_look = look
	bearer.update_body_parts()
	step_done()

/datum/component/chrome_emp_show/proc/add_holder(obj/effect/abstract/cyberware_anim/holder)
	if(!holder)
		return
	holders += holder
	RegisterSignal(holder, COMSIG_QDELETING, PROC_REF(on_holder_deleted))

/datum/component/chrome_emp_show/proc/on_holder_deleted(datum/source)
	SIGNAL_HANDLER
	holders -= source

/datum/component/chrome_emp_show/proc/step_done()
	pending--
	if(pending <= 0 && !length(crackling))
		qdel(src)

#undef EMP_SHOW_FIRST_DEATH
#undef EMP_SHOW_DEATH_STAGGER
#undef EMP_SHOW_ARC_TIME
#undef EMP_SHOW_MAX_ARCS

// =========================================================================
// CLEANUP
// =========================================================================

/**
 * Takes every animation this organ is running off [old_owner] and resets its
 * looks. Called when the chrome leaves a body and when it is deleted.
 */
/obj/item/organ/proc/cyberware_anim_clear(mob/living/carbon/old_owner)
	var/datum/component/cyberware/chrome = GetComponent(/datum/component/cyberware)
	if(chrome)
		chrome.emp_look = null

/obj/item/organ/cyberimp/arm/toolkit/cyberware/cyberware_anim_clear(mob/living/carbon/old_owner)
	. = ..()
	stop_blade_anim()
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade in contents)
		blade.inhand_hidden_until = 0

/obj/item/organ/cyberimp/cyberware/ghostskin/cyberware_anim_clear(mob/living/carbon/old_owner)
	. = ..()
	clear_cloak_fx()

/obj/item/organ/cyberimp/cyberware/cascade/cyberware_anim_clear(mob/living/carbon/old_owner)
	. = ..()
	clear_node_looks()

#undef CYBERWARE_ANIM_ICON
#undef CYBERWARE_ANIM_LARGE_ICON
#undef CHROME_LOOK_STATIC
#undef CHROME_LOOK_DARK
#undef CHROME_LOOK_FLASH
#undef CHROME_LOOK_FOLD
#undef CHROME_ANIM_BLADE_LAYER
#undef CHROME_ANIM_TOP_LAYER
