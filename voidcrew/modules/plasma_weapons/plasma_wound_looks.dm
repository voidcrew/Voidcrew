// Plasma burn looks: the wound's own overlays on the victim.
// _set and _raw sit at tg's DAMAGE_LAYER through COMSIG_ATOM_UPDATE_OVERLAYS (as tg's fire overlay does), so
// clothing covers them like tg's burns. The hot glow is a pair of vis_contents objects over the clothes (one
// visible, one emissive) so it can pulse and cool with animate() instead of a per-tick redraw. No light is cast.

#define PLASMA_WOUND_LOOK_ICON 'voidcrew/modules/plasma_weapons/icons/plasma_wounds.dmi'
/// The sprites are drawn for human-shaped limbs; monkeys and husks show none.
#define PLASMA_WOUND_LOOK_DRAWS(limb) (limb.dmg_overlay_type == "human")
/// One breath of the glow: 100% -> 62% -> 100% alpha.
#define PLASMA_WOUND_GLOW_PULSE (1.2 SECONDS)
#define PLASMA_WOUND_GLOW_PULSE_ALPHA 160
/// How fast a quench cuts the glow.
#define PLASMA_WOUND_GLOW_QUENCH (0.3 SECONDS)
/// A colour matrix for the glow sprite: keeps `keep` of its own colour, adds its blue channel tinted by
/// tint_r/g/b and adds a flat `add` of white. The fade and the breathing run on the alpha var, not in here.
#define PLASMA_WOUND_GLOW_MATRIX(keep, tint_r, tint_g, tint_b, add_r, add_g, add_b) list(	keep, 0, 0, 	0, keep, 0, 	tint_r, tint_g, keep + tint_b, 	add_r, add_g, add_b)

/datum/wound/burn/flesh/plasma
	/// The visible glow while the slag is hot.
	var/obj/effect/abstract/plasma_wound_glow/look_glow
	/// The emissive twin of the glow, so it shows in the dark.
	var/obj/effect/abstract/plasma_wound_glow_emissive/look_emissive

/// Called by the wound core on every state change.
/datum/wound/burn/flesh/plasma/proc/update_look()
	if(QDELETED(src) || !victim || !limb || !PLASMA_WOUND_LOOK_DRAWS(limb))
		clear_look_glow()
	else if(look_state() == "hot")
		start_look_glow()
	else
		fade_look_glow() // a quench or the end of the cooling
	victim?.update_appearance(UPDATE_OVERLAYS)

/datum/wound/burn/flesh/plasma/set_victim(new_victim)
	var/mob/living/carbon/old_victim = victim
	if(old_victim)
		UnregisterSignal(old_victim, list(COMSIG_ATOM_UPDATE_OVERLAYS, COMSIG_MOVABLE_Z_CHANGED))
		clear_look_glow()
	. = ..()
	if(old_victim && !QDELETED(old_victim))
		old_victim.update_appearance(UPDATE_OVERLAYS)
	if(victim)
		RegisterSignal(victim, COMSIG_ATOM_UPDATE_OVERLAYS, PROC_REF(add_look_overlays))
		RegisterSignal(victim, COMSIG_MOVABLE_Z_CHANGED, PROC_REF(look_z_changed))
		update_look()

/datum/wound/burn/flesh/plasma/set_limb(obj/item/bodypart/new_value, replaced = FALSE)
	. = ..()
	if(victim)
		update_look()

/datum/wound/burn/flesh/plasma/Destroy()
	clear_look_glow()
	return ..()

/// The tier name the sprites use.
/datum/wound/burn/flesh/plasma/proc/look_tier()
	switch(severity)
		if(WOUND_SEVERITY_CRITICAL)
			return "through"
		if(WOUND_SEVERITY_SEVERE)
			return "slag"
	return "spatter"

/// Seconds a fresh wound of this tier stays hot.
/datum/wound/burn/flesh/plasma/proc/look_hot_time()
	switch(severity)
		if(WOUND_SEVERITY_CRITICAL)
			return PLASMA_WOUND_HEAT_CRITICAL
		if(WOUND_SEVERITY_SEVERE)
			return PLASMA_WOUND_HEAT_SEVERE
	return PLASMA_WOUND_HEAT_MODERATE

