// Status effects applied by artifact effects.
//
// Rewritten for tg from the Polaris (6cd19fe0dec6) and VOREStation (9335d66b9fdf) /datum/modifier
// types the xenoarchaeology effects used (fortify, faraday, sprinting, berserk and its exhaustion,
// feysight). tg has no modifiers, so each is a status effect here.
//
// None of them stack. A fresh dose only tops the time up to that dose's own length, never past
// max_duration, so standing in an aura keeps a buff going but never banks a long one.
// Also here: the shared parent for effects that hand one of these out.

/// Artifact status effects: refresh to the longer of what is left and the new dose.
/datum/status_effect/artifact
	id = "artifact"
	status_type = STATUS_EFFECT_REFRESH
	duration = 30 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null
	/// Longest one dose can last, in deciseconds
	var/max_duration = 2 MINUTES

/datum/status_effect/artifact/on_creation(mob/living/new_owner, set_duration)
	if(isnum(set_duration))
		duration = clamp(set_duration, 1 SECONDS, max_duration)
	return ..()

/datum/status_effect/artifact/refresh(mob/living/new_owner, set_duration)
	var/dose = isnum(set_duration) ? clamp(set_duration, 1 SECONDS, max_duration) : initial(duration)
	duration = max(duration, world.time + dose)

// ===== Fortify =====

#define ARTIFACT_FORTIFY_DAMAGE_MULT 0.85

/datum/status_effect/artifact/fortify
	id = "artifact_fortify"
	max_duration = 90 SECONDS
	alert_type = /atom/movable/screen/alert/status_effect/artifact_fortify

/datum/status_effect/artifact/fortify/on_apply()
	RegisterSignal(owner, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS, PROC_REF(soften_blow))
	owner.add_filter("artifact_fortify", 2, outline_filter(1, "#a7b89a80"))
	return TRUE

/datum/status_effect/artifact/fortify/on_remove()
	UnregisterSignal(owner, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS)
	owner.remove_filter("artifact_fortify")
	to_chat(owner, span_notice("Your skin softens and feels like your own again."))

/datum/status_effect/artifact/fortify/proc/soften_blow(mob/living/source, list/damage_mods, damage, damagetype)
	SIGNAL_HANDLER
	if(damagetype == BRUTE || damagetype == BURN)
		damage_mods += ARTIFACT_FORTIFY_DAMAGE_MULT

/atom/movable/screen/alert/status_effect/artifact_fortify
	name = "Hardened Skin"
	desc = "Your skin is tight and tough, like old leather."
	icon_state = "slime_stoneskin"

#undef ARTIFACT_FORTIFY_DAMAGE_MULT

// ===== Faraday =====

/datum/status_effect/artifact/faraday
	id = "artifact_faraday"
	max_duration = 2 MINUTES
	alert_type = /atom/movable/screen/alert/status_effect/artifact_faraday
	/// Throttles the "it went nowhere" message
	COOLDOWN_DECLARE(grounded_message)

/datum/status_effect/artifact/faraday/on_apply()
	RegisterSignal(owner, COMSIG_ATOM_PRE_EMP_ACT, PROC_REF(ground_pulse))
	owner.add_filter("artifact_faraday", 2, outline_filter(1, "#5fd3ff60"))
	return TRUE

/datum/status_effect/artifact/faraday/on_remove()
	UnregisterSignal(owner, COMSIG_ATOM_PRE_EMP_ACT)
	owner.remove_filter("artifact_faraday")
	to_chat(owner, span_notice("The hush around you lifts, and the static comes back."))

/// Swallows an EMP whole: the mob, everything it carries, and its wiring.
/datum/status_effect/artifact/faraday/proc/ground_pulse(atom/source, severity)
	SIGNAL_HANDLER
	if(COOLDOWN_FINISHED(src, grounded_message))
		COOLDOWN_START(src, grounded_message, 5 SECONDS)
		to_chat(owner, span_notice("A pulse crackles over your skin and goes nowhere."))
		new /obj/effect/temp_visual/emp(get_turf(owner))
	return EMP_PROTECT_SELF | EMP_PROTECT_CONTENTS | EMP_PROTECT_WIRES

/atom/movable/screen/alert/status_effect/artifact_faraday
	name = "Grounded"
	desc = "There is a cold, still hush on your skin. Even your radio sounds far away."
	icon_state = "shock_immune"

// ===== Sprint =====

/datum/movespeed_modifier/status_effect/artifact_sprint
	multiplicative_slowdown = -0.25
	blacklisted_movetypes = (FLYING|FLOATING)

