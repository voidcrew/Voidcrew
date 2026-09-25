/**
 * # Nutritional Healing
 *
 * Ported from tgstation #84356 / #89062 (hyperjll). Level 11, and the first healing symptom that
 * pays for itself out of a resource the host controls: it only mends tissue while the host is
 * genuinely full, and it burns nutrition to do it. That makes it the one healing symptom a crew
 * can keep running indefinitely as long as they keep eating - a supply-ship fantasy rather than a
 * combat one.
 *
 * Resistance 1 / stage_speed 1 / transmittable 1 make it mildly self-supporting, which is why it
 * is priced at 11 despite healing slowly.
 *
 * ## Deviation from the ported copy
 *
 * The original tracked the fat-regen multiplier in a `var/fatregenmult` on the symptom datum, but
 * it is only ever read and written within `Heal()`. It is a local now, so the datum cannot carry
 * stale state between calls. Behaviour is identical.
 */
/datum/symptom/heal/calorie
	name = "Nutritional Healing"
	desc = "The virus uses newly obtained nutrients inside the body to repair damaged tissue cells. Most effective on well-fed hosts."
	stealth = 0
	resistance = 1
	stage_speed = 1
	transmittable = 1
	level = 11
	passive_message = span_notice("Your body feels like it's healing...")
	required_organ = ORGAN_SLOT_LIVER
	threshold_descs = list(
		"Stage Speed 5" = "Being obese allows for slow regeneration.",
	)
	var/fatregen = FALSE

/datum/symptom/heal/calorie/Start(datum/disease/advance/A)
	. = ..()
	if(!.)
		return
	if(A.totalStageSpeed() >= 5)
		fatregen = TRUE

/datum/symptom/heal/calorie/Heal(mob/living/carbon/infected_mob, datum/disease/advance/A, actual_power)
	if(infected_mob.getBruteLoss() || infected_mob.getFireLoss() || infected_mob.getToxLoss())
		// If we are fat and have fat regen, multiply heals by 2
		var/fatregenmult = (fatregen && HAS_TRAIT_FROM(infected_mob, TRAIT_FAT, OBESITY)) ? 2 : 1
		// If we have a full stomach, begin healing us && let's also prevent cheese by ensuring you HAVE to be able to get fat.
		if(infected_mob.nutrition > NUTRITION_LEVEL_FULL && !HAS_TRAIT(infected_mob, TRAIT_NOFAT))
			infected_mob.adjustBruteLoss(-0.2 * fatregenmult)
			infected_mob.adjustFireLoss(-0.2 * fatregenmult)
			infected_mob.adjustToxLoss(-0.1 * fatregenmult)
			// If we have a full stomach, but aren't fat, make us hungry (no free lipliocide)
			if(!HAS_TRAIT_FROM(infected_mob, TRAIT_FAT, OBESITY))
				infected_mob.adjust_nutrition(-0.2)

/datum/symptom/heal/calorie/passive_message_condition(mob/living/carbon/infected_mob)
	if(infected_mob.getBruteLoss() || infected_mob.getFireLoss())
		return TRUE

	return FALSE
