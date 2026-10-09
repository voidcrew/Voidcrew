/**
 * Milkies.
 *
 * An Experiment subspecies from Casualties Unknown's Gunsaw (SAW-03): colour-swapped and built
 * short. Fluffy white fur, cyan eyes on black, short white horns, a flatter snout and fins down
 * the back, on legs half as long as an Experiment's. Otherwise they're Experiments through and
 * through: the same voice, claws, frailty and yellow blood.
 *
 * Their pieces are the Experiment's own, recoloured, with the legs squashed to half their length
 * and everything above the hips drawn 13 pixels lower to meet them.
 */
/datum/species/experiment/milkie
	name = "Milkie"
	plural_form = "Milkies"
	id = SPECIES_MILKIE
	bodypart_overrides = list(
		BODY_ZONE_HEAD = /obj/item/bodypart/head/experiment/milkie,
		BODY_ZONE_CHEST = /obj/item/bodypart/chest/experiment/milkie,
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left/experiment/milkie,
		BODY_ZONE_R_ARM = /obj/item/bodypart/arm/right/experiment/milkie,
		BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/experiment/milkie,
		BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right/experiment/milkie,
	)
	limb_rig_shape = list(
		"always" = TRUE,
		"rig_type" = /datum/limb_rig/sprites/experiment/milkie,
		"sprites" = 'voidcrew/modules/expie/icons/milkie_rig.dmi',
		"cloth_masks" = 'voidcrew/modules/expie/icons/cloth_masks.dmi',
		"damage" = 'voidcrew/modules/expie/icons/milkie_damage.dmi',
		// The Experiment's, with the legs half as long and the rest brought down to meet them.
		"skeleton" = list(
			"south" = list("l_arm" = list(list(19.96, 24.04), list(19.85, 18.27), list(19.96, 12.11)), "r_arm" = list(list(12.04, 24.04), list(12.15, 18.27), list(12.04, 12.11)), "l_leg" = list(list(18.56, 12.97), list(18.93, 9.17), list(18.93, 6.07), list(18.78, 0)), "r_leg" = list(list(13.44, 12.97), list(13.07, 9.17), list(13.07, 6.07), list(13.22, 0)), "head" = list(16, 25.31), "crown" = list(16, 39), "chest" = list(16, 12.8), "tail" = list(16, 14.26)),
			"north" = list("l_arm" = list(list(12.04, 24.04), list(12.15, 18.27), list(12.04, 12.11)), "r_arm" = list(list(19.96, 24.04), list(19.85, 18.27), list(19.96, 12.11)), "l_leg" = list(list(13.44, 12.97), list(13.07, 9.17), list(13.07, 6.07), list(13.22, 0)), "r_leg" = list(list(18.56, 12.97), list(18.93, 9.17), list(18.93, 6.07), list(18.78, 0)), "head" = list(16, 25.31), "crown" = list(16, 39), "chest" = list(16, 12.8), "tail" = list(16, 14.26)),
			"east" = list("l_arm" = list(list(15.89, 24.04), list(15.46, 18.27), list(16.05, 12.11)), "r_arm" = list(list(15.89, 24.04), list(15.46, 18.27), list(16.05, 12.11)), "l_leg" = list(list(16, 12.97), list(16, 9.17), list(16, 6.07), list(16, 0)), "r_leg" = list(list(16, 12.97), list(16, 9.17), list(16, 6.07), list(16, 0)), "head" = list(15.7, 25.31), "crown" = list(16, 39), "chest" = list(15.71, 12.8), "tail" = list(12.71, 14.26)),
			"west" = list("l_arm" = list(list(16.11, 24.04), list(16.54, 18.27), list(15.95, 12.11)), "r_arm" = list(list(16.11, 24.04), list(16.54, 18.27), list(15.95, 12.11)), "l_leg" = list(list(16, 12.97), list(16, 9.17), list(16, 6.07), list(16, 0)), "r_leg" = list(list(16, 12.97), list(16, 9.17), list(16, 6.07), list(16, 0)), "head" = list(16.3, 25.31), "crown" = list(16, 39), "chest" = list(16.29, 12.8), "tail" = list(19.29, 14.26)),
		),
		"leg_rest" = list(27.4, 85.2, 74.3),
		"hat_scale" = 1.4,
		// Squashed paws.
		"paw_height" = 2,
		"torso_width" = 1.2,
		// Stubby legs, just as thick.
		"cloth_widths" = list("thigh" = 2.2, "shin" = 1.4, "arm" = 1.5, "forearm" = 1),
		"posture" = list(
			RIG_TAIL = list("lift" = 10),
		),
	)

/datum/limb_rig/sprites/experiment/milkie

/datum/species/experiment/milkie/get_physical_attributes()
	return "Milkies are short and stocky, with fluffy white fur, stubby digitigrade legs, cyan eyes on black, \
		short white horns, fins down the back and a huge spiky tail."

/datum/species/experiment/milkie/get_species_description()
	return "A short, fluffy white Experiment with cyan eyes, little horns and fins down its back."

/datum/species/experiment/milkie/get_species_lore()
	return list(
		"Experiments, only white, short and fluffy. The lab numbers on their manifests start SAW-03, \
		and whatever made them that way isn't in the paperwork either.",

		"They get underfoot, and they like it there. Nobody has ever managed to stay angry at one for long.",
	)

/mob/living/carbon/human/species/experiment/milkie
	race = /datum/species/experiment/milkie

// Previews and corpses (see bodyparts.dm).

#define MILKIE_BODYPARTS 'voidcrew/modules/expie/icons/milkie_bodyparts.dmi'

/obj/item/bodypart/head/experiment/milkie
	icon = MILKIE_BODYPARTS
	icon_static = MILKIE_BODYPARTS
	limb_id = SPECIES_MILKIE

/obj/item/bodypart/chest/experiment/milkie
	icon = MILKIE_BODYPARTS
	icon_static = MILKIE_BODYPARTS
	limb_id = SPECIES_MILKIE

/obj/item/bodypart/arm/left/experiment/milkie
	icon = MILKIE_BODYPARTS
	icon_static = MILKIE_BODYPARTS
	limb_id = SPECIES_MILKIE

/obj/item/bodypart/arm/right/experiment/milkie
	icon = MILKIE_BODYPARTS
	icon_static = MILKIE_BODYPARTS
	limb_id = SPECIES_MILKIE

/obj/item/bodypart/leg/left/experiment/milkie
	icon = MILKIE_BODYPARTS
	icon_static = MILKIE_BODYPARTS
	limb_id = SPECIES_MILKIE

/obj/item/bodypart/leg/right/experiment/milkie
	icon = MILKIE_BODYPARTS
	icon_static = MILKIE_BODYPARTS
	limb_id = SPECIES_MILKIE

#undef MILKIE_BODYPARTS
