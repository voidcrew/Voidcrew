/**
 * Every roundstart species is animated like the Experiment: always rigged, on a generated body a
 * quarter bigger than a human with their own head on top (see humanoid_rig.dm). The Overanimated
 * quirk is left for anyone else human-shaped.
 *
 * Tails (lizard, felinid) come off the torso onto the tail bone and swing from the small of the
 * back, with every breath and pose. See limb_rig.dm for the keys.
 */

/// The generated body: its sprites, bones, and how clothes are stretched onto it.
#define HUMANOID_RIG_BODY \
	"always" = TRUE, \
	"optional" = TRUE, \
	"rig_type" = /datum/limb_rig/sprites/humanoid, \
	"sprites" = 'voidcrew/modules/limb_rig/icons/humanoid.dmi', \
	"cloth_masks" = 'voidcrew/modules/limb_rig/icons/humanoid_cloth_masks.dmi', \
	"skeleton" = list( \
		"south" = list("l_arm" = list(list(22.85, 24.9), list(22.98, 19.4), list(22.85, 14.1)), "r_arm" = list(list(10.15, 24.9), list(10.02, 19.4), list(10.15, 14.1)), "l_leg" = list(list(19.05, 15.1), list(19.05, 8.7), list(19.05, 2.7), list(19.05, 0.5)), "r_leg" = list(list(13.95, 15.1), list(13.95, 8.7), list(13.95, 2.7), list(13.95, 0.5)), "head" = list(16.5, 26.7), "crown" = list(16.5, 35.3), "chest" = list(16.5, 14.5), "tail" = list(16.5, 15.7)), \
		"north" = list("l_arm" = list(list(10.15, 24.9), list(10.02, 19.4), list(10.15, 14.1)), "r_arm" = list(list(22.85, 24.9), list(22.98, 19.4), list(22.85, 14.1)), "l_leg" = list(list(13.95, 15.1), list(13.95, 8.7), list(13.95, 2.7), list(13.95, 0.5)), "r_leg" = list(list(19.05, 15.1), list(19.05, 8.7), list(19.05, 2.7), list(19.05, 0.5)), "head" = list(16.5, 26.7), "crown" = list(16.5, 35.3), "chest" = list(16.5, 14.5), "tail" = list(16.5, 15.7)), \
		"east" = list("l_arm" = list(list(15.7, 24.9), list(15.7, 19.4), list(15.9, 14.1)), "r_arm" = list(list(15.7, 24.9), list(15.7, 19.4), list(15.9, 14.1)), "l_leg" = list(list(16.5, 15.1), list(16.65, 8.7), list(16.4, 2.7), list(16.4, 0.5)), "r_leg" = list(list(16.5, 15.1), list(16.65, 8.7), list(16.4, 2.7), list(16.4, 0.5)), "head" = list(16.8, 26.7), "crown" = list(16.8, 35.3), "chest" = list(16.5, 14.5), "tail" = list(14.3, 15.7)), \
		"west" = list("l_arm" = list(list(17.3, 24.9), list(17.3, 19.4), list(17.1, 14.1)), "r_arm" = list(list(17.3, 24.9), list(17.3, 19.4), list(17.1, 14.1)), "l_leg" = list(list(16.5, 15.1), list(16.35, 8.7), list(16.6, 2.7), list(16.6, 0.5)), "r_leg" = list(list(16.5, 15.1), list(16.35, 8.7), list(16.6, 2.7), list(16.6, 0.5)), "head" = list(16.2, 26.7), "crown" = list(16.2, 35.3), "chest" = list(16.5, 14.5), "tail" = list(18.7, 15.7)), \
	), \
	"leg_rest" = list(2, 4, 2), \
	"hat_scale" = 1.25, \
	"item_scale" = 1.25, \
	"paw_height" = 2.8, \
	"torso_width" = 1.12, \
	"torso_depth" = 0.95, \
	"cloth_widths" = list("thigh" = 1.3, "shin" = 1.05, "arm" = 1.4, "forearm" = 1.05)

/datum/species/human
	limb_rig_shape = list(HUMANOID_RIG_BODY)

/datum/species/human/felinid
	limb_rig_shape = list(
		HUMANOID_RIG_BODY,
		// Tail carried a touch high.
		"posture" = list(RIG_TAIL = list("lift" = 8)),
	)

/datum/species/lizard
	limb_rig_shape = list(
		HUMANOID_RIG_BODY,
		// A slight forward lean, chin up to make up for it, the tail carried up behind.
		"posture" = list(
			RIG_CHEST = list("bend" = 6),
			RIG_HEAD = list("nod" = -5),
			RIG_TAIL = list("lift" = 12),
		),
	)

/datum/species/moth
	limb_rig_shape = list(HUMANOID_RIG_BODY)

/datum/species/plasmaman
	limb_rig_shape = list(HUMANOID_RIG_BODY)

/datum/species/ethereal
	limb_rig_shape = list(HUMANOID_RIG_BODY)

#undef HUMANOID_RIG_BODY
