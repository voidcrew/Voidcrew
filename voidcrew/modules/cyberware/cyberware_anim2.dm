/**
 * # Chrome animations, second batch
 *
 * More motion on chrome that already works, built the same way as
 * cyberware_anim.dm: every proc here only draws, and the mechanics call into
 * it after they have already happened. Nothing here changes a number, a timer
 * or who gets hit.
 *
 * - Redline Burn: nodes flash white and run red-hot, eyes flood red, a red
 *   halo breathes round the body and the roar rolls a ring across the floor.
 *   The crash vents steam from the back, cools the nodes to grey and slumps
 *   the body a little.
 * - Lazarus Node: a magenta charge crawls over the body through the windup,
 *   then a white jolt, a burst and a little spring as they come up.
 * - Leaps: the Hopper crouches, kicks up dust and arcs over to where it lands,
 *   with a shadow running along the floor under it. The Piledriver glides to
 *   its mark and slams down with a ring and a cracked floor.
 * - Cyberdeck: packets run up the trace, a door glitches when a hack lands on
 *   it, and Ping sweeps a ring out and outlines what answered.
 * - Weapon trails: a Scorch cut leaves an ember crescent; the Widowline Arc
 *   lashes and its lightning crackles along the wire.
 * - Brownout: worn chrome stutters, warms and dims together, and stutters
 *   back on when the load comes off. (The LEDs breathing at rest are part of
 *   the plain worn look in cyberware_anim.dm.)
 * - Chrome cradle: the rig's arms come down on the servo beats, carry the ware
 *   in and sink it, and the patient glitches as it boots.
 *
 * Timers are one-shot and owned by the thing they animate, or global procs
 * holding weak references, so nothing outlives what it draws on.
 */

#define CYBERWARE_ANIM2_ICON 'voidcrew/modules/cyberware/icons/cyberware_anim2.dmi'
#define CYBERWARE_ANIM2_LARGE_ICON 'voidcrew/modules/cyberware/icons/cyberware_anim2_large.dmi'
#define CYBERWARE_ANIM_PING_ICON 'voidcrew/modules/cyberware/icons/cyberware_anim_ping.dmi'
#define CHROME_CRADLE_RIG_ICON 'voidcrew/modules/cyberware/icons/chrome_cradle_rig.dmi'

/// Layer for flashes, arcs and bursts: over everything the bearer wears.
#define CHROME_ANIM2_TOP_LAYER (-(HIGHEST_LAYER - 0.5))

/// Worn looks shared with cyberware_anim.dm.
#define CHROME_LOOK_BROWN "brown"
#define CHROME_LOOK_WARM "warm"

// =========================================================================
// SHARED HELPERS
// =========================================================================

/// Plays a 64x64 state from the batch-2 sheet centred on [bearer].
/proc/cyberware_anim2_play_large(atom/movable/bearer, state, lifetime, glow = TRUE)
	var/obj/effect/abstract/cyberware_anim/holder = cyberware_anim_play(bearer, CYBERWARE_ANIM2_LARGE_ICON, state, CHROME_ANIM2_TOP_LAYER, lifetime, glow)
	if(holder)
		holder.pixel_x = -16
		holder.pixel_y = -16
	return holder

/**
 * A particle emitter riding [bearer] for [lifetime]. It stops making new
 * particles after [emit_time] so the last ones fade out before it goes.
 */
/proc/cyberware_anim_particles(atom/movable/bearer, particles_type, anim_layer, emit_time, lifetime)
	if(QDELETED(bearer))
		return null
	var/obj/effect/abstract/cyberware_anim/holder = new(null)
	holder.bearer = bearer
	holder.icon = null
	holder.layer = anim_layer
	holder.particles = new particles_type
	holder.RegisterSignal(bearer, COMSIG_QDELETING, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim, on_bearer_deleted))
	bearer.vis_contents += holder
	addtimer(CALLBACK(holder, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim, stop_particles)), emit_time)
	QDEL_IN(holder, lifetime)
	return holder

/obj/effect/abstract/cyberware_anim/proc/stop_particles()
	if(particles)
		particles.spawning = 0

/// Grey dust kicked up by a landing or a take-off.
/proc/cyberware_grey_dust(turf/where)
	if(isnull(where))
		return null
	var/obj/effect/temp_visual/mook_dust/dust = new(where)
	dust.color = list(0.45, 0.45, 0.45, 0.45, 0.45, 0.45, 0.2, 0.2, 0.2, 0.33, 0.33, 0.35)
	return dust

#define CHROME_FLASH_FILTER "cyberware_flash"

/// A white flash over [target] that fades back to its own colours.
/proc/cyberware_flash_fx(atom/movable/target, fade_time = 0.25 SECONDS)
	if(QDELETED(target))
		return
	var/static/list/flash = list(0.4, 0, 0, 0, 0, 0.4, 0, 0, 0, 0, 0.4, 0, 0, 0, 0, 1, 0.6, 0.6, 0.62, 0)
	target.add_filter(CHROME_FLASH_FILTER, 43, color_matrix_filter(flash))
	animate(target.get_filter(CHROME_FLASH_FILTER), color = COLOR_MATRIX_IDENTITY, time = fade_time)
	// A rebuild of the target's filters lands on the faded end, not the flash.
	target.filter_data[CHROME_FLASH_FILTER]["color"] = COLOR_MATRIX_IDENTITY
	addtimer(CALLBACK(target, TYPE_PROC_REF(/datum, remove_filter), CHROME_FLASH_FILTER), fade_time + 0.5)

#undef CHROME_FLASH_FILTER

// =========================================================================
// GLITCH (doors, and a patient booting new chrome)
// =========================================================================

#define CHROME_GLITCH_SLICES "cyberware_glitch_slices"
#define CHROME_GLITCH_RED "cyberware_glitch_red"
#define CHROME_GLITCH_CYAN "cyberware_glitch_cyan"

