/**
 * # Voidcrew virology: symptom tiers (tissue destruction)
 *
 * Level re-tier from tgstation #84356 / #89062 (hyperjll). Necrotizing Fasciitis moves up one
 * tier (7) and Autophagocytosis Necrosis - which eats the host's flesh and kills them outright -
 * goes to 10, so the two are no longer neighbours you can accidentally roll together at a
 * mid-ladder budget.
 *
 * Levels only: stats, thresholds and procs are all inherited. See
 * code/modules/unit_tests/voidcrew_virology_tiers.dm for the whole map.
 */
/datum/symptom/flesh_eating
	level = 7

/datum/symptom/flesh_death
	level = 10
