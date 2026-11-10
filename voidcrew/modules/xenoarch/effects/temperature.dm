// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/temperature.dm.
// Voidcrew: gentle targets (a common minor effect makes a room uncomfortable, not lethal); bodies
// never pushed past the damage limits; planet air is never written (bodies only on planet turfs);
// no destroy burst.

/datum/artifact_effect/temperature
	tier = ARTIFACT_TIER_COMMON
	minor = TRUE
	allowed_release_methods = list(ARTIFACT_RELEASE_TOUCH, ARTIFACT_RELEASE_AURA, ARTIFACT_RELEASE_PULSE)
	/// Air near it moves toward this
	var/target_temp = T20C
	var/target_low = T20C
	var/target_high = T20C
	/// Bodies never go past this (kept short of the damage limit)
	var/body_limit = T20C
	/// Kelvin per second the tile's air moves while the aura runs
	var/air_rate = 8
	/// Kelvin per second bodies in range move while the aura runs
	var/body_rate = 1.5
	/// Shown to a toucher
	var/touch_message

/datum/artifact_effect/temperature/setup()
	target_temp = rand(target_low, target_high)

/datum/artifact_effect/temperature/copy_settings_to(datum/artifact_effect/temperature/copy)
	copy.target_temp = target_temp

/datum/artifact_effect/temperature/do_effect_touch(mob/living/user)
	to_chat(user, span_warning(touch_message))
	nudge_body(user, 15)
	nudge_air(20)

/datum/artifact_effect/temperature/do_effect_aura(seconds_per_tick)
	nudge_air(air_rate * seconds_per_tick)
	for(var/mob/living/target as anything in living_in_range())
		nudge_body(target, body_rate * seconds_per_tick)

/datum/artifact_effect/temperature/do_effect_pulse(power)
	nudge_air(clamp(power * 2, 10, 60))
	for(var/mob/living/target as anything in living_in_range())
		nudge_body(target, clamp(power / 3, 3, 12))

/datum/artifact_effect/temperature/do_effect_destroy()
	return

/// Moves the air on its own tile toward the target. Never planet air, never vacuum.
/datum/artifact_effect/temperature/proc/nudge_air(amount)
	var/turf/open/here = source_turf()
	if(!istype(here) || here.planetary_atmos || isspaceturf(here))
		return
	var/datum/gas_mixture/air = here.return_air()
	if(!air || air.total_moles() <= 0)
		return
	var/difference = target_temp - air.temperature
	if(abs(difference) < 1)
		return
	air.temperature += clamp(difference, -amount, amount)
	here.air_update_turf(FALSE, FALSE)

/datum/artifact_effect/temperature/proc/nudge_body(mob/living/target, amount)
	var/goal = target_temp > T20C ? min(target_temp, body_limit) : max(target_temp, body_limit)
	var/difference = goal - target.bodytemperature
	if(abs(difference) < 0.5)
		return
	target.adjust_bodytemperature(clamp(difference, -amount, amount) * artifact_exposure(target))

/datum/artifact_effect/temperature/heat
	label_name = "Heat"
	log_name = "Heat"
	possible_kinds = list(ARTIFACT_ENERGY_CONCENTRATED, ARTIFACT_ENERGY_SYNTHESIS)
	target_low = 310
	target_high = 345
	body_limit = BODYTEMP_HEAT_DAMAGE_LIMIT - 5
	touch_message = "A wave of heat runs up your arm."

/datum/artifact_effect/temperature/cold
	label_name = "Cold"
	log_name = "Cold"
	possible_kinds = list(ARTIFACT_ENERGY_SYNTHESIS, ARTIFACT_ENERGY_BLUESPACE)
	target_low = 255
	target_high = 280
	body_limit = BODYTEMP_COLD_DAMAGE_LIMIT + 5
	touch_message = "A chill runs up your spine."
