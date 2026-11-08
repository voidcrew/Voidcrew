/**
 * # Finisher status effects and telegraph
 *
 * The finisher (finisher.dm) puts one status effect on each mob and takes it off when it ends.
 * Each effect also runs out on its own after the finisher's longest possible length, so a broken
 * or forgotten finisher can never leave a victim held or a boss frozen.
 */

/// On the mob doing a finisher: rooted, its AI held, and it takes extra damage
/datum/status_effect/hv_finishing
	id = "hv_finishing"
	alert_type = null
	duration = 15 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_UNIQUE
	/// Multiplier on damage it takes
	var/vulnerability = 1.5

/datum/status_effect/hv_finishing/on_creation(mob/living/new_owner, duration_override, vulnerability)
	if(isnum(duration_override))
		duration = duration_override
	if(isnum(vulnerability))
		src.vulnerability = vulnerability
	return ..()

/datum/status_effect/hv_finishing/on_apply()
	owner.add_traits(list(TRAIT_AI_PAUSED, TRAIT_IMMOBILIZED), TRAIT_STATUS_EFFECT(id))
	RegisterSignal(owner, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS, PROC_REF(on_damage_modifiers))
	return TRUE

/datum/status_effect/hv_finishing/on_remove()
	owner.remove_traits(list(TRAIT_AI_PAUSED, TRAIT_IMMOBILIZED), TRAIT_STATUS_EFFECT(id))
	UnregisterSignal(owner, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS)

/datum/status_effect/hv_finishing/proc/on_damage_modifiers(mob/living/source, list/damage_mods, damage, damagetype, def_zone, sharpness, attack_direction, attacking_item)
	SIGNAL_HANDLER
	damage_mods += vulnerability

/// On the victim of a finisher: marked so nothing else starts one on them, and held down once gripped
/datum/status_effect/hv_finisher_hold
	id = "hv_finisher_hold"
	alert_type = null
	duration = 15 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_UNIQUE
	/// TRUE while held down
	var/gripped = FALSE

/datum/status_effect/hv_finisher_hold/on_creation(mob/living/new_owner, duration_override)
	if(isnum(duration_override))
		duration = duration_override
	return ..()

/datum/status_effect/hv_finisher_hold/on_remove()
	set_gripped(FALSE)

/// Holds the victim down, or lets them go. Their hands stay free: a downed victim can still shoot back.
/datum/status_effect/hv_finisher_hold/proc/set_gripped(grip)
	if(gripped == grip)
		return
	gripped = grip
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

/// The wind-up's mark over the victim: jaws or a skull in a red box, following them if they are dragged
/obj/effect/temp_visual/telegraphing/hv_finisher_mark
	icon = 'icons/mob/telegraphing/telegraph.dmi'
	icon_state = "skull"
	// Over the victim and the boss leaning across them, and lit, so it reads in a dark derelict
	layer = ABOVE_MOB_LAYER
	light_color = COLOR_RED
	randomdir = FALSE
	duration = 1.5 SECONDS

/obj/effect/temp_visual/telegraphing/hv_finisher_mark/Initialize(mapload, atom/movable/followed, state, new_duration)
	if(isnum(new_duration))
		duration = new_duration
	if(state)
		icon_state = state
	. = ..()
	if(isnull(followed))
		return
	RegisterSignal(followed, COMSIG_MOVABLE_MOVED, PROC_REF(on_followed_moved))
	RegisterSignal(followed, COMSIG_QDELETING, PROC_REF(on_followed_deleted))

/obj/effect/temp_visual/telegraphing/hv_finisher_mark/proc/on_followed_moved(atom/movable/source)
	SIGNAL_HANDLER
	var/turf/spot = get_turf(source)
	if(isnull(spot))
		qdel(src)
		return
	forceMove(spot)

/obj/effect/temp_visual/telegraphing/hv_finisher_mark/proc/on_followed_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)
