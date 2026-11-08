// Artifact effect: extinguisher.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/extinguisher.dm.
// Voidcrew: puts out burning people, burning objects and open flames in its range, and wets
// people a little so they are slow to catch again. Air is only cooled indoors; on planet ground
// it snuffs the flames and never touches the shared planet air. No wet floors (Polaris left
// slippery tiles); no destroy burst.

/// Hot air on a fire tile is pulled down toward this
#define ARTIFACT_EXTINGUISH_COOL_TO (T20C + 30)
/// At most this many kelvin come off a fire tile's air per douse
#define ARTIFACT_EXTINGUISH_COOL_STEP 120

/datum/artifact_effect/extinguisher
	label_name = "Puts out fires"
	log_name = "Extinguisher"
	tier = ARTIFACT_TIER_COMMON
	minor = TRUE
	helpful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_SYNTHESIS, ARTIFACT_ENERGY_PARTICLE)

/datum/artifact_effect/extinguisher/do_effect_touch(mob/living/user)
	douse(user, 4)
	to_chat(user, span_notice("Cold mist beads on your skin where you touched [holder]."))
	playsound(source_turf(), 'sound/effects/extinguish.ogg', 25, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)

/datum/artifact_effect/extinguisher/do_effect_aura(seconds_per_tick)
	var/turf/center = source_turf()
	if(!center)
		return
	var/quenched = quench_area(center)
	for(var/mob/living/target in living_in_range())
		if(target.on_fire)
			douse(target, 2)
			quenched = TRUE
	if(quenched)
		playsound(center, 'sound/effects/extinguish.ogg', 30, TRUE)
	else if(SPT_PROB(15, seconds_per_tick))
		new /obj/effect/temp_visual/artifact_mist(center)

/datum/artifact_effect/extinguisher/do_effect_pulse(power)
	var/turf/center = source_turf()
	if(!center)
		return
	new /obj/effect/temp_visual/circle_wave/artifact_mist(center, max(range * 0.6, 1.5))
	playsound(center, 'sound/effects/extinguish.ogg', 45, TRUE)
	quench_area(center)
	for(var/mob/living/target in living_in_range())
		douse(target, 3)

/datum/artifact_effect/extinguisher/do_effect_destroy()
	return

/// Puts out `target` and leaves them damp. Tells them if they were burning.
/datum/artifact_effect/extinguisher/proc/douse(mob/living/target, wetness)
	var/was_burning = target.on_fire
	target.extinguish_mob()
	target.adjust_wet_stacks(wetness * artifact_exposure(target))
	if(was_burning && !target.on_fire)
		to_chat(target, span_notice("A cold mist rolls over you, and the flames on you gutter out."))

/// Snuffs open flames and burning objects in range. Returns TRUE if it put anything out.
/datum/artifact_effect/extinguisher/proc/quench_area(turf/center)
	. = FALSE
	for(var/obj/effect/hotspot/flame in range(range, center))
		var/turf/open/flame_turf = flame.loc
		qdel(flame)
		cool_air(flame_turf)
		new /obj/effect/temp_visual/artifact_mist(flame_turf)
		. = TRUE
	for(var/obj/burning in range(range, center))
		if(burning.resistance_flags & ON_FIRE)
			burning.extinguish()
			. = TRUE

/// Takes the heat out of an indoor fire tile so it doesn't flare straight back. Never planet air.
/datum/artifact_effect/extinguisher/proc/cool_air(turf/open/spot)
	if(!istype(spot) || spot.planetary_atmos || isspaceturf(spot))
		return
	var/datum/gas_mixture/air = spot.return_air()
	if(!air || air.temperature <= ARTIFACT_EXTINGUISH_COOL_TO)
		return
	air.temperature = max(ARTIFACT_EXTINGUISH_COOL_TO, air.temperature - ARTIFACT_EXTINGUISH_COOL_STEP)
	spot.air_update_turf(FALSE, FALSE)

/// A puff of cold mist.
/obj/effect/temp_visual/artifact_mist
	icon_state = "extinguish"
	alpha = 200
	duration = 0.8 SECONDS

/obj/effect/temp_visual/artifact_mist/Initialize(mapload)
	. = ..()
	pixel_x = rand(-6, 6)
	pixel_y = rand(-4, 8)
	animate(src, alpha = 0, pixel_y = pixel_y + 6, time = duration)

/// A ring of mist rolling out from the artifact.
/obj/effect/temp_visual/circle_wave/artifact_mist
	color = "#cfe9ff"
	max_alpha = 170
	duration = 0.8 SECONDS

/obj/effect/temp_visual/circle_wave/artifact_mist/Initialize(mapload, scale)
	if(isnum(scale))
		amount_to_scale = scale
	return ..()

#undef ARTIFACT_EXTINGUISH_COOL_TO
#undef ARTIFACT_EXTINGUISH_COOL_STEP
