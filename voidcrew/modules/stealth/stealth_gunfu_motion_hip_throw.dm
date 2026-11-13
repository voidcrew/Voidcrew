/**
 * # Gun-fu motion: the hip throw (stealth step 3c, decision 17)
 *
 * Visual only, under hyperviolence's motion rules (voidcrew/modules/hyperviolence/visuals/_motion_core.dm): named
 * hv_vis_play() sequences that end where they began; nothing here moves, stuns, roots or hurts anyone. Built
 * storyboard -> blocking -> full build (kit rule), in all four facings.
 */

/// Hip throw: `victim` is being thrown toward `toward` by tg's throw_at() right after this call.
/mob/living/carbon/human/proc/gunfu_vis_hip_throw(mob/living/victim, turf/toward)
	return
