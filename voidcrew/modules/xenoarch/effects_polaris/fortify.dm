// Artifact effect: fortify.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/fortify.dm, also in
// VOREStation (9335d66b9fdf). Voidcrew: a short status effect taking 15% off brute and burn
// (Polaris used a /datum/modifier); doses never stack past a minute and a half.

/datum/artifact_effect/bestow/fortify
	label_name = "Toughens skin"
	log_name = "Fortify"
	tier = ARTIFACT_TIER_UNCOMMON
	helpful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_CONCENTRATED, ARTIFACT_ENERGY_ORGANIC)
	status_type = /datum/status_effect/artifact/fortify
	touch_duration = 60 SECONDS
	pulse_duration = 30 SECONDS
	aura_duration = 10 SECONDS

/datum/artifact_effect/bestow/fortify/on_bestowed(mob/living/target)
	if(issilicon(target))
		to_chat(target, span_notice("Your plating hums and stiffens."))
	else
		to_chat(target, span_notice("Your skin tightens and goes tough as old leather."))
	playsound(target, 'sound/effects/magic/fleshtostone.ogg', 20, TRUE, SILENCED_SOUND_EXTRARANGE)

/datum/artifact_effect/bestow/fortify/on_renewed(mob/living/target)
	to_chat(target, span_notice("Your skin tightens again."))
