// Artifact effect: disarm.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/disarm.dm. Voidcrew:
// pries open the hand people are using, so what they hold drops at their feet (never thrown, so
// nothing lands in a chasm or lava); items that can't be dropped stay put. Run from a carried
// battery, it pries open its carrier's hand too. Logged like a weapon.

/datum/artifact_effect/disarm
	label_name = "Makes people drop things"
	log_name = "Disarm"
	tier = ARTIFACT_TIER_UNCOMMON
	harmful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_PSIONIC, ARTIFACT_ENERGY_BLUESPACE)

/datum/artifact_effect/disarm/do_effect_touch(mob/living/user)
	pry(user)

/datum/artifact_effect/disarm/do_effect_aura(seconds_per_tick)
	for(var/mob/living/target in living_in_range())
		if(SPT_PROB(6, seconds_per_tick))
			pry(target)

/datum/artifact_effect/disarm/do_effect_pulse(power)
	var/turf/center = source_turf()
	if(center)
		new /obj/effect/temp_visual/circle_wave/artifact_ring/pry(center, max(range * 0.6, 1.5))
	for(var/mob/living/target in living_in_range())
		pry(target)

/// Makes `target` drop what is in their active hand. Returns TRUE if it fell.
/datum/artifact_effect/disarm/proc/pry(mob/living/target)
	if(target.stat != CONSCIOUS)
		return FALSE
	if(!prob(100 * artifact_exposure(target)))
		return FALSE
	var/obj/item/held = target.get_active_held_item()
	if(!held || !target.dropItemToGround(held))
		return FALSE
	target.visible_message(
		span_warning("[target]'s hand jerks open and [held] falls to the floor."),
		span_warning("Something pries your fingers open. [held] falls out of your grip!"),
	)
	playsound(target, 'sound/items/weapons/thudswoosh.ogg', 40, TRUE)
	new /obj/effect/temp_visual/telekinesis(get_turf(target))
	log_harm(target)
	return TRUE

/// A faint violet ripple for the burst.
/obj/effect/temp_visual/circle_wave/artifact_ring/pry
	color = "#e17ceb"
	max_alpha = 110
