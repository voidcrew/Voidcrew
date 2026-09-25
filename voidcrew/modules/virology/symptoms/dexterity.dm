/**
 * # Muscular Dexterity
 *
 * Ported from tgstation #84356 / #89062 (hyperjll). Level 11. All progress bar actions are 5%
 * faster, and the thresholds stack real utility on top: another 5% at Resistance 7, faster
 * carrying at Stage Speed 2, faster surgery at 4, faster construction at 6. It is the symptom you
 * give a working crew - it does nothing for a fight except let you build the thing you are
 * fighting with slightly sooner.
 *
 * Every effect it applies is a trait or a speed modifier keyed to DISEASE_TRAIT, so the whole lot
 * is removed on stage drop and again in `End()` - a cured host must not keep the buffs.
 *
 * Movement speed is one of the Stage Speed 2 effects: see
 * voidcrew/modules/virology/speed_modifiers.dm for why that buff moved here from an orphan
 * reagent the PR never wired up.
 */
/datum/symptom/actionspd
	name = "Muscular Dexterity"
	desc = "The virus stimulates and compresses the muscles within the host, speeding up progress bar actions by 5%."
	stealth = -2
	resistance = 0
	stage_speed = 0
	transmittable = 0
	level = 11
	symptom_delay_min = 1
	symptom_delay_max = 1
	threshold_descs = list(
		"Resistance 7" = "All progress bar actions are sped up by an additional 5%.",
		"Stage Speed 2" = "The host moves faster and carries bodies more easily.",
		"Stage Speed 4" = "Surgery is faster.",
		"Stage Speed 6" = "Construction is faster.",
	)
	var/buffed = FALSE
	var/bodycarryspd = FALSE
	var/surgeryspd = FALSE
	var/constructspd = FALSE

/datum/symptom/actionspd/Start(datum/disease/advance/A)
	. = ..()
	if(!.)
		return
	if(A.totalResistance() >= 7)
		buffed = TRUE
	if(A.totalStageSpeed() >= 2)
		bodycarryspd = TRUE
	if(A.totalStageSpeed() >= 4)
		surgeryspd = TRUE
	if(A.totalStageSpeed() >= 6)
		constructspd = TRUE

/datum/symptom/actionspd/on_stage_change(datum/disease/advance/A)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/carbon/M = A.affected_mob
	if(A.stage >= 4)
		if(buffed)
			M.add_actionspeed_modifier(/datum/actionspeed_modifier/diseasestimbuffed)
		else
			M.add_actionspeed_modifier(/datum/actionspeed_modifier/diseasestim)

		if(bodycarryspd)
			ADD_TRAIT(M, TRAIT_QUICKER_CARRY, DISEASE_TRAIT)
			M.add_movespeed_modifier(/datum/movespeed_modifier/viro_dexterity)
		if(surgeryspd)
			ADD_TRAIT(M, TRAIT_FASTMED, DISEASE_TRAIT)
		if(constructspd)
			ADD_TRAIT(M, TRAIT_QUICK_BUILD, DISEASE_TRAIT)
	else
		M.remove_actionspeed_modifier(/datum/actionspeed_modifier/diseasestimbuffed)
		M.remove_actionspeed_modifier(/datum/actionspeed_modifier/diseasestim)

		REMOVE_TRAIT(M, TRAIT_QUICKER_CARRY, DISEASE_TRAIT)
		REMOVE_TRAIT(M, TRAIT_FASTMED, DISEASE_TRAIT)
		REMOVE_TRAIT(M, TRAIT_QUICK_BUILD, DISEASE_TRAIT)
		M.remove_movespeed_modifier(/datum/movespeed_modifier/viro_dexterity)
	return TRUE

/datum/symptom/actionspd/End(datum/disease/advance/A)
	. = ..()
	if(!.)
		return
	A.affected_mob.remove_actionspeed_modifier(/datum/actionspeed_modifier/diseasestimbuffed)
	A.affected_mob.remove_actionspeed_modifier(/datum/actionspeed_modifier/diseasestim)
	A.affected_mob.remove_movespeed_modifier(/datum/movespeed_modifier/viro_dexterity)

	REMOVE_TRAIT(A.affected_mob, TRAIT_QUICKER_CARRY, DISEASE_TRAIT)
	REMOVE_TRAIT(A.affected_mob, TRAIT_FASTMED, DISEASE_TRAIT)
	REMOVE_TRAIT(A.affected_mob, TRAIT_QUICK_BUILD, DISEASE_TRAIT)
