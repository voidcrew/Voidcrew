/**
 * # Voidcrew virology: symptom tiers (mental and sensory)
 *
 * Level re-tier from tgstation #84356 / #89062 (hyperjll). Both restoration symptoms move up a
 * tier - Mind Restoration 5 -> 6 and Sensory Restoration 4 -> 5 - keeping them just below the
 * healing cluster so a support virus still has to spend real budget on them.
 *
 * Levels only: stats, thresholds and procs are all inherited. See
 * code/modules/unit_tests/voidcrew_virology_tiers.dm for the whole map.
 */
/datum/symptom/mind_restoration
	level = 6

/datum/symptom/sensory_restoration
	level = 5
