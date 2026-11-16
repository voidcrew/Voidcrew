/**
 * # Gun-fu motion: the shoulder flip (stealth step 3c, decision 17)
 *
 * Visual only, under hyperviolence's motion rules (voidcrew/modules/hyperviolence/visuals/_motion_core.dm): named
 * hv_vis_play() sequences that end where they began; nothing here moves, stuns, roots or hurts anyone. Built
 * storyboard -> blocking -> full build (kit rule), in all four facings.
 */

/// Shoulder flip: `victim`, on this mob's tile, is thrown onto `landing` right after this call.
/mob/living/carbon/human/proc/gunfu_vis_flip(mob/living/victim, turf/landing)
	return
