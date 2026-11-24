// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/blood.dm.
// Voidcrew: blood_volume set directly (Nova's adjust_blood_volume() doesn't exist here); regen stops
// at a normal amount; drain never takes anyone below the point where they start to pass out.

/datum/artifact_effect/blood
	tier = ARTIFACT_TIER_RARE
	possible_kinds = list(ARTIFACT_ENERGY_ORGANIC)

/// Whether `target` has blood to work on.
/datum/artifact_effect/blood/proc/bleeds(mob/living/target)
	return target.stat != DEAD && target.blood_volume > 0 && !HAS_TRAIT(target, TRAIT_NOBLOOD)

/datum/artifact_effect/blood/regen
	label_name = "Restores blood"
	log_name = "Blood regeneration"
	helpful = TRUE

/datum/artifact_effect/blood/regen/do_effect_touch(mob/living/user)
	if(restore(user, 20))
		to_chat(user, span_notice("Your body feels full, somehow."))

/datum/artifact_effect/blood/regen/do_effect_aura(seconds_per_tick)
	for(var/mob/living/target as anything in living_in_range())
		if(restore(target, 2 * seconds_per_tick) && prob(10))
			to_chat(target, span_notice("Your chest feels warm."))

/datum/artifact_effect/blood/regen/do_effect_pulse(power)
	for(var/mob/living/target as anything in living_in_range())
		if(restore(target, power * 1.5))
			to_chat(target, span_notice("Warmth floods through your veins."))

/datum/artifact_effect/blood/regen/proc/restore(mob/living/target, amount)
	if(!bleeds(target) || target.blood_volume >= BLOOD_VOLUME_NORMAL)
		return FALSE
	target.blood_volume = min(BLOOD_VOLUME_NORMAL, target.blood_volume + amount * artifact_exposure(target))
	return TRUE

/datum/artifact_effect/blood/drain
	label_name = "Drains blood"
	log_name = "Blood drain"
	harmful = TRUE

/datum/artifact_effect/blood/drain/do_effect_touch(mob/living/user)
	if(bleed(user, 40))
		to_chat(user, span_warning("Blood beads up through the skin of your palm!"))

/datum/artifact_effect/blood/drain/do_effect_aura(seconds_per_tick)
	for(var/mob/living/target as anything in living_in_range())
		if(bleed(target, 2 * seconds_per_tick) && prob(10))
			to_chat(target, span_warning("Your nose starts to bleed."))

/datum/artifact_effect/blood/drain/do_effect_pulse(power)
	for(var/mob/living/target as anything in living_in_range())
		if(bleed(target, power))
			to_chat(target, span_warning("You feel suddenly light-headed."))
			target.add_splatter_floor(get_turf(target), small_drip = TRUE)

/datum/artifact_effect/blood/drain/proc/bleed(mob/living/target, amount)
	if(!bleeds(target) || target.blood_volume <= BLOOD_VOLUME_OKAY)
		return FALSE
	target.blood_volume = max(BLOOD_VOLUME_OKAY, target.blood_volume - amount * artifact_exposure(target))
	log_harm(target)
	return TRUE
