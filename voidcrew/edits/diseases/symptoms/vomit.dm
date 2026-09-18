/**
 * # Voidcrew virology: symptom tiers (vomiting)
 *
 * Level re-tier from tgstation #84356 / #89062 (hyperjll). Vomiting drops 3 -> 2, joining
 * fever/chills/choking in the cheap tier. It is disruptive rather than damaging, and the old
 * placement meant a viro had to fight the ladder for the symptom that also happens to be the
 * main way a virus spreads through a ship's corridors (`/datum/symptom/vomit`'s whole gimmick
 * is airborne spread from vomit), which made early spread builds impractical.
 *
 * `/datum/symptom/vomit/nebula` is deliberately untouched - it is a nebula-specific variant.
 *
 * Level only: stats, thresholds and procs are all inherited. See
 * code/modules/unit_tests/voidcrew_virology_tiers.dm for the whole map.
 */
/datum/symptom/vomit
	level = 2
