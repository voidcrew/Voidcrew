/**
 * # Outpost jobs: goods and job people
 *
 * Owner: P2. The goods base (a mission item: never confiscated, never destroyed, never gear, deleted when its job
 * ends) and the setup every job person gets (spec 4.7). Job packages subtype the goods and call these.
 */

/// A fixer job's goods (the case, the ledger, the evidence bag, the proof of a hit). Job packages subtype it.
/obj/item/mission_recovery/fixer_goods

/// Binds this to `job`: it is the job's goods, and an outsider's hand on it spoils the job. P2.
/obj/item/mission_recovery/fixer_goods/proc/bind_job(datum/mission/fixer_job/job)
	return

/// A job person at `job`'s outpost: set_place(), the protections of spec 4.7, track(). P2.
/proc/fixer_job_npc_setup(mob/living/carbon/human/npc/ambient_npc/npc, datum/mission/fixer_job/job)
	return
