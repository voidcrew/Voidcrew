/*
 * Novelty reagents ported from monkestation.
 */

/// Flips the drinker upside down, and inverts every invertible chem it shares a
/// container with.
/datum/reagent/australium
	name = "Australium"
	description = "Turns people upside down. Has interesting effects on other chemicals, too."
	color = "#9b9924"
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED|REAGENT_CLEANS
	taste_description = "spiders"
	requires_process = TRUE

/datum/reagent/australium/on_mob_add(mob/living/affected_mob, amount)
	. = ..()
	var/matrix/flipped = matrix(affected_mob.transform)
	flipped.Turn(180)
	animate(affected_mob, transform = flipped, time = 3)

/datum/reagent/australium/on_mob_delete(mob/living/affected_mob)
	. = ..()
	var/matrix/flipped = matrix(affected_mob.transform)
	flipped.Turn(180)
	animate(affected_mob, transform = flipped, time = 3)

/datum/reagent/australium/reagent_fire(obj/item/reagent_containers/host)
	for(var/datum/reagent/listed_reagent as anything in host.reagents.reagent_list.Copy())
		if(isnull(listed_reagent))
			continue
		// /datum/reagent/inverse is the generic fallback every reagent carries by
		// default - only convert chems that name a real inverse of their own.
		if(isnull(listed_reagent.inverse_chem) || listed_reagent.inverse_chem == /datum/reagent/inverse)
			continue
		var/listed_volume = listed_reagent.volume
		var/inverse_type = listed_reagent.inverse_chem
		host.reagents.remove_reagent(listed_reagent.type, listed_volume)
		host.reagents.add_reagent(inverse_type, listed_volume)

/// Shakes the drinker harder and harder. Overdosing eventually rattles them apart.
/datum/reagent/shakeium
	name = "Shakeium"
	description = "Causes violent shaking in consumers."
	color = "#6fda28"
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED|REAGENT_CLEANS
	taste_description = "milkshakes"
	overdose_threshold = 25
	/// Grows every life tick, driving how far the mob is shaken.
	var/intensity = 1
	/// Brute per overdose tick. Climbs once the shaking gets bad enough.
	var/damage_amount = 3
	/// Set once the limb-loss timers have been queued, so they only fire once.
	var/triggered_breakdown = FALSE

/datum/reagent/shakeium/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	var/pixel_shift = (1 + (intensity / 10))
	affected_mob.Shake(pixel_shift, pixel_shift)
	intensity += seconds_per_tick

/datum/reagent/shakeium/overdose_start(mob/living/affected_mob, metabolization_ratio)
	. = ..()
	to_chat(affected_mob, span_warning("You're vibrating too hard. Your body can't take much more of this."))

/datum/reagent/shakeium/overdose_process(mob/living/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	// REM RESTORATION: authored against the old REM (0.5), where `damage_amount * REM * seconds_per_tick`
	// dealt damage_amount brute per 2s tick == damage_amount/2 per second. REM is now 2.5, so that
	// expression became 5x. Default metabolization_rate (0.2) => metabolization_ratio == 1.0 at a normal
	// 2s tick, so the coefficient halves: damage_amount * 0.5 * 1.0 * 2 == damage_amount per tick.
	// damage_amount itself is REM-independent, so the >10 / >20 escalation thresholds are untouched.
	var/need_mob_update = affected_mob.adjust_brute_loss(damage_amount * 0.5 * metabolization_ratio * seconds_per_tick, updating_health = FALSE)
	if(intensity > 15)
		intensity += seconds_per_tick
		damage_amount += seconds_per_tick
	if(damage_amount > 10)
		to_chat(affected_mob, span_warning("Your brain is rattling around inside your skull. You need a doctor."))
		// REM RESTORATION: was 3 * REM(0.5) * spt == 3 brain damage per 2s tick (1.5/s); ratio == 1.0 here,
		// so 1.5 * ratio * spt == 3 per tick. No `maximum` arg, so this is uncapped flat organ damage.
		need_mob_update += affected_mob.adjust_organ_loss(ORGAN_SLOT_BRAIN, 1.5 * metabolization_ratio * seconds_per_tick, required_organ_flag = affected_organ_flags)
	if(damage_amount > 20 && !triggered_breakdown && iscarbon(affected_mob))
		to_chat(affected_mob, span_userdanger("You can't hold yourself together any longer!"))
		triggered_breakdown = TRUE
		var/mob/living/carbon/carbon_target = affected_mob
		var/timer = 15 SECONDS
		for(var/obj/item/bodypart/limb as anything in carbon_target.bodyparts)
			if(limb.body_part == HEAD || limb.body_part == CHEST)
				continue
			addtimer(CALLBACK(limb, TYPE_PROC_REF(/obj/item/bodypart, dismember)), timer)
			addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(playsound), carbon_target, 'sound/effects/cartoon_sfx/cartoon_pop.ogg', 70), timer)
			timer += 15 SECONDS
	if(need_mob_update)
		return UPDATE_MOB_HEALTH

/// Sets you on fire unless you have a lawman's liver.
/datum/reagent/liquid_justice
	name = "Liquid Justice"
	description = "Rumour has it only the truly robust can process this safely."
	color = "#00ffff" // rgb: 0, 255, 255
	metabolization_rate = 1.5 * REAGENTS_METABOLISM
	ph = 0

// Metabolises 50% faster than phlogiston and gives double fire stacks, but deals
// no direct burn damage of its own.
/datum/reagent/liquid_justice/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	var/obj/item/organ/liver/liver = affected_mob.get_organ_slot(ORGAN_SLOT_LIVER)
	if(!liver || !HAS_TRAIT(liver, TRAIT_LAW_ENFORCEMENT_METABOLISM))
		// REM RESTORATION: was 2 * REM(0.5) * spt == 2 fire stacks per 2s tick (1.0/s), i.e. exactly double
		// phlogiston, which is what the comment above promises. metabolization_rate here is 1.5x default, so
		// metabolization_ratio == 1.5 at a normal 2s tick and the coefficient is 2 / (2 * 1.5) == 0.66667:
		// 0.66667 * 1.5 * 2 == 2.0 stacks per tick. Upstream phlogiston is now 0.5 * ratio(1.0) * spt == 1.0,
		// so the "double phlogiston" relationship still holds.
		affected_mob.adjust_fire_stacks(0.66667 * metabolization_ratio * seconds_per_tick)
		affected_mob.ignite_mob()
