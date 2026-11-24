// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/emp.dm.
// Voidcrew: smaller pulses (Nova's light radius reached ten tiles); logged.

/datum/artifact_effect/emp
	label_name = "EMP"
	log_name = "EMP"
	tier = ARTIFACT_TIER_RARE
	harmful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_ELECTROMAGNETIC)
	allowed_release_methods = list(ARTIFACT_RELEASE_PULSE)

/datum/artifact_effect/emp/do_effect_pulse(power)
	var/turf/here = source_turf()
	if(!here)
		return
	var/light_range = clamp(range - 1, 1, 6)
	empulse(here, round(light_range / 3), light_range)
	for(var/mob/living/carbon/human/target in living_in_range())
		log_harm(target)
