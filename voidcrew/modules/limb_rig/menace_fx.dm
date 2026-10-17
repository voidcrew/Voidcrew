/**
 * The cursed bits of a Loomer's combat stance, on top of the reaching and trembling.
 *
 * - Tendrils: the forearms and fingers writhe, using looping wave filters the way anomalies
 *   wibble (apply_wibbly_filters()), so the arms read as something other than arms.
 * - Glitches: every few seconds, for a moment, the face turns into Ransom from DOORS: crushed
 *   to black and white, drowned in flickering static flecked with red, smeared sideways. The
 *   body tears into a red and blue split and the whole thing jumps a couple of pixels.
 *
 * The stop-motion freezes and snaps are part of the tremble itself (play_menace()).
 */

/// How many writhing waves each tendril piece gets.
#define TENDRIL_WAVES 3
/// Flickering static that covers the face during a glitch.
#define RANSOM_STATIC 'voidcrew/modules/limb_rig/icons/ransom.dmi'

/datum/limb_rig
	/// Whether the tendrils and glitches are running.
	var/menace_fx = FALSE
	/// Timer for the next glitch.
	var/glitch_timer
	/// The static on the face while a glitch is showing.
	var/mutable_appearance/glitch_static

/// The pieces that writhe: forearms and fingers.
/datum/limb_rig/proc/get_tendril_parts()
	return list(parts["l_forearm"], parts["r_forearm"], finger_parts["l"], finger_parts["r"])

/datum/limb_rig/proc/start_menace_fx()
	if(menace_fx)
		return
	menace_fx = TRUE
	for(var/obj/effect/abstract/limb_rig_part/part as anything in get_tendril_parts())
		for(var/wave in 1 to TENDRIL_WAVES)
			var/phase = rand()
			// Short wavelengths along the limb, a pixel or two of sway.
			part.add_filter("tendril-[wave]", 5, wave_filter(x = rand(-8, 8), y = rand(6, 12) * pick(-1, 1), size = rand(8, 20) / 10, offset = phase))
			var/filter = part.get_filter("tendril-[wave]")
			animate(filter, offset = phase, time = 0, loop = -1, flags = ANIMATION_PARALLEL)
			animate(offset = phase - 1, time = rand(4, 9))
	schedule_glitch()

/datum/limb_rig/proc/stop_menace_fx()
	if(!menace_fx)
		return
	menace_fx = FALSE
	deltimer(glitch_timer)
	glitch_timer = null
	for(var/obj/effect/abstract/limb_rig_part/part as anything in get_tendril_parts())
		for(var/wave in 1 to TENDRIL_WAVES)
			animate(part.get_filter("tendril-[wave]"))
			part.remove_filter("tendril-[wave]")
	end_glitch()

/datum/limb_rig/proc/schedule_glitch()
	deltimer(glitch_timer)
	glitch_timer = addtimer(CALLBACK(src, PROC_REF(glitch)), rand(15, 45), TIMER_STOPPABLE|TIMER_DELETE_ME)

/// A moment of the upper body tearing apart on screen.
/datum/limb_rig/proc/glitch()
	if(!menace_fx || QDELETED(owner))
		return
	for(var/obj/effect/abstract/limb_rig_part/part as anything in list(parts[RIG_HEAD], parts[RIG_CHEST]))
		part.add_filter("glitch_red", 10, drop_shadow_filter(x = -rand(1, 3), y = rand(-1, 1), size = 0, color = "#ff0028aa"))
		part.add_filter("glitch_blue", 11, drop_shadow_filter(x = rand(1, 3), y = rand(-1, 1), size = 0, color = "#00d0ffaa"))
	var/obj/effect/abstract/limb_rig_part/head = parts[RIG_HEAD]
	// The face goes to static: crushed to harsh black and white, warped, smeared sideways.
	glitch_static = mutable_appearance(RANSOM_STATIC, "ransom")
	head.add_overlay(glitch_static)
	head.add_filter("glitch_warp", 12, wave_filter(x = rand(2, 4), y = rand(2, 4), size = rand(2, 4), offset = rand()))
	head.add_filter("glitch_color", 13, color_matrix_filter(list(0.54, 0.54, 0.54, 1.06, 1.06, 1.06, 0.2, 0.2, 0.2, -0.6, -0.6, -0.6)))
	head.add_filter("glitch_smear", 14, motion_blur_filter(x = pick(-3, 3), y = 0))
	pivot.pixel_w = pick(-2, -1, 1, 2)
	addtimer(CALLBACK(src, PROC_REF(end_glitch)), rand(2, 4), TIMER_DELETE_ME)
	schedule_glitch()

/datum/limb_rig/proc/end_glitch()
	if(QDELETED(owner))
		return
	for(var/obj/effect/abstract/limb_rig_part/part as anything in list(parts[RIG_HEAD], parts[RIG_CHEST]))
		part.remove_filter("glitch_red")
		part.remove_filter("glitch_blue")
	var/obj/effect/abstract/limb_rig_part/head = parts[RIG_HEAD]
	head.remove_filter("glitch_warp")
	head.remove_filter("glitch_color")
	head.remove_filter("glitch_smear")
	if(glitch_static)
		head.cut_overlay(glitch_static)
		glitch_static = null
	pivot.pixel_w = 0

#undef TENDRIL_WAVES
#undef RANSOM_STATIC
