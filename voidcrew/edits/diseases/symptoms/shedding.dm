/**
 * # Voidcrew virology: symptom tiers (hair loss)
 *
 * Level re-tier from tgstation #84356 / #89062 (hyperjll). Alopecia drops 4 -> 3: it is purely
 * cosmetic and was priced above genuinely disruptive symptoms like deafness and confusion, so
 * it now sits in the cheap nuisance tier where it belongs. It also had no business being as
 * expensive as the symptom that makes you vomit blood.
 *
 * Level only: stats, thresholds and procs are all inherited. See
 * code/modules/unit_tests/voidcrew_virology_tiers.dm for the whole map.
 */
/datum/symptom/shedding
	level = 3
