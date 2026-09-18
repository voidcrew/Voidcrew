/**
 * # Voidcrew virology: symptom tiers (voice)
 *
 * Level re-tier from tgstation #84356 / #89062 (hyperjll). Voice Change moves 6 -> 9. It is the
 * purest "you cannot rely on your voice" symptom in the game - it defeats voice authentication
 * and makes the host unrecognisable in a crowd - so it belongs with the organ-failure tier
 * rather than the mid ladder.
 *
 * Level only: stats, thresholds and procs are all inherited. See
 * code/modules/unit_tests/voidcrew_virology_tiers.dm for the whole map.
 */
/datum/symptom/voice_change
	level = 9
