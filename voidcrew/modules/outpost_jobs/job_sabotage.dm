/**
 * # Outpost jobs: sabotage
 *
 * Owner: P3. Spec 6.1: a structure the job places, with its keeper; wrecking or quietly ruining it is the deed.
 * P0 declared the types. The target is excluded from ship saves (GLOB.outpost_checkpoint_excluded).
 */

/datum/mission/fixer_job/sabotage
	job_kind = FIXER_JOB_SABOTAGE
	base_pay = FIXER_PAY_SABOTAGE
	duration = FIXER_TIME_SABOTAGE
	slate_weight = FIXER_WEIGHT_SABOTAGE

/// A sabotage target the job placed (the freight consignment, the drinks machine, the data rack). P3 subtypes it.
/obj/structure/fixer_target
	name = "freight crate"
	desc = "A sealed crate of somebody's freight."
	icon = 'icons/obj/storage/crates.dmi'
	icon_state = "crate"
	density = TRUE
	anchored = TRUE

/// The person who minds a sabotage target
/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper
