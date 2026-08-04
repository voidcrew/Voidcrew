/**
 * Anyone can operate on themselves.
 *
 * Upstream gates surgery-on-yourself behind TRAIT_SELF_SURGERY, and the only thing that
 * hands that trait out is the 4U70-P3R4710N skillchip, sold on a black market this fork
 * does not ship. The single exception is Hardware Manipulation, flagged
 * SURGERY_SELF_OPERABLE so synthetic crew can open their own chassis. Everything else -
 * a broken bone, an embedded round, a failing heart - needs a second pair of hands.
 *
 * That assumes a station with a medbay on it. A hull flies with a handful of people and
 * often no doctor at all, so in practice an injury that needs surgery is untreatable
 * until someone else is both aboard and willing. Granting the trait to every carbon
 * covers both places upstream checks for it: the menu built by
 * /datum/component/surgery_initiator, and the per-step check in /mob/living/item_interaction.
 *
 * Operating on yourself is still meant to be the worse option, so steps that were
 * previously off-limits carry the same fumble penalty the skillchip used to apply - a
 * crew that has a medic is better off using them. Surgeries upstream already allowed
 * self-serve keep their original difficulty.
 */

/// Added to the failure chance of each self-performed surgery step, as a flat percentage.
#define SELF_SURGERY_FAIL_PENALTY 33
/// Multiplier on how long each self-performed surgery step takes.
#define SELF_SURGERY_SPEED_PENALTY 1.5

/mob/living/carbon/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_SELF_SURGERY, INNATE_TRAIT)
	RegisterSignal(src, COMSIG_LIVING_INITIATE_SURGERY_STEP, PROC_REF(apply_self_surgery_penalty))

/mob/living/carbon/proc/apply_self_surgery_penalty(mob/living/carbon/_source, mob/living/user, mob/living/target, target_zone, obj/item/tool, datum/surgery/surgery, datum/surgery_step/step, list/modifiers)
	SIGNAL_HANDLER
	if(user != target)
		return
	// Hardware Manipulation and anything else already flagged self-operable was never
	// gated in the first place, so it is not made harder here.
	if(surgery.surgery_flags & SURGERY_SELF_OPERABLE)
		return
	modifiers[FAIL_PROB_INDEX] += SELF_SURGERY_FAIL_PENALTY
	modifiers[SPEED_MOD_INDEX] *= SELF_SURGERY_SPEED_PENALTY

/**
 * The skillchip now grants a trait that everyone already has, so the only thing it can
 * still contribute is a second copy of the penalty above - stacking it to a 66% fumble
 * chance and turning what used to be the enabling item into a pure downside. Its handler
 * is dropped instead; the chip still installs and reads as a Self Surgery skill, it just
 * no longer changes anything.
 */
/obj/item/skillchip/self_surgery/apply_surgery_penalty(mob/living/carbon/_source, mob/living/user, mob/living/target, target_zone, obj/item/tool, datum/surgery/surgery, datum/surgery_step/step, list/modifiers)
	SIGNAL_HANDLER
	return

#undef SELF_SURGERY_FAIL_PENALTY
#undef SELF_SURGERY_SPEED_PENALTY
