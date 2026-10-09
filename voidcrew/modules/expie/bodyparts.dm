#define EXPIE_BODYPARTS 'voidcrew/modules/expie/icons/bodyparts.dmi'

// An Experiment is always drawn through the limb rig (see experiment.dm), which builds it from its
// own piece sprites. These are what's drawn when it isn't rigged (a preview, a corpse): the body
// standing at rest, tail and all, 64x64 and drawn 16 pixels left like the rig's pieces.

/obj/item/bodypart/head/experiment
	icon = EXPIE_BODYPARTS
	// Human-shaped wounds don't fit; the rig draws the Experiment's own (see experiment.dm).
	dmg_overlay_type = null
	icon_static = EXPIE_BODYPARTS
	limb_id = SPECIES_EXPERIMENT
	is_dimorphic = FALSE
	should_draw_greyscale = FALSE
	// No hair, and the eyes are part of the sprite.
	head_flags = HEAD_DEBRAIN

/obj/item/bodypart/head/experiment/get_limb_icon(dropped, mob/living/carbon/update_on)
	. = ..()
	for(var/image/sprite as anything in .)
		sprite.pixel_w -= 16

/obj/item/bodypart/chest/experiment
	icon = EXPIE_BODYPARTS
	// Human-shaped wounds don't fit; the rig draws the Experiment's own (see experiment.dm).
	dmg_overlay_type = null
	icon_static = EXPIE_BODYPARTS
	limb_id = SPECIES_EXPERIMENT
	is_dimorphic = FALSE
	should_draw_greyscale = FALSE

/obj/item/bodypart/chest/experiment/get_limb_icon(dropped, mob/living/carbon/update_on)
	. = ..()
	for(var/image/sprite as anything in .)
		sprite.pixel_w -= 16

/obj/item/bodypart/arm/left/experiment
	icon = EXPIE_BODYPARTS
	// Human-shaped wounds don't fit; the rig draws the Experiment's own (see experiment.dm).
	dmg_overlay_type = null
	icon_static = EXPIE_BODYPARTS
	limb_id = SPECIES_EXPERIMENT
	should_draw_greyscale = FALSE

/obj/item/bodypart/arm/left/experiment/get_limb_icon(dropped, mob/living/carbon/update_on)
	. = ..()
	for(var/image/sprite as anything in .)
		sprite.pixel_w -= 16

/obj/item/bodypart/arm/right/experiment
	icon = EXPIE_BODYPARTS
	// Human-shaped wounds don't fit; the rig draws the Experiment's own (see experiment.dm).
	dmg_overlay_type = null
	icon_static = EXPIE_BODYPARTS
	limb_id = SPECIES_EXPERIMENT
	should_draw_greyscale = FALSE

/obj/item/bodypart/arm/right/experiment/get_limb_icon(dropped, mob/living/carbon/update_on)
	. = ..()
	for(var/image/sprite as anything in .)
		sprite.pixel_w -= 16

/obj/item/bodypart/leg/left/experiment
	icon = EXPIE_BODYPARTS
	// Human-shaped wounds don't fit; the rig draws the Experiment's own (see experiment.dm).
	dmg_overlay_type = null
	icon_static = EXPIE_BODYPARTS
	limb_id = SPECIES_EXPERIMENT
	should_draw_greyscale = FALSE
	footprint_sprite = FOOTPRINT_SPRITE_PAWS

/obj/item/bodypart/leg/left/experiment/get_limb_icon(dropped, mob/living/carbon/update_on)
	. = ..()
	for(var/image/sprite as anything in .)
		sprite.pixel_w -= 16

/obj/item/bodypart/leg/right/experiment
	icon = EXPIE_BODYPARTS
	// Human-shaped wounds don't fit; the rig draws the Experiment's own (see experiment.dm).
	dmg_overlay_type = null
	icon_static = EXPIE_BODYPARTS
	limb_id = SPECIES_EXPERIMENT
	should_draw_greyscale = FALSE
	footprint_sprite = FOOTPRINT_SPRITE_PAWS

/obj/item/bodypart/leg/right/experiment/get_limb_icon(dropped, mob/living/carbon/update_on)
	. = ..()
	for(var/image/sprite as anything in .)
		sprite.pixel_w -= 16

#undef EXPIE_BODYPARTS
