// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/gravity.dm.
// Voidcrew: shorter reach (four tiles of pull or push, not eight), anchored and heavy things stay
// put, only loose items, structures and people move; any trigger. Moving people is logged.

#define ARTIFACT_GRAVITY_PULL 1
#define ARTIFACT_GRAVITY_PUSH 2
#define ARTIFACT_GRAVITY_SCATTER 3

/datum/artifact_effect/gravity
	label_name = "Gravity"
	log_name = "Gravity"
	tier = ARTIFACT_TIER_UNCOMMON
	harmful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_BLUESPACE)
	allowed_release_methods = list(ARTIFACT_RELEASE_PULSE)
	/// Pull, push or scatter
	var/mode = ARTIFACT_GRAVITY_PULL

/datum/artifact_effect/gravity/setup()
	mode = pick(ARTIFACT_GRAVITY_PULL, ARTIFACT_GRAVITY_PUSH, ARTIFACT_GRAVITY_SCATTER)
	range = min(range, 6)

/datum/artifact_effect/gravity/copy_settings_to(datum/artifact_effect/gravity/copy)
	copy.mode = mode

/datum/artifact_effect/gravity/do_effect_pulse(power)
	var/turf/center = source_turf()
	if(!center)
		return
	new /obj/effect/temp_visual/circle_wave/gravity(center)
	for(var/atom/movable/thing in range(range, center))
		if(thing == holder || !can_shift(thing))
			continue
		var/exposure = isliving(thing) ? artifact_exposure(thing) : 1
		if(exposure <= 0)
			continue
		switch(mode)
			if(ARTIFACT_GRAVITY_PULL)
				for(var/step in 1 to round(4 * exposure))
					step_towards(thing, center)
			if(ARTIFACT_GRAVITY_PUSH)
				for(var/step in 1 to round(4 * exposure))
					step_away(thing, center)
			if(ARTIFACT_GRAVITY_SCATTER)
				var/turf/landing = pick(RANGE_TURFS(range, center))
				thing.throw_at(landing, round(4 * exposure), 2)
		if(isliving(thing))
			log_harm(thing)

/// Loose items, unanchored structures and the living; nothing anchored or immovable.
/datum/artifact_effect/gravity/proc/can_shift(atom/movable/thing)
	if(thing.anchored || thing.move_resist > MOVE_FORCE_STRONG)
		return FALSE
	return isitem(thing) || isstructure(thing) || isliving(thing)

#undef ARTIFACT_GRAVITY_PULL
#undef ARTIFACT_GRAVITY_PUSH
#undef ARTIFACT_GRAVITY_SCATTER
