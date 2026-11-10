/**
 * # Finisher status effects
 *
 * The finisher (finisher.dm) puts one status effect on each mob and takes it off when it ends.
 * Each effect also runs out on its own after the finisher's longest possible length, so a broken
 * or forgotten finisher can never leave a victim held or a boss frozen.
 */

/**
 * On the mob doing a finisher: its AI held while it works. A beast is also rooted and takes extra
 * damage; a person (a human NPC boss) is neither: it simply stands there busy, as a player would (HV-5).
 */
/datum/status_effect/hv_finishing
	id = "hv_finishing"
	alert_type = null
	duration = 15 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_UNIQUE
	/// Multiplier on damage it takes. 1 adds none.
	var/vulnerability = 1.5
	/// Rooted where it stands
	var/rooted = TRUE

/datum/status_effect/hv_finishing/on_creation(mob/living/new_owner, duration_override, vulnerability, rooted = TRUE)
	if(isnum(duration_override))
		duration = duration_override
	if(isnum(vulnerability))
		src.vulnerability = vulnerability
	src.rooted = rooted
	return ..()

/datum/status_effect/hv_finishing/on_apply()
	ADD_TRAIT(owner, TRAIT_AI_PAUSED, TRAIT_STATUS_EFFECT(id))
	if(rooted)
		ADD_TRAIT(owner, TRAIT_IMMOBILIZED, TRAIT_STATUS_EFFECT(id))
	if(vulnerability != 1)
		RegisterSignal(owner, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS, PROC_REF(on_damage_modifiers))
	return TRUE

/datum/status_effect/hv_finishing/on_remove()
	owner.remove_traits(list(TRAIT_AI_PAUSED, TRAIT_IMMOBILIZED), TRAIT_STATUS_EFFECT(id))
	UnregisterSignal(owner, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS)

/datum/status_effect/hv_finishing/proc/on_damage_modifiers(mob/living/source, list/damage_mods, damage, damagetype, def_zone, sharpness, attack_direction, attacking_item)
	SIGNAL_HANDLER
	damage_mods += vulnerability

/**
 * On the victim of a finisher: marked so nothing else starts one on them, and held down once gripped.
 * When a person does the finisher the hold is their real grab, so this only marks the victim.
 */
/datum/status_effect/hv_finisher_hold
	id = "hv_finisher_hold"
	alert_type = null
	duration = 15 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_UNIQUE
	/// TRUE while held down
	var/gripped = FALSE
	/// The attacker holds them with a real grab: no traits of its own
	var/real_grip = FALSE

/datum/status_effect/hv_finisher_hold/on_creation(mob/living/new_owner, duration_override, real_grip = FALSE)
	if(isnum(duration_override))
		duration = duration_override
	src.real_grip = real_grip
	return ..()

/datum/status_effect/hv_finisher_hold/on_remove()
	set_gripped(FALSE)

/// Holds the victim down, or lets them go. Their hands stay free: a downed victim can still shoot back.
/datum/status_effect/hv_finisher_hold/proc/set_gripped(grip)
	if(gripped == grip)
		return
	gripped = grip
	if(real_grip)
		return
	if(gripped)
		owner.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_FLOORED), TRAIT_STATUS_EFFECT(id))
	else
		owner.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_FLOORED), TRAIT_STATUS_EFFECT(id))

/// On a mob made to let go of a finisher by damage: a moment where it does nothing
/datum/status_effect/hv_finisher_reeling
	id = "hv_finisher_reeling"
	alert_type = null
	duration = 2 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_REFRESH

/datum/status_effect/hv_finisher_reeling/on_creation(mob/living/new_owner, duration_override)
	if(isnum(duration_override))
		duration = duration_override
	return ..()

/datum/status_effect/hv_finisher_reeling/on_apply()
	owner.add_traits(list(TRAIT_AI_PAUSED, TRAIT_IMMOBILIZED), TRAIT_STATUS_EFFECT(id))
	return TRUE

/datum/status_effect/hv_finisher_reeling/on_remove()
	owner.remove_traits(list(TRAIT_AI_PAUSED, TRAIT_IMMOBILIZED), TRAIT_STATUS_EFFECT(id))