/**
 * Tears [target] into shifted slices with a red and cyan fringe and a burst
 * of static over it, for [duration]. With [flash] it whites out first. With
 * [inset] the static keeps to the target's own pixels, which needs a target
 * drawn as one piece (KEEP_TOGETHER, as people are).
 */
/proc/cyberware_glitch_fx(atom/movable/target, duration = 0.25 SECONDS, flash = FALSE, inset = FALSE)
	if(QDELETED(target))
		return
	target.add_filters(list(
		list("name" = CHROME_GLITCH_SLICES, "priority" = 40, "params" = displacement_map_filter(icon(CYBERWARE_ANIM2_ICON, "glitch_slices"), size = 3)),
		list("name" = CHROME_GLITCH_RED, "priority" = 41, "params" = drop_shadow_filter(x = -1, y = 0, size = 0, color = "#ff2020a0")),
		list("name" = CHROME_GLITCH_CYAN, "priority" = 42, "params" = drop_shadow_filter(x = 1, y = 0, size = 0, color = "#20e0ffa0")),
	))
	// The slices jump about, then settle.
	var/slices = target.get_filter(CHROME_GLITCH_SLICES)
	animate(slices, y = 7, time = 0.5)
	animate(y = 13, size = 2, time = 0.5)
	animate(y = 3, size = 0, time = max(duration - 1, 0.5))
	target.filter_data[CHROME_GLITCH_SLICES]["size"] = 0
	if(flash)
		cyberware_flash_fx(target, duration * 0.5)
	var/obj/effect/abstract/cyberware_anim/tear = cyberware_anim_play(target, CYBERWARE_ANIM2_ICON, "glitch_tear", CHROME_ANIM2_TOP_LAYER, duration)
	if(tear && inset)
		tear.blend_mode = BLEND_INSET_OVERLAY
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(cyberware_glitch_end), WEAKREF(target)), duration)

/proc/cyberware_glitch_end(datum/weakref/target_ref)
	var/atom/movable/target = target_ref?.resolve()
	if(QDELETED(target))
		return
	target.remove_filter(list(CHROME_GLITCH_SLICES, CHROME_GLITCH_RED, CHROME_GLITCH_CYAN))

#undef CHROME_GLITCH_SLICES
#undef CHROME_GLITCH_RED
#undef CHROME_GLITCH_CYAN

// =========================================================================
// REDLINE BURN
// =========================================================================

#define REDLINE_LOOK_FLASH "flash"
#define REDLINE_LOOK_HOT "hot"
#define REDLINE_LOOK_COOL1 "cool1"
#define REDLINE_LOOK_COOL2 "cool2"
#define REDLINE_GLOW_FILTER "cyberware_redline_glow"
#define REDLINE_SAG_FILTER "cyberware_redline_sag"
/// How long the white kick-in flash holds before the nodes run red.
#define REDLINE_FLASH_TIME (0.15 SECONDS)
/// From the crash to the nodes going grey.
#define REDLINE_COOL_STEP (0.6 SECONDS)
/// How long the back vents steam, and how long the last of it hangs.
#define REDLINE_STEAM_TIME (1.2 SECONDS)
#define REDLINE_STEAM_LIFE (2.4 SECONDS)
/// The eyes during the burn.
#define REDLINE_EYE_COLOR "#ff2a1a"

/obj/item/organ/cyberimp/cyberware/redline
	/// The node look drawn over the core, or null for the plain one.
	var/burn_look
	/// Timer for the next node look.
	var/burn_look_timer
	/// Who carries our filters and our death watch.
	var/datum/weakref/burn_fx_ref
	/// The red light the burn throws.
	var/datum/weakref/burn_light_ref
	/// The steam venting off the back in the crash.
	var/datum/weakref/burn_steam_ref

/obj/item/organ/cyberimp/cyberware/redline/cyberware_worn_key()
	return "[..()]-[burn_look]"

/obj/item/organ/cyberimp/cyberware/redline/cyberware_dress_worn(list/imageset, image_layer, obj/item/bodypart/limb)
	if(cyberware_worn_look() || !burn_look)
		return ..()
	var/state = "[aug_overlay]_[burn_look]"
	if(!icon_exists(CYBERWARE_ANIM2_ICON, state))
		return ..()
	// The node look replaces the core's own glow.
	var/list/dressed = list()
	for(var/image/part as anything in imageset)
		if(PLANE_TO_TRUE(part.plane) == EMISSIVE_PLANE)
			continue
		dressed += part
	var/atom/glow_owner = limb?.owner || limb
	dressed += image(icon = CYBERWARE_ANIM2_ICON, icon_state = state, layer = image_layer)
	if(icon_exists(CYBERWARE_ANIM2_ICON, "[state]_e"))
		dressed += emissive_appearance(CYBERWARE_ANIM2_ICON, "[state]_e", glow_owner, image_layer)
	if(burn_look == REDLINE_LOOK_HOT || burn_look == REDLINE_LOOK_FLASH)
		dressed += redline_eyes(limb, image_layer)
	return dressed

/// Red eyes for the burn, drawn from the bearer's own eye sprites so they sit where their eyes are.
/obj/item/organ/cyberimp/cyberware/redline/proc/redline_eyes(obj/item/bodypart/limb, image_layer)
	var/mob/living/carbon/human/bearer = limb?.owner
	if(!istype(bearer))
		return list()
	var/obj/item/organ/eyes/eyes = bearer.get_organ_slot(ORGAN_SLOT_EYES)
	var/obj/item/bodypart/head/head = bearer.get_bodypart(BODY_ZONE_HEAD)
	if(!istype(eyes) || isnull(eyes.eye_icon_state) || !head)
		return list()
	if(bearer.check_obscured_slots() & ITEM_SLOT_EYES)
		return list()
	var/list/eye_images = list()
	for(var/side in list("_l", "_r"))
		var/mutable_appearance/eye = mutable_appearance('icons/mob/human/human_face.dmi', "[eyes.eye_icon_state][side]", image_layer, bearer)
		eye.color = REDLINE_EYE_COLOR
		var/mutable_appearance/eye_glow = emissive_appearance(eye.icon, eye.icon_state, bearer, image_layer)
		if(head.worn_face_offset)
			head.worn_face_offset.apply_offset(eye)
			head.worn_face_offset.apply_offset(eye_glow)
		eye_images += eye
		eye_images += eye_glow
	return eye_images

