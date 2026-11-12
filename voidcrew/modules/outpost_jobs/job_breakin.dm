/**
 * # Outpost jobs: break-ins
 *
 * Owner: P5. Spec 6.3 (the safe and its ledger) and 6.5 (a bag out of the evidence locker). The safe is excluded
 * from ship saves (GLOB.outpost_checkpoint_excluded).
 */

/datum/mission/fixer_job/breakin
	job_kind = FIXER_JOB_BREAKIN
	base_pay = FIXER_PAY_BREAKIN
	duration = FIXER_TIME_BREAKIN
	trust_tier = FIXER_TRUST_TIER1
	slate_weight = FIXER_WEIGHT_BREAKIN

/datum/mission/fixer_job/breakin/evidence
	job_kind = FIXER_JOB_EVIDENCE
	base_pay = FIXER_PAY_EVIDENCE
	duration = FIXER_TIME_EVIDENCE
	trust_tier = FIXER_TRUST_TIER2
	slate_weight = FIXER_WEIGHT_EVIDENCE

/// The safe the job brings
/obj/structure/safe/fixer

/// The ledger inside it
/obj/item/mission_recovery/fixer_goods/ledger

/// The evidence bag
/obj/item/mission_recovery/fixer_goods/evidence

/// The slip with the safe's combination
/obj/item/paper/fixer_slip

/// The clerk who carries the slip
/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk
