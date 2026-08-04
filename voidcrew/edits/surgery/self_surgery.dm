/**
 * Anyone can operate on themselves.
 *
 * Upstream gates surgery-on-yourself behind TRAIT_SELF_SURGERY, and the only thing that
 * hands that trait out is the 4U70-P3R4710N skillchip, sold on a black market this fork
 * does not ship. A hull flies with a handful of people and often no doctor at all, so in
 * practice an injury that needs surgery would be untreatable until someone else is both
 * aboard and willing.
 *
 * The operation API already prices unaided self-surgery: TRAIT_SELF_SURGERY on an
 * operation that is not OPERATION_SELF_OPERABLE imparts the slower speed and the flat
 * failure penalty natively (see the trait checks in
 * code/modules/surgery/operations/_operation.dm). Granting the trait innately to every
 * carbon is therefore the entire edit - a crew that has a medic is still better off
 * using them. The 4U70-P3R4710N skillchip still installs and reads as a Self Surgery
 * skill; it just grants a trait everyone already has.
 */

/mob/living/carbon/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_SELF_SURGERY, INNATE_TRAIT)
