/**
 * # Voidcrew virology: symptom tiers (airway)
 *
 * Level re-tier from tgstation #84356 / #89062 (hyperjll). The ladder now runs 1-12 so
 * `Evolve()` has a real choice at every rung, instead of the top-heavy clustering upstream had -
 * a doctor who wanted a specific build usually had to take whatever the high tiers gave them.
 * Choking's cheap tier (2, alongside fever/chills/vomiting) and its lethal tier (9, alongside
 * the other organ-failure symptoms) both come from that redistribution.
 *
 * Levels only: every stat, threshold, message and proc below is inherited untouched, so if
 * upstream retunes this symptom the rest of it still tracks. The full before/after level map
 * lives in code/modules/unit_tests/voidcrew_virology_tiers.dm.
 */
/datum/symptom/choking
	level = 2

/datum/symptom/asphyxiation
	level = 9
