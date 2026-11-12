// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/sleepy.dm.
// Voidcrew: drowsiness first, then short sleeps (Nova slept you 25 seconds per touch).

/datum/artifact_effect/sleepy
	label_name = "Puts people to sleep"
	log_name = "Sleep"
	tier = ARTIFACT_TIER_UNCOMMON
	harmful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_PSIONIC, ARTIFACT_ENERGY_ORGANIC)

/datum/artifact_effect/sleepy/do_effect_touch(mob/living/user)
	lull(user, 30 SECONDS, 4 SECONDS)

/datum/artifact_effect/sleepy/do_effect_aura(seconds_per_tick)
	for(var/mob/living/carbon/target in living_in_range())
		if(SPT_PROB(30, seconds_per_tick))
			lull(target, 4 SECONDS)

/datum/artifact_effect/sleepy/do_effect_pulse(power)
	for(var/mob/living/carbon/target in living_in_range())
		lull(target, power * 0.8 SECONDS, power >= 30 ? 3 SECONDS : 0)

/// Makes `target` drowsy (up to 40 seconds) and maybe nod off.
/datum/artifact_effect/sleepy/proc/lull(mob/living/target, drowsy, nap = 0)
	if(!iscarbon(target) || target.stat == DEAD)
		return
	var/exposure = artifact_exposure(target)
	if(exposure <= 0)
		return
	if(prob(25))
		to_chat(target, span_notice(pick("You feel a yawn coming on.", "Your eyelids are heavy.", "You could do with a nap.")))
	target.adjust_drowsiness_up_to(drowsy * exposure, 40 SECONDS)
	if(nap)
		target.Sleeping(nap * exposure)
	log_harm(target)
