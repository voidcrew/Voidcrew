// Artifact effect: faraday.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/faraday.dm.
// Voidcrew: a status effect that swallows EMPs for the wearer and everything they carry
// (Polaris used a /datum/modifier); doses never stack past two minutes.

/datum/artifact_effect/bestow/faraday
	label_name = "EMP shielding"
	log_name = "Faraday"
	tier = ARTIFACT_TIER_UNCOMMON
	helpful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_ELECTROMAGNETIC, ARTIFACT_ENERGY_PARTICLE)
	status_type = /datum/status_effect/artifact/faraday
	touch_duration = 90 SECONDS
	pulse_duration = 30 SECONDS
	aura_duration = 10 SECONDS

/datum/artifact_effect/bestow/faraday/on_bestowed(mob/living/target)
	if(issilicon(target))
		to_chat(target, span_notice("Your sensors go quiet. Background interference: none."))
	else
		to_chat(target, span_notice("The hair on your arms lies flat, and a cold hush settles over your skin."))
	playsound(target, 'sound/effects/magic/magic_block.ogg', 20, TRUE, SILENCED_SOUND_EXTRARANGE)

/datum/artifact_effect/bestow/faraday/on_renewed(mob/living/target)
	to_chat(target, span_notice("The hush on your skin deepens."))