/obj/item/organ/cyberimp/cyberware/redline/proc/set_burn_look(look)
	burn_look_timer = null
	if(burn_look == look)
		return
	burn_look = look
	owner?.update_body_parts()

/obj/item/organ/cyberimp/cyberware/redline/proc/queue_burn_look(look, delay)
	if(burn_look_timer)
		deltimer(burn_look_timer)
	burn_look_timer = addtimer(CALLBACK(src, PROC_REF(set_burn_look), look), delay, TIMER_STOPPABLE)

/// The window opens: white-hot nodes, then red, red eyes, a red halo and light.
/obj/item/organ/cyberimp/cyberware/redline/proc/play_burn_window(mob/living/carbon/bearer)
	if(QDELETED(bearer) || bearer != owner)
		return
	clear_burn_fx()
	watch_burn_bearer(bearer)
	set_burn_look(REDLINE_LOOK_FLASH)
	queue_burn_look(REDLINE_LOOK_HOT, REDLINE_FLASH_TIME)
	bearer.add_filter(REDLINE_GLOW_FILTER, 30, drop_shadow_filter(x = 0, y = 0, size = 1.5, color = "#ff2a1470"))
	animate(bearer.get_filter(REDLINE_GLOW_FILTER), size = 2.5, color = "#ff2a14b0", time = 0.35 SECONDS, loop = -1, easing = SINE_EASING)
	animate(size = 1.5, color = "#ff2a1470", time = 0.35 SECONDS, easing = SINE_EASING)
	burn_light_ref = WEAKREF(bearer.mob_light(2, 0.7, "#ff3b22", burn_window + 2 SECONDS))

/// The roar: a red ring rolls out as far as it reaches.
/obj/item/organ/cyberimp/cyberware/redline/proc/play_burn_roar(mob/living/carbon/bearer, reach)
	var/turf/here = get_turf(bearer)
	if(here && reach > 0)
		new /obj/effect/temp_visual/circle_wave/cyberware_roar(here, reach)

/// The crash: the halo goes out, the nodes cool, steam vents from the back and the body slumps.
/obj/item/organ/cyberimp/cyberware/redline/proc/play_burn_crash(mob/living/carbon/bearer)
	if(QDELETED(bearer) || bearer != owner)
		return
	stop_burn_glow(bearer)
	watch_burn_bearer(bearer)
	set_burn_look(REDLINE_LOOK_COOL1)
	queue_burn_look(REDLINE_LOOK_COOL2, REDLINE_COOL_STEP)
	qdel(burn_steam_ref?.resolve())
	burn_steam_ref = WEAKREF(cyberware_anim_particles(bearer, /particles/smoke/steam/cyberware_vent, CHROME_ANIM2_TOP_LAYER, REDLINE_STEAM_TIME, REDLINE_STEAM_LIFE))
	bearer.add_filter(REDLINE_SAG_FILTER, 31, displacement_map_filter(icon(CYBERWARE_ANIM2_ICON, "sag_map"), size = 0))
	animate(bearer.get_filter(REDLINE_SAG_FILTER), size = 2, time = 0.3 SECONDS, easing = QUAD_EASING | EASE_OUT)
	bearer.filter_data[REDLINE_SAG_FILTER]["size"] = 2

/// Takes the halo and the light off; the nodes and the slump stay.
/obj/item/organ/cyberimp/cyberware/redline/proc/stop_burn_glow(mob/living/carbon/bearer)
	qdel(burn_light_ref?.resolve())
	burn_light_ref = null
	if(!QDELETED(bearer))
		bearer.remove_filter(REDLINE_GLOW_FILTER)

/obj/item/organ/cyberimp/cyberware/redline/proc/watch_burn_bearer(mob/living/carbon/bearer)
	burn_fx_ref = WEAKREF(bearer)
	RegisterSignal(bearer, COMSIG_LIVING_DEATH, PROC_REF(on_burn_bearer_death), override = TRUE)

/obj/item/organ/cyberimp/cyberware/redline/proc/on_burn_bearer_death(datum/source)
	SIGNAL_HANDLER
	clear_burn_fx()

/// Back to the plain core: no node look, no halo, light, steam or slump.
/obj/item/organ/cyberimp/cyberware/redline/proc/clear_burn_fx()
	if(burn_look_timer)
		deltimer(burn_look_timer)
		burn_look_timer = null
	qdel(burn_steam_ref?.resolve())
	burn_steam_ref = null
	var/mob/living/carbon/bearer = burn_fx_ref?.resolve()
	burn_fx_ref = null
	stop_burn_glow(bearer)
	if(!QDELETED(bearer))
		UnregisterSignal(bearer, COMSIG_LIVING_DEATH)
		bearer.remove_filter(REDLINE_SAG_FILTER)
	if(isnull(burn_look))
		return
	burn_look = null
	if(!QDELETED(bearer))
		bearer.update_body_parts()

/// The core in the bearer's OS slot, if it is a Redline model.
/proc/cyberware_bearer_redline(mob/living/bearer)
	if(!iscarbon(bearer))
		return null
	var/mob/living/carbon/carbon_bearer = bearer
	var/obj/item/organ/cyberimp/cyberware/redline/core = carbon_bearer.get_organ_slot(ORGAN_SLOT_CYBERWARE_OS)
	return istype(core) ? core : null