/datum/status_effect/artifact/sprint
	id = "artifact_sprint"
	max_duration = 60 SECONDS
	alert_type = /atom/movable/screen/alert/status_effect/artifact_sprint

/datum/status_effect/artifact/sprint/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/status_effect/artifact_sprint)
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(leave_afterimage))
	return TRUE

/datum/status_effect/artifact/sprint/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/status_effect/artifact_sprint)
	UnregisterSignal(owner, COMSIG_MOVABLE_MOVED)
	to_chat(owner, span_notice("Your legs feel heavy again."))

/// A fading copy of them where they just were.
/datum/status_effect/artifact/sprint/proc/leave_afterimage(atom/movable/source, atom/old_loc, movement_dir, forced)
	SIGNAL_HANDLER
	if(forced || !isturf(old_loc) || !prob(45))
		return
	var/obj/effect/temp_visual/decoy/fading/halfsecond/afterimage = new(old_loc, owner)
	afterimage.alpha = 110
	animate(afterimage, alpha = 0, time = 0.5 SECONDS)

/atom/movable/screen/alert/status_effect/artifact_sprint
	name = "Light on Your Feet"
	desc = "Your legs feel springy and tireless. The floor seems to rush by."
	icon_state = "realignment"

// ===== Berserk and exhaustion =====

#define ARTIFACT_BERSERK_FORCE_MULT 1.25
#define ARTIFACT_BERSERK_SWING_MULT 0.8
#define ARTIFACT_EXHAUSTED_SWING_MULT 1.25

/datum/mood_event/artifact_berserk
	description = "Everything makes me so ANGRY."
	mood_change = -3
	timeout = 2 MINUTES

/datum/status_effect/artifact/berserk
	id = "artifact_berserk"
	max_duration = 45 SECONDS
	alert_type = /atom/movable/screen/alert/status_effect/artifact_berserk

/datum/status_effect/artifact/berserk/on_apply()
	// The fury needs something to burn. A spent body can't hold it.
	if(owner.stat == DEAD || owner.has_status_effect(/datum/status_effect/artifact/exhausted))
		return FALSE
	ADD_TRAIT(owner, TRAIT_PERFECT_ATTACKER, TRAIT_STATUS_EFFECT(id))
	RegisterSignal(owner, COMSIG_MOB_ITEM_ATTACK, PROC_REF(swing_harder))
	owner.add_filter("artifact_berserk", 2, outline_filter(1, "#c0202080"))
	owner.add_mood_event("artifact_berserk", /datum/mood_event/artifact_berserk)
	return TRUE

/datum/status_effect/artifact/berserk/on_remove()
	REMOVE_TRAIT(owner, TRAIT_PERFECT_ATTACKER, TRAIT_STATUS_EFFECT(id))
	UnregisterSignal(owner, COMSIG_MOB_ITEM_ATTACK)
	owner.remove_filter("artifact_berserk")
	if(QDELETED(owner) || owner.stat == DEAD)
		return
	to_chat(owner, span_warning("The anger drains out of you, and takes your strength with it."))
	owner.apply_status_effect(/datum/status_effect/artifact/exhausted, 25 SECONDS)

/datum/status_effect/artifact/berserk/nextmove_modifier()
	return ARTIFACT_BERSERK_SWING_MULT

/datum/status_effect/artifact/berserk/proc/swing_harder(mob/living/source, mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	MODIFY_ATTACK_FORCE_MULTIPLIER(attack_modifiers, ARTIFACT_BERSERK_FORCE_MULT)

/atom/movable/screen/alert/status_effect/artifact_berserk
	name = "Seeing Red"
	desc = "Your blood is up. Every swing lands, and lands hard."
	icon_state = "blooddrunk"

/datum/movespeed_modifier/status_effect/artifact_exhausted
	multiplicative_slowdown = 0.6
	blacklisted_movetypes = (FLYING|FLOATING)

/// Worn out: after a rage, a life drain, or being dragged back from death.
/datum/status_effect/artifact/exhausted
	id = "artifact_exhausted"
	max_duration = 60 SECONDS
	alert_type = /atom/movable/screen/alert/status_effect/artifact_exhausted

/datum/status_effect/artifact/exhausted/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/status_effect/artifact_exhausted)
	return TRUE

/datum/status_effect/artifact/exhausted/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/status_effect/artifact_exhausted)

/datum/status_effect/artifact/exhausted/nextmove_modifier()
	return ARTIFACT_EXHAUSTED_SWING_MULT

/atom/movable/screen/alert/status_effect/artifact_exhausted
	name = "Drained"
	desc = "You feel wrung out. Every step is an effort."
	icon_state = "weaken"

