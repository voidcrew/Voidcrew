// Plasma burn looks: the wound's own overlays on the victim.
// _set and _raw sit at tg's DAMAGE_LAYER through COMSIG_ATOM_UPDATE_OVERLAYS (as tg's fire overlay does), so
// clothing covers them like tg's burns. The hot glow is a pair of vis_contents objects over the clothes (one
// visible, one emissive) so it can pulse and cool with animate() instead of a per-tick redraw. No light is cast.

#define PLASMA_WOUND_LOOK_ICON 'voidcrew/modules/plasma_weapons/icons/plasma_wounds.dmi'
/// The sprites are drawn for human-shaped limbs; monkeys and husks show none.
#define PLASMA_WOUND_LOOK_DRAWS(limb) (limb.dmg_overlay_type == "human")
/// One breath of the glow: 100% -> 72% -> 100% alpha.
#define PLASMA_WOUND_GLOW_PULSE (1.2 SECONDS)
#define PLASMA_WOUND_GLOW_PULSE_ALPHA 184
/// How fast a quench cuts the glow.
#define PLASMA_WOUND_GLOW_QUENCH (0.3 SECONDS)
/// Fraction of the hot time at which the emissive starts to fade out.
#define PLASMA_WOUND_GLOW_FADE_START 0.85

/datum/wound/burn/flesh/plasma
	/// The visible glow while the slag is hot.
	var/obj/effect/abstract/plasma_wound_glow/look_glow
	/// The emissive twin of the glow, so it shows in the dark.
	var/obj/effect/abstract/plasma_wound_glow/emissive/look_emissive

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

	// The glow's colour runs the melt ramp: white-hot, then green, then deep green, then out.
	// Keys are fractions of the hot time, each with a colour multiplier and alpha.
	var/static/list/ramp_at = list(0, 0.3, 0.6, PLASMA_WOUND_GLOW_FADE_START, 1)
	var/static/list/ramp = list(
		list(255, 255, 255, 255),
		list(255, 255, 255, 255),
		list(150, 255, 185, 255),
		list(40, 150, 80, 255),
		list(40, 150, 80, 0),
	)
	var/key = 1
	while(key < length(ramp_at) && ramp_at[key + 1] <= done)
		key++
	var/list/now
	if(key >= length(ramp_at))
		now = ramp[length(ramp)]
	else
		var/span = (done - ramp_at[key]) / (ramp_at[key + 1] - ramp_at[key])
		var/list/from_col = ramp[key]
		var/list/to_col = ramp[key + 1]
		now = list()
		for(var/i in 1 to 4)
			now += round(from_col[i] + (to_col[i] - from_col[i]) * span)
	look_glow.color = rgb(now[1], now[2], now[3], now[4])
	var/first = TRUE
	var/at = done
	for(var/i in (key + 1) to length(ramp_at))
		var/list/col = ramp[i]
		var/step_time = max((ramp_at[i] - at) * hot_time * 1 SECONDS, 0)
		if(first)
			animate(look_glow, color = rgb(col[1], col[2], col[3], col[4]), time = step_time)
			first = FALSE
		else
			animate(color = rgb(col[1], col[2], col[3], col[4]), time = step_time)
		at = ramp_at[i]
	// The slow breathing runs on alpha, alongside the colour.
	animate(look_glow, alpha = PLASMA_WOUND_GLOW_PULSE_ALPHA, time = PLASMA_WOUND_GLOW_PULSE / 2, easing = SINE_EASING, loop = -1, flags = ANIMATION_PARALLEL)
	animate(alpha = 255, time = PLASMA_WOUND_GLOW_PULSE / 2, easing = SINE_EASING)

	// The emissive stays full until the last of the cooling, then fades out with the glow.
	if(done < PLASMA_WOUND_GLOW_FADE_START)
		look_emissive.color = GLOB.emissive_color
		animate(look_emissive, time = (PLASMA_WOUND_GLOW_FADE_START - done) * hot_time * 1 SECONDS)
		animate(color = _EMISSIVE_COLOR(0), time = (1 - PLASMA_WOUND_GLOW_FADE_START) * hot_time * 1 SECONDS)
	else
		look_emissive.color = _EMISSIVE_COLOR((1 - done) / (1 - PLASMA_WOUND_GLOW_FADE_START))
		animate(look_emissive, color = _EMISSIVE_COLOR(0), time = (1 - done) * hot_time * 1 SECONDS)

/// Cuts the glow quickly, as water hitting it would.
/datum/wound/burn/flesh/plasma/proc/fade_look_glow()
	if(!look_glow)
		return
	var/obj/effect/abstract/plasma_wound_glow/glow = look_glow
	var/obj/effect/abstract/plasma_wound_glow/emissive/emissive = look_emissive
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
/obj/effect/abstract/plasma_wound_glow/emissive
	name = "slag glow"
	appearance_flags = EMISSIVE_APPEARANCE_FLAGS|PIXEL_SCALE|TILE_BOUND
	vis_flags = VIS_INHERIT_DIR | VIS_INHERIT_ID

#undef PLASMA_WOUND_LOOK_ICON
#undef PLASMA_WOUND_LOOK_DRAWS
#undef PLASMA_WOUND_GLOW_PULSE
#undef PLASMA_WOUND_GLOW_PULSE_ALPHA
#undef PLASMA_WOUND_GLOW_QUENCH
#undef PLASMA_WOUND_GLOW_FADE_START