/// Hook for the window's on_apply().
/proc/cyberware_redline_window_fx(mob/living/bearer)
	cyberware_bearer_redline(bearer)?.play_burn_window(bearer)

/// Hook for the roar, with the reach it was given.
/proc/cyberware_redline_roar_fx(mob/living/bearer, reach)
	cyberware_bearer_redline(bearer)?.play_burn_roar(bearer, reach)

/// Hook for the window's on_remove(), after it has (or hasn't) applied the crash.
/proc/cyberware_redline_window_end_fx(mob/living/bearer)
	var/obj/item/organ/cyberimp/cyberware/redline/core = cyberware_bearer_redline(bearer)
	if(core && !bearer.has_status_effect(/datum/status_effect/cyberware_redline_crash))
		core.clear_burn_fx()

/// Hook for the crash's on_apply().
/proc/cyberware_redline_crash_fx(mob/living/bearer)
	cyberware_bearer_redline(bearer)?.play_burn_crash(bearer)

/// Hook for the crash's on_remove().
/proc/cyberware_redline_crash_end_fx(mob/living/bearer)
	cyberware_bearer_redline(bearer)?.clear_burn_fx()

/obj/item/organ/cyberimp/cyberware/redline/cyberware_anim_clear(mob/living/carbon/old_owner)
	. = ..()
	clear_burn_fx()

/// The roar's ring, out as far as the roar reaches.
/obj/effect/temp_visual/circle_wave/cyberware_roar
	color = "#ff4a2a"
	max_alpha = 200
	duration = 0.5 SECONDS
	layer = BELOW_MOB_LAYER

/obj/effect/temp_visual/circle_wave/cyberware_roar/Initialize(mapload, reach = 5)
	// The 64 px ring, scaled so its edge lands [reach] tiles out.
	amount_to_scale = reach + 0.5
	return ..()

/// Steam off the back of a crashing core.
/particles/smoke/steam/cyberware_vent
	icon_state = list("steam_1" = 1, "steam_2" = 1, "steam_3" = 2)
	count = 50
	spawning = 3
	lifespan = 1 SECONDS
	fade = 0.6 SECONDS
	position = generator(GEN_BOX, list(-7, 2, 0), list(7, 8, 0), UNIFORM_RAND)
	velocity = generator(GEN_VECTOR, list(-0.6, 0.8, 0), list(0.6, 1.5, 0), NORMAL_RAND)
	gravity = list(0, 0.2)
	friction = 0.15
	drift = generator(GEN_SPHERE, 0, 0.3, NORMAL_RAND)
	grow = 0.05
	scale = 0.75

#undef REDLINE_LOOK_FLASH
#undef REDLINE_LOOK_HOT
#undef REDLINE_LOOK_COOL1
#undef REDLINE_LOOK_COOL2
#undef REDLINE_GLOW_FILTER
#undef REDLINE_SAG_FILTER
#undef REDLINE_FLASH_TIME
#undef REDLINE_COOL_STEP
#undef REDLINE_STEAM_TIME
#undef REDLINE_STEAM_LIFE
#undef REDLINE_EYE_COLOR

// =========================================================================
// LAZARUS NODE
// =========================================================================

#define LAZARUS_SPRING_OFFSET "cyberware_lazarus_spring"
#define LAZARUS_CHARGE_FILTER "cyberware_lazarus_charge"

/obj/item/organ/cyberimp/cyberware/lazarus
	/// Who carries the charge's magenta halo.
	var/datum/weakref/charge_fx_ref
	/// The charge glow on the chest through the windup.
	var/datum/weakref/charge_glow_ref
	/// The arcs crawling over the body through the windup.
	var/datum/weakref/charge_arcs_ref
	/// The magenta light of the charge.
	var/datum/weakref/charge_light_ref

/// The windup: the node charges, magenta arcs crawl out over the body.
/obj/item/organ/cyberimp/cyberware/lazarus/proc/play_charge_fx(mob/living/carbon/patient, windup)
	clear_charge_fx()
	if(QDELETED(patient))
		return
	charge_glow_ref = WEAKREF(cyberware_anim_play(patient, CYBERWARE_ANIM2_ICON, "lazarus_charge", CHROME_ANIM2_TOP_LAYER, windup, glow = TRUE))
	charge_arcs_ref = WEAKREF(cyberware_anim2_play_large(patient, "lazarus_arcs", windup))
	charge_light_ref = WEAKREF(patient.mob_light(1.5, 0.8, "#e700e3", windup))
	// The whole body takes on the charge, brighter as it fills.
	charge_fx_ref = WEAKREF(patient)
	patient.add_filter(LAZARUS_CHARGE_FILTER, 33, drop_shadow_filter(x = 0, y = 0, size = 1, color = "#e700e340"))
	animate(patient.get_filter(LAZARUS_CHARGE_FILTER), size = 2.5, color = "#e700e3b0", time = windup, easing = QUAD_EASING | EASE_IN)
	patient.filter_data[LAZARUS_CHARGE_FILTER]["size"] = 2.5
	patient.filter_data[LAZARUS_CHARGE_FILTER]["color"] = "#e700e3b0"

/// Takes the charge off whoever it is on.
/obj/item/organ/cyberimp/cyberware/lazarus/proc/clear_charge_fx()
	qdel(charge_glow_ref?.resolve())
	qdel(charge_arcs_ref?.resolve())
	qdel(charge_light_ref?.resolve())
	charge_glow_ref = null
	charge_arcs_ref = null
	charge_light_ref = null
	var/mob/living/carbon/patient = charge_fx_ref?.resolve()
	charge_fx_ref = null
	if(!QDELETED(patient))
		patient.remove_filter(LAZARUS_CHARGE_FILTER)

