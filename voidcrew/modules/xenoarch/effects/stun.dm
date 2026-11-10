// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/stun.dm.
// Voidcrew: Nova's touch put 200 stamina damage into one hand; touch now knocks you down briefly,
// auras sap stamina, bursts can floor a room. Logged like a weapon.

/datum/artifact_effect/stun
	label_name = "Knocks people down"
	log_name = "Stun"
	tier = ARTIFACT_TIER_UNCOMMON
	harmful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_PSIONIC, ARTIFACT_ENERGY_ORGANIC)

/datum/artifact_effect/stun/do_effect_touch(mob/living/user)
	if(sap(user, 45, 2 SECONDS))
		to_chat(user, span_warning("A jolt runs up your arm and your legs give out."))

/datum/artifact_effect/stun/do_effect_aura(seconds_per_tick)
	for(var/mob/living/target as anything in living_in_range())
		if(SPT_PROB(15, seconds_per_tick) && sap(target, 12))
			to_chat(target, span_warning("Your limbs go heavy for a moment."))

/datum/artifact_effect/stun/do_effect_pulse(power)
	for(var/mob/living/target as anything in living_in_range())
		if(sap(target, clamp(power * 2, 20, 70), power >= 20 ? 1.5 SECONDS : 0))
			to_chat(target, span_warning("A wave of force knocks the wind out of you!"))

/// Saps stamina and maybe knocks down. Returns TRUE if it took.
/datum/artifact_effect/stun/proc/sap(mob/living/target, stamina, knockdown = 0)
	if(target.stat != CONSCIOUS || issilicon(target))
		return FALSE
	var/exposure = artifact_exposure(target)
	if(exposure <= 0)
		return FALSE
	target.adjust_confusion_up_to(3 SECONDS * exposure, 10 SECONDS)
	target.adjustStaminaLoss(stamina * exposure)
	if(knockdown)
		target.Knockdown(knockdown * exposure)
	log_harm(target)
	return TRUE
