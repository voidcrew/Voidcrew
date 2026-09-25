/**
 * # Voidcrew virology: symptom tiers (species adaptation)
 *
 * Level re-tier from tgstation #84356 / #89062 (hyperjll). Both adaptation symptoms move 5 -> 6,
 * but only Necrotic Metabolism also gets new stats - it is the ported "nobody ever used this"
 * buff, because its old numbers (stealth 2 / resistance -2 / transmittable 0) made a symptom
 * whose entire point is letting a virus thrive in a corpse cost more than it gave back:
 *
 *   stealth       2 -> 1     (resurrection is meant to be noticed, that is the horror)
 *   resistance   -2 -> 1     (it no longer fights the disease it is part of)
 *   transmittable 0 -> 1     (a corpse-hopping virus can spread from a corpse)
 *
 * These four var assignments are the only non-level change in the whole re-tier. Everything
 * else - OnAdd/OnRemove, thresholds, procs - is inherited.
 */
/datum/symptom/undead_adaptation
	stealth = 1
	resistance = 1
	transmittable = 1
	level = 6

/datum/symptom/inorganic_adaptation
	level = 6
