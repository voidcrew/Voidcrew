// Artifact effect: gaia.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/gaia.dm, also in
// VOREStation (9335d66b9fdf). Voidcrew: tends living plants in hydroponics trays nearby (water,
// health, weeds, pests and toxins) but never speeds their growth or revives dead ones, so it
// saves a gardener's chores without making more crop. Plant people nearby feel it too, inside the
// shared artifact healing cap. Polaris' glitterflies become a few short-lived butterflies, at
// most three at a time, that fade away on their own.

/// Butterflies alive at once, per artifact
#define ARTIFACT_GAIA_MAX_BUTTERFLIES 3

/datum/artifact_effect/gaia
	label_name = "Feeds plants"
	log_name = "Gaia"
	tier = ARTIFACT_TIER_UNCOMMON
	helpful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_ORGANIC, ARTIFACT_ENERGY_SYNTHESIS)
	/// Weakrefs to the butterflies it has drawn
	var/list/datum/weakref/butterflies = list()

/datum/artifact_effect/gaia/Destroy(force)
	for(var/datum/weakref/butterfly_ref as anything in butterflies)
		var/mob/living/basic/butterfly/lavaland/temporary/butterfly = butterfly_ref.resolve()
		if(butterfly)
			butterfly.fadeout()
	butterflies = null
	return ..()

/datum/artifact_effect/gaia/do_effect_touch(mob/living/user)
	to_chat(user, span_notice("You feel the presence of something long forgotten, and green."))
	var/tended = tend_all(range + 2, 3, 30)
	if(tended)
		to_chat(user, span_notice("Somewhere nearby, leaves rustle."))

/datum/artifact_effect/gaia/do_effect_aura(seconds_per_tick)
	tend_all(range, 0.5 * seconds_per_tick, 2)
	for(var/mob/living/carbon/human/sprout in living_in_range())
		if(SPT_PROB(10, seconds_per_tick))
			nourish(sprout, 2)

/datum/artifact_effect/gaia/do_effect_pulse(power)
	var/turf/center = source_turf()
	if(!center)
		return
	new /obj/effect/temp_visual/circle_wave/artifact_ring/gaia(center, max(range * 0.6, 1.5))
	playsound(center, 'sound/effects/rustle/rustle1.ogg', 40, TRUE)
	tend_all(range, clamp(power / 5, 2, 8), 10)
	if(prob(25))
		draw_butterfly(get_step(center, pick(GLOB.alldirs)))
	for(var/mob/living/carbon/human/sprout in living_in_range())
		nourish(sprout, clamp(power / 4, 2, 8))

/**
 * Tends every planted tray in `reach` by `amount`, with `butterfly_chance` per tray of drawing a
 * butterfly. Returns how many it tended.
 */
/datum/artifact_effect/gaia/proc/tend_all(reach, amount, butterfly_chance)
	. = 0
	var/turf/center = source_turf()
	if(!center)
		return
	for(var/obj/machinery/hydroponics/tray in range(reach, center))
		if(!tend(tray, amount))
			continue
		.++
		if(prob(butterfly_chance))
			draw_butterfly(get_turf(tray))

/// Waters, weeds and soothes one tray's living plant. Never ages it. Returns TRUE if it had one.
/datum/artifact_effect/gaia/proc/tend(obj/machinery/hydroponics/tray, amount)
	if(!tray.myseed || tray.plant_status == HYDROTRAY_PLANT_DEAD)
		return FALSE
	tray.adjust_waterlevel(amount * 3)
	tray.adjust_plant_health(amount)
	tray.adjust_weedlevel(-1)
	tray.adjust_pestlevel(-1)
	tray.adjust_toxic(-amount)
	tray.update_appearance()
	if(prob(30))
		new /obj/effect/temp_visual/artifact_gaia_bloom(get_turf(tray))
	return TRUE

/// Plant people take a little warmth from it, inside the shared healing cap.
/datum/artifact_effect/gaia/proc/nourish(mob/living/carbon/human/sprout, amount)
	if(sprout.stat == DEAD || !(sprout.mob_biotypes & MOB_PLANT))
		return
	if(artifact_capped_heal(sprout, amount * artifact_exposure(sprout)) > 0 && prob(30))
		to_chat(sprout, span_notice("A warm, green feeling seeps into your leaves."))

/// A butterfly comes to the plants for a while.
/datum/artifact_effect/gaia/proc/draw_butterfly(turf/spot)
	for(var/datum/weakref/butterfly_ref as anything in butterflies)
		if(!butterfly_ref.resolve())
			butterflies -= butterfly_ref
	if(length(butterflies) >= ARTIFACT_GAIA_MAX_BUTTERFLIES || !istype(spot) || spot.is_blocked_turf())
		return
	var/mob/living/basic/butterfly/lavaland/temporary/butterfly = new(spot)
	butterfly.source = artifact_effect_visible_source(holder)
	butterfly.max_distance = range + 3
	butterflies += WEAKREF(butterfly)
	addtimer(CALLBACK(butterfly, TYPE_PROC_REF(/mob/living/basic/butterfly/lavaland/temporary, fadeout)), rand(60, 120) SECONDS, TIMER_DELETE_ME)

/// A green shimmer over a tended tray.
/obj/effect/temp_visual/artifact_gaia_bloom
	icon = 'icons/obj/service/hydroponics/equipment.dmi'
	icon_state = "gaia_blessing"
	duration = 1.5 SECONDS

/obj/effect/temp_visual/artifact_gaia_bloom/Initialize(mapload)
	. = ..()
	alpha = 0
	animate(src, alpha = 255, time = 0.4 SECONDS)
	animate(alpha = 0, time = 1.1 SECONDS)

/// A soft green ring for the burst.
/obj/effect/temp_visual/circle_wave/artifact_ring/gaia
	color = "#8cd448"
	max_alpha = 140

#undef ARTIFACT_GAIA_MAX_BUTTERFLIES
