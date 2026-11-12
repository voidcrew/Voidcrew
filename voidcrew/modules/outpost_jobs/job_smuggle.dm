/**
 * # Outpost jobs: smuggle
 *
 * Owner: P4. Spec 6.2: a sealed case carried to another outpost's fixer, through a checkpoint scanner that refuses
 * it (the checkpoint calls fixer_is_contraband(), trade/outpost_checkpoint.dm).
 */

/datum/mission/fixer_job/smuggle
	job_kind = FIXER_JOB_SMUGGLE
	base_pay = FIXER_PAY_SMUGGLE
	duration = FIXER_TIME_SMUGGLE
	slate_weight = FIXER_WEIGHT_SMUGGLE

/// The sealed case
/obj/item/mission_recovery/fixer_goods/case

/// Whether the checkpoint scanner refuses `thing`: a case whose job is live. P4.
/proc/fixer_is_contraband(atom/movable/thing)
	return FALSE
