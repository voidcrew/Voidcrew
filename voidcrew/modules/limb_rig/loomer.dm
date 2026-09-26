/**
 * Loomer.
 *
 * An admin smite: the limb rig draws you with legs four and a half times their length, arms
 * three times, long fingers, a permanent stoop so you still fit through doors, and a long
 * loping walk. In combat mode with your hands empty you reach out, arms straight, fingers
 * creeping longer, trembling all over.
 *
 * It needs the Overanimated quirk, since that's what gives you a rig to stretch, and hands it
 * out if it's missing. Taking the quirk away takes this with it.
 *
 * Loosely after the Serverblight and DOORS' Figure, minus the blindness: you see fine. It's
 * all looks; nothing about how you play changes.
 */
GLOBAL_LIST_INIT(loomer_rig_shape, list(
	"arm_stretch" = 3.2,
	"leg_stretch" = 4.5,
	"finger_stretch" = 3,
	"walk" = RIG_WALK_LOPE,
	"menace" = TRUE,
	// Stooped: back bent, head craned up to see where it's going, arms hanging out in front,
	// knees never quite straight.
	"posture" = list(
		RIG_CHEST = list("bend" = 40),
		RIG_HEAD = list("nod" = -30),
		RIG_L_ARM = list("swing" = 18, "raise" = 6, "elbow" = 20),
		RIG_R_ARM = list("swing" = 18, "raise" = 6, "elbow" = 20),
		RIG_L_LEG = list("swing" = 10, "knee" = 22),
		RIG_R_LEG = list("swing" = 10, "knee" = 22),
	),
))

/mob/living/carbon
	/// Whether the limb rig draws this mob as a Loomer. Set by the smite.
	var/limb_rig_loomer = FALSE

/// Makes someone a Loomer, or turns a Loomer back.
/datum/smite/loomer
	name = "Loomer"

/datum/smite/loomer/effect(client/user, mob/living/target)
	. = ..()
	if(!ishuman(target))
		to_chat(user, span_warning("This must be used on a human."), confidential = TRUE)
		return
	var/mob/living/carbon/human/victim = target
	if(victim.limb_rig_loomer)
		victim.limb_rig_loomer = FALSE
		to_chat(victim, span_notice("Your limbs settle back to a sensible length."))
	else
		victim.add_quirk(/datum/quirk/overanimated, announce = FALSE)
		victim.limb_rig_loomer = TRUE
		to_chat(victim, span_warning("You feel very, very tall."))
	victim.update_limb_rig()
