/**
 * # Outpost jobs: jailbreak
 *
 * Owner: P7. Spec 6.6: an NPC prisoner held in a real cell through the cell's ward list (police_cell.dm, P0 seam:
 * hold_ward(), drop_ward(), cell_for_ward(), cell_of_ward(), COMSIG_OUTPOST_POLICE_CELL_FORCED).
 */

/datum/mission/fixer_job/jailbreak
	job_kind = FIXER_JOB_JAILBREAK
	base_pay = FIXER_PAY_JAILBREAK
	duration = FIXER_TIME_JAILBREAK
	trust_tier = FIXER_TRUST_TIER2
	slate_weight = FIXER_WEIGHT_JAILBREAK
	noise_floor = FIXER_JAILBREAK_FLOOR

/// The prisoner
/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward
