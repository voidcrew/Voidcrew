/**
 * # Voidcrew virology: symptom tiers (genetics)
 *
 * Level re-tier from tgstation #84356 / #89062 (hyperjll). The harmful Dormant DNA Activator
 * moves 6 -> 7, which is the mirror of its new beneficial counterpart sitting at the top of the
 * ladder (see voidcrew/modules/virology/symptoms/genetic_mutation.dm): the version that improves
 * a host should cost more to build than the version that wrecks them.
 *
 * Level only: stats, thresholds and procs are all inherited. See
 * code/modules/unit_tests/voidcrew_virology_tiers.dm for the whole map.
 */
/datum/symptom/genetic_mutation
	level = 7
