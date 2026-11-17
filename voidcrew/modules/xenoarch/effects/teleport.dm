// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/teleport.dm.
// Voidcrew: short hops onto open floor (never into walls, space or a chasm), through unforced
// do_teleport() so no-teleport areas and the zone guard still apply; no sparks, which light
// plasma; logged.

/datum/artifact_effect/teleport
	label_name = "Teleports"
	log_name = "Teleport"
	tier = ARTIFACT_TIER_RARE
	harmful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_BLUESPACE)

/datum/artifact_effect/teleport/do_effect_touch(mob/living/user)
	if(hop(user, 6))
		to_chat(user, span_warning("You're suddenly standing somewhere else!"))

/datum/artifact_effect/teleport/do_effect_aura(seconds_per_tick)
	for(var/mob/living/target as anything in living_in_range())
		if(SPT_PROB(10, seconds_per_tick) && hop(target, range))
			to_chat(target, span_warning("You are displaced by a strange force!"))

/datum/artifact_effect/teleport/do_effect_pulse(power)
	var/turf/center = source_turf()
	if(center)
		new /obj/effect/temp_visual/circle_wave/bluespace(center)
	for(var/mob/living/target as anything in living_in_range())
		if(hop(target, range + 2))
			to_chat(target, span_warning("You are displaced by a strange force!"))

/// Hops `target` to a random open floor up to `distance` tiles away. Returns TRUE if it moved.
/datum/artifact_effect/teleport/proc/hop(mob/living/target, distance)
	if(target.buckled || target.anchored)
		return FALSE
	var/exposure = artifact_exposure(target)
	distance = round(distance * exposure)
	if(distance < 1)
		return FALSE
	var/turf/origin = get_turf(target)
	var/list/landings = list()
	for(var/turf/open/spot in RANGE_TURFS(distance, origin))
		if(spot == origin || isspaceturf(spot) || isgroundlessturf(spot) || islava(spot))
			continue
		if(spot.is_blocked_turf(exclude_mobs = TRUE))
			continue
		landings += spot
	if(!length(landings))
		return FALSE
	var/turf/landing = pick(landings)
	new /obj/effect/temp_visual/bluespace_fissure(origin)
	if(!do_teleport(target, landing, precision = 0, no_effects = TRUE, channel = TELEPORT_CHANNEL_BLUESPACE))
		return FALSE
	playsound(origin, 'sound/effects/magic/blink.ogg', 40, TRUE)
	playsound(landing, 'sound/effects/phasein.ogg', 40, TRUE)
	log_harm(target)
	return TRUE