#undef ARTIFACT_BERSERK_FORCE_MULT
#undef ARTIFACT_BERSERK_SWING_MULT
#undef ARTIFACT_EXHAUSTED_SWING_MULT

// ===== Feysight =====

/datum/client_colour/artifact_feysight
	priority = CLIENT_COLOR_TEMPORARY_PRIORITY
	color = "#d4ffdc"
	fade_in = 1 SECONDS
	fade_out = 1 SECONDS

/datum/status_effect/artifact/feysight
	id = "artifact_feysight"
	max_duration = 45 SECONDS
	alert_type = /atom/movable/screen/alert/status_effect/artifact_feysight

/datum/status_effect/artifact/feysight/on_apply()
	ADD_TRAIT(owner, TRAIT_THERMAL_VISION, TRAIT_STATUS_EFFECT(id))
	RegisterSignal(owner, COMSIG_MOB_UPDATE_SIGHT, PROC_REF(tint_sight))
	owner.update_sight()
	owner.add_client_colour(/datum/client_colour/artifact_feysight, REF(src))
	return TRUE

/datum/status_effect/artifact/feysight/on_remove()
	REMOVE_TRAIT(owner, TRAIT_THERMAL_VISION, TRAIT_STATUS_EFFECT(id))
	UnregisterSignal(owner, COMSIG_MOB_UPDATE_SIGHT)
	owner.update_sight()
	owner.remove_client_colour(REF(src))
	to_chat(owner, span_notice("You blink, and the walls are only walls again."))

/// A faint green to the dark while the sight lasts.
/datum/status_effect/artifact/feysight/proc/tint_sight(mob/source)
	SIGNAL_HANDLER
	source.lighting_color_cutoffs = blend_cutoff_colors(source.lighting_color_cutoffs, list(5, 22, 10))

/atom/movable/screen/alert/status_effect/artifact_feysight
	name = "Second Sight"
	desc = "Living things glow through the walls like coals through paper."
	icon_state = "moon_hide"

// ===== Effects that hand one out =====

/**
 * Shared parent for effects that give people near them a status effect: a touch gives the
 * longest dose, a burst a medium one to everyone in range, and a field brushes people now and
 * then with a short one. Protective gear shortens every dose. Not rollable itself.
 */
/datum/artifact_effect/bestow
	/// The /datum/status_effect/artifact it hands out
	var/datum/status_effect/artifact/status_type
	var/touch_duration = 60 SECONDS
	var/pulse_duration = 30 SECONDS
	var/aura_duration = 10 SECONDS
	/// Chance per second that the field reaches each person in range
	var/aura_chance = 10

/datum/artifact_effect/bestow/do_effect_touch(mob/living/user)
	bestow(user, touch_duration)

/datum/artifact_effect/bestow/do_effect_aura(seconds_per_tick)
	for(var/mob/living/target in living_in_range())
		if(SPT_PROB(aura_chance, seconds_per_tick))
			bestow(target, aura_duration, quiet = TRUE)

/datum/artifact_effect/bestow/do_effect_pulse(power)
	var/dose = pulse_duration * clamp(power / 25, 0.5, 1.5)
	for(var/mob/living/target in living_in_range())
		bestow(target, dose)

/**
 * Gives `target` a dose lasting `duration` (deciseconds), shortened by protective gear.
 * `quiet` keeps a field's top-ups from repeating the renewal message.
 * Returns TRUE if they have it afterwards.
 */
/datum/artifact_effect/bestow/proc/bestow(mob/living/target, duration, quiet = FALSE)
	if(!status_type || !can_bestow(target))
		return FALSE
	duration *= artifact_exposure(target)
	if(duration < 1 SECONDS)
		return FALSE
	var/had_it = !!target.has_status_effect(status_type)
	target.apply_status_effect(status_type, duration)
	if(!target.has_status_effect(status_type))
		on_refused(target)
		return FALSE
	if(!had_it)
		on_bestowed(target)
	else if(!quiet)
		on_renewed(target)
	log_harm(target)
	return TRUE

/// Who it works on.
/datum/artifact_effect/bestow/proc/can_bestow(mob/living/target)
	return target.stat != DEAD

/// Hook: `target` just got their first dose.
/datum/artifact_effect/bestow/proc/on_bestowed(mob/living/target)
	return

/// Hook: `target` already had it and got topped up by a touch or burst.
/datum/artifact_effect/bestow/proc/on_renewed(mob/living/target)
	return

/// Hook: `target` could not take it (the status effect refused).
/datum/artifact_effect/bestow/proc/on_refused(mob/living/target)
	return
