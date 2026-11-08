// Artifact effect: poltergeist.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/poltergeist.dm, also in
// VOREStation (9335d66b9fdf). Voidcrew: picks a loose object lying near the artifact, lifts it for a
// moment (time to duck) and hurls it at the nearest person. Only small and medium items lying on
// the floor fly; nothing is pulled from hands, bags or tables' contents, and a thrown object only
// hits as hard as its own weight allows. Logged like a weapon.

/// How long an object hangs in the air before it flies
#define ARTIFACT_POLTERGEIST_WINDUP (0.8 SECONDS)

/datum/artifact_effect/poltergeist
	label_name = "Throws things"
	log_name = "Poltergeist"
	tier = ARTIFACT_TIER_RARE
	harmful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_PSIONIC, ARTIFACT_ENERGY_BLUESPACE)

/datum/artifact_effect/poltergeist/do_effect_touch(mob/living/user)
	lift_and_throw(user)

/datum/artifact_effect/poltergeist/do_effect_aura(seconds_per_tick)
	if(SPT_PROB(15, seconds_per_tick))
		lift_and_throw(nearest_target())

/datum/artifact_effect/poltergeist/do_effect_pulse(power)
	var/mob/living/target = nearest_target()
	if(!target)
		return
	var/throws = power >= 30 ? 2 : 1
	for(var/i in 1 to throws)
		lift_and_throw(target)

/// Smashed, it flings what is near it at once, with no warning.
/datum/artifact_effect/poltergeist/do_effect_destroy()
	var/mob/living/target = nearest_target()
	var/obj/item/missile = find_missile(target)
	if(target && missile)
		hurl(WEAKREF(missile), WEAKREF(target))

/// The closest conscious mob in range, preferring people with a mind over animals.
/datum/artifact_effect/poltergeist/proc/nearest_target()
	var/turf/center = source_turf()
	if(!center)
		return null
	var/mob/living/best
	var/best_distance = INFINITY
	var/best_has_mind = FALSE
	for(var/mob/living/candidate in living_in_range())
		if(candidate.stat != CONSCIOUS || candidate == artifact_effect_visible_source(holder))
			continue
		var/has_mind = !!candidate.mind
		var/distance = get_dist(center, candidate)
		if(best_has_mind && !has_mind)
			continue
		if((has_mind && !best_has_mind) || distance < best_distance)
			best = candidate
			best_distance = distance
			best_has_mind = has_mind
	return best

/// A loose item on the floor within its reach, not right under `target`'s feet.
/datum/artifact_effect/poltergeist/proc/find_missile(mob/living/target)
	var/turf/center = source_turf()
	if(!center || !target)
		return null
	var/list/candidates = list()
	for(var/obj/item/thing in range(range, center))
		if(!isturf(thing.loc) || thing.anchored || thing.w_class > WEIGHT_CLASS_BULKY)
			continue
		if((thing.item_flags & ABSTRACT) || HAS_TRAIT(thing, TRAIT_NODROP) || thing.throwforce <= 0)
			continue
		if(get_dist(thing, target) < 2)
			continue
		candidates += thing
	return length(candidates) ? pick(candidates) : null

/// Lifts something toward `target`; it flies after a short windup. Returns TRUE if it lifted one.
/datum/artifact_effect/poltergeist/proc/lift_and_throw(mob/living/target)
	if(!target || target.stat == DEAD || !prob(100 * artifact_exposure(target)))
		return FALSE
	var/obj/item/missile = find_missile(target)
	if(!missile)
		return FALSE
	missile.visible_message(span_warning("[missile] lifts off the floor and turns toward [target]!"))
	playsound(missile, 'sound/effects/magic/summonitems_generic.ogg', 30, TRUE)
	animate(missile, pixel_z = 10, time = ARTIFACT_POLTERGEIST_WINDUP, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)
	var/atom/origin = artifact_effect_visible_source(holder)
	origin?.Beam(missile, icon_state = "kinesis", time = ARTIFACT_POLTERGEIST_WINDUP)
	addtimer(CALLBACK(src, PROC_REF(hurl), WEAKREF(missile), WEAKREF(target)), ARTIFACT_POLTERGEIST_WINDUP, TIMER_DELETE_ME)
	return TRUE

/// Throws the lifted item, if it is still lying where it was lifted and the target still stands.
/datum/artifact_effect/poltergeist/proc/hurl(datum/weakref/missile_ref, datum/weakref/target_ref)
	var/obj/item/missile = missile_ref?.resolve()
	var/mob/living/target = target_ref?.resolve()
	if(!missile)
		return
	animate(missile, pixel_z = 0, time = 0.1 SECONDS, flags = ANIMATION_PARALLEL)
	if(!isturf(missile.loc) || !target || target.stat == DEAD || missile.z != target.z)
		return
	playsound(missile, 'sound/effects/magic/repulse.ogg', 30, TRUE)
	// Positional: some item overrides of throw_at() rename their arguments.
	missile.throw_at(target, range * 2, 3)
	log_harm(target)

#undef ARTIFACT_POLTERGEIST_WINDUP
