// Artifact effect: feysight.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/feysight.dm, also in
// VOREStation (9335d66b9fdf). Voidcrew: a status effect giving thermal sight (living things show
// through walls) with a faint green tint, instead of Polaris' /datum/modifier. The first dose
// still costs a pounding headache, as in Polaris. Doses never stack past 45 seconds.

#define ARTIFACT_FEYSIGHT_HEADACHE 10

/datum/artifact_effect/bestow/feysight
	label_name = "Second sight"
	log_name = "Feysight"
	tier = ARTIFACT_TIER_RARE
	helpful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_PSIONIC)
	status_type = /datum/status_effect/artifact/feysight
	touch_duration = 30 SECONDS
	pulse_duration = 20 SECONDS
	aura_duration = 8 SECONDS
	aura_chance = 8

/datum/artifact_effect/bestow/feysight/can_bestow(mob/living/target)
	return iscarbon(target) && target.stat != DEAD

/datum/artifact_effect/bestow/feysight/on_bestowed(mob/living/target)
	to_chat(target, span_hypnophrase("The walls go thin as paper, and through them, warm shapes move."))
	to_chat(target, span_warning("The inside of your head hurts..."))
	target.adjustStaminaLoss(ARTIFACT_FEYSIGHT_HEADACHE)
	playsound(target, 'sound/effects/magic/magic_block_mind.ogg', 20, TRUE, SILENCED_SOUND_EXTRARANGE)

/datum/artifact_effect/bestow/feysight/on_renewed(mob/living/target)
	to_chat(target, span_hypnophrase("The shapes behind the walls sharpen."))

#undef ARTIFACT_FEYSIGHT_HEADACHE
