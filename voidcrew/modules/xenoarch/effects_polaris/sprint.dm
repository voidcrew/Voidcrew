// Artifact effect: sprint.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/sprinting.dm.
// Voidcrew: uncommon, not common (design catalogue); a short movement-speed status effect with a
// fading afterimage, instead of Polaris' /datum/modifier; doses never stack past a minute.

/datum/artifact_effect/bestow/sprint
	label_name = "Speeds people up"
	log_name = "Sprint"
	tier = ARTIFACT_TIER_UNCOMMON
	helpful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_CONCENTRATED, ARTIFACT_ENERGY_PSIONIC)
	status_type = /datum/status_effect/artifact/sprint
	touch_duration = 45 SECONDS
	pulse_duration = 25 SECONDS
	aura_duration = 8 SECONDS

/datum/artifact_effect/bestow/sprint/on_bestowed(mob/living/target)
	if(issilicon(target))
		to_chat(target, span_notice("Your actuators whine up to a higher pitch."))
	else
		to_chat(target, span_notice("Your legs fill with a restless spring."))
	playsound(target, 'sound/effects/magic/tail_swing.ogg', 20, TRUE, SILENCED_SOUND_EXTRARANGE)

/datum/artifact_effect/bestow/sprint/on_renewed(mob/living/target)
	to_chat(target, span_notice("Your legs itch to run."))
