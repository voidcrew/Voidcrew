// Artifact effect: life drain.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/lifedrain.dm. Voidcrew:
// a sickly beam hooks into someone nearby; if they are still in reach a few seconds later, it
// tears a little life out of them (bruising, breathlessness and a spell of weakness). Stepping out
// of reach snaps the beam, so it can always be escaped. One beam per person at a time, people in
// a good biosuit are ignored (as in Polaris), and every drain is logged. Polaris healed the
// toucher with what it took; that is the extreme Life steal effect, so this only takes.

/// Seconds between the hook and the drain
#define ARTIFACT_DRAIN_WINDUP (3 SECONDS)

/datum/artifact_effect/life_drain
	label_name = "Drains life"
	log_name = "Life drain"
	tier = ARTIFACT_TIER_RARE
	harmful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_ORGANIC, ARTIFACT_ENERGY_CONCENTRATED)
	/// REF(victim) -> TRUE while a beam is hooked into them
	var/list/hooked = list()

/datum/artifact_effect/life_drain/Destroy(force)
	hooked = null
	return ..()

/datum/artifact_effect/life_drain/do_effect_touch(mob/living/user)
	hook(user, 10)

/datum/artifact_effect/life_drain/do_effect_aura(seconds_per_tick)
	for(var/mob/living/target in living_in_range())
		if(SPT_PROB(6, seconds_per_tick))
			hook(target, 5)

/datum/artifact_effect/life_drain/do_effect_pulse(power)
	var/list/victims = living_in_range()
	for(var/i in 1 to 2)
		if(!length(victims))
			return
		hook(pick_n_take(victims), clamp(power * 0.3, 4, 12))

/// Smashed, it lashes everyone in reach at once, with no warning.
/datum/artifact_effect/life_drain/do_effect_destroy()
	for(var/mob/living/target in living_in_range())
		if(can_hook(target))
			siphon(target, 6)

/// Whether `target` is somebody it can feed on.
/datum/artifact_effect/life_drain/proc/can_hook(mob/living/target)
	if(target.stat == DEAD || hooked?[REF(target)])
		return FALSE
	return artifact_exposure(target) >= 0.5

/// Hooks a beam into `target`; the drain lands after the windup if they stay. Returns TRUE if it hooked.
/datum/artifact_effect/life_drain/proc/hook(mob/living/target, damage)
	if(!can_hook(target))
		return FALSE
	var/atom/origin = artifact_effect_visible_source(holder)
	if(!isatom(origin))
		return FALSE
	var/key = REF(target)
	hooked[key] = TRUE
	playsound(target, 'sound/effects/magic/enter_blood.ogg', 35, TRUE)
	// Carried in a battery, it feeds on whoever holds it: no beam to step out of.
	if(origin == target)
		target.visible_message(
			span_danger("[target] shudders as something in [target.p_their()] grip starts to pull."),
			span_userdanger("Something in your grip hooks into you. Something cold starts to pull."),
		)
		addtimer(CALLBACK(src, PROC_REF(finish_hook), WEAKREF(target), null, key, damage, TRUE), ARTIFACT_DRAIN_WINDUP, TIMER_DELETE_ME)
		return TRUE
	var/datum/beam/drain_beam = origin.Beam(target, icon_state = "drain_life", time = ARTIFACT_DRAIN_WINDUP + 0.5 SECONDS, maxdistance = range + 1)
	target.visible_message(
		span_danger("A sickly beam lashes out from [origin] and hooks into [target]!"),
		span_userdanger("A sickly beam lashes out from [origin] and hooks into you. Something cold starts to pull."),
	)
	addtimer(CALLBACK(src, PROC_REF(finish_hook), WEAKREF(target), WEAKREF(drain_beam), key, damage), ARTIFACT_DRAIN_WINDUP, TIMER_DELETE_ME)
	return TRUE

/// The windup ended: drains `target` if the beam still holds them.
/datum/artifact_effect/life_drain/proc/finish_hook(datum/weakref/target_ref, datum/weakref/beam_ref, key, damage, held = FALSE)
	hooked -= key
	var/mob/living/target = target_ref?.resolve()
	var/datum/beam/drain_beam = beam_ref?.resolve()
	if(!target || target.stat == DEAD)
		qdel(drain_beam)
		return
	if(held)
		if(artifact_effect_visible_source(holder) != target)
			to_chat(target, span_notice("The cold hook slips out of you."))
			return
	else if(QDELETED(drain_beam))
		to_chat(target, span_notice("The cold hook slips out of you."))
		return
	qdel(drain_beam)
	siphon(target, damage)

/// Tears `damage` worth of life out of `target`.
/datum/artifact_effect/life_drain/proc/siphon(mob/living/target, damage)
	damage *= artifact_exposure(target)
	if(damage <= 0)
		return
	target.take_overall_damage(damage)
	target.adjustStaminaLoss(damage * 2)
	target.apply_status_effect(/datum/status_effect/artifact/exhausted, 10 SECONDS)
	new /obj/effect/temp_visual/heal(get_turf(target), "#7a1d3a")
	target.visible_message(
		span_danger("Something pale and shining is pulled out of [target]."),
		span_userdanger("Something is torn out of you. Your legs go weak."),
	)
	playsound(target, 'sound/effects/magic/exit_blood.ogg', 40, TRUE)
	log_harm(target)

#undef ARTIFACT_DRAIN_WINDUP