/datum/wound/burn/flesh/plasma/proc/add_look_overlays(mob/living/carbon/source, list/overlays)
	SIGNAL_HANDLER
	if(!limb || limb.owner != source || !PLASMA_WOUND_LOOK_DRAWS(limb))
		return
	var/kind = (look_state() == "raw") ? "raw" : "set" // hot draws the glass under its glow
	overlays += mutable_appearance(PLASMA_WOUND_LOOK_ICON, "[limb.body_zone]_[look_tier()]_[kind]", -DAMAGE_LAYER)

/datum/wound/burn/flesh/plasma/proc/look_z_changed(datum/source)
	SIGNAL_HANDLER
	if(look_emissive && victim)
		SET_PLANE_EXPLICIT(look_emissive, EMISSIVE_PLANE, victim)

/// Puts the glow on (or re-times it from the current heat) and starts its cooling.
/datum/wound/burn/flesh/plasma/proc/start_look_glow()
	var/glow_state = "[limb.body_zone]_[look_tier()]_glow"
	if(look_glow && look_glow.icon_state != glow_state)
		clear_look_glow()
	if(!look_glow)
		look_glow = new(null, glow_state)
		look_emissive = new(null, glow_state)
		SET_PLANE_EXPLICIT(look_emissive, EMISSIVE_PLANE, victim)
		victim.vis_contents += look_glow
		victim.vis_contents += look_emissive

	var/hot_time = look_hot_time()
	var/left = clamp(heat, 0, hot_time)
	var/done = 1 - left / hot_time

	// The glow flashes pink-white, drops fast to a deep violet and cools through dark plum, fading the whole way.
	// Keys are fractions of the hot time, each a colour matrix over the purple sprite and an alpha.
	// The colours named are what the sprite's brightest pixels come out as.
	var/static/list/ramp_at = list(0, 0.1, 0.22, 0.55, 0.85, 1)
	var/static/list/ramp = list(
		PLASMA_WOUND_GLOW_MATRIX(0.25, 0, 0, 0, 0.75, 0.75, 0.75), // white-hot
		PLASMA_WOUND_GLOW_MATRIX(0.4, 0, 0, 0, 0.6, 0.5, 0.6), // pink-white
		PLASMA_WOUND_GLOW_MATRIX(0, 0.541, 0.122, 0.749, 0, 0, 0), // #8A1FBF
		PLASMA_WOUND_GLOW_MATRIX(0, 0.416, 0.086, 0.627, 0, 0, 0), // #6A16A0
		PLASMA_WOUND_GLOW_MATRIX(0, 0.243, 0.059, 0.361, 0, 0, 0), // #3E0F5C
		PLASMA_WOUND_GLOW_MATRIX(0, 0.243, 0.059, 0.361, 0, 0, 0),
	)
	var/static/list/ramp_alpha = list(255, 242, 226, 165, 90, 0)
	var/key = 1
	while(key < length(ramp_at) && ramp_at[key + 1] <= done)
		key++
	var/list/now
	var/now_alpha
	if(key >= length(ramp_at))
		now = ramp[length(ramp)]
		now_alpha = 0
	else
		var/span = (done - ramp_at[key]) / (ramp_at[key + 1] - ramp_at[key])
		var/list/from_matrix = ramp[key]
		var/list/to_matrix = ramp[key + 1]
		now = list()
		for(var/i in 1 to length(from_matrix))
			now += from_matrix[i] + (to_matrix[i] - from_matrix[i]) * span
		now_alpha = round(ramp_alpha[key] + (ramp_alpha[key + 1] - ramp_alpha[key]) * span)
	// A zero-time first step: a glow the client has not drawn yet would otherwise start from the end of the ramp
	animate(look_glow, color = now, time = 0)
	var/at = done
	for(var/i in (key + 1) to length(ramp_at))
		animate(color = ramp[i], time = max((ramp_at[i] - at) * hot_time * 1 SECONDS, 0))
		at = ramp_at[i]
	// Alpha fades with the ramp and breathes on the way down: each half breath is one step.
	animate(look_glow, alpha = now_alpha, time = 0, flags = ANIMATION_PARALLEL)
	var/left_ds = left * 1 SECONDS
	var/elapsed = 0
	var/dim = TRUE
	while(elapsed < left_ds)
		var/step = min(PLASMA_WOUND_GLOW_PULSE / 2, left_ds - elapsed)
		elapsed += step
		var/fraction = done + (1 - done) * elapsed / left_ds
		var/target = plasma_glow_alpha_at(fraction, ramp_at, ramp_alpha)
		if(dim)
			target = round(target * PLASMA_WOUND_GLOW_PULSE_ALPHA / 255)
		animate(alpha = target, time = step, easing = SINE_EASING)
		dim = !dim

	// The emissive dims steadily with the glow across the whole hot time.
	animate(look_emissive, color = _EMISSIVE_COLOR(1 - done), time = 0)
	animate(color = _EMISSIVE_COLOR(0), time = left * 1 SECONDS)

