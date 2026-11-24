// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/disgust.dm.
// Voidcrew: nausea that builds, rather than one touch that empties your stomach.

/datum/artifact_effect/disgust
	label_name = "Nausea"
	log_name = "Disgust"
	tier = ARTIFACT_TIER_UNCOMMON
	minor = TRUE
	harmful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_PSIONIC, ARTIFACT_ENERGY_ORGANIC)

/datum/artifact_effect/disgust/do_effect_touch(mob/living/user)
	sicken(user, 50)

/datum/artifact_effect/disgust/do_effect_aura(seconds_per_tick)
	for(var/mob/living/carbon/target in living_in_range())
		if(SPT_PROB(40, seconds_per_tick))
			sicken(target, 4)

/datum/artifact_effect/disgust/do_effect_pulse(power)
	for(var/mob/living/carbon/target in living_in_range())
		sicken(target, clamp(power * 1.5, 10, 60))

/datum/artifact_effect/disgust/proc/sicken(mob/living/target, amount)
	if(!iscarbon(target) || target.stat == DEAD)
		return
	var/exposure = artifact_exposure(target)
	if(exposure <= 0)
		return
	if(prob(30))
		to_chat(target, span_warning(pick("Your stomach turns over.", "You don't feel so good.", "Your mouth floods with spit.")))
	target.adjust_disgust(amount * exposure)
	log_harm(target)
