// Artifact effect: resurrect.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/resurrect.dm and the
// VOREStation (9335d66b9fdf) "vitality swap" version. Voidcrew (owner decision 4): brings back one
// person lying beside it who died less than five minutes ago, three times in all, then it cracks
// and goes dull for good. It is never a free revive loop:
// - three lives per artifact, stored on the effect; not harvestable, and artifacts are never
//   saved with a ship, so the count can't be copied or reset;
// - only a body whose own player is still there to come back: a ghost that can re-enter, or a
//   player still in the body. Do-not-resuscitate, logged-out players, and a mind that already moved
//   on (a clone, a new body) are refused;
// - the same checks as a defibrillator: suicides, husks, failing or missing hearts and brains, and
//   bodies too broken to hold life;
// - its healing goes through the shared artifact cap (30 brute and burn); it clears the choking
//   and some poison, but a body torn apart past that stays dead and costs no use.
// Polaris drained the living nearby to fuel it; that is dropped. The price is the use, and the
// person comes back weak. Every revival is logged.

/// Lives it can give back before it is spent
#define ARTIFACT_RESURRECT_USES 3
/// How long after death a body can still be raised
#define ARTIFACT_RESURRECT_WINDOW (5 MINUTES)
/// How long the light works on a body before it wakes
#define ARTIFACT_RESURRECT_RITE (4 SECONDS)
/// Poison it clears from a body
#define ARTIFACT_RESURRECT_TOX_MEND 40

/datum/artifact_effect/resurrect
	label_name = "Raises the dead"
	log_name = "Resurrect"
	tier = ARTIFACT_TIER_EXTREME
	harvestable = FALSE
	helpful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_ORGANIC)
	/// Lives it can still give back. At zero it is spent for good.
	var/uses_left = ARTIFACT_RESURRECT_USES
	/// The body it is working on, if any
	var/datum/weakref/working_on
	/// REF(body) -> world.time it last showed it could not help them
	var/list/refused_at

/datum/artifact_effect/resurrect/Destroy(force)
	working_on = null
	refused_at = null
	return ..()

/datum/artifact_effect/resurrect/copy_settings_to(datum/artifact_effect/resurrect/copy)
	copy.uses_left = uses_left

/datum/artifact_effect/resurrect/is_spent()
	return uses_left <= 0

/datum/artifact_effect/resurrect/do_effect_touch(mob/living/user)
	seek()

/datum/artifact_effect/resurrect/do_effect_aura(seconds_per_tick)
	seek()

/datum/artifact_effect/resurrect/do_effect_pulse(power)
	seek()

/// Spent, it only gives the faintest light when woken.
/datum/artifact_effect/resurrect/light_override()
	if(uses_left <= 0)
		return list(1, 0.3, "#5a1a1a")
	return null

/// Looks for a body laid beside it and starts on the first one that can come back.
/datum/artifact_effect/resurrect/proc/seek()
	if(uses_left <= 0 || working_on?.resolve())
		return
	var/turf/center = source_turf()
	if(!center)
		return
	for(var/mob/living/carbon/human/body in range(1, center))
		if(body.stat != DEAD)
			continue
		var/refusal = raise_refusal(body)
		if(refusal)
			show_refusal(body, refusal)
			continue
		begin_rite(body)
		return

/**
 * Why `body` can't be raised, as a short reason, or null if it can.
 * "spent", "not here", "too late", "gone" (nobody to come back) or "ruined" (the body can't hold life).
 */
/datum/artifact_effect/resurrect/proc/raise_refusal(mob/living/carbon/human/body)
	if(uses_left <= 0)
		return "spent"
	if(!istype(body) || QDELETED(body) || body.stat != DEAD || !isturf(body.loc))
		return "not here"
	if(world.time - body.timeofdeath > ARTIFACT_RESURRECT_WINDOW)
		return "too late"
	if(!body.mind || body.mind.current != body)
		return "gone"
	if(body.can_defib() != DEFIB_POSSIBLE)
		return "ruined"
	if(projected_health(body) <= HEALTH_THRESHOLD_DEAD)
		return "ruined"
	if(!body.client && !body.get_ghost(FALSE, TRUE))
		return "gone"
	return null

/// What `body`'s health would be after the mending it gives.
/datum/artifact_effect/resurrect/proc/projected_health(mob/living/carbon/human/body)
	var/mended = min(artifact_heal_allowance(body), body.getBruteLoss() + body.getFireLoss())
	mended += body.getOxyLoss() + min(body.getToxLoss(), ARTIFACT_RESURRECT_TOX_MEND)
	return body.health + mended