/// The jolt: a white flash, a burst and a light, and a little spring off the floor.
/obj/item/organ/cyberimp/cyberware/lazarus/proc/play_jolt_fx(mob/living/carbon/patient)
	clear_charge_fx()
	if(QDELETED(patient))
		return
	cyberware_anim2_play_large(patient, "lazarus_jolt", 0.5 SECONDS)
	patient.mob_light(2.5, 1.4, "#ffe6ff", 0.3 SECONDS)
	cyberware_flash_fx(patient, 0.25 SECONDS)
	patient.add_offsets(LAZARUS_SPRING_OFFSET, z_add = 3, animate = FALSE)
	addtimer(CALLBACK(patient, TYPE_PROC_REF(/mob/living, remove_offsets), LAZARUS_SPRING_OFFSET), 0.5)

/obj/item/organ/cyberimp/cyberware/lazarus/cyberware_anim_clear(mob/living/carbon/old_owner)
	. = ..()
	clear_charge_fx()

#undef LAZARUS_SPRING_OFFSET
#undef LAZARUS_CHARGE_FILTER

// =========================================================================
// LEAPS
// =========================================================================

/// Set at take-off to when the leap should be down. A leap whose landing never
/// runs is put back on the floor shortly after.
/mob/living/var/cyberware_leap_until = 0

/// Where the body sits at rest, before any leap offset.
/proc/cyberware_leap_rest(mob/living/jumper, pixel)
	var/base = pixel == PIXEL_W_OFFSET ? jumper.base_pixel_w : jumper.base_pixel_z
	return base + jumper.has_offset(pixel = pixel)

/**
 * Take-off. The body arcs from [launch] over to [landing] during [airtime], rising
 * to [peak] halfway and ending [height] over the landing tile, where the
 * landing drops it. The body stays on its own tile until the landing moves
 * it; only the drawing travels. A one-tile leap hops in place, since moving
 * one tile glides.
 */
/proc/cyberware_leap_takeoff_fx(mob/living/jumper, turf/launch, turf/landing, airtime, height, peak, obj/effect/afterimage)
	if(QDELETED(jumper))
		return
	if(afterimage)
		// The crouch the pistons fired out of.
		var/matrix/squash = matrix(afterimage.transform)
		squash.Scale(1.08, 0.86)
		squash.Translate(0, -2)
		afterimage.transform = squash
	cyberware_grey_dust(launch)
	var/dx = 0
	var/dy = 0
	if(launch && landing && get_dist(launch, landing) >= 2)
		dx = (landing.x - launch.x) * ICON_SIZE_X
		dy = (landing.y - launch.y) * ICON_SIZE_Y
	var/rest_w = cyberware_leap_rest(jumper, PIXEL_W_OFFSET)
	var/rest_z = cyberware_leap_rest(jumper, PIXEL_Z_OFFSET)
	animate(jumper, pixel_w = rest_w + dx * 0.5, pixel_z = rest_z + dy * 0.5 + peak, time = airtime * 0.5, easing = SINE_EASING | EASE_OUT)
	animate(pixel_w = rest_w + dx, pixel_z = rest_z + dy + height, time = airtime * 0.5, easing = SINE_EASING | EASE_IN)
	if(dx || dy)
		new /obj/effect/temp_visual/cyberware_leap_shadow(launch, dx, dy, airtime)
	jumper.cyberware_leap_until = world.time + airtime
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(cyberware_leap_failsafe), WEAKREF(jumper)), airtime + 0.5 SECONDS)

/// Touchdown: the body is over its landing tile and drops [height] onto it.
/proc/cyberware_leap_touchdown_fx(mob/living/jumper, height, drop_time)
	if(QDELETED(jumper))
		return
	jumper.cyberware_leap_until = 0
	var/rest_z = cyberware_leap_rest(jumper, PIXEL_Z_OFFSET)
	jumper.pixel_w = cyberware_leap_rest(jumper, PIXEL_W_OFFSET)
	jumper.pixel_z = rest_z + height
	animate(jumper, pixel_z = rest_z, time = drop_time)

/// A leap whose landing never ran (the pistons were pulled mid-air) is put back down.
/proc/cyberware_leap_failsafe(datum/weakref/jumper_ref)
	var/mob/living/jumper = jumper_ref?.resolve()
	if(QDELETED(jumper) || !jumper.cyberware_leap_until || world.time < jumper.cyberware_leap_until)
		return
	cyberware_leap_touchdown_fx(jumper, 0, 0)

/// The Piledriver's impact: a ring rolls out over the shockwave and the floor cracks.
/proc/cyberware_piledriver_impact_fx(turf/where, reach)
	if(isnull(where))
		return
	new /obj/effect/temp_visual/circle_wave/cyberware_slam(where, reach)
	new /obj/effect/temp_visual/cyberware_impact_cracks(where, "damaged1", 255)
	for(var/direction in GLOB.cardinals)
		var/turf/next = get_step(where, direction)
		if(next)
			new /obj/effect/temp_visual/cyberware_impact_cracks(next, "damaged5", 140)

/// The shadow that runs along the floor under a leap.
/obj/effect/temp_visual/cyberware_leap_shadow
	icon = CYBERWARE_ANIM2_ICON
	icon_state = "leap_shadow"
	layer = BELOW_MOB_LAYER
	randomdir = FALSE
	duration = 0.3 SECONDS

/obj/effect/temp_visual/cyberware_leap_shadow/Initialize(mapload, dx = 0, dy = 0, airtime = 0.2 SECONDS)
	duration = airtime + 0.1 SECONDS
	. = ..()
	animate(src, pixel_x = dx, pixel_y = dy, time = airtime)
	animate(src, transform = matrix().Scale(0.7), time = airtime * 0.5, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)
	animate(transform = matrix(), time = airtime * 0.5, easing = SINE_EASING | EASE_IN)

/// The Piledriver's ring: grey, out over the shockwave.
/obj/effect/temp_visual/circle_wave/cyberware_slam
	color = "#d8d4cc"
	max_alpha = 220
	duration = 0.4 SECONDS
	layer = BELOW_MOB_LAYER

