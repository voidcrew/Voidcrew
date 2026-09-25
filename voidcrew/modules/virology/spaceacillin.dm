/**
 * # Voidcrew virology: spaceacillin can end a disease outright
 *
 * Ported from tgstation #84356 / #89062 (hyperjll). Upstream's spaceacillin only ever gives
 * TRAIT_VIRUS_RESISTANCE (a 50% slowdown on the disease's stage progression, plus a recovery
 * bonus in `stage_act()`); the ported PR adds the actual cure roll below.
 *
 * This is deliberately the strongest thing in the whole port. It also touches nearly every
 * disease in the game - including the beneficial viruses this same port spends the rest of its
 * effort making worth building - so the numbers are worth spelling out before a balance pass:
 *
 *   metabolization_rate = 0.1 * REAGENTS_METABOLISM, so a 10u pill metabolises in ~100 ticks.
 *   prob(0.2) per tick over ~100 ticks is a ~18% chance to cure anything you are carrying.
 *
 * It fires per tick, not per pill, and it cures EVERY disease on the mob rather than one, so a
 * crew member who is running a nasty engineered virus and a useful one at the same time can lose
 * both. If it proves too strong in play the levers in order of least disruption are: drop the
 * probability, cure only one disease per roll, or skip DISEASE_SEVERITY_POSITIVE diseases so it
 * cannot delete a beneficial virus.
 *
 * The tox-loss line is the same purity-scaled trickle other medicines use, so a low-purity batch
 * is worse for you as well as weaker.
 */
/datum/reagent/medicine/spaceacillin/on_mob_life(mob/living/carbon/M, seconds_per_tick, times_fired)
	. = ..()
	var/need_mob_update
	need_mob_update += M.adjustToxLoss(-0.1 * REM * normalise_creation_purity() * seconds_per_tick, updating_health = FALSE)
	if(need_mob_update)
		return UPDATE_MOB_HEALTH

	if((M.mob_biotypes & MOB_ORGANIC) && prob(0.2))
		for(var/thing in M.diseases) // can clean viruses from organic lifeforms.
			var/datum/disease/D = thing
			D.cure()
