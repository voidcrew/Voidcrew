/**
 * # Gun-fu motion (stealth step 3c, decision 17)
 *
 * The pictures for each gun-fu move (stealth_gunfu.dm). Visual only, under hyperviolence's motion rules
 * (voidcrew/modules/hyperviolence/visuals/_motion_core.dm): named hv_vis_play() sequences that end where they began,
 * nothing that moves, stuns, roots or hurts anyone. The gameplay has already happened (or is happening through tg's
 * throw) when these are called; each only draws it.
 *
 * Each move is built storyboard -> blocking -> full build (kit rule), in all four facings. A move with no pictures
 * yet just plays tg's own throw and shove.
 */

/// Hip throw: `victim` is being thrown toward `toward` by tg's throw_at() right after this call.
/mob/living/carbon/human/proc/gunfu_vis_hip_throw(mob/living/victim, turf/toward)
	return

/// Shoulder flip: `victim`, on this mob's tile, is thrown onto `landing` right after this call.
/mob/living/carbon/human/proc/gunfu_vis_flip(mob/living/victim, turf/landing)
	return

/// Wall slam: `victim` is about to be shoved into the solid thing on `wall` by tg's disarm().
/mob/living/carbon/human/proc/gunfu_vis_wall_slam(mob/living/victim, turf/wall)
	return

/// Disarm: `victim` is about to be shoved, and `held` knocked out of their hand.
/mob/living/carbon/human/proc/gunfu_vis_disarm(mob/living/victim, obj/item/held)
	return