/obj/effect/temp_visual/circle_wave/cyberware_slam/Initialize(mapload, reach = 2)
	amount_to_scale = reach + 0.5
	return ..()

/// Cracks the Piledriver leaves in the floor. They fade on their own.
/obj/effect/temp_visual/cyberware_impact_cracks
	icon = 'icons/turf/damaged.dmi'
	icon_state = "damaged1"
	plane = FLOOR_PLANE
	layer = ABOVE_OPEN_TURF_LAYER
	randomdir = FALSE
	duration = 8 SECONDS

/obj/effect/temp_visual/cyberware_impact_cracks/Initialize(mapload, state = "damaged1", peak_alpha = 255)
	. = ..()
	var/turf/here = loc
	// Nothing to crack in space, open air or a chasm.
	if(!isfloorturf(here))
		return INITIALIZE_HINT_QDEL
	icon_state = state
	alpha = peak_alpha
	animate(src, alpha = peak_alpha, time = duration - 2 SECONDS)
	animate(alpha = 0, time = 2 SECONDS)

// =========================================================================
// CYBERDECK
// =========================================================================

/// Packets running up the trace while a hack uploads, drawn over it.
/proc/cyberware_deck_packets(mob/living/bearer, atom/target, time, maxdistance)
	if(QDELETED(bearer) || QDELETED(target))
		return null
	return bearer.Beam(target, icon_state = "deck_packets", icon = CYBERWARE_ANIM2_ICON, time = time, maxdistance = maxdistance)

/// How long after a Ping the sweep reaches [machine] from [center].
/proc/cyberware_ping_reveal_delay(turf/center, atom/machine)
	var/turf/there = get_turf(machine)
	if(isnull(center) || isnull(there))
		return 0
	var/distance = sqrt((there.x - center.x) ** 2 + (there.y - center.y) ** 2) * ICON_SIZE_X
	// The ring's radius is 6 + 224 * (1 - (1 - t)^2) over the sweep; solve for t.
	var/progress = clamp((distance - 6) / 224, 0, 1)
	return round((1 - sqrt(1 - progress)) * 0.72 SECONDS, 0.5)

/// The Ping sweep: a ring rolls out from the hacker, for the hacker alone.
/proc/cyberware_ping_sweep_fx(mob/living/viewer)
	var/turf/here = get_turf(viewer)
	if(isnull(here) || !viewer.client)
		return
	var/image/sweep = image(CYBERWARE_ANIM_PING_ICON, here, "ping_sweep", ABOVE_ALL_MOB_LAYER)
	sweep.pixel_w = -224
	sweep.pixel_z = -224
	sweep.appearance_flags = RESET_COLOR | RESET_TRANSFORM | RESET_ALPHA
	SET_PLANE_EXPLICIT(sweep, ABOVE_LIGHTING_PLANE, here)
	viewer.client.images += sweep
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(cyberware_ping_sweep_end), WEAKREF(viewer), sweep), 0.9 SECONDS)

/proc/cyberware_ping_sweep_end(datum/weakref/viewer_ref, image/sweep)
	var/mob/living/viewer = viewer_ref?.resolve()
	viewer?.client?.images -= sweep

/**
 * A tinted copy of [target] with an outline in [mark_color], for a HUD mark
 * to draw through walls. Only the target's own drawing comes along: its
 * lights and emissive blockers stay behind.
 */
/proc/cyberware_mark_outline(atom/target, mark_color)
	var/mutable_appearance/look = new(target)
	var/list/kept = list()
	for(var/mutable_appearance/part as anything in look.overlays)
		if(part.plane == FLOAT_PLANE)
			kept += part
	look.overlays = kept
	look.underlays = list()
	look.filters = null
	look.alpha = 210
	look.layer = ABOVE_ALL_MOB_LAYER - 0.01
	look.appearance_flags = KEEP_TOGETHER | PIXEL_SCALE | RESET_COLOR | RESET_ALPHA
	look.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/list/rgb = rgb2num(mark_color)
	var/red = rgb[1] / 255 * 1.3
	var/green = rgb[2] / 255 * 1.3
	var/blue = rgb[3] / 255 * 1.3
	look.color = list(
		0.3 * red, 0.3 * green, 0.3 * blue,
		0.59 * red, 0.59 * green, 0.59 * blue,
		0.11 * red, 0.11 * green, 0.11 * blue,
		0.12 * rgb[1] / 255, 0.12 * rgb[2] / 255, 0.12 * rgb[3] / 255,
	)
	var/image/outline = new
	outline.appearance = look
	outline.add_filter("cyberware_mark_outline", 1, outline_filter(1, mark_color))
	return outline

/// The outline fades in when the sweep reaches it and out before the mark goes.
/proc/cyberware_mark_outline_reveal(image/outline, delay, duration)
	outline.alpha = 0
	animate(outline, alpha = 0, time = max(delay, 0))
	animate(alpha = 210, time = 1)
	animate(alpha = 210, time = max(duration - delay - 5, 0))
	animate(alpha = 0, time = 4)

// =========================================================================
// WEAPON TRAILS
// =========================================================================

/// A landed Scorch cut: embers fly off whoever it cut. The burning slash itself
/// is the blade's impact (cyberware_anim.dm), so nothing else is drawn on top.
/proc/cyberware_scorch_trail_fx(mob/living/user, mob/living/target)
	var/turf/here = get_turf(target)
	if(isnull(here))
		return
	new /obj/effect/temp_visual/cyberware_scorch_embers(here)

/// Only the embers: the picture is blank.
/obj/effect/temp_visual/cyberware_scorch_embers
	layer = ABOVE_MOB_LAYER
	randomdir = FALSE
	duration = 0.7 SECONDS

