// Artifact effect: life steal.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/lifesteal.dm.
// Voidcrew: heals one person by taking the same amount from everyone else in reach, split between
// them. It only takes what it gives, so nothing happens unless the person it feeds is hurt, and
// what it gives goes through the shared artifact healing cap: it is a slow trickle, never a
// medbay and never a weapon. Who it feeds: the hand on it, the person carrying it, or for a burst
// the nearest hurt person. Every theft is logged.

/datum/artifact_effect/life_steal
	label_name = "Steals life"
	log_name = "Life steal"
	tier = ARTIFACT_TIER_EXTREME
	harmful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_ORGANIC, ARTIFACT_ENERGY_CONCENTRATED)
	allowed_release_methods = list(ARTIFACT_RELEASE_TOUCH, ARTIFACT_RELEASE_PULSE)

/datum/artifact_effect/life_steal/do_effect_touch(mob/living/user)
	if(!steal_for(user, 10))
		to_chat(user, span_notice("Something in [holder] reaches for you, then lets go."))

/datum/artifact_effect/life_steal/do_effect_pulse(power)
	steal_for(pick_beneficiary(), clamp(power * 0.4, 5, 15))

/// Whoever a burst feeds: the person carrying it, else the nearest hurt person in reach.
/datum/artifact_effect/life_steal/proc/pick_beneficiary()
	var/atom/carrier = get_atom_on_turf(holder)
	if(isliving(carrier))
		return carrier
	var/turf/center = source_turf()
	if(!center)
		return null
	var/mob/living/best
	var/best_distance = INFINITY
	for(var/mob/living/candidate in living_in_range())
		if(candidate.stat == DEAD || candidate.getBruteLoss() + candidate.getFireLoss() <= 0)
			continue
		var/distance = get_dist(center, candidate)
		if(distance < best_distance)
			best = candidate
			best_distance = distance
	return best

/**
 * Heals `beneficiary` by up to `amount`, taken from everyone else in reach.
 * Returns the amount healed.
 */
/datum/artifact_effect/life_steal/proc/steal_for(mob/living/beneficiary, amount)
	if(!beneficiary || beneficiary.stat == DEAD)
		return 0
	var/wanted = min(amount, beneficiary.getBruteLoss() + beneficiary.getFireLoss(), artifact_heal_allowance(beneficiary))
	if(wanted <= 0)
		return 0
	var/list/victims = list()
	for(var/mob/living/victim in living_in_range())
		if(victim == beneficiary || victim.stat == DEAD || artifact_exposure(victim) <= 0)
			continue
		victims += victim
	if(!length(victims))
		return 0
	// What each victim can give: an even share, less for those in protective gear.
	var/list/shares = list()
	var/offered = 0
	for(var/mob/living/victim as anything in victims)
		var/share = wanted / length(victims) * artifact_exposure(victim)
		shares[victim] = share
		offered += share
	if(offered <= 0)
		return 0
	var/healed = artifact_capped_heal(beneficiary, offered)
	if(healed <= 0)
		return 0
	// Everyone gives up exactly their part of what was healed.
	var/scale = healed / offered
	for(var/mob/living/victim as anything in shares)
		victim.take_overall_damage(shares[victim] * scale)
		victim.Beam(beneficiary, icon_state = "lichbeam", time = 1.5 SECONDS)
		to_chat(victim, span_danger("Warmth bleeds out of you and runs toward [beneficiary]."))
		log_harm(victim)
	new /obj/effect/temp_visual/heal(get_turf(beneficiary), "#b0306a")
	to_chat(beneficiary, span_notice("Stolen warmth floods into you, and your wounds pull shut."))
	playsound(beneficiary, 'sound/effects/magic/exit_blood.ogg', 35, TRUE)
	return healed