/// Shows, now and then, that it reached for a body and could not take hold.
/datum/artifact_effect/resurrect/proc/show_refusal(mob/living/carbon/human/body, refusal)
	if(refusal == "spent" || refusal == "not here")
		return
	var/key = REF(body)
	if(LAZYACCESS(refused_at, key) > world.time - 30 SECONDS)
		return
	LAZYSET(refused_at, key, world.time)
	if(refusal == "gone")
		body.visible_message(span_notice("A thread of red light reaches from [holder] to [body], finds no one there, and fades."))
	else
		body.visible_message(span_notice("A thread of red light touches [body], slides off, and fades."))

/// The light goes to work on `body`; it wakes after the rite if nothing has changed.
/datum/artifact_effect/resurrect/proc/begin_rite(mob/living/carbon/human/body)
	working_on = WEAKREF(body)
	var/atom/origin = artifact_effect_visible_source(holder)
	origin?.Beam(body, icon_state = "lichbeam", time = ARTIFACT_RESURRECT_RITE)
	body.visible_message(span_warning("Threads of red light reach out of [holder] and sink into [body]. The body twitches."))
	playsound(body, 'sound/effects/magic/enter_blood.ogg', 45, TRUE)
	playsound(body, 'sound/effects/singlebeat.ogg', 60, TRUE)
	body.do_jitter_animation(100)
	body.notify_revival("Something is dragging you back toward your body!", source = holder)
	addtimer(CALLBACK(src, PROC_REF(finish_rite), WEAKREF(body)), ARTIFACT_RESURRECT_RITE, TIMER_DELETE_ME)

/// The rite ends: raises the body if it still can be.
/datum/artifact_effect/resurrect/proc/finish_rite(datum/weakref/body_ref)
	working_on = null
	var/mob/living/carbon/human/body = body_ref?.resolve()
	if(!body)
		return
	var/obj/machinery/artifact/artifact = holder
	if((istype(artifact) && artifact.suppressed) || get_dist(source_turf(), body) > 1 || raise_refusal(body))
		body.visible_message(span_notice("The red light drains out of [body] and is gone."))
		return
	raise(body)

/**
 * Brings `body` back to life and spends one use. Returns TRUE if they live.
 * Checks nothing about whether they should: raise_refusal() does that.
 */
/datum/artifact_effect/resurrect/proc/raise(mob/living/carbon/human/body)
	if(uses_left <= 0 || QDELETED(body) || body.stat != DEAD)
		return FALSE
	artifact_capped_heal(body, artifact_heal_allowance(body))
	body.adjustOxyLoss(-body.getOxyLoss(), updating_health = FALSE)
	body.adjustToxLoss(-min(body.getToxLoss(), ARTIFACT_RESURRECT_TOX_MEND), updating_health = FALSE, forced = TRUE)
	body.updatehealth()
	body.set_heartattack(FALSE)
	if(body.health <= HEALTH_THRESHOLD_DEAD)
		return FALSE
	body.grab_ghost()
	if(!body.revive_from("artifact"))
		return FALSE
	uses_left--
	body.emote("gasp")
	body.set_jitter_if_lower(20 SECONDS)
	body.apply_status_effect(/datum/status_effect/artifact/exhausted, 60 SECONDS)
	body.visible_message(
		span_warning("[body]'s eyes snap open in a flash of red light!"),
		span_userdanger("You are dragged back into your body, gasping. Everything aches."),
	)
	playsound(body, 'sound/effects/magic/staff_healing.ogg', 50, TRUE)
	var/mob/responsible = get_responsible()
	log_combat(responsible || holder, body, "revived", holder, "with [log_name] ([uses_left] uses left)")
	if(uses_left <= 0)
		go_dull()
	return TRUE

/// The last life is given: it cracks and the light inside goes out.
/datum/artifact_effect/resurrect/proc/go_dull()
	var/turf/here = source_turf()
	if(!here)
		return
	here.visible_message(span_warning("[holder] cracks with a sound like a knuckle, and the light deep inside it goes out."))
	playsound(here, 'sound/effects/wounds/crack1.ogg', 50, TRUE)
	var/obj/machinery/artifact/artifact = holder
	if(istype(artifact))
		artifact.update_activity_visuals()

#undef ARTIFACT_RESURRECT_USES
#undef ARTIFACT_RESURRECT_WINDOW
#undef ARTIFACT_RESURRECT_RITE
#undef ARTIFACT_RESURRECT_TOX_MEND
