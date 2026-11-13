/**
 * # Gun-fu motion: the wall slam and the disarm (stealth step 3c, decision 17)
 *
 * Visual only, under hyperviolence's motion rules (voidcrew/modules/hyperviolence/visuals/_motion_core.dm): named
 * hv_vis_play() sequences that end where they began; nothing here moves, stuns, roots or hurts anyone. Built
 * storyboard -> blocking -> full build (kit rule), in all four facings.
 */

/// Wall slam: `victim` is about to be shoved into the solid thing on `wall` by tg's disarm().
/mob/living/carbon/human/proc/gunfu_vis_wall_slam(mob/living/victim, turf/wall)
	return

/// Disarm: `victim` is about to be shoved, and `held` knocked out of their hand.
/mob/living/carbon/human/proc/gunfu_vis_disarm(mob/living/victim, obj/item/held)
	return