/// The ramp's alpha at a fraction of the hot time.
/datum/wound/burn/flesh/plasma/proc/plasma_glow_alpha_at(fraction, list/ramp_at, list/ramp_alpha)
	if(fraction >= 1)
		return 0
	for(var/i in 1 to length(ramp_at) - 1)
		if(fraction < ramp_at[i + 1])
			var/span = (fraction - ramp_at[i]) / (ramp_at[i + 1] - ramp_at[i])
			return round(ramp_alpha[i] + (ramp_alpha[i + 1] - ramp_alpha[i]) * span)
	return 0

/// Cuts the glow quickly, as water hitting it would.
/datum/wound/burn/flesh/plasma/proc/fade_look_glow()
	if(!look_glow)
		return
	var/obj/effect/abstract/plasma_wound_glow/glow = look_glow
	var/obj/effect/abstract/plasma_wound_glow_emissive/emissive = look_emissive
	look_glow = null
	look_emissive = null
	animate(glow, alpha = 0, time = PLASMA_WOUND_GLOW_QUENCH)
	animate(emissive, color = _EMISSIVE_COLOR(0), time = PLASMA_WOUND_GLOW_QUENCH)
	QDEL_IN(glow, PLASMA_WOUND_GLOW_QUENCH) // Destroy takes them out of the victim's vis_contents
	QDEL_IN(emissive, PLASMA_WOUND_GLOW_QUENCH)

/datum/wound/burn/flesh/plasma/proc/clear_look_glow()
	if(victim)
		victim.vis_contents -= look_glow
		victim.vis_contents -= look_emissive
	QDEL_NULL(look_glow)
	QDEL_NULL(look_emissive)

/// Hot slag showing over the clothes. Turns and lies down with its wearer.
/obj/effect/abstract/plasma_wound_glow
	name = "glowing slag"
	icon = PLASMA_WOUND_LOOK_ICON
	layer = -HIGHEST_LAYER
	appearance_flags = RESET_COLOR|PIXEL_SCALE|TILE_BOUND
	vis_flags = VIS_INHERIT_DIR | VIS_INHERIT_PLANE | VIS_INHERIT_ID
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/obj/effect/abstract/plasma_wound_glow/Initialize(mapload, glow_state)
	. = ..()
	icon_state = glow_state

/// The emissive mask of the glow, on its own plane so it lights up in the dark.
/obj/effect/abstract/plasma_wound_glow_emissive
	name = "slag glow"
	icon = PLASMA_WOUND_LOOK_ICON
	layer = -HIGHEST_LAYER
	appearance_flags = EMISSIVE_APPEARANCE_FLAGS|PIXEL_SCALE|TILE_BOUND
	vis_flags = VIS_INHERIT_DIR | VIS_INHERIT_ID
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/obj/effect/abstract/plasma_wound_glow_emissive/Initialize(mapload, glow_state)
	. = ..()
	icon_state = glow_state

#undef PLASMA_WOUND_LOOK_ICON
#undef PLASMA_WOUND_LOOK_DRAWS
#undef PLASMA_WOUND_GLOW_PULSE
#undef PLASMA_WOUND_GLOW_PULSE_ALPHA
#undef PLASMA_WOUND_GLOW_QUENCH
#undef PLASMA_WOUND_GLOW_MATRIX
