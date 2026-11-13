/**
 * # Gun-fu motion: the human shield (stealth step 3c, decision 17)
 *
 * Visual only, under hyperviolence's motion rules (voidcrew/modules/hyperviolence/visuals/_motion_core.dm): named
 * hv_vis_play() sequences that end where they began; nothing here moves, stuns, roots or hurts anyone. Built
 * storyboard -> blocking -> full build (kit rule), in all four facings.
 */

/// Human shield: how far in front of the holder the held body is drawn, in pixels.
#define GUNFU_SHIELD_SHIFT 12

/// A body held up as a shield stands in front of its holder, facing the same way, instead of tg's grab offset. Rows
/// sort before layers (SIDE_MAP), so a step down keeps it drawn in front of the holder side-on.
/mob/living/set_pull_offsets(mob/living/mob_to_set, grab_state = GRAB_PASSIVE, animate = TRUE)
	if(!ishuman(src))
		return ..()
	var/mob/living/carbon/human/holder = src
	if(holder.gunfu_shield_body() != mob_to_set)
		return ..()
	mob_to_set.remove_offsets(GRABBING_TRAIT, animate = FALSE)
	mob_to_set.setDir(dir)
	var/shift_x = 0
	var/shift_y = 0
	switch(dir)
		if(NORTH)
			shift_y = GUNFU_SHIELD_SHIFT
		if(SOUTH)
			shift_y = -GUNFU_SHIELD_SHIFT
		if(EAST)
			shift_x = GUNFU_SHIELD_SHIFT
			shift_y = -1
		if(WEST)
			shift_x = -GUNFU_SHIELD_SHIFT
			shift_y = -1
	mob_to_set.add_offsets(GRABBING_TRAIT, x_add = shift_x, y_add = shift_y, animate = animate)
