/**
 * # Anemia
 *
 * Ported from tgstation #84356 / #89062 (hyperjll). Level 12. The virus eats the host's blood:
 * at stage 4+ it drains blood_volume every tick while the host is at or above normal volume, and
 * with the resistance threshold met it keeps draining past that point until the host starts
 * suffocating.
 *
 * The visible/messaging side is deliberately quiet (base_message_chance 5) so a victim reads as
 * "weirdly pale and tired" before the blood loss is obviously the cause - which is the point of a
 * slow-loss symptom.
 *
 * ## Deviation from the ported copy
 *
 * The threshold label and the code disagreed: `threshold_descs` advertised "Resistance 10" while
 * `Start()` gated on `totalResistance() >= 8`. The labels are player-facing (the virus designer
 * shows them as the unlock conditions), so the label is what changed here - the gate stays at 8,
 * which keeps the shipped behaviour identical. The Stealth 6 threshold matched already.
 */
/datum/symptom/anemia
	name = "Anemia"
	desc = "The virus eats the host's blood cells to sustain itself."
	stealth = 0
	resistance = 1
	stage_speed = -1
	transmittable = 1
	severity = 5
	level = 12
	base_message_chance = 5
	symptom_delay_min = 1
	symptom_delay_max = 1
	threshold_descs = list(
		"Resistance 8" = "The virus can consume large amounts of blood, leading to suffocation.",
		"Stealth 6" = "This symptom remains hidden until active.",
	)
	var/nobloodlimit = FALSE
	var/stealthy = FALSE

/datum/symptom/anemia/Start(datum/disease/advance/A)
	. = ..()
	if(!.)
		return
	if(A.totalResistance() >= 8) //blood regeneration
		nobloodlimit = TRUE
	if(A.totalStealth() >= 6)
		stealthy = TRUE

/datum/symptom/anemia/Activate(datum/disease/advance/advanced_disease)
	. = ..()
	if(!.)
		return

	var/mob/living/carbon/infected_mob = advanced_disease.affected_mob
	switch(advanced_disease.stage)
		if(1, 2, 3)
			if(prob(base_message_chance) && !stealthy)
				to_chat(infected_mob, span_warning("[pick("Your body begins to sweat.", "You notice how sickly you look.", "It's getting harder to concentrate.")]"))
		if(4, 5)
			if(nobloodlimit && infected_mob.blood_volume < BLOOD_VOLUME_NORMAL)
				infected_mob.blood_volume -= 1
			if(infected_mob.blood_volume > BLOOD_VOLUME_NORMAL)
				infected_mob.blood_volume -= 1
	return
