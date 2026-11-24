// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/light.dm.
// Voidcrew: shines (or darkens) the whole time it is awake and costs no charge; any trigger;
// brightness kept to an ordinary lamp's range.

/datum/artifact_effect/light
	label_name = "Light"
	log_name = "Light"
	tier = ARTIFACT_TIER_COMMON
	minor = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_CONCENTRATED, ARTIFACT_ENERGY_PARTICLE)
	allowed_release_methods = list(ARTIFACT_RELEASE_AURA)
	/// Light colour
	var/light_tint = "#fff3d6"
	/// Light power sign: 1 for light, -1 for darkness
	var/light_sign = 1

/datum/artifact_effect/light/release_aura(seconds_per_tick)
	return

/datum/artifact_effect/light/do_effect_destroy()
	return

/datum/artifact_effect/light/light_override()
	return list(range, light_sign * clamp(maximum_charges / 12, 0.8, 3), light_tint)

/datum/artifact_effect/light/on_activate()
	// An artifact refreshes its own light; anything else (a battery in a utilizer) is lit here.
	if(holder && !istype(holder, /obj/machinery/artifact))
		var/list/glow = light_override()
		holder.set_light(glow[1], glow[2], glow[3])

/datum/artifact_effect/light/on_deactivate()
	if(holder && !istype(holder, /obj/machinery/artifact))
		holder.set_light(0)

/datum/artifact_effect/light/darkness
	label_name = "Darkness"
	log_name = "Darkness"
	possible_kinds = list(ARTIFACT_ENERGY_PARTICLE, ARTIFACT_ENERGY_BLUESPACE)
	light_tint = COLOR_WHITE
	light_sign = -1