/obj/effect/temp_visual/cyberware_scorch_embers/Initialize(mapload)
	. = ..()
	particles = new /particles/embers/spark/cyberware_scorch
	addtimer(CALLBACK(src, PROC_REF(stop_embers)), 1)

/obj/effect/temp_visual/cyberware_scorch_embers/proc/stop_embers()
	if(particles)
		particles.spawning = 0

/// One burst of embers off a Scorch cut.
/particles/embers/spark/cyberware_scorch
	count = 8
	spawning = 8
	lifespan = 0.6 SECONDS
	fade = 0.4 SECONDS
	velocity = generator(GEN_CIRCLE, 2, 3, SQUARE_RAND)
	gravity = list(0, -0.15)

/// A landed Widowline Arc swing: the wire lashes out to whatever it hit.
/proc/cyberware_monowire_lash_fx(mob/living/user, atom/target)
	if(QDELETED(user) || QDELETED(target) || get_turf(user) == get_turf(target))
		return
	user.Beam(target, icon_state = "monowire_lash", icon = CYBERWARE_ANIM2_ICON, time = 0.3 SECONDS)

/// The Arc's shock: a crackle runs along the wire and sparks burst where it lands.
/proc/cyberware_arc_crackle_fx(mob/living/user, atom/target)
	if(QDELETED(user) || QDELETED(target))
		return
	if(get_turf(user) != get_turf(target))
		user.Beam(target, icon_state = "arc_crackle", icon = CYBERWARE_ANIM2_ICON, time = 0.5 SECONDS)
	var/turf/there = get_turf(target)
	if(there)
		new /obj/effect/temp_visual/cyberware_arc_hit(there)

/obj/effect/temp_visual/cyberware_arc_hit
	icon = CYBERWARE_ANIM2_LARGE_ICON
	icon_state = "arc_hit"
	pixel_x = -16
	pixel_y = -16
	layer = ABOVE_MOB_LAYER
	randomdir = FALSE
	duration = 0.4 SECONDS

/obj/effect/temp_visual/cyberware_arc_hit/Initialize(mapload)
	. = ..()
	add_overlay(emissive_appearance(icon, icon_state, src))

// =========================================================================
// BROWNOUT
// =========================================================================

/// Step between the frames of a brownout stutter.
#define BROWNOUT_STEP (0.1 SECONDS)

/**
 * The brownout picture for one bearer: every worn piece stutters, warms and
 * dims together on the way down, and stutters back on on the way up. The
 * brownout itself has already happened; this only plays the picture, and
 * clearing it at any point leaves each piece drawn as its state says.
 */
/datum/component/chrome_brownout_show
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Looks still to play, in order.
	var/list/steps
	/// Timer for the next look.
	var/step_timer
	/// Pieces whose look this show has set.
	var/list/datum/weakref/touched = list()

