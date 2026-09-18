/**
 * # Insomnia
 *
 * Ported from tgstation #84356 / #89062 (hyperjll). Level 12, and the beneficial counterpart to
 * Narcolepsy (which sits one tier below at 7): the host cannot be put to sleep, and at stage 5
 * runs a slow stamina drain unless the Resistance 8 threshold is met.
 *
 * Being unable to fall asleep sounds like a penalty until you remember what sleeping does to a
 * disease - `stage_act()` hands out DISEASE_GOOD_SLEEPING_RECOVERY_BONUS per sleeping aid, and
 * being knocked out is also how a lot of antagonists and stuns remove you from a fight. A crew
 * member carrying this cannot be slept, sedated or cured by a nap.
 *
 * ## Deviation from the ported copy
 *
 * The original had no `End()` override, so TRAIT_SLEEPIMMUNE - granted in `on_stage_change()` -
 * was only ever removed by a later stage change. Curing the virus while the host was at stage 4+
 * left the trait applied forever, i.e. a permanently un-sleepable crew member. The cleanup here
 * matches what every other trait-granting symptom in heal.dm does (see self-respiration and
 * Plasma Fixation: on_stage_change adds, End removes).
 */
/datum/symptom/insomnia
	name = "Insomnia"
	desc = "The virus alters brain patterns within the host, suppressing the brain's natural sleep functionality."
	stealth = -1
	resistance = 0
	stage_speed = 0
	transmittable = 2
	level = 12
	symptom_delay_min = 30
	symptom_delay_max = 85
	threshold_descs = list(
		"Resistance 8" = "The stamina drain no longer occurs.",
	)
	var/stamdrain = TRUE

/datum/symptom/insomnia/Start(datum/disease/advance/A)
	. = ..()
	if(!.)
		return
	if(A.totalResistance() >= 8)
		stamdrain = FALSE

/datum/symptom/insomnia/on_stage_change(datum/disease/advance/A)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/carbon/M = A.affected_mob
	if(A.stage >= 4)
		ADD_TRAIT(M, TRAIT_SLEEPIMMUNE, DISEASE_TRAIT)
	else
		REMOVE_TRAIT(M, TRAIT_SLEEPIMMUNE, DISEASE_TRAIT)
	return TRUE

/datum/symptom/insomnia/Activate(datum/disease/advance/A)
	. = ..()
	if(!.)
		return

	var/mob/living/M = A.affected_mob
	switch(A.stage)
		if(1, 2, 3, 4)
			if(prob(50))
				to_chat(M, span_notice("You suddenly find it difficult to blink."))

		if(5)
			if(stamdrain && (M.getStaminaLoss() < 20))
				M.adjustStaminaLoss(2.5)

/datum/symptom/insomnia/End(datum/disease/advance/A)
	. = ..()
	if(!.)
		return
	REMOVE_TRAIT(A.affected_mob, TRAIT_SLEEPIMMUNE, DISEASE_TRAIT)
