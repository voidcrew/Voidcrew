// Artifact effect: animate.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/animate_anomaly.dm,
// also in VOREStation (9335d66b9fdf). Voidcrew: the artifact itself lurches one step at a time
// toward the nearest person (or away from a hand laid on it). It only moves with an ordinary
// Move(), so walls, doors and people stop it, and it never steps into space, open air, lava or a
// chasm. Bolted down, it strains against the bolts instead. Not harvestable: only an artifact
// can walk. No destroy burst.

/datum/artifact_effect/animate
	label_name = "Moves on its own"
	log_name = "Animate"
	tier = ARTIFACT_TIER_COMMON
	harvestable = FALSE
	possible_kinds = list(ARTIFACT_ENERGY_PSIONIC, ARTIFACT_ENERGY_BLUESPACE)
	/// Who it is following
	var/datum/weakref/quarry_ref
	/// Throttles the lurch and strain messages
	COOLDOWN_DECLARE(message_cooldown)

/datum/artifact_effect/animate/setup()
	range = max(range, 3)

/datum/artifact_effect/animate/Destroy(force)
	quarry_ref = null
	return ..()

/datum/artifact_effect/animate/do_effect_touch(mob/living/user)
	var/obj/machinery/artifact/artifact = holder
	if(!istype(artifact) || !isturf(artifact.loc))
		return
	if(lurch(get_step_away(artifact, user)))
		artifact.visible_message(span_warning("[artifact] lurches away from [user]!"))

/datum/artifact_effect/animate/do_effect_aura(seconds_per_tick)
	stalk()

/datum/artifact_effect/animate/do_effect_pulse(power)
	for(var/step in 1 to clamp(round(power / 12), 1, 3))
		if(!stalk())
			return

/datum/artifact_effect/animate/do_effect_destroy()
	return

/// One step toward whoever it is following. Returns TRUE if it moved.
/datum/artifact_effect/animate/proc/stalk()
	var/obj/machinery/artifact/artifact = holder
	if(!istype(artifact) || !isturf(artifact.loc))
		return FALSE
	var/mob/living/quarry = find_quarry()
	if(!quarry)
		return FALSE
	artifact.setDir(get_dir(artifact, quarry))
	if(get_dist(artifact, quarry) <= 1)
		return FALSE
	if(!lurch(get_step_to(artifact, quarry)))
		return FALSE
	if(COOLDOWN_FINISHED(src, message_cooldown))
		COOLDOWN_START(src, message_cooldown, 8 SECONDS)
		artifact.visible_message(span_warning("[artifact] lurches toward [quarry]."))
	return TRUE

/// Steps onto `destination` if it can stand there. Returns TRUE if it moved.
/datum/artifact_effect/animate/proc/lurch(turf/destination)
	var/obj/machinery/artifact/artifact = holder
	if(!istype(artifact) || !isturf(destination) || destination.z != artifact.z)
		return FALSE
	if(isspaceturf(destination) || isgroundlessturf(destination) || islava(destination) || ischasm(destination))
		return FALSE
	if(artifact.anchored)
		strain(artifact)
		return FALSE
	var/turf/start = artifact.loc
	if(!artifact.Move(destination, get_dir(start, destination)) || artifact.loc == start)
		return FALSE
	playsound(artifact, pick('sound/effects/footstep/heavy1.ogg', 'sound/effects/footstep/heavy2.ogg'), 40, TRUE)
	hop(artifact)
	return TRUE

/// Bolted down, it rocks against the bolts.
/datum/artifact_effect/animate/proc/strain(obj/machinery/artifact/artifact)
	playsound(artifact, 'sound/effects/creak/creak1.ogg', 35, TRUE)
	var/shove = pick(-3, 3)
	animate(artifact, pixel_x = artifact.base_pixel_x + shove, time = 0.1 SECONDS, flags = ANIMATION_PARALLEL)
	animate(pixel_x = artifact.base_pixel_x, time = 0.2 SECONDS)
	if(COOLDOWN_FINISHED(src, message_cooldown))
		COOLDOWN_START(src, message_cooldown, 8 SECONDS)
		artifact.visible_message(span_warning("[artifact] strains against its bolts."))

/// A heavy little hop.
/datum/artifact_effect/animate/proc/hop(obj/machinery/artifact/artifact)
	animate(artifact, pixel_z = 4, time = 0.1 SECONDS, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)
	animate(pixel_z = 0, time = 0.15 SECONDS, easing = SINE_EASING | EASE_IN)

/**
 * The person it follows: the last one while they stay close and awake, else the nearest
 * conscious mob in range, preferring people with a mind over animals.
 */
/datum/artifact_effect/animate/proc/find_quarry()
	var/turf/center = source_turf()
	if(!center)
		return null
	var/mob/living/quarry = quarry_ref?.resolve()
	if(quarry && quarry.stat == CONSCIOUS && quarry.z == center.z && get_dist(center, quarry) <= range)
		return quarry
	quarry = null
	var/quarry_distance = INFINITY
	var/quarry_has_mind = FALSE
	for(var/mob/living/candidate in living_in_range())
		if(candidate.stat != CONSCIOUS)
			continue
		var/has_mind = !!candidate.mind
		var/distance = get_dist(center, candidate)
		if(quarry_has_mind && !has_mind)
			continue
		if((has_mind && !quarry_has_mind) || distance < quarry_distance)
			quarry = candidate
			quarry_distance = distance
			quarry_has_mind = has_mind
	quarry_ref = quarry ? WEAKREF(quarry) : null
	return quarry