/datum/component/chrome_brownout_show/Initialize()
	if(!iscarbon(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/chrome_brownout_show/RegisterWithParent()
	RegisterSignal(parent, COMSIG_LIVING_DEATH, PROC_REF(on_death))

/datum/component/chrome_brownout_show/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_LIVING_DEATH)

/datum/component/chrome_brownout_show/Destroy()
	if(step_timer)
		deltimer(step_timer)
		step_timer = null
	var/changed = FALSE
	for(var/datum/weakref/piece_ref as anything in touched)
		var/obj/item/organ/piece = piece_ref.resolve()
		var/datum/component/cyberware/chrome = piece?.GetComponent(/datum/component/cyberware)
		if(chrome?.brownout_look)
			chrome.brownout_look = null
			changed = TRUE
	touched.Cut()
	var/mob/living/carbon/bearer = parent
	if(changed && !QDELETED(bearer))
		bearer.update_body_parts()
	return ..()

/datum/component/chrome_brownout_show/proc/on_death(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// Starts the stutter: down when [tripped], back up otherwise.
/datum/component/chrome_brownout_show/proc/play(tripped)
	if(tripped)
		steps = list(CHROME_LOOK_WARM, CHROME_LOOK_BROWN, CHROME_LOOK_WARM, CHROME_LOOK_BROWN, CHROME_LOOK_BROWN, CHROME_LOOK_WARM, CHROME_LOOK_BROWN)
	else
		steps = list(CHROME_LOOK_BROWN, CHROME_LOOK_WARM, CHROME_LOOK_BROWN, CHROME_LOOK_BROWN, CHROME_LOOK_WARM, CHROME_LOOK_BROWN)
	if(step_timer)
		deltimer(step_timer)
		step_timer = null
	advance()

/datum/component/chrome_brownout_show/proc/advance()
	step_timer = null
	if(!length(steps))
		qdel(src)
		return
	var/look = popleft(steps)
	var/mob/living/carbon/bearer = parent
	for(var/obj/item/organ/piece as anything in get_installed_cyberware(bearer))
		var/obj/item/organ/cyberimp/implant = piece
		if(!istype(implant) || !implant.bodypart_aug)
			continue
		var/datum/component/cyberware/chrome = piece.GetComponent(/datum/component/cyberware)
		if(!chrome)
			continue
		chrome.brownout_look = look
		touched |= WEAKREF(piece)
	bearer.update_body_parts()
	step_timer = addtimer(CALLBACK(src, PROC_REF(advance)), BROWNOUT_STEP, TIMER_STOPPABLE)

/// Hook for the brownout monitor: [bearer]'s chrome just went down ([tripped]) or came back.
/proc/cyberware_brownout_fx(mob/living/carbon/bearer, tripped)
	if(!iscarbon(bearer) || QDELETED(bearer))
		return
	if(bearer.stat == DEAD)
		// No show on a corpse: just draw it as it is.
		bearer.update_body_parts()
		return
	var/datum/component/chrome_brownout_show/show = bearer.GetComponent(/datum/component/chrome_brownout_show) || bearer.AddComponent(/datum/component/chrome_brownout_show)
	show?.play(tripped)

#undef BROWNOUT_STEP

// =========================================================================
// CHROME CRADLE RIG
// =========================================================================

/// Layers on the cradle: the rig over the ware, both over the patient.
#define RIG_LAYER (ABOVE_MOB_LAYER + 0.02)
#define RIG_WARE_LAYER (ABOVE_MOB_LAYER + 0.01)
/// The gripper's tip, as pixel offsets of the carried ware's centre on the cradle tile.
#define RIG_WARE_X 4
#define RIG_WARE_PARKED_Y 19
#define RIG_WARE_WORK_Y 2
/// How long each move of the rig takes, matching its art.
#define RIG_GRIP_TIME (0.6 SECONDS)
#define RIG_PRESS_TIME (0.4 SECONDS)
#define RIG_RETRACT_TIME (0.3 SECONDS)

/obj/machinery/chrome_cradle
	/// The rig's current move, or null while it is parked.
	var/rig_phase
	/// The rig drawing that move.
	var/datum/weakref/rig_ref
	/// The ware in the gripper.
	var/datum/weakref/rig_ware_ref
	/// Timer that parks the rig once it has pulled back.
	var/rig_park_timer

/obj/machinery/chrome_cradle/update_overlays()
	. = ..()
	if(rig_phase)
		return
	// The parked rig, over whoever lies on the slab.
	var/mutable_appearance/rig = mutable_appearance(CHROME_CRADLE_RIG_ICON, "rig", RIG_LAYER)
	rig.pixel_x = -16
	rig.pixel_y = -16
	. += rig
	var/mutable_appearance/rig_glow = emissive_appearance(CHROME_CRADLE_RIG_ICON, "rig_e", src, RIG_LAYER)
	rig_glow.pixel_x = -16
	rig_glow.pixel_y = -16
	. += rig_glow

/// Plays one move of the rig: [phase] is a state of the rig sheet without its "rig_".
/obj/machinery/chrome_cradle/proc/play_rig(phase)
	if(rig_park_timer)
		deltimer(rig_park_timer)
		rig_park_timer = null
	qdel(rig_ref?.resolve())
	var/was_parked = isnull(rig_phase)
	rig_phase = phase
	if(was_parked)
		update_appearance(UPDATE_OVERLAYS)
	var/state = "rig_[phase]"
	var/obj/effect/abstract/cyberware_anim/rig = cyberware_anim_play(src, CHROME_CRADLE_RIG_ICON, state, RIG_LAYER, CYBERWARE_INSTALL_TIME + 1 SECONDS)
	if(!rig)
		return
	rig.pixel_x = -16
	rig.pixel_y = -16
	rig.add_overlay(emissive_appearance(CHROME_CRADLE_RIG_ICON, "[state]_e", src))
	rig_ref = WEAKREF(rig)

/// A servo beat of the install: the arms come down, the gripper brings the ware, then presses it in.
/obj/machinery/chrome_cradle/proc/rig_beat(mid_stage)
	if(busy_action != "install")
		return
	if(mid_stage)
		play_rig("press")
		var/obj/effect/abstract/cyberware_anim/carried = rig_ware_ref?.resolve()
		if(carried)
			animate(carried, pixel_y = RIG_WARE_WORK_Y - 3, transform = matrix().Scale(0.2), alpha = 0, time = RIG_PRESS_TIME, easing = QUAD_EASING | EASE_IN)
		return
	if(isnull(rig_phase) || rig_phase == "retract")
		play_rig("arms_down")
		return
	play_rig("grip_down")
	qdel(rig_ware_ref?.resolve())
	if(QDELETED(busy_ware))
		return
	var/obj/effect/abstract/cyberware_anim/carried = cyberware_anim_play(src, busy_ware.icon, busy_ware.icon_state, RIG_WARE_LAYER, CYBERWARE_INSTALL_TIME)
	if(!carried)
		return
	carried.transform = matrix().Scale(0.45)
	carried.pixel_x = RIG_WARE_X
	carried.pixel_y = RIG_WARE_PARKED_Y
	animate(carried, pixel_y = RIG_WARE_WORK_Y, time = RIG_GRIP_TIME, easing = CUBIC_EASING | EASE_OUT)
	rig_ware_ref = WEAKREF(carried)

/// The sequence is over, done or not: the rig pulls back and parks.
/obj/machinery/chrome_cradle/proc/rig_stop()
	qdel(rig_ware_ref?.resolve())
	rig_ware_ref = null
	if(isnull(rig_phase) || rig_phase == "retract")
		return
	play_rig("retract")
	rig_park_timer = addtimer(CALLBACK(src, PROC_REF(park_rig)), RIG_RETRACT_TIME, TIMER_STOPPABLE)

/obj/machinery/chrome_cradle/proc/park_rig()
	rig_park_timer = null
	qdel(rig_ref?.resolve())
	rig_ref = null
	rig_phase = null
	update_appearance(UPDATE_OVERLAYS)

/// The ware boots in its new owner: a glitch runs over them.
/obj/machinery/chrome_cradle/proc/rig_boot_fx(mob/living/carbon/patient)
	cyberware_glitch_fx(patient, 0.2 SECONDS, flash = TRUE, inset = TRUE)

#undef RIG_LAYER
#undef RIG_WARE_LAYER
#undef RIG_WARE_X
#undef RIG_WARE_PARKED_Y
#undef RIG_WARE_WORK_Y
#undef RIG_GRIP_TIME
#undef RIG_PRESS_TIME
#undef RIG_RETRACT_TIME

#undef CYBERWARE_ANIM2_ICON
#undef CYBERWARE_ANIM2_LARGE_ICON
#undef CYBERWARE_ANIM_PING_ICON
#undef CHROME_CRADLE_RIG_ICON
#undef CHROME_ANIM2_TOP_LAYER
#undef CHROME_LOOK_BROWN
#undef CHROME_LOOK_WARM
