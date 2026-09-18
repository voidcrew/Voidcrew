/**
 * # Voidcrew virology: symptom tiers (sleep)
 *
 * Level re-tier from tgstation #84356 / #89062 (hyperjll). Narcolepsy moves 6 -> 7, one tier
 * below the new Insomnia symptom (see voidcrew/modules/virology/symptoms/insomnia.dm): the
 * harmful "you cannot stay awake" and the beneficial "you cannot be put to sleep" are now
 * separate purchases rather than one being strictly better than the other.
 *
 * Level only: stats, thresholds and procs are all inherited. See
 * code/modules/unit_tests/voidcrew_virology_tiers.dm for the whole map.
 */
/datum/symptom/narcolepsy
	level = 7
