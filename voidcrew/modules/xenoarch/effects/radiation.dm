// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/radiate.dm.
// Voidcrew: lower aura chances (Nova reached 100% per tick); exposure logged.

/datum/artifact_effect/radiation
	label_name = "Radiation"
	log_name = "Radiation"
	tier = ARTIFACT_TIER_RARE
	harmful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_PARTICLE, ARTIFACT_ENERGY_ORGANIC)
	/// How hot it runs, 1 to 5
	var/intensity = 1

/datum/artifact_effect/radiation/setup()
	intensity = rand(1, 5)

/datum/artifact_effect/radiation/copy_settings_to(datum/artifact_effect/radiation/copy)
	copy.intensity = intensity

/datum/artifact_effect/radiation/do_effect_touch(mob/living/user)
	var/turf/here = source_turf()
	if(!here)
		return
	radiation_pulse(here, max_range = 1, threshold = RAD_MEDIUM_INSULATION, chance = 50)
	log_harm(user)

/datum/artifact_effect/radiation/do_effect_aura(seconds_per_tick)
	var/turf/here = source_turf()
	if(!here)
		return
	radiation_pulse(here, max_range = range, threshold = RAD_MEDIUM_INSULATION, chance = 4 + intensity * 2)
	log_nearby()

/datum/artifact_effect/radiation/do_effect_pulse(power)
	var/turf/here = source_turf()
	if(!here)
		return
	radiation_pulse(here, max_range = range, threshold = RAD_MEDIUM_INSULATION, chance = clamp(power, 10, 50))
	log_nearby()

/datum/artifact_effect/radiation/proc/log_nearby()
	for(var/mob/living/carbon/human/target in living_in_range())
		log_harm(target)
