/**
 * # Voidcrew virology: symptom tiers (healing)
 *
 * Level re-tier from tgstation #84356 / #89062 (hyperjll). This is the largest single file in
 * the re-tier, and it is the one that matters most: beneficial symptoms were previously cheap
 * enough that a viro could stack several at once, which is why the old ladder felt like it had
 * no cost. Every healing symptom except Regenerative Coma now sits at 8 or above, so a healing
 * virus is a genuine investment:
 *
 *   Starlight Condensation   6 -> 9    (light-dependent, so it is free healing in the open)
 *   Toxolysis                7 -> 10   (heart required, purges chems)
 *   Metabolic Boost          7 -> 10   (stomach required, speeds metabolism)
 *   Nocturnal Regeneration   6 -> 8    (darkness-dependent)
 *   Regenerative Coma        8 -> 11   (retuned separately, see below)
 *   Tissue Hydration         6 -> 9    (liver required)
 *   Plasma Fixation          8 -> 10   (liver required, plasma exposure)
 *   Radioactive Resonance    6 -> 8
 *
 * Regenerative Coma's BEHAVIOUR is also deliberately changed - it now arms two seconds after the
 * host is actually in crit instead of at a raw brute/burn threshold - and that lives in
 * voidcrew/edits/diseases/symptoms/coma.dm so this file stays a pure level map.
 *
 * Levels only here: stats, thresholds and procs are all inherited. See
 * code/modules/unit_tests/voidcrew_virology_tiers.dm for the whole map.
 */
/datum/symptom/heal/starlight
	level = 9

/datum/symptom/heal/chem
	level = 10

/datum/symptom/heal/metabolism
	level = 10

/datum/symptom/heal/darkness
	level = 8

/datum/symptom/heal/coma
	level = 11

/datum/symptom/heal/water
	level = 9

/datum/symptom/heal/plasma
	level = 10

/datum/symptom/heal/radiation
	level = 8
