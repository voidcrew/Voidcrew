/**
 * # Outpost recovery: the janitors
 *
 * Owner: R4 (spec-rehydrate.md 3.2 and 3.3, M33, M34). A real mop wetted at the closet's bucket
 * (recovery.closet_turf), tg's own wash on each tile, and a trash bag for a fixed list of litter. Nothing
 * structural is repaired (decision 18). Their stops are the police beat routes' stops (group.routes).
 *
 * Frozen by R0: the type and the proc names and signatures below. Behaviour at R0: every stop is clean.
 */

/// Mops up and bags the litter
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor
	name = "outpost janitor"
	desc = "Outpost cleaning staff."

/// Whether patrol stop `stop` still has a body or a mess within OUTPOST_RECOVERY_STOP_RANGE
/datum/outpost_recovery/proc/stop_dirty(turf/stop)
	return FALSE

/// A worker on `stop` found it clean
/datum/outpost_recovery/proc/mark_clean(turf/stop)
	return

/// The share of patrol stops that are clean, 0 to 1
/datum/outpost_recovery/proc/clean_share()
	return 1
