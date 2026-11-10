// Tutorial checklist hooks. Part C: cyberware install and surgery hooks.
// Overrides chain with any others of the same proc; each returns the parent's value unchanged.

/// Chrome credits the body that receives it; a surgeon gets credit under Surgery instead.
/obj/item/organ/cyberimp/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	if(!special && organ_owner?.ckey)
		tutorial_credit(organ_owner, TUTORIAL_STEP_CHROME_INSTALL)

/obj/item/organ/eyes/robotic/cyberware/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	if(!special && organ_owner?.ckey)
		tutorial_credit(organ_owner, TUTORIAL_STEP_CHROME_INSTALL)

/datum/surgery_step/initiate(mob/living/user, mob/living/target, target_zone, obj/item/tool, datum/surgery/surgery, try_to_fail = FALSE)
	tutorial_credit(user, TUTORIAL_STEP_SURGERY_START)
	return ..()

/// Credited before the parent, which qdels the surgery. Not COMSIG_MOB_SURGERY_FINISHED:
/// that fires from Destroy(), including for cancelled operations.
/datum/surgery/complete(mob/surgeon)
	tutorial_credit(surgeon, TUTORIAL_STEP_SURGERY_FINISH)
	return ..()

/// Every dissection tier inherits this step. The body's dissection_points_paid grows by
/// exactly what the notes are worth, so a rise means research was actually earned.
/datum/surgery_step/experimental_dissection/success(mob/user, mob/living/target, target_zone, obj/item/tool, datum/surgery/surgery, default_display_results = FALSE)
	var/paid_before = target?.dissection_points_paid
	. = ..()
	if(target && target.dissection_points_paid > paid_before)
		tutorial_credit(user, TUTORIAL_STEP_SURGERY_DISSECT)
