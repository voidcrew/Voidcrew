/**
 * # Outpost jobs: assassination
 *
 * Owner: P6. Spec 6.4: a visitor the job brings, and proof that he is dead.
 */

/datum/mission/fixer_job/hit
	job_kind = FIXER_JOB_HIT
	base_pay = FIXER_PAY_HIT
	duration = FIXER_TIME_HIT
	trust_tier = FIXER_TRUST_TIER1
	slate_weight = FIXER_WEIGHT_HIT

/// The mark
/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark

/// Proof of a hit
/obj/item/mission_recovery/fixer_goods/proof
