/**
 * # Voidcrew virology: symptom tiers (burning)
 *
 * Level re-tier from tgstation #84356 / #89062 (hyperjll). Both burning symptoms move deeper
 * into the ladder: Spontaneous Combustion joins the hazardous-reagent tier (8) and Alkali
 * Perspiration - which can set a host alight repeatedly and is the single nastiest thing a
 * viro can hand out - moves to 11, so it needs an endgame reagent to reach.
 *
 * Levels only: stats, thresholds and procs are all inherited. See
 * code/modules/unit_tests/voidcrew_virology_tiers.dm for the whole map.
 */
/datum/symptom/fire
	level = 8

/datum/symptom/alkali
	level = 11
