/**
 * # Bluespace Manifestation
 *
 * Ported from tgstation #84356 / #89062 (hyperjll). Top of the ladder (12): the host becomes
 * leaky to bluespace and randomly teleports. On a shuttle this is much more dangerous than it is
 * on a station - a bad roll can put a crew member outside their own hull - which is exactly why
 * it sits behind an endgame reagent rather than in the middle of the ladder.
 *
 * Costs are in line with the other level-12 symptoms: it is loud (stealth -4) and it fights the
 * disease that carries it (transmittable 2, resistance 2, stage_speed 2), so it is a violence
 * symptom, not something you staple onto a healing virus.
 *
 * Two changes from the ported copy:
 *   - The description said "suseptible"; that is a typo and it is player-visible text, so it now
 *     reads "susceptible".
 *   - `!M.reagents.has_reagent(/datum/reagent/bluespace)` is an anti-stacking guard that stops
 *     the symptom re-dosing a host who is already bluespace-contaminated.
 */
/datum/symptom/bluespace
	name = "Bluespace Manifestation"
	desc = "The virus becomes susceptible to foreign bluespace energies and will randomly manifest these energies within the host, leading to spontaneous teleportation."
	stealth = -4
	resistance = 2
	stage_speed = 2
	transmittable = 2
	level = 12
	severity = 6

/datum/symptom/bluespace/Activate(datum/disease/advance/A)
	. = ..()
	if(!.)
		return
	var/mob/living/M = A.affected_mob
	switch(A.stage)
		if(1)
			if(prob(10))
				to_chat(M, span_notice("You feel rather unstable..."))
		if(2, 3)
			if(prob(10))
				to_chat(M, span_danger("You feel like you're in two places at once..."))
		if(4, 5)
			if(prob(5) && !M.reagents.has_reagent(/datum/reagent/bluespace))
				M.reagents.add_reagent(/datum/reagent/bluespace, 10)
